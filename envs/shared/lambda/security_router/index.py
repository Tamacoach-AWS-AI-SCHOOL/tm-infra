import json
import os
import time
import urllib.request
from base64 import b64encode
from datetime import datetime, timezone

import boto3


ssm = boto3.client("ssm")
sns = boto3.client("sns")
dynamodb = boto3.resource("dynamodb")

JIRA_PARAM_BASE_URL = os.environ["JIRA_BASE_URL_PARAM"]
JIRA_PARAM_EMAIL = os.environ["JIRA_EMAIL_PARAM"]
JIRA_PARAM_API_TOKEN = os.environ["JIRA_API_TOKEN_PARAM"]
JIRA_PARAM_PROJECT_KEY = os.environ["JIRA_PROJECT_KEY_PARAM"]
SECURITY_TOPIC_ARN = os.environ["SECURITY_TOPIC_ARN"]
DEDUPE_TABLE_NAME = os.environ["DEDUPE_TABLE_NAME"]
LOW_AGG_TABLE_NAME = os.environ["LOW_AGG_TABLE_NAME"]
DEDUPE_WINDOW_SECONDS = int(os.environ.get("DEDUPE_WINDOW_SECONDS", "1800"))
JIRA_ISSUE_TYPE = os.environ.get("JIRA_ISSUE_TYPE", "작업")
MEDIUM_JIRA_ENABLED = os.environ.get("MEDIUM_JIRA_ENABLED", "false").lower() == "true"


def get_secure_param(name):
    return ssm.get_parameter(Name=name, WithDecryption=True)["Parameter"]["Value"]


def get_jira_config():
    return {
        "base_url": get_secure_param(JIRA_PARAM_BASE_URL).rstrip("/"),
        "email": get_secure_param(JIRA_PARAM_EMAIL),
        "api_token": get_secure_param(JIRA_PARAM_API_TOKEN),
        "project_key": get_secure_param(JIRA_PARAM_PROJECT_KEY),
    }


def map_securityhub_severity(finding):
    label = (finding.get("Severity", {}) or {}).get("Label", "")
    up = str(label).upper()
    if up in {"CRITICAL", "HIGH", "MEDIUM", "LOW"}:
        return up
    normalized = (finding.get("Severity", {}) or {}).get("Normalized", 0)
    try:
        n = int(normalized)
    except Exception:
        n = 0
    if n >= 90:
        return "CRITICAL"
    if n >= 70:
        return "HIGH"
    if n >= 40:
        return "MEDIUM"
    return "LOW"


def map_guardduty_severity(detail):
    score = float(detail.get("severity", 0))
    if score >= 8:
        return "CRITICAL"
    if score >= 5:
        return "HIGH"
    if score >= 3:
        return "MEDIUM"
    return "LOW"


def extract_event(event):
    source = event.get("source", "unknown")
    detail = event.get("detail", {}) or {}
    detail_type = event.get("detail-type", "Security Finding")

    if source == "aws.securityhub":
        finding = (detail.get("findings", [{}]) or [{}])[0]
        severity = map_securityhub_severity(finding)
        finding_id = finding.get("Id", "unknown")
        title = finding.get("Title", detail_type)
        resource = ((finding.get("Resources", [{}]) or [{}])[0]).get("Id", "unknown")
        service = "securityhub"
        raw_link = finding.get("ProductArn", "")
        workflow_status = ((finding.get("Workflow", {}) or {}).get("Status", "") or "").upper()
        record_state = (finding.get("RecordState", "") or "").upper()
    elif source == "aws.guardduty":
        severity = map_guardduty_severity(detail)
        finding_id = detail.get("id", "unknown")
        title = detail.get("title", detail_type)
        resource = (detail.get("resource", {}) or {}).get("resourceType", "unknown")
        service = "guardduty"
        raw_link = finding_id
        workflow_status = ""
        record_state = ""
    else:
        severity = "LOW"
        finding_id = "unknown"
        title = detail_type
        resource = "unknown"
        service = source
        raw_link = ""
        workflow_status = ""
        record_state = ""

    return {
        "source": source,
        "service": service,
        "severity": severity,
        "finding_id": finding_id,
        "title": title,
        "resource": resource,
        "link": raw_link,
        "workflow_status": workflow_status,
        "record_state": record_state,
    }


