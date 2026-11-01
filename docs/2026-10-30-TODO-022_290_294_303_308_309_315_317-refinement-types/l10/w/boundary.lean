import Lean
import Benitoite.Release.Refinement.ProgramWellFormed

/-! 本番の二つの入口に、非空の表と条件を壊す入力を渡す。 -/
namespace Benitoite.Release.Refinement.L10WBoundary
open Benitoite.Release.Refinement
noncomputable section

def unit : Ty := .base .unit
def box : ConDecl := ⟨"Box", 1, [.tvar 0]⟩
def info : DataVarianceDecl := ⟨1, [.covariant], [unit], [(.positive, .tvar 0)]⟩
def identity : Def := ⟨[], 0, ["x"], [unit], unit, Eff.empty, .escape (.var 0)⟩
-- 自身の型パラメータは0、クラス引数は1である。
def method : MethSig := ⟨[⟨({} : TParam), .value⟩], 0, ["x"], [.tvar 1], .tvar 1, Eff.empty⟩
def parent : ClassDecl := ⟨.value, [], fun _ => none⟩
def klass : ClassDecl := ⟨.value, ["Parent"], fun m => if m = "id" then some method else none⟩
def implDecl : ImplDecl := ⟨[({} : TParam)], [("Parent", 0)], "Class", .tvar 0,
  fun s => if s = "Parent" then some (.var 0) else none,
  fun m => if m = "id" then some (.ret (.var 0)) else none⟩
def operation : OpDecl := ⟨"Effect", [], ["x"], [unit], unit, []⟩
def externalEntry : ExternalKey × ExternalDecl :=
  (.type (.mk 0), .type ⟨.mk 0, .mk 0, "Handle", 0, 0⟩)
def program : Program := {
  defs := fun f => if f = "identity" then some identity else none
  cons := fun c => if c = "Box.Box" then some box else none
  ops := fun o => if o = "Effect.op" then some operation else none
  effects := fun e => if e = "Effect" then some ["Effect.op"] else none
  classes := fun c => if c = "Class" then some klass else if c = "Parent" then some parent else none
  impls := fun i => if i = "Instance" then some implDecl else none
  externals := [externalEntry]
  dataInfo := fun d => if d = "Box" then some info else none }

variable (B : Builtins)

theorem annotation_unit (P : Program) (C : List TParam) (Γ : Ctx) : Ty.Annotation P C Γ unit := by
  constructor <;> trivial
theorem annotation_tvar (P : Program) (C : List TParam) (Γ : Ctx) (i : Nat) (h : i < C.length) :
    Ty.Annotation P C Γ (.tvar i) := ⟨h, trivial, trivial⟩

@[simp] theorem annotation_iff (P : Program) (C : List TParam) (Γ : Ctx) (a : Ty) :
    Ty.Annotation P C Γ a ↔ a.WF 0 C.length Γ.length ∧ a.Sorted Γ ∧ a.Declared P C Γ :=
  ⟨fun h => ⟨h.wf, h.sorted, h.declared⟩, fun h => ⟨h.1, h.2.1, h.2.2⟩⟩

theorem variance : program.VarianceValid := by
  constructor
  · intro d inf h
    simp only [program] at h
    split at h <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst inf
    refine ⟨rfl, ?_, ?_, ?_⟩
    · intro i v hv hn
      cases i with
      | succ i => simp [info] at hv
      | zero =>
        simp only [info, List.getElem?_cons_zero, Option.some.injEq] at hv
        subst v
        exact False.elim (hn ⟨"Box.Box", box, .tvar 0, by simp [program], rfl, by simp [box], by trivial⟩)
    · intro a ha
      simp only [info, List.mem_singleton] at ha
      subst a; trivial
    · intro item hi
      simp only [info, List.mem_singleton] at hi
      subst item
      exact ⟨.covariant, rfl, trivial⟩
  · intro c cd hc
    simp only [program] at hc
    split at hc <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst cd
    constructor
    · intro inf hi
      have he : inf = info := by simpa [program, box] using hi.symm
      subst inf; rfl
    · intro a ha
      simp only [box, List.mem_singleton] at ha
      subst a
      refine ⟨annotation_tvar _ _ _ _ (by simp [box]), ?_, ?_⟩
      · rfl
      · refine ⟨.covariant, ?_, trivial⟩
        simp [Program.varianceFor, program, info, box]

theorem external : program.ExternalWF := by
  constructor
  · simp [program]
  · intro key decl h
    simp only [program, List.mem_singleton] at h
    cases h
    exact ⟨rfl, rfl⟩

theorem def_typed : identity.WellTyped program B := by
  refine ⟨by simp [NamesWF, identity], ?_, ?_, .param (.done (.C_Escape (.V_Var rfl ?_) (annotation_unit _ _ _)))⟩
  · exact ⟨trivial, trivial, trivial⟩
  · constructor <;> simp [Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys, identity, Def.tel, signatureTel, unit]
  · intro b t e h; cases h

-- 型の置換と、実装の辞書の位置を空ける値の移動をそれぞれ使う。
theorem method_contract :
    Tel.shiftV implDecl.dictTys.length 0
      (Tel.bind (typeEnvAt method.tparams.length [implDecl.target] []) method.tel) =
      .param "x" (.tvar 1) (.done (.tvar 1) Eff.empty) := by
  simp [implDecl, method, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, shiftTypes, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Tel.shiftV, Ty.shiftV, Eff.shiftV, shiftVTys, ImplDecl.dictTys]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

theorem impl_typed : implDecl.WellTyped program B := by
  refine ⟨klass, by simp [program, implDecl], ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "id" <;> simp [implDecl, klass, h]
  · intro s; by_cases h : s = "Parent" <;> simp [implDecl, klass, h]
  · rfl
  · intro a ha
    simp [ImplDecl.dictTys, implDecl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, implDecl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 0), by simp [implDecl, *], by simp [NamesWF, method], ?_⟩
    rw [method_contract]
    exact .param (.done (.C_Return (.V_Var rfl (by intro b t e h; cases h))))
  · intro s hs
    simp only [klass, List.mem_singleton] at hs
    subst s
    refine ⟨.var 0, by simp [implDecl], .V_Var ?_ ?_⟩
    · rfl
    · intro b t e h; cases h

theorem wellTyped : program.WellTyped B := by
  refine ⟨variance, external, ?_, ?_⟩
  · intro f d hd
    simp only [program] at hd
    split at hd <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst d; exact def_typed B
  · intro i id hi
    simp only [program] at hi
    split at hi <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst id; exact impl_typed B

