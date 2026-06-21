#!/bin/bash
# ============================================
# 服务器 Git 配置 + 克隆项目
# 用法: chmod +x git-setup.sh && ./git-setup.sh
# ============================================
set -e

GREEN='\033[0;32m' YELLOW='\033[1;33m' RED='\033[0;31m' NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

GITHUB_REPO="git@github.com:wxHHHHHHHHH/prod.git"
PROJECT_DIR="/opt/mall"

echo "========================================"
echo " Git 配置 & 项目克隆"
echo "========================================"

# ---- 1. 安装 Git ----
if ! command -v git &>/dev/null; then
    echo "📦 安装 Git..."
    apt-get update -qq && apt-get install -y -qq git
    log "Git 已安装"
else
    log "Git 已安装: $(git --version)"
fi

# ---- 2. 配置 Git 用户信息 ----
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    echo "请填写 Git 用户信息:"
    read -p "  你的名字 (如: zhangsan): " GIT_NAME
    read -p "  你的邮箱 (如: zhangsan@qq.com): " GIT_EMAIL
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    log "Git 用户已配置: $GIT_NAME <$GIT_EMAIL>"
else
    log "Git 用户: $(git config --global user.name) <$(git config --global user.email)>"
fi

# ---- 3. 生成 SSH 密钥 ----
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo ""
    echo "🔑 生成 SSH 密钥对..."
    ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f ~/.ssh/id_ed25519 -N "" -q
    log "SSH 密钥已生成"
else
    log "SSH 密钥已存在"
fi

# ---- 4. 显示公钥（添加到 GitHub）----
echo ""
echo "========================================"
echo " ⚠️  请把下面的公钥添加到 GitHub!"
echo "========================================"
echo ""
echo "  复制以下内容:"
echo "  ┌────────────────────────────────────────────┐"
cat ~/.ssh/id_ed25519.pub
echo "  └────────────────────────────────────────────┘"
echo ""
echo "  然后去: https://github.com/settings/keys"
echo "  点击 New SSH Key → 粘贴 → Add SSH Key"
echo ""
read -p "  添加好了按回车继续..." _
echo ""

# ---- 5. 测试 SSH 连接 ----
echo "🔍 测试 GitHub SSH 连接..."
if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    log "GitHub SSH 连接成功!"
else
    warn "GitHub SSH 测试未通过，但可能只是 warning，继续..."
fi

# ---- 6. 克隆项目 ----
if [ -d "$PROJECT_DIR/.git" ]; then
    log "项目已存在，执行 git pull..."
    cd "$PROJECT_DIR" && git pull
else
    rm -rf "$PROJECT_DIR" 2>/dev/null
    echo "📥 克隆项目..."
    git clone "$GITHUB_REPO" "$PROJECT_DIR"
    log "项目已克隆到 $PROJECT_DIR"
fi

echo ""
echo "========================================"
echo " ✅ Git 配置完成"
echo "========================================"
echo ""
echo "  项目目录: $PROJECT_DIR"
echo "  下一步:"
echo "    cd $PROJECT_DIR/server-setup"
echo "    ./install.sh   # 安装环境"
echo "    ./start.sh     # 启动中间件"
echo "    ./deploy.sh all  # 部署应用"
