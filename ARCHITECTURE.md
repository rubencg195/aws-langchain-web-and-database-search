# AWS LangChain Architecture - Complete System Design

## System Architecture Overview

```mermaid
graph TB
    User["👤 User/Client"]
    Internet["🌐 Internet"]
    
    subgraph AWS["AWS Cloud (us-east-1)"]
        subgraph Network["VPC (10.0.0.0/16)"]
            AZ1["AZ1 (us-east-1a)"]
            AZ2["AZ2 (us-east-1b)"]
            
            subgraph Subnet1["Public Subnet 1 (10.0.1.0/24)"]
                Task1["ECS Task 1<br/>Flask App"]
            end
            
            subgraph Subnet2["Public Subnet 2 (10.0.2.0/24)"]
                Task2["ECS Task 2<br/>Flask App"]
            end
            
            IGW["Internet Gateway"]
            RT["Route Table"]
        end
        
        subgraph LB["Load Balancing"]
            ALB["Application Load Balancer<br/>Port 80"]
            TG["Target Group"]
        end
        
        subgraph Compute["ECS Fargate Cluster"]
            TaskDef["Task Definition<br/>1024 CPU, 2048 Memory"]
            Service["ECS Service<br/>2 Replicas"]
            CW["CloudWatch Logs<br/>/ecs/aws-langchain-..."]
        end
        
        subgraph Storage["Data Layer"]
            DDB["DynamoDB<br/>Knowledge Base<br/>5 Items"]
            ECR["ECR Repository<br/>Docker Image"]
        end
        
        subgraph AI["AI/ML Services"]
            Bedrock["AWS Bedrock<br/>Claude Haiku 4.5"]
            Profile["Inference Profile<br/>us.anthropic.claude-haiku-4-5"]
        end
        
        subgraph External["External Services"]
            SerpAPI["SerpAPI<br/>Web Search<br/>Optional"]
        end
    end
    
    User -->|HTTP Request| Internet
    Internet -->|Port 80| ALB
    ALB -->|Route| TG
    TG -->|Target| Task1
    TG -->|Target| Task2
    Task1 -->|Pull Image| ECR
    Task2 -->|Pull Image| ECR
    Task1 -->|Query| DDB
    Task2 -->|Query| DDB
    Task1 -->|Logs| CW
    Task2 -->|Logs| CW
    Task1 -->|Invoke| Bedrock
    Task2 -->|Invoke| Bedrock
    Bedrock -->|Use| Profile
    Task1 -.->|Optional| SerpAPI
    Task2 -.->|Optional| SerpAPI
    Task1 -->|HTTP Response| Internet
    Task2 -->|HTTP Response| Internet
    Internet -->|HTTP Response| User
```

## Request Flow - Complete Journey

```mermaid
sequenceDiagram
    participant User as User/Client
    participant ALB as ALB (Port 80)
    participant TG as Target Group
    participant Task as ECS Task<br/>(Flask)
    participant DDB as DynamoDB
    participant Bedrock as AWS Bedrock
    participant SerpAPI as SerpAPI<br/>(Optional)
    participant CW as CloudWatch Logs

    User->>ALB: POST /summarize<br/>{"topic":"Canada"}
    ALB->>TG: Forward Request
    TG->>Task: Route to Task 1 or 2
    activate Task
    
    Task->>Task: Parse JSON Payload
    Task->>CW: Log: Processing topic
    
    Task->>DDB: Scan for matching items<br/>topic="Canada"
    DDB->>Task: Return 1 item
    Task->>CW: Log: db_count=1
    
    alt SerpAPI Key Configured
        Task->>SerpAPI: POST search request<br/>Optional web search
        SerpAPI->>Task: Return search results
        Task->>CW: Log: web_count=X
    else No SerpAPI Key
        Task->>CW: Log: SerpAPI skipped
    end
    
    Task->>Task: Combine DDB + Web results
    Task->>Task: Build prompt for Bedrock
    Task->>CW: Log: Prompt length: XXX chars
    
    Task->>Bedrock: invoke_model()<br/>Model: Haiku 4.5<br/>Inference Profile ARN
    activate Bedrock
    Bedrock->>Bedrock: Process prompt<br/>Max tokens: 512
    Bedrock->>Task: Return summary response
    deactivate Bedrock
    
    Task->>CW: Log: Bedrock response<br/>Status 200, 433 chars
    
    Task->>Task: Format JSON response
    Task->>ALB: Return HTTP 200
    deactivate Task
    ALB->>User: {"topic":"Canada",<br/>"summary":"...",<br/>"db_count":1,<br/>"web_count":0}
```

