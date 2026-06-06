#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bgp_traffic_generator.py
========================
Erzeugt eine vollständige, realistische BGP-Session über die lokale
Loopback-Schnittstelle, damit Studierende den Verkehr mit Wireshark
(Filter: tcp.port == 179) mitschneiden und analysieren können.

Didaktischer Bezug (Modul "Sichere Netzwerke", Routing / BGP):
  - OPEN .......... zeigt ASN beider Peers + BGP-Version (4)
  - UPDATE ........ kuendigt IP-Praefixe an UND zieht ein Praefix zurueck
  - KEEPALIVE ..... wird mehrfach gesendet (Frequenz zaehlbar)
  - NOTIFICATION .. beendet die Session sauber (Cease / Admin Shutdown)

Das Skript startet beide BGP-Peers selbst (Listener + Connector) auf
127.0.0.1, es ist also KEIN echter Router/Quagga/FRR noetig.

Mitschnitt:
  1) Wireshark starten, Interface "Loopback" (Linux: lo / "Loopback: lo",
     Windows: "Adapter for loopback traffic capture" via Npcap).
  2) Anzeigefilter setzen: tcp.port == 17000
  3) Dann dieses Skript ausführen.

Standard: Bindung an 127.0.0.1:17000 (hoher Port -> KEINE Adminrechte noetig).
  python3 bgp_traffic_generator.py
Da Port 17000 nicht der Well-Known-Port ist, in Wireshark einmalig
"Decode As..." -> BGP setzen, damit der Dissector greift.

Optional auf dem echten BGP-Port 179 (dann mit Adminrechten):
  Linux/macOS:  sudo python3 bgp_traffic_generator.py --port 179
  Windows:      Terminal als Administrator

