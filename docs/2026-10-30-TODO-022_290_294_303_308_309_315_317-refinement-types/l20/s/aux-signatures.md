# 再開1の最終署名の照合

[signatures.md](signatures.md) に先に記した署名と、最終の125手書き宣言の型を照合する。private の完全名は [declarations.json](declarations.json) に保存した。末尾の ✝ は Lean が private 名を表示するときの印である。印字の台本は [signatures.lean](signatures.lean) であり、既定の Benitoite を import して検査する。

HeldTyped の motive の実体は次のとおりである。値・二つの列以外の成分は True とし、七判断の型付けの帰納を作り直さない。

```lean
private def HeldTyped (K : DeclarationKinds) (P0 : Benitoite.Release.Program) (B : Builtins) : LegacyJudgment → Prop
  | .value κ Ψ Q C Γ v a => κ = [] → Q = Qempty → C = [] → Γ = [] →
      HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] [] (embedHeldVal v) (embedTy a)
  | .values κ Ψ Q C Γ vs ts => κ = [] → Q = Qempty → C = [] → Γ = [] →
      HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] []
        (closeVals Capture.empty (embedVals vs)) (embedTys ts)
  | .each κ Ψ Q C Γ vs a => κ = [] → Q = Qempty → C = [] → Γ = [] →
      HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Qempty [] [] []
        (closeVals Capture.empty (embedVals vs)) (embedTy a)
  | _ => True

```

以下は再開2の全125手書き宣言の実際の全引数を含む最終の型である。

