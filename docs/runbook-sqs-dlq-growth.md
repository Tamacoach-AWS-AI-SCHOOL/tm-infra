# Runbook: SQS DLQ Message Growth

## 1) Purpose
Resolve dead-letter queue accumulation and restore consumer processing.

## 2) Trigger
- CloudWatch alarm on DLQ visible messages
- Worker error logs repeatedly failing same message

## 3) Initial Scope Check
- Queue name: `<queue>`
- DLQ name: `<dlq>`
- Environment: `dev | prod`
- Growth trend: single spike vs continuous increase

## 4) Quick Checks
```bash
# Queue attributes
aws sqs get-queue-attributes --region ap-northeast-2 --queue-url "<DLQ_URL>" --attribute-names ApproximateNumberOfMessages

# Worker logs
kubectl -n apps logs deploy/tm-app-<env>-worker --since=30m | tail -n 300

# Worker env sanity
kubectl -n apps exec deploy/tm-app-<env>-worker -- sh -c 'echo $SQS_CONSUME_QUEUE_URL'
```

## 5) Common Root Causes
- Wrong queue URL/ARN in secret
- Permission denied (`ReceiveMessage/DeleteMessage`)
- Callback/processing exception loops
- Downstream dependency timeout

## 6) Recovery Steps
1. Fix queue URL/secret mismatch and restart affected deployment.
2. Fix IAM/IRSA permissions if AccessDenied is present.
3. Fix app exception causing retries.
4. Redrive DLQ messages after fix validation.

## 7) Exit Criteria
- DLQ count stops increasing
- Consumer processes new messages successfully
- No repeated failure signature in logs

## 8) Escalation
- Prod DLQ keeps increasing for > 15 minutes: escalate to backend + platform on-call.

