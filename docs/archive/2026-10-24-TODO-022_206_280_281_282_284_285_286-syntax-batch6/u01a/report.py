#!/usr/bin/env python3
"""取得した診断だけを集計し、U01b への一覧を作る。"""
import collections
import gzip
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('u01_inventory', HERE / 'inventory.py')
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


def key(diagnostic):
    primary = diagnostic.get('primary') or {}
    start = primary.get('start') or {}
    return (diagnostic.get('code'), primary.get('file'), start.get('offset'))


def main():
    totals = json.loads((HERE / 'all-counts.json').read_text())
    manifest = json.loads(inventory.MANIFEST.read_text())
    items = {item['id']: item for item in manifest['inputs']}
    deltas, unavailable, transitions, expectation_differences = [], [], [], []
    codes = {version: collections.Counter() for version in ('b0', 'current')}
    shared = []
    with gzip.open(inventory.RECORDS / 'all-observations.jsonl.gz', 'rt') as stream:
        for line in stream:
            record = json.loads(line)
            old, new = record['b0'], record['current']
            for version in codes:
                if record[version]['W']['acquired']:
                    codes[version].update(d['code'] for d in record[version]['W']['warnings'])
                for mode in ('W', 'R'):
                    row = record[version][mode]
                    if not row['acquired']:
                        unavailable.append({'id': record['id'], 'version': version, 'mode': mode,
                                            'exit': row['exit'], 'reason': row.get('reason', 'usage-or-no-structured-diagnostic')})
            if all(r['acquired'] for r in (old['W'], old['R'], new['W'], new['R'])):
                before = {key(d) for d in old['W']['warnings']}
                after = {key(d) for d in new['W']['warnings']}
                if before != after or old['R']['exit'] != new['R']['exit']:
                    deltas.append({'id': record['id'], 'group': record['group'],
                                   'oldWarnings': len(old['W']['warnings']), 'newWarnings': len(new['W']['warnings']),
                                   'added': [d for d in new['W']['warnings'] if key(d) not in before],
                                   'removed': [d for d in old['W']['warnings'] if key(d) not in after],
                                   'oldW': old['W']['exit'], 'newW': new['W']['exit'],
                                   'oldR': old['R']['exit'], 'newR': new['R']['exit']})
                if old['W']['exit'] == 0 and new['W']['exit'] == 2:
                    transitions.append({'id': record['id'], 'errors': new['W']['errors']})
                if old['R']['exit'] == 0 and new['R']['exit'] == 2 and old['W']['exit'] == new['W']['exit'] == 0:
                    shared.append(record['id'])
            item = items[record['id']]
            # 実行せず分かる、check/test 文書例の「診断なし」の契約だけを判定する。
            expectation = item.get('expectation', {})
            if expectation.get('mode') in ('check', 'test') and new['W']['acquired'] and (
                    new['W']['exit'] != 0 or new['W']['warnings'] or new['W']['errors']):
                expectation_differences.append({'id': record['id'], 'mode': expectation['mode'],
                                               'warnings': new['W']['warnings'], 'errors': new['W']['errors'],
                                               'exit': new['W']['exit']})
    inventory.write(HERE / 'warning-deltas.json', deltas)
    inventory.write(HERE / 'unacquired.json', unavailable)
    inventory.write(HERE / 'normal-rejections.json', transitions)
    inventory.write(HERE / 'expectation-differences.json', expectation_differences)
    inventory.write(HERE / 'strict-new-rejections.json', shared)
    inventory.write(HERE / 'warning-codes.json', codes)

    lines = ['# U01: 警告と strict 入力の棚卸し', '',
             'U01a、2026-10-27。取得した CLI 診断を旧新で比較した。解析の消費量・予算の到達と期待値の修正は U01b の範囲である。', '',
             '## 比較する状態と数え方', '',
             '- B0: `706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8`。現在版: `cb15b08b3ca4ba0810a765322c3cfd8678c598f7`。いずれも既定構成の debug ビルド。実行ファイルの SHA-256 は [全件の集計](../u01a/all-counts.json)にある。',
             '- [共通入力一覧](../u01a/inputs.json)は1,217入口であり、同じ本文・付随ファイルを両版へ渡した。標準ライブラリの組込みソースは各版の同梱物を使い、そのハッシュの差を [標準本体の観察](../u01a/standard-observations.json)へ残した。',
             f'- 共通一覧自体の SHA-256: `{totals["manifestSha256"]}`。',
             '- W は通常検査、R は `--deny-warnings` 付きの同じ検査である。main が必要な例には `check --diagnostics=json`、main 不要の例には `test --check --report=json --diagnostics=json` を使った。失敗を意図する入力にも W と R を両方実行した。スクリプト本体や利用者テストは実行しない。',
             '- 「警告ファイル」は入口単位で警告が1件以上あった数、「警告診断」はW コードを持つ診断の数である（strict で error に昇格した同じコードも含む）。パッケージは一括指定1件、抽出例は仮想ファイル1件とする。同じ本文の標準 doc と生成 Skill の例は別の入口であり、カテゴリ間で固有ファイル数を合算しない。',
             '- 「R 拒否」は取得済み R の終了2の数であり、既存の誤りによる拒否も含む。「警告だけの strict 拒否」は同じ版で W が終了0、R が終了2の数である。取得不能・タイムアウト・CLI の使い方の誤りは取得済みの0件へ含めない。',
             '- 標準本体、Rust の文字列、仕様の文・型・パターンの断片、`.files` と `.formatted` の付属入力を、独立した実行可能ファイルへ書き換えていない。bind や未知値を足す変更もない。', '',
             '## 通常の警告と strict 拒否', '',
             '| 入力の区分 | 入口数 | 旧 W 警告ファイル / 診断 | 新 W 警告ファイル / 診断 | 旧 R 拒否 / 警告だけ | 新 R 拒否 / 警告だけ |',
             '|---|---:|---:|---:|---:|---:|']
    labels = {'golden-or-fixture': 'golden と検査用ソース（単独入口）', 'golden-package': 'golden のパッケージ（一括入口）',
              'test-file': 'tests 配下の実ファイル', 'example': 'examples の実ファイル', 'tool-input': '道具の実ファイル',
              'bench-input': 'bench の実ファイル（静的検査だけ）', 'standard-doc': '標準ソースから抽出した doc',
              'user-doc': '利用者ソースから抽出した doc', 'reference': '英語 reference の実行用例',
              'skill-handwritten': 'Skill の手書きの実行用例', 'skill-generated': 'Skill の生成参照の実行用例'}
    for group, count in totals['groups'].items():
        old, new = count['b0'], count['current']
        lines.append(f'| {labels.get(group, group)} | {count["inputs"]} | '
                     f'{old["W"]["warningFiles"]} / {old["W"]["warnings"]} | '
                     f'{new["W"]["warningFiles"]} / {new["W"]["warnings"]} | '
                     f'{old["R"]["rejected"]} / {old["strictOnlyRejected"]} | '
                     f'{new["R"]["rejected"]} / {new["strictOnlyRejected"]} |')
    lines += ['', '警告コード別（W、取得済みの入口だけ）:', '', '| コード | 旧診断数 | 新診断数 |', '|---|---:|---:|']
    for code in sorted(codes['b0'].keys() | codes['current'].keys()):
        lines.append(f'| {code} | {codes["b0"][code]} | {codes["current"][code]} |')
    lines += ['', f'旧 R が受理し、新 R だけが拒否する同じ入口は **{len(shared)}件**である（両版の W が受理したものだけ）。[一覧](../u01a/strict-new-rejections.json)を U01b へ渡す。',
              f'旧 W 受理から新 W 拒否への変化は **{len(transitions)}件**。[診断と一覧](../u01a/normal-rejections.json)に残す。', '',
              '## 意図した失敗を含む誤りの観察', '',
              '| 区分 | 旧 W 誤りファイル / 診断 | 新 W 誤りファイル / 診断 | 旧 R 誤り診断 | 新 R 誤り診断 |',
              '|---|---:|---:|---:|---:|']
    for group, count in totals['groups'].items():
        old, new = count['b0'], count['current']
        lines.append(f'| {labels.get(group, group)} | {old["W"]["errorFiles"]} / {old["W"]["errors"]} | '
                     f'{new["W"]["errorFiles"]} / {new["W"]["errors"]} | {old["R"]["errors"]} | {new["R"]["errors"]} |')
    lines += ['', '## 標準本体と未取得の範囲', '',
              '標準63モジュールをすべて import する同じプローブを両版へ渡した。W/R とも終了0、読み込み63ソース、出力された警告診断0件である。標準本体の警告抑制を観察した結果であり、標準本体を追加解析した結果ではない。標準本体の解析は除外されるため、解析の消費量・候補数は未取得であり、0消費の実測へ含めない。抽出 doc 18例は上表の別区分である。', '',
              f'CLI の実行で個別診断を取得できなかったものは **{len(unavailable)}起動**。[入力・版・W/R・終了状態](../u01a/unacquired.json)に列挙した。', '',
              '| 追加の入力一覧 | 固定した単位 | 旧新の個別 W/R 診断 | 確認する既存の実行器 |',
              '|---|---:|---|---|',
              '| Rust のホストソース | 509ファイル | 未取得。文字列リテラルと動的な生成入力の数へ換算しない | 既定 lib と全統合の既存テスト |',
              '| 仕様と付録08-04の `text` 断片 | 131ブロック | 未取得。文・型・パターンを完全なプログラムへ補わない | `spec_examples` |',
              '| 生成 Skill のシグネチャなど | 575フェンス | 実行用の例ではない。警告0件には数えない | `skill_generated` と `skill_docs` |',
              '| `.files` / `.formatted` 配下の付属ソース | 28ファイル | 独立入口として未実行。親の読み込み・既存 golden で確認する | `golden` |', '',
              'Rust のホスト・実ソース・文書・golden の期待値は [hosts.json](../u01a/hosts.json)、設定・Wasm 等の付随ファイルは [support-hosts.json](../u01a/support-hosts.json)、仕様の断片は [spec-fragments.json](../u01a/spec-fragments.json)に、それぞれ一覧と SHA-256 を残した。`deny_warnings` と `--deny-warnings` の参照位置は hosts.json の `strictSites` に含む。これは参照を持つホストの一覧であり、strict 入力の個数ではない。', '',
              '標準 doc の抽出には本番の AST と `doc_examples::extract`、reference と Skill には既存の `doc_examples::blocks` / `example` を使った。初回の不正UTF-8停止は、同入力を抽出不能として記録して処理を続けるよう直した。生成参照の宣言フェンスを実行用の例として数えず、本文・位置とともに [抽出の内訳](../u01a/extraction.json)へ別分類した。', '',
              '## U01b への受け渡し', '',
              f'警告の追加・削除または R の終了が変わった入口は **{len(deltas)}件**。[診断の差分一覧](../u01a/warning-deltas.json)に旧新件数、W/R の終了、追加・削除した診断の元位置・補助位置・注記を保存した。期待値を修正した一覧ではない。',
              f'抽出した check/test 例の「診断なし」という期待との食い違いは **{len(expectation_differences)}件**。[一覧](../u01a/expectation-differences.json)に保存した。run の出力や error の部分文字列、golden の JSON 全文については既存テストの結果を [U01a の結果](../u01a/results.md)で確認する。',
              '本体ごと・全体の解析消費と予算上限への到達、定数展開の大きさ、外の事実なら未到達となる枝に独立解析が出した候補の分類は、この枝では取得していない。警告の減少を予算超過の件数に読み替えず、U01b が同じ一覧・ハッシュを使って区別する。', '',
              '生の全出力は `work/m012/records/u01a/all-raw.jsonl.gz`、個別診断と版・W/Rの対応は `all-observations.jsonl.gz`、抽出本文は `doc-examples.jsonl.gz` と `extracted.jsonl.gz` に保存した。永続記録の大きさと SHA-256 は [records-index.json](../u01a/records-index.json)にある。リポジトリには [全件集計](../u01a/all-counts.json)と `all-inputs-00.json` 以降の分割した索引を置く。', '']
    destination = HERE.parent / 'u01'
    destination.mkdir(exist_ok=True)
    (destination / 'warnings.md').write_text('\n'.join(lines))
    print(json.dumps({'warningChanges': len(deltas), 'newStrictRejections': len(shared),
                      'newNormalRejections': len(transitions), 'unacquiredRuns': len(unavailable),
                      'documentExpectationDifferences': len(expectation_differences)}))


if __name__ == '__main__':
    main()
