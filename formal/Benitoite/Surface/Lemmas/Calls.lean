import Benitoite.Surface.Lemmas.ScopedSupport

/-! 呼び出しの契約とソース順の束縛の型保存（設計書 01-12「呼び出し」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}


/-- 頭の型付けは、辞書を除いた値引数と呼び出しの結果を表す。
`meth` の引数の型の等式は、`Ty.Le` が最も外側の関数型のエフェクトだけを広げることに依る。
`Ty.Le` を深い部分型に広げるときは、C-Meth の型を `Ty.Le` で広げた形に直す。 -/
inductive CallHead.HasTypeQ (P : Release.Program) (B : Builtins) (Q : NoFailCtx) (C : List TParam)
    (Γ : List (Option Ty)) : CallHead → List String → List Ty → Ty → Eff → Prop
  | app {v ds dnames names dtys as a εcall ε} :
      HasTypeVQ P B StoreTy.empty Q C Γ v (.fn (dnames ++ names) (dtys ++ as) a εcall) →
      HasTypeVsQ P B StoreTy.empty Q C Γ ds dtys → Eff.Sub εcall ε →
      CallHead.HasTypeQ P B Q C Γ (.app v ds) names as a ε
  | meth {d cl τ cd m ms ss es us utys as ε} :
      HasTypeVQ P B StoreTy.empty Q C Γ d (.dict cl τ) →
      P.classes cl = some cd → cd.methods m = some ms → NamesWF ms.names ms.params →
      SatAll B C ss ms.tparams →
      (∀ t ∈ ss ++ [τ], Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e) →
      MethodRowsAdmissible C Q ms es →
      HasTypeVsQ P B StoreTy.empty Q C Γ us utys →
      ms.params.map (Ty.subst (ss ++ [τ]) es) = utys ++ as →
      Eff.Sub (Eff.substAt 0 (ss ++ [τ]) es ms.eff) ε →
      CallHead.HasTypeQ P B Q C Γ (.meth d m ss es us) (ms.names.drop us.length) as
        (ms.ret.subst (ss ++ [τ]) es) ε

abbrev CallHead.HasType (P : Release.Program) (B : Builtins) := CallHead.HasTypeQ P B Qempty

theorem CallHead.HasTypeQ.apply {P B C Γ h names as a ε R ws}
    (hh : CallHead.HasTypeQ P B Q C Γ h names as a ε)
    (hw : HasTypeVsQ P B StoreTy.empty Q C Γ ws as) :
    HasTypeCQ P B StoreTy.empty Q C Γ R (h.apply ws) a ε := by
  cases hh with
  | app hv hd hs => exact .C_Eff (.C_App hv (hd.append hw)) hs
  | meth hd hc hm hn ht hscope he hu hp hs =>
      apply HasTypeCQ.weakenEff (HasTypeCQ.C_Meth hd hc hm hn ht hscope he ?_) hs
      rw [hp]; exact hu.append hw

theorem CallHead.HasTypeQ.rename {P B C Γ Δ h names as a ε ξ}
    (hh : CallHead.HasTypeQ P B Q C Γ h names as a ε) (hr : RenOk Γ Δ ξ) :
    CallHead.HasTypeQ P B Q C Δ (h.rename ξ) names as a ε := by
  cases hh with
  | app hv hd hs => exact .app (hv.rename hr) (hd.rename hr) hs
  | meth hd hc hm hn ht hscope he hu hp hs => simpa only [CallHead.rename, Val.renameList_length] using
      (CallHead.HasTypeQ.meth (hd.rename hr) hc hm hn ht hscope he (hu.rename hr) hp hs)

theorem CallHead.HasTypeQ.weakenEff {P B C Γ h names as a ε δ}
    (hh : CallHead.HasTypeQ P B Q C Γ h names as a ε) (hs : Eff.Sub ε δ) :
    CallHead.HasTypeQ P B Q C Γ h names as a δ := by
  cases hh with
  | app hv hd he => exact .app hv hd (he.trans hs)
  | meth hd hc hm hn ht hscope he hu hp heff => exact .meth hd hc hm hn ht hscope he hu hp (heff.trans hs)

/-- handled は節の本体を読まないので、脱糖前の操作の並びで計算できる。 -/
theorem desugarClauses_handles (op : OpPrim) (cs : Clauses) (o : OpRef) :
    handles (desugarClauses op cs) o = handles cs.skeleton o := by
  match cs with
  | .nil => rfl
  | .cons _ _ _ _ rest _ =>
      simpa only [desugarClauses, Clauses.skeleton, handles, List.any_cons, Clause.op] using
        congrArg (fun b => _ || b) (desugarClauses_handles op rest o)

theorem desugarClauses_handled (op : OpPrim) (p : Program) (B : Builtins) (cs : Clauses) :
    handled (desugarProgram op p) B (desugarClauses op cs) =
      handled p.declarations.patternProgram B cs.skeleton := by
  have hh : handles (desugarClauses op cs) = handles cs.skeleton :=
    funext (desugarClauses_handles op cs)
  apply Eff.ext_test
  · intro a
    cases a with
    | rho _ => rfl
    | name l =>
        simp only [Eff.test, Eff.ofAtoms, handled, hh]
        rfl
  · rfl

