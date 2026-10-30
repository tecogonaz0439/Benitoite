import Benitoite.Release.Refinement.Kinds

/-!
# 宣言した kind と注釈の出現の照合

型パラメータの宣言から kind の列を得る。辞書の引数では型クラスが
宣言した kind を使い、注釈の出現と実際の適用の形を検査する。
-/
namespace Benitoite.Release.Refinement

mutual
  def Ty.kindUses (P : Program) : Ty → List (Nat × TyKind)
    | .tvar i => [(i, .value)]
    | .tapp i as => (i, .constructor as.length) :: kindUsesTys P as
    | .data _ as | .external _ as => kindUsesTys P as
    | .list a | .reference a | .lazy a | .set a | .refined a _ => a.kindUses P
    | .dict cl a => match P.classes cl with
      | none => []
      | some cd => match cd.argumentKind with
        | .value => a.kindUses P
        | .constructor n => match a with | .tvar i => [(i, .constructor n)] | _ => []
    | .fn _ ps r e => kindUsesTys P ps ++ r.kindUses P ++ kindUsesEff P e
    | .dependentFn t => Tel.kindUses P t
    | .cont a b e => a.kindUses P ++ b.kindUses P ++ kindUsesEff P e
    | .map a b => a.kindUses P ++ b.kindUses P
    | _ => []
  def Tel.kindUses (P : Program) : Tel → List (Nat × TyKind)
    | .done r e => r.kindUses P ++ kindUsesEff P e
    | .param _ a t => a.kindUses P ++ Tel.kindUses P t
  def kindUsesTys (P : Program) : List Ty → List (Nat × TyKind)
    | [] => []
    | a :: as => a.kindUses P ++ kindUsesTys P as
  def kindUsesEff (P : Program) : Eff → List (Nat × TyKind)
    | .mk _ fs => kindUsesTys P fs
end

theorem Ty.kindUses_dict_tvar {P cl cd i} (hc : P.classes cl = some cd) :
    (Ty.dict cl (.tvar i)).kindUses P = [(i, cd.argumentKind)] := by
  simp only [Ty.kindUses, hc]
  cases cd.argumentKind <;> rfl


def Def.declaredKinds (d : Def) : KindCtx := d.tparams.map TParamDecl.kind

def Def.kindUses (P : Program) (d : Def) : List (Nat × TyKind) :=
  kindUsesTys P d.params ++ d.ret.kindUses P ++ kindUsesEff P d.eff

/-- 出現との一致に加えて、実際の注釈も検査する。未宣言のクラス、
値を渡した構成子位置、ctorのarityの不一致を出現なしとして通さない。 -/
def Def.KindWF (P : Program) (d : Def) (K : KindCtx) : Prop :=
  K = d.declaredKinds ∧
    (∀ p ∈ d.kindUses P, K[p.1]? = some p.2) ∧
    kindsList P K d.params ∧ d.ret.HasKind P K .value ∧ kindsEff P K d.eff

noncomputable def Def.kinds (P : Program) (d : Def) : Option KindCtx := by
  classical
  exact if d.KindWF P d.declaredKinds then some d.declaredKinds else none

theorem Def.kinds_sound {P d K} (h : Def.kinds P d = some K) : Def.KindWF P d K := by
  unfold Def.kinds at h
  split at h
  · rename_i hw
    cases h
    exact hw
  · cases h

theorem Def.kinds_complete {P d K} (h : Def.KindWF P d K) : Def.kinds P d = some K := by
  classical
  have he := h.1
  subst K
  simp only [Def.kinds, ite_eq_left h]

theorem Def.kinds_eq_some_iff {P d K} : Def.kinds P d = some K ↔ Def.KindWF P d K :=
  ⟨Def.kinds_sound, Def.kinds_complete⟩

theorem Def.kinds_declared {P d K} (h : Def.kinds P d = some K) : K = d.declaredKinds :=
  (Def.kinds_sound h).1

theorem Def.kinds_length {P d K} (h : Def.kinds P d = some K) : K.length = d.tparams.length := by
  rw [Def.kinds_declared h]
  exact List.length_map _

theorem Def.kinds_none_of_conflict {P d i k} (hu : (i,k) ∈ d.kindUses P)
    (hne : d.declaredKinds[i]? ≠ some k) : Def.kinds P d = none := by
  cases h : Def.kinds P d with
  | none => rfl
  | some K =>
    have hs := Def.kinds_sound h
    exact False.elim (hne (hs.1 ▸ hs.2.1 _ hu))

theorem Def.kinds_none_of_bad_annotation {P d} (hbad :
    ¬ (kindsList P d.declaredKinds d.params ∧ d.ret.HasKind P d.declaredKinds .value ∧ kindsEff P d.declaredKinds d.eff)) :
    Def.kinds P d = none := by
  cases h : Def.kinds P d with
  | none => rfl
  | some K =>
    have hs := Def.kinds_sound h
    exact False.elim (hbad (hs.1 ▸ hs.2.2))

end Benitoite.Release.Refinement
