#!/bin/bash
# ============================================
# 微服务商城 — 中间件一键部署（随机5位端口）
# 用法: chmod +x start.sh && ./start.sh
# 端口信息保存到 services-ports.env，供 deploy.sh 读取
# ============================================
set -e

GREEN='\033[0;32m' YELLOW='\033[1;33m' RED='\033[0;31m' NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$SCRIPT_DIR/services-ports.env"
MYSQL_PASS="${MYSQL_ROOT_PASSWORD:-Mall@2024!}"
SERVER_IP="${SERVER_IP:-47.108.130.167}"

# ---- 固定5位数端口 ----
# 加载已有端口（如果有）, 否则用默认固定端口
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi
MYSQL_PORT="${MYSQL_PORT:-41728}"
REDIS_PORT="${REDIS_PORT:-52936}"
NACOS_PORT="${NACOS_PORT:-38848}"
NACOS_GRPC_PORT=$((NACOS_PORT + 1000))

echo "========================================"
echo " 微服务商城 — 启动中间件"
echo "========================================"
echo " MySQL : $SERVER_IP:$MYSQL_PORT"
echo " Redis : $SERVER_IP:$REDIS_PORT"
echo " Nacos : http://$SERVER_IP:$NACOS_PORT/nacos"
echo "========================================"

# ---- 1. 确保 Docker 运行 ----
if ! docker info &>/dev/null 2>&1; then
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null
    sleep 2
fi
docker info &>/dev/null || { echo "❌ Docker 未运行"; exit 1; }

# ---- 2. 配置镜像加速 ----
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << JSON
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me",
    "https://mrauqknj.mirror.aliyuncs.com"
  ],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m", "max-file": "3" }
}
JSON
systemctl restart docker 2>/dev/null && sleep 2 || true
log "Docker 就绪"

# ---- 3. 智能拉取镜像 ----
pull_image() {
    local img="$1"
    if docker image inspect "$img" &>/dev/null 2>&1; then
        log "镜像已存在: $img"; return 0
    fi
    # 代理优先！直连 Docker Hub 容易卡死
    for src in \
        "docker.xuanyuan.me/$img" \
        "docker.xuanyuan.me/library/$img" \
        "mrauqknj.mirror.aliyuncs.com/$img" \
        "mrauqknj.mirror.aliyuncs.com/library/$img" \
        "docker.m.daocloud.io/$img" \
        "docker.1panel.live/$img" \
        "$img"; do
        echo "  尝试: $src"
        if timeout 30 docker pull "$src" 2>&1 | tail -1 | grep -qE "Downloaded|exists|Pulled"; then
            [ "$src" != "$img" ] && docker tag "$src" "$img" 2>/dev/null
            log "拉取成功: $img"
            return 0
        fi
    done
    warn "无法拉取: $img"
    return 1
}

echo ""
echo "📥 拉取镜像..."
pull_image "mysql:8.0"
pull_image "redis:7-alpine"
pull_image "nacos/nacos-server:v2.3.2" || warn "Nacos 拉取失败，跳过，用原生安装"

# ---- 4. 清理旧容器 ----
docker rm -f mall-mysql mall-redis mall-nacos 2>/dev/null || true
docker network create mall-net 2>/dev/null || true

# ---- 5. 启动 MySQL ----
echo ""
echo "🐳 启动 MySQL (:$MYSQL_PORT)..."
docker run -d --name mall-mysql \
    --network mall-net \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_PASS}" \
    -e MYSQL_DATABASE=mall \
    -e TZ=Asia/Shanghai \
    -p ${MYSQL_PORT}:3306 \
    -v mall-mysql-data:/var/lib/mysql \
    -v "${PROJECT_DIR}/sql/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro" \
    --restart unless-stopped \
    mysql:8.0 \
    --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci \
    --default-time-zone=+08:00 --default-authentication-plugin=mysql_native_password

echo "⏳ 等待 MySQL 就绪..."
for i in $(seq 1 30); do
    if docker exec mall-mysql mysqladmin ping -h localhost -u root -p"${MYSQL_PASS}" --silent 2>/dev/null; then
        log "MySQL 已就绪"
        break
    fi
    sleep 2
done

# ---- 6. 启动 Redis ----
echo "🐳 启动 Redis (:$REDIS_PORT)..."
docker run -d --name mall-redis \
    --network mall-net \
    -p ${REDIS_PORT}:6379 \
    -v mall-redis-data:/data \
    --restart unless-stopped \
    redis:7-alpine \
    redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
log "Redis 已就绪"

# ---- 7. 启动 Nacos ----
echo "🐳 启动 Nacos (:$NACOS_PORT)..."
if docker image inspect "nacos/nacos-server:v2.3.2" &>/dev/null; then
    docker run -d --name mall-nacos \
        --network host \
        -e MODE=standalone \
        -e SERVER_PORT=${NACOS_PORT} \
        -e EMBEDDED_STORAGE=embedded \
        -e NACOS_AUTH_ENABLE=false \
        -v mall-nacos-data:/home/nacos/data \
        --restart unless-stopped \
        nacos/nacos-server:v2.3.2
    log "Nacos 已就绪"
else
    warn "Nacos 镜像不可用，手动安装: bash install-nacos-native.sh"
fi

# ---- 8. 保存端口信息 ----
cat > "$ENV_FILE" << EOF
# 微服务商城 — 端口配置（由 start.sh 生成，deploy.sh 读取）
SERVER_IP=$SERVER_IP
MYSQL_PORT=$MYSQL_PORT
REDIS_PORT=$REDIS_PORT
NACOS_PORT=$NACOS_PORT
MYSQL_PASSWORD=$MYSQL_PASS
NACOS_SERVER=$SERVER_IP:$NACOS_PORT
MYSQL_URL=jdbc:mysql://$SERVER_IP:$MYSQL_PORT/mall?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai
REDIS_HOST=$SERVER_IP
REDIS_PORT=$REDIS_PORT
EOF
log "端口信息已保存: $ENV_FILE"

# ---- 9. 总结 ----
echo ""
echo "========================================"
echo " ✅ 中间件部署完成"
echo "========================================"
echo ""
echo "  MySQL:  $SERVER_IP:$MYSQL_PORT  (root / ${MYSQL_PASS})"
echo "  Redis:  $SERVER_IP:$REDIS_PORT"
echo "  Nacos:  http://$SERVER_IP:$NACOS_PORT/nacos"
echo ""
echo "⚠️  安全组放行端口: $MYSQL_PORT, $REDIS_PORT, $NACOS_PORT"
echo ""
echo "下一步: bash server-setup/deploy.sh all"
