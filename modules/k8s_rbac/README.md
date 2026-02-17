# Kubernetes RBAC Module

`modules/k8s_rbac`는 EKS access group에 대한 Kubernetes 권한을 환경별로 고정한다.

핵심 원칙:
- Access Entry는 "인증 주체 매핑"
- RBAC는 "실제 권한"의 진실 원천
- prod `apps` write는 ArgoCD Controller ServiceAccount에만 부여

## Inputs

- `env` (`dev|prod`)
- `enable_rbac` (`bool`, default: `false`)
- `namespaces`
  - `apps`
  - `platform`
  - `argocd`
- `groups`
  - `platform_admin`
  - `platform_ops`
  - `developer`
  - `argocd_deployer`
- `argocd`
  - `controller_namespace`
  - `controller_serviceaccount`

## Policy Summary

| Env | Subject | apps | platform | cluster |
| --- | --- | --- | --- | --- |
| dev | `tama:developer` | edit | - | - |
| dev | `tama:platform-ops` | - | edit | - |
| dev/prod | `tama:platform-admin` | - | - | cluster-admin |
| prod | `tama:developer` | view | - | - |
| prod | `tama:platform-ops` | view | edit | - |
| prod | ArgoCD controller SA | edit | - | - |

`tama:argocd-deployer`는 ArgoCD UI/API sync 권한 용도이므로 Kubernetes write RoleBinding을 만들지 않는다.

## ArgoCD Controller SA Name

차트/values에 따라 이름이 다를 수 있다. 예:
- `argocd-application-controller`
- `argocd-app-controller`

`argocd.controller_serviceaccount` 입력을 실제 Helm values와 일치시켜야 한다.

