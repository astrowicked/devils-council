FROM docker.io/library/nginx:latest
FROM quay.io/prometheus/prometheus:v2.45.0

WORKDIR /app
COPY . /app

RUN apt-get update && apt-get install -y curl

EXPOSE 8080
CMD ["/app/start.sh"]
