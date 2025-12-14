# Backstage Developer Portal

> 整合本專案 CI/CD 資訊的開發者入口平台

---

## 簡介

[Backstage](https://backstage.io/) 是由 Spotify 開發的開源開發者入口平台，用於建立、管理和文件化軟體服務目錄。本專案將 Backstage 整合到 CI/CD 環境中，提供統一的服務檢視介面。

## 安裝結果

### 部署狀態

```
✅ Backstage Cluster: 運行中 (kind-backstage-cluster)
✅ PostgreSQL: 運行中 (backstage-postgresql-0)
✅ Backstage: 運行中 (backstage-bdc89f545-nnmhp)
✅ Web UI: http://localhost:7007 (HTTP 200)
```

### 已部署組件

| 組件 | 映像 | 狀態 |
|------|------|------|
| Backstage | ghcr.io/backstage/backstage:latest | Running |
| PostgreSQL | bitnami/postgresql:15 | Running |

## 系統架構

```
┌────────────────────────────────────────────────────┐
│              Backstage Cluster (Kind)              │
│                                                    │
│  ┌─────────────────┐    ┌─────────────────────┐  │
│  │   PostgreSQL    │◄──►│     Backstage       │  │
│  │                 │    │                     │  │
│  │  Port: 5432     │    │  Port: 7007         │  │
│  └─────────────────┘    └─────────────────────┘  │
│                                                    │
└────────────────────────────────────────────────────┘
                         │
                         ▼ 整合
    ┌────────────────────┼────────────────────┐
    │                    │                    │
    ▼                    ▼                    ▼
┌─────────┐      ┌─────────────┐      ┌──────────┐
│  Gitea  │      │   ArgoCD    │      │ Registry │
│ :3001   │      │   :8443     │      │  :5000   │
└─────────┘      └─────────────┘      └──────────┘
```

## 快速部署

### 使用 Helm (推薦)

```bash
# 1. 創建 Backstage Cluster (如尚未創建)
kind create cluster --config kind-backstage-cluster.yaml

# 2. 切換到 Backstage cluster context
./kubectl config use-context kind-backstage-cluster

# 3. 添加 Helm repo
./helm repo add backstage https://backstage.github.io/charts
./helm repo update

# 4. 安裝 Backstage
./helm install backstage backstage/backstage -n backstage --create-namespace \
  -f backstage/helm-values.yaml

# 5. 等待 Backstage 就緒
./kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=backstage -n backstage --timeout=180s
```

### 手動部署 (備用方案)

```bash
# 1. 切換到 Backstage cluster context
./kubectl config use-context kind-backstage-cluster

# 2. 創建 namespace
./kubectl create namespace backstage

# 3. 部署 PostgreSQL
./kubectl apply -f backstage/postgres-secrets.yaml
./kubectl apply -f backstage/postgres-pvc.yaml
./kubectl apply -f backstage/postgres-deployment.yaml

# 4. 等待 PostgreSQL 就緒
./kubectl wait --for=condition=ready pod -l app=postgres -n backstage --timeout=120s

# 5. 部署 Backstage
./kubectl apply -f backstage/backstage-secrets.yaml
./kubectl apply -f backstage/backstage-configmap.yaml
./kubectl apply -f backstage/backstage-deployment.yaml

# 6. 等待 Backstage 就緒
./kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=180s
```

## 訪問 Backstage

部署完成後，可透過以下方式訪問：

| 訪問方式 | URL | 說明 |
|---------|-----|------|
| NodePort | http://localhost:7007 | 透過 Kind 端口映射 |

### 預設憑證

- **認證模式**：Guest (開發環境)
- 無需登入即可訪問

## 服務目錄

Backstage 已預先配置以下 CI/CD 組件：

| 組件 | 類型 | 說明 |
|------|------|------|
| cicd-integration-server | System | CI/CD 整合環境系統 |
| gitea-server | Component | Git 服務 |
| gitea-runner | Component | CI Runner |
| argocd-server | Component | GitOps CD 工具 |
| docker-registry | Component | Docker 映像倉庫 |
| backstage-portal | Component | 開發者入口平台 |
| argocd-cluster | Resource | ArgoCD Kubernetes Cluster |
| app-cluster | Resource | Applications Kubernetes Cluster |
| backstage-cluster | Resource | Backstage Kubernetes Cluster |

## 目錄結構

```
backstage/
├── README.md                    # 本文件
├── helm-values.yaml             # Helm 安裝配置
├── catalog-info.yaml            # 服務目錄定義
├── postgres-secrets.yaml        # PostgreSQL 認證資訊
├── postgres-pvc.yaml            # PostgreSQL 持久化儲存
├── postgres-deployment.yaml     # PostgreSQL 部署配置
├── backstage-secrets.yaml       # Backstage 認證資訊
├── backstage-configmap.yaml     # Backstage 應用配置
└── backstage-deployment.yaml    # Backstage 部署配置
```

## 配置說明

### Helm Values 配置 (helm-values.yaml)

```yaml
backstage:
  image:
    registry: ghcr.io
    repository: backstage/backstage
    tag: latest

  appConfig:
    app:
      title: CI/CD Integration Server - Backstage
      baseUrl: http://localhost:7007

    organization:
      name: CI/CD Team
```

### 整合 Gitea (選用)

編輯 `helm-values.yaml`，添加 Gitea 整合：

```yaml
backstage:
  appConfig:
    integrations:
      gitea:
        - host: gitea.local
          baseUrl: http://gitea.local:3001
          username: your-username
          password: your-access-token
```

### 添加自訂組件

編輯 `catalog-info.yaml`，添加新的組件定義：

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  title: My Service
  description: Description of my service
spec:
  type: service
  lifecycle: production
  owner: cicd-team
  system: cicd-integration-server
```

## 維護指南

### 檢查狀態

```bash
# 檢查 Pods
./kubectl get pods -n backstage

# 檢查 Services
./kubectl get svc -n backstage

# 檢查 Helm release
./helm list -n backstage
```

### 更新 Backstage

```bash
# 使用 Helm 更新
./helm upgrade backstage backstage/backstage -n backstage -f backstage/helm-values.yaml

# 或手動重啟
./kubectl rollout restart deployment/backstage -n backstage
```

### 備份資料庫

```bash
./kubectl exec -n backstage backstage-postgresql-0 -- \
  pg_dump -U backstage backstage > backstage-backup.sql
```

## 故障排除

### Backstage 無法啟動

```bash
# 檢查 Pod 狀態
./kubectl get pods -n backstage

# 查看 Backstage 日誌
./kubectl logs -n backstage deployment/backstage

# 檢查 PostgreSQL 連線
./kubectl logs -n backstage backstage-postgresql-0
```

### 資料庫連線失敗

```bash
# 確認 PostgreSQL 運行中
./kubectl get pods -n backstage -l app.kubernetes.io/name=postgresql

# 測試資料庫連線
./kubectl exec -n backstage backstage-postgresql-0 -- psql -U backstage -c '\l'
```

### 無法訪問 Web UI

```bash
# 確認 Service 配置
./kubectl get svc -n backstage

# 確認端口映射
docker ps | grep backstage-cluster

# 測試連線
curl -s -o /dev/null -w "%{http_code}" http://localhost:7007
```

### 清理重建

```bash
# 卸載 Helm release
./helm uninstall backstage -n backstage

# 刪除 namespace
./kubectl delete namespace backstage

# 重新安裝
./helm install backstage backstage/backstage -n backstage --create-namespace \
  -f backstage/helm-values.yaml
```

---

**安裝日期**：2025-12-14
**Helm Chart 版本**：backstage/backstage 2.6.3
**Backstage 映像**：ghcr.io/backstage/backstage:latest
