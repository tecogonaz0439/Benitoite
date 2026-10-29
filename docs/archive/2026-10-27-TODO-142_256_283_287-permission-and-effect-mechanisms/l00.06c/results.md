# L00.06c の結果（案 (ii) を暗黙の変換なしで数え直す）

作業 L00.06c（plan「計画の変更」の L00.06 の行、[l00.06/results.md](../l00.06/results.md)「追加の点検の提案」の L00.06c）の記録である。採用を決めない。記録の `<wt>` は作業用のディレクトリ、`<repo>` は本線のディレクトリ、`<home>` はホーム、`<scratch>` は担当の一時ディレクトリを表す。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L00.06c。L00.01 の案 (ii) の最後の差分 `l00.01/candidate-ii/trial-15.diff` から `String` からの暗黙の変換（`Coe`）を外し、旧の綴りを明示の Top の構築関数で書き直して、破損を数え直す。L00.06 の提案のとおり、資源の型を Top の添字に限る形（L00.03 の申し送り 3）も同時に当てた |
| 基準 | B_WORK `91c9af89163fc08103efebf8642607bf05aee06c`（作業用のディレクトリの HEAD と同じ）。B0 から `formal/` に加わったのは `Scope/` の模型7ファイルと既定 import の8行だけで、`trial-15.diff` はそのまま当たった |
| 閉じた範囲 | 試行（比較用ビルド14回）で既定の全入口が終了0、未検査0。`Atom.code_injective` を証明した（sorry なし）。宣言・ファイル・診断の件数、明示の構築関数へ書き直した箇所の数、L00.01 の変換に頼る箇所の数との照合、案 (i) の系列 C との比較表。試行の取り消しと受け渡す状態の既定ビルド |
| 未完の範囲 | `preservationE` の `E_OpPrim` は依頼どおり sorry のまま残した（L00.06b が案 (i) で同じ論点を試している）。試行の最後の状態は sorry 1 件を含むので、成功とは数えない |

## 試行の内容

`trial-15.diff` を当てた後、次を変えた。最後の差分は `trial-14.diff`（基準からの累積、60ファイル、+736/−365。うち本番57ファイル +660/−326、比較用の模型3ファイル +76/−39）、L00.01 の最後からの差は `delta-from-trial15.diff`（43ファイル、+456/−263）である。

| 対象 | 変更 |
|---|---|
| `Release/Atom.lean`・`Types.lean` | `instance : Coe EffBase EffName` と `instance : Coe String OpaqueName` を消し、`abbrev EffName.top (s : EffBase) : EffName := ⟨s, .top⟩` と `abbrev OpaqueName.top` を置いた。期待型があれば `.top "IO"` と書ける。`Eff.single` は `EffName → Eff` のまま変えていない |
| 資源の型（L00.03 申し送り 3） | `release_exists`・`ContTy.K_Release`・`HasTypeCQ.C_Use`・`FramesOk`・`ContTy.inv_release`・`prepend_releases`・`HasTypeCQ.inv_use`・Surface の `E_With` を、`o.base` で引く形から `.opaque (.top o)` と `B.isResource o`（`o : String`）の形へ戻した。検査器 `checkExprR` の `withE` は `o.index == .top && isResource o.base` を求め、`CheckSoundControl.with_case` で添字を Top に定めてから規則を当てる |
| `Release/Order/Atoms.lean` | `Atom.code_injective` を証明した。L00.01 の `scopeChars` による符号化は単射でない（範囲の要素が `'\u0000'` を含めば `pathExact ["a\u0000b"]` と `pathExact ["a", "b"]` が同じ文字列になる）ので、符号化を替えた。基数 `codeBase + 2` の桁の列で、文字の桁（1〜`codeBase − 1`）と二つの区切りの桁（名前と範囲の区切り、範囲の要素の終わり）を分け、区切りでの分割の補題と要素の列の補題で単射性を示した（新しい宣言17、うち補題11） |
| 旧の綴りの書き換え | 失敗したファイルの中で、`.name "…"`・`Eff.single "…"`・`.opaque "…"`・`.withE "…"`・`.name stateEff`・`Eff.single stateEff`・`Eff.single od.eff`・`.name d.eff` を `(.top …)` へ置き換えた（`tools/fixtop.py`。置き換えの数は `fixtop-tally.jsonl`）。型の誤りの位置だけでなく、失敗したファイルの中の同じ綴りを一度に置き換えた。手で直したのは、`io_op` の `Eff.single (.top l)`、`PrimSig.inst_eff_single` の仮定、`LogExamples.operation`、`Surface/Examples` の `mem_single (.top "Read")` 2件、`BudgetChildrenExamples` の比較 1件、交換の旧版の読み込み `Exchange/Convert` の3件（原子・不透明型・`withE` を Top として読む）である。置き換えの道具が交換の側の自前の原子（`String`）まで置き換えた1件は戻した |
| 比較用の模型（L00.01 の後に置いたもの） | `RepresentationExamplesI` は本番の名前の型が構造体になったので、符号を `Release.Atom.code (.name l)` の対にし、単射性を本番の補題から得た。リテラルを `.top` で書いた。`RepresentationExamplesII` は旧の名前だけの原子を模型の中の `OldAtom` に写した（本番の `Release.Atom` が既に範囲を持つため）。`CompatExamples.embII` は本番の原子と模型の原子の全単射（`atomII`・`atomRel?`）で作り直した。模型の言明の意味は「旧の原子＝範囲のない原子」から「本番の原子」へ変わるので、模型の結論は案 (ii) を当てた状態では L00.01〜.06 のものと同じ意味ではない（L00.08 で模型は削除される） |

