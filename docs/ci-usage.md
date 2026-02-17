# CI Usage (Infra Repo)

인프라 레포 변경 시 팀 공통 CI 사용 절차입니다.

## 1) 작업 시작
- `feature/*` 브랜치에서 작업
- 커밋 전 `terraform fmt -recursive`를 실행

## 2) MR 생성
- 기본 흐름: `feature/* -> develop`
- 운영 반영 시: `develop -> main`

## 3) Plan 확인
- 파이프라인에서 `fmt`, `validate` 성공을 먼저 확인
- 변경된 환경만 `plan`이 실행됨됨
  - `envs/shared/**` 변경: `plan:shared`
  - `envs/dev/**` 변경: `plan:dev`
  - `envs/prod/**` 변경: `plan:prod`

## 4) Apply 실행 (수동)
- `apply`는 항상 수동(`manual`)으로 실행
- 실행 순서:
  1. `apply:shared`
  2. `apply:dev` 또는 `apply:prod`

## 5) 실패 시 빠른 점검
- `AccessDenied`: IAM role 정책 누락
- `InvalidIdentityToken`: OIDC issuer/audience/JWKS 접근 문제
- `Unauthorized`(Kubernetes): EKS access entry/RBAC 누락
- `No value for required variable`: `terraform.tfvars` 또는 CI 변수 누락

## 6) 운영 원칙
- `main` 직접 push 금지 (Protected branch)
- `apply` 자동 실행 금지
- 수동 변경 발생 시 Terraform 코드에 즉시 반영
