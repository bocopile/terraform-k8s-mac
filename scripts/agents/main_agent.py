#!/usr/bin/env python3
"""
Claude Code SubAgent - Main Agent (Orchestrator)

전체 워크플로우를 관리하고 SubAgent들을 조율하는 메인 에이전트
"""

import sys
import os
import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional

# 프로젝트 루트 경로를 sys.path에 추가
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root / 'scripts'))

from config import get_config


class WorkflowStatus:
    """워크플로우 상태 관리"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"


class MainAgent:
    """메인 오케스트레이션 에이전트"""

    def __init__(self, ticket_id: str, resume: bool = False, restart: bool = False):
        """
        Main Agent 초기화

        Args:
            ticket_id: JIRA 티켓 ID (예: FINOPS-350)
            resume: 체크포인트에서 재개 여부
            restart: 처음부터 재시작 여부
        """
        self.ticket_id = ticket_id
        self.resume = resume
        self.restart = restart
        self.config = get_config()

        # 체크포인트 파일 경로
        self.checkpoint_dir = Path(self.config.checkpoint_dir)
        self.checkpoint_dir.mkdir(exist_ok=True)
        self.checkpoint_file = self.checkpoint_dir / f"{ticket_id}.json"

        # 워크플로우 상태
        self.state = self._load_checkpoint() if resume else self._init_state()

        # Agent 활성화 상태
        self.agents_enabled = {
            'backend': self.config.backend_agent_enabled,
            'qa': self.config.qa_agent_enabled,
            'review': self.config.review_agent_enabled,
            'docs': self.config.docs_agent_enabled,
        }

    def _init_state(self) -> Dict[str, Any]:
        """초기 상태 생성"""
        return {
            "ticket_id": self.ticket_id,
            "branch": f"feature/{self.ticket_id}",
            "status": WorkflowStatus.PENDING,
            "started_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
            "steps": {
                "jira_fetch": {"status": WorkflowStatus.PENDING, "error": None},
                "git_branch": {"status": WorkflowStatus.PENDING, "error": None},
                "backend_dev": {"status": WorkflowStatus.PENDING, "error": None},
                "qa_test": {"status": WorkflowStatus.PENDING, "error": None},
                "code_review": {"status": WorkflowStatus.PENDING, "error": None},
                "documentation": {"status": WorkflowStatus.PENDING, "error": None},
                "pr_creation": {"status": WorkflowStatus.PENDING, "error": None},
            },
            "metadata": {
                "jira_summary": None,
                "jira_description": None,
                "jira_labels": [],
                "pr_url": None,
            }
        }

    def _load_checkpoint(self) -> Dict[str, Any]:
        """체크포인트 파일에서 상태 로드"""
        if not self.checkpoint_file.exists():
            print(f"⚠️  체크포인트 파일이 없습니다: {self.checkpoint_file}")
            print("처음부터 시작합니다.")
            return self._init_state()

        try:
            with open(self.checkpoint_file, 'r', encoding='utf-8') as f:
                state = json.load(f)
                print(f"✅ 체크포인트 로드 완료: {self.checkpoint_file}")
                return state
        except Exception as e:
            print(f"❌ 체크포인트 로드 실패: {e}")
            print("처음부터 시작합니다.")
            return self._init_state()

    def _save_checkpoint(self):
        """현재 상태를 체크포인트 파일에 저장"""
        self.state["updated_at"] = datetime.now().isoformat()

        try:
            with open(self.checkpoint_file, 'w', encoding='utf-8') as f:
                json.dump(self.state, f, indent=2, ensure_ascii=False)
            print(f"💾 체크포인트 저장: {self.checkpoint_file}")
        except Exception as e:
            print(f"❌ 체크포인트 저장 실패: {e}")

    def _update_step(self, step_name: str, status: str, error: Optional[str] = None):
        """단계 상태 업데이트"""
        self.state["steps"][step_name] = {
            "status": status,
            "error": error,
            "timestamp": datetime.now().isoformat()
        }
        self._save_checkpoint()

    def run(self):
        """메인 워크플로우 실행"""
        print("=" * 60)
        print(f"🚀 Claude Code SubAgent - Main Workflow")
        print("=" * 60)
        print(f"Ticket ID: {self.ticket_id}")
        print(f"Mode: {'Resume' if self.resume else 'Restart' if self.restart else 'New'}")
        print(f"Branch: {self.state['branch']}")
        print("=" * 60)

        try:
            # 1. JIRA 티켓 조회/생성
            if self._should_run_step("jira_fetch"):
                self._run_jira_fetch()

            # 2. Git 브랜치 생성
            if self._should_run_step("git_branch"):
                self._run_git_branch()

            # 3. Backend Agent 실행
            if self.agents_enabled['backend'] and self._should_run_step("backend_dev"):
                self._run_backend_agent()

            # 4. QA Agent 실행
            if self.agents_enabled['qa'] and self._should_run_step("qa_test"):
                self._run_qa_agent()

            # 5. Review Agent 실행
            if self.agents_enabled['review'] and self._should_run_step("code_review"):
                self._run_review_agent()

            # 6. Docs Agent 실행
            if self.agents_enabled['docs'] and self._should_run_step("documentation"):
                self._run_docs_agent()

            # 7. PR 생성
            if self._should_run_step("pr_creation"):
                self._run_pr_creation()

            # 워크플로우 완료
            self.state["status"] = WorkflowStatus.COMPLETED
            self._save_checkpoint()

            print("\n" + "=" * 60)
            print("✅ 워크플로우 완료!")
            print("=" * 60)
            self._print_summary()

        except KeyboardInterrupt:
            print("\n⚠️  사용자에 의해 중단되었습니다.")
            self.state["status"] = WorkflowStatus.FAILED
            self._save_checkpoint()
            sys.exit(1)

        except Exception as e:
            print(f"\n❌ 워크플로우 실패: {e}")
            self.state["status"] = WorkflowStatus.FAILED
            self._save_checkpoint()
            sys.exit(1)

    def _should_run_step(self, step_name: str) -> bool:
        """단계 실행 여부 판단"""
        step_status = self.state["steps"][step_name]["status"]

        # Resume 모드: 완료된 단계는 건너뛰기
        if self.resume and step_status == WorkflowStatus.COMPLETED:
            print(f"⏭️  [{step_name}] 이미 완료됨 - 건너뜀")
            return False

        # Restart 모드 또는 New 모드: 모든 단계 실행
        return True

    def _run_jira_fetch(self):
        """JIRA 티켓 정보 조회/생성"""
        print(f"\n📋 [1/7] JIRA 티켓 조회: {self.ticket_id}")
        self._update_step("jira_fetch", WorkflowStatus.IN_PROGRESS)

        try:
            # TODO: JIRA API 호출 로직 구현
            # jira_client를 통해 티켓 정보 조회
            print(f"✅ JIRA 티켓 조회 완료")

            # 메타데이터 업데이트
            self.state["metadata"]["jira_summary"] = "Sample JIRA Ticket"
            self.state["metadata"]["jira_description"] = "Description here"
            self.state["metadata"]["jira_labels"] = ["backend", "api"]

            self._update_step("jira_fetch", WorkflowStatus.COMPLETED)

        except Exception as e:
            self._update_step("jira_fetch", WorkflowStatus.FAILED, str(e))
            raise

    def _run_git_branch(self):
        """Git 브랜치 생성"""
        print(f"\n🌿 [2/7] Git 브랜치 생성: {self.state['branch']}")
        self._update_step("git_branch", WorkflowStatus.IN_PROGRESS)

        try:
            # TODO: Git 브랜치 생성 로직 구현
            print(f"✅ Git 브랜치 생성 완료")
            self._update_step("git_branch", WorkflowStatus.COMPLETED)

        except Exception as e:
            self._update_step("git_branch", WorkflowStatus.FAILED, str(e))
            raise

    def _run_backend_agent(self):
        """Backend Agent 실행"""
        print(f"\n💻 [3/7] Backend Agent 실행")
        self._update_step("backend_dev", WorkflowStatus.IN_PROGRESS)

        try:
            # TODO: Backend Agent 호출
            print(f"✅ Backend 개발 완료")
            self._update_step("backend_dev", WorkflowStatus.COMPLETED)

        except Exception as e:
            self._update_step("backend_dev", WorkflowStatus.FAILED, str(e))
            raise

    def _run_qa_agent(self):
        """QA Agent 실행"""
        print(f"\n🧪 [4/7] QA Agent 실행")
        self._update_step("qa_test", WorkflowStatus.IN_PROGRESS)

        try:
            # TODO: QA Agent 호출
            print(f"✅ 테스트 완료")
            self._update_step("qa_test", WorkflowStatus.COMPLETED)

        except Exception as e:
            self._update_step("qa_test", WorkflowStatus.FAILED, str(e))
            raise

    def _run_review_agent(self):
        """Review Agent 실행"""
        print(f"\n👀 [5/7] Review Agent 실행")
        self._update_step("code_review", WorkflowStatus.IN_PROGRESS)

        try:
            # TODO: Review Agent 호출
            print(f"✅ 코드 리뷰 완료")
            self._update_step("code_review", WorkflowStatus.COMPLETED)

        except Exception as e:
            self._update_step("code_review", WorkflowStatus.FAILED, str(e))
            raise

    def _run_docs_agent(self):
        """Docs Agent 실행"""
        print(f"\n📝 [6/7] Docs Agent 실행")
        self._update_step("documentation", WorkflowStatus.IN_PROGRESS)

        try:
            # TODO: Docs Agent 호출
            print(f"✅ 문서화 완료")
            self._update_step("documentation", WorkflowStatus.COMPLETED)

        except Exception as e:
            self._update_step("documentation", WorkflowStatus.FAILED, str(e))
            raise

    def _run_pr_creation(self):
        """PR 생성"""
        print(f"\n🔀 [7/7] PR 생성")
        self._update_step("pr_creation", WorkflowStatus.IN_PROGRESS)

        try:
            # TODO: PR 생성 로직 구현
            pr_url = f"https://github.com/user/repo/pull/123"
            self.state["metadata"]["pr_url"] = pr_url

            print(f"✅ PR 생성 완료: {pr_url}")
            self._update_step("pr_creation", WorkflowStatus.COMPLETED)

        except Exception as e:
            self._update_step("pr_creation", WorkflowStatus.FAILED, str(e))
            raise

    def _print_summary(self):
        """워크플로우 요약 출력"""
        print(f"\n📊 워크플로우 요약:")
        print(f"  - 티켓: {self.ticket_id}")
        print(f"  - 브랜치: {self.state['branch']}")
        print(f"  - 상태: {self.state['status']}")

        if self.state["metadata"]["pr_url"]:
            print(f"  - PR: {self.state['metadata']['pr_url']}")

        print(f"\n단계별 상태:")
        for step_name, step_data in self.state["steps"].items():
            status_icon = {
                WorkflowStatus.COMPLETED: "✅",
                WorkflowStatus.IN_PROGRESS: "🔄",
                WorkflowStatus.FAILED: "❌",
                WorkflowStatus.PENDING: "⏸️",
                WorkflowStatus.SKIPPED: "⏭️",
            }.get(step_data["status"], "❓")

            print(f"  {status_icon} {step_name}: {step_data['status']}")


def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(
        description="Claude Code SubAgent - Main Workflow Orchestrator"
    )
    parser.add_argument(
        "ticket_id",
        help="JIRA 티켓 ID (예: FINOPS-350)"
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="체크포인트에서 재개"
    )
    parser.add_argument(
        "--restart",
        action="store_true",
        help="처음부터 재시작"
    )

    args = parser.parse_args()

    # Resume와 Restart 동시 사용 불가
    if args.resume and args.restart:
        print("❌ --resume과 --restart는 동시에 사용할 수 없습니다.")
        sys.exit(1)

    # Main Agent 실행
    agent = MainAgent(
        ticket_id=args.ticket_id,
        resume=args.resume,
        restart=args.restart
    )

    agent.run()


if __name__ == "__main__":
    main()
