#!/usr/bin/env python3
"""L00.06c の件数の集計。

使い方: count06c.py <b0> <t15> <final> <ci> <l00.06c のディレクトリ> <出力の JSON>
  b0    基準の formal の写しの根（`git archive 91c9af89 formal` を展開した場所）
  t15   b0 に L00.01 の案 (ii) の trial-15.diff を当てた根
  final b0 にこの枝の最後の差分（trial-14.diff）を当てた根
  ci    b0 に L00.01 の案 (i) の trial-30-final.diff を当てた根
宣言の区切り・言明と本体の境目は L00.06 の tools/classify.py と同じ字句の近似である。
"""
import collections, json, os, re, sys

b0, t15, final, ci, ldir, out = sys.argv[1:7]

DECL_RE = re.compile(r'^(\s*)(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe|nonrec)\s+)*'
                     r'(theorem|lemma|def|abbrev|instance|inductive|structure|example|opaque|axiom|class)\b\s*([^\s:(\[{]*)')
STOP_RE = re.compile(r'^(end\b|namespace\b|section\b|mutual\b|/-!|open\b|#guard|#eval|#print|variable\b|set_option\b|attribute\b)')


def parse_decls(path):
    """L00.06 の classify.py の parse_decls と同じ。"""
    if not os.path.exists(path):
        return []
    lines = open(path, encoding='utf-8').read().splitlines()
    res, cur = [], None
    for i, s in enumerate(lines):
        m = DECL_RE.match(s)
        if m:
            if cur:
                res.append(cur)
            cur = {'kind': m.group(2), 'name': m.group(3) or '@anon', 'line': i + 1, 'stmt': [], 'body': [],
                   'in_stmt': True}
        elif cur and STOP_RE.match(s):
            res.append(cur)
            cur = None
            continue
        if not cur:
            continue
        if cur['in_stmt']:
            if cur['kind'] in ('inductive', 'structure', 'class'):
                cur['stmt'].append(s)
                continue
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
        res.append(cur)
    for d in res:
        d['stmt'] = ' '.join(' '.join(d['stmt']).split())
        d['body'] = ' '.join(' '.join(d['body']).split())
        del d['in_stmt']
    return res


def top_norm(s):
    """明示の Top の構築関数（案 (ii) の `(.top x)`、案 (i) の `nameTop`・`opaqueTop`）を旧の綴りへ戻す。"""
    s = re.sub(r'\((?:EffName|OpaqueName)?\.top ("[^"]*"|[A-Za-z_][\w.]*)\)', r'\1', s)
    s = re.sub(r'(?:EffName|OpaqueName)\.top ("[^"]*")', r'\1', s)
    s = re.sub(r'\.top ("[^"]*")', r'\1', s)
    s = re.sub(r'\b(nameTop|opaqueTop)\b', lambda m: 'name' if m.group(1) == 'nameTop' else 'opaque', s)
    return s


def lean_files(root):
    fs = []
    for d, _, names in os.walk(os.path.join(root, 'formal')):
        if '.lake' in d:
            continue
        for n in names:
            if n.endswith('.lean'):
                fs.append(os.path.relpath(os.path.join(d, n), os.path.join(root, 'formal')))
    return sorted(fs)


def compare(old_root, new_root):
    files = sorted(set(lean_files(old_root)) | set(lean_files(new_root)))
    changed, new_decls, files_changed = [], [], set()
    for f in files:
        po, pn = (os.path.join(r, 'formal', f) for r in (old_root, new_root))
        so = open(po, encoding='utf-8').read() if os.path.exists(po) else None
        sn = open(pn, encoding='utf-8').read() if os.path.exists(pn) else None
        if so == sn:
            continue
        files_changed.add(f)
        old, new = parse_decls(po), parse_decls(pn)

        def keyed(ds):
            seen, m = collections.Counter(), {}
            for d in ds:
                k = (d['kind'], d['name']); seen[k] += 1
                m[(k, seen[k])] = d
            return m
        olds, news = keyed(old), keyed(new)
        for key, o in olds.items():
            n = news.get(key)
            if n is None:
                changed.append(dict(file=f, kind=o['kind'], name=o['name'], removed=True)); continue
            st, bd = o['stmt'] != n['stmt'], o['body'] != n['body']
            if st or bd:
                changed.append(dict(file=f, kind=o['kind'], name=o['name'], removed=False, stmt=st, body=bd,
                                    stmt_top_only=st and top_norm(n['stmt']) == top_norm(o['stmt']),
                                    body_top_only=bd and top_norm(n['body']) == top_norm(o['body'])))
        for key, n in news.items():
            if key not in olds:
                new_decls.append(dict(file=f, kind=n['kind'], name=n['name']))
    return changed, new_decls, sorted(files_changed)


def summarize(changed, new_decls, files):
    def part(sel):
        ch = [c for c in changed if sel(c['file'])]
        nd = [c for c in new_decls if sel(c['file'])]
        thm = lambda c: c['kind'] in ('theorem', 'lemma')
        stmt = [c for c in ch if not c['removed'] and c['stmt']]
        return dict(
            files=len({c['file'] for c in ch} | {c['file'] for c in nd}),
            changed_existing=len(ch),
            removed=sum(c['removed'] for c in ch),
            statement_changed=len(stmt),
            statement_changed_theorems=sum(thm(c) for c in stmt),
            statement_top_builder_only=sum(c['stmt_top_only'] for c in stmt),
            statement_top_builder_only_theorems=sum(thm(c) and c['stmt_top_only'] for c in stmt),
            body_only=sum(1 for c in ch if not c['removed'] and not c['stmt']),
            body_only_top_builder_only=sum(1 for c in ch if not c['removed'] and not c['stmt'] and c['body_top_only']),
            new_declarations=len(nd),
        )
    model = lambda f: f.startswith('Benitoite/Scope/')
    return dict(all=part(lambda f: True), production=part(lambda f: not model(f) and f != 'Benitoite.lean'),
                comparison_models=part(model))


