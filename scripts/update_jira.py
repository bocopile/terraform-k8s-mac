#!/usr/bin/env python3
"""
JIRA Ticket Update Script
Updates JIRA tickets with test results and error details
"""

import os
import sys
import json
import requests
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)

JIRA_URL = os.getenv('JIRA_URL')
JIRA_EMAIL = os.getenv('JIRA_EMAIL')
JIRA_API_TOKEN = os.getenv('JIRA_API_TOKEN')
JIRA_PROJECT_KEY = os.getenv('JIRA_PROJECT_KEY')

if not all([JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN]):
    print("Error: JIRA credentials not found in .env file")
    sys.exit(1)

# Authentication
auth = (JIRA_EMAIL, JIRA_API_TOKEN)
headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

# Test results for each ticket
TICKET_UPDATES = {
    'TERRAFORM-57': {
        'status': 'success',
        'component': 'Fluent Bit',
        'summary': '✅ 테스트 성공 - Fluent Bit 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
- Storage path 권한 오류: `/var/fluent-bit/state/flb-storage/` 경로 초기화 실패
- readOnlyRootFilesystem: true 설정으로 인한 쓰기 권한 없음

### 해결 방법
- `fluent-bit-values.yaml`에 emptyDir volume 추가
- Storage path를 `/var/fluent-bit/state`로 마운트

### 최종 상태
- 모든 노드(3개)에서 Fluent Bit pods 정상 실행 중
- Loki 및 OpenTelemetry Collector로 로그 전송 확인

### 수정된 파일
- `addons/values/logging/fluent-bit-values.yaml`
'''
    },
    'TERRAFORM-58': {
        'status': 'success',
        'component': 'Grafana Tempo',
        'summary': '✅ 테스트 성공 - Tempo 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
- Values 파일 구조가 현재 Tempo Helm chart 스키마와 호환되지 않음
- Deprecated fields 사용: `tempo.ingester.replicas`, `tempo.queryFrontend.enabled` 등
- 잘못된 duration 형식: `retention: map[enabled:true max_duration:168h]`

### 해결 방법
- Values 파일을 완전히 재작성하여 chart 스키마에 맞춤
- 단순화된 구조로 변경
- Retention 형식을 단순 문자열로 수정: `retention: 168h`

### 최종 상태
- Tempo pod 정상 실행 중 (1/1 Running)
- 10Gi PVC (local-path) 정상 마운트
- Metrics generator 활성화

### 수정된 파일
- `addons/values/tracing/tempo-values.yaml` (전체 재작성)
'''
    },
    'TERRAFORM-63': {
        'status': 'success',
        'component': 'Sloth',
        'summary': '✅ 테스트 성공 - Sloth 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
1. **Helm repo URL 오류**
   - 기존: `https://sloth-dev.github.io/sloth` (404 Not Found)
   - 수정: `https://slok.github.io/sloth` ✅

2. **이미지 버전 호환성 문제**
   - v0.11.0: `--plugins-path` flag 미지원
   - v0.15.0: flag 지원

3. **git-sync container 크래시**
   - read-only filesystem으로 인해 `/tmp`에 gitconfig 생성 불가

### 해결 방법
1. 이미지 버전을 v0.11.0 → v0.15.0으로 업그레이드
2. 이미지 경로 수정: `registry: ghcr.io`, `repository: slok/sloth`
3. `readOnlyRootFilesystem: false` 설정 (git-sync 호환성)

### 최종 상태
- Pod status: 2/2 Running ✅
- Sloth controller 정상 동작
- git-sync-plugins sidecar 정상 동작
- SLI plugins 자동 다운로드 및 동기화

### 수정된 파일
- `addons/install.sh` (Sloth repo URL 수정)
- `addons/values/monitoring/sloth-values.yaml` (완전 재작성)
'''
    },
    'TERRAFORM-59': {
        'status': 'success',
        'component': 'cert-manager',
        'summary': '✅ 테스트 성공 - cert-manager 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
- 초기 테스트에서 ServiceMonitor CRD not found 오류
- cert-manager가 kube-prometheus-stack보다 먼저 설치되려 할 때 발생

### 해결 방법
- kube-prometheus-stack이 이미 설치되어 있는 상태에서 cert-manager 설치
- ServiceMonitor CRD가 존재하는 것을 확인 후 진행

### 최종 상태
- cert-manager 정상 설치 완료
- 4개 pods 모두 Running 상태 ✅
  - cert-manager controller
  - cert-manager webhook
  - cert-manager cainjector
  - cert-manager startupapicheck (Completed)

### 참고사항
- ClusterIssuers는 istio-ingress namespace 생성 후 적용 가능
- 현재는 cert-manager 자체 설치만 완료된 상태

### 수정된 파일
- 없음 (values 파일 정상, 설치 순서만 조정)
'''
    },
    'TERRAFORM-60': {
        'status': 'success',
        'component': 'MinIO',
        'summary': '✅ 테스트 성공 - MinIO 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
1. **Template error with policies section**
   - MinIO chart의 policy helper template에서 타입 불일치 오류
   - Values 파일의 복잡한 IAM-style policies 설정이 chart와 호환되지 않음

2. **필드명 오류**
   - `DeploymentUpdate` → `deploymentUpdate` (대소문자 구분)

### 해결 방법
1. `policies:` 섹션 전체 제거 (lines 78-96)
2. `DeploymentUpdate` → `deploymentUpdate` 수정
3. MetalLB annotations 단순화

### 최종 상태
- MinIO pod 정상 Running 상태 ✅
- LoadBalancer 서비스 생성 완료
- S3-compatible storage 정상 동작
- Loki 및 Tempo용 버킷 준비 완료

### 수정된 파일
- `addons/values/storage/minio-values.yaml` (policies 섹션 제거, 필드명 수정)
'''
    },
    'TERRAFORM-61': {
        'status': 'success',
        'component': 'KEDA',
        'summary': '✅ 테스트 성공 - KEDA 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
1. **Deployment strategy 타입 불일치**
   - `upgradeStrategy`가 문자열로 설정되어 있음
   - Kubernetes는 object 타입 기대

2. **SecurityContext 구조 오류**
   - `fsGroup`이 container securityContext에 있음
   - `fsGroup`은 pod securityContext에 있어야 함

### 해결 방법
1. `securityContext`를 `podSecurityContext`와 `securityContext`로 분리
2. `fsGroup`을 `podSecurityContext`로 이동
3. `upgradeStrategy`를 문자열에서 object로 변경:
   ```yaml
   upgradeStrategy:
     operator:
       type: RollingUpdate
       rollingUpdate:
         maxUnavailable: 1
         maxSurge: 1
   ```

### 최종 상태
- KEDA operator 정상 Running ✅
- KEDA metrics-apiserver 정상 Running ✅
- KEDA admission-webhooks 정상 Running ✅
- Event-driven autoscaling 준비 완료

### 수정된 파일
- `addons/values/autoscaling/keda-values.yaml` (securityContext 분리, upgradeStrategy 수정)
'''
    },
    'TERRAFORM-62': {
        'status': 'success',
        'component': 'Kyverno',
        'summary': '✅ 테스트 성공 - Kyverno 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
- Webhook 설정이 배열 형식으로 되어 있음
- Chart template에서는 object 타입 기대
- `config.webhooks`가 `- namespaceSelector:` 형식으로 설정됨

### 해결 방법
- Webhook 설정을 배열에서 object로 변경:
  ```yaml
  # Before (배열)
  webhooks:
    - namespaceSelector:

  # After (object)
  webhooks:
    namespaceSelector:
  ```

### 최종 상태
- Kyverno admission controller 정상 Running ✅
- Kyverno background controller 정상 Running ✅
- Kyverno cleanup controller 정상 Running ✅
- Kyverno reports controller 정상 Running ✅
- Policy engine 준비 완료

### 수정된 파일
- `addons/values/security/kyverno-values.yaml` (webhooks 구조 변경)
'''
    },
    'TERRAFORM-64': {
        'status': 'success',
        'component': 'Velero',
        'summary': '✅ 테스트 성공 - Velero 정상 동작',
        'details': '''## 테스트 결과: 성공 ✅

### 발견된 문제
1. **YAML 파싱 오류**
   - Line 200에 markdown 코드 블록 종료 기호 존재
   - YAML 문법 오류 발생

2. **kubectl 이미지 태그 오류**
   - `tag: 1.30` → YAML 파서가 숫자 1.3으로 인식
   - 이미지 `docker.io/bitnami/kubectl:1.3` 존재하지 않음

3. **Deprecated 필드 사용**
   - `configuration.provider: aws` 필드가 deprecated
   - 각 location별로 provider 설정 필요

4. **호환되지 않는 flags**
   - `--repo-maintenance-job-configmap` flag가 현재 chart 버전에서 미지원

5. **MinIO namespace 오류**
   - Values 파일에서 `minio.storage.svc.cluster.local` 사용
   - 실제 MinIO는 `minio.minio.svc.cluster.local`에 위치

6. **MinIO 버킷 누락**
   - `velero-backups` 버킷이 생성되지 않음
   - BackupStorageLocation Unavailable 상태

### 해결 방법
1. Values 파일 완전 재작성 (197줄 → 96줄)
2. Chart 기본값 활용하여 단순화
3. 호환되지 않는 설정 모두 제거
4. MinIO URL을 `minio.minio.svc.cluster.local`로 수정
5. MinIO에 `velero-backups` 버킷 생성
6. 백업 테스트 수행하여 정상 동작 확인

### 최종 상태
- Velero pod 정상 Running (1/1) ✅
- BackupStorageLocation Available ✅
- MinIO S3 backend 연결 성공 ✅
- 테스트 백업 성공 (6/6 items backed up) ✅
- 백업 데이터 MinIO에 저장 확인 ✅

### 수정된 파일
- `addons/values/backup/velero-values.yaml` (완전 재작성 및 MinIO URL 수정)
'''
    }
}


def get_issue_transitions(issue_key):
    """Get available transitions for an issue"""
    url = f"{JIRA_URL}/rest/api/3/issue/{issue_key}/transitions"
    response = requests.get(url, auth=auth, headers=headers)

    if response.status_code == 200:
        return response.json()['transitions']
    else:
        print(f"Error getting transitions for {issue_key}: {response.status_code}")
        print(response.text)
        return []


def add_comment(issue_key, comment_text):
    """Add a comment to a JIRA issue"""
    url = f"{JIRA_URL}/rest/api/3/issue/{issue_key}/comment"

    data = {
        "body": {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [
                        {
                            "type": "text",
                            "text": comment_text
                        }
                    ]
                }
            ]
        }
    }

    response = requests.post(url, auth=auth, headers=headers, json=data)

    if response.status_code in [200, 201]:
        print(f"✅ Comment added to {issue_key}")
        return True
    else:
        print(f"❌ Failed to add comment to {issue_key}: {response.status_code}")
        print(response.text)
        return False


def transition_issue(issue_key, transition_name):
    """Transition an issue to a new status"""
    # Get available transitions
    transitions = get_issue_transitions(issue_key)

    # Find the transition ID by name
    transition_id = None
    for t in transitions:
        if t['name'].lower() == transition_name.lower():
            transition_id = t['id']
            break

    if not transition_id:
        print(f"⚠️  Transition '{transition_name}' not found for {issue_key}")
        print(f"Available transitions: {[t['name'] for t in transitions]}")
        return False

    # Perform transition
    url = f"{JIRA_URL}/rest/api/3/issue/{issue_key}/transitions"
    data = {
        "transition": {
            "id": transition_id
        }
    }

    response = requests.post(url, auth=auth, headers=headers, json=data)

    if response.status_code == 204:
        print(f"✅ {issue_key} transitioned to '{transition_name}'")
        return True
    else:
        print(f"❌ Failed to transition {issue_key}: {response.status_code}")
        print(response.text)
        return False


def update_ticket(issue_key, update_info):
    """Update a JIRA ticket with test results"""
    print(f"\n{'='*60}")
    print(f"Updating {issue_key}: {update_info['component']}")
    print(f"{'='*60}")

    # Add comment with test results
    comment_success = add_comment(issue_key, update_info['details'])

    # Determine target status based on test result
    status = update_info['status']

    if status == 'success':
        # Try to transition to Done (완료)
        target_status = '완료'
    elif status == 'partial':
        # Keep in progress or move to 'In Progress' (진행 중)
        target_status = '진행 중'
    else:  # failed
        # Move to 'To Do' for rework (해야 할 일)
        target_status = '해야 할 일'

    # Get current status first
    response = requests.get(
        f"{JIRA_URL}/rest/api/3/issue/{issue_key}?fields=status",
        auth=auth,
        headers=headers
    )

    if response.status_code == 200:
        current_status = response.json()['fields']['status']['name']
        print(f"Current status: {current_status}")

        if current_status != target_status:
            transition_success = transition_issue(issue_key, target_status)
        else:
            print(f"Already in '{target_status}' status")
            transition_success = True
    else:
        print(f"Failed to get current status: {response.status_code}")
        transition_success = False

    return comment_success and transition_success


def main():
    print("="*60)
    print("JIRA Ticket Update Script")
    print("="*60)
    print(f"JIRA URL: {JIRA_URL}")
    print(f"Project: {JIRA_PROJECT_KEY}")
    print(f"Tickets to update: {len(TICKET_UPDATES)}")
    print("="*60)

    results = {}

    for issue_key, update_info in TICKET_UPDATES.items():
        success = update_ticket(issue_key, update_info)
        results[issue_key] = success

    print(f"\n{'='*60}")
    print("Summary")
    print(f"{'='*60}")

    success_count = sum(1 for v in results.values() if v)
    total_count = len(results)

    for issue_key, success in results.items():
        status_icon = "✅" if success else "❌"
        print(f"{status_icon} {issue_key}")

    print(f"\nTotal: {success_count}/{total_count} tickets updated successfully")


if __name__ == '__main__':
    main()
