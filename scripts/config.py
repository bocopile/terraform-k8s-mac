"""
Claude Code SubAgent - Configuration Manager

.env 파일을 로드하고 환경변수를 관리하는 Config 클래스
"""

from dotenv import load_dotenv
import os
from pathlib import Path
from typing import Optional


class Config:
    """환경변수 설정을 관리하는 클래스"""

    def __init__(self, env_file: Optional[str] = None):
        """
        Config 초기화

        Args:
            env_file: .env 파일 경로 (기본값: 프로젝트 루트의 .env)
        """
        # .env 파일 로드
        if env_file:
            load_dotenv(env_file)
        else:
            # 프로젝트 루트의 .env 파일 자동 로드
            project_root = Path(__file__).parent.parent
            env_path = project_root / '.env'
            load_dotenv(env_path)

        # ===================================
        # JIRA 설정
        # ===================================
        self.jira_url = os.getenv('JIRA_URL')
        self.jira_email = os.getenv('JIRA_EMAIL')
        self.jira_api_token = os.getenv('JIRA_API_TOKEN')
        self.jira_project_key = os.getenv('JIRA_PROJECT_KEY', 'FINOPS')

        # ===================================
        # Slack 설정
        # ===================================
        self.slack_webhook_url = os.getenv('SLACK_WEBHOOK_URL')
        self.slack_channel = os.getenv('SLACK_CHANNEL', '#finops-dev')
        self.slack_username = os.getenv('SLACK_USERNAME', 'Claude Code Bot')

        # ===================================
        # Git 설정
        # ===================================
        self.git_author_name = os.getenv('GIT_AUTHOR_NAME', 'Claude Code')
        self.git_author_email = os.getenv('GIT_AUTHOR_EMAIL', 'claude@company.com')
        self.git_main_branch = os.getenv('GIT_MAIN_BRANCH', 'grafana')
        self.git_stage_branch = os.getenv('GIT_STAGE_BRANCH', 'grafana-stage')

        # ===================================
        # Redis 설정
        # ===================================
        self.redis_host = os.getenv('REDIS_HOST', 'localhost')
        self.redis_port = int(os.getenv('REDIS_PORT', '6379'))
        self.redis_password = os.getenv('REDIS_PASSWORD', None)
        self.redis_db = int(os.getenv('REDIS_DB', '0'))

        # ===================================
        # 워크플로우 설정
        # ===================================
        self.workflow_mode = os.getenv('WORKFLOW_MODE', 'auto')
        self.checkpoint_dir = os.getenv('CHECKPOINT_DIR', './checkpoints')
        self.log_level = os.getenv('LOG_LEVEL', 'INFO')

        # ===================================
        # 품질 게이트 설정
        # ===================================
        self.min_code_coverage = int(os.getenv('MIN_CODE_COVERAGE', '80'))
        self.sonarqube_url = os.getenv('SONARQUBE_URL')
        self.sonarqube_token = os.getenv('SONARQUBE_TOKEN')

        # ===================================
        # SubAgent 설정
        # ===================================
        self.backend_agent_enabled = os.getenv('BACKEND_AGENT_ENABLED', 'true').lower() == 'true'
        self.qa_agent_enabled = os.getenv('QA_AGENT_ENABLED', 'true').lower() == 'true'
        self.review_agent_enabled = os.getenv('REVIEW_AGENT_ENABLED', 'true').lower() == 'true'
        self.docs_agent_enabled = os.getenv('DOCS_AGENT_ENABLED', 'true').lower() == 'true'

        # ===================================
        # 테스트 설정
        # ===================================
        self.test_timeout = int(os.getenv('TEST_TIMEOUT', '300'))
        self.test_retry_count = int(os.getenv('TEST_RETRY_COUNT', '3'))

    def validate(self) -> None:
        """
        필수 환경변수 검증

        Raises:
            EnvironmentError: 필수 환경변수가 누락된 경우
        """
        required_vars = [
            ('JIRA_URL', self.jira_url),
            ('JIRA_EMAIL', self.jira_email),
            ('JIRA_API_TOKEN', self.jira_api_token),
            ('SLACK_WEBHOOK_URL', self.slack_webhook_url),
            ('GIT_AUTHOR_NAME', self.git_author_name),
            ('GIT_AUTHOR_EMAIL', self.git_author_email),
        ]

        missing_vars = [name for name, value in required_vars if not value]

        if missing_vars:
            raise EnvironmentError(
                f"Missing required environment variables: {', '.join(missing_vars)}\n"
                f"Please check your .env file and make sure all required variables are set.\n"
                f"You can copy .env.example to .env and fill in the values."
            )

    def print_config(self) -> None:
        """설정 정보 출력 (민감 정보 제외)"""
        print("=" * 50)
        print("Claude Code SubAgent Configuration")
        print("=" * 50)
        print(f"JIRA URL: {self.jira_url}")
        print(f"JIRA Project: {self.jira_project_key}")
        print(f"Slack Channel: {self.slack_channel}")
        print(f"Git Main Branch: {self.git_main_branch}")
        print(f"Git Stage Branch: {self.git_stage_branch}")
        print(f"Redis Host: {self.redis_host}:{self.redis_port}")
        print(f"Workflow Mode: {self.workflow_mode}")
        print(f"Checkpoint Dir: {self.checkpoint_dir}")
        print(f"Log Level: {self.log_level}")
        print(f"Min Code Coverage: {self.min_code_coverage}%")
        print(f"Backend Agent: {'✅ Enabled' if self.backend_agent_enabled else '❌ Disabled'}")
        print(f"QA Agent: {'✅ Enabled' if self.qa_agent_enabled else '❌ Disabled'}")
        print(f"Review Agent: {'✅ Enabled' if self.review_agent_enabled else '❌ Disabled'}")
        print(f"Docs Agent: {'✅ Enabled' if self.docs_agent_enabled else '❌ Disabled'}")
        print("=" * 50)

    @property
    def redis_config(self) -> dict:
        """Redis 연결 설정 딕셔너리 반환"""
        config = {
            'host': self.redis_host,
            'port': self.redis_port,
            'db': self.redis_db,
        }
        if self.redis_password:
            config['password'] = self.redis_password
        return config


# 싱글톤 패턴으로 전역 config 객체 생성
_config_instance = None


def get_config(reload: bool = False) -> Config:
    """
    전역 Config 인스턴스 반환 (싱글톤)

    Args:
        reload: True일 경우 config를 다시 로드

    Returns:
        Config 인스턴스
    """
    global _config_instance

    if _config_instance is None or reload:
        _config_instance = Config()
        _config_instance.validate()

    return _config_instance


# 사용 예시
if __name__ == '__main__':
    try:
        config = get_config()
        config.print_config()
    except EnvironmentError as e:
        print(f"❌ Configuration Error: {e}")
        exit(1)
