# CI/CD Integration Server - 輕量級本地開發環境

> 完整的 CI/CD 整合環境，採用 Gitea + Kind + ArgoCD 架構，大幅降低資源需求

---

## 目錄

- [專案簡介](#專案簡介)
- [系統架構](#系統架構)
- [核心概念](#核心概念)
- [學習路徑](#學習路徑)
- [環境需求](#環境需求)
- [快速安裝](#快速安裝)
- [目錄結構](#目錄結構)
- [服務訪問](#服務訪問)
- [進階設定](#進階設定)
- [維護指南](#維護指南)
- [故障排除](#故障排除)
- [學習資源](#學習資源)

---

## 專案簡介

這是一個為本地開發設計的輕量級 CI/CD 整合環境。使用 **Gitea** 取代 GitLab，搭配 **Kind** (Kubernetes in Docker) 和 **ArgoCD**，實現完整的 GitOps 持續部署流程。

### 為什麼選擇這個方案？

| 項目 | 傳統方案 (GitLab) | 本方案 (Gitea) | 優勢 |
|------|-------------------|----------------|------|
| Git 服務 | 8 GB RAM | 0.5 GB RAM | 省 7.5 GB |
| CI Runner | 4 GB RAM | 0.5 GB RAM | 省 3.5 GB |
| 啟動時間 | 3-5 分鐘 | 5-10 秒 | 快 30 倍 |
| 學習曲線 | 較陡峭 | 平緩 (類似 GitHub) | 易上手 |
| **總計** | ~56 GB | **~45 GB** | **省 11 GB** |

### 主要特色

- **三個獨立 Kind Clusters**：ArgoCD、Git、Applications 分離部署
- **Gitea + Actions**：輕量級 Git 服務，相容 GitHub Actions 語法
- **ArgoCD GitOps**：自動化持續部署
- **本地 Docker Registry**：私有 Image 倉庫
- **Oracle XE 整合**：支援整合測試環境

---

## 系統架構

### 整體架構圖

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Host Machine (建議 64GB RAM)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Kind Kubernetes Clusters                       │  │
│  │                                                                   │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────────┐  │  │
│  │  │ ArgoCD Cluster │  │  Git Cluster   │  │    App Cluster     │  │  │
│  │  │                │  │                │  │                    │  │  │
│  │  │  - ArgoCD      │  │  - (保留)       │  │  - Registry        │  │  │
│  │  │  - GitOps CD   │  │                │  │  - Registry UI     │  │  │
│  │  │                │  │                │  │  - Applications    │  │  │
│  │  │  Port: 8443    │  │                │  │  - Oracle XE       │  │  │
│  │  └────────────────┘  └────────────────┘  └────────────────────┘  │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌────────────────┐    ┌────────────────┐                              │
│  │     Gitea      │    │  Gitea Runner  │                              │
│  │   (Docker)     │    │   (Docker)     │                              │
│  │                │    │                │                              │
│  │  - Git Repos   │◄──►│  - CI/CD Jobs  │                              │
│  │  - Web UI      │    │  - Actions     │                              │
│  │  - Actions CI  │    │                │                              │
│  │                │    │                │                              │
│  │  Port: 3000    │    │                │                              │
│  │  SSH:  2222    │    │                │                              │
│  └────────────────┘    └────────────────┘                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### CI/CD 流程

```
開發者 Push Code
       │
       ▼
Gitea Actions 觸發 CI
       │
       ▼
┌─────────────────────────────────────────┐
│  Build → Test → Build Image → Push      │
└─────────────────────────────────────────┘
       │
       ▼
更新 GitOps Repository (Image Tag)
       │
       ▼
ArgoCD 偵測變更
       │
       ▼
自動同步到 Kubernetes Cluster
       │
       ▼
應用程式部署完成
```

---

## 核心概念

### 1. Kind (Kubernetes in Docker)

**Kind** 是一個在 Docker 容器內運行 Kubernetes 的工具，非常適合本地開發和測試。

**特點：**
- 快速建立/銷毀 Kubernetes cluster
- 支援多節點配置
- 資源消耗比完整 K8s 低

**本專案使用三個獨立 Cluster：**
- `argocd-cluster`：運行 ArgoCD
- `git-cluster`：保留供未來擴展
- `app-cluster`：運行應用程式和 Registry

### 2. Gitea

**Gitea** 是輕量級的 Git 服務，功能類似 GitHub/GitLab。

**特點：**
- 記憶體需求極低 (約 500MB)
- 內建 CI/CD (Gitea Actions，相容 GitHub Actions)
- 支援 Container Registry
- 快速啟動 (秒級)

### 3. Gitea Actions

**Gitea Actions** 是 Gitea 的 CI/CD 功能，語法與 GitHub Actions 相容。

**Workflow 檔案位置：** `.gitea/workflows/`

**範例：**
```yaml
name: CI Pipeline
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm install
      - run: npm test
```

### 4. ArgoCD 與 GitOps

**GitOps** 是一種使用 Git 作為單一事實來源的部署方法。

**ArgoCD** 是 Kubernetes 原生的 GitOps 工具：
- 監控 Git Repository 變更
- 自動同步到 Kubernetes
- 支援回滾和差異比對
- 提供視覺化管理介面

**GitOps 優勢：**
- 所有配置都在 Git 中版本控制
- 易於審計和回滾
- 聲明式配置

### 5. Docker Registry

**本地 Docker Registry** 用於儲存和分發 Docker images。

**優勢：**
- 不需要網路即可拉取 images
- 加速 CI/CD 流程
- 保護私有 images

---

## 學習路徑

### 階段一：基礎環境 (第 1-2 天)

```
1. 了解 Docker 基礎
   └── 容器、映像檔、docker-compose

2. 了解 Kubernetes 基礎
   └── Pod、Deployment、Service、Namespace

3. 安裝本專案環境
   └── 執行 deploy-all.sh
```

**學習重點：**
- Docker 容器運作原理
- Kubernetes 基本資源類型
- Kind 的使用方式

### 階段二：Git 服務 (第 3-4 天)

```
1. 設定 Gitea
   └── 初始化、建立帳號、建立 Repository

2. 設定 Gitea Runner
   └── 取得 Token、啟動 Runner

3. 撰寫第一個 Workflow
   └── .gitea/workflows/ci.yaml
```

**學習重點：**
- Git 工作流程
- CI/CD Pipeline 概念
- GitHub Actions 語法

### 階段三：GitOps 部署 (第 5-7 天)

```
1. 了解 ArgoCD
   └── 安裝、登入、基本操作

2. 連接 Repository
   └── 設定 Gitea 連線

3. 建立 Application
   └── 設定自動同步
```

**學習重點：**
- GitOps 原則
- ArgoCD Application 配置
- Kustomize 或 Helm 使用

### 階段四：完整流程整合 (第 8-10 天)

```
1. 設計完整 CI/CD Pipeline
   └── Build → Test → Push → Deploy

2. 設定整合測試
   └── Oracle 資料庫測試

3. 監控與維護
   └── 日誌、備份、問題排查
```

**學習重點：**
- 端到端 CI/CD 流程
- 測試策略
- 生產環境最佳實踐

### 推薦學習順序

| 順序 | 主題 | 相關檔案 |
|------|------|----------|
| 1 | Docker 基礎 | `gitea/docker-compose.yaml` |
| 2 | Kind & K8s | `kind-*.yaml`, `create-clusters.sh` |
| 3 | Gitea 設定 | `gitea-runner/README.md` |
| 4 | CI Pipeline | `workflows/ci-example.yaml` |
| 5 | ArgoCD | `argocd/README.md` |
| 6 | 完整流程 | `tasks-gitea.md` |

---

## 環境需求

### 硬體需求

| 項目 | 最低需求 | 建議配置 |
|------|----------|----------|
| CPU | 4 核心 | 8+ 核心 |
| RAM | 32 GB | 64 GB |
| 磁碟 | 256 GB SSD | 512 GB SSD |

### 軟體需求

| 軟體 | 版本 | 安裝指令 (Ubuntu) |
|------|------|-------------------|
| Docker | 24.x+ | `apt install docker.io` |
| Kind | 0.20+ | 從 [官網](https://kind.sigs.k8s.io/) 下載 |
| kubectl | 1.28+ | 專案已內含 |
| Git | 2.x+ | `apt install git` |

### 記憶體分配 (預估)

| 組件 | 記憶體 |
|------|--------|
| Host OS | 4 GB |
| Docker Engine | 2 GB |
| Gitea | 0.5 GB |
| Gitea Runner | 0.5 GB |
| Kind Clusters | 16 GB |
| 緩衝空間 | 20+ GB |
| **總計** | **~45 GB** |

---

## 快速安裝

### 一鍵部署 (推薦)

```bash
# 1. 進入專案目錄
cd /path/to/cicd

# 2. 執行部署腳本
./deploy-all.sh
```

部署腳本會自動：
1. 配置 `/etc/hosts`
2. 創建三個 Kind clusters
3. 部署 Gitea、Registry、ArgoCD
4. 下載並推送 Oracle image

### 手動分步部署

#### 步驟 1: 設定 Docker 權限

```bash
./setup-docker-permissions.sh
# 然後執行 newgrp docker 或重新登入
```

#### 步驟 2: 配置 /etc/hosts

```bash
sudo bash -c 'cat >> /etc/hosts << EOF

# CI/CD Integration Server
127.0.0.1  gitea.local
127.0.0.1  registry.local
127.0.0.1  argocd.local
EOF'
```

#### 步驟 3: 創建 Kind Clusters

```bash
# 一般方式
./create-clusters.sh

# 或使用 sudo
./create-clusters-sudo.sh
```

#### 步驟 4: 部署 Gitea

```bash
cd gitea
docker-compose up -d
# 訪問 http://gitea.local:3000 完成初始設定
```

#### 步驟 5: 部署 Registry

```bash
./kubectl config use-context kind-app-cluster
./kubectl create namespace registry
./kubectl apply -f registry/
```

#### 步驟 6: 部署 ArgoCD

```bash
./kubectl config use-context kind-argocd-cluster
./kubectl create namespace argocd
./kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

## 目錄結構

```
cicd/
├── README.md                    # 本文件
├── SUMMARY.md                   # 專案總結
├── tasks-gitea.md               # 詳細任務清單
├── DEPLOYMENT-STATUS.md         # 部署狀態報告
├── DEPLOY-COMMANDS.md           # 部署命令指南
│
├── 腳本檔案
│   ├── deploy-all.sh            # 一鍵部署腳本
│   ├── create-clusters.sh       # Cluster 創建腳本
│   ├── create-clusters-sudo.sh  # Cluster 創建腳本 (sudo)
│   ├── execute-deployment.sh    # 執行部署工具
│   ├── deploy-step-by-step.sh   # 分步部署腳本
│   └── setup-docker-permissions.sh  # Docker 權限設定
│
├── Kind 配置
│   ├── kind-argocd-cluster.yaml # ArgoCD Cluster 配置
│   ├── kind-git-cluster.yaml    # Git Cluster 配置
│   └── kind-app-cluster.yaml    # App Cluster 配置
│
├── gitea/                       # Gitea 配置
│   └── docker-compose.yaml      # Gitea Docker Compose
│
├── gitea-runner/                # Gitea Actions Runner
│   ├── docker-compose.yaml      # Runner Docker Compose
│   ├── config.yaml              # Runner 配置
│   ├── .env.template            # 環境變數範本
│   └── README.md                # Runner 設定指南
│
├── registry/                    # Docker Registry K8s Manifests
│   ├── registry-pvc.yaml        # 持久化儲存
│   ├── registry-deployment.yaml # Registry 部署
│   └── registry-ui-deployment.yaml  # Registry UI 部署
│
├── argocd/                      # ArgoCD 配置
│   ├── application-example.yaml # Application 範例
│   └── README.md                # ArgoCD 使用指南
│
├── workflows/                   # Gitea Actions Workflow 範例
│   ├── ci-example.yaml          # CI Pipeline 範例
│   └── integration-test-example.yaml  # 整合測試範例
│
├── db/                          # 資料庫腳本
│   ├── migration/               # Flyway Migration 腳本
│   └── scripts/                 # 工具腳本
│
└── kubectl                      # kubectl 執行檔
```

---

## 服務訪問

### 服務列表

| 服務 | URL | 說明 |
|------|-----|------|
| Gitea Web | http://gitea.local:3000 | Git 服務 Web UI |
| Gitea SSH | ssh://gitea.local:2222 | Git SSH 存取 |
| Registry API | http://localhost:5000 | Docker Registry |
| Registry UI | http://localhost:8081 | Registry Web 介面 |
| ArgoCD | https://localhost:8443 | 需先 port-forward |

### 訪問 ArgoCD

```bash
# 1. 啟動 port-forward (在背景或新終端執行)
./kubectl config use-context kind-argocd-cluster
./kubectl port-forward svc/argocd-server -n argocd 8443:443

# 2. 取得初始密碼
./kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo

# 3. 登入
# URL: https://localhost:8443
# 帳號: admin
# 密碼: (步驟 2 取得)
```

### 訪問 Gitea

1. 開啟 http://gitea.local:3000
2. 首次訪問需完成初始設定：
   - 資料庫選擇 SQLite3
   - 設定管理員帳號密碼
3. 建立 Organization 和 Repositories

---

## 進階設定

### 設定 Gitea Actions Runner

詳細步驟請參考 [gitea-runner/README.md](gitea-runner/README.md)

```bash
# 1. 在 Gitea 取得 Runner Token
# 路徑: Site Administration > Actions > Runners > Create new Runner

# 2. 配置環境變數
cd gitea-runner
cp .env.template .env
# 編輯 .env，填入 RUNNER_TOKEN

# 3. 啟動 Runner
docker-compose up -d

# 4. 驗證 Runner 狀態 (在 Gitea UI 查看)
```

### 配置 ArgoCD 連接 Gitea

詳細步驟請參考 [argocd/README.md](argocd/README.md)

```bash
# 1. 在 Gitea 建立 Access Token
# 路徑: User Settings > Applications > Generate New Token

# 2. 在 ArgoCD 新增 Repository
# Settings > Repositories > Connect Repo
# URL: http://gitea.local:3000/org/repo.git
# Username: your-username
# Password: your-access-token
```

### 撰寫 CI Pipeline

將 `workflows/ci-example.yaml` 複製到你的 Repository：

```bash
# 在你的專案中
mkdir -p .gitea/workflows
cp /path/to/cicd/workflows/ci-example.yaml .gitea/workflows/ci.yaml

# 修改配置後提交
git add .gitea/workflows/ci.yaml
git commit -m "Add CI pipeline"
git push
```

---

## 維護指南

### 檢查系統狀態

```bash
# 檢查所有 clusters
kind get clusters

# 檢查特定 cluster
./kubectl cluster-info --context kind-argocd-cluster
./kubectl cluster-info --context kind-app-cluster

# 檢查所有 pods
./kubectl get pods -A --context kind-argocd-cluster
./kubectl get pods -A --context kind-app-cluster

# 檢查 Gitea 容器
docker ps | grep gitea

# 檢查資源使用
docker stats
./kubectl top nodes --context kind-app-cluster
```

### 備份

```bash
# Gitea 資料備份
docker exec -t gitea /bin/sh -c 'gitea dump -c /data/gitea/conf/app.ini'

# Registry 資料 (位於 K8s PVC)
./kubectl get pvc -n registry --context kind-app-cluster
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

# 清理 Docker volumes (可選)
docker volume prune
```

### 定期維護

| 頻率 | 任務 | 指令 |
|------|------|------|
| 每日 | 檢查容器狀態 | `docker ps -a` |
| 每週 | 檢查磁碟空間 | `df -h` |
| 每月 | 清理未使用 images | `docker system prune` |
| 每季 | 更新組件版本 | 修改各 docker-compose.yaml |

---

## 故障排除

### Gitea 無法訪問

```bash
# 檢查容器狀態
docker logs gitea
docker ps | grep gitea

# 確認 /etc/hosts 配置
cat /etc/hosts | grep gitea

# 重啟 Gitea
cd gitea && docker-compose restart
```

### Registry 無法推送 Image

```bash
# 檢查 Registry 狀態
./kubectl get pods -n registry --context kind-app-cluster
./kubectl logs -n registry deployment/docker-registry --context kind-app-cluster

# 測試連線
curl http://localhost:5000/v2/_catalog
```

### ArgoCD 無法同步

```bash
# 檢查 Application 狀態
./kubectl get applications -n argocd --context kind-argocd-cluster

# 查看詳細錯誤
./kubectl describe application <app-name> -n argocd --context kind-argocd-cluster

# 查看 logs
./kubectl logs -n argocd deployment/argocd-application-controller --context kind-argocd-cluster
```

### Gitea Runner 離線

```bash
# 檢查 Runner 日誌
docker logs gitea-runner

# 常見問題：
# - Token 錯誤：重新產生 token
# - 網路問題：確認容器網路連通
# - Docker socket：確認權限正確

# 重新註冊 Runner
cd gitea-runner
docker-compose down
rm -rf runner-data/*
# 更新 .env 中的 RUNNER_TOKEN
docker-compose up -d
```

### 常見問題速查表

| 問題 | 可能原因 | 解決方案 |
|------|----------|----------|
| Gitea Actions 未觸發 | Runner 未連線 | 檢查 Runner Token、網路 |
| Image push 失敗 | Registry 不可達 | 檢查 insecure-registry 配置 |
| ArgoCD 無法同步 | Repository 認證失敗 | 檢查 Access Token |
| Oracle 啟動緩慢 | 記憶體不足 | 增加 container memory |
| Cluster 創建失敗 | Docker 權限不足 | 使用 sudo 或設定 docker group |

---

## 學習資源

### 官方文件

| 工具 | 文件連結 |
|------|----------|
| Kind | https://kind.sigs.k8s.io/ |
| Gitea | https://docs.gitea.io/ |
| Gitea Actions | https://docs.gitea.io/en-us/actions-overview/ |
| ArgoCD | https://argo-cd.readthedocs.io/ |
| GitOps 原則 | https://opengitops.dev/ |

### 本專案文件

| 文件 | 說明 |
|------|------|
| [tasks-gitea.md](tasks-gitea.md) | 詳細部署任務清單 |
| [gitea-runner/README.md](gitea-runner/README.md) | Runner 設定指南 |
| [argocd/README.md](argocd/README.md) | ArgoCD 使用指南 |
| [SUMMARY.md](SUMMARY.md) | 專案完整總結 |

### 延伸學習

- **Kubernetes 基礎**：Pod、Deployment、Service、ConfigMap、Secret
- **Docker 進階**：多階段建置、最佳實踐
- **CI/CD 模式**：藍綠部署、金絲雀部署
- **GitOps 工具**：Flux、ArgoCD 比較

---

## 技術棧

| 組件 | 版本 | 說明 |
|------|------|------|
| Docker | 24.x+ | 容器運行時 |
| Kind | 0.20+ | Kubernetes in Docker |
| Kubernetes | 1.28+ | 容器編排 |
| Gitea | 1.21+ | Git 服務 |
| act_runner | 0.2.6+ | CI Runner |
| ArgoCD | 2.9+ | GitOps CD |
| Oracle XE | 21.3.0 | 測試資料庫 |

---

## 授權

本專案為內部使用的 CI/CD 環境配置，基於開源工具搭建。

---

**建立日期**：2025-12-14
**最後更新**：2025-12-14
**版本**：v1.0
