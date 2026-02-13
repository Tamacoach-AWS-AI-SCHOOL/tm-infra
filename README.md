# Tamacochi – Infrastructure Repository

This repository manages AWS infrastructure using Terraform.

It provisions shared, development, and production environments
for the Tamacochi cloud architecture.

---

# 📌 Core Principles

- **Repo of Truth**  
  Application deployment state is defined in the manifest-repo.
  This repository only provisions infrastructure.

- **Environment Mapping**
  - develop → dev (stage)
  - main → prod

- **Immutable Promotion**
  Production workloads must use image digest pinning.

- **Environment Isolation**
  shared / dev / prod are separated at the state level.

- **State Safety**
  Remote state is stored in S3 with DynamoDB locking.

---

# 📁 Repository Structure

```
bootstrap/          # One-time setup for remote state (S3 + DynamoDB)
modules/            # Reusable Terraform modules
envs/
  shared/           # Global resources (VPC, ECR, CloudFront, etc.)
  dev/              # Development environment
  prod/             # Production environment
```

---

# 🗂 Environments

## shared

Global infrastructure components:

- VPC
- Subnets
- ECR
- CloudFront
- Route53
- ACM
- API Gateway (if shared)

## dev

- EKS (dev cluster)
- Internal NLB (dev)
- Environment-specific configuration

## prod

- EKS (prod cluster)
- Internal NLB (prod)
- Production-specific configuration

---

# 🔐 Remote State Architecture

Remote state is configured using:

- S3 bucket (state storage)
- DynamoDB table (state locking)

Each environment uses a separate state key:

```
shared/terraform.tfstate
dev/terraform.tfstate
prod/terraform.tfstate
```

Bootstrap must be executed before using remote state.

---

# 🚀 Workflow

## 1️⃣ Bootstrap (One-Time Only)

Creates:
- S3 bucket for state
- DynamoDB table for locking

```
cd bootstrap
terraform init
terraform apply
```

---

## 2️⃣ Deploy Shared Environment

```
cd envs/shared
terraform init
terraform plan
terraform apply
```

---

## 3️⃣ Deploy Dev or Prod

```
cd envs/dev
terraform init
terraform apply
```

or

```
cd envs/prod
terraform init
terraform apply
```

---

# 📤 Exposed Outputs

This repository exposes infrastructure outputs used by other repositories
(CI/CD pipelines or SSM Parameter Store).

Examples:

- front_bucket_name
- cloudfront_distribution_id
- api_custom_domain
- ecr_repository_url
- eks_cluster_name
- nlb_arn
- nlb_target_group_arn

---

# 🔒 Operational Rules

- Never commit `.tfstate` files.
- Production apply must go through CI with manual approval.
- Do not modify infrastructure manually via AWS Console.
- Avoid configuration drift.
- Keep Terraform version and provider versions pinned.

---

# 🧱 Infrastructure Responsibility

This repository:
- Provisions infrastructure
- Defines environment boundaries
- Exposes outputs for CI/CD usage

This repository does NOT:
- Deploy application workloads
- Manage Kubernetes manifests
- Control image promotion logic

Those responsibilities belong to the application and manifest repositories.

---

# 🛠 Tooling

- Terraform
- AWS
- GitLab CI (for plan/apply pipeline)
- ArgoCD (for workload deployment)
