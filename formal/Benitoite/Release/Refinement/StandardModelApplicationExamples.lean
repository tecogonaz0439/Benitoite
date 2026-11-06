import Benitoite.Release.Refinement.StandardModelApplication
import Benitoite.Release.Refinement.StandardModelConditionInputs

/-! # 利用者の宣言を追加したプログラムと完成した表の証人 -/
namespace Benitoite.Release.Refinement.StandardModel.ApplicationExamples
noncomputable section

/-- 仮定側の行を使わない表。通常資源の追加の種類も持たない。 -/
def noAssumptions : AssumedTable where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  isResource := fun _ => false
  releaseResponse := fun _ _ => False
  effKind := fun _ => none

/-- 仮定側の行が無いことから契約を証明する。合成側の行の証拠はこの契約の中へ移さない。 -/
theorem noAssumptions_completion {L : NameLists} (hL : L.WF) {P} (T : DataTable P) :
    Completion L T noAssumptions := by
  have absent : ∀ b, b ∈ L.assumed → (complete L T noAssumptions).sig b = none := by
    intro b hb
    have hnc : b ∉ L.composed := fun hc => hL.disjoint b hc hb
    simp [complete, completeBase, ExternalModel.builtins, noAssumptions, hnc]
  have emptySig : ∀ b s, b ∈ L.assumed → (complete L T noAssumptions).sig b = some s → False := by
    intro b s hb hs
    rw [absent b hb] at hs
    cases hs
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro b h; cases h
  · intro b s h; cases h
  · intro b s h; cases h
  · constructor <;> intros <;> exfalso <;> solve_by_elim [emptySig]
  · intro Ψ v o ho _ hr
    change (if o ∈ L.resources then false else T.base.isResource o) = true at hr
    simp [ho] at hr
  · intro o h; cases h
  · intros; rfl
  · intro b s h; cases h
  · intro Ψ v o r _ _ h; exact h.elim

/-- 追加する利用者の関数。 -/
def userDef : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  body := .ret (.const .unit)

/-- 外部宣言の表を保ち、利用者の関数を一つ加える。 -/
def userProgram (externals : List (ExternalKey × ExternalDecl)) : Program :=
  {program externals with defs := fun f => if f = "User.main" then some userDef else (program externals).defs f}

private theorem user_fresh (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).defs "User.main" = none := rfl

/-- 合成プログラムの宣言の包含と内部名の非衝突。 -/
theorem user_includes (externals : List (ExternalKey × ExternalDecl)) : Includes externals (userProgram externals) where
  extends_ := { Program.Extends.refl (program externals) with
    defs := by
      intro f d hd
      have hn : f ≠ "User.main" := by intro he; subst f; rw [user_fresh] at hd; cases hd
      simp [userProgram, hn, hd] }
  internal := by
    intro f d hn hd
    by_cases he : f = "User.main"
    · subst f
      simp only [String.startsWith_string_iff]
      decide
    · simp [userProgram, he, hn] at hd
  publicCollisions := by
    intro n hn
    have h0 := (Includes.refl externals).publicCollisions n hn
    simp only [FunctionNames.collisionNames, List.mem_cons, List.not_mem_nil, or_false] at hn
    rcases hn with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
      rfl | rfl <;> exact h0

/-- 利用者の関数は data 宣言と変性を変えない。 -/
def userData (externals : List (ExternalKey × ExternalDecl)) : DataTable (userProgram externals) :=
  { dataTable externals with
    valid := by
      have h := (user_includes externals).extends_
      obtain ⟨h1,h2⟩ := (Program.varianceValid_iff _).mp (variance_valid externals)
      apply (Program.varianceValid_iff _).mpr
      refine ⟨fun d info hi => (h1 d info hi).ofExtends h, fun c cd hc => ?_⟩
      obtain ⟨hi,ha⟩ := h2 c cd hc
      exact ⟨hi, fun a hm => ⟨(ha a hm).1.ofExtends h, (ha a hm).2.1.ofExtends h,
        (ha a hm).2.2.ofExtends h⟩⟩}

