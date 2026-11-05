# L70.03 完全名の対照表と読者の棚卸し

2026-11-06。L70 群 A の実装担当（Claude、Opus 5.5）の記録であり、独立レビュー済みを意味しない。基準は B_WORK `243e4237b6775b9677676fcbc6ed5de216a5662a` の既定環境（群 A の宣言を足す前）である。

数と一覧の正は [inventory.json](inventory.json) である。台本 [inventory.py](inventory.py) が、`formal/` の全 Lean ファイルの import 行と、[graph.lean](graph.lean) の出力（宣言ごとの型と値に現れる定数）と、[L00a.06a の対照表](../../l00a.06a/contracts.md)から作り直す。graph.lean の生の出力は `<tmp>` に置いた（115,387,755 バイト、SHA-256 `0ff5d444161b479edfeaa5e7913d2e4f2b782b7e94aa89a7579282a3383d8500`、宣言 86,150）。手で数えた値はない。

以下、`Benitoite.Release.Refinement.` を「R.」、`Benitoite.Release.`（Refinement を除く）を「旧 Release」、`Benitoite.Surface.` を「旧 Surface」と書く。

## 1. 母集団

| 項目 | 値 |
|---|---|
| `formal/` の Lean モジュール（`.lake`・`tests` を除く） | 1,084 |
| 既定 import（`formal/Benitoite.lean`）の閉包 | 1,073。内訳は R. 750、旧 Release 109、旧 Surface 97、Interval 66、Core 16、Exchange 12、Scope 12、Checked 6、Shared 3、Library 1、根 1 |
| 既定 import の閉包の外の Benitoite のモジュール | `Benitoite.Release.LegacyCheck` の1つ。どの target からも読まれない。開始前からある（群 A では扱わず、L70.44 の削除の集合に入れる） |
| 既定環境の宣言（生成宣言・private を含む） | 86,150 |

## 2. 完全名の対照表の更新（L00a.06a の表）

L00a.06a の二つの表の旧の完全名62件（旧 Release）と新しい完全名の組を、今の既定環境で照合した。

- 旧の完全名62件はすべて既定環境にある。新しい完全名もすべて既定環境にある（予約のまま残る行はない）。
- 旧の完全名を、旧 Release・旧 Surface・Core の外から読む宣言は、R. の埋め込みの宣言（名前の成分が `embed` か `Legacy` で始まるもの、`Legacy*`・`Embedding` のモジュール）と、次の一つのモジュールだけである。
- 62件のうち判断の本体（型付け・遷移・継続・状態・ストア・網羅性・部分型・被覆・宣言とプログラムの型付けの41件。inventory.json の `proper_judgments`）を、埋め込みでない R. の宣言が**直接**読む箇所は0件である（`backflow` が空）。ただし推移の閉包では0件でない（下の「逆戻りの推移の照合」）。残りの21件（`Const`・`Program`・`Builtins`・`Ty.WF`・正規化・`PatTy` など）は構文と共有の定義であり、R. の `Const` は旧 `Const` の略記である（L00a.06a の決定）。
- 例外の `R.CurrentSignatureRows` は、旧三モデル（`Model`・`ModelTargets`・`ModelHttp`）と旧 `Examples` の組み込みの表の署名の行を新しい署名と並べ、旧三モデルの `assumptions`（旧主定理）を読む。

### 逆戻りの推移の照合（RV-L70.a 重1 の処置で足した）

旧判断の本体の41件へ、埋め込みの宣言（名前の成分が `embed`・`Legacy` で始まるもの、`Legacy*`・`Embedding` のモジュールの宣言）を通らずに辿れる宣言を、宣言の依存の逆向きの到達で求めた（inventory.json の `backflow_transitive`。各宣言に最短の経路の例を記す）。新判断の宣言で当たるのは次の4件だけである。

| 新判断の宣言 | 経路 |
|---|---|
| `R.CurrentSignatureRows.model_rows` | → `Release.Model.assumptions` → `Release.HasTypeV` |
| `R.CurrentSignatureRows.model_targets_rows` | → `Release.ModelTargets.assumptions` → `Release.HasTypeV` |
| `R.CurrentSignatureRows.model_http_rows` | → `Release.ModelHttp.assumptions` → `Release.HasTypeV` |
| `R.CurrentSignatureRows.target_entries_rows` | → `Release.TargetTable.entries_scoped` → `Release.Model.assumptions` → `Release.HasTypeV` |

