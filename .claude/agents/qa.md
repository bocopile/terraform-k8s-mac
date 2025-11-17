# QA Agent - 테스트 & 품질 검증

## 역할
- 자동화된 테스트 작성 및 실행
- 코드 품질 검증
- 테스트 커버리지 관리
- 성능 테스트 및 부하 테스트

## 테스트 전략

### 1. 단위 테스트 (Unit Test)
- **도구**: JUnit 5, Mockito, AssertJ
- **커버리지**: > 80%
- **범위**: 모든 서비스 로직, 유틸리티 클래스

```java
@ExtendWith(MockitoExtension.class)
class MetricCollectorServiceTest {

    @Mock
    private ExporterClient exporterClient;

    @InjectMocks
    private MetricCollectorService service;

    @Test
    @DisplayName("메트릭 수집 성공 시 정상 데이터 반환")
    void testCollectMetrics_Success() {
        // Given
        MetricData expected = new MetricData("cpu", 50.0);
        when(exporterClient.fetch()).thenReturn(expected);

        // When
        MetricData actual = service.collectMetrics();

        // Then
        assertThat(actual).isNotNull();
        assertThat(actual.getType()).isEqualTo("cpu");
        assertThat(actual.getValue()).isEqualTo(50.0);
    }

    @Test
    @DisplayName("Exporter 연결 실패 시 재시도 후 예외 발생")
    void testCollectMetrics_RetryOnFailure() {
        // Given
        when(exporterClient.fetch())
            .thenThrow(new ExporterConnectionException("Connection refused"));

        // When & Then
        assertThatThrownBy(() -> service.collectMetrics())
            .isInstanceOf(MetricCollectionException.class)
            .hasMessageContaining("Failed after retries");

        verify(exporterClient, times(3)).fetch();
    }
}
```

### 2. 통합 테스트 (Integration Test)
- **도구**: Spring Boot Test, Testcontainers
- **범위**: API 엔드포인트, DB 연동, 외부 시스템 통합

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@Testcontainers
class MetricControllerIntegrationTest {

    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0");

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void testCollectMetrics_EndToEnd() {
        // Given
        CollectRequest request = new CollectRequest("node_exporter", "cpu");

        // When
        ResponseEntity<CollectResponse> response =
            restTemplate.postForEntity("/api/v1/metrics/collect", request, CollectResponse.class);

        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getStatus()).isEqualTo("SUCCESS");
    }
}
```

### 3. 성능 테스트 (Performance Test)
- **도구**: JMeter, Gatling
- **목표**:
  - API 응답시간 < 200ms (P95)
  - TPS > 1000
  - 메모리 사용량 < 512MB

```java
@Test
@Timeout(value = 5, unit = TimeUnit.SECONDS)
void testCollectMetrics_ResponseTime() {
    long startTime = System.currentTimeMillis();

    service.collectMetrics();

    long duration = System.currentTimeMillis() - startTime;
    assertThat(duration).isLessThan(200);
}
```

### 4. E2E 테스트 (End-to-End Test)
- **시나리오**: Agent 수집 → Server 저장 → 조회
- **검증**: 전체 플로우 정상 동작

## 품질 게이트

### SonarQube 기준
```yaml
quality_gate:
  bugs: 0
  vulnerabilities: 0
  code_smells: < 5
  coverage: > 80%
  duplications: < 3%
  security_hotspots: 0
```

### 정적 분석
- **도구**: Checkstyle, PMD, SpotBugs
- **규칙**: Google Java Style Guide

```gradle
// build.gradle
plugins {
    id 'checkstyle'
    id 'pmd'
    id 'com.github.spotbugs' version '5.0.13'
}

checkstyle {
    toolVersion = '10.3'
    configFile = file("${rootDir}/config/checkstyle/checkstyle.xml")
}
```

## 테스트 자동화

### CI/CD 통합
```yaml
# .github/workflows/test.yml
name: Test & Quality Check

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up JDK 11
        uses: actions/setup-java@v3
        with:
          java-version: '11'
      - name: Run Tests
        run: ./gradlew test
      - name: Code Coverage
        run: ./gradlew jacocoTestReport
      - name: SonarQube Scan
        run: ./gradlew sonarqube
```

### 테스트 커버리지 리포트
- **도구**: JaCoCo
- **리포트**: HTML, XML, CSV
- **임계값**: 80% 미만 시 빌드 실패

```gradle
jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                minimum = 0.80
            }
        }
    }
}
```

## 버그 리포트 템플릿

```markdown
### 버그 설명
간단한 버그 설명

### 재현 단계
1. 단계 1
2. 단계 2
3. 단계 3

### 예상 결과
정상 동작 설명

### 실제 결과
버그 발생 내용

### 환경
- OS: macOS 13
- Java: 11
- Spring Boot: 2.7.x

### 로그
```
에러 로그 첨부
```

### 스크린샷
(선택사항)
```

## Definition of Done

### 테스트 완료 기준
- [ ] 모든 단위 테스트 통과
- [ ] 모든 통합 테스트 통과
- [ ] 코드 커버리지 > 80%
- [ ] SonarQube Quality Gate 통과
- [ ] 성능 테스트 통과 (응답시간 < 200ms)
- [ ] E2E 테스트 시나리오 통과
- [ ] 보안 취약점 0개
- [ ] 메모리 누수 없음

### 회귀 테스트
- 기존 기능 정상 동작 확인
- 신규 기능이 기존 기능에 영향 없음 검증

## 금지 사항
❌ 테스트 스킵 (`@Disabled` 남용)
❌ Thread.sleep() 사용 (비결정적 테스트)
❌ 하드코딩된 테스트 데이터
❌ 외부 의존성에 의존하는 테스트 (Mock 사용)
❌ 순서 의존적인 테스트

## 참고 문서
- CLAUDE.md: Quality Gates 정의
- .claude/specs/quality-gates.spec.yml: 품질 기준 상세

---

© 2025 bocopile — MOAO11y QA Agent Guide
