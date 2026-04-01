<!-- ENG -->
<details open>
<summary><strong>English</strong></summary>

> **Commit History Notice**: This repository was migrated from a GitLab Self-Managed instance. Commit history may appear inconsistent.
> Commits attributed to **`administrator`** were actually authored by **`sml-logs`**. Please keep this in mind when reviewing contribution history.

---

# TamaCoach — Infra Repository

Infrastructure repository for TamaCoach, an Agentic AI personal coaching service for self-understanding and behavioral change, powered by Amazon Bedrock.

**Development Period**: 2026.01.28 ~ 2026.03.04

> This repository manages all AWS infrastructure as code using Terraform.
> For application deployment state, refer to [**tm-manifest**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-manifest). For service code, refer to each app repository below.

---

## Repository Structure

| Repository | Role |
|------------|------|
| [**tm-infra**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-infra) (current) | Terraform IaC — full AWS infrastructure |
| [**tm-manifest**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-manifest) | ArgoCD GitOps source — image digest (backend/worker) |
| [**tm-helm**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-helm) | ArgoCD GitOps source — Helm chart templates |
| [**tm-backend**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-backend) | Django backend |
| [**tm-frontend**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-frontend) | Vue frontend |
| [**tm-agent**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-agent) | AI Multi-Agent (Strands Agents + LangChain) |

---

## Infrastructure Stack

| Area | Service |
|------|---------|
| Container | AWS EKS (Private Endpoint, Multi-AZ, ap-northeast-2a/2c) |
| Node Provisioning | Karpenter (fixed System nodes / dynamic App nodes) |
| GitOps | ArgoCD (Dual-Source: tm-helm + tm-manifest) |
| IaC | Terraform (4-layer state: bootstrap / shared / dev / prod) |
| Network | VPC, Route53, CloudFront + WAF, API Gateway (HTTP API), Internal NLB |
| Security | IRSA, ESO + Secrets Manager, GuardDuty, SecurityHub, Inspector, Macie |
| Monitoring | ADOT → AMP, AMG (Grafana), Fluent Bit → CloudWatch |
| Alerting | CloudWatch/AMP Rules → SNS → Lambda Notifier → Slack |
| CI Auth | OIDC Keyless (STS AssumeRoleWithWebIdentity) |
| Code Quality | SonarQube (deploy blocked if Quality Gate fails) |

---

# Infra Architecture
<img width="1895" height="2098" alt="다마코치_전체_인프라_아키텍처 drawio (3)" src="https://github.com/user-attachments/assets/0d1fa7fc-84aa-42b9-a8b9-be9ec31c97e1" />

# System Architecture
<img width="1302" height="1511" alt="다마코치_시스템_아키텍처의 복사본 drawio (2)" src="https://github.com/user-attachments/assets/61ed27e5-142c-4466-a10e-26fe568a8e4a" />

---

## CI/CD — Terraform Apply Flow
<img width="1096" height="568" alt="다마코치_CI_CD drawio (3)" src="https://github.com/user-attachments/assets/15274821-7294-4d94-a392-5eedffdbcf28" />

GitLab Self-Managed (deployed inside VPC) + OIDC Keyless authentication.
No long-lived AWS Access Keys — GitLab CI jobs obtain temporary credentials via OIDC token → AWS STS AssumeRoleWithWebIdentity.

| Branch | Environment | Apply Method |
|--------|-------------|--------------|
| develop | dev (stage) | auto plan → auto apply |
| main | prod | auto plan → **manual approval required** |

**Per-environment Role separation**: separate IAM Roles for shared / dev / prod with least privilege

--

## CI/CD — Application Deployment Pipeline

Full CI/CD architecture covering all app repositories (GitLab CI → SonarQube → ECR → manifest-repo → ArgoCD → EKS).
For pipeline details of each repository, refer to the respective app repo README.

<img width="1096" height="568" alt="다마코치_CI_CD drawio (3)" src="https://github.com/user-attachments/assets/52fe27ad-a9bc-4ac2-a655-c26ebf71eb42" />

---

## Operational Access

EKS is configured with **Private Endpoint only**. Direct cluster access is not available.

- **Access path**: Jump Host → SSM Session Manager
- **Kubernetes write access**: granted only to ArgoCD Service Account (direct `kubectl apply` by humans is blocked)
- **Terraform apply**: via GitLab CI (OIDC) or lead local environment (prod requires manual approval)

---

## Monitoring & Alerting

**`Metrics`**: ADOT Collector → AMP → AMG Grafana dashboard

**`Logs`**: Fluent Bit DaemonSet + EKS Control Plane Logs → CloudWatch

