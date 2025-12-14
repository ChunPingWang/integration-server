#!/bin/bash
# 使用 sudo 創建四個 Kind Clusters 的腳本
# 注意：這是臨時方案，建議完成 docker group 設置後使用 create-clusters.sh

set -e

echo "=== 開始創建 Kind Clusters (使用 sudo) ==="
echo ""

# 檢查 Docker 是否可用
if ! sudo docker ps > /dev/null 2>&1; then
    echo "❌ 錯誤：無法連接到 Docker"
    echo "請確認 Docker 服務已啟動: sudo systemctl start docker"
    exit 1
fi

echo "✅ Docker 連接正常"
echo ""

# 創建 ArgoCD Cluster
echo "📦 [1/4] 創建 ArgoCD Cluster..."
if sudo kind get clusters 2>/dev/null | grep -q "^argocd-cluster$"; then
    echo "⚠️  ArgoCD cluster 已存在，跳過創建"
else
    sudo kind create cluster --config kind-argocd-cluster.yaml
    echo "✅ ArgoCD cluster 創建完成"
fi
echo ""

# 創建 Git Cluster
echo "📦 [2/4] 創建 Git (Gitea) Cluster..."
if sudo kind get clusters 2>/dev/null | grep -q "^git-cluster$"; then
    echo "⚠️  Git cluster 已存在，跳過創建"
else
    sudo kind create cluster --config kind-git-cluster.yaml
    echo "✅ Git cluster 創建完成"
fi
echo ""

# 創建 App Cluster
echo "📦 [3/4] 創建 Applications Cluster..."
if sudo kind get clusters 2>/dev/null | grep -q "^app-cluster$"; then
    echo "⚠️  App cluster 已存在，跳過創建"
else
    sudo kind create cluster --config kind-app-cluster.yaml
    echo "✅ Applications cluster 創建完成"
fi
echo ""

# 創建 Backstage Cluster
echo "📦 [4/4] 創建 Backstage Cluster..."
if sudo kind get clusters 2>/dev/null | grep -q "^backstage-cluster$"; then
    echo "⚠️  Backstage cluster 已存在，跳過創建"
else
    sudo kind create cluster --config kind-backstage-cluster.yaml
    echo "✅ Backstage cluster 創建完成"
fi
echo ""

# 修復 kubeconfig 權限
echo "🔧 修復 kubeconfig 權限..."
sudo chown -R $USER:$USER ~/.kube
echo "✅ kubeconfig 權限已修復"
echo ""

echo "=== 所有 Clusters 創建完成 ==="
echo ""
echo "📋 驗證 clusters:"
sudo kind get clusters
echo ""

echo "🔍 檢查 clusters 狀態:"
echo ""
echo "--- ArgoCD Cluster ---"
kubectl cluster-info --context kind-argocd-cluster
echo ""
echo "--- Git Cluster ---"
kubectl cluster-info --context kind-git-cluster
echo ""
echo "--- App Cluster ---"
kubectl cluster-info --context kind-app-cluster
echo ""
echo "--- Backstage Cluster ---"
kubectl cluster-info --context kind-backstage-cluster
echo ""

echo "✅ 所有 clusters 已就緒！"
echo ""
echo "💡 提示：若要避免每次都使用 sudo，請執行："
echo "   sudo usermod -aG docker \$USER"
echo "   然後登出並重新登入"
