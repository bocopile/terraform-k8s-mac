#!/usr/bin/env python3
"""
Claude Code SubAgent - Slack Notifier

Slack Webhook을 통한 알림 전송 클라이언트
"""

import requests
import json
from typing import Optional, Dict, Any, List
from datetime import datetime
from config import get_config


class SlackNotifier:
    """Slack 알림 전송 클라이언트"""

    def __init__(self):
        """Slack Notifier 초기화"""
        self.config = get_config()
        self.webhook_url = self.config.slack_webhook_url
        self.channel = self.config.slack_channel
        self.username = self.config.slack_username

    def send_message(
        self,
        text: str,
        attachments: Optional[List[Dict[str, Any]]] = None,
        blocks: Optional[List[Dict[str, Any]]] = None
    ) -> bool:
        """
        Slack 메시지 전송

        Args:
            text: 메시지 텍스트
            attachments: 첨부파일 (레거시)
            blocks: Block Kit 블록

        Returns:
            성공 여부
        """
        try:
            payload = {
                "channel": self.channel,
                "username": self.username,
                "text": text,
                "icon_emoji": ":robot_face:"
            }

            if attachments:
                payload["attachments"] = attachments

            if blocks:
                payload["blocks"] = blocks

            response = requests.post(
                self.webhook_url,
                json=payload,
                timeout=10
            )

            if response.status_code == 200:
                print(f"✅ Slack 알림 전송 완료")
                return True
            else:
                print(f"❌ Slack 알림 전송 실패: HTTP {response.status_code}")
                print(f"   {response.text}")
                return False

        except Exception as e:
            print(f"❌ Slack 알림 전송 실패: {e}")
            return False

    def notify_workflow_started(
        self,
        ticket_id: str,
        branch: str
    ) -> bool:
        """
        워크플로우 시작 알림

        Args:
            ticket_id: JIRA 티켓 ID
            branch: Git 브랜치명

        Returns:
            성공 여부
        """
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"🚀 워크플로우 시작: {ticket_id}"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*티켓:*\n{ticket_id}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*브랜치:*\n`{branch}`"
                    }
                ]
            },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": f"시작 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                    }
                ]
            }
        ]

        return self.send_message(
            text=f"워크플로우 시작: {ticket_id}",
            blocks=blocks
        )

    def notify_test_failed(
        self,
        ticket_id: str,
        error_message: str,
        branch: str
    ) -> bool:
        """
        테스트 실패 알림

        Args:
            ticket_id: JIRA 티켓 ID
            error_message: 에러 메시지
            branch: Git 브랜치명

        Returns:
            성공 여부
        """
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"❌ 테스트 실패: {ticket_id}"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*티켓:*\n{ticket_id}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*브랜치:*\n`{branch}`"
                    }
                ]
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*에러:*\n```{error_message[:500]}```"
                }
            },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": f"실패 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                    }
                ]
            }
        ]

        return self.send_message(
            text=f"테스트 실패: {ticket_id} - 재작업 필요",
            blocks=blocks
        )

    def notify_pr_created(
        self,
        ticket_id: str,
        pr_url: str,
        branch: str
    ) -> bool:
        """
        PR 생성 완료 알림

        Args:
            ticket_id: JIRA 티켓 ID
            pr_url: Pull Request URL
            branch: Git 브랜치명

        Returns:
            성공 여부
        """
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"✅ PR 생성 완료: {ticket_id}"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*티켓:*\n{ticket_id}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*브랜치:*\n`{branch}`"
                    }
                ]
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Pull Request:*\n<{pr_url}|PR 보기>"
                }
            },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": f"완료 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                    }
                ]
            }
        ]

        return self.send_message(
            text=f"PR 생성 완료: {ticket_id}",
            blocks=blocks
        )

    def notify_workflow_completed(
        self,
        ticket_id: str,
        branch: str,
        pr_url: Optional[str] = None,
        duration: Optional[str] = None
    ) -> bool:
        """
        워크플로우 완료 알림

        Args:
            ticket_id: JIRA 티켓 ID
            branch: Git 브랜치명
            pr_url: Pull Request URL (옵션)
            duration: 소요 시간 (옵션)

        Returns:
            성공 여부
        """
        fields = [
            {
                "type": "mrkdwn",
                "text": f"*티켓:*\n{ticket_id}"
            },
            {
                "type": "mrkdwn",
                "text": f"*브랜치:*\n`{branch}`"
            }
        ]

        if duration:
            fields.append({
                "type": "mrkdwn",
                "text": f"*소요 시간:*\n{duration}"
            })

        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"🎉 워크플로우 완료: {ticket_id}"
                }
            },
            {
                "type": "section",
                "fields": fields
            }
        ]

        if pr_url:
            blocks.append({
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Pull Request:*\n<{pr_url}|PR 보기>"
                }
            })

        blocks.append({
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": f"완료 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                }
            ]
        })

        return self.send_message(
            text=f"워크플로우 완료: {ticket_id}",
            blocks=blocks
        )

    def notify_error(
        self,
        ticket_id: str,
        error_message: str,
        step: Optional[str] = None
    ) -> bool:
        """
        에러 알림

        Args:
            ticket_id: JIRA 티켓 ID
            error_message: 에러 메시지
            step: 실패한 단계 (옵션)

        Returns:
            성공 여부
        """
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"🚨 워크플로우 에러: {ticket_id}"
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*티켓:*\n{ticket_id}"
                    }
                ]
            }
        ]

        if step:
            blocks[1]["fields"].append({
                "type": "mrkdwn",
                "text": f"*실패 단계:*\n{step}"
            })

        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*에러:*\n```{error_message[:500]}```"
            }
        })

        blocks.append({
            "type": "context",
            "elements": [
                {
                    "type": "mrkdwn",
                    "text": f"에러 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                }
            ]
        })

        return self.send_message(
            text=f"워크플로우 에러: {ticket_id}",
            blocks=blocks
        )


def main():
    """테스트용 메인 함수"""
    notifier = SlackNotifier()

    # 테스트 메시지 전송
    notifier.send_message("🤖 Slack Notifier 테스트 메시지입니다!")


if __name__ == "__main__":
    main()
