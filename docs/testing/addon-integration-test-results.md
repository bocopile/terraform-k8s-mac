# 애드온 통합 테스트 결과

## 개요

grafana-stage 브랜치에 배포된 5개 애드온(MinIO, KEDA, Kyverno, Sloth, Velero)의 통합 테스트 결과입니다.

**테스트 일시**: 2025-11-14
**테스트 환경**:
- Kubernetes 버전: v1.30.14
- 노드 구성: 1 master, 2 workers
- 플랫폼: Multipass (macOS)
- MetalLB IP Pool: 192.168.65.200-192.168.65.250

---

## 테스트 결과 요약

| 애드온 | 백로그 | Pod 상태 | CRD | 핵심 기능 | 상태 |
|--------|--------|----------|-----|-----------|------|
| **MinIO** | TERRAFORM-60 | 1/1 Running | - | LoadBalancer IP 할당, 버킷 생성 | ✅ |
| **KEDA** | TERRAFORM-61 | 3/3 Running | 6개 | Operator 정상, ServiceMonitor 생성 | ✅ |
| **Kyverno** | TERRAFORM-62 | 4/4 Running | 18개 | Admission controller 정상 | ✅ |
| **Sloth** | TERRAFORM-63 | 2/2 Running | 1개 | git-sync, 21개 SLI plugins 로드 | ✅ |
| **Velero** | TERRAFORM-64 | 1/1 Running | 13개 | MinIO S3 연동, BSL Available | ✅ |

---

## 1. MinIO (TERRAFORM-60)

### 목적
S3 호환 오브젝트 스토리지를 로컬 환경에서 제공하여 Loki, Tempo, Velero의 백엔드로 사용

### 테스트 결과

#### Pod 상태
```bash
$ kubectl get pods -n minio
NAME                     READY   STATUS    RESTARTS   AGE
minio-6f9bc48b98-t52qc   1/1     Running   0          19h
```

#### LoadBalancer 서비스
```bash
$ kubectl get svc -n minio
NAME            TYPE           EXTERNAL-IP      PORT(S)
minio           LoadBalancer   192.168.65.205   9000:32178/TCP
minio-console   LoadBalancer   192.168.65.204   9001:30311/TCP
```

✅ **LoadBalancer IP 할당 성공**
- MinIO API: `192.168.65.205:9000`
- MinIO Console (WebUI): `192.168.65.204:9001`

#### 버킷 생성 확인
```bash
$ kubectl exec -n minio deployment/minio -- mc ls minio/
[2025-11-13 05:18:05 UTC]     0B loki-data/
[2025-11-13 05:18:05 UTC]     0B tempo-data/
[2025-11-13 06:30:14 UTC]     0B velero-backups/
```

✅ **3개 버킷 자동 생성 성공**

#### 발견된 이슈
⚠️ ServiceMonitor 미생성 - MinIO Helm chart가 ServiceMonitor CRD를 직접 생성하지 않는 것으로 확인됨

### 완료 조건 검증
- [x] MinIO Pod Running 상태
- [x] LoadBalancer IP 할당
- [x] 웹 콘솔 접근 가능
- [x] 버킷 자동 생성
- [ ] ServiceMonitor (차트 미지원)

---

## 2. KEDA (TERRAFORM-61)

### 목적
이벤트 기반 오토스케일링을 위한 Kubernetes 확장

### 테스트 결과

#### Pod 상태
```bash
$ kubectl get pods -n keda
NAME                                               READY   STATUS    RESTARTS
keda-admission-webhooks-7448687bd5-wc424           1/1     Running   0
keda-operator-d5bd8f887-n8j46                      1/1     Running   1
keda-operator-metrics-apiserver-848dfd57ff-dt7jd   1/1     Running   0
```

✅ **3개 컴포넌트 정상 실행**

#### CRD 설치
```bash
$ kubectl get crd | grep keda
cloudeventsources.eventing.keda.sh
clustercloudeventsources.eventing.keda.sh
clustertriggerauthentications.keda.sh
scaledjobs.keda.sh
scaledobjects.keda.sh
triggerauthentications.keda.sh
```

