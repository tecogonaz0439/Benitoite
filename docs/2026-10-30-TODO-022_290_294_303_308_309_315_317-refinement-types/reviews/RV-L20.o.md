# RV-L20.o: L20 群 O・P（L20.123〜.134）の独立レビュー

2026-11-03。対象はブランチ `m014/l20.o` の未コミットの作業木、基準 `428ed95f`（san_benito の先端）。依頼文 `L20.o-prompt.md`、担当の報告 `L20.o-report.md`、`l20/o/` の記録（results.md・signatures.md・value-signatures.md・declarations.tsv・各 json・contracts.lean・axioms.lean・signatures-o/p.lean・audit-*.txt）、`l20/detail.md` の G10・S12.5・L20.123〜.143 の行・群 O・P の見込みの行・O042・O065・O160・O027 の行・「本番追随の最初の同種19規則と残り27規則」、`plan.md` の外挿の節、`implementation-request.md` の RSS の扱い、`reviews/RV-L20.n.md` を読んだ。新規の Lean 17本のうち、LegacyTyping・LegacyValueEmbedding・LegacyValueCases・LegacySubCases・LegacyHeldCases・LegacyLambdaCase・LegacyCallInputs・LegacyOperationCase・LegacyCollectionCases・LegacyPrimitiveCase・LegacyPatterns・LegacyPatternMatch・LegacyPatternCoverage・LegacyPatternExamples・LegacyEmbeddingExamples は全文、LegacyTypeAlgebra・LegacyRangeAlgebra は宣言の一覧と言明を全件、証明は `legacy_primitive_type`・`legacy_old_instR_fn`・`legacy_instREff` の周辺を抜き取りで読んだ。既存の変更は `git diff` で読んだ。照合のために `LegacyRegularity.lean` の `LegacyNodeContext`・`LegacyNodeTypes`・`LegacyNodeRegular`・`LegacyRule`・`LegacyOutputInput`、`LegacyInput.lean` の値の入力、旧 `RangeInstDef.lean` の `Ty.instR`・`Eff.instR`、新 `RangeSubst.lean` の `Eff.mapRanges` を読んだ。補助の入力は `<tmp>/rv-l20-o/` に置き、既存のファイルを変えていない。

## 総合判定

**可**（重0・中0・軽5、計5件）。

埋め込みの骨格（.123〜.124）、パターンと網羅性（.125〜.128）、値19規則（.129〜.134）はいずれも可である。`LegacyRule.embed_value` は19枝すべてを、子の `Embedded`（任意の Φ の新しい型付け）から親の新しい型付けを HasTypeVQ の構成子で組み立てる補題として閉じており、意味の包含や値の像の等号で代用していない。`embedExhaustive` は全ての新しい所属値を旧の所属値へ写し、照合結果の対応で同じパターン列の成功を得る正しい証明である。反例と拒否の対照はどちらの側も意味を持つ。新しい公理・`sorry`・独立の信頼条件・既定 import からの除外はなく、公理監査の台本を再実行して、17モジュール499定数・558件の依存が許可三公理だけであることを確かめた。

所見は軽だけで、いずれも主な10言明・型付け規則・`ValueMeaning`・公理に触れない。網羅性の入口の前提の強さ（軽1）、記録の文言（軽2・軽3）、具体の適用例の範囲（軽4）、L20.143 への申し送り（軽5）である。

## 所見

### 軽

#### 軽1: `embedExhaustive` は `LegacyNodeTypes [a]` のうち範囲の深さ0の `WF` だけを読む（読めば確定、Lean で確認）

