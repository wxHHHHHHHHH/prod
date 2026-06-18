#!/bin/bash
# ============================================================
# 微服务商城 - 服务器环境一键安装脚本
# 用法: bash install-env.sh
# 支持: CentOS 7/8/9, RHEL, Fedora, Ubuntu 18/20/22/24, Debian
# 所有组件均使用国内镜像加速
# ============================================================
set -e

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[✓]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
step() { echo ""; echo -e "${BLUE}============================================${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}============================================${NC}"; }

# ============ 检测系统 ============
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    OS_VERSION=$VERSION_ID
  else
    err "无法检测操作系统类型"; exit 1
  fi
  case "$OS" in
    centos|rhel|rocky|almalinux|fedora|tencentos|anolis)  OS_FAMILY="rhel" ;;
    ubuntu|debian|deepin|uos)                              OS_FAMILY="debian" ;;
    *) warn "未知系统: $OS，尝试继续..."; OS_FAMILY="unknown" ;;
  esac
  info "检测到系统: $OS $OS_VERSION ($OS_FAMILY 系列)"
}

# ============ 配置 yum/apt 国内镜像源 ============
setup_mirror_repos() {
  step "1. 配置系统镜像源"

  if [ "$OS_FAMILY" = "rhel" ]; then
    case "${OS_VERSION:0:1}" in
      7)
        info "配置 CentOS 7 阿里云镜像源"
        $SUDO curl -fsSL -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo 2>/dev/null || \
        warn "阿里云源下载失败，使用默认源"
        ;;
      8)
        info "配置 CentOS 8 阿里云镜像源 (vault)"
        $SUDO sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-* 2>/dev/null || true
        $SUDO sed -i 's|#baseurl=http://mirror.centos.org|baseurl=https://mirrors.aliyun.com|g' /etc/yum.repos.d/CentOS-* 2>/dev/null || true
        $SUDO curl -fsSL -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo 2>/dev/null || \
        warn "阿里云源下载失败"
        ;;
      *)
        # Rocky / Alma / CentOS Stream 9+
        if [ "$OS" = "rocky" ]; then
          $SUDO sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/Rocky-*.repo 2>/dev/null || true
          $SUDO sed -i 's|^#baseurl=http://dl.rockylinux.org|baseurl=https://mirrors.aliyun.com|g' /etc/yum.repos.d/Rocky-*.repo 2>/dev/null || true
        elif [ "$OS" = "almalinux" ]; then
          $SUDO sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/almalinux*.repo 2>/dev/null || true
          $SUDO sed -i 's|^#baseurl=https://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g' /etc/yum.repos.d/almalinux*.repo 2>/dev/null || true
        fi
        ;;
    esac
    $SUDO yum makecache 2>/dev/null || warn "yum makecache 失败，继续..."
    log "yum 镜像源配置完成"

  elif [ "$OS_FAMILY" = "debian" ]; then
    if [ -f /etc/apt/sources.list ]; then
      $SUDO cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%s) 2>/dev/null || true
    fi
    # 阿里云 Ubuntu/Debian 镜像
    $SUDO sed -i "s|http://.*archive.ubuntu.com|https://mirrors.aliyun.com|g" /etc/apt/sources.list 2>/dev/null || true
    $SUDO sed -i "s|http://.*security.ubuntu.com|https://mirrors.aliyun.com|g" /etc/apt/sources.list 2>/dev/null || true
    $SUDO sed -i "s|http://.*deb.debian.org|https://mirrors.aliyun.com|g" /etc/apt/sources.list 2>/dev/null || true
    # 备选: 清华源
    if ! grep -q "mirrors.aliyun.com" /etc/apt/sources.list 2>/dev/null; then
      $SUDO sed -i "s|http://.*archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list 2>/dev/null || true
      $SUDO sed -i "s|http://.*security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list 2>/dev/null || true
    fi
    $SUDO apt-get update -y 2>/dev/null || warn "apt update 失败，继续..."
    log "apt 镜像源配置完成"
  fi
}

