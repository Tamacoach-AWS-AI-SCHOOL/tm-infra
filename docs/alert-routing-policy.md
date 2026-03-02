# Alert Routing Policy (Prod)

## 1. Purpose
Define a single operational policy for:
- Slack channel routing
- Auto ticket creation criteria
- Paging criteria
- Deduplication and reopen rules

## 2. Slack Channel Policy

### `#alerts-prod`
- Scope: all production operational alerts
- Primary audience: on-call + platform
- Goal: real-time service health awareness

### `#security-prod`
- Scope: GuardDuty and SecurityHub findings
- Primary audience: security owner + on-call
- Goal: isolate security response workflow from general ops noise

### `#deployments`
- Scope: ArgoCD deployment events (sync success/failure, degraded health)
- Primary audience: application teams + platform
- Goal: deployment visibility and rollback decision support

## 3. Severity Model
- `P1` page immediately (service impact or imminent impact)
- `P2` create ticket automatically and notify Slack
- `P3` notify Slack only, include runbook link
- `P4` informational or daily summary only

## 4. Paging and Ticket Rules

### 4.1 Page Immediately (`P1`)
- API Gateway p95 latency above threshold for sustained window
- API 5xx rate above threshold for sustained window
- RDS storage critical threshold reached
- Security finding severity `HIGH` or `CRITICAL`

Action:
- Send to `#alerts-prod` (or `#security-prod` for security findings)
- Trigger pager
- Create/attach incident ticket

### 4.2 Auto Ticket (`P2`)
- `PodRestartsHigh`
- `NodeCpuSaturation`
- `NodeMemorySaturation`
- `ArgoCD sync failed`
- `DLQ` message depth above threshold
- Security finding severity `MEDIUM`

Action:
- Send Slack notification with runbook and dashboard links
- Auto-create Jira issue in project `WEFJ`

### 4.3 Notify Only (`P3`)
- ArgoCD sync success
- short-lived warning that self-recovers within policy window
- Security finding severity `LOW`

Action:
- Slack only
- no ticket unless repeated beyond threshold

## 5. Deduplication and Reopen Policy
- Dedup key: `alarm_name + resource + env`
- Dedup window: 30 minutes
- If alarm returns to `OK` and later goes `ALARM` again, open a new ticket
- Keep all repeated updates as comments on the same open ticket inside dedup window

## 6. Ownership Mapping
- `service=api` -> backend owner
- `service=infra` -> platform owner
- `service=security` -> security owner
- If owner is unknown, fallback to on-call platform owner

## 7. Required Message Fields
Every alert message must include:
- environment (`dev`/`prod`)
- alarm/finding name
- resource identifier
- severity and current state
- runbook URL
- dashboard URL (AMG/CloudWatch)
- logs query URL (if available)

## 8. Review Cycle
- Weekly: alert noise review (false positives, flapping, threshold tuning)
- Monthly: severity mapping and owner mapping review
- Quarterly: runbook freshness audit
