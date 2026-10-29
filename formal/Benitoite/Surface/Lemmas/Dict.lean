import Benitoite.Surface.Lemmas.CallHead

/-! 操作へ渡す辞書と節の局所束縛の対応（設計書 01-12「型クラス」「ハンドラ」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

/-- 操作は行引数を持たず、辞書を値引数の前へ渡す。 -/
theorem op_dicts_typed {p : Program} {B op Q C Γ R o od ts ds ws}
    (hd : p.declarations.ops o = some od) (hn : NamesWF od.names od.params)
    (ht : SatAll B C ts od.tparams) (hp : od.params = od.dictTys ++ od.valueParams)
    (hds : DictEv.HasTypes p.declarations B C Γ ds (od.dictTys.map (Ty.subst ts [])))
    (hws : HasTypeVsQ (desugarProgram op p) B StoreTy.empty Q C Γ ws
      (od.valueParams.map (Ty.subst ts []))) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R
      (.app (.op o ts) (DictEv.toValList ds ++ ws)) (od.ret.subst ts []) (Eff.single od.eff) := by
  have hv := HasTypeVQ.V_Op (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty)
    (Q := Q) (Γ := Γ) hd hn ht
  rw [fnTy_eq, hp, List.map_append] at hv
  have he : Eff.substAt 0 ts [] (Eff.single od.eff) = Eff.single od.eff :=
    Eff.substAt_ofAtoms 0 [] _
  rw [he] at hv
  exact .C_App hv ((DictEv.HasTypes.toVal op hds).append hws)

/-- 操作の値化は辞書を捕える。作成は純粋で、操作の効果はラムダの呼び出しに残る。 -/
theorem op_value_typed {p : Program} {B op Q view C Γ Γc o od ts ds ps}
    (hd : (p.declarationsFor view).ops o = some od)
    (hcore : NamesWF od.names od.params) (hn : NamesWF od.valueNames ps)
    (ht : SatAll B C ts od.tparams) (hpref : od.params = od.dictTys ++ od.valueParams)
    (hnames : od.names = internalNames ds.length ++ od.valueNames)
    (hp : ps = od.valueParams.map (Ty.subst ts []))
    (hds : DictEv.HasTypes (p.declarationsFor view) B C Γ ds (od.dictTys.map (Ty.subst ts [])))
    (hΓc : RenOk Γ Γc id)
    (hc : Ty.VarsInList 0 C.length (fun _ => True) ps)
    (hw : Ty.WF 0 C.length (.fn od.valueNames ps (od.ret.subst ts []) (Eff.single od.eff))) :
    HasTypeVQ (desugarProgram op p) B StoreTy.empty Q C Γc
      (.lam od.valueNames ps (.app (.op o ts)
        (Val.renameList (· + ps.length) (DictEv.toValList ds) ++ boundVars ps.length)))
      (.fn od.valueNames ps (od.ret.subst ts []) (Eff.single od.eff)) := by
  have hv := (DictEv.HasTypes.toVal (Q := Q) op (DictEv.HasTypes.hide hds)).rename hΓc.hide
  simp only [Val.renameList_id] at hv
  have hs := hv.rename (RenOk.shift (binds ps) (hideConts Γc))
  have he : Eff.substAt 0 ts [] (Eff.single od.eff) = Eff.single od.eff :=
    Eff.substAt_ofAtoms 0 [] _
  apply HasTypeVQ.V_Lam hn hw
  change HasTypeCQ _ _ StoreTy.empty _ _ _ _ _ _ _
  apply HasTypeCQ.C_App
  · simpa only [fnTy_eq, hpref, hnames, List.map_append, hp, he] using
      (HasTypeVQ.V_Op (P := desugarProgram op p) (B := B)
        (Ψ := StoreTy.empty) (Q := Q) (Γ := binds ps ++ hideConts Γc) hd hcore ht)
  · simpa only [binds_length, hp] using hs.append (boundVars_typed hc)