## 比較用ビルドごとの終了・時間・件数

各ビルドは `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>`（既定の全入口、lakefile の `-M 12288`）。「時間」は `/usr/bin/time -l` の real（秒）、「待ち」は排他の待ち（秒）。「未検査」は失敗したモジュールを推移的に import するため検査されなかったモジュールの数で、既定の全入口の閉包は 274 モジュールである（L00.01 の `breakage.py` をそのまま使った。`tools/breakage.py`）。

| ビルド | 直した群 | 終了 | 失敗 | 未検査 | 診断 | ファイル | 宣言 | 時間 | 待ち | RSS（MiB） |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 00 基準 | 変更なし | 0 | 0 | 0 | 0 | 0 | 0 | 0.15 | 162 | 66.1 |
| 01 | 変換の除去・資源の Top・Surface の with | 1 | 3 | 215 | 44 | 3 | 15 | 11.19 | 0 | 752.7 |
| 02 | Typing・模型 I/II・`code_injective` の証明 | 1 | 3 | 189 | 8 | 3 | 6 | 21.41 | 0 | 1429.1 |
| 03 | BuiltinTable・Semantics・Inversion | 1 | 3 | 186 | 15 | 3 | 6 | 9.10 | 1 | 1649.7 |
| 04 | Assumptions（`io_op` を含む）・Examples・FailureBase | 1 | 2 | 178 | 15 | 2 | 8 | 11.55 | 0 | 1015.5 |
| 05 | ContLemmas・Coverage | 1 | 5 | 99 | 23 | 5 | 7 | 117.54 | 0 | 1591.1 |
| 06 | Preservation・Surface/Typing | 1 | 9 | 74 | 69 | 9 | 30 | 20.23 | 129 | 1244.8 |
| 07 | PresBase・CompatExamples（リテラル）・Surface/Check・FiniteExamples・NoFailCheckExamples | 1 | 7 | 69 | 22 | 7 | 8 | 5.35 | 2 | 833.4 |
| 08 | `embII`・Interval の例・Progress・Check・CallHead | 1 | 7 | 47 | 48 | 7 | 35 | 11.40 | 7 | 1395.3 |
| 09 | Convert・Model・CheckComputeControl など7ファイル | 1 | 4 | 36 | 17 | 4 | 8 | 9.23 | 0 | 1397.1 |
| 10 | CheckSoundBasicExpr・CheckSoundDie・Surface/Lemmas/Typing | 1 | 3 | 27 | 19 | 3 | 12 | 21.81 | 0 | 1396.4 |
| 11 | Surface/Examples（リテラル） | 1 | 3 | 27 | 7 | 3 | 6 | 4.30 | 24 | 1395.0 |
| 12 | Convert の読み込み・`with_case`・Examples の `mem_single` | 1 | 5 | 2 | 132 | 5 | 83 | 12.25 | 0 | 1505.4 |
| 13 | BuilderExamples・CheckExamples・FailureExamples・LogExamples・Validation | 1 | 1 | 1 | 11 | 1 | 9 | 6.43 | 0 | 1353.6 |
| 14 | LogExamples の `operation` | 0 | 0 | 0 | 0 | 0 | 0 | 7.11 | 0 | 2534.1 |

