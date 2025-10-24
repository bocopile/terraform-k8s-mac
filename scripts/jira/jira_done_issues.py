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

# Get completed issues using the new API
jql_url = f"{JIRA_BASE_URL}/rest/api/3/search/jql?jql=project=TERRAFORM+AND+status=Done+ORDER+BY+created+DESC"
cmd = ['curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}', '-H', 'Content-Type: application/json', jql_url]
result = subprocess.run(cmd, capture_output=True, text=True)

if not result.stdout.strip():
    print("Error: Empty response from JIRA API")
    print("stderr:", result.stderr)
    exit(1)

try:
    data = json.loads(result.stdout)
except json.JSONDecodeError as e:
    print(f"Error parsing JSON: {e}")
    print("Response:", result.stdout[:200])
    exit(1)

issues = data.get('issues', [])
print(f'완료된 이슈: {len(issues)}개')
print('-' * 100)

# Get detailed information for each issue
for issue in issues:
    issue_id = issue['id']
    issue_url = f"{JIRA_BASE_URL}/rest/api/3/issue/{issue_id}"
    cmd = ['curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}', '-H', 'Content-Type: application/json', issue_url]
    result = subprocess.run(cmd, capture_output=True, text=True)

    try:
        issue_data = json.loads(result.stdout)
        key = issue_data['key']
        summary = issue_data['fields']['summary']
        created = issue_data['fields']['created'][:10]
        print(f'{key:15} | {created} | {summary}')
    except (json.JSONDecodeError, KeyError) as e:
        print(f'Error processing issue {issue_id}: {e}')
