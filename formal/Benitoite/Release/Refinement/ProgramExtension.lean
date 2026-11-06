import Benitoite.Release.Refinement.ProgramWellFormed
import Benitoite.Release.Refinement.HandlerEffects
import Benitoite.Release.Refinement.TypingDeclared
import Benitoite.Release.Refinement.StandardModelResponse

/-! # 利用者のプログラムへの収集: 旧宣言の移送と追加宣言の合成

標準の定義を持つプログラム P に利用者の宣言を加えたプログラム P' について、主な定理の前提を P' で得る形を定める
（設計書 07-04「01-12 との対応」）。

- `Program.Extends P P'`: P の lookup を P' が同じ値で返し、P が名前を持つ data 型に P' が構成子を足さず、その変性の
  宣言を変えない。型付けは P の lookup を正の形で読むほか、同じ data 型の全構成子（`Program.DataArity`・網羅性の
  `Inhabits`）と変性の宣言（`Program.varianceFor`）を読むので、後の二欄が要る。
- `Program.Additions P P' B`: P に無く P' にある宣言の義務。整形式・型付け・変性・効果の検査のうち、追加された宣言の
  分を P' の上で述べる。供給元は表層の性質 1 である。
- 型付けが組み込みの表を読むのは型付けの七射影だけである。合成表は外部応答を P の型付けから作るので、P と P' の
  合成表は等しくないが、七射影は等しい（`StandardModel.builtins_fields`）。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- P が data 型 d の名前を持つ。構成子か変性の宣言のどちらかがある。 -/
def Program.HasData (P : Program) (d : DataName) : Prop :=
  (∃ c cd, P.cons c = some cd ∧ cd.data = d) ∨ (P.dataInfo d).isSome

