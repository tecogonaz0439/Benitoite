# -*- coding: utf-8 -*-
"""変更範囲・固定値・保存物・リンクを読み取りで最終照合する。"""
import ast
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
V=Path(__file__).resolve().parent
ROOT=V.parents[2]
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def read(p):return json.loads(p.read_text())
assert git('rev-parse','HEAD').decode().strip()=='bae86164de063a9807784513e8960e46536d9f4b'
assert git('branch','--show-current').decode().strip()=='m013/v10.1b'
assert not git('diff','--cached','--binary')
tracked=git('diff','--name-only').decode().splitlines()
assert tracked==['crates/benitoite/tests/desugar_export/range-sources/expected.json'],tracked
untracked=git('ls-files','--others','--exclude-standard').decode().splitlines()
allowed={str((ROOT/'crates/benitoite/tests/desugar_export/range-sources'/n).relative_to(ROOT)) for n in ['h31-user-signature.bnt','h31-user-forward.bnt']}
assert all(p in allowed or p.startswith(str(V.relative_to(ROOT))+'/') for p in untracked)
sources=ROOT/'crates/benitoite/tests/desugar_export/range-sources'
old=read(V/'h31-expected-before.json');now=read(sources/'expected.json')
assert now['cases'][:-2]==old['cases']
assert {k:v for k,v in now.items() if k!='cases'}=={k:v for k,v in old.items() if k!='cases'}
assert len(now['cases'])==33
for row in read(V/'h31-freeze.json')['files']:assert sha((ROOT/row['path']).read_bytes())==row['sha256']
for p in V.glob('*.py'):ast.parse(p.read_text(),filename=p.name)
links=0
for p in V.glob('*.md'):
 for target in re.findall(r'\[[^\n\]]+\]\(([^)]+)\)',p.read_text()):
  assert not target.startswith(('http','/'))
  path=(p.parent/target.split('#')[0]).resolve();assert path.exists(),(p.name,target)
  links+=1
 assert '/Users/' not in p.read_text()
 assert not re.search(r'\]\([^)]*docs/todo',p.read_text())
for p in V.iterdir():
 if p.suffix in ['.json','.log','.patch','.py']:
  assert str(ROOT).encode() not in p.read_bytes(),p.name
manifests=[]
for r in read(V.parent/'v10.1a/evidence-audit.json')['finalManifests']:
 p=ROOT/r['path'];h=sha(p.read_bytes());assert h==r['recorded']['sha256']
 manifests.append(dict(path=r['path'],sha256=h,matches=True))
env={}
for name,cmd in [('rustc',['rustc','--version','--verbose']),('cargo',['cargo','--version']),('python',['python3','--version']),('os',['uname','-sm'])]:
 env[name]=subprocess.check_output(cmd,cwd=ROOT,text=True).strip()
(V/'environment.json').write_text(json.dumps(env,indent=2)+'\n')
patch=git('diff','--binary');(V/'actual-change.patch').write_bytes(patch)
finished=datetime.datetime.now(datetime.timezone.utc)
started=datetime.datetime.fromisoformat('2026-10-29T17:21:46+00:00')
elapsed=(finished-started).total_seconds()
p=V/'results.md';s=p.read_text();assert '終了の採時計は' not in s
s+='\n終了の採時計は'+finished.astimezone(datetime.timezone(datetime.timedelta(hours=9))).strftime('%Y-%m-%d %H:%M:%S JST')+'である。開始時計からの外側の所要は'+str(round(elapsed,2))+'秒（約'+str(round(elapsed/60,1))+'分）で、能動時間は約'+str(round((elapsed-195.16)/60,1))+'分の概算である。検査・ビルド待ちの一部と文書作業は重なるため厳密な分離ではない。独立レビュー・設計者の回答待ちは含めない。6時間の停止条件には達していない。\n\n最終確認では、既存31caseと固定した追加2caseの期待値、許可された差分だけであること、Python台本の構文、相対リンク'+str(links)+'件、手元の絶対パスと禁止先リンクの不在、HEAD・ブランチ・indexの不変を確認した。[最終状態](final-state.json)へ差分と未追跡入力のSHA-256を保存した。K10.3の最終3manifestのハッシュも元記録と一致した。最後の追記は記録だけであり、F-L・W-Rを繰り返していない。\n'
p.write_text(s)
files=[dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size,sha256=sha(p.read_bytes())) for p in sorted(V.rglob('*')) if p.is_file() and p.name!='final-state.json']
inputs=[dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size,sha256=sha(p.read_bytes())) for p in [sources/'expected.json',sources/'h31-user-signature.bnt',sources/'h31-user-forward.bnt']]
result=dict(base=git('rev-parse','HEAD').decode().strip(),branch='m013/v10.1b',finishedAt=finished.isoformat(),elapsedSeconds=elapsed,trackedFiles=tracked,trackedDiffSha256=sha(patch),indexDiffBytes=0,comparisonInputs=inputs,artifacts=files,k103Manifests=manifests,markdownLinksChecked=links,existingCasesUnchanged=31,addedCases=2,gitMutations=False,formalBuildsRun=0,fullFormalComparisonsRun=0,rss='time -pからは取得不能',limitations=['H08/H09/義務行23は未確認','義務行35はV10.1dの最終確認待ち','独立レビュー・受け入れは取りまとめと設計者'])
(V/'final-state.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('最終確認成功。記録',len(files),'ファイル、所要',round(elapsed/60,1),'分、リンク',links,'件')