「直した群」は、そのビルドの前に当てた修正である。ビルド 14 の出力の sorry の警告は `PresMain.lean` の `preservationE` の1件だけである。全出力は `build-NN-trial.log`、宣言・ファイル・未検査の一覧は `count-NN.json`、各ビルドの前の累積の差分は `trial-NN.diff` に置いた。ビルドが速いのは、`formal/.lake` が本線のビルド済みの生成物の写しで、変えたファイルの下流だけを作り直したためである。

一回のビルドで見つかる破損は、失敗した import の先が未検査で残るため、全体の破損の総数ではない（ビルド 01 は 215 モジュールが未検査）。全体の規模は、各ビルドの破損の和と、最後の差分の宣言の分類で読む。

## 件数の集計

集計は `tools/count06c.py`（宣言の区切りと言明・本体の境目は L00.06 の `tools/classify.py` と同じ字句の近似）。出力は `counts.json`。明示の Top の構築関数（案 (ii) の `(.top x)`、案 (i) の `nameTop`・`opaqueTop`）を旧の綴りへ戻すと旧と一致する変更を「Top の構築関数だけ」と数えた。

### 比較用ビルドで壊れたもの（ビルド 01〜13 の和、重複を除く）

| 区分 | 宣言 | ファイル | 診断の和 |
|---|---:|---:|---:|
| 本番（`Scope/` 以外） | 183 | 37 | 367 |
| 比較用の模型（`Scope/` の3ファイル） | 18 | 3 | 63 |
| 合計 | 201 | 40 | 430 |

183 宣言には名前のない `example` を行番号で数えたものを含む（CheckExamples など例のファイルが多い。ビルド 12 の 83 宣言の大半）。

### 最後の差分の宣言（`trial-14` と基準、本番だけ）

| 区分 | 宣言 |
|---|---:|
| 変えた既存の宣言 | 190（ファイル 55） |
| 言明の字面の変更 | 96（定理 34） |
| うち Top の構築関数だけ | 70（定理 28） |
| 言明の実質の変更 | 26（定理 6） |
| 本体だけの変更 | 92（うち Top の構築関数だけ 59） |
| 新しい宣言 | 45 |
| 消えた宣言 | 2（`abbrev EffName`・`abbrev OpaqueName` が構造体へ替わった） |

言明の実質の変更 26 は、すべて L00.01 の `trial-15` の言明の変更 32 に含まれる。L00.01 から実質の変更でなくなった 6 宣言は、資源の型を Top に限ったことで Top の構築関数だけの変更へ下がった `ContTy.inv_release`・`prepend_releases`・`HasTypeCQ.inv_use`・`ContTy`・`HasTypeCQ`・Surface の `HasTypeQ` である（L00.06 の「資源の 4 件は字面だけへ下がる見込み」を確かめた）。残る実質の変更は次のとおりである。

- 定理 6: `ContTy.end_of_noHandler`（名前を `EffName` に一般化）、`HasTypeVQ.inv_prim`・`inv_prim_app`・`PrimitiveAdmissible.outer`・`.substTy`・`progress_io`（署名の具体化 `s.inst R`。L20 の内容）
- 前提: `Builtins.Assumptions`（`delta_typed`・`io_typed`・`io_exists` の `∀ R` の量化と `io_op` の対象の位置の連言。`release_exists` は基準と同じ意味に戻り、字面は `.opaque (.top o)`）
- 定義・構造体 19: 表の鍵を元の名前にした `OpDecl`・`Program`（Release・Surface）・`Declarations`・`Builtins`・`OpSig`・`effOps`・`PrimSig`・`HasTypeVQ`（`V_Prim` の R）・`stateEff`（`EffBase`）・`Release/Examples.sig`、`CheckTables` の 6 件、`Exchange/Builtins` の 2 件

