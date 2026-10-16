# D7 四つの失敗型と表示用の宣言

## 目的と変更

`IOErrorKind`・`NetworkErrorKind`・`Json.ParseError`・`Csv.ParseError` に `@extensible` を付けた。構成子・レコードの欄・順序・組み込みの指定・WIT の対応は変えていない。Result・Option と不透明な IOError・NetworkError には指定を加えていない。

Skill の `decl_head` は、属性の AST の位置から `@extensible` だけを取り出して `public` の前に出力する。ほかの属性を含む範囲を一括で切り出さない。gen_skill で生成し直した差分は四型のリファレンス各一行だけである。API の現行の説明を 01-09・03-08 に、宣言抽出の規則を 06-06 に反映した。06-06 に残っていた属性未受理の説明も、D6c の実装に合わせた。

実際に変えたファイルは、四つの `src/prelude/stdlib/*.bnt`、`src/cli/tools/skill/generate.rs`、対応する四つの `skill/references/stdlib/*.md`、`tests/{skill_docs,l21_json,l23_csv,coverage_export}.rs`、`tests/desugar_export/{named.rs,check_named.py}`、`testdata/patterns/d7-stdlib-extensible` の入力と四つの期待値、`tests/desugar_export/{routing,exchange}-manifest.json`、設計書の 01-09・03-08・06-06、本記録と decisions.md である。

## test-audit の作成時の関門

1. 主となる境界は、Skill の公開の生成結果、CLI の golden、既存の Json/Csv の統合テストである。四型の使用条件の表示と、標準ライブラリの外から既知の分解形だけで照合・束縛した場合の診断、ParseError の構築・更新・getter の実行を守る。
2. 属性の出力漏れ・不要な属性の混入、四宣言の指定漏れ、既知の Other を将来の形として扱う退行、組み込みソースの副位置の描画漏れ、生成した getter・更新に外部用の view を誤って適用する退行で失敗する。
3. skill_docs の既存テストは @builtin・本体・非公開関数の除去を検査しているため、その表を拡張した。既存の外部パッケージの golden は利用者のファイルを副位置に使っており、組み込みソースの描画を検査しないため、四型をまとめた golden 一件を追加した。既存の l21_json・l23_csv は解析結果の getter を検査しているため、同じスクリプトへ構築・更新後の欄と元の値の保持の検査を追記した。
4. 本番コードの公開範囲・引数・テスト専用の差し込み口を増やしていない。テストの削除、assert の削除、期待値の緩和、ignore の追加はない。

形式化の書き出しの既存テストにも同じ関門を適用した。守る契約は、ソースの属性・所属から作った view が六入口へ届き、作者側と外部側で正しい判定になることである。標準の二型を出力から落とす、所属を一律に author とする、依存内の view から標準型を落とす退行で失敗する。既存の独立入力を拡張し、公開のパターン検査と実際の書き出しを使うため、本番の差し込み口は不要である。R41 に記した厳密な期待値へ更新し、元の四つのソース由来の判定を維持して四件を追加した。

実装前の `cargo test -p benitoite --test skill_docs declarations_keep_extensible_and_omit_implementation_details` は、IOErrorKind の属性の出力がないため意図どおり失敗した。golden の生成は `BENITOITE_GOLDEN_FILTER=d7-stdlib-extensible BENITOITE_BLESS=1` に限定し、出力の全六件と文章の副位置を確認した。既存の golden の期待値は再生成していない。

## 既存の照合と移行

調査の六件をソースで再確認した。`builtins/funcs/file/resource_tests.rs` の IOErrorKind 二件と `tests/l32_http_client.rs` の NetworkErrorKind 一件には `_` があり、Skill の idioms・01-09 の例・日本語訳の idioms の IOErrorKind 各一件には変数の分岐がある。追加の分岐は 0 件であり、既存の分岐の本体を変更していない。

標準ライブラリのソースには、四型を構成子で分解する match/bind がない。Json.Value の照合は今回の対象ではない。Json/Csv の解析結果の構築と getter の利用を照合の分岐の追加に数えていない。

## 診断の対応

| 入力 | 旧 → 新 | 主位置・副位置・help・終了状態 | 元の誤りの検査の維持先 |
|---|---|---|---|
| IOErrorKind・NetworkErrorKind の全既知構成子（Other を含む）のみの match | 受理 → E0601、主文は既存の `match` 非網羅の文言 | 対象式、各組み込み宣言の型名、将来の形の反例とガードのない変数か `_` を追加する help、終了 1 | 新しい d7-stdlib-extensible の文章/JSON。通常の非網羅の golden は保持 |
| Json/Csv の ParseError のレコードパターンのみの match | 受理 → E0601、同上 | 対象式、各組み込み宣言の型名、将来の形の反例と同じ help、終了 1 | 同上。`..` でも将来の形を覆わないことを検査 |
| Json/Csv の ParseError を分解する bind | 受理 → E0607、主文は既存の必ず照合するパターンの文言 | パターン、各組み込み宣言の型名、将来の形の反例、既存の match への案内と将来の形の help、終了 1 | 同上。既存の c11-refutable-bind と D6c の外部 record の golden は保持 |

