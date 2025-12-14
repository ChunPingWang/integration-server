# Gitea Actions Runner 設定指南

## 前置條件

- Gitea 已啟動並完成初始設定
- 已在 Gitea 建立管理員帳號

## 設定步驟

### 步驟 1: 取得 Runner Registration Token

1. 登入 Gitea (http://gitea.local:3000)
2. 前往 **Site Administration** (管理員選單)
3. 點擊左側 **Actions** > **Runners**
4. 點擊 **Create new Runner** 按鈕
5. 複製顯示的 **Registration Token**

### 步驟 2: 配置環境變數

```bash
cd gitea-runner
cp .env.template .env
```

編輯 `.env` 檔案，將 `RUNNER_TOKEN` 替換為步驟 1 取得的 token：

```bash
RUNNER_TOKEN=你的-registration-token-在這裡
```

### 步驟 3: 啟動 Runner

```bash
docker-compose up -d
```

### 步驟 4: 驗證 Runner 狀態

回到 Gitea Web UI 的 Runners 頁面，應該會看到：

- Runner 名稱: `docker-runner`
- 狀態: **Online** (綠色)
- Labels: `ubuntu-latest`, `ubuntu-22.04`

## 測試 Runner

在任何 Gitea repository 中創建測試 workflow：

```bash
mkdir -p .gitea/workflows
cat > .gitea/workflows/test.yaml << 'EOF'
name: Test Workflow
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Hello World
        run: echo "Hello from Gitea Actions!"
EOF

git add .gitea/workflows/test.yaml
git commit -m "Add test workflow"
git push
```

前往 Repository > Actions 頁面查看 workflow 執行結果。

## 故障排除

### Runner 顯示 Offline

檢查 Runner 日誌：
```bash
docker logs gitea-runner
```

常見問題：
- Token 錯誤：重新產生 token 並更新 `.env`
- 網路問題：確認 Runner 容器能連接到 Gitea 容器
- Docker socket 權限：確認 `/var/run/docker.sock` 可訪問

### 重新註冊 Runner

```bash
docker-compose down
rm -rf runner-data/*
# 取得新的 Registration Token
# 更新 .env 中的 RUNNER_TOKEN
docker-compose up -d
```

## Runner 標籤說明

配置的 Runner Labels：
- `ubuntu-latest`: 使用 `node:20-bookworm` Docker image
- `ubuntu-22.04`: 使用 `ubuntu:22.04` Docker image

可在 workflow 中指定：
```yaml
jobs:
  build:
    runs-on: ubuntu-latest  # 或 ubuntu-22.04
```

## 進階配置

若需要自訂 labels 或增加 runners，編輯 `docker-compose.yaml`：

```yaml
environment:
  - GITEA_RUNNER_LABELS=my-label:docker://my-image:tag
```

## 相關連結

- [Gitea Actions 官方文件](https://docs.gitea.io/en-us/actions-overview/)
- [act_runner GitHub](https://gitea.com/gitea/act_runner)
