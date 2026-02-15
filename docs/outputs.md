# Outputs 설계 + 전달 경로 확정 (Step G)

본 문서는 P1 단계에서 Outputs의 **키 이름**과 **전달 경로(SSM Parameter Store)** 규칙만 확정한다.
Terraform의 SSM 자동 저장(`aws_ssm_parameter`) 코드는 아직 적용하지 않으며, 해당 자동화는 P3~P5에서 구현한다.

## 1) Outputs Contract

### 1-1. front (shared)
- `front_bucket_name`
- `cloudfront_distribution_id`

### 1-2. api (shared)
- `api_custom_domain`
- `api_stage_mapping`

### 1-3. ecr (shared)
- `ecr_repository_url`

### 1-4. eks (dev/prod)
- `eks_dev_cluster_name`
- `eks_prod_cluster_name`

### 1-5. nlb (dev/prod)
- `nlb_dev_arn`
- `nlb_dev_tg_arn`
- `nlb_prod_arn`
- `nlb_prod_tg_arn`

## 2) SSM Path Mapping

경로 규칙:

`/{project}/{env}/{domain}/{key}`

고정 값:
- `project = tm`
- `env ∈ {shared, dev, prod}`
- `domain ∈ {front, api, ecr, eks, nlb}`

Front는 "S3 1개 + CloudFront 1개 + prefix로 dev/prod 분리" 구조이므로 outputs는 `shared` 경로로 관리한다.

| Output Key | SSM Path |
|---|---|
| `front_bucket_name` | `/tm/shared/front/front_bucket_name` |
| `cloudfront_distribution_id` | `/tm/shared/front/cloudfront_distribution_id` |
| `api_custom_domain` | `/tm/shared/api/api_custom_domain` |
| `api_stage_mapping` | `/tm/shared/api/api_stage_mapping` |
| `ecr_repository_url` | `/tm/shared/ecr/ecr_repository_url` |
| `eks_dev_cluster_name` | `/tm/dev/eks/eks_dev_cluster_name` |
| `eks_prod_cluster_name` | `/tm/prod/eks/eks_prod_cluster_name` |
| `nlb_dev_arn` | `/tm/dev/nlb/nlb_dev_arn` |
| `nlb_dev_tg_arn` | `/tm/dev/nlb/nlb_dev_tg_arn` |
| `nlb_prod_arn` | `/tm/prod/nlb/nlb_prod_arn` |
| `nlb_prod_tg_arn` | `/tm/prod/nlb/nlb_prod_tg_arn` |

## 3) Who Uses What

- front CI/CD: `front_bucket_name`, `cloudfront_distribution_id`
- backend/worker CI/CD 또는 운영: `ecr_repository_url`
- platform/ops 또는 ArgoCD bootstrap: `eks_dev_cluster_name`, `eks_prod_cluster_name`, `nlb_dev_arn`, `nlb_dev_tg_arn`, `nlb_prod_arn`, `nlb_prod_tg_arn`
- API 라우팅 설정: `api_custom_domain`, `api_stage_mapping`

## 4) Policy

- `tfvars`에는 비밀값을 저장하지 않는다. 민감정보는 필요 시 SSM SecureString 또는 Secrets Manager를 사용한다.
- overwrite 정책: dev는 overwrite 허용(운영 편의), prod는 승인/정책 하에서만 변경 가능하도록 제한한다.
- 현재 단계(P1)에서는 SSM 자동 저장 미구현 상태이므로, 값 조회는 우선 `terraform output`으로 수행한다.