output "postgres_address" {
  description = "Endpoint of new PostgreSQL DB"
  value       = aws_db_instance.postgres_db.address
}

output "mssql_address" {
  description = "Endpoint of new MSSQL DB"
  value       = aws_db_instance.mssql_db.address
}