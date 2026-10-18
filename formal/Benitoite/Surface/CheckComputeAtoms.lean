import Benitoite.Surface.CheckLemmas

/-! strict・relaxedの両方で使う計算の支持保存。
型付けの成功とは分け、継続の要求も再帰的な支持に含める。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

/-- 要求の番号とstrictContsは支持に関係せず、要求した効果の内部を追跡する。 -/
def Requests.AtomsIn (atoms : List Atom) (requests : Requests) : Prop :=
  ∀ r ∈ requests, r.2.AtomsIn atoms

def CheckState.AtomsIn (atoms : List Atom) (s : CheckState) : Prop :=
  Requests.AtomsIn atoms s.requests

/-- 任意の初期状態にある要求の支持を保存する計算の契約。 -/
def ComputesIn (q : Input) (P : α → Prop) (x : Checking α) : Prop :=
  ∀ s s' a, s.AtomsIn q.atoms → x s = .ok (a, s') → P a ∧ s'.AtomsIn q.atoms

abbrev Inferred.AtomsIn (atoms : List Atom) (a : Inferred) :=
  a.1.AtomsIn atoms ∧ a.2.AtomsIn atoms

theorem computes_pure {q : Input} {P : α → Prop} {a : α} (ha : P a) :
    ComputesIn q P (pure a) := by
  intro s s' b hs h
  obtain ⟨rfl, rfl⟩ := checking_pure_ok h
  exact ⟨ha, hs⟩

theorem computes_throw {q : Input} {P : α → Prop} {e : Error} :
    ComputesIn q P (throw e) := by
  intro s s' a hs h
  contradiction

theorem computes_bind {q : Input} {P : α → Prop} {Q : β → Prop}
    {x : Checking α} {f : α → Checking β} (hx : ComputesIn q P x)
    (hf : ∀ a, P a → ComputesIn q Q (f a)) : ComputesIn q Q (x >>= f) := by
  intro s s' b hs h
  obtain ⟨a, mid, ha, hb⟩ := checking_bind_ok h
  obtain ⟨hpa, hmid⟩ := hx _ _ _ hs ha
  exact hf a hpa _ _ _ hmid hb

theorem computes_lift {q : Input} {P : α → Prop} {x : Result α}
    (hx : ∀ a, x = .ok a → P a) : ComputesIn q P (StateT.lift x) := by
  intro s s' a hs h
  obtain ⟨ha, rfl⟩ := checking_lift_ok h
  exact ⟨hx a ha, hs⟩

/-- 純粋な検査の成功の式を残し、参照した宣言などの支持を取り出す。 -/
theorem computes_lift_bind {q : Input} {P : β → Prop} {x : Result α} {f : α → Checking β}
    (hf : ∀ a, x = .ok a → ComputesIn q P (f a)) :
    ComputesIn q P ((StateT.lift x) >>= f) := by
  intro s s' b hs h
  obtain ⟨a, hx, hf'⟩ := checking_lift_bind_ok h
  exact hf a hx _ _ _ hs hf'

theorem computes_accept_bind {q : Input} {P : α → Prop} {x : Checking Inferred}
    {n path expected} {f : Eff → Checking α}
    (hx : ComputesIn q (Inferred.AtomsIn q.atoms) x)
    (hf : ∀ ε, ε.AtomsIn q.atoms → ComputesIn q P (f ε)) :
    ComputesIn q P (do let ε ← accept q n path expected (← x); f ε) := by
  apply computes_bind hx
  intro actual ha
  apply computes_lift_bind
  intro ε hε
  rw [(accept_ok hε).2]
  exact hf actual.2 ha.2

