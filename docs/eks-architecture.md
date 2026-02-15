# EKS 아키텍처 설계 문서 (Dev / Prod 공통 원칙)

## 1. 클러스터 구성 개요

* **EKS 2개 운영**

  * `eks-dev`
  * `eks-prod`
* 네트워크: Private Subnet 기반
* API Endpoint: **Private Only**
* 접근 방식: **SSM Jump Host 경유 kubectl 접근 (SSH 포트 미개방)**
* Dev → Prod 순서로 변경 승격

---

## 2. 접근 모델 (Access & GitOps 원칙)

### 2.1 kubectl 운영 원칙

| 주체        | 접근 방식                | 권한                                         |
| --------- | -------------------- | ------------------------------------------ |
| 사람(운영/개발) | SSM Session Manager로 Jump Host 접속 후 kubectl | 최소 권한                                      |
| ArgoCD    | GitOps 기반 배포         | ArgoCD Application Controller SA가 앱 namespace write |
| GitLab CI | manifest-repo 수정만    | 클러스터 직접 접근 없음                              |

### 원칙

* 사람은 prod에 직접 `kubectl apply` 하지 않는다.
* 배포 변경은 **manifest-repo → ArgoCD 동기화**를 통해서만 반영된다.
* prod `apps` namespace의 Kubernetes write 권한은 **ArgoCD Application Controller가 사용하는 Kubernetes ServiceAccount에만 부여한다.**
* 사람 IAM Role은 prod `apps` namespace에 write 권한을 갖지 않는다.
* `argocd-deployer` 역할은 ArgoCD UI/API에서 sync를 수행할 수 있는 권한으로 정의한다.
* Kubernetes 리소스 write는 ArgoCD 내부 ServiceAccount가 수행한다.

---

## 3. Kubernetes 버전 및 Add-on 정책

* Dev/Prod **동일 Kubernetes 버전 유지**
* 업그레이드 순서: `dev → 검증 → prod`
* Core Add-ons:

  * vpc-cni
  * coredns
  * kube-proxy
* Add-on은 버전 관리(Pinning) 원칙

  * Dev에서 최신 검증
  * Prod는 검증된 버전만 적용
* 자동 무작위 업데이트는 사용하지 않음

---

## 4. 노드 아키텍처

### 4.1 노드 구성 전략

| 구분          | 용도               | 생성 방식              |
| ----------- | ---------------- | ------------------ |
| System Node | 클러스터 필수 컴포넌트     | Managed Node Group |
| App Node    | Backend / Worker | Karpenter          |

---

### 4.2 System 노드 정책

목적:

* 앱 트래픽 폭주와 클러스터 핵심 컴포넌트 분리
* 오토스케일 장애 방지

**Taint**

```
dedicated=system:NoSchedule
```

**필수 컴포넌트**

* ArgoCD
* metrics-server
* Karpenter Controller
* AWS Load Balancer Controller
* ADOT Collector
* Fluent Bit
* External Secrets

---

### 4.3 App 노드 정책 (Karpenter)

* HPA 기반 Pod 오토스케일링
* Karpenter 기반 Node 오토스케일링
* On-Demand 인스턴스만 사용
* Backend/Worker 동일 노드풀에서 시작
* 추후 필요 시 workload 분리 가능

Karpenter는 서브넷 및 보안 그룹을
"karpenter.sh/discovery={cluster-name}" 태그를 통해 선택한다.
해당 태그는 Terraform에서 EKS 클러스터 이름 기준으로 설정한다.

---

## 5. IRSA 설계 원칙

### 5.1 사람 IAM vs Pod IAM 경계

| 구분            | 역할             |
| ------------- | -------------- |
| 사람 IAM        | 인프라 관리, 조회 중심  |
| Pod IAM(IRSA) | 런타임 AWS 리소스 접근 |

**원칙**

* 사람에게 데이터 plane 권한 최소화
* Pod는 최소 권한 원칙(ARN/Prefix 제한)
* dev/prod IAM Role 완전 분리

---

### 5.2 Pod 단위 AWS 접근 대상

| 영역      | 예시                   |
| ------- | -------------------- |
| Secrets | Secrets Manager, SSM |
| Logging | CloudWatch Logs      |
| Metrics | AMP remote_write     |
| Async   | SQS, EventBridge     |
| Storage | S3 (prefix 제한)       |
| AI      | Bedrock invoke       |

ECR Pull은 Node IAM Role에서 처리.

