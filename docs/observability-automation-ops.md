# Observability Automation Ops Guide

## Scope
This guide covers 3 automations in `envs/shared`:
- Alarm -> Jira ticket (`ticket_notifier`)
- Slack alert enrichment with runbook/dashboard/log links (`slack_notifier`)
- GuardDuty/SecurityHub routing (`security_router`)

## Prerequisites
- Shared stack apply permission
- Jira project/API token prepared
- Slack channels configured:
  - `#alerts-prod`
  - `#security-prod`
  - `#deployments`

## 1) Required SecureString Parameters
Store these before apply:

```bash
aws ssm put-parameter --region ap-northeast-2 --name /tamacoach/shared/jira/base_url --type SecureString --value "https://<your-org>.atlassian.net" --overwrite
aws ssm put-parameter --region ap-northeast-2 --name /tamacoach/shared/jira/email --type SecureString --value "<jira-email>" --overwrite
aws ssm put-parameter --region ap-northeast-2 --name /tamacoach/shared/jira/api_token --type SecureString --value "<jira-api-token>" --overwrite
aws ssm put-parameter --region ap-northeast-2 --name /tamacoach/shared/jira/project_key --type SecureString --value "WEFJ" --overwrite
```

## 2) Apply Order
1. `terraform -chdir=envs/shared init`
2. `terraform -chdir=envs/shared plan`
3. `terraform -chdir=envs/shared apply`

## 3) Validation Commands

### Terraform
```bash
terraform fmt envs/shared/observability_alerts.tf
terraform -chdir=envs/shared validate
```

### Deployed resources
```bash
aws lambda get-function --region ap-northeast-2 --function-name tamacoach-shared-ticket-notifier
aws lambda get-function --region ap-northeast-2 --function-name tamacoach-shared-security-router
aws dynamodb describe-table --region ap-northeast-2 --table-name tamacoach-shared-alert-ticket-dedupe
aws dynamodb describe-table --region ap-northeast-2 --table-name tamacoach-shared-security-low-agg
```

## 4) Test Commands

### 4.1 CloudWatch alarm path -> Jira ticket
Publish synthetic SNS payload (replace topic ARN):
```bash
aws sns publish \
  --region ap-northeast-2 \
  --topic-arn arn:aws:sns:ap-northeast-2:193629269600:tamacoach-prod-alerts \
  --message '{"AlarmName":"tamacoach-prod-apigw-latency-p95","AlarmDescription":"severity=P1 service=apigw metric=latency-p95","NewStateValue":"ALARM","NewStateReason":"test alarm"}'
```

### 4.2 SecurityHub sample event -> security_router
```bash
aws events put-events --region ap-northeast-2 --entries '[
  {
    "Source":"aws.securityhub",
    "DetailType":"Security Hub Findings - Imported",
    "Detail":"{\"findings\":[{\"Id\":\"test-finding-1\",\"Title\":\"Test SecurityHub Finding\",\"Severity\":{\"Label\":\"MEDIUM\"},\"Workflow\":{\"Status\":\"NEW\"},\"Resources\":[{\"Id\":\"arn:aws:ec2:ap-northeast-2:193629269600:instance/i-1234567890\"}]}]}"
  }
]'
```

### 4.3 GuardDuty sample event -> security_router
```bash
aws events put-events --region ap-northeast-2 --entries '[
  {
    "Source":"aws.guardduty",
    "DetailType":"GuardDuty Finding",
    "Detail":"{\"id\":\"gd-test-1\",\"severity\":8.2,\"title\":\"Test GuardDuty Finding\",\"resource\":{\"resourceType\":\"Instance\"}}"
  }
]'
```

## 5) Runtime Log Checks
```bash
aws logs tail /aws/lambda/tamacoach-shared-ticket-notifier --since 30m --region ap-northeast-2
aws logs tail /aws/lambda/tamacoach-shared-security-router --since 30m --region ap-northeast-2
aws logs tail /aws/lambda/tamacoach-shared-slack-notifier-prod --since 30m --region ap-northeast-2
aws logs tail /aws/lambda/tamacoach-shared-slack-notifier-prod_security --since 30m --region ap-northeast-2
```

## 6) Operational Notes
- `ticket_notifier` dedupe key: `alarmName + resource + alarmStartTime` concept is enforced by table `tamacoach-shared-alert-ticket-dedupe`.
- Security `LOW` findings are aggregated in `tamacoach-shared-security-low-agg`.
- `#security-prod` mention behavior for high/critical is driven through `MENTION_RULE=p1_here` on prod security notifier.
