import Benitoite.Release.Refinement.Coverage
import Benitoite.Release.Refinement.MatchPaths

/-!
# 到達しない選択肢の判定と実行時の分岐の選択

設計書 01-12「網羅性検査」、02-05「本体の後の検査」に対応する。網羅性の検査が到達しないと報告した選択肢は、
パターンの照合の上で選ばれない（`checkMatchWithView_unreachable_sound`）。本ファイルは、束縛の並べ替え（`selectSlots`）が
失敗しないという条件 `SlotsOk` のもとで、この判定を照合の遷移（`E_MatchBody`・`E_MatchGuard` の前提
`firstAlt v alts = some ws`）と照合の状態の不変条件 `MatchPrefix` に結ぶ。`SlotsOk` は腕の型付け（`AltsTy` の順列の
条件）から従う（`HasTypeArmsQ.slotsOk`）。
-/

namespace Benitoite.Release.Refinement

/-- どの分岐でも、パターンの照合に成功すれば束縛の並べ替えに成功する。 -/
def SlotsOk (arms : List Arm) : Prop :=
  ∀ arm ∈ arms, ∀ alt ∈ arm.alts, ∀ v ws, matchVal alt.pat v = some ws →
    (selectSlots ws alt.slots).isSome

/-- 実行が分岐 i に着いたとき、`firstAlt` が選択肢 j で照合するための条件。`MatchPrefix` は照合の状態の型付けと
`K_Guard` が保つ不変条件であり、前のガードのない分岐で `firstAlt = none` を要求し、ガード付きの分岐は数えない。
実際の到達可能性は主張しない。 -/
def RuntimeSelected (arms : List Arm) (i j : Nat) (v : Val) : Prop :=
  MatchPrefix v arms i ∧ ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
    firstAlt v (arm.alts.take j) = none ∧ (matchVal alt.pat v).isSome

/-! ## 型を仮定しない束縛の個数 -/

mutual
  theorem matchVal_binders {p : Pat} {v : Val} {ws : List Val}
      (hm : matchVal p v = some ws) : ws.length = p.binders := by
    cases p with
    | wild => simp only [matchVal, Option.some.injEq] at hm; subst ws; rfl
    | var => simp only [matchVal, Option.some.injEq] at hm; subst ws; rfl
    | const c =>
        cases v <;> simp only [matchVal, reduceCtorEq] at hm
        split at hm
        · simp only [Option.some.injEq] at hm; subst ws; rfl
        · cases hm
    | range lo hi =>
        cases v <;> simp only [matchVal, reduceCtorEq] at hm
        split at hm
        · simp only [Option.some.injEq] at hm; subst ws; rfl
        · cases hm
    | con c ps =>
        cases v <;> simp only [matchVal, reduceCtorEq] at hm
        all_goals
          split at hm
          · exact matchList_binders hm
          · cases hm
    | list before rest after =>
        cases v with
        | list elems =>
            simp only [matchVal] at hm
            cases hl : matchList before (elems.take before.length) with
            | none => simp [hl] at hm
            | some left =>
                cases hr : matchList after (elems.drop (elems.length - after.length)) with
                | none => simp [hl, hr] at hm
                | some right =>
                    simp only [hl, hr, Option.bind_eq_bind, Option.bind_some, Option.pure_def,
                      Option.ite_none_right_eq_some] at hm
                    obtain ⟨-, hws⟩ := hm
                    simp only [Option.some.injEq] at hws
                    subst hws
                    have hb := matchList_binders hl
                    have ha := matchList_binders hr
                    cases rest with
                    | none => simp [Pat.binders, hb, ha]
                    | some r => cases r <;> simp [Pat.binders, ListRest.binders, hb, ha] <;> omega
        | _ => simp [matchVal] at hm
  termination_by sizeOf p

  theorem matchList_binders {ps : List Pat} {vs ws : List Val}
      (hm : matchList ps vs = some ws) : ws.length = Pat.bindersList ps := by
    cases ps with
    | nil => cases vs <;> simp [matchList] at hm; subst ws; rfl
    | cons p ps =>
        cases vs with
        | nil => simp [matchList] at hm
        | cons v vs =>
            simp only [matchList] at hm
            cases hp : matchVal p v with
            | none => simp [hp] at hm
            | some left =>
                cases hs : matchList ps vs with
                | none => simp [hp, hs] at hm
                | some right =>
                    simp only [hp, hs, Option.bind_eq_bind, Option.bind_some, Option.pure_def,
                      Option.some.injEq] at hm
                    subst ws
                    simp [Pat.bindersList, matchVal_binders hp, matchList_binders hs]
  termination_by sizeOf ps
