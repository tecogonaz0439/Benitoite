"""同じ SecTrust 対照を再実行し、公開証明書と拡張設定を根拠入力として保存する。"""
import datetime
import hashlib
import http.server
import json
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
LABEL = "sectrust-aia-preserved"
INPUTS = HERE / LABEL
ROOT = HERE.parents[2]
TARGET = ROOT / "target" / "r30.4"
TARGET.mkdir(exist_ok=True)
STARTED = time.monotonic()
events = []
body = b""


class Receiver(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        assert self.client_address[0] == "127.0.0.1"
        events.append(dict(path=self.path, host=self.headers.get("Host"),
                           user_agent=self.headers.get("User-Agent")))
        self.send_response(200)
        self.send_header("Content-Type", "application/pkix-cert")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def run(command, cwd, timeout=20):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError((command[0:3], result.returncode, result.stdout, result.stderr))
    return result.stdout + result.stderr


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Receiver)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix="sectrust-aia-", dir=TARGET) as temporary:
        temp = Path(temporary)
        ident = uuid.uuid4().hex
        port = server.server_port
        aia_url = f"http://127.0.0.1:{port}/intermediate-{ident}.der"
        (temp / "intermediate.cnf").write_text("""basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
""")
        (temp / "leaf.cnf").write_text(f"""basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
authorityInfoAccess=caIssuers;URI:{aia_url}
""")
        openssl = "/usr/bin/openssl"
        run([openssl, "req", "-new", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "2",
             "-subj", f"/CN=R30.4 AIA root {ident}", "-keyout", "root.key", "-out", "root.pem"], temp)
        for name, issuer, extension in [("intermediate", "root", "intermediate.cnf"),
                                         ("leaf", "intermediate", "leaf.cnf")]:
            run([openssl, "req", "-new", "-newkey", "rsa:2048", "-nodes", "-subj",
                 f"/CN=R30.4 {name} {ident}", "-keyout", f"{name}.key", "-out", f"{name}.csr"], temp)
            run([openssl, "x509", "-req", "-in", f"{name}.csr", "-CA", f"{issuer}.pem",
                 "-CAkey", f"{issuer}.key", "-CAcreateserial", "-days", "2", "-sha256",
                 "-extfile", extension, "-out", f"{name}.pem"], temp)
        for name in ["root", "intermediate", "leaf"]:
            run([openssl, "x509", "-in", f"{name}.pem", "-outform", "DER", "-out", f"{name}.der"], temp)
        # レビューに要る公開入力だけを残し、秘密鍵は一時領域から出さない。
        INPUTS.mkdir(exist_ok=False)
        for name in ["root.der", "intermediate.der", "leaf.der", "intermediate.cnf", "leaf.cnf"]:
            (INPUTS / name).write_bytes((temp / name).read_bytes())
        body = (temp / "intermediate.der").read_bytes()
        run(["xcrun", "clang", "-framework", "Security", "-framework", "CoreFoundation",
             str(HERE / "sectrust-aia.c"), "-o", str(temp / "sectrust-aia")], temp)
        observations = []
        for mode in ["disabled", "default"]:
            initial = len(events)
            t0 = time.monotonic()
            output = run([str(temp / "sectrust-aia"), str(temp / "leaf.der"),
                          str(temp / "root.der"), mode], temp)
            observations.append(dict(mode=mode, output=output, seconds=time.monotonic() - t0,
                                     aia_connections=events[initial:]))
        record = dict(recorded_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                      seconds=time.monotonic() - STARTED, aia_url=aia_url,
                      constraints="explicit in-memory root only; no OS trust store changes; certificate URLs are loopback only",
                      observations=observations,
                      inputs={name: hashlib.sha256((temp / name).read_bytes()).hexdigest()
                              for name in ["root.der", "intermediate.der", "leaf.der", "intermediate.cnf", "leaf.cnf"]},
                      preserved_inputs=INPUTS.name,
                      temporary_removed=True)
        (HERE / f"{LABEL}.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps(record, ensure_ascii=False, indent=2))
finally:
    server.shutdown()
    server.server_close()
    thread.join()
