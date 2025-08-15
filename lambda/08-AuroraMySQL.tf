data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_rds_cluster" "lambda_aurora_mysql" {
  cluster_identifier      = var.lambda_aurora_mysql_name
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.11.2"
  availability_zones      = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1], data.aws_availability_zones.available.names[2]]
  database_name           = var.lambda_aurora_mysql_database_name
  master_username         = "invoice"
  master_password         = "Invoice1234"
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
}