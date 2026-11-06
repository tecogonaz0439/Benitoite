#!/usr/bin/env python3
"""確認用入力の必須宣言を再生成し、検査前後の入力を照合する。Git は呼ばない。"""
import argparse
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parents[1]
PREFIX = "Benitoite.Release.Refinement.CheckErasureBoundary."


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def names():
    source = (HERE / "obstruction.lean").read_text()
    return [PREFIX + n for n in re.findall(r"^(?:def|theorem) ([A-Za-z_][A-Za-z_0-9]*)", source, re.M)]


def inputs():
    paths = [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    paths += [ROOT / "formal" / n for n in ("lakefile.toml", "lake-manifest.json", "lean-toolchain")]
    paths += [p for p in CHANGE.rglob("*") if p.is_file() and HERE not in p.parents]
    paths += [ROOT / "docs/design/01-spec/01-12-core-calculus.md",
              ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(set(paths)) if p.is_file()}


def fingerprint(items):
    return hashlib.sha256(json.dumps(items, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def baseline():
    index = json.loads((HERE / "baseline-index.json").read_text())
    items = {}
    for part in index["parts"]:
        path = HERE / part["name"]
        assert digest(path) == part["digest"], part["name"]
        items.update(json.loads(path.read_text()))
    assert len(items) == index["count"]
    assert fingerprint(items) == index["sha256"]
    return items


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    write(HERE / "required-names.json", names())
    # 本番へ追加するモジュールはない。確認用入力は audit-tail と結合して独立に検査する。
    write(HERE / "audit-modules.json", [])
    if args.capture:
        assert not (HERE / "baseline-index.json").exists(), "既存の基準は上書きしない"
        items = inputs()
        entries = list(items.items())
        parts = []
        for i in range(0, len(entries), 200):
            name = "baseline-inputs-%02d.json" % (i // 200 + 1)
            path = HERE / name
            write(path, dict(entries[i:i + 200]))
            assert path.stat().st_size <= 100_000
            parts.append({"name": name, "digest": digest(path)})
        write(HERE / "baseline-index.json", {"count": len(items), "sha256": fingerprint(items), "parts": parts})
    else:
        assert inputs() == baseline(), "保護した入力に差がある"
    print(json.dumps({"required": len(names()), "production_modules_added": 0}))


if __name__ == "__main__":
    main()
