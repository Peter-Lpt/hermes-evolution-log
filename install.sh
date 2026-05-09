#!/usr/bin/env bash
#
# hermes-evolution-log installer
# Idempotent — safe to run multiple times.
#
# 单目录工作流：源文件、构建配置、运行时数据都在同一个目录。
#
# Environment variables:
#   HERMES_DIR   — Path to hermes skills directory (default: ~/.hermes)
#   PORT         — Host port to expose (default: 9912)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

HERMES_DIR="${HERMES_DIR:-$HOME/.hermes}"
PORT="${PORT:-9912}"

echo "=== hermes-evolution-log installer ==="
echo "DIR=$SCRIPT_DIR"
echo "HERMES_DIR=$HERMES_DIR"
echo "PORT=$PORT"
echo

# ── 1. Check prerequisites ────────────────────────────────────────────
echo "[1/5] Checking prerequisites..."

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found. Please install Python 3." >&2
  exit 1
fi
echo "  python3: $(python3 --version)"

if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
  echo "ERROR: pip3 not found. Please install pip." >&2
  exit 1
fi
echo "  pip: OK"

if ! command -v docker &>/dev/null; then
  echo "ERROR: docker not found. Please install Docker." >&2
  exit 1
fi
echo "  docker: $(docker --version)"

# ── 2. Install Python dependencies ────────────────────────────────────
echo
echo "[2/5] Installing Python dependencies..."
pip3 install --user --quiet pyyaml
echo "  pyyaml: installed"

# ── 3. Generate config files from .example templates ──────────────────
echo
echo "[3/5] Generating config files from templates..."

for tpl in Dockerfile docker-compose.yml .env; do
  example="${tpl}.example"
  if [ -f "$example" ] && [ ! -f "$tpl" ]; then
    cp "$example" "$tpl"
    echo "  $tpl ← copied from $example"
  elif [ -f "$tpl" ]; then
    echo "  $tpl — already exists, skipped"
  fi
done

# Ensure data directory exists
mkdir -p "$SCRIPT_DIR/data"

# ── 4. Build Docker image ─────────────────────────────────────────────
echo
echo "[4/5] Building Docker image..."

if [ ! -f "Dockerfile" ]; then
  echo "ERROR: Dockerfile not found. Copy from Dockerfile.example first." >&2
  exit 1
fi

export HERMES_DIR PORT
docker build -t hermes-log .
echo "  Build complete"

# ── 5. Start / restart the container ──────────────────────────────────
echo
echo "[5/5] Starting hermes-log on port $PORT..."

docker rm -f hermes-log 2>/dev/null || true
docker run -d \
  --name hermes-log \
  --restart always \
  -p "$PORT:80" \
  -v "$SCRIPT_DIR/data:/usr/share/nginx/html/data" \
  hermes-log >/dev/null

echo
echo "=== Done! ==="
echo "hermes-log is running at http://localhost:$PORT"
echo "Data directory: $SCRIPT_DIR/data"
echo
echo "⚠️  IMPORTANT: Set up scheduled task to keep data updated!"
echo
echo "Without a cron job, evolution data will NOT update automatically."
echo "Add to crontab (crontab -e):"
echo
echo "  # Daily at 2:00 AM"
echo "  0 2 * * * cd $SCRIPT_DIR && python3 src/tracker.py --output $SCRIPT_DIR/data/evolution.json --snapshot $SCRIPT_DIR/data/snapshots/state.json"
echo
echo "Or use Hermes Agent cronjob instead."
