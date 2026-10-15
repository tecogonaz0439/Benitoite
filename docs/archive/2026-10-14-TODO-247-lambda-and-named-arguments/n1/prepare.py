import pathlib,subprocess,json,importlib.util,re,collections,hashlib,sys
root=pathlib.Path.cwd(); out=root/'docs/2026-10-14-TODO-247-lambda-and-named-arguments/n1'
spec=importlib.util.spec_from_file_location('counts',out.parent/'study/count-calls.py'); c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
paths=sorted(filter(None,subprocess.check_output(['git','ls-files','-z']).decode().split('\0')))
def scope(p):
 if p.startswith(('docs/archive/','reference/','tools/bench/results/','tools/syntax-measure/')) or p=='docs/reference/benitoite-minimal.md':return 'history'
 if p.startswith('docs/2026-10-14-TODO-247-'):return 'study'
 if p.startswith('crates/benitoite/skill/references/') and pathlib.Path(p).name not in {'idioms.md','common-mistakes.md','language-comparison.md','testing.md'}:return 'generated_document'
 if p.endswith('.rs') or p.endswith('.py'):return 'generated_input'
 return 'current'
def intent(p):
 q=root/p
 if p.startswith('crates/benitoite/testdata/'):
  stem=q.with_suffix(''); ex=pathlib.Path(str(stem)+'.exit')
  if ex.exists():return 'success' if ex.read_text().strip()=='0' else 'intended_failure'
  return 'fixture_or_module'
 return 'success_or_explanatory'
inputs=[]; candidates=[];langs=[]; golden=[]
for p in paths:
 if p.endswith('.mode') and p.startswith('crates/benitoite/testdata/'):
  stem=(root/p).with_suffix(''); sides=[]
  for suffix in ['bnt','mode','exit','stdout','stderr','diag.json','text.stderr','text.stdout','formatted','args','stdin']:
   f=pathlib.Path(str(stem)+'.'+suffix)
   if f.is_file():sides.append({'path':str(f.relative_to(root)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
  diag=pathlib.Path(str(stem)+'.diag.json'); ds=[json.loads(x) for x in diag.read_text().splitlines()] if diag.exists() else []
  golden.append({'case':str(stem.relative_to(root)),'mode':(root/p).read_text().strip(),'exit':int(pathlib.Path(str(stem)+'.exit').read_text()),'diagnostics':[d['code'] for d in ds],'sidecars':sides})
 if not p.endswith(('.bnt','.rs','.md','.py')):continue
 s=(root/p).read_text(errors='replace'); sc=scope(p)
 for i,(code,line) in enumerate(c.snippets(p,s)):
  for row in c.candidates(code,line):
   row.update(path=p,snippet=i,scope=sc,intent=intent(p)); candidates.append(row)
  for m in re.finditer(r'\blanguage\s+"([^"\n]+)"',code):
   version=m[1]; purpose='ordinary'
   if any(t in p for t in ['language_future','language_old','language_deprecated','package_command','cli_process']) or version not in {'0.0.3','0.0.4'}:purpose='version_or_syntax_test'
   langs.append({'path':p,'snippet':i,'line':line+code.count('\n',0,m.start()),'version':version,'scope':sc,'purpose':purpose})
  if sc in {'history','study','generated_document'}:continue
  inputs.append({'path':p,'snippet':i,'base_line':line,'source':code,'scope':sc,'intent':intent(p),'direct':p.endswith('.bnt')})
# ディレクトリのケースと .files の材料も、後の変更との比較に含める。
for row in golden:
 stem=root/row['case']; fixtures=[]
 for directory in [stem,pathlib.Path(str(stem)+'.files')]:
  if directory.is_dir():
   for f in sorted(directory.rglob('*')):
    if f.is_file():fixtures.append({'path':str(f.relative_to(root)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
 row['fixtures']=fixtures

# Python の生成元は Rust と同じ抽出器に入らないため、場所とハッシュで記録する。
generators=[{'path':p,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in paths if p.endswith(('.py','.rs')) and (p.startswith(('tools/','fuzz/')) or p.startswith('crates/benitoite/tests/random_programs') or p=='crates/benitoite/examples/gen_skill.rs')]
for name,data in [('call-candidates',candidates),('language-declarations',langs),('golden-baseline',golden),('generators',generators)]:
 (out/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
(pathlib.Path(sys.argv[1])/'inputs.json').write_text(json.dumps(inputs))
print('inputs',len(inputs),'calls',len(candidates),'languages',len(langs),'golden',len(golden))
print(collections.Counter((r['scope'],r['intent']) for r in candidates))
