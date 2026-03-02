import json
import os
import time
import urllib.request
from base64 import b64encode

import boto3


ssm = boto3.client("ssm")
dynamodb = boto3.resource("dynamodb")

JIRA_PARAM_BASE_URL = os.environ["JIRA_BASE_URL_PARAM"]
JIRA_PARAM_EMAIL = os.environ["JIRA_EMAIL_PARAM"]
JIRA_PARAM_API_TOKEN = os.environ["JIRA_API_TOKEN_PARAM"]
JIRA_PARAM_PROJECT_KEY = os.environ["JIRA_PROJECT_KEY_PARAM"]
DEDUPE_TABLE_NAME = os.environ["DEDUPE_TABLE_NAME"]
DEDUPE_WINDOW_SECONDS = int(os.environ.get("DEDUPE_WINDOW_SECONDS", "1800"))
JIRA_ISSUE_TYPE = os.environ.get("JIRA_ISSUE_TYPE", "작업")


def get_secure_param(name):
    return ssm.get_parameter(Name=name, WithDecryption=True)["Parameter"]["Value"]


def get_jira_config():
    return {
        "base_url": get_secure_param(JIRA_PARAM_BASE_URL).rstrip("/"),
        "email": get_secure_param(JIRA_PARAM_EMAIL),
        "api_token": get_secure_param(JIRA_PARAM_API_TOKEN),
        "project_key": get_secure_param(JIRA_PARAM_PROJECT_KEY),
    }


def parse_record(record):
    message = record.get("Sns", {}).get("Message", "")
    try:
        payload = json.loads(message)
    except Exception:
        payload = {"raw_message": message}
    return payload


def severity_from_payload(payload):
    desc = payload.get("AlarmDescription", "")
    if "severity=P0" in desc:
        return "P0"
    if "severity=P1" in desc:
        return "P1"
    if "severity=P2" in desc:
        return "P2"
    return "P2"


def should_create_ticket(payload):
    if payload.get("AlarmName"):
        return payload.get("NewStateValue") == "ALARM"
    # custom payload support if needed
    if payload.get("should_create_ticket") is True:
        return True
    return False


def dedupe_key(payload):
    if payload.get("AlarmName"):
        alarm_name = payload.get("AlarmName", "unknown")
        trigger = payload.get("Trigger", {})
        resource = trigger.get("Dimensions", [{}])
        resource_blob = json.dumps(resource, sort_keys=True)
        started = payload.get("StateChangeTime", payload.get("AlarmConfigurationUpdatedTimestamp", "unknown"))
        return f"{alarm_name}|{resource_blob}|{started}"
    return payload.get("dedupe_key", f"custom|{int(time.time())}")


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


def build_issue(payload, severity):
    alarm_name = payload.get("AlarmName", "CloudWatch Alarm")
    reason = payload.get("NewStateReason", "-")
    env = "prod" if "-prod-" in alarm_name else "dev" if "-dev-" in alarm_name else "unknown"
    summary = f"[{env}] [{severity}] {alarm_name}"
    description = {
        "version": 1,
        "type": "doc",
        "content": [
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": f"Alarm: {alarm_name}"}],
            },
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": f"Reason: {reason}"}],
            },
        ],
    }
    return summary, description


def create_jira_issue(jira, summary, description):
    payload = {
        "fields": {
            "project": {"key": jira["project_key"]},
            "summary": summary,
            "issuetype": {"name": JIRA_ISSUE_TYPE},
            "description": description,
            "labels": ["auto-alert"],
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
        return json.loads(body)


def handler(event, context):
    table = dynamodb.Table(DEDUPE_TABLE_NAME)
    jira = get_jira_config()

    created = []
    skipped = 0
    for record in event.get("Records", []):
        payload = parse_record(record)
        if not should_create_ticket(payload):
            skipped += 1
            continue
        key = dedupe_key(payload)
        if dedupe_check_and_mark(table, key):
            skipped += 1
            continue
        severity = severity_from_payload(payload)
        summary, description = build_issue(payload, severity)
        issue = create_jira_issue(jira, summary, description)
        created.append(issue.get("key"))

    return {"ok": True, "created": created, "skipped": skipped}
