# M2a 最終の移行一覧と適用順

## 基準と確認表の読み方

開始時の HEAD は `42dffe1098f1086112ecf3f1d41c9f6fb377efbf`、ブランチは `mod254/M2a`、作業ツリーに差分はなかった。[P1](../p1/inputs.md) と [M1](../m1/inputs.md) の全候補を、このツリーの追跡6,260項目へ再照合した。追跡する通常ファイル6,254件は元のバイト列で検索し、ディレクトリへのシンボリックリンク6件はリンクとして列挙した。無視された docs/todo と reference の内容を移行の対象に加えていない。

本書と [inputs.json](inputs.json) が M2b の確定した確認表である。M2a では処理系、通常入力、公開文書、版、固定ハッシュ、生成物を変更しない。JSON はこの作業の一覧であり、CLI の公開形式や移行を自動適用するための承認 manifest ではない。

JSON の `files` はファイルごとの分類と理由のキーを持つ。`edit` の73件には元のファイル全体の `baseSha256`、編集位置または厳密な置換対と件数、実施する処置を載せた。行番号は基準の LF 区切りの1始まりであり、編集後の位置ではない。`replacements` は通常の宣言等に限り、負の版境界や prose の一律置換には使わない。固定ハッシュの変更は、通常入力の置換とは別に `hashPairs` を適用する。各組に影響元の全バイト列、相対パス、個別のハッシュ、集約する行、現在値と予定値を載せた。

検索は P1 の版・language・ハッシュ・環境設定の四系統を保ち、裸の64桁の十六進数と `benitoite test` fence を補助検索に加えた。パターンは JSON の `searchPatterns` に保存した。検索一致と再生成対象を合わせた994ファイルを全件分類し、未分類は0件である。検索一致には `127.0.0.1`、`FIELD_` 等の識別子、説明文、Wasm のバイト列も含むので、一致件数を変更件数とは扱わない。

| M2b の処置 | ファイル数 | 確定した範囲 |
|---|---:|---|
| 手で編集 | 73 | 通常の testdata 50件と下表の23件。版・負の期待値・正の固定ハッシュを一単位で更新 |
| 生成元から再生成 | 56 | grammar、diagnostics、stdlib 53件、bundle.rs。各パスは JSON の generate に全件列挙。生成結果が同じなら差分不要 |
| 手書き Skill を保持して照合 | 5 | SKILL.md、common-mistakes、idioms、inspection、language-comparison。固定の0.0.6宣言はなく、placeholderを維持 |
| 後の作業へ引き渡し | 7 | 日本語リファレンス2件はM3a、既存Skill訳4件はM3b、回答文1件はM3b/F2で再採取。inspectionの新訳もM3bへ渡す |
| その他を保持 | 853 | 履歴671件、構文専用5件、固定・合成版6件、動的な版4件、既存の入力・設計・処理・道具等。理由と全パスはJSON |

上表の7件は既存ファイルだけの数であり、新しい日本語 inspection.md は含まない。版の更新後も tags や公開済みのリリースの存在を推定しない。

## M2b で編集する23ファイル

パスはリポジトリの根からの相対パスである。通常の testdata 50件は後の独立した表に示す。

