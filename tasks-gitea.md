# Integration Server 搭建工作清單 (Gitea 輕量版)

> **環境規格**：Intel i5 12代 / 64GB RAM / 512GB SSD  
> **架構**：Docker + Kind (K8s) + **Gitea** + Gitea Actions + ArgoCD + Local Registry  
> **建立日期**：2024/XX/XX  
> **負責人**：_______________

---

## 架構概覽

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Host Machine (64GB RAM)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────┐    ┌──────────────────────────────────────────────┐ │
│  │     Gitea      │    │              Kind K8s Cluster                │ │
│  │  (Docker)      │    │  ┌────────────────────────────────────────┐  │ │
│  │                │    │  │  Namespaces:                           │  │ │
│  │  - Git Repo    │    │  │  - argocd     (ArgoCD)                 │  │ │
│  │  - Actions CI  │    │  │  - registry   (Docker Registry + UI)   │  │ │
│  │  - Registry    │    │  │  - app-dev    (應用程式)                │  │ │
│  │  (~512MB RAM)  │    │  │  - test       (整合測試 + Oracle)      │  │ │
│  └───────┬────────┘    │  └────────────────────────────────────────┘  │ │
│          │             │                                               │ │
│          │ trigger     │                                               │ │
│          └─────────────┼───────────────────────────────────────────►   │ │
│                        └──────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────┐                                                     │
│  │  Gitea Runner  │  ← act_runner (執行 Gitea Actions)                  │
│  │  (~512MB RAM)  │                                                     │
│  └────────────────┘                                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 資源配置規劃 (輕量版)

| 組件 | 配置記憶體 | 對比 GitLab 版 |
|------|-----------|----------------|
| Host OS | 4 GB | 相同 |
| Docker Engine | 2 GB | 相同 |
| **Gitea** | **0.5 GB** | GitLab 8GB → 省 7.5GB |
| **Gitea Runner** | **0.5 GB** | GitLab Runner 4GB → 省 3.5GB |
| Kind Cluster | 16 GB | 相同 |
| ├─ ArgoCD | 1 GB | |
| ├─ Registry + UI | 1 GB | |
| ├─ 應用程式 | 4 GB | |
| └─ Oracle XE (測試時) | 4 GB | |
| Backstage (可選) | 2.5 GB | |
| 緩衝空間 | **20+ GB** | 原本 10GB |
| **合計** | **~45 GB** | 原本 ~56GB |

> 🎉 **總共省下約 11GB 記憶體**，系統更有餘裕！

---

## 方案比較：GitLab vs Gitea

| 項目 | GitLab CE | Gitea |
|------|-----------|-------|
| 記憶體需求 | 8-12 GB | 0.5-1 GB |
| 啟動時間 | 3-5 分鐘 | 5-10 秒 |
| CI/CD | GitLab CI | Gitea Actions (GitHub Actions 相容) |
| Container Registry | 內建 | 內建 |
| 複雜度 | 高 | 低 |
| 功能完整度 | 企業級 | 足夠小團隊 |
| 學習曲線 | 較陡 | 平緩 (類似 GitHub) |

---

## Phase 0：環境準備與規劃

### 0.1 作業系統準備
- [ ] 確認作業系統版本 (建議 Ubuntu 22.04 LTS 或 Windows 11 + WSL2)
- [ ] 更新系統套件至最新版本
- [ ] 配置系統時區與 NTP 同步

### 0.2 磁碟規劃
- [ ] 規劃磁碟分區配置
  - `/var/lib/docker` - 150GB (Docker images、volumes)
  - `/home` 或其他 - 剩餘空間
- [ ] 配置 Docker storage driver (建議 overlay2)

### 0.3 網路規劃
- [ ] 規劃 IP/Port 配置表

| 服務 | Port | 說明 |
|------|------|------|
| Gitea HTTP | 3000 | Web UI |
| Gitea SSH | 2222 | Git SSH |
| Local Registry | 5000 | Docker Registry |
| Registry UI | 8081 | Registry Web UI |
| ArgoCD | 8443 | ArgoCD Web UI |
| K8s API | 6443 | Kind cluster API |
| Backstage | 7007 | Developer Portal (可選) |

- [ ] 配置 `/etc/hosts` 本地 DNS

