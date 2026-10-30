import Benitoite.Release.Refinement.Normalize

/-!
# 文脈・事実・整形式と同時置換

None と値の番号を保ち、篩の self を外側の値から区別する。
-/

namespace Benitoite.Release.Refinement

abbrev Ctx := List (Option Ty)

/-- 通常値を参照できる位置。継続を隠す操作と同じ境界を使う。 -/
def Ordinary (a : Ty) : Prop := ∀ b t e, a ≠ .cont b t e
abbrev Ty.Ordinary (a : Ty) : Prop := Benitoite.Release.Refinement.Ordinary a

@[simp] theorem ordinary_iff (a : Ty) : Ordinary a ↔ ∀ b t e, a ≠ .cont b t e := Iff.rfl

def Ty.sort? : Ty → Option «Sort»
  | .base .integer | .base .integer8 | .base .integer16 | .base .integer32
  | .base .unsignedInteger16 | .base .unsignedInteger32 | .base .unsignedInteger64
  | .base .byte => some .integer
  | .base .character => some .character
  | .base .float => some .float64
  | .base .float32 => some .float32
  | .base .decimal => some .decimal
  | .base .boolean => some .boolean
  | .base .unit => some .unit
  | .base .string => some .string
  | .list _ => some .list
  | .bytes => some .bytes
  | .map _ _ => some .map
  | .set _ => some .set
  | .data _ _ => some .data
  | .scoped _ k _ => some (.target k)
  | .refined a _ => a.sort?
  | _ => none

