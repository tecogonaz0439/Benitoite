import Benitoite.Release.Refinement.AtPatternText

/-! # At の pattern と対象の起点の違い

解析できた単一の pattern と At の対象の起点が両方とも確定して違うかを判定し、全ての有効な起点の値での不所属と
区別する（設計書 01-07「閉じた範囲引数」）。

- 判定 `PathBasesDiffer` は起点だけを読む。Top・絶対形・`{secrets}` の pattern と絶対形の対象は起点を持たず、
  判定の外にある。
- 起点が違うことは不所属を意味しない。木の pattern では、ある有効な起点の値で対象が所属し、別の有効な起点の値で
  所属しない（`PathBasesDiffer.tree_not_outside`・`PathBasesDiffer.exists_outside`）。一つの起点の値で観測した
  不所属は、全ての起点の値での不所属の根拠にならない。
- 全ての有効な起点の値で所属しないこと `OutsideAllEnvs` は、起点からの pattern と対象について、起点と要素の列だけで
  決まる（`outsideAllEnvs_based_iff`）。成り立つときは、どの有効な起点の値と上限でも At が成功せず
  （`OutsideAllEnvs.checkAt_not_ok`）、対象の解決先が正規で成り立たないときは、ある有効な起点の値で Top を上限にした
  At が成功する（`checkAt_ok_of_not_outside`）。二つを合わせ、全ての有効な起点の値での不所属は、Top を上限にした At が
  全ての有効な起点の値で成功しないことと同値である（`outsideAllEnvs_iff_checkAt`）。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

/-- pattern と対象の起点が両方とも確定し、違う。 -/
def PathBasesDiffer (p : RangeExpr) (t : TargetInput) : Prop :=
  match p.base?, t.base? with
  | some b, some c => b ≠ c
  | _, _ => False

instance (p : RangeExpr) (t : TargetInput) : Decidable (PathBasesDiffer p t) := by
  unfold PathBasesDiffer
  cases p.base? <;> cases t.base? <;> infer_instance

/-- 全ての有効な起点の値で、対象の解決先が pattern に所属しない。 -/
def OutsideAllEnvs (p : RangeExpr) (t : TargetInput) : Prop :=
  ∀ σ : PathEnv, σ.Valid → ∀ target, t.resolve σ = some target → ¬ p.Mem σ .path target

/-- 起点からの対象の起点と要素の列。絶対形の対象は持たない。 -/
def TargetInput.basedPath? : TargetInput → Option (PathBase × Word)
  | .relativePath w => some (.cwd, w)
  | .homePath w => some (.home, w)
  | .absolute _ => none

/-- 対象の起点は、起点からの対象の起点と要素の列の起点である。 -/
theorem TargetInput.base?_eq_basedPath? (t : TargetInput) : t.base? = t.basedPath?.map Prod.fst := by
  cases t <;> rfl

/-- 判定が成り立つのは、起点からの pattern と起点からの対象の組だけである。 -/
theorem PathBasesDiffer.based {p : RangeExpr} {t : TargetInput} (h : PathBasesDiffer p t) :
    ∃ b pat c w, p = .based b pat ∧ t.basedPath? = some (c, w) ∧ b ≠ c := by
  unfold PathBasesDiffer at h
  rcases p with _ | ⟨b, pat⟩ | _ <;> rcases t with _ | w | w <;>
    simp only [RangeExpr.base?, TargetInput.base?] at h
  · exact ⟨b, pat, .cwd, w, rfl, rfl, h⟩
  · exact ⟨b, pat, .home, w, rfl, rfl, h⟩

/-- 起点からの対象の解決先は、起点の値がその起点に置く列へ要素の列を付けたパスである。 -/
theorem TargetInput.resolve_of_basedPath? {t : TargetInput} {c : PathBase} {w : Word}
    (ht : t.basedPath? = some (c, w)) (σ : PathEnv) :
    t.resolve σ = (σ.lookup c).map (fun X => .path (X ++ w)) := by
  rcases t with _ | w' | w' <;> simp only [TargetInput.basedPath?, Option.some.injEq, Prod.mk.injEq] at ht <;>
    obtain ⟨rfl, rfl⟩ := ht <;> rfl

