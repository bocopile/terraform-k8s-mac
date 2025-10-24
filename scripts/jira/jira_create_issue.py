#!/usr/bin/env python3
import os
import subprocess
import json
import sys

JIRA_EMAIL = os.getenv('JIRA_EMAIL')
JIRA_API_TOKEN = os.getenv('JIRA_API_TOKEN')
JIRA_BASE_URL = os.getenv('JIRA_BASE_URL')

if not all([JIRA_EMAIL, JIRA_API_TOKEN, JIRA_BASE_URL]):
    print("Error: JIRA environment variables not set")
    exit(1)

if len(sys.argv) < 3:
    print("Usage: jira_create_issue.py <summary> <description> [issue_type]")
    print("Example: jira_create_issue.py 'Issue title' 'Issue description' Task")
    exit(1)

summary = sys.argv[1]
description = sys.argv[2]
issue_type = sys.argv[3] if len(sys.argv) > 3 else "Task"  # Task, Bug, Epic, Story

# Create issue payload
payload = {
    "fields": {
        "project": {
            "key": "TERRAFORM"
        },
        "summary": summary,
        "description": {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [
                        {
                            "type": "text",
                            "text": description
                        }
                    ]
                }
            ]
        },
        "issuetype": {
            "name": issue_type
        }
    }
}

# Create issue
create_url = f"{JIRA_BASE_URL}/rest/api/3/issue"
cmd = [
    'curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}',
    '-X', 'POST',
    '-H', 'Content-Type: application/json',
    '-d', json.dumps(payload),
    create_url
]

result = subprocess.run(cmd, capture_output=True, text=True)

try:
    response = json.loads(result.stdout)
    if 'key' in response:
        print(f"✅ 이슈 생성 완료: {response['key']}")
        print(f"   URL: {JIRA_BASE_URL}/browse/{response['key']}")
    else:
        print(f"❌ 이슈 생성 실패:")
        print(json.dumps(response, indent=2, ensure_ascii=False))
except json.JSONDecodeError as e:
    print(f"Error parsing response: {e}")
    print("Response:", result.stdout[:500])
