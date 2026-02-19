# 📌 Tamacoach Infra Naming / Tagging / Validation – Code Agent 입력용 통합 규칙

아래 규칙은 **절대 위반하지 말 것**.
Terraform 코드 생성/수정 시 반드시 이 규칙을 따른다.

---

# 0️⃣ 정책 범위

이번 정책은 다음을 강제한다:

* 네이밍 규칙
* 필수 태그 적용
* project 값 고정
* SSM Parameter 경로 검증
* env 오염 방지
* 기존 리소스 rename 방지

현재는 다음을 사용한다:

* **variable validation**
* **check 블록**
* **provider default_tags**

---

# 1️⃣ 환경 정의

Env는 아래 4개 중 하나만 사용:

```
bootstrap
shared
dev
prod
```

브랜치 매핑:

```
develop → dev
main → prod
```

---

# 2️⃣ Prefix 정책 (레거시 공존)

* 신규 리소스는 반드시 `tamacoach` prefix 사용
* 기존 `tm-*` 리소스는 이름 변경 금지
* `tm`과 `tamacoach`를 한 이름에 혼합 금지

❌ 금지 예:

```
tm-dev-tamacoach-eks
```

---

# 3️⃣ 네이밍 규칙

## 3.1 dev/prod 리소스

형식:

```
<domain>-<env>-tamacoach-<resource>
```

예:

```
eks-dev-tamacoach-cluster
eks-prod-tamacoach-nodegroup
irsa-dev-tamacoach-apps-backend-sa
jump-prod-tamacoach-role
```

---

## 3.2 shared 리소스

형식:

```
tamacoach-shared-<resource>
```

단:

* 기존 `tm-*`는 유지
* 신규만 `tamacoach-shared-*` 사용

---

## 3.3 bootstrap 리소스

* 기존 `tm-*` 유지
* 이름 변경 금지
* 신규 생성 거의 없음

---

# 4️⃣ 네이밍 금지 규칙

* dev/prod 리소스에 env 누락 금지
* shared 리소스에 dev/prod env 포함 금지
* prefix 혼합 금지
* 임의 축약 금지
* 기존 리소스 이름 절대 변경 금지

예외(단일 허용):
* `aws_lb`(NLB) 이름은 AWS 32자 제한으로 인해 `envs/shared/backend_infra.tf`의
  `aws_lb.tamacoach_shared_backend_internal`에 한해 `-backend-`를 `-be-`로 축약 허용.
* 이 예외는 해당 리소스 1건에만 적용하며, 다른 리소스/스택으로 확장 금지.

만약 plan에 다음이 보이면 즉시 중지:

```
destroy
replace
```

→ DevOps 승인 없이 진행 금지

---

# 5️⃣ 필수 태그 규칙

모든 AWS 리소스(가능한 범위)에 반드시 적용:

```
Project    = tamacoach
StackEnv   = bootstrap | shared | dev | prod
Owner      = team-devops
ManagedBy  = terraform
```

### 구현 강제 방식

```hcl
provider "aws" {
  default_tags {
    tags = local.common_tags
  }
}
```

```hcl
locals {
  common_tags = {
    Project    = "tamacoach"
    StackEnv   = var.env
    Owner      = "team-devops"
    ManagedBy  = "terraform"
    CostCenter = "tamacoach"
  }
}
```

---

# 6️⃣ Project 값 강제 정책

## 현재 구현

* `envs/shared/variables.tf`
* `envs/dev/variables.tf`
* `envs/prod/variables.tf`

Validation:

```hcl
validation {
  condition     = var.project == "tamacoach"
  error_message = "project must be \"tamacoach\"."
}
```

즉:

* project는 항상 tamacoach
* tm 선택 불가

---

# 7️⃣ shared 레거시 네이밍 통제

`envs/shared/variables.tf`

```hcl
resource_naming_project
```

허용 값:

```
tm
tamacoach
```

목적:

* 기존 물리 리소스명 유지 허용
* 신규 전환은 통제된 값만 허용

---

# 8️⃣ SSM Parameter 경로 정책

형식:

```
/tamacoach/<env>/<domain>/<name>
```

---

## 8.1 dev/prod 허용 prefix

허용 경로:

```
/${project}/${env}/app/...
/${project}/${env}/sqs/...
/${project}/${env}/obs/...
```

금지:

```
/${project}/shared/network/...
```

---

## 8.2 shared 허용 prefix

허용:

```
/${project}/shared/network/...
```

금지:

```
/${project}/shared/app/...
/${project}/shared/sqs/...
/${project}/shared/obs/...
```

---

# 9️⃣ SSM Validation 구현 방식

## 9.1 variable validation

* 대상 변수: `ssm_parameter_names`
* 위치:

  * `envs/dev/variables.tf`
  * `envs/prod/variables.tf`

에러 메시지:

```
ssm_parameter_names must be under /${project}/${env}/{app|sqs|obs}/...
```

---

## 9.2 check 블록

### dev/prod

파일:

```
envs/dev/main.tf
envs/prod/main.tf
```

check:

```
check "ssm_parameter_prefix_policy"
```

보장:

* 허용 prefix 외 사용 금지
* shared/network 경로 금지

---

### shared

파일:

```
envs/shared/main.tf
```

check:

```
check "shared_ssm_prefix_policy"
```

보장:

* network prefix만 허용

---

# 🔟 Validation 동작 시점

| 종류                  | 실행 시점             | 차단 수준     |
| ------------------- | ----------------- | --------- |
| variable validation | validate / plan 전 | 입력값 자체 차단 |
| check 블록            | plan/apply 시      | 정책 위반 차단  |

---

# 1️⃣1️⃣ 팀원 작업 규칙

* SSM 새로 생성 시:

  * 허용 prefix 사용
  * dev/prod에서는 `ssm_parameter_names`에 반드시 추가
* shared는 network 키만 생성
* dev/prod는 shared/network 절대 금지
* project는 항상 tamacoach
* shared에서 `resource_naming_project="tm"` 사용은 승인된 경우만

---

# 1️⃣2️⃣ 검증 명령

```
terraform -chdir=envs/shared validate
terraform -chdir=envs/dev validate
terraform -chdir=envs/prod validate
```

check 블록 포함 검증:

```
terraform -chdir=envs/dev plan -var-file=terraform.tfvars
terraform -chdir=envs/prod plan -var-file=terraform.tfvars
```

---

# ⚠️ 운영상 매우 중요한 포인트

dev/prod의 SSM 검증은 `ssm_parameter_names` 목록 기반이다.

따라서:

* SSM 리소스를 추가하면서
* `ssm_parameter_names`에 반영하지 않으면
* 정책 검증이 약해질 수 있다.

운영 규칙:

> SSM 리소스 추가 시 `ssm_parameter_names` 동시 수정은 필수.

PR 체크리스트에 반드시 포함할 것.

---

# 📌 코드 에이전트 한 줄 요약

Terraform 생성 시:

* project는 반드시 tamacoach
* 신규 리소스는 tamacoach prefix
* dev/prod는 `<domain>-<env>-tamacoach-<resource>`
* shared는 `tamacoach-shared-*`
* bootstrap은 기존 tm-* 유지
* 모든 AWS 리소스는 default_tags 사용
* SSM은 env별 허용 prefix만 사용
* 기존 리소스 replace/destroy 시 무조건 중지
