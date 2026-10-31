import Benitoite.Release.Refinement.SubstTyping
import Benitoite.Release.Refinement.Narrowing

/-!
# 生の値置換と潜在効果の正規形

生の置換は Fail の重複や並び順の崩れを生む。
項の値置換では bind による正規化が必要である。
-/

namespace Benitoite.Release.Refinement

set_option maxHeartbeats 2000000

private theorem lam_annotations {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) :
    ∀ ns ps body, v = .lam ns ps body → Ty.WFList 0 C.length Γ.length ps := by
  match h with
  | .V_Var _ _ | .V_Const _ | .V_List _ _ _ _ | .V_Raise _ | .V_LocRef _ _ | .V_LocLazy _ _
  | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_Map _ _ _ _ _ _ | .V_Set _ _ _ | .V_Dict _ _ _ _ _ _ _ _
  | .V_PathBases _ | .V_ScopePattern _ _ _ | .V_Checked _ _ _ |
      .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ | .V_AtError _
  | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _
  | .V_Bytes _ | .V_Con _ _ _ _ _ _ | .V_Super _ _ _ _ =>
      intro ns ps body he; cases he
  | .V_DependentLam .. | .V_Closure .. => intro ns ps body he; cases he
  | .V_Lam _ hw _ _ _ =>
      intro ns ps body he; cases he; exact hw.2.1
  | .V_Normal hv => exact lam_annotations hv
  | .V_Sub hv _ _ _ _ => exact lam_annotations hv
  | .V_Refine hv _ _ _ _ _ _ _ => exact lam_annotations hv

/-- ラムダの注釈の整形式は、外側の部分型・篩導入を越えて必要である。 -/
theorem HasTypeVQ.lam_annotations_wf {P B store Q C Γ Φ ns ps body a}
    (h : HasTypeVQ P B store Q C Γ Φ (.lam ns ps body) a) :
    Ty.WFList 0 C.length Γ.length ps := lam_annotations h ns ps body rfl

private theorem return_value {P B store Q C Γ Φ R m a ε Δl}
    (h : HasTypeCQ P B store Q C Γ Φ R m a ε Δl) :
    ∀ v, m = .ret v → ∃ b, HasTypeVQ P B store Q C Γ Φ v b := by
  match h with
  | .C_Return hv => intro v he; cases he; exact ⟨_, hv⟩
  | .C_IssuePathBases _ _ _ _ _ _ _ _ | .C_CheckAt _
  | .C_Handle _ _ _ | .C_Handle_Fail _ _ _ _ | .C_Match _ _ _ | .C_External _ _ _ _ | .C_Resume _ _ _ | .C_ResumeL _ _ _ | .C_ResumeNorm _ _ _ | .C_ResumeLNorm _ _ _ _
  | .C_BuilderLet _ _ _ _ | .C_BuilderOp _ _ _ _ | .C_Meth _ _ _ _ _ _ _ _ _ _
  | .C_Let _ _ _ | .C_DependentApp .. | .C_App _ _ | .C_If _ _ _ | .C_Lazy _ _ | .C_Escape _ _ | .C_Use _ _ _ _ => intro v he; cases he
  | .C_Normal hm | .C_Sub hm _ _ _ _ _ | .C_Eff hm _ => exact return_value hm

/-- return の型付けは、部分型・効果拡大の下にも値の導出を含む。 -/
theorem HasTypeCQ.return_value_typable {P B store Q C Γ Φ R v a ε Δl}
    (h : HasTypeCQ P B store Q C Γ Φ R (.ret v) a ε Δl) :
    ∃ b, HasTypeVQ P B store Q C Γ Φ v b := return_value h v rfl

namespace RawValueSubstCollision

def refinedInt : Ty := .refined (.base .integer) (.eq (.var 0) (.integer 7))
def Γ : Ctx := [some refinedInt, some refinedInt]
def Δ : Ctx := [some refinedInt]
def path : Pred := .eq (.var 0) (.integer 7)
def Φ : List Pred := [path]
def σ (_ : Nat) : Val := .var 0
def failure (i : Nat) : Ty := .refined (.base .integer) (.eq (.var 0) (.var (i+1)))
def latent : Eff := .mk (fun _ => false) [failure 0, failure 1]
def sourceTy : Ty := .fn [] [] (.base .unit) latent

