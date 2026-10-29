# L40.4 の結果: Surface の型・値の型付けと検査器

2026-10-28。plan-l10-l50「L40」の表の L40.4 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l40.4`）で行った。担当は Claude のサブエージェントである。git の状態は変えていない（コミットは取りまとめが行う）。作業中に取りまとめから RV-L30 の二つの条件（Release の包含を構造上のまま保つこと、記録の引き方）を受け、本書の「RV-L30 の条件への対応」に扱いを書いた。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.4（Surface の型・値の型付けと検査器） |
| B_WORK | `819065c77c76028e08b27debac0e22a7e3b69875`（L40.3 と L30.4 の取り込みの後の本線） |
| 閉じた範囲 | 依頼の 1〜8。表層の組み込みの名前に範囲の列を持たせ、E-Prim を V-Prim と同じ具体化の形にした。脱糖は範囲の列を写す。検査器は範囲付きの項目を型付ける（許容の判定と計算できる具体化）。Scope の必須の判定の結果からの受理の判定、DET-05 の拒否の理由、明示拡大の行き先、問 3 の P1 の補題、旧の像での同値の補題、小例、01-12・07-04 |
| 未完 | なし（計画の行の範囲で）。受理した範囲の列と脱糖・コアの範囲の一致（`checkRule_index_agrees` の本番版）は L40.5、接続定理は L40.6、交換と入口への判定の組み込みは L50.1・L50.2 |
| 適用した前提の変更の行 | 停止の表の「表層の側の前提（`desugar_typed` の `hsig`、`p.WellTyped` の内容）」の L40.4 の分（`p.WellTyped` の E-Prim）と、S4 の行（L40.4 で外す分） |
| 停止条件 | 該当なし（下の「停止条件の点検」）。採用定義（`Scope/`）と `Release/` は変えていない |

## 試行

最初の約12分（06:00〜06:12）で、コミットしない試行として中心の変更を当て、排他の道具で全体の `lake build` を4回走らせた。記録は [trial/counts.md](trial/counts.md)、差分・全出力・未検査の一覧は `trial/` にある。

| 回 | 誤り | 失敗したモジュール | 未検査のモジュール |
|---|---:|---:|---:|
| 1（中心の変更だけ） | 14 | 3（構成子の引数の数） | 153 |
| 2（引数の数の機械的な追随を加えた） | 7 | 3 | 79 |
| 3 | 4 | 2 | 11 |
| 4 | 0（検査器の `primName_case` の仮置きの `sorry` だけ） | 0 | 0 |

構成子の引数の数の機械的な追随を除く壊れた宣言は5件（clean の不変条件の E-Prim、検査器の `primName_case`、`Interval.Sound.call_binding_target`、脱糖の型の保存の E-Prim、例1件）で、上端の2倍（12時間）を超える見込みはなかったので本体へ進んだ。仮置きの `sorry` は本体で証明に置き換えた。

## 変えた定義

| 定義（ファイル） | 変更 |
|---|---|
| `Surface.Expr.primName`（`Surface/Syntax.lean`） | 末尾に型検査器が選んだ範囲の列 `ranges : List Scope.Domain.Range` を加えた |
| `Surface.HasTypeQ.E_Prim`（`Surface/Typing.lean`） | 前提 `s.nranges = 0` を外し、V-Prim と同じく `B.RangeAdmissible b s rs` と `s.inst rs` の名前・`PrimitiveAdmissible`・`SingleTy`・型にした |
| 脱糖（`Surface/Desugar.lean`） | `directCallee` と `desugarExpr` の `primName` の腕が範囲の列をコアの `.prim b ts es rs` へ写す（2か所）。演算子・負号・連結・die の終了は空の列のまま |
| `Check.Input`（`Surface/Check.lean`） | 欄 `admitsRDec : PrimName → List Range → Bool`（既定は何も許さない）を加えた |
| 検査器の `primName` の場合（`Surface/Check.lean`） | `s.nranges == 0` の要求を、許容の判定 `CheckRanges.rangeAdmissibleCheck`・原子の閉包の判定 `instClosed` と、具体化した署名 `CheckRanges.instSig` での型の計算に替えた。誤りの文は "primitive range instantiation is not admitted"・"primitive range instantiation leaves the atom set" |
| `Check.Input.Sound`（`Surface/CheckLemmas.lean`） | 欄 `admitsR : CheckRanges.AdmitsRDecSound q.B q.admitsRDec` を加えた |
| `CheckTables.Materials.input`（`Surface/CheckTables.lean`） | 新しい欄に何も許さない判定を渡す（交換の材料は範囲を持たない） |
| `Interval.standardCallHead`・`targetOperationAt`（`Interval/Eval.lean`・`Interval/Sound.lean`） | 範囲の列が空の組み込みの名前だけを標準の呼び出しの頭として読む（旧の像の意味を保つ）。ほかの区間解析のファイルはパターンの引数の数だけ |
| 交換の読み込み（`Exchange/Convert.lean`） | 表層の組み込みの名前を空の範囲の列で作る（交換形式に範囲はまだない。L50.1） |

構成子の引数の数だけを追随したファイル: 表層 `BuilderExamples`・`BuilderFree`・`CheckExamples`・`CheckPredicates`・`CheckSupport`・`CheckToolsExamples`・`LogExamples`・`ScopeLower`・`WellFormed`・`CheckComputeCases`・`CheckSoundBasicExpr`、区間解析 `Analyze`・`BudgetChildren`・`BudgetCount`・`BudgetDiscover`・`BudgetWalk`・`DomainExamples`・`Eval`・`FixedDomainExamples`・`Identity`・`Sound`、`SurfaceCheck/Walk.lean`。`Release/` のファイルは一つも変えていない（並行する L30.5 との衝突はない）。

## 置いた定理

| ファイル（名前空間） | 定理 |
|---|---|
| 新 `Surface/CheckRanges.lean`（`Benitoite.Surface.CheckRanges`、16件） | `Ty.support_rawInstR`・`Ty.supportList_rawInstRTys`・`Eff.support_rawInstR`（相互帰納）、`Ty.support_instTarget`・`Tys.support_instTarget`、`instClosed_spec`、`instTy_eq`・`instEff_eq`、`inst_rawSupport`、`instSig_eq`（検査器の具体化は `s.inst rs`）、`inst_atoms`、`rangeAdmissibleCheck_sound`、`rangeAdmissibleCheck_nil`・`rangeAdmissibleCheck_nil_iff`、`instClosed_nil`、`instSig_nil` |
| 新 `Surface/ScopeAccept.lean`（`Benitoite.Surface.ScopeAccept`、25件） | `Required.ofIndex_index`、`acceptRange_sound`・`acceptRange_top_of_not_known`・`acceptRange_top_only`・`acceptRange_of_covers`・`acceptRange_top`・`acceptRange_unknown`・`acceptRange_exceeded`・`acceptRange_notCovered`、`acceptRanges_sound`、`acceptAtom_sound`・`acceptAtom_of_covers`・`acceptAtom_of_mem`・`acceptAtom_nameTop`・`acceptAtoms_sound`、`mem_statesAt`、`allOk_ok`、`acceptCall_sound`・`acceptCall_sound_unrecorded`・`acceptCall_top_of_top`、`acceptBody_occurrence`・`acceptBody_sound`、`widenPathIn_inst_ret`・`widenRequestIn_inst_ret`・`widenPathIn_inst_params`・`widenPathIn_target_unique`・`widenRanges_pathIn` |
| 新 `Surface/PrimRange.lean`（`Benitoite.Surface`、5件） | `HasTypeQ.E_PrimNil`、`ePrim_premises_iff_old`、`desugar_primName`、`Def.Scoped.rangeFree`・`Program.WellFormed.rangeFree` |
| 新 `Surface/ScopeAcceptExamples.lean`（`Benitoite.Surface.ScopeAcceptExamples`） | 定理 `checkPathIn_fnTy`・`checkPathIn_typed`、`example` 3件、`#guard` 37件 |
| 証明を変えた既存の定理 | `Check.primName_case`、`Check.computes_primName`、`Check.Input.Sound.withView`・`withNoFailRows`、`CheckTables.input_sound`、clean の不変条件の相互帰納（`Surface/Lemmas/Invariants.lean` の E-Prim の場合）、脱糖の型の保存の相互帰納（`Surface/Lemmas/Typing.lean` の E-Prim の場合。`V_PrimNil` から `V_Prim` へ）、`Interval.call_binding_target` |

