# 群 Q・R の完全署名

再開1の既定 import から `#check @宣言名` で全引数・証拠の添字を印字した。型検査の入力は [signatures-main.lean](signatures-main.lean)。主入口の前提は `DeclarationKinds.WF`・`LegacyTables`・`LegacyOutputInput` である。表現可能性・対象保持は node の入力、宣言の kind と表の対応は先の二前提で検査する。旧状態の入力には新しい型付け・遷移の結論を置かない。

再開1では LegacyCellInput の used の定義を `∃ b t e r, Ψ l = some (.cont b t e r)` とした。型の署名は同じであり、重複する LegacyLocInput の欄だけを外した。

```lean
@Benitoite.Release.Refinement.LegacyRule.embed_comp : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx}
  {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyRule K P0 B0 (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L)
      children →
    K.WF P0 →
      Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
        Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
            (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
          (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
              @Membership.mem.{0, 0} Benitoite.Release.Refinement.LegacyJudgment
                  (List.{0} Benitoite.Release.Refinement.LegacyJudgment)
                  (@List.instMembership.{0} Benitoite.Release.Refinement.LegacyJudgment) children child →
                Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B child) →
            (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
                @Membership.mem.{0, 0} Benitoite.Release.Refinement.LegacyJudgment
                    (List.{0} Benitoite.Release.Refinement.LegacyJudgment)
                    (@List.instMembership.{0} Benitoite.Release.Refinement.LegacyJudgment) children child →
                  Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B child) →
              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
                (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L)
@Benitoite.Release.Refinement.LegacyRule.embed_arms : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {xs : List.{0} Benitoite.Release.Arm} {a b : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx}
  {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyRule K P0 B0
      (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R xs a b e L) children →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R xs a b e L) →
        (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
            @Membership.mem.{0, 0} Benitoite.Release.Refinement.LegacyJudgment
                (List.{0} Benitoite.Release.Refinement.LegacyJudgment)
                (@List.instMembership.{0} Benitoite.Release.Refinement.LegacyJudgment) children child →
              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B child) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R xs a b e L)
@Benitoite.Release.Refinement.LegacyRule.embed_clauses : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {eb : Benitoite.Release.Eff} {cs : List.{0} Benitoite.Release.Clause}
  {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx}
  {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyRule K P0 B0
      (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb cs a e L) children →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb cs a e L) →
        (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
            @Membership.mem.{0, 0} Benitoite.Release.Refinement.LegacyJudgment
                (List.{0} Benitoite.Release.Refinement.LegacyJudgment)
                (@List.instMembership.{0} Benitoite.Release.Refinement.LegacyJudgment) children child →
              Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B child) →
          Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
            (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb cs a e L)
@Benitoite.Release.Refinement.LegacyRule.embed_failure : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {κ : Benitoite.Release.Refinement.KindCtx} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {E : Benitoite.Release.Ty}
  {R : Option.{0} Benitoite.Release.Ty} {cs : List.{0} Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx}
  {children : List.{0} Benitoite.Release.Refinement.LegacyJudgment},
  Benitoite.Release.Refinement.LegacyRule K P0 B0
      (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R cs a e L) children →
    Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R cs a e L) →
      (∀ (child : Benitoite.Release.Refinement.LegacyJudgment),
          @Membership.mem.{0, 0} Benitoite.Release.Refinement.LegacyJudgment
              (List.{0} Benitoite.Release.Refinement.LegacyJudgment)
              (@List.instMembership.{0} Benitoite.Release.Refinement.LegacyJudgment) children child →
            Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B child) →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B
          (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R cs a e L)
@Benitoite.Release.Refinement.LegacyOutputInput.embed : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {j : Benitoite.Release.Refinement.LegacyJudgment},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B j →
        Benitoite.Release.Refinement.LegacyJudgment.Embedded K P0 B j
@Benitoite.Release.Refinement.embedHasTypeVQ : ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {v : Benitoite.Release.Val}
  {a : Benitoite.Release.Ty} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
        ∀ (Φ : List.{0} Benitoite.Release.Refinement.Pred),
          Benitoite.Release.Refinement.HasTypeVQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            Φ (Benitoite.Release.Refinement.embedVal v) (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.embedHasTypeVQ_empty : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty}
  (K : Benitoite.Release.Refinement.DeclarationKinds) (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value κ Ψ Q C Γ v a) →
        Benitoite.Release.Refinement.HasTypeVQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (@List.nil.{0} Benitoite.Release.Refinement.Pred) (Benitoite.Release.Refinement.embedVal v)
          (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.embedHasTypeVsQ : ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {vs : List.{0} Benitoite.Release.Val} {ts : List.{0} Benitoite.Release.Ty}
  (K : Benitoite.Release.Refinement.DeclarationKinds) (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ vs ts) →
        ∀ (Φ : List.{0} Benitoite.Release.Refinement.Pred),
          Benitoite.Release.Refinement.HasTypeVsQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            Φ (Benitoite.Release.Refinement.embedVals vs) (Benitoite.Release.Refinement.embedTys ts)
@Benitoite.Release.Refinement.embedHasTypeVsQ_empty : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {vs : List.{0} Benitoite.Release.Val}
  {ts : List.{0} Benitoite.Release.Ty} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.values κ Ψ Q C Γ vs ts) →
        Benitoite.Release.Refinement.HasTypeVsQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (@List.nil.{0} Benitoite.Release.Refinement.Pred) (Benitoite.Release.Refinement.embedVals vs)
          (Benitoite.Release.Refinement.embedTys ts)
@Benitoite.Release.Refinement.embedHasTypeEachQ : ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {vs : List.{0} Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ vs a) →
        ∀ (Φ : List.{0} Benitoite.Release.Refinement.Pred),
          Benitoite.Release.Refinement.HasTypeEachQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            Φ (Benitoite.Release.Refinement.embedVals vs) (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.embedHasTypeEachQ_empty : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {vs : List.{0} Benitoite.Release.Val} {a : Benitoite.Release.Ty}
  (K : Benitoite.Release.Refinement.DeclarationKinds) (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.each κ Ψ Q C Γ vs a) →
        Benitoite.Release.Refinement.HasTypeEachQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (@List.nil.{0} Benitoite.Release.Refinement.Pred) (Benitoite.Release.Refinement.embedVals vs)
          (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.embedHasTypeCQ : ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
        ∀ (Φ : List.{0} Benitoite.Release.Refinement.Pred),
          Benitoite.Release.Refinement.HasTypeCQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            Φ
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy R)
            (Benitoite.Release.Refinement.embedComp m) (Benitoite.Release.Refinement.embedTy a)
            (Benitoite.Release.Refinement.embedEff e)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
              (Option.{0} Benitoite.Release.Refinement.BuilderKind)
              (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
                Benitoite.Release.Refinement.embedBuilderKind)
              L)
@Benitoite.Release.Refinement.embedHasTypeCQ_empty : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {R : Option.{0} Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
  {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx}
  (K : Benitoite.Release.Refinement.DeclarationKinds) (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.comp κ Ψ Q C Γ R m a e L) →
        Benitoite.Release.Refinement.HasTypeCQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (@List.nil.{0} Benitoite.Release.Refinement.Pred)
          (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy
            R)
          (Benitoite.Release.Refinement.embedComp m) (Benitoite.Release.Refinement.embedTy a)
          (Benitoite.Release.Refinement.embedEff e)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
            (Option.{0} Benitoite.Release.Refinement.BuilderKind)
            (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
              Benitoite.Release.Refinement.embedBuilderKind)
            L)
@Benitoite.Release.Refinement.embedHasTypeArmsQ : ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : List.{0} Benitoite.Release.TParam} {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)}
  {R : Option.{0} Benitoite.Release.Ty} {xs : List.{0} Benitoite.Release.Arm} {a b : Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R xs a b e L) →
        ∀ (Φ : List.{0} Benitoite.Release.Refinement.Pred),
          Benitoite.Release.Refinement.HasTypeArmsQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            Φ
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy R)
            (@Option.none.{0} Benitoite.Release.Refinement.Term) (Benitoite.Release.Refinement.embedArms xs)
            (Benitoite.Release.Refinement.embedTy a) (Benitoite.Release.Refinement.embedTy b)
            (Benitoite.Release.Refinement.embedEff e)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
              (Option.{0} Benitoite.Release.Refinement.BuilderKind)
              (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
                Benitoite.Release.Refinement.embedBuilderKind)
              L)
@Benitoite.Release.Refinement.embedHasTypeArmsQ_empty : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {R : Option.{0} Benitoite.Release.Ty}
  {xs : List.{0} Benitoite.Release.Arm} {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {L : Benitoite.Release.LocalCtx} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.arms κ Ψ Q C Γ R xs a b e L) →
        Benitoite.Release.Refinement.HasTypeArmsQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (@List.nil.{0} Benitoite.Release.Refinement.Pred)
          (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy
            R)
          (@Option.none.{0} Benitoite.Release.Refinement.Term) (Benitoite.Release.Refinement.embedArms xs)
          (Benitoite.Release.Refinement.embedTy a) (Benitoite.Release.Refinement.embedTy b)
          (Benitoite.Release.Refinement.embedEff e)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
            (Option.{0} Benitoite.Release.Refinement.BuilderKind)
            (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
              Benitoite.Release.Refinement.embedBuilderKind)
            L)
@Benitoite.Release.Refinement.embedHasTypeClausesQ : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {R : Option.{0} Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
  {cs : List.{0} Benitoite.Release.Clause} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {L : Benitoite.Release.LocalCtx} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb cs a e L) →
        ∀ (Φ : List.{0} Benitoite.Release.Refinement.Pred),
          Benitoite.Release.Refinement.HasTypeClausesQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            Φ
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy R)
            (Benitoite.Release.Refinement.embedEff eb) (Benitoite.Release.Refinement.embedClauses cs)
            (Benitoite.Release.Refinement.embedTy a) (Benitoite.Release.Refinement.embedEff e)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
              (Option.{0} Benitoite.Release.Refinement.BuilderKind)
              (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
                Benitoite.Release.Refinement.embedBuilderKind)
              L)
@Benitoite.Release.Refinement.embedHasTypeClausesQ_empty : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {R : Option.{0} Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
  {cs : List.{0} Benitoite.Release.Clause} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {L : Benitoite.Release.LocalCtx} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.clauses κ Ψ Q C Γ R eb cs a e L) →
        Benitoite.Release.Refinement.HasTypeClausesQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (@List.nil.{0} Benitoite.Release.Refinement.Pred)
          (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy
            R)
          (Benitoite.Release.Refinement.embedEff eb) (Benitoite.Release.Refinement.embedClauses cs)
          (Benitoite.Release.Refinement.embedTy a) (Benitoite.Release.Refinement.embedEff e)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
            (Option.{0} Benitoite.Release.Refinement.BuilderKind)
            (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
              Benitoite.Release.Refinement.embedBuilderKind)
            L)
@Benitoite.Release.Refinement.embedHasFailureClause : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {E : Benitoite.Release.Ty} {R : Option.{0} Benitoite.Release.Ty}
  {cs : List.{0} Benitoite.Release.Clause} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {L : Benitoite.Release.LocalCtx} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R cs a e L) →
        ∀ (Φ : List.{0} Benitoite.Release.Refinement.Pred),
          Benitoite.Release.Refinement.HasFailureClause (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
              (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
                Benitoite.Release.Refinement.embedTy)
              Γ)
            Φ (Benitoite.Release.Refinement.embedTy E)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy R)
            (Benitoite.Release.Refinement.embedClauses cs) (Benitoite.Release.Refinement.embedTy a)
            (Benitoite.Release.Refinement.embedEff e)
            (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
              (Option.{0} Benitoite.Release.Refinement.BuilderKind)
              (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
                Benitoite.Release.Refinement.embedBuilderKind)
              L)
@Benitoite.Release.Refinement.embedHasFailureClause_empty : ∀ {P0 : Benitoite.Release.Program}
  {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : List.{0} Benitoite.Release.TParam}
  {Γ : List.{0} (Option.{0} Benitoite.Release.Ty)} {E : Benitoite.Release.Ty} {R : Option.{0} Benitoite.Release.Ty}
  {cs : List.{0} Benitoite.Release.Clause} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {L : Benitoite.Release.LocalCtx} (K : Benitoite.Release.Refinement.DeclarationKinds)
  (κ : Benitoite.Release.Refinement.KindCtx),
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.failure κ Ψ Q C Γ E R cs a e L) →
        Benitoite.Release.Refinement.HasFailureClause (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Q (Benitoite.Release.Refinement.legacyTypeCtx C κ)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.Ty) (Option.{0} Benitoite.Release.Refinement.Ty)
            (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty
              Benitoite.Release.Refinement.embedTy)
            Γ)
          (@List.nil.{0} Benitoite.Release.Refinement.Pred) (Benitoite.Release.Refinement.embedTy E)
          (@Option.map.{0, 0} Benitoite.Release.Ty Benitoite.Release.Refinement.Ty Benitoite.Release.Refinement.embedTy
            R)
          (Benitoite.Release.Refinement.embedClauses cs) (Benitoite.Release.Refinement.embedTy a)
          (Benitoite.Release.Refinement.embedEff e)
          (@List.map.{0, 0} (Option.{0} Benitoite.Release.BuilderKind)
            (Option.{0} Benitoite.Release.Refinement.BuilderKind)
            (@Option.map.{0, 0} Benitoite.Release.BuilderKind Benitoite.Release.Refinement.BuilderKind
              Benitoite.Release.Refinement.embedBuilderKind)
            L)
Benitoite.Release.Refinement.LegacyClosedCompInput : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program →
    Benitoite.Release.Builtins →
      Benitoite.Release.Refinement.Builtins →
        Benitoite.Release.StoreTy →
          List.{0} (Option.{0} Benitoite.Release.Ty) →
            Option.{0} Benitoite.Release.Ty →
              Benitoite.Release.Comp → Benitoite.Release.Ty → Benitoite.Release.Eff → Prop
Benitoite.Release.Refinement.LegacyContRegular : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program →
    Benitoite.Release.StoreTy →
      Option.{0} Benitoite.Release.Ty →
        Benitoite.Release.Eff →
          Benitoite.Release.Ty → Benitoite.Release.Ty → Benitoite.Release.Eff → Option.{0} Benitoite.Release.Ty → Prop
Benitoite.Release.Refinement.LegacyContInput : Benitoite.Release.Refinement.DeclarationKinds →
  (P0 : Benitoite.Release.Program) →
    (B0 : Benitoite.Release.Builtins) →
      Benitoite.Release.Refinement.Builtins →
        (Ψ : Benitoite.Release.StoreTy) →
          {R : Option.{0} Benitoite.Release.Ty} →
            {e : Benitoite.Release.Eff} →
              {k : Benitoite.Release.Cont} →
                {a b : Benitoite.Release.Ty} →
                  {out : Benitoite.Release.Eff} →
                    {Re : Option.{0} Benitoite.Release.Ty} → Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re → Prop
Benitoite.Release.Refinement.LegacyBuilderContentsInput : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program →
    Benitoite.Release.Builtins →
      Benitoite.Release.Refinement.Builtins → Benitoite.Release.StoreTy → Benitoite.Release.BuilderContents → Prop
Benitoite.Release.Refinement.LegacyCellInput : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program →
    Benitoite.Release.Builtins →
      Benitoite.Release.Refinement.Builtins → Benitoite.Release.StoreTy → Nat → Benitoite.Release.Cell → Prop
Benitoite.Release.Refinement.LegacyStoreInput : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program →
    Benitoite.Release.Builtins →
      Benitoite.Release.Refinement.Builtins → Benitoite.Release.StoreTy → Benitoite.Release.Store → Prop
Benitoite.Release.Refinement.LegacyStateInput : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program →
    Benitoite.Release.Builtins →
      Benitoite.Release.Refinement.Builtins → Benitoite.Release.Eff → Benitoite.Release.State → Prop
@Benitoite.Release.Refinement.LegacyStateInput.old : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Eb : Benitoite.Release.Eff} {s : Benitoite.Release.State},
  Benitoite.Release.Refinement.LegacyStateInput K P0 B0 B Eb s → Benitoite.Release.StateTyE P0 B0 Eb s
@Benitoite.Release.Refinement.LegacyContInput.empty : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {a : Benitoite.Release.Ty} {out : Benitoite.Release.Eff} {hs : e.Sub out}
  {hw :
    Benitoite.Release.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) a},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R e a a out R →
    @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e (@List.nil.{0} Benitoite.Release.Frame) a a out R
      (@Benitoite.Release.ContTy.K_Empty P0 B0 Ψ R e a out hs hw)
@Benitoite.Release.Refinement.LegacyContInput.letFrame : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {n : Benitoite.Release.Comp} {k : Benitoite.Release.Cont} {a c b : Benitoite.Release.Ty}
  {out e1 : Benitoite.Release.Eff} {Re : Option.{0} Benitoite.Release.Ty}
  {ht :
    Benitoite.Release.HasTypeC P0 B0 Ψ (@List.nil.{0} Benitoite.Release.TParam)
      (@List.cons.{0} (Option.{0} Benitoite.Release.Ty) (@Option.some.{0} Benitoite.Release.Ty a)
        (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)))
      R n c e1}
  {hw :
    Benitoite.Release.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) a}
  {hs : e1.Sub e} {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k c b out Re},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R e a b out Re →
    Benitoite.Release.Refinement.LegacyClosedCompInput K P0 B0 B Ψ
        (@List.cons.{0} (Option.{0} Benitoite.Release.Ty) (@Option.some.{0} Benitoite.Release.Ty a)
          (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)))
        R n c e1 →
      @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k c b out Re hk →
        @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e
          (@List.cons.{0} Benitoite.Release.Frame (Benitoite.Release.Frame.letF n) k) a b out Re
          (@Benitoite.Release.ContTy.K_Let P0 B0 Ψ R e n k a c b out e1 Re ht hw hs hk)
@Benitoite.Release.Refinement.LegacyContInput.mark : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {k : Benitoite.Release.Cont} {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option.{0} Benitoite.Release.Ty} {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re}
  {hw :
    Benitoite.Release.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) a},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ (@Option.some.{0} Benitoite.Release.Ty a) e a b out Re →
    @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k a b out Re hk →
      @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ (@Option.some.{0} Benitoite.Release.Ty a) e
        (@List.cons.{0} Benitoite.Release.Frame Benitoite.Release.Frame.mark k) a b out Re
        (@Benitoite.Release.ContTy.K_Mark P0 B0 Ψ R e k a b out Re hk hw)
@Benitoite.Release.Refinement.LegacyContInput.update : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {l : Nat}
  {k : Benitoite.Release.Cont} {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option.{0} Benitoite.Release.Ty}
  {hl :
    @Eq.{1} (Option.{0} Benitoite.Release.LocTy) (Ψ l)
      (@Option.some.{0} Benitoite.Release.LocTy (Benitoite.Release.LocTy.lazy a))}
  {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ (@Option.none.{0} Benitoite.Release.Ty) e a b out Re →
    @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k a b out Re hk →
      @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ (@Option.none.{0} Benitoite.Release.Ty) e
        (@List.cons.{0} Benitoite.Release.Frame (Benitoite.Release.Frame.update l) k) a b out Re
        (@Benitoite.Release.ContTy.K_Update P0 B0 Ψ R e l k a b out Re hl hk)
@Benitoite.Release.Refinement.LegacyContInput.release : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {v : Benitoite.Release.Val} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Release.Cont}
  {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff} {Re : Option.{0} Benitoite.Release.Ty}
  {hv :
    Benitoite.Release.HasTypeV P0 B0 Ψ (@List.nil.{0} Benitoite.Release.TParam)
      (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) v (Benitoite.Release.Ty.opaqueTop o)}
  {hr : @Eq.{1} Bool (B0.isResource o) Bool.true}
  {hs : e.mem (Benitoite.Release.Atom.nameTop Benitoite.Release.stateEff)}
  {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R e a b out Re →
    Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.value (@List.nil.{0} Benitoite.Release.Refinement.TyKind) Ψ
          Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.TParam)
          (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) v (Benitoite.Release.Ty.opaqueTop o)) →
      (Benitoite.Release.Refinement.embedVal v).Ground →
        @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k a b out Re hk →
          @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e
            (@List.cons.{0} Benitoite.Release.Frame (Benitoite.Release.Frame.release v) k) a b out Re
            (@Benitoite.Release.ContTy.K_Release P0 B0 Ψ R e v o k a b out Re hv hr hs hk)
@Benitoite.Release.Refinement.LegacyContInput.handle : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e ec eb : Benitoite.Release.Eff}
  {cs : List.{0} Benitoite.Release.Clause} {k : Benitoite.Release.Cont} {t b : Benitoite.Release.Ty}
  {out : Benitoite.Release.Eff} {Re : Option.{0} Benitoite.Release.Ty}
  {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k t b out Re} {hc : e.Covers ec}
  {hs : eb.Sub (ec.union (Benitoite.Release.handled P0 B0 cs))}
  {ht :
    Benitoite.Release.HasTypeClauses P0 B0 Ψ.hideBuilders (@List.nil.{0} Benitoite.Release.TParam)
      (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) R eb cs t ec}
  {hw :
    Benitoite.Release.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R eb t b out Re →
    Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.clauses (@List.nil.{0} Benitoite.Release.Refinement.TyKind)
          Ψ.hideBuilders Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.TParam)
          (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) R eb cs t ec
          (@List.nil.{0} (Option.{0} Benitoite.Release.BuilderKind))) →
      Benitoite.Release.Refinement.Clause.ClosedList (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
          (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) (Benitoite.Release.Refinement.embedClauses cs) →
        @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k t b out Re hk →
          @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R eb
            (@List.cons.{0} Benitoite.Release.Frame (Benitoite.Release.Frame.handleF cs) k) t b out Re
            (@Benitoite.Release.ContTy.K_Handle P0 B0 Ψ R e ec eb cs k t b out Re hk hc hs ht hw)
@Benitoite.Release.Refinement.LegacyContInput.handleFail : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e ec rest : Benitoite.Release.Eff}
  {E : Benitoite.Release.Ty} {cs : List.{0} Benitoite.Release.Clause} {k : Benitoite.Release.Cont}
  {t b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff} {Re : Option.{0} Benitoite.Release.Ty}
  {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k t b out Re} {hc : e.Covers rest}
  {hn : Benitoite.Release.NoFail Benitoite.Release.Qempty rest}
  {ht :
    Benitoite.Release.HasFailureClause P0 B0 Ψ.hideBuilders Benitoite.Release.Qempty
      (@List.nil.{0} Benitoite.Release.TParam) (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) E R cs t ec
      (@List.nil.{0} (Option.{0} Benitoite.Release.BuilderKind))}
  {hc' : e.Covers ec}
  {hw :
    Benitoite.Release.Ty.WF (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R ((Benitoite.Release.Eff.singleFail E).union rest) t b out Re →
    Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
        (Benitoite.Release.Refinement.LegacyJudgment.failure (@List.nil.{0} Benitoite.Release.Refinement.TyKind)
          Ψ.hideBuilders Benitoite.Release.Qempty (@List.nil.{0} Benitoite.Release.TParam)
          (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) E R cs t ec
          (@List.nil.{0} (Option.{0} Benitoite.Release.BuilderKind))) →
      Benitoite.Release.Refinement.Clause.ClosedList (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
          (@OfNat.ofNat.{0} Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) (Benitoite.Release.Refinement.embedClauses cs) →
        @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k t b out Re hk →
          @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R ((Benitoite.Release.Eff.singleFail E).union rest)
            (@List.cons.{0} Benitoite.Release.Frame (Benitoite.Release.Frame.handleF cs) k) t b out Re
            (@Benitoite.Release.ContTy.K_Handle_Fail P0 B0 Ψ R e ec rest E cs k t b out Re hk hc hn ht hc' hw)
@Benitoite.Release.Refinement.LegacyContInput.drop : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {i : Nat}
  {k : Benitoite.Release.Cont} {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option.{0} Benitoite.Release.Ty} {b' t' : Benitoite.Release.Ty} {e' : Benitoite.Release.Eff}
  {R' : Option.{0} Benitoite.Release.Ty}
  {hl :
    @Eq.{1} (Option.{0} Benitoite.Release.LocTy) (Ψ i)
      (@Option.some.{0} Benitoite.Release.LocTy (Benitoite.Release.LocTy.cont b' t' e' R'))}
  {hs :
    e'.mem (Benitoite.Release.Atom.nameTop Benitoite.Release.stateEff) →
      e.mem (Benitoite.Release.Atom.nameTop Benitoite.Release.stateEff)}
  {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R e a b out Re →
    @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k a b out Re hk →
      @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e
        (@List.cons.{0} Benitoite.Release.Frame (Benitoite.Release.Frame.drop i) k) a b out Re
        (@Benitoite.Release.ContTy.K_Drop P0 B0 Ψ R e i k a b out Re b' t' e' R' hl hs hk)
@Benitoite.Release.Refinement.LegacyContInput.guard : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {v : Benitoite.Release.Val} {arms : List.{0} Benitoite.Release.Arm} {next : Nat} {m : Benitoite.Release.Comp}
  {k : Benitoite.Release.Cont} {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option.{0} Benitoite.Release.Ty} {e1 : Benitoite.Release.Eff}
  {ht :
    Benitoite.Release.HasTypeC P0 B0 Ψ (@List.nil.{0} Benitoite.Release.TParam)
      (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) R (Benitoite.Release.Comp.match v arms) a e1}
  {hs : e1.Sub e} {hp : Benitoite.Release.MatchPrefix v arms next}
  {hm :
    Benitoite.Release.HasTypeC P0 B0 Ψ (@List.nil.{0} Benitoite.Release.TParam)
      (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) R m a e1}
  {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ (@Option.none.{0} Benitoite.Release.Ty)
      Benitoite.Release.Eff.empty (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.boolean) b out Re →
    Benitoite.Release.Refinement.LegacyClosedCompInput K P0 B0 B Ψ (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) R
        (Benitoite.Release.Comp.match v arms) a e1 →
      Benitoite.Release.Refinement.LegacyClosedCompInput K P0 B0 B Ψ (@List.nil.{0} (Option.{0} Benitoite.Release.Ty)) R
          m a e1 →
        @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k a b out Re hk →
          @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ (@Option.none.{0} Benitoite.Release.Ty)
            Benitoite.Release.Eff.empty
            (@List.cons.{0} Benitoite.Release.Frame (Benitoite.Release.Frame.guardF v arms next m) k)
            (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.boolean) b out Re
            (@Benitoite.Release.ContTy.K_Guard P0 B0 Ψ R e v arms next m k a b out Re e1 ht hs hp hm hk)
@Benitoite.Release.Refinement.LegacyContInput.sub : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option.{0} Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {k : Benitoite.Release.Cont} {a a' b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option.{0} Benitoite.Release.Ty} {hk : Benitoite.Release.ContTy P0 B0 Ψ R e k a' b out Re} {hs : a.Le a'},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R e a b out Re →
    @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k a' b out Re hk →
      @Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ R e k a b out Re
        (@Benitoite.Release.ContTy.K_Sub P0 B0 Ψ R e k a a' b out Re hk hs)
```