| ファイル | 基準の編集位置 | 処置 |
|---|---|---|
| `CHANGELOG.md` | 5, 7, 11, 14 | Unreleasedを0.0.7 (San Benito)へ改題。予定表現を提供時点へ直しソースのみの版と明示。0.0.6以前の履歴を保持。 |
| `Cargo.lock` | 60 | name=benitoiteの自身の版だけ更新。依存のchecksumと解決結果を保持。 |
| `crates/benitoite/Cargo.toml` | 3 | 自身の公開版を一度だけ更新。 |
| `crates/benitoite/src/cli/tools/package/tests.rs` | 36, 40, 91, 95 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。動的な版と他の契約は保持。 |
| `crates/benitoite/src/external/tests.rs` | 1612, 1754, 1778 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。動的な版と他の契約は保持。 |
| `crates/benitoite/src/modules/hash.rs` | 221, 222 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。正の固定ハッシュもhashPairsに従い更新。 |
| `crates/benitoite/src/modules/tests.rs` | 32, 33, 66, 69, 71, 72, 75, 87, 872, 892, 916, 922, 928, 1001, 1036, 1072, 1076, 1111, 1147 | 実版の境界表・主文・全notes/helpsを入力別に更新。872行以降の通常宣言11件は0.0.7へ。ゼロの負のhashは保持。詳細はinputs.md。 |
| `crates/benitoite/src/typeck/pattern_ext.rs` | 865 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。動的な版と他の契約は保持。 |
| `crates/benitoite/testdata/packages/dependency-settings.diag.json` | 3 | 未来99.0.0の入力・診断コード・位置を保持し、主文の実際の処理系の版だけ更新。 |
| `crates/benitoite/testdata/packages/hash-match/package.bnt` | 3 | hashPairsのhashkitの新しい正の固定値へ。入口にはlanguageを追加しない。 |
| `crates/benitoite/testdata/packages/newer-config.diag.json` | 1 | 未来99.0.0の入力・診断コード・位置を保持し、主文の実際の処理系の版だけ更新。 |
| `crates/benitoite/testdata/packages/newer-language.diag.json` | 1 | 未来99.0.0の入力・診断コード・位置を保持し、主文の実際の処理系の版だけ更新。 |
| `crates/benitoite/testdata/packages/older-language.diag.json` | 1 | 0.0.4の入力と既存0.0.5/6の全文を保持。0.0.7のnote/helpを各配列の末尾へ一件ずつ追加。主文・位置・edits:[]を保持。 |
| `crates/benitoite/tests/cli_process.rs` | 590 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。動的な版と他の契約は保持。 |
| `crates/benitoite/tests/desugar_export/named.rs` | 589, 594 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。動的な版と他の契約は保持。 |
| `crates/benitoite/tests/package_command.rs` | 18, 114, 192, 219, 274, 275, 400, 405, 407, 452, 463 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。正の固定ハッシュもhashPairsに従い更新。 |
| `crates/benitoite/tests/spec_examples.rs` | 454 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。動的な版と他の契約は保持。 |
| `crates/benitoite/tests/test_command.rs` | 1395, 1402, 1905, 1916 | 通常入力とその厳密な期待値の0.0.6を0.0.7へ。動的な版と他の契約は保持。 |
| `docs/design/01-spec/01-02-syntax.md` | 454 | 通常のヘッダ例の宣言を0.0.7へ。構文とfenceの種類を保持。 |
| `docs/design/01-spec/01-03-names-modules.md` | 278 | 既存0.0.5/6の変更の後に0.0.7の互換性の変更を追記。CLIやJSONの実装事情は書かない。 |
| `docs/design/06-tooling/06-09-packages.md` | 20, 32, 41 | 二つの通常宣言を0.0.7へ。既存の互換性表へ0.0.7を追加。 |
| `docs/reference/benitoite.md` | 16, 100, 158, 1319, 1331, 1349, 1381, 1392 | 現行版、version JSON例、三つの通常宣言、版境界、ソースのみの提供範囲を0.0.7へ。公開タグの実在は主張しない。 |
| `docs/reference/install.md` | 3, 31, 38, 44, 56, 57, 59, 65, 199 | 現行版、配布名・展開名の例、version表示、ソースのみの提供範囲を0.0.7へ。バイナリ提供済みとは書かない。 |

CHANGELOG.md の見出しは `## Unreleased` から `## 0.0.7 (San Benito)` へ改める。冒頭の「実装はまだ0.0.6」と予定の表記を提供時点の説明へ直し、ソースのみの提供という状態を明記する。新しい節の旧0.0.6からの移行例や、0.0.6以前の履歴は残す。六機能、全 formats、E0512、テスト全体の非実行、二接頭辞全体・ASCIIの大小・空値・同値上書き・LD_RUN_PATH・InvalidInput・継承の扱いを省かない。

### 実版に依存する負の検査の変更

`src/modules/tests.rs::language_versions_check_the_release_boundary_in_each_header_location` は entry/config/dependency の三つの場所に、次の同じ表を適用する。0.0.6の行を削って0.0.7へ移すだけでは、直前の版の拒否を失うため、0.0.6の負例も残す。無宣言の通常入力は引き続き現行規則で検査する。

