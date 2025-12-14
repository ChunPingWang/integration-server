#!/bin/bash
# 測試 Oracle 資料庫連線腳本

ORACLE_HOST=${1:-localhost}
ORACLE_PORT=${2:-1521}
ORACLE_SERVICE=${3:-XEPDB1}
ORACLE_USER=${4:-system}
ORACLE_PASSWORD=${5:-test123}

echo "=== Oracle 資料庫連線測試 ==="
echo "Host: $ORACLE_HOST"
echo "Port: $ORACLE_PORT"
echo "Service: $ORACLE_SERVICE"
echo "User: $ORACLE_USER"
echo ""

# 檢查 Port 是否開啟
echo "檢查 Port $ORACLE_PORT..."
if nc -z $ORACLE_HOST $ORACLE_PORT; then
    echo "✅ Port $ORACLE_PORT 已開啟"
else
    echo "❌ Port $ORACLE_PORT 未開啟"
    exit 1
fi

echo ""
echo "嘗試連接資料庫..."

# 使用 sqlplus 測試連線（需要安裝 Oracle Instant Client）
if command -v sqlplus &> /dev/null; then
    echo "exit" | sqlplus -S $ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_HOST:$ORACLE_PORT/$ORACLE_SERVICE
    if [ $? -eq 0 ]; then
        echo "✅ 資料庫連線成功"
    else
        echo "❌ 資料庫連線失敗"
        exit 1
    fi
else
    echo "⚠️  sqlplus 未安裝，無法測試 SQL 連線"
    echo "但 Port 可達，應該可以連線"
fi

echo ""
echo "=== 測試完成 ==="
