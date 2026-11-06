# RV-L70.d2: L70 群 D 再開5〜7（範囲パラメータを持つ利用者の関数の表層）の独立レビュー

2026-11-06。対象はブランチ `m014/l70.d2` のコミット `44d5f0ee` である。基準は `e70794188e24de95b5bb424f9d75090f77d1c703` で、差分 `git diff e7079418 44d5f0ee` を読んだ。本書の `<repo>` は対象の worktree、`<tmp>` は指定された scratchpad の `rv-l70-d2/`、C は本書を置く改造ディレクトリ、R は `<repo>/formal/Benitoite/Release/Refinement/` を表す。本レビューは本レビュー一回である。

読んだもの:

- 本体の作業木の依頼文 `work/m014/L70.d-r5-prompt.md`〜`L70.d-r7-prompt.md` と報告 `L70.d-r5-report.md`〜`L70.d-r7-report.md`、[群 D の結果](../l70/d/results.md)の「範囲パラメータを持つ利用者の関数（除いた範囲）」と再開5〜7、[再開5の停止](../l70/d/resume5-obstruction.md)・[再開6の停止](../l70/d/resume6-obstruction.md)。
- 本体の作業木の最新の `plan.md` の先頭の判断のうち、停止の条件の改め、群 D 再開5の停止（案 A）、再開6の停止（葉の構文上の条件と、合成表が満たせば止めずに進める条件 (i)(ii)）、群 K の取り込みの後の起動（発行専用の節を断ること）、RV-L70.k の情報1〜5、RV-L70.k-int の扱い。
- [U02 の決定](../u02/decisions.md)の S8・S9・S13・R3・R4・R5、[群 K の結果](../l70/k/results.md)の「性質1への受け口と見込み（中2）」、[RV-L70.k](RV-L70.k.md)・[RV-L70.k-int](RV-L70.k-int.md) の情報。記録の形は [RV-L70.d](RV-L70.d.md) の初回の部分に倣った。
- 変更した既存12モジュール（`Syntax`・`Rules`・`Desugar`・`Program`・`Theorems`・`Scoped`・`ScopedProof`・`Property1` 系）の差分と、新規37モジュールのうち `OpenSurface`・`OpenBody`・`OpenSurfaceProperty1`・`RangeStandard`・`RangeAliases`・`RangeFunctionExamples`・`RangeClauseExamples`・`OpenStandardClauses`。核の `RangeTyping`・`RangeCode`・`Admissible`・`HandlerContracts`・`ProgramWellFormed`・`External`・`Normalize` の関係する定義を読み合わせた。01-12・07-04 の差分。
- 群 D の `verify.py`・`prepare.py`・`axioms.lean` と保存された集計。台本は読んで判定し、実行していない。

したことは、規則の構成子の独立集計、全具体化の補題の言明と公理依存の確認、節の葉の条件についての受理と拒否の対照の Lean による確認、葉の条件の供給補題の読者の照会である。Lean は `<repo>/formal/` から `lake env lean -M 12288 <file>` で一つずつ実行し、確認用の入力は `<tmp>` に置いた。`-o` は使っていない。

`lake build`・cargo・`scripts/check.sh`・台本の実行・git の書き込み操作は行っていない。群 E の checker と、群 C・F2 の並行の枝との結合は検査していない。変更したリポジトリのファイルは本書だけである。

## 結論

**不可。重1件、中2件、軽2件、情報3件である。**

全具体化の性質1（`OpenSurface.BodyTy.desugar_at`・`desugar`）は、表層の95場合と本体の2場合を帰納で閉じており、葉に核の本体の型付けを置いていない。前提は `D.Realizes P`・`Builtins.ValueAssumptions P B` と具体化 σ だけで、新しい公理・`sorry` もない。発行専用の節の拒否は、選んだ組込みの一覧の `pathBases` の種類の節に限られる。しかし、節の葉が要求する署名の正規性 `ClauseSyntax` は、利用者の操作については合成表と無関係に成り立たず、範囲パラメータを持つ関数の本体で、正規形でない引数型を持つ利用者の操作の節を書けない。これは書ける形を狭める。

