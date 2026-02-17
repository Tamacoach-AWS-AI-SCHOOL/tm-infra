# IRSA Module

`modules/irsa`는 EKS IRSA 구성을 표준화한다.

- ServiceAccount 1개당 IAM Role 1개 생성
- IRSA trust policy 자동 구성 (OIDC `sub` / `aud`)
- 관리형 정책 attach + 인라인 정책 attach
- Kubernetes ServiceAccount 생성 + `eks.amazonaws.com/role-arn` annotation 자동 추가

## Inputs

- `env` (`string`): `dev` 또는 `prod`
- `cluster_name` (`string`)
- `oidc_provider_arn` (`string`)
- `oidc_provider_url` (`string`)
- `project` (`string`)
- `serviceaccounts` (`list(object)`)
  - `namespace` (`string`)
  - `name` (`string`)
  - `policy_arns` (`optional(list(string), [])`)
  - `inline_policy_json` (`optional(string, null)`)
  - `create_namespace` (`optional(bool, true)`)
  - `tags` (`optional(map(string), {})`)

## Outputs

- `role_arns` (`map(string)`): key=`<namespace>/<name>`, value=`role arn`
- `serviceaccount_names` (`map(string)`): key=`<namespace>/<name>`, value=`sa name`
- `namespaces` (`set(string)`): 생성한 namespace 목록

## Usage Example

```hcl
module "irsa" {
  source = "../../modules/irsa"

  env               = var.env
  cluster_name      = var.cluster_name
  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url
  project           = var.project

  serviceaccounts = [
    {
      namespace = "apps"
      name      = "backend-sa"
      policy_arns = []
      inline_policy_json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
          Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_env_prefix}/*"
        }]
      })
    }
  ]
}
```

## Notes

- Role name 규칙은 `irsa-${env}-${project}-${namespace}-${name}`를 기본으로 하며, 64자 초과 시 해시 suffix를 붙여 축약한다.
- OIDC URL은 모듈 내부에서 `https://`와 trailing `/`를 제거해 trust condition 변수로 사용한다.
- `create_namespace = true`인 항목만 namespace를 생성한다. 이미 존재하는 namespace를 사용할 때는 `false`로 설정한다.
