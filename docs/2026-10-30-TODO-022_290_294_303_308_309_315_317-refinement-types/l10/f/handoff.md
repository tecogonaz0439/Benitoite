# L20 への受渡し

2026-11-01。指定ブランチ `m014/l10.f`、B_WORK `f4952052e9474f40ac9a257d260065cf8103cfaf`。git 操作はしていない。本書は L10.55 の受渡しであり、全埋め込みを証明した記録ではない。`Old` は `Benitoite.Release`、`R/` は `formal/Benitoite/Release/Refinement/` を表す。断りのない宣言は新しい名前空間のものである。

## 既存の表と全中間判断

`LegacyTables` は旧の受理から新の受理への片方向の対応を要求する。sat/admits/admitsR の逆向き、δ/IO の全量化の旧新同値、新しい型付けや遷移の結論は入力にしない。constructor の同名 data ごとの arity、全欄の Annotation・HasKind・SourceScoped を省略しない。旧 ConDecl.Scoped の番号の上限だけからこれらを得たとは扱わない。

以下は現行本番の完全な表である。

```lean
structure LegacyPrimSignature (s0 : Benitoite.Release.PrimSig) (s : PrimSig) : Prop where
  constraints : s.tparams.map TParamDecl.constraints = s0.tparams
  neffs : s.neffs = s0.neffs
  names : s.names = s0.names
  params : s.params = embedParameters s0.params
  ret : s.ret = (embedTy s0.ret).shiftV s0.params.length 0
  eff : s.eff = (embedEff s0.eff).shiftV s0.params.length 0
  kind : s.kind = embedPrimKind s0.kind
  opEff : s.opEff = s0.opEff
  rkinds : s.rkinds = s0.rkinds
  shape : s.shape = s0.shape
  admits : ∀ C ts, s0.admits C ts → s.admits C (Ty.normTys (embedTys ts))

/-- 新型付けや遷移の結論ではなく、表の各位置の対応を読む。 -/
structure LegacyTables (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop where
  primitives : ∀ b s0, B0.sig b = some s0 → ∃ s, B.sig b = some s ∧ LegacyPrimSignature s0 s
  sat : ∀ C a p, B0.sat C a p → B.sat C (embedTy a).norm p
  resources : B.isResource = B0.isResource
  effects : B.effects = B0.effects
  refGet : B.refGet = B0.refGet
  refSet : B.refSet = B0.refSet
  effKind : B.effKind = B0.effKind
  valKind : B.valKind = B0.valKind
  valContent : ∀ o, B.valContent o = (B0.valContent o).map embedTy
  ranges : ∀ b rs, B0.admitsR b rs → B.admitsR b (rs.map embedRange)
  constructorArity : ∀ c cd c' cd', P0.cons c = some cd → P0.cons c' = some cd' →
    cd.data = cd'.data → cd.ntys = cd'.ntys
  constructorFields : ∀ c cd, P0.cons c = some cd → ∀ a ∈ cd.args,
    Ty.Annotation (embedProgramWithKinds K P0) (List.replicate cd.ntys ({} : TParam)) [] (embedTy a) ∧
    Ty.HasKind (embedProgramWithKinds K P0) (List.replicate cd.ntys .value) (embedTy a) .value
  constructorScope : ∀ c cd, P0.cons c = some cd → ∀ a ∈ cd.args,
    (embedTy a).SourceScoped 0 cd.ntys 0 0

```

`LegacyTables.dataArity` は同名 data の構成子の実在と全 arity の一致を返す。`constructor_scoped` は各欄の SourceScoped と Annotation/HasKind を返す。`varianceValid` は dataInfo=none の像について、型引数を不変として欄の変性を証明する。none の metadata の条件が空に成立することを、原ソースの収集が完全である証拠にしない。P.WellFormed の全宣言の充足は L20 G08 と L70 に残る。

`LegacyOutputInput` は根の型の検査だけではない。各 node で型文脈・ストア・値文脈・全結果型と型列・R・効果・局所参照を検査する。kind の列は親と宣言から延長し、全子を同じ述語で検査する。7種類の判断、46局所規則（値19・値列2・同型値列2・計算17・腕3・節2・失敗節1）を持つ。構文に現れない let の中間型と拡張Γ、App の関数・結果型、空腕、resume、Fail の型束縛も含む。

