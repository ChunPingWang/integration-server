#!/bin/bash
# 分步部署腳本 - 需要手動執行每個步驟

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================"
echo "  CI/CD 環境分步部署指南"
echo "======================================"
echo ""

echo -e "${BLUE}步驟 1: 配置 /etc/hosts${NC}"
echo "請執行以下命令："
echo -e "${YELLOW}sudo bash -c 'cat >> /etc/hosts << EOF

# CI/CD Integration Server
127.0.0.1  gitea.local
127.0.0.1  registry.local
127.0.0.1  argocd.local
EOF'${NC}"
echo ""
read -p "完成後按 Enter 繼續..."
echo ""

echo -e "${BLUE}步驟 2: 創建 ArgoCD Cluster${NC}"
echo "請執行："
echo -e "${YELLOW}sudo kind create cluster --config kind-argocd-cluster.yaml${NC}"
echo ""
read -p "完成後按 Enter 繼續..."
echo ""

echo -e "${BLUE}步驟 3: 創建 Git Cluster${NC}"
echo "請執行："
echo -e "${YELLOW}sudo kind create cluster --config kind-git-cluster.yaml${NC}"
echo ""
read -p "完成後按 Enter 繼續..."
echo ""

echo -e "${BLUE}步驟 4: 創建 App Cluster${NC}"
echo "請執行："
echo -e "${YELLOW}sudo kind create cluster --config kind-app-cluster.yaml${NC}"
echo ""
read -p "完成後按 Enter 繼續..."
echo ""

echo -e "${BLUE}步驟 5: 修復 kubeconfig 權限${NC}"
echo "請執行："
echo -e "${YELLOW}sudo chown -R \$USER:\$USER ~/.kube${NC}"
echo ""
read -p "完成後按 Enter 繼續..."
echo ""

echo -e "${BLUE}步驟 6: 驗證 Clusters${NC}"
echo "執行驗證..."
export KUBECONFIG=~/.kube/config
./kubectl cluster-info --context kind-argocd-cluster
./kubectl cluster-info --context kind-git-cluster
./kubectl cluster-info --context kind-app-cluster
echo ""
echo -e "${GREEN}✅ Clusters 創建完成！${NC}"
echo ""

echo -e "${BLUE}步驟 7: 部署 Gitea${NC}"
echo "請執行："
echo -e "${YELLOW}cd gitea && sudo docker-compose up -d && cd ..${NC}"
echo ""
read -p "完成後按 Enter 繼續..."
echo ""

echo -e "${BLUE}步驟 8: 部署 Docker Registry${NC}"
echo "執行部署..."
./kubectl config use-context kind-app-cluster
./kubectl create namespace registry --dry-run=client -o yaml | ./kubectl apply -f -
./kubectl apply -f registry/registry-pvc.yaml
./kubectl apply -f registry/registry-deployment.yaml
./kubectl apply -f registry/registry-ui-deployment.yaml
echo "等待 Registry pods 啟動..."
./kubectl wait --for=condition=Ready pods --all -n registry --timeout=180s || true
echo -e "${GREEN}✅ Registry 部署完成${NC}"
echo ""

echo -e "${BLUE}步驟 9: 部署 ArgoCD${NC}"
echo "執行部署..."
./kubectl config use-context kind-argocd-cluster
./kubectl create namespace argocd --dry-run=client -o yaml | ./kubectl apply -f -
./kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "等待 ArgoCD pods 啟動（可能需要幾分鐘）..."
./kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s || true
echo -e "${GREEN}✅ ArgoCD 部署完成${NC}"
echo ""

echo -e "${BLUE}步驟 10: 取得 ArgoCD 初始密碼${NC}"
sleep 10
ARGOCD_PASSWORD=$(./kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "等待 secret 創建...")
echo -e "${GREEN}ArgoCD 管理員帳號:${NC}"
echo -e "  Username: ${YELLOW}admin${NC}"
echo -e "  Password: ${YELLOW}${ARGOCD_PASSWORD}${NC}"
echo ""

echo -e "${BLUE}步驟 11: 下載 Oracle Image（可選）${NC}"
echo "這將下載約 2GB 的 Oracle image，可能需要幾分鐘"
echo "請執行："
echo -e "${YELLOW}sudo docker pull gvenzl/oracle-xe:21-slim${NC}"
echo -e "${YELLOW}sudo docker tag gvenzl/oracle-xe:21-slim localhost:5000/oracle-xe:21-slim${NC}"
echo -e "${YELLOW}sudo docker push localhost:5000/oracle-xe:21-slim${NC}"
echo ""
read -p "是否要執行此步驟？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "請手動執行上述命令"
fi
echo ""

echo "======================================"
echo -e "${GREEN}部署完成！${NC}"
echo "======================================"
echo ""
echo -e "${BLUE}已部署的服務:${NC}"
echo "  ✓ ArgoCD Cluster (kind-argocd-cluster)"
echo "  ✓ Git Cluster (kind-git-cluster)"
echo "  ✓ App Cluster (kind-app-cluster)"
echo "  ✓ Gitea - http://gitea.local:3001"
echo "  ✓ Registry - http://localhost:5000"
echo "  ✓ Registry UI - http://localhost:8081"
echo "  ✓ ArgoCD - https://localhost:8443"
echo ""
echo -e "${YELLOW}啟動 ArgoCD Port Forward:${NC}"
echo -e "${BLUE}  ./kubectl port-forward svc/argocd-server -n argocd 8443:443${NC}"
echo ""
