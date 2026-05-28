#!/bin/bash
# ── Server Health Check ────────────────────────
# Checks CPU, memory, disk and running services
# Usage: ./health_check.sh [--silent] [--report]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../../config/settings.cfg"
source "$CONFIG"

# ── Colors ─────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SILENT=false
ISSUES=0

[[ "${1:-}" == "--silent" ]] && SILENT=true

log()  { $SILENT || echo -e "$1"; }
ok()   { log "${GREEN}[OK]${NC}      $1"; }
warn() { log "${YELLOW}[WARN]${NC}    $1"; ISSUES=$((ISSUES+1)); }
fail() { log "${RED}[CRITICAL]${NC} $1"; ISSUES=$((ISSUES+1)); }
info() { log "[INFO]     $1"; }

# ── Checks ─────────────────────────────────────
check_disk() {
    log "\n── Disk Usage ──────────────────────────────"
    while read -r LINE; do
        USAGE=$(echo "$LINE" | awk '{print $5}' | tr -d '%')
        MOUNT=$(echo "$LINE" | awk '{print $6}')
        FS=$(echo "$LINE" | awk '{print $1}')
        [[ "$FS" == tmpfs ]] || [[ "$FS" == none ]] && continue
        if   [ "$USAGE" -ge "$DISK_CRITICAL" ]; then fail "Disk $MOUNT at ${USAGE}%"
        elif [ "$USAGE" -ge "$DISK_WARNING" ];  then warn "Disk $MOUNT at ${USAGE}%"
        else ok "Disk $MOUNT at ${USAGE}%"
        fi
    done < <(df -h | tail -n +2)
}

check_memory() {
    log "\n── Memory ──────────────────────────────────"
    local USAGE
    USAGE=$(free | awk '/Mem/{printf "%.0f", $3/$2*100}')
    local USED TOTAL
    USED=$(free -h | awk '/Mem/{print $3}')
    TOTAL=$(free -h | awk '/Mem/{print $2}')
    if   [ "$USAGE" -ge "$MEM_CRITICAL" ]; then fail "Memory at ${USAGE}% (${USED}/${TOTAL})"
    elif [ "$USAGE" -ge "$MEM_WARNING" ];  then warn "Memory at ${USAGE}% (${USED}/${TOTAL})"
    else ok "Memory at ${USAGE}% (${USED}/${TOTAL})"
    fi
}

check_cpu() {
    log "\n── CPU ─────────────────────────────────────"
    local LOAD
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    local CORES
    CORES=$(nproc)
    local PCT
    PCT=$(echo "$LOAD $CORES" | awk '{printf "%.0f", ($1/$2)*100}')
    if   [ "$PCT" -ge "$CPU_CRITICAL" ]; then fail "CPU load ${LOAD} (${PCT}% of ${CORES} cores)"
    elif [ "$PCT" -ge "$CPU_WARNING" ];  then warn "CPU load ${LOAD} (${PCT}% of ${CORES} cores)"
    else ok "CPU load ${LOAD} (${PCT}% of ${CORES} cores)"
    fi
}

check_services() {
    log "\n── Services ────────────────────────────────"
    local SERVICES=("ssh" "cron")
    for SVC in "${SERVICES[@]}"; do
        if pgrep -x "$SVC" > /dev/null 2>&1 || \
           pgrep -f "$SVC" > /dev/null 2>&1; then
            ok "Service $SVC is running"
        else
            warn "Service $SVC is NOT running"
        fi
    done
}

# ── Main ────────────────────────────────────────
main() {
    log "╔══════════════════════════════════════════╗"
    log "║  Server Health Check — $(date '+%Y-%m-%d %H:%M')  ║"
    log "╚══════════════════════════════════════════╝"
    info "Host: $(hostname) | User: $(whoami) | Uptime: $(uptime -p)"

    check_disk
    check_memory
    check_cpu
    check_services

    log "\n══════════════════════════════════════════"
    if [ "$ISSUES" -eq 0 ]; then
        log "${GREEN}All checks passed. System healthy.${NC}"
    else
        log "${RED}${ISSUES} issue(s) found. Investigate immediately.${NC}"
    fi
    log "══════════════════════════════════════════\n"
    return "$ISSUES"
}

main
