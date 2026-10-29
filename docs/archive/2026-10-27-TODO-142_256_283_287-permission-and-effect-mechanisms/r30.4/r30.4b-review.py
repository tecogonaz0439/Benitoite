"""再開分の入力・文書・引用条件を読み取りで照合し、伏せ字の記録を残す。"""
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
ENV = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
BASE = "98b420af9bf9e6de4eea81bab140efb835529bd9"
DOCS = [
    "docs/design/03-interop/03-09-network.md",
    "docs/design/07-quality/07-01-security-model.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
]


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, env=ENV, text=True).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sanitized(text):
    text = text.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")
    temporary = os.environ.get("TMPDIR")
    if temporary:
        text = text.replace(temporary.rstrip("/"), "<tmp>")
    return text


def restore_before(path):
    """開始時に保存した差分を HEAD の本文へ適用し、比較元をメモリ内で戻す。"""
    source = subprocess.check_output(["git", "show", BASE + ":" + path],
                                     cwd=ROOT, env=ENV, text=True).splitlines(True)
    patch = (HERE / "r30.4b-before-design.patch").read_text()
    block = next(b for b in patch.split("diff --git ")
                 if b.startswith("a/" + path + " b/" + path + "\n"))
    rows = block.splitlines(True)
    result, pos, active = [], 0, False
    for row in rows:
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
    assert hashlib.sha256(text.encode()).hexdigest() == START["input_hashes"][path]
    return text


START = json.loads((HERE / "r30.4b-start-state.json").read_text())
PREVIOUS = json.loads((HERE / "final-state.json").read_text())
previous_inputs = json.loads((HERE / "changed-inputs.json").read_text())
comparisons = [dict(path=x["path"], previous_sha256=x["sha256"],
                    current_sha256=sha(ROOT / x["path"]),
                    equal=sha(ROOT / x["path"]) == x["sha256"])
               for x in previous_inputs]
changed = sorted(x["path"] for x in comparisons if not x["equal"])
assert changed == sorted(DOCS), changed

patch = []
headings_equal = {}
blocks_equal = {}
new_work_ids = []
observation = "プログラムが接続する endpoint（DNS と OS による変換前の、保持した endpoint）"
for path in DOCS:
    before = restore_before(path)
    after = (ROOT / path).read_text()
    headings_equal[path] = re.findall(r"^#{1,6} .*$", before, re.M) == re.findall(
        r"^#{1,6} .*$", after, re.M)
    blocks_equal[path] = re.findall(r"^```.*?^```[^\n]*$", before, re.M | re.S) == re.findall(
        r"^```.*?^```[^\n]*$", after, re.M | re.S)
    assert headings_equal[path] and blocks_equal[path]
    assert observation in after
    for row in difflib.ndiff(before.splitlines(), after.splitlines()):
        if row.startswith("+ ") and re.search(r"\b(?:R30\.4b?|K10|V10)\b", row):
            new_work_ids.append(dict(path=path, line=row[2:]))
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                      fromfile="before/" + path, tofile="after/" + path))
assert not new_work_ids
(HERE / "r30.4b-design.patch").write_text(sanitized("".join(patch)))

missing = []
checked_links = 0
for path in [*(ROOT / p for p in DOCS), HERE / "results.md"]:
    for target in re.findall(r"\[[^\]]+\]\(([^\s)]+)\)", path.read_text()):
        if target.startswith(("http:", "https:", "mailto:", "#")):
            continue
        target_path = target.split("#", 1)[0]
        resolved = (path.parent / target_path).resolve()
        assert not any(part in {"private", "todo"} for part in resolved.relative_to(ROOT).parts)
        # この実行で作る結果ファイルへのリンクも照合する。
        if resolved != HERE / "r30.4b-review.json" and not resolved.exists():
            missing.append(dict(source=str(path.relative_to(ROOT)), target=target))
        checked_links += 1
assert not missing, missing

configs = ["Cargo.toml", "Cargo.lock", "fuzz/Cargo.toml", "fuzz/Cargo.lock",
           "deny.toml", "rust-toolchain.toml", ".cargo/config.toml",
           "crates/benitoite/Cargo.toml", "crates/benitoite/build.rs",
           "crates/benitoite/examples/gen_skill.rs",
           "crates/benitoite/src/cli/tools/skill/generate.rs",
           "crates/benitoite/src/cli/tools/skill/bundle.rs", "scripts/check.sh",
           "tools/spec-coverage/spec_coverage.py", "formal/lean-toolchain"]
