# N12 実装記録

## 範囲

名前付き表層の実行可能な checker と、型の比較・包含・置換、規則の前提の判定、パターンと網羅性、宣言表の構築を追加する。旧モデルは変更しない。checker の全構文の健全性は N13・N14、新しい交換形式と六つの入口は N15 に残す。

## テストの作成時の関門

具体例を追加する前に、四つの問いを次のように確認した。

1. 守る契約は、checker が契約名を保持し、ラベルと位置の対応を独立して検査すること、穴・パイプ・実装メソッドにも同じ規則を適用することである。実装メソッドは局所束縛を位置に変える前の実名の並び全体を検査する。
2. ラベルを無視する、Rust の位置を信用する、重複や不足を許す、引数を宣言順の型でソース順のまま検査する、穴の名前を宣言順で作る、パイプの位置 0 を二重に占める、実装メソッドの実名を検査前に消す、といった退行で失敗する。
3. 旧 checker は契約名を持たず、N8〜N11 の例は関係としての型付けと脱糖を検査する。今回の主な例は `checkExpr`・`checkImpl`・`checkProgram` の公開入口で計算するため、実行可能な検査への接続漏れを捕まえる。型の操作とパターンの既存例も名前付きの型へ移し、旧モデルの例を残す。
4. テストのための公開範囲の拡大・フラグ・差し込み口は加えない。checker が本番の入力に必要とする材料だけを定義する。失敗例はエラーの経路と理由に厳密に一致させ、別の型の誤りで拒否される例にしない。既存の assert・期待値・ignore は変更しない。

## 実装と自己確認

`NamedSurface/CheckTools`・`CheckPredicates`・`CheckPatterns`・`CheckSupport`・`Check`・`CheckTables`・`CheckToolsExamples` を追加し、`formal/Benitoite.lean` に登録した。契約名の比較は入れ子の関数型も含む。呼び出しの位置対応は入力のまま使わず、`callOk` で名前・ラベル・全位置の置換を照合する。引数型は `sourceTypes` でソース順に取り出す。穴は `holeNames`、直接の構成子の穴は宣言位置由来の argN、パイプ挿入は位置 0 を使う。

実装メソッドの実名は `Check.MethodInput.names` に保持し、`checkMethods` が `MethSig.names` と並び全体を比較してから本体を検査する。`Check.ImplInput.decl` は性質 1 の使う本体への射影であり、その射影だけで検査を済ませない。`CheckTables.checkProgram` は元の材料を受け取って `ImplInput` を作る。旧交換形式の材料への依存を分離した理由とこの入力の補正は [decisions.md](decisions.md) の R36 に記す。

[formal-rules.md](formal-rules.md) に、旧定理と新定理の前提・結論・名前の保持の対応を記した。既存の公開定理はモジュールごとに 43・25・14・15・2 個、計 99 個あり、欠落・改名はない。追加の三定理は `namesWF_spec`・`callOk_spec`・`constructorHolesOk_spec` であり、実行可能な判定の成功と入力側の規則の同値を追加の前提なしで示す。`AtomsIn` へ名前の正しさの外部条件を追加していない。

全 99 組に `#print axioms` を適用し、公理依存が一致することを確認した。追加の三定理も既存の `propext`・`Classical.choice`・`Quot.sound` の範囲であり、sorry と新しい公理はない。再現コマンドは `formal/` で `lake env lean /private/tmp/benitoite-n12-axioms.lean`、出力は `/private/tmp/benitoite-n12-axioms.log` である。

旧 130 例は型の名前と新構文の欄を付けて維持し、checker の公開入口の 42 例を追加した。成功例は推論した型の名前・引数型・戻り値型・エフェクトを比較する。失敗例はエラーの経路と理由の厳密な等式をカーネルで計算する。メソッド実名の例は同じ型の二引数・同じ本体で並びだけを入れ替え、型の違いで拒否されることを避けている。

## 検査

依頼に従い `scripts/check.sh`（dry-run を含む）と gc-stress の構成は実行しない。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib --test coverage_export --test desugar_export` | 成功。1,134 passed、既存の 23 ignored、3 suites、約 59 秒 |
| `cargo fmt --all --check` | 成功 |
| `cargo clippy --all-targets` | 成功 |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 成功 |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 成功 |
| `formal/` で `lake build` | 成功。166 jobs。全七モジュール・102 公開定理・172 具体例をビルドし、警告と sorry なし |
| `scripts/check-formal.sh` | 成功。約 10 分。旧形式の全比較、coverage_export 1 件、desugar_export 6 件、幅付き数値の交換形式 4 件が通った |
| `git diff --check` と新規ファイルの末尾の空白の確認 | 成功 |
| 全公開補題の公理依存と旧モデルの比較 | 成功。99 組が一致。全 102 定理に新しい公理と sorryAx なし |


旧形式の件数と対象外の境界は N11 の記録と一致した。

| 比較 | 結果 |
|---|---|
| `coverageDiff` | 10,020 件一致。不一致・燃料切れ 0 |
| `desugarDiff` | golden 337 プログラム・910 関数、生成した 1,000 プログラム・72,218 関数が一致。不一致・対象外 0。既存の負の入力 378 件は検査エラーとして除外 |
| `builtinCheck` | 71,914 比較。不一致・非収束 0。足りない組み込み・構成子 0。既存の不透明な引数 2 件と State の対象外境界 11 件を維持 |
| `coverageProgramDiff` | 22,430 件一致。不一致・対象外・燃料切れ 0 |
| `surfaceCheckAll` | 51,036 件一致。不一致・準備の失敗 0。既存の対象外 19 件と q11 1 件を維持 |

結果は `target/desugar-diff/run-48980/` と `target/coverage-diff/run-48980/`、生の出力は `/private/tmp/benitoite-n12-check-formal.log` にある。corpus の書き出しを含む脱糖の統合テストは約 522 秒で終えた。新モデルは、全モジュール・証明・具体例のビルドと公理依存の照合で検査した。旧交換形式の成功を、新モデルの全入力への接続済みの保証として扱わない。

## 後続作業

N13 は `namesWF_spec`・`callOk_spec`・`constructorHolesOk_spec` の成功から規則の前提を取り出し、`sourceTypes` とソース順の引数の型付けへ接続する。`fnView` は名前・引数型・戻り値型・エフェクトの四要素を返す。

N14 は `checkMethods` の成功から `MethodInput.names = MethSig.names` を導き、`ImplInput.decl` の本体の型付けを証明する。実装メソッドの全名前が有限の一覧にあることは、旧 checker と同じく表の材料とその完全性から導く。名前の一致を外部仮定にしない。`CheckTables.checkProgram` は Program に射影する前の Materials を受け取るため、プログラムの健全性の証明ではその射影との関係も示す。

N15 は corpus 8・型表 2・網羅性 2 の必須欄を、今回の Named の型付きの材料に接続する。実装側の引数名を JSON から `MethodInput.names` まで保持し、宣言名による自動補完や旧形式への変換を行わない。比較と型付けへの接続が終わる前に、新しい checker の全構文の健全性を証明済みとは扱わない。

Rust の本番コードとテストの行数の増減はともに 0 である。旧 Lean の例・定理、既存の assert・期待値・ignore、現在の設計書、`docs/todo/` は変更していない。コミットは行っていない。オーケストレータは最後に `scripts/check.sh` と gc-stress の構成を検査する。
