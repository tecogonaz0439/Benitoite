"""Save hashes of the checked inputs and a read-only Git state."""
import hashlib
import json
import platform
from datetime import datetime
from pathlib import Path
import subprocess
import sys

root = Path.cwd()
out = Path(__file__).resolve().parent

def command(*args):
    return subprocess.check_output(args, text=True).strip()

def redact(text):
    return text.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")

changed = command("git", "diff", "--name-only").splitlines()
untracked = command("git", "ls-files", "--others", "--exclude-standard").splitlines()
checked = [p for p in changed + untracked if not p.startswith(str(out.relative_to(root)) + "/")]
support = ["Cargo.toml", "Cargo.lock", "fuzz/Cargo.toml", "fuzz/Cargo.lock",
           "rust-toolchain.toml", "deny.toml", "scripts/check.sh",
           "tools/bench/compare/timing_probe.rs", "tools/bench/compare/build.py",
           "docs/design/00-overview/00-04-glossary.md"]

def hashes(paths):
    rows = []
    for name in sorted(set(paths)):
        path = Path(name)
        if path.is_file():
            data = path.read_bytes()
            rows.append(dict(path=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
    return rows

(out / "checked-files.json").write_text(json.dumps(dict(
    changed_checked_inputs=hashes(checked), unchanged_support_inputs=hashes(support)
), indent=2) + "\n")
state = dict(head=command("git", "rev-parse", "HEAD"),
             branch=command("git", "branch", "--show-current"),
             staged=command("git", "diff", "--cached", "--name-only").splitlines(),
             changed=changed, untracked=untracked,
             platform=platform.platform(), machine=platform.machine(),
             rustc=command("rustc", "--version"), cargo=command("cargo", "--version"),
             python=sys.version, status=command("git", "status", "--short"))
state["recorded_at"] = datetime.now().astimezone().isoformat()
patch = subprocess.check_output(["git", "diff", "--binary", "HEAD"])
(out / "implementation.patch").write_bytes(patch)
(out / "implementation-patch.json").write_text(json.dumps(dict(
    path="implementation.patch", bytes=len(patch), sha256=hashlib.sha256(patch).hexdigest()
), indent=2) + "\n")
evidence = [str(p.relative_to(root)) for p in out.iterdir()
            if p.is_file() and p.suffix in {".bnt", ".py"}]
(out / "evidence-files.json").write_text(json.dumps(hashes(evidence), indent=2) + "\n")
(out / "final-state.json").write_text(redact(json.dumps(state, indent=2)) + "\n")
print({"checked_inputs": len(checked), "head": state["head"], "staged": state["staged"]})
