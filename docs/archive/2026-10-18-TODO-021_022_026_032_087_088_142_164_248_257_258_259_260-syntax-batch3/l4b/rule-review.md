# L4b 規則ごとの帰納の照合

2026-10-18、Codex。FはfillBuilders Γ Δを表す。型判断の定義は開始版と同一であり、七判断の全78規則を確認した。入力のAligned Γ ΔとClean C.length Δを、通常束縛・hideConts・空Δの境界へ渡す。次の一覧は証明の読解記録であり、有限例による型保存の代用ではない。

| 判断 | 規則数 |
|---|---|
| HasTypeQ | 56 |
| HasTypesQ | 2 |
| HasEachQ | 2 |
| HasHoleArgsQ | 3 |
| HasArmsQ | 3 |
| HasClausesQ | 2 |
| HasBlockQ | 10 |

| 判断 | 規則 | 帰納の結論と組み立て |
|---|---|---|
| HasTypeQ | E_Local | 子の帰納なし。value_lookupで通常値の型をセル環境に保存する。 |
| HasTypeQ | E_Const | 本体の帰納はfillBuilders [] []。空環境から使用位置のFへ恒等移行する。 |
| HasTypeQ | E_Fun | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_FunDicts | 式の子の帰納なし。辞書列だけをhide Fへ移し、引数束縛の下でラムダを組み立てる。 |
| HasTypeQ | E_MethName | 式の子の帰納なし。対象辞書と固定辞書列をhide Fへ移してからメソッド値を組み立てる。 |
| HasTypeQ | E_Prim | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_Op | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_OpDicts | 式の子の帰納なし。op_value_typedのRenOkから辞書列をhide Fへ移し、ラムダを組み立てる。 |
| HasTypeQ | E_NullCon | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_ConValue | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_PipeCall | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_PipeConCall | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_PipeConValue | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_PipeApply | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_PartialCall | callee・固定引数の帰納は空Δ。calleeはhide Fへ、計算列は穴の束縛 ++ hide FへRenOk.up_idで移す。 |
| HasTypeQ | E_PartialCon | 固定引数の帰納は空Δ。穴の束縛 ++ hide Fへ計算列をRenOk.up_idで移す。 |
| HasTypeQ | E_Match | 対象はF、分岐はsome a :: Fを帰納の結論に持つ。 |
| HasTypeQ | E_Literal | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_NegInt | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_NegFloat | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_NegDecimal | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_NegInteger8 | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_NegInteger16 | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_NegInteger32 | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_NegFloat32 | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_Raise | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_HandleFail | 本体の帰納はF。節は空Δで帰納し、shiftE 1とup_id [none, some E↑]で移す。 |
| HasTypeQ | E_Unit | 式の子の帰納なし。宣言・注釈・コアの値規則からFで直接組み立てる。 |
| HasTypeQ | E_Paren | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Record | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_RecordUpdate | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_ConCall | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Call | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Binary | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Neg | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Not | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_And | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Or | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_List | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_ListSpread | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Interpolation | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Lam | 本体の帰納は空Δ。RenOk.hide/up_idでbinds ps ++ hide Fへ移す。 |
| HasTypeQ | E_If | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_ElseIf | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_IfOnly | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_ReturnTail | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_ReturnOther | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_TryResult | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_TryOption | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_TryResultDie | 対象はF、説明はfillBuilders (hide Γ) Δ。hideContsとの交換と表示辞書の恒等移行で組み立てる。 |
| HasTypeQ | E_TryOptionDie | 対象はF、説明はfillBuilders (hide Γ) Δ。hideContsとの交換で組み立てる。 |
| HasTypeQ | E_With | 値はF、本体はfillBuilders (some resource :: Γ) (none :: Δ)。under_valueでsome resource :: Fに一致する。 |
| HasTypeQ | E_Lazy | 本体の帰納は空Δ。RenOk.hideでhide Fへ移す。 |
| HasTypeQ | E_Handle | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypeQ | E_Resume | 引数の帰納はF。既存の継続のlookupもvalue_lookupでFへ移す。 |
| HasTypeQ | E_Sub | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasTypesQ | nil | 子の帰納なし。Fで空の列またはUnitを組み立てる。 |
| HasTypesQ | cons | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasEachQ | nil | 子の帰納なし。Fで空の列またはUnitを組み立てる。 |
| HasEachQ | cons | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasHoleArgsQ | nil | 子の帰納なし。Fで空の列またはUnitを組み立てる。 |
| HasHoleArgsQ | expr | 固定式はFの帰納から穴の束縛下へshiftする。残りの帰納は同じFと全穴の束縛を持つ。 |
| HasHoleArgsQ | hole | 残りの帰納は同じFと全穴の束縛を持つ。穴の変数をその束縛位置で型付けする。 |
| HasArmsQ | nil | 子の帰納なし。some a :: Fで空の分岐列を組み立てる。 |
| HasArmsQ | plain | 本体はfillBuilders (binds δ ++ Γ) (none^δ.length ++ Δ)、続きはsome a :: F。under_bindsとshiftAltsで結合する。 |
| HasArmsQ | guarded | ガードはfillBuilders (hide (binds δ ++ Γ)) (none^δ.length ++ Δ)、本体と続きはplainと同じ。hide交換・under_binds・shiftGuardで結合する。 |
| HasClausesQ | nil | 子の帰納なし。Fで空の節列を組み立てる。 |
| HasClausesQ | cons | 本体の帰納は空Δ。shiftE ntysとup_id (continuation :: binds params)で移す。節列の続きの帰納はF。 |
| HasBlockQ | B_LastPat | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasBlockQ | B_BindPat | 値はF、続きはfillBuilders (binds δ ++ Γ) (none^δ.length ++ Δ)。under_bindsで結合する。 |
| HasBlockQ | B_Empty | 子の帰納なし。Fで空の列またはUnitを組み立てる。 |
| HasBlockQ | B_Last | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasBlockQ | B_LastBind | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasBlockQ | B_LastDiscard | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |
| HasBlockQ | B_Bind | 値はF、続きはfillBuilders (some t :: Γ) (none :: Δ)。under_valueで結合する。 |
| HasBlockQ | B_Discard | 式と続きの帰納はF。コアだけの一つのletをshiftOneで挿入する。 |
| HasBlockQ | B_Seq | 式と続きの帰納はF。コアだけの一つのletをshiftOneで挿入する。 |
| HasBlockQ | B_Sub | 同じΔの全ての子の帰納はF（列はCompTypesQ）を結論し、コアの既存の規則で結合する。 |

