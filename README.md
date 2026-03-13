# Environment Prefix Policy (SSM / Secrets)

이 문서는 `envs/shared`, `envs/dev`, `envs/prod` 스택의 SSM/Secrets prefix 사용 규칙을 정의한다.

## Prefix 규칙

| Stack | SSM Prefix | Secrets Prefix |
| --- | --- | --- |
| shared | `/${project}/shared/network/...` | 사용 금지 |
| dev | `/${project}/dev/app/...`, `/${project}/dev/sqs/...`, `/${project}/dev/obs/...` | `${project}/dev/...` |
| prod | `/${project}/prod/app/...`, `/${project}/prod/sqs/...`, `/${project}/prod/obs/...` | `${project}/prod/...` |

Terraform 기준으로는 아래 로컬 값을 사용한다.

- shared: `local.ssm_shared_prefix`, `local.ssm_network_prefix`
- dev/prod: `local.ssm_env_prefix`, `local.ssm_app_prefix`, `local.ssm_sqs_prefix`, `local.ssm_obs_prefix`, `local.secrets_prefix`

## 정책

- shared 스택은 네트워크 값만 SSM에 저장한다.
- shared 스택의 `aws_ssm_parameter`는 반드시 `${local.ssm_network_prefix}/...` 형식이어야 한다.
- dev/prod 스택에서 SSM 값을 생성할 경우 `app|sqs|obs` prefix만 허용한다.
- dev/prod 스택은 shared 네트워크 prefix(`/${project}/shared/network/...`)에 쓰기하면 안 된다.
- shared 값이 필요하면 SSM data source 또는 remote state로 읽는다.

## 예시 키

- network 1: `/${project}/shared/network/vpc_id`
- network 2: `/${project}/shared/network/private_subnet_ids`
- dev app 1: `/${project}/dev/app/backend/db_url`
- dev app 2: `/${project}/dev/app/backend/jwt_public_key`
- dev sqs 1: `/${project}/dev/sqs/worker-task/url`

참고:
- 실제 운영 `project` 값은 스택 설정을 따르며, 레거시 리소스에는 `tm` prefix가 남아있을 수 있다.

## IRSA 최소권한과의 연결

Prefix를 stack/도메인 단위로 고정하면 IRSA 정책에서 `ssm:GetParameter*`, `secretsmanager:GetSecretValue`의 리소스 범위를 prefix 기준으로 잘라 최소권한을 강제할 수 있다.

## IAM Policy 관리 원칙 (LBC / Karpenter)

- `AWS Load Balancer Controller`와 `Karpenter Controller` IAM Policy는 Terraform이 생성한다. 콘솔/CLI 수동 생성은 금지한다.
- 정책 이름 규칙:
  - `AWSLoadBalancerControllerIAMPolicy-${project}-${env}`
  - `KarpenterControllerPolicy-${project}-${env}`
- `modules/irsa`는 정책을 생성하지 않고, 생성된 policy ARN을 ServiceAccount용 IAM Role에 attach만 수행한다.
- 따라서 dev/prod `terraform apply` 시 정책 생성 -> IRSA Role 생성/attach -> ServiceAccount `eks.amazonaws.com/role-arn` annotation 연결이 한 흐름으로 처리된다.
- Karpenter Controller policy의 `iam:PassRole` 대상은 Karpenter가 실제로 생성할 노드 IAM Role이어야 한다.
  기본값은 `module.eks.nodegroup_role_arn`이며, app node role을 분리하는 경우 `karpenter_node_role_arn` 변수로 override한다.
- Karpenter interruption queue를 사용하는 경우 `karpenter_interruption_queue_arn`을 지정하면 SQS 권한이 함께 추가된다.

## IRSA Apply 전제조건 (enable_irsa=true)

IRSA 모듈이 `kubernetes_namespace` / `kubernetes_service_account`를 생성하려면 AWS provider뿐 아니라 `kubernetes`/`helm` provider가 실제 EKS API에 연결되어 있어야 한다.

필수 입력/출력:

- `cluster_name`
- `oidc_provider_arn`
- `oidc_provider_url`
- `cluster_endpoint` (provider `host`)
- `cluster_ca_certificate` (provider `cluster_ca_certificate`, 일반적으로 `base64decode(...)` 필요)

