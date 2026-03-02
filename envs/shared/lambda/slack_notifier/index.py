import json
import os
import urllib.request

import boto3


ssm = boto3.client("ssm")

DEFAULT_GRAFANA_URL = "https://g-ae8080edb2.grafana-workspace.ap-northeast-2.amazonaws.com/dashboards"
DEFAULT_LOGS_URL = "https://ap-northeast-2.console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#logsV2:logs-insights"
DEFAULT_RUNBOOK_URL = "https://github.com/tamacoach/tm-infra/tree/develop/docs"

# env + alarm/finding name mapping for runbook/dashboard/log links
ALERT_LINKS = {
    "prod": {
        "tamacoach-prod-apigw-latency-p95": {
            "runbook_url": "https://github.com/tamacoach/tm-infra/blob/develop/docs/runbook-apigateway-latency-5xx.md",
            "grafana_url": DEFAULT_GRAFANA_URL,
            "cloudwatch_logs_insights_url": DEFAULT_LOGS_URL,
        },
        "tamacoach-prod-apigw-5xx": {
            "runbook_url": "https://github.com/tamacoach/tm-infra/blob/develop/docs/runbook-apigateway-latency-5xx.md",
            "grafana_url": DEFAULT_GRAFANA_URL,
            "cloudwatch_logs_insights_url": DEFAULT_LOGS_URL,
        },
        "tamacoach-prod-rds-cpu": {
            "runbook_url": "https://github.com/tamacoach/tm-infra/blob/develop/docs/runbook-rds-cpu-storage-alarm.md",
            "grafana_url": DEFAULT_GRAFANA_URL,
            "cloudwatch_logs_insights_url": DEFAULT_LOGS_URL,
        },
        "tamacoach-prod-rds-free-storage": {
            "runbook_url": "https://github.com/tamacoach/tm-infra/blob/develop/docs/runbook-rds-cpu-storage-alarm.md",
            "grafana_url": DEFAULT_GRAFANA_URL,
            "cloudwatch_logs_insights_url": DEFAULT_LOGS_URL,
        },
    },
    "dev": {
        "tamacoach-dev-apigw-latency-p95": {
            "runbook_url": "https://github.com/tamacoach/tm-infra/blob/develop/docs/runbook-apigateway-latency-5xx.md",
            "grafana_url": DEFAULT_GRAFANA_URL,
            "cloudwatch_logs_insights_url": DEFAULT_LOGS_URL,
        },
        "tamacoach-dev-apigw-5xx": {
            "runbook_url": "https://github.com/tamacoach/tm-infra/blob/develop/docs/runbook-apigateway-latency-5xx.md",
            "grafana_url": DEFAULT_GRAFANA_URL,
            "cloudwatch_logs_insights_url": DEFAULT_LOGS_URL,
        },
    },
}


def get_webhook_url():
    param_name = os.environ["SLACK_WEBHOOK_SSM_PARAM"]
    resp = ssm.get_parameter(Name=param_name, WithDecryption=True)
    return resp["Parameter"]["Value"]


def parse_payload(raw_record):
    msg = raw_record.get("Sns", {}).get("Message", "")
    try:
        parsed = json.loads(msg)
    except Exception:
        parsed = msg

    return parsed


def extract_fields(payload, default_env):
    env = default_env
    service = "unknown"
    severity = "P2"
    title = "Alert"
    link = ""
    resource = "-"
    datapoint = "-"

    if isinstance(payload, dict):
        source = payload.get("source", "")

        # CloudWatch Alarm -> SNS
        if payload.get("AlarmName"):
            title = payload.get("AlarmName", title)
            reason = payload.get("NewStateReason", "")
            service = payload.get("Trigger", {}).get("Namespace", "cloudwatch")
            # alarm_description contains "severity=P1 ..."
            alarm_description = payload.get("AlarmDescription", "")
            env = payload.get("AlarmName", "").split("-")[1] if "-" in payload.get("AlarmName", "") else env
            if "severity=P1" in alarm_description:
                severity = "P1"
            elif "severity=P0" in alarm_description:
                severity = "P0"
            else:
                severity = "P2"
            link = reason
            resource = payload.get("Trigger", {}).get("MetricName", "-")
            datapoint = payload.get("NewStateReason", "-")
            if payload.get("NewStateValue") == "OK" and severity in {"P0", "P1"}:
                severity = "INFO"

        # SecurityHub EventBridge
        elif source == "aws.securityhub":
            title = payload.get("detail-type", "SecurityHub Finding")
            service = "securityhub"
            finding = (payload.get("detail", {}).get("findings", [{}]) or [{}])[0]
            sev = (
                finding.get("Severity", {}).get("Label")
                or finding.get("Severity", {}).get("Normalized")
            )
            severity = str(sev) if sev is not None else "HIGH"
            link = finding.get("ProductArn", "")
            resource = finding.get("Id", "-")
            datapoint = finding.get("Title", "-")

        # GuardDuty EventBridge
        elif source == "aws.guardduty":
            title = payload.get("detail-type", "GuardDuty Finding")
            service = "guardduty"
            numeric = payload.get("detail", {}).get("severity", 0)
            severity = "CRITICAL" if float(numeric) >= 8 else "HIGH"
            link = payload.get("detail", {}).get("id", "")
            resource = payload.get("detail", {}).get("resource", {}).get("resourceType", "-")
            datapoint = f"score={numeric}"

        # Custom message shape
        else:
            env = payload.get("env", env)
            service = payload.get("service", service)
            severity = payload.get("severity", severity)
            title = payload.get("title", title)
            link = payload.get("link", link)
            resource = payload.get("resource", resource)
            datapoint = payload.get("datapoint", datapoint)
    else:
        title = str(payload)

    return env, service, str(severity), title, link, resource, datapoint


def resolve_links(env, title):
    env_map = ALERT_LINKS.get(env, {})
    link_set = env_map.get(title)
    if link_set:
        return link_set
    return {
        "runbook_url": DEFAULT_RUNBOOK_URL,
        "grafana_url": DEFAULT_GRAFANA_URL,
        "cloudwatch_logs_insights_url": DEFAULT_LOGS_URL,
    }


def mention_for(severity):
    rule = os.environ.get("MENTION_RULE", "none")
    up = severity.upper()
    if rule == "p1_here" and up in {"P1", "P0", "CRITICAL", "HIGH"}:
        return "@here "
    if rule == "critical_here" and up in {"CRITICAL", "P0"}:
        return "@here "
    return ""


def post_to_slack(webhook_url, text):
    body = json.dumps({"text": text}).encode("utf-8")
    req = urllib.request.Request(
        webhook_url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(f"slack post failed: {resp.status}")


def handler(event, context):
    webhook_url = get_webhook_url()
    default_env = os.environ.get("ALERT_ENV", "unknown")
    records = event.get("Records", [])
    if not records:
        return {"ok": True, "records": 0}

    for r in records:
        payload = parse_payload(r)
        env, service, severity, title, link, resource, datapoint = extract_fields(payload, default_env)
        links = resolve_links(env, title)
        mention = mention_for(severity)
        text = (
            f"{mention}[{env}] [{service}] [{severity}] {title}\n"
            f"resource: {resource}\n"
            f"datapoint: {datapoint}\n"
            f"event: {link if link else '-'}\n"
            f"runbook: {links['runbook_url']}\n"
            f"dashboard: {links['grafana_url']}\n"
            f"logs: {links['cloudwatch_logs_insights_url']}"
        )
        post_to_slack(webhook_url, text)

    return {"ok": True, "records": len(records)}
