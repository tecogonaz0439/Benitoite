# RV-L70.d3: L70 群 D 再開8（J70-9 の14の判定の関数と、開いた契約の受理）の独立レビュー

2026-11-07。対象はブランチ `m014/l70.d3` の作業木の未コミットの差分と未追跡のファイルである。基準は `73585979113c7acf25b38673f9c2c52d1d38dfaf` で、HEAD が基準と一致することを確かめ、`git status` と `git diff` で読んだ。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-d3/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木の依頼文 `work/m014/L70.d3-prompt.md` と報告 `L70.d3-report.md`、[群 D の結果](../l70/d/results.md)の「再開8（J70-9）」、[表層の実装の記録](../l70/d/resume8-design.md)・[開いた契約の記録](../l70/d/resume8-open-contract.md)・[内部行の記録](../l70/d/resume8-predicate-rows.md)。
- [RV-L70.d2](RV-L70.d2.md) と「取りまとめの追記」（情1を再開8で外す、軽1を同じ再開で直す）。記録の形は RV-L70.d2 の初回の部分に倣った。
- 本体の作業木の最新の `plan.md` の先頭の判断のうち、群 D の結合の取り込みと次の起動、RV-L70.d2 の処置の確認（開いた契約の制限を外す方向で直す）、RV-L70.f2（14の関数の J70-9 を群 D が受け持つ、`BooleanResult.typed` は閉じた値の応答までである）、群 F2 再開2の停止、設計者の決定 J70-7〜11、RV-L70.e3 の処置（標準の完成表の下の証人を群 E の後半で閉じる）。
- 変更した既存のモジュールの差分（`Rules`・`Desugar`・`OpenSurface`・`OpenSurfacePartial`・`OpenSurfaceProperty1`・`Check`・`CheckOpen`・`CheckInfer`・`CheckAcceptBase`・`CheckAcceptedRanges`）。新規のモジュールのうち `PredicateRows`・`PredicateRowsResponse`・`PredicateCalls`・`PredicateRowCollection`・`PredicateRowCollectionExamples`・`PredicateRowsTable`・`PredicateProjectionTable` の宣言の一覧・`OpenScopeAccept`・`OpenScopeExamples`・`CheckPredicateExamples`・`CheckPredicateFallbackExamples`・`CheckPredicateProjectionExamples`。照合のために `CheckTables.checkProgram`・`CheckAccept.checkProgramAccepted`・`ScopeSignatures.widenPathIn`・`RangeFunctionExamples.endpointDef`・`Syntax.Expr` の構成子を読み合わせた。01-12・07-04 の差分。
- `resume8/verify.py`・`statement-differences.json` と保存された集計。台本は読んで判定し、実行していない。

したことは、14の関数の述語と δ・内部行の応答の照合、新しい二規則と脱糖・性質1の読み合わせ、解決（公開呼出しから内部行への書き換え）の読者の照会、開いた契約の受理と閉じた由来の受理の対照の Lean による確認である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、確認用の入力は `<tmp>` に置いた。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・台本の実行・git の書き込み操作は行っていない。群 E の後半の枝との結合は検査していない。変更したリポジトリのファイルは本書だけである。

## 結論

**不可。重1件、中3件、軽2件、情報4件である。**