新しい静的な誤りの golden 一件を manifest に登録し、golden の静的な誤りの件数を 385 から 386 にした。既存の入力の受理結果・対象内件数・除外理由は変えていない。

## 計画との差と申し送り

R40 に、宣言抽出の検査が置かれている skill_docs の拡張と、golden の二つの manifest への登録を記した。R41 に、標準型への指定により必要になった既存の交換入力の期待値と所属の更新を記した。最初の check-formal は coverage_export の三型という期待値で、続けて実行した `desugar_export export_extensible` は二つの旧 view・件数の期待値で失敗した。初回の補正では desugar_export も prelude の二型だけを含むと見込んだが、実際は全標準ライブラリの四型を含むため、その境界の違いも厳密な期待値に反映した。補正後の `desugar_export export_extensible` は二件とも成功した。

続く全件比較では、追加した九構成子の入力が coverageDiff の六分岐という上限を超えた。各分岐の選択肢を三個ずつにまとめて全構成子を保持し、十件すべての比較が成功することを単独実行でも確認した。Python の最終照合にも同じ標準型一型の前提が残っていたため、四型の名前・record の印・view の厳密な比較へ更新した。IOErrorKind だけを view から欠落させる既存の破損入力の拒否も単独実行で成功した。

言語 API・Lean の規則・証明・交換形式の版の変更はない。D8 の入れ子・到達可能性の追加検査、D9 の全ターゲット・段末の検査は後続の作業である。

## 検査の結果

`BENITOITE_DESUGAR_DIFF_DIR=target/desugar-diff/d7-final BENITOITE_COVERAGE_DIFF_DIR=target/coverage-diff/d7-final bash scripts/check-formal.sh` は終了状態 0 で完了した。ログは `/private/tmp/d7-formal-verified.log`、出力は指定した二つのディレクトリにある。その後の lib も成功し、Clippy がテストの ModuleKind のワイルドカード分岐を拒否したため、Config・PackageConfig の列挙へ修正した。型付きの入力の処理・交換の内容は変わらない。

| 検査 | 結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill` | 成功。差分は四型の参照の属性各一行だけ |
| `cargo test -p benitoite --test l21_json --test l23_csv --test l32_http_client --test package_command --test golden --test skill_docs --test spec_examples --test skill_examples` | 八 suite・45 件成功、96.96 秒。既存の assert と期待値を保持 |
| `lake build`（formal/。check-formal 内） | 成功、162 jobs。Lean の変更、新しい axiom・sorry・admit・native_decide はない |
| 形式化の Rust 書き出し | coverage_export 二件と desugar_export 17 件が成功 |
| `coverageDiff` | 通常 10,020 件、view 付き 10,016 件、名前付き関数型・ソース属性の十件が一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden の 348 入力・960 定義、乱択の 1,000 入力・72,778 定義が一致。静的な誤り 386 入力を正確な理由で分類 |
| `builtinCheck` | 72,416 比較が一致。不一致・非収束 0。既存の対象外の一覧を維持 |
| `coverageProgramDiff` | 1,348 入力、match 16,409 件・binding 6,035 件、計 22,444 件が一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheck`・`surfaceCheckAll` | 全 1,734 入力の分類と個別検査が一致。51,639 件の一致と既存の対象外 19 件・Q11 一件を維持。不一致・準備の失敗 0 |
| 交換形式の独立した正負の検査 | width 四件・named 12 件・extensible 22 件成功。最終の manifest の照合、既存の契約・hole/pipe の破損入力、標準型の view の欠落の拒否も成功 |

| 最終の Rust の検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test coverage_export` | 1,161 件成功（lib 1,160 件・coverage_export 一件）、既存の ignore 22 件、72.15 秒。ignore の形式化用の一件は前述の check-formal で実行済み |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |

Clippy の修正後に書き出したソース由来の独立した網羅性入力は、check-formal が比較したファイルとバイト単位で一致した。SHA-256 は `9b6016546c836bc11d7c267f196dd9b04d98d7288ff7f1bb80a4a706e0690c2e` である。正式な比較出力とビルドのキャッシュは保持し、相対の出力先指定で誤って作った `crates/benitoite/target/coverage-diff/d7-final/named-corpus.json` 一件（54,010 バイト）だけを削除した。

本番の Rust は +13/-2 行、標準ライブラリのソースは +4/-0 行、Rust のテストは +107/-14 行、Python の照合器は +5/-1 行である（置換をそれぞれ数える）。テストの削除はない。依頼に従い、scripts/check.sh（dry-run を含む）と gc-stress は実行していない。コミットと docs/todo の変更も行っていない。
