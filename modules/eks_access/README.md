# EKS Access Module

`modules/eks_access`는 EKS Access Entry를 사용해 IAM Principal을 Kubernetes group으로 매핑한다.

주의:
- 이 모듈은 "누가 클러스터에 인증되는가"를 연결한다.
- 실제 권한(무엇을 할 수 있는가)은 `modules/k8s_rbac`가 고정한다.
- 즉, 권한의 진실 원천은 RBAC이다.
- Access Policy Association은 기본 생성하지 않는다(권한 부여를 IAM policy가 아닌 RBAC로 고정하기 위함).

## Inputs

- `env` (`string`): `dev` | `prod`
- `cluster_name` (`string`)
- `enable_access_entries` (`bool`, default: `false`)
- `access_entries` (`list(object)`)
  - `principal_arn` (`string`)
  - `groups` (`list(string)`)  
    허용값: `tama:platform-admin`, `tama:platform-ops`, `tama:developer`, `tama:argocd-deployer`
  - `username` (`optional(string, null)`)
  - `type` (`optional(string, "STANDARD")`)

## Outputs

- `applied_entries`: `principal_arn => groups`
- `entry_ids`: `principal_arn => access_entry_id`

## Example

```hcl
module "eks_access" {
  source = "../../modules/eks_access"

  env                   = var.env
  cluster_name          = var.cluster_name
  enable_access_entries = var.enable_access_entries
  access_entries = [
    {
      principal_arn = "arn:aws:iam::123456789012:role/tm-platform-admin"
      groups        = ["tama:platform-admin"]
    },
    {
      principal_arn = "arn:aws:iam::123456789012:role/tm-developer"
      groups        = ["tama:developer"]
    },
  ]
}
```
