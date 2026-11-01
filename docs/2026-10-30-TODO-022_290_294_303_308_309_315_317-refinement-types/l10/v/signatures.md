# 群 V の署名と決定の記録

2026-11-01。指定ブランチは `m014/l10.v`、B_WORK は `c668ff024b99287de702c5823c6280f8130a6aa5` である。git による照合・操作は行わない。初回に確定した契約をレビューの所見に従って更新した。以下は現在の契約である。完全な型は [signatures.lean](signatures.lean) の `#check @…` と [signatures-output.txt](signatures-output.txt) に保存する。名前空間は `Benitoite.Release.Refinement` とする。

## 宣言と構造検証

```lean
inductive Variance where
  | covariant | contravariant | invariant
inductive Polarity where
  | positive | negative | both
structure DataVarianceDecl where
  arity : Nat
  variances : List Variance
  requirements : List Ty
  publicBoundary : List (Polarity × Ty)
-- Program の既存七欄に追加する。
-- dataInfo : DataName → Option DataVarianceDecl := fun _ => none
def Program.varianceFor (P : Program) (d : DataName) (n : Nat) : List Variance
def Ty.VarianceOK (P : Program) (vs : List Variance)
    (polarity : Polarity) (a : Ty) : Prop
def Tel.VarianceOK (P : Program) (vs : List Variance)
    (polarity : Polarity) (t : Tel) : Prop
def Eff.VarianceOK (P : Program) (vs : List Variance)
    (polarity : Polarity) (e : Eff) : Prop
def Ty.ParamOccurs (i : Nat) (a : Ty) : Prop
def Program.ParamOccursInFields (P : Program) (d : DataName) (i : Nat) : Prop :=
  ∃ c cd a, P.cons c = some cd ∧ cd.data = d ∧
    a ∈ cd.args ∧ a.ParamOccurs i
def Program.VarianceValid (P : Program) : Prop :=
  (∀ d info, P.dataInfo d = some info →
    info.variances.length = info.arity ∧
    (∀ i variance, info.variances[i]? = some variance →
      (¬ P.ParamOccursInFields d i → variance = .invariant)) ∧
    (∀ a ∈ info.requirements, Ty.VarianceOK P info.variances .both a) ∧
    (∀ item ∈ info.publicBoundary,
      Ty.VarianceOK P info.variances item.1 item.2)) ∧
  (∀ c cd, P.cons c = some cd →
    (∀ info, P.dataInfo cd.data = some info → info.arity = cd.ntys) ∧
    (∀ a ∈ cd.args,
      Ty.Annotation P (List.replicate cd.ntys ({} : TParam)) [] a ∧
      Ty.HasKind P (List.replicate cd.ntys .value) a .value ∧
      Ty.VarianceOK P (P.varianceFor cd.data cd.ntys) .positive a))
```

`DataName`・`TParam` は既存の `Benitoite.Release` の名前を使う。`requirements` と `publicBoundary` の収集が原ソースを尽くすことは、L70/R10b の照合に残す。空の metadata を収集の完全性の証拠にしない。

## 部分型の相互四族

