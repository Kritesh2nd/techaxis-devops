#!/bin/bash

set -e

JENKINS_IP="${jenkins_private_ip}"
DEPLOYMENT_IP="${deployment_private_ip}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y

apt-get install -y \
  curl \
  wget \
  unzip \
  ca-certificates \
  gnupg \
  apt-transport-https \
  software-properties-common

useradd \
  --system \
  --no-create-home \
  --shell /usr/sbin/nologin \
  loki || true

mkdir -p /etc/loki
mkdir -p /var/lib/loki
mkdir -p /var/lib/loki/chunks
mkdir -p /var/lib/loki/index
mkdir -p /var/lib/loki/cache

chown -R loki:loki /var/lib/loki
chown -R loki:loki /etc/loki

cd /tmp

wget -q \
  https://github.com/grafana/loki/releases/download/v3.7.8/loki-linux-amd64.zip

unzip -o loki-linux-amd64.zip

chmod +x loki-linux-amd64

mv loki-linux-amd64 /usr/local/bin/loki

rm -f loki-linux-amd64.zip

cat > /etc/loki/loki.yaml <<EOF
auth_enabled: false

server:
  http_listen_address: 0.0.0.0
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /var/lib/loki
  replication_factor: 1

  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2025-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: /var/lib/loki/chunks

compactor:
  working_directory: /var/lib/loki/compactor
  retention_enabled: true
  delete_request_store: filesystem

limits_config:
  retention_period: 168h
  reject_old_samples: true
  reject_old_samples_max_age: 168h

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

analytics:
  reporting_enabled: false
EOF

chown -R loki:loki /etc/loki
chown -R loki:loki /var/lib/loki

cat > /etc/systemd/system/loki.service <<EOF
[Unit]
Description=Loki
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=loki
Group=loki
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/loki.yaml
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable loki
systemctl start loki

install -m 0755 -d /etc/apt/keyrings

wget -O /etc/apt/keyrings/grafana.asc \
  https://apt.grafana.com/gpg-full.key

chmod 644 /etc/apt/keyrings/grafana.asc

echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" \
  > /etc/apt/sources.list.d/grafana.list

apt-get update

apt-get install -y grafana

mkdir -p /etc/grafana/provisioning/datasources

cat > /etc/grafana/provisioning/datasources/loki.yaml <<EOF
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://127.0.0.1:3100
    isDefault: true
    editable: false
EOF

mkdir -p /etc/grafana/provisioning/dashboards
mkdir -p /var/lib/grafana/dashboards

cat > /etc/grafana/provisioning/dashboards/dashboard.yaml <<EOF
apiVersion: 1

providers:
  - name: Logging
    orgId: 1
    folder: Logs
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

cat > /var/lib/grafana/dashboards/logging.json <<EOF
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "graphTooltip": 0,
  "panels": [
    {
      "datasource": {
        "type": "loki",
        "uid": "loki"
      },
      "gridPos": {
        "h": 18,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "deduplication": "none",
        "enableLogDetails": true,
        "prettifyLogMessage": false,
        "showCommonLabels": false,
        "showLabels": true,
        "showTime": true,
        "sortOrder": "Descending",
        "wrapLines": true
      },
      "targets": [
        {
          "expr": "{server=~\"jenkins|deployment\"}",
          "refId": "A"
        }
      ],
      "title": "Jenkins and Deployment Logs",
      "type": "logs"
    }
  ],
  "schemaVersion": 39,
  "tags": [
    "logs"
  ],
  "templating": {
    "list": [
      {
        "current": {
          "text": "All",
          "value": "$__all"
        },
        "datasource": {
          "type": "loki",
          "uid": "loki"
        },
        "definition": "label_values(server)",
        "includeAll": true,
        "label": "Server",
        "multi": true,
        "name": "server",
        "options": [],
        "query": {
          "label": "server",
          "refId": "Loki-server-Variable-Query"
        },
        "refresh": 2,
        "type": "query"
      }
    ]
  },
  "title": "Infrastructure Logs",
  "uid": "infrastructure-logs",
  "version": 1
}
EOF

chown -R grafana:grafana /var/lib/grafana/dashboards
chown -R grafana:grafana /etc/grafana/provisioning

systemctl enable grafana-server
systemctl restart grafana-server

systemctl restart loki

echo "Monitoring server setup completed"
echo "Jenkins private IP: ${JENKINS_IP}"
echo "Deployment private IP: ${DEPLOYMENT_IP}"
echo "Loki: http://$(hostname -I | awk '{print $1}'):3100"
echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000"