未証明の theorem と `sorry` はない。新しいモジュールは既定の import（`formal/Benitoite.lean`）に入れた。

## 依頼の各点の扱い

1. **型と値**: 表層の型は Release の `Ty` であり、範囲付きの値型 `O[fixed R]` と範囲付きの原子 `L[fixed R]` は既に表せる。表層の整形式性は型注釈を `Ty.VarsIn 0` で読むので、プログラムの関数の型には範囲の変数が現れない（P1。`Def.Scoped.rangeFree`・`Program.WellFormed.rangeFree` で明示した）。組み込みの名前の範囲の列は閉じた範囲だけを持つ。**値の型付けの葉の規則は表層に足していない**（下の「ずれ」1）。範囲付きの値型の照合に変数か `_` が要ること（L20.4 の申し送り 9）は、表層の検査器の網羅性の判定が不透明型を変数か `_` だけで覆う型として扱うので、変更なしで成り立つ（範囲付きの値型を持つ照合の判定の健全性の証明も変えずに通った）。
2. **検査器と必須の判定**: 型検査器が選ぶ範囲の列の条件を `ScopeAccept.acceptCall`・`acceptBody` に置いた。Scope の規則を持つ出現（検査・射影・拡大）の範囲の列の各位置は、規則の `index` が L40.3 の記録の状態の抽象値から選ぶ範囲を覆うときだけ受理する（狭い契約は被覆を確かめたときだけ受理する）。未知・予算の超過で Top になった位置は Top の契約だけを受理する。Top を覆うのは Top だけで、`/**` も Top を覆わない（`acceptRange_top_only`、例）。受理は Scope の局所解析の記録だけを読み、区間解析の結果を読まない（`ScopeAccept` は `Interval.Eval`・`RangeState` を import しない）。
3. **明示拡大の S**: `widenRanges argTy expectedTy` が引数の型 `O[R]` と戻り値の注釈 `O[S]` から `[R, S]` を決め、具体化した戻りの型が同じなら行き先は同じである（`widenPathIn_target_unique`）。拡大の規則の `index` は R だけを選ぶので、S の位置には受理の制約を置かず、表の `admitsR`（S が R を覆う）が確かめる。
4. **検査器**: 検査器が範囲付きの項目を型付ける。`instSig` は計算できる正規化 `Ty.normWith` で具体化を計算し、署名の原子の具体化の像が候補の集合にあれば `s.inst rs` と等しい（`instSig_eq`）。