theorem failure_compare : tyCompare (failure 0) (failure 1) = .lt := by
  simp [failure, tyCompare, Ty.toTree, predTree, termTree, Order.treeCompare,
    Order.treesCompare, Order.labelCompare, BaseTy.rank, Ordering.then]
  rfl

theorem failure_norm (i : Nat) : (failure i).norm = failure i := rfl

theorem latent_canonical : latent.Canonical := by
  simp only [Eff.Canonical, latent, Eff.norm, Ty.normTys, failure_norm,
    Order.sortUnique, Order.insertUnique, failure_compare]

theorem source_wf : sourceTy.WF 0 0 Γ.length := by
  exact ⟨⟨rfl, List.nodup_nil⟩, trivial, trivial,
    ⟨⟨trivial, by simp [Term.VarsIn, Pred.VarsIn, Γ, Pred.WF, Ty.NotContCore, Ty.core]⟩,
      ⟨trivial, by simp [Term.VarsIn, Pred.VarsIn, Γ, Pred.WF, Ty.NotContCore, Ty.core]⟩, trivial⟩, latent_canonical⟩

theorem source_sorted : sourceTy.Sorted Γ := by
  simp [Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Ty.HasSort, Ty.sort?, sourceTy, Ty.Sorted, sortedTys, sortedEff, latent, failure,
    Pred.Sorted, Γ, refinedInt]

theorem image_type : substTyValues σ refinedInt = refinedInt := rfl

theorem images_typed {P B store Q C i a} (hi : Γ[i]? = some (some a)) :
    HasTypeVQ P B store Q C Δ Φ (σ i) (substTyValues σ a) := by
  have ha : a = refinedInt := by
    cases i with
    | zero => simpa [Γ] using hi.symm
    | succ i => cases i <;> simp_all [Γ]
  subst a
  exact .V_Var rfl (by intro b t e h; cases h)

/-- 契約の SubstOk が要求する正規化後の像でも、同じ型付き像が使える。 -/
theorem images_typed_bind {P B store Q C i a} (hi : Γ[i]? = some (some a)) :
    HasTypeVQ P B store Q C Δ Φ (σ i) (a.bind (valEnv σ)) := by
  have ha : a = refinedInt := by
    cases i with
    | zero => simpa [Γ] using hi.symm
    | succ i => cases i <;> simp_all [Γ]
  subst a
  exact .V_Var rfl (by intro b t e h; cases h)

theorem context_facts : Γ.facts = [path, .eq (.var 1) (.integer 7)] ∧
    Δ.facts = [path] := ⟨rfl, rfl⟩

theorem transport : Transport (valEnv σ) Γ Φ Δ Φ := by
  constructor
  · intro i a sort hi ha
    have he : a = refinedInt := by
      cases i with
      | zero => simpa [Γ] using hi.symm
      | succ i => cases i <;> simp_all [Γ]
    subst a
    exact ⟨.var 0, rfl, ⟨refinedInt, rfl, by simp [refinedInt]⟩, refinedInt, rfl, ha⟩
  · intro i a hi ho t ht
    cases ht
    exact ⟨refinedInt, rfl, by simp [refinedInt]⟩
  · intro i; simp [valEnv]
  · intro p hp
    have hp : p = path ∨ p = .eq (.var 1) (.integer 7) := by
      simp only [context_facts.1, Φ, List.mem_append, List.mem_cons,
        List.not_mem_nil, or_false] at hp
      rcases hp with (h | h) | h
      · exact Or.inl h
      · exact Or.inr h
      · exact Or.inl h
    rcases hp with rfl | rfl
    all_goals exact .hyp (List.mem_append_left _ (by rw [context_facts.2]; exact List.mem_cons_self))

