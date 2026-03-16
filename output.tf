output "ec2_public_ip" {
  description = "Public IP of the Tomcat app server"
  value       = aws_instance.Ec2Instance.public_ip
}

output "rds_endpoint" {
  description = "RDS MariaDB endpoint"
  value       = aws_db_instance.my_db.address
}

output "app_url" {
  description = "Tomcat app URL"
  value       = "http://${aws_instance.Ec2Instance.public_ip}:8080/student"
}