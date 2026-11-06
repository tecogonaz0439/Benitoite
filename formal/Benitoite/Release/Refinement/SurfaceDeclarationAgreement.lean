import Benitoite.Release.Refinement.SurfaceLibrary

/-! # 有限の宣言表と保持した核の署名の一致

型と効果は、同じ有限の原子一覧による構造比較で照合する。本体の振る舞いを仮定せず、
宣言の全 lookup を覆う名前の一覧から宣言表の実現を構成する。
-/
namespace Benitoite.Release.Refinement.Surface.DeclarationAgreement

local instance : DecidableEq Benitoite.Release.TParam := by
  intro a b
  cases a; cases b
  simp only [Benitoite.Release.TParam.mk.injEq]
  infer_instance

local instance : DecidableEq TParamDecl := by
  intro a b
  cases a; cases b
  simp only [TParamDecl.mk.injEq]
  infer_instance

/-- 依存する引数・結果・効果を含む署名の構造。型と行の深さ、範囲の種類は別に照合する。 -/
def functionType (d : Refinement.Def) : Ty := .fn d.names d.params d.ret d.eff

def declarationType (fd : FunDecl) : Ty := .fn fd.coreNames fd.coreParams fd.ret fd.eff

/-- 核の本体に付いた署名と checker の関数宣言を照合する有限判定。 -/
def functionCheck (atoms : List Atom) (d : Refinement.Def) (fd : FunDecl) : Bool :=
  decide (d.tparams = fd.tparams) && (decide (d.neffs = fd.neffs) &&
    (decide (d.rkinds = fd.rangeParams) && CheckCompare.rawTyEq atoms (functionType d) (declarationType fd)))

/-- 実装の型パラメータ・辞書パラメータ・型クラス・対象型を照合する有限判定。 -/
def implementationCheck (atoms : List Atom) (id : Refinement.ImplDecl) (is : ImplSig) : Bool :=
  decide (id.tparams = is.tparams) && (decide (id.dictParams = is.dictParams) &&
    (decide (id.cls = is.cls) && CheckCompare.rawTyEq atoms id.target is.target))

/-- 宣言を持つ名前では、対応する核の本体が存在し、その署名が一致することを要求する。 -/
def functionsCheck (atoms : List Atom) (D : Declarations) (P : Refinement.Program)
    (names : List FunName) : Bool :=
  names.all fun f => match D.funs f with
    | none => true
    | some fd => match P.defs f with
      | none => false
      | some d => functionCheck atoms d fd

def implementationsCheck (atoms : List Atom) (D : Declarations) (P : Refinement.Program)
    (names : List ImplName) : Bool :=
  names.all fun i => match D.impls i with
    | none => true
    | some is => match P.impls i with
      | none => false
      | some id => implementationCheck atoms id is

/-- 有限の名前一覧で、補完した宣言も含めた関数と実装の署名をすべて照合する。 -/
def check (atoms : List Atom) (D : Declarations) (P : Refinement.Program)
    (functions : List FunName) (implementations : List ImplName) : Bool :=
  functionsCheck atoms D P functions && implementationsCheck atoms D P implementations

private theorem functionCheck_sound {atoms d fd}
    (hd : (functionType d).Support (· ∈ atoms))
    (hf : (declarationType fd).Support (· ∈ atoms))
    (h : functionCheck atoms d fd = true) :
    d.tparams = fd.tparams ∧ d.neffs = fd.neffs ∧ d.names = fd.coreNames ∧
      d.params = fd.coreParams ∧ d.ret = fd.ret ∧ d.eff = fd.eff ∧ d.rkinds = fd.rangeParams := by
  simp only [functionCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  have ht := (CheckCompare.rawTyEq_spec hd hf).mp h.2.2.2
  simp only [functionType, declarationType, Ty.fn.injEq] at ht
  exact ⟨h.1,h.2.1,ht.1,ht.2.1,ht.2.2.1,ht.2.2.2,h.2.2.1⟩

private theorem implementationCheck_sound {atoms id is}
    (hd : id.target.Support (· ∈ atoms)) (hf : is.target.Support (· ∈ atoms))
    (h : implementationCheck atoms id is = true) :
    id.tparams = is.tparams ∧ id.dictParams = is.dictParams ∧ id.cls = is.cls ∧ id.target = is.target := by
  simp only [implementationCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  exact ⟨h.1,h.2.1,h.2.2.1,(CheckCompare.rawTyEq_spec hd hf).mp h.2.2.2⟩

/-- 有限判定の成功から宣言表の実現を得る。型の宣言の一致と外部宣言の整形式は、
署名比較から独立に受ける。支持は比較する署名だけについて要求する。 -/
theorem realizes_of_check {atoms D P functions implementations}
    (ht : D.core.SameTypes P) (he : P.ExternalWF)
    (hf : ∀ f fd, D.funs f = some fd → f ∈ functions)
    (hi : ∀ i is, D.impls i = some is → i ∈ implementations)
    (hfd : ∀ f fd, D.funs f = some fd → (declarationType fd).Support (· ∈ atoms))
    (hpd : ∀ f fd d, D.funs f = some fd → P.defs f = some d → (functionType d).Support (· ∈ atoms))
    (hid : ∀ i is, D.impls i = some is → is.target.Support (· ∈ atoms))
    (hpi : ∀ i is id, D.impls i = some is → P.impls i = some id → id.target.Support (· ∈ atoms))
    (h : check atoms D P functions implementations = true) : D.Realizes P := by
  have checks := Bool.and_eq_true_iff.mp h
  have funs : ∀ f fd, D.funs f = some fd → ∃ d, P.defs f = some d ∧
      d.tparams = fd.tparams ∧ d.neffs = fd.neffs ∧ d.names = fd.coreNames ∧
      d.params = fd.coreParams ∧ d.ret = fd.ret ∧ d.eff = fd.eff ∧ d.rkinds = fd.rangeParams := by
    intro f fd hd
    have hc := List.all_eq_true.mp checks.1 f (hf f fd hd)
    rw [hd] at hc
    cases hp : P.defs f with
    | none => simp [hp] at hc
    | some d =>
      rw [hp] at hc
      exact ⟨d,rfl,functionCheck_sound (hpd f fd d hd hp) (hfd f fd hd) hc⟩
  refine ⟨ht,?_,?_,he,?_⟩
  · intro f fd hd
    obtain ⟨d,hp,h1,h2,h3,h4,h5,h6,_⟩ := funs f fd hd
    exact ⟨d,hp,h1,h2,h3,h4,h5,h6⟩
  · intro i is hd
    have hc := List.all_eq_true.mp checks.2 i (hi i is hd)
    rw [hd] at hc
    cases hp : P.impls i with
    | none => simp [hp] at hc
    | some id =>
      rw [hp] at hc
      exact ⟨id,rfl,implementationCheck_sound (hpi i is id hd hp) (hid i is hd) hc⟩
  · intro f fd hd d hp
    obtain ⟨d',hp',_,_,_,_,_,_,hr⟩ := funs f fd hd
    rw [hp] at hp'
    cases hp'
    exact hr

end Benitoite.Release.Refinement.Surface.DeclarationAgreement
