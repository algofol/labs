# ── SNS Topic ─────────────────────────────────────────────────────────────────
resource "aws_sns_topic" "devopsguru" {
  name = "${var.project}-devopsguru-notifications"

  tags = { DevOpsGuruEnabled = "true" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.devopsguru.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ── DevOps Guru – Tag-based Resource Collection ───────────────────────────────
# Monitors all resources tagged with DevOpsGuruEnabled=true
resource "aws_devopsguru_resource_collection" "main" {
  type = "AWS_TAGS"

  tags {
    app_boundary_key = "DevOpsGuruEnabled"
    tag_values       = ["true"]
  }
}

# ── DevOps Guru – Notification Channel ───────────────────────────────────────
resource "aws_devopsguru_notification_channel" "main" {
  sns {
    topic_arn = aws_sns_topic.devopsguru.arn
  }

  filters {
    message_types = ["CLOSED_INSIGHT", "NEW_INSIGHT", "NEW_RECOMMENDATION", "SEVERITY_UPGRADED"]
    severities    = ["HIGH", "MEDIUM", "LOW"]
  }
}