theorem latent_image : Eff.rawBind (valEnv σ) latent =
    .mk (fun _ => false) [failure 0, failure 0] := by
  change Eff.rawBind ⟨Ty.tvar, [], [], fun _ => some (.var 0)⟩ latent = _
  rw [← Eff.rawSubstV_eq_rawBind]
  rfl

theorem latent_image_not_canonical : ¬ (Eff.rawBind (valEnv σ) latent).Canonical := by
  rw [latent_image]
  simp only [Eff.Canonical, Eff.norm, Ty.normTys, Ty.norm, failure,
    Order.sortUnique, Order.insertUnique,
    (tyCompare_eq_iff _ _).mpr rfl]
  intro h
  have := congrArg (fun e => e.fails.length) h
  simp [Eff.fails] at this

theorem substituted_not_wf : ¬ (sourceTy.rawBind (valEnv σ)).WF 0 0 Δ.length := by
  intro h
  exact latent_image_not_canonical h.2.2.2.2

def sourceVal : Val := .lam ["f"] [sourceTy] (.ret (.const .unit))
def valueTy : Ty := .fn ["f"] [sourceTy] (.base .unit) Eff.empty
def resultTy : Ty := .refined valueTy path.lift

theorem value_wf : valueTy.WF 0 0 Γ.length := by
  exact ⟨⟨rfl, by simp⟩, ⟨source_wf, trivial⟩, trivial, trivial, rfl⟩

theorem value_sorted : valueTy.Sorted Γ := ⟨⟨source_sorted, trivial⟩, trivial, trivial⟩

theorem path_lift_sorted : path.lift.Sorted Γ (some valueTy) := by
  simp [termBind?, Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Ty.HasSort, Ty.sort?, path, Pred.lift, predBind, termBind, Pred.Sorted,
    Γ, refinedInt]

theorem path_lift_wf : path.lift.WF (Γ.length+1) := by
  simp [termBind?, Term.VarsIn, Pred.VarsIn, path, Pred.lift, predBind, termBind, Pred.WF, Γ]

/-- 文脈の事実を実際に使う、外側の篩の導入。 -/
theorem source_le : Ty.LeQ Γ Φ valueTy resultTy := by
  apply Ty.LeQ.introduce path_lift_sorted
  exact .hyp (List.mem_append_right _ (List.mem_map.mpr
    ⟨path, List.mem_append_left _ (by rw [context_facts.1]; exact List.mem_cons_self), rfl⟩))

theorem lambda_typed {P B store Q} :
    HasTypeVQ P B store Q [] Γ Φ sourceVal valueTy := by
  change HasTypeVQ P B store Q [] Γ Φ
    (.lam ["f"] [sourceTy] (.ret (.const .unit))) (.fn ["f"] [sourceTy] (.base .unit) Eff.empty)
  refine .V_Lam ?_ value_wf value_sorted ?_ ?_
  · exact ⟨rfl, by simp⟩
  · exact .C_Return (.V_Const trivial)
  · simp [sourceTy, latent, failure, refinedInt, predBind,
      termBind, termBind?, Ty.Declared, declaredTys, declaredEff, Pred.Declared, Term.Declared,
      Ctx.declarationSelf, Ctx.extend, Ctx.Readable, Γ, Ty.shiftV, Ordinary, Eff.empty]

theorem result_declared {P} : Ty.Declared P [] Γ resultTy := by
  simp [resultTy, valueTy, sourceTy, latent, failure, refinedInt, path, Pred.lift, predBind,
    termBind, termBind?, Ty.Declared, declaredTys, declaredEff, Pred.Declared, Term.Declared,
    Ctx.declarationSelf, Ctx.extend, Ctx.Readable, Γ, Ty.shiftV, Ordinary, Eff.empty]

theorem source_v_sub {P B store Q} :
    HasTypeVQ P B store Q [] Γ Φ sourceVal resultTy :=
  .V_Sub lambda_typed source_le ⟨value_wf, path_lift_wf, by simp [valueTy, Ty.NotContCore, Ty.core]⟩
    ⟨value_sorted, path_lift_sorted⟩ result_declared

