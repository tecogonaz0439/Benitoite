# N16 実装記録

## 範囲と成果物

名前付きモデルの定義・最終定理・交換形式を、Rust の表現変更の前にレビューした。[formal-rules.md](formal-rules.md) に元と新しい定理の前提・結論・範囲、呼び出しと評価順、六つの交換の入口の対応表を追加した。[G4-report.md](reviews/G4-report.md) に所見と対処、信頼する境界、再現可能な公理依存の検査を記録した。

レビューで、辞書付き実装メソッドの JSON から checker への接続の不具合を一件見つけた。`NamedExchange.CheckInput.prepare` で、実装自身の辞書数から作る内部名を実装自身の利用者名の前に付ける。型クラス側の名前を転記せず、既存の比較と健全性定理を使う。最小の補正とその理由は [decisions.md](decisions.md) の R43 に記す。独立入力の説明にも辞書名と利用者名の区別を反映した。

旧新の型付け規則・最終定理・対象外の境界は変更しない。現在の設計書・Rust の表現・docs/todo/ は変更せず、コミットも行わない。

## テストの作成時の関門

辞書付き実装の退行テストの追加前に、四つの問いを確認した。

1. 守る契約は、実装自身の辞書引数と利用者の実名を保持したまま、宣言と名前が一致する実装を受理し、実名が違う同じ実装を拒否することである。
2. 利用者名だけを辞書込みの宣言名と比較する退行、宣言の名前を転記して実名を消す退行、全件検査の正規化で名前を失う退行を捕まえる。
3. 既存の型付きの例は `MethodInput` を直接構築し、N15 の JSON の実装例は辞書がない。今回の主な境界は JSON を受け取る二つの checker の公開入口である。同じ独立入力の脱糖比較も通し、checker の拒否が型や交換形式の別の誤りによるものではないことを確かめる。準備は既存の `run_tool` を共用する。
4. テスト専用の公開範囲・引数・フラグは加えない。既存の入力を複製して一メソッドへ絞り、辞書と名前を明示して本物の入口を呼ぶ。既存の assert・期待値・ignore は変更しない。

修正前には、正常な辞書付き入力が `namedDesugarDiff` で成功し、二つの checker では名前不一致で失敗することを確認した。修正後は三入口で受理し、利用者名だけが違う入力は二つの checker で終了状態 1、具体的な名前不一致の理由と経路に一致する。既存の 10 テストに一つを加え、全 11 テストが成功した。

公理依存の検査ファイルはレビュー用の成果物であり、処理系の振る舞いをソースの字面で検査するテストではない。ビルド済みの Lean の環境から宣言を列挙し、証明の依存を調べる。既存のテストや証明を削除する監査は行っていない。Rust の本番コード・Rust のテストの行数の増減はともに 0、Lean の既存の証明と評価例の削除も 0 である。

## 検査

依頼に従い scripts/check.sh（dry-run を含む）と gc-stress の構成は実行しない。K のそれ以外の検査と、N16 の旧入口・独立入力の検査を行う。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test desugar_export --test coverage_export` | 成功。1,134 passed、既存の 23 ignored、3 suites、約 61 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。238 jobs。R43 の修正後の全モデル・証明・新しい六入口を含み、sorry・警告なし |
| `python3 -I formal/tests/test_named_exchange.py` | 成功。全 11 tests。元の六入口の正常・不正入力に加え、R43 の正常・不一致の両方を確認 |
| `formal/` で `lake env lean ../docs/2026-10-14-TODO-247-lambda-and-named-arguments/reviews/N16-axioms.lean` | 成功。3,668 宣言で標準の三公理以外の依存なし。内訳と旧との差は G4 のレビュー記録を参照 |
| `scripts/check-formal.sh` | 成功。約 10 分。旧形式の Rust の全出力を再作成して比較。coverage_export 1 件、desugar_export 6 件（既存の ignored を含む）、幅付き数値の交換の 4 tests も成功 |
| `formal/` で `lake build surfaceCheck` と旧 `surfaceCheck` の実行 | 成功。既存の幅付き数値の正常入力の 40 定義を受理。report は `target/n16-gate/legacy-surface-check.json` |
| `git diff --check` と文書リンク・新規文書の空白の確認 | 成功 |

全体の形式化の検査は、`BENITOITE_DESUGAR_DIFF_DIR=target/n16-gate/desugar` と `BENITOITE_COVERAGE_DIFF_DIR=target/n16-gate/coverage` を指定して実行する。生の出力は `/private/tmp/benitoite-n16-formal.log`、公理依存の一覧は `/private/tmp/benitoite-n16-axioms.log` に保存する。

旧形式の件数と分類は N12〜N14 の記録と一致した。新旧を同じ対象件数で比較する接続は後続作業であり、今回は旧全件の維持と新形式の独立入力をそれぞれ確認した。

| 旧形式の比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 定義、生成した 1,000 プログラム・72,218 定義が一致。不一致・対象外 0。負の入力 378 件は従来どおり型検査の誤りとして除外 |
| `builtinCheck` | 71,914 比較。不一致・非収束・足りない組み込みと構成子 0。既存の不透明な引数 2 件・State の境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を維持し、補正件数の照合も成功 |

新しい独立入力は、既存の 17 定義の期待コア・全件の表層 16 件・二種類の網羅性の各 2 件が一致する。元の 10 テストの期待値は維持し、R43 の一メソッドの入力を追加した。新たに対象外へ分類した入力はない。

## 計画との差と申し送り

範囲内のずれは R43 の交換の接続の修正一件である。新しい規則・公開型の変更・証明の弱化はない。レビューより先に名前付きの型や呼び出しの意味を Rust へ実装していない。

N17 はこのレビュー済みの契約を前提に移行候補を作れる。後の書き出し器は、メソッド宣言の辞書込みの名前と実装側の利用者名・辞書数を区別する。N21b 以降は入力単位の新旧の版、型表と sidecar、対象内件数と対象外理由を照合する。N34a の正式モデルと規則の写しの同時切り替え、N34b の旧経路削除の条件は維持する。

オーケストレータが最後に scripts/check.sh と gc-stress の構成を検査する。
