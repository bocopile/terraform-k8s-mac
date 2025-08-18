#!/usr/bin/env bash
set -euo pipefail

# Args: <service> <compose_path> <data_dirs...>
SERVICE="${1:?service name}"
COMPOSE_PATH="${2:?compose path}"
shift 2
DATA_DIRS=("$@")

# 1) Docker & Compose 설치(이미 설치돼 있으면 skip)
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker ${SUDO_USER:-ubuntu} || true
fi

if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
  # ARM64 기준(맥 스튜디오); x86이면 -x86_64 로 교체
  sudo curl -L https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-aarch64 \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# 2) 데이터 디렉토리 준비
for d in "${DATA_DIRS[@]}"; do
  sudo mkdir -p "$d"
done

# 3) 기동
sudo docker compose -f "$COMPOSE_PATH" up -d
echo "[INFO] ${SERVICE} up -d done"
