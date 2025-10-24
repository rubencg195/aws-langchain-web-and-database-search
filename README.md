# AWS LangChain Web and Database Search

A production-ready serverless application that combines web search and database retrieval with AI-powered summarization using AWS Bedrock. The application is deployed on AWS ECS Fargate using OpenTofu/Terraform.

## Project Status

✅ **FULLY DEPLOYED AND OPERATIONAL WITH BEDROCK SUMMARIZATION WORKING**

### Latest Updates (October 24, 2025)

**Infrastructure**: All resources deployed successfully via OpenTofu
- VPC with 2 public subnets ✅
- Application Load Balancer ✅
- ECS Fargate cluster with running Flask task ✅
- ECR repository with Docker image built and pushed ✅
- DynamoDB table with 5 sample items populated ✅
- CloudWatch Logs integration ✅
- Bedrock Inference Profile (system-defined Claude Haiku 4.5) ✅

**API Status**:
- Health Check (`/health`): ✅ Working - Returns `{"status":"ok"}`
- Summarize Endpoint (`/summarize`): ✅ Working - HTTP 200 with JSON response
- Database Search: ✅ Verified - Successfully retrieves matching items
- **Bedrock Summarization**: ✅ **WORKING** - Claude Haiku 4.5 generating summaries
- Error Handling: ✅ Graceful error messages with proper status codes

**Testing Results**:
```bash
# Test 1: Health Check ✅
curl http://langchain-web-db-search-alb-1600321510.us-east-1.elb.amazonaws.com/health
Response: {"status":"ok"}

# Test 2: Bedrock Summarization with Database Context ✅  
curl -X POST http://langchain-web-db-search-alb-1600321510.us-east-1.elb.amazonaws.com/summarize \
  -H "Content-Type: application/json" \
  -d '{"topic":"Canada"}'
  
Response:
{
  "db_count": 1,
  "summary": "# Canada's Renewable Energy Expansion\n\nCanada is planning to significantly increase its wind and solar energy capacity by 2030 as part of its commitment to clean energy and climate goals. This expansion aims to reduce reliance on fossil fuels and support the country's transition toward net-zero emissions...",
  "topic": "Canada",
  "web_count": 0
}
```

**Working Components**:
- ✅ Infrastructure fully managed by OpenTofu
- ✅ Docker containerization and ECR integration
- ✅ Database search functionality
- ✅ Bedrock Claude Haiku 4.5 integration
- ✅ API endpoints responding correctly
- ✅ CloudWatch logging
- ✅ Error handling and retry logic

**Known Status**:
- Database search working correctly ✅
- API endpoint responding properly ✅
- Error handling functional ✅
- Bedrock model access not yet enabled (pending account setup)

### Current Status Details
- **Infrastructure**: All resources deployed successfully
- **ECS Service**: Running and healthy
- **Health Check**: ✅ Working (`/health` returns 200 OK)
- **Database**: ✅ DynamoDB populated with 5 sample renewable energy items
- **API Response**: ✅ Returns correct JSON structure with db_count matching
- **Summarize Endpoint**: ✅ Responding (HTTP 200), Bedrock setup needed for full functionality
- **Known Issues**: Bedrock model access not yet enabled in AWS account

## Overview

This project demonstrates a modern RAG (Retrieval-Augmented Generation) architecture that:
- **Web Search**: Concurrent async searches using SerpAPI with retry/backoff logic
- **Database Retrieval**: Queries DynamoDB for relevant stored knowledge
- **AI Summarization**: Uses AWS Bedrock (Claude 3 Sonnet) to generate summaries
- **Orchestration**: Combines multiple data sources in a Flask API
- **Infrastructure as Code**: Fully automated deployment using OpenTofu

## Architecture

```
┌─────────────────┐
│   Application   │
│  Load Balancer  │
│    (ALB)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   ECS Fargate   │
│   Flask API     │
│                 │
│  ┌──────────┐   │
│  │ Web      │   │
│  │ Search   │───┼──► SerpAPI
│  └──────────┘   │
│                 │
│  ┌──────────┐   │
│  │ Database │   │
│  │ Search   │───┼──► DynamoDB
│  └──────────┘   │
│                 │
│  ┌──────────┐   │
│  │ Bedrock  │   │
│  │ Summary  │───┼──► AWS Bedrock
│  └──────────┘   │
└─────────────────┘
```

## Features

### Application Features
- ✅ **Async Concurrent Web Search**: Multiple SerpAPI searches run in parallel
- ✅ **Tenacity Retry Logic**: Automatic retry with exponential backoff
- ✅ **DynamoDB Integration**: Retrieval from knowledge base with sample data
- ✅ **AWS Bedrock LLM**: Claude 3 Sonnet for summarization (needs account setup)
- ✅ **RESTful API**: Simple POST endpoint for summarization
- ✅ **Health Checks**: Monitoring endpoint for ALB

