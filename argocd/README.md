# ArgoCD 配置與使用指南

## 訪問 ArgoCD

### 1. 啟動 Port Forward

```bash
kubectl config use-context kind-argocd-cluster
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

### 2. 取得初始密碼

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

### 3. 登入

- URL: https://localhost:8443
- Username: `admin`
- Password: (從步驟 2 取得)

### 4. 修改密碼（建議）

登入後前往 User Info > Update Password

## 連接 Gitea Repository

### 方法 1: 透過 Web UI

1. 前往 **Settings** > **Repositories**
2. 點擊 **Connect Repo**
3. 填入以下資訊：
   - Repository URL: `http://gitea.local:3000/your-org/gitops-manifests.git`
   - Username: (你的 Gitea 使用者名稱)
   - Password: (Gitea Access Token)
4. 點擊 **Connect**

### 方法 2: 透過 CLI

```bash
# 安裝 ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd
rm argocd

# 登入 ArgoCD
argocd login localhost:8443 --username admin --password <your-password> --insecure

# 新增 repository
argocd repo add http://gitea.local:3000/your-org/gitops-manifests.git \
  --username <gitea-username> \
  --password <gitea-access-token>
```

## 建立 Gitea Access Token

1. 登入 Gitea (http://gitea.local:3000)
2. 前往 **User Settings** > **Applications**
3. 在 **Generate New Token** 區域：
   - Token Name: `argocd`
   - Select Scopes:
     - ✅ `repo` (所有 repository 權限)
     - ✅ `read:org` (讀取 organization)
4. 點擊 **Generate Token**
5. **立即複製 token**（只會顯示一次）

## 部署 Application

### 使用範例配置

1. 編輯 `application-example.yaml`，更新：
   - `repoURL`: 你的 GitOps repository URL
   - `path`: manifest 檔案路徑
   - `namespace`: 目標 namespace

2. 部署 Application：

```bash
kubectl config use-context kind-argocd-cluster
kubectl apply -f application-example.yaml
```

3. 在 ArgoCD UI 中查看同步狀態

### 透過 CLI 建立

```bash
argocd app create my-application \
  --repo http://gitea.local:3000/your-org/gitops-manifests.git \
  --path overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace app-dev \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

## GitOps Workflow

### 典型流程

1. **開發者推送程式碼** → Gitea
2. **Gitea Actions 觸發 CI**
   - 執行測試
   - 建立 Docker image
   - 推送到本地 Registry
3. **CI 更新 GitOps repo**
   - 更新 `overlays/dev/deployment.yaml` 中的 image tag
   - Commit & Push
4. **ArgoCD 偵測變更**
   - 自動同步到 Kubernetes cluster
   - 部署新版本應用程式

### GitOps Repository 結構範例

```
gitops-manifests/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── deployment.yaml  # 覆寫 image tag
    └── prod/
        ├── kustomization.yaml
        └── deployment.yaml
```

## 監控與管理

### 查看 Application 狀態

```bash
# 列出所有 applications
argocd app list

# 查看特定 application
argocd app get my-application

# 查看同步歷史
argocd app history my-application
```

### 手動同步

```bash
# 同步 application
argocd app sync my-application

# Hard refresh（重新拉取 Git）
argocd app sync my-application --force
```

### 回滾

```bash
# 查看歷史版本
argocd app history my-application

# 回滾到特定版本
argocd app rollback my-application <version-id>
```

## 多 Cluster 管理

由於我們使用三個獨立的 Kind clusters，需要將 App Cluster 註冊到 ArgoCD：

```bash
# 取得 App Cluster 的 kubeconfig
kubectl config use-context kind-app-cluster
kubectl config view --minify --flatten > /tmp/app-cluster-kubeconfig

# 切換到 ArgoCD cluster
kubectl config use-context kind-argocd-cluster

# 註冊 App Cluster（透過 ArgoCD CLI）
argocd cluster add kind-app-cluster \
  --name app-cluster \
  --kubeconfig /tmp/app-cluster-kubeconfig

# 驗證
argocd cluster list
```

更新 Application manifest 使用 App Cluster：

```yaml
destination:
  name: app-cluster  # 使用註冊的 cluster name
  namespace: app-dev
```

## 故障排除

### Application 卡在 Syncing

```bash
# 查看詳細狀態
argocd app get my-application

# 查看 logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Repository 連線失敗

- 檢查 Gitea 是否可從 ArgoCD cluster 訪問
- 驗證 Access Token 是否有效
- 檢查 repository URL 是否正確

### Sync 失敗

```bash
# 查看 sync 錯誤訊息
argocd app get my-application

# 檢查 resource 差異
argocd app diff my-application
```

## 相關文件

- [ArgoCD 官方文件](https://argo-cd.readthedocs.io/)
- [GitOps 最佳實踐](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