## 拒否の理由の対応（DET-05）

| 理由 | 返す場面 |
|---|---|
| `notCovered` | 既知の範囲を Top でない契約が覆わない（`acceptRange_notCovered`）。原子では、Top の原子を既知の由来で範囲付きの上限が覆わないとき、閉じた範囲の原子を同名の閉じた範囲の原子が一つ以下の上限が覆わないとき |
| `atomicCoverOnly` | 閉じた範囲の原子を、上限の同じ名前の Top でない閉じた範囲の原子が二つ以上あるのに一原子では覆えない（`0..9` と `0..4`・`5..9` の例） |
| `unknownSource` | 規則の `index` が Top を返し、解析が予算を超えていない位置の狭い契約（`acceptRange_unknown`）。Top の原子の由来が未知のとき |
| `budgetExceeded` | 規則の `index` が Top を返し、解析の `Run.exceeded` がある位置の狭い契約（`acceptRange_exceeded`）。Top の原子の由来が予算の超過のとき |

予算の超過の有無は解析の結果の `Run` が持ち、記録は状態だけを持つので、本体の解析のどこかで超過していれば、Top の位置の理由を全て `budgetExceeded` とする（L40.3 の申し送り 9。地点ごとの超過の理由が要るなら記録に `Run` を載せる）。

