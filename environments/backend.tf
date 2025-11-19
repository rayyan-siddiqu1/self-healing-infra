# ==================================
# Terraform Backend Configuration
# ==================================
# This configures remote state storage in S3 with DynamoDB locking
# Uncomment and configure after creating the S3 bucket and DynamoDB table

terraform {
  backend "s3" {
    bucket         = "self-healing-infra-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# To create the backend resources, run:
#
# aws s3 mb s3://self-healing-infra-terraform-state --region us-east-1
# aws s3api put-bucket-versioning \
#   --bucket self-healing-infra-terraform-state \
#   --versioning-configuration Status=Enabled
# aws s3api put-bucket-encryption \
#   --bucket self-healing-infra-terraform-state \
#   --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
#
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1