```lean
def LegacyNodeContext (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (Ψ : Benitoite.Release.StoreTy) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) : Prop :=
  LegacyContextInput K P0 Ψ C Γ ⟨κ, C, 0, Γ.length⟩

def LegacyNodeTypes (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat)
    (as : List Benitoite.Release.Ty) : Prop :=
  ∀ a ∈ as, LegacyTypeInput K P0 ⟨κ, C, 0, nv⟩ a .value

def LegacyNodeLocal (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat)
    (L : Benitoite.Release.LocalCtx) : Prop :=
  ∀ item ∈ L, ∀ k ∈ item.toList, LegacyBuilderInput K P0 ⟨κ, C, 0, nv⟩ k

def LegacyNodeRegular (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : LegacyJudgment → Prop
  | .value κ Ψ _Q C Γ v a =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValueInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ v ∧ LegacyHeldTypeInput B0 B v a ∧
      LegacyNodeTypes K P0 κ C Γ.length [a]
  | .values κ Ψ _Q C Γ vs ts =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValuesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ vs ∧
      LegacyNodeTypes K P0 κ C Γ.length ts
  | .each κ Ψ _Q C Γ vs a =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyValuesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ vs ∧
      LegacyNodeTypes K P0 κ C Γ.length [a]
  | .comp κ Ψ _Q C Γ R m a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyCompInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ m ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .arms κ Ψ _Q C Γ R arms a b e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyArmsInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ arms ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: b :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .clauses κ Ψ _Q C Γ R eb cs a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyClausesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ cs ∧
      LegacyNodeTypes K P0 κ C Γ.length (a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [eb, e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
  | .failure κ Ψ _Q C Γ E R cs a e L =>
      LegacyNodeContext K P0 κ Ψ C Γ ∧ LegacyClausesInput K P0 B0 B ⟨κ, C, 0, Γ.length⟩ cs ∧
      LegacyNodeTypes K P0 κ C Γ.length (E :: a :: R.toList) ∧
      LegacyRowsInput K P0 ⟨κ, C, 0, Γ.length⟩ [e] ∧ LegacyNodeLocal K P0 κ C Γ.length L
inductive LegacyOutputInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : LegacyJudgment → Prop where
  | node {j children} : LegacyRule K P0 B0 j children →
      LegacyNodeRegular K P0 B0 B j →
      (∀ child ∈ children, LegacyOutputInput K P0 B0 B child) →
      LegacyOutputInput K P0 B0 B j

```

`LegacyRule.old` と `LegacyOutputInput.old` は旧判断を再構成する。`LegacyOutputInput.regular` は根の適格性を取り出す。旧 HasType だけから任意の中間型の kind/形成を導くことはしない。`LegacyOutputInput` から新判断を得る帰納法と、各子へ適格性を引き継ぐ全証明が L20 の仕事である。

通常節では、操作自身の制約・value kind の列と範囲/値深さ0で元の `opSig` を検査する。`LegacyClausesInput.signature_wf` を使い、Top だけでなく実際の節の範囲 S に対する `opSigAt` へ渡す。外側 C で不適格な元署名を補わない。`use` は値を束縛せず、入力の nv も増やさない。

## 全導出・状態と宣言本体の完全署名

次のコードは [handoff.lean](handoff.lean) の型検査した契約の全体である。七判断・パターン・網羅性・状態の命題を **Prop の定義** として置き、未証明定理や公理は置いていない。旧 HasType の前提は LegacyOutputInput.old からも得られるが、依頼の全署名と照合するため明記する。七判断の主たる帰納の結論は任意のΦ（`∀ Φ : List Pred`）である。Armsの入口の観測はnoneを保つ。空Φの形はこの結論を[]へ特殊化する系とし、既存のweaken_conditionsを経由しない。

`LegacyStateInput` は本番で未定義である。以下の高階の引数がその完全な型を固定する。L20 は状態・frame・store 内の全コードについて、七判断の全導出の入力、型注釈と保持値の適格性を具体化する。新しい StateTyE や遷移先の等号をこの入力の欄にしてはならない。型を検査したことは、その入力の定義や embedStateTyE の証明の完了を意味しない。

