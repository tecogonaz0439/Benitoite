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

次のコードは [handoff.lean](handoff.lean) の型検査した契約の全体である。七つの型付け・状態の命題を **Prop の定義** として置き、未証明定理や公理は置いていない。旧 HasType の前提は LegacyOutputInput.old からも得られるが、依頼の全署名と照合するため明記する。Arms の入口の観測は none、Φ は空であり、必要な強化は既存の事実の弱化で扱う。

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
      HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedVal v) (embedTy a)

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
      HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedVals vs) (embedTys ts)

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
      HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedVals vs) (embedTy a)

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
      HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (R.map embedTy)
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
      HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (R.map embedTy) none
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
      HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (R.map embedTy) (embedEff eb)
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
      HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

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

現在の kind・表・入力・葉・非継続・局所文脈の37署名は [handoff-output.txt](handoff-output.txt) に完全修飾名と暗黙引数を含めて印字した。七判断と状態の計8契約と三種の親判断を本番へ追加した意味ではない。

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
| 差分入力の費用 | 深い経路で Atom.code の桁数が増える。浅い入力から費用を確認し、支持不変量を読者へ渡す。符号順は今回変更しない | L70 |

各群の完全署名は [V](../v/signatures.md)・[X](../x/signatures.md)・[W](../w/signatures.md)・[K](../k/signatures.md)・[S前半](../s1/signatures.md)・[S後半](../s2/signatures.md)・[A](../a/signatures.md) を引き継ぐ。X の全 valueMeaning_sub と typed→ValueMeaning、状態の全保存、全宣言の埋め込みは、代表の成功から完了へ繰り上げない。