theorem computes_get {q : Input} :
    ComputesIn q (CheckState.AtomsIn q.atoms) get := by
  intro s s' a hs h
  have he : (s, s) = (a, s') := Except.ok.inj h
  cases he
  exact ⟨hs, hs⟩

theorem computes_modify {q : Input} {f : CheckState → CheckState}
    (hf : ∀ s, s.AtomsIn q.atoms → (f s).AtomsIn q.atoms) :
    ComputesIn q (fun _ => True) (modify f) := by
  intro s s' a hs h
  have he : ((), f s) = (a, s') := Except.ok.inj h
  cases he
  exact ⟨trivial, hf s hs⟩

theorem computes_guard {q : Input} {path inputOK x} (hx : ComputesIn q (Inferred.AtomsIn q.atoms) x) :
    ComputesIn q (Inferred.AtomsIn q.atoms) (guardInferred q path x inputOK) := by
  intro s s' a hs h
  exact hx _ _ _ hs (guardInferred_ok h)

/-- 独立の探索は空の要求から始め、結果の状態ごと外側へ返す。 -/
theorem computes_run_empty {q : Input} {P : α → Prop} {x : Checking α}
    (hx : ComputesIn q P x) :
    ComputesIn q (fun v : α × CheckState => P v.1 ∧ v.2.AtomsIn q.atoms) (StateT.lift (x.run {})) := by
  apply computes_lift
  intro v hv
  exact hx {} v.2 v.1 (fun r hr => by cases hr) hv

/-- 効果の反復はstepが結果と要求を保存するとき、任意の燃料で支持を保つ。 -/
theorem fixedEffectsR_computes {q path step}
    (hstep : ∀ e, e.AtomsIn q.atoms → ComputesIn q (Eff.AtomsIn q.atoms) (step e))
    (n : Nat) {ε : Eff} (hε : ε.AtomsIn q.atoms) :
    ComputesIn q (Eff.AtomsIn q.atoms) (fixedEffectsR q path step n ε) := by
  induction n generalizing ε with
  | zero => exact computes_throw
  | succ n ih =>
    apply computes_bind (hstep ε hε)
    intro next hn
    dsimp only
    split
    · exact computes_pure hε
    · exact ih (union_atoms hε hn)

theorem requests_atoms_nil (atoms : List Atom) : Requests.AtomsIn atoms [] := by
  intro r hr; cases hr

theorem requests_atoms_cons {atoms r rs} (hr : r.2.AtomsIn atoms) (hs : Requests.AtomsIn atoms rs) :
    Requests.AtomsIn atoms (r :: rs) := by
  intro x hx
  rcases List.mem_cons.mp hx with rfl | hx
  · exact hr
  · exact hs x hx

theorem requests_atoms_append {atoms rs ss} (hr : Requests.AtomsIn atoms rs)
    (hs : Requests.AtomsIn atoms ss) : Requests.AtomsIn atoms (rs ++ ss) := by
  intro x hx
  rcases List.mem_append.mp hx with hx | hx
  · exact hr x hx
  · exact hs x hx

theorem requests_atoms_filter {atoms rs} (hr : Requests.AtomsIn atoms rs) (p : Nat × Eff → Bool) :
    Requests.AtomsIn atoms (rs.filter p) := by
  intro x hx
  exact hr x ((List.mem_filter.mp hx).1)

mutual
  /-- 辞書の計算は探索モードと独立であり、型付けの証明なしで支持を得る。 -/
  theorem checkDict_atoms {q : Input} (d : DictEv) {C Γ path a}
      (hq : q.Sound) (hd : d.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
      (h : checkDict q C Γ path d = .ok a) : a.AtomsIn q.atoms := by
    cases d with
    | «local» j =>
      have h := guardResult_ok h
      obtain ⟨t, ht, h⟩ := bind_ok h
      obtain ⟨v, hv, h⟩ := bind_ok h
      cases Except.ok.inj h
      exact Env.atoms_get hΓ (lookup_local_ok ht)
    | clause scope i depth =>
      have h := guardResult_ok h
      obtain ⟨u, hu, h⟩ := bind_ok h
      obtain ⟨t, ht, h⟩ := bind_ok h
      obtain ⟨v, hv, h⟩ := bind_ok h
      cases Except.ok.inj h
      exact Env.atoms_get hΓ (lookup_local_ok ht)
    | impl i ts ds =>
      have h := guardResult_ok h
      obtain ⟨id, hi, h⟩ := bind_ok h
      obtain ⟨u, hu, h⟩ := bind_ok h
      obtain ⟨v, hv, h⟩ := bind_ok h
      cases Except.ok.inj h
      exact substTy_atoms (hq.declarations.2.2.2.2 i id (lookup_ok hi)).1 hd.1 (by simp)
    | super d sup =>
      have h := guardResult_ok h
      obtain ⟨t, ht, h⟩ := bind_ok h
      obtain ⟨⟨cl, τ⟩, hv, h⟩ := bind_ok h
      obtain ⟨cd, hc, h⟩ := bind_ok h
      obtain ⟨u, hu, h⟩ := bind_ok h
      cases Except.ok.inj h
      have hs := checkDict_atoms d hq hd hΓ ht
      have he := dictView_ok hv
      subst t
      exact hs
  termination_by sizeOf d
end


def ExprComputes (q : Input) (e : Expr) : Prop :=
  ∀ mode C Γ R p path, q.Sound → e.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → ComputesIn q (Inferred.AtomsIn q.atoms) (checkExprR q mode C Γ R p path e)

def BlockComputes (q : Input) (b : Block) : Prop :=
  ∀ mode C Γ R p path, q.Sound → b.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → ComputesIn q (Inferred.AtomsIn q.atoms) (checkBlockR q mode C Γ R p path b)

def TypesComputes (q : Input) (es : Exprs) : Prop :=
  ∀ mode C Γ R path index ts, q.Sound → es.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → Tys.AtomsIn q.atoms ts →
    ComputesIn q (Eff.AtomsIn q.atoms) (checkTypesR q mode C Γ R path index es ts)

def EachComputes (q : Input) (es : Exprs) : Prop :=
  ∀ mode C Γ R path index a, q.Sound → es.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → a.AtomsIn q.atoms →
    ComputesIn q (Eff.AtomsIn q.atoms) (checkEachR q mode C Γ R path index es a)

def HolesComputes (q : Input) (args : HoleArgs) : Prop :=
  ∀ mode C Γ R path index ts, q.Sound → args.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → Tys.AtomsIn q.atoms ts →
    ComputesIn q (Eff.AtomsIn q.atoms) (checkHoleArgsR q mode C Γ R path index args ts)

def ArmsComputes (q : Input) (arms : Arms) : Prop :=
  ∀ mode C Γ R p path a b, q.Sound → arms.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → a.AtomsIn q.atoms → b.AtomsIn q.atoms →
    ComputesIn q (Eff.AtomsIn q.atoms) (checkArmsR q mode C Γ R p path arms a b)

def ClausesComputes (q : Input) (cs : Clauses) : Prop :=
  ∀ mode C Γ R path t ε, q.Sound → cs.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → t.AtomsIn q.atoms → ε.AtomsIn q.atoms →
    ComputesIn q (Eff.AtomsIn q.atoms) (checkClausesR q mode C Γ R path cs t ε)

def ClauseTypesComputes (q : Input) (cs : Clauses) : Prop :=
  ∀ C Γ R path t ε, q.Sound → cs.AtomsIn q.atoms → Env.AtomsIn q.atoms Γ →
    ReturnAtoms q.atoms R → t.AtomsIn q.atoms → ε.AtomsIn q.atoms →
    ComputesIn q (Ty.AtomsIn q.atoms) (inferClauseTypesR q C Γ R path cs t ε)

end Benitoite.Surface.Check
