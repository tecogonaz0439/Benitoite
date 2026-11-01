"""再開後の全差分・保護入力・保存した出力・公理依存を照合する。"""
from pathlib import Path
import collections, datetime, hashlib, json, re, subprocess, tempfile
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parent.parent
PREFIX = 'Benitoite.Release.Refinement.'
MODULES = ['TypeRegularity','TypeBounds','TypeRows','TypeVariables','TypeShiftFacts','EffectFacts','TypeArgumentRegularity']
BASE = '42a09116fd2442fca93b38a7e18b8138356a8dcc'
ALLOWED = {'propext','Quot.sound','Classical.choice'}
SOURCE_EDITS = set('''HandlerOperation HandlerAlgebra Narrowing NarrowingObstruction TypingShift
SubstTyping ReferencePreservation AdmissibleMap TypeBounds HandlerCalls ClosedCapture KindValues
LegacyDeclarations Typing TypingDeclared TypedFacts LazyPreservation ValueFacts TypeShiftKinds
Admissible SubstTypingObstruction LegacyInput TypeShiftTyping LegacyValues Context/Declarations'''.split())

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def saved_path(name):
    return Path(tempfile.gettempdir())/Path(name).name if name.startswith('<tmp>/') else HERE/name

def initial(name):
    meta=json.loads((HERE/name).read_text());path=saved_path(meta['file'])
    if path.stat().st_size!=meta['bytes'] or sha(path)!=meta['sha256']:
        raise SystemExit('INITIAL_HASH_MISMATCH '+name)
    return json.loads(path.read_text())