Autor: erstellt für das Modul "Sichere Netzwerke" (FOM)
"""

import argparse
import socket
import struct
import sys
import threading
import time

# ---------------------------------------------------------------------------
# BGP-Konstanten (RFC 4271)
# ---------------------------------------------------------------------------
BGP_MARKER = b"\xff" * 16          # 16 Byte Marker, bei fehlender Auth alle 1en

# Nachrichtentypen
MSG_OPEN = 1
MSG_UPDATE = 2
MSG_NOTIFICATION = 3
MSG_KEEPALIVE = 4

MSG_NAMES = {1: "OPEN", 2: "UPDATE", 3: "NOTIFICATION", 4: "KEEPALIVE"}

# Path-Attribute-Flags
ATTR_TRANSITIVE = 0x40             # well-known, transitive
ATTR_OPTIONAL = 0x80
ATTR_EXT_LEN = 0x10

# Path-Attribute-Typen
ATTR_ORIGIN = 1
ATTR_AS_PATH = 2
ATTR_NEXT_HOP = 3

# ORIGIN-Werte
ORIGIN_IGP = 0

# AS_PATH-Segmenttypen
AS_SEQUENCE = 2

# NOTIFICATION: Error Codes / Subcodes
NOTIFY_CEASE = 6
CEASE_ADMIN_SHUTDOWN = 2


# ---------------------------------------------------------------------------
# Nachrichten-Builder
# ---------------------------------------------------------------------------
def bgp_message(msg_type: int, body: bytes) -> bytes:
    """Setzt einen vollstaendigen BGP-Frame (Header + Body) zusammen."""
    total_length = 19 + len(body)            # 16 Marker + 2 Length + 1 Type
    header = BGP_MARKER + struct.pack("!HB", total_length, msg_type)
    return header + body


def build_open(my_as: int, hold_time: int, bgp_id: str) -> bytes:
    """OPEN-Nachricht (Version 4)."""
    version = 4
    identifier = socket.inet_aton(bgp_id)
    opt_params = b""                          # keine optionalen Capabilities
    body = (
        struct.pack("!B", version)
        + struct.pack("!H", my_as)
        + struct.pack("!H", hold_time)
        + identifier
        + struct.pack("!B", len(opt_params))
        + opt_params
    )
    return bgp_message(MSG_OPEN, body)


def build_keepalive() -> bytes:
    """KEEPALIVE-Nachricht (nur Header, leerer Body)."""
    return bgp_message(MSG_KEEPALIVE, b"")


def _path_attribute(flags: int, type_code: int, value: bytes) -> bytes:
    """Kodiert ein einzelnes Path-Attribut."""
    if len(value) > 255 or (flags & ATTR_EXT_LEN):
        flags |= ATTR_EXT_LEN
        length = struct.pack("!H", len(value))
    else:
        length = struct.pack("!B", len(value))
    return struct.pack("!BB", flags, type_code) + length + value


def _encode_prefix(prefix: str, prefix_len: int) -> bytes:
    """Kodiert ein NLRI-Praefix: 1 Byte Laenge (in Bit) + gepackte Bytes."""
    num_octets = (prefix_len + 7) // 8
    packed = socket.inet_aton(prefix)[:num_octets]
    return struct.pack("!B", prefix_len) + packed


def build_update(announce, withdraw=None, as_path=None,
                 next_hop="0.0.0.0") -> bytes:
    """
    UPDATE-Nachricht.

    announce : Liste von (praefix, laenge), die angekuendigt werden
    withdraw : Liste von (praefix, laenge), die zurueckgezogen werden
    as_path  : Liste von ASN fuer das AS_PATH-Attribut
    next_hop : NEXT_HOP-Adresse
    """
    withdraw = withdraw or []
    as_path = as_path or []

    # --- Withdrawn Routes ---------------------------------------------------
    withdrawn_bytes = b"".join(_encode_prefix(p, l) for p, l in withdraw)

    # --- Path Attributes (nur wenn etwas angekuendigt wird) -----------------
    path_attr_bytes = b""
    nlri_bytes = b""
    if announce:
        # ORIGIN = IGP
        origin = _path_attribute(ATTR_TRANSITIVE, ATTR_ORIGIN,
                                 struct.pack("!B", ORIGIN_IGP))
        # AS_PATH = ein AS_SEQUENCE-Segment
        seg = struct.pack("!BB", AS_SEQUENCE, len(as_path))
        seg += b"".join(struct.pack("!H", a) for a in as_path)
        aspath = _path_attribute(ATTR_TRANSITIVE, ATTR_AS_PATH, seg)
        # NEXT_HOP
        nexthop = _path_attribute(ATTR_TRANSITIVE, ATTR_NEXT_HOP,
                                  socket.inet_aton(next_hop))
        path_attr_bytes = origin + aspath + nexthop
        nlri_bytes = b"".join(_encode_prefix(p, l) for p, l in announce)

    body = (
        struct.pack("!H", len(withdrawn_bytes)) + withdrawn_bytes
        + struct.pack("!H", len(path_attr_bytes)) + path_attr_bytes
        + nlri_bytes
    )
    return bgp_message(MSG_UPDATE, body)


def build_notification(code: int, subcode: int, data: bytes = b"") -> bytes:
    """NOTIFICATION-Nachricht zum Beenden der Session."""
    body = struct.pack("!BB", code, subcode) + data
    return bgp_message(MSG_NOTIFICATION, body)


# ---------------------------------------------------------------------------
# Empfangshilfen
# ---------------------------------------------------------------------------
def _recv_exact(sock: socket.socket, n: int):
    """Liest exakt n Bytes oder gibt None bei Verbindungsende zurueck."""
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def recv_bgp_message(sock: socket.socket):
    """Liest genau eine BGP-Nachricht. Rueckgabe: (typ, body) oder None."""
    header = _recv_exact(sock, 19)
    if header is None:
        return None
    length = struct.unpack("!H", header[16:18])[0]
    msg_type = header[18]
    body = b""
    if length > 19:
        body = _recv_exact(sock, length - 19)
        if body is None:
            return None
    return msg_type, body


# ---------------------------------------------------------------------------
# Peer-Logik
# ---------------------------------------------------------------------------
class Peer:
    """Spielt einen BGP-Sprecher (Sender + Empfaenger) auf einer Verbindung."""

    def __init__(self, name, my_as, bgp_id, announce, withdraw,
                 keepalives, hold_time, interval):
        self.name = name
        self.my_as = my_as
        self.bgp_id = bgp_id
        self.announce = announce
        self.withdraw = withdraw
        self.keepalives = keepalives
        self.hold_time = hold_time
        self.interval = interval

    def log(self, direction, text):
        arrow = "-->" if direction == "tx" else "<--"
        print(f"  [{self.name:<7}] {arrow} {text}")

    def _reader(self, sock, stop_event):
        """Liest eingehende Nachrichten und protokolliert sie."""
        while not stop_event.is_set():
            try:
                msg = recv_bgp_message(sock)
            except OSError:
                break
            if msg is None:
                break
            msg_type, _ = msg
            self.log("rx", MSG_NAMES.get(msg_type, f"TYP {msg_type}"))
            if msg_type == MSG_NOTIFICATION:
                break

    def run_session(self, sock):
        """Fuehrt die komplette BGP-Konversation aus."""
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        stop_event = threading.Event()
        reader = threading.Thread(target=self._reader,
                                  args=(sock, stop_event), daemon=True)
        reader.start()

        # 1) OPEN
        sock.sendall(build_open(self.my_as, self.hold_time, self.bgp_id))
        self.log("tx", f"OPEN (AS{self.my_as}, Version 4, ID {self.bgp_id})")
        time.sleep(self.interval)

        # 2) KEEPALIVE zur Bestaetigung des OPEN
        sock.sendall(build_keepalive())
        self.log("tx", "KEEPALIVE (OPEN bestaetigt)")
        time.sleep(self.interval)

        # 3) UPDATE: Praefixe ankuendigen
        if self.announce:
            sock.sendall(build_update(
                announce=self.announce,
                as_path=[self.my_as],
                next_hop=self.bgp_id,
            ))
            pretty = ", ".join(f"{p}/{l}" for p, l in self.announce)
            self.log("tx", f"UPDATE announce: {pretty}")
            time.sleep(self.interval)

        # 4) UPDATE: Praefix zurueckziehen
        if self.withdraw:
            sock.sendall(build_update(announce=[], withdraw=self.withdraw))
            pretty = ", ".join(f"{p}/{l}" for p, l in self.withdraw)
            self.log("tx", f"UPDATE withdraw: {pretty}")
            time.sleep(self.interval)

        # 5) Mehrere KEEPALIVEs (Frequenz fuer die Studierenden zaehlbar)
        for i in range(self.keepalives):
            sock.sendall(build_keepalive())
            self.log("tx", f"KEEPALIVE ({i + 1}/{self.keepalives})")
            time.sleep(self.interval)

        stop_event.set()
        return sock


# ---------------------------------------------------------------------------
# Server-Seite (Peer B, lauschend)
# ---------------------------------------------------------------------------
def run_server(host, port, ready_event, done_event):
    peer_b = Peer(
        name="AS65002", my_as=65002, bgp_id="10.0.0.2",
        announce=[("203.0.113.0", 24)],
        withdraw=[],
        keepalives=3, hold_time=180, interval=0.6,
    )
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((host, port))
    srv.listen(1)
    ready_event.set()
    conn, addr = srv.accept()
    print(f"  [AS65002] TCP-Verbindung von {addr[0]}:{addr[1]} akzeptiert")
    with conn:
        peer_b.run_session(conn)
        # Server schliesst nach Erhalt der NOTIFICATION
        time.sleep(0.5)
    srv.close()
    done_event.set()


# ---------------------------------------------------------------------------
# Client-Seite (Peer A, verbindend) + Sitzungsabschluss
# ---------------------------------------------------------------------------
def run_client(host, port):
    peer_a = Peer(
        name="AS65001", my_as=65001, bgp_id="10.0.0.1",
        announce=[("192.0.2.0", 24), ("198.51.100.0", 24)],
        withdraw=[("198.51.100.0", 24)],     # spaeter wieder zurueckziehen
        keepalives=3, hold_time=180, interval=0.6,
    )
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((host, port))
    print(f"  [AS65001] TCP-Verbindung zu {host}:{port} aufgebaut")
    with sock:
        peer_a.run_session(sock)
        # 6) NOTIFICATION: Session administrativ beenden
        sock.sendall(build_notification(NOTIFY_CEASE, CEASE_ADMIN_SHUTDOWN))
        peer_a.log("tx", "NOTIFICATION (Cease / Administrative Shutdown)")
        time.sleep(0.5)


# ---------------------------------------------------------------------------
# Hauptprogramm
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Erzeugt eine BGP-Session ueber Loopback fuer Wireshark.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Beispiele:\n"
            "  python3 bgp_traffic_generator.py\n"
            "  python3 bgp_traffic_generator.py --port 179   (mit sudo/Admin)\n"
            "  python3 bgp_traffic_generator.py --loops 3\n"
        ),
    )
    parser.add_argument("--host", default="127.0.0.1",
                        help="Loopback-Adresse (Standard: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=17000,
                        help="TCP-Port (Standard: 17000, keine Adminrechte noetig)")
    parser.add_argument("--loops", type=int, default=1,
                        help="Anzahl kompletter Sessions hintereinander")
    parser.add_argument("--pause", type=float, default=2.0,
                        help="Pause zwischen den Sessions in Sekunden")
    args = parser.parse_args()

    print("=" * 64)
    print(" BGP-Traffic-Generator  |  Modul Sichere Netzwerke")
    print("=" * 64)
    print(f" Host:  {args.host}")
    print(f" Port:  {args.port}")
    print(f" Wireshark-Filter:  tcp.port == {args.port}")
    if args.port < 1024:
        print(" Hinweis: Port < 1024 -> mit Adminrechten/sudo starten.")
    else:
        print(" Hinweis: In Wireshark ggf. 'Decode As...' -> BGP setzen.")
    print("-" * 64)

    for n in range(1, args.loops + 1):
        if args.loops > 1:
            print(f"\n>>> Session {n}/{args.loops}")
        ready = threading.Event()
        done = threading.Event()
        server_thread = threading.Thread(
            target=run_server,
            args=(args.host, args.port, ready, done),
            daemon=True,
        )
        server_thread.start()

        if not ready.wait(timeout=5):
            print("FEHLER: Server konnte nicht starten.", file=sys.stderr)
            sys.exit(1)

        try:
            run_client(args.host, args.port)
        except PermissionError:
            print("\nFEHLER: Keine Berechtigung fuer Port "
                  f"{args.port}.", file=sys.stderr)
            print("Loesung: mit sudo/Admin starten oder Default-Port 17000 "
                  "nutzen (ohne --port).", file=sys.stderr)
            sys.exit(1)
        except ConnectionRefusedError:
            print("\nFEHLER: Verbindung abgelehnt.", file=sys.stderr)
            sys.exit(1)

        done.wait(timeout=5)
        server_thread.join(timeout=2)
        print("  [Session beendet]")
        if n < args.loops:
            time.sleep(args.pause)

    print("-" * 64)
    print(" Fertig. Mitschnitt in Wireshark stoppen und analysieren.")
    print("=" * 64)


if __name__ == "__main__":
    main()
