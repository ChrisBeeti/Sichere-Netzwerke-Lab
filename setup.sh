#!/bin/bash
# ============================================================
#  setup.sh
#  Automatische Installation: Docker + ContainerLab
#  Modul: Sichere Netzwerke | FOM Hochschule | SS 2026
#  Christian Böttger M.Sc.
#
#  Unterstützte Systeme:
#    - Ubuntu 20.04 / 22.04 / 24.04 (nativ oder WSL2)
#    - Debian 11 / 12
#    - Kali Linux
#
#  Verwendung:
#    chmod +x setup.sh
#    ./setup.sh
# ============================================================

set -euo pipefail

# ── Farben für die Ausgabe ──────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Hilfsfunktionen ─────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[FEHLER]${NC} $*"; exit 1; }
step()    { echo -e "\n${BOLD}━━━  $*  ━━━${NC}"; }

# ── Banner ──────────────────────────────────────────────────
echo -e "${BLUE}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║     FOM Hochschule – Sichere Netzwerke SS 2026      ║"
echo "  ║        Lab-Setup: Docker + ContainerLab             ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Root-Check ──────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
  error "Dieses Skript NICHT als root ausführen. Sudo wird bei Bedarf intern verwendet."
fi

# ── Sudo verfügbar? ─────────────────────────────────────────
if ! command -v sudo &>/dev/null; then
  error "sudo ist nicht installiert. Bitte erst 'apt-get install sudo' als root ausführen."
fi

# ── Betriebssystem erkennen ─────────────────────────────────
step "System erkennen"

if [[ ! -f /etc/os-release ]]; then
  error "/etc/os-release nicht gefunden – unbekanntes Betriebssystem."
fi

source /etc/os-release

info "Betriebssystem: ${PRETTY_NAME:-unbekannt}"
info "Kernel:         $(uname -r)"

# WSL erkennen
IS_WSL=false
if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  IS_WSL=true
  warn "WSL2-Umgebung erkannt – einige Hinweise beachten (siehe unten)."
fi

# Unterstützte Distributionen
case "${ID}" in
  ubuntu|debian|kali)
    success "Distribution '${ID}' wird unterstützt."
    ;;
  *)
    warn "Distribution '${ID}' wurde nicht getestet. Versuche fortzufahren..."
    ;;
esac

# ── Schritt 1: System aktualisieren ─────────────────────────
step "1/5 – Paketliste aktualisieren"

sudo apt-get update -qq
success "Paketliste aktualisiert."

# ── Schritt 2: Abhängigkeiten installieren ───────────────────
step "2/5 – Abhängigkeiten installieren"

sudo apt-get install -y -qq \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common \
  git \
  net-tools \
  iproute2 \
  iputils-ping \
  tcpdump

success "Abhängigkeiten installiert."

# ── Schritt 2b: Kernel-Module für WSL2-Networking ───────────
if $IS_WSL; then
  step "2b/5 – Kernel-Module laden (WSL2)"
  MODULES=("bridge" "br_netfilter" "8021q" "ip_tables" "iptable_filter" "iptable_nat")
  for MOD in "${MODULES[@]}"; do
    if sudo modprobe "$MOD" 2>/dev/null; then
      success "Modul geladen: ${MOD}"
    else
      warn "Modul nicht verfügbar: ${MOD}"
    fi
  done
  sudo sysctl -w net.ipv4.ip_forward=1 -q
  sudo sysctl -w net.bridge.bridge-nf-call-iptables=1 -q 2>/dev/null || true
  success "IPv4-Forwarding und Bridge-Netfilter aktiviert."
  MODFILE="/etc/modules-load.d/containerlab.conf"
  if [[ ! -f "$MODFILE" ]]; then
    printf '%s\n' "${MODULES[@]}" | sudo tee "$MODFILE" > /dev/null
    success "Module in ${MODFILE} für automatisches Laden eingetragen."
  else
    success "Modul-Persistenz bereits konfiguriert."
  fi
fi

# ── Schritt 3: Docker installieren ──────────────────────────
step "3/5 – Docker installieren"

if command -v docker &>/dev/null; then
  DOCKER_VERSION=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
  success "Docker ist bereits installiert (Version: ${DOCKER_VERSION}) – überspringe Installation."
else
  info "Lade offizielles Docker-Installationsskript herunter..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh --quiet
  rm -f /tmp/get-docker.sh
  success "Docker wurde installiert."
fi

# Docker-Dienst starten (nicht in WSL ohne systemd)
if $IS_WSL; then
  warn "WSL2 erkannt: Starte Docker-Daemon manuell (kein systemd)."
  if ! sudo service docker start 2>/dev/null; then
    warn "Docker-Dienst konnte nicht gestartet werden. Starte alternativ via dockerd..."
    sudo dockerd &>/tmp/dockerd.log &
    sleep 3
  fi
else
  sudo systemctl enable docker --quiet
  sudo systemctl start docker
