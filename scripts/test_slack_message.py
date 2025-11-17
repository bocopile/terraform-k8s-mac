#!/usr/bin/env python3
"""
Slack 메시지 전송 테스트 스크립트
"""

import sys
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

def test_send_message(token, channel_id):
    """Slack 채널로 테스트 메시지 전송"""
    try:
        print(f"🔍 Slack 메시지 전송 테스트 중...")
        print(f"   Token: {token[:15]}...")
        print(f"   Channel ID: {channel_id}")

        client = WebClient(token=token)

        # 간단한 텍스트 메시지 전송
        response = client.chat_postMessage(
            channel=channel_id,
            text="🤖 Slack Bot Token 연결 테스트 메시지입니다!",
            username="Claude Code Bot"
        )

        print(f"\n✅ 메시지 전송 성공!")
        print(f"   채널: {response['channel']}")
        print(f"   타임스탬프: {response['ts']}")
        print(f"   메시지: {response['message']['text']}")

        # Block Kit을 사용한 메시지 전송
        response2 = client.chat_postMessage(
            channel=channel_id,
            text="Slack 연결 테스트",
            blocks=[
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "✅ Slack Bot Token 연결 성공!"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {
                            "type": "mrkdwn",
                            "text": f"*팀:* 개인 스페이스"
                        },
                        {
                            "type": "mrkdwn",
                            "text": f"*봇:* subagentai"
                        }
                    ]
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": "이제 Slack 알림을 받을 수 있습니다! 🎉"
                    }
                }
            ]
        )

        print(f"\n✅ Block Kit 메시지 전송 성공!")
        print(f"   채널: {response2['channel']}")

        return True

    except SlackApiError as e:
        print(f"\n❌ 메시지 전송 실패!")
        print(f"   에러: {e.response['error']}")

        if e.response['error'] == 'channel_not_found':
            print("   채널을 찾을 수 없습니다. 채널 ID를 확인해주세요.")
        elif e.response['error'] == 'not_in_channel':
            print("   봇이 해당 채널에 추가되지 않았습니다.")
            print("   Slack에서 채널로 가서 봇을 초대해주세요: /invite @subagentai")
        elif e.response['error'] == 'missing_scope':
            print("   봇에 chat:write 권한이 없습니다.")
            print("   https://api.slack.com/apps 에서 권한을 추가해주세요.")

        return False

    except Exception as e:
        print(f"\n❌ 예상치 못한 오류 발생: {e}")
        return False


def main():
    """메인 함수"""
    if len(sys.argv) < 3:
        print("사용법: python test_slack_message.py <TOKEN> <CHANNEL_ID>")
        sys.exit(1)

    token = sys.argv[1]
    channel_id = sys.argv[2]

    print("=" * 60)
    print("Slack 메시지 전송 테스트")
    print("=" * 60)

    test_send_message(token, channel_id)

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()
