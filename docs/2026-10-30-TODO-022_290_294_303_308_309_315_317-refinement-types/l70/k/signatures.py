"""基準と対象の公開宣言を比較する。git は読み取りだけに使う。"""
import argparse
import collections
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import io
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = 'dcaa396bad7a60d4da9b99d07ad9b75c0f328b07'
HEAD = 'de7fbf28cdebef9f5b62a7eb8457aecdaa988faa'


def clean(text):
    # 入れ子のブロックコメントと行コメントを除く。改行は位置のために残す。
    out, i, depth, string = [], 0, 0, False
    while i < len(text):
        pair = text[i:i+2]
        if depth:
            if pair == '/-': depth += 1; i += 2
            elif pair == '-/': depth -= 1; i += 2
            else:
                out.append('\n' if text[i] == '\n' else ' '); i += 1
        elif string:
            out.append(text[i])
            if text[i] == '\\' and i+1 < len(text):
                i += 1; out.append(text[i])
            elif text[i] == '"': string = False
            i += 1
        elif pair == '/-': depth = 1; out.append('  '); i += 2
        elif pair == '--':
            end = text.find('\n', i)
            if end < 0: break
            out.append('\n'); i = end+1
        else:
            if text[i] == '"': string = True
            out.append(text[i]); i += 1
    assert depth == 0
    return ''.join(out)


def normal(text):
    return re.sub(r'\s+', ' ', text).strip()


def header(text):
    # 束縛子の既定値の := は署名の一部として保つ。
    depth, string = 0, False
    for i, ch in enumerate(text):
        if ch == '"' and (i == 0 or text[i-1] != '\\'): string = not string
        if string: continue
        if ch in '({[': depth += 1
        elif ch in ')}]': depth -= 1
        elif depth == 0 and text[i:i+2] == ':=': return text[:i]
        elif depth == 0 and text[i:i+6] == ' where': return text[:i]
        elif depth == 0 and ch == '\n' and re.match(r'\s*\|', text[i+1:]): return text[:i]
    return text


def declarations(text):
    text = clean(text)
    lines = text.splitlines(keepends=True)
    scopes, result = [], {}
    decl = re.compile(r'^[ \t]*(?:@\[[^\n]*?\]\s*)?(?P<mods>(?:(?:private|protected|noncomputable|unsafe|partial) )*)(?P<kind>theorem|lemma|def|abbrev|inductive|structure)\s+(?P<name>[^\s({:]+)')
    for i, line in enumerate(lines):
        if re.match(r'^namespace\s+', line):
            scopes.append(('namespace',line.split()[1])); continue
        if re.match(r'^(?:noncomputable )?section\b|^mutual\s*$', line):
            scopes.append(('section','')); continue
        if re.match(r'^end(?:\s|$)',line):
            if scopes: scopes.pop()
            continue
        m = decl.match(line)
        if not m or 'private' in m['mods']: continue
        namespace = '.'.join(n for k,n in scopes if k == 'namespace')
        name = namespace+'.'+m['name'] if namespace else m['name']
        j = i+1
        while j < len(lines):
            s = lines[j]
            if decl.match(s) or re.match(r'^(?:namespace |end\b|section\b|noncomputable section\b|mutual\b|attribute\b|variable\b|open\b|@\[)', s): break
            j += 1
        block = ''.join(lines[i:j]).strip()
        h = normal(header(block))
        assert name not in result, name
        result[name] = {'kind':m['kind'], 'head':h, 'body':normal(block), 'line':i+1}
        if m['kind'] in {'structure','inductive'}:
            # 構成子と欄は、親の署名に隠さず個別に比較する。
            body = ''.join(lines[i+1:j])
            pat = r'^\s+\|\s+([\w]+)\b' if m['kind']=='inductive' else r'^' + ' ' * (len(line)-len(line.lstrip())+2) + r'([\w]+)\s*(?=[:({])'
            fields = list(re.finditer(pat,body,re.M))
            for k,f in enumerate(fields):
                end = fields[k+1].start() if k+1 < len(fields) else len(body)
                value = normal(body[f.start():end])
                value = re.split(r'\bderiving\b', value)[0].strip()
                result[name+'.'+f[1]] = {'kind':'constructor' if m['kind']=='inductive' else 'field', 'head':value, 'body':value, 'line':i+2+body[:f.start()].count('\n')}
    return result