14の関数の内部行は、述語・δ・結果型が一致する。`PredicateRows.response` は内部行の全ての `BuiltinArgs` について、結果の真偽が同じ対象の述語と一致する篩付きの型を持つことを示し、`PredicateCalls.path_delta` などは固定したリテラルで内部行と公開の δ が等しいことを示す。新しい二規則の脱糖は対象の値を一度だけ渡し、通常・開いた性質1は両規則の場合を含む。開いた契約の `acceptSelection_sound` は based・secrets を含む全ての適格な具体化で被覆と位置0の契約の存在を示し、新しい公理・`sorry` もない。しかし、公開呼出しを内部行へ書き換える解決は、型検査器のどの実入口にも組み込まれていない。利用者が `if` の条件に書いた公開呼出しは、実入口では素の Boolean として検査され、枝の事実を得られない。解決の前後の意味の一致も、プログラムの水準では示されていない。これは J70-9 の決定と食い違う。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | `R/Surface/PredicateCalls.lean` の `resolveCall`・`resolveExpr`、`PredicateRowCollection.lean` の `prepareExpr`・`prepareBlock`、`CheckTables.lean:10` の `checkProgram`、`CheckAccept.lean:16` の `checkProgramAccepted`、01-12 の「`Surface.PredicateRows` は、述語へ写せる公開の判定の呼出しを…解決する」 | 結果型の篩は、解決後の内部形（穴のない `partialCall` と `%Predicate.n`）にだけ付く。公開の `E_CallDirect` の結果型は素の Boolean のままである。解決と行の収集は独立の関数で、読者は `CheckPredicateExamples`・`CheckPredicateProjectionExamples`・`PredicateRowCollectionExamples` の例だけである。`checkProgram` と `checkProgramAccepted` は解決も `.predicates` の表の構成も行わない。そのため、利用者が書いた `if Float.isFinite(x) …` を実入口へ渡すと枝の事実はなく、J70-9（篩の外の `if` の条件に書いたとき枝で同じ事実を得る）は実入口で成り立たない。例は、手で解決した式と手で作った表を `Check.checkExpr`・`checkDef` へ渡している。また、主定理を解決後のプログラムと拡張した表に当てても、元のプログラムとの意味の一致は示されていない。示されているのは行ごとの δ の等式（`path_delta` など。読者は例の `public_delta` だけ）である。処理系の側（R 系）も、解決がどの段で行われるかを読めない | 全定義と全実装メソッドの本体から行を収集して解決し、`.predicates` の表を構成してから `checkProgramAccepted` を呼ぶ入口を置く（又は `checkProgram` の内側で行う）。その入口の健全性として、解決後のプログラムの型付けと受理を返す系を置く。あわせて、元のプログラムの脱糖と解決後の脱糖が、標準表と拡張した表の下で同じ結果を返すことを示す（値引数と δ の等式から、解決した全出現についての帰納で示せる見込みである）。又は、言語の意味を解決後のプログラムで定めることを 01-12 に書き、その段の位置を明記する。処置の後に、公開呼出しのままのソースを新しい入口へ渡して枝の事実を受理する例を、少なくとも scalar と投影で一つずつ置く | 読めば確定。読者の照会は `grep` で行った。意味の一致の補題を示せるかは確かめていない |
| 中1 | 中 | `CheckPredicateProjectionExamples.lean` の `text_source_checked`・`open_number_source_checked`・`text_branches`、`CheckPredicateExamples.lean` の `input`、resume8-design.md「実入口と拒否の対照」 | 投影の例の入力 `.predicates data rows` について `Check.Input.Sound` を示していない。そのため、`text_branches` などの検査器の成功から表層の型付けを得られない。`text_source_checked` と `open_number_source_checked` は型付けを仮定として受ける補題の適用で、その仮定を満たす導出は既定ビルドのどこにも作られていない。scalar の例は内部行一つだけの `.custom` 表で `Input.Sound` を示し、型付けを得るのは path の一例（`path_wellTyped`）だけである。標準表と内部行を合成した表の下で、検査器の成功から型付けまで届く例はない。記録はこの限界を書いているが、例の受理が型付けを意味することは示されていない | RV-L70.e3 の中1の処置（標準の完成表の下で入口の前提を満たす証人を群 E の後半で作る）を、`.predicates` の表（`Rows.Valid` を満たす内部行の追加）にも広げる。重1の新しい入口の例で、標準表と内部行の下の `Input.Sound` から型付けを得て、`text_source_checked` の仮定を実際に満たす | 読めば確定 |
| 中2 | 中 | `OpenScopeAccept.lean` の `select`・`sourceRange`・`acceptBody`、`CheckAcceptBase.lean` の `acceptDef`、resume8-open-contract.md、01-12「Scope の必須の判定の受理と拒否の理由」の冒頭の理由 | 記号側の規則は、宣言したパラメータの型の注釈 `PathIn[R]` から元の範囲を読む。閉じた由来の規則は、パラメータの由来を知らないので Top と読む。そのため、範囲パラメータを持つ関数の転送 `widenPathIn[R, R](p)`（`p : PathIn[R]`）は受理され、範囲パラメータを持たない同じ形 `widenPathIn["/a", "/a"](p)`（`p : PathIn["/a"]`）は `unknownSource` で断られる（検査2。規則は `OpenScopeExamples` の由来の規則と同じ定義を使った）。範囲パラメータを足すと受理されるという逆転は、記録に書かれていない。01-12 は受理の理由を「その範囲が注釈を信用したものでなく必須の判定の結果に覆われること」とするが、記号側はパラメータの注釈を読む。どちらの扱いも健全性を損なわない（受理は主定理の前提でない）。ただし、受理の意味が範囲パラメータの有無で変わる | 設計者の見直しの表に、閉じた関数との逆転と、記号側がパラメータの注釈を読むことを書く。注釈を読むことが01-12の理由と両立する根拠（`PathIn` の値は必須の判定を経て作られる）を「理由:」に書くか、閉じた由来の規則にも同じ読み方を加えるかを、設計者に問う | 実行で確定（検査2）。閉じた形の型付けの成功は確かめていない。処理系の実際の規則表での振る舞いは確かめていない |
| 中3 | 中 | `OpenScopeAccept.lean` の `select`、results.md「開いた契約の受理」の外せなかった形の表、resume8-open-contract.md の範囲の表 | 記号側が選ぶのは、本体の全体が一つの直接の末尾呼出しで、引数が宣言したパラメータの参照一つの場合だけである。末尾呼出しの前に束縛が一つでもある本体、呼出しの結果を束縛して返す本体（`let q = Scope.widenPathIn[R, R](p); q`）、`File.writeTextIn` のような複数の引数の呼出しは、閉じた由来へ渡り `unknownSource` になる（検査2で束縛して返す形を確かめた）。記録の表は「束縛・分岐・ラムダの内側」と書き、受理する形を肯定の形で書いていない。そのため、受理されるのが実質的に範囲を転送するだけの包む関数に限られることが読めない。取りまとめの判断は、この制限を「よく使う形なので外す方向で直す」としていた | 結果の表の冒頭に、受理する形（本体の全体が一つの末尾呼出し、引数はパラメータの参照一つ）を書き、実用への影響の列に、束縛の前置き・結果の束縛・書き込みが断られる例を書く。段末の受け入れで、この範囲で足りるかを設計者に問う | 実行で確定（検査2） |
| 軽1・2 | 軽 | `PredicateCalls.apiOfName`、`CheckPredicateExamples.float32_branches`、`resolveExprWith` の `.pipe` | 軽1: `Float32.isInfinite` は解決の対象に入るが、`float32_branches` は `test ≠ .infinite` で除き、受理の例がない。軽2: 解決は `.call` の頭だけを書き換えるので、パイプ `x \|> Float.isFinite` の形は素の Boolean になる。この形は記録の素の Boolean になる形に書かれていない | 軽1: 一行の例を足すか、件数の外であることを例の docstring に書く。軽2: 記録の表に一行足す | 読めば確定 |
| 情1 | 情報 | `PredicateRows.lean`・`PredicateRowsResponse.lean`・`PredicateCalls.lean` | 14行の述語 `Entry.predicate` は所属・文字集合・Float の分類であり、`input_eval` がその閉じた評価を `Entry.run` と結ぶ。`response` は全ての `BuiltinArgs` で `BooleanResult.typed` を使う。`path_run`・`host_run` は `parseAtPattern` の成功の下で、characters と floating は定義の上で、公開の `API.run` と同じ引数の順序（pattern・対象、対象・両端）で一致する。対象を自己変数の下へ一つずらすこと、動的な pattern と端で元の公開呼出しを保つこと（`CheckPredicateFallbackExamples`）も妥当である。書ける形は狭めていない | なし | 読めば確定 |
| 情2 | 情報 | `Desugar.lean` の `directValueCall?`、`Rules.lean`・`OpenSurface.lean` の `E_PartialCall*` | 脱糖は穴のない内部形の番号0の値だけを渡し、投影の番号1のソースを評価しない。投影の元のソースは `Eff.empty` で型付ける。既存の4つの部分適用の規則は `args.holeTypes ≠ []` を既に持つ（`Rules.lean:570`・`591`・`617`・`641`、開いた側も同じ）ので、四補助に足した前提は元の読者から供給される。`Accepted.def_body`・`def_ranges` の差は `def_body_no_ranges`・`def_ranges_no_ranges` で元の結論に戻る | なし | 読めば確定 |
| 情3 | 情報 | `OpenScopeExamples.different_entry_rejected`、報告の表「プログラムの実入口も受理しない」 | 異なる範囲変数の実入口の拒否は、型付けの段の拒否（`.typing`、kind が rejected）である。受理の段の拒否は `acceptDef` の単位で示される。`widenPathIn` の引数の型 `PathIn[R0]` を型付けが要求するので、この直接の形では型付けを通って記号側だけが断る例は無いと読める。記号側の受理は、この形では型付けに制限を足さない | 報告の表に、実入口の拒否は型付けの段であることを書き添える | 読めば確定。型付けを通って記号側が断る例が無いことは証明していない |
| 情4 | 情報 | `OpenScopeAccept.acceptBody`、`DefinitionRanges` | 選べない本体を閉じた由来へ渡して `unknownSource` にするのは、誤って受理しない側である。`DefinitionRanges` は範囲文脈が空のとき閉じた `BodyRanges`、非空で選んだとき記号側の全具体化の被覆を返し、後段（R20・R60）が二つの結論を区別して読める。記号側の `close` は `rs[i]?` で範囲変数を引くが、同じ変数・Top・固定範囲だけを被覆とするので、核の具体化の添字の向きに依らず結論が成り立つ | 後段で処理系と比べるとき、記号側の七規則と位置0を同じ表として持つ | 読めば確定 |

