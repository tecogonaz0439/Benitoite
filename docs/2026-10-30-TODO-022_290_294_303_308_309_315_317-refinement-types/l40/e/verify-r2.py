"""再開2の全通常契約、固定入力、公理監査と群末workを照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, ast, hashlib, json, re, time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE="548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8"
FORBIDDEN=r"\b(?:sorry|axiom|admit|native_decide|implemented_by)\b|#eval"
ENGINEERING=r"\b(?:L\d{2}(?:\.\d+[a-z]?)?|B\d{2}(?:-\d+)?|O\d{3}|TODO-\d{3}|RV-[A-Za-z0-9.-]+)\b"
def digest(path):
 data=path.read_bytes()
 return {"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}
def parts(name,values):
 result=[]
 for i in range(0,len(values),150):
  filename=f"{name}-part-{i//150+1:02}.json"
  (HERE/filename).write_text(json.dumps(values[i:i+150],ensure_ascii=False,indent=2)+"\n")
  result.append({"file":filename,**digest(HERE/filename)})
 return result
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument("--tmp",type=Path,required=True)
 ap.add_argument("--tag",default="r2-final")
 args=ap.parse_args()
 args.tmp.mkdir(parents=True,exist_ok=True)
 start=time.monotonic(); started=datetime.now(timezone.utc).isoformat()
 modules=json.loads((HERE/"modules-r1.json").read_text())
 assert modules and len(set(modules))==len(modules)
 audit=json.loads((HERE/f"audit-summary-{args.tag}.json").read_text())
 assert audit["exit"]==0 and audit["new_axioms"]==0 and audit["local_records"]==0
 assert audit["private_and_generated_included"] and not audit["inventory_only"]
 assert set(audit["new_modules"])==set(modules)
 assert all(set(a.split(" + "))<={"none","propext","Quot.sound","Classical.choice"} for a in audit["axiom_sets"])
 for name,expected in audit["source_inputs"].items():
  assert digest(ROOT/name)==expected,name
 original={}
 for path in HERE.glob("inputs-r2-part-*.json"): original.update(json.loads(path.read_text()))
 retained=0; root_prefix=0
 for name,expected in original.items():
  if "/.lake/" in name: continue
  if name in {"docs/design/01-spec/01-12-core-calculus.md","docs/design/07-quality/07-04-formal-semantics.md"}: continue
  path=ROOT/name
  if name=="formal/Benitoite.lean":
   data=path.read_bytes()[:expected["bytes"]]
   assert {"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}==expected,name
   root_prefix=expected["bytes"]
  else:
   assert digest(path)==expected,name
   retained+=1
 assert root_prefix>0
 sources=json.loads((HERE/"sources-r2-u28.json").read_text())
 old=json.loads((HERE/"sources-r1-u28.json").read_text())
 assert sources["counts"]["apis"]==len(sources["rows"])==328
 assert sources["counts"]["pure-local"]==244 and sources["counts"]["core-local"]==84
 assert sources["counts"]["open"]==0
 assert sources["resumed_ordinary"]=={"closed":179,"remaining":0}
 assert {r[0] for r in sources["rows"]}=={r[0] for r in old["rows"]}
 assert all(r[4] in {"pure-local","core-local"} for r in sources["rows"])
 assert sources["whole_api_contracts_closed"]==0 and sources["whole_obligations_closed"]==0
 assert sources["L40_unproved_transferred"]==0
 originals=json.loads((HERE/"sources.json").read_text())
 for name,expected in originals["inputs"].items(): assert digest(ROOT/name)==expected,name
 obligation=(HERE/"obligations.md").read_text(); detail=(HERE.parent/"detail.md").read_text()
 ids=re.findall(r"^\| (O\d{3}) \|",obligation,re.M)
 assert len(ids)==len(set(ids))==64
 assert set(ids)==set(re.findall(r"^\| (O\d{3}) \|",detail,re.M))
 checks=[]
 for path in HERE.glob("checks-r2*.json"):
  rows=json.loads(path.read_text()); assert isinstance(rows,list),path.name
  checks+=rows
 # 継承した試行だけは再開1系の別記録に残る。
 inherited=json.loads((HERE/"checks-r1-r2.json").read_text())
 checks+=inherited
 assert len({(c["label"],c["start"]) for c in checks})==len(checks)
 for c in checks:
  cmd=c["command"]
  if cmd[:2]==["lake","build"]: assert cmd==["lake","build"] and c["cwd"]=="formal/",c
  if cmd[:3]==["lake","env","lean"]: assert cmd[3:5]==["-M","12288"] and c["cwd"]=="formal/",c
 workcmd=["scripts/check.sh","--level","work","--base",BASE]
 works=[c for c in checks if c["command"]==workcmd]
 assert len(works)==1 and works[0]["exit"]==0
 assert any(c["command"]==["lake","build"] and c["exit"]==0 for c in checks)
 default=(ROOT/"formal/Benitoite.lean").read_text().splitlines()
 inventory=[]
 for name in modules:
  assert "import Benitoite.Release.Refinement."+name in default,name
  path=ROOT/"formal/Benitoite/Release/Refinement"/(name+".lean")
  source=path.read_text()
  assert not re.search(FORBIDDEN,source),name
  assert not re.search(ENGINEERING+r"|/Users/",source),name
  record=json.loads((HERE/f"declarations-{args.tag}-{name}.json").read_text())
  assert record["module"]=="Benitoite.Release.Refinement."+name
  if "names_parts" in record:
   names=[]
   for part in record["names_parts"]:
    part_path=HERE/part["file"]
    assert digest(part_path)=={k:part[k] for k in ["bytes","sha256"]}
    chunk=json.loads(part_path.read_text())
    assert len(chunk)==part["count"]
    names+=chunk
  else:names=record["names"]
  assert len(names)==len(set(names))==audit["new_modules"][name]
  assert (ROOT/"formal/.lake/build/lib/lean/Benitoite/Release/Refinement"/(name+".olean")).exists()
  inventory.append({"module":name,"source":digest(path),"declarations":record["count"],
   "examples":len(re.findall(r"^example\b",source,re.M))})
 paths=sorted(p for p in (ROOT/"formal").rglob("*.lean") if ".lake" not in p.parts)
 old_leans={n for n in original if n.endswith(".lean") and "/.lake/" not in n}
 new_leans={str(p.relative_to(ROOT)) for p in paths}-old_leans
 assert new_leans<={"formal/Benitoite/Release/Refinement/"+n+".lean" for n in modules}
 module_parts=parts("verified-r2-modules",inventory)
 manifest=args.tmp/"source-manifest-r2.txt"
 manifest.write_text("".join(digest(p)["sha256"]+"  "+str(p.relative_to(ROOT))+"\n" for p in paths))
 # 再開2の生成器も含めて、記録のサイズ・文法・恒久リンクを照合する。
 for path in HERE.iterdir():
  if not path.is_file():continue
  assert path.stat().st_size<=100000,path.name
  text=path.read_text()
  assert str(ROOT) not in text,path.name
  if path.suffix==".py":ast.parse(text,filename=path.name)
  if path.suffix==".md":
   for link in re.findall(r"\]\(([^)]+)\)",text):
    target=link.split("#")[0]
    if "://" not in link and target:assert (path.parent/target).exists(),(path.name,link)
   assert not re.search(r"\]\([^)]*docs/todo",text),path.name
 brief={"exit":0,"start":started,"end":datetime.now(timezone.utc).isoformat(),
  "seconds":time.monotonic()-start,"base":BASE,"modules":len(modules),
  "audited_modules":audit["module_count"],"audited_declarations":audit["targets"],
  "new_axioms":audit["new_axioms"],"baseline_unchanged":retained,
  "root_retained_prefix_bytes":root_prefix,"new_lean_sources":len(new_leans),
  "lean_sources":len(paths),"obligations":64,"apis":328,"resumed_ordinary":sources["resumed_ordinary"],
  "ordinary_counts":sources["counts"],"module_parts":module_parts,
  "source_manifest":digest(manifest),"work":works[0]["label"],"new_command_deviations":0}
 (HERE/"verification-r2.json").write_text(json.dumps(brief,ensure_ascii=False,indent=2)+"\n")
 print(json.dumps(brief,ensure_ascii=False))
if __name__=="__main__":main()

