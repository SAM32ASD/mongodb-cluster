#cloud-config
users:
  - name: bigdata
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: sudo,adm,systemd-journal
    ssh_authorized_keys:
      - ${public_key}

disable_root: true
ssh_pwauth: false

package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - apt-transport-https
  - software-properties-common
  - adduser
  - libfontconfig1

runcmd:
  # 1. Installer Prometheus
  - |
    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
    tar xvfz prometheus-2.45.0.linux-amd64.tar.gz
    cd prometheus-2.45.0.linux-amd64
    sudo cp prometheus promtool /usr/local/bin/
    sudo mkdir -p /etc/prometheus /var/lib/prometheus
    sudo cp -r consoles console_libraries /etc/prometheus/
    sudo useradd --no-create-home --shell /bin/false prometheus || true
    sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

  # 2. Configuration Prometheus
  - |
    cat > /tmp/prometheus.yml << 'EOF'
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'mongodb-exporter'
        static_configs:
          - targets:
            - '${mongo_us_ip}:9216'
            - '${mongo_eu_ip}:9216'
            - '${mongo_ap_ip}:9216'
    EOF
    sudo mv /tmp/prometheus.yml /etc/prometheus/prometheus.yml
    sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

  # 3. Service Prometheus
  - |
    cat > /tmp/prometheus.service << 'EOF'
    [Unit]
    Description=Prometheus
    After=network.target

    [Service]
    User=prometheus
    Group=prometheus
    Type=simple
    ExecStart=/usr/local/bin/prometheus \
      --config.file /etc/prometheus/prometheus.yml \
      --storage.tsdb.path /var/lib/prometheus/ \
      --web.console.templates=/etc/prometheus/consoles \
      --web.console.libraries=/etc/prometheus/console_libraries
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOF
    sudo mv /tmp/prometheus.service /etc/systemd/system/prometheus.service

  # 4. Installer Grafana
  - |
    sudo apt-get install -y apt-transport-https software-properties-common
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
    sudo apt-get update
    sudo apt-get install -y grafana

  # 5. Configuration Grafana
  - sudo sed -i 's/;admin_password = admin/admin_password = ${grafana_password}/g' /etc/grafana/grafana.ini

  # 6. Démarrer les services
  - sudo systemctl daemon-reload
  - sudo systemctl enable prometheus
  - sudo systemctl start prometheus
  - sudo systemctl enable grafana-server
  - sudo systemctl start grafana-server

  # 7. Message de bienvenue
  - |
    cat > /etc/update-motd.d/99-monitoring << 'MOTD'
    #!/bin/bash
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     MongoDB Cluster - Monitoring Server               ║"
    echo "║     Prometheus: http://$(hostname -I | awk '{print $1}'):9090    ║"
    echo "║     Grafana:    http://$(hostname -I | awk '{print $1}'):3000    ║"
    echo "╚════════════════════════════════════════════════════════╝"
    MOTD
  - chmod +x /etc/update-motd.d/99-monitoring

final_message: "Monitoring server ready. Grafana: http://<IP>:3000 (admin/${grafana_password})"
