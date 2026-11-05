import Benitoite.Release.Refinement.Ground

/-! # Atの結果の宣言と閉じた保持値 -/
namespace Benitoite.Release.Refinement

def Eff.single (l : EffName) : Eff := .mk (fun a => decide (a = .name l .top)) []

def atErrorType : Ty := .data "Scope.ScopeError" []
def atDetailType : Ty := .data "Scope.AtDetail" []
/-- `Scope.ScopeError.At` の欄。九欄の公開形の record 一つである。 -/
def atErrorFields : List Ty := [atDetailType]

/-- At の診断の公開の宣言の全体と標準の Option を、同じ lookup と arity で持つ。 -/
structure Program.HasScopePublic (P : Program) : Prop where
  arity : ∀ d ∈ ScopePublic.all, P.DataArity d.name 0
  cons : ∀ c d as, (c, d, as) ∈ ScopePublic.constructors →
    P.cons c = some ⟨d, 0, as.map ScopePublic.PublicTy.ty⟩
  optionArity : P.DataArity "Option" 1
  optionSome : P.cons "Option.Some" = some ⟨"Option", 1, [.tvar 0]⟩
  optionNone : P.cons "Option.None" = some ⟨"Option", 1, []⟩

/-- At の結果の誤り型は公開の ScopeError であり、同じ P が At の詳細の公開の宣言を持つ。 -/
def ResultShape.StandardError (P : Program) (shape : ResultShape) : Prop :=
  shape.errorType = atErrorType ∧ P.DataArity "Scope.ScopeError" 0 ∧
  (∃ cd, P.cons "Scope.ScopeError.At" = some cd ∧ cd.data = "Scope.ScopeError" ∧
    cd.ntys = 0 ∧ cd.args = atErrorFields) ∧ P.HasScopePublic

structure ResultShape.Declared (P : Program) (shape : ResultShape) : Prop where
  standard : shape.StandardError P
  arity : P.DataArity shape.owner 2
  distinct : shape.ok ≠ shape.error
  okDecl : ∃ cd, P.cons shape.ok = some cd ∧ cd.data = shape.owner ∧
    cd.ntys = 2 ∧ cd.args = [.tvar 0]
  errorDecl : ∃ cd, P.cons shape.error = some cd ∧ cd.data = shape.owner ∧
    cd.ntys = 2 ∧ cd.args = [.tvar 1]

theorem ResultShape.Declared.errorType_eq {P : Program} {shape : ResultShape} (h : shape.Declared P) :
    shape.errorType = atErrorType := h.standard.1

theorem ResultShape.Declared.errorType_declared {P : Program} {shape : ResultShape} {C Γ} (h : shape.Declared P) :
    Ty.Declared P C Γ shape.errorType := by rw [h.errorType_eq]; exact ⟨⟨0, h.standard.2.1, rfl⟩, trivial⟩

theorem ResultShape.Declared.error_data {P : Program} {shape : ResultShape} {Γ : Ctx} {detail : AtError}
    (h : shape.Declared P) : Term.HasData P Γ
      (.dataValue "Scope.ScopeError.At" [some detail.publicTree.toTerm]) "Scope.ScopeError" [] := by
  obtain ⟨cd, hc, hd, hn, ha⟩ := h.standard.2.2.1
  exact .value hc hd hn (by simp [ha, atErrorFields])

namespace ScopePublic
theorem lookup_mem {c : ConName} {d : DataName} {as : List PublicTy}
    (h : lookup c = some (d, as)) : (c, d, as) ∈ constructors := by
  unfold lookup at h
  obtain ⟨before, after, eq, _⟩ := List.lookup_eq_some_iff.mp h
  rw [eq]
  exact List.mem_append_right _ List.mem_cons_self

theorem lookup_cons {P : Program} (hp : P.HasScopePublic) {c : ConName} {d : DataName} {as : List PublicTy}
    (h : lookup c = some (d, as)) : P.cons c = some ⟨d, 0, as.map PublicTy.ty⟩ :=
  hp.cons c d as (lookup_mem h)

mutual
  /-- 型付きの公開の値の観測は、同じ宣言の項である。 -/
  theorem PublicTree.Typed.declared {P : Program} {C : TypeCtx} {Γ : Ctx} (hp : P.HasScopePublic)
      {t : PublicTree} {a : PublicTy} (h : t.Typed a) : Term.Declared P C Γ t.toTerm := by
    match h with
    | .text _ | .integer _ | .bytes _ => trivial
    | .list _ hs => exact PublicTree.TypedEach.declared hp hs
    | .none _ => exact ⟨trivial, _, hp.optionNone, rfl⟩
    | .some _ hx => exact ⟨⟨PublicTree.Typed.declared hp hx, trivial⟩, _, hp.optionSome, rfl⟩
    | .con hl hs =>
      exact ⟨PublicTree.TypedAll.declared hp hs, _, lookup_cons hp hl,
        by simpa only [List.length_map] using PublicTree.TypedAll.slots_length hs⟩
  theorem PublicTree.TypedAll.declared {P : Program} {C : TypeCtx} {Γ : Ctx} (hp : P.HasScopePublic)
      {ts : List PublicTree} {as : List PublicTy} (h : PublicTree.TypedAll ts as) :
      declaredSlots P C Γ (PublicTree.toTermSlots ts) := by
    match h with
    | .nil => trivial
    | .cons hx hs => exact ⟨PublicTree.Typed.declared hp hx, PublicTree.TypedAll.declared hp hs⟩
  theorem PublicTree.TypedEach.declared {P : Program} {C : TypeCtx} {Γ : Ctx} (hp : P.HasScopePublic)
      {ts : List PublicTree} {a : PublicTy} (h : PublicTree.TypedEach ts a) :
      declaredSlots P C Γ (PublicTree.toTermSlots ts) := by
    match h with
    | .nil => trivial
    | .cons hx hs => exact ⟨PublicTree.Typed.declared hp hx, PublicTree.TypedEach.declared hp hs⟩
  theorem PublicTree.TypedAll.slots_length {ts : List PublicTree} {as : List PublicTy}
      (h : PublicTree.TypedAll ts as) : (PublicTree.toTermSlots ts).length = as.length := by
    match h with
    | .nil => rfl
    | .cons _ hs => simp only [PublicTree.toTermSlots, List.length_cons, PublicTree.TypedAll.slots_length hs]
end
end ScopePublic

/-- 九欄の公開形は、公開形を持たない診断の固定の値を含め、AtDetail の型を持つ。 -/
theorem Detail.publicTree_typed (d : AtError) : d.publicTree.Typed (.data "Scope.AtDetail") := by
  unfold Detail.publicTree
  cases h : ScopePublic.detailTree? ScopePublic.inputOfVal d with
  | none => exact ScopePublic.unreachable_typed
  | some t =>
    refine ScopePublic.detail_typed (fun v u hv => ?_) h
    unfold ScopePublic.inputOfVal at hv
    split at hv <;> cases hv
    · exact ScopePublic.inputText_typed _
    · exact ScopePublic.inputPattern_typed _

theorem ResultShape.Declared.error_observation_declared {P : Program} {shape : ResultShape} {C Γ} {detail : AtError}
    (h : shape.Declared P) : Term.Declared P C Γ
      (.dataValue "Scope.ScopeError.At" [some detail.publicTree.toTerm]) := by
  obtain ⟨cd, hc, _, _, ha⟩ := h.standard.2.2.1
  exact ⟨⟨detail.publicTree_typed.declared h.standard.2.2.2, trivial⟩, cd, hc, by simp [ha, atErrorFields]⟩


end Benitoite.Release.Refinement
