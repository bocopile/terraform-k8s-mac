# Promtail → Fluent Bit 마이그레이션 가이드

## 📋 개요

본 가이드는 기존 Promtail 기반 로그 수집 시스템을 Fluent Bit으로 전환하는 방법을 안내합니다.

### 마이그레이션 이유

1. **리소스 효율성**: Fluent Bit은 Promtail 대비 50% 이하의 메모리 사용 (64Mi vs 128Mi)
2. **OpenTelemetry 통합**: Native OTLP 지원으로 trace correlation 강화
3. **다양한 출력**: Loki + OpenTelemetry Collector 동시 출력 지원
4. **성능**: C로 작성되어 Go 기반 Promtail보다 빠른 처리 속도
5. **파서 확장성**: Envoy 로그, JSON, Regex 등 다양한 파서 내장

---

## 🔄 마이그레이션 절차

### 1단계: 기존 환경 확인

#### Promtail 상태 확인
```bash
# Promtail Pod 확인
kubectl get pods -n logging -l app.kubernetes.io/name=promtail

# Promtail 로그 확인
kubectl logs -n logging -l app.kubernetes.io/name=promtail --tail=50

# Loki에 로그 수집 확인
kubectl port-forward -n logging svc/loki 3100:3100
curl http://localhost:3100/loki/api/v1/labels
```

#### 백업 (선택 사항)
```bash
# Promtail Helm 값 백업
helm get values promtail -n logging > promtail-values-backup.yaml

# Promtail ConfigMap 백업
kubectl get configmap -n logging promtail -o yaml > promtail-configmap-backup.yaml
```

---

### 2단계: Fluent Bit 배포

#### Helm Repo 추가
```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
```

#### Fluent Bit 설치
```bash
# 설정 파일 위치 확인
cat addons/values/logging/fluent-bit-values.yaml

# Fluent Bit 배포
helm upgrade --install fluent-bit fluent/fluent-bit \
  -n logging \
  --create-namespace \
  -f addons/values/logging/fluent-bit-values.yaml
```

#### 배포 확인
```bash
# Pod 상태 확인
kubectl get pods -n logging -l app.kubernetes.io/name=fluent-bit

# DaemonSet 확인 (모든 노드에 배포됨)
kubectl get daemonset -n logging fluent-bit

# 로그 확인
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=50
```

---

### 3단계: 동시 실행 및 검증

Fluent Bit과 Promtail을 동시에 실행하여 로그 수집을 비교합니다.

#### Loki에서 로그 확인
```bash
# Port-forward
kubectl port-forward -n logging svc/loki 3100:3100

# Fluent Bit 로그 확인
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="fluentbit"}' | jq

# Promtail 로그 확인
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="promtail"}' | jq
```

#### 메타데이터 확인
```bash
# Kubernetes 메타데이터가 포함되었는지 확인
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="fluentbit", kubernetes_namespace_name!=""}' | jq

# trace_id 필드 확인 (OpenTelemetry 통합)
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="fluentbit"} | json | trace_id != ""' | jq
```

#### 리소스 사용량 비교
```bash
# Promtail 리소스 사용
kubectl top pods -n logging -l app.kubernetes.io/name=promtail

# Fluent Bit 리소스 사용
kubectl top pods -n logging -l app.kubernetes.io/name=fluent-bit
```

**예상 결과**:
- Promtail: ~100Mi Memory, ~50m CPU
- Fluent Bit: ~64Mi Memory, ~30m CPU

---

### 4단계: Promtail 제거

검증 완료 후 Promtail을 제거합니다.

```bash
# Promtail Uninstall
helm uninstall promtail -n logging

# ConfigMap 정리 (자동 삭제되지만 확인)
kubectl delete configmap -n logging promtail --ignore-not-found=true

# PVC 정리 (있는 경우)
kubectl delete pvc -n logging -l app.kubernetes.io/name=promtail
```

---

### 5단계: 최종 검증

#### Loki 로그 수집 확인
```bash
# Fluent Bit 로그만 수집되는지 확인
kubectl port-forward -n logging svc/loki 3100:3100

curl -G -s "http://localhost:3100/loki/api/v1/labels" | jq
curl -G -s "http://localhost:3100/loki/api/v1/label/job/values" | jq
```

**예상 출력**:
```json
{
  "status": "success",
  "data": [
    "fluentbit"
  ]
}
```