**`Alert Routing`**: CloudWatch/AMP → SNS → Lambda Notifier → Slack (routed by channel)

| Slack Channel | Purpose |
|---------------|---------|
| `#alerts-dev` | dev CloudWatch alerts (API GW latency, SQS DLQ) |
| `#alerts-prod` | prod CloudWatch alerts (@here mention for critical) |
| `#deployments` | ArgoCD deployment success/failure |
| `#gitlab-webhook` | MR creation, merge, pipeline result notifications |
| `#security-prod` | GuardDuty·SecurityHub prod security events |

<details>
<summary>Slack screenshots</summary>
<div markdown="1">

  ### `#security-prod`
  <img width="994" height="713" alt="ScreenShot 2026-04-01 오후 9 19 39" src="https://github.com/user-attachments/assets/6b3969cb-1062-4b60-b439-6e8571f0537e" />

  ### `#alerts-dev`
  <img width="994" height="713" alt="ScreenShot 2026-04-01 오후 9 20 57" src="https://github.com/user-attachments/assets/c1026a6e-5ec8-4271-8d9d-f2b1ad80f930" />

  ### `#alerts-prod`
  <img width="994" height="713" alt="ScreenShot 2026-04-01 오후 9 21 08" src="https://github.com/user-attachments/assets/68ae35f3-4972-4a0f-b132-a20feefc44f5" />

  ### `#deployments`
  <img width="674" height="362" alt="ScreenShot 2026-04-01 오후 9 22 04" src="https://github.com/user-attachments/assets/3a18199b-75b7-41a0-8835-75c441ebed5c" />

  ### `#gitlab-webhook`
  <img width="995" height="707" alt="ScreenShot 2026-04-01 오후 9 23 06" src="https://github.com/user-attachments/assets/2701571c-3635-4c38-bcd1-db23f1f16ef3" />

</div>
</details>

---

# Infra Repo Conventions (Structure / State / Governance)

## 1) Core Principles

* **Repo of Truth**: Application deployment state is owned by manifest-repo. This repo manages infrastructure only.
* **Branch-to-environment mapping**
  * develop → dev (stage)
  * main → prod
* **Environment isolation**
  * Terraform state is separated into: bootstrap / shared / dev / prod
  * Shared resources live in `shared`; environment-specific resources live in `dev` or `prod`
* Production promotion requires image digest pinning (deployment state is managed in manifest-repo)

---

## 2) Folder Structure

```
bootstrap/     : one-time stack for remote state (S3 + DynamoDB)
modules/       : reusable Terraform modules
envs/shared/   : shared infrastructure (VPC, NAT, VPCE, etc.)
envs/dev/      : dev environment infrastructure (EKS, IRSA, Jump Host, etc.)
envs/prod/     : prod environment infrastructure
docs/          : conventions, outputs, and operational docs
```

---

## 3) Environment Ownership

| Stack     | Purpose                   | Who can change     |
| --------- | ------------------------- | ------------------ |
| bootstrap | remote state foundation   | Lead / DevOps only |
| shared    | network / shared resources | DevOps            |
| dev       | development environment   | Entire team        |
| prod      | production environment    | After approval     |

---

## 4) State / Apply Rules

* `bootstrap/` is applied once with local state only.
* All other stacks use S3 backend + DynamoDB lock.
* Apply order:
  1. bootstrap
  2. envs/shared
  3. envs/dev or envs/prod
* prod apply requires manual approval (manual gate).
* bootstrap resources (S3 tfstate bucket, DynamoDB lock table) must never be renamed.

---

## 5) Secrets Handling

* Never commit secret values in tfvars files.
* Sensitive values must use SSM Parameter Store (SecureString) or Secrets Manager.
* Non-sensitive values (ARNs, IDs, etc.) may use SSM String.

---

## 6) Code Style

* All code must pass `terraform fmt`.
* Terraform and provider versions must be pinned.
* `.terraform.lock.hcl` must be committed for reproducibility.
* No manual console changes — all changes must go through Terraform.

---

## 7) Naming / Tagging Policy

Detailed naming and tagging rules are defined in
→ [`docs/naming-tagging.md`](docs/naming-tagging.md)

</details>

---

<!-- KOR -->
<details>
<summary><strong>한국어</strong></summary>

> **커밋 이력 안내**: 이 레포지토리는 GitLab Self-Managed 인스턴스에서 마이그레이션된 것으로, 커밋 이력이 일부 다르게 표시될 수 있습니다.
> 특히 **`administrator`** 계정으로 표시된 커밋은 실제로 **`sml-logs`** 가 작성한 것입니다. 기여 이력 확인 시 참고해 주세요.

---

