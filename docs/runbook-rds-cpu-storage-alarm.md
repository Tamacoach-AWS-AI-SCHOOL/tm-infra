# Runbook: RDS CPU/Storage Alarm

## 1) Purpose
Respond to RDS CPU or storage alarms before user-facing degradation.

## 2) Trigger
- CloudWatch alarm:
  - High CPU utilization
  - Low free storage space

## 3) Initial Scope Check
- Environment: `dev | prod`
- Alarm type: CPU / storage
- Duration: short spike vs sustained pressure

## 4) Quick Checks
```bash
# DB connectivity from backend pod
kubectl -n apps exec deploy/tm-app-<env>-backend -- sh -c 'python manage.py check'

# Backend DB-related errors
kubectl -n apps logs deploy/tm-app-<env>-backend --since=30m | grep -Ei "db|postgres|timeout|connection" -n

# (Optional) inspect active queries via psql if access is available
```

## 5) Common Root Causes
- Traffic spike / expensive query
- Missing index or slow query plan
- Long-running transaction
- Storage growth from data/log retention

## 6) Recovery Steps
1. Identify top offenders (query/connection/traffic).
2. Apply immediate mitigation (scale instance/storage or reduce load path).
3. Apply permanent fix (query/index/schema/job tuning).
4. Validate API latency and DB alarm recovery.

## 7) Exit Criteria
- Alarm returns to `OK`
- API response and DB errors normalize
- No sustained DB timeout/connection failures

## 8) Escalation
- Prod sustained impact > 10 minutes: DB owner + platform on-call.
- Imminent storage exhaustion: immediate emergency response.

