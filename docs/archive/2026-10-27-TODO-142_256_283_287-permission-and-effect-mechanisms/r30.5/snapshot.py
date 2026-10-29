"""引用に使う入力・差分・固定版を、禁止領域を除いた明示した範囲から記録する。"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PATHS = ["crates/benitoite", "formal", "scripts", "tools/bench/compare",
         "tools/spec-coverage", "docs/design", "docs/reference", "docs/ja",
         "Cargo.toml", "Cargo.lock", "fuzz/Cargo.toml", "fuzz/Cargo.lock",
         "rust-toolchain.toml", "deny.toml", ".cargo", "build.rs"]


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def sha(data):
    return hashlib.sha256(data).hexdigest()


names = set(git("ls-files", "-z", "--", *PATHS).decode().split("\0"))
names.update(git("ls-files", "--others", "--exclude-standard", "-z", "--", *PATHS).decode().split("\0"))
files = []
for name in sorted(names - {""}):
    path = ROOT / name
    if path.is_file() and not path.is_symlink():
        data = path.read_bytes()
        files.append(dict(path=name, bytes=len(data), sha256=sha(data)))
patch = git("diff", "--binary", "HEAD", "--", *PATHS)
(HERE / f"{sys.argv[1]}.patch").write_bytes(patch)
record = dict(head=git("rev-parse", "HEAD").decode().strip(),
              base="ea42f4f97fe34e1f4768404f5b44aac3ff371155",
              diff_sha256=sha(patch), diff_bytes=len(patch),
              changed=git("diff", "--name-only", "HEAD", "--", *PATHS).decode().splitlines(),
              untracked=git("ls-files", "--others", "--exclude-standard", "--", *PATHS).decode().splitlines(),
              files=files)
(HERE / f"{sys.argv[1]}.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({k: v for k, v in record.items() if k != "files"}, ensure_ascii=False))
print(f"入力 {len(files)} ファイル")
