# Suffixe aléatoire pour garantir l'unicité du nom du bucket
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket pour stocker le state Terraform
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${random_string.suffix.result}"
  
  tags = {
    Name        = "${var.project_name} Terraform State"
    Environment = var.environment
    Company     = "HopeSystem"
    ManagedBy   = "Terraform"
  }
}

# Activation du versioning pour garder l'historique des states
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement du bucket pour la sécurité
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Blocage de l'accès public (bonne pratique de sécurité)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Table DynamoDB pour les verrous Terraform
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${var.project_name}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "${var.project_name} Terraform State Locking"
    Company   = "HopeSystem"
    ManagedBy = "Terraform"
  }
}