```lean
mutual
inductive Ty.LeQ (P : Program) : Ctx → List Pred → Ty → Ty → Prop where
  | refl {Γ Φ a} : Ty.LeQ P Γ Φ a a
  | convert {Γ Φ a b} : a.norm = b.norm → Ty.LeQ P Γ Φ a b
  | trans {Γ Φ a b c} : Ty.LeQ P Γ Φ a b → Ty.LeQ P Γ Φ b c → Ty.LeQ P Γ Φ a c
  | fn_effect {Γ Φ ns ps r ε ε'} : Eff.Covers Γ Φ ε' ε →
      Ty.LeQ P Γ Φ (.fn ns ps r ε) (.fn ns ps r ε')
  | list {Γ Φ a b} : Ty.LeQ P Γ Φ a b → Ty.LeQ P Γ Φ (.list a) (.list b)
  | lazy {Γ Φ a b} : Ty.LeQ P Γ Φ a b → Ty.LeQ P Γ Φ (.lazy a) (.lazy b)
  | map_value {Γ Φ k k' a b} : k = k' → Ty.LeQ P Γ Φ a b →
      Ty.LeQ P Γ Φ (.map k a) (.map k' b)
  | forget {Γ Φ a p} : Ty.LeQ P Γ Φ (.refined a p) a
  | introduce {Γ Φ a p} : p.Sorted Γ (some a) → Entails (assumptions Γ Φ a) p →
      Ty.LeQ P Γ Φ a (.refined a p)
  | refine {Γ Φ a b p q} : Ty.LeQ P Γ Φ a b → p.Sorted Γ (some a) →
      q.Sorted Γ (some b) → Entails (p :: assumptions Γ Φ a) q →
      Ty.LeQ P Γ Φ (.refined a p) (.refined b q)
  | dependentFn {Γ Φ t u} : TelClosure P Γ Φ t u →
      Ty.LeQ P Γ Φ (.dependentFn t) (.dependentFn u)
  | scoped {Γ Φ o k inner outer} : RangeIx.Covers outer inner →
      Ty.LeQ P Γ Φ (.scoped o k inner) (.scoped o k outer)
  | scoped_forget {Γ Φ o k ix} : Ty.LeQ P Γ Φ (.scoped o k ix) (.opaque o ix)
  | data {Γ Φ d as bs} : TypeArgsLe P Γ Φ (P.varianceFor d as.length) as bs →
      Ty.LeQ P Γ Φ (.data d as) (.data d bs)
inductive TelLe (P : Program) : Ctx → List Pred → Tel → Tel → Prop where
  | done {Γ Φ r s e f} : Ty.LeQ P Γ Φ r s → Eff.Covers Γ Φ f e →
      TelLe P Γ Φ (.done r e) (.done s f)
  | param {Γ Φ n a b t u} : Ty.LeQ P Γ Φ b a →
      TelLe P (Γ.extend b) (Φ.map Pred.lift) t u →
      TelLe P Γ Φ (.param n a t) (.param n b u)
inductive TelClosure (P : Program) : Ctx → List Pred → Tel → Tel → Prop where
  | refl {Γ Φ t} : TelClosure P Γ Φ t t
  | tail {Γ Φ t u v} : TelClosure P Γ Φ t u → TelLe P Γ Φ u v → TelClosure P Γ Φ t v
inductive TypeArgsLe (P : Program) :
    Ctx → List Pred → List Variance → List Ty → List Ty → Prop where
  | nil {Γ Φ} : TypeArgsLe P Γ Φ [] [] []
  | covariant_cons {Γ Φ vs a b as bs} : Ty.LeQ P Γ Φ a b →
      TypeArgsLe P Γ Φ vs as bs → TypeArgsLe P Γ Φ (.covariant :: vs) (a :: as) (b :: bs)
  | contravariant_cons {Γ Φ vs a b as bs} : Ty.LeQ P Γ Φ b a →
      TypeArgsLe P Γ Φ vs as bs → TypeArgsLe P Γ Φ (.contravariant :: vs) (a :: as) (b :: bs)
  | invariant_cons {Γ Φ vs a b as bs} : a.norm = b.norm →
      TypeArgsLe P Γ Φ vs as bs → TypeArgsLe P Γ Φ (.invariant :: vs) (a :: as) (b :: bs)
end
```

既存の13+2+2規則に `P` を渡し、data の1規則と型引数列の4規則を加える。`Eff.Covers`・`Eff.Sub`・`assumptions` は現行の署名を保つ。

## 単調性と形成の分離

中2の修正では、単調性の前提を総称の欄の `Sorted` と通常値の型像に替えた。`VarianceValid`・`VarianceSubstInput`・具体化後の欄の注釈を単調性へ渡す旧契約は廃止した。

```lean
theorem variance_field_mono (P : Program) (Γ Φ) (vs : List Variance) (a : Ty) (as bs : List Ty)
    (occurs : Ty.VarianceOK P vs .positive a) (wf : a.WF 0 vs.length 0)
    (generic : a.Sorted [])
    (oa : ∀ t ∈ as, Ordinary t) (ob : ∀ t ∈ bs, Ordinary t)
    (args : TypeArgsLe P Γ Φ vs as bs) :
    Ty.LeQ P Γ Φ (a.subst as []) (a.subst bs [])
theorem Ty.VarianceOK.mono {P Γ Φ vs θ τ G} (a : Ty) (p : Polarity)
      (h : a.VarianceOK P vs p) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : a.WF nr nt nv)
      (hg : a.Sorted G) (hm : SortMap G Γ) (hi : OrdinaryTypeImages θ τ) :
      p.Rel P Γ Φ (a.rawBind θ) (a.rawBind τ)
theorem Tel.VarianceOK.mono {P Γ Φ vs θ τ G} (t : Tel) (p : Polarity)
      (h : t.VarianceOK P vs p) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : t.WF nr nt nv)
      (hg : Tel.Sorted G t) (hm : SortMap G Γ) (hi : OrdinaryTypeImages θ τ) :
      p.TelRel P Γ Φ (Tel.rawBind θ t) (Tel.rawBind τ t)
```

