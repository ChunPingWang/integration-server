#!/bin/bash
# 部署 Ingress 規則到各個 Cluster
# Apply Ingress rules to clusters

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
echo "  部署 Ingress 規則"
echo "========================================"
echo ""

# 部署 ArgoCD Ingress
echo -e "${BLUE}[1/3]${NC} 部署 ArgoCD Ingress 規則..."
./kubectl config use-context kind-argocd-cluster
./kubectl apply -f ingress/argocd-ingress.yaml
echo -e "${GREEN}✅ ArgoCD Ingress 部署完成${NC}"
echo ""

# 部署 Registry Ingress
echo -e "${BLUE}[2/3]${NC} 部署 Registry Ingress 規則..."
./kubectl config use-context kind-app-cluster
./kubectl apply -f ingress/registry-ingress.yaml
echo -e "${GREEN}✅ Registry Ingress 部署完成${NC}"
echo ""

# 部署 Backstage Ingress
echo -e "${BLUE}[3/3]${NC} 部署 Backstage Ingress 規則..."
./kubectl config use-context kind-backstage-cluster
./kubectl apply -f ingress/backstage-ingress.yaml
echo -e "${GREEN}✅ Backstage Ingress 部署完成${NC}"
echo ""

echo "========================================"
echo -e "${GREEN}    Ingress 規則部署完成！${NC}"
echo "========================================"
echo ""
echo -e "${BLUE}服務訪問方式 (本機):${NC}"
echo "  ArgoCD:      https://argocd.local:8443"
echo "  Backstage:   http://backstage.local:7080"
echo "  Registry:    http://registry.local:8088"
echo "  Registry UI: http://registry-ui.local:8088"
echo ""
echo -e "${YELLOW}遠端訪問設定:${NC}"
echo "  1. 在遠端機器的 /etc/hosts 加入:"
echo "     <SERVER_IP>  argocd.local backstage.local registry.local registry-ui.local gitea.local"
echo ""
echo "  2. 確保防火牆允許以下端口:"
echo "     - 3001 (Gitea)"
echo "     - 7080/7443 (Backstage via Ingress)"
echo "     - 8080/8443 (ArgoCD via Ingress)"
echo "     - 8088/8448 (Registry via Ingress)"
echo ""
