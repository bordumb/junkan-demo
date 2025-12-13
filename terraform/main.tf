resource "aws_db_instance" "payment_db" {
  identifier = "payment-db-prod"
  instance_class = "db.t3.micro"
  engine = "postgres"
  username = "dbadmin"
  password = var.db_password
}

# BREAKING CHANGE: Renamed output. App will break because it expects 'payment_db_host'
output "payment_database_endpoint" {
  value = aws_db_instance.payment_db.address
  description = "The endpoint for the payment database"
}
