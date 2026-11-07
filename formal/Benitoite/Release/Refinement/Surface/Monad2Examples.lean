import Benitoite.Release.Refinement.Surface.CheckPatterns
import Benitoite.Release.Refinement.Surface.CheckMaterials
import Benitoite.Release.Refinement.SurfaceMain

/-!
# 二引数の型構成子を引数に取る型クラスの宣言・実装・辞書の呼出しと性質1

型構成子 `F[_, _]` を引数に取る三つの型クラスを置く。

- `Functor2` は `map[A, B, X](x: F[A, X], f: (A) -> B with ρ) -> F[B, X] with ρ` を持つ。
- `Applicative2` は上位に `Functor2` を持ち、`pure[A, X](x: A) -> F[A, X]` と
  `apply[A, B, X](fs: F[(A) -> B with ρ, X], x: F[A, X]) -> F[B, X] with ρ` を持つ。
- `Monad2` は上位に `Applicative2` を持ち、`flatMap[A, B, X](x: F[A, X], f: (A) -> F[B, X] with ρ) -> F[B, X] with ρ`
  を持つ。

同じ成功先行の形を持つが別の宣言の二つの data 型 `Result` と `UserResult` に、三つのクラスの実装をそれぞれ置き、
上位の辞書は同じ型の一つ下のクラスの実装で与える。各メソッドの本体は照合する値の二つの構成子で分岐する。
`genericMap[A, B, X, F[_, _]: Monad2]` は受け取った辞書から上位の辞書を二度取り出して map を呼ぶ。
このプログラムは表層の整形式と型付けを満たし（`program_wellFormed`・`program_wellTyped`）、性質1から脱糖した
プログラムは型付く（`desugared_typed`。設計書 01-12「型クラス」「確かめる性質」、07-04「証明する性質」）。
-/

namespace Benitoite.Release.Refinement.Surface.Monad2Examples
noncomputable section

private abbrev vt : TParamDecl := TypeCtx.valueParam
/-- 型構成子 `F[_, _]` の型パラメータ。 -/
private abbrev ft : TParamDecl := ⟨{}, .constructor 2⟩

/-- 行の変数 ρ だけを持つ効果。 -/
def row : Eff := .mk (fun a => decide (a = .rho 0)) []

/-- 関数の型 `(value: a) -> b with ρ`。 -/
abbrev fnTy (a b : Ty) : Ty := .dependentFn (.param "value" a (.done b row))

/-- F はメソッドの型パラメータの直後に束縛される（番号3）。 -/
def mapSig : MethSig :=
  { tparams := [vt, vt, vt], neffs := 1, names := ["x", "f"],
    params := [.tapp 3 [.tvar 0, .tvar 2], fnTy (.tvar 0) (.tvar 1)],
    ret := .tapp 3 [.tvar 1, .tvar 2], eff := row }

/-- pure は効果を持たない（F は番号2）。 -/
def pureSig : MethSig :=
  { tparams := [vt, vt], neffs := 0, names := ["x"], params := [.tvar 0],
    ret := .tapp 2 [.tvar 0, .tvar 1], eff := Eff.empty }

/-- apply の関数側と値側は同じ X を使う。 -/
def applySig : MethSig :=
  { tparams := [vt, vt, vt], neffs := 1, names := ["fs", "x"],
    params := [.tapp 3 [fnTy (.tvar 0) (.tvar 1), .tvar 2], .tapp 3 [.tvar 0, .tvar 2]],
    ret := .tapp 3 [.tvar 1, .tvar 2], eff := row }

/-- flatMap のコールバックも同じ F と X を返す。 -/
def flatMapSig : MethSig :=
  { mapSig with params := [.tapp 3 [.tvar 0, .tvar 2], fnTy (.tvar 0) (.tapp 3 [.tvar 1, .tvar 2])] }

def functor2 : ClassDecl := ⟨.constructor 2, [], fun m => if m = "map" then some mapSig else none⟩
def applicative2 : ClassDecl :=
  ⟨.constructor 2, ["Functor2"], fun m => if m = "pure" then some pureSig else if m = "apply" then some applySig else none⟩
def monad2 : ClassDecl := ⟨.constructor 2, ["Applicative2"], fun m => if m = "flatMap" then some flatMapSig else none⟩

def classTable : ClassName → Option ClassDecl := fun c =>
  if c = "Functor2" then some functor2 else if c = "Applicative2" then some applicative2
  else if c = "Monad2" then some monad2 else none

/-! ## 二つの data 型とメソッドの本体 -/

def okName (name : String) : ConName := name ++ ".Ok"
def errName (name : String) : ConName := name ++ ".Error"

private def one (e : Expr) : Exprs := .cons e .nil
private def call1 (f x : Expr) : Expr := .call f [some "value"] [0] (one x)
private def ok (name : String) (a x : Ty) (e : Expr) : Expr := .conCall (okName name) [a, x] (one e)
private def err (name : String) (a x : Ty) (e : Expr) : Expr := .conCall (errName name) [a, x] (one e)

/-- `match scrutinee { name.Ok(v) => yes; name.Error(e) => no }`。腕の中で番号0は束縛した欄、番号1は照合する値である。 -/
def casesResult (name : String) (ret : Ty) (scrutinee yes no : Expr) : Expr :=
  .matchE ret scrutinee
    (.cons [⟨.con (some name) (okName name) [.var], [0]⟩] none (.last yes)
      (.cons [⟨.con (some name) (errName name) [.var], [0]⟩] none (.last no) .nil))

/-- `map(x, f) = return match x { Ok(v) => Ok(f(v)); Error(e) => Error(e) }`。 -/
def mapBody (name : String) : Block :=
  let ret := Ty.data name [.tvar 1, .tvar 2]
  .last (.returnE ret (casesResult name ret (.local 1)
    (ok name (.tvar 1) (.tvar 2) (call1 (.local 2) (.local 0)))
    (err name (.tvar 1) (.tvar 2) (.local 0))))

/-- `pure(x) = return Ok(x)`。 -/
def pureBody (name : String) : Block :=
  .last (.returnE (.data name [.tvar 0, .tvar 1]) (ok name (.tvar 0) (.tvar 1) (.local 0)))

/-- `apply(fs, x) = return match fs { Ok(g) => match x { Ok(v) => Ok(g(v)); Error(e) => Error(e) }; Error(e) => Error(e) }`。 -/
def applyBody (name : String) : Block :=
  let ret := Ty.data name [.tvar 1, .tvar 2]
  .last (.returnE ret (casesResult name ret (.local 1)
    (casesResult name ret (.local 2)
      (ok name (.tvar 1) (.tvar 2) (call1 (.local 2) (.local 0)))
      (err name (.tvar 1) (.tvar 2) (.local 0)))
    (err name (.tvar 1) (.tvar 2) (.local 0))))

/-- `flatMap(x, f) = return match x { Ok(v) => f(v); Error(e) => Error(e) }`。 -/
def flatMapBody (name : String) : Block :=
  let ret := Ty.data name [.tvar 1, .tvar 2]
  .last (.returnE ret (casesResult name ret (.local 1)
    (call1 (.local 2) (.local 0)) (err name (.tvar 1) (.tvar 2) (.local 0))))

/-! ## 実装と汎用の関数 -/

def functorName (name : String) : ImplName := name ++ "Functor2"
def applicativeName (name : String) : ImplName := name ++ "Applicative2"
def monadName (name : String) : ImplName := name ++ "Monad2"

def functorImpl (name : String) : ImplDecl :=
  { tparams := [], dictParams := [], cls := "Functor2", target := .ctor (.data name),
    supers := fun _ => none, methods := fun m => if m = "map" then some (mapBody name) else none }

def applicativeImpl (name : String) : ImplDecl :=
  { tparams := [], dictParams := [], cls := "Applicative2", target := .ctor (.data name),
    supers := fun s => if s = "Functor2" then some (.impl (functorName name) [] []) else none,
    methods := fun m => if m = "pure" then some (pureBody name) else if m = "apply" then some (applyBody name)
      else none }

def monadImpl (name : String) : ImplDecl :=
  { tparams := [], dictParams := [], cls := "Monad2", target := .ctor (.data name),
    supers := fun s => if s = "Applicative2" then some (.impl (applicativeName name) [] []) else none,
    methods := fun m => if m = "flatMap" then some (flatMapBody name) else none }

/-- `genericMap[A, B, X, F[_, _]: Monad2](x: F[A, X], f: (A) -> B with ρ) -> F[B, X] with ρ`。辞書は値引数より前に
置き、本体では番号2で参照する。上位の辞書を二度取り出して Functor2 の map を呼ぶ。 -/
def genericMap : Def :=
  { tparams := [vt, vt, vt, ft], neffs := 1, names := ["x", "f"],
    params := mapSig.params, ret := mapSig.ret, eff := row,
    dictParams := [("Monad2", 3)],
    body := .last (.returnE mapSig.ret
      (.call (.methName (.super (.super (.local 2) "Applicative2") "Functor2")
        "map" [.tvar 0, .tvar 1, .tvar 2] [row] [] ["x", "f"] mapSig.params)
        [some "x", some "f"] [0, 1] (.cons (.local 1) (.cons (.local 0) .nil)))) }

