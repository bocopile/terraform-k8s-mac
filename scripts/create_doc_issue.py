#!/usr/bin/env python3
"""
Create JIRA issue for addon documentation
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from jira_client import JiraClient

def main():
    client = JiraClient()

    # 문서화 백로그 생성
    issue_data = client.create_issue(
        summary="[Documentation] 애드온 통합 테스트 결과 및 사용 가이드 문서화",
        description="""## 🎯 목표

grafana-stage에 배포된 5개 애드온(MinIO, KEDA, Kyverno, Sloth, Velero)의 통합 테스트 결과를 문서화하고, 각 애드온별 사용 가이드를 작성합니다.

## 📋 작업 내용

### 1. 통합 테스트 결과 문서 작성
* **파일 경로**: `docs/testing/addon-integration-test-results.md`
* 각 애드온별 테스트 결과 정리:
  * Pod 상태, CRD 설치, 핵심 기능 검증
  * LoadBalancer IP 할당 (MinIO)
  * git-sync 플러그인 로드 (Sloth)
  * MinIO S3 연동 (Velero)
* 발견된 이슈 및 해결 방법
* 테스트 환경 정보

### 2. 애드온별 사용 가이드 작성
각 애드온별 README 또는 가이드 문서 작성:

#### MinIO (TERRAFORM-60)
* **파일**: `docs/addons/minio-guide.md`
* 웹 콘솔 접근 방법 (LoadBalancer IP)
* 버킷 생성 및 관리
* Loki/Tempo S3 백엔드 연동 설정
* mc (MinIO Client) 사용법

#### KEDA (TERRAFORM-61)
* **파일**: `docs/addons/keda-guide.md`
* ScaledObject 생성 예시
* 지원되는 Scaler 목록
* Prometheus 메트릭 기반 오토스케일링 예시

#### Kyverno (TERRAFORM-62)
* **파일**: `docs/addons/kyverno-guide.md`
* ClusterPolicy 생성 예시
* 일반적인 정책 패턴 (보안, 레이블 강제 등)
* Policy 검증 및 테스트 방법

#### Sloth (TERRAFORM-63)
* **파일**: `docs/addons/sloth-guide.md`
* PrometheusServiceLevel CRD 생성 예시
* SLO 정의 방법 (가용성, 응답시간)
* git-sync 플러그인 사용법
* Grafana 대시보드 연동

#### Velero (TERRAFORM-64)
* **파일**: `docs/addons/velero-guide.md`
* Backup 생성 및 실행
* Restore 방법
* Schedule 설정
* MinIO S3 백엔드 확인

### 3. 트러블슈팅 가이드
* **파일**: `docs/troubleshooting/addons-troubleshooting.md`
* 자주 발생하는 문제 및 해결 방법
* ServiceMonitor 미생성 (MinIO)
* Node-agent DaemonSet 확인 (Velero)

## 🔧 기술 요구사항

* Markdown 형식
* 코드 블록 및 YAML 예시 포함
* 명확한 섹션 구조
* 실행 가능한 명령어 예시

## ✅ 완료 조건

* [ ] 통합 테스트 결과 문서 작성
* [ ] 5개 애드온별 사용 가이드 작성
* [ ] 트러블슈팅 가이드 작성
* [ ] 문서 검토 및 오타 수정
* [ ] grafana-stage에 merge

## 📎 참고 자료

* grafana-stage 브랜치 테스트 결과
* 각 애드온 공식 문서
* Helm values 파일들
""",
        issue_type="작업",
        labels=["documentation", "addons", "testing"]
    )

    if issue_data:
        issue_key = issue_data['key']
        print(f"\n✅ JIRA 이슈 생성 완료: {issue_key}")
        print(f"URL: {client.base_url}/browse/{issue_key}")

        # 상태를 "진행 중"으로 변경
        print(f"\n이슈 상태를 '진행 중'으로 변경합니다...")
        client.update_status(issue_key, "진행 중")

        return issue_key
    else:
        print("\n❌ JIRA 이슈 생성 실패")
        return None

if __name__ == "__main__":
    issue_key = main()
    if issue_key:
        print(f"\n다음 명령으로 feature 브랜치를 생성하세요:")
        print(f"git checkout -b feature/{issue_key}")
        sys.exit(0)
    else:
        sys.exit(1)
