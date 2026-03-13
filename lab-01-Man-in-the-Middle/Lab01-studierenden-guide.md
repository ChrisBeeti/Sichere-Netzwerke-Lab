# lab01 – Man-in-the-Middle: Wer sitzt in der Leitung?

| | |
|---|---|
| **Modul** | Sichere Netzwerke |
| **Hochschule** | FOM Hochschule für Oekonomie & Management |
| **Semester** | Sommersemester 2026 |
| **Dauer** | ca. 45–60 Minuten |
| **Voraussetzungen** | Docker Desktop installiert, Linux-Grundkenntnisse |

---

## Lernziele

Nach diesem Lab kannst du...

1. erklären, was ein Man-in-the-Middle-Angriff prinzipiell ist
2. beschreiben, welche Voraussetzungen ein Angreifer benötigt
3. nachvollziehen, wie unverschlüsselter Traffic mitgelesen werden kann
4. begründen, warum ein Angreifer in der Mitte für das Opfer unsichtbar bleiben kann
5. geeignete Schutzmaßnahmen benennen

---

## Das Szenario

Du arbeitest mit drei virtuellen Maschinen. Ein **Opfer** kommuniziert über das Netzwerk
mit einem **Webserver**. Zwischen beiden sitzt ein **Angreifer** – so positioniert, dass
jedes Paket vom Opfer an den Server zwingend durch ihn läuft.

> **Leitfrage:** Woher weiß ich eigentlich, mit wem ich wirklich kommuniziere?

---

## Topologie

```
  ┌─────────────┐       ┌──────────────┐       ┌─────────────┐
  │   victim    │       │   attacker   │       │   server    │
  │172.30.0.10  │──────▶│ 172.30.0.99  │──────▶│ 172.30.0.20 │
  └─────────────┘       └──────────────┘       └─────────────┘

  Alle drei Nodes im selben Netz: 172.30.0.0/24
  victim hat eine explizite Route: Pakete an server gehen via attacker.
  Jedes Paket von victim an server läuft zwingend durch den attacker.
```

| Node | Image | IP | Rolle |
|---|---|---|---|
| `victim` | `ubuntu:22.04` | `172.30.0.10` | Sendet HTTP-Anfragen |
| `attacker` | `kalilinux/kali-rolling` | `172.30.0.99` | Sitzt routing-technisch in der Mitte |
| `server` | `python:3-alpine` | `172.30.0.20` | HTTP-Webserver (Port 8080) |

---

## Aufgaben

### Schritt 1 – Lab starten

```bash
# Container starten
docker compose up -d

# Netzwerk und Tools konfigurieren
bash setup.sh
```

Prüfe, ob alle Container laufen:

```bash
docker ps
# Erwartung: 3 Container mit Status "Up"
```

---

### Schritt 2 – Drei Terminals öffnen

```bash
# Terminal A – victim
docker exec -it lab01-victim bash

# Terminal B – attacker
docker exec -it lab01-attacker bash

# Terminal C – server
docker exec -it lab01-server sh
```

---

### Schritt 3 – Netzwerk erkunden

Führe auf **victim** (Terminal A) aus:

```bash
# Routing-Tabelle anzeigen
ip route show

# Erreichbarkeit des Servers testen
ping -c 3 172.30.0.20
```

> **Frage:** Welche Route nimmt der Traffic zum Server?
> Was fällt an der Routing-Tabelle auf?

---

### Schritt 4 – HTTP-Traffic erzeugen

Starte auf **victim** eine Dauerschleife:

```bash
while true; do
  echo "=== $(date) ==="
  curl -s http://172.30.0.20:8080/
  sleep 5
done
```

Du siehst die Antwort des Servers. Lass dieses Terminal **laufen**.

---

### Schritt 5 – Traffic auf dem Angreifer beobachten

Wechsle zu **Terminal B (attacker)**:

```bash
tcpdump -i any -n -A -s 0 'tcp port 8080'
```

> **Beobachte die Ausgabe ca. 30 Sekunden:**
> - Was siehst du?
> - Welche Informationen aus der HTTP-Kommunikation sind lesbar?

**Notiere deine Beobachtungen:**

```
_______________________________________________
_______________________________________________
_______________________________________________
```

---

### Schritt 6 – Merkt das Opfer etwas?

Schau auf **Terminal A (victim)**:

> - Gibt es Fehlermeldungen?
> - Kommen die Server-Antworten weiterhin normal an?

Zeige den Routing-Pfad:

```bash
# Auf victim:
traceroute 172.30.0.20
```

**Was fällt an der Ausgabe auf?**

```
_______________________________________________
_______________________________________________
```

---

### Schritt 7 – Cleanup

```bash
# Strg+C in allen Terminals
docker compose down
```

---

## Reflexionsfragen

**F1 – Was hast du beobachtet?**
Beschreibe in eigenen Worten, was der Angreifer sehen konnte.

**F2 – Warum funktioniert das?**
Erkläre, warum der Traffic zwingend über den Angreifer läuft.

**F3 – Hat das Opfer etwas bemerkt?**
Was sagt dir das über reale Angreiferszenarien?

**F4 – Wie nennt sich dieses Angriffsmuster?**
Recherchiere den Fachbegriff für einen Angreifer, der unbemerkt zwischen
zwei Kommunikationspartnern sitzt.

**F5 – Schutzmaßnahmen**
Nenne mindestens zwei technische Maßnahmen, die verhindern, dass ein
Angreifer den Inhalt mitlesen kann.

---

## Quick Reference

| Befehl | Beschreibung | Node |
|---|---|---|
| `ip route show` | Routing-Tabelle anzeigen | victim |
| `ping -c 3 <ip>` | Erreichbarkeit testen | alle |
| `traceroute <ip>` | Routing-Pfad anzeigen | victim |
| `curl -s http://172.30.0.20:8080/` | HTTP-Anfrage senden | victim |
| `tcpdump -i any -n -A tcp port 8080` | Traffic mitschneiden | attacker |
| `docker compose up -d` | Lab starten | Host |
| `docker compose down` | Lab beenden | Host |
| `docker exec -it <n> bash` | In Container einloggen | Host |