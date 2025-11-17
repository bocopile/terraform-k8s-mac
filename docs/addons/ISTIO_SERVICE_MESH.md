# Istio Multi-cluster Service Mesh

## Overview

Istio Service Mesh를 Control Cluster와 App Cluster에 걸쳐 구성하여 마이크로서비스 간 통신을 관리하고, 트래픽 제어, 보안, 관찰성을 제공합니다.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│              Control Cluster (Primary)                    │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Istiod (192.168.64.107)                           │ │
│  │  - Control Plane                                   │ │
│  │  - Certificate Authority                           │ │
│  │  - Service Discovery                               │ │
│  │  - Configuration Distribution                      │ │
│  └──────────────┬─────────────────────────────────────┘ │
│                 │                                         │
│  ┌──────────────┴─────────────────────────────────────┐ │
│  │  Istio Ingress Gateway (192.168.64.108)            │ │
│  │  - North-South Traffic                             │ │
│  │  - External Access                                 │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Kiali (192.168.64.109)                            │ │
│  │  - Service Mesh Visualization                      │ │
│  │  - Traffic Flow                                    │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
                  │
                  │ Control Plane Sync
                  │
┌──────────────────────────────────────────────────────────┐
│              App Cluster (Remote)                         │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Istio Sidecar Proxies (Envoy)                     │ │
│  │  - East-West Traffic                               │ │
│  │  - mTLS                                            │ │
│  │  - Load Balancing                                  │ │
│  │  - Controlled by Control Cluster Istiod           │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Istio Ingress Gateway (192.168.64.128)            │ │
│  │  - Application Entry Point                         │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Service A   │  │ Service B   │  │ Service C   │    │
│  │ + Envoy     │  │ + Envoy     │  │ + Envoy     │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└──────────────────────────────────────────────────────────┘
```

## Installation

### Prerequisites

```bash
# Install istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Verify installation
istioctl version
```

### 1. Install Istio on Control Cluster (Primary)

```bash
# Create namespace
kubectl create namespace istio-system

# Install Istio base
istioctl install -f addons/values/service-mesh/control-istio-values.yaml -y

# Verify installation
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

### 2. Configure Multi-cluster Secret

App Cluster가 Control Cluster의 Istiod에 접근할 수 있도록 설정합니다.

```bash
# Create remote secret for App Cluster
istioctl x create-remote-secret \
  --name=app-cluster \
  --context=kubernetes-admin@kubernetes-app | \
  kubectl apply -f - --context=kubernetes-admin@kubernetes-control
```

### 3. Install Istio on App Cluster (Remote)

```bash
# Install Istio (remote configuration)
istioctl install -f addons/values/service-mesh/app-istio-values.yaml -y \
  --context=kubernetes-admin@kubernetes-app

# Verify installation
kubectl get pods -n istio-system --context=kubernetes-admin@kubernetes-app
```

### 4. Enable Cross-cluster Service Discovery

```bash
# Expose istiod for remote access
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: istiod-remote
  namespace: istio-system
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.64.107
  ports:
  - name: tls-istiod
    port: 15012
    targetPort: 15012
  - name: tls-webhook
    port: 15017
    targetPort: 15017
  selector:
    app: istiod
EOF
```

### 5. Install Kiali (Observability Dashboard)

```bash
# Apply Kiali manifest
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Access Kiali
open http://192.168.64.109:20001
```

## Sidecar Injection

### Automatic Injection

Namespace에 label을 추가하여 자동 injection 활성화:

```bash
# Enable injection for namespace
kubectl label namespace default istio-injection=enabled

# Verify
kubectl get namespace -L istio-injection
```

### Manual Injection

```bash
# Inject sidecar manually
istioctl kube-inject -f deployment.yaml | kubectl apply -f -
```

### Example Deployment

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
  labels:
    istio-injection: enabled

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
        version: v1
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
```

## Traffic Management

### Virtual Service

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: default
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

### Destination Rule

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
  namespace: default
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer:
        simple: ROUND_ROBIN
```

### Gateway

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-gateway
  namespace: demo
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"

---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin
  namespace: demo
spec:
  hosts:
  - "httpbin.example.com"
  gateways:
  - httpbin-gateway
  http:
  - route:
    - destination:
        host: httpbin
        port:
          number: 80
```

## Security

### mTLS (Mutual TLS)

#### Strict mTLS

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

#### Permissive mTLS (for migration)

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: demo
spec:
  mtls:
    mode: PERMISSIVE
```

### Authorization Policy

#### Allow all traffic

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-all
  namespace: demo
spec:
  action: ALLOW
  rules:
  - {}
```

#### Deny all traffic

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: demo
spec:
  {}
```

#### Allow specific service

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin
  namespace: demo
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/demo/sa/sleep"]
    to:
    - operation:
        methods: ["GET"]
