#!/usr/bin/env python3
import os
import subprocess
import json

JIRA_EMAIL = os.getenv('JIRA_EMAIL')
JIRA_API_TOKEN = os.getenv('JIRA_API_TOKEN')
JIRA_BASE_URL = os.getenv('JIRA_BASE_URL')

if not all([JIRA_EMAIL, JIRA_API_TOKEN, JIRA_BASE_URL]):
    print("Error: JIRA environment variables not set")
    exit(1)

# Get issue IDs
jql_url = f"{JIRA_BASE_URL}/rest/api/3/search/jql?jql=project=TERRAFORM+AND+status!=Done+ORDER+BY+priority+DESC,created+ASC"
cmd = ['curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}', '-H', 'Content-Type: application/json', jql_url]
result = subprocess.run(cmd, capture_output=True, text=True)
data = json.loads(result.stdout)

issue_ids = [issue['id'] for issue in data['issues']]

print(f'총 {len(issue_ids)}개의 백로그 작업')
print('-' * 100)

# Get details for each issue
for issue_id in issue_ids:
    issue_url = f"{JIRA_BASE_URL}/rest/api/3/issue/{issue_id}"
    cmd = ['curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}', '-H', 'Content-Type: application/json', issue_url]
    result = subprocess.run(cmd, capture_output=True, text=True)
    issue_data = json.loads(result.stdout)

    key = issue_data['key']
    summary = issue_data['fields']['summary']
    status = issue_data['fields']['status']['name']
    priority_obj = issue_data['fields'].get('priority')
    priority = priority_obj['name'] if priority_obj else 'None'

    print(f'{key:15} | {status:15} | {priority:10} | {summary}')
