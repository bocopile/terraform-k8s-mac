#!/usr/bin/env python3
"""
JIRA 이슈의 사용 가능한 전환(transition) 조회
"""

import sys
from jira_client import JiraClient


def main():
    if len(sys.argv) < 2:
        print("Usage: python check_transitions.py <issue_key>")
        sys.exit(1)

    issue_key = sys.argv[1]
    client = JiraClient()

    # 전환 목록 조회
    transitions = client._get_transitions(issue_key)

    if transitions:
        print(f"\n사용 가능한 전환 ({issue_key}):")
        print("-" * 50)
        for trans in transitions:
            trans_id = trans['id']
            trans_name = trans['name']
            to_status = trans['to']['name']
            print(f"  ID: {trans_id:3s} | {trans_name:20s} → {to_status}")
        print("-" * 50)
    else:
        print(f"❌ {issue_key}의 전환을 조회할 수 없습니다.")


if __name__ == "__main__":
    main()