```

### Request Authentication (JWT)

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-example
  namespace: demo
spec:
  selector:
    matchLabels:
      app: httpbin
  jwtRules:
  - issuer: "testing@secure.istio.io"
    jwksUri: "https://raw.githubusercontent.com/istio/istio/release-1.20/security/tools/jwt/samples/jwks.json"
```

## Observability

### Metrics

Istio는 자동으로 Prometheus metrics를 생성합니다.

#### Key Metrics

- `istio_requests_total` - Total requests
- `istio_request_duration_milliseconds` - Request duration
- `istio_request_bytes` - Request size
- `istio_response_bytes` - Response size
- `istio_tcp_sent_bytes_total` - TCP bytes sent
- `istio_tcp_received_bytes_total` - TCP bytes received

### Distributed Tracing

Istio는 OpenTelemetry Collector로 trace를 전송합니다.

```yaml
# Deployment with tracing headers
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        # Propagate trace headers
        - name: TRACE_HEADERS
          value: "x-request-id,x-b3-traceid,x-b3-spanid,x-b3-parentspanid,x-b3-sampled,x-b3-flags,x-ot-span-context"
```

### Access Logs

```yaml
# Enable access logs
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: mesh-default
  namespace: istio-system
spec:
  accessLogging:
  - providers:
    - name: envoy
```

## Traffic Policies

### Circuit Breaker

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin
  namespace: demo
spec:
  host: httpbin
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 1
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 100
      minHealthPercent: 50
```

### Retry

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
  namespace: default
spec:
  hosts:
  - ratings
  http:
  - route:
    - destination:
        host: ratings
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx
```

### Timeout

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: default
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
    timeout: 10s
```

### Rate Limiting

```yaml
# Local rate limit
apiVersion: networking.istio.io/v1beta1
kind: EnvoyFilter
metadata:
  name: filter-local-ratelimit
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      app: httpbin
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.local_ratelimit
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
          stat_prefix: http_local_rate_limiter
          token_bucket:
            max_tokens: 10
            tokens_per_fill: 10
            fill_interval: 60s
          filter_enabled:
            runtime_key: local_rate_limit_enabled
            default_value:
              numerator: 100
              denominator: HUNDRED
          filter_enforced:
            runtime_key: local_rate_limit_enforced
            default_value:
              numerator: 100
              denominator: HUNDRED
```

## Canary Deployment

### Traffic Splitting

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: default
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
```

### Header-based Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: default
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
```

## Multi-cluster Traffic

### Cross-cluster Service Access

```yaml
# Service on App Cluster accessible from Control Cluster
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: default
  annotations:
    topology.istio.io/network: app-network
spec:
  selector:
    app: myapp
  ports:
  - port: 8080
    targetPort: 8080
```

### Service Entry for External Services

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-api
  namespace: default
spec:
  hosts:
  - api.external.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

## Troubleshooting

### Check Proxy Status

```bash
# Check proxy sync status
istioctl proxy-status

# Get proxy config
istioctl proxy-config clusters <pod-name> -n <namespace>
istioctl proxy-config listeners <pod-name> -n <namespace>
istioctl proxy-config routes <pod-name> -n <namespace>
istioctl proxy-config endpoints <pod-name> -n <namespace>
```

### Analyze Configuration

```bash
# Analyze namespace
istioctl analyze -n demo

# Analyze all namespaces
istioctl analyze --all-namespaces
```

### Debug Envoy

```bash
# Get Envoy logs
kubectl logs <pod-name> -c istio-proxy -n <namespace>

# Enable debug logging
istioctl proxy-config log <pod-name> --level debug
```

### Verify mTLS

```bash
# Check mTLS status
istioctl authn tls-check <pod-name>.<namespace>

# Verify certificates
istioctl proxy-config secret <pod-name> -n <namespace>
```

## Best Practices

### 1. Start with Permissive mTLS

```yaml
# Gradually enable strict mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE
```

### 2. Use Namespace-scoped Policies

```yaml
# Namespace-specific policy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: prod
spec:
  {}
```

### 3. Resource Limits

```yaml
# Set resource limits for sidecars
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-sidecar-injector
  namespace: istio-system
data:
  values: |
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1024Mi
```

### 4. Health Checks

```yaml
# Configure health checks
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 5
      interval: 10s
      baseEjectionTime: 30s
```

## ArgoCD Integration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-base
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://istio-release.storage.googleapis.com/charts
    targetRevision: 1.20.0
    chart: base
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## References

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Multi-cluster](https://istio.io/latest/docs/setup/install/multicluster/)
- [Istio Best Practices](https://istio.io/latest/docs/ops/best-practices/)

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-17 | 1.0.0 | Istio Multi-cluster Service Mesh 초기 설정 |
