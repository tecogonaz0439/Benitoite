"""対象の実宣言の字面と、有限Lean表への対応に用いた入力を照合する。"""
from pathlib import Path
import hashlib
import json
import re
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
STD = ROOT / "crates/benitoite/src/prelude/stdlib"
EXPECTED = [
    (STD / "Option.bnt", "data", "Option[T]", "Some(T) None"),
    (STD / "Result.bnt", "data", "Result[T, E]", "Ok(T) Error(E)"),
    (STD / "Pair.bnt", "data", "Pair[A, B]", "Pair(A, B)"),
    (STD / "Test/Property.bnt", "record", "Shrinker[T]", "candidates: function(value: T) -> ShrinkStep[T]"),
    (STD / "Test/Property.bnt", "data", "ShrinkStep[T]", "Done Yield(T, function() -> ShrinkStep[T]) Skip(function() -> ShrinkStep[T])"),
    (HERE.parent / "a/keys/recursive.bnt", "data", "A[T]", "End Next(B[T])"),
    (HERE.parent / "a/keys/recursive.bnt", "data", "B[T]", "End(T) Next(A[T])"),
    (HERE.parent / "a/keys/recursive.bnt", "data", "Phantom[T]", "Make(Unit)"),
]
records = []
for path, kind, header, fields in EXPECTED:
    text = path.read_text()
    match = re.search(r"(?:public )?" + kind + " " + re.escape(header) + r"\n(.*?)end " + kind, text, re.S)
    assert match, (path.name, header)
    actual = " ".join(match[1].split())
    assert actual == fields, (header, actual)
    records.append(dict(source=str(path.relative_to(ROOT)), declaration=header, fields=actual,
                        bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(HERE / "variance-sources.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(dict(exit=0, declarations=len(records), constructors=14)))
