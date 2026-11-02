# 群 I の完全署名

開始版 B_WORK: `e485c90cf428d0dc9086594d489e58776ed6ed1d`。ブランチ: `m014/l20.i1`。本体を書く前に署名を記録し、再開1の追加と内部補題の変更を反映した。以下は [signatures.lean](signatures.lean) が既定 import から印字する79宣言の完全な型である。暗黙引数の型も含む。100 KB 以下とする。

閉じた型付けから意味・所属・束縛の保存を導く段は CoreAssumptions を前提にしない。捕捉の変数の閉じた型付けには SubstitutionAssumptions とストアの型の WF を使う。任意の開いた値の閉じた型付けを供給する close_value_typed の CoreAssumptions 等の入力とは区別する。

S08 の内部補題は、不要な WellFormed・WellTyped・CoreAssumptions・ストアの WF を外し、VarianceValid だけを受ける。結論は δ.map Ty.norm のままであり、元の型への束縛保存を結論しない。Ground の保存は、照合前の同じ値の Ground を入力にする。

再開1では具体の捕捉、値依存の型、受理と拒否、self を読む Map の unknown の21宣言を追加し、読者のない bridge_bind_o を削除した。month_variable_coverage は具体の捕捉を内部で構成する例とした。主な言明・型付けの規則・公理の変更はない。

