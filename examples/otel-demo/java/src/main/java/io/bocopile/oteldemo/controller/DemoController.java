package io.bocopile.oteldemo.controller;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.context.Scope;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

@RestController
public class DemoController {

    private static final Logger logger = LoggerFactory.getLogger(DemoController.class);
    private final Tracer tracer;
    private final LongCounter requestCounter;
    private final DoubleHistogram requestDuration;
    private final Random random = new Random();

    @Value("${otel.service.name:java-otel-demo}")
    private String serviceName;

    public DemoController(Tracer tracer, Meter meter) {
        this.tracer = tracer;
        this.requestCounter = meter
                .counterBuilder("http_requests_total")
                .setDescription("Total number of HTTP requests")
                .setUnit("1")
                .build();
        this.requestDuration = meter
                .histogramBuilder("http_request_duration_seconds")
                .setDescription("HTTP request duration in seconds")
                .setUnit("s")
                .build();
    }

    @GetMapping("/")
    public ResponseEntity<Map<String, Object>> index() {
        long startTime = System.currentTimeMillis();
        Span span = tracer.spanBuilder("index_handler").startSpan();

        try (Scope scope = span.makeCurrent()) {
            logger.info("Index page accessed");

            Map<String, Object> response = new HashMap<>();
            response.put("service", serviceName);
            response.put("status", "healthy");
            response.put("message", "OpenTelemetry Java Demo is running!");
            response.put("endpoints", List.of("/", "/api/orders", "/api/slow", "/api/error"));

            recordMetrics("/", "GET", "200", startTime);
            return ResponseEntity.ok(response);
        } finally {
            span.end();
        }
    }

    @GetMapping("/api/orders")
    public ResponseEntity<List<Map<String, Object>>> getOrders() {
        long startTime = System.currentTimeMillis();
        Span span = tracer.spanBuilder("get_orders").startSpan();

        try (Scope scope = span.makeCurrent()) {
            span.setAttribute("http.method", "GET");
            span.setAttribute("http.route", "/api/orders");

            // 데이터베이스 조회 시뮬레이션
            Span dbSpan = tracer.spanBuilder("database.query")
                    .setParent(io.opentelemetry.context.Context.current())
                    .startSpan();

            try (Scope dbScope = dbSpan.makeCurrent()) {
                dbSpan.setAttribute("db.system", "postgresql");
                dbSpan.setAttribute("db.statement", "SELECT * FROM orders");

                Thread.sleep(random.nextInt(40) + 10);

                List<Map<String, Object>> orders = List.of(
                        Map.of("id", 1, "product", "Laptop", "quantity", 1, "price", 1200.00),
                        Map.of("id", 2, "product", "Mouse", "quantity", 2, "price", 50.00),
                        Map.of("id", 3, "product", "Keyboard", "quantity", 1, "price", 75.00)
                );

                logger.info("Retrieved {} orders", orders.size());
                recordMetrics("/api/orders", "GET", "200", startTime);

                return ResponseEntity.ok(orders);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new RuntimeException(e);
            } finally {
                dbSpan.end();
            }
        } finally {
            span.end();
        }
    }

    @GetMapping("/api/slow")
    public ResponseEntity<Map<String, Object>> slowEndpoint() {
        long startTime = System.currentTimeMillis();
        Span span = tracer.spanBuilder("slow_operation").startSpan();

        try (Scope scope = span.makeCurrent()) {
            span.setAttribute("http.method", "GET");
            span.setAttribute("http.route", "/api/slow");

            int delay = random.nextInt(1500) + 500;
            span.setAttribute("operation.delay", delay);

            // 여러 단계로 나누어 느린 작업 시뮬레이션
            simulateSlowStep("slow.step1", delay / 3);
            simulateSlowStep("slow.step2", delay / 3);
            simulateSlowStep("slow.step3", delay / 3);

            double duration = (System.currentTimeMillis() - startTime) / 1000.0;
            logger.warn("Slow operation completed in {}s", String.format("%.3f", duration));

            Map<String, Object> response = new HashMap<>();
            response.put("message", "Operation completed");
            response.put("duration", String.format("%.3fs", duration));

            recordMetrics("/api/slow", "GET", "200", startTime);
            return ResponseEntity.ok(response);
        } finally {
            span.end();
        }
    }

    @GetMapping("/api/error")
    public ResponseEntity<Map<String, Object>> errorEndpoint() {
        long startTime = System.currentTimeMillis();
        Span span = tracer.spanBuilder("error_operation").startSpan();

        try (Scope scope = span.makeCurrent()) {
            span.setAttribute("http.method", "GET");
            span.setAttribute("http.route", "/api/error");

            // 의도적으로 에러 발생
            Exception exception = new RuntimeException("Intentional error for testing");
            span.recordException(exception);
            span.setStatus(StatusCode.ERROR, exception.getMessage());

            logger.error("Error occurred: {}", exception.getMessage());

            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", exception.getMessage());

            recordMetrics("/api/error", "GET", "500", startTime);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        } finally {
            span.end();
        }
    }

    private void simulateSlowStep(String stepName, int delayMs) {
        Span stepSpan = tracer.spanBuilder(stepName)
                .setParent(io.opentelemetry.context.Context.current())
                .startSpan();

        try (Scope scope = stepSpan.makeCurrent()) {
            Thread.sleep(delayMs);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException(e);
        } finally {
            stepSpan.end();
        }
    }

    private void recordMetrics(String endpoint, String method, String status, long startTime) {
        double duration = (System.currentTimeMillis() - startTime) / 1000.0;

        io.opentelemetry.api.common.Attributes attributes = io.opentelemetry.api.common.Attributes.builder()
                .put("endpoint", endpoint)
                .put("method", method)
                .put("status", status)
                .build();

        requestCounter.add(1, attributes);
        requestDuration.record(duration, attributes);
    }
}