Top の構築関数だけの言明の変更 28 定理は、`handled_state`・`ContTy.state_end`・`ContTy.inv_release`・`ContTy.inv_drop`・`ContTy.prepend_releases`・`ContTy.drop_releases`・`captureEff_state`・`HasTypeVQ.inv_op`・`HasTypeCQ.inv_use`・`refUpdate_typed`・`inv_op_app`・`no_unhandled_user`・`single_no_rho`・`checkDieExit_contains`・`checkDieExit_sound`・`resultDie_typed`・`HasTypeQ.inv_opDicts`・`op_dicts_typed`・`op_value_typed`・`DieExitOk.app_typed`・`dieFailure_typed`・`tryResultDie_typed`・`tryOptionDie_typed`、Log の例の 5 件である。

### 明示の構築関数へ書き直した箇所

L00.01 の最後（`trial-15`）から加えた `(.top …)` は 289 か所・230 行・38 ファイル（本番 257 か所・209 行・36 ファイル、模型 32 か所・21 行・2 ファイル）。

L00.01 の案 (ii) が挙げた変換に頼る箇所と照らした（基準の `Scope/` を除く。正規表現が L00.01 と少し違うので基準の数が 1 ずつずれる）。

| 綴り | L00.01 の数（B0） | この枝の基準での数 | 最後の状態で明示の Top にした行 | 旧の綴りのまま残った行 |
|---|---:|---:|---:|---:|
| `.name "…"` | 36 行（13） | 35 行（13） | 34 行（12） | 1（交換の自前の原子 `Exchange/CheckInput`。`String` の型で正しい） |
| `Eff.single "…"` | 75 行（9） | 76 行（10） | 76 行（10） | 0 |
| `.opaque "…"` | 13 行（7） | 13 行（7） | 13 行（7） | 0 |
| `Eff.single <変数>` | 47 行（18） | 47 行（18） | 44 行（14） | 4（下の「黙った一般化」） |
| `stateEff` | 53 行（15） | 53 行（15） | 47 行（13）が `(.top stateEff)` | 6（`stateEff` の定義、`simp` の引数、`B.effects`・`P.effects` の鍵の引き。名前の原子を作らない箇所） |

数え方の差に注意する。案 (i) の系列 C は `Eff.single : String → Eff` を残し、Top の原子を関数の中で作った。この枝は `Eff.single : EffName → Eff` を変えなかったので、呼び出し側の 120 行（`Eff.single "…"` 76 行と `Eff.single (.top <変数>)` 44 行）を書き換えた。これを除いた本番の書き換えは約 90 行で、案 (i) の Top の構築関数の置き換え 104 行（35 ファイル）と同じ規模である。

### 黙った狭めと黙った一般化

- 黙った狭め: 変換を外したので、`String` の値が名前の記述として黙って Top に読まれる箇所はない。L00.01 の2件（Surface の `E_With`、`ContTy.end_of_noHandler`）は、前者は資源の型を Top に限る明示の変更、後者は `{l : EffName}` の明示の一般化として差分に残った。
- 黙った一般化: 名前の変数の型が推論で `EffName`（範囲を持つ）になった言明は、字面を変えずに意味が広がる。`Surface/CheckTools.singleEff_eq`（`singleEff atoms (.name l) = Eff.single l`）、`Release/TypeScopedSubst`（`Eff.substAt c ts es (Eff.single l) = Eff.single l`）、`Surface/CheckSupport.singleEff_eq_contains`、`Surface/Examples.canonical_single` の 4 行がこれに当たる。どれも任意の範囲で成り立つ等式で、ビルドが通った。意味が弱くなる方向ではないが、言明の対象が範囲付きの名前へ広がったことは差分に現れない。`BuiltinOnly` の `∃ l, a = .name l ∧ …` も同じく範囲付きの名前を許す形になった（`trial-15` から。L00.01 の申し送り 2 の `BuiltinOnly` の拡張に当たり、案 (ii) では字面の変更なしに起こる）。

## 案 (i) の系列 C との比較

同じ道具（`count06c.py`）で、基準の写しに各案の最後の差分を当てて数えた。案 (i) の系列 C の破損の和は L00.01 の `candidate-i/broken-union.json`、案 (ii) の L00.01 の和は `candidate-ii/count-*.json`（07a を除く）を同じ方法で数えた。

