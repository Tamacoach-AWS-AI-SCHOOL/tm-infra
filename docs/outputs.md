# Infra Outputs Specification

본 문서는 infra-repo가 생성/노출하는 주요 outputs와
이를 다른 레포(앱/manifest/CI)가 어디에서 어떻게 가져가는지 정의한다.

---

## 1) Output 저장 위치

SSM Parameter Store 단일 소스 사용

경로 규칙:

```
/{project}/{env}/...
```

예:
- /tamacochi/shared/front/bucket_name
- /tamacochi/dev/eks/cluster_name

민감정보는 SecureString, 비민감정보는 String 타입을 사용한다.

---

## 2) Outputs 목록

### 2-1. Front (shared)

| Output Key | 의미 | 사용 주체 | SSM 경로 |
|------------|------|------------|-----------|
| front_bucket_name | 정적 프론트 배포 S3 버킷 이름 | front CI | /{project}/shared/front/bucket_name |
| cloudfront_distribution_id | CloudFront 배포 ID (invalidate 용) | front CI | /{project}/shared/front/cloudfront_distribution_id |

---

### 2-2. API (shared)

| Output Key | 의미 | 사용 주체 | SSM 경로 |
|------------|------|------------|-----------|
| api_custom_domain | API Gateway 커스텀 도메인 | front/app 설정 | /{project}/shared/api/custom_domain |
| api_stage_mapping | API stage 매핑 식별자 또는 이름 | 운영/CI | /{project}/shared/api/stage_mapping |

---

### 2-3. ECR (shared)

| Output Key | 의미 | 사용 주체 | SSM 경로 |
|------------|------|------------|-----------|
| ecr_repository_url | ECR 레포지토리 URL | backend/worker CI | /{project}/shared/ecr/repository_url |

---

### 2-4. EKS

| Output Key | 의미 | 사용 주체 | SSM 경로 |
|------------|------|------------|-----------|
| eks_dev_cluster_name | dev EKS 클러스터 이름 | CI/운영 | /{project}/dev/eks/cluster_name |
| eks_prod_cluster_name | prod EKS 클러스터 이름 | CI/운영 | /{project}/prod/eks/cluster_name |

---

### 2-5. NLB

| Output Key | 의미 | 사용 주체 | SSM 경로 |
|------------|------|------------|-----------|
| nlb_dev_arn | dev internal NLB ARN | API Gateway / 운영 | /{project}/dev/nlb/arn |
| nlb_dev_tg_arn | dev Target Group ARN | TGB/헬스체크 | /{project}/dev/nlb/target_group_arn |
| nlb_prod_arn | prod internal NLB ARN | API Gateway / 운영 | /{project}/prod/nlb/arn |
| nlb_prod_tg_arn | prod Target Group ARN | TGB/헬스체크 | /{project}/prod/nlb/target_group_arn |

---

## 3) CI에서 조회 방법 예시

### String 조회

```
aws ssm get-parameter \
  --name "/tamacochi/shared/front/cloudfront_distribution_id" \
  --query "Parameter.Value" \
  --output text
```

### SecureString 조회

```
aws ssm get-parameter \
  --name "/tamacochi/shared/slack/webhook_url" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text
```

---

## 4) 운영 주의사항

- prod 관련 파라미터는 prod 파이프라인 Role만 접근 가능하도록 IAM으로 제한한다.
- dev는 overwrite 허용 가능, prod는 승인 프로세스 기반으로 제한하는 것을 권장한다.
- 동일 값을 CI 변수에 중복 저장하지 않는다 (드리프트 방지).
