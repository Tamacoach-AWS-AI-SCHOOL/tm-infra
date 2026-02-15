variable "project" {
  type        = string
  description = "Project name used in resource naming"
  default     = "tamacoach"
}

variable "stack_env" {
  type        = string
  description = "Stack environment tag value (shared/dev/prod)"
  default     = "shared"
}

variable "owner" {
  type        = string
  description = "Owner tag value"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Existing public subnet IDs (2) used for NAT placement"

  validation {
    condition     = length(var.public_subnet_ids) == 2
    error_message = "public_subnet_ids must contain exactly 2 subnet IDs."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Existing private subnet IDs (2) for EKS nodes and interface endpoints"

  validation {
    condition     = length(var.private_subnet_ids) == 2
    error_message = "private_subnet_ids must contain exactly 2 subnet IDs."
  }
}

variable "private_route_table_ids" {
  type        = list(string)
  description = "Existing private route table IDs (1~2)"

  validation {
    condition     = length(var.private_route_table_ids) >= 1
    error_message = "private_route_table_ids must contain at least 1 route table ID."
  }
}

variable "db_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for new DB subnets (2, non-overlapping with existing subnets)"

  validation {
    condition     = length(var.db_subnet_cidrs) == 2
    error_message = "db_subnet_cidrs must contain exactly 2 CIDR blocks."
  }
}

variable "db_subnet_azs" {
  type        = list(string)
  description = "Availability zones for DB subnets (2)"

  validation {
    condition     = length(var.db_subnet_azs) == 2
    error_message = "db_subnet_azs must contain exactly 2 availability zones."
  }
}

variable "nat_mode" {
  type        = string
  description = "NAT deployment mode: ha or single"
  default     = "ha"

  validation {
    condition     = contains(["ha", "single"], var.nat_mode)
    error_message = "nat_mode must be one of: ha, single."
  }
}

variable "backend_port" {
  type        = number
  description = "Backend service port exposed from EKS nodes"
  default     = 8000
}

variable "db_port" {
  type        = number
  description = "Database port"
  default     = 5432
}

variable "flow_logs_retention_days" {
  type        = number
  description = "CloudWatch Logs retention for VPC Flow Logs"
  default     = 30
}

variable "gitlab_instance_id" {
  type        = string
  description = "Optional existing GitLab EC2 instance ID to reference as data only"
  default     = null
}
