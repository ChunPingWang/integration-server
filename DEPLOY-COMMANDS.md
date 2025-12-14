# 部署命令清單

由於需要 sudo 權限，請按順序手動執行以下命令：

## 1. 配置 /etc/hosts

```bash
sudo bash -c 'cat >> /etc/hosts << EOF

# CI/CD Integration Server
127.0.0.1  gitea.local
127.0.0.1  registry.local
127.0.0.1  argocd.local
EOF'
```

驗證：
```bash
cat /etc/hosts | tail -5
```

## 2. 創建 Kind Clusters

### 創建 ArgoCD Cluster
```bash
sudo kind create cluster --config kind-argocd-cluster.yaml
```

### 創建 Git Cluster
```bash
sudo kind create cluster --config kind-git-cluster.yaml
```

### 創建 App Cluster
```bash
sudo kind create cluster --config kind-app-cluster.yaml
```

### 修復 kubeconfig 權限
```bash
sudo chown -R $USER:$USER ~/.kube
```

### 驗證 Clusters
```bash
sudo kind get clusters
./kubectl config get-contexts
```

## 3. 部署 Gitea

```bash
cd gitea
sudo docker-compose up -d
cd ..
```

驗證：
```bash
sudo docker ps | grep gitea
```

等待 10 秒後訪問: http://gitea.local:3001

## 4. 部署 Docker Registry

```bash
./kubectl config use-context kind-app-cluster
./kubectl create namespace registry
./kubectl apply -f registry/registry-pvc.yaml
./kubectl apply -f registry/registry-deployment.yaml
./kubectl apply -f registry/registry-ui-deployment.yaml
```

等待 Registry 啟動：
```bash
./kubectl get pods -n registry -w
# 按 Ctrl+C 停止監看
```

驗證：
```bash
curl http://localhost:5000/v2/_catalog
```

訪問 Registry UI: http://localhost:8081

## 5. 部署 ArgoCD

```bash
./kubectl config use-context kind-argocd-cluster
./kubectl create namespace argocd
./kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

等待 ArgoCD 啟動（約 2-3 分鐘）：
```bash
./kubectl get pods -n argocd -w
# 按 Ctrl+C 停止監看
```

取得 ArgoCD 初始密碼：
```bash
./kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

啟動 Port Forward（在新終端執行）：
```bash
cd /home/rexwang/workspace/cicd
./kubectl port-forward svc/argocd-server -n argocd 8443:443
```

訪問 ArgoCD: https://localhost:8443
- Username: `admin`
- Password: (從上一步取得)

## 6. 下載並推送 Oracle Image（可選）

```bash
sudo docker pull gvenzl/oracle-xe:21-slim
sudo docker tag gvenzl/oracle-xe:21-slim localhost:5000/oracle-xe:21-slim
sudo docker push localhost:5000/oracle-xe:21-slim
```

驗證：
```bash
curl http://localhost:5000/v2/oracle-xe/tags/list
```

## 7. 驗證所有服務

```bash
# 檢查 Clusters
sudo kind get clusters

# 檢查 Pods
./kubectl get pods -A --context kind-argocd-cluster
./kubectl get pods -A --context kind-app-cluster

# 檢查 Gitea
sudo docker ps | grep gitea

# 檢查 Registry
curl http://localhost:5000/v2/_catalog
```

## 完成！

所有服務已部署完成。現在可以：

1. 訪問 http://gitea.local:3001 完成 Gitea 初始設定
2. 建立 Organization 和 Repositories
3. 設定 Gitea Actions Runner（參考 gitea-runner/README.md）
4. 配置 ArgoCD 連接到 Gitea（參考 argocd/README.md）
5. 測試 CI/CD Pipeline

## 故障排除

### 如果 /etc/hosts 配置後 gitea.local 無法解析
```bash
ping gitea.local
# 如果失敗，確認 /etc/hosts 內容正確
cat /etc/hosts | grep gitea
```

### 如果 kubectl 無法連接 cluster
```bash
./kubectl config get-contexts
./kubectl config use-context kind-app-cluster
./kubectl get nodes
```

### 如果 Registry 無法訪問
```bash
./kubectl get pods -n registry --context kind-app-cluster
./kubectl logs -n registry deployment/docker-registry --context kind-app-cluster
```
