locals {
  observability_metrics_envs = {
    for env, cfg in local.backend_envs : env => {
      topic_arn = aws_sns_topic.observability_alerts[env].arn
    }
  }
}

resource "aws_prometheus_workspace" "observability" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  alias = var.amp_workspace_alias
  tags = merge(local.common_tags, {
    Name    = var.amp_workspace_alias
    Service = "observability"
  })
}

resource "aws_ssm_parameter" "observability_amp_workspace_id" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  name      = "${local.ssm_shared_prefix}/obs/metrics/amp/workspace_id"
  type      = "String"
  value     = aws_prometheus_workspace.observability[0].id
  overwrite = true
}

resource "aws_ssm_parameter" "observability_amp_workspace_arn" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  name      = "${local.ssm_shared_prefix}/obs/metrics/amp/workspace_arn"
  type      = "String"
  value     = aws_prometheus_workspace.observability[0].arn
  overwrite = true
}

resource "aws_ssm_parameter" "observability_amp_remote_write_endpoint" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  name      = "${local.ssm_shared_prefix}/obs/metrics/amp/remote_write_endpoint"
  type      = "String"
  value     = "${aws_prometheus_workspace.observability[0].prometheus_endpoint}api/v1/remote_write"
  overwrite = true
}

data "aws_iam_policy_document" "observability_amp_remote_write" {
  for_each = var.enable_observability_metrics_platform ? local.observability_metrics_envs : {}

  statement {
    sid    = "AllowAmpRemoteWrite"
    effect = "Allow"
    actions = [
      "aps:RemoteWrite",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]
    resources = [aws_prometheus_workspace.observability[0].arn]
  }
}

resource "aws_iam_policy" "observability_amp_remote_write" {
  for_each = data.aws_iam_policy_document.observability_amp_remote_write

  name   = "${var.project}-${each.key}-adot-amp-remote-write"
  policy = each.value.json
  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-adot-amp-remote-write"
    Service = "observability"
    Env     = each.key
  })
}

resource "aws_prometheus_rule_group_namespace" "observability_baseline" {
  for_each = var.enable_observability_metrics_platform ? local.observability_metrics_envs : {}

  name         = "${var.project}-${each.key}-baseline"
  workspace_id = aws_prometheus_workspace.observability[0].id
  data         = <<-EOT
groups:
  - name: ${var.project}-${each.key}-kubernetes-baseline
    rules:
      - alert: ${title(each.key)}KubeNodeNotReady
        expr: max by (node) (kube_node_status_condition{condition="Ready",status="true",env="${each.key}"} == 0) > 0
        for: 5m
        labels:
          severity: warning
          env: ${each.key}
          service: kubernetes
        annotations:
          summary: "Node not ready (${each.key})"
      - alert: ${title(each.key)}PodRestartsHigh
        expr: sum by (namespace, pod) (increase(kube_pod_container_status_restarts_total{env="${each.key}"}[10m])) > 5
        for: 10m
        labels:
          severity: warning
          env: ${each.key}
          service: kubernetes
        annotations:
          summary: "Pod restarts are high (${each.key})"
      - alert: ${title(each.key)}NodeCpuSaturation
        expr: (100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle",env="${each.key}"}[5m])) * 100)) > 90
        for: 10m
        labels:
          severity: critical
          env: ${each.key}
          service: infrastructure
        annotations:
          summary: "Node CPU saturation (${each.key})"
      - alert: ${title(each.key)}NodeMemorySaturation
        expr: ((1 - (node_memory_MemAvailable_bytes{env="${each.key}"} / node_memory_MemTotal_bytes{env="${each.key}"})) * 100) > 90
        for: 10m
        labels:
          severity: critical
          env: ${each.key}
          service: infrastructure
        annotations:
          summary: "Node memory saturation (${each.key})"
      - alert: ${title(each.key)}ApiServer5xxRateHigh
        expr: (sum(rate(apiserver_request_total{code=~"5..",env="${each.key}"}[5m])) / clamp_min(sum(rate(apiserver_request_total{env="${each.key}"}[5m])), 1)) > 0.05
        for: 5m
        labels:
          severity: critical
          env: ${each.key}
          service: apiserver
        annotations:
          summary: "API server 5xx rate is high (${each.key})"
      - alert: ${title(each.key)}ApiServerLatencyP95High
        expr: histogram_quantile(0.95, sum by (le) (rate(apiserver_request_duration_seconds_bucket{env="${each.key}"}[5m]))) > 1
        for: 10m
        labels:
          severity: warning
          env: ${each.key}
          service: apiserver
        annotations:
          summary: "API server latency p95 is high (${each.key})"
  EOT
}

resource "aws_prometheus_alert_manager_definition" "observability" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  workspace_id = aws_prometheus_workspace.observability[0].id
  definition   = <<-EOT
alertmanager_config: |
  route:
    receiver: dev-alerts
    group_by: ["alertname", "env", "cluster"]
    group_wait: 30s
    group_interval: 5m
    repeat_interval: 4h
    routes:
      - receiver: dev-alerts
        matchers:
          - env="dev"
      - receiver: prod-alerts
        matchers:
          - env="prod"
  receivers:
    - name: dev-alerts
      sns_configs:
        - topic_arn: ${aws_sns_topic.observability_alerts["dev"].arn}
          sigv4:
            region: ${var.aws_region}
          subject: "[AMP][dev] {{ .CommonLabels.alertname }}"
    - name: prod-alerts
      sns_configs:
        - topic_arn: ${aws_sns_topic.observability_alerts["prod"].arn}
          sigv4:
            region: ${var.aws_region}
          subject: "[AMP][prod] {{ .CommonLabels.alertname }}"
  EOT
}