## Flask Application Flow - Internal Processing

```mermaid
graph TD
    A["1. HTTP Request<br/>POST /summarize<br/>{topic: 'Canada'}"] -->|Parse| B["2. Extract Topic<br/>Clean & Validate"]
    
    B -->|Trigger| C["3. Database Search<br/>DynamoDB Scan"]
    C -->|Return| D["4. Parse DB Results<br/>List of items"]
    
    B -->|Check| E{SerpAPI Key<br/>Configured?}
    E -->|Yes| F["5. Web Search<br/>SerpAPI Async"]
    E -->|No| G["Skip Web Search"]
    F -->|Return| H["6. Parse Web Results<br/>List of snippets"]
    G --> H
    
    D --> I["7. Combine Results<br/>DB + Web"]
    H --> I
    
    I -->|Create| J["8. Build Prompt<br/>Topic + Context<br/>+ Instructions"]
    
    J -->|Retry Logic| K["9. Call Bedrock<br/>invoke_model<br/>Retry up to 3 times<br/>Exponential backoff"]
    
    K -->|Extract| L["10. Parse Response<br/>response['body'].read()"]
    
    L -->|Error Handling| M{Response<br/>Valid?}
    
    M -->|Success| N["11. Extract Summary<br/>response_body['content'][0]['text']"]
    M -->|Error| O["12. Handle Error<br/>Extract error message<br/>Return to user"]
    
    N --> P["13. Format JSON<br/>topic, summary, db_count, web_count"]
    O --> P
    
    P -->|Return| Q["14. HTTP 200<br/>JSON Response<br/>to User"]
```

## AWS Component Interactions

### 1. VPC & Networking
```mermaid
graph LR
    IGW["Internet Gateway"]
    
    subgraph VPC["VPC 10.0.0.0/16"]
        RT["Route Table"]
        
        subgraph AZ1["Availability Zone 1"]
            Sub1["Subnet 10.0.1.0/24"]
            Task1["Task 1"]
        end
        
        subgraph AZ2["Availability Zone 2"]
            Sub2["Subnet 10.0.2.0/24"]
            Task2["Task 2"]
        end
        
        SG["Security Group<br/>Ingress: 80<br/>Egress: All"]
    end
    
    IGW -->|Route| VPC
    RT -->|Forward| IGW
    Sub1 --> RT
    Sub2 --> RT
    Task1 -.->|Attached| SG
    Task2 -.->|Attached| SG
```

### 2. Load Balancing & Service Discovery
```mermaid
graph TB
    Internet["Client Requests"]
    
    Internet --> ALB["ALB<br/>langchain-web-db-search-alb<br/>Port: 80<br/>Protocol: HTTP"]
    
    ALB --> LR["Listener Rule<br/>Path: /health, /summarize"]
    
    LR --> TG["Target Group<br/>langchain-web-db-search-tg<br/>Port: 80<br/>Protocol: HTTP"]
    
    TG --> HC["Health Check<br/>Path: /health<br/>Interval: 30s<br/>Threshold: 2"]
    
    HC --> T1["Target: Task 1<br/>IP: 10.0.1.X<br/>Status: Healthy"]
    HC --> T2["Target: Task 2<br/>IP: 10.0.2.X<br/>Status: Healthy"]
    
    T1 --> APP1["Flask App<br/>Port 80"]
    T2 --> APP2["Flask App<br/>Port 80"]
```

### 3. ECS Fargate Compute Layer
```mermaid
graph TD
    Cluster["ECS Cluster<br/>aws-langchain-web-and-database-search-cluster<br/>FARGATE launch type"]
    
    Cluster --> TaskDef["Task Definition<br/>aws-langchain-web-and-database-search<br/>Image: ECR URL<br/>CPU: 1024<br/>Memory: 2048"]
    
    TaskDef -->|Environment Variables| Env["BEDROCK_MODEL_ID<br/>AWS_REGION: us-east-1<br/>DDB_TABLE: aws-langchain-web-and-database-search-kb<br/>SERPAPI_API_KEY: optional"]
    
    TaskDef -->|Logging| LogDriver["awslogs driver<br/>Log Group: /ecs/aws-langchain-web-and-database-search"]
    
    TaskDef -->|IAM Role| Role["ecsTaskExecutionRole<br/>Permissions:<br/>- bedrock:InvokeModel<br/>- dynamodb:Scan<br/>- dynamodb:Query<br/>- logs:CreateLogStream<br/>- logs:PutLogEvents<br/>- ecr:GetAuthorizationToken"]
    
    Cluster --> Service["ECS Service<br/>Desired Count: 2<br/>Launch Type: FARGATE<br/>Network: Public Subnets"]
    
    Service -->|Manages| Task1["Running Task 1"]
    Service -->|Manages| Task2["Running Task 2"]
    
    Task1 --> Container1["Flask Container<br/>Python 3.11"]
    Task2 --> Container2["Flask Container<br/>Python 3.11"]
```

