> 本書の二候補は採用しない。取りまとめは制約の読み手を正規形へ揃える第三案を採った。

# 型パラメータの移動と正規化の間に残る契約

2026-10-31。rawApply の第三案を実装した後の、別の反例の報告である。[source-kind-contract.md](source-kind-contract.md) の二案を再提案するものではない。rawApply_norm・Ty.subst_norm_images・Ty.subst_norm_typeImages・Ty.bind_sameTypes は無制限の形で証明できた。

## 反例が否定する主定理

[TypeShiftTyping.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftTyping.lean) の HasTypeVQ.shift_types は、型付け h、Builtins.TypeAssumptions、StoreTy.WF、TypeParamRenaming、文脈長の等式、TypeCtxMap を受け、Val.shiftEAt 後の同じ値の型付けを返す。定理の言明は変更していない。

[type-shift-normalization-obstruction.lean](type-shift-normalization-obstruction.lean) の full_shift_types_counterexample は、この全前提と結論の否定を同時に証明する。shift_types_contract_false は、同じ入力へ特殊化した主定理の含意そのものを否定する。壊れている TypeShiftTyping を import しない。操作値の型付けの否定は、V_Sub/V_Refine を含む HasTypeVQ の全28場合を消去する。

具体的な入力は次のとおりである。

| 欄 | 入力 |
|---|---|
| raw な型引数 | `raw = Unit{true}`。WF・Sorted・Declared・value kind を満たす |
| 操作宣言 | 型引数を一つ持ち、equality を要求する。値引数はなく、結果は Unit |
| 制約の解釈 | `B.sat C a p := C = [] ∨ a.Normal` |
| 元の文脈 | `C = []`、`Γ = []`、空のストア、経路条件は空 |
| 元の値 | `.op "op" [raw]`。V_Op で元の型付けを構成する |
| 移動 | `k = 1`、`c = 0`、`C' = [{}]`、`Δ = []` |
| 移動後 | `Val.shiftEAt` は型引数に生の shiftTypes を適用するので raw のまま。C' は空でなく raw.Normal も偽であり、SatAll を満たせない |

Builtins.TypeAssumptions の sat_renameTypes と sat_subst の出力型は、いずれも定義上 norm を含む。したがって、この制約モデルは norm_idem により両欄を満たす。sig は全て none とし、admits の二つの欄は lookup の矛盾で満たす。TypeParamRenaming は空の元文脈からなので成立する。文脈長と TypeCtxMap も独立に証明する。主定理の前提を省いた例ではない。

型付けの convert は値に書かれた型引数を変えない。V_Sub で結論の型を変えても、V_Op が要求する SatAll は同じ raw の型引数である。LeQ.convert をさらに使ってこの失敗を回避することはできない。

## 原因となる補助補題

TypeShiftContracts の Ty.renameTypes_shift_of_wf は WF だけから norm の固定点を使っていた。正しい無条件の等号は `a.renameTypes (shiftIndex k c) = (shiftTypes k c a).norm` であり、生の shiftTypes との等号ではない。Unit{true} で旧等号を否定した。

Builtins.TypeAssumptions.sat_shiftTypes_raw、admits_shiftTypes_raw、SatAll.shiftTypes は、その生の等号に依存する。正規化した引数に対する契約だけでは生の型引数の制約を戻せない。これは Sorted/Declared の norm 保存とは別の問題である。後者と TypedFacts は今回閉じた。

同じ理由で、未使用だった sat_local/admits_local の生の結論も偽になる。この二つだけは結論を正規化する補助へ改め、旧言明を sat_local_raw_counterexample/admits_local_raw_counterexample で否定した。主定理の shift_types をこの変更だけで証明することはできない。

## 判断が必要な変更の候補

次の候補は実装していない。いずれも主定理の入力契約か、結論に含まれる項の変換の意味に触れるためである。

| 候補 | 必要となる変更 | 検討点 |
|---|---|---|
| 制約解釈を正規化に対して不変とする | sat と admits が norm の前後で同値となる条件を信頼契約へ追加するか、生の型改名の保存条件を既存の条件と併記する | Builtins.TypeAssumptions の前提を強める。既存の組込みモデルの全てが満たすことの確認が要る |
| 項の型移動も正規化する | Val.shiftEAt と計算・節・局所文脈の型移動の定義を変更し、実際の型引数を norm 後の形にする | 主定理の結論に現れる変換の意味が変わる。移動の恒等性・合成と、構文に依存する実行の契約を併せて見直す必要がある |

型引数を Normal に限定して拒否する変更は提案しない。利用者の書ける形を狭めるためである。正規化前後の値を無条件に同じとする新規の型付け規則も、組込みの実行や操作の引数型の契約を検査せずには追加しない。

今回の依頼の「この案が別の Lean の反例で成り立たないと分かったら、その反例を Lean で示して、ビルドが通らないままでよいので報告する」と、主な定理の前提と結論に触れる場合の停止条件を適用する。差分を戻さず、主定理を撤回せず、失敗したビルドを記録した。L00b.11 の残りを L00b.13 や L40 に送って完了としない。
