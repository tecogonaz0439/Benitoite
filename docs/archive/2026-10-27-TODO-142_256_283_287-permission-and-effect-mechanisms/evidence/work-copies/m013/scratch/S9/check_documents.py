"""S9 文書の静的な照合。処理系・Lean・検査スクリプトを実行しない。"""
from pathlib import Path
import hashlib,json,re,subprocess
root=Path('.')
change=Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms')
files=[change/'study/language-rules.md',change/'study/user-effect-scopes.md']
allowed={str(p) for p in files}
records={}
errors=[]
for p in files:
 s=p.read_text()
 links=[]
 parsed=re.sub(r"```[^\n]*\n.*?^```[^\n]*$", "", s, flags=re.M|re.S)
 parsed=re.sub(r"`[^`\n]*`", "", parsed)
 for text,target in re.findall(r'\[([^\]]+)\]\(([^)]+)\)',parsed):
  if re.match(r'https?://',target):continue
  q=target.split('#',1)[0]
  dest=p.parent/q
  links.append({'target':target,'exists':dest.exists()})
  if not dest.exists():errors.append(f'{p}: missing link {target}')
 if re.search(r'/Users/|/home/|/private/var/',s):errors.append(f'{p}: absolute local path')
 if re.search(r'\]\([^)]*(?:todo/|/todo)',s):errors.append(f'{p}: todo link')
 if len(re.findall(r'^```',s,re.M))%2:errors.append(f'{p}: unbalanced fence')
 records[str(p)]={'sha256':hashlib.sha256(s.encode()).hexdigest(),'lines':len(s.splitlines()),'local_links':links}
s=files[0].read_text()
question=s.split('## 設計者への問い\n',1)[1].split('\n## ',1)[0]
qs=re.findall(r'^\| Q(\d+)',question,re.M)
if qs!=['9']:errors.append(f'language question rows {qs}')
# All current numbered decisions must be present outside the one-row question table.
for n in [1,2,3,4,5,6,7,8,10,11,12,13,14]:
 if not re.search(rf'^\| Q{n}（',s,re.M):errors.append(f'missing decided Q{n}')
status=subprocess.run(['git','status','--porcelain','--untracked-files=all'],capture_output=True,text=True,check=True).stdout
for line in status.splitlines():
 p=line[3:]
 if p not in allowed and not p.startswith('work/m013/scratch/S9/'):
  errors.append(f'outside allowed files: {p}')
diff=subprocess.run(['git','diff','--check'],capture_output=True,text=True)
if diff.returncode:errors.append('git diff --check: '+diff.stdout+diff.stderr)
result={'date':'2026-10-27','base':'04c78e527e6c23c0be8a9dbce26f23d685a5e04d','files':records,'question_rows':qs,'status':status,'diff_check_returncode':diff.returncode,'errors':errors,'limits':'文書の静的な照合だけ。新構文、Rust/Leanの正しさ、ビルド・テスト成功を示さない。'}
Path('work/m013/scratch/S9/document-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'files':{p:v['lines'] for p,v in records.items()},'question_rows':qs,'errors':errors},ensure_ascii=False,indent=2))
if errors:raise SystemExit(1)
