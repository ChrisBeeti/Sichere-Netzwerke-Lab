#!/bin/bash
# ============================================================
#  setup.sh  –  Lab 03: TLS-Analyse
#  FOM Hochschule – Sichere Netzwerke SS 2026
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

echo -e "\n${BOLD}  ╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}  ║   Lab 03: TLS-Analyse  |  FOM Sichere Netze    ║${NC}"
echo -e "${BOLD}  ╚══════════════════════════════════════════════════╝${NC}\n"

# ── 1/4 Zertifikate generieren ────────────────────────────────────────────────
echo -e "${BOLD}━━━  1/4 – Zertifikate generieren  ━━━${NC}"
info "Erstelle selbst-signiertes Serverzertifikat..."
mkdir -p configs/server/certs

openssl req -x509 -newkey rsa:2048 \
  -keyout configs/server/certs/server.key \
  -out    configs/server/certs/server.crt \
  -days   365 -nodes \
  -subj   "/C=DE/ST=NRW/L=Essen/O=FOM Lab/CN=lab03.fom.local" \
  -addext "subjectAltName=IP:10.30.0.10,DNS:lab03.fom.local" \
  2>/dev/null

success "Zertifikat erstellt: configs/server/certs/server.crt"

# ── 2/4 Altes Netz entfernen ──────────────────────────────────────────────────
echo -e "${BOLD}━━━  2/4 – Netzwerk vorbereiten  ━━━${NC}"
docker network rm lab03-net >/dev/null 2>&1 && \
  info "Altes Netzwerk entfernt." || true

# ── 3/4 Container starten ─────────────────────────────────────────────────────
echo -e "${BOLD}━━━  3/4 – Container starten  ━━━${NC}"
if [[ $VERBOSE -eq 1 ]]; then
  docker compose up -d
else
  docker compose up -d 2>&1 | grep -E "(Running|Started|Created|Error)" || true
fi

sleep 2

# ── 4/4 Lab-Info injizieren ───────────────────────────────────────────────────
echo -e "${BOLD}━━━  4/4 – Lab-Info einrichten  ━━━${NC}"

# Fingerprint des Zertifikats für Aufgabe 2
FINGERPRINT=$(openssl x509 -in configs/server/certs/server.crt \
  -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2)

for CONTAINER in lab03-client lab03-analyst; do
  docker exec "$CONTAINER" sh -c "cat > /etc/lab-info << 'LABINFO'
=== Lab 03: TLS-Analyse ===
Server:   10.30.0.10  (HTTPS Port 443)
Client:   10.30.0.20
Analyst:  10.30.0.30

Leitfrage: Welche Informationen überträgt TLS im Klartext,
           und welche sind verschlüsselt?

Aufgaben:
  A1  TLS-Handshake mit openssl s_client beobachten
  A2  Zertifikat analysieren (Felder, Gültigkeit, Fingerprint)
  A3  Netzwerkverkehr mit tshark aufzeichnen und auswerten
  A4  TLS-Versionen und Cipher Suites vergleichen
  A5  Reflexion: Was schützt TLS — und was nicht?
LABINFO
" 2>/dev/null
done

# Fingerprint-Datei für Aufgabe 2 ablegen
docker exec lab03-client sh -c "echo 'SHA256-Fingerprint des Serverzertifikats:' > /expected-fingerprint.txt; \
  echo '$FINGERPRINT' >> /expected-fingerprint.txt"

# Hilfs-Alias im Client setzen
docker exec lab03-client sh -c "
  echo 'alias server-connect=\"openssl s_client -connect 10.30.0.10:443 -CAfile /server.crt\"' >> /root/.bashrc
"

# Server-Zertifikat in Client kopieren (für Verifikation)
docker cp configs/server/certs/server.crt lab03-client:/server.crt 2>/dev/null

success "Lab-Info in Containern hinterlegt."

# ── Abschluss ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Lab 03 bereit!${NC}"
echo ""
echo -e "  ${BOLD}Zugriff:${NC}"
echo -e "  Client:   docker exec -it lab03-client bash"
echo -e "  Analyst:  docker exec -it lab03-analyst bash"
echo -e ""
echo -e "  ${BOLD}Einstieg:${NC}"
echo -e "  docker exec lab03-client cat /etc/lab-info"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
