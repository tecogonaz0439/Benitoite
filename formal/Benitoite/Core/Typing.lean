import Benitoite.Core.Subst

/-!
# 型付け規則（段階 A）

設計書 01-12「型付け規則」（値、計算、パターン、定義）を書き写す。

01-12 との表現の違い:

- 型の環境 Γ は型の並びで、先頭が番号 0 の変数の型である。`Γ, x1:A1, …, xn:An` は
  `params.reverse ++ Γ` に当たる。
- P-Con の「Δ1, …, Δn の変数はすべて異なる」は、変数を番号で表すので要らない。
- C-Match の「A について網羅的である」は、01-05 の検査の手順ではなく、
  「型 A のどの値にも、照合する分岐がある」こととして定める（`Exhaustive`）。
  01-05 の検査がこの性質を満たすことは、段階 2 の対象にしない（型推論と同じ扱い）。
- 組み込みの関数の型と制約は、01-12 が他の章に委ねているので、`Builtins` の欄として与える。
- 網羅性の `Inhabits` は、型の付いた閉じた値の集合より広い「値の形」の集合である。関数の型と型パラメータには
  どの値も、構成子の値には型引数によらず属するとする。広い集合について網羅的であれば、型の付いた値についても
  網羅的である。
- エフェクトの集合は無限集合も表せるので、型付けは 01-12 より広い（01-12 の導出はどれもここでの導出になる）。
  この型付けについて証明した性質は、01-12 の型付けについても成り立つ。
-/

namespace Benitoite.Core

/-! ## 組み込みの関数 -/

/-- 実行時エラーの種類 `r`。01-12 は種類の中身を定めないので、名前で表す。 -/
abbrev ErrKind := String

/-- 組み込みの関数の結果。01-12 の δ の値と IO の応答は、値 V か `error(r)` である。 -/
inductive Outcome where
  | val (v : Val)
  | err (r : ErrKind)

/-- 組み込みの関数 `b` の型 `∀ᾱ ρ̄. (Ā) → B ! ε` と、型パラメータの制約、IO を行うか。 -/
structure PrimSig where
  ntys : Nat
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  /-- 型パラメータの制約（01-12 の V-Prim の「T̄ が b の型パラメータの制約を満たす」）。 -/
  admits : List Ty → Prop
  /-- IO を行う組み込みの関数か（E-IO・E-IOErr を使うか、E-Prim・E-Err を使うか）。 -/
  io : Bool

/-- 組み込みの関数の型と値。01-12 は、これらを 01-04・01-06・01-07・03-06 に委ねている。
形式化では中身を定めず、`Builtins.Assumptions`（`Assumptions.lean`）の性質だけを仮定する。 -/
structure Builtins where
  sig : PrimName → Option PrimSig
  /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)。型引数とエフェクト引数も受け取る（01-12「実行の規則」）。 -/
  delta : PrimName → List Ty → List Eff → List Val → Option Outcome
  /-- IO を行う組み込みの関数 `b[T̄; Ē]` に `W̄` を渡したときの応答として起こりうるもの。
  型引数とエフェクト引数にもよってよい（01-12「実行の規則」）。 -/
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → Prop