private theorem matches_atBase (X : Word) (pat : PathPattern) (u : Word) :
    (PathPattern.atBase X pat).Matches u ↔
      match pat with
      | .exact s => u = X ++ s
      | .tree s => ∃ rest, u = X ++ s ++ rest := by
  cases pat <;> simp [PathPattern.atBase, PathPattern.Matches, List.append_assoc]

private theorem mem_based (σ : PathEnv) (b : PathBase) (pat : PathPattern) (u : Word) :
    (RangeExpr.based b pat).Mem σ .path (.path u) ↔
      ∃ X, σ.lookup b = some X ∧ (PathPattern.atBase X pat).Matches u := by
  simp only [RangeExpr.Mem, RangeExpr.resolve, Target.kind, true_and]
  cases σ.lookup b <;> simp [Range.Mem]

/-- 一つの起点へ値を置いた起点の値。 -/
private def PathEnv.set (σ : PathEnv) : PathBase → Word → PathEnv
  | .root, w => { σ with root := w }
  | .cwd, w => { σ with cwd := w }
  | .home, w => { σ with home := w }
  | .work, w => { σ with work := some w }
  | .tmp, w => { σ with tmp := some w }

private theorem PathEnv.lookup_set_self (σ : PathEnv) (b : PathBase) (w : Word) :
    (σ.set b w).lookup b = some w := by
  cases b <;> rfl

private theorem PathEnv.lookup_set_ne (σ : PathEnv) {b c : PathBase} (h : b ≠ c) (w : Word) :
    (σ.set b w).lookup c = σ.lookup c := by
  cases b <;> cases c <;> first | exact (h rfl).elim | rfl

private theorem PathEnv.valid_set {σ : PathEnv} (hσ : σ.Valid) (b : PathBase) {w : Word}
    (hw : PathWordWF w) : (σ.set b w).Valid := by
  obtain ⟨hr, hc, hh, hwk, ht, hs⟩ := hσ
  cases b
  · exact ⟨hw, hc, hh, hwk, ht, hs⟩
  · exact ⟨hr, hw, hh, hwk, ht, hs⟩
  · exact ⟨hr, hc, hw, hwk, ht, hs⟩
  · exact ⟨hr, hc, hh, by simpa [PathEnv.set] using hw, ht, hs⟩
  · exact ⟨hr, hc, hh, hwk, by simpa [PathEnv.set] using hw, hs⟩

/-- 全ての起点を根（空の列）に束縛し、secrets を持たない有効な起点の値。 -/
private def PathEnv.rootAll : PathEnv := ⟨[], [], [], some [], some [], none⟩

private theorem PathEnv.rootAll_valid : PathEnv.rootAll.Valid := by decide

private theorem PathEnv.rootAll_lookup (b : PathBase) : PathEnv.rootAll.lookup b = some [] := by
  cases b <;> rfl

/-- 二つの起点へ値を置いた有効な起点の値。起点が違えば、両方の値がそのまま読める。 -/
private theorem PathEnv.exists_pair {b c : PathBase} (h : b ≠ c) {X Y : Word}
    (hX : PathWordWF X) (hY : PathWordWF Y) :
    ∃ σ : PathEnv, σ.Valid ∧ σ.lookup b = some X ∧ σ.lookup c = some Y :=
  ⟨(PathEnv.rootAll.set c Y).set b X,
    PathEnv.valid_set (PathEnv.valid_set PathEnv.rootAll_valid c hY) b hX,
    PathEnv.lookup_set_self _ _ _,
    by rw [PathEnv.lookup_set_ne _ h, PathEnv.lookup_set_self]⟩

private theorem wordWF_of_sublist {u w : Word} (h : u.Sublist w) (hw : PathWordWF w) : PathWordWF u :=
  fun s hs => hw s (h.subset hs)

