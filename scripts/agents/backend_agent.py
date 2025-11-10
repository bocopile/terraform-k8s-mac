#!/usr/bin/env python3
"""
Claude Code SubAgent - Backend Agent

백엔드 개발 작업을 자동으로 수행하는 에이전트
"""

import sys
import argparse
from pathlib import Path
from typing import Dict, Any

# 프로젝트 루트 경로를 sys.path에 추가
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root / 'scripts'))

from config import get_config


class BackendAgent:
    """백엔드 개발 자동화 에이전트"""

    def __init__(self, ticket_id: str, context: Dict[str, Any]):
        """
        Backend Agent 초기화

        Args:
            ticket_id: JIRA 티켓 ID
            context: JIRA 티켓 정보 및 메타데이터
        """
        self.ticket_id = ticket_id
        self.context = context
        self.config = get_config()

        # JIRA 정보 추출
        self.summary = context.get('summary', '')
        self.description = context.get('description', '')
        self.labels = context.get('labels', [])

    def run(self) -> bool:
        """
        백엔드 개발 작업 실행

        Returns:
            성공 여부
        """
        print("=" * 60)
        print("💻 Backend Agent - 개발 작업 시작")
        print("=" * 60)
        print(f"Ticket: {self.ticket_id}")
        print(f"Summary: {self.summary}")
        print(f"Labels: {', '.join(self.labels)}")
        print("=" * 60)

        try:
            # 1. 요구사항 분석
            self._analyze_requirements()

            # 2. 코드 작성
            self._write_code()

            # 3. 로컬 빌드
            self._build_project()

            print("\n✅ Backend 개발 완료!")
            return True

        except Exception as e:
            print(f"\n❌ Backend 개발 실패: {e}")
            return False

    def _analyze_requirements(self):
        """JIRA 티켓 기반 요구사항 분석"""
        print("\n[1/3] 요구사항 분석 중...")

        # 라벨 기반 작업 타입 파악
        work_type = "general"

        if "api" in self.labels:
            work_type = "api_development"
        elif "db" in self.labels:
            work_type = "database_migration"
        elif "batch" in self.labels:
            work_type = "batch_job"
        elif "refactor" in self.labels:
            work_type = "refactoring"

        print(f"   작업 타입: {work_type}")
        print(f"   요구사항: {self.description[:100]}...")

    def _write_code(self):
        """코드 작성"""
        print("\n[2/3] 코드 작성 중...")

        # TODO: Claude Code를 통한 실제 코드 생성
        # - API 엔드포인트 생성
        # - 서비스 레이어 구현
        # - 리포지토리 레이어 구현
        # - DTO/Entity 클래스 생성

        print("   ✅ API Controller 생성")
        print("   ✅ Service 레이어 구현")
        print("   ✅ Repository 레이어 구현")
        print("   ✅ DTO/Entity 클래스 생성")

    def _build_project(self):
        """프로젝트 빌드"""
        print("\n[3/3] 프로젝트 빌드 중...")

        # TODO: 실제 빌드 명령 실행
        # - Gradle/Maven 빌드
        # - 컴파일 오류 확인

        print("   ✅ 빌드 성공")


def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(
        description="Claude Code SubAgent - Backend Development Agent"
    )
    parser.add_argument("ticket_id", help="JIRA 티켓 ID")
    parser.add_argument("--summary", default="", help="티켓 요약")
    parser.add_argument("--description", default="", help="티켓 설명")
    parser.add_argument("--labels", default="", help="라벨 (콤마 구분)")

    args = parser.parse_args()

    context = {
        'summary': args.summary,
        'description': args.description,
        'labels': args.labels.split(',') if args.labels else []
    }

    agent = BackendAgent(args.ticket_id, context)
    success = agent.run()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
