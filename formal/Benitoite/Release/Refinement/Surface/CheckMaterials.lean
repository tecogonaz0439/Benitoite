import Benitoite.Release.Refinement.Surface.CheckDeclarations
import Benitoite.Release.Refinement.Surface.CheckTablesBase
import Benitoite.Release.Refinement.Surface.CheckAcceptBase

/-! 有限の宣言材料から、プログラム・宣言表・名前の全一覧を同時に作る。 -/
namespace Benitoite.Release.Refinement.Surface.CheckTables

/-- 同じ名前が重なるときは先頭を使う。一覧の外は空欄である。 -/
def lookup : List (String × α) → String → Option α
  | [], _ => none
  | (key, value) :: rest, name => if key = name then some value else lookup rest name

theorem lookup_mem {xs : List (String × α)} {name value} (h : lookup xs name = some value) :
    (name, value) ∈ xs := by
  induction xs with
  | nil => cases h
  | cons pair rest ih =>
    rcases pair with ⟨key, item⟩
    simp only [lookup] at h
    split at h
    · next he => cases h; exact List.mem_cons.mpr (Or.inl (by simp [he]))
    · exact List.mem_cons.mpr (Or.inr (ih h))

theorem lookup_key {xs : List (String × α)} {name value} (h : lookup xs name = some value) :
    name ∈ xs.map Prod.fst := List.mem_map.mpr ⟨_, lookup_mem h, rfl⟩

theorem lookup_map (f : α → β) (xs : List (String × α)) (name : String) :
    lookup (xs.map (fun (n, a) => (n, f a))) name = (lookup xs name).map f := by
  induction xs with
  | nil => rfl
  | cons pair rest ih =>
    rcases pair with ⟨key, value⟩
    simp only [List.map_cons, lookup]
    split <;> simp only [Option.map_some, ih]

structure ClassMaterial where
  argumentKind : TyKind := .value
  supers : List ClassName := []
  methods : List (MethName × MethSig) := []

def ClassMaterial.decl (c : ClassMaterial) : ClassDecl := ⟨c.argumentKind, c.supers, lookup c.methods⟩

structure MethodMaterial where
  names : List String
  body : Block

structure ImplMaterial where
  signature : ImplSig
  supers : List (ClassName × DictEv) := []
  methods : List (MethName × MethodMaterial) := []

/-- 実名を保持した材料から、本体だけを表層の実装へ射影する。 -/
def ImplMaterial.decl (i : ImplMaterial) : ImplDecl :=
  {i.signature with supers := lookup i.supers, methods := lookup (i.methods.map (fun (n, m) => (n, m.body)))}

structure Materials where
  functionViews : FunName → CoverageView := fun _ => closedView
  methodViews : ImplName → MethName → CoverageView := fun _ _ => closedView
  defs : List (FunName × Def) := []
  cons : List (ConName × ConDecl) := []
  conFields : List (ConName × List String) := []
  ops : List (OpName × OpDecl) := []
  effects : List (EffName × List OpName) := []
  classes : List (ClassName × ClassMaterial) := []
  impls : List (ImplName × ImplMaterial) := []
  accessors : List (FunName × (ConName × Nat)) := []
  aliases : List (String × AliasDecl) := []
  records : List (ConName × RecordDecl) := []
  testers : List (FunName × ConName) := []
  externals : List (ExternalKey × ExternalDecl) := []
  dataInfo : List (DataName × DataVarianceDecl) := []
  trustedFuns : List (FunName × FunDecl) := []
  trustedImpls : List (ImplName × ImplSig) := []

/-- 構成子は、同じ材料の実際の所属の欄によって data ごとに列挙する。 -/
def Materials.constructors (m : Materials) (d : DataName) : List ConName :=
  (m.cons.filter (fun entry => entry.2.data == d)).map Prod.fst


/-- 生成関数・型の別名・外部宣言も含む、全ての表を同じ材料で作る。 -/
def Materials.program (m : Materials) : Program where
  functionViews := m.functionViews
  methodViews := m.methodViews
  defs := lookup m.defs
  cons := lookup m.cons
  conFields := lookup m.conFields
  dataConstructors := m.constructors
  ops := lookup m.ops
  effects := lookup m.effects
  classes := lookup (m.classes.map (fun (n, c) => (n, c.decl)))
  impls := lookup (m.impls.map (fun (n, i) => (n, i.decl)))
  accessors := lookup m.accessors
  aliases := lookup m.aliases
  records := lookup m.records
  testers := lookup m.testers
  externals := m.externals
  dataInfo := lookup m.dataInfo

/-- 関数と実装の空欄だけを、信頼するシグネチャで補完する。 -/
def extend (D : Declarations) (fs : List (FunName × FunDecl)) (is : List (ImplName × ImplSig)) : Declarations :=
  {D with funs := fun n => (D.funs n).or (lookup fs n), impls := fun n => (D.impls n).or (lookup is n)}

