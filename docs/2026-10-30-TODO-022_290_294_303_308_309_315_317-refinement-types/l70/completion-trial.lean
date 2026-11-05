import Benitoite
namespace Benitoite.Release.Refinement
/-! L70.05b の契約の形の試行（本番に入れない）。sorry を使わず、定義と言明の型検査だけを行う。 -/
open Scope.Domain (Target Kind)

/-- 名前の述語 N に制限した、名前ごとの条件（CoreAssumptions の17欄の該当部分と TargetAgreement）。 -/
structure Builtins.RowConditions (N : PrimName → Prop) (P : Program) (B : Builtins) : Prop where
  admits_rename : ∀ b sg C Γ Δ ts (ξ : Nat → Nat), N b → B.sig b = some sg →
    (∀ i j, i < j → ξ i < ξ j) → TypeAnnotations P C Γ ts →
    TypeAnnotations P C Δ (ts.map (renameTy ξ)) →
    sg.admits (TypeCtx.constraints C) ts → sg.admits (TypeCtx.constraints C) (ts.map (renameTy ξ))
  admits_values : ∀ b sg Ψ Q C Γ Δ Ξ ν ts, N b → B.sig b = some sg →
    TypedValueImages P B Ψ Q C Γ Δ Ξ ν → TypeAnnotations P C Γ ts →
    sg.admits (TypeCtx.constraints C) ts → sg.admits (TypeCtx.constraints C) (ts.map (substTyValues ν))
  admits_renameTypes : ∀ b sg C C' Γ Δ ts ρ, N b → B.sig b = some sg → TypeParamRenaming C C' ρ →
    TypeAnnotations P C Γ ts → TypeAnnotations P C' Δ (ts.map (fun a => a.renameTypes ρ)) →
    sg.admits (TypeCtx.constraints C) ts → sg.admits (TypeCtx.constraints C') (ts.map (fun a => a.renameTypes ρ))
  admits_subst : ∀ b sg C0 C1 ts ts' es', N b → B.sig b = some sg →
    sg.admits (TypeCtx.constraints (C1 ++ C0)) ts →
    (∀ t ∈ ts', t.WF 0 0 0) → SatAll B C1 ts' (TypeCtx.constraints C0) → ts'.length = C0.length →
    sg.admits (TypeCtx.constraints C1) (ts.map (Ty.substAt C1.length ts' es'))
  delta_typed : ∀ Ψ b sg ts es rs ws a e, N b →
    B.sig b = some sg → sg.kind = .pure → BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
  io_typed : ∀ Ψ b sg ts es rs ws a e out obs, N b →
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.ioResponse b ts es ws out obs →
    Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
  io_kind : ∀ Ψ b sg ts es rs ws a e out obs, N b →
    B.sig b = some sg → BuiltinArgs P B Ψ b sg ts es rs ws a e →
    B.ioResponse b ts es ws out obs →
    (sg.kind = .io ∧ ∀ n, out ≠ .exit n) ∨ (sg.kind = .exit ∧ ∀ v, out ≠ .val v)
  io_exists : ∀ Ψ b sg ts es rs ws a e, N b →
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → ∃ out obs, B.ioResponse b ts es ws out obs
  sig_scoped : ∀ b s, N b → B.sig b = some s → PrimSig.Scoped P s
  admits_sat : ∀ b s C ts, N b → B.sig b = some s → s.admits (TypeCtx.constraints C) (Ty.normTys ts) →
    SatAll B C ts (s.tparams.map TParamDecl.constraints)
  pathBases_shape : ∀ b s, N b → B.sig b = some s → s.kind = .pathBases → s.PathBasesShape B b
  io_op : ∀ b s, N b → B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.ShapeOk b s
  opEff_io : ∀ b s l, N b → B.sig b = some s → s.opEff = some l →
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases
  store_shape : ∀ b s, N b → B.sig b = some s → s.kind ≠ .pathBases → s.StoreShape
  store_admits : ∀ b s C ts, N b → B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
    s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts
  io_target : ∀ Ψ b sg ts es rs ws a e out obs, N b →
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.ioResponse b ts es ws out obs →
    Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs

/-- 資源の種類 R に制限した解放の条件（release_exists の該当部分）。 -/
def Builtins.ReleaseOn (R : OpaqueName → Prop) (P : Program) (B : Builtins) : Prop :=
  ∀ Ψ v o, R o → HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) →
    B.isResource o = true → ∃ r, B.releaseResponse v r

/-- 表全体の条件（名前ごとに分けない12欄）。 -/
structure Builtins.TableConditions (P : Program) (B : Builtins) : Prop where
  sat_rename : ∀ C Γ Δ a p (ξ : Nat → Nat), (∀ i j, i < j → ξ i < ξ j) →
    Ty.Annotation P C Γ a → Ty.Annotation P C Δ (renameTy ξ a) →
    B.sat (TypeCtx.constraints C) a p → B.sat (TypeCtx.constraints C) (renameTy ξ a) p
  sat_values : ∀ Ψ Q C Γ Δ Ξ ν a p, TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
    Ty.Annotation P C Γ a → B.sat (TypeCtx.constraints C) a p → B.sat (TypeCtx.constraints C) (substTyValues ν a) p
  sat_renameTypes : ∀ C C' Γ Δ a p ρ, TypeParamRenaming C C' ρ →
    Ty.Annotation P C Γ a → Ty.Annotation P C' Δ (a.renameTypes ρ) →
    B.sat (TypeCtx.constraints C) a p → B.sat (TypeCtx.constraints C') (a.renameTypes ρ) p
  sat_subst : ∀ C0 C1 a p ts es,
    B.sat (TypeCtx.constraints (C1 ++ C0)) a p →
    (∀ t ∈ ts, t.WF 0 0 0) → SatAll B C1 ts (TypeCtx.constraints C0) → ts.length = C0.length →
    B.sat (TypeCtx.constraints C1) (a.substAt C1.length ts es) p
  external : Builtins.ExternalAssumptions P B
  sat_unconstrained : ∀ (t : Ty), t.WF 0 0 0 → B.sat [] t.norm ({} : TParam)
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧ s.opEff = some l
  state_effect : B.effects stateEff = some []
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet

/-- 仮定側の表。143名（δ80・IO47・通常資源の状態16）の署名と応答、その資源の種類。 -/
structure StandardModel.AssumedTable where
  sig : PrimName → Option PrimSig
  delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Target → Prop
  isResource : OpaqueName → Bool
  releaseResponse : Val → Option Benitoite.Release.ErrKind → Prop
  effKind : EffName → Option Kind

/-- 名前の一覧（本番では L60 の台帳から生成する）を受ける。 -/
structure StandardModel.NameLists where
  composed : List PrimName
  assumed : List PrimName       -- δ80・IO47・資源16
  outside : List PrimName       -- 形式化の外7（J70-8: 署名を持たせない）
  resources : List OpaqueName   -- 資源の状態16名が作る資源の種類
  composedEffects : List EffName  -- 合成表の効果表が成功する全ラベル（effKind が none のラベルを含む）

/-- 一覧の整形式。本番では台帳から生成した定数について decide で確かめる。 -/
structure StandardModel.NameLists.WF (L : StandardModel.NameLists) : Prop where
  disjoint : ∀ b, b ∈ L.composed → b ∉ L.assumed
  effects : ∀ l, (StandardModel.baseBuiltins.effects l).isSome → l ∈ L.composedEffects
  resources : ∀ o, o ∈ L.resources → StandardModel.baseBuiltins.isResource o = false

/-- 仮定側の操作のうち、ラベル l を opEff に持つもの。 -/
def StandardModel.assumedOps (L : StandardModel.NameLists) (A : StandardModel.AssumedTable) (l : EffName) : List PrimName :=
  L.assumed.filter (fun b => (A.sig b).bind PrimSig.opEff == some l)

/-- 完成した表。各欄を名前・ラベル・資源の種類で分け、合成済みの側は合成表の値を A で上書きしない。 -/
noncomputable def StandardModel.completeBase (L : StandardModel.NameLists) (A : StandardModel.AssumedTable) : Builtins :=
  {StandardModel.baseBuiltins with
    sig := fun b => if b ∈ L.composed then StandardModel.baseBuiltins.sig b
      else if b ∈ L.assumed then A.sig b else none
    delta := fun b => if b ∈ L.composed then StandardModel.baseBuiltins.delta b else A.delta b
    ioResponse := fun b => if b ∈ L.composed then StandardModel.baseBuiltins.ioResponse b else A.ioResponse b
    isResource := fun o => if o ∈ L.resources then A.isResource o else StandardModel.baseBuiltins.isResource o
    effects := fun l => match StandardModel.baseBuiltins.effects l with
      | some bs => some (bs ++ StandardModel.assumedOps L A l)
      | none => if StandardModel.assumedOps L A l = [] then none else some (StandardModel.assumedOps L A l)
    effKind := fun l => if l ∈ L.composedEffects then StandardModel.baseBuiltins.effKind l else A.effKind l }

noncomputable def StandardModel.complete (L : StandardModel.NameLists) (P : Program) (A : StandardModel.AssumedTable) : Builtins :=
  ExternalModel.builtins P (StandardModel.completeBase L A)
    (fun v r => ResourceRelease.response (StandardModel.completeBase L A).isResource v r ∨ A.releaseResponse v r)

structure StandardModel.Completion (L : StandardModel.NameLists) (externals : List (ExternalKey × ExternalDecl))
    (P : Program) (A : StandardModel.AssumedTable) : Prop where
  domain : ∀ b, (A.sig b).isSome → b ∈ L.assumed
  kinds : ∀ b s, A.sig b = some s → s.kind = .pure ∨ s.kind = .io ∨ s.kind = .exit
  rows : Builtins.RowConditions (· ∈ L.assumed) P (StandardModel.complete L P A)
  release : Builtins.ReleaseOn (· ∈ L.resources) P (StandardModel.complete L P A)
  resourceDomain : ∀ o, A.isResource o = true → o ∈ L.resources
  /-- 合成済みの効果のラベルに種類を与えない（構成でも合成表の値を使うが、A の記述として要求する）。 -/
  effKindComposed : ∀ l, l ∈ L.composedEffects → A.effKind l = none
  /-- 仮定側の操作は State のラベルを使わない（state_effect の効果表を空のまま保つ）。 -/
  stateFree : ∀ b s, A.sig b = some s → s.opEff ≠ some stateEff
  /-- 合成表の資源の値に解放の応答を足さない。 -/
  releaseComposed : ∀ Ψ v o r, HasTypeV P (StandardModel.complete L P A) Ψ [] [] [] v (.opaque o (.fixed .top)) →
    o ∉ L.resources → A.releaseResponse v r → ResourceRelease.response StandardModel.baseBuiltins.isResource v r

/-- 合成済みの名前で表が一致すること（任意の B へ一般化する前提）。ShapeOk が読む効果表の所属と effKind・valKind を含む。 -/
structure Builtins.ComposedAgree (L : StandardModel.NameLists) (S B : Builtins) : Prop where
  sig : ∀ b, b ∈ L.composed → B.sig b = S.sig b
  delta : ∀ b, b ∈ L.composed → B.delta b = S.delta b
  ioResponse : ∀ b, b ∈ L.composed → B.ioResponse b = S.ioResponse b
  effects : ∀ l bs b, S.effects l = some bs → b ∈ bs → ∃ bs', B.effects l = some bs' ∧ b ∈ bs'
  effKind : ∀ l, l ∈ L.composedEffects → B.effKind l = S.effKind l
  isResource : ∀ o, o ∉ L.resources → B.isResource o = S.isResource o
  sat : B.sat = S.sat
  valKind : B.valKind = S.valKind
  valContent : B.valContent = S.valContent
  admitsR : B.admitsR = S.admitsR
  refGet : B.refGet = S.refGet
  refSet : B.refSet = S.refSet

/-- 効果の種類の上書きの穴が閉じたこと: 合成済みのラベルでは、どの A でも合成表の値になる。 -/
theorem StandardModel.complete_effKind_composed (L : StandardModel.NameLists) (P : Program)
    (A : StandardModel.AssumedTable) (l : EffName) (hl : l ∈ L.composedEffects) :
    (StandardModel.complete L P A).effKind l = StandardModel.baseBuiltins.effKind l := by
  simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hl]

/-- 合成済みの名前の ShapeOk は完成した表でも成り立つ（io_op の合成済みの場合）。 -/
theorem StandardModel.complete_shapeOk_composed (L : StandardModel.NameLists) (hL : L.WF) (P : Program)
    (A : StandardModel.AssumedTable) {b : PrimName} {s : PrimSig}
    (h : StandardModel.baseBuiltins.ShapeOk b s) : (StandardModel.complete L P A).ShapeOk b s := by
  obtain ⟨l, bs, ho, hn, he, hb, hm⟩ := h
  have hl : l ∈ L.composedEffects := hL.effects l (by simp [he])
  have hk : (StandardModel.complete L P A).effKind l = StandardModel.baseBuiltins.effKind l :=
    StandardModel.complete_effKind_composed L P A l hl
  have hv : (StandardModel.complete L P A).valKind = StandardModel.baseBuiltins.valKind := rfl
  refine ⟨l, bs ++ StandardModel.assumedOps L A l, ho, hn, ?_, List.mem_append_left _ hb, ?_⟩
  · simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, he]
  · rw [hk, hv]; exact hm

