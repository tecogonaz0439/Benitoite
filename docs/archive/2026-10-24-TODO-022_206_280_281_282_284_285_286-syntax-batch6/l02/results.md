# L02 の結果

2026-10-24。基準 B_WORK は `69d8f2e5f02448c22e778e37649ec85d1f7098a7`。開始時の HEAD はこの基準と一致し、作業差分はなかった。git の変更操作は行っていない。

## 実行した検査

以下の `scripts/check.sh` はリポジトリの根で実行した。シェルの入口は `rtk proxy` とし、実検査の外側の時間は Python の `time.monotonic()` で計測した。

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---|---|
| `lake env lean Benitoite/Interval/Eval.lean`（作業ディレクトリ: `formal/`） | 6回中、初期の2回が1、修正後の4回が0 | 各回約1秒未満。個別の精密値は未保存。失敗と修正は下記 |
| `scripts/check.sh --level work --base 69d8f2e5f02448c22e778e37649ec85d1f7098a7 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 約0.1秒。指定した三単位だけを選択 |
| `scripts/check.sh --level work --base 69d8f2e5f02448c22e778e37649ec85d1f7098a7 --only formal_build,spec_examples,spec_tally` | 0 | 11.552秒。仕様集計の自己検査と集計が成功、仕様例7件成功、既定の `lake build` 成功、`sorry` の検出なし |
| `scripts/check.sh --level work --base 69d8f2e5f02448c22e778e37649ec85d1f7098a7 --only formal_build --dry-run` | 0 | 約0.1秒。最終の局所修正後に古くなった Lean ビルドだけを選択 |
| `scripts/check.sh --level work --base 69d8f2e5f02448c22e778e37649ec85d1f7098a7 --only formal_build` | 0 | 1.299秒。最終の既定 `lake build` 成功、`sorry` の検出なし |
| `git diff --check` | 0 | 約0.1秒。空白の誤りなし |

仕様集計は、新設した 01-12「区間解析の対象構文の評価関係」を Rust テストからの参照がない節として表示した。終了状態は0である。今回の独立例は Lean の定義の内側の検査であり、Rust の構文・警告のテストを追加していない。

局所検査の失敗と修正:

- `integer_value_in_top` の Boolean と Unit の場合に、型を射影する定義を展開せず `contradiction` だけを使った証明が失敗した。`ConcreteValue.type` を展開して異なる型を排除する証明へ直した。
- `unknown_analysis_sound` で正常結果を固定したまま帰納関係を場合分けすると、return の `returnOutcome` に対する従属除去が失敗した。結果の等式を一般化してから場合分けし、オペランドの結果ごとに正常結果との不一致を示した。

work の成功後の自己点検で、`StandardRule.finish` が Range の評価規則から生成されない拒否理由に対して、引数のない OutOfRange の値を作る補完処理を見つけた。実際の二種類の Range エラーだけを Result.Error へ移し、それ以外は failed とする全域の定義へ直した。仕様例・集計の入力は変わらないため、古くなった `formal_build` だけを再実行した。

## 計画からのずれ

- L02 の定義と証明を `formal/Benitoite/Interval/Eval.lean` に置き、`formal/Benitoite.lean` の既定 import に接続した。01-12 に写し、07-04 に対応と A1 の限界・レビューの観点を加えた。
- 指定の設計書の更新に伴い、AGENTS.md の用語集の規約に従って、00-04 に設計者が選んだ「対象構文の評価関係」の一行を加えた。言語の規則・既存の主定理・公理・`Builtins.Assumptions` の変更はない。取りまとめへ判断を戻す停止条件には該当しなかった。
- 独立例は test-audit の作成時の関門を通し、新しい評価関係の境界に3まとまりを置いた。守る契約は未知の正常値と失敗の許容、Range の拒否から通常の Result.Error への変換と入力保存、固定域外の正常結果の排除である。対応する退行は、未知の正常値を失うこと、API の拒否を全体の失敗と混同すること、域外で成功を許すことである。既存の Domain・Checked.Range の単独例はこの接続を通らず、検査のための専用の公開口やフラグは追加していない。テストの削除はない。新設ファイルは422行で、定義・証明等387行、独立例35行（コメント・空行を含む）である。

## 後続への申し送り

- L03 は `ConcreteEnv.locals : List (Option ConcreteValue)` に局所の対応を接続する。`none` は専用 builder の位置であり、Integer64 の事実を持たせない。`classify` は全53構成子、`children` と各容器の関数は Exprs・HoleArgs・Block・Arms・Clauses の全形を扱う。子の列挙は構文上の順序であり、未対応式の子を評価する許可ではない。
- `EvalInput` は式の出現・型・`OperationKey` を持つ。キーの番号付け、一意性、元の AST との対応は L26・X の担当であり、この構造だけでは証明していない。`ConcreteEnv.apiAt` の宣言名は `standards` の表で引く。表にない場合だけ API の未知規則を許し、同定済み API に任意値を返す未知規則を重ねない。
- `unknownAnalysis` は型の全値域・mayFail=true・警告なしである。正常な Integer64 は有界な具体整数で表し、Top 所属・任意整数の許容・空 trace・共通解析規則の健全性を証明した。関数・ラムダ・lazy・節の別本体としての列挙と Top 開始、予算退避は後続の担当である。
- `EvalPartial` の現在の具体規則は Integer64 のリテラルと直接負号、Boolean、Unit、括弧、空の局所環境での constE、オペランドまでの return に限る。local・Block・算術・分岐等の具体規則は L03 以降の各作業で接続する。53構成子の分類があることを、全構成子を具体評価したことと扱わない。
- L18〜L25 は `StandardBinding.rule` と `EvalStandard` を使って、表層の直接呼び出し・引数順・レコード欄・Range の成功値の束縛との対応を接続する。Range の規則は三入力の Integer64 表現可能性を入力の型で確保し、逆転優先・三欄の保存を定義する。成功値の呼び出しのキーは保持するが、局所の束縛番号との対応は未接続である。固定域は契約上の引数位置と閉区間を持ち、域内の他の失敗は許す。
- 中心定理は `NormalSoundness Models analyze` と `WarningSoundness Models analyze` の二命題として固定した。正常値は `AnalysisResult.normal` の所属述語で表し、各解析領域の区間の所属をここへ与える。抽象環境と予算の型を量化し、標準 API や δ の意味の前提を含めない。実際の `Models`・解析・予算の定義と、これらの命題の証明は L03 以降・L07b・L12 の担当である。profile の拡張でこの前提・結論を変えないことをレビューで確認する。
- 独立した定義・言明・仮定のレビューと受け入れは取りまとめが行う。本作業のビルド成功だけを C0/C1 や Rust へ進む条件の充足と扱わない。実ソース・標準 API・VM との値・失敗・到達の比較は X の担当であり、未実施である。

## L02R: 警告の原因と拒否理由の一致

2026-10-24。基準 B_WORK は引き続き `69d8f2e5f02448c22e778e37649ec85d1f7098a7` とする。L02 の未コミットの変更がある状態から、取りまとめの指示による修正を行った。git コマンドは起動せず、private/ とそこを指すスキルのリンクも読んでいない。

### 指摘と修正

取りまとめの指摘は、旧 `WarningSoundness` の結論 `∃ reason, event.result = .rejected reason` が拒否理由を限定せず、あふれで拒否する演算に除数0の警告を付けても排除できない、というものである。この依頼で明示された中心命題の強化を行い、L02 の完了時に固定する言明を以下へ改めた。

- `WarningCause` を `zeroDivisor | overflow | outsideDomain` の三種類で定義し、`IntervalWarning.cause` に持たせた。`toFailure` はそれぞれを同名の `Failure` に写す。`unknown`・`invalidBounds`・`outOfRange` を警告の原因に使うことはできない。
- `WarningSoundness` の結論を `event.result = .rejected warning.cause.toFailure` にした。任意の環境・予算・評価、解析の各警告、到達した各事象を量化する形は保つ。`Reached` は trace 内の所属とキー・演算の一致のままであり、原因の一致を前提へ移していない。
- `domainRejected` が `.rejected .outsideDomain` を返す定義と一致することを確認した。01-12 の写し、07-04 の同名節と対応表を、警告の原因と拒否理由の一致まで含む言明へ更新した。既存の主定理・公理・`Builtins.Assumptions` の変更はない。
- 固定域の既存の独立例を広げ、256 が閉区間 [0, 255] の外にある場合に `WarningCause.outsideDomain.toFailure` に対応する拒否を得て、正常結果と `WarningCause.zeroDivisor.toFailure` に対応する拒否を得られないことを確認した。

独立例の変更には test-audit の作成時の関門を適用した。守る契約は固定域の拒否理由と警告の原因の対応であり、誤った写像や別の原因での拒否を許す変更を捕まえる。既存例は `.outsideDomain` と正常結果だけを検査し、警告の原因からの写像や異なる原因での拒否を検査していなかったため、その例に条件を加えた。専用の公開口やフラグは追加していない。例の削除はなく、Eval.lean は422行から439行へ増えた（定義・言明等は12行増、既存の独立例の部分は5行増。コメント・空行を含む）。この例は評価規則の内側の検査であり、解析全体の健全性や実行系との一致の証明ではない。

### 後続への契約

L04 以降が算術の具体規則を追加するときは、除数0を `.rejected .zeroDivisor`、あふれを `.rejected .overflow` で表す。例えば最小値の `div -1` のあふれを `.zeroDivisor` として扱わない。固定域外は既存の `domainRejected` の `.rejected .outsideDomain` を使う。W0401・W0402・W0404 は、それぞれ `zeroDivisor`・`overflow`・`outsideDomain` を警告の原因に持たせる。この契約を01-12にも記した。算術の具体規則自体は今回追加していない。

以後の profile は、この強化後の `NormalSoundness`・`WarningSoundness` の前提・結論を変えずに接続する。今回固定したのは中心定理の言明であり、解析全体に対する証明は後続の担当である。定義・言明・仮定の独立レビューと受け入れは、引き続き取りまとめが行う。

### L02R の検査

リポジトリの根から `rtk proxy` 経由で実行し、外側の時間を Python の `time.monotonic()` で計測した。

| コマンド | 終了状態 | 外側の時間・結果 |
|---|---|---|
| `lake env lean Benitoite/Interval/Eval.lean`（作業ディレクトリ: `formal/`） | 0 | 0.634秒。変更した定義・言明と独立例が成功 |
| `scripts/check.sh --level work --base 69d8f2e5f02448c22e778e37649ec85d1f7098a7 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.010秒。指定の仕様集計・仕様例・Lean ビルドの三単位だけを選択 |
| `scripts/check.sh --level work --base 69d8f2e5f02448c22e778e37649ec85d1f7098a7 --only formal_build,spec_examples,spec_tally` | 0 | 5.293秒。一度実行し、仕様集計の自己検査と集計、仕様例7件、既定の `lake build` と `sorry` の検出がすべて成功 |

L02R の検査失敗はない。仕様集計は引き続き本節を Rust テストからの参照がない節として表示したが、終了状態は0である。指定した中心命題の強化以外に計画からのずれはない。独立レビュー・解析全体の証明・実ソースや VM との比較を今回の検査成功で代用しない。
