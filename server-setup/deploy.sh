#!/bin/bash
# ============================================
# 微服务商城 — 应用部署脚本
# 用法:
#   bash deploy.sh build     # 编译所有后端服务
#   bash deploy.sh start     # 启动所有后端服务
#   bash deploy.sh stop      # 停止后端服务
#   bash deploy.sh status    # 查看服务状态
#   bash deploy.sh frontend  # 部署前端 (Nginx)
#   bash deploy.sh all       # 全部: 编译 + 启动 + 前端
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
mkdir -p "$LOG_DIR" "$PID_DIR"

SERVER_IP="47.108.130.167"
DB_PASS="${MYSQL_ROOT_PASSWORD:-Mall@2024!}"

# ============ 微服务列表 ============
# 格式: "服务名:端口:模块目录"
SERVICES=(
    "gateway:8080:gateway"
    "auth-service:8081:auth-service"
    "product-service:8083:product-service"
    "order-service:8084:order-service"
    "payment-service:8085:payment-service"
)

export NACOS_SERVER="${SERVER_IP}:8848"
export MYSQL_URL="jdbc:mysql://${SERVER_IP}:3306/mall?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai"
export MYSQL_PASSWORD="${DB_PASS}"
export REDIS_HOST="${SERVER_IP}"
export REDIS_PORT="6379"
export REDIS_PASSWORD=""

# ============ 编译 ============
do_build() {
    echo ""
    echo "========================================"
    echo " 📦 Maven 编译"
    echo "========================================"
    cd "$PROJECT_DIR"

    if ! command -v mvn &>/dev/null; then
        echo "❌ Maven 未安装! 运行: apt install -y maven"
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

    # 先停旧进程
    do_stop

    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name port module <<< "$svc"

        # 找 JAR 包
        local jar=$(ls "$PROJECT_DIR/$module/target/"*.jar 2>/dev/null | grep -v sources | head -1)
        if [ -z "$jar" ] || [ ! -f "$jar" ]; then
            warn "$name: JAR 不存在，需要先编译: bash deploy.sh build"
            continue
        fi

        info "启动 $name (:$port)..."
        nohup java -Xms128m -Xmx384m \
            -Dserver.port="$port" \
            -Dspring.profiles.active=server \
            -DNACOS_SERVER="$NACOS_SERVER" \
            -DMYSQL_URL="$MYSQL_URL" \
            -DMYSQL_PASSWORD="$MYSQL_PASSWORD" \
            -DREDIS_HOST="$REDIS_HOST" \
            -DREDIS_PORT="$REDIS_PORT" \
            -jar "$jar" \
            > "$LOG_DIR/$name.log" 2>&1 &
        echo $! > "$PID_DIR/$name.pid"
        log "$name 已启动 (PID: $(cat $PID_DIR/$name.pid))"
        sleep 3  # 错开启动，避免同时注册 Nacos
    done

    echo ""
    info "等待服务就绪..."
    sleep 10
    do_status
}

# ============ 停止 ============
do_stop() {
    echo "停止后端服务..."
    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name port module <<< "$svc"
        local pid=$(cat "$PID_DIR/$name.pid" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null && log "已停止 $name"
        fi
        rm -f "$PID_DIR/$name.pid"
    done
    sleep 2
}

# ============ 状态 ============
do_status() {
    echo ""
    echo "--- 服务状态 ---"
    printf "  %-20s %-8s %s\n" "服务" "端口" "状态"
    printf "  %-20s %-8s %s\n" "────" "────" "────"
    for svc in "${SERVICES[@]}"; do
        IFS=':' read -r name port module <<< "$svc"
        local code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port 2>/dev/null || echo "000")
        if [ "$code" != "000" ]; then
            printf "  ${GREEN}%-20s${NC} %-8s ${GREEN}运行中 (%s)${NC}\n" "$name" "$port" "$code"
        else
            printf "  ${RED}%-20s${NC} %-8s ${RED}未启动${NC}\n" "$name" "$port"
        fi
    done
}

# ============ 前端部署 ============
do_frontend() {
    echo ""
    echo "========================================"
    echo " 🌐 部署前端"
    echo "========================================"

    # 安装 Nginx
    if ! command -v nginx &>/dev/null; then
        info "安装 Nginx..."
        apt-get update -qq && apt-get install -y -qq nginx
    fi

    # 构建前端（如果本地没构建）
    local dist_dir="$PROJECT_DIR/frontend/dist"
    if [ ! -d "$dist_dir" ]; then
        info "构建前端..."
        cd "$PROJECT_DIR/frontend"
        if command -v npm &>/dev/null; then
            npm install --silent && npm run build
        else
            warn "npm 未安装，跳过前端构建"
            return
        fi
    fi

    # 部署到 Nginx
    local nginx_dir="/var/www/mall"
    rm -rf "$nginx_dir"
    cp -r "$dist_dir" "$nginx_dir"

    # Nginx 配置
    cat > /etc/nginx/sites-available/mall << 'NGINX'
server {
    listen 80;
    server_name _;

    root /var/www/mall;
    index index.html;

    # 前端静态文件
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 代理到网关
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Swagger 代理
    location /swagger-ui {
        proxy_pass http://127.0.0.1:8080;
    }
    location /v3/api-docs {
        proxy_pass http://127.0.0.1:8080;
    }
}
NGINX

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/mall /etc/nginx/sites-enabled/mall
    nginx -t && systemctl reload nginx
    log "前端已部署: http://${SERVER_IP}"
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
echo "  API 网关: http://${SERVER_IP}:8080"
echo "  Swagger:  http://${SERVER_IP}:8080/swagger-ui.html"
echo "  前端:     http://${SERVER_IP}"
echo "========================================"
