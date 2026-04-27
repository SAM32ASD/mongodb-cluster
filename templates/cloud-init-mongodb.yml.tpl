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
chpasswd:
  expire: false

package_update: true
package_upgrade: true
packages:
  - curl
  - wget
  - gnupg2
  - software-properties-common
  - apt-transport-https
  - ca-certificates
  - net-tools
  - htop
  - vim
  - jq
  - python3
  - python3-pip

bootcmd:
  - fallocate -l 2G /swapfile || true
  - chmod 600 /swapfile || true
  - mkswap /swapfile || true
  - swapon /swapfile || true

mounts:
  - [ '/swapfile', 'none', 'swap', 'sw', '0', '0' ]

runcmd:
  # 1. Configurer SSH
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
  - sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
  - sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
  - systemctl restart sshd

  # 2. Permissions .ssh pour bigdata
  - mkdir -p /home/bigdata/.ssh
  - chmod 700 /home/bigdata/.ssh
  - touch /home/bigdata/.ssh/authorized_keys
  - chmod 600 /home/bigdata/.ssh/authorized_keys
  - chown -R bigdata:bigdata /home/bigdata/.ssh

  # 3. Installer MongoDB ${mongodb_version}
  - curl -fsSL https://pgp.mongodb.com/server-${mongodb_version}.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-${mongodb_version}.gpg
  - echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${mongodb_version}.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/${mongodb_version} multiverse" | tee /etc/apt/sources.list.d/mongodb-org-${mongodb_version}.list
  - apt-get update
  - apt-get install -y mongodb-org

  # 4. Répertoires MongoDB
  - mkdir -p /data/configdb /data/shard /var/log/mongodb /var/run/mongodb
  - chown -R mongodb:mongodb /data /var/log/mongodb /var/run/mongodb
  - chmod 755 /data/configdb /data/shard

  # 5. Créer les fichiers de configuration MongoDB par défaut (seront remplacés par Terraform)
  - |
    cat > /etc/mongod-config.conf << 'CONFEOF'
    storage:
      dbPath: /data/configdb
      journal:
        enabled: true
    systemLog:
      destination: file
      path: /var/log/mongodb/config.log
      logAppend: true
    net:
      port: 27019
      bindIp: 0.0.0.0
    processManagement:
      timeZoneInfo: /usr/share/zoneinfo
    CONFEOF

  - |
    cat > /etc/mongod-shard.conf << 'CONFEOF'
    storage:
      dbPath: /data/shard
      journal:
        enabled: true
    systemLog:
      destination: file
      path: /var/log/mongodb/shard.log
      logAppend: true
    net:
      port: 27018
      bindIp: 0.0.0.0
    processManagement:
      timeZoneInfo: /usr/share/zoneinfo
    CONFEOF

  - |
    cat > /etc/mongos.conf << 'CONFEOF'
    systemLog:
      destination: file
      path: /var/log/mongodb/mongos.log
      logAppend: true
    net:
      port: 27017
      bindIp: 0.0.0.0
    processManagement:
      timeZoneInfo: /usr/share/zoneinfo
    CONFEOF

  - chown mongodb:mongodb /etc/mongod-config.conf /etc/mongod-shard.conf /etc/mongos.conf
  - chmod 644 /etc/mongod-config.conf /etc/mongod-shard.conf /etc/mongos.conf

  # 7. Services systemd
  - |
    cat > /etc/systemd/system/mongod-config.service << 'EOF'
    [Unit]
    Description=MongoDB Config Server
    After=network.target
    [Service]
    User=mongodb
    Group=mongodb
    ExecStart=/usr/bin/mongod --config /etc/mongod-config.conf
    Restart=always
    [Install]
    WantedBy=multi-user.target
    EOF

  - |
    cat > /etc/systemd/system/mongod-shard.service << 'EOF'
    [Unit]
    Description=MongoDB Shard Server
    After=network.target
    [Service]
    User=mongodb
    Group=mongodb
    ExecStart=/usr/bin/mongod --config /etc/mongod-shard.conf
    Restart=always
    [Install]
    WantedBy=multi-user.target
    EOF

  - |
    cat > /etc/systemd/system/mongos.service << 'EOF'
    [Unit]
    Description=MongoDB Mongos Router
    After=network.target
    [Service]
    User=mongodb
    Group=mongodb
    ExecStart=/usr/bin/mongos --config /etc/mongos.conf
    Restart=always
    [Install]
    WantedBy=multi-user.target
    EOF

  - systemctl daemon-reload

  # 8. Message de bienvenue
  - |
    cat > /etc/update-motd.d/99-mongodb-cluster << 'MOTD'
    #!/bin/bash
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     MongoDB Sharded Cluster - ${region_name}          ║"
    echo "║     Utilisateur: bigdata                               ║"
    echo "║     Région: ${region_code}                             ║"
    echo "╚════════════════════════════════════════════════════════╝"
    MOTD
  - chmod +x /etc/update-motd.d/99-mongodb-cluster

  # 9. Optimisations système
  - echo "vm.swappiness=10" >> /etc/sysctl.conf
  - echo "vm.dirty_ratio=15" >> /etc/sysctl.conf
  - sysctl -p

  # 10. Logrotate MongoDB
  - |
    cat > /etc/logrotate.d/mongodb-custom << 'LOGROTATE'
    /var/log/mongodb/*.log {
      daily
      rotate 3
      compress
      missingok
      notifempty
      create 0640 mongodb mongodb
      sharedscripts
      postrotate
        /bin/kill -SIGUSR1 $(cat /var/run/mongodb/mongod-*.pid 2>/dev/null) > /dev/null 2>&1 || true
      endscript
    }
    LOGROTATE

final_message: "Instance ${region_name} prête. Connectez-vous: ssh bigdata@<IP>"