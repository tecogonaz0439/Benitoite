import Benitoite.Release.Typing

namespace Benitoite.Release.Refinement

/-- 整数を観測する有限項。番号は Nat の de Bruijn 添字である。 -/
inductive Term where
  | var (index : Nat)
  | integer (value : Int)
  | add (a b : Term)
  deriving DecidableEq

/-- 一階の整数の条件。 -/
inductive Pred where
  | truth | falsity
  | eq (a b : Term) | le (a b : Term) | lt (a b : Term)
  | and (p q : Pred) | or (p q : Pred) | not (p : Pred)
  deriving DecidableEq

mutual
/-- 型。旧型の欄を保ち、有限の述語による篩を子にも格納できる。
`opaque o ix` は範囲の位置 ix を持つ不透明型（添字のない旧型は Top の範囲位置へ写す）。`tvar i` は番号 i の型パラメータ。`cont b t ε` は継続の型 `Cont(B → T ! ε)`。`dict cl τ` は辞書の型
`Dict[Cl, τ]`、`tapp i Ā` は型構成子を表す型パラメータの適用 `α[Ā]`、`ctor φ` は型構成子 φ である。 -/
inductive Ty where
  | base (ι : BaseTy)
  | opaque (o : OpaqueName) (ix : Scope.Signature.Ix)
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


/-- 名前と行の所属、および Fail のエラー型の有限列。 -/
inductive EffR where
  | mk (atoms : Atom → Bool) (fails : List Ty)
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
    | .opaque o ix => .opaque o ix
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
    | .mk a fs => .mk a (embedTys fs)
end

@[simp] theorem embedTys_eq_map (as : List Benitoite.Release.Ty) :
    embedTys as = as.map embedTy := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [embedTys, List.map_cons, ih]

end Benitoite.Release.Refinement
