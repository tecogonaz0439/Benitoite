"""調査用の候補の集計。言語入力には書き込まず、JSON を標準出力へ出す。"""
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools/named-arguments-migrate"))
from extract import snippets

WORDS = "fn pub impl mut for while loop break continue where switch as async await spawn select class instance var mutable module derive let of when die non_exhaustive open extensible".split()
EXCLUDED = ("reference/", "docs/archive/", "docs/todo/", "tools/bench/results/", "tools/skill-eval/results/", "tools/syntax-measure/", "tools/named-arguments-migrate/", str(Path(__file__).resolve().parents[1].relative_to(ROOT)) + "/")
TOKEN = re.compile(r'//[^\n]*|r(?P<h>\#*)".*?"(?P=h)|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[A-Za-z_][A-Za-z_0-9]*|->|\S', re.S)
HINT = re.compile(r'\b(?:function|lambda|bind|match|try|public data|import|uses)\b')


def group(path):
    if path.startswith("crates/benitoite/src/prelude/stdlib/"):
        return "stdlib"
    if path.startswith("crates/benitoite/testdata/"):
        return "testdata"
    if path.startswith("crates/benitoite/skill/references/") and Path(path).name not in {"idioms.md", "common-mistakes.md", "language-comparison.md", "testing.md"}:
        return "skill_generated"
    if path.startswith("crates/benitoite/skill/"):
        return "skill_handwritten"
    if path.startswith("docs/ja/"):
        return "japanese"
    if path.startswith("docs/reference/"):
        return "reference"
    if path.startswith("docs/design/"):
        return "design"
    if path.endswith(".rs"):
        return "rust_host"
    return "other_bnt" if path.endswith(".bnt") else "other_docs"


def tokens(source):
    return [(m[0], m.start()) for m in TOKEN.finditer(source)
            if not m[0].startswith(("//", '"', "'")) and not re.match(r'r\#*"', m[0])]


def main():
    files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    records, matches, hashes = [], [], {}
    units = collections.Counter()
    for path in files:
        if not path or path.startswith(EXCLUDED) or path in {"AGENTS.md", "docs/reference/benitoite-minimal.md"}:
            continue
        if not path.endswith((".bnt", ".rs", ".md")) or "THIRD-PARTY" in path or "LICENSE" in path:
            continue
        data = (ROOT / path).read_bytes()
        category = group(path)
        for index, unit in enumerate(snippets(path, data)):
            if unit.kind != "bnt" and not HINT.search(unit.source):
                continue
            units[category] += 1
            hashes[path] = hashlib.sha256(data).hexdigest()

            def location(at):
                byte = len(unit.source[:at].encode())
                host = unit.boundaries[byte] if byte < len(unit.boundaries) else -1
                return dict(path=path, snippet=index, snippet_line=unit.source.count("\n", 0, at) + 1,
                            host_line=data[:host].count(b"\n") + 1 if host >= 0 else None,
                            host_byte=host, hold=unit.hold, group=category)

            ts, stack, skip = tokens(unit.source), [], False
            for i, (word, at) in enumerate(ts):
                if word in WORDS or word == "try":
                    records.append(dict(location(at), word=word))
                if skip:
                    skip = False
                    continue
                if word == "end" and i + 1 < len(ts) and ts[i + 1][0] == "match":
                    if stack:
                        entry = stack.pop()
                        entry["closed"] = True
                        matches.append(entry)
                    skip = True
                elif word == "match":
                    stack.append(dict(location(at), arms=[], closed=False,
                                      target=" ".join(w for w, _ in ts[i + 1:i + 25]).split(" with")[0]))
                elif word == "case" and stack:
                    arm, depth = [], 0
                    for w, _ in ts[i + 1:]:
                        if w == "->" and depth == 0:
                            break
                        arm.append(w)
                        depth += int(w in ("(", "[")) - int(w in (")", "]"))
                        if len(arm) > 200:
                            break
                    stack[-1]["arms"].append(arm)
            matches.extend(stack)
    for entry in matches:
        arms = entry["arms"]
        entry["error_kinds"] = sorted({w for arm in arms for w in arm if w in ("IOErrorKind", "NetworkErrorKind")})
        entry["catchall"] = any(len(arm) == 1 and re.fullmatch(r"[a-z_][A-Za-z_0-9]*", arm[0]) for arm in arms)
        entry["result_error"] = any("Result" in arm and "Error" in arm for arm in arms)
    summary = {}
    for category, count in sorted(units.items()):
        ms = [m for m in matches if m["group"] == category]
        rs = [r for r in records if r["group"] == category and r["word"] == "try"]
        summary[category] = dict(snippets=count, try_occurrences=len(rs), try_files=len({r["path"] for r in rs}),
                                 matches=len(ms), kind_matches=sum(bool(m["error_kinds"]) for m in ms),
                                 kind_without_catchall=sum(bool(m["error_kinds"]) and not m["catchall"] for m in ms),
                                 result_error_matches=sum(m["result_error"] for m in ms),
                                 result_without_top_catchall=sum(m["result_error"] and not m["catchall"] for m in ms))
    declarations = []
    for path in hashes:
        data = (ROOT / path).read_bytes()
        for index, unit in enumerate(snippets(path, data)):
            for match in re.finditer(r'(?m)^\s*language\s+"(\d+\.\d+\.\d+)"', unit.source):
                host = unit.boundaries[len(unit.source[:match.start()].encode())]
                declarations.append(dict(path=path, snippet=index, host_line=data[:host].count(b"\n") + 1,
                                         version=match[1], hold=unit.hold))
    result = dict(head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
                  method="extract.py + approximate tokens; no AST/typecheck; strings including interpolation excluded; Rust fragments include diagnostics and generators",
                  summary=summary,
                  word_summary={w: dict(occurrences=sum(r["word"] == w for r in records),
                                       files=len({r["path"] for r in records if r["word"] == w}),
                                       groups=dict(collections.Counter(r["group"] for r in records if r["word"] == w))) for w in WORDS},
                  matches=matches, word_occurrences=records, language_declarations=declarations, source_sha256=hashes)
    # 候補一件を一行にし、位置と集計を同じ JSON で確かめられるようにする。
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
