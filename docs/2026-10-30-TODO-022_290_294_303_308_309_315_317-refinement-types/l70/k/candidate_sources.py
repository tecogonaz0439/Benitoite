"""保存した差分を読み取り専用で再構成し、前後のハッシュを照合する。"""
import hashlib
import json
from pathlib import Path
import re
from run_checks import HERE, ROOT


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def apply_unified(original, patch):
    old = original.splitlines(keepends=True)
    lines = patch.splitlines(keepends=True)
    assert lines[0].startswith("--- ") and lines[1].startswith("+++ ")
    out, cursor, i = [], 0, 2
    while i < len(lines):
        h = re.fullmatch(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@.*\n", lines[i])
        assert h, lines[i]
        start = max(0, int(h[1]) - 1)
        assert start >= cursor
        out.extend(old[cursor:start])
        cursor = start
        used = added = 0
        i += 1
        while i < len(lines) and not lines[i].startswith("@@ "):
            line = lines[i]
            assert line[0] in " +-", line
            if line[0] in " -":
                assert cursor < len(old) and old[cursor] == line[1:], (cursor, line)
                cursor += 1
                used += 1
            if line[0] in " +":
                out.append(line[1:])
                added += 1
            i += 1
        assert used == int(h[2] or 1) and added == int(h[4] or 1)
    out.extend(old[cursor:])
    return "".join(out)


def reconstruct():
    manifest = json.loads((HERE / "resume2-candidate.json").read_text())
    sources = {}
    for row in manifest["files"]:
        path = ROOT / row["file"]
        before = path.read_text() if row["before"] is not None else ""
        if row["before"] is None:
            assert not path.exists(), path
        else:
            assert sha(before) == row["before"], path
        patch = (HERE / row["patch"]).read_text()
        assert sha(patch) == row["patch_sha256"]
        after = apply_unified(before, patch)
        assert sha(after) == row["after"]
        sources[row["file"]] = after
    return sources


if __name__ == "__main__":
    data = reconstruct()
    print(json.dumps({"candidate_modules": len(data), "new_modules": sum(
        not (ROOT / name).exists() for name in data), "verification": "成功。候補の型検査の成功を意味しない"}, ensure_ascii=False))