```bash
127.0.0.1  gitea.local
127.0.0.1  registry.local
127.0.0.1  argocd.local
127.0.0.1  backstage.local
```

### 0.4 工具安裝
- [ ] 安裝 Docker Engine / Docker Desktop
- [ ] 安裝 Kind CLI
- [ ] 安裝 kubectl
- [ ] 安裝 Helm v3
- [ ] 安裝 Git
- [ ] (可選) 安裝 k9s (K8s TUI 管理工具)

### 0.5 Oracle Image 準備
- [ ] 從 Docker Hub 拉取 Oracle XE image
  ```bash
  docker pull gvenzl/oracle-xe:21-slim
  ```

---

## Phase 1：Kind K8s Cluster 搭建

### 1.1 建立 Kind 配置檔
- [ ] 撰寫 `kind-config.yaml`

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: integration-cluster
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 30000
        hostPort: 30000
        protocol: TCP
      - containerPort: 30001
        hostPort: 30001
        protocol: TCP
  - role: worker
  - role: worker
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.local:5000"]
      endpoint = ["http://registry.local:5000"]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gitea.local:3000"]
      endpoint = ["http://gitea.local:3000"]
```

### 1.2 建立 Cluster
- [ ] 執行 Kind 建立指令
  ```bash
  kind create cluster --config kind-config.yaml
  ```
- [ ] 驗證 cluster 狀態
  ```bash
  kubectl cluster-info
  kubectl get nodes
  ```

### 1.3 安裝 Ingress Controller
- [ ] 部署 NGINX Ingress Controller
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
  ```
- [ ] 等待 Ingress Controller ready
  ```bash
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s
  ```

### 1.4 安裝 Metrics Server (可選)
- [ ] 部署 Metrics Server
  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  ```
- [ ] 修改 deployment 加入 `--kubelet-insecure-tls` 參數

---

## Phase 2：Docker Registry 搭建

### 2.1 建立 Registry Namespace
- [ ] 建立 namespace
  ```bash
  kubectl create namespace registry
  ```

### 2.2 部署 Docker Registry
- [ ] 撰寫 `registry-deployment.yaml`

```yaml
# registry-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-registry
  template:
    metadata:
      labels:
        app: docker-registry
    spec:
      containers:
        - name: registry
          image: registry:2
          ports:
            - containerPort: 5000
          volumeMounts:
            - name: registry-data
              mountPath: /var/lib/registry
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
      volumes:
        - name: registry-data
          persistentVolumeClaim:
            claimName: registry-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: docker-registry
  namespace: registry
spec:
  type: NodePort
  ports:
    - port: 5000
      targetPort: 5000
      nodePort: 30000
  selector:
    app: docker-registry
```

- [ ] 部署 Registry
  ```bash
  kubectl apply -f registry-deployment.yaml
  ```

### 2.3 部署 Registry UI
- [ ] 撰寫 `registry-ui-deployment.yaml`

```yaml
# registry-ui-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-ui
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry-ui
  template:
    metadata:
      labels:
        app: registry-ui
    spec:
      containers:
        - name: registry-ui
          image: joxit/docker-registry-ui:latest
          ports:
            - containerPort: 80
          env:
            - name: REGISTRY_TITLE
              value: "Integration Registry"
            - name: REGISTRY_URL
              value: "http://docker-registry:5000"
            - name: SINGLE_REGISTRY
              value: "true"
            - name: DELETE_IMAGES
              value: "true"
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: registry-ui
  namespace: registry
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30001
  selector:
    app: registry-ui
```

- [ ] 部署 Registry UI
  ```bash
  kubectl apply -f registry-ui-deployment.yaml
  ```

### 2.4 推送 Oracle Image 到本地 Registry
- [ ] Tag Oracle image
  ```bash
  docker tag gvenzl/oracle-xe:21-slim localhost:30000/oracle-xe:21-slim
  ```
- [ ] Push 到本地 Registry
  ```bash
  docker push localhost:30000/oracle-xe:21-slim
  ```
- [ ] 驗證 image 存在
  ```bash
  curl http://localhost:30000/v2/oracle-xe/tags/list
  ```

---

## Phase 3：Gitea 搭建

### 3.1 準備 Gitea 配置
- [ ] 建立 Gitea 資料目錄
  ```bash
  mkdir -p /srv/gitea/{data,config}
  ```

### 3.2 撰寫 Docker Compose 配置
- [ ] 撰寫 `gitea/docker-compose.yaml`

```yaml
# gitea/docker-compose.yaml
version: "3.8"

