# Bedrock Resources - Inference Profile for Claude Haiku 4.5

# Create an inference profile for Claude Haiku 4.5
# This enables on-demand throughput access to the latest Haiku model
resource "aws_bedrock_inference_profile" "haiku_profile" {
  inference_profile_name = "${local.project_name}-inference-profile"
  
  model_source {
    copy_from = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-inference-profile"
  })
}

# Output the inference profile ARN for use in the application
output "bedrock_inference_profile_arn" {
  value       = aws_bedrock_inference_profile.haiku_profile.inference_profile_arn
  description = "ARN of the Bedrock inference profile for Claude Haiku 4.5"
}
