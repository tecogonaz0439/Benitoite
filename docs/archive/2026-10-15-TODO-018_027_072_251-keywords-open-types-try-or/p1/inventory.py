"""P1 の確認表を標準出力へ出す。入力と通常の検査には書き込まない。"""

import collections
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[3]
CHANGE = Path(__file__).resolve().parents[1]
PREFIX = str(CHANGE.relative_to(ROOT)) + "/"
HISTORY = ("reference/", "docs/archive/", "docs/todo/", "tools/bench/results/",
           "tools/skill-eval/results/", "tools/syntax-measure/")
HANDWRITTEN = {"idioms.md", "common-mistakes.md", "language-comparison.md", "testing.md"}
HITS = re.compile(r"\btry\b|\blanguage\b|\b[0-9a-fA-F]{64}\b")


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def role(path):
    if path == "docs/reference/benitoite-minimal.md":
        return "minimal_reference_review"
    if path.startswith("crates/benitoite/src/prelude/stdlib/"):
        return "stdlib_implementation"
    if path.startswith("crates/benitoite/skill/"):
        if path.endswith("/SKILL.md") or Path(path).name in HANDWRITTEN:
            return "skill_handwritten"
        return "skill_generated"
    if path.startswith("docs/ja/"):
        return "translation_review"
    if path.startswith(("docs/design/", "docs/reference/")):
        return "sample_and_notation_review"
    if path.startswith("crates/benitoite/testdata/"):
        return "test_input_or_expectation"
    if path.startswith(("crates/benitoite/tests/", "fuzz/", "formal/tests/")):
        return "test_or_test_generator"
    if path.startswith("crates/benitoite/examples/"):
        return "example_or_development_generator_review"
    if path.startswith("tools/named-arguments-migrate/"):
        return "previous_migration_tool_do_not_apply"
    if path.startswith(("tools/bench/", "tools/skill-eval/")):
        return "current_tool_sample_or_generator_review"
    if path.startswith("crates/benitoite/src/"):
        if "test" in Path(path).stem or "/tests/" in path:
            return "lib_test"
        if path.endswith(("/diag/codes.rs", "/cli/tools/skill/generate.rs")):
            return "sample_generator_and_diagnostic_review"
        return "implementation_including_inline_tests_review"
    return "support_or_other_document_review"


def main():
    previous = json.loads((CHANGE / "study/inventory.json").read_text())
    files, raw_hits, exclusions = [], [], collections.Counter()
    for path in sorted(filter(None, git("ls-files", "-z").split("\0"))):
        if path.startswith(PREFIX):
            exclusions["this_change"] += 1
            continue
        excluded = next((p for p in HISTORY if path.startswith(p)), None)
        if excluded:
            exclusions[excluded] += 1
            continue
        if (ROOT / path).is_symlink():
            target = os.readlink(ROOT / path)
            files.append(dict(path=path, role="skill_symlink", target=target,
                              sha256=digest(target.encode())))
            continue
        data = (ROOT / path).read_bytes()
        files.append(dict(path=path, role=role(path), sha256=digest(data)))
        # コメント・文字列・インラインも残す。Python/Rust 自身の語を含む候補であり、AST の件数ではない。
        if Path(path).suffix not in {".bnt", ".rs", ".md", ".py", ".toml", ".lock", ".json", ".formatted", ".sh"}:
            continue
        try:
            source = data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        for line, text in enumerate(source.splitlines(), 1):
            for match in HITS.finditer(text):
                word = match[0]
                kind = word if word in {"try", "language"} else "fixed_hash_candidate"
                raw_hits.append(dict(path=path, line=line, column=match.start() + 1,
                                     kind=kind, text=word))
    hashes = {f["path"]: f["sha256"] for f in files}
    stale = [p for p, h in previous["source_sha256"].items() if hashes.get(p) != h]
    metadata = json.loads(subprocess.check_output(
        ["cargo", "metadata", "--no-deps", "--format-version", "1"], cwd=ROOT))
    targets = []
    for package in metadata["packages"]:
        for target in package["targets"]:
            targets.append(dict(package=package["name"], name=target["name"], kind=target["kind"],
                                path=str(Path(target["src_path"]).relative_to(ROOT))))
    tries = [r for r in previous["word_occurrences"] if r["word"] == "try"]
    golden = []
    for path in sorted({r["path"] for r in tries if r["group"] == "testdata"}):
        p = Path(path)
        # 同じ名前の期待値と、同じケースの .files/ 以下の入力も保持する。
        related = [f["path"] for f in files if Path(f["path"]).parent == p.parent
                   and f["path"].startswith(str(p.with_suffix("")) + ".")]
        fixture_prefix = str(p.with_suffix(".files")) + "/"
        related.extend(f["path"] for f in files if f["path"].startswith(fixture_prefix))
        golden.append(dict(path=path, try_candidates=sum(r["path"] == path for r in tries),
                           related=sorted(set(related))))
    result = dict(head=git("rev-parse", "HEAD").strip(), study_head=previous["head"],
                  method="tracked files; path roles need per-example review; raw hits include host language, comments and strings; study candidates are lexical, not AST counts",
                  source_set_sha256=digest("".join(f'{p}\0{h}\n' for p, h in sorted(hashes.items())).encode()),
                  study_hash_mismatches=stale, excluded_tracked_counts=dict(exclusions),
                  summary=dict(files_by_role=dict(collections.Counter(f["role"] for f in files)),
                               raw_hits_by_kind=dict(collections.Counter(h["kind"] for h in raw_hits)),
                               study_try_candidates=len(tries), study_try_files=len({r["path"] for r in tries}),
                               golden_try_files=len(golden), cargo_targets=len(targets)),
                  files=files, cargo_targets=targets, raw_hits=raw_hits,
                  study_try_candidates=tries, golden_try_baseline=golden,
                  study_language_declarations=previous["language_declarations"])
    # 配列の一項目を一行にし、確認表の差分を読める量に抑える。
    print("{")
    for index, (key, value) in enumerate(result.items()):
        comma = "," if index + 1 < len(result) else ""
        print(json.dumps(key) + ": " + ("[" if isinstance(value, list) else json.dumps(value, ensure_ascii=False)) + ("" if isinstance(value, list) else comma))
        if isinstance(value, list):
            for i, row in enumerate(value):
                print(json.dumps(row, ensure_ascii=False) + ("," if i + 1 < len(value) else ""))
            print("]" + comma)
    print("}")


if __name__ == "__main__":
    main()
