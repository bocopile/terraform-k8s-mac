# Jaeger → Grafana Tempo 마이그레이션 가이드

## 📋 개요

본 가이드는 기존 Jaeger 기반 분산 트레이싱 시스템을 Grafana Tempo로 전환하는 방법을 안내합니다.

### 마이그레이션 이유

1. **Grafana 통합**: Logs ↔ Traces 상호 참조 (trace_id 기반)
2. **S3 스토리지**: MinIO/S3 백엔드 지원으로 장기 보관 및 비용 절감
3. **성능 향상**: 효율적인 블록 스토리지 및 쿼리 최적화
4. **확장성**: Horizontal scaling 지원 (distributor, ingester, querier 분리)
5. **비용 효율**: 메모리 기반 Jaeger 대비 50% 이상 리소스 절감

---

## 🔄 마이그레이션 절차

### 1단계: 기존 환경 확인

#### Jaeger 상태 확인
```bash
# Jaeger Pod 확인
kubectl get pods -n tracing -l app.kubernetes.io/name=jaeger

# Jaeger 서비스 확인
kubectl get svc -n tracing -l app.kubernetes.io/name=jaeger

# Jaeger에 trace 수집 확인
kubectl port-forward -n tracing svc/jaeger-query 16686:16686
# http://localhost:16686
```

#### 백업 (선택 사항)
Jaeger는 메모리 스토리지를 사용하므로 영구 백업이 없습니다.
필요시 현재 trace 데이터를 스크린샷으로 기록하세요.

---

### 2단계: Grafana Tempo 배포

#### Helm Repo 추가
```bash
# Grafana Helm repo 추가 (이미 있음)
helm repo update
```

#### Grafana Tempo 설치
```bash
# 설정 파일 위치 확인
cat addons/values/tracing/tempo-values.yaml

# Tempo 배포
helm upgrade --install tempo grafana/tempo \
  -n tracing \
  --create-namespace \
  -f addons/values/tracing/tempo-values.yaml
```

#### 배포 확인
```bash
# Pod 상태 확인
kubectl get pods -n tracing -l app.kubernetes.io/name=tempo

# PVC 확인 (10Gi 스토리지)
kubectl get pvc -n tracing

# 서비스 확인
kubectl get svc -n tracing tempo

# 로그 확인
kubectl logs -n tracing -l app.kubernetes.io/name=tempo --tail=50
```

---

### 3단계: OpenTelemetry Collector 업데이트

OpenTelemetry Collector가 Tempo로 trace를 전송하도록 설정이 자동 업데이트됩니다.

#### 설정 확인
```bash
# OTel Collector ConfigMap 확인
kubectl get configmap -n tracing otel-opentelemetry-collector -o yaml | grep -A5 "endpoint:"
```

**예상 출력**:
```yaml
endpoint: tempo.tracing.svc.cluster.local:4317
```

#### OTel Collector 재시작
```bash
# ConfigMap 변경 후 재시작
kubectl rollout restart deployment -n tracing otel-opentelemetry-collector
kubectl rollout status deployment -n tracing otel-opentelemetry-collector
```

---

### 4단계: 동시 실행 및 검증

Tempo와 Jaeger를 동시에 실행하여 trace 수집을 비교합니다.

#### Tempo에서 trace 확인
```bash
# Tempo query port-forward
kubectl port-forward -n tracing svc/tempo 3200:3200

# Trace 검색 (API)
curl "http://localhost:3200/api/search?tags=service.name=my-service" | jq
```

#### Grafana에서 확인
```bash
# Grafana port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# http://localhost:3000
# Configuration → Data Sources → Tempo 추가 확인
# Explore → Tempo → Search
```

#### Logs ↔ Traces 상호 참조 테스트
```bash
# 1. Loki에서 trace_id가 있는 로그 검색
{job="fluentbit"} | json | trace_id != ""

# 2. trace_id 복사

# 3. Grafana Explore → Tempo → Query by Trace ID로 이동

# 4. trace_id 입력 → 전체 trace 조회
```

#### 리소스 사용량 비교
```bash
# Jaeger 리소스 사용
kubectl top pods -n tracing -l app.kubernetes.io/name=jaeger

# Tempo 리소스 사용
kubectl top pods -n tracing -l app.kubernetes.io/name=tempo
```

**예상 결과**:
- Jaeger: ~512Mi Memory, ~200m CPU
- Tempo: ~256Mi Memory, ~100m CPU (50% 절감)

---

### 5단계: Jaeger 제거

검증 완료 후 Jaeger를 제거합니다.

```bash
# Jaeger Uninstall
helm uninstall jaeger -n tracing

# Jaeger LoadBalancer 서비스 제거 확인
kubectl get svc -n tracing | grep jaeger

# PVC 정리 (없음, 메모리 스토리지 사용)
```

---

### 6단계: 최종 검증

#### Tempo 트레이스 수집 확인
```bash
# Port-forward
kubectl port-forward -n tracing svc/tempo 3200:3200

# Search API 테스트
curl "http://localhost:3200/api/search?limit=10" | jq

# Trace ID로 조회
TRACE_ID=$(curl -s "http://localhost:3200/api/search?limit=1" | jq -r '.traces[0].traceID')
curl "http://localhost:3200/api/traces/$TRACE_ID" | jq
```

#### Grafana Data Source 확인
```bash
# Grafana 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# http://localhost:3000
# Configuration → Data Sources → Tempo
# - URL: http://tempo.tracing.svc.cluster.local:3200
# - Trace to logs: Enabled (Loki 연동)
```

#### ServiceMonitor 확인
```bash
# Prometheus에서 Tempo 메트릭 수집 확인
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# http://localhost:9090
# tempo_* 메트릭 검색
```