4件はいずれも旧三モデルの `assumptions`（旧主定理）を経る。処置は L70.44 で4件を除く（旧三モデルと `TargetTable` の署名の行の照合の役割は、新しい三モデル（C07）と合成表の行の照合が持つ）。

## 3. 旧主定理・旧表層の主定理の読者

| 旧の名前 | 件数 | 旧の外の読者 |
|---|---:|---|
| 旧 Release の主定理（`Theorems` の8件と `Lemmas.TargetStep` の `step_target_sound`） | 9 | なし |
| 旧三モデルの `Model.assumptions`・`ModelTargets.assumptions`・`ModelHttp.assumptions` | 3 | `R.CurrentSignatureRows` の `model_rows`・`model_targets_rows`・`model_http_rows` |
| 旧表層の主定理（`desugar_typed`・`surface_effect_soundness`・`surface_target_sound`）と checker の健全性（`CheckProgramSound` の11件） | 14 | なし（7入口の実行ファイルも定理を読まない） |

L70.44 で旧主定理を削除するとき、`R.CurrentSignatureRows` の三モデルの行（3定理）を除くか、新しい三モデル（C07）の行へ替える。

## 4. 7入口の経路

入口の実行ファイルのモジュールは既定環境の宣言の書き出しに入らないので、入口のソースが直接書く完全名を文字で数えた（inventory.json の `entry_refs`）。モジュールの閉包は import 行から求めた。

| 入口（根） | 閉包のモジュール数 | 直接の import | 入口が直接読む旧の名前 |
|---|---:|---|---|
| desugarDiff（`DesugarDiff.Main`） | 183 | `Exchange.Convert` | なし（交換の名前だけ） |
| builtinCheck（`BuiltinCheck.Main`） | 184 | `Exchange.Builtins` | 旧 Release の `BoundSummary`・`dataSummaries`・`summariesConverged`（`BuiltinTable` の共有の定義） |
| coverageDiff（`CoverageDiff.Main`） | 184 | `Release.CoverageShow`・`Exchange.Convert` | 旧 Release の `CoverageShow` |
| coverageProgramDiff（`CoverageProgramDiff.Main`） | 185 | `Exchange.Builtins`・`Release.CoverageShow` | 旧 Release の `Arm`・`CoverageShow` |
| surfaceCheck（`SurfaceCheck.Main`） | — | `Exchange.CheckInput` | 旧 Surface の `CheckAccept.checkProgramAccepted`・`Check.checkDef`・`CheckAccept.acceptDef`・`CheckAccept.AcceptInput`・`EntryError`・`Check.Input`・`Check.Error`・`CheckTables` |
| surfaceCheckAll（`SurfaceCheck.All`→`Validation`→`Batch`→`Walk`） | — | `SurfaceCheck.Validation` | 旧 Surface の `Check.checkDef`・`checkImpl`・`checkBlock`・`CheckAccept.acceptDef`・`acceptMethod`・`AcceptInput.noRules`（`Validation`）・`CheckTables`・`CheckTools`・`ScopeAccept.allOk`・`Expr` |
| intervalDiff（`IntervalDiff.Main`） | — | `Interval.Exchange` | なし（区間の交換の名前だけ） |

どの入口の閉包にも旧 Surface の74モジュールと旧 Release の89〜90モジュールが入る（`Exchange.Convert`・`CheckInput` が旧 Surface を import するため）。`surfaceCheckAll` の `Validation` は試験の補助の `AcceptInput.noRules` を読む（L70.31b で実入口に使わない形へ替える）。

## 5. 層の分類と受持単位

分類は宣言の依存で決めた。「旧の判断を読む」は L00a.06a の旧の完全名か旧 Surface の検査・判断（`Syntax` 以外の旧 Surface のモジュール）を読むこと、「旧表層の構文を読む」は旧 Surface の `Syntax` だけを読むことである。

