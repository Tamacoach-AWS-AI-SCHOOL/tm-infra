# Infra Repo Conventions (Naming / Tags / Structure)

## 1) 기본 원칙

- Repo of Truth: 애플리케이션 배포 상태는 manifest-repo가 진실의 원천이며, 본 레포는 인프라만 관리한다.
- 환경 매핑
  - develop → dev (stage)
  - main → prod
- 환경 분리 원칙
  - Terraform state는 shared/dev/prod로 분리한다.
  - 공통 리소스는 shared에, 환경 종속 리소스는 dev/prod에 둔다.
- 운영 승격은 image digest pinning을 전제로 한다 (배포 상태는 manifest-repo에서 관리).

---

## 2) 폴더 구조 규칙

```
bootstrap/     : remote state(S3 + DynamoDB) 1회성 스택
modules/       : 재사용 가능한 Terraform 모듈
envs/shared/   : 공통 인프라 (VPC, ECR, CloudFront 등)
envs/dev/      : dev 환경 인프라
envs/prod/     : prod 환경 인프라
docs/          : 규칙/출력/운영 문서
```

### 환경 스택 공통 파일 구성

- backend.tf     : S3 backend 설정 (환경별 key 분리)
- versions.tf    : Terraform CLI 버전 + provider 버전 핀
- providers.tf   : provider 설정 (aws, 필요 시 kubernetes/helm)
- main.tf        : module 호출
- variables.tf   : 입력 변수 정의
- outputs.tf     : 출력 값 정의

---

## 3) 네이밍 규칙

### 공통 변수 (권장)

- project : tamacochi
- env     : shared | dev | prod
- region  : ap-northeast-2 (예시)
- owner   : 팀 또는 조직 식별자

### 리소스 이름 패턴

기본 형식:

```
{project}-{env}-{component}
```

예:
- tamacochi-dev-eks
- tamacochi-shared-front-bucket

전역 유니크가 필요한 리소스(S3 등)는 suffix를 추가한다:

```
{project}-{env}-{component}-{suffix}
```

---

## 4) 태깅 규칙

모든 AWS 리소스에 공통 태그를 적용한다.

### Required Tags

- Project   = tamacochi
- Env       = shared | dev | prod
- Owner     = 팀명
- ManagedBy = Terraform
- Repo      = infra / front / backend / worker

### Optional Tags

- CostCenter
- Service (front/api/worker 등)
- DataClassification (public/internal/confidential)

---

## 5) State / Apply 규칙

- bootstrap/은 최초 1회 local state로 apply한다.
- 그 외 모든 스택은 S3 backend + DynamoDB lock을 사용한다.
- apply 순서 원칙:
  1. bootstrap
  2. envs/shared
  3. envs/dev 또는 envs/prod
- prod apply는 수동 승인(manual gate) 기반으로 수행한다.

---

## 6) 민감정보 처리 원칙

- tfvars 파일에 비밀값을 커밋하지 않는다.
- 민감정보는 다음으로 관리한다:
  - SSM Parameter Store (SecureString)
- ARN, 도메인, ID 등 비민감 값은 SSM String으로 관리 가능.

---

## 7) 코드 스타일 규칙

- terraform fmt를 항상 통과해야 한다.
- Terraform 및 provider 버전은 반드시 핀한다.
- .terraform.lock.hcl은 커밋하여 재현성을 확보한다.