```lean
namespace Benitoite.Release.Refinement.L10FHandoff
noncomputable section

def embedHasTypeVQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValueInput K P0 B0 B Δ v →
      LegacyOutputInput K P0 B0 B (.value Δ.kinds Ψ Q C Γ v a) →
      Benitoite.Release.HasTypeVQ P0 B0 Ψ Q C Γ v a →
      ∀ Φ : List Pred, HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) Φ (embedVal v) (embedTy a)

def embedHasTypeVsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {ts : List Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.values Δ.kinds Ψ Q C Γ vs ts) →
      Benitoite.Release.HasTypeVsQ P0 B0 Ψ Q C Γ vs ts →
      ∀ Φ : List Pred, HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTys ts)

def embedHasTypeEachQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.each Δ.kinds Ψ Q C Γ vs a) →
      Benitoite.Release.HasTypeEachQ P0 B0 Ψ Q C Γ vs a →
      ∀ Φ : List Pred, HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTy a)

def embedHasTypeCQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
      {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyCompInput K P0 B0 B Δ m →
      LegacyOutputInput K P0 B0 B (.comp Δ.kinds Ψ Q C Γ R m a e L) →
      Benitoite.Release.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L →
      ∀ Φ : List Pred, HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
        (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeArmsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {xs : List Benitoite.Release.Arm}
      {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyArmsInput K P0 B0 B Δ xs →
      LegacyOutputInput K P0 B0 B (.arms Δ.kinds Ψ Q C Γ R xs a b e L) →
      Benitoite.Release.HasTypeArmsQ P0 B0 Ψ Q C Γ R xs a b e L →
      ∀ Φ : List Pred, HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) none
        (embedArms xs) (embedTy a) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeClausesQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.clauses Δ.kinds Ψ Q C Γ R eb cs a e L) →
      Benitoite.Release.HasTypeClausesQ P0 B0 Ψ Q C Γ R eb cs a e L →
      ∀ Φ : List Pred, HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) (embedEff eb)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasFailureClause : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {E : Benitoite.Release.Ty} {R : Option Benitoite.Release.Ty}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.failure Δ.kinds Ψ Q C Γ E R cs a e L) →
      Benitoite.Release.HasFailureClause P0 B0 Ψ Q C Γ E R cs a e L →
      ∀ Φ : List Pred, HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) Φ (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

/-- 旧→新のパターンと網羅性。適格な入力に条件を限る未証明の契約。 -/
def embedExhaustive : Prop :=
  ∀ {K P0 B0 B κ C nv a ps}, K.WF P0 → LegacyTables K P0 B0 B →
    LegacyNodeTypes K P0 κ C nv [a] → Benitoite.Release.Exhaustive P0 a ps →
    Exhaustive (embedProgramWithKinds K P0) (embedTy a) ps

def embedPatTy : Prop :=
  ∀ {K P0 B0 B κ C nv p a δ}, K.WF P0 → LegacyTables K P0 B0 B →
    LegacyNodeTypes K P0 κ C nv (a :: δ) → Benitoite.Release.PatTy P0 p a δ →
    PatTy (embedProgramWithKinds K P0) p (embedTy a) (embedTys δ)

def embedPatTys : Prop :=
  ∀ {K P0 B0 B κ C nv ps as δ}, K.WF P0 → LegacyTables K P0 B0 B →
    LegacyNodeTypes K P0 κ C nv (as ++ δ) → Benitoite.Release.PatTys P0 ps as δ →
    PatTys (embedProgramWithKinds K P0) ps (embedTys as) (embedTys δ)

def embedAltsTy : Prop :=
  ∀ {K P0 B0 B κ C nv alts a δ}, K.WF P0 → LegacyTables K P0 B0 B →
    LegacyNodeTypes K P0 κ C nv (a :: δ) → Benitoite.Release.AltsTy P0 alts a δ →
    AltsTy (embedProgramWithKinds K P0) alts (embedTy a) (embedTys δ)

def embedStateTyE
    (LegacyStateInput : DeclarationKinds → Benitoite.Release.Program →
      Benitoite.Release.Builtins → Builtins → PathEnv → Benitoite.Release.State → Prop) : Prop :=
    ∀ {P0 B0 B σ Eb s} (K : DeclarationKinds),
      K.WF P0 → LegacyTables K P0 B0 B → σ.Valid →
      LegacyStateInput K P0 B0 B σ s → Benitoite.Release.StateTyE P0 B0 Eb s →
      StateTyE (embedProgramWithKinds K P0) B σ (embedEff Eb) (embedState s)

/-- P0.defs f = some d の関数本体。 -/
def functionBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (f : FunName) (d : Benitoite.Release.Def) : Prop :=
  LegacyOutputInput K P0 B0 B (.comp (K.functionParams f) Benitoite.Release.StoreTy.empty
    (Benitoite.Release.Qsig d.params d.ret d.eff) d.tparams (Benitoite.Release.binds d.params)
    (some d.ret) d.body d.ret d.eff [])

/-- P0.impls i = some id、クラスとメソッドの lookup、id.methods m = some body の本体。 -/
def methodBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (m : MethName) (ms : Benitoite.Release.MethSig) (body : Benitoite.Release.Comp) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.comp (K.methodParams id.cls m ++ List.replicate id.tparams.length .value)
      Benitoite.Release.StoreTy.empty (Benitoite.Release.Qsig ms.params ms.ret ms.eff)
      (ms.tparams ++ id.tparams)
      (Benitoite.Release.binds (id.dictTys.map (Benitoite.Release.Ty.shift ms.tparams.length 0) ++
        ms.params.map (id.methTy ms)))
      (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret)
      (Benitoite.Release.Eff.substAt ms.tparams.length [id.target] [] ms.eff) [])

/-- s ∈ cd.supers と id.supers s = some value の上位の辞書。 -/
def superBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (s : ClassName) (value : Benitoite.Release.Val) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.value (List.replicate id.tparams.length .value) Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty
      id.tparams (Benitoite.Release.binds id.dictTys) value (.dict s id.target))


def declarationBodyInputs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop :=
  (∀ f d, P0.defs f = some d → functionBodyInput K P0 B0 B f d) ∧
  (∀ i id cd m ms body, P0.impls i = some id → P0.classes id.cls = some cd →
    cd.methods m = some ms → id.methods m = some body →
    methodBodyInput K P0 B0 B id m ms body) ∧
  (∀ i id cd s value, P0.impls i = some id → P0.classes id.cls = some cd →
    s ∈ cd.supers → id.supers s = some value → superBodyInput K P0 B0 B id s value)

end
end Benitoite.Release.Refinement.L10FHandoff

```