| 番号 | 重さ | 場所 | 問題 | 修正案 | 確度 |
|---|---|---|---|---|---|
| 重1 | 重 | `R/Surface/OpenSurface.lean:989` の `HasClausesQ.cons` の前提、`OpenSurfaceHandlers.lean:264` の `ClauseSyntax`、results.md「葉の条件と合成表」の節の行、01-12 の「プログラムから外部宣言や利用者の操作を除く条件ではない」 | 開いた節の規則は、節の署名の各引数型と結果型に `a.norm = a` を要求する。利用者の操作では `opSigAt` の `.user` が宣言の `params` をそのまま返し、`OpDecl.Scoped`・`Program.WellFormed` は正規形を要求しない。そのため、入れ子の篩（別名の展開や左結合の `and` で生じる形）を引数型に持つ利用者の操作の節は、範囲文脈の本体では全導出がない。同じ節は範囲のない `HasClausesQ.cons` では受理される（検査2）。合成表についての供給 `standard_clauseSig_prim` は組込みの節だけを覆い、(ii) の「合成表が満たす」は利用者の操作の節に当たらない | 正規性を前提に置かず、`rangeCtx rs (sg.context …)` と `sg.context` の正規化の同値（`rangeCtx_normEq` と同じ形の `Ctx.NormEq`）の下で節の本体を移す。又は、規則の文脈を `sg.params.map Ty.norm` で作り、元の文脈との同値で核の節へ接続する。いずれも利用者の操作の宣言に新しい条件を加えない。処置後、正規形でない引数型の利用者の操作の節を、範囲文脈の本体で受理する例を既定ビルドに置く | 実行で確定（検査2）。全範囲文脈についての全導出の否定と、範囲のない規則での受理を証明した。実際の交換の入力に正規形でない操作の型が現れるかは確かめていない |
| 中1 | 中 | `R/Surface/OpenSurface.lean:31`〜`61` の `Satisfies`・`Admits`・`Primitive`・`Signature`・`MethodRows`・`ExternalAdmits`・`RangesAdmit`、`RangeStandard.lean` の全補題、results.md「葉の条件と合成表」 | 許容と署名の葉は、全ての適格な具体化 σ についての条件として置かれている。案 A は許容についてこれを認めたが、合成表の補題 `admits_instR`・`sat_instR` は `s.admits`・`sat` の保存を示すだけで、葉の形（`Primitive` が要求する `PrimitiveAdmissible` の全欄、正規化した型引数、`Signature` の具体化後の `SignatureInstance`）を一度の開いた検査から供給する補題はない。`RangeStandard` の補題の読者は同じファイルの `example` だけで、受理例の葉は `ts = es = []` の場合に σ ごとに直接証明している。results.md の葉の一覧には `Signature`・`RangesAdmit`・`MethodRows`・`ExternalAdmits` の全具体化の条件が載っていない。群 E の L70.34 などの後段は、これらの全称の葉をどの有限の検査で満たすかを読めない | 各葉について、開いた型引数に対する一度の検査（`PrimitiveAdmissible`・`SignatureInstance`・`Admissible` を範囲文脈の注釈で述べた形）から全具体化の条件を導く導入の補題を置き、合成表についてはその補題と `admits_instR`・`sat_instR` を合成した形を示す。型引数が空でない合成表の組込みへ範囲変数を含む型引数を渡す受理例を一つ置く。results.md の葉の一覧を規則の前提と一対一に直す | 読めば確定（読者の照会は検査3） |
| 中2 | 中 | results.md「言明の差」、`R/Surface/Syntax.lean` の `Expr.primName`、`Rules.lean` の通常の `CallHeadTy.fn`・`fnDicts`・`prim`、`Theorems.lean` の `Program.WellFormed.defs`、`Property1Base.lean` の `Declarations.Realizes.ranges` | 差の表は言明の文字列の比較であり、範囲のない部分の定義・構文の変更を載せていない。`primName` の範囲の欄は `List Scope.Domain.Range` から `List RangeIx` に変わり、通常の `CallHeadTy.prim` は `RangeExpr` の全構成子（`based`・`secrets` を含む）を受けるように広がった。通常の `fn`・`fnDicts` は `RangesFit rs fd.rangeParams` を要求し、`Program.WellFormed.defs` は `SignatureScopedR` と範囲の深さ付きの `Scoped` を読む。後者には範囲のない場合に元の形へ戻る系がない。どれも範囲の量化を足す変更の内であり、性質1は保たれるが、並行の群 E の checker と交換の受け口が追随すべき差として読めない | 差の表に、変えた定義・構文・通常の規則の前提を一行ずつ加える。`Program.WellFormed` について、全関数の `rangeParams = []` のとき元の `SignatureScoped`・`Scoped` に戻る系を置く | 読めば確定 |
| 軽1 | 軽 | `R/Surface/OpenBody.lean` | `Le` の `refl`・`convert`・`trans` と `Covers` の `refl`・`empty` の構成子は、本番では使われず、`.source` だけが読まれる | 使う構成子だけを残すか、使う箇所を置く | 読めば確定 |
| 軽2 | 軽 | `C/l70/d/results.md` | 94,173 バイトで、各ファイル100 KB の上限に近い。次の再開の追記で上限を超える | 再開5・6の停止の詳細を停止の文書へ寄せ、results.md には要約と参照だけを残す | 読めば確定 |
| 情1 | 情報 | `RangeFunctionExamples.lean` の `host_primitive_def_wellTyped`・`standard_no_host_range` | host の受理例は例の中で作った表の組込みを使う。合成表の全377登録行の種類列に host がないことを全場合で証明しており、U02 R3（host を受け付け、host の範囲を添字に持つ型は別項目）と整合する。合成表で host を渡せる組込みは現れていないので、例を標準の host API の証拠に数えないという記録は正しい | なし | 読めば確定 |
| 情2 | 情報 | `OpenSurface.lean:175`・`335`・`474` の `d.parameters.RangesScoped 0` | 外部関数の葉の条件は、参照する宣言だけを検査し、外部宣言を持つ P を除かない。外部の署名は `kinds = []` で範囲パラメータを持たないので、自由な範囲変数を持たない正しい外部宣言を断ることはない。ただし `ExternalSignature.WF` の `annotation` が範囲深さ0の `WF` を含むので、この条件は `ExternalWF` から導ける見込みがある | 導ければ葉から除き、`ExternalWF` からの補題で供給する | 読めば確定。導出の可否は確かめていない |
| 情3 | 情報 | `OpenSurfaceProperty1.lean`、`Program.lean` の `BodyTyR.desugar`・`Def.WellTyped.desugar` | 性質1の構造は依頼の重点1を満たす。七つの相互判断の構成子は通常の規則と名前・順序・数が一致し（72・2・2・3・3・2・11）、本体の2場合と合わせて97場合を帰納する。各場合は子の導出の帰納法の仮定を同じ σ で使い、葉は全具体化の許容・形成の条件だけである | なし | 実行で確定（検査1・4） |