services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    hostname: gitea.local
    restart: always
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__server__ROOT_URL=http://gitea.local:3000
      - GITEA__server__HTTP_PORT=3000
      - GITEA__server__SSH_PORT=2222
      - GITEA__server__SSH_DOMAIN=gitea.local
      - GITEA__server__LFS_START_SERVER=true
      - GITEA__service__DISABLE_REGISTRATION=false
      - GITEA__actions__ENABLED=true
      # Container Registry 設定
      - GITEA__packages__ENABLED=true
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - /srv/gitea/data:/data
      - /srv/gitea/config:/etc/gitea
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - gitea-network

networks:
  gitea-network:
    driver: bridge
```

### 3.3 啟動 Gitea
- [ ] 啟動 Gitea 容器
  ```bash
  cd gitea
  docker-compose up -d
  ```
- [ ] 等待 Gitea 啟動 (約 5-10 秒)
- [ ] 開啟 http://gitea.local:3000 完成初始設定
  - [ ] 設定管理員帳號
  - [ ] 確認 SQLite 資料庫設定
  - [ ] 確認 SSH Port 為 2222

### 3.4 Gitea 基礎配置
- [ ] 登入 Gitea Web UI (http://gitea.local:3000)
- [ ] 建立 Organization (例如: `integration-team`)
- [ ] 建立 Repository: `my-application`
- [ ] 建立 Repository: `gitops-manifests`
- [ ] 建立 Repository: `backstage-catalog` (如果要整合 Backstage)

### 3.5 配置 Gitea Actions Runner
- [ ] 撰寫 Runner 配置 `gitea-runner/docker-compose.yaml`

```yaml
# gitea-runner/docker-compose.yaml
version: "3.8"

services:
  gitea-runner:
    image: gitea/act_runner:latest
    container_name: gitea-runner
    restart: always
    environment:
      - GITEA_INSTANCE_URL=http://gitea:3000
      - GITEA_RUNNER_REGISTRATION_TOKEN=${RUNNER_TOKEN}
      - GITEA_RUNNER_NAME=docker-runner
      - GITEA_RUNNER_LABELS=ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://ubuntu:22.04
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./runner-data:/data
    networks:
      - gitea_gitea-network
    depends_on:
      - gitea

networks:
  gitea_gitea-network:
    external: true
```

- [ ] 在 Gitea 取得 Runner Token
  - 路徑: Site Administration > Actions > Runners > Create new Runner
  - 或: Repository Settings > Actions > Runners
- [ ] 設定環境變數並啟動 Runner
  ```bash
  cd gitea-runner
  export RUNNER_TOKEN="your-token-here"
  docker-compose up -d
  ```
- [ ] 驗證 Runner 已連線 (Gitea UI 顯示 Online)

### 3.6 測試 Gitea Actions
- [ ] 在測試 Repository 建立 `.gitea/workflows/test.yaml`

```yaml
# .gitea/workflows/test.yaml
name: Test Workflow
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Hello World
        run: echo "Hello from Gitea Actions!"
```

- [ ] Push 並確認 workflow 執行成功

---

## Phase 4：ArgoCD 搭建

### 4.1 建立 ArgoCD Namespace
- [ ] 建立 namespace
  ```bash
  kubectl create namespace argocd
  ```

### 4.2 部署 ArgoCD
- [ ] 使用官方 manifest 部署
  ```bash
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  ```
- [ ] 等待所有 pods ready
  ```bash
  kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
  ```

### 4.3 配置 ArgoCD 存取
- [ ] 建立 NodePort Service 或使用 port-forward
  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8443:443
  ```
- [ ] 取得初始 admin 密碼
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```
- [ ] 登入 ArgoCD UI (https://localhost:8443)
- [ ] 修改 admin 密碼

### 4.4 連接 Gitea Repository
- [ ] 在 Gitea 建立 Access Token
  - 路徑: User Settings > Applications > Generate New Token
  - Scope: `repo`, `read:org`
- [ ] 在 ArgoCD 新增 Repository
  - Settings > Repositories > Connect Repo
  - URL: `http://gitea.local:3000/integration-team/gitops-manifests.git`
  - Username: `your-username`
  - Password: `your-access-token`

