import Benitoite.Release.Atom

/-!
# 共有する型とエフェクトの表現

型の順序と、項・宣言の構文から同じ型を参照するために分離する。
型の構成と契約名は、設計書 01-12「コア計算と脱糖」に対応する。
-/

namespace Benitoite.Release

/-- 基本型。01-12 の `ι`。既存の Integer・Float・Byte と幅付きの七種を区別する。 -/
inductive BaseTy where
  | integer | float | string | character | boolean | unit | byte | decimal
  | integer8 | integer16 | integer32
  | unsignedInteger16 | unsignedInteger32 | unsignedInteger64 | float32
  deriving DecidableEq, Repr

abbrev DataName := String
abbrev ConName := String
abbrev FunName := String
abbrev PrimName := String
abbrev OpName := String
/-- 中身を見せない型の名前（`IOError`・`NetworkError`・リソースの型など）。01-12 の `O`。 -/
abbrev OpaqueName := String
abbrev ClassName := String
abbrev ImplName := String
abbrev MethName := String

/-- 型構成子 φ（01-12「型クラス」の `τ ::= A | φ`）。型引数を与えずに書いた型構成子であり、高カインドの
型パラメータの型引数と、型構成子を引数にとる型クラスの辞書の型に現れる。高カインドの型パラメータそのものを
型構成子として書く形は、型の変数 `Ty.tvar` で表す。 -/
inductive TyCon where
  | data (d : DataName)
  | list
  | set
  | map
  | reference
  | lazy

mutual
/-- 型。01-12 の型に、初回リリース版の拡張が加える型を加えたもの。
`opaque o ix` は範囲の位置 ix を持つ不透明型（旧の添字のない型は `Ty.opaqueTop o`）。`tvar i` は番号 i の型パラメータ。`cont b t ε` は継続の型 `Cont(B → T ! ε)`。`dict cl τ` は辞書の型
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


/-- 名前と行の所属、および Fail のエラー型の有限列。 -/
inductive EffR where
  | mk (atoms : Atom → Bool) (fails : List Ty)
end

abbrev Eff := EffR

/-- 旧の添字のない不透明型（範囲の位置が Top）を作る明示の構築関数。`.opaque o Ix.top` と同じ項である。
既定引数と暗黙の変換を置かない（`Release.Atom` の先頭のコメント）。 -/
abbrev Ty.opaqueTop (o : OpaqueName) : Ty := .opaque o (.fixed .top)

/-- `Ty.opaqueTop` は `Ix.top` を範囲の位置に持つ。 -/
theorem Ty.opaqueTop_eq (o : OpaqueName) : Ty.opaqueTop o = .opaque o Scope.Signature.Ix.top := rfl

namespace Eff

/-- 名前と行の所属関数。 -/
def atoms : Eff → Atom → Bool
  | .mk a _ => a

/-- Fail のエラー型の生の列。 -/
def fails : Eff → List Ty
  | .mk _ fs => fs

abbrev test (e : Eff) (a : Atom) : Bool := e.atoms a
abbrev mem (e : Eff) (a : Atom) : Prop := test e a = true
abbrev ofAtoms (a : Atom → Bool) : Eff := .mk a []

/-- 生の列も等しいことを確認して効果の等号を導く。 -/
theorem ext {e f : Eff} (ha : ∀ a, mem e a ↔ mem f a) (hf : e.fails = f.fails) : e = f := by
  cases e with
  | mk a fs =>
    cases f with
    | mk b gs =>
      have hab : a = b := funext (fun x => Bool.eq_iff_iff.mpr (ha x))
      cases hab; cases hf; rfl

theorem ext_test {e f : Eff} (ha : ∀ a, test e a = test f a) (hf : e.fails = f.fails) : e = f :=
  ext (fun a => Bool.eq_iff_iff.mp (ha a)) hf

end Eff

/-- 契約名は引数型と同じ個数であり、重複しない。
名前は宣言順に対応し、de Bruijn の局所変数とは区別する。 -/
def NamesWF (names : List String) (params : List Ty) : Prop :=
  names.length = params.length ∧ names.Nodup

end Benitoite.Release