✅ **6개 CRD 정상 설치**

#### ServiceMonitor
```bash
$ kubectl get servicemonitor -n keda
NAME                              AGE
keda-admission-webhooks           18h
keda-operator                     18h
keda-operator-metrics-apiserver   18h
```

✅ **Prometheus 메트릭 수집 준비 완료**

#### Operator 로그
```
{"level":"info","ts":"2025-11-13T06:41:40Z","logger":"grpc_server","msg":"Starting Metrics Service gRPC Server","address":":9666"}
```

✅ **Operator 정상 동작, gRPC 서버 실행 중**

### 완료 조건 검증
- [x] KEDA CRD 설치
- [x] Operator, Webhook, Metrics API Server 실행
- [x] ServiceMonitor 생성
- [x] Prometheus 메트릭 노출

---

## 3. Kyverno (TERRAFORM-62)

### 목적
Kubernetes 정책 엔진 - 보안, 규정 준수, 모범 사례 자동 적용

### 테스트 결과

#### Pod 상태
```bash
$ kubectl get pods -n kyverno
NAME                                             READY   STATUS    RESTARTS
kyverno-admission-controller-75dbc56f6b-fbps2    1/1     Running   0
kyverno-background-controller-768fb94b64-82d4k   1/1     Running   0
kyverno-cleanup-controller-86b9cbbd79-4qtg2      1/1     Running   0
kyverno-reports-controller-6984fcf648-gtt9v      1/1     Running   0
```

✅ **4개 컨트롤러 정상 실행**

#### CRD 설치
```bash
$ kubectl get crd | grep kyverno | wc -l
18
```

✅ **18개 CRD 정상 설치** (ClusterPolicy, Policy, PolicyException 등)

#### Admission Controller 로그
```
starting controller name=admissionpolicy-generator workers=2
starting controller name=webhook-controller workers=2
starting controller name=certmanager-controller workers=1
```

✅ **Webhook 및 정책 컨트롤러 정상 시작**

### 완료 조건 검증
- [x] Kyverno CRD 설치
- [x] 4개 컨트롤러 실행
- [x] Admission Webhook 구성
- [x] 메트릭 엔드포인트 노출

---

## 4. Sloth (TERRAFORM-63)

### 목적
SLO(Service Level Objective) 자동 생성 및 관리

### 테스트 결과

#### Pod 상태
```bash
$ kubectl get pods -n monitoring | grep sloth
sloth-5fd5dc6895-nhlrs   2/2   Running   6 (36m ago)   18h
```

✅ **2개 컨테이너 정상 실행** (sloth, git-sync-plugins)

#### 컨테이너 확인
```bash
$ kubectl get pod -n monitoring sloth-xxx -o jsonpath='{.spec.containers[*].name}'
sloth git-sync-plugins
```

✅ **git-sync sidecar 컨테이너 정상 추가**

#### Sloth 로그
```
INFO Plugins loaded sli-plugins=21 slo-plugins=11 version=v0.15.0
INFO Hot-reload triggered from http webhook
```

✅ **21개 SLI plugins 로드 성공** (이전 0개에서 21개로 증가)

#### git-sync 로그
```
{"level":0,"msg":"updated successfully","ref":"main","remote":"8fe474063dbccf340a661493785b195373832b5b","syncCount":1}
{"level":0,"msg":"sending webhook","hash":"8fe474063dbccf340a661493785b195373832b5b","url":"http://localhost:8082/-/reload"}
```

✅ **git-sync가 sloth-common-sli-plugins 저장소를 성공적으로 동기화하고 hot-reload 트리거**

#### CRD 설치
```bash
$ kubectl get crd | grep sloth
prometheusservicelevels.sloth.slok.dev
```

✅ **PrometheusServiceLevel CRD 정상 설치**

