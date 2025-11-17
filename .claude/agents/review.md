# Review Agent - 코드 리뷰 & 보안

## 역할
- 코드 품질 검토
- 보안 취약점 분석
- 성능 최적화 제안
- 설계 패턴 검증

## 리뷰 체크리스트

### 1. 코드 품질

#### 가독성
- [ ] 의미 있는 변수/메서드명 사용
- [ ] 적절한 주석 (Why, not What)
- [ ] 복잡도 낮은 메서드 (Cyclomatic Complexity < 10)
- [ ] 중복 코드 제거 (DRY 원칙)

```java
// ❌ 나쁜 예
public void p(String d) {
    // d를 처리
}

// ✅ 좋은 예
public void processMetricData(String metricData) {
    // 메트릭 데이터를 파싱하고 저장합니다
}
```

#### SOLID 원칙
- [ ] Single Responsibility: 단일 책임
- [ ] Open/Closed: 확장에는 열려있고 수정에는 닫혀있음
- [ ] Liskov Substitution: 하위 타입 치환 가능
- [ ] Interface Segregation: 인터페이스 분리
- [ ] Dependency Inversion: 의존성 역전

```java
// ✅ 단일 책임 원칙
public class MetricCollector {
    // 수집만 담당
    public MetricData collect() { }
}

public class MetricSender {
    // 전송만 담당
    public void send(MetricData data) { }
}

public class MetricStorage {
    // 저장만 담당
    public void save(MetricData data) { }
}
```

#### 디자인 패턴
- [ ] 적절한 패턴 사용 (Strategy, Factory, Observer 등)
- [ ] 과도한 패턴 사용 지양
- [ ] 상황에 맞는 패턴 선택

```java
// ✅ Strategy Pattern 예시
public interface CollectorStrategy {
    MetricData collect();
}

public class NodeExporterCollector implements CollectorStrategy {
    @Override
    public MetricData collect() {
        // Node Exporter 수집 로직
    }
}

public class RabbitMQExporterCollector implements CollectorStrategy {
    @Override
    public MetricData collect() {
        // RabbitMQ Exporter 수집 로직
    }
}
```

### 2. 보안

#### 입력 검증
```java
// ✅ 모든 외부 입력 검증
@PostMapping("/collect")
public ResponseEntity<CollectResponse> collect(@Valid @RequestBody CollectRequest request) {
    if (request.getSource() == null || request.getSource().isBlank()) {
        throw new IllegalArgumentException("Source cannot be null or empty");
    }
    // ...
}
```

#### SQL Injection 방지
```java
// ❌ 절대 금지
String sql = "SELECT * FROM metrics WHERE type = '" + type + "'";

// ✅ PreparedStatement 사용
String sql = "SELECT * FROM metrics WHERE type = ?";
PreparedStatement pstmt = conn.prepareStatement(sql);
pstmt.setString(1, type);

// ✅ JPA 사용
@Query("SELECT m FROM Metric m WHERE m.type = :type")
List<Metric> findByType(@Param("type") String type);
```

#### 민감 정보 관리
```java
// ❌ 하드코딩 금지
private static final String API_KEY = "sk-1234567890";

// ✅ 환경변수 사용
@Value("${moao11y.api.key}")
private String apiKey;

// ✅ 로그에서 민감 정보 제거
log.info("API request completed"); // ✅
log.info("API Key: {}", apiKey);   // ❌
```

#### 인증/인가
```java
// ✅ Spring Security 설정
@Configuration
@EnableWebSecurity
public class SecurityConfig extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .authorizeRequests()
            .antMatchers("/api/v1/metrics/**").authenticated()
            .and()
            .httpBasic();
    }
}
```

### 3. 성능

#### 효율적인 알고리즘
```java
// ❌ O(n²) - 비효율
for (Metric m1 : metrics) {
    for (Metric m2 : metrics) {
        if (m1.getId().equals(m2.getId())) {
            // ...
        }
    }
}

// ✅ O(n) - HashMap 사용
Map<String, Metric> metricMap = new HashMap<>();
for (Metric m : metrics) {
    metricMap.put(m.getId(), m);
}
```

