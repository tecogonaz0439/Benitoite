"""Q12 の追加調査。ソースを変更せず、宣言とパターンの候補を JSON に出す。"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location("inventory", HERE / "inventory.py")
inv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inv)
TYPES = ["IOErrorKind", "NetworkErrorKind", "Json.ParseError", "Csv.ParseError"]


def main():
    previous = json.loads((HERE / "inventory.json").read_text())
    declarations = []
    for path in sorted((ROOT / "crates/benitoite/src/prelude/stdlib").rglob("*.bnt")):
        source = path.read_text()
        for m in re.finditer(r"(?m)^public (data|record) (\w+)", source):
            declarations.append(dict(path=str(path.relative_to(ROOT)), line=source.count("\n", 0, m.start()) + 1,
                                     kind=m[1], name=m[2]))
    # 全入力を再抽出する。前回の match 候補に加え、構築・getter とパターンの区別を人が確認する。
    occurrences = []
    hashes = {}
    for path in sorted(previous["source_sha256"]):
        data = (ROOT / path).read_bytes()
        hashes[path] = hashlib.sha256(data).hexdigest()
        if hashes[path] != previous["source_sha256"][path]:
            raise SystemExit(f"stale inventory source: {path}; refresh the baseline before counting")
        for index, unit in enumerate(inv.snippets(path, data)):
            ts = inv.tokens(unit.source)
            for i, (word, at) in enumerate(ts):
                if word not in {"IOErrorKind", "NetworkErrorKind", "ParseError"}:
                    continue
                byte = len(unit.source[:at].encode())
                host = unit.boundaries[byte]
                occurrences.append(dict(path=path, snippet=index, line=data[:host].count(b"\n") + 1,
                                        word=word, context=" ".join(w for w, _ in ts[max(0, i-5):i+14]),
                                        hold=unit.hold))
    matches = [m for m in previous["matches"] if any(w in {"IOErrorKind", "NetworkErrorKind", "ParseError"}
                for arm in m["arms"] for w in arm)]
    print(json.dumps(dict(head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
                         method="previous inventory hosts re-extracted; lexical candidates manually reviewed; not a typed coverage proof",
                         target_types=TYPES, public_data_and_records=declarations, matches=matches,
                         occurrences=occurrences, source_sha256=hashes), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
