"""最終の入力・検査件数・編集範囲を読み取りだけで記録する。"""
import datetime
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE = "98b420af9bf9e6de4eea81bab140efb835529bd9"


def command(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def save(name, value):
    text = json.dumps(value, ensure_ascii=False, indent=2)
    text = text.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")
    (HERE / name).write_text(text + "\n")


paths = set(command("git", "diff", "--name-only", BASE, "--",
                    "crates/benitoite", "docs/design", "tools/bench/compare").splitlines())
paths.update(command("git", "ls-files", "--others", "--exclude-standard", "--",
                     "crates/benitoite", "docs/design", "tools/bench/compare").splitlines())
save("changed-inputs.json", [{"path": p, "bytes": (ROOT / p).stat().st_size,
                               "sha256": hashlib.sha256((ROOT / p).read_bytes()).hexdigest()}
                              for p in sorted(paths) if p])
patch = subprocess.check_output(["git", "diff", "--binary", BASE, "--",
                                 "crates/benitoite", "docs/design", "tools/bench/compare"], cwd=ROOT)
(HERE / "implementation.patch").write_bytes(patch)

counts = {}
pattern = re.compile(r"test result: (ok|FAILED)\. (\d+) passed; (\d+) failed; (\d+) ignored; (\d+) measured; (\d+) filtered out;")
for label in ["work", "registry-fixed", "work-remaining", "ports", "heap"]:
    log = HERE / f"{label}.log"
    if not log.exists():
        continue
    section = target = ""
    rows = []
    for line in log.read_text().splitlines():
        if line.startswith("== "):
            section = line[3:]
            target = ""
        running = re.search(r"Running (.*?) \(", line)
        if running:
            target = running.group(1)
        if "Doc-tests" in line:
            target = line.strip()
        found = pattern.search(line)
        if found:
            rows.append(dict(section=section, target=target, status=found[1],
                             **dict(zip(["passed", "failed", "ignored", "measured", "filtered"],
                                        map(int, found.groups()[1:])))))
    counts[label] = rows
save("test-counts.json", counts)

status = command("git", "status", "--porcelain", "--untracked-files=all")
allowed_docs = {"01-06-type-system.md", "01-07-effects.md", "02-08-vm.md", "02-09-runtime.md",
                "03-09-network.md", "07-01-security-model.md", "07-04-formal-semantics.md"}
violations = []
for row in status.splitlines():
    # strip は先頭行の状態欄の空白を落とすため、パスは状態欄の後の最初の空白から読む。
    path = row.split(maxsplit=1)[1]
    allowed = (path.startswith("crates/benitoite/") or path.startswith("tools/bench/compare/")
               or path.startswith(str(HERE.relative_to(ROOT)) + "/")
               or (path.startswith("docs/design/") and Path(path).name in allowed_docs))
    if not allowed:
        violations.append(path)
absolute_leaks = []
for p in HERE.rglob("*"):
    if p.is_file() and p.suffix in {".md", ".json", ".log", ".patch"}:
        content = p.read_text()
        if any(x in content for x in [str(ROOT), str(Path.home()), "/private/var/folders/"]):
            absolute_leaks.append(str(p.relative_to(HERE)))
save("final-state.json", dict(base=BASE, head=command("git", "rev-parse", "HEAD"),
                              branch=command("git", "branch", "--show-current"),
                              index_unchanged=subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode == 0,
                              edited_paths_outside_scope=violations, local_absolute_path_leaks=absolute_leaks,
                              status=status, rustc=command("rustc", "-Vv"), cargo=command("cargo", "-V"),
                              python=platform.python_version(), platform=platform.platform(),
                              timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                              cleanup="target 外の一時ビルド・基準展開なし、新しい CARGO_TARGET_DIR なし。比較器の一時入力は終了時に削除。"))
if violations or absolute_leaks:
    raise SystemExit("編集範囲または伏せ字の確認に失敗")
