import Benitoite.Surface.Lemmas.Patterns
import Benitoite.Release.Lemmas.Dict

/-! レコードの位置の並べ替え、平らなパターンの網羅性と生成する定義。 -/
namespace Benitoite.Surface
open Benitoite.Release

/-- fieldAt は入力の値の性質を保つ。位置が重複した入力でも成り立つ。 -/
theorem fieldAt_property {α : Type} (Q : α → Prop) {i positions values v}
    (h : ∀ w ∈ values, Q w) (hv : fieldAt i positions values = some v) : Q v := by
  induction positions generalizing values with
  | nil => simp [fieldAt] at hv
  | cons j js ih =>
      cases values with
      | nil => simp [fieldAt] at hv
      | cons w ws =>
          by_cases he : i = j
          · simp [fieldAt, he] at hv; subst v; exact h w (by simp)
          · exact ih (values := ws) (fun x hx => h x (by simp [hx])) (by simpa [fieldAt, he] using hv)

theorem valVarsInList_mem {nt pe vs v} (h : Val.VarsInList nt pe vs) (hv : v ∈ vs) :
    Val.VarsIn nt pe v := by
  induction vs with
  | nil => cases hv
  | cons w ws ih =>
      rcases List.mem_cons.mp hv with rfl | hv
      · exact h.1
      · exact ih h.2 hv

theorem valVarsInList_of_forall {nt pe vs} (h : ∀ v ∈ vs, Val.VarsIn nt pe v) :
    Val.VarsInList nt pe vs := by
  induction vs with
  | nil => trivial
  | cons w ws ih => exact ⟨h w (by simp), ih (fun v hv => h v (by simp [hv]))⟩

theorem recordFields_scoped {nt pe n positions vs fallback}
    (h : Val.VarsInList nt pe vs) (hf : Val.VarsIn nt pe fallback) :
    Val.VarsInList nt pe (recordFields n positions vs fallback) := by
  apply valVarsInList_of_forall
  intro v hv
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hv
  cases he : fieldAt i positions vs with
  | none => exact hf
  | some v => exact fieldAt_property (Val.VarsIn nt pe) (fun w hw => valVarsInList_mem h hw) he

theorem recordUpdateValues_scoped {nt pe c n positions vs}
    (h : Val.VarsInList nt pe vs) :
    Val.VarsInList nt pe (recordUpdateValues c n positions vs) := by
  apply valVarsInList_of_forall
  intro v hv
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hv
  cases he : fieldAt i positions vs with
  | none => trivial
  | some v =>
      exact Val.VarsIn.renameScoped _ _ (fieldAt_property (Val.VarsIn nt pe) (fun w hw => valVarsInList_mem h hw) he)

theorem desugarExprs_length (op : OpPrim) : (es : Exprs) →
    (desugarExprs op es).length = es.length
  | .nil => rfl
  | .cons _ es => by simp only [desugarExprs, List.length_cons, Exprs.length, desugarExprs_length op es]

variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

/-- 書いた位置に対応する値が、その位置の宣言型を持つ。 -/
theorem fieldAt_typed {positions : List Nat} {vs : List Val} {tys : List Ty} {i : Nat}
    (h : HasTypeVs P B StoreTy.empty C Γ vs
      (positions.map fun j => (tys[j]?).getD (.base .unit))) (hi : i ∈ positions) :
    ∃ v, fieldAt i positions vs = some v ∧
      HasTypeV P B StoreTy.empty C Γ v ((tys[i]?).getD (.base .unit)) := by
  induction positions generalizing vs with
  | nil => cases hi
  | cons j js ih =>
      cases h with
      | cons hv hvs =>
          by_cases he : i = j
          · subst i; exact ⟨_, by simp [fieldAt], hv⟩
          · obtain ⟨w, hw, ht⟩ := ih hvs ((List.mem_cons.mp hi).resolve_left he)
            exact ⟨w, by simp [fieldAt, he, hw], ht⟩

/-- 同じ位置列で作った値の列と型の列の点ごとの対応。 -/
theorem valueMaps_typed (indices : List Nat) (v : Nat → Val) (t : Nat → Ty)
    (h : ∀ i ∈ indices, HasTypeV P B StoreTy.empty C Γ (v i) (t i)) :
    HasTypeVs P B StoreTy.empty C Γ (indices.map v) (indices.map t) := by
  induction indices with
  | nil => exact .nil
  | cons i is ih => exact .cons (h i (by simp)) (ih (fun j hj => h j (by simp [hj])))