theorem source_c_sub {P B store Q R Δl} :
    HasTypeCQ P B store Q [] Γ Φ R (.ret sourceVal) resultTy Eff.empty Δl :=
  .C_Sub (.C_Return lambda_typed) source_le (Eff.Covers.refl _ _ _)
    ⟨value_wf, path_lift_wf, by simp [valueTy, Ty.NotContCore, Ty.core]⟩ ⟨value_sorted, path_lift_sorted⟩ result_declared

def rawSourceVal : Val := .lam ["f"] [sourceTy.rawBind (valEnv σ)] (.ret (.const .unit))

/-- 生の型注釈のままのラムダは、結果型を変えても型付けできない。 -/
theorem raw_lambda_untypable {P B store Q Φ' a} :
    ¬ HasTypeVQ P B store Q [] Δ Φ' rawSourceVal a := by
  intro h
  have hw := HasTypeVQ.lam_annotations_wf h
  exact substituted_not_wf hw.1

theorem raw_return_untypable {P B store Q Φ' R a ε Δl} :
    ¬ HasTypeCQ P B store Q [] Δ Φ' R (.ret rawSourceVal) a ε Δl := by
  intro h
  obtain ⟨b, hb⟩ := HasTypeCQ.return_value_typable h
  exact raw_lambda_untypable hb

theorem subst_ok {P B store Q R0} : SubstOk P B store Q [] Γ Φ Δ Φ R0 σ := by
  intro i a hi
  have ha : a = refinedInt := by
    cases i with
    | zero => simpa [Γ] using hi.symm
    | succ i => cases i <;> simp_all [Γ]
  subst a
  refine .ordinary ?_ (images_typed hi)
  intro b t e he; cases he

theorem conditions_image : ∀ p ∈ Φ, Entails (Δ.facts ++ Φ) (predBind (valEnv σ).values p) := by
  intro p hp
  exact transport.facts p (List.mem_append_right _ hp)

/-- 修正後は、型付き像から導いた facts を V_Sub の置換で使える。 -/
theorem substituted_lambda_typed {P B store Q} (hA : Builtins.SubstitutionAssumptions P B) :
    HasTypeVQ P B store Q [] Δ Φ (sourceVal.subst σ) (substTyValues σ resultTy) :=
  ((source_v_sub (store := StoreTy.empty)).subst hA StoreTy.WF.empty (subst_ok (R0 := none)) conditions_image).weaken_empty hA.toValueAssumptions

theorem substituted_return_typed {P B store Q Δl} {R : Option Ty} (hA : Builtins.SubstitutionAssumptions P B) :
    HasTypeCQ P B store Q [] Δ Φ (R.map (substTyValues σ))
      ((Comp.ret sourceVal).subst σ) (substTyValues σ resultTy) (substEffValues σ Eff.empty) Δl :=
  ((source_c_sub (store := StoreTy.empty) (Δl := [])).subst hA StoreTy.WF.empty subst_ok conditions_image LocalRef.bound (.empty _ _ _ _)).weaken_empty hA.toValueAssumptions

theorem normalized_image_canonical : (substEffValues σ latent).Canonical := Eff.norm_idem _

def swapIndex (i : Nat) : Nat := if i = 0 then 1 else if i = 1 then 0 else i
def swapσ (i : Nat) : Val := .var (swapIndex i)

theorem swap_involutive (i : Nat) : swapIndex (swapIndex i) = i := by
  by_cases hi : i=0
  · subst i; rfl
  · by_cases hj : i=1
    · subst i; rfl
    · simp [swapIndex,hi,hj]

theorem swap_injective : Function.Injective swapσ := by
  intro i j he
  have hi := congrArg swapIndex (Val.var.inj he)
  simpa only [swap_involutive] using hi

theorem swap_latent_image : Eff.rawBind (valEnv swapσ) latent =
    .mk (fun _ => false) [failure 1, failure 0] := by
  change Eff.rawBind ⟨Ty.tvar, [], [], _⟩ latent = _
  rw [← Eff.rawSubstV_eq_rawBind]
  rfl

theorem swap_not_canonical : ¬ (Eff.rawBind (valEnv swapσ) latent).Canonical := by
  rw [swap_latent_image]
  have hcmp : tyCompare (failure 1) (failure 0) = .gt := by
    simp [failure, tyCompare, Ty.toTree, predTree, termTree, Order.treeCompare,
      Order.treesCompare, Order.labelCompare, BaseTy.rank, Ordering.then]
    rfl
  simp only [Eff.Canonical, Eff.norm, Ty.normTys, failure_norm,
    Order.sortUnique, Order.insertUnique, hcmp]
  intro he
  have ht := congrArg (fun e => e.fails.head?) he
  simp [Eff.fails, failure] at ht

/-- 空でない facts と篩付き像を、None の専用入口でも使う。 -/
theorem substituted_lambda_under_none {P B store Q} (hA : Builtins.SubstitutionAssumptions P B) :
    HasTypeVQ P B store Q [] Δ.extendNone (Φ.map Pred.lift)
      ((sourceVal.rename (fun i => i+1)).subst (upSubst 1 σ) (upLocalSubst 1 LocalRef.bound))
      (substTyValues (upSubst 1 σ) (resultTy.shiftV 1 0)) := by
  have hs := (source_v_sub (P := P) (B := B) (store := StoreTy.empty) (Q := Q)).shift_values
    (store' := StoreTy.empty) hA.toValueAssumptions StoreTy.WF.empty (.refl _) (ShiftMap.outerNone Γ)
    (Ξ := Φ.map Pred.lift) (fun p hp => by
      change Entails _ p.lift
      exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩)))
  simpa only [shiftIndex_add] using (hs.subst_under_none hA StoreTy.WF.empty (subst_ok (R0 := none)) conditions_image).weaken_empty hA.toValueAssumptions

theorem substituted_return_under_none {P B store Q} (hA : Builtins.SubstitutionAssumptions P B) :
    HasTypeCQ P B store Q [] Δ.extendNone (Φ.map Pred.lift) none
      ((Comp.ret (sourceVal.rename (fun i => i+1))).subst (upSubst 1 σ) (upLocalSubst 1 LocalRef.bound))
      (substTyValues (upSubst 1 σ) (resultTy.shiftV 1 0)) Eff.empty [] := by
  simpa only [substEffValues_empty, shiftIndex_add, Option.map_none] using
    ((HasTypeCQ.C_Return (P := P) (B := B) (R := none) (Δ := [])
      ((source_v_sub (P := P) (B := B) (store := StoreTy.empty) (Q := Q)).shift_values (store' := StoreTy.empty) hA.toValueAssumptions StoreTy.WF.empty (.refl _) (ShiftMap.outerNone Γ)
        (Ξ := Φ.map Pred.lift) (fun p hp => by
          change Entails _ p.lift
          exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩))))).subst_under_none (R := none)
          hA StoreTy.WF.empty subst_ok conditions_image LocalRef.bound (.empty _ _ _ _)).weaken_empty hA.toValueAssumptions

