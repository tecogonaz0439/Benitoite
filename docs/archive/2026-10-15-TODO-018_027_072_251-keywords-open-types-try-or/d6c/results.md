# D6c 属性の受理と網羅性への接続

## 目的と変更

`@extensible` を data/record 宣言で受理し、宣言の属性から `AdtDef.extensible` を設定する。D6a の判定と D6b の交換出力は、この指定を同じ型表から受け取る。構成子前の属性を解析する経路は追加しない。

| ファイル | 変更 |
|---|---|
| `src/syntax/parser/items.rs` | 属性名・引数・適用先の検査。公開範囲、空括弧、重複、別名・外部型・定数への拒否、宣言なしの属性、構成子前の拒否を検査 |
| `src/typeck/decls.rs` | data/record の属性を型表へ反映 |
| `src/diag/codes.rs` | E0817 と引数を除く help を追加。E0801 の属性一覧と E0802 の説明を更新 |
| `src/cli/tools/formatter/tests.rs` | 既存のテストに、空括弧を保つ整形の例を追加 |
| `testdata/` | 属性の正負、同一パッケージと外部の data/record 照合、レコードの更新・getter の正の入力を追加。既存の E0801 は help の属性一覧だけを更新 |
| `tests/coverage_export.rs` | ソース属性から作った型表と view を独立した coverageDiff にも渡す。作者・外部の data/record 4 件と未使用の指定を追加し、既存の乱択入力を維持 |
| `tests/desugar_export/named.rs` | ソース由来の指定が未使用の型を含めて型表・本体の view・網羅性出力へ残ることを検査 |
| `tests/desugar_export/{exchange-manifest,routing-manifest}.json` | 追加した 6 入力と独立したソース由来の網羅性 4 件の識別・分類・件数を固定。既存入力の分類と対象外理由を維持 |
| 01-02・01-05・02-05・01-12・07-04 | 属性の文法・使用条件・パッケージ境界と実装済みの接続を反映。属性の構文検査は形式化の対象外として明記 |
| `src/cli/tools/skill/generate.rs`、`skill/SKILL.md`、`skill/references/common-mistakes.md`、Skill の生成物 | 未受理の説明を訂正して再生成（R39） |
| `CHANGELOG.md`、`decisions.md` | 属性と診断の変更、R39 の補足を記録 |

`src/`・`testdata/`・`tests/`・`skill/` は `crates/benitoite/` の下を指す。Lean の定義・定理と標準ライブラリの属性は変えていない。コミットと docs/todo の変更は行っていない。

## test-audit の作成時の関門

1. 構文解析の公開結果、CLI の診断と終了状態、整形の公開結果、形式化への交換出力を境界とする。受理した属性を必ず型表へ反映し、作者の照合を保ち、外部の照合に将来の形を要求する契約を守る。
2. 属性だけを受理して型表への反映を落とす退行、record の指定漏れ、引数と位置の二重診断、構成子前の属性を誤って受理する変更、未使用の型を交換出力から落とす退行を捕まえる。
3. D6a の独立入力は型表を直接設定しており、ソース属性の接続漏れを検出できない。構文の負の入力と整形は既存の表・テストへ追加し、CLI と交換出力の固有の契約を追加入力で確かめる。既存の assert・期待値・ignore と裸の try の検査は維持する。
4. 本番の公開範囲・フラグ・差し込み口は追加しない。本物の parser、型検査、脱糖、書き出しを使う。新機能の実装であり、既存の不具合の修正ではない。

## 診断の対応

主文と help は英語のまま codes.rs に置く。新しい入力の期待診断は個別に内容を確認した。golden の一括再生成はしていない。

| 入力・変更 | 旧 → 新 | 主位置・副位置・help・終了状態 | 元の誤りの維持先 |
|---|---|---|---|
| 未知の属性 | E0801 → E0801。主文は同じ | 属性名、既存の help 一覧へ `@extensible` を追加、終了 1 | `syntax/c11-attribute-unknown` |
| 文字列引数付き `@extensible` | 未知の属性 E0801 → E0817、`@extensible` takes no arguments | 属性全体、副位置なし、remove the arguments from `@extensible`、終了 1 | `syntax/d6c-extensible-arguments`、parser の表 |
| 非文字列引数 | 未知の属性 E0801 → E0220、既存の文字列引数の主文 | 不正な引数、既存の plain help、終了 1 | 同上。既存の deprecated の負の入力も維持 |
| 重複 | 未知の属性 → E0803 | 二度目の属性、最初の属性の副位置、除去の edit、終了 1 | 同上。既存の test の重複の assert も維持 |
| 不適切な宣言への適用 | 未知の属性 E0801 → E0802 | 属性全体、副位置・help なし、終了 1。引数にも誤りがあれば引数の診断だけ | 同上、parser の表 |
| 構成子前・宣言なし | E0201 を維持（宣言なしでは未知の属性の診断は不要になる） | 不正な字句または EOF、終了 1 | `syntax/d6c-extensible-constructor`・`orphan` |
| 外部の全既知構成子・record だけの照合と束縛 | 属性を拒否していた入力 → E0601/E0607 | 既存の対象式/パターンの主位置、将来の形の反例、型の宣言の副位置、変数か `_` を追加する help、終了 1 | `packages/d6c-extensible-missing`。D6a の直接入力の検査も維持 |

