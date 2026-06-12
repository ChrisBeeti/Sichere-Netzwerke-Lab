#!/bin/sh
# =============================================================================
#  enable-dnssec.sh  –  im Resolver-Container ausfuehren (Stufe 3)
#  Aktiviert die DNSSEC-Validierung mit dem Trust Anchor von auth-dns.
# =============================================================================
set -e

A=/shared/bank.local.ksk
[ -s "$A" ] || { echo "FEHLER: Kein Trust Anchor in $A (laeuft auth-dns schon?)"; exit 1; }
TA=$(cat "$A")

[ -f /etc/unbound/unbound.conf.nodnssec ] || cp /etc/unbound/unbound.conf /etc/unbound/unbound.conf.nodnssec

# | als Delimiter (base64 enthaelt kein |)
sed "s|__TRUST_ANCHOR__|${TA}|" /etc/unbound/unbound-dnssec.conf.tmpl > /etc/unbound/unbound.conf

unbound-control reload >/dev/null
unbound-control flush_zone bank.local. >/dev/null 2>&1 || true

echo "DNSSEC-Validierung AKTIV. Cache fuer bank.local geleert."
echo "Trust Anchor: ${TA}"