def compare(base, head):
    rows=[]
    for p in sorted((base/'formal').rglob('*.lean')):
        path = p.relative_to(base)
        q=head/path
        if not q.exists() or p.read_bytes()==q.read_bytes(): continue
        old,new=declarations(p.read_text()),declarations(q.read_text())
        for name in sorted(set(old)|set(new)):
            a,b=old.get(name),new.get(name)
            if a and b and a['head'] != b['head']:
                rows.append({'file':str(path),'name':name,'kind':a['kind'],'old':a['head'],'new':b['head']})
            elif a and b and a['kind'] in {'def','abbrev'} and a['body'] != b['body']:
                rows.append({'file':str(path),'name':name,'kind':'definition','old':a['body'],'new':b['body']})
            elif b and not a and b['kind']=='field':
                rows.append({'file':str(path),'name':name,'kind':'field','old':None,'new':b['head']})
            elif a and not b:
                rows.append({'file':str(path),'name':name,'kind':a['kind'],'old':a['head'],'new':None})
    return rows



def extract_revision(revision, destination):
    data = subprocess.check_output(['git','archive',revision,'formal'],cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.isfile() and member.name.endswith('.lean'):
                target=destination/member.name
                assert target.resolve().is_relative_to(destination.resolve())
                target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(archive.extractfile(member).read())


def revision_rows():
    with tempfile.TemporaryDirectory(prefix='l70k-signatures-') as directory:
        base,head=Path(directory)/'base',Path(directory)/'head'
        extract_revision(BASE,base)
        extract_revision(HEAD,head)
        return compare(base,head)


PREFIX='Benitoite.Release.Refinement.'
CATEGORIES={
    'A':'範囲の列・構成子の欄',
    'B':'範囲の具体化・範囲の深さ',
    'C':'Ty.Declared',
    'D':'処理済みの効果',
    'E':'発行の規則',
    'F':'群Cの宣言前提・独立の移送の除去',
    'G':'束縛子名の表記',
}


def category(row):
    name=row['name'].removeprefix(PREFIX)
    a,b=row['old'] or '',row['new'] or ''
    if 'ofExtends' in name or name.startswith('Program.'):
        return 'F'
    if name in {'HasTypeCQ.match_legacy','S02Internal.case_C_Match','HasTypeCQ.C_Match'}:
        return 'C'
    if name in {'handled','legacy_handled_sub','LegacyCompCases.handle_case'}:
        return 'D'
    if ('NoHandler' in a and 'NoHandler' not in b) or ('pathBases' in a and 'pathBases' not in b):
        return 'E'
    if name in {'OperationStateExamples.primitive_pathBases','stepRun'}:
        return 'E'
    if name in {'Def.WellTyped.inputs','HasTypeVQ.canonical_function','Def.WellTyped','Def.Scoped',
                'StandardModel.BodyScoped','Val.ClosedAt','Val.ClosedNoLamNames','Val.SourceScoped',
                'PreparationNode.Child','Step.E_Fun','S02Internal.case_V_Fun','HasTypeVQ.V_Fun'}:
        return 'B'
    if name=='gate_fun_case':return 'G'
    return 'A'


def fragments(a,b):
    a,b=(a or '宣言なし').split(),(b or '宣言なし').split()
    matcher=difflib.SequenceMatcher(None,a,b,autojunk=False)
    old,new=[],[]
    for group in matcher.get_grouped_opcodes(2):
        x,y=group[0][1],group[-1][2]
        u,v=group[0][3],group[-1][4]
        old.append(('… ' if x else '')+' '.join(a[x:y])+(' …' if y<len(a) else ''))
        new.append(('… ' if u else '')+' '.join(b[u:v])+(' …' if v<len(b) else ''))
    return ' / '.join(old),' / '.join(new)


def conditions(row):
    group=category(row)
    name=row['name'].removeprefix(PREFIX)
    if group=='A':
        if name.endswith('.definition') or 'Definition' in name or name=='embedDef' or name=='Def.rkinds':
            return 'i（Def の欄）・ii（末尾欄）・iii（空範囲）','rkinds=[] は既定値と同じ。既存 Def に範囲の束縛を足さない。別名の系なし'
        return 'i（範囲の欄）・ii（欄の像）・iii（空列）','旧閉範囲列は fixed の像で読む。空列の像は []。別名の系なし'
    if group=='B':
        if name=='Def.WellTyped.inputs':return 'i（具体化前は偽）・ii（全具体化）・iii（空範囲）',PREFIX+'Def.WellTyped.inputs_no_ranges（d.rkinds=[]）'
        if name=='HasTypeVQ.canonical_function':return 'i（非空参照）・ii（存在量化）・iii（空参照）',PREFIX+'HasTypeVQ.canonical_function_no_ranges（全 fnRef の範囲引数が空）'
        if name=='Def.Scoped':return 'i（範囲深さ）・ii（範囲文脈）・iii（空範囲）',PREFIX+'Ty.annotationR_nil と rkinds=[] により SignatureScopedR は元の SignatureScoped、深さは0。別名の系なし'
        if name=='Def.WellTyped':return 'i（範囲深さ）・ii（範囲文脈）・iii（空範囲）',PREFIX+'Ty.annotationR_nil・'+PREFIX+'telBodyTyR_nil、rkinds=[] で旧形。Scoped は深さ0へ簡約'
        return 'i（範囲導入）・ii（具体化・深さ・欄）・iii（空列）','rs=[]・rkinds=[] で具体化は恒等。深さ0の旧形へ特殊化。別名の系なし'
    if group=='C':
        cor=PREFIX+('LegacyCompCases.match_type_subst' if name.startswith('S02') else 'LegacyCompCases.match_case')
        return 'i（C_Match）・ii（宣言前提）・iii（旧導出）',cor+'（旧値の正則性から Declared を供給）'
    if group=='D':
        if name=='handled':return 'i（発行）・ii（表の選択）／iiiは旧埋め込みで確認',PREFIX+'embedHasTypeCQ（旧導出）、'+PREFIX+'handledSelected_eq_d（P.EffectsOk B）'
        return 'i（handled）・ii（旧導出の入力）・iii（公開入口）',PREFIX+('LegacyRule.embed_comp' if name.endswith('handle_case') else 'embedHasTypeCQ')+'（署名不変。旧節の署名を入力から供給）'
    if group=='E':
        if row['new'] is None:return 'i（発行）／ii・iiiは発行の別承認',PREFIX+'Builtins.CoreAssumptions.pathBases_never_handled（hn 不要）'
        if 'NoHandler' in (row['old'] or '') and 'NoHandler' not in (row['new'] or ''):
            return 'i（発行）／既承認の不要前提の削除','同名の入口へ旧 NoHandler を渡さず適用できる。範囲の有無によらない'
        return 'i（発行）・ii（欄）／iiiは範囲部分のみ','rs=[] で像は旧形。pathBases の処理枝は S13 の別承認で除去し、元へ戻さない'
    if group=='F':
        if name=='Program.ExtendsTypingStatement':return 'C_Match による既承認の不要前提の削除',PREFIX+'Program.extends_typing_declared_context（旧文脈前提付き）'
        if row['new'] is None:
            replacements={'Program.ExhaustiveTransport':'Program.extends_exhaustive',
                'Program.compose_of_exhaustive':'Program.compose',
                'Program.extendsDeclaration_of_exhaustive':'Program.extends_declaration',
                'Program.extendsTyping_of_exhaustive':'Program.extends_typing'}
            return 'i（C_Match）／独立前提を除く既承認の切替',PREFIX+replacements[name]+'。公開入口の元からある WellFormed を使用。範囲の有無によらない'
        return 'i（C_Match）・ii（宣言前提）・iii（公開入口）','hex を hwf:P.WellFormed へ替える。公開三入口の既存 hwf から供給。単独の旧 hex だけの系は置かない'
    return '署名の意味は不変（三条件による変更なし）','_hc を hc とした束縛子名だけの差。同名の入口'


def escape(value):return value.replace('|','&#124;').replace('`','&#96;')


def render(rows):
    counts=collections.Counter(category(r) for r in rows)
    text='# 公開宣言の署名と定義の差\n\n'
    text+=f'基準 `{BASE}` と対象 `{HEAD}` を、`signatures.py` が読み取り専用の git archive から比較する。新規モジュール内の新規宣言と private 宣言を既存署名の差に混ぜない。既存の変更モジュールについて、公開宣言の頭部、構成子・欄、def/abbrev の本体を比較する。コメントと空白を除く。束縛子内の既定値の `:=` は署名に含める。\n\n'
    text+='表の元・新は差のあるトークン列と前後2トークンであり、`…` の位置は同一の部分である。完全な頭部と定義は固定コミットと台本から再生成できる。宣言名は名前空間 `Benitoite.Release.Refinement` からの相対名、パスは `formal/Benitoite/Release/Refinement/` からの相対名である。\n\n'
    text+='三条件は同時に満たす条件である。(i)承認済みの核の導入で旧言明が偽になる、(ii)全具体化の量化・範囲の深さ・増えた欄・宣言前提の追加、(iii)範囲なし・空引数・旧導出の系を保つ。発行の規則と群Cの不要な前提の削除は、それぞれの既承認の変更として分ける。範囲を空にするだけで発行の旧規則へ戻るとは扱わない。旧節の入力の追加は、取りまとめの2026-11-06の判断で(ii)に含める扱いを確認した。情報3の判断をこの作業で変更していない。\n\n'
    text+='| 種類 | 件数 |\n|---|---:|\n'
    text+=''.join(f'| {k} {CATEGORIES[k]} | {counts[k]} |\n' for k in CATEGORIES)
    text+=f'| 合計 | {len(rows)} |\n\n'
    for key,title in CATEGORIES.items():
        text+=f'## {key} {title}\n\n| 宣言（モジュール） | 元の署名・定義の差の部分 | 新しい署名・定義の差の部分 | 条件・理由 | 範囲なしの場合・系の完全名 |\n|---|---|---|---|---|\n'
        for row in rows:
            if category(row)!=key:continue
            a,b=fragments(row['old'],row['new'])
            cond,cor=conditions(row)
            name=row['name'].removeprefix(PREFIX)
            file=Path(row['file']).stem
            text+='| '+f'`{name}`（{file}）'+' | '+' | '.join(escape(s) for s in [a,b,cond,cor])+' |\n'
        text+='\n'
    text+='## レビューの比較との照合\n\nレビューの173行は、新規7モジュール、既存モジュールへの公開追加31件、private の追加・変更・削除27件、公開の変更・削除108件を含む。公開の変更・削除のうち、Step・FreshStepInputs・StoreReplyInputs・Def は本表で構成子・追加欄へ分けた。次の7件は、その宣言自体の頭部と定義が不変である。レビューの台本が次の字下げされた宣言やコメントまでを同じ宣言へ含めたため、差として数えた。\n\n'
    text+='| レビューで差と数えた宣言 | 実際に変わった箇所 |\n|---|---|\n'
    for a,b in [('lambdaShape','後続の closeVal の fnRef の欄'),('embedBuilderKind','後続の embedVal の prim の像'),('handles','後続のコメントの区切り'),('telBinders','後続の Val.rename の fnRef の欄'),('shiftKindE','後続の Val.shiftEAt の fnRef の欄'),('ResultShape','後続の Val.fnRef・Val.prim の構成子'),('HasTypeCL','後続のコメントの区切り')]:
        text+=f'| `{a}` | {b} |\n'
    return text


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-dir',type=Path)
    parser.add_argument('--head-dir',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--render',action='store_true')
    args=parser.parse_args()
    assert bool(args.base_dir)==bool(args.head_dir)
    rows=compare(args.base_dir,args.head_dir) if args.base_dir else revision_rows()
    data=(json.dumps(rows,ensure_ascii=False,indent=2)+'\n').encode()
    args.output.write_bytes(data)
    if args.render:
        content=render(rows)
        assert len(content.encode())<=100000
        (HERE/'resume4-signatures.md').write_text(content)
    print(json.dumps({'rows':len(rows),'kinds':dict(collections.Counter(r['kind'] for r in rows)), 'categories':dict(collections.Counter(category(r) for r in rows)), 'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()},ensure_ascii=False))


if __name__=='__main__': main()
