"""R20.6b の検査入力、読取り専用の git 状態、件数を保存する。"""
import hashlib
import json
from datetime import datetime
from pathlib import Path
import platform
import re
import subprocess
import sys

root = Path.cwd()
out = Path(__file__).resolve().parent
base = "5e6817fe2d466fcd60881d4d2d17f3413de6729e"
prefix = "r20.6b-"


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def redact(text):
    return text.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")


def save(name, data):
    (out / (prefix + name)).write_text(
        redact(json.dumps(data, ensure_ascii=False, indent=2)) + "\n"
    )


def hashes(paths):
    rows = []
    for name in sorted(set(paths)):
        path = root / name
        if path.is_file():
            data = path.read_bytes()
            rows.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    return rows


phase = sys.argv[1]
changed = command("git", "diff", "--name-only", "HEAD").splitlines()
untracked = command("git", "ls-files", "--others", "--exclude-standard").splitlines()
tracked_inputs = command(
    "git", "ls-files", "crates/benitoite", "scripts/check.sh", "scripts/check",
    "tools/spec-coverage", "tools/bench/compare", "docs/design", "docs/reference",
    "docs/ja", "Cargo.toml", "Cargo.lock", "fuzz/Cargo.toml", "fuzz/Cargo.lock",
    "rust-toolchain.toml", "deny.toml", ".cargo",
).splitlines()
input_paths = tracked_inputs + [p for p in untracked if p.startswith("crates/benitoite/")]
state = dict(
    base=base, head=command("git", "rev-parse", "HEAD"),
    branch=command("git", "branch", "--show-current"),
    staged=command("git", "diff", "--cached", "--name-only").splitlines(),
    changed=changed, untracked=untracked,
    platform=platform.platform(), machine=platform.machine(),
    rustc=command("rustc", "--version"), cargo=command("cargo", "--version"),
    python=sys.version, status=command("git", "status", "--short"),
    recorded_at=datetime.now().astimezone().isoformat(),
)
assert state["head"] == base and state["branch"] == "m013/r20.6"
assert not state["staged"]
inputs = hashes(input_paths)
review = out.parent / "reviews/RV-R20.6.md"
frozen = hashes([str(p.relative_to(root)) for p in (out / "rv-probes").rglob("*")]
                + [str(review.relative_to(root))])
save(phase + "-state.json", state)
save(phase + "-inputs.json", inputs)
save(phase + "-review-inputs.json", frozen)
patch = redact(subprocess.check_output(["git", "diff", "--binary", "HEAD"], text=True))
(out / (prefix + phase + "-implementation.patch")).write_text(patch)
save(phase + "-patch.json", dict(
    path=prefix + phase + "-implementation.patch", bytes=len(patch.encode()),
    sha256=hashlib.sha256(patch.encode()).hexdigest(),
))
if phase == "after":
    assert inputs == json.loads((out / (prefix + "before-inputs.json")).read_text())
    assert frozen == json.loads((out / (prefix + "before-review-inputs.json")).read_text())
    assert patch == (out / (prefix + "before-implementation.patch")).read_text()
    log = (out / (prefix + "w-r.log")).read_text()
    targets = []
    target = None
    for line in log.splitlines():
        if "Running unittests src/lib.rs" in line:
            target = "lib_default"
        match = re.search(r"Running tests/([^ /]+)\.rs", line)
        if match:
            target = match[1]
        match = re.search(
            r"test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored; "
            r"(\d+) measured; (\d+) filtered out; finished in ([\d.]+)s", line
        )
        if match:
            assert target is not None
            targets.append(dict(zip(
                ("target", "passed", "failed", "ignored", "measured", "filtered", "test_seconds"),
                [target, *(int(v) for v in match.groups()[:5]), float(match[6])],
            )))
            target = None
    assert len(targets) == 43, targets
    stage = {"golden", "verify", "random_programs", "desugar_export", "checked_args", "fmt_command"}
    counts = dict(targets=targets, integration_targets=len(targets) - 1,
                  stage_10_20=[t for t in targets if t["target"] in stage])
    for name in ("passed", "failed", "ignored", "filtered"):
        counts[name] = sum(t[name] for t in targets)
        counts["integration_" + name] = sum(t[name] for t in targets[1:])
    save("w-r-counts.json", counts)
    check = subprocess.run(["git", "diff", "--check"], capture_output=True, text=True)
    assert check.returncode == 0, redact(check.stdout + check.stderr)
    save("closing-checks.json", dict(
        input_hashes_unchanged=True, tracked_patch_unchanged=True,
        review_and_probes_unchanged=True, git_diff_check_exit=check.returncode,
        head=state["head"], branch=state["branch"], staged=state["staged"],
    ))
print(json.dumps(dict(phase=phase, head=state["head"], input_files=len(inputs),
                      frozen_review_files=len(frozen)), ensure_ascii=False))