res = {}
for label, (o, n) in {'final_vs_b0': (b0, final), 't15_vs_b0': (b0, t15), 'final_vs_t15': (t15, final),
                      'ci_vs_b0': (b0, ci)}.items():
    ch, nd, fs = compare(o, n)
    res[label] = dict(summary=summarize(ch, nd, fs), changed=ch, new=nd)

# 各試行の比較用ビルドで壊れた宣言の和
union, diag_total, files_union, per_build = {}, 0, set(), []
for n in sorted(os.listdir(ldir)):
    m = re.match(r'count-(\d+)\.json$', n)
    if not m:
        continue
    d = json.load(open(os.path.join(ldir, n), encoding='utf-8'))
    diag_total += d['error_diagnostics']
    per_build.append(dict(build=m.group(1), failed=len(d['failed_modules']), unchecked=d['unchecked_modules_count'],
                          diagnostics=d['error_diagnostics'], files=len(d['error_files']),
                          decls=len(d['error_declarations']), sorry=d['sorry_warnings']))
    for e in d['error_declarations']:
        union.setdefault((e['file'], e['decl']), 0)
        union[(e['file'], e['decl'])] += e['errors']
        files_union.add(e['file'])
model = lambda f: f.startswith('Benitoite/Scope/')
res['breakage'] = dict(
    per_build=per_build,
    unique_decls=len(union), unique_files=len(files_union), diagnostics_sum=diag_total,
    production=dict(decls=sum(1 for (f, _) in union if not model(f)),
                    files=len({f for f in files_union if not model(f)}),
                    diagnostics=sum(c for (f, _), c in union.items() if not model(f))),
    comparison_models=dict(decls=sum(1 for (f, _) in union if model(f)),
                           files=len({f for f in files_union if model(f)}),
                           diagnostics=sum(c for (f, _), c in union.items() if model(f))),
    decls=[dict(file=f, decl=k, errors=c) for (f, k), c in sorted(union.items())],
)

# 暗黙の変換に頼っていた綴りの数（L00.01 の案 (ii) の数え方に合わせ、基準の Scope の模型を除く）
PATS = {
    'name_lit': r'\.name "',
    'single_lit': r'Eff\.single "',
    'opaque_lit': r'\.opaque "',
    'single_var': r'Eff\.single [A-Za-z_]',
    'stateEff': r'\bstateEff\b',
}
TOP_PATS = {
    'name_lit': r'\.name \(\.top "',
    'single_lit': r'Eff\.single \(\.top "',
    'opaque_lit': r'\.opaque \(\.top "',
    'single_var': r'Eff\.single \(\.top [A-Za-z_]',
    'stateEff': r'\(\.top stateEff\)',
}


def count_lines(root, pats, exclude_models=True):
    c = collections.Counter(); fc = collections.defaultdict(set)
    for f in lean_files(root):
        if exclude_models and f.startswith('Benitoite/Scope/'):
            continue
        for line in open(os.path.join(root, 'formal', f), encoding='utf-8'):
            for k, p in pats.items():
                if re.search(p, line):
                    c[k] += 1; fc[k].add(f)
    return {k: dict(lines=c[k], files=len(fc[k])) for k in pats}


res['coercion_sites'] = dict(
    b0_old_spelling=count_lines(b0, PATS),
    final_old_spelling_remaining=count_lines(final, PATS),
    final_explicit_top=count_lines(final, TOP_PATS),
    final_explicit_top_all_files=count_lines(final, TOP_PATS, exclude_models=False),
)

# 最後の差分（L00.01 の trial-15 からの差）で加えた明示の Top の構築の数
adds = collections.Counter(); add_files = collections.defaultdict(set)
cur = None
for line in open(os.path.join(ldir, 'delta-from-trial15.diff'), encoding='utf-8'):
    if line.startswith('+++ b/'):
        cur = line[6:].strip()
    elif line.startswith('+') and not line.startswith('+++'):
        n = len(re.findall(r'\(\.top [^)]*\)|\.top "', line))
        if n:
            adds['occurrences'] += n; adds['lines'] += 1; add_files['all'].add(cur)
            key = 'models' if '/Scope/' in cur else 'production'
            adds[key + '_occurrences'] += n; adds[key + '_lines'] += 1; add_files[key].add(cur)
res['explicit_top_added_vs_t15'] = dict(adds, files=len(add_files['all']),
                                        production_files=len(add_files['production']),
                                        model_files=len(add_files['models']))
json.dump(res, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for k in ('final_vs_b0', 't15_vs_b0', 'final_vs_t15', 'ci_vs_b0'):
    print(k, json.dumps(res[k]['summary'], ensure_ascii=False))
print('breakage', {k: v for k, v in res['breakage'].items() if k not in ('decls', 'per_build')})
print('coercion', json.dumps(res['coercion_sites'], ensure_ascii=False))
print('adds', res['explicit_top_added_vs_t15'])
