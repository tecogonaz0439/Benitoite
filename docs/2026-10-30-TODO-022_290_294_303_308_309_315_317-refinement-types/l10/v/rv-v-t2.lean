import Lean
import Benitoite.Release.Refinement.ValueFacts

open Benitoite Benitoite.Release.Refinement
namespace RV

abbrev pureEff : Eff := .mk (fun _ => false) []
def fieldCo : Ty := .tvar 0
def fieldContra : Ty := .fn ["x"] [.tvar 0] (.base .unit) pureEff
def fieldInv : Ty := .reference (.tvar 0)
def cd (field : Ty) : ConDecl := ⟨"Box", 1, [field]⟩
def info (v : Variance) : DataVarianceDecl := ⟨1, [v], [], []⟩
def single (v : Variance) (field : Ty) : Program := {
  defs := fun _ => none
  cons := fun c => if c = "C" then some (cd field) else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  dataInfo := fun d => if d = "Box" then some (info v) else none
}

theorem single_valid (v : Variance) (field : Ty)
    (ha : Ty.Annotation (single v field) [{}] [] field)
    (hk : field.HasKind (single v field) [.value] .value)
    (hv : field.VarianceOK (single v field) [v] .positive)
    (occurs : v = .invariant ∨ field.ParamOccurs 0) :
    (single v field).VarianceValid := by
  constructor
  · intro d inf hi
    by_cases hd : d = "Box"
    · subst d
      simp only [single, ↓reduceIte, Option.some.injEq] at hi
      subst inf
      refine ⟨rfl, ?_, by simp [info], by simp [info]⟩
      intro i w hw hno
      cases i with
      | zero =>
        cases Option.some.inj hw
        rcases occurs with he | ho
        · exact he
        · exact False.elim (hno ⟨"C", cd field, field, by simp [single], rfl, List.mem_cons_self, ho⟩)
      | succ i => simp [info] at hw
    · simp [single, hd] at hi
  · intro c dec hc
    by_cases hC : c = "C"
    · subst c
      simp only [single, ↓reduceIte, Option.some.injEq] at hc
      subst dec
      constructor
      · intro inf hi
        simp only [single, cd, ↓reduceIte, Option.some.injEq] at hi
        subst inf
        rfl
      · intro a ha'
        have he : a = field := List.mem_singleton.mp ha'
        subst a
        refine ⟨ha, hk, ?_⟩
        simpa [single, cd, Program.varianceFor, info] using hv
    · simp [single, hC] at hc

-- 検査器が共変・反変・不変の宣言を受ける。
theorem co_valid : (single .covariant fieldCo).VarianceValid := by
  apply single_valid
  · exact ⟨by simp [fieldCo, Ty.WF], trivial, trivial⟩
  · trivial
  · exact ⟨.covariant, rfl, trivial⟩
  · exact Or.inr rfl

/-! 正例: 実際の値が V_Con → V_Sub を通り、con_field_by_type が広い型の欄を返す。 -/
def q : Pred := .le (.integer 0) (.var 0)
def intT : Ty := .base .integer
def posT : Ty := .refined intT q
def Pb := single .covariant fieldCo
def Γ0 : Ctx := [some posT]

theorem arity : Pb.DataArity "Box" 1 := by
  refine ⟨⟨"C", cd fieldCo, by simp [Pb, single], rfl⟩, ?_⟩
  intro c dec hc _
  by_cases hC : c = "C"
  · subst c; simp only [Pb, single, ↓reduceIte, Option.some.injEq] at hc; subst dec; rfl
  · simp [Pb, single, hC] at hc

theorem q_sorted (Γ : Ctx) : q.Sorted Γ (some intT) := by
  refine ⟨⟨trivial, rfl⟩, ⟨?_, ?_⟩⟩
  · exact ⟨intT, rfl, by simp [Ordinary, intT, Ty.core]⟩
  · exact ⟨intT, rfl, rfl⟩

theorem ann_int (C Γ) : Ty.Annotation Pb C Γ intT := ⟨trivial, trivial, trivial⟩

