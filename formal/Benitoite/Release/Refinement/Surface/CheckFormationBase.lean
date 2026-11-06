import Benitoite.Release.Refinement.Surface.CheckCompare
import Benitoite.Release.Refinement.Admissible

/-! 型注釈の形成を有限の構文と宣言の一覧で照合する（設計書 01-12「型の情報を付けた表層の構文と型付け」）。 -/
namespace Benitoite.Release.Refinement.Surface.CheckFormation
open CheckCompare

/-- 欄の受け手の名目型を指定する有限の案内。各段は宣言の表と照合する。 -/
inductive DataHint where
  | var
  | value (arguments : List Ty)
  | field (receiver : DataHint)
  | widen (receiver : DataHint) (arguments : List Ty)

/-- 効果の有限候補と、data ごとの構成子の全一覧、ソースの位置ごとの案内。 -/
structure Input where
  atoms : List Atom
  ctors : DataName → List ConName
  hints : List Nat → DataHint := fun _ => .var

def CtorsComplete (P : Refinement.Program) (ctors : DataName → List ConName) : Prop :=
  ∀ c cd, P.cons c = some cd → c ∈ ctors cd.data

def DataHint.Support (s : List Atom) : DataHint → Prop
  | .var => True
  | .value ts => Ty.SupportList (· ∈ s) ts
  | .field h => h.Support s
  | .widen h ts => h.Support s ∧ Ty.SupportList (· ∈ s) ts

/-- 一覧の全件性と、入力に現れる型の有限支持。判定の健全性はこの欄に含めない。 -/
structure Input.Sound (q : Input) (P : Refinement.Program) : Prop where
  ctors : CtorsComplete P q.ctors
  fields : ∀ c cd, P.cons c = some cd → Ty.SupportList (· ∈ q.atoms) cd.args
  hints : ∀ path, (q.hints path).Support q.atoms

