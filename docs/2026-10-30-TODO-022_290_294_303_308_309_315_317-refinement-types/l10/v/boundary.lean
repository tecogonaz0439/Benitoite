import Lean
import Benitoite.Release.Refinement.ValueFacts

open Benitoite Benitoite.Release.Refinement
namespace L10VBoundary

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

theorem contra_valid : (single .contravariant fieldContra).VarianceValid := by
  apply single_valid
  · constructor
    · simp [fieldContra, pureEff, Ty.WF, Ty.WFList, Eff.WF, NamesWF, Eff.Canonical, Eff.norm, Ty.normTys]
    · trivial
    · trivial
  · simp [fieldContra, Ty.HasKind, kindsList, kindsEff, pureEff, NamesWF]
  · exact ⟨⟨⟨.contravariant, rfl, trivial⟩, trivial⟩, trivial, trivial⟩
  · exact Or.inr (Or.inl (Or.inl rfl))

theorem inv_valid : (single .invariant fieldInv).VarianceValid := by
  apply single_valid
  · exact ⟨by simp [fieldInv, Ty.WF], trivial, trivial⟩
  · trivial
  · exact ⟨.invariant, rfl, trivial⟩
  · exact Or.inl rfl

-- Reference と負の位置を共変とする表を、変性の検証で拒む。
theorem reference_co_rejected : ¬ (single .covariant fieldInv).VarianceValid := by
  intro h
  have hv := ((h.2 "C" (cd fieldInv) (by simp [single])).2 fieldInv List.mem_cons_self).2.2
  simp [single, Program.varianceFor, cd, info, fieldInv, Ty.VarianceOK, Variance.accepts] at hv

theorem negative_co_rejected : ¬ (single .covariant fieldContra).VarianceValid := by
  intro h
  have hv := ((h.2 "C" (cd fieldContra) (by simp [single])).2 fieldContra List.mem_cons_self).2.2
  simp [single, Program.varianceFor, cd, info, fieldContra, Ty.VarianceOK, varianceTysOK,
    Polarity.flip, Variance.accepts] at hv

def readTy : Ty := .scoped "Path" .path .top
def wideTy : Ty := .opaque "Path" .top

theorem covariant_use : Ty.LeQ (single .covariant fieldCo) [] []
    (.data "Box" [readTy]) (.data "Box" [wideTy]) := by
  apply Ty.LeQ.data
  simpa [single, Program.varianceFor, info] using
    (TypeArgsLe.covariant_cons Ty.LeQ.scoped_forget TypeArgsLe.nil :
      TypeArgsLe (single .covariant fieldCo) [] [] [.covariant] [readTy] [wideTy])

theorem contravariant_use : Ty.LeQ (single .contravariant fieldContra) [] []
    (.data "Box" [wideTy]) (.data "Box" [readTy]) := by
  apply Ty.LeQ.data
  simpa [single, Program.varianceFor, info] using
    (TypeArgsLe.contravariant_cons Ty.LeQ.scoped_forget TypeArgsLe.nil :
      TypeArgsLe (single .contravariant fieldContra) [] [] [.contravariant] [wideTy] [readTy])

theorem invariant_use : Ty.LeQ (single .invariant fieldInv) [] []
    (.data "Box" [wideTy]) (.data "Box" [wideTy]) := by
  apply Ty.LeQ.data
  simpa [single, Program.varianceFor, info] using
    (TypeArgsLe.invariant_cons rfl TypeArgsLe.nil :
      TypeArgsLe (single .invariant fieldInv) [] [] [.invariant] [wideTy] [wideTy])

-- 非出現を共変と宣言した metadata も拒む。
theorem unused_co_rejected : ¬ (single .covariant (.base .unit)).VarianceValid := by
  intro h
  have he := (h.1 "Box" (info .covariant) (by simp [single])).2.1 0 .covariant rfl
  have hn : ¬ (single .covariant (.base .unit)).ParamOccursInFields "Box" 0 := by
    rintro ⟨c, dec, a, hc, _, ha, ho⟩
    by_cases hC : c = "C"
    · subst c
      simp only [single, ↓reduceIte, Option.some.injEq] at hc
      subst dec
      cases List.mem_singleton.mp ha
      exact ho
    · simp [single, hC] at hc
  cases he hn

def token : Program := {
  defs := fun _ => none
  cons := fun c => if c = "Token" then some ⟨"Token", 1, []⟩ else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  dataInfo := fun d => if d = "Token" then some (info .invariant) else none
}

theorem token_valid : token.VarianceValid := by
  constructor
  · intro d inf hi
    by_cases hd : d = "Token"
    · subst d
      simp only [token, ↓reduceIte, Option.some.injEq] at hi
      subst inf
      refine ⟨rfl, ?_, by simp [info], by simp [info]⟩
      intro i v hv _
      cases i with
      | zero => exact Option.some.inj hv |>.symm
      | succ i => simp [info] at hv
    · simp [token, hd] at hi
  · intro c dec hc
    by_cases hC : c = "Token"
    · subst c
      simp only [token, ↓reduceIte, Option.some.injEq] at hc
      subst dec
      refine ⟨?_, by simp⟩
      intro inf hi
      simp only [token, ↓reduceIte, Option.some.injEq] at hi
      subst inf
      rfl
    · simp [token, hC] at hc

