import Benitoite.Release.Refinement.KindInference

namespace Benitoite.Release.Refinement.KindReviewBoundary

def functor : ClassDecl := { argumentKind := .constructor 1, supers := [], methods := fun _ => none }
def functor2 : ClassDecl := { argumentKind := .constructor 2, supers := [], methods := fun _ => none }
def showClass : ClassDecl := { supers := [], methods := fun _ => none }
def optionSome : ConDecl := ⟨"Option", 1, [.tvar 0]⟩

def program : Program :=
  { defs := fun _ => none
    cons := fun c => if c = "Some" then some optionSome else none
    ops := fun _ => none
    effects := fun _ => none
    classes := fun cl => if cl = "Functor" then some functor else
      if cl = "Functor2" then some functor2 else if cl = "Show" then some showClass else none
    impls := fun _ => none }

theorem option_arity : program.DataArity "Option" 1 := by
  constructor
  · exact ⟨"Some", optionSome, by simp [program], rfl⟩
  · intro c cd hc _
    change (if c = "Some" then some optionSome else none) = some cd at hc
    split at hc
    · cases hc; rfl
    · cases hc

-- map[F[_]: Functor, A](d: Dict[Functor,F], x: F[A]) -> F[A]
def mapDef : Def :=
  { tparams := [{ kind := .constructor 1 }, {}]
    neffs := 0, names := ["d", "x"]
    params := [.dict "Functor" (.tvar 0), .tapp 0 [.tvar 1]]
    ret := .tapp 0 [.tvar 1], eff := Eff.empty, body := .ret (.var 0) }

theorem map_kind_uses : mapDef.kindUses program =
    [(0, .constructor 1), (0, .constructor 1), (1, .value), (0, .constructor 1), (1, .value)] := rfl

theorem map_declared_kinds : mapDef.declaredKinds = [.constructor 1, .value] := rfl

theorem map_kind_wf : mapDef.KindWF program [.constructor 1, .value] := by
  refine ⟨rfl, ?_, ?_, ?_, trivial⟩
  · simp only [map_kind_uses, List.mem_cons, List.not_mem_nil, or_false]
    intro p hp
    rcases hp with rfl | rfl | rfl | rfl | rfl <;> rfl
  · exact ⟨⟨functor, rfl, rfl⟩, ⟨⟨rfl, rfl, trivial⟩, trivial⟩⟩
  · exact ⟨rfl, rfl, trivial⟩

theorem map_accepted : Def.kinds program mapDef = some [.constructor 1, .value] :=
  Def.kinds_complete map_kind_wf

theorem dictionary_parameter_accepted :
    Ty.ValueKind program [.constructor 1, .value] (.dict "Functor" (.tvar 0)) := ⟨functor, rfl, rfl⟩

theorem dictionary_option_accepted : Ty.ValueKind program [] (.dict "Functor" (.ctor (.data "Option"))) := by
  refine ⟨functor, rfl, ?_⟩
  exact TyCon.arity_data option_arity

theorem dictionary_integer_rejected : ¬ Ty.ValueKind program [] (.dict "Functor" (.base .integer)) := by
  rw [Ty.valueKind_dict_iff_class (show program.classes "Functor" = some functor from rfl)]
  exact id

def badImplementation : ImplDecl :=
  { tparams := [], dictParams := [], cls := "Functor", target := .base .integer
    supers := fun _ => none, methods := fun _ => none }

theorem implementation_integer_rejected : ¬ badImplementation.TargetKinded program [] := by
  rw [ImplDecl.targetKinded_iff (show program.classes badImplementation.cls = some functor from rfl)]
  exact id

theorem implementation_option_accepted :
    ImplDecl.TargetKinded program [] { badImplementation with target := .ctor (.data "Option") } := by
  refine ⟨functor, rfl, ?_⟩
  exact TyCon.arity_data option_arity


theorem binary_parameter_accepted :
    Ty.ValueKind program [.constructor 2] (.dict "Functor2" (.tvar 0)) := ⟨functor2, rfl, rfl⟩

theorem binary_constructor_accepted :
    Ty.ValueKind program [] (.dict "Functor2" (.ctor .map)) := ⟨functor2, rfl, rfl⟩

theorem wrong_arity_rejected : ¬ Ty.ValueKind program [] (.dict "Functor" (.ctor .map)) := by
  rw [Ty.valueKind_dict_iff_class (show program.classes "Functor" = some functor from rfl)]
  simp [Ty.HasKind, TyCon.arity, functor]

-- valueが既定の従来のクラスも、同じ共通判断で検査する。
theorem value_dictionary_accepted : Ty.ValueKind program [] (.dict "Show" (.base .integer)) :=
  ⟨showClass, rfl, trivial⟩

theorem value_class_constructor_rejected : ¬ Ty.ValueKind program [] (.dict "Show" (.ctor (.data "Option"))) := by
  rw [Ty.valueKind_dict_iff_class (show program.classes "Show" = some showClass from rfl)]
  exact id

-- 出現する型パラメータがなくても、実際の辞書の引数のkindを検査する。
theorem concrete_bad_annotation_rejected :
    Def.kinds program { mapDef with tparams := [], params := [], names := [], ret := .dict "Functor" (.base .integer) } = none := by
  apply Def.kinds_none_of_bad_annotation
  intro h
  exact dictionary_integer_rejected h.2.1

-- 宣言と食い違う出現を、注釈からkindを推論して通さない。
theorem declaration_mismatch_rejected :
    Def.kinds program { mapDef with tparams := [{}, {}] } = none := by
  apply Def.kinds_none_of_conflict (i := 0) (k := .constructor 1)
  · simp [Def.kindUses, mapDef, kindUsesTys, Ty.kindUses, kindUsesEff, program, functor, Eff.empty]
  · simp [Def.declaredKinds]

-- 未使用の明示的なconstructorのkindもvalueに変えない。
def unused : Def := { mapDef with params := [], names := [], ret := .base .unit }

theorem unused_declared_kind_preserved : Def.kinds program unused = some [.constructor 1, .value] := by
  apply Def.kinds_complete
  exact ⟨rfl, by simp [Def.kindUses, unused, mapDef, kindUsesTys, Ty.kindUses, kindUsesEff, Eff.empty], trivial, trivial, trivial⟩

-- 旧の制約・名前・メソッドの表を保ち、新欄の既定をvalueにする。
theorem legacy_parameter_roundtrip (p : Benitoite.Release.TParam) : (embedTParam p).constraints = p := rfl

theorem legacy_class_default (c : Benitoite.Release.ClassDecl) : (embedClassDecl c).argumentKind = .value := rfl

theorem legacy_method_parameters (m : Benitoite.Release.MethSig) :
    (embedMethSig m).tparams.map TParamDecl.constraints = m.tparams := embedMethSig_constraints m

end Benitoite.Release.Refinement.KindReviewBoundary

#print axioms Benitoite.Release.Refinement.KindReviewBoundary.option_arity
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.map_kind_uses
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.map_declared_kinds
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.map_kind_wf
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.map_accepted
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.dictionary_parameter_accepted
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.dictionary_option_accepted
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.dictionary_integer_rejected
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.implementation_integer_rejected
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.implementation_option_accepted
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.binary_parameter_accepted
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.binary_constructor_accepted
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.wrong_arity_rejected
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.value_dictionary_accepted
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.value_class_constructor_rejected
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.concrete_bad_annotation_rejected
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.declaration_mismatch_rejected
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.unused_declared_kind_preserved
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.legacy_parameter_roundtrip
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.legacy_class_default
#print axioms Benitoite.Release.Refinement.KindReviewBoundary.legacy_method_parameters
