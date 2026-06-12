#!/bin/sh
# =============================================================================
#  enable-dot.sh  –  im Resolver-Container ausfuehren (Stufe 3, BONUS)
#  Aktiviert einen DNS-over-TLS-Listener auf Port 853. Eine ueber DoT
#  gestellte Anfrage ist verschluesselt -> der on-path-Angreifer kann sie
#  weder mitlesen noch faelschen.
# =============================================================================
set -e

apk add --no-cache openssl >/dev/null 2>&1 || true
cd /etc/unbound

[ -f dot.pem ] || openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout dot.key -out dot.pem -days 365 \
    -subj "/CN=resolver.bank.local" >/dev/null 2>&1

if ! grep -q "@853" /etc/unbound/unbound.conf; then
    sed -i '/port: 53/a\    interface: 0.0.0.0@853\n    tls-service-key: "/etc/unbound/dot.key"\n    tls-service-pem: "/etc/unbound/dot.pem"' /etc/unbound/unbound.conf
fi

unbound-control reload >/dev/null
echo "DoT-Listener auf Port 853 aktiv."
echo "Test vom victim:  kdig -d +tls @10.50.0.53 bank.local"
