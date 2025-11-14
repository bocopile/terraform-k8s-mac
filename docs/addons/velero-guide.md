# Velero - Kubernetes 백업 및 복원

## 개요

Velero는 **Kubernetes 클러스터 백업 및 복원**을 위한 오픈소스 도구입니다.
재해 복구(DR), 클러스터 마이그레이션, 개발/테스트 환경 복제 등에 활용됩니다.

**주요 특징:**
- **전체 클러스터 또는 네임스페이스 백업**
- **PersistentVolume 스냅샷 지원**
- **스케줄 백업** (Cron 형식)
- **선택적 복원** (특정 리소스만)
- **S3 호환 스토리지 백엔드** (MinIO, AWS S3, GCS 등)
- **플러그인 시스템** (CSI, AWS, Azure, GCP 등)

---

## 설치

### Helm으로 설치

```bash
# Velero Helm 리포지토리 추가
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# Velero 설치 (MinIO 백엔드)
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  -f addons/values/backup/velero-values.yaml

# 설치 확인
kubectl get pods -n velero
```

### 상태 확인

```bash
# Velero Pod 확인
kubectl get pods -n velero

# Node-Agent DaemonSet 확인 (파일 레벨 백업용)
kubectl get daemonset -n velero

# BackupStorageLocation 확인
velero backup-location get

# VolumeSnapshotLocation 확인
velero snapshot-location get
```

**예상 출력:**
```
NAME                     READY   STATUS    RESTARTS   AGE
velero-xxxxxxxxxx-xxxxx  1/1     Running   0          5m
node-agent-xxxxx         1/1     Running   0          5m
node-agent-yyyyy         1/1     Running   0          5m
```

---

## Velero CLI 설치

### Mac

```bash
# Homebrew로 설치
brew install velero

# 버전 확인
velero version
```

### Linux

```bash
# 최신 버전 다운로드
wget https://github.com/vmware-tanzu/velero/releases/download/v1.15.0/velero-v1.15.0-linux-amd64.tar.gz
tar -xvf velero-v1.15.0-linux-amd64.tar.gz
sudo mv velero-v1.15.0-linux-amd64/velero /usr/local/bin/

# 버전 확인
velero version
```

---

## 핵심 사용법

### 1. 백업 생성

#### 전체 클러스터 백업

```bash
# 모든 리소스 백업
velero backup create full-backup

# 백업 상태 확인
velero backup describe full-backup

# 백업 로그 확인
velero backup logs full-backup
```

#### 특정 네임스페이스 백업

```bash
# 단일 네임스페이스
velero backup create default-backup --include-namespaces default

# 여러 네임스페이스
velero backup create app-backup --include-namespaces default,production,staging
```

#### 라벨 기반 백업

```bash
# 특정 라벨이 있는 리소스만 백업
velero backup create app-backup --selector app=nginx

# 여러 라벨
velero backup create app-backup --selector app=nginx,tier=frontend
```

#### 리소스 타입 지정

```bash
# Deployment와 Service만 백업
velero backup create deploy-svc-backup \
  --include-resources deployments,services

# ConfigMap과 Secret 제외
velero backup create no-config-backup \
  --exclude-resources configmaps,secrets
```

#### TTL (Time To Live) 설정

```bash
# 7일 후 자동 삭제
velero backup create temp-backup --ttl 168h

# 30일 후 자동 삭제
velero backup create monthly-backup --ttl 720h
```

### 2. 백업 목록 및 상태

```bash
# 백업 목록
velero backup get

# 백업 상세 정보
velero backup describe full-backup

# 백업 로그
velero backup logs full-backup

# 백업 삭제
velero backup delete full-backup
```

**백업 상태:**
- `New`: 백업 시작
- `InProgress`: 진행 중
- `Completed`: 완료
- `PartiallyFailed`: 일부 실패
- `Failed`: 실패

### 3. 복원 (Restore)

#### 전체 복원

```bash
# 최신 백업에서 복원
velero restore create --from-backup full-backup

# 복원 상태 확인
velero restore describe <restore-name>

# 복원 로그
velero restore logs <restore-name>
```

#### 특정 네임스페이스만 복원

```bash
# default 네임스페이스만 복원
velero restore create --from-backup full-backup \
  --include-namespaces default

# 네임스페이스 이름 변경하여 복원
velero restore create --from-backup production-backup \
  --namespace-mappings production:staging
```

#### 선택적 복원

```bash
# 특정 리소스만 복원
velero restore create --from-backup full-backup \
  --include-resources deployments,services

# 라벨 기반 복원
velero restore create --from-backup full-backup \
  --selector app=nginx
```

#### 기존 리소스 보존

```bash
# 기존 리소스가 있으면 건너뜀
velero restore create --from-backup full-backup \
  --preserve-nodeports

# 기존 ServiceAccount 유지
velero restore create --from-backup full-backup \
  --existing-resource-policy preserve
```