theorem wellFormed (B : Builtins) : program.WellFormed := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, external⟩
  · intro f d hd
    simp only [program] at hd
    split at hd <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst d
    refine ⟨by simp [NamesWF, identity], ?_, by simp [identity, Def.ntys, Comp.SourceScoped, Val.SourceScoped]⟩
    refine ⟨?_, ?_, (def_typed B).2.1, (def_typed B).2.2.1⟩
    · exact ⟨(def_typed B).2.2.1.wf, by simp [identity, Def.tel, signatureTel, Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Ty.RowsInList, unit, Eff.empty], by simp [identity, Def.tel, signatureTel, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, unit, Eff.empty]⟩
    · simp [identity, Def.tel, signatureTel, Tel.RowsIn, Ty.RowsIn, Eff.RowsIn, Ty.RowsInList, Eff.empty, unit]
  · intro c cd hc
    simp only [program] at hc
    split at hc <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst cd
    constructor
    · refine ⟨⟨"Box.Box", box, by simp [program], rfl⟩, ?_⟩
      intro c cd hc hd
      simp only [program] at hc
      split at hc <;> simp_all [box]
    · intro a ha
      simp only [box, List.mem_singleton] at ha
      subst a
      exact ⟨⟨by simp [Ty.WF, box], trivial, trivial⟩, annotation_tvar _ _ _ _ (by simp [box]), rfl⟩
  · intro o od ho
    simp only [program] at ho
    split at ho <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst od
    refine ⟨by simp [NamesWF, operation], ?_, rfl, ?_⟩
    · intro p hp; cases hp
    · constructor <;> simp [Ty.SourceScoped, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, RangeIx.WF, Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys, signatureTel, unit, operation, OpDecl.tel, Eff.RowsIn, Ty.RowsInList, Tel.RowsIn, Ty.RowsIn, Ty.HasKind, kindsTel, kindsEff, kindsList]
      intro name ix hi
      cases ix with
      | fixed r => trivial
      | rvar i => cases hi
  · intro c cd hc
    simp only [program] at hc
    split at hc
    · simp only [Option.some.injEq] at hc
      subst cd
      intro m ms hm
      simp only [klass] at hm
      split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
      subst ms
      refine ⟨by simp [NamesWF, method], ?_⟩
      constructor <;> simp [Ty.SourceScoped, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, RangeIx.WF, Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys, signatureTel, Eff.RowsIn, Ty.RowsInList, Tel.RowsIn, Ty.RowsIn, Ty.HasKind, kindsTel, kindsEff, kindsList, method, MethSig.tel, klass]
    · split at hc
      · simp only [Option.some.injEq] at hc
        subst cd
        intro m ms hm; cases hm
      · cases hc
  · intro i id hi
    simp only [program] at hi
    split at hi <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst id
    refine ⟨?_, ⟨by simp [Ty.WF, implDecl], trivial, trivial⟩, annotation_tvar _ _ _ _ (by simp [implDecl]), ?_, ?_, ?_, ?_⟩
    · intro p hp; simp [implDecl] at hp; subst p; exact Nat.zero_lt_succ _
    · exact (impl_typed B).choose_spec.2.2.2.2.1
    · intro a ha
      simp [ImplDecl.dictTys, implDecl] at ha
      subst a
      exact ⟨parent, by simp [program], rfl⟩
    · intro s u hu
      simp only [implDecl] at hu
      split at hu <;> simp_all only [Option.some.injEq, reduceCtorEq]
      subst u; exact Nat.zero_lt_succ _
    · intro cd m ms body hc hm hb
      simp [program, implDecl] at hc
      subst cd
      simp only [klass] at hm
      split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
      subst ms
      simp [implDecl] at hb
      subst body
      exact Nat.zero_lt_succ _
  · intro d inf hi
    simp only [program] at hi
    split at hi <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst inf
    refine ⟨rfl, ?_, ?_⟩
    · intro c cd hc hd
      simp only [program] at hc
      split at hc <;> simp_all only [Option.some.injEq, reduceCtorEq]
      subst cd; rfl
    · intro a ha
      simp only [info, List.map_cons, List.map_nil, List.cons_append, List.nil_append, List.mem_cons, List.not_mem_nil, or_false] at ha
      rcases ha with rfl | rfl
      · exact ⟨⟨trivial, trivial, trivial⟩, annotation_unit _ _ _, trivial⟩
      · exact ⟨⟨by simp [Ty.WF, info], trivial, trivial⟩, annotation_tvar _ _ _ _ (by simp [info]), rfl⟩

-- Q の条件に空でない行変数を含む。NoFail の仮定はない。
def rowFailure : Eff := .mk (fun a => match a with | .rho i => decide (i = 0) | _ => false) [unit]
def rowSignature : Def := { identity with ret := .fn [] [] unit rowFailure }
theorem q_nonempty : QTel rowSignature.tel 0 := by
  exact Or.inr (Or.inl (Or.inr (Or.inr (Or.inl ⟨by decide, rfl⟩))))
theorem q_method : QTel method.tel = Qsig method.params method.ret method.eff :=
  method.QTel_eq_Qsig (by simp [method, NamesWF])
theorem q_callsite : QTel rowSignature.tel = Qsig rowSignature.params rowSignature.ret rowSignature.eff :=
  rowSignature.QTel_eq_Qsig (by simp [rowSignature, identity, NamesWF])

-- 負例は、本番の全体の入口から破れた条件を射影して拒否を示す。
def withDef (d : Def) : Program := { program with defs := fun f => if f = "identity" then some d else none }
def withImpl (id : ImplDecl) : Program := { program with impls := fun i => if i = "Instance" then some id else none }
def withInfo (inf : DataVarianceDecl) : Program := { program with dataInfo := fun d => if d = "Box" then some inf else none }

theorem reject_def_names : ¬ (withDef { identity with names := [] }).WellTyped B := by
  intro h
  have hn := (h.defs "identity" _ (by rfl)).1
  simp [NamesWF, identity] at hn

theorem reject_def_kind : ¬ (withDef { identity with ret := .ctor .list }).WellTyped B := by
  intro h
  have hk := (h.defs "identity" _ (by rfl)).2.1
  exact hk.2.1

-- kind は value のままで、値参照の範囲だけを破る。
def badAnnotation : Ty := .refined (.base .integer) (.eq (.var 2) (.integer 0))
theorem reject_def_annotation : ¬ (withDef { identity with ret := badAnnotation }).WellTyped B := by
  intro h
  have hw := (h.defs "identity" _ (by rfl)).2.2.1.wf
  have hp := hw.2.1.2.1
  exact (Nat.lt_irrefl 2) hp.1

private theorem variable_bound {P B Ψ Q C Γ Φ v a i}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .var i) : i < Γ.length := by
  match h with
  | .V_Var hi _ => cases hv; have he := List.getElem?_eq_some_iff.mp hi; exact he.1
  | .V_Normal h => exact variable_bound h hv
  | .V_Sub h .. => exact variable_bound h hv
  | .V_Refine h .. => exact variable_bound h hv
  | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv
private theorem ret_variable_bound {P B Ψ Q C Γ Φ R m a e L i}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hm : m = .ret (.var i)) : i < Γ.length := by
  match h with
  | .C_Return h => cases hm; exact variable_bound h rfl
  | .C_Normal h => exact ret_variable_bound h hm
  | .C_Sub h .. => exact ret_variable_bound h hm
  | .C_Eff h .. => exact ret_variable_bound h hm
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem reject_def_body : ¬ (withDef { identity with body := .ret (.var 1) }).WellTyped B := by
  intro h
  have hb := (h.defs "identity" _ (by rfl)).2.2.2
  cases hb with | param hb => cases hb with | done hb =>
    exact (Nat.lt_irrefl 1) (ret_variable_bound hb rfl)

