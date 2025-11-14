#!/usr/bin/env python3
"""
JIRA 이슈 상태 업데이트 스크립트
"""

import sys
import requests
import base64
from config import get_config


def update_status(issue_key, transition_id):
    """JIRA 이슈 상태 전환"""
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

    # 상태 전환 실행
    url = f"{config.jira_url}/rest/api/2/issue/{issue_key}/transitions"
    payload = {"transition": {"id": transition_id}}

    response = requests.post(url, json=payload, headers=headers, timeout=10)

    if response.status_code == 204:
        print(f"✅ JIRA 이슈 상태 변경 완료: {issue_key}")
        return True
    else:
        print(f"❌ JIRA 상태 변경 실패: HTTP {response.status_code}")
        print(f"   {response.text}")
        return False


def main():
    if len(sys.argv) < 3:
        print("Usage: python update_issue_status.py <issue_key> <transition_id>")
        print("\nCommon transitions:")
        print("  21 - 진행 중")
        print("  31 - 완료")
        print("  32 - 테스트 진행중")
        sys.exit(1)

    issue_key = sys.argv[1]
    transition_id = sys.argv[2]

    success = update_status(issue_key, transition_id)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
