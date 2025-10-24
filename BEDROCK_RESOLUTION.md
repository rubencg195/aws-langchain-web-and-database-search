# Bedrock Integration Resolution

## Problem Summary

The initial deployment encountered an issue with Claude Haiku 4.5 on-demand throughput:
```
ValidationException: Invocation of model ID anthropic.claude-haiku-4-5-20251001-v1:0 
with on-demand throughput isn't supported. Retry your request with the ID or ARN 
of an inference profile that contains this model.
```

## Root Cause

AWS Bedrock requires an **inference profile ARN** for certain models to support on-demand throughput. An inference profile is a container that provides consistent, cross-region model access.

## Solution: System-Defined Inference Profiles

AWS provides pre-built, system-defined inference profiles for all major models. These don't require manual creation—they're automatically available in your account.

### What Changed

**Before** (Manual Attempt):
- Tried to create custom inference profile with AWS CLI
- Used wrong ARN format: `application-inference-profile/...`
- Inconsistent API version handling

**After** (System-Defined):
- Uses AWS's system-defined inference profile
- Correct ARN format: `inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0`
- Consistent, tested API version: `bedrock-2023-05-31`

### File Changes

#### `bedrock.tf`
```hcl
# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Use system-defined inference profile ARN
locals {
  bedrock_inference_profile_arn = "arn:aws:bedrock:${local.region}:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

output "bedrock_inference_profile_arn" {
  value       = local.bedrock_inference_profile_arn
  description = "ARN of the system-defined Bedrock inference profile for Claude Haiku 4.5"
}
```

#### `fargate.tf`
```hcl
# Task definition environment variable
{
  name  = "BEDROCK_MODEL_ID"
  value = local.bedrock_inference_profile_arn
}
```

#### `ecr.tf` (app.py)
```python
request_body = {
    "anthropic_version": "bedrock-2023-05-31",
    "max_tokens": 512,
    "messages": [
        {
            "role": "user",
            "content": [{"type": "text", "text": prompt}]
        }
    ]
}
```

## Key Insights

1. **Inference Profile ARN Format**: `arn:aws:bedrock:REGION:ACCOUNT_ID:inference-profile/MODEL_NAME:VERSION`
2. **System-Defined vs Custom**: AWS's system profiles are optimized and pre-tested
3. **API Version Matters**: Use `bedrock-2023-05-31` for Anthropic models
4. **Content Structure**: Messages must use `[{"type": "text", "text": "..."}]` format

## Testing

Created `bedrock-test.py` for local validation before Fargate deployment:

```python
# Test with system-defined inference profile
BEDROCK_MODEL_ID = "arn:aws:bedrock:us-east-1:176843580427:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"

# All 3 tests passed:
# ✅ Basic Prompt Test
# ✅ Summarization Test  
# ✅ Error Handling Test
```

## Results

### Before Fix
```json
{
  "summary": "BEDROCK_ERROR: ...",
  "db_count": 1,
  "web_count": 0
}
```

### After Fix
```json
{
  "summary": "# Canada's Renewable Energy Expansion\n\nCanada is planning to significantly increase its wind and solar energy capacity by 2030 as part of its commitment to clean energy and climate goals...",
  "db_count": 1,
  "web_count": 0
}
```

## Available System-Defined Inference Profiles

All of these are automatically available in your account:

- `us.anthropic.claude-haiku-4-5-20251001-v1:0` (Latest, fastest, most cost-effective) ✅
- `us.anthropic.claude-3-sonnet-20240229-v1:0` (Balanced capability and speed)
- `us.anthropic.claude-3-opus-20240229-v1:0` (Most capable, slowest)
- `us.meta.llama3-70b-instruct-v1:0` (Open-source alternative)
- `us.mistral.mistral-large-2402-v1:0` (Mistral's large model)

## Future Enhancements

To change models, simply update the inference profile ARN:

```hcl
# In bedrock.tf
bedrock_inference_profile_arn = "arn:aws:bedrock:us-east-1:ACCOUNT_ID:inference-profile/us.anthropic.claude-3-sonnet-20240229-v1:0"
```

Then redeploy: `tofu apply -auto-approve`

## Lessons Learned

1. **Always check AWS documentation** - System profiles are the recommended approach
2. **Local testing is critical** - bedrock-test.py caught issues before Fargate deployment
3. **Inference profiles are powerful** - They abstract away regional complexity
4. **API format matters** - The message structure must match the API version specification
