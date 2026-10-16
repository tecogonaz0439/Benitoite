"""M6a の確認済みパッチを一時ディレクトリへ順に適用し、元の入力を変更せず照合する。"""

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def check_file(path, expected):
    require(digest(path.read_bytes()) == expected, f"hash mismatch: {path}")


def apply(directory, patch, reverse=False):
    command = ["git", "apply", "--whitespace=error-all"]
    if reverse:
        command.append("--reverse")
    subprocess.run([*command, "--check", str(patch)], cwd=directory, check=True)
    subprocess.run([*command, str(patch)], cwd=directory, check=True)


def main():
    manifest = json.loads((HERE / "manifest.json").read_text())
    for name, expected in manifest["artifacts"].items():
        check_file(HERE / name, expected)
    inventory = json.loads((HERE / "inventory.json").read_text())
    require(all(row["reviewed"] for row in inventory["candidates"]), "unreviewed candidate")
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    active = {
        path for path in tracked
        if path and not path.startswith(tuple(inventory["excluded_prefixes"]))
    }
    require(active == {row["path"] for row in inventory["files"]}, "source file set changed")
    # HEAD は作業の記録であり、文書だけの取り込みでは変わる。適用の条件は実際のバイト内容である。
    for row in inventory["files"]:
        path = ROOT / row["path"]
        data = str(path.readlink()).encode() if path.is_symlink() else path.read_bytes()
        require(digest(data) == row["sha256"], f"source changed: {row['path']}")
    patches = manifest["stages"]
    require([row["order"] for row in patches] == list(range(1, len(patches) + 1)), "patch order")
    with tempfile.TemporaryDirectory(prefix="benitoite-m6a-verify-") as temporary:
        directory = Path(temporary)
        paths = {row["path"] for patch in patches for row in patch["files"]}
        for path in paths:
            target = directory / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / path).read_bytes())
        for patch in patches:
            source = HERE / patch["path"]
            check_file(source, patch["sha256"])
            for row in patch["files"]:
                check_file(directory / row["path"], row["before_sha256"])
            apply(directory, source)
            for row in patch["files"]:
                check_file(directory / row["path"], row["after_sha256"])
        for package in json.loads((HERE / "packages.json").read_text()):
            root = Path(package["config"]).parent
            for row in package["files"]:
                path = root / row["path"]
                check_file(ROOT / path, row["before_sha256"])
                after = directory / path if path.as_posix() in paths else ROOT / path
                check_file(after, row["after_sha256"])
        # 二度適用せず、逆順に戻して元のバイト内容との一致まで確かめる。
        for patch in reversed(patches):
            apply(directory, HERE / patch["path"], reverse=True)
        for path in paths:
            require((directory / path).read_bytes() == (ROOT / path).read_bytes(), path)
    for package in json.loads((HERE / "hashes.json").read_text()):
        for phase, key in [("before", "old"), ("after", "new")]:
            summary = "".join(
                f"{row[phase + '_sha256']}  {row['path']}\n"
                for row in sorted(package["files"], key=lambda row: row["path"].encode())
            ).encode()
            require("sha256:" + digest(summary) == package[key], package["label"])
    print(f"verified: {len(patches)} ordered patches, {len(paths)} files; reverse apply restored all bytes")
    print(f"reviewed: {len(inventory['candidates'])} candidates; 3 independent package hash summaries")


if __name__ == "__main__":
    main()