config_hashes = {p: sha(ROOT / p) for p in configs if (ROOT / p).is_file()}
tools = dict(rustc=command("rustc", "-Vv"), cargo=command("cargo", "-V"),
             python=platform.python_version(), platform=platform.platform())
same_environment = {key: value == PREVIOUS[key] for key, value in tools.items()}
assert all(same_environment.values()), same_environment

source_comparison = []
for item in json.loads((HERE / "sectrust-aia-sources.json").read_text())["sources"][:5]:
    kind, relative = item["source"].split(":", 1)
    if kind == "cargo-registry":
        matches = list((Path.home() / ".cargo/registry/src").glob("*/" + relative))
        assert len(matches) == 1
        source_path = matches[0]
    else:
        source_path = Path(command("xcrun", "--show-sdk-path")) / relative
    current = sha(source_path)
    assert current == item["sha256"]
    source_comparison.append(dict(source=item["source"], previous_sha256=item["sha256"],
                                  current_sha256=current, equal=True))

status = command("git", "status", "--porcelain", "--untracked-files=all")
tracked = command("git", "diff", "--name-only").splitlines()
assert set(tracked) == set(START["input_hashes"]) - {"crates/benitoite/tests/scoped_calls/http_io.rs"}
untracked = command("git", "ls-files", "--others", "--exclude-standard").splitlines()
outside = [p for p in untracked if p != "crates/benitoite/tests/scoped_calls/http_io.rs"
           and not p.startswith(str(HERE.relative_to(ROOT)) + "/")]
assert not outside, outside
assert command("git", "rev-parse", "HEAD") == BASE
assert command("git", "branch", "--show-current") == START["branch"]
index = ROOT / command("git", "rev-parse", "--git-path", "index")
assert sha(index) == START["index_sha256"]
whitespace = subprocess.run(["git", "diff", "--check"], cwd=ROOT, env=ENV,
                            capture_output=True, text=True)
assert whitespace.returncode == 0, whitespace.stdout + whitespace.stderr

leaks = []
for path in HERE.glob("r30.4b-*"):
    if path.suffix in {".md", ".json", ".log", ".patch"}:
        text = path.read_text()
        if any(s in text for s in [str(ROOT), str(Path.home()), "/private/var/folders/"]):
            leaks.append(path.name)
assert not leaks, leaks
records = {}
for label in ["work", "registry-fixed", "work-remaining", "ports", "final-lint", "heap"]:
    item = json.loads((HERE / (label + ".json")).read_text())
    records[label] = dict(command=item["command"], check_exit_code=item["check_exit_code"],
                          outer_wall_seconds=item["outer_wall_seconds"],
                          maxrss_raw=item["maxrss_raw"], maxrss_unit=item["maxrss_unit"],
                          record_sha256=sha(HERE / (label + ".json")),
                          log_sha256=sha(HERE / (label + ".log")))
result = dict(recorded_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              judgment_by="再開担当 Codex、2026-10-29", base=BASE, head=BASE,
              branch=START["branch"], status=status, input_comparison=comparisons,
              restart_changed_design_files=changed, config_hashes=config_hashes,
              tools=tools, same_environment_as_previous=same_environment,
              tls_primary_source_comparison=source_comparison,
              reused_results=records, headings_equal=headings_equal,
              fenced_blocks_equal=blocks_equal, new_work_ids=new_work_ids,
              local_links_checked=checked_links, missing_links=missing,
              diff_check_exit_code=whitespace.returncode, index_unchanged=True,
              edited_paths_outside_scope=outside, local_absolute_path_leaks=leaks,
              generated_sources_and_outputs_unchanged=True,
              remaining_selected_checks_after_citation=[],
              excluded="lake build・check-formal.sh・short・本番TLS/OCSPの追加試験は未実施")
working_diff = subprocess.check_output(["git", "diff", "--binary"], cwd=ROOT, env=ENV)
result["working_diff_sha256"] = hashlib.sha256(working_diff).hexdigest()
result["results_sha256"] = sha(HERE / "results.md")
result["untracked_test_input_sha256"] = sha(ROOT / "crates/benitoite/tests/scoped_calls/http_io.rs")
(HERE / "r30.4b-review.json").write_text(sanitized(json.dumps(result, ensure_ascii=False, indent=2)) + "\n")
print(json.dumps(dict(changed_design_files=changed, input_files=len(comparisons),
                      local_links_checked=checked_links, index_unchanged=True,
                      checks="文書と引用条件の照合に成功"), ensure_ascii=False))
