import Benitoite.Surface.Lemmas.BuilderCaptureAll

/-!
# 脱糖の組み立てと捕捉

通常の計算を let でつなぐ際に、自由参照の番号を束縛数に合わせる。
設計書 01-12「構築器の局所文脈と旧構文の意味」に対応する。
-/
namespace Benitoite.Surface
open Benitoite.Release

theorem liftReads_zero (p : Nat → Prop) : liftReads 0 p = p := by
  funext i; simp [liftReads]

theorem liftReads_add (n d : Nat) (p : Nat → Prop) :
    liftReads n (liftReads d p) = liftReads (n + d) p := by
  funext i; apply propext
  simp only [liftReads]
  constructor
  · rintro (h | h | h)
    · exact Or.inl (by omega)
    · exact Or.inl (by omega)
    · by_cases hi : i < n + d
      · exact Or.inl hi
      · exact Or.inr (by simpa [Nat.sub_sub, Nat.add_comm] using h)
  · rintro (h | h)
    · by_cases hi : i < n
      · exact Or.inl hi
      · exact Or.inr (Or.inl (by omega))
    · by_cases hi : i < n
      · exact Or.inl hi
      · exact Or.inr (Or.inr (by simpa [Nat.sub_sub, Nat.add_comm] using h))

theorem Vals.captures_iff {p vs} : Vals.Captures p vs ↔ ∀ v ∈ vs, Val.Captures p v := by
  induction vs with
  | nil => simp [Vals.Captures]
  | cons v vs ih => simp [Vals.Captures, ih]

theorem Vals.captures_append {p xs ys} (hx : Vals.Captures p xs) (hy : Vals.Captures p ys) :
    Vals.Captures p (xs ++ ys) := by
  rw [Vals.captures_iff] at *
  intro v hv
  rcases List.mem_append.mp hv with h | h
  · exact hx v h
  · exact hy v h

theorem boundVars_captures (p : Nat → Prop) (n : Nat) : Vals.Captures p (boundVars n) := by
  simp [boundVars, Vals.captures_iff, Val.Captures]

mutual
  theorem DictEv.captures (p : Nat → Prop) (d : DictEv) : Val.Captures p d.toVal := by
    cases d with
    | impl i ts ds => exact DictEv.capturesList p ds
    | «local» i => trivial
    | clause s i depth => trivial
    | super d s => exact DictEv.captures p d
  theorem DictEv.capturesList (p : Nat → Prop) (ds : List DictEv) :
      Vals.Captures p (DictEv.toValList ds) := by
    cases ds with
    | nil => trivial
    | cons d ds => exact ⟨DictEv.captures p d, DictEv.capturesList p ds⟩
end

def CallHead.Captures (p : Nat → Prop) : CallHead → Prop
  | .app v ds | .meth v _ _ _ ds => Val.Captures p v ∧ Vals.Captures p ds

theorem CallHead.captures_rename {p q ξ} {h : CallHead} (hh : h.Captures p)
    (hr : ∀ i, p i → q (ξ i)) : (h.rename ξ).Captures q := by
  cases h <;> exact ⟨Val.Captures.rename _ hh.1 hr, Vals.Captures.rename _ hh.2 hr⟩

theorem CallHead.captures_apply {p vs} {h : CallHead} (hh : h.Captures p) (hv : Vals.Captures p vs) :
    Comp.Captures p (h.apply vs) := by
  cases h <;> simp only [CallHead.apply, Comp.Captures]
  all_goals exact ⟨hh.1, Vals.captures_append hh.2 hv⟩

theorem directCallee_captures {f h} (p : Nat → Prop) (hd : directCallee f = some h) :
    h.Captures p := by
  cases f <;> simp only [directCallee, Option.some.injEq] at hd
  all_goals cases hd
  all_goals first
    | exact ⟨trivial, trivial⟩
    | exact ⟨trivial, DictEv.capturesList p _⟩
    | exact ⟨DictEv.captures p _, DictEv.capturesList p _⟩

