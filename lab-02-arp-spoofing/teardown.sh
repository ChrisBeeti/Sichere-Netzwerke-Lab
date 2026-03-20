#!/bin/bash
# ============================================================
#  teardown.sh  –  Lab 02: ARP Spoofing
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo -e "\n${BOLD}━━━  Lab 02: ARP Spoofing – Teardown  ━━━${NC}\n"

info "Stoppe und entferne Container..."
for C in lab02-alice lab02-gateway lab02-mallory; do
  docker stop "$C" >/dev/null 2>&1 || true
  docker rm   "$C" >/dev/null 2>&1 || true
done
docker compose down >/dev/null 2>&1 || \
  docker-compose down >/dev/null 2>&1 || true

info "Entferne Netzwerk lab02-net..."
docker network rm lab02-net >/dev/null 2>&1 || true

success "Lab gestoppt und aufgeräumt."
echo ""