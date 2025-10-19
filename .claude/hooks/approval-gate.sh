#!/bin/bash

# Approval Gate Hook
# This hook is triggered for high-risk operations requiring user approval

TASK_NAME="$1"
TASK_TYPE="$2"
RISK_LEVEL="$3"

# Define task types that require approval
APPROVAL_REQUIRED_TYPES=(
  "database-migration"
  "schema-change"
  "production-deployment"
  "infrastructure-change"
  "security-change"
  "breaking-change"
  "dependency-upgrade"
)

# Check if this task type requires approval
requires_approval=false
for type in "${APPROVAL_REQUIRED_TYPES[@]}"; do
  if [[ "$TASK_TYPE" == "$type" ]]; then
    requires_approval=true
    break
  fi
done

# Also require approval for high/critical risk levels
if [[ "$RISK_LEVEL" == "high" ]] || [[ "$RISK_LEVEL" == "critical" ]]; then
  requires_approval=true
fi

if [[ "$requires_approval" == "true" ]]; then
  echo "⚠️  APPROVAL REQUIRED"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Task: $TASK_NAME"
  echo "Type: $TASK_TYPE"
  echo "Risk Level: $RISK_LEVEL"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Send Slack notification if configured
  if [[ -n "$SLACK_WEBHOOK_APPROVALS" ]]; then
    curl -X POST "$SLACK_WEBHOOK_APPROVALS" \
      -H 'Content-Type: application/json' \
      -d "{
        \"text\": \"⚠️ Approval Required\",
        \"attachments\": [{
          \"color\": \"warning\",
          \"fields\": [
            {\"title\": \"Task\", \"value\": \"$TASK_NAME\", \"short\": false},
            {\"title\": \"Type\", \"value\": \"$TASK_TYPE\", \"short\": true},
            {\"title\": \"Risk Level\", \"value\": \"$RISK_LEVEL\", \"short\": true}
          ]
        }]
      }" 2>/dev/null
  fi

  echo ""
  echo "This operation requires approval to proceed."
  echo "The coordinator should use AskUserQuestion to get explicit approval."

  exit 0
else
  exit 0
fi
