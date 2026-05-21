# Use a lightweight official Python slim base image
FROM python:3.11-slim

# Set system environment variables to prevent Python buffering & caching
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Install system dependencies and pip requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all backend source files into the container
COPY . .

# Expose the port (Cloud Run will override this via $PORT environment variable)
EXPOSE 8080

# Run Uvicorn bound to host '0.0.0.0' and reference the dynamic environment variable port: --port env.get("PORT", 8080)
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}"]
