#!/usr/bin/env bash
#
# hermes-evolution-log installer
# Idempotent — safe to run multiple times.
#
# Environment variables:
#   HERMES_DIR   — Path to hermes skills directory (default: ~/.hermes/skills)
#   INSTALL_DIR  — Installation target (default: /opt/hermes-log)
#   PORT         — Host port to expose (default: 9912)

set -euo pipefail

HERMES_DIR="${HERMES_DIR:-$HOME/.hermes/skills}"
INSTALL_DIR="${INSTALL_DIR:-/opt/hermes-log}"
PORT="${PORT:-9912}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== hermes-evolution-log installer ==="
echo "HERMES_DIR=$HERMES_DIR"
echo "INSTALL_DIR=$INSTALL_DIR"
echo "PORT=$PORT"
echo

# ── 1. Check prerequisites ────────────────────────────────────────────
echo "[1/5] Checking prerequisites..."

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 not found. Please install Python 3." >&2
  exit 1
fi
echo "  python3: $(python3 --version)"

if ! command -v pip3 &>/dev/null && ! command -v python3 -m pip &>/dev/null; then
  echo "ERROR: pip3 not found. Please install pip." >&2
  exit 1
fi
echo "  pip: OK"

if ! command -v docker &>/dev/null; then
  echo "ERROR: docker not found. Please install Docker." >&2
  exit 1
fi
echo "  docker: $(docker --version)"

if ! command -v docker compose &>/dev/null && ! command -v docker-compose &>/dev/null; then
  echo "ERROR: docker compose not found." >&2
  exit 1
fi
echo "  docker compose: OK"

# ── 2. Install Python dependencies ────────────────────────────────────
echo
echo "[2/5] Installing Python dependencies..."
pip3 install --user --quiet pyyaml
echo "  pyyaml: installed"

# ── 3. Create install directory and copy files ────────────────────────
echo
echo "[3/5] Setting up $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/scripts"

# Copy project files (skip .git and data snapshots)
rsync -a --delete \
  --exclude='.git' \
  --exclude='data/evolution.json' \
  --exclude='data/snapshots/' \
  "$SCRIPT_DIR/" "$INSTALL_DIR/"

echo "  Files copied to $INSTALL_DIR"

# Ensure data directory exists
mkdir -p "$INSTALL_DIR/data"

# ── 4. Export vars for docker-compose and build ───────────────────────
echo
echo "[4/5] Building Docker image..."
cd "$INSTALL_DIR"
export HERMES_DIR PORT

if docker compose version &>/dev/null 2>&1; then
  docker compose build
else
  docker-compose build
fi
echo "  Build complete"

# ── 5. Start / restart the container ──────────────────────────────────
echo
echo "[5/5] Starting hermes-log on port $PORT..."

if docker compose version &>/dev/null 2>&1; then
  docker compose up -d
else
  docker-compose up -d
fi

echo
echo "=== Done! ==="
echo "hermes-log is running at http://localhost:$PORT"
echo "Data directory: $INSTALL_DIR/data"
