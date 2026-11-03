"""入力のハッシュ、変更範囲、公開署名を再生成する。"""
from pathlib import Path
import argparse
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULES = ["MeasureContracts", "NumericContracts", "KeyContracts", "PreparedLeaf", "CertificateKeys",
           "NormalResultLeaves", "ObservationContractsExamples", "PreparedLeafExamples",
           "FieldObservationExamples", "PreparedSortExamples"]


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, required=True,
                        help="開始時に控えた形式化のソースの相対名からSHA-256へのJSON")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    old = json.loads(args.baseline.read_text())
    now = {str(p.relative_to(ROOT)): digest(p)["sha256"]
           for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts}
    changed = sorted(p for p in old if now.get(p) != old[p])
    added = sorted(set(now) - set(old))
    original_release = [p for p in old if p.startswith("formal/Benitoite/Release/")
                        and not p.startswith("formal/Benitoite/Release/Refinement/")]
    assert all(now[p] == old[p] for p in original_release)
    assert changed == ["formal/Benitoite.lean", "formal/Benitoite/Release/Refinement/MeasureContracts.lean"]
    raw = args.tmp / "source-hashes.json"
    raw.write_text(json.dumps(dict(sorted(now.items())), indent=2) + "\n")
    files = ["formal/Benitoite.lean", "formal/lakefile.toml", "formal/lean-toolchain",
             "docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]
    files += ["formal/Benitoite/Release/Refinement/" + m + ".lean" for m in MODULES]
    files += [str((HERE / p).relative_to(ROOT)) for p in ["audit.lean", "audit.py", "handoff.lean"]]
    (HERE / "inputs.json").write_text(json.dumps({
        "base": "65677215c04e632a397126f97fbb442ec6b0108c", "changed_original_lean": changed,
        "added_lean": added, "all_lean_count": len(now), "all_lean_list": digest(raw),
        "start_lean_count": len(old), "start_lean_list": digest(args.baseline),
        "unchanged_original_lean": len(old) - len(changed),
        "unchanged_original_release": len(original_release),
        "files": {p: digest(ROOT / p) for p in files}}, indent=2) + "\n")
    headings = ["# 群 J・K の完全署名\n",
                "名前空間は `Benitoite.Release.Refinement`。NumericContracts、NormalResultLeaves と適用例はファイル名と同名の下位名前空間である。群 A〜I の署名・構成子は不変である。公開の S05 四入口は固定した署名をそのまま実装した。再開1でbyte_representedをbyte_and_u16_representedへ改名し、AllKeysCheckedのrefuteの条件を実際の平坦化した仮定の鍵列に強めた。S05四入口の署名は不変である。以下は本番から抽出した署名である。有限構造の構成子は省略しない。\n",
                "数学の整数は Int、七整数の幅は既存 IntKind、Float の二幅は既存の bits を読む。保存幅128やstepsの値を固定する新しい前提はない。\n"]
    for module in MODULES:
        src = (ROOT / "formal/Benitoite/Release/Refinement" / (module + ".lean")).read_text()
        matches = list(re.finditer(r"(?m)^\s*(?:(?:private|noncomputable)\s+)*(?:theorem|def|inductive)\s+[A-Za-z][^\n]*", src))
        sigs = []
        for i, match in enumerate(matches):
            chunk = src[match.start():matches[i + 1].start() if i + 1 < len(matches) else len(src)].strip()
            chunk = chunk.split("/--")[0].split("/-!")[0].strip()
            body = re.search(r":=(?:[ \t]*by\b|[ \t]*\n)", chunk)
            if body:
                chunk = chunk[:body.start()].rstrip()
            else:
                chunk = re.sub(r"(?m)^end.*$", "", chunk).strip()
            sigs.append(chunk)
        headings.append("## " + module + "\n\n```lean\n" + "\n\n".join(sigs) + "\n```\n")
    (HERE / "signatures.md").write_text("\n".join(headings))
    for file in HERE.iterdir():
        if file.is_file():
            assert file.stat().st_size <= 100000, file.name
    print(json.dumps({"changed": len(changed), "added": len(added), "all_lean": len(now),
                      "old_release_unchanged": len(original_release)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
