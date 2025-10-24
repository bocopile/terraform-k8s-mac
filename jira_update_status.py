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

issue_key = sys.argv[1] if len(sys.argv) > 1 else "TERRAFORM-41"
status_name = sys.argv[2] if len(sys.argv) > 2 else "진행 중"

# Get available transitions
transitions_url = f"{JIRA_BASE_URL}/rest/api/3/issue/{issue_key}/transitions"
cmd = ['curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}', '-H', 'Content-Type: application/json', transitions_url]
result = subprocess.run(cmd, capture_output=True, text=True)
transitions_data = json.loads(result.stdout)

# Find transition ID for the desired status
transition_id = None
for transition in transitions_data.get('transitions', []):
    if transition['name'] == status_name or transition['to']['name'] == status_name:
        transition_id = transition['id']
        break

if not transition_id:
    print(f"Error: Cannot find transition to '{status_name}'")
    print(f"Available transitions:")
    for transition in transitions_data.get('transitions', []):
        print(f"  - {transition['name']} -> {transition['to']['name']}")
    exit(1)

# Execute transition
data = json.dumps({"transition": {"id": transition_id}})
cmd = ['curl', '-s', '-X', 'POST', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}',
       '-H', 'Content-Type: application/json',
       '--data', data,
       transitions_url]
result = subprocess.run(cmd, capture_output=True, text=True)

if result.returncode == 0:
    print(f"✓ {issue_key} 상태를 '{status_name}'(으)로 변경했습니다.")
else:
    print(f"Error: {result.stderr}")
