output "web_server_public_ip" {
  description = "The public IP of the web server"
  value       = aws_instance.web_server.public_ip
}

output "web_server_public_dns" {
  description = "The public DNS name of the web server"
  value       = aws_instance.web_server.public_dns
}

output "db_server_private_ip" {
  description = "The private IP of the database server"
  value       = aws_instance.db_server.private_ip
}