| 宣言 | M2b 後の結果 | 主文で示す版 | notes/helps の対象と順 |
|---|---|---|---|
| 0.0.0、0.0.3、0.0.4 | E0908 | 最初の変更0.0.5 | 0.0.5、0.0.6、0.0.7 |
| 0.0.5 | E0908 | 最初の変更0.0.6 | 0.0.6、0.0.7 |
| 0.0.6 | E0908 | 最初の変更0.0.7 | 0.0.7 |
| 0.0.7 | 成功 | なし | 診断なし |
| 0.0.8 | E0907 | 要求0.0.8、処理系0.0.7 | notes/helps は空 |

0.0.6の追加に合わせ、先頭の変更を選ぶ分岐と notes/helps の開始位置も三段階にする。既存の主文・位置・notes全体・helpsの件数と全文・各 edits が空であることの assert は同じ厳密さで残す。未来版の主文は全文で `this file needs Benitoite 0.0.8 or later, but this is Benitoite 0.0.7` と比較する。旧版の主文は `this file was written for Benitoite {宣言版}, and the language changed incompatibly in {最初の変更版}` の全文である。

0.0.7について追加する note は、次の一行の全文である。

```text
0.0.7: Command.environment rejects names starting with DYLD_ or LD_ (ASCII case-insensitive), including build-tool variables such as LD_RUN_PATH
```

対応する help の message は次の一行の全文とし、edits は空のままとする。既存0.0.5/6の説明を上書きしない。

```text
review explicit settings of DYLD_ and LD_ variables, including LD_RUN_PATH used by build tools; run and runAttached return IOErrorKind.InvalidInput before starting a child; inherited variables are unchanged; update the language declaration to 0.0.7 after reviewing the script, update dependency hashes, and see the 0.0.7 section of CHANGELOG.md for migration details
```

older-language の golden は入力の0.0.4・主文・位置を保持し、既存 notes/helps の末尾へ上の一件ずつを追加する。未来99.0.0の三つの golden は、主文の実際の処理系の版だけを0.0.7へ直す。JSON Linesのkindやcode、終了状態2、診断の件数を緩めない。

### 通常の testdata 50件

全件で `language "0.0.6"` を `language "0.0.7"` へ一件だけ置き換える。M1/P1の50件とパス・行が一致することを確認した。別の誤りを検査する入力も、正常な版の準備を更新して同じ拒否理由まで到達させる。

| ファイル（crates/benitoite/testdata/からの相対パス） | 行 |
|---|---:|
| `external/self-package-outside/package.bnt` | 1 |
| `external/self-package/package.bnt` | 1 |
| `packages/alias-only/deps/textkit/package.bnt` | 1 |
| `packages/config-declaration/package.bnt` | 1 |
| `packages/config-textkit/deps/textkit/package.bnt` | 1 |
| `packages/copied-textkit/Textkit/package.bnt` | 1 |
| `packages/d6c-extensible-external/package.bnt` | 1 |
| `packages/d6c-extensible-missing/package.bnt` | 1 |
| `packages/d8-extensible-run/package.bnt` | 1 |
| `packages/d8-extensible.files/dep/package.bnt` | 1 |
| `packages/dependency-collision/deps/textkit/package.bnt` | 1 |
| `packages/dependency-config-declaration/deps/textkit/package.bnt` | 1 |
| `packages/dependency-no-block/deps/textkit/package.bnt` | 1 |
| `packages/dependency-root-import/Textkit/package.bnt` | 1 |
| `packages/dependency-root-overlap/package.bnt` | 1 |
| `packages/dependency-settings/deps/transitive/package.bnt` | 1 |
| `packages/distinct-modules/deps/textkit/package.bnt` | 1 |
| `packages/extensible.files/dep/package.bnt` | 1 |
| `packages/hash-match/deps/hashkit/package.bnt` | 1 |
| `packages/header-overlap/deps/textkit/package.bnt` | 1 |
| `packages/header-overlap/main.bnt` | 3 |
| `packages/header-overlap/package.bnt` | 1 |
| `packages/header/deps/textkit/package.bnt` | 1 |
| `packages/header/main.bnt` | 3 |
| `packages/imported-header/Helper.bnt` | 1 |
| `packages/imported-header/deps/textkit/package.bnt` | 1 |
| `packages/libraries.files/fuzzy/package.bnt` | 1 |
| `packages/libraries.files/json-checks/package.bnt` | 1 |
| `packages/libraries.files/pure-json/package.bnt` | 1 |
| `packages/libraries.files/textkit/package.bnt` | 1 |
| `packages/libraries.files/wasm-hash/package.bnt` | 1 |
| `packages/libraries.files/wasm-json/package.bnt` | 1 |
| `packages/libraries.files/wasm-regex/package.bnt` | 1 |
| `packages/local-textkit/deps/textkit/package.bnt` | 1 |
| `packages/package-as-root/package.bnt` | 1 |
| `packages/package-dependencies/deps/textkit/package.bnt` | 1 |
| `packages/package-dependencies/package.bnt` | 1 |
| `packages/package-error/deps/textkit/package.bnt` | 1 |
| `packages/package-header/deps/textkit/Slug.bnt` | 1 |
| `packages/package-header/deps/textkit/package.bnt` | 1 |
| `packages/package-isolation/deps/other/package.bnt` | 1 |
| `packages/package-isolation/deps/textkit/package.bnt` | 1 |
| `packages/package-private-name/deps/textkit/package.bnt` | 1 |
| `packages/package-visibility-hidden/deps/textkit/package.bnt` | 1 |
| `packages/package-visibility-run/deps/textkit/package.bnt` | 1 |
| `packages/package-warning/deps/textkit/package.bnt` | 1 |
| `packages/root-config/deps/textkit/package.bnt` | 1 |
| `packages/root-config/package.bnt` | 1 |
| `packages/root-fallback/deps/textkit/package.bnt` | 1 |
| `packages/todo-handler/deps/todo/package.bnt` | 1 |

