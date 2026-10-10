import Benitoite.Release.Coverage
import Benitoite.Release.Lemmas.Canonical
import Benitoite.Release.Lemmas.Rename

/-!
# 網羅性の検査と実行時の分岐の選択（E1b-2）

束縛の並べ替えが成功するという条件のもとで、パターンだけによる
「選ばれない選択肢」の判定を `firstAlt` と照合の再開位置に結び付ける。
-/

namespace Benitoite.Release

/-- どの分岐でも、パターンの照合に成功すれば束縛の並べ替えに成功する。 -/
def SlotsOk (arms : List Arm) : Prop :=
  ∀ arm ∈ arms, ∀ alt ∈ arm.alts, ∀ v ws, Pat.matchVal alt.pat v = some ws →
    (selectSlots ws alt.slots).isSome

/-- 実行が分岐 i に着いたとき、`firstAlt` が選択肢 j で照合するための条件。
`MatchPrefix` は `StateTy` の `matchRun` と `K_Guard` が保つ不変条件であり、
前のガードのない分岐で `firstAlt = none` を要求し、ガード付き分岐は数えない。
前のガード付き分岐のガードが真なら i に着かないので、実行についての主張は空虚に成り立つ。
偽なら `E_GuardF` で次の分岐へ進む。i 自身にガードがある場合も、
前の選択肢が照合すれば `firstAlt` がそれを選ぶ。ガードが偽なら次の分岐へ進み、j は試されない。
slots が整っていれば、`firstAlt_eq_selectSlots_of_take` と合わせて
`E_MatchBody`・`E_MatchGuard` の `firstAlt = some ws` に結び付く。
この条件だけで実際の到達可能性は主張しない。 -/
def RuntimeSelected (arms : List Arm) (i j : Nat) (v : Val) : Prop :=
  MatchPrefix v arms i ∧ ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
    firstAlt v (arm.alts.take j) = none ∧ (Pat.matchVal alt.pat v).isSome

/-! ## 型を仮定しない束縛の個数と並べ替え -/

mutual
  theorem Pat.matchVal_length {p : Pat} {v : Val} {ws : List Val}
      (hm : Pat.matchVal p v = some ws) : ws.length = p.binders := by
    cases p with
    | wild => simp [Pat.matchVal] at hm; subst ws; rfl
    | var => simp [Pat.matchVal] at hm; subst ws; rfl
    | const c =>
        cases v <;> simp only [Pat.matchVal] at hm
        all_goals first
          | cases hm
          | (split at hm
             · simp at hm; subst ws; rfl
             · cases hm)
    | range lo hi =>
        cases v <;> simp only [Pat.matchVal] at hm
        all_goals first
          | cases hm
          | (split at hm
             · simp at hm; subst ws; rfl
             · cases hm)
    | con c ps =>
        cases v with
        | con c' ts args =>
            simp only [Pat.matchVal] at hm
            split at hm
            · exact Pat.matchList_length hm
            · cases hm
        | _ => simp [Pat.matchVal] at hm
    | list before rest after =>
        cases v with
        | list elems =>
            simp only [Pat.matchVal] at hm
            by_cases hlen : (if rest.isSome then before.length + after.length ≤ elems.length
                else before.length + after.length = elems.length)
            · rw [ite_eq_left hlen] at hm
              cases hl : Pat.matchList before (elems.take before.length) with
              | none => simp [hl] at hm
              | some left =>
                  cases hr : Pat.matchList after (elems.drop (elems.length - after.length)) with
                  | none => simp [hl, hr] at hm
                  | some right =>
                      simp [hl, hr] at hm; subst ws
                      have hb := Pat.matchList_length hl
                      have ha := Pat.matchList_length hr
                      cases rest with
                      | none => simp [Pat.binders, hb, ha]
                      | some r => cases r <;> simp [Pat.binders, ListRest.binders, hb, ha,
                          Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]
            · rw [ite_eq_right hlen] at hm; cases hm
        | _ => simp [Pat.matchVal] at hm
  termination_by sizeOf p

  theorem Pat.matchList_length {ps : List Pat} {vs ws : List Val}
      (hm : Pat.matchList ps vs = some ws) : ws.length = Pat.bindersList ps := by
    cases ps with
    | nil => cases vs <;> simp [Pat.matchList] at hm; subst ws; rfl
    | cons p ps =>
        cases vs with
        | nil => simp [Pat.matchList] at hm
        | cons v vs =>
            simp only [Pat.matchList] at hm
            cases hp : Pat.matchVal p v with
            | none => simp [hp] at hm
            | some left =>
                cases hs : Pat.matchList ps vs with
                | none => simp [hp, hs] at hm
                | some right =>
                    simp [hp, hs] at hm; subst ws
                    simp [Pat.bindersList, Pat.matchVal_length hp, Pat.matchList_length hs]
  termination_by sizeOf ps
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

