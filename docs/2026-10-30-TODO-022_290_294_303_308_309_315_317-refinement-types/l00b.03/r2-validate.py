"""レビュー対応後の既定ビルド・境界・公理依存を検査する。git と work は使わない。"""
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


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(name, data):
    if isinstance(data, str):
        data = data.encode()
    dest = RAW if len(data) > 100_000 else HERE
    (dest / name).write_bytes(data)
    info = {"name": name, "bytes": len(data), "sha256": sha(data), "storage": "<tmp>" if dest == RAW else "改造/l00b.03"}
    if dest == RAW:
        with (HERE / "large-records.md").open("a") as f:
            f.write(f"| `{name}` | {len(data)} | `{info['sha256']}` |\n")
    return info


def write(name, value):
    return save(name, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def inputs():
    ps = [p for p in FORMAL.rglob("*.lean") if ".lake" not in p.parts]
    ps += [FORMAL / "lakefile.toml", FORMAL / "lean-toolchain"]
    return {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in sorted(ps)}


def protected_check(start):
    allowed = {"formal/Benitoite/Release/Refinement/Context/" + n + ".lean" for n in ("WF", "Facts", "Declarations", "Capture")}
    allowed.add(str((HERE.parent / "l00b.02/signatures.md").relative_to(ROOT)))
    changed = []
    for n, h in start["files"].items():
        p = ROOT / n
        if p.exists() and sha(p.read_bytes()) == h:
            continue
        if n in allowed:
            continue
        if p.parent == HERE and not p.name.startswith("rv-"):
            continue
        changed.append(n)
    assert not changed, changed
    return changed


def main():
    start = json.loads((RAW / "l00b03-r2-start.json").read_text())
    protected_check(start)
    fixed = inputs()
    write("r2-inputs.json", fixed)
    changes = [{"path": n, "before": start["files"].get(n), "after": h}
               for n, h in fixed.items() if start["files"].get(n) != h]
    assert {x["path"] for x in changes} == {"formal/Benitoite/Release/Refinement/Context/" + n + ".lean"
                                           for n in ("WF", "Facts", "Declarations", "Capture")}
    write("r2-source-changes.json", changes)
    commands = []

    def run(label, cmd):
        tick = time.monotonic()
        began = datetime.datetime.now(datetime.timezone.utc).isoformat()
        result = subprocess.run(cmd, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        data = result.stdout.replace(str(ROOT).encode(), b"<repo>").replace(str(Path.home()).encode(), b"<home>")
        commands.append({"label": label, "command": cmd, "cwd": "formal", "started_utc": began,
                         "exit": result.returncode, "elapsed_seconds": time.monotonic() - tick,
                         "input_sha256": sha((FORMAL / cmd[-1]).read_bytes()) if cmd[-1].endswith(".lean") else None,
                         "output": save("r2-" + label + ".log", data)})
        write("r2-commands.json", commands)
        print(label, "終了", result.returncode, "外側", round(commands[-1]["elapsed_seconds"], 3), "秒", flush=True)
        assert result.returncode == 0, data.decode()[-3000:]
        assert not re.search(rb"declaration uses .sorry.|sorryAx", data)
        return data

    run("build", ["lake", "build"])
    prefix = "../" + str(HERE.relative_to(ROOT)) + "/"
    boundary = run("boundary", ["lake", "env", "lean", "-M", "12288", prefix + "boundary.lean"])
    assert b"warning:" not in boundary and b"error:" not in boundary
    public = run("public-api", ["lake", "env", "lean", "-M", "12288", prefix + "r2-public-api.lean"])
    assert b"warning:" not in public and b"error:" not in public
    ax = run("axioms", ["lake", "env", "lean", "-M", "12288", prefix + "r2-axioms.lean"])
    modules = [{"module": n.decode(), "declarations": int(k)}
               for n, k in re.findall(rb"^MODULE ([^:]+): (\d+)$", ax, re.M)]
    names = re.findall(rb"^'(.+)' (?:depends on axioms|does not depend)", ax, re.M)
    assert len(names) == len(set(names)) == sum(m["declarations"] for m in modules) + 12
    used = {a.strip().decode() for data in (ax, boundary)
            for group in re.findall(rb"depends on axioms:\s*\[([^\]]*)\]", data)
            for a in group.split(b",") if a.strip()}
    assert used <= ALLOWED
    new = [m for m in modules if m["module"].startswith("Benitoite.Release.Refinement.Context.")]
    write("r2-axioms-summary.json", {"modules": len(modules), "declarations": len(names),
          "context_modules": new, "context_declarations": sum(m["declarations"] for m in new),
          "used": sorted(used), "rejected": [],
          "boundary_declarations": int(re.search(rb"BOUNDARY_DECLARATIONS (\d+)", boundary).group(1))})
    save("r2-axiom-targets.txt", b"\n".join(names) + b"\n")
    save("r2-case-inventory.txt", b"\n".join(re.findall(rb"^(?:CONSTRUCTORS|CONTEXT_CONSTRUCTORS|SHARED_CONSTRUCTORS|MUTUAL_TYPES|SOURCE_CONSTRUCTORS).*", ax, re.M)) + b"\n")
    count_public = len((HERE / "r2-public-targets.txt").read_text().splitlines())
    assert len(re.findall(rb"^Benitoite\.", public, re.M)) == count_public
    counts = {}
    for p in sorted((FORMAL / "Benitoite/Release/Refinement/Context").glob("*.lean")):
        text = p.read_text()
        counts[p.name] = {"public_definitions": len(re.findall(r"^(?:@\[[^\n]+\]\s*)?(?:def|structure)\s+", text, re.M)),
                         "public_theorems": len(re.findall(r"^(?:@\[[^\n]+\]\s*)?theorem\s+", text, re.M)),
                         "private_theorems": len(re.findall(r"^private theorem\s+", text, re.M))}
    write("r2-declaration-counts.json", counts)
    assert inputs() == fixed
    protected_check(start)
    forbidden = [n for n in fixed if "/Refinement/Context/" in n and
                 re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|extern)\b", (ROOT / n).read_text())]
    assert not forbidden
    write("r2-validation.json", {"base_work": "5016f55febc6973855c37dc22fda24a6317e2b28",
          "input_count": len(fixed), "protected_changes": [], "public_signatures": count_public,
          "boundary_theorems": len(re.findall(r"^theorem\s+", (HERE / "boundary.lean").read_text(), re.M)),
          "axiom_declarations": len(names), "context_declarations": sum(m["declarations"] for m in new),
          "allowed_axioms": sorted(ALLOWED), "used_axioms": sorted(used), "forbidden": forbidden,
          "memory_mib_per_lean_process": 12288, "rss": "未取得（計画上の非採取）",
          "git": "未実行", "work": "未実行", "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()})
    print("公理依存", len(names), "宣言、許可外0件、固定対象の変更0件。", flush=True)


if __name__ == "__main__":
    main()
