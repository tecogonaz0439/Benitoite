import Benitoite.Release.Refinement.StandardModelCore
import Benitoite.Release.Refinement.StandardModelGeneral
import Benitoite.Release.Refinement.ProgramExtension
import Benitoite.Release.Refinement.StandardModelNameLists

/-! # 組込みの表の完成

利用者のプログラムの組込みの表を、合成表の行（合成済みの名前）と、証拠を持たない名前の行（仮定側）で一つの表に
完成させる（設計書 07-04「01-12 との対応」）。主な定理は任意の表と信頼条件で述べてあるので、利用者のプログラムへ
当てるときは、完成した表で `CoreAssumptions` と `TargetAgreement` を組み立てる。

- 信頼条件の29条件（`CoreAssumptions` の28欄と `TargetAgreement` の1欄）は、名前ごとに分ける16欄（`RowConditions`。
  `CoreAssumptions` の15欄と `TargetAgreement` の1欄）、資源の種類ごとの解放の存在（`ReleaseOn` の1条件）、表全体の
  10欄（`TableConditions`。外部の欄を `ExternalAssumptions` の3欄へ展開すると12条件）に分かれ、16＋1＋12＝29 である
  （`Builtins.core_of_parts`）。
- 完成した表の各欄は、合成済みの名前・効果のラベル・資源の種類で分け、合成済みの側は合成表の値を仮定側の表で
  上書きしない。仮定側の名前は δ・IO 応答・通常資源の状態の三区分で受け、形式化の外の名前には署名を持たせない。
-/
namespace Benitoite.Release.Refinement
noncomputable section
open Scope.Domain (Kind)

/-- 名前の述語 N に制限した、名前ごとの条件（`CoreAssumptions` の15欄と `TargetAgreement` の1欄の計16欄）。 -/
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

/-- 資源の種類の述語 R に制限した解放の存在（`release_exists` の該当部分）。 -/
def Builtins.ReleaseOn (R : OpaqueName → Prop) (P : Program) (B : Builtins) : Prop :=
  ∀ Ψ v o, R o → HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) →
    B.isResource o = true → ∃ r, B.releaseResponse v r

/-- 表全体の条件（名前ごとに分けない10欄。外部の3欄は `ExternalAssumptions` の1欄として持つ）。 -/
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

