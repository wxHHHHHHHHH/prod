#!/bin/bash
# ============================================
# K8s 一键部署: 基础设施 + 微服务
# 用法: bash deploy.sh [apply|delete|status]
# ============================================
set -e

GREEN='\033[0;32m' NC='\033[0m'
log() { echo -e "${GREEN}[✓]${NC} $1"; }

K8S_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-apply}"

echo ""
echo "============================================"
echo "  微服务商城 — K8s 部署"
echo "============================================"

case "$ACTION" in
  apply)
    log "创建命名空间..."
    kubectl apply -f "$K8S_DIR/namespace.yaml"

    log "创建 Secret & ConfigMap..."
    kubectl apply -f "$K8S_DIR/secrets.yaml"
    kubectl apply -f "$K8S_DIR/configmap.yaml"
    kubectl apply -f "$K8S_DIR/init-sql-configmap.yaml"

    log "部署基础设施 (MySQL/Redis/Nacos)..."
    kubectl apply -f "$K8S_DIR/infrastructure.yaml"

    echo "等待基础设施就绪..."
    kubectl -n mall wait --for=condition=ready pod -l app=mysql --timeout=120s 2>/dev/null || true
    kubectl -n mall wait --for=condition=ready pod -l app=redis --timeout=60s 2>/dev/null || true
    kubectl -n mall wait --for=condition=ready pod -l app=nacos --timeout=120s 2>/dev/null || true

    log "部署微服务..."
    kubectl apply -f "$K8S_DIR/microservices.yaml"

    echo ""
    echo "============================================"
    log "部署完成！"
    echo ""
    echo "查看状态:"
    echo "  kubectl -n mall get pods"
    echo "  kubectl -n mall get svc"
    echo ""
    echo "Gateway NodePort: 30080 (对外访问)"
    echo "Nacos 内部:       http://nacos:8848/nacos"
    echo "============================================"
    ;;

  delete)
    log "删除所有 mall 资源..."
    kubectl delete namespace mall
    ;;

  status)
    echo "--- Pods ---"
    kubectl -n mall get pods -o wide
    echo ""
    echo "--- Services ---"
    kubectl -n mall get svc
    echo ""
    echo "--- PVC ---"
    kubectl -n mall get pvc
    ;;

  *)
    echo "用法: bash deploy.sh [apply|delete|status]"
    ;;
esac
