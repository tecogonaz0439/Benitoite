#!/usr/bin/env python3
"""L00a.01 の入力と既存成果物を読む。ビルドせず、隣の JSON だけを書く。"""

import ast
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import time


START = time.monotonic()
HERE = pathlib.Path(__file__).resolve().parent
CHANGE = HERE.parent
ROOT = HERE.parents[2]
FORMAL = ROOT / "formal"
B0 = "80e8127a4f7edff946529153b2002666cc35edc1"
B_WORK = "9506fb623d9b26750177521933b50a9f67dd0346"


def command(args, cwd=ROOT):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError((args, result.returncode, result.stderr))
    return {"command": args, "exit_code": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr}


def describe(path):
    data = path.read_bytes()
    stat = path.stat()
    return {"path": str(path.relative_to(ROOT)) if path.is_relative_to(ROOT)
            else str(path), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "mtime_ns": stat.st_mtime_ns,
            "mtime": datetime.datetime.fromtimestamp(
                stat.st_mtime, datetime.timezone.utc).isoformat()}


def tracked_files(revision, paths):
    # ls-tree はオブジェクトを読むだけであり、index・ref・作業ツリーを変えない。
    raw = subprocess.check_output(
        ["git", "ls-tree", "-rz", revision, "--"] + paths, cwd=ROOT)
    rows = []
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, kind, expected = metadata.decode().split()
        assert kind == "blob" and mode in ("100644", "100755"), (mode, kind, name)
        path = ROOT / name.decode()
        data = path.read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
        rows.append({**describe(path), "git_mode": mode, "git_blob": expected,
                     "matches_revision": actual == expected and
                     bool(path.stat().st_mode & 0o111) == (mode == "100755")})
    return rows


# この lakefile の文字列・配列・[[lean_exe]] だけを読む。汎用 TOML 解析器ではない。
# 標準 Python 3.9.6 に tomllib がないため、依存や設定を追加しない。
config = (FORMAL / "lakefile.toml").read_text()
default_targets = ast.literal_eval(re.search(
    r"^defaultTargets = (\[[^\n]+\])$", config, re.M).group(1))
more_lean_args = ast.literal_eval(re.search(
    r"^moreLeanArgs = (\[[^\n]+\])$", config, re.M).group(1))
exe_roots = {}
for block in config.split("[[lean_exe]]")[1:]:
    block = block.split("[[", 1)[0]
    exe_roots[re.search(r'^name = "([^"]+)"$', block, re.M).group(1)] = re.search(
        r'^root = "([^"]+)"$', block, re.M).group(1)
roots = {name: exe_roots.get(name, name) for name in default_targets}
sources = {str(p.relative_to(FORMAL).with_suffix("")).replace("/", "."): p
           for p in FORMAL.rglob("*.lean") if ".lake" not in p.parts}


def imports(path):
    # 入れ子のブロックコメントを除き、import 行の複数モジュールを読む。
    data = path.read_text()
    depth = 0
    lines = []
    for line in data.splitlines():
        visible = ""
        i = 0
        while i < len(line):
            if line[i:i + 2] == "/-":
                depth += 1
                i += 2
            elif depth and line[i:i + 2] == "-/":
                depth -= 1
                visible += " "
                i += 2
            elif depth:
                i += 1
            elif line[i:i + 2] == "--":
                break
            elif line[i] == '"':
                # 文字列の内部のコメント記号を解釈しない。
                visible += " "
                i += 1
                while i < len(line):
                    if line[i] == "\\":
                        i += 2
                    elif line[i] == '"':
                        i += 1
                        break
                    else:
                        i += 1
            else:
                visible += line[i]
                i += 1
        match = re.match(r"^\s*(?:(?:public|private|meta)\s+)*import\s+(.+)$", visible)
        if match:
            names = match.group(1).split()
            assert all(re.fullmatch(r"[A-Za-z_][A-Za-z_0-9.]*", n) for n in names)
            lines.extend(names)
    return lines


edges = {name: imports(path) for name, path in sources.items()}
seen, external = set(), set()