### 4.5 建立 ArgoCD Application
- [ ] 撰寫 Application manifest `argocd-app.yaml`

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-application
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitea.local:3000/integration-team/gitops-manifests.git
    targetRevision: HEAD
    path: overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] 部署 Application
  ```bash
  kubectl apply -f argocd-app.yaml
  ```

---

## Phase 5：CI Pipeline 設計與實作 (Gitea Actions)

### 5.1 Pipeline 流程設計

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Gitea Actions Pipeline Flow                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  [Push Code]                                                             │
│       │                                                                  │
│       ▼                                                                  │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐              │
│  │  Build  │───►│  Unit   │───►│  Build  │───►│  Push   │              │
│  │         │    │  Test   │    │  Image  │    │  Image  │              │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘              │
│                                                      │                   │
│                                                      ▼                   │
│                                               ┌─────────────┐           │
│                                               │   Update    │           │
│                                               │  GitOps     │           │
│                                               │   Repo      │           │
│                                               └──────┬──────┘           │
│                                                      │                   │
│                           ArgoCD Auto Sync ◄─────────┘                   │
│                                  │                                       │
│                                  ▼                                       │
│                           ┌─────────────┐                               │
│                           │   Deploy    │                               │
│                           │   to K8s    │                               │
│                           └──────┬──────┘                               │
│                                  │                                       │
│                                  ▼                                       │
│                    ┌─────────────────────────────┐                       │
│                    │ Integration Test (手動觸發)  │                       │
│                    │   workflow_dispatch          │                       │
│                    └─────────────────────────────┘                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 撰寫 Gitea Actions Workflow
- [ ] 建立 `.gitea/workflows/ci.yaml`

```yaml
# .gitea/workflows/ci.yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: registry.local:5000
  IMAGE_NAME: my-application

jobs:
  # ===== Build Stage =====
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Build with Maven
        run: mvn clean compile -DskipTests

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: target/
          retention-days: 1

  # ===== Unit Test Stage =====
  unit-test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Run unit tests
        run: mvn test

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: |
            target/surefire-reports/
            target/site/jacoco/

      - name: Publish Test Report
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: JUnit Tests
          path: target/surefire-reports/TEST-*.xml
          reporter: java-junit

  # ===== Build & Push Docker Image =====
  build-image:
    runs-on: ubuntu-latest
    needs: unit-test
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Build JAR
        run: mvn package -DskipTests

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ===== Update GitOps Repository =====
  update-gitops:
    runs-on: ubuntu-latest
    needs: build-image
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: integration-team/gitops-manifests
          token: ${{ secrets.GITOPS_TOKEN }}
          path: gitops

      - name: Update image tag
        run: |
          cd gitops
          sed -i "s|image:.*${{ env.IMAGE_NAME }}:.*|image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}|g" overlays/dev/deployment.yaml

      - name: Commit and push
        run: |
          cd gitops
          git config user.name "Gitea Actions"
          git config user.email "actions@gitea.local"
          git add .
          git diff --staged --quiet || git commit -m "Update ${{ env.IMAGE_NAME }} to ${{ github.sha }}"
          git push
```

### 5.3 撰寫整合測試 Workflow (手動觸發)
- [ ] 建立 `.gitea/workflows/integration-test.yaml`

