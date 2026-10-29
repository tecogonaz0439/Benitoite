#!/usr/bin/env python3
"""L00.06 の母集団の分類。

入力:
  --deps   deps.lean が書き出した JSON 行（B0 と同じ formal の既定の環境の直接の依存）
  --b0     B0 の formal の写しの根（`git archive <B0> formal` を展開した場所）
  --ci     B0 の写しに L00.01 の案 (i) の trial-30-final.diff を当てた根
  --cii    B0 の写しに L00.01 の案 (ii) の trial-15.diff を当てた根
  --change 改造のディレクトリ（evidence/S8 と l00.01 を読む）
  --out    出力の JSON
出力: 宣言ごとの行（母集団の出どころ、試行の差分の区分、依存から得た前提の変更の印、二案それぞれの分類と根拠）と集計。

分類は次の三つと未分類である。
  statement  言明の変更（字面の変更、または字面は同じで前提・結論の内容が変わる）
  proof      証明だけの変更（定義では本体だけの変更）
  check      点検のみ（試行の全体のビルドで変えずに通り、前提の変更の直接の利用もない）
  unclassified 試行と依存の情報では三つのどれかに決まらない（理由を付ける）
字句の比較と Lean の直接の依存だけを使い、推移的な証明の依存で「変更」を増やさない（点検のみに数える）。
"""
import argparse, collections, json, os, re

ap = argparse.ArgumentParser()
for a in ('deps', 'b0', 'ci', 'cii', 'change', 'out'):
    ap.add_argument('--' + a, required=True)
A = ap.parse_args()

DECL_RE = re.compile(r'^(\s*)(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe|nonrec)\s+)*'
                     r'(theorem|lemma|def|abbrev|instance|inductive|structure|example|opaque|axiom|class)\b\s*([^\s:(\[{]*)')
STOP_RE = re.compile(r'^(end\b|namespace\b|section\b|mutual\b|/-!|open\b|#guard|#eval|#print|variable\b|set_option\b|attribute\b)')


def parse_decls(path):
    """ファイルを宣言へ区切り、各宣言の言明（最初の `:=`・`where`・腕まで）と本体の文字列を返す。"""
    if not os.path.exists(path):
        return []
    lines = open(path, encoding='utf-8').read().splitlines()
    out = []
    cur = None
    for i, s in enumerate(lines):
        m = DECL_RE.match(s)
        if m:
            if cur:
                out.append(cur)
            kind, name = m.group(2), m.group(3) or '@anon'
            cur = {'kind': kind, 'name': name, 'line': i + 1, 'stmt': [], 'body': [], 'in_stmt': True}
        elif cur and STOP_RE.match(s):
            out.append(cur)
            cur = None
            continue
        if not cur:
            continue
        if cur['in_stmt']:
            if cur['kind'] in ('inductive', 'structure', 'class'):
                cur['stmt'].append(s)
                continue
            # 腕で始まる行は、等式で定義する本体の始まり。言明の中の match の腕（言明に match がある）は除く
            if not m and re.match(r'^\s*\|', s) and not re.search(r'\bmatch\b', ' '.join(cur['stmt'])):
                cur['in_stmt'] = False
                cur['body'].append(s)
                continue
            mm = re.search(r':=|\bwhere\b', s)
            if mm:
                cur['stmt'].append(s[:mm.start()])
                cur['body'].append(s[mm.start():])
                cur['in_stmt'] = False
            else:
                cur['stmt'].append(s)
        else:
            cur['body'].append(s)
    if cur:
        out.append(cur)
    for d in out:
        d['stmt'] = ' '.join(' '.join(d['stmt']).split())
        d['body'] = ' '.join(' '.join(d['body']).split())
        del d['in_stmt']
    return out


def builder_norm(s):
    return re.sub(r'\b(nameTop|opaqueTop)\b', lambda m: 'name' if m.group(1) == 'nameTop' else 'opaque', s)


