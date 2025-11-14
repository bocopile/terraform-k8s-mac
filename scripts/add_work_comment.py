#!/usr/bin/env python3
"""
Add work summary comments to JIRA issues
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from jira_client import JiraClient

def main():
    client = JiraClient()

    # TERRAFORM-60: MinIO LoadBalancer 수정
    terraform_60_comment = """## 작업 완료 ✅

### 발견된 문제
1. **LoadBalancer IP 할당 실패**
   - 기존: `metallb.universe.tf/loadBalancerIPs: 192.168.100.240` (IP Pool 범위 외)
   - MetalLB IP Pool: `192.168.65.200-192.168.65.250`
   - 결과: `<pending>` 상태로 IP 할당 안됨

2. **설정 파일 오류**
   - `DeploymentUpdate` → `deploymentUpdate` (대소문자 오류)
   - ServiceMonitor에 Prometheus 라벨 누락

### 해결 방법
- MetalLB annotation을 IP Pool 자동 할당 방식으로 변경
  - `metallb.universe.tf/address-pool: default-address-pool`
- ServiceMonitor에 Prometheus 라벨 추가
  - `release: kube-prometheus-stack`
- deploymentUpdate 필드명 수정

### 최종 상태
- ✅ MinIO Service: `192.168.65.205:9000`
- ✅ MinIO Console: `192.168.65.204:9001`
- ✅ Pod 상태: Running (1/1)
- ✅ 웹 콘솔 접근 가능

### 수정된 파일
- `addons/values/storage/minio-values.yaml`

### Git 커밋
- feature/TERRAFORM-60: 9b50b8e
- grafana-stage merge: 1c0a9ee
"""

    # TERRAFORM-63: Sloth git-sync 설정
    terraform_63_comment = """## 작업 완료 ✅

### 발견된 문제
1. **git-sync sidecar 미적용**
   - Sloth v0.11.0: commonPlugins 설정 미지원
   - SLI plugins: 0개 (내장 플러그인만 사용)
   - git-sync 컨테이너 없음

2. **설정 구조 호환성**
   - v0.11.0 설정이 최신 Helm chart 스키마와 불일치
   - 불필요한 legacy 설정 포함

### 해결 방법
- Sloth 버전 업그레이드: v0.11.0 → v0.15.0
- commonPlugins 설정 추가
  ```yaml
  commonPlugins:
    enabled: true
    image:
      repository: registry.k8s.io/git-sync/git-sync
      tag: v4.5.0
    gitRepo:
      url: https://github.com/slok/sloth-common-sli-plugins
      branch: main
  ```
- readOnlyRootFilesystem: false 설정 (git-sync 호환성)
- extraVolumes 추가 (git-sync temp 파일용)

### 최종 상태
- ✅ Sloth v0.15.0 실행 중
- ✅ Containers: `sloth`, `git-sync-plugins` (2/2 Running)
- ✅ SLI plugins: 0 → 21개 로드 성공
- ✅ Hot-reload 정상 작동

### 수정된 파일
- `addons/values/monitoring/sloth-values.yaml`

### Git 커밋
- feature/TERRAFORM-63: 47c9bfe
- grafana-stage merge: f93e421
"""

    print("TERRAFORM-60에 댓글 추가 중...")
    result1 = client.add_comment("TERRAFORM-60", terraform_60_comment)

    print("\nTERRAFORM-63에 댓글 추가 중...")
    result2 = client.add_comment("TERRAFORM-63", terraform_63_comment)

    if result1 and result2:
        print("\n✅ 모든 댓글이 성공적으로 추가되었습니다.")
        return 0
    else:
        print("\n❌ 일부 댓글 추가에 실패했습니다.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
