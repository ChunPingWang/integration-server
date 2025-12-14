# CI/CD Integration Server 部署指南

## 環境概覽

本專案使用三個獨立的 Kind Kubernetes clusters：

1. **ArgoCD Cluster** - 專門運行 ArgoCD (GitOps CD 工具)
2. **Git Cluster** - 專門運行 Gitea (Git 服務 + CI Runner)
3. **App Cluster** - 運行應用程式、Docker Registry、測試環境

## 快速開始

### 步驟 1: 設置 Docker 權限

```bash
./setup-docker-permissions.sh
```

執行後需要：
- 執行 `newgrp docker` 或
- 登出並重新登入系統

### 步驟 2: 創建 Kind Clusters

```bash
./create-clusters.sh
```

這將創建所有三個 clusters 並驗證其狀態。

### 步驟 3: 部署服務

按照 `tasks-gitea.md` 文件繼續部署：
- Gitea (Git 服務器)
- Docker Registry
- ArgoCD
- Gitea Actions Runner

## Cluster 配置

### ArgoCD Cluster
- Ports: 8080 (HTTP), 8443 (HTTPS), 30443
- Nodes: 1 control-plane

### Git Cluster
- Ports: 3000 (Gitea Web), 2222 (Gitea SSH)
- Nodes: 1 control-plane

### App Cluster
- Ports: 80, 443 (Ingress), 5000 (Registry), 8081 (Registry UI)
- Nodes: 1 control-plane + 2 workers
- Registry: 支援 insecure local registry

## 檢查 Cluster 狀態

```bash
# 列出所有 clusters
kind get clusters

# 檢查特定 cluster
kubectl cluster-info --context kind-argocd-cluster
kubectl cluster-info --context kind-git-cluster
kubectl cluster-info --context kind-app-cluster

# 查看 nodes
kubectl get nodes --context kind-app-cluster
```

## 刪除 Clusters

```bash
kind delete cluster --name argocd-cluster
kind delete cluster --name git-cluster
kind delete cluster --name app-cluster
```
