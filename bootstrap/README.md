# Tamacochi – Infrastructure Repository

이 저장소는 Terraform을 사용하여 Tamacochi 서비스의 AWS 인프라를 관리한다

shared, dev, prod 환경을 분리하여 인프라를 구성하며,
애플리케이션 배포 상태는 별도의 manifest-repo(tm-manifest)에서 관리된다.

---

# 📌 핵심 원칙

- **Repo of Truth**
  애플리케이션 배포 상태는 manifest-repo에서만 정의한다.
  본 저장소는 인프라 프로비저닝만 담당한다.

- **환경 매핑**
  - develop → dev (stage)
  - main → prod

- **Immutable Promotion**
  운영 환경은 반드시 이미지 digest pinning 기반으로 승격

- **환경 격리**
  shared / dev / prod는 Terraform state 단위로 완전히 분리

- **State 안전성**
  Remote state는 S3에 저장하며 DynamoDB로 locking을 수행

---

# 📁 레포 구조

```
bootstrap/          # Remote state용 S3 + DynamoDB를 생성하는 1회성 스택
modules/            # 재사용 가능한 Terraform 모듈
envs/
  shared/           # 공통 인프라 (VPC, ECR, CloudFront 등)
  dev/              # 개발 환경 인프라
  prod/             # 운영 환경 인프라
```

---

# 🗂 환경 설명

## shared

공통 인프라 구성 요소:

- VPC
- Subnet
- ECR
- CloudFront
- Route53
- ACM
- API Gateway

## dev

- EKS (dev 클러스터)
- Internal NLB (dev)
- 개발 환경 전용 설정

## prod

- EKS (prod 클러스터)
- Internal NLB (prod)
- 운영 환경 전용 설정

---

# 🔐 Remote State 구조

Remote state 구성:

- S3 버킷 (Terraform state 저장)
- DynamoDB 테이블 (state lock)

각 환경은 별도의 state key를 사용

```
shared/terraform.tfstate
dev/terraform.tfstate
prod/terraform.tfstate
```

Remote state 사용 전 반드시 bootstrap을 실행해야 함

---

# 🚀 실행 순서

## 1️⃣ Bootstrap (최초 1회 실행)

생성 리소스:
- Terraform state 저장용 S3 버킷
- DynamoDB Lock 테이블

```
cd bootstrap
terraform init
terraform apply
```

---

## 2️⃣ Shared 환경 배포

```
cd envs/shared
terraform init
terraform plan
terraform apply
```

---

## 3️⃣ Dev 또는 Prod 배포

```
cd envs/dev
terraform init
terraform apply
```

또는

```
cd envs/prod
terraform init
terraform apply
```

---

# 📤 Outputs / Parameter Store 공유 값

이 저장소는 다른 레포(CI/CD, manifest-repo 등)가 참조해야 하는 인프라 식별자/엔드포인트를 `terraform output`으로 정의한다.

- Output 자체는 인터넷에 공개되지 않으며,
  **Terraform state에 접근 가능한 주체(사람/CI)** 에게만 노출된다.
- 다른 레포에서의 사용 편의를 위해,
  필요한 값은 **SSM Parameter Store 경로 규칙**에 따라 저장한다.

## 저장 방식

- **Terraform이 `aws_ssm_parameter`로 자동 저장**
  - `terraform apply` 시점에 output 값을 SSM에 함께 기록

## 예시 outputs

- front_bucket_name
- cloudfront_distribution_id
- api_custom_domain
- ecr_repository_url
- eks_cluster_name
- nlb_arn
- nlb_target_group_arn

## SSM 경로 규칙

- shared(network only): `/${project}/shared/network/...`
- dev/prod(runtime): `/${project}/${env}/app/...`, `/${project}/${env}/sqs/...`, `/${project}/${env}/obs/...`
- secrets prefix: `${project}/${env}/...` (선행 `/` 없이)

---

# 🔒 운영 규칙

- `.tfstate` 파일은 절대 커밋 X
- 운영(prod) apply는 반드시 CI 수동 승인 후 실행한다.
- AWS Console에서 수동 변경 금지(드리프트 방지)
- Terraform 및 provider 버전은 반드시 고정
- shared → dev → prod 순서를 준수한다.

---

# 🧱 역할 범위

이 저장소가 담당하는 것:
- 인프라 프로비저닝
- 환경 경계 정의
- CI/CD에서 사용할 output 제공

이 저장소가 담당하지 않는 것:
- 애플리케이션 배포
- Kubernetes 매니페스트 관리
- 이미지 승격 로직 관리

위 항목은 application 레포(tm-frontend, tm-backend) 및 manifest-repo(tm-manifest)에서 담당한다.


# 🛠 사용 기술

- Terraform
- AWS
- GitLab CI
- ArgoCD (워크로드 배포용)