## 観点ごとの根拠

### 1. 14の関数

結果型は `Entry.result entry t = Boolean{b | agreement (entry.predicate t)}` で、`agreementAt` は `(b = true ∧ p) ∨ (¬(b = true) ∧ ¬p)` である。内部行の署名は対象一つを値引数とし、型・行・範囲パラメータを持たない。`argument_result` は全ての `BuiltinArgs` から型・行・範囲の引数が空で、値が一つの定数であることを取り出す。`response` はその定数の述語の閉じた評価と `Entry.run` の一致（`input_eval`）から `BooleanResult.typed` を当てる。経路は有限の `Entry` の場合分けで閉じており、大きな具体値を作らない。

公開の δ との一致は、`path_delta`・`host_delta`（`parseAtPattern` の成功を前提とする）、`characters_delta`（定義の上の等号）、`floating_delta` が示す。解決の `identifyCore` が読む引数の順序は、公開の `API.run` の順序と同じである。`Float32.isInfinite` は件数の外で、解決の対象に入るが例はない（軽1）。

動的な pattern や端は `identify` が `none` を返し、`resolveCall` は元の公開呼出しを保つ。`CheckPredicateFallbackExamples` は、その結果が素の Boolean で受理されることを示す。J70-10（絶対形だけ）の下で相対形の pattern も解析に失敗して元の呼出しを保つので、書ける形は狭めていない。

ただし、これらは解決後の内部形についての性質である。解決を行う実入口がない（重1）。

### 2. `E_PredicateCall`・`E_PredicateProject`

両規則は穴のない `partialCall` を内部形として使い、`target.valueOf? = some v`（又は `root`）の値を `ValsTel` で検査する。脱糖の `directValueCall?` は `args.holeTypes = []` のときだけ当たり、核の `app (prim …) [v]` を作る（`desugar_predicateCall`・`desugar_predicateProject`）。値は評価を伴わないので、対象は一度だけ渡る。投影の元のソースは脱糖で捨てるが、規則が `Eff.empty` で型付けることを要求する。

通常の性質1と開いた性質1（`OpenSurfaceProperty1.lean` の追加の二場合）は、`CallHeadTy.app_value` と `ValsTel.core` から `C_DependentApp` を作り、`C_Sub` で注釈へ広げる。checker（`Check.lean`・`CheckOpen.lean`）は両規則を同じ前提で再検査し、推論（`CheckInfer.lean`）は元のソースを推論して案内に入れる。投影の再検査は元のソースを実際に `checkExprAt` に通すので、`wrong_child_type` が示すとおり、誤った子の型引数を内部行の解決で隠さない。

### 3. 開いた契約の受理