## 観点ごとの根拠

### 1. 全具体化の性質1

`OpenSurface.BodyTy.desugar_at` の言明は、`OpenSurface.BodyTy D B ks op Q C Γ Φ t body`・`D.Realizes P`・`Builtins.ValueAssumptions P B` と `σ : Instance ks` から、`TelBodyTy P B StoreTy.empty Q C (rangeCtx σ.val Γ) Φ (rangeTel σ.val t) ((desugarBlock op .tail body).instR σ.val)` を返す（検査4で `#check` を確認）。`desugar` はこれを全 rs についてまとめて `TelBodyTyR` を得る。空の種類列では `RangesFit [] []` の具体化を一つ選んで元の判断へ戻す。群 K の中2の受け口（表層の本体の一度の導出から、任意の `RangesFit rs ks` で `TelBodyTy` を得る）と同じ形である。

相互帰納の `HasTypeQ.desugar` などは、表層の導出の各構成子で子の導出の結論を同じ σ で受け、`local_core`・`head_expr_core`・`.C_Sub` などで核の規則を組み立てる。`ExprCore`・`BlockCore` は固定した具体化の核の結論の略記であり、`OpenSurface.lean` の規則の前提には `HasTypeCQ`・`HasTypeVQ`・`TelBodyTy` が一度も現れない。全称の葉は `Satisfies`・`Admits`・`Primitive`・`Signature`・`MethodRows`・`ExternalAdmits`・`RangesAdmit` の七つで、どれも許容又は署名の形成の条件である。部分型と効果の被覆は開いた `Ty.LeQ`・`Eff.Covers` を前提に置き、核の範囲の具体化の保存で移す。

