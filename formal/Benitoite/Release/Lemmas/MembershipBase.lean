import Benitoite.Release.Lemmas.Canonical
import Benitoite.Scope.RangeCover
import Benitoite.Release.RangeInst

/-!
# 値の所属の葉の規則（V-Checked）の逆転と範囲の拡大

設計書 01-12「型付け規則」の V-Checked について、逆転（`HasTypeVQ.checked_iff`）、範囲の拡大（意味の包含・被覆・
Top への拡大）、範囲付きの値型の閉じた値の標準形（`HasTypeVQ.canonical_opaque`）と閉じた値の範囲の拡大を置く。
拡大は葉の規則の補題に限り、関数の型・リストなどの内側へ範囲を広げる共変の規則は置かない（L20 の段末の確認
「非関数の共変なし」）。保存の証明（`E_OpPrim` の捕捉した引数の Top への拡大）が使うので、`Release/Lemmas/PresMain.lean`
より前に置く。旧の像での同値と小例は `Release/Lemmas/Membership.lean` にある。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins} {Q : NoFailCtx}

/-! ## 逆転と範囲の拡大 -/

/-- 検査済みの対象の値の型付けは、ちょうど V-Checked が与えるものである。 -/
theorem HasTypeVQ.checked_iff {Ψ C Γ t T} :
    HasTypeVQ P B Ψ Q C Γ (.checked t) T ↔
      ∃ o R, T = .opaque o (.fixed R) ∧ B.valKind o = some t.kind ∧ R.Mem t := by
  constructor
  · intro h; exact h.inv_checked rfl
  · rintro ⟨o, R, rfl, hk, hm⟩; exact .V_Checked hk hm

