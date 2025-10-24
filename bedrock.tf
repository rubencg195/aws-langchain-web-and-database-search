# Bedrock Resources - Use System-Defined Inference Profile for Claude Haiku 4.5

# Get current AWS account ID for constructing the inference profile ARN
data "aws_caller_identity" "current" {}

# The Claude Haiku 4.5 system-defined inference profile ARN
# This is pre-created by AWS and supports on-demand throughput across us-east-1, us-east-2, us-west-2
locals {
  bedrock_inference_profile_arn = "arn:aws:bedrock:${local.region}:${data.aws_caller_identity.current.account_id}:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

# Output the inference profile ARN for use in the application
output "bedrock_inference_profile_arn" {
  value       = local.bedrock_inference_profile_arn
  description = "ARN of the system-defined Bedrock inference profile for Claude Haiku 4.5"
}