/-- 信頼条件の29欄の組立て。署名を持つ全名前を二つの述語で覆い、資源の全種類を二つの述語で覆えば、各部分の条件と
表全体の条件から `CoreAssumptions` と `TargetAgreement` が従う。 -/
theorem Builtins.core_of_parts {P : Program} {B : Builtins} {N M : PrimName → Prop} {R S : OpaqueName → Prop}
    (names : ∀ b s, B.sig b = some s → N b ∨ M b)
    (resources : ∀ o, B.isResource o = true → R o ∨ S o)
    (hN : Builtins.RowConditions N P B) (hM : Builtins.RowConditions M P B)
    (hR : Builtins.ReleaseOn R P B) (hS : Builtins.ReleaseOn S P B)
    (ht : Builtins.TableConditions P B) :
    Builtins.CoreAssumptions P B ∧ Builtins.TargetAgreement P B := by
  have pick : ∀ {b s}, B.sig b = some s → ∀ {α : Prop},
      (Builtins.RowConditions N P B → N b → α) → (Builtins.RowConditions M P B → M b → α) → α :=
    fun h _ f g => (names _ _ h).elim (f hN) (g hM)
  refine ⟨{
    sat_rename := ht.sat_rename
    admits_rename := fun b sg C Γ Δ ts ξ h => pick h (·.admits_rename b sg C Γ Δ ts ξ · h) (·.admits_rename b sg C Γ Δ ts ξ · h)
    sat_values := ht.sat_values
    admits_values := fun b sg Ψ Q C Γ Δ Ξ ν ts h =>
      pick h (·.admits_values b sg Ψ Q C Γ Δ Ξ ν ts · h) (·.admits_values b sg Ψ Q C Γ Δ Ξ ν ts · h)
    sat_renameTypes := ht.sat_renameTypes
    admits_renameTypes := fun b sg C C' Γ Δ ts ρ h =>
      pick h (·.admits_renameTypes b sg C C' Γ Δ ts ρ · h) (·.admits_renameTypes b sg C C' Γ Δ ts ρ · h)
    sat_subst := ht.sat_subst
    admits_subst := fun b sg C0 C1 ts ts' es' h =>
      pick h (·.admits_subst b sg C0 C1 ts ts' es' · h) (·.admits_subst b sg C0 C1 ts ts' es' · h)
    toExternalAssumptions := ht.external
    delta_typed := fun Ψ b sg ts es rs ws a e h =>
      pick h (·.delta_typed Ψ b sg ts es rs ws a e · h) (·.delta_typed Ψ b sg ts es rs ws a e · h)
    io_typed := fun Ψ b sg ts es rs ws a e out obs h =>
      pick h (·.io_typed Ψ b sg ts es rs ws a e out obs · h) (·.io_typed Ψ b sg ts es rs ws a e out obs · h)
    io_kind := fun Ψ b sg ts es rs ws a e out obs h =>
      pick h (·.io_kind Ψ b sg ts es rs ws a e out obs · h) (·.io_kind Ψ b sg ts es rs ws a e out obs · h)
    io_exists := fun Ψ b sg ts es rs ws a e h =>
      pick h (·.io_exists Ψ b sg ts es rs ws a e · h) (·.io_exists Ψ b sg ts es rs ws a e · h)
    sig_scoped := fun b s h => pick h (·.sig_scoped b s · h) (·.sig_scoped b s · h)
    sat_unconstrained := ht.sat_unconstrained
    admits_sat := fun b s C ts h => pick h (·.admits_sat b s C ts · h) (·.admits_sat b s C ts · h)
    release_exists := fun Ψ v o typed resource =>
      (resources o resource).elim (fun r => hR Ψ v o r typed resource) (fun r => hS Ψ v o r typed resource)
    pathBases_shape := fun b s h => pick h (·.pathBases_shape b s · h) (·.pathBases_shape b s · h)
    io_op := fun b s h => pick h (·.io_op b s · h) (·.io_op b s · h)
    opEff_io := fun b s l h => pick h (·.opEff_io b s l · h) (·.opEff_io b s l · h)
    effect_ops := ht.effect_ops
    state_effect := ht.state_effect
    ref_get := ht.ref_get
    ref_set := ht.ref_set
    store_shape := fun b s h => pick h (·.store_shape b s · h) (·.store_shape b s · h)
    store_admits := fun b s C ts h => pick h (·.store_admits b s C ts · h) (·.store_admits b s C ts · h) },
    ⟨fun Ψ b sg ts es rs ws a e out obs h =>
      pick h (·.io_target Ψ b sg ts es rs ws a e out obs · h) (·.io_target Ψ b sg ts es rs ws a e out obs · h)⟩⟩