#### Logs → Traces 링크 테스트
```bash
# Grafana Explore
# 1. Loki 선택
# 2. {job="fluentbit"} | json 쿼리
# 3. 로그 라인 클릭 → "Tempo" 링크 확인
# 4. 클릭 시 해당 trace로 이동
```

---

## 📊 주요 차이점

| 항목 | Jaeger | Grafana Tempo |
|------|--------|---------------|
| 스토리지 | Memory (휘발성) | Filesystem / S3 (영구) |
| 메모리 사용 | ~512Mi | ~256Mi (50% ↓) |
| CPU 사용 | ~200m | ~100m (50% ↓) |
| Retention | 재시작 시 삭제 | 7일 (로컬), 30일 (S3) |
| Grafana 통합 | 별도 연동 | Native 지원 |
| Logs 연동 | ❌ | ✅ trace_id 기반 |
| S3 백엔드 | ❌ | ✅ |
| Query 최적화 | Basic | Query Frontend + Cache |
| 커뮤니티 | CNCF (Jaeger) | Grafana Labs |

---

## 🔧 설정 매핑

### Jaeger → Tempo 설정 비교

#### 수신기 (Receivers)
**Jaeger**:
```yaml
# Jaeger native receivers
- thrift_http: 14268
- grpc: 14250
```

**Tempo**:
```yaml
# OTLP receivers (primary)
- otlp-grpc: 4317
- otlp-http: 4318

# Jaeger compatibility (migration)
- jaeger-thrift-http: 14268
- jaeger-grpc: 14250

# Zipkin compatibility
- zipkin: 9411
```

#### 스토리지
**Jaeger**:
```yaml
storage:
  type: memory  # 휘발성
```

**Tempo**:
```yaml
storage:
  trace:
    backend: local  # 또는 s3
    local:
      path: /var/tempo/traces
  retention:
    max_duration: 168h  # 7 days
```

#### Grafana 연동
**Jaeger**: 수동 Data Source 추가 필요

**Tempo**: 자동 Logs ↔ Traces 연동
```yaml
tracesToLogs:
  datasourceUid: 'loki'
  filterByTraceID: true
```

---

## 🚨 롤백 절차

문제 발생 시 Jaeger로 롤백합니다.

```bash
# 1. Tempo 일시 중지
kubectl scale deployment -n tracing tempo --replicas=0

# 2. OTel Collector 설정 롤백
# otel-values.yaml의 endpoint를 jaeger-collector로 변경

# 3. Jaeger 재배포
helm upgrade --install jaeger jaegertracing/jaeger \
  -n tracing \
  -f addons/values/tracing/jaeger-values.yaml

# 4. OTel Collector 재시작
kubectl rollout restart deployment -n tracing otel-opentelemetry-collector

# 5. Jaeger Query 확인
kubectl port-forward -n tracing svc/jaeger-query 16686:16686

# 6. Tempo 완전 제거 (선택)
helm uninstall tempo -n tracing
```

---

## ✅ 체크리스트

마이그레이션 완료 전 확인 사항:

- [ ] Tempo Pod이 정상 실행됨
- [ ] PVC 10Gi가 생성되고 바인딩됨
- [ ] OTLP 4317/4318 포트가 정상 수신됨
- [ ] OpenTelemetry Collector → Tempo 연동 성공
- [ ] Grafana Data Source에 Tempo 등록됨
- [ ] Grafana Explore에서 trace 쿼리 가능
- [ ] Logs → Traces 링크가 정상 동작함 (trace_id)
- [ ] Traces → Logs 링크가 정상 동작함
- [ ] Prometheus에서 Tempo 메트릭 수집됨
- [ ] 리소스 사용량이 Jaeger 대비 감소함
- [ ] Jaeger가 안전하게 제거됨

---

## 🔗 S3 (MinIO) 백엔드 연동 (선택 사항)

장기 보관 및 비용 절감을 위해 MinIO S3를 백엔드로 사용할 수 있습니다.

### MinIO 설치
```bash
# MinIO Helm Chart 설치
helm repo add minio https://charts.min.io/
helm upgrade --install minio minio/minio \
  -n minio \
  --create-namespace \
  --set rootUser=admin \
  --set rootPassword=minio123 \
  --set persistence.size=50Gi
```

### Tempo 설정 업데이트
```yaml
# tempo-values.yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: tempo-traces
      endpoint: minio.minio.svc.cluster.local:9000
      access_key: admin
      secret_key: minio123
      insecure: true
```

### Retention 정책
- **Local (Hot)**: 7일 (빠른 쿼리)
- **S3 (Warm)**: 30일 (압축, 장기 보관)
- **Compaction**: 자동 블록 병합 및 최적화

---

## 📚 참고 자료

- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Tempo Helm Chart](https://github.com/grafana/helm-charts/tree/main/charts/tempo)
- [Tempo Configuration](https://grafana.com/docs/tempo/latest/configuration/)
- [Logs to Traces](https://grafana.com/docs/grafana/latest/datasources/tempo/#trace-to-logs)
- [Tempo Performance](https://grafana.com/docs/tempo/latest/operations/backend_local/)

---

## 🎯 다음 단계

1. **cert-manager 설정** (TERRAFORM-59)
   - Tempo ↔ Grafana TLS 암호화

2. **Distributed Tempo**
   - High Availability 구성
   - Scaling (Distributor, Ingester, Querier 분리)

3. **Alerting 설정**
   - Tempo 메트릭 기반 알림 (trace ingestion rate, query latency)

---

**작성일**: 2025-01-10
**작성자**: Claude Code
**관련 JIRA**: TERRAFORM-58
