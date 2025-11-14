#!/usr/bin/env python3
"""
Sprint 이슈 목록 조회 스크립트
"""

import requests
import base64
import sys
from config import get_config


def view_sprint_issues(sprint_id):
    """Sprint의 이슈 목록 조회"""
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

    # Sprint 이슈 조회
    url = f"{config.jira_url}/rest/agile/1.0/sprint/{sprint_id}/issue"
    params = {
        'maxResults': 100,
        'fields': 'summary,status,priority,assignee,labels,description'
    }

    response = requests.get(url, headers=headers, params=params, timeout=10)

    if response.status_code == 200:
        data = response.json()
        issues = data.get('issues', [])

        print("\n" + "=" * 80)
        print(f"📋 Sprint {sprint_id} 이슈 목록 ({len(issues)}개)")
        print("=" * 80 + "\n")

        if not issues:
            print("이슈가 없습니다.")
            return

        for idx, issue in enumerate(issues, 1):
            key = issue['key']
            fields = issue['fields']
            summary = fields.get('summary', 'N/A')
            priority = fields.get('priority', {})
            priority_name = priority.get('name', 'N/A') if priority else 'N/A'
            status = fields.get('status', {}).get('name', 'N/A')
            assignee = fields.get('assignee', {})
            assignee_name = assignee.get('displayName', 'Unassigned') if assignee else 'Unassigned'
            labels = fields.get('labels', [])
            description = fields.get('description', '')

            # 우선순위 아이콘
            priority_icon = {
                'Highest': '🔴',
                'High': '🟠',
                'Medium': '🟡',
                'Low': '🟢',
                'Lowest': '⚪'
            }.get(priority_name, '⚫')

            print(f"{idx}. {priority_icon} [{key}] {summary}")
            print(f"   우선순위: {priority_name} | 상태: {status} | 담당: {assignee_name}")
            if labels:
                print(f"   라벨: {', '.join(labels)}")
            if description:
                # 설명 첫 줄만 출력
                desc_first_line = str(description).split('\n')[0][:100]
                print(f"   설명: {desc_first_line}...")
            print()

        print("=" * 80 + "\n")
    else:
        print(f"❌ Sprint 이슈 조회 실패: HTTP {response.status_code}")
        print(f"   {response.text}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python view_sprint_issues.py <sprint_id>")
        sys.exit(1)

    sprint_id = int(sys.argv[1])
    view_sprint_issues(sprint_id)