end RawValueSubstCollision

namespace NarrowingExample

open RawValueSubstCollision (refinedInt path)
def outer : Ctx := [some refinedInt, none]
def Φ : List Pred := [path]
def narrowTy : Ty := .refined refinedInt .truth
def source : Ctx := outer.extend refinedInt
def target : Ctx := outer.extend narrowTy
def result : Ty := .refined refinedInt path.lift

theorem original_wf : refinedInt.WF 0 0 outer.length := by
  simp [Term.VarsIn, Pred.VarsIn, refinedInt, outer, Ty.WF, Pred.WF, Ty.NotContCore, Ty.core]

theorem original_sorted : refinedInt.Sorted outer := by
  simp [Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Ty.HasSort, Ty.sort?, refinedInt, Ty.Sorted, Pred.Sorted]

theorem narrows {P} : Ctx.Narrows P [] source (Φ.map Pred.lift) target (Φ.map Pred.lift) :=
  .here .forget (by exact ⟨original_wf, trivial, by intro b t e h; cases h⟩) original_wf original_sorted (by
    simp [refinedInt, Ty.Declared, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.extend, Ctx.Readable, Ty.shiftV, Ordinary])

theorem source_le : Ty.LeQ source (Φ.map Pred.lift) refinedInt result := by
  apply Ty.LeQ.introduce
  · simp [Ty.shiftV, termBind?, Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Ty.HasSort, Ty.sort?, path, Pred.lift, predBind, termBind, Pred.Sorted, source,
      Ctx.extend, refinedInt]
  · exact .hyp (List.mem_append_right _ (List.mem_map.mpr
      ⟨path, List.mem_append_left _ (Ctx.mem_facts_extend.mpr
        (Or.inl (show path ∈ refinedInt.assume from List.mem_cons_self))), rfl⟩))