`declarationBodyInputs` の三つの全称は、関数の defs、実装・クラス・メソッド・本体の各 lookup、上位クラスの所属と辞書の lookup に対応する。関数は functionBodyInput、メソッドは methodBodyInput、上位辞書は superBodyInput を使う。C/Q/Γ/R/効果/κ の順序は旧 WellTyped の判断そのものである。メソッドの Q は **代入前** の Qsig ms.params ms.ret ms.eff であり、QTel t' へ戻さない。`LegacyDeclarationsInput` は構文の再帰条件なので、この三つの導出全体の入力を代用しない。ソースのプログラムの全宣言を埋め込むときは SourceScoped も供給し、実行時専用の checked/checkedRequest/loc 等がないことを旧 WellFormed/VarsIn だけで済ませない。

現在の表・入力・kind・葉・非継続の供給などの39宣言の署名は [handoff-output.txt](handoff-output.txt) に完全修飾名と暗黙引数を含めて印字した。一覧にはLocalCtx.Shift.emptyを一件含む。七判断と状態の8契約、パターン/網羅性の4契約と三種の親判断を、本番へ追加又は証明した意味ではない。

### Φを一般化する帰納の経路

七判断の各帰納法の仮定は、旧の子判断を受け取った後に `∀ Φ` を返す形とする。C_Ifの子には `boolCond t true/false :: Φ`、C_Let/V_Lamの子には束縛数だけ持ち上げたΦ、腕の子には `pathFacts none … ++ Φ` とguardの真の条件を、そのまま帰納法の仮定へ渡す。checkedRequestの内容の子は[]へ特殊化する。embedLe/embedCoversは任意のΓ・Φで使えるので、この一般化のための新しい信頼条件は要らない。

`HasTypeVQ/CQ.weaken_conditions` はshift_valuesのk=0を経由し、Builtins.ValueAssumptionsとストアのWFを要求する。LegacyTables.satの片方向の対応からそれらは得られない。そのため、空Φで帰納を閉じてから既存弱化で補う経路は使わず、ValueAssumptionsを埋め込みの独立前提へ加えない。detailの旧「空Φから任意Φへは既存弱化」の文は、取りまとめが本節へ合わせて訂正する。

### パターンと旧から新への網羅性

上のembedPatTy/PatTys/AltsTy/ExhaustiveはG10で証明する未実装の契約である。K.WFとLegacyTables、範囲深さ0のLegacyNodeTypesを入力とする。PatTy/AltsTyでは入力型と束縛列の全型、PatTysでは入力列と束縛列を検査する。C_Matchのscrutinee型aの入力はそのLegacyNodeRegularから取り出し、束縛列δの入力は腕の子の拡張Γの正則性から構成する。constructorの総称欄のWF・kind・arityはLegacyTablesから供給し、中間のパターンの形成を旧PatTyだけから無条件に導かない。これらを既存の全導出の入力から構成できなければ、新しい独立の仮定を足して全埋め込みを閉じず、取りまとめへ返す。

無条件の `Old.Exhaustive P0 a ps → Exhaustive (embedProgramWithKinds K P0) (embedTy a) ps` は偽である。変更していない [rv-f-t2.lean](rv-f-t2.lean) のa=`opaque "o" (rvar 0)`では、旧Inhabitsの値がないため空腕の網羅性が成り立つ一方、新しいInhabitsはcheckedAtOpaqueを含むため空腕は網羅的でない。このaは範囲深さ0のLegacyTypeInputが拒む。したがって適格な旧導出の埋め込みの反例ではなく、上の入力条件を外せないことの証拠である。

