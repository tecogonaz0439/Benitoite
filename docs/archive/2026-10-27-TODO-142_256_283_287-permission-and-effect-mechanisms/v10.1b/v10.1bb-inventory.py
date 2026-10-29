"""保存した版の検索結果から、初稿の一覧へ V10.1bb の追補を加える。"""
from pathlib import Path
import hashlib
import json
import re

V = Path(__file__).resolve().parent
ROOT = V.parents[2]
MARKER = '\n## V10.1bb 追補（RV-V10.1b 中1・中2）\n'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def occurrences(path, action):
    return [dict(line=i, text=line.strip(), action=action(i))
            for i, line in enumerate((ROOT / path).read_text().splitlines(), 1)
            if re.search(r'0\.0\.12|0, 0, 12', line)]


data = json.loads((V / 'j2-rewrite-inventory.json').read_text())
data['firstDraftCounts'] = dict(testdata=50, integrationTestFiles=5,
                              sourceTestFiles=4, testFiles=9, registryAndText=2,
                              diagnostics=4, hashProposals=3, hashTargets=4,
                              uniqueRewriteFiles=67, exclusionRows=8)
path = 'crates/benitoite/src/typeck/pattern_ext.rs'
addition = dict(
    path=path, sha256=sha(ROOT / path),
    reason='#[cfg(test)] 内の external の場合に使う根の package.bnt の成功用宣言を0.0.13へ更新する。E0908より先のパターンの検査へ到達させる',
    readers='lib_default の typeck::pattern_ext::tests。依存側の設定は既存50候補の d8-extensible.files/dep/package.bnt。MemFsの文字列を全比較へ収集しない',
    occurrences=occurrences(path, lambda _: 'V10.3aで成功用の language 宣言を0.0.13へ更新する'))
data['testFiles'] = [r for r in data['testFiles'] if r['path'] != path] + [addition]

spec_reader = ('spec_examples::spec_and_appendix_examples_are_readable の text 抽出 → check_example → '
               'check_local_bindings → pipeline::check_files。ローダは通るが、loading_errors と '
               '束縛診断の絞り込みに E0907/E0908 はなく、版の受理自体を検査の成功条件にしていない。'
               '版上げ後に束縛の検査まで到達することは V10.3a で確かめる')
documents = [
    ('docs/design/01-spec/01-02-syntax.md', [477], spec_reader,
     'V10.3aで現在の正常な先頭部分の例を0.0.13へ更新する案。spec_examples.rsの補助の依存headerと同時に確認する'),
    ('docs/design/06-tooling/06-09-packages.md', [20, 32],
     'spec_examples の text 抽出対象は01-specと付録08-04であり、本章は含まれない。文書の例を直接実行するテストは、調べた tests 内では見つからなかった',
     'V10.3aで根とパッケージの正常な宣言の例を0.0.13へ更新する案。54・56行の過去の登録・案内の説明は保持し、新登録の説明は現行の設計文書との整合で別に確認する'),
    ('docs/reference/benitoite.md', [2059, 2077, 2109],
     'reference_examples::code_examples_in_the_language_reference_behave_as_written → doc_examples。2059の files と2077の本文はCLIのrun、2109の files はCLIのcheckへ渡る。三つとも実ローダが版を照合する',
     'V10.3aで三つの実行例の宣言と現在版の説明・version表示を0.0.13へ更新する案。2016〜2020の旧版の移行節と旧版の宣言は保持し、一括置換しない。新しい移行手順は書かない'),
    ('docs/ja/reference/benitoite.md', [1963, 1981, 2013],
     'reference_examplesのDOCUMENTSは英語のbenitoite.mdだけであり、この訳は直接実行しない。英語の例との対照をV10.3aで行う',
     'V10.3aで対応する三宣言・現在版の表示・訳元を英語と同時に0.0.13へ更新する案。1920〜1924の旧版の移行節と旧版の宣言は保持する'),
    ('docs/reference/install.md', [],
     'reference_examplesのDOCUMENTSにinstall.mdはなく、直接実行するテストは調べた tests 内では見つからなかった',
     'V10.3aで3・5行の現在版の説明を0.0.13へ更新する案。150・152行の0.0.11から0.0.12への更新節とinlineのlanguage宣言は過去の手順として保持する。0.0.13の移行手順に書き換えない'),
    ('docs/ja/reference/install.md', [],
     '直接実行するテストは調べた tests 内では見つからなかった。英語install.mdとの対照をV10.3aで行う',
     'V10.3aで3・5・7行の訳元と現在版の説明を英語と同時に更新する案。152・154行の旧版の更新節とinlineのlanguage宣言は保持する'),
]
data['documentExamples'] = [
    dict(path=p, sha256=sha(ROOT / p), declarationLines=lines, readers=reader,
         change=action, occurrences=occurrences(p, lambda _, a=action: a))
    for p, lines, reader, action in documents]

