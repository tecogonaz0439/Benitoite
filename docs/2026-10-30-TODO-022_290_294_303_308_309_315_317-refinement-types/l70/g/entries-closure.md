# 担当 entries-closure の記録（7入口の依存の閉包の照合）

時刻は JST。開始 2026-11-07 08:10、終了 2026-11-07 08:20。ソースは変えていない。git の状態は変えていない。`scripts/check.sh`・`check-formal.sh` は実行していない。`<scratch>` は取りまとめの作業用の一時領域を表す。

## 変えたファイル

| ファイル | 内容 |
|---|---|
| [entries_closure.py](entries_closure.py)（新規） | 照合の台本。確認用の .lean は台本が入口ごとに `<scratch>/g/entries-closure/` に作る |
| [entries-closure.json](entries-closure.json)（新規、51,668 バイト、SHA-256 `18dac94e…5256`） | 結果の要約 |

## 方法

- 照合の前後に、共有ロックの下で `lake build --no-build`（既定の対象。書き込みなし）を実行し、両方とも終了0（`All targets up-to-date (2337 jobs).`）を確かめた。既定ビルドの .olean だけを読み、`-o` は使っていない。
- 照合の前後で作業木の状態（HEAD `eb4f0ef9`、`formal/` の未コミット差分 88,867 バイト SHA-256 `bc43010d…0192`、未追跡5ファイル SHA-256 `d263cdf5…060d`）が一致した。結果はこの状態についてのものである。並行する担当が `formal/` を変えた後は、台本を同じ引数で再実行すれば作り直せる。
- 入口ごとに `import <根>` の確認用の .lean を作り、単独の Lean の順番のロックの下で `lake env lean -M 12288` で実行した。`main` から幅優先で辿る辺は、型と値（不透明な定数の値を含む）に現れる定数、`._unsafe_rec`、`implemented_by` の先、コンパイラの `csimp` の置き換え先、帰納型から構成子と構成子から帰納型である。`csimp` の定理は辿らず、名前だけを記録した（各入口24〜35件、すべて `List.map → List.mapTR` などの Lean の標準の置き換え）。担当 coverage-entries の照合より辺が多いので、定数の数は同じ入口で多い（例: builtinCheck 9,103 → 9,576）。
- 違反の経路は、各定数を最初に見つけた辺を `main` まで辿った連鎖で示す。(d) の当たりには、閉包の中でその名前を読む宣言と辺の一覧も添えた（JSON の `d_detail`）。
- 入口のソースが直接書く完全名は、入口の根と、その import の閉包のうち `Benitoite` の外のモジュール（`SurfaceCheck.All` では All・Validation・Batch・Walk）の本文から、コメントを除いて文字で数え、Lean で所属モジュールを引いて同じ基準で分けた。

## 結果

| 入口 | 閉包の定数 | モジュール | (a) 旧 Surface（定数） | (b) 旧 Release のモジュール／定数 | (c) Core | (d) 旧の名前 | ソースの完全名（違反） | 生の出力（バイト、SHA-256 の先頭） | 所要・最大常駐量 |
|---|---|---|---|---|---|---|---|---|---|
| desugarDiff | 10,765 | 213 | 0 | 12／307 | 0 | `Const` | 3（0） | 1,301,969 `ff86787d…` | 1.7秒・1.90 GB |
| builtinCheck | 9,576 | 205 | 0 | 14／359 | 0 | `Const`・`Ty.lazy` | 6（0） | 1,100,968 `39a5fa80…` | 1.4秒・1.90 GB |
| coverageDiff | 9,602 | 199 | 0 | 11／269 | 0 | `Const` | 12（0） | 1,117,917 `3207fd04…` | 1.4秒・1.90 GB |
| coverageProgramDiff | 9,815 | 207 | 0 | 11／269 | 0 | `Const` | 7（0） | 1,150,520 `b5d89833…` | 1.4秒・1.91 GB |
| surfaceCheck | 21,569 | 666 | Syntax 21 | 18／656 | 0 | `Const`・`Ty.lazy` | 10（0） | 3,338,268 `32706406…` | 2.1秒・1.98 GB |
| surfaceCheckAll | 21,610 | 663 | Syntax 21 | 18／656 | 0 | `Const`・`Ty.lazy` | 17（0） | 3,337,712 `b8af4ef9…` | 3.1秒・1.99 GB |
| intervalDiff | 22,085 | 439 | Syntax 334・FormatSpec 32 | 19／656 | 0 | `Const`・`Ty.lazy` | 1（0） | 3,039,607 `35d33948…` | 11.3秒・2.20 GB |