theorem result_wf : result.WF 0 0 source.length := by
  simp [Ty.shiftV, termBind?, Term.VarsIn, Pred.VarsIn, result, refinedInt, path, Pred.lift, predBind, termBind, Ty.WF, Pred.WF,
    source, outer, Ctx.extend, Ty.NotContCore, Ty.core]

theorem result_sorted : result.Sorted source := by
  simp [Ty.shiftV, termBind?, Term.HasSort, Term.Shape, Term.References, Ctx.Readable, Term.VarsIn, Ty.HasSort, Ty.sort?, result, refinedInt, path, Pred.lift, predBind, termBind, Ty.Sorted, Pred.Sorted,
    source, Ctx.extend]

theorem result_declared {P} : Ty.Declared P [] source result := by
  simp [result, refinedInt, path, Pred.lift, predBind, termBind, termBind?, Ty.Declared,
    Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.extend, Ctx.Readable, source, outer,
    Ty.shiftV, Ordinary]

theorem source_value {P B store Q} : HasTypeVQ P B store Q [] source (Φ.map Pred.lift) (.var 0) result :=
  .V_Sub (.V_Var rfl (by intro b t e he; cases he)) source_le result_wf result_sorted result_declared

theorem narrowed_value {P B store Q} (hA : Builtins.SubstitutionAssumptions P B) : HasTypeVQ P B store Q [] target (Φ.map Pred.lift) (.var 0) result :=
  ((source_value (store := StoreTy.empty)).narrow hA.toValueAssumptions StoreTy.WF.empty narrows).weaken_empty hA.toValueAssumptions

theorem source_comp {P B store Q} :
    HasTypeCQ P B store Q [] source (Φ.map Pred.lift) none (.ret (.var 0)) result Eff.empty [] :=
  .C_Sub (.C_Return (.V_Var rfl (by intro b t e he; cases he))) source_le
    (Eff.Covers.refl _ _ _) result_wf result_sorted result_declared

theorem narrowed_comp {P B store Q} (hA : Builtins.SubstitutionAssumptions P B) :
    HasTypeCQ P B store Q [] target (Φ.map Pred.lift) none (.ret (.var 0)) result Eff.empty [] :=
  ((source_comp (store := StoreTy.empty)).narrow hA.toValueAssumptions StoreTy.WF.empty narrows).weaken_empty hA.toValueAssumptions

theorem narrowed_under_none {P B store Q} (hA : Builtins.SubstitutionAssumptions P B) :
    HasTypeVQ P B store Q [] target.extendNone ((Φ.map Pred.lift).map Pred.lift)
      (.var 1) (result.shiftV 1 0) := by
  have hs := (source_value (P := P) (B := B) (store := StoreTy.empty) (Q := Q)).shift_values
    (store' := StoreTy.empty) hA.toValueAssumptions StoreTy.WF.empty (.refl _) (ShiftMap.outerNone source)
    (Ξ := (Φ.map Pred.lift).map Pred.lift) (fun p hp => by
      change Entails _ p.lift
      exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩)))
  exact (hs.narrow hA.toValueAssumptions StoreTy.WF.empty (.underNone narrows)).weaken_empty hA.toValueAssumptions

end NarrowingExample
end Benitoite.Release.Refinement
