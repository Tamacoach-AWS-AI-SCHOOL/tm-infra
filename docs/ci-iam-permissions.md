# CI IAM Permissions Guide

## 1) 목적
GitLab CI에서 Terraform `plan/apply` 실행 시 AccessDenied 재발을 줄이기 위한 권한 기준 문서입니다.

## 2) 역할
- Plan Role
  - 목적: state 접근 + refresh/plan에 필요한 read-only API 호출
- Apply Role
  - 목적: Plan Role 권한 포함 + 생성/수정/삭제 권한

## 3) 대상 Role ARN
- `TF_PLAN_ROLE_ARN_SHARED`
- `TF_PLAN_ROLE_ARN_DEV`
- `TF_PLAN_ROLE_ARN_PROD`
- `TF_APPLY_ROLE_ARN_SHARED`
- `TF_APPLY_ROLE_ARN_DEV`
- `TF_APPLY_ROLE_ARN_PROD`

## 4) Plan 필수 권한 기준
### State
- `s3:ListBucket`
- `s3:GetObject`
- `s3:GetObjectVersion`
- `s3:PutObject`
- `s3:DeleteObject`
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:DeleteItem`
- `dynamodb:UpdateItem`
- `dynamodb:DescribeTable`

### Read/Refresh
- `ec2:Describe*`
- `eks:Describe*`
- `eks:List*`
- `eks:ListTagsForResource`
- `elasticloadbalancing:Describe*`
- `logs:Describe*`
- `logs:ListTagsForResource`
- `ecr:Describe*`
- `ecr:List*`
- `ssm:Describe*`
- `ssm:GetParameter`
- `ssm:GetParameters`
- `ssm:GetParametersByPath`
- `ssm:ListTagsForResource`
- `secretsmanager:DescribeSecret`
- `secretsmanager:GetSecretValue`
- `iam:Get*`
- `iam:List*`
- `acm:DescribeCertificate`
- `acm:GetCertificate`
- `acm:ListCertificates`
- `acm:ListTagsForCertificate`
- `cloudfront:GetDistribution`
- `cloudfront:GetDistributionConfig`
- `cloudfront:GetFunction`
- `cloudfront:DescribeFunction`
- `cloudfront:GetOriginAccessControl`
- `cloudfront:ListOriginAccessControls`
- `cloudfront:ListTagsForResource`
- `route53:Get*`
- `route53:List*`
- `s3:GetBucketTagging`
- `s3:GetBucketVersioning`
- `s3:GetEncryptionConfiguration`
- `s3:GetBucketPublicAccessBlock`
- `s3:GetBucketOwnershipControls`
- `s3:GetBucketPolicy`
- `s3:GetBucketWebsite`

## 5) Apply 추가 권한 기준
- `acm:*`, `route53:*`, `cloudfront:*`, `s3:*`, `apigateway:*`, `lambda:*`, `iam:PassRole`, `iam:GetRole` (`TerraformInfrastructureManagement`)
- `ec2:Create*`, `ec2:Modify*`, `ec2:Delete*`, `ec2:RunInstances`, `ec2:TerminateInstances`
- `eks:Create*`, `eks:Update*`, `eks:Delete*`, `eks:TagResource`, `eks:UntagResource`
- `elasticloadbalancing:Create*`, `elasticloadbalancing:Modify*`, `elasticloadbalancing:Delete*`
- `autoscaling:Create*`, `autoscaling:Update*`, `autoscaling:Delete*`
- `iam:Create*`, `iam:Update*`, `iam:Delete*`, `iam:Attach*`, `iam:Detach*`, `iam:PassRole`
- `logs:Create*`, `logs:Delete*`, `logs:PutRetentionPolicy`
- `acm:RequestCertificate`, `acm:DeleteCertificate`, `acm:AddTagsToCertificate`, `acm:RemoveTagsFromCertificate`
- `route53:ChangeResourceRecordSets`, `route53:Create*`, `route53:Delete*`
- `ssm:PutParameter`, `ssm:DeleteParameter`, `ssm:DeleteParameters`
- `secretsmanager:CreateSecret`, `secretsmanager:UpdateSecret`, `secretsmanager:DeleteSecret`, `secretsmanager:TagResource`, `secretsmanager:UntagResource`
- `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey`, `kms:DescribeKey`
- `s3:CreateBucket`, `s3:DeleteBucket`, `s3:PutBucket*`, `s3:DeleteBucket*`, `s3:PutObject`, `s3:DeleteObject`
- `dynamodb:CreateTable`, `dynamodb:UpdateTable`, `dynamodb:DeleteTable`, `dynamodb:TagResource`, `dynamodb:UntagResource`

## 6) AccessDenied 대응 규칙
- 에러가 `Describe/List/Get/ListTags*`면 Plan 정책에 추가 검토
- 에러가 `Create/Update/Delete/Put/Tag/Untag`면 Apply 정책에 추가 검토
- 추가 시:
  1. 최소 액션만 추가
  2. 가능한 경우 `Resource` ARN 범위 제한
  3. 변경 사유를 PR/MR에 기록

## 7) 검증 절차
1. IAM 시뮬레이션
```bash
aws iam simulate-principal-policy \
  --policy-source-arn <PLAN_ROLE_ARN> \
  --action-names ssm:ListTagsForResource logs:ListTagsForResource eks:ListTagsForResource \
  --resource-arns <RESOURCE_ARN_1> <RESOURCE_ARN_2> <RESOURCE_ARN_3>
```

2. Terraform plan smoke
- `shared/dev/prod`에서 plan 수행
- AccessDenied 발생 시 액션명을 수집해 6장 규칙대로 분류

## 8) 최근 AccessDenied 이슈 (2026-02-17)
발생 파이프라인: `plan:shared` (`tamacoach-shared-tf-plan-role`)

부족 권한:
- `ssm:ListTagsForResource`
- `logs:ListTagsForResource`

에러 대상 리소스:
- `arn:aws:ssm:ap-northeast-2:193629269600:parameter/tamacoach/shared/network/vpc_id`
- `arn:aws:ssm:ap-northeast-2:193629269600:parameter/tamacoach/shared/network/s3_gateway_vpce_id`
- `arn:aws:ssm:ap-northeast-2:193629269600:parameter/tamacoach/shared/network/public_subnet_ids`
- `arn:aws:ssm:ap-northeast-2:193629269600:parameter/tamacoach/shared/network/private_subnet_ids`
- `arn:aws:ssm:ap-northeast-2:193629269600:parameter/tamacoach/shared/network/db_subnet_ids`
- `arn:aws:ssm:ap-northeast-2:193629269600:parameter/tamacoach/shared/network/db_route_table_ids`
- `arn:aws:ssm:ap-northeast-2:193629269600:parameter/tamacoach/shared/network/sg_ids`
- `arn:aws:logs:ap-northeast-2:193629269600:log-group:/aws/vpc/flow-logs/tm-shared`

재발 방지 조치:
- `modules/iam-gitlab-oidc/main.tf`의 plan policy(`GeneralReadForPlan`)에
  `ssm:ListTagsForResource`, `logs:ListTagsForResource` 추가
- 향후 유사 이슈 방지를 위해 `eks:ListTagsForResource`도 포함 권장

## 9) 운영 체크리스트 (PR/MR 필수)
- [ ] 신규 리소스가 호출할 AWS API 확인
- [ ] Plan Role read 권한 충족 확인
- [ ] Apply Role mutation 권한 충족 확인
- [ ] IAM 시뮬레이션 결과 첨부
- [ ] Terraform plan 결과 첨부
