#!/usr/bin/env python3
"""
Jira 워크플로우 자동화 스크립트

이 스크립트는 Jira 이슈 관리를 자동화합니다:
- 이슈 시작: 상태 변경 + 댓글 + 브랜치 생성
- 진행 상황 업데이트
- 이슈 완료: 상태 변경 + 최종 댓글

사용법:
    python scripts/jira_workflow.py get-issue TERRAFORM-66
    python scripts/jira_workflow.py start-issue TERRAFORM-66
    python scripts/jira_workflow.py add-comment TERRAFORM-66 "메시지"
    python scripts/jira_workflow.py complete-issue TERRAFORM-66 --commit abc1234 --notion-url "..."
"""

import os
import sys
import yaml
import argparse
import subprocess
from pathlib import Path
from atlassian import Jira
from dotenv import load_dotenv

# .env 파일 로드
load_dotenv()

# 프로젝트 루트 디렉토리
PROJECT_ROOT = Path(__file__).parent.parent

# workflow.yaml 로드
WORKFLOW_CONFIG_PATH = PROJECT_ROOT / ".claude" / "config" / "workflow.yaml"


def load_workflow_config():
    """workflow.yaml 설정 로드"""
    if not WORKFLOW_CONFIG_PATH.exists():
        print(f"❌ 오류: {WORKFLOW_CONFIG_PATH} 파일을 찾을 수 없습니다.")
        sys.exit(1)

    with open(WORKFLOW_CONFIG_PATH, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def get_jira_client():
    """Jira 클라이언트 생성"""
    jira_url = os.getenv("JIRA_URL")
    jira_email = os.getenv("JIRA_EMAIL")
    jira_token = os.getenv("JIRA_API_TOKEN")

    if not jira_email or not jira_token:
        print("❌ 오류: JIRA_EMAIL 또는 JIRA_API_TOKEN이 설정되지 않았습니다.")
        print("   .env 파일을 확인하세요.")
        sys.exit(1)

    return Jira(url=jira_url, username=jira_email, password=jira_token, cloud=True)


def get_issue(issue_key):
    """Jira 이슈 조회"""
    jira = get_jira_client()

    try:
        issue = jira.issue(issue_key)
        print(f"\n📋 {issue_key}: {issue['fields']['summary']}")
        print(f"상태: {issue['fields']['status']['name']}")
        print(f"우선순위: {issue['fields']['priority']['name']}")
        print(f"담당자: {issue['fields'].get('assignee', {}).get('displayName', '미할당')}")
        print(f"URL: {os.getenv('JIRA_URL')}/browse/{issue_key}\n")
        return issue
    except Exception as e:
        print(f"❌ 이슈 조회 실패: {e}")
        sys.exit(1)


def get_transition_id(jira, issue_key, transition_name):
    """상태 전환 ID 조회"""
    try:
        url = f"rest/api/3/issue/{issue_key}/transitions"
        transitions = jira.get(url)

        for transition in transitions.get('transitions', []):
            if transition['name'] == transition_name:
                return transition['id']

        print(f"⚠️  경고: '{transition_name}' 전환을 찾을 수 없습니다.")
        print(f"   사용 가능한 전환: {[t['name'] for t in transitions.get('transitions', [])]}")
        return None
    except Exception as e:
        print(f"⚠️  전환 ID 조회 실패: {e}")
        return None


def transition_issue(issue_key, transition_name):
    """Jira 이슈 상태 전환"""
    jira = get_jira_client()

    try:
        transition_id = get_transition_id(jira, issue_key, transition_name)
        if not transition_id:
            return False

        url = f"rest/api/3/issue/{issue_key}/transitions"
        jira.post(url, data={"transition": {"id": transition_id}})
        print(f"✅ 상태 변경: {transition_name}")
        return True
    except Exception as e:
        print(f"❌ 상태 변경 실패: {e}")
        return False


def add_comment(issue_key, comment_body):
    """Jira 이슈에 댓글 추가"""
    jira = get_jira_client()

    try:
        url = f"rest/api/3/issue/{issue_key}/comment"
        jira.post(url, data={"body": comment_body})
        print(f"✅ 댓글 작성 완료")
        return True
    except Exception as e:
        print(f"❌ 댓글 작성 실패: {e}")
        return False


def create_branch(issue_key):
    """Git 브랜치 생성"""
    config = load_workflow_config()
    branch_prefix = config['git']['branch_prefix']
    branch_name = f"{branch_prefix}{issue_key.split('-')[1]}"

    try:
        # stage 브랜치로 이동 및 업데이트
        subprocess.run(["git", "checkout", "stage"], check=True, capture_output=True)
        subprocess.run(["git", "pull", "origin", "stage"], check=True, capture_output=True)

        # 새 브랜치 생성
        subprocess.run(["git", "checkout", "-b", branch_name], check=True, capture_output=True)

        print(f"✅ Git 브랜치 생성: {branch_name}")
        return branch_name
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Git 브랜치 생성 실패: {e}")
        return None


def start_issue(issue_key):
    """
    이슈 시작:
    1. 상태 변경 (진행 중)
    2. 시작 댓글 작성
    3. Git 브랜치 생성
    """
    config = load_workflow_config()

    print(f"\n🚀 {issue_key} 작업 시작...\n")

    # 1. 이슈 조회
    issue = get_issue(issue_key)

    # 2. 상태 변경
    transition_name = config['jira']['transitions']['start']
    if not transition_issue(issue_key, transition_name):
        print("⚠️  상태 변경은 실패했지만 계속 진행합니다.")

    # 3. Git 브랜치 생성
    branch_name = create_branch(issue_key)
    if not branch_name:
        branch_name = f"feature/terraform-{issue_key.split('-')[1]}"

    # 4. 시작 댓글 작성
    comment_template = config['jira']['comment_templates']['start']
    comment = comment_template.format(branch_name=branch_name)
    add_comment(issue_key, comment)

    print(f"\n✨ {issue_key} 작업 준비 완료!")
    print(f"   브랜치: {branch_name}")
    print(f"   다음 단계: 코드 작업 시작\n")


def add_progress_comment(issue_key, milestone):
    """진행 상황 댓글 작성"""
    config = load_workflow_config()

    print(f"\n📝 {issue_key} 진행 상황 업데이트...\n")

    comment_template = config['jira']['comment_templates']['progress']
    comment = comment_template.format(milestone=milestone)

    if add_comment(issue_key, comment):
        print(f"✨ 진행 상황 업데이트 완료: {milestone}\n")


def add_commit_comment(issue_key, commit_hash, changes=""):
    """커밋 완료 댓글 작성"""
    config = load_workflow_config()

    print(f"\n📝 {issue_key} 커밋 완료 댓글 작성...\n")

    comment_template = config['jira']['comment_templates']['commit']
    comment = comment_template.format(commit_hash=commit_hash, changes=changes)

    if add_comment(issue_key, comment):
        print(f"✨ 커밋 완료 댓글 작성 완료\n")


def add_notion_comment(issue_key, notion_url):
    """Notion 문서 링크 댓글 작성"""
    config = load_workflow_config()

    print(f"\n📝 {issue_key} Notion 문서 링크 댓글 작성...\n")

    comment_template = config['jira']['comment_templates']['notion']
    comment = comment_template.format(notion_url=notion_url)

    if add_comment(issue_key, comment):
        print(f"✨ Notion 문서 링크 댓글 작성 완료\n")


def complete_issue(issue_key, commit_hash, notion_url, test_summary="", changes_summary=""):
    """
    이슈 완료:
    1. 최종 완료 댓글 작성
    2. 상태 변경 (완료)
    """
    config = load_workflow_config()

    print(f"\n🎉 {issue_key} 작업 완료 처리...\n")

    # 브랜치명 추출
    try:
        current_branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            text=True
        ).strip()
    except:
        current_branch = f"feature/terraform-{issue_key.split('-')[1]}"

    # 1. 최종 완료 댓글 작성
    comment_template = config['jira']['comment_templates']['complete']
    comment = comment_template.format(
        commit_hash=commit_hash,
        notion_url=notion_url,
        branch_name=current_branch,
        test_summary=test_summary or "테스트 통과",
        changes_summary=changes_summary or "주요 변경사항 참조"
    )

    if not add_comment(issue_key, comment):
        print("⚠️  완료 댓글 작성은 실패했지만 계속 진행합니다.")

    # 2. 상태 변경 (완료)
    transition_name = config['jira']['transitions']['complete']
    if transition_issue(issue_key, transition_name):
        print(f"\n✨ {issue_key} 작업 완료!")
        print(f"   커밋: {commit_hash}")
        print(f"   문서: {notion_url}")
        print(f"   브랜치: {current_branch}\n")
    else:
        print("\n⚠️  상태 변경 실패. Jira 웹에서 수동으로 완료 처리하세요.\n")


