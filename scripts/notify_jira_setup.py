#!/usr/bin/env python3
"""
JIRA Multi-cluster 백로그 생성 완료 Slack 알림
"""

import os
from slack_sdk import WebClient
from dotenv import load_dotenv

load_dotenv()

SLACK_TOKEN = os.getenv('SLACK_BOT_TOKEN')
SLACK_CHANNEL_ID = os.getenv('SLACK_CHANNEL_ID', 'C07HFHA7J7L')
JIRA_URL = os.getenv('JIRA_URL', 'https://gjrjr4545.atlassian.net/')
JIRA_PROJECT_KEY = os.getenv('JIRA_PROJECT_KEY', 'TERRAFORM')

client = WebClient(token=SLACK_TOKEN)

response = client.chat_postMessage(
    channel=SLACK_CHANNEL_ID,
    text="Multi-cluster 프로젝트 JIRA 백로그 생성 완료!",
    blocks=[
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "🎉 Multi-cluster 프로젝트 JIRA 백로그 생성 완료!"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": "*총 Story 수:*\n16개 (Optional 1개 포함)"
                },
                {
                    "type": "mrkdwn",
                    "text": "*총 Story Points:*\n112 SP"
                }
            ]
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Sprint별 구성:*\n• Sprint 1 (Week 1): 5개 Story, 37 SP\n• Sprint 2 (Week 2): 6개 Story, 44 SP\n• Sprint 3 (Week 3): 4개 Story, 31 SP\n• Backlog (Optional): 1개 Story, 5 SP"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*JIRA 프로젝트:*\n<{JIRA_URL}/projects/{JIRA_PROJECT_KEY}|{JIRA_PROJECT_KEY} Board 확인>"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*주요 Phase:*\n✅ Phase 1: 인프라 기반 (16 SP)\n✅ Phase 2: Control Cluster 애드온 (52 SP)\n✅ Phase 3: App Cluster 애드온 (13 SP)\n✅ Phase 5: 자동화 (10 SP)\n✅ Phase 6: 테스트 & 문서 (21 SP)"
            }
        },
        {
            "type": "divider"
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "📝 상세 문서: `docs/JIRA_SPRINT_SUMMARY.md`\n📊 견적서: `docs/MULTI_CLUSTER_ESTIMATE.md`"
            }
        }
    ]
)

print(f"✅ Slack 알림 전송 완료: {response['ts']}")
