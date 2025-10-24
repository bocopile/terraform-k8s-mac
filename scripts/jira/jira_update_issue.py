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
    print("Usage: jira_update_issue.py <issue_key> <description>")
    print("Example: jira_update_issue.py TERRAFORM-53 'Updated description'")
    exit(1)

issue_key = sys.argv[1]
description = sys.argv[2]

# Update issue payload
payload = {
    "fields": {
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
        }
    }
}

# Update issue
update_url = f"{JIRA_BASE_URL}/rest/api/3/issue/{issue_key}"
cmd = [
    'curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}',
    '-X', 'PUT',
    '-H', 'Content-Type: application/json',
    '-d', json.dumps(payload),
    update_url
]

result = subprocess.run(cmd, capture_output=True, text=True)

if result.stdout.strip() == '' or result.returncode == 0:
    print(f"✅ 이슈 업데이트 완료: {issue_key}")
    print(f"   URL: {JIRA_BASE_URL}/browse/{issue_key}")
else:
    try:
        response = json.loads(result.stdout)
        print(f"❌ 이슈 업데이트 실패:")
        print(json.dumps(response, indent=2, ensure_ascii=False))
    except:
        print(f"Response: {result.stdout}")