end

mutual
  /-- 型付いたパターンの束縛の型の列は、パターンの束縛の個数と同じ長さを持つ。 -/
  theorem PatTy.length_binders {P : Program} {p : Pat} {a : Ty} {δ : List Ty}
      (h : PatTy P p a δ) : δ.length = p.binders := by
    match h with
    | .P_Wild => rfl
    | .P_Var => rfl
    | .P_Const _ => rfl
    | .P_RangeInt => rfl
    | .P_RangeChar => rfl
    | .P_List (rest := rest) hb ha _ =>
        have eb := PatTys.length_binders hb
        have ea := PatTys.length_binders ha
        cases rest with
        | none => simp [Pat.binders, restTys, eb, ea]
        | some r => cases r <;> simp [Pat.binders, ListRest.binders, restTys, eb, ea] <;> omega
    | .P_Convert _ h => simpa only [List.length_map] using PatTy.length_binders h
    | .P_Refined h => exact PatTy.length_binders h
    | .P_Con _ _ _ hs => simpa only [Pat.binders] using PatTys.length_binders hs

  theorem PatTys.length_binders {P : Program} {ps : List Pat} {as δ : List Ty}
      (h : PatTys P ps as δ) : δ.length = Pat.bindersList ps := by
    match h with
    | .nil => rfl
    | .cons hp hs =>
        simp only [List.length_append, Pat.bindersList, PatTy.length_binders hp, PatTys.length_binders hs]
end

theorem selectSlots_isSome_of_lt {α : Type} {xs : List α} {slots : List Nat}
    (h : ∀ i ∈ slots, i < xs.length) : (selectSlots xs slots).isSome := by
  induction slots with
  | nil => rfl
  | cons i slots ih =>
      have hi := h i (by simp)
      have hs := ih (fun j hj => h j (by simp [hj]))
      simp only [selectSlots, List.getElem?_eq_getElem hi]
      cases he : selectSlots xs slots <;> simp_all

/-- 腕の型付けは束縛の並べ替えの成功を与える（`AltsTy` の順列の条件）。 -/
theorem HasTypeArmsQ.slotsOk {P B Ψ Q C Γ Φ R obs arms a b ε L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε L) : SlotsOk arms := by
  induction arms generalizing Φ with
  | nil => intro arm harm; cases harm
  | cons arm0 arms ih =>
    have key : ∃ δ, AltsTy P arm0.alts a δ ∧ ∃ Φ', HasTypeArmsQ P B Ψ Q C Γ Φ' R obs arms a b ε L := by
      cases h with
      | plain halts _ _ _ _ hr => exact ⟨_, halts, _, hr⟩
      | guarded halts _ _ _ _ _ _ hr => exact ⟨_, halts, _, hr⟩
    obtain ⟨δ, halts, Φ', hr⟩ := key
    intro arm harm alt halt v ws hm
    rcases List.mem_cons.mp harm with rfl | harm
    · obtain ⟨γ, hp, hperm, _⟩ := halts.2.2.2 alt halt
      apply selectSlots_isSome_of_lt
      intro i hi
      have hr := List.mem_range.mp (hperm.mem_iff.mp hi)
      rw [PatTy.length_binders hp] at hr
      simpa only [matchVal_binders hm] using hr
    · exact ih hr arm harm alt halt v ws hm

/-! ## 選択肢の順と分岐の順 -/

theorem firstAlt_none_of_slotsOk {alts : List Alt} {v : Val}
    (hs : ∀ alt ∈ alts, ∀ v ws, matchVal alt.pat v = some ws → (selectSlots ws alt.slots).isSome)
    (hn : firstAlt v alts = none) :
    ∀ alt ∈ alts, ¬ (matchVal alt.pat v).isSome := by
  induction alts with
  | nil => simp
  | cons alt alts ih =>
      cases hm : matchVal alt.pat v with
      | none =>
          have ht : firstAlt v alts = none := by simpa [firstAlt, hm] using hn
          intro other ho
          rcases List.mem_cons.mp ho with rfl | ho
          · simp [hm]
          · exact ih (fun x hx => hs x (by simp [hx])) ht other ho
      | some ws =>
          have hok := hs alt (by simp) v ws hm
          have he : selectSlots ws alt.slots = none := by simpa [firstAlt, hm] using hn
          simp [he] at hok

