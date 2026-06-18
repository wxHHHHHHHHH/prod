#!/bin/bash
# ============================================================
# 微服务商城 — 服务器一键部署脚本
# 用法:
#   bash deploy.sh              # 部署全部(基础组件+应用)
#   bash deploy.sh infra        # 只部署基础组件(Nacos/MySQL/Redis)
#   bash deploy.sh app          # 只部署应用(编译+启动)
#   bash deploy.sh status       # 查看服务状态
#   bash deploy.sh stop         # 停止所有服务
#   bash deploy.sh restart app  # 重启应用
#   bash deploy.sh logs svc     # 查看指定服务日志
# ============================================================
set -e

GREEN='\033[0;32m'  YELLOW='\033[1;33m'  CYAN='\033[0;36m'  RED='\033[0;31m'  NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$(dirname "$SETUP_DIR")"           # server-setup 上级目录即项目根
LOG_DIR="$SETUP_DIR/logs"
PID_DIR="$SETUP_DIR/pids"

mkdir -p "$LOG_DIR" "$PID_DIR"

STEP="${1:-all}"
SERVICE="${2:-}"

# ========== 端口随机生成 ==========
gen_port() {
  local port
  while :; do
    port=$((10000 + RANDOM % 55535))
    (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null || break
  done
  echo $port
}

# 加载或生成端口
if [ -f "$SETUP_DIR/.env" ]; then
  source "$SETUP_DIR/.env"
else
  # 基础设施端口
  NACOS_PORT=$(gen_port)
  MYSQL_PORT=$(gen_port)
  REDIS_PORT=$(gen_port)
  MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12 2>/dev/null || echo "Mall@$(date +%s)")
fi

# 微服务端口(首次随机)
[ -z "$GW_PORT" ] && GW_PORT=$(gen_port)
[ -z "$AUTH_PORT" ] && AUTH_PORT=$(gen_port)
[ -z "$PRODUCT_PORT" ] && PRODUCT_PORT=$(gen_port)
[ -z "$ORDER_PORT" ] && ORDER_PORT=$(gen_port)
[ -z "$PAYMENT_PORT" ] && PAYMENT_PORT=$(gen_port)

# 保存端口
cat > "$SETUP_DIR/.env" <<EOF
NACOS_PORT=$NACOS_PORT
MYSQL_PORT=$MYSQL_PORT
REDIS_PORT=$REDIS_PORT
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=mall
GW_PORT=$GW_PORT
AUTH_PORT=$AUTH_PORT
PRODUCT_PORT=$PRODUCT_PORT
ORDER_PORT=$ORDER_PORT
PAYMENT_PORT=$PAYMENT_PORT
EOF

# 端口信息供微服务读取
cat > "$SETUP_DIR/services-ports.env" <<EOF
NACOS_SERVER=47.108.130.167:$NACOS_PORT
MYSQL_URL=jdbc:mysql://47.108.130.167:$MYSQL_PORT/mall
REDIS_HOST=47.108.130.167
REDIS_PORT=$REDIS_PORT
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD
EOF

# ========== 服务列表 ==========
# 格式: "服务名:端口变量:jar路径"
SERVICES=(
  "gateway:$GW_PORT:$APP_DIR/gateway/target/gateway-*.jar"
  "auth-service:$AUTH_PORT:$APP_DIR/auth-service/target/auth-service-*.jar"
  "product-service:$PRODUCT_PORT:$APP_DIR/product-service/target/product-service-*.jar"
  "order-service:$ORDER_PORT:$APP_DIR/order-service/target/order-service-*.jar"
  "payment-service:$PAYMENT_PORT:$APP_DIR/payment-service/target/payment-service-*.jar"
)

echo ""
echo "============================================"
echo "  微服务商城 — 部署工具"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"

# ============================================================
# 部署基础设施
# ============================================================
deploy_infra() {
  echo ""
  echo "--- 部署基础设施 ---"

  # 1. 安装 Docker（如果没有）
  if ! command -v docker &>/dev/null; then
    info "安装 Docker..."
    # 尝试 yum（Alibaba Cloud Linux / CentOS）
    if yum install -y docker 2>/dev/null; then
      log "yum install docker 成功"
    elif apt-get install -y docker.io 2>/dev/null; then
      log "apt-get install docker 成功"
    else
      err "无法安装 Docker，请手动安装: yum install -y docker"
      exit 1
    fi
    systemctl enable docker 2>/dev/null || true
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
    log "Docker 安装完成"
  fi
  # 2. 配置 Docker 国内镜像加速（始终覆盖）
  info "配置 Docker 镜像加速..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<'DOCKERJSON'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ]
}
DOCKERJSON
    sudo systemctl daemon-reload 2>/dev/null; sudo systemctl restart docker 2>/dev/null || sudo service docker restart 2>/dev/null || true
    log "Docker 镜像加速已配置"
    info "验证镜像加速..."
    sleep 2
    docker info 2>/dev/null | grep -A3 "Registry Mirrors" || true

  # 3. 创建数据目录+初始化SQL
  DATA_DIR="$SETUP_DIR/services"
  mkdir -p "$DATA_DIR"/{mysql-data,redis-data}

  cat > "$DATA_DIR/init.sql" <<'SQL'
