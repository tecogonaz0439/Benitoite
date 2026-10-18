import Benitoite.Surface.Lemmas.Patterns
import Benitoite.Surface.Lemmas.Calls
import Benitoite.Release.Lemmas.Dict

/-! レコードの取得・更新と構成子の網羅性（設計書 01-12「レコード」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

theorem desugarExprs_length (op : OpPrim) : (es : Exprs) →
    (desugarExprs op es).length = es.length
  | .nil => rfl
  | .cons _ es => by simp only [desugarExprs, List.length_cons, Exprs.length, desugarExprs_length op es]

variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

/-- 生成する関数の型引数・戻り値・本体は構成子の宣言の範囲内。 -/
theorem accessorDef_scoped {c cd k} (sc : cd.Scoped) (hk : k < cd.args.length) :
    (accessorDef c cd k).Scoped := by
  simp only [accessorDef, accessorDecl, Release.Def.Scoped, Release.Def.ntys, List.length_replicate,
    Comp.VarsIn, mkArm, Arm.VarsInList, Val.VarsIn, List.getElem?_eq_getElem hk, Option.getD_some]
  refine ⟨by simp [NamesWF], ⟨?_, trivial⟩, ?_, ?_, trivial, trivial, trivial⟩
  · exact Ty.varsInList_of_forall (by
      intro t ht
      obtain ⟨i, hi, rfl⟩ := List.mem_map.mp ht
      exact List.mem_range.mp hi)
  · exact Ty.VarsIn.mono (Nat.le_refl _) (by intro i hi; exact False.elim hi) _
      (varsInList_mem sc (List.getElem_mem hk))
  · exact ⟨fun _ h => Bool.noConfusion h, trivial⟩

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

-- getter はソースのパターンでなく、現在の構成子だけを扱う合成照合である。
-- view 付き条件を要求せず、閉じたコアの Exhaustive を示す（設計書 01-12「型の情報を付けた表層の構文と型付け」）。
theorem accessorPattern_exhaustive {P : Release.Program} {c cd ts k}
    (hc : P.cons c = some cd)
    (unique : ∀ c' cd', P.cons c' = some cd' → cd'.data = cd.data → c' = c) :
    Exhaustive P (.data cd.data ts) [accessorPattern c cd.args.length k] := by
  apply singleConstructor_exhaustive hc unique (by simp)
  intro p hp
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hp
  split <;> simp


/-- 宣言自身の型変数で具体化すると、レコードのフィールド型は変わらない。 -/
theorem record_subst_identity (n : Nat) (t : Ty) (h : Ty.VarsIn n (fun _ => False) t) :
    t.subst ((List.range n).map Ty.tvar) [] = t := by
  rw [Ty.subst, Ty.substAt_eq_bind]
  have he : Ty.bind (SubstEnv.at 0 ((List.range n).map Ty.tvar) []) t =
      Ty.bind SubstEnv.identity t := by
    apply Ty.bind_congr_scoped (n := n)
    · intro i hi
      simp [SubstEnv.at, SubstEnv.identity, hi, Ty.rawShift, Ty.norm]
    · exact (Ty.VarsIn.wf t h).raw t
    · exact Ty.RowsIn.mono (fun _ _ => rfl) t (Ty.VarsIn.rows t h)
  rw [he, Ty.bind_identity, (Ty.VarsIn.wf t h).canonical t]

theorem record_substList_identity (n : Nat) (ts : List Ty)
    (h : Ty.VarsInList n (fun _ => False) ts) :
    ts.map (Ty.subst ((List.range n).map Ty.tvar) []) = ts := by
  calc
    _ = ts.map id := List.map_congr_left (fun t ht =>
      record_subst_identity n t (Ty.VarsInList.iff.mp h t ht))
    _ = _ := List.map_id ts


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
  refine ⟨by simp [accessorDef, accessorDecl, NamesWF], ?_⟩
  apply HasTypeCQ.C_Match (.V_Var rfl (by intro _ _ _ he; cases he))
  · exact HasTypeArmsQ.mkArm_cons hp (.C_Return (.V_Var rfl (clean_notCont ha)))
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
    (h : HasTypeVsQ P B StoreTy.empty Q C Γ vs
      (positions.map fun i => (tys[i]?).getD (.base .unit)))
    (hclean : Ty.VarsInList C.length (fun _ => True) tys)
    (hp : PatTy P (recordUpdatePattern c n positions) (.data d ts)
      (retainedTypes (List.range n) positions (fun i => (tys[i]?).getD (.base .unit)))) :
    HasTypeVsQ P B StoreTy.empty Q C
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
            apply HasTypeVQ.V_Var (retained_get_range t hil him Γ)
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
