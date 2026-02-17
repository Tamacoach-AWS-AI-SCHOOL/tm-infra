output "instance_id" {
  value = aws_instance.jump.id
}

output "private_ip" {
  value = aws_instance.jump.private_ip
}

output "security_group_id" {
  value = aws_security_group.jump.id
}

output "role_name" {
  value = local.effective_role_name
}

