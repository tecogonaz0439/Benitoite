import Benitoite.Release.Refinement.TypeShiftOrder
import Benitoite.Release.Refinement.ValueInstantiation

namespace Benitoite.Release.Refinement

def SubstEnv.mapTypeIndices (θ : SubstEnv) (k c : Nat) : SubstEnv :=
  {θ with types := fun i => Refinement.shiftTypes k c (θ.types i), rows := θ.rows.map (shiftRowsTypes k c)}

theorem SubstEnv.mapTypeIndices_up (θ : SubstEnv) (k c : Nat) :
    θ.up.mapTypeIndices k c = (θ.mapTypeIndices k c).up := by
  cases θ
  simp only [SubstEnv.mapTypeIndices, SubstEnv.up, List.map_map, shiftTypes_shiftV,
    shiftRowsTypes_shiftV, Function.comp_def]

theorem shiftTypes_rawApply (t : Ty) (as : List Ty) (k c : Nat) :
    shiftTypes k c (rawApply t as) = rawApply (shiftTypes k c t) (shiftTypesList k c as) := by
  cases t <;> simp only [rawApply, shiftTypes]
  case refined a p => rw [shiftTypes_rawApply a as k c]
  case ctor con =>
    cases con <;> cases as <;> simp [rawApply, shiftTypes, shiftTypesList]
    rename_i a as
    cases as <;> rfl

theorem substAtoms_mapTypeIndices (es : List Eff) (a : Atom → Bool) (k c : Nat) :
    substAtoms (es.map (shiftRowsTypes k c)) a = substAtoms es a := by
  funext x
  simp only [substAtoms, List.length_map, List.getElem?_map]
  congr 1
  apply congrArg (fun f => (List.range es.length).any f)
  funext i
  cases es[i]? with
  | none => rfl
  | some e => cases e; rfl

theorem rowFails_mapTypeIndices (es : List Eff) (a : Atom → Bool) (k c : Nat) :
    rowFails (es.map (shiftRowsTypes k c)) a = (rowFails es a).map (shiftTypes k c) := by
  simp only [rowFails, List.length_map, List.getElem?_map, List.map_flatMap]
  congr 1
  funext i
  cases es[i]? with
  | none => rfl
  | some e => cases e; exact shiftTypesList_eq_map k c _

theorem shiftTypesList_append (as bs : List Ty) (k c : Nat) :
    shiftTypesList k c (as ++ bs) = shiftTypesList k c as ++ shiftTypesList k c bs := by
  simp only [shiftTypesList_eq_map, List.map_append]

mutual
  theorem Ty.shiftTypes_rawBind (a : Ty) (θ : SubstEnv) (k c : Nat) :
      shiftTypes k c (a.rawBind θ) = a.rawBind (θ.mapTypeIndices k c) := by
    cases a <;> simp only [Ty.rawBind, shiftTypes, Ty.shiftTypes_rawBind,
      shiftTypesList_rawBind, Eff.shiftTypes_rawBind, Tel.shiftTypes_rawBind,
      SubstEnv.mapTypeIndices, shiftTypes_rawApply]
  termination_by structural a
  theorem Tel.shiftTypes_rawBind (t : Tel) (θ : SubstEnv) (k c : Nat) :
      shiftTelTypes k c (Tel.rawBind θ t) = Tel.rawBind (θ.mapTypeIndices k c) t := by
    cases t <;> simp only [Tel.rawBind, shiftTelTypes, Ty.shiftTypes_rawBind,
      Eff.shiftTypes_rawBind, Tel.shiftTypes_rawBind, SubstEnv.mapTypeIndices_up]
  termination_by structural t
  theorem shiftTypesList_rawBind (as : List Ty) (θ : SubstEnv) (k c : Nat) :
      shiftTypesList k c (rawBindTys θ as) = rawBindTys (θ.mapTypeIndices k c) as := by
    cases as <;> simp only [rawBindTys, shiftTypesList, Ty.shiftTypes_rawBind, shiftTypesList_rawBind]
  termination_by structural as
  theorem Eff.shiftTypes_rawBind (e : Eff) (θ : SubstEnv) (k c : Nat) :
      shiftRowsTypes k c (Eff.rawBind θ e) = Eff.rawBind (θ.mapTypeIndices k c) e := by
    cases e
    simp only [Eff.rawBind, shiftRowsTypes, SubstEnv.mapTypeIndices, substAtoms_mapTypeIndices,
      shiftTypesList_append, shiftTypesList_rawBind, rowFails_mapTypeIndices, ← shiftTypesList_eq_map]
  termination_by structural e
end

theorem Ty.shiftTypes_bind (a : Ty) (θ : SubstEnv) (k c : Nat) :
    shiftTypes k c (a.bind θ) = a.bind (θ.mapTypeIndices k c) := by
  rw [Ty.bind, ← Ty.norm_shiftTypes, Ty.shiftTypes_rawBind]
  rfl