/-- 利用者のプログラムの data 型の宣言の有限の一覧。構成子の lookup はこの一覧の lookup であり、型の制約（等値・鍵）
の判定と、鍵の符号化が読む構成子の並びはこの一覧から作る。変性の検査を満たす。 -/
structure StandardModel.DataTable (P : Program) where
  declarations : List StandardKeyTyping.DataDecl
  constructorNames : ((declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst).Nodup
  dataNames : (declarations.map StandardKeyTyping.DataDecl.name).Nodup
  cons_eq : P.cons = fun c => (declarations.flatMap StandardKeyTyping.DataDecl.entries).lookup c
  converged : Benitoite.Release.summariesConverged (declarations.map StandardKeyTyping.DataDecl.summaryInput)
    (Benitoite.Release.dataSummaries (declarations.map StandardKeyTyping.DataDecl.summaryInput)) = true
  valid : P.VarianceValid

/-- 宣言の一覧の要約による型の制約の判定。 -/
def StandardModel.DataTable.sat {P : Program} (T : StandardModel.DataTable P) : List TParam → Ty → TParam → Prop :=
  ModelConstraints.sat (Benitoite.Release.dataSummaries (T.declarations.map StandardKeyTyping.DataDecl.summaryInput))

/-- 鍵の符号化が読む構成子の並び。 -/
def StandardModel.DataTable.keyNames {P : Program} (T : StandardModel.DataTable P) : List ConName :=
  (T.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst

/-- 宣言の一覧と同じ型の制約の判定を持つ表の鍵の宣言表。 -/
def StandardModel.DataTable.table {P : Program} (T : StandardModel.DataTable P) {B : Builtins} (h : B.sat = T.sat) :
    StandardKeyTyping.Table P B :=
  ⟨T.declarations, T.constructorNames, T.dataNames, T.cons_eq, T.converged, fun C a p => by rw [h]; rfl⟩

/-- 利用者のプログラムの宣言の一覧で型の制約と鍵の符号化を作った合成表。 -/
def StandardModel.DataTable.base {P : Program} (T : StandardModel.DataTable P) : Builtins :=
  StandardModel.baseBuiltinsFor T.sat T.keyNames

/-- 合成プログラムの宣言の一覧。 -/
def StandardModel.dataTable (externals : List (ExternalKey × ExternalDecl)) :
    StandardModel.DataTable (StandardModel.program externals) :=
  ⟨StandardModel.declarations, (StandardModel.table externals).constructorNames,
    (StandardModel.table externals).dataNames, (StandardModel.table externals).cons_eq,
    (StandardModel.table externals).converged, StandardModel.variance_valid externals⟩

/-- 合成プログラムの宣言の一覧で作った合成表は、合成表である。 -/
theorem StandardModel.dataTable_base (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.dataTable externals).base = StandardModel.baseBuiltins :=
  StandardModel.baseBuiltinsFor_base

/-- 仮定側の表。δ・IO 応答・通常資源の状態の名前の署名と応答、その資源の種類と解放、効果の種類。 -/
structure StandardModel.AssumedTable where
  sig : PrimName → Option PrimSig
  delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop
  isResource : OpaqueName → Bool
  releaseResponse : Val → Option Benitoite.Release.ErrKind → Prop
  effKind : EffName → Option Kind

/-- 名前の一覧。合成済みの名前、仮定側の三区分、形式化の外の名前、仮定側の資源の種類、合成表の効果表が成功する
全ラベル（`effKind` が none のラベルを含む）。 -/
structure StandardModel.NameLists where
  composed : List PrimName
  delta : List PrimName
  io : List PrimName
  state : List PrimName
  outside : List PrimName
  resources : List OpaqueName
  composedEffects : List EffName

/-- 仮定側の名前（三区分の和）。 -/
def StandardModel.NameLists.assumed (L : StandardModel.NameLists) : List PrimName := L.delta ++ L.io ++ L.state

/-- 一覧の整形式。合成表の署名の全名前を合成済みに持ち、区分は互いに交わらない。 -/
structure StandardModel.NameLists.WF (L : StandardModel.NameLists) : Prop where
  composedAll : ∀ b, (StandardModel.baseBuiltins.sig b).isSome → b ∈ L.composed
  disjoint : ∀ b, b ∈ L.composed → b ∉ L.assumed
  deltaDisjoint : ∀ b, b ∈ L.delta → b ∉ L.io ∧ b ∉ L.state
  ioDisjoint : ∀ b, b ∈ L.io → b ∉ L.state
  outside : ∀ b, b ∈ L.outside → b ∉ L.composed ∧ b ∉ L.assumed
  effects : ∀ l, (StandardModel.baseBuiltins.effects l).isSome → l ∈ L.composedEffects
  resources : ∀ o, o ∈ L.resources → StandardModel.baseBuiltins.isResource o = false

/-- 仮定側の操作のうち、ラベル l を opEff に持つもの。 -/
def StandardModel.assumedOps (L : StandardModel.NameLists) (A : StandardModel.AssumedTable) (l : EffName) :
    List PrimName :=
  L.assumed.filter (fun b => (A.sig b).bind PrimSig.opEff == some l)

/-- 完成した表の欄。合成済みの側は、利用者のプログラムの宣言の一覧で作った合成表の値を仮定側の表で上書きしない。 -/
def StandardModel.completeBase (L : StandardModel.NameLists) {P : Program} (T : StandardModel.DataTable P)
    (A : StandardModel.AssumedTable) : Builtins :=
  {T.base with
    sig := fun b => if b ∈ L.composed then T.base.sig b
      else if b ∈ L.assumed then A.sig b else none
    delta := fun b => if b ∈ L.composed then T.base.delta b else A.delta b
    ioResponse := fun b => if b ∈ L.composed then T.base.ioResponse b else A.ioResponse b
    isResource := fun o => if o ∈ L.resources then A.isResource o else T.base.isResource o
    effects := fun l => match T.base.effects l with
      | some bs => some (bs ++ StandardModel.assumedOps L A l)
      | none => if StandardModel.assumedOps L A l = [] then none else some (StandardModel.assumedOps L A l)
    effKind := fun l => if l ∈ L.composedEffects then T.base.effKind l else A.effKind l }

/-- 完成した表。外部応答は P の外部宣言から作り、解放は資源の分類による抽象の応答と仮定側の応答の和である。 -/
def StandardModel.complete (L : StandardModel.NameLists) {P : Program} (T : StandardModel.DataTable P)
    (A : StandardModel.AssumedTable) : Builtins :=
  ExternalModel.builtins P (StandardModel.completeBase L T A)
    (fun v r => ResourceRelease.response (StandardModel.completeBase L T A).isResource v r ∨ A.releaseResponse v r)

/-- 仮定側の表の契約。署名は仮定側の名前だけに置き、区分ごとの種類を持ち、仮定側の名前の行の条件と、仮定側の資源の
種類の解放の存在を満たす。合成済みの効果のラベル・State のラベル・合成表の資源の解放へ立ち入らない。 -/
structure StandardModel.Completion (L : StandardModel.NameLists) {P : Program} (T : StandardModel.DataTable P)
    (A : StandardModel.AssumedTable) : Prop where
  domain : ∀ b, (A.sig b).isSome → b ∈ L.assumed
  deltaKind : ∀ b s, A.sig b = some s → b ∈ L.delta → s.kind = .pure
  ioKind : ∀ b s, A.sig b = some s → b ∈ L.io ∨ b ∈ L.state → s.kind = .io ∨ s.kind = .exit
  rows : Builtins.RowConditions (· ∈ L.assumed) P (StandardModel.complete L T A)
  release : Builtins.ReleaseOn (· ∈ L.resources) P (StandardModel.complete L T A)
  resourceDomain : ∀ o, A.isResource o = true → o ∈ L.resources
  effKindComposed : ∀ l, l ∈ L.composedEffects → A.effKind l = none
  stateFree : ∀ b s, A.sig b = some s → s.opEff ≠ some stateEff
  releaseComposed : ∀ Ψ v o r, HasTypeV P (StandardModel.complete L T A) Ψ [] [] [] v (.opaque o (.fixed .top)) →
    o ∉ L.resources → A.releaseResponse v r → ResourceRelease.response StandardModel.baseBuiltins.isResource v r

/-- 合成済みの名前で表が一致すること（合成表の行の証明を任意の表へ移す前提）。`ShapeOk` が読む効果表の所属と
`effKind`・`valKind` を含む。 -/
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

/-- 衝突18名の公開名が指す内部名。R40 の後の標準ライブラリは精密側を指す。 -/
def FunctionNames.publicTarget (n : String) : String :=
  if n ∈ FunctionNames.collisionNames then FunctionNames.rename true n else n

theorem FunctionNames.publicTarget_collision {n : String} (h : n ∈ FunctionNames.collisionNames) :
    FunctionNames.publicTarget n = FunctionNames.rename true n := by
  simp [FunctionNames.publicTarget, h]

theorem FunctionNames.publicTarget_other {n : String} (h : n ∉ FunctionNames.collisionNames) :
    FunctionNames.publicTarget n = n := by
  simp [FunctionNames.publicTarget, h]

/-- 衝突18名の公開名は互いに異なる内部名へ写る。 -/
theorem FunctionNames.publicTarget_injective {n m : String} (hn : n ∈ FunctionNames.collisionNames)
    (hm : m ∈ FunctionNames.collisionNames) (h : FunctionNames.publicTarget n = FunctionNames.publicTarget m) :
    n = m := by
  rw [FunctionNames.publicTarget_collision hn, FunctionNames.publicTarget_collision hm] at h
  exact FunctionNames.rename_injective true h

/-- 公開名 `List.mapFrom` は精密側の本体の鍵を指し、合成プログラムはその鍵に精密側の定義を持つ。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).defs (FunctionNames.publicTarget "List.mapFrom") =
      some StandardModel.Body.b101.definition := by
  rw [FunctionNames.publicTarget_collision (by decide),
    show FunctionNames.rename true "List.mapFrom" = StandardModel.Body.b101.key from
      (StandardModel.Body.key_correspondence .b101).symm]
  exact StandardModel.body_lookup externals .b101

/-- 利用者のプログラムが合成プログラムを含むこと。旧宣言の移送の関係にあり、利用者が足す定義は `%` で始まる内部名を
使わず、衝突18名の公開名を定義の鍵にしない（参照は `FunctionNames.publicTarget` の内部名で読む）。 -/
structure StandardModel.Includes (externals : List (ExternalKey × ExternalDecl)) (P : Program) : Prop where
  extends_ : Program.Extends (StandardModel.program externals) P
  internal : ∀ f d, (StandardModel.program externals).defs f = none → P.defs f = some d → ¬ f.startsWith "%"
  publicCollisions : ∀ n, n ∈ FunctionNames.collisionNames → P.defs n = none

/-! ## 言明 -/

/-- 合成済みの名前の行の条件。利用者のプログラムの宣言の一覧で作った合成表と合成済みの名前で一致する任意の表で、
合成表の行の証明を述べる。 -/
def StandardModel.ComposedRowsStatement (L : StandardModel.NameLists)
    (externals : List (ExternalKey × ExternalDecl)) : Prop :=
  L.WF → ∀ P (T : StandardModel.DataTable P) B, StandardModel.Includes externals P →
    Builtins.ComposedAgree L T.base B → Builtins.RowConditions (· ∈ L.composed) P B

/-- 合成表の資源の種類の解放の存在。合成表の解放の応答を含む任意の表へ移す。 -/
def StandardModel.ComposedReleaseStatement (L : StandardModel.NameLists)
    (externals : List (ExternalKey × ExternalDecl)) : Prop :=
  L.WF → ∀ P (T : StandardModel.DataTable P) B, StandardModel.Includes externals P →
    Builtins.ComposedAgree L T.base B →
    (∀ v r, ResourceRelease.response StandardModel.baseBuiltins.isResource v r → B.releaseResponse v r) →
    Builtins.ReleaseOn (fun o => StandardModel.baseBuiltins.isResource o = true) P B

/-- 完成した表の、表全体の条件。 -/
def StandardModel.TableConditionsStatement (L : StandardModel.NameLists)
    (externals : List (ExternalKey × ExternalDecl)) : Prop :=
  L.WF → ∀ P (T : StandardModel.DataTable P) A, StandardModel.Includes externals P → StandardModel.Completion L T A →
    Builtins.TableConditions P (StandardModel.complete L T A)

/-- 完成した表の信頼条件と対象の条件。 -/
def StandardModel.CompletionCoreStatement (L : StandardModel.NameLists)
    (externals : List (ExternalKey × ExternalDecl)) : Prop :=
  L.WF → ∀ P (T : StandardModel.DataTable P) A, StandardModel.Includes externals P → StandardModel.Completion L T A →
    Builtins.CoreAssumptions P (StandardModel.complete L T A) ∧
      Builtins.TargetAgreement P (StandardModel.complete L T A)

/-! ## 合成済みの側を上書きしないこと -/

/-- 宣言の一覧で作った合成表の署名を持つ名前は、合成表の署名を持つ名前と同じである。 -/
theorem StandardModel.DataTable.base_sig_isSome {P : Program} (T : StandardModel.DataTable P) (b : PrimName) :
    (T.base.sig b).isSome = (StandardModel.baseBuiltins.sig b).isSome := by
  show ((StandardModel.primitive b).map _).isSome = ((StandardModel.primitive b).map _).isSome
  cases StandardModel.primitive b <;> rfl

/-- 合成済みのラベルでは、どの仮定側の表でも、完成した表の効果の種類は合成表の値である。 -/
theorem StandardModel.complete_effKind_composed (L : StandardModel.NameLists) {P : Program}
    (T : StandardModel.DataTable P) (A : StandardModel.AssumedTable) (l : EffName) (hl : l ∈ L.composedEffects) :
    (StandardModel.complete L T A).effKind l = T.base.effKind l := by
  simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hl]