private theorem wordWF_append {u w : Word} (hu : PathWordWF u) (hw : PathWordWF w) : PathWordWF (u ++ w) := by
  intro s hs
  rcases List.mem_append.mp hs with hs | hs
  · exact hu s hs
  · exact hw s hs

/-- 起点からの pattern と対象の、全ての有効な起点の値での不所属は、起点と要素の列で決まる。同じ起点なら
pattern が要素の列に所属しないこと、違う起点なら完全一致の pattern で、要素の列と幹のどちらも他方の接尾辞で
ないことである。起点が違う木の pattern は、全ての起点の値で不所属にならない。 -/
theorem outsideAllEnvs_based_iff {b c : PathBase} {pat : PathPattern} {t : TargetInput} {w : Word}
    (hpat : pat.WF) (hw : PathWordWF w) (ht : t.basedPath? = some (c, w)) :
    OutsideAllEnvs (.based b pat) t ↔
      if b = c then ¬ pat.Matches w else ∃ s, pat = .exact s ∧ ¬ (s <:+ w ∨ w <:+ s) := by
  have hs : ∀ s, pat = .exact s ∨ pat = .tree s → PathWordWF s := by
    rintro s (rfl | rfl) <;> exact hpat.1
  unfold OutsideAllEnvs
  simp only [TargetInput.resolve_of_basedPath? ht]
  constructor
  · intro hout
    split
    · rename_i hbc
      subst hbc
      intro hm
      refine hout PathEnv.rootAll PathEnv.rootAll_valid _ (by rw [PathEnv.rootAll_lookup]; rfl) ?_
      refine (mem_based _ _ _ _).mpr ⟨[], PathEnv.rootAll_lookup b, ?_⟩
      cases pat <;> simpa [PathPattern.atBase, PathPattern.Matches] using hm
    · rename_i hbc
      cases pat with
      | tree s =>
        exfalso
        obtain ⟨σ, hσ, hb, hc⟩ := PathEnv.exists_pair hbc (X := []) (Y := s) (fun _ h => nomatch h)
          (hs s (.inr rfl))
        refine hout σ hσ _ (by rw [hc]; rfl) ((mem_based _ _ _ _).mpr ⟨[], hb, ?_⟩)
        exact ⟨w, by simp⟩
      | exact s =>
        refine ⟨s, rfl, ?_⟩
        rintro (⟨u, rfl⟩ | ⟨u, rfl⟩)
        · obtain ⟨σ, hσ, hb, hc⟩ := PathEnv.exists_pair hbc (X := u) (Y := [])
            (wordWF_of_sublist (List.sublist_append_left u s) hw) (fun _ h => nomatch h)
          exact hout σ hσ _ (by rw [hc]; rfl) ((mem_based _ _ _ _).mpr ⟨u, hb, by simp [PathPattern.atBase,
            PathPattern.Matches]⟩)
        · obtain ⟨σ, hσ, hb, hc⟩ := PathEnv.exists_pair hbc (X := []) (Y := u) (fun _ h => nomatch h)
            (wordWF_of_sublist (List.sublist_append_left u w) (hs _ (.inl rfl)))
          exact hout σ hσ _ (by rw [hc]; rfl) ((mem_based _ _ _ _).mpr ⟨[], hb, by simp [PathPattern.atBase,
            PathPattern.Matches]⟩)
  · intro hcond σ _ target htarget hm
    obtain ⟨Y, hY, rfl⟩ := Option.map_eq_some_iff.mp htarget
    obtain ⟨X, hX, hmatch⟩ := (mem_based _ _ _ _).mp hm
    rw [matches_atBase] at hmatch
    split at hcond
    · rename_i hbc
      subst hbc
      have hXY : X = Y := Option.some.inj (hX.symm.trans hY)
      subst hXY
      apply hcond
      cases pat with
      | exact s => exact List.append_cancel_left hmatch
      | tree s =>
        obtain ⟨rest, hr⟩ := hmatch
        exact ⟨rest, List.append_cancel_left (as := X) (by rw [hr, List.append_assoc])⟩
    · obtain ⟨s, rfl, hns⟩ := hcond
      apply hns
      exact List.suffix_or_suffix_of_suffix (l₃ := Y ++ w) (by rw [hmatch]; exact List.suffix_append _ _)
        (List.suffix_append _ _)