variable {P : Release.Program} {B : Builtins} {C : List TParam} {Γ : List (Option Ty)}

/-- 位置が一意なら、検索は同じソース位置の値を返す。値の型には依存しない。 -/
theorem fieldAt_getElem {α : Type} {positions : List Nat} {vs : List α} {k : Nat}
    (hn : positions.Nodup) (hl : vs.length = positions.length) (hk : k < positions.length) :
    fieldAt positions[k] positions vs = some (vs[k]'(by omega)) := by
  induction positions generalizing vs k with
  | nil => simp at hk
  | cons j js ih =>
      cases vs with
      | nil => simp at hl
      | cons v vs =>
          obtain ⟨hj, hn⟩ := List.nodup_cons.mp hn
          cases k with
          | zero => simp [fieldAt]
          | succ k =>
              have hk' : k < js.length := by simpa using hk
              have he : js[k] ≠ j := by
                intro he
                exact hj (he ▸ List.getElem_mem hk')
              simpa only [List.getElem_cons_succ, fieldAt, ite_eq_right he] using
                ih hn (by simpa using hl) hk'

/-- 宣言位置への並べ替えは、元のソース位置の値そのものを保持する。 -/
theorem recordFields_getElem {α : Type} {n : Nat} {positions : List Nat} {vs : List α}
    (fallback : α) (hp : positions.Perm (List.range n)) (hl : vs.length = positions.length)
    {k : Nat} (hk : k < positions.length) :
    (recordFields n positions vs fallback)[positions[k]]? = some (vs[k]'(by omega)) := by
  have hi : positions[k] < n := List.mem_range.mp (hp.mem_iff.mp (List.getElem_mem hk))
  have hf := fieldAt_getElem (hp.nodup_iff.mpr List.nodup_range) hl hk
  simp [recordFields, hi, hf]

/-- k 番目の計算の束縛は、全 n 個を束縛した後の番号 n-1-k を持つ。 -/
theorem boundVars_getElem {n k : Nat} (hk : k < n) :
    (boundVars n)[k]'(by simpa [boundVars] using hk) = .var (n - 1 - k) := by
  simp only [boundVars, List.getElem_map, List.getElem_reverse, List.length_range,
    List.getElem_range]

/-- 書いた位置に対応する値が、その位置の宣言型を持つ。 -/
theorem fieldAt_typed {positions : List Nat} {vs : List Val} {tys : List Ty} {i : Nat}
    (h : HasTypeVsQ P B StoreTy.empty Q C Γ vs
      (positions.map fun j => (tys[j]?).getD (.base .unit))) (hi : i ∈ positions) :
    ∃ v, fieldAt i positions vs = some v ∧
      HasTypeVQ P B StoreTy.empty Q C Γ v ((tys[i]?).getD (.base .unit)) := by
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
    (h : ∀ i ∈ indices, HasTypeVQ P B StoreTy.empty Q C Γ (v i) (t i)) :
    HasTypeVsQ P B StoreTy.empty Q C Γ (indices.map v) (indices.map t) := by
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
    (h : HasTypeVsQ P B StoreTy.empty Q C Γ vs
      (positions.map fun j => (tys[j]?).getD (.base .unit))) :
    HasTypeVsQ P B StoreTy.empty Q C Γ
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


/-- 対応表の全域性・単射性・範囲は、型付けが持つ置換から得る。 -/
theorem CallOk.positions {names ps inserted labels positions}
    (h : CallOk names ps inserted labels positions) :
    ((if inserted then [0] else []) ++ positions).Nodup ∧
      (∀ i ∈ (if inserted then [0] else []) ++ positions, i < ps.length) ∧
      (∀ i, i < ps.length → i ∈ (if inserted then [0] else []) ++ positions) := by
  have hp := h.2.2.1
  exact ⟨hp.nodup_iff.mpr List.nodup_range,
    fun i hi => List.mem_range.mp (hp.mem_iff.mp hi),
    fun i hi => hp.mem_iff.mpr (List.mem_range.mpr hi)⟩

/-- 通常・穴・パイプの対応表で、明示引数 k の束縛を位置 i に置く。
insertedValues は評価済みの挿入引数であり、callee の束縛や rename 後の値でもよい。 -/
theorem CallOk.recordFields_source {names ps inserted labels positions}
    (h : CallOk names ps inserted labels positions) (insertedValues : List Val)
    (hl : insertedValues.length = if inserted then 1 else 0) {n k i : Nat}
    (hn : n = positions.length) (hk : k < positions.length) (hi : positions[k] = i) :
    (recordFields (insertedValues.length + n) (List.range insertedValues.length ++ positions)
      (insertedValues ++ boundVars n) (.const .unit))[i]? = some (.var (n - 1 - k)) := by
  have hr : List.range insertedValues.length = (if inserted then [0] else []) := by
    cases inserted <;> simp_all
  have hp := h.2.2.1
  rw [← hr] at hp
  have hs : insertedValues.length + n = ps.length := by
    have hs := hp.length_eq
    simp only [List.length_append, List.length_range] at hs
    omega
  rw [← hs] at hp
  have hj : insertedValues.length + k < (List.range insertedValues.length ++ positions).length := by
    simp only [List.length_append, List.length_range]
    omega
  have hi' : (List.range insertedValues.length ++ positions)[insertedValues.length + k] = i := by
    rw [List.getElem_append_right (by simp)]
    simpa using hi
  have hv := recordFields_getElem (.const .unit) hp
    (vs := insertedValues ++ boundVars n) (by simp [boundVars, hn]) hj
  rw [hi'] at hv
  have hk' : k < n := by omega
  simpa [List.getElem_append_right, boundVars_getElem hk'] using hv

@[simp] theorem sourceTypes_length (ps : List Ty) (positions : List Nat) :
    (sourceTypes ps positions).length = positions.length := by simp [sourceTypes]

@[simp] theorem sourceTypes_append (ps : List Ty) (xs ys : List Nat) :
    sourceTypes ps (xs ++ ys) = sourceTypes ps xs ++ sourceTypes ps ys := List.map_append

/-- 参照の型を並べ替えるだけであり、計算の順序は変更しない。 -/
theorem callComp_typed {R shift inserted f callee positions ms names ps a ε εcall}
    (xs : List (Option Ty)) (hlen : xs.length = inserted.length)
    (hp : (List.range inserted.length ++ positions).Perm (List.range ps.length))
    (hf : HasTypeCQ P B StoreTy.empty Q C (xs ++ Γ) R (callee.rename (· + shift))
      (.fn names ps a εcall) ε)
    (hd : ∀ h, directCallee f = some h → ∀ ys : List (Option Ty),
      CallHead.HasTypeQ P B Q C (ys ++ xs ++ Γ)
        (h.rename (· + (shift + ys.length))) names ps a εcall)
    (hi : HasTypeVsQ P B StoreTy.empty Q C (xs ++ Γ) inserted
      (sourceTypes ps (List.range inserted.length)))
    (hms : CompTypesQ P B Q C Γ R ε ms (sourceTypes ps positions))
    (hc : Ty.VarsInList C.length (fun _ => True) (sourceTypes ps positions))
    (he : Eff.Sub εcall ε) :
    HasTypeCQ P B StoreTy.empty Q C (xs ++ Γ) R (callComp shift inserted f callee positions ms) a ε := by
  have hm : ms.length = positions.length := by simpa only [sourceTypes_length] using hms.length
  have ordered := fun {Δ : List (Option Ty)} {vs} (hv : HasTypeVsQ P B StoreTy.empty Q C Δ vs
      (sourceTypes ps (List.range inserted.length ++ positions))) =>
    recordFields_typed hp hv
  unfold callComp
  split
  · rename_i h hh
    rw [← hlen]
    apply letChain_typed hms xs
    rw [hms.length]
    apply HasTypeCQ.weakenEff (δ := ε)
    · apply CallHead.HasTypeQ.apply
      · simpa only [binds_length] using hd h hh (binds (sourceTypes ps positions))
      · have hv := (hi.rename (RenOk.shift (binds (sourceTypes ps positions)) (xs ++ Γ))).append
          (boundVars_typed (Γ := xs ++ Γ) hc)
        have ho := ordered (by simpa only [sourceTypes_append] using hv)
        simpa only [List.length_append, List.length_range, sourceTypes_length, hm, ← hlen,
          binds_length, List.append_assoc] using ho
    · exact he
  · apply HasTypeCQ.C_Let hf
    rw [← hlen]
    apply letChain_typed hms (some (.fn names ps a εcall) :: xs)
    rw [hms.length]
    apply HasTypeCQ.weakenEff (δ := ε)
    · apply HasTypeCQ.C_App (names := names) (as := ps) (ε := εcall)
      · apply HasTypeVQ.V_Var
        · rw [List.append_assoc, List.getElem?_append_right (by simp [binds_length])]
          simp [binds_length]
        · intro _ _ _ h; cases h
      · have hr := hi.rename (RenOk.shift
          (binds (sourceTypes ps positions) ++ [some (.fn names ps a εcall)]) (xs ++ Γ))
        have hv := hr.append (by
          simpa only [List.append_assoc, List.singleton_append] using
            (boundVars_typed (P := P) (B := B) (Γ := some (.fn names ps a εcall) :: (xs ++ Γ)) hc))
        have ho := ordered (by simpa only [sourceTypes_append, List.append_assoc, List.singleton_append] using hv)
        simpa only [List.length_append, List.length_range, sourceTypes_length, hm, ← hlen, binds_length,
          List.length_singleton, List.append_assoc, List.singleton_append, List.cons_append,
          List.nil_append] using ho
    · exact he

end Benitoite.Surface
