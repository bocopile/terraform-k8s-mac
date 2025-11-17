#!/usr/bin/env python3
"""
Jira 스프린트 생성 및 이슈 할당 스크립트
"""

import os
import sys
from atlassian import Jira
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# Jira 설정
JIRA_URL = os.getenv("JIRA_URL", "https://gjrjr4545.atlassian.net")
JIRA_EMAIL = os.getenv("JIRA_EMAIL")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")

# 스프린트 구성
SPRINTS = [
    {
        "name": "Sprint 1 - Infra & Network",
        "goal": "Multi-cluster 기초 인프라 구축 및 네트워크 설정",
        "issues": [
            "TERRAFORM-66",  # Terraform 코드 모듈화
            "TERRAFORM-69",  # ArgoCD GitOps Hub 구성
            "TERRAFORM-70",  # Prometheus Federation 중앙 모니터링 구성
            "TERRAFORM-67",  # Multi-cluster 네트워크 구성
            "TERRAFORM-68",  # 클러스터 초기화 스크립트 분리
        ]
    },
    {
        "name": "Sprint 2 - Services",
        "goal": "Service Mesh, Logging, Tracing, Secrets 중앙화",
        "issues": [
            "TERRAFORM-74",  # Istio Multi-cluster Service Mesh 구성
            "TERRAFORM-71",  # Loki 중앙 로깅 시스템 구성
            "TERRAFORM-72",  # Tempo 중앙 트레이싱 시스템 구성
            "TERRAFORM-73",  # Vault 중앙 시크릿 관리 시스템 구성
            "TERRAFORM-75",  # App Cluster Workload 애드온 설치
            "TERRAFORM-76",  # App Cluster Observability Agent 설정
        ]
    },
    {
        "name": "Sprint 3 - Deploy & Docs",
        "goal": "배포 자동화, 통합 테스트 및 문서화",
        "issues": [
            "TERRAFORM-78",  # Multi-cluster 설치 스크립트 작성
            "TERRAFORM-80",  # Multi-cluster 통합 테스트
            "TERRAFORM-81",  # Multi-cluster 문서화
            "TERRAFORM-82",  # 기존 docs 문서를 Notion으로 마이그레이션
        ]
    }
]


def main():
    """메인 실행 함수"""

    # 인증 정보 확인
    if not JIRA_EMAIL or not JIRA_API_TOKEN:
        print("❌ 오류: JIRA_EMAIL 또는 JIRA_API_TOKEN이 설정되지 않았습니다.")
        print("   .env 파일을 확인하세요.")
        sys.exit(1)

    # Jira 연결
    print(f"🔗 Jira 연결 중... ({JIRA_URL})")
    jira = Jira(
        url=JIRA_URL,
        username=JIRA_EMAIL,
        password=JIRA_API_TOKEN,
        cloud=True
    )

    # 프로젝트 확인
    project_key = "TERRAFORM"
    try:
        project = jira.project(project_key)
        print(f"✅ 프로젝트 확인: {project['name']}")
    except Exception as e:
        print(f"❌ 프로젝트 조회 실패: {e}")
        sys.exit(1)

    # 보드 ID 찾기
    print("\n📋 보드 조회 중...")
    try:
        # Agile API를 직접 호출
        url = "rest/agile/1.0/board"
        response = jira.get(url)
        boards = response.get('values', [])

        terraform_board = None
        for board in boards:
            if project_key in board.get('name', '') or board.get('location', {}).get('projectKey') == project_key:
                terraform_board = board
                break

        if not terraform_board:
            print(f"❌ {project_key} 프로젝트의 보드를 찾을 수 없습니다.")
            print("   Jira에서 먼저 Scrum 보드를 생성해주세요.")
            sys.exit(1)

        board_id = terraform_board['id']
        print(f"✅ 보드 확인: {terraform_board['name']} (ID: {board_id})")

    except Exception as e:
        print(f"❌ 보드 조회 실패: {e}")
        sys.exit(1)

    # 스프린트 생성 및 이슈 할당
    print("\n🏃 스프린트 생성 시작...\n")

    for sprint_config in SPRINTS:
        sprint_name = sprint_config["name"]
        sprint_goal = sprint_config["goal"]
        issue_keys = sprint_config["issues"]

        print(f"📌 {sprint_name}")
        print(f"   목표: {sprint_goal}")

        try:
            # 스프린트 생성 (Agile API 직접 호출)
            sprint_url = "rest/agile/1.0/sprint"
            sprint_data = {
                "name": sprint_name,
                "originBoardId": board_id,
                "goal": sprint_goal
            }
            sprint = jira.post(sprint_url, data=sprint_data)
            sprint_id = sprint['id']
            print(f"   ✅ 스프린트 생성 완료 (ID: {sprint_id})")

            # 이슈를 스프린트에 할당
            print(f"   📝 이슈 할당 중...")
            move_url = f"rest/agile/1.0/sprint/{sprint_id}/issue"
            for issue_key in issue_keys:
                try:
                    # 이슈 키로 이슈 정보 조회
                    issue = jira.issue(issue_key)
                    issue_id = issue['id']

                    # 스프린트에 이슈 추가
                    jira.post(move_url, data={"issues": [issue_id]})
                    print(f"      ✅ {issue_key} 할당 완료")
                except Exception as e:
                    print(f"      ⚠️  {issue_key} 할당 실패: {e}")

            print(f"   ✅ {sprint_name} 완료\n")

        except Exception as e:
            print(f"   ❌ 스프린트 생성 실패: {e}\n")
            continue

    print("=" * 60)
    print("✨ 스프린트 생성 완료!")
    print(f"🔗 {JIRA_URL}/jira/software/c/projects/{project_key}/boards/{board_id}")
    print("=" * 60)


if __name__ == "__main__":
    main()
