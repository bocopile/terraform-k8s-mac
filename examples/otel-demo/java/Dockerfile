FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /app

# pom.xml 복사 및 의존성 다운로드
COPY pom.xml .
RUN mvn dependency:go-offline -B

# 소스 코드 복사 및 빌드
COPY src ./src
RUN mvn clean package -DskipTests

# 실행 이미지
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# JAR 파일 복사
COPY --from=build /app/target/*.jar app.jar

# 환경 변수 설정
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz-otel-collector.observability.svc.cluster.local:4317
ENV OTEL_SERVICE_NAME=java-otel-demo
ENV OTEL_DEPLOYMENT_ENVIRONMENT=production

# 포트 노출
EXPOSE 8080

# 헬스체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "app.jar"]