`Def.WellTyped` は `AnnotationR` と `BodyTyR` を読み、`BodyTyR` は空の種類列で元の `BodyTy`、非空で `OpenSurface.BodyTy` を使う。`Def.wellTyped_no_ranges` が空の列で元の四条件と同値になる。`desugar_typed` の経路では、`declarationsFor_realizes` が `desugarProgram_ranges` で `rkinds = fd.rangeParams` を供給し、`Def.WellTyped.desugar` が `BodyTyR.desugar` を使うので、範囲パラメータを持つ関数も主定理の対象に入る。隠れた前提は見当たらない。

### 2. 葉の条件と合成表

`admits_instR` は `StandardModel.builtins_lookup_iff` で全登録行へ帰着し、`admits_form` の二形（制約の照合の写像と、List.sort の順序の検査）の両方で保存を示す。`sat_instR` は制約の照合が範囲の具体化で同値であることを示す。したがって、許容の述語そのものについて「渡せなくなる標準組込みは0件」は全377行で成り立つ。`standard_no_host_range` も全行の場合分けで決まる。

一方、規則が要求するのは述語の保存ではなく全称の葉である。`Primitive ks C nv s Q ts es` は全 σ で `PrimitiveAdmissible` の全欄（型引数の数、`Ty.normTys` を通した `admits`、型引数の範囲深さ0の `WF` と `Ordinary`、行の条件）を要求し、`Signature` は全 σ で具体化後の `SignatureInstance` を要求する。一度の開いた検査からこれらを導く補題はなく、`RangeStandard` の補題を葉へ接続する証明もない（中1）。`endpoint_standard_def_wellTyped` は型・行の引数が空の `Http.widenRequestIn` を使い、葉を σ ごとに直接証明しているので、型引数を持つ合成表の組込みへの適用例にならない。

署名と宣言の形成の葉（`PrimSig.Scoped`、関数・操作・メソッドの依存列の `RangesScoped` と `WF`、辞書の対象型とコンストラクタの欄の範囲閉性、`PatternRangesClosed`）は、合成表については `sig_scoped`・`function_formation`・`declarations_empty`・`pattern_ranges_closed` が供給する。利用者のプログラムについても、`OpDecl.Scoped`・`ConDecl.Scoped`・`ImplDecl.Scoped`・`SignatureScopedR` が範囲深さ0（関数は宣言した深さ）の形成を含むので、正しい宣言を断らないと読んだ。宣言の形成から各葉を導く補題が置かれていることは確かめていない。節の正規性だけがこの形にならない（重1）。外部関数の葉は情2のとおりである。

### 3. 三つの形の規則

`RangeArgument ks (.rvar i) k` は呼出し元の i 番目の種類が k に等しいこと、`.fixed r` は `r.WF ∧ r.Canonical ∧ r.FitsKind k` を要求する。`RangeArgument.close` は `RangesFit rs ks` の具体化で閉じた列を `RangesFit … kinds` に移すので、核の `V_Fun` の `RangesFit rs d.rkinds` と `RangeIx` の照合に合う。U02 S8・S9 の位置（範囲付きの値型の添字と効果の引数）と R5（関数と別名に書ける）を受け、R4 の閉じた原子との混在は効果の行の側で扱われる。

`desugarDef` は `rkinds := d.rangeParams` を置き、`directCallee` と `desugarExpr` は `funName`・`funDicts` の範囲の列を `Val.fnRef` へ渡す。RV-L70.k-int の情1（`rangeParams` が読まれない）は解消した。通常の `CallHeadTy.fn`・`fnDicts` は閉じた列 `rs.map RangeIx.fixed` と `RangesFit rs fd.rangeParams` を受け、範囲パラメータを持たない関数への呼出しは既定値 `[]` で元の形になる。範囲のない本体から範囲パラメータを持つ関数を閉じた範囲で呼ぶ形も通常の規則で受ける。ただし、この規則と `prim` の前提の変更は差の表にない（中2）。

`AliasDecl.expandOpen_annotation` は `RangeArguments` と開いた文脈 `openContext` の下の値引数の条件から、展開の `AnnotationR` を返す。閉じた `expand_annotation` の言明は変わっていない。

### 4. 発行専用の節の拒否