## RV-L30 の条件への対応

1. **Release の効果の包含は構造上のまま**: `Release/` を変えていない。Release の C-Sub と `Eff.Sub`、表層の `E_Sub`・`B_Sub` の `Eff.Sub` も構造上の包含のままである。被覆による受理（`acceptRange`・`acceptAtom`）は型付けの規則に加えて確かめる必要条件であり、構造上の包含なら必ず受理する（`acceptAtom_of_mem`）。被覆を Release に入れる必要は出なかった。
2. **記録の引き方**: `lookup` を使わず、出現の番号 k の記録の**全て**の状態で受理を求める（`statesAt` と `allOk`）。健全性は全称の形で述べた（`acceptCall_sound`: `∀ st, (k, st) ∈ records → …`）。L40.3 の存在の形の `analyzeBody_sound`・`analyzeBody_requiredIndex` と組み合わせると、番号の重複を仮定せずに、到達した局所に対応する記録の状態でも受理の条件が成り立つ。**辿らない式の中の地点**（記録のない出現）では外側の文の記録を使わない。事実を持たない状態で規則の `index` を計算するので、リテラルと `const` の直接参照の引数だけが既知になり、局所の引数は未知になる（`acceptCall_sound_unrecorded`、リストの要素の中の呼び出しの例）。

## S4 の中間状態をどこまで外したか

| 箇所 | L40.4 の後 |
|---|---|
| 表層の `E_Prim` の `s.nranges = 0` | 外した。V-Prim と同じく範囲の列で具体化する |
| 脱糖の組み込みの名前の空の範囲の列 | 外した。表層の範囲の列を写す（`desugar_primName`） |
| 表層の `E_Binary`・`E_Neg`・`StringAddOk`・`DieExitOk` の `s.nranges = 0` と、脱糖がそれらに書く空の列 | 残した。`OpPrim` と die の終了の名前は範囲の列を与えず、`desugarProgram opPrim p` は組み込みの表を受け取らないので、範囲の変数を持つ項目をこれらに使えない。L20.5 の S4 の代案 (a) の終わりの形と同じであり、L40.5 で外す必要はないと考える（取りまとめの確認を求める） |
| 交換の読み込みの空の範囲の列、`fromVal` の `.prim` の範囲の列の切り捨て | 変えていない（L40.5 の `throw`、L50.1 の読み書き） |
| 検査器の `s.nranges == 0` の要求 | 許容の判定に替えた。範囲の変数のない項目の空の列では同じ条件である（`rangeAdmissibleCheck_nil_iff`） |
| 脱糖が規則の index と同じ R を書くこと | L40.5（受理の判定 `acceptCall` が選ぶ範囲との一致） |

## 主定理の言明と前提の内容

| 主定理 | 言明の字面 | 前提の内容 | 旧の像での同値 |
|---|---|---|---|
| `Release.progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound` | L30.4 の後と同じ（`Release/` を変えていない） | 変わらない | — |
| `Surface.desugar_typed` | 同じ | `hsig`（`PrimSig.Scoped`）は変わらない。`p.WellTyped` は、組み込みの名前を範囲の列の許容と具体化した署名で型付ける内容に変わった（範囲の変数を持つ項目を呼べるようになり、広がる向き）。結論は同じ字面で、脱糖が写した範囲の列のコアの項が V-Prim で型付く | `ePrim_premises_iff_old`（範囲の変数のない `PrimSig.Scoped` の項目では、新しい E-Prim の前提と型は、列が空であることと L20.5 の後の E-Prim の前提と型の組と同値）、`desugar_primName`（空の列では同じ項を書く）、`HasTypeQ.E_PrimNil` |
| `Surface.surface_effect_soundness` | 同じ | `p.WellTyped` の内容は上と同じ変化。`hb` は L20.7 の後の `CoreAssumptions` のまま | 同上 |

