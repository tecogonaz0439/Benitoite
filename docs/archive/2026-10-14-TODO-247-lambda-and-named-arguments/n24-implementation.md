# N24 操作・メソッド・外部・コード生成の実装

## 範囲

クラス宣言と実装の契約名の一致、操作の宣言名とハンドラの局所名の区別、外部の位置による照合を確認する。操作・メソッド・辞書を含む新しい成功入力を corpus 8・型表 2 へ接続する。

## 変更

- traits/impls.rs は、宣言と実装の外側の名前を位置ごとに比較する。名前だけの不一致は E0454、既存の型などの不一致は E0711 とする。新しい入力の判定には宣言の型と、AST の共通の走査を使う。別モジュールの実装と、本体の束縛の注釈だけを持つ入力も検査する。
- 名前付きの交換は、既存の定義・クラス表の書き出しを共用して、利用者の操作・実装メソッド・上位辞書の単位も出す。methName・funDicts は参照型の実名を使う。コアとメソッド宣言の内部名は、辞書の個数から %dict1 以降を作り、利用者の名前と分ける。
- named_operations と named_methods の golden は、逆順引数、操作とメソッドの関数値、パイプ・部分適用、固定式の遅れ、局所名を変えたハンドラ、メソッド自身と関数自身の辞書を通る。メソッドの右引数に作った文字列を、左引数の IO の安全点を越えて保持することも実行結果で確認する。
- external/tests.rs は、本物の Wasm コンポーネントの WIT 名 a・b に対して、Benitoite の left・right で呼ぶ。非可換の減算を直接・関数値・部分適用・パイプで実行し、Direct と Request で結果を比較する。WIT 側の名前 a を呼ぶ側で使う場合は E0451 とする。
- manifest と形式化の対応表を更新する。既存の七入力の件数、操作がないこと、関数の辞書引数が空であることの assert は、その七入力の関門へ移して維持する。新しい二入力には定義数・操作数・実装メソッド数の比較を追加する。表層がまとめて検査する実装数は脱糖の定義数と分ける。

操作・メソッド・外部の呼び出しは、既に通常の CallPlan を使い、ソース順の pending を作ってから値の参照だけを宣言順へ移す。dicts.rs・effects.rs、コード生成の app・method・vals、external/check.rs を確認した結果、これらの呼び出しの変更は不要だった。コード生成は辞書・利用者の値を既存の連続するレジスタへ移し、Call・TailCall・Method・TailMethod・Perform・Ext を使う。vals はまだ読んでいない引数の根を保持する。WIT は params の個数と位置の型だけを照合し、名前の一致を要求しない。VM の名前検索・新しい値の確保は追加していない。

## テストの作成時の関門

1. クラス実装は宣言の契約名に一致し、操作の呼び出しは宣言名を使い、ハンドラの束縛名は自由であることを、公開の型検査で確かめる。逆順の引数はソース順で評価した後に宣言位置へ渡すこと、辞書と利用者の引数を混同しないことを実行結果で確かめる。外部は Benitoite の契約名を使い、WIT の名前が異なっても位置で渡すことを確かめる。
2. 実装名の比較漏れ、特殊な呼び出しによる CallPlan の迂回、辞書分の位置ずれ、引数の先行評価、WIT の名前による対応付けへの退行を捕まえる。
3. 既存の名前付き呼び出しの検査には利用者の操作・ハンドラ、追加の辞書を持つメソッド、異なる WIT 名の実行がない。診断は named_arguments の表へ追加し、実行順は golden の新しい入力、交換の接続は desugar_export の公開パイプラインを境界にする。交換の検査は実行結果だけでは分からない名前の欠落と未検査の定義を捕まえる。
4. 本番の公開範囲・型・引数はテストのために変更しない。既存の実行器とパイプラインを使う。

実装前の named_arguments は、順を逆にした実装を受理してしまい、期待 E0454 に対して空の診断で失敗した。比較の追加後に同じ入力で成功した。既存の external_types_and_effects_match_component_contracts は、全件に比較を強制した途中の実装では E0454 で失敗した。元の assert と入力を変えずに R62 の旧適合を補い、同じ検査で成功した。既存のテストの削除・ignore の追加・期待値の緩和は行っていない。