`covers` は同じ `RangeIx`、外側の固定 Top、固定範囲どうしの `Covers` だけを真とする。`covers_sound` は based・secrets を含む全ての `RangeExpr` について、Top が覆うこと（`RangeExpr.top_covers`）を使う。`acceptSelection_sound` は `RangesFit rs ks` の全ての `rs` について、位置0の契約・元の範囲・契約の具体化の存在と被覆を返す。異なる範囲変数の被覆は推測しない。`different_variables_counterexamples` は、変数0を Top、変数1を狭い path 又は endpoint とする適格な具体化で被覆しないことを示し、受理しない理由として意味を持つ。

一方、受理する形は狭い（中3）。閉じた関数との逆転もある（中2）。実入口の拒否の対照は型付けの段で起きる（情3）。

### 4. 既存の言明の差6件

`statement-differences.json` の6件は、記録の表と一致する。四補助の追加の前提 `args.holeTypes ≠ []` は、性質1の既存の四場合で、元の規則の前提がそのまま渡される（`OpenSurfaceProperty1.lean` の差分）。受理の二言明は `no_ranges` の系で元の結論に戻る。`verify.py` は群 D の308件の承認済み二差、群 E の617件の差が受理の二件だけであること、97規則の名前と順序を照合する台本である。

### 5. 報告の述べる限界

生成の完備性を主張しないことは、例の前提を空疎にしない。例は具体の入力で `checkChain` などの成功を計算で示しているからである。小さい投影の fixture の `Input.Sound` を示していないことは、投影の例の受理から型付けへ進めないことを意味する（中1）。`text_source_checked` は仮定を受ける補題で、論理として空疎ではないが、既定ビルドでその仮定を満たす導出はない。

### 6. 守ること

新規・変更のモジュールに `axiom`・`sorry`・`#eval`・`native_decide` はない（`verify.py` の検査と `grep` で確認した）。新しい `maxHeartbeats 400000` は `PredicateProjectSource.lean` の反転の二か所で、記録に理由がある。`Property1`・`ScopedProof`・`OpenSurfaceProperty1`・`OpenSurfaceScoped` の上限は基準の版から既にある。01-12 の `unknownSource` の段落は開いた契約の場合を含み（RV-L70.d2 の軽1）、07-04 は型付けの入口と受理の入口を区別して書く。写しに経緯の文や工程の ID は見当たらない。ただし、01-12 の解決の段落は解決がどの段で行われるかを書いておらず、重1の処置に合わせて直す必要がある。results.md は81,772バイトで上限の内側である。

## 実行した検査

Lean はすべて `<repo>/formal/` から実行し、同時に一つだけとした。既定のビルド出力は上書きしていない。単独検査は対象 worktree の既存のビルド済みモジュールを import する。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | 読み取り専用の `grep` による照会。`resolveCall`・`resolveExpr`・`prepareExpr`・`prepareBlock`・`BuiltinSource.predicates`・`path_delta` などの読者、`checkProgram`・`checkProgramAccepted` の定義、`Syntax.Expr` の構成子と `resolveExprWith` の対応、新規・変更のファイルの禁止した構文と `maxHeartbeats` | 解決と収集の読者は例だけで、実入口の定義は解決を呼ばない。`resolveExprWith` は部分式を持つ全構成子を辿る。禁止した構文はない |
| 2 | `<tmp>/ClosedForward.lean`。`OpenScopeExamples` の由来の規則と同じ定義の規則を `Scope.widenPathIn` に登録した受理の入力で、(a) 範囲パラメータを持たない `widenPathIn["/a","/a"](p)`（`p : PathIn["/a"]`）の `acceptDef` が `unknownSource`、(b) 範囲パラメータを持つ `widenPathIn[R,R](p)` が `.ok ()`、(c) (b) の呼出しを束縛して返す本体が `unknownSource` であることを `rfl` で確かめた。あわせて `acceptSelection_sound`・`Accepted.def_ranges`・`acceptDef` の言明を `#check` で確かめた | 終了0、警告なし。中2・中3を確認。初稿は名前空間の指定の誤りで終了1となり、確認用入力を直した |

担当が記した既定ビルド1,566ジョブ・公理監査117,433宣言・照合の終了0は保存された報告として読み、本レビューで実行した検査としては数えていない。`verify.py` は実行していない。

確認用の最終入力は、`ClosedForward.lean` が2,224バイト（SHA-256 `c6e3c1bb2bf4f8fb9447c092fd83b5adc75cc87c83c4c424ec97415076074ad7`）である。

## 処置の確認

2026-11-07。群 D の再開9の処置を確かめた。対象は同じ worktree の未コミットの差分である（基準は前節と同じ `73585979`）。読んだものは、本体の作業木の依頼文 `work/m014/L70.d-r9-prompt.md` と報告 `L70.d-r9-report.md`、[群 D の結果](../l70/d/results.md)の「再開9」、[再開9の詳細](../l70/d/resume9-details.md)、`resume9/verification.json` と各実行の要約である。Lean のソースは `CheckPreparation`・`PredicateProgramSemantics`・`CheckTables.checkProgram`・`CheckAccept.checkProgramAccepted`・`CheckBuiltinSource`・`CheckPredicateProgramExamples`・`OpenScopeAccept` を読んだ。群 E の後半の取り込み後の `san_benito` の `SurfaceLibrary.lean` を、読み取り専用の `git show` で読み合わせた。確認は本レビューの処置の確認の一回である。

### 結論

