#!/usr/bin/env python3
"""
Claude Code SubAgent - PR Creator

GitHub Pull Request 자동 생성 클라이언트
"""

import subprocess
import sys
from typing import Optional
from pathlib import Path


class PRCreator:
    """Pull Request 생성 클래스"""

    def __init__(self, repo_path: str = "."):
        """
        PR Creator 초기화

        Args:
            repo_path: Git 저장소 경로
        """
        self.repo_path = Path(repo_path)

    def create_pr(
        self,
        title: str,
        body: str,
        base_branch: str = "grafana-stage",
        head_branch: Optional[str] = None,
        draft: bool = False
    ) -> Optional[str]:
        """
        Pull Request 생성

        Args:
            title: PR 제목
            body: PR 본문
            base_branch: 베이스 브랜치 (기본: grafana-stage)
            head_branch: 헤드 브랜치 (기본: 현재 브랜치)
            draft: Draft PR 여부

        Returns:
            생성된 PR URL 또는 None
        """
        try:
            # 현재 브랜치 확인
            if not head_branch:
                head_branch = self._get_current_branch()

            print(f"📝 PR 생성 중...")
            print(f"  Base: {base_branch}")
            print(f"  Head: {head_branch}")
            print(f"  Title: {title}")

            # gh CLI를 사용한 PR 생성
            cmd = [
                "gh", "pr", "create",
                "--title", title,
                "--body", body,
                "--base", base_branch,
                "--head", head_branch
            ]

            if draft:
                cmd.append("--draft")

            result = subprocess.run(
                cmd,
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=False
            )

            if result.returncode == 0:
                pr_url = result.stdout.strip()
                print(f"✅ PR 생성 완료: {pr_url}")
                return pr_url
            else:
                print(f"❌ PR 생성 실패:")
                print(result.stderr)
                return None

        except Exception as e:
            print(f"❌ PR 생성 실패: {e}")
            return None

    def _get_current_branch(self) -> str:
        """
        현재 Git 브랜치명 조회

        Returns:
            브랜치명
        """
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()

        except subprocess.CalledProcessError as e:
            print(f"❌ 현재 브랜치 조회 실패: {e}")
            return "main"

    def push_branch(
        self,
        branch: Optional[str] = None,
        force: bool = False
    ) -> bool:
        """
        브랜치를 원격 저장소에 푸시

        Args:
            branch: 푸시할 브랜치명 (기본: 현재 브랜치)
            force: Force push 여부

        Returns:
            성공 여부
        """
        try:
            if not branch:
                branch = self._get_current_branch()

            print(f"🚀 브랜치 푸시: {branch}")

            cmd = ["git", "push", "origin", branch]

            if force:
                cmd.append("--force")

            result = subprocess.run(
                cmd,
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=False
            )

            if result.returncode == 0:
                print(f"✅ 브랜치 푸시 완료: {branch}")
                return True
            else:
                print(f"❌ 브랜치 푸시 실패:")
                print(result.stderr)
                return False

        except Exception as e:
            print(f"❌ 브랜치 푸시 실패: {e}")
            return False

    def commit_changes(
        self,
        message: str,
        add_all: bool = True
    ) -> bool:
        """
        변경사항 커밋

        Args:
            message: 커밋 메시지
            add_all: 모든 변경사항 추가 여부

        Returns:
            성공 여부
        """
        try:
            # 변경사항 스테이징
            if add_all:
                subprocess.run(
                    ["git", "add", "."],
                    cwd=self.repo_path,
                    check=True
                )

            # 커밋
            result = subprocess.run(
                ["git", "commit", "-m", message],
                cwd=self.repo_path,
                capture_output=True,
                text=True,
                check=False
            )

            if result.returncode == 0:
                print(f"✅ 커밋 완료: {message}")
                return True
            else:
                # 변경사항이 없으면 에러가 아님
                if "nothing to commit" in result.stdout:
                    print("ℹ️  변경사항이 없습니다.")
                    return True
                else:
                    print(f"❌ 커밋 실패:")
                    print(result.stderr)
                    return False

        except Exception as e:
            print(f"❌ 커밋 실패: {e}")
            return False

    def create_branch(
        self,
        branch_name: str,
        base_branch: str = "grafana-stage"
    ) -> bool:
        """
        새 브랜치 생성

        Args:
            branch_name: 생성할 브랜치명
            base_branch: 베이스 브랜치

        Returns:
            성공 여부
        """
        try:
            print(f"🌿 브랜치 생성: {branch_name} (from {base_branch})")

            # 베이스 브랜치 체크아웃
            subprocess.run(
                ["git", "checkout", base_branch],
                cwd=self.repo_path,
                capture_output=True,
                check=True
            )

            # 최신 상태로 업데이트
            subprocess.run(
                ["git", "pull", "origin", base_branch],
                cwd=self.repo_path,
                capture_output=True,
                check=True
            )

            # 새 브랜치 생성 및 체크아웃
            subprocess.run(
                ["git", "checkout", "-b", branch_name],
                cwd=self.repo_path,
                capture_output=True,
                check=True
            )

            print(f"✅ 브랜치 생성 완료: {branch_name}")
            return True

        except subprocess.CalledProcessError as e:
            print(f"❌ 브랜치 생성 실패: {e}")
            return False


def main():
    """테스트용 메인 함수"""
    import argparse

    parser = argparse.ArgumentParser(description="PR Creator")
    parser.add_argument("--title", required=True, help="PR 제목")
    parser.add_argument("--body", default="", help="PR 본문")
    parser.add_argument("--base", default="grafana-stage", help="베이스 브랜치")
    parser.add_argument("--draft", action="store_true", help="Draft PR")

    args = parser.parse_args()

    creator = PRCreator()
    pr_url = creator.create_pr(
        title=args.title,
        body=args.body,
        base_branch=args.base,
        draft=args.draft
    )

    sys.exit(0 if pr_url else 1)


if __name__ == "__main__":
    main()
