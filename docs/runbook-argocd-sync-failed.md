# Runbook: ArgoCD Sync Failed

## 1) Purpose
Recover quickly when ArgoCD application sync fails and restore service state.

## 2) Trigger
- Slack alert: ArgoCD sync failed
- ArgoCD status: `OutOfSync`, `Degraded`, or `Sync Failed`

## 3) Initial Impact Check (within 5 minutes)
- Application: `<app-name>`
- Environment: `dev | prod`
- User impact:
  - [ ] No user impact
  - [ ] Partial degradation
  - [ ] Major outage

## 4) Quick Checks
```bash
kubectl -n argocd get applications.argoproj.io
kubectl -n argocd describe application <app-name>
kubectl -n argocd logs deploy/argocd-application-controller --since=15m | grep -i "<app-name>"
```

## 5) Common Root Causes
- Bad manifest change (YAML/value/image digest)
- Permission issue (IRSA/IAM/RBAC)
- Immutable field conflict
- Missing dependency (CRD/Secret/ConfigMap)
- Cluster-level issue (node/network)

## 6) Recovery Steps
1. Retry sync once from ArgoCD UI/CLI.
2. If still failing, rollback manifest to last known good revision and re-sync.
3. If dependency/infrastructure issue is confirmed, apply Terraform in `tm-infra` and re-sync.

## 7) Exit Criteria
- App status: `Synced`
- Health status: `Healthy`
- Core health endpoint passes
- No re-fire for 15 minutes

## 8) Escalation
- If not recovered in 15 minutes: escalate to platform on-call.
- If prod wide impact: open incident channel immediately.

## 9) Postmortem Notes
- Start/end time
- Root cause
- Actions taken
- Preventive action items
- Links (ArgoCD app, PR/MR, logs, Slack thread)

