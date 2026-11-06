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
