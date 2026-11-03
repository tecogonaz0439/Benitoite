"""全新モジュール、宣言一覧、実ソース、義務、最終検査と記録を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, subprocess, sys, time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
NEW=["StandardInteger","StandardByteCharacter","StandardFloat","StandardDecimal","StandardFactExamples"]
BASE="5e2012958fe8aab1edca8587ec8dd731a1527a82"
ENGINEERING_ID = r"\b(?:L\d{2}(?:\.\d+[a-z]?)?|B\d{2}(?:-\d+)?|O\d{3}|TODO-\d{3}|RV-[A-Za-z0-9.-]+)\b"
def check_engineering_ids():
    for token in ["B04", "B15-2", "L40.16", "L30", "O118", "RV-L40.d", "TODO-022"]:
        assert re.search(ENGINEERING_ID,token), token
    for text in ["Boolean", "UInt64", "0xB04", "IntegerValue", "B.CoreAssumptions"]:
        assert not re.search(ENGINEERING_ID,text), text
def digest(p):
    b=p.read_bytes()
    return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
def main():
    check_engineering_ids()
    t=time.monotonic(); started=datetime.now(timezone.utc).isoformat()
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp",type=Path,required=True)
    a=ap.parse_args();a.tmp.mkdir(parents=True,exist_ok=True)
    subprocess.run([sys.executable,str(HERE/"sources.py")],check=True,capture_output=True)
    default=(ROOT/"formal/Benitoite.lean").read_text().splitlines()
    audit=json.loads((HERE/"audit-summary.json").read_text())
    assert audit["exit"]==0 and not audit["inventory_only"] and audit["new_axioms"]==0
    assert set(audit["new_modules"])==set(NEW) and audit["local_records"]==0
    assert all(set(k.split(" + "))<={"none","propext","Quot.sound","Classical.choice"} for k in audit["axiom_sets"])
    declarations={};files=[ROOT/"formal/Benitoite.lean"]
    for name in NEW:
        module="Benitoite.Release.Refinement."+name
        assert "import "+module in default,name
        p=ROOT/"formal/Benitoite/Release/Refinement"/(name+".lean");files.append(p)
        source=p.read_text()
        assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval",source),name
        assert not re.search(ENGINEERING_ID + r"|/Users/",source),name
        recorded=json.loads((HERE/("declarations-"+name+".json")).read_text())
        assert recorded["module"]==module
        assert recorded["count"]==audit["new_modules"][name]==len(set(recorded["names"]))
        olean=ROOT/"formal/.lake/build/lib/lean/Benitoite/Release/Refinement"/(name+".olean")
        assert olean.exists() and olean.stat().st_mtime>=p.stat().st_mtime,name
        named=re.findall(r"^(private )?(theorem|def|inductive|structure) ([^\s{(:]+)",source,re.M)
        declarations[name]={"environment":recorded["count"],"public":[n for priv,_,n in named if not priv],
            "named_private":sum(bool(priv) for priv,_,_ in named),
            "anonymous_examples":len(re.findall(r"^example\b",source,re.M))}
    (HERE/"declarations.json").write_text(json.dumps(declarations,ensure_ascii=False,indent=2)+"\n")
    obligations=(HERE/"obligations.md").read_text()
    ids=re.findall(r"^\| (O\d{3}) \|",obligations,re.M)
    detail=(HERE.parent/"detail.md").read_text()
    assert len(ids)==len(set(ids))==64
    assert set(ids)==set(re.findall(r"^\| (O\d{3}) \|",detail,re.M))
    checks=json.loads((HERE/"checks.json").read_text())
    work=[r for r in checks if r["label"]=="work"]
    assert len(work)==1 and work[0]["exit"]==0
    assert work[0]["command"]==["scripts/check.sh","--level","work","--base",BASE]
    current=[r for r in checks if r["label"]=="r1-work"]
    assert len(current)==1 and current[0]["exit"]==0
    assert current[0]["command"]==work[0]["command"]
    assert sum(r["command"]==work[0]["command"] for r in checks)==2
    assert next(r for r in checks if r["label"]=="r1-axioms")["exit"]==0
    assert next(r for r in checks if r["label"]=="r1-final-build")["exit"]==0
    paths=sorted(p for p in (ROOT/"formal").rglob("*.lean") if ".lake" not in p.parts)
    manifest=a.tmp/"source-manifest.txt"
    manifest.write_text("".join(digest(p)["sha256"]+"  "+str(p.relative_to(ROOT))+"\n" for p in paths))
    files += [ROOT/"docs/design/01-spec/01-12-core-calculus.md",ROOT/"docs/design/07-quality/07-04-formal-semantics.md"]
    for p in HERE.iterdir():
        if not p.is_file(): continue
        assert p.stat().st_size<=100000,p.name
        text=p.read_text()
        assert str(ROOT) not in text,p.name
        assert not re.search(r"\]\([^)]*docs/todo",text),p.name
        if p.suffix==".md":
            for link in re.findall(r"\]\(([^)]+)\)",text):
                if "://" not in link and link.split("#")[0]:
                    assert (p.parent/link.split("#")[0]).exists(),(p.name,link)
    brief=json.dumps({"exit":0,"new_modules":len(NEW),"declarations":audit["added_declarations"],
      "lean_sources":len(paths),"obligations":len(ids),"public":sum(len(x["public"]) for x in declarations.values()),
      "private":sum(x["named_private"] for x in declarations.values()),
      "examples":sum(x["anonymous_examples"] for x in declarations.values())},ensure_ascii=False)+"\n"
    output=a.tmp/"verify.log";output.write_text(brief)
    result={"base":BASE,"output":digest(output),"exit":0,"started":started,"ended":datetime.now(timezone.utc).isoformat(),
      "seconds":time.monotonic()-t,"new_modules":NEW,"added_declarations":audit["added_declarations"],
      "lean_sources":len(paths),"manifest":digest(manifest),"obligations":len(ids),
      "files":{str(p.relative_to(ROOT)):digest(p) for p in files},
      "records":{p.name:digest(p) for p in HERE.iterdir() if p.is_file() and p.name!="inputs.json"}}
    (HERE/"inputs.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(brief,end="")
if __name__=="__main__": main()