def Materials.declarations (m : Materials) : Declarations := extend m.program.declarations m.trustedFuns m.trustedImpls


def Materials.methodNames (m : Materials) (i : ImplName) (name : MethName) : List String :=
  match lookup m.impls i with
  | none => []
  | some im => ((lookup im.methods name).map MethodMaterial.names).getD []

/-- 予算・論理の証明書・組み込みの許容判定は基の入力から受け取り、表と全一覧と実名を有限材料で固定する。 -/
def Materials.input (m : Materials) (base : Check.Input) : Check.Input :=
  {base with
    D := m.declarations
    formation := {base.formation with ctors := m.constructors}
    defs := m.defs.map Prod.fst
    impls := m.impls.map Prod.fst
    effects := m.effects.map Prod.fst
    ops := m.ops.map Prod.fst
    methods := ((m.classes.flatMap (fun (_, c) => c.methods.map Prod.fst)) ++
      (m.impls.flatMap (fun (_, i) => i.methods.map Prod.fst))).eraseDups
    supers := ((m.classes.flatMap (fun (_, c) => c.supers)) ++
      (m.impls.flatMap (fun (_, i) => i.supers.map Prod.fst))).eraseDups
    dataNames := m.dataInfo.map Prod.fst
    ctorNames := m.cons.map Prod.fst
    methodParamNames := m.methodNames}

theorem Materials.constructors_complete (m : Materials) :
    CheckFormation.CtorsComplete m.declarations.core m.constructors := by
  intro c cd hc
  change lookup m.cons c = some cd at hc
  exact List.mem_map.mpr ⟨(c, cd), List.mem_filter.mpr ⟨lookup_mem hc, by simp⟩, rfl⟩

/-- 宣言の本体の表に実在する全ての名前が、入力の有限一覧に含まれる。 -/
theorem Materials.names_complete (m : Materials) (base : Check.Input) : NamesComplete (m.input base) m.program := by
  constructor
  · intro n d h; exact lookup_key h
  · intro n id h
    change lookup (m.impls.map (fun (n, i) => (n, i.decl))) n = some id at h
    rw [lookup_map] at h
    obtain ⟨im, hi, _⟩ := Option.map_eq_some_iff.mp h
    exact lookup_key hi
  · intro n os h; exact lookup_key h
  · intro n od h; exact lookup_key h
  · intro n info h; exact lookup_key h
  · intro n cd h; exact lookup_key h

/-- 補完は利用者の宣言を保存し、型の判断が読む表とその他の欄を変えない。 -/
theorem Materials.extends (m : Materials) (base : Check.Input) : Extends (m.input base).D m.program.declarations := by
  refine ⟨?_, ?_, rfl, rfl, rfl, rfl, rfl⟩
  · intro n d h
    change (m.program.declarations.funs n).or (lookup m.trustedFuns n) = some d
    rw [h]; rfl
  · intro n id h
    change (m.program.declarations.impls n).or (lookup m.trustedImpls n) = some id
    rw [h]; rfl

private theorem extend_empty (D : Declarations) : extend D [] [] = D := by
  have hf : (fun n => (D.funs n).or (lookup [] n)) = D.funs := by
    funext n; cases D.funs n <;> rfl
  have hi : (fun n => (D.impls n).or (lookup [] n)) = D.impls := by
    funext n; cases D.impls n <;> rfl
  simp only [extend, hf, hi]

theorem Materials.declarations_empty {m : Materials} (hf : m.trustedFuns = []) (hi : m.trustedImpls = []) :
    m.declarations = m.program.declarations := by
  simp only [Materials.declarations, hf, hi, extend_empty]

/-- 同じメソッド材料の実名と本体を、射影前と射影後で対応させる。 -/
theorem Materials.method_input {m : Materials} {base i im name method}
    (hi : lookup m.impls i = some im) (hm : lookup im.methods name = some method) :
    (m.input base).methodParamNames i name = method.names ∧ im.decl.methods name = some method.body := by
  constructor
  · simp only [Materials.input, Materials.methodNames, hi, hm, Option.map_some, Option.getD_some]
  · change lookup (im.methods.map (fun (n, m) => (n, m.body))) name = some method.body
    rw [lookup_map, hm]
    rfl

