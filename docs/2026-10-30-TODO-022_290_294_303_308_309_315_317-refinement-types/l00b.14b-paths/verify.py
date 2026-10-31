#!/usr/bin/env python3
"""既定ビルド、境界、公開署名、全差分を含む公理依存を検査する。git は使用しない。"""
from pathlib import Path
import datetime, hashlib, json, re, subprocess, sys, tempfile, time

root = Path(__file__).resolve().parents[3]
base = Path(__file__).resolve().parent
allowed = {"propext", "Quot.sound", "Classical.choice"}


def digest(path):
    data = path.read_bytes()
    return dict(path=str(path.relative_to(root)), bytes=len(data), sha256=hashlib.sha256(data).hexdigest())


def api_blocks(text):
    heads = list(re.finditer(r"^Benitoite\.Release\.Refinement\.[^\s(]+", text, re.M))
    return {h.group(): re.sub(r"\s+", " ", text[h.start():heads[i+1].start() if i+1<len(heads) else len(text)]).strip()
            for i,h in enumerate(heads)}


if sys.argv[1:] == ["--check-hashes"]:
    count = 0
    for manifest in ("source-inputs.json", "reference-inputs.json", "source-delta.json", "files.json"):
        for row in json.loads((base / manifest).read_text())["files"]:
            assert digest(root / row["path"]) == row, row["path"]
            count += 1
    print(json.dumps(dict(hash_records=count, matched=True)))
    raise SystemExit(0)

scratch = Path(tempfile.mkdtemp(prefix="benitoite-paths-"))
records = json.loads((base / "verification.json").read_text()) if sys.argv[1:] else []
commands = [
    ("build", ["lake", "build"]),
    *[(label,["lake","env","lean","-M","12288","../"+str((base / (label+".lean")).relative_to(root))])
      for label in ("boundary","match-boundary","public-api","axioms")],
]
for label, args in commands:
    if sys.argv[1:] and label not in sys.argv[1:]:
        continue
    records = [r for r in records if r["label"] != label]
    started = time.monotonic()
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    raw = scratch / (label + ".log")
    with raw.open("wb") as out:
        proc = subprocess.run(args,cwd=root / "formal",stdout=out,stderr=subprocess.STDOUT)
    data = raw.read_bytes()
    output = data.decode()
    record = dict(label=label,command="cd formal && "+" ".join(args),started_utc=timestamp,
                  exit_code=proc.returncode,seconds=round(time.monotonic()-started,3),
                  bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
    if proc.returncode == 0:
        if label == "build":
            assert '"-M", "12288"' in (root / "formal/lakefile.toml").read_text()
        if label in ("axioms","boundary","match-boundary"):
            dependencies=set()
            lines=output.splitlines()
            for i,line in enumerate(lines):
                if "depends on axioms:" in line:
                    value=line.split("depends on axioms:",1)[1]
                    j=i+1
                    while "]" not in value and j<len(lines):
                        value+=lines[j];j+=1
                    value=re.sub(r"\.\{[^}]*\}","",value)
                    dependencies.update(re.findall(r"[A-Za-z_][A-Za-z0-9_.]*",value))
            record["axioms"]=sorted(dependencies)
            record["axiom_reports"]=sum("depends on axioms:" in l or "does not depend on any axioms" in l for l in lines)
            assert not dependencies-allowed, dependencies
            assert record["axiom_reports"]>0
            if label=="axioms":
                modules=set(re.findall(r"AUDIT_MODULE (\S+)",output))
                changed={r["path"][7:-5].replace("/",".") for r in json.loads((base/"source-delta.json").read_text())["files"]}
                assert changed <= modules, changed-modules
                record["modules"]=len(modules)
                record["changed_modules"]=len(changed)
                record["changed_modules_covered"]=True
                (base/"axioms-summary.json").write_text(json.dumps(record,indent=2)+"\n")
                inventory=[l for l in lines if l.startswith(("cases ","THREE_FAMILY_CASES"))]
                (base/"case-inventory.txt").write_text("\n".join(inventory)+"\n")
        if label=="public-api":
            before=api_blocks((base/"primary-api-baseline.log").read_text())
            after=api_blocks(output)
            unchanged={name:after.get(name)==signature for name,signature in before.items()}
            assert len(unchanged)==10 and all(unchanged.values()),unchanged
            (base/"primary-api-comparison.json").write_text(json.dumps(dict(
                baseline=digest(base/"primary-api-baseline.log"),
                method="前回停止時の #check 出力との空白を除く比較。VQ/CQ の5操作ずつ。",
                unchanged=unchanged),ensure_ascii=False,indent=2)+"\n")
            record["unchanged_primary_signatures"]=10
            # 再レビューの契約: 除外の入力は根の形で、型付けから構成できる。
            prefix="Benitoite.Release.Refinement.MatchFacts."
            for name in ("excluded_true","excluded_evalClosed_true","excluded_paths_true"):
                signature=after[prefix+name]
                assert "RootShape P a v" in signature and "Inhabits" not in signature, signature
            for name in ("rootShape_of_typing","excluded_true_of_typing",
                         "excluded_evalClosed_true_of_typing","excluded_paths_true_of_typing"):
                assert "HasTypeVQ" in after[prefix+name], name
            assert "theorem HasTypeArmsQ.guard_context" not in (root/"formal/Benitoite/Release/Refinement/StateTyping.lean").read_text()
            record["root_shape_exclusion_signatures"]=3
            record["closed_typing_entry_signatures"]=4
            record["guard_context_removed"]=True
            # 宣言の境界で分け、完全署名を改造内でも読めるようにする。
            starts=[m.start() for m in re.finditer(r"^Benitoite\.Release\.Refinement\.[^\s(]+",output,re.M)]+[len(output)]
            chunks=[]; chunk=""
            for i in range(len(starts)-1):
                block=output[starts[i]:starts[i+1]]
                if len((chunk+block).encode())>80_000 and chunk:
                    chunks.append(chunk);chunk=""
                chunk+=block
            if chunk:chunks.append(chunk)
            record["signature_parts"]=[]
            for i,chunk in enumerate(chunks,1):
                part=base/f"public-api-{i}.log"
                part.write_text(chunk)
                record["signature_parts"].append(digest(part))
    if len(data)<=100_000:
        (base/(label+".log")).write_text(output.replace(str(root),"<repo>").replace(str(Path.home()),"<home>"))
    else:
        (base/(label+".log")).write_text("生の記録は <tmp> に保存した。\n"+json.dumps(record,ensure_ascii=False,indent=2)+"\n")
    records.append(record)
    (base/"verification.json").write_text(json.dumps(records,indent=2)+"\n")
    print(json.dumps(record),flush=True)
    if proc.returncode:
        raise SystemExit(proc.returncode)
large=[r for r in records if r["bytes"]>100_000]
(base/"large-records.md").write_text("# 大きな生の記録\n\n<tmp> に保存した。手元の絶対パスは記録しない。\n\n| 記録 | バイト数 | SHA-256 |\n|---|---:|---|\n"+"".join(f"| {r['label']}.log | {r['bytes']} | {r['sha256']} |\n" for r in large))