/-- 起点が違う木の pattern は、全ての有効な起点の値で不所属にならない（起点の違いだけを所属不良の根拠にしない）。 -/
theorem PathBasesDiffer.tree_not_outside {b : PathBase} {s : Word} {t : TargetInput} {c : PathBase} {w : Word}
    (hpat : (PathPattern.tree s).WF) (hw : PathWordWF w) (ht : t.basedPath? = some (c, w))
    (h : PathBasesDiffer (.based b (.tree s)) t) : ¬ OutsideAllEnvs (.based b (.tree s)) t := by
  have hbc : b ≠ c := by
    simpa [PathBasesDiffer, RangeExpr.base?, TargetInput.base?_eq_basedPath?, ht] using h
  rw [outsideAllEnvs_based_iff hpat hw ht]
  simp only [hbc, ↓reduceIte]
  rintro ⟨_, he, _⟩
  cases he

/-- 起点が違えば、どの pattern と対象でも、対象が所属しない有効な起点の値がある。一つの起点の値で観測した不所属は
全ての起点の値での不所属を示さない。 -/
theorem PathBasesDiffer.exists_outside {p : RangeExpr} {t : TargetInput} (h : PathBasesDiffer p t) :
    ∃ σ : PathEnv, σ.Valid ∧ ∃ target, t.resolve σ = some target ∧ ¬ p.Mem σ .path target := by
  obtain ⟨b, pat, c, w, rfl, ht, hbc⟩ := h.based
  obtain ⟨σ, hσ, hb, hc⟩ := PathEnv.exists_pair hbc (X := ["a"]) (Y := ["b"]) (by decide) (by decide)
  refine ⟨σ, hσ, _, by rw [TargetInput.resolve_of_basedPath? ht, hc]; rfl, ?_⟩
  intro hm
  obtain ⟨X, hX, hmatch⟩ := (mem_based _ _ _ _).mp hm
  rw [hb] at hX
  cases hX
  rw [matches_atBase] at hmatch
  cases pat with
  | exact s => simp at hmatch
  | tree s =>
    obtain ⟨_, hr⟩ := hmatch
    simp at hr

private theorem resolveSnapshot_some (σ : PathEnv) (p : RangeExpr) :
    resolveSnapshot (some σ) p = p.resolve σ := by
  cases p <;> rfl

private theorem resolveTargetSnapshot_some (σ : PathEnv) (t : TargetInput) :
    resolveTargetSnapshot (some σ) t = t.resolve σ := by
  cases t <;> rfl

/-- 成功した At の対象は、同じ起点の値での対象の解決先であり、pattern に所属する。 -/
theorem checkAt_ok_mem {σ : PathEnv} {k : Kind} {p : RangeExpr} {input : TargetInput} {bound : RangeExpr}
    {target : Target} (h : checkAt (some σ) k p input bound = .ok target) :
    input.resolve σ = some target ∧ p.Mem σ k target := by
  unfold checkAt at h
  split at h
  · cases h
  · cases h
  · cases h
  · rename_i ps t bs hp ht _
    split at h
    · cases h
    · split at h
      · cases h
      · split at h
        · cases h
        · split at h
          · cases h
          · rename_i hk _ hmem _
            cases h
            have hres : p.resolve σ = some ps := by rw [← resolveSnapshot_some]; exact hp
            have htr : input.resolve σ = some target := by rw [← resolveTargetSnapshot_some]; exact ht
            refine ⟨htr, ?_, ?_⟩
            · exact (not_or.mp hk).2 |> Classical.not_not.mp
            · simpa [hres] using Classical.not_not.mp hmem

