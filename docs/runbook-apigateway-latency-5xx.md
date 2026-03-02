# Runbook: API Gateway Latency/5xx

## 1) Purpose
Handle high latency or 5xx errors on API Gateway and restore stable response.

## 2) Trigger
- CloudWatch alarm:
  - `tamacoach-*-apigw-latency-p95`
  - `tamacoach-*-apigw-5xx`

## 3) Initial Scope Check
- Environment: `dev | prod`
- Symptom: latency only / 5xx / both
- Affected route: `/api/*` specific path if known

## 4) Quick Checks
```bash
# API health check
curl -i https://api-stage.tamacoach.net/api/health
curl -i https://api.tamacoach.net/api/health

# Backend pods and endpoints
kubectl -n apps get pods -l app.kubernetes.io/component=backend -o wide
kubectl -n apps get svc tm-app-<env>-backend
kubectl -n apps get endpoints tm-app-<env>-backend

# Recent backend errors
kubectl -n apps logs deploy/tm-app-<env>-backend --since=30m | tail -n 200
```

## 5) Common Root Causes
- Backend app error (exceptions, dependency errors)
- No healthy endpoints behind service
- IAM/IRSA permission error
- External dependency slowdown (DB/Bedrock/queue)

## 6) Recovery Steps
1. Confirm backend readiness and endpoint population.
2. Fix immediate app/config issue (secret/env mismatch, rollout restart if needed).
3. If infra dependency issue, apply targeted Terraform fix.
4. Re-check latency and 5xx metrics for at least 15 minutes.

## 7) Exit Criteria
- Health endpoint stable
- No sustained 5xx
- Latency alarm returns to `OK`

## 8) Escalation
- Prod customer impact > 10 minutes: incident escalation.
- Cross-service issue suspected: engage platform + app owners.

