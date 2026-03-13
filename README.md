# Lab 01: ARP-Spoofing mit ContainerLab
Das Szenario spielt in einem einfachen Layer-2-Netzwerk, das ein typisches Büro- oder Campusnetz simuliert. Alice ist ein normaler Rechner, der mit einem Gateway/Router kommuniziert (z. B. HTTP-Anfragen ins Internet). Mallory ist der Angreifer im gleichen Netz — genau wie früher die Kali-VM, nur jetzt als Container.

## ContainerLab-Topologie
````
┌─────────────────────────────────────────┐
│          eth-bridge (L2-Segment)        │
│            10.0.0.0/24                  │
└──────┬──────────────┬───────────┬───────┘
       │              │           │
  ┌────┴───┐     ┌────┴───┐   ┌───┴────┐
  │ alice  │     │gateway │   │mallory │
  │victim  │     │ router │   │Angreif.│
  │Ubuntu  │     │ Alpine │   │ Kali   │
  │.10     │     │ .1     │   │ .99    │
  └────────┘     └────────┘   └────────┘
````

## Aufgabenstruktur
### Aufgabe 1 - Topogie starten und verstehen 
Die Studierenden starten das Lab mit containerlab 
````
deploy -t lab-02-arp-spoofing.clab.yml 
````
und prüfen zunächst mit arp -n auf allen Knoten den ARP-Cache. 
Sie dokumentieren, welche MAC-Adressen für welche IPs eingetragen sind — 
das ist der Ausgangszustand vor dem Angriff.