| 層 | 分類 | 受持単位 |
|---|---|---|
| `Exchange.Convert`（1,031行） | 移植（旧表層の構文と `CheckTables` を読む） | L70.40a |
| `Exchange.Syntax`・`Exchange.Range` | 継承（旧を読まない。ただし `Syntax` は旧 Surface の `Desugar` を import する。宣言は読まないので import を除く） | L70.40a（新しい版の構文は L70.08 で別に置いた） |
| `Exchange.Version` | 継承（旧 Release の `CoverageView` だけを読む）。旧版の読み分け（版8〜15・2〜7）は J70-1 で除く | L70.42・.44 |
| `Exchange.CheckInput`（`prepare`・`Prepared`） | 移植（旧 Surface の `CheckTables`・`Check`・`CheckAccept` と旧 Release の `BuiltinTable`・`Coverage` を読む） | L70.40b |
| `Exchange.Builtins` | 移植（旧 Surface と旧 Release の `BuiltinTable` を読む） | L70.40b |
| `Exchange.Observe` | 移植（旧 Surface の `CheckAccept` を読む） | L70.40b |
| `Exchange` の例（`BuilderExamples`・`FormatExamples`・`IntegerExamples`・`ObserveExamples`・`RangeExamples`） | 移植（`RangeExamples` は旧 Release の共有の定義だけ） | L70.40a・.40b |
| 旧 Surface の `CheckTables`・`CheckTablesSound`・`CheckAccept` | 削除（新しい表層の checker・受理へ置き換える） | L70.31b（受理）・L70.40b（表） |
| 旧 Release の `CoverageShow`・`Coverage` | 移植（入口が旧 Release の網羅性の判定の表示を読む。新しい網羅性 L70.32 の表示へ替える） | L70.40b |
| `Interval` の66モジュール（34,669行） | 移植58（旧の判断・旧表層の検査を読む21・20,234行、旧表層の構文だけを読む37・13,195行）、継承8（旧を読まない7・旧 Release の共有の定義だけ1） | L70.43（**計画より広い**。下の注） |
| R. の旧表層を読む9モジュール | `IntervalConnection`・`IntervalConnectionExamples`・`IntervalFailure`・`IntervalFlowLeaves`・`IntervalControlLeaves`・`FirstFailure`・`StandardIntegerFailure`（旧 Surface の `Expr`・`Arms`・`BinOp` などの構文を読む）、`ExternalSurfaceLeaves`・`ExternalLeafSelection`（旧 Surface の `recordFields`・`fieldAt`） | 区間の7つは L70.43、外部の2つは L70.25（脱糖の並べ替えの補助を新しい表層へ） |
| `Scope.CompatExamples` | 旧 Surface の `Lemmas.Sequence` を import する例 | L70.44 |

注（計画との差）: detail.md の L70.43 は `Interval/Exchange.lean`・`Interval/Identity.lean` の移植だけを挙げるが、区間解析の本体（`Interval` の58モジュール）が旧 Surface の構文（`Surface.Syntax` の定数への参照 73,150）の上で定義されている。J70-5 で旧 Surface を全て削除するには、この58モジュールと R. の区間の7モジュールを新しい表層の構文へ移す必要がある。移さずに旧 Surface の `Syntax` だけを残す代案は J70-5 の削除の範囲を狭めるので、取りまとめに判断を求める（results.md「取りまとめに判断を求める点」）。

## 6. 削除の集合と残す旧 Release

**取り直した結果（RV-L70.a 重1 の処置）**。初版は必要な宣言の所属モジュールを選んだだけで、選んだモジュールの残りの宣言を閉包へ加えていなかった。残すモジュールの全宣言を根にして、削除先への依存がなくなるまで残す側へ加える不動点で取り直した（inventory.json の `fixpoint`、5回で収束）。

- 残す側の初期の集合は、新判断・Scope・Checked・Shared・Library・交換・区間の全モジュールと、取りまとめの判断(1)で区間解析の入力の構文として残す旧 Surface の構文（`Surface.Syntax`・`BuilderSyntax`・`FormatSpec`）である。
- 旧主定理（旧 Release の9件・旧三モデルの3件）と旧表層の主定理14件は残さない（FORBIDDEN）。これを推移的に読む残す側の宣言は「変える宣言」として閉包の根から外す。
- 旧 Surface の構文以外と Core への依存は「読者の移植」として数え、削除の集合を広げない。

