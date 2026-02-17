# GitLab OIDC Terraform CI Role Module

`modules/iam-gitlab-oidc`는 GitLab CI에서 AWS 인증을 OIDC(`AssumeRoleWithWebIdentity`)로 수행하기 위한
OIDC Provider(선택 생성)와 Terraform Plan/Apply 역할 1쌍을 생성한다.

## 생성 리소스

- `aws_iam_openid_connect_provider.gitlab` (선택: `create_oidc_provider=true`일 때만 생성)
- `aws_iam_role.plan` (`<prefix>-tf-plan-role`)
- `aws_iam_role.apply` (`<prefix>-tf-apply-role`)
- `aws_iam_policy.plan` / `aws_iam_policy.apply`
- 각 role-policy attachment

## Trust Policy 설계

- 공통:
  - `sts:AssumeRoleWithWebIdentity`만 허용
  - `aud` claim 일치 강제
  - `sub` claim 패턴으로 프로젝트 범위 제한
- plan role 기본 `sub`:
  - `project_path:<gitlab_project_path>:*`
- apply role 기본 `sub`:
  - `project_path:<gitlab_project_path>:ref_type:branch:ref:main`
  - 즉 기본값은 main 브랜치에서만 Assume 가능

`aud_claim_name`, `sub_claim_name`, `allowed_ref_patterns_plan`, `allowed_ref_patterns_apply` 변수로
GitLab.com / Self-Managed claim 매핑 차이를 흡수할 수 있다.

## 권한 정책 분리

- plan role:
  - state bucket/list+object 접근
  - lock table 접근
  - plan/refresh에 필요한 Describe/List/Get 중심
- apply role:
  - plan policy 포함
  - 현재 인프라 서비스 범위(EC2/EKS/ELB/IAM/SSM/Secrets/KMS/S3/DynamoDB 등) 변경 권한 추가

## 입력 변수 핵심

- `gitlab_oidc_issuer_url`
- `gitlab_oidc_audience`
- `gitlab_oidc_thumbprint_list`
- `gitlab_project_path`
- `state_bucket_name`, `state_bucket_arn`
- `lock_table_arn`
- `kms_key_arn` (optional)
- `role_name_prefix`

## 출력

- `oidc_provider_arn`
- `tf_plan_role_arn`
- `tf_apply_role_arn`
- `tf_plan_policy_arn`
- `tf_apply_policy_arn`

## 예시

```hcl
module "gitlab_ci_oidc" {
  source = "../../modules/iam-gitlab-oidc"

  gitlab_oidc_issuer_url   = "https://gitlab.com"
  gitlab_oidc_audience     = "https://gitlab.com"
  gitlab_oidc_thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd0e5b0"]
  gitlab_project_path      = "group/subgroup/tm-infra"

  state_bucket_name = "tm-193629269600-tfstate"
  state_bucket_arn  = "arn:aws:s3:::tm-193629269600-tfstate"
  lock_table_arn    = "arn:aws:dynamodb:ap-northeast-2:193629269600:table/tm-tf-lock"
  region            = "ap-northeast-2"

  role_name_prefix = "tamacoach"
  tags = {
    Project  = "tamacoach"
    StackEnv = "shared"
    Owner    = "team-a"
  }
}
```

## 운영 메모

- Apply는 GitLab에서 반드시 manual gate로 실행한다.
- IAM Trust에서 이미 main 제한이 걸리므로, develop/feature에서 apply role Assume은 실패해야 정상이다.
- (선택) shared apply를 더 강하게 제한하려면 `apply_sub_patterns`를 별도 role로 분리하거나,
  GitLab `rules:changes`로 `envs/shared/**` 변경 시에만 apply job을 노출한다.
