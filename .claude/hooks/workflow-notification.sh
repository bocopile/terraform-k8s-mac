#!/bin/bash

# Workflow Notification Hook
# Sends notifications about workflow events to Slack

EVENT_TYPE="$1"
WORKFLOW_NAME="$2"
STATUS="$3"
DETAILS="$4"

# Only send notification if Slack webhook is configured
if [[ -z "$SLACK_WEBHOOK_WORKFLOW" ]]; then
  exit 0
fi

# Determine color based on status
case "$STATUS" in
  "started"|"running")
    COLOR="good"
    ICON="🚀"
    ;;
  "completed"|"success")
    COLOR="good"
    ICON="✅"
    ;;
  "failed"|"error")
    COLOR="danger"
    ICON="❌"
    ;;
  "warning")
    COLOR="warning"
    ICON="⚠️"
    ;;
  *)
    COLOR="#439FE0"
    ICON="ℹ️"
    ;;
esac

# Create message payload
PAYLOAD=$(cat <<EOF
{
  "text": "$ICON $WORKFLOW_NAME - $STATUS",
  "attachments": [{
    "color": "$COLOR",
    "fields": [
      {
        "title": "Workflow",
        "value": "$WORKFLOW_NAME",
        "short": true
      },
      {
        "title": "Status",
        "value": "$STATUS",
        "short": true
      },
      {
        "title": "Details",
        "value": "$DETAILS",
        "short": false
      },
      {
        "title": "Time",
        "value": "$(date '+%Y-%m-%d %H:%M:%S')",
        "short": true
      }
    ]
  }]
}
EOF
)

# Send notification to Slack
curl -X POST "$SLACK_WEBHOOK_WORKFLOW" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" \
  2>/dev/null

exit 0
