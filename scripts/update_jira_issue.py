#!/usr/bin/env python3
"""
JIRA 이슈 업데이트 스크립트
"""

import sys
from jira_client import JiraClient


def main():
    if len(sys.argv) < 3:
        print("Usage: python update_jira_issue.py <issue_key> <pr_url>")
        sys.exit(1)

    issue_key = sys.argv[1]
    pr_url = sys.argv[2]

    client = JiraClient()

    # 코멘트 추가
    comment = f"""개발 완료 및 PR 생성

PR: {pr_url}

주요 작업 내용:
- Fluent Bit 설정 파일 생성 (fluent-bit-values.yaml)
- install.sh에 Fluent Bit 설치 명령어 추가
- Promtail → Fluent Bit 마이그레이션 가이드 작성

기술 스택:
- Helm Chart: fluent/fluent-bit (latest stable)
- 리소스 최적화: CPU 50m-200m, Memory 64Mi-128Mi
- 멀티 출력: Loki + OpenTelemetry Collector

검증 완료:
✅ YAML 문법 검증
✅ Bash 스크립트 검증
✅ PR 생성 완료

다음 단계: PR 리뷰 및 스테이징 배포 테스트
"""

    success = client.add_comment(issue_key, comment)

    if success:
        print(f"✅ JIRA 이슈 {issue_key} 코멘트 추가 완료")
    else:
        print(f"❌ JIRA 이슈 {issue_key} 코멘트 추가 실패")
        sys.exit(1)


if __name__ == "__main__":
    main()
