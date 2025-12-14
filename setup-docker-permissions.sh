#!/bin/bash
# Docker 權限設置腳本

echo "=== Docker 權限設置 ==="
echo ""
echo "步驟 1: 將當前使用者加入 docker group"
sudo usermod -aG docker $USER

echo ""
echo "步驟 2: 啟動 Docker 服務"
sudo systemctl start docker
sudo systemctl enable docker

echo ""
echo "步驟 3: 驗證 Docker 狀態"
sudo systemctl status docker --no-pager

echo ""
echo "✅ 設置完成！"
echo ""
echo "⚠️  重要：請執行以下命令之一來使 docker group 生效："
echo "   方法 1: newgrp docker  (在當前 shell 中生效)"
echo "   方法 2: 登出並重新登入系統"
echo ""
echo "然後執行: ./create-clusters.sh"