```yaml
# .gitea/workflows/integration-test.yaml
name: Integration Test

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging

env:
  REGISTRY: registry.local:5000

jobs:
  integration-test:
    runs-on: ubuntu-latest
    
    services:
      oracle:
        image: registry.local:5000/oracle-xe:21-slim
        env:
          ORACLE_PASSWORD: test123
        ports:
          - 1521:1521
        options: >-
          --health-cmd "echo 'SELECT 1 FROM DUAL;' | sqlplus -s system/test123@localhost:1521/XEPDB1"
          --health-interval 30s
          --health-timeout 10s
          --health-retries 10

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Wait for Oracle to be ready
        run: |
          echo "Waiting for Oracle to be ready..."
          for i in $(seq 1 60); do
            if nc -z localhost 1521; then
              echo "Oracle is ready!"
              break
            fi
            echo "Waiting... ($i/60)"
            sleep 5
          done

      - name: Run database migrations
        run: |
          mvn flyway:migrate \
            -Dflyway.url=jdbc:oracle:thin:@localhost:1521/XEPDB1 \
            -Dflyway.user=system \
            -Dflyway.password=test123

      - name: Run integration tests
        run: mvn verify -Pintegration-test
        env:
          SPRING_DATASOURCE_URL: jdbc:oracle:thin:@localhost:1521/XEPDB1
          SPRING_DATASOURCE_USERNAME: system
          SPRING_DATASOURCE_PASSWORD: test123

      - name: Generate Allure Report
        if: always()
        run: mvn allure:report

      - name: Upload test reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: integration-test-reports
          path: |
            target/allure-report/
            target/failsafe-reports/

      - name: Publish Integration Test Report
        uses: dorny/test-reporter@v1
        if: always()
        with:
          name: Integration Tests
          path: target/failsafe-reports/TEST-*.xml
          reporter: java-junit
```

### 5.4 配置 Secrets
- [ ] 在 Gitea Repository Settings > Actions > Secrets 設定
  - `GITOPS_TOKEN` - 用於更新 GitOps repo 的 Access Token
  - `ORACLE_PASSWORD` - Oracle 測試密碼 (可選)

---

## Phase 6：整合測試環境設計

### 6.1 準備測試資料庫腳本
- [ ] 建立 `db/migration/` 目錄結構

```
db/
├── migration/
│   ├── V1.0__create_schema.sql      # DDL
│   ├── V1.1__create_tables.sql      # DDL
│   └── V1.2__seed_test_data.sql     # DML
└── scripts/
    ├── init-test-data.sh
    └── cleanup.sh
```

### 6.2 撰寫 DDL 腳本範例
- [ ] 建立 `V1.0__create_schema.sql`

```sql
-- V1.0__create_schema.sql
CREATE USER app_user IDENTIFIED BY app_password;
GRANT CONNECT, RESOURCE TO app_user;
ALTER USER app_user QUOTA UNLIMITED ON USERS;
```

### 6.3 撰寫 DML 腳本範例
- [ ] 建立 `V1.2__seed_test_data.sql`

```sql
-- V1.2__seed_test_data.sql
INSERT INTO app_user.customers (id, name, email) VALUES (1, 'Test User 1', 'test1@example.com');
INSERT INTO app_user.customers (id, name, email) VALUES (2, 'Test User 2', 'test2@example.com');
COMMIT;
```

### 6.4 配置 Flyway
- [ ] 在 `pom.xml` 加入 Flyway 依賴
- [ ] 配置 Flyway 指向 migration 目錄

---

## Phase 7：測試報告產出

### 7.1 配置 Allure Report
- [ ] 加入 Allure 依賴到 `pom.xml`

```xml
<dependency>
  <groupId>io.qameta.allure</groupId>
  <artifactId>allure-junit5</artifactId>
  <version>2.24.0</version>
  <scope>test</scope>
</dependency>
```

- [ ] 配置 Maven Allure Plugin

```xml
<plugin>
  <groupId>io.qameta.allure</groupId>
  <artifactId>allure-maven</artifactId>
  <version>2.12.0</version>
</plugin>
```

### 7.2 測試報告內容
- [ ] 單元測試覆蓋率報告 (JaCoCo)
- [ ] 整合測試結果報告 (Allure)
- [ ] 測試執行時間統計
- [ ] 報告自動上傳為 Artifacts

---

## Phase 8：Backstage 整合 (可選)

### 8.1 Backstage 配置調整
- [ ] 修改 `app-config.yaml` 使用 Gitea 整合

```yaml
# app-config.yaml (Gitea 版本)
integrations:
  gitea:
    - host: gitea.local
      baseUrl: http://gitea.local:3000
      username: ${GITEA_USERNAME}
      password: ${GITEA_TOKEN}

catalog:
  locations:
    - type: url
      target: http://gitea.local:3000/integration-team/backstage-catalog/raw/branch/main/all.yaml
```

### 8.2 Backstage Gitea Plugin
- [ ] 安裝 Gitea Plugin (社群維護)
  ```bash
  yarn --cwd packages/app add @backstage-community/plugin-gitea
  ```

---

