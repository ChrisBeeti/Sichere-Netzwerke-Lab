# Sichere Netzwerke – Labor-Repository

**FOM Hochschule für Oekonomie & Management**  
Modul: Sichere Netzwerke | 6 ECTS | Sommersemester 2026

Dieses Repository enthält alle praktischen Laborübungen zum Modul **Sichere Netzwerke**. Die Labs sind als eigenständige Docker-Compose-Umgebungen aufgebaut und laufen auf Windows (Docker Desktop), Linux (Ubuntu VM) und macOS ohne zusätzliche Konfiguration.

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

---

## Struktur des Repositories

```
sichere-netzwerke-labs/
│
├── setup.sh                        # Docker + Containerlab Installation
├── README.md                       # Diese Datei
│
├── lab-01-Man-in-the-Middle/       # ✅ verfügbar
│   ├── docker-compose.yml
│   ├── setup.sh
│   ├── lab01_studierenden_guide.md
│   └── lab01_dozenten_guide.md
│
├── lab-02-ARP-Spoofing/            # 🔜 in Vorbereitung
├── lab-03-TLS-Analyse/             # 🔜 in Vorbereitung
├── lab-04-Firewall/                # 🔜 in Vorbereitung
├── lab-05-DNS-Poisoning/           # 🔜 in Vorbereitung
└── lab-06-Forensik/                # 🔜 in Vorbereitung
```

Jedes Lab-Verzeichnis ist vollständig eigenständig und enthält:

| Datei | Beschreibung |
|---|---|
| `docker-compose.yml` | Netzwerktopologie und Container-Definition |
| `setup.sh` | Post-Start-Konfiguration (Routen, Tools, Dienste) |
| `labXX_studierenden_guide.md` | Schritt-für-Schritt-Anleitung für Studierende |
| `labXX_dozenten_guide.md` | Musterlösungen und didaktische Hinweise ⚠️ vertraulich |

---

## Übersicht aller Labs

| # | Titel | Thema | Schwierigkeit | Status |
|---|---|---|---|---|
| [lab01](./lab-01-Man-in-the-Middle/) | Man-in-the-Middle | Angreifer in der Mitte, Klartext-HTTP | Einsteiger | ✅ |
| lab02 | ARP Spoofing | L2-Angriff, ARP-Cache-Manipulation | Einsteiger | 🔜 |
| lab03 | TLS-Analyse | HTTPS, Zertifikate, Wireshark | Fortgeschritten | 🔜 |
| lab04 | Firewall | iptables / nftables Regelwerke | Fortgeschritten | 🔜 |
| lab05 | DNS Poisoning | Cache Poisoning, DNSSEC | Fortgeschritten | 🔜 |
| lab06 | Netzwerkforensik | PCAP-Analyse, Angriffsrekonstruktion | Experte | 🔜 |

---

## Plattform-Kompatibilität

| Plattform | Getestet | Hinweis |
|---|---|---|
| Windows – Docker Desktop | ✅ | Empfohlen für Studium |
| Ubuntu VM (nativ) | ✅ | Empfohlen für tieferes Verständnis |
| macOS – Docker Desktop | ✅ | |
| Windows WSL2 | ⚠️ | Netzwerk-Einschränkungen möglich |

---

## Technische Grundlagen

Die Labs nutzen ausschließlich frei verfügbare Open-Source-Images:

| Image | Einsatz |
|---|---|
| `ubuntu:22.04` | Client/Opfer-Nodes |
| `kalilinux/kali-rolling` | Angreifer-Nodes (Tools vorinstalliert) |
| `python:3-alpine` | Leichtgewichtige Server (HTTP, DNS) |
| `frrouting/frr:latest` | Routing-Labs (OSPF, BGP) |
| `nginx:alpine` | Webserver für TLS-Labs |

---

## Neues Lab hinzufügen

1. Verzeichnis anlegen: `lab-XX-Thema/`
2. Folgende Dateien erstellen:
   - `docker-compose.yml` – Topologie
   - `setup.sh` – Post-Start-Konfiguration
   - `labXX_studierenden_guide.md` – Anleitung
   - `labXX_dozenten_guide.md` – Musterlösung
3. Eintrag in der Übersichtstabelle in dieser README ergänzen

---

## Lizenz & Verwendung

Dieses Repository ist für den Einsatz im Rahmen des Moduls **Sichere Netzwerke** an der FOM Hochschule bestimmt. Die Dozenten-Guides sind vertraulich und nicht zur Weitergabe an Studierende vorgesehen.