resource "aws_iam_role" "observability_amg_workspace" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  name = "${local.name_prefix}-amg-workspace-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowGrafanaAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-amg-workspace-role"
    Service = "observability"
  })
}

data "aws_iam_policy_document" "observability_amg_workspace" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  statement {
    sid    = "AllowReadCloudWatch"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "ec2:DescribeRegions",
      "ec2:DescribeTags",
      "tag:GetResources",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowReadAmp"
    effect = "Allow"
    actions = [
      "aps:DescribeWorkspace",
      "aps:ListWorkspaces",
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]
    resources = [aws_prometheus_workspace.observability[0].arn]
  }
}

resource "aws_iam_policy" "observability_amg_workspace" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  name   = "${local.name_prefix}-amg-workspace-policy"
  policy = data.aws_iam_policy_document.observability_amg_workspace[0].json

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-amg-workspace-policy"
    Service = "observability"
  })
}

resource "aws_iam_role_policy_attachment" "observability_amg_workspace" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  role       = aws_iam_role.observability_amg_workspace[0].name
  policy_arn = aws_iam_policy.observability_amg_workspace[0].arn
}

resource "aws_grafana_workspace" "observability" {
  count = var.enable_observability_metrics_platform ? 1 : 0

  name                      = var.amg_workspace_name
  account_access_type       = "CURRENT_ACCOUNT"
  authentication_providers  = var.amg_authentication_providers
  permission_type           = "SERVICE_MANAGED"
  role_arn                  = aws_iam_role.observability_amg_workspace[0].arn
  data_sources              = ["PROMETHEUS", "CLOUDWATCH"]
  notification_destinations = ["SNS"]

  tags = merge(local.common_tags, {
    Name    = var.amg_workspace_name
    Service = "observability"
  })

  depends_on = [
    aws_iam_role_policy_attachment.observability_amg_workspace,
  ]
}

resource "aws_grafana_role_association" "observability_admin" {
  count = var.enable_observability_metrics_platform && length(var.amg_admin_group_ids) > 0 ? 1 : 0

  workspace_id = aws_grafana_workspace.observability[0].id
  role         = "ADMIN"
  group_ids    = var.amg_admin_group_ids
}

resource "aws_grafana_role_association" "observability_editor" {
  count = var.enable_observability_metrics_platform && length(var.amg_editor_group_ids) > 0 ? 1 : 0

  workspace_id = aws_grafana_workspace.observability[0].id
  role         = "EDITOR"
  group_ids    = var.amg_editor_group_ids
}

resource "aws_grafana_role_association" "observability_viewer" {
  count = var.enable_observability_metrics_platform && length(var.amg_viewer_group_ids) > 0 ? 1 : 0

  workspace_id = aws_grafana_workspace.observability[0].id
  role         = "VIEWER"
  group_ids    = var.amg_viewer_group_ids
}

data "aws_iam_policy_document" "observability_metrics_readonly" {
  for_each = var.enable_observability_metrics_platform ? local.observability_metrics_envs : {}

  statement {
    sid    = "AllowReadAmpWorkspace"
    effect = "Allow"
    actions = [
      "aps:DescribeWorkspace",
      "aps:ListWorkspaces",
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]
    resources = [aws_prometheus_workspace.observability[0].arn]
  }

  statement {
    sid    = "AllowReadCloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:DescribeAlarms",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowReadAmgWorkspace"
    effect = "Allow"
    actions = [
      "grafana:DescribeWorkspace",
      "grafana:ListWorkspaces",
    ]
    resources = [aws_grafana_workspace.observability[0].arn]
  }
}

resource "aws_iam_policy" "observability_metrics_readonly" {
  for_each = data.aws_iam_policy_document.observability_metrics_readonly

  name   = "${var.project}-${each.key}-observability-metrics-readonly"
  policy = each.value.json
  tags = merge(local.common_tags, {
    Name    = "${var.project}-${each.key}-observability-metrics-readonly"
    Service = "observability"
    Env     = each.key
  })
}
