# DynamoDB table for knowledge base retrieval

resource "aws_dynamodb_table" "kb_table" {
  name         = local.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = local.dynamodb_table
  })
}

# Populate DynamoDB with sample data
resource "null_resource" "populate_db_local" {
  depends_on = [aws_dynamodb_table.kb_table]

  provisioner "local-exec" {
    command = "python populate_db.py"
    environment = {
      AWS_REGION = local.region
      DDB_TABLE  = aws_dynamodb_table.kb_table.name
    }
  }

  triggers = {
    always_run = timestamp()
  }
}

