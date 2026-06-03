#!/bin/bash
# ============================================================
#  lab-02-arp-spoofing.sh  –  Lab 02: ARP Spoofing
#  Modul: Sichere Netzwerke | FOM Hochschule | SS 2026
#
#  Alles in einer Datei: Topologie, Setup, Teardown.
#
#  Verwendung:
#    chmod +x lab-02-arp-spoofing.sh
#    ./lab-02-arp-spoofing.sh          # starten
#    ./lab-02-arp-spoofing.sh teardown # beenden
#
#  Voraussetzungen:
#    - ContainerLab installiert (containerlab version)
#    - Docker installiert und gestartet
#    - Linux (nativ oder WSL2)
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[FEHLER]${NC} $*"; exit 1; }
step()    { echo -e "\n${BOLD}━━━  $*  ━━━${NC}"; }

TOPO_FILE="/tmp/lab-02-arp-spoofing.clab.yml"
LAB_NAME="lab-02-arp-spoofing"

# ── Teardown ────────────────────────────────────────────────
if [[ "${1:-}" == "teardown" ]]; then
  echo -e "\n${BOLD}━━━  Lab 02: Teardown  ━━━${NC}\n"
  info "Stoppe ContainerLab..."
  sudo containerlab destroy -t "$TOPO_FILE" --cleanup 2>/dev/null || \
    containerlab destroy -t "$TOPO_FILE" --cleanup 2>/dev/null || true
  rm -f "$TOPO_FILE"
  success "Lab gestoppt und aufgeräumt."
  echo ""
  exit 0
fi

# ── Banner ──────────────────────────────────────────────────
echo -e "\n${BLUE}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   Lab 02: ARP Spoofing  |  FOM Sichere Netze   ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Voraussetzungen prüfen ───────────────────────────────────
step "0/4 – Voraussetzungen prüfen"

command -v containerlab >/dev/null 2>&1 || \
  error "containerlab nicht gefunden. Installation: bash -c \"\$(curl -sL https://get.containerlab.dev)\""
command -v docker >/dev/null 2>&1 || \
  error "docker nicht gefunden."
success "ContainerLab $(containerlab version 2>/dev/null | grep -i 'version:' | awk '{print $2}' | tr -d ' ' | head -1) und Docker verfügbar."

# ── Kernel-Parameter auf dem Host setzen ────────────────────
step "1/4 – Host-Kernel konfigurieren"

# Bridge-Netfilter deaktivieren – sonst filtert der Kernel
# gefälschte ARP-Replies auf der Bridge heraus
info "Setze Bridge-Netfilter und ARP-Parameter..."
sudo sysctl -w net.bridge.bridge-nf-call-arptables=0 >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-iptables=0  >/dev/null 2>&1 || true
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=0 >/dev/null 2>&1 || true
success "Host-Kernel konfiguriert."

# ── Topologie-Datei schreiben ────────────────────────────────
step "2/4 – Topologie erstellen"

cat > "$TOPO_FILE" << 'TOPOLOGY'
name: lab-02-arp-spoofing

topology:

  nodes:

    # ── alice: Das Opfer ──────────────────────────────────────
    alice:
      kind: linux
      image: ubuntu:22.04
      sysctls:
        # Gratuitous ARP akzeptieren – nötig damit ARP-Spoofing wirkt
        net.ipv4.conf.all.arp_accept: 1
        net.ipv4.conf.default.arp_accept: 1
      exec:
        - bash -c "apt-get update -qq && apt-get install -y -qq curl net-tools iputils-ping tcpdump iproute2 2>/dev/null"
        - bash -c "while true; do curl -s http://gateway.lab-02-arp-spoofing/ -o /dev/null --max-time 3 2>/dev/null || true; sleep 2; done &"

    # ── gateway: Der Webserver ────────────────────────────────
    gateway:
      kind: linux
      image: alpine:latest
      sysctls:
        net.ipv4.ip_forward: 1
      exec:
        - apk add --no-cache busybox-extras
        - mkdir -p /www
        # \072 = Oktal-Code fuer Doppelpunkt – vermeidet YAML-Parsing-Fehler
        - sh -c "printf '<html><head><title>Firmen-Intranet</title></head><body><h1>Firmen-Intranet</h1><p>Benutzername\072 admin</p><p>Passwort\072 SuperGeheim123</p></body></html>' > /www/index.html"
        - httpd -p 80 -h /www

    # ── mallory: Der Angreifer ────────────────────────────────
    mallory:
      kind: linux
      image: kalilinux/kali-rolling
      sysctls:
        # ip_forward=1: Pakete transparent weiterleiten – stiller MitM
        net.ipv4.ip_forward: 1
      exec:
        - bash -c "apt-get update -qq && apt-get install -y -qq ettercap-text-only tcpdump net-tools iputils-ping 2>/dev/null"

    # ── br0: Gemeinsame Bridge (L2-Segment) ─────────────────
    br0:
      kind: bridge

  links:
    # Alle drei Knoten hängen an der Bridge – eine Broadcast-Domain
    - endpoints: ["alice:eth1",   "br0:eth1"]
    - endpoints: ["gateway:eth1", "br0:eth2"]
    - endpoints: ["mallory:eth1", "br0:eth3"]