### 완료 조건 검증
- [x] Sloth v0.15.0 실행
- [x] git-sync sidecar 정상 동작
- [x] 21개 SLI plugins 로드
- [x] Hot-reload 기능 동작
- [x] PrometheusServiceLevel CRD 설치

---

## 5. Velero (TERRAFORM-64)

### 목적
Kubernetes 클러스터 백업 및 복원

### 테스트 결과

#### Pod 상태
```bash
$ kubectl get pods -n velero
NAME                     READY   STATUS    RESTARTS   AGE
velero-5b67777f9-7xrzb   1/1     Running   0          18h
```

✅ **Velero Pod 정상 실행**

#### BackupStorageLocation
```bash
$ kubectl get backupstoragelocation -n velero
NAME      PHASE       LAST VALIDATED   AGE   DEFAULT
default   Available   31s              18h   true
```

✅ **MinIO S3 백엔드 연동 성공** (Phase: Available)

#### VolumeSnapshotLocation
```bash
$ kubectl get volumesnapshotlocation -n velero
NAME      AGE
default   18h
```

✅ **볼륨 스냅샷 위치 구성 완료**

#### Velero 로그
```
level=info msg="BackupStorageLocations is valid, marking as available" backup-storage-location=velero/default
```

✅ **BackupStorageLocation 검증 성공**

#### MinIO 버킷 확인
```bash
$ kubectl exec -n minio deployment/minio -- mc ls minio/
[2025-11-13 06:30:14 UTC]     0B velero-backups/
```

✅ **velero-backups 버킷 생성 확인**

#### CRD 설치
```bash
$ kubectl get crd | grep velero | wc -l
13
```

✅ **13개 CRD 정상 설치**

### 발견된 이슈
⚠️ **Node-agent DaemonSet 미생성** - `nodeAgent.enabled: true`로 설정했으나 DaemonSet이 생성되지 않음. 파일 레벨 백업을 사용하려면 추가 설정 필요.

### 완료 조건 검증
- [x] Velero Pod 실행
- [x] BackupStorageLocation Available
- [x] MinIO S3 연동 확인
- [x] VolumeSnapshotLocation 구성
- [ ] Node-agent DaemonSet (추가 설정 필요)

---

## 종합 평가

### 성공 사항
1. ✅ **모든 애드온 정상 배포** - 5개 애드온 모두 Pod Running 상태
2. ✅ **CRD 정상 설치** - 총 38개 CRD 설치 완료
3. ✅ **LoadBalancer IP 자동 할당** - MetalLB를 통한 IP 할당 성공
4. ✅ **git-sync 플러그인 로드** - Sloth에서 21개 SLI plugins 로드 성공
5. ✅ **S3 백엔드 연동** - MinIO와 Velero 정상 연동

### 발견된 문제
1. ⚠️ **MinIO ServiceMonitor 미생성** - Helm chart 미지원 (수동 생성 가능)
2. ⚠️ **Velero Node-agent 미생성** - 추가 설정 확인 필요

### 다음 단계
1. 각 애드온별 사용 예시 작성 (ScaledObject, ClusterPolicy, PrometheusServiceLevel 등)
2. 실제 워크로드에 대한 정책 및 SLO 적용 테스트
3. Velero 백업/복원 시나리오 테스트
4. 트러블슈팅 가이드 작성

---

## 참고 정보

### Git 커밋
- grafana-stage: f93e421
- TERRAFORM-60: 9b50b8e (MinIO LoadBalancer 수정)
- TERRAFORM-63: 47c9bfe (Sloth git-sync 플러그인 연동)

### 관련 문서
- [MinIO 사용 가이드](../addons/minio-guide.md)
- [KEDA 사용 가이드](../addons/keda-guide.md)
- [Kyverno 사용 가이드](../addons/kyverno-guide.md)
- [Sloth 사용 가이드](../addons/sloth-guide.md)
- [Velero 사용 가이드](../addons/velero-guide.md)
- [트러블슈팅 가이드](../troubleshooting/addons-troubleshooting.md)