### 4. 스케줄 백업 (자동 백업)

#### Daily 백업

```bash
# 매일 새벽 2시 백업 (7일 보관)
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --ttl 168h

# 스케줄 목록
velero schedule get

# 스케줄 상세 정보
velero schedule describe daily-backup
```

#### Weekly 백업

```bash
# 매주 일요일 새벽 3시 백업 (30일 보관)
velero schedule create weekly-backup \
  --schedule="0 3 * * 0" \
  --ttl 720h \
  --include-namespaces production
```

#### Hourly 백업

```bash
# 매시간 정각 백업 (24시간 보관)
velero schedule create hourly-backup \
  --schedule="0 * * * *" \
  --ttl 24h \
  --include-namespaces default
```

#### 스케줄 일시 중지/재개

```bash
# 일시 중지
velero schedule pause daily-backup

# 재개
velero schedule unpause daily-backup

# 스케줄 삭제
velero schedule delete daily-backup
```

---

## MinIO 백엔드 설정

본 프로젝트는 **MinIO를 S3 호환 백엔드**로 사용합니다.

### MinIO Bucket 확인

```bash
# MinIO Client 설치 (Mac)
brew install minio/stable/mc

# MinIO 접속 설정
mc alias set myminio http://minio.bocopile.io:9000 minioadmin minioadmin123

# Velero Bucket 확인
mc ls myminio/velero-backups

# Bucket 내용 확인
mc tree myminio/velero-backups
```

### BackupStorageLocation 확인

```bash
# BackupStorageLocation 상태
velero backup-location get

# 상세 정보
kubectl get backupstoragelocation -n velero default -o yaml
```

**출력 예시:**
```
NAME      PROVIDER   BUCKET           ACCESS MODE
default   aws        velero-backups   ReadWrite
```

---

## PersistentVolume 백업

Velero는 두 가지 방식으로 PV를 백업합니다:

### 1. 파일 레벨 백업 (File-Level Backup)

**Node-Agent**를 사용한 파일 복사 방식:

```bash
# PV를 포함한 백업
velero backup create pv-backup \
  --include-namespaces default \
  --default-volumes-to-fs-backup

# 복원
velero restore create --from-backup pv-backup
```

**특정 PVC만 백업:**
```yaml
# Pod에 annotation 추가
apiVersion: v1
kind: Pod
metadata:
  name: app
  annotations:
    backup.velero.io/backup-volumes: data-volume  # PVC 이름
spec:
  volumes:
    - name: data-volume
      persistentVolumeClaim:
        claimName: app-data
```

### 2. 스냅샷 백업 (Snapshot Backup)

CSI 또는 클라우드 제공자의 스냅샷 기능 사용:

```bash
# CSI 스냅샷 포함 백업
velero backup create snapshot-backup \
  --include-namespaces default \
  --snapshot-volumes
```

---

## 주요 명령어

### 백업 관리

```bash
# 백업 생성
velero backup create <name> [options]

# 백업 목록
velero backup get

# 백업 상세 정보
velero backup describe <name>

# 백업 로그
velero backup logs <name>

# 백업 삭제
velero backup delete <name>

# 모든 백업 삭제
velero backup delete --all
```

### 복원 관리

```bash
# 복원 생성
velero restore create --from-backup <backup-name> [options]

# 복원 목록
velero restore get

# 복원 상태
velero restore describe <name>

# 복원 로그
velero restore logs <name>

# 복원 삭제
velero restore delete <name>
```

### 스케줄 관리

```bash
# 스케줄 생성
velero schedule create <name> --schedule="<cron>" [options]

# 스케줄 목록
velero schedule get

# 스케줄 상세 정보
velero schedule describe <name>

# 스케줄 일시 중지
velero schedule pause <name>

# 스케줄 재개
velero schedule unpause <name>

# 스케줄 삭제
velero schedule delete <name>
```

### 정보 확인

```bash
# Velero 서버 상태
velero version

# BackupStorageLocation
velero backup-location get

# VolumeSnapshotLocation
velero snapshot-location get

# 플러그인 목록
velero plugin get
```

---

## 실전 시나리오

### 시나리오 1: 재해 복구 (Disaster Recovery)

```bash
# 1. 정기 백업 설정 (매일 새벽 2시)
velero schedule create disaster-recovery \
  --schedule="0 2 * * *" \
  --ttl 720h \
  --include-namespaces production

# 2. 장애 발생 시 최신 백업 확인
velero backup get | grep disaster-recovery

# 3. 복원
velero restore create dr-restore \
  --from-backup disaster-recovery-20250114020000

# 4. 복원 상태 확인
velero restore describe dr-restore

# 5. 애플리케이션 검증
kubectl get pods -n production
```