G10の証明では、旧の像にないcheckedAtとatErrorを含む新Inhabitsの全場合を扱う。checkedAtの照合を旧checked又はopaque定数の照合へ、atErrorを同じ七つの文字列を持つScopeErrorのAt構成子の照合へ対応させる案は未検証であり、一般補題として成功したとは書かない。入れ子のList/data欄、名前と型引数、正規化後の照合と束縛列まで確認する。G06の束縛の型保存とG03の型置換とは共有補題を使い、旧→新の移送をG10で一度だけ数える。

### 旧宣言の辞書の供給元

plan先頭の軽1の判断に従い、LegacyDeclarationsInputの操作のlookupには、元署名のLegacyTypeInputに加え、辞書の添字の上限と写した引数列の先頭の一致を加えた。`LegacyDeclarationsInput.op_dictionaryInputs` がこの二条件を返す。実装の辞書型のvalue kindは既存のLegacyTypeInputの第一射影にあり、`impl_dictionaryKinds` が写した実際のdictTysの全要素へ渡す。後者に新しい入力条件は足していない。

```lean
def LegacyDeclarationsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop :=
  (∀ f fd, P0.defs f = some fd →
    LegacyTypeInput K P0 ⟨K.functionParams f, fd.tparams, 0, 0⟩
      (.fn fd.names fd.params fd.ret fd.eff) .value ∧
    LegacyCompInput K P0 B0 B ⟨K.functionParams f, fd.tparams, 0, fd.params.length⟩ fd.body) ∧
  (∀ o od, P0.ops o = some od →
    LegacyTypeInput K P0 ⟨List.replicate od.tparams.length .value, od.tparams, 0, 0⟩
      (.fn od.names od.params od.ret (Benitoite.Release.Eff.single od.eff)) .value ∧
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    (embedOpDecl od).params.take od.dictParams.length =
      od.dictParams.map (fun p => Ty.dict p.1 (.tvar p.2))) ∧
  (∀ cl cd m ms, P0.classes cl = some cd → cd.methods m = some ms →
    LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl], ms.tparams ++ [({} : Benitoite.Release.TParam)], 0, 0⟩
      (.fn ms.names ms.params ms.ret ms.eff) .value) ∧
  (∀ i id, P0.impls i = some id →
    LegacyTypeInput K P0 ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩
      id.target (K.classArgument id.cls) ∧
    (∀ a ∈ id.dictTys, LegacyTypeInput K P0
      ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩ a .value) ∧
    (∀ s v, id.supers s = some v → LegacyValueInput K P0 B0 B
      ⟨List.replicate id.tparams.length .value, id.tparams, 0, id.dictTys.length⟩ v) ∧
    (∀ cl m ms body, P0.classes id.cls = some cl → cl.methods m = some ms → id.methods m = some body →
      LegacyCompInput K P0 B0 B
        ⟨K.methodParams id.cls m ++ List.replicate id.tparams.length .value,
          ms.tparams ++ id.tparams, 0, id.dictTys.length + ms.params.length⟩ body))

/-- 操作の辞書の添字と先頭の一致を、宣言の形成へ渡す。 -/
theorem LegacyDeclarationsInput.op_dictionaryInputs {K P0 B0 B o od}
    (h : LegacyDeclarationsInput K P0 B0 B) (lookup : P0.ops o = some od) :
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    (embedOpDecl od).params.take od.dictParams.length =
      od.dictParams.map (fun p => Ty.dict p.1 (.tvar p.2)) :=
  (h.2.1 o od lookup).2

/-- 実装の辞書型の kind は既存の型入力から得る（設計書 01-12「旧判断の適格な入力」）。 -/
theorem LegacyDeclarationsInput.impl_dictionaryKinds {K P0 B0 B i id}
    (h : LegacyDeclarationsInput K P0 B0 B) (lookup : P0.impls i = some id) :
    ∀ a ∈ (embedImplDecl id).dictTys,
      a.HasKind (embedProgramWithKinds K P0)
        (List.replicate id.tparams.length .value) .value := by
  intro a ha
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp ha
  have oldMem : Benitoite.Release.Ty.dict p.1 (.tvar p.2) ∈ id.dictTys :=
    List.mem_map.mpr ⟨p, hp, rfl⟩
  exact ((h.2.2.2 i id lookup).2.1 _ oldMem).1

```

操作の辞書の先頭又は添字が不適格な旧プログラムは、宣言入力で新たに拒む。個々のLegacyOutputInputや旧七判断の範囲は変更していない。実装の辞書型のkindの範囲も従来どおりである。合法なソースの辞書挿入との一致を、この構造条件だけで証明したとはしない。G08/R10bで照合する。`boundary.lean` はrv-f-t3と同じbadOpの拒否、添字の拒否、正しい操作の受理と二条件の供給、実装の辞書型のkindの供給、クラスのない実装の拒否を示す。

## 空の局所文脈