| 区分 | モジュール | 行 |
|---|---:|---:|
| Core（J70-7） | 16（全体） | 2,505 |
| 旧 Surface（構文の3を除く） | 94 | — |
| 旧 Release | **35** | 7,882 |
| 旧 Release の既定 import の外の `LegacyCheck` | 1 | — |

残す旧 Release は**74**である（初版の50に、`Admissible`・`SubstEnv`・`ShapeOk`・`ModelTargets`・`LocalTyping` と `Lemmas` の15モジュールなどの24を加えた。一覧は `fixpoint.keep_release`）。区間解析の構文を残す判断(1)だけのために残る旧 Release のモジュールは0である（`kept_only_for_surface_syntax`。構文の import 先は交換・区間も読むため）。

削除する旧主定理のうち、残すモジュールにあるのは旧三モデルの `Model.assumptions`・`ModelTargets.assumptions`・`ModelHttp.assumptions` の3件である（`Theorems` と `Lemmas.TargetStep` は削除するモジュールに入る）。この3件を除くと、残すモジュールの次の宣言が推移的に読めなくなる（`fixpoint.change_release_declarations`・`change_other_declarations`）。

| モジュール | 変える宣言 |
|---|---|
| `Release.TargetTable` | `entries_scoped`・`sig_scoped`（2） |
| `Release.ModelTargets` | `check_scoped`・`ref_scoped_get`・`ref_scoped_set`・`write_scoped` と `Examples` の14宣言（計18） |
| `Release.ModelHttp` | `check_scoped`・`send_scoped`・`value_scoped` と `Examples` の7宣言（計10） |
| `R.CurrentSignatureRows` | `model_rows`・`model_targets_rows`・`model_http_rows`・`target_entries_rows`（4） |

旧 Release の変える宣言は30、加えて旧三モデルの `assumptions` 3件そのものを除く。これらは旧主定理を読む例と、旧の署名の表が旧主定理から範囲を得る補題であり、新判断・交換・区間は読まない。残すモジュールの import から削除するモジュールへの辺は11である（`fixpoint.import_cuts`。旧 Release の中は `Model → Theorems`・`ModelHttp → Lemmas.PrimRanges`・`ModelHttp → Theorems`・`ModelTargets → Lemmas.PrimRanges` の4）。

取りまとめの判断(4)（「削除は宣言の閉包で行い（旧 Release 59 モジュール）、残すモジュールの import の行だけを除く」）は、この取り直しでは成り立たない。成り立つ形は次のどちらかである。

1. 残す旧 Release を74モジュールとし、削除は35モジュールにする。import の行（11辺）に加えて、`Release.TargetTable`・`ModelTargets`・`ModelHttp`・`Model` の4モジュールで上の33宣言（変える30と旧三モデルの `assumptions` 3）を除き、`R.CurrentSignatureRows` の4宣言を除く。さらに下の「宣言のグラフに現れない参照」の8件を加える。旧 Release の本文の変更は、旧主定理とそれを読む例・補題・`open` の名前の削除に限られる。
2. 旧 Release の本文を変えないなら、旧三モデルの `assumptions` 3件を残すことになる。これは旧主定理を残すことで帳尻を合わせる形であり、採らない。

### 宣言のグラフに現れない参照（RV-L70.a 再重1 の処置で足した）

環境の定数の型と値のグラフは、匿名の `example`、宣言の本体の外の `open`・`export`・`attribute`・`#check` などのコマンド、証明の中で項に残らない参照（使われない `simp` の引数など）を含まない。残すモジュール935（旧 Release 74・旧 Surface の構文3・新判断・Scope・Checked・Shared・Library・交換・区間。群 A で足したモジュールを含む）のソースを走査し、これらの中の削除対象への参照を列挙した（inventory.py 第12節、inventory.json の `source_scan`）。

- 削除対象は、削除するモジュール（旧 Release 35・旧 Surface の構文以外94・Core 16・`LegacyCheck`）の宣言と、残すモジュールから除く37宣言である。
- 識別子は、そのファイルの名前空間と、選択でない `open` で解決し、削除対象に当たり残す宣言に当たらないものを参照とした。名前空間の `open` は、その名前空間の宣言が一つ以上あり全て削除されるときだけ参照とみなした。選択の `open N (a b)` は、指定した名前ごとに照合した。
- コメントと文字列・文字の定数は除いた。証明の中の参照は、除く宣言の本文の行、グラフに現れる参照（移植する読者の辺）、ファイルの中で局所の名前として束縛する綴りを数えない。