theorem reject_impl_missing_method : ¬ (withImpl { implDecl with methods := fun _ => none }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, hm, _⟩ := h.impls "Instance" _ (by rfl)
  have he : cd = klass := by simpa [withImpl, program, implDecl] using hc.symm
  subst cd
  have := hm "id"
  simp [klass] at this

theorem reject_impl_extra_method : ¬ (withImpl { implDecl with methods := fun _ => some (.ret (.var 0)) }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, hm, _⟩ := h.impls "Instance" _ (by rfl)
  have he : cd = klass := by simpa [withImpl, program, implDecl] using hc.symm
  subst cd
  have := hm "extra"
  simp [klass] at this

theorem reject_impl_missing_super : ¬ (withImpl { implDecl with supers := fun _ => none }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _, hs, _⟩ := h.impls "Instance" _ (by rfl)
  have he : cd = klass := by simpa [withImpl, program, implDecl] using hc.symm
  subst cd
  have := hs "Parent"
  simp [klass] at this

theorem reject_impl_extra_super : ¬ (withImpl { implDecl with supers := fun _ => some (.var 0) }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _, hs, _⟩ := h.impls "Instance" _ (by rfl)
  have he : cd = klass := by simpa [withImpl, program, implDecl] using hc.symm
  subst cd
  have := hs "Extra"
  simp [klass] at this

theorem reject_impl_target_kind : ¬ (withImpl { implDecl with target := .ctor .list }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _, _, hk, _⟩ := h.impls "Instance" _ (by rfl)
  have he : cd = klass := by simpa [withImpl, program, implDecl] using hc.symm
  subst cd
  exact hk

theorem reject_impl_dictionary : ¬ (withImpl { implDecl with dictParams := [("Parent", 1)] }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _, _, _, ha, _⟩ := h.impls "Instance" _ (by rfl)
  have hw := (ha (.dict "Parent" (.tvar 1)) (by simp [ImplDecl.dictTys])).wf
  exact (Nat.lt_irrefl 1) hw

theorem reject_impl_body : ¬ (withImpl { implDecl with methods := fun m => if m = "id" then some (.ret (.var 2)) else none }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _, _, _, _, hm, _⟩ := h.impls "Instance" _ (by rfl)
  have he : cd = klass := by simpa [withImpl, program, implDecl] using hc.symm
  subst cd
  obtain ⟨body, hb, _, ht⟩ := hm "id" method (by simp [klass])
  have he : body = .ret (.var 2) := by simpa using hb.symm
  subst body
  change TelBodyTy _ _ _ _ _ _ []
    (Tel.shiftV implDecl.dictTys.length 0 (Tel.bind (typeEnvAt method.tparams.length [implDecl.target] []) method.tel)) _ at ht
  rw [method_contract] at ht
  cases ht with | param ht => cases ht with | done ht =>
    exact (Nat.lt_irrefl 2) (by simpa [bindParams, implDecl, ImplDecl.dictTys, Ctx.extend] using ret_variable_bound ht rfl)

-- requirements の both で共変引数を使うと変性の検証に通らない。
theorem reject_variance : ¬ (withInfo { info with requirements := [.tvar 0] }).WellTyped B := by
  intro h
  have hv := (h.variance.1 "Box" _ (by rfl)).2.2.1 (.tvar 0) (by simp)
  obtain ⟨v, he, hp⟩ := hv
  simp only [info, List.getElem?_cons_zero, Option.some.injEq] at he
  subst v
  exact hp

-- metadata の none と空列の全称の範囲。構成子の検査は取り除かない。
theorem absent_metadata : ({ program with dataInfo := fun _ => none } : Program).MetadataScoped := by
  intro d inf h; cases h

theorem reject_metadata_length : ¬ (withInfo { info with variances := [] }).WellFormed := by
  intro h
  have hl := (h.metadata "Box" _ (by rfl)).1
  exact Nat.noConfusion hl

theorem reject_metadata_scope : ¬ (withInfo { info with requirements := [.tvar 1] }).WellFormed := by
  intro h
  have hw := ((h.metadata "Box" _ (by rfl)).2.2 (.tvar 1) (by simp)).1.1
  exact Nat.lt_irrefl 1 hw

theorem reject_metadata_kind : ¬ (withInfo { info with publicBoundary := [(.positive, .ctor .list)] }).WellFormed := by
  intro h
  exact ((h.metadata "Box" _ (by rfl)).2.2 (.ctor .list) (by simp)).2.2

def conflictingArity : Program := { program with cons := fun c => if c = "Box.Other" then some ({ box with ntys := 2 } : ConDecl) else program.cons c }
theorem reject_constructor_arity : ¬ conflictingArity.WellFormed := by
  intro h
  have ha := (h.cons "Box.Box" box (by simp [conflictingArity, program])).1
  have he := ha.2 "Box.Other" { box with ntys := 2 } (by simp [conflictingArity]) rfl
  have he' : (2 : Nat) = 1 := he
  contradiction

def badConstructor : Program := { program with cons := fun c => if c = "Box.Box" then some { box with args := [.tvar 1] } else none }
theorem reject_constructor_scope : ¬ badConstructor.WellFormed := by
  intro h
  have hw := ((h.cons "Box.Box" _ (by rfl)).2 (.tvar 1) (by simp)).1.1
  exact Nat.lt_irrefl 1 hw

def badOperation : Program := { program with ops := fun o => if o = "Effect.op" then some { operation with ret := .tvar 0 } else none }
theorem reject_operation : ¬ badOperation.WellFormed := by
  intro h
  have hw := (h.ops "Effect.op" _ (by rfl)).2.2.2.1
  exact Nat.not_lt_zero _ hw.1.2.1

def badClass : Program := { program with classes := fun c => if c = "Class" then some { klass with methods := fun m => if m = "id" then some { method with ret := .tvar 2 } else none } else program.classes c }
theorem reject_class_method : ¬ badClass.WellFormed := by
  intro h
  have hw := (h.classes "Class" _ (by rfl)) "id" _ (by rfl)
  exact Nat.lt_irrefl 2 hw.2.1.1.2.1

theorem reject_impl_scoped : ¬ (withImpl { implDecl with methods := fun m => if m = "id" then some (.ret (.var 2)) else none }).WellFormed := by
  intro h
  have hs := (h.impls "Instance" _ (by rfl)).2.2.2.2.2.2 klass "id" method (.ret (.var 2))
    (by simp [withImpl, program, implDecl]) (by simp [klass]) (by simp)
  exact Nat.lt_irrefl 2 hs

theorem reject_def_scoped : ¬ (withDef { identity with body := .ret (.var 1) }).WellFormed := by
  intro h
  have hs := h.defs "identity" ({ identity with body := .ret (.var 1) }) rfl
  exact Nat.lt_irrefl 1 hs.2.2

-- external は両方の入口で検査される。小さい名目型の重複を使う。
def duplicateExternal : Program := { program with externals := [externalEntry, externalEntry] }
theorem reject_external_typed : ¬ duplicateExternal.WellTyped B := by
  intro h
  have hu := h.external.unique
  simp [duplicateExternal] at hu

theorem reject_external_formed : ¬ duplicateExternal.WellFormed := by
  intro h
  have hu := h.external.unique
  simp [duplicateExternal] at hu

-- 全称条件が空に成り立つのは該当する格納欄だけである。
theorem empty_metadata_lists :
    (withInfo { info with requirements := [], publicBoundary := [] }).MetadataScoped := by
  intro d inf hi
  have he : inf = { info with requirements := [], publicBoundary := [] } := by
    exact (by simpa [withInfo] using hi.symm : d = "Box" ∧ inf = { info with requirements := [], publicBoundary := [] }).2
  subst inf
  refine ⟨rfl, ?_, ?_⟩
  · intro c cd hc hd
    simp only [withInfo, program] at hc
    split at hc <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst cd; rfl
  · intro a ha; cases ha

theorem reject_impl_class_lookup : ¬ (withImpl { implDecl with cls := "Missing" }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _⟩ := h.impls "Instance" _ rfl
  cases hc

theorem reject_super_body : ¬ (withImpl { implDecl with supers := fun s => if s = "Parent" then some (.var 1) else none }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _, _, _, _, _, hs⟩ := h.impls "Instance" _ rfl
  have he : cd = klass := by simpa [withImpl, program, implDecl] using hc.symm
  subst cd
  obtain ⟨u, hu, ht⟩ := hs "Parent" (by simp [klass])
  have he : u = .var 1 := by simpa using hu.symm
  subst u
  exact Nat.lt_irrefl 1 (by simpa [bindParams, implDecl, ImplDecl.dictTys] using variable_bound ht rfl)

theorem reject_metadata_arity : ¬ (withInfo { info with arity := 2, variances := [.covariant, .invariant] }).WellFormed := by
  intro h
  have he := (h.metadata "Box" _ rfl).2.1 "Box.Box" box (by simp [withInfo, program]) rfl
  have he' : (1 : Nat) = 2 := he
  contradiction

-- WF の上限、Annotation の sort、kind は独立に検査する。
def wrongSort : Ty := .refined unit (.eq (.var 0) (.integer 0))
theorem reject_metadata_annotation : ¬ (withInfo { info with requirements := [wrongSort] }).WellFormed := by
  intro h
  have hs := ((h.metadata "Box" _ rfl).2.2 wrongSort (by simp)).2.1.sorted
  have he := hs.2.1.2
  simp [unit, Term.Shape, Ty.HasSort, Ty.sort?] at he

-- 宣言の署名に隠れた行変数と範囲変数も、全体の入口で拒否する。
def unboundRowDef : Def := { identity with eff := Eff.row 0 }
theorem reject_signature_row : ¬ (withDef unboundRowDef).WellFormed := by
  intro h
  have hr := (h.defs "identity" unboundRowDef rfl).2.1.2.1
  have he := hr.2.2.1 0 rfl
  exact Nat.not_lt_zero 0 he

def unboundRangeDef : Def := { identity with eff := .mk (fun a => match a with | .name _ (.rvar 0) => true | _ => false) [] }
theorem reject_signature_range : ¬ (withDef unboundRangeDef).WellFormed := by
  intro h
  have hr := (h.defs "identity" unboundRangeDef rfl).2.1.1.2.2
  have he := hr.2.2.1 "Effect" (.rvar 0) rfl
  exact Nat.not_lt_zero 0 he

-- ソースに書けない実行時構文は本体の SourceScoped が拒む。
theorem reject_runtime_syntax : ¬ (withDef { identity with body := .ret (.loc 0) }).WellFormed := by
  intro h
  have hs := h.defs "identity" ({ identity with body := .ret (.loc 0) }) rfl
  exact hs.2.2

-- 型・行・範囲・値と各束縛の上限を同じ再帰検査へ渡す。
theorem scoped_telescope :
    Val.SourceScoped 0 1 0 0 (.dependentLam (.param "x" (.tvar 0) (.done (.tvar 0) Eff.empty)) (.ret (.var 0))) := by
  simp [Val.SourceScoped, Ty.SourceScoped, Ty.WF, Tel.WF, Eff.WF, Eff.Canonical,
    Ty.WFList, Eff.empty, Eff.norm, Ty.normTys, Ty.RowsIn, Tel.RowsIn, Eff.RowsIn,
    Ty.RowsInList, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes,
    Comp.SourceScoped, telBinders]
theorem reject_nested_type :
    ¬ Val.SourceScoped 0 1 0 0 (.dependentLam (.param "x" (.tvar 1) (.done unit Eff.empty)) (.ret (.var 0))) := by
  intro h
  exact Nat.lt_irrefl 1 h.1.1.1

-- 外部IDのキーと宣言の一致も、重複の検査とは別に要求する。
def wrongExternalKey : Program := { program with externals := [(.type (.mk 1), .type ⟨.mk 0, .mk 0, "Handle", 0, 0⟩)] }
theorem reject_external_key : ¬ wrongExternalKey.WellFormed := by
  intro h
  have hk := (h.external.keys (.type (.mk 1)) (.type ⟨.mk 0, .mk 0, "Handle", 0, 0⟩) (List.mem_singleton_self _)).1
  cases hk

-- クラス引数の置換が、値の移動と異なる操作であることを具体的な像で確認する。
theorem class_argument_substitution :
    Ty.rawBind (typeEnvAt method.tparams.length [unit] []) (.tvar 1) = unit := by rfl
theorem dictionary_value_shift :
    Tel.shiftV 1 0 (.param "x" (.refined (.base .integer) (.eq (.var 0) (.var 1)))
      (.done unit Eff.empty)) =
    .param "x" (.refined (.base .integer) (.eq (.var 0) (.var 2))) (.done unit Eff.empty) := by rfl
-- 上の列は外側の自由な値参照を持つ補助入力であり、ソース宣言の閉性は主張しない。

theorem scoped_four_depths :
    Val.SourceScoped 1 1 1 1 (.fnRef "f" [.opaque "Opaque" (.rvar 0), .tvar 0] [Eff.row 0]) := by
  simp [Val.SourceScoped, scopedTypes, scopedRows, Ty.SourceScoped, Eff.SourceScoped,
    Ty.WF, RangeIx.WF, Ty.RowsIn, Ty.RangesScoped, Eff.WF, Ty.WFList,
    Eff.RowsIn, Ty.RowsInList, Eff.RangesScoped, rangesScopedTypes, Eff.row]

theorem reject_def_duplicate_names :
    ¬ (withDef { identity with names := ["x", "x"], params := [unit, unit] }).WellTyped B := by
  intro h
  have hn := (h.defs "identity" _ rfl).1.2
  simp at hn

end
end Benitoite.Release.Refinement.L10WBoundary

/-! 辞書引数を読むメソッド本体、行を持つ署名、Q の接続の確認。 -/
namespace Benitoite.Release.Refinement.L10WDictionary
open Benitoite.Release.Refinement
noncomputable section

def unit : Ty := .base .unit
-- クラス引数は番号1。自身の型パラメータ0。結果は親クラスの辞書。
def getSig : MethSig := ⟨[⟨({} : TParam), .value⟩], 0, ["x"], [.tvar 1], .dict "Parent" (.tvar 1), Eff.empty⟩
def parentC : ClassDecl := ⟨.value, [], fun _ => none⟩
def klass : ClassDecl := ⟨.value, [], fun m => if m = "get" then some getSig else none⟩
def mkImpl (body : Comp) : ImplDecl := ⟨[({} : TParam)], [("Parent", 0)], "Class", .tvar 0,
  fun _ => none, fun m => if m = "get" then some body else none⟩
def program (body : Comp) : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun c => if c = "Class" then some klass else if c = "Parent" then some parentC else none
  impls := fun i => if i = "I" then some (mkImpl body) else none }

theorem contract (b) : Tel.shiftV (mkImpl b).dictTys.length 0
      (Tel.bind (typeEnvAt getSig.tparams.length [(mkImpl b).target] []) getSig.tel) =
      .param "x" (.tvar 1) (.done (.dict "Parent" (.tvar 1)) Eff.empty) := by
  simp [mkImpl, getSig, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, shiftTypes, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Tel.shiftV, Ty.shiftV, Eff.shiftV, shiftVTys, ImplDecl.dictTys]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

theorem dictctx (b) : bindParams [] ((mkImpl b).dictTys.map (Ty.shift getSig.tparams.length 0)) =
    [some (.dict "Parent" (.tvar 1))] := by
  simp [bindParams, mkImpl, ImplDecl.dictTys, getSig, Ty.shift, Ty.bind, Ty.rawBind, SubstEnv.shiftTypes, Ty.norm, Ty.shiftV, shiftIndex]

/-- 辞書は Γ の番号1にあり、メソッドの型代入の後の結果型と一致する。 -/
theorem dict_body_typed (B : Builtins) :
    TelBodyTy (program (.ret (.var 1))) B StoreTy.empty (fun _ => False) ([{}, {}]) 
      [some (.dict "Parent" (.tvar 1))] []
      (.param "x" (.tvar 1) (.done (.dict "Parent" (.tvar 1)) Eff.empty)) (.ret (.var 1)) := by
  refine .param (.done (.C_Return (.V_Var ?_ ?_)))
  · simp [Ctx.extend, Ty.shiftV]
  · intro b t e h; cases h

/-- 入口全体でも同じ本体が通る。 -/
theorem impl_wellTyped (B : Builtins) : (mkImpl (.ret (.var 1))).WellTyped (program (.ret (.var 1))) B := by
  refine ⟨klass, by simp [program, mkImpl], ?_, ?_, rfl, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "get" <;> simp [mkImpl, klass, h]
  · intro s; simp [mkImpl, klass]
  · intro a ha
    simp [ImplDecl.dictTys, mkImpl] at ha
    subst a
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, mkImpl]
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.var 1), by simp [mkImpl, *], by simp [NamesWF, getSig], ?_⟩
    rw [contract, dictctx]
    have := dict_body_typed B
    have hq : QTel getSig.tel = fun _ => False := by
      funext i; simp [QTel, QTy, QEff, Eff.empty, Qempty, QTys, getSig, MethSig.tel, signatureTel]
    rw [hq]
    simpa [List.map_append, TParamDecl.constraints, getSig, mkImpl] using this
  · intro s hs; simp [klass] at hs

-- 行変数は es=[] の型代入で保たれる。
theorem row_kept : Tel.bind (typeEnvAt 1 [.tvar 0] []) (.done (.tvar 0) (Eff.row 0)) = .done (.tvar 0) (Eff.row 0) := by
  simp [Tel.bind, Tel.rawBind, Ty.rawBind, typeEnvAt, Eff.rawBind, rowFails, Tel.norm, Ty.norm, Eff.norm, Eff.row, Ty.normTys]
  funext a; cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

-- 反例の入力: 対象型が行を持つと、代入後の QTel は代入前の Qsig より広い。
def failRow : Eff := .mk (fun a => match a with | .rho i => decide (i = 0) | _ => false) [unit]
def rowTarget : Ty := .fn [] [] unit failRow
def plain : MethSig := ⟨[], 1, ["x"], [.tvar 0], unit, Eff.empty⟩
theorem qsig_empty : ¬ Qsig plain.params plain.ret plain.eff 0 := by
  simp [Qsig, plain, QTys, QTy, QEff, Eff.empty, Qempty, unit]
theorem qtel_grows :
    QTel (Tel.shiftV 0 0 (Tel.bind (typeEnvAt 0 [rowTarget] []) plain.tel)) 0 := by
  simp [plain, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, rowTarget, Tel.norm, Tel.shiftV, QTel, QTy, Ty.norm, Ty.shiftV, Ty.normTys, Eff.norm, QTys, QEff, failRow, unit, Eff.shiftV]
end
end Benitoite.Release.Refinement.L10WDictionary

/-! 辞書引数からの C_Meth、handler の下の escape、kind と dictParams の空き。 -/
namespace Benitoite.Release.Refinement.L10WCall
open Benitoite.Release.Refinement
noncomputable section

def unit : Ty := .base .unit
def pm : MethSig := ⟨[], 0, ["x"], [.tvar 0], .tvar 0, Eff.empty⟩
def parentC : ClassDecl := ⟨.value, [], fun m => if m = "pm" then some pm else none⟩
def P0 : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun c => if c = "Parent" then some parentC else none
  impls := fun _ => none }

theorem pm_inst : instantiatedTel pm.tel [.tvar 0] [] = .param "x" (.tvar 0) (.done (.tvar 0) Eff.empty) := by
  simp [instantiatedTel, pm, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Ty.shiftV]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

/-- 本体 `d.pm(x)`: 辞書の引数（番号1）からメソッドを呼ぶ。 -/
theorem call_through_dictionary (B : Builtins) :
    TelBodyTy P0 B StoreTy.empty (fun _ => False) [{}]
      [some (.dict "Parent" (.tvar 0))] []
      (.param "x" (.tvar 0) (.done (.tvar 0) Eff.empty))
      (.meth (.var 1) "pm" [] [] [.var 0]) := by
  have ha : Ty.Annotation P0 [{}] [some (.tvar 0), some (.dict "Parent" (.tvar 0))] (.tvar 0) := ⟨by simp [Ty.WF], trivial, trivial⟩
  refine .param (.done ?_)
  have hΓ : Ctx.extend [some (.dict "Parent" (.tvar 0))] (.tvar 0) = [some (.tvar 0), some (.dict "Parent" (.tvar 0))] := by
    simp [Ctx.extend, Ty.shiftV]
  rw [hΓ]
  have hsi : SignatureInstance P0 [{}] [some (.tvar 0), some (.dict "Parent" (.tvar 0))] pm.tel ([] ++ [TyKind.value]) [.tvar 0] [] := by
    refine ⟨?_, ?_, ?_, ?_, ?_⟩
    · simp [Ty.WF, Tel.WF, pm, MethSig.tel, signatureTel, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]
    · intro t ht; simp at ht; subst t; exact ha
    · exact ⟨rfl, [.value], rfl, by
        intro i a k h1 h2
        cases i with
        | zero =>
          simp at h1 h2; subst h1; subst h2; rfl
        | succ i => simp at h1⟩
    · intro e he; cases he
    · rw [pm_inst]
      constructor <;> simp [Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys]
  have hargs : Tel.arguments (instantiatedTel pm.tel ([] ++ [.tvar 0]) []) [.var 0] = some ([.tvar 0], .tvar 0, Eff.empty) := by
    simp only [List.nil_append, pm_inst, Tel.arguments, Tel.bind, Tel.rawBind, Tel.argumentsEnv]
    simp [Tel.arguments, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Eff.norm, Ty.normTys, Eff.empty, rowFails, valEnv]
    funext a
    cases a with
    | name l ix => cases ix <;> simp [substAtoms, instAtoms, ]
    | rho i => simp [substAtoms, instAtoms]
  have hmeth := @HasTypeCQ.C_Meth P0 B StoreTy.empty (fun _ => False) [{}]
    [some (.tvar 0), some (.dict "Parent" (.tvar 0))] [] [] (some (.tvar 0)) (.var 1) "Parent" (.tvar 0) parentC "pm" pm [] [] [.var 0] [.tvar 0] (.tvar 0) Eff.empty
    (.V_Var rfl (by intro b t e h; cases h)) rfl (by simp [parentC])
    (by simp [NamesWF, pm]) ⟨rfl, by intro i t p h; cases i <;> simp at h⟩ hsi
    ⟨rfl, (by intro f hf; cases hf), by simp [pm, Eff.empty, Eff.RowsIn, Ty.RowsInList], by simp [pm, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty], by intro i hi; simp [pm, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty] at hi⟩
    hargs (.cons (.V_Var rfl (by intro b t e h; cases h)) .nil) ha
  exact hmeth

/-- handler の下の escape も done の return 契約を読む。 -/
theorem escape_under_handler (B : Builtins) (Γ) (h1 : Γ[0]? = some (some unit)) :
    HasTypeCQ P0 B StoreTy.empty (fun _ => False) [] Γ [] (some unit) (.handle (.escape (.var 0)) []) unit Eff.empty [] := by
  refine .C_Handle (εm := Eff.empty) (.C_Escape (.V_Var h1 (by intro b t e h; cases h)) ⟨?_, ?_, ?_⟩) ?_ .nil
  · trivial
  · trivial
  · trivial
  · constructor <;> intro x hx <;> simp [Eff.mem, Eff.memFail, Eff.empty, Eff.test, Eff.fails, Eff.atoms] at hx
end
end Benitoite.Release.Refinement.L10WCall

namespace Benitoite.Release.Refinement.L10WConditions
open Benitoite.Release.Refinement L10WBoundary
noncomputable section
variable (B : Builtins)
def withCon (cd : ConDecl) : Program := { program with cons := fun c => if c = "Box.Box" then some cd else none }
def withOp (od : OpDecl) : Program := { program with ops := fun o => if o = "Effect.op" then some od else none }
def withClass (cl : ClassDecl) : Program := { program with classes := fun c => if c = "Class" then some cl else program.classes c }

theorem reject_method_names :
    ¬ (withClass { klass with methods := fun m => if m = "id" then some { method with names := [] } else none }).WellTyped B := by
  intro h
  obtain ⟨cd, hc, _, _, _, _, hm, _⟩ := h.impls "Instance" implDecl rfl
  have he : cd = { klass with methods := fun m => if m = "id" then some { method with names := [] } else none } := by simpa [withClass, program, implDecl] using hc.symm
  subst cd
  obtain ⟨body, _, hn, _⟩ := hm "id" _ rfl
  simp [NamesWF, method] at hn

theorem reject_con_annotation : ¬ (withCon { box with args := [wrongSort] }).WellFormed := by
  intro h
  have hs := ((h.cons "Box.Box" _ rfl).2 wrongSort (by simp)).2.1.sorted
  have he := hs.2.1.2
  simp [unit, Term.Shape, Ty.HasSort, Ty.sort?] at he

theorem reject_con_kind : ¬ (withCon { box with args := [.ctor .list] }).WellFormed := by
  intro h
  exact ((h.cons "Box.Box" ({ box with args := [.ctor .list] }) rfl).2 (.ctor .list) (by simp)).2.2

theorem reject_op_names : ¬ (withOp { operation with names := [] }).WellFormed := by
  intro h
  have hn := (h.ops "Effect.op" _ rfl).1
  simp [NamesWF, operation] at hn

theorem reject_op_dictionary_index : ¬ (withOp { operation with dictParams := [("Parent", 0)] }).WellFormed := by
  intro h
  have hi := (h.ops "Effect.op" _ rfl).2.1 ("Parent", 0) (by simp)
  exact Nat.not_lt_zero 0 hi

theorem reject_op_dictionary_prefix :
    ¬ (withOp { operation with tparams := [{}], dictParams := [("Parent", 0)] }).WellFormed := by
  intro h
  have hp := (h.ops "Effect.op" _ rfl).2.2.1
  have he : unit = .dict "Parent" (.tvar 0) := List.cons.inj hp |>.1
  cases he

theorem reject_meth_scoped_names :
    ¬ (withClass { klass with methods := fun _ => some { method with names := [] } }).WellFormed := by
  intro h
  have hn := (h.classes "Class" _ rfl) "id" ({ method with names := [] }) rfl |>.1
  simp [NamesWF, method] at hn

theorem reject_meth_scoped_kind :
    ¬ (withClass { klass with methods := fun _ => some { method with ret := .ctor .list } }).WellFormed := by
  intro h
  have hk := (h.classes "Class" _ rfl) "id" ({ method with ret := .ctor .list }) rfl |>.2.2.2.1
  exact hk.2.1

theorem reject_impl_dictionary_index :
    ¬ (withImpl { implDecl with dictParams := [("Parent", 1)] }).WellFormed := by
  intro h
  have hi := (h.impls "Instance" _ rfl).1 ("Parent", 1) (by simp)
  exact Nat.lt_irrefl 1 hi

theorem reject_impl_dictionary_kind :
    ¬ (withImpl { implDecl with dictParams := [("Ghost", 0)] }).WellFormed := by
  intro h
  have hk := (h.impls "Instance" _ rfl).2.2.2.2.1 (.dict "Ghost" (.tvar 0)) (by simp [ImplDecl.dictTys])
  obtain ⟨cd, hc, _⟩ := hk
  cases hc

theorem reject_impl_target_scope : ¬ (withImpl { implDecl with target := .tvar 1 }).WellFormed := by
  intro h
  have hw := (h.impls "Instance" _ rfl).2.1.1
  exact Nat.lt_irrefl 1 hw

theorem reject_impl_target_annotation : ¬ (withImpl { implDecl with target := wrongSort }).WellFormed := by
  intro h
  have hs := (h.impls "Instance" _ rfl).2.2.1.sorted
  have he := hs.2.1.2
  simp [unit, Term.Shape, Ty.HasSort, Ty.sort?] at he

theorem reject_impl_super_scope :
    ¬ (withImpl { implDecl with supers := fun _ => some (.var 1) }).WellFormed := by
  intro h
  have hs := (h.impls "Instance" _ rfl).2.2.2.2.2.1 "Parent" (.var 1) rfl
  exact Nat.lt_irrefl 1 hs

theorem reject_public_boundary_scope :
    ¬ (withInfo { info with publicBoundary := [(.positive, .tvar 1)] }).WellFormed := by
  intro h
  have hw := ((h.metadata "Box" _ rfl).2.2 (.tvar 1) (by simp)).1.1
  exact Nat.lt_irrefl 1 hw

-- 辞書の型を持つ params の先頭が実際に検査を通る。
def dictionaryOp : OpDecl := ⟨"Effect", [{}], ["dictionary", "x"], [.dict "Parent" (.tvar 0), unit], unit, [("Parent", 0)]⟩
theorem dictionary_op_scoped : dictionaryOp.Scoped program := by
  refine ⟨by simp [dictionaryOp, NamesWF], ?_, rfl, ?_⟩
  · intro p hp; simp [dictionaryOp] at hp; subst p; decide
  · constructor <;> simp [dictionaryOp, Ty.SourceScoped, Ty.WF, Tel.WF,
      Eff.WF, Ty.WFList, Eff.Canonical, Eff.norm, Ty.normTys, OpDecl.tel, signatureTel,
      Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Ty.RowsInList, Ty.RangesScoped, Tel.RangesScoped,
      Eff.RangesScoped, rangesScopedTypes, Ty.HasKind, kindsTel, kindsEff, kindsList,
      unit, program, parent, annotation_iff, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys,
      Ty.Declared, Tel.Declared, declaredEff, declaredTys]
    all_goals first
      | exact ⟨parent, by simp [program], rfl⟩
      | (intro name ix hi; cases ix with | fixed r => trivial | rvar i => cases hi)

def externalFunction : ExternalSignature := ⟨.mk 0, "constant", [], [], .done unit Eff.empty, []⟩
theorem external_function_signature : externalFunction.WF program := by
  refine ⟨rfl, rfl, ?_, ?_, ?_, List.nodup_nil, .done .unit rfl⟩
  · constructor <;> simp [externalFunction, unit, Ty.WF, Tel.WF, Eff.WF, Ty.WFList,
      Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff,
      sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys]
  · exact ⟨trivial, trivial⟩
  · intro use; constructor
    · intro h; cases h
    · intro h; cases h with | result h => cases h

theorem external_function_table :
    ({ program with externals := [(.function (.mk 0), .function (.mk 0) externalFunction)] } : Program).ExternalWF := by
  refine ⟨by simp, ?_⟩
  intro key decl h
  have he := List.mem_singleton.mp h
  cases he
  exact ⟨rfl, by
    refine ⟨rfl, rfl, ?_, ?_, ?_, List.nodup_nil, .done .unit rfl⟩
    · constructor <;> simp [externalFunction, unit, Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys]
    · exact external_function_signature.kinded
    · intro use; constructor
      · intro h; cases h
      · intro h; cases h with | result h => cases h⟩
end
end Benitoite.Release.Refinement.L10WConditions

namespace Benitoite.Release.Refinement.L10WRows
open Benitoite.Release.Refinement
noncomputable section
def unit : Ty := .base .unit
def failRow (i : Nat) : Eff := .mk (fun a => match a with | .rho j => decide (j = i) | _ => false) [unit]
def gate : Def := ⟨[], 1, [], [], unit, failRow 0, .ret (.const .unit)⟩
def body (i : Nat) : Comp := .letIn (.ret (.fnRef "gate" [] [Eff.row i])) (.ret (.const .unit))
def definition (i : Nat) : Def := ⟨[], 2, [], [], unit, failRow 0, body i⟩
def method : MethSig := ⟨[], 2, [], [], unit, failRow 0⟩
def klass : ClassDecl := ⟨.value, [], fun m => if m = "run" then some method else none⟩
def implDecl (i : Nat) : ImplDecl := ⟨[], [], "Class", unit, fun _ => none, fun m => if m = "run" then some (body i) else none⟩
def program (i : Nat) : Program := {
  defs := fun f => if f = "gate" then some gate else if f = "test" then some (definition i) else none
  cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun c => if c = "Class" then some klass else none
  impls := fun n => if n = "I" then some (implDecl i) else none }

theorem empty_covers (Γ Φ) (e : Eff) : Eff.Covers Γ Φ e Eff.empty := by
  constructor <;> intro x hx <;> simp [Eff.mem, Eff.memFail, Eff.empty, Eff.fails, Eff.test, Eff.atoms] at hx

theorem annotation_result (P : Program) (C : List TParam) (Γ : Ctx) (i : Nat) :
    Ty.Annotation P C Γ (.dependentFn (.done unit (failRow i))) := by
  constructor <;> simp [unit, failRow, Ty.WF, Tel.WF, Eff.WF, Ty.WFList,
    Eff.Canonical, Eff.norm, Ty.normTys, Ty.norm, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys,
    Ty.Declared, Tel.Declared, declaredEff, declaredTys]

theorem gate_inst (i : Nat) : instantiatedTel gate.tel [] [Eff.row i] = .done unit (failRow i) := by
  simp [instantiatedTel, gate, Def.tel, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind,
    Eff.rawBind, Tel.norm, Ty.norm, Eff.norm, Ty.normTys, rowFails, failRow, Eff.row, unit, typeEnvAt, shiftRowsTypes, Eff.fails]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms, Eff.test, Eff.atoms]
  | rho j => simp [substAtoms, instAtoms, Eff.test, Eff.atoms]

theorem gate_q (i : Nat) : Qsig gate.params gate.ret gate.eff i ↔ i = 0 := by
  simp [gate, Qsig, QTys, QTy, QEff, failRow, unit, Qempty, QTys]

theorem def_q (k i : Nat) : QTel (definition k).tel i ↔ i = 0 := by
  simp [definition, Def.tel, signatureTel, QTel, QTy, QEff, failRow, unit, Qempty, QTys]

theorem method_q (i : Nat) : QTel method.tel i ↔ i = 0 := by
  simp [method, MethSig.tel, signatureTel, QTel, QTy, QEff, failRow, unit, Qempty, QTys]

theorem gate_reference (B : Builtins) (k i : Nat) (Q : NoFailCtx) (C : List TParam) (Γ : Ctx) (Φ : List Pred)
    (hq : Q i) : HasTypeVQ (program k) B StoreTy.empty Q C Γ Φ
      (.fnRef "gate" [] [Eff.row i]) (.dependentFn (.done unit (failRow i))) := by
  rw [← gate_inst]
  refine .V_Fun (by simp [program]) (by simp [gate, NamesWF]) ?_ ?_
  · refine ⟨⟨rfl, ?_⟩, ?_, rfl, ?_, ?_, ?_, ?_⟩
    · intro j t p h; cases j <;> simp at h
    · intro t ht; cases ht
    · intro e he; simp only [List.mem_singleton] at he; subst e; trivial
    · simp [gate, Eff.RowsIn, failRow, Ty.RowsInList, Ty.RowsIn, unit]
    · intro j hj; have he := (gate_q j).mp hj; subst j; simp
    · intro j hj; have he := (gate_q j).mp hj; subst j
      refine ⟨rfl, ?_⟩
      intro j hj
      have he : j = i := by simpa [Eff.row, Eff.test, Eff.atoms] using hj
      subst j; exact hq
  · refine ⟨(annotation_result (program k) [] [] 0).wf, ?_, ?_, ?_, ?_⟩
    · intro t ht; cases ht
    · exact ⟨rfl, List.replicate C.length .value, by simp, by intro j a t h; cases j <;> simp at h⟩
    · intro e he; simp only [List.mem_singleton] at he; subst e
      constructor <;> trivial
    · rw [gate_inst]; exact annotation_result _ _ _ _

private theorem reference_requires_q {B k Ψ Q C Γ Φ v a i}
    (h : HasTypeVQ (program k) B Ψ Q C Γ Φ v a)
    (hv : v = .fnRef "gate" [] [Eff.row i]) : Q i := by
  match h with
  | .V_Fun (d := d) hd _ ha _ =>
    cases hv
    have he : d = gate := by simpa [program] using hd.symm
    subst d
    have hn := ha.noFailRows 0 ((gate_q 0).mpr rfl)
    exact hn.2 i (by simp [Eff.row, Eff.test, Eff.atoms])
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact reference_requires_q h hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. |
    .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

private theorem ret_requires_q {B k Ψ Q C Γ Φ R m a e L i}
    (h : HasTypeCQ (program k) B Ψ Q C Γ Φ R m a e L)
    (hm : m = .ret (.fnRef "gate" [] [Eff.row i])) : Q i := by
  match h with
  | .C_Return h => cases hm; exact reference_requires_q h rfl
  | .C_Normal h | .C_Sub h .. | .C_Eff h .. => exact ret_requires_q h hm
  | .C_Let .. | .C_BuilderLet .. | .C_BuilderOp .. | .C_App .. | .C_DependentApp .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

private theorem body_requires_q {B k Ψ Q C Γ Φ R m a e L i}
    (h : HasTypeCQ (program k) B Ψ Q C Γ Φ R m a e L)
    (hm : m = body i) : Q i := by
  match h with
  | .C_Let h _ _ => cases hm; exact ret_requires_q h rfl
  | .C_Normal h | .C_Sub h .. | .C_Eff h .. => exact body_requires_q h hm
  | .C_Return .. | .C_BuilderLet .. | .C_BuilderOp .. | .C_App .. | .C_DependentApp .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem body_typed (B : Builtins) (k i : Nat) (Q : NoFailCtx) (hq : Q i) :
    HasTypeCQ (program k) B StoreTy.empty Q [] [] [] (some unit) (body i) unit (failRow 0) [] := by
  apply HasTypeCQ.C_Eff (ε := Eff.empty)
  · refine .C_Let (.C_Return (gate_reference B k i Q [] [] [] hq)) ?_ trivial
    exact .C_Return (.V_Const trivial)
  · exact empty_covers _ _ _

theorem definition_typed (B : Builtins) : (definition 0).WellTyped (program 0) B := by
  refine ⟨by simp [definition, NamesWF], ?_, annotation_result _ _ _ _, .done ?_⟩
  · exact ⟨trivial, ⟨trivial, trivial⟩⟩
  · exact body_typed B 0 0 _ ((def_q 0 0).mpr rfl)

theorem reject_definition_q (B : Builtins) : ¬ (definition 1).WellTyped (program 1) B := by
  intro h
  have ht := h.2.2.2
  cases ht with | done ht =>
    have hq := body_requires_q ht rfl
    exact (Nat.zero_ne_one ((def_q 1 1).mp hq).symm)

theorem method_inst : Tel.shiftV (implDecl 0).dictTys.length 0
    (Tel.bind (typeEnvAt method.tparams.length [(implDecl 0).target] []) method.tel) =
    .done unit (failRow 0) := by
  simp [implDecl, method, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind,
    Eff.rawBind, Tel.norm, Ty.norm, Eff.norm, Ty.normTys, rowFails, failRow, unit, Ty.shiftV,
    Tel.shiftV, Eff.shiftV, shiftVTys, ImplDecl.dictTys, typeEnvAt]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho j => simp [substAtoms, instAtoms]

theorem implementation_typed (B : Builtins) : (implDecl 0).WellTyped (program 0) B := by
  refine ⟨klass, rfl, ?_, ?_, trivial, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "run" <;> simp [implDecl, klass, h]
  · intro s; simp [implDecl, klass]
  · intro a ha; cases ha
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨body 0, by simp [implDecl, *], by simp [method, NamesWF], ?_⟩
    rw [method_inst]
    exact .done (body_typed B 0 0 _ ((method_q 0).mpr rfl))
  · intro s hs; cases hs

theorem reject_implementation_q (B : Builtins) : ¬ (implDecl 1).WellTyped (program 1) B := by
  intro h
  obtain ⟨cd, hc, _, _, _, _, hm, _⟩ := h
  have he : cd = klass := by simpa [program, implDecl] using hc.symm
  subst cd
  obtain ⟨b, hb, _, ht⟩ := hm "run" method rfl
  have he : b = body 1 := by simpa [implDecl] using hb.symm
  subst b
  have hm : Tel.shiftV (implDecl 1).dictTys.length 0
    (Tel.bind (typeEnvAt method.tparams.length [(implDecl 1).target] []) method.tel) =
    .done unit (failRow 0) := method_inst
  dsimp only at ht
  rw [hm] at ht
  cases ht with | done ht =>
    have hq := body_requires_q ht rfl
    exact Nat.zero_ne_one ((method_q 1).mp hq).symm
end
end Benitoite.Release.Refinement.L10WRows

namespace Benitoite.Release.Refinement.L10WOrder
open Benitoite.Release.Refinement
noncomputable section
def unit : Ty := .base .unit
def method (p : TParam) : MethSig := ⟨[⟨p, .value⟩], 0, [], [], .set unit, Eff.empty⟩
def klass (p : TParam) : ClassDecl := ⟨.value, [], fun m => if m = "collect" then some (method p) else none⟩
def implDecl (p : TParam) : ImplDecl := ⟨[p], [], "Class", unit, fun _ => none, fun m => if m = "collect" then some (.ret (.setV [])) else none⟩
def program (p : TParam) : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun c => if c = "Class" then some (klass p) else none
  impls := fun _ => none }
def orderedBuiltins (B : Builtins) : Builtins := { B with sat := fun C _ _ => C = [TParam.keyC, {}] }

theorem contract (p q : TParam) :
    Tel.shiftV (implDecl p).dictTys.length 0
      (Tel.bind (typeEnvAt (method q).tparams.length [(implDecl p).target] []) (method q).tel) =
      .done (.set unit) Eff.empty := by
  simp [implDecl, method, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind,
    Eff.rawBind, Tel.norm, Ty.norm, Eff.norm, Ty.normTys, rowFails, unit, Ty.shiftV,
    Tel.shiftV, Eff.shiftV, shiftVTys, ImplDecl.dictTys, typeEnvAt, Eff.empty]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho j => simp [substAtoms, instAtoms]

theorem implementation_typed (B : Builtins) :
    (implDecl {}).WellTyped (program TParam.keyC) (orderedBuiltins B) := by
  refine ⟨klass TParam.keyC, rfl, ?_, ?_, trivial, ?_, ?_, ?_⟩
  · intro m; by_cases h : m = "collect" <;> simp [implDecl, klass, h]
  · intro s; simp [implDecl, klass]
  · intro a ha; cases ha
  · intro m ms hm
    simp only [klass] at hm
    split at hm <;> simp_all only [Option.some.injEq, reduceCtorEq]
    subst ms
    refine ⟨.ret (.setV []), by simp [implDecl, *], by simp [method, NamesWF], ?_⟩
    rw [contract]
    refine .done (.C_Return (.V_Set .nil rfl ?_))
    constructor <;> trivial
  · intro s hs; cases hs

private theorem set_requires_order {B P Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P (orderedBuiltins B) Ψ Q C Γ Φ v a) (hv : v = .setV []) : C = [TParam.keyC, {}] := by
  match h with
  | .V_Set _ hs _ => exact hs
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact set_requires_order h hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
    .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_Map .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. |
    .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv
private theorem ret_requires_order {B P Ψ Q C Γ Φ R m a e L}
    (h : HasTypeCQ P (orderedBuiltins B) Ψ Q C Γ Φ R m a e L) (hm : m = .ret (.setV [])) : C = [TParam.keyC, {}] := by
  match h with
  | .C_Return h => cases hm; exact set_requires_order h rfl
  | .C_Normal h | .C_Sub h .. | .C_Eff h .. => exact ret_requires_order h hm
  | .C_Let .. | .C_BuilderLet .. | .C_BuilderOp .. | .C_App .. | .C_DependentApp .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem reject_swapped_constraints (B : Builtins) :
    ¬ (implDecl TParam.keyC).WellTyped (program {}) (orderedBuiltins B) := by
  intro h
  obtain ⟨cd, hc, _, _, _, _, hm, _⟩ := h
  have he : cd = klass {} := by simpa [program, implDecl] using hc.symm
  subst cd
  obtain ⟨b, hb, _, ht⟩ := hm "collect" (method {}) rfl
  have he : b = .ret (.setV []) := by simpa [implDecl] using hb.symm
  subst b
  dsimp only at ht
  rw [contract] at ht
  cases ht with | done ht =>
    have he := ret_requires_order ht rfl
    have hp := List.cons.inj he |>.1
    have hk := congrArg TParam.key hp
    cases hk
end
end Benitoite.Release.Refinement.L10WOrder

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if env.getModuleIdxFor? name == none then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