**不可。重1は実入口への組み込みについて可、意味の一致について不可とし、新しく重1件（重2）・中2件（中4・中5）・軽1件・情報2件を足す。** 公開呼出しのままのプログラムは、両実入口で15の公開名の両枝を受理し、素の Boolean を拒否する。中1〜中3と軽1・2の処置は可である。しかし、解決後の意味の下で、受理から主定理の保証へ届く経路が閉じていない。重ねた表 `predicateOverlay` について、`Builtins.ValueAssumptions` と標準の表の条件が示されていない。そのため `accepted_property1` の前提 `hvalues` を供給するものがない。群 E の後半の主保証の系も、元のプログラムと標準表の下の旧い言明を読んでいる（重2）。

| 所見 | 判定 | 根拠 |
|---|---|---|
| 重1（実入口） | 可 | `checkProgram` は `prepare` の後に `checkPreparedProgram` を呼び、`checkProgramAccepted` はその結果を使う。`CheckPredicateProgramExamples` の `path_entry`・`host_entry`・`characters_entry`・`floating_entry` は、公開呼出しのままの全プログラムの両枝の受理と素の Boolean の拒否を示す（Float32.isInfinite を含む）。`path_typed` は標準表の下の `Input.Sound` から準備後の `CheckedUnder` まで届く。`.custom` の表は恒等に準備し（`prepare_custom`）、従来の検査を保つ |
| 重1（意味の一致） | 不可（重2・中4として残す） | (a)〜(c) は次の小節に書く |
| 中1 | 可 | 標準の全392行の有限支持と内部行の支持から `Input.Sound` を構成した（`input_sound`・`prepare_sound`）。`source_typed` と `text_source_derivation`・`open_number_source_derivation` は、実入口の成功から得た型付けで元の取り出しの補題の仮定を満たす。値の仮定は重2に残る |
| 中2 | 可 | 検査3で、範囲パラメータを持たない固定範囲の転送 `widenPathIn["/a","/a"](p)` を `acceptDef` が受理することを確かめ、逆転は解消した。束縛の注釈 `PathIn[R1]` だけから転送する形は受理しない。局所の注釈を信用しない区別も保たれる。01-12 の理由は、契約の範囲を「局所の由来又は型付けで検査済みのパラメータ型」から選ぶと書き改めた |
| 中3 | 可 | `selections` は全出現について、文列を辿った元のパラメータ参照から選ぶ。束縛の後は未知の位置を加える。五形（直接の末尾、束縛の前置き、結果の束縛、ブロックの末尾、書き込みの二引数）に受理と範囲変数の取り違えの拒否がある。検査3で結果を束縛して返す形の受理を確かめた。書き込みは宣言順の位置0（`path`）を読み、ラベルの並べ替えも `positions` で対応する |
| 軽1・軽2 | 可 | `Float32.isInfinite` の実入口の例を足した。パイプの形は表に書いた |
| 情3 | 可 | 実入口の取り違えの拒否が型付けの段であることを、報告と表に書いた |

### 意味の定め方（重1の意味の一致）

(a) **定め方の妥当性。** 型付けの前に名前を解決し、公開ソースの意味を解決後のプログラムの脱糖で定めることは、性質1の脱糖の前段の一段として妥当である。解決は公開名・ラベル・リテラルを読む構文上の書き換えで、宣言を保ち（`resolveProgram_declarations`）、行のないプログラムでは恒等である。ただし、この定め方は「利用者の書いた公開の呼出しは、公開の行の δ で実行される」という読み方を、言語の定義から外す。処理系（R 系）が同じ解決を行わずに公開の δ で実行するなら、処理系と形式化の意味は一致の証明なしに異なる二つの定義になる。

(b) **未証明の信頼条件か。** 形式化の中では、模倣を仮定として置いた箇所はない。しかし、模倣を示さないことで、次の二つが受け口として開いたまま残る。第一に、処理系との対応である。処理系が解決をしないなら、公開の δ による実行と解決後の実行の一致が、未証明の前提になる。第二に、主定理の系である。群 E の後半の `SurfaceLibrary.checkProgramAccepted_main` は、元の `p` と標準表 `q.B = StandardModel.complete L T A` の下の保証を、旧い `checkProgramAccepted_sound`（`CheckedUnder p q`）から導く。再開9の変更の後、この言明は準備後のプログラムと重ねた表の結論しか得られない。重ねた表は `StandardModel.complete` の形でない。したがって、合流すると、主保証の系は書き直しが必要になる。書き直しの前提（重ねた表の値の仮定と標準の表の条件）は示されていない（重2）。

(c) **模倣の大きさ。** 小さくない。scalar の行では、公開呼出しの脱糖（引数ごとの `letIn` の列と公開の行の呼出し）と、解決後の内部行の直接呼出しの間に、段の数の違う模倣が要る。項の関係を核の全ての計算・継続・閉包・ストアへ閉じ、全ての Step の規則で保存を示す必要がある。群 E の後半の消去の模倣（`SafeCheckErasure`・`SafeCheckSimulation`・`SafeCheckPreservation`・`SafeCheckObservations` の計約1,600行）が型板になる見込みである。投影の行では、元の取り出しの関数の呼出しの連鎖を `readPath` の一回の読み取りへ縮める対応も要る。行ごとの δ の等式（`public_deltas`）は、この模倣の呼出しの一段にしか当たらない。