def diff_trial(root_old, root_new, files):
    """試行で変えたファイルの宣言を旧と新で対にし、言明・本体の変更を判定する。"""
    res = {}
    new_decls = []
    for f in files:
        old = parse_decls(os.path.join(root_old, f))
        new = parse_decls(os.path.join(root_new, f))
        seen = collections.Counter()
        olds = {}
        for d in old:
            k = (d['kind'], d['name']); seen[k] += 1
            olds[(k, seen[k])] = d
        seen = collections.Counter()
        news = {}
        for d in new:
            k = (d['kind'], d['name']); seen[k] += 1
            news[(k, seen[k])] = d
        for key, o in olds.items():
            n = news.get(key)
            if n is None:
                res[(f, o['line'])] = {'kind': o['kind'], 'name': o['name'], 'removed': True,
                                       'stmt': True, 'body': True, 'builder_only_stmt': False}
                continue
            st = o['stmt'] != n['stmt']
            bd = o['body'] != n['body']
            if st or bd:
                res[(f, o['line'])] = {
                    'kind': o['kind'], 'name': o['name'], 'removed': False, 'stmt': st, 'body': bd,
                    'builder_only_stmt': st and builder_norm(n['stmt']) == o['stmt'],
                    'builder_only_body': bd and builder_norm(n['body']) == o['body'],
                }
        for key, n in news.items():
            if key not in olds:
                new_decls.append({'file': f, 'kind': n['kind'], 'name': n['name'], 'line': n['line']})
    return res, new_decls


def changed_files(diff_path):
    fs = []
    for line in open(diff_path, encoding='utf-8'):
        m = re.match(r'^diff --git a/(\S+) b/', line)
        if m:
            fs.append(m.group(1))
    return fs


# ---------------------------------------------------------------- 依存
deps = {}
for line in open(A.deps, encoding='utf-8'):
    d = json.loads(line)
    deps[d['name']] = d


def mod_path(m):
    return 'formal/' + m.replace('.', '/') + '.lean'


# 行を持つ宣言を持ち主とし、行のない補助の定数（match_・proof_・casesOn など）を最も近い持ち主へ寄せる
ranged = {n for n, d in deps.items() if d['line'] is not None}
# 自動で生成した定数（recOn・casesOn・構成子の injEq など）は、名前の前置きの宣言と同じ行を持つ。持ち主へ寄せる
_pos = collections.defaultdict(set)
for n in ranged:
    _pos[(deps[n]['module'], deps[n]['line'])].add(n)
for n in list(ranged):
    same = _pos[(deps[n]['module'], deps[n]['line'])]
    if deps[n]['kind'] in ('rec',) or any(m != n and n.startswith(m + '.') for m in same):
        ranged.discard(n)


def owner(n):
    if n.startswith('Benitoite.Release.Builtins.Assumptions.') and n in deps and deps[n]['kind'] in ('def', 'theorem'):
        return 'Benitoite.Release.Builtins.Assumptions'
    if n in ranged:
        return n
    p = n
    while '.' in p:
        p = p.rsplit('.', 1)[0]
        if p in ranged:
            return p
    return n


owned = collections.defaultdict(set)
for n in deps:
    owned[owner(n)].add(n)

by_pos = {}
for n in ranged:
    d = deps[n]
    by_pos.setdefault((mod_path(d['module']), d['line']), []).append(n)


def folded(n):
    """宣言の言明（型）と本体の直接の参照を、持ち主の単位で返す。帰納型は構成子の型を言明に含める。"""
    d = deps[n]
    ty, val = set(d['type']), set(d['value'])
    for c in d.get('ctors', []):
        if c in deps:
            ty |= set(deps[c]['type'])
    for a in owned[n]:
        if a == n or a in d.get('ctors', []):
            continue
        val |= set(deps[a]['type']) | set(deps[a]['value'])
    return {owner(c) for c in ty} - {n}, {owner(c) for c in val} - {n}, ty, val


def resolve(path, line, short):
    cands = by_pos.get((path, line), [])
    if len(cands) == 1:
        return cands[0]
    for c in cands:
        if c == short or c.endswith('.' + short):
            return c
    return cands[0] if cands else None


