# N10 実装記録

## 範囲

`NamedSurface/Lemmas/Calls.lean`・`CallHead.lean`・`Typing.lean` に、名前と位置対応を持つ呼び出し・穴・パイプの型保存を追加した。辞書の依存の前倒しと相互帰納法の分割は [decisions.md](decisions.md) の R33 に記す。旧モデル・交換形式・Rust の本番コードとテストは変更しない。

## テストの作成時の関門

一般の補題と、逆順指定・複数の穴・パイプの具体例について、四つの問いを次のように確認した。

1. 守る契約は、契約名の一致、位置の全域性・単射性、ソース順の引数の型と宣言順の参照の型の対応、穴の名前と型のソース順、固定式の遅れた評価、パイプの位置 0 の挿入である。
2. 位置の逆転、引数の並べ替えで生じる型の不一致、穴の変数番号と契約順の取り違え、callee・固定式をラムダの外へ移す変更、パイプ左辺の移動量の誤りで、実際の脱糖結果の型付けが通らなくなる。
3. N8 の具体例は脱糖結果の等式であり、表層からコアへの型保存を使っていない。今回の例は型の異なる逆順の引数、エフェクトを持つ固定引数を挟む複数の穴、位置 0 を挿入するパイプに一般の型保存の補題を適用する。旧モデルは名前と位置を持たないため、この契約を検査できない。
4. テスト専用の API・フラグ・差し込み口は加えない。新モデルの型付け・脱糖と、その型保存の補題を直接使う。Rust のテスト、旧 Lean の定理と例は変更せず、期待値の緩和や ignore の追加を行わない。

式の列・穴の列の `desugar_of_expr` は、式の帰納法の結論から保存を組み立てる補題である。式全体・プログラム全体の性質 1 を、この前提を外部仮定に残して証明済みとはしない。N11 の相互帰納法で接続する。実行時の IO 順全体と短いラムダの解析境界は今回の定理に含めない。

## 検査

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行しない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test coverage_export --test desugar_export` | 成功。1,134 passed、既存の 23 ignored、3 suites、約 60 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。151 jobs。四つの新モジュールと三つの具体例を登録・ビルドし、sorry と警告なし |
| 全公開補題の `#print axioms` | 成功。36 定理の依存は `propext`・`Classical.choice`・`Quot.sound` の範囲。旧モデルに同名の定理がある 21 補題と公理依存が一致。新しい公理と `sorryAx` なし |
| `scripts/check-formal.sh` | 成功。約 10 分。旧形式の全比較、coverage_export 1 件、desugar_export 6 件、幅付き数値の交換形式 4 件が通った |
| `git diff --check` と新規ファイルの末尾の空白の確認 | 成功 |

公理の確認は、`import Benitoite` と各公開補題および同名の旧補題の `#print axioms` を含む一時ファイルを作り、`formal/` で `lake env lean /private/tmp/benitoite-n10-axioms.lean` を実行した。旧形式の差分検査の生の出力は `/private/tmp/benitoite-n10-check-formal.log` に置く。

旧形式の比較は N9 の件数と対象外の境界を維持した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は検査エラーとして除外 |
| `builtinCheck` | 71,914 比較。不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を維持 |

結果は `target/desugar-diff/run-44654/` と `target/coverage-diff/run-44654/` にある。corpus の書き出しを含む脱糖の統合テストは約 528 秒で終えた。新モデルは全モジュールの証明と具体例のビルドで検査し、checker と新しい交換形式の接続は N12〜N15 に残す。

## 後続作業

N11 の `Typing` は `HasType.desugar_call`・`desugar_partialCall`・四つのパイプの補題・構成子の補題を各場合から使う。ソース引数の計算と範囲は `HasTypes.desugar_of_expr`、穴は `HasHoleArgs.desugar_of_expr` の証明と同じ帰納法で得る。穴の helper は prior を空にして使い、callee と穴の計算をともに `binds args.holeTypes ++ hideConts Γ` の下へ移す。式全体の保存を外部仮定に残さず、全構文の相互帰納法を完成する。

`Records` は `Calls` の `fieldAt_typed`・`valueMaps_typed`・`map_range_getD`・`recordFields_typed` を使い、N9 の `ScopedSupport` の範囲保存とともに再定義しない。`Dict` は `DictSupport` の三補題を使う。`funDecl_desugared` は追加した coreNames の等式、逆転は追加した名前の整形式と名前の一致を取り出す。`Extensions` の頭の判断にも名前を渡し、List.concat は xs・ys、補間の変換関数は value の契約を保つ。

Rust の本番コード・テストの行数の増減はともに 0 である。既存の assert・期待値・ignore、旧 Lean の定理と例、現在の設計書、`docs/todo/` は変更していない。コミットは行っていない。オーケストレータは最後に `scripts/check.sh` と gc-stress の構成を検査する。
