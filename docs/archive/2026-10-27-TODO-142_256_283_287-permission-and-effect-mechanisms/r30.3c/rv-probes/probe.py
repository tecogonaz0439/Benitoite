import socket
def listen(fam, addr, v6only=None):
    s = socket.socket(fam, socket.SOCK_STREAM)
    if v6only is not None:
        s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, v6only)
    s.bind((addr, 0)); s.listen(4); s.settimeout(0.5)
    return s
def try_connect(dst, port):
    c = socket.socket(socket.AF_INET6, socket.SOCK_STREAM); c.settimeout(1)
    try:
        c.connect((dst, port)); return "connected"
    except OSError as e:
        return f"error {e.errno} {e.strerror}"
    finally:
        c.close()
targets = ["::ffff:127.0.0.1", "::127.0.0.1", "::7f00:1", "64:ff9b::127.0.0.1", "::ffff:0:127.0.0.1", "::1"]
for label, srv in [("v4 127.0.0.1", lambda: listen(socket.AF_INET, "127.0.0.1")),
                   ("v4 0.0.0.0", lambda: listen(socket.AF_INET, "0.0.0.0")),
                   ("v6 :: dual", lambda: listen(socket.AF_INET6, "::", 0))]:
    s = srv(); port = s.getsockname()[1]
    for t in targets:
        r = try_connect(t, port)
        acc = ""
        if r == "connected":
            try:
                a, peer = s.accept(); acc = f" peer={peer[0]}"; a.close()
            except socket.timeout:
                acc = " (no accept)"
        print(f"{label:14} -> {t:22} {r}{acc}")
    s.close()