台本の全体の所要は外側で約1分45秒（ロックの待ちを含む）。全 SHA-256 は JSON にある。

- (a) 違反0。現れる旧 Surface は `Surface.Syntax`（7入口のうち3つ）と `Surface.FormatSpec`（intervalDiff）だけで、`BuilderSyntax` は現れない。surfaceCheck の経路は `CheckInput.prepare` → `BuiltinAgreement.standardSig` → `StandardModel.signature` → `StandardScalar.integerBinaryDelta` → `Interval.WidthBinary.apply` → `Surface.BinOp.intDiv`（区間の幅の演算子の構文）である。
- (b) 違反0。7入口の和集合で22モジュール（Atom・BuilderExec・BuiltinTable・Coverage・Effect・Lemmas.Canonical・Lemmas.Rename・LocalRef・ModelHttp・NoFail・Order の7つ・Subst・Syntax・TargetTable・Types・Typing）で、すべて残す74モジュールにある。
- (c) 違反0。
- (d) 依頼の基準（旧の完全名62・旧の判断62・旧主定理12・旧表層の主定理14、和集合88）では、2つの名前が11件（入口ごとの延べ）当たった。直していない。
  - `Benitoite.Release.Const`（`Release.Syntax` の帰納型、7入口すべて）。例えば desugarDiff は `main` → `run` → `compareInput` → `Exchange.desugar` → `Exchange.fromComp` → `fromComp._unsafe_rec` → `Exchange.fromPattern` → `fromPattern._unsafe_rec` → `Release.Const`、builtinCheck は `main` → `run` → `validate` → `Refinement.Builtins.mk` の型 → `Refinement.Val.lam` → `Refinement.Comp.match` → `Refinement.Arm.mk` の型 → 旧 `Release.Alt` → 旧 `Release.Pat.const` の型 → `Release.Const` で読む。
  - `Benitoite.Release.Ty.lazy`（`Release.Types` の旧の型の構成子。builtinCheck・surfaceCheck・surfaceCheckAll・intervalDiff）。builtinCheck は `main` → `run` → `validate` → `Exchange.toBuiltinDataDecl` の値 → 旧 `Release.Ty` → 構成子の辺で読む。surfaceCheck では `Refinement.embedTy` の場合分けも読む。intervalDiff は `Interval.Exchange.evalDefinition` と区間の走査（`BudgetScan`・`BudgetAnalysis`）が読む。
  - 両者とも群 A の判断の本体（`proper_judgments` の41）にも、旧主定理・旧表層の主定理にも入らない（JSON の `totals.d_proper_judgments_or_main` は0）。棚卸しの「旧の完全名」の表は構文の名前を含み、完全名の対照表（`l00a.06a/contracts.md`）は `Refinement.Const` を旧 `Release.Const` の略記として共有すると定め、`Refinement.Const.type` を `embedTy` と旧 `Const.type` の合成としている。所属の2モジュールはどちらも残す74モジュールにある。この2件を (d) の違反とみなすか共有の構文として除くかは、取りまとめの判断に委ねる。台本の `pass` は依頼の基準どおり厳しく判定して `false` である。
- 入口のソースが直接書く完全名: 計56件、違反0。builtinCheck の旧 Release の3件（`BoundSummary`・`dataSummaries`・`summariesConverged`）は残す `BuiltinTable` の共有の定義である。

## 止めずに進めた変更

なし（ソースは変えていない）。

## 残りと申し送り

- 結果は上の作業木の状態についてのものである。並行する担当（L70.40b〜.44）が入口の経路を変えた後と、L70.44 の削除の後に、同じ台本を再実行する必要がある。
- (d) の2件の扱い（上記）は取りまとめが決める。除く場合は、台本の旧の名前の集合から、残すモジュールに属する構文の名前を除く条件を足す。
