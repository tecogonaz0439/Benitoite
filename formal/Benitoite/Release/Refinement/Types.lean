import Benitoite.Release.Refinement.TermSyntax
import Benitoite.Release.Refinement.Atoms

namespace Benitoite.Release.Refinement

inductive TyKind where
  | value
  | constructor (arity : Nat)
  deriving DecidableEq

abbrev KindCtx := List TyKind

/-- 関数の型パラメータの宣言。操作・実装の値型パラメータの制約とは分ける。 -/
structure TParamDecl where
  constraints : Benitoite.Release.TParam := {}
  kind : TyKind := .value

def embedTParam (p : Benitoite.Release.TParam) : TParamDecl := ⟨p, .value⟩

@[simp] theorem embedTParam_constraints (p : Benitoite.Release.TParam) :
    (embedTParam p).constraints = p := rfl
@[simp] theorem embedTParam_kind (p : Benitoite.Release.TParam) :
    (embedTParam p).kind = .value := rfl

/-- 宣言した kind と組込みの制約を、同じ型パラメータの位置で保持する。 -/
abbrev TypeCtx := List TParamDecl

namespace TypeCtx
  def constraints (C : TypeCtx) : List Benitoite.Release.TParam :=
    C.map TParamDecl.constraints
  def kinds (C : TypeCtx) : KindCtx := C.map TParamDecl.kind
  def values (ps : List Benitoite.Release.TParam) : TypeCtx := ps.map embedTParam
  def valueParam : TParamDecl := ⟨{}, .value⟩

  theorem kinds_eq_map (C : TypeCtx) : kinds C = C.map TParamDecl.kind := rfl

  @[simp] theorem constraints_values (ps : List Benitoite.Release.TParam) :
      constraints (values ps) = ps := by simp [constraints, values, List.map_map, Function.comp_def]
  @[simp] theorem kinds_values (ps : List Benitoite.Release.TParam) :
      kinds (values ps) = List.replicate ps.length .value := by
    induction ps <;> simp_all [kinds, values, embedTParam, List.replicate_succ, Function.comp_def]
  @[simp] theorem length_values (ps : List Benitoite.Release.TParam) :
      (values ps).length = ps.length := by simp [values]
end TypeCtx

theorem embedTParam_injective : Function.Injective embedTParam := by
  intro a b h
  exact congrArg TParamDecl.constraints h


mutual
/-- 型。旧型の欄を保ち、有限の述語による篩を子にも格納できる。
`opaque o ix` は範囲の位置 ix を持つ不透明型（添字のない旧型は Top の範囲位置へ写す）。`tvar i` は番号 i の型パラメータ。`cont b t ε` は継続の型 `Cont(B → T ! ε)`。`dict cl τ` は辞書の型
`Dict[Cl, τ]`、`tapp i Ā` は型構成子を表す型パラメータの適用 `α[Ā]`、`ctor φ` は型構成子 φ である。 -/
inductive Ty where
  | base (ι : BaseTy)
  | opaque (o : OpaqueName) (ix : RangeIx)
  | data (d : DataName) (args : List Ty)
  | list (a : Ty)
  | fn (names : List String) (params : List Ty) (ret : Ty) (eff : EffR)
  | tvar (i : Nat)
  | reference (a : Ty)
  | lazy (a : Ty)
  | cont (b : Ty) (t : Ty) (eff : EffR)
  | map (k : Ty) (v : Ty)
  | set (a : Ty)
  | bytes
  | dict (cl : ClassName) (τ : Ty)
  | tapp (i : Nat) (args : List Ty)
  | ctor (φ : TyCon)
  | refined (a : Ty) (p : Pred)
  | dependentFn (signature : Tel)
  | external (id : ExternalId) (arguments : List Ty)
  | scoped (name : OpaqueName) (kind : Scope.Domain.Kind) (index : RangeIx)
  | pathBases
  | scopePattern (kind : Scope.Domain.Kind)


/-- 名前と行の所属、および Fail のエラー型の有限列。 -/
inductive EffR where
  | mk (atoms : Atom → Bool) (fails : List Ty)

inductive Tel where
  | done (result : Ty) (effect : EffR)
  | param (name : String) (argument : Ty) (rest : Tel)
end

abbrev Eff := EffR

namespace Eff

/-- 名前と行の所属関数。 -/
def atoms : Eff → Atom → Bool
  | .mk a _ => a

/-- Fail のエラー型の生の列。 -/
def fails : Eff → List Ty
  | .mk _ fs => fs

abbrev test (e : Eff) (a : Atom) : Bool := e.atoms a
abbrev mem (e : Eff) (a : Atom) : Prop := test e a = true

end Eff

/-- 契約名は引数型と同じ個数であり、重複しない。
名前は宣言順に対応し、de Bruijn の局所変数とは区別する。 -/
def NamesWF (names : List String) (params : List Ty) : Prop :=
  names.length = params.length ∧ names.Nodup


mutual
  /-- 旧型の全ての子を新構文へ写す。 -/
  def embedTy : Benitoite.Release.Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o (embedIx ix)
    | .data d as => .data d (embedTys as)
    | .list a => .list (embedTy a)
    | .fn ns ps r e => .fn ns (embedTys ps) (embedTy r) (embedEff e)
    | .tvar i => .tvar i
    | .reference a => .reference (embedTy a)
    | .lazy a => .lazy (embedTy a)
    | .cont b t e => .cont (embedTy b) (embedTy t) (embedEff e)
    | .map a b => .map (embedTy a) (embedTy b)
    | .set a => .set (embedTy a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (embedTy a)
    | .tapp i as => .tapp i (embedTys as)
    | .ctor c => .ctor c
  def embedTys : List Benitoite.Release.Ty → List Ty
    | [] => []
    | a :: as => embedTy a :: embedTys as
  def embedEff : Benitoite.Release.Eff → Eff
    | .mk a fs => .mk (embedAtoms a) (embedTys fs)
end

@[simp] theorem embedTys_eq_map (as : List Benitoite.Release.Ty) :
    embedTys as = as.map embedTy := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [embedTys, List.map_cons, ih]

end Benitoite.Release.Refinement
