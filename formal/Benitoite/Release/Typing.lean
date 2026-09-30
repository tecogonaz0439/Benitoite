import Benitoite.Release.Subst

/-!
# 型付け規則（段階 B）

設計書 01-12 の型付け規則に、「初回リリース版の拡張」の制御の構成の型付けを加える。
計算の判断は 01-12 の `Γ; R ⊢c M : A ! ε` であり、値の判断にはストアの型付け Ψ を加える。

段階 A からの表現の違い:

- 型付けの判断は、型パラメータの組み込みの制約の並び `C`（型の変数の番号の順）を持つ（ADR 0297）。V-Prim は
  組み込みの関数の型パラメータの制約を `C` のもとで確かめ、V-Fun は型引数が関数の型パラメータの制約を
  満たすことを確かめる。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、`Builtins.sat` で与える。
- 環境 Γ の要素は `Option Ty` である。V-Lam の前提と `lazy M` の M の検査では、Γ から継続の型を持つ変数を
  除く（01-12「ハンドラ」）。番号で表した変数を除くと番号がずれるので、要素を `none` に置き換えて表す。
- 型クラスのメソッドの型と実装の定義は、型の変数を番号で表す（`Syntax.lean` の `MethSig`・`ImplDecl`）。
  D-Impl のメソッドの本体の型付けは、メソッドの型パラメータを内側（番号 `0..g-1`）、実装の型パラメータを
  外側に並べた制約の並びで行う。
- `handle` の節が処理する操作の型パラメータは、節の中で型の変数の番号 `0..k-1` に束縛し、制約の並びの
  先頭に加える（01-06「その型パラメータをほかの何とも等しくない型として扱う」）。節の外側の型（環境の型、
  `handle` の式の型、R）は、節の中では番号を k だけずらす。
-/

namespace Benitoite.Release

/-! ## 組み込みの関数 -/

abbrev ErrKind := String

/-- 組み込みの関数の結果。値、実行時エラー、プロセスの終了（E-Exit の `b(W̄) ↦ exit(n)`）。 -/
inductive Outcome where
  | val (v : Val)
  | err (r : ErrKind)
  | exit (n : Int)

/-- 組み込みの関数の種類。ストアの規則（E-RefNew など）を使う関数は、E-Prim・E-IO を使わない
（01-12「ストア：可変のセルと明示遅延」）。終了状態を指定したプロセスの終了の関数（`exit`）には、E-IO を使わず
E-Exit を使う（01-12「プロセスの終了」）。 -/
inductive PrimKind where
  | pure | io | exit | refNew | refGet | refSet | refUpdate | force
  deriving DecidableEq

structure PrimSig where
  tparams : List TParam
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  /-- 型パラメータの制約（組み込みの制約と演算子の型の集まり）。制約の並び `C` のもとで判定する。 -/
  admits : List TParam → List Ty → Prop
  kind : PrimKind
  /-- 組み込みのエフェクトの操作のとき、そのエフェクトの名前。 -/
  opEff : Option EffName

def PrimSig.ntys (s : PrimSig) : Nat := s.tparams.length

/-- 組み込みの関数と、01-12 がほかの章に委ねているもの。 -/
structure Builtins where
  sig : PrimName → Option PrimSig
  /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)（ADR 0296）。 -/
  delta : PrimName → List Ty → List Eff → List Val → Option Outcome
  /-- IO を行う組み込みの関数の応答として起こりうるもの。 -/
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → Prop
  /-- 事象 `release(V)` の応答として起こりうるもの。`none` が `ok`、`some r` が `error(r)`。 -/
  releaseResponse : Val → Option ErrKind → Prop
  /-- リソースの型か。リソースの型の解放のエフェクト `rel(O_r)` は `{State}` である。 -/
  isResource : OpaqueName → Bool
  /-- 組み込みのエフェクトと、その操作。`State` は操作を持たない。 -/
  effects : EffName → Option (List PrimName)
  /-- 型が組み込みの制約を満たすか（01-06「等値の型」「鍵の型」）。制約の並び `C` のもとで判定する。 -/
  sat : List TParam → Ty → TParam → Prop
  /-- `Reference.get` と `Reference.set` の名前。`Reference.update` の遷移が使う。 -/
  refGet : PrimName
  refSet : PrimName