## Phase 9：整合驗證與優化

### 9.1 端到端流程驗證

#### 測試場景 1：程式碼推送觸發自動部署
- [ ] 修改應用程式程式碼
- [ ] Push 到 Gitea main branch
- [ ] 驗證 Gitea Actions 自動觸發
- [ ] 驗證單元測試執行成功
- [ ] 驗證 Docker Image 推送到本地 Registry
- [ ] 驗證 GitOps Repo 自動更新 image tag
- [ ] 驗證 ArgoCD 偵測變更並自動同步
- [ ] 驗證應用程式成功部署到 K8s

#### 測試場景 2：手動觸發整合測試
- [ ] 在 Gitea Actions 頁面手動觸發 Integration Test (Run workflow)
- [ ] 驗證 Oracle 容器成功啟動
- [ ] 驗證 DDL/DML 腳本執行成功
- [ ] 驗證整合測試執行完成
- [ ] 驗證測試報告產出 (下載 Artifacts)
- [ ] 驗證測試環境清理

### 9.2 效能監控
- [ ] 監控各組件記憶體使用量
  ```bash
  docker stats
  kubectl top pods -A
  ```
- [ ] 驗證總記憶體使用低於 50GB

### 9.3 備份策略
- [ ] 配置 Gitea 資料備份
  ```bash
  docker exec -t gitea /bin/sh -c 'gitea dump -c /etc/gitea/app.ini'
  ```
- [ ] 配置 Registry 資料備份

### 9.4 文件撰寫
- [ ] 撰寫架構文件 (Architecture.md)
- [ ] 撰寫操作手冊 (Runbook.md)
- [ ] 撰寫故障排除指南 (Troubleshooting.md)

---

## 檢查清單 (Checklist)

### 環境健康檢查
```bash
# Docker 狀態
docker ps
docker system df

# Kind Cluster 狀態
kubectl get nodes
kubectl get pods -A

# Gitea 狀態
curl -s http://gitea.local:3000/api/v1/version

# Gitea Runner 狀態
docker logs gitea-runner

# Registry 狀態
curl -s http://localhost:30000/v2/_catalog

# ArgoCD 狀態
kubectl get applications -n argocd
```

### 常見問題排查

| 問題 | 可能原因 | 解決方案 |
|------|----------|----------|
| Gitea Actions 未觸發 | Runner 未連線 | 檢查 Runner Token、網路 |
| Image push 失敗 | Registry 不可達 | 檢查 insecure-registry 配置 |
| ArgoCD 無法同步 | Repository 認證失敗 | 檢查 Access Token |
| Oracle 啟動緩慢 | 記憶體不足 | 增加 container memory |
| Workflow 卡在 services | Oracle health check 失敗 | 增加 health-retries |

---

## 附錄

### A. Gitea vs GitLab CI 語法對照

| 功能 | GitLab CI | Gitea Actions |
|------|-----------|---------------|
| 配置檔 | `.gitlab-ci.yml` | `.gitea/workflows/*.yaml` |
| 變數 | `variables:` | `env:` |
| Stage/Job | `stages:` + `stage:` | `jobs:` |
| 手動觸發 | `when: manual` | `workflow_dispatch` |
| 快取 | `cache:` | `actions/cache@v4` |
| Artifacts | `artifacts:` | `actions/upload-artifact@v4` |
| Services | `services:` | `services:` (相同) |
| 條件執行 | `only:` / `rules:` | `if:` |

### B. 參考文件
- [Gitea 官方文件](https://docs.gitea.io/)
- [Gitea Actions 文件](https://docs.gitea.io/en-us/actions-overview/)
- [Kind 官方文件](https://kind.sigs.k8s.io/)
- [ArgoCD 官方文件](https://argo-cd.readthedocs.io/)
- [Docker Registry 文件](https://docs.docker.com/registry/)

### C. 版本資訊
| 組件 | 建議版本 |
|------|----------|
| Docker | 24.x+ |
| Kind | 0.20+ |
| Kubernetes | 1.28+ |
| **Gitea** | **1.21+** |
| **act_runner** | **0.2.6+** |
| ArgoCD | 2.9+ |
| Oracle XE | 21.3.0 |

---

> **最後更新**：_____________  
> **版本**：v2.0 (Gitea 輕量版)
