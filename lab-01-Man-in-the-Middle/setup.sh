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
  # Pakete an server zwingend via attacker
  ip route add 172.30.0.20/32 via 172.30.0.99 2>/dev/null || true
  echo "    [victim] Route zu server (172.30.0.20) via attacker (172.30.0.99)"
'

# ── attacker ──────────────────────────────────────────────────
echo "==> Konfiguriere attacker..."
docker exec lab01-attacker bash -c '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq tcpdump iproute2 iputils-ping net-tools > /dev/null 2>&1
  # Sicherstellen dass IP-Forwarding aktiv ist (sysctl aus compose könnte nicht greifen)
  echo 1 > /proc/sys/net/ipv4/ip_forward
  FWD=$(cat /proc/sys/net/ipv4/ip_forward)
  if [ "$FWD" = "1" ]; then
    echo "    [attacker] 172.30.0.99 | IP-Forwarding: aktiv (verifiziert)"
  else
    echo "    [FEHLER] IP-Forwarding konnte nicht aktiviert werden!"
    exit 1
  fi
'

# ── server ────────────────────────────────────────────────────
echo "==> Konfiguriere server..."
docker exec lab01-server sh -c '
  # Antworten an victim ebenfalls via attacker – sonst sieht attacker nur eine Richtung
  ip route add 172.30.0.10/32 via 172.30.0.99 2>/dev/null || true
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
  echo "    [server] Route zu victim via attacker | HTTP auf Port 8080"
'

echo ""
echo "============================================================"
echo "  Lab01 bereit!"
echo ""
echo "  Terminal A (victim):   docker exec -it lab01-victim bash"
echo "  Terminal B (attacker): docker exec -it lab01-attacker bash"
echo "  Terminal C (server):   docker exec -it lab01-server sh"
echo ""
echo "  Testen (auf victim):"
echo "    curl http://172.30.0.20:8080/"
echo ""
echo "  Mitlesen (auf attacker):"
echo "    tcpdump -i any -n -A tcp port 8080"
echo ""
echo "  Aufraemen: docker compose down"
echo "============================================================"