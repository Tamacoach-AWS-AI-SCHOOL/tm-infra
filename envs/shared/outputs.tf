output "ssm_shared_prefix" {
  description = "SSM base prefix for shared stack"
  value       = local.ssm_shared_prefix
}

output "ssm_network_prefix" {
  description = "SSM network-only prefix for shared stack"
  value       = local.ssm_network_prefix
}