より小さい代案は、意味を解決後で定めたまま、次の三つを閉じることである。(i) 重ねた表が `Builtins.ValueAssumptions` と、群 E の主保証が要求する標準の表の条件を満たすこと。`PredicateRowsTable.core`・`PredicateProjectionTable.core` は `.predicates` の構成について示しており、重ねた表との一致又は同じ条件を示す。(ii) 収集した行の `Rows.Valid` を、元のプログラムの整形式から導くこと。(iii) `checkProgramAccepted_main` を `meaning` の上で言い直すこと。加えて、処理系が同じ解決を行うことを 01-12 の決定に書き、R 系の受け口とする。どちらの案を採るかは設計者の判断である。模倣を省くなら、(i)〜(iii) と処理系の義務の記録は必要と判断する。

### 足す所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重2 | 重 | `CheckBuiltinSource.lean` の `predicateOverlay`、`PredicateProgramSemantics.accepted_property1` の `hvalues`、`san_benito` の `SurfaceLibrary.checkProgramAccepted_guarantees`・`checkProgramAccepted_main` | 解決後の意味の下で、受理から主定理の保証へ届く経路がない。`predicateOverlay` を読む定理は定義の一つだけで、値の仮定と表の条件の補題がない。`accepted_property1` の `hvalues` を供給するものがなく、この定理にも適用例と読者がない。群 E の後半の主保証の系は、元の `p` と標準表の下の旧い言明を読む。合流の後は、準備後のプログラムと重ねた表の結論と合わない。J70-9 の事実を使うプログラムは、主保証の系の対象から外れる | 上の (i)〜(iii) を閉じ、公開呼出しのままのプログラム一つについて、実入口の受理から言い直した主保証の系までを既定ビルドで示す。又は (c) の模倣を示し、元の `p` と標準表の下の保証へ移す。どちらを採るかを設計者に問う | 読めば確定（`grep` と `git show` で照会した）。合流の後のビルドの失敗は確かめていない |
| 中4 | 中 | `PredicateProgramSemantics.observations_preserved`、01-12 の同じ段落、07-04 の `Surface.PredicateProgramSemantics` の段落 | `execution` は `meaning` の `Steps` と定義され、`meaning` は `core (prepare q p)` である。三つの同値はどれも `Iff.rfl` で、定義の言い換えにすぎない。前の連言の `PublicDeltaAgreement` は後の同値と論理の関係がなく、δ の等式に形の上の読者を作っている。名前・docstring・写しの「公開ソースと…解決済み表現のプログラムの意味は一致する」は、この中身を超える（守ること: 名前と docstring は中身に合わせる） | 言明を除くか、中身に合わせて名前と docstring を改める（例: 意味を解決後で定める定義の展開であることを書く）。δ の等式は、模倣か重2の (i) の証明で実際に使う箇所に読者を置く | 読めば確定 |
| 中5 | 中 | `OpenScopeAccept.acceptBody_no_ranges`、`CheckAccept.acceptDef_no_ranges`、`Accepted.def_body_no_ranges`・`def_ranges_no_ranges` | 範囲パラメータを持たない定義の受理の規則が変わった。選択のある本体では、旧い閉じた由来の判定でなく記号側の判定を使う。四系は「選択なし」の前提を足したときだけ旧い形に戻り、範囲のない全ての定義では戻らない。依頼文の停止の条件（範囲パラメータを持たない既存の規則の変更で、範囲のない場合の系で元の形に戻らないもの）に字義どおり当たる。変更は受理を広げる向きで、中2の処置の結果である。表には書かれているが、停止の条件に当たることは書かれていない | 設計者の見直しの表に、停止の条件に当たる変更として一行を置き、了承を得る | 読めば確定。旧く受理したプログラムを新しい規則が断る例がないことは確かめていない |
| 軽3 | 軽 | `C/l70/d/results.md` | 92,759バイトで、各ファイル100 KB の上限に近い | 再開8・9の詳細を別ファイルへ寄せる | 読めば確定 |
| 情5 | 情報 | `OpenScopeAccept.contextsBlock`・`selections` | 文脈の列と出現の列は `zip` で対応する。長さと順序の一致の補題はない。読む限り、`surfacePreorder`・`preorderBlock` と同じ形で辿り、ブロックと括弧以外の部分式には空の文脈を与えるので一致する。ずれると別の局所を参照するおそれがあるので、長さの一致の補題があると後段が読みやすい | 長さの一致の補題を足す | 読めば確定。一致は証明していない |
| 情6 | 情報 | `resume9/verification.json`・各実行の要約 | 公理監査は一回で、全120,931宣言の依存を出力した後、必須名の照合で終了1となった。原因は private の宣言を公開名で記した誤りである。宣言の所属の記録は別の環境の列挙で補い、ビルド・監査・補完の入力の指紋は同じである。監査をやり直さずに補った扱いは妥当である | なし | 読めば確定 |

### 実行した検査

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 3 | `<tmp>/ClosedForward9.lean`。前節の検査2の入力を再開9の版で再検査した。(a) 範囲パラメータを持たない固定範囲の転送、(b) 範囲変数の転送、(c) 結果を束縛して返す本体を `acceptDef` が `.ok ()` とすること、(d) 束縛の注釈 `PathIn[R1]` だけを持つ局所から `widenPathIn[R1,R1]` へ転送する本体を `unknownSource` で断ることを `rfl` で確かめた | 終了0、警告なし。中2・中3の処置を確認。初稿は (d) の鍵を定義の鍵と書いて終了1となり、拒否の理由だけを照合する形に直した |
| 4 | 読み取り専用の照会。`predicateOverlay`・`accepted_property1`・`observations_preserved` の読者、`san_benito` の群 E の後半の変更のうち実入口の言明を読むファイル | 重ねた表の値の仮定と表の条件の補題はない。二つの定理に読者はない。`SurfaceLibrary` の主保証の系が旧い `checkProgramAccepted_sound` を読む |

