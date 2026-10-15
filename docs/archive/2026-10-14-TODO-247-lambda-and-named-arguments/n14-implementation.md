# N14 実装記録

## 範囲

制御・コレクション・辞書・実装と、プログラム全体の checker の健全性を完成する。既存の名前付きコアの最終定理と表層の性質 1 を保つ。新交換形式と六つの入口は N15 に残す。

## テストの作成時の関門

評価例を完成する前に、四つの問いを確認した。

1. 守る契約は、制御・コレクション・辞書・プログラムの型とエフェクト、実装メソッドの実引数名の宣言との一致、穴から作る関数の戻り値と継続の境界である。
2. 名前を失った実装から本体を検査する退行、型は同じでも異なるラムダ契約を受理する退行、ハンドラ内の継続を穴の生成するラムダへ漏らす退行を捕まえる。
3. N12・N13 の例は呼び出しと判定の契約を持つ。N14 は残る構文の公開入口と、実名を保持した材料からプログラム全体を検査・型付けする接続を担当する。既存の同じ契約の例は再掲せず、穴の境界は旧の四例を名前付きで移し、同じ経路・理由・成功期待を維持する。
4. 既存の公開入口と型付き材料を使う。テストのためだけの公開範囲の拡大・フラグ・注入用の引数は不要である。Rust の本番コードとテストは変更しない。

## 計画との対応

演算子の交換形式への依存の補正は [decisions.md](decisions.md) の R39、評価例の準備入力の構成は R40 に記す。R35・R36 の実名を持つ `ImplInput` と `MethodInput` を検査成功から本体の型付けへ接続する。

## 実装と自己確認

`CheckSoundControl`・`CheckSoundCollections`・`CheckSoundDicts`・`CheckTablesSound`・`CheckProgramSound`・`CheckSound` と、評価例の `CheckExamples`・`CheckCounterexamples` を追加して lake のルートへ登録した。六つの証明モジュールの公開定理は 58 件、旧の同名定理との対応は 55 件である。前提・結論・契約名の対応は [formal-rules.md](formal-rules.md) に記す。

実装の証明は、`MethodInput.names = MethSig.names` と宣言名の整形式を `checkMethods_entry` の結論として持つ。元の有限な一覧の完全性と検査成功から、全メソッド本体と上位辞書の型付けを `ImplInput.decl` について導く。さらに `checkImpl_contracts`・`checkProgram_contracts` で実名の保証を射影前の入力について結論する。名前の正しさを新たな外部仮定にせず、既存の型付き表層の規則も弱めていない。

全 58 公開定理に公理依存の検査を行った。新しい公理と `sorryAx` はなく、旧 55 組のうち 54 組が一致する。`opPrim_sound` は R39 の構築方法により `Quot.sound` への依存が不要になり、`propext` だけになった。再現は `formal/` で `lake env lean /private/tmp/benitoite-n14-axioms.lean`、出力は `/private/tmp/benitoite-n14-axioms.log`、定理一覧は `/private/tmp/benitoite-n14-theorems.json` である。

評価例は新しい 24 件と、旧の穴の境界を名前付きで検査する四件である。型・エフェクトと診断の経路・理由を具体的に比較する。N12・N13 の名前・位置の拒否例も維持した。旧の例や Rust の assert・期待値・ignore は変更していない。

## 検査

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行しない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test desugar_export --test coverage_export` | 成功。合計 1,134 passed・既存の 23 ignored、3 suites、約 60 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。180 jobs、コアの最終定理・表層の性質 1・全追加モジュールを含み、警告と sorry なし |
| 公開定理の公理依存の検査 | 成功。58 定理に新しい公理と sorryAx なし |
| `scripts/check-formal.sh` | 成功。約 10 分。網羅性の書き出し 1 件・脱糖の統合テスト 6 件は ignored を含め全て成功し、幅付き数値の交換形式 4 件も成功 |
| `git diff --check`・新規ファイルの空白・文書リンクの確認 | 成功 |

旧形式の比較の件数・対象外の境界は、N13 の記録と一致した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は検査エラーとして除外 |
| `builtinCheck` | 71,914 比較。不一致・非収束 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を維持 |

結果は `target/desugar-diff/run-51262/` と `target/coverage-diff/run-51262/`、生の出力は `/private/tmp/benitoite-n14-check-formal.log` にある。corpus の書き出しを含む脱糖の統合テストは約 522 秒で終えた。

## 後続作業

N15 は corpus 8・型表 2・網羅性 2 と六つの入口を接続する。演算子の JSON から組み込み名を選ぶ処理は `CheckTables.makeOpPrim` に渡す。全実装の本体の型付けには `checkProgram_sound`・`checkProgram_empty`、元の材料に残る実名の保証には `checkProgram_contracts` を使える。旧形式の成功を、新形式の全入力へ接続済みの保証として扱わない。

オーケストレータは最後に `scripts/check.sh` と gc-stress の構成を検査する。Rust の本番コードとテストの行数の増減はともに 0 である。現在の設計書・`docs/todo/` は変更せず、コミットは行っていない。
