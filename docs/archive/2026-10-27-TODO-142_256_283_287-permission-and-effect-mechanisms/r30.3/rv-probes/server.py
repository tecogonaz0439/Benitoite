import socket, threading, sys
def serve(fam, addr, port, tag):
    s = socket.socket(fam, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if fam == socket.AF_INET6:
        s.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
    s.bind((addr, port)); s.listen(16)
    while True:
        c, peer = s.accept()
        data = b''
        c.settimeout(2)
        try:
            while b'\r\n\r\n' not in data:
                d = c.recv(4096)
                if not d: break
                data += d
        except Exception: pass
        head = data.split(b'\r\n\r\n')[0].decode('latin1')
        lines = head.split('\r\n')
        host = [l for l in lines[1:] if l.lower().startswith('host:')]
        body = f"{tag}:{port} {lines[0]} {host}".encode()
        print(body.decode(), flush=True)
        c.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % len(body) + body)
        c.close()
for p in (18081, 18082):
    threading.Thread(target=serve, args=(socket.AF_INET, '127.0.0.1', p, 'v4'), daemon=True).start()
    threading.Thread(target=serve, args=(socket.AF_INET6, '::1', p, 'v6'), daemon=True).start()
threading.Event().wait()