theorem ann_pos (C) (Γ : Ctx) : Ty.Annotation Pb C Γ posT := by
  refine ⟨⟨trivial, ?_, ?_⟩, ⟨trivial, q_sorted Γ⟩, ⟨trivial, ?_⟩⟩
  · simp [q, Pred.WF, Pred.VarsIn, Term.VarsIn]
  · simp [intT, Ty.NotContCore, Ty.core]
  · exact ⟨trivial, ⟨intT, rfl, by simp [Ordinary, intT, Ty.core]⟩⟩

theorem ann_box (C Γ a) (ha : Ty.Annotation Pb C Γ a) : Ty.Annotation Pb C Γ (.data "Box" [a]) := by
  exact ⟨⟨ha.wf, trivial⟩, ⟨ha.sorted, trivial⟩, ⟨⟨1, arity, rfl⟩, ha.declared, trivial⟩⟩

theorem subst1 (a : Ty) : fieldCo.subst [a] [] = a.norm := by
  simp [fieldCo, Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, shiftTypes_zero]

theorem le_arg : Ty.LeQ Pb Γ0 [] posT.norm intT.norm := Ty.LeQ.norm .forget

/-- 値 C(x) を型 Box[Integer{0≤self}] で作り、Box[Integer] へ広げる。 -/
theorem built {B Ψ Q} :
    HasTypeVQ Pb B Ψ Q [] Γ0 [] (.con "C" [posT] [.var 0]) (.data "Box" [intT]) := by
  have hv : HasTypeVQ Pb B Ψ Q [] Γ0 [] (.var 0) posT :=
    .V_Var rfl (by simp [Ordinary, posT, intT, Ty.core])
  have hc : HasTypeVQ Pb B Ψ Q [] Γ0 [] (.con "C" [posT] [.var 0]) (.data "Box" [posT]) := by
    refine .V_Con (cd := cd fieldCo) (by simp [Pb, single]) rfl ?_ ?_ ?_ (ann_box _ _ _ (ann_pos _ _))
    · refine ⟨rfl, [], rfl, ?_⟩
      intro i a k ha hk
      cases i with
      | zero =>
        cases Option.some.inj ha; cases Option.some.inj hk
        exact ⟨trivial, by simp [intT, Ty.NotContCore, Ty.core]⟩
      | succ i => simp at ha
    · intro t ht
      simp only [cd, List.mem_singleton] at ht
      subst t; simp [fieldCo, Ty.WF, cd]
    · simp only [cd, List.map_cons, List.map_nil, subst1]
      exact .cons (.V_Normal hv) .nil
  have hann := ann_box [] Γ0 intT (ann_int [] Γ0)
  refine .V_Sub hc (.data ?_) hann.wf hann.sorted hann.declared
  have hv : Pb.varianceFor "Box" 1 = [.covariant] := by simp [Pb, single, Program.varianceFor, info]
  have hh : TypeArgsLe Pb Γ0 [] [.covariant] [posT] [intT] := .covariant_cons .forget .nil
  simpa only [List.length_cons, List.length_nil, Nat.zero_add, hv] using hh

theorem field_widened {B Ψ Q} :
    ∃ v, ([.var 0] : List Val)[0]? = some v ∧
      HasTypeVQ Pb B Ψ Q [] Γ0 [] v (fieldCo.subst [intT] []) := by
  have hc : Pb.cons "C" = some (cd fieldCo) := by simp [Pb, single]
  refine (built (B := B) (Ψ := Ψ) (Q := Q)).con_field_by_type hc rfl rfl co_valid ?_ ?_ ?_
  · simp only [subst1]; exact (ann_pos _ _).norm
  · simp only [subst1]; exact (ann_int _ _).norm
  · have hv : Pb.varianceFor "Box" 1 = [.covariant] := by simp [Pb, single, Program.varianceFor, info]
    refine ⟨?_, ?_, ?_⟩
    · simp [Ty.normTys, hv, cd]
    · simp [hv, cd]
    · intro t ht
      simp only [cd, Ty.normTys, List.cons_append, List.nil_append, List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl
      · exact (ann_pos _ _).norm
      · exact (ann_int _ _).norm

#print axioms field_widened
end RV