# ============ 安装 Java 17 ============
install_java() {
  step "2. 安装 Java 17"

  if java -version 2>&1 | grep -qiE "17\.[0-9]|21\.[0-9]"; then
    log "Java 17 已安装: $(java -version 2>&1 | head -1)"
    return
  fi

  info "正在安装 Java 17..."

  if [ "$OS_FAMILY" = "rhel" ]; then
    $SUDO yum install -y java-17-openjdk java-17-openjdk-devel 2>/dev/null || {
      warn "yum 安装失败，尝试手动安装 Amazon Corretto 17"
      $SUDO rpm --import https://yum.corretto.aws/corretto.key 2>/dev/null || true
      $SUDO curl -fsSL -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo 2>/dev/null || true
      $SUDO yum install -y java-17-amazon-corretto-devel 2>/dev/null || \
        err "Java 17 安装失败，请手动安装"
    }
  elif [ "$OS_FAMILY" = "debian" ]; then
    $SUDO apt-get install -y openjdk-17-jdk 2>/dev/null || {
      warn "apt 安装失败，尝试手动安装..."
      err "Java 17 安装失败，请手动安装"
    }
  fi

  # 验证
  if java -version 2>&1 | grep -qiE "17\.[0-9]|21\.[0-9]"; then
    log "Java 17 安装完成: $(java -version 2>&1 | head -1)"
  else
    err "Java 17 验证失败"
  fi
}

# ============ 安装 Maven (配置阿里云镜像) ============
install_maven() {
  step "3. 安装 Maven (配置阿里云镜像)"

  if mvn --version 2>&1 | grep -qi "Apache Maven 3"; then
    log "Maven 已安装: $(mvn --version 2>&1 | head -1)"
  else
    info "正在安装 Maven..."
    if [ "$OS_FAMILY" = "rhel" ]; then
      $SUDO yum install -y maven 2>/dev/null || true
    elif [ "$OS_FAMILY" = "debian" ]; then
      $SUDO apt-get install -y maven 2>/dev/null || true
    fi

    # 如果包管理器没有，手动安装
    if ! command -v mvn &>/dev/null; then
      info "包管理器未找到 Maven，手动安装..."
      MAVEN_VERSION="3.9.6"
      $SUDO curl -fsSL "https://mirrors.aliyun.com/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
        -o /tmp/maven.tar.gz 2>/dev/null || \
      $SUDO curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
        -o /tmp/maven.tar.gz 2>/dev/null || true

      if [ -f /tmp/maven.tar.gz ]; then
        $SUDO tar -xzf /tmp/maven.tar.gz -C /opt/
        $SUDO ln -sf /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin/mvn
        rm -f /tmp/maven.tar.gz
        log "Maven 手动安装完成"
      fi
    fi
  fi

  # 配置阿里云 Maven 镜像
  info "配置 Maven 阿里云镜像..."
  M2_HOME="${M2_HOME:-/opt/apache-maven-${MAVEN_VERSION:-3.9.6}}"
  [ ! -d "$M2_HOME" ] && M2_HOME=$(dirname $(dirname $(readlink -f $(which mvn 2>/dev/null) 2>/dev/null) 2>/dev/null) 2>/dev/null) || true
  [ ! -d "$M2_HOME" ] && M2_HOME="/usr/share/maven"

  SETTINGS_FILE=""
  if [ -f "$M2_HOME/conf/settings.xml" ]; then
    SETTINGS_FILE="$M2_HOME/conf/settings.xml"
  elif [ -f "/etc/maven/settings.xml" ]; then
    SETTINGS_FILE="/etc/maven/settings.xml"
  fi

  if [ -n "$SETTINGS_FILE" ]; then
    # 备份
    $SUDO cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak.$(date +%s)" 2>/dev/null || true
    # 检查是否已配置
    if grep -q "maven.aliyun.com" "$SETTINGS_FILE" 2>/dev/null; then
      log "Maven 阿里云镜像已配置"
    else
      info "写入阿里云镜像配置到 $SETTINGS_FILE"
      $SUDO sed -i '/<mirrors>/a\    <mirror>\n      <id>aliyunmaven</id>\n      <mirrorOf>central</mirrorOf>\n      <name>阿里云公共仓库</name>\n      <url>https://maven.aliyun.com/repository/public</url>\n    </mirror>' "$SETTINGS_FILE" 2>/dev/null || {
        # 如果没有 <mirrors> 标签，在 </settings> 前插入
        $SUDO sed -i 's|</settings>|  <mirrors>\n    <mirror>\n      <id>aliyunmaven</id>\n      <mirrorOf>central</mirrorOf>\n      <name>阿里云公共仓库</name>\n      <url>https://maven.aliyun.com/repository/public</url>\n    </mirror>\n  </mirrors>\n</settings>|' "$SETTINGS_FILE" 2>/dev/null || true
      }
      log "Maven 阿里云镜像配置完成"
    fi
  fi

  # 用户级 settings.xml
  mkdir -p ~/.m2
  if [ ! -f ~/.m2/settings.xml ]; then
    cat > ~/.m2/settings.xml << 'MAVENXML'
<?xml version="1.0" encoding="UTF-8"?>
<settings>
  <mirrors>
    <mirror>
      <id>aliyunmaven</id>
      <mirrorOf>central</mirrorOf>
      <name>阿里云公共仓库</name>
      <url>https://maven.aliyun.com/repository/public</url>
    </mirror>
  </mirrors>
</settings>
MAVENXML
    log "用户级 Maven settings.xml 已创建"
  fi
}