def visit(name):
    if name in seen:
        return
    if name not in sources:
        external.add(name)
        return
    seen.add(name)
    for dep in edges[name]:
        visit(dep)


for root in roots.values():
    visit(root)
rows = []
for name in sorted(seen):
    source = describe(sources[name])
    path = FORMAL / ".lake/build/lib/lean" / (name.replace(".", "/") + ".olean")
    artifact = describe(path) if path.exists() else None
    rows.append({"module": name, "imports": edges[name], "source": source,
                 "olean": artifact, "not_older_than_source": artifact is not None
                 and artifact["mtime_ns"] >= source["mtime_ns"]})

tools = {name: command([name, "--version"], FORMAL) for name in ("lean", "lake", "elan")}
tools["python"] = {"version": sys.version, "executable": sys.executable}
prefix = pathlib.Path(command(["lean", "--print-prefix"], FORMAL)["stdout"].strip())
toolchain = {"fixed": (FORMAL / "lean-toolchain").read_text().strip(),
             "prefix": str(prefix), "lean_executable": describe(prefix / "bin/lean"),
             "lake_executable": describe(prefix / "bin/lake")}
external_rows = [{"module": name,
                  "source": describe(prefix / "src/lean" / (name.replace(".", "/") + ".lean")),
                  "olean": describe(prefix / "lib/lean" / (name.replace(".", "/") + ".olean"))}
                 for name in sorted(external)]
commands = [command(["git", "diff", "--stat", B0, B_WORK, "--", "formal"]),
            command(["git", "rev-parse", "HEAD"]),
            command(["git", "diff", "--name-only", B_WORK, "--", "formal", "scripts/check.sh"])]
input_rows = tracked_files(B_WORK, ["formal", "scripts/check.sh", str(CHANGE.relative_to(ROOT))])
missing = [r["module"] for r in rows if r["olean"] is None]
older = [r["module"] for r in rows if r["olean"] and not r["not_older_than_source"]]
build_start = datetime.datetime.fromisoformat("2026-10-30T19:44:31+09:00").timestamp()
build_end = datetime.datetime.fromisoformat("2026-10-30T19:47:59+09:00").timestamp()
outside_build = [r["module"] for r in rows if r["olean"] and not
                 build_start <= r["olean"]["mtime_ns"] / 1e9 <= build_end]
unexpected_artifacts = sorted(str(p.relative_to(FORMAL))
    for p in (FORMAL / ".lake/build/lib/lean").rglob("*.olean")
    if str(p.relative_to(FORMAL / ".lake/build/lib/lean").with_suffix("")).replace("/", ".") not in seen)
summary = {"local_source_count": len(sources), "default_module_count": len(rows),
           "outside_default_imports": sorted(set(sources) - seen),
           "missing_olean": missing, "older_olean": older,
           "olean_outside_wl0_interval": outside_build,
           "unexpected_olean": unexpected_artifacts,
           "tracked_input_count": len(input_rows),
           "tracked_input_mismatches": [r["path"] for r in input_rows if not r["matches_revision"]]}
result = {"captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
          "B0": B0, "B_WORK": B_WORK, "commands": commands, "tools": tools,
          "toolchain": toolchain, "default_targets": roots, "moreLeanArgs": more_lean_args,
          "summary": summary, "modules": rows, "external_direct_imports": external_rows,
          "inputs_at_B_WORK": input_rows,
          "wl0_record": describe(CHANGE / "l00a.01a/wl0-measure.md"),
          "inventory_script": describe(pathlib.Path(__file__)),
          "elapsed_seconds": round(time.monotonic() - START, 6)}
(HERE / "inventory.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"summary": summary, "elapsed_seconds": result["elapsed_seconds"]},
                 ensure_ascii=False, indent=2))
assert not any((missing, older, outside_build, unexpected_artifacts,
                summary["tracked_input_mismatches"]))
assert commands[0]["stdout"] == commands[2]["stdout"] == ""
assert commands[1]["stdout"].strip() == B_WORK
assert toolchain["fixed"] == "leanprover/lean4:v4.34.1"
assert "version 4.34.1," in tools["lean"]["stdout"]