### Infrastructure Features
- ✅ **Fully Automated Deployment**: One command deployment with OpenTofu
- ✅ **Modular Architecture**: Separated into logical components (VPC, ECR, Fargate, DynamoDB)
- ✅ **Auto-scaling Ready**: ECS Fargate with configurable task counts
- ✅ **Secure Networking**: VPC with public subnets and security groups
- ✅ **Container Registry**: Private ECR repository
- ✅ **Logging**: CloudWatch Logs integration
- ✅ **Infrastructure Testing**: Automated endpoint validation

## Project Structure

```
.
├── provider.tf          # AWS provider configuration
├── locals.tf            # Local variables and constants
├── data.tf              # Data sources (AZs)
├── vpc.tf               # VPC, subnets, routing, security groups
├── dynamo.tf            # DynamoDB table and data population
├── ecr.tf               # ECR repository, Docker build/push, app files
├── fargate.tf           # ECS cluster, task definition, service, ALB
├── output.tf            # Output values (ALB DNS, endpoints)
├── test.tf              # Automated API testing
├── app.py               # Flask application (generated)
├── Dockerfile           # Container image definition (generated)
├── populate_db.py       # DynamoDB seeding script (generated)
├── requirements.txt     # Python dependencies (generated)
└── README.md            # This file
```

## Prerequisites

1. **OpenTofu/Terraform**: Install OpenTofu
   ```bash
   # macOS
   brew install opentofu
   
   # Windows (WSL/Git Bash)
   # Download from https://opentofu.org/
   ```

2. **AWS CLI**: Configured with credentials
   ```bash
   aws configure
   ```

3. **Docker**: For building container images
   ```bash
   docker --version
   ```

4. **Python 3**: For database population script
   ```bash
   python3 --version
   ```

5. **AWS Permissions**: Your AWS account needs:
   - ECS, ECR, VPC, ALB, DynamoDB, CloudWatch Logs
   - **Bedrock Model Access** (IMPORTANT - see setup below)
   - IAM role creation

## Deployment

### Quick Start

```bash
# Initialize OpenTofu
tofu init

# Deploy everything
tofu apply -auto-approve
```

That's it! The deployment will:
1. Create VPC and networking infrastructure
2. Create ECR repository
3. Build and push Docker image
4. Create DynamoDB table and populate with sample data
5. Deploy ECS Fargate service with ALB
6. Run automated tests

### Deployment Time
- **Total**: ~10-12 minutes
- Image build/push: ~2-3 minutes
- ECS service stabilization: ~2-3 minutes
- Testing: ~2 minutes

## Accessing the Application

### Get Endpoints

```bash
tofu output
```

Output will show:
```
alb_dns_name = "langchain-web-db-search-alb-xxx.us-east-1.elb.amazonaws.com"
health_endpoint = "http://langchain-web-db-search-alb-xxx.us-east-1.elb.amazonaws.com/health"
summarize_endpoint = "http://langchain-web-db-search-alb-xxx.us-east-1.elb.amazonaws.com/summarize"
```

### API Usage

#### Health Check
```bash
curl http://<ALB_DNS>/health
```

Response:
```json
{"status":"ok"}
```

#### Summarize Endpoint

```bash
curl -X POST http://<ALB_DNS>/summarize \
  -H "Content-Type: application/json" \
  -d '{"topic": "renewable energy"}'
```

Response:
```json
{
  "topic": "renewable energy",
  "summary": "Based on the available information...",
  "web_count": 0,
  "db_count": 3
}
```

## Setup & Configuration

### 1. Bedrock Setup (ALREADY AUTOMATED)

**Good news**: Bedrock model access is now automatically enabled by AWS for all accounts!

✅ **System-Defined Inference Profiles**: AWS provides pre-built inference profiles for optimal cross-region support
✅ **Claude Haiku 4.5 (Latest Model)**: `us.anthropic.claude-haiku-4-5-20251001-v1:0` 
✅ **No Manual Enablement Needed**: All foundation models support on-demand throughput by default

**What's Configured**:
- Model: `anthropic.claude-haiku-4-5-20251001-v1:0` (latest, most cost-effective)
- Inference Profile: System-defined for us-east-1 region
- API Version: `bedrock-2023-05-31` with proper message format
- Auto-retry with exponential backoff (3 attempts, max 10s wait)

**If You Want to Change the Model**:

Edit `bedrock.tf` to use a different inference profile ARN, or edit `locals.tf` for model configuration:
```hcl
locals {
  bedrock_model_id = "arn:aws:bedrock:us-east-1:ACCOUNT_ID:inference-profile/us.anthropic.claude-3-sonnet-20240229-v1:0"
}
```