theorem token_read_write_rejected : ¬ Ty.LeQ token [] []
    (.data "Token" [.opaque "Read" .top]) (.data "Token" [.opaque "Write" .top]) := by
  intro h
  obtain ⟨bs, hb, hs⟩ := h.dataCore rfl
  have he := (Ty.data.inj hb).2
  subst bs
  simp only [token, Program.varianceFor, info, ↓reduceIte] at hs
  cases hs with
  | invariant_cons he _ =>
    have hh : ("Read" : String) = "Write" := (Ty.opaque.inj he).1
    exact (by decide : ("Read" : String) ≠ "Write") hh

-- 検証から取り出した出現条件を、本番の欄の単調性へ渡す。
theorem co_field_sound {Γ Φ as bs}
    (oa : ∀ t ∈ as, Ordinary t) (ob : ∀ t ∈ bs, Ordinary t)
    (args : TypeArgsLe (single .covariant fieldCo) Γ Φ [.covariant] as bs) :
    Ty.LeQ (single .covariant fieldCo) Γ Φ (fieldCo.subst as []) (fieldCo.subst bs []) := by
  have checked := ((co_valid.2 "C" (cd fieldCo) (by simp [single])).2 fieldCo List.mem_cons_self).2.2
  exact variance_field_mono _ Γ Φ [.covariant] fieldCo as bs
    (by simpa [single, Program.varianceFor, cd, info] using checked)
    (by simp [fieldCo, Ty.WF]) trivial oa ob args

-- 旧判断は P を持たず、その導出は任意の同じ P の下へ埋め込める。
theorem legacy_without_program (P : Program) (a b : Release.Ty) (h : Release.Ty.Le a b) :
    Ty.LeQ P [] [] (embedTy a) (embedTy b) := embedLe h

-- Byte と七幅の整数は、述語では同じ数学上の整数 sort を使う。
theorem all_integer_sorts :
    ([.base .integer, .base .integer8, .base .integer16, .base .integer32,
      .base .unsignedInteger16, .base .unsignedInteger32, .base .unsignedInteger64,
      .base .byte] : List Ty).map Ty.sort? = List.replicate 8 (some Sort.integer) := rfl

theorem byte_integer8_predicate :
    Pred.Sorted [some (.base .byte), some (.base .integer8)] none (.le (.var 0) (.var 1)) := by
  constructor
  · exact ⟨⟨.base .byte, rfl, by intro b t e h; cases h⟩, .base .byte, rfl, rfl⟩
  · exact ⟨⟨.base .integer8, rfl, by intro b t e h; cases h⟩, .base .integer8, rfl, rfl⟩

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
  apply (built (B := B) (Ψ := Ψ) (Q := Q)).con_field_by_type hc rfl rfl co_valid
  · intro t ht; have he := List.mem_singleton.mp ht; subst t
    simp [posT, intT, Ordinary, Ty.core]
  · intro t ht; have he := List.mem_singleton.mp ht; subst t
    exact ann_int _ _
  · intro t ht; have he := List.mem_singleton.mp ht; subst t
    simp [intT, Ordinary, Ty.core, Ty.norm]

theorem supplied_sourceField_and_inputs (B : Builtins) (Ψ : StoreTy) (Q : Release.NoFailCtx) :
    Ty.Annotation Pb [] Γ0 (fieldCo.subst [posT] []) ∧
      Ty.Annotation Pb [] Γ0 (fieldCo.subst [intT] []) ∧
      VarianceSubstInput Pb [] Γ0 (Pb.varianceFor "Box" 1) (Ty.normTys [posT]) [intT] := by
  have hc : Pb.cons "C" = some (cd fieldCo) := by simp [Pb, single]
  apply (built (B := B) (Ψ := Ψ) (Q := Q)).constructor_field_inputs (i := 0) hc rfl rfl co_valid
  · intro t ht; have he := List.mem_singleton.mp ht; subst t
    simp [posT, intT, Ordinary, Ty.core]
  · intro t ht; have he := List.mem_singleton.mp ht; subst t
    exact ann_int _ _
  · intro t ht; have he := List.mem_singleton.mp ht; subst t
    simp [intT, Ordinary, Ty.core, Ty.norm]

-- 観測で捨てた List の要素型を復元せず、型置換後も widen を読む。
theorem widened_type_substitution {P Γ Δ t d xs bs f}
    (h : Term.HasData P Γ t d xs) (hw : DataObservationLe P d xs bs)
    (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) :
    Term.HasData P Δ t d (bs.map (Ty.bind (.typesOnly f))) :=
  (h.widen hw).typesOnly valid hm

-- 推移の中間の型引数 ms に形成も Ordinary も要求しない。
theorem field_mono_trans {P Γ Φ vs a as ms bs}
    (checked : Ty.VarianceOK P vs .positive a) (wf : a.WF 0 vs.length 0) (sorted : a.Sorted [])
    (oa : ∀ t ∈ as, Ordinary t) (ob : ∀ t ∈ bs, Ordinary t)
    (hm : TypeArgsLe P Γ Φ vs as ms) (hn : TypeArgsLe P Γ Φ vs ms bs) :
    Ty.LeQ P Γ Φ (a.subst as []) (a.subst bs []) :=
  variance_field_mono P Γ Φ vs a as bs checked wf sorted oa ob (hm.trans hn)

end L10VBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (Name.mkSimple "L10VBoundary").isPrefixOf name then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