# 定義を通した到達（言明の意味が、変わる定義へ定義の展開でつながるか）
def rev_def_closure(targets):
    """targets を（定義・帰納型の本体・構成子の型を通して）参照する定義の集合。定理は辿らない。"""
    users = collections.defaultdict(set)
    for n in ranged:
        k = deps[n]['kind']
        if k in ('def', 'inductive', 'opaque'):
            ty, val, _, _ = folded(n)
            for c in ty | val:
                users[c].add(n)
    seen = set(targets)
    stack = list(targets)
    while stack:
        c = stack.pop()
        for u in users.get(c, ()):
            if u not in seen:
                seen.add(u); stack.append(u)
    return seen


R = 'Benitoite.Release.'
ASM = R + 'Builtins.Assumptions'
FIELD = lambda f: ASM + '.' + f
BUILTIN_ONLY_CLOSURE = rev_def_closure({R + 'BuiltinOnly'})

CHANGED_FIELDS = {'io_op', 'delta_typed', 'io_typed', 'io_exists', 'io_kind'}
ALL_FIELDS = {n for n in deps if n.startswith(ASM + '.') and deps[n]['kind'] in ('def', 'theorem') and n != ASM + '.mk'}


def field_reach():
    """各宣言の本体が、宣言の本体を推移的に辿って使う Builtins.Assumptions の欄。"""
    val_edges = {}
    for n in ranged:
        _, val, _, rawval = folded(n)
        val_edges[n] = val
    direct = {n: {c for c in deps[n]['value'] for _ in [0] if c in ALL_FIELDS} for n in ranged}
    for n in ranged:
        for a in owned[n]:
            direct[n] |= {c for c in deps[a]['value'] if c in ALL_FIELDS}
    reach = {n: set(v) for n, v in direct.items()}
    changed = True
    while changed:
        changed = False
        for n, es in val_edges.items():
            cur = reach[n]
            before = len(cur)
            for c in es:
                if c in reach:
                    cur |= reach[c]
            if len(cur) != before:
                changed = True
    return reach


FIELD_REACH = field_reach()

PREMISE = {
    # 判断 15 で計画済みの io_op の内容の変更（両案）。欄を使う証明が変わる
    'io_op_use': {FIELD('io_op')},
    # L00.01・L00.03 の既存の欄の量化（両案。L00.03 の判定の案 A・B は未決）
    'quant_use': {FIELD('delta_typed'), FIELD('io_typed'), FIELD('io_exists')},
    # L00.04 の観測の欄（案 O1 を推す。未決）。事象の構成子と応答の関係の引数が増える
    'obs_use': {R + 'Event.io', R + 'Builtins.ioResponse', FIELD('io_kind'), R + 'Step.E_IO'},
    # 捕捉した操作の節の添字 S（判断 11。L00.01 案 (ii) の sorry、案 (i) は未確認）
    'clause_use': {R + 'Step.E_OpPrim', R + 'opSig'},
    # L00.05 の申し送り 2（RangeState へ Scope の成分を足す場合だけ）
    'range_state_use': {'Benitoite.Interval.RangeState'},
}
PREMISE_STMT = {
    'assumptions_stmt': {ASM},
    'obs_stmt': {R + 'Event.io', R + 'Builtins.ioResponse'},
    'clause_stmt': {R + 'opSig'},
    'range_state_stmt': {'Benitoite.Interval.RangeState'},
}

# ---------------------------------------------------------------- 母集団の出どころ
inv = json.load(open(os.path.join(A.change, 'evidence/S8/lean-inventory.json'), encoding='utf-8'))
L1 = os.path.join(A.change, 'l00.01')

PRIORITY18 = {
    'Release/Effect.lean': ['Eff.eq_of_sub_of_sub'],
    'Release/TypeComposition.lean': ['Eff.norm_ext', 'Eff.bind_comp_of_types', 'Eff.ext_canonical'],
    'Surface/Lemmas/Sequence.lean': ['union_empty_right_nested', 'union_empty_left_nested'],
    'Release/Lemmas/EffectSound.lean': ['no_event'],
    'Release/Lemmas/PresMain.lean': ['preservationE'],
    'Release/Lemmas/Progress.lean': ['progress_io'],
    'Release/Lemmas/StepSound.lean': ['step_soundE'],
    'Release/Lemmas/TySubstMain.lean': ['opSig_scoped'],
    'Release/Model.lean': ['assumptions'],
    'Release/Theorems.lean': ['progress', 'preservation', 'effect_soundness', 'effect_soundness_noLamNames',
                              'step_sound'],
    'Surface/Theorems.lean': ['desugar_typed'],
}

