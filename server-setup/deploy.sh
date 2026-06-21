#!/bin/bash
# ============================================
# 微服务商城 — 应用部署（随机5位端口）
# 用法:
#   bash deploy.sh build     # Maven 编译
#   bash deploy.sh start     # 启动后端 5 个微服务
#   bash deploy.sh stop      # 停止后端
#   bash deploy.sh status    # 查看状态
#   bash deploy.sh frontend  # 构建前端 + Nginx 部署
#   bash deploy.sh all       # 编译 + 启动 + 前端
# ============================================
set -e

GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' RED='\033[0;31m' NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$SCRIPT_DIR/logs"
PID_DIR="$SCRIPT_DIR/pids"
ENV_FILE="$SCRIPT_DIR/services-ports.env"
mkdir -p "$LOG_DIR" "$PID_DIR"

# ---- 随机5位端口 ----
gen_port() {
    local port
    while :; do
        port=$((10000 + RANDOM % 55535))
        (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null || break
    done
    echo $port
}

# ---- 加载中间件端口 ----
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "❌ 请先运行 start.sh 启动中间件！"
    exit 1
fi

SERVER_IP="${SERVER_IP:-47.108.130.167}"
APP_ENV_FILE="$SCRIPT_DIR/app-ports.env"

# 先加载已有端口（如果有），再生成缺失的
source "$APP_ENV_FILE" 2>/dev/null || true
[ -z "$GW_PORT" ]      && GW_PORT=$(gen_port)
[ -z "$AUTH_PORT" ]    && AUTH_PORT=$(gen_port)
[ -z "$PRODUCT_PORT" ] && PRODUCT_PORT=$(gen_port)
[ -z "$ORDER_PORT" ]   && ORDER_PORT=$(gen_port)
[ -z "$PAYMENT_PORT" ] && PAYMENT_PORT=$(gen_port)

# 服务列表: "服务名:端口变量名:端口值:模块目录"
SERVICES=(
    "gateway:GW_PORT:$GW_PORT:gateway"
    "auth-service:AUTH_PORT:$AUTH_PORT:auth-service"
    "product-service:PRODUCT_PORT:$PRODUCT_PORT:product-service"
    "order-service:ORDER_PORT:$ORDER_PORT:order-service"
    "payment-service:PAYMENT_PORT:$PAYMENT_PORT:payment-service"
)

# 保存后端端口到独立文件（每次启动覆盖，避免重复追加）
cat > "$APP_ENV_FILE" << EOF
GW_PORT=$GW_PORT
AUTH_PORT=$AUTH_PORT
PRODUCT_PORT=$PRODUCT_PORT
ORDER_PORT=$ORDER_PORT
PAYMENT_PORT=$PAYMENT_PORT
EOF

# 构建环境变量（供 Java -D 使用）
export NACOS_SERVER="${NACOS_SERVER:-$SERVER_IP:$NACOS_PORT}"
export MYSQL_URL="${MYSQL_URL:-jdbc:mysql://$SERVER_IP:$MYSQL_PORT/mall?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai}"
export MYSQL_PASSWORD="${MYSQL_PASSWORD:-Mall@2024!}"
export REDIS_HOST="${REDIS_HOST:-$SERVER_IP}"
export REDIS_PORT="${REDIS_PORT:-6379}"

# ============ 编译 ============
do_build() {
    echo ""
    echo "========================================"
    echo " 📦 Maven 编译"
    echo "========================================"
    cd "$PROJECT_DIR"

    if ! command -v mvn &>/dev/null; then
        echo "❌ Maven 未安装! apt install -y maven"
        exit 1
    fi

    info "编译中 (跳过测试)..."
    mvn clean package -DskipTests -q 2>&1 | tail -10

    local jar_count=$(find . -name "*.jar" -path "*/target/*" ! -name "*sources*" ! -name "*test*" | wc -l)
    log "编译完成 ($jar_count 个 JAR)"
}

# ============ 启动 ============
do_start() {
    echo ""
    echo "========================================"
    echo " 🚀 启动微服务"
    echo "========================================"
    cd "$PROJECT_DIR"
    do_stop  # 先停旧的

    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name port_key port_val module <<< "$svc"
        local jar=$(ls "$PROJECT_DIR/$module/target/"*.jar 2>/dev/null | grep -v sources | head -1)
        if [ -z "$jar" ] || [ ! -f "$jar" ]; then
            warn "$name: JAR 不存在，需先编译"
            continue
        fi

        info "启动 $name (:$port_val)..."

        # 网关特殊处理: 需要将端口写入 Nacos 路由配置
        local extra_opts=""
        if [ "$name" = "gateway" ]; then
            extra_opts="-DGATEWAY_PORT=$port_val"
        fi

        nohup java -Xms128m -Xmx384m \
            -Dserver.port="$port_val" \
            -Dspring.profiles.active=server \
            -DNACOS_SERVER="$NACOS_SERVER" \
            -DMYSQL_URL="$MYSQL_URL" \
            -DMYSQL_PASSWORD="$MYSQL_PASSWORD" \
            -DREDIS_HOST="$REDIS_HOST" \
            -DREDIS_PORT="$REDIS_PORT" \
            $extra_opts \
            -jar "$jar" \
            > "$LOG_DIR/$name.log" 2>&1 &
        echo $! > "$PID_DIR/$name.pid"
        log "$name 已启动 (PID: $(cat $PID_DIR/$name.pid))"
        sleep 3
    done

    echo ""
    info "等待服务就绪 (10s)..."
    sleep 10
    do_status
}

# ============ 停止 ============
do_stop() {
    echo "停止后端服务..."
    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name port_key port_val module <<< "$svc"
        local pid=$(cat "$PID_DIR/$name.pid" 2>/dev/null || true)
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null && log "已停止 $name"
        rm -f "$PID_DIR/$name.pid"
    done
    sleep 2
}

# ============ 状态 ============
do_status() {
    echo ""
    printf "  %-20s %-8s %s\n" "服务" "端口" "状态"
    printf "  %-20s %-8s %s\n" "────" "────" "────"
    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name port_key port_val module <<< "$svc"
        local code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port_val 2>/dev/null || echo "000")
        if [ "$code" != "000" ]; then
            printf "  ${GREEN}%-20s${NC} %-8s ${GREEN}运行中${NC}\n" "$name" "$port_val"
        else
            printf "  ${RED}%-20s${NC} %-8s ${RED}未启动${NC}\n" "$name" "$port_val"
        fi
    done
    echo ""
    echo "中间件:"
    printf "  %-20s %-8s\n" "MySQL"  "$SERVER_IP:$MYSQL_PORT"
    printf "  %-20s %-8s\n" "Redis"  "$SERVER_IP:$REDIS_PORT"
    printf "  %-20s %-8s\n" "Nacos"  "$SERVER_IP:$NACOS_PORT"
}

# ============ 前端 ============
do_frontend() {
    echo ""
    echo "========================================"
    echo " 🌐 部署前端"
    echo "========================================"

    source "$ENV_FILE" 2>/dev/null || true
    source "$APP_ENV_FILE" 2>/dev/null || true
    local gw_port="${GW_PORT:-8080}"
    local web_port=$(gen_port)

    # 安装 Nginx
    if ! command -v nginx &>/dev/null; then
        info "安装 Nginx..."
        apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx
    fi

    # 构建前端
    local dist_dir="$PROJECT_DIR/frontend/dist"
    if [ ! -d "$dist_dir" ]; then
        info "构建前端..."
        cd "$PROJECT_DIR/frontend"
        if command -v npm &>/dev/null; then
            npm install --silent 2>/dev/null || npm install
            npx vite build --base=/ 2>&1 | tail -5
        else
            warn "npm 未安装，跳过前端构建"
            return
        fi
    fi

    # 部署
    local nginx_dir="/var/www/mall"
    rm -rf "$nginx_dir" 2>/dev/null
    cp -r "$dist_dir" "$nginx_dir"

    # Nginx 配置（用实际的网关端口）
    cat > /etc/nginx/sites-available/mall << NGINX
server {
    listen ${web_port};
    server_name _;

    root /var/www/mall;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:${gw_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_connect_timeout 30s;
        proxy_read_timeout 60s;
    }

    location /swagger-ui {
        proxy_pass http://127.0.0.1:${gw_port};
    }
    location /v3/api-docs {
        proxy_pass http://127.0.0.1:${gw_port};
    }
}
NGINX

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/mall /etc/nginx/sites-enabled/mall
    nginx -t 2>&1 && systemctl reload nginx 2>/dev/null || nginx -s reload 2>/dev/null

    # 保存前端端口
    echo "WEB_PORT=$web_port" >> "$ENV_FILE"
    log "前端已部署: http://${SERVER_IP}:${web_port}"
}

# ============ 路由 ============
case "${1:-all}" in
    build)    do_build ;;
    start)    do_start ;;
    stop)     do_stop ;;
    status)   do_status ;;
    frontend) do_frontend ;;
    all)
        do_build
        do_start
        do_frontend
        ;;
    *)
        echo "用法: bash deploy.sh [build|start|stop|status|frontend|all]"
        ;;
esac

echo ""
echo "========================================"
echo -e " ${GREEN}部署完成${NC}"
echo "  网关:     http://${SERVER_IP}:${GW_PORT}"
echo "  Swagger:  http://${SERVER_IP}:${GW_PORT}/swagger-ui.html"
echo "  Nacos:    http://${SERVER_IP}:${NACOS_PORT}/nacos"
[ -n "$web_port" ] && echo "  前端:     http://${SERVER_IP}:${web_port}"
echo "========================================"
