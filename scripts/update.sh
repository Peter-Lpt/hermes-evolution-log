#!/usr/bin/env bash
#
# hermes-evolution-log updater
# 单目录工作流：运行追踪器 → 构建 Docker → 重启容器
#
# Environment variables:
#   HERMES_DIR — Path to hermes home directory (default: ~/.hermes)
#   PORT       — Host port to expose (default: 9912)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

HERMES_DIR="${HERMES_DIR:-$HOME/.hermes}"
PORT="${PORT:-9912}"

echo "=== hermes-evolution-log updater ==="
echo "DIR=$SCRIPT_DIR"
echo

# ── 1. Run tracker ────────────────────────────────────────────────────
echo "[1/3] Running tracker to detect changes..."
if [ -f "$SCRIPT_DIR/src/tracker.py" ]; then
  python3 "$SCRIPT_DIR/src/tracker.py" \
    --output "$SCRIPT_DIR/data/evolution.json" \
    --snapshot "$SCRIPT_DIR/data/snapshots/state.json"
  echo "  Tracker complete"
else
  echo "  WARNING: src/tracker.py not found, skipping"
fi

# ── 2. Rebuild Docker image ──────────────────────────────────────────
echo
echo "[2/3] Rebuilding Docker image..."
export HERMES_DIR PORT
docker build --no-cache -t hermes-log .
echo "  Build complete"

# ── 3. Restart container ─────────────────────────────────────────────
echo
echo "[3/3] Restarting container..."
docker rm -f hermes-log 2>/dev/null || true
docker run -d \
  --name hermes-log \
  --restart always \
  -p "$PORT:80" \
  -v "$SCRIPT_DIR/data:/usr/share/nginx/html/data" \
  hermes-log >/dev/null

echo
echo "=== Update complete! ==="
echo "hermes-log running at http://localhost:$PORT"