rows = {}


def row_for(name):
    if name not in rows:
        d = deps[name]
        rows[name] = {'name': name, 'kind': d['kind'], 'file': mod_path(d['module']), 'line': d['line'],
                      'sources': set()}
    return rows[name]


unmatched = []
for e in inv['entries']:
    n = resolve(e['path'], e['line'], e['name'])
    if n is None:
        unmatched.append(e); continue
    r = row_for(n)
    r['sources'].add('inventory')
    r['inventory_categories'] = e['categories']

for f, names in PRIORITY18.items():
    for s in names:
        cands = [n for n in ranged if mod_path(deps[n]['module']) == 'formal/Benitoite/' + f and
                 (n.endswith('.' + s))]
        cands = [c for c in cands if deps[c]['kind'] == 'theorem'] or cands
        if len(cands) != 1:
            unmatched.append({'priority18': f + ':' + s, 'candidates': cands}); continue
        row_for(cands[0])['sources'].add('priority18')

# 試行の差分の区分
trials = {}
for cand, root, diff in (('i', A.ci, os.path.join(L1, 'candidate-i/trial-30-final.diff')),
                         ('ii', A.cii, os.path.join(L1, 'candidate-ii/trial-15.diff'))):
    fs = changed_files(diff)
    res, new = diff_trial(A.b0, root, fs)
    trials[cand] = {'changed': {}, 'new': new, 'files': fs}
    for (f, line), info in res.items():
        n = resolve(f, line, info['name'])
        if n is None:
            unmatched.append({'trial': cand, 'file': f, 'line': line, 'name': info['name']}); continue
        trials[cand]['changed'][n] = info
        row_for(n)['sources'].add(f'l00.01-{cand}-changed')

# L00.01 のビルドで壊れた宣言（中間の試行の分。案 (i) は broken-union、案 (ii) は count-*.json）
broken = {'i': set(), 'ii': set()}
bu = json.load(open(os.path.join(L1, 'candidate-i/broken-union.json'), encoding='utf-8'))
for s in bu['series'].values():
    for x in s['declarations']:
        broken['i'].add(x)
for fn in sorted(os.listdir(os.path.join(L1, 'candidate-ii'))):
    if fn.startswith('count-') and fn.endswith('.json'):
        c = json.load(open(os.path.join(L1, 'candidate-ii', fn), encoding='utf-8'))
        for x in c.get('error_declarations', []):
            broken['ii'].add(x if isinstance(x, str) else f"{x['file']}: {x['decl']}")
        for x in c.get('sorry_warnings', []):
            broken['ii'].add(f'{x[0]}: {x[1]}')
decl_short = re.compile(r'^(?:formal/)?(\S+): (\S+) (\S+)$')
for cand in ('i', 'ii'):
    for x in sorted(broken[cand]):
        m = decl_short.match(x)
        if not m:
            unmatched.append({'broken': cand, 'raw': x}); continue
        f, kind, short = 'formal/' + m.group(1), m.group(2), m.group(3)
        cands = [n for n in ranged if mod_path(deps[n]['module']) == f and (n == short or n.endswith('.' + short))]
        if not cands:
            unmatched.append({'broken': cand, 'raw': x}); continue
        for n in cands[:1]:
            row_for(n)['sources'].add(f'l00.01-{cand}-broken')

# 前提の変更を直接使う宣言（依存から）
for n in ranged:
    if not (n.startswith('Benitoite.') and deps[n]['kind'] in ('theorem', 'def', 'inductive', 'opaque')):
        continue
    if owner(n) != n:
        continue
    if n.startswith('Benitoite.Scope.') or n.startswith('Benitoite.Core.'):
        continue
    ty, val, _, _ = folded(n)
    hit = [k for k, s in PREMISE.items() if (ty | val) & s] + [k for k, s in PREMISE_STMT.items() if ty & s]
    if ty & BUILTIN_ONLY_CLOSURE or val & {R + 'BuiltinOnly'}:
        hit.append('builtin_only')
    if hit:
        row_for(n)['sources'].add('premise')