TOPOLOGY

success "Topologie geschrieben: $TOPO_FILE"

# ── ContainerLab deployen ────────────────────────────────────
step "3/4 – ContainerLab deployen"

info "Starte Container (exec-Befehle dauern ~2-3 Min)..."
sudo containerlab deploy -t "$TOPO_FILE" 2>/dev/null || \
  containerlab deploy -t "$TOPO_FILE"

# ── IPs auslesen und Zusammenfassung ────────────────────────
step "4/4 – Lab-Info"

# ContainerLab vergibt IPs über seine eigene Bridge
# Container-Namen haben das Schema: clab-<labname>-<node>
IP_ALICE=$(docker inspect -f \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  "clab-${LAB_NAME}-alice" 2>/dev/null || echo "unbekannt")
IP_GATEWAY=$(docker inspect -f \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  "clab-${LAB_NAME}-gateway" 2>/dev/null || echo "unbekannt")
IP_MALLORY=$(docker inspect -f \
  '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  "clab-${LAB_NAME}-mallory" 2>/dev/null || echo "unbekannt")

# Lab-Info in Container schreiben
for C in alice gateway mallory; do
  docker exec "clab-${LAB_NAME}-${C}" sh -c \
    "printf 'Lab 02\n  alice   ${IP_ALICE}\n  gateway ${IP_GATEWAY}\n  mallory ${IP_MALLORY}\n' \
    > /etc/lab-info" 2>/dev/null || true
done

# Angriffsbefehle speichern
cat > .attack-cmds << ACEOF
# Lab 02 – Angriffsbefehle
# ettercap (alle Befehle in clab-lab-02-arp-spoofing-mallory):

docker exec -it clab-${LAB_NAME}-mallory bash
ettercap -T -i eth1 -M arp:remote /${IP_ALICE}// /${IP_GATEWAY}//

# ARP-Cache beobachten (Host-Terminal):
watch -n 2 "docker exec clab-${LAB_NAME}-alice arp -n"

# ARP-Pakete mitschneiden (zweites Terminal):
docker exec clab-${LAB_NAME}-alice tcpdump -i eth1 -n arp
ACEOF

echo -e "\n${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║              Lab ist bereit!                    ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Netzwerk-Übersicht:${NC}"
echo -e "  alice   (Opfer)      →  ${BLUE}${IP_ALICE}${NC}   (Interface: eth1)"
echo -e "  gateway (Webserver)  →  ${BLUE}${IP_GATEWAY}${NC}   (HTTP Port 80)"
echo -e "  mallory (Angreifer)  →  ${BLUE}${IP_MALLORY}${NC}   (Interface: eth1)"

echo ""
echo -e "${BOLD}Container betreten:${NC}"
echo -e "  ${BLUE}docker exec -it clab-${LAB_NAME}-alice   bash${NC}"
echo -e "  ${BLUE}docker exec -it clab-${LAB_NAME}-gateway sh${NC}"
echo -e "  ${BLUE}docker exec -it clab-${LAB_NAME}-mallory bash${NC}"

echo ""
echo -e "${BOLD}Verbindung testen:${NC}"
echo -e "  ${BLUE}docker exec clab-${LAB_NAME}-alice curl -s http://${IP_GATEWAY}/${NC}"
echo -e "  ${BLUE}docker exec clab-${LAB_NAME}-alice arp -n${NC}"

echo ""
echo -e "${BOLD}Angriff starten (ettercap):${NC}"
echo -e "  ${BLUE}docker exec -it clab-${LAB_NAME}-mallory bash${NC}"
echo -e "  ${BLUE}ettercap -T -i eth1 -M arp:remote /${IP_ALICE}// /${IP_GATEWAY}//${NC}"

echo ""
echo -e "  ${BOLD}ARP-Cache beobachten:${NC}"
echo -e "  ${BLUE}watch -n 2 \"docker exec clab-${LAB_NAME}-alice arp -n\"${NC}"

echo ""
echo -e "  Alle Befehle auch in: ${YELLOW}.attack-cmds${NC}"
echo ""
echo -e "${BOLD}Lab beenden:${NC}"
echo -e "  ${BLUE}./lab-02-arp-spoofing.sh teardown${NC}"
echo ""

echo -e "${YELLOW}Hinweis: Interface ist eth1 (ContainerLab), nicht eth0 (Docker Compose)${NC}"
echo ""