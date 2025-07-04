# scripts/Dockerfile
FROM python:3.9-slim-buster

WORKDIR /app

COPY efs_manifest_generator.py .

RUN pip install boto3

ENTRYPOINT ["python3", "efs_manifest_generator.py"]