def publish_security_message(event_data):
    sev = event_data["severity"]
    slack_sev = "P1" if sev in {"HIGH", "CRITICAL"} else "P2"
    message = {
        "env": "prod",
        "service": event_data["service"],
        "severity": slack_sev,
        "title": f"{event_data['title']} ({sev})",
        "link": event_data["link"],
        "resource": event_data["resource"],
        "datapoint": f"finding_id={event_data['finding_id']}",
    }
    sns.publish(TopicArn=SECURITY_TOPIC_ARN, Message=json.dumps(message))


def dedupe_check_and_mark(table, key):
    now = int(time.time())
    item = table.get_item(Key={"dedupe_key": key}).get("Item")
    if item:
        last_seen = int(item.get("last_seen_epoch", 0))
        if now - last_seen <= DEDUPE_WINDOW_SECONDS:
            return True
    table.put_item(
        Item={
            "dedupe_key": key,
            "last_seen_epoch": now,
            "ttl_epoch": now + (7 * 24 * 60 * 60),
        }
    )
    return False


def create_jira_issue(jira, event_data):
    summary = f"[prod] [security] [{event_data['severity']}] {event_data['title']}"
    description = {
        "version": 1,
        "type": "doc",
        "content": [
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": f"Service: {event_data['service']}"}],
            },
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": f"Finding ID: {event_data['finding_id']}"}],
            },
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": f"Resource: {event_data['resource']}"}],
            },
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": f"Link: {event_data['link'] or '-'}"}],
            },
        ],
    }
    payload = {
        "fields": {
            "project": {"key": jira["project_key"]},
            "summary": summary,
            "issuetype": {"name": JIRA_ISSUE_TYPE},
            "description": description,
            "labels": ["security-auto", event_data["service"]],
        }
    }
    token = b64encode(f"{jira['email']}:{jira['api_token']}".encode("utf-8")).decode("ascii")
    req = urllib.request.Request(
        f"{jira['base_url']}/rest/api/3/issue",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Basic {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read().decode("utf-8") if resp.length else "{}"
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(f"jira create failed: {resp.status} {body}")


def aggregate_finding(table, event_data, severity):
    day_key = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    agg_key = f"{day_key}|{event_data['service']}|{severity}"
    table.update_item(
        Key={"aggregate_key": agg_key},
        UpdateExpression="ADD finding_count :inc SET updated_at = :ts",
        ExpressionAttributeValues={
            ":inc": 1,
            ":ts": datetime.now(timezone.utc).isoformat(),
        },
    )


def handler(event, context):
    event_data = extract_event(event)
    severity = event_data["severity"]
    dedupe_table = dynamodb.Table(DEDUPE_TABLE_NAME)
    low_table = dynamodb.Table(LOW_AGG_TABLE_NAME)

    # SecurityHub noise control: process only active/new findings.
    if event_data["source"] == "aws.securityhub":
        if event_data["record_state"] and event_data["record_state"] != "ACTIVE":
            return {"ok": True, "route": "ignored_record_state"}
        if event_data["workflow_status"] and event_data["workflow_status"] != "NEW":
            return {"ok": True, "route": "ignored_workflow_status"}

    if severity in {"HIGH", "CRITICAL"}:
        key = f"security|{event_data['source']}|{event_data['finding_id']}|{severity}"
        if dedupe_check_and_mark(dedupe_table, key):
            return {"ok": True, "route": "high_critical_deduped"}
        publish_security_message(event_data)
        return {"ok": True, "route": "high_critical"}

    if severity == "MEDIUM":
        # Default: aggregate medium findings to prevent Jira/Slack flood.
        if not MEDIUM_JIRA_ENABLED:
            aggregate_finding(low_table, event_data, "MEDIUM")
            return {"ok": True, "route": "medium_aggregated"}
        hour_bucket = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H")
        key = f"security|{event_data['source']}|{event_data['service']}|{event_data['resource']}|MEDIUM|{hour_bucket}"
        if dedupe_check_and_mark(dedupe_table, key):
            return {"ok": True, "route": "medium_deduped"}
        jira = get_jira_config()
        create_jira_issue(jira, event_data)
        return {"ok": True, "route": "medium_ticket_created"}

    aggregate_finding(low_table, event_data, "LOW")
    return {"ok": True, "route": "low_aggregated"}