- 場所: `LegacyPatternCoverage.lean` 147〜160行（`embedExhaustive`。154行で `(types a _).2.1` だけを使う）、01-12・07-04 の追加段落「`embedExhaustive` は、…範囲の深さ0の `LegacyNodeTypes [a]`…から」、results.md の「署名と前提」の表。
- 問題点: 証明が使うのは `LegacyNodeTypes` の5成分のうち `embedTy a` の `WF`（範囲の深さ0）だけで、そこから `legacy_wf` で旧の `a.WF 0 nt` を得る。補助の入力 `probe1.lean` で、`LegacyNodeTypes` の代わりに `a.WF 0 nt` だけを受ける同じ証明（`probe_exhaustive_wf`）が通ることを確かめた。必要に近い条件は「旧型の範囲変数が0個であること」であり、`Sorted`・`Declared`・kind の成分は使わない。C_Match の node（`LegacyNodeRegular` の照合値の `.value` の子）が `LegacyNodeTypes κ C Γ.length [a]` を範囲の深さ0で常に持つので、L20.138 の適用に支障はない。detail の G10 の表もこの形を指定しているので、署名の誤りではない。問題は、設計書と results.md の書き方から「範囲の深さ0」が `LegacyNodeTypes` のどの成分で効くかが読めないことである。
- 修正案: 次のどちらかを取りまとめが選ぶ。(a) 署名はそのままとし、01-12・07-04・results.md に「`LegacyNodeTypes` のうち使うのは範囲の深さ0の `WF` だけで、反例 `opaque o (rvar 0)` はこの成分で拒否される」と一文足す。(b) `a.WF 0 nt` を受ける一般の補題を置き、今の `embedExhaustive` をその系にする。L20.138 は今の形をそのまま使えるので、(a) で足りる。

#### 軽2: results.md の「実装前に完全署名を signatures.md に固定し」は実物より強い（読めば確定）

- 場所: `l20/o/results.md` 26行、`signatures.md` 3行（「実装前に固定した署名を、最終の型検査の出力に合わせて示す」）。
- 問題点: 担当の実行記録では、最初に書いたのは七つの契約と帰納の骨格であり、パターン・照合・網羅性・値の各枝の署名は、各単位の実装と並行して signatures.md・value-signatures.md へ書き足し、最後に `#check` の出力で置き換えている。置き換えた後の内容はソースと一致する（「確認した事項」6）ので、記録の誤りは順序の説明だけである。
- 修正案: results.md と signatures.md の文を「七つの契約と帰納の骨格を実装前に固定し、各単位の署名は実装と並行して記録し、最後に型検査の出力に揃えた」に改める。

#### 軽3: 「浮動小数のビット値は復元しない」は Float64 だけに当たる（読めば確定）

- 場所: `LegacyPatternMatch.lean` 8行（`.float64 _ => .float 0`）と 22行（`.float32 b => .float32 b`）、01-12 3344行・07-04 221行の段落「パターンが比較しない浮動小数のビット値…は復元しない」、results.md 40行。
- 問題点: `legacyPatternConst` は Float32 のビット列を保ち、Float64 だけを旧の `.float 0` に写す。照合結果の一致は `legacy_patternMatches`・`legacy_patternRange` が全ての定数の組で `rfl` により示しているので、証明は正しい。文言が Float32 にも当たるように読める。
- 修正案: 三か所を「Float64 の値」に改める。

#### 軽4: `embed_value` の具体の適用は `V_Const` だけである（読めば確定、Lean で確認）

- 場所: `LegacyEmbeddingExamples.lean` 31〜33行（`unit_from_value_rule`）、`unit_from_induction`（`embed_constants`。`V_Const` と `V_Sub` の枝だけ）、results.md の L20.134 の行。
- 問題点: 19枝は一般に証明されており、各 case 補題には `embed_value` という読者があるので、依頼文の「公開した入口に読者を置く」は満たしている。ただし、具体の宣言表と組み込み表の下で `LegacyNodeRegular` が満たせることを示した値の規則は `V_Const` だけである。とくに `V_Fun`・`V_Prim`・`V_Op` は、例の表の `defs`・`sig`・`ops` がすべて `none` なので、具体の入力では一度も通らない。空虚の心配は小さい。補助の入力 `probe2.lean` で、同じ表の下で `V_List []` の `LegacyNodeRegular` を構成し、`embed_value` へ渡せることを確かめた。RV-L20.n 軽4 と同じ形の範囲の限定である。
- 修正案: 子を持つ枝（`V_List` か `V_Lam`）と、署名を引く枝（`V_Fun` か `V_Prim`）の具体例を一つずつ既定ビルドに足す。足さない場合は、results.md に「`embed_value` の具体の適用は `V_Const` だけで、残りの枝の入力の充足は L20.143 の合成で示す」と書く。

#### 軽5: 七契約の前提のうち `LegacyContextInput`・各項の入力・旧の型付けは、`Embedded` の合成では使わない見込みである（読めば確定。L20.143 への申し送り）

