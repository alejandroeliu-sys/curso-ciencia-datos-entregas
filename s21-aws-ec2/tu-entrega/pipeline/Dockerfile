FROM python:3.12-slim
RUN pip install --no-cache-dir duckdb==1.1.3 && \
    python -c "import duckdb; c=duckdb.connect(); c.sql('INSTALL httpfs; INSTALL aws')"
COPY pipeline.py /app/pipeline.py
CMD ["python", "/app/pipeline.py"]
