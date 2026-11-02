# 群 O の完全署名

B_WORK: `428ed95f768f41d63cbc3353e2b21fca0bb88e42`。七つの契約と帰納の骨格を実装前に固定した。各単位の署名は実装と並行して記録し、最後に型検査の出力へ揃えた。再開1では `embedExhaustive` を旧型の `a.WF 0 nt` を受ける入口へ弱めた。内部の署名の変更と具体例は [results.md](results.md) に記録する。群 P は [value-signatures.md](value-signatures.md) に分ける。

## 七判断の契約

次の七つは全埋め込みの契約を表す `Prop` の定義であり、七つの全導出の埋め込みを証明した定理ではない。[contracts.lean](contracts.lean) で型検査する。表現可能性・対象保持・宣言の kind 表は、既存の各 Legacy 入力と `LegacyTables` に分けて明示する。実装した共通の結論は `LegacyJudgment.Embedded`、帰納の骨格は `LegacyOutputInput.induct_regular` である。再開1ではこの七契約を変更していない。

```lean
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
      ∀ Φ : List Pred, HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
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
      ∀ Φ : List Pred, HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
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
      ∀ Φ : List Pred, HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
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
      ∀ Φ : List Pred, HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
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
      ∀ Φ : List Pred, HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
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
      ∀ Φ : List Pred, HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
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
      ∀ Φ : List Pred, HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))
end
```

## 実装した公開宣言

[signatures-o.lean](signatures-o.lean) の `#check @宣言名` の出力である。七判断の `Embedded` の定義本体は [LegacyTyping.lean](../../../../formal/Benitoite/Release/Refinement/LegacyTyping.lean) に置く。

