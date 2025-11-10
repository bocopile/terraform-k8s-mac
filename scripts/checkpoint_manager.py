#!/usr/bin/env python3
"""
Claude Code SubAgent - Checkpoint Manager

워크플로우 체크포인트 관리 클라이언트
"""

import json
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime


class CheckpointManager:
    """체크포인트 관리 클래스"""

    def __init__(self, checkpoint_dir: str = "./checkpoints"):
        """
        Checkpoint Manager 초기화

        Args:
            checkpoint_dir: 체크포인트 파일 저장 디렉토리
        """
        self.checkpoint_dir = Path(checkpoint_dir)
        self.checkpoint_dir.mkdir(exist_ok=True)

    def save(
        self,
        ticket_id: str,
        state: Dict[str, Any]
    ) -> bool:
        """
        체크포인트 저장

        Args:
            ticket_id: JIRA 티켓 ID
            state: 저장할 상태 딕셔너리

        Returns:
            성공 여부
        """
        try:
            checkpoint_file = self.checkpoint_dir / f"{ticket_id}.json"

            # 타임스탬프 추가
            state["updated_at"] = datetime.now().isoformat()

            with open(checkpoint_file, 'w', encoding='utf-8') as f:
                json.dump(state, f, indent=2, ensure_ascii=False)

            print(f"💾 체크포인트 저장: {checkpoint_file}")
            return True

        except Exception as e:
            print(f"❌ 체크포인트 저장 실패: {e}")
            return False

    def load(
        self,
        ticket_id: str
    ) -> Optional[Dict[str, Any]]:
        """
        체크포인트 로드

        Args:
            ticket_id: JIRA 티켓 ID

        Returns:
            저장된 상태 딕셔너리 또는 None
        """
        try:
            checkpoint_file = self.checkpoint_dir / f"{ticket_id}.json"

            if not checkpoint_file.exists():
                print(f"⚠️  체크포인트 파일이 없습니다: {checkpoint_file}")
                return None

            with open(checkpoint_file, 'r', encoding='utf-8') as f:
                state = json.load(f)

            print(f"✅ 체크포인트 로드: {checkpoint_file}")
            return state

        except Exception as e:
            print(f"❌ 체크포인트 로드 실패: {e}")
            return None

    def delete(
        self,
        ticket_id: str
    ) -> bool:
        """
        체크포인트 삭제

        Args:
            ticket_id: JIRA 티켓 ID

        Returns:
            성공 여부
        """
        try:
            checkpoint_file = self.checkpoint_dir / f"{ticket_id}.json"

            if checkpoint_file.exists():
                # 백업 생성
                backup_file = checkpoint_file.with_suffix('.json.bak')
                checkpoint_file.rename(backup_file)
                print(f"💾 체크포인트 백업: {backup_file}")
                return True
            else:
                print(f"⚠️  체크포인트 파일이 없습니다: {checkpoint_file}")
                return False

        except Exception as e:
            print(f"❌ 체크포인트 삭제 실패: {e}")
            return False

    def list_checkpoints(self) -> list:
        """
        모든 체크포인트 목록 조회

        Returns:
            체크포인트 파일 리스트
        """
        try:
            checkpoints = list(self.checkpoint_dir.glob("*.json"))
            return [cp.stem for cp in checkpoints]

        except Exception as e:
            print(f"❌ 체크포인트 목록 조회 실패: {e}")
            return []

    def get_last_step(
        self,
        ticket_id: str
    ) -> Optional[str]:
        """
        마지막으로 완료한 단계 조회

        Args:
            ticket_id: JIRA 티켓 ID

        Returns:
            마지막 단계명 또는 None
        """
        state = self.load(ticket_id)

        if not state:
            return None

        steps = state.get('steps', {})
        last_step = None

        for step_name, step_data in steps.items():
            if step_data.get('status') == 'completed':
                last_step = step_name

        return last_step

    def print_status(
        self,
        ticket_id: str
    ):
        """
        체크포인트 상태 출력

        Args:
            ticket_id: JIRA 티켓 ID
        """
        state = self.load(ticket_id)

        if not state:
            print(f"체크포인트를 찾을 수 없습니다: {ticket_id}")
            return

        print("=" * 60)
        print(f"체크포인트 상태: {ticket_id}")
        print("=" * 60)
        print(f"브랜치: {state.get('branch')}")
        print(f"상태: {state.get('status')}")
        print(f"시작 시간: {state.get('started_at')}")
        print(f"마지막 업데이트: {state.get('updated_at')}")
        print()

        print("단계별 상태:")
        steps = state.get('steps', {})
        for step_name, step_data in steps.items():
            status = step_data.get('status', 'unknown')
            error = step_data.get('error')

            status_icon = {
                'completed': '✅',
                'in_progress': '🔄',
                'failed': '❌',
                'pending': '⏸️',
                'skipped': '⏭️'
            }.get(status, '❓')

            print(f"  {status_icon} {step_name}: {status}")

            if error:
                print(f"      에러: {error}")

        print("=" * 60)


def main():
    """테스트용 메인 함수"""
    import sys

    manager = CheckpointManager()

    if len(sys.argv) > 1:
        ticket_id = sys.argv[1]
        manager.print_status(ticket_id)
    else:
        checkpoints = manager.list_checkpoints()
        print(f"저장된 체크포인트: {checkpoints}")


if __name__ == "__main__":
    main()