# ============ 安装 Docker (配置国内镜像加速) ============
install_docker() {
  step "4. 安装 Docker (配置国内镜像加速)"

  if docker --version &>/dev/null 2>&1; then
    log "Docker 已安装: $(docker --version)"
  else
    info "正在安装 Docker..."

    # 方案1: 阿里云 Docker CE 镜像
    if [ "$OS_FAMILY" = "rhel" ]; then
      $SUDO yum install -y yum-utils 2>/dev/null || true
      if curl -fsSL --connect-timeout 5 https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -o /tmp/docker-ce.repo 2>/dev/null; then
        $SUDO cp /tmp/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
        $SUDO yum install -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
      elif curl -fsSL --connect-timeout 5 https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/centos/docker-ce.repo -o /tmp/docker-ce.repo 2>/dev/null; then
        $SUDO cp /tmp/docker-ce.repo /etc/yum.repos.d/docker-ce.repo
        $SUDO yum install -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
      fi

    elif [ "$OS_FAMILY" = "debian" ]; then
      $SUDO apt-get install -y ca-certificates curl gnupg lsb-release 2>/dev/null || true
      # 尝试阿里云 Docker 源
      if curl -fsSL --connect-timeout 5 https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg 2>/dev/null | $SUDO gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | \
          $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
        $SUDO apt-get update -y 2>/dev/null || true
        $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
      elif curl -fsSL --connect-timeout 5 https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg 2>/dev/null | $SUDO gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | \
          $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
        $SUDO apt-get update -y 2>/dev/null || true
        $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
      fi
    fi

    # 方案2: 如果上面都失败了，用 daocloud 镜像的一键脚本
    if ! docker --version &>/dev/null 2>&1; then
      warn "包管理器安装失败，尝试 DaoCloud 镜像脚本..."
      curl -fsSL https://get.daocloud.io/docker | bash 2>/dev/null || \
      curl -fsSL https://get.docker.com | bash 2>/dev/null || true
    fi

    # 启动 Docker
    $SUDO systemctl enable docker 2>/dev/null || true
    $SUDO systemctl start docker 2>/dev/null || true

    if docker --version &>/dev/null 2>&1; then
      log "Docker 安装完成: $(docker --version)"
    else
      err "Docker 安装失败"
      return
    fi
  fi

  # 配置 Docker 国内镜像加速器
  info "配置 Docker 镜像加速器..."
  if [ ! -f /etc/docker/daemon.json ]; then
    $SUDO mkdir -p /etc/docker
    $SUDO tee /etc/docker/daemon.json > /dev/null << 'DOCKERJSON'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me",
    "https://hub.rat.dev",
    "https://docker.m.daocloud.io",
    "https://dockerhub.icu",
    "https://docker.chenby.cn",
    "https://docker.registry.cyou",
    "https://dhub.kubesre.xyz",
    "https://docker.hpcloud.cloud",
    "https://docker.rainbond.cc"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
DOCKERJSON
    $SUDO systemctl daemon-reload 2>/dev/null || true
    $SUDO systemctl restart docker 2>/dev/null || true
    log "Docker 镜像加速配置完成"
  elif grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
    log "Docker 镜像加速已配置"
  else
    warn "daemon.json 已存在但未配置镜像加速，请手动添加"
  fi

  # Docker Compose
  info "检查 Docker Compose..."
  if docker compose version &>/dev/null 2>&1; then
    log "Docker Compose (plugin) 已就绪: $(docker compose version)"
  elif docker-compose --version &>/dev/null 2>&1; then
    log "Docker Compose (standalone) 已就绪: $(docker-compose --version)"
  else
    info "安装 Docker Compose..."
    if [ "$OS_FAMILY" = "debian" ]; then
      $SUDO apt-get install -y docker-compose-plugin 2>/dev/null || true
    elif [ "$OS_FAMILY" = "rhel" ]; then
      $SUDO yum install -y docker-compose-plugin 2>/dev/null || true
    fi
    # 如果 plugin 安装失败，手动下载
    if ! docker compose version &>/dev/null 2>&1; then
      COMPOSE_VER=$(curl -fsSL --connect-timeout 5 https://mirrors.aliyun.com/docker-toolbox/linux/compose/latest 2>/dev/null || echo "v2.24.0")
      $SUDO curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose 2>/dev/null && $SUDO chmod +x /usr/local/bin/docker-compose || true
    fi
    log "Docker Compose 安装完成"
  fi
}

# ============ 安装其他工具 ============
install_tools() {
  step "5. 安装其他必要工具"

  local missing=""
  for tool in git curl wget openssl; do
    if ! command -v $tool &>/dev/null; then
      missing="$missing $tool"
    fi
  done

  if [ -z "$missing" ]; then
    log "常用工具均已安装"; return
  fi

  info "正在安装: $missing"
  if [ "$OS_FAMILY" = "rhel" ]; then
    $SUDO yum install -y git curl wget vim net-tools openssl epel-release 2>/dev/null || true
  elif [ "$OS_FAMILY" = "debian" ]; then
    $SUDO apt-get install -y git curl wget vim net-tools openssl 2>/dev/null || true
  fi
  log "工具安装完成"
}

# ============ 输出汇总 ============
print_summary() {
  step "安装完成 - 环境汇总"

  echo ""
  printf "  %-20s : " "操作系统"; [ -f /etc/os-release ] && . /etc/os-release && echo "$NAME $VERSION" || uname -a
  printf "  %-20s : " "Java"; java -version 2>&1 | head -1 || echo "未安装"
  printf "  %-20s : " "Maven"; mvn --version 2>&1 | head -1 || echo "未安装"
  printf "  %-20s : " "Docker"; docker --version 2>/dev/null || echo "未安装"
  printf "  %-20s : " "Docker Compose"; docker compose version 2>/dev/null | head -1 || docker-compose --version 2>/dev/null || echo "未安装"
  printf "  %-20s : " "Git"; git --version 2>/dev/null || echo "未安装"

  echo ""
  echo -e "${CYAN}  镜像加速状态:${NC}"
  if [ -f /etc/docker/daemon.json ] && grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
    echo "    Docker 镜像加速: ${GREEN}已配置${NC}"
  else
    echo "    Docker 镜像加速: ${YELLOW}未配置${NC}"
  fi
  if grep -q "maven.aliyun.com" ~/.m2/settings.xml 2>/dev/null; then
    echo "    Maven 阿里云镜像: ${GREEN}已配置${NC}"
  else
    echo "    Maven 阿里云镜像: ${YELLOW}未配置${NC}"
  fi

  echo ""
  echo -e "${GREEN}============================================${NC}"
  echo -e "${GREEN}  环境安装完成！${NC}"
  echo -e "${GREEN}  接下来运行: bash check-env.sh 检查环境${NC}"
  echo -e "${GREEN}  然后运行: bash deploy.sh 部署项目${NC}"
  echo -e "${GREEN}============================================${NC}"
  echo ""
}

# ============ Main ============
echo ""
echo "============================================"
echo "  微服务商城 - 服务器环境安装脚本"
echo "  支持: CentOS 7/8/9, Rocky, Alma, Ubuntu, Debian"
echo "  所有组件均使用国内镜像加速"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

if [ "$EUID" -ne 0 ] && ! command -v sudo &>/dev/null; then
  err "请使用 root 用户运行，或安装 sudo"; exit 1
fi

if [ "$EUID" -ne 0 ]; then
  info "使用 sudo 执行安装..."
  SUDO="sudo"
else
  SUDO=""
fi

detect_os
setup_mirror_repos
install_java
install_maven
install_docker
install_tools
print_summary
