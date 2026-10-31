"""既定ビルド・閉じた評価の境界・全宣言の公理依存を検査する。git/workは使わない。"""
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
RAW = Path(tempfile.gettempdir()) / json.loads((HERE / "record-location.json").read_text())["tmp_name"]
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
NEW_MODULES = {"Observation", "ClosedDecidable", "ClosedEvaluation", "ClosedKeys", "LogicSound", "Carrier", "ExternalCheck"}
MODIFIED = {"formal/Benitoite.lean", "formal/Benitoite/Release/Refinement/Logic.lean", "formal/Benitoite/Release/Refinement/Basic.lean"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def save(name, data):
    if isinstance(data, str):
        data = data.encode()
    dest = RAW if len(data) > 100_000 else HERE
    (dest / name).write_bytes(data)
    result = {"name": name, "bytes": len(data), "sha256": sha(data), "storage": "<tmp>" if dest == RAW else "改造/l00b.04"}
    if dest == RAW:
        with (HERE / "large-records.md").open("a") as f:
            f.write(f"| `{name}` | {len(data)} | `{result['sha256']}` |\n")
    return result


def write(name, value):
    return save(name, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def inputs():
    ps = [p for p in FORMAL.rglob("*.lean") if ".lake" not in p.parts]
    ps += [FORMAL / "lakefile.toml", FORMAL / "lean-toolchain"]
    return {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in sorted(ps)}


def main():
    baseline = json.loads((RAW / "baseline.json").read_text())
    (HERE / "large-records.md").write_text("# 大きな生の記録\n\n100 KBを超える生の記録は `<tmp>` に置く。所在のディレクトリ名は record-location.json に記録する。台本はOSの一時ディレクトリからその名前を解決する。\n\n| ファイル | bytes | SHA-256 |\n|---|---:|---|\n")
    save("baseline.json", (RAW / "baseline.json").read_bytes())
    for n, h in baseline["protected"].items():
        assert sha((ROOT / n).read_bytes()) == h, n
    fixed = inputs()
    previous_inputs = json.loads((HERE/"inputs.json").read_text()) if (HERE/"inputs.json").exists() else None
    previous_records = json.loads((HERE/"commands.json").read_text()) if (HERE/"commands.json").exists() else []
    write("inputs.json", fixed)
    changes = [{"path": n, "before": baseline["formal"].get(n), "after": h}
               for n,h in fixed.items() if n.endswith(".lean") and baseline["formal"].get(n) != h]
    expected = MODIFIED | {"formal/Benitoite/Release/Refinement/"+m+".lean" for m in NEW_MODULES}
    assert {c["path"] for c in changes} == expected
    write("source-changes.json", changes)
    assert 'moreLeanArgs = ["-M", "12288"]' in (FORMAL / "lakefile.toml").read_text()
    records = []

    def run(label, args):
        old = next((r for r in previous_records if r["label"]==label and r["exit"]==0 and r["command"]==args), None)
        input_sha = sha((FORMAL/args[-1]).read_bytes()) if args[-1].endswith(".lean") else None
        if previous_inputs==fixed and old and old["input_sha256"]==input_sha:
            info=old["output"]
            out=((RAW if info["storage"]=="<tmp>" else HERE)/info["name"]).read_bytes()
            assert sha(out)==info["sha256"]
            assert not re.search(rb"declaration uses .sorry.|sorryAx|error:|warning:",out)
            save(info["name"],out)
            records.append(old)
            print(label,"同じ入力での終了0を引用、再実行なし。",flush=True)
            return out
        start = time.monotonic()
        began = datetime.datetime.now(datetime.timezone.utc).isoformat()
        result = subprocess.run(args, cwd=FORMAL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = result.stdout.replace(str(ROOT).encode(), b"<repo>").replace(str(Path.home()).encode(), b"<home>")
        records.append({"label": label, "command": args, "cwd": "formal", "started_utc": began,
                        "exit": result.returncode, "elapsed_seconds": time.monotonic()-start,
                        "input_sha256": sha((FORMAL / args[-1]).read_bytes()) if args[-1].endswith(".lean") else None,
                        "output": save(label+".log", out)})
        write("commands.json", records)
        print(label, "終了", result.returncode, "外側", round(records[-1]["elapsed_seconds"],3), "秒", flush=True)
        assert result.returncode == 0, out.decode()[-5000:]
        assert not re.search(rb"declaration uses .sorry.|sorryAx|error:", out)
        if label != "build":
            assert b"warning:" not in out
        else:
            assert not re.search(rb"warning: Benitoite/Release/Refinement/", out)
        return out

    # 同じ全入力で既に成功した既定ビルドは繰り返さず、元の記録を引用する。
    existing = next((r for r in previous_records if r["label"]=="build" and r["exit"]==0), None)
    if previous_inputs == fixed and existing:
        info=existing["output"]
        build_out=((RAW if info["storage"]=="<tmp>" else HERE)/info["name"]).read_bytes()
        assert sha(build_out)==info["sha256"]
        assert not re.search(rb"declaration uses .sorry.|sorryAx|error:|warning: Benitoite/Release/Refinement/",build_out)
        records.append(existing)
        print("build 同じ入力での終了0を引用、再実行なし。",flush=True)
    else:
        build_out=run("build", ["lake", "build"])
    warning_lines=[x.decode() for x in build_out.splitlines() if re.match(rb"^(warning:|ld64\.lld: warning:)",x)]
    write("build-warnings.json",{"warnings":len(warning_lines),"lines":warning_lines,
        "changed_refinement_warnings":0,"source_files_unchanged":True})
    prefix = "../" + str(HERE.relative_to(ROOT)) + "/"
    boundary = run("boundary", ["lake", "env", "lean", "-M", "12288", prefix+"boundary.lean"])
    public = run("public-api", ["lake", "env", "lean", "-M", "12288", prefix+"public-api.lean"])
    axioms = run("axioms", ["lake", "env", "lean", "-M", "12288", prefix+"axioms.lean"])
    write("commands.json",records)
    names = re.findall(rb"^'(.+)' (?:depends on axioms|does not depend)", axioms, re.M)
    modules = [{"module": n.decode(), "declarations": int(k)} for n,k in re.findall(rb"^MODULE ([^:]+): (\d+)$", axioms,re.M)]
    assert len(names) == len(set(names)) == sum(m["declarations"] for m in modules)+12
    used = {a.strip().decode() for out in [axioms,boundary]
            for group in re.findall(rb"depends on axioms:\s*\[([^\]]*)\]",out)
            for a in group.split(b",") if a.strip()}
    assert used <= ALLOWED, used-ALLOWED
    changed_modules = [m for m in modules if m["module"].rsplit(".",1)[-1] in NEW_MODULES | {"Logic","Basic"}]
    write("axioms-summary.json", {"modules":len(modules),"declarations":len(names),
          "new_or_changed_modules":changed_modules, "new_or_changed_declarations":sum(m["declarations"] for m in changed_modules),
          "used":sorted(used), "rejected":[],
          "boundary_declarations":int(re.search(rb"BOUNDARY_DECLARATIONS (\d+)",boundary).group(1))})
    save("axiom-targets.txt",b"\n".join(names)+b"\n")
    save("case-inventory.txt",b"\n".join(re.findall(rb"^(?:CONSTRUCTORS|CONTEXT_CONSTRUCTORS|SHARED_CONSTRUCTORS|MUTUAL_TYPES|SOURCE_CONSTRUCTORS).*",axioms,re.M))+b"\n")
    count_public=len((HERE/"public-targets.txt").read_text().splitlines())
    assert len(re.findall(rb"^Benitoite\.",public,re.M)) == count_public
    assert fixed == inputs()
    for n,h in baseline["protected"].items():
        assert sha((ROOT/n).read_bytes()) == h, n
    forbidden=[]
    for c in changes:
        if c["path"]=="formal/Benitoite.lean":
            continue
        text=(ROOT/c["path"]).read_text()
        if re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|extern)\b",text):
            forbidden.append(c["path"])
    assert not forbidden, forbidden
    for f in HERE.iterdir():
        if f.is_file() and f.stat().st_size>100_000:
            save(f.name,f.read_bytes())
            f.unlink()
    write("validation.json", {"base_work":"610bd4ebf54905d36c5ccaeb2f6126d7149448a4",
          "formal_inputs":len(fixed),"protected_inputs":len(baseline["protected"]),"protected_changes":[],
          "new_modules":sorted(NEW_MODULES),"changed_files":len(changes),"public_signatures":count_public,
          "boundary_theorems":len(re.findall(r"^theorem\s+",(HERE/"boundary.lean").read_text(),re.M)),
          "axiom_declarations":len(names),"allowed_axioms":sorted(ALLOWED),"used_axioms":sorted(used),
          "forbidden":forbidden,"lean_memory_mib":12288,"rss":"未取得（計画上の非採取）",
          "git":"未実行","work":"未実行","finished_utc":datetime.datetime.now(datetime.timezone.utc).isoformat()})
    print("全検査終了。許可外の公理0件、固定対象の変更0件。",flush=True)


if __name__=="__main__":
    main()