연결 방식 1: EKS 모듈 outputs 직접 연결 (같은 stack 내부)

```hcl
cluster_name           = module.eks.cluster_name
oidc_provider_arn      = module.eks.oidc_provider_arn
oidc_provider_url      = module.eks.oidc_provider_url
cluster_endpoint       = module.eks.cluster_endpoint
cluster_ca_certificate = module.eks.cluster_ca_certificate
```

연결 방식 2: 변수 주입 (remote state/외부 파이프라인)

```hcl
cluster_name           = var.cluster_name
oidc_provider_arn      = var.oidc_provider_arn
oidc_provider_url      = var.oidc_provider_url
cluster_endpoint       = var.cluster_endpoint
cluster_ca_certificate = var.cluster_ca_certificate
```

Provider 예시 (`aws eks get-token` exec 방식):

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}
```

Prefix 차이 주의:

- SSM은 계층형 경로이므로 `/${project}/${env}/...`처럼 선행 `/`를 사용한다.
- Secrets Manager는 이름(prefix) 관례로 `${project}/${env}/...`처럼 선행 `/`를 사용하지 않는다.

## EKS Private Endpoint 운영 메모

- dev/prod EKS는 API endpoint를 Private Only로 구성한다.
- 따라서 `kubectl`/Terraform kubernetes provider 실행 주체는 VPC 내부 경로(예: SSM Jump Host)에서 접근해야 한다.
- 운영 방식으로 SSM을 사용하는 경우, EKS node role에 `AmazonSSMManagedInstanceCore`가 포함되어야 한다.
- Private subnet에서 SSM을 사용하려면 `ssm`, `ssmmessages`, `ec2messages` VPC Interface Endpoint가 필요하다(본 레포 network 스택에서 구성).
- 클러스터 접속 컨텍스트 갱신 예시:

```bash
aws eks update-kubeconfig --name eks-dev --region ap-northeast-2
aws eks update-kubeconfig --name eks-prod --region ap-northeast-2
```

- kubernetes/helm provider는 `module.eks.cluster_endpoint`, `module.eks.cluster_ca_certificate`를 연결해 사용한다.

## Jump Host (SSM only) 사용 절차

1. `enable_jump_host=true`로 apply하여 private subnet 점프 호스트를 생성한다.
2. Session Manager로 접속한다:
`aws ssm start-session --target <instance-id> --region ap-northeast-2`
3. 점프 호스트에서 kubeconfig를 갱신한다:
`aws eks update-kubeconfig --name eks-${env} --region ap-northeast-2`
4. 노드 상태를 확인한다:
`kubectl get nodes`

사람 IAM에 필요한 최소 권한 예시:

- `ssm:StartSession`
- `ssm:TerminateSession`
- `ssm:DescribeSessions`
- `ssm:DescribeInstanceInformation`

## EKS System NodeGroup 표준

`modules/eks/main.tf`의 `aws_eks_node_group.system`은 dev/prod 공통으로 항상 생성되며 아래 정책을 강제한다.

- label: `nodepool=system`
- taint: `dedicated=system:NoSchedule`
- 목적: 클러스터 필수 컨트롤러 전용 노드풀

검증 명령:

- `kubectl get nodes --show-labels | grep nodepool=system`
- `kubectl describe node <node-name> | grep dedicated=system:NoSchedule`

## 컨트롤러 System 고정 원칙

필수 컨트롤러(관측/인그레스/오토스케일링/GitOps)는 앱 워크로드와 격리해 운영 안정성을 확보한다.  
따라서 컨트롤러 파드는 모두 system 노드만 허용하며 app 워크로드는 Karpenter app 노드풀로 분리한다.

## Add-ons 표준 (dev/prod 공통)

`envs/dev/addons.tf`, `envs/prod/addons.tf`에서 공통 로컬 값을 사용한다.

- `local.addons_system_node_selector = { nodepool = "system" }`
- `local.addons_system_tolerations = [{ key = "dedicated", operator = "Equal", value = "system", effect = "NoSchedule" }]`

| Add-on | Namespace | Chart | SA | system 고정 values 경로 |
| --- | --- | --- | --- | --- |
| metrics-server | `kube-system` | `metrics-server` | chart 기본 | `nodeSelector`, `tolerations` |
| aws-load-balancer-controller | `platform` | `aws-load-balancer-controller` | `create=false`, `name=aws-load-balancer-controller` | `nodeSelector`, `tolerations` |
| karpenter-crd | `platform` | `karpenter-crd` | N/A | CRD chart(스케줄링 없음) |
| karpenter | `platform` | `karpenter` | `create=false`, `name=karpenter` | `nodeSelector`, `tolerations`, `controller.nodeSelector`, `controller.tolerations` |
| argocd | `argocd` | `argo-cd` | chart 기본 | `controller/server/repoServer/applicationSet/redis/dex` 각각 `nodeSelector`, `tolerations` |
| aws-ebs-csi-driver | `kube-system` | `aws-ebs-csi-driver` | chart 기본 | `controller.nodeSelector`, `controller.tolerations`, `node.tolerations` |

ArgoCD RBAC/CM 주입 위치(Helm values):

- `configs.rbac.policy.default=readonly`
- `configs.rbac.scopes=[groups]`
- `configs.rbac.policy.csv`:
  - `p, role:deployer, applications, get, */*, allow`
  - `p, role:deployer, applications, sync, */*, allow`
  - `g, tama:argocd-deployer, role:deployer`
- `configs.cm.statusbadge.enabled=true`

검증 명령:

- `kubectl -n argocd get cm argocd-rbac-cm -o yaml`
- `kubectl -n argocd get cm argocd-cm -o yaml`

## Logging/Observability 메모

### 현재 반영된 범위 (1차)

- EKS Control Plane Logging을 dev/prod 공통으로 활성화한다.
  - ON: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`
