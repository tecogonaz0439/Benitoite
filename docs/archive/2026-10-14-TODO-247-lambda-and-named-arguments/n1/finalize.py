import json,pathlib,re,collections,hashlib,subprocess,sys
out=pathlib.Path('docs/2026-10-14-TODO-247-lambda-and-named-arguments/n1'); tmp=pathlib.Path(sys.argv[1])
def save(name,data): (out/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
rows=[json.loads(s) for s in (tmp/'ast.jsonl').read_text().splitlines()]; recovered={(r['path'],r['snippet']):r for r in map(json.loads,(tmp/'recovered.jsonl').read_text().splitlines())}
rows=[recovered.get((r['path'],r['snippet']),r)for r in rows]
generated=[json.loads(s)for s in (tmp/'generated.jsonl').read_text().splitlines()]
assert len(generated)==300
assert all(r['typed'] for r in generated)
joins=[];decls=[];statuses=[]
for r in rows+generated:
 if r['path'].startswith('crates/benitoite/src/prelude/stdlib/'):
  module=r['path'].split('stdlib/')[1][:-4].replace('/','.')
  for d in r['declarations']:
   d.update(path=r['path'],module=module)
   for t in d['inner_function_types']:
    short=d['name'].split('.')[-1];arity=t['arity']
    if arity==0:names=[]
    elif module=='Map':names=['acc','key','value'] if arity==3 else ['key','value']
    elif module=='Regex':names=['matched']
    elif module=='Network.Http':names=['request']
    elif module=='Result' and short=='mapError':names=['error']
    elif arity==2:names=['acc','value']
    else:names=['value']
    assert arity==len(names)
    t['candidate_names']=names
   decls.append(d)
  continue
 metadata={k:r[k]for k in ('path','snippet','base_line','scope','intent','typed','parse_errors','check_codes')}
 metadata['recovered_error_types']=r.get('recovered_error_types',False);metadata['recovery_error']=r.get('recovery_error');metadata['entry_error']=r.get('entry_error')
 statuses.append(metadata)
 for j in r['joins']:
  if j['kind']=='return' and not any('Fn(' in t for t in j['value_types']):continue
  j.update(metadata);j['source_line_hint']=r['base_line']+j['position']['line']-1
  ns=[s['names']for s in j['contract_sources']if 'names'in s]
  j['candidate_names']=ns[0]if ns else None
  j['candidate_status']='review_declaration_contract'if any(s['kind']!='lambda'for s in j['contract_sources']) else ('first_source_lambda'if ns else 'needs_component_analysis')
  # 型検査でエラーになった成分の案は採用しない。
  if r.get('recovered_error_types'):j['candidate_status']='error_input_review'
  joins.append(j)
# 付録の全宣言について、関数名・モジュール・外側の名前・重複数を照合する。
actual=collections.Counter((d['module'],tuple(d['params']),d['name'].split('.')[-1])for d in decls)
expected=collections.Counter()
for line in (out.parent/'design.md').read_text().split('## 付録:')[1].splitlines():
 cells=line.split('|')
 if len(cells)!=5 or not cells[1].strip().startswith('`'):continue
 module=cells[1].strip().strip('`'); names=tuple(re.findall(r'`([^`]+)`',cells[2]))
 for name in re.findall(r'`([^`]+)`（\d+）',cells[3]):expected[(module,names,name)]+=1
assert actual==expected, (actual-expected,expected-actual)
save('q10-declarations',decls);save('typed-inputs',statuses);save('joins',joins)
inputs=json.loads((tmp/'generated-inputs.json').read_text());save('generated-snapshot',[{'seed':i,'max_stage':6,'sha256':hashlib.sha256(r['source'].encode()).hexdigest()}for i,r in enumerate(inputs)])
golden=json.loads((out/'golden-baseline.json').read_text()); gm={r['case']:r for r in golden}
def owner(p):
 stem=p[:-4] if p.endswith('.bnt') else p
 if stem in gm:return gm[stem]
 if '.files/'in p and p.split('.files/')[0]in gm:return gm[p.split('.files/')[0]]
 for a in pathlib.Path(p).parents:
  if str(a)in gm:return gm[str(a)]
 return None
cs=json.loads((out/'call-candidates.json').read_text())
for r in cs:
 g=owner(r['path']);st=next((x for x in statuses if x['path']==r['path']and x['snippet']==r['snippet']),None)
 if r['scope']in {'history','study','generated_document'}:cl='history_or_excluded'
 elif g:cl='success'if g['exit']==0 else 'intended_failure';r['golden_owner']=g['case'];r['expected_exit']=g['exit'];r['expected_diagnostics']=g['diagnostics']
 elif r['scope']=='generated_input':cl='generated_input'
 elif st and st['typed']:cl='success'
 else:cl='generated_input';r['review_reason']='fragment, explanatory example, or dependency context not reconstructed'
 r['classification']=cl
save('call-candidates',cs)
# 文言中の function() も含む、型表示に影響しうる 11 件の厳密な旧表示。
ds=[]
for p in sorted(pathlib.Path('crates/benitoite/testdata').rglob('*.diag.json')):
 if 'function('not in p.read_text():continue
 ds.append({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'diagnostics':[json.loads(s)for s in p.read_text().splitlines()]})
assert len(ds)==11
unchanged={'effects/effect_var_rigid.diag.json','effects/outermost_only.diag.json','types/equality_function.diag.json','types/equality_summary.diag.json'}
for row in ds:row['display_classification']='zero_parameter_display_unchanged'if row['path'].split('testdata/')[1]in unchanged else 'nonzero_parameter_display_or_help_candidate'
save('type-display-baseline',ds)
langs=json.loads((out/'language-declarations.json').read_text())
for r in langs:
 p=r['path'];v=r['version']
 if r['scope']=='history':purpose='historical'
 elif p.endswith('modules/package.rs'):purpose='E0907_E0908_boundary'
 elif v=='99.0.0':purpose='future_version_or_search_isolation'
 elif p.endswith('syntax/parser/header.rs')or p.endswith('tests/spec_examples.rs')and v not in {'0.0.3','0.0.4'}:purpose='header_syntax'
 elif p.endswith('tests/spec_examples.rs'):purpose='fixture_generator'
 elif p.endswith('modules/hash.rs'):purpose='hash_bytes'
 elif any(t in p for t in ['formatter/','fmt_command','testdata/fmt/']):purpose='format_preservation'
 elif any(t in p for t in ['package/tests.rs','package_command.rs','modules/tests.rs','external/tests.rs','test_command.rs']):purpose='module_package_header_or_execution'
 elif p.startswith('crates/benitoite/testdata/packages/')or p.startswith('crates/benitoite/testdata/external/'):purpose='module_package_fixture'
 else:purpose='ordinary_example'
 r['purpose']=purpose
save('language-declarations',langs)
summary={'head':subprocess.check_output(['git','rev-parse','HEAD']).decode().strip(),'rustc':subprocess.check_output(['rustc','--version']).decode().strip(),'cargo':subprocess.check_output(['cargo','--version']).decode().strip(),'call_classifications':dict(collections.Counter(r['classification']for r in cs)),'call_current_by_kind':dict(collections.Counter(r['kind']for r in cs if r['scope']not in {'history','study','generated_document'})),'lexical_bnt_multi':sum(r['path'].endswith('.bnt')and r['kind']=='function'and r['explicit_args']>=2 and r['scope']=='current'for r in cs),'lexical_bnt_pipe':sum(r['path'].endswith('.bnt')and r['kind']=='function'and r['explicit_args']==1 and r['scope']=='current'for r in cs),'joins':dict(collections.Counter(j['kind']for j in joins)),'joins_typed_success':dict(collections.Counter(j['kind']for j in joins if j['typed'])),'joins_recovered_errors':dict(collections.Counter(j['kind']for j in joins if j['recovered_error_types'])),'input_count':len(rows),'standalone_typed':sum(r['typed']for r in rows),'parse_error_inputs':sum(r['parse_errors']>0for r in rows),'recovered_error_type_inputs':sum(r.get('recovered_error_types',False)for r in rows),'golden_count':len(golden),'golden_exits':dict(collections.Counter(str(r['exit'])for r in golden)),'q10_appendix_exact_match':actual==expected,'stdlib_declarations':len(decls),'stdlib_groups':len({(d['module'],tuple(d['params']))for d in decls}),'stdlib_inner_types':sum(len(d['inner_function_types'])for d in decls),'language_by_purpose':dict(collections.Counter(r['purpose']for r in langs)),'language_by_version':dict(collections.Counter(r['version']for r in langs))}
save('summary',summary);print(json.dumps(summary,ensure_ascii=False,indent=2))