### 4. Data & Storage Layer
```mermaid
graph TB
    subgraph DynamoDB["DynamoDB<br/>Billing Mode: PAY_PER_REQUEST"]
        Table["Table: aws-langchain-web-and-database-search-kb<br/>Partition Key: id (String)"]
        
        Table -->|Item 1| I1["Canada Renewable Energy<br/>2030 capacity plans"]
        Table -->|Item 2| I2["Alberta Incentives<br/>Project development"]
        Table -->|Item 3| I3["Battery Storage<br/>Investment trends"]
        Table -->|Item 4| I4["BC Net-Zero<br/>Provincial policies"]
        Table -->|Item 5| I5["Ontario EV<br/>Infrastructure"]
    end
    
    subgraph ECR["ECR Repository<br/>aws-langchain-web-and-database-search"]
        Image["Docker Image<br/>Tag: latest<br/>Base: python:3.11-slim<br/>Size: ~500MB"]
        
        Image -->|Includes| App["app.py<br/>Flask endpoints<br/>Bedrock integration"]
        Image -->|Includes| ReqFile["requirements.txt<br/>aiohttp, flask,<br/>tenacity, boto3,<br/>langchain modules"]
    end
```

### 5. AI/ML & Bedrock Integration
```mermaid
graph TB
    App["Flask App<br/>call_bedrock()"]
    
    App -->|1. Construct Request| ReqBody["Request Body<br/>{<br/>  anthropic_version: bedrock-2023-05-31<br/>  max_tokens: 512<br/>  messages: [{<br/>    role: user<br/>    content: [{<br/>      type: text<br/>      text: prompt<br/>    }]<br/>  }]<br/>}"]
    
    ReqBody -->|2. Invoke| BedRock["AWS Bedrock<br/>bedrock-runtime client<br/>invoke_model()"]
    
    BedRock -->|Use| Profile["Inference Profile<br/>arn:aws:bedrock:us-east-1:...<br/>:inference-profile/<br/>us.anthropic.claude-haiku-4-5-20251001-v1:0"]
    
    Profile -->|Route to| Model["Claude Haiku 4.5<br/>Latest Model<br/>Fast & Cost-effective<br/>On-demand throughput"]
    
    Model -->|3. Process| Process["Model Processing<br/>- Tokenize input<br/>- Generate tokens<br/>- Apply constraints"]
    
    Process -->|4. Return| Response["Response Body<br/>{<br/>  model: haiku-...<br/>  id: msg_...<br/>  content: [{<br/>    type: text<br/>    text: summary<br/>  }]<br/>  usage: {...}<br/>}"]
    
    Response -->|5. Parse| Extract["Extract Summary<br/>response['body'].read()<br/>json.loads()<br/>response['content'][0]['text']"]
    
    Extract -->|6. Return| AppReturn["Return to Flask<br/>For JSON response"]
```

## Detailed Application Flow in Fargate

