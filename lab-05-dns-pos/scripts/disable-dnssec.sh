#!/bin/sh
# =============================================================================
#  disable-dnssec.sh  –  im Resolver-Container ausfuehren
#  Schaltet die Validierung wieder ab (Ausgangszustand Stufe 1+2).
# =============================================================================
set -e

if [ -f /etc/unbound/unbound.conf.nodnssec ]; then
    cp /etc/unbound/unbound.conf.nodnssec /etc/unbound/unbound.conf
fi
unbound-control reload >/dev/null
unbound-control flush_zone bank.local. >/dev/null 2>&1 || true
echo "DNSSEC-Validierung DEAKTIVIERT (zurueck zu Stufe 1+2). Cache geleert."
