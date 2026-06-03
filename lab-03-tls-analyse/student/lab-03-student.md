# Lab 03: Netzwerksicherheit in der Praxis

| Modul | Sichere Netzwerke SS 2026 |
|---|---|
| Dozent | Christian Böttger |
| Schwierigkeit | ⭐⭐ Mittel |
| Dauer | ca. 60–75 Minuten |
| Voraussetzungen | Lab 01 und Lab 02 abgeschlossen |

---

## Lernziele

Nach diesem Lab kannst du:

- einen TLS-Verbindungsaufbau Schritt für Schritt nachvollziehen
- ein X.509-Zertifikat auslesen und seine Felder einordnen
- TLS-Verkehr im Netzwerk aufzeichnen und auswerten
- den Unterschied zwischen verschlüsseltem und unverschlüsseltem Verkehr erkennen
- einschätzen, welche Metadaten auch bei TLS sichtbar bleiben

---

## Topologie

```
┌────────────────┐        10.30.0.0/24        ┌────────────────┐
│                │                             │                │
│   lab03-server │◄──────────────────────────►│  lab03-client  │
│   10.30.0.10   │   HTTPS (443) / HTTP (80)  │   10.30.0.20   │
│   nginx + TLS  │                             │  openssl/curl  │
└────────────────┘                             └────────────────┘
                                                       │
                                               ┌───────┴───────┐
                                               │ lab03-analyst │
                                               │  10.30.0.30   │
                                               │    tshark     │
                                               └───────────────┘
```

---

## Vorbereitung

> **Leitfrage:** Welche Informationen überträgt TLS im Klartext — und welche nicht?

```bash
# Lab starten
./setup.sh

# In den Client-Container wechseln
docker exec -it lab03-client bash

# Aufgabenübersicht anzeigen
cat /etc/lab-info
```

---

## Aufgabe 1: TLS-Handshake beobachten

Verbinde dich vom **Client** aus mit dem Server und beobachte den Handshake-Ablauf.

```bash
# Aus dem Client-Container heraus:
openssl s_client -connect 10.30.0.10:443 \
  -CAfile /server.crt \
  -state -msg 2>&1 | head -60
```

> 🎓 **Beobachtungsaufgabe:** Notiere die Reihenfolge der Nachrichten.  
> Welche Meldungen tauchen auf? Was passiert vor dem eigentlichen Datenaustausch?

**Notizen:**

```
_______________________________________________________
_______________________________________________________
_______________________________________________________
_______________________________________________________
```

---

## Aufgabe 2: Zertifikat analysieren

Lass dir das Serverzertifikat vollständig anzeigen:

```bash
# Zertifikat-Details ausgeben
openssl s_client -connect 10.30.0.10:443 \
  -CAfile /server.crt \
  -showcerts 2>/dev/null \
  | openssl x509 -noout -text

# Nur die wichtigsten Felder
openssl x509 -in /server.crt -noout \
  -subject -issuer -dates -fingerprint -sha256
```

Fülle die folgende Tabelle aus:

| Feld | Wert |
|---|---|
| Common Name (CN) | |
| Aussteller (Issuer) | |
| Gültig von | |
| Gültig bis | |
| SHA-256 Fingerprint | |
| Public Key Algorithmus | |
| Schlüssellänge | |

> ℹ️ **Frage:** Wer hat dieses Zertifikat ausgestellt? Würde dein Browser diesem Zertifikat vertrauen?

---

## Aufgabe 3: Netzwerkverkehr aufzeichnen

Öffne zwei Terminals parallel.

**Terminal 1 — Analyst-Container (Mitschnitt starten):**
```bash
docker exec -it lab03-analyst bash

# Verkehr auf dem Netz aufzeichnen, auf Port 443 filtern
tshark -i eth0 -f "tcp port 443" \
  -Y "tls" -V 2>/dev/null | head -80
```

**Terminal 2 — Client-Container (Anfrage senden):**
```bash
docker exec -it lab03-client bash

# HTTPS-Anfrage
curl -k https://10.30.0.10/api/secret
```

> 🎓 **Beobachtungsaufgabe:** Was siehst du in der tshark-Ausgabe?  
> Kannst du den Inhalt der Antwort im Netzwerkverkehr erkennen?

**Notizen:**

```
_______________________________________________________
_______________________________________________________
```

**Jetzt im Vergleich HTTP (unverschlüsselt):**
```bash
# Im Analyst-Terminal: Filter auf Port 80
tshark -i eth0 -f "tcp port 80" -A 2>/dev/null | head -40 &

# Im Client-Terminal:
curl http://10.30.0.10/api/secret
```

> 🎓 **Vergleich:** Was ist jetzt im Mitschnitt sichtbar?

**Notizen:**

```
_______________________________________________________
_______________________________________________________
```

---

## Aufgabe 4: TLS-Versionen und Cipher Suites

```bash
# Verfügbare TLS-Versionen testen
for VERSION in tls1_2 tls1_3; do
  echo "=== TLS $VERSION ==="
  openssl s_client -connect 10.30.0.10:443 \
    -CAfile /server.crt \
    -$VERSION 2>&1 | grep -E "(Protocol|Cipher|New|Reused)"
  echo ""
done
```

> 🎓 **Frage:** Welche Cipher Suite wird bei TLS 1.3 ausgehandelt?  
> Was bedeutet „Perfect Forward Secrecy" (PFS)?

**Notizen:**

```
_______________________________________________________
_______________________________________________________
_______________________________________________________
```

---

## Aufgabe 5 (Bonus): Was sieht ein Angreifer?

Auch wenn TLS den Inhalt verschlüsselt, bleiben bestimmte Informationen sichtbar.

```bash
# Im Analyst-Terminal: Nur TLS-Metadaten
tshark -i eth0 \
  -Y "tls.handshake.type == 1" \
  -T fields \
  -e ip.src -e ip.dst \
  -e tls.handshake.extensions_server_name \
  -e tls.handshake.version \
  2>/dev/null &

# Client: Mehrere Anfragen senden
for i in 1 2 3; do
  curl -sk https://10.30.0.10/api/secret > /dev/null
done
```

**Welche Metadaten sind auch bei TLS sichtbar?**

```
_______________________________________________________
_______________________________________________________
```

---

## Reflexionsfragen

**F1.** Ein Kollege meint: „Wir nutzen HTTPS, also sind unsere Daten sicher." Was würdest du antworten?

```
_______________________________________________________
_______________________________________________________
```

**F2.** Euer Unternehmen nutzt ein selbst-signiertes Zertifikat für das interne Mitarbeiterportal. Welche Risiken entstehen dadurch? Was wäre die Alternative?

```
_______________________________________________________
_______________________________________________________
```

**F3.** Was passiert, wenn ein Angreifer ein TLS-Zertifikat für eine Domain fälscht? Welche Schutzmechanismen verhindern das?

```
_______________________________________________________
_______________________________________________________
```

---

## Cleanup

```bash
# Lab beenden
exit  # Container verlassen
./teardown.sh
```
