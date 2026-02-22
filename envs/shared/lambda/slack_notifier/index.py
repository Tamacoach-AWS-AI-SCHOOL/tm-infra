import json
import os
import urllib.request

import boto3


ssm = boto3.client("ssm")


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

    if isinstance(payload, dict):
        source = payload.get("source", "")

        # CloudWatch Alarm -> SNS
        if payload.get("AlarmName"):
            title = payload.get("AlarmName", title)
            reason = payload.get("NewStateReason", "")
            service = payload.get("Trigger", {}).get("Namespace", "cloudwatch")
            # alarm_description contains "severity=P1 ..."
            alarm_description = payload.get("AlarmDescription", "")
            if "severity=P1" in alarm_description:
                severity = "P1"
            elif "severity=P0" in alarm_description:
                severity = "P0"
            else:
                severity = "P2"
            link = reason

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

        # GuardDuty EventBridge
        elif source == "aws.guardduty":
            title = payload.get("detail-type", "GuardDuty Finding")
            service = "guardduty"
            numeric = payload.get("detail", {}).get("severity", 0)
            severity = "CRITICAL" if float(numeric) >= 8 else "HIGH"
            link = payload.get("detail", {}).get("id", "")

        # Custom message shape
        else:
            env = payload.get("env", env)
            service = payload.get("service", service)
            severity = payload.get("severity", severity)
            title = payload.get("title", title)
            link = payload.get("link", link)
    else:
        title = str(payload)

    return env, service, str(severity), title, link


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
        env, service, severity, title, link = extract_fields(payload, default_env)
        mention = mention_for(severity)
        text = (
            f"{mention}[{env}] [{service}] [{severity}] {title}\n"
            f"link: {link if link else '-'}"
        )
        post_to_slack(webhook_url, text)

    return {"ok": True, "records": len(records)}