Available inference profiles (system-defined):
- `us.anthropic.claude-haiku-4-5-20251001-v1:0` (default - fast, cost-effective) ✅
- `us.anthropic.claude-3-sonnet-20240229-v1:0` (balanced)
- `us.anthropic.claude-3-opus-20240229-v1:0` (most capable)

### 2. AWS Region
Edit `locals.tf`:
```hcl
locals {
  region = "us-east-1"  # Change to your preferred region
}
```

### 3. Bedrock Model Configuration

The model is managed through the Bedrock inference profile. The correct setup is already in place in `bedrock.tf`:

```hcl
# bedrock.tf - Already configured for system-defined Haiku 4.5
locals {
  bedrock_inference_profile_arn = "arn:aws:bedrock:${local.region}:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
}
```

This references AWS's system-defined inference profile which:
- ✅ Supports on-demand throughput
- ✅ Works across us-east-1, us-east-2, us-west-2
- ✅ Automatically scales based on usage
- ✅ No provisioning or configuration needed

### 4. ECS Resources
Edit `locals.tf`:
```hcl
locals {
  ecs_cpu    = "1024"  # 1 vCPU
  ecs_memory = "2048"  # 2 GB
}
```

### 5. SerpAPI Key (Optional - for web search)

For web search functionality, add SERPAPI_KEY to the container environment:

1. Get API key from https://serpapi.com/
2. Edit `fargate.tf`, add to `environment` block in task definition:
   ```hcl
   {
     name  = "SERPAPI_API_KEY"
     value = "your-api-key-here"
   }
   ```
3. Redeploy: `tofu apply -auto-approve`

## Sample Data

The DynamoDB table is pre-populated with renewable energy facts:
- Canada's wind and solar capacity plans (2030)
- Alberta renewable project incentives
- Battery storage investment trends
- British Columbia net-zero policies
- Ontario EV infrastructure

To modify or add data, edit the populate_db.py section in `ecr.tf` and redeploy.

## Monitoring

### CloudWatch Logs
```bash
aws logs tail /ecs/aws-langchain-web-and-database-search --follow
```

### ECS Service Status
```bash
aws ecs describe-services \
  --cluster aws-langchain-web-and-database-search-cluster \
  --services aws-langchain-web-and-database-search \
  --region us-east-1
```

### View Service Events
```bash
aws ecs describe-services \
  --cluster aws-langchain-web-and-database-search-cluster \
  --services aws-langchain-web-and-database-search \
  --query 'services[0].events[:5]' \
  --region us-east-1
```

## Cost Estimation

**Monthly costs** (with minimal usage):
- ECS Fargate (1 task): ~$30-40
- ALB: ~$20
- DynamoDB (on-demand): ~$1-5
- ECR: ~$1
- CloudWatch Logs: ~$1
- Data Transfer: Variable
- **Bedrock**: Pay per token (~$0.003/1K input tokens, ~$0.015/1K output tokens)

**Total**: ~$55-70/month (plus Bedrock usage)

## Troubleshooting

### Bedrock Returns ValidationError
**Solution**: Enable Bedrock model access in your AWS account (see Setup section above)

### ECS Task Won't Start
```bash
# Check task status
aws ecs describe-tasks \
  --cluster aws-langchain-web-and-database-search-cluster \
  --tasks <task-arn> \
  --region us-east-1

# Check logs
aws logs tail /ecs/aws-langchain-web-and-database-search --follow
```

### Health Check Fails
- Wait 2-3 minutes for service to stabilize
- Check security group allows port 80
- Verify task is running: `aws ecs list-tasks --cluster aws-langchain-web-and-database-search-cluster`

### Summarize Returns 415 Error
- Ensure Content-Type header is set to `application/json`
- Use `curl -H "Content-Type: application/json"`

### No Database Results
- Verify data exists: `aws dynamodb scan --table-name aws-langchain-web-and-database-search-kb`
- Search terms must match content in database (case-insensitive)
- Try searching for keywords from the sample data

## Cleanup

To destroy all resources:
```bash
tofu destroy -auto-approve
```

This will remove:
- ECS service and tasks
- ALB and target groups
- ECR repository (images retained)
- DynamoDB table (data deleted)
- VPC and networking
- IAM roles and policies
- CloudWatch log groups

## Development

### Local Testing
```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export AWS_REGION=us-east-1
export DDB_TABLE=aws-langchain-web-and-database-search-kb
export BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0

# Run locally
python app.py
```

### Updating the Application
1. Modify code in `ecr.tf` (app.py, populate_db.py, etc.)
2. Run `tofu apply -auto-approve`
3. OpenTofu will rebuild and redeploy automatically

### Adding More Data
1. Edit `populate_db.py` in `ecr.tf`