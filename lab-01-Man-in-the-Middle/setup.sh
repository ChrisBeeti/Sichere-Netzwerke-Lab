#!/bin/bash
# =============================================================
# lab01 – Setup-Skript
# Aufruf: bash setup.sh
# Voraussetzung: docker compose up -d wurde bereits ausgefuehrt
# =============================================================

set -e

check_container() {
  if ! docker ps --format '{{.Names}}' | grep -q "^$1$"; then
    echo "[FEHLER] Container '$1' laeuft nicht. Bitte zuerst: docker compose up -d"
    exit 1
  fi
}

echo "==> Pruefe Container..."
check_container lab01-victim
check_container lab01-attacker
check_container lab01-server
echo "    Alle Container laufen."

# ── victim ────────────────────────────────────────────────────
echo ""
echo "==> Konfiguriere victim..."
docker exec lab01-victim bash -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq curl iputils-ping iproute2 net-tools traceroute > /dev/null 2>&1
  # Route zum Server zwingend ueber attacker leiten
  ip route del 172.30.0.20/32 2>/dev/null || true
  ip route add 172.30.0.20 via 172.30.0.99
  echo "    [victim] 172.30.0.10 | Route zu server via attacker (172.30.0.99)"
'

# ── attacker ──────────────────────────────────────────────────
echo "==> Konfiguriere attacker..."
docker exec lab01-attacker bash -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq tcpdump iproute2 iputils-ping net-tools > /dev/null 2>&1
  echo "    [attacker] 172.30.0.99 | IP-Forwarding: aktiv"
'

# ── server ────────────────────────────────────────────────────
echo "==> Konfiguriere server..."
docker exec lab01-server sh -c '
  mkdir -p /var/www
  cat > /var/www/index.html << HTMLEOF
Internes Mitarbeiterportal
==========================
Status:    Anmeldung erfolgreich
Benutzer:  muster
Passwort:  Sommer2026!
Abteilung: IT-Infrastruktur
HTMLEOF
  cd /var/www && python3 -m http.server 8080 > /dev/null 2>&1 &
  echo "    [server] HTTP-Server laeuft auf 172.30.0.20:8080"
'

echo ""
echo "============================================================"
echo "  Lab01 bereit!"
echo ""
echo "  Terminal A (victim):   docker exec -it lab01-victim bash"
echo "  Terminal B (attacker): docker exec -it lab01-attacker bash"
echo "  Terminal C (server):   docker exec -it lab01-server sh"
echo ""
echo "  Testen:"
echo "    victim:   curl http://172.30.0.20:8080/"
echo "    attacker: tcpdump -i any -n -A tcp port 8080"
echo ""
echo "  Aufraemen: docker compose down"
echo "============================================================"