def fnTy (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
  Ty.subst ts es (.fn params ret eff)

/-- 型引数 `ts` が、型パラメータの制約 `tps` を、制約の並び `C` のもとで満たす。制約の並びは、型の変数の番号の
順（内側から）に並べる。 -/
def SatAll (B : Builtins) (C : List TParam) (ts : List Ty) (tps : List TParam) : Prop :=
  ts.length = tps.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → tps[i]? = some p → B.sat C t p

/-! ## 操作 -/

/-- 操作の型 `∀ᾱ. (Ā) → B ! {L}`。 -/
structure OpSig where
  tparams : List TParam
  params : List Ty
  ret : Ty
  eff : EffName

def opSig (P : Program) (B : Builtins) : OpRef → Option OpSig
  | .user o => (P.ops o).map fun od => ⟨od.tparams, od.params, od.ret, od.eff⟩
  | .prim b =>
      match B.sig b with
      | some s =>
          match s.opEff with
          | some l => some ⟨s.tparams, s.params, s.ret, l⟩
          | none => none
      | none => none

/-- エフェクト L の操作の一覧。利用者が宣言したエフェクトか、組み込みのエフェクト。 -/
def effOps (P : Program) (B : Builtins) (l : EffName) : Option (List OpRef) :=
  match P.effects l with
  | some os => some (os.map .user)
  | none => (B.effects l).map (·.map .prim)

/-- `handles(H, op)`。 -/
def handles (h : List Clause) (o : OpRef) : Bool := h.any (fun c => c.op == o)

/-- `handled(H)`。一つ以上の操作を持ち、そのすべての操作の節を H が持つエフェクトの集合。 -/
def handled (P : Program) (B : Builtins) (h : List Clause) : Eff := fun a =>
  match a with
  | .name l =>
      match effOps P B l with
      | some (o :: os) => (o :: os).all (handles h)
      | _ => false
  | .rho _ => false

/-! ## 型の正しさ -/

mutual
  /-- 型の中の型の変数の番号が `n` より小さい（その位置で束縛された型の変数だけを使う）。 -/
  def Ty.WF (n : Nat) : Ty → Prop
    | .base _ => True
    | .opaque _ => True
    | .data _ args => Ty.WFList n args
    | .list a => Ty.WF n a
    | .fn params ret _ => Ty.WFList n params ∧ Ty.WF n ret
    | .tvar i => i < n
    | .reference a => Ty.WF n a
    | .lazy a => Ty.WF n a
    | .cont b t _ => Ty.WF n b ∧ Ty.WF n t
    | .map a b => Ty.WF n a ∧ Ty.WF n b
    | .set a => Ty.WF n a
    | .bytes => True
    | .dict _ τ => Ty.WF n τ
    | .tapp i args => i < n ∧ Ty.WFList n args
    | .ctor _ => True

  def Ty.WFList (n : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Ty.WF n a ∧ Ty.WFList n as
end

/-! ## 型の包含 -/

def Ty.Le (a a' : Ty) : Prop :=
  a = a' ∨ ∃ ps r ε ε', a = .fn ps r ε ∧ a' = .fn ps r ε' ∧ Eff.Sub ε ε'

/-! ## ストアの型付けと環境 -/

/-- ストアの場所の型。可変のセル、明示遅延、継続（継続の型と、継続を作った節の R）。 -/
inductive LocTy where
  | ref (a : Ty)
  | lazy (a : Ty)
  | cont (b t : Ty) (ε : Eff) (r : Option Ty)

/-- ストアの型付け Ψ。 -/
abbrev StoreTy := Nat → Option LocTy

/-- 環境から継続の型を持つ変数を除く。番号をずらさないように、要素を `none` にする。 -/
def hideConts (Γ : List (Option Ty)) : List (Option Ty) :=
  Γ.map fun o => match o with
    | some (.cont _ _ _) => none
    | x => x

/-- 型の並びを、環境に加える形にする。 -/
def binds (as : List Ty) : List (Option Ty) := as.reverse.map some

/-- 環境の型の番号をずらす（節の内側に入るとき）。 -/
def shiftEnv (k : Nat) (Γ : List (Option Ty)) : List (Option Ty) := Γ.map (Option.map (Ty.shift k 0))

/-! ## パターンと網羅性 -/

mutual
  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop
    | P_Wild {a} : PatTy P .wild a []
    | P_Var {a} : PatTy P .var a [a]
    | P_Const {c} :
        (∀ x, c ≠ .float x) → (∀ n, c ≠ .byte n) → (∀ n s, c ≠ .decimal n s) →
        (∀ o n, c ≠ .opaque o n) →
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

mutual
  /-- 網羅性を考えるうえでの値の形。パターンが中を調べない型（関数の型、型パラメータ、セル、明示遅延、
  継続、マップ、集合、バイト列、辞書、型パラメータの適用、型構成子）には、どの値も属するとする。 -/
  inductive Inhabits (P : Program) : Ty → Val → Prop
    | const {c} : Inhabits P c.type (.const c)
    | con {c ts tys' args cd} :
        P.cons c = some cd → cd.ntys = ts.length →
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
        Inhabits P (.data cd.data ts) (.con c tys' args)
    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
    | fn {ps r ε v} : Inhabits P (.fn ps r ε) v
    | tvar {i v} : Inhabits P (.tvar i) v
    | reference {a v} : Inhabits P (.reference a) v
    | lazy {a v} : Inhabits P (.lazy a) v
    | cont {b t ε v} : Inhabits P (.cont b t ε) v
    | map {a b v} : Inhabits P (.map a b) v
    | set {a v} : Inhabits P (.set a) v
    | bytes {v} : Inhabits P .bytes v
    | dict {cl τ v} : Inhabits P (.dict cl τ) v
    | tapp {i as v} : Inhabits P (.tapp i as) v
    | ctor {φ v} : Inhabits P (.ctor φ) v

  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop
    | nil : InhabitsAll P [] []
    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)

  inductive InhabitsEach (P : Program) : Ty → List Val → Prop
    | nil {a} : InhabitsEach P a []
    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
end

def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a v → ∃ p ∈ ps, (Pat.matchVal p v).isSome

/-! ## 値と計算の型付け -/

mutual
  /-- `Γ ⊢v V : A`（制約の並び C とストアの型付け Ψ のもとで）。 -/
  inductive HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Val → Ty → Prop
    /-- 継続の型の変数は、`resume` の第一引数にだけ書ける（C-Resume。ADR 0300）。 -/
    | V_Var {Γ i a} : Γ[i]? = some (some a) → (∀ b t ε, a ≠ .cont b t ε) →
        HasTypeV P B Ψ C Γ (.var i) a
    | V_Const {Γ c} : HasTypeV P B Ψ C Γ (.const c) c.type
    | V_Fun {Γ f d ts es} :
        P.defs f = some d → SatAll B C ts d.tparams → es.length = d.neffs →
        HasTypeV P B Ψ C Γ (.fnRef f ts es) (fnTy d.params d.ret d.eff ts es)
    | V_Prim {Γ b s ts es} :
        B.sig b = some s → ts.length = s.ntys → es.length = s.neffs → s.admits C ts →
        HasTypeV P B Ψ C Γ (.prim b ts es) (fnTy s.params s.ret s.eff ts es)
    | V_Op {Γ o od ts} :
        P.ops o = some od → SatAll B C ts od.tparams →
        HasTypeV P B Ψ C Γ (.op o ts) (fnTy od.params od.ret (Eff.single od.eff) ts [])
    | V_Lam {Γ ps body r ε} :
        HasTypeC P B Ψ C (binds ps ++ hideConts Γ) (some r) body r ε →
        HasTypeV P B Ψ C Γ (.lam ps body) (.fn ps r ε)
    | V_Con {Γ c ts args cd} :
        P.cons c = some cd → ts.length = cd.ntys →
        HasTypeVs P B Ψ C Γ args (cd.args.map (Ty.subst ts [])) →
        HasTypeV P B Ψ C Γ (.con c ts args) (.data cd.data ts)
    /-- V-List。要素の型は、その位置で束縛された型の変数だけを使う（空のリストの要素の型は項に現れないので、
    型の正しさを前提に置く）。 -/
    | V_List {Γ elems a} :
        HasTypeEach P B Ψ C Γ elems a → Ty.WF C.length a → HasTypeV P B Ψ C Γ (.list elems) (.list a)
    /-- `Ψ(ℓ) = A` のとき `ℓ : A`（01-12「確かめる性質」）。 -/
    | V_LocRef {Γ l a} : Ψ l = some (.ref a) → HasTypeV P B Ψ C Γ (.loc l) (.reference a)
    | V_LocLazy {Γ l a} : Ψ l = some (.lazy a) → HasTypeV P B Ψ C Γ (.loc l) (.lazy a)
    /-- V-Map。鍵と値の型は、V-List と同じく、その位置で束縛された型の変数だけを使う。 -/
    | V_Map {Γ ks vs a b} :
        HasTypeEach P B Ψ C Γ ks a → HasTypeEach P B Ψ C Γ vs b → ks.length = vs.length →
        B.sat C a TParam.keyC → Ty.WF C.length a → Ty.WF C.length b →
        HasTypeV P B Ψ C Γ (.mapV ks vs) (.map a b)
    | V_Set {Γ elems a} :
        HasTypeEach P B Ψ C Γ elems a → B.sat C a TParam.keyC → Ty.WF C.length a →
        HasTypeV P B Ψ C Γ (.setV elems) (.set a)
    | V_Bytes {Γ bs} : HasTypeV P B Ψ C Γ (.bytesV bs) .bytes
    /-- V-Dict。実装の型パラメータの制約を、型引数が満たす。 -/
    | V_Dict {Γ i ts vs id} :
        P.impls i = some id → SatAll B C ts id.tparams →
        HasTypeVs P B Ψ C Γ vs (id.dictTys.map (Ty.subst ts [])) →
        HasTypeV P B Ψ C Γ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))
    | V_Super {Γ v cl τ cd s} :
        HasTypeV P B Ψ C Γ v (.dict cl τ) → P.classes cl = some cd → s ∈ cd.supers →
        HasTypeV P B Ψ C Γ (.super v s) (.dict s τ)
    | V_Sub {Γ v a a'} :
        HasTypeV P B Ψ C Γ v a → Ty.Le a a' → HasTypeV P B Ψ C Γ v a'

  inductive HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → List Val → List Ty → Prop
    | nil {Γ} : HasTypeVs P B Ψ C Γ [] []
    | cons {Γ v vs a as} :
        HasTypeV P B Ψ C Γ v a → HasTypeVs P B Ψ C Γ vs as → HasTypeVs P B Ψ C Γ (v :: vs) (a :: as)

  inductive HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → List Val → Ty → Prop
    | nil {Γ a} : HasTypeEach P B Ψ C Γ [] a
    | cons {Γ v vs a} :
        HasTypeV P B Ψ C Γ v a → HasTypeEach P B Ψ C Γ vs a → HasTypeEach P B Ψ C Γ (v :: vs) a

  /-- `Γ; R ⊢c M : A ! ε`。R は最も内側の関数の戻り値の型で、`none` は `escape` を許さない。 -/
  inductive HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Option Ty → Comp → Ty → Eff → Prop
    | C_Return {Γ R v a} : HasTypeV P B Ψ C Γ v a → HasTypeC P B Ψ C Γ R (.ret v) a Eff.empty
    | C_Sub {Γ R m a a' ε ε'} :
        HasTypeC P B Ψ C Γ R m a ε → Ty.Le a a' → Eff.Sub ε ε' → HasTypeC P B Ψ C Γ R m a' ε'
    | C_Let {Γ R m n a b ε} :
        HasTypeC P B Ψ C Γ R m a ε → HasTypeC P B Ψ C (some a :: Γ) R n b ε →
        HasTypeC P B Ψ C Γ R (.letIn m n) b ε
    | C_App {Γ R f args as b ε} :
        HasTypeV P B Ψ C Γ f (.fn as b ε) → HasTypeVs P B Ψ C Γ args as →
        HasTypeC P B Ψ C Γ R (.app f args) b ε
    | C_If {Γ R v m n a ε} :
        HasTypeV P B Ψ C Γ v (.base .boolean) → HasTypeC P B Ψ C Γ R m a ε →
        HasTypeC P B Ψ C Γ R n a ε → HasTypeC P B Ψ C Γ R (.ite v m n) a ε
    | C_Match {Γ R v arms a b ε} :
        HasTypeV P B Ψ C Γ v a → HasTypeArms P B Ψ C Γ R arms a b ε →
        Exhaustive P a (arms.map Prod.fst) → HasTypeC P B Ψ C Γ R (.match v arms) b ε
    /-- `Γ ⊢c M : A ! { }` のとき `Γ ⊢c lazy M : Lazy[A] ! { }`。M は R を持たない判断で、継続の型を持つ
    変数を除いた環境で検査する（01-12「ストア」「関数の境界と escape」「ハンドラ」）。 -/
    | C_Lazy {Γ R m a} :
        HasTypeC P B Ψ C (hideConts Γ) none m a Eff.empty →
        HasTypeC P B Ψ C Γ R (.lazyC m) (.lazy a) Eff.empty
    /-- `Γ; R ⊢v V : R` のとき、`Γ; R ⊢c escape V : A ! ε`（任意の A と ε）。 -/
    | C_Escape {Γ r v a ε} :
        HasTypeV P B Ψ C Γ v r → Ty.WF C.length a → HasTypeC P B Ψ C Γ (some r) (.escape v) a ε
    /-- C-Use。解放のエフェクト `rel(O_r) = {State}` を ε が含む。 -/
    | C_Use {Γ R v o m b ε} :
        HasTypeV P B Ψ C Γ v (.opaque o) → B.isResource o = true →
        HasTypeC P B Ψ C Γ R m b ε → ε (.name stateEff) = true →
        HasTypeC P B Ψ C Γ R (.use v m) b ε
    /-- C-Handle。 -/
    | C_Handle {Γ R m h t εm ε} :
        HasTypeC P B Ψ C Γ R m t εm → Eff.Sub εm (Eff.union ε (handled P B h)) →
        HasTypeClauses P B Ψ C Γ R h t ε →
        HasTypeC P B Ψ C Γ R (.handle m h) t ε
    /-- C-Resume（節の変数 k）と C-ResumeL（継続の場所 κ）。継続の型の値は、`resume` の第一引数に
    だけ書ける（ADR 0300）。κ に `resume` するときは、κ を作った節の R が、いまの R と等しい。 -/
    | C_Resume {Γ R i v b t ε} :
        Γ[i]? = some (some (.cont b t ε)) → HasTypeV P B Ψ C Γ v b →
        HasTypeC P B Ψ C Γ R (.resume (.var i) v) t ε
    | C_ResumeL {Γ R l v b t ε} :
        Ψ l = some (.cont b t ε R) → HasTypeV P B Ψ C Γ v b →
        HasTypeC P B Ψ C Γ R (.resume (.loc l) v) t ε
    /-- C-Meth。θ = [τ/P, S̄/γ̄, Ē/ρ̄] は、メソッドの型パラメータ γ̄ の番号 `0..g-1` を S̄ に、型クラスの引数 P の
    番号 g を τ に置き換える。メソッドの型パラメータの制約を、型引数 S̄ が満たす。 -/
    | C_Meth {Γ R v cl τ cd m ms ss es ws} :
        HasTypeV P B Ψ C Γ v (.dict cl τ) → P.classes cl = some cd → cd.methods m = some ms →
        SatAll B C ss ms.tparams → es.length = ms.neffs →
        HasTypeVs P B Ψ C Γ ws (ms.params.map (Ty.subst (ss ++ [τ]) es)) →
        HasTypeC P B Ψ C Γ R (.meth v m ss es ws) (ms.ret.subst (ss ++ [τ]) es) (Eff.substRho es ms.eff)

  inductive HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Option Ty → List (Pat × Comp) → Ty → Ty → Eff → Prop
    | nil {Γ R a b ε} : Ty.WF C.length b → HasTypeArms P B Ψ C Γ R [] a b ε
    | cons {Γ R p m arms a b ε δ} :
        PatTy P p a δ → HasTypeC P B Ψ C (binds δ ++ Γ) R m b ε →
        HasTypeArms P B Ψ C Γ R arms a b ε →
        HasTypeArms P B Ψ C Γ R ((p, m) :: arms) a b ε

  /-- C-Handle の各節 `op(x̄) k ⇒ N`：`Γ, x̄:Ā, k:Cont(B → T ! ε); R ⊢c N : T ! ε`。操作の型パラメータは、
  節の中の型の変数の番号 `0..k-1` に束縛した、宣言の制約を持つ、ほかの型とは等しくない型の変数である。
  節の外側の Γ・T・R の型は、番号を k だけずらす。 -/
  inductive HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) :
      List TParam → List (Option Ty) → Option Ty → List Clause → Ty → Eff → Prop
    | nil {Γ R t ε} : HasTypeClauses P B Ψ C Γ R [] t ε
    | cons {Γ R o n k body cs t ε sg} :
        opSig P B o = some sg → n = sg.params.length → k = sg.tparams.length →
        HasTypeC P B Ψ (sg.tparams ++ C)
          (some (.cont sg.ret (t.shift k 0) ε) :: (binds sg.params ++ shiftEnv k Γ))
          (R.map (Ty.shift k 0)) body (t.shift k 0) ε →
        HasTypeClauses P B Ψ C Γ R cs t ε →
        HasTypeClauses P B Ψ C Γ R (.mk o n k body :: cs) t ε
end

/-! ## 定義とプログラム -/

/-- 空のストアの型付け。定義の本体は場所を含まない。 -/
def StoreTy.empty : StoreTy := fun _ => none

/-- 定義に型が付く。`x1:A1, …, xn:An; B ⊢c M : B ! ε`（R := B）。 -/
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  HasTypeC P B StoreTy.empty d.tparams (binds d.params) (some d.ret) d.body d.ret d.eff

/-- D-Impl のメソッドの型 `Ājθ`・`Bjθ`（θ = [τ/P]）。型クラスの引数 P の番号 g（メソッドの型パラメータの
個数）を、実装の対象 τ に置き換える。 -/
def ImplDecl.methTy (id : ImplDecl) (ms : MethSig) (t : Ty) : Ty :=
  t.substAt ms.tparams.length [id.target] []

/-- 実装の定義に型が付く（D-Impl）。実装の定義は、型クラスが宣言したメソッドと上位の型クラスについてだけ、
本体と辞書を持つ。型クラスの各メソッドの本体を、実装の型パラメータの外側にメソッドの
型パラメータを加えた制約の並びと、辞書の引数 d̄ の後にメソッドの引数 x̄ を並べた環境で、R := Bjθ として検査する。
上位の型クラスの各辞書 U を、辞書の引数 d̄ の環境で検査する。 -/
def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      HasTypeC P B StoreTy.empty (ms.tparams ++ id.tparams)
        (binds (id.dictTys.map (Ty.shift ms.tparams.length 0) ++ ms.params.map (id.methTy ms)))
        (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret) ms.eff) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty id.tparams (binds id.dictTys) u (.dict s id.target))

def Program.WellTyped (P : Program) (B : Builtins) : Prop :=
  (∀ f d, P.defs f = some d → d.WellTyped P B) ∧ (∀ i id, P.impls i = some id → id.WellTyped P B)

end Benitoite.Release
