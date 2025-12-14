#!/bin/bash
# CI/CD 環境完整部署腳本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================"
echo "  CI/CD Integration Server 部署腳本  "
echo "======================================"
echo ""

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 步驟 0: 配置 /etc/hosts
echo -e "${BLUE}[步驟 0]${NC} 配置 /etc/hosts..."
if ! grep -q "gitea.local" /etc/hosts; then
    echo "需要 sudo 權限來配置 /etc/hosts"
    sudo bash -c 'cat >> /etc/hosts << EOF

# CI/CD Integration Server
127.0.0.1  gitea.local
127.0.0.1  registry.local
127.0.0.1  argocd.local
EOF'
    echo -e "${GREEN}✅ /etc/hosts 配置完成${NC}"
else
    echo -e "${YELLOW}⚠️  /etc/hosts 已包含相關配置${NC}"
fi
echo ""

# 步驟 1: 創建 Kind Clusters
echo -e "${BLUE}[步驟 1]${NC} 創建 Kind Clusters..."
if command -v kind &> /dev/null; then
    if ! docker ps &> /dev/null; then
        echo -e "${YELLOW}需要 sudo 執行 Docker 命令${NC}"
        sudo ./create-clusters-sudo.sh
    else
        ./create-clusters.sh
    fi
    echo -e "${GREEN}✅ Kind Clusters 創建完成${NC}"
else
    echo -e "${RED}❌ Kind 未安裝，請先安裝 Kind${NC}"
    exit 1
fi
echo ""

# 步驟 2: 部署 Gitea
echo -e "${BLUE}[步驟 2]${NC} 部署 Gitea..."
cd gitea
if docker ps | grep -q gitea; then
    echo -e "${YELLOW}⚠️  Gitea 已在運行${NC}"
else
    if ! docker-compose ps &> /dev/null; then
        sudo docker-compose up -d
    else
        docker-compose up -d
    fi
    echo "等待 Gitea 啟動..."
    sleep 10
    echo -e "${GREEN}✅ Gitea 部署完成${NC}"
    echo -e "${GREEN}   訪問: http://gitea.local:3001${NC}"
fi
cd ..
echo ""

# 步驟 3: 部署 Docker Registry 到 App Cluster
echo -e "${BLUE}[步驟 3]${NC} 部署 Docker Registry..."
./kubectl config use-context kind-app-cluster

# 創建 registry namespace
./kubectl create namespace registry --dry-run=client -o yaml | ./kubectl apply -f -

# 部署 registry
./kubectl apply -f registry/registry-pvc.yaml
./kubectl apply -f registry/registry-deployment.yaml
./kubectl apply -f registry/registry-ui-deployment.yaml

echo "等待 Registry pods 啟動..."
./kubectl wait --for=condition=Ready pods --all -n registry --timeout=180s || true
echo -e "${GREEN}✅ Registry 部署完成${NC}"
echo -e "${GREEN}   Registry: http://localhost:5000${NC}"
echo -e "${GREEN}   Registry UI: http://localhost:8081${NC}"
echo ""

# 步驟 4: 部署 ArgoCD
echo -e "${BLUE}[步驟 4]${NC} 部署 ArgoCD..."
./kubectl config use-context kind-argocd-cluster

# 創建 argocd namespace
./kubectl create namespace argocd --dry-run=client -o yaml | ./kubectl apply -f -

# 部署 ArgoCD
./kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "等待 ArgoCD pods 啟動..."
./kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s || true

echo -e "${GREEN}✅ ArgoCD 部署完成${NC}"
echo ""
echo -e "${YELLOW}取得 ArgoCD 初始密碼:${NC}"
ARGOCD_PASSWORD=$(./kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "等待 secret 創建...")
echo -e "${GREEN}   使用者名稱: admin${NC}"
echo -e "${GREEN}   密碼: ${ARGOCD_PASSWORD}${NC}"
echo ""
echo -e "${YELLOW}啟動 ArgoCD Port Forward (在新終端執行):${NC}"
echo -e "${BLUE}   ./kubectl port-forward svc/argocd-server -n argocd 8443:443${NC}"
echo -e "${GREEN}   訪問: https://localhost:8443${NC}"
echo ""

# 步驟 5: 部署 Backstage
echo -e "${BLUE}[步驟 5]${NC} 部署 Backstage Developer Portal..."
./kubectl config use-context kind-backstage-cluster

# 檢查 Helm 是否存在
if [ ! -f "./helm" ]; then
    echo "下載 Helm..."
    curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-v3.19.4-linux-amd64.tar.gz
    tar -zxvf /tmp/helm.tar.gz -C /tmp
    cp /tmp/linux-amd64/helm ./helm
    chmod +x ./helm