/-- 全ての有効な起点の値で不所属なら、どの有効な起点の値と上限でも At は成功しない。 -/
theorem OutsideAllEnvs.checkAt_not_ok {p : RangeExpr} {t : TargetInput} (h : OutsideAllEnvs p t)
    {σ : PathEnv} (hσ : σ.Valid) (bound : RangeExpr) (target : Target) :
    checkAt (some σ) .path p t bound ≠ .ok target := by
  intro hc
  obtain ⟨ht, hm⟩ := checkAt_ok_mem hc
  exact h σ hσ target ht hm

/-- 起点からの対象の解決先は、有効な起点の値と正規の要素の列で正規のパスである。 -/
theorem TargetInput.resolve_wf_of_basedPath? {t : TargetInput} {c : PathBase} {w : Word}
    (ht : t.basedPath? = some (c, w)) (hw : PathWordWF w) {σ : PathEnv} (hσ : σ.Valid) {target : Target}
    (htarget : t.resolve σ = some target) : target.WF := by
  rw [TargetInput.resolve_of_basedPath? ht] at htarget
  obtain ⟨Y, hY, rfl⟩ := Option.map_eq_some_iff.mp htarget
  obtain ⟨hr, hc, hh, hwk, htp, _⟩ := hσ
  have hYw : PathWordWF Y := by
    cases c <;> simp only [PathEnv.lookup, Option.some.injEq] at hY
    · subst hY; exact hr
    · subst hY; exact hc
    · subst hY; exact hh
    · exact hwk Y hY
    · exact htp Y hY
  exact wordWF_append hYw hw

/-- 全ての有効な起点の値での不所属が成り立たず、対象の解決先が正規なら、ある有効な起点の値で、Top を上限にした At
が成功する。 -/
theorem checkAt_ok_of_not_outside {p : RangeExpr} {t : TargetInput} (hp : p.WF) (hk : p.FitsKind .path)
    (htw : ∀ σ : PathEnv, σ.Valid → ∀ target, t.resolve σ = some target → target.WF)
    (h : ¬ OutsideAllEnvs p t) :
    ∃ σ : PathEnv, σ.Valid ∧ ∃ target, checkAt (some σ) .path p t (.absolute .top) = .ok target := by
  obtain ⟨σ, hσ, target, htarget, hm⟩ :
      ∃ σ : PathEnv, σ.Valid ∧ ∃ target, t.resolve σ = some target ∧ p.Mem σ .path target := by
    exact Classical.byContradiction fun hne => h fun σ hσ target ht hm => hne ⟨σ, hσ, target, ht, hm⟩
  refine ⟨σ, hσ, target, ?_⟩
  have hw := htw σ hσ target htarget
  cases hps : p.resolve σ with
  | none => simp [RangeExpr.Mem, hps] at hm
  | some ps =>
    have hmem : ∃ q ∈ ps, q.Mem target := by simpa [RangeExpr.Mem, hps] using hm.2
    have hbw : (RangeExpr.absolute Range.top).WF := trivial
    have hbk : (RangeExpr.absolute Range.top).FitsKind .path := Range.top_fitsKind _
    unfold checkAt
    rw [resolveSnapshot_some, hps, resolveTargetSnapshot_some, htarget]
    simp [resolveSnapshot, hw, hm.1, hp, hk, hbw, hbk, hmem]

/-- 整形式で種類 path の pattern と、解決先が正規の対象について、全ての有効な起点の値での不所属は、Top を上限にした
At が全ての有効な起点の値で成功しないことと同値である。 -/
theorem outsideAllEnvs_iff_checkAt {p : RangeExpr} {t : TargetInput} (hp : p.WF) (hk : p.FitsKind .path)
    (htw : ∀ σ : PathEnv, σ.Valid → ∀ target, t.resolve σ = some target → target.WF) :
    OutsideAllEnvs p t ↔
      ∀ σ : PathEnv, σ.Valid → ∀ target, checkAt (some σ) .path p t (.absolute .top) ≠ .ok target := by
  constructor
  · exact fun h σ hσ => h.checkAt_not_ok hσ _
  · intro h
    exact Classical.byContradiction fun hn => by
      obtain ⟨σ, hσ, target, hc⟩ := checkAt_ok_of_not_outside hp hk htw hn
      exact h σ hσ target hc

