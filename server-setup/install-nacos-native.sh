#!/bin/bash
# ============================================
# Nacos 原生安装（Docker 镜像拉不下来时用）
# 用法: bash install-nacos-native.sh
# ============================================
set -e

NACOS_VERSION="2.3.2"
NACOS_HOME="/opt/nacos"

echo "📦 原生安装 Nacos ${NACOS_VERSION}..."

# 下载 Nacos（使用阿里云 OSS 镜像加速）
if [ ! -f "/tmp/nacos-${NACOS_VERSION}.zip" ]; then
    NACOS_URL="https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}/nacos-server-${NACOS_VERSION}.zip"
    # GitHub 加速代理
    wget -q --show-progress "${NACOS_URL}" -O /tmp/nacos-${NACOS_VERSION}.zip || \
    wget -q --show-progress "https://ghproxy.com/${NACOS_URL}" -O /tmp/nacos-${NACOS_VERSION}.zip || {
        echo "❌ Nacos 下载失败，请手动下载到 /tmp/nacos-${NACOS_VERSION}.zip"
        exit 1
    }
fi

rm -rf ${NACOS_HOME}
unzip -q /tmp/nacos-${NACOS_VERSION}.zip -d /opt/
mv /opt/nacos ${NACOS_HOME}

# 配置单机模式 + MySQL
cat > ${NACOS_HOME}/conf/application.properties << CONF
server.servlet.contextPath=/nacos
server.port=8848
spring.datasource.platform=mysql
db.num=1
db.url.0=jdbc:mysql://localhost:3306/nacos?characterEncoding=utf8&connectTimeout=3000&socketTimeout=6000&autoReconnect=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai
db.user.0=root
db.password.0=Mall@2024!
nacos.core.auth.enabled=true
nacos.core.auth.plugin.nacos.token.secret.key=SecretKey012345678901234567890123456789012345678901234567890123456789
nacos.core.auth.server.identity.key=mall
nacos.core.auth.server.identity.value=mall
CONF

# 创建 systemd 服务
cat > /etc/systemd/system/nacos.service << SERVICE
[Unit]
Description=Nacos Server
After=network.target mysql.service

[Service]
Type=simple
ExecStart=${NACOS_HOME}/bin/startup.sh -m standalone
ExecStop=${NACOS_HOME}/bin/shutdown.sh
Restart=on-failure
WorkingDirectory=${NACOS_HOME}

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable nacos --now
echo "✅ Nacos 已安装并启动: http://localhost:8848/nacos (nacos/nacos)"
