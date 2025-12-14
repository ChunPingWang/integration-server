#!/bin/bash
# 完整部署執行腳本 - 需要 sudo 權限
# 執行方式: sudo ./execute-deployment.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "======================================"
echo "  CI/CD Integration Server 自動部署  "
echo "======================================"
echo ""

# 步驟 1: 配置 /etc/hosts
echo -e "${BLUE}[1/8]${NC} 配置 /etc/hosts..."
if grep -q "gitea.local" /etc/hosts; then
    echo -e "${YELLOW}⚠️  /etc/hosts 已包含配置${NC}"
else
    cat >> /etc/hosts << 'EOF'

# CI/CD Integration Server
127.0.0.1  gitea.local
127.0.0.1  registry.local
127.0.0.1  argocd.local
EOF
    echo -e "${GREEN}✅ /etc/hosts 配置完成${NC}"
fi
echo ""

# 步驟 2: 創建 ArgoCD Cluster
echo -e "${BLUE}[2/8]${NC} 創建 ArgoCD Cluster..."
if kind get clusters 2>/dev/null | grep -q "^argocd-cluster$"; then
    echo -e "${YELLOW}⚠️  ArgoCD cluster 已存在${NC}"
else
    kind create cluster --config kind-argocd-cluster.yaml
    echo -e "${GREEN}✅ ArgoCD cluster 創建完成${NC}"
fi
echo ""

# 步驟 3: 創建 Git Cluster
echo -e "${BLUE}[3/8]${NC} 創建 Git Cluster..."
if kind get clusters 2>/dev/null | grep -q "^git-cluster$"; then
    echo -e "${YELLOW}⚠️  Git cluster 已存在${NC}"
else
    kind create cluster --config kind-git-cluster.yaml
    echo -e "${GREEN}✅ Git cluster 創建完成${NC}"
fi
echo ""

# 步驟 4: 創建 App Cluster
echo -e "${BLUE}[4/8]${NC} 創建 App Cluster..."
if kind get clusters 2>/dev/null | grep -q "^app-cluster$"; then
    echo -e "${YELLOW}⚠️  App cluster 已存在${NC}"
else
    kind create cluster --config kind-app-cluster.yaml
    echo -e "${GREEN}✅ App cluster 創建完成${NC}"
fi
echo ""

# 修復 kubeconfig 權限
echo -e "${BLUE}修復 kubeconfig 權限...${NC}"
if [ -d /root/.kube ]; then
    cp -r /root/.kube /home/$SUDO_USER/ 2>/dev/null || true
fi
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.kube 2>/dev/null || true
echo -e "${GREEN}✅ 權限已修復${NC}"
echo ""

# 驗證 Clusters
echo -e "${BLUE}驗證 Clusters...${NC}"
kind get clusters
echo ""

# 步驟 5: 部署 Gitea
echo -e "${BLUE}[5/8]${NC} 部署 Gitea..."
cd gitea
if docker ps | grep -q gitea; then
    echo -e "${YELLOW}⚠️  Gitea 已在運行${NC}"
else
    docker-compose up -d
    echo "等待 Gitea 啟動..."
    sleep 10
    echo -e "${GREEN}✅ Gitea 部署完成${NC}"
    echo -e "${GREEN}   訪問: http://gitea.local:3000${NC}"
fi
cd ..
echo ""

# 步驟 6: 部署 Docker Registry
echo -e "${BLUE}[6/8]${NC} 部署 Docker Registry..."
sudo -u $SUDO_USER ./kubectl config use-context kind-app-cluster
sudo -u $SUDO_USER ./kubectl create namespace registry --dry-run=client -o yaml | sudo -u $SUDO_USER ./kubectl apply -f -
sudo -u $SUDO_USER ./kubectl apply -f registry/registry-pvc.yaml
sudo -u $SUDO_USER ./kubectl apply -f registry/registry-deployment.yaml
sudo -u $SUDO_USER ./kubectl apply -f registry/registry-ui-deployment.yaml

