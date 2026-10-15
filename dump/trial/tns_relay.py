# tns_relay.py — TRIAL: relay localhost:15210 to the MFRI Oracle listener, logging each TNS packet's direction,
# type and length, never data, only the text of a refusal or redirect (decision 106). Point a client at
# 127.0.0.1:15210; argument: seconds to wait for a client. oracle_scanner 0.4.0 reached the login through it and
# timed out without it.
import socket, threading, sys, time
TYPES = {1:"CONNECT",2:"ACCEPT",3:"ACK",4:"REFUSE",5:"REDIRECT",6:"DATA",7:"NULL",9:"ABORT",11:"RESEND",12:"MARKER",13:"ATTENTION",14:"CONTROL"}
t0 = time.time()
def pump(src, dst, tag):
    try:
        while True:
            b = src.recv(65536)
            if not b: print(f"{time.time()-t0:6.2f} {tag} closed", flush=True); break
            kind = TYPES.get(b[4], b[4]) if len(b) > 4 else "?"
            print(f"{time.time()-t0:6.2f} {tag} {len(b):6d} bytes, first packet type {kind}", flush=True)
            if kind == "REFUSE" or kind == "REDIRECT":
                print("        text:", b[8:].decode("latin-1", "replace")[:300], flush=True)
            dst.sendall(b)
    except Exception as e:
        print(f"{time.time()-t0:6.2f} {tag} {e}", flush=True)
    for s in (src, dst):
        try: s.shutdown(socket.SHUT_RDWR)
        except Exception: pass
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 15210)); srv.listen(5)
srv.settimeout(float(sys.argv[1]) if len(sys.argv) > 1 else 60)
try:
    while True:
        c, _ = srv.accept()
        print(f"{time.time()-t0:6.2f} client connected", flush=True)
        u = socket.create_connection(("hafmey.hafro.is", 1521))
        threading.Thread(target=pump, args=(c, u, "client->server"), daemon=True).start()
        threading.Thread(target=pump, args=(u, c, "server->client"), daemon=True).start()
except socket.timeout:
    pass
