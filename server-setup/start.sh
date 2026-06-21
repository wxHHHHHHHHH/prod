#!/bin/bash
# ============================================
# 微服务商城 — 中间件一键部署
# 用法: chmod +x start.sh && ./start.sh
# ============================================
set -e

GREEN='\033[0;32m' YELLOW='\033[1;33m' RED='\033[0;31m' NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MYSQL_PASS="${MYSQL_ROOT_PASSWORD:-Mall@2024!}"
# 如果你的镜像加速器地址不同，改这里
ALIYUN_MIRROR="https://mrauqknj.mirror.aliyuncs.com"

echo "========================================"
echo " 微服务商城 — 启动中间件"
echo "========================================"

# ---- 1. 确保 Docker 运行 ----
if ! docker info &>/dev/null 2>&1; then
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null
    sleep 2
fi
docker info &>/dev/null || { echo "❌ Docker 未运行"; exit 1; }
log "Docker 已运行"

# ---- 2. 配置镜像加速 ----
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << JSON
{
  "registry-mirrors": ["${ALIYUN_MIRROR}"],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m", "max-file": "3" }
}
JSON
systemctl restart docker 2>/dev/null && sleep 2 || true

# ---- 3. 智能拉取镜像（多源尝试）----
pull_image() {
    local img="$1"
    if docker image inspect "$img" &>/dev/null 2>&1; then
        log "镜像已存在: $img"; return 0
    fi
    # 依次尝试不同源
    for src in \
        "$img" \
        "docker.m.daocloud.io/$img" \
        "docker.1panel.live/$img"; do
        echo "  尝试: $src"
        if docker pull "$src" 2>&1 | tail -1 | grep -q "Downloaded\|exists\|Pulled"; then
            [ "$src" != "$img" ] && docker tag "$src" "$img" 2>/dev/null
            log "拉取成功: $img"
            return 0
        fi
    done
    warn "无法拉取: $img"
    return 1
}

echo ""
echo "📥 拉取 MySQL 8.0..."
pull_image "mysql:8.0"

echo "📥 拉取 Redis 7..."
pull_image "redis:7-alpine"

echo "📥 拉取 Nacos（可能较慢）..."
pull_image "nacos/nacos-server:v2.3.2" || warn "Nacos 拉取失败，跳过，用原生安装"

# ---- 4. 停止旧容器 ----
docker rm -f mall-mysql mall-redis mall-nacos 2>/dev/null || true

# ---- 5. 创建 Docker 网络 ----
docker network create mall-net 2>/dev/null || true

# ---- 6. 启动 MySQL ----
echo ""
echo "🐳 启动 MySQL..."
docker run -d --name mall-mysql \
    --network mall-net \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_PASS}" \
    -e MYSQL_DATABASE=mall \
    -e TZ=Asia/Shanghai \
    -p 3306:3306 \
    -v mall-mysql-data:/var/lib/mysql \
    -v "${PROJECT_DIR}/sql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
    --restart unless-stopped \
    mysql:8.0 \
    --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci \
    --default-time-zone=+08:00 --default-authentication-plugin=mysql_native_password

# ---- 7. 等待 MySQL 就绪 ----
echo "⏳ 等待 MySQL 就绪..."
for i in $(seq 1 30); do
    if docker exec mall-mysql mysqladmin ping -h localhost -u root -p"${MYSQL_PASS}" --silent 2>/dev/null; then
        log "MySQL 已就绪 (端口 3306)"
        break
    fi
    sleep 2
done

# ---- 8. 启动 Redis ----
echo "🐳 启动 Redis..."
docker run -d --name mall-redis \
    --network mall-net \
    -p 6379:6379 \
    -v mall-redis-data:/data \
    --restart unless-stopped \
    redis:7-alpine \
    redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
log "Redis 已启动 (端口 6379)"

# ---- 9. 启动 Nacos ----
echo "🐳 启动 Nacos..."
if docker image inspect "nacos/nacos-server:v2.3.2" &>/dev/null; then
    docker run -d --name mall-nacos \
        --network mall-net \
        -e MODE=standalone \
        -e PREFER_HOST_MODE=ip \
        -e SPRING_DATASOURCE_PLATFORM=mysql \
        -e MYSQL_SERVICE_HOST=mysql \
        -e MYSQL_SERVICE_PORT=3306 \
        -e MYSQL_SERVICE_DB_NAME=nacos \
        -e MYSQL_SERVICE_USER=root \
        -e MYSQL_SERVICE_PASSWORD="${MYSQL_PASS}" \
        -e MYSQL_SERVICE_DB_PARAM="characterEncoding=utf8&connectTimeout=3000&socketTimeout=6000&autoReconnect=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Shanghai" \
        -p 8848:8848 -p 9848:9848 \
        -v mall-nacos-data:/home/nacos/data \
        --restart unless-stopped \
        nacos/nacos-server:v2.3.2
    log "Nacos 已启动: http://47.108.130.167:8848/nacos (nacos/nacos)"
else
    warn "Nacos 镜像不可用，请手动安装: bash install-nacos-native.sh"
fi

# ---- 10. 总结 ----
echo ""
echo "========================================"
echo " ✅ 中间件部署完成"
echo "========================================"
echo ""
echo "  MySQL:  47.108.130.167:3306  (root / ${MYSQL_PASS})"
echo "  Redis:  47.108.130.167:6379"
echo "  Nacos:  http://47.108.130.167:8848/nacos (nacos/nacos)"
echo ""
echo "⚠️  请确保阿里云安全组已放行: 3306, 6379, 8848, 8080-8085"
echo ""
echo "下一步: cd /opt/mall && bash server-setup/deploy.sh app"