echo "等待 Registry pods 啟動..."
sudo -u $SUDO_USER ./kubectl wait --for=condition=Ready pods --all -n registry --timeout=180s || true
echo -e "${GREEN}✅ Registry 部署完成${NC}"
echo -e "${GREEN}   Registry: http://localhost:5000${NC}"
echo -e "${GREEN}   Registry UI: http://localhost:8081${NC}"
echo ""

# 步驟 7: 部署 ArgoCD
echo -e "${BLUE}[7/8]${NC} 部署 ArgoCD..."
sudo -u $SUDO_USER ./kubectl config use-context kind-argocd-cluster
sudo -u $SUDO_USER ./kubectl create namespace argocd --dry-run=client -o yaml | sudo -u $SUDO_USER ./kubectl apply -f -
sudo -u $SUDO_USER ./kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "等待 ArgoCD pods 啟動（約 2-3 分鐘）..."
sudo -u $SUDO_USER ./kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s || true

echo -e "${GREEN}✅ ArgoCD 部署完成${NC}"
echo ""

# 取得 ArgoCD 初始密碼
echo -e "${BLUE}取得 ArgoCD 初始密碼...${NC}"
sleep 10
ARGOCD_PASSWORD=$(sudo -u $SUDO_USER ./kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "等待 secret 創建...")
echo -e "${GREEN}ArgoCD 管理員帳號:${NC}"
echo -e "  Username: ${YELLOW}admin${NC}"
echo -e "  Password: ${YELLOW}${ARGOCD_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}啟動 ArgoCD Port Forward (在新終端執行):${NC}"
echo -e "${BLUE}  cd /home/$SUDO_USER/workspace/cicd${NC}"
echo -e "${BLUE}  ./kubectl port-forward svc/argocd-server -n argocd 8443:443${NC}"
echo ""

# 步驟 8: 下載並推送 Oracle Image
echo -e "${BLUE}[8/8]${NC} 下載並推送 Oracle Image..."
if docker images | grep -q "gvenzl/oracle-xe"; then
    echo -e "${YELLOW}⚠️  Oracle image 已存在${NC}"
else
    echo "下載 Oracle XE image (約 2GB)..."
    docker pull gvenzl/oracle-xe:21-slim
    echo -e "${GREEN}✅ Oracle image 下載完成${NC}"
fi

echo "推送 Oracle image 到本地 registry..."
docker tag gvenzl/oracle-xe:21-slim localhost:5000/oracle-xe:21-slim
docker push localhost:5000/oracle-xe:21-slim
echo -e "${GREEN}✅ Oracle image 已推送到本地 registry${NC}"
echo ""

# 驗證
echo -e "${BLUE}驗證 Oracle image...${NC}"
curl -s http://localhost:5000/v2/oracle-xe/tags/list
echo ""
echo ""

# 總結
echo "======================================"
echo -e "${GREEN}    部署完成！${NC}"
echo "======================================"
echo ""
echo -e "${BLUE}已部署的服務:${NC}"
echo -e "  ✓ Kind Clusters: $(kind get clusters | wc -l) 個"
echo -e "  ✓ Gitea - http://gitea.local:3000"
echo -e "  ✓ Docker Registry - http://localhost:5000"
echo -e "  ✓ Registry UI - http://localhost:8081"
echo -e "  ✓ ArgoCD - https://localhost:8443 (需要 port-forward)"
echo ""
echo -e "${YELLOW}檢查狀態:${NC}"
echo -e "${BLUE}  sudo kind get clusters${NC}"
echo -e "${BLUE}  sudo docker ps | grep gitea${NC}"
echo -e "${BLUE}  ./kubectl get pods -A --context kind-app-cluster${NC}"
echo -e "${BLUE}  ./kubectl get pods -A --context kind-argocd-cluster${NC}"
echo ""
echo -e "${GREEN}下一步：訪問 http://gitea.local:3000 完成 Gitea 初始設定${NC}"
echo ""
