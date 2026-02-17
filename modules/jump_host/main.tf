data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "aws_iam_policy_document" "assume_role_ec2" {
  count = var.existing_instance_profile_name == null ? 1 : 0

  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "jump" {
  count = var.existing_instance_profile_name == null ? 1 : 0

  name               = "jump-${var.env}-${var.project}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ec2[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  count = var.existing_instance_profile_name == null ? 1 : 0

  role       = aws_iam_role.jump[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "jump_inline" {
  count = var.existing_instance_profile_name == null ? 1 : 0

  statement {
    sid       = "AllowDescribeEksCluster"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [var.eks_cluster_arn]
  }

  statement {
    sid       = "AllowCallerIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "jump_inline" {
  count = var.existing_instance_profile_name == null ? 1 : 0

  name   = "jump-${var.env}-${var.project}-inline"
  role   = aws_iam_role.jump[0].id
  policy = data.aws_iam_policy_document.jump_inline[0].json
}

resource "aws_iam_instance_profile" "jump" {
  count = var.existing_instance_profile_name == null ? 1 : 0

  name = "jump-${var.env}-${var.project}-instance-profile"
  role = aws_iam_role.jump[0].name
  tags = var.tags
}

resource "aws_security_group" "jump" {
  name        = "jump-${var.env}-${var.project}-sg"
  description = "SSM jump host SG (no inbound, egress only)"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_egress_rule" "jump_allow_all_egress" {
  security_group_id = aws_security_group.jump.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

locals {
  effective_ami_id             = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id
  effective_instance_profile   = var.existing_instance_profile_name != null ? var.existing_instance_profile_name : aws_iam_instance_profile.jump[0].name
  effective_role_name          = var.existing_instance_profile_name != null ? null : aws_iam_role.jump[0].name
  effective_security_group_ids = concat([aws_security_group.jump.id], var.additional_sg_ids)
}

resource "aws_instance" "jump" {
  ami                         = local.effective_ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  iam_instance_profile        = local.effective_instance_profile
  vpc_security_group_ids      = local.effective_security_group_ids
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    exec > >(tee /var/log/jump-host-userdata.log|logger -t user-data -s 2>/dev/console) 2>&1

    if command -v dnf >/dev/null 2>&1; then
      dnf -y update
      dnf -y install unzip curl tar gzip
    else
      yum -y update
      yum -y install unzip curl tar gzip
    fi

    if ! command -v aws >/dev/null 2>&1; then
      if command -v dnf >/dev/null 2>&1; then
        dnf -y install awscli
      else
        yum -y install awscli
      fi
    fi

    curl -sSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${var.kubectl_version}/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    if [ "${var.install_helm}" = "true" ]; then
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi

    aws --version || true
    kubectl version --client --output=yaml || true
    helm version || true
  EOF

  tags = merge(var.tags, {
    Name = "jump-${var.env}-${var.project}"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