INDUCT_RE = {
    'NT': re.compile(r'^Benitoite\.Release\.(HasTypeVQ|HasTypeVsQ|HasTypeEachQ|HasTypeCQ|HasTypeArmsQ|HasTypeClausesQ|'
                     r'HasFailureClause)\.(rec|rec_\d+|casesOn|recOn|brecOn|below|binductionOn)$'),
    'NV': re.compile(r'^Benitoite\.Release\.(Val|Const)\.(rec|rec_\d+|casesOn|recOn|brecOn|below)$'),
    'NS': re.compile(r'^Benitoite\.Surface\.(HasTypeQ|HasTypesQ|HasEachQ|HasHoleArgsQ|HasArmsQ|HasClausesQ|HasBlockQ)\.'
                     r'(rec|rec_\d+|casesOn|recOn|brecOn|below|binductionOn)$'),
}
_rv_cache = {}


def rawval_all(n):
    """宣言と補助の定数（match_・proof_ など）の本体が直接使う定数（持ち主へ寄せない）。"""
    if n not in _rv_cache:
        acc = set(deps[n]['value'])
        for a in owned[n]:
            if a != n and a not in deps[n].get('ctors', []):
                acc |= set(deps[a]['value'])
                # match_ の補助は casesOn を本体で使う
        _rv_cache[n] = acc
    return _rv_cache[n]


