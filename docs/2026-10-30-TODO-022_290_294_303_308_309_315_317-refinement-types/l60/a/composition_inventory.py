"""全出典・helperの元Defと合成lookupの入力を再生成し、全有限キーを照合する。"""
import argparse
import json
from collections import Counter
from pathlib import Path
from inventory import HERE, FORMAL, digest, write
from ledger import pages


def read_pages(record, key):
    rows=[]
    for page in record[key]:
        assert digest(HERE/page['file']) == {k:page[k] for k in ['bytes','sha256']}
        rows.extend(json.loads((HERE/page['file']).read_text()))
    return rows


def prepare():
    closure=json.loads((HERE/'resume3-closure-summary.json').read_text())
    graph=read_pages(closure,'rows')
    bodies=json.loads((HERE/'resume3-body-sources.json').read_text())
    bykey={r['key']:r for r in bodies}
    headers='''import Lean
import Benitoite.Release.Refinement.StandardModelResponse
import Benitoite.Release.Refinement.StandardAliasBodies
import Benitoite.Release.Refinement.StandardSafeBodies
namespace Benitoite.RefinementSourceCorrespondence
open Benitoite.Release.Refinement
'''
    audit='''
end Benitoite.RefinementSourceCorrespondence
open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let names := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if names.isEmpty then break
    for n in names do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      let deps ← Lean.collectAxioms n
      logInfo m!"'{n}' depends on axioms: [{String.intercalate ", " (deps.toList.map Name.toString)}]"
'''
    proofs=[]
    for i,r in enumerate(graph[:159]):
        b=bykey[r['key']]
        proofs.append(f'''theorem source{i+1:03} (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.{b['constructor']}.key =
      ({r['expression']} : Option Def).map
        (FunctionNames.definition (FunctionNames.rename {str(b['refined']).lower()})) := by
  rw [StandardModel.body_lookup]
  rfl
''')
    helper=next(b for b in bodies if b['key'] not in {r['key'] for r in graph[:159]})
    proofs.append(f'''theorem ordinary_filter_helper (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs StandardModel.Body.{helper['constructor']}.key =
      some (FunctionNames.definition (FunctionNames.rename false) (StandardBodies.listFromDefinition true)) := by
  rw [StandardModel.body_lookup]
  rfl
''')
    inputs=[]
    for start in range(0,len(proofs),80):
        name=f'source-correspondence-{start//80+1:02}.lean'
        (HERE/name).write_text(headers+'\n'.join(proofs[start:start+80])+audit)
        inputs.append({'file':name,'proofs':len(proofs[start:start+80]),**digest(HERE/name)})
    write(HERE/'resume3-correspondence-inputs.json',inputs)
    return inputs


def verify_tables(record=True):
    summary=json.loads((HERE/'ledger-summary.json').read_text())
    evidence=read_pages(summary,'evidence_pages');ledger=read_pages(summary,'ledger_pages')
    rust=read_pages(summary,'rust_pages');conditions=read_pages(summary,'condition_pages')
    bodies=json.loads((HERE/'resume3-body-sources.json').read_text())
    prims=json.loads((HERE/'resume3-primitive-sources.json').read_text())
    closure=json.loads((HERE/'resume3-closure-summary.json').read_text());graph=read_pages(closure,'rows')
    assert [len(x) for x in [evidence,ledger,rust,conditions,bodies,prims]]==[552,640,523,75,130,373]
    assert summary['lookup_composition_complete'] is True and summary['composition_complete'] is False
    assert not closure['same_original_reference_conflicts']
    source_to_body={r['source']:r['key'] for r in graph[:159]}
    bodybykey={r['key']:r for r in bodies};primitive_names={r['name'] for r in prims}
    body_keys={r['internal_name'] for r in bodies}
    assert len(body_keys)==130 and len(primitive_names)==373
    assert not body_keys & primitive_names
    all_keys=body_keys|primitive_names|{'File.Handle'}
    composition=[r for r in ledger if r['classification']=='合成'];assumed=[r for r in ledger if r['classification']=='仮定']
    assert len(composition)==486 and len(assumed)==154
    ledger_keys={n for r in composition for n in r['internal_names']}
    assert ledger_keys==all_keys and len(all_keys)==504
    assert not {r['lean_name'] for r in assumed} & all_keys
    assert all(not r['evidence'] and not r['evidence_rows'] and r['reason'] for r in assumed)
    byid={r['id']:r for r in ledger}
    for e in evidence:
        parent=byid[e['ledger']]
        assert parent['classification']=='合成' and e['id'] in parent['evidence_rows']
        if e['original_def']:
            b=bodybykey[source_to_body[e['id']]]
            assert e['internal_name']==b['internal_name']
            assert e['composition_lookup']=='StandardModel.Body.'+b['constructor']
        elif e['category']!='resource':assert e['lean_name'] in primitive_names
        assert set(e['evidence']) <= set(parent['evidence'])
    # 構文の有限列を独立に再生成し、本番の全枝と集合・順序を照合する。
    names=set(closure['renamed_names'])
    assert not names & all_keys
    for b in bodies:
        assert not any(n.startswith('%') for n in b['references']), b['constructor']
    edges=read_pages(closure,'edges')
    bybody={r['key']:r for r in bodies}
    for edge in edges:
        parent=bybody[edge['parent']];target=bybody[edge['target']]
        reference='%'+edge['name']+('.refined' if parent['refined'] else '.ordinary') if edge['name'] in names else edge['name']
        assert reference==target['internal_name'],edge
    source=(FORMAL/'StandardModelDeclarations.lean').read_text()
    for b in bodies:
        assert f'| .{b["constructor"]} => {json.dumps(b["name"])}' in source
        assert f'| .{b["constructor"]} => ({b["expression"]} : Option Def).get (by rfl)' in source
        key='%'+b['name']+('.refined' if b['refined'] else '.ordinary') if b['name'] in names else b['name']
        assert key==b['internal_name'] and f'| .{b["constructor"]} => {json.dumps(key)}' in source
    sig=(FORMAL/'StandardModelSignatures.lean').read_text()
    lookups=(FORMAL/'StandardModelPrimitiveLookup.lean').read_text()
    assert [r['name'] for r in prims]==sorted(primitive_names)
    for r in prims:
        assert f'| .{r["constructor"]} => {json.dumps(r["name"])}' in sig
        assert f'private theorem lookup_{r["constructor"]} : primitive {json.dumps(r["name"])} = some Primitive.{r["constructor"]} := rfl' in lookups
    def tree(rows):
        if not rows:return '.empty'
        i=len(rows)//2;r=rows[i]
        return f'(.node {json.dumps(r["name"])} .{r["constructor"]} rfl {tree(rows[:i])} {tree(rows[i+1:])})'
    assert 'private def primitiveTree : SignatureTree := '+tree(prims) in sig
    result={'source_rows':552,'body_sources':159,'distinct_body_defs':130,'extra_helper_defs':1,
        'primitive_names':373,'resource_names':1,'composition_keys':504,'ledger_composition_rows':486,
        'assumption_rows':154,'rust_references':523,'model_conditions':75,'renamed_names':18,
        'ledger_to_lookup_missing':0,'lookup_to_ledger_missing':0,'evidence_on_assumption_rows':0,
        'lookup_composition_complete':True,'semantic_composition_complete':False}
    if record:
        write(HERE/'resume3-composition-summary.json',result)
    return result

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--prepare',action='store_true')
    args=ap.parse_args()
    if args.prepare:print(json.dumps(prepare(),ensure_ascii=False))
    else:print(json.dumps(verify_tables(),ensure_ascii=False))
