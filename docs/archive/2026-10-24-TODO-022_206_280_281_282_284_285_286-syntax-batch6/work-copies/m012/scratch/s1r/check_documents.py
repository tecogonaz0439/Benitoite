from pathlib import Path
import re,json,difflib,hashlib
base=Path('docs/2026-10-24-TODO-022_206_280_281_282-syntax-batch6')
files=[base/'study/interval-analysis.md',base/'study/interval-analysis-questions.md',base/'reviews/RV-S1-response.md']
issues=[];stats=[]
for p in files:
 s=p.read_text();fenced=False;table_cols=None
 for n,line in enumerate(s.splitlines(),1):
  if line.startswith('```'):fenced=not fenced
  if line.rstrip()!=line:issues.append(f'{p}:{n}: trailing whitespace')
  if line.startswith('|') and not fenced:
   cols=len(re.split(r'(?<!\\)\|',line))-2
   if table_cols is None:table_cols=cols
   elif cols!=table_cols:issues.append(f'{p}:{n}: table cols {cols}, expected {table_cols}')
  else:table_cols=None
 if fenced:issues.append(f'{p}: unmatched fence')
 for label,target in re.findall(r'\[([^\]]+)\]\(([^)]+)\)',s):
  if target.startswith(('https:','http:','#')):continue
  local=target.split('#')[0]
  if not (p.parent/local).exists():issues.append(f'{p}: broken local link {target}')
 if re.search(r'/Users/|/home/|\]\([^)]*docs/todo',s):issues.append(f'{p}: forbidden path/link')
 stats.append({'file':str(p),'lines':len(s.splitlines()),'bytes':len(s.encode()),'sha256':hashlib.sha256(s.encode()).hexdigest()})
 for link in re.finditer(r'本文第(\d+)(?:\.(\d+))?節',s):
  main=files[0].read_text();chapter=link.group(1);sec=link.group(2)
  head=f'### {chapter}.{sec} ' if sec else f'## {chapter}. '
  if head not in main:issues.append(f'{p}: missing section {link.group(0)}')
for p in files[:2]:
 old=Path('work/m012/scratch/s1r')/(p.name+'.before')
 delta=''.join(difflib.unified_diff(old.read_text().splitlines(True),p.read_text().splitlines(True),fromfile=p.name+'.before',tofile=p.name))
 (Path('work/m012/scratch/s1r')/(p.name+'.diff')).write_text(delta)
response=files[2].read_text()
for key in [*[f'E{i}' for i in range(1,7)],*[f'V{i}' for i in range(1,5)],*[f'F{i}' for i in range(1,5)],*[f'問いの所見Q{i}' for i in range(1,5)],'文書の規範: 用語','文書の規範: 略記']:
 if '| '+key not in response:issues.append('missing response row: '+key)
questions=files[1].read_text()
if re.findall(r'^\| Q(\d+)',questions,re.M)!=['1','2','3','4']:issues.append('question IDs are not Q1-Q4')
result={'issues':issues,'files':stats}
Path('work/m012/scratch/s1r/document-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False,indent=2))