fi

# Aktuellen User zur Docker-Gruppe hinzufügen
if ! groups "$USER" | grep -q docker; then
  sudo usermod -aG docker "$USER"
  warn "Benutzer '${USER}' zur Gruppe 'docker' hinzugefügt."
  warn "WICHTIG: Nach dem Skript einmal ab- und wieder anmelden (oder 'newgrp docker' ausführen)!"
else
  success "Benutzer '${USER}' ist bereits in der Docker-Gruppe."
fi

# Docker-Test
info "Teste Docker-Installation..."
if sudo docker run --rm hello-world &>/dev/null; then
  success "Docker funktioniert korrekt."
else
  error "Docker-Test fehlgeschlagen. Bitte 'sudo service docker start' manuell ausführen."
fi

# ── Schritt 4: ContainerLab installieren ────────────────────
step "4/5 – ContainerLab installieren"

if command -v containerlab &>/dev/null; then
  CLAB_VERSION=$(containerlab version 2>/dev/null | grep -i "version:" | awk '{print $2}' | tr -d '[:space:]' | head -1)
  success "ContainerLab ist bereits installiert (Version: ${CLAB_VERSION}) – überspringe."
else
  info "Lade ContainerLab-Installationsskript herunter..."
  curl -sL https://get.containerlab.dev | sudo bash
  success "ContainerLab wurde installiert."
fi

# clab_admins-Gruppe hinzufügen (neu ab ContainerLab v0.56+)
# Ohne diese Gruppe schlägt 'containerlab deploy' ohne sudo fehl
if getent group clab_admins &>/dev/null; then
  if ! groups "$USER" | grep -q clab_admins; then
    sudo usermod -aG clab_admins "$USER"
    warn "Benutzer '${USER}' zur Gruppe 'clab_admins' hinzugefügt."
    warn "WICHTIG: 'newgrp clab_admins' ausführen oder neu anmelden!"
  else
    success "Benutzer '${USER}' ist bereits in der Gruppe 'clab_admins'."
  fi
else
  warn "Gruppe 'clab_admins' nicht gefunden – ContainerLab ggf. mit sudo ausführen."
fi

# Version sauber parsen (Leerzeichen entfernen)
CLAB_VER=$(containerlab version 2>/dev/null | grep -i "version:" | awk '{print $2}' | tr -d '[:space:]' | head -1 || echo "unbekannt")
info "ContainerLab-Version: ${CLAB_VER}"

# ── Schritt 5: Docker-Images vorziehen ─────────────────────
step "5/5 – Docker-Images für Lab 01 vorziehen"

info "Dies kann einige Minuten dauern (Kali-Image ~1,5 GB)..."

IMAGES=(
  "ubuntu:22.04"
  "alpine:latest"
  "kalilinux/kali-rolling"
)

for IMAGE in "${IMAGES[@]}"; do
  info "Lade Image: ${IMAGE}"
  if sudo docker pull "${IMAGE}" --quiet; then
    success "Image bereit: ${IMAGE}"
  else
    warn "Image konnte nicht geladen werden: ${IMAGE} – ggf. manuell nachholen."
  fi
done

# ── Abschlussbericht ────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║              Installation abgeschlossen!            ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Installierte Komponenten:${NC}"
echo -e "  Docker        →  $(sudo docker --version 2>/dev/null || echo 'nicht gefunden')"
echo -e "  ContainerLab  →  $(containerlab version 2>/dev/null | grep -i "version:" | awk '{print $2}' | tr -d '[:space:]' | head -1 || echo 'nicht gefunden')"

echo ""
echo -e "${BOLD}Nächste Schritte:${NC}"
echo -e "  1. ${YELLOW}Neu anmelden${NC} (oder beide Befehle ausführen):"
echo -e "     ${BLUE}newgrp docker && newgrp clab_admins${NC}"
echo -e "  2. Lab-Topologie starten:"
echo -e "     ${BLUE}containerlab deploy -t lab-01-arp-spoofing.clab.yml${NC}"
echo -e "  3. Lab beenden:"
echo -e "     ${BLUE}containerlab destroy -t lab-01-arp-spoofing.clab.yml${NC}"

if $IS_WSL; then
  echo ""
  echo -e "${YELLOW}${BOLD}WSL2-Hinweise:${NC}"
  echo -e "  • Docker-Dienst muss nach jedem WSL-Neustart manuell gestartet werden:"
  echo -e "    ${BLUE}sudo service docker start${NC}"
  echo -e "  • Falls ContainerLab Probleme mit Bridges hat:"
  echo -e "    ${BLUE}sudo modprobe br_netfilter${NC}"
  echo -e "  • Für persistenten Docker-Start: .bashrc oder .zshrc ergänzen:"
  echo -e "    ${BLUE}echo 'sudo service docker start' >> ~/.bashrc${NC}"
fi

echo ""