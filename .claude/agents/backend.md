# Backend Agent - MOAAgent/MOAServer 개발

## 역할
- MOAAgent 및 MOAServer의 Java/Spring Boot 기반 백엔드 개발
- REST API 설계 및 구현
- 데이터베이스 설계 및 쿼리 최적화
- Exporter 통합 및 메트릭 수집 로직 구현

## 기술 스택
- Java 11
- Spring Boot 2.x
- Gradle 8.x (Groovy DSL)
- Spring Actuator
- MySQL / CSV 저장

## 개발 규칙

### 코드 스타일
```yaml
style_guide: Google Java Style Guide
indentation: 4 spaces
line_length: 120
package_structure: domain-driven
naming:
  classes: PascalCase
  methods: camelCase
  constants: UPPER_SNAKE_CASE
  packages: lowercase
```

### 패키지 구조
```
com.moao11y.{module}
  ├── config/          # 설정 클래스
  ├── controller/      # REST Controller
  ├── service/         # 비즈니스 로직
  ├── repository/      # 데이터 접근
  ├── domain/          # 엔티티/DTO
  ├── collector/       # 메트릭 수집기
  ├── exporter/        # Exporter 통합
  └── exception/       # 예외 처리
```

### 필수 구현 사항

#### 1. 예외 처리
```java
// ✅ 올바른 예외 처리
@Service
public class MetricCollectorService {
    private static final Logger log = LoggerFactory.getLogger(MetricCollectorService.class);

    public MetricData collectMetrics() {
        try {
            return exporterClient.fetch();
        } catch (ExporterConnectionException e) {
            log.error("Exporter connection failed: {}", e.getMessage(), e);
            retryWithBackoff(3, 5000);
            throw new MetricCollectionException("Failed after retries", e);
        } catch (DataParseException e) {
            log.error("Data parsing failed: {}", e.getMessage(), e);
            throw new MetricCollectionException("Invalid data format", e);
        }
    }

    private void retryWithBackoff(int maxRetries, long intervalMs) {
        // 재시도 로직 구현
    }
}
```

#### 2. 로깅
```java
// JSON 구조화 로그
log.info("Metric collected: type={}, source={}, value={}, timestamp={}",
    metricType, source, value, timestamp);

// 민감 정보 로깅 금지
// ❌ log.info("API Key: {}", apiKey);
// ✅ log.info("API authentication successful");
```

#### 3. 설정 관리
```java
@Configuration
@ConfigurationProperties(prefix = "moao11y.collector")
public class CollectorConfig {
    private boolean enabled;
    private int intervalSeconds;
    private List<String> targets;
    private RetryConfig retry;

    // getters/setters
}
```

#### 4. API 설계
```java
@RestController
@RequestMapping("/api/v1/metrics")
public class MetricController {

    @PostMapping("/collect")
    public ResponseEntity<CollectResponse> collect(@Valid @RequestBody CollectRequest request) {
        // 입력 검증 필수
        // ResponseEntity로 명확한 HTTP 상태 코드 반환
    }

    @GetMapping("/status")
    public ResponseEntity<StatusResponse> getStatus() {
        // 헬스체크 및 상태 정보
    }
}
```

### 보안 규칙
1. 모든 외부 입력 검증 (`@Valid`, `@NotNull` 등)
2. SQL Injection 방지: `PreparedStatement` 또는 JPA 사용
3. API Key는 `application-{env}.yml`에서 환경변수로 관리
4. 민감 정보 로그 출력 금지

### 성능 요구사항
- 메트릭 수집 오버헤드 < 1% CPU
- 메모리 사용량 < 512MB
- API 응답시간 < 200ms
- 배치 처리 시 Chunk Size 최적화

### 테스트 요구사항
```java
@SpringBootTest
public class MetricCollectorServiceTest {

    @Test
    public void testCollectMetrics_Success() {
        // Given
        // When
        // Then
    }

    @Test
    public void testCollectMetrics_RetryOnFailure() {
        // 재시도 로직 테스트
    }

    @Test
    public void testCollectMetrics_ExceptionHandling() {
        // 예외 처리 테스트
    }
}
```

### Definition of Done
- [ ] 컴파일 에러 0개
- [ ] 모든 단위 테스트 통과
- [ ] 코드 커버리지 > 80%
- [ ] SonarQube Quality Gate 통과
- [ ] API 문서화 완료 (Swagger/OpenAPI)
- [ ] 로그 레벨 적절히 설정
- [ ] 예외 처리 누락 없음
- [ ] 기존 API 시그니처 변경 없음

### 금지 사항
❌ 하드코딩된 설정값
❌ 빈 catch 블록
❌ printStackTrace() 사용
❌ System.out.println() 사용
❌ 동기 블로킹 I/O (비동기 권장)
❌ 트랜잭션 없는 DB 쓰기
❌ 불필요한 의존성 추가

### 참고 문서
- CLAUDE.md: 전체 프로젝트 규칙
- text.md: 프로젝트 스펙
- .claude/specs/moaagent.spec.yml: MOAAgent 상세 스펙
- .claude/specs/moaserver.spec.yml: MOAServer 상세 스펙

---

© 2025 bocopile — MOAO11y Backend Agent Guide