theorem HasTypeArms.slotsOk {P : Program} {B : Builtins} {Ψ C Γ R arms a b ε}
    (h : HasTypeArms P B Ψ C Γ R arms a b ε) : SlotsOk arms := by
  intro arm harm alt halt v ws hm
  obtain ⟨δ, ha, _, _⟩ := h.mem harm
  obtain ⟨γ, hp, hperm, _⟩ := ha.2.2.2 alt halt
  apply selectSlots_isSome_of_lt
  intro i hi
  have hr := List.mem_range.mp (hperm.mem_iff.mp hi)
  rw [PatTy.length_eq hp] at hr
  simpa only [Pat.matchVal_length hm] using hr

/-! ## 選択肢の順と分岐の順 -/

theorem firstAlt_none_of_slotsOk {alts : List Alt} {v : Val}
    (hs : ∀ alt ∈ alts, ∀ v ws, Pat.matchVal alt.pat v = some ws →
      (selectSlots ws alt.slots).isSome)
    (hn : firstAlt v alts = none) :
    ∀ alt ∈ alts, ¬ (Pat.matchVal alt.pat v).isSome := by
  induction alts with
  | nil => simp
  | cons alt alts ih =>
      cases hm : Pat.matchVal alt.pat v with
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

theorem mem_unguardedPats_iff {p : Pat} {arms : List Arm} :
    p ∈ unguardedPats arms ↔
      ∃ arm ∈ arms, arm.guard = none ∧ ∃ alt ∈ arm.alts, alt.pat = p := by
  simpa only [Option.isNone_iff_eq_none] using mem_unguardedPats arms p

/-- 前の選択肢で並べ替えが失敗しないなら、接頭部の失敗後に j の照合結果を返す。
slots の条件がないと、前の選択肢が照合して並べ替えに失敗した場合に偽になる。 -/
theorem firstAlt_eq_selectSlots_of_take {alts : List Alt} {j : Nat} {alt : Alt}
    {v : Val} {ws : List Val}
    (hs : ∀ prior ∈ alts.take j, ∀ v ws, Pat.matchVal prior.pat v = some ws →
      (selectSlots ws prior.slots).isSome)
    (hn : firstAlt v (alts.take j) = none) (hi : alts[j]? = some alt)
    (hm : Pat.matchVal alt.pat v = some ws) :
    firstAlt v alts = selectSlots ws alt.slots := by
  have hp := firstAlt_none_of_slotsOk hs hn
  induction j generalizing alts with
  | zero => cases alts <;> simp_all [firstAlt]
  | succ j ih =>
      cases alts with
      | nil => simp at hi
      | cons prior alts =>
          have hprior : Pat.matchVal prior.pat v = none := by
            cases he : Pat.matchVal prior.pat v with
            | none => rfl
            | some xs => exact False.elim (hp prior (by simp) (by simp [he]))
          simp only [firstAlt, hprior]
          apply ih
          · intro other ho; exact hs other (by simp [ho])
          · simpa [List.take_succ_cons, firstAlt, hprior] using hn
          · simpa using hi
          · intro other ho; exact hp other (by simp [ho])

/-- 実行時の選択条件から、パターンだけによる選択条件を導く。 -/
theorem RuntimeSelected.alternativeSelected {arms : List Arm} {i j : Nat} {v : Val}
    (hs : SlotsOk arms) (h : RuntimeSelected arms i j v) :
    AlternativeSelected arms i j v := by
  obtain ⟨hprefix, arm, alt, hi, hj, hn, hm⟩ := h
  refine ⟨arm, alt, hi, hj, ?_, ?_, hm⟩
  · intro p hp
    obtain ⟨prior, hprior, hg, other, ho, he⟩ := mem_unguardedPats_iff.mp hp
    have hs' := hs prior (List.mem_of_mem_take hprior)
    have hn' := hprefix prior hprior hg
    subst p
    exact firstAlt_none_of_slotsOk hs' hn' other ho
  · apply firstAlt_none_of_slotsOk ?_ hn
    intro prior hp
    exact hs arm (List.mem_of_getElem? hi) prior (List.mem_of_mem_take hp)

theorem checkMatch_unreachable_runtime (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (i j : Nat) (hc : CtorsComplete P ctors) (hs : SlotsOk arms)
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ v, Inhabits P a v → ¬ RuntimeSelected arms i j v := by
  intro v hv hsel
  exact checkMatch_unreachable_sound P ctors a arms i j hc h v hv
    (hsel.alternativeSelected hs)

/-- C_Match の前提で照合の型 a を固定した系。
値の型付けと網羅性は C_Match に対応する。slots の整合は分岐の型付けから導く。 -/
theorem checkMatch_unreachable_runtime_of_C_Match
    {P : Program} {B : Builtins} {Ψ C Γ R v arms a b ε}
    (ctors : DataName → List ConName) (i j : Nat)
    (_hv : HasTypeV P B Ψ C Γ v a)
    (ha : HasTypeArms P B Ψ C Γ R arms a b ε)
    (_hex : Exhaustive P a (unguardedPats arms)) (hc : CtorsComplete P ctors)
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ w, Inhabits P a w → ¬ RuntimeSelected arms i j w :=
  checkMatch_unreachable_runtime P ctors a arms i j hc ha.slotsOk h

end Benitoite.Release
