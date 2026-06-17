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

# ========== 服务列表 ==========
# 格式: "服务名:端口:jar路径"
SERVICES=(
  "gateway:8080:$APP_DIR/gateway/target/gateway-1.0.0.jar"
  "auth-service:8081:$APP_DIR/auth-service/target/auth-service-1.0.0.jar"
  "product-service:8083:$APP_DIR/product-service/target/product-service-1.0.0.jar"
  "order-service:8084:$APP_DIR/order-service/target/order-service-1.0.0.jar"
  "payment-service:8085:$APP_DIR/payment-service/target/payment-service-1.0.0.jar"
)

# 加载基础设施端口
if [ -f "$SETUP_DIR/.env" ]; then
  source "$SETUP_DIR/.env"
fi
if [ -f "$SETUP_DIR/services-ports.env" ]; then
  source "$SETUP_DIR/services-ports.env"
fi

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
  if [ ! -f "$SETUP_DIR/docker-compose.yml" ]; then
    err "docker-compose.yml 不存在，请先上传 server-setup 目录"
    exit 1
  fi

  # 首次运行生成随机端口
  if [ ! -f "$SETUP_DIR/.env" ]; then
    info "首次运行，生成随机端口..."
    source "$SETUP_DIR/start.sh" _gen_only
  else
    source "$SETUP_DIR/.env"
  fi

  # 启动 Docker 容器
  cd "$SETUP_DIR"
  docker compose up -d 2>&1 | tail -3
  log "基础组件已启动 (Nacos:$NACOS_PORT MySQL:$MYSQL_PORT Redis:$REDIS_PORT)"
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
  info "Maven 编译..."
  cd "$APP_DIR"
  mvn clean package -DskipTests -q 2>&1 | tail -3
  log "编译完成"

  # 3. 加载环境变量
  if [ -f "$SETUP_DIR/services-ports.env" ]; then
    source "$SETUP_DIR/services-ports.env"
  fi

  # 4. 停止旧进程
  info "停止旧进程..."
  for svc in "${SERVICES[@]}"; do
    IFS=':' read -r name port jar <<< "$svc"
    pid=$(lsof -ti :$port 2>/dev/null || true)
    if [ -n "$pid" ]; then
      kill $pid 2>/dev/null && warn "已停止 $name (PID:$pid)"
    fi
  done
  sleep 2

  # 5. 启动服务
  info "启动服务 (profile=server)..."
  for svc in "${SERVICES[@]}"; do
    IFS=':' read -r name port jar <<< "$svc"
    if [ ! -f "$jar" ]; then
      err "$name JAR 不存在: $jar"
      continue
    fi
    nohup java -Xms256m -Xmx512m \
      -Dspring.profiles.active=server \
      -DNACOS_SERVER="${NACOS_SERVER:-47.108.130.167:8848}" \
      -DMYSQL_URL="${MYSQL_URL}" \
      -DMYSQL_PASSWORD="${MYSQL_PASSWORD}" \
      -DREDIS_HOST="${REDIS_HOST:-47.108.130.167}" \
      -DREDIS_PORT="${REDIS_PORT:-6379}" \
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
    IFS=':' read -r name port jar <<< "$svc"
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
    docker compose -f "$SETUP_DIR/docker-compose.yml" ps 2>/dev/null | tail -4
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
    cd "$SETUP_DIR" && docker compose stop 2>/dev/null && log "基础组件已停止"
  fi

  if [ "$target" = "app" ] || [ "$target" = "all" ]; then
    for svc in "${SERVICES[@]}"; do
      IFS=':' read -r name port jar <<< "$svc"
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
echo "  API 网关: http://47.108.130.167:8080"
echo "  Nacos:    http://47.108.130.167:${NACOS_PORT:-?}/nacos"
echo "============================================"