| 構文 | 件数 | 箇所と参照先 |
|---|---:|---|
| 匿名の `example` | 4 | `Release.Model` の150行（`Model.assumptions`・`Release.effect_soundness`）、310行（同）、350行（`Model.assumptions`）、439行（削除する `Lemmas.Preservation` の `Ty.Le.fn_fn'`） |
| `open` | 4 | `Release.ModelHttp` の44行（選択の `open Benitoite.Release.ModelTargets (…)` の `ref_scoped_get`・`ref_scoped_set`）、`Exchange.CheckInput` の8行（名前空間 `Surface.CheckTables`）、`Exchange.Observe` の23行と `Exchange.ObserveExamples` の12行（名前空間 `Surface.ScopeAccept.CoverFailure`） |
| `export` | 0 | — |
| `attribute` | 0 | — |
| `#check` などのコマンド | 0 | — |
| 証明の中の参照 | 0 | — |

L70.44 の削除の指定に、次の8件を加える。

1. `Release.Model` の匿名の `example` 4件（150・310・350・439行）を除く。
2. `Release.ModelHttp` の44行の選択の `open` から `ref_scoped_get`・`ref_scoped_set` の2名を除く（`open` の行は残す）。
3. `Exchange.CheckInput`・`Exchange.Observe`・`Exchange.ObserveExamples` の3件の `open` は、移植する読者（L70.40b。`fixpoint.port_edges` の読者）の側で、旧 Surface の名前空間を除く。

これで、旧 Release の本文の変更は、33宣言・匿名の `example` 4件・`open` の2名の削除になる。

判断(1)との関係: 旧 Surface の構文の3モジュールを残しても、残す旧 Release の数は変わらない（上記）。旧 Surface の構文以外を読む交換・区間・新判断の16モジュール（`fixpoint.port_edges`）は、L70.40a・.40b・.43・.25 で新しい表層又は残す構文へ移す読者であり、削除の集合とは別に扱う。

### 初版の算出（参考）

初版は残す旧 Release を50（C05 の閉包31・共有19）、削除を59（14,037行）、import の辺を26とした。残すモジュールの宣言本体が削除先を読む（例: `EffectCover` の `Eff.Covers.substRho` が `SubstEnv` を、`ModelHttp` の `Examples.httpCons` が `ModelTargets` の宣言を読む）ので、import だけを除く形では実行できない。この値は inventory.json の `keep_release`・`delete`・`import_cuts` に残し、削除の指定には上の取り直しを使う。

## 7. `admit` の名前（TODO-294、O116）

既定環境に最後の成分が `admit` の宣言は0件、`formal/` のソースに単語 `admit` の行は0件、01-12・07-04 にも0件である。改名の残りの読者はない。L70.44・.45 は削除の後に同じ検索を繰り返して確かめる。

## 8. 申し送りの照合（plan-RV03・plan-RVat）

tables.md の plan-RV03 と plan-RVat は、L70.03 の棚卸しで内容を照合するとされている。

| 申し送り | 元の内容 | 今の既定環境 | 残り |
|---|---|---|---|
| plan-RV03（l00b.03/signatures.md の L20/L70 の義務） | 全本体の導出を宣言と照合して最終の `Program.WellTyped` にまとめること、`TypeArgsKindedAt` の型の shift と置換（軽5） | `R.Program.WellTyped`、`R.TypeArgsKindedAt.shift`・`subst`・`forget` が既定環境にある | 開始の定理（L70.14）が `Program.WellTyped` を前提に読むことは群 B で確かめる |
| plan-RVat（RV-L00b.02b-at 軽1） | At のエラーの七つの String 欄が `reprStr` の出力で、処理系の文言と対応させられないこと | 群 U で七欄を除き、九欄の公開形 `R.Detail.publicTree` へ替えた（`Detail.textFields` は既定環境にない） | 公開形と処理系の値・Show・JSON の照合は R30・R60（群 U の申し送り）。効果の pathBases の場合（L70.15）は群 B |
