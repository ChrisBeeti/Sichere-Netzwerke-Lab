#!/usr/bin/env bash
# =============================================================================
#  switch-attacker.sh  –  Wechselt den Angreifer-Container zwischen
#                         Szenario A (ip_forward=0) und B/C (ip_forward=1).
#
#  Hintergrund: Unter Docker Desktop/WSL2 ist /proc/sys im Container
#  read-only – ip_forward laesst sich nicht zur Laufzeit aendern.
#  Der Wert muss beim Container-Start per sysctls gesetzt sein.
#  Dieses Skript stoppt den alten Container, startet den neuen (gleiche IP,
#  gleiche Tools), reinstalliert dsniff falls noetig.
#
#  Verwendung:
#    ./switch-attacker.sh a      # Szenario A  (ip_forward=0)
#    ./switch-attacker.sh b      # Szenario B/C (ip_forward=1)
# =============================================================================
set -euo pipefail

MODE="${1:-}"
if [[ "$MODE" != "a" && "$MODE" != "b" ]]; then
  echo "Verwendung: $0 a|b"
  echo "  a = Szenario A  (ip_forward=0, dnsspoof antwortet direkt)"
  echo "  b = Szenario B/C (ip_forward=1, Pakete werden weitergeleitet)"
  exit 1
fi

echo "==> Stoppe laufenden Attacker-Container (falls aktiv) ..."
docker stop lab05-attacker     2>/dev/null || true
docker stop lab05-attacker-fwd 2>/dev/null || true
docker rm   lab05-attacker     2>/dev/null || true
docker rm   lab05-attacker-fwd 2>/dev/null || true

if [[ "$MODE" == "a" ]]; then
  echo "==> Starte Attacker fuer Szenario A (ip_forward=0) ..."
  docker compose up -d attacker
  CONTAINER=lab05-attacker
else
  echo "==> Starte Attacker fuer Szenario B/C (ip_forward=1) ..."
  COMPOSE_PROFILES=fwd docker compose up -d attacker-fwd
  CONTAINER=lab05-attacker-fwd
  # Container heisst intern lab05-attacker-fwd, aber alle Befehle im Guide
  # nutzen lab05-attacker -> Alias via Docker rename
  docker rename lab05-attacker-fwd lab05-attacker 2>/dev/null || true
  CONTAINER=lab05-attacker
fi

echo "==> Installiere dsniff (falls noch nicht im Image) ..."
docker exec "$CONTAINER" bash -c \
  "command -v arpspoof >/dev/null 2>&1 || (apt-get update -qq && \
   DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
   dsniff iproute2 tcpdump dnsutils net-tools >/dev/null 2>&1)" || \
  echo "   ! Hinweis: dsniff-Installation pruefen (Internetzugang?)"

FWD=$(docker exec "$CONTAINER" cat /proc/sys/net/ipv4/ip_forward)
echo
echo "============================================================"
echo " Attacker bereit fuer Szenario $(echo "$MODE" | tr a-z A-Z)"
echo " Container: $CONTAINER"
echo " ip_forward = $FWD  (erwartet: $([ "$MODE" = "a" ] && echo 0 || echo 1))"
echo "============================================================"
