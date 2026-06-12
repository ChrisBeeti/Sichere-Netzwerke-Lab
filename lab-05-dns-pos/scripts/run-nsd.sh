#!/bin/sh
# =============================================================================
#  run-nsd.sh  –  Startskript fuer den autoritativen Server (auth-dns)
#  Signiert bank.local mit DNSSEC und exportiert den KSK fuer den Resolver.
# =============================================================================
set -e

echo "[auth-dns] Installiere nsd + ldns + Tools ..."
apk add --no-cache nsd ldns ldns-tools bind-tools >/dev/null 2>&1 || \
  apk add --no-cache nsd ldns bind-tools >/dev/null 2>&1
if ! command -v ldns-signzone >/dev/null 2>&1; then
  echo "[auth-dns] FEHLER: ldns-signzone fehlt. apk-Paket 'ldns-tools' nicht verfuegbar?"
  echo "[auth-dns]        Pruefe: docker exec lab05-auth-dns apk add ldns-tools"
  exit 1
fi

echo "[auth-dns] Uebernehme Konfiguration ..."
mkdir -p /etc/nsd/zones
cp /configs/nsd/nsd.conf                 /etc/nsd/nsd.conf
cp /configs/nsd/zones/bank.local.zone    /etc/nsd/zones/bank.local.zone
cd /etc/nsd/zones

echo "[auth-dns] Erzeuge DNSSEC-Schluessel (KSK + ZSK) ..."
KSK=$(ldns-keygen -a ECDSAP256SHA256 -k bank.local)
ZSK=$(ldns-keygen -a ECDSAP256SHA256 bank.local)

echo "[auth-dns] Signiere Zone bank.local ..."
ldns-signzone bank.local.zone "$ZSK" "$KSK"

echo "[auth-dns] Exportiere KSK als Trust Anchor (-> /shared) ..."
mkdir -p /shared
awk '/DNSKEY/ && $0 !~ /^;/ { sub(/;.*/,""); $1=$1; print; exit }' "${KSK}.key" > /shared/bank.local.ksk
echo "[auth-dns] Trust Anchor: $(cat /shared/bank.local.ksk)"

echo "[auth-dns] Starte nsd ..."
exec nsd -d -c /etc/nsd/nsd.conf
