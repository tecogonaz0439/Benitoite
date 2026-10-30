| 種類 g | 段 | 候補 | 最小版の対応済み | N_g | 必要な補題・条件 |
|---|---|---:|---:|---:|---|
| 型・行・範囲の WF/有限支持/正規化/順序 (`foundation`) | L10 | 158 | 7 | 151 | L00b.02a/.11 の全sortと正規化、L00a の移動/置換の各場合 |
| 値の相互置換 subst (`subst`) | L20 | 7 | 0 | 7 | L00a.12a/.12b、SubstOk、型付き像→facts→cut、全腕/節の構成子 |
| 改名 rename (`rename`) | L20 | 7 | 0 | 7 | L00a.08 の shift と論理の rename、RenOk、facts/Φ/None と束縛の保存 |
| ストア拡張 store (`store`) | L20 | 9 | 0 | 9 | StoreTy.Sub、閉じた環境、LeQ/Covers が同じ Γ/Φ の下にあること |
| 継続位置の hide (`hide`) | L20 | 3 | 0 | 3 | hideConts、None、参照集合と sort、消える位置を述語が参照しない証拠 |
| NoFail 文脈の q_mono (`q_mono`) | L20 | 7 | 0 | 7 | QLe/Admissible の単調性。Γ/Φ は同じなので LeQ を再利用できる条件を確認 |
| 無関係な位置と subst_congr (`subst_congr`) | L20 | 7 | 0 | 7 | SubstAgree/LocalSubstAgree、述語・型・行の自由参照集合と置換合同 |
| 局所参照 localRefs (`localRefs`) | L20 | 9 | 0 | 9 | LocalRef.HasKind、全値/腕/節と CellOk/ContTy の局所参照、篩の観測制限 |
| builder の隠蔽と強化 (`hideBuilders`) | L20 | 5 | 0 | 5 | hideBuilders のストア包含、捕捉の禁止、値/列/節の強化 |
| 戻り先の withReturn (`withReturn`) | L20 | 4 | 0 | 4 | L00b の正常/return と閉じた契約、空ストア/R=None、束縛下の R/型/効果の移動 |
| 型・行・範囲の相互置換と交換 (`type_subst`) | L20 | 195 | 0 | 195 | L00a.09a/.09b/.10、全sortの bind/instR と正規化、L00b で追加した全構成子 |
| 文脈・閉じた値・名前等の補助 (`context_other`) | L20 | 114 | 0 | 114 | 前掲の rename/subst、ClosedTy、WF/sort/arity と facts の対応 |
| 継続 K_Sub・ストア/セルの葉 (`continuation`) | L20 | 27 | 0 | 27 | L00b.03/.14 の閉じた契約、LeQ の narrowing と全枠、固定 Eb/末尾 R |
| 部分型の構造別逆転・canonical forms (`inversion`) | L40 | 53 | 0 | 53 | L00b.11 の carrier の形と TelClosure、L20 の narrowing、L30 の論理。全非関数等号へ戻さない |
| 値・パターン・builder・δ の葉 (`value_leaves`) | L40 | 29 | 0 | 29 | L20 の置換、L30、ConstOK/表現可能性、F3/data変性/各不変位置と returned |
| 保持対象・σ・所属・Model の対象条件 (`targets`) | L50 | 36 | 0 | 36 | L40 の値所属、L00b の σ/保持要求、groundVal・reqTarget・端点一致。Model の対象外部分は L40/L60 と接続 |
| 表層 E_Sub/B_Sub・checker・脱糖・網羅性 (`surface`) | L70 | 242 | 0 | 242 | L20 の文脈補題、L40 の逆転、L50/L60 の葉、新 HasType/HasBlock と性質1/消去 |
| 保存・進行・効果/対象の主定理と例 (`main`) | L70 | 50 | 0 | 50 | L20〜L60 の全葉、StateTyE/Program.WellTyped、既定 import と全交換入口の切替 |
| 合計 | — | 962 | 7 | 955 | 候補の台帳。将来の新規定理数は含まない |
