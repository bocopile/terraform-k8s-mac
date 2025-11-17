#!/usr/bin/env python3
"""
Slack 토큰 연결 테스트 스크립트
"""

import sys

# Bot Token으로 연결 테스트
def test_bot_token(token):
    """Slack Bot Token으로 연결 테스트"""
    try:
        from slack_sdk import WebClient
        from slack_sdk.errors import SlackApiError

        print(f"🔍 Slack Bot Token 연결 테스트 중...")
        print(f"   Token: {token[:10]}...")

        client = WebClient(token=token)

        # auth.test API 호출로 토큰 유효성 검증
        response = client.auth_test()

        print(f"\n✅ Slack 연결 성공!")
        print(f"   팀: {response['team']}")
        print(f"   사용자: {response['user']}")
        print(f"   사용자 ID: {response['user_id']}")
        print(f"   팀 ID: {response['team_id']}")
        print(f"   봇 ID: {response.get('bot_id', 'N/A')}")

        # 채널 목록 가져오기
        try:
            channels_response = client.conversations_list(types="public_channel,private_channel")
            channels = channels_response['channels']

            print(f"\n📋 사용 가능한 채널 ({len(channels)}개):")
            for channel in channels[:10]:  # 처음 10개만 표시
                print(f"   - #{channel['name']} (ID: {channel['id']})")

            if len(channels) > 10:
                print(f"   ... 외 {len(channels) - 10}개")

        except SlackApiError as e:
            print(f"\n⚠️  채널 목록 조회 실패: {e.response['error']}")

        return True

    except ImportError:
        print("❌ slack_sdk 라이브러리가 설치되지 않았습니다.")
        print("   다음 명령어로 설치하세요: pip install slack_sdk")
        return False

    except SlackApiError as e:
        print(f"\n❌ Slack 연결 실패!")
        print(f"   에러: {e.response['error']}")

        if e.response['error'] == 'invalid_auth':
            print("   토큰이 유효하지 않거나 만료되었습니다.")
        elif e.response['error'] == 'not_authed':
            print("   인증되지 않은 토큰입니다.")

        return False

    except Exception as e:
        print(f"\n❌ 예상치 못한 오류 발생: {e}")
        return False


def test_webhook_url(webhook_url):
    """Slack Webhook URL로 연결 테스트"""
    try:
        import requests

        print(f"🔍 Slack Webhook URL 연결 테스트 중...")

        payload = {
            "text": "🤖 Slack 연결 테스트 메시지입니다!",
            "username": "Claude Code Bot",
            "icon_emoji": ":robot_face:"
        }

        response = requests.post(
            webhook_url,
            json=payload,
            timeout=10
        )

        if response.status_code == 200:
            print(f"\n✅ Slack Webhook 연결 성공!")
            print(f"   메시지가 전송되었습니다.")
            return True
        else:
            print(f"\n❌ Slack Webhook 연결 실패!")
            print(f"   HTTP Status: {response.status_code}")
            print(f"   Response: {response.text}")
            return False

    except Exception as e:
        print(f"\n❌ Webhook 테스트 실패: {e}")
        return False


def main():
    """메인 함수"""
    if len(sys.argv) < 2:
        print("사용법: python test_slack_connection.py <TOKEN_OR_WEBHOOK_URL>")
        sys.exit(1)

    token_or_url = sys.argv[1]

    print("=" * 60)
    print("Slack 연결 테스트")
    print("=" * 60)

    # URL인지 토큰인지 구분
    if token_or_url.startswith("https://hooks.slack.com/"):
        test_webhook_url(token_or_url)
    else:
        test_bot_token(token_or_url)

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()