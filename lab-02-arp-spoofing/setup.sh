#!/bin/bash
# ============================================================
#  setup.sh  –  Lab 02: ARP Spoofing
#  Modul: Sichere Netzwerke | FOM Hochschule | SS 2026
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[FEHLER]${NC} $*"; exit 1; }
step()    { echo -e "\n${BOLD}━━━  $*  ━━━${NC}"; }

echo -e "\n${BLUE}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   Lab 02: ARP Spoofing  |  FOM Sichere Netze   ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Schritt 1: Aufräumen ─────────────────────────────────────
step "1/3 – Container starten"

# Bridge-Netfilter deaktivieren – sonst filtert der Linux-Kernel
# gefälschte ARP-Replies zwischen Containern heraus (ARP Spoofing schlägt fehl)
info "Deaktiviere Bridge-Netfilter für ARP-Spoofing..."
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-arptables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0 >/dev/null 2>&1 || true
success "Bridge-Netfilter deaktiviert."

info "Räume vorherige Instanz auf..."
for C in lab02-alice lab02-gateway lab02-mallory; do
  docker stop "$C" >/dev/null 2>&1 || true
  docker rm   "$C" >/dev/null 2>&1 || true
done
docker network rm lab02-net >/dev/null 2>&1 || true
success "Aufgeräumt."

# Netzwerk mit freiem /24-Subnetz erstellen
# Probiert verschiedene Subnetze bis eines funktioniert
info "Erstelle Netzwerk mit freiem /24-Subnetz..."
CREATED=false
for OCTET in 200 201 202 203 204 205 210 211 212 220 221 230; do
  SUBNET="10.${OCTET}.${OCTET}.0/24"
  GW="10.${OCTET}.${OCTET}.254"   # Docker-Bridge-IP (nicht für Container)
  if docker network create \
      --driver bridge \
      --subnet "$SUBNET" \
      --gateway "$GW" \
      lab02-net >/dev/null 2>&1; then
    success "Netzwerk lab02-net erstellt: ${SUBNET}"
    # Container-IPs aus dem gewählten Subnetz ableiten
    BASE="10.${OCTET}.${OCTET}"
    IP_GATEWAY="${BASE}.1"
    IP_ALICE="${BASE}.10"
    IP_MALLORY="${BASE}.99"
    CREATED=true
    break
  fi
done

$CREATED || error "Kein freies /24-Subnetz gefunden. Bitte 'docker network prune -f' ausführen."

# Container starten
info "Starte Container..."
docker compose up -d 2>/dev/null || docker-compose up -d

sleep 2
for C in lab02-alice lab02-gateway lab02-mallory; do
  STATUS=$(docker inspect -f '{{.State.Status}}' "$C" 2>/dev/null || echo "fehlt")
  [[ "$STATUS" == "running" ]] \
    && success "Container '$C' läuft." \
    || error "Container '$C' nicht gestartet (Status: $STATUS)."
done

