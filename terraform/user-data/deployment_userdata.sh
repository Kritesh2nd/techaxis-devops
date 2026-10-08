#!/bin/bash

set -e

LOKI_URL="${loki_url}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y

apt-get install -y \
  nginx \
  curl \
  wget \
  unzip \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https

systemctl enable nginx
systemctl start nginx

cat > /etc/nginx/sites-available/app <<'EOF'
server {
    listen 80;
    server_name _;

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:3000;

        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default

ln -s /etc/nginx/sites-available/app \
      /etc/nginx/sites-enabled/app

nginx -t
systemctl reload nginx

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

mkdir -p /opt/task-app

chown -R ubuntu:ubuntu /opt/task-app

mkdir -p /opt/promtail
mkdir -p /var/lib/promtail
mkdir -p /etc/promtail

cd /opt/promtail

wget -q \
  https://github.com/grafana/loki/releases/download/v3.5.7/promtail-linux-amd64.zip

unzip -o promtail-linux-amd64.zip

chmod +x promtail-linux-amd64

mv promtail-linux-amd64 /usr/local/bin/promtail

rm -f promtail-linux-amd64.zip

cat > /etc/promtail/promtail.yaml <<EOF
server:
  http_listen_address: 0.0.0.0
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: $${LOKI_URL}/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          server: deployment
          environment: production
          __path__: /var/lib/docker/containers/*/*-json.log

    pipeline_stages:
      - docker: {}

  - job_name: nginx
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx
          server: deployment
          environment: production
          __path__: /var/log/nginx/*.log

  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          server: deployment
          environment: production
          __path__: /var/log/*.log
EOF

cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail --config.file=/etc/promtail/promtail.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promtail
systemctl restart promtail

echo "Deployment server setup completed"