/-- 関数の型の、型とエフェクトの置き換えの後の形。V-Fun と V-Prim の `((Ā) → B ! ε)θ`。 -/
def fnTy (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
  Ty.subst ts es (.fn params ret eff)

/-! ## 型の包含 `A ≤ A'` -/

/-- `A ≤ A'`（01-12「値」の後の【決定】）。A と A' が等しいか、最も外側の関数の型のエフェクトだけが
包含の関係にある。 -/
def Ty.Le (a a' : Ty) : Prop :=
  a = a' ∨ ∃ ps r ε ε', a = .fn ps r ε ∧ a' = .fn ps r ε' ∧ Eff.Sub ε ε'

/-! ## パターン -/

mutual
  /-- `⊢p p : A ⊣ Δ`。Δ は束縛する変数の型を左から順に並べたもの。 -/
  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop
    | P_Wild {a} : PatTy P .wild a []
    | P_Var {a} : PatTy P .var a [a]
    | P_Const {c} :
        (∀ x, c ≠ .float x) → (∀ n, c ≠ .ioError n) →
        PatTy P (.const c) c.type []
    | P_Con {c ps cd ts δ} :
        P.cons c = some cd → ts.length = cd.ntys →
        PatTys P ps (cd.args.map (Ty.subst ts [])) δ →
        PatTy P (.con c ps) (.data cd.data ts) δ

  inductive PatTys (P : Program) : List Pat → List Ty → List Ty → Prop
    | nil : PatTys P [] [] []
    | cons {p ps a as δ δs} :
        PatTy P p a δ → PatTys P ps as δs → PatTys P (p :: ps) (a :: as) (δ ++ δs)
end

/-! ## 網羅性 -/

mutual
  /-- `Inhabits P A V`: 値 V が、網羅性を考えるうえで型 A の値の形をしている。
  型の付いた閉じた値は、その型について `Inhabits` を満たす（証明する補題）。
  関数の型と型パラメータについては、パターンが値の中を調べないので、どの値でもよいとする。 -/
  inductive Inhabits (P : Program) : Ty → Val → Prop
    | const {c} : Inhabits P c.type (.const c)
    | con {c ts tys' args cd} :
        P.cons c = some cd → cd.ntys = ts.length →
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
        Inhabits P (.data cd.data ts) (.con c tys' args)
    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
    | fn {ps r ε v} : Inhabits P (.fn ps r ε) v
    | tvar {i v} : Inhabits P (.tvar i) v

  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop
    | nil : InhabitsAll P [] []
    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)

  inductive InhabitsEach (P : Program) : Ty → List Val → Prop
    | nil {a} : InhabitsEach P a []
    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
end

/-- C-Match の「p1, …, pn は A について網羅的である」。 -/
def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a v → ∃ p ∈ ps, (Pat.matchVal p v).isSome

/-! ## 値と計算の型付け -/

mutual
  /-- `Γ ⊢v V : A`。 -/
  inductive HasTypeV (P : Program) (B : Builtins) : List Ty → Val → Ty → Prop
    | V_Var {Γ i a} : Γ[i]? = some a → HasTypeV P B Γ (.var i) a
    | V_Const {Γ c} : HasTypeV P B Γ (.const c) c.type
    | V_Fun {Γ f d ts es} :
        P.defs f = some d → ts.length = d.ntys → es.length = d.neffs →
        HasTypeV P B Γ (.fnRef f ts es) (fnTy d.params d.ret d.eff ts es)
    | V_Prim {Γ b s ts es} :
        B.sig b = some s → ts.length = s.ntys → es.length = s.neffs → s.admits ts →
        HasTypeV P B Γ (.prim b ts es) (fnTy s.params s.ret s.eff ts es)
    | V_Lam {Γ ps body r ε} :
        HasTypeC P B (ps.reverse ++ Γ) body r ε →
        HasTypeV P B Γ (.lam ps body) (.fn ps r ε)
    | V_Con {Γ c ts args cd} :
        P.cons c = some cd → ts.length = cd.ntys →
        HasTypeVs P B Γ args (cd.args.map (Ty.subst ts [])) →
        HasTypeV P B Γ (.con c ts args) (.data cd.data ts)
    | V_List {Γ elems a} :
        HasTypeEach P B Γ elems a → HasTypeV P B Γ (.list elems) (.list a)
    | V_Sub {Γ v a a'} :
        HasTypeV P B Γ v a → Ty.Le a a' → HasTypeV P B Γ v a'

  /-- 値の並びと型の並びの、要素ごとの型付け（C-App・V-Con の「各 i」）。 -/
  inductive HasTypeVs (P : Program) (B : Builtins) : List Ty → List Val → List Ty → Prop
    | nil {Γ} : HasTypeVs P B Γ [] []
    | cons {Γ v vs a as} :
        HasTypeV P B Γ v a → HasTypeVs P B Γ vs as → HasTypeVs P B Γ (v :: vs) (a :: as)

  /-- 値の並びのすべてが同じ型を持つ（V-List の「各 i」）。 -/
  inductive HasTypeEach (P : Program) (B : Builtins) : List Ty → List Val → Ty → Prop
    | nil {Γ a} : HasTypeEach P B Γ [] a
    | cons {Γ v vs a} :
        HasTypeV P B Γ v a → HasTypeEach P B Γ vs a → HasTypeEach P B Γ (v :: vs) a

  /-- `Γ ⊢c M : A ! ε`。 -/
  inductive HasTypeC (P : Program) (B : Builtins) : List Ty → Comp → Ty → Eff → Prop
    | C_Return {Γ v a} : HasTypeV P B Γ v a → HasTypeC P B Γ (.ret v) a Eff.empty
    | C_Sub {Γ m a a' ε ε'} :
        HasTypeC P B Γ m a ε → Ty.Le a a' → Eff.Sub ε ε' → HasTypeC P B Γ m a' ε'
    | C_Let {Γ m n a b ε} :
        HasTypeC P B Γ m a ε → HasTypeC P B (a :: Γ) n b ε →
        HasTypeC P B Γ (.letIn m n) b ε
    | C_App {Γ f args as b ε} :
        HasTypeV P B Γ f (.fn as b ε) → HasTypeVs P B Γ args as →
        HasTypeC P B Γ (.app f args) b ε
    | C_If {Γ v m n a ε} :
        HasTypeV P B Γ v (.base .boolean) → HasTypeC P B Γ m a ε → HasTypeC P B Γ n a ε →
        HasTypeC P B Γ (.ite v m n) a ε
    | C_Match {Γ v arms a b ε} :
        HasTypeV P B Γ v a → HasTypeArms P B Γ arms a b ε →
        Exhaustive P a (arms.map Prod.fst) →
        HasTypeC P B Γ (.match v arms) b ε

  /-- C-Match の各分岐 `⊢p pi : A ⊣ Δi` と `Γ, Δi ⊢c Mi : B ! ε`。 -/
  inductive HasTypeArms (P : Program) (B : Builtins) : List Ty → List (Pat × Comp) → Ty → Ty → Eff → Prop
    | nil {Γ a b ε} : HasTypeArms P B Γ [] a b ε
    | cons {Γ p m arms a b ε δ} :
        PatTy P p a δ → HasTypeC P B (δ.reverse ++ Γ) m b ε →
        HasTypeArms P B Γ arms a b ε →
        HasTypeArms P B Γ ((p, m) :: arms) a b ε
end

/-! ## 定義とプログラム -/

/-- 定義に型が付く（01-12「定義」）。`x1:A1, …, xn:An ⊢c M : B ! ε`。 -/
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  HasTypeC P B d.params.reverse d.body d.ret d.eff

/-- プログラムのすべての定義に型が付く。 -/
def Program.WellTyped (P : Program) (B : Builtins) : Prop :=
  ∀ f d, P.defs f = some d → d.WellTyped P B

end Benitoite.Core