# Tatsächliche IPs von Docker lesen (Zuweisung erfolgt automatisch aus dem /24)
IP_ALICE=$(docker inspect -f \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab02-alice)
IP_GATEWAY=$(docker inspect -f \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab02-gateway)
IP_MALLORY=$(docker inspect -f \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' lab02-mallory)

success "IPs vergeben: alice=${IP_ALICE}  gateway=${IP_GATEWAY}  mallory=${IP_MALLORY}"

# ── Schritt 2: Dienste starten ───────────────────────────────
step "2/3 – Dienste starten"

# HTTP-Server auf gateway
info "Starte HTTP-Server auf gateway..."
docker exec lab02-gateway apk add --no-cache busybox-extras >/dev/null 2>&1
docker exec lab02-gateway sh -c 'mkdir -p /www && printf \
  "<html><head><title>Firmen-Intranet</title></head><body>\
<h1>Firmen-Intranet</h1><p>Benutzername: admin</p>\
<p>Passwort: SuperGeheim123</p></body></html>" > /www/index.html'
docker exec -d lab02-gateway httpd -p 80 -h /www
success "HTTP-Server läuft auf ${IP_GATEWAY}:80."

# Tools auf alice
info "Installiere Tools auf alice..."
docker exec -e DEBIAN_FRONTEND=noninteractive lab02-alice \
  bash -c "apt-get update -qq && apt-get install -y -qq \
    curl net-tools iputils-ping iproute2 tcpdump" >/dev/null 2>&1
success "Tools auf alice bereit."

# arp_accept=1 aktivieren – ohne das verwirft alice unaufgeforderte ARP-Replies
# (Gratuitous ARP) und ARP Spoofing schlägt still fehl
info "Aktiviere arp_accept auf alice..."
docker exec lab02-alice sysctl -w net.ipv4.conf.eth0.arp_accept=1 >/dev/null 2>&1
docker exec lab02-alice sysctl -w net.ipv4.conf.all.arp_accept=1 >/dev/null 2>&1
success "arp_accept=1 gesetzt."

# Traffic-Generator
info "Starte Traffic-Generator auf alice..."
docker exec -d lab02-alice bash -c "
  while true; do
    curl -s http://${IP_GATEWAY}/ -o /dev/null --max-time 3 2>/dev/null || true
    sleep 2
  done"
success "Traffic-Generator läuft (alle 2 Sek.)."

# Lab-Info in alle Container schreiben
LAB_INFO="Lab 02 – Netzwerk\n  alice   ${IP_ALICE}\n  gateway ${IP_GATEWAY}\n  mallory ${IP_MALLORY}\nAnzeigen: cat /etc/lab-info"
for C in lab02-alice lab02-gateway lab02-mallory; do
  docker exec "$C" sh -c "printf '${LAB_INFO}' > /etc/lab-info" 2>/dev/null || true
done

# ── Schritt 3: Tools auf mallory ─────────────────────────────
step "3/3 – Angriffs-Tools installieren (~2 Min)"

info "Installiere bettercap, ettercap, tcpdump..."
docker exec -e DEBIAN_FRONTEND=noninteractive lab02-mallory \
  bash -c "apt-get update -qq && apt-get install -y -qq \
    ettercap-text-only tcpdump net-tools iputils-ping bettercap" \
  >/dev/null 2>&1
success "Tools bereit."

# Angriffsbefehle mit korrekten IPs speichern
cat > .attack-cmds << ACEOF
# ============================================================
#  Lab 02 – Angriffsbefehle (alle in lab02-mallory)
# ============================================================

# ettercap – ARP Spoofing + Traffic-Mitschnitt in einem Befehl
# Terminal 1:
docker exec -it lab02-mallory bash
ettercap -T -i eth0 -M arp:remote /${IP_ALICE}// /${IP_GATEWAY}//

# ARP-Cache auf alice beobachten (Host-Terminal):
watch -n 2 "docker exec lab02-alice arp -n"

# ARP-Pakete mitschneiden (zweites Terminal auf alice):
docker exec lab02-alice tcpdump -i eth0 -n arp
ACEOF

# ── Zusammenfassung ──────────────────────────────────────────
echo -e "\n${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║              Lab ist bereit!                    ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Netzwerk-Übersicht:${NC}"
echo -e "  alice   (Opfer)      →  ${BLUE}${IP_ALICE}${NC}"
echo -e "  gateway (Webserver)  →  ${BLUE}${IP_GATEWAY}${NC}  (HTTP Port 80)"
echo -e "  mallory (Angreifer)  →  ${BLUE}${IP_MALLORY}${NC}"

echo ""
echo -e "${BOLD}Verbindung testen:${NC}"
echo -e "  ${BLUE}docker exec lab02-alice curl -s http://${IP_GATEWAY}/${NC}"
echo -e "  ${BLUE}docker exec lab02-alice arp -n${NC}"

echo ""
echo -e "${BOLD}Angriff starten (ettercap):${NC}"
echo -e "  ${BLUE}docker exec -it lab02-mallory bash${NC}"
echo -e "  ${BLUE}ettercap -T -i eth0 -M arp:remote /${IP_ALICE}// /${IP_GATEWAY}//${NC}"
echo ""
echo -e "  ${BOLD}ARP-Cache auf alice beobachten:${NC}"
echo -e "  ${BLUE}watch -n 2 \"docker exec lab02-alice arp -n\"${NC}"
echo ""
echo -e "  ${BOLD}ARP-Pakete mitschneiden (zweites Terminal):${NC}"
echo -e "  ${BLUE}docker exec lab02-alice tcpdump -i eth0 -n arp${NC}"
echo ""
echo -e "  Alle Befehle auch in: ${YELLOW}.attack-cmds${NC}"
echo ""
echo -e "Beenden: ${YELLOW}./teardown.sh${NC}"
echo ""