```lean
Benitoite.Release.Refinement.LegacyJudgment.Embedded : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program → Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.LegacyJudgment → Prop
@Benitoite.Release.Refinement.LegacyOutputInput.induct_regular : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {j : Benitoite.Release.Refinement.LegacyJudgment} {M : Benitoite.Release.Refinement.LegacyJudgment → Prop},
  Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B j →
    (∀ {j : Benitoite.Release.Refinement.LegacyJudgment}
        {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
        Benitoite.Release.Refinement.LegacyRule K P0 B0 j children →
          Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B j →
            (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
                Membership.mem.{0, 0} children child → Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B child) →
              (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
                  Membership.mem.{0, 0} children child → M child) →
                M j) →
      M j
@Benitoite.Release.Refinement.LegacyNodeTypes.annotation : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : Benitoite.Release.Refinement.KindCtx} {C : List.{0} Benitoite.Release.TParam}
  {nv : Nat} {as : List.{0} Benitoite.Release.Ty} {a : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeTypes K P0 κ C nv as →
    Membership.mem.{0, 0} as a →
      Eq.{1} (List.length.{0} κ) (List.length.{0} C) →
        ∀ (Γ : Benitoite.Release.Refinement.Ctx),
          Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
            (Benitoite.Release.Refinement.legacyTypeCtx C κ) Γ (Benitoite.Release.Refinement.embedTy a)
Benitoite.Release.Refinement.legacy_local_kind_shift : ∀ (b : Benitoite.Release.BuilderKind) (k c : Nat),
  Eq.{1}
    (Benitoite.Release.Refinement.renameKind (Benitoite.Release.Refinement.shiftIndex k c)
      (Benitoite.Release.Refinement.embedBuilderKind b))
    (Benitoite.Release.Refinement.embedBuilderKind b)
Benitoite.Release.Refinement.legacy_local_map : ∀ (L : Benitoite.Release.LocalCtx) (k c : Nat),
  Eq.{1}
    (List.map.{0, 0}
      (Option.map.{0, 0} (Benitoite.Release.Refinement.renameKind (Benitoite.Release.Refinement.shiftIndex k c)))
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind) L))
    (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind) L)
Benitoite.Release.Refinement.legacy_localExtend : ∀ (n : Nat) (L : Benitoite.Release.LocalCtx),
  Eq.{1}
    (Benitoite.Release.Refinement.localExtend n
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind) L))
    (HAppend.hAppend.{0, 0, 0} (List.replicate.{0} n none.{0})
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind) L))
Benitoite.Release.Refinement.legacy_local_shift : ∀ (n : Nat) (L : Benitoite.Release.LocalCtx),
  Benitoite.Release.Refinement.LocalCtx.Shift 0 0
    (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind)
      (Benitoite.Release.LocalCtx.extend n L))
    (Benitoite.Release.Refinement.localExtend n
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind) L))
@Benitoite.Release.Refinement.legacy_local_zero : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List.{0} Benitoite.Release.Refinement.Pred} {R : Option.{0} Benitoite.Release.Refinement.Ty}
  {m : Benitoite.Release.Refinement.Comp} {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {n : Nat} {L : Benitoite.Release.LocalCtx},
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R m a e
      (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind)
        (Benitoite.Release.LocalCtx.extend n L)) →
    Benitoite.Release.Refinement.HasTypeCQ P B Ψ Q C Γ Φ R m a e
      (Benitoite.Release.Refinement.localExtend n
        (List.map.{0, 0} (Option.map.{0, 0} Benitoite.Release.Refinement.embedBuilderKind) L))
Benitoite.Release.Refinement.legacy_eff_test : ∀ (e : Benitoite.Release.Eff) (x : Benitoite.Release.Refinement.Atom),
  Eq.{1} ((Benitoite.Release.Refinement.embedEff e).test x) (Benitoite.Release.Refinement.embedAtoms e.test x)
Benitoite.Release.Refinement.legacy_substAtoms : ∀ (es : List.{0} Benitoite.Release.Eff)
  (a : Benitoite.Release.Atom → Bool),
  Eq.{1} (Benitoite.Release.Refinement.embedAtoms (Benitoite.Release.Eff.substAtoms es a))
    (Benitoite.Release.Refinement.substAtoms (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es)
      (Benitoite.Release.Refinement.embedAtoms a))
Benitoite.Release.Refinement.legacy_rowFails : ∀ (es : List.{0} Benitoite.Release.Eff)
  (a : Benitoite.Release.Atom → Bool),
  Eq.{1} (Benitoite.Release.Refinement.embedTys (Benitoite.Release.Eff.rowFails es a))
    (Benitoite.Release.Refinement.rowFails (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es)
      (Benitoite.Release.Refinement.embedAtoms a))
Benitoite.Release.Refinement.legacy_ordinary : ∀ (a : Benitoite.Release.Ty),
  (∀ (b t : Benitoite.Release.Ty) (e : Benitoite.Release.EffR), Ne.{1} a (b.cont t e)) →
    Benitoite.Release.Refinement.Ordinary (Benitoite.Release.Refinement.embedTy a)
Benitoite.Release.Refinement.legacy_rawBind : ∀ (θ : Benitoite.Release.SubstEnv)
  (σ : Benitoite.Release.Refinement.SubstEnv),
  (∀ (i : Nat), Eq.{1} (Benitoite.Release.Refinement.embedTy (θ.types i)) (σ.types i)) →
    Eq.{1} σ.rows (List.map.{0, 0} Benitoite.Release.Refinement.embedEff θ.rows) →
      Eq.{1} σ.ranges List.nil.{0} →
        ∀ (a : Benitoite.Release.Ty),
          Eq.{1} (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.rawBind θ a))
            (Benitoite.Release.Refinement.Ty.rawBind σ (Benitoite.Release.Refinement.embedTy a))
Benitoite.Release.Refinement.legacy_rawBindTys : ∀ (θ : Benitoite.Release.SubstEnv)
  (σ : Benitoite.Release.Refinement.SubstEnv),
  (∀ (i : Nat), Eq.{1} (Benitoite.Release.Refinement.embedTy (θ.types i)) (σ.types i)) →
    Eq.{1} σ.rows (List.map.{0, 0} Benitoite.Release.Refinement.embedEff θ.rows) →
      Eq.{1} σ.ranges List.nil.{0} →
        ∀ (as : List.{0} Benitoite.Release.Ty),
          Eq.{1} (Benitoite.Release.Refinement.embedTys (Benitoite.Release.Ty.rawBindTys θ as))
            (Benitoite.Release.Refinement.rawBindTys σ (Benitoite.Release.Refinement.embedTys as))
Benitoite.Release.Refinement.legacy_rawBindEff : ∀ (θ : Benitoite.Release.SubstEnv)
  (σ : Benitoite.Release.Refinement.SubstEnv),
  (∀ (i : Nat), Eq.{1} (Benitoite.Release.Refinement.embedTy (θ.types i)) (σ.types i)) →
    Eq.{1} σ.rows (List.map.{0, 0} Benitoite.Release.Refinement.embedEff θ.rows) →
      Eq.{1} σ.ranges List.nil.{0} →
        ∀ (e : Benitoite.Release.Eff),
          Eq.{1} (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.rawBind θ e))
            (Benitoite.Release.Refinement.Eff.rawBind σ (Benitoite.Release.Refinement.embedEff e))
Benitoite.Release.Refinement.legacy_subst : ∀ (a : Benitoite.Release.Ty) (ts : List.{0} Benitoite.Release.Ty),
  Eq.{1} (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.subst ts List.nil.{0} a))
    (Benitoite.Release.Refinement.Ty.subst (Benitoite.Release.Refinement.embedTys ts) List.nil.{0}
      (Benitoite.Release.Refinement.embedTy a))
Benitoite.Release.Refinement.legacy_subst_rows : ∀ (a : Benitoite.Release.Ty) (ts : List.{0} Benitoite.Release.Ty)
  (es : List.{0} Benitoite.Release.Eff),
  Eq.{1} (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.subst ts es a))
    (Benitoite.Release.Refinement.Ty.subst (Benitoite.Release.Refinement.embedTys ts)
      (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es) (Benitoite.Release.Refinement.embedTy a))
Benitoite.Release.Refinement.legacy_shiftV : ∀ (a : Benitoite.Release.Ty) (k c : Nat),
  Eq.{1} (Benitoite.Release.Refinement.Ty.shiftV k c (Benitoite.Release.Refinement.embedTy a))
    (Benitoite.Release.Refinement.embedTy a)
Benitoite.Release.Refinement.legacy_shiftVTys : ∀ (as : List.{0} Benitoite.Release.Ty) (k c : Nat),
  Eq.{1} (Benitoite.Release.Refinement.shiftVTys k c (Benitoite.Release.Refinement.embedTys as))
    (Benitoite.Release.Refinement.embedTys as)
Benitoite.Release.Refinement.legacy_shiftVEff : ∀ (e : Benitoite.Release.Eff) (k c : Nat),
  Eq.{1} (Benitoite.Release.Refinement.Eff.shiftV k c (Benitoite.Release.Refinement.embedEff e))
    (Benitoite.Release.Refinement.embedEff e)
Benitoite.Release.Refinement.legacy_embedParameters : ∀ (ps : List.{0} Benitoite.Release.Ty),
  Eq.{1} (Benitoite.Release.Refinement.embedParameters ps) (Benitoite.Release.Refinement.embedTys ps)
Benitoite.Release.Refinement.legacy_signatureTel : ∀ (ns : List.{0} String) (ps : List.{0} Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff),
  Eq.{1}
    (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
      (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
    (Benitoite.Release.Refinement.Ty.toTel ns (Benitoite.Release.Refinement.embedTys ps)
      (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
Benitoite.Release.Refinement.legacy_annotation_context : ∀ (a : Benitoite.Release.Ty)
  {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ Δ : Benitoite.Release.Refinement.Ctx},
  Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.embedTy a) →
    Benitoite.Release.Refinement.Ty.Annotation P C Δ (Benitoite.Release.Refinement.embedTy a)
Benitoite.Release.Refinement.legacy_signatureTel_annotation : ∀ (ns : List.{0} String)
  (ps : List.{0} Benitoite.Release.Ty) (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff)
  {P : Benitoite.Release.Refinement.Program} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ : Benitoite.Release.Refinement.Ctx},
  Benitoite.Release.Refinement.Ty.Annotation P C Γ
      (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.fn ns ps r e)) →
    Benitoite.Release.Refinement.Ty.Annotation P C Γ
      (Benitoite.Release.Refinement.Ty.dependentFn
        (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
          (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e)))
Benitoite.Release.Refinement.legacy_substEff : ∀ (e : Benitoite.Release.Eff) (ts : List.{0} Benitoite.Release.Ty)
  (es : List.{0} Benitoite.Release.Eff),
  Eq.{1} (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.substAt 0 ts es e))
    (Benitoite.Release.Refinement.Eff.subst (Benitoite.Release.Refinement.embedTys ts)
      (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es) (Benitoite.Release.Refinement.embedEff e))
Benitoite.Release.Refinement.legacy_instantiatedTel : ∀ (ns : List.{0} String) (ps : List.{0} Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (ts : List.{0} Benitoite.Release.Ty)
  (es : List.{0} Benitoite.Release.Eff),
  Eq.{1}
    (Benitoite.Release.Refinement.instantiatedTel
      (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
        (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
      (Benitoite.Release.Refinement.embedTys ts) (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es))
    (Benitoite.Release.Refinement.signatureTel ns
      (Benitoite.Release.Refinement.embedTys (List.map.{0, 0} (Benitoite.Release.Ty.subst ts es) ps))
      (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.subst ts es r))
      (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.substAt 0 ts es e)))
Benitoite.Release.Refinement.legacy_instantiated_annotation : ∀ (ns : List.{0} String)
  (ps : List.{0} Benitoite.Release.Ty) (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff)
  (ts : List.{0} Benitoite.Release.Ty) (es : List.{0} Benitoite.Release.Eff) {P : Benitoite.Release.Refinement.Program}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx},
  Benitoite.Release.Refinement.Ty.Annotation P C Γ
      (Benitoite.Release.Refinement.embedTy (Benitoite.Release.fnTy ns ps r e ts es)) →
    Benitoite.Release.Refinement.Ty.Annotation P C Γ
      (Benitoite.Release.Refinement.Ty.dependentFn
        (Benitoite.Release.Refinement.instantiatedTel
          (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
            (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
          (Benitoite.Release.Refinement.embedTys ts) (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es)))
Benitoite.Release.Refinement.legacy_instantiated_norm : ∀ (ns : List.{0} String) (ps : List.{0} Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (ts : List.{0} Benitoite.Release.Ty)
  (es : List.{0} Benitoite.Release.Eff),
  Benitoite.Release.NamesWF ns ps →
    Eq.{1}
      (Benitoite.Release.Refinement.Ty.dependentFn
          (Benitoite.Release.Refinement.instantiatedTel
            (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
              (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
            (Benitoite.Release.Refinement.embedTys ts) (List.map.{0, 0} Benitoite.Release.Refinement.embedEff es))).norm
      (Benitoite.Release.Refinement.embedTy (Benitoite.Release.fnTy ns ps r e ts es)).norm
@Benitoite.Release.Refinement.legacy_wf : ∀ {nr nt nv : Nat} {a : Benitoite.Release.Ty},
  Benitoite.Release.Refinement.Ty.WF nr nt nv (Benitoite.Release.Refinement.embedTy a) → Benitoite.Release.Ty.WF nr nt a
@Benitoite.Release.Refinement.legacy_wfTys : ∀ {nr nt nv : Nat} {as : List.{0} Benitoite.Release.Ty},
  Benitoite.Release.Refinement.Ty.WFList nr nt nv (Benitoite.Release.Refinement.embedTys as) →
    Benitoite.Release.Ty.WFList nr nt as
@Benitoite.Release.Refinement.legacy_wfEff : ∀ {nr nt nv : Nat} {e : Benitoite.Release.Eff},
  Benitoite.Release.Refinement.Eff.WF nr nt nv (Benitoite.Release.Refinement.embedEff e) →
    Benitoite.Release.Eff.WF nr nt e
@Benitoite.Release.Refinement.LegacyTypeInput.at_values : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Δ : Benitoite.Release.Refinement.LegacyInputCtx} {a : Benitoite.Release.Ty}
  {k : Benitoite.Release.Refinement.TyKind},
  Benitoite.Release.Refinement.LegacyTypeInput K P0 Δ a k →
    ∀ (nv : Nat),
      Benitoite.Release.Refinement.LegacyTypeInput K P0
        { kinds := Δ.kinds, constraints := Δ.constraints, nr := Δ.nr, nv := nv } a k
@Benitoite.Release.Refinement.LegacyNodeContext.bindings : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {δ : List.{0} Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyNodeContext K P0 κ Ψ C (HAppend.hAppend.{0, 0, 0} (Benitoite.Release.binds δ) Γ) →
    ∀ (nv : Nat), Benitoite.Release.Refinement.LegacyNodeTypes K P0 κ C nv δ
@Benitoite.Release.Refinement.embedPatTy : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {p : Benitoite.Release.Pat} {a : Benitoite.Release.Ty} {δ : List.{0} Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.PatTy P0 p a δ →
      Benitoite.Release.Refinement.PatTy (Benitoite.Release.Refinement.embedProgramWithKinds K P0) p
        (Benitoite.Release.Refinement.embedTy a) (Benitoite.Release.Refinement.embedTys δ)
@Benitoite.Release.Refinement.embedPatTys : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {ps : List.{0} Benitoite.Release.Pat} {as δ : List.{0} Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.PatTys P0 ps as δ →
      Benitoite.Release.Refinement.PatTys (Benitoite.Release.Refinement.embedProgramWithKinds K P0) ps
        (Benitoite.Release.Refinement.embedTys as) (Benitoite.Release.Refinement.embedTys δ)
@Benitoite.Release.Refinement.legacy_selectSlots : ∀ {α : Type} (xs : List.{0} α) (slots : List.{0} Nat),
  Eq.{1} (Benitoite.Release.Refinement.selectSlots xs slots) (Benitoite.Release.selectSlots xs slots)
@Benitoite.Release.Refinement.embedAltsTy : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {alts : List.{0} Benitoite.Release.Alt} {a : Benitoite.Release.Ty} {δ : List.{0} Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.AltsTy P0 alts a δ →
      Benitoite.Release.Refinement.AltsTy (Benitoite.Release.Refinement.embedProgramWithKinds K P0) alts
        (Benitoite.Release.Refinement.embedTy a) (Benitoite.Release.Refinement.embedTys δ)
Benitoite.Release.Refinement.legacyPatternConst : Benitoite.Release.Refinement.Const → Benitoite.Release.Const
Benitoite.Release.Refinement.legacyPatternVal : Benitoite.Release.Refinement.Val → Benitoite.Release.Val
Benitoite.Release.Refinement.legacyPatternVals : List.{0} Benitoite.Release.Refinement.Val →
  List.{0} Benitoite.Release.Val
Benitoite.Release.Refinement.legacyPatternVals_eq_map : ∀ (vs : List.{0} Benitoite.Release.Refinement.Val),
  Eq.{1} (Benitoite.Release.Refinement.legacyPatternVals vs)
    (List.map.{0, 0} Benitoite.Release.Refinement.legacyPatternVal vs)
Benitoite.Release.Refinement.legacyPatternConst_type : ∀ (c : Benitoite.Release.Refinement.Const),
  Eq.{1} (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Refinement.legacyPatternConst c).type) c.type
Benitoite.Release.Refinement.legacy_matchVal : ∀ (p : Benitoite.Release.Pat) (v : Benitoite.Release.Refinement.Val),
  Eq.{1} (p.matchVal (Benitoite.Release.Refinement.legacyPatternVal v))
    (Option.map.{0, 0} Benitoite.Release.Refinement.legacyPatternVals (Benitoite.Release.Refinement.matchVal p v))
Benitoite.Release.Refinement.legacy_matchList : ∀ (ps : List.{0} Benitoite.Release.Pat)
  (vs : List.{0} Benitoite.Release.Refinement.Val),
  Eq.{1} (Benitoite.Release.Pat.matchList ps (Benitoite.Release.Refinement.legacyPatternVals vs))
    (Option.map.{0, 0} Benitoite.Release.Refinement.legacyPatternVals (Benitoite.Release.Refinement.matchList ps vs))
@Benitoite.Release.Refinement.legacy_inhabits : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {nt : Nat} {t : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.Inhabits (Benitoite.Release.Refinement.embedProgramWithKinds K P0) t v →
      ∀ (a : Benitoite.Release.Ty),
        Eq.{1} (Benitoite.Release.Refinement.embedTy a) t →
          Benitoite.Release.Ty.WF 0 nt a →
            Benitoite.Release.Inhabits P0 a (Benitoite.Release.Refinement.legacyPatternVal v)
@Benitoite.Release.Refinement.legacy_inhabitsAll : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {nt : Nat} {ts : List.{0} Benitoite.Release.Refinement.Ty} {vs : List.{0} Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.InhabitsAll (Benitoite.Release.Refinement.embedProgramWithKinds K P0) ts vs →
      ∀ (as : List.{0} Benitoite.Release.Ty),
        Eq.{1} (Benitoite.Release.Refinement.embedTys as) ts →
          Benitoite.Release.Ty.WFList 0 nt as →
            Benitoite.Release.InhabitsAll P0 as (Benitoite.Release.Refinement.legacyPatternVals vs)
@Benitoite.Release.Refinement.legacy_inhabitsEach : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {nt : Nat} {t : Benitoite.Release.Refinement.Ty} {vs : List.{0} Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Refinement.InhabitsEach (Benitoite.Release.Refinement.embedProgramWithKinds K P0) t vs →
      ∀ (a : Benitoite.Release.Ty),
        Eq.{1} (Benitoite.Release.Refinement.embedTy a) t →
          Benitoite.Release.Ty.WF 0 nt a →
            Benitoite.Release.InhabitsEach P0 a (Benitoite.Release.Refinement.legacyPatternVals vs)
@Benitoite.Release.Refinement.embedExhaustive : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {nt : Nat} {a : Benitoite.Release.Ty} {ps : List.{0} Benitoite.Release.Pat},
  Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
    Benitoite.Release.Ty.WF 0 nt a →
      Benitoite.Release.Exhaustive P0 a ps →
        Benitoite.Release.Refinement.Exhaustive (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
          (Benitoite.Release.Refinement.embedTy a) ps
Benitoite.Release.Refinement.LegacyPatternExamples.kinds : Benitoite.Release.Refinement.DeclarationKinds
Benitoite.Release.Refinement.LegacyPatternExamples.atDecl : Benitoite.Release.ConDecl
Benitoite.Release.Refinement.LegacyPatternExamples.unitOperation : Benitoite.Release.OpDecl
Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram : Benitoite.Release.Program
Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins : Benitoite.Release.Builtins
Benitoite.Release.Refinement.LegacyPatternExamples.builtins : Benitoite.Release.Refinement.Builtins
Benitoite.Release.Refinement.LegacyPatternExamples.tables : Benitoite.Release.Refinement.LegacyTables
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
Benitoite.Release.Refinement.LegacyPatternExamples.kinds_wf : Benitoite.Release.Refinement.LegacyPatternExamples.kinds.WF
  Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType : Benitoite.Release.Ty
Benitoite.Release.Refinement.LegacyPatternExamples.allList : Benitoite.Release.Pat
Benitoite.Release.Refinement.LegacyPatternExamples.list_input : Benitoite.Release.Refinement.LegacyNodeTypes
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  List.nil.{0} List.nil.{0} 0
  (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list List.nil.{0})
Benitoite.Release.Refinement.LegacyPatternExamples.list_coverage : Benitoite.Release.Refinement.Exhaustive
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list)
  (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.allList List.nil.{0})
Benitoite.Release.Refinement.LegacyPatternExamples.checkedAt_in_list : ∀ (r : Benitoite.Release.Refinement.RangeExpr)
  (snapshot : Option.{0} Benitoite.Release.Refinement.PathEnv) (target : Benitoite.Scope.Domain.Target)
  (request : Option.{0} Benitoite.Release.Refinement.Val),
  Exists.{1} fun p =>
    Membership.mem.{0, 0} (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.allList List.nil.{0}) p ∧
      Eq.{1}
        (Option.isSome.{0}
          (Benitoite.Release.Refinement.matchVal p
            (Benitoite.Release.Refinement.Val.list
              (List.cons.{0} (Benitoite.Release.Refinement.Val.checkedAt r snapshot target request) List.nil.{0}))))
        true
Benitoite.Release.Refinement.LegacyPatternExamples.nested_pattern : Benitoite.Release.Refinement.PatTy
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  (Benitoite.Release.Pat.list (List.cons.{0} Benitoite.Release.Pat.var List.nil.{0})
    (some.{0} Benitoite.Release.ListRest.bind) List.nil.{0})
  (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list)
  (Benitoite.Release.Refinement.embedTys
    (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType
      (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list List.nil.{0})))
Benitoite.Release.Refinement.LegacyPatternExamples.nested_alts : Benitoite.Release.Refinement.AltsTy
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  (List.cons.{0}
    {
      pat :=
        Benitoite.Release.Pat.list (List.cons.{0} Benitoite.Release.Pat.var List.nil.{0})
          (some.{0} Benitoite.Release.ListRest.bind) List.nil.{0},
      slots := List.cons.{0} 0 (List.cons.{0} 1 List.nil.{0}) }
    List.nil.{0})
  (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list)
  (Benitoite.Release.Refinement.embedTys
    (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType
      (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.opaqueType.list List.nil.{0})))
Benitoite.Release.Refinement.LegacyPatternExamples.atPattern : Benitoite.Release.Pat
Benitoite.Release.Refinement.LegacyPatternExamples.at_seven_bindings : ∀
  (detail : Benitoite.Release.Refinement.AtError),
  Eq.{1}
    (Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.LegacyPatternExamples.atPattern
      (Benitoite.Release.Refinement.Val.atError detail))
    (some.{0} detail.values)
Benitoite.Release.Refinement.LegacyPatternExamples.at_old_correspondence : ∀
  (detail : Benitoite.Release.Refinement.AtError),
  Eq.{1}
    (Benitoite.Release.Refinement.LegacyPatternExamples.atPattern.matchVal
      (Benitoite.Release.Refinement.legacyPatternVal (Benitoite.Release.Refinement.Val.atError detail)))
    (some.{0}
      (List.map.{0, 0} (fun s => Benitoite.Release.Val.const (Benitoite.Release.Const.string s)) detail.textFields))
Benitoite.Release.Refinement.LegacyPatternExamples.at_wrong_name : ∀ (detail : Benitoite.Release.Refinement.AtError),
  Eq.{1}
    (Benitoite.Release.Refinement.matchVal
      (Benitoite.Release.Pat.con "Other" (List.replicate.{0} 7 Benitoite.Release.Pat.var))
      (Benitoite.Release.Refinement.Val.atError detail))
    none.{0}
Benitoite.Release.Refinement.LegacyPatternExamples.at_wrong_arity : ∀ (detail : Benitoite.Release.Refinement.AtError),
  Eq.{1}
    (Benitoite.Release.Refinement.matchVal
      (Benitoite.Release.Pat.con "Scope.ScopeError.At" (List.replicate.{0} 6 Benitoite.Release.Pat.var))
      (Benitoite.Release.Refinement.Val.atError detail))
    none.{0}
Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque : Benitoite.Release.Ty
Benitoite.Release.Refinement.LegacyPatternExamples.old_range_exhaustive : ∀ (P0 : Benitoite.Release.Program),
  Benitoite.Release.Exhaustive P0 Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque List.nil.{0}
Benitoite.Release.Refinement.LegacyPatternExamples.new_range_not_exhaustive : ∀
  (P : Benitoite.Release.Refinement.Program),
  ¬Benitoite.Release.Refinement.Exhaustive P
      (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque) List.nil.{0}
Benitoite.Release.Refinement.LegacyPatternExamples.range_wf_rejected : ∀ (nt : Nat),
  ¬Benitoite.Release.Ty.WF 0 nt Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque
Benitoite.Release.Refinement.LegacyPatternExamples.range_input_rejected : ∀
  (K : Benitoite.Release.Refinement.DeclarationKinds) (P0 : Benitoite.Release.Program)
  (κ : Benitoite.Release.Refinement.KindCtx) (C : List.{0} Benitoite.Release.TParam) (nv : Nat),
  ¬Benitoite.Release.Refinement.LegacyNodeTypes K P0 κ C nv
      (List.cons.{0} Benitoite.Release.Refinement.LegacyPatternExamples.rangeOpaque List.nil.{0})
```