## ハッシュの独立計算と適用順

パッケージの集約ハッシュは、対象の相対パスをUTF-8のバイト順で並べ、各ファイルの `SHA-256の小文字十六進 + 半角空白二つ + 相対パス + LF` を連結し、その全体をさらにSHA-256にする。走査する下位ディレクトリは大文字で始まるものと、根のwasmおよびその配下である。隠し項目等の除外規則も modules/hash.rs と照合した。含めるファイルは .bnt、.wasm、LICENSE/COPYING/README で始まる名前のものであり、標準ソースや診断報告の単一本文のハッシュとは区別する。

三組とも Python hashlib で現在値との一致を確認し、予定値も独立に計算した。予定の変更は各組の package.bnt の宣言を0.0.6から0.0.7に変える一件だけである。CRLF・非UTF-8・空行・末尾改行を正規化しない。予定値は本書の条件に対する値であり、M2bが入力を変更したら入力を再確定して計算し直す。

| 組と固定値の所在 | 含める全相対パス |
|---|---|
| hashkit: testdata/packages/hash-match/package.bnt:3 | Value.bnt、package.bnt |
| modules-hash-fixture: src/modules/hash.rs::FIXED | A/Sub.bnt、COPYING、License.md、Z.bnt、package.bnt、readme.md、wasm/x.wasm |
| package-command-words: tests/package_command.rs:114 | Value.bnt（READ）、package.bnt（CONFIG）。根のmain.bntは依存の外なので含めない |

上表のRustのパスは crates/benitoite/ からの相対パスである。hashkit の影響元は testdata/packages/hash-match/deps/hashkit/ の二件である。modules の Z.bnt は `61 62 63 0d 0a`、wasm/x.wasm は `00 61 73 6d ff` のまま含める。

| 組 | 現在の値 | 変更後の予定値 |
|---|---|---|
| hashkit | `sha256:20e42f7da076ce5bd11f6f4a7b433f956e8f73e98f58cd279c8dc2aafbe09393` | `sha256:5d12e17f6e1522ec49837e741d7b5a28145b94f6aa6ab95c6b72b683c534dd65` |
| modules-hash-fixture | `sha256:3b02e3120f7e20f1c82b7c70dae26848f301edbb5988602795002a20d5c8b9b5` | `sha256:dfa96801c59264be45ff137fedbfd84bf176c3941b66c751cadbca0692c82fec` |
| package-command-words | `sha256:0e03d3fd2ac72afce915d04f076536efd301078c8e9f416bceb6b6f80b2219c7` | `sha256:ec9bf643e50197c98e9aa736bb08ef612cf253cb682ef4936f800cf57dacbbed` |

適用順は次のとおりとする。M2b全体が一回の版の更新であり、途中の状態を別の取り込み単位にしない。

