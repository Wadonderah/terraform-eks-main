data "aws_availability_zones" "available" {
  state = "available"
}

# Generate secure random password for Aurora MySQL
resource "random_password" "aurora_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "aurora_password" {
  name        = "${var.lambda_aurora_mysql_name}-master-password"
  description = "Master password for Aurora MySQL cluster"
  
  tags = {
    Environment = "production"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "aurora_password" {
  secret_id     = aws_secretsmanager_secret.aurora_password.id
  secret_string = random_password.aurora_password.result
}

resource "aws_rds_cluster" "lambda_aurora_mysql" {
  cluster_identifier      = var.lambda_aurora_mysql_name
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.04.0"  # Updated to latest stable version
  availability_zones      = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  database_name           = var.lambda_aurora_mysql_database_name
  master_username         = "invoice"
  master_password         = random_password.aurora_password.result
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  
  # Enable encryption at rest
  storage_encrypted = true
  
  # Enable deletion protection for production
  deletion_protection = false  # Set to true for production
  
  # Skip final snapshot for development (change for production)
  skip_final_snapshot = true
  
  tags = {
    Environment = "production"
    Application = "invoice-automation"
    ManagedBy   = "terraform"
  }
}