| 観点 | 案 (i) 系列 C（`trial-30-final`） | 案 (ii) L00.01（`trial-15`、暗黙の変換あり） | 案 (ii) L00.06c（`trial-14`、変換なし） |
|---|---|---|---|
| 全体のビルドが通った最後の差分 | 56 ファイル、+251/−166 | 36 ファイル、+305/−127 | 本番 57 ファイル +660/−326、模型 3 ファイル +76/−39 |
| 比較用ビルドの回数 | 12（試行 19〜30） | 15 | 14 |
| 壊れた宣言・ファイル・診断の和 | 41・23・89（系列 C。全系列で 113・42・213） | 50・30・111 | 本番 183・37・367、模型 18・3・63 |
| 変えた既存の宣言（本番） | 119（55 ファイル） | 70（36 ファイル） | 190（55 ファイル） |
| 新しい宣言 | 12 | 28 | 45（うち符号の単射性 17、構築関数 2） |
| 言明の字面の変更 | 44（定理 25） | 32（定理 9） | 96（定理 34） |
| うち Top の構築関数だけ | 34（定理 17） | 0 | 70（定理 28） |
| 言明の実質の変更 | 10（定理 8: 代入の補題の一般化 5 など） | 32（定理 9） | 26（定理 6） |
| 本体だけの変更 | 75（Top の構築関数だけ 38） | 36 | 92（Top の構築関数だけ 59） |
| 場合分けの腕 | 腕 57 行・45 宣言 | なし | なし |
| 明示の Top の構築の行 | 104 行（35 ファイル。`Eff.single` は関数の中で Top を作る） | 0（変換に頼る） | 本番 209 行（36 ファイル。うち `Eff.single` の呼び出し 120 行） |
| 主定理の言明 | 不変 | 字面は不変 | 字面は不変 |
| 前提（`Builtins.Assumptions`） | 変更なし（Top に特化、署名の具体化なし） | 5 欄（`delta_typed`・`io_typed`・`io_exists` の量化、`io_op` の連言、`release_exists` の `o.base`） | 4 欄（量化 3 と `io_op` の連言）。`release_exists` は Top の構築関数だけ |
| 資源の型 | Top の添字に特化 | 元の名前で判定（範囲付きも資源になりうる） | Top の添字に限る（L00.03 申し送り 3） |
| 原子の符号の単射性 | 対の符号で証明 | sorry | 区切りの桁を持つ符号で証明 |
| sorry | 0 | 2（`code_injective`・`E_OpPrim`） | 1（`E_OpPrim`。依頼により残した） |
| 黙った狭め | 系列 C では検出なし（系列 B は既定引数で起こる） | 2 件 | 0 件（黙った一般化 4 行と `BuiltinOnly` は残る） |
| 署名の具体化（L20 の内容） | 含まない | 含む（`PrimSig.inst`・`V_Prim` の R・`inv_prim` 群） | 含む（同じ） |

比べるときの注意:

1. 案 (ii) の二列は署名の具体化（言明 6 定理、`Builtins.Assumptions` の量化、`PrimSig`・`HasTypeVQ`）を含み、案 (i) は含まない。実質の言明の変更の差（26 と 10）の多くはこの差である。
2. 案 (ii) の L00.06c の破損の和には、L00.01 の後に置いた比較用の模型（`Scope/`）の破損と、例のファイルの名前のない `example` が多く入っている。案 (i) の系列 C は系列 B の腕の修正を引き継いだ後の数である。三つの和は試行の進め方が違うので、そのまま大小を比べない。
3. 案 (ii) の明示の Top の構築の行は `Eff.single` の引数の型の選び方で 120 行変わる。`Eff.single` を案 (i) と同じく元の名前を受け取って Top を作る関数にすれば呼び出し側は変わらないが、その場合は署名の具体化が範囲付きの単一原子を作る別の構築関数を要する。

## 格納方式の判断への影響

