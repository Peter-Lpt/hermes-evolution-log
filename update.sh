#!/bin/bash
# Hermes Agent 进化日志更新脚本
# 单目录工作流：所有文件在 /opt/hermes-evolution-log/ 中
#
# 流程：运行追踪器 → 构建 Docker → 重启容器

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧬 Hermes 进化日志更新..."
echo ""

# ── 1. 运行追踪器，检测变化 ──
echo "📡 检测进化变化..."
python3 src/tracker.py \
  --output "$SCRIPT_DIR/data/evolution.json" \
  --snapshot "$SCRIPT_DIR/data/snapshots/state.json"
echo ""

# ── 2. 重新构建 Docker 镜像 ──
echo "🐳 重新构建 Docker 镜像..."
docker build --no-cache -t hermes-log . 2>&1 | tail -1
echo ""

# ── 3. 重启容器 ──
echo "🔄 重启服务..."
docker rm -f hermes-log 2>/dev/null
docker run -d --name hermes-log --restart always -p 9912:80 \
  -v "$SCRIPT_DIR/data:/usr/share/nginx/html/data" \
  hermes-log >/dev/null
echo ""

# ── 4. 验证 ──
sleep 1
if curl -sf http://localhost:9912/ >/dev/null 2>&1; then
    echo "✅ 更新完成！访问 http://$(hostname -I | awk '{print $1}'):9912"
else
    echo "❌ 服务启动失败，请检查日志：docker logs hermes-log"
    exit 1
fi
