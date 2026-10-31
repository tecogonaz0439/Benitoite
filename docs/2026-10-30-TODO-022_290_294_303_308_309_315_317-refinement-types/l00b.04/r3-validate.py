"""群末レビューの修正を検査する。既定ビルド、公理依存、保護対象のハッシュを照合する。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import tempfile
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
FORMAL=ROOT/"formal"
RAW=Path(tempfile.gettempdir())/json.loads((HERE/"record-location.json").read_text())["tmp_name"]
ALLOWED={"propext","Quot.sound","Classical.choice"}
MODULES={"ClosedEvaluation"}

def sha(data):return hashlib.sha256(data).hexdigest()

def save(name,data):
    if isinstance(data,str):data=data.encode()
    dest=RAW if len(data)>100_000 else HERE
    (dest/name).write_bytes(data)
    info={"name":name,"bytes":len(data),"sha256":sha(data),"storage":"<tmp>" if dest==RAW else "改造/l00b.04"}
    if dest==RAW:
        with (HERE/"r3-large-records.md").open("a") as f:f.write(f"| `{name}` | {len(data)} | `{info['sha256']}` |\n")
    return info

def write(name,value):return save(name,json.dumps(value,ensure_ascii=False,indent=2)+"\n")

def inputs():
    files=[p for p in FORMAL.rglob("*.lean") if ".lake" not in p.parts]+[FORMAL/"lakefile.toml",FORMAL/"lean-toolchain"]
    return {str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sorted(files)}

def check_protected(baseline):
    for n,h in baseline["protected"].items():assert sha((ROOT/n).read_bytes())==h,n

def main():
    baseline=json.loads((RAW/"r3-baseline.json").read_text())
    (HERE/"r3-large-records.md").write_text("# レビュー対応の大きな生の記録\n\n100 KBを超える生の記録を `<tmp>` に保存する。所在のディレクトリ名はrecord-location.jsonを使う。\n\n| ファイル | bytes | SHA-256 |\n|---|---:|---|\n")
    save("r3-baseline.json",(RAW/"r3-baseline.json").read_bytes())
    check_protected(baseline)
    fixed=inputs();write("r3-inputs.json",fixed)
    changes=[{"path":n,"before":baseline["formal"].get(n),"after":h} for n,h in fixed.items() if baseline["formal"].get(n)!=h]
    assert {c["path"] for c in changes}=={"formal/Benitoite/Release/Refinement/"+m+".lean" for m in MODULES}
    write("r3-source-changes.json",changes)
    records=[]
    def run(label,args):
        start=time.monotonic();began=datetime.datetime.now(datetime.timezone.utc).isoformat()
        r=subprocess.run(args,cwd=FORMAL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        out=r.stdout.replace(str(ROOT).encode(),b"<repo>").replace(str(Path.home()).encode(),b"<home>")
        records.append({"label":label,"command":args,"cwd":"formal","started_utc":began,"exit":r.returncode,
          "elapsed_seconds":time.monotonic()-start,
          "input_sha256":sha((FORMAL/args[-1]).read_bytes()) if args[-1].endswith(".lean") else None,
          "output":save("r3-"+label+".log",out)})
        write("r3-commands.json",records)
        print(label,"終了",r.returncode,"外側",round(records[-1]["elapsed_seconds"],3),"秒",flush=True)
        assert r.returncode==0,out.decode()[-5000:]
        assert not re.search(rb"declaration uses .sorry.|sorryAx|error:",out)
        if label=="build":assert not re.search(rb"warning: Benitoite/Release/Refinement/",out)
        else:assert b"warning:" not in out
        return out
    completion=(HERE/"r3-build-final.log").read_bytes()
    assert b"Build completed successfully (694 jobs)." in completion
    records.append({"label":"build","command":["lake","build"],"cwd":"formal","exit":0,
      "timing":"起動から完了確認までの上限（並行した境界入力作成を含む）",
      "elapsed_upper_bound_seconds":(HERE/"r3-build-final.log").stat().st_mtime-(HERE/"signatures.md").stat().st_mtime,
      "output":save("r3-build-final.log",completion),"initial_output":"先頭の既存警告はツールの出力制限で省略。末尾の完了と終了0を保存"})
    pre="../"+str(HERE.relative_to(ROOT))+"/"
    old=run("old-boundary",["lake","env","lean","-M","12288",pre+"boundary.lean"])
    light=run("light-boundary",["lake","env","lean","-M","12288",pre+"r2-boundary.lean"])
    new=run("boundary",["lake","env","lean","-M","12288",pre+"r3-boundary.lean"])
    public=run("public-api",["lake","env","lean","-M","12288",pre+"r3-public-api.lean"])
    axioms=run("axioms",["lake","env","lean","-M","12288",pre+"r3-axioms.lean"])
    modules=[{"module":m.decode(),"declarations":int(k)} for m,k in re.findall(rb"^MODULE ([^:]+): (\d+)$",axioms,re.M)]
    names=re.findall(rb"^'(.+)' (?:depends on axioms|does not depend)",axioms,re.M)
    assert len(names)==len(set(names))==sum(m["declarations"] for m in modules)+12
    used={a.strip().decode() for out in [old,light,new,axioms] for group in re.findall(rb"depends on axioms:\s*\[([^\]]*)\]",out) for a in group.split(b",") if a.strip()}
    assert used<=ALLOWED,used-ALLOWED
    changed=[m for m in modules if m["module"].rsplit(".",1)[-1] in MODULES]
    write("r3-axioms-summary.json",{"modules":len(modules),"declarations":len(names),"changed_modules":changed,
      "changed_declarations":sum(m["declarations"] for m in changed),"used":sorted(used),"rejected":[],
      "old_boundary_declarations":int(re.search(rb"BOUNDARY_DECLARATIONS (\d+)",old).group(1)),
      "kleene_boundary_declarations":int(re.search(rb"KLEENE_BOUNDARY_DECLARATIONS (\d+)",new).group(1))})
    save("r3-axiom-targets.txt",b"\n".join(names)+b"\n")
    save("r3-case-inventory.txt",b"\n".join(re.findall(rb"^(?:CONSTRUCTORS|MUTUAL_TYPES|SOURCE_CONSTRUCTORS).*",axioms,re.M))+b"\n")
    count_public=len((HERE/"r3-public-targets.txt").read_text().splitlines())
    assert len(re.findall(rb"^Benitoite\.",public,re.M))==count_public
    assert inputs()==fixed
    check_protected(baseline)
    for m in MODULES:
        s=(FORMAL/("Benitoite/Release/Refinement/"+m+".lean")).read_text()
        assert not re.search(r"\b(sorry|admit|axiom|native_decide|implemented_by|unsafe|partial|extern)\b",s),m
    write("r3-validation.json",{"base_work":"610bd4ebf54905d36c5ccaeb2f6126d7149448a4","formal_inputs":len(fixed),
      "protected_inputs":len(baseline["protected"]),"protected_changes":[],"evalWith":"強いKleeneの三値へ変更",
      "public_signatures":count_public,"axiom_declarations":len(names),"changed_declarations":sum(m["declarations"] for m in changed),
      "old_boundary_theorems":len(re.findall(r"^theorem\s+",(HERE/"boundary.lean").read_text(),re.M)),
      "kleene_boundary_theorems":len(re.findall(r"^theorem\s+",(HERE/"r3-boundary.lean").read_text(),re.M)),
      "used_axioms":sorted(used),"lean_memory_mib":12288,"rss":"未取得（計画上の非採取）","git":"未実行","work":"未実行",
      "finished_utc":datetime.datetime.now(datetime.timezone.utc).isoformat()})
    print("許可外の公理0件、保護対象の変更0件、強いKleeneへの変更はClosedEvaluationのみ。",flush=True)

if __name__=="__main__":main()