担当が記した既定ビルド1,577ジョブ・公理監査・照合の結果は保存された記録として読み、本確認で実行した検査としては数えていない。確認用の最終入力は、`ClosedForward9.lean` が2,730バイト（SHA-256 `872ecc665703fe1f517b750b5499c63c705ddc580236dc494e4bb8e5d8effa6b`）である。

## 再開10の処置の確認

2026-11-07。群 D の再開10の処置を確かめた。対象は同じ worktree の未コミットの差分で、基準は `1395ebfb01be54bc53299c610c70477c1231898c` である（`san_benito` の群 E の後半を結合した版。HEAD が一致することを確かめた）。読んだものは、本体の作業木の依頼文 `work/m014/L70.d-r10-prompt.md`・`L70.d-r10-claude-preamble.md` と報告 `L70.d-r10-claude-report.md`、[再開9・10の記録](../l70/d/resume9-10.md)の「再開10」、[群 D の結果](../l70/d/results.md)の要約、`resume10/checks.py` と各実行の要約である。Lean のソースは次を読んだ。

- `PredicateSimulationTraces`・`PredicateSimulationInvariant`・`PredicateSimulationRuntime` の `StateRel`・`PredicateSimulationObservations` の `terminal`。
- `PredicateProgramObservations`・`PredicateProgramSemantics`・`PredicateProgramGuarantees`。
- `PredicateMainExamples` の主な言明、`OpenScopeAccept` の受理と `no_ranges` の系、`OpenScopeForwardExamples`。
- 群 E の後半の `SurfaceLibrary`・`SurfaceCheckedMainExamples` の差分。

模倣の90余りのモジュールの個々の場合の証明は読んでいない。言明・定義・公理依存を確かめ、場合の網羅は Lean の検査に依った。確認は再開10の処置の確認の一回である。

### 結論

**可。前節までの重・中の所見はすべて処置された。足す所見は軽1件・情報2件である。** 前節の重2・中4・中5・軽3・情5も処置された。

模倣は、名前解決の前の核（公開の行の δ と元の表）と準備後の核（内部の行と重ねた表）の間で、両方向に一段ずつ示されている。`observations_preserved` の四つの同値は、その模倣から導かれる。公開呼出しを `if` の条件に書いた main について、受理・主保証・観測の同値が仮定なしで成り立つ。公理は `propext`・`Classical.choice`・`Quot.sound` だけである（検査5）。

| 所見 | 判定 | 根拠 |
|---|---|---|
| 重1（意味の一致）・重2・中4 | 可 | 下の小節 |
| 中5 | 可 | `acceptBody` は範囲の種類列が空で閉じた由来の判定が成功すれば成功する（`acceptBody_no_ranges_of_closed`）。`accepted_no_ranges_of_closed` は、範囲パラメータのない全定義で旧規則の受理から `Accepted` と旧い閉じた `BodyRanges` を返す。これは保存的な拡張の系である。`closed_extension` は五形で、旧規則が `unknownSource` で断り、新規則が受理する例を示す。`acceptBody_no_ranges`（選択なし）は等号の系から導く形に整理された |
| 軽3 | 可 | results.md は83,230バイト、resume9-10.md は48,012バイトである |
| 情5 | 可 | `contextsBlock_length` が文脈の列と `preorderBlock` の長さの一致を、`occurrences_zip_contexts_length` が `zip` で出現を落とさないことを示す |

### 重1・重2・中4

**模倣の形。** `Trace.Forward` は、元の一段に、同じラベルを出す対象側の有限実行を対応させる。対象側は一段以上進むか、又は事象を出さずに留まり、順位が真に減る。この順位の減少は型の上で要求される。`Setting.forward` は順位 `administrativeRank` で、`Setting.backward` は順位を定数0として示す。定数0の順位は減らないので、逆向きでは元の側が必ず一段以上進む。`Trace.accessible` は順位の整礎性から停止性を移す。有限の事象列・無限の実行・非停止・効果の被覆の保存は、すべてこの二つから導かれる。`Setting.forward`・`Setting.backward` は既定ビルドで検査された証明であり、Step の全ての規則の場合を含む。関係 `InvariantRel` は、状態の構造的な対応 `StateRel`、元の状態の生成名の不在、準備後の状態の型付けの組である。`StateRel` は終端の失敗と終了の payload を同じ値で対応させ、公開判定の途中（引数の束縛と取り出しの関数の呼出し）だけに専用の構成子を持つ。

**`observations_preserved`。** 比べるのは、`original`（元のプログラムを標準の本体と結合した核と、元の表 `q.B`）と、`resolved`（準備後の核と、準備後の表）の実行である。四つの同値は、`Trace.observations`・`Trace.infinite`・`Trace.diverging_prefixes`・`InvariantRel.effects` を、受理から作った `Setting` と main の開始の関係に当てて得ている。`Iff.rfl` ではない。準備が恒等のときだけ、二つの核と表が等しいことから直接得る。終端の観測 `terminal` は、失敗と終了を全 payload で、正常値を値の対応の同値類で比べる。Boolean の真と偽は区別される（同じファイルの例）。中4は処置された。

**前提の `p.WellFormed`。** 群 E の主保証の系は、準備後のプログラムの整形式 `hwf` を表層の整形式として別に受ける。元のプログラムの整形式も同じ種類の前提で、構文の前段が供給する条件である。生成した欄の行の `Valid` を元の宣言の整形式から導くために使っている。`PredicateMainExamples` は `source_wellFormed` でこれを証明している。前提として妥当である。