- 場所: `l20/o/contracts.lean`（`detail.md` の G10 の七署名の写し）、`LegacyTyping.lean` の `LegacyJudgment.Embedded`・`LegacyOutputInput.induct_regular`、`LegacyValueEmbedding.lean` の `embed_value`。
- 問題点: 七契約は `K.WF`・`LegacyTables`・`LegacyContextInput`・`LegacyValueInput` など・`LegacyOutputInput`・旧の `HasTypeVQ` などを前提に持つ。一方、`LegacyOutputInput` の各 node が `LegacyNodeRegular`（文脈・項の入力・型の入力）と `LegacyRule`（旧の局所規則）を既に持つので、`induct_regular` に `embed_value` と残り27規則の case 補題を渡す合成は、`K.WF`・`LegacyTables`・`LegacyOutputInput` だけで閉じる見込みが高い。値19枝の case 補題も、旧の型付けや `LegacyContextInput` を受けていない。そうなると、L20.143 で七定理を契約どおりの形で閉じたとき、`LegacyContextInput`・各項の入力・旧の型付けが使わない前提として残る。依頼文の「使わない前提を残さない」と、detail の「handoff の引数を省かず引き継ぐ」が衝突する。
- 修正案: L20.143 の依頼文に、どちらを取るかを先に書く。(a) 契約どおりの七定理を置き、使わない前提は handoff の形を保つためと docstring・results.md に明記する。(b) 前提の少ない七定理を主の入口とし、契約の形はその系として置く。前提を減らす向きなので主な言明の弱化には当たらないが、契約の変更なので取りまとめが決める。

## 確認した事項

### 1. 埋め込みの骨格（.123〜.124）

- `LegacyJudgment.Embedded` の七形は、G10 の七契約の結論と一字ずつ一致した。型文脈は各判断の κ を使う `legacyTypeCtx C κ`、ストアは `embedStoreTy Ψ`、値文脈は `Γ.map (Option.map embedTy)`、戻り先は `R.map embedTy`、局所文脈は `L.map (Option.map embedBuilderKind)`、腕の観測は `none` である。Φ は各形で全称に量化されている。Q は旧の `NoFailCtx` をそのまま渡す。
- `induct_regular` の motive は任意の `M : LegacyJudgment → Prop` で、step は親の `LegacyRule`・`LegacyNodeRegular`・全ての子の `LegacyOutputInput`・全ての子の `M` を受ける。子の文脈を変える規則（V_Lam の hide と bindParams、C_If の boolCond、C_Let・腕の localExtend、Clauses_cons の `replicate ++ κ`、Failure_one の `.value :: κ`）は、どれも子の LegacyJudgment の添字に現れており、子の `Embedded` が任意の Φ を持つので、残り27規則の合成でこの motive を作り直す必要は見当たらない。子の `LegacyNodeRegular` も子の `LegacyOutputInput` から取り出せる。`embed_constants` が実際にこの帰納を使っている。
- 片方向である。前提は、`K.WF`（V_Fun の宣言の kind の長さだけに使う）、`LegacyTables`（構成子の欄・制約・組み込みの署名と範囲の表）、親の `LegacyNodeRegular`（表現可能性・同じ対象/要求/端点・型の入力）、子の `Embedded` であり、すべて署名に現れる。隠れた前提や使わない前提はない（K.WF・tables は使う枝がある）。
- `legacy_local_zero` は、空の旧局所文脈では `LocalCtx.Shift.empty`、非空では `legacy_localExtend` による等号で `local_zero` へ渡す。`ValueAssumptions` を要求しない。適用例 `local_let`・`local_arm`・`nonempty_local_bound` は手で作った新しい導出への適用であり、埋め込んだ旧の let・腕への適用は L20.136・.141 で行う。detail の .124 の「実際の let/腕へ適用する」はこの範囲で満たされている。

### 2. パターンと網羅性（.125〜.128）