# ---------------------------------------------------------------- 分類
def classify(n, cand):
    r = rows[n]
    ty, val, _, _ = folded(n)
    kind = r['kind']
    reasons, cond, uncl = [], [], []
    t = trials[cand]['changed'].get(n)
    cls = 'check'
    if t:
        if t.get('removed'):
            cls = 'statement'; reasons.append('trial: 宣言を削除・改名した')
        elif t['stmt'] and not t['builder_only_stmt']:
            cls = 'statement'; reasons.append('trial: 言明の字面を変えた')
        elif t['stmt']:
            cls = 'statement_text'; reasons.append('trial: 言明の字面を Top の構築関数へ置き換えた（abbrev なので項は同じ）')
        if cls == 'check' and t['body']:
            cls = 'proof'
            reasons.append('trial: 本体だけを変えた' + ('（Top の構築関数への置き換えだけ）' if t.get('builder_only_body') else ''))
        elif cls == 'statement' and t['body']:
            reasons.append('trial: 本体も変えた')
    # 前提の変更（二案共通。io_op は計画済み、量化は L00.03 の案 A/B が未決）
    if ty & {ASM}:
        if cls in ('check', 'proof', 'statement_text'):
            cls = 'statement_premise'
        used = sorted(f.rsplit('.', 1)[1] for f in FIELD_REACH.get(n, ()))
        reasons.append('premise: 言明が Builtins.Assumptions を前提に持つ（io_op の内容と既存欄の量化が変わる。字面は不変）')
        if not (set(used) & CHANGED_FIELDS):
            cond.append('SPLIT: 証明が推移的にも io_op・delta_typed・io_typed・io_exists・io_kind を使わない'
                        '（CoreAssumptions と TargetAgreement を分ければ、前提を旧の内容の構造体に保てる）')
    if val & PREMISE['io_op_use']:
        cls = 'proof' if cls == 'check' else cls
        reasons.append('premise: 本体が io_op を使う（判断 15 の io_op の変更）')
    if val & PREMISE['quant_use']:
        cls = 'proof' if cls == 'check' else cls
        reasons.append('premise: 本体が delta_typed・io_typed・io_exists を使う（範囲への量化。L00.03 の案 A/B は未決）')
    if ty & PREMISE_STMT['obs_stmt']:
        cond.append('O1: 言明が Event.io・Builtins.ioResponse を直接書く（観測の欄で字面が変わる）')
    elif val & PREMISE['obs_use']:
        cond.append('O1: 本体が Event.io・ioResponse・io_kind・E_IO を使う（観測の欄で証明が変わる）')
    if ty & BUILTIN_ONLY_CLOSURE:
        cond.append('BA: 言明が StateTy などを通して BuiltinOnly に依存する（BA なら前提・結論の内容が変わる。BB は Top の像の上で同じ）')
    if val & {R + 'BuiltinOnly'}:
        cond.append('BA: 本体が BuiltinOnly を直接使う（BA なら証明が変わる）')
    if (ty | val) & PREMISE['range_state_use']:
        cond.append('RS: RangeState を使う（L40 で RangeState に Scope の成分を足す場合だけ変わる）')
    if val & {ASM + '.mk'} or ASM + '.mk' in rawval_all(n):
        reasons.append('premise: 本体が Builtins.Assumptions を構成する（変わる欄を証明し直す）')
        cls = 'proof' if cls == 'check' else cls
    rv = rawval_all(n)
    if any(INDUCT_RE['NT'].match(c) for c in rv):
        cond.append('NT: 本体が Release の値の型付け（HasTypeVQ などの相互帰納）を場合分けする'
                    '（範囲付きの値の所属を持つ型付けの規則を構成子として足す場合、場合が一つ増える）')
    if any(INDUCT_RE['NV'].match(c) for c in rv):
        cond.append('NV: 本体が Release の値・定数（Val・Const）を場合分けする（対象を持つ値の形を構成子として足す場合、場合が一つ増える）')
    if any(INDUCT_RE['NS'].match(c) for c in rv):
        cond.append('NS: 本体が Surface の型付け（HasTypeQ などの相互帰納）を場合分けする（L40 で範囲付きの値の規則を足す場合）')
    if val & {R + 'Step.E_OpPrim'} or ty & {R + 'opSig'}:
        uncl.append('clause: 本体が E_OpPrim の場合を扱うか、言明が opSig を書く（捕捉した操作の節の添字 S。案 (ii) は sorry で止め、案 (i) は非 Top の型付けを試していない）')
    elif val & {R + 'opSig'}:
        cond.append('CS: 本体が opSig を使う（節の添字 S を opSig・HasTypeClausesQ に入れる場合、相互帰納の証明が変わりうる）')
    if cand == 'ii' and n.endswith('.Order.Atom.code_injective') or (cand == 'ii' and n == R + 'Atom.code_injective'):
        uncl.append('sorry: 案 (ii) の試行で sorry を仮置きした（証明だけの見込み）')
    if cand == 'ii' and n == R + 'preservationE':
        uncl.append('sorry: 案 (ii) の試行で E_OpPrim の場合に sorry を仮置きした')
    if cand == 'ii' and cls == 'check':
        ti = trials['i']['changed'].get(n)
        if ti and (ti.get('builder_only_stmt') or ti.get('builder_only_body')):
            cond.append('EX: 案 (ii) の試行は String からの暗黙の変換で通った。変換を置かない場合、案 (i) と同じく'
                        'Top の構築関数への字面の変更になる（下限）')
    if not reasons and cls == 'check':
        reasons.append('trial: 全体のビルドで変えずに通った。前提の変更の直接の利用なし')
    final = 'unclassified' if uncl else cls
    keys = sorted({c.split(':', 1)[0] for c in cond})
    return {'class': final, 'definite_class': cls, 'reasons': reasons, 'conditional': cond,
            'condition_keys': keys, 'unclassified': uncl,
            'assumption_fields_reached': sorted(f.rsplit('.', 1)[1] for f in FIELD_REACH.get(n, ()))}


out_rows = []
for n, r in sorted(rows.items(), key=lambda x: (x[1]['file'], x[1]['line'] or 0)):
    r = dict(r)
    r['sources'] = sorted(r['sources'])
    r['i'] = classify(n, 'i')
    r['ii'] = classify(n, 'ii')
    r['priority18'] = 'priority18' in r['sources']
    r['differs'] = r['i']['class'] != r['ii']['class']
    out_rows.append(r)


def summarize(sel):
    s = {}
    for cand in ('i', 'ii'):
        c = collections.Counter(x[cand]['class'] for x in sel)
        s[cand] = dict(sorted(c.items()))
        s[cand + '_with_conditions'] = sum(1 for x in sel if x[cand]['conditional'])
        s[cand + '_conditions'] = dict(sorted(collections.Counter(
            k for x in sel for k in x[cand]['condition_keys']).items()))
        # 条件付きで点検のみから上がりうるもの
        s[cand + '_check_but_conditional'] = dict(sorted(collections.Counter(
            k for x in sel if x[cand]['class'] == 'check' for k in x[cand]['condition_keys']).items()))
    s['differs'] = sum(1 for x in sel if x['differs'])
    s['total'] = len(sel)
    return s


