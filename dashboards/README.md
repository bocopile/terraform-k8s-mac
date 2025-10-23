# SigNoz Dashboards

이 디렉토리는 SigNoz 대시보드 JSON 파일을 포함합니다.

## 사용 방법

### 대시보드 Import
1. SigNoz UI 접속: `http://signoz.bocopile.io`
2. **Dashboards** 메뉴 → **Import** 클릭
3. JSON 파일 업로드
4. 대시보드 이름 확인 및 저장

### 대시보드 Export
1. SigNoz UI에서 대시보드 선택
2. **Settings** → **Export** 클릭
3. JSON 파일 다운로드
4. 이 디렉토리에 저장

```bash
# 저장 위치
cp ~/Downloads/dashboard-export.json dashboards/signoz/my-dashboard.json

# Git에 커밋
git add dashboards/
git commit -m "feat: Add new dashboard"
```

## 대시보드 목록

### Infrastructure Metrics
- 파일: `infrastructure-metrics.json`
- 설명: Kubernetes 클러스터 인프라 리소스 모니터링
- 패널: Node CPU, Memory, Disk, Pod 상태

### Application Logs
- 파일: `application-logs.json`
- 설명: 애플리케이션 로그 분석 및 에러 추적
- 패널: Error logs, Log levels, Top errors

### Distributed Tracing
- 파일: `distributed-tracing.json`
- 설명: 분산 트레이싱 및 성능 분석
- 패널: Service map, Latency, Error rate

### Unified Observability
- 파일: `unified-observability.json`
- 설명: Metrics, Logs, Traces 통합 대시보드
- 패널: 전체 시스템 상태 한눈에 보기

## 주의사항

- 대시보드를 수정한 후 반드시 Export하여 Git에 저장
- 대시보드 ID는 Import 시 자동 생성되므로 JSON에서 제거
- 환경별로 다른 값(endpoint 등)은 변수로 처리

## 참고 자료

- [SigNoz Dashboard Documentation](https://signoz.io/docs/userguide/manage-dashboards/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
