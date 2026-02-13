# Infra Repo Conventions (Naming / Tags / Structure)

## 1) 기본 원칙

- **Repo of Truth**: 배포 상태는 manifest-repo가 진실의 원천이며, 본 레포는 인프라만 관리한다.
- **환경 매핑**
  - `develop` → `dev(stage)`
  - `main` → `prod`
- **환경 분리 원칙**
  - Terraform state는 `shared/dev/prod`로 분리한다.
  - 공통 리소스는 `shared`, 환경 종속 리소스는 `dev/prod`에 둔다.
- **동일 바이너리 보장(참고)**
  - 운영 승격은 image digest pinning을 전제로 한다(배포 상태는 manifest-repo에서 관리).

---

## 2) 폴더 구조 규칙
- bootstrap/ : remote state(S3+DDB) 1회성 스택
- modules/ : 재사용 모듈
- envs/shared/ : 공통 인프라(VPC, ECR, CloudFront, Route53/ACM, API GW 등)
- envs/dev/ : dev 환경(EKS-dev, NLB-dev 등)
- envs/prod/ : prod 환경(EKS-prod, NLB-prod 등)
- docs/ : 규칙/출력/운영 문서