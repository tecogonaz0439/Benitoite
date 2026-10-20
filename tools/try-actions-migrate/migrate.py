#!/usr/bin/env python3
"""try の処置を確認する候補・確認表・diff と、確認後だけの適用。"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools/source-migrate'))
from source_extract import Snippet, snippets
import source_migrate as shared

VERSION = 1
WORD = re.compile(rb'\btry\b')
HANDWRITTEN = {'idioms.md', 'common-mistakes.md', 'language-comparison.md', 'testing.md'}
CLASSES = {'change', 'already_explicit', 'notation', 'pre_migration', 'keep_test', 'history', 'hold'}


def role(path):
    """保管資料と検査は読んで分類するが、適用先にはしない。"""
    if path.startswith(('reference/', 'docs/archive/', 'docs/todo/', '.git/', 'tools/bench/results/',
                        'tools/skill-eval/results/', 'tools/syntax-measure/')):
        return 'history'
    if path.startswith(('crates/benitoite/testdata/', 'crates/benitoite/tests/', 'fuzz/')):
        return 'test'
    if path.endswith('.rs') and (pathlib.Path(path).stem == 'tests' or '/tests/' in path):
        return 'test'
    if path.startswith('crates/benitoite/src/prelude/stdlib/'):
        return 'library'
    if path.startswith(('crates/benitoite/skill/references/', 'docs/ja/skill/references/')):
        return 'sample' if pathlib.Path(path).name in HANDWRITTEN else 'generator'
    if path == 'docs/reference/benitoite-minimal.md':
        return 'minimal_reference'
    if path.startswith(('docs/20', 'tools/source-migrate/',
                        'tools/try-actions-migrate/')) or path == 'AGENTS.md':
        return 'history'
    if path.startswith('tools/bench/') and path.endswith('.bnt'):
        return 'benchmark'
    if path.endswith('.rs') and not path.startswith('crates/benitoite/examples/'):
        return 'generator'
    return 'sample'


def files(root, paths):
    """既定は追跡ファイル。非公開の todo とビルド生成物を探索しない。"""
    if not paths:
        names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    else:
        names = []
        for name in paths:
            target = shared.safe_path(root, name)
            if target.is_dir():
                names.extend(str(p.relative_to(root)) for p in target.rglob('*') if p.is_file())
            else:
                names.append(name)
    return sorted({n for n in names if n and not n.startswith(('docs/todo/', 'target/', '.git/'))
                   and (n.endswith(('.bnt', '.rs', '.md')) or n.startswith('fuzz/corpus/'))})


def markdown_extras(data):
    """通常のブロック以外の fence と、fence の外のコードスパンを分類する。"""
    offset = 0
    outside = []
    fence = None
    for line in data.splitlines(keepends=True):
        m = re.match(rb' {0,3}(`{3,}|~{3,})([^\r\n]*)', line)
        if fence is None and m:
            fence = (m[1][:1], len(m[1]), m[2].strip(), offset + len(line))
        elif fence is not None:
            if m and m[1][:1] == fence[0] and len(m[1]) >= fence[1] and not m[2].strip():
                if fence[2] not in (b'', b'text', b'bnt', b'benitoite'):
                    start = fence[3]
                    # test などの実行用 fence は未解析の手本として保留し、記法に紛れ込ませない。
                    kind = 'markdown_fence' if fence[2].split()[:1] == [b'benitoite'] else 'markdown_notation'
                    yield Snippet(data[start:offset].decode(), list(range(start, offset + 1)),
                                  kind, 'non_executable_fence')
                fence = None
        else:
            outside.append((offset, line))
        offset += len(line)
    # コードスパンは改行を含められる。物理位置を保つため空白の正規化は行わない。
    masked = bytearray(b' ' * len(data))
    for start, line in outside:
        masked[start:start + len(line)] = line
    pattern = re.compile(rb'(?<!`)(`+)(?!`)(.*?)(?<!`)\1(?!`)', re.S)
    for m in pattern.finditer(masked):
        start, end = m.span(2)
        yield Snippet(data[start:end].decode(), list(range(start, end + 1)), 'markdown_inline')
    if fence is not None:
        start = fence[3]
        yield Snippet(data[start:].decode(), list(range(start, len(data) + 1)),
                      'markdown_notation', 'unclosed_fence')


def extract(path, data):
    covered = []
    for snippet in snippets(path, data):
        covered.extend(p for p in snippet.boundaries if p >= 0)
        yield snippet
    if path.endswith('.md'):
        for snippet in markdown_extras(data):
            covered.extend(p for p in snippet.boundaries if p >= 0)
            yield snippet
    # コメントや説明文の中の実行例も一覧から落とさず、文脈の確認へ回す。
    covered = set(covered)
    for m in WORD.finditer(data):
        if m.start() not in covered:
            yield Snippet(m[0].decode(), list(range(m.start(), m.end() + 1)),
                          'host_text', 'review_embedded_example')


def inventory(root, paths, helper):
    inputs, units, requests = [], [], []
    for path in files(root, paths):
        data = shared.safe_path(root, path).read_bytes()
        inputs.append({'path': path, 'source_sha256': shared.sha(data)})
        for number, snippet in enumerate(extract(path, data)):
            if not WORD.search(snippet.source.encode()):
                continue
            unit = {'path': path, 'source_sha256': shared.sha(data), 'snippet': number,
                    'kind': snippet.kind, 'role': role(path), 'hold': snippet.hold,
                    'source': snippet.source, 'boundaries': snippet.boundaries}
            unit['notation'] = (snippet.kind == 'markdown_inline' and
                                re.fullmatch(r'\s*try\s+(?:e|Expr|Operand)\s*', snippet.source) is not None)
            prefix = data[:snippet.boundaries[0]].decode(errors='replace')
            if unit['role'] != 'history' and path.endswith('.rs') and re.search(r'#\[(?:cfg\(test\)|test)\]', prefix):
                # 独立の Rust parser を持たないため、検査属性以降は保守的に検査として保持する。
                unit['role'] = 'test'
            # 明記された移行前の引用だけを自動編集から除く。曖昧な説明は保留にする。
            unit['pre_migration'] = path.endswith('.md') and re.search(
                r'(?:^|\n)(?:#{1,6}\s*|\*\*)?(?:Before(?: migration)?|移行前|旧構文)(?:\*\*)?\s*[:：]?\s*\n(?:```[^\n]*\n)?$',
                prefix, re.I) is not None
            units.append(unit)
            # 過去の入力や構文名から処置を決めない。現行の候補だけ本物の parser に渡す。
            unit['request'] = None
            if unit['role'] != 'history' and not snippet.hold and not unit['pre_migration']:
                unit['request'] = len(requests)
                requests.append({'path': path, 'source': snippet.source,
                                 'direct': snippet.kind == 'bnt'})
    response = subprocess.run([str(helper)], input=shared.dump(requests), text=True,
                              capture_output=True, cwd=root, check=True)
    answers = [json.loads(line) for line in response.stdout.splitlines()]
    if len(answers) != len(requests):
        raise ValueError('inventory response count mismatch')
    rows = []
    for unit in units:
        inv = answers[unit['request']] if unit['request'] is not None else {
            'tries': [], 'typed': False, 'parse_errors': [], 'check_codes': [], 'fragment': False}
        ast = {t['start']: t for t in inv['tries']}
        data = shared.safe_path(root, unit['path']).read_bytes()
        for match in WORD.finditer(unit['source'].encode()):
            t = ast.get(match.start())
            start = unit['boundaries'][match.start()]
            end_in_source = t['end'] if t else match.end()
            end = unit['boundaries'][end_in_source]
            owner = t['owner'] if t else None
            current = t['action'] if t else None
            chosen, reason = proposal(unit['role'], owner)
            holds = []
            if unit['hold']:
                holds.append(unit['hold'])
            if unit['role'] in ('generator', 'minimal_reference'):
                holds.append('review_generation_source' if unit['role'] == 'generator' else 'link_current_reference')
            if not t:
                holds.append('non_ast_example_or_text')
            elif not inv['typed']:
                holds.append('untyped_fragment' if inv['fragment'] else 'parse_or_type_errors')
            if start < 0 or end < 0:
                holds.append('unmapped_host_boundary')
            if owner and owner['kind'] in ('handler', 'constant'):
                holds.append('unsupported_enclosing_contract')
            before = data[start:end].decode() if start >= 0 and end >= 0 else ''
            # 通常の Rust 文字列でも挿入は ASCII だけなので既存の escape を保持できる。
            edits = []
            if t and current == 'implicit_return' and not holds and unit['role'] not in ('test', 'history') and not unit['notation']:
                pos = unit['boundaries'][t['operand_end']]
                if pos >= 0:
                    edits = [{'start': pos, 'end': pos, 'before': '', 'after': ' or ' + chosen}]
                else:
                    holds.append('unmapped_host_boundary')
            if chosen == 'die' and t and current == 'implicit_return':
                holds.append('contract_review_required')
            classification = ('history' if unit['role'] == 'history' else
                              'keep_test' if unit['role'] == 'test' else
                              'pre_migration' if unit['pre_migration'] else
                              'notation' if unit['notation'] else
                              'already_explicit' if t and current != 'implicit_return' else
                              'notation' if not t and unit['kind'] in ('markdown_inline', 'markdown_notation') else
                              'hold' if holds else 'change')
            updated = data
            for edit in reversed(edits):
                updated = updated[:edit['start']] + edit['after'].encode() + updated[edit['end']:]
            local_edits = [e for e in edits if start <= e['start'] <= end]
            after = before.encode()
            for e in reversed(local_edits):
                p = e['start'] - start
                after = after[:p] + e['after'].encode() + after[p:]
            rows.append({'id': f"try-{len(rows) + 1:06}", 'path': unit['path'],
                         'source_sha256': unit['source_sha256'], 'after_sha256': shared.sha(updated),
                         'snippet': unit['snippet'], 'host_kind': unit['kind'], 'role': unit['role'],
                         'line': data[:max(0, start)].count(b'\n') + 1, 'start': start, 'end': end,
                         'operand_end': t['operand_end'] if t else None,
                         'operand_host_end': unit['boundaries'][t['operand_end']] if t else None,
                         'action': current, 'owner': owner, 'classification': classification,
                         'proposed_action': chosen if t and current == 'implicit_return' else None,
                         'reason': reason, 'before': before, 'after': after.decode(), 'edits': edits,
                         'typed': inv['typed'], 'parse_errors': inv['parse_errors'],
                         'check_codes': inv['check_codes'], 'holds': holds,
                         'contract_changes': {'uses': 'review Process.Exit' if chosen == 'die' else 'unchanged',
                                              'return': 'review outer Result/Option' if chosen == 'die' else 'unchanged',
                                              'output': 'review failure report and exit status' if chosen == 'die' else 'unchanged'},
                         'contract_reviewed': False, 'confirmation': 'pending'})
    manifest = {'version': VERSION, 'inputs': inputs, 'candidates': rows,
                'counts': dict(sorted(Counter(r['classification'] for r in rows).items()))}
    return manifest


def proposal(source_role, owner):
    if source_role == 'benchmark':
        return 'return', 'Preserve the benchmark result, effects, and workload.'
    if source_role == 'library' or not owner or owner['kind'] != 'function' or owner['name'] != 'main':
        return 'return', 'Preserve the reusable function or callback contract.'
    return 'die', 'Entry point: review effects, return contract, and failure output before choosing die.'


def editable(root, path):
    if role(path) not in ('sample', 'library', 'benchmark') or not path.endswith(('.bnt', '.rs', '.md')):
        raise ValueError('protected migration target: ' + path)
    return shared.safe_path(root, path)


def selected(manifest, *, approved):
    if manifest['version'] != VERSION:
        raise ValueError('unsupported manifest version')
    if len({r['id'] for r in manifest['candidates']}) != len(manifest['candidates']):
        raise ValueError('duplicate candidate id')
    rows = []
    for row in manifest['candidates']:
        if row['classification'] not in CLASSES:
            raise ValueError('unknown classification: ' + row['id'])
        if approved and row['confirmation'] != 'approved':
            continue
        if not approved and row['classification'] != 'change':
            continue
        if approved and row['proposed_action'] == 'die' and (not row['contract_reviewed'] or
                any(not v or v.startswith('review ') for v in row['contract_changes'].values())):
            raise ValueError('die contract review required: ' + row['id'])
        if row['classification'] != 'change' or row['holds'] or not row['typed']:
            raise ValueError('held candidate cannot be applied: ' + row['id'])
        if row['action'] != 'implicit_return' or row['proposed_action'] not in ('return', 'die'):
            raise ValueError('invalid action: ' + row['id'])
        action_edits = [e for e in row['edits'] if e['start'] == row['operand_host_end']
                        and e['before'] == '' and e['after'] == ' or ' + row['proposed_action']]
        if len(action_edits) != 1:
            raise ValueError('action edit mismatch: ' + row['id'])
        rows.append(row)
    selected_ids = {r['id'] for r in rows}
    shared_ends = {}
    for row in manifest['candidates']:
        if row['action'] == 'implicit_return':
            for edit in row['edits']:
                if edit['before'] == '' and edit['after'] in (' or return', ' or die'):
                    shared_ends.setdefault((row['path'], edit['start']), set()).add(row['id'])
    for ids in shared_ends.values():
        if ids & selected_ids and not ids <= selected_ids:
            raise ValueError('nested try action dependency: ' + ', '.join(sorted(ids)))
    # 入れ子の try は同じ末尾を持てる。同位置の内側から処置を並べ、共通適用器へ一挿入で渡す。
    grouped = {}
    for row in rows:
        grouped.setdefault(row['path'], []).append(row)
    combined = []
    for path, group in grouped.items():
        insertions, other = {}, []
        for row in sorted(group, key=lambda r: r['start'], reverse=True):
            for edit in row['edits']:
                if edit['start'] == edit['end']:
                    key = edit['start']
                    insertions[key] = insertions.get(key, '') + edit['after']
                else:
                    other.append(edit)
        combined.append({'path': path, 'source_sha256': group[0]['source_sha256'], 'edits': other + [
            {'start': p, 'end': p, 'before': '', 'after': s} for p, s in sorted(insertions.items())]})
    return combined


def review(manifest):
    lines = ['# try の移行候補の確認表', '',
             '既定は読み取りのみ。die の契約と処置は人が確認する。候補ごとの変更後のハッシュは単独編集、ファイルの最終ハッシュは file_changes に記す。', '',
             '分類の件数: `' + json.dumps(manifest['counts'], ensure_ascii=False) + '`', '']
    for row in manifest['candidates']:
        lines.extend([f"## {row['id']} — {row['path']}:{row['line']}", '',
                      '```json', shared.dump({k: v for k, v in row.items() if k != 'edits'}).rstrip(),
                      '```', ''])
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=pathlib.Path, default=REPO)
    parser.add_argument('--helper', type=pathlib.Path, default=REPO / 'target/debug/examples/try_actions_inventory')
    sub = parser.add_subparsers(dest='command', required=True)
    scan = sub.add_parser('inventory')
    scan.add_argument('--out', type=pathlib.Path, required=True)
    scan.add_argument('paths', nargs='*')
    diff = sub.add_parser('diff')
    diff.add_argument('--manifest', type=pathlib.Path, required=True)
    diff.add_argument('--out', type=pathlib.Path, required=True)
    apply = sub.add_parser('apply')
    apply.add_argument('--manifest', type=pathlib.Path, required=True)
    apply.add_argument('--reviewed-sha256', required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    path_for = lambda path: editable(root, path)
    if args.command == 'inventory':
        manifest = inventory(root, args.paths, args.helper.resolve())
        changes = shared.proposed(selected(manifest, approved=False), path_for)
        manifest['file_changes'] = {p: {'before_sha256': shared.sha(a), 'after_sha256': shared.sha(b)}
                                    for p, (a, b) in changes.items()}
        args.out.mkdir(parents=True, exist_ok=True)
        (args.out / 'manifest.json').write_text(shared.dump(manifest))
        (args.out / 'review.md').write_text(review(manifest))
        shared.write_diff(changes, args.out / 'proposed.diff')
        print(shared.dump(manifest['counts']).strip())
    elif args.command == 'diff':
        manifest = json.loads(args.manifest.read_text())
        rows = selected(manifest, approved=True)
        for unit in manifest['inputs']:
            if shared.sha(shared.safe_path(root, unit['path']).read_bytes()) != unit['source_sha256']:
                raise ValueError('input hash mismatch: ' + unit['path'])
        shared.write_diff(shared.proposed(rows, path_for), args.out)
    elif args.command == 'apply':
        manifest = shared.reviewed_manifest(args.manifest, args.reviewed_sha256)
        rows = selected(manifest, approved=True)
        for row in rows:
            editable(root, row['path'])
        count = shared.apply(manifest['inputs'], rows,
                             manifest_sha256=args.reviewed_sha256,
                             receipt=args.manifest.with_suffix('.applied.json'), path_for=lambda p: shared.safe_path(root, p))
        # 入力全体には保管資料も含むが、編集先は上で検証する。
        print('already applied; no diff' if count is None else f'applied {count} files')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
