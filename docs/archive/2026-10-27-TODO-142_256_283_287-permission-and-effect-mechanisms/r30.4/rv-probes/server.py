import socket,sys,threading,time
ports=[int(p) for p in sys.argv[1:]]
log=open('server.log','a')
def serve(p):
    s=socket.socket(socket.AF_INET6 if p>=30000 and False else socket.AF_INET); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    s.bind(('127.0.0.1',p)); s.listen(16)
    while True:
        c,a=s.accept(); c.settimeout(2)
        data=b''
        try:
            while b'\r\n\r\n' not in data:
                d=c.recv(4096)
                if not d: break
                data+=d
        except Exception: pass
        log.write(f'--- port {p}\n{data.decode(errors="replace")}\n'); log.flush()
        c.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok'); c.close()
for p in ports: threading.Thread(target=serve,args=(p,),daemon=True).start()
time.sleep(600)
