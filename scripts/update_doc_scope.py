#!/usr/bin/env python3
"""
Update TERRAFORM-65 scope to include Sprint 1 & 2 (8 addons)
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from jira_client import JiraClient

def main():
    client = JiraClient()

    comment = """## 📝 문서화 범위 업데이트

Sprint 1과 Sprint 2의 **전체 8개 애드온**을 문서화하도록 범위를 확대합니다.

### Sprint 1 (ID: 133) - 3개 애드온
1. **TERRAFORM-57**: Fluent Bit - 로그 수집 및 전송
2. **TERRAFORM-58**: Grafana Tempo - 분산 트레이싱
3. **TERRAFORM-59**: cert-manager - TLS 인증서 관리

### Sprint 2 (ID: 236) - 5개 애드온
4. **TERRAFORM-60**: MinIO - S3 호환 오브젝트 스토리지
5. **TERRAFORM-61**: KEDA - 이벤트 기반 오토스케일링
6. **TERRAFORM-62**: Kyverno - 정책 엔진
7. **TERRAFORM-63**: Sloth - SLO 자동화
8. **TERRAFORM-64**: Velero - 백업 및 복원

### 작성할 문서
- [x] 통합 테스트 결과 문서 (8개 애드온 포함)
- [ ] Sprint 1: Fluent Bit 사용 가이드
- [ ] Sprint 1: Tempo 사용 가이드
- [ ] Sprint 1: cert-manager 사용 가이드
- [ ] Sprint 2: MinIO 사용 가이드
- [ ] Sprint 2: KEDA 사용 가이드
- [ ] Sprint 2: Kyverno 사용 가이드
- [ ] Sprint 2: Sloth 사용 가이드
- [ ] Sprint 2: Velero 사용 가이드
- [ ] 트러블슈팅 가이드 (8개 애드온)
"""

    print("TERRAFORM-65에 범위 업데이트 댓글 추가 중...")
    success = client.add_comment("TERRAFORM-65", comment)

    if success:
        print("\n✅ 문서화 범위가 8개 애드온으로 확대되었습니다.")
        return 0
    else:
        print("\n❌ 댓글 추가 실패")
        return 1

if __name__ == "__main__":
    sys.exit(main())
