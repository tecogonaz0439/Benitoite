"""H31 の独立した入力・期待値を、処理系を呼ばずに一度だけ固定する。"""
from pathlib import Path
import datetime
import hashlib
import json
V=Path(__file__).resolve().parent
ROOT=V.parents[2]
S=ROOT/'crates/benitoite/tests/desugar_export/range-sources'
header='''import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.IO.File

effect Audit
 function log(path: Scope.PathIn["/srv/audit/**"], line: String) -> Unit
 function flush() -> Unit
end effect

'''
inputs={
'h31-user-signature':header+'''function sample(path: Scope.PathIn["/srv/audit/**"]) -> Unit uses Audit
 log(path: path, line: "a")
end function
''',
'h31-user-forward':header+'''function sample(path: Scope.PathIn["/srv/audit/**"]) -> Unit uses File.Write["/srv/audit/**"]
 handle log(path: path, line: "a") with
 case log(q, line) ->
  bind _ <- File.writeTextIn(path: q, text: line)
  resume(())
 case flush() -> resume(())
 end handle
end function
'''}
expected=json.loads((S/'expected.json').read_text())
assert not any(c['name'].startswith('h31-') for c in expected['cases'])
original=(S/'expected.json').read_bytes()
(V/'h31-expected-before.json').write_bytes(original)
new=[]
for name,source in inputs.items():
 p=S/(name+'.bnt'); assert not p.exists(); p.write_text(source)
 forward=name.endswith('forward')
 case=dict(name=name,file=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),exit=0,definitions=1,nonTopRangesMinimum=1,nonTopRanges=7 if forward else 3,surface={'ok':True},h31=dict(signature=dict(operation='log',names=['path','line'],parameterIndex=0,range={'path':{'tree':['srv','audit']}}),definitionNames=['sample'],effects=['File.Write["/srv/audit/**"]'] if forward else ['Audit'],prim='File.writeTextIn' if forward else None,primOccurrencesPerRepresentation=1 if forward else 0,allDefinitionsChecked=True))
 expected['cases'].append(case);new.append(case)
(S/'expected.json').write_text(json.dumps(expected,ensure_ascii=False,indent=2)+'\n')
(V/'h31-expectations.json').write_text(json.dumps(dict(basis='実行前に公開契約と交換の構造から手書き。出力から期待値を作らない',cases=new,counting='signature: 操作headerのPathIn 1 + sampleのsurface/core headerのPathIn各1 =3。forward: これに両headerのFile.Write各1とsurface/coreのFile.writeTextInのranges各1を加えて7。節の引数はarityで表し型は操作headerから得る。candidatesは除く。'),ensure_ascii=False,indent=2)+'\n')
files=[S/'expected.json',*[S/(name+'.bnt') for name in inputs],V/'h31-expectations.json']
(V/'h31-freeze.json').write_text(json.dumps(dict(frozenAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),previousExpectedSha256=hashlib.sha256(original).hexdigest(),files=[dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in files]),indent=2)+'\n')
print((V/'h31-freeze.json').read_text())