def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(description="Jira 워크플로우 자동화 스크립트")
    subparsers = parser.add_subparsers(dest='command', help='명령어')

    # get-issue 명령어
    parser_get = subparsers.add_parser('get-issue', help='이슈 조회')
    parser_get.add_argument('issue_key', help='Jira 이슈 키 (예: TERRAFORM-66)')

    # start-issue 명령어
    parser_start = subparsers.add_parser('start-issue', help='이슈 시작')
    parser_start.add_argument('issue_key', help='Jira 이슈 키')

    # add-comment 명령어
    parser_comment = subparsers.add_parser('add-comment', help='댓글 추가')
    parser_comment.add_argument('issue_key', help='Jira 이슈 키')
    parser_comment.add_argument('message', help='댓글 내용')

    # add-progress-comment 명령어
    parser_progress = subparsers.add_parser('add-progress-comment', help='진행 상황 댓글 추가')
    parser_progress.add_argument('issue_key', help='Jira 이슈 키')
    parser_progress.add_argument('milestone', help='마일스톤 내용')

    # add-commit-comment 명령어
    parser_commit = subparsers.add_parser('add-commit-comment', help='커밋 완료 댓글 추가')
    parser_commit.add_argument('issue_key', help='Jira 이슈 키')
    parser_commit.add_argument('commit_hash', help='커밋 해시')
    parser_commit.add_argument('--changes', default="", help='변경 내용')

    # add-notion-comment 명령어
    parser_notion = subparsers.add_parser('add-notion-comment', help='Notion 문서 링크 댓글 추가')
    parser_notion.add_argument('issue_key', help='Jira 이슈 키')
    parser_notion.add_argument('notion_url', help='Notion 문서 URL')

    # complete-issue 명령어
    parser_complete = subparsers.add_parser('complete-issue', help='이슈 완료')
    parser_complete.add_argument('issue_key', help='Jira 이슈 키')
    parser_complete.add_argument('--commit', required=True, help='커밋 해시')
    parser_complete.add_argument('--notion-url', required=True, help='Notion 문서 URL')
    parser_complete.add_argument('--test-summary', default="", help='테스트 결과 요약')
    parser_complete.add_argument('--changes-summary', default="", help='변경사항 요약')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # 명령어 실행
    if args.command == 'get-issue':
        get_issue(args.issue_key)

    elif args.command == 'start-issue':
        start_issue(args.issue_key)

    elif args.command == 'add-comment':
        add_comment(args.issue_key, args.message)

    elif args.command == 'add-progress-comment':
        add_progress_comment(args.issue_key, args.milestone)

    elif args.command == 'add-commit-comment':
        add_commit_comment(args.issue_key, args.commit_hash, args.changes)

    elif args.command == 'add-notion-comment':
        add_notion_comment(args.issue_key, args.notion_url)

    elif args.command == 'complete-issue':
        complete_issue(
            args.issue_key,
            args.commit,
            args.notion_url,
            args.test_summary,
            args.changes_summary
        )


if __name__ == "__main__":
    main()
