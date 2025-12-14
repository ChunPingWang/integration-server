# Ingress 設定指南

本目錄包含 NGINX Ingress Controller 的部署腳本和 Ingress 規則，用於從遠端訪問 CI/CD 服務。

## 快速開始

```bash
# 1. 部署 Ingress Controller
./ingress/deploy-ingress-controller.sh

# 2. 部署 Ingress 規則
./ingress/apply-ingress-rules.sh
```

## 服務訪問

### 本機訪問 (透過 Ingress)

| 服務 | URL |
|------|-----|
| ArgoCD | https://argocd.local:8443 |
| Backstage | http://backstage.local:7080 |
| Registry | http://registry.local:8088 |
| Registry UI | http://registry-ui.local:8088 |
| Gitea | http://gitea.local:3001 |

### 遠端訪問設定

#### 1. 在遠端機器配置 /etc/hosts

```bash
# 將 SERVER_IP 替換為運行 CI/CD 環境的機器 IP
sudo bash -c 'cat >> /etc/hosts << EOF

# CI/CD Integration Server (Remote)
SERVER_IP  argocd.local
SERVER_IP  backstage.local
SERVER_IP  registry.local
SERVER_IP  registry-ui.local
SERVER_IP  gitea.local
EOF'
```

#### 2. 確保防火牆允許以下端口

```bash
# Ubuntu/Debian (使用 ufw)
sudo ufw allow 3001/tcp  # Gitea
sudo ufw allow 7007/tcp  # Backstage (NodePort)
sudo ufw allow 7080/tcp  # Backstage (Ingress HTTP)
sudo ufw allow 8080/tcp  # ArgoCD (Ingress HTTP)
sudo ufw allow 8443/tcp  # ArgoCD (Ingress HTTPS)
sudo ufw allow 8088/tcp  # Registry (Ingress HTTP)
sudo ufw allow 5000/tcp  # Registry (NodePort)

# 或者開放所有需要的端口
sudo ufw allow from <CLIENT_IP> to any
```

## 端口映射說明

### ArgoCD Cluster (kind-argocd-cluster)
| 容器端口 | 主機端口 | 用途 |
|---------|---------|------|
| 80 | 8080 | HTTP Ingress |
| 443 | 8443 | HTTPS Ingress |
| 30443 | 30443 | NodePort |

### App Cluster (kind-app-cluster)
| 容器端口 | 主機端口 | 用途 |
|---------|---------|------|
| 80 | 8088 | HTTP Ingress |
| 443 | 8448 | HTTPS Ingress |
| 30000 | 5000 | Registry |
| 30001 | 8081 | Registry UI |

### Backstage Cluster (kind-backstage-cluster)
| 容器端口 | 主機端口 | 用途 |
|---------|---------|------|
| 80 | 7080 | HTTP Ingress |
| 443 | 7443 | HTTPS Ingress |
| 30007 | 7007 | Backstage NodePort |

## 網路架構

```
遠端客戶端
     │
     ▼
┌─────────────────────────────────────────────────────┐
│                  Server (HOST)                       │
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │               Docker Network                  │  │
│  │                                               │  │
│  │  ┌─────────────┐    ┌─────────────────────┐  │  │
│  │  │    Gitea    │    │  kind-argocd-cluster│  │  │
│  │  │  :3001      │    │  Ingress :8080/8443 │  │  │
│  │  └─────────────┘    │  ArgoCD             │  │  │
│  │                     └─────────────────────┘  │  │
│  │                                               │  │
│  │  ┌─────────────────────┐  ┌───────────────┐  │  │
│  │  │  kind-app-cluster   │  │kind-backstage │  │  │
│  │  │  Ingress :8088/8448 │  │Ingress :7080  │  │  │
│  │  │  Registry :5000     │  │Backstage:7007 │  │  │
│  │  └─────────────────────┘  └───────────────┘  │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## 故障排除

### Ingress Controller 未就緒

```bash
# 檢查 Ingress Controller 狀態
./kubectl config use-context kind-argocd-cluster
./kubectl get pods -n ingress-nginx

# 查看 Ingress Controller 日誌
./kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### 無法從遠端訪問

1. 確認服務正在運行：
   ```bash
   ./kubectl get pods -A | grep -E "(argocd|backstage|registry)"
   ```

2. 確認 Ingress 規則已部署：
   ```bash
   ./kubectl get ingress -A
   ```

3. 測試本機連接：
   ```bash
   curl -k https://localhost:8443  # ArgoCD
   curl http://localhost:7007      # Backstage
   ```

4. 檢查防火牆規則

## 安全建議

1. **生產環境**：使用真正的 TLS 證書，不要使用自簽名證書
2. **網路隔離**：限制可訪問 CI/CD 服務的 IP 範圍
3. **認證**：確保所有服務都啟用了認證
4. **VPN**：考慮使用 VPN 來訪問內部 CI/CD 服務