/-- レビューの反例の A（署名なし、Console.Write に path の種類）。 -/
def StandardModel.reviewA : StandardModel.AssumedTable where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  isResource := fun _ => false
  releaseResponse := fun _ _ => True
  effKind := fun l => if l = "Console.Write" then some .path else none

/-- 反例の A は新しい Completion の effKindComposed を満たさない。 -/
theorem StandardModel.reviewA_not_completion (L : StandardModel.NameLists)
    (hc : "Console.Write" ∈ L.composedEffects) (externals) (P : Program) :
    ¬ StandardModel.Completion L externals P StandardModel.reviewA := by
  intro h
  have := h.effKindComposed "Console.Write" hc
  simp [StandardModel.reviewA] at this

/-- 構成の側でも、反例の A の種類は合成済みのラベルに現れない。 -/
example (L : StandardModel.NameLists) (hc : "Console.Write" ∈ L.composedEffects) (P : Program) :
    (StandardModel.complete L P StandardModel.reviewA).effKind "Console.Write" =
      StandardModel.baseBuiltins.effKind "Console.Write" :=
  StandardModel.complete_effKind_composed L P _ _ hc

/-- Console.Write は合成表の効果表で成功するラベルである（WF の effects 欄から composedEffects に入る）。 -/
example : (StandardModel.baseBuiltins.effects "Console.Write").isSome := by decide

