"""文脈の群末のビルド・境界・署名・公理依存を記録する。git は使わない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FORMAL = ROOT / "formal"
RAW = Path(tempfile.gettempdir())
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
NEW = ["formal/Benitoite/Release/Refinement/Context/" + n + ".lean"
       for n in ("WF", "Facts", "Declarations", "Capture")]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(name, data):
    if isinstance(data, str):
        data = data.encode()
    place = RAW if len(data) > 100_000 else HERE
    (place / name).write_bytes(data)
    item = {"name": name, "bytes": len(data), "sha256": sha(data),
            "storage": "<tmp>" if place == RAW else "改造/l00b.03"}
    if place == RAW:
        with (HERE / "large-records.md").open("a") as f:
            f.write(f"| `{name}` | {len(data)} | `{item['sha256']}` |\n")
    return item


def write(name, value):
    return save(name, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    start = json.loads((RAW / "benitoite-l00b03-inputs-start.json").read_text())
    inputs = {str(p.relative_to(ROOT)): sha(p.read_bytes())
              for p in sorted(FORMAL.rglob("*.lean")) if ".lake" not in p.parts}
    inputs.update({str(p.relative_to(ROOT)): sha(p.read_bytes())
                   for p in (FORMAL / "lakefile.toml", FORMAL / "lean-toolchain")})
    write("inputs-final.json", inputs)
    prior = json.loads((HERE.parent / "l00b.02/02c-inputs-final.json").read_text())
    assert inputs["formal/lean-toolchain"] == prior["formal/lean-toolchain"]
    start["files"]["formal/lean-toolchain"] = prior["formal/lean-toolchain"]
    changes = [{"path": n, "before": start["files"].get(n), "after": h}
               for n, h in inputs.items() if start["files"].get(n) != h]
    assert {x["path"] for x in changes} == set(NEW) | {"formal/Benitoite.lean"}, changes
    addition = "\n" + "".join("import " + n.removeprefix("formal/").removesuffix(".lean").replace("/", ".") + "\n"
                               for n in NEW)
    entry = (FORMAL / "Benitoite.lean").read_text()
    assert entry.endswith(addition)
    assert sha(entry[:-len(addition)].encode()) == start["files"]["formal/Benitoite.lean"]
    protected_changes = [n for n, h in start["files"].items() if n != "formal/Benitoite.lean" and
                         (not (ROOT / n).exists() or sha((ROOT / n).read_bytes()) != h)]
    assert not protected_changes, protected_changes
    write("source-changes.json", changes)
    forbidden = [n for n in NEW if re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|extern)\b",
                                            (ROOT / n).read_text())]
    assert not forbidden, forbidden
    records = []

    def run(label, command):
        tick = time.monotonic()
        began = datetime.datetime.now(datetime.timezone.utc).isoformat()
        result = subprocess.run(command, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        elapsed = time.monotonic() - tick
        data = result.stdout.replace(str(ROOT).encode(), b"<repo>").replace(str(Path.home()).encode(), b"<home>")
        artifact = save(label + ".log", data)
        records.append({"label": label, "command": command, "cwd": "formal", "started_utc": began,
                        "elapsed_seconds": elapsed, "exit": result.returncode, "output": artifact})
        write("commands.json", records)
        print(label, "終了", result.returncode, "外側", round(elapsed, 3), "秒", flush=True)
        assert result.returncode == 0, data.decode()[-3000:]
        assert not re.search(rb"declaration uses .sorry.|sorryAx", data), label
        return data

    build = run("build", ["lake", "build"])
    version = run("lean-version", ["lake", "env", "lean", "-M", "12288", "--version"])
    prefix = "../" + str(HERE.relative_to(ROOT)) + "/"
    boundary = run("boundary", ["lake", "env", "lean", "-M", "12288", prefix + "boundary.lean"])
    assert b"warning:" not in boundary and b"error:" not in boundary
    public_api = run("public-api", ["lake", "env", "lean", "-M", "12288", prefix + "public-api.lean"])
    assert b"warning:" not in public_api and b"error:" not in public_api
    save("public-api.md", "# 完全な公開署名\n\n```text\n".encode() + public_api + b"\n```\n")
    axioms = run("axioms", ["lake", "env", "lean", "-M", "12288", prefix + "axioms.lean"])
    names = re.findall(rb"^'(.+)' (?:depends on axioms|does not depend)", axioms, re.M)
    modules = [{"module": n.decode(), "declarations": int(c)}
               for n, c in re.findall(rb"^MODULE ([^:]+): (\d+)$", axioms, re.M)]
    assert len(names) == len(set(names)) == sum(m["declarations"] for m in modules) + 7
    used = {a.strip().decode() for group in re.findall(rb"depends on axioms:\s*\[([^\]]*)\]", axioms)
            for a in group.split(b",") if a.strip()}
    boundary_used = {a.strip().decode() for group in re.findall(rb"depends on axioms:\s*\[([^\]]*)\]", boundary)
                     for a in group.split(b",") if a.strip()}
    assert used <= ALLOWED and boundary_used <= ALLOWED, (used, boundary_used)
    save("axiom-targets.txt", b"\n".join(names) + b"\n")
    write("axioms-summary.json", {"modules": modules, "declarations": len(names),
          "new_modules": [m for m in modules if m["module"].startswith("Benitoite.Release.Refinement.Context.")],
          "used": sorted(used), "boundary_used": sorted(boundary_used), "rejected": []})
    inventory = re.findall(rb"^(?:CONSTRUCTORS|SHARED_CONSTRUCTORS|CONTEXT_CONSTRUCTORS|MUTUAL_TYPES|SOURCE_CONSTRUCTORS).*", axioms, re.M)
    save("case-inventory.txt", b"\n".join(inventory) + b"\n")
    case_names = re.findall(r"^theorem\s+(\w+)", (HERE / "boundary.lean").read_text(), re.M)
    write("boundary-inventory.json", {"named_theorems": len(case_names), "names": case_names,
          "environment_declarations": int(re.search(rb"BOUNDARY_DECLARATIONS (\d+)", boundary).group(1))})
    for label, file in (("closures-compat", "02b-closures-r4-public-api"), ("shared-compat", "02c-public-api")):
        prior = HERE.parent / "l00b.02" / (file + ".lean")
        output = run(label, ["lake", "env", "lean", "-M", "12288", "../" + str(prior.relative_to(ROOT))])
        assert output == prior.with_suffix(".log").read_bytes(), label
    for name in ("boundary-first", "boundary-extra-first"):
        save(name + ".log", (RAW / ("benitoite-l00b03-" + name + ".log")).read_bytes())
    assert all(sha((ROOT / n).read_bytes()) == h for n, h in inputs.items())
    count_public = len((HERE / "public-targets.txt").read_text().splitlines())
    assert len(re.findall(rb"^Benitoite\.", public_api, re.M)) == count_public
    write("validation.json", {"base_work": start["base"], "branch": "m014/l00b.03",
          "input_count": len(inputs), "production_changes": changes,
          "toolchain_baseline": "l00b.02/02c-inputs-final.json の同一ハッシュ",
          "protected_input_count": len(start["files"]) - 1, "protected_changes": protected_changes,
          "public_signatures": count_public, "boundary_theorems": len(case_names),
          "axiom_declarations": len(names), "axiom_modules": len(modules),
          "new_declarations": sum(m["declarations"] for m in modules if m["module"].startswith("Benitoite.Release.Refinement.Context.")),
          "allowed_axioms": sorted(ALLOWED), "used_axioms": sorted(used), "forbidden_tokens": forbidden,
          "compatibility_outputs_identical": ["closures", "shared"], "default_imports_additions_only": True,
          "build_memory_mib_per_lean_process": 12288, "explicit_lean_memory_mib": 12288,
          "rss": "未取得（計画上の非採取）", "git": "未実行", "work": "取りまとめが担当するため未実行",
          "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()})
    print("公理依存", len(names), "宣言、許可外0件。固定対象の変更0件。", flush=True)


def audit_old():
    tick = time.monotonic()
    began = datetime.datetime.now(datetime.timezone.utc).isoformat()
    command = ["lake", "env", "lean", "-M", "12288", "../" + str(HERE.relative_to(ROOT)) + "/old-axioms.lean"]
    result = subprocess.run(command, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    data = result.stdout.replace(str(ROOT).encode(), b"<repo>").replace(str(Path.home()).encode(), b"<home>")
    record = {"label": "old-main-axioms", "command": command, "cwd": "formal", "started_utc": began,
              "elapsed_seconds": time.monotonic() - tick, "exit": result.returncode,
              "output": save("old-main-axioms.log", data)}
    records = json.loads((HERE / "commands.json").read_text())
    records.append(record)
    write("commands.json", records)
    assert result.returncode == 0
    names = re.findall(rb"^'(.+)' (?:depends on axioms|does not depend)", data, re.M)
    used = {a.strip().decode() for group in re.findall(rb"depends on axioms:\s*\[([^\]]*)\]", data)
            for a in group.split(b",") if a.strip()}
    assert len(names) == 5 and used <= ALLOWED
    summary = json.loads((HERE / "axioms-summary.json").read_text())
    summary["old_main"] = {"declarations": [n.decode() for n in names], "used": sorted(used)}
    summary["total_with_old_main"] = summary["declarations"] + len(names)
    write("axioms-summary.json", summary)
    validation = json.loads((HERE / "validation.json").read_text())
    validation["supplemental_old_main_declarations"] = len(names)
    validation["total_axiom_declarations"] = summary["total_with_old_main"]
    write("validation.json", validation)
    print("旧主定理", len(names), "宣言の追加照合、終了0、許可外0件。")


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["--old-main"]:
        audit_old()
    else:
        main()
        audit_old()