- Control Plane 로그 그룹(`/aws/eks/<cluster>/cluster`) retention을 env별로 관리한다.
  - dev: 14일
  - prod: 30일
- 컨테이너 로그 수집(Fluent Bit)을 dev/prod 공통으로 구성한다.
  - Helm chart: `aws-for-fluent-bit`
  - 로그 그룹: `${project}/${env}/eks/<cluster>/application`
  - IRSA ServiceAccount: `observability/aws-for-fluent-bit`
- 로그 기반 최소 알람 세트를 CloudWatch Logs Metric Filter + Alarm으로 구성한다.
  - `ERROR`, `5xx`, `CrashLoopBackOff`, `OOMKilled`
  - 알람 라우팅: `tamacoach-dev-alerts`, `tamacoach-prod-alerts` (SNS -> Lambda -> Slack 재사용)

### 다음 단계 (후속)

- ADOT -> AMP(shared) -> AMG(shared) 경로
- Grafana Alerting rules 고도화
- 로그 패턴/임계치 운영 데이터 기반 튜닝
- (선택) Control Plane/Application 로그 그룹 KMS 키 분리 운영

### 메트릭 플랫폼 표준 (ADOT/AMP/AMG)

- shared:
  - AMP workspace(`aws_prometheus_workspace`)를 생성하고 remote write endpoint를 output/SSM으로 배포한다.
  - AMG workspace(`aws_grafana_workspace`)를 생성하고 Prometheus/CloudWatch datasource 타입을 활성화한다.
  - AMP Alertmanager를 SNS(dev/prod)로 라우팅해 기존 Slack Lambda 경로를 재사용한다.
  - Alert rule IaC는 AMG API 의존도를 줄이기 위해 AMP rule group namespace로 관리한다.
  - ADOT remote write용 IAM 정책, 운영 조회용 AMP/AMG readonly IAM 정책을 env별(dev/prod)로 생성한다.
- dev/prod:
  - `enable_adot_metrics=true`일 때 `kube-state-metrics`, `prometheus-node-exporter`, `adot-collector`를 observability namespace에 배포한다.
  - ADOT collector는 AMP remote write를 사용하고, 공통 라벨(`env`, `cluster`)을 메트릭에 주입한다.
  - 고카디널리티 라벨(`pod_uid`, `container_id`, `id`)은 remote write 전에 제거한다.
