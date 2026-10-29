"""保存済みの公開境界の出力を独立した期待値で点検する。"""
from pathlib import Path
import json,hashlib,difflib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def read(variant):
    return {Path(r['path']).stem:r for r in map(json.loads,(HERE/(variant+'.jsonl')).read_text().splitlines())}
b=read('baseline');p=read('prototype')
assert len(b)==len(p)==94
def codes(row): return sorted(d['code'] for d in row['lex']+row['parse'])
def expect(name, expected):
    assert codes(p[name])==sorted('Some('+e+')' for e in expected),(name,codes(p[name]))

positive=['when_format','when_format_crlf','when_nested','when_call','default_format',
    'lambda_format','lambda_format_crlf','lambda_header_good','lambda_nested_format','lambda_nested_both',
    'lambda_explicit_format','outer_lambda_explicit_format','named_arg','record','record_pattern',
    'block_type','short_bind','function_type','triple','triple_crlf','with_resource_format','list_format',
    'hash_number','caret','number_precision','multiple','japanese_head','number_decimal_spec','nested_raw']
for name in positive: expect(name,[]); assert p[name]['formats'],name

legacy=['when_old','when_guard_real_colon','when_guard_old_plain','with_when_old']
for name in legacy: expect(name,['E0232'])
expect('default_old',['E0239'])
expect('lambda_header_bad',['E0234'])
assert b['when_format']['parse'][0]['text']=='+'
assert b['default_format']['parse'][0]['text']==':'
assert b['lambda_format']['parse'][0]['text']==':'

preserved={
    'bad_number_expr':['E0115'],'bad_number_plain':['E0115'],
    'bad_number_nested':['E0115'],'bad_number_after':['E0115'],
    'number_bad_suffix_expr':['E0124'],'number_wrong_form_expr':['E0127'],
    'string_tail_number_error':['E0115'],
    'bad_symbol_expr':['E0105'],'bad_symbol_plain':['E0105'],
    'bidi_format':['E0104'],'utf8_format':['E0102'],
    'unicode_escape':['E0110'],'lone_cr':['E0107'],
    'unicode_expr':['E0103','E0201'],'utf8_expr':['E0102','E0201'],
    'comment_format':['E0120'],'failed_expr':['E0201','E0116'],
    'newline_expr':['E0119','E0108','E0212'],
}
for name, expected in preserved.items(): expect(name,expected)
for name in ['bad_number_expr','bad_number_nested','number_bad_suffix_expr','number_wrong_form_expr','string_tail_number_error']:
    numeric=lambda r:sorted((d['code'],d['span'],d['text']) for d in r['lex']+r['parse'] if d['code'] in ['Some(E0115)','Some(E0124)','Some(E0127)'])
    assert numeric(b[name])==numeric(p[name]),name
assert not p['failed_expr']['formats']
assert p['failed_expr']['pending']
assert not p['bad_number_plain']['formats']
for name in ['bidi_format','utf8_format','unicode_escape','lone_cr','comment_format','newline_expr']:
    assert b[name]['lex']==p[name]['lex'],name

old_cases=['when_plain','default_plain','lambda_plain','lambda_nested_plain','block_type_plain',
    'raw','with_resource_plain','when_guard_old_plain']+[n for n in b if n.startswith('old_')]
for name in old_cases:
    assert codes(b[name])==codes(p[name]),name
    assert b[name]['ast']==p[name]['ast'],name
    assert b[name]['newlines']==p[name]['newlines'],name

expect('limit_inside',[]); expect('limit_outside',['E0208']);expect('expr_limit',['E0208'])
expect('limit_pending',['E0208']+['E0116']*4)
assert len(p['limit_pending']['pending'])==1001
assert len(p['limit_pending']['formats'])==997
for name in ['newline_statement_bracket','newline_statement_lambda','newline_statement_plain']:
    src=(HERE/'inputs'/(name+'.bnt')).read_bytes()
    assert p[name]['newlines']==[i for i,c in enumerate(src) if c==10],name
assert len(b['newline_statement_bracket']['newlines'])==1

for name,expected in {'hash_number':[':#08x'],'caret':[':^8'],'left_arrow':[':<-8'],
    'multiple':[':#08x',':^8',':8.2f'],'lambda_invalid_end':[':end lambda'],
    'lambda_nested_both':[':^8',':>8']}.items():
    assert [s['raw'] for s in p[name]['formats']]==expected,name
for name,row in p.items():
    src=(HERE/'inputs'/(name+'.bnt')).read_bytes()
    for f in row['formats']:
        start,end=f['span']
        assert src[start:end].decode(errors='replace')==f['raw'],name
        assert src[f['id']:f['id']+2]==b'${',name

state=json.loads((HERE/'start.json').read_text())
changed=[name for name,h in state['sha256'].items() if not (ROOT/name).is_file() or hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=h]
assert not changed,changed
base_mismatch=[]
for name in state['sha256']:
    if name.startswith('crates/benitoite/src/'):
        if (ROOT/name).read_bytes()!=(HERE/'baseline'/name).read_bytes(): base_mismatch.append(name)
assert not base_mismatch,base_mismatch
patch=[]; changed_src=[]
for path in sorted((HERE/'prototype/crates/benitoite/src').rglob('*.rs')):
    rel=path.relative_to(HERE/'prototype/crates/benitoite')
    old=(HERE/'baseline/crates/benitoite'/rel).read_text();new=path.read_text()
    if old!=new:
        changed_src.append(str(rel))
        patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+str(rel),tofile='b/'+str(rel)))
assert ''.join(patch)==(HERE/'prototype.patch').read_text()
result={'inputs':len(p),'positive_format_cases':len(positive),'old_ast_pairs':len(old_cases),
    'preserved_error_cases':len(preserved),'production_files_unchanged':len(state['sha256']),
    'scratch_source_files':changed_src,'patch_sha256':hashlib.sha256((HERE/'prototype.patch').read_bytes()).hexdigest()}
(HERE/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