```lean
Benitoite.Release.Refinement.HeldTyped✝ : Benitoite.Release.Refinement.DeclarationKinds →
  Benitoite.Release.Program → Benitoite.Release.Refinement.Builtins → Benitoite.Release.Refinement.LegacyJudgment → Prop
@Benitoite.Release.Refinement.held_lambda✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {ns : List String} {ps : List Benitoite.Release.Ty} {body : Benitoite.Release.Comp}
  {r : Benitoite.Release.Ty} {e : Benitoite.Release.EffR},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyNodeRegular K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value [] Ψ Benitoite.Release.Qempty [] []
            (Benitoite.Release.Val.lam ns ps body) (Benitoite.Release.Ty.fn ns ps r e)) →
        Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
            (Benitoite.Release.Refinement.LegacyJudgment.comp [] Ψ.hideBuilders Benitoite.Release.Qempty []
              (Benitoite.Release.binds ps) (Option.some r) body r e []) →
          Benitoite.Release.Refinement.HasTypeVQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) Benitoite.Release.Qempty [] [] []
            (Benitoite.Release.Refinement.embedHeldVal (Benitoite.Release.Val.lam ns ps body))
            (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.fn ns ps r e))
@Benitoite.Release.Refinement.close_type✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Δ : Benitoite.Release.Refinement.LegacyInputCtx} {a : Benitoite.Release.Ty}
  {k : Benitoite.Release.Refinement.TyKind},
  Benitoite.Release.Refinement.LegacyTypeInput K P0 Δ a k →
    Benitoite.Release.Refinement.Capture.empty.closeTy (Benitoite.Release.Refinement.embedTy a) =
      Benitoite.Release.Refinement.embedTy a
@Benitoite.Release.Refinement.close_types✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Δ : Benitoite.Release.Refinement.LegacyInputCtx} {ts : List Benitoite.Release.Ty}
  {ks : List Benitoite.Release.Refinement.TyKind},
  Benitoite.Release.Refinement.LegacyTypesInput K P0 Δ ts ks →
    List.map Benitoite.Release.Refinement.Capture.empty.closeTy (Benitoite.Release.Refinement.embedTys ts) =
      Benitoite.Release.Refinement.embedTys ts
@Benitoite.Release.Refinement.close_rows✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Δ : Benitoite.Release.Refinement.LegacyInputCtx} {es : List Benitoite.Release.Eff},
  Benitoite.Release.Refinement.LegacyRowsInput K P0 Δ es →
    List.map Benitoite.Release.Refinement.Capture.empty.closeEff (List.map Benitoite.Release.Refinement.embedEff es) =
      List.map Benitoite.Release.Refinement.embedEff es
@Benitoite.Release.Refinement.held_induct✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {j : Benitoite.Release.Refinement.LegacyJudgment},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B j → Benitoite.Release.Refinement.HeldTyped✝ K P0 B j
@Benitoite.Release.Refinement.embedHeldVal_typed : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyOutputInput K P0 B0 B
          (Benitoite.Release.Refinement.LegacyJudgment.value [] Ψ Benitoite.Release.Qempty [] [] v a) →
        Benitoite.Release.Refinement.HasTypeVQ (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
          (Benitoite.Release.Refinement.embedStoreTy Ψ) Benitoite.Release.Qempty [] [] []
          (Benitoite.Release.Refinement.embedHeldVal v) (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.legacy_closed_annotation✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {Γ : List (Option Benitoite.Release.Ty)} {R : Option Benitoite.Release.Ty}
  {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff},
  Benitoite.Release.Refinement.LegacyClosedCompInput K P0 B0 B Ψ Γ R m a e →
    Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0) [] []
      (Benitoite.Release.Refinement.Ty.dependentFn
        (Benitoite.Release.Refinement.Tel.done (Benitoite.Release.Refinement.embedTy a)
          (Benitoite.Release.Refinement.embedEff e)))
@Benitoite.Release.Refinement.legacy_closed_return✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {Γ : List (Option Benitoite.Release.Ty)} {R : Option Benitoite.Release.Ty}
  {m : Benitoite.Release.Comp} {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff},
  Benitoite.Release.Refinement.LegacyClosedCompInput K P0 B0 B Ψ Γ R m a e →
    ∀ (r : Benitoite.Release.Refinement.Ty),
      Option.map Benitoite.Release.Refinement.embedTy R = Option.some r →
        Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0) [] [] r ∧
          r.Normal
@Benitoite.Release.Refinement.legacy_cont_annotation✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Ψ : Benitoite.Release.StoreTy} {R : Option Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option Benitoite.Release.Ty},
  Benitoite.Release.Refinement.LegacyContRegular K P0 Ψ R e a b out Re →
    Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0) [] []
      (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.legacy_close_type✝ : ∀ {a : Benitoite.Release.Ty} {nr nt nv : Nat},
  Benitoite.Release.Refinement.Ty.WF nr nt nv (Benitoite.Release.Refinement.embedTy a) →
    ∀ (cap : Benitoite.Release.Refinement.Capture) (n : Nat),
      cap.closeTyAt n (Benitoite.Release.Refinement.embedTy a) = Benitoite.Release.Refinement.embedTy a
@Benitoite.Release.Refinement.legacy_pure_let✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
  {a c : Benitoite.Release.Ty} {e : Benitoite.Release.Eff},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.Ty.Annotation (Benitoite.Release.Refinement.embedProgramWithKinds K P0) [] []
          (Benitoite.Release.Refinement.embedTy a) →
        Benitoite.Release.Refinement.LegacyClosedCompInput K P0 B0 B Ψ [Option.some a] R m c e →
          Benitoite.Release.Refinement.ClosureTy (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
            (Benitoite.Release.Refinement.embedStoreTy Ψ) [Benitoite.Release.Refinement.embedTy a]
            (Option.map Benitoite.Release.Refinement.embedTy R)
            (Benitoite.Release.Refinement.Closure.pure (Benitoite.Release.Refinement.embedComp m))
            (Benitoite.Release.Refinement.embedTy c) (Benitoite.Release.Refinement.embedEff e)
@Benitoite.Release.Refinement.legacy_close_return✝ : ∀ {P : Benitoite.Release.Refinement.Program}
  {R : Option Benitoite.Release.Ty},
  (∀ (a : Benitoite.Release.Ty),
      a ∈ R.toList → Benitoite.Release.Refinement.Ty.Annotation P [] [] (Benitoite.Release.Refinement.embedTy a)) →
    Benitoite.Release.Refinement.Capture.empty.closeR (Option.map Benitoite.Release.Refinement.embedTy R) =
      Option.map Benitoite.Release.Refinement.embedTy R
Benitoite.Release.Refinement.legacy_values_map✝ : ∀ (vs : List Benitoite.Release.Val),
  Benitoite.Release.Refinement.embedVals vs = List.map Benitoite.Release.Refinement.embedVal vs
Benitoite.Release.Refinement.legacy_arms_map✝ : ∀ (arms : List Benitoite.Release.Arm),
  Benitoite.Release.Refinement.embedArms arms = List.map Benitoite.Release.Refinement.embedArm arms
Benitoite.Release.Refinement.legacy_const_matches✝ : ∀ (p c : Benitoite.Release.Const),
  Benitoite.Release.Refinement.patternMatches p (Benitoite.Release.Refinement.embedConst c) = p.matches c
Benitoite.Release.Refinement.legacy_const_range✝ : ∀ (lo hi c : Benitoite.Release.Const),
  Benitoite.Release.Refinement.patternRange lo hi (Benitoite.Release.Refinement.embedConst c) = lo.inRange hi c
@Benitoite.Release.Refinement.closed_take✝ : ∀ {vs : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.Val.ClosedList 0 0 vs →
    ∀ (n : Nat), Benitoite.Release.Refinement.Val.ClosedList 0 0 (List.take n vs)
@Benitoite.Release.Refinement.closed_drop✝ : ∀ {vs : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.Val.ClosedList 0 0 vs →
    ∀ (n : Nat), Benitoite.Release.Refinement.Val.ClosedList 0 0 (List.drop n vs)
Benitoite.Release.Refinement.legacy_firstAlt_embed✝ : ∀ (v : Benitoite.Release.Val) (alts : List Benitoite.Release.Alt),
  (Benitoite.Release.Refinement.embedVal v).Ground →
    Benitoite.Release.Refinement.firstAlt (Benitoite.Release.Refinement.embedHeldVal v) alts =
      Option.map
        (fun vs =>
          Benitoite.Release.Refinement.closeVals Benitoite.Release.Refinement.Capture.empty
            (Benitoite.Release.Refinement.embedVals vs))
        (Benitoite.Release.firstAlt v alts)
@Benitoite.Release.Refinement.legacy_prefix✝ : ∀ {v : Benitoite.Release.Val} {arms : List Benitoite.Release.Arm}
  {next : Nat},
  Benitoite.Release.MatchPrefix v arms next →
    (Benitoite.Release.Refinement.embedVal v).Ground →
      Benitoite.Release.Refinement.MatchPrefix (Benitoite.Release.Refinement.embedHeldVal v)
        (Benitoite.Release.Refinement.embedArms arms) next
@Benitoite.Release.Refinement.embedContTy : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.StoreTy} {R : Option Benitoite.Release.Ty}
  {e : Benitoite.Release.Eff} {k : Benitoite.Release.Cont} {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option Benitoite.Release.Ty} {h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ h →
        Benitoite.Release.Refinement.ContTy (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B σ
          (Benitoite.Release.Refinement.embedStoreTy Ψ) (Option.map Benitoite.Release.Refinement.embedTy R)
          (Benitoite.Release.Refinement.embedEff e) (Benitoite.Release.Refinement.embedCont k)
          (Benitoite.Release.Refinement.embedTy a) (Benitoite.Release.Refinement.embedTy b)
          (Benitoite.Release.Refinement.embedEff out) (Option.map Benitoite.Release.Refinement.embedTy Re)
@Benitoite.Release.Refinement.legacy_store_formation✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {Ψ : Benitoite.Release.StoreTy},
  Benitoite.Release.Refinement.LegacyNodeContext K P0 [] Ψ [] [] →
    (Benitoite.Release.Refinement.embedStoreTy Ψ).WF ∧
      (Benitoite.Release.Refinement.embedStoreTy Ψ).Sorted ∧
        Benitoite.Release.Refinement.StoreTy.Declared (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
          (Benitoite.Release.Refinement.embedStoreTy Ψ)
@Benitoite.Release.Refinement.legacy_cont_closed✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {R : Option Benitoite.Release.Ty} {e : Benitoite.Release.Eff}
  {k : Benitoite.Release.Cont} {a b : Benitoite.Release.Ty} {out : Benitoite.Release.Eff}
  {Re : Option Benitoite.Release.Ty} {h : Benitoite.Release.ContTy P0 B0 Ψ R e k a b out Re},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyContInput K P0 B0 B Ψ h → (Benitoite.Release.Refinement.embedCont k).Closed
@Benitoite.Release.Refinement.legacy_cell✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {l : Nat} {c : Benitoite.Release.Cell} {σ : Benitoite.Release.Refinement.PathEnv},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyCellInput K P0 B0 B Ψ l c →
        Benitoite.Release.Refinement.CellOk (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B σ
            (Benitoite.Release.Refinement.embedStoreTy Ψ) l (Benitoite.Release.Refinement.embedCell c) ∧
          (Benitoite.Release.Refinement.embedCell c).Closed
@Benitoite.Release.Refinement.embedStoreOk : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.StoreTy} {μ : Benitoite.Release.Store},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyStoreInput K P0 B0 B Ψ μ →
        Benitoite.Release.Refinement.StoreOk (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B σ
          (Benitoite.Release.Refinement.embedStoreTy Ψ) (Benitoite.Release.Refinement.embedStore μ)
@Benitoite.Release.Refinement.legacy_store_closed✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.StoreTy} {μ : Benitoite.Release.Store},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyStoreInput K P0 B0 B Ψ μ → (Benitoite.Release.Refinement.embedStore μ).Closed
@Benitoite.Release.Refinement.embedStateTyE : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Eb : Benitoite.Release.Eff} {s : Benitoite.Release.State},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyStateInput K P0 B0 B Eb s →
        Benitoite.Release.Refinement.StateTyE (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B σ
          (Benitoite.Release.Refinement.embedEff Eb) (Benitoite.Release.Refinement.embedState s)
@Benitoite.Release.Refinement.kind_toTel✝ : ∀ {P : Benitoite.Release.Refinement.Program}
  {K : Benitoite.Release.Refinement.KindCtx} {ns : List String} {ps : List Benitoite.Release.Refinement.Ty}
  {r : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.EffR},
  Benitoite.Release.Refinement.Ty.HasKind P K (Benitoite.Release.Refinement.Ty.fn ns ps r e)
      Benitoite.Release.Refinement.TyKind.value →
    Benitoite.Release.Refinement.kindsTel P K (Benitoite.Release.Refinement.Ty.toTel ns ps r e)
@Benitoite.Release.Refinement.embedDefWellTyped : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {f : Benitoite.Release.FunName} {d : Benitoite.Release.Def},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyDeclarationsInput K P0 B0 B →
        P0.defs f = Option.some d →
          Benitoite.Release.Refinement.functionBodyInput K P0 B0 B f d →
            Benitoite.Release.Refinement.Def.WellTyped (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
              (Benitoite.Release.Refinement.embedDefWithKinds (K.functionParams f) d)
Benitoite.Release.Refinement.legacy_substAt✝ : ∀ (a : Benitoite.Release.Ty) (c : Nat) (ts : List Benitoite.Release.Ty)
  (es : List Benitoite.Release.Eff),
  Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.substAt c ts es a) =
    Benitoite.Release.Refinement.Ty.substAt c (Benitoite.Release.Refinement.embedTys ts)
      (List.map Benitoite.Release.Refinement.embedEff es) (Benitoite.Release.Refinement.embedTy a)
Benitoite.Release.Refinement.legacy_substEffAt✝ : ∀ (e : Benitoite.Release.Eff) (c : Nat)
  (ts : List Benitoite.Release.Ty) (es : List Benitoite.Release.Eff),
  Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.substAt c ts es e) =
    Benitoite.Release.Refinement.Eff.substAt c (Benitoite.Release.Refinement.embedTys ts)
      (List.map Benitoite.Release.Refinement.embedEff es) (Benitoite.Release.Refinement.embedEff e)
Benitoite.Release.Refinement.legacy_method_tel✝ : ∀ (ks : Benitoite.Release.Refinement.KindCtx)
  (id : Benitoite.Release.ImplDecl) (ms : Benitoite.Release.MethSig),
  Benitoite.Release.Refinement.Tel.bind
      (Benitoite.Release.Refinement.typeEnvAt ms.tparams.length [Benitoite.Release.Refinement.embedTy id.target] [])
      (Benitoite.Release.Refinement.embedMethSigWithKinds ks ms).tel =
    Benitoite.Release.Refinement.Ty.toTel ms.names
      (Benitoite.Release.Refinement.embedTys (List.map (id.methTy ms) ms.params))
      (Benitoite.Release.Refinement.embedTy (id.methTy ms ms.ret))
      (Benitoite.Release.Refinement.embedEff (Benitoite.Release.Eff.substAt ms.tparams.length [id.target] [] ms.eff))
Benitoite.Release.Refinement.legacy_public_shift✝ : ∀ (a : Benitoite.Release.Ty) (k c : Nat),
  Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.shift k c a) =
    Benitoite.Release.Refinement.Ty.shift k c (Benitoite.Release.Refinement.embedTy a)
@Benitoite.Release.Refinement.embedImplWellTyped : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins}
  {i : Benitoite.Release.ImplName} {id : Benitoite.Release.ImplDecl},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyDeclarationInputs K P0 B0 B →
        P0.impls i = Option.some id →
          Benitoite.Release.ImplDecl.WellTyped P0 B0 id →
            Benitoite.Release.Refinement.ImplDecl.WellTyped (Benitoite.Release.Refinement.embedProgramWithKinds K P0) B
              (Benitoite.Release.Refinement.embedImplDecl id)
@Benitoite.Release.Refinement.embedProgramWellTyped : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyDeclarationInputs K P0 B0 B →
        P0.WellTyped B0 → (Benitoite.Release.Refinement.embedProgramWithKinds K P0).WellTyped B
Benitoite.Release.Refinement.signature_rows✝ : ∀ (ns : List String) (ps : List Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (pe : Nat → Prop),
  Benitoite.Release.Refinement.Ty.RowsIn pe (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.fn ns ps r e)) →
    Benitoite.Release.Refinement.Tel.RowsIn pe
      (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
        (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
Benitoite.Release.Refinement.signature_ranges✝ : ∀ (ns : List String) (ps : List Benitoite.Release.Ty)
  (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (nr : Nat),
  Benitoite.Release.Refinement.Ty.RangesScoped nr
      (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.fn ns ps r e)) →
    Benitoite.Release.Refinement.Tel.RangesScoped nr
      (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
        (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
@Benitoite.Release.Refinement.signature_scoped✝ : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {κ : List Benitoite.Release.Refinement.TyKind} {C : List Benitoite.Release.TParam}
  {ns : List String} {ps : List Benitoite.Release.Ty} {r : Benitoite.Release.Ty} {e : Benitoite.Release.EffR}
  {ne : Nat},
  κ.length = C.length →
    Benitoite.Release.Refinement.LegacyTypeInput K P0 { kinds := κ, constraints := C, nr := 0, nv := 0 }
        (Benitoite.Release.Ty.fn ns ps r e) Benitoite.Release.Refinement.TyKind.value →
      Benitoite.Release.Refinement.Ty.RowsIn (fun x => x < ne)
          (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.fn ns ps r e)) →
        Benitoite.Release.Refinement.SignatureScoped (Benitoite.Release.Refinement.embedProgramWithKinds K P0)
          (Benitoite.Release.Refinement.legacyTypeCtx C κ) ne
          (Benitoite.Release.Refinement.signatureTel ns (Benitoite.Release.Refinement.embedTys ps)
            (Benitoite.Release.Refinement.embedTy r) (Benitoite.Release.Refinement.embedEff e))
@Benitoite.Release.Refinement.embedProgramWellFormed : ∀ {K : Benitoite.Release.Refinement.DeclarationKinds}
  {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Benitoite.Release.Refinement.Builtins},
  K.WF P0 →
    Benitoite.Release.Refinement.LegacyTables K P0 B0 B →
      Benitoite.Release.Refinement.LegacyDeclarationInputs K P0 B0 B →
        P0.WellFormed → (Benitoite.Release.Refinement.embedProgramWithKinds K P0).WellFormed
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝ : Benitoite.Release.Ty
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝ : Benitoite.Release.Eff
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝ : Benitoite.Release.StoreTy
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝ : Benitoite.Release.Ty
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝ : Benitoite.Release.Val
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.arms✝ : List Benitoite.Release.Arm
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.guardStack✝ : Benitoite.Release.Cont
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.empty_context✝ : Benitoite.Release.Refinement.LegacyNodeContext
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  [] Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝ [] []
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.unit_type✝ : Benitoite.Release.Refinement.LegacyTypeInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyInputCtx.closed Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝
  Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.function_type✝ : Benitoite.Release.Refinement.LegacyTypeInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyInputCtx.closed Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝
  Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.rows✝ : Benitoite.Release.Refinement.LegacyRowsInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyInputCtx.closed [Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝]
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.ret_input✝ : ∀ (R : Option Benitoite.Release.Ty),
  (∀ (a : Benitoite.Release.Ty), a ∈ R.toList → a = Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝) →
    Benitoite.Release.Refinement.LegacyOutputInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
      Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins
      (Benitoite.Release.Refinement.LegacyJudgment.comp [] Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝
        Benitoite.Release.Qempty [] [] R
        (Benitoite.Release.Comp.ret (Benitoite.Release.Val.const Benitoite.Release.Const.unit))
        Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝
        Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝ [])
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.lambda_input✝ : Benitoite.Release.Refinement.LegacyOutputInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  (Benitoite.Release.Refinement.LegacyJudgment.value [] Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝
    Benitoite.Release.Qempty [] [] Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝
    Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝)
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.match_input✝ : Benitoite.Release.Refinement.LegacyClosedCompInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝ [] Option.none
  (Benitoite.Release.Comp.match Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝
    Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.arms✝)
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.sub_empty✝ : Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝.Sub
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.oldGuard✝ : Benitoite.Release.ContTy
  Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝ Option.none
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.guardStack✝
  (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.boolean)
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝ Option.none
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.guard_input : Benitoite.Release.Refinement.LegacyContInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.oldGuard✝
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.no_closed_lambda✝ : ∀ (v : Benitoite.Release.Refinement.Val)
  (ns : List String) (ps : List Benitoite.Release.Refinement.Ty) (body : Benitoite.Release.Refinement.Comp),
  Benitoite.Release.Refinement.closeVal Benitoite.Release.Refinement.Capture.empty v ≠
    Benitoite.Release.Refinement.Val.lam ns ps body
@Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.no_embedded_guard : ∀
  {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff}
  {k : Benitoite.Release.Refinement.Cont} {a b : Benitoite.Release.Refinement.Ty}
  {out : Benitoite.Release.Refinement.Eff} {Re : Option Benitoite.Release.Refinement.Ty} {ns : List String}
  {ps : List Benitoite.Release.Refinement.Ty} {body : Benitoite.Release.Refinement.Comp}
  {arms : List Benitoite.Release.Refinement.Arm} {next : Nat} {q : Benitoite.Release.Refinement.Closure},
  ¬Benitoite.Release.Refinement.ContTy P B σ Ψ R e
      (Benitoite.Release.Refinement.Frame.guardF (Benitoite.Release.Refinement.Val.lam ns ps body)
          Benitoite.Release.Refinement.Capture.empty arms next q ::
        k)
      a b out Re
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.old_guard_embedding_impossible : ∀
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.LegacyContInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
      Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins
      Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝
      Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.oldGuard✝ ∧
    ¬Benitoite.Release.Refinement.ContTy
        (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
          Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
        Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
        (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝)
        Option.none (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
        [Benitoite.Release.Refinement.Frame.guardF
            (Benitoite.Release.Refinement.embedVal
              Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝)
            Benitoite.Release.Refinement.Capture.empty
            (Benitoite.Release.Refinement.embedArms Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.arms✝) 0
            (Benitoite.Release.Refinement.Closure.pure
              (Benitoite.Release.Refinement.Comp.ret
                (Benitoite.Release.Refinement.Val.const Benitoite.Release.Refinement.Const.unit)))]
        (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.boolean))
        (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝)
        (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝) Option.none
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.matchState✝ : Benitoite.Release.State
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.empty_store✝ : Benitoite.Release.Refinement.LegacyStoreInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝ Benitoite.Release.Store.empty
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.state_input : Benitoite.Release.Refinement.LegacyStateInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.matchState✝
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.old_state_embedding_impossible : ∀
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.LegacyStateInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
      Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins
      Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝
      Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.matchState✝ ∧
    ¬Benitoite.Release.Refinement.StateTyE
        (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
          Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
        Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
        (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
        (Benitoite.Release.Refinement.State.matchRun
          (Benitoite.Release.Refinement.embedVal
            Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝)
          Benitoite.Release.Refinement.Capture.empty
          (Benitoite.Release.Refinement.embedArms Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.arms✝) 0 []
          (Benitoite.Release.Refinement.embedStore Benitoite.Release.Store.empty))
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.old_match_step : Benitoite.Release.Step
  Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  (Benitoite.Release.State.run
    (Benitoite.Release.Comp.match Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝
      Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.arms✝)
    [] Benitoite.Release.Store.empty)
  Option.none Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.matchState✝
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.guard_embedding_accepted : ∀
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.ContTy
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
    (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝) Option.none
    (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
    (Benitoite.Release.Refinement.embedCont Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.guardStack✝)
    (Benitoite.Release.Refinement.embedTy (Benitoite.Release.Ty.base Benitoite.Release.BaseTy.boolean))
    (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.U✝)
    (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝) Option.none
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.state_embedding_accepted : ∀
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.StateTyE
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
    (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
    (Benitoite.Release.Refinement.embedState Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.matchState✝)
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.held_lambda_typed : Benitoite.Release.Refinement.HasTypeVQ
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝)
  Benitoite.Release.Qempty [] [] []
  (Benitoite.Release.Refinement.embedHeldVal Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝)
  (Benitoite.Release.Refinement.embedTy Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝)
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.held_lambda_covered : ∃ p,
  p ∈ [Benitoite.Release.Pat.wild] ∧
    (Benitoite.Release.Refinement.matchVal p
          (Benitoite.Release.Refinement.embedHeldVal
            Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝)).isSome =
      Bool.true
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.state_typed_of_valid : ∀
  (σ : Benitoite.Release.Refinement.PathEnv),
  σ.Valid →
    Benitoite.Release.Refinement.StateTy
      (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
        Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
      (Benitoite.Release.Refinement.embedState Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.matchState✝)
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.empty_store_embedded : ∀
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.StoreOk
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
    (Benitoite.Release.Refinement.embedStoreTy Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝)
    (Benitoite.Release.Refinement.embedStore Benitoite.Release.Store.empty)
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.run_embedded : ∀ (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.StateTyE
    (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
    (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
    (Benitoite.Release.Refinement.embedState
      (Benitoite.Release.State.run
        (Benitoite.Release.Comp.ret (Benitoite.Release.Val.const Benitoite.Release.Const.unit)) []
        Benitoite.Release.Store.empty))
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.error_and_exit_embedded : ∀
  (σ : Benitoite.Release.Refinement.PathEnv) (rs : List Benitoite.Release.ErrKind) (code : Int),
  Benitoite.Release.Refinement.StateTyE
      (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
        Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
      (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
      (Benitoite.Release.Refinement.embedState (Benitoite.Release.State.error rs [] Benitoite.Release.Store.empty)) ∧
    Benitoite.Release.Refinement.StateTyE
      (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
        Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
      (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
      (Benitoite.Release.Refinement.embedState (Benitoite.Release.State.exit code rs [] Benitoite.Release.Store.empty))
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.listArms✝ : List Benitoite.Release.Arm
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.function_type_at✝ : ∀ (n : Nat),
  Benitoite.Release.Refinement.LegacyTypeInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram { kinds := [], constraints := [], nr := 0, nv := n }
    Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝ Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.list_type✝ : Benitoite.Release.Refinement.LegacyTypeInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyInputCtx.closed Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝.list
  Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.list_input✝ : Benitoite.Release.Refinement.LegacyOutputInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  (Benitoite.Release.Refinement.LegacyJudgment.value [] Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝
    Benitoite.Release.Qempty [] []
    (Benitoite.Release.Val.list [Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝])
    Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝.list)
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.list_match_input✝ : Benitoite.Release.Refinement.LegacyClosedCompInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.S✝ [] Option.none
  (Benitoite.Release.Comp.match
    (Benitoite.Release.Val.list [Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝])
    Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.listArms✝)
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.F✝
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.listState✝ : Benitoite.Release.State
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.list_state_input✝ : Benitoite.Release.Refinement.LegacyStateInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝
  Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.listState✝
Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.list_lambda_state : ∀
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.StateTyE
      (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
        Benitoite.Release.Refinement.LegacyPatternExamples.oldProgram)
      Benitoite.Release.Refinement.LegacyPatternExamples.builtins σ
      (Benitoite.Release.Refinement.embedEff Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.E✝)
      (Benitoite.Release.Refinement.embedState Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.listState✝) ∧
    Benitoite.Release.Refinement.firstAlt
        (Benitoite.Release.Refinement.embedHeldVal
          (Benitoite.Release.Val.list [Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝]))
        [{
            pat :=
              Benitoite.Release.Pat.list [Benitoite.Release.Pat.var] (Option.some Benitoite.Release.ListRest.skip) [],
            slots := [0] }] =
      Option.some
        [Benitoite.Release.Refinement.embedHeldVal
            Benitoite.Release.Refinement.LegacyStateEmbeddingExamples.functionValue✝]
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.U✝ : Benitoite.Release.Ty
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.E✝ : Benitoite.Release.Eff
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.declaration✝ : Benitoite.Release.Def
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝ : Benitoite.Release.Program
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.lookup✝ : Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝.defs
    "identity" =
  Option.some Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.declaration✝
@Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.only_function✝ : ∀ {f : Benitoite.Release.FunName}
  {d : Benitoite.Release.Def},
  Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝.defs f = Option.some d →
    d = Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.declaration✝
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.kinds_valid✝ : Benitoite.Release.Refinement.LegacyPatternExamples.kinds.WF
  Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.tables✝ : Benitoite.Release.Refinement.LegacyTables
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.unit_type✝ : ∀ (n : Nat),
  Benitoite.Release.Refinement.LegacyTypeInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝
    { kinds := [], constraints := [], nr := 0, nv := n } Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.U✝
    Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.function_type✝ : Benitoite.Release.Refinement.LegacyTypeInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyInputCtx.closed
  (Benitoite.Release.Ty.fn ["x"] [Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.U✝]
    Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.U✝
    Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.E✝)
  Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.body_input✝ : Benitoite.Release.Refinement.functionBodyInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins "identity"
  Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.declaration✝
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.inputs✝ : Benitoite.Release.Refinement.LegacyDeclarationInputs
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.old_typed✝ : Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝.WellTyped
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.old_scoped✝ : Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝.WellFormed
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.function_embedded : Benitoite.Release.Refinement.Def.WellTyped
  (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝)
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  (Benitoite.Release.Refinement.embedDefWithKinds []
    Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.declaration✝)
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program_embedded : (Benitoite.Release.Refinement.embedProgramWithKinds
      Benitoite.Release.Refinement.LegacyPatternExamples.kinds
      Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝).WellTyped
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program_well_formed : (Benitoite.Release.Refinement.embedProgramWithKinds
    Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples.program✝).WellFormed
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.U✝ : Benitoite.Release.Ty
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.E✝ : Benitoite.Release.Eff
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.signature✝ : Benitoite.Release.MethSig
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.baseClass✝ : Benitoite.Release.ClassDecl
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childClass✝ : Benitoite.Release.ClassDecl
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.baseImpl✝ : Benitoite.Release.ImplDecl
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝ : Benitoite.Release.ImplDecl
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝ : Benitoite.Release.Program
@Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.only_class✝ : ∀ {c : Benitoite.Release.ClassName}
  {cd : Benitoite.Release.ClassDecl},
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝.classes c = Option.some cd →
    c = "Base" ∧ cd = Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.baseClass✝ ∨
      c = "Child" ∧ cd = Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childClass✝
@Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.only_impl✝ : ∀ {i : Benitoite.Release.ImplName}
  {id : Benitoite.Release.ImplDecl},
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝.impls i = Option.some id →
    id = Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.baseImpl✝ ∨
      id = Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝
@Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.only_method✝ : ∀ {m : Benitoite.Release.MethName}
  {ms : Benitoite.Release.MethSig},
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childClass✝.methods m = Option.some ms →
    m = "identity" ∧ ms = Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.signature✝
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.tables✝ : Benitoite.Release.Refinement.LegacyTables
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.kinds_valid✝ : Benitoite.Release.Refinement.LegacyPatternExamples.kinds.WF
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.unit_type✝ : ∀ (n : Nat),
  Benitoite.Release.Refinement.LegacyTypeInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
    { kinds := [], constraints := [], nr := 0, nv := n }
    Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.U✝ Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.signature_input✝ : ∀
  (Δ : Benitoite.Release.Refinement.LegacyInputCtx),
  Benitoite.Release.Refinement.LegacyTypeInput Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝ Δ
    (Benitoite.Release.Ty.fn ["x"] [Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.U✝]
      Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.U✝
      Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.E✝)
    Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.method_type✝ : Benitoite.Release.Refinement.LegacyTypeInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  { kinds := [Benitoite.Release.Refinement.TyKind.value], constraints := [{ }], nr := 0, nv := 0 }
  (Benitoite.Release.Ty.fn ["x"] [Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.U✝]
    Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.U✝
    Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.E✝)
  Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.method_input✝ : Benitoite.Release.Refinement.methodBodyInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝ "identity"
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.signature✝
  (Benitoite.Release.Comp.ret (Benitoite.Release.Val.var 0))
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.dictionary_type✝ : Benitoite.Release.Refinement.LegacyTypeInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyInputCtx.closed
  (Benitoite.Release.Ty.dict "Base" Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.U✝)
  Benitoite.Release.Refinement.TyKind.value
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.super_input✝ : Benitoite.Release.Refinement.superBodyInput
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝ "Base"
  (Benitoite.Release.Val.dict "unitBase" [] [])
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.inputs✝ : Benitoite.Release.Refinement.LegacyDeclarationInputs
  Benitoite.Release.Refinement.LegacyPatternExamples.kinds
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyPatternExamples.builtins
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.old_base✝ : Benitoite.Release.ImplDecl.WellTyped
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.baseImpl✝
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.old_child✝ : Benitoite.Release.ImplDecl.WellTyped
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.old_typed✝ : Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝.WellTyped
  Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.old_formed✝ : Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝.WellFormed
Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.implementation_parents : Benitoite.Release.Refinement.LegacyDeclarationInputs
    Benitoite.Release.Refinement.LegacyPatternExamples.kinds
    Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝
    Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins
    Benitoite.Release.Refinement.LegacyPatternExamples.builtins ∧
  Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝.WellTyped
      Benitoite.Release.Refinement.LegacyPatternExamples.oldBuiltins ∧
    Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝.WellFormed ∧
      Benitoite.Release.Refinement.ImplDecl.WellTyped
          (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
            Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝)
          Benitoite.Release.Refinement.LegacyPatternExamples.builtins
          (Benitoite.Release.Refinement.embedImplDecl
            Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝) ∧
        (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
                Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝).WellTyped
            Benitoite.Release.Refinement.LegacyPatternExamples.builtins ∧
          (Benitoite.Release.Refinement.embedProgramWithKinds Benitoite.Release.Refinement.LegacyPatternExamples.kinds
                Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.program✝).WellFormed ∧
            (Benitoite.Release.Refinement.embedImplDecl
                      Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝).methods
                  "identity" =
                Option.some
                  (Benitoite.Release.Refinement.embedComp (Benitoite.Release.Comp.ret (Benitoite.Release.Val.var 0))) ∧
              (Benitoite.Release.Refinement.embedImplDecl
                      Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples.childImpl✝).supers
                  "Base" =
                Option.some (Benitoite.Release.Refinement.embedVal (Benitoite.Release.Val.dict "unitBase" [] []))
Benitoite.Release.Refinement.embedHeldVal : Benitoite.Release.Val → Benitoite.Release.Refinement.Val
Benitoite.Release.Refinement.legacy_held_value_adequate : ∀ (v : Benitoite.Release.Val)
  (σ : Benitoite.Release.Refinement.PathEnv),
  Benitoite.Release.Refinement.Val.Adequate σ (Benitoite.Release.Refinement.embedHeldVal v)
```
