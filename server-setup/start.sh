#!/bin/bash
# ============================================
# 微服务商城 — 基础设施部署 (Nacos/MySQL/Redis)
# 推荐通过 deploy.sh 调用: bash deploy.sh infra
# ============================================
set -e

GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

# ========== 生成随机端口 ==========
# 在 10000-60000 范围内生成,避开常用端口
gen_port() {
  local port
  while :; do
    port=$((10000 + RANDOM % 55535))
    # 检查端口是否被占用
    (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null || break
  done
  echo $port
}

SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_DIR="$SETUP_DIR/services"

# 首次运行生成随机端口并保存，后续复用
if [ -f "$SETUP_DIR/.env" ]; then
  source "$SETUP_DIR/.env"
  info "复用已保存的端口: Nacos=$NACOS_PORT  MySQL=$MYSQL_PORT  Redis=$REDIS_PORT"
else
  NACOS_PORT=$(gen_port)
  MYSQL_PORT=$(gen_port)
  REDIS_PORT=$(gen_port)
  MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12 2>/dev/null || echo "Mall@$(date +%s)")
  cat > "$SETUP_DIR/.env" <<EOF
NACOS_PORT=$NACOS_PORT
MYSQL_PORT=$MYSQL_PORT
REDIS_PORT=$REDIS_PORT
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=mall
EOF
  log "首次运行，随机端口: Nacos=$NACOS_PORT  MySQL=$MYSQL_PORT  Redis=$REDIS_PORT"
fi

source "$SETUP_DIR/.env"

source "$SETUP_DIR/.env"

echo ""
echo "============================================"
echo "  微服务基础组件 — Docker 部署"
echo "============================================"
info "部署目录: $SETUP_DIR"
info "Nacos  端口: $NACOS_PORT"
info "MySQL  端口: $MYSQL_PORT"
info "Redis  端口: $REDIS_PORT"
echo ""

# ========== 1. 检查 Docker ==========
if ! command -v docker &>/dev/null; then
  echo "Docker 未安装，正在安装..."
  curl -fsSL https://get.docker.com | bash
  sudo systemctl enable docker && sudo systemctl start docker
fi

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
  sudo apt-get update -y && sudo apt-get install -y docker-compose-plugin 2>/dev/null || \
  sudo yum install -y docker-compose-plugin 2>/dev/null
fi
log "Docker 环境就绪"

# ========== 2. 创建服务目录 ==========
mkdir -p "$SERVICE_DIR"/{mysql-data,redis-data,nacos-logs}

# ========== 3. 生成 docker-compose.yml ==========
cat > "$SETUP_DIR/docker-compose.yml" <<'COMPOSE'
version: '3.8'
services:
  nacos:
    image: nacos/nacos-server:v2.3.1
    container_name: mall-nacos
    environment:
      - MODE=standalone
      - PREFER_HOST_MODE=hostname
      - NACOS_AUTH_ENABLE=false
    ports:
      - "${NACOS_PORT}:8848"
    volumes:
      - ./services/nacos-logs:/home/nacos/logs
    restart: unless-stopped

  mysql:
    image: mysql:8.0
    container_name: mall-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: mall
      MYSQL_CHARSET: utf8mb4
      MYSQL_COLLATION: utf8mb4_unicode_ci
      TZ: Asia/Shanghai
    ports:
      - "${MYSQL_PORT}:3306"
    volumes:
      - ./services/mysql-data:/var/lib/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: mall-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD:-}
    ports:
      - "${REDIS_PORT}:6379"
    volumes:
      - ./services/redis-data:/data
    restart: unless-stopped
COMPOSE

# ========== 4. 生成数据库初始化脚本 ==========
cat > "$SETUP_DIR/init.sql" <<'SQL'
CREATE DATABASE IF NOT EXISTS mall CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mall;

