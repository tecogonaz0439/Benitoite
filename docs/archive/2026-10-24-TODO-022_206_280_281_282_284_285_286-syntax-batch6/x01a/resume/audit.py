"""X01a の入力・保護対象・記録の伏せ方を読み取りで点検する。"""
import hashlib
import json
import re
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "0341dfe350598fb3626137d4d47121301acea382"
FILES = [
    "crates/benitoite/src/typeck/interval/mod.rs",
    "crates/benitoite/src/typeck/interval/observation.rs",
    "crates/benitoite/src/typeck/mod.rs",
    "crates/benitoite/src/typeck/decls.rs",
    "crates/benitoite/tests/desugar_export/exchange.rs",
    "crates/benitoite/tests/desugar_export/interval.rs",
    "crates/benitoite/tests/desugar_export/interval/source.rs",
    "docs/design/02-impl/02-05-typechecker.md",
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    stage = sys.argv[1]
    protected = ["formal", "crates/benitoite/testdata/interval-budget", "crates/benitoite/tests/call_allocations.rs",
                 "Cargo.toml", "crates/benitoite/Cargo.toml", "Cargo.lock", "fuzz/Cargo.toml", "fuzz/Cargo.lock", "deny.toml", "rust-toolchain.toml"]
    changed = subprocess.check_output(["git", "diff", "--name-only", BASE, "--"] + protected, cwd=ROOT, text=True)
    assert not changed, changed
    hashes = {path: digest(ROOT / path) for path in FILES}
    signatures = []
    for path, name in [("crates/benitoite/src/typeck/mod.rs", "typecheck"),
                       ("crates/benitoite/src/typeck/decls.rs", "check"),
                       ("crates/benitoite/src/typeck/interval/mod.rs", "analyze")]:
        old = subprocess.check_output(["git", "show", BASE+":"+path], cwd=ROOT, text=True)
        new = (ROOT/path).read_text()
        def signature(text):
            start = text.index("fn "+name+"(")
            return text[start:text.index("{",start)]
        assert signature(old) == signature(new), name
        signatures.append(name)
    observer = (ROOT/"crates/benitoite/src/typeck/interval/observation.rs").read_text()
    assert not re.search(r"thread_local!|static mut|OnceLock|Atomic", observer)
    allowed = set(FILES)
    record_dir = str(HERE.parent.relative_to(ROOT))+"/"
    tracked = subprocess.check_output(["git","diff","--name-only",BASE],cwd=ROOT,text=True).splitlines()
    untracked = subprocess.check_output(["git","ls-files","--others","--exclude-standard"],cwd=ROOT,text=True).splitlines()
    assert all(path in allowed or path.startswith(record_dir) for path in tracked+untracked)
    if not stage.startswith("before"):
        assert hashes == json.loads((HERE / "inputs-before-scoped.json").read_text())["sha256"]
    leaked = []
    for path in HERE.rglob("*"):
        if path.is_file() and path.suffix in [".py", ".md", ".json", ".log"]:
            content = path.read_text()
            if str(ROOT) in content or str(Path.home()) in content:
                leaked.append(str(path.relative_to(HERE)))
    assert not leaked, leaked
    subprocess.run(["git", "diff", "--check"], cwd=ROOT, check=True)
    record = {"base": BASE, "sha256": hashes, "protectedDiff": [], "pathLeaks": leaked, "existingSignaturesUnchanged": signatures, "observerGlobalState": False}
    (HERE / ("inputs-"+stage+".json")).write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(dict(stage=stage, files=len(hashes), protectedDiff=changed, pathLeaks=leaked)))

if __name__ == "__main__":
    main()