旧の像の入力（組み込みの名前の範囲の列が空、表の項目が範囲の変数を持たない `PrimSig.Scoped`）では、E-Prim の前提と型は L20.5 の後の規則と同値であり、ほかの規則は変えていないので、表層の型付けの導出は前提の付け外しで対応する。旧の表層の型付けの相互帰納を別に並べた形式の同値の定理は置いていない（RV-L20 軽9 と同じ扱い）。

検査器の健全性（`checkExpr_sound` ほか、`CheckTables.checkProgram_sound`）の前提 `Input.Sound` は欄 `admitsR` が増えた。主定理ではないが、契約の内容の変更として記録する。既定の判定（何も許さない）と交換の材料の入力では自明に満たす（`CheckTables.input_sound`）。

## 確かめた例

`Surface/ScopeAcceptExamples.lean`（`#guard` 37件、定理2件、`example` 3件。大きな `decide` は使っていない）。

- 範囲の受理: 既知の `/data/**` を `/data/**`・`/**`・Top で受理、`/data/a/**`・`/database/**` を `notCovered`。未知は `unknownSource`、超過は `budgetExceeded`、どちらも Top は受理。既知の Top を `/**` は受理しない。
- 原子の受理: 一原子の被覆と構造上の包含を受理。`Http.Connect` の `0..9` を `0..4`・`5..9` で覆う判定が `atomicCoverOnly`、一原子の上限なら `notCovered`。旧の `File.Write`（Top）を `File.Write["/**"]` の上限が覆わず、由来により `notCovered`・`unknownSource`・`budgetExceeded`。
- 本体の受理（L40.3 の例の境界の表を使う）: `let r = Scope.checkPathIn(pattern: "/data/**", path: raw)` の範囲の列 `[/data/**]`・`[Top]`・`[/**]` を受理し `[/data/a/**]` を `notCovered`。局所のパターンでは `[/data/**]` を `unknownSource`、上限 0 の解析では `budgetExceeded`、`[Top]` は受理。リストの要素の中の呼び出し（記録のない出現）は、リテラルのパターンなら既知、局所のパターンなら `unknownSource`（外側の文の記録を使わない）。
- 検査器（`TargetTable` の表と例の判定 `admitsRDec`）: `Scope.checkPathIn[/data/**]` の型が `Result[Scope.PathIn[/data/**], Scope.ScopeError]` を返す関数の型、`File.writeTextIn[/data/**]` の引数と効果が同じ範囲、`Scope.widenPathIn[/data/a/**, /data/**]` を受理し逆向きを拒否、原子の一覧にない具体化（`[/data/a/**]`）・空の列・種類の違う範囲を拒否。
- 型付けと脱糖: `checkPathIn_typed`（表層の型付けで `Scope.checkPathIn` を `/data/**` で具体化した名前が型付く）、脱糖が同じ範囲の列のコアの項になる例、`widenRanges` の例。

## 設計書

