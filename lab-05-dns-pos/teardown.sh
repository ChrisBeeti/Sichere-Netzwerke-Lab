#!/usr/bin/env bash
# =============================================================================
#  teardown.sh  –  Lab 05  vollstaendig entfernen
# =============================================================================
set -uo pipefail

echo "==> Stoppe Container und entferne Volumes"
docker compose down -v

echo "==> Entferne Netzwerk lab05-net"
docker network rm lab05-net 2>/dev/null || true

rm -f .attack-cmds
echo "Lab 05 entfernt."
