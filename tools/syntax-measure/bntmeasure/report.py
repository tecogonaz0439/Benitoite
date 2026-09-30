# -*- coding: utf-8 -*-
"""結果（JSON Lines）の集計。Markdown の表を作る。

率は次のとおりに定める。
- n: 1 回目に main.bnt を書いた試行の数（時間切れ・エージェントの失敗・main.bnt を書かなかった試行を除く）
- 1 回目の構文の誤りの率: n のうち、1 回目の検査で誤りが見つかった試行の割合
- 1 回で直せた率: 1 回目に誤りがあった試行のうち、診断を渡した修正の後の検査を通った割合
区間は Wilson の 95% の信頼区間である。基準（V00）との差は、同じエージェント・同じ課題・同じ試行の番号の
組で対にし、1 回目の誤りの有無について McNemar の検定（正確な二項検定、両側）の p 値を示す。
"""
import json
import math
import os
from collections import Counter, defaultdict

from . import variants as V

Z = 1.959963984540054


def wilson(k, n):
    if n == 0:
        return None
    p = k / n
    d = 1 + Z * Z / n
    c = (p + Z * Z / (2 * n)) / d
    h = Z * math.sqrt(p * (1 - p) / n + Z * Z / (4 * n * n)) / d
    return max(0.0, c - h), min(1.0, c + h)


def mcnemar_exact(b, c):
    """不一致の組の数 b・c から、McNemar の正確な検定（二項検定、両側）の p 値。"""
    n = b + c
    if n == 0:
        return None
    k = min(b, c)
    tail = sum(math.comb(n, i) for i in range(k + 1)) / (2 ** n)
    return min(1.0, 2 * tail)


def load(paths):
    rows = []
    metas = {}
    archives = {}
    for p in paths:
        for line in open(p, encoding='utf-8'):
            line = line.strip()
            if line:
                rows.append(json.loads(line))
        base = p[:-len('.jsonl')] if p.endswith('.jsonl') else p
        for suffix, store in (('.meta.json', metas), ('.archive.json', archives)):
            q = base + suffix
            if os.path.exists(q):
                store[os.path.basename(base)] = json.load(open(q, encoding='utf-8'))
    return rows, metas, archives


def pct(x):
    return '—' if x is None else '%.1f%%' % (100 * x)


def rate_cell(k, n):
    if n == 0:
        return '—'
    lo, hi = wilson(k, n)
    return '%s (%d/%d) [%s, %s]' % (pct(k / n), k, n, pct(lo), pct(hi))


def pvalue(p):
    if p is None:
        return '—'
    return '%.3g' % p


def summarize(rows):
    groups = defaultdict(list)
    for r in rows:
        groups[(r['agent'], r['model'], r['variant'])].append(r)
    return groups


def stats(rs):
    written = [r for r in rs if r.get('first_ok') is not None]
    errs = [r for r in written if r['first_ok'] is False]
    fix_n = [r for r in errs if r.get('fixed') is not None]
    fixed = [r for r in fix_n if r['fixed']]
    cats = Counter(r.get('first_category') for r in errs)
    other = Counter(r['status'] for r in rs if r.get('first_ok') is None)
    return dict(total=len(rs), n=len(written), err=len(errs), fix_n=len(fix_n), fixed=len(fixed), cats=cats,
                other=other)


def paired(base_rows, rows):
    idx = {(r['task'], r['trial']): r for r in base_rows if r.get('first_ok') is not None}
    b = c = pairs = 0
    for r in rows:
        if r.get('first_ok') is None:
            continue
        o = idx.get((r['task'], r['trial']))
        if o is None:
            continue
        pairs += 1
        if o['first_ok'] and not r['first_ok']:
            b += 1
        elif not o['first_ok'] and r['first_ok']:
            c += 1
    return pairs, b, c