| 文書 | 変更 |
|---|---|
| 01-12「型の情報を付けた表層の構文と型付け」 | 組み込みの名前が範囲の列を持つことを情報の一覧に加え、E-Prim の【決定】と理由・旧の像の補題・P1 の補題を書き直した（S4 の中間状態の記述を置き換えた） |
| 01-12 新しい節「Scope の必須の判定の受理と拒否の理由」 | 「Scope の局所解析の表層からの対応」の後に置いた（【決定】・写し・定理の表・独立例。区間解析の節と同じ構成）。` ```text ` のブロックは加えていない |
| 07-04「証明する性質」 | 性質 1 の前提の `p.WellTyped` の記述を組み込みの名前の範囲の列に合わせ、旧の像の補題に `ePrim_premises_iff_old` を加えた |
| 07-04「01-12 との対応」 | 組み込みの呼び出しの範囲の列の行の表層の記述を直し、L40.3 の行の「型検査器の受理の条件への接続はない」を次の行への参照にし、新しい二行（Scope の必須の判定の受理と拒否の理由、表層の組み込みの名前の範囲の列）を「Rust は未接続」で加えた |

見出しの参照: 新しい見出し「Scope の必須の判定の受理と拒否の理由」を `git grep` で探し、参照は 01-12 の本文の一か所、07-04 の新しい行、新しい二つの Lean のファイルの先頭のコメントだけである。既存の見出しは変えていない。RV-L30 の文言の修正は取りまとめが行うので触れていない。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 最初の全体のビルド（基準） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。455ジョブ | 2.41 秒（排他の待ち 0 秒） | [lake-build-first.log](lake-build-first.log) |
| 試行のビルド 4回 | 同上 | 1・1・1・0 | 6.03・70.70・89.48・23.42 秒（1回目は排他の待ち 129 秒） | `trial/` |
| 局所の単一ファイル（約12回） | `cd <wt>/formal && lake env lean -M 12288 <相対パス>` | 途中は 1（下の「失敗と修正」）、最後は全て 0 | 各 0.4〜数秒 | 本書 |
| モジュールのビルド（約8回。下流の単一ファイルの検査のため） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <一時ログ> <モジュール>` | 途中に 1 が2回、最後は 0 | 各数秒 | 一時ファイル（保存していない） |
| 本体の途中の全体のビルド 4回 | 同上 | 1・1・0・0（下の「失敗と修正」） | 各 5〜12 秒 | 一時ファイル（保存していない） |
| 作業末の全体のビルド | 同上 | 0。460ジョブ、`Build completed successfully`、`sorry` の出現 0。警告 88件（基準の 89件から1件減。新しいファイルの警告なし） | 81.36 秒（排他の待ち 0 秒） | [lake-build.log](lake-build.log)。その前の2回（新しい警告の修正の前）は `lake-build-1.log`・`lake-build-2.log` |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <l40.4>/axioms.lean`（`#print axioms` 62件） | 0 | 0.62 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base 819065c77c76028e08b27debac0e22a7e3b69875 --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` の変更による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 819065c77c76028e08b27debac0e22a7e3b69875` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.42 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |

