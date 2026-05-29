#!/bin/bash
# ── Server Backup Script ───────────────────────
# Creates timestamped compressed backups
# Usage: ./backup.sh <source_dir> [dest_dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config/settings.cfg"

# ── Args ───────────────────────────────────────
SOURCE="${1:-$HOME}"
DEST="${2:-$BACKUP_DIR}"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
HOSTNAME=$(hostname)
BACKUP_NAME="${HOSTNAME}_backup_${TIMESTAMP}.tar.gz"

# ── Setup ──────────────────────────────────────
mkdir -p "$DEST"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# ── Pre-checks ─────────────────────────────────
log "Starting backup..."
log "Source:      $SOURCE"
log "Destination: $DEST"
log "Backup file: $BACKUP_NAME"

if [ ! -d "$SOURCE" ]; then
    echo "ERROR: Source directory not found: $SOURCE"
    exit 1
fi

AVAIL=$(df -BM "$DEST" | tail -1 | awk '{print $4}' | tr -d 'M')
SOURCE_SIZE=$(du -sm "$SOURCE" 2>/dev/null | awk '{print $1}')

if [ "$AVAIL" -lt "$SOURCE_SIZE" ]; then
    echo "ERROR: Not enough space. Need ${SOURCE_SIZE}MB, have ${AVAIL}MB"
    exit 1
fi

# ── Backup ─────────────────────────────────────
log "Compressing..."
tar -czf "$DEST/$BACKUP_NAME" \
    --exclude='*.log' \
    --exclude='node_modules' \
    --exclude='.git' \
    "$SOURCE" 2>/dev/null

SIZE=$(du -sh "$DEST/$BACKUP_NAME" | awk '{print $1}')
log "Done! Backup size: $SIZE"

# ── Rotate old backups ─────────────────────────
COUNT=$(ls -1 "$DEST"/*.tar.gz 2>/dev/null | wc -l)
if [ "$COUNT" -gt "$KEEP_BACKUPS" ]; then
    log "Rotating old backups (keeping $KEEP_BACKUPS)..."
    ls -1t "$DEST"/*.tar.gz | tail -n +"$((KEEP_BACKUPS + 1))" | xargs rm -f
    log "Old backups removed"
fi

log "Backup complete: $DEST/$BACKUP_NAME"
echo "$DEST/$BACKUP_NAME"