#### 리소스 관리
```java
// ✅ try-with-resources 사용
try (Connection conn = dataSource.getConnection();
     PreparedStatement pstmt = conn.prepareStatement(sql)) {
    // ...
} // 자동으로 리소스 해제

// ❌ 수동 close (누락 위험)
Connection conn = dataSource.getConnection();
try {
    // ...
} finally {
    conn.close(); // 예외 발생 시 누락 가능
}
```

#### 캐싱
```java
// ✅ 자주 조회되는 데이터 캐싱
@Cacheable(value = "metrics", key = "#type")
public List<Metric> getMetricsByType(String type) {
    return metricRepository.findByType(type);
}
```

#### 배치 처리
```java
// ❌ 건별 처리
for (Metric m : metrics) {
    metricRepository.save(m);
}

// ✅ 배치 처리
metricRepository.saveAll(metrics);
```

### 4. 예외 처리

```java
// ✅ 적절한 예외 처리
public MetricData collect() {
    try {
        return exporterClient.fetch();
    } catch (ExporterConnectionException e) {
        log.error("Exporter connection failed: {}", e.getMessage(), e);
        throw new MetricCollectionException("Failed to collect metrics", e);
    } catch (Exception e) {
        log.error("Unexpected error: {}", e.getMessage(), e);
        throw new MetricCollectionException("Unexpected error occurred", e);
    }
}

// ❌ 빈 catch 블록
try {
    // ...
} catch (Exception e) {
    // 아무것도 안함
}

// ❌ Exception 삼키기
try {
    // ...
} catch (Exception e) {
    log.error("Error");
    return null; // 예외 정보 손실
}
```

### 5. 테스트 가능성

```java
// ✅ 의존성 주입으로 테스트 가능하게
@Service
public class MetricCollectorService {

    private final ExporterClient exporterClient;

    // 생성자 주입 (테스트 시 Mock 주입 가능)
    public MetricCollectorService(ExporterClient exporterClient) {
        this.exporterClient = exporterClient;
    }
}

// ❌ 테스트 불가능
@Service
public class MetricCollectorService {

    private ExporterClient exporterClient = new ExporterClient(); // 하드코딩
}
```

## 보안 체크리스트

### OWASP Top 10
- [ ] SQL Injection 방지
- [ ] XSS 방지 (입력 Sanitization)
- [ ] CSRF 토큰 사용
- [ ] 안전한 인증/세션 관리
- [ ] 민감 데이터 암호화
- [ ] 적절한 접근 제어
- [ ] 보안 설정 오류 방지
- [ ] 안전하지 않은 역직렬화 방지
- [ ] 취약한 컴포넌트 사용 금지
- [ ] 로깅 및 모니터링

### 의존성 보안
```bash
# Gradle 의존성 취약점 체크
./gradlew dependencyCheckAnalyze

# OWASP Dependency-Check
./gradlew dependencyCheckUpdate
```

## 리뷰 프로세스

### 1. 자동 리뷰
- SonarQube 분석
- Checkstyle 검사
- SpotBugs 취약점 검사
- 의존성 보안 검사

### 2. 수동 리뷰
- 로직 검토
- 설계 검토
- 성능 검토
- 보안 검토

### 3. 리뷰 코멘트 작성
```markdown
**[CRITICAL]** SQL Injection 취약점 발견
- 파일: MetricRepository.java:45
- 문제: 사용자 입력이 SQL에 직접 삽입됨
- 해결: PreparedStatement 사용 필요

**[SUGGESTION]** 성능 개선 가능
- 파일: MetricCollectorService.java:102
- 문제: O(n²) 알고리즘 사용
- 해결: HashMap 사용으로 O(n) 개선 가능
```

## Definition of Done

### 리뷰 완료 기준
- [ ] 모든 SonarQube 이슈 해결
- [ ] 보안 취약점 0개
- [ ] 성능 문제 해결
- [ ] 코드 스타일 준수
- [ ] 테스트 커버리지 > 80%
- [ ] 리뷰어 2명 승인

## 참고 문서
- CLAUDE.md: 코딩 표준 및 품질 기준
- .claude/specs/quality-gates.spec.yml: 품질 게이트 상세

---

© 2025 bocopile — MOAO11y Review Agent Guide