def consOf (name : String) : List (ConName × ConDecl) :=
  [(okName name, ⟨name, 2, [.tvar 0]⟩), (errName name, ⟨name, 2, [.tvar 1]⟩)]

def implsOf (name : String) : List (ImplName × ImplDecl) :=
  [(functorName name, functorImpl name), (applicativeName name, applicativeImpl name),
    (monadName name, monadImpl name)]

def program : Program where
  defs := fun f => if f = "genericMap" then some genericMap else none
  cons := CheckTables.lookup (consOf "Result" ++ consOf "UserResult")
  classes := classTable
  impls := CheckTables.lookup (implsOf "Result" ++ implsOf "UserResult")

/-- 組込みの表は空である。 -/
def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ p => p = {},
    refGet := "Reference.get", refSet := "Reference.set" }

abbrev op : OpPrim := fun _ _ => none

/-! ## 宣言の表 -/

/-- 二つの data 型の名前。 -/
def Named (name : String) : Prop := name = "Result" ∨ name = "UserResult"

abbrev D : Declarations := program.declarations

theorem cons_ok {name : String} (hn : Named name) :
    D.core.cons (okName name) = some ⟨name, 2, [.tvar 0]⟩ := by
  rcases hn with rfl | rfl <;> rfl

theorem cons_err {name : String} (hn : Named name) :
    D.core.cons (errName name) = some ⟨name, 2, [.tvar 1]⟩ := by
  rcases hn with rfl | rfl <;> rfl