/-- 実際の実装とクラスの lookup を全て量化して、メソッドと上位の辞書の全一覧を導く。 -/
theorem Materials.impl_names_complete {m : Materials} {base i id} (hi : m.program.impls i = some id) :
    CheckDeclarations.ImplNamesComplete (m.input base) id := by
  change lookup (m.impls.map (fun (n, im) => (n, im.decl))) i = some id at hi
  rw [lookup_map] at hi
  obtain ⟨im, him, rfl⟩ := Option.map_eq_some_iff.mp hi
  have hmem := lookup_mem him
  constructor
  · intro cd hc name hn
    change lookup (m.classes.map (fun (n, c) => (n, c.decl))) im.signature.cls = some cd at hc
    rw [lookup_map] at hc
    obtain ⟨cm, hcm, rfl⟩ := Option.map_eq_some_iff.mp hc
    change name ∈ ((m.classes.flatMap (fun (_, c) => c.methods.map Prod.fst)) ++
      (m.impls.flatMap (fun (_, im) => im.methods.map Prod.fst))).eraseDups
    apply List.mem_eraseDups.mpr
    rcases hn with hn | hn
    · cases hm : im.decl.methods name with
      | none => simp [hm] at hn
      | some body =>
        change lookup (im.methods.map (fun (n, m) => (n, m.body))) name = some body at hm
        rw [lookup_map] at hm
        obtain ⟨method, hm, _⟩ := Option.map_eq_some_iff.mp hm
        exact List.mem_append.mpr (Or.inr (List.mem_flatMap.mpr ⟨_, hmem, lookup_key hm⟩))
    · cases hm : cm.decl.methods name with
      | none => simp [hm] at hn
      | some ms =>
        exact List.mem_append.mpr (Or.inl (List.mem_flatMap.mpr ⟨_, lookup_mem hcm, lookup_key hm⟩))
  · intro s u hu
    change s ∈ ((m.classes.flatMap (fun (_, c) => c.supers)) ++
      (m.impls.flatMap (fun (_, im) => im.supers.map Prod.fst))).eraseDups
    exact List.mem_eraseDups.mpr (List.mem_append.mpr (Or.inr
      (List.mem_flatMap.mpr ⟨_, hmem, lookup_key hu⟩)))

/-- 構成子の全件性は材料から導き、型・効果の支持と既存の許容判定との対応だけを受け取る。 -/
theorem Materials.input_sound (m : Materials) (base : Check.Input)
    (hf : ∀ c cd, m.declarations.core.cons c = some cd → Ty.SupportList (· ∈ base.formation.atoms) cd.args)
    (ht : CheckArguments.HeadTableSupport base.formation.atoms m.declarations base.B)
    (hs : CheckArguments.SatSound base.B base.satDec)
    (ha : CheckArguments.AdmitsSound base.B base.admitsDec)
    (hr : CheckArguments.RangeAdmitsSound base.B base.admitsRDec)
    (ho : ∀ o t b ts, base.opPrim o t = some (b, ts) → t.Support (· ∈ base.formation.atoms) →
      Ty.SupportList (· ∈ base.formation.atoms) ts) : (m.input base).Sound :=
  ⟨⟨m.constructors_complete, hf⟩, ht, hs, ha, hr, ho⟩

/-- 必須の判定が読む本体の名前も、同じ有限の実装とメソッドの材料から得る。 -/
theorem Materials.accept_names_complete (m : Materials) (base : Check.Input) :
    CheckAccept.NamesComplete (m.input base) m.program := by
  refine ⟨(m.names_complete base).defs, (m.names_complete base).impls, ?_⟩
  intro i id hi name body hm
  change lookup (m.impls.map (fun (n, im) => (n, im.decl))) i = some id at hi
  rw [lookup_map] at hi
  obtain ⟨im, him, rfl⟩ := Option.map_eq_some_iff.mp hi
  change lookup (im.methods.map (fun (n, method) => (n, method.body))) name = some body at hm
  rw [lookup_map] at hm
  obtain ⟨method, hmethod, _⟩ := Option.map_eq_some_iff.mp hm
  change name ∈ ((m.classes.flatMap (fun (_, c) => c.methods.map Prod.fst)) ++
    (m.impls.flatMap (fun (_, im) => im.methods.map Prod.fst))).eraseDups
  exact List.mem_eraseDups.mpr (List.mem_append.mpr (Or.inr
    (List.mem_flatMap.mpr ⟨_, lookup_mem him, lookup_key hmethod⟩)))

/-- checker が照合した実名の契約を、射影前のメソッド材料の実名として読み出す。 -/
theorem Materials.actual_contracts {m : Materials} {base i im}
    (hi : lookup m.impls i = some im)
    (hc : CheckDeclarations.ContractsMatch (m.input base) i im.decl) :
    ∀ cd, (m.input base).D.classes im.signature.cls = some cd → ∀ name method ms,
      lookup im.methods name = some method → cd.methods name = some ms → method.names = ms.names := by
  intro cd hcd name method ms hm hms
  have hn := hc cd hcd name ms hms
  rw [(Materials.method_input (base := base) hi hm).1] at hn
  exact hn

end Benitoite.Release.Refinement.Surface.CheckTables
