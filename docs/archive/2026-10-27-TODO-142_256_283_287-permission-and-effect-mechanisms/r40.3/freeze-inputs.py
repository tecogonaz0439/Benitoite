#!/usr/bin/env python3
"""独立期待値と通常ソースを一度だけ固定する。CLI の出力を期待値へ使わない。"""
import hashlib
import json
from pathlib import Path

out = Path(__file__).resolve().parent
root = Path.cwd()
change = out.parent
inputs = out / 'inputs'
if (out / 'handoff.json').exists():
    raise SystemExit('固定済みの一覧を上書きしない')
inputs.mkdir(exist_ok=True)
cases = []


def effects(names=(), bounds=()):
    return {'basis': 'declaredUpperBound', 'expanded': list(names), 'bounds': list(bounds)}


def add(name, source, expected, note):
    path = inputs / (name + '.bnt')
    path.write_text(source)
    cases.append({'file': str(path.relative_to(out)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                  'expected': expected, 'purpose': note})


def success(name, source, contract, note):
    add(name, source, {'exit': 0, 'complete': True, 'effects': contract}, note)


def rejection(name, source, code, reason=None):
    expected = {'exit': 2, 'complete': False, 'effects': None, 'code': code}
    if reason:
        expected['reason'] = reason
    add(name, source, expected, '拒否時は集約も null。理由は診断の注記で照合する')


imports = 'import Benitoite.Unofficial.IO.File\nimport Benitoite.Unofficial.Network.Http\n'
for name, upper, contract in [
    ('pure', '', effects()),
    ('top', ' uses File.Read', effects(['File.Read'], [{'name': 'File.Read', 'scope': {'kind': 'all'}}])),
    ('non-top', ' uses File.Write["/data/**"]', effects(['File.Write'], [{'name': 'File.Write', 'scope': {'kind': 'pathTree', 'path': '/data'}}])),
    ('redundant', ' uses File.Read, File.Read["/data/**"], File.Read["/data/a"]',
     effects(['File.Read'], [{'name': 'File.Read', 'scope': scope} for scope in
                            [{'kind': 'all'}, {'kind': 'pathExact', 'path': '/data/a'}, {'kind': 'pathTree', 'path': '/data'}]])),
]:
    success(name, imports + f'function main() -> Unit{upper}\nend function\n@test\nfunction upper() -> Unit{upper}\nend function\n', contract,
            '本体は純粋でも宣言上限を保持。Top と狭い原子の併存も省かない')

success('handled-user-pure', 'effect Report\n function save() -> Unit\nend effect\nfunction main() -> Unit\n handle save() with\n case save() -> resume(())\n end handle\nend function\n@test\nfunction upper() -> Unit\n main()\nend function\n', effects(), '処理した利用者名を名前集合と bounds へ戻さない')
success('handled-scoped-write', (root / 'crates/benitoite/tests/cli_process/fixtures/handled-scoped-write.bnt').read_text(),
        effects(['File.Write'], [{'name': 'File.Write', 'scope': {'kind': 'pathTree', 'path': '/data/reports'}}]),
        '固定範囲の利用者操作の節から File.writeTextIn へ渡す。本体は実行しない')

for name, old, code, reason in [
    ('not-covered', 'atom-single', 'E0519', 'notCovered'),
    ('atomic-cover-only', 'atom-multi', 'E0519', 'atomicCoverOnly'),
    ('unknown-source', 'path-project-parameter-narrow', 'E0519', 'unknownSource'),
    ('budget-exceeded', 'budget', 'E0519', 'budgetExceeded'),
    ('show-rejected', 'request-error-show', 'E0705', None),
]:
    rejection(name, (change / 'r40.1/probes' / (old + '.bnt')).read_text(), code, reason)
for name, old in [('projection-repaired', 'path-project-bind'), ('show-match', 'request-error-match')]:
    success(name, (change / 'r40.1/probes' / (old + '.bnt')).read_text(), effects(),
            '案内による受理。RequestCheckError の標準 Show を追加しない判断を保つ')
for name, old, code in [('user-unhandled', 'unhandled', 'E0506'), ('user-scope-rejected', 'user-range', 'E0513')]:
    rejection(name, (change / 'ub20.01/inputs' / (old + '.bnt')).read_text(), code)

# 操作の一覧は標準宣言の公開契約に基づく。出力や処理系の表から生成しない。
reads = ['File.readText(path)', 'File.readTextIn(path)', 'File.openReader(path)', 'File.readLine(reader)',
         'File.readBytes(path)', 'File.readBytesIn(path)', 'File.readLines(path)', 'File.exists(path)',
         'File.info(path)', 'File.listDirectory(path)', 'File.walk(path)', 'File.canonicalize(path)', 'File.readChunk(reader, maximumBytes)']
writes = ['File.writeText(path, text)', 'File.writeTextIn(path, text)', 'File.appendText(path, text)',
          'File.appendTextIn(path, text)', 'File.writeBytes(path, content)', 'File.writeBytesIn(path, content)',
          'File.appendBytes(path, content)', 'File.appendBytesIn(path, content)', 'File.createDirectory(path)',
          'File.remove(path)', 'File.removeTree(path)', 'File.rename(from, to)', 'File.openWriter(path, mode)',
          'File.write(writer, text)', 'File.writeLine(writer, text)', 'File.writeChunk(writer, content)']
connects = ['Http.send(request)', 'Http.sendIn(request)']
for label, effect, scope, clauses, missing in [
    ('read', 'File.Read', '["/data/**"]', reads, 'File.readTextIn(path)'),
    ('write', 'File.Write', '["/data/**"]', writes, 'File.writeTextIn(path, text)'),
    ('connect', 'Http.Connect', '["api.example", 443]', connects, 'Http.sendIn(request)'),
]:
    contract = effects([effect], [{'name': effect, 'scope': {'kind': 'endpoint', 'host': {'kind': 'exact', 'name': 'api.example'},
                              'ports': {'minimum': 443, 'maximum': 443}} if label == 'connect' else {'kind': 'pathTree', 'path': '/data'}}])
    for partial in [False, True]:
        upper = f' uses {effect}{scope}' if partial else ''
        body = ''.join(f' case {clause} -> 0\n' for clause in clauses if not partial or clause != missing)
        source = imports + f'function protected() -> Integer uses {effect}{scope}\n return 1\nend function\nfunction main() -> Unit{upper}\n bind _ <- handle protected() with\n{body} end handle\nend function\n@test\nfunction upper() -> Unit{upper}\n main()\nend function\n'
        success(f'{label}-' + ('partial' if partial else 'complete'), source, contract if partial else effects(),
                f'{effect} 全{len(clauses)}節' + (f'のうち {missing} が不足' if partial else 'を処理'))
        if partial:
            rejection(f'{label}-missing-upper', source.replace(f'function main() -> Unit{upper}', 'function main() -> Unit').replace(f'function upper() -> Unit{upper}', 'function upper() -> Unit'), 'E0501')

doc = '//! ```benitoite error\n//! import Benitoite.Unofficial.IO.File\n//! function main() -> Integer uses File.Write\n//!  return "bad"\n//! end function\n//! ```\n//! ```diagnostic\n//! E0401\n//! ```\nfunction helper() -> Unit\nend function\n'
add('doc-error', doc, {'exit': 0, 'complete': True, 'effects': effects(), 'doc': True, 'diagnosticCode': 'E0401'},
    '期待した拒否の doc 例の空 Effects は純粋を意味しない。実行の集約から除く')

manifest = {'schemaVersion': 1, 'basis': '独立期待値を公開契約から先に固定。CLI 出力は不使用',
            'rule': '期待値だけを書き換えない。差は入力・理由・承認とともに後続へ返す',
            'baselineWork': '867a36713aa30520be4d5ea8dff0d57b846c919c', 'cases': cases}
data = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()
(out / 'handoff.json').write_bytes(data)
(out / 'handoff.sha256').write_text(hashlib.sha256(data).hexdigest() + '  handoff.json\n')
rows = ['# K10・候補 CLI 用の固定入力と独立期待値', '',
        '期待値は公開契約から独立に定め、実行前に固定した。`handoff.json` とその SHA-256 を正とする。期待値だけの差替えは認めず、相違は入力・理由・後続の判断とともに記録する。実 IO の観測と Rust/Lean の比較は K10 に残す。', '',
        '| ファイル | 期待する終了・契約または診断 | SHA-256 |', '|---|---|---|']
for case in cases:
    expected = case['expected']
    text = str(expected['exit']) + ' / ' + (expected.get('code', '') + ' ' + expected.get('reason', '') if expected['exit'] else json.dumps(expected['effects'], ensure_ascii=False, separators=(',', ':')))
    rows.append(f"| [{Path(case['file']).name}]({case['file']}) | `{text.strip()}` | `{case['sha256']}` |")
(out / 'handoff.md').write_text('\n'.join(rows) + '\n')
print(f'{len(cases)}入力を固定した。期待値の SHA-256: {hashlib.sha256(data).hexdigest()}')