/-- 宣言順の辞書は、継続・値引数の後の逆順の束縛へ写る。 -/
theorem clause_dict_scope {D B C Γ ds ps cl τ i k n}
    (hi : ds[i]? = some (.dict cl τ)) :
    DictEv.HasType D B C
      (some k :: (binds (ds ++ ps) ++ shiftEnv n Γ))
      (.clause ⟨Γ.length, ps.length, ds.length⟩ i) (.dict cl τ) := by
  have he : binds (ds ++ ps) ++ shiftEnv n Γ = binds ps ++ binds ds ++ shiftEnv n Γ := by
    simp [binds, List.reverse_append, List.map_append, List.append_assoc]
  rw [he]
  have hlt : i < ds.length := (List.getElem?_eq_some_iff.mp hi).1
  apply DictEv.HasType.clause hlt
  · simp only [List.length_cons, List.length_append, binds_length, shiftEnv_length]
    dsimp
    omega
  · change (some k :: (binds ps ++ binds ds ++ shiftEnv n Γ))[
      0 + (1 + ps.length + (ds.length - 1 - i))]? = _
    rw [show 0 + (1 + ps.length + (ds.length - 1 - i)) =
      (ps.length + (ds.length - 1 - i)) + 1 by omega]
    rw [List.getElem?_cons_succ]
    rw [List.getElem?_append_left (by simp [binds_length]; omega)]
    rw [List.getElem?_append_right (by simp [binds_length])]
    simp only [binds_length, Nat.add_sub_cancel_left]
    simp only [binds, List.getElem?_map]
    rw [List.getElem?_reverse (by omega)]
    have he : ds.length - 1 - (ds.length - 1 - i) = i := by omega
    rw [he, hi]
    rfl

/-- E-Op の代入も、宣言順の辞書を同じ値へ写す。未使用の辞書も列に残す。 -/
theorem clause_dict_instantiate {ds vs : List Val} {i : Nat} {w : Val} (κ : Nat)
    (hi : ds[i]? = some w) :
    Val.instantiate ((ds ++ vs) ++ [Val.loc κ])
      (.var (1 + vs.length + (ds.length - 1 - i))) = w := by
  have hlt : i < ds.length := (List.getElem?_eq_some_iff.mp hi).1
  have hj : 1 + vs.length + (ds.length - 1 - i) < ((ds ++ vs) ++ [Val.loc κ]).length := by
    simp; omega
  simp only [Val.instantiate, Val.subst, instSubst, hj, ↓reduceIte]
  rw [List.getElem?_reverse hj]
  have he : ((ds ++ vs) ++ [Val.loc κ]).length - 1 -
      (1 + vs.length + (ds.length - 1 - i)) = i := by simp; omega
  rw [he, List.getElem?_append_left (by simp; omega), List.getElem?_append_left hlt, hi]
  rfl

/-- 継続の番号は辞書数や値引数数によらず 0 である。 -/
theorem clause_cont_instantiate (ds vs : List Val) (κ : Nat) :
    Val.instantiate ((ds ++ vs) ++ [Val.loc κ]) (.var 0) = .loc κ := by
  simp [Val.instantiate, Val.subst, instSubst, List.reverse_append]

/-- 外側の環境の番号は、節の辞書・値・継続の束縛を取り除いて戻す。 -/
theorem clause_outer_instantiate (ds vs : List Val) (κ : Nat) (j : Nat) :
    Val.instantiate ((ds ++ vs) ++ [Val.loc κ])
      (.var (1 + ds.length + vs.length + j)) = .var j := by
  simp only [Val.instantiate, Val.subst, instSubst]
  have hle : ¬ 1 + ds.length + vs.length + j < ((ds ++ vs) ++ [Val.loc κ]).length := by simp; omega
  simp only [hle, ↓reduceIte]
  congr 1
  simp; omega

end Benitoite.Surface
