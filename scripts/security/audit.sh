#!/bin/bash
# ── Security Audit Script ──────────────────────
# Checks common security misconfigurations
# Usage: ./audit.sh
set -euo pipefail

PASS=0
WARN=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }

echo "╔══════════════════════════════════════════╗"
echo "║        Security Audit Report             ║"
echo "║        $(date '+%Y-%m-%d %H:%M:%S')          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

echo "── File Permissions ────────────────────────"
# Check SSH private key permissions
if [ -f ~/.ssh/id_ed25519 ]; then
    PERMS=$(stat -c "%a" ~/.ssh/id_ed25519)
    if [ "$PERMS" = "600" ]; then
        pass "SSH private key permissions: $PERMS"
    else
        fail "SSH private key permissions: $PERMS (should be 600)"
    fi
fi

# Check .ssh directory permissions
if [ -d ~/.ssh ]; then
    PERMS=$(stat -c "%a" ~/.ssh)
    if [ "$PERMS" = "700" ]; then
        pass "SSH directory permissions: $PERMS"
    else
        warn "SSH directory permissions: $PERMS (should be 700)"
    fi
fi

# Check for world-writable files in home
echo ""
echo "── World-Writable Files ────────────────────"
WW_FILES=$(find "$HOME" -maxdepth 3 -perm -002 -type f 2>/dev/null | wc -l)
if [ "$WW_FILES" -eq 0 ]; then
    pass "No world-writable files found in home"
else
    warn "Found $WW_FILES world-writable file(s) in home"
    find "$HOME" -maxdepth 3 -perm -002 -type f 2>/dev/null | head -5
fi

echo ""
echo "── Password Policy ─────────────────────────"
# Check if password aging is configured
if chage -l "$USER" 2>/dev/null | grep -q "Maximum number of days"; then
    MAX_DAYS=$(chage -l "$USER" 2>/dev/null | grep "Maximum" | awk -F: '{print $2}' | tr -d ' ')
    if [ "$MAX_DAYS" = "99999" ] || [ "$MAX_DAYS" = "-1" ]; then
        warn "Password never expires for user: $USER"
    else
        pass "Password expiry set to $MAX_DAYS days"
    fi
fi

echo ""
echo "── Open Ports ──────────────────────────────"
OPEN=$(ss -tlnp | grep LISTEN | wc -l)
if [ "$OPEN" -le 5 ]; then
    pass "Open ports: $OPEN (acceptable)"
else
    warn "Open ports: $OPEN (review if all are needed)"
fi
ss -tlnp | grep LISTEN | awk '{print "  → " $4}'

echo ""
echo "── Sudo Access ─────────────────────────────"
if groups "$USER" | grep -qw sudo; then
    warn "User $USER has sudo access — ensure this is intentional"
else
    pass "User $USER does not have unrestricted sudo"
fi

echo ""
echo "══════════════════════════════════════════"
echo -e "  ${GREEN}PASS: $PASS${NC}  |  ${YELLOW}WARN: $WARN${NC}  |  ${RED}FAIL: $FAIL${NC}"
echo "══════════════════════════════════════════"
echo ""
