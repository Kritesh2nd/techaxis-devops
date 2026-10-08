output "jenkins_public_ip" {
  value = aws_instance.kritesh_jenkins_server.public_ip
}

output "jenkins_public_dns" {
  value = aws_instance.kritesh_jenkins_server.public_dns
}

output "deployment_public_ip" {
  value = aws_instance.kritesh_deployment_server.public_ip
}

output "deployment_public_dns" {
  value = aws_instance.kritesh_deployment_server.public_dns
}

output "monitoring_public_ip" {
  value = aws_instance.kritesh_monitoring_server.public_ip
}

output "monitoring_public_dns" {
  value = aws_instance.kritesh_monitoring_server.public_dns
}

output "monitoring_private_ip" {
  value = aws_instance.kritesh_monitoring_server.private_ip
}

output "loki_url" {
  value = "http://${aws_instance.kritesh_monitoring_server.private_ip}:3100"
}

output "ssh_key_name" {
  value = aws_key_pair.ssh_key.key_name
}

output "private_key_file" {
  value = local_file.private_key.filename
}

output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.kritesh_jenkins_server.id
}

output "deployment_instance_id" {
  description = "Deployment EC2 instance ID"
  value       = aws_instance.kritesh_deployment_server.id
}

output "monitoring_instance_id" {
  description = "Monitoring EC2 instance ID"
  value       = aws_instance.kritesh_monitoring_server.id
}
