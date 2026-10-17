# M1 移行の確認表

## 基準と分類

開始時の HEAD は `4051360bdf26f2e76ae98d4a5668d92bc866a801`（`mod254/M1`）であり、作業ツリーに差分はなかった。[P1 の入力の確認表](../p1/inputs.md) を全追跡ファイルへ再照合した。本書は M2a の確定前の一覧であり、M1 では版・通常入力・固定ハッシュを変えない。

P1 と同じく、版（`0.0.*`・`CARGO_PKG_VERSION`・`benitoite-version`）、language、SHA-256、環境設定の四系統で検索した。`git ls-files -z` の対象をバイト列として読み、不正な UTF-8 の検査入力も対象にした。`127.0.0.1` は版ではない。ファイル単位の一律置換はせず、同じファイル内の通常入力と負の検査・過去の説明を区別する。

| 分類 | M1 の判断と後の担当 |
|---|---|
| 通常入力 | 下表の testdata 50件と Rust の合成入力を M2a/M2b で更新。他の誤りを調べる負のテストでも、準備の版を旧版のままにしない |
| 旧版・未来版・不正版の検査 | 拒否の理由を保持。実版に依存する未来0.0.7だけを M2b で0.0.8へ。合成版と不正版は保持 |
| 構文・整形だけの例 | 版の意味を検査しない parser/fmt の例は保持 |
| 生成元 | 英語文書・標準ソース・構文章・診断表を先に確定。M2b の版の変更も生成元へ適用 |
| 生成物 | gen_skill で再生成。手では変更しない。M1 の生成では差分なし |
| 歴史資料・別クレート・別用途 | docs/archive、測定記録、最小版リファレンス、旧構文測定、fuzz、IPアドレス、Wasm のチェックサム等は保持 |
| 今回の契約例・作業記録 | design/harness-response の予定版は保持。過去の実測記録は書き換えず、最終版の実出力を M3b/F2 で採取 |

## 版と合成入力の対応

以下の Rust のパスは `crates/benitoite/` からの相対パスである。行番号は M1 のツリーの位置であり、M2a で内容を再確認する。

| 所在 | 更新または保持の理由・順序 |
|---|---|
| `Cargo.toml:3`、ルート Cargo.lock の benitoite 項目 | M2b で自身の版だけを一回0.0.7へ。依存の再解決を伴わせない |
| `src/modules/package.rs`、`src/modules/text.rs` | M1 で0.0.7の summary/help を登録。既存0.0.5/6の型板と合成の current=0.0.6/7 は保持。M2b でも合成版を実版へ追随させない |
| `src/modules/tests.rs:25` | 実版を使う入口・根の設定・依存の版境界。M2b では0.0.6を E0908、0.0.7を成功、0.0.8を E0907 とし、notes/helps の全文・件数・順と編集なしを保つ |
| `src/modules/tests.rs:872,892,916,922,928,1001,1036,1072,1076,1111,1147` | 通常入力の宣言を M2b で更新。path欠落・重複・依存の包含・循環等の本来の診断へ到達させる。ゼロの不一致ハッシュは保持 |
| `src/modules/hash.rs:221–222` | CONFIG を更新してから FIXED を独立計算。CRLF と非UTF-8の wasm/x.wasm を含める |
| `src/external/tests.rs:1612,1754,1778`、`src/typeck/pattern_ext.rs:865` | 通常の依存・入口の宣言。外部の関数や extensible の検査を E0908 へ変えない |
| `src/cli/tools/package/tests.rs:36,40,91,95` | ヘッダ移動の入力と期待値を一対で更新。BOM・コメント・改行の保持を検査し続ける |
| `tests/package_command.rs:18,192,219,274,275,400,405,407,452,463` | CONFIG・生成文字列・操作後の期待値をまとめて更新。固定ハッシュの影響元は次節 |
| `tests/cli_process.rs:590` | P1 後の C3 で加わった依存 Kit の通常宣言。shell の参照・報告を検査する入力として更新 |
| `tests/test_command.rs:1395,1402,1905,1916` | P1 から位置・件数が変わった通常の設定・依存。探索で除く package.bnt も通常入力に分類し、まとめて更新 |
| `tests/desugar_export/named.rs:589,594`、`tests/spec_examples.rs:454` | 合成の入口・依存パッケージの通常宣言を更新 |
| `src/syntax/parser/header.rs:350`以降、`src/cli/tools/formatter/tests.rs:408`、`tests/fmt_command.rs:479,485`、testdata/fmt/header の二ファイル | 版の意味を検査しない構文・整形の契約。0.0.5/2/6の綴りを保持 |
| `tests/build_info.rs:94`、fuzz/Cargo.toml | 前者は独立した probe クレートの0.0.0、後者は fuzz クレート自身の版。提供版へ置換しない |
| `src/cli/{mod,build_info}.rs`、`src/runtime/report.rs`、`tests/cli_process.rs` の CARGO_PKG_VERSION | 動的な表示・producer・期待値は維持。版の文字列を新たに固定しない |
| `src/cli/tools/skill/{mod,tests}.rs`、`tests/skill_docs.rs:241` | metadata の検出、placeholder、`1`・`benitoite-versions` の負の入力を保持。実版の置換は既存処理へ任せる |
| `src/diag/codes.rs`、改名の golden、過去の0.0.1の説明 | 過去の改名の版と0.0.3の書式例であり、保持 |
| `tests/runtime_builtins.rs` | 再検索でも固定の版・language 宣言なし。更新不要。F1 の全ターゲットの対象からは外さない |

