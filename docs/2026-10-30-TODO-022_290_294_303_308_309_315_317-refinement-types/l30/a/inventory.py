"""元の読者群の検索を再生成する。新しい並置モジュールは別に公理監査する。"""
from pathlib import Path
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
NEW = {"CarrierFacts.lean", "CarrierFactsMeaning.lean", "LinearSyntax.lean", "LinearSound.lean",
       "CertificateKernelBind.lean", "EqCertificate.lean", "MeasureNonnegative.lean", "MeasureContracts.lean",
       "LogicKernelExamples.lean"}
PATTERNS = [r"assume", r"\bCaptureOk\b", r"\b(simp|simpa|unfold|dsimp)\b[^\n]*(Ctx\.facts\b|Ty\.assume\b)", r"facts|assume"]
EXPECTED = [(29, 141), (50, 220), (16, 25), (48, 485)]


def main():
    root = ROOT / "formal/Benitoite/Release/Refinement"
    report = []
    for pattern, expected in zip(PATTERNS, EXPECTED):
        rows = []
        for path in sorted(root.rglob("*.lean")):
            if path.name in NEW:
                continue
            declaration = "(先頭)"
            for number, line in enumerate(path.read_text().splitlines(), 1):
                match = re.match(r"\s*(?:(?:private|noncomputable|protected)\s+)*(?:theorem|def|inductive|structure|abbrev)\s+(\S+)", line)
                if match:
                    declaration = match[1]
                if re.search(pattern, line):
                    rows.append((str(path.relative_to(root)), number, declaration))
        count = len({r[0] for r in rows}), len(rows)
        assert count == expected, (pattern, count, expected)
        report.append({"pattern": pattern, "files": count[0], "lines": count[1], "rows": rows})
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