```text
@Benitoite.Release.Refinement.TypedMeaning.constructor_meaning : ∀ {P : Benitoite.Release.Refinement.Program}
  {η : Benitoite.Release.Refinement.ObservationEnvModel} {c : Benitoite.Release.ConName}
  {cd : Benitoite.Release.Refinement.ConDecl} {ts tys : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val},
  P.cons c = some cd →
    ts.length = cd.ntys →
      (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ cd.args → Benitoite.Release.Refinement.Ty.WF 0 cd.ntys 0 t) →
        Benitoite.Release.Refinement.ValueMeanings P η (List.map (Benitoite.Release.Refinement.Ty.subst ts []) cd.args)
            vs →
          Benitoite.Release.Refinement.ValueMeaning P η (Benitoite.Release.Refinement.Ty.data cd.data ts)
            (Benitoite.Release.Refinement.Val.con c tys vs)
Benitoite.Release.Refinement.TypedMeaning.bridge_term : ∀ (u : Benitoite.Release.Refinement.Term)
  (ν : Benitoite.Release.Refinement.ObservationEnv) (ξ ζ : Benitoite.Release.Refinement.ObservationEnvModel),
  (∀ (i : Nat),
      ∃ s,
        ν i = some s ∧
          Benitoite.Release.Refinement.Term.observe ξ s = ζ i ∧ Benitoite.Release.Refinement.Term.interpret ξ s = ζ i) →
    ∃ s,
      Benitoite.Release.Refinement.termBind? ν u = some s ∧
        Benitoite.Release.Refinement.Term.observe ξ s = Benitoite.Release.Refinement.Term.observe ζ u ∧
          Benitoite.Release.Refinement.Term.interpret ξ s = Benitoite.Release.Refinement.Term.interpret ζ u
Benitoite.Release.Refinement.TypedMeaning.bridge_slots : ∀ (xs : List (Option Benitoite.Release.Refinement.Term))
  (ν : Benitoite.Release.Refinement.ObservationEnv) (ξ ζ : Benitoite.Release.Refinement.ObservationEnvModel),
  (∀ (i : Nat),
      ∃ s,
        ν i = some s ∧
          Benitoite.Release.Refinement.Term.observe ξ s = ζ i ∧ Benitoite.Release.Refinement.Term.interpret ξ s = ζ i) →
    Benitoite.Release.Refinement.observeSlots ξ (Benitoite.Release.Refinement.bindSlots ν xs) =
      Benitoite.Release.Refinement.observeSlots ζ xs
Benitoite.Release.Refinement.TypedMeaning.bridge_bind : ∀ (u : Benitoite.Release.Refinement.Term)
  (ν : Benitoite.Release.Refinement.ObservationEnv) (ξ ζ : Benitoite.Release.Refinement.ObservationEnvModel),
  (∀ (i : Nat),
      ∃ s,
        ν i = some s ∧
          Benitoite.Release.Refinement.Term.observe ξ s = ζ i ∧ Benitoite.Release.Refinement.Term.interpret ξ s = ζ i) →
    Benitoite.Release.Refinement.Term.interpret ξ (Benitoite.Release.Refinement.termBind ν u) =
      Benitoite.Release.Refinement.Term.interpret ζ u
Benitoite.Release.Refinement.TypedMeaning.bridge_pred : ∀ (p : Benitoite.Release.Refinement.Pred)
  (ν : Benitoite.Release.Refinement.ObservationEnv) (ξ ζ : Benitoite.Release.Refinement.ObservationEnvModel),
  (∀ (i : Nat),
      ∃ s,
        ν i = some s ∧
          Benitoite.Release.Refinement.Term.observe ξ s = ζ i ∧ Benitoite.Release.Refinement.Term.interpret ξ s = ζ i) →
    Benitoite.Release.Refinement.Pred.interpret ξ (Benitoite.Release.Refinement.predBind ν p) =
      Benitoite.Release.Refinement.Pred.interpret ζ p
@Benitoite.Release.Refinement.TypedMeaning.toTerm_interpret : ∀ {v : Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Term},
  v.toTerm? = some t →
    ∀ (η : Benitoite.Release.Refinement.ObservationEnvModel),
      Benitoite.Release.Refinement.Term.interpret η t = Benitoite.Release.Refinement.Term.observe η t
@Benitoite.Release.Refinement.TypedMeaning.refine_bridge : ∀ {v : Benitoite.Release.Refinement.Val}
  {t : Benitoite.Release.Refinement.Term} {η : Benitoite.Release.Refinement.ObservationEnvModel}
  {p : Benitoite.Release.Refinement.Pred},
  v.toTerm? = some t →
    t.Closed →
      Benitoite.Release.Refinement.Pred.interpret η (p.open t) = true →
        Benitoite.Release.Refinement.Pred.interpret (Benitoite.Release.Refinement.selfModel η v) p = true
Benitoite.Release.Refinement.TypedMeaning.const_norm : ∀ (c : Benitoite.Release.Refinement.Const), c.type.norm = c.type
Benitoite.Release.Refinement.TypedMeaning.const_meaning : ∀ (P : Benitoite.Release.Refinement.Program)
  (η : Benitoite.Release.Refinement.ObservationEnvModel) (c : Benitoite.Release.Refinement.Const),
  Benitoite.Release.Refinement.ValueMeaning P η c.type (Benitoite.Release.Refinement.Val.const c)
@Benitoite.Release.Refinement.TypedMeaning.closed_of_refs : ∀ {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.Term.References [] t → t.Closed
@Benitoite.Release.Refinement.TypedMeaning.typed_meaning_aux : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a →
      Γ = [] → Φ = [] → Benitoite.Release.Refinement.ValueMeaning P (fun x => none) a v
@Benitoite.Release.Refinement.TypedMeaning.typed_meaning_auxs : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as →
      Γ = [] → Φ = [] → Benitoite.Release.Refinement.ValueMeanings P (fun x => none) as vs
@Benitoite.Release.Refinement.TypedMeaning.typed_each_norm : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a →
      Γ = [] → Φ = [] → Benitoite.Release.Refinement.ValueMeaningEach P (fun x => none) a.norm vs
@Benitoite.Release.Refinement.typed_value_meaning_closed : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {v : Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a →
      Benitoite.Release.Refinement.ValueMeaning P (fun x => none) a v
@Benitoite.Release.Refinement.inhabits_of_typed : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {v : Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a →
      Benitoite.Release.Refinement.Inhabits P a.norm v
@Benitoite.Release.Refinement.inhabits_of_typed_raw : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {v : Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a →
      Benitoite.Release.Refinement.Inhabits P a v
@Benitoite.Release.Refinement.Capture.typed_coverage : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {a : Benitoite.Release.Refinement.Ty} {w : Benitoite.Release.Refinement.Val} {ps : List Benitoite.Release.Pat}
  {cap : Benitoite.Release.Refinement.Capture},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] w (cap.closeTy a) →
      Benitoite.Release.Refinement.Exhaustive P a ps →
        ∃ p, p ∈ ps ∧ (Benitoite.Release.Refinement.matchVal p w).isSome = true
@Benitoite.Release.Refinement.CaptureOk.typed_variable_coverage : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {R : Option Benitoite.Release.Refinement.Ty} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {cap : Benitoite.Release.Refinement.Capture} {i : Nat}
  {a : Benitoite.Release.Refinement.Ty} {ps : List Benitoite.Release.Pat},
  P.VarianceValid →
    Benitoite.Release.Refinement.CaptureOk P B Ψ R Γ Φ cap →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] Γ Φ
          (Benitoite.Release.Refinement.Val.var i) a →
        Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
          Ψ.WF →
            Benitoite.Release.Refinement.Exhaustive P a ps →
              ∃ p,
                p ∈ ps ∧
                  (Benitoite.Release.Refinement.matchVal p
                        (Benitoite.Release.Refinement.closeVal cap (Benitoite.Release.Refinement.Val.var i))).isSome =
                    true
@Benitoite.Release.Refinement.Capture.typed_meaning : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {cap : Benitoite.Release.Refinement.Capture} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        (Benitoite.Release.Refinement.closeVal cap v) (cap.closeTy a) →
      Benitoite.Release.Refinement.ValueMeaning P (fun x => none) (cap.closeTy a)
          (Benitoite.Release.Refinement.closeVal cap v) ∧
        Benitoite.Release.Refinement.Inhabits P a (Benitoite.Release.Refinement.closeVal cap v)
Benitoite.Release.Refinement.TypedMeaningExamples.month_typed : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
    (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩))
    Benitoite.Release.Refinement.monthType
@Benitoite.Release.Refinement.TypedMeaningExamples.typed_entries : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {a : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a →
      Benitoite.Release.Refinement.ValueMeaning P (fun x => none) a v ∧
        Benitoite.Release.Refinement.Inhabits P a.norm v ∧
          Benitoite.Release.Refinement.Inhabits P a v ∧
            Benitoite.Release.Refinement.ValueMeaning P (fun x => none) a.norm v
Benitoite.Release.Refinement.TypedMeaningExamples.month_entries : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    Benitoite.Release.Refinement.ValueMeaning P (fun x => none) Benitoite.Release.Refinement.monthType
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩)) ∧
      Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.monthType.norm
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩)) ∧
        Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.monthType
            (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩)) ∧
          ∃ p,
            p ∈ [Benitoite.Release.Refinement.monthPattern] ∧
              (Benitoite.Release.Refinement.matchVal p
                    (Benitoite.Release.Refinement.Val.const
                      (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩))).isSome =
                true
@Benitoite.Release.Refinement.TypedMeaningExamples.empty_entries : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {a : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v
        (a.refined Benitoite.Release.Refinement.Pred.falsity) →
      False
Benitoite.Release.Refinement.TypedMeaningExamples.nonempty_entries : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    ∀ (k : Nat),
      0 < k →
        Benitoite.Release.Refinement.ValueMeaning P (fun x => none)
            (Benitoite.Release.Refinement.nonemptyType Benitoite.Release.Refinement.unobservableFunctionType)
            (Benitoite.Release.Refinement.Val.list
              (List.replicate k Benitoite.Release.Refinement.unobservableFunction)) ∧
          Benitoite.Release.Refinement.Inhabits P
              (Benitoite.Release.Refinement.nonemptyType Benitoite.Release.Refinement.unobservableFunctionType).norm
              (Benitoite.Release.Refinement.Val.list
                (List.replicate k Benitoite.Release.Refinement.unobservableFunction)) ∧
            Benitoite.Release.Refinement.Inhabits P
                (Benitoite.Release.Refinement.nonemptyType Benitoite.Release.Refinement.unobservableFunctionType)
                (Benitoite.Release.Refinement.Val.list
                  (List.replicate k Benitoite.Release.Refinement.unobservableFunction)) ∧
              ∃ p,
                p ∈ [Benitoite.Release.Refinement.headRestPattern] ∧
                  (Benitoite.Release.Refinement.matchVal p
                        (Benitoite.Release.Refinement.Val.list
                          (List.replicate k Benitoite.Release.Refinement.unobservableFunction))).isSome =
                    true
Benitoite.Release.Refinement.TypedMeaningExamples.unknownTerm : Benitoite.Release.Refinement.Term
Benitoite.Release.Refinement.TypedMeaningExamples.unknownPredicate : Benitoite.Release.Refinement.Pred
Benitoite.Release.Refinement.TypedMeaningExamples.unknownType : Benitoite.Release.Refinement.Ty
Benitoite.Release.Refinement.TypedMeaningExamples.unknown_eval : ∀ (v : Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.Pred.evalWith (Benitoite.Release.Refinement.selfModel (fun x => none) v)
      Benitoite.Release.Refinement.TypedMeaningExamples.unknownPredicate =
    none
Benitoite.Release.Refinement.TypedMeaningExamples.unknown_typed : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
    (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩))
    Benitoite.Release.Refinement.TypedMeaningExamples.unknownType
Benitoite.Release.Refinement.TypedMeaningExamples.unknown_entries : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    Benitoite.Release.Refinement.ValueMeaning P (fun x => none)
        Benitoite.Release.Refinement.TypedMeaningExamples.unknownType
        (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩)) ∧
      Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.TypedMeaningExamples.unknownType.norm
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩)) ∧
        Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.TypedMeaningExamples.unknownType
            (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩)) ∧
          Benitoite.Release.Refinement.Pred.evalWith
              (Benitoite.Release.Refinement.selfModel (fun x => none)
                (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer ⟨5, ⋯⟩)))
              Benitoite.Release.Refinement.TypedMeaningExamples.unknownPredicate =
            none
Benitoite.Release.Refinement.TypedMeaningExamples.five : Benitoite.Release.Refinement.Val
Benitoite.Release.Refinement.TypedMeaningExamples.thirteen : Benitoite.Release.Refinement.Val
@Benitoite.Release.Refinement.TypedMeaningExamples.thirteen_rejected : ∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.monthType
      Benitoite.Release.Refinement.TypedMeaningExamples.thirteen →
    False
@Benitoite.Release.Refinement.TypedMeaningExamples.reject_top : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy},
  P.VarianceValid →
    ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        Benitoite.Release.Refinement.TypedMeaningExamples.thirteen Benitoite.Release.Refinement.monthType
@Benitoite.Release.Refinement.TypedMeaningExamples.reject_list : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy},
  P.VarianceValid →
    ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        (Benitoite.Release.Refinement.Val.list [Benitoite.Release.Refinement.TypedMeaningExamples.thirteen])
        Benitoite.Release.Refinement.monthType.list
Benitoite.Release.Refinement.TypedMeaningExamples.mapT : Benitoite.Release.Refinement.Ty
Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownTerm : Benitoite.Release.Refinement.Term
Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownPred : Benitoite.Release.Refinement.Pred
Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownType : Benitoite.Release.Refinement.Ty
Benitoite.Release.Refinement.TypedMeaningExamples.lamMap : Benitoite.Release.Refinement.Val
Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknown_eval : Benitoite.Release.Refinement.Pred.evalWith
    (Benitoite.Release.Refinement.selfModel (fun x => none) Benitoite.Release.Refinement.TypedMeaningExamples.lamMap)
    Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownPred =
  none
Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknown_typed : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  B.sat [] Benitoite.Release.Refinement.unobservableFunctionType.norm Benitoite.Release.TParam.keyC →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
      Benitoite.Release.Refinement.TypedMeaningExamples.lamMap
      Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownType
Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknown_entries : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    B.sat [] Benitoite.Release.Refinement.unobservableFunctionType.norm Benitoite.Release.TParam.keyC →
      Benitoite.Release.Refinement.ValueMeaning P (fun x => none)
          Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownType
          Benitoite.Release.Refinement.TypedMeaningExamples.lamMap ∧
        Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownType.norm
            Benitoite.Release.Refinement.TypedMeaningExamples.lamMap ∧
          Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownType
            Benitoite.Release.Refinement.TypedMeaningExamples.lamMap
Benitoite.Release.Refinement.TypedMeaningExamples.unknown_not_excluded : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    B.sat [] Benitoite.Release.Refinement.unobservableFunctionType.norm Benitoite.Release.TParam.keyC →
      ¬Benitoite.Release.Refinement.Exhaustive P Benitoite.Release.Refinement.TypedMeaningExamples.selfUnknownType []
Benitoite.Release.Refinement.TypedMeaningExamples.depPred : Benitoite.Release.Refinement.Pred
Benitoite.Release.Refinement.TypedMeaningExamples.depType : Benitoite.Release.Refinement.Ty
Benitoite.Release.Refinement.TypedMeaningExamples.cap5 : Benitoite.Release.Refinement.Capture
Benitoite.Release.Refinement.TypedMeaningExamples.close_depType : Benitoite.Release.Refinement.TypedMeaningExamples.cap5.closeTy
    Benitoite.Release.Refinement.TypedMeaningExamples.depType =
  (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer).refined
    (Benitoite.Release.Refinement.Pred.eq (Benitoite.Release.Refinement.Term.var 0)
      (Benitoite.Release.Refinement.Term.integer 5))
Benitoite.Release.Refinement.TypedMeaningExamples.dependent_capture_entries : ∀
  (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    Benitoite.Release.Refinement.ValueMeaning P (fun x => none)
        (Benitoite.Release.Refinement.TypedMeaningExamples.cap5.closeTy
          Benitoite.Release.Refinement.TypedMeaningExamples.depType)
        Benitoite.Release.Refinement.TypedMeaningExamples.five ∧
      Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.TypedMeaningExamples.depType
        Benitoite.Release.Refinement.TypedMeaningExamples.five
Benitoite.Release.Refinement.TypedMeaningExamples.cap_month : ∀ (P : Benitoite.Release.Refinement.Program)
  (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    (Benitoite.Release.Refinement.ValueMeaning P (fun x => none)
          (Benitoite.Release.Refinement.TypedMeaningExamples.cap5.closeTy Benitoite.Release.Refinement.monthType)
          Benitoite.Release.Refinement.TypedMeaningExamples.five ∧
        Benitoite.Release.Refinement.Inhabits P Benitoite.Release.Refinement.monthType
          Benitoite.Release.Refinement.TypedMeaningExamples.five) ∧
      ∃ p,
        p ∈ [Benitoite.Release.Refinement.monthPattern] ∧
          (Benitoite.Release.Refinement.matchVal p Benitoite.Release.Refinement.TypedMeaningExamples.five).isSome = true
Benitoite.Release.Refinement.TypedMeaningExamples.nonempty_capture_coverage : ∀
  (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  P.VarianceValid →
    ∀ (k : Nat),
      0 < k →
        ∃ p,
          p ∈ [Benitoite.Release.Refinement.headRestPattern] ∧
            (Benitoite.Release.Refinement.matchVal p
                  (Benitoite.Release.Refinement.closeVal
                    (Benitoite.Release.Refinement.Capture.empty.extend
                      (Benitoite.Release.Refinement.Val.list
                        (List.replicate k Benitoite.Release.Refinement.unobservableFunction)))
                    (Benitoite.Release.Refinement.Val.var 0))).isSome =
              true
@Benitoite.Release.Refinement.PatternBindings.observable_annotation : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a →
    Γ = [] → (∃ s, a.HasSort s) → Benitoite.Release.Refinement.Ty.Annotation P C Γ a
@Benitoite.Release.Refinement.PatternBindings.refined_annotation : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a →
    Γ = [] → a.refinementPredicates ≠ [] → Benitoite.Release.Refinement.Ty.Annotation P C Γ a
@Benitoite.Release.Refinement.PatternBindings.notCont_of_predicates : ∀ {a : Benitoite.Release.Refinement.Ty}
  {nr nt nv : Nat}, Benitoite.Release.Refinement.Ty.WF nr nt nv a → a.refinementPredicates ≠ [] → a.NotContCore
@Benitoite.Release.Refinement.PatternBindings.annotation_norm_subset : ∀ {P : Benitoite.Release.Refinement.Program}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {a b : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.Ty.Annotation P C Γ a →
    a.core = b.norm.core →
      (∀ (p : Benitoite.Release.Refinement.Pred), p ∈ b.refinementPredicates → p ∈ a.refinementPredicates) →
        Benitoite.Release.Refinement.Ty.Annotation P C Γ b.norm
@Benitoite.Release.Refinement.PatternBindings.forget_refined : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.Refinement.Pred},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v (a.refined p).norm →
    Γ = [] → Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a.norm
@Benitoite.Release.Refinement.PatternBindings.args_ordinary : ∀ {P : Benitoite.Release.Refinement.Program}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {vars : List Benitoite.Release.Refinement.Variance} {xs ys : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.TypeArgsLe P Γ Φ vars xs ys →
    (∀ (a : Benitoite.Release.Refinement.Ty), a ∈ xs → Benitoite.Release.Refinement.Ordinary a) →
      ∀ (b : Benitoite.Release.Refinement.Ty), b ∈ ys → Benitoite.Release.Refinement.Ordinary b
@Benitoite.Release.Refinement.PatternBindings.values_of_get : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  vs.length = as.length →
    (∀ (i : Nat) (a : Benitoite.Release.Refinement.Ty),
        as[i]? = some a → ∃ v, vs[i]? = some v ∧ Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a) →
      Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as
@Benitoite.Release.Refinement.PatternBindings.constructor_values : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx}
  {Γ : List (Option Benitoite.Release.Refinement.Ty)} {Φ : List Benitoite.Release.Refinement.Pred}
  {c : Benitoite.Release.ConName} {tys : List Benitoite.Release.Refinement.Ty}
  {vs : List Benitoite.Release.Refinement.Val} {cd : Benitoite.Release.Refinement.ConDecl}
  {ts : List Benitoite.Release.Refinement.Ty},
  P.VarianceValid →
    Γ = [] →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.con c tys vs)
          (Benitoite.Release.Refinement.Ty.data cd.data ts) →
        P.cons c = some cd →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs
            (List.map (Benitoite.Release.Refinement.Ty.subst ts []) cd.args)
@Benitoite.Release.Refinement.PatternBindings.atError_declaration : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {detail : Benitoite.Release.Refinement.AtError}
  {a : Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a →
    v = Benitoite.Release.Refinement.Val.atError detail →
      ∃ cd, P.cons "Scope.ScopeError.At" = some cd ∧ cd.ntys = 0 ∧ cd.args = Benitoite.Release.Refinement.atErrorFields
@Benitoite.Release.Refinement.PatternBindings.each_of_mem : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  (∀ (v : Benitoite.Release.Refinement.Val), v ∈ vs → Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v a) →
    Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a
@Benitoite.Release.Refinement.PatternBindings.list_elements : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ (Benitoite.Release.Refinement.Val.list vs) a.list.norm →
    Γ = [] →
      Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a.norm ∧
        Benitoite.Release.Refinement.Ty.Annotation P C Γ a.norm
@Benitoite.Release.Refinement.PatternBindings.values_append : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs ws : List Benitoite.Release.Refinement.Val}
  {as bs : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as →
    Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ ws bs →
      Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ (vs ++ ws) (as ++ bs)
@Benitoite.Release.Refinement.PatternBindings.values_replicate : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {n : Nat},
  Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q C Γ Φ vs a →
    vs.length = n → Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs (List.replicate n a)
@Benitoite.Release.Refinement.pattern_bindings_aux : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy} {p : Benitoite.Release.Pat}
  {a : Benitoite.Release.Refinement.Ty} {δ : List Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.PatTy P p a δ →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a.norm →
        Benitoite.Release.Refinement.matchVal p v = some ws →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
            (List.map Benitoite.Release.Refinement.Ty.norm δ)
@Benitoite.Release.Refinement.patterns_bindings_aux : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ps : List Benitoite.Release.Pat} {as δ : List Benitoite.Release.Refinement.Ty}
  {vs ws : List Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.PatTys P ps as δ →
      Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] vs
          (List.map Benitoite.Release.Refinement.Ty.norm as) →
        Benitoite.Release.Refinement.matchList ps vs = some ws →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
            (List.map Benitoite.Release.Refinement.Ty.norm δ)
@Benitoite.Release.Refinement.pattern_bindings_typed : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy} {p : Benitoite.Release.Pat}
  {a : Benitoite.Release.Refinement.Ty} {δ : List Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.PatTy P p a δ →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a.norm →
        Benitoite.Release.Refinement.matchVal p v = some ws →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
            (List.map Benitoite.Release.Refinement.Ty.norm δ)
@Benitoite.Release.Refinement.patterns_bindings_typed : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ps : List Benitoite.Release.Pat} {as δ : List Benitoite.Release.Refinement.Ty}
  {vs ws : List Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.PatTys P ps as δ →
      Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] vs
          (List.map Benitoite.Release.Refinement.Ty.norm as) →
        Benitoite.Release.Refinement.matchList ps vs = some ws →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
            (List.map Benitoite.Release.Refinement.Ty.norm δ)
@Benitoite.Release.Refinement.HasTypeVsQ.select_slots : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Q : Benitoite.Release.NoFailCtx} {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty} {slots : List Nat} {bs : List Benitoite.Release.Refinement.Ty}
  {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as →
    Benitoite.Release.Refinement.selectSlots as slots = some bs →
      Benitoite.Release.Refinement.selectSlots vs slots = some ws →
        Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ ws bs
@Benitoite.Release.Refinement.alternatives_bindings_typed : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty} {δ : List Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.AltsTy P alts a δ →
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] v a.norm →
        Benitoite.Release.Refinement.firstAlt v alts = some ws →
          Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
            (List.map Benitoite.Release.Refinement.Ty.norm δ)
Benitoite.Release.Refinement.pattern_length_relation : ∀ (vs ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.matchVal
        (Benitoite.Release.Pat.list [Benitoite.Release.Pat.var] (some Benitoite.Release.ListRest.bind) [])
        (Benitoite.Release.Refinement.Val.list vs) =
      some ws →
    ∃ v rest, vs = v :: rest ∧ ws = [v, Benitoite.Release.Refinement.Val.list rest] ∧ vs.length = rest.length + 1
Benitoite.Release.Refinement.pattern_length_close : ∀ (cap : Benitoite.Release.Refinement.Capture)
  (vs ws : List Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.headRestPattern
        (Benitoite.Release.Refinement.Val.list vs) =
      some ws →
    ∃ v rest,
      vs = v :: rest ∧
        ws = [v, Benitoite.Release.Refinement.Val.list rest] ∧
          Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.headRestPattern
                (Benitoite.Release.Refinement.closeVal cap (Benitoite.Release.Refinement.Val.list vs)) =
              some
                [Benitoite.Release.Refinement.closeVal cap v,
                  Benitoite.Release.Refinement.Val.list (Benitoite.Release.Refinement.closeVals cap rest)] ∧
            (Benitoite.Release.Refinement.closeVal cap v).toTerm? =
                (Benitoite.Release.Refinement.Val.subst cap.env v).toTerm? ∧
              (Benitoite.Release.Refinement.closeVal cap (Benitoite.Release.Refinement.Val.list rest)).toTerm? =
                  (Benitoite.Release.Refinement.Val.subst cap.env
                      (Benitoite.Release.Refinement.Val.list rest)).toTerm? ∧
                (Benitoite.Release.Refinement.closeVals cap vs).length =
                  (Benitoite.Release.Refinement.closeVals cap rest).length + 1
@Benitoite.Release.Refinement.pattern_bindings_ground : ∀ {p : Benitoite.Release.Pat}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  v.Ground →
    Benitoite.Release.Refinement.matchVal p v = some ws → ∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground
@Benitoite.Release.Refinement.patterns_bindings_ground : ∀ {ps : List Benitoite.Release.Pat}
  {vs ws : List Benitoite.Release.Refinement.Val},
  (∀ (v : Benitoite.Release.Refinement.Val), v ∈ vs → v.Ground) →
    Benitoite.Release.Refinement.matchList ps vs = some ws → ∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground
@Benitoite.Release.Refinement.alternatives_bindings_ground : ∀ {alts : List Benitoite.Release.Alt}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  v.Ground →
    Benitoite.Release.Refinement.firstAlt v alts = some ws → ∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → w.Ground
@Benitoite.Release.Refinement.head_rest_bindings_typed : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {a : Benitoite.Release.Refinement.Ty} {vs ws : List Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        (Benitoite.Release.Refinement.Val.list vs) a.list.norm →
      Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.headRestPattern
            (Benitoite.Release.Refinement.Val.list vs) =
          some ws →
        ∃ v rest,
          vs = v :: rest ∧
            ws = [v, Benitoite.Release.Refinement.Val.list rest] ∧
              vs.length = rest.length + 1 ∧
                Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] []
                  [v, Benitoite.Release.Refinement.Val.list rest] [a.norm, a.norm.list]
@Benitoite.Release.Refinement.head_rest_close_typed : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {a : Benitoite.Release.Refinement.Ty} {vs ws : List Benitoite.Release.Refinement.Val}
  {cap : Benitoite.Release.Refinement.Capture},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        (Benitoite.Release.Refinement.closeVal cap (Benitoite.Release.Refinement.Val.list vs)) (cap.closeTy a.list) →
      Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.headRestPattern
            (Benitoite.Release.Refinement.Val.list vs) =
          some ws →
        ∃ v rest,
          vs = v :: rest ∧
            ws = [v, Benitoite.Release.Refinement.Val.list rest] ∧
              Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] []
                  [Benitoite.Release.Refinement.closeVal cap v,
                    Benitoite.Release.Refinement.Val.list (Benitoite.Release.Refinement.closeVals cap rest)]
                  [(cap.closeTy a).norm, (cap.closeTy a).norm.list] ∧
                (Benitoite.Release.Refinement.closeVal cap v).toTerm? =
                    (Benitoite.Release.Refinement.Val.subst cap.env v).toTerm? ∧
                  (Benitoite.Release.Refinement.closeVal cap (Benitoite.Release.Refinement.Val.list rest)).toTerm? =
                      (Benitoite.Release.Refinement.Val.subst cap.env
                          (Benitoite.Release.Refinement.Val.list rest)).toTerm? ∧
                    (Benitoite.Release.Refinement.closeVals cap vs).length =
                      (Benitoite.Release.Refinement.closeVals cap rest).length + 1
@Benitoite.Release.Refinement.head_rest_two : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {a : Benitoite.Release.Refinement.Ty} {v₀ v₁ : Benitoite.Release.Refinement.Val},
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
        (Benitoite.Release.Refinement.Val.list [v₀, v₁]) a.list.norm →
      Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] []
          [v₀, Benitoite.Release.Refinement.Val.list [v₁]] [a.norm, a.norm.list] ∧
        Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.headRestPattern
              (Benitoite.Release.Refinement.Val.list [v₀, v₁]) =
            some [v₀, Benitoite.Release.Refinement.Val.list [v₁]] ∧
          Benitoite.Release.Refinement.matchVal Benitoite.Release.Refinement.headRestPattern
              (Benitoite.Release.Refinement.Val.list []) =
            none
@Benitoite.Release.Refinement.month_variable_coverage : ∀ {P : Benitoite.Release.Refinement.Program}
  {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy},
  P.VarianceValid →
    Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
      Ψ.WF →
        ∃ p,
          p ∈ [Benitoite.Release.Refinement.monthPattern] ∧
            (Benitoite.Release.Refinement.matchVal p Benitoite.Release.Refinement.TypedMeaningExamples.five).isSome =
              true
```

非公開の補助の完全署名は次のとおりである。

```lean
private theorem ground_list_iff (vs : List Val) :
    Val.ClosedList 0 0 vs ↔ ∀ v ∈ vs, v.Ground
```