- `embedPatTy`・`embedPatTys` は旧の PatTy・PatTys の全構成子を同じパターンと `embedTys δ` へ写す。構成子の欄の形成は `tables.constructorFields` から取る。`embedAltsTy` は `selectSlots` の一致を `legacy_selectSlots` で示し、同じ束縛型列の像を持つ。三つとも `K.WF`・`LegacyNodeTypes` を受けない。
- `legacy_matchVal`・`legacy_matchList` は前提なしで全てのパターンと全ての新しい値について、旧の照合の結果が新の照合の結果を `legacyPatternVals` で写したものに等しいことを示す。checkedAt・checkedRequest は同じ対象の旧 `checked`、atError は `"Scope.ScopeError.At"` と七つの文字列、構成子と List は子の再帰で写す。値の像の等号は使っていない。
- `legacy_inhabits` は新しい Inhabits の全構成子を場合分けし、checked 系は範囲の深さ0（`rvar i` を `Nat.not_lt_zero` で排除）から旧 `checked` へ、構成子は欄の型を表から旧 `WF` へ戻して下降し、atError は `StandardError` から旧の構成子 `atDecl` 相当の七欄を得る。`dependentFn`・`external`・`scoped`・`refined` などは旧型の像に現れないので矛盾で閉じる。
- 反例: `old_range_exhaustive` は旧の `opaque o (rvar 0)` に所属値がないことによる空の網羅性、`new_range_not_exhaustive` は新しい `checkedAt` の所属による否定であり、無条件の含意 `旧 Exhaustive → 新 Exhaustive` を否定する。`range_input_rejected` は同じ型を `LegacyNodeTypes` の WF 成分で拒否する。受理側の `list_coverage`・`checkedAt_in_list` は、任意の範囲・対象・要求を持つ checkedAt を含む List が同じパターンで照合に成功することを示す。両側とも意味を持つ。
- 標準 At: `at_shape` は例の表の下で `StandardError` を構成し、`at_legacy_inhabits`・`at_pattern_typed`・`at_old_correspondence` が型・型引数0個・七文字列の束縛を照合する。`at_wrong_name`・`at_wrong_arity` は新側の照合の拒否、`at_type_argument_rejected` は型引数1個の旧型の入力の拒否である。
- 具体の宣言表・組み込み表は `kinds`・`oldProgram`・`oldBuiltins`・`builtins` の一組で、`tables`・`kinds_wf` を定理として構成しており、同時に満たせる。

### 3. 値19規則（.129〜.134）

- `embed_value` は `cases rule` で値の19構成子を全て扱い、各枝は対応する case 補題へ渡す。子を持つ枝（Lam・Con・List・Map・Set・Dict・CheckedRequest・Super・Sub）は子の `Embedded` を受け、HasTypeVQ の同名の構成子の前提へ渡す。
- V_Fun・V_Op は、旧署名から新しい依存列の `SignatureInstance` を `legacy_signatureInstance`（関数は `embedDefWithKinds_signatureInstance`）で作り、新しい `V_Fun`・`V_Op` の型を `legacy_instantiated_norm` の正規化した等号と `V_Sub` の `convert` で旧の fn 型の像へ移す。
- V_Prim は、`tables.primitives` の `LegacyPrimSignature` と親の値の入力から、範囲の許容（`legacy_RangeAdmissible`）・組み込みの許容（`legacy_PrimitiveAdmissible`）・`Tel.instR` した依存列の `SignatureInstance` を作る。`legacy_primitive_type` は、旧の最上位だけの具体化（`instTarget`）の fn 型が、結果型の範囲の深さ0・型引数と行引数の入力の下で全体の具体化の後の置換に等しいことを示す。範囲の列 `rs` は任意で、範囲のない署名に限っていない。
- 旧 `Eff.instR` は `RangeInstDef.lean` 64行で最上位の Fail の列を正規化せずに写し、新 `Eff.instR` は `Eff.mapRanges` が `norm` を取る。したがって正規化前の等号は一般に成り立たず、`legacy_instREff` を `(embedEff (Eff.instR rs e)).norm = Eff.instR …` に直した訂正は正しい。
- V_Lam は子の `Embedded` を `liftMany (embedTys ps).length Φ` に特殊化し、`legacy_hideBuilders`・`legacy_bindParams`・`legacy_hideConts` で文脈の像を揃える。NamesWF は長さの写しで供給する。
- V_CheckedRequest は子の `Embedded` を空の Φ（`ih []`）に特殊化し、`V_Normal` で包む。対象・範囲・内容の型は親の `LegacyHeldTypeInput` と値の入力から取り、旧と新の `valContent` の一致を `Option.some.inj` で揃える。
- V_Super は `embedProgramWithKinds_class` と結果の Declared、V_Sub は既存の `embedLe` と結果の `Annotation` の三成分で閉じる。
- 規則ごとの所要（rule-times.json）は、実行記録の中で `var_case` から `sub_case` までが規則の順に書かれ、各規則の後に局所の型検査が走っている順序と矛盾しない。6〜8秒の枝は既存の補題を一行で渡す枝で、局所の型検査が1秒未満で終わることも記録にある。V_Fun・V_Prim は共通の代数を含む。代数の一部（`legacy_subst` など）は表より前のパターンの段で作られており、results.md の「共通の骨格・パターン・局所文脈の作成はこの表より前」と合う。待ちと能動時間を分けず、E/19 を単価と呼ばない扱いは plan の外挿の節に合う。

