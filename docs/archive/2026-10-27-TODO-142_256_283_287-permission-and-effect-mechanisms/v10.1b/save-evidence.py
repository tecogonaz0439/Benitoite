"""局所出力を同定し、後から参照できる小さい記録を改造内へ保存する。"""
import gzip
import hashlib
import json
from pathlib import Path
import tarfile
V=Path(__file__).resolve().parent
ROOT=V.parents[2]
OUT=ROOT/'target/v10.1b'
rows=[]
for directory in ['export','compare']:
 for p in sorted((OUT/directory).rglob('*')):
  if p.is_file():
   b=p.read_bytes()
   assert str(ROOT).encode() not in b, str(p.relative_to(ROOT))
   rows.append(dict(path=str(p.relative_to(OUT)),bytes=len(b),sha256=hashlib.sha256(b).hexdigest()))
(V/'local-output-inventory.json').write_text(json.dumps(rows,indent=2)+'\n')
archive=V/'local-evidence.tar.gz'
with tarfile.open(archive,'w:gz') as out:
 for row in rows:out.add(OUT/row['path'],arcname=row['path'],recursive=False)
for file in ['summary.json','source-manifest.json']:
 (V/('f-l-'+file)).write_bytes((OUT/'compare'/file).read_bytes())
state=json.loads(gzip.decompress((V.parent/'k10.3/k10.3b-final-state.json.gz').read_bytes()))
matched=0;differences=[]
for path,wanted in state['sourceHashes'].items():
 p=ROOT/path; actual=hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
 if actual==wanted:matched+=1
 else:differences.append(dict(path=path,oldSha256=wanted,sha256=actual))
assert [r['path'] for r in differences]==['crates/benitoite/tests/desugar_export/range-sources/expected.json'],differences
(V/'relation-state-after.json').write_text(json.dumps(dict(basis='../v10.1a/relation-state.json -> ../k10.3/k10.3b-final-state.json.gz',matchedFiles=matched,differences=differences,addedComparisonInputs=['crates/benitoite/tests/desugar_export/range-sources/h31-user-signature.bnt','crates/benitoite/tests/desugar_export/range-sources/h31-user-forward.bnt'],archive=dict(path=archive.name,bytes=archive.stat().st_size,sha256=hashlib.sha256(archive.read_bytes()).hexdigest()),localFiles=len(rows),localBytes=sum(r['bytes'] for r in rows)),indent=2)+'\n')
print('元入力一致',matched,'差分',len(differences),'保存',len(rows),'files',archive.stat().st_size,'compressed bytes')