/-- 宣言の一覧で作った合成表の `ShapeOk` は完成した表でも成り立つ（`io_op` の合成済みの名前の場合）。 -/
theorem StandardModel.complete_shapeOk_composed (L : StandardModel.NameLists) (hL : L.WF) {P : Program}
    (T : StandardModel.DataTable P) (A : StandardModel.AssumedTable) {b : PrimName} {s : PrimSig}
    (h : T.base.ShapeOk b s) : (StandardModel.complete L T A).ShapeOk b s := by
  obtain ⟨l, bs, ho, hn, he, hb, hm⟩ := h
  have hl : l ∈ L.composedEffects := hL.effects l (by
    change (T.base.effects l).isSome = true
    simp [he])
  have hk : (StandardModel.complete L T A).effKind l = T.base.effKind l :=
    StandardModel.complete_effKind_composed L T A l hl
  have hv : (StandardModel.complete L T A).valKind = T.base.valKind := rfl
  refine ⟨l, bs ++ StandardModel.assumedOps L A l, ho, hn, ?_, List.mem_append_left _ hb, ?_⟩
  · simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, he]
  · rw [hk, hv]; exact hm

/-- 完成した表は、宣言の一覧で作った合成表と合成済みの名前で一致する。 -/
theorem StandardModel.complete_agree (L : StandardModel.NameLists) {P : Program} (T : StandardModel.DataTable P)
    (A : StandardModel.AssumedTable) :
    Builtins.ComposedAgree L T.base (StandardModel.complete L T A) where
  sig b hb := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hb]
  delta b hb := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hb]
  ioResponse b hb := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hb]
  effects l bs b he hb := ⟨bs ++ StandardModel.assumedOps L A l,
    by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, he],
    List.mem_append_left _ hb⟩
  effKind l hl := StandardModel.complete_effKind_composed L T A l hl
  isResource o ho := by simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, ho]
  sat := rfl
  valKind := rfl
  valContent := rfl
  admitsR := rfl
  refGet := rfl
  refSet := rfl