`OrdinaryTypeImages θ τ` は両環境の型像が `Ordinary` であり、値の像が恒等であることを要求する。`VarianceEnvRel` は同じ P・Γ・Φ の下の型像の対応と、行・範囲・値の像の等号を持つ。`SortMap G Γ` は sort と通常値の可読性だけを移し、事実の包含は要求しない。Tel の param では二つの具体化した束縛型へ `SortMap` を延長する。

`TypeArgsLe.trans` の中間の型引数に形成や `Ordinary` を追加しない。境界の `field_mono_trans` は中間列 ms にそのいずれも仮定せず、推移後の対応を `variance_field_mono` に渡す。

## 型代入の形成

中1の修正で `TypeFormation` を本番へ追加した。総称の欄の形成と kind は `VarianceValid` から取り出し、呼出し側は型引数の形成・個数・`Ordinary` を供給する。欄ごとの `Annotation` を呼出し側の仮定にしない。

```lean
theorem Ty.Annotation.subst_types_closed {P C n a Γ xs}
    (h : Ty.Annotation P (List.replicate n ({} : TParam)) [] a) (hk : a.HasKind P (List.replicate n .value) .value)
    (valid : P.VarianceValid) (hl : xs.length = n) (ht : TypeAnnotations P C Γ xs)
    (ho : ∀ t ∈ xs, Ordinary t) : Ty.Annotation P C Γ (a.subst xs [])
theorem Program.VarianceValid.field_annotation {P C Γ c cd a xs} (valid : P.VarianceValid)
    (hc : P.cons c = some cd) (ha : a ∈ cd.args) (hl : xs.length = cd.ntys)
    (ht : TypeAnnotations P C Γ xs) (ho : ∀ t ∈ xs, Ordinary t) : Ty.Annotation P C Γ (a.subst xs [])
```

`HasKind … .value` は継続型も含むため、通常値の型引数であることを kind だけから導く契約にはしない。`Ordinary` は補助の入力であり、`V_Con` 又は主な定理へ新しい前提を加えない。

`Ty.NoTapp` は型構成子変数の適用を含まないという内部の構造条件である。型構成子そのものを禁止しない。すべて value の kind 文脈で検査済みの欄から `Ty.HasKind.noTapp` で導けるので、`field_annotation` の利用者へ新しい構文の制限として要求しない。値・行・範囲を恒等に保つ `SubstEnv.typesOnly` を用い、WF・Sorted・Declared を別々に移した後に正規化する。

```lean
theorem Ty.subst_typesOnly_closed {n : Nat} {a : Ty} (hw : a.WF 0 n 0) (ha : a.NoTapp)
    (xs : List Ty) (hn : n ≤ xs.length) (f : Nat → Ty) :
    (a.subst xs []).bind (.typesOnly f) = a.subst (xs.map (Ty.bind (.typesOnly f))) []
theorem Term.HasData.typesOnly {P Γ Δ t d xs f} (h : Term.HasData P Γ t d xs)
    (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) :
    Term.HasData P Δ t d (xs.map (Ty.bind (.typesOnly f)))
theorem FieldRef.Declared.typesOnly {P C D Γ Δ t ref f} (h : FieldRef.Declared P C Γ t ref)
    (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) : FieldRef.Declared P D Δ t ref
theorem Term.Declared.typesOnly {P C D Γ Δ t f} (h : Term.Declared P C Γ t)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) : Term.Declared P D Δ t
theorem Pred.Declared.typesOnly {P C D Γ Δ self p f} (h : Pred.Declared P C Γ self p)
    (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) :
    Pred.Declared P D Δ (self.map (Ty.rawBind (.typesOnly f))) p
theorem Ty.Declared.typesOnly {P C D Γ Δ a f} (h : Ty.Declared P C Γ a) (ha : a.NoTapp)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, Ty.Declared P D Δ (f i)) :
      Ty.Declared P D Δ (a.rawBind (.typesOnly f))
```

`TypeFormationMap Γ Δ f` は、元の lookup の型 a を `a.rawBind (.typesOnly f)` へ写すことと、f の全像の `Ordinary` を保持する。param/self の下では f の値位置を一つ移し、写した束縛型で文脈を延長する。`Ty.Declared.typesOnly` の型像に必要なのは Declared であり、Sorted/WF はそれぞれの移送で要求する。NoTapp を持つ欄での二度の型代入の可換性を `subst_typesOnly_closed` で示し、HasData の field と FieldRef の枝に使う。

## 観測用の対応の型置換