private theorem user_typed (externals : List (ExternalKey × ExternalDecl)) (B : Builtins) :
    userDef.WellTyped (userProgram externals) B := by
  refine ⟨⟨rfl, by simp [userDef]⟩, ?_, ?_, ?_⟩
  · simp [userDef, Def.tel, signatureTel, Ty.HasKind, kindsTel, kindsEff, kindsList, Eff.empty]
  · change Ty.AnnotationR _ [] [] [] (.dependentFn (.done (.base .unit) Eff.empty))
    rw [Ty.annotationR_nil]
    exact ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
  · change TelBodyTyR _ B _ _ [] [] [] [] (.done (.base .unit) Eff.empty) (.ret (.const .unit))
    rw [telBodyTyR_nil]
    exact .done (.C_Return (.V_Const trivial))

private theorem user_scoped (externals : List (ExternalKey × ExternalDecl)) :
    userDef.Scoped (userProgram externals) := by
  have ha := (user_typed externals (userData externals).base).2.2.1
  refine ⟨⟨rfl,by simp [userDef]⟩, ?_, trivial⟩
  exact ⟨by simp [userDef, Def.tel, signatureTel, Ty.SourceScoped, Ty.WF, Tel.WF,
      Ty.RowsIn, Tel.RowsIn, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes,
      Eff.WF, Eff.RowsIn, Ty.RowsInList, Ty.WFList, Eff.Canonical, Eff.norm, Ty.normTys, Eff.empty],
    by simp [userDef, Def.tel, signatureTel, Tel.RowsIn, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn, Eff.empty],
    (user_typed externals (userData externals).base).2.1, ha⟩

/-- 追加宣言の全義務を満たす。 -/
theorem user_additions (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) (B : Builtins) :
    Program.Additions (program externals) (userProgram externals) B := by
  constructor
  case impls => intro i id hn hd; exact (by cases hd)
  case cons => intro c cd hn hd; change (program externals).cons c = some cd at hd; rw [hn] at hd; cases hd
  case ops => intro o od hn hd; exact (by cases hd)
  case classes => intro c cd hn hd; exact (by cases hd)
  case metadata =>
    intro d info hi
    obtain ⟨hlen,hcons,hfields⟩ := (program_wellFormed externals hw).metadata d info hi
    exact ⟨hlen,hcons,fun a ha => ⟨(hfields a ha).1,
      (hfields a ha).2.1.ofExtends (user_includes externals).extends_,
      (hfields a ha).2.2.ofExtends (user_includes externals).extends_⟩⟩
  case dataVariance => intro d info hn hd; change (program externals).dataInfo d = some info at hd; rw [hn] at hd; cases hd
  case conVariance => intro c cd hn hd; change (program externals).cons c = some cd at hd; rw [hn] at hd; cases hd
  case effectOps => intro l os o hn hd; exact (by cases hd)
  case opEffects => intro o od hn hd; exact (by cases hd)
  case builtinEffects => intro l os hn hd; exact (by cases hd)
  intro f d hn hd
  by_cases he : f = "User.main"
  · subst f
    have hd' : userDef = d := Option.some.inj hd
    subst d
    exact ⟨user_typed externals B, user_scoped externals⟩
  · simp [userProgram, he, hn] at hd

/-- 同じ利用者のプログラムの具体の包含・完成・追加宣言の義務から、全ての主定理へ接続する。 -/
theorem user_guarantees (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) (σ : PathEnv) :
    ProgramGuarantees (userProgram externals) (complete nameLists (userData externals) noAssumptions) σ :=
  included_guarantees nameLists_wf (userData externals) (user_includes externals)
    (noAssumptions_completion nameLists_wf _) hw (user_additions externals hw _) σ

/-- 外部関数を一つ持つ入力で系の全前提が同時に成り立つ。 -/
example (σ : PathEnv) :
    ProgramGuarantees (userProgram positiveExternals)
      (complete nameLists (userData positiveExternals) noAssumptions) σ :=
  user_guarantees _ positive_wf σ

