#!/bin/bash

set -e

LOKI_URL="${loki_url}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y

apt-get install -y \
  curl \
  wget \
  unzip \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  fontconfig \
  openjdk-21-jre \
  apt-transport-https

install -m 0755 -d /etc/apt/keyrings

wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

apt-get update
apt-get install -y jenkins

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

usermod -aG docker jenkins

systemctl enable jenkins
systemctl restart jenkins

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
  - job_name: jenkins
    static_configs:
      - targets:
          - localhost
        labels:
          job: jenkins
          server: jenkins
          environment: ci
          __path__: /var/log/jenkins/jenkins.log

  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: system
          server: jenkins
          environment: ci
          __path__: /var/log/*.log

  - job_name: auth
    static_configs:
      - targets:
          - localhost
        labels:
          job: auth
          server: jenkins
          environment: ci
          __path__: /var/log/auth.log

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          server: jenkins
          environment: ci
          __path__: /var/log/syslog
EOF

cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail
After=network-online.target
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

systemctl restart jenkins

echo "Jenkins server setup completed"
echo "Jenkins initial password:"
cat /var/lib/jenkins/secrets/initialAdminPassword