theorem fieldAt_captures {p vs fallback} (hv : Vals.Captures p vs)
    (hf : Val.Captures p fallback) (i : Nat) (positions : List Nat) :
    Val.Captures p ((fieldAt i positions vs).getD fallback) := by
  induction positions generalizing vs with
  | nil => simpa [fieldAt] using hf
  | cons j js ih =>
      cases vs with
      | nil => simpa [fieldAt] using hf
      | cons v vs =>
          simp only [fieldAt]
          split
          · exact hv.1
          · exact ih hv.2

theorem recordFields_captures {p vs fallback} (hv : Vals.Captures p vs)
    (hf : Val.Captures p fallback) (n : Nat) (positions : List Nat) :
    Vals.Captures p (recordFields n positions vs fallback) := by
  simp only [recordFields, Vals.captures_iff, List.forall_mem_map]
  intro i _; exact fieldAt_captures hv hf i positions

/-- 子の計算だけがクロージャを含み得る。終端の計算には全述語での条件を渡す。 -/
theorem letChain_captures {p ms body} (hm : ∀ m ∈ ms, Comp.Captures p m)
    (hb : ∀ q, Comp.Captures q body) (depth : Nat) :
    Comp.Captures (liftReads depth p) (letChain depth ms body) := by
  induction ms generalizing depth with
  | nil => exact hb _
  | cons m ms ih =>
      simp only [letChain, Comp.Captures]
      refine ⟨Comp.Captures.shift (hm m (by simp)) depth, ?_⟩
      simpa only [liftReads_add, Nat.add_comm 1] using
        ih (fun m h => hm m (by simp [h])) (depth + 1)

theorem sequence_captures {p ms finish} (hm : ∀ m ∈ ms, Comp.Captures p m)
    (hf : ∀ q, Comp.Captures q (finish (boundVars ms.length))) :
    Comp.Captures p (sequence ms finish) := by
  simpa only [sequence, liftReads_zero] using letChain_captures hm hf 0

/-- callComp が作る頭と並べ替えには lambda がない。callee と引数の帰納を保つ。 -/
theorem callComp_captures {p f callee ms} (hc : Comp.Captures p callee)
    (hm : ∀ m ∈ ms, Comp.Captures p m) (inserted : List Val)
    (hi : ∀ q, Vals.Captures q inserted) (positions : List Nat) :
    Comp.Captures (liftReads inserted.length p)
      (callComp inserted.length inserted f callee positions ms) := by
  unfold callComp
  split
  next h hd =>
    apply letChain_captures hm
    intro q
    apply CallHead.captures_apply
    · exact CallHead.captures_rename (directCallee_captures (fun _ => False) hd)
        (fun _ h => h.elim)
    · apply recordFields_captures (fallback := .const .unit) _ trivial
      exact Vals.captures_append
        (Vals.Captures.rename _ (hi (fun _ => False)) (fun _ h => h.elim)) (boundVars_captures _ _)
  next hd =>
    simp only [Comp.Captures]
    refine ⟨Comp.Captures.shift hc _, ?_⟩
    rw [liftReads_add, Nat.add_comm 1]
    apply letChain_captures hm
    intro q
    simp only [Comp.Captures, Val.Captures]
    exact ⟨trivial, recordFields_captures (fallback := .const .unit) (Vals.captures_append
      (Vals.Captures.rename _ (hi (fun _ => False)) (fun _ h => h.elim))
      (boundVars_captures _ _)) trivial _ _⟩

/-- 外側の番号に条件を課さない値は、任意の付け替えでも同じ性質を持つ。 -/
theorem Val.captures_free_rename {v ξ} (h : ∀ p, Val.Captures p v) :
    ∀ p, Val.Captures p (v.rename ξ) :=
  fun _ => Val.Captures.rename v (h (fun _ => False)) (fun _ h => h.elim)

theorem Vals.captures_free_rename {vs ξ} (h : ∀ p, Vals.Captures p vs) :
    ∀ p, Vals.Captures p (Val.renameList ξ vs) :=
  fun _ => Vals.Captures.rename vs (h (fun _ => False)) (fun _ h => h.elim)

theorem CallHead.captures_free_rename {h ξ} (hh : ∀ p, CallHead.Captures p h) :
    ∀ p, CallHead.Captures p (h.rename ξ) :=
  fun _ => CallHead.captures_rename (hh (fun _ => False)) (fun _ h => h.elim)

theorem recordUpdateValues_captures {vs} (hv : ∀ p, Vals.Captures p vs)
    (c : ConName) (n : Nat) (positions : List Nat) (p : Nat → Prop) :
    Vals.Captures p (recordUpdateValues c n positions vs) := by
  simp only [recordUpdateValues, Vals.captures_iff, List.forall_mem_map]
  intro i _
  have hf := fun p => fieldAt_captures (hv p) (fallback := .var 0) trivial i positions
  split
  next v he =>
    have hh : ∀ p, Val.Captures p v := by intro p; simpa [he] using hf p
    exact Val.captures_free_rename hh p
  next => simp [Val.Captures]

theorem spreadFinish_captures {h before s after}
    (hh : ∀ p, CallHead.Captures p h) (hb : ∀ p, Vals.Captures p before)
    (hs : ∀ p, Val.Captures p s) (ha : ∀ p, Vals.Captures p after) (p : Nat → Prop) :
    Comp.Captures p (spreadFinish h before s after) := by
  cases before <;> cases after <;> simp only [spreadFinish, Comp.Captures]
  · exact hs p
  · exact CallHead.captures_apply (hh p) ⟨hs p, ha p, trivial⟩
  · exact CallHead.captures_apply (hh p) ⟨hb p, hs p, trivial⟩
  · exact ⟨CallHead.captures_apply (hh p) ⟨hb p, hs p, trivial⟩,
      CallHead.captures_apply (CallHead.captures_free_rename hh _)
        ⟨trivial, Vals.captures_free_rename ha _, trivial⟩⟩

theorem spreadValues_captures {h vs} (hh : ∀ p, CallHead.Captures p h)
    (hv : ∀ p, Vals.Captures p vs) (n : Nat) (p : Nat → Prop) :
    Comp.Captures p (spreadValues h n vs) := by
  unfold spreadValues
  split
  next s after he =>
    apply spreadFinish_captures hh
    · intro p; rw [Vals.captures_iff]
      exact fun v h => Vals.captures_iff.mp (hv p) v (List.mem_of_mem_take h)
    · intro p; exact (Vals.captures_iff.mp (hv p)) _
        (List.mem_of_mem_drop (by rw [he]; simp))
    · intro p; rw [Vals.captures_iff]
      exact fun v h => Vals.captures_iff.mp (hv p) v (List.mem_of_mem_drop (by rw [he]; simp [h]))
  next => simp [Comp.Captures, Val.Captures]

theorem joinStringFrom_captures {left vs} (hl : ∀ p, Val.Captures p left)
    (hv : ∀ p, Vals.Captures p vs) (op : OpPrim) (depth : Nat) (p : Nat → Prop) :
    Comp.Captures p (joinStringFrom op depth left vs) := by
  induction vs generalizing left depth p with
  | nil => simpa only [joinStringFrom, Comp.Captures] using hl p
  | cons v vs ih =>
      simp only [joinStringFrom]
      split
      · simp [Comp.Captures, Val.Captures]
      · cases vs with
        | nil =>
            simp only [Comp.Captures, Val.Captures, Vals.Captures]
            exact ⟨trivial, hl p, Val.captures_free_rename (fun q => (hv q).1) p, trivial⟩
        | cons w ws =>
            simp only [Comp.Captures, Val.Captures, Vals.Captures]
            exact ⟨⟨trivial, hl p, Val.captures_free_rename (fun q => (hv q).1) p, trivial⟩,
              ih (left := .var 0) (fun _ => trivial) (fun q => (hv q).2) _ _⟩