`ClauseAllowed D B o` は、`o = .prim b`、`B.sig b = some s`、利用者の操作の一覧のないラベル l（`D.effects l = none`）、`B.effects l = some bs`、`b ∈ bs` のときだけ `s.kind ≠ .pathBases` を要求する。`.user` の節は `ClauseAllowed.user` で常に通り、`pathBases` 以外の種類の組込みの節も断らない。通常と開いた節の規則の両方が読み、`standard_issue_clause_rejected` と `user_clause_accepted` が同じ `Process.Environment` の効果で対照を作る。断る範囲は承認された範囲に限られる。

### 5. 既存の言明の差

`desugarProgram_ranges` は、結論を `d.rkinds = fd.rangeParams` に変え、`desugarProgram_ranges_no_ranges` が表層の全関数の種類列が空のときに元の結論 `d.rkinds = []` を返す。`Declarations.realizes_no_ranges` は表層の種類列が空という前提 `hs` を受け、両方の列が空のとき元の四条件との同値を返す。どちらも系で元の形を回復する。

スコープの補題は、`HasTypeQ.scoped`・`HasClausesQ.scoped`・`DictEv.ScopedList.toValList` を基準の版と照合し、名前・暗黙引数・前提・結論の文字列が一致した。`Expr.Scoped` などの追加の `nr` は既定値0の省略可能な引数であり、元の呼出し形の意味は変わらない。一般化は `_ranges` 名の補題に分かれ、旧名はその `nr := 0` の適用である。

### 6. 守ること

新規・変更のモジュールに `axiom`・`sorry`・`#eval`・`native_decide` はない。手で書いた private 宣言は、同じファイルの中に読者がある。`maxHeartbeats 400000` は `OpenSurfaceProperty1` と `OpenSurfaceScoped` の相互証明の二か所で、既定値での時間切れの記録が `resume7-limits.json` にある。01-12・07-04 の写しは今回の定義と規則に当たる箇所であり、経緯の文や工程の ID はない。ただし 01-12 の節の葉の記述は重1の処置に合わせて直す必要がある。記録は群 D 全体で約290 KB、最大は results.md の94 KB である（軽2）。

## 実行した検査

Lean はすべて `<repo>/formal/` から実行し、同時に一つだけとした。既定のビルド出力は上書きしていない。単独検査は対象 worktree の既存のビルド済みモジュール（最終ビルドの時刻のもの）を import する。

| 番号 | 内容・入力 | 結果 |
|---|---|---|
| 1 | 記録を書き換えない Python の独立集計。`Rules.lean` と `OpenSurface.lean` の七つの相互判断の構成子の名前と順序 | 72・2・2・3・3・2・11 の95構成子で、名前と順序がすべて一致 |
| 2 | `<tmp>/ClauseNormal.lean`。引数型が `.refined (.refined Integer falsity) falsity` の利用者の操作を一つ持つ宣言の表で、その型が `norm` の固定点でないこと、範囲のない `HasClausesQ` で節を受理すること、任意の `ks` の `OpenSurface.HasClausesQ` で同じ節の全導出がないことを証明 | 終了0、出力・警告なし。重1を確認。初稿は名前空間の曖昧さと `OpSig.WF` の簡約の不足で終了1となり、確認用入力を直した |
| 3 | 読み取り専用の `grep` による照会。`admits_instR`・`sat_instR`・`signature_ranges`・`function_formation`・`clause_formation`・`pattern_ranges_closed`・`external_signature_formation` の読者と、全称の葉を作る導入の補題 | 読者は `RangeStandard.lean` の `example` だけ。葉を導く一般の補題はなく、`OpenSurface.Signature` を結論に持つ定理は受理例の一つだけ |
| 4 | `<tmp>/Axioms.lean`。`desugar_at`・`desugar` の `#check` と、全具体化の補題・`BodyTyR.desugar`・`desugar_typed`・`Def.wellTyped_no_ranges`・`desugarProgram_ranges_no_ranges`・受理と拒否の例・`admits_instR`・`pathAlias_expandOpen_annotation` の `#print axioms` | 終了0。言明は前記のとおりで、公理は `propext`・`Classical.choice`・`Quot.sound` の範囲内 |
| 5 | 読み取り専用の git 照会。スコープの3補題の基準と成果の header、`Scoped` の追加引数の既定値、新規ファイルの private 宣言の読者、禁止した構文 | header の一致、既定値0、読者のない private 宣言なし、禁止した構文なし |

担当が記した既定ビルド1,422ジョブ・公理監査4,590宣言・照合の終了0は保存された報告として読み、本レビューで実行した検査としては数えていない。`verify.py` は実行していない。

