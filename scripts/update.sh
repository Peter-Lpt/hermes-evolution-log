#!/usr/bin/env bash
#
# hermes-evolution-log updater
# Runs the tracker, rebuilds the Docker image, and restarts the container.
#
# Environment variables:
#   HERMES_DIR   — Path to hermes skills directory (default: ~/.hermes/skills)
#   INSTALL_DIR  — Installation directory (default: /opt/hermes-log)
#   PORT         — Host port to expose (default: 9912)

set -euo pipefail

HERMES_DIR="${HERMES_DIR:-$HOME/.hermes/skills}"
INSTALL_DIR="${INSTALL_DIR:-/opt/hermes-log}"
PORT="${PORT:-9912}"

echo "=== hermes-evolution-log updater ==="
echo "HERMES_DIR=$HERMES_DIR"
echo "INSTALL_DIR=$INSTALL_DIR"
echo "PORT=$PORT"
echo

# ── 1. Run tracker ────────────────────────────────────────────────────
echo "[1/3] Running tracker to detect changes..."
cd "$INSTALL_DIR"

if [ -f "$INSTALL_DIR/tracker.py" ]; then
  HERMES_DIR="$HERMES_DIR" python3 "$INSTALL_DIR/tracker.py"
  echo "  Tracker complete"
else
  echo "  WARNING: tracker.py not found, skipping"
fi

# ── 2. Rebuild Docker image ──────────────────────────────────────────
echo
echo "[2/3] Rebuilding Docker image..."
export HERMES_DIR PORT

if docker compose version &>/dev/null 2>&1; then
  docker compose build --no-cache
else
  docker-compose build --no-cache
fi
echo "  Build complete"

# ── 3. Restart container ─────────────────────────────────────────────
echo
echo "[3/3] Restarting container..."
if docker compose version &>/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi

echo
echo "=== Update complete! ==="
echo "hermes-log running at http://localhost:$PORT"