metadata = [
    ('crates/benitoite/Cargo.toml', 'V10.3aでbenitoiteの版だけ0.0.13へ。ワークスペースの全依存を更新しない', 'Cargoとbuild_info。W-V'),
    ('Cargo.lock', 'V10.3aでbenitoite項目を対象を絞って同期する', 'Cargo。W-Vと候補照合'),
    ('fuzz/Cargo.lock', 'V10.3aでbenitoiteのパス依存の項目だけ同期する', 'fuzzのCargo。勧告照合と候補照合'),
    ('README.md', 'V10.3aで現在版を更新する。0.0.13の移行案内を作らない', '実行例の自動抽出ではなく候補照合'),
    ('crates/benitoite/skill/SKILL.md', '既存必須欄の説明だけを指すv0.0.12固定参照は意味を確認して保持できる。V10.2bの一覧をV10.3aで照合する', 'skill_examplesとskill_docs。リンク先の取得・内容の実行を確認した意味ではない'),
    ('crates/benitoite/skill/references/inspection.md', '既存必須欄のv0.0.12固定参照は意味を確認して保持できる。新しい範囲の説明は候補版へ固定する。V10.2bでの編集結果をV10.3aで照合する', 'skill_examples。版固定参照の意味は文書と候補の照合'),
]
for p in ['SKILL.md', 'references/common-mistakes.md', 'references/idioms.md',
          'references/inspection.md', 'references/language-comparison.md']:
    metadata.append(('docs/ja/skill/' + p,
                     'V10.3aで訳元の版を0.0.13へ更新し英語の最終差分に対応させる。版固定参照は英語側の保持・更新の判断に合わせる',
                     '日本語訳をskill_examplesのDOCUMENTSには含めない。V10.3aで英語との対照'))
data['relatedVersionFiles'] = [
    dict(path=p, sha256=sha(ROOT / p), change=action, readers=reader,
         occurrences=occurrences(p, lambda _, a=action: a))
    for p, action, reader in metadata]

core = {r['path'] for key in ['testdata', 'testFiles', 'diagnostics'] for r in data[key]}
core.update(data[k]['path'] for k in ['registry', 'text'])
core.update(t.split('::')[0] for h in data['hashProposals'] for t in h['targets'])
assert len(core) == 68
core.update(r['path'] for r in data['documentExamples'])
assert len(core) == 74
all_paths = core | {r['path'] for r in data['relatedVersionFiles']}
assert len(all_paths) == 85
raw = (V / 'v10.1bb-version-grep.log').read_text()
groups = {}
for line in raw.splitlines():
    p, n, text = line.split(':', 2)
    groups.setdefault(p, []).append(int(n))
classified = []
for p, lines in groups.items():
    if p in all_paths:
        kind = '一覧の候補（同一ファイル内の保持箇所も含む）'
    elif p.startswith('docs/archive/'):
        kind = '保管した過去の文書。保持'
    elif p.startswith(str(V.parent.relative_to(ROOT)) + '/'):
        kind = '今回の改造の入力・結果・レビュー・計画の記録。過去の状態を保持し一括置換しない'
    elif p == 'CHANGELOG.md':
        kind = '過去の版の変更記録。保持。新しい版の事実の追記はV10.3a'
    else:
        raise AssertionError('分類していない候補: ' + p)
    classified.append(dict(path=p, lines=lines, classification=kind))
data['counts'] = dict(testdata=50, integrationTestFiles=5, sourceTestFiles=5,
                      testFiles=10, registryAndText=2, testsRegistryAndText=12,
                      diagnostics=4, hashProposals=3, hashTargets=4,
                      uniqueRewriteFilesBeforeDocuments=68, documentExampleFiles=6,
                      uniqueRewriteFiles=74, relatedVersionFiles=11,
                      totalReviewFiles=85, exclusionRows=8,
                      grepFiles=len(groups), grepLines=len(raw.splitlines()))