### 4. 担当の主張

- 「値19枝は子の帰納仮説から親を構成する補題で、七判断全体の埋め込みは残り27規則と L20.143 の合成に残る」「状態・三親判断は含めない」は実物どおりである。一般の `embedHasTypeVQ` などの定理はなく、contracts.lean は Prop の型検査だけで、記録もそう書く。detail の G10 の表は embedHasTypeVQ の担当を「.123/.129〜.134」とするが、V_Lam の子が計算の判断なので値の判断だけでは閉じず、合成を .143 に置く担当の扱いが正しい。
- O042・O065・O160 の判定は「担当部分完了」とし、残る段を書いている。O027 は RSS を未取得とし、その理由を「限定採取の作業を追加していない」と書く。依頼文の書式（「未取得（計画上の非採取）」）と言い回しが違うが、内容は同じである。

### 5. 公理・署名・設計書

- 新規17本に `sorry`・`axiom`・`admit`・`unsafe`・`partial` はない。`legacyPatternVal` は明示的な noncomputable で、`_unsafe_rec` は生成されていない。新規16モジュールは `Benitoite.lean` に明記され、LegacyTypeAlgebra は LegacyTyping などから到達する（既存のモジュールも推移的な到達が普通である）。
- 公理監査: `axioms.lean` を `lake env lean -M 12288` で再実行し、終了0、17モジュールの定数の合計499、依存の印字558件、公理は propext・Classical.choice・Quot.sound だけだった。対象一覧は新規の17モジュールの全定数（生成定数を含む）なので、新規の公開入口を全て覆う。最大常駐量は 1,706,344,448 バイト（`/usr/bin/time -l`、手元の arm64/macOS）。
- declarations.tsv の161宣言は、全件が signatures.md か value-signatures.md の `#check` の出力にある。読者のない公開宣言は具体例の定理だけである。contracts.lean・signatures-p.lean は再実行して終了0だった。
- 01-12・07-04 の追加段落は同一で、変更の経緯の文はない（RV-L20.n と同じ形）。前提の書き方（`embed_value` の四つの前提、`legacy_local_zero` の `ValueAssumptions` 不要、パターン三補題の追加の前提なし、`legacy_inhabits` の三つの前提、`embedExhaustive` の三つの前提、`embed_constants` の入力が `LegacyOutputInput` だけ）は Lean の実物と一致した。浮動小数の文言は軽3、網羅性の前提の読み方は軽1。「構成する」は型付け・Inhabits・Exhaustive、「保持する」は照合が読む構造に使われ、実物どおりである。
- 名前は中身に合う。`LegacyValueCases` の名前空間に19の case 補題を置き、ファイルを枝の種類で分けている。

### 6. 記録

- 改造内の記録は最大が value-signatures.md の54,945 バイトで、いずれも 100 KB 以下である。手元の絶対パスは `<tmp>` に置き換えられ、`work/`・`reference/` の参照と docs/todo へのリンクはない。
- 改造に置いた json は検査・入力・公理・規則ごとの時間の要約で、lean は契約・署名・監査の再実行用の台本である。いずれも記録として妥当である。`rv-f-t2.lean` は変更されていない。

## 補助の入力

`<tmp>/rv-l20-o/` に置いた。

| ファイル | 内容 | 結果 |
|---|---|---|
| `probe1.lean` | 主な入口の `#check`・`#print axioms`、`a.WF 0 nt` だけを受ける網羅性の証明（軽1） | 終了0、診断なし |
| `probe2.lean` | 例の表の下での `V_List []` の `LegacyNodeRegular` の構成と `embed_value` の適用（軽4） | 終了0、診断なし |
| `axioms.out`・`axioms.time` | 改造内の `axioms.lean` の再実行 | 終了0、3公理だけ、依存558件、最大常駐量 1,706,344,448 バイト |

## 再レビュー（再開1）

