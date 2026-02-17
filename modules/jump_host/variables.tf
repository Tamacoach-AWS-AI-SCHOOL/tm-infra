variable "project" {
  type        = string
  description = "Project identifier for naming."
}

variable "env" {
  type        = string
  description = "Environment name (dev/prod)."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where jump host is deployed."
}

variable "subnet_id" {
  type        = string
  description = "Private subnet ID where jump host is deployed."
}

variable "additional_sg_ids" {
  type        = list(string)
  description = "Optional additional security group IDs."
  default     = []
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for jump host."
  default     = "t3.small"
}

variable "ami_id" {
  type        = string
  description = "Optional AMI ID override. If empty, latest Amazon Linux 2023 AMI is used."
  default     = ""
}

variable "existing_instance_profile_name" {
  type        = string
  description = "Optional existing instance profile name. If null, module creates role/profile."
  default     = null
}

variable "eks_cluster_arn" {
  type        = string
  description = "EKS cluster ARN for least-privilege eks:DescribeCluster."
}

variable "install_helm" {
  type        = bool
  description = "Install helm in user data."
  default     = false
}

variable "kubectl_version" {
  type        = string
  description = "kubectl version to install."
  default     = "1.30.0"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
