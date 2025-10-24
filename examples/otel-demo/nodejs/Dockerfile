FROM node:18-alpine

WORKDIR /app

# 의존성 파일 복사 및 설치
COPY package*.json ./
RUN npm ci --only=production

# 애플리케이션 코드 복사
COPY app.js .

# 환경 변수 설정
ENV NODE_ENV=production
ENV OTEL_EXPORTER_OTLP_ENDPOINT=signoz-otel-collector.observability.svc.cluster.local:4317
ENV SERVICE_NAME=nodejs-otel-demo
ENV DEPLOYMENT_ENVIRONMENT=production
ENV PORT=3000

# 포트 노출
EXPOSE 3000

# 헬스체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); }).on('error', () => { process.exit(1); })"

# 애플리케이션 실행
CMD ["node", "app.js"]