## clean・scopedと関連補題

- cleanはHasTypeQ/HasBlockQの全規則の相互帰納である。結果型を注釈・宣言から得る規則は従来の根拠を保つ。同じΔの子にはClean Δ、通常束縛の子にはclean_valueまたはall_values、lazy本体にはclean_emptyを渡す。型保存の七判断は、この結果と必要な内部のAlignedを使う。AtomsIn/Singleの条件はこの三つの証明では不要である。
- scopedの七判断の全78規則は任意Δ・nt/pe/nvに対する相互帰納のままである。Comp.VarsIn/Arm.VarsInList/Clause.VarsInListは環境を引数に取らず、脱糖の関数と局所数は変わらない。セル環境への型保存に合わせて前提を強める必要はない。元の強い言明と各分岐の証明は保った。
- ShiftClean/SubstCleanは通常型・効果の型変数だけを扱い、開始版とバイト単位で同じである。型束縛のある節は空Δなので、fillBuildersと型のshift/代入の交換は不要である。既存のshift_clean/rawShiftEff_clean/substAt_cleanとその利用側を維持した。
- desugar_of_exprの式列・各要素・穴・ブロックの四補題も、preserveの仮定とその帰納の結論の両方をFへ変更した。BlockSequenceは従来の独立したブロックの帰納を保つ。
- 新規のup_id・aligned_binds・under_binds・HasTypeCQ.renameId・CompTypesQ.renameIdの使用箇所と理由はdecisions.mdのR149に記録した。直接の頭・補間・操作の値化・dieの表示辞書は、表層ΓとコアΓcの恒等のRenOkに一般化した。辞書だけを移し、子の帰納の結論を通常Γへ戻さない。

## 関門の照合

K契約/K接続: Surface/Typing.leanとDesugar.leanを変更せず、局所番号・評価順・型・効果・失敗の契約を維持した。K形式化: 主定理とその前提の定義を変更せず、型保存の帰納で直接F上の導出を構築した。型検査による後付けの証拠には置き換えていない。K文書: 01-12と07-04にこの段階の規則と保証を写し、専用構文・捕捉禁止・検査器の四条件・Rust未接続を明示した。K安全点/K性能/K境界: ランタイム、GC、性能計測、Scope/Rangeの契約は作業対象に含まない。