## 負の入力と厳密な期待値

| 所在 | M2b で保つ理由・変更 |
|---|---|
| testdata/packages/older-language/main.bnt | 0.0.4を保持。older-language.diag.json に0.0.7の note/help を追加し、旧項目の全文と版順を維持 |
| testdata/packages/newer-language/main.bnt、newer-config/package.bnt、dependency-settings/deps/future/package.bnt | 99.0.0を保持。対応する三つの .diag.json の実際の処理系の版だけを0.0.7へ |
| package-language-required、header-overlap、config-declaration、dependency-config-declaration、package-header、imported-header | 宣言の必須・重複・場所の拒否を保持。準備の正常版だけを移行し、不要な E0908 の混入を許さない |
| `src/modules/package.rs` の合成表 | 意図して逆順の変更、未来・既適用の除外、変更なし、E0907、主文・位置・全 notes/helps を保持。本番の変更表を使う0.0.6/7の対照も今回追加 |
| 版の不正文字列・桁あふれ、hash の構文用 a/b、意図したゼロの不一致値 | 版や内容の正当性とは別の契約として保持。正の固定ハッシュへ置換しない |

## ハッシュの影響元と適用順

| 期待値の所在 | ハッシュへ含める影響元・現在値 |
|---|---|
| testdata/packages/hash-match/package.bnt | deps/hashkit の package.bnt・ほかの包含対象全件。現在 `sha256:20e42f7da076ce5bd11f6f4a7b433f956e8f73e98f58cd279c8dc2aafbe09393` |
| `src/modules/hash.rs::FIXED` | fixture の package.bnt（CONFIG）・Z.bnt（CRLF）・A/Sub.bnt・License.md・readme.md・COPYING・wasm/x.wasm（`00 61 73 6d ff`）。現在 `sha256:3b02e3120f7e20f1c82b7c70dae26848f301edbb5988602795002a20d5c8b9b5` |
| `tests/package_command.rs:114` | Directory::fixture の deps/words/package.bnt（CONFIG）と Value.bnt（READ）。現在 `sha256:0e03d3fd2ac72afce915d04f076536efd301078c8e9f416bceb6b6f80b2219c7`。add/update の stdout と書き込んだ内容の期待値を一緒に更新 |

1. M2a で通常入力と保持する負の入力を確定する。M2b で版・宣言・生成元の本文をすべて編集し、ハッシュへ入る最終のバイト列を決める。
2. 包含規則に従い対象の相対パスを UTF-8 のバイト順に並べる。各ファイルの SHA-256 の小文字十六進・半角空白二つ・相対パス・LF を連結し、その全体を SHA-256 にする。Python hashlib で独立に計算する。
3. 三組の正の固定値と参照する操作出力・書き込み結果の期待値を同時に更新する。CRLF・非UTF-8の本文を正規化しない。modules/tests.rs の負の値は維持する。
4. gen_skill で生成し、版の置換後の Skill 本文の byteLength/contentHash を提供する CLI で再取得する。これは単一本文のハッシュであり、パッケージの集約ハッシュと計算を混ぜない。
5. M3b/F2 の回答例の producer・build・ソースのハッシュを最終版で再採取する。過去の d3/z6 の採取記録は保持する。Wasm バイナリ、外部の THIRD-PARTY、測定入力のハッシュは対象のバイト列が変わらない限り保持する。

