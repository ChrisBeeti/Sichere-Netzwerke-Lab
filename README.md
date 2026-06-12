# Sichere Netzwerke – Labor-Repository

**FOM Hochschule für Oekonomie & Management**  
Modul: Sichere Netzwerke | 6 ECTS | Sommersemester 2026

Dieses Repository enthält alle praktischen Laborübungen zum Modul **Sichere Netzwerke** sowie die zugehörigen Vorlesungsmaterialien (`Lecture/`). Die Docker-basierten Labs sind als eigenständige Docker-Compose-Umgebungen aufgebaut und laufen auf Windows (Docker Desktop), Linux (Ubuntu VM) und macOS ohne zusätzliche Konfiguration.

---

## Schnellstart

### 1. Voraussetzungen installieren

Im Root-Verzeichnis liegt ein Installationsskript für Docker und Containerlab:

```bash
bash setup.sh
```

> Unter **Windows** das Skript in einer WSL2-Shell oder Git Bash ausführen.  
> Alternativ: [Docker Desktop](https://www.docker.com/products/docker-desktop/) manuell installieren.

### 2. Ein Lab starten

```bash
cd lab-01-Man-in-the-Middle/
docker compose up -d
bash setup.sh
```

### 3. Lab beenden

```bash
docker compose down
```

> **Ausnahme lab-04-bgp-gen:** Dieses Lab läuft komplett lokal über Python + Wireshark und benötigt **kein** Docker (siehe `lab-04-bgp-gen/lab06-studierenden-guide.md`).

---

## Struktur des Repositories

```
Sichere-Netzwerke-Lab/
│
├── setup.sh                         # Docker + Containerlab Installation
├── README.md                        # Diese Datei
├── Lecture/                          # Vorlesungsmaterialien (Folien, Demos)
│
├── lab-01-Man-in-the-Middle/         # ✅ Man-in-the-Middle
├── lab-02-arp-spoofing/              # ✅ ARP Spoofing
├── lab-03-tls-analyse/               # ✅ TLS-Analyse
├── lab-04-bgp-gen/                   # ✅ BGP-Verkehr-Analyse (ohne Docker)
└── lab-05-dns-pos/                   # ✅ DNS Poisoning
```

Jedes Docker-basierte Lab-Verzeichnis ist eigenständig und enthält in der Regel:

| Datei | Beschreibung |
|---|---|
| `docker-compose.yml` | Netzwerktopologie und Container-Definition |
| `setup.sh` / `teardown.sh` | Post-Start-Konfiguration bzw. Aufräumen (Routen, Tools, Dienste) |
| `*-studierenden-guide.md` (bzw. `student/`) | Schritt-für-Schritt-Anleitung für Studierende |
| `*-dozenten-guide.md` (bzw. `instructor/`) | Musterlösungen und didaktische Hinweise – ⚠️ vertraulich, nicht im Repo (`.gitignore`) |

> Die genauen Dateinamen variieren leicht je Lab (z. B. `Lab01-studierenden-guide.md` vs. `lab05-studierenden-guide.md`).

---

## Übersicht aller Labs

| # | Verzeichnis | Titel | Thema | Schwierigkeit | Status |
|---|---|---|---|---|---|
| 01 | [lab-01-Man-in-the-Middle](./lab-01-Man-in-the-Middle/) | Man-in-the-Middle | Angreifer in der Mitte, Klartext-HTTP | Einsteiger | ✅ |
| 02 | [lab-02-arp-spoofing](./lab-02-arp-spoofing/) | ARP Spoofing | L2-Angriff, ARP-Cache-Manipulation | Einsteiger | ✅ |
| 03 | [lab-03-tls-analyse](./lab-03-tls-analyse/) | TLS-Analyse | HTTPS, Zertifikate, Wireshark | Fortgeschritten | ✅ |
| 04 | [lab-04-bgp-gen](./lab-04-bgp-gen/) | BGP-Verkehr-Analyse | Routing, BGP-Nachrichten, PCAP-Analyse (ohne Docker) | Einsteiger–Mittel | ✅ |
| 05 | [lab-05-dns-pos](./lab-05-dns-pos/) | DNS Poisoning | Cache Poisoning, DNSSEC | Fortgeschritten | ✅ |

---

## Plattform-Kompatibilität

| Plattform | Getestet | Hinweis |
|---|---|---|
| Windows – Docker Desktop | ✅ | Empfohlen für Studium |
| Ubuntu VM (nativ) | ✅ | Empfohlen für tieferes Verständnis |
| macOS – Docker Desktop | ✅ | |
| Windows WSL2 | ⚠️ | Netzwerk-Einschränkungen möglich |

> lab-04-bgp-gen benötigt kein Docker, sondern lediglich Python 3 und Wireshark (auf Windows mit Npcap-Loopback-Unterstützung).

---

## Technische Grundlagen

Die Docker-Labs nutzen ausschließlich frei verfügbare Open-Source-Images:

| Image | Einsatz |
|---|---|
| `ubuntu:22.04` | Client/Opfer-Nodes |
| `kalilinux/kali-rolling` | Angreifer-Nodes (Tools vorinstalliert) |
| `alpine:latest` | Leichtgewichtige Nodes (Gateway, DNS-Resolver) |
| `python:3-alpine` | Leichtgewichtige Server (HTTP, DNS) |
| `nginx:alpine` | Webserver für TLS- und DNS-Labs |
| `nicolaka/netshoot` | Analyse-Container mit Netzwerk-Troubleshooting-Tools |

---

## Neues Lab hinzufügen

1. Verzeichnis anlegen: `lab-XX-thema/`
2. Folgende Dateien erstellen:
   - `docker-compose.yml` – Topologie (oder lokales Setup-Skript, falls ohne Docker)
   - `setup.sh` / `teardown.sh` – Post-Start-Konfiguration und Aufräumen
   - `*-studierenden-guide.md` – Anleitung
   - `*-dozenten-guide.md` – Musterlösung (nicht committen, siehe `.gitignore`)
3. Eintrag in der Übersichtstabelle in dieser README ergänzen

---

## Lizenz & Verwendung

Dieses Repository ist für den Einsatz im Rahmen des Moduls **Sichere Netzwerke** an der FOM Hochschule bestimmt. Die Dozenten-Guides sind vertraulich und nicht zur Weitergabe an Studierende vorgesehen.