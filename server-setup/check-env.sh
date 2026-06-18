#!/bin/bash
# ============================================================
# 微服务商城 - 服务器环境检查脚本
# 用法: bash check-env.sh
# ============================================================
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# ---------- helper ----------
check_cmd() {
  local name="$1" cmd="$2" expect="$3" hint="$4"
  printf "  %-20s ... " "$name"
  local result
  result=$(eval "$cmd" 2>&1) || true
  if echo "$result" | grep -qiE "$expect"; then
    echo -e "${GREEN}✓ 已安装${NC}"
    echo "    $result" | head -1
    ((PASS++))
  else
    echo -e "${RED}✗ 未安装或版本不满足${NC}"
    [ -n "$hint" ] && echo -e "    ${YELLOW}→ 安装: $hint${NC}"
    ((FAIL++))
  fi
}

check_port() {
  local port="$1" desc="$2"
  printf "  %-20s ... " "$desc (:$port)"
  if ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
    echo -e "${RED}✗ 已被占用${NC}"
    ((FAIL++))
  else
    echo -e "${GREEN}✓ 空闲${NC}"
    ((PASS++))
  fi
}

# ---------- header ----------
echo ""
echo "============================================"
echo "  微服务商城 - 服务器环境检查"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"

# ---------- 1. OS ----------
echo ""
echo -e "${CYAN}--- 操作系统 ---${NC}"
printf "  操作系统         : "
if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "$NAME $VERSION"
else
  uname -a
fi
printf "  内核             : "; uname -r
printf "  架构             : "; uname -m

# ---------- 2. 基础工具 ----------
echo ""
echo -e "${CYAN}--- 基础环境 ---${NC}"
check_cmd "Java 17"      "java -version 2>&1"          "17\.[0-9]|21\.[0-9]"  "yum install -y java-17-openjdk-devel  或 apt install -y openjdk-17-jdk"
check_cmd "Maven"        "mvn --version 2>&1"          "Apache Maven 3"       "yum install -y maven  或 apt install -y maven"
check_cmd "Git"          "git --version"               "git version"          "yum install -y git  或 apt install -y git"
check_cmd "Curl"         "curl --version"              "curl"                 "yum install -y curl"
check_cmd "OpenSSL"      "openssl version"             "OpenSSL"              "yum install -y openssl"

# ---------- 3. Docker ----------
echo ""
echo -e "${CYAN}--- Docker ---${NC}"
check_cmd "Docker"       "docker --version 2>&1"       "Docker version"       "curl -fsSL https://get.docker.com | bash"
check_cmd "Docker Compose" "docker compose version 2>&1 || docker-compose --version 2>&1" "v?[0-9]+\.[0-9]+" "Docker 自带或 apt install docker-compose-plugin"

# 检查 Docker 是否运行
printf "  %-20s ... " "Docker 运行状态"
if docker info &>/dev/null 2>&1; then
  echo -e "${GREEN}✓ 运行中${NC}"
  ((PASS++))
else
  echo -e "${YELLOW}⚠ 未运行或无权限${NC}"
  ((WARN++))
fi

# Docker 镜像加速检查
printf "  %-20s ... " "Docker 镜像加速"
if [ -f /etc/docker/daemon.json ]; then
  if grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
    echo -e "${GREEN}✓ 已配置${NC}"
    grep "registry-mirrors" /etc/docker/daemon.json | head -1
    ((PASS++))
  else
    echo -e "${YELLOW}⚠ 未配置镜像加速（国内拉取可能很慢）${NC}"
    ((WARN++))
  fi
else
  echo -e "${YELLOW}⚠ 未配置镜像加速${NC}"
  ((WARN++))
fi

# ---------- 4. 端口检查 ----------
echo ""
echo -e "${CYAN}--- 关键端口 ---${NC}"
check_port 8080 "API 网关"
check_port 8848 "Nacos"
check_port 3306 "MySQL"
check_port 6379 "Redis"
check_port 8081 "Auth 服务"
check_port 8083 "Product 服务"
check_port 8084 "Order 服务"
check_port 8085 "Payment 服务"

# ---------- 5. 系统资源 ----------
echo ""
echo -e "${CYAN}--- 系统资源 ---${NC}"
printf "  磁盘 (/): "; df -h / 2>/dev/null | tail -1 | awk '{printf "总 %s / 已用 %s / 可用 %s", $2, $3, $4}'
echo ""
printf "  内存:     "; free -h 2>/dev/null | awk '/Mem:/{printf "总 %s / 已用 %s / 可用 %s", $2, $3, $7}'
echo ""
printf "  CPU:      "; nproc 2>/dev/null && echo " 核心" || echo "无法检测"
printf "  运行时间: "; uptime 2>/dev/null | awk '{print $3, $4}' | tr -d ','

# ---------- 6. 网络 ----------
echo ""
echo -e "${CYAN}--- 网络连通性 ---${NC}"
check_url() {
  local name="$1" url="$2"
  printf "  %-20s ... " "$name"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null) || true
  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
    echo -e "${GREEN}✓ 可达 (HTTP $code)${NC}"
    ((PASS++))
  else
    echo -e "${RED}✗ 不可达${NC}"
    ((FAIL++))
  fi
}

check_url "GitHub"        "https://github.com"
check_url "Maven Central" "https://repo1.maven.org"
check_url "Docker Hub"    "https://hub.docker.com"
check_url "阿里云 Maven"  "https://maven.aliyun.com"

# ---------- 7. 防火墙 ----------
echo ""
echo -e "${CYAN}--- 防火墙 ---${NC}"
printf "  %-20s ... " "防火墙状态"
if command -v firewall-cmd &>/dev/null; then
  if firewall-cmd --state 2>/dev/null | grep -q "running"; then
    echo "firewalld 运行中"
    echo "  ${YELLOW}提示: 需要放行端口 8080, 8848, 3306, 6379 等${NC}"
  else
    echo "firewalld 未运行"
  fi
  ((PASS++))
elif command -v ufw &>/dev/null; then
  sudo ufw status 2>/dev/null | head -1
  ((PASS++))
elif command -v iptables &>/dev/null; then
  echo "iptables 可用"
  ((PASS++))
else
  echo -e "${YELLOW}未检测到防火墙${NC}"
  ((WARN++))
fi

# 云服务器安全组提醒
echo ""
echo -e "${YELLOW}  ⚠ 如果是云服务器（阿里云/腾讯云等），请确保安全组已放行以下端口:${NC}"
echo -e "${YELLOW}     8080 (API网关), 8848 (Nacos), 3306 (MySQL), 6379 (Redis)${NC}"

# ---------- 总结 ----------
echo ""
echo "============================================"
TOTAL=$((PASS + FAIL + WARN))
printf "  通过: ${GREEN}%d${NC}  |  失败: ${RED}%d${NC}  |  警告: ${YELLOW}%d${NC}  |  共 %d 项\n" $PASS $FAIL $WARN $TOTAL
echo "============================================"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}  检测到 ${FAIL} 项缺失，请运行 install-env.sh 安装所需环境${NC}"
  echo ""
  exit 1
else
  echo ""
  echo -e "${GREEN}  环境检查全部通过，可以部署项目${NC}"
  echo ""
  exit 0
fi