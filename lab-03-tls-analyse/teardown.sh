#!/bin/bash
# ============================================================
#  teardown.sh  –  Lab 03: TLS-Analyse
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo -e "\n${BOLD}━━━  Lab 03: TLS-Analyse – Teardown  ━━━${NC}\n"

info "Stoppe und entferne Container..."
docker compose down --remove-orphans 2>/dev/null || true

info "Entferne Netzwerk 'lab03-net'..."
docker network rm lab03-net >/dev/null 2>&1 && \
  success "Netzwerk entfernt." || info "Netzwerk war bereits weg."

info "Bereinige generierte Zertifikate..."
rm -rf configs/server/certs
success "Zertifikate entfernt."

docker network prune -f >/dev/null 2>&1

success "Lab vollständig gestoppt und aufgeräumt."