1. 編集前に本書と JSON の基準を照合する。差があれば対象と分類を再確認する。Cargo.toml とルートCargo.lockの自身の版、通常入力、文書の生成元、CHANGELOGを同じ作業で0.0.7へ更新する。Cargo.lockの無関係な再解決を行わない。
2. 旧版・現在版・未来版の境界と全診断の期待値を上表へ合わせる。旧0.0.6を残す必要がある負例と、合成のcurrentを固定したテストを一律置換しない。
3. ハッシュに入る入力の全バイト列を確定してから上のアルゴリズムで独立計算する。hashkitは依存の設定の後に親のhashを直す。modulesのFIXEDとCONFIG、package_commandの固定値と生成入力・stdout・書き込み結果の厳密な期待を一緒に更新する。後者の共有hash変数の利用先も残す。
4. 生成元の編集後に `cargo run -p benitoite --example gen_skill` を実行する。grammar、diagnostics、stdlib、bundle.rsは手で直さない。HAND_WRITTENの5件とライセンス2件を合わせた62件の構成を維持し、二回目の生成で差が増えないことを確かめる。SKILL.mdのplaceholderを実版に固定せず、list/show/installが置換した同じ本文の長さ・ハッシュをCLIから取得する。
5. 全追跡ファイルを再検索して通常入力の0.0.6の取り残しが0件であることを確かめる。本書の保持する例を除いて判定する。指定の文書テストと関連テストを実施し、gc-stressと共通のcheckはオーケストレータへ渡す。
6. M3a/M3bで訳を英語正へ合わせる。M3b/F2で最終ビルドの回答例のproducer・build・byteLength/contentHashとsource hashを再採取する。過去のd3/z6の採取記録を改変しない。

独立計算の再確認は、リポジトリの根で次を実行できる。これは確認表の検算であり、M2bの編集や本番のハッシュ関数を呼ばない。

```sh
python3 - <<'PY'
import hashlib
import json
from pathlib import Path

path = Path('docs/2026-10-17-TODO-254-harness-check-interface/m2a/inputs.json')
record = json.loads(path.read_text())
for pair in record['hashPairs']:
    members = sorted(pair['members'], key=lambda item: item['relativePath'].encode('utf-8'))
    for kind, bytes_key in [('current', 'currentBytesHex'), ('planned', 'plannedBytesHex')]:
        summary = b''
        for item in members:
            body = bytes.fromhex(item[bytes_key])
            digest = hashlib.sha256(body).hexdigest()
            assert digest == item[kind + 'Sha256']
            summary += (digest + '  ' + item['relativePath'] + '\n').encode('utf-8')
        assert summary.decode('utf-8') == pair[kind + 'Summary']
        assert 'sha256:' + hashlib.sha256(summary).hexdigest() == pair[kind]
    for item in members:
        current = bytes.fromhex(item['currentBytesHex'])
        planned = bytes.fromhex(item['plannedBytesHex'])
        expected = current.replace(b'language "0.0.6"', b'language "0.0.7"') if item['relativePath'] == 'package.bnt' else current
        assert planned == expected
    print(pair['name'], pair['planned'])
PY
```

## 保持する入力・値と後続の担当

