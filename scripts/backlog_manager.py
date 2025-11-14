#!/usr/bin/env python3
"""
Claude Code SubAgent - Backlog Manager

JIRA JQL을 사용한 백로그 조회 및 관리
"""

import requests
import base64
from typing import Optional, Dict, Any, List
from config import get_config


class BacklogManager:
    """JIRA Backlog 관리 클라이언트"""

    def __init__(self):
        """Backlog Manager 초기화"""
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

    def get_board_id(self) -> Optional[int]:
        """
        프로젝트의 첫 번째 보드 ID 조회

        Returns:
            보드 ID 또는 None
        """
        try:
            url = f"{self.base_url}/rest/agile/1.0/board"
            params = {"projectKeyOrId": self.project_key}

            response = requests.get(
                url,
                headers=self.headers,
                params=params,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                boards = data.get('values', [])
                if boards and len(boards) > 0:
                    return boards[0]['id']
            return None

        except Exception as e:
            print(f"❌ 보드 ID 조회 실패: {e}")
            return None

    def get_backlog_issues(
        self,
        max_results: int = 50,
        order_by_priority: bool = True
    ) -> Optional[List[Dict[str, Any]]]:
        """
        백로그 이슈 조회 (스프린트에 할당되지 않은 이슈)
        Agile API를 사용하여 보드의 백로그를 조회합니다.

        Args:
            max_results: 최대 조회 개수
            order_by_priority: 우선순위로 정렬

        Returns:
            백로그 이슈 리스트 또는 None
        """
        try:
            # 보드 ID 조회
            board_id = self.get_board_id()
            if not board_id:
                print("❌ 보드를 찾을 수 없습니다.")
                return None

            # Agile API를 사용하여 백로그 조회
            url = f"{self.base_url}/rest/agile/1.0/board/{board_id}/backlog"

            params = {
                'maxResults': max_results,
                'fields': 'summary,status,priority,assignee,labels,created,updated'
            }

            response = requests.get(
                url,
                headers=self.headers,
                params=params,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                issues = data.get('issues', [])

                # 우선순위로 정렬 (클라이언트 측)
                if order_by_priority and issues:
                    priority_order = {
                        'Highest': 1,
                        'High': 2,
                        'Medium': 3,
                        'Low': 4,
                        'Lowest': 5
                    }

                    def get_priority_value(issue):
                        priority = issue.get('fields', {}).get('priority', {})
                        if priority:
                            priority_name = priority.get('name', 'Medium')
                            return priority_order.get(priority_name, 99)
                        return 99

                    issues = sorted(issues, key=get_priority_value)

                return issues
            else:
                print(f"❌ 백로그 조회 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return None

        except Exception as e:
            print(f"❌ 백로그 조회 실패: {e}")
            return None

    def get_all_issues(
        self,
        jql: Optional[str] = None,
        max_results: int = 50
    ) -> Optional[List[Dict[str, Any]]]:
        """
        커스텀 JQL로 이슈 조회

        Args:
            jql: JQL 쿼리 (미지정 시 프로젝트 전체 조회)
            max_results: 최대 조회 개수

        Returns:
            이슈 리스트 또는 None
        """
        try:
            url = f"{self.base_url}/rest/api/2/search"

            if not jql:
                jql = f'project = {self.project_key} ORDER BY created DESC'

            payload = {
                'jql': jql,
                'maxResults': max_results,
                'fields': ['summary', 'status', 'priority', 'assignee', 'labels', 'created', 'updated']
            }

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                return data.get('issues', [])
            else:
                print(f"❌ 이슈 조회 실패: HTTP {response.status_code}")
                return None

        except Exception as e:
            print(f"❌ 이슈 조회 실패: {e}")
            return None

    def print_backlog_summary(self, limit: int = 10):
        """백로그 요약 출력"""
        print("\n" + "=" * 80)
        print("📋 JIRA Backlog 현황 (우선순위 높은 순)")
        print("=" * 80)

        issues = self.get_backlog_issues(max_results=50)

        if not issues:
            print("❌ 백로그 이슈를 찾을 수 없습니다.")
            return

        print(f"\n총 백로그 이슈: {len(issues)}개")
        print(f"\n상위 {min(limit, len(issues))}개 이슈:\n")

        for idx, issue in enumerate(issues[:limit], 1):
            key = issue['key']
            fields = issue['fields']
            summary = fields.get('summary', 'N/A')
            priority = fields.get('priority', {})
            priority_name = priority.get('name', 'N/A') if priority else 'N/A'
            status = fields.get('status', {}).get('name', 'N/A')
            assignee = fields.get('assignee', {})
            assignee_name = assignee.get('displayName', 'Unassigned') if assignee else 'Unassigned'
            labels = fields.get('labels', [])

            # 우선순위 아이콘
            priority_icon = {
                'Highest': '🔴',
                'High': '🟠',
                'Medium': '🟡',
                'Low': '🟢',
                'Lowest': '⚪'
            }.get(priority_name, '⚫')

            print(f"{idx:2d}. {priority_icon} [{key}] {summary}")
            print(f"    우선순위: {priority_name} | 상태: {status} | 담당: {assignee_name}")
            if labels:
                print(f"    라벨: {', '.join(labels)}")
            print()

        print("=" * 80 + "\n")

    def get_top_priority_issues(
        self,
        count: int = 5
    ) -> List[str]:
        """
        우선순위 상위 N개 이슈 키 반환

        Args:
            count: 조회할 이슈 개수

        Returns:
            이슈 키 리스트
        """
        issues = self.get_backlog_issues(max_results=count)

        if not issues:
            return []

        return [issue['key'] for issue in issues[:count]]


def main():
    """테스트용 메인 함수"""
    import sys

    manager = BacklogManager()

    if len(sys.argv) < 2:
        # 인자 없으면 백로그 요약 출력
        manager.print_backlog_summary(limit=20)
        print("\nUsage:")
        print("  python backlog_manager.py list [limit]           # 백로그 목록 (기본 10개)")
        print("  python backlog_manager.py top [count]            # 우선순위 상위 N개 키만 출력")
        print("  python backlog_manager.py jql '<jql_query>'      # 커스텀 JQL 조회")
        sys.exit(0)

    command = sys.argv[1]

    if command == "list":
        limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10
        manager.print_backlog_summary(limit=limit)

    elif command == "top":
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        issue_keys = manager.get_top_priority_issues(count=count)
        print("\n우선순위 상위 이슈:")
        for key in issue_keys:
            print(f"  - {key}")

    elif command == "jql":
        if len(sys.argv) < 3:
            print("❌ JQL 쿼리를 입력하세요.")
            sys.exit(1)

        jql = sys.argv[2]
        issues = manager.get_all_issues(jql=jql)

        if issues:
            print(f"\n조회된 이슈: {len(issues)}개\n")
            for issue in issues:
                key = issue['key']
                summary = issue['fields'].get('summary', 'N/A')
                print(f"  [{key}] {summary}")
        else:
            print("❌ 이슈를 찾을 수 없습니다.")

    else:
        print(f"❌ 알 수 없는 명령: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