CREATE TABLE IF NOT EXISTS mall_user (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(200) NOT NULL,
  nickname VARCHAR(50) DEFAULT NULL,
  phone VARCHAR(20) DEFAULT NULL,
  email VARCHAR(100) DEFAULT NULL,
  avatar VARCHAR(500) DEFAULT NULL,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted TINYINT DEFAULT 0,
  INDEX idx_username(username)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mall_product (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  stock INT DEFAULT 0,
  image_url VARCHAR(500) DEFAULT NULL,
  category VARCHAR(50) DEFAULT NULL,
  status TINYINT DEFAULT 1,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mall_order (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  order_no VARCHAR(64) NOT NULL UNIQUE,
  user_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  product_name VARCHAR(200) DEFAULT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) DEFAULT 'PENDING',
  pay_time DATETIME DEFAULT NULL,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id(user_id),
  INDEX idx_order_no(order_no)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS mall_payment (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  pay_no VARCHAR(64) NOT NULL UNIQUE,
  order_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  pay_type VARCHAR(20) DEFAULT 'ALIPAY',
  status VARCHAR(20) DEFAULT 'PENDING',
  third_party_no VARCHAR(100) DEFAULT NULL,
  pay_time DATETIME DEFAULT NULL,
  create_time DATETIME DEFAULT CURRENT_TIMESTAMP,
  update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_order_id(order_id),
  INDEX idx_pay_no(pay_no)
) ENGINE=InnoDB;

-- 测试数据: 密码 123456 的 BCrypt 哈希
INSERT IGNORE INTO mall_user (username, password, nickname) VALUES
('admin', '$2a$10$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', '管理员');

INSERT IGNORE INTO mall_product (name, description, price, stock, category, status) VALUES
('Spring Cloud Alibaba 实战', '从零入门微服务，Nacos/Sentinel/Seata/RocketMQ 全套', 99.00, 1000, '电子书', 1),
('Java 面试八股文 2026', 'Java基础/Spring/微服务/并发/JVM/数据库', 49.90, 500, '电子书', 1),
('机械键盘 Cherry 青轴', '87键 白光版 热插拔', 299.00, 50, '数码', 1),
('4K 显示器 27寸 Type-C', 'IPS面板 65W反向充电', 1999.00, 20, '数码', 1);
SQL

# ========== 5. 开放防火墙端口 ==========
info "配置防火墙..."
if command -v firewall-cmd &>/dev/null; then
  for p in $NACOS_PORT $MYSQL_PORT $REDIS_PORT; do
    sudo firewall-cmd --permanent --add-port=$p/tcp 2>/dev/null || true
  done
  sudo firewall-cmd --reload 2>/dev/null || true
  log "firewalld 端口已开放"
elif command -v ufw &>/dev/null; then
  for p in $NACOS_PORT $MYSQL_PORT $REDIS_PORT; do
    sudo ufw allow $p/tcp 2>/dev/null || true
  done
  log "ufw 端口已开放"
else
  warn "未检测到防火墙，请手动开放端口: $NACOS_PORT $MYSQL_PORT $REDIS_PORT"
fi

# ========== 6. 启动服务 ==========
info "启动 Docker 容器..."
cd "$SETUP_DIR"
docker compose up -d

# 等待 MySQL 就绪
info "等待 MySQL 启动..."
for i in $(seq 1 30); do
  if docker compose logs mysql 2>/dev/null | grep -q "ready for connections"; then
    break
  fi
  sleep 2
done
log "MySQL 已就绪"

# ========== 7. 保存端口信息供微服务读取 ==========
cat > "$SETUP_DIR/services-ports.env" <<EOF
# 微服务连接信息
NACOS_SERVER=47.108.130.167:$NACOS_PORT
MYSQL_URL=jdbc:mysql://47.108.130.167:$MYSQL_PORT/mall
REDIS_HOST=47.108.130.167
REDIS_PORT=$REDIS_PORT
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD
EOF
log "端口信息已保存到 services-ports.env"

# ========== 8. 输出连接信息 ==========
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || curl -s ifconfig.me 2>/dev/null || echo "47.108.130.167")

echo ""
echo "============================================"
echo -e "  ${GREEN}服务部署完成！${NC}"
echo "============================================"
echo ""
echo "服务器 IP: $SERVER_IP"
echo ""
echo "连接信息:"
echo "  Nacos  : http://$SERVER_IP:$NACOS_PORT/nacos"
echo "  MySQL  : $SERVER_IP:$MYSQL_PORT (root / $MYSQL_ROOT_PASSWORD)"
echo "  Redis  : $SERVER_IP:$REDIS_PORT"
echo ""
echo "微服务配置 (application.yml):"
echo "  spring.cloud.nacos.discovery.server-addr: $SERVER_IP:$NACOS_PORT"
echo "  spring.datasource.url: jdbc:mysql://$SERVER_IP:$MYSQL_PORT/mall"
echo "  spring.data.redis.host: $SERVER_IP"
echo "  spring.data.redis.port: $REDIS_PORT"
echo ""
echo "管理命令:"
echo "  查看状态 : docker compose ps"
echo "  查看日志 : docker compose logs -f"
echo "  停止服务 : docker compose stop"
echo "  重启服务 : docker compose restart"
echo ""
echo "⚠  请确保以下端口在云服务器安全组中已放行:"
echo "   $NACOS_PORT, $MYSQL_PORT, $REDIS_PORT"
echo ""