旧 `LocalCtx.extend n [] = []` と新 `localExtend n []`（none が n 個）は一致しない。L20 の C_Let と腕の子では、`LocalCtx.Shift.empty 0 c (localExtend n [])` を用いる k=0 の局所文脈の移送を閉じる。shiftV_zero/shiftIndex_zero で値・型・効果の移動を消す。空でない L の場合も先頭の空の位置と参照の移動を照合する。

一般の HasTypeCQ.shift_values は Builtins.ValueAssumptions・StoreTy.WF・FullShiftMap・事実の含意を要求する。そのまま任意の旧埋め込みへ適用できたとはしない。入口から条件を供給できなければ、k=0 で局所文脈だけを変える補助を L20 で証明する。ValueAssumptions を新しい独立の埋め込み前提に加えない。本書は橋渡しの義務と入力を固定する段であり、この補助は未実装である。

## 旧読者12件の代替

不要43件は旧言明をそのまま新規則へ移さない処分であり、旧ファイルの削除ではない。次の12行は言明の種類で数え、複数の読者を重ねて件数へ加えない。新しい入口への全読者の追随は後段であり、L10 の foundation 残99件へ戻さない。

| 旧言明（O/） | 確認した旧読者/説明の参照 | 代替の担当 | 新しい入口・前提 |
|---|---|---|---|
| `Ty.wf_iff_old` | `Release/RangeInst.lean` | L20 G04 | R/Contextの四名前空間のWFとRangeSubstの範囲の移送を直接使う。旧WFとの同値を経由しない |
| `Ty.varsIn_iff_old` | `Release/RangeInst.lean`、`Surface/PrimRange.lean`、`Surface/DesugarRange.lean` | L20 G04／L70 | 型/行/範囲/値のscopeを直接分解。PrimRange/DesugarRangeの新しい署名のWF/RowsIn/Referencesの射影へ置換 |
| `Ty.varsInList_iff_old` | `Release/RangeInst.lean`、`Surface/PrimRange.lean`、`Surface/DesugarRange.lean` | L20 G04／L70 | 型列のWF/RowsIn/Referencesを要素ごとに射影し、旧型列との同値を使わない |
| `Eff.varsIn_iff_old` | `Release/RangeInst.lean`、`Surface/PrimRange.lean`、`Surface/DesugarRange.lean` | L20 G04／L70 | 新EffのRowsInとFail型のWF、範囲添字のWFを直接使う |
| `Ty.RangesIn.opaque` | `Release/RangeInst.lean` | L20 G04 | RangeIx.WFの射影と同じ添字のinstR/shiftRのscope保存を使う |
| `PrimSig.scoped_iff_old` | `Release/WellFormed.lean`、`Release/RangeInst.lean` | L20 G08／L70 | 新PrimSig.Scopedを定義し各成分を直接使う。旧ScopedOldとの同値は提供しない |
| `sig_scoped_iff_old_of_rangeFree` | `Release/RangeInst.lean` | L20 G08／L70 | 新sig_scopedの全量化と各実表の充足を直接供給。新表層の署名の入口も新Scopedへ切替 |
| `Ty.WF.raw` | `Release/RangeInst.lean`、`Release/TypeScopedSubst.lean`、`Release/Lemmas/Dict.lean`、`Release/Lemmas/TyLemmas.lean` | L20 G04 | L10.44/.45の像の条件付きbind/substのWFとProperApply/HasKindを使い、RawWF層を経由しない |
| `Ty.WFList.raw` | `Release/Lemmas/TyLemmas.lean` | L20 G04 | 上と同じ型列のWFの移送を使う。Dict/TyLemmasの適用にはKind/ProperApplyの入力を渡す |
| `Eff.WF.raw` | `Release/TypeScopedSubst.lean` | L20 G04 | 行の像とFail内部のWFから、正規化後のbind/substのWFへ直接進む |
| `Ty.norm_rawWF` | `Release/RangeInst.lean`、`Release/Lemmas/TyLemmas.lean` | L20 G04 | 新WFの正規化保存と、像のWFを前提にした代入後の形成で置換 |
| `Ty.WF.canonical` | `Release/RangeInst.lean`、`Release/HandlerTargetExamples.lean` | L20 G04／L70 | WFからCanonicalを結論しない。正規化した入口とnorm_idemを使い、元と同じ型へ戻す箇所は明示のNormalの証拠でつなぐ |


別枠として、旧 `Release/TypeSubstLemmas.lean` の Ty.norm_legacy/Eff.norm_legacy は旧 Legacy 層への橋である。新体系では norm/bind/shift の交換を直接使う。旧互換の読者を残す範囲の確定は L70 の担当である。

## 非継続の二読者の代替

