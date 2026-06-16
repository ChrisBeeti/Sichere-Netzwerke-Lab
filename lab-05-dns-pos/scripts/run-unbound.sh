#!/bin/sh
# =============================================================================
#  run-unbound.sh  –  Startskript fuer den Resolver-Container (Stufe 1+2)
# =============================================================================
set -e

echo "[resolver] Installiere unbound + Tools ..."
apk add --no-cache unbound bind-tools >/dev/null 2>&1

echo "[resolver] Uebernehme Konfiguration ..."
mkdir -p /etc/unbound
cp /configs/unbound/unbound.conf            /etc/unbound/unbound.conf
cp /configs/unbound/unbound-dnssec.conf.tmpl /etc/unbound/unbound-dnssec.conf.tmpl

echo "[resolver] Starte unbound  (Stufe 1+2: OHNE DNSSEC-Validierung)"
exec unbound -d -c /etc/unbound/unbound.conf