/-- 旧宣言の移送の関係。 -/
structure Program.Extends (P P' : Program) : Prop where
  defs : ∀ f d, P.defs f = some d → P'.defs f = some d
  cons : ∀ c cd, P.cons c = some cd → P'.cons c = some cd
  ops : ∀ o od, P.ops o = some od → P'.ops o = some od
  effects : ∀ l os, P.effects l = some os → P'.effects l = some os
  classes : ∀ c cd, P.classes c = some cd → P'.classes c = some cd
  impls : ∀ i id, P.impls i = some id → P'.impls i = some id
  dataInfo : ∀ d info, P.dataInfo d = some info → P'.dataInfo d = some info
  externals : P.externals = P'.externals
  /-- P が名前を持つ data 型の構成子は、P' でも P の一覧と同じである。 -/
  consClosed : ∀ c cd, P'.cons c = some cd → P.HasData cd.data → P.cons c = some cd
  /-- P が名前を持つ data 型の変性の宣言は、P' でも同じである。 -/
  dataInfoOld : ∀ d, P.HasData d → P'.dataInfo d = P.dataInfo d

theorem Program.Extends.refl (P : Program) : Program.Extends P P where
  defs _ _ h := h
  cons _ _ h := h
  ops _ _ h := h
  effects _ _ h := h
  classes _ _ h := h
  impls _ _ h := h
  dataInfo _ _ h := h
  externals := rfl
  consClosed _ _ h _ := h
  dataInfoOld _ _ := rfl

/-- 変性の検査（`Program.VarianceValid`）の、変性の宣言一つ分の条件。 -/
def Program.DataInfoVariance (P : Program) (d : DataName) (info : DataVarianceDecl) : Prop :=
  info.variances.length = info.arity ∧
    (∀ i variance, info.variances[i]? = some variance →
      (¬ P.ParamOccursInFields d i → variance = .invariant)) ∧
    (∀ a ∈ info.requirements, Ty.VarianceOK P info.variances .both a) ∧
    (∀ item ∈ info.publicBoundary, Ty.VarianceOK P info.variances item.1 item.2)

/-- 変性の検査の、構成子一つ分の条件。 -/
def Program.ConVariance (P : Program) (cd : ConDecl) : Prop :=
  (∀ info, P.dataInfo cd.data = some info → info.arity = cd.ntys) ∧
    (∀ a ∈ cd.args,
      Ty.Annotation P (List.replicate cd.ntys TypeCtx.valueParam) [] a ∧
      Ty.HasKind P (List.replicate cd.ntys .value) a .value ∧
      Ty.VarianceOK P (P.varianceFor cd.data cd.ntys) .positive a)

/-- 変性の検査は、変性の宣言ごとと構成子ごとの条件の組である。 -/
theorem Program.varianceValid_iff (P : Program) :
    P.VarianceValid ↔ (∀ d info, P.dataInfo d = some info → P.DataInfoVariance d info) ∧
      (∀ c cd, P.cons c = some cd → P.ConVariance cd) := Iff.rfl

/-- 追加された宣言の義務。P に無く P' にある宣言を、P' の上で検査した結果として受ける。 -/
structure Program.Additions (P P' : Program) (B : Builtins) : Prop where
  defs : ∀ f d, P.defs f = none → P'.defs f = some d → Def.WellTyped P' B d ∧ d.Scoped P'
  impls : ∀ i id, P.impls i = none → P'.impls i = some id → ImplDecl.WellTyped P' B id ∧ id.Scoped P'
  cons : ∀ c cd, P.cons c = none → P'.cons c = some cd → P'.DataArity cd.data cd.ntys ∧ cd.Scoped P'
  ops : ∀ o od, P.ops o = none → P'.ops o = some od → od.Scoped P'
  classes : ∀ c cd, P.classes c = none → P'.classes c = some cd → cd.Scoped P'
  metadata : P'.MetadataScoped
  dataVariance : ∀ d info, P.dataInfo d = none → P'.dataInfo d = some info → P'.DataInfoVariance d info
  conVariance : ∀ c cd, P.cons c = none → P'.cons c = some cd → P'.ConVariance cd
  effectOps : ∀ l os o, P.effects l = none → P'.effects l = some os → o ∈ os →
    ∃ od, P'.ops o = some od ∧ od.eff = l
  opEffects : ∀ o od, P.ops o = none → P'.ops o = some od → ∃ os, P'.effects od.eff = some os ∧ o ∈ os
  builtinEffects : ∀ l os, P.effects l = none → P'.effects l = some os → B.effects l = none

/-- P に無く P' にある効果のラベルを、組込みの表が持たない。P' が組込みのラベルへ利用者の操作を足すと、
ハンドラが処理済みとする効果（`handled`）が P' で小さくなるので、旧宣言の移送はこの条件を要する。 -/
def Program.FreshEffects (P P' : Program) (B : Builtins) : Prop :=
  ∀ l os, P.effects l = none → P'.effects l = some os → B.effects l = none

/-- 追加宣言の義務は、追加された効果のラベルが組込みの表に無いことを含む。 -/
theorem Program.Additions.freshEffects {P P' B} (h : Program.Additions P P' B) :
    Program.FreshEffects P P' B := h.builtinEffects

/-- 旧宣言の値と計算の型付けの移送。P の導出は P' の導出である。 -/
def Program.ExtendsTypingStatement (P P' : Program) (B : Builtins) : Prop :=
  Program.Extends P P' → Program.FreshEffects P P' B → P.WellFormed →
    (∀ Ψ Q C Γ Φ v a, HasTypeVQ P B Ψ Q C Γ Φ v a → HasTypeVQ P' B Ψ Q C Γ Φ v a) ∧
    (∀ Ψ Q C Γ Φ R m a ε Δ, HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
      HasTypeCQ P' B Ψ Q C Γ Φ R m a ε Δ)

/-- 旧宣言の網羅性の移送。P で宣言済みの型について、網羅性は P と P' で同じである。 -/
def Program.ExtendsExhaustiveStatement (P P' : Program) : Prop :=
  Program.Extends P P' → P.WellFormed →
    ∀ C Γ a ps, Ty.Declared P C Γ a → (Exhaustive P a ps ↔ Exhaustive P' a ps)

/-- 旧宣言の関数と実装の型付けの移送。 -/
def Program.ExtendsDeclarationStatement (P P' : Program) (B : Builtins) : Prop :=
  Program.Extends P P' → Program.FreshEffects P P' B → P.WellFormed →
    (∀ d, d.Scoped P → Def.WellTyped P B d → Def.WellTyped P' B d) ∧
    (∀ id, id.Scoped P → ImplDecl.WellTyped P B id → ImplDecl.WellTyped P' B id)

/-- 追加宣言を検査した後の全体の合成。 -/
def Program.ComposeStatement (P P' : Program) (B : Builtins) : Prop :=
  P.WellTyped B → P.WellFormed → P.EffectsOk B → Program.Extends P P' → Program.Additions P P' B →
    P'.WellTyped B ∧ P'.WellFormed ∧ P'.EffectsOk B

/-- 合成表の型付けの七射影は、プログラムによらない。 -/
theorem StandardModel.builtins_fields (P P' : Program) :
    Builtins.TypingFieldsEq (StandardModel.builtins P) (StandardModel.builtins P') :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- 合成表の上の値の型付けは、外部応答を作るプログラムを替えた表へ移る。 -/
example {P P' : Program} {Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P (StandardModel.builtins P) Ψ Q C Γ Φ v a) :
    HasTypeVQ P (StandardModel.builtins P') Ψ Q C Γ Φ v a :=
  HasTypeVQ.of_fields (StandardModel.builtins_fields P P') h

/-! ## 同じ data 型へ構成子を足す拡張を断る -/

/-- 構成子 `D.A` だけを持つプログラム。 -/
def Program.extensionBase : Program where
  defs := fun _ => none
  cons := fun c => if c = "D.A" then some ⟨"D", 0, []⟩ else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

/-- 同じ data 型 `D` へ構成子 `D.B` を足したプログラム。 -/
def Program.extensionAdded : Program :=
  { Program.extensionBase with
    cons := fun c => if c = "D.A" ∨ c = "D.B" then some ⟨"D", 0, []⟩ else none }

/-- 既存の data 型へ構成子を足す拡張は `consClosed` で断られる（足すと既存の照合の網羅性が移らない）。 -/
theorem Program.extensionAdded_not_extends :
    ¬ Program.Extends Program.extensionBase Program.extensionAdded := by
  intro h
  have hd : Program.extensionBase.HasData "D" := Or.inl ⟨"D.A", ⟨"D", 0, []⟩, by simp [Program.extensionBase], rfl⟩
  have := h.consClosed "D.B" ⟨"D", 0, []⟩ (by simp [Program.extensionAdded]) hd
  simp [Program.extensionBase] at this

/-- 新しい data 型の構成子を足す拡張は、旧宣言の移送の関係にある。 -/
example : Program.Extends Program.extensionBase
    { Program.extensionBase with
      cons := fun c => if c = "D.A" then some ⟨"D", 0, []⟩ else if c = "E.C" then some ⟨"E", 0, []⟩ else none } where
  defs _ _ h := h
  cons c cd h := by
    simp only [Program.extensionBase] at h ⊢
    split at h <;> simp_all
  ops _ _ h := h
  effects _ _ h := h
  classes _ _ h := h
  impls _ _ h := h
  dataInfo _ _ h := h
  externals := rfl
  consClosed c cd h hd := by
    rcases hd with ⟨c', cd', hc', hd'⟩ | hi
    · simp only [Program.extensionBase] at hc' h ⊢
      by_cases hA : c' = "D.A"
      · simp only [hA, ite_true, Option.some.injEq] at hc'
        subst hc'
        by_cases hcA : c = "D.A"
        · simpa [hcA] using h
        · simp only [hcA, ite_false] at h ⊢
          by_cases hcE : c = "E.C"
          · simp only [hcE, ite_true, Option.some.injEq] at h
            subst h
            simp at hd'
          · simp [hcE] at h
      · simp [hA] at hc'
    · simp [Program.extensionBase] at hi
  dataInfoOld _ _ := rfl

end
end Benitoite.Release.Refinement