fi

# 添加 Backstage Helm repo
./helm repo add backstage https://backstage.github.io/charts 2>/dev/null || true
./helm repo update

# 創建 backstage namespace
./kubectl create namespace backstage --dry-run=client -o yaml | ./kubectl apply -f -

# 部署 Backstage
if ./helm list -n backstage | grep -q backstage; then
    echo -e "${YELLOW}⚠️  Backstage 已部署，跳過安裝${NC}"
else
    ./helm install backstage backstage/backstage -n backstage -f backstage/helm-values.yaml --timeout 10m
fi

# 應用額外配置 (允許從 GitHub 讀取 catalog)
./kubectl apply -f backstage/app-config-override.yaml

# 更新 deployment 以掛載配置
./kubectl patch deployment backstage -n backstage --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes",
    "value": [
      {
        "name": "app-config-override",
        "configMap": {
          "name": "backstage-app-config"
        }
      }
    ]
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts",
    "value": [
      {
        "name": "app-config-override",
        "mountPath": "/app/app-config.production.yaml",
        "subPath": "app-config.production.yaml"
      }
    ]
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/command",
    "value": ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
  }
]' 2>/dev/null || true

# 設定 Guest 認證環境變數
./kubectl set env deployment/backstage -n backstage \
  NODE_ENV=development \
  APP_CONFIG_auth_environment=development \
  APP_CONFIG_auth_providers_guest_dangerouslyAllowOutsideDevelopment=true 2>/dev/null || true

echo "等待 Backstage pods 啟動..."
./kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=backstage -n backstage --timeout=300s || true
./kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=postgresql -n backstage --timeout=180s || true

echo -e "${GREEN}✅ Backstage 部署完成${NC}"
echo -e "${GREEN}   訪問: http://localhost:7007${NC}"
echo ""

# 步驟 6: 下載 Oracle Image
echo -e "${BLUE}[步驟 6]${NC} 準備 Oracle Image..."
if docker images | grep -q "gvenzl/oracle-xe"; then
    echo -e "${YELLOW}⚠️  Oracle image 已存在${NC}"
else
    echo "下載 Oracle XE image (約 2GB，可能需要幾分鐘)..."
    if ! docker pull gvenzl/oracle-xe:21-slim &> /dev/null; then
        sudo docker pull gvenzl/oracle-xe:21-slim
    fi
    echo -e "${GREEN}✅ Oracle image 下載完成${NC}"
fi

# Push Oracle image 到本地 registry
echo "Push Oracle image 到本地 registry..."
if ! docker tag gvenzl/oracle-xe:21-slim localhost:5000/oracle-xe:21-slim &> /dev/null; then
    sudo docker tag gvenzl/oracle-xe:21-slim localhost:5000/oracle-xe:21-slim
fi
if ! docker push localhost:5000/oracle-xe:21-slim &> /dev/null; then
    sudo docker push localhost:5000/oracle-xe:21-slim
fi
echo -e "${GREEN}✅ Oracle image 已推送到本地 registry${NC}"
echo ""

# 總結
echo "======================================"
echo -e "${GREEN}    部署完成！${NC}"
echo "======================================"
echo ""
echo -e "${BLUE}已部署的服務:${NC}"
echo -e "  ✓ ArgoCD Cluster (kind-argocd-cluster)"
echo -e "  ✓ Git Cluster (kind-git-cluster)"
echo -e "  ✓ App Cluster (kind-app-cluster)"
echo -e "  ✓ Backstage Cluster (kind-backstage-cluster)"
echo -e "  ✓ Gitea - http://gitea.local:3001"
echo -e "  ✓ Docker Registry - http://localhost:5000"
echo -e "  ✓ Registry UI - http://localhost:8081"
echo -e "  ✓ ArgoCD - https://localhost:8443 (需要 port-forward)"
echo -e "  ✓ Backstage - http://localhost:7007"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo -e "  1. 訪問 http://gitea.local:3001 完成 Gitea 初始設定"
echo -e "  2. 在 Gitea 創建 Organization 和 Repositories"
echo -e "  3. 設定 Gitea Actions Runner (參考 gitea-runner/README.md)"
echo -e "  4. 配置 ArgoCD 連接到 Gitea repositories"
echo -e "  5. 訪問 http://localhost:7007 使用 Backstage 開發者入口"
echo ""
echo -e "${BLUE}檢查狀態:${NC}"
echo -e "  ./kubectl get pods -A                  # 查看所有 pods"
echo -e "  kind get clusters                      # 列出所有 clusters"
echo -e "  docker ps                              # 查看 Gitea 容器"
echo ""