## 検査と結果

| コマンド | 結果 |
|---|---|
| cargo test -p benitoite --lib | 1,148 成功、失敗 0、既存の ignore 21 |
| cargo test -p benitoite --test named_arguments --test golden --test random_programs --test vm_handlers --test call_allocations --test verify --test l13_external_commands --test runtime_builtins --test skill_docs | 九つのテスト実行ファイルで 40 成功、失敗 0 |
| cargo test -p benitoite --test desugar_export --test coverage_export --test skill_docs | 20 成功、失敗 0、既存の ignore 2。全件の交換は下記の形式化の検査で実行 |
| cargo clippy --all-targets | 成功 |
| cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats | 成功 |
| cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep | 成功 |
| cargo fmt --all --check、git diff --check | 成功 |
| cargo run -p benitoite --example gen_skill | 成功。生成物の差分なし。skill_docs でも一致を確認 |
| formal/ で lake build | 238 対象で成功。sorry の警告なし。Lean のソースは変更していない |
| scripts/check-formal.sh | 終了状態 0。lake build と新旧の六入口の比較を含む |

全件の脱糖の書き出しは約 613 秒で、desugar_export の全 12 検査が成功した。独立した交換の既存 4 検査と Named の既存 12 検査、coverage_export の全 2 検査も成功した。新形式の一般入力は九件・42 定義で脱糖が一致し、表層の 36 定義と二実装、型表とプログラム内の網羅性六項目が通った。最小・静的な入力と独立した網羅性二件も維持した。従来の六つの不正入力と、実装の実名・辞書の内部名・操作の宣言名を変えた三つの不正入力は、意図した理由で拒否された。

旧形式は対象内の golden 337 件・生成 1,000 件、型検査の誤りによる除外 378 件、対象外 0 件で N23 と一致した。旧の表層検査は 51,036 成功、既存の対象外 19 件と Q11 の一件を維持し、不一致・準備失敗はない。独立した網羅性 10,020 件、プログラム内の網羅性 22,430 件も不一致・燃料切れがない。四つの旧出力の SHA-256 は全て N23 と一致した（[legacy-hashes.json](n24/legacy-hashes.json)）。最終の交換器の短い出力も、プログラムの列挙順だけを揃えると全件の出力と一致する。結果は [formal-results.json](n24/formal-results.json) に記す。

Rust の検査のログは target/n24-lib.log・n24-integration.log・n24-export-final.log、clippy の三構成は target/n24-clippy.log・n24-clippy-verify.log・n24-clippy-mark-sweep.log、形式化の全体のログは target/n24-check-formal.log に置く。交換の出力は target/desugar-diff/n24-full/ と target/coverage-diff/n24-full/ に置く。最終の交換器の短い検査は n24-final/ の別の出力先を使い、全件の出力を上書きしない。

## 計画からのずれと申し送り

R62 は旧入力だけのクラス実装の適合を維持する補正、R63 は交換器の範囲と件数の補正である。公開の型・シグネチャは変更していない。従来のテストの意図・入力・期待値は維持した。本番は追加 208 行・削除 89 行、テスト・入力・交換の補助は追加 468 行・削除 54 行である（[line-counts.json](n24/line-counts.json)）。AST の既存の走査の移動も本番の差分に含む。

N25 は [exchange-manifest.json](n24/exchange-manifest.json) と、操作・メソッド・辞書を含む一般の出力を全入口の照合に使う。N33 は R62 の新旧の判定を除き、全実装に名前の一致を要求する。その前に旧 external/tests.rs の Trait.Show[Cell] の局所名 a を、移行作業で宣言名 x へ揃える必要がある。名前の暗黙の読み替えは行わない。

コミットと docs/todo の変更は行っていない。依頼に従い、scripts/check.sh（dry-run を含む）と gc-stress 構成の検査はオーケストレータの最後の検査に残した。
