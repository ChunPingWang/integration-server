# CI/CD Integration Server 部署狀態報告

**日期**: 2025-12-14
**版本**: v1.1
**狀態**: 已驗證完成

---

## 測試結果摘要

| 測試項目 | 狀態 | 說明 |
|---------|------|------|
| Kind Clusters 建立 | 通過 | 3 個 clusters 正常運行 |
| Gitea 服務 | 通過 | http://gitea.local:3001 |
| Docker Registry | 通過 | http://localhost:5000 |
| ArgoCD 部署 | 通過 | https://localhost:8443 |
| Gitea Runner CI | 通過 | Docker 建置正常 |
| GitOps 端到端流程 | 通過 | 完整流程驗證 |

---

## 已驗證的完整 GitOps 流程

```
Git Push → Gitea Actions → Docker Build → Registry Push → Manifest Update → ArgoCD Sync → App Deployed
```

### 測試結果詳情

| 步驟 | 組件 | 狀態 | 詳情 |
|------|------|------|------|
| 1 | Git Push | 通過 | 程式碼推送至 Gitea |
| 2 | Gitea Actions | 通過 | CI Pipeline 自動觸發 |
| 3 | Docker Build | 通過 | 使用 catthehacker/ubuntu:act-latest 映像 |
| 4 | Registry Push | 通過 | 映像推送至 172.18.0.1:5000 |
| 5 | Manifest Update | 通過 | k8s 清單自動更新映像標籤 |
| 6 | ArgoCD Sync | 通過 | 自動同步至 app-cluster |
| 7 | Pod Rollout | 通過 | 新版本 Pod 正常運行 |

---

## 服務訪問資訊

| 服務 | URL | 帳號 |
|------|-----|------|
| Gitea | http://gitea.local:3001 | admin / Admin@123 |
| ArgoCD | https://localhost:8443 | admin / (見 CREDENTIALS.md) |
| Registry | http://localhost:5000 | 無需認證 |
| Registry UI | http://localhost:8081 | 無需認證 |

### ArgoCD Port Forward 指令

```bash
./kubectl config use-context kind-argocd-cluster
./kubectl port-forward svc/argocd-server -n argocd 8443:443
```

---

## 部署過程中解決的問題

### 1. Port 衝突問題

**問題**: app-cluster 與 git-cluster 的 port 衝突

**解決方案**:
- Gitea: 3000 → 3001, 2222 → 2223
- app-cluster: 80 → 8088, 443 → 8448

### 2. inotify 限制錯誤

**問題**: Kind 節點出現 `too many open files` 錯誤

**解決方案**:
```bash
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
```

### 3. Registry PVC Pending

**問題**: local-path-provisioner 無法正常運作

**解決方案**: 將 Registry 部署改為使用 emptyDir

### 4. CI 建置 Docker 失敗

**問題**:
- `docker: command not found`
- `http: server gave HTTP response to HTTPS client`

**解決方案**:
1. 更新 Runner labels 使用 `catthehacker/ubuntu:act-latest` 映像
2. 配置 Docker daemon insecure-registries
3. 刪除 `.runner` 檔案重新註冊 Runner

### 5. ArgoCD 無法連接 app-cluster

**問題**: app-cluster 未在 ArgoCD 註冊

**解決方案**: 建立 ServiceAccount 並配置 cluster secret

### 6. app-cluster 無法拉取 Registry 映像

**問題**: containerd 未配置 insecure registry

**解決方案**:
```bash
docker exec app-cluster-control-plane bash -c 'cat >> /etc/containerd/config.toml << EOF
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."172.18.0.1:5000"]
  endpoint = ["http://172.18.0.1:5000"]
EOF'
docker exec app-cluster-control-plane systemctl restart containerd
```

---

## Kubernetes Clusters 狀態

| Cluster | Context | 用途 |
|---------|---------|------|
| argocd-cluster | kind-argocd-cluster | ArgoCD GitOps CD |
| git-cluster | kind-git-cluster | 保留擴展用 |
| app-cluster | kind-app-cluster | 應用程式部署 |

### 檢查指令

```bash
# 列出所有 clusters
kind get clusters

# 檢查特定 cluster
./kubectl get pods -A --context kind-argocd-cluster
./kubectl get pods -A --context kind-app-cluster

# 檢查 ArgoCD Applications
./kubectl get applications -n argocd --context kind-argocd-cluster
```

---

## Registry 映像清單

```bash
# 查看所有映像
curl -s http://localhost:5000/v2/_catalog

# 查看特定映像標籤
curl -s http://localhost:5000/v2/test-app/tags/list
curl -s http://localhost:5000/v2/oracle-xe/tags/list
```

---

## 下次部署注意事項

1. **先執行 inotify 設定** - 避免 Kind 節點崩潰
2. **配置 Docker insecure-registries** - CI 建置需要
3. **使用正確的 ports** - Gitea: 3001/2223
4. **Runner 重新註冊** - 修改 labels 後需要

---

## 文件連結

- [主要使用指南](README.md)
- [Gitea Runner 設定](gitea-runner/README.md)
- [ArgoCD 使用指南](argocd/README.md)
- [認證資訊](CREDENTIALS.md) (已加入 .gitignore)

---

**最後更新**: 2025-12-14
**測試人員**: Claude Code
