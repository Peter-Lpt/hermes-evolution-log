#!/usr/bin/env bash
#
# Setup cron job for Hermes Evolution Log
# This script helps users set up the required scheduled task
#

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/hermes-evolution-log}"
FREQUENCY="${1:-daily}"  # daily or hourly

echo "=== Hermes Evolution Log - Cron Setup ==="
echo

# Check if crontab is available
if ! command -v crontab &>/dev/null; then
    echo "ERROR: crontab not found. Please install cron." >&2
    exit 1
fi

# Determine cron schedule
case "$FREQUENCY" in
    daily)
        SCHEDULE="0 2 * * *"
        DESC="daily at 2:00 AM"
        ;;
    hourly)
        SCHEDULE="*/30 * * * *"
        DESC="every 30 minutes"
        ;;
    *)
        echo "Usage: $0 [daily|hourly]" >&2
        echo "  daily  - Run once per day at 2:00 AM (default)"
        echo "  hourly - Run every 30 minutes"
        exit 1
        ;;
esac

# Cron job command
CRON_CMD="$SCHEDULE cd $INSTALL_DIR && python3 src/tracker.py --output $INSTALL_DIR/data/evolution.json --snapshot $INSTALL_DIR/data/snapshots/state.json >> $INSTALL_DIR/data/cron.log 2>&1"

echo "This will add a cron job to run tracker $DESC"
echo "Command: $CRON_CMD"
echo

# Check if already exists
if crontab -l 2>/dev/null | grep -q "$INSTALL_DIR"; then
    echo "⚠️  Warning: A cron job for this directory already exists:"
    crontab -l 2>/dev/null | grep "$INSTALL_DIR"
    echo
    read -p "Do you want to replace it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    # Remove existing entry
    crontab -l 2>/dev/null | grep -v "$INSTALL_DIR" | crontab -
fi

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

echo "✅ Cron job added successfully!"
echo
echo "Current crontab:"
crontab -l | grep -v "^#" | grep -v "^$" || echo "  (empty)"
echo
echo "To verify, run: crontab -l"
echo "To remove, run: crontab -e"
echo
echo "You can test manually with:"
echo "  cd $INSTALL_DIR && python3 src/tracker.py"
