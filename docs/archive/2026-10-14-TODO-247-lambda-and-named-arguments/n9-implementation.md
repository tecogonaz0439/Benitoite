# N9 実装記録

## 範囲

`NamedSurface/Lemmas/` に表層の変数移動・範囲保存・文の列の補題を追加した。計画の七モジュールの全 83 定理を同じ名前と順で維持し、四つの補助モジュールに 21 定理を加えた。十一モジュールを `formal/Benitoite.lean` に登録した。定理と前提・結論の対応は [formal-rules.md](formal-rules.md) の「表層の変数移動・範囲保存・文の列の対応」に記す。

型・値の変数移動は契約名を保持する。新しい全構文に対する結果型の不変条件と脱糖後の範囲保存を証明した。任意の長さの let の列はソース順に束縛し、型付きの環境と de Bruijn の番号を対応させる。文の列の全 11 規則、末尾・非末尾の return、Result・Option の try について、子の計算から型保存を組み立てる補題も加えた。

## テストの関門と証明の境界

Rust のテストと Lean の具体例は追加・変更していない。証明の追加に対して、作成時の四つの問いを次のように確認した。

1. 守る契約は、契約名とその整形式、型・エフェクト変数の範囲、挿入した束縛と変数番号の対応、文の型と許容エフェクト、return・try の最も内側の作用先である。
2. 名前の整形式を失う変数移動、穴の番号や let の移動量の誤り、範囲保存の構文の漏れ、捨てる文の後の変数の誤った捕獲、別の戻り先への escape により、一般の補題の証明が通らなくなる。
3. 旧モデルは契約名と位置情報を持たず、新しい判断での一般の帰納法を検査できない。新しいコア・表層・脱糖の定義を直接使って証明する。元の七モジュールの全定理を維持し、具体例を重複して追加しない。
4. テスト専用の公開 API・フラグ・差し込み口は追加しない。子の計算からの組み立てを分けた補題は、後続の型保存の証明に必要な境界である。型付け・範囲条件以外から名前の正しさを一括で仮定しない。

`HasBlock.desugar_of_expr` の式の保存は組み立ての前提であり、式全体とプログラム全体の保存を終えたことを意味しない。N10・N11 は相互帰納法の各場合で、この補題と同じ文の証明を接続する。短いラムダの解析境界と IO 順全体は今回の定理の対象外である。

## 計画との差

旧 `Scoped` の依存から範囲保存の補題だけを前倒しし、式全体の保存と相互に再帰する文・return・try の場合を組み立ての補題へ分けた。理由と推す案は [decisions.md](decisions.md) の R32 に記す。全範囲の性質 1、呼び出し・穴・パイプの引数の型保存、checker と交換形式の接続は後続の作業に残した。

## 検査

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress は実行しない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test coverage_export --test desugar_export` | 成功。1,134 passed、既存の 23 ignored、3 suites、約 61 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。147 jobs。新しい全モジュールを登録・ビルドし、sorry と警告なし |
| 全公開補題の `#print axioms` | 成功。103 定理の依存は `propext`・`Classical.choice`・`Quot.sound` の範囲。既存の公開 82 定理は旧モデルと公理依存が一致。新しい公理と `sorryAx` なし |
| 元の七モジュールとの定理名・順の比較 | 成功。全 83 定理を維持 |
| `scripts/check-formal.sh` | 成功。約 10 分。旧形式の全比較、coverage_export 1 件、desugar_export 6 件、幅付き数値の交換形式 4 件が通った |
| `git diff --check` | 成功 |

公理の確認は、`import Benitoite` と各公開補題の `#print axioms` を含む一時ファイルを作り、`formal/` で `lake env lean /private/tmp/benitoite-n9-axioms.lean` を実行した。旧形式の差分検査の生の出力は `/private/tmp/benitoite-n9-check-formal.log` に置く。

旧形式の比較は N8 の件数と対象外境界を維持した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は検査エラーとして除外 |
| `builtinCheck` | 71,914 比較。不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を維持 |

結果は `target/desugar-diff/run-43324/` と `target/coverage-diff/run-43324/` にある。corpus の書き出しを含む脱糖の統合テストは約 537 秒で終えた。新モデルの検査は全モジュールの証明と既存の定義例のビルドで行い、新しい交換形式の接続は N12〜N15 に残す。

## 後続作業

N10 の `Calls` は `ScopedSupport` を読み込み、`CallHead.Scoped`・`desugarPipeValue`・`callComp_scoped` を再定義しない。名前と位置の検査、ソース順の型から位置順の参照の型付けを導く補題は N10 で追加する。`letChain_typed`・`sequence_typed` は入力の計算の順を変えない形で使う。

N11 の `Records`・`Patterns` は前倒しした範囲保存・合同性・変数移動を各補助モジュールから読み込み、再定義しない。`Typing` の相互帰納法で文・return・try の組み立てを接続し、式全体とプログラム全体の保存を完成する。`BlockSequence` の普遍的な式の保存の前提を、そのまま最終定理の外部仮定に残してはならない。

Rust の本番コード・テストの行数の増減はともに 0 である。既存の assert・期待値・ignore、旧 Lean の定理と例、現在の設計書、`docs/todo/` は変更していない。コミットは行っていない。オーケストレータは最後に `scripts/check.sh` と gc-stress の構成を検査する。