指定のない型の E0601/E0607、重複分岐の E0602/E0608、通常の反例の表示と help は変更しない。

## 計画との差と申し送り

R39 として、生成元の固定英文と手書き Skill の未受理の説明も同期した。ほかに意味・公開 API・交換形式の計画変更はない。標準ライブラリの四型への指定は D7、追加の入れ子・束縛・到達可能性の実行確認は D8 の担当のままである。D6 の親の完了確認と G3a のレビューはオーケストレータへ引き継ぐ。

## 検査の結果

`BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/d6c-final BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/d6c-final bash scripts/check-formal.sh` は終了状態 0 で完了した。ログは `/private/tmp/d6c-formal.log`、出力は指定した二つのディレクトリにある。ソース由来の独立入力を追加した後に coverage_export を同じ出力先へ再実行し、その named-corpus の coverageDiff 6 件を確認した。末尾の check_named.py でも更新後の 6 件を含む六入口と manifest が一致した。

| 検査 | 結果 |
|---|---|
| `lake build`（formal/） | 成功、162 jobs。Lean の変更、新しい axiom・sorry・admit・native_decide はない |
| `check-formal.sh` の Rust 書き出し | 網羅性の 2 テストと、全 corpus を含む脱糖の 17 テストが成功 |
| `coverageDiff` | 通常 10,020 件、view 付き 10,016 件、名前付き関数型とソース属性の 6 件が一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden の 348 入力・960 定義、乱択の 1,000 入力・72,778 定義が一致。静的な誤りの 385 入力を分類し、既存の除外理由を維持 |
| `builtinCheck` | summary 72,416 比較、不一致・非収束 0。既存の対象外の組み込みの一覧を維持 |
| `coverageProgramDiff` | 1,348 入力、match 16,409 件・binding 6,035 件、計 22,444 件が一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheck`・`surfaceCheckAll` | 全 1,733 入力の分類と個別検査を照合。51,639 件が一致、既存の対象外 19 件・Q11 1 件を維持。不一致・準備の失敗 0 |
| 交換形式の独立した正負の検査 | width 4 テスト、named 12 テスト、extensible 22 テストが成功。hole/pipe・契約・view の破損入力も意図した理由で拒否 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成元の固定英文の訂正後にも再生成 |
| `cargo test -p benitoite --lib syntax::` | 107 件成功 |
| `cargo test -p benitoite --lib cli::tools::formatter::tests::normalizes_blank_lines` | 成功。空括弧を維持 |
| `cargo clippy --workspace --all-targets` | 最終ツリーで成功、指摘なし |
| `cargo fmt --all --check` | 最終ツリーで成功 |

初回の構文検査では、新しく書いたテストの準備に二つの誤りがあった。非文字列引数の位置を探す文字 `x` が属性名自身にも含まれていたため、正確な引数位置を確かめる専用の入力へ移した。また、外部型の拒否の入力に必要な `@external` を補った。既存の assert は変えていない。整形検査の初回で見つけた差は cargo fmt で揃えた。

Rust の差分は、本番 +13/-5 行、テスト +167/-1 行（単体テストを含み、置換をそれぞれ数える）である。golden の入力・期待値、固定 manifest、文書の差分は別にある。テストの削除と ignore の追加はない。

最終ツリーで次の検査も成功した。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1,160 件成功、既存の ignore 21 件。99.39 秒 |
| `cargo test -p benitoite --test golden --test coverage_export --test desugar_export --test skill_docs --test spec_examples --test skill_examples` | 6 suite 合計 37 件成功、既存の ignore 2 件。96.01 秒。形式化用の ignore は前述の check-formal で実行済み |
| `git diff --check` | 成功 |

最終の Rust・検査入力を固定してから上の lib・統合テスト、Clippy、fmt を実行した。依頼に従い scripts/check.sh（dry-run を含む）と gc-stress は実行していない。
