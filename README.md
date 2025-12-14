# CI/CD Integration Server 部署指南

## 專案簡介

完整的輕量級 CI/CD 整合環境，使用 Gitea（輕量 Git 服務）取代 GitLab，大幅降低記憶體需求約 11GB。

### 架構特色

- **三個獨立 Kind Clusters**：ArgoCD、Git、Applications 分離部署
- **Gitea + Actions**：輕量級 Git 服務與 CI/CD (相容 GitHub Actions 語法)
- **ArgoCD**：GitOps 持續部署
- **本地 Registry**：Docker image 私有倉庫
- **Oracle XE 整合**：支援整合測試環境

### 資源優勢

| 組件 | 傳統方案 | 本方案 | 節省 |
|------|---------|--------|------|
| Git 服務 | GitLab (8GB) | Gitea (0.5GB) | 7.5GB |
| CI Runner | GitLab Runner (4GB) | Gitea Runner (0.5GB) | 3.5GB |
| **總計** | ~56GB | **~45GB** | **11GB** |

## 快速部署

### 一鍵部署（推薦）

```bash
# 執行完整自動化部署
./deploy-all.sh
```

這將自動：
1. 配置 `/etc/hosts`
2. 創建三個 Kind clusters
3. 部署 Gitea、Registry、ArgoCD
4. 下載並推送 Oracle image

### 手動分步部署

#### 步驟 1: 設置 Docker 權限

```bash
./setup-docker-permissions.sh
```

執行後需要：
- 執行 `newgrp docker` 或
- 登出並重新登入系統

若使用 sudo 方式，可跳過此步驟。

#### 步驟 2: 創建 Kind Clusters

```bash
# 有 docker 權限
./create-clusters.sh

# 或使用 sudo（臨時方案）
./create-clusters-sudo.sh
```

#### 步驟 3: 部署 Gitea

```bash
cd gitea
docker-compose up -d
# 訪問 http://gitea.local:3000 完成初始設定
```

#### 步驟 4: 部署 Registry

```bash
kubectl config use-context kind-app-cluster
kubectl create namespace registry
kubectl apply -f registry/
```

#### 步驟 5: 部署 ArgoCD

```bash
kubectl config use-context kind-argocd-cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

詳細步驟請參考 [tasks-gitea.md](tasks-gitea.md)。

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

## 已部署服務訪問

| 服務 | URL | 說明 |
|------|-----|------|
| Gitea | http://gitea.local:3000 | Git 服務與 Web UI |
| Gitea SSH | ssh://gitea.local:2222 | Git SSH 存取 |
| Registry | http://localhost:5000 | Docker Registry API |
| Registry UI | http://localhost:8081 | Registry Web 介面 |
| ArgoCD | https://localhost:8443 | 需先執行 port-forward |

### ArgoCD 訪問步驟

```bash
# 1. Port forward
kubectl config use-context kind-argocd-cluster
kubectl port-forward svc/argocd-server -n argocd 8443:443

# 2. 取得初始密碼（在新終端）
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 3. 訪問 https://localhost:8443
# Username: admin
# Password: (從步驟 2 取得)
```

## 目錄結構

```
cicd/
├── kind-*.yaml              # Kind cluster 配置文件
├── deploy-all.sh            # 一鍵部署腳本
├── create-clusters*.sh      # Cluster 創建腳本
├── gitea/                   # Gitea 配置
│   └── docker-compose.yaml
├── gitea-runner/            # Gitea Actions Runner
│   ├── docker-compose.yaml
│   ├── .env.template
│   └── README.md           # Runner 設定指南
├── registry/                # Docker Registry K8s manifests
│   ├── registry-pvc.yaml
│   ├── registry-deployment.yaml
│   └── registry-ui-deployment.yaml
├── argocd/                  # ArgoCD 配置
│   ├── application-example.yaml
│   └── README.md           # ArgoCD 使用指南
├── workflows/               # Gitea Actions workflow 範例
│   ├── ci-example.yaml
│   └── integration-test-example.yaml
├── db/                      # 資料庫腳本
│   ├── migration/          # Flyway migration scripts
│   └── scripts/            # 工具腳本
└── tasks-gitea.md          # 詳細部署任務清單
```

## 下一步

### 1. 設定 Gitea

1. 訪問 http://gitea.local:3000
2. 完成初始設定（選擇 SQLite3）
3. 建立管理員帳號
4. 建立 Organization（例如：`integration-team`）
5. 建立 Repositories：
   - `my-application` - 應用程式程式碼
   - `gitops-manifests` - GitOps 配置

### 2. 設定 Gitea Actions Runner

參考 [gitea-runner/README.md](gitea-runner/README.md)：
1. 在 Gitea 取得 Runner Registration Token
2. 配置 `gitea-runner/.env`
3. 啟動 Runner: `cd gitea-runner && docker-compose up -d`

### 3. 配置 ArgoCD

參考 [argocd/README.md](argocd/README.md)：
1. 連接 Gitea repository
2. 建立 Application
3. 設定自動同步

### 4. 測試 CI/CD Pipeline

1. 將 `workflows/ci-example.yaml` 複製到你的 repository `.gitea/workflows/`
2. Push 程式碼觸發 CI
3. 驗證 ArgoCD 自動部署

## 維護與管理

### 檢查系統狀態

```bash
# 檢查所有 clusters
kind get clusters

# 檢查 pods 狀態
kubectl get pods -A --context kind-argocd-cluster
kubectl get pods -A --context kind-app-cluster

# 檢查 Gitea 容器
docker ps | grep gitea

# 檢查資源使用
docker stats
kubectl top nodes --context kind-app-cluster
kubectl top pods -A --context kind-app-cluster
```

### 備份

```bash
# Gitea 資料備份
docker exec -t gitea /bin/sh -c 'gitea dump -c /data/gitea/conf/app.ini'

# Registry 資料備份（位於 K8s PVC）
kubectl get pvc -n registry --context kind-app-cluster
```

### 清理與重置

```bash
# 停止所有服務
cd gitea && docker-compose down
cd ../gitea-runner && docker-compose down

# 刪除 clusters
kind delete cluster --name argocd-cluster
kind delete cluster --name git-cluster
kind delete cluster --name app-cluster

# 清理 Docker volumes（可選）
docker volume prune
```

## 故障排除

### Gitea 無法訪問

```bash
docker logs gitea
docker ps | grep gitea
# 確認 /etc/hosts 已配置 gitea.local
```

### Registry 無法推送

```bash
# 檢查 Registry 狀態
kubectl get pods -n registry --context kind-app-cluster
kubectl logs -n registry deployment/docker-registry --context kind-app-cluster

# 測試連線
curl http://localhost:5000/v2/_catalog
```

### ArgoCD 無法同步

```bash
# 檢查 Application 狀態
kubectl get applications -n argocd --context kind-argocd-cluster

# 查看 logs
kubectl logs -n argocd deployment/argocd-application-controller --context kind-argocd-cluster
```

## 參考文件

- [詳細任務清單](tasks-gitea.md) - Phase-by-phase 部署指南
- [Gitea Runner 設定](gitea-runner/README.md)
- [ArgoCD 使用指南](argocd/README.md)
- [Gitea 官方文件](https://docs.gitea.io/)
- [ArgoCD 官方文件](https://argo-cd.readthedocs.io/)
- [Kind 官方文件](https://kind.sigs.k8s.io/)

## 授權

本專案為內部使用的 CI/CD 環境配置，基於開源工具搭建。
