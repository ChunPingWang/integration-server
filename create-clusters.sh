#!/bin/bash
# 創建三個 Kind Clusters 的腳本

set -e

echo "=== 開始創建 Kind Clusters ==="
echo ""

# 檢查 Docker 是否可用
if ! docker ps > /dev/null 2>&1; then
    echo "❌ 錯誤：無法連接到 Docker"
    echo "請先執行 ./setup-docker-permissions.sh 並重新登入"
    exit 1
fi

echo "✅ Docker 連接正常"
echo ""

# 創建 ArgoCD Cluster
echo "📦 [1/3] 創建 ArgoCD Cluster..."
if kind get clusters | grep -q "^argocd-cluster$"; then
    echo "⚠️  ArgoCD cluster 已存在，跳過創建"
else
    kind create cluster --config kind-argocd-cluster.yaml
    echo "✅ ArgoCD cluster 創建完成"
fi
echo ""

# 創建 Git Cluster
echo "📦 [2/3] 創建 Git (Gitea) Cluster..."
if kind get clusters | grep -q "^git-cluster$"; then
    echo "⚠️  Git cluster 已存在，跳過創建"
else
    kind create cluster --config kind-git-cluster.yaml
    echo "✅ Git cluster 創建完成"
fi
echo ""

# 創建 App Cluster
echo "📦 [3/3] 創建 Applications Cluster..."
if kind get clusters | grep -q "^app-cluster$"; then
    echo "⚠️  App cluster 已存在，跳過創建"
else
    kind create cluster --config kind-app-cluster.yaml
    echo "✅ Applications cluster 創建完成"
fi
echo ""

echo "=== 所有 Clusters 創建完成 ==="
echo ""
echo "📋 驗證 clusters:"
kind get clusters
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

echo "✅ 所有 clusters 已就緒！"