| 旧読者 | 旧入力と使う経路 | 新しい供給元と送り先 |
|---|---|---|
| Lemmas/Preservation.closedArgs_of | VarsInListからClosedArgs（閉じたWFとNotCont）を得てE_Fun・E_Meth・E_Op・E_OpFailへ渡す | 新VarsInは非継続を含まない。関数・操作はSignatureInstance.typeScope、メソッドはmethod_body_typeScope、raiseはraise_typeScopeからWFとOrdinaryを取り出す。E_OpFailの結果型Tの単一の像[T]にはraise_subst_wf/raise_subst_leを供給する。G03で全本体への型置換へ接続 |
| Lemmas/PresBase.ClosedArgs.single | `.prim b [t] es rs` の旧VarsInからClosedArgs [t]を得る。PresMainのReferenceなどの遷移で型のWFと非継続を使う | V_PrimのSignatureInstance.typeScopeとPrimitiveAdmissible.typeScopeから一つの型像のWF/Ordinaryを得る。ReferencePreservationは強めたSignatureInstanceへ追随済み。一般の本体の型置換への接続はG03 |


Ordinary は篩を外した芯の最上位だけを読む。新 VarsIn は非継続を含まないので、旧 VarsIn から ClosedArgs を作る経路を復活させない。旧型の NotCont と embedTy 後の Ordinary の同値、および LegacyTypesInput.iff_of_notCont は、開いた型変数にも使える。入れ子の継続を再帰的に禁止しない。G03 では捕捉のある閉包、複数引数、全本体、tapp の Sorted/Declared と入れ子の像について型置換を接続する。

## embedStep の撤回と主な定理の前提

旧 E_Fun は `(d.body.substTy ts es).instantiate ws` へ進む。新 E_Fun は `Closure.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)` へ進み、embedState の Closure.pure と等しくない。E_Lam/E_Return/E_Meth も同じ理由で単純な一段可換性は要求から外れている。表の対応を増やしても等号にはならない。適格な型付けと状態の片方向の埋め込みは L20、新 Step の保存・進行・step_sound とモデル・表層・全比較は L70 である。一般の旧実行の模倣を LegacyRuntimeRelation という無検査の前提で置き換えない。

| 契約 | 引き継ぐ前提と結論 | 残る担当 |
|---|---|---|
| progress/preservation | Program.WellTyped の本体 TelBodyTy・kind/Annotation・検証済み変性・external、および格納済み宣言の WellFormed。任意の field_mono を仮定しない。Final/新Step と新StateTyの保存の結論を維持 | L20/L70 |
| effect_soundness/noLamNames/対象健全性 | CoreAssumptions と TargetAgreement、全ての有効なσ、必要な束縛と固定σ、型付き依存入力・外部三条件。sig_scoped だけは未移行 | G08/L50/L60/L70 |
| 型付け→ValueMeaning→Inhabits | P.WellTyped.variance から検証を供給。意味の所属を主定理の独立前提にしない。Exhaustive は P と a.norm を読み B/Γ/Φを追加しない | G09 |
| step_sound | 実装した新stepの各構成と新Stepの一致を示す。旧Stepの一段の行き先の等号へ変えない | L70 |
| 値・型移動/値置換/narrowing の主な十言明 | 既存の前提と結論を維持し、P付き部分型と追加したOrdinaryの規則へ追随済み。全型置換の完成とは分ける | G03/G04 |

## 表層の結果型・効果と静的な分岐の契約

以下はL70/R10b/R50へ渡す完了条件であり、旧型付けの七判断の埋め込みとは別の表層の契約である。今回これらのchecker/脱糖を実装した意味ではない。

| 義務 | 引き渡す契約 | 後段で確かめる証拠 |
|---|---|---|
| O037 | 表層checkerがΓ/Φの下で篩付きの結果型Aと効果εを受理したなら、その同じA・ε（規定の正規化を除き篩を落とさない）で脱糖後の計算を型付けする。literal/checker/脱糖の全経路を含む | L70の表層の型保存。carrierだけへの結論の弱化では受け入れない |
| O066 | 正規形を読む網羅性を表層へ接続しても、同じ篩付き結果型Aと効果εを保つ。静的な証拠の消去が実行の観測を変えない | L70/R50の表層・交換の全実証と消去の観測。旧→新の値/型の写しだけでは閉じない |
| O138 | Γのlen(l)=nとΦのn>0から、証明できる場合にscrutineeの非空Listの型を静的に合成する。unknownで腕を除かず、不可能腕にも名前・型構造・効果の検査を残す。証明不能を受理するための暗黙の動的検査を足さない | L30の有限の証明書、L70/R10bの静的合成、R50の受理/拒否と実行の対応。未証明は既定の拒否であり、実行時検査の挿入に替えない |

## 捕捉からの正則性と方式の適合