- IRSA:
  - `enable_adot_irsa=true` + `enable_adot_metrics=true`일 때 `observability/adot-collector` SA에 최소권한(`aps:RemoteWrite` 범위) 정책을 연결한다.
  - policy ARN은 `adot_policy_arns`를 우선 사용하고, 없으면 shared remote state output을 기본 사용한다.

### 월간 점검 체크리스트

- dev/prod 컨테이너 로그 유입 여부(최근 24h 샘플) 확인
- Log Group retention/KMS 설정 drift 여부 점검
- 로그 기반 알람 오탐/미탐 리뷰 후 임계치 조정
- CloudWatch Logs ingest 비용 추이 확인(전월 대비 증감)
- ADOT collector / exporter 타겟 up 비율 점검 (`kube-state-metrics`, `node-exporter`, `apiserver`, `kubelet-cadvisor`)
- AMP ingest/query 비용 및 샘플 수 추세 점검
- AMG datasource/notification(SNS) 연결 상태 점검
- AMP Alertmanager 라우팅(dev/prod) 및 Slack 수신 정상 여부 점검

## ArgoCD AppProject 경계(dev/prod)

- `envs/dev/addons.tf`는 `AppProject/dev`를 생성하고, `sourceRepos`와 `destinations(namespace=apps, server=https://kubernetes.default.svc)`를 강제한다.
- `envs/prod/addons.tf`는 `AppProject/prod`를 동일 구조로 생성한다.
- `clusterResourceWhitelist=[]`로 cluster-scoped 리소스 배포를 기본 차단한다.
- `namespaceResourceWhitelist`는 apps namespace에서 필요한 core/apps 리소스만 허용한다.
- 경로(path) 제한은 AppProject 단독으로 완전하지 않으므로, `Application` 매니페스트를 `env/dev` 또는 `env/prod` 디렉터리에만 두는 배치 정책으로 보완한다.

검증 명령:

- `kubectl -n argocd get appproject dev -o yaml`
- `kubectl -n argocd get appproject prod -o yaml`

참고:

- LBC/Karpenter Helm release는 `depends_on = [module.irsa]`로 IRSA ServiceAccount 생성 이후 설치된다.
- Karpenter는 `depends_on = [module.irsa, helm_release.karpenter_crd]` 순서를 강제한다.

## Karpenter Discovery Tag 정책

NodeClass는 subnet/security group selector에 `karpenter.sh/discovery` 태그를 사용한다.

- dev: `karpenter.sh/discovery=eks-dev`
- prod: `karpenter.sh/discovery=eks-prod`

주의:

- security group은 dev/prod를 분리해 각각 `eks-dev`/`eks-prod` 태그를 사용한다.
- 현재 NodeClass selector는 `eks-${env}` 단일 태그 기준으로 동작한다.

확인 명령 예시:

- `aws ec2 describe-subnets --filters Name=tag:karpenter.sh/discovery,Values=eks-dev`
- `aws ec2 describe-subnets --filters Name=tag:karpenter.sh/discovery,Values=eks-prod`
- `aws ec2 describe-security-groups --filters Name=tag:karpenter.sh/discovery,Values=eks-dev`
- `aws ec2 describe-security-groups --filters Name=tag:karpenter.sh/discovery,Values=eks-prod`

## Karpenter NodeClass/NodePool 운영 규칙

`envs/*/addons.tf`는 Terraform `kubernetes_manifest`로 `EC2NodeClass(app)` + `NodePool(app)`를 관리한다.

- 공통:
  - `EC2NodeClass` `amiFamily=AL2023`
  - `NodePool` label `nodepool=app`
  - requirements: `kubernetes.io/arch=amd64`, `karpenter.sh/capacity-type=on-demand`
  - role 기본값: `module.eks.nodegroup_role_arn` (override: `karpenter_node_role_arn`)
- dev:
  - limits: `cpu=8`
  - disruption: `WhenEmptyOrUnderutilized`, `consolidateAfter=5m`
- prod:
  - limits: `cpu=4`
  - instance-type 제한: `m5.large`, `m5.xlarge`, `c6i.large`
  - disruption: `WhenEmpty`, `consolidateAfter=30m`
