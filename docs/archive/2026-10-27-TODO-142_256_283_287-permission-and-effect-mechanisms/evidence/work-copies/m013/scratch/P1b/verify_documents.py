# coding: utf-8
"""指定された成果物の静的な整合と、書き込み範囲を確認する。"""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import unicodedata

D = Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms')
O = Path('work/m013/scratch/P1b')
names = ['decisions.md','plan.md','implementation-request.md','time-policy.md']
files = [D/name for name in names] + sorted((D/'evidence').rglob('*'))
files = [p for p in files if p.is_file()]
errors = []
links = []
def slug(s):
    s = re.sub(r'`([^`]*)`',r'\1',s).lower()
    s = ''.join(c for c in s if c in '-_ ' or unicodedata.category(c)[0] in 'LNM')
    return s.replace(' ','-')
for p in files:
    content = p.read_text()
    if any(x in content for x in ['/Users/', '/home/', 'file://']):
        errors.append([p.as_posix(),'手元の絶対パス'])
    if p.suffix == '.py':
        ast.parse(content, p.as_posix())
    if p.suffix != '.md':
        continue
    for label,link in re.findall(r'\[([^\]\n]+)\]\(([^)\n]+)\)',content):
        if '://' in link or link.startswith('mailto:'):
            continue
        if '/todo/' in link or 'docs/todo' in link or 'private' in link:
            errors.append([p.as_posix(),link,'禁止したリンク'])
            continue
        path,_,anchor = link.partition('#')
        target = (p.parent/path) if path else p
        if not target.exists():
            errors.append([p.as_posix(),link,'リンク先なし'])
        elif anchor:
            headings = [slug(m[1]) for m in re.finditer(r'^#{1,6}\s+(.+)$',target.read_text(),re.M)]
            if anchor not in headings:
                errors.append([p.as_posix(),link,'見出しなし'])
        links.append([p.as_posix(),link])
    width = None
    for i,line in enumerate(content.splitlines(),1):
        if line.startswith('|'):
            current = line.count('|')
            if width is not None and width != current:
                errors.append([p.as_posix(),i,'表の欄数',width,current])
            width = current
        else:
            width = None

decisions = (D/'decisions.md').read_text()
plan = (D/'plan.md').read_text()
if [int(n) for n in re.findall(r'^### 判断 (\d+) ',decisions,re.M)] != list(range(1,22)):
    errors.append('判断の番号')
if re.findall(r'^\| (DET-\d+) \|',decisions,re.M) != [f'DET-{n:02d}' for n in range(1,10)]:
    errors.append('細則の番号')
if re.findall(r'^### 作業 L00\.(\d+):',plan,re.M) != [f'{n:02d}' for n in range(1,9)]:
    errors.append('L00 の枝番号')
for name in names:
    s = (D/name).read_text()
    # 元番号の説明を除き、旧作業と旧細則の裸の番号を残さない。
    if re.search(r'(?<![A-Za-z0-9_-])(?:P(?:10|20|30)|Q(?:20|30)|F(?:10|20|30)|H10)(?![0-9])',s):
        errors.append([name,'旧作業 ID'])
    if name != 'decisions.md' and re.search(r'(?<![A-Za-z0-9_-])(?:D[1-9]|U[1-8])(?![0-9])',s):
        errors.append([name,'裸の調べ/細則番号'])

tests = sorted(set(re.findall(r'--test ([a-z][a-z_0-9]+)',plan)))
for name in tests:
    if not Path('crates/benitoite/tests',name+'.rs').is_file():
        errors.append(['統合対象なし',name])
manifest = json.loads((D/'evidence/copy-manifest.json').read_text())
for row in manifest:
    p = D/'evidence'/row['copy']
    if hashlib.sha256(p.read_bytes()).hexdigest() != row['sanitized_sha256']:
        errors.append(['複写ハッシュ不一致',row['copy']])
inventory = json.loads((D/'evidence/S8/lean-inventory.json').read_text())
changed_inventory_inputs = [name for name,h in inventory['sha256'].items()
                            if hashlib.sha256(Path(name).read_bytes()).hexdigest() != h]
if changed_inventory_inputs:
    errors.append(['S8 の棚卸し対象との差',changed_inventory_inputs])
reproduced = O/'reproduced/inventory'
inventory_diffs = [p.name for p in (D/'evidence/S8').iterdir()
                   if p.suffix != '.py' and p.read_bytes() != (reproduced/p.name).read_bytes()]
if inventory_diffs:
    errors.append(['棚卸しの再現差',inventory_diffs])

before = json.loads((O/'start.json').read_text())
changed = []
for name,h in before['tracked_hashes'].items():
    p = Path(name)
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != h:
        changed.append(name)
allowed = {str(D/name) for name in names}
unexpected = [name for name in changed if name not in allowed]
status = subprocess.check_output(['git','status','--short','--untracked-files=all'],text=True)
for row in status.splitlines():
    name = row[3:]
    if name not in allowed and not name.startswith(str(D/'evidence')+'/'):
        unexpected.append(name)
head = subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
branch = subprocess.check_output(['git','branch','--show-current'],text=True).strip()
if head != before['head'] or branch != 'san_benito':
    errors.append('HEAD/ブランチが変わった')
if unexpected:
    errors.append(['指定外の変更',unexpected])

counts = {'l00_hours':[1+.5+.5+.5+.5+2+.5+1.5,2+1+1+1+1+3+1+3],
          'lean_hours':[7+11+6+11+13+10,13+24+14+26+31+28],
          'rust_hours':[14+14+11+7+6+4,33+33+29+16+15+12],
          'docs_hours':[4,8], 'pm_hours':[6,14], 'if_hours':[9,18], 'ub_hours':[3,7],
          'l00_branch_count':8,'parallel_required_branches':34,'optional_branches':2}
counts['mandatory_total_hours'] = [sum(counts[k][i] for k in ('lean_hours','rust_hours','docs_hours','pm_hours','if_hours','ub_hours')) for i in (0,1)]
assert counts['l00_hours']==[7,13]
assert counts['lean_hours']==[58,136]
assert counts['mandatory_total_hours']==[136,321]
(O/'counts.json').write_text(json.dumps(counts,ensure_ascii=False,indent=2)+'\n')
report={'errors':errors,'head':head,'branch':branch,'changed_tracked_files':changed,
        'evidence_copies_verified':len(manifest),'inventory_inputs_verified':len(inventory['sha256']),
        'inventory_outputs_reproduced':len(list(reproduced.iterdir())),
        'links_checked':len(links),'explicit_test_targets_verified':tests,'counts':counts}
(O/'document-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
if errors:
    raise SystemExit(1)