/-- 裸の相対形の pattern `data/**` は root から、対象 `data/in.txt` は cwd からであり、起点が違う。木の pattern なので
全ての起点の値での不所属にならず、root と cwd が同じ有効な起点の値では At が成功し、違う起点の値では所属しない。 -/
example : parsePatternText .path "data/**" = some (.based .root (.tree ["data"])) ∧
    parseAtInput .path (.const (.string "data/in.txt")) = some (.relativePath ["data", "in.txt"]) ∧
    PathBasesDiffer (.based .root (.tree ["data"])) (.relativePath ["data", "in.txt"]) ∧
    ¬ OutsideAllEnvs (.based .root (.tree ["data"])) (.relativePath ["data", "in.txt"]) ∧
    (∃ σ : PathEnv, σ.Valid ∧ ∃ target,
      checkAt (some σ) .path (.based .root (.tree ["data"])) (.relativePath ["data", "in.txt"])
        (.absolute .top) = .ok target) ∧
    ∃ σ : PathEnv, σ.Valid ∧ ∃ target, (TargetInput.relativePath ["data", "in.txt"]).resolve σ = some target ∧
      ¬ (RangeExpr.based .root (.tree ["data"])).Mem σ .path target := by
  have hd : PathBasesDiffer (.based .root (.tree ["data"])) (.relativePath ["data", "in.txt"]) := by decide
  have hn := hd.tree_not_outside (by decide) (by decide) rfl
  exact ⟨by decide +kernel, by decide +kernel, hd, hn,
    checkAt_ok_of_not_outside (by decide) (by decide)
      (fun _ hσ _ ht => TargetInput.resolve_wf_of_basedPath? rfl (by decide) hσ ht) hn, hd.exists_outside⟩

/-- 同じ起点の `{cwd}/a` と `./b` は起点が違わないが、全ての有効な起点の値で不所属であり、At は成功しない。
起点が違う完全一致の `~/notes` と `data/a` は、どちらも他方の接尾辞でないので、全ての起点の値で不所属であり、Top を
上限にした At は全ての有効な起点の値で成功しない。 -/
example (σ : PathEnv) (hσ : σ.Valid) (bound : RangeExpr) (target : Target) :
    ¬ PathBasesDiffer (.based .cwd (.exact ["a"])) (.relativePath ["b"]) ∧
    checkAt (some σ) .path (.based .cwd (.exact ["a"])) (.relativePath ["b"]) bound ≠ .ok target ∧
    PathBasesDiffer (.based .home (.exact ["notes"])) (.relativePath ["data", "a"]) ∧
    ∀ σ : PathEnv, σ.Valid → ∀ target,
      checkAt (some σ) .path (.based .home (.exact ["notes"])) (.relativePath ["data", "a"]) (.absolute .top) ≠
        .ok target := by
  have h₁ : OutsideAllEnvs (.based .cwd (.exact ["a"])) (.relativePath ["b"]) :=
    (outsideAllEnvs_based_iff (c := .cwd) (w := ["b"]) (by decide) (by decide) rfl).mpr
      (show ¬ (PathPattern.exact ["a"]).Matches ["b"] by decide)
  have h₂ : OutsideAllEnvs (.based .home (.exact ["notes"])) (.relativePath ["data", "a"]) :=
    (outsideAllEnvs_based_iff (c := .cwd) (w := ["data", "a"]) (by decide) (by decide) rfl).mpr
      (show ∃ s, PathPattern.exact ["notes"] = .exact s ∧ ¬ (s <:+ ["data", "a"] ∨ ["data", "a"] <:+ s) from
        ⟨_, rfl, by decide⟩)
  refine ⟨by decide, h₁.checkAt_not_ok hσ bound target, by decide, ?_⟩
  exact (outsideAllEnvs_iff_checkAt (by decide) (by decide)
    (fun _ hσ _ ht => TargetInput.resolve_wf_of_basedPath? rfl (by decide) hσ ht)).mp h₂

end Benitoite.Release.Refinement
