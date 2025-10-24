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

# Get issue details
issue_url = f"{JIRA_BASE_URL}/rest/api/3/issue/{issue_key}"
cmd = ['curl', '-s', '-u', f'{JIRA_EMAIL}:{JIRA_API_TOKEN}', '-H', 'Content-Type: application/json', issue_url]
result = subprocess.run(cmd, capture_output=True, text=True)
issue_data = json.loads(result.stdout)

key = issue_data['key']
summary = issue_data['fields']['summary']
status = issue_data['fields']['status']['name']
description = issue_data['fields'].get('description', {})
priority_obj = issue_data['fields'].get('priority')
priority = priority_obj['name'] if priority_obj else 'None'

print(f'Key: {key}')
print(f'Summary: {summary}')
print(f'Status: {status}')
print(f'Priority: {priority}')
print(f'\nDescription:')

# Parse Atlassian Document Format (ADF)
if description:
    def parse_adf(content):
        if isinstance(content, dict):
            if content.get('type') == 'doc':
                for item in content.get('content', []):
                    parse_adf(item)
            elif content.get('type') == 'paragraph':
                texts = []
                for item in content.get('content', []):
                    if item.get('type') == 'text':
                        texts.append(item.get('text', ''))
                if texts:
                    print(''.join(texts))
            elif content.get('type') == 'heading':
                level = content.get('attrs', {}).get('level', 1)
                texts = []
                for item in content.get('content', []):
                    if item.get('type') == 'text':
                        texts.append(item.get('text', ''))
                if texts:
                    print(f"\n{'#' * level} {''.join(texts)}")
            elif content.get('type') == 'bulletList':
                for item in content.get('content', []):
                    parse_adf(item)
            elif content.get('type') == 'listItem':
                texts = []
                for item in content.get('content', []):
                    if item.get('type') == 'paragraph':
                        for text_item in item.get('content', []):
                            if text_item.get('type') == 'text':
                                texts.append(text_item.get('text', ''))
                if texts:
                    print(f"- {''.join(texts)}")
            elif content.get('type') == 'codeBlock':
                code = []
                for item in content.get('content', []):
                    if item.get('type') == 'text':
                        code.append(item.get('text', ''))
                if code:
                    print(f"```\n{''.join(code)}\n```")

    parse_adf(description)
else:
    print("(설명 없음)")
