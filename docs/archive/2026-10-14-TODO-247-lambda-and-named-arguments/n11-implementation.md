# N11 実装記録

## 範囲

名前付き表層の制御・コレクション・パターン・レコード・辞書を、全構文の脱糖の型保存へ接続する。`desugar_typed`（性質 1）と `surface_effect_soundness` は、旧モデルと同じ前提・結論の形と対象範囲を維持する。既に前倒しした補題の配置と全構文の相互帰納法の接続は [decisions.md](decisions.md) の R34 に記す。

## テストの作成時の関門

Lean の具体例を追加する前に、四つの問いを次のように確認した。

1. 守る契約は、名前付きの型付けから実際の脱糖結果の型付けを得ることと、契約名の異なるラムダを型付けで拒否することである。操作・ハンドラ・型クラスの実装を含むプログラム全体について、性質 1 の前提を具体的に満たす例を作る。
2. 相互帰納法の制御・コレクション・辞書の接続漏れ、操作の節での名前の条件の欠落、ラムダの名前を型の包含で読み替える退行、内部辞書名と利用者名の取り違えで失敗する。
3. 旧モデルは契約名を持たず、N8 の例は型付けと脱糖の等式、N10 の例は子の計算を型付け済みとして各場合を組み立てる。今回の例は全構文の主定理・プログラム全体の定理を使うため、それらが確認していない接続を検査する。旧 `Surface/Examples.lean` の全例と、既存の Named の全例も残す。
4. テスト専用の API・フラグ・差し込み口を加えず、型付け・脱糖・性質 1 を直接使う。Rust のテストと旧 Lean の定理・例には触れない。assert・期待値・ignore を変更しない。

性質 1 は型の保存であり、短いラムダの解析境界や実行時の IO 順全体の証明とは扱わない。実行可能な checker と新形式の交換は N12 以降で接続する。

## 定理の対応と自己確認

`formal-rules.md` に、全 49 公開定理と旧モデルの前提・結論・名前の保持の対応をまとめた。`Extensions`・`Patterns`・`Records`・`Dict`・`Typing`・`Program` の旧定理はそれぞれ 13・13・26・3・7・4 個であり、前倒ししたモジュールを含め、Named 側の同名定理に欠落・重複がない。

49 公開定理と旧モデルの同名定理、およびプログラム全体の二つの具体例に `#print axioms` を適用した。全 49 組で公理依存が一致し、依存は既存の `propext`・`Classical.choice`・`Quot.sound` の範囲である。新しい公理と `sorryAx` はない。コマンドは `formal/` で `lake env lean /private/tmp/benitoite-n11-axioms.lean`、出力は `/private/tmp/benitoite-n11-axioms.log` に置く。

具体例は、操作・再開するハンドラ・逆順のメソッド呼び出し・型クラスの実装を含むプログラムに性質 1 と表層のエフェクト健全性を適用する二定理、if とリストの型保存、契約名だけが違う期待型へのラムダの適合の拒否の計四例である。ラムダの拒否は、入力の範囲条件を満たすことを示し、全構文の型保存を通して名前付きコアの反転と名前の一致から矛盾を導く。

## 検査

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行しない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test coverage_export --test desugar_export` | 成功。1,134 passed、既存の 23 ignored、3 suites、約 60 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。158 jobs。追加した七モジュールと全構文の相互帰納法を登録・ビルドし、sorry と警告なし |
| 全公開定理の `#print axioms` と旧モデルとの比較 | 成功。49 組の公理依存が一致。プログラム全体の二つの具体例にも新しい公理と sorryAx なし |
| `scripts/check-formal.sh` | 成功。約 10 分。旧形式の全比較、coverage_export 1 件、desugar_export 6 件、幅付き数値の交換形式 4 件が通った |
| `git diff --check` と新規ファイルの末尾の空白の確認 | 成功 |

旧形式の比較は N10 の件数と対象外の境界を維持した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は検査エラーとして除外 |
| `builtinCheck` | 71,914 比較。不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を維持 |

結果は `target/desugar-diff/run-46050/` と `target/coverage-diff/run-46050/`、生の出力は `/private/tmp/benitoite-n11-check-formal.log` にある。corpus の書き出しを含む脱糖の統合テストは約 527 秒で終えた。新モデルは、登録した全モジュール・証明・具体例のビルドと公理依存の照合で検査した。

## 後続作業

N12 の checker は、`NamedSurface.Typing`・`WellFormed` の名前付きの入力条件を独立して検査する。N13・N14 は、その成功から各判断・プログラム全体の型付けと範囲条件を導き、今回の `desugar_typed` に接続する。Rust の位置を入力のまま信用せず、名前・ラベル・位置の一致を検査する。新形式の交換は N15 以降で接続する。現在の設計書の正式規則への切り替えは N34a に残す。

Rust の本番コードとテストの行数の増減はともに 0 である。既存の assert・期待値・ignore、旧 Lean の定理と例、現在の設計書、`docs/todo/` は変更していない。コミットは行っていない。オーケストレータは最後に `scripts/check.sh` と gc-stress の構成を検査する。
