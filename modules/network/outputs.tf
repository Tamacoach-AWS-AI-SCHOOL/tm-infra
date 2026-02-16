output "db_subnet_ids" {
  description = "New DB subnet IDs"
  value       = values(aws_subnet.db)[*].id
}

output "db_route_table_ids" {
  description = "DB route table IDs"
  value       = values(aws_route_table.db)[*].id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs"
  value       = values(aws_nat_gateway.this)[*].id
}

output "nlb_dev_sg_id" {
  value = aws_security_group.nlb_dev.id
}

output "nlb_prod_sg_id" {
  value = aws_security_group.nlb_prod.id
}

output "eks_nodes_dev_sg_id" {
  value = aws_security_group.eks_nodes_dev.id
}

output "eks_nodes_prod_sg_id" {
  value = aws_security_group.eks_nodes_prod.id
}

output "rds_dev_sg_id" {
  value = aws_security_group.rds_dev.id
}

output "rds_prod_sg_id" {
  value = aws_security_group.rds_prod.id
}

output "vpce_s3_id" {
  value = aws_vpc_endpoint.s3_gateway.id
}

output "vpce_interface_ids" {
  value = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

output "vpc_id" {
  value = var.vpc_id
}

output "public_subnet_ids" {
  value = var.public_subnet_ids
}

output "private_subnet_ids" {
  description = "DEPRECATED: dev private subnet IDs. Use private_subnet_ids_dev/private_subnet_ids_prod."
  value       = var.private_subnet_ids
}

output "private_subnet_ids_dev" {
  description = "Existing dev private subnet IDs"
  value       = values(data.aws_subnet.private_dev)[*].id
}

output "private_subnet_ids_prod" {
  description = "New prod private subnet IDs"
  value       = values(aws_subnet.private_prod)[*].id
}

output "s3_gateway_vpce_id" {
  value = aws_vpc_endpoint.s3_gateway.id
}

output "sg_ids" {
  value = {
    vpce     = aws_security_group.vpce.id
    nlb_dev  = aws_security_group.nlb_dev.id
    nlb_prod = aws_security_group.nlb_prod.id
    eks_dev  = aws_security_group.eks_nodes_dev.id
    eks_prod = aws_security_group.eks_nodes_prod.id
    rds_dev  = aws_security_group.rds_dev.id
    rds_prod = aws_security_group.rds_prod.id
  }
}
