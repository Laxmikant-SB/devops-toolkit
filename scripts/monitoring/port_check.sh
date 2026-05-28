#!/bin/bash
# ── Port Availability Checker ──────────────────
# Checks if required ports are open and listening
set -euo pipefail

REQUIRED_PORTS=(22 80 443 3306 27017)
ISSUES=0

echo "── Port Check — $(date '+%Y-%m-%d %H:%M:%S') ──"
echo ""

for PORT in "${REQUIRED_PORTS[@]}"; do
    if ss -tlnp | grep -q ":${PORT} "; then
        PID=$(ss -tlnp | grep ":${PORT} " | \
              grep -oP 'pid=\K[0-9]+' | head -1)
        PROC=$(ps -p "$PID" -o comm= 2>/dev/null || echo "unknown")
        echo "  [OPEN]   Port $PORT — $PROC (PID: $PID)"
    else
        echo "  [CLOSED] Port $PORT — nothing listening"
        ISSUES=$((ISSUES+1))
    fi
done

echo ""
echo "Result: $ISSUES port(s) not listening"
exit "$ISSUES"
