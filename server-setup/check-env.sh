#!/bin/bash
# ============================================
# 服务器环境检查
# 用法: bash check-env.sh
# ============================================
GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'
pass=0 fail=0

check() {
  local name="$1" cmd="$2" min="$3"
  echo -n "  $name ... "
  result=$(eval "$cmd" 2>&1)
  if echo "$result" | grep -q "$min"; then
    echo -e "${GREEN}✓${NC} $result" | head -1
    ((pass++))
  elif [ -n "$result" ]; then
    echo -e "${YELLOW}?${NC} $result" | head -1
    ((pass++))
  else
    echo -e "${RED}✗ 未安装${NC}"
    ((fail++))
  fi
}

echo "============================================"
echo "  服务器环境检查"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

echo "--- 基础环境 ---"
check "Java 17"    "java -version 2>&1 | head -1"        "17\|21"
check "Maven"      "mvn --version 2>&1 | head -1"       "3"
check "Git"        "git --version"                        "git"
check "Curl"       "curl --version | head -1"             "curl"

echo ""
echo "--- Docker ---"
check "Docker"     "docker --version"                     "Docker"
check "Compose"    "docker compose version 2>&1"          "v2"

echo ""
echo "--- 端口占用 ---"
for p in 8080 8081 8083 8084 8085; do
  if ss -tlnp 2>/dev/null | grep -q ":$p "; then
    echo -e "  ${RED}✗ 端口 $p 已被占用${NC}"
    ((fail++))
  else
    echo -e "  ${GREEN}✓${NC} 端口 $p 空闲"
    ((pass++))
  fi
done

echo ""
echo "--- 资源 ---"
echo -n "  磁盘: "; df -h / 2>/dev/null | tail -1 | awk '{print $4 " 可用"}'
echo -n "  内存: "; free -h 2>/dev/null | awk '/Mem:/{print $2 " 总量, " $7 " 可用"}'
echo -n "  CPU: "; nproc 2>/dev/null && echo "核"

echo ""
echo "--- 网络 ---"
check "GitHub连通" "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 https://github.com" "200"
check "DockerHub"  "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 https://hub.docker.com" "200"

echo ""
echo "============================================"
echo -e "  通过: ${GREEN}$pass${NC}  失败: ${RED}$fail${NC}"
echo "============================================"
if [ $fail -gt 0 ]; then
  echo ""
  echo "缺失组件安装命令:"
  echo "  Java:   yum install -y java-17-openjdk-devel"
  echo "  Maven:  yum install -y maven"
  echo "  Docker: curl -fsSL https://get.docker.com | bash"
  echo "  Git:    yum install -y git"
fi
