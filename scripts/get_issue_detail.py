#!/usr/bin/env python3
"""
JIRA 이슈 상세 정보 조회 스크립트
"""

import requests
import base64
import sys
from config import get_config


def get_issue_detail(issue_key):
    """JIRA 이슈 상세 정보 조회"""
    config = get_config()

    # 인증 헤더 생성
    auth_string = f"{config.jira_email}:{config.jira_api_token}"
    auth_bytes = auth_string.encode('utf-8')
    auth_b64 = base64.b64encode(auth_bytes).decode('utf-8')

    headers = {
        'Authorization': f'Basic {auth_b64}',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }

    # 이슈 조회
    url = f"{config.jira_url}/rest/api/2/issue/{issue_key}"

    response = requests.get(url, headers=headers, timeout=10)

    if response.status_code == 200:
        data = response.json()
        fields = data.get('fields', {})

        summary = fields.get('summary', 'N/A')
        description = fields.get('description', 'N/A')
        status = fields.get('status', {}).get('name', 'N/A')
        priority = fields.get('priority', {})
        priority_name = priority.get('name', 'N/A') if priority else 'N/A'
        assignee = fields.get('assignee', {})
        assignee_name = assignee.get('displayName', 'Unassigned') if assignee else 'Unassigned'
        labels = fields.get('labels', [])

        print("\n" + "=" * 80)
        print(f"📋 JIRA Issue: {issue_key}")
        print("=" * 80)
        print(f"\n제목: {summary}")
        print(f"상태: {status}")
        print(f"우선순위: {priority_name}")
        print(f"담당자: {assignee_name}")
        if labels:
            print(f"라벨: {', '.join(labels)}")
        print(f"\n설명:")
        print("-" * 80)
        print(description)
        print("-" * 80 + "\n")
    else:
        print(f"❌ 이슈 조회 실패: HTTP {response.status_code}")
        print(f"   {response.text}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python get_issue_detail.py <issue_key>")
        sys.exit(1)

    issue_key = sys.argv[1]
    get_issue_detail(issue_key)