/-- 仮定側の操作が State のラベルを使わなければ、完成した表の State の効果表は空のままである。 -/
theorem StandardModel.complete_state_effect (L : StandardModel.NameLists) {P : Program}
    (T : StandardModel.DataTable P) (A : StandardModel.AssumedTable) (hc : StandardModel.Completion L T A) :
    (StandardModel.complete L T A).effects stateEff = some [] := by
  have hfree : StandardModel.assumedOps L A stateEff = [] := by
    simp only [StandardModel.assumedOps, List.filter_eq_nil_iff]
    intro b _
    cases hs : A.sig b with
    | none => simp
    | some s => simpa using hc.stateFree b s hs
  have hbase : T.base.effects stateEff = some [] := StandardModel.state_effect (StandardModel.program [])
  simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hbase, hfree]

/-- 完成した表の署名を持つ名前は、合成済みか仮定側の名前である。 -/
theorem StandardModel.complete_sig_cover (L : StandardModel.NameLists) {P : Program} (T : StandardModel.DataTable P)
    (A : StandardModel.AssumedTable) {b : PrimName} {s : PrimSig}
    (h : (StandardModel.complete L T A).sig b = some s) : b ∈ L.composed ∨ b ∈ L.assumed := by
  by_cases hb : b ∈ L.composed
  · exact Or.inl hb
  · by_cases ha : b ∈ L.assumed
    · exact Or.inr ha
    · simp [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, hb, ha] at h

