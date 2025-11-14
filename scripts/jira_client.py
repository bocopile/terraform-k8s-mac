#!/usr/bin/env python3
"""
Claude Code SubAgent - JIRA Client

JIRA REST API를 사용한 티켓 관리 클라이언트
"""

import requests
import base64
from typing import Optional, Dict, Any, List
from config import get_config


class JiraClient:
    """JIRA REST API 클라이언트"""

    def __init__(self):
        """JIRA 클라이언트 초기화"""
        self.config = get_config()
        self.base_url = self.config.jira_url
        self.email = self.config.jira_email
        self.api_token = self.config.jira_api_token
        self.project_key = self.config.jira_project_key

        # 인증 헤더 생성
        auth_string = f"{self.email}:{self.api_token}"
        auth_bytes = auth_string.encode('utf-8')
        auth_b64 = base64.b64encode(auth_bytes).decode('utf-8')

        self.headers = {
            'Authorization': f'Basic {auth_b64}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }

    def get_issue(self, issue_key: str) -> Optional[Dict[str, Any]]:
        """
        JIRA 이슈 조회

        Args:
            issue_key: 이슈 키 (예: FINOPS-350)

        Returns:
            이슈 정보 딕셔너리 또는 None
        """
        try:
            url = f"{self.base_url}/rest/api/3/issue/{issue_key}"
            response = requests.get(url, headers=self.headers, timeout=10)

            if response.status_code == 200:
                return response.json()
            elif response.status_code == 404:
                print(f"⚠️  이슈를 찾을 수 없습니다: {issue_key}")
                return None
            else:
                print(f"❌ JIRA API 오류: HTTP {response.status_code}")
                print(f"   {response.text}")
                return None

        except Exception as e:
            print(f"❌ JIRA 이슈 조회 실패: {e}")
            return None

    def create_issue(
        self,
        summary: str,
        description: str,
        issue_type: str = "Task",
        labels: Optional[List[str]] = None
    ) -> Optional[Dict[str, Any]]:
        """
        JIRA 이슈 생성

        Args:
            summary: 이슈 제목
            description: 이슈 설명
            issue_type: 이슈 타입 (Task, Bug, Story 등)
            labels: 라벨 리스트

        Returns:
            생성된 이슈 정보 또는 None
        """
        try:
            url = f"{self.base_url}/rest/api/3/issue"

            payload = {
                "fields": {
                    "project": {
                        "key": self.project_key
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

            # 라벨 추가
            if labels:
                payload["fields"]["labels"] = labels

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 201:
                issue_data = response.json()
                print(f"✅ JIRA 이슈 생성 완료: {issue_data['key']}")
                return issue_data
            else:
                print(f"❌ JIRA 이슈 생성 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return None

        except Exception as e:
            print(f"❌ JIRA 이슈 생성 실패: {e}")
            return None

    def update_status(
        self,
        issue_key: str,
        status: str
    ) -> bool:
        """
        JIRA 이슈 상태 변경

        Args:
            issue_key: 이슈 키
            status: 변경할 상태 (예: "진행중", "완료", "재작업")

        Returns:
            성공 여부
        """
        try:
            # 사용 가능한 전환(transition) 조회
            transitions = self._get_transitions(issue_key)

            if not transitions:
                print(f"❌ 사용 가능한 전환을 찾을 수 없습니다.")
                return False

            # 상태명으로 전환 ID 찾기
            transition_id = None
            for trans in transitions:
                if trans['to']['name'].lower() == status.lower():
                    transition_id = trans['id']
                    break

            if not transition_id:
                print(f"❌ '{status}' 상태로 전환할 수 없습니다.")
                print(f"사용 가능한 상태: {[t['to']['name'] for t in transitions]}")
                return False

            # 상태 전환 실행
            url = f"{self.base_url}/rest/api/3/issue/{issue_key}/transitions"
            payload = {"transition": {"id": transition_id}}

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 204:
                print(f"✅ JIRA 이슈 상태 변경 완료: {issue_key} → {status}")
                return True
            else:
                print(f"❌ JIRA 상태 변경 실패: HTTP {response.status_code}")
                return False

        except Exception as e:
            print(f"❌ JIRA 상태 변경 실패: {e}")
            return False

    def add_comment(
        self,
        issue_key: str,
        comment: str
    ) -> bool:
        """
        JIRA 이슈에 코멘트 추가

        Args:
            issue_key: 이슈 키
            comment: 코멘트 내용

        Returns:
            성공 여부
        """
        try:
            url = f"{self.base_url}/rest/api/3/issue/{issue_key}/comment"

            payload = {
                "body": {
                    "type": "doc",
                    "version": 1,
                    "content": [
                        {
                            "type": "paragraph",
                            "content": [
                                {
                                    "type": "text",
                                    "text": comment
                                }
                            ]
                        }
                    ]
                }
            }

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 201:
                print(f"✅ JIRA 코멘트 추가 완료")
                return True
            else:
                print(f"❌ JIRA 코멘트 추가 실패: HTTP {response.status_code}")
                return False

        except Exception as e:
            print(f"❌ JIRA 코멘트 추가 실패: {e}")
            return False

    def _get_transitions(self, issue_key: str) -> Optional[List[Dict[str, Any]]]:
        """
        이슈에 사용 가능한 전환(transition) 목록 조회

        Args:
            issue_key: 이슈 키

        Returns:
            전환 목록 또는 None
        """
        try:
            url = f"{self.base_url}/rest/api/3/issue/{issue_key}/transitions"
            response = requests.get(url, headers=self.headers, timeout=10)

            if response.status_code == 200:
                data = response.json()
                return data.get('transitions', [])
            else:
                return None

        except Exception as e:
            print(f"❌ JIRA 전환 조회 실패: {e}")
            return None

    def get_issue_summary(self, issue_key: str) -> str:
        """
        이슈 요약 정보 문자열 반환

        Args:
            issue_key: 이슈 키

        Returns:
            이슈 요약 문자열
        """
        issue = self.get_issue(issue_key)

        if not issue:
            return f"이슈를 찾을 수 없습니다: {issue_key}"

        fields = issue.get('fields', {})
        summary = fields.get('summary', 'N/A')
        status = fields.get('status', {}).get('name', 'N/A')
        assignee = fields.get('assignee', {})
        assignee_name = assignee.get('displayName', 'Unassigned') if assignee else 'Unassigned'

        return f"""
JIRA Issue: {issue_key}
Summary: {summary}
Status: {status}
Assignee: {assignee_name}
        """.strip()


def main():
    """테스트용 메인 함수"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python jira_client.py <issue_key>")
        sys.exit(1)

    issue_key = sys.argv[1]

    client = JiraClient()
    print(client.get_issue_summary(issue_key))


if __name__ == "__main__":
    main()
