#!/usr/bin/env python3
"""
JIRA REST API 연결 테스트 스크립트
"""
import os
import sys
import requests
import json
from pathlib import Path

# .env 파일 로드
env_path = Path(__file__).parent.parent / '.env'
if env_path.exists():
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ[key] = value

# JIRA 설정
JIRA_URL = os.getenv('JIRA_URL')
JIRA_EMAIL = os.getenv('JIRA_EMAIL')
JIRA_API_TOKEN = os.getenv('JIRA_API_TOKEN')
JIRA_PROJECT_KEY = os.getenv('JIRA_PROJECT_KEY')

print("=" * 60)
print("JIRA REST API 연결 테스트")
print("=" * 60)
print(f"JIRA URL: {JIRA_URL}")
print(f"Email: {JIRA_EMAIL}")
print(f"Project Key: {JIRA_PROJECT_KEY}")
print(f"Token: {'*' * 20}...{JIRA_API_TOKEN[-10:] if JIRA_API_TOKEN else 'None'}")
print("=" * 60)

# 1. 프로젝트 정보 조회
print("\n[1] 프로젝트 정보 조회")
try:
    url = f"{JIRA_URL}/rest/api/3/project/{JIRA_PROJECT_KEY}"
    response = requests.get(
        url,
        auth=(JIRA_EMAIL, JIRA_API_TOKEN),
        headers={'Accept': 'application/json'}
    )

    if response.status_code == 200:
        project = response.json()
        print(f"✅ 성공: {project.get('name')} ({project.get('key')})")
        print(f"   ID: {project.get('id')}")
        print(f"   Lead: {project.get('lead', {}).get('displayName', 'N/A')}")
    else:
        print(f"❌ 실패: HTTP {response.status_code}")
        print(f"   {response.text}")
        sys.exit(1)
except Exception as e:
    print(f"❌ 오류: {e}")
    sys.exit(1)

# 2. 이슈 타입 조회
print("\n[2] 이슈 타입 조회")
try:
    url = f"{JIRA_URL}/rest/api/3/issuetype/project"
    params = {'projectId': project['id']}
    response = requests.get(
        url,
        params=params,
        auth=(JIRA_EMAIL, JIRA_API_TOKEN),
        headers={'Accept': 'application/json'}
    )

    if response.status_code == 200:
        issue_types = response.json()
        print(f"✅ 사용 가능한 이슈 타입:")
        for issue_type in issue_types[:5]:
            print(f"   - {issue_type.get('name')} (ID: {issue_type.get('id')})")
    else:
        print(f"⚠️  이슈 타입 조회 실패: HTTP {response.status_code}")
except Exception as e:
    print(f"⚠️  이슈 타입 조회 오류: {e}")

# 3. 최근 이슈 조회
print("\n[3] 최근 이슈 조회 (최대 3개)")
try:
    url = f"{JIRA_URL}/rest/api/3/search"
    params = {
        'jql': f'project={JIRA_PROJECT_KEY} ORDER BY created DESC',
        'maxResults': 3,
        'fields': 'summary,status,assignee,created'
    }
    response = requests.get(
        url,
        params=params,
        auth=(JIRA_EMAIL, JIRA_API_TOKEN),
        headers={'Accept': 'application/json'}
    )

    if response.status_code == 200:
        result = response.json()
        total = result.get('total', 0)
        issues = result.get('issues', [])

        print(f"✅ 총 이슈 개수: {total}")
        for issue in issues:
            key = issue.get('key')
            fields = issue.get('fields', {})
            summary = fields.get('summary', 'N/A')
            status = fields.get('status', {}).get('name', 'N/A')
            print(f"   - [{key}] {summary}")
            print(f"     상태: {status}")
    else:
        print(f"⚠️  이슈 조회 실패: HTTP {response.status_code}")
except Exception as e:
    print(f"⚠️  이슈 조회 오류: {e}")

print("\n" + "=" * 60)
print("✅ JIRA REST API 연결 테스트 완료!")
print("=" * 60)
