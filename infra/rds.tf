# Infrastructure Definition
# Scenario: This resource provides the host for the Payment Service.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# The Critical Resource
# Junkan will stitch this to the Python app via the 'identifier' or name tokens.
resource "aws_db_instance" "payments_db" {
  identifier           = "payments-production-db"
  allocated_storage    = 100
  db_name              = "payments"
  engine               = "postgres"
  engine_version       = "14"
  instance_class       = "db.t3.medium"
  username             = "admin"
  password             = "super-secret-password" # In reality, use Secrets Manager
  skip_final_snapshot  = true
  
  tags = {
    Environment = "Production"
    Service     = "PaymentService"
    Critical    = "True"
  }
}