/-- stateFree の下で、完成した表の State の効果表は空のままである。 -/
theorem StandardModel.complete_state_effect (L : StandardModel.NameLists) (P : Program)
    (A : StandardModel.AssumedTable) (hbase : StandardModel.baseBuiltins.effects stateEff = some [])
    (hfree : StandardModel.assumedOps L A stateEff = []) :
    (StandardModel.complete L P A).effects stateEff = some [] := by
  simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hbase, hfree]

/-- 完成した表は合成表に一致する（ComposedAgree）。 -/
theorem StandardModel.complete_agree (L : StandardModel.NameLists) (P : Program)
    (A : StandardModel.AssumedTable) :
    Builtins.ComposedAgree L StandardModel.baseBuiltins (StandardModel.complete L P A) where
  sig b hb := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hb]
  delta b hb := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hb]
  ioResponse b hb := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hb]
  effects l bs b he hb := ⟨bs ++ StandardModel.assumedOps L A l,
    by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, he],
    List.mem_append_left _ hb⟩
  effKind l hl := StandardModel.complete_effKind_composed L P A l hl
  isResource o ho := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, ho]
  sat := rfl
  valKind := rfl
  valContent := rfl
  admitsR := rfl
  refGet := rfl
  refSet := rfl

/-- completion_core の言明の形（Includes は別に置く前提として受ける）。 -/
def StandardModel.CompletionCoreStatement (L : StandardModel.NameLists) (externals : List (ExternalKey × ExternalDecl)) (P : Program) (A : StandardModel.AssumedTable) : Prop :=
  L.WF → StandardModel.Completion L externals P A →
  Builtins.RowConditions (· ∈ L.composed) P (StandardModel.complete L P A) →
  Builtins.ReleaseOn (fun o => StandardModel.baseBuiltins.isResource o = true) P (StandardModel.complete L P A) →
  Builtins.TableConditions P (StandardModel.complete L P A) →
  Builtins.CoreAssumptions P (StandardModel.complete L P A) ∧ Builtins.TargetAgreement P (StandardModel.complete L P A)

/-- 表全体の外部の3欄は L60 の汎用の補題から得られる（型が合うことの確認）。 -/
example (L : StandardModel.NameLists) (P : Program) (A : StandardModel.AssumedTable) :
    Builtins.ExternalAssumptions P (StandardModel.complete L P A) :=
  ExternalModel.external_assumptions P _ _

#print axioms StandardModel.complete_shapeOk_composed
#print axioms StandardModel.reviewA_not_completion
#print axioms StandardModel.complete_agree
end Benitoite.Release.Refinement