theorem joinStringParts_captures {vs} (hv : ∀ p, Vals.Captures p vs) (op : OpPrim) (p : Nat → Prop) :
    Comp.Captures p (joinStringParts op vs) := by
  cases vs with
  | nil => simp [joinStringParts, Comp.Captures, Val.Captures]
  | cons v vs => exact joinStringFrom_captures (fun q => (hv q).1) (fun q => (hv q).2) op 0 p

theorem interpolate_captures (parts : List InterpPart) {vs hs acc}
    (hv : ∀ p, Vals.Captures p vs) (hh : ∀ h ∈ hs, ∀ p, CallHead.Captures p h)
    (ha : ∀ p, Vals.Captures p acc) (op : OpPrim) (p : Nat → Prop) :
    Comp.Captures p (interpolate op parts vs hs acc) := by
  induction parts generalizing vs hs acc p with
  | nil => exact joinStringParts_captures ha op p
  | cons part parts ih =>
      cases part with
      | text s =>
          simp only [interpolate]
          apply ih hv hh
          intro p; split
          · exact ha p
          · exact Vals.captures_append (ha p) ⟨trivial, trivial⟩
      | stringExpr =>
          cases vs with
          | nil => simp [interpolate, Comp.Captures, Val.Captures]
          | cons v vs =>
              exact ih (acc := acc ++ [v]) (fun q => (hv q).2) hh
                (fun q => Vals.captures_append (ha q) ⟨(hv q).1, trivial⟩) p
      | converted t =>
          cases vs with
          | nil => simp [interpolate, Comp.Captures, Val.Captures]
          | cons v vs =>
              cases hs with
              | nil => simp [interpolate, Comp.Captures, Val.Captures]
              | cons h hs =>
                  simp only [interpolate, Comp.Captures]
                  refine ⟨CallHead.captures_apply (hh h (by simp) p) ⟨(hv p).1, trivial⟩, ?_⟩
                  apply ih (Vals.captures_free_rename (fun q => (hv q).2))
                  · intro h hm q
                    obtain ⟨h', hm', rfl⟩ := List.mem_map.mp hm
                    exact CallHead.captures_free_rename (hh h' (by simp [hm'])) q
                  · intro q; exact Vals.captures_append (Vals.captures_free_rename ha q) ⟨trivial, trivial⟩

theorem directHeads_captures (fs : Exprs) :
    ∀ h ∈ directHeads fs, ∀ p, CallHead.Captures p h := by
  cases fs with
  | nil => simp [directHeads]
  | cons f fs =>
      intro h hm p
      simp only [directHeads, List.mem_cons] at hm
      rcases hm with rfl | hm
      · cases hd : directCallee f with
        | none => trivial
        | some h => simpa [hd] using directCallee_captures p hd
      · exact directHeads_captures fs h hm p

theorem BuilderPureRef.captures (r : BuilderPureRef) (p : Nat → Prop) :
    Val.Captures p r.toVal := by
  cases r <;> simp [BuilderPureRef.toVal, BuilderPrimRef.toVal, Val.Captures]

theorem builderFinish_captures (op : BuilderOp) (r : BuilderRefs) (i : Nat) {vs}
    (hv : ∀ p, Vals.Captures p vs) (p : Nat → Prop) :
    Comp.Captures p (builderFinish op i r vs) := by
  cases r <;> cases op <;> cases vs with
  | nil => simp [builderFinish, Comp.Captures, Val.Captures, Vals.Captures,
      BuilderRefs.cells, BuilderRefs.lengthRef, BuilderPrimRef.toVal, BuilderPureRef.captures]
  | cons v vs =>
      cases vs <;> simp only [builderFinish]
      all_goals first
        | (solve | simp [Comp.Captures, Val.Captures])
        | (simp only [builderCombine, Comp.Captures, Val.Captures, Vals.Captures,
            BuilderRefs.cells, BuilderPrimRef.toVal, Val.rename, BuilderPureRef.captures,
            true_and, and_true]
           exact Val.captures_free_rename (fun q => (hv q).1) _)

end Benitoite.Surface