data['supplement'] = dict(task='V10.1bb', addedTestFile=path,
                         command="git grep -n -E '0\\.0\\.12|0, 0, 12'",
                         raw='v10.1bb-version-grep.log', rawSha256=sha(V / 'v10.1bb-version-grep.log'),
                         classification='v10.1bb-version-grep.json',
                         initialGenerator='make-inventory.pyは初稿用。本追補はv10.1bb-inventory.pyで加える')
(V / 'j2-rewrite-inventory.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
(V / 'v10.1bb-version-grep.json').write_text(json.dumps(dict(
    base=data['base'], command=data['supplement']['command'], exit=0,
    files=len(groups), lines=len(raw.splitlines()), rawSha256=data['supplement']['rawSha256'],
    classifiedFiles=classified), ensure_ascii=False, indent=2) + '\n')

md = (V / 'j2-rewrite-inventory.md').read_text().split(MARKER)[0]
md += MARKER + '\n上の表と件数は初稿の記録として残す。以後はこの追補とJSONの `counts` を使う。'
md += '初稿のJSONの件数は `firstDraftCounts` に残し、`testFiles` へ漏れていた1ファイルを追加した。\n\n'
md += '指定の `git grep -n -E \'0\\.0\\.12|0, 0, 12\'` は終了0、955ファイル・2,611行であった。'
md += 'エスケープした宣言にも一致する。[生出力](v10.1bb-version-grep.log)と[全ファイルの分類](v10.1bb-version-grep.json)を保存した。'
md += '検索の一致行数を、編集する宣言の数やファイル数と混同しない。\n\n'
md += '| 区分 | 初稿 | 追補後 |\n|---|---:|---:|\n'
for label, before, after in [
    ('testdata', '50', '50'), ('テスト内の版文字列', '統合5・src内4、計9', '統合5・src内5、計10'),
    ('登録・文言を加えた区分全体', '11', '12'), ('診断期待値', '4', '4'),
    ('依存ハッシュ', '3組・変更先4か所', '3組・変更先4か所'),
    ('文書の例を加える前の重複を除く対象', '67', '68'), ('文書の例', '未計上', '6'),
    ('文書の例を含む重複を除く書き換え候補', '67', '74'),
    ('関連する版・固定参照・訳元の表示（保持判断を含む）', '未計上', '11'),
    ('上記全体の重複を除く確認・編集候補', '67', '85'), ('既存の一括置換からの除外', '8行', '8行')]:
    md += f'| {label} | {before} | {after} |\n'
md += '\n### テストと登録・文言への追加\n\n| パス | 変更案と読者 |\n|---|---|\n'
md += f"| `{path}:920` | {addition['reason']}。{addition['readers']} |\n"
md += '\n### 文書の例\n\ninlineの過去の宣言も含めて区分した。宣言の更新・保持は次表の案であり、この作業では入力を変更していない。\n\n'
md += '| パス・行 | 読むテストと確認範囲 | V10.3aへの案 |\n|---|---|---|\n'
for row in data['documentExamples']:
    at = '、'.join(map(str, row['declarationLines'])) if row['declarationLines'] else 'inlineの旧版の宣言はJSON参照'
    md += f"| `{row['path']}`（{at}） | {row['readers']} | {row['change']} |\n"
md += '\n01-02の版の診断を失敗に含めない点は読解で確定するが、版上げ後の実行は本追補で行っていない。'
md += '正常な現在版の例として宣言を更新し、V10.3aで `spec_examples` の結果を確かめる。検査器を拡張する案ではない。\n'
md += '\n### 検索で拾った関連する版・固定参照・訳元の表示\n\n'
md += '上の74ファイルと重ならない11ファイルである。現行版へ更新する表示と、意味を確認して保持できる固定参照を区別した。'
md += '文書の例の6ファイル内の現在版表示・過去の節は、前表とJSONの全出現へ含めた。\n\n'
md += '| パス | V10.3aでの更新・保持の案 | 読者 |\n|---|---|---|\n'
for row in data['relatedVersionFiles']:
    md += f"| `{row['path']}` | {row['change']} | {row['readers']} |\n"
md += '\nその他の一致は保管済み文書37ファイル、今回の改造の記録834ファイル、過去のCHANGELOG 1ファイルである。'
md += 'これらを版上げの一括置換へ含めない。候補内での保持箇所も全出現と変更案に記した。\n'
(V / 'j2-rewrite-inventory.md').write_text(md)
print(json.dumps(data['counts'], ensure_ascii=False))
