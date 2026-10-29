"""R30.4c の文書差分、保護した記録、前回の検査の引用条件を照合する。"""
import datetime
import difflib
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = "98b420af9bf9e6de4eea81bab140efb835529bd9"
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
START = json.loads((HERE / "r30.4c-start-state.json").read_text())
PREFIX = str(HERE.relative_to(ROOT)) + "/"
EXPECTED = {
    "crates/benitoite/src/prelude/stdlib/Network/Http.bnt",
    "crates/benitoite/skill/SKILL.md",
    "crates/benitoite/skill/references/idioms.md",
    "crates/benitoite/skill/references/stdlib/Network.Http.md",
    "docs/design/02-impl/02-08-vm.md",
    "docs/design/07-quality/07-01-security-model.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
    PREFIX + "runtime-notes.md",
    PREFIX + "results.md",
}


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, env=ENV, text=True)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sanitized(text):
    text = text.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")
    temporary = os.environ.get("TMPDIR")
    if temporary:
        text = text.replace(temporary.rstrip("/"), "<tmp>")
    return text


def before(path):
    source = git("show", BASE + ":" + path).splitlines(True)
    patch = (HERE / "r30.4c-before.patch").read_text()
    block = next(b for b in patch.split("diff --git ")
                 if b.startswith("a/" + path + " b/" + path + "\n"))
    result, pos, active = [], 0, False
    for row in block.splitlines(True):
        hunk = re.match(r"@@ -(\d+)(?:,\d+)? \+\d+(?:,\d+)? @@", row)
        if hunk:
            start = int(hunk[1]) - 1
            result.extend(source[pos:start])
            pos, active = start, True
        elif active and row.startswith((" ", "-")):
            assert source[pos] == row[1:], (path, pos)
            if row.startswith(" "):
                result.append(source[pos])
            pos += 1
        elif active and row.startswith("+"):
            result.append(row[1:])
    result.extend(source[pos:])
    text = "".join(result)
    assert hashlib.sha256(text.encode()).hexdigest() == START["hashes"][path]
    return text


comparisons = [{"path": p, "before_sha256": old,
                "after_sha256": sha(ROOT / p), "equal": sha(ROOT / p) == old}
               for p, old in START["hashes"].items()]
changed = {x["path"] for x in comparisons if not x["equal"]}
assert changed == EXPECTED, changed ^ EXPECTED
assert set(git("diff", "--name-only").splitlines()) == set(START["tracked_changed"])
assert git("rev-parse", "HEAD").strip() == START["head"] == BASE
assert git("branch", "--show-current").strip() == START["branch"]
assert hashlib.sha256(git("ls-files", "--stage").encode()).hexdigest() == START["index_sha256"]

patch, prose = [], {}
for path in sorted(EXPECTED):
    if path.startswith(PREFIX):
        continue
    old, new = before(path), (ROOT / path).read_text()
    patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                      fromfile="before/" + path, tofile="after/" + path))
    if path.endswith(".md"):
        headings = re.findall(r"^#{1,6} .*$", old, re.M) == re.findall(r"^#{1,6} .*$", new, re.M)
        if path.endswith("Network.Http.md"):
            assert old.replace("NetworkError.InvalidInput", "NetworkErrorKind.InvalidInput") == new
            blocks = "生成された宣言の doc コメントだけを訂正"
        else:
            blocks = re.findall(r"^```.*?^```[^\n]*$", old, re.M | re.S) == re.findall(
                r"^```.*?^```[^\n]*$", new, re.M | re.S)
            assert blocks
        assert headings
        prose[path] = {"headings_unchanged": headings, "code_blocks": blocks}
    else:
        assert old.replace("NetworkError.InvalidInput", "NetworkErrorKind.InvalidInput") == new
        assert [l for l in old.splitlines() if not l.lstrip().startswith("//")] == [
            l for l in new.splitlines() if not l.lstrip().startswith("//")]
(HERE / "r30.4c-documentation.patch").write_text(sanitized("".join(patch)))

previous = json.loads((HERE / "r30.4b-review.json").read_text())
configs = {p: sha(ROOT / p) for p in previous["config_hashes"]}
assert configs == previous["config_hashes"]
tools = {"rustc": subprocess.check_output(["rustc", "-Vv"], text=True).strip(),
         "cargo": subprocess.check_output(["cargo", "-V"], text=True).strip(),
         "python": platform.python_version(), "platform": platform.platform()}
assert tools == previous["tools"]

links, missing = 0, []
for path in sorted(EXPECTED):
    if not path.endswith(".md"):
        continue
    for target in re.findall(r"\[[^\]]+\]\(([^\s)]+)\)", (ROOT / path).read_text()):
        if target.startswith(("http:", "https:", "mailto:", "#")):
            continue
        resolved = (ROOT / path).parent / target.split("#", 1)[0]
        assert not any(p in {"private", "todo"} for p in resolved.resolve().relative_to(ROOT).parts)
        pending = {HERE / name for name in ["r30.4c-review.json", "r30.4c-review-fixed.log",
                                            "r30.4c-review-fixed.json"]}
        if resolved not in pending and not resolved.exists():
            missing.append({"source": path, "target": target})
        links += 1
assert not missing, missing
check = subprocess.run(["git", "diff", "--check"], cwd=ROOT, env=ENV, capture_output=True, text=True)
assert check.returncode == 0, check.stdout + check.stderr
leaks = []
for path in HERE.glob("r30.4c-*"):
    if path.suffix in {".json", ".log", ".patch"} and any(
        s in path.read_text() for s in [str(ROOT), str(Path.home()), "/private/var/folders/"]):
        leaks.append(path.name)
assert not leaks, leaks

result = {"recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "judgment_by": "R30.4c 担当 Codex、2026-10-29", "base": BASE, "head": BASE,
          "branch": START["branch"], "index_unchanged": True,
          "status": git("status", "--porcelain", "--untracked-files=all"),
          "input_comparison": comparisons, "changed_existing_files": sorted(changed),
          "rust_sources_and_tests_unchanged": True, "bnt_declarations_unchanged": True,
          "review_and_rv_probes_unchanged": True, "config_hashes": configs, "tools": tools,
          "same_environment_as_previous": True, "prose_comparison": prose,
          "links_checked": links, "diff_check_exit_code": check.returncode,
          "working_diff_sha256": hashlib.sha256(git("diff", "--binary").encode()).hexdigest(),
          "untracked_test_input_sha256": sha(ROOT / "crates/benitoite/tests/scoped_calls/http_io.rs"),
          "reused_results": previous["reused_results"],
          "local_absolute_path_leaks": leaks,
          "excluded": "lake build・check-formal.sh・short は実行しない"}
(HERE / "r30.4c-review.json").write_text(sanitized(json.dumps(result, ensure_ascii=False, indent=2)) + "\n")
print(json.dumps({"changed_existing_files": sorted(changed), "compared_files": len(comparisons),
                  "links_checked": links, "index_unchanged": True}, ensure_ascii=False))
