#!/bin/bash
# ============================================================
# 阿里云服务器 - 开启 SSH 密码登录
# 用法: sudo bash enable-password-login.sh
# ============================================================
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# 必须 root
if [ "$EUID" -ne 0 ]; then
  echo "请用 sudo bash enable-password-login.sh 执行"
  exit 1
fi

echo ""
echo "============================================"
echo "  阿里云服务器 - 开启 SSH 密码登录"
echo "============================================"
echo ""

# ---------- 1. 输入密码 ----------
echo -n "请输入要设置的 root 密码: "
read -s ROOT_PASS
echo ""
if [ -z "$ROOT_PASS" ]; then
  echo "密码不能为空，退出"
  exit 1
fi
echo -n "请再次输入密码: "
read -s ROOT_PASS2
echo ""
if [ "$ROOT_PASS" != "$ROOT_PASS2" ]; then
  echo "两次密码不一致，退出"
  exit 1
fi

# ---------- 2. 设置 root 密码 ----------
echo "root:$ROOT_PASS" | chpasswd 2>/dev/null && log "root 密码已设置" || {
  warn "chpasswd 失败，尝试 passwd"
  echo -e "$ROOT_PASS\n$ROOT_PASS" | passwd root
}

# ---------- 3. 修改 sshd_config ----------
SSHD_CFG="/etc/ssh/sshd_config"

# 备份
cp "$SSHD_CFG" "${SSHD_CFG}.bak.$(date +%s)"
log "已备份 $SSHD_CFG"

# 修改主配置
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CFG"
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' "$SSHD_CFG"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CFG"

# 确保有这行（如果原来没有则追加）
grep -q "^PasswordAuthentication" "$SSHD_CFG" || echo "PasswordAuthentication yes" >> "$SSHD_CFG"
grep -q "^ChallengeResponseAuthentication" "$SSHD_CFG" || echo "ChallengeResponseAuthentication yes" >> "$SSHD_CFG"
grep -q "^PermitRootLogin" "$SSHD_CFG" || echo "PermitRootLogin yes" >> "$SSHD_CFG"

log "sshd_config 主配置已修改"

# ---------- 4. 处理子配置覆盖（阿里云常见）----------
# 阿里云可能在 /etc/ssh/sshd_config.d/ 下有子配置覆盖了 PasswordAuthentication
for d in /etc/ssh/sshd_config.d/*.conf; do
  [ -f "$d" ] || continue
  if grep -q "PasswordAuthentication" "$d" 2>/dev/null; then
    cp "$d" "${d}.bak.$(date +%s)"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$d"
    log "已处理子配置: $d"
  fi
done

# ---------- 5. 检查 include 指令 ----------
if grep -q "^Include" "$SSHD_CFG" 2>/dev/null; then
  warn "sshd_config 包含 Include 指令，如有问题请检查子配置文件"
  grep "^Include" "$SSHD_CFG"
fi

# ---------- 6. 验证配置 ----------
echo ""
echo "--- 配置预览 ---"
grep -E "^(PasswordAuthentication|ChallengeResponseAuthentication|PermitRootLogin)" "$SSHD_CFG"
echo ""

# ---------- 7. 重启 sshd ----------
echo "即将重启 SSH 服务..."
systemctl restart sshd 2>/dev/null && log "sshd 已重启" || {
  warn "systemctl 失败，尝试 service"
  service sshd restart 2>/dev/null && log "sshd 已重启" || service ssh restart && log "ssh 已重启"
}

# ---------- 8. 防火墙 / 安全组提示 ----------
echo ""
echo "============================================"
echo -e "  ${GREEN}密码登录已开启！${NC}"
echo "============================================"
echo ""
echo "  现在可以用 root + 密码登录:"
echo "    ssh root@$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
echo ""
echo -e "  ${YELLOW}⚠ 阿里云安全组必须放行 22 端口(TCP)${NC}"
echo -e "  ${YELLOW}   控制台 → 实例 → 安全组 → 入方向 → 添加 22 端口${NC}"
echo ""

# 不退出当前连接，保留会话
