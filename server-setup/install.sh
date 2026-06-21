#!/bin/bash
# ============================================
# 微服务商城 — 服务器环境一键安装
# 用法: chmod +x install.sh && ./install.sh
# ============================================
set -e

echo "========================================"
echo " 微服务商城 — 服务器环境安装"
echo "========================================"

# ---- 配置你的阿里云镜像加速器（必须！）----
ALIYUN_MIRROR="https://mrauqknj.mirror.aliyuncs.com"

# ---- 1. 安装 Docker ----
if command -v docker &>/dev/null; then
    echo "✅ Docker 已安装: $(docker --version)"
else
    echo "📦 安装 Docker..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker --now
    echo "✅ Docker 安装完成: $(docker --version)"
fi

# ---- 2. 配置 Docker 镜像加速 ----
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << DOCKERCONF
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me",
    "https://mrauqknj.mirror.aliyuncs.com"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m", "max-file": "3" }
}
DOCKERCONF
systemctl restart docker
echo "✅ Docker 镜像加速器已配置: ${ALIYUN_MIRROR}"

# ---- 3. 安装 Java 17 ----
if command -v java &>/dev/null; then
    echo "✅ Java 已安装: $(java -version 2>&1 | head -1)"
else
    echo "📦 安装 OpenJDK 17..."
    apt-get install -y -qq openjdk-17-jdk
    echo "✅ Java 安装完成: $(java -version 2>&1 | head -1)"
fi

# ---- 4. 安装 Maven ----
if command -v mvn &>/dev/null; then
    echo "✅ Maven 已安装: $(mvn --version 2>&1 | head -1)"
else
    echo "📦 安装 Maven..."
    apt-get install -y -qq maven
    echo "✅ Maven 安装完成"
fi

echo ""
echo "========================================"
echo " ✅ 环境安装完成!"
echo "========================================"
echo ""
echo "已安装:"
echo "  Docker:     $(docker --version 2>/dev/null || echo '未安装')"
echo "  Compose:    $(docker compose version 2>/dev/null || echo '未安装')"
echo "  Java:       $(java -version 2>&1 | head -1 || echo '未安装')"
echo "  Maven:      $(mvn --version 2>&1 | head -1 || echo '未安装')"
echo ""
echo "下一步:"
echo "  1. 上传项目: scp -r microservice-mall/ root@服务器:/opt/mall/"
echo "  2. cd /opt/mall/server-setup"
echo "  3. ./start.sh   # 启动中间件"
echo "  4. ./deploy.sh  # 部署后端"
