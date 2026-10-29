"""現在のソースにある要求の表現への明示的な参照を数える。破損数ではない。"""
from pathlib import Path
import re

here = Path(__file__).resolve().parent
root = here.parents[2]
files = sorted(
    list((root / "formal/Benitoite/Release").rglob("*.lean"))
    + list((root / "formal/Benitoite/Surface").rglob("*.lean"))
)
patterns = {
    "全参照（コメントを含む）": r"checkedRequest|V_CheckedRequest|valContent",
    "型付けの明示的な場合": r"^\s*\|\s*\.V_CheckedRequest\b",
    "値の明示的な場合・構成子の宣言": r"^\s*\|\s*\.?checkedRequest\b",
}
out = []
for label, pattern in patterns.items():
    found = []
    for path in files:
        lines = [(i, line.strip()) for i, line in enumerate(path.read_text().splitlines(), 1)
                 if re.search(pattern, line)]
        if lines:
            found.append((path.relative_to(root), lines))
    out.append(f"{label}: {len(found)} files, {sum(len(lines) for _, lines in found)} lines")
    for path, lines in found:
        for number, line in lines:
            out.append(f"{path}:{number}: {line}")
    out.append("")
text = "\n".join(out)
(here / "inventory.txt").write_text(text + "\n")
print("\n".join(line for line in out if " files, " in line))