### 시나리오 2: 클러스터 마이그레이션

```bash
# --- 소스 클러스터 ---
# 1. 전체 백업
velero backup create migration-backup

# 2. 백업 완료 확인
velero backup describe migration-backup

# --- 대상 클러스터 ---
# 3. Velero 설치 (동일한 MinIO 백엔드 사용)
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  -f velero-values.yaml

# 4. 백업 목록 확인
velero backup get

# 5. 복원
velero restore create --from-backup migration-backup

# 6. 검증
kubectl get all -A
```

### 시나리오 3: 개발 환경 복제

```bash
# 1. Production 백업
velero backup create prod-snapshot \
  --include-namespaces production

# 2. Staging 네임스페이스로 복원
velero restore create staging-clone \
  --from-backup prod-snapshot \
  --namespace-mappings production:staging

# 3. ConfigMap/Secret 재설정 (필요 시)
kubectl edit configmap -n staging
```

---

## 모니터링 및 알림

### Prometheus 메트릭

Velero는 Prometheus 메트릭을 제공합니다:

```bash
# 메트릭 확인
kubectl port-forward -n velero svc/velero 8085:8085
curl http://localhost:8085/metrics
```

**주요 메트릭:**
- `velero_backup_total`: 총 백업 수
- `velero_backup_success_total`: 성공한 백업 수
- `velero_backup_failure_total`: 실패한 백업 수
- `velero_restore_total`: 총 복원 수
- `velero_backup_duration_seconds`: 백업 소요 시간

### Grafana 대시보드

1. Grafana 접속: http://grafana.bocopile.io
2. Dashboards → Import
3. Dashboard ID: **11055** (Velero Stats)
4. Prometheus 데이터소스 선택

---

## 트러블슈팅

### 백업이 `PartiallyFailed` 상태

```bash
# 1. 백업 로그 확인
velero backup logs <backup-name>

# 2. 실패한 리소스 확인
velero backup describe <backup-name> --details

# 3. 특정 리소스 제외 후 재시도
velero backup create retry-backup \
  --exclude-resources <failed-resource-type>
```

### BackupStorageLocation `Unavailable`

```bash
# 1. BackupStorageLocation 상태 확인
velero backup-location get

# 2. MinIO 연결 테스트
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://minio.minio.svc.cluster.local:9000

# 3. Credentials 확인
kubectl get secret -n velero cloud-credentials -o yaml

# 4. BackupStorageLocation 재설정
kubectl edit backupstoragelocation -n velero default
```

### Node-Agent DaemonSet 실행 안 됨

```bash
# 1. Node-Agent Pod 상태 확인
kubectl get pods -n velero -l name=node-agent

# 2. Node-Agent 로그 확인
kubectl logs -n velero -l name=node-agent

# 3. Privileged 권한 확인
kubectl get daemonset -n velero node-agent -o yaml | grep privileged

# 4. hostPath 확인
kubectl describe daemonset -n velero node-agent
```

### PV 복원 실패

```bash
# 1. PVC 상태 확인
kubectl get pvc -A

# 2. StorageClass 확인
kubectl get storageclass

# 3. 파일 레벨 백업 강제 사용
velero backup create pv-backup \
  --default-volumes-to-fs-backup
```

---

## 모범 사례

### 1. 백업 전략

- **3-2-1 Rule:**
  - 3개의 복사본
  - 2개의 다른 미디어
  - 1개는 오프사이트 (다른 리전/클라우드)
- **정기 백업:**
  - Daily: 7일 보관
  - Weekly: 30일 보관
  - Monthly: 1년 보관

### 2. 백업 범위

- **전체 백업:** 주 1회
- **중요 네임스페이스:** 일 1회
- **개발 환경:** 필요 시

### 3. 복원 테스트

- **월 1회 복원 테스트** (별도 네임스페이스)
- **재해 복구 훈련** (분기 1회)

### 4. 보안

- **Credentials 암호화:**
  ```bash
  kubectl create secret generic cloud-credentials \
    --from-file=cloud=./credentials-velero \
    -n velero
  ```
- **RBAC 제한:**
  ```bash
  # 백업만 허용
  kubectl create rolebinding velero-backup-only \
    --clusterrole=velero:backup-only \
    --user=backup-user
  ```

### 5. 모니터링

- **백업 성공률 추적** (Prometheus + Grafana)
- **실패 알림 설정** (Alertmanager)
- **스토리지 용량 모니터링** (MinIO)

---

## 참고 자료

- Velero 공식 문서: https://velero.io/docs/
- Velero GitHub: https://github.com/vmware-tanzu/velero
- 플러그인 목록: https://velero.io/plugins/
- Grafana 대시보드: https://grafana.com/grafana/dashboards/11055
- Disaster Recovery Guide: https://velero.io/docs/main/disaster-case/
