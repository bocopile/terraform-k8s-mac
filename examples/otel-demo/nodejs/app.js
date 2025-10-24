/**
 * OpenTelemetry Node.js Demo Application
 * SigNoz와 통합된 간단한 Express 애플리케이션
 */
const express = require('express');
const { trace, metrics, context } = require('@opentelemetry/api');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { BatchSpanProcessor } = require('@opentelemetry/sdk-trace-base');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { MeterProvider, PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { registerInstrumentations } = require('@opentelemetry/instrumentation');

// 환경 변수
const OTEL_EXPORTER_OTLP_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
  'signoz-otel-collector.observability.svc.cluster.local:4317';
const SERVICE_NAME = process.env.SERVICE_NAME || 'nodejs-otel-demo';
const DEPLOYMENT_ENV = process.env.DEPLOYMENT_ENVIRONMENT || 'development';
const PORT = process.env.PORT || 3000;

// OpenTelemetry 리소스 설정
const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: SERVICE_NAME,
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: DEPLOYMENT_ENV,
  [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
  [SemanticResourceAttributes.SERVICE_INSTANCE_ID]: process.env.HOSTNAME || 'local',
});

// Tracer 설정
const traceExporter = new OTLPTraceExporter({
  url: `http://${OTEL_EXPORTER_OTLP_ENDPOINT}`,
});

const tracerProvider = new NodeTracerProvider({ resource });
tracerProvider.addSpanProcessor(new BatchSpanProcessor(traceExporter));
tracerProvider.register();

// Metrics 설정
const metricExporter = new OTLPMetricExporter({
  url: `http://${OTEL_EXPORTER_OTLP_ENDPOINT}`,
});

const metricReader = new PeriodicExportingMetricReader({
  exporter: metricExporter,
  exportIntervalMillis: 60000,
});

const meterProvider = new MeterProvider({
  resource,
  readers: [metricReader],
});

metrics.setGlobalMeterProvider(meterProvider);

// 자동 계측 등록
registerInstrumentations({
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
});

// Tracer와 Meter 가져오기
const tracer = trace.getTracer(SERVICE_NAME);
const meter = metrics.getMeter(SERVICE_NAME);

// 커스텀 메트릭 정의
const requestCounter = meter.createCounter('http_requests_total', {
  description: 'Total number of HTTP requests',
  unit: '1',
});

const requestDuration = meter.createHistogram('http_request_duration_seconds', {
  description: 'HTTP request duration in seconds',
  unit: 's',
});

// Express 앱 생성
const app = express();
app.use(express.json());

// 미들웨어: 요청 로깅
app.use((req, res, next) => {
  const startTime = Date.now();
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);

  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;
    requestCounter.add(1, {
      endpoint: req.path,
      method: req.method,
      status: res.statusCode.toString(),
    });
    requestDuration.record(duration, {
      endpoint: req.path,
      method: req.method,
    });
  });

  next();
});

// 라우트 정의
app.get('/', (req, res) => {
  const span = tracer.startSpan('index_handler');
  console.log('Index page accessed');

  res.json({
    service: SERVICE_NAME,
    status: 'healthy',
    message: 'OpenTelemetry Node.js Demo is running!',
    endpoints: ['/', '/api/products', '/api/slow', '/api/error'],
  });

  span.end();
});

app.get('/api/products', async (req, res) => {
  const span = tracer.startSpan('get_products');
  span.setAttribute('http.method', 'GET');
  span.setAttribute('http.route', '/api/products');

  try {
    // 데이터베이스 조회 시뮬레이션
    const dbSpan = tracer.startSpan('database.query', {
      parent: span,
    });
    dbSpan.setAttribute('db.system', 'mongodb');
    dbSpan.setAttribute('db.statement', 'db.products.find()');

    await new Promise(resolve => setTimeout(resolve, Math.random() * 50 + 10));

    const products = [
      { id: 1, name: 'Laptop', price: 1200 },
      { id: 2, name: 'Mouse', price: 25 },
      { id: 3, name: 'Keyboard', price: 75 },
    ];

    dbSpan.end();

    console.log(`Retrieved ${products.length} products`);
    res.json(products);
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
    res.status(500).json({ error: error.message });
  } finally {
    span.end();
  }
});

app.get('/api/slow', async (req, res) => {
  const span = tracer.startSpan('slow_operation');
  span.setAttribute('http.method', 'GET');
  span.setAttribute('http.route', '/api/slow');

  const startTime = Date.now();

  try {
    const delay = Math.random() * 1500 + 500;
    span.setAttribute('operation.delay', delay);

    // 여러 단계로 나누어 느린 작업 시뮬레이션
    const step1Span = tracer.startSpan('slow.step1', { parent: span });
    await new Promise(resolve => setTimeout(resolve, delay / 3));
    step1Span.end();

    const step2Span = tracer.startSpan('slow.step2', { parent: span });
    await new Promise(resolve => setTimeout(resolve, delay / 3));
    step2Span.end();

    const step3Span = tracer.startSpan('slow.step3', { parent: span });
    await new Promise(resolve => setTimeout(resolve, delay / 3));
    step3Span.end();

    const duration = (Date.now() - startTime) / 1000;
    console.warn(`Slow operation completed in ${duration.toFixed(3)}s`);

    res.json({
      message: 'Operation completed',
      duration: `${duration.toFixed(3)}s`,
    });
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
    res.status(500).json({ error: error.message });
  } finally {
    span.end();
  }
});

app.get('/api/error', (req, res) => {
  const span = tracer.startSpan('error_operation');
  span.setAttribute('http.method', 'GET');
  span.setAttribute('http.route', '/api/error');

  try {
    // 의도적으로 에러 발생
    throw new Error('Intentional error for testing');
  } catch (error) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
    console.error(`Error occurred: ${error.message}`);
    res.status(500).json({ error: error.message });
  } finally {
    span.end();
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// 서버 시작
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Starting ${SERVICE_NAME} on port ${PORT}`);
  console.log(`OTLP Endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT}`);
  console.log(`Deployment Environment: ${DEPLOYMENT_ENV}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM signal received: closing HTTP server');
  await tracerProvider.shutdown();
  await meterProvider.shutdown();
  process.exit(0);
});
