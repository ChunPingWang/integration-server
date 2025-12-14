# CI/CD Integration Server - 輕量級本地開發環境

> 完整的 CI/CD 整合環境，採用 Gitea + Kind + ArgoCD + Backstage 架構，大幅降低資源需求

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
- [Backstage 開發者入口](#backstage-開發者入口)
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

- **四個獨立 Kind Clusters**：ArgoCD、Git、Applications、Backstage 分離部署
- **Gitea + Actions**：輕量級 Git 服務，相容 GitHub Actions 語法
- **ArgoCD GitOps**：自動化持續部署
- **本地 Docker Registry**：私有 Image 倉庫
- **Backstage Developer Portal**：統一的開發者入口平台
- **Oracle XE 整合**：支援整合測試環境

---

## 系統架構

### 整體架構圖

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       Host Machine (建議 64GB RAM)                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                      Kind Kubernetes Clusters                          │  │
│  │                                                                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │  │
│  │  │ArgoCD Cluster│  │ Git Cluster  │  │ App Cluster  │  │ Backstage  │  │  │
│  │  │              │  │              │  │              │  │  Cluster   │  │  │
│  │  │  - ArgoCD    │  │  - (保留)     │  │  - Registry  │  │            │  │  │
│  │  │  - GitOps CD │  │              │  │  - Apps      │  │ - Backstage│  │  │
│  │  │              │  │              │  │  - Oracle XE │  │ - PostgreSQL│ │  │
│  │  │  Port: 8443  │  │              │  │  Port: 5000  │  │  Port: 7007│  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └────────────┘  │  │
│  │                                                                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────┐    ┌────────────────┐                                    │
│  │     Gitea      │    │  Gitea Runner  │                                    │
│  │   (Docker)     │    │   (Docker)     │                                    │
│  │                │    │                │                                    │
│  │  - Git Repos   │◄──►│  - CI/CD Jobs  │                                    │
│  │  - Web UI      │    │  - Actions     │                                    │
│  │  - Actions CI  │    │                │                                    │
│  │                │    │                │                                    │
│  │  Port: 3001    │    │                │                                    │
│  │  SSH:  2223    │    │                │                                    │
│  └────────────────┘    └────────────────┘                                    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
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

**本專案使用四個獨立 Cluster：**
- `argocd-cluster`：運行 ArgoCD
- `git-cluster`：保留供未來擴展
- `app-cluster`：運行應用程式和 Registry
- `backstage-cluster`：運行 Backstage 開發者入口平台

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
# 訪問 http://gitea.local:3001 完成初始設定
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
│   ├── kind-argocd-cluster.yaml    # ArgoCD Cluster 配置
│   ├── kind-git-cluster.yaml       # Git Cluster 配置
│   ├── kind-app-cluster.yaml       # App Cluster 配置
│   └── kind-backstage-cluster.yaml # Backstage Cluster 配置
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
├── backstage/                   # Backstage 開發者入口
│   ├── README.md                # Backstage 設定指南
│   ├── helm-values.yaml         # Helm 安裝配置
│   ├── catalog-info.yaml        # 服務目錄定義
│   └── *.yaml                   # Kubernetes 部署配置
│
├── ingress/                     # Ingress 設定 (遠端訪問)
│   ├── README.md                # Ingress 設定指南
│   ├── deploy-ingress-controller.sh  # 部署 Ingress Controller
│   ├── apply-ingress-rules.sh   # 部署 Ingress 規則
│   ├── argocd-ingress.yaml      # ArgoCD Ingress
│   ├── backstage-ingress.yaml   # Backstage Ingress
│   └── registry-ingress.yaml    # Registry Ingress
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
| Gitea Web | http://gitea.local:3001 | Git 服務 Web UI |
| Gitea SSH | ssh://gitea.local:2223 | Git SSH 存取 |
| Registry API | http://localhost:5000 | Docker Registry |
| Registry UI | http://localhost:8081 | Registry Web 介面 |
| ArgoCD | https://localhost:8443 | 需先 port-forward |
| Backstage | http://localhost:7007 | 開發者入口平台 |

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

1. 開啟 http://gitea.local:3001
2. 首次訪問需完成初始設定：
   - 資料庫選擇 SQLite3
   - 設定管理員帳號密碼
3. 建立 Organization 和 Repositories

---

## 遠端訪問設定

### 使用 Ingress Controller 遠端訪問

若需從其他電腦訪問 CI/CD 服務，可以設定 Ingress Controller：

```bash
# 1. 部署 NGINX Ingress Controller
./ingress/deploy-ingress-controller.sh

# 2. 部署 Ingress 規則
./ingress/apply-ingress-rules.sh
```

### 遠端機器配置

在遠端機器的 `/etc/hosts` 加入 (將 `SERVER_IP` 替換為實際 IP)：

```bash
sudo bash -c 'cat >> /etc/hosts << EOF

# CI/CD Integration Server
SERVER_IP  argocd.local
SERVER_IP  backstage.local
SERVER_IP  registry.local
SERVER_IP  registry-ui.local
SERVER_IP  gitea.local
EOF'
```

### 遠端訪問 URL

| 服務 | URL | 端口 |
|------|-----|------|
| ArgoCD | https://argocd.local:8443 | 8443 |
| Backstage | http://backstage.local:7080 | 7080 |
| Registry | http://registry.local:8088 | 8088 |
| Gitea | http://gitea.local:3001 | 3001 |

### 防火牆設定

確保以下端口可從遠端訪問：

```bash
# Ubuntu/Debian (使用 ufw)
sudo ufw allow 3001/tcp  # Gitea
sudo ufw allow 7007/tcp  # Backstage (NodePort)
sudo ufw allow 7080/tcp  # Backstage (Ingress)
sudo ufw allow 8080/tcp  # ArgoCD HTTP
sudo ufw allow 8443/tcp  # ArgoCD HTTPS
sudo ufw allow 8088/tcp  # Registry
sudo ufw allow 5000/tcp  # Registry (NodePort)
```

詳細說明請參考 [ingress/README.md](ingress/README.md)

---

## Backstage 開發者入口

### 簡介

[Backstage](https://backstage.io/) 是由 Spotify 開發的開源開發者入口平台。本專案已整合 Backstage，提供統一的服務目錄和文件入口，讓使用者可以在一個介面中查看所有 CI/CD 服務的狀態和資訊。

### 訪問 Backstage

部署完成後，直接訪問：**http://localhost:7007**

- **認證模式**: Guest (開發環境)
- **登入方式**: 點擊 "Enter" 按鈕直接進入

### Backstage 架構

```
┌─────────────────────────────────────────────────────────┐
│                  Backstage Developer Portal              │
│                  http://localhost:7007                   │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Catalog    │  │    APIs     │  │  TechDocs   │     │
│  │  服務目錄    │  │  API 文件   │  │  技術文件    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │              catalog-info.yaml                     │  │
│  │  (GitHub: integration-server/backstage/)          │  │
│  │                                                    │  │
│  │  定義: Domain, System, Components, APIs,          │  │
│  │        Resources, Groups, Users                   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
├─────────────────────────────────────────────────────────┤
│  PostgreSQL │ backstage-postgresql:5432                  │
└─────────────────────────────────────────────────────────┘
```

### Service Catalog (服務目錄)

Backstage 使用 **catalog-info.yaml** 定義所有服務和資源。目前的 Catalog 包含：

| 類型 | 數量 | 說明 |
|------|------|------|
| Domain | 1 | CI/CD 基礎設施領域 |
| System | 1 | CI/CD Integration Server 系統 |
| Component | 5 | Gitea, Runner, ArgoCD, Registry, Backstage |
| API | 2 | Gitea REST API, Docker Registry API |
| Resource | 6 | 4 個 K8s Clusters + PostgreSQL + Oracle Image |
| Group | 1 | CI/CD Team |
| User | 1 | Admin |

### Catalog 實體說明

#### 1. Domain (領域)
定義業務或技術領域，用於組織多個 Systems。

```yaml
apiVersion: backstage.io/v1alpha1
kind: Domain
metadata:
  name: cicd-infrastructure
  title: CI/CD Infrastructure
spec:
  owner: cicd-team
```

#### 2. System (系統)
代表一組相關的 Components 和 Resources。

```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: cicd-integration-server
  title: CI/CD Integration Server
spec:
  owner: cicd-team
  domain: cicd-infrastructure
```

#### 3. Component (組件)
代表可部署的軟體單元，如服務、網站、函式庫等。

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: gitea-server
  title: Gitea Git Server
  description: |
    ## 服務說明
    輕量級 Git 服務...
  links:
    - url: http://gitea.local:3001
      title: Gitea Web UI
      icon: web
spec:
  type: service          # service, website, library
  lifecycle: production  # experimental, production, deprecated
  owner: cicd-team
  system: cicd-integration-server
  providesApis:
    - gitea-api
```

#### 4. API
定義服務提供的 API 介面。

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: gitea-api
  title: Gitea REST API
spec:
  type: openapi
  lifecycle: production
  owner: cicd-team
  definition: |
    openapi: 3.0.0
    info:
      title: Gitea API
      version: "1.0"
```

#### 5. Resource (資源)
代表基礎設施資源，如資料庫、Kubernetes Clusters 等。

```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: argocd-cluster
  title: ArgoCD Kind Cluster
spec:
  type: kubernetes-cluster  # database, s3-bucket, kubernetes-cluster
  owner: cicd-team
  system: cicd-integration-server
```

### 配置檔案說明

#### backstage/helm-values.yaml
Helm 安裝的主要配置檔案，定義：
- Backstage 映像和資源限制
- 應用程式基礎 URL
- 認證設定 (Guest 模式)
- PostgreSQL 資料庫連線
- Catalog 初始位置

```yaml
backstage:
  appConfig:
    app:
      baseUrl: http://localhost:7007
    auth:
      environment: development
      providers:
        guest:
          dangerouslyAllowOutsideDevelopment: true
    catalog:
      locations:
        - type: url
          target: https://raw.githubusercontent.com/.../catalog-info.yaml
```

#### backstage/app-config-override.yaml
Kubernetes ConfigMap，覆蓋預設配置：
- 允許讀取 GitHub raw 檔案
- Catalog 規則 (允許的實體類型)

```yaml
backend:
  reading:
    allow:
      - host: raw.githubusercontent.com
      - host: github.com
catalog:
  rules:
    - allow: [Component, System, API, Resource, Location, Group, User, Template, Domain]
```

#### backstage/catalog-info.yaml
服務目錄定義檔，包含所有 CI/CD 服務的詳細資訊。每個服務包含：
- 存取資訊 (URL、帳號密碼)
- 操作指令 (kubectl 命令)
- 健康檢查命令
- 相關連結

### 新增服務到 Catalog

#### 方法 1: 編輯 catalog-info.yaml

1. 編輯 `backstage/catalog-info.yaml`，新增 Component：

```yaml
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-new-service
  title: My New Service
  description: |
    ## 服務說明
    描述你的服務...

    ## 存取資訊
    - **URL**: http://localhost:8080
  links:
    - url: http://localhost:8080
      title: Service URL
      icon: web
  tags:
    - my-tag
spec:
  type: service
  lifecycle: production
  owner: cicd-team
  system: cicd-integration-server
```

2. 提交並推送到 GitHub：

```bash
git add backstage/catalog-info.yaml
git commit -m "新增: My New Service 到 Backstage Catalog"
git push
```

3. Backstage 會自動抓取更新 (約 1-5 分鐘)

#### 方法 2: 透過 Backstage UI 註冊

1. 開啟 http://localhost:7007
2. 點擊左側 **Create** 選單
3. 選擇 **Register Existing Component**
4. 輸入 catalog-info.yaml 的 URL
5. 點擊 **Analyze** 然後 **Import**

### 手動重新整理 Catalog

如果需要立即更新 Catalog：

```bash
# 1. 取得認證 Token
TOKEN=$(curl -s -X POST http://localhost:7007/api/auth/guest/refresh \
  -H "Content-Type: application/json" | jq -r '.backstageIdentity.token')

# 2. 刪除舊的 Location
LOCATION_ID=$(curl -s http://localhost:7007/api/catalog/locations \
  -H "Authorization: Bearer $TOKEN" | jq -r '.[0].data.id')

curl -X DELETE "http://localhost:7007/api/catalog/locations/$LOCATION_ID" \
  -H "Authorization: Bearer $TOKEN"

# 3. 重新註冊 Catalog Location
curl -X POST http://localhost:7007/api/catalog/locations \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"url","target":"https://raw.githubusercontent.com/ChunPingWang/integration-server/main/backstage/catalog-info.yaml"}'

# 4. 等待處理完成 (約 10-30 秒)
sleep 15

# 5. 驗證實體數量
curl -s http://localhost:7007/api/catalog/entities \
  -H "Authorization: Bearer $TOKEN" | jq 'length'
```

### 查看 Catalog API

```bash
# 取得 Token
TOKEN=$(curl -s -X POST http://localhost:7007/api/auth/guest/refresh \
  -H "Content-Type: application/json" | jq -r '.backstageIdentity.token')

# 列出所有實體
curl -s http://localhost:7007/api/catalog/entities \
  -H "Authorization: Bearer $TOKEN" | jq '.[].metadata.name'

# 依類型篩選
curl -s "http://localhost:7007/api/catalog/entities?filter=kind=Component" \
  -H "Authorization: Bearer $TOKEN" | jq '.[].metadata.name'

# 取得特定實體
curl -s "http://localhost:7007/api/catalog/entities/by-name/component/default/gitea-server" \
  -H "Authorization: Bearer $TOKEN" | jq '.metadata.title'
```

### 部署 Backstage

如果需要手動部署 Backstage：

```bash
# 1. 創建 Backstage Cluster (如尚未創建)
kind create cluster --config kind-backstage-cluster.yaml

# 2. 切換到 Backstage cluster context
./kubectl config use-context kind-backstage-cluster

# 3. 使用 Helm 安裝 Backstage
./helm repo add backstage https://backstage.github.io/charts
./helm repo update
./helm install backstage backstage/backstage -n backstage --create-namespace \
  -f backstage/helm-values.yaml

# 4. 應用額外配置
./kubectl apply -f backstage/app-config-override.yaml

# 5. 設定 Guest 認證
./kubectl set env deployment/backstage -n backstage \
  NODE_ENV=development \
  APP_CONFIG_auth_environment=development \
  APP_CONFIG_auth_providers_guest_dangerouslyAllowOutsideDevelopment=true

# 6. 等待 Backstage 就緒
./kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=backstage \
  -n backstage --timeout=180s
```

### 目錄結構

```
backstage/
├── README.md                    # Backstage 詳細指南
├── helm-values.yaml             # Helm 安裝配置
├── catalog-info.yaml            # 服務目錄定義 (核心檔案)
├── app-config-override.yaml     # 額外配置 ConfigMap
├── postgres-secrets.yaml        # 資料庫認證 (備用)
├── postgres-pvc.yaml            # 持久化儲存 (備用)
├── postgres-deployment.yaml     # PostgreSQL 部署 (備用)
├── backstage-secrets.yaml       # Backstage 認證 (備用)
├── backstage-configmap.yaml     # 應用配置 (備用)
└── backstage-deployment.yaml    # 部署配置 (備用)
```

### Backstage 故障排除

#### 無法登入 (Guest 認證失敗)

```bash
# 確認環境變數設定
./kubectl get deployment backstage -n backstage -o yaml | grep -A5 env

# 重新設定 Guest 認證
./kubectl set env deployment/backstage -n backstage \
  NODE_ENV=development \
  APP_CONFIG_auth_environment=development \
  APP_CONFIG_auth_providers_guest_dangerouslyAllowOutsideDevelopment=true
```

#### Catalog 無法載入

```bash
# 檢查 Backstage 日誌
./kubectl logs -n backstage deployment/backstage --tail=50

# 確認可以讀取 GitHub
curl -s https://raw.githubusercontent.com/ChunPingWang/integration-server/main/backstage/catalog-info.yaml | head -10
```

#### 實體未顯示

```bash
# 檢查 Catalog 位置
TOKEN=$(curl -s -X POST http://localhost:7007/api/auth/guest/refresh \
  -H "Content-Type: application/json" | jq -r '.backstageIdentity.token')

curl -s http://localhost:7007/api/catalog/locations \
  -H "Authorization: Bearer $TOKEN" | jq '.'

# 如果沒有位置，重新註冊
curl -X POST http://localhost:7007/api/catalog/locations \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"url","target":"https://raw.githubusercontent.com/ChunPingWang/integration-server/main/backstage/catalog-info.yaml"}'
```

詳細說明請參考 [backstage/README.md](backstage/README.md)

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
# URL: http://172.18.0.1:3001/org/repo.git  (使用 Docker 網路 IP)
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

### inotify 限制錯誤 (重要)

當 Kind 節點出現 `too many open files` 錯誤時：

```bash
# 檢查當前限制
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances

# 增加限制（需要 sudo）
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

# 永久生效
echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
echo 'fs.inotify.max_user_instances=512' | sudo tee -a /etc/sysctl.conf
```

### Docker Insecure Registry 設定 (重要)

若 CI 建置時出現 `http: server gave HTTP response to HTTPS client` 錯誤：

```bash
# 編輯 Docker daemon 設定
sudo nano /etc/docker/daemon.json

# 加入以下內容
{
  "insecure-registries": ["172.18.0.1:5000", "localhost:5000"]
}

# 重啟 Docker
sudo systemctl restart docker
```

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
| Backstage | https://backstage.io/docs |
| GitOps 原則 | https://opengitops.dev/ |

### 本專案文件

| 文件 | 說明 |
|------|------|
| [tasks-gitea.md](tasks-gitea.md) | 詳細部署任務清單 |
| [gitea-runner/README.md](gitea-runner/README.md) | Runner 設定指南 |
| [argocd/README.md](argocd/README.md) | ArgoCD 使用指南 |
| [backstage/README.md](backstage/README.md) | Backstage 設定指南 |
| [ingress/README.md](ingress/README.md) | 遠端訪問設定指南 |
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
| Backstage | latest | 開發者入口平台 |
| Helm | 3.x+ | Kubernetes 套件管理 |
| Oracle XE | 21.3.0 | 測試資料庫 |

---

## 授權

本專案為內部使用的 CI/CD 環境配置，基於開源工具搭建。

---

**建立日期**：2025-12-14
**最後更新**：2025-12-14
**版本**：v1.3 (增強 Backstage 配置說明)
