# Bedrock Resources - Inference Profile for Claude Haiku 4.5

# Create an inference profile using AWS CLI since Terraform doesn't support it yet
resource "null_resource" "bedrock_inference_profile" {
  provisioner "local-exec" {
    command = <<-EOT
      aws bedrock create-inference-profile \
        --inference-profile-name "${local.project_name}-inference-profile" \
        --model-source copyFrom=arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0 \
        --region ${local.region} 2>/dev/null || echo "Inference profile may already exist"
    EOT
  }

  triggers = {
    profile_name = local.project_name
  }
}

# Local variable to store the inference profile ARN
# The ARN format is predictable based on AWS account ID and profile name
locals {
  bedrock_inference_profile_arn = "arn:aws:bedrock:${local.region}:${data.aws_caller_identity.current.account_id}:application-inference-profile/${local.project_name}-inference-profile"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Output the inference profile ARN for use in the application
output "bedrock_inference_profile_arn" {
  value       = local.bedrock_inference_profile_arn
  description = "ARN of the Bedrock inference profile for Claude Haiku 4.5"
  depends_on  = [null_resource.bedrock_inference_profile]
}
