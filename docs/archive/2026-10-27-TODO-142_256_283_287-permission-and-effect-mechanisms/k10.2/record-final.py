"""最終状態と保存物を、禁止した非公開ディレクトリへ入らず記録する。"""
from pathlib import Path
import ast
import hashlib
import json
import subprocess


def require(ok, message):
    if not ok:
        raise AssertionError(message)


root=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
changed=subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=root,text=True).splitlines()
untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard','--','crates/benitoite','formal/tests'],cwd=root,text=True).splitlines()
allowed_exact={'scripts/check-formal.sh','scripts/check/formal_interval.py','docs/design/01-spec/01-12-core-calculus.md','docs/design/07-quality/07-03-compiler-testing.md','docs/design/07-quality/07-04-formal-semantics.md'}
require(all(p.startswith(('crates/benitoite/','formal/tests/','docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/k10.2/')) or p in allowed_exact for p in changed), 'record-final.py:14: requirement failed')
rows=[]
for name in changed+untracked:
    p=root/name
    require(not p.is_symlink(), 'record-final.py:18: requirement failed')
    rows.append({'path':name,'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size})
diff=subprocess.check_output(['git','diff','--no-ext-diff','--binary','HEAD'],cwd=root)
(here/'final-source-state.json').write_text(json.dumps({'baseline':'c3ca4504dae42271df7336aca41d0a6d5447d0e3','head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'changed':changed,'untrackedInputs':untracked,'diffSha256':sha(diff),'files':rows,'runtimeSourceChanges':[]},indent=2)+'\n')
# W-K後の実質変更はこの2ファイルのみ。初回の内容は操作記録から再構成し、その旨を明記する。
p=root/'scripts/check-formal.sh';after=p.read_text();before=after.replace('for profile in b3 blocks g2 g3; do','for profile in b3 blocks g2 g3 k3 k4 m1 t3; do')
script={'path':'scripts/check-formal.sh','workInputSha256Reconstructed':sha(before.encode()),'finalSha256':sha(after.encode())}
p=root/'crates/benitoite/tests/desugar_export/check_named.py';after=p.read_text();first=after.index('def check_remaining_batch3(');last=after.index('def main():',first);before=after[:first]+after[last:];before=before.replace('    check_remaining_batch3(directory)\n','')
reader={'path':'crates/benitoite/tests/desugar_export/check_named.py','workInputSha256Reconstructed':sha(before.encode()),'finalSha256':sha(after.encode())}
(here/'work-followup-state.json').write_text(json.dumps({'basis':'初回実行後の操作記録から2ファイルの初回内容を再構成。事前採取と偽らない','functionalChangesAfterWork':[script,reader],'unchangedRustInputs':[r for r in rows if r['path'].startswith('crates/benitoite/') and r['path']!=reader['path']],'retested':['policy_selftest','final check_remaining_batch3 six-entry comparison'],'notRepeated':['fmt','lint_default','lib_default','tests_related','source_rules','skill_generated','spec_tally','spec_examples','python_syntax']},ensure_ascii=False,indent=2)+'\n')
# 初回ログの全結果。policyの失敗をRustの成功と混同しない。
log=(here/'work-check.log').read_text()
import re

results=[]
for m in re.finditer(r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;.*?finished in ([0-9.]+)s',log):
    results.append(dict(passed=int(m[1]),failed=int(m[2]),ignored=int(m[3]),seconds=float(m[4])))
(here/'work-test-counts.json').write_text(json.dumps({'runs':results,'rustPassed':sum(r['passed'] for r in results),'rustFailed':sum(r['failed'] for r in results),'rustIgnored':sum(r['ignored'] for r in results),'policyInitial':{'passed':29,'failed':1},'policyRetry':{'passed':30,'failed':0}},indent=2)+'\n')
# 新規のテストの行数を、本番から分離する。
numstat=subprocess.check_output(['git','diff','--numstat'],cwd=root,text=True).splitlines()
(here/'line-counts.json').write_text(json.dumps({'runtimeAdded':0,'runtimeDeleted':0,'trackedNumstat':numstat,'newTestAndInputLines':{n:len((root/n).read_bytes().splitlines()) for n in untracked}},indent=2)+'\n')
# 圧縮物の内部は archive-redaction.json で別途検査済み。
artifacts=[];absolute=[]
for p in sorted(here.rglob('*')):
    if not p.is_file() or p.name in {'final-artifacts.json','final-verification.json'}:continue
    data=p.read_bytes()
    if p.suffix not in {'.gz','.zip','.pyc'} and (str(root).encode() in data or str(Path.home()).encode() in data):absolute.append(str(p.relative_to(here)))
    artifacts.append({'path':str(p.relative_to(here)),'bytes':len(data),'sha256':sha(data)})
require(not absolute, absolute)
(here/'final-artifacts.json').write_text(json.dumps(artifacts,indent=2)+'\n')
print(json.dumps({'inputFiles':len(rows),'artifacts':len(artifacts),'artifactBytes':sum(r['bytes'] for r in artifacts),'rustPassed':sum(r['passed'] for r in results),'absolutePathMatches':absolute}))
