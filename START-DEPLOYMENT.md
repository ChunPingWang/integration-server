# 🚀 開始部署 - 只需一個命令！

## 快速開始

我已經為您準備好完整的自動化部署腳本。**只需執行以下單一命令**：

```bash
sudo ./execute-deployment.sh
```

這個腳本會自動完成以下所有步驟：

### ✅ 自動執行的任務

1. ✅ 配置 `/etc/hosts`
2. ✅ 創建 ArgoCD Cluster
3. ✅ 創建 Git Cluster
4. ✅ 創建 App Cluster
5. ✅ 修復 kubeconfig 權限
6. ✅ 部署 Gitea
7. ✅ 部署 Docker Registry
8. ✅ 部署 Registry UI
9. ✅ 部署 ArgoCD
10. ✅ 下載並推送 Oracle image

### ⏱️ 預計時間

- **總時間**: 約 10-15 分鐘
  - Clusters 創建: 5-8 分鐘
  - 服務部署: 3-5 分鐘
  - Oracle image: 2-5 分鐘（取決於網速）

### 📋 執行步驟

```bash
# 1. 確保在正確的目錄
cd /home/rexwang/workspace/cicd

# 2. 執行部署腳本（會要求輸入 sudo 密碼）
sudo ./execute-deployment.sh
```

### 📊 腳本會顯示的進度

```
======================================
  CI/CD Integration Server 自動部署
======================================

[1/8] 配置 /etc/hosts...
✅ /etc/hosts 配置完成

[2/8] 創建 ArgoCD Cluster...
✅ ArgoCD cluster 創建完成

[3/8] 創建 Git Cluster...
✅ Git cluster 創建完成

[4/8] 創建 App Cluster...
✅ App cluster 創建完成

[5/8] 部署 Gitea...
✅ Gitea 部署完成
   訪問: http://gitea.local:3001

[6/8] 部署 Docker Registry...
✅ Registry 部署完成
   Registry: http://localhost:5000
   Registry UI: http://localhost:8081

[7/8] 部署 ArgoCD...
✅ ArgoCD 部署完成

ArgoCD 管理員帳號:
  Username: admin
  Password: <密碼會顯示在這裡>

[8/8] 下載並推送 Oracle Image...
✅ Oracle image 已推送到本地 registry

======================================
    部署完成！
======================================
```

### 🎯 部署完成後

部署完成後，您可以：

1. **訪問 Gitea**: http://gitea.local:3001
   - 完成初始設定
   - 建立管理員帳號

2. **訪問 Registry UI**: http://localhost:8081
   - 查看已推送的 Docker images

3. **訪問 ArgoCD**: https://localhost:8443
   - 先執行 port-forward:
     ```bash
     ./kubectl port-forward svc/argocd-server -n argocd 8443:443
     ```
   - 使用腳本顯示的密碼登入

### 🔍 驗證部署

```bash
# 檢查 Clusters
sudo kind get clusters

# 檢查 Gitea
sudo docker ps | grep gitea

# 檢查 Registry
curl http://localhost:5000/v2/_catalog

# 檢查 Pods
./kubectl get pods -A --context kind-app-cluster
./kubectl get pods -A --context kind-argocd-cluster
```

### ⚠️ 如果遇到問題

如果腳本執行過程中出現錯誤：

1. **查看錯誤訊息**: 腳本會顯示詳細的錯誤資訊
2. **重新執行**: 腳本具有冪等性，可以安全地重新執行
3. **查看日誌**:
   ```bash
   # Gitea
   sudo docker logs gitea

   # Registry
   ./kubectl logs -n registry deployment/docker-registry --context kind-app-cluster

   # ArgoCD
   ./kubectl logs -n argocd deployment/argocd-server --context kind-argocd-cluster
   ```

### 📚 相關文件

部署完成後，繼續參考：
- [README.md](README.md) - 完整使用指南
- [gitea-runner/README.md](gitea-runner/README.md) - 設定 Gitea Runner
- [argocd/README.md](argocd/README.md) - 配置 ArgoCD

---

## 🚀 現在就開始！

```bash
sudo ./execute-deployment.sh
```

祝部署順利！ 🎉
