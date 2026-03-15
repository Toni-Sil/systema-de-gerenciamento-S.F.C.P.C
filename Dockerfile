# S.F.C.P.C — Production Dockerfile
# Multi-stage build: builder installs deps, runner is a lean final image

# ---- Stage 1: builder ----
FROM python:3.12-slim AS builder

WORKDIR /build

# Install system dependencies for asyncpg, bcrypt, Pillow, tesseract
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    tesseract-ocr \
    tesseract-ocr-por \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---- Stage 2: runner ----
FROM python:3.12-slim AS runner

WORKDIR /app

# Copy system libs needed at runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    tesseract-ocr \
    tesseract-ocr-por \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY src/ ./src/
COPY migrations/ ./migrations/
COPY alembic.ini .

# Run migrations then start the server
# Note: in K8s, run migrations as a separate init container instead
CMD ["sh", "-c", \
     "cd /app && alembic upgrade head && \
      uvicorn src.main:app \
        --host 0.0.0.0 \
        --port 8000 \
        --workers 2 \
        --loop uvloop \
        --http httptools"]

# Expose API port
EXPOSE 8000

# Docker health check (mirrors the /health endpoint)
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1