---

### 5.3 네이밍 규칙

**Namespace**

* argocd
* apps
* platform
* observability
* external-secrets

**ServiceAccount 예시**

```
apps/backend-sa
apps/worker-sa
platform/lbc-sa
observability/adot-sa
```

**IAM Role 예시**

```
irsa-dev-apps-backend
irsa-prod-apps-backend
```

---

## 6. Access Entries 기반 접근 제어 설계

### 6.1 역할 정의

| 역할            | dev                             | prod                            |
| ------------- | ------------------------------- | ------------------------------- |
| PlatformAdmin | cluster-admin                   | cluster-admin (제한적)             |
| PlatformOps   | 운영 범위 write                     | 제한적 write                       |
| Argo Deployer | ArgoCD UI/API sync 권한 (K8s write 아님) | ArgoCD UI/API sync 권한 (K8s write 아님) |
| Developer     | apps write                      | read-only                       |

※ 주의:
argocd-deployer는 Kubernetes 리소스에 직접 write하는 IAM 역할이 아니다.
해당 역할은 ArgoCD UI/API에서 Application sync를 수행할 수 있는 권한을 의미한다.
실제 Kubernetes 리소스 변경은 ArgoCD Application Controller의 ServiceAccount를 통해 수행된다.

---

### 6.2 Prod Write 정책

* apps namespace Kubernetes write:

  * ArgoCD Application Controller ServiceAccount 전용
* 사람 IAM Role은 기본 read-only
* 긴급 시 break-glass admin 사용

ArgoCD Application Controller의 Kubernetes ServiceAccount는
IAM Access Entry 대상이 아니며,
클러스터 내부 RBAC 및 IRSA를 통해 권한을 가진다.


---

## 7. Load Balancer 전략

선택: **A안 (AWS Load Balancer Controller)**

* NLB를 Kubernetes 리소스로 관리
* TargetGroupBinding 필요 시 사용
* LBC는 system 노드에 배치

---

## 8. Storage 전략

* GitLab/SonarQube는 EKS 외부
* EBS CSI Driver 설치 (미래 확장 대비)
* 기본 StorageClass: **gp3**
* gp3를 default로 설정

상태 저장 컴포넌트는:

* Prometheus 자체 저장
* Redis/Kafka 등 클러스터 내부 저장 시스템
* 현재 필수는 아님

---

## 9. Observability 구조

### 9.1 AMP / AMG

* AMP: AWS 관리형 Prometheus (클러스터 외부)
* AMG: AWS 관리형 Grafana (클러스터 외부)

### 9.2 EKS 내부 구성

System 노드에 배치:

* metrics-server
* ADOT Collector (remote_write → AMP)
* Fluent Bit

---

## 10. 기본 애드온 최소 셋

필수:

* vpc-cni
* coredns
* kube-proxy
* metrics-server
* karpenter
* AWS Load Balancer Controller
* EBS CSI Driver
* ADOT Collector
* Fluent Bit
* External Secrets

---

# 최종 설계 요약

* Private EKS + SSM Jump Host 접근
* GitOps 중심 (Kubernetes write는 ArgoCD Controller SA가 수행)
* System/App 노드 분리
* IRSA 최소 권한 원칙
* Access Entries 기반 접근 통제
* AMP/AMG는 외부 관리형
* HPA + Karpenter 구조

---

## 1) IRSA 스코프 확정 (최종)

project_prefix는 Terraform 변수로 정의되며,
예: "/tamacoach" 형태로 설정된다.
SSM 및 Secrets 경로는 해당 prefix를 기준으로 구성된다.

### 1-1. SSM 경로 규칙

* **최상위 규칙**

  * `shared` 스택은 네트워크/공용 인프라 값만 저장
  * 런타임(앱/큐/시크릿) 값은 **반드시 env 아래로 분리**

#### Shared (네트워크 전용)

* `${var.project_prefix}/shared/network/...`

#### Dev/Prod (런타임/앱 전용)

* `${var.project_prefix}/${var.env}/...` (`var.env ∈ {dev, prod}`)

권장 세부 경로(고정):

* `${var.project_prefix}/${var.env}/app/{service}/...`
* `${var.project_prefix}/${var.env}/sqs/{queue-name}/...`
* `${var.project_prefix}/${var.env}/obs/...` (필요 시)

예시:

