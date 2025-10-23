"""
OpenTelemetry Python Demo Application
SigNoz와 통합된 간단한 Flask 애플리케이션
"""
from flask import Flask, jsonify, request
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, DEPLOYMENT_ENVIRONMENT
from opentelemetry.instrumentation.flask import FlaskInstrumentor
import logging
import time
import random
import os

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 환경 변수에서 설정 가져오기
OTEL_EXPORTER_OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://signoz-otel-collector.observability.svc.cluster.local:4317")
SERVICE_NAME_VALUE = os.getenv("SERVICE_NAME", "python-otel-demo")
DEPLOYMENT_ENV = os.getenv("DEPLOYMENT_ENVIRONMENT", "development")

# OpenTelemetry 리소스 설정
resource = Resource.create({
    SERVICE_NAME: SERVICE_NAME_VALUE,
    DEPLOYMENT_ENVIRONMENT: DEPLOYMENT_ENV,
    "service.version": "1.0.0",
    "service.instance.id": os.getenv("HOSTNAME", "local"),
})

# Tracer 설정
trace_provider = TracerProvider(resource=resource)
otlp_span_exporter = OTLPSpanExporter(endpoint=OTEL_EXPORTER_OTLP_ENDPOINT, insecure=True)
trace_provider.add_span_processor(BatchSpanProcessor(otlp_span_exporter))
trace.set_tracer_provider(trace_provider)
tracer = trace.get_tracer(__name__)

# Metrics 설정
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=OTEL_EXPORTER_OTLP_ENDPOINT, insecure=True)
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)
meter = metrics.get_meter(__name__)

# 커스텀 메트릭 정의
request_counter = meter.create_counter(
    name="http_requests_total",
    description="Total number of HTTP requests",
    unit="1",
)

request_duration = meter.create_histogram(
    name="http_request_duration_seconds",
    description="HTTP request duration in seconds",
    unit="s",
)

# Flask 앱 생성
app = Flask(__name__)

# Flask 자동 계측
FlaskInstrumentor().instrument_app(app)

@app.route("/")
def index():
    """메인 페이지"""
    logger.info("Index page accessed")
    return jsonify({
        "service": SERVICE_NAME_VALUE,
        "status": "healthy",
        "message": "OpenTelemetry Python Demo is running!",
        "endpoints": ["/", "/api/users", "/api/slow", "/api/error"]
    })

@app.route("/api/users")
def get_users():
    """사용자 목록 조회"""
    start_time = time.time()

    with tracer.start_as_current_span("get_users") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/users")

        # 데이터베이스 조회 시뮬레이션
        with tracer.start_as_current_span("database.query") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.statement", "SELECT * FROM users")
            time.sleep(random.uniform(0.01, 0.05))

            users = [
                {"id": 1, "name": "Alice", "email": "alice@example.com"},
                {"id": 2, "name": "Bob", "email": "bob@example.com"},
                {"id": 3, "name": "Charlie", "email": "charlie@example.com"},
            ]

        duration = time.time() - start_time
        request_counter.add(1, {"endpoint": "/api/users", "method": "GET", "status": "200"})
        request_duration.record(duration, {"endpoint": "/api/users", "method": "GET"})

        logger.info(f"Retrieved {len(users)} users in {duration:.3f}s")
        return jsonify(users)

@app.route("/api/slow")
def slow_endpoint():
    """느린 응답을 시뮬레이션하는 엔드포인트"""
    start_time = time.time()

    with tracer.start_as_current_span("slow_operation") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/slow")

        # 느린 작업 시뮬레이션
        delay = random.uniform(0.5, 2.0)
        span.set_attribute("operation.delay", delay)

        with tracer.start_as_current_span("slow.step1"):
            time.sleep(delay / 3)

        with tracer.start_as_current_span("slow.step2"):
            time.sleep(delay / 3)

        with tracer.start_as_current_span("slow.step3"):
            time.sleep(delay / 3)

        duration = time.time() - start_time
        request_counter.add(1, {"endpoint": "/api/slow", "method": "GET", "status": "200"})
        request_duration.record(duration, {"endpoint": "/api/slow", "method": "GET"})

        logger.warning(f"Slow operation completed in {duration:.3f}s")
        return jsonify({"message": "Operation completed", "duration": f"{duration:.3f}s"})

@app.route("/api/error")
def error_endpoint():
    """에러를 발생시키는 엔드포인트"""
    start_time = time.time()

    with tracer.start_as_current_span("error_operation") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/error")

        try:
            # 의도적으로 에러 발생
            raise ValueError("Intentional error for testing")
        except Exception as e:
            duration = time.time() - start_time
            span.record_exception(e)
            span.set_status(trace.Status(trace.StatusCode.ERROR, str(e)))

            request_counter.add(1, {"endpoint": "/api/error", "method": "GET", "status": "500"})
            request_duration.record(duration, {"endpoint": "/api/error", "method": "GET"})

            logger.error(f"Error occurred: {str(e)}")
            return jsonify({"error": str(e)}), 500

@app.route("/health")
def health():
    """헬스체크 엔드포인트"""
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    logger.info(f"Starting {SERVICE_NAME_VALUE} on port 5000")
    logger.info(f"OTLP Endpoint: {OTEL_EXPORTER_OTLP_ENDPOINT}")
    logger.info(f"Deployment Environment: {DEPLOYMENT_ENV}")
    app.run(host="0.0.0.0", port=5000, debug=False)