/-- 完成した表の資源の種類は、合成表の資源か仮定側の資源の種類である。 -/
theorem StandardModel.complete_resource_cover (L : StandardModel.NameLists) {P : Program}
    (T : StandardModel.DataTable P) (A : StandardModel.AssumedTable) {o : OpaqueName}
    (h : (StandardModel.complete L T A).isResource o = true) :
    StandardModel.baseBuiltins.isResource o = true ∨ o ∈ L.resources := by
  by_cases ho : o ∈ L.resources
  · exact Or.inr ho
  · left
    have hb : T.base.isResource o = true := by
      simpa [StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase, ho] using h
    exact hb

/-- 完成した表の解放の応答は、合成表の資源の値について合成表の解放の応答を含む。 -/
theorem StandardModel.complete_release_composed (L : StandardModel.NameLists) (hL : L.WF) {P : Program}
    (T : StandardModel.DataTable P) (A : StandardModel.AssumedTable) {v : Val} {r : Option Benitoite.Release.ErrKind}
    (h : ResourceRelease.response StandardModel.baseBuiltins.isResource v r) :
    (StandardModel.complete L T A).releaseResponse v r := by
  obtain ⟨o, i, hv, ho⟩ := h
  have hn : o ∉ L.resources := fun hm => by simp [hL.resources o hm] at ho
  have hb : T.base.isResource o = true := ho
  exact Or.inl ⟨o, i, hv, by simpa [StandardModel.completeBase, hn] using hb⟩

