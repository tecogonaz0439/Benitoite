"""停止時点の台帳・有限の先頭十六件・資源の名前を保存する。"""
import json
import re
from inventory import ROOT, HERE, CHANGE, FORMAL, digest, write
from ledger import lean_rows, pages
from rust_inventory import registrations

rows = lean_rows()
operators = (FORMAL/"StandardOperatorResponse.lean").read_text()
integers = re.search(r"def entries.*?\(\[([^]]+)\]\.flatMap", operators, re.S)[1]
integers = re.findall(r"\.(\w+)", integers)
prefixes = {"integer8":"Integer8","integer16":"Integer16","integer32":"Integer32",
    "integer64":"Integer","unsignedInteger16":"UnsignedInteger16",
    "unsignedInteger32":"UnsignedInteger32","unsignedInteger64":"UnsignedInteger64"}
first = []
for kind in integers:
    for modulo in [False,True]:
        first.append(("%"+prefixes[kind]+(".mod" if modulo else ".div"),
            "StandardOperatorResponse.Entry.integer ."+kind+" "+str(modulo).lower()))
assert "[false,true].flatMap (fun s => [.floating s .add,.floating s .subtract" in operators
first += [("%Float.add","StandardOperatorResponse.Entry.floating false .add"),
    ("%Float.subtract","StandardOperatorResponse.Entry.floating false .subtract")]
assert len(first) == 16
first_rows=[]
for i,(name,expr) in enumerate(first):
    match=[r for r in rows if r['group']==3 and r['lean_name']==name]
    assert len(match)==1
    first_rows.append({"source_index":i,"name":name,"entry":expr,"evidence_row":match[0]['id'],
        "evidence":"Benitoite.Release.Refinement.StandardOperatorResponse.response",
        "signature":"Benitoite.Release.Refinement.StandardOperatorResponse.Entry.signature",
        "delta":"Benitoite.Release.Refinement.StandardOperatorResponse.Entry.delta",
        "status":"名前・実定義・完全名の照合。合成先のlookupからの適用は未実施"})
write(HERE/'first-sixteen.json', first_rows)

runtime=(ROOT/'crates/benitoite/src/runtime/mod.rs').read_text()
resource_kinds=re.findall(r"^    (\w+),",runtime.split('pub enum ResourceKind {')[1].split('}',1)[0],re.M)
assert resource_kinds==['FileReader','FileWriter','HttpListener','HttpExchange','TaskGroup']
resources=[]
for kind in resource_kinds:
    resources.append({"rust_name":"runtime::ResourceKind::"+kind,
        "lean_name":"該当なし（実資源の状態に対応する証拠なし）",
        "classification":"仮定","evidence":[],
        "reason":kind+" の実資源の通常解放は、07-04の解放応答の条件として定理の引数で量化する。File.Handleは抽象モデル内の資源名であり、この実資源種の署名や開閉状態を証明するものではない。実解放との対応はR30/R50で確認する"})
write(HERE/'resources.json',resources)

inputs={r['source'] for r in rows}
sources=[]
for name in sorted(inputs):
    file=FORMAL/name if name.endswith('.lean') else CHANGE/name
    sources.append({"file":str(file.relative_to(ROOT)),**digest(file)})
for name in ['l60/detail.md','l60/tables.md','plan.md','README.md','l50/stage-results.md','l50/j/handoffs.md',
    'l50/j/conditions.json','l40/stage-results.md','implementation-request.md','reviews/RV-L60-plan.md']:
    file=CHANGE/name
    sources.append({"file":str(file.relative_to(ROOT)),**digest(file)})
for file in sorted(FORMAL.glob('*.lean')):
    if file.name.startswith(('StandardOrdinary','StandardSafe','StandardHeadTail')) and not any(r['file']==str(file.relative_to(ROOT)) for r in sources):
        sources.append({"file":str(file.relative_to(ROOT)),**digest(file)})
for name in sorted({r['source'] for r in registrations()} | {'crates/benitoite/src/builtins/funcs/mod.rs',
    'crates/benitoite/src/runtime/mod.rs','formal/lean-toolchain','formal/lakefile.toml'}):
    sources.append({'file':name,**digest(ROOT/name)})
write(HERE/'source-inputs.json',sources)
PYTHON_NOTE = "Pythonの静的展開。Leanの具体値の評価はしない"
print(len(first_rows),len(resources),len(sources),PYTHON_NOTE)