STAGE = [
    ('L10', re.compile(r'^formal/Benitoite/Release/(Atom|Types|Effect|Normalize|Finite|TypeComposition|TypeSubst\w*|TypeShift|'
                       r'TypeScopedSubst|SubstEnv|TypeBounds|TypeRows|TypeVariables|CoverageTypes|NoFail|Subst)\.lean$|'
                       r'^formal/Benitoite/Release/Order/')),
    ('L20', re.compile(r'^formal/Benitoite/Release/(Typing|Syntax|Assumptions|Semantics|BuiltinTable|WellFormed|Examples)\.lean$')),
    ('L30', re.compile(r'^formal/Benitoite/Release/')),
    ('L40', re.compile(r'^formal/Benitoite/(Surface|Interval|Checked)/')),
    ('L50', re.compile(r'^formal/')),
]


def stage_of(f):
    for st, rx in STAGE:
        if rx.search(f):
            return st
    return '?'


by_file = collections.defaultdict(lambda: {'stage': None, 'i': collections.Counter(), 'ii': collections.Counter()})
for x in out_rows:
    b = by_file[x['file']]
    b['stage'] = stage_of(x['file'])
    for cand in ('i', 'ii'):
        b[cand][x[cand]['class']] += 1
by_stage = {}
for f, b in by_file.items():
    st = by_stage.setdefault(b['stage'], {'files': 0, 'i': collections.Counter(), 'ii': collections.Counter()})
    st['files'] += 1
    for cand in ('i', 'ii'):
        st[cand].update(b[cand])
for st in by_stage.values():
    for cand in ('i', 'ii'):
        st[cand] = dict(sorted(st[cand].items()))

summary = {
    'population_total': summarize(out_rows),
    'theorems': summarize([x for x in out_rows if x['kind'] == 'theorem']),
    'non_theorems': summarize([x for x in out_rows if x['kind'] != 'theorem']),
    'inventory_306': summarize([x for x in out_rows if 'inventory' in x['sources'] and x['kind'] == 'theorem']),
    'inventory_387': summarize([x for x in out_rows if 'inventory' in x['sources']]),
    'priority18': summarize([x for x in out_rows if x['priority18']]),
    'outside_inventory': summarize([x for x in out_rows if 'inventory' not in x['sources']]),
    'sources': dict(collections.Counter(s for x in out_rows for s in x['sources'])),
    'new_declarations_in_trials': {c: len(trials[c]['new']) for c in trials},
    'unmatched': len(unmatched),
    'by_stage': dict(sorted(by_stage.items())),
}
doc = {'summary': summary, 'rows': out_rows,
           'by_file': {f: {'stage': b['stage'], 'i': dict(b['i']), 'ii': dict(b['ii'])} for f, b in sorted(by_file.items())}, 'new_declarations': {c: trials[c]['new'] for c in trials},
           'unmatched': unmatched,
           'inputs': {'deps_constants': len(deps), 'trial_files': {c: trials[c]['files'] for c in trials}}}
# 宣言の行は一行に一つ置き、差分を読めるようにする
with open(A.out, 'w', encoding='utf-8') as fh:
    fh.write('{\n')
    keys = list(doc)
    for i, k in enumerate(keys):
        sep = ',' if i + 1 < len(keys) else ''
        if k == 'rows':
            fh.write(' "rows": [\n')
            for j, r in enumerate(doc['rows']):
                fh.write('  ' + json.dumps(r, ensure_ascii=False, separators=(',', ':')) +
                         (',' if j + 1 < len(doc['rows']) else '') + '\n')
            fh.write(' ]' + sep + '\n')
        else:
            fh.write(' ' + json.dumps(k) + ': ' + json.dumps(doc[k], ensure_ascii=False, separators=(',', ':')) + sep + '\n')
    fh.write('}\n')
print(json.dumps(summary, ensure_ascii=False, indent=1))