M1 では三組とも入力と期待値を変更せず、上表の現行値が Python hashlib の独立計算と一致することを確認した。ハッシュの更新値は M2a/M2b の最終の入力で計算する。

## 文書・生成物・環境設定の再照合

| 対象 | 更新または保持・担当 |
|---|---|
| docs/design/01-spec/01-02-syntax.md、01-03-names-modules.md、06-tooling/06-09-packages.md | M2b で実版の例・互換性表を更新。M1 は0.0.6の観測可能な規則を変えないため未変更 |
| docs/reference/benitoite.md・install.md | M2b で現在版の説明・language・公開版・配布名を更新。歴史としての0.0.6やソースのみの配布という事実を一律に置換しない |
| Skill の SKILL.md と手書き references | S/D/Z6 の契約・二接頭辞の説明は実装済み。placeholder は保持。inspection.md の追加と参照の移動も照合済み |
| grammar/diagnostics/stdlib、bundle.rs | 生成元を M2b で編集してから gen_skill。M1 は生成して差分なし |
| docs/ja の六組と inspection.md の新しい訳 | M3a/M3b。Z6/R29 の追加文書も対象にする。英語が確定してから訳し、Skill の埋め込みには入れない |
| Markdown の benitoite test fence | 現行8件。Skill/SKILL.mdに1、idioms.mdに2、英語referenceに1、日本語の対応文書に計4。実行用入力として M2a/M2b/M3b で照合 |
| tools/skill-eval/tasks の参照解11本 | language 固定宣言なし。LC_ALL・SKILL_EVAL_HTTP_BASE と shell の入力は通常の契約として保持。禁止接頭辞の明示設定はない。LLM を呼ぶ評価は実施しない |
| tools/bench の実行入力・tools のハーネス | language 宣言の版の更新は不要。ローカルIP、測定メタデータ、OS の環境設定を Command.environment の入力と混同しない |
| process.rs・process/external_tests.rs、Process.bnt、IO.Process.md、install.md、03-07、07-01 | E1/D の二接頭辞・ASCIIの大小・InvalidInput・LD_RUN_PATH・空/同値・継承の説明と入力は移行済み。負の入力を通常の環境名へ変えない |
| testdata/io/l40-process-environment.bnt、l10_console_clock_process.rs、l13_external_commands.rs | 通常の環境の追加/上書き、環境の読み取り、子の非起動の契約を保持 |
| build.rs・build_info・BENITOITE_BUILD_*、BENITOITE_DEV_* | ビルド情報や既存の開発用入力。版の一律置換や親の環境の変更をしない |
| CHANGELOG.md | M1 で Unreleased を新設。M2b で0.0.7へ改題し、冒頭の「実装はまだ0.0.6」の説明と表の予定表記も提供時点へ更新。0.0.6以前の履歴は保持 |
| docs/archive、reference、測定の results、tools/syntax-measure、benitoite-minimal.md、初回版・改名の説明 | 履歴・比較用の資料として保持。現在の実行入力とは区別する |
| fuzz/Cargo.lock、旧移行器の基準データ | P1 の既知の別件を保持。数字だけを直したり依存を再解決したりしない |

P1 の分類から外れる新しい移行対象はない。後から加わった CLI/test の合成入力と inspection.md は、それぞれ通常入力と手書き文書へ分類した。未分類の候補はない。M2a はこの表を最新のツリーへ再照合し、適用対象を確定する。

## 通常の testdata の全パス

次表は `crates/benitoite/testdata/` からの相対パスである。全50件は P1 の末尾の一覧と一致する。全行で現在の宣言は `language "0.0.6"`、担当は M2a/M2b である。

| パス | 行 |
|---|---|
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