def CtxSupport (s : List Atom) (Γ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.Support (· ∈ s)

instance rangeIxWFDecidable (nr : Nat) (ix : RangeIx) : Decidable (ix.WF nr) := by
  cases ix <;> unfold RangeIx.WF <;> infer_instance

def canonicalEff (q : Input) (e : Eff) : Bool := rawEffEq q.atoms (e.normWith q.atoms) e

theorem canonicalEff_sound {q e} (he : e.Support (· ∈ q.atoms)) (h : canonicalEff q e = true) :
    e.Canonical := by
  have hh := (rawEffEq_spec (Eff.normWith_support q.atoms e he) he).mp h
  simpa only [Eff.normWith_eq_norm q.atoms e he, Eff.Canonical] using hh

mutual
  def wfTy (q : Input) (nr nt nv : Nat) : Ty → Bool
    | .base _ | .bytes | .ctor _ | .pathBases | .scopePattern _ => true
    | .opaque _ ix | .scoped _ _ ix => decide (ix.WF nr)
    | .data _ as | .external _ as => wfTys q nr nt nv as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => wfTy q nr nt nv a
    | .fn ns ps r e => decide (NamesWF ns ps) &&
        (wfTys q nr nt nv ps && (wfTy q nr nt nv r && (wfEff q nr nt nv e && canonicalEff q e)))
    | .tvar i => decide (i < nt)
    | .cont b t e => wfTy q nr nt nv b &&
        (wfTy q nr nt nv t && (wfEff q nr nt nv e && canonicalEff q e))
    | .map a b => wfTy q nr nt nv a && wfTy q nr nt nv b
    | .tapp i as => decide (i < nt) && wfTys q nr nt nv as
    | .refined a p => wfTy q nr nt nv a && (decide (p.WF (nv + 1)) && decide (Ordinary a))
    | .dependentFn t => wfTel q nr nt nv t
  def wfTel (q : Input) (nr nt nv : Nat) : Tel → Bool
    | .done r e => wfTy q nr nt nv r && (wfEff q nr nt nv e && canonicalEff q e)
    | .param _ a t => wfTy q nr nt nv a && wfTel q nr nt (nv + 1) t
  def wfTys (q : Input) (nr nt nv : Nat) : List Ty → Bool
    | [] => true
    | a :: as => wfTy q nr nt nv a && wfTys q nr nt nv as
  def wfEff (q : Input) (nr nt nv : Nat) : Eff → Bool
    | .mk _ fs => wfTys q nr nt nv fs
end

mutual
  theorem wfTy_sound {q nr nt nv a} (ha : a.Support (· ∈ q.atoms)) (h : wfTy q nr nt nv a = true) :
      a.WF nr nt nv := by
    cases hcase : a <;> simp only [hcase, wfTy, Bool.and_eq_true, decide_eq_true_eq, Ty.Support] at h ha ⊢
    case base | bytes | ctor | pathBases | scopePattern => trivial
    case «opaque» | «scoped» | tvar => exact h
    case data | external => exact wfTys_sound ha h
    case list a | reference a | lazy a | set a => exact wfTy_sound (a := a) ha h
    case dict cl a => exact wfTy_sound (a := a) ha h
    case dependentFn => exact wfTel_sound ha h
    case fn ns ps r e =>
      exact ⟨h.1, wfTys_sound ha.1 h.2.1, wfTy_sound ha.2.1 h.2.2.1,
        wfEff_sound ha.2.2 h.2.2.2.1, canonicalEff_sound ha.2.2 h.2.2.2.2⟩
    case cont b t e =>
      exact ⟨wfTy_sound ha.1 h.1, wfTy_sound ha.2.1 h.2.1,
        wfEff_sound ha.2.2 h.2.2.1, canonicalEff_sound ha.2.2 h.2.2.2⟩
    case map a b => exact ⟨wfTy_sound ha.1 h.1, wfTy_sound ha.2 h.2⟩
    case tapp i as => exact ⟨h.1, wfTys_sound ha h.2⟩
    case refined a p => exact ⟨wfTy_sound ha h.1, h.2.1, h.2.2⟩
  termination_by sizeOf a
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem wfTel_sound {q nr nt nv t} (ht : t.Support (· ∈ q.atoms)) (h : wfTel q nr nt nv t = true) :
      t.WF nr nt nv := by
    cases hcase : t with
    | done r e =>
      simp only [hcase] at ht h ⊢
      simp only [wfTel, Bool.and_eq_true] at h
      exact ⟨wfTy_sound ht.1 h.1, wfEff_sound ht.2 h.2.1, canonicalEff_sound ht.2 h.2.2⟩
    | param n a t =>
      simp only [hcase] at ht h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨wfTy_sound ht.1 hh.1, wfTel_sound ht.2 hh.2⟩
  termination_by sizeOf t
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem wfTys_sound {q nr nt nv as} (ht : Ty.SupportList (· ∈ q.atoms) as)
      (h : wfTys q nr nt nv as = true) : Ty.WFList nr nt nv as := by
    cases hcase : as with
    | nil => simp only [Ty.WFList]
    | cons a as =>
      simp only [hcase] at ht h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨wfTy_sound ht.1 hh.1, wfTys_sound ht.2 hh.2⟩
  termination_by sizeOf as
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem wfEff_sound {q nr nt nv e} (he : e.Support (· ∈ q.atoms)) (h : wfEff q nr nt nv e = true) :
      Eff.WF nr nt nv e := by
    cases hcase : e with
    | mk a fs =>
      simp only [hcase] at he h ⊢
      exact wfTys_sound he.2 h
  termination_by sizeOf e
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

end

mutual
  def sortedTy (Γ : Ctx) : Ty → Bool
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ | .scoped _ _ _
    | .pathBases | .scopePattern _ => true
    | .data _ as | .tapp _ as | .external _ as => sortedTys Γ as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => sortedTy Γ a
    | .fn _ ps r e => sortedTys Γ ps && (sortedTy Γ r && sortedEff Γ e)
    | .cont b t e => sortedTy Γ b && (sortedTy Γ t && sortedEff Γ e)
    | .map a b => sortedTy Γ a && sortedTy Γ b
    | .refined a p => sortedTy Γ a && decide (p.Sorted Γ (some a))
    | .dependentFn t => sortedTel Γ t
  def sortedTel (Γ : Ctx) : Tel → Bool
    | .done r e => sortedTy Γ r && sortedEff Γ e
    | .param _ a t => sortedTy Γ a && sortedTel (Γ.extend a) t
  def sortedTys (Γ : Ctx) : List Ty → Bool
    | [] => true
    | a :: as => sortedTy Γ a && sortedTys Γ as
  def sortedEff (Γ : Ctx) : Eff → Bool
    | .mk _ fs => sortedTys Γ fs
end

mutual
  theorem sortedTy_sound {Γ a} (h : sortedTy Γ a = true) : a.Sorted Γ := by
    cases hcase : a <;> simp only [hcase, sortedTy, Bool.and_eq_true, decide_eq_true_eq] at h ⊢
    case base | «opaque» | tvar | bytes | ctor | «scoped» | pathBases | scopePattern => trivial
    case data | tapp | external => exact sortedTys_sound h
    case list a | reference a | lazy a | set a => exact sortedTy_sound (a := a) h
    case dict cl a => exact sortedTy_sound (a := a) h
    case dependentFn => exact sortedTel_sound h
    case fn ns ps r e => exact ⟨sortedTys_sound h.1, sortedTy_sound h.2.1, sortedEff_sound h.2.2⟩
    case cont b t e => exact ⟨sortedTy_sound h.1, sortedTy_sound h.2.1, sortedEff_sound h.2.2⟩
    case map a b => exact ⟨sortedTy_sound h.1, sortedTy_sound h.2⟩
    case refined a p => exact ⟨sortedTy_sound h.1, h.2⟩
  termination_by sizeOf a
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem sortedTel_sound {Γ t} (h : sortedTel Γ t = true) : t.Sorted Γ := by
    cases hcase : t with
    | done r e =>
      simp only [hcase] at h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨sortedTy_sound hh.1, sortedEff_sound hh.2⟩
    | param n a t =>
      simp only [hcase] at h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨sortedTy_sound hh.1, sortedTel_sound hh.2⟩
  termination_by sizeOf t
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem sortedTys_sound {Γ as} (h : sortedTys Γ as = true) : Refinement.sortedTys Γ as := by
    cases hcase : as with
    | nil => simp only [Refinement.sortedTys]
    | cons a as =>
      simp only [hcase] at h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨sortedTy_sound hh.1, sortedTys_sound hh.2⟩
  termination_by sizeOf as
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem sortedEff_sound {Γ e} (h : sortedEff Γ e = true) : Refinement.sortedEff Γ e := by
    cases hcase : e with
    | mk a fs =>
      simp only [hcase] at h ⊢
      exact sortedTys_sound h
  termination_by sizeOf e
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

end

def dataEntries (q : Input) (P : Refinement.Program) (d : DataName) : List (ConName × ConDecl) :=
  (q.ctors d).filterMap fun c =>
    match P.cons c with
    | some cd => if cd.data = d then some (c, cd) else none
    | none => none

theorem dataEntries_mem {q P d c cd} : (c, cd) ∈ dataEntries q P d ↔
    c ∈ q.ctors d ∧ P.cons c = some cd ∧ cd.data = d := by
  simp only [dataEntries, List.mem_filterMap]
  constructor
  · rintro ⟨a, ha, hh⟩
    split at hh
    · split at hh
      · cases hh; exact ⟨ha, ‹_›, ‹_›⟩
      · cases hh
    · cases hh
  · rintro ⟨hc, hcd, hd⟩
    exact ⟨c, hc, by simp [hcd, hd]⟩

/-- 空の data を仮定せず、存在と全構成子の arity の一致を検査する。 -/
def dataArity (q : Input) (P : Refinement.Program) (d : DataName) : Option Nat :=
  match dataEntries q P d with
  | [] => none
  | (_, cd) :: rest =>
      if rest.all (fun e => decide (e.2.ntys = cd.ntys)) then some cd.ntys else none

theorem dataArity_sound {q P d n} (hq : CtorsComplete P q.ctors) (h : dataArity q P d = some n) :
    P.DataArity d n := by
  unfold dataArity at h
  split at h
  · cases h
  · rename_i c cd rest hrows
    split at h
    · rename_i hall
      cases h
      have first := dataEntries_mem.mp (show (c, cd) ∈ dataEntries q P d from hrows ▸ List.mem_cons_self)
      refine ⟨⟨c, cd, first.2.1, first.2.2⟩, ?_⟩
      intro c' cd' hc hd
      have hm := dataEntries_mem.mpr ⟨hd ▸ hq c' cd' hc, hc, hd⟩
      rw [hrows] at hm
      rcases List.mem_cons.mp hm with he | hm
      · cases he; rfl
      · exact of_decide_eq_true (List.all_eq_true.mp hall _ hm)
    · cases h

def ctorArity (q : Input) (P : Refinement.Program) : TyCon → Option Nat
  | .data d => dataArity q P d
  | .list | .set | .reference | .lazy => some 1
  | .map => some 2

theorem ctorArity_sound {q P c n} (hq : CtorsComplete P q.ctors) (h : ctorArity q P c = some n) :
    TyCon.arity P c = some n := by
  cases c <;> first | exact h | exact TyCon.arity_data (dataArity_sound hq h)

mutual
  def kindTy (q : Input) (P : Refinement.Program) (K : KindCtx) : Ty → TyKind → Bool
    | .ctor c, .constructor n => decide (ctorArity q P c = some n)
    | .tvar i, .constructor n => decide (K[i]? = some (.constructor n))
    | _, .constructor _ => false
    | .base _, .value | .bytes, .value | .opaque _ _, .value | .scoped _ _ _, .value
    | .pathBases, .value | .scopePattern _, .value => true
    | .data d as, .value => decide (dataArity q P d = some as.length) && kindTys q P K as
    | .external _ as, .value => kindTys q P K as
    | .list a, .value | .reference a, .value | .lazy a, .value | .set a, .value => kindTy q P K a .value
    | .dict cl a, .value => match P.classes cl with
      | some cd => kindTy q P K a cd.argumentKind
      | none => false
    | .fn ns ps r e, .value => decide (NamesWF ns ps) &&
        (kindTys q P K ps && (kindTy q P K r .value && kindEff q P K e))
    | .dependentFn t, .value => kindTel q P K t
    | .tvar i, .value => decide (K[i]? = some .value)
    | .cont b t e, .value => kindTy q P K b .value && (kindTy q P K t .value && kindEff q P K e)
    | .map a b, .value => kindTy q P K a .value && kindTy q P K b .value
    | .tapp i as, .value => decide (K[i]? = some (.constructor as.length)) && kindTys q P K as
    | .ctor _, .value => false
    | .refined a _, .value => kindTy q P K a .value && decide (Ordinary a)
  def kindTel (q : Input) (P : Refinement.Program) (K : KindCtx) : Tel → Bool
    | .done r e => kindTy q P K r .value && kindEff q P K e
    | .param _ a t => kindTy q P K a .value && kindTel q P K t
  def kindTys (q : Input) (P : Refinement.Program) (K : KindCtx) : List Ty → Bool
    | [] => true
    | a :: as => kindTy q P K a .value && kindTys q P K as
  def kindEff (q : Input) (P : Refinement.Program) (K : KindCtx) : Eff → Bool
    | .mk _ fs => kindTys q P K fs
end

mutual
  theorem kindTy_sound {q P K a k} (hq : CtorsComplete P q.ctors) (h : kindTy q P K a k = true) :
      a.HasKind P K k := by
    cases k with
    | constructor n =>
      cases hcase : a <;> simp only [hcase, kindTy, Bool.false_eq_true, decide_eq_true_eq] at h ⊢
      · exact h
      · exact ctorArity_sound hq h
    | value =>
      cases hcase : a <;> simp only [hcase, kindTy, Bool.and_eq_true, decide_eq_true_eq, Bool.false_eq_true] at h ⊢
      case base | bytes | «opaque» | «scoped» | pathBases | scopePattern => trivial
      case tvar => exact h
      case external => exact kindTys_sound hq h
      case list a | reference a | lazy a | set a => exact kindTy_sound (a := a) hq h
      case dependentFn => exact kindTel_sound hq h
      case data d as => exact ⟨TyCon.arity_data (dataArity_sound hq h.1), kindTys_sound hq h.2⟩
      case dict cl a =>
        split at h
        · rename_i cd hcd
          exact ⟨cd, hcd, kindTy_sound (a := a) hq h⟩
        · cases h
      case fn ns ps r e =>
        exact ⟨h.1, kindTys_sound hq h.2.1, kindTy_sound hq h.2.2.1, kindEff_sound hq h.2.2.2⟩
      case cont b t e => exact ⟨kindTy_sound hq h.1, kindTy_sound hq h.2.1, kindEff_sound hq h.2.2⟩
      case map a b => exact ⟨kindTy_sound hq h.1, kindTy_sound hq h.2⟩
      case tapp i as => exact ⟨h.1, kindTys_sound hq h.2⟩
      case refined a p => exact ⟨kindTy_sound hq h.1, h.2⟩
  termination_by sizeOf a
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem kindTel_sound {q P K t} (hq : CtorsComplete P q.ctors) (h : kindTel q P K t = true) :
      kindsTel P K t := by
    cases hcase : t with
    | done r e =>
      simp only [hcase] at h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨kindTy_sound hq hh.1, kindEff_sound hq hh.2⟩
    | param n a t =>
      simp only [hcase] at h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨kindTy_sound hq hh.1, kindTel_sound hq hh.2⟩
  termination_by sizeOf t
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem kindTys_sound {q P K as} (hq : CtorsComplete P q.ctors) (h : kindTys q P K as = true) :
      kindsList P K as := by
    cases hcase : as with
    | nil => simp only [kindsList]
    | cons a as =>
      simp only [hcase] at h ⊢
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨kindTy_sound hq hh.1, kindTys_sound hq hh.2⟩
  termination_by sizeOf as
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

  theorem kindEff_sound {q P K e} (hq : CtorsComplete P q.ctors) (h : kindEff q P K e = true) :
      kindsEff P K e := by
    cases hcase : e with
    | mk a fs =>
      simp only [hcase] at h ⊢
      exact kindTys_sound hq h
  termination_by sizeOf e
  decreasing_by all_goals (subst_vars; simp_wf <;> omega)

end

end Benitoite.Release.Refinement.Surface.CheckFormation