/-- 追加した関数を実際に呼び、戻り値へ一段進む。型付けは同じ完成した表で行う。 -/
example (externals : List (ExternalKey × ExternalDecl)) (σ : PathEnv) :
    let P := userProgram externals
    let B := complete nameLists (userData externals) noAssumptions
    HasTypeC P B StoreTy.empty [] [] [] none (.app (.fnRef "User.main" [] []) []) (.base .unit) Eff.empty ∧
    Step P B σ (.run (Closure.pure (.app (.fnRef "User.main" [] []) [])) [] Store.empty) none
      (.run (Closure.pure (.ret (.const .unit))) [.mark] Store.empty) := by
  dsimp only
  have hsig : SignatureInstance (userProgram externals) [] [] userDef.tel [] [] [] := by
    refine ⟨⟨trivial,trivial,rfl⟩, ?_, ⟨rfl, ?_⟩, ?_, ?_, ?_⟩
    · intro a ha; cases ha
    · intro i a k hi; cases hi
    · intro e he; cases he
    · intro e he; cases he
    · exact ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
  have had : Admissible (complete nameLists (userData externals) noAssumptions) [] 0 [] 0
      (Qsig userDef.params userDef.ret userDef.eff) Qempty [] [] userDef.eff := by
    refine ⟨⟨rfl,?_⟩, ?_, rfl, ?_, ?_, ?_, ?_⟩
    · intro i a p hi; cases hi
    · intro a ha; cases ha
    · intro e he; cases he
    · simp [userDef, Eff.RowsIn, Ty.RowsInList, Eff.empty]
    · intro i hi; simp [userDef, Qsig, QTys, QTy, QEff, Qempty, Benitoite.Release.Qempty, Eff.empty] at hi
    · intro i hi; simp [userDef, Qsig, QTys, QTy, QEff, Qempty, Benitoite.Release.Qempty, Eff.empty] at hi
  have hf := HasTypeVQ.fun_empty (P := userProgram externals) (Ψ := StoreTy.empty) (C := []) (Γ := []) (Φ := [])
    (f := "User.main") (d := userDef) rfl ⟨rfl,by simp [userDef]⟩ rfl had hsig
  have ht : instantiatedTel userDef.tel [] [] = .done (.base .unit) Eff.empty := by
    have h := Tel.substAt_nil_of_wf (nr := 0) (nv := 0) (c := 0) [] userDef.tel ⟨trivial,trivial,rfl⟩
    exact h
  rw [ht] at hf
  refine ⟨.C_DependentApp hf (.done ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩), ?_⟩
  exact .E_Fun (f := "User.main") (ts := []) (es := []) (rs := []) (ws := []) (k := [])
    (μ := Store.empty) (q := Closure.pure (.app (.fnRef "User.main" [] []) [])) (d := userDef)
    rfl rfl rfl rfl rfl

/-- 形式化の外の七名の署名は、同じ完成した表で全て無い。 -/
example (externals : List (ExternalKey × ExternalDecl)) : ∀ b ∈ outsideNames,
    (complete nameLists (userData externals) noAssumptions).sig b = none :=
  fun _ hb => complete_outside nameLists_wf _ _ hb

/-- 内部の front の名前を利用者が追加定義として上書きすることはない。 -/
example (externals : List (ExternalKey × ExternalDecl)) (d : Def) :
    (userProgram externals).defs "%List.getFront" ≠ some d :=
  (user_includes externals).getFront_fresh rfl

/-- 合成側の丸め方式の構成子は、利用者の宣言表でも同じ宣言を持つ。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    ((userData externals).declarations.flatMap StandardKeyTyping.DataDecl.entries).lookup
      "RoundingMode.TowardZero" = some ⟨"RoundingMode", 0, []⟩ :=
  (user_includes externals).constructor_entry (userData externals) rfl

/-- Map と Set を含む合成側の全行は、同じ利用者の構成子順で δ を作る。 -/
example (externals : List (ExternalKey × ExternalDecl)) (row : Primitive) :
    (complete nameLists (userData externals) noAssumptions).delta row.name =
      row.deltaWith (userData externals).keyNames row.name :=
  complete_delta nameLists_wf _ _ row

/-- 対象のない標準の PathIn 定数は、利用者の完成した表でも許さない。 -/
example (externals : List (ExternalKey × ExternalDecl)) (id : Nat) :
    ¬ ConstOK (complete nameLists (userData externals) noAssumptions) (.opaque "Scope.PathIn" id) := by
  intro h
  have hn : (some Scope.Domain.Kind.path : Option Scope.Domain.Kind) = none := h.1
  cases hn

/-- 外部関数の参照は Lean のソース値に含まれる。 -/
example (f : ExternalFunctionId) (ts : List Ty) : (Val.externalRef f ts).Source := trivial

end
end Benitoite.Release.Refinement.StandardModel.ApplicationExamples
