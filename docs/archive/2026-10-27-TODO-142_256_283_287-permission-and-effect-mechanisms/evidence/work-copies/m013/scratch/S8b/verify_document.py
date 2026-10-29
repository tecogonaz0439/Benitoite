"""S8b の文書・参照・算術・変更範囲の静的な点検。ビルドやテストは実行しない。"""
from pathlib import Path
from urllib.parse import unquote
import hashlib,json,re,subprocess
out=Path('work/m013/scratch/S8b')
path=Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/study/language-rules.md')
review=path.parent.parent/'reviews/RV-S8.md'
before=json.loads((out/'before.json').read_text())
s=path.read_text()
def git(*args):
 p=subprocess.run(['git',*args],text=True,capture_output=True)
 assert p.returncode==0,p.stderr
 return p.stdout
checks={}
checks['branch_unchanged']=git('branch','--show-current').strip()==before['branch']=='san_benito'
checks['head_unchanged']=git('rev-parse','HEAD').strip()==before['head']
checks['only_allowed_tracked_file_changed']=git('diff','--name-only').splitlines()==[str(path)]
checks['index_unchanged']=not git('diff','--cached','--name-only')
checks['review_unchanged']=hashlib.sha256(review.read_bytes()).hexdigest()==before['review_sha256']
checks['diff_whitespace']=not git('diff','--check')
qsection=s.split('## 設計者への問い\n',1)[1].split('## 未確認の事実\n',1)[0]
rows=re.findall(r'^\| Q(\d+) \|.*$',qsection,re.M)
checks['questions_1_to_14']=rows==[str(i) for i in range(1,15)]
checks['question_columns']=all(len(row.split('|'))==8 and all(c.strip() for c in row.split('|')[1:-1]) for row in qsection.splitlines() if re.match(r'^\| Q\d+ \|',row))
old=set()
for n in re.findall(r'\bR(\d+)\b',s.split('## 決まっていること\n',1)[1].split('## 未確認の事実\n',1)[0]): old.add(int(n))
checks['all_old_numbers_mapped']=old==set(range(1,24))
handling=s.split('## RV-S8 への対応\n',1)[1]
checks['review_findings_covered']=all(f'| {tag}' in handling for tag in ['重1','重2','中1','中2','中3','中4','中5','中6','軽1','軽2','軽3'])
checks['handling_is_last_section']=s.rfind('\n## ')==s.index('\n## RV-S8 への対応')
checks['no_todo_links']=not re.search(r'\]\([^)]*docs/todo',s)
checks['agreed_terms']=all(term in s for term in ['情報フロー制御（information-flow control）','セキュリティ型システム（security type system）','非干渉性','非機密化（declassification）','エンドースメント（endorsement。信頼の付与、または完全性レベルの引き上げ）'])
links=[]
prose=re.sub(r'^```[^\n]*\n.*?^```[^\n]*$', '', s, flags=re.M|re.S)
for label,url in re.findall(r'\[([^\]]+)\]\(([^)]+)\)',prose):
 if url.startswith(('http://','https://')): continue
 target,_,anchor=url.partition('#')
 p=path.parent/unquote(target) if target else path
 exists=p.is_file()
 anchor_ok=True
 if anchor and exists:
  headings=re.findall(r'^#{1,6} (.+)$',p.read_text(),re.M)
  def slug(x):
   x=x.lower().replace(' ','-')
   return re.sub(r'[^\w\-\u3000-\u9fff]', '', x)
  anchor_ok=unquote(anchor) in [slug(h) for h in headings]
 links.append({'label':label,'target':url,'exists':exists,'anchor_exists':anchor_ok})
checks['local_links']=all(v['exists'] and v['anchor_exists'] for v in links)
fences=re.findall(r'^```.*$',s,re.M)
checks['closed_code_fences']=len(fences)%2==0
checks['start_commit']='開始版3597b310' in s and 'の `3597b310ea0d91fb3a3bb3fcf281c7aa57ac9a34`' in s
checks['no_old_bad_plan']=not any(x in s for x in ['46時間の側ならおよそ60〜92','110〜120作業','一度の型構成子変更で接続','declassification と endorsement は原語で書く'])
budget=json.loads((out/'time-budget.json').read_text())
checks['lean_capacity']=budget['lean']['total_hours']==[46,110] and budget['lean']['reserved']==220
checks['implementation_capacity']=budget['implementation']['total_hours']==[48,118] and budget['implementation']['reserved']==236
bad_abs=[]
for p in [path,*[f for f in out.iterdir() if f.is_file()]]:
 # 文字列を組み合わせ、点検スクリプト自身へ手元のパスを埋め込まない。
 if re.search(r'/(?:'+'Users|home|private/tmp'+r')/',p.read_text()): bad_abs.append(str(p))
checks['no_local_absolute_paths']=not bad_abs
result={'date':'2026-10-27','document':str(path),'questions':len(rows),'checks':checks,'local_links':links,'absolute_path_findings':bad_abs,'limits':'文書の静的な点検。Rust・Lean・CLI・評価・checkスクリプトの実行結果ではない。'}
(out/'document-check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'questions':len(rows),'checks':checks,'failures':[k for k,v in checks.items() if not v]},ensure_ascii=False,indent=2))
assert all(checks.values())