2026-11-03。担当の報告 `L20.o-r1-report.md`、results.md の「再開1」の節、checks-resume1.json を読んだ。Lean は LegacyPatternCoverage の `embedExhaustive`、LegacyPatternExamples の変更（`unitOperation` を加えた宣言表、`list_coverage`・`range_wf_rejected`・`range_input_rejected`）、LegacyEmbeddingExamples の `list_from_value_rule`・`operation_from_value_rule`・`match_node_coverage` を全文読んだ。軽5は取りまとめの判断（plan.md の 2026-11-03 の項。前提の少ない定理を主の入口にし、契約の形の系は置かない。L20.143 で扱う）を確認し、本節の対象から外した。

### 判定

**可**（軽1〜4は閉じた。新しい所見はない）。

### 処置の確認

- 軽1（閉じた）: `embedExhaustive` の前提は `LegacyTables`・旧 `a.WF 0 nt`・旧 `Exhaustive` の三つになった。三つとも証明で使う（`legacy_inhabits` に tables と WF を渡し、旧網羅性からパターンを得る）。使わない成分はない。強い入口は消えた。読者は `list_coverage`（`list_input` の WF 成分を `legacy_wf` で移して渡す）と `match_node_coverage` の二つで、壊れた読者はない。既定ビルドの中にも旧い前提の記述（`LegacyNodeTypes [a]` の形）は残っていない。`match_node_coverage` は、Arms_plain・Arms_nil・C_Return の子を持つ実際の C_Match の node の `LegacyOutputInput` を構成し、照合値の子の `LegacyNodeRegular` から WF を取り出して適用する。L20.138 が使う経路そのものの適用であり、意味がある。照合するパターンは wild なので網羅性そのものは自明だが、この例が示すべき点は node からの WF の供給である。`range_wf_rejected` は `opaque o (rvar 0)` の旧 WF を直接否定し、弱めた前提でも反例の型が拒否されることを示す。`old_range_exhaustive`・`new_range_not_exhaustive` も保たれている。
- 軽4（閉じた）: `list_from_value_rule` は、Unit 一要素の List の `LegacyNodeRegular` を構成し、`V_List` の枝で `embed_value` を通す。子の `Embedded` は `unit_from_value_rule`（V_Const の `embed_value`）から作る。`operation_from_value_rule` は宣言表に実際の操作 `unitOp`（効果 `UnitEffect`）を加え、元の署名の `LegacyTypeInput` と `LegacyNodeRegular` を構成し、`V_Op` の枝で `embed_value` を通す。宣言表の変更の後も、`tables`・`kinds_wf` と既存の At の例は同じ表の下で通る。同じ表で同時に満たせる入力から実際に通している。
- 軽2（閉じた）: results.md 26行・signatures.md 3行・再開1の表は「七つの契約と帰納の骨格を実装前に固定し、各単位の署名は実装と並行して記録し、最後に型検査の出力に揃えた」となり、実物どおりである。
- 軽3（閉じた）: 01-12・07-04・results.md は「Float64 は旧の `.float 0` に写し、Float32 のビット列は保持する」となり、`legacyPatternConst` と一致する。01-12・07-04 の `embedExhaustive` の段落も弱めた三つの前提と、C_Match の子からの WF の供給を実物どおりに書いている。signatures.md の `embedExhaustive` の署名も新しい形である。
- 公理と sorry: 改造内の `axioms.lean` を再実行し、終了0、17モジュール509定数・依存568件で、公理は propext・Classical.choice・Quot.sound だけだった。新しい4つの例も監査の対象に含まれている。変更した3ファイルに `sorry`・`axiom`・`admit` はない。LegacyEmbeddingExamples の単独の型検査も終了0だった。最大常駐量は 1,708,097,536 バイト（`/usr/bin/time -l`、手元の arm64/macOS）。

### 補助の入力（追加）

| ファイル | 内容 | 結果 |
|---|---|---|
| `r1-examples.out` | LegacyEmbeddingExamples の単独の型検査 | 終了0、診断なし |
| `r1-axioms.out`・`r1-axioms.time` | 再開1の `axioms.lean` の再実行 | 終了0、3公理だけ、509定数・依存568件 |

## 取りまとめの追記

- 軽5は、取りまとめが plan.md の「計画の変更と取りまとめへの確認点」の 2026-11-03 の項で判断した。前提の少ない定理を主の入口にし、契約の形に揃えるためだけの系は置かない。L20.143 の依頼文に写す。
- 軽1〜4は担当の再開1で処置し、再レビューで可とした。作業末の work は終了0、147.84秒（l20/o/results.md「作業末の work」）。
