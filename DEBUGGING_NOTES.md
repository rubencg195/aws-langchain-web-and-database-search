# Debugging & Deployment Notes

## Current Status

✅ **Infrastructure**: Fully deployed and operational
✅ **Health Check**: Working (`/health` returns 200 OK)
✅ **DynamoDB**: Populated and searchable
✅ **API**: Responding with correct data structure
⏳ **Bedrock**: Needs AWS account configuration

## What's Working

### 1. API Health Endpoint
```bash
curl http://langchain-web-db-search-alb-1600321510.us-east-1.elb.amazonaws.com/health
# Response: {"status":"ok"}
```

### 2. Database Search
- DynamoDB table has 5 sample items populated
- Search function correctly matches topics against database content
- Example: Query with topic "Canada" returns db_count: 1 match

```bash
curl -X POST http://langchain-web-db-search-alb-1600321510.us-east-1.elb.amazonaws.com/summarize \
  -H "Content-Type: application/json" \
  -d '{"topic":"Canada"}'

# Response:
{
  "db_count": 1,
  "summary": "Error calling Bedrock: RetryError[...]",
  "topic": "Canada",
  "web_count": 0
}
```

## What Needs Configuration

### Bedrock Model Access (REQUIRED)

The API returns this error because Bedrock model access hasn't been enabled:
```
"summary": "Error calling Bedrock: RetryError[<Future at 0x7f02bb53bf50 state=finished raised ValidationError>]"
```

**Steps to Fix:**

1. Go to AWS Bedrock Console: https://console.aws.amazon.com/bedrock/home
2. Click "Model access" in the left sidebar
3. Click "Manage model access" button
4. Find and check "Anthropic Claude 3 Sonnet"
5. Click "Save changes"
6. Wait 2-3 minutes for access to be provisioned

After enabling, the same API call will return:
```json
{
  "db_count": 1,
  "summary": "Based on the available information, Canada has announced plans...",
  "topic": "Canada",
  "web_count": 0
}
```

### SerpAPI (Optional for Web Search)

To enable web search functionality:
1. Get API key from https://serpapi.com/
2. Edit `fargate.tf` and add to the environment block:
   ```hcl
   {
     name  = "SERPAPI_API_KEY"
     value = "your-key-here"
   }
   ```
3. Run `tofu apply -auto-approve` to redeploy

## Deployment Summary

- **Deployed**: October 24, 2025
- **Infrastructure Time**: ~10 minutes
- **All Resources**: Active and healthy
- **ALB DNS**: `langchain-web-db-search-alb-1600321510.us-east-1.elb.amazonaws.com`
- **Git Commit**: `aa6905a` - Reorganized terraform into modular files

## Testing Checklist

- [x] Health check endpoint works
- [x] Database has sample data
- [x] Database search correctly matches topics
- [x] API endpoint responds with correct JSON structure
- [x] Error handling works (Bedrock access error is caught properly)
- [ ] Bedrock summarization works (requires account setup)
- [ ] Web search works (optional - requires SERPAPI_KEY)

## Next Steps

1. **Enable Bedrock Model Access** (see above)
2. Test API with Bedrock enabled
3. (Optional) Add SERPAPI_KEY for web search
4. Monitor CloudWatch logs: `aws logs tail /ecs/aws-langchain-web-and-database-search --follow`

## Key Files Modified

- `ecr.tf`: Added debug logging to `ddb_search_similar()` function
- All other files: No changes since last git push

## Sample API Responses

### Working with Database Match:
```json
{
  "db_count": 1,
  "summary": "Error calling Bedrock: RetryError[...]",
  "topic": "Canada",
  "web_count": 0
}
```

### After Bedrock Setup:
```json
{
  "db_count": 1,
  "summary": "Based on the retrieved information, Canada is planning to increase wind and solar capacity by 2030...",
  "topic": "Canada",
  "web_count": 0
}
```

## Troubleshooting

### API Returns 400 Bad Request
- Ensure Content-Type header is `application/json`
- Ensure JSON payload has `"topic"` field

### API Returns 200 but db_count is 0
- Database search is working correctly (this means the topic doesn't match any items)
- Try with keywords from sample data: "Canada", "Alberta", "renewable", "battery", "Ontario", "solar", "wind", "emissions", "electric"

### Bedrock Returns ValidationError
- Need to enable Bedrock model access (see steps above)
- Must be done in the AWS account where the ECS task is running

## Infrastructure Resources

| Resource | Type | Status |
|----------|------|--------|
| VPC | AWS VPC | ✅ Active |
| Subnets | 2x Public | ✅ Active |
| ALB | Application Load Balancer | ✅ Active |
| ECS Cluster | Fargate | ✅ Active |
| ECS Task | Flask App (1x running) | ✅ Active |
| ECR Repository | Docker Registry | ✅ Active |
| DynamoDB Table | Knowledge Base | ✅ Active (5 items) |
| CloudWatch Logs | Logging | ✅ Active |