/-- 実行時の選択条件から、パターンだけによる選択条件を導く。 -/
theorem RuntimeSelected.alternativeSelected {arms : List Arm} {i j : Nat} {v : Val}
    (hs : SlotsOk arms) (h : RuntimeSelected arms i j v) :
    AlternativeSelected arms i j v := by
  obtain ⟨hprefix, arm, alt, hi, hj, hn, hm⟩ := h
  refine ⟨arm, alt, hi, hj, ?_, ?_, hm⟩
  · intro p hp
    obtain ⟨prior, hprior, hg, other, ho, he⟩ := (mem_unguardedPats (arms.take i) p).mp hp
    have hs' := hs prior (List.mem_of_mem_take hprior)
    have hn' := hprefix prior hprior (Option.isNone_iff_eq_none.mp hg)
    subst p
    exact firstAlt_none_of_slotsOk hs' hn' other ho
  · apply firstAlt_none_of_slotsOk ?_ hn
    intro prior hp
    exact hs arm (List.mem_of_getElem? hi) prior (List.mem_of_mem_take hp)

/-- 照合の遷移が分岐 i で `firstAlt v alts = some ws` を得るとき（`E_MatchBody`・`E_MatchGuard` の前提）、
`firstAlt` が実際に使った選択肢 j は実行時に選ばれる。 -/
theorem RuntimeSelected.of_firstAlt {arms : List Arm} {i : Nat} {v : Val} {alts : List Alt}
    {guard : Option Comp} {body : Comp} {ws : List Val}
    (hprefix : MatchPrefix v arms i) (hi : arms[i]? = some (.mk alts guard body))
    (hf : firstAlt v alts = some ws) :
    ∃ j alt xs, alts[j]? = some alt ∧ matchVal alt.pat v = some xs ∧
      selectSlots xs alt.slots = some ws ∧ RuntimeSelected arms i j v := by
  suffices key : ∀ (pre : List Alt) (rest : List Alt), pre ++ rest = alts → firstAlt v pre = none →
      firstAlt v rest = some ws →
      ∃ j alt xs, alts[j]? = some alt ∧ matchVal alt.pat v = some xs ∧
        selectSlots xs alt.slots = some ws ∧ firstAlt v (alts.take j) = none by
    obtain ⟨j, alt, xs, hj, hm, hsel, hn⟩ := key [] alts rfl rfl hf
    exact ⟨j, alt, xs, hj, hm, hsel, hprefix, .mk alts guard body, alt, hi, hj, hn, by simp [hm]⟩
  intro pre rest
  induction rest generalizing pre with
  | nil => intro _ _ h; simp [firstAlt] at h
  | cons alt rest ih =>
      intro he hpre hrest
      cases hm : matchVal alt.pat v with
      | some xs =>
          have hsel : selectSlots xs alt.slots = some ws := by simpa [firstAlt, hm] using hrest
          refine ⟨pre.length, alt, xs, ?_, hm, hsel, ?_⟩
          · subst he; simp
          · subst he; simp [hpre]
      | none =>
          have hrest' : firstAlt v rest = some ws := by simpa [firstAlt, hm] using hrest
          refine ih (pre ++ [alt]) (by simpa using he) ?_ hrest'
          clear ih hrest hrest' he
          induction pre with
          | nil => simp [firstAlt, hm]
          | cons x xs ihx =>
              cases hx : matchVal x.pat v with
              | none => simp only [firstAlt, hx] at hpre; simpa [firstAlt, hx] using ihx hpre
              | some ys =>
                  simp only [firstAlt, hx] at hpre
                  simp [firstAlt, hx, hpre]

/-! ## 到達しない選択肢の実行時の系 -/

/-- 任意の view の到達しない判定を、現在の値に対する実行時の選択条件へ結ぶ。 -/
theorem checkMatchWithView_unreachable_runtime (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView) (a : Ty) (arms : List Arm) (i j : Nat)
    (hc : CtorsComplete P ctors) (hs : SlotsOk arms)
    (h : (i, j) ∈ (checkMatchWithView P ctors view a arms).unreachable) :
    ∀ v, Inhabits P a v → ¬ RuntimeSelected arms i j v := by
  intro v hv hsel
  exact checkMatchWithView_unreachable_sound P ctors view a arms i j hc h v hv
    (hsel.alternativeSelected hs)

