#!/usr/bin/env python3
"""
Claude Code SubAgent - Sprint Manager

JIRA Agile API를 사용한 스프린트 관리
"""

import requests
import base64
from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
from config import get_config


class SprintManager:
    """JIRA Sprint 관리 클라이언트"""

    def __init__(self):
        """Sprint Manager 초기화"""
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

    def get_boards(self) -> Optional[List[Dict[str, Any]]]:
        """
        프로젝트의 보드 목록 조회

        Returns:
            보드 목록 또는 None
        """
        try:
            url = f"{self.base_url}/rest/agile/1.0/board"
            params = {
                "projectKeyOrId": self.project_key
            }

            response = requests.get(
                url,
                headers=self.headers,
                params=params,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                return data.get('values', [])
            else:
                print(f"❌ 보드 조회 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return None

        except Exception as e:
            print(f"❌ 보드 조회 실패: {e}")
            return None

    def get_board_id(self) -> Optional[int]:
        """
        프로젝트의 첫 번째 보드 ID 조회

        Returns:
            보드 ID 또는 None
        """
        boards = self.get_boards()
        if boards and len(boards) > 0:
            return boards[0]['id']
        return None

    def create_sprint(
        self,
        name: str,
        goal: Optional[str] = None,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        스프린트 생성

        Args:
            name: 스프린트 이름
            goal: 스프린트 목표
            start_date: 시작일 (ISO 8601 형식, 예: 2025-01-01T09:00:00.000Z)
            end_date: 종료일 (ISO 8601 형식)

        Returns:
            생성된 스프린트 정보 또는 None
        """
        try:
            board_id = self.get_board_id()
            if not board_id:
                print("❌ 보드를 찾을 수 없습니다.")
                return None

            url = f"{self.base_url}/rest/agile/1.0/sprint"

            payload = {
                "name": name,
                "originBoardId": board_id
            }

            if goal:
                payload["goal"] = goal

            if start_date:
                payload["startDate"] = start_date

            if end_date:
                payload["endDate"] = end_date

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 201:
                sprint_data = response.json()
                print(f"✅ 스프린트 생성 완료: {sprint_data['name']} (ID: {sprint_data['id']})")
                return sprint_data
            else:
                print(f"❌ 스프린트 생성 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return None

        except Exception as e:
            print(f"❌ 스프린트 생성 실패: {e}")
            return None

    def get_sprints(
        self,
        state: Optional[str] = None
    ) -> Optional[List[Dict[str, Any]]]:
        """
        보드의 스프린트 목록 조회

        Args:
            state: 스프린트 상태 필터 (active, closed, future)

        Returns:
            스프린트 목록 또는 None
        """
        try:
            board_id = self.get_board_id()
            if not board_id:
                print("❌ 보드를 찾을 수 없습니다.")
                return None

            url = f"{self.base_url}/rest/agile/1.0/board/{board_id}/sprint"
            params = {}

            if state:
                params['state'] = state

            response = requests.get(
                url,
                headers=self.headers,
                params=params,
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                return data.get('values', [])
            else:
                print(f"❌ 스프린트 조회 실패: HTTP {response.status_code}")
                return None

        except Exception as e:
            print(f"❌ 스프린트 조회 실패: {e}")
            return None

    def add_issues_to_sprint(
        self,
        sprint_id: int,
        issue_keys: List[str]
    ) -> bool:
        """
        스프린트에 이슈 추가

        Args:
            sprint_id: 스프린트 ID
            issue_keys: 이슈 키 리스트 (예: ["TERRAFORM-1", "TERRAFORM-2"])

        Returns:
            성공 여부
        """
        try:
            url = f"{self.base_url}/rest/agile/1.0/sprint/{sprint_id}/issue"

            payload = {
                "issues": issue_keys
            }

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 204:
                print(f"✅ 스프린트에 이슈 추가 완료: {len(issue_keys)}개")
                return True
            else:
                print(f"❌ 스프린트 이슈 추가 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return False

        except Exception as e:
            print(f"❌ 스프린트 이슈 추가 실패: {e}")
            return False

    def start_sprint(
        self,
        sprint_id: int,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> bool:
        """
        스프린트 시작

        Args:
            sprint_id: 스프린트 ID
            start_date: 시작일 (ISO 8601 형식, 미지정 시 현재 시각)
            end_date: 종료일 (ISO 8601 형식, 미지정 시 2주 후)

        Returns:
            성공 여부
        """
        try:
            url = f"{self.base_url}/rest/agile/1.0/sprint/{sprint_id}"

            # 기본값 설정
            if not start_date:
                start_date = datetime.now().isoformat() + "Z"

            if not end_date:
                end = datetime.now() + timedelta(weeks=2)
                end_date = end.isoformat() + "Z"

            payload = {
                "state": "active",
                "startDate": start_date,
                "endDate": end_date
            }

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 200:
                print(f"✅ 스프린트 시작 완료 (ID: {sprint_id})")
                return True
            else:
                print(f"❌ 스프린트 시작 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return False

        except Exception as e:
            print(f"❌ 스프린트 시작 실패: {e}")
            return False

    def close_sprint(self, sprint_id: int) -> bool:
        """
        스프린트 종료

        Args:
            sprint_id: 스프린트 ID

        Returns:
            성공 여부
        """
        try:
            url = f"{self.base_url}/rest/agile/1.0/sprint/{sprint_id}"

            payload = {
                "state": "closed"
            }

            response = requests.post(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 200:
                print(f"✅ 스프린트 종료 완료 (ID: {sprint_id})")
                return True
            else:
                print(f"❌ 스프린트 종료 실패: HTTP {response.status_code}")
                return False

        except Exception as e:
            print(f"❌ 스프린트 종료 실패: {e}")
            return False

    def update_sprint(
        self,
        sprint_id: int,
        name: Optional[str] = None,
        goal: Optional[str] = None
    ) -> bool:
        """
        스프린트 정보 업데이트

        Args:
            sprint_id: 스프린트 ID
            name: 새로운 스프린트 이름
            goal: 새로운 스프린트 목표

        Returns:
            성공 여부
        """
        try:
            # 먼저 현재 스프린트 정보 조회
            get_url = f"{self.base_url}/rest/agile/1.0/sprint/{sprint_id}"
            get_response = requests.get(
                get_url,
                headers=self.headers,
                timeout=10
            )

            if get_response.status_code != 200:
                print(f"❌ 스프린트 조회 실패: HTTP {get_response.status_code}")
                return False

            current_sprint = get_response.json()
            current_state = current_sprint.get('state', 'future')

            # 업데이트 페이로드 구성
            url = f"{self.base_url}/rest/agile/1.0/sprint/{sprint_id}"

            payload = {
                "state": current_state  # 현재 상태 유지
            }

            if name:
                payload["name"] = name
            if goal:
                payload["goal"] = goal

            response = requests.put(
                url,
                json=payload,
                headers=self.headers,
                timeout=10
            )

            if response.status_code == 200:
                print(f"✅ 스프린트 업데이트 완료 (ID: {sprint_id})")
                if name:
                    print(f"   이름: {name}")
                if goal:
                    print(f"   목표: {goal}")
                return True
            else:
                print(f"❌ 스프린트 업데이트 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return False

        except Exception as e:
            print(f"❌ 스프린트 업데이트 실패: {e}")
            return False

    def print_sprint_summary(self):
        """현재 스프린트 상태 출력"""
        print("\n" + "=" * 60)
        print("📋 JIRA Sprint 현황")
        print("=" * 60)

        # Active 스프린트
        active_sprints = self.get_sprints(state="active")
        if active_sprints:
            print("\n🔵 진행 중인 스프린트:")
            for sprint in active_sprints:
                print(f"   - {sprint['name']} (ID: {sprint['id']})")
                if sprint.get('goal'):
                    print(f"     Goal: {sprint['goal']}")

        # Future 스프린트
        future_sprints = self.get_sprints(state="future")
        if future_sprints:
            print("\n⚪ 예정된 스프린트:")
            for sprint in future_sprints:
                print(f"   - {sprint['name']} (ID: {sprint['id']})")

        # Closed 스프린트 (최근 3개)
        closed_sprints = self.get_sprints(state="closed")
        if closed_sprints:
            print("\n⚫ 완료된 스프린트 (최근 3개):")
            for sprint in closed_sprints[:3]:
                print(f"   - {sprint['name']} (ID: {sprint['id']})")

        print("\n" + "=" * 60 + "\n")


def main():
    """테스트용 메인 함수"""
    import sys

    manager = SprintManager()

    if len(sys.argv) < 2:
        # 인자 없으면 현황 출력
        manager.print_sprint_summary()
        print("\nUsage:")
        print("  python sprint_manager.py list                  # 스프린트 목록")
        print("  python sprint_manager.py create <name> [goal]  # 스프린트 생성")
        print("  python sprint_manager.py update <id> <name> [goal]  # 스프린트 업데이트")
        print("  python sprint_manager.py add <id> <issues>     # 이슈 추가")
        print("  python sprint_manager.py start <id>            # 스프린트 시작")
        sys.exit(0)

    command = sys.argv[1]

    if command == "list":
        manager.print_sprint_summary()

    elif command == "create":
        if len(sys.argv) < 3:
            print("❌ 스프린트 이름을 입력하세요.")
            sys.exit(1)

        name = sys.argv[2]
        goal = sys.argv[3] if len(sys.argv) > 3 else None
        manager.create_sprint(name, goal)

    elif command == "add":
        if len(sys.argv) < 4:
            print("❌ Usage: python sprint_manager.py add <sprint_id> <issue1> [issue2...]")
            sys.exit(1)

        sprint_id = int(sys.argv[2])
        issues = sys.argv[3:]
        manager.add_issues_to_sprint(sprint_id, issues)

    elif command == "update":
        if len(sys.argv) < 4:
            print("❌ Usage: python sprint_manager.py update <sprint_id> <name> [goal]")
            sys.exit(1)

        sprint_id = int(sys.argv[2])
        name = sys.argv[3]
        goal = sys.argv[4] if len(sys.argv) > 4 else None
        manager.update_sprint(sprint_id, name, goal)

    elif command == "start":
        if len(sys.argv) < 3:
            print("❌ 스프린트 ID를 입력하세요.")
            sys.exit(1)

        sprint_id = int(sys.argv[2])
        manager.start_sprint(sprint_id)

    else:
        print(f"❌ 알 수 없는 명령: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
