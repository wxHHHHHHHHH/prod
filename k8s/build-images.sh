#!/bin/bash
# ============================================
# 构建 Docker 镜像 + 推送到仓库
# ============================================
set -e
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "============================================"
echo "  构建微服务 Docker 镜像"
echo "============================================"

# 1. 编译项目
echo "[1/3] Maven 编译..."
cd "$APP_DIR"
mvn clean package -DskipTests -q

# 2. 构建各服务镜像
echo "[2/3] 构建镜像..."
services=("gateway" "auth-service" "product-service" "order-service" "payment-service")
for svc in "${services[@]}"; do
  echo "  -> mall-$svc"
  cat > "$APP_DIR/$svc/Dockerfile" <<DOCKERFILE
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY target/$svc-*.jar app.jar
ENV TZ=Asia/Shanghai
EXPOSE 8080
ENTRYPOINT ["java", "-Xms256m", "-Xmx512m", "-jar", "app.jar"]
DOCKERFILE
  cd "$APP_DIR/$svc"
  docker build -t "mall-$svc:latest" . -q
done

echo "[3/3] 镜像列表:"
docker images | grep mall-
echo ""
echo "构建完成！"
echo "推送到仓库: docker tag mall-xxx:latest registry.example.com/mall-xxx && docker push"
