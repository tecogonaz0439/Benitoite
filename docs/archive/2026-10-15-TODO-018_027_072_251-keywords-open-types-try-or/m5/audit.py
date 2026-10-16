"""M5 の比較記録を作る。通常の検査からは呼ばず、入力も編集しない。"""

from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
CHANGE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/source-migrate"))
from source_extract import snippets


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read(name):
    return json.loads((CHANGE / name).read_text())


def original(path):
    return subprocess.check_output(["git", "show", baseline["head"] + ":" + path], cwd=ROOT)


baseline = read("p1/inputs.json")
files = {r["path"]: r for r in baseline["files"]}
rows = []
for path in sorted({r["path"] for r in baseline["study_try_candidates"]}):
    old = original(path)
    current = (ROOT / path).read_bytes()
    if sha(old) != files[path]["sha256"]:
        raise ValueError("P1 hash mismatch: " + path)
    role = files[path]["role"]
    if role in {"test_input_or_expectation", "test_or_test_generator", "lib_test",
                "implementation_including_inline_tests_review",
                "example_or_development_generator_review"}:
        outcome = "keep_test"
    elif role == "translation_review":
        outcome = "defer_translation_M8"
    elif role == "skill_generated":
        outcome = "regenerate"
    elif role in {"sample_and_notation_review", "skill_handwritten",
                  "sample_generator_and_diagnostic_review"}:
        outcome = "reviewed_M3"
    elif role in {"stdlib_implementation", "current_tool_sample_or_generator_review"}:
        outcome = "reviewed_M4"
    else:
        raise ValueError("unclassified P1 path: " + path)
    candidates = [dict(index=i, **r) for i, r in enumerate(baseline["study_try_candidates"])
                  if r["path"] == path]
    rows.append(dict(path=path, role=role, disposition=outcome,
                     before_sha256=sha(old), after_sha256=sha(current),
                     unchanged=old == current, candidates=candidates))

golden = []
for path in sorted({p for r in baseline["golden_try_baseline"] for p in r["related"]}):
    current_sha = sha((ROOT / path).read_bytes())
    if current_sha != files[path]["sha256"]:
        raise ValueError("golden input/expectation changed: " + path)
    golden.append(dict(path=path, before_sha256=files[path]["sha256"], after_sha256=current_sha))

rust = []
for path in sorted({r["path"] for r in baseline["study_try_candidates"] if r["group"] == "rust_host"}):
    old = list(snippets(path, original(path)))
    current = list(snippets(path, (ROOT / path).read_bytes()))
    sources = {s.source for s in current}
    kept = []
    reviewed = []
    for index, s in enumerate(old):
        if not re.search(r"\btry\b", s.source):
            continue
        entry = dict(snippet=index, sha256=sha(s.source.encode()))
        if s.source in sources:
            kept.append(entry)
        else:
            # 差のある五断片だけを review.md で個別に確認する。
            if path.endswith("/resource_tests.rs"):
                changed = s.source.replace(
                    "{IMPORTS}\n", "{IMPORTS}\nimport Benitoite.Unofficial.IO.Process\n"
                ).replace("Clock.Time,Console.Write\n", "Clock.Time,Console.Write{extra_uses}\n"
                ).replace("return Result.Ok(2) end lambda", "return {winner} end lambda")
                if changed not in sources:
                    raise ValueError("unexpected cancellation fixture change")
                entry["review"] = "cancellation_program_with_winner(Result.Ok(2), empty uses)"
            elif path.endswith("/diag/codes.rs"):
                if s.source == "write `try` before the expression, such as `try parse(text)`":
                    if "write `try` before the expression, such as `try parse(text) or return`" not in sources:
                        raise ValueError("missing explicit diagnostic repair")
                    entry["review"] = "M3 E0211 repair example; not a compatibility test"
                elif s.source.startswith("`return` and `try` cannot leave a `lazy` body"):
                    entry["review"] = "E0218 explanation includes die message; lazy/guard tests retained"
                else:
                    raise ValueError("unexpected diagnostic change")
            elif path.endswith("/cli/tools/skill/generate.rs"):
                if not s.source.startswith("The base grammar of Benitoite in EBNF."):
                    raise ValueError("unexpected generation source change")
                entry["review"] = "grammar introduction describes the implemented rules; not a test input"
            elif path.endswith("/l21_json.rs"):
                # 追加した Show の検査を除いた元の裸の式と旧失敗条件は人が照合する。
                entry["review"] = "Json Show/construction checks added; see review.md"
            else:
                raise ValueError("unreviewed Rust snippet: " + path)
            reviewed.append(entry)
    rust.append(dict(path=path, identical_try_snippets=kept, reviewed_try_snippets=reviewed))

inputs = []
for stage in ("m3", "m4"):
    for row in read(stage + "/final-inventory.json")["inputs"]:
        expected = row.get("source_sha256", row.get("sha256"))
        actual = sha((ROOT / row["path"]).read_bytes())
        if expected != actual:
            raise ValueError("migration final input changed: " + row["path"])
        inputs.append(dict(stage=stage, path=row["path"], sha256=actual))

result = dict(
    baseline=baseline["head"],
    head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
    method="P1 lexical candidates, complete golden hashes, decoded Rust snippets, M3/M4 final hashes; assertion semantics reviewed in review.md",
    summary=dict(candidates=sum(len(r["candidates"]) for r in rows), files=len(rows),
                 dispositions=dict(Counter(r["disposition"] for r in rows)),
                 golden_inputs=len(baseline["golden_try_baseline"]), golden_related=len(golden),
                 identical_rust_snippets=sum(len(r["identical_try_snippets"]) for r in rust),
                 reviewed_rust_snippets=sum(len(r["reviewed_try_snippets"]) for r in rust),
                 verified_migration_inputs=len(inputs)),
    p1_candidates=rows, golden_related=golden, rust_snippets=rust, migration_inputs=inputs,
)
# 配列は一記録を一行にし、ハッシュの対応を差分で読みやすくする。
print("{")
for index, (key, value) in enumerate(result.items()):
    comma = "," if index + 1 < len(result) else ""
    prefix = json.dumps(key) + ": "
    if isinstance(value, list):
        print(prefix + "[")
        for number, row in enumerate(value):
            print(json.dumps(row, ensure_ascii=False) + ("," if number + 1 < len(value) else ""))
        print("]" + comma)
    else:
        print(prefix + json.dumps(value, ensure_ascii=False) + comma)
print("}")