公理: 62件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 39、`propext`・`Quot.sound` 19、`propext` だけ 4）。`sorryAx` と独自の公理はない。対象は新しい定理の全て（48件）、証明を変えた既存の定理6件、主定理8件（`progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`step_target_sound`・`desugar_typed`・`surface_effect_soundness`）である。

work の `formal_build` は `scripts/check.sh` の中の `lake build` で、排他の道具を通らない。作業末の全体のビルドの直後でビルド済みであり、組み立ては起きていない。Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。全体のビルドの値は並行するジョブの中で最大のプロセスの値である。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 最初の全体のビルド | 1525022720 | 1454.4 | 1.42 |
| 試行 1・2・3・4 | 1674362880・1574338560・2655141888・1527103488 | 1596.8・1501.4・2532.1・1456.4 | 1.56・1.47・2.47・1.42 |
| 作業末の前の全体のビルド（`lake-build-1.log`） | 3557539840 | 3392.7 | 3.31 |
| 作業末の全体のビルド | 1672347648 | 1594.9 | 1.56 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1383645184 | 1319.5 | 1.29 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1520091136 | 1449.7 | 1.42 |

本作業で観測した最大は 3.31 GiB（作業末の前の全体のビルド）である。`-M 12288` は変えていない。work の値は一括の実行の中で最大のプロセスの値であり、どのプロセスかは `time` から分からない。

## 失敗と修正

- 試行の1〜3回目が終了1（上の「試行」と `trial/counts.md`）。構成子の引数の数、clean の不変条件の E-Prim（`PrimSig.Scoped.inst_varsIn_zero` で直した）、区間解析の場合分け（範囲の列を場合分けに加えた）、脱糖の型の保存（`V_Prim` で直した）、例（`HasTypeQ.E_PrimNil` で直した）。
- 本体の途中のモジュールのビルド1回と全体のビルド2回が終了1: `CheckComputeCases.computes_primName`（具体化した署名の原子の支持が要った）、`CheckTables.Materials.input`（`Input` の欄の数）、`CheckTablesSound.input_sound`（`Input.Sound` の欄の数）。それぞれ直した。
- `ScopeAccept.lean` の局所の検査の1〜3回目が終了1: `split` で `match` の場合が閉じない（`by_cases` に直した）、`∀ i S q` の型の推論（注釈を付けた）、`List.forM` の簡約（自前の `allOk` に替えた）、`mem_statesAt` の `subst` の向き。`PrimRange.lean` で、相互帰納の型付けの導出の上の再帰（旧の像の表で範囲の列が空に限られる補題）が終了を示せず、補題を外した（旧の像の同値は `ePrim_premises_iff_old` で示す）。例の型付けで `SingleTy` が閉じず、型を具体の形に書き直す補題 `checkPathIn_fnTy` を置いた。
- 作業末の全体のビルドで、新しい例と `Interval.Sound` の未使用の simp の引数の警告が増えたので直し、全体のビルドをやり直した（警告は基準より1件少ない）。

## ずれと申し送り

### 計画からのずれ

1. **表層に値の型付けの葉の規則を足していない**。計画の行と依頼の 2 は「値の型付けに葉の規則を加え」とする（印 NS の 22 定理の場合分けが増える想定）。表層の構文は検査済みの対象の値を持たず（L20.4 の申し送り 9、01-12「値」）、ソースから書けない値の構成子を表層に足すと、Rust の表層の書き出しにない形と、脱糖の型の保存の新しい場合が増えるだけである。範囲付きの値型の値は実行時に δ が作り、コアの V-Checked で型付く。表層では、範囲付きの値型は組み込みの名前の具体化（E-Prim）と局所の型（`case Result.Ok(p)` の束縛）として現れる。NS の 22 定理は E-Prim の場合だけが変わった（clean の不変条件と脱糖の型の保存の2件）。この読み方でよいか取りまとめの確認を求める。表層に葉の規則が要ると判断されたら、構成子 `Expr.checked t` と規則 `E_Checked`、脱糖 `.ret (.val (.checked t))` を足す一度の切り替えになる（見込み 1〜2時間）。
2. **区間解析のファイルを変えた**。依頼の「編集してよい」範囲に `Benitoite/Interval/` はないが、表層の構成子の引数の数の追随に10ファイルを変えた。意味の変更は `standardCallHead`・`targetOperationAt` が空の範囲の列の組み込みの名前だけを読むこと（旧の像と同じ）と、`call_binding_target` の証明の場合分けである。採用定義 `Interval/BindingScope.lean` は変えていない。
3. **受理の判定を検査器の入口に組み込んでいない**。`acceptBody` は Scope の表（出現の解決 `resolve` と規則）と予算の上限を要るが、`CheckTables.checkProgram` と交換の材料はそれらを持たない。交換に加えるのは L50.2（「観測と拒否の理由（DET-05 の列挙）を交換に加える」）である。今は、受理の判定は独立の関数とその健全性であり、検査器と型付けは任意の許容される範囲の列を受理する（コアの検査の δ が動的なパターンと R の両方を確かめるので健全性は保たれる）。
4. **S4 の演算子・連結・die の終了の `nranges = 0` を残した**（上の S4 の表）。

### L40.3b への申し送り

5. 検査済みの要求の値と葉の規則を入れても、表層の構文と受理の判定は変えずに済む見込みである（表層は値を作らない）。`Http.checkRequestIn` の規則の `index` はリテラルのポートから選ぶ（`requestLitBound`）。

### L40.5 への申し送り

6. 脱糖は表層の範囲の列を写すので、「脱糖が型検査器の選んだ R をコアの項 `.prim` へ書く」は、`acceptCall` が受理した範囲の列が規則の `index`（記録の状態での）を覆い、検査の規則では index と一致する（`checkRule_index_agrees`）ことを示す形になる。受理は「覆う」ことだけを求め、等号を求めない（契約の範囲を広く書くことを許す）。等号が要るなら `acceptRange` を等号にする（推す案は今の被覆。L40.5 で決める）。
7. 交換の `fromEff`・`fromVal` の `throw`（RV-L10 中2・RV-L20 軽5）は未着手のままである。表層は範囲の列を持つようになったが、交換の読み込みは空の列を書くので、交換の経路で範囲付きの値は現れない。
8. `HasClausesQ` の節の添字 S（L30.1）は表層ではまだ Top である。

### L40.6 への申し送り

9. 接続定理の材料: `acceptBody_sound`（全称の形）と L40.3 の `analyzeBody_requiredIndex`（存在の形）を、記録の番号の重複を仮定せずに組み合わせられる。記録のない出現は `acceptCall_sound_unrecorded` を使う。受理した範囲の列が E-Prim の `rs` そのものであること（同じ構文の欄）は自明である。

### L50・R20 への申し送り

10. L50.1・L50.2: 交換形式に組み込みの名前の範囲の列、検査の入力の `admitsRDec`（表の `admitsR` と合う判定）、Scope の表と上限、拒否の理由 `CoverFailure` を加える。検査器の誤りの文 "primitive has range variables" は "primitive range instantiation is not admitted" に替わった（範囲の変数のない項目の空の列では同じ条件）。Rust の書き出しとの比較で文の違いを扱う必要がある。
11. L50.2・K10: 検査器は具体化の像の原子が候補の原子の集合にあることを要求する（`instClosed`）。交換の原子の一覧は、具体化した範囲の原子（`File.Write[/data/**]` など）まで含める必要がある（L50.1 の行の「書き出す原子の一覧を、具体化した範囲と署名の表の原子まで含めて作る」と同じ）。
12. R20: 型検査器の範囲の列の選び方は `acceptCall` に合わせる（記録の全ての状態、記録のない出現は事実を持たない状態、規則が選ばない位置は制約なし、予算の超過は Top の位置を全て `budgetExceeded`）。原子の `atomicCoverOnly` の判定（上限に同じ名前の Top でない閉じた範囲の原子が二つ以上）も Rust の E0519 の理由の判定に合わせるか、違えるなら Lean の側を直す。地点ごとの超過の理由は記録に `Run` がないので区別していない。

## 停止条件の点検

- `Release/` の主定理6件の言明と前提は変えていない。表層の二つの主定理の字面は変えず、前提の内容の変更は `p.WellTyped` の E-Prim だけであり、停止の表の「表層の側の前提」と S4 の行に含まれる。`Builtins.Assumptions` の欄の追加・公理の追加・結論の弱化はない。
- 採用定義（`Scope/` の五つのモジュールと `Interval/BindingScope.lean`）は変えていない。被覆による包含を Release に入れる必要は出なかった（RV-L30 の条件 1）。
- 検査器の健全性の前提 `Input.Sound` に欄 `admitsR` を足した。主定理ではなく、L40.4 の対象（`Check*.lean`）の契約の内容の変更として上に記録した。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 05:45 ごろ（JST、依頼文を読み始めた時刻。記録の最初の時刻は 05:51） |
| 終了 | 06:40 ごろ（本書の作成まで） |
| 外側の所要 | 約55分 |
| 能動時間 | 試行 約10分（06:00〜06:12 のうちビルドの待ちを除く）。本体 約35分（設計約8分、検査器の具体化と健全性約7分、受理の判定約8分、旧の像と P1 と例約6分、設計書約4分、本書約2分）。合わせて約45分。ほかに文書と既存の定義を読む約10分 |
| ビルドの回数と時間 | 全体のビルド 12回（基準 1、試行 4、本体の途中 4（うち終了1が2回。ログは一時ファイル）、作業末 3（保存した `lake-build-1.log`・`lake-build-2.log`・`lake-build.log`））。最長 89.48 秒。モジュールのビルド約8回、局所の単一ファイル約12回 |
| 検査 | work 1回 9.42 秒（dry-run 数秒）、公理の確かめ 2回（各 1 秒以下） |
| 待ち | 排他の道具の待ちは試行の1回目の 129 秒だけ。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.9〜6時間の下端を下回った。上端の2倍（12時間）を超えていない |