def main():
    old=initial('review-initial-record.json');first=initial('initial-record.json')
    protected=json.loads((HERE/'review-inputs.json').read_text())
    protected.update(json.loads((HERE/'coordinator-inputs.json').read_text()))
    for n,h in protected.items():
        if not (ROOT/n).is_file() or sha(ROOT/n)!=h: raise SystemExit('PROTECTED_INPUT_CHANGED '+n)
    changed=[n for n,h in old['files'].items() if not (ROOT/n).is_file() or sha(ROOT/n)!=h]
    allowed={f'formal/Benitoite/Release/Refinement/{m}.lean' for m in SOURCE_EDITS}
    allowed.update(['formal/Benitoite.lean','docs/design/01-spec/01-12-core-calculus.md',
        'docs/design/07-quality/07-04-formal-semantics.md','docs/design/00-overview/00-04-glossary.md'])
    allowed.update(str((CHANGE/n).relative_to(ROOT)) for n in ['l10/v/signatures.md','l10/v/results.md',
        'l10/v/boundary.lean','reviews/RV-L10.s2-request.md'])
    allowed.update(protected)  # 取りまとめが追記したレビュー等の現在の入力を固定する。
    for n in changed:
        if not (ROOT/n).is_file(): raise SystemExit('DELETED_INPUT '+n)
        if n not in allowed and not n.startswith(str(HERE.relative_to(ROOT))+'/'):
            raise SystemExit('UNEXPECTED_EXISTING_CHANGE '+n)
    for n,h in json.loads((HERE/'review-changes.json').read_text())['changed_existing'].items():
        if sha(ROOT/n)!=h:raise SystemExit('CHANGED_INPUT_HASH_MISMATCH '+n)
    latest={}
    for p in sorted(HERE.glob('run-*.json')):
        r=json.loads(p.read_text());path=saved_path(r['log'])
        if path.stat().st_size!=r['bytes'] or sha(path)!=r['sha256']:
            raise SystemExit('OUTPUT_HASH_MISMATCH '+p.name)
        # 同時実行の番号が重なる場合も、ラベルと開始時刻で最新版を選ぶ。
        if r['label'] not in latest or r['start_utc']>latest[r['label']]['start_utc']:
            latest[r['label']]=r|{'record':p.name}
    labels=['build','signatures','foundation','axioms','boundary','main-contracts',
        'v-boundary','review-t2','review-t3','review-t4','review-t5']
    final={n:latest[n] for n in labels}
    for label,r in final.items():
        if r['exit'] or r.get('verification_failure'): raise SystemExit('FAILED '+label)
        body=saved_path(r['log']).read_text();axs=set()
        for group in re.findall(r'depends on axioms: \[(.*?)\]',body,re.S):
            axs.update(x.strip() for x in group.split(',') if x.strip())
        if axs-ALLOWED or re.search(r"declaration uses ['‘]sorry|\bsorryAx\b",body):
            raise SystemExit('DISALLOWED_AXIOM '+label)
        r.update(axioms=sorted(axs),warnings=body.count('warning:'))
        if label!='build' and r['warnings']:raise SystemExit('FINAL_WARNING '+label)
    for n,count in [('signatures',160),('boundary',154)]:
        if final[n]['constants']!=count or final[n]['print_axioms_count']!=count:
            raise SystemExit('WRONG_LOCAL_COUNT '+n)
    mods=json.loads((HERE/'audit-modules.json').read_text());a=final['axioms']
    if set(a['modules'])!=set(mods) or sum(a['modules'].values())+18!=a['print_axioms_count']:
        raise SystemExit('INCOMPLETE_MODULE_AUDIT')
    audit_body=saved_path(a['log']).read_text()
    cases={m:int(n) for m,n in re.findall(r'TYPING_CASES (\S+) (\d+)',audit_body)}
    if len(cases)!=14 or sum(cases.values())!=76 or a['cases']!={'SINGLE':26,'PAIR':450}:
        raise SystemExit('WRONG_CASES')
    required=set(PREFIX+m for m in MODULES)
    required.update(n.removeprefix('formal/').removesuffix('.lean').replace('/','.') for n in changed if n.startswith('formal/') and n.endswith('.lean'))
    if required-set(mods):raise SystemExit('UNAUDITED_CHANGED_MODULE')
    f=json.loads((HERE/'foundation-map.json').read_text())
    if f['counts']!={'不要':43,'本群で完了':68,'既済':16,'前群で完了':31}:raise SystemExit('WRONG_FOUNDATION_COUNTS')
    expected={44:5,45:7,46:7,47:10,48:12,49:8,50:13,51:6}
    if dict(collections.Counter(r['unit'] for r in f['rows'] if r['disposition']=='本群で完了'))!=expected:
        raise SystemExit('WRONG_UNIT_COUNTS')
    imports=(ROOT/'formal/Benitoite.lean').read_text()
    suffix='\n'+''.join('import '+PREFIX+n+'\n' for n in MODULES)
    if not imports.endswith(suffix) or hashlib.sha256(imports.removesuffix(suffix).encode()).hexdigest()!=first['files']['formal/Benitoite.lean']:
        raise SystemExit('EXISTING_IMPORT_CHANGED')
    main=json.loads((HERE/'main-contracts.json').read_text())
    if len(main['rows'])!=10 or not all(r['header_unchanged'] and r['current_header_sha256']==r['full_header_sha256'] for r in main['rows']):
        raise SystemExit('MAIN_CONTRACT_CHANGED')
    for mod in mods:
        path=ROOT/'formal'/(mod.replace('.','/')+'.lean')
        if re.search(r'\b(sorry|admit)\b',path.read_text()):raise SystemExit('PROOF_HOLE '+mod)
        if re.search(r'^\s*axiom\b',path.read_text(),re.M):raise SystemExit('NEW_AXIOM '+mod)
    # 本群の文書・台本・入力には手元の絶対パスや消える作業領域の参照を残さない。
    for p in HERE.iterdir():
        if p.name.startswith('rv-') or not p.is_file():continue
        if p.stat().st_size>100000:raise SystemExit('LARGE_RAW_RECORD '+p.name)
        body=p.read_text()
        if re.search(r'/(?:Users|private/tmp|private/var|var/folders)/',body):raise SystemExit('ABSOLUTE_PATH '+p.name)
    if '"-M", "12288"' not in (ROOT/'formal/lakefile.toml').read_text():raise SystemExit('MEMORY_CONFIG')
    version=subprocess.run(['lake','env','lean','-M','12288','--version'],cwd=ROOT/'formal',check=True,stdout=subprocess.PIPE).stdout.decode().strip()
    inputs={n:sha(ROOT/n) for n in changed}
    for m in MODULES:inputs['formal/Benitoite/Release/Refinement/'+m+'.lean']=sha(ROOT/'formal/Benitoite/Release/Refinement'/(m+'.lean'))
    inputs.update(protected)
    for p in HERE.iterdir():
        if p.is_file() and p.suffix in ['.lean','.md','.py','.json'] and not p.name.startswith('run-') and p.name!='verification.json':
            inputs[str(p.relative_to(ROOT))]=sha(p)
    for n in ['formal/lakefile.toml','formal/lean-toolchain',str((CHANGE/'reviews/RV-L10.s2-request.md').relative_to(ROOT))]:inputs[n]=sha(ROOT/n)
    start=json.loads((HERE/'rereview-start.json').read_text())['started_utc'];end=datetime.datetime.now(datetime.timezone.utc).isoformat()
    result=dict(base=BASE,branch='m014/l10.s2',git_verification=False,toolchain=version,
        memory_mib=12288,existing_inputs=len(old['files']),protected_inputs=len(protected),changed_existing=changed,
        unchanged_existing=len(old['files'])-len(changed),new_modules=MODULES,inputs=inputs,checks=final,
        foundation=f['counts'],unit_counts=expected,typing_cases=cases,typing_total=76,typing_judgments=14,
        transport_families=['shift_values','shift_types','subst','narrow'],main_contracts_unchanged=10,
        axioms_total=sum(r['print_axioms_count'] for r in final.values()),allowed_axioms=sorted(ALLOWED),
        first_clock_utc=start,ended_utc=end,outer_seconds=(datetime.datetime.fromisoformat(end)-datetime.datetime.fromisoformat(start)).total_seconds(),
        rss='未取得（計画上の非採取）',work='取りまとめ担当。未実行',
        notes=['再開前の控えを保護照合の基準とする。初回のsnapshotは既定importの比較にも使用。',
        '主な十定理は、群Vの保存したソースから本体開始までの完全な宣言を抽出して照合。',
        'rv-s2-t1は変更前の型付けを作る入力のため再成功を要求しない。boundaryの拒否と通常の型引数の正例で処置を検査。',
        '再レビューの原本への取りまとめの追記とt5は、今回の開始前に配置された入力としてreview-inputs.jsonで固定する。',
        '能動時間と待ちは分離していない。'])
    (HERE/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    for k in ['existing_inputs','protected_inputs','unchanged_existing','axioms_total','outer_seconds']:print(k,result[k])
    for label,r in final.items():print(label,r['exit'],r['seconds'],'warnings',r['warnings'])

if __name__=='__main__':main()