theorem map_range_getD {α : Type} (xs : List α) (fallback : α) :
    (List.range xs.length).map (fun i => (xs[i]?).getD fallback) = xs := by
  apply List.ext_getElem
  · simp
  · intro i hi hi'
    simp only [List.getElem_map, List.getElem_range, List.getElem?_eq_getElem hi', Option.getD_some]

theorem recordFields_typed {positions vs tys}
    (hp : positions.Perm (List.range tys.length))
    (h : HasTypeVs P B StoreTy.empty C Γ vs
      (positions.map fun j => (tys[j]?).getD (.base .unit))) :
    HasTypeVs P B StoreTy.empty C Γ
      (recordFields positions.length positions vs (.const .unit)) tys := by
  have hl := hp.length_eq
  rw [List.length_range] at hl
  unfold recordFields
  rw [hl]
  have hm := valueMaps_typed (P := P) (B := B) (C := C) (Γ := Γ) (List.range tys.length)
    (fun i => (fieldAt i positions vs).getD (.const .unit))
    (fun i => (tys[i]?).getD (.base .unit)) (by
      intro i hi
      obtain ⟨v, hv, ht⟩ := fieldAt_typed h (hp.mem_iff.mpr hi)
      simpa only [hv, Option.getD_some] using ht)
  simpa only [map_range_getD] using hm

/-- 生成する関数の型引数・戻り値・本体は構成子の宣言の範囲内。 -/
theorem accessorDef_scoped {c cd k} (sc : cd.Scoped) (hk : k < cd.args.length) :
    (accessorDef c cd k).Scoped := by
  simp only [accessorDef, accessorDecl, Release.Def.Scoped, Release.Def.ntys, List.length_replicate,
    Comp.VarsIn, mkArm, Arm.VarsInList, Val.VarsIn, List.getElem?_eq_getElem hk, Option.getD_some]
  refine ⟨⟨?_, trivial⟩, ?_, ?_, trivial, trivial, trivial⟩
  · exact Ty.varsInList_of_forall (by
      intro t ht
      obtain ⟨i, hi, rfl⟩ := List.mem_map.mp ht
      exact List.mem_range.mp hi)
  · exact Ty.VarsIn.mono (Nat.le_refl _) (by intro i hi; exact False.elim hi) _
      (varsInList_mem sc (List.getElem_mem hk))
  · intro i hi; simp [Eff.empty] at hi

theorem InhabitsAll.length {P as vs} (h : InhabitsAll P as vs) : as.length = vs.length := by
  match h with
  | .nil => rfl
  | .cons _ hs => exact congrArg Nat.succ (InhabitsAll.length hs)

/-- wild と var だけの引数列は、同じ個数のどの値列にも照合する。 -/
theorem flatPattern_match {ps : List Release.Pat} {vs : List Val}
    (h : ∀ p ∈ ps, p = .wild ∨ p = .var) (hl : ps.length = vs.length) :
    ∃ ws, Release.Pat.matchList ps vs = some ws := by
  induction ps generalizing vs with
  | nil => cases vs <;> simp_all [Release.Pat.matchList]
  | cons p ps ih =>
      cases vs with
      | nil => simp at hl
      | cons v vs =>
          obtain ⟨ws, hs⟩ := ih (fun q hq => h q (by simp [hq])) (by simpa using hl)
          rcases h p (by simp) with rfl | rfl
          · exact ⟨ws, by simp [Release.Pat.matchList, Release.Pat.matchVal, hs]⟩
          · exact ⟨v :: ws, by simp [Release.Pat.matchList, Release.Pat.matchVal, hs]⟩

/-- 単一構成子のデータ型では、wild/var の一分岐が網羅する。
構築された値は Inhabits の構成子宣言により全フィールドを持つ。 -/
theorem singleConstructor_exhaustive {P : Release.Program} {c cd ts ps}
    (hc : P.cons c = some cd)
    (unique : ∀ c' cd', P.cons c' = some cd' → cd'.data = cd.data → c' = c)
    (hl : ps.length = cd.args.length)
    (hp : ∀ p ∈ ps, p = .wild ∨ p = .var) :
    Exhaustive P (.data cd.data ts) [.con c ps] := by
  intro v hv
  generalize he : Ty.data cd.data ts = t at hv
  cases hv with
  | @const cn => cases cn <;> cases he
  | @con c' ts' _ args cd' hc' _ hargs =>
      have hdata : cd'.data = cd.data := (Ty.data.inj he).1.symm
      have he := unique c' cd' hc' hdata
      subst c'
      have hd := Option.some.inj (hc'.symm.trans hc)
      subst cd'
      obtain ⟨ws, hws⟩ := flatPattern_match (vs := args) hp (by simpa [hl] using InhabitsAll.length hargs)
      exact ⟨.con c ps, by simp, by simp [Release.Pat.matchVal, hws]⟩
  | _ => cases he

theorem recordUpdatePattern_exhaustive {P : Release.Program} {c cd ts positions}
    (hc : P.cons c = some cd)
    (unique : ∀ c' cd', P.cons c' = some cd' → cd'.data = cd.data → c' = c) :
    Exhaustive P (.data cd.data ts) [recordUpdatePattern c cd.args.length positions] := by
  apply singleConstructor_exhaustive hc unique (by simp)
  intro p hp
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hp
  split <;> simp

theorem accessorPattern_exhaustive {P : Release.Program} {c cd ts k}
    (hc : P.cons c = some cd)
    (unique : ∀ c' cd', P.cons c' = some cd' → cd'.data = cd.data → c' = c) :
    Exhaustive P (.data cd.data ts) [accessorPattern c cd.args.length k] := by
  apply singleConstructor_exhaustive hc unique (by simp)
  intro p hp
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hp
  split <;> simp


mutual
  /-- 宣言自身の型変数で具体化すると、レコードのフィールド型は変わらない。 -/
  theorem record_subst_identity (n : Nat) : (t : Ty) → Ty.VarsIn n (fun _ => False) t →
      t.subst ((List.range n).map Ty.tvar) [] = t
    | .base _, _ => by simp only [Ty.subst, Ty.substAt]
    | .opaque _, _ => by simp only [Ty.subst, Ty.substAt]
    | .data d as, h => by
        simpa only [Ty.subst, Ty.substAt] using congrArg (Ty.data d) (record_substList_identity n as h)
    | .list a, h => by
        simpa only [Ty.subst, Ty.substAt] using congrArg Ty.list (record_subst_identity n a h)
    | .fn ps r e, h => by
        simp only [Ty.subst, Ty.substAt, Eff.substRho_nil]
        congr 1
        · simpa only [Ty.subst] using record_substList_identity n ps h.1
        · simpa only [Ty.subst] using record_subst_identity n r h.2.1
    | .tvar i, h => by
        change i < n at h
        simp [Ty.subst, Ty.substAt, h, Ty.shift]
    | .reference a, h => by
        simpa only [Ty.subst, Ty.substAt] using congrArg Ty.reference (record_subst_identity n a h)
    | .lazy a, h => by
        simpa only [Ty.subst, Ty.substAt] using congrArg Ty.lazy (record_subst_identity n a h)
    | .cont _ _ _, h => False.elim h
    | .map a b, h => by
        simp only [Ty.subst, Ty.substAt]
        congr 1
        · simpa only [Ty.subst] using record_subst_identity n a h.1
        · simpa only [Ty.subst] using record_subst_identity n b h.2
    | .set a, h => by
        simpa only [Ty.subst, Ty.substAt] using congrArg Ty.set (record_subst_identity n a h)
    | .bytes, _ => by simp only [Ty.subst, Ty.substAt]
    | .dict cl a, h => by
        simpa only [Ty.subst, Ty.substAt] using congrArg (Ty.dict cl) (record_subst_identity n a h)
    | .tapp i as, h => by
        have hi := h.1
        simp only [Ty.subst, Ty.substAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero,
          List.length_map, List.length_range, List.getElem?_map, List.getElem?_range, hi,
          ↓reduceIte, Option.map_some, Option.getD_some, Ty.shift_zero, Ty.applyTo]
        exact congrArg (Ty.tapp i) (record_substList_identity n as h.2)
    | .ctor _, _ => by simp only [Ty.subst, Ty.substAt]

  theorem record_substList_identity (n : Nat) : (ts : List Ty) → Ty.VarsInList n (fun _ => False) ts →
      ts.map (Ty.subst ((List.range n).map Ty.tvar) []) = ts
    | [], _ => rfl
    | t :: ts, h => by
        simp only [List.map_cons, record_subst_identity n t h.1, record_substList_identity n ts h.2]
end

theorem wilds_typed (P : Release.Program) (as : List Ty) :
    PatTys P (as.map fun _ => .wild) as [] := by
  induction as with
  | nil => exact .nil
  | cons a as ih => exact .cons .P_Wild ih

/-- 平らな取得パターンは、一つだけフィールドの型を束縛する。 -/
theorem accessorArgs_typed (P : Release.Program) (as : List Ty) (k : Nat) (hk : k < as.length) :
    PatTys P ((List.range as.length).map fun i => if i = k then .var else .wild) as
      [(as[k]?).getD (.base .unit)] := by
  induction as generalizing k with
  | nil => simp at hk
  | cons a as ih =>
      cases k with
      | zero =>
          simp only [List.length_cons, List.range_succ_eq_map, List.map_cons, List.map_map, Function.comp_def,
            Nat.succ_ne_zero, ↓reduceIte, List.getElem?_cons_zero, Option.getD_some]
          have he : (List.range as.length).map (fun _ => Release.Pat.wild) = as.map (fun _ => .wild) := by
            simp only [List.map_const', List.length_range]
          rw [he]
          exact .cons .P_Var (wilds_typed P as)
      | succ k =>
          simp only [List.length_cons, List.range_succ_eq_map, List.map_cons, List.map_map, Function.comp_def,
            Nat.zero_ne_add_one, ↓reduceIte, Nat.succ.injEq, List.getElem?_cons_succ]
          exact .cons .P_Wild (ih k (by simpa using hk))

/-- 単一構成子の条件から網羅性を導き、生成する取得関数の定義全体に型を付ける。 -/
theorem accessorDef_typed {P : Release.Program} {B : Builtins} {c cd k}
    (hc : P.cons c = some cd) (sc : cd.Scoped) (hk : k < cd.args.length)
    (unique : ∀ c' cd', P.cons c' = some cd' → cd'.data = cd.data → c' = c) :
    (accessorDef c cd k).WellTyped P B := by
  let ts := (List.range cd.ntys).map Ty.tvar
  let a := (cd.args[k]?).getD (.base .unit)
  have ha : TyOK cd.ntys a := by
    simp only [a, List.getElem?_eq_getElem hk, Option.getD_some]
    exact scoped_clean (varsInList_mem sc (List.getElem_mem hk))
  have hp : PatTy P (accessorPattern c cd.args.length k) (.data cd.data ts) [a] := by
    apply PatTy.P_Con hc (by simp [ts])
    rw [record_substList_identity cd.ntys cd.args sc]
    exact accessorArgs_typed P cd.args k hk
  apply HasTypeC.C_Match (.V_Var rfl (by intro _ _ _ he; cases he))
  · exact HasTypeArms.mkArm_cons hp (.C_Return (.V_Var rfl (clean_notCont ha)))
      (.nil (by simpa [accessorDef, accessorDecl, List.length_replicate] using Ty.VarsIn.wf _ ha))
  · simpa only [unguardedPats_mkArm_cons, unguardedPats] using accessorPattern_exhaustive hc unique


/-- 更新で残すフィールドの型を、宣言の順に集める。 -/
def retainedTypes (indices positions : List Nat) (t : Nat → Ty) : List Ty :=
  (indices.filter (fun i => i ∉ positions)).map t

theorem updateArgs_typed (P : Release.Program) (indices positions : List Nat) (t : Nat → Ty) :
    PatTys P (indices.map fun i => if i ∈ positions then .wild else .var)
      (indices.map t) (retainedTypes indices positions t) := by
  induction indices with
  | nil => exact .nil
  | cons i is ih =>
      by_cases hi : i ∈ positions
      · simpa [retainedTypes, hi] using PatTys.cons PatTy.P_Wild ih
      · simpa [retainedTypes, hi] using PatTys.cons PatTy.P_Var ih

/-- i より後に残す束縛の個数が、i の de Bruijn 番号である。 -/
theorem retained_get (pre post positions : List Nat) (t : Nat → Ty) (i : Nat)
    (hi : i ∉ positions) (Δ : List (Option Ty)) :
    (binds (retainedTypes (pre ++ i :: post) positions t) ++ Δ)[(post.filter (fun j => j ∉ positions)).length]? = some (some (t i)) := by
  have hf : (i :: post).filter (fun j => j ∉ positions) =
      i :: post.filter (fun j => j ∉ positions) :=
    List.filter_cons_of_pos (by simpa using hi)
  simp only [retainedTypes, List.filter_append, hf,
    List.map_append, List.map_cons, binds_append, binds_cons, List.append_assoc]
  rw [List.getElem?_append_right (by simp [binds_length])]
  simp [binds_length]

theorem retained_get_range {n i positions} (t : Nat → Ty) (hi : i < n)
    (hn : i ∉ positions) (Δ : List (Option Ty)) :
    (binds (retainedTypes (List.range n) positions t) ++ Δ)[(((List.range n).drop (i + 1)).filter (fun j => j ∉ positions)).length]? =
      some (some (t i)) := by
  have hi' : i < (List.range n).length := by simpa using hi
  have hs : List.range n = (List.range n).take i ++ i :: (List.range n).drop (i + 1) := by
    calc
      List.range n = (List.range n).take i ++ (List.range n).drop i :=
        (List.take_append_drop i (List.range n)).symm
      _ = _ := by rw [← List.getElem_cons_drop hi', List.getElem_range]
  have h := retained_get ((List.range n).take i) ((List.range n).drop (i + 1)) positions t i hn Δ
  rw [← hs] at h
  exact h

/-- 検索が成功した位置は、書いた位置の列に含まれる。 -/
theorem fieldAt_mem {α : Type} {i positions vs} {v : α}
    (he : fieldAt i positions vs = some v) : i ∈ positions := by
  induction positions generalizing vs with
  | nil => simp [fieldAt] at he
  | cons j js ih =>
      cases vs with
      | nil => simp [fieldAt] at he
      | cons w ws =>
          by_cases hij : i = j
          · simp [hij]
          · exact List.mem_cons_of_mem j (ih (by simpa [fieldAt, hij] using he))

/-- 書いた値は束縛の下へずらし、残す値はパターンの環境から取り出す。 -/
theorem recordUpdateValues_typed {P : Release.Program} {B : Builtins} {C Γ c n positions vs tys}
    (hn : n = tys.length)
    (h : HasTypeVs P B StoreTy.empty C Γ vs
      (positions.map fun i => (tys[i]?).getD (.base .unit)))
    (hclean : Ty.VarsInList C.length (fun _ => True) tys)
    (hp : PatTy P (recordUpdatePattern c n positions) (.data d ts)
      (retainedTypes (List.range n) positions (fun i => (tys[i]?).getD (.base .unit)))) :
    HasTypeVs P B StoreTy.empty C
      (binds (retainedTypes (List.range n) positions (fun i => (tys[i]?).getD (.base .unit))) ++ Γ)
      (recordUpdateValues c n positions vs) tys := by
  let t : Nat → Ty := fun i => (tys[i]?).getD (.base .unit)
  let δ := retainedTypes (List.range n) positions t
  have hm := valueMaps_typed (P := P) (B := B) (C := C) (Γ := binds δ ++ Γ) (List.range n)
    (fun i => match fieldAt i positions vs with
      | some v => v.rename (· + (recordUpdatePattern c n positions).binders)
      | none => .var ((((List.range n).drop (i + 1)).filter (fun j => j ∉ positions)).length)) t (by
        intro i hi
        have hil : i < n := List.mem_range.mp hi
        cases he : fieldAt i positions vs with
        | some v =>
            have him := fieldAt_mem he
            obtain ⟨w, hw, ht⟩ := fieldAt_typed h him
            have hv : w = v := Option.some.inj (hw.symm.trans he)
            subst w
            have hh := ht.rename (RenOk.shift (binds δ) Γ)
            have hl : δ.length = (recordUpdatePattern c n positions).binders := hp.length_eq
            simpa only [binds_length, hl] using hh
        | none =>
            have him : i ∉ positions := by
              intro him
              obtain ⟨v, hv, _⟩ := fieldAt_typed h him
              rw [he] at hv; cases hv
            apply HasTypeV.V_Var (retained_get_range t hil him Γ)
            have hi' : i < tys.length := by omega
            apply clean_notCont
            simp only [t, List.getElem?_eq_getElem hi', Option.getD_some]
            exact varsInList_mem hclean (List.getElem_mem hi'))
  have hv : recordUpdateValues c n positions vs =
      (List.range n).map (fun i => match fieldAt i positions vs with
        | some v => v.rename (· + (recordUpdatePattern c n positions).binders)
        | none => .var ((((List.range n).drop (i + 1)).filter (fun j => j ∉ positions)).length)) := by
    unfold recordUpdateValues
    apply congrArg (fun f => (List.range n).map f)
    funext i
    cases fieldAt i positions vs <;> rfl
  rw [hv]
  simpa only [δ, t, hn, map_range_getD] using hm

end Benitoite.Surface
