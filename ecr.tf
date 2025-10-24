# ECR Repository for Docker images

resource "aws_ecr_repository" "repo" {
  name                 = local.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = local.ecr_repo_name
  })
}

# Application files
resource "local_file" "app_py" {
  filename = "app.py"
  content  = <<-PY
import os
import asyncio
import json
from typing import List
from flask import Flask, request, jsonify
import aiohttp
from tenacity import retry, wait_exponential, stop_after_attempt, retry_if_exception_type
import boto3

# langchain imports
try:
    from langchain_aws.llms import BedrockLLM
except Exception:
    try:
        from langchain_community.llms.bedrock import Bedrock as BedrockLLM
    except Exception:
        BedrockLLM = None

app = Flask(__name__)

SERPAPI_KEY = os.getenv('SERPAPI_API_KEY', '')
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
DDB_TABLE = os.getenv('DDB_TABLE', '')
BEDROCK_MODEL = os.getenv('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')

session = None

# ------------------ async web search (concurrent) ------------------
async def serpapi_search_single(session: aiohttp.ClientSession, query: str, start: int = 0):
    url = 'https://serpapi.com/search.json'
    params = {'q': query, 'api_key': SERPAPI_KEY, 'start': start}
    async with session.get(url, params=params, timeout=15) as resp:
        resp.raise_for_status()
        return await resp.json()

async def run_concurrent_searches(query: str, pages: int = 2) -> List[str]:
    if not SERPAPI_KEY:
        return []
    global session
    if session is None:
        session = aiohttp.ClientSession()
    tasks = [serpapi_search_single(session, query, start=i*10) for i in range(pages)]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    snippets = []
    for r in results:
        if isinstance(r, Exception):
            print('search error', r)
            continue
        for item in r.get('organic_results', [])[:5]:
            snippets.append(item.get('snippet') or item.get('title') or '')
    return snippets

# ------------------ DynamoDB retrieval ------------------

db = boto3.resource('dynamodb', region_name=AWS_REGION)

def ddb_search_similar(topic: str) -> List[str]:
    if not DDB_TABLE:
        return []
    table = db.Table(DDB_TABLE)
    try:
        resp = table.scan()
        items = resp.get('Items', [])
        out = [it['content'] for it in items if 'content' in it and topic.lower() in it['content'].lower()]
        return out
    except Exception as e:
        print(f'DynamoDB error: {e}')
        return []

# ------------------ Bedrock summarize with retry/backoff ------------------
@retry(wait=wait_exponential(min=1, max=10), stop=stop_after_attempt(3), retry=retry_if_exception_type(Exception))
def call_bedrock(prompt: str) -> str:
    if BedrockLLM is None:
        return 'BEDROCK SDK not installed. Prompt excerpt:\n' + prompt[:500]
    
    try:
        llm = BedrockLLM(
            model_id=BEDROCK_MODEL,
            region_name=AWS_REGION
        )
        response = llm.invoke(prompt)
        return str(response)
    except Exception as e:
        print(f'Bedrock error: {e}')
        raise

# ------------------ Orchestrator ------------------
@app.route('/health')
def health():
    return jsonify({'status': 'ok'})

@app.route('/summarize', methods=['POST'])
def summarize():
    try:
        payload = request.get_json(force=True) or {}
    except Exception as e:
        print(f'JSON parsing error: {e}')
        return jsonify({'error': f'Invalid JSON: {e}'}), 400
    
    topic = payload.get('topic', '').strip()
    if not topic:
        return jsonify({'error': 'topic required'}), 400

    # run async web searches
    try:
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        web_snippets = loop.run_until_complete(run_concurrent_searches(topic, pages=2))
    except Exception as e:
        print(f'Web search error: {e}')
        web_snippets = []

    # db retrieval
    db_snippets = ddb_search_similar(topic)

    # combine and summarize
    combined = '\n\n'.join([f'Web: {s}' for s in web_snippets[:20]] + [f'DB: {s}' for s in db_snippets[:20]])
    if not combined.strip():
        combined = f'Topic: {topic}'
    
    prompt = f"""You are an expert summarizer. Summarize key points and action items about '{topic}'. Use the following sources:
{combined}"""

    try:
        summary = call_bedrock(prompt)
    except Exception as e:
        summary = f'Summary generation failed: {str(e)[:200]}'
        print(f'Bedrock call failed: {e}')

    return jsonify({
        'topic': topic, 
        'summary': summary, 
        'web_count': len(web_snippets), 
        'db_count': len(db_snippets)
    })

if __name__ == '__main__':
    print(f'Starting app with BEDROCK_MODEL={BEDROCK_MODEL}, AWS_REGION={AWS_REGION}')
    app.run(host='0.0.0.0', port=80, debug=False)
PY
}

resource "local_file" "dockerfile" {
  filename = "Dockerfile"
  content  = <<-DOCKER
FROM python:3.11-slim
WORKDIR /app
COPY app.py ./
COPY populate_db.py ./
RUN apt-get update && apt-get install -y gcc libpq-dev build-essential --no-install-recommends && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir aiohttp flask tenacity boto3 langchain langchain-aws langchain-community
ENV SERPAPI_API_KEY=""
ENV BEDROCK_MODEL_ID="${local.bedrock_model_id}"
ENV AWS_REGION="${local.region}"
ENV DDB_TABLE="${local.dynamodb_table}"
EXPOSE 80
CMD ["python", "app.py"]
DOCKER
}

resource "local_file" "requirements_txt" {
  filename = "requirements.txt"
  content  = <<-REQ
aiohttp
flask
tenacity
boto3
langchain
langchain-aws
langchain-community
REQ
}

resource "local_file" "populate_db_py" {
  filename = "populate_db.py"
  content  = <<-POP
import os
import boto3

ddb = boto3.resource('dynamodb', region_name=os.getenv('AWS_REGION','${local.region}'))
TABLE = os.getenv('DDB_TABLE','${local.dynamodb_table}')

def main():
    table = ddb.Table(TABLE)
    items = [
        {'id': '1', 'content': 'Canada plans to increase wind and solar capacity by 2030.'},
        {'id': '2', 'content': 'Alberta announced incentives for renewable projects.'},
        {'id': '3', 'content': 'Investors show interest in battery storage solutions.'},
        {'id': '4', 'content': 'British Columbia targets net-zero emissions with new policies.'},
        {'id': '5', 'content': 'Ontario invests in electric vehicle infrastructure expansion.'}
    ]
    for it in items:
        table.put_item(Item=it)
    print('Inserted sample items into', TABLE)

if __name__ == '__main__':
    main()
POP
}

# Build and push Docker image to ECR
resource "null_resource" "build_and_push" {
  depends_on = [
    aws_ecr_repository.repo,
    local_file.app_py,
    local_file.dockerfile,
    local_file.populate_db_py
  ]

  provisioner "local-exec" {
    command = <<-CMD
      aws ecr get-login-password --region ${local.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.repo.repository_url} && docker build -t ${local.project_name}:${local.image_tag} . && docker tag ${local.project_name}:${local.image_tag} ${aws_ecr_repository.repo.repository_url}:${local.image_tag} && docker push ${aws_ecr_repository.repo.repository_url}:${local.image_tag}
    CMD
  }

  triggers = {
    app_file        = md5(local_file.app_py.content)
    dockerfile      = md5(local_file.dockerfile.content)
    populate_db     = md5(local_file.populate_db_py.content)
    requirements    = md5(local_file.requirements_txt.content)
  }
}