* `${var.project_prefix}/shared/network/vpc_id`
* `${var.project_prefix}/dev/sqs/{project-name}-dev-worker-task/url`
* `${var.project_prefix}/prod/app/backend/db_url`

---

### 1-2. Secrets Manager 경로 규칙

* Secret name(또는 path):
* `${var.project_prefix}/${var.env}/{service}/{secret-name}`

예시:

* `${var.project_prefix}/dev/backend/db-credentials`
* `${var.project_prefix}/prod/backend/db-credentials`

Secrets Manager는 이름 기반 prefix 구조를 사용하며,
SSM처럼 실제 계층 구조가 존재하는 것은 아니다.


---

### 1-3. SQS 큐 ARN 스코프(backend/worker)

큐 네이밍:

* `{project-name}-{env}-{domain}-{purpose}`

backend(Producer):

* `sqs:SendMessage`만
* 대상: backend가 보내는 큐 ARN 목록만

worker(Consumer):

* `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:ChangeMessageVisibility`, `sqs:GetQueueAttributes`
* 대상: worker가 읽는 큐 ARN 목록만

> **큐 ARN 목록은 “변수로 고정”**(예: `backend_queue_arns`, `worker_queue_arns`)

---

### 1-4. S3 prefix(필요 시)

* 공용 버킷이어도 prefix로 env 격리
* `s3://{bucket}/app-data/{env}/...`

backend/worker가 S3가 필요할 때만 IRSA 권한 부여.

---

### 1-5. IRSA 역할(최소 확정 셋)

* `apps/backend-sa` → `irsa-{env}-apps-backend`
* `apps/worker-sa` → `irsa-{env}-apps-worker`
* `platform/aws-load-balancer-controller` → `irsa-{env}-platform-lbc`
* `platform/karpenter` → `irsa-{env}-platform-karpenter`
* `observability/adot-collector` → `irsa-{env}-obs-adot`
* `external-secrets/external-secrets` → `irsa-{env}-sec-eso`

Karpenter는 Controller용 IRSA Role과,
실제 EC2 노드가 사용하는 Instance Profile Role을 별도로 구성한다.

---

## 2) Access Entries 역할 확정 (최종)

### 2-1. 역할(고정)

* `platform-admin`
* `platform-ops`
* `argocd-deployer`
* `developer`

### 2-2. dev/prod write 범위 확정표

#### Dev

| 역할              | 클러스터 레벨          | apps                                   | platform |
| --------------- | ---------------- | -------------------------------------- | -------- |
| platform-admin  | cluster-admin    | full                                   | full     |
| platform-ops    | 운영 범위 write      | edit                                   | edit     |
| argocd-deployer | ArgoCD sync 수행 권한 | sync trigger only (직접 Kubernetes write 없음) | none     |
| developer       | 없음               | edit                                   | none     |

#### Prod

| 역할              | 클러스터 레벨                     | apps                                   | platform |
| --------------- | --------------------------- | -------------------------------------- | -------- |
| platform-admin  | cluster-admin (break-glass) | full                                   | full     |
| platform-ops    | 제한적 운영 write                | read-only                              | edit     |
| argocd-deployer | 앱 배포 sync 수행 권한             | sync trigger only (직접 Kubernetes write 없음) | none     |
| developer       | 없음                          | read-only                              | none     |

**Prod 핵심 원칙(고정)**

* prod `apps` namespace의 Kubernetes write는 **ArgoCD Application Controller ServiceAccount만 수행**
* 사람(developer/ops)은 prod 앱에 직접 apply 금지(원칙)
* `argocd-deployer`는 ArgoCD UI/API sync 권한만 가지며 Kubernetes 리소스 write 권한은 가지지 않음
* 긴급 시에만 platform-admin 사용

---

## 3) 네임스페이스 최소 셋 확정 (최종)

### 필수

* `argocd`
* `apps`
* `platform`
* `observability` (AMP/로그/메트릭 에이전트)
* `external-secrets` (ESO)

---

## 변수로 고정해야 하는 목록(문서/TF 변수)

* `project_prefix = "/tamacoach"`
* `ssm_shared_prefix = "${var.project_prefix}/shared"`
* `ssm_env_prefix = "${var.project_prefix}/${var.env}"`
* `secrets_prefix = "${var.project_prefix}/${var.env}"`
* `backend_queue_arns = [...]`
* `worker_queue_arns = [...]`
* `(optional) s3_bucket`, `(optional) s3_prefix = "app-data/${env}/"`