`DataObservationLe` は、篩の事実や List などの子の型を捨てる観測の射影で比較する。完全な型引数の等号又は部分型を結論しない。`HasData.widen` の引数は、受け手が作られたときの実の引数とは限らない。

```lean
theorem Ty.observationType_rawBind_typesOnly (a : Ty) (f : Nat → Ty) :
      (a.rawBind (.typesOnly f)).observationType =
        (a.observationType.rawBind (.typesOnly (fun i => (f i).observationType))).observationType
theorem DataObservationLe.bind_typesOnly {P d as bs} (h : DataObservationLe P d as bs)
    (f : Nat → Ty) (ho : ∀ i, Ordinary (f i)) :
    DataObservationLe P d (as.map (Ty.bind (.typesOnly f))) (bs.map (Ty.bind (.typesOnly f)))
```

型置換の像も観測用に射影し、既存の `TypeArgsLe.rawBind` を適用した後、もう一度射影する。これにより、捨てた子の型を復元する前提を置かずに widen の型置換を閉じる。`Declared` と widen の docstring にこの境界を明記した。欄の sort を観測の行き先から元へ反映するには `Program.VarianceValid` が要ることを群 X へ引き継ぐ。

## 構成子の逆転と欄の利用

```lean
theorem HasTypeVQ.inv_con {P B Ψ Q C Γ Φ v T c ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .con c ts vs) :
    ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      TypeArgsKinded P C ts (List.replicate cd.ntys .value) ∧
      Ty.Annotation P C Γ (.data cd.data ts) ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) ∧
      ∃ us, T.norm.core = .data cd.data us ∧
        TypeArgsLe P Γ Φ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us
theorem HasTypeVQ.constructor_field_inputs {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid) (sourceOrd : ∀ t ∈ ts, Ordinary t)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t) :
    Ty.Annotation P C Γ (a.subst ts []) ∧ Ty.Annotation P C Γ (a.subst us []) ∧
      VarianceSubstInput P C Γ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us
theorem HasTypeVQ.con_field_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid) (sourceOrd : ∀ t ∈ ts, Ordinary t)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t) :
    ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst us [])
theorem HasTypeVQ.field_facts_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (valid : P.VarianceValid) (sourceOrd : ∀ t ∈ ts, Ordinary t)
    (targetTypes : TypeAnnotations P C Γ us) (targetOrd : ∀ t ∈ us, Ordinary t)
    (hs : (Val.toTermSlots vs)[i]? = some (some t)) :
    ∀ p ∈ (a.subst us []).assume, Entails (Γ.facts ++ Φ) (p.open t)
```

`inv_con` が保持する元の data の注釈から `Ty.Annotation.data_args` で型引数の注釈を得る。`constructor_field_inputs` は検証済みの総称の欄と両側の型引数から両側の欄の注釈と `VarianceSubstInput` を返す。`con_field_by_type` はこの出力の行き先の欄の注釈で `V_Sub` を作り、単調性には総称の欄と両端の `Ordinary` だけを使う。境界の `supplied_sourceField_and_inputs` と `field_widened` が実際の `V_Con → V_Sub` からこの呼出しを行う。

## 補助の契約で決めたこと

1. 三値の変性と極性を保ち、unused を置かない。読者のない `Polarity.join` は削除した。
2. 不変の比較は正規化後の等号とする。Reference・Map の鍵・Set・辞書・継続・外部型・型構成子の適用・Fail を不変として検査する。
3. 単調性と形成を分ける。単調性の推移の中間に注釈を要求せず、形成では総称の欄の注釈・kind、型引数の注釈・個数・Ordinary から具体化後の注釈を証明する。
4. `DataImages`・`DeclarationImages` の外形は維持し、観測の widen と完全な欄の型付けを区別する。型だけを代入する新しい移送は `TypeFormationMap` を用いる。
5. 型構成子変数の適用を含まないという内部条件は、検証済みの value-kind の総称の欄から導く。利用者の書ける形を新たに狭めない。
6. `HasTypeVQ`・`HasTypeCQ` の subst・subst_under_none・shift_values・shift_types・narrow の10定理の宣言を保つ。新しい公理・提供範囲・精密な外部状態を追加しない。
7. 新しい形成の補助を第六のモジュールへ分け、既定 import と ValueFacts から読む。metadata の収集の完全性は L70/R10b、WellTyped への格納は群 W に残す。

前の記録にあった「両側の具体化した欄の注釈を呼出し元に残す」という判断は、中1・中2により上の契約へ改めた。初回の L10.07・L10.08 の完了の記録は形成の未実装を見落としていた。今回の修正で本番の補題と実際の境界の呼出しを加えた。