**main の証人。** `PredicateMainExamples.main_observations` は、事象列と観測を全称にした言明で、ほかに仮定を持たない（検査5の `#check`）。`main_guarantees` は、`String.charactersIn` を条件に書いた main について、`Accepted`・`ProgramGuarantees`・`MainGuarantees` を、内部行を加えた表 `Table.builtins data rows` の下で仮定なしで結論する。`entry_succeeds` は公開呼出しのままのソースで実入口の成功を示す。

**重ねた表。** `PredicateOverlayTable.builtins_eq` は、`Rows.Valid` と整形式の下で、重ねた表と内部行を加えた完成表の全欄の等号を示す。これで、群 D の `.predicates` の表の条件（`core`）がそのまま使える。`PredicateOverlayValues.prepared_standard_values` は、標準の構成データを持つ入力の準備後の表について、値の仮定を任意の核で示す。`accepted_standard_property1` はこれを `hvalues` へ渡し、`CheckPredicateProgramExamples.path_property1` が読む。重2は処置された。

**群 E の後半の追随。** `SurfaceLibrary.checkProgramAccepted_guarantees`・`checkProgramAccepted_main` は、型付けと保証の対象を準備後のプログラムと表へ移した。`CheckedMainExamples.main_guarantees` は言明を変えず仮定なしのままで、`checker_succeeds` の証明だけが `checkPreparedProgram` への展開に変わった。

**01-12 の記述。** 「処理系は名前解決を行わず、公開の呼出しを公開の行の δ で実行してよい」は、`observations_preserved` の結論（公開の行の実行と解決後の実行の観測の同値）と、その前提（実入口の受理と主保証の系の前提）に合う。正常値の比較が値の対応の同値類であることも、同じ章の理由に書かれている。処理系の δ と形式化の公開の行の δ の対応は、この定理の外の後段の照合である（情7）。

### 足す所見

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 軽4 | 軽 | `PredicateSimulationAlgebra.lean:189`・`448`、`PredicateSimulationTyping.lean:8`・`105`、`PredicateSimulationPipeSafety.lean:100`、`PredicateSimulationOpenPipeSafety.lean:6`・`103`・`232`、resume9-10.md の maxHeartbeats の段落 | 報告は「4か所」とするが、指定は4モジュールの8か所にある。記録の「除いた写しで四つとも timeout」は、モジュール単位の確認か指定ごとの確認かが読めない | 指定ごとに既定の上限での timeout を記録するか、モジュール単位の確認であることを書く | 読めば確定 |
| 情7 | 情報 | 01-12 の「処理系は名前解決を行わず…実行してよい」 | 形式化が保証するのは、公開の行の δ による実行と解決後の実行の観測の同値である。処理系の組込みの実装が公開の行の δ に一致することは、従来どおり後段（R 系）の照合が受け持つ。正常値は値の対応の同値類で比べるので、関数値の閉包のコードの一致までは主張しない | R 系の照合の表に、公開の行の δ と終端の観測の比べ方を受け口として写す | 読めば確定 |
| 情8 | 情報 | `resume10/checks.py` の `audit_input` | 監査は二種類の名前を対象に数えない。(1) 監査の実行中に実現され lookup できない62件。(2) 待ち行列に入れる段で `hasMacroScopes` を持つ名前で、こちらは環境に既にある名前も含む。どちらも依存先としては、それを使う宣言の `#print axioms` に推移的に含まれる。したがって、監査対象の定理の公理を見落とす余地はない。ただし (2) の名前は、それ自体が `axiom` であるかの照合（`AUDIT_AXIOM`）を通らない。ソースの `axiom` の字句の検査が補っているので、実害はないと読める | (2) で除いた名前の件数を記録し、その全てが `axiomInfo` でないことを同じ実行で照合する | 読めば確定。(2) の件数は確かめていない |

### 実行した検査

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 5 | `<tmp>/R10Axioms.lean`。`main_observations`・`main_guarantees`（群 D と群 E の後半）・`builtins_eq`・`prepared_standard_values`・`contextsBlock_length`・`occurrences_zip_contexts_length`・`accepted_no_ranges_of_closed` の `#check`。`main_observations`・両 `main_guarantees`・`observations_preserved`・`Setting.forward`・`Setting.backward`・`accepted_standard_property1`・`closed_extension` の `#print axioms` | 終了0。言明は上のとおりで、公理は `propext`・`Classical.choice`・`Quot.sound` だけ。初稿は群 E の後半の名前空間を誤って終了1となり、名前を直した |
| 6 | 読み取り専用の照会。`accepted_standard_property1`・`prepared_standard_values`・`builtins_eq` の読者、新規・変更のファイルの `sorry`・`axiom`・`native_decide`・`#eval`・`maxHeartbeats`、`checks.py` の監査の台本の書き換え | 三つとも読者がある。禁止した構文はない。上限の指定は軽4のとおり |

担当が記した既定ビルド1,678ジョブ・公理監査128,566宣言・照合の終了0は保存された記録として読み、本確認で実行した検査としては数えていない。確認用の最終入力は、`R10Axioms.lean` が1,409バイト（SHA-256 `88e10d5194edb1a4a84fb2d2cb724f1f180cb9b1da772ee460b07f20209c51bb`）である。

## 取りまとめの追記

- 2026-11-07: 再開10の処置の確認は可。初回の重1・中1〜3、処置の確認の重1（意味の一致）・重2・中4・中5 は閉じた。中5 の受理の拡大は、設計者の見直しの対象として plan.md に記録した。軽4 は取りまとめが `l70/d/resume9-10.md` の末尾に訂正を書いた。情8 は群 H の L70.46 へ申し送る。情7 は R 段の照合が受け持つ。