def render(rows, metas, archives, by_task=False, include_outside=False):
    out = ['# 構文だけの測定の集計', '']
    # 作業場所の外（リポジトリやほかの試行）を読んだ形跡のある試行は、参照の文書以外の情報を使った
    # おそれがあるので、既定では率の計算から除き、件数だけを示す
    outside = [r for r in rows if r.get('outside_access')]
    if outside:
        out += ['作業場所の外を読んだ形跡のある試行: %d 件（%s）' % (
            len(outside), '率に含めた' if include_outside else '率の計算から除いた'), '']
        for r in outside[:50]:
            out.append('- %s %s %s %s trial %s: %s' % (r['run_id'], r['agent'], r['variant'], r['task'], r['trial'],
                                                       ', '.join(r['outside_access'][:3])))
        out.append('')
        if not include_outside:
            rows = [r for r in rows if not r.get('outside_access')]
    if metas:
        out += ['## 実行', '', '| 実行 ID | エージェント | モデル | 選択肢 | 開始 | 終了 | 組の数 | 順 | 種 | コミット | 変更あり |',
                '|---|---|---|---|---|---|---|---|---|---|---|']
        for rid, m in sorted(metas.items()):
            out.append('| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |' % (
                rid, m.get('agent'), m.get('model'), json.dumps(m.get('agent_options'), ensure_ascii=False),
                m.get('started_at'), m.get('finished_at'), m.get('combinations'), m.get('order'), m.get('seed'),
                (m.get('git') or {}).get('head', '')[:12], (m.get('git') or {}).get('dirty')))
        out.append('')
    if archives:
        out += ['## 生の記録のアーカイブ', '', '| 実行 ID | パス | SHA-256 | 大きさ（バイト） |', '|---|---|---|---|']
        for rid, a in sorted(archives.items()):
            out.append('| %s | `%s` | `%s` | %s |' % (rid, a['path'], a['sha256'], a['bytes']))
        out.append('')
    groups = summarize(rows)
    agents = sorted({(k[0], k[1]) for k in groups})
    out += ['## 案ごとの率', '',
            '率の後の括弧は件数、角括弧は Wilson の 95% 信頼区間。差は V00 との差（ポイント）、p は対にした McNemar の'
            '正確な検定の p 値（1 回目の誤りの有無）。', '']
    for agent, model in agents:
        out += ['### %s（%s）' % (agent, model), '',
                '| 案 | 説明 | n | 1 回目の構文の誤りの率 | 1 回で直せた率 | V00 との差（誤りの率） | 対の数 | p | 多い誤りの分類 | 除いた試行 |',
                '|---|---|---|---|---|---|---|---|---|---|']
        base = groups.get((agent, model, 'V00'), [])
        bs = stats(base) if base else None
        for vid in V.VARIANT_IDS:
            rs = groups.get((agent, model, vid))
            if not rs:
                continue
            s = stats(rs)
            diff = '—'
            pairs_txt = p_txt = '—'
            if bs and vid != 'V00' and s['n'] and bs['n']:
                diff = '%+.1f' % (100 * (s['err'] / s['n'] - bs['err'] / bs['n']))
                pairs, b, c = paired(base, rs)
                pairs_txt = '%d（%d/%d）' % (pairs, b, c)
                p_txt = pvalue(mcnemar_exact(b, c))
            top = ', '.join('%s×%d' % (k, v) for k, v in s['cats'].most_common(3))
            excl = ', '.join('%s×%d' % (k, v) for k, v in sorted(s['other'].items()))
            out.append('| %s | %s | %d | %s | %s | %s | %s | %s | %s | %s |' % (
                vid, V.TITLES[vid], s['n'], rate_cell(s['err'], s['n']), rate_cell(s['fixed'], s['fix_n']), diff,
                pairs_txt, p_txt, top or '—', excl or '—'))
        out.append('')
        out.append('対の数の括弧は（V00 だけ通った組 / 案だけ通った組）。')
        out.append('')
    if by_task:
        out += ['## 課題ごとの 1 回目の構文の誤り（誤り/n）', '']
        tasks = sorted({r['task'] for r in rows})
        for agent, model in agents:
            out += ['### %s（%s）' % (agent, model), '', '| 案 | ' + ' | '.join(tasks) + ' |',
                    '|---|' + '---|' * len(tasks)]
            for vid in V.VARIANT_IDS:
                rs = groups.get((agent, model, vid))
                if not rs:
                    continue
                cells = []
                for t in tasks:
                    s = stats([r for r in rs if r['task'] == t])
                    cells.append('%d/%d' % (s['err'], s['n']) if s['n'] else '—')
                out.append('| %s | %s |' % (vid, ' | '.join(cells)))
            out.append('')
    cats = Counter(r.get('first_category') for r in rows if r.get('first_ok') is False)
    if cats:
        out += ['## 1 回目の誤りの分類（全体）', '', '| 分類 | 件数 |', '|---|---|']
        for k, v in cats.most_common():
            out.append('| %s | %d |' % (k, v))
        out.append('')
    return '\n'.join(out)


def report(args):
    rows, metas, archives = load(args.results)
    text = render(rows, metas, archives, by_task=args.by_task, include_outside=args.include_outside)
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(text + '\n')
    else:
        print(text)
    return text
