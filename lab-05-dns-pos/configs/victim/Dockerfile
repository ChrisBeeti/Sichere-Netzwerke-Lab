# Opfer-Image fuer Lab 05.
# curl + dig werden hier beim BUILD installiert (ueber Dockers Standard-DNS),
# damit zur Laufzeit kein Internet noetig ist – das Opfer nutzt dann unsere
# unbound (10.50.0.53), die absichtlich nicht ins Internet aufloest.
FROM ubuntu:22.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl dnsutils iputils-ping ca-certificates \
 && rm -rf /var/lib/apt/lists/*
CMD ["sleep", "infinity"]
