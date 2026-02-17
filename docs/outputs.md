# Outputs 및 공유값 전달 규칙

현재 레포 기준으로 팀/스택 간 공유값은 다음 원칙으로 전달한다.

- 우선순위 1: `terraform output`
- 우선순위 2: SSM Parameter Store (이미 코드에서 관리 중인 항목만)

## 1) 현재 stack별 주요 outputs

## 1-1. `envs/shared`
- `ssm_shared_prefix`
- `ssm_network_prefix`
- `private_subnet_ids_dev`
- `private_subnet_ids_prod`

## 1-2. `envs/dev`
- `eks_cluster_name`, `eks_cluster_arn`, `eks_cluster_endpoint`
- `eks_oidc_provider_arn`, `eks_oidc_provider_url`
- `eks_system_nodegroup_name`, `eks_system_nodegroup_role_arn`
- `irsa_role_arns`, `irsa_serviceaccount_names`
- `eks_access_applied_entries`, `eks_access_entry_ids`
- `jump_host_instance_id`, `jump_host_private_ip`, `jump_host_security_group_id`

## 1-3. `envs/prod`
- `envs/dev`와 동일 구조

## 2) SSM 저장 상태 (현재 코드 기준)

- `shared` 스택은 네트워크 공유값을 SSM에 저장한다.
  - 예: `/${project}/shared/network/vpc_id`
  - 예: `/${project}/shared/network/private_subnet_ids`
  - 예: `/${project}/shared/network/sg_ids`
- `dev/prod`는 점프호스트 식별값을 SSM에 저장한다.
  - 예: `/${project}/${env}/platform/jump/instance_id`
  - 예: `/${project}/${env}/platform/jump/private_ip`
  - 예: `/${project}/${env}/platform/jump/security_group_id`

참고:
- `project` 값은 스택별 실제 설정(`tm` 또는 `tamacoach`)을 따른다. 레거시 리소스는 `tm` prefix가 남아있을 수 있다.
- 모든 output이 자동으로 SSM에 저장되는 구조는 아니다.

## 3) 운영 규칙

- 팀 간 계약값은 먼저 `terraform output` 이름으로 합의한다.
- SSM에 없는 output은 필요 시 별도 `aws_ssm_parameter` 리소스로 명시 추가한다.
- `tfvars`에 비밀값은 커밋하지 않는다.
- 민감정보는 SSM SecureString 또는 Secrets Manager를 사용한다.