/-- 完成した表の信頼条件は、合成済みの行・合成表の資源の解放・表全体の条件から組み立てられる（29欄の対応表）。 -/
theorem StandardModel.completion_core_of (L : StandardModel.NameLists) (externals : List (ExternalKey × ExternalDecl))
    (rows : StandardModel.ComposedRowsStatement L externals)
    (release : StandardModel.ComposedReleaseStatement L externals)
    (table : StandardModel.TableConditionsStatement L externals) :
    StandardModel.CompletionCoreStatement L externals := by
  intro hL P T A hI hc
  exact Builtins.core_of_parts (N := (· ∈ L.composed)) (M := (· ∈ L.assumed))
    (R := fun o => StandardModel.baseBuiltins.isResource o = true) (S := (· ∈ L.resources))
    (fun _ _ h => StandardModel.complete_sig_cover L T A h)
    (fun _ h => StandardModel.complete_resource_cover L T A h)
    (rows hL P T _ hI (StandardModel.complete_agree L T A)) hc.rows
    (release hL P T _ hI (StandardModel.complete_agree L T A)
      (fun _ _ h => StandardModel.complete_release_composed L hL T A h)) hc.release
    (table hL P T A hI hc)

/-! ## レビューの反例: 合成済みのラベルに効果の種類を与える仮定側の表 -/

/-- 署名を持たず、合成表で種類のない `Console.Write` に path の種類を与える仮定側の表。 -/
def StandardModel.reviewA : StandardModel.AssumedTable where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  isResource := fun _ => false
  releaseResponse := fun _ _ => True
  effKind := fun l => if l = "Console.Write" then some .path else none

/-- この表は契約の `effKindComposed` を満たさない。 -/
theorem StandardModel.reviewA_not_completion (L : StandardModel.NameLists)
    (hc : "Console.Write" ∈ L.composedEffects) {P : Program} (T : StandardModel.DataTable P) :
    ¬ StandardModel.Completion L T StandardModel.reviewA := by
  intro h
  have := h.effKindComposed "Console.Write" hc
  simp [StandardModel.reviewA] at this

/-- 構成の側でも、この表の種類は合成済みのラベルに現れない。 -/
example (L : StandardModel.NameLists) (hc : "Console.Write" ∈ L.composedEffects) {P : Program}
    (T : StandardModel.DataTable P) :
    (StandardModel.complete L T StandardModel.reviewA).effKind "Console.Write" =
      StandardModel.baseBuiltins.effKind "Console.Write" :=
  StandardModel.complete_effKind_composed L T _ _ hc

/-! ## 標準の名前の一覧 -/

