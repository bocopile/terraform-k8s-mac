#!/usr/bin/env bash
# OpenTelemetry Demo 애플리케이션 배포 스크립트
# 사용법: ./deploy-all.sh [python|nodejs|java|all]

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd -P)"
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/kubeconfig}"
export KUBECONFIG="$KUBECONFIG_PATH"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        log_error "'$1' 명령이 필요합니다"
        exit 1
    }
}

# 사전 요구사항 확인
check_prerequisites() {
    log_info "사전 요구사항 확인 중..."
    need_cmd kubectl
    need_cmd docker

    # Kubernetes 연결 확인
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Kubernetes 클러스터에 연결할 수 없습니다"
        exit 1
    fi

    # SigNoz OTEL Collector 확인
    if ! kubectl get svc -n observability signoz-otel-collector >/dev/null 2>&1; then
        log_warn "SigNoz OTEL Collector 서비스를 찾을 수 없습니다"
        log_warn "SigNoz가 설치되어 있는지 확인하세요: addons/install.sh"
    fi

    log_info "사전 요구사항 확인 완료"
}

# 네임스페이스 생성
create_namespace() {
    log_info "네임스페이스 생성 중..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: otel-demo
  labels:
    istio-injection: enabled
EOF
}

# Python 애플리케이션 배포
deploy_python() {
    log_info "Python 애플리케이션 빌드 및 배포 중..."
    cd "$SCRIPT_DIR/python"

    # Docker 이미지 빌드
    log_info "Docker 이미지 빌드: python-otel-demo:latest"
    docker build -t python-otel-demo:latest .

    # Kubernetes에 배포
    log_info "Kubernetes에 배포 중..."
    kubectl apply -f k8s-deployment.yaml

    # Pod 준비 대기
    log_info "Pod 준비 대기 중..."
    kubectl wait --for=condition=ready pod -l app=python-otel-demo -n otel-demo --timeout=120s || true

    log_info "Python 애플리케이션 배포 완료"
}

# Node.js 애플리케이션 배포
deploy_nodejs() {
    log_info "Node.js 애플리케이션 빌드 및 배포 중..."
    cd "$SCRIPT_DIR/nodejs"

    # Docker 이미지 빌드
    log_info "Docker 이미지 빌드: nodejs-otel-demo:latest"
    docker build -t nodejs-otel-demo:latest .

    # Kubernetes에 배포
    log_info "Kubernetes에 배포 중..."
    kubectl apply -f k8s-deployment.yaml

    # Pod 준비 대기
    log_info "Pod 준비 대기 중..."
    kubectl wait --for=condition=ready pod -l app=nodejs-otel-demo -n otel-demo --timeout=120s || true

    log_info "Node.js 애플리케이션 배포 완료"
}

# Java 애플리케이션 배포
deploy_java() {
    log_info "Java 애플리케이션 빌드 및 배포 중..."
    need_cmd mvn

    cd "$SCRIPT_DIR/java"

    # Docker 이미지 빌드
    log_info "Docker 이미지 빌드: java-otel-demo:latest"
    docker build -t java-otel-demo:latest .

    # Kubernetes에 배포
    log_info "Kubernetes에 배포 중..."
    kubectl apply -f k8s-deployment.yaml

    # Pod 준비 대기
    log_info "Pod 준비 대기 중..."
    kubectl wait --for=condition=ready pod -l app=java-otel-demo -n otel-demo --timeout=180s || true

    log_info "Java 애플리케이션 배포 완료"
}

# 배포 상태 확인
check_status() {
    log_info "배포 상태 확인 중..."
    echo ""
    echo "=== Pods ==="
    kubectl get pods -n otel-demo
    echo ""
    echo "=== Services ==="
    kubectl get svc -n otel-demo
    echo ""
    echo "=== Gateways ==="
    kubectl get gateway -n otel-demo
    echo ""
    echo "=== VirtualServices ==="
    kubectl get virtualservice -n otel-demo
}

# 접근 정보 출력
print_access_info() {
    log_info "접근 정보"
    echo ""
    echo "1. Port-Forward를 사용한 접근:"
    echo "   kubectl port-forward -n otel-demo svc/python-otel-demo 5000:80"
    echo "   kubectl port-forward -n otel-demo svc/nodejs-otel-demo 3000:80"
    echo "   kubectl port-forward -n otel-demo svc/java-otel-demo 8080:80"
    echo ""
    echo "2. Ingress Gateway를 사용한 접근 (ISTIO_EXPOSE=on):"
    echo "   http://python-demo.bocopile.io"
    echo "   http://nodejs-demo.bocopile.io"
    echo "   http://java-demo.bocopile.io"
    echo ""
    echo "3. SigNoz에서 확인:"
    echo "   http://signoz.bocopile.io"
    echo ""
    echo "로그 확인:"
    echo "   kubectl logs -n otel-demo -l app=python-otel-demo -f"
    echo "   kubectl logs -n otel-demo -l app=nodejs-otel-demo -f"
    echo "   kubectl logs -n otel-demo -l app=java-otel-demo -f"
}

# 메인 실행
main() {
    local target="${1:-all}"

    log_info "OpenTelemetry Demo 애플리케이션 배포 시작"
    log_info "대상: $target"

    check_prerequisites
    create_namespace

    case "$target" in
        python)
            deploy_python
            ;;
        nodejs)
            deploy_nodejs
            ;;
        java)
            deploy_java
            ;;
        all)
            deploy_python
            deploy_nodejs
            deploy_java
            ;;
        *)
            log_error "알 수 없는 대상: $target"
            log_error "사용법: $0 [python|nodejs|java|all]"
            exit 1
            ;;
    esac

    check_status
    print_access_info

    log_info "배포 완료!"
}

# 스크립트 실행
main "$@"
