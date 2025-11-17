#!/usr/bin/env python3
"""
JIRA Multi-cluster 프로젝트 백로그 및 스프린트 생성 스크립트
"""

import sys
import os
from datetime import datetime, timedelta
from atlassian import Jira

# .env 파일에서 설정 로드
from dotenv import load_dotenv
load_dotenv()

JIRA_URL = os.getenv('JIRA_URL')
JIRA_EMAIL = os.getenv('JIRA_EMAIL')
JIRA_API_TOKEN = os.getenv('JIRA_API_TOKEN')
JIRA_PROJECT_KEY = os.getenv('JIRA_PROJECT_KEY', 'TERRAFORM')


class JiraMultiClusterSetup:
    """JIRA Multi-cluster 백로그 설정"""

    def __init__(self):
        """JIRA 클라이언트 초기화"""
        self.jira = Jira(
            url=JIRA_URL,
            username=JIRA_EMAIL,
            password=JIRA_API_TOKEN
        )
        self.project_key = JIRA_PROJECT_KEY
        self.epics = {}
        self.stories = {}

    def create_epic(self, summary, description, priority="High"):
        """Epic 생성"""
        try:
            issue_dict = {
                'project': {'key': self.project_key},
                'summary': summary,
                'description': description,
                'issuetype': {'name': 'Epic'},
                'priority': {'name': priority}
            }

            epic = self.jira.issue_create(fields=issue_dict)
            epic_key = epic['key']

            print(f"✅ Epic 생성: {epic_key} - {summary}")
            return epic_key

        except Exception as e:
            print(f"❌ Epic 생성 실패: {e}")
            return None

    def create_story(self, summary, description, epic_key=None, story_points=None, priority="Medium", labels=None):
        """Story 생성"""
        try:
            issue_dict = {
                'project': {'key': self.project_key},
                'summary': summary,
                'description': description,
                'issuetype': {'name': 'Story'},
                'priority': {'name': priority}
            }

            # Epic 링크 추가
            if epic_key:
                issue_dict['customfield_10014'] = epic_key  # Epic Link field

            # Story Points 추가
            if story_points:
                issue_dict['customfield_10016'] = story_points  # Story Points field

            # Labels 추가
            if labels:
                issue_dict['labels'] = labels

            story = self.jira.issue_create(fields=issue_dict)
            story_key = story['key']

            print(f"  ✅ Story 생성: {story_key} - {summary}")
            return story_key

        except Exception as e:
            print(f"  ❌ Story 생성 실패: {e}")
            return None

    def create_task(self, summary, description, parent_key, priority="Medium", labels=None):
        """Sub-task 생성"""
        try:
            issue_dict = {
                'project': {'key': self.project_key},
                'summary': summary,
                'description': description,
                'issuetype': {'name': 'Task'},
                'parent': {'key': parent_key},
                'priority': {'name': priority}
            }

            # Labels 추가
            if labels:
                issue_dict['labels'] = labels

            task = self.jira.issue_create(fields=issue_dict)
            task_key = task['key']

            print(f"    ✅ Task 생성: {task_key} - {summary}")
            return task_key

        except Exception as e:
            print(f"    ❌ Task 생성 실패: {e}")
            return None

    def setup_multi_cluster_backlog(self):
        """Multi-cluster 백로그 전체 설정"""
        print("\n" + "="*80)
        print("🚀 JIRA Multi-cluster 백로그 생성 시작")
        print("="*80 + "\n")

        # Phase 1: 인프라 기반 작업
        print("\n📦 Phase 1: 인프라 기반 작업")
        print("-" * 80)

        phase1_epic = self.create_epic(
            summary="[Phase 1] Multi-cluster 인프라 기반 작업",
            description="""
# Phase 1: 인프라 기반 작업

Control Cluster와 App Cluster를 위한 Terraform 코드 리팩토링 및 네트워크 구성

## 목표
- Terraform 모듈화 (단일 클러스터 → Multi-cluster)
- 네트워크 구성 (IP 대역 분리, DNS 설정)
- 클러스터 초기화 스크립트 분리

## 예상 시간
9-13시간

## 산출물
- modules/k8s-cluster/
- clusters/control/, clusters/app/
- shell/cluster-init-control.sh, shell/cluster-init-app.sh
            """,
            priority="Highest"
        )
        self.epics['phase1'] = phase1_epic

        # Phase 1 Stories
        story1_1 = self.create_story(
            summary="Terraform 코드 모듈화",
            description="""
## 작업 내용
- main.tf를 modules/k8s-cluster/로 모듈화
- Control Cluster용 구성 파일 생성 (clusters/control/)
- App Cluster용 구성 파일 생성 (clusters/app/)
- 변수 파일 분리 (variables-control.tf, variables-app.tf)
- 공통 변수 추출 (variables-common.tf)

## 산출물
```
terraform-k8s-mac/
├── modules/
│   └── k8s-cluster/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── clusters/
│   ├── control/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
```

## 예상 시간
4-6시간
            """,
            epic_key=phase1_epic,
            story_points=8,
            priority="Highest",
            labels=["infrastructure", "terraform", "sprint-1"]
        )

        story1_2 = self.create_story(
            summary="Multi-cluster 네트워크 구성",
            description="""
## 작업 내용
- MetalLB IP 범위 분리
  - Control Cluster: 192.168.64.100-110
  - App Cluster: 192.168.64.120-140
- DNS 레코드 설정 (hosts 파일)
- 클러스터 간 Service Discovery 구성

## 산출물
- addons/values/metallb/control-cluster-values.yaml
- addons/values/metallb/app-cluster-values.yaml
- docs/NETWORK_ARCHITECTURE.md

## 예상 시간
3-4시간
            """,
            epic_key=phase1_epic,
            story_points=5,
            priority="High",
            labels=["networking", "metallb", "sprint-1"]
        )

        story1_3 = self.create_story(
            summary="클러스터 초기화 스크립트 분리",
            description="""
## 작업 내용
- shell/cluster-init.sh를 control용, app용으로 분리
- shell/join-all.sh 수정 (클러스터별 처리)
- Kubeconfig 파일 관리 (control-kubeconfig, app-kubeconfig)
- Context 스위칭 스크립트 작성

## 산출물
- shell/cluster-init-control.sh
- shell/cluster-init-app.sh
- shell/switch-cluster.sh
- shell/kubeconfig-merge.sh

## 예상 시간
2-3시간
            """,
            epic_key=phase1_epic,
            story_points=3,
            priority="High",
            labels=["scripting", "kubernetes", "sprint-1"]
        )

        # Phase 2: Control Cluster 애드온
        print("\n📦 Phase 2: Control Cluster 애드온 구성")
        print("-" * 80)

        phase2_epic = self.create_epic(
            summary="[Phase 2] Control Cluster 애드온 구성",
            description="""
# Phase 2: Control Cluster 애드온 구성

Control Cluster에 중앙 집중식 관리 및 모니터링 애드온 설치

## 목표
- GitOps Hub (ArgoCD Multi-cluster)
- 중앙 모니터링 (Prometheus Federation)
- 중앙 로깅 (Loki)
- 중앙 트레이싱 (Tempo)
- 중앙 시크릿 관리 (Vault)
- Service Mesh (Istio Multi-cluster)

## 예상 시간
29-37시간
            """,
            priority="Highest"
        )
        self.epics['phase2'] = phase2_epic

        # Phase 2.1: ArgoCD
        story2_1 = self.create_story(
            summary="ArgoCD GitOps Hub 구성",
            description="""
## 작업 내용
- ArgoCD를 Control Cluster에 설치
- App Cluster를 Remote Cluster로 등록
- ApplicationSet을 통한 Multi-cluster 배포 설정
- App of Apps 패턴 적용

## 산출물
- addons/values/argocd/multi-cluster-values.yaml
- argocd-apps/app-cluster/
- docs/addons/ARGOCD_MULTI_CLUSTER.md

## 예상 시간
4-5시간
            """,
            epic_key=phase2_epic,
            story_points=8,
            priority="Highest",
            labels=["gitops", "argocd", "sprint-1"]
        )

        # Phase 2.2: Prometheus
        story2_2 = self.create_story(
            summary="Prometheus Federation 중앙 모니터링 구성",
            description="""
## 작업 내용
- Control Cluster: Prometheus 서버 (중앙 집중)
- App Cluster: Prometheus Agent (Remote Write 모드)
- Grafana 대시보드 통합 (Multi-cluster view)
- Thanos 또는 Mimir 도입 검토 (장기 저장)

## 산출물
- addons/values/monitoring/control-prometheus-values.yaml
- addons/values/monitoring/app-prometheus-agent-values.yaml
- docs/addons/PROMETHEUS_FEDERATION.md

## 예상 시간
6-8시간
            """,
            epic_key=phase2_epic,
            story_points=13,
            priority="Highest",
            labels=["monitoring", "prometheus", "sprint-1"]
        )

        # Phase 2.3: Loki
        story2_3 = self.create_story(
            summary="Loki 중앙 로깅 시스템 구성",
            description="""
## 작업 내용
- Control Cluster: Loki 서버
- App Cluster: Fluent-Bit (Control Loki로 전송)
- Grafana에서 Multi-cluster 로그 통합 검색

## 산출물
- addons/values/logging/control-loki-values.yaml
- addons/values/logging/app-fluent-bit-values.yaml

## 예상 시간
3-4시간
            """,
            epic_key=phase2_epic,
            story_points=5,
            priority="High",
            labels=["logging", "loki", "sprint-2"]
        )

        # Phase 2.4: Tempo
        story2_4 = self.create_story(
            summary="Tempo 중앙 트레이싱 시스템 구성",
            description="""
## 작업 내용
- Control Cluster: Tempo 서버
- App Cluster: OpenTelemetry Collector (Control Tempo로 전송)
- Grafana에서 Trace 통합 확인

## 산출물
- addons/values/tracing/control-tempo-values.yaml
- addons/values/tracing/app-otel-collector-values.yaml

## 예상 시간
3-4시간
            """,
            epic_key=phase2_epic,
            story_points=5,
            priority="High",
            labels=["tracing", "tempo", "sprint-2"]
        )

        # Phase 2.5: Vault
        story2_5 = self.create_story(
            summary="Vault 중앙 시크릿 관리 시스템 구성",
            description="""
## 작업 내용
- Control Cluster에 Vault 설치
- App Cluster에서 Vault Agent Injector 설정
- External Secrets Operator를 통한 시크릿 동기화

## 산출물
- addons/values/vault/control-vault-values.yaml
- addons/values/vault/app-external-secrets-values.yaml
- docs/addons/VAULT_MULTI_CLUSTER.md

## 예상 시간
5-6시간
            """,
            epic_key=phase2_epic,
            story_points=8,
            priority="High",
            labels=["security", "vault", "sprint-2"]
        )

        # Phase 2.6: Istio
        story2_6 = self.create_story(
            summary="Istio Multi-cluster Service Mesh 구성",
            description="""
## 작업 내용
- Istio Multi-primary 또는 Primary-Remote 모델 구성
- Cross-cluster Service Discovery 설정
- East-West Gateway 구성
- mTLS 인증서 공유

## 산출물
- addons/values/istio/control-istiod-values.yaml
- addons/values/istio/app-istio-remote-values.yaml
- docs/addons/ISTIO_MULTI_CLUSTER.md

## 예상 시간
8-10시간
            """,
            epic_key=phase2_epic,
            story_points=13,
            priority="Highest",
            labels=["service-mesh", "istio", "sprint-2"]
        )

        # Phase 3: App Cluster 애드온
        print("\n📦 Phase 3: App Cluster 애드온 구성")
        print("-" * 80)

        phase3_epic = self.create_epic(
            summary="[Phase 3] App Cluster 애드온 구성",
            description="""
# Phase 3: App Cluster 애드온 구성

App Cluster에 워크로드 실행을 위한 애드온 설치

## 목표
- KEDA (로컬 오토스케일링)
- Kyverno (로컬 정책 적용)
- Observability Agent 설정

## 예상 시간
7-9시간
            """,
            priority="High"
        )
        self.epics['phase3'] = phase3_epic

        story3_1 = self.create_story(
            summary="App Cluster Workload 애드온 설치",
            description="""
## 작업 내용
- KEDA (로컬 오토스케일링)
- Kyverno (로컬 정책 적용)
- MinIO (App Cluster 전용 스토리지 - 선택사항)
- Velero (App Cluster 백업)

## 산출물
- addons/values/autoscaling/app-keda-values.yaml
- addons/values/security/app-kyverno-values.yaml

## 예상 시간
4-5시간
            """,
            epic_key=phase3_epic,
            story_points=8,
            priority="High",
            labels=["app-cluster", "autoscaling", "sprint-2"]
        )

        story3_2 = self.create_story(
            summary="App Cluster Observability Agent 설정",
            description="""
## 작업 내용
- Prometheus Agent 설정 (Remote Write to Control)
- Fluent-Bit 설정 (Forward to Control Loki)
- OpenTelemetry Collector 설정 (Export to Control Tempo)

## 예상 시간
3-4시간
            """,
            epic_key=phase3_epic,
            story_points=5,
            priority="High",
            labels=["app-cluster", "observability", "sprint-2"]
        )

        # Phase 4: Multi-cluster 관리 도구
        print("\n📦 Phase 4: Multi-cluster 관리 도구 (Optional)")
        print("-" * 80)

        phase4_epic = self.create_epic(
            summary="[Phase 4] Multi-cluster 관리 도구 (Optional)",
            description="""
# Phase 4: Multi-cluster 관리 도구

Rancher를 통한 통합 클러스터 관리

## 목표
- Rancher 설치 및 Multi-cluster 등록
- RBAC 및 사용자 관리 설정
- Multi-cluster 대시보드 구성

## 예상 시간
4-5시간
            """,
            priority="Low"
        )
        self.epics['phase4'] = phase4_epic

        story4_1 = self.create_story(
            summary="Rancher Multi-cluster 관리 도구 설치",
            description="""
## 작업 내용
- Control Cluster에 Rancher 설치
- App Cluster를 Rancher에 등록
- RBAC 및 사용자 관리 설정
- Multi-cluster 대시보드 구성

## 산출물
- addons/values/rancher/rancher-values.yaml
- docs/addons/RANCHER_SETUP.md

## 예상 시간
4-5시간
            """,
            epic_key=phase4_epic,
            story_points=5,
            priority="Low",
            labels=["rancher", "management", "optional"]
        )

        # Phase 5: 스크립트 및 자동화
        print("\n📦 Phase 5: 스크립트 및 자동화")
        print("-" * 80)

        phase5_epic = self.create_epic(
            summary="[Phase 5] 스크립트 및 자동화",
            description="""
# Phase 5: 스크립트 및 자동화

Multi-cluster 설치 및 운영 자동화

## 목표
- 설치 스크립트 분리 (control용, app용)
- CI/CD 파이프라인 통합
- Slack 알림 통합

## 예상 시간
6-8시간
            """,
            priority="High"
        )
        self.epics['phase5'] = phase5_epic

        story5_1 = self.create_story(
            summary="Multi-cluster 설치 스크립트 작성",
            description="""
## 작업 내용
- addons/install.sh 분리 (control용, app용)
- addons/uninstall.sh 분리
- addons/verify.sh 수정 (Multi-cluster 지원)
- 전체 프로비저닝 스크립트 작성 (provision-all.sh)

## 산출물
- addons/install-control.sh
- addons/install-app.sh
- provision-all.sh

## 예상 시간
3-4시간
            """,
            epic_key=phase5_epic,
            story_points=5,
            priority="High",
            labels=["automation", "scripting", "sprint-3"]
        )

        story5_2 = self.create_story(
            summary="CI/CD 파이프라인 및 Slack 알림 통합",
            description="""
## 작업 내용
- GitHub Actions 워크플로우 작성
- ArgoCD를 통한 자동 배포 설정
- Slack 알림 통합 (Control/App Cluster 구분)

## 산출물
- .github/workflows/deploy-control.yml
- .github/workflows/deploy-app.yml

## 예상 시간
3-4시간
            """,
            epic_key=phase5_epic,
            story_points=5,
            priority="Medium",
            labels=["cicd", "github-actions", "sprint-3"]
        )

        # Phase 6: 테스트 및 문서화
        print("\n📦 Phase 6: 테스트 및 문서화")
        print("-" * 80)

        phase6_epic = self.create_epic(
            summary="[Phase 6] 테스트 및 문서화",
            description="""
# Phase 6: 테스트 및 문서화

통합 테스트 및 운영 문서 작성

## 목표
- Control/App Cluster 통합 테스트
- Cross-cluster 통신 검증
- 아키텍처 및 운영 가이드 작성

## 예상 시간
10-14시간
            """,
            priority="High"
        )
        self.epics['phase6'] = phase6_epic

        story6_1 = self.create_story(
            summary="Multi-cluster 통합 테스트",
            description="""
## 작업 내용
- Control Cluster 단독 테스트
- App Cluster 단독 테스트
- Cross-cluster 통신 테스트
- Observability 데이터 흐름 검증
- 장애 시나리오 테스트 (Chaos Engineering)

## 산출물
- docs/testing/MULTI_CLUSTER_TEST_RESULTS.md
- tests/integration/multi-cluster-tests.sh

## 예상 시간
6-8시간
            """,
            epic_key=phase6_epic,
            story_points=13,
            priority="High",
            labels=["testing", "integration", "sprint-3"]
        )

        story6_2 = self.create_story(
            summary="Multi-cluster 문서화",
            description="""
## 작업 내용
- 아키텍처 다이어그램 작성
- 설치 가이드 작성
- 운영 가이드 작성 (장애 복구, 확장 등)
- 트러블슈팅 가이드 업데이트

## 산출물
- docs/MULTI_CLUSTER_ARCHITECTURE.md
- docs/MULTI_CLUSTER_INSTALLATION.md
- docs/MULTI_CLUSTER_OPERATIONS.md
- docs/troubleshooting/MULTI_CLUSTER_TROUBLESHOOTING.md

## 예상 시간
4-6시간
            """,
            epic_key=phase6_epic,
            story_points=8,
            priority="Medium",
            labels=["documentation", "sprint-3"]
        )

        print("\n" + "="*80)
        print("✅ JIRA Multi-cluster 백로그 생성 완료!")
        print("="*80 + "\n")

        return True


def main():
    """메인 함수"""
    print("\n" + "="*80)
    print("🎯 JIRA Multi-cluster 프로젝트 백로그 설정")
    print("="*80)

    print(f"\n📋 JIRA 설정:")
    print(f"   URL: {JIRA_URL}")
    print(f"   Email: {JIRA_EMAIL}")
    print(f"   Project: {JIRA_PROJECT_KEY}")

    # 사용자 확인
    confirm = input("\n위 설정으로 JIRA 백로그를 생성하시겠습니까? (y/N): ")
    if confirm.lower() != 'y':
        print("❌ 작업이 취소되었습니다.")
        sys.exit(0)

    # JIRA 백로그 생성
    jira_setup = JiraMultiClusterSetup()
    jira_setup.setup_multi_cluster_backlog()

    print("\n✅ 모든 작업이 완료되었습니다!")
    print(f"📊 JIRA 프로젝트 확인: {JIRA_URL}/projects/{JIRA_PROJECT_KEY}")


if __name__ == "__main__":
    main()