G04の残りは、捕捉の緩い三条件から結果のWF/Sorted/Declaredを供給する全正則性である。Ty.CaptureWF/CaptureSorted/CaptureDeclaredは継続の入力・結果の型を検査するが、潜在効果の条件を持たない。変更していないrv-f-t1のk0はCaptureWF 0 0 0を満たしてもWF 0 0 0を満たさない。CaptureWFをそのままTy.bind_wfの入力にしてはならない。

Ordinaryな束縛は `Ty.CaptureWF.ordinary` からWFへ戻す。継続の束縛はCaptureOkにあるImageOk.contLoc/contVar等の実際の型付き像とストア/継続の証拠から閉じた型の形成を供給する経路を確かめる。CaptureOkへ強いCtx.WFを追加せず、像の証拠を読む。`l10/s2/rv-s2-t2.lean` のclose_wf/ground_term/close_wf_groundは、WFな型とGroundな像についての試行の証拠であり、本番の全正則性の補題ではない。これらをG04の入力として写し、Sort/Declared、hide、局所構築器と継続の潜在効果への全接続を残す。

これはL20の最初の単位群で確かめる方式の適合の点である。G03の型置換・入れ子の継続の像、G09の意味への全接続、G10のパターン/網羅性と同じく、全帰納を進める前に形を確かめる。既定の前提から供給できなければ、強い捕捉条件や独立の信頼条件を足して続けず、定義・反例又は未証明の言明・代案・時間を示して停止する。全正則性は未確認である。

## 支持・近似・表層への接点

| 受渡し | 使う証拠と注意 | 残る担当 |
|---|---|---|
| 形成 | TypeBounds の WFImages、Ty/Eff/Tel.substAt_wf、Ty.bind_wf/Eff.bind_wf、TypeVariables の SourceScoped との一致。像の WF と Ordinary を分け、HasKind/ProperApply/Sorted/Declared の全接続は別に供給 | G03/G04 |
| 有限支持 | TypeSupport/FiniteSupport の Ty/型列/Eff/Tel の全再帰条件、normWith_* 一致。比較と正規化へ候補の支持を渡す。支持不足で Fail の異なる型が eq とされる可能性を隠さない | G07、L70 の有限APIの利用先 |
| fnView | fnViewWith?/foldFnWith を再使用。支持前提なし版の一般証明は未実施。現在の支持付きの定理を維持し、追加するか G07 で判断 | G07 |
| 近似 | normalToShared_iff の型一致、baseToShared_mem、Report.sharedFlow の明示 returned と mayFail の射影。constOK_toApprox の ∃ n だけから元の整数値との一致を仮定しない | L20/L40 H04、L70、R10b/R50 |
| 失敗 | normal の空・mayFailの複写を failed の意味の健全性と読まない。J04 の入力条件と接続が未確定 | L20/L40 |
| 値依存長 | month_exhaustive/empty_refinement_exhaustive/nonempty_exhaustive、length_refinement_coverage、HasTypeVQ.nonempty_from_entails、CaptureOk.variable_coverage。Γ の len(l)=n と Φ の n>0 からの静的な scrutinee 型の合成は未実装 | L30 の証明書、L70/R10b、R50 |
| パターン | 型置換（旧 Exhaustive.substAt 相当）と、v : a.norm から δ.map Ty.norm への束縛の型保存。rawへ戻すには形成を供給 | G03/G06、L70/R10b の P_Var/P_Refined/P_Convert 照合 |
| 変性の外側 | 元の辞書制約・公開境界の全収集と実表の一致。行変数を残すなら MetadataScoped の ne=0 を機械的に当てず収集と整合させる | L70/R10b |
| 観測の準備 | Declaredだけでは欄のsortを元へ反映できない。同じPの検証済みVarianceValidを使う（群Vのsort_reflect_aux） | L30/L40 |
| 効果を構成する補助 | 旧Surface/FiniteToolsのunion_support等を移植し、注釈/型/行/Tel/Fail内部を覆う支持を構成ごとに供給する | L70 |
| sortごとの対応 | [sort-correspondence.md](sort-correspondence.md)の全16行とmember/constructorIs/Booleanの表。WF/Sorted/Source/意味を区別する | L30/L40/L50 |
| 差分入力の費用 | 深い経路で Atom.code の桁数が増える。浅い入力から費用を確認し、支持不変量を読者へ渡す。符号順は今回変更しない | L70 |

各群の完全署名は [V](../v/signatures.md)・[X](../x/signatures.md)・[W](../w/signatures.md)・[K](../k/signatures.md)・[S前半](../s1/signatures.md)・[S後半](../s2/signatures.md)・[A](../a/signatures.md) を引き継ぐ。X の全 valueMeaning_sub と typed→ValueMeaning、状態の全保存、全宣言の埋め込みは、代表の成功から完了へ繰り上げない。