structure SubstEnv.AgreesBelow (nt : Nat) (θ τ : SubstEnv) : Prop where
  types : ∀ i, i<nt → θ.types i = τ.types i
  rows : θ.rows = τ.rows
  ranges : θ.ranges = τ.ranges
  values : θ.values = τ.values

theorem SubstEnv.AgreesBelow.up {nt θ τ} (h : SubstEnv.AgreesBelow nt θ τ) :
    SubstEnv.AgreesBelow nt θ.up τ.up :=
  ⟨fun i hi => congrArg (Ty.shiftV 1 0) (h.types i hi), congrArg (List.map (Eff.shiftV 1 0)) h.rows, h.ranges, congrArg upValues h.values⟩

mutual
  theorem Ty.rawBind_agrees {nr nt nv a θ τ} (ha : Ty.WF nr nt nv a)
      (h : SubstEnv.AgreesBelow nt θ τ) : a.rawBind θ = a.rawBind τ := by
    cases a <;> simp only [Ty.WF] at ha <;> simp only [Ty.rawBind]
    all_goals try rfl
    case tvar i => exact h.types i ha
    case fn ns ps r e => rw [rawBindTys_agrees ha.2.1 h, Ty.rawBind_agrees ha.2.2.1 h, Eff.rawBind_agrees ha.2.2.2.1 h]
    case cont b t e => rw [Ty.rawBind_agrees ha.1 h, Ty.rawBind_agrees ha.2.1 h, Eff.rawBind_agrees ha.2.2.1 h]
    case map a b => rw [Ty.rawBind_agrees ha.1 h, Ty.rawBind_agrees ha.2 h]
    case tapp i as => rw [h.types i ha.1, rawBindTys_agrees ha.2 h]
    case refined a p => rw [Ty.rawBind_agrees ha.1 h, h.values]
    case «opaque» o ix => rw [h.ranges]
    case «scoped» o ki ix => rw [h.ranges]
    all_goals congr 1
    all_goals first
      | exact Ty.rawBind_agrees ha h
      | exact rawBindTys_agrees ha h
      | exact Tel.rawBind_agrees ha h
  theorem Tel.rawBind_agrees {nr nt nv t θ τ} (ha : Tel.WF nr nt nv t)
      (h : SubstEnv.AgreesBelow nt θ τ) : Tel.rawBind θ t = Tel.rawBind τ t := by
    cases t with
    | done r e => rw [Tel.rawBind, Tel.rawBind, Ty.rawBind_agrees ha.1 h, Eff.rawBind_agrees ha.2.1 h]
    | param n a t => rw [Tel.rawBind, Tel.rawBind, Ty.rawBind_agrees ha.1 h, Tel.rawBind_agrees ha.2 h.up]
  theorem rawBindTys_agrees {nr nt nv as θ τ} (ha : Ty.WFList nr nt nv as)
      (h : SubstEnv.AgreesBelow nt θ τ) : rawBindTys θ as = rawBindTys τ as := by
    cases as with
    | nil => rfl
    | cons a as => rw [rawBindTys, rawBindTys, Ty.rawBind_agrees ha.1 h, rawBindTys_agrees ha.2 h]
  theorem Eff.rawBind_agrees {nr nt nv e θ τ} (ha : Eff.WF nr nt nv e)
      (h : SubstEnv.AgreesBelow nt θ τ) : Eff.rawBind θ e = Eff.rawBind τ e := by
    cases e
    simp only [Eff.rawBind, h.rows, h.ranges, rawBindTys_agrees ha h]
end

theorem Ty.subst_shiftTypes {nt nv : Nat} {a : Ty} (hw : a.WF 0 nt nv) (ts : List Ty) (es : List Eff)
    (hn : nt ≤ ts.length) (k c : Nat) :
    shiftTypes k c (a.subst ts es) = a.subst (ts.map (shiftTypes k c)) (es.map (shiftRowsTypes k c)) := by
  rw [Ty.subst, Ty.substAt, substTypeAt, Ty.shiftTypes_bind]
  apply congrArg Ty.norm
  apply Ty.rawBind_agrees hw
  constructor
  · intro i hi
    have hit : i<ts.length := by omega
    simp only [SubstEnv.mapTypeIndices, typeEnvAt, List.length_map, Nat.not_lt_zero, ↓reduceIte,
      Nat.sub_zero, hit, shiftTypes_zero, List.getElem?_map]
    cases hg : ts[i]? with
    | none => exact False.elim (by have hh := List.getElem?_eq_none_iff.mp hg; omega)
    | some t => simp only [Option.getD_some, Option.map_some]
  · simp only [SubstEnv.mapTypeIndices, typeEnvAt, List.map_map, Function.comp_def, shiftRowsTypes_zero]
  · rfl
  · rfl

end Benitoite.Release.Refinement
