"""固定19本文・旧734Lean・具体ソースとの対応と局所成果を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re, runpy
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULES = ['StandardSafeContracts','StandardSafeAnnotations','StandardSafeAccess',
           'StandardSafeBodies','StandardSafeFieldGap','StandardSafeSlice']

def digest(data):
    return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}

def read(relative):
    return (ROOT / relative).read_text()

def function(text, signature):
    first = text.index(signature)
    return text[first:text.index('end function',first)+len('end function')]

def main():
    old = json.loads((HERE/'baseline-r1-u26.json').read_text())
    captured = {}
    for part in old['files_parts']:
        data = (HERE/part['file']).read_bytes()
        assert digest(data)=={k:part[k] for k in ['bytes','sha256']}
        captured.update(json.loads(data))
    for relative,expected in captured.items():
        data=(ROOT/relative).read_bytes()
        if relative=='formal/Benitoite.lean': data=data[:expected['bytes']]
        assert digest(data)==expected, relative
    lean = [p for p in (ROOT/'formal').rglob('*.lean') if '.lake' not in p.parts]
    assert len(lean)==old['lean_sources']+len(MODULES)
    fixed=(HERE.parent/'a/safe-contracts.lean').read_bytes()
    assert hashlib.sha256(fixed).hexdigest()=='b8bc4b877992e4f43560b46cad38151f3825882b2b49f0e1c91d4e28005e9172'
    copied=(ROOT/'formal/Benitoite/Release/Refinement/StandardSafeContracts.lean').read_bytes()
    assert copied[copied.index(b'open Benitoite'):]==fixed[fixed.index(b'open Benitoite'):]
    imports=read('formal/Benitoite.lean')
    listed=json.loads((HERE/'modules-r1.json').read_text())
    evidence={}
    publics=[]
    allcode='\n'.join(read(f'formal/Benitoite/Release/Refinement/{m}.lean') for m in MODULES)
    for module in MODULES:
        relative=f'formal/Benitoite/Release/Refinement/{module}.lean'
        code=read(relative)
        assert f'import Benitoite.Release.Refinement.{module}\n' in imports
        assert module in listed
        assert not re.search(r'\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval',code)
        assert not re.search(r'\b(?:L\d{2}(?:\.\d+)?|O\d{3}|TODO-\d{3})\b|/Users/',code)
        olean=ROOT/f'formal/.lake/build/lib/lean/Benitoite/Release/Refinement/{module}.olean'
        assert olean.exists() and olean.stat().st_mtime>=(ROOT/relative).stat().st_mtime
        evidence[relative]={'input':digest((ROOT/relative).read_bytes())}
        for match in re.finditer(r'(?m)^(?:@\[simp\] )?(?:theorem|def|structure) ([A-Za-z_][A-Za-z0-9_]*)',code):
            name=match.group(1)
            count=len(re.findall(r'\b'+re.escape(name)+r'\b',allcode))
            assert count>1, (module,name)
            publics.append({'module':module,'name':name,'line':code.count('\n',0,match.start())+1,'textual_occurrences':count})
    # The following are preserved source excerpts, not execution tests.
    specs={
      'crates/benitoite/src/prelude/stdlib/Range.bnt':[(100,142),(158,266)],
      'crates/benitoite/src/prelude/stdlib/NonEmptyList.bnt':[(25,74)],
      'crates/benitoite/src/prelude/stdlib/Result.bnt':[(1,22)],
      'crates/benitoite/src/prelude/stdlib/List.bnt':[(16,32)],
      'crates/benitoite/src/builtins/funcs/list.rs':[(171,220)],
      'crates/benitoite/src/builtins/table.rs':[(216,226),(665,670),(1000,1020),(1044,1056),(1501,1521)],
      'crates/benitoite/src/base/parameter_names.rs':[(1,35)],
      'crates/benitoite/src/runtime/list.rs':[(242,279)],
      'crates/benitoite/src/ir/desugar/decls.rs':[(254,341)],
      'crates/benitoite/tests/desugar_export/exchange.rs':[(2462,2496)]}
    for relative,spans in specs.items():
        raw=(ROOT/relative).read_bytes();lines=raw.decode().splitlines(keepends=True)
        evidence[relative]={'input':digest(raw),'excerpts':[{'first':a,'last':b,'text':''.join(lines[a-1:b])} for a,b in spans]}
    source=read('crates/benitoite/src/prelude/stdlib/Range.bnt')
    records={
      'CheckedInteger':(['minimum: Integer','maximum: Integer','value: Integer'],0),
      'CheckedLength':(['minimum: Integer','maximum: Integer','length: Integer','values: List[T]'],1),
      'CheckedIndex':(['values: List[T]','index: Integer','element: T'],1)}
    checked=[]
    for name,(fields,arity) in records.items():
        first=source.index('public record '+name)
        block=source[first:source.index('end record',first)]
        assert [block.index(f) for f in fields]==sorted(block.index(f) for f in fields)
        checked.append({'data':'Benitoite.Range.'+name,'constructor':'Benitoite.Range.'+name,'type_parameters':arity,'fields':fields})
    wrappers={
      'minimum':'CheckedInteger.minimum(value)','maximum':'CheckedInteger.maximum(value)',
      'value':'CheckedInteger.value(value)','lengthMinimum':'CheckedLength.minimum(value)',
      'lengthMaximum':'CheckedLength.maximum(value)','checkedLength':'CheckedLength.length(value)',
      'lengthValues':'CheckedLength.values(value)','indexValue':'CheckedIndex.index(value)',
      'indexValues':'CheckedIndex.values(value)','get':'CheckedIndex.element(value)'}
    wrapper_evidence=[]
    for name,call in wrappers.items():
        match=re.search(r'public function '+name+r'(?:\[T\])?\(',source)
        block=function(source,match.group())
        assert '(value:' in block and call in block
        wrapper_evidence.append({'name':name,'parameter':'value','getter_call':call,'source':block})
    ne=read('crates/benitoite/src/prelude/stdlib/NonEmptyList.bnt')
    assert 'public record NonEmptyList[T]\n  first: T\n  rest: List[T]' in ne
    assert 'fromList[T](values: List[T])' in ne
    for name in ['toList','head','tail','map']:
        assert re.search(r'public function '+name+r'\[[^\n]+\]\(value: NonEmptyList\[T\]',ne)
    assert 'Result.Ok(NonEmptyList(first: head, rest: tail))' in ne
    assert 'List.prepend(xs: NonEmptyList.rest(value), x: NonEmptyList.first(value))' in ne
    for api in ['head[T](xs: List[T]) -> Option[T]','tail[T](xs: List[T]) -> Option[List[T]]','get[T](xs: List[T], i: Integer) -> Option[T]']:
        assert api in read('crates/benitoite/src/prelude/stdlib/List.bnt')
    builtin=read('crates/benitoite/src/builtins/funcs/list.rs')
    assert 'u32::try_from(i)' in builtin
    assert 'let (Ok(front), Ok(back)) = (u32::try_from(front), u32::try_from(back))' in builtin
    assert '.checked_sub(back)' in builtin and '.filter(|end| *end >= front)' in builtin
    obligations=re.findall(r'^\| (O\d{3}) \|',(HERE/'obligations.md').read_text(),re.M)
    assert len(obligations)==len(set(obligations))==64
    for relative in ['docs/design/01-spec/01-12-core-calculus.md','docs/design/07-quality/07-04-formal-semantics.md']:
        for module in MODULES: assert module in read(relative)
    checks=json.loads((HERE/'checks-r1-u26.json').read_text())
    deviations=json.loads((HERE/'command-deviations-r1.json').read_text())
    actual=[{k:r[k] for k in ['label','start','command','exit']} for r in checks if r['command'][:2]==['lake','build'] and r['command']!=['lake','build']]
    assert deviations['executions']==actual and deviations['count']==len(actual)==23
    validate=runpy.run_path(str(HERE/'run-r1.py'))['validate_command']
    rejected = 0
    for command,formal in [(['lake','build','Target'],True),(['lake','build','-d','other'],True),
                          (['lake','build'],False),(['lake','env','lean','X.lean'],True),
                          (['lake','env','lean','-M12288','X.lean'],False)]:
        try: validate(command,formal)
        except ValueError: rejected += 1
        else: raise AssertionError(command)
    assert rejected == 5
    for command in [['lake','build'],['lake','env','lean','-M','12288','X.lean'],
                    ['lake','env','lean','-M12288','X.lean']]: validate(command,True)
    for item in checks:
        if any(item['start']==r['start'] and item['label']==r['label'] for r in actual):continue
        validate(item['command'],item['cwd']=='formal/')
    for p in HERE.iterdir():
        if p.is_file():
            assert p.stat().st_size<=100000,p.name
            text=p.read_text()
            assert str(ROOT) not in text,p.name
            if p.suffix=='.md':
                for link in re.findall(r'\]\(([^)]+)\)',text):
                    target=link.split('#')[0]
                    if target and '://' not in target: assert (p.parent/target).exists(),(p.name,target)
    result={'observed_utc':datetime.now(timezone.utc).isoformat(),'exit':0,
      'scope':'局所照合。全公理監査・独立レビュー・実Rust/Lean交換は含まない',
      'retained_lean_sources':old['lean_sources'],'current_lean_sources':len(lean),'modules':MODULES,
      'fixed_19':digest(fixed),'copied_body_equal':True,'obligations':64,
      'procedure_deviations':len(actual),'later_deviations':0,
      'records_under_100KB':True,'source_evidence':evidence,'checked_records':checked,
      'public_wrapper_differences':wrapper_evidence,
      'nonempty_difference':'現行nominal first/restとvalue/values。内部NE別名/xsへの変換はR40未完',
      'public_readers':publics}
    (HERE/'source-evidence-u26.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    assert (HERE/'source-evidence-u26.json').stat().st_size<=100000
    print(json.dumps({k:v for k,v in result.items() if k not in ['source_evidence','checked_records','public_wrapper_differences','public_readers']},ensure_ascii=False))

if __name__=='__main__':main()