CREATE DATABASE IF NOT EXISTS mall CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mall;
CREATE TABLE IF NOT EXISTS mall_user (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(200) NOT NULL,
  nickname VARCHAR(50),
  phone VARCHAR(20), email VARCHAR(100), avatar VARCHAR(500),
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT DEFAULT 0
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS mall_product (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL, description TEXT,
  price DECIMAL(10,2) NOT NULL, stock INT DEFAULT 0,
  image_url VARCHAR(500), category VARCHAR(50), status TINYINT DEFAULT 1,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS mall_order (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_no VARCHAR(64) NOT NULL UNIQUE,
  user_id BIGINT NOT NULL, product_id BIGINT NOT NULL,
  product_name VARCHAR(200), quantity INT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL, total_amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) DEFAULT 'PENDING', pay_time DATETIME,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS mall_payment (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  pay_no VARCHAR(64) NOT NULL UNIQUE,
  order_id BIGINT NOT NULL, user_id BIGINT NOT NULL,
  amount DECIMAL(10,2) NOT NULL, pay_type VARCHAR(20) DEFAULT 'ALIPAY',
  status VARCHAR(20) DEFAULT 'PENDING', third_party_no VARCHAR(100),
  pay_time DATETIME,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;
INSERT IGNORE INTO mall_user (username, password, nickname) VALUES
('admin', '$2a$10$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', '管理员');
INSERT IGNORE INTO mall_product (name, description, price, stock, category, status) VALUES
('Spring Cloud Alibaba 实战', '从零入门微服务', 99.00, 1000, '电子书', 1),
('Java 面试八股文 2026', 'Java/Spring/微服务/并发/JVM', 49.90, 500, '电子书', 1),
('机械键盘 Cherry 青轴', '87键 白光版', 299.00, 50, '数码', 1);
SQL

  # 4. 拉取镜像 + 启动容器（docker run，无需 compose）
  info "拉取镜像..."
  docker pull mysql:8.0 2>&1 | tail -3
  docker pull nacos/nacos-server:v2.3.1 2>&1 | tail -3
  docker pull redis:7-alpine 2>&1 | tail -3

  info "启动容器..."
  docker rm -f mall-mysql mall-nacos mall-redis 2>/dev/null || true

  docker run -d --name mall-mysql \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
    -e MYSQL_DATABASE=mall \
    -e TZ=Asia/Shanghai \
    -p ${MYSQL_PORT}:3306 \
    -v "$DATA_DIR/mysql-data:/var/lib/mysql" \
    -v "$DATA_DIR/init.sql:/docker-entrypoint-initdb.d/init.sql" \
    --restart unless-stopped \
    mysql:8.0

  docker run -d --name mall-nacos \
    -e MODE=standalone \
    -e PREFER_HOST_MODE=hostname \
    -e NACOS_AUTH_ENABLE=false \
    -p ${NACOS_PORT}:8848 \
    --restart unless-stopped \
    nacos/nacos-server:v2.3.1

  docker run -d --name mall-redis \
    -p ${REDIS_PORT}:6379 \
    -v "$DATA_DIR/redis-data:/data" \
    --restart unless-stopped \
    redis:7-alpine redis-server --appendonly yes

  log "Nacos: $NACOS_PORT   MySQL: $MYSQL_PORT   Redis: $REDIS_PORT"
}

# ============================================================
# 部署应用
# ============================================================
deploy_app() {
  echo ""
  echo "--- 部署应用 ---"

  # 1. 拉最新代码
  info "拉取最新代码..."
  cd "$APP_DIR" && git pull 2>&1 | tail -1

  # 2. 编译
  info "Maven 编译（跳过测试）..."
  cd "$APP_DIR"
  if ! command -v mvn &>/dev/null; then
    err "Maven 未安装！yum install -y maven"
    exit 1
  fi
  mvn clean package -DskipTests 2>&1 | tail -20
  JAR_COUNT=$(find . -name "*.jar" -path "*/target/*" ! -name "*sources*" | wc -l)
  [ "$JAR_COUNT" -lt 3 ] && { err "编译失败(JAR=$JAR_COUNT)"; exit 1; }
  log "编译完成 ($JAR_COUNT 个JAR)"

  # 3. 加载环境变量
  if [ -f "$SETUP_DIR/services-ports.env" ]; then
    source "$SETUP_DIR/services-ports.env"
  fi

  # 4. 停止旧进程
  info "停止旧进程..."
  for svc in "${SERVICES[@]}"; do
    IFS=':' read -r name port pattern <<< "$svc"
    pid=$(lsof -ti :$port 2>/dev/null || true)
    if [ -n "$pid" ]; then
      kill $pid 2>/dev/null && warn "已停止 $name (PID:$pid)"
    fi
  done
  sleep 2

  # 5. 启动服务
  info "启动服务 (profile=server)..."
  for svc in "${SERVICES[@]}"; do
    IFS=':' read -r name port pattern <<< "$svc"
    jar=$(ls $pattern 2>/dev/null | head -1)
    if [ -z "$jar" ] || [ ! -f "$jar" ]; then
      err "$name JAR 不存在: $pattern"
      continue
    fi
    nohup java -Xms256m -Xmx512m \
      -Dserver.port=$port \
      -Dspring.profiles.active=server \
      -DNACOS_SERVER="47.108.130.167:${NACOS_PORT}" \
      -DMYSQL_URL="jdbc:mysql://47.108.130.167:${MYSQL_PORT}/mall" \
      -DMYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
      -DREDIS_HOST="47.108.130.167" \
      -DREDIS_PORT="${REDIS_PORT}" \
      -jar "$jar" \
      > "$LOG_DIR/$name.log" 2>&1 &
    echo $! > "$PID_DIR/$name.pid"
    log "$name 已启动 (port $port, PID $(cat $PID_DIR/$name.pid))"
    sleep 2
  done

  echo ""
  info "等待服务就绪..."
  sleep 8
  check_status
}

# ============================================================
# 状态检查
# ============================================================
check_status() {
  echo ""
  echo "--- 服务状态 ---"
  printf "  %-20s %-8s %s\n" "服务" "端口" "状态"
  printf "  %-20s %-8s %s\n" "────" "────" "────"
  for svc in "${SERVICES[@]}"; do
    IFS=':' read -r name port pattern <<< "$svc"
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$port 2>/dev/null | grep -q "200\|302\|404\|401"; then
      printf "  ${GREEN}%-20s${NC} %-8s ${GREEN}运行中${NC}\n" "$name" "$port"
    else
      printf "  ${RED}%-20s${NC} %-8s ${RED}未启动${NC}\n" "$name" "$port"
    fi
  done
  echo ""

  # 基础设施状态
  if command -v docker &>/dev/null; then
    echo "基础组件:"
    docker ps --filter "name=mall-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
  fi
}

# ============================================================
# 停止服务
# ============================================================
stop_services() {
  local target="${1:-all}"
  echo ""
  info "停止服务..."

  if [ "$target" = "infra" ] || [ "$target" = "all" ]; then
    docker stop mall-mysql mall-nacos mall-redis 2>/dev/null && log "基础组件已停止"
  fi

  if [ "$target" = "app" ] || [ "$target" = "all" ]; then
    for svc in "${SERVICES[@]}"; do
      IFS=':' read -r name port pattern <<< "$svc"
      pid=$(lsof -ti :$port 2>/dev/null || cat "$PID_DIR/$name.pid" 2>/dev/null)
      if [ -n "$pid" ]; then
        kill $pid 2>/dev/null && log "已停止 $name"
      fi
      rm -f "$PID_DIR/$name.pid"
    done
  fi
}

# ============================================================
# 查看日志
# ============================================================
view_logs() {
  local svc="$1"
  if [ -n "$svc" ]; then
    tail -f "$LOG_DIR/$svc.log" 2>/dev/null || err "日志不存在: $svc"
  else
    tail -f "$LOG_DIR"/*.log
  fi
}

# ============================================================
# 路由
# ============================================================
case "$STEP" in
  all)
    deploy_infra
    deploy_app
    ;;
  infra)
    deploy_infra
    ;;
  app)
    deploy_app
    ;;
  status)
    check_status
    ;;
  stop)
    stop_services "${SERVICE:-all}"
    ;;
  restart)
    if [ "$SERVICE" = "app" ] || [ "$SERVICE" = "all" ]; then
      stop_services app
      sleep 3
      deploy_app
    else
      stop_services infra
      deploy_infra
    fi
    ;;
  logs)
    view_logs "$SERVICE"
    ;;
  *)
    echo "用法: bash deploy.sh [all|infra|app|status|stop|restart|logs] [服务名]"
    echo ""
    echo "  all             部署全部(默认)"
    echo "  infra           只部署基础组件"
    echo "  app             只部署应用"
    echo "  status          查看状态"
    echo "  stop            停止全部"
    echo "  stop app        只停应用"
    echo "  restart app     重启应用"
    echo "  logs gateway    查看指定服务日志"
    ;;
esac

echo ""
echo "============================================"
echo -e "  ${GREEN}完成${NC}"
echo "  API 网关: http://47.108.130.167:${GW_PORT}"
  echo "  Nacos:    http://47.108.130.167:${NACOS_PORT}/nacos"
echo "============================================"
