#!/bin/bash
# 部署 NGINX Ingress Controller 到所有 Kind Clusters
# Deploy NGINX Ingress Controller to all Kind Clusters

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "  部署 NGINX Ingress Controller"
echo "========================================"
echo ""

# NGINX Ingress Controller for Kind
INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"

deploy_ingress() {
    local context=$1
    local cluster_name=$2

    echo -e "${BLUE}[${cluster_name}]${NC} 部署 Ingress Controller..."

    ./kubectl config use-context "$context"

    # 檢查是否已安裝
    if ./kubectl get namespace ingress-nginx &>/dev/null; then
        echo -e "${YELLOW}⚠️  Ingress Controller 已存在於 ${cluster_name}${NC}"
    else
        ./kubectl apply -f "$INGRESS_MANIFEST"
        echo "等待 Ingress Controller 就緒..."
        ./kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=180s || true
        echo -e "${GREEN}✅ Ingress Controller 部署完成${NC}"
    fi
    echo ""
}

# 部署到 ArgoCD Cluster
deploy_ingress "kind-argocd-cluster" "ArgoCD Cluster"

# 部署到 App Cluster
deploy_ingress "kind-app-cluster" "App Cluster"

# 部署到 Backstage Cluster
deploy_ingress "kind-backstage-cluster" "Backstage Cluster"

echo "========================================"
echo -e "${GREEN}    Ingress Controller 部署完成！${NC}"
echo "========================================"
echo ""
echo -e "${BLUE}下一步：${NC}"
echo "  1. 執行 ./ingress/apply-ingress-rules.sh 部署 Ingress 規則"
echo "  2. 在遠端機器配置 /etc/hosts 或 DNS"
echo "  3. 透過域名訪問服務"
