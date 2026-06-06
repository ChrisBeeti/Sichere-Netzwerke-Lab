# Lab 06: BGP-Verkehr forensisch analysieren

|  |  |
|---|---|
| **Modul** | Sichere Netzwerke (FOM Hochschule, SS 2026) |
| **Lab** | 06 — Routing / BGP-Analyse |
| **Dauer** | ca. 45–60 Minuten |
| **Schwierigkeit** | ●●○○ (Einsteiger–Mittel) |
| **Vorausgesetzt** | Wireshark-Grundlagen (Lab 01/02), Python 3 installiert |
| **Tools** | Python 3, Wireshark (Windows: mit Npcap-Loopback) |
| **Infrastruktur** | Kein Docker nötig — der Verkehr entsteht lokal über die Loopback-Schnittstelle |

---

## Lernziele

Am Ende dieses Labs könnt ihr:

- den Aufbau einer Routing-Session zwischen zwei autonomen Systemen im Mitschnitt **identifizieren**
- die vier BGP-Nachrichtentypen (OPEN, UPDATE, KEEPALIVE, NOTIFICATION) **unterscheiden** und ihren Zweck **erklären**
- aus den Nachrichten ASN, Protokollversion, angekündigte und zurückgezogene IP-Präfixe sowie Pfad-Attribute **auslesen**
- aus einer Eigenschaft des Protokolls eine **Sicherheitslücke ableiten** und passende Gegenmaßnahmen **benennen**

---

## Szenario

Zwei Router stehen jeweils am Rand eines autonomen Systems (AS65001 und AS65002) und tauschen über das Border Gateway Protocol Erreichbarkeitsinformationen aus. Ihr habt den Datenverkehr dieser Peering-Sitzung mitgeschnitten und sollt ihn als Netzwerk-Analyst:in auseinandernehmen — so, wie ihr es bei der forensischen Auswertung eines echten Vorfalls tun würdet.

