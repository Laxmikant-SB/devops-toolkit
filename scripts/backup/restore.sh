#!/bin/bash
# ── Restore from Backup ────────────────────────
# Usage: ./restore.sh <backup_file> <restore_dir>
set -euo pipefail

BACKUP_FILE="${1:-}"
RESTORE_DIR="${2:-/tmp/restore}"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.tar.gz> [restore_dir]"
    echo ""
    echo "Available backups:"
    ls -lh /tmp/backups/*.tar.gz 2>/dev/null || echo "  No backups found"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

log() { echo "[$(date '+%H:%M:%S')] $1"; }

mkdir -p "$RESTORE_DIR"

log "Restoring from: $BACKUP_FILE"
log "Restoring to:   $RESTORE_DIR"

tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

log "Restore complete!"
log "Files restored to: $RESTORE_DIR"
ls -lh "$RESTORE_DIR"