def Ty.HasSort (a : Ty) (s : «Sort») : Prop := a.sort? = some s
theorem Ty.hasSort_unique {a : Ty} {s t : «Sort»} (h : a.HasSort s) (h' : a.HasSort t) : s = t :=
  Option.some.inj (h.symm.trans h')
def Ty.IntegerCarrier (a : Ty) : Prop := a.HasSort .integer
theorem Ty.integerCarrier_iff_hasSort (a : Ty) : a.IntegerCarrier ↔ a.HasSort .integer := Iff.rfl

def Ty.core : Ty → Ty
  | .refined a _ => a.core
  | a => a
def Ty.NotContCore (a : Ty) : Prop := ∀ b t e, a.core ≠ .cont b t e

@[simp] theorem Ty.notContCore_norm (a : Ty) : a.norm.NotContCore ↔ a.NotContCore := by
  cases a <;> simp [Ty.NotContCore, Ty.core, Ty.norm]
  case refined a p => exact Ty.notContCore_norm a

theorem Ty.HasSort.ordinary {a : Ty} {s : «Sort»} (h : a.HasSort s) : Ordinary a := by
  cases a <;> simp_all [Ordinary, Ty.HasSort, Ty.sort?]

theorem Ty.HasSort.notContCore {a : Ty} {s : «Sort»} (h : a.HasSort s) : a.NotContCore := by
  cases a <;> simp_all [Ty.HasSort, Ty.sort?, Ty.NotContCore, Ty.core]
  case refined a p => exact Ty.HasSort.notContCore h

theorem Ty.IntegerCarrier.notContCore {a : Ty} (h : a.IntegerCarrier) : a.NotContCore := by
  cases a <;> simp_all [Ty.IntegerCarrier, Ty.HasSort, Ty.sort?, Ty.NotContCore, Ty.core]
  case refined a p => exact Ty.IntegerCarrier.notContCore h

def Ctx.Readable (Γ : Ctx) (i : Nat) : Prop := ∃ a, Γ[i]? = some (some a) ∧ Ordinary a
def Term.References (Γ : Ctx) (t : Term) : Prop := t.VarsIn Γ.Readable
def Pred.References (Γ : Ctx) (self : Option Ty) (p : Pred) : Prop :=
  p.VarsIn (match self with | none => Γ.Readable | some a => Ctx.Readable (some a :: Γ))

def Term.Shape (Γ : Ctx) : Term → «Sort» → Prop
  | .var i, s => ∃ a, Γ[i]? = some (some a) ∧ a.HasSort s
  | .integer _, s => s = .integer
  | .character _, s => s = .character
  | .float64 _, s => s = .float64
  | .float32 _, s => s = .float32
  | .decimal _ _, s => s = .decimal
  | .boolean _, s => s = .boolean
  | .unitValue, s => s = .unit
  | .string _, s => s = .string
  | .listValue _, s => s = .list
  | .bytesValue _, s => s = .bytes
  | .mapValue _ _, s => s = .map
  | .setValue _, s => s = .set
  | .dataValue _ _, s => s = .data
  | .targetValue _ t, s => s = .target t.kind
  | .field r t, s => t.Shape Γ .data ∧ s = r.result
  | .measure m t, s => t.Shape Γ m.input ∧ s = m.output
  | .add a b, s => a.Shape Γ .integer ∧ b.Shape Γ .integer ∧ s = .integer
  | .neg a, s | .scale _ a, s => a.Shape Γ .integer ∧ s = .integer

def Term.HasSort (Γ : Ctx) (t : Term) (s : «Sort») : Prop := t.References Γ ∧ t.Shape Γ s
abbrev termSorted (Γ : Ctx) (t : Term) : Prop := t.HasSort Γ .integer

def Pred.Sorted (Γ : Ctx) (self : Option Ty) : Pred → Prop
  | .truth | .falsity => True
  | .eq a b | .le a b | .lt a b =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      a.HasSort Δ .integer ∧ b.HasSort Δ .integer
  | .compare s o a b =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      Comparison.Allowed s o ∧ a.HasSort Δ s ∧ b.HasSort Δ s
  | .floatClass w _ a =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      a.HasSort Δ (match w with | .binary32 => .float32 | .binary64 => .float64)
  | .decimalRepresented a =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      a.HasSort Δ .decimal
  | .charactersIn a _ _ =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      a.HasSort Δ .string
  | .member k a _ =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      a.HasSort Δ (.target k)
  | .constructorIs a _ =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      a.HasSort Δ .data
  | .and p q | .or p q => Pred.Sorted Γ self p ∧ Pred.Sorted Γ self q
  | .not p => Pred.Sorted Γ self p

theorem Term.references_wf {Γ : Ctx} {t : Term} (h : t.References Γ) : termWF Γ.length t :=
  Term.varsIn_mono h (fun _ ⟨_, hi, _⟩ => (List.getElem?_eq_some_iff.mp hi).1)

theorem Term.HasSort.references {Γ : Ctx} {t : Term} {s : «Sort»} (h : t.HasSort Γ s) :
    t.References Γ := h.1

theorem Pred.Sorted.references {Γ : Ctx} {self : Option Ty} {p : Pred}
    (h : p.Sorted Γ self) : p.References Γ self := by
  cases self <;> cases p <;> simp only [Pred.Sorted] at h <;> simp only [Pred.References, Pred.VarsIn]
  all_goals first
    | trivial
    | exact ⟨Term.HasSort.references h.1, Term.HasSort.references h.2⟩
    | exact ⟨Term.HasSort.references h.2.1, Term.HasSort.references h.2.2⟩
    | exact Term.HasSort.references h
    | exact ⟨Pred.Sorted.references h.1, Pred.Sorted.references h.2⟩
    | exact Pred.Sorted.references h

theorem Pred.references_wf {Γ : Ctx} {a : Ty} {p : Pred}
    (h : p.References Γ (some a)) : p.WF (Γ.length+1) :=
  Pred.varsIn_mono h (fun _ ⟨_, hi, _⟩ => (List.getElem?_eq_some_iff.mp hi).1)

def Ty.assume : Ty → List Pred
  | .refined a p => p :: a.assume
  | _ => []

/-- 文脈の番号を保ち、各変数の最外の篩だけを事実とする。 -/
def Ctx.facts (Γ : Ctx) : List Pred :=
  (Γ.zipIdx).flatMap fun (a, i) =>
    match a with
    | none => []
    | some a => a.assume.map (fun p => p.open (.var i))

mutual
  /-- 値の名前空間だけを移動する。篩の self は越えない。 -/
  def Ty.shiftV (k c : Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o ix
    | .data d as => .data d (shiftVTys k c as)
    | .list a => .list (a.shiftV k c)
    | .fn ns ps r e => .fn ns (shiftVTys k c ps) (r.shiftV k c) (Eff.shiftV k c e)
    | .tvar i => .tvar i
    | .reference a => .reference (a.shiftV k c)
    | .lazy a => .lazy (a.shiftV k c)
    | .cont b t e => .cont (b.shiftV k c) (t.shiftV k c) (Eff.shiftV k c e)
    | .map a b => .map (a.shiftV k c) (b.shiftV k c)
    | .set a => .set (a.shiftV k c)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.shiftV k c)
    | .tapp i as => .tapp i (shiftVTys k c as)
    | .ctor φ => .ctor φ
    | .refined a p => .refined (a.shiftV k c)
        (predBind (fun i => some (.var (if i < c+1 then i else i+k))) p)
    | .dependentFn t => .dependentFn (Tel.shiftV k c t)
    | .external id as => .external id (shiftVTys k c as)
    | .scoped o kind ix => .scoped o kind ix
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  def Tel.shiftV (k c : Nat) : Tel → Tel
    | .done r e => .done (r.shiftV k c) (Eff.shiftV k c e)
    | .param n a t => .param n (a.shiftV k c) (Tel.shiftV k (c+1) t)
  def shiftVTys (k c : Nat) : List Ty → List Ty
    | [] => []
    | a :: as => a.shiftV k c :: shiftVTys k c as
  def Eff.shiftV (k c : Nat) : Eff → Eff
    | .mk a fs => .mk a (shiftVTys k c fs)
end

def Ctx.extend (Γ : Ctx) (a : Ty) : Ctx :=
  some (a.shiftV 1 0) :: Γ.map (Option.map (Ty.shiftV 1 0))
def Ctx.extendNone (Γ : Ctx) : Ctx :=
  none :: Γ.map (Option.map (Ty.shiftV 1 0))

@[simp] theorem Ty.notContCore_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).NotContCore ↔ a.NotContCore := by
  cases a <;> simp [Ty.NotContCore, Ty.core, Ty.shiftV]
  case refined a p => exact Ty.notContCore_shiftV a k c


mutual
  def Ty.WF (nr nt nv : Nat) : Ty → Prop
    | .base _ | .bytes | .ctor _ | .pathBases | .scopePattern _ => True
    | .opaque _ ix | .scoped _ _ ix => ix.WF nr
    | .data _ args | .external _ args => Ty.WFList nr nt nv args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.WF nr nt nv
    | .fn ns ps r e => NamesWF ns ps ∧ Ty.WFList nr nt nv ps ∧ r.WF nr nt nv ∧
        Eff.WF nr nt nv e ∧ Eff.Canonical e
    | .tvar i => i < nt
    | .cont b t e => b.WF nr nt nv ∧ t.WF nr nt nv ∧ Eff.WF nr nt nv e ∧ Eff.Canonical e
    | .map a b => a.WF nr nt nv ∧ b.WF nr nt nv
    | .tapp i args => i < nt ∧ Ty.WFList nr nt nv args
    | .refined a p => a.WF nr nt nv ∧ p.WF (nv+1) ∧ a.NotContCore
    | .dependentFn t => Tel.WF nr nt nv t
  def Tel.WF (nr nt nv : Nat) : Tel → Prop
    | .done r e => r.WF nr nt nv ∧ Eff.WF nr nt nv e ∧ Eff.Canonical e
    | .param _ a t => a.WF nr nt nv ∧ Tel.WF nr nt (nv+1) t
  def Ty.WFList (nr nt nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.WF nr nt nv ∧ Ty.WFList nr nt nv as
  def Eff.WF (nr nt nv : Nat) : Eff → Prop
    | .mk _ fs => Ty.WFList nr nt nv fs
end

mutual
  def Ty.Sorted (Γ : Ctx) : Ty → Prop
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ | .scoped _ _ _ | .pathBases | .scopePattern _ => True
    | .data _ as | .tapp _ as | .external _ as => sortedTys Γ as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.Sorted Γ
    | .fn _ ps r e => sortedTys Γ ps ∧ r.Sorted Γ ∧ sortedEff Γ e
    | .cont b t e => b.Sorted Γ ∧ t.Sorted Γ ∧ sortedEff Γ e
    | .map a b => a.Sorted Γ ∧ b.Sorted Γ
    | .refined a p => a.Sorted Γ ∧ p.Sorted Γ (some a)
    | .dependentFn t => Tel.Sorted Γ t
  def Tel.Sorted (Γ : Ctx) : Tel → Prop
    | .done r e => r.Sorted Γ ∧ sortedEff Γ e
    | .param _ a t => a.Sorted Γ ∧ Tel.Sorted (Γ.extend a) t
  def sortedTys (Γ : Ctx) : List Ty → Prop
    | [] => True
    | a :: as => a.Sorted Γ ∧ sortedTys Γ as
  def sortedEff (Γ : Ctx) : Eff → Prop
    | .mk _ fs => sortedTys Γ fs
end

mutual
  def Ty.References (Γ : Ctx) : Ty → Prop
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ | .scoped _ _ _ | .pathBases | .scopePattern _ => True
    | .data _ as | .tapp _ as | .external _ as => referencesTys Γ as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.References Γ
    | .fn _ ps r e => referencesTys Γ ps ∧ r.References Γ ∧ Eff.References Γ e
    | .cont b t e => b.References Γ ∧ t.References Γ ∧ Eff.References Γ e
    | .map a b => a.References Γ ∧ b.References Γ
    | .refined a p => a.References Γ ∧ p.References Γ (some a)
    | .dependentFn t => Tel.References Γ t
  def Tel.References (Γ : Ctx) : Tel → Prop
    | .done r e => r.References Γ ∧ Eff.References Γ e
    | .param _ a t => a.References Γ ∧ Tel.References (Γ.extend a) t
  def referencesTys (Γ : Ctx) : List Ty → Prop
    | [] => True
    | a :: as => a.References Γ ∧ referencesTys Γ as
  def Eff.References (Γ : Ctx) : Eff → Prop
    | .mk _ fs => referencesTys Γ fs
end

mutual
  theorem Ty.Sorted.references {Γ : Ctx} {a : Ty} (h : a.Sorted Γ) : a.References Γ := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.References]
    all_goals first
      | trivial
      | exact Ty.Sorted.references h
      | exact Tel.Sorted.references h
      | exact sortedTys_references h
      | exact ⟨sortedTys_references h.1, Ty.Sorted.references h.2.1, sortedEff_references h.2.2⟩
      | exact ⟨Ty.Sorted.references h.1, Ty.Sorted.references h.2.1, sortedEff_references h.2.2⟩
      | exact ⟨Ty.Sorted.references h.1, Ty.Sorted.references h.2⟩
      | exact ⟨Ty.Sorted.references h.1, Pred.Sorted.references h.2⟩
  theorem Tel.Sorted.references {Γ : Ctx} {t : Tel} (h : Tel.Sorted Γ t) : Tel.References Γ t := by
    cases t with
    | done r e => exact ⟨Ty.Sorted.references h.1, sortedEff_references h.2⟩
    | param n a t => exact ⟨Ty.Sorted.references h.1, Tel.Sorted.references h.2⟩
  private theorem sortedTys_references {Γ : Ctx} {as : List Ty} (h : sortedTys Γ as) :
      referencesTys Γ as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Sorted.references h.1, sortedTys_references h.2⟩
  theorem sortedEff_references {Γ : Ctx} {e : Eff} (h : sortedEff Γ e) : Eff.References Γ e := by
    cases e; exact sortedTys_references h
end



mutual
  theorem embed_wf {nr nt nv : Nat} {a : Benitoite.Release.Ty} (h : a.WF nr nt) :
      (embedTy a).WF nr nt nv := by
    cases a <;> simp only [Benitoite.Release.Ty.WF] at h <;> simp only [embedTy, Ty.WF]
    all_goals first
      | exact h
      | exact embed_wf h
      | exact embed_wfList h
      | skip
    case «opaque» o ix => exact embedIx_wf h
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, Benitoite.Release.NamesWF, embedTys_eq_map, List.length_map] using h.1,
        embed_wfList h.2.1, embed_wf h.2.2.1, embed_eff_wf h.2.2.2.1,
        embed_canonical h.2.2.2.2⟩
    case cont b t e => exact ⟨embed_wf h.1, embed_wf h.2.1, embed_eff_wf h.2.2.1, embed_canonical h.2.2.2⟩
    case map a b => exact ⟨embed_wf h.1, embed_wf h.2⟩
    case tapp i as => exact ⟨h.1, embed_wfList h.2⟩
  private theorem embed_wfList {nr nt nv : Nat} {as : List Benitoite.Release.Ty}
      (h : Benitoite.Release.Ty.WFList nr nt as) : Ty.WFList nr nt nv (embedTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨embed_wf h.1, embed_wfList h.2⟩
  private theorem embed_eff_wf {nr nt nv : Nat} {e : Benitoite.Release.Eff} (h : e.WF nr nt) :
      Eff.WF nr nt nv (embedEff e) := by
    cases e
    exact embed_wfList h
end

/-- 型・行・閉じた範囲と、論理の値の同時置換。 -/
structure SubstEnv where
  types : Nat → Ty
  rows : List Eff
  ranges : List RangeExpr
  values : ObservationEnv

def SubstEnv.up (θ : SubstEnv) : SubstEnv :=
  ⟨fun i => (θ.types i).shiftV 1 0, θ.rows.map (Eff.shiftV 1 0), θ.ranges, upValues θ.values⟩

@[simp] theorem SubstEnv.up_types (θ : SubstEnv) (i : Nat) : θ.up.types i = (θ.types i).shiftV 1 0 := rfl
@[simp] theorem SubstEnv.up_rows (θ : SubstEnv) : θ.up.rows = θ.rows.map (Eff.shiftV 1 0) := rfl
@[simp] theorem SubstEnv.up_ranges (θ : SubstEnv) : θ.up.ranges = θ.ranges := rfl
@[simp] theorem SubstEnv.up_values (θ : SubstEnv) : θ.up.values = upValues θ.values := rfl

def rawApply (t : Ty) (as : List Ty) : Ty :=
  match t with
  | .ctor (.data d) => .data d as
  | .ctor .list => .list (as.headD (.base .unit))
  | .ctor .set => .set (as.headD (.base .unit))
  | .ctor .map => .map (as.headD (.base .unit)) (as.tail.headD (.base .unit))
  | .ctor .reference => .reference (as.headD (.base .unit))
  | .ctor .lazy => .lazy (as.headD (.base .unit))
  | .tvar i => .tapp i as
  | t => t

def substAtoms (es : List Eff) (a : Atom → Bool) : Atom → Bool := fun x =>
  let kept := match x with
    | .name l r => a (.name l r)
    | .rho i => if i < es.length then false else a (.rho i)
  kept || (List.range es.length).any (fun i =>
    a (.rho i) && match es[i]? with | some e => e.test x | none => false)

def rowFails (es : List Eff) (a : Atom → Bool) : List Ty :=
  ((List.range es.length).filter (fun i => a (.rho i))).flatMap (fun i =>
    match es[i]? with | some e => e.fails | none => [])

mutual
  /-- 入力の子だけに再帰し、型・行の像には同じ置換を再適用しない。 -/
  def Ty.rawBind (θ : SubstEnv) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o (ix.inst θ.ranges)
    | .data d as => .data d (rawBindTys θ as)
    | .list a => .list (a.rawBind θ)
    | .fn ns ps r e => .fn ns (rawBindTys θ ps) (r.rawBind θ) (Eff.rawBind θ e)
    | .tvar i => θ.types i
    | .reference a => .reference (a.rawBind θ)
    | .lazy a => .lazy (a.rawBind θ)
    | .cont b t e => .cont (b.rawBind θ) (t.rawBind θ) (Eff.rawBind θ e)
    | .map a b => .map (a.rawBind θ) (b.rawBind θ)
    | .set a => .set (a.rawBind θ)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.rawBind θ)
    | .tapp i as => rawApply (θ.types i) (rawBindTys θ as)
    | .ctor φ => .ctor φ
    | .refined a p => .refined (a.rawBind θ) (predBind (upValues θ.values) p)
    | .dependentFn t => .dependentFn (Tel.rawBind θ t)
    | .external id as => .external id (rawBindTys θ as)
    | .scoped o kind ix => .scoped o kind (ix.inst θ.ranges)
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  def Tel.rawBind (θ : SubstEnv) : Tel → Tel
    | .done r e => .done (r.rawBind θ) (Eff.rawBind θ e)
    | .param n a t => .param n (a.rawBind θ) (Tel.rawBind θ.up t)
  def rawBindTys (θ : SubstEnv) : List Ty → List Ty
    | [] => []
    | a :: as => a.rawBind θ :: rawBindTys θ as
  def Eff.rawBind (θ : SubstEnv) : Eff → Eff
    | .mk a fs => .mk (substAtoms θ.rows (instAtoms θ.ranges a))
        (rawBindTys θ fs ++ rowFails θ.rows a)
end

noncomputable def Ty.bind (θ : SubstEnv) (t : Ty) : Ty := (t.rawBind θ).norm
noncomputable def Eff.bind (θ : SubstEnv) (e : Eff) : Eff := (Eff.rawBind θ e).norm
noncomputable def Tel.bind (θ : SubstEnv) (t : Tel) : Tel := Tel.norm (Tel.rawBind θ t)

end Benitoite.Release.Refinement