```mermaid
graph TD
    Start["Container Start"] -->|Set Env| EnvVars["Load Environment:<br/>- BEDROCK_MODEL_ID<br/>- AWS_REGION<br/>- DDB_TABLE"]
    
    EnvVars -->|Init| BotoInit["Initialize AWS Clients:<br/>- bedrock-runtime<br/>- dynamodb<br/>- aiohttp session"]
    
    BotoInit -->|Start| Flask["Start Flask App<br/>Debug: False<br/>Port: 80<br/>Host: 0.0.0.0"]
    
    Flask -->|Ready| Ready["App Ready<br/>Listening for requests"]
    
    Ready -->|Route| HealthRoute["/health endpoint<br/>GET /health"]
    Ready -->|Route| SummarizeRoute["/summarize endpoint<br/>POST /summarize"]
    
    HealthRoute -->|Handler| HealthHandler["Health Check Handler<br/>Return {status: ok}"]
    
    SummarizeRoute -->|Handler| ParseJSON["Parse JSON Request<br/>Extract 'topic' field<br/>Use force=True<br/>for flexibility"]
    
    ParseJSON -->|Validate| Validate{Topic<br/>Valid?}
    
    Validate -->|No| Error400["Return 400 Error<br/>Invalid JSON"]
    Validate -->|Yes| DBSearch["Search DynamoDB<br/>ddb_search_similar(topic)"]
    
    DBSearch -->|Scan| DDBScan["DynamoDB Scan<br/>Filter items<br/>by topic match"]
    
    DDBScan -->|Parse| DBResults["Parse Results<br/>Extract text<br/>Build list"]
    
    DBResults -->|Check| SerpCheck{SerpAPI<br/>Key Set?}
    
    SerpCheck -->|No| SkipWeb["Skip Web Search<br/>web_results = []"]
    SerpCheck -->|Yes| WebSearch["Run Web Search<br/>asyncio.run(<br/>run_concurrent_searches())"]
    
    WebSearch -->|Async| WS1["Search 1<br/>aiohttp GET"]
    WebSearch -->|Async| WS2["Search 2<br/>aiohttp GET"]
    WS1 -->|Gather| WSGather["Gather Results<br/>Parse JSON"]
    WS2 --> WSGather
    
    SkipWeb --> Combine["Combine Results<br/>db_results + web_results<br/>Max 10 items"]
    WSGather --> Combine
    
    Combine -->|Check| HasResults{Any<br/>Results?}
    
    HasResults -->|No| NoInfo["Set summary<br/>= No information found"]
    
    HasResults -->|Yes| BuildPrompt["Build Prompt<br/>Topic: {topic}<br/>Context: {results}<br/>Instruction:<br/>Provide concise<br/>summary 2-3 sentences"]
    
    BuildPrompt -->|Call| Bedrock["Call Bedrock<br/>@retry decorator<br/>Max 3 attempts<br/>Exponential backoff"]
    
    Bedrock -->|Success| Summary["Extract Summary<br/>from response"]
    Bedrock -->|Fail| BedError["Handle Error<br/>Return error message<br/>as summary"]
    
    Summary --> Format["Format Response<br/>{<br/>  topic: ...<br/>  summary: ...<br/>  db_count: ...<br/>  web_count: ...<br/>}"]
    
    BedError --> Format
    NoInfo --> Format
    Error400 --> Format
    
    Format -->|Return| HTTP["HTTP 200<br/>Content-Type: application/json<br/>Return JSON"]
    
    HTTP -->|Send| ALB["ALB receives<br/>response"]
    
    ALB -->|Forward| Client["Client receives<br/>JSON response"]
    
    Client -->|Done| End["Request Complete<br/>Task ready for<br/>next request"]
```

## Error Handling & Retry Logic

```mermaid
graph TD
    Call["Bedrock Call<br/>invoke_model()"]
    
    Call -->|Try 1| Attempt1["Attempt 1<br/>Wait 1-2s"]
    
    Attempt1 -->|Success| Return["✅ Return Response"]
    Attempt1 -->|Exception| Check1{Is<br/>Exception?}
    
    Check1 -->|Yes| Wait1["Wait exponential<br/>min=1s, max=10s"]
    Check1 -->|No| Return
    
    Wait1 --> Attempt2["Attempt 2<br/>Wait 2-4s"]
    
    Attempt2 -->|Success| Return
    Attempt2 -->|Exception| Check2{Is<br/>Exception?}
    
    Check2 -->|Yes| Wait2["Wait exponential<br/>min=1s, max=10s"]
    Check2 -->|No| Return
    
    Wait2 --> Attempt3["Attempt 3<br/>Wait 4-8s"]
    
    Attempt3 -->|Success| Return
    Attempt3 -->|Exception| Check3{Is<br/>Exception?}
    
    Check3 -->|Yes| Fail["❌ Raise RetryError<br/>Extract last exception"]
    Check3 -->|No| Return
    
    Fail -->|Extract| FinalError["Extract inner<br/>exception details<br/>from RetryError"]
    
    FinalError -->|Return| ErrorMsg["Return error message<br/>BEDROCK_ERROR:<br/>ValidationException:<br/>..."]
    
    Return -->|User| Success["User gets<br/>summary"]
    ErrorMsg -->|User| Error["User gets<br/>error in summary field"]
```

## Infrastructure as Code (IaC) Organization