| ファイル・対象 | 保持する理由・確認した範囲 |
|---|---|
| src/modules/package.rs、src/modules/text.rs | M1の0.0.7登録と既存0.0.5/6の説明を保持。合成のcurrent=0.0.6/7、宣言0.0.0/3/4/5/6/7/8、逆順の注入表、不正な版、桁あふれは固定した別の契約 |
| src/syntax/parser/header.rs、src/cli/tools/formatter/tests.rs、tests/fmt_command.rs、testdata/fmt/header.bnt・header.formatted | 構文・整形だけの0.0.2/5/6。旧版の綴り自体と位置・出力を保持 |
| src/modules/tests.rs:100、testdata/packages/hash-mismatch/main.bnt、同.diag.json、src/modules/hash.rsの欠落入力 | ゼロのhashはpath欠落、意図した不一致や読み込みの失敗を検査する。正の固定値に直さない |
| src/cli/tools/package/tests.rs・src/syntax/parser/header.rsのa/b等のhash文字列 | ヘッダ編集や構文の契約。元の文字列を保ち、内容一致のハッシュとして再計算しない |
| tests/test_command.rs:2008/2065の単一本文SHA-256 | `14c52fc2838594adb45ee1ec151457617d8e5ed2347dbb1ba70d6570ced86307` を独立計算して一致。元の本文にlanguage宣言はなく不変。JSONのunchangedSingleSourceHashへ全バイトを保存 |
| tests/runtime_builtins.rs | 固定版とlanguage宣言なしを再確認。Rustの生文字列・format生成入力も検索し、M2b/F1の全ターゲットの検査から外さない |
| tools/skill-eval/tasks/*/reference.bntの全11本 | 全パスと元のSHA-256はJSONに列挙。固定language宣言・禁止接頭辞の明示設定なし。LC_ALL、SKILL_EVAL_HTTP_BASE、shellの通常入力を保持。LLMを呼ぶ評価を行わない |
| tools/benchの入力・ハーネス、WasmのREADME・バイナリ・THIRD-PARTY・別Rustクレートのlock | 入力やバイナリの内容が変わらないハッシュを保持。IP、OS設定、測定メタデータを版やCommand.environmentの入力と混同しない |
| process.rs・process/external_tests.rs、testdata/io/l40-process-environment.bnt、tests/l10_console_clock_process.rs・l13_external_commands.rs | E1で接続した拒否・非起動・継承と、通常の環境操作を保持。負例の禁止名を普通の変数へ変えない |
| build.rs、tests/build_info.rs、src/cli/build_info.rs、既存BENITOITE_DEV_* | ビルドの入力や既存の開発用経路。probe自身の0.0.0と動的なCARGO_PKG_VERSIONを保持。親の環境を変更しない |
| Skillの版キー・placeholder、tests/skill_docs.rs、src/cli/tools/skill/tests.rs | metadataの識別・負例の`1`/`benitoite-versions`・実版による置換の契約を保持 |
| docs/design/06-tooling/06-01-cli.md:72–73 | 0.0.6で導入した既存診断/testResults形式の説明。現行producerの版を示す例ではないため保持 |
| src/diag/codes.rs、改名のgolden、初回版を説明するAGENTS・設計目次・ロードマップ・用語集・配布・formal README | 改名0.0.1・書式例0.0.3・初回の公開・過去の不具合等の事実を保持。現在版の通常入力へ置換しない |
| docs/archive、reference、測定results、tools/syntax-measure、benitoite-minimal.md、archive-and-bundleの例 | 読み取り専用の過去資料・比較の入力・既存タグ。原文と観測時の値を保ち、現在の実装の根拠にしない |
| fuzz/Cargo.toml・fuzz/Cargo.lock、旧移行器の基準データ | 別クレート自身の版と既知の旧lock・既存の残件。勝手に再解決・修復しない |
| 今回のrequest・answers・study・各results・d3/z6のcli-observations.json | 検討と実測の記録を保持。将来版の契約例と過去の実出力を区別。harness-response.mdの実出力例だけはM3b/F2で再採取 |
| docs/ja/reference/benitoite.md・install.md | M3aで版・例・CLI・表・配布の現実を英語正へ合わせる |
| docs/ja/skill/SKILL.md・references/common-mistakes.md・idioms.md・language-comparison.md | M3bで英語正へ合わせ、references/inspection.mdを新規翻訳。R29の分割と62件の埋め込みの説明を揃える。訳をSkillに含めない |

上表のsrc/tests/testdataのパスは crates/benitoite/ からの相対パスである。ファイル単位で通常入力と負例が混在する場合は、JSONのedit.actionと本書の負の検査の表を優先し、ファイル全体を保持扱いや一律置換にしない。

### 実行用の benitoite test fence

次の8件は記法だけの例として除外しない。固定の旧い宣言の取り残しはなく、M2bのreference_examples/skill_examples/skill_docsで英語の4件を含む例を検査し、日本語の4件はM3a/M3bで対応を照合する。ラベルと期待結果を保持する。

| ファイル | 開始行 |
|---|---|
| `crates/benitoite/skill/SKILL.md` | 159 |
| `crates/benitoite/skill/references/idioms.md` | 635, 649 |
| `docs/ja/reference/benitoite.md` | 947 |
| `docs/ja/skill/SKILL.md` | 155 |
| `docs/ja/skill/references/idioms.md` | 634, 648 |
| `docs/reference/benitoite.md` | 1077 |

M2bの検査は plan の K-R と関連9統合テスト、gen_skill、両構成のall-targetsを基準とする。今回の依頼で禁止されたcheck.sh/gc-stressは実行せず、オーケストレータが最後に実施する。個別の既定構成の成功を段末・G7・公開の完了へ読み替えない。
