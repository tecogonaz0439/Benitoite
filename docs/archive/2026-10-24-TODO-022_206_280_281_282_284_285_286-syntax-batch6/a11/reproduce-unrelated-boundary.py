"""既定の本体予算とモジュール分類の境界例を生成する。"""

import pathlib
import sys

destination = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/a11-boundary-repro")
destination.mkdir(parents=True, exist_ok=True)
source = "function sample(x: Integer) -> Integer\n bind z <- 0\n"
source += "".join(f" bind n{i} <- x\n" for i in range(440))
source += " bind _ <- ()\n" * 102
source += " bind _ <- (())\n" * 2
source += " return 1 div z\nend function\n"
source += "function main() -> Unit end function\n"
for name, prefix in [
    ("first.bnt", ""),
    ("prefixed.bnt", "function unrelated() -> Unit end function\n"),
]:
    path = destination / name
    path.write_text(prefix + source, encoding="utf-8")
    print(path)