theorem cons_cases {c cd} (h : D.core.cons c = some cd) :
    ∃ name, Named name ∧ ((c = okName name ∧ cd = ⟨name, 2, [.tvar 0]⟩) ∨
      (c = errName name ∧ cd = ⟨name, 2, [.tvar 1]⟩)) := by
  have hm := CheckTables.lookup_mem (show CheckTables.lookup (consOf "Result" ++ consOf "UserResult") c = some cd from h)
  simp only [consOf, List.cons_append, List.nil_append, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hm
  rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
  · exact ⟨"Result", .inl rfl, .inl ⟨rfl, rfl⟩⟩
  · exact ⟨"Result", .inl rfl, .inr ⟨rfl, rfl⟩⟩
  · exact ⟨"UserResult", .inr rfl, .inl ⟨rfl, rfl⟩⟩
  · exact ⟨"UserResult", .inr rfl, .inr ⟨rfl, rfl⟩⟩

theorem data_arity {name : String} (hn : Named name) : D.core.DataArity name 2 :=
  ⟨⟨_, _, cons_ok hn, rfl⟩, fun c cd hc _ => by
    obtain ⟨m, -, ⟨-, rfl⟩ | ⟨-, rfl⟩⟩ := cons_cases hc <;> rfl⟩

theorem arity {name : String} (hn : Named name) : TyCon.arity D.core (.data name) = some 2 :=
  TyCon.arity_data (data_arity hn)

/-! ## 依存列の具体化 -/

@[simp] theorem row_shiftV (k c : Nat) : Eff.shiftV k c row = row := by simp [Eff.shiftV, row]

/-- 正規化した関数の型 `(value: a) -> b with ρ`。 -/
abbrev funTy (a b : Ty) : Ty := .fn ["value"] [a] b row

theorem foldFn_value (a b : Ty) (hb : b.shiftV 1 0 = b) :
    Ty.foldFn (.param "value" a (.done b row)) = funTy a b := by
  have h := Ty.foldFn_toTel ⟨["value"], [a], b, row, by simp [NamesWF]⟩
  simp only [FnView.toTel, Ty.toTel, hb, row_shiftV] at h
  exact h

private abbrev t0 : Ty := .tvar 0
private abbrev t1 : Ty := .tvar 1
private abbrev t2 : Ty := .tvar 2

/-- 実装の型で具体化した map の依存列。 -/
def mapTel (name : String) : Tel :=
  .param "x" (.data name [t0, t2]) (.param "f" (funTy t0 t1) (.done (.data name [t1, t2]) row))

private theorem row_eq : (EffR.mk (fun a => decide (a = Atom.rho 0)) []) = row := rfl

theorem map_tel (name : String) :
    Tel.bind (typeEnvAt mapSig.tparams.length [.ctor (.data name)] []) mapSig.tel = mapTel name := by
  simp [MethSig.tel, mapSig, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt, Tel.norm, Ty.norm,
    Ty.normTys, Eff.norm, rawBindTys, row, substAtoms_nil, instAtoms_nil, rowFails, rawApply, shiftTypes, Ty.shiftV]
  rw [row_eq, foldFn_value _ _ rfl]; rfl

/-- 実装の型で具体化した pure の依存列。 -/
def pureTel (name : String) : Tel := .param "x" t0 (.done (.data name [t0, t1]) Eff.empty)

theorem pure_tel (name : String) :
    Tel.bind (typeEnvAt pureSig.tparams.length [.ctor (.data name)] []) pureSig.tel = pureTel name := by
  simp [MethSig.tel, pureSig, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt, Tel.norm, Ty.norm,
    Ty.normTys, Eff.norm, rawBindTys, substAtoms_nil, instAtoms_nil, rowFails, rawApply, shiftTypes, Ty.shiftV,
    pureTel, Eff.empty]

/-- 実装の型で具体化した apply の依存列。 -/
def applyTel (name : String) : Tel :=
  .param "fs" (.data name [funTy t0 t1, t2]) (.param "x" (.data name [t0, t2]) (.done (.data name [t1, t2]) row))

theorem apply_tel (name : String) :
    Tel.bind (typeEnvAt applySig.tparams.length [.ctor (.data name)] []) applySig.tel = applyTel name := by
  simp [MethSig.tel, applySig, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt, Tel.norm, Ty.norm,
    Ty.normTys, Eff.norm, rawBindTys, row, substAtoms_nil, instAtoms_nil, rowFails, rawApply, shiftTypes, Ty.shiftV]
  rw [row_eq, foldFn_value _ _ rfl]; rfl

/-- 実装の型で具体化した flatMap の依存列。 -/
def flatMapTel (name : String) : Tel :=
  .param "x" (.data name [t0, t2]) (.param "f" (funTy t0 (.data name [t1, t2])) (.done (.data name [t1, t2]) row))

theorem flatMap_tel (name : String) :
    Tel.bind (typeEnvAt flatMapSig.tparams.length [.ctor (.data name)] []) flatMapSig.tel = flatMapTel name := by
  simp [MethSig.tel, flatMapSig, mapSig, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt,
    Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys, row, substAtoms_nil, instAtoms_nil, rowFails, rawApply,
    shiftTypes, Ty.shiftV]
  rw [row_eq, foldFn_value _ _ (by simp [Ty.shiftV])]; rfl

/-! ## 型の注釈 -/

private theorem eff_empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨by intro a ha; simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at ha,
    by intro t ht; obtain ⟨u,hu,_⟩ := ht; simp [Eff.empty,Eff.fails] at hu⟩

theorem tvar_annotation {C : TypeCtx} {Γ : Ctx} {i : Nat} (hi : i < C.length) :
    Ty.Annotation D.core C Γ (.tvar i) := ⟨hi, trivial, trivial⟩

theorem fun_annotation {C : TypeCtx} {Γ : Ctx} {a b : Ty} (ha : Ty.Annotation D.core C Γ a)
    (hb : Ty.Annotation D.core C Γ b) : Ty.Annotation D.core C Γ (funTy a b) :=
  ⟨⟨by simp [NamesWF], ⟨ha.wf, trivial⟩, hb.wf, by simp [Eff.WF, row, Ty.WFList], by simp [Eff.Canonical, Eff.norm, row]⟩,
    ⟨⟨ha.sorted, trivial⟩, hb.sorted, by simp [sortedEff, row, sortedTys]⟩,
    ⟨⟨ha.declared, trivial⟩, hb.declared, by simp [declaredEff, row, declaredTys]⟩⟩

theorem data_annotation {name : String} (hn : Named name) {C : TypeCtx} {Γ : Ctx} {a x : Ty}
    (ha : Ty.Annotation D.core C Γ a) (hx : Ty.Annotation D.core C Γ x) :
    Ty.Annotation D.core C Γ (.data name [a, x]) :=
  ⟨⟨ha.wf, hx.wf, trivial⟩, ⟨ha.sorted, hx.sorted, trivial⟩,
    ⟨⟨2, data_arity hn, rfl⟩, ha.declared, hx.declared, trivial⟩⟩

/-! ## 式の型付け -/

variable (v : CoverageView) (Q : NoFailCtx) (Δ : BuilderCtx) (C : TypeCtx) (Φ : List Pred) (R : Option Ty)
  (p : Position) (ε : Eff)

/-- 局所の値。効果は任意の効果へ広げる。 -/
theorem local_typed {Γ : Ctx} {i : Nat} {a : Ty} (hΓ : Γ[i]? = some (some a)) (ho : Ordinary a)
    (ha : Ty.Annotation D.core C Γ a) :
    HasTypeQ (D.withView v) builtins op Q Δ C Γ Φ R p (.local i) a ε :=
  .E_Sub (.E_Local hΓ ho) .refl (eff_empty_sub _).covers ha

private theorem tvars_kinded {i j : Nat} (hki : (TypeCtx.kinds C)[i]? = some .value)
    (hkj : (TypeCtx.kinds C)[j]? = some .value) :
    TypeArgsKinded D.core C [.tvar i, .tvar j] (List.replicate 2 .value) := by
  refine ⟨rfl, ?_⟩
  intro k a kk ha hk
  match k, ha, hk with
  | 0, ha, hk => cases ha; cases hk; exact ⟨hki, by simp [Ordinary, Ty.core]⟩
  | 1, ha, hk => cases ha; cases hk; exact ⟨hkj, by simp [Ordinary, Ty.core]⟩

/-- `name.Ok[tvar i, tvar j](arg)`。 -/
theorem ok_typed {name : String} (hn : Named name) {Γ : Ctx} {i j : Nat}
    (hi : i < C.length) (hj : j < C.length) (hki : (TypeCtx.kinds C)[i]? = some .value)
    (hkj : (TypeCtx.kinds C)[j]? = some .value) {arg : Expr}
    (harg : HasTypeQ (D.withView v) builtins op Q Δ C Γ Φ R .other arg (.tvar i) ε) :
    HasTypeQ (D.withView v) builtins op Q Δ C Γ Φ R p (.conCall (okName name) [.tvar i, .tvar j] (one arg))
      (.data name [.tvar i, .tvar j]) ε :=
  HasTypeQ.E_ConCall (cons_ok hn) rfl (tvars_kinded C hki hkj) (by simp [Ty.WF])
    (data_annotation hn (tvar_annotation hi) (tvar_annotation hj)) (.cons harg .nil)
    (by
      simp [boundVars, Ty.subst, Ty.substAt, shiftTs, Ty.shiftV, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm]
      exact .cons (tvar_annotation hi) (.var rfl (by simp [Ordinary, Ty.core, Ty.shiftV]))
        (.convert (by simp [Ty.shiftV])) .nil)

/-- `name.Error[tvar i, tvar j](arg)`。 -/
theorem err_typed {name : String} (hn : Named name) {Γ : Ctx} {i j : Nat}
    (hi : i < C.length) (hj : j < C.length) (hki : (TypeCtx.kinds C)[i]? = some .value)
    (hkj : (TypeCtx.kinds C)[j]? = some .value) {arg : Expr}
    (harg : HasTypeQ (D.withView v) builtins op Q Δ C Γ Φ R .other arg (.tvar j) ε) :
    HasTypeQ (D.withView v) builtins op Q Δ C Γ Φ R p (.conCall (errName name) [.tvar i, .tvar j] (one arg))
      (.data name [.tvar i, .tvar j]) ε :=
  HasTypeQ.E_ConCall (cons_err hn) rfl (tvars_kinded C hki hkj) (by simp [Ty.WF])
    (data_annotation hn (tvar_annotation hi) (tvar_annotation hj)) (.cons harg .nil)
    (by
      simp [boundVars, Ty.subst, Ty.substAt, shiftTs, Ty.shiftV, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm]
      exact .cons (tvar_annotation hj) (.var rfl (by simp [Ordinary, Ty.core, Ty.shiftV]))
        (.convert (by simp [Ty.shiftV])) .nil)

/-- 関数の値の呼出し `f(value: x)`。f は正規化した関数の型 `(value: a) -> b with ρ` を持つ局所の値である。 -/
theorem call_typed {Γ : Ctx} {k m : Nat} {a b : Ty} (hk : Γ[k]? = some (some (funTy a b)))
    (hm : Γ[m]? = some (some a)) (hoa : Ordinary a)
    (ha : ∀ Γ', Ty.Annotation D.core C Γ' a) (hb : ∀ Γ', Ty.Annotation D.core C Γ' b)
    (hsa : ∀ n c, a.shiftV n c = a) (hsb : ∀ n c, b.shiftV n c = b)
    (hnorm : (funTy a b).norm = (Ty.dependentFn (.param "value" a (.done b row))).norm)
    (hbind : Tel.bind (Tel.argumentsEnv (.var 0)) (.done b row) = .done b row) :
    HasTypeQ (D.withView v) builtins op Q Δ C Γ Φ R p (call1 (.local k) (.local m)) b row := by
  have hdep : ∀ Γ', Ty.Annotation D.core C Γ' (.dependentFn (.param "value" a (.done b row))) := fun Γ' =>
    ⟨⟨(ha Γ').wf, by simpa [Ty.WF, Ctx.extend] using (hb (Γ'.extend a)).wf, by simp [Eff.WF, row, Ty.WFList],
        by simp [Eff.Canonical, Eff.norm, row]⟩,
      ⟨(ha Γ').sorted, (hb _).sorted, by simp [sortedEff, row, sortedTys]⟩,
      ⟨(ha Γ').declared, (hb _).declared, by simp [declaredEff, row, declaredTys]⟩⟩
  refine HasTypeQ.E_Call (D := D.withView v) (t := .param "value" a (.done b row)) (r := b) (e := row)
    (as := [a]) (b := b) (ε := row) rfl
    (.E_Sub (D := D.withView v) (.E_Local hk (by simp [Ordinary, Ty.core])) (.convert hnorm) (eff_empty_sub _).covers
      (hdep Γ)) ?_ ?_ ?_ ?_ ?_ ?_
  · simp [CallOk, Tel.names, telBinders]
  · exact .cons (local_typed v Q Δ C Φ R .other row hm hoa (ha Γ)) .nil
  · simp only [Tel.shiftV, hsa, row_shiftV]
    refine .param (ha _) (.var rfl (by rw [hsa]; exact hoa)) (by rw [hsa]; exact .refl) ?_
    rw [hsb]
    show ValsTel _ _ _ _ _ _ _ [] (Tel.bind (Tel.argumentsEnv (.var 0)) (.done b row)) b row
    rw [hbind]
    exact .done ⟨⟨(hb _).wf, by simp [Eff.WF, row, Ty.WFList], by simp [Eff.Canonical, Eff.norm, row]⟩,
      ⟨(hb _).sorted, by simp [sortedEff, row, sortedTys]⟩, ⟨(hb _).declared, by simp [declaredEff, row, declaredTys]⟩⟩
  · rw [hsb]; exact .refl
  · simp only [row_shiftV]; exact Eff.Covers.refl _ _ _
  · exact hb Γ

/-! ## 照合 -/

/-- 本体を型付ける宣言の表（既定の照合の見方）。 -/
abbrev Dc : Declarations := D.withView closedView

def ctors : DataName → List ConName := fun d => [okName d, errName d]

theorem ctors_complete : Refinement.CtorsComplete Dc.core ctors := by
  intro c cd h
  obtain ⟨m, -, ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩⟩ := cons_cases h <;> simp [ctors]

theorem cases_exhaustive {name : String} (hn : Named name) (a x : Ty) :
    ViewExhaustive Dc Dc.view (.data name [a, x]) [.con (okName name) [.var], .con (errName name) [.var]] := by
  apply CheckPatterns.exhaustiveWithView_view ctors_complete
  rcases hn with rfl | rfl <;> with_unfolding_all rfl

private theorem var0_data {Γ : Ctx} {name : String} {as : List Ty} :
    (Term.var 0).HasSort (Γ.extend (.data name as)) .data := by
  simp [Term.HasSort, Term.References, Term.VarsIn, Ctx.Readable, Term.Shape, Ctx.extend, Ordinary,
    Ty.core, Ty.HasSort, Ty.sort?, Ty.shiftV]

private theorem test_wf {name : String} {Γ : Ctx} {a x : Ty} {c : ConName}
    {cd : ConDecl} (hc : Dc.core.cons c = some cd) (hd : cd.data = name)
    (hsc : (Ty.data name [a, x]).shiftV 1 0 = .data name [a, x])
    (hnorm : (Ty.data name [a, x]).norm = .data name [a, x]) :
    Pred.WellFormed Dc.core C (Γ.extend (.data name [a, x])) (.constructorIs (.var 0) c) := by
  refine ⟨by simp [Pred.WF, Pred.VarsIn, Term.VarsIn, Ctx.extend], var0_data, ?_⟩
  refine ⟨var0_data.1, name, [a, x], cd, ?_, hc, hd⟩
  exact .var (a := .data name [a, x]) (by simp [Ctx.declarationSelf, Ctx.extend, hsc]) (by rw [hnorm]; rfl)

private theorem no_links_facts {Γ : Ctx} {n : Nat} {obs : Option Term} :
    FactsWF Dc.core C Γ (fieldFacts n obs []) := by
  cases obs <;> simp [FactsWF, fieldFacts]

private theorem obs_cases (Γ : Ctx) : scrutObs Γ = none ∨ scrutObs Γ = some (.var 0) := by
  unfold scrutObs; split <;> simp

private theorem path_facts_wf {name : String} {Γ : Ctx} {a x : Ty} {c : ConName}
    {cd : ConDecl} (hc : Dc.core.cons c = some cd) (hd : cd.data = name)
    (hsc : (Ty.data name [a, x]).shiftV 1 0 = .data name [a, x])
    (hnorm : (Ty.data name [a, x]).norm = .data name [a, x]) :
    FactsWF Dc.core C (Γ.extend (.data name [a, x]))
      (pathFacts (scrutObs (Γ.extend (.data name [a, x]))) [.constructor c, .excluded c]) := by
  rcases obs_cases (Γ.extend (.data name [a, x])) with h | h <;> rw [h]
  · simp [FactsWF, pathFacts]
  · intro q hq
    simp [pathFacts, PathTest.predicate] at hq
    have hw := test_wf C (Γ := Γ) hc hd hsc hnorm
    rcases hq with rfl | rfl
    · exact hw
    · exact ⟨hw.wf, hw.sorted, hw.declared⟩

/-- 二つの構成子で分岐する照合の型付け。腕の本体の型付けは事実の列によらない。 -/
theorem cases_typed {name : String} (hn : Named name) {Γ : Ctx} {j : Nat} {a x ret : Ty} {yes no : Expr}
    (hj : Γ[j]? = some (some (.data name [a, x])))
    (hsa : ∀ n c, a.shiftV n c = a) (hsx : ∀ n c, x.shiftV n c = x) (hsr : ∀ n c, ret.shiftV n c = ret)
    (hε : ∀ n c, Eff.shiftV n c ε = ε)
    (ha : ∀ Γ', Ty.Annotation D.core C Γ' a) (hx : ∀ Γ', Ty.Annotation D.core C Γ' x)
    (hr : ∀ Γ', Ty.Annotation D.core C Γ' ret)
    (hsub0 : Ty.subst [a, x] [] (.tvar 0) = a) (hsub1 : Ty.subst [a, x] [] (.tvar 1) = x)
    (hnorm : (Ty.data name [a, x]).norm = .data name [a, x])
    (hyes : ∀ Φ', HasTypeQ Dc builtins op Q (localExtend 1 (localExtend 1 Δ)) C
      (bindParams (Γ.extend (.data name [a, x])) [a]) Φ' ((R.map (Ty.shiftV 1 0)).map (Ty.shiftV 1 0)) p yes ret ε)
    (hno : ∀ Φ', HasTypeQ Dc builtins op Q (localExtend 1 (localExtend 1 Δ)) C
      (bindParams (Γ.extend (.data name [a, x])) [x]) Φ' ((R.map (Ty.shiftV 1 0)).map (Ty.shiftV 1 0)) p no ret ε) :
    HasTypeQ Dc builtins op Q Δ C Γ Φ R p (casesResult name ret (.local j) yes no) ret ε := by
  have hsc : ∀ n c, (Ty.data name [a, x]).shiftV n c = .data name [a, x] := by
    intro n c; simp [Ty.shiftV, shiftVTys, hsa, hsx]
  have hsc' := hsc 1 0
  unfold casesResult
  refine .E_Match (by simp) (by simp [Ordinary, Ty.core])
    (local_typed closedView Q Δ C Φ R .other ε hj (by simp [Ordinary, Ty.core]) (data_annotation hn (ha _) (hx _)))
    ?_ (cases_exhaustive hn a x) (data_annotation hn (ha _) (hx _)) (hr Γ)
  rw [hsc, hsr, hε]
  apply HasArmsQ.plain (δ := [a]) (links := [])
  · simp [Alternative.Valid, Pattern.Valid, Pattern.ValidList]
  · refine ⟨by simp [Alternative.toCoreList], rfl, ?_, ?_⟩
    · intro alt h
      simp [Alternative.toCoreList, Alternative.toCore] at h; subst h; rfl
    · intro alt h
      simp [Alternative.toCoreList, Alternative.toCore] at h; subst h
      refine ⟨[a], ?_, List.Perm.refl _, rfl⟩
      have hp := PatTy.P_Con (P := Dc.core) (ps := [.var]) (ts := [a, x]) (δ := [a] ++ []) (cons_ok hn) rfl
        (by simp [Ty.WF])
        (by simpa [hsub0] using (PatTys.cons (P := Dc.core) (PatTy.P_Var (a := a)) .nil))
      simpa [Pattern.toCore, Pattern.toCoreList] using hp
  · intro link h; cases h
  · exact no_links_facts C
  · simpa [Alternative.toCoreList, Alternative.toCore, Pattern.toCore, Pattern.toCoreList, matchedTests, excludedTests,
      patternTest?, excludedTest?, irrefutableField] using path_facts_wf C (Γ := Γ) (cons_ok hn) rfl hsc' hnorm
  · simp only [hsr, hε, List.length_cons, List.length_nil, Nat.zero_add]
    exact .B_Last (hyes _)
  · apply HasArmsQ.plain (δ := [x]) (links := [])
    · simp [Alternative.Valid, Pattern.Valid, Pattern.ValidList]
    · refine ⟨by simp [Alternative.toCoreList], rfl, ?_, ?_⟩
      · intro alt h
        simp [Alternative.toCoreList, Alternative.toCore] at h; subst h; rfl
      · intro alt h
        simp [Alternative.toCoreList, Alternative.toCore] at h; subst h
        refine ⟨[x], ?_, List.Perm.refl _, rfl⟩
        have hp := PatTy.P_Con (P := Dc.core) (ps := [.var]) (ts := [a, x]) (δ := [x] ++ []) (cons_err hn) rfl
          (by simp [Ty.WF])
          (by simpa [hsub1] using (PatTys.cons (P := Dc.core) (PatTy.P_Var (a := x)) .nil))
        simpa [Pattern.toCore, Pattern.toCoreList] using hp
    · intro link h; cases h
    · exact no_links_facts C
    · simpa [Alternative.toCoreList, Alternative.toCore, Pattern.toCore, Pattern.toCoreList, matchedTests,
        excludedTests, patternTest?, excludedTest?, irrefutableField] using
        path_facts_wf C (Γ := Γ) (cons_err hn) rfl hsc' hnorm
    · simp only [hsr, hε, List.length_cons, List.length_nil, Nat.zero_add]
      exact .B_Last (hno _)
    · exact .nil

/-! ## メソッドの本体 -/

private abbrev C3 : TypeCtx := [vt, vt, vt]

@[simp] private theorem tvar_shiftV (i n c : Nat) : (Ty.tvar i).shiftV n c = .tvar i := rfl

private theorem data_shiftV (name : String) (i j n c : Nat) :
    (Ty.data name [.tvar i, .tvar j]).shiftV n c = .data name [.tvar i, .tvar j] := by
  simp [Ty.shiftV, shiftVTys]

private theorem fun_shiftV (a b : Ty) (ha : ∀ n c, a.shiftV n c = a) (hb : ∀ n c, b.shiftV n c = b) (n c : Nat) :
    (funTy a b).shiftV n c = funTy a b := by
  simp [funTy, Ty.shiftV, shiftVTys, ha, hb]

@[simp] theorem row_norm : row.norm = row := by
  simp [row, Eff.norm]

@[simp] theorem funTy_tvar_shiftV (i j n c : Nat) : (funTy (.tvar i) (.tvar j)).shiftV n c = funTy (.tvar i) (.tvar j) := by
  simp [funTy, Ty.shiftV, shiftVTys]

@[simp] theorem funTy_data_shiftV (name : String) (i j k n c : Nat) :
    (funTy (.tvar i) (.data name [.tvar j, .tvar k])).shiftV n c = funTy (.tvar i) (.data name [.tvar j, .tvar k]) := by
  simp [funTy, Ty.shiftV, shiftVTys]

private theorem fun_norm (a b : Ty) (ha : a.norm = a) (hb : b.norm = b) (hsb : b.shiftV 1 0 = b) :
    (funTy a b).norm = (Ty.dependentFn (.param "value" a (.done b row))).norm := by
  simp only [Ty.norm, Tel.norm, Ty.normTys, ha, hb, row_norm]
  rw [foldFn_value _ _ hsb]

private theorem done_bind_tvar (i : Nat) :
    Tel.bind (Tel.argumentsEnv (.var 0)) (.done (.tvar i) row) = .done (.tvar i) row := by
  simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv, rowFails, Tel.norm, Ty.norm,
    Eff.norm, rawBindTys, row, substAtoms_nil, instAtoms_nil]

private theorem done_bind_data (name : String) (i j : Nat) :
    Tel.bind (Tel.argumentsEnv (.var 0)) (.done (.data name [.tvar i, .tvar j]) row) =
      .done (.data name [.tvar i, .tvar j]) row := by
  simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv, rowFails, Tel.norm, Ty.norm,
    Ty.normTys, Eff.norm, rawBindTys, row, substAtoms_nil, instAtoms_nil]

/-- map の本体の型付け。 -/
theorem map_body {name : String} (hn : Named name) (Q : NoFailCtx) :
    BodyTy Dc builtins op Q C3 [] [] (mapTel name) (mapBody name) := by
  refine .param (.param (.done ?_))
  refine .B_Last (.E_ReturnTail ?_)
  refine cases_typed Q [] C3 _ _ .tail row hn (j := 1) (a := t0) (x := t2)
    (by simp [Ctx.extend, data_shiftV]) (by simp) (by simp) (data_shiftV name 1 2) (by simp)
    (fun _ => tvar_annotation (by decide)) (fun _ => tvar_annotation (by decide))
    (fun _ => data_annotation hn (tvar_annotation (by decide)) (tvar_annotation (by decide)))
    (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
    (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
    (by simp [Ty.norm, Ty.normTys]) (fun Φ' => ?_) (fun Φ' => ?_)
  · exact ok_typed closedView Q _ C3 Φ' _ .tail row hn (i := 1) (j := 2) (by decide) (by decide) rfl rfl
      (call_typed closedView Q _ C3 Φ' _ .other (k := 2) (m := 0) (a := t0) (b := t1)
        (by simp [bindParams, Ctx.extend]) (by simp [bindParams, Ctx.extend])
        (by simp [Ordinary, Ty.core]) (fun _ => tvar_annotation (by decide)) (fun _ => tvar_annotation (by decide))
        (by simp) (by simp) (fun_norm _ _ rfl rfl rfl) (done_bind_tvar 1))
  · exact err_typed closedView Q _ C3 Φ' _ .tail row hn (i := 1) (j := 2) (by decide) (by decide) rfl rfl
      (local_typed closedView Q _ C3 Φ' _ .other row (i := 0) (a := t2) (by simp [bindParams, Ctx.extend])
        (by simp [Ordinary, Ty.core]) (tvar_annotation (by decide)))

private abbrev C2 : TypeCtx := [vt, vt]

/-- pure の本体の型付け。 -/
theorem pure_body {name : String} (hn : Named name) (Q : NoFailCtx) :
    BodyTy Dc builtins op Q C2 [] [] (pureTel name) (pureBody name) :=
  .param (.done (.B_Last (.E_ReturnTail
    (ok_typed closedView Q _ C2 _ _ .tail Eff.empty hn (i := 0) (j := 1) (by decide) (by decide) rfl rfl
      (local_typed closedView Q _ C2 _ _ .other Eff.empty (i := 0) (a := t0) (by simp [Ctx.extend])
        (by simp [Ordinary, Ty.core]) (tvar_annotation (by decide)))))))

/-- flatMap の本体の型付け。 -/
theorem flatMap_body {name : String} (hn : Named name) (Q : NoFailCtx) :
    BodyTy Dc builtins op Q C3 [] [] (flatMapTel name) (flatMapBody name) := by
  refine .param (.param (.done ?_))
  refine .B_Last (.E_ReturnTail ?_)
  refine cases_typed Q [] C3 _ _ .tail row hn (j := 1) (a := t0) (x := t2)
    (by simp [Ctx.extend, data_shiftV]) (by simp) (by simp) (data_shiftV name 1 2) (by simp)
    (fun _ => tvar_annotation (by decide)) (fun _ => tvar_annotation (by decide))
    (fun _ => data_annotation hn (tvar_annotation (by decide)) (tvar_annotation (by decide)))
    (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
    (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
    (by simp [Ty.norm, Ty.normTys]) (fun Φ' => ?_) (fun Φ' => ?_)
  · exact call_typed closedView Q _ C3 Φ' _ .tail (k := 2) (m := 0) (a := t0) (b := .data name [t1, t2])
      (by simp [bindParams, Ctx.extend]) (by simp [bindParams, Ctx.extend])
      (by simp [Ordinary, Ty.core]) (fun _ => tvar_annotation (by decide))
      (fun _ => data_annotation hn (tvar_annotation (by decide)) (tvar_annotation (by decide)))
      (by simp) (data_shiftV name 1 2) (fun_norm _ _ rfl (by simp [Ty.norm, Ty.normTys]) (data_shiftV name 1 2 1 0))
      (done_bind_data name 1 2)
  · exact err_typed closedView Q _ C3 Φ' _ .tail row hn (i := 1) (j := 2) (by decide) (by decide) rfl rfl
      (local_typed closedView Q _ C3 Φ' _ .other row (i := 0) (a := t2) (by simp [bindParams, Ctx.extend])
        (by simp [Ordinary, Ty.core]) (tvar_annotation (by decide)))

/-- apply の本体の型付け。外側の照合の Ok の腕で、値の側をもう一度照合する。 -/
theorem apply_body {name : String} (hn : Named name) (Q : NoFailCtx) :
    BodyTy Dc builtins op Q C3 [] [] (applyTel name) (applyBody name) := by
  refine .param (.param (.done ?_))
  refine .B_Last (.E_ReturnTail ?_)
  have hf : ∀ Γ', Ty.Annotation D.core C3 Γ' (funTy t0 t1) := fun _ =>
    fun_annotation (tvar_annotation (by decide)) (tvar_annotation (by decide))
  refine cases_typed Q [] C3 _ _ .tail row hn (j := 1) (a := funTy t0 t1) (x := t2)
    (by simp [Ctx.extend, Ty.shiftV, shiftVTys]) (by simp) (by simp) (data_shiftV name 1 2) (by simp)
    hf (fun _ => tvar_annotation (by decide))
    (fun _ => data_annotation hn (tvar_annotation (by decide)) (tvar_annotation (by decide)))
    (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
    (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
    (by simp [Ty.norm, Ty.normTys]) (fun Φ' => ?_) (fun Φ' => ?_)
  · refine cases_typed Q _ C3 Φ' _ .tail row hn (j := 2) (a := t0) (x := t2)
      (by simp [bindParams, Ctx.extend, data_shiftV]) (by simp) (by simp) (data_shiftV name 1 2) (by simp)
      (fun _ => tvar_annotation (by decide)) (fun _ => tvar_annotation (by decide))
      (fun _ => data_annotation hn (tvar_annotation (by decide)) (tvar_annotation (by decide)))
      (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
      (by simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm])
      (by simp [Ty.norm, Ty.normTys]) (fun Φ'' => ?_) (fun Φ'' => ?_)
    · exact ok_typed closedView Q _ C3 Φ'' _ .tail row hn (i := 1) (j := 2) (by decide) (by decide) rfl rfl
        (call_typed closedView Q _ C3 Φ'' _ .other (k := 2) (m := 0) (a := t0) (b := t1)
          (by simp [bindParams, Ctx.extend]) (by simp [bindParams, Ctx.extend])
          (by simp [Ordinary, Ty.core]) (fun _ => tvar_annotation (by decide)) (fun _ => tvar_annotation (by decide))
          (by simp) (by simp) (fun_norm _ _ rfl rfl rfl) (done_bind_tvar 1))
    · exact err_typed closedView Q _ C3 Φ'' _ .tail row hn (i := 1) (j := 2) (by decide) (by decide) rfl rfl
        (local_typed closedView Q _ C3 Φ'' _ .other row (i := 0) (a := t2) (by simp [bindParams, Ctx.extend])
          (by simp [Ordinary, Ty.core]) (tvar_annotation (by decide)))
  · exact err_typed closedView Q _ C3 Φ' _ .tail row hn (i := 1) (j := 2) (by decide) (by decide) rfl rfl
      (local_typed closedView Q _ C3 Φ' _ .other row (i := 0) (a := t2) (by simp [bindParams, Ctx.extend])
        (by simp [Ordinary, Ty.core]) (tvar_annotation (by decide)))

/-! ## 汎用の関数 -/

private abbrev C4 : TypeCtx := [vt, vt, vt, ft]

theorem subst_row : substAtoms [row] (fun a => decide (a = .rho 0)) = fun a => decide (a = .rho 0) := by
  funext x
  cases x with
  | name l r => simp [substAtoms, row, Eff.test, Eff.atoms]
  | rho i => cases i <;> simp [substAtoms, row, Eff.test, Eff.atoms]

/-- 型構成子の変数で具体化した map の依存列。 -/
def genericTel : Tel :=
  .param "x" (.tapp 3 [t0, t2]) (.param "f" (funTy t0 t1) (.done (.tapp 3 [t1, t2]) row))

theorem generic_instantiated : instantiatedTel mapSig.tel ([t0, t1, t2] ++ [.tvar 3]) [row] = genericTel := by
  simp [instantiatedTel, MethSig.tel, mapSig, signatureTel, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, typeEnvAt,
    Tel.norm, Ty.norm, Ty.normTys, Eff.norm, rawBindTys, instAtoms_nil, rowFails, rawApply, 
    row, SubstEnv.up]
  simp only [row_eq, row_shiftV, subst_row]
  simp [row, Eff.fails]
  rw [row_eq, foldFn_value _ _ rfl]; rfl

theorem tapp_annotation {Γ : Ctx} (i j : Nat) (hi : i < 3) (hj : j < 3) :
    Ty.Annotation D.core C4 Γ (.tapp 3 [.tvar i, .tvar j]) :=
  ⟨by simp [Ty.WF, Ty.WFList]; omega, ⟨trivial, trivial, trivial⟩,
    ⟨rfl, trivial, trivial, trivial⟩⟩

@[simp] private theorem tapp_shiftV (i j n c : Nat) :
    (Ty.tapp 3 [.tvar i, .tvar j]).shiftV n c = .tapp 3 [.tvar i, .tvar j] := by
  simp [Ty.shiftV, shiftVTys]

@[simp] private theorem fnTy_shiftV (i j n c : Nat) : (fnTy (.tvar i) (.tvar j)).shiftV n c = fnTy (.tvar i) (.tvar j) := by
  simp [fnTy, Ty.shiftV, Tel.shiftV]

@[simp] private theorem dict_shiftV (n c : Nat) : (Ty.dict "Monad2" (.tvar 3)).shiftV n c = .dict "Monad2" (.tvar 3) := by
  simp [Ty.shiftV]

/-- 汎用の関数の本体の文脈（後ろから辞書・x・f）。 -/
abbrev genericCtx : Ctx :=
  ((Ctx.extend [] (.dict "Monad2" (.tvar 3))).extend (.tapp 3 [t0, t2])).extend (fnTy t0 t1)

/-- 受け取った Monad2 の辞書から上位の辞書を二度取り出すと、Functor2 の辞書になる。 -/
theorem functor_dict :
    DictEv.HasType D builtins C4 genericCtx (.super (.super (.local 2) "Applicative2") "Functor2")
      (.dict "Functor2" (.tvar 3)) :=
  .super (cd := applicative2)
    (.super (cd := monad2) (.local (cl := "Monad2") (τ := .tvar 3) (by simp [Ctx.extend])) rfl
      (by simp [monad2]) trivial) rfl (by simp [applicative2]) trivial

theorem generic_annotation (Γ : Ctx) : Ty.Annotation D.core C4 Γ (.dependentFn genericTel) :=
  ⟨by simp [genericTel, Ty.WF, Tel.WF, Ty.WFList, NamesWF, Eff.WF, row, Eff.Canonical, Eff.norm],
    by simp [genericTel, Ty.Sorted, Tel.Sorted, sortedTys, sortedEff, row],
    by simp [genericTel, Ty.Declared, Tel.Declared, declaredTys, declaredEff, row, TypeCtx.kinds, vt, ft,
      TypeCtx.valueParam]⟩

private theorem map_head (Q : NoFailCtx) :
    CallHeadTy D builtins Q C4 genericCtx
      (.methName (.super (.super (.local 2) "Applicative2") "Functor2") "map" [t0, t1, t2] [row] [] ["x", "f"]
        mapSig.params) genericTel [] := by
  have h := CallHeadTy.meth (D := D) (B := builtins) (Q := Q) (C := C4) (Γ := genericCtx) (cd := functor2) (m := "map")
    (ms := mapSig) (ss := [t0, t1, t2]) (es := [row]) (us := []) (names := ["x", "f"]) (ps := mapSig.params)
    functor_dict rfl rfl (by simp [mapSig, NamesWF])
    ⟨rfl, by
      intro i t p ht hp
      simp only [builtins]
      rcases i with _ | _ | _ | i <;> simp [mapSig, TypeCtx.constraints, vt, TypeCtx.valueParam] at hp <;>
        exact hp.symm⟩
    (by
      constructor
      · simp [MethSig.tel, mapSig, signatureTel, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.norm, row, 
          TypeCtx.kinds]
      · intro t ht
        simp at ht
        rcases ht with rfl | rfl | rfl | rfl <;> exact tvar_annotation (by decide)
      · refine ⟨rfl, ?_⟩
        intro i a k ha hk
        rcases i with _ | _ | _ | _ | i <;>
          simp [mapSig, functor2, TypeCtx.kinds, vt, TypeCtx.valueParam] at ha hk <;> subst ha <;> subst hk <;>
          simp [Ty.HasKind, Ordinary, Ty.core, TypeCtx.kinds, vt, ft, TypeCtx.valueParam]
      · intro e he
        simp at he; subst he
        exact ⟨by simp [Ty.WF, NamesWF, Ty.WFList, Eff.WF, row, Eff.Canonical, Eff.norm],
          by simp [Ty.Sorted, sortedTys, sortedEff, row], by simp [Ty.Declared, declaredTys, declaredEff, row]⟩
      · intro e he
        simp at he; subst he
        simp [kindsEff, row, kindsList]
      · rw [generic_instantiated]
        exact generic_annotation _)
    (by
      refine ⟨rfl, ?_, ?_, ?_, ?_⟩
      · simp [row, Eff.WF, Ty.WFList]
      · simp [mapSig, row, Eff.RowsIn, Ty.RowsInList]
      · intro i hi; simp [Qsig, QTys, QTy, QEff, QTel, mapSig, row, Benitoite.Release.Qempty] at hi
      · intro i hi; simp [Qsig, QTys, QTy, QEff, QTel, mapSig, row, Benitoite.Release.Qempty] at hi)
  rw [generic_instantiated] at h
  exact h

theorem fnTy_annotation {C : TypeCtx} {Γ : Ctx} {i j : Nat} (hi : i < C.length) (hj : j < C.length) :
    Ty.Annotation D.core C Γ (fnTy (.tvar i) (.tvar j)) :=
  ⟨⟨hi, hj, by simp [Eff.WF, row, Ty.WFList], by simp [Eff.Canonical, Eff.norm, row]⟩,
    ⟨trivial, trivial, by simp [sortedEff, row, sortedTys]⟩, ⟨trivial, trivial, by simp [declaredEff, row, declaredTys]⟩⟩

theorem generic_def_tel : genericMap.toFunDecl.tel =
    .param "%dict1" (.dict "Monad2" (.tvar 3))
      (.param "x" (.tapp 3 [t0, t2]) (.param "f" (fnTy t0 t1) (.done (.tapp 3 [t1, t2]) row))) := by
  simp [genericMap, FunDecl.tel, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, signatureTel, internalNames,
    mapSig]
  decide

/-- 汎用の関数の本体の型付け。上位の辞書を二度取り出した Functor2 の辞書で map を直接呼ぶ。 -/
theorem generic_body (Q : NoFailCtx) :
    BodyTy D builtins op Q C4 [] [] genericMap.toFunDecl.tel genericMap.body := by
  rw [generic_def_tel]
  refine .param (.param (.param (.done ?_)))
  refine .B_Last (.E_ReturnTail ?_)
  refine HasTypeQ.E_CallDirect (t := genericTel) (ds := []) (as := [.tapp 3 [t0, t2], fnTy t0 t1])
    (r := .tapp 3 [t1, t2]) (e := row) (map_head Q) ?_ ?_ ?_ ?_ ?_ (tapp_annotation 1 2 (by decide) (by decide))
  · simp [CallOk, genericTel, Tel.names, telBinders]
    exact List.Perm.refl _
  · exact .cons (local_typed closedView Q _ C4 _ _ .other row (i := 1) (by simp [Ctx.extend])
        (by simp [Ordinary, Ty.core]) (tapp_annotation 0 2 (by decide) (by decide)))
      (.cons (local_typed closedView Q _ C4 _ _ .other row (i := 0) (by simp [Ctx.extend])
        (by simp [Ordinary, Ty.core]) (fnTy_annotation (by decide) (by decide))) .nil)
  · simp [Tel.shiftV, genericTel, bindParams, liftMany, boundVars, recordFields, fieldAt, List.range, List.range.loop]
    refine .param (tapp_annotation 0 2 (by decide) (by decide)) (.var rfl (by simp [Ordinary, Ty.core])) .refl ?_
    have h1 : Tel.bind (Tel.argumentsEnv (.var 1)) (.param "f" (funTy t0 t1) (.done (.tapp 3 [t1, t2]) row)) =
        .param "f" (funTy t0 t1) (.done (.tapp 3 [t1, t2]) row) := by
      simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv, rowFails, Tel.norm, Ty.norm,
        Ty.normTys, Eff.norm, rawBindTys, row, substAtoms_nil, instAtoms_nil, rawApply]
    rw [h1]
    refine .param (fun_annotation (tvar_annotation (by decide)) (tvar_annotation (by decide)))
      (.var rfl (by simp [Ordinary, Ty.core])) (.convert (fun_norm _ _ rfl rfl rfl).symm) ?_
    have h2 : Tel.bind (Tel.argumentsEnv (.var 0)) (.done (.tapp 3 [t1, t2]) row) = .done (.tapp 3 [t1, t2]) row := by
      simp [Tel.bind, Tel.rawBind, Tel.argumentsEnv, Ty.rawBind, Eff.rawBind, valEnv, rowFails, Tel.norm, Ty.norm,
        Ty.normTys, Eff.norm, rawBindTys, row, substAtoms_nil, instAtoms_nil, rawApply]
    rw [h2]
    exact .done (by
      have h := tapp_annotation (Γ := (some (fnTy t0 t1) :: some (.tapp 3 [t0, t2]) :: List.map (Option.map (Ty.shiftV 2 0)) genericCtx)) 1 2 (by decide) (by decide)
      exact ⟨⟨h.wf, by simp [Eff.WF, row, Ty.WFList], by simp [Eff.Canonical, Eff.norm, row]⟩,
        ⟨h.sorted, by simp [sortedEff, row, sortedTys]⟩, ⟨h.declared, by simp [declaredEff, row, declaredTys]⟩⟩)
  · simp; exact .refl
  · simp only [row_shiftV]; exact Eff.Covers.refl _ _ _

/-! ## 実装の型付け -/

private theorem impl_lookup {name : String} (hn : Named name) :
    program.impls (functorName name) = some (functorImpl name) ∧
    program.impls (applicativeName name) = some (applicativeImpl name) ∧
    program.impls (monadName name) = some (monadImpl name) := by
  rcases hn with rfl | rfl <;> exact ⟨rfl, rfl, rfl⟩

private theorem ctor_kind {name : String} (hn : Named name) :
    Ty.HasKind D.core (TypeCtx.kinds (TypeCtx.values [])) (.ctor (.data name)) (.constructor 2) := arity hn

/-- 上位の辞書 `.impl i [] []` の型付け。 -/
private theorem super_dict {name : String} (hn : Named name) {i : ImplName} {id : ImplDecl} (hi : program.impls i = some id)
    (ht : id.tparams = []) (hd : id.dictParams = []) (htarget : id.target = .ctor (.data name)) :
    DictEv.HasType D builtins (TypeCtx.values []) (bindParams [] []) (.impl i [] []) (.dict id.cls (.ctor (.data name))) := by
  have h := DictEv.HasType.impl (D := D) (B := builtins) (C := TypeCtx.values []) (Γ := bindParams [] [])
    (i := i) (ts := []) (ds := []) (is := id.toImplSig) (by simp [D, Program.declarations, Program.declarationsFor, hi])
    ⟨by simp [ht], by intro k t p h; cases h⟩ (by simp [TypeAnnotations]) ⟨by simp [ht], by intro k a kk h; cases h⟩
    (by simp [ImplSig.dictTys, hd]) (by simp [htarget, Ty.WF]) (by simpa [ImplSig.dictTys, hd] using DictEv.HasTypes.nil)
    (by simp [htarget, Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm]; exact ⟨trivial, trivial, ⟨2, data_arity hn⟩⟩)
  simpa [htarget, Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, Ty.norm] using h

theorem functor_typed {name : String} (hn : Named name) :
    ImplDecl.WellTyped D builtins op (functorImpl name) (fun _ => closedView) := by
  refine ⟨functor2, rfl, ?_, ?_, ctor_kind hn, by simp [TypeAnnotations, ImplSig.dictTys, functorImpl], ?_, ?_⟩
  · intro m; by_cases h : m = "map" <;> simp [functorImpl, functor2, h]
  · intro s; simp [functorImpl, functor2]
  · intro m ms hm
    have : m = "map" ∧ ms = mapSig := by simp [functor2] at hm; exact ⟨hm.1, hm.2.symm⟩
    obtain ⟨rfl, rfl⟩ := this
    refine ⟨mapBody name, by simp [functorImpl], by simp [mapSig, NamesWF], ?_⟩
    simp only [functorImpl, map_tel]
    exact map_body hn _
  · intro s hs; simp [functor2] at hs

theorem applicative_typed {name : String} (hn : Named name) :
    ImplDecl.WellTyped D builtins op (applicativeImpl name) (fun _ => closedView) := by
  refine ⟨applicative2, rfl, ?_, ?_, ctor_kind hn, by simp [TypeAnnotations, ImplSig.dictTys, applicativeImpl], ?_, ?_⟩
  · intro m
    by_cases h : m = "pure"
    · simp [applicativeImpl, applicative2, h]
    · by_cases h' : m = "apply" <;> simp [applicativeImpl, applicative2, h, h']
  · intro s; by_cases h : s = "Functor2" <;> simp [applicativeImpl, applicative2, h]
  · intro m ms hm
    by_cases h : m = "pure"
    · subst h
      have : ms = pureSig := by simp [applicative2] at hm; exact hm.symm
      subst this
      refine ⟨pureBody name, by simp [applicativeImpl], by simp [pureSig, NamesWF], ?_⟩
      simp only [applicativeImpl, pure_tel]
      exact pure_body hn _
    · have : m = "apply" ∧ ms = applySig := by simp [applicative2, h] at hm; exact ⟨hm.1, hm.2.symm⟩
      obtain ⟨rfl, rfl⟩ := this
      refine ⟨applyBody name, by simp [applicativeImpl], by simp [applySig, NamesWF], ?_⟩
      simp only [applicativeImpl, apply_tel]
      exact apply_body hn _
  · intro s hs
    simp [applicative2] at hs; subst hs
    exact ⟨_, by simp [applicativeImpl], super_dict hn (impl_lookup hn).1 rfl rfl rfl⟩

theorem monad_typed {name : String} (hn : Named name) :
    ImplDecl.WellTyped D builtins op (monadImpl name) (fun _ => closedView) := by
  refine ⟨monad2, rfl, ?_, ?_, ctor_kind hn, by simp [TypeAnnotations, ImplSig.dictTys, monadImpl], ?_, ?_⟩
  · intro m; by_cases h : m = "flatMap" <;> simp [monadImpl, monad2, h]
  · intro s; by_cases h : s = "Applicative2" <;> simp [monadImpl, monad2, h]
  · intro m ms hm
    have : m = "flatMap" ∧ ms = flatMapSig := by simp [monad2] at hm; exact ⟨hm.1, hm.2.symm⟩
    obtain ⟨rfl, rfl⟩ := this
    refine ⟨flatMapBody name, by simp [monadImpl], by simp [flatMapSig, mapSig, NamesWF], ?_⟩
    simp only [monadImpl, flatMap_tel]
    exact flatMap_body hn _
  · intro s hs
    simp [monad2] at hs; subst hs
    exact ⟨_, by simp [monadImpl], super_dict hn (impl_lookup hn).2.1 rfl rfl rfl⟩

/-! ## プログラムの型付けと整形式 -/

theorem impl_cases {i : ImplName} {id : ImplDecl} (h : program.impls i = some id) :
    ∃ name, Named name ∧ (id = functorImpl name ∨ id = applicativeImpl name ∨ id = monadImpl name) := by
  have hm := CheckTables.lookup_mem (show CheckTables.lookup (implsOf "Result" ++ implsOf "UserResult") i = some id from h)
  simp only [implsOf, List.cons_append, List.nil_append, List.mem_cons, List.not_mem_nil, or_false,
    Prod.mk.injEq] at hm
  rcases hm with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩
  · exact ⟨_, .inl rfl, .inl rfl⟩
  · exact ⟨_, .inl rfl, .inr (.inl rfl)⟩
  · exact ⟨_, .inl rfl, .inr (.inr rfl)⟩
  · exact ⟨_, .inr rfl, .inl rfl⟩
  · exact ⟨_, .inr rfl, .inr (.inl rfl)⟩
  · exact ⟨_, .inr rfl, .inr (.inr rfl)⟩

private theorem generic_lookup {f : FunName} {d : Def} (h : program.defs f = some d) : f = "genericMap" ∧ d = genericMap := by
  change (if f = "genericMap" then some genericMap else none) = some d at h
  split at h
  · exact ⟨‹_›, (Option.some.inj h).symm⟩
  · cases h

theorem generic_kind : Ty.HasKind D.core (TypeCtx.kinds genericMap.tparams) (.dependentFn genericMap.toFunDecl.tel) .value := by
  rw [generic_def_tel]
  refine ⟨⟨monad2, rfl, rfl⟩, ?_⟩
  simp [Ty.HasKind, kindsTel, kindsList, kindsEff, row, TypeCtx.kinds, genericMap, vt, ft, TypeCtx.valueParam
    ]

theorem generic_annotation' : Ty.Annotation D.core genericMap.tparams [] (.dependentFn genericMap.toFunDecl.tel) := by
  rw [generic_def_tel]
  exact ⟨by simp [genericMap, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, row, Eff.Canonical, Eff.norm],
    by simp [Ty.Sorted, Tel.Sorted, sortedTys, sortedEff, row],
    by simp [Ty.Declared, Tel.Declared, declaredTys, declaredEff, row, TypeCtx.kinds, genericMap, vt, ft,
      TypeCtx.valueParam]⟩

private theorem generic_names : NamesWF genericMap.coreNames genericMap.coreParams := by
  simp [genericMap, FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF, mapSig]; decide

theorem generic_typed : Def.WellTyped D builtins op genericMap :=
  (Def.wellTyped_no_ranges rfl).mpr ⟨generic_names, generic_kind, generic_annotation', generic_body _⟩

theorem program_wellTyped : program.WellTyped builtins op where
  variance := by
    unfold Refinement.Program.VarianceValid
    refine ⟨fun d info h => by simp [Program.declarations, Program.declarationsFor, program,
      Declarations.core] at h, ?_⟩
    intro c cd hc
    obtain ⟨m, -, ⟨-, rfl⟩ | ⟨-, rfl⟩⟩ := cons_cases hc
    all_goals refine ⟨fun info h => by simp [Program.declarations, Program.declarationsFor, program,
      Declarations.core] at h, ?_⟩
    all_goals intro a ha; simp at ha; subst ha
    all_goals exact ⟨tvar_annotation (by simp), rfl, ⟨.invariant, by simp [Refinement.Program.varianceFor, 
      Program.declarations, Program.declarationsFor, program, Declarations.core], by decide⟩⟩
  defs := by
    intro f d hd
    obtain ⟨rfl, rfl⟩ := generic_lookup hd
    exact generic_typed
  impls := by
    intro i id hi
    obtain ⟨name, hn, rfl | rfl | rfl⟩ := impl_cases hi
    · exact functor_typed hn
    · exact applicative_typed hn
    · exact monad_typed hn
  effects := by
    unfold Refinement.Program.EffectsOk
    refine ⟨fun _ _ _ h => ?_, fun _ _ h => ?_, fun _ _ h => ?_⟩ <;>
      simp [Program.declarations, Program.declarationsFor, program, Declarations.core] at h

private theorem class_cases {c : ClassName} {cd : ClassDecl} (h : D.core.classes c = some cd) :
    cd = functor2 ∨ cd = applicative2 ∨ cd = monad2 := by
  change classTable c = some cd at h
  simp only [classTable] at h
  split at h
  · exact .inl (Option.some.inj h).symm
  · split at h
    · exact .inr (.inl (Option.some.inj h).symm)
    · split at h
      · exact .inr (.inr (Option.some.inj h).symm)
      · cases h

private theorem sig_scoped {ms : MethSig} (h : ms = mapSig ∨ ms = pureSig ∨ ms = applySig ∨ ms = flatMapSig) :
    ms.Scoped D.core (.constructor 2) := by
  rcases h with rfl | rfl | rfl | rfl
  all_goals refine ⟨by simp [mapSig, pureSig, applySig, flatMapSig, NamesWF], ?_, ?_, ?_, ?_⟩
  all_goals simp [MethSig.tel, mapSig, pureSig, applySig, flatMapSig, signatureTel, Ty.SourceScoped, Ty.WF, Tel.WF,
    Ty.WFList, Eff.WF, Eff.Canonical, Eff.norm, row, Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Ty.RowsInList,
    Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, Ty.HasKind, kindsTel, kindsList, kindsEff,
    TypeCtx.kinds, vt, TypeCtx.valueParam, 
    Eff.empty]
  all_goals exact ⟨by simp [Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.norm, row],
    by simp [Ty.Sorted, Tel.Sorted, sortedTys, sortedEff, row],
    by simp [Ty.Declared, Tel.Declared, declaredTys, declaredEff, TypeCtx.kinds, row]⟩


private theorem body_scoped_simp {name : String} :
    Block.Scoped 3 1 2 0 (mapBody name) ∧ Block.Scoped 2 0 1 0 (pureBody name) ∧
    Block.Scoped 3 1 2 0 (applyBody name) ∧ Block.Scoped 3 1 2 0 (flatMapBody name) := by
  simp [mapBody, pureBody, applyBody, flatMapBody, casesResult, ok, err, call1, one, Block.Scoped, Expr.Scoped,
    Exprs.Scoped, Arms.Scoped, Alternative.toCoreList, Alternative.toCore, Pattern.toCore, Pattern.toCoreList,
    Arm.bindersOf, Pat.binders, Pat.bindersList, Ty.SourceScoped, Ty.WF, Ty.RowsIn, 
    Ty.RangesScoped, scopedTypes]

private theorem impl_head_scoped {name : String} (hn : Named name) {id : ImplDecl}
    (hd : id.dictParams = []) (htarget : id.target = .ctor (.data name)) :
    (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    id.target.SourceScoped 0 id.tparams.length 0 0 ∧
    Ty.Annotation D.core (TypeCtx.values id.tparams) [] id.target ∧
    TypeAnnotations D.core (TypeCtx.values id.tparams) [] id.dictTys ∧
    (∀ a ∈ id.dictTys, a.HasKind D.core (List.replicate id.tparams.length .value) .value) := by
  refine ⟨by simp [hd], by simp [htarget, Ty.SourceScoped, Ty.WF, Ty.RowsIn, Ty.RangesScoped],
    by rw [htarget]; exact ⟨trivial, trivial, ⟨2, data_arity hn⟩⟩, by simp [TypeAnnotations, ImplSig.dictTys, hd],
    by simp [ImplSig.dictTys, hd]⟩

theorem functor_scoped {name : String} (hn : Named name) : ImplDecl.Scoped D (functorImpl name) := by
  obtain ⟨h1, h2, h3, h4, h5⟩ := impl_head_scoped hn (id := functorImpl name) rfl rfl
  refine ⟨h1, h2, h3, h4, h5, ?_, ?_⟩
  · intro s u hu; simp [functorImpl] at hu
  · intro cd m ms body hc hm hb
    change classTable "Functor2" = some cd at hc
    simp [classTable] at hc; subst hc
    simp only [functor2] at hm
    split at hm
    · cases hm; subst_vars
      simp [functorImpl] at hb; subst hb
      exact body_scoped_simp.1
    · cases hm

theorem applicative_scoped {name : String} (hn : Named name) : ImplDecl.Scoped D (applicativeImpl name) := by
  obtain ⟨h1, h2, h3, h4, h5⟩ := impl_head_scoped hn (id := applicativeImpl name) rfl rfl
  refine ⟨h1, h2, h3, h4, h5, ?_, ?_⟩
  · intro s u hu
    simp [applicativeImpl] at hu
    obtain ⟨-, rfl⟩ := hu
    simp [DictEv.Scoped, DictEv.ScopedList, scopedTypes]
  · intro cd m ms body hc hm hb
    change classTable "Applicative2" = some cd at hc
    simp [classTable] at hc; subst hc
    simp only [applicative2] at hm
    split at hm
    · cases hm; subst_vars
      simp [applicativeImpl] at hb; subst hb
      exact body_scoped_simp.2.1
    · split at hm
      · cases hm; subst_vars
        simp [applicativeImpl] at hb; subst hb
        exact body_scoped_simp.2.2.1
      · cases hm

theorem monad_scoped {name : String} (hn : Named name) : ImplDecl.Scoped D (monadImpl name) := by
  obtain ⟨h1, h2, h3, h4, h5⟩ := impl_head_scoped hn (id := monadImpl name) rfl rfl
  refine ⟨h1, h2, h3, h4, h5, ?_, ?_⟩
  · intro s u hu
    simp [monadImpl] at hu
    obtain ⟨-, rfl⟩ := hu
    simp [DictEv.Scoped, DictEv.ScopedList, scopedTypes]
  · intro cd m ms body hc hm hb
    change classTable "Monad2" = some cd at hc
    simp [classTable] at hc; subst hc
    simp only [monad2] at hm
    split at hm
    · cases hm; subst_vars
      simp [monadImpl] at hb; subst hb
      exact body_scoped_simp.2.2.2
    · cases hm

theorem program_wellFormed : program.WellFormed where
  types := by
    constructor
    · intro f d h; cases h
    · intro c cd hc
      obtain ⟨m, hm, ⟨-, rfl⟩ | ⟨-, rfl⟩⟩ := cons_cases hc
      all_goals refine ⟨data_arity hm, ?_⟩
      all_goals intro a ha; simp at ha; subst ha
      all_goals exact ⟨by simp [Ty.SourceScoped, Ty.WF, Ty.RowsIn, Ty.RangesScoped], tvar_annotation (by simp), rfl⟩
    · intro o od h; cases h
    · intro cl cd h m ms hm
      rcases class_cases h with rfl | rfl | rfl
      · simp [functor2] at hm; exact sig_scoped (.inl hm.2.symm)
      · simp only [applicative2] at hm
        split at hm
        · exact sig_scoped (.inr (.inl (Option.some.inj hm).symm))
        · split at hm
          · exact sig_scoped (.inr (.inr (.inl (Option.some.inj hm).symm)))
          · cases hm
      · simp [monad2] at hm; exact sig_scoped (.inr (.inr (.inr hm.2.symm)))
    · intro i id h; cases h
    · intro d info h; cases h
    · exact ⟨by simp [Program.declarationsFor, Program.declarations, Declarations.core, program],
        fun _ _ h => by simp [Program.declarationsFor, Program.declarations, Declarations.core, program] at h⟩
  defs := by
    intro f d hd
    obtain ⟨rfl, rfl⟩ := generic_lookup hd
    refine ⟨generic_names, ⟨?_, ?_, generic_kind, by
      rw [show genericMap.rangeParams = [] from rfl, Ty.annotationR_nil]; exact generic_annotation'⟩, ?_⟩
    · rw [generic_def_tel]
      simp [genericMap, Ty.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.norm, row, 
        Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Ty.RowsInList, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped,
        rangesScopedTypes]
    · rw [generic_def_tel]
      simp [genericMap, Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Ty.RowsInList, row]
    · simp [genericMap, mapSig, Block.Scoped, Expr.Scoped, Exprs.Scoped, DictEv.Scoped, scopedTypes, scopedRows,
        FunDecl.coreParams, FunDecl.dictTys, Ty.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, Eff.WF,
        Eff.Canonical, Eff.norm, row, NamesWF, Ty.RowsIn, Tel.RowsIn, Eff.RowsIn, Ty.RowsInList, Ty.RangesScoped,
        Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, DictEv.ScopedList, Eff.SourceScoped]
  impls := by
    intro i id hi
    obtain ⟨name, hn, rfl | rfl | rfl⟩ := impl_cases hi
    · exact functor_scoped hn
    · exact applicative_scoped hn
    · exact monad_scoped hn
  accessors := by intro f c k h; cases h
  testers := by intro f c h; cases h

/-! ## 性質1の適用 -/

/-- 型パラメータの制約の判定は型によらず、組込みの関数を持たないので、値の信頼条件を満たす。 -/
theorem value_assumptions : Builtins.ValueAssumptions (desugarProgram op program) builtins where
  sat_rename := fun _ _ _ _ _ _ _ _ _ h => h
  admits_rename := fun _ _ _ _ _ _ _ h => by cases h
  sat_values := fun _ _ _ _ _ _ _ _ _ _ _ h => h
  admits_values := fun _ _ _ _ _ _ _ _ _ _ h => by cases h

/-- 三つの二引数のクラスと六つの実装と辞書を受け取る関数を含むプログラムに、性質1を適用する。 -/
theorem desugared_typed :
    (desugarProgram op program).WellFormed ∧ (desugarProgram op program).WellTyped builtins ∧
      (desugarProgram op program).EffectsOk builtins :=
  desugar_typed program_wellFormed program_wellTyped value_assumptions

end
end Benitoite.Release.Refinement.Surface.Monad2Examples
