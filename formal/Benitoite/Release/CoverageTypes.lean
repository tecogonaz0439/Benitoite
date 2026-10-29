import Benitoite.Release.Lemmas.TySubst

/-!
# 網羅性が観察する型の形

潜在効果を消した型の等しさから、パターン照合の値の所属を移す。
正規化前の計算できる代入を網羅性判定へ接続する（設計書 07-04「01-12 との対応」）。
-/
namespace Benitoite.Release.Coverage

mutual
  def erase : Ty → Ty
    | .base b => .base b
    | .opaque o r => .opaque o r
    | .data d ts => .data d (eraseTys ts)
    | .list a => .list (erase a)
    | .fn ns ps r _ => .fn ns (eraseTys ps) (erase r) Eff.empty
    | .tvar i => .tvar i
    | .reference a => .reference (erase a)
    | .lazy a => .lazy (erase a)
    | .cont a b _ => .cont (erase a) (erase b) Eff.empty
    | .map a b => .map (erase a) (erase b)
    | .set a => .set (erase a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (erase a)
    | .tapp i ts => .tapp i (eraseTys ts)
    | .ctor c => .ctor c
  def eraseTys : List Ty → List Ty
    | [] => []
    | t :: ts => erase t :: eraseTys ts
end

@[simp] theorem eraseTys_map (ts : List Ty) : eraseTys ts = ts.map erase := by
  induction ts with
  | nil => rfl
  | cons t ts ih => simp [eraseTys, ih]

mutual
  @[simp] theorem erase_norm (t : Ty) : erase t.norm = erase t := by
    cases t <;> simp only [Ty.norm, erase, erase_norm, eraseTys_norm]
  @[simp] theorem eraseTys_norm (ts : List Ty) : eraseTys (Ty.normTys ts) = eraseTys ts := by
    cases ts with
    | nil => rfl
    | cons t ts => simp only [Ty.normTys, eraseTys, erase_norm, eraseTys_norm]
end

theorem erase_rawApply (c : TyCon) (ts : List Ty) :
    erase (c.rawApply ts) = c.rawApply (eraseTys ts) := by
  cases c <;> cases ts <;> simp only [TyCon.rawApply, erase, eraseTys,
    List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons]
  rename_i t ts
  cases ts <;> rfl

theorem erase_rawApplyTo (t : Ty) (ts : List Ty) :
    erase (t.rawApplyTo ts) = (erase t).rawApplyTo (eraseTys ts) := by
  cases t <;> simp only [Ty.rawApplyTo, erase, erase_rawApply]

mutual
  theorem erase_rawBind (θ : SubstEnv) (t : Ty) :
      erase (t.rawBind θ) = (erase t).rawBind ⟨fun i => erase (θ.types i), []⟩ := by
    cases t <;> simp only [Ty.rawBind, erase, erase_rawBind, eraseTys_rawBind]
    case tapp i ts =>
      rw [erase_rawApplyTo, eraseTys_rawBind]
    all_goals simp [Eff.empty, Eff.rawBind, Ty.rawBindTys, Eff.substAtoms_nil]
  theorem eraseTys_rawBind (θ : SubstEnv) (ts : List Ty) :
      eraseTys (Ty.rawBindTys θ ts) = Ty.rawBindTys ⟨fun i => erase (θ.types i), []⟩ (eraseTys ts) := by
    cases ts with
    | nil => rfl
    | cons t ts => simp only [Ty.rawBindTys, eraseTys, erase_rawBind, eraseTys_rawBind]
end

theorem erase_subst_raw (ts : List Ty) (t : Ty) :
    erase (t.subst ts []) = erase (t.rawSubstAt 0 ts []) := by
  rw [Ty.subst, Ty.substAt_eq_rawBind, erase_norm]
  rfl

theorem erase_subst_congr {ts us : List Ty} (h : eraseTys ts = eraseTys us) (t : Ty) :
    erase (t.subst ts []) = erase (t.subst us []) := by
  rw [erase_subst_raw, erase_subst_raw, Ty.rawSubstAt, Ty.rawSubstAt,
    erase_rawBind, erase_rawBind]
  congr 1
  congr 1
  funext i
  simp only [SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, Ty.rawShift_zero]
  have hl : ts.length = us.length := by
    simpa only [eraseTys_map, List.length_map] using congrArg List.length h
  rw [hl]
  split
  · have he := congrArg (fun xs : List Ty => xs[i]?) h
    simp only [eraseTys_map, List.getElem?_map] at he
    cases ht : ts[i]? <;> cases hu : us[i]? <;> simp_all
  · rfl

mutual
  theorem inhabits_erase_transfer {P : Program} {a : Ty} {v : Val}
      (h : Inhabits P a v) : ∀ {b}, erase a = erase b → Inhabits P b v := by
    cases h with
    | @const c =>
      intro b he
      have he' : c.type = b := by
        cases c <;> cases b <;> simp_all [Const.type, erase]
      rw [← he']
      exact .const (c := c)
    | @con c ts tys args cd hd hn hx =>
      intro b he
      cases b <;> simp only [erase] at he <;> try contradiction
      rename_i d us
      have hh := Ty.data.inj he
      obtain ⟨rfl, hts⟩ := hh
      have hl : ts.length = us.length := by
        simpa only [eraseTys_map, List.length_map] using congrArg List.length hts
      refine .con hd (hn.trans hl) (inhabitsAll_erase_transfer hx ?_)
      simp only [eraseTys_map, List.map_map]
      exact List.map_congr_left (fun t _ => erase_subst_congr hts t)
    | list hx =>
      intro b he
      cases b <;> simp only [erase] at he <;> try contradiction
      exact .list (inhabitsEach_erase_transfer hx (Ty.list.inj he))
    | fn | tvar | reference | lazy | cont | map | set | bytes | dict | tapp | ctor =>
      intro b he
      cases b <;> simp only [erase] at he <;> try contradiction
      all_goals constructor
    | checked =>
      intro b he
      cases b <;> simp only [erase] at he <;> try contradiction
      obtain ⟨rfl, rfl⟩ := Ty.opaque.inj he
      exact .checked
    | checkedRequest =>
      intro b he
      cases b <;> simp only [erase] at he <;> try contradiction
      obtain ⟨rfl, rfl⟩ := Ty.opaque.inj he
      exact .checkedRequest
  theorem inhabitsAll_erase_transfer {P : Program} {ts : List Ty} {vs : List Val}
      (h : InhabitsAll P ts vs) : ∀ {us}, eraseTys ts = eraseTys us → InhabitsAll P us vs := by
    cases h with
    | nil => intro us he; cases us <;> simp_all [eraseTys]; exact .nil
    | cons hv hs =>
      intro us he
      cases us with
      | nil => simp [eraseTys] at he
      | cons u us =>
        have hh := List.cons.inj he
        exact .cons (inhabits_erase_transfer hv hh.1) (inhabitsAll_erase_transfer hs hh.2)
  theorem inhabitsEach_erase_transfer {P : Program} {a : Ty} {vs : List Val}
      (h : InhabitsEach P a vs) : ∀ {b}, erase a = erase b → InhabitsEach P b vs := by
    cases h with
    | nil => intro b _; exact .nil
    | cons hv hs =>
      intro b he
      exact .cons (inhabits_erase_transfer hv he) (inhabitsEach_erase_transfer hs he)
end

end Benitoite.Release.Coverage
