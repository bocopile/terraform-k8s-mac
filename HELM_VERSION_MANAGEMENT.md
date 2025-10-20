# Helm Chart 버전 관리 가이드

## 현재 사용 중인 Chart 버전

| Chart | Repository | Version | 최종 업데이트 |
|-------|-----------|---------|-------------|
| SigNoz | https://charts.signoz.io | 0.50.0 | 2025-10-20 |
| ArgoCD | https://argoproj.github.io/argo-helm | 5.51.0 | 2025-10-20 |
| Vault | https://helm.releases.hashicorp.com | 0.27.0 | 2025-10-20 |
| Istio Base | https://istio-release.storage.googleapis.com/charts | 1.20.0 | 2025-10-20 |
| Istiod | https://istio-release.storage.googleapis.com/charts | 1.20.0 | 2025-10-20 |
| Kube-State-Metrics | https://prometheus-community.github.io/helm-charts | 5.15.0 | 2025-10-20 |
| Fluent Bit | https://fluent.github.io/helm-charts | 0.43.0 | 2025-10-20 |

## 버전 업그레이드 절차

### 1. 사용 가능한 버전 확인
```bash
# Repository 업데이트
helm repo update

# 사용 가능한 버전 확인
helm search repo signoz/signoz --versions | head -10
helm search repo argo/argo-cd --versions | head -10
helm search repo hashicorp/vault --versions | head -10
```

### 2. Chart 정보 확인
```bash
# 현재 설치된 버전
helm list -n signoz
helm list -n argocd
helm list -n vault

# Chart 상세 정보
helm show chart signoz/signoz --version 0.50.0
helm show values signoz/signoz --version 0.50.0
```

### 3. 변경 사항 확인 (Changelog)
- **SigNoz**: https://github.com/SigNoz/charts/releases
- **ArgoCD**: https://github.com/argoproj/argo-helm/releases
- **Vault**: https://github.com/hashicorp/vault-helm/releases
- **Istio**: https://istio.io/latest/news/releases/
- **Fluent Bit**: https://github.com/fluent/helm-charts/releases

### 4. 테스트 환경에서 업그레이드 테스트
```bash
# Dry-run으로 변경사항 확인
helm upgrade signoz signoz/signoz \
  --version 0.51.0 \
  -n signoz \
  -f addons/values/signoz/signoz-values.yaml \
  --dry-run

# 실제 업그레이드
helm upgrade signoz signoz/signoz \
  --version 0.51.0 \
  -n signoz \
  -f addons/values/signoz/signoz-values.yaml

# Rollback (문제 발생 시)
helm rollback signoz -n signoz
```

### 5. Chart.lock 파일 업데이트
```bash
# addons/Chart.lock 파일 수정
# version을 새 버전으로 업데이트
# digest 및 generated 날짜도 업데이트
```

## 업그레이드 체크리스트

### Pre-Upgrade
- [ ] Changelog 검토 (Breaking Changes 확인)
- [ ] 현재 버전 백업
- [ ] Values 파일 호환성 확인
- [ ] 테스트 환경에서 업그레이드 테스트
- [ ] Downtime 예상 여부 확인
- [ ] Rollback 계획 수립

### During Upgrade
- [ ] Helm Dry-run 실행
- [ ] 업그레이드 실행
- [ ] Pod 상태 모니터링
- [ ] 로그 에러 확인

### Post-Upgrade
- [ ] 서비스 정상 동작 확인
- [ ] 모니터링 대시보드 확인
- [ ] Chart.lock 파일 업데이트
- [ ] Git 커밋 및 Push
- [ ] 문서 업데이트

## Breaking Changes 주의사항

### SigNoz
- v0.40.0 → v0.50.0: ClickHouse 스토리지 스키마 변경 가능
- 업그레이드 전 데이터 백업 필수

### ArgoCD
- v5.x → v6.x: CRD 변경 주의
- Application 설정 호환성 확인 필요

### Vault
- v0.25.0 → v0.27.0: HA Raft 설정 변경 가능
- Unseal Key 보관 확인

### Istio
- v1.19.x → v1.20.x: Gateway API 변경
- VirtualService, DestinationRule 검증 필요

## 자동화 스크립트

### helm-upgrade-check.sh
```bash
#!/bin/bash
# Helm Chart 업그레이드 가능 여부 확인

helm repo update

echo "=== 업그레이드 가능한 Chart ==="
for release in $(helm list -A -q); do
  namespace=$(helm list -A | grep $release | awk '{print $2}')
  current=$(helm list -n $namespace | grep $release | awk '{print $9}')
  latest=$(helm search repo $(helm list -n $namespace | grep $release | awk '{print $10}') --versions | head -2 | tail -1 | awk '{print $2}')

  if [ "$current" != "$latest" ]; then
    echo "📦 $release: $current → $latest 업그레이드 가능"
  fi
done
```

## 관련 문서
- `ADDON_OPERATIONS_GUIDE.md`: 애드온 운영 가이드
- `DISASTER_RECOVERY_PLAN.md`: 백업 및 복구
- `HA_CONFIGURATION_GUIDE.md`: 고가용성 설정

**문서 버전**: 1.0
**최종 수정**: 2025-10-20
**관련 JIRA**: TERRAFORM-26
