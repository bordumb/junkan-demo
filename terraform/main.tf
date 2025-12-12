resource "aws_db_instance" "payment_db" {
  identifier = "payment-db-prod"
  instance_class = "db.t3.micro"
  engine = "postgres"
  username = "dbadmin"
  password = var.db_password
}

# V1 OUTPUT (Safe)
output "payment_db_host" {
  value = aws_db_instance.payment_db.address
  description = "The endpoint for the payment database"
}