> ℹ️ **Hinweis:** Die verwendeten IP-Präfixe (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`) und die AS-Nummern stammen aus offiziell für Dokumentation/Tests reservierten Bereichen. Es wird kein realer Internetverkehr erzeugt — alles läuft auf eurer eigenen Loopback-Schnittstelle.

---

## Aufgabe 1 — Mitschnitt vorbereiten und starten

1. Öffnet **Wireshark** und wählt die **Loopback**-Schnittstelle:
   - Linux: `lo` bzw. „Loopback: lo"
   - Windows: „Adapter for loopback traffic capture" (über Npcap)
   - macOS: `lo0`
2. Tragt den Anzeigefilter ein:

   ```
   tcp.port == 17000
   ```
3. Startet die Aufzeichnung (▶), dann führt in einem Terminal aus:

   ```
   python3 bgp_traffic_generator.py
   ```
4. Stoppt nach Ende des Skripts die Aufzeichnung (■).

> ℹ️ **Wichtig:** Da die Session nicht über den Standardport 179 läuft, erkennt Wireshark sie zunächst als reines TCP. Klickt ein TCP-Paket mit Rechtsklick an → **Decode As…** → Feld *Current* auf **BGP** setzen → OK. Jetzt zerlegt der Dissector die Nutzdaten.

> **Leitfrage:** Warum erkennt Wireshark ein Protokoll überhaupt am Port — und was bedeutet das für die Zuverlässigkeit dieser Erkennung?

```
________________________________________________________________

________________________________________________________________
```

---

## Aufgabe 2 — Die Nachrichtentypen kartieren

Scrollt durch den Mitschnitt. Die Spalte *Info* zeigt nach dem Decode-As den Nachrichtentyp.

> 🎓 **Beobachtungsaufgabe:** Notiert die Reihenfolge der ausgetauschten BGP-Nachrichten vom Verbindungsaufbau bis zum Sitzungsende. Welcher Typ kommt zuerst, welcher zuletzt?

```
1. ____________________   4. ____________________

2. ____________________   5. ____________________

3. ____________________   6. ____________________
```

> **Leitfrage:** Welche Aufgabe erfüllt jeder der vier Nachrichtentypen in der Session?

```
OPEN ........... _________________________________________________

UPDATE ......... _________________________________________________

KEEPALIVE ...... _________________________________________________

NOTIFICATION ... _________________________________________________
```

---

## Aufgabe 3 — Die OPEN-Nachricht sezieren

Wählt die erste **OPEN**-Nachricht aus und klappt im Detailbereich den Bereich *Border Gateway Protocol → OPEN Message* auf.

> **Leitfrage:** Tragt die folgenden Felder beider Peers ein.

```
                         Peer A            Peer B

BGP-Version ........  __________        __________

My Autonomous System  __________        __________

Hold Time (s) ......  __________        __________

BGP Identifier .....  __________        __________
```

> 🎓 **Reflexion:** In welchem Zahlenbereich liegen die beiden AS-Nummern — und was sagt euch das über ihre Verwendung (öffentlich vs. privat)?

```
________________________________________________________________
```

---

## Aufgabe 4 — Die UPDATE-Nachrichten sezieren

UPDATE-Nachrichten transportieren die eigentlichen Routing-Informationen. Sucht die UPDATE-Pakete und klappt *Path Attributes* sowie *Network Layer Reachability Information (NLRI)* bzw. *Withdrawn Routes* auf.

> **Leitfrage:** Welche IP-Präfixe werden **angekündigt** und welches Präfix wird später wieder **zurückgezogen**?

```
Angekündigt:  __________________________________________________

Zurückgezogen: _________________________________________________
```

> **Leitfrage:** Welche drei Pfad-Attribute enthält eine angekündigte Route und was beschreibt jedes?

```
ORIGIN ...... _________________________________________________

AS_PATH ..... _________________________________________________

NEXT_HOP .... _________________________________________________
```

> 🎓 **Beobachtungsaufgabe:** Der `AS_PATH` ist das Herzstück der BGP-Wegewahl. Was würdet ihr im `AS_PATH` erwarten, wenn eine Route über mehrere autonome Systeme gelaufen wäre?

```
________________________________________________________________
```

---

## Aufgabe 5 — KEEPALIVE und der Hold-Timer

> **Leitfrage:** Wie viele KEEPALIVE-Nachrichten sendet jeder Peer insgesamt, und in welchem zeitlichen Abstand (Spalte *Time*)?

```
Anzahl pro Peer: __________   Abstand: __________
```

> ℹ️ **Hintergrund:** In produktiven Netzen wird das KEEPALIVE-Intervall typischerweise auf **ein Drittel des Hold-Timers** gesetzt. Bei der in Aufgabe 3 abgelesenen Hold Time wäre das …

> **Leitfrage:** Was passiert mit der Session, wenn innerhalb der Hold Time **kein** KEEPALIVE (oder UPDATE) mehr eintrifft?

```
________________________________________________________________
```

---

## Aufgabe 6 — Das Sitzungsende

> **Leitfrage:** Welcher Nachrichtentyp beendet die Session, und welcher *Error Code / Subcode* steht darin? Was bedeutet er?

```
Typ: __________   Code/Subcode: __________

Bedeutung: _____________________________________________________
```

---

## Aufgabe 7 — Der forensische Blick

Stellt euch vor, ihr seht in einem echten Mitschnitt eine UPDATE-Nachricht, in der **AS65001** plötzlich ein Präfix ankündigt, das eigentlich zu **AS65002** gehört — mit einem kürzeren `AS_PATH` als das Original.

> 🎓 **Analyse:** Wie würden andere Router auf diese beiden konkurrierenden Ankündigungen reagieren? Wohin würde der Datenverkehr für dieses Präfix anschließend fließen?

```
________________________________________________________________

________________________________________________________________
```

> **Leitfrage:** Prüft eine empfangende BGP-Instanz irgendwo, **ob** der ankündigende Router das Präfix tatsächlich besitzen darf? Was bedeutet die Antwort für die Vertrauensannahme im Protokoll?

```
________________________________________________________________
```

---

## Reflexionsfragen (Transferbezug)

> **F1:** Das in Aufgabe 7 beschriebene Vorgehen — das Fälschen einer UPDATE-Nachricht, um fremden Datenverkehr an sich zu ziehen — hat einen feststehenden Fachbegriff. Wie lautet er?

```
________________________________________________________________
```

> **F2:** Recherchiert einen realen Vorfall, bei dem genau dieses Vorgehen großflächige Ausfälle oder Umleitungen verursacht hat. Was ist passiert?

```
________________________________________________________________

________________________________________________________________
```

> **F3:** Ordnet die Schwachstelle den Schutzzielen der CIA-Triade zu. Welche Ziele werden verletzt — und warum genau ermöglicht das Protokolldesign den Angriff?

```
________________________________________________________________

________________________________________________________________
```

> **F4:** Nennt mindestens drei technische oder organisatorische Gegenmaßnahmen, mit denen sich solche gefälschten Ankündigungen erkennen oder verhindern lassen.

```
________________________________________________________________

________________________________________________________________
```

> **F5:** Wo in eurem beruflichen Umfeld spielt die Vertrauenswürdigkeit von Routing-Informationen eine Rolle? Welche Abhängigkeit von „dem Internet drumherum" würdet ihr nach diesem Lab kritischer hinterfragen?

```
________________________________________________________________

________________________________________________________________
```

---

## Quick Reference

| Aktion | Vorgehen |
|---|---|
| Auf Loopback aufzeichnen | Interface `lo` / „Loopback" / `lo0` wählen |
| Verkehr filtern | `tcp.port == 17000` |
| Als BGP interpretieren | Rechtsklick → *Decode As…* → BGP |
| Nur einen Typ zeigen | `bgp.type == 1` (OPEN), `2` (UPDATE), `3` (NOTIFICATION), `4` (KEEPALIVE) |
| Echter BGP-Port | `179/tcp` (im Lab durch 17000 ersetzt) |
| AS-Nummer eines Updates | Detailbereich → *Path Attributes → AS_PATH* |

---

<details>
<summary>🧩 Abschluss-Quiz (erst nach den Aufgaben aufklappen)</summary>

**Welche Aussage über das Border Gateway Protocol ist korrekt?**

A) BGP signiert jede Routenankündigung kryptografisch, sodass gefälschte Updates abgewiesen werden.
B) BGP verlässt sich auf das Vertrauen zwischen Peers; eine empfangene Ankündigung wird standardmäßig nicht auf Eigentümerschaft geprüft.
C) KEEPALIVE-Nachrichten enthalten die vollständige Routing-Tabelle.
D) Eine NOTIFICATION baut die Session neu auf, ohne sie zu trennen.

**Lösung:** **B** — Genau diese fehlende Herkunftsprüfung ist die strukturelle Schwäche, die ihr in Aufgabe 7 hergeleitet habt. RPKI/ROA und Präfix-Filter setzen hier an.

</details>

---

*Lab 06 | Sichere Netzwerke | FOM Hochschule | SS 2026*