/-- 閉じた入口についての実行時の系。 -/
theorem checkMatch_unreachable_runtime (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (i j : Nat) (hc : CtorsComplete P ctors) (hs : SlotsOk arms)
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ v, Inhabits P a v → ¬ RuntimeSelected arms i j v :=
  checkMatchWithView_unreachable_runtime P ctors closedView a arms i j hc hs h

/-- 腕の型付けの型 a ごとの全称の系（旧の判断の同じ系の形）。`SlotsOk` は腕の型付けから導く。 -/
theorem checkMatchWithView_unreachable_runtime_of_arms
    {P : Program} {B : Builtins} {Ψ Q C Γ Φ R obs arms a b ε L}
    (ctors : DataName → List ConName) (view : CoverageView) (i j : Nat)
    (ha : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε L) (hc : CtorsComplete P ctors)
    (h : (i, j) ∈ (checkMatchWithView P ctors view a arms).unreachable) :
    ∀ w, Inhabits P a w → ¬ RuntimeSelected arms i j w :=
  checkMatchWithView_unreachable_runtime P ctors view a arms i j hc ha.slotsOk h

/-- 閉じた入口についての腕の型付けの全称の系。 -/
theorem checkMatch_unreachable_runtime_of_arms
    {P : Program} {B : Builtins} {Ψ Q C Γ Φ R obs arms a b ε L}
    (ctors : DataName → List ConName) (i j : Nat)
    (ha : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε L) (hc : CtorsComplete P ctors)
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ w, Inhabits P a w → ¬ RuntimeSelected arms i j w :=
  checkMatchWithView_unreachable_runtime_of_arms ctors closedView i j ha hc h

/-- 照合の計算の型付け（`C_Match`）から照合の型 a を取り出した系。`SlotsOk` は腕の型付けから導く。 -/
theorem checkMatchWithView_unreachable_runtime_of_C_Match
    {P : Program} {B : Builtins} {Ψ Q C Γ Φ R b e L v arms}
    (ctors : DataName → List ConName) (view : CoverageView)
    (ht : HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b e L) (hc : CtorsComplete P ctors) :
    ∃ a, HasTypeVQ P B Ψ Q C Γ Φ v a ∧ ∀ i j, (i, j) ∈ (checkMatchWithView P ctors view a arms).unreachable →
      ∀ w, Inhabits P a w → ¬ RuntimeSelected arms i j w := by
  obtain ⟨a, obs, hv, _, ha, _⟩ := ht.match_arms rfl
  exact ⟨a, hv, fun i j h => checkMatchWithView_unreachable_runtime_of_arms ctors view i j ha hc h⟩

/-- 閉じた入口についての `C_Match` の系。 -/
theorem checkMatch_unreachable_runtime_of_C_Match
    {P : Program} {B : Builtins} {Ψ Q C Γ Φ R b e L v arms}
    (ctors : DataName → List ConName)
    (ht : HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b e L) (hc : CtorsComplete P ctors) :
    ∃ a, HasTypeVQ P B Ψ Q C Γ Φ v a ∧ ∀ i j, (i, j) ∈ (checkMatch P ctors a arms).unreachable →
      ∀ w, Inhabits P a w → ¬ RuntimeSelected arms i j w :=
  checkMatchWithView_unreachable_runtime_of_C_Match ctors closedView ht hc

/-- 腕の型付けの全称の系の閉じた入口での適用。照合の計算の型付けの系は、反転で得た腕の型付けにこの系を当てる。 -/
example {P : Program} {B : Builtins} {Ψ Q C Γ Φ R obs arms a b ε L}
    (ctors : DataName → List ConName) (ha : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε L)
    (hc : CtorsComplete P ctors) (i j : Nat) (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ w, Inhabits P a w → ¬ RuntimeSelected arms i j w :=
  checkMatch_unreachable_runtime_of_arms ctors i j ha hc h

/-- 照合の遷移の前提（分岐 i で `firstAlt v alts = some ws`）が使う選択肢は、到達しないと報告された位置ではない。 -/
theorem firstAlt_not_unreachable (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} {arms : List Arm} {i : Nat} {v : Val} {alts : List Alt} {guard : Option Comp} {body : Comp}
    {ws : List Val} (hc : CtorsComplete P ctors) (hs : SlotsOk arms) (hv : Inhabits P a v)
    (hprefix : MatchPrefix v arms i) (hi : arms[i]? = some (.mk alts guard body))
    (hf : firstAlt v alts = some ws) :
    ∃ j alt xs, alts[j]? = some alt ∧ matchVal alt.pat v = some xs ∧ selectSlots xs alt.slots = some ws ∧
      (i, j) ∉ (checkMatchWithView P ctors view a arms).unreachable := by
  obtain ⟨j, alt, xs, hj, hm, hsel, hr⟩ := RuntimeSelected.of_firstAlt hprefix hi hf
  exact ⟨j, alt, xs, hj, hm, hsel, fun hu => checkMatchWithView_unreachable_runtime P ctors view a arms i j hc hs hu v hv hr⟩

end Benitoite.Release.Refinement