- 暗黙の変換を外すと、案 (ii) の「既存の構成子の引数の数を保つので利用側の変更が少ない」という利点は、Top の構築関数の書き換えでほぼ打ち消される。書き換えの規模は、`Eff.single` の呼び出しを除けば案 (i) の Top の構築関数の置き換えと同じ程度（約 90 行と 104 行）である。案 (ii) は場合分けの腕の修正（案 (i) の 57 行）を要しない代わりに、表の鍵を元の名前（`EffBase`）と名前の記述（`EffName`）に分ける変更（定義・構造体 19）と `.base` の射影を要する。
- 実質の言明の変更は、署名の具体化を除けば `ContTy.end_of_noHandler` の一般化だけで、資源の型を Top に限れば L00.01 の資源の 4 件は字面だけへ下がる。前提の変更（量化 3 欄と `io_op`）は格納方式によらない（L00.03 の申し送り 1）。
- 原子の符号の単射性は、案 (ii) でも閉じた。ただし範囲の要素が任意の文字を持つので、区切りを文字と別の桁にする符号化が要り、L00.01 の符号化は単射でなかった。案 (i) の対の符号と同じく証明だけの費用である。
- 案 (ii) には黙った一般化（名前の変数の型の推論で言明の対象が範囲付きへ広がる）が残る。案 (i) の明示の構築関数は構成子の引数が増えるので、同じ箇所が型の誤りか腕の不足として現れる。
- 以上から、この枝の件数だけでは二案の優劣は決まらない。規模の差は主に試行の範囲（署名の具体化の有無）と `Eff.single` の設計の選び方から来る。`E_OpPrim` の費用（L00.06b）と合わせて L00.08 で判断する材料とする。

## 受け渡す状態

- 試行を `git restore --worktree --staged -- formal` と `git clean -fd -- formal/Benitoite formal/Benitoite.lean` で元に戻した。`git status --short` は `l00.06c/` の追加だけを示す（`formal/` に差分なし）。
- 既定ビルド: `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>`。終了 0、`Build completed successfully (417 jobs).`、sorry の警告 0 件（`grep -c sorry` が 0）。待ち 0 秒、時間 162.06 秒（試行の取り消しで作り直したため）。ログは `build-20-handover.log`。
- 受け渡すのは `l00.06c/` の記録だけで、模型・既定 import・既存の定義は基準のままである。旧の主定理と小補題はすべて既定の全入口に残っている。

## 検査

