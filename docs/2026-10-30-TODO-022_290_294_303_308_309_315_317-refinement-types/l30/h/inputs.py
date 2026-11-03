"""本番と写し・設定の入力ハッシュを保存する。生の全ソース一覧はtmpへ置く。"""
from pathlib import Path
import argparse
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]

def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
args.tmp.mkdir(parents=True, exist_ok=True)
changed = json.loads((HERE / "source-changes.json").read_text())["changed"]
paths = changed + ["docs/design/01-spec/01-12-core-calculus.md",
                   "docs/design/07-quality/07-04-formal-semantics.md",
                   "formal/lakefile.toml", "formal/lean-toolchain", "formal/lake-manifest.json",
                   "rust-toolchain.toml", "Cargo.lock", "fuzz/Cargo.lock", "deny.toml"]
files = {name: digest((ROOT / name).read_bytes()) for name in sorted(set(paths))}
lean = sorted(p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.relative_to(ROOT / "formal").parts)
raw = (json.dumps({str(p.relative_to(ROOT)): digest(p.read_bytes()) for p in lean}, sort_keys=True, indent=2) + "\n").encode()
(args.tmp / "all-sources.json").write_bytes(raw)
summary = {"base": "82a7f626e38b6e861f896ec5033e08e6acdfa435", "files": files,
           "all_formal_sources": {"count": len(lean), **digest(raw)},
           "memory_MiB": 12288, "formal_RSS": "未取得（計画上の非採取）"}
(HERE / "inputs.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"files": len(files), "all_sources": len(lean), "source_list": digest(raw)}))