```mermaid
graph TB
    IaC["Infrastructure as Code<br/>OpenTofu/Terraform"]
    
    IaC -->|locals.tf| Locals["Configuration<br/>- project_name<br/>- region<br/>- resource names<br/>- bedrock_model_id<br/>- common_tags"]
    
    IaC -->|provider.tf| Provider["AWS Provider<br/>- Region<br/>- Default tags"]
    
    IaC -->|data.tf| Data["Data Sources<br/>- AWS Availability Zones"]
    
    IaC -->|vpc.tf| VPC["VPC & Networking<br/>- VPC (10.0.0.0/16)<br/>- Public Subnets<br/>- IGW<br/>- Route Tables<br/>- Security Group"]
    
    IaC -->|ecr.tf| ECR["ECR & Docker<br/>- ECR Repository<br/>- Local files (app.py, Dockerfile)<br/>- Build & Push provisioner<br/>- DynamoDB populate"]
    
    IaC -->|bedrock.tf| Bedrock["Bedrock Setup<br/>- AWS Account data<br/>- Inference Profile ARN<br/>- Output ARN for fargate"]
    
    IaC -->|fargate.tf| Fargate["ECS Fargate<br/>- ECS Cluster<br/>- Task Definition<br/>- IAM Roles/Policies<br/>- ECS Service<br/>- ALB & Target Group<br/>- CloudWatch Logs"]
    
    IaC -->|dynamo.tf| DynamoDB["DynamoDB<br/>- Table definition<br/>- Populate with data<br/>via local-exec"]
    
    IaC -->|output.tf| Output["Terraform Outputs<br/>- ALB DNS<br/>- API endpoints<br/>- Resource names"]
    
    Locals --> Fargate
    Locals --> VPC
    Locals --> ECR
    Locals --> DynamoDB
    Locals --> Bedrock
    Provider --> All["All Resources"]
    Data --> VPC
```

## Deployment Sequence

```mermaid
sequenceDiagram
    participant User as User
    participant TF as OpenTofu
    participant AWS as AWS Services
    
    User->>TF: tofu apply -auto-approve
    
    activate TF
    TF->>AWS: Create VPC
    TF->>AWS: Create Subnets (2)
    TF->>AWS: Create IGW & Route Table
    TF->>AWS: Create Security Group
    TF->>AWS: Create ECR Repository
    
    Note over TF,AWS: Build & Push Phase
    TF->>AWS: Build Docker Image
    TF->>AWS: Tag Image
    TF->>AWS: Push to ECR
    
    Note over TF,AWS: Database Setup Phase
    TF->>AWS: Create DynamoDB Table
    TF->>AWS: Populate with 5 items
    
    Note over TF,AWS: Compute Setup Phase
    TF->>AWS: Create ECS Cluster
    TF->>AWS: Create IAM Roles
    TF->>AWS: Create Task Definition
    TF->>AWS: Create ALB
    TF->>AWS: Create Target Group
    TF->>AWS: Create ECS Service (2 tasks)
    TF->>AWS: Setup CloudWatch Logs
    
    deactivate TF
    
    Note over AWS: Services Stabilizing
    AWS->>AWS: Task 1 Starts
    AWS->>AWS: Task 2 Starts
    AWS->>AWS: Health Checks Begin
    AWS->>AWS: Targets Healthy
    
    User->>AWS: Ready for requests
```

## Key Metrics & Thresholds

| Component | Metric | Threshold | Action |
|-----------|--------|-----------|--------|
| ALB | Health Check | 200 OK | Target marked Healthy |
| ALB | Health Check Interval | 30s | Every 30 seconds |
| ALB | Unhealthy Threshold | 2 failed checks | Remove from targets |
| ECS Task | CPU | 1024 units (1 vCPU) | Autoscale if exceeded |
| ECS Task | Memory | 2048 MB | Hard limit, OOM if exceeded |
| ECS Service | Desired Count | 2 | Maintain 2 running tasks |
| Bedrock | Retry Attempts | 3 | Maximum retry attempts |
| Bedrock | Backoff | Exponential (1-10s) | Wait between retries |
| DynamoDB | Billing | PAY_PER_REQUEST | Auto-scale read/write |
| CloudWatch | Log Retention | Indefinite | Keep all logs |

---

## Conclusion

This architecture provides:
- ✅ **High Availability**: 2 tasks across 2 AZs
- ✅ **Scalability**: Fargate auto-scaling capability
- ✅ **Reliability**: Health checks, retry logic, error handling
- ✅ **Cost Efficiency**: On-demand pricing for all services
- ✅ **Observability**: CloudWatch Logs integration
- ✅ **AI/ML Integration**: AWS Bedrock with latest Claude Haiku
- ✅ **Infrastructure as Code**: Full OpenTofu management
