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
→ `docs/naming-tagging.md` 문서를 따른다.