確認用の最終入力は、`ClauseNormal.lean` が2,177バイト（SHA-256 `f23108cc78109f92e365bb2ac336c95a56554329c2608162ed6e2985928cbd01`）、`Axioms.lean` が647バイト（SHA-256 `e025eb657f5c32c5819c0da6586c576fce3843c4d7e813d8de895cf7c69c72fc`）である。

## Opus による処置の確認と群 E の追随のレビュー（2026-11-06）

対象はブランチ `m014/l70.d-int` のコミット `a7ade0e5` で、`git diff 601a52ca a7ade0e5` を読んだ。その後の `b3445f14`（群 F2 と消去の取り込み）の衝突の解き方は確かめていない。読んだのは、依頼文、報告、[d-int の結果](../l70/d-int/results.md)・`closed-notes.md`・`leaf-notes.md`、[群 D の結果](../l70/d/results.md)、01-12・07-04 の差分、変更した Lean のうち `OpenSurface`・`OpenSurfaceHandlers`・`OpenSurfaceProperty1`・`OpenSurfaceScoped`・`OpenBody`・`NormalContext` の言明、`RangeClauseExamples`・`RangeStandard`・`OpenLeafFormation` の言明、`CheckBuiltinSource`・`CheckInput`・`CheckHandler`・`CheckOpenArgumentLeaves`・`CheckOpenArguments.head`・`CheckOpen.checkClausesAt`・`CheckOpenDeclarations`・`CheckDeclarations`・`CheckDeclarationBase`・`CheckDeclarationsSound`・`CheckProgramSound`・`CheckTables`・`ScopeAccept`・`Theorems` の差分、実入口の例（`CheckOpenExamples`・`CheckOpenStandardExamples`・`CheckOpenAcceptanceExamples`・`CheckClauseExamples`）である。

### 結論

**可。残った所見は軽1件、情報3件である。** 重1・中1・中2・軽1・軽2は処置された。群 E の追随にも、健全性を弱める接続や、隠れた信頼条件は見当たらない。

| 番号 | 重さ | 場所 | 問題 | 修正案 |
|---|---|---|---|---|
| 軽1 | 軽 | 01-12 の拒否の理由 `CoverFailure` を定める段落（「`unknownSource`（由来を認定できず Top になった）」） | `acceptOccurrence` は、必須の規則が選ばれた位置の契約が固定した絶対範囲でない場合（`.rvar`・based・secrets）にも `unknownSource` を返す。同じ章の `CheckAccept` の段落はこれを書いているが、理由の定義の段落は Top の由来の場合だけを定義しており、二つの記述が合わない | 定義の段落に、開いた契約の場合も `unknownSource` を返すことを一文で加える。処理系の E0519 の分類へ写すときに、別の理由にするかは処理系側の改造で決める |
| 情1 | 情報 | `ScopeAccept.acceptOccurrence`、`CheckOpenStandardExamples.endpoint_forward`、07-04「実入口の例は…標準の endpoint 組込みを受理する」 | 開いた契約を `unknownSource` で断るのは、全具体化の被覆を求める以上必要である。狭い具体化は推論した範囲を覆わないためで、Top に読み替えないのは正しい。ただし実用上は、範囲パラメータを持つ関数の中で、検査・射影・拡大の規則が選ぶ位置に範囲変数を書くと、必ず受理の段で断られる（例 `Scope.checkPathIn[x]`、`Http.widenRequestIn[x, …]` の内側）。`endpoint_forward`（`Http.widenRequestIn[x, x]`）は `checkDef` の型付けでは通る。しかし、規則表が拡大に `widenRule` を与えるなら（添字は位置0を選ぶ）、`checkProgramAccepted` の受理の段で `unknownSource` になる。閉じた関数で引数が未知のときに Top だけを受理するのと同じ程度の制限であり、新しい信頼条件ではない | 設計者の見直しの表のこの行に、実用への影響（範囲変数を受けた関数の中では、検査・拡大の規則の位置に範囲変数を書けないこと）を添える。07-04 の「受理する」は型付けの入口の受理であることを明記する |
| 情2 | 情報 | `CheckHandler.clauseAllowed`、`ClauseAllowed` | checker は pathBases の組込みの節を、効果の一覧の所属を問わず全て断る。表層の `ClauseAllowed` が断るのは、選んだ一覧の場合だけである。一致は片方向（checker の方が強い）で、01-12 もそう書いている。余分に断るのは pathBases の節だけで、これは呼ばれない節である。利用者の操作と通常の IO の節は、閉じた実入口（`CheckClauseExamples`）で受理される。開いた `checkClausesAt` も同じ `clauseAllowed` を読む | なし |
| 情3 | 情報 | `CheckOpenArgumentLeaves.typeArguments`・`ranges`、`Check.BuiltinSource` | 任意の表（`.custom`）では、組込みへ渡す型引数の範囲閉性と固定した範囲引数を求める。そのため任意の表では、範囲変数を組込みへ渡せない。標準表（`.standard`）は `RangeStandard` の保存補題を使い、この制限を受けない。固定範囲の受理も元の `admitsR`（`s.Covers r`）と同じ被覆で、全 Top の場合だけ広い。`.unrestrictedRanges` は `admitsR` を真に置き換えた別の表であり、元の表についての主張ではないことが記録されている。実際のプログラムが標準表を選ぶ限り、書ける形は狭まらない | 実入口の材料（`Materials`）がどの構成元を選ぶかを、群 E の後段の交換の受け口で固定するときに確かめる |