/-- 標準の名前の一覧。合成済みの名前と効果のラベルは合成表の行から作り、仮定側は台帳から生成した一覧を使う。 -/
def StandardModel.nameLists : StandardModel.NameLists where
  composed := StandardModel.Primitive.all.map StandardModel.Primitive.name
  delta := StandardModel.deltaNames
  io := StandardModel.ioNames
  state := StandardModel.stateNames
  outside := StandardModel.outsideNames
  resources := StandardModel.resourceNames
  composedEffects := stateEff :: StandardModel.Primitive.all.filterMap (fun row => row.signature.opEff)

theorem StandardModel.nameLists_wf : StandardModel.nameLists.WF where
  composedAll b h := by
    obtain ⟨s, hs⟩ := Option.isSome_iff_exists.mp h
    obtain ⟨row, hrow, rfl, -⟩ := StandardModel.lookup_primitive hs
    exact List.mem_map_of_mem hrow
  disjoint b hb ha := by
    obtain ⟨row, -, rfl⟩ := List.mem_map.mp hb
    have hall : StandardModel.nameLists.assumed.all (fun b => (StandardModel.primitive b).isNone) = true := by
      decide
    have hnone := List.all_eq_true.mp hall _ ha
    simp [StandardModel.primitive_lookup row] at hnone
  deltaDisjoint b hb := by
    have hall : ∀ b ∈ StandardModel.deltaNames, b ∉ StandardModel.ioNames ∧ b ∉ StandardModel.stateNames := by
      decide
    exact hall b hb
  ioDisjoint b hb := by
    have hall : ∀ b ∈ StandardModel.ioNames, b ∉ StandardModel.stateNames := by decide
    exact hall b hb
  outside b hb := by
    have hall : ∀ b ∈ StandardModel.outsideNames, b ∉ StandardModel.nameLists.assumed := by decide
    have hnone : StandardModel.outsideNames.all (fun b => (StandardModel.primitive b).isNone) = true := by decide
    refine ⟨fun hc => ?_, hall b hb⟩
    obtain ⟨row, -, rfl⟩ := List.mem_map.mp hc
    have := List.all_eq_true.mp hnone _ hb
    simp [StandardModel.primitive_lookup row] at this
  effects l h := by
    by_cases hl : l = stateEff
    · exact hl ▸ List.mem_cons_self
    · apply List.mem_cons_of_mem
      change (StandardModel.effects l).isSome = true at h
      simp [StandardModel.effects, hl] at h
      obtain ⟨row, hm, hop⟩ := h
      exact List.mem_filterMap.mpr ⟨row, hm, hop⟩
  resources o ho := by
    have hall : StandardModel.resourceNames.all (fun o => !(o == "File.Handle")) = true := by decide
    have := List.all_eq_true.mp hall o ho
    change (o == "File.Handle") = false
    simpa using this

/-- 標準の一覧の仮定側の件数は、δ 80・IO 応答 47・通常資源の状態 16、形式化の外は7である。 -/
example : StandardModel.nameLists.delta.length = 80 ∧ StandardModel.nameLists.io.length = 47 ∧
    StandardModel.nameLists.state.length = 16 ∧ StandardModel.nameLists.outside.length = 7 :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- 操作の効果を持つ行のラベルは、合成済みのラベルの一覧に含まれる。 -/
theorem StandardModel.composedEffect_member (row : StandardModel.Primitive) {l : EffName}
    (h : row.signature.opEff = some l) : l ∈ StandardModel.nameLists.composedEffects := by
  apply List.mem_cons_of_mem
  apply List.mem_filterMap.mpr
  have hr := StandardModel.lookup_primitive (by
    simp only [StandardModel.signature,StandardModel.primitive_lookup,Option.map_some] :
      StandardModel.signature row.name = some row.signature)
  obtain ⟨row',hm,hn,_⟩ := hr
  have same := (StandardModel.primitive_lookup row).symm.trans (hn ▸ StandardModel.primitive_lookup row')
  cases Option.some.inj same
  exact ⟨row,hm,h⟩

/-- 合成済みの効果のラベルは `Console.Write` を含む。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    ¬ StandardModel.Completion StandardModel.nameLists (StandardModel.dataTable externals) StandardModel.reviewA :=
  StandardModel.reviewA_not_completion _ (StandardModel.composedEffect_member .p373 rfl) _

end
end Benitoite.Release.Refinement
