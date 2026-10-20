# coding: utf-8
from pathlib import Path
import re,subprocess,json,hashlib,unicodedata
D=Path('docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4');V=D/'v1'
files=[Path(f) for f in subprocess.check_output(['git','diff','--name-only'],text=True).splitlines() if f.endswith('.md')]
def anchors(p):
 seen={};out=set()
 for h in re.findall(r'^#{1,6} (.+)$',p.read_text(),re.M):
  h=h.lower().replace('`',''); h=''.join(c for c in h if c in '-_ ' or unicodedata.category(c)[0] in 'LN') .replace(' ','-')
  n=seen.get(h,0);seen[h]=n+1;out.add(h+(f'-{n}' if n else ''))
 return out
links=[];errors=[];anchor_errors=[]
for p in files:
 # Code fences can contain example Markdown such as [text](...).
 source=re.sub(r'```.*?```','',p.read_text(),flags=re.S)
 for target in re.findall(r'(?<!!)\[[^\]]*\]\(([^\s)]+)\)',source):
  target=target.strip('<>')
  if target=='...':continue
  if '://' in target or target.startswith(('mailto:','app:')):continue
  file,_,fragment=target.partition('#');dest=p.parent/file if file else p
  if not dest.exists():errors.append([str(p),target]);continue
  links.append([str(p),target])
  if fragment and dest.suffix=='.md' and fragment not in anchors(dest):anchor_errors.append([str(p),target])
assert not errors,errors
print('local file links',len(links),'broken anchors',anchor_errors)
# Match newly introduced examples and the six handcrafted Skill document pairs.
for source,target in [('docs/reference/benitoite.md','docs/ja/reference/benitoite.md'),('crates/benitoite/skill/references/idioms.md','docs/ja/skill/references/idioms.md')]:
 a=Path(source).read_text();b=Path(target).read_text()
 for name in ['function sign(', 'function checkedLists(', 'bind text <- block','Log.debug(message: "starting"']:
  if name not in a:continue
  block=next(m for m in re.findall(r'```benitoite[^\n]*\n.*?```',a,re.S) if name in m);assert block in b,(target,name)
# The planned 13 outside rows must each be unique and state a reason and a check.
text=Path('docs/design/07-quality/07-04-formal-semantics.md').read_text()
rows=['Logの位置の事前展開・名前解決・CLI','Logの既定書式とIO','判定の共有と行ごとの照合','自由変数・生存の解析とIR検査の表','構築器の物理バッファ・容量と予約失敗','構築器のGC・継続の保持とタスク取消','Writerの解放と中断','deriveの宣言グラフと生成器','deriveの縮小と生成記録','旧移行道具の保管','参照値とヒープ値の橋渡し','Engine・Componentの共有','宣言由来の診断と型名・整数の警告']
outside=[]
for name in rows:
 found=[l for l in text.splitlines() if l.startswith('| '+name+' |')];assert len(found)==1,name
 parts=found[0].split('|');assert parts[2].strip()=='対象外';assert len(parts[3])>60
 outside.append({'name':name,'line':text.splitlines().index(found[0])+1,'boundary':parts[3].strip()})
# Compare the embedded logical list with the actual distribution files, excluding translations.
bundle=Path('crates/benitoite/src/cli/tools/skill/bundle.rs').read_text();names=re.findall(r'path: "(.*?)"',bundle)
actual=sorted(str(p.relative_to('crates/benitoite/skill')) for p in Path('crates/benitoite/skill').rglob('*') if p.is_file())
assert sorted(names)==sorted(actual+['LICENSE-MIT','LICENSE-APACHE']),(len(names),len(actual))
assert all(not n.startswith(('docs/','ja/')) for n in names)
assert {'references/stdlib/'+n+'.md' for n in ['Log','SourceLocation','Range','NonEmptyList']}<=set(names)
for n in ['SKILL.md','references/idioms.md','references/common-mistakes.md','references/inspection.md','references/language-comparison.md']:
 assert 'Benitoite 0.0.10 の英語版' in Path('docs/ja/skill',n).read_text()
assert 'version = "0.0.10"' in Path('crates/benitoite/Cargo.toml').read_text()
r={'local_file_links':len(links),'errors':errors,'anchor_errors':anchor_errors,'new_examples_agree':True,'outside_rows':outside,'embedded_files':len(names),'modules':len(list(Path('crates/benitoite/skill/references/stdlib').glob('*.md')))-1,'handwritten_japanese_documents':5}
(V/'document-audit.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in r.items() if k not in ('outside_rows',)})
assert not anchor_errors
