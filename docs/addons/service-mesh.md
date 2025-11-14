# Service Mesh (Istio)

## 개요

Istio Service Mesh는 마이크로서비스 간의 통신을 관리하고 보안을 강화합니다.
- **Traffic Management**: 트래픽 라우팅, 로드 밸런싱, 타임아웃, 재시도
- **Security**: mTLS, 인증, 권한 부여
- **Observability**: 메트릭, 로그, 트레이스 자동 수집
- **Ingress Gateway**: 외부 트래픽 진입점

## 설치

```bash
cd addons
./install.sh
```

또는 개별 설치:

```bash
# Istio Base
helm upgrade --install istio-base istio/base \
  -n istio-system --create-namespace

# Istiod (Control Plane)
helm upgrade --install istiod istio/istiod \
  -n istio-system

# Ingress Gateway
helm upgrade --install istio-ingress istio/gateway \
  -n istio-ingress --create-namespace
```

## 핵심 사용법

### 1. Sidecar 주입 활성화

네임스페이스에 자동 주입 활성화:

```bash
kubectl label namespace default istio-injection=enabled
```

검증:

```bash
# 라벨 확인
kubectl get namespace -L istio-injection

# 기존 Pod 재시작 (사이드카 주입)
kubectl rollout restart deployment -n default
```

### 2. VirtualService - 트래픽 라우팅

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
  namespace: default
spec:
  hosts:
    - my-app.example.com
  gateways:
    - istio-ingress/gateway  # Gateway 이름
  http:
    # 헤더 기반 라우팅
    - match:
        - headers:
            version:
              exact: v2
      route:
        - destination:
            host: my-app-v2
            port:
              number: 8080
    # 가중치 기반 라우팅 (Canary)
    - route:
        - destination:
            host: my-app-v1
            port:
              number: 8080
          weight: 90
        - destination:
            host: my-app-v2
            port:
              number: 8080
          weight: 10
```

### 3. DestinationRule - 트래픽 정책

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app
  namespace: default
spec:
  host: my-app
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN  # ROUND_ROBIN, RANDOM, PASSTHROUGH
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

### 4. Gateway - 외부 트래픽

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: gateway
  namespace: istio-ingress
spec:
  selector:
    istio: ingress
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "*.example.com"
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: example-com-cert  # Secret 이름
      hosts:
        - "*.example.com"
```

### 5. PeerAuthentication - mTLS

```yaml
# 네임스페이스 전체 mTLS 활성화
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT  # STRICT, PERMISSIVE, DISABLE
```

### 6. AuthorizationPolicy - 접근 제어

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-app
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
    - from:
        - source:
            principals: ["cluster.local/ns/frontend/sa/frontend-service-account"]
```

## 주요 명령어

### istioctl 명령어

```bash
# Istio 버전 확인
istioctl version

# 프록시 상태 확인
istioctl proxy-status

# 특정 Pod의 설정 확인
istioctl proxy-config cluster <pod-name> -n default

# 설정 동기화 상태
istioctl proxy-status <pod-name>.<namespace>

# Envoy 로그 레벨 변경
istioctl proxy-config log <pod-name> -n default --level debug

# 설정 검증
istioctl analyze -n default

# 사이드카 주입 여부 확인
istioctl experimental check-inject -f deployment.yaml
```

### 트래픽 테스트

```bash
# Ingress Gateway IP 확인
kubectl get svc -n istio-ingress

# 트래픽 전송
curl -H "Host: my-app.example.com" http://<GATEWAY_IP>/

# 특정 버전으로 라우팅 테스트
curl -H "Host: my-app.example.com" -H "version: v2" http://<GATEWAY_IP>/
```

### mTLS 확인

```bash
# mTLS 상태 확인
istioctl experimental auth check <pod-name>.<namespace>

# 인증서 확인
istioctl proxy-config secret <pod-name> -n default
```

## 트래픽 관리 패턴

### 1. Canary Deployment

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-canary
spec:
  hosts:
    - my-app
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: my-app
            subset: v2
    - route:
        - destination:
            host: my-app
            subset: v1
          weight: 95
        - destination:
            host: my-app
            subset: v2
          weight: 5
```

### 2. Traffic Mirroring (Shadow Traffic)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-mirror
spec:
  hosts:
    - my-app
  http:
    - route:
        - destination:
            host: my-app
            subset: v1
      mirror:
        host: my-app
        subset: v2
      mirrorPercentage:
        value: 100.0
```

### 3. 타임아웃 및 재시도

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-resilience
spec:
  hosts:
    - my-app
  http:
    - route:
        - destination:
            host: my-app
      timeout: 10s
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,reset,connect-failure,refused-stream
```

### 4. Circuit Breaker

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app-cb
spec:
  host: my-app
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

## Kiali 활용

```bash
# Kiali URL
http://kiali.bocopile.io

# 기능:
# - Service Graph: 서비스 간 의존성 시각화
# - Traffic: 실시간 트래픽 흐름
# - Traces: 분산 트레이싱
# - Configuration: Istio 리소스 검증
# - mTLS Status: 보안 상태 확인
```

## 트러블슈팅

### Sidecar 주입 안됨
```bash
# 1. 네임스페이스 라벨 확인
kubectl get namespace default --show-labels

# 2. Istiod 로그 확인
kubectl logs -n istio-system -l app=istiod

# 3. Webhook 확인
kubectl get mutatingwebhookconfiguration istio-sidecar-injector -o yaml
```

### 트래픽이 라우팅되지 않음
```bash
# 1. VirtualService 검증
istioctl analyze

# 2. Envoy 설정 확인
istioctl proxy-config route <pod-name> -n default

# 3. Gateway 리스너 확인
istioctl proxy-config listener <gateway-pod> -n istio-ingress

# 4. 로그 확인
kubectl logs -n default <pod-name> -c istio-proxy
```

### mTLS 연결 실패
```bash
# 1. mTLS 정책 확인
kubectl get peerauthentication -A

# 2. DestinationRule TLS 모드 확인
kubectl get destinationrule -A -o yaml | grep -A5 tls

# 3. 인증서 확인
istioctl proxy-config secret <pod-name> -n default
```

## 참고 자료

- [Istio 공식 문서](https://istio.io/latest/docs/)
- [Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Security](https://istio.io/latest/docs/concepts/security/)
- [Observability](https://istio.io/latest/docs/concepts/observability/)
- [Best Practices](https://istio.io/latest/docs/ops/best-practices/)