# 다마코치 (TamaCoach) — Infra Repository

Amazon Bedrock 기반 자기이해 및 행동 변화를 위한 Agentic AI 퍼스널 코칭 서비스의 인프라 코드를 관리하는 레포지토리입니다.

**개발 기간**: 2026.01.28 ~ 2026.03.04

> 본 레포는 Terraform으로 AWS 인프라를 코드로 관리합니다.
> 애플리케이션 배포 상태는 [**tm-manifest**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-manifest), 서비스 코드는 각 앱 레포를 참고하세요.

---

## 레포지토리 구성

| 레포 | 역할 |
|------|------|
| [**tm-infra**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-infra) (현재) | Terraform IaC — AWS 인프라 전체 |
| [**tm-manifest**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-manifest) | ArgoCD GitOps 소스 — image digest (backend/worker) |
| [**tm-helm**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-helm) | ArgoCD GitOps 소스 — Helm 차트 템플릿 |
| [**tm-backend**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-backend) | Django 백엔드 |
| [**tm-frontend**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-frontend) | Vue 프론트엔드 |
| [**tm-agent**](https://github.com/Tamacoach-AWS-AI-SCHOOL/tm-agent) | AI Multi-Agent (Strands Agents + LangChain) |

---

## 주요 인프라 스택

| 영역 | 서비스 |
|------|--------|
| 컨테이너 | AWS EKS (Private Endpoint, Multi-AZ, ap-northeast-2a/2c) |
| 노드 프로비저닝 | Karpenter (System 노드 고정 / App 노드 동적) |
| GitOps | ArgoCD (Dual-Source: tm-helm + tm-manifest) |
| IaC | Terraform (4-layer state: bootstrap / shared / dev / prod) |
| 네트워크 | VPC, Route53, CloudFront + WAF, API Gateway (HTTP API), Internal NLB |
| 보안 | IRSA, ESO + Secrets Manager, GuardDuty, SecurityHub, Inspector, Macie |
| 모니터링 | ADOT → AMP, AMG (Grafana), Fluent Bit → CloudWatch |
| 알람 | CloudWatch/AMP Rules → SNS → Lambda Notifier → Slack |
| CI 인증 | OIDC Keyless (STS AssumeRoleWithWebIdentity) |
| 코드 품질 | SonarQube (Quality Gate 미통과 시 deploy 차단) |

---

# Infra Architecture
<img width="1895" height="2098" alt="다마코치_전체_인프라_아키텍처 drawio (3)" src="https://github.com/user-attachments/assets/0d1fa7fc-84aa-42b9-a8b9-be9ec31c97e1" />

# System Architecture
<img width="1302" height="1511" alt="다마코치_시스템_아키텍처의 복사본 drawio (2)" src="https://github.com/user-attachments/assets/61ed27e5-142c-4466-a10e-26fe568a8e4a" />

---

## CI/CD — Terraform Apply 흐름

GitLab Self-Managed (VPC 내 구축) + OIDC Keyless 인증 사용.
장기 Access Key 미사용 — GitLab CI Job이 OIDC Token을 발급받아 AWS STS로 임시 자격증명을 획득합니다.

| 브랜치 | 환경 | apply 방식 |
|--------|------|-----------|
| develop | dev (stage) | 자동 plan → 자동 apply |
| main | prod | 자동 plan → **수동 승인 후** apply |

**환경별 Role 분기**: shared / dev / prod 각각 별도 IAM Role로 최소 권한 적용

---

## CI/CD — 애플리케이션 배포 파이프라인

전체 앱 레포의 CI/CD 아키텍처입니다 (GitLab CI → SonarQube → ECR → manifest-repo → ArgoCD → EKS).
각 레포별 파이프라인 상세는 해당 앱 레포 README를 참고하세요.

<img width="1096" height="568" alt="다마코치_CI_CD drawio (3)" src="https://github.com/user-attachments/assets/2b34bd47-aab2-4162-8732-961ffb28457f" />

---

## 운영 접근 방법

EKS는 **Private Endpoint** 전용 구성입니다. 클러스터에 직접 접근 불가.

- **접근 경로**: Jump Host → SSM Session Manager
- **Kubernetes write 권한**: ArgoCD Service Account에만 부여 (사람의 직접 kubectl apply 차단)
- **Terraform apply**: GitLab CI (OIDC) 또는 리드 로컬 환경 (prod는 수동 승인 필수)

---

## 모니터링 & 알람

**`메트릭`**: ADOT Collector → AMP → AMG Grafana 대시보드

**`로그`**: Fluent Bit DaemonSet + EKS Control Plane Logs → CloudWatch

**`알람 라우팅`**: CloudWatch/AMP → SNS → Lambda Notifier → Slack 채널별 분리

| Slack 채널 | 용도 |
|------------|------|
| `#alerts-dev` | dev CloudWatch 알람 (API GW 지연, SQS DLQ) |
| `#alerts-prod` | prod CloudWatch 알람 (@here critical 멘션) |
| `#deployments` | ArgoCD 배포 성공/실패 알림 |
| `#gitlab-webhook` | MR 생성·머지·파이프라인 결과 알림 |
| `#security-prod` | GuardDuty·SecurityHub prod 보안 이벤트 |

<details>
<summary>슬랙 캡처</summary>
<div markdown="1">

  ### `#security-prod`
  <img width="994" height="713" alt="ScreenShot 2026-04-01 오후 9 19 39" src="https://github.com/user-attachments/assets/6b3969cb-1062-4b60-b439-6e8571f0537e" />

  ### `#alerts-dev`
  <img width="994" height="713" alt="ScreenShot 2026-04-01 오후 9 20 57" src="https://github.com/user-attachments/assets/c1026a6e-5ec8-4271-8d9d-f2b1ad80f930" />

  ### `#alerts-prod`
  <img width="994" height="713" alt="ScreenShot 2026-04-01 오후 9 21 08" src="https://github.com/user-attachments/assets/68ae35f3-4972-4a0f-b132-a20feefc44f5" />

  ### `#deployments`
  <img width="674" height="362" alt="ScreenShot 2026-04-01 오후 9 22 04" src="https://github.com/user-attachments/assets/3a18199b-75b7-41a0-8835-75c441ebed5c" />

  ### `#gitlab-webhook`
  <img width="995" height="707" alt="ScreenShot 2026-04-01 오후 9 23 06" src="https://github.com/user-attachments/assets/2701571c-3635-4c38-bcd1-db23f1f16ef3" />

</div>
</details>

---

# Infra Repo Conventions (Structure / State / Governance)

## 1) 기본 원칙

* Repo of Truth: 애플리케이션 배포 상태는 manifest-repo가 진실의 원천이며, 본 레포는 인프라만 관리한다.
* 환경 매핑
  * develop → dev (stage)
  * main → prod
* 환경 분리 원칙
  * Terraform state는 bootstrap / shared / dev / prod로 분리한다.
  * 공통 리소스는 shared에, 환경 종속 리소스는 dev/prod에 둔다.
* 운영 승격은 image digest pinning을 전제로 한다 (배포 상태는 manifest-repo에서 관리).

---

## 2) 폴더 구조 규칙

```
bootstrap/     : remote state(S3 + DynamoDB) 1회성 스택
modules/       : 재사용 가능한 Terraform 모듈
envs/shared/   : 공통 인프라 (VPC, NAT, VPCE 등)
envs/dev/      : dev 환경 인프라 (EKS, IRSA, Jump 등)
envs/prod/     : prod 환경 인프라
docs/          : 규칙/출력/운영 문서
```

---

## 3) 환경별 책임 범위

| Stack     | 목적              | 변경 권한      |
| --------- | --------------- | ---------- |
| bootstrap | remote state 기반 | 리드/DevOps만 |
| shared    | 네트워크/공용 리소스     | DevOps     |
| dev       | 개발 환경           | 팀 전체       |
| prod      | 운영 환경           | 승인 후       |

---

## 4) State / Apply 규칙

* bootstrap/은 최초 1회 local state로 apply한다.
* 그 외 모든 스택은 S3 backend + DynamoDB lock을 사용한다.
* apply 순서 원칙:
  1. bootstrap
  2. envs/shared
  3. envs/dev 또는 envs/prod
* prod apply는 수동 승인(manual gate) 기반으로 수행한다.
* bootstrap 리소스(S3 tfstate, DynamoDB lock table)는 이름 변경 금지.

---

## 5) 민감정보 처리 원칙

* tfvars 파일에 비밀값을 커밋하지 않는다.
* 민감정보는 SSM Parameter Store(SecureString) 또는 Secrets Manager 사용.
* 비민감 값(ARN, ID 등)은 SSM String 사용 가능.

---

## 6) 코드 스타일 규칙

* terraform fmt를 항상 통과해야 한다.
* Terraform 및 provider 버전은 반드시 핀한다.
* .terraform.lock.hcl은 커밋하여 재현성을 확보한다.
* 수동 콘솔 생성 금지 (Terraform으로만 변경).

---

## 7) Naming / Tagging 정책

Naming 및 Tagging의 상세 규칙은
→ [`docs/naming-tagging.md`](docs/naming-tagging.md) 문서를 따른다.

</details>
