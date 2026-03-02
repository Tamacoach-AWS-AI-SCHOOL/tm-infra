data "aws_region" "current" {}

data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_subnet" "public" {
  for_each = toset(var.public_subnet_ids)
  id       = each.value
}

data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

data "aws_subnet" "private_dev" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

data "aws_route_table" "private" {
  for_each       = toset(var.private_route_table_ids)
  route_table_id = each.value
}

data "aws_instance" "gitlab" {
  count       = var.gitlab_instance_id == null ? 0 : 1
  instance_id = var.gitlab_instance_id
}

locals {
  shared_env            = var.stack_env
  naming_project_prefix = var.resource_naming_project != "" ? var.resource_naming_project : var.project

  nat_subnet_map = var.nat_mode == "ha" ? {
    for idx, subnet_id in var.public_subnet_ids : tostring(idx) => subnet_id
    } : {
    "0" = var.public_subnet_ids[0]
  }

  private_rt_map = {
    for idx, route_table_id in var.private_route_table_ids : tostring(idx) => route_table_id
  }

  db_subnet_map = {
    for idx, cidr in var.db_subnet_cidrs : tostring(idx) => {
      cidr = cidr
      az   = var.db_subnet_azs[idx]
    }
  }

  private_prod_subnet_map = {
    for idx, cidr in var.prod_private_subnet_cidrs : tostring(idx) => {
      cidr = cidr
      az   = var.prod_private_subnet_azs[idx]
    }
  }

  interface_endpoint_services = {
    ecr_api                   = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
    ecr_dkr                   = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
    logs                      = "com.amazonaws.${data.aws_region.current.name}.logs"
    ssm                       = "com.amazonaws.${data.aws_region.current.name}.ssm"
    ssmmessages               = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
    ec2messages               = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
    secretsmanager            = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
    bedrock_runtime           = "com.amazonaws.${data.aws_region.current.name}.bedrock-runtime"
    bedrock_agentcore         = "com.amazonaws.${data.aws_region.current.name}.bedrock-agentcore"
    bedrock_agentcore_gateway = "com.amazonaws.${data.aws_region.current.name}.bedrock-agentcore.gateway"
  }
}

# NOTE: Existing resources may show in-place tag updates in plan as this module
# transitions to StackEnv(default_tags) + Environment(resource tag).

resource "aws_eip" "nat" {
  for_each = local.nat_subnet_map
  domain   = "vpc"

  tags = {
    Environment = "shared"
  }
}

resource "aws_nat_gateway" "this" {
  for_each      = local.nat_subnet_map
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value

  depends_on = [data.aws_subnet.public]

  tags = {
    Environment = "shared"
  }
}

resource "aws_subnet" "db" {
  for_each = local.db_subnet_map

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "${local.naming_project_prefix}-${local.shared_env}-db-subnet-${tonumber(each.key) + 1}"
    Environment = "shared"
  }
}

resource "aws_route_table" "db" {
  for_each = local.db_subnet_map
  vpc_id   = var.vpc_id

  tags = {
    Name        = "${local.naming_project_prefix}-${local.shared_env}-db-rt-${tonumber(each.key) + 1}"
    Environment = "shared"
  }
}

resource "aws_route_table_association" "db" {
  for_each       = local.db_subnet_map
  subnet_id      = aws_subnet.db[each.key].id
  route_table_id = aws_route_table.db[each.key].id
}

resource "aws_subnet" "private_prod" {
  for_each = local.private_prod_subnet_map

  vpc_id                  = var.vpc_id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = {
    Name        = "${local.naming_project_prefix}-shared-private-prod-${each.value.az}"
    Environment = "shared"
    Project     = var.project
  }

  # Subnet workload tags are owned by env stacks (aws_ec2_tag), not shared subnet resource.
  lifecycle {
    ignore_changes = [
      tags["karpenter.sh/discovery"],
      tags["kubernetes.io/cluster/eks-prod"],
      tags["kubernetes.io/role/internal-elb"],
    ]
  }
}

resource "aws_route_table_association" "private_prod" {
  for_each = local.private_prod_subnet_map

  subnet_id      = aws_subnet.private_prod[each.key].id
  route_table_id = var.private_route_table_ids[tonumber(each.key) % length(var.private_route_table_ids)]
}

# If a target route table already has 0.0.0.0/0, this resource can conflict.
# In that case, import the existing route into state or remove/replace the existing route first.
resource "aws_route" "private_default_to_nat" {
  for_each = local.private_rt_map

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = (
    var.nat_mode == "ha"
    ? aws_nat_gateway.this[tostring(tonumber(each.key) % length(var.public_subnet_ids))].id
    : aws_nat_gateway.this["0"].id
  )
}

