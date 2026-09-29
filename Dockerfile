# ═══════════════════════════════════════════════════════════════════
# Stage 1: builder — cài dependencies
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --default-timeout=100 --prefix=/install -r requirements.txt

# ═══════════════════════════════════════════════════════════════════
# Stage 2: runtime — image production nhỏ gọn, non-root
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy dependencies từ stage builder
COPY --from=builder /install /usr/local

# Tạo non-root user và chuyển sang
RUN useradd --create-home --uid 10001 appuser

# Copy mã nguồn sau pip install để tận dụng cache
COPY . .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request, os; port = os.environ.get('PORT', '8000'); urllib.request.urlopen(f'http://127.0.0.1:{port}/health').read()" || exit 1

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