### 観点ごとの根拠

**重1。** `OpenSurface.HasClausesQ.cons` と `ClauseSyntax` は `a.norm = a` を求めなくなり、範囲閉性 `RangesScoped 0` だけを残した。`clauses_cons_core` は、空の具体化では元の本体をそのまま使う。非空の具体化では、`rangeCtx_clauseContext_normEq` が与える文脈の正規形の一致を使い、`NormalContext.comp` で節の文脈へ型付けを移す。この移送が読むのは既存の `Builtins.ValueAssumptions` だけで、新しい仮定はない。空の範囲文脈では、構成子 `closed` が元の節列の全導出を受ける。性質1の `.closed` の場合は元の `HasClausesQ.desugar` に、スコープの場合は `scoped_ranges` に帰着する。非空の範囲文脈で残る差は `RangesScoped 0` だけである。これは `OpSig` の範囲深さ0の形成で、宣言の形成と標準表の `clause_formation` が供給する。checker も `clauseSyntaxCheck` で同じ条件を検査する。前回のレビューの反例（引数型が `.refined (.refined Integer falsity) falsity` の利用者の操作）は、範囲を除いた規則と空の開いた文脈では `nested_clause_no_ranges` で、任意の `ks` では `nested_clause_open` で受理される。後者は、その型が正規形でないことも同じ言明に含む。

**中1。** 七つの葉は、`OpenLeafFormation` の有限な形成の構造（`PrimitiveCheck`・`AdmitsCheck`・`SignatureCheck`・`MethodRowsCheck`）と、`RangeStandard.primitive_of_check`・`satisfies_of_check`・`admits_of_check`・`ranges_of_check`、`external_of_check`・`ranges_of_fixed` から導かれる。`admits_instR` は `primitive_of_check` が読み、`sat_instR` は `sat_range_norm` を経て `satisfies_of_check` が読む。この二つを本番の `CheckOpenArgumentLeaves.satAll_sound`・`primitive_leaf`・`admissible_leaf`・`ranges_sound` が呼び、`CheckOpenArguments.head` の検査の成功から葉が得られる。したがって、`example` でない読者がある。型引数が空でない受理例 `RangeLeafExamples.list_length_reference` も置かれた。

**中2。** 差の表には、`primName` の欄、通常の `CallHeadTy.prim`・`fn`・`fnDicts`、`Program.WellFormed.defs`、`Check.Input.B`、`CheckFormation.Input`、群 E の3言明の行が加わった。`Program.wellFormed_no_ranges` は、全関数の `rangeParams = []` の下で、元の `SignatureScoped`・範囲深さ0の `Scoped` を含む五条件と同値になる。`Examples` の `example` がこれを `mainProgram` に適用している。

**群 E の追随。** 617言明の差は `checkDef_ok`・`checkDef_unknown`・`checkDef_sound` の3件である。それぞれ次の系で元の形へ戻る。