#### Grafana에서 로그 확인
```bash
# Grafana 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# http://localhost:3000
# Explore → Loki → {job="fluentbit"}
```

#### Prometheus 메트릭 확인
```bash
# Fluent Bit ServiceMonitor 확인
kubectl get servicemonitor -n logging fluent-bit

# Prometheus에서 메트릭 확인
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# http://localhost:9090
# fluentbit_* 메트릭 검색
```

---

## 📊 주요 차이점

| 항목 | Promtail | Fluent Bit |
|------|----------|------------|
| 언어 | Go | C |
| 메모리 사용 | ~128Mi | ~64Mi |
| CPU 사용 | ~50m | ~30m |
| 파서 | Limited | 20+ Built-in |
| 출력 | Loki Only | Loki + OTLP + 50+ |
| OpenTelemetry | ❌ | ✅ Native |
| 멀티 출력 | ❌ | ✅ |
| 커뮤니티 | Grafana Labs | CNCF |

---

## 🔧 설정 매핑

### Promtail → Fluent Bit 설정 비교

#### 로그 수집 경로
**Promtail**:
```yaml
config:
  clients:
  - url: http://loki.logging.svc.cluster.local:3100/loki/api/v1/push
```

**Fluent Bit**:
```yaml
config:
  outputs: |
    [OUTPUT]
        Name loki
        Match kube.*
        Host loki.logging.svc.cluster.local
        Port 3100
```

#### Kubernetes 메타데이터
**Promtail**: Automatic via scrape_configs

**Fluent Bit**: Explicit filter
```yaml
[FILTER]
    Name kubernetes
    Match kube.*
    Labels On
```

#### 파서 설정
**Promtail**: Limited to pipeline stages

**Fluent Bit**: Dedicated parsers
```yaml
[PARSER]
    Name envoy-json
    Format json

[PARSER]
    Name otel-trace-id
    Format regex
    Regex ^.*trace_id[=:](?<trace_id>[a-f0-9]{32}).*$
```

---

## 🚨 롤백 절차

문제 발생 시 Promtail로 롤백합니다.

```bash
# 1. Fluent Bit 일시 중지
kubectl scale daemonset -n logging fluent-bit --replicas=0

# 2. Promtail 재배포
helm upgrade --install promtail grafana/promtail \
  -n logging \
  -f addons/values/logging/promtail-values.yaml

# 3. Promtail 확인
kubectl get pods -n logging -l app.kubernetes.io/name=promtail

# 4. 로그 수집 확인
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="promtail"}' | jq

# 5. Fluent Bit 완전 제거 (선택)
helm uninstall fluent-bit -n logging
```

---

## ✅ 체크리스트

마이그레이션 완료 전 확인 사항:

- [ ] Fluent Bit Pod이 모든 노드에 정상 배포됨
- [ ] Loki에 Fluent Bit 로그가 정상 수집됨
- [ ] Kubernetes 메타데이터 (Pod, Namespace, Labels)가 포함됨
- [ ] trace_id 필드가 존재함 (OpenTelemetry 통합 확인)
- [ ] OpenTelemetry Collector에 로그가 전송됨
- [ ] Prometheus에서 Fluent Bit 메트릭이 수집됨
- [ ] Grafana에서 로그 쿼리가 정상 동작함
- [ ] 리소스 사용량이 Promtail 대비 감소함
- [ ] Promtail이 안전하게 제거됨
- [ ] 기존 대시보드 및 알림이 정상 동작함

---

## 📚 참고 자료

- [Fluent Bit Helm Chart](https://github.com/fluent/helm-charts)
- [Fluent Bit Kubernetes Filter](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes)
- [Fluent Bit Loki Output](https://docs.fluentbit.io/manual/pipeline/outputs/loki)
- [Fluent Bit OpenTelemetry Output](https://docs.fluentbit.io/manual/pipeline/outputs/opentelemetry)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)

---

## 🎯 다음 단계

1. **Grafana Tempo 통합** (TERRAFORM-58)
   - trace_id를 활용한 Logs ↔ Traces 연결

2. **cert-manager 설정** (TERRAFORM-59)
   - Fluent Bit ↔ Loki TLS 암호화

3. **알림 설정**
   - Fluent Bit 메트릭 기반 알림 (로그 수집 실패, 버퍼 초과 등)

---

**작성일**: 2025-01-10
**작성자**: Claude Code
**관련 JIRA**: TERRAFORM-57
