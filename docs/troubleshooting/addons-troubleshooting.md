# 애드온 트러블슈팅 가이드

이 문서는 Sprint 1, 2에서 배포된 애드온들의 **공통적인 문제와 해결 방법**을 정리합니다.

---

## 목차

1. [공통 문제](#공통-문제)
2. [MinIO](#minio)
3. [KEDA](#keda)
4. [Kyverno](#kyverno)
5. [Sloth](#sloth)
6. [Velero](#velero)
7. [Prometheus + Grafana](#prometheus--grafana)
8. [Loki + Fluent-Bit](#loki--fluent-bit)
9. [Tempo + OpenTelemetry](#tempo--opentelemetry)
10. [Istio](#istio)
11. [ArgoCD](#argocd)
12. [Vault](#vault)

---

## 공통 문제

### Pod이 `Pending` 상태

**증상:**
```bash
kubectl get pods -A | grep Pending
```

**원인:**
1. 리소스 부족 (CPU/메모리)
2. PVC 바인딩 실패
3. Node Selector/Affinity 불일치

**해결 방법:**
```bash
# 1. Pod 이벤트 확인
kubectl describe pod <pod-name> -n <namespace>

# 2. 노드 리소스 확인
kubectl top nodes

# 3. PVC 상태 확인
kubectl get pvc -A

# 4. 리소스 제한 완화 (values.yaml)
resources:
  requests:
    memory: "256Mi"  # 기존 512Mi에서 축소
    cpu: "100m"      # 기존 500m에서 축소
```

### ServiceMonitor가 Prometheus에 인식되지 않음

**증상:**
- Prometheus Targets에 나타나지 않음
- Grafana에서 메트릭 조회 불가

**원인:**
- ServiceMonitor 라벨 누락: `release: kube-prometheus-stack`

**해결 방법:**
```bash
# 1. ServiceMonitor 라벨 확인
kubectl get servicemonitor -n <namespace> <name> -o yaml | grep release

# 2. 라벨 추가 (values.yaml 또는 직접 수정)
kubectl edit servicemonitor -n <namespace> <name>

# 추가할 라벨:
metadata:
  labels:
    release: kube-prometheus-stack

# 3. Prometheus Operator 재시작 (필요 시)
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-operator

# 4. Prometheus Targets 확인
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090/targets
```

### LoadBalancer IP가 `<pending>` 상태

**증상:**
```bash
kubectl get svc -A --field-selector spec.type=LoadBalancer
# EXTERNAL-IP: <pending>
```

**원인:**
- MetalLB IP Pool 범위 외의 IP 지정
- MetalLB annotation 오류

**해결 방법:**
```bash
# 1. MetalLB IP Pool 확인
kubectl get ipaddresspool -n metallb-system -o yaml

# 2. 서비스 annotation 확인
kubectl get svc -n <namespace> <service-name> -o yaml | grep metallb

# 3. IP Pool 자동 할당 방식으로 변경
metadata:
  annotations:
    metallb.universe.tf/address-pool: default-address-pool  # IP 지정 제거

# 4. 서비스 재생성
kubectl delete svc -n <namespace> <service-name>
helm upgrade <release> <chart> -f values.yaml
```

### CRD가 설치되지 않음

**증상:**
```bash
kubectl get crd | grep <addon>
# No resources found
```

**해결 방법:**
```bash
# 1. Helm chart에 CRD가 포함되어 있는지 확인
helm show crds <chart>

# 2. CRD 수동 설치
kubectl apply -f https://<addon-crd-url>.yaml

# 3. Helm 재설치 (--force)
helm uninstall <release> -n <namespace>
helm install <release> <chart> -f values.yaml
```

---

## MinIO

### Pod이 시작되지 않음

**증상:**
```bash
kubectl get pods -n minio
# STATUS: CrashLoopBackOff 또는 Error
```

**해결 방법:**
```bash
# 1. Pod 로그 확인
kubectl logs -n minio <pod-name>

# 2. PVC 상태 확인
kubectl get pvc -n minio

# 3. PVC가 Pending이면 StorageClass 확인
kubectl get storageclass

# 4. PVC 재생성 (주의: 데이터 손실!)
kubectl delete pvc -n minio minio-pvc
helm upgrade minio oci://registry-1.docker.io/bitnamicharts/minio -f minio-values.yaml
```

### 웹 콘솔 접속 불가

**증상:**
- http://localhost:9001 접속 안 됨

**해결 방법:**
```bash
# 1. Service 확인
kubectl get svc -n minio

# 2. LoadBalancer IP 확인
CONSOLE_IP=$(kubectl get svc -n minio minio-console -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Console URL: http://$CONSOLE_IP:9001"

# 3. 포트 포워딩으로 테스트
kubectl port-forward -n minio svc/minio-console 9001:9001

# 4. 계정 정보 확인
kubectl get secret -n minio minio -o jsonpath='{.data.rootUser}' | base64 -d
kubectl get secret -n minio minio -o jsonpath='{.data.rootPassword}' | base64 -d
```

### ServiceMonitor 미생성

**증상:**
- Prometheus Targets에 MinIO 없음

**해결 방법:**
```yaml
# minio-values.yaml 수정
metrics:
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack  # 필수!
```

```bash
# 재배포
helm upgrade minio oci://registry-1.docker.io/bitnamicharts/minio -n minio -f minio-values.yaml

# ServiceMonitor 확인
kubectl get servicemonitor -n minio
```

---

## KEDA

### ScaledObject가 HPA를 생성하지 않음

**증상:**
```bash
kubectl get scaledobject -n <namespace>
# READY: False

kubectl get hpa -n <namespace>
# No resources found
```

**해결 방법:**
```bash
# 1. ScaledObject 상태 확인
kubectl describe scaledobject <name> -n <namespace>

# 2. KEDA Operator 로그 확인
kubectl logs -n keda deployment/keda-operator

# 3. Metrics API 서버 상태 확인
kubectl get apiservice v1beta1.external.metrics.k8s.io

# 4. KEDA 재시작
kubectl rollout restart deployment -n keda keda-operator
kubectl rollout restart deployment -n keda keda-operator-metrics-apiserver
```

### Prometheus Scaler 메트릭을 가져오지 못함

**증상:**
- ScaledObject 이벤트: `error getting metric from prometheus`

**해결 방법:**
```bash
# 1. Prometheus 주소 확인
kubectl get svc -n monitoring kube-prometheus-stack-prometheus

# 2. ScaledObject의 serverAddress 확인
kubectl get scaledobject <name> -n <namespace> -o yaml | grep serverAddress

# 올바른 주소:
# serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090

# 3. Prometheus 쿼리 테스트
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl "http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up"

# 4. ScaledObject 재생성
kubectl delete scaledobject <name> -n <namespace>
kubectl apply -f scaledobject.yaml
```

### 스케일 다운이 안 됨

**증상:**
- Pod 수가 줄어들지 않음

**해결 방법:**
```yaml
# ScaledObject에 cooldownPeriod 설정
spec:
  cooldownPeriod: 60  # 기본값: 300초, 1분으로 단축

  # 또는 advanced 설정으로 스케일 다운 정책 조정
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 60
```

---

## Kyverno

### Policy가 적용되지 않음

**증상:**
- 정책 위반 리소스가 생성됨

**해결 방법:**
```bash
# 1. ClusterPolicy 상태 확인
kubectl get clusterpolicy

# 2. Kyverno Webhook 확인
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno

# 3. Kyverno 로그 확인
kubectl logs -n kyverno deployment/kyverno

# 4. Policy validationFailureAction 확인
kubectl get clusterpolicy <name> -o yaml | grep validationFailureAction
# Enforce: 거부, Audit: 경고만

# 5. 네임스페이스 제외 확인
kubectl get clusterpolicy <name> -o yaml | grep -A5 exclude
```

### PolicyReport가 생성되지 않음

**증상:**
```bash
kubectl get policyreport -A
# No resources found
```

**해결 방법:**
```bash
# 1. background 스캔 활성화 확인
kubectl get clusterpolicy <name> -o yaml | grep background
# background: true

# 2. Kyverno Pod 재시작
kubectl rollout restart deployment -n kyverno kyverno

# 3. 수동 PolicyReport 트리거
kubectl label namespace default policy.kyverno.io/scan=true
```

---

## Sloth

### PrometheusRule이 생성되지 않음

**증상:**
```bash
kubectl get prometheusslo -n monitoring
# 존재함

kubectl get prometheusrule -n monitoring | grep sloth
# No resources found
```

**해결 방법:**
```bash
# 1. Sloth Pod 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=sloth -c sloth

# 2. PrometheusServiceLevel 유효성 검증
kubectl describe prometheusslo <name> -n monitoring

# 3. Sloth 재시작
kubectl rollout restart deployment -n monitoring sloth

# 4. PrometheusServiceLevel 재생성
kubectl delete prometheusslo <name> -n monitoring
kubectl apply -f slo.yaml
```

### git-sync 플러그인 로드 실패

**증상:**
- Sloth 로그: `plugins loaded: 0`

**해결 방법:**
```bash
# 1. git-sync 컨테이너 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=sloth -c git-sync-plugins

# 2. git-sync 볼륨 확인
kubectl describe pod -n monitoring -l app.kubernetes.io/name=sloth | grep -A5 Volumes

# 3. readOnlyRootFilesystem 설정 확인
kubectl get deployment -n monitoring sloth -o yaml | grep readOnlyRootFilesystem

# sloth-values.yaml에서 설정:
securityContext:
  container:
    readOnlyRootFilesystem: false  # git-sync 호환성

# 4. 재배포
helm upgrade sloth sloth/sloth -n monitoring -f sloth-values.yaml
```

### Prometheus에 메트릭이 없음

**증상:**
- Grafana에서 `slo:sli_error:ratio_rate5m` 조회 불가

**해결 방법:**
```bash
# 1. PrometheusRule 생성 확인
kubectl get prometheusrule -n monitoring sloth-slo-sli-recordings-<slo-name>

# 2. Prometheus에서 Rule 로드 확인
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090/rules 에서 "sloth" 검색

# 3. Prometheus Operator 재시작
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-operator

# 4. Recording Rule 즉시 평가
# Prometheus UI → Status → Rules → Evaluate Now
```

---

## Velero

### BackupStorageLocation `Unavailable`

**증상:**
```bash
velero backup-location get
# ACCESS MODE: Unavailable
```

**해결 방법:**
```bash
# 1. MinIO 연결 테스트
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://minio.minio.svc.cluster.local:9000

# 2. Credentials 확인
kubectl get secret -n velero cloud-credentials -o yaml

# 3. BackupStorageLocation 재설정
kubectl edit backupstoragelocation -n velero default

# s3Url 확인:
config:
  s3Url: http://minio.minio.svc.cluster.local:9000
  s3ForcePathStyle: "true"
  region: minio

# 4. Velero Pod 재시작
kubectl rollout restart deployment -n velero velero
```

### Node-Agent DaemonSet이 실행되지 않음

**증상:**
```bash
kubectl get daemonset -n velero
# DESIRED: 0, READY: 0
```

**해결 방법:**
```yaml
# velero-values.yaml 확인
nodeAgent:
  enabled: true  # 반드시 true

# 재배포
helm upgrade velero vmware-tanzu/velero -n velero -f velero-values.yaml
```

```bash
# Node-Agent Pod 상태 확인
kubectl get pods -n velero -l name=node-agent

# 로그 확인
kubectl logs -n velero -l name=node-agent
```

### 백업이 `PartiallyFailed`

**증상:**
```bash
velero backup get
# STATUS: PartiallyFailed
```

**해결 방법:**
```bash
# 1. 백업 로그 확인
velero backup logs <backup-name>

# 2. 실패한 리소스 확인
velero backup describe <backup-name> --details

# 3. 특정 리소스 제외
velero backup create retry-backup \
  --exclude-resources <failed-resource-type> \
  --include-namespaces <namespace>

# 4. 일반적인 제외 리소스
velero backup create safe-backup \
  --exclude-resources events,events.events.k8s.io
```

---

## Prometheus + Grafana

### Prometheus Pod이 CrashLoopBackOff

**증상:**
```bash
kubectl get pods -n monitoring | grep prometheus
# STATUS: CrashLoopBackOff
```

**해결 방법:**
```bash
# 1. Pod 로그 확인
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0

# 2. PVC 확인
kubectl get pvc -n monitoring

# 3. 설정 오류 확인 (PrometheusRule)
kubectl get prometheusrule -n monitoring

# 4. 잘못된 PrometheusRule 삭제
kubectl delete prometheusrule -n monitoring <invalid-rule>

# 5. Prometheus 재시작
kubectl delete pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

### Grafana 대시보드에 데이터 없음

**증상:**
- "No data" 표시

**해결 방법:**
```bash
# 1. Prometheus 데이터소스 상태 확인
# Grafana → Configuration → Data Sources → Prometheus → Save & Test

# 2. Prometheus에서 직접 쿼리 테스트
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090/graph

# 3. Targets 확인
# http://localhost:9090/targets

# 4. Time Range 확인
# Grafana 대시보드 우측 상단 시간 범위 확인
```

---

## Loki + Fluent-Bit

### 로그가 수집되지 않음

**증상:**
- Grafana Explore → Loki: "No logs found"

**해결 방법:**
```bash
# 1. Fluent-Bit DaemonSet 확인
kubectl get daemonset -n logging fluent-bit

# 2. Fluent-Bit Pod 로그 확인
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit

# 3. Loki 연결 테스트
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit | grep -i error

# 4. Loki 엔드포인트 확인 (fluent-bit-values.yaml)
config:
  outputs: |
    [OUTPUT]
        Name loki
        Match *
        Host loki-gateway.logging.svc.cluster.local
        Port 80

# 5. Loki 상태 확인
kubectl get pods -n logging -l app.kubernetes.io/name=loki
kubectl logs -n logging -l app.kubernetes.io/name=loki
```

### Loki 쿼리가 느림

**해결 방법:**
```bash
# 1. 쿼리 시간 범위 줄이기
# 나쁜 예: {namespace="default"}[7d]
# 좋은 예: {namespace="default"}[1h]

# 2. Loki 리소스 증가
kubectl edit statefulset -n logging loki

# 3. 인덱스 캐시 확인
kubectl logs -n logging loki-0 | grep cache
```

---

## Tempo + OpenTelemetry

### 트레이스가 수집되지 않음

**증상:**
- Grafana Explore → Tempo: "Trace not found"

**해결 방법:**
```bash
# 1. OpenTelemetry Collector 상태 확인
kubectl get pods -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# 2. OTEL Collector 로그 확인
kubectl logs -n tracing -l app.kubernetes.io/name=opentelemetry-collector

# 3. Tempo 엔드포인트 확인
kubectl get svc -n tracing tempo

# 4. 애플리케이션 환경 변수 확인
# OTEL_EXPORTER_OTLP_ENDPOINT=http://opentelemetry-collector.tracing.svc.cluster.local:4317

# 5. 연결 테스트
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v telnet://opentelemetry-collector.tracing.svc.cluster.local:4317
```

### Kiali에 데이터 없음

**해결 방법:**
```bash
# 1. Istio Sidecar 주입 확인
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].name}'
# "istio-proxy" 컨테이너가 있어야 함

# 2. 네임스페이스 라벨 확인
kubectl get namespace <namespace> --show-labels | grep istio-injection

# 3. Istio 주입 활성화
kubectl label namespace <namespace> istio-injection=enabled

# 4. Pod 재시작
kubectl rollout restart deployment -n <namespace>

# 5. 트래픽 생성 (Kiali는 트래픽이 있어야 표시)
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl http://my-service.<namespace>.svc.cluster.local
```

---

## Istio

### Sidecar가 주입되지 않음

**증상:**
```bash
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].name}'
# "istio-proxy" 없음
```

**해결 방법:**
```bash
# 1. 네임스페이스 라벨 확인
kubectl get namespace <namespace> --show-labels

# 2. 라벨 추가
kubectl label namespace <namespace> istio-injection=enabled

# 3. Pod 재생성
kubectl rollout restart deployment -n <namespace>

# 4. Istiod 로그 확인
kubectl logs -n istio-system -l app=istiod

# 5. Webhook 확인
kubectl get mutatingwebhookconfigurations | grep istio
```

### VirtualService 라우팅 안 됨

**증상:**
- 트래픽이 의도한 버전으로 가지 않음

**해결 방법:**
```bash
# 1. VirtualService 검증
istioctl analyze -n <namespace>

# 2. Envoy 설정 확인
istioctl proxy-config routes <pod-name>.<namespace>

# 3. Gateway 확인
kubectl get gateway -n <namespace>

# 4. VirtualService와 Gateway 연결 확인
kubectl get virtualservice <name> -n <namespace> -o yaml | grep gateways
```

---

## ArgoCD

### Application이 OutOfSync

**증상:**
```bash
argocd app list
# STATUS: OutOfSync
```

**해결 방법:**
```bash
# 1. Diff 확인
argocd app diff <app-name>

# 2. 수동 동기화
argocd app sync <app-name>

# 3. Hard Refresh
argocd app sync <app-name> --force

# 4. Prune 활성화
kubectl edit application -n argocd <app-name>

spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Git 리포지토리 연결 실패

**해결 방법:**
```bash
# 1. 리포지토리 연결 테스트
argocd repo list

# 2. 리포지토리 재추가
argocd repo add https://github.com/myorg/myrepo.git

# 3. Private 리포지토리 (SSH)
argocd repo add git@github.com:myorg/myrepo.git --ssh-private-key-path ~/.ssh/id_rsa

# 4. ArgoCD Server 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

---

## Vault

### Vault가 Sealed 상태

**증상:**
```bash
kubectl exec -n vault vault-0 -- vault status
# Sealed: true
```

**해결 방법:**
```bash
# Unseal (Unseal Key 3개 중 2개 입력)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>

# 상태 확인
kubectl exec -n vault vault-0 -- vault status
# Sealed: false
```

### Pod에서 Vault 시크릿 조회 실패

**해결 방법:**
```bash
# 1. Kubernetes Auth 활성화 확인
kubectl exec -n vault vault-0 -- vault auth list

# 2. Policy 확인
kubectl exec -n vault vault-0 -- vault policy list

# 3. Role 확인
kubectl exec -n vault vault-0 -- vault list auth/kubernetes/role

# 4. ServiceAccount Token 확인
kubectl get sa -n <namespace> <service-account>
```

---

## 유용한 디버깅 명령어

### 전체 애드온 상태 확인

```bash
# 모든 애드온 Pod 상태
kubectl get pods -A | grep -E "monitoring|logging|tracing|argocd|istio|vault|keda|kyverno|velero|minio"

# 모든 Service 확인
kubectl get svc -A | grep -E "monitoring|logging|tracing|argocd|istio|vault|keda|kyverno|velero|minio"

# LoadBalancer IP 확인
kubectl get svc -A --field-selector spec.type=LoadBalancer

# PVC 상태 확인
kubectl get pvc -A
```

### 리소스 사용량 확인

```bash
# 노드 리소스
kubectl top nodes

# Pod 리소스 (전체)
kubectl top pods -A

# 특정 네임스페이스
kubectl top pods -n monitoring
```

### 로그 수집

```bash
# 특정 애드온 전체 로그
kubectl logs -n <namespace> -l app=<app-label> --all-containers=true > addon-logs.txt

# 이벤트 확인
kubectl get events -A --sort-by='.lastTimestamp' | tail -50

# Describe 정보 수집
kubectl describe pod -n <namespace> <pod-name> > pod-describe.txt
```

---

## 참고 자료

각 애드온별 상세 가이드:
- [MinIO 가이드](../addons/storage.md)
- [KEDA 가이드](../addons/keda-guide.md)
- [Kyverno 가이드](../addons/security.md#kyverno)
- [Sloth 가이드](../addons/sloth-guide.md)
- [Velero 가이드](../addons/velero-guide.md)
- [모니터링 가이드](../addons/monitoring.md)
- [로깅 가이드](../addons/logging.md)
- [트레이싱 가이드](../addons/tracing.md)
- [Service Mesh 가이드](../addons/service-mesh.md)
- [GitOps 가이드](../addons/gitops.md)
- [보안 가이드](../addons/security.md)
