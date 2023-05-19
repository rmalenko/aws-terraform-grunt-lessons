#!/usr/bin/env bash

# Prometheus
sudo groupadd --system prometheus && sudo useradd -s /sbin/nologin --system -g prometheus prometheus
sudo wget https://github.com/prometheus/node_exporter/releases/download/v${version_nodeexporter}/node_exporter-${version_nodeexporter}.linux-amd64.tar.gz --output-document=/tmp/node_exporter-amd64.tar.gz
sudo mkdir -p /tmp/node_exporter && sudo tar xvf /tmp/node_exporter-amd64.tar.gz --directory=/tmp/node_exporter --strip-components=1
sudo cp /tmp/node_exporter/node_exporter /usr/local/bin/node_exporter

printf %s "[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
" | sudo tee /etc/systemd/system/${systemd_unit_name}.service

sudo systemctl daemon-reload && sudo systemctl start ${systemd_unit_name} && sudo systemctl enable ${systemd_unit_name}