# If a target route table already has 0.0.0.0/0, this resource can conflict.
# In that case, import the existing route into state or remove/replace the existing route first.
resource "aws_route" "db_default_to_nat" {
  for_each = local.db_subnet_map

  route_table_id         = aws_route_table.db[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = (
    var.nat_mode == "ha"
    ? aws_nat_gateway.this[each.key].id
    : aws_nat_gateway.this["0"].id
  )
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(var.private_route_table_ids, values(aws_route_table.db)[*].id)

  tags = {
    Environment = "shared"
  }
}

resource "aws_security_group" "vpce" {
  name        = "${local.naming_project_prefix}-${local.shared_env}-vpce-sg"
  description = "Interface endpoint SG"
  vpc_id      = var.vpc_id

  tags = {
    Environment = "shared"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_https_from_vpc" {
  security_group_id = aws_security_group.vpce.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = data.aws_vpc.existing.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "vpce_all_egress" {
  security_group_id = aws_security_group.vpce.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = var.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = {
    Environment = "shared"
  }
}

data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${local.naming_project_prefix}-${local.shared_env}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json

  tags = {
    Environment = "shared"
  }
}

data "aws_iam_policy_document" "flow_logs_to_cw" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_logs_to_cw" {
  name   = "${local.naming_project_prefix}-${local.shared_env}-vpc-flow-logs-policy"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_to_cw.json
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${local.naming_project_prefix}-${local.shared_env}"
  retention_in_days = var.flow_logs_retention_days

  tags = {
    Environment = "shared"
  }
}

resource "aws_flow_log" "vpc" {
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = {
    Name        = "${local.naming_project_prefix}-${local.shared_env}-vpc-flow-log"
    Environment = "shared"
  }
}

resource "aws_security_group" "nlb_dev" {
  name        = "${local.naming_project_prefix}-dev-nlb-sg"
  description = "NLB SG for dev"
  vpc_id      = var.vpc_id

  tags = {
    Environment = "dev"
  }
}

resource "aws_security_group" "nlb_prod" {
  name        = "${local.naming_project_prefix}-prod-nlb-sg"
  description = "NLB SG for prod"
  vpc_id      = var.vpc_id

  tags = {
    Environment = "prod"
  }
}

resource "aws_security_group" "eks_nodes_dev" {
  name        = "${local.naming_project_prefix}-dev-eks-nodes-sg"
  description = "EKS nodes SG for dev"
  vpc_id      = var.vpc_id

  tags = {
    Environment = "dev"
  }
}

resource "aws_security_group" "eks_nodes_prod" {
  name        = "${local.naming_project_prefix}-prod-eks-nodes-sg"
  description = "EKS nodes SG for prod"
  vpc_id      = var.vpc_id

  tags = {
    Environment = "prod"
  }
}

resource "aws_security_group" "rds_dev" {
  name        = "${local.naming_project_prefix}-dev-rds-sg"
  description = "RDS SG for dev"
  vpc_id      = var.vpc_id

  tags = {
    Environment = "dev"
  }
}

resource "aws_security_group" "rds_prod" {
  name        = "${local.naming_project_prefix}-prod-rds-sg"
  description = "RDS SG for prod"
  vpc_id      = var.vpc_id

  tags = {
    Environment = "prod"
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks_dev_from_nlb_dev_backend" {
  security_group_id            = aws_security_group.eks_nodes_dev.id
  referenced_security_group_id = aws_security_group.nlb_dev.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_port
  to_port                      = var.backend_port
}

resource "aws_vpc_security_group_ingress_rule" "eks_prod_from_nlb_prod_backend" {
  security_group_id            = aws_security_group.eks_nodes_prod.id
  referenced_security_group_id = aws_security_group.nlb_prod.id
  ip_protocol                  = "tcp"
  from_port                    = var.backend_port
  to_port                      = var.backend_port
}

resource "aws_vpc_security_group_ingress_rule" "rds_dev_from_eks_dev_db" {
  security_group_id            = aws_security_group.rds_dev.id
  referenced_security_group_id = aws_security_group.eks_nodes_dev.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}

resource "aws_vpc_security_group_ingress_rule" "rds_prod_from_eks_prod_db" {
  security_group_id            = aws_security_group.rds_prod.id
  referenced_security_group_id = aws_security_group.eks_nodes_prod.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
}

resource "aws_vpc_security_group_ingress_rule" "eks_dev_self" {
  security_group_id            = aws_security_group.eks_nodes_dev.id
  referenced_security_group_id = aws_security_group.eks_nodes_dev.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "eks_prod_self" {
  security_group_id            = aws_security_group.eks_nodes_prod.id
  referenced_security_group_id = aws_security_group.eks_nodes_prod.id
  ip_protocol                  = "-1"
}