/-- 範囲の拡大（意味の包含）。所属の包含 `R ⊆ R'` のもとで、`O[R]` の検査済みの対象の値は `O[R']` を持つ。 -/
theorem HasTypeVQ.checked_widen {Ψ C Γ t o R R'}
    (h : HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaque o (.fixed R))) (hs : R.Sub R') :
    HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaque o (.fixed R')) := by
  obtain ⟨o', R0, hT, hk, hm⟩ := h.inv_checked rfl
  cases hT
  exact .V_Checked hk (hs t hm)

/-- 検査済みの要求の値の型付けは、ちょうど V-CheckedRequest が与えるものである。 -/
theorem HasTypeVQ.checkedRequest_iff {Ψ C Γ t c T} :
    HasTypeVQ P B Ψ Q C Γ (.checkedRequest t c) T ↔
      ∃ o R A, T = .opaque o (.fixed R) ∧ B.valKind o = some t.kind ∧ R.Mem t ∧ B.valContent o = some A ∧
        HasTypeVQ P B Ψ Qempty [] [] c A := by
  constructor
  · intro h; exact h.inv_checkedRequest rfl
  · rintro ⟨o, R, n, rfl, hk, hm, hc, ht⟩; exact .V_CheckedRequest hk hm hc ht

/-- 検査済みの要求の値の範囲の拡大（意味の包含）。保持する要求は変わらない。 -/
theorem HasTypeVQ.checkedRequest_widen {Ψ C Γ t c o R R'}
    (h : HasTypeVQ P B Ψ Q C Γ (.checkedRequest t c) (.opaque o (.fixed R))) (hs : R.Sub R') :
    HasTypeVQ P B Ψ Q C Γ (.checkedRequest t c) (.opaque o (.fixed R')) := by
  obtain ⟨o', R0, n, hT, hk, hm, hc, ht⟩ := h.inv_checkedRequest rfl
  cases hT
  exact .V_CheckedRequest hk (hs t hm) hc ht

/-- 範囲の拡大（被覆）。被覆の判定の健全性（`Range.Covers.sound`）から得る。 -/
theorem HasTypeVQ.checked_widen_covers {Ψ C Γ t o R R'}
    (h : HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaque o (.fixed R))) (hc : R'.Covers R) :
    HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaque o (.fixed R')) :=
  h.checked_widen hc.sound

/-- Top への拡大。検査済みの対象の値は、同じ名前の範囲が Top の不透明型を持つ。 -/
theorem HasTypeVQ.checked_widen_top {Ψ C Γ t o R}
    (h : HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaque o (.fixed R))) :
    HasTypeVQ P B Ψ Q C Γ (.checked t) (.opaqueTop o) :=
  h.checked_widen (Scope.Domain.Range.sub_top R)

/-! ## 閉じた値の標準形 -/

/-- 不透明型の閉じた値は、範囲が Top の型の不透明型の定数か、範囲付きの値型の検査済みの対象の値か、検査済みの
要求の値である。 -/
theorem HasTypeVQ.canonical_opaque {Ψ C v o ix} (h : HasTypeVQ P B Ψ Q C [] v (.opaque o ix)) :
    (∃ n, v = .const (.opaque o n) ∧ ix = .fixed .top) ∨
      (∃ t R, v = .checked t ∧ ix = .fixed R ∧ B.valKind o = some t.kind ∧ R.Mem t) ∨
      (∃ t R c n, v = .checkedRequest t c ∧ ix = .fixed R ∧ B.valKind o = some t.kind ∧ R.Mem t ∧
        B.valContent o = some n ∧ HasTypeVQ P B Ψ Qempty [] [] c n) := by
  have hnf : ∀ names ps r ε, (Ty.opaque o ix) ≠ .fn names ps r ε := by intros; simp
  cases v with
  | var i => obtain ⟨_, hi, _⟩ := h.inv_var rfl; simp at hi
  | const c =>
      have := (h.inv_const rfl).eq_of_not_fn hnf
      cases c <;> simp [Const.type] at this
      obtain ⟨rfl, rfl⟩ := this
      exact .inl ⟨_, rfl, rfl⟩
  | checked t =>
      obtain ⟨o', R, hT, hk, hm⟩ := h.inv_checked rfl
      cases hT
      exact .inr (.inl ⟨t, R, rfl, rfl, hk, hm⟩)
  | checkedRequest t c =>
      obtain ⟨o', R, n, hT, hk, hm, hc, ht⟩ := h.inv_checkedRequest rfl
      cases hT
      exact .inr (.inr ⟨t, R, c, n, rfl, rfl, hk, hm, hc, ht⟩)
  | fnRef f ts es =>
      obtain ⟨_, _, _, _, _, hle⟩ := h.inv_fnRef rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | prim b ts es rs =>
      obtain ⟨_, _, _, _, _, _, _, hle⟩ := h.inv_prim rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | op o ts =>
      obtain ⟨_, _, _, _, hle⟩ := h.inv_op rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | raise T E =>
      obtain ⟨_, _, hl⟩ := h.inv_raise rfl
      have := hl.eq_of_not_fn hnf; simp at this
  | lam names ps body =>
      obtain ⟨_, _, _, _, hle⟩ := h.inv_lam rfl
      have := hle.eq_of_not_fn hnf; simp at this
  | con c ts args => obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | list elems => obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'
  | mapV ks vs => obtain ⟨_, _, h'⟩ := h.inv_mapV rfl; simp at h'
  | setV _ => obtain ⟨_, h'⟩ := h.inv_setV rfl; simp at h'
  | bytesV _ => have h' := h.inv_bytesV rfl; simp at h'
  | dict _ _ _ => obtain ⟨_, _, _, _, h'⟩ := h.inv_dict rfl; simp at h'
  | super _ _ => obtain ⟨_, _, _, _, _, _, h'⟩ := h.inv_super rfl; simp at h'
  | loc l => rcases h.inv_loc rfl with ⟨_, _, h'⟩ | ⟨_, _, h'⟩ <;> simp at h'

/-- Top の範囲を含むのは Top だけである（種類の違う対象は非 Top の範囲に所属しない）。 -/
theorem _root_.Benitoite.Scope.Domain.Range.eq_top_of_top_sub {R : Scope.Domain.Range} (h : Scope.Domain.Range.top.Sub R) :
    R = .top := by
  cases R with
  | top => rfl
  | path _ => exact absurd (h (.host (.name [])) trivial) id
  | host _ => exact absurd (h (.path []) trivial) id
  | endpoint _ => exact absurd (h (.path []) trivial) id

/-- 閉じた値の範囲の拡大。拡大するのは最上位の不透明型の範囲だけである（葉の規則の補題）。 -/
theorem HasTypeVQ.widen_opaque {Ψ C v o R R'} (h : HasTypeVQ P B Ψ Q C [] v (.opaque o (.fixed R)))
    (hs : R.Sub R') : HasTypeVQ P B Ψ Q C [] v (.opaque o (.fixed R')) := by
  rcases h.canonical_opaque with ⟨n, rfl, hix⟩ | ⟨t, R0, rfl, hix, -, -⟩ | ⟨t, R0, c, n, rfl, hix, -⟩
  · cases hix
    rw [Scope.Domain.Range.eq_top_of_top_sub hs]
    exact h
  · exact h.checked_widen hs
  · exact h.checkedRequest_widen hs

/-- 閉じた値の Top への拡大（L20.5 の `E_OpPrim` が、捕捉した引数を Top の型へ広げるときに使う）。 -/
theorem HasTypeVQ.widen_opaque_top {Ψ C v o R} (h : HasTypeVQ P B Ψ Q C [] v (.opaque o (.fixed R))) :
    HasTypeVQ P B Ψ Q C [] v (.opaqueTop o) :=
  h.widen_opaque (Scope.Domain.Range.sub_top R)

/-! ## 捕捉した引数の Top への拡大（`E_OpPrim`） -/

/-- 不透明型は型代入で変わらない。 -/
theorem Ty.subst_opaque (ts : List Ty) (es : List Eff) (o : OpaqueName) (ix : Scope.Signature.Ix) :
    Ty.subst ts es (.opaque o ix) = .opaque o ix := by
  simp [Ty.subst, Ty.substAt]

/-- 一つの引数の拡大。引数の型を呼び出しの範囲の列で具体化した型の閉じた値は、Top の列で具体化した型を持つ。
具体化が変えるのは最上位の対象の位置だけなので、拡大は葉の値の補題（`widen_opaque_top`）で済む。 -/
theorem HasTypeVQ.widen_instTarget {Ψ C v ts es} {p : Ty} {rs : List Scope.Domain.Range} {n : Nat}
    (hn : rs.length = n)
    (hp : ∀ o ix, p = .opaque o ix → ix.WF n)
    (h : HasTypeVQ P B Ψ Q C [] v ((p.instTarget rs).subst ts es)) :
    HasTypeVQ P B Ψ Q C [] v ((p.instTarget (List.replicate n .top)).subst ts es) := by
  cases p with
  | «opaque» o ix =>
    simp only [Ty.instTarget, Ty.subst_opaque] at h ⊢
    cases ix with
    | fixed r => simpa [Scope.Signature.Ix.inst] using h
    | rvar i =>
      have hi : i < n := hp o (.rvar i) rfl
      have hi' : i < rs.length := hn ▸ hi
      simp only [Scope.Signature.Ix.inst, List.getElem?_eq_getElem hi'] at h
      simp only [Scope.Signature.Ix.inst, List.getElem?_replicate, hi, ite_true]
      exact h.widen_opaque_top
  | _ => simpa [Ty.instTarget] using h

/-- 組み込みの呼び出しの閉じた引数の列は、署名を Top の列で具体化した引数の型（節が使う操作の型）を持つ。 -/
theorem HasTypeVsQ.widen_topRanges {Ψ C ws ts es} {s : PrimSig} {rs : List Scope.Domain.Range}
    (hs : s.Scoped) (hn : rs.length = s.nranges)
    (h : HasTypeVsQ P B Ψ Q C [] ws ((s.inst rs).params.map (Ty.subst ts es))) :
    HasTypeVsQ P B Ψ Q C [] ws ((s.params.map (Ty.instTarget s.topRanges)).map (Ty.subst ts es)) := by
  have hwf : ∀ p ∈ s.params, ∀ o ix, p = .opaque o ix → ix.WF s.nranges := by
    intro p hp o ix he
    have := Ty.VarsInList.iff.mp hs.2.1 p hp
    subst he
    exact this
  rw [PrimSig.inst_params] at h
  generalize s.params = ps at h hwf
  induction ps generalizing ws with
  | nil => simpa using h
  | cons p ps ih =>
    cases h with
    | cons hv hvs =>
      exact .cons (hv.widen_instTarget hn (hwf p (List.mem_cons_self ..)))
        (ih hvs (fun q hq => hwf q (List.mem_cons_of_mem _ hq)))


/-! ## 捕捉した引数の、節の添字への拡大（`E_OpPrim`、L40.6c） -/

/-- 一つの引数の被覆による拡大。引数の型を呼び出しの範囲の列で具体化した型の閉じた値は、列の各範囲を覆う範囲 S の
列で具体化した型を持つ。具体化が変えるのは最上位の対象の位置だけなので、拡大は葉の値の補題（`widen_opaque`）と
被覆の健全性（`Range.Covers.sound`）で済む（判断 11 の、R への所属と R の S への被覆から S への所属を得る補題）。 -/
theorem HasTypeVQ.widen_instTarget_covers {Ψ C v ts es} {p : Ty} {rs : List Scope.Domain.Range}
    {S : Scope.Domain.Range} {n : Nat} (hn : rs.length = n)
    (hp : ∀ o ix, p = .opaque o ix → ix.WF n) (hcov : ∀ r ∈ rs, S.Covers r)
    (h : HasTypeVQ P B Ψ Q C [] v ((p.instTarget rs).subst ts es)) :
    HasTypeVQ P B Ψ Q C [] v ((p.instTarget (List.replicate n S)).subst ts es) := by
  cases p with
  | «opaque» o ix =>
    simp only [Ty.instTarget, Ty.subst_opaque] at h ⊢
    cases ix with
    | fixed r => simpa [Scope.Signature.Ix.inst] using h
    | rvar i =>
      have hi : i < n := hp o (.rvar i) rfl
      have hi' : i < rs.length := hn ▸ hi
      simp only [Scope.Signature.Ix.inst, List.getElem?_eq_getElem hi'] at h
      simp only [Scope.Signature.Ix.inst, List.getElem?_replicate, hi, ite_true]
      exact h.widen_opaque (hcov _ (List.getElem_mem hi')).sound
  | _ => simpa [Ty.instTarget] using h

/-- 組み込みの呼び出しの閉じた引数の列は、署名を、呼び出しの範囲の列の各範囲を覆う範囲 S の列で具体化した引数の型
（節の添字 S で選んだ操作の型）を持つ。 -/
theorem HasTypeVsQ.widen_covers {Ψ C ws ts es} {s : PrimSig} {rs : List Scope.Domain.Range}
    {S : Scope.Domain.Range}
    (hs : s.Scoped) (hn : rs.length = s.nranges) (hcov : ∀ r ∈ rs, S.Covers r)
    (h : HasTypeVsQ P B Ψ Q C [] ws ((s.inst rs).params.map (Ty.subst ts es))) :
    HasTypeVsQ P B Ψ Q C [] ws ((s.params.map (Ty.instTarget (List.replicate s.nranges S))).map (Ty.subst ts es)) := by
  have hwf : ∀ p ∈ s.params, ∀ o ix, p = .opaque o ix → ix.WF s.nranges := by
    intro p hp o ix he
    have := Ty.VarsInList.iff.mp hs.2.1 p hp
    subst he
    exact this
  rw [PrimSig.inst_params] at h
  generalize s.params = ps at h hwf
  induction ps generalizing ws with
  | nil => simpa using h
  | cons p ps ih =>
    cases h with
    | cons hv hvs =>
      exact .cons (hv.widen_instTarget_covers hn (hwf p (List.mem_cons_self ..)) hcov)
        (ih hvs (fun q hq => hwf q (List.mem_cons_of_mem _ hq)))

end Benitoite.Release
