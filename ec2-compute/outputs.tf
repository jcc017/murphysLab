output "win_prv_ip" {
  description = "Private IP address of new Windows Server"
  value       = aws_instance.win_srv.private_ip
}

output "unix_prv_ip" {
  description = "Private IP address of new Unix Server"
  value       = aws_instance.unix_srv.private_ip
}
