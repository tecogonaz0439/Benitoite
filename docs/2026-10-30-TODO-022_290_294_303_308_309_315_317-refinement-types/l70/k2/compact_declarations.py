"""run_check.py が書く宣言の型の写し（declarations*.md）を、件数・大きさ・SHA-256 と例・対照・反例の名前の要約へ置き換える。

群の記録を小さく保つため、写しの全体は改造の外（<tmp>）へ移す。run_check.py axioms を実行し直した後に、続けて実行する。
"""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
PREFIXES = ("Benitoite.Release.Refinement.Surface.FieldProjectionExamples.",
            "Benitoite.Release.Refinement.Surface.FieldCheckerExamples.",
            "Benitoite.Release.Refinement.K2Obstruction.")


def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    tmp = parser.parse_args().tmp
    tmp.mkdir(parents=True, exist_ok=True)
    audit = json.loads((HERE / "audit-summary.json").read_text())
    text = ""
    for name, recorded in audit["declarations"].items():
        data = (HERE / name).read_bytes()
        assert digest(data) == recorded, name
        text += data.decode()
        shutil.copy(HERE / name, tmp / name)
    names = re.findall(r"^## (\S+)$", text, re.M)
    assert len(names) == audit["signature_count"]
    summary = {
        "signature_count": len(names),
        "full_copy": {"files": len(audit["declarations"]), **digest(text.encode())},
        "parts": audit["declarations"],
        "example_names": sorted(n for n in names if n.startswith(PREFIXES)),
    }
    out = json.dumps(summary, ensure_ascii=False, indent=1) + "\n"
    (HERE / "declarations-summary.json").write_text(out)
    for name in audit["declarations"]:
        (HERE / name).unlink()
    audit["declarations"] = {"declarations-summary.json": digest(out.encode())}
    (HERE / "audit-summary.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