| 検査 | コマンド | 結果 |
|---|---|---|
| 基準の既定ビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh build-00-baseline.log` | 終了 0（417 ジョブ）、0.15 秒、待ち 162 秒 |
| 比較用ビルド 01〜14 | 同じ道具（上の表） | 01〜13 は終了 1（比較の証拠）、14 は終了 0、sorry 1 件 |
| 単一ファイル（途中） | `cd <wt>/formal && lake env lean -M 12288 <ファイル>`（`Release/Order/Atoms.lean` 3 回、`Scope/RepresentationExamplesI.lean`・`II.lean`・`Surface/CheckSoundControl.lean` 各 1〜2 回） | 最後はいずれも終了 0。`Atoms.lean` の初回は単射性の証明の誤り 3 件、2 回目は未使用の simp の引数の警告 |
| 試行の状態の公理の依存 | `lake env lean -M 12288 <l00.06c>/axioms-trial.lean`（試行 14 の状態で実行） | `Atom.code_injective`・`progress`・`desugar_typed` は `propext`・`Classical.choice`・`Quot.sound` だけ。`preservation`・`effect_soundness`・`surface_effect_soundness` は `sorryAx` を含む（`E_OpPrim` の sorry による）。記録は `axioms-trial.log` |
| 受け渡す状態の既定ビルド | 上の「受け渡す状態」 | 終了 0、sorry なし |

plan「work L00 の各枝」の `scripts/check.sh --level work` は実行していない。依頼文が全体の `lake build` を排他の道具だけで走らせるよう定めたためで、受け渡す状態は基準と `formal/` が同じである。

## 最大常駐量

`/usr/bin/time -l` の maximum resident set size（バイト）。各ビルドは排他で一度に一つだけ走り、値は lake の配下で最大の一つのプロセスである（並行した別のプロセスの和ではない）。

| ビルド | 原値（バイト） | MiB | GiB |
|---|---:|---:|---:|
| 受け渡す状態の既定ビルド（20） | 2644688896 | 2522.2 | 2.46 |
| 試行の最大（14） | 2657239040 | 2534.1 | 2.47 |
| 基準（00、全て再利用） | 69320704 | 66.1 | 0.06 |
| 公理の確かめ（単一ファイル） | 1502134272 | 1432.5 | 1.40 |

メモリの見張りの記録（`<repo>/work/m013/lean-guard.log`）は確かめていない。ビルドの異常な停止はなかった。

## 失敗と修正

- `Order/Atoms.lean` の単射性の証明の初回: 桁の積の消去を `omega` で試みて失敗（非線形）、`rw` の対象が未定、`congrArg` の不足の 3 件。`Nat.eq_of_mul_eq_mul_left` と型の注釈で直した。
- 模型 II の書き換えで import の行まで置き換え、単一ファイルの検査が失敗した（`unknown module prefix 'OldAtom'`）。import を戻した。
- 置き換えの道具が `Exchange/Convert.validateClauses` の交換の自前の原子 `Atom.name od.eff`（`String`）まで置き換え、ビルド 11 で `String.top` が未定として失敗した。その1件を戻した。
- 書き換えと作り直しを繰り返す補助の手順（`tools/loop.sh`）が、件数の集計の出力を `head` へ渡したため `BrokenPipeError` を表示した。JSON は書き出した後なので件数に影響はない。
- 比較用の写しを作るとき、`git apply` と `patch` を続けて走らせ、`patch` が差分を逆に当てた。写しを作り直し、`git apply` だけで当てた（集計の前。集計に使った写しは `trial-15` の `Atom.lean` との一致を確かめた）。

## ずれと申し送り

1. **`E_OpPrim` の sorry**: 依頼どおり残した。試行の最後の状態では `preservation`・`effect_soundness`・`surface_effect_soundness` が `sorryAx` に依存する。案 (ii) で閉じられるかは L00.06b（案 (i)）の結果と合わせて L00.08 で比べる。
2. **符号化の単射性**: L00.01 の案 (ii) の `scopeChars` の符号化は単射でなかった（範囲の要素の文字に `'\u0000'` を含めると衝突する）。採るなら区切りを文字と別の桁にする符号化（この枝の形）か、案 (i) の対の符号を使う。範囲の要素の文字を制限する整形式性（判断 4 の既存の不正）に頼る形は試していない。
3. **黙った一般化**: 案 (ii) では、名前の変数の型の推論で言明の対象が範囲付きの名前へ広がる箇所が残る（4 行と `BuiltinOnly`）。採るなら、範囲を区別すべき言明で `EffName` か `EffBase` を明示する点検を L10 の枝に入れる。
4. **`Eff.single` の引数の型**: `EffName → Eff` のままにしたので呼び出し側 120 行が変わった。元の名前を受け取る Top の版と範囲付きの版を分けるかは、格納方式を採るときの細部として L00.08 へ渡す。
5. **比較用の模型の意味**: 案 (ii) を本番へ当てると、模型 I・II と `CompatExamples` の「旧の原子」は本番の原子と同じでなくなる。この枝は模型が通るよう最小の修正をしたが、模型の結論を案 (ii) を当てた状態へ読み替えたものではない。
6. **停止条件**: 受け渡す状態は既存の定義と定理を変えておらず、旧の四主定理の前提・結論の変更、公理や `Builtins.Assumptions` の欄の追加はない。試行の記録としては L00.01 と同じく、`delta_typed`・`io_typed`・`io_exists` の量化と `io_op` の連言が前提の変更として残る（L00.03 の申し送り 1 の判定の案 A で L00.08 に列挙する事項）。新しい欄は要らなかった。
7. **計画からのずれ**: 失敗したファイルの中の同じ綴りを、型の誤りが報告される前に一度に置き換えた。各ビルドの破損の数は、そのファイルの中で後に現れたはずの誤りを含まない場合がある（ファイルの中の宣言はふつう独立に検査されるので、多くは同じビルドで報告済みである）。全体の規模は最後の差分の宣言の分類を正とする。

## 時間

| 区分 | 値 |
|---|---|
| 開始・終了 | 2026-10-27 19:52:56 〜 20:24 頃（外側の所要 約 31 分） |
| ビルドの時間の和 | 約 431 秒（基準・試行 14 回・受け渡し。単一ファイルの検査を除く） |
| 排他の待ちの和 | 325 秒（基準の 162 秒を含む） |
| 能動時間 | 約 19 分（外側の所要からビルドと待ちを除いた概算。読む時間を含む） |
| 見込みとの比 | 見込み 1〜2 時間の内。上端の 2 倍に達していない |