- `checkDef_ok`: 空列の前提 `hk` を加えた。
- `checkDef_unknown`: `checkDef_no_ranges_unknown` と `programStopped_no_ranges` で元の `BodyTelStopped`・存在形に戻る。
- `checkDef_sound`: `checkDef_no_ranges_sound` で戻る。ただし `d.rangeParams = []` を前提にする。範囲の欄を加えた後の系として自然であり、元の定理の適用範囲を狭めるものではない。

非空の場合に読む構成子一覧の完全性は、`checkProgram_sound` が既存の `hn.ctorNames` から供給する。プログラムの健全性に新しい外部条件は加わっていない。開いた本体は次の手順で検査する。推論 `inferBlockExpected` が案内を計算し、`CheckFinite.guide` で有限化し、`CheckOpen.checkBlockAt` で再検査する。`OpenSurface.BodyTy` はこの再検査の成功と `checkBlockAt_sound` だけから導き、推論の結果は信頼しない。`OpenSound` が含む `constructorsClosed` も、入口で実際に計算している。実入口の受理例（`function_forward`・`primitive_forward`・`alias_annotation`・`endpoint_forward`）は、いずれも `checkDef` に案内を渡さず、`cbv` で計算して閉じている。`function_forward_wellTyped` は、入力の全 `Sound` と支持を構成して公開の `checkDef_sound` を適用している。閉じた補助入口 `checkDefWith` は空列を検査し、元の健全性へ `Def.wellTyped_no_ranges` で戻る。非空の場合を閉じた成功と同一視する経路はない。

**止めずに進めた変更。** 開いた契約の `unknownSource` は情1、任意の表の範囲閉性は情3のとおりである。どちらも制限であるが、全具体化の量化の下で必要なものか、任意の表に限られるものである。新しい信頼条件ではない。表のほかの行（`Le`・`Covers` の未使用の構成子の削除、`ValueAssumptions` の受け渡し、`Identity`・`ScopeLower` の欄数）にも、書ける形の制限や新しい仮定は見当たらない。

**守ること。** 変更した Lean のファイルに `axiom`・`sorry`・`#eval`・`native_decide` はない。`maxHeartbeats 400000` は前回と同じ二か所だけである。`cbv_opaque`・`cbv_eval` の局所属性は、例のファイルにだけある。読者のない private 宣言は、変更した主要なファイルを読んだ範囲では見当たらない。全宣言の照合は、担当の公理監査の記録に拠り、本レビューでは数えていない。軽1（`OpenBody` の未使用の構成子）は削除された。軽2の記録の大きさは、`d/results.md` 60,111 バイト、`d/resume5-7-details.md` 47,459 バイトであり、ファイルごとの上限を下回る。

### 実行した検査

| 番号 | 内容 | 結果 |
|---|---|---|
| 1 | 読み取り専用の `git diff`・`grep` による照会。前記のファイルの差分、`admits_instR`・`sat_instR`・`ClauseSyntax`・`unrestrictedRanges`・`widenRule` の読者、禁止した構文 | 前記のとおり |
| 2 | `<tmp>/rv-l70-dint/Check.lean`（1,657 バイト、SHA-256 `07aa23329612f32d76f9adf3ab36526fef7a3dd9c9c227c0ae5e866f38eb8d87`）。`nested_clause_open`・`checkDef_no_ranges_sound`・`Program.wellFormed_no_ranges`・`programStopped_no_ranges`・`acceptBody_ranges` の `#check`、受理例と健全性の `#print axioms`、`Http.widenRequestIn[x, x]` の出現で規則がある場合に `acceptOccurrence` が `unknownSource` を返すことの `example` | **実行していない。** 取りまとめの `lake build` が 21:40 に終わった時点で、作業木の生成物に `RangeClauseExamples`・`CheckOpenStandardExamples`・`CheckOpenAcceptanceExamples`・`CheckProgramSound` などの `.olean` がなく、`lake env lean` で import できなかった。`formal/.lake` に書き込まない指示に従い、ビルドもしていない。上の結論は読むことで確定した範囲に拠る。公理と既定ビルドについては、担当の記録（1,529ジョブの既定ビルド、全環境の公理監査、最終 `verify`）を報告として読み、本レビューの検査には数えていない。取りまとめのビルドが成功した後に、この入力を一度実行することを勧める |

`lake build`・cargo・`scripts/check.sh`・台本の実行・git の書き込み操作は行っていない。変更したリポジトリのファイルは本書だけである。
