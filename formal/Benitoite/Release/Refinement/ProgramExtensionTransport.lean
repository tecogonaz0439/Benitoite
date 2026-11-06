import Benitoite.Release.Refinement.ProgramExtension

/-! # 旧宣言の移送の関係の下で、P の条件を P' へ移す

`Program.Extends P P'` の下で、型付けの規則の前提のうち P を読むもの（構成子の arity・kind・宣言の照合・部分型・
パターン・外部の宣言・節の署名）を P' へ移す（設計書 07-04「01-12 との対応」）。lookup を正の形で読む前提は lookup の
保存で移り、同じ data 型の全構成子を読む前提（`Program.DataArity`・外部の受渡し型）は `consClosed` で移る。
変性の宣言は、P に宣言のある data 型では `dataInfo` で同じであり、宣言のない data 型では P の不変の列の比較
（正規形の等号）がどの変性の比較にも移る。 -/
namespace Benitoite.Release.Refinement
noncomputable section

variable {P P' : Program}

namespace Program.Extends

theorem hasData (h : P.Extends P') {d : DataName} (hd : P.HasData d) : P'.HasData d := by
  rcases hd with ⟨c, cd, hc, he⟩ | hi
  · exact Or.inl ⟨c, cd, h.cons c cd hc, he⟩
  · obtain ⟨info, hi⟩ := Option.isSome_iff_exists.mp hi
    exact Or.inr (by simp [h.dataInfo d info hi])

theorem dataArity (h : P.Extends P') {d n} (hd : P.DataArity d n) : P'.DataArity d n := by
  obtain ⟨⟨c, cd, hc, he⟩, hall⟩ := hd
  refine ⟨⟨c, cd, h.cons c cd hc, he⟩, fun c' cd' hc' he' => hall c' cd' ?_ he'⟩
  exact h.consClosed c' cd' hc' (he' ▸ Or.inl ⟨c, cd, hc, he⟩)

theorem consData (h : P.Extends P') {c cd d} (hc : P'.cons c = some cd) (he : cd.data = d)
    (hd : P.HasData d) : P.cons c = some cd :=
  h.consClosed c cd hc (he ▸ hd)

theorem externalType (h : P.Extends P') (id : ExternalId) : P'.externalType id = P.externalType id := by
  simp only [Program.externalType, h.externals]

theorem externalFunction (h : P.Extends P') (f : ExternalFunctionId) :
    P'.externalFunction f = P.externalFunction f := by
  simp only [Program.externalFunction, h.externals]

end Program.Extends

theorem TyCon.arity_some_data {P : Program} {d n} (h : TyCon.arity P (.data d) = some n) : P.DataArity d n := by
  classical
  simp only [TyCon.arity] at h
  split at h
  · rename_i hex
    cases h
    exact Classical.choose_spec hex
  · cases h

theorem TyCon.arity_ofExtends (h : P.Extends P') {c : Benitoite.Release.TyCon} {n}
    (hc : TyCon.arity P c = some n) : TyCon.arity P' c = some n := by
  cases c with
  | data d => exact TyCon.arity_data (h.dataArity (TyCon.arity_some_data hc))
  | _ => exact hc

mutual
  theorem Ty.HasKind.ofExtends (h : P.Extends P') {K : KindCtx} {a : Ty} {k : TyKind}
      (hk : a.HasKind P K k) : a.HasKind P' K k := by
    cases k with
    | constructor n =>
      cases a <;> simp only [Ty.HasKind] at hk ⊢
      all_goals first | exact hk | exact TyCon.arity_ofExtends h hk
    | value =>
      cases a <;> simp only [Ty.HasKind] at hk ⊢
      all_goals first
        | trivial
        | exact hk
        | exact Ty.HasKind.ofExtends h hk
        | exact kindsList_ofExtends h hk
        | exact kindsTel_ofExtends h hk
        | skip
      case data d as => exact ⟨TyCon.arity_ofExtends h hk.1, kindsList_ofExtends h hk.2⟩
      case dict cl a =>
        obtain ⟨cd, hc, ha⟩ := hk
        exact ⟨cd, h.classes cl cd hc, Ty.HasKind.ofExtends h ha⟩
      case fn ns ps r e =>
        exact ⟨hk.1, kindsList_ofExtends h hk.2.1, Ty.HasKind.ofExtends h hk.2.2.1, kindsEff_ofExtends h hk.2.2.2⟩
      case cont b t e =>
        exact ⟨Ty.HasKind.ofExtends h hk.1, Ty.HasKind.ofExtends h hk.2.1, kindsEff_ofExtends h hk.2.2⟩
      case map a b => exact ⟨Ty.HasKind.ofExtends h hk.1, Ty.HasKind.ofExtends h hk.2⟩
      case tapp i as => exact ⟨hk.1, kindsList_ofExtends h hk.2⟩
      case refined a p => exact ⟨Ty.HasKind.ofExtends h hk.1, hk.2⟩
  theorem kindsTel_ofExtends (h : P.Extends P') {K : KindCtx} {t : Tel} (hk : kindsTel P K t) :
      kindsTel P' K t := by
    cases t with
    | done r e => exact ⟨Ty.HasKind.ofExtends h hk.1, kindsEff_ofExtends h hk.2⟩
    | param n a t => exact ⟨Ty.HasKind.ofExtends h hk.1, kindsTel_ofExtends h hk.2⟩
  theorem kindsList_ofExtends (h : P.Extends P') {K : KindCtx} {as : List Ty} (hk : kindsList P K as) :
      kindsList P' K as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.HasKind.ofExtends h hk.1, kindsList_ofExtends h hk.2⟩
  theorem kindsEff_ofExtends (h : P.Extends P') {K : KindCtx} {e : Eff} (hk : kindsEff P K e) :
      kindsEff P' K e := by
    cases e with
    | mk atoms fs => exact kindsList_ofExtends h hk
end

theorem TypeArgsKinded.ofExtends (h : P.Extends P') {C ts ks} (hk : TypeArgsKinded P C ts ks) :
    TypeArgsKinded P' C ts ks :=
  ⟨hk.1, fun i a k ha hk' => ⟨(hk.2 i a k ha hk').1.ofExtends h, (hk.2 i a k ha hk').2⟩⟩

/-! ## 変性と部分型 -/

/-- P の変性の列は、P' の同じ data 型の変性の列と一致するか、不変の列である。 -/
theorem Program.Extends.variance (h : P.Extends P') (d : DataName) (n : Nat) :
    P'.varianceFor d n = P.varianceFor d n ∨ P.varianceFor d n = List.replicate n .invariant := by
  cases hd : P.dataInfo d with
  | none => exact Or.inr (by simp [Program.varianceFor, hd])
  | some info => exact Or.inl (by simp [Program.varianceFor, hd, h.dataInfo d info hd])

/-- 不変の列の比較（正規形の等号）は、同じ長さのどの変性の列の比較でもある。 -/
theorem TypeArgsLe.of_invariant {Q : Program} {Γ Φ} : ∀ {vs as bs},
    TypeArgsLe Q Γ Φ (List.replicate vs.length .invariant) as bs → TypeArgsLe Q Γ Φ vs as bs
  | [], _, _, hl => by cases hl; exact .nil
  | v :: vs, _, _, hl => by
    cases hl with
    | invariant_cons he hs =>
      have hs' := TypeArgsLe.of_invariant (vs := vs) hs
      cases v
      · exact .covariant_cons (.convert he) hs'
      · exact .contravariant_cons (.convert he.symm) hs'
      · exact .invariant_cons he hs'

mutual
  theorem Ty.LeQ.ofExtends (h : P.Extends P') {Γ Φ a b} (hl : Ty.LeQ P Γ Φ a b) : Ty.LeQ P' Γ Φ a b := by
    match hl with
    | .refl => exact .refl
    | .convert he => exact .convert he
    | .trans h₁ h₂ => exact .trans (h₁.ofExtends h) (h₂.ofExtends h)
    | .fn_effect hc => exact .fn_effect hc
    | .list hl => exact .list (hl.ofExtends h)
    | .lazy hl => exact .lazy (hl.ofExtends h)
    | .map_value hk hl => exact .map_value hk (hl.ofExtends h)
    | .forget => exact .forget
    | .introduce hs he => exact .introduce hs he
    | .refine hl hp hq he => exact .refine (hl.ofExtends h) hp hq he
    | .dependentFn hc => exact .dependentFn (hc.ofExtends h)
    | .scoped hc => exact .scoped hc
    | .scoped_forget => exact .scoped_forget
    | .data (d := d) (as := as) ha =>
      have ha' := ha.ofExtends h
      rcases h.variance d as.length with he | he
      · exact .data (he ▸ ha')
      · rw [he] at ha'
        exact .data (TypeArgsLe.of_invariant (by simpa using ha'))
  theorem TelLe.ofExtends (h : P.Extends P') {Γ Φ t u} (hl : TelLe P Γ Φ t u) : TelLe P' Γ Φ t u := by
    match hl with
    | .done hr hc => exact .done (hr.ofExtends h) hc
    | .param ha ht => exact .param (ha.ofExtends h) (ht.ofExtends h)
  theorem TelClosure.ofExtends (h : P.Extends P') {Γ Φ t u} (hl : TelClosure P Γ Φ t u) :
      TelClosure P' Γ Φ t u := by
    match hl with
    | .refl => exact .refl
    | .tail hc hl => exact .tail (hc.ofExtends h) (hl.ofExtends h)
  theorem TypeArgsLe.ofExtends (h : P.Extends P') {Γ Φ vs as bs} (hl : TypeArgsLe P Γ Φ vs as bs) :
      TypeArgsLe P' Γ Φ vs as bs := by
    match hl with
    | .nil => exact .nil
    | .covariant_cons ha hs => exact .covariant_cons (ha.ofExtends h) (hs.ofExtends h)
    | .contravariant_cons ha hs => exact .contravariant_cons (ha.ofExtends h) (hs.ofExtends h)
    | .invariant_cons ha hs => exact .invariant_cons ha (hs.ofExtends h)
end

theorem DataObservationLe.ofExtends (h : P.Extends P') {d as bs} (hl : DataObservationLe P d as bs) :
    DataObservationLe P' d as bs := by
  unfold DataObservationLe at hl ⊢
  have hl' := hl.ofExtends h
  rcases h.variance d as.length with he | he
  · exact he ▸ hl'
  · rw [he] at hl'
    exact TypeArgsLe.of_invariant (by simpa using hl')

/-! ## 宣言の照合 -/

theorem Term.HasData.ofExtends (h : P.Extends P') {Γ t d ts} (hd : Term.HasData P Γ t d ts) :
    Term.HasData P' Γ t d ts := by
  match hd with
  | .var hi he => exact .var hi he
  | .value hc hd hn hl => exact .value (h.cons _ _ hc) hd hn hl
  | .field hr hc hd hn ha hw hs hv => exact .field (hr.ofExtends h) (h.cons _ _ hc) hd hn ha hw hs hv
  | .widen hr hl => exact .widen (hr.ofExtends h) (hl.ofExtends h)

theorem FieldRef.Declared.ofExtends (h : P.Extends P') {C Γ t ref} (hd : FieldRef.Declared P C Γ t ref) :
    FieldRef.Declared P' C Γ t ref := by
  obtain ⟨ts, cd, a, ht, hc, rest⟩ := hd
  exact ⟨ts, cd, a, ht.ofExtends h, h.cons _ _ hc, rest⟩

mutual
  theorem Term.Declared.ofExtends (h : P.Extends P') {C Γ} {t : Term} (hd : Term.Declared P C Γ t) :
      Term.Declared P' C Γ t := by
    cases t with
    | var i => exact hd
    | field ref t => exact ⟨Term.Declared.ofExtends h hd.1, hd.2.ofExtends h⟩
    | measure _ t | neg t | scale _ t => exact Term.Declared.ofExtends h (t := t) hd
    | add a b => exact ⟨Term.Declared.ofExtends h hd.1, Term.Declared.ofExtends h hd.2⟩
    | listValue xs | setValue xs => exact declaredSlots_ofExtends h hd
    | mapValue ks vs => exact ⟨declaredSlots_ofExtends h hd.1, declaredSlots_ofExtends h hd.2⟩
    | dataValue c xs =>
      obtain ⟨hs, cd, hc, hl⟩ := hd
      exact ⟨declaredSlots_ofExtends h hs, cd, h.cons _ _ hc, hl⟩
    | _ => trivial
  theorem declaredSlot_ofExtends (h : P.Extends P') {C Γ} {x : Option Term} (hd : declaredSlot P C Γ x) :
      declaredSlot P' C Γ x := by
    cases x with
    | none => trivial
    | some t => exact Term.Declared.ofExtends h (t := t) hd
  theorem declaredSlots_ofExtends (h : P.Extends P') {C Γ} {xs : List (Option Term)}
      (hd : declaredSlots P C Γ xs) : declaredSlots P' C Γ xs := by
    cases xs with
    | nil => trivial
    | cons x xs => exact ⟨declaredSlot_ofExtends h hd.1, declaredSlots_ofExtends h hd.2⟩
end

theorem Pred.Declared.ofExtends (h : P.Extends P') {C Γ self} {p : Pred} (hd : Pred.Declared P C Γ self p) :
    Pred.Declared P' C Γ self p := by
  cases p with
  | truth | falsity => trivial
  | eq a b | le a b | lt a b | compare _ _ a b => exact ⟨hd.1.ofExtends h, hd.2.ofExtends h⟩
  | floatClass _ _ a | decimalRepresented a | charactersIn a _ _ | member _ a _ => exact Term.Declared.ofExtends h hd
  | constructorIs a c =>
    obtain ⟨ht, d, ts, cd, hdat, hc, hn⟩ := hd
    exact ⟨ht.ofExtends h, d, ts, cd, hdat.ofExtends h, h.cons _ _ hc, hn⟩
  | and p q | or p q => exact ⟨Pred.Declared.ofExtends h (p := p) hd.1, Pred.Declared.ofExtends h (p := q) hd.2⟩
  | not p => exact Pred.Declared.ofExtends h (p := p) hd

mutual
  theorem Ty.Declared.ofExtends (h : P.Extends P') {C Γ} {a : Ty} (hd : Ty.Declared P C Γ a) :
      Ty.Declared P' C Γ a := by
    match a with
    | .base _ | .bytes | .opaque _ _ | .scoped _ _ _ | .pathBases | .scopePattern _ | .tvar _ => trivial
    | .data d as =>
      obtain ⟨⟨n, hn, hl⟩, has⟩ := hd
      exact ⟨⟨n, h.dataArity hn, hl⟩, declaredTys_ofExtends h has⟩
    | .external id as =>
      obtain ⟨⟨td, ht, hi, hl⟩, has⟩ := hd
      exact ⟨⟨td, (h.externalType id).trans ht, hi, hl⟩, declaredTys_ofExtends h has⟩
    | .tapp i as => exact ⟨hd.1, declaredTys_ofExtends h hd.2⟩
    | .ctor (.data d) =>
      obtain ⟨n, hn⟩ := hd
      exact ⟨n, h.dataArity hn⟩
    | .ctor .list | .ctor .set | .ctor .map | .ctor .reference | .ctor .lazy => trivial
    | .list a | .reference a | .lazy a | .set a | .dict _ a => exact Ty.Declared.ofExtends h (a := a) hd
    | .fn ns ps r e =>
      exact ⟨declaredTys_ofExtends h hd.1, Ty.Declared.ofExtends h hd.2.1, declaredEff_ofExtends h hd.2.2⟩
    | .dependentFn t => exact Tel.Declared.ofExtends h (t := t) hd
    | .cont b t e =>
      exact ⟨Ty.Declared.ofExtends h hd.1, Ty.Declared.ofExtends h hd.2.1, declaredEff_ofExtends h hd.2.2⟩
    | .map a b => exact ⟨Ty.Declared.ofExtends h hd.1, Ty.Declared.ofExtends h hd.2⟩
    | .refined a p => exact ⟨Ty.Declared.ofExtends h hd.1, hd.2.ofExtends h⟩
  theorem Tel.Declared.ofExtends (h : P.Extends P') {C Γ} {t : Tel} (hd : Tel.Declared P C Γ t) :
      Tel.Declared P' C Γ t := by
    cases t with
    | done r e => exact ⟨Ty.Declared.ofExtends h hd.1, declaredEff_ofExtends h hd.2⟩
    | param n a t => exact ⟨Ty.Declared.ofExtends h hd.1, Tel.Declared.ofExtends h hd.2⟩
  theorem declaredTys_ofExtends (h : P.Extends P') {C Γ} {as : List Ty} (hd : declaredTys P C Γ as) :
      declaredTys P' C Γ as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Declared.ofExtends h hd.1, declaredTys_ofExtends h hd.2⟩
  theorem declaredEff_ofExtends (h : P.Extends P') {C Γ} {e : Eff} (hd : declaredEff P C Γ e) :
      declaredEff P' C Γ e := by
    cases e with
    | mk atoms fs => exact declaredTys_ofExtends h hd
end

theorem Ty.Annotation.ofExtends (h : P.Extends P') {C Γ a} (ha : Ty.Annotation P C Γ a) :
    Ty.Annotation P' C Γ a :=
  ⟨ha.wf, ha.sorted, ha.declared.ofExtends h⟩

theorem TypeAnnotations.ofExtends (h : P.Extends P') {C Γ ts} (ha : TypeAnnotations P C Γ ts) :
    TypeAnnotations P' C Γ ts := fun t ht => (ha t ht).ofExtends h

theorem RowAnnotations.ofExtends (h : P.Extends P') {C Γ es} (ha : RowAnnotations P C Γ es) :
    RowAnnotations P' C Γ es := fun e he => (ha e he).ofExtends h

theorem SignatureInstance.ofExtends (h : P.Extends P') {C Γ t ks ts es}
    (hs : SignatureInstance P C Γ t ks ts es) : SignatureInstance P' C Γ t ks ts es :=
  ⟨hs.source, hs.types.ofExtends h, hs.kinds.ofExtends h, hs.rows.ofExtends h,
    fun e he => kindsEff_ofExtends h (hs.rowKinds e he), hs.result.ofExtends h⟩

theorem FactsWF.ofExtends (h : P.Extends P') {C Γ Φ} (hf : FactsWF P C Γ Φ) : FactsWF P' C Γ Φ :=
  fun p hp => ⟨(hf p hp).wf, (hf p hp).sorted, (hf p hp).declared.ofExtends h⟩

theorem Ty.CaptureDeclared.ofExtends (h : P.Extends P') {C Γ} {a : Ty} (hd : a.CaptureDeclared P C Γ) :
    a.CaptureDeclared P' C Γ := by
  cases a <;> simp only [Ty.CaptureDeclared] at hd ⊢
  all_goals first
    | exact Ty.Declared.ofExtends h hd
    | exact ⟨hd.1.ofExtends h, hd.2.ofExtends h⟩

/-! ## At の結果の形・外部の宣言・パターン・節の署名 -/

theorem Program.HasScopePublic.ofExtends (h : P.Extends P') (hs : P.HasScopePublic) : P'.HasScopePublic :=
  ⟨fun d hd => h.dataArity (hs.arity d hd), fun c d as hc => h.cons _ _ (hs.cons c d as hc),
    h.dataArity hs.optionArity, h.cons _ _ hs.optionSome, h.cons _ _ hs.optionNone⟩

theorem ResultShape.StandardError.ofExtends (h : P.Extends P') {shape : ResultShape}
    (hs : shape.StandardError P) : shape.StandardError P' := by
  obtain ⟨he, ha, ⟨cd, hc, rest⟩, hp⟩ := hs
  exact ⟨he, h.dataArity ha, ⟨cd, h.cons _ _ hc, rest⟩, hp.ofExtends h⟩

theorem ResultShape.Declared.ofExtends (h : P.Extends P') {shape : ResultShape}
    (hs : shape.Declared P) : shape.Declared P' := by
  obtain ⟨standard, arity, distinct, ⟨cd, hc, ok⟩, ⟨cd', hc', err⟩⟩ := hs
  exact ⟨standard.ofExtends h, h.dataArity arity, distinct, ⟨cd, h.cons _ _ hc, ok⟩,
    ⟨cd', h.cons _ _ hc', err⟩⟩

theorem ExternalValueType.ofExtends (h : P.Extends P') {component unit a}
    (hv : ExternalValueType P component unit a) : ExternalValueType P' component unit a := by
  match hv with
  | .scalar hs => exact .scalar hs
  | .unit => exact .unit
  | .bytes => exact .bytes
  | .handle ht hc hi ha hts => exact .handle ((h.externalType _).trans ht) hc hi ha hts
  | .list hv => exact .list (hv.ofExtends h)
  | .map hk hv => exact .map hk (hv.ofExtends h)
  | .flags (d := d) cs hn h1 h32 hm ha hargs =>
    have hd : P.HasData d := Or.inl ha.1
    refine .flags cs hn h1 h32 (fun c => ?_) (h.dataArity ha)
      (fun c cd hc he => hargs c cd (h.consData hc he hd) he)
    rw [hm c]
    exact ⟨fun ⟨cd, hc, he⟩ => ⟨cd, h.cons _ _ hc, he⟩, fun ⟨cd, hc, he⟩ => ⟨cd, h.consData hc he hd, he⟩⟩
  | .data (d := d) cs hn hne hm ha hargs =>
    have hd : P.HasData d := Or.inl ha.1
    refine .data cs hn hne (fun c => ?_) (h.dataArity ha)
      (fun c cd hc he a hm' => (hargs c cd (h.consData hc he hd) he a hm').ofExtends h)
    rw [hm c]
    exact ⟨fun ⟨cd, hc, he⟩ => ⟨cd, h.cons _ _ hc, he⟩, fun ⟨cd, hc, he⟩ => ⟨cd, h.consData hc he hd, he⟩⟩
  | .refined hv => exact .refined (hv.ofExtends h)

theorem ExternalTelWF.ofExtends (h : P.Extends P') {component effect t}
    (hw : ExternalTelWF P component effect t) : ExternalTelWF P' component effect t := by
  match hw with
  | .done hv he => exact .done (hv.ofExtends h) he
  | .param hv hr => exact .param (hv.ofExtends h) (hr.ofExtends h)

theorem ExternalOccurrence.ofExtends (h : P.Extends P') {a path id}
    (ho : ExternalOccurrence P a path id) : ExternalOccurrence P' a path id := by
  match ho with
  | .root => exact .root
  | .element ho => exact .element (ho.ofExtends h)
  | .key ho => exact .key (ho.ofExtends h)
  | .value ho => exact .value (ho.ofExtends h)
  | .field hc hd hn ha ho => exact .field (h.cons _ _ hc) hd hn ha (ho.ofExtends h)
  | .refined ho => exact .refined (ho.ofExtends h)

/-- 外部の写像の鍵の型は外部型を含まない。 -/
theorem ExternalMapKey.no_occurrence {Q : Program} : ∀ {k : Ty} {path id}, ExternalMapKey k →
    ¬ ExternalOccurrence Q k path id
  | .base _, _, _, _, ho => by cases ho
  | .refined k _, _, _, hk, ho => by
    cases ho with
    | refined ho => exact ExternalMapKey.no_occurrence (k := k) hk ho

/-- 外部の受渡し型の外部型の出現は、P' の出現が P の出現でもある（data 型の全構成子を受渡し型が読む）。 -/
theorem ExternalOccurrence.ofExtends_rev (h : P.Extends P') {component unit a path id}
    (hv : ExternalValueType P component unit a) (ho : ExternalOccurrence P' a path id) :
    ExternalOccurrence P a path id := by
  match hv, ho with
  | .handle _ _ _ _ _, .root => exact .root
  | .list hv, .element ho => exact .element (ho.ofExtends_rev h hv)
  | .map hk _, .key ho => exact absurd ho (ExternalMapKey.no_occurrence hk)
  | .map _ hv, .value ho => exact .value (ho.ofExtends_rev h hv)
  | .data (d := d) _ _ _ _ ha hargs, .field (cd := cd) hc hdata hn hi ho =>
    have hP : P.cons _ = some cd := h.consData hc hdata (Or.inl ha.1)
    exact .field hP hdata hn hi (ho.ofExtends_rev h (hargs _ cd hP hdata _ (List.mem_of_getElem? hi)))
  | .refined hv, .refined ho => exact .refined (ho.ofExtends_rev h hv)

theorem ExternalUseAt.ofExtends (h : P.Extends P') {n t use} (hu : ExternalUseAt P n t use) :
    ExternalUseAt P' n t use := by
  match hu with
  | .argument ho => exact .argument (ho.ofExtends h)
  | .next hu => exact .next (hu.ofExtends h)
  | .result ho => exact .result (ho.ofExtends h)

theorem ExternalUseAt.ofExtends_rev (h : P.Extends P') {component effect n t use}
    (hw : ExternalTelWF P component effect t) (hu : ExternalUseAt P' n t use) : ExternalUseAt P n t use := by
  match hw, hu with
  | .param hv _, .argument ho => exact .argument (ho.ofExtends_rev h hv)
  | .param _ hr, .next hu => exact .next (hu.ofExtends_rev h hr)
  | .done hv _, .result ho => exact .result (ho.ofExtends_rev h hv)

theorem ExternalSignature.WF.ofExtends (h : P.Extends P') {d : ExternalSignature} (hw : d.WF P) : d.WF P' :=
  ⟨hw.monomorphic, hw.kinds, hw.annotation.ofExtends h, hw.kinded.ofExtends h,
    fun use => (hw.uses_exact use).trans ⟨(·.ofExtends h), (·.ofExtends_rev h hw.shape)⟩,
    hw.uses_unique, hw.shape.ofExtends h, hw.sourceTelRows⟩

theorem ExternalCallAdmissible.ofExtends (h : P.Extends P') {B C d ts}
    (ha : ExternalCallAdmissible P B C d ts) : ExternalCallAdmissible P' B C d ts :=
  ⟨ha.count, ha.kinds.ofExtends h, ha.constraints, ha.types.ofExtends h⟩

theorem Program.ExternalWF.ofExtends (h : P.Extends P') (hw : P.ExternalWF) : P'.ExternalWF := by
  refine ⟨h.externals ▸ hw.unique, fun key decl hm => ?_⟩
  have := hw.keys key decl (h.externals ▸ hm)
  match key, decl, this with
  | .type _, .type _, hk => exact hk
  | .function _, .function _ _, hk => exact ⟨hk.1, hk.2.ofExtends h⟩

mutual
  theorem PatTy.ofExtends (h : P.Extends P') {p a δ} (hp : PatTy P p a δ) : PatTy P' p a δ := by
    match hp with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const hc => exact .P_Const hc
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List hb ha hr => exact .P_List (hb.ofExtends h) (ha.ofExtends h) hr
    | .P_Convert he hp => exact .P_Convert he (hp.ofExtends h)
    | .P_Refined hp => exact .P_Refined (hp.ofExtends h)
    | .P_Con hc hn hw hps => exact .P_Con (h.cons _ _ hc) hn hw (hps.ofExtends h)
  theorem PatTys.ofExtends (h : P.Extends P') {ps as δ} (hp : PatTys P ps as δ) : PatTys P' ps as δ := by
    match hp with
    | .nil => exact .nil
    | .cons hp hps => exact .cons (hp.ofExtends h) (hps.ofExtends h)
end

theorem AltsTy.ofExtends (h : P.Extends P') {alts a δ} (ha : AltsTy P alts a δ) : AltsTy P' alts a δ := by
  obtain ⟨hne, hl, hh, hall⟩ := ha
  exact ⟨hne, hl, hh, fun alt hm => let ⟨γ, hp, rest⟩ := hall alt hm; ⟨γ, hp.ofExtends h, rest⟩⟩

theorem opSigAt.ofExtends (h : P.Extends P') {B S o sg} (hs : opSigAt P B S o = some sg) :
    opSigAt P' B S o = some sg := by
  cases o with
  | fail => cases hs
  | prim b => exact hs
  | user o =>
    simp only [opSigAt] at hs ⊢
    obtain ⟨od, ho, rfl⟩ := Option.map_eq_some_iff.mp hs
    simp [h.ops o od ho]

theorem ClauseSig.ofExtends (h : P.Extends P') {B e o sg} (hc : ClauseSig P B e o sg) : ClauseSig P' B e o sg := by
  obtain ⟨S, hix, hs, hr⟩ := hc
  exact ⟨S, hix, opSigAt.ofExtends h hs, hr⟩

/-- 追加された効果のラベルが組込みの表に無ければ、ハンドラが処理済みとする効果は P' で小さくならない。 -/
theorem handled_ofExtends (h : P.Extends P') {B} (hf : Program.FreshEffects P P' B) (cs : List Clause) :
    Eff.Sub (handled P B cs) (handled P' B cs) := by
  refine ⟨fun a ha => ?_, fun t ht => by simp [Eff.memFail, handled, Eff.fails] at ht⟩
  cases a with
  | rho i => simp [handled, Eff.mem, Eff.test, Eff.atoms] at ha
  | name l ix =>
    have same : effOps P' B l = effOps P B l ∨ effOps P B l = none := by
      cases hp : P.effects l with
      | some os => exact Or.inl (by simp [effOps, hp, h.effects l os hp])
      | none =>
        cases hb : B.effects l with
        | none => exact Or.inr (by simp [effOps, hp, hb])
        | some bs =>
          left
          cases hp' : P'.effects l with
          | none => simp [effOps, hp, hp', hb]
          | some os => simp [hf l os hp hp'] at hb
    rcases same with he | he
    · simpa [handled, Eff.mem, Eff.test, Eff.atoms, he] using ha
    · simp [handled, Eff.mem, Eff.test, Eff.atoms, he] at ha

/-! ## 型付けの14判断の移送

照合の規則 `C_Match` の網羅性だけは P について単調でない（P に構成子の無い型は P で住む値を持たない）。ここでは
網羅性の移送を前提 `hex` として受け、他の全ての規則を移す。 -/

theorem Eff.Sub.union_right {e f g : Eff} (h : Eff.Sub f g) {m : Eff} (hm : Eff.Sub m (e.union f)) :
    Eff.Sub m (e.union g) := by
  refine ⟨fun a ha => ?_, fun t ht => ?_⟩
  · rcases (Eff.mem_union_iff _ _ _).mp (hm.1 a ha) with ha | ha
    · exact (Eff.mem_union_iff _ _ _).mpr (Or.inl ha)
    · exact (Eff.mem_union_iff _ _ _).mpr (Or.inr (h.1 a ha))
  · rcases (Eff.memFail_union_iff _ _ _).mp (hm.2 t ht) with ht | ht
    · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inl ht)
    · exact (Eff.memFail_union_iff _ _ _).mpr (Or.inr (h.2 t ht))

/-- 網羅性の移送の前提。 -/
def Program.ExhaustiveTransport (P P' : Program) : Prop := ∀ a ps, Exhaustive P a ps → Exhaustive P' a ps

mutual
  theorem HasTypeVQ.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ v a} (typed : HasTypeVQ P B Ψ Q C Γ Φ v a) :
      HasTypeVQ P' B Ψ Q C Γ Φ v a := by
    match typed with
    | .V_Var h0 h1 => exact .V_Var h0 h1
    | .V_Const h0 => exact .V_Const h0
    | .V_Lam h0 h1 h2 h3 h4 => exact .V_Lam h0 h1 h2 (h3.ofExtends h hf hex) (h4.ofExtends h)
    | .V_DependentLam h0 h1 => exact .V_DependentLam (h0.ofExtends h) (h1.ofExtends h hf hex)
    | .V_Closure h0 h1 h2 => exact .V_Closure (h0.ofExtends h) h1 (h2.ofExtends h hf hex)
    | .V_Fun h0 h1 h2 h3 => exact .V_Fun (h.defs _ _ h0) h1 h2 (h3.ofExtends h)
    | .V_Prim h0 h1 h2 h3 h4 => exact .V_Prim h0 h1 h2 h3 (h4.ofExtends h)
    | .V_Op h0 h1 h2 h3 => exact .V_Op (h.ops _ _ h0) h1 h2 (h3.ofExtends h)
    | .V_ExternalRef h0 h1 h2 h3 =>
      exact .V_ExternalRef ((h.externalFunction _).trans h0) (h1.ofExtends h) (h2.ofExtends h) (h3.ofExtends h)
    | .V_ExternalHandle hd td h0 h1 h2 h3 h4 =>
      exact .V_ExternalHandle hd td ((h.externalType _).trans h0) h1 h2 h3 (h4.ofExtends h)
    | .V_PathBases h0 => exact .V_PathBases h0
    | .V_ScopePattern h0 h1 h2 => exact .V_ScopePattern h0 h1 h2
    | .V_Checked h0 h1 h2 => exact .V_Checked h0 h1 h2
    | .V_CheckedRequest h0 h1 h2 h3 h4 h5 => exact .V_CheckedRequest h0 h1 (h2.ofExtends h hf hex) h3 h4 h5
    | .V_CheckedAt h0 => exact .V_CheckedAt (h0.ofExtends h hf hex)
    | .V_AtError h0 => exact .V_AtError (h0.ofExtends h)
    | .V_Map h0 h1 h2 h3 h4 h5 =>
      exact .V_Map (h0.ofExtends h hf hex) (h1.ofExtends h hf hex) h2 h3 (h4.ofExtends h) (h5.ofExtends h)
    | .V_Set h0 h1 h2 => exact .V_Set (h0.ofExtends h hf hex) h1 (h2.ofExtends h)
    | .V_Dict h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .V_Dict (h.impls _ _ h0) h1 (h2.ofExtends h) (h3.ofExtends h) h4 h5 (h6.ofExtends h hf hex) (h7.ofExtends h)
    | .V_Raise h0 h1 h2 h3 => exact .V_Raise (h0.ofExtends h) h1 h2 (h3.ofExtends h)
    | .V_LocRef h0 h1 => exact .V_LocRef h0 (h1.ofExtends h)
    | .V_LocLazy h0 h1 => exact .V_LocLazy h0 (h1.ofExtends h)
    | .V_Bytes h0 => exact .V_Bytes h0
    | .V_Con h0 h1 h2 h3 h4 h5 => exact .V_Con (h.cons _ _ h0) h1 (h2.ofExtends h) h3 (h4.ofExtends h hf hex) (h5.ofExtends h)
    | .V_Super h0 h1 h2 h3 => exact .V_Super (h0.ofExtends h hf hex) (h.classes _ _ h1) h2 (h3.ofExtends h)
    | .V_List h0 h1 h2 h3 => exact .V_List (h0.ofExtends h hf hex) h1 h2 (h3.ofExtends h)
    | .V_Sub h0 h1 h2 h3 h4 => exact .V_Sub (h0.ofExtends h hf hex) (h1.ofExtends h) h2 h3 (h4.ofExtends h)
    | .V_Normal h0 => exact .V_Normal (h0.ofExtends h hf hex)
    | .V_Refine h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .V_Refine (h0.ofExtends h hf hex) h1 h2 h3 h4 h5 (h6.ofExtends h) (h7.ofExtends h)
  theorem HasTypeVsQ.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ vs as} (typed : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
      HasTypeVsQ P' B Ψ Q C Γ Φ vs as := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 => exact .cons (h0.ofExtends h hf hex) (h1.ofExtends h hf hex)
  theorem HasTypeEachQ.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ vs a} (typed : HasTypeEachQ P B Ψ Q C Γ Φ vs a) :
      HasTypeEachQ P' B Ψ Q C Γ Φ vs a := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 => exact .cons (h0.ofExtends h hf hex) (h1.ofExtends h hf hex)
  theorem HasTypeCQ.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ R m a ε Δ} (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) :
      HasTypeCQ P' B Ψ Q C Γ Φ R m a ε Δ := by
    match typed with
    | .C_BuilderLet h0 h1 h2 h3 => exact .C_BuilderLet (h0.ofExtends h) (h1.ofExtends h) (h2.ofExtends h hf hex) (h3.ofExtends h)
    | .C_BuilderOp h0 h1 h2 h3 => exact .C_BuilderOp (h0.ofExtends h) (h1.ofExtends h) h2 (h3.ofExtends h hf hex)
    | .C_Return h0 => exact .C_Return (h0.ofExtends h hf hex)
    | .C_Let h0 h1 h2 => exact .C_Let (h0.ofExtends h hf hex) (h1.ofExtends h hf hex) (h2.ofExtends h)
    | .C_App h0 h1 => exact .C_App (h0.ofExtends h hf hex) (h1.ofExtends h hf hex)
    | .C_DependentApp h0 h1 => exact .C_DependentApp (h0.ofExtends h hf hex) (h1.ofExtends h hf hex)
    | .C_If h0 h1 h2 h3 => exact .C_If (h0.ofExtends h hf hex) h1 (h2.ofExtends h hf hex) (h3.ofExtends h hf hex)
    | .C_Match h0 h1 h2 h3 => exact .C_Match (h0.ofExtends h hf hex) h1 (h2.ofExtends h hf hex) (hex _ _ h3)
    | .C_Lazy h0 h1 => exact .C_Lazy (h0.ofExtends h hf hex) (h1.ofExtends h)
    | .C_Escape h0 h1 => exact .C_Escape (h0.ofExtends h hf hex) (h1.ofExtends h)
    | .C_Use h0 h1 h2 h3 => exact .C_Use (h0.ofExtends h hf hex) h1 (h2.ofExtends h hf hex) h3
    | .C_Handle (h := cs) h0 h1 h2 =>
      exact .C_Handle (h0.ofExtends h hf hex) (Eff.Sub.union_right (handled_ofExtends h hf cs) h1) (h2.ofExtends h hf hex)
    | .C_Handle_Fail h0 h1 h2 h3 => exact .C_Handle_Fail (h0.ofExtends h hf hex) h1 h2 (h3.ofExtends h hf hex)
    | .C_Resume h0 h1 h2 => exact .C_Resume h0 (h1.ofExtends h hf hex) (h2.ofExtends h)
    | .C_ResumeL h0 h1 h2 => exact .C_ResumeL h0 (h1.ofExtends h hf hex) (h2.ofExtends h)
    | .C_ResumeNorm h0 h1 h2 => exact .C_ResumeNorm h0 (h1.ofExtends h hf hex) (h2.ofExtends h)
    | .C_ResumeLNorm h0 h1 h2 h3 => exact .C_ResumeLNorm h0 h1 (h2.ofExtends h hf hex) (h3.ofExtends h)
    | .C_Normal h0 => exact .C_Normal (h0.ofExtends h hf hex)
    | .C_Meth h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 =>
      exact .C_Meth (h0.ofExtends h hf hex) (h.classes _ _ h1) h2 h3 h4 (h5.ofExtends h) h6 h7 (h8.ofExtends h hf hex) (h9.ofExtends h)
    | .C_External h0 h1 h2 h3 =>
      exact .C_External ((h.externalFunction _).trans h0) (h1.ofExtends h) (h2.ofExtends h) (h3.ofExtends h hf hex)
    | .C_IssuePathBases b sg h0 h1 h2 h3 h4 h5 => exact .C_IssuePathBases b sg h0 h1 h2 h3 h4 h5
    | .C_CheckAt h0 => exact .C_CheckAt (h0.ofExtends h hf hex)
    | .C_Sub h0 h1 h2 h3 h4 h5 => exact .C_Sub (h0.ofExtends h hf hex) (h1.ofExtends h) h2 h3 h4 (h5.ofExtends h)
    | .C_Eff h0 h1 => exact .C_Eff (h0.ofExtends h hf hex) h1
  theorem HasTypeTelArgsQ.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ ws t a e} (typed : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t a e) :
      HasTypeTelArgsQ P' B Ψ Q C Γ Φ ws t a e := by
    match typed with
    | .done h0 => exact .done (h0.ofExtends h)
    | .param h0 h1 h2 => exact .param (h0.ofExtends h) (h1.ofExtends h hf hex) (h2.ofExtends h hf hex)
  theorem TelBodyTy.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ t body} (typed : TelBodyTy P B Ψ Q C Γ Φ t body) :
      TelBodyTy P' B Ψ Q C Γ Φ t body := by
    match typed with
    | .done h0 => exact .done (h0.ofExtends h hf hex)
    | .param h0 => exact .param (h0.ofExtends h hf hex)
  theorem CaptureOk.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ R Γ Φ cap} (typed : CaptureOk P B Ψ R Γ Φ cap) : CaptureOk P' B Ψ R Γ Φ cap := by
    match typed with
    | .mk h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .mk h0 h1 h2 (fun i a hi => ⟨(h3 i a hi).1, (h3 i a hi).2.ofExtends h⟩)
        (fun p hp => ⟨(h4 p hp).1, (h4 p hp).2.1, (h4 p hp).2.2.ofExtends h⟩) h5
        (fun i a hi => (h6 i a hi).ofExtends h hf hex) h7
  theorem DependentClosureTy.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ body t} (typed : DependentClosureTy P B Ψ body t) :
      DependentClosureTy P' B Ψ body t := by
    match typed with
    | .mk h0 h1 h2 h3 => exact .mk (h0.ofExtends h hf hex) (h1.ofExtends h hf hex) (h2.ofExtends h) (h3.ofExtends h)
  theorem CheckedWitness.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ o k range snapshot target request}
      (typed : CheckedWitness P B Ψ o k range snapshot target request) :
      CheckedWitness P' B Ψ o k range snapshot target request := by
    match typed with
    | .plain h0 h1 h2 h3 => exact .plain h0 h1 h2 h3
    | .request h0 h1 h2 h3 h4 h5 => exact .request h0 h1 (h2.ofExtends h hf hex) h3 h4 h5
  theorem AtCallAdmissible.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ kind name shape bases pattern input index}
      (typed : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
      AtCallAdmissible P' B Ψ Q C Γ Φ kind name shape bases pattern input index := by
    match typed with
    | .mk h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .mk (h0.ofExtends h) h1 (fun v hv => (h2 v hv).ofExtends h hf hex) (h3.ofExtends h hf hex) h4
        (h5.ofExtends h hf hex) h6 h7
    | .text h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .text (h0.ofExtends h) h1 (fun v hv => (h2 v hv).ofExtends h hf hex) (h3.ofExtends h hf hex) h4
        (h5.ofExtends h hf hex) h6 h7
  theorem HasTypeArmsQ.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ R obs arms a b e Δ}
      (typed : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e Δ) : HasTypeArmsQ P' B Ψ Q C Γ Φ R obs arms a b e Δ := by
    match typed with
    | .nil h0 => exact .nil (h0.ofExtends h)
    | .plain h0 h1 h2 h3 h4 h5 =>
      exact .plain (h0.ofExtends h) h1 (h2.ofExtends h) (h3.ofExtends h) (h4.ofExtends h hf hex) (h5.ofExtends h hf hex)
    | .guarded h0 h1 h2 h3 h4 h5 h6 h7 =>
      exact .guarded (h0.ofExtends h) h1 (h2.ofExtends h) (h3.ofExtends h) (h4.ofExtends h)
        (h5.ofExtends h hf hex) (h6.ofExtends h hf hex) (h7.ofExtends h hf hex)
  theorem HasTypeClausesQ.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ R eb cs t e Δ}
      (typed : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e Δ) : HasTypeClausesQ P' B Ψ Q C Γ Φ R eb cs t e Δ := by
    match typed with
    | .nil => exact .nil
    | .cons h0 h1 h2 h3 h4 h5 h6 => exact .cons (h0.ofExtends h) h1 h2 h3 h4 (h5.ofExtends h hf hex) (h6.ofExtends h hf hex)
  theorem HasFailureClause.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ E R cs t e Δ}
      (typed : HasFailureClause P B Ψ Q C Γ Φ E R cs t e Δ) : HasFailureClause P' B Ψ Q C Γ Φ E R cs t e Δ := by
    match typed with
    | .one h0 h1 h2 h3 => exact .one (h0.ofExtends h) (h1.ofExtends h) (h2.ofExtends h) (h3.ofExtends h hf hex)
  theorem ImageOk.ofExtends {B : Builtins} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
      (hex : Program.ExhaustiveTransport P P') {Ψ Q C Γ Φ R env i a} (typed : ImageOk P B Ψ Q C Γ Φ R env i a) :
      ImageOk P' B Ψ Q C Γ Φ R env i a := by
    match typed with
    | .ordinary h0 h1 => exact .ordinary h0 (h1.ofExtends h hf hex)
    | .hidden h0 h1 => exact .hidden h0 h1
    | .contLoc h0 h1 h2 h3 h4 h5 => exact .contLoc h0 h1 h2 h3 h4 h5
    | .contVar h0 h1 h2 => exact .contVar h0 h1 h2
end

/-! ## 宣言の型付けと整形式 -/

theorem Def.WellTyped.ofExtends {B} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
    (hex : Program.ExhaustiveTransport P P') {d : Def} (hd : Def.WellTyped P B d) : Def.WellTyped P' B d :=
  ⟨hd.1, hd.2.1.ofExtends h, hd.2.2.1.ofExtends h, hd.2.2.2.ofExtends h hf hex⟩

theorem ImplDecl.WellTyped.ofExtends {B} (h : P.Extends P') (hf : Program.FreshEffects P P' B)
    (hex : Program.ExhaustiveTransport P P') {id : ImplDecl} (hi : ImplDecl.WellTyped P B id) :
    ImplDecl.WellTyped P' B id := by
  obtain ⟨cd, hc, hm, hs, hk, ha, hb, hsup⟩ := hi
  refine ⟨cd, h.classes _ _ hc, hm, hs, hk.ofExtends h, ha.ofExtends h, fun m ms hms => ?_,
    fun s hs' => let ⟨u, hu, ht⟩ := hsup s hs'; ⟨u, hu, ht.ofExtends h hf hex⟩⟩
  obtain ⟨body, hbody, hn, ht⟩ := hb m ms hms
  exact ⟨body, hbody, hn, ht.ofExtends h hf hex⟩

theorem SignatureScoped.ofExtends (h : P.Extends P') {C ne t} (hs : SignatureScoped P C ne t) :
    SignatureScoped P' C ne t :=
  ⟨hs.1, hs.2.1, hs.2.2.1.ofExtends h, hs.2.2.2.ofExtends h⟩

theorem Def.Scoped.ofExtends (h : P.Extends P') {d : Def} (hd : d.Scoped P) : d.Scoped P' :=
  ⟨hd.1, hd.2.1.ofExtends h, hd.2.2⟩

theorem ConDecl.Scoped.ofExtends (h : P.Extends P') {cd : ConDecl} (hd : cd.Scoped P) : cd.Scoped P' :=
  fun a ha => ⟨(hd a ha).1, (hd a ha).2.1.ofExtends h, (hd a ha).2.2.ofExtends h⟩

theorem OpDecl.Scoped.ofExtends (h : P.Extends P') {od : OpDecl} (hd : od.Scoped P) : od.Scoped P' :=
  ⟨hd.1, hd.2.1, hd.2.2.1, hd.2.2.2.ofExtends h⟩

theorem ClassDecl.Scoped.ofExtends (h : P.Extends P') {cl : ClassDecl} (hd : cl.Scoped P) : cl.Scoped P' :=
  fun m ms hm => ⟨(hd m ms hm).1, (hd m ms hm).2.ofExtends h⟩

/-- 実装の整形式は型クラスの lookup を読むので、型クラスが P にある実装について移す。 -/
theorem ImplDecl.Scoped.ofExtends (h : P.Extends P') {id : ImplDecl} (hc : (P.classes id.cls).isSome)
    (hd : id.Scoped P) : id.Scoped P' := by
  obtain ⟨cd0, hc0⟩ := Option.isSome_iff_exists.mp hc
  obtain ⟨h1, h2, h3, h4, h5, h6, h7⟩ := hd
  refine ⟨h1, h2, h3.ofExtends h, h4.ofExtends h, fun a ha => (h5 a ha).ofExtends h, h6, ?_⟩
  intro cd m ms body hc' hm hb
  have : cd = cd0 := Option.some.inj (hc'.symm.trans (h.classes _ _ hc0))
  subst this
  exact h7 cd m ms body hc0 hm hb

/-- 旧宣言の整形式と追加宣言の義務から、P' の整形式を得る。旧宣言の実装はその型クラスを P に持つ。 -/
theorem Program.WellFormed.compose {B} (h : P.Extends P') (himpls : ∀ i id, P.impls i = some id → (P.classes id.cls).isSome)
    (hwf : P.WellFormed) (hadd : Program.Additions P P' B) : P'.WellFormed where
  defs f d hd := by
    cases hp : P.defs f with
    | none => exact (hadd.defs f d hp hd).2
    | some d0 =>
      have := Option.some.inj ((h.defs f d0 hp).symm.trans hd)
      subst this
      exact (hwf.defs f d0 hp).ofExtends h
  cons c cd hc := by
    cases hp : P.cons c with
    | none => exact hadd.cons c cd hp hc
    | some cd0 =>
      have := Option.some.inj ((h.cons c cd0 hp).symm.trans hc)
      subst this
      exact ⟨h.dataArity (hwf.cons c cd0 hp).1, (hwf.cons c cd0 hp).2.ofExtends h⟩
  ops o od ho := by
    cases hp : P.ops o with
    | none => exact hadd.ops o od hp ho
    | some od0 =>
      have := Option.some.inj ((h.ops o od0 hp).symm.trans ho)
      subst this
      exact (hwf.ops o od0 hp).ofExtends h
  classes cl cd hc := by
    cases hp : P.classes cl with
    | none => exact hadd.classes cl cd hp hc
    | some cd0 =>
      have := Option.some.inj ((h.classes cl cd0 hp).symm.trans hc)
      subst this
      exact (hwf.classes cl cd0 hp).ofExtends h
  impls i id hi := by
    cases hp : P.impls i with
    | none => exact (hadd.impls i id hp hi).2
    | some id0 =>
      have := Option.some.inj ((h.impls i id0 hp).symm.trans hi)
      subst this
      exact (hwf.impls i id0 hp).ofExtends h (himpls i id0 hp)
  metadata := hadd.metadata
  external := hwf.external.ofExtends h

/-- 旧宣言の効果の検査と追加宣言の義務から、P' の効果の検査を得る。 -/
theorem Program.EffectsOk.compose {B} (h : P.Extends P') (hok : P.EffectsOk B)
    (hadd : Program.Additions P P' B) : P'.EffectsOk B := by
  obtain ⟨h1, h2, h3⟩ := hok
  refine ⟨fun l os o hl ho => ?_, fun o od ho => ?_, fun l os hl => ?_⟩
  · cases hp : P.effects l with
    | none => exact hadd.effectOps l os o hp hl ho
    | some os0 =>
      have := Option.some.inj ((h.effects l os0 hp).symm.trans hl)
      subst this
      obtain ⟨od, hod, he⟩ := h1 l os0 o hp ho
      exact ⟨od, h.ops o od hod, he⟩
  · cases hp : P.ops o with
    | none => exact hadd.opEffects o od hp ho
    | some od0 =>
      have := Option.some.inj ((h.ops o od0 hp).symm.trans ho)
      subst this
      obtain ⟨os, hos, hm⟩ := h2 o od0 hp
      exact ⟨os, h.effects _ os hos, hm⟩
  · cases hp : P.effects l with
    | none => exact hadd.builtinEffects l os hp hl
    | some os0 => exact h3 l os0 hp

/-! ## 変性の検査 -/

mutual
  /-- 両方向の位置で通る出現は、どの向きの位置でも通る。 -/
  theorem Ty.VarianceOK.of_both {Q : Program} {vs : List Variance} {a : Ty}
      (hv : a.VarianceOK Q vs .both) (q : Polarity) : a.VarianceOK Q vs q := by
    match a with
    | .tvar i =>
      obtain ⟨v, hi, ha⟩ := hv
      refine ⟨v, hi, ?_⟩
      cases v <;> simp_all [Variance.accepts]
    | .data d as => exact varianceArgsOK_of_both (vs := vs) (as := as) hv q
    | .list a | .lazy a | .refined a _ => exact Ty.VarianceOK.of_both (a := a) hv q
    | .dependentFn t => exact Tel.VarianceOK.of_both (t := t) hv q
    | .fn _ ps r e => exact ⟨varianceTysOK_of_both (as := ps) hv.1 q.flip, Ty.VarianceOK.of_both hv.2.1 q, by cases e; exact hv.2.2⟩
    | .map k a => exact ⟨hv.1, Ty.VarianceOK.of_both hv.2 q⟩
    | .reference _ | .set _ | .dict _ _ | .cont _ _ _ | .tapp _ _ | .external _ _ => exact hv
    | .base _ | .opaque _ _ | .bytes | .ctor _ | .scoped _ _ _ | .pathBases | .scopePattern _ => trivial
  theorem Tel.VarianceOK.of_both {Q : Program} {vs : List Variance} {t : Tel}
      (hv : t.VarianceOK Q vs .both) (q : Polarity) : t.VarianceOK Q vs q := by
    match t with
    | .done r e => exact ⟨Ty.VarianceOK.of_both hv.1 q, by cases e; exact hv.2⟩
    | .param _ a t => exact ⟨Ty.VarianceOK.of_both hv.1 q.flip, Tel.VarianceOK.of_both hv.2 q⟩
  theorem varianceTysOK_of_both {Q : Program} {vs : List Variance} {as : List Ty}
      (hv : varianceTysOK Q vs .both as) (q : Polarity) : varianceTysOK Q vs q as := by
    match as with
    | [] => trivial
    | a :: as => exact ⟨Ty.VarianceOK.of_both hv.1 q, varianceTysOK_of_both hv.2 q⟩
  theorem varianceArgsOK_of_both {Q : Program} {vs ws : List Variance} {as : List Ty}
      (hv : varianceArgsOK Q vs .both ws as) (q : Polarity) : varianceArgsOK Q vs q ws as := by
    match ws, as with
    | [], [] => trivial
    | w :: ws, a :: as =>
      rw [varianceArgsOK, Polarity.both_compose] at hv
      exact ⟨Ty.VarianceOK.of_both hv.1 _, varianceArgsOK_of_both hv.2 q⟩
    | [], _ :: _ | _ :: _, [] => exact hv.elim
end

/-- 不変の列で通る引数の出現は、同じ長さのどの変性の列でも通る。 -/
theorem varianceArgsOK_of_invariant {Q : Program} {vs : List Variance} {p : Polarity} :
    ∀ {ws : List Variance} {as : List Ty},
      varianceArgsOK Q vs p (List.replicate ws.length .invariant) as → varianceArgsOK Q vs p ws as
  | [], [], _ => trivial
  | w :: ws, a :: as, hv => by
    simp only [List.length_cons, List.replicate_succ, varianceArgsOK, Polarity.compose] at hv
    exact ⟨Ty.VarianceOK.of_both hv.1 _, varianceArgsOK_of_invariant hv.2⟩
  | [], _ :: _, hv | _ :: _, [], hv => by simp [varianceArgsOK] at hv

mutual
  theorem Ty.VarianceOK.ofExtends (h : P.Extends P') {vs : List Variance} {p : Polarity} {a : Ty}
      (hv : a.VarianceOK P vs p) : a.VarianceOK P' vs p := by
    match a with
    | .tvar _ => exact hv
    | .data d as =>
      have hv' := varianceArgsOK_ofExtends h (ws := P.varianceFor d as.length) (as := as) hv
      rcases h.variance d as.length with he | he
      · simp only [Ty.VarianceOK]
        rw [he]; exact hv'
      · rw [he] at hv'
        simp only [Ty.VarianceOK]
        exact varianceArgsOK_of_invariant (by simpa using hv')
    | .list a | .lazy a | .refined a _ => exact Ty.VarianceOK.ofExtends h (a := a) hv
    | .dependentFn t => exact Tel.VarianceOK.ofExtends h (t := t) hv
    | .fn _ ps r e =>
      exact ⟨varianceTysOK_ofExtends h hv.1, Ty.VarianceOK.ofExtends h hv.2.1, by cases e; exact varianceTysOK_ofExtends h hv.2.2⟩
    | .map k a => exact ⟨Ty.VarianceOK.ofExtends h hv.1, Ty.VarianceOK.ofExtends h hv.2⟩
    | .reference a | .set a | .dict _ a => exact Ty.VarianceOK.ofExtends h (a := a) hv
    | .cont a b e =>
      exact ⟨Ty.VarianceOK.ofExtends h hv.1, Ty.VarianceOK.ofExtends h hv.2.1, by cases e; exact varianceTysOK_ofExtends h hv.2.2⟩
    | .tapp i as => exact ⟨hv.1, varianceTysOK_ofExtends h hv.2⟩
    | .external _ as => exact varianceTysOK_ofExtends h (as := as) hv
    | .base _ | .opaque _ _ | .bytes | .ctor _ | .scoped _ _ _ | .pathBases | .scopePattern _ => trivial
  theorem Tel.VarianceOK.ofExtends (h : P.Extends P') {vs : List Variance} {p : Polarity} {t : Tel}
      (hv : t.VarianceOK P vs p) : t.VarianceOK P' vs p := by
    match t with
    | .done r e => exact ⟨Ty.VarianceOK.ofExtends h hv.1, by cases e; exact varianceTysOK_ofExtends h hv.2⟩
    | .param _ a t => exact ⟨Ty.VarianceOK.ofExtends h hv.1, Tel.VarianceOK.ofExtends h hv.2⟩
  theorem varianceTysOK_ofExtends (h : P.Extends P') {vs : List Variance} {p : Polarity} {as : List Ty}
      (hv : varianceTysOK P vs p as) : varianceTysOK P' vs p as := by
    match as with
    | [] => trivial
    | a :: as => exact ⟨Ty.VarianceOK.ofExtends h hv.1, varianceTysOK_ofExtends h hv.2⟩
  theorem varianceArgsOK_ofExtends (h : P.Extends P') {vs ws : List Variance} {p : Polarity} {as : List Ty}
      (hv : varianceArgsOK P vs p ws as) : varianceArgsOK P' vs p ws as := by
    match ws, as with
    | [], [] => trivial
    | w :: ws, a :: as => exact ⟨Ty.VarianceOK.ofExtends h hv.1, varianceArgsOK_ofExtends h hv.2⟩
    | [], _ :: _ | _ :: _, [] => exact hv.elim
end

theorem Program.ParamOccursInFields.ofExtends (h : P.Extends P') {d i} (ho : P.ParamOccursInFields d i) :
    P'.ParamOccursInFields d i := by
  obtain ⟨c, cd, a, hc, rest⟩ := ho
  exact ⟨c, cd, a, h.cons _ _ hc, rest⟩

theorem Program.DataInfoVariance.ofExtends (h : P.Extends P') {d info} (hv : P.DataInfoVariance d info) :
    P'.DataInfoVariance d info :=
  ⟨hv.1, fun i v hi hn => hv.2.1 i v hi (fun ho => hn (ho.ofExtends h)),
    fun a ha => (hv.2.2.1 a ha).ofExtends h, fun item hm => (hv.2.2.2 item hm).ofExtends h⟩

/-- 旧宣言の変性の検査と追加宣言の義務から、P' の変性の検査を得る。 -/
theorem Program.VarianceValid.compose {B} (h : P.Extends P') (hv : P.VarianceValid)
    (hadd : Program.Additions P P' B) : P'.VarianceValid := by
  rw [Program.varianceValid_iff] at hv ⊢
  refine ⟨fun d info hi => ?_, fun c cd hc => ?_⟩
  · cases hp : P.dataInfo d with
    | none => exact hadd.dataVariance d info hp hi
    | some info0 =>
      have := Option.some.inj ((h.dataInfo d info0 hp).symm.trans hi)
      subst this
      exact (hv.1 d info0 hp).ofExtends h
  · cases hp : P.cons c with
    | none => exact hadd.conVariance c cd hp hc
    | some cd0 =>
      have := Option.some.inj ((h.cons c cd0 hp).symm.trans hc)
      subst this
      have hd : P.HasData cd0.data := Or.inl ⟨c, cd0, hp, rfl⟩
      have hinfo := h.dataInfoOld cd0.data hd
      have hvar : P'.varianceFor cd0.data cd0.ntys = P.varianceFor cd0.data cd0.ntys := by
        simp only [Program.varianceFor, hinfo]
      obtain ⟨h1, h2⟩ := hv.2 c cd0 hp
      refine ⟨fun info hi => h1 info (hinfo ▸ hi), fun a ha => ?_⟩
      obtain ⟨ha1, ha2, ha3⟩ := h2 a ha
      exact ⟨ha1.ofExtends h, ha2.ofExtends h, hvar ▸ ha3.ofExtends h⟩

/-! ## 網羅性の移送を前提にした移送と合成

照合の規則の網羅性の移送（`Program.ExhaustiveTransport`）を前提に取る形である。照合の型が P で宣言済みであることを
照合の規則が持てば、この前提は宣言済みの型の網羅性の移送から供給される。 -/

theorem Program.extendsTyping_of_exhaustive {P P' : Program} {B : Builtins}
    (hex : Program.ExhaustiveTransport P P') : Program.ExtendsTypingStatement P P' B :=
  fun h hf _ => ⟨fun _ _ _ _ _ _ _ _ hv => hv.ofExtends h hf hex, fun _ _ _ _ _ _ _ _ _ _ _ hm => hm.ofExtends h hf hex⟩

theorem Program.extendsDeclaration_of_exhaustive {P P' : Program} {B : Builtins}
    (hex : Program.ExhaustiveTransport P P') : Program.ExtendsDeclarationStatement P P' B :=
  fun h hf _ => ⟨fun _ _ hd => hd.ofExtends h hf hex, fun _ _ hi => hi.ofExtends h hf hex⟩

theorem Program.compose_of_exhaustive {P P' : Program} {B : Builtins}
    (hex : Program.ExhaustiveTransport P P') : Program.ComposeStatement P P' B := by
  intro hwt hwf hok h hadd
  have hf := hadd.freshEffects
  refine ⟨⟨hwt.variance.compose h hadd, hwt.external.ofExtends h, fun f d hd => ?_, fun i id hi => ?_⟩,
    hwf.compose h (fun i id hi => by obtain ⟨cd, hc, -⟩ := hwt.impls i id hi; simp [hc]) hadd, hok.compose h hadd⟩
  · cases hp : P.defs f with
    | none => exact (hadd.defs f d hp hd).1
    | some d0 =>
      have := Option.some.inj ((h.defs f d0 hp).symm.trans hd)
      subst this
      exact (hwt.defs f d0 hp).ofExtends h hf hex
  · cases hp : P.impls i with
    | none => exact (hadd.impls i id hp hi).1
    | some id0 =>
      have := Option.some.inj ((h.impls i id0 hp).symm.trans hi)
      subst this
      exact (hwt.impls i id0 hp).ofExtends h hf hex

/-! ## 宣言済みの型の網羅性

網羅性は住む値の全称なので、P' の住む値が P でも住むことが要る。住む値の構成子は型の data 型の構成子であり、
その data 型が P に名前を持てば `consClosed` で P の構成子になる。型の中の全ての data 型が名前の集合 N に入る
ことを `Ty.DataIn N` で表し、代入・正規化で保たれることを示す。 -/

mutual
  /-- 型の中の全ての data 型の名前が N に入る（篩の述語は読まない）。 -/
  def Ty.DataIn (N : DataName → Prop) : Ty → Prop
    | .data d as => N d ∧ Ty.DataInTys N as
    | .ctor (.data d) => N d
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => a.DataIn N
    | .fn _ ps r e => Ty.DataInTys N ps ∧ r.DataIn N ∧ Eff.DataIn N e
    | .cont b t e => b.DataIn N ∧ t.DataIn N ∧ Eff.DataIn N e
    | .map a b => a.DataIn N ∧ b.DataIn N
    | .tapp _ as | .external _ as => Ty.DataInTys N as
    | .dependentFn t => Tel.DataIn N t
    | _ => True
  def Tel.DataIn (N : DataName → Prop) : Tel → Prop
    | .done r e => r.DataIn N ∧ Eff.DataIn N e
    | .param _ a t => a.DataIn N ∧ Tel.DataIn N t
  def Ty.DataInTys (N : DataName → Prop) : List Ty → Prop
    | [] => True
    | a :: as => a.DataIn N ∧ Ty.DataInTys N as
  def Eff.DataIn (N : DataName → Prop) : Eff → Prop
    | .mk _ fs => Ty.DataInTys N fs
end

theorem Ty.dataInTys_iff {N : DataName → Prop} : ∀ {as : List Ty}, Ty.DataInTys N as ↔ ∀ a ∈ as, a.DataIn N
  | [] => by simp [Ty.DataInTys]
  | a :: as => by simp [Ty.DataInTys, Ty.dataInTys_iff (as := as)]

mutual
  theorem Ty.dataIn_shiftV {N : DataName → Prop} (k c : Nat) {a : Ty} :
      (a.shiftV k c).DataIn N ↔ a.DataIn N := by
    match a with
    | .data d as => simp only [Ty.shiftV, Ty.DataIn, Ty.dataInTys_shiftV]
    | .list a | .reference a | .lazy a | .set a | .dict _ a => simp only [Ty.shiftV, Ty.DataIn, Ty.dataIn_shiftV]
    | .refined a _ => simp only [Ty.shiftV, Ty.DataIn, Ty.dataIn_shiftV]
    | .fn _ ps r e =>
      simp only [Ty.shiftV, Ty.DataIn, Ty.dataInTys_shiftV, Ty.dataIn_shiftV, Eff.dataIn_shiftV]
    | .cont b t e => simp only [Ty.shiftV, Ty.DataIn, Ty.dataIn_shiftV, Eff.dataIn_shiftV]
    | .map a b => simp only [Ty.shiftV, Ty.DataIn, Ty.dataIn_shiftV]
    | .tapp _ as | .external _ as => simp only [Ty.shiftV, Ty.DataIn, Ty.dataInTys_shiftV]
    | .dependentFn t => simp only [Ty.shiftV, Ty.DataIn, Tel.dataIn_shiftV]
    | .ctor _ | .base _ | .opaque _ _ | .tvar _ | .bytes | .scoped _ _ _ | .pathBases | .scopePattern _ =>
      simp only [Ty.shiftV]
  theorem Tel.dataIn_shiftV {N : DataName → Prop} (k c : Nat) {t : Tel} :
      (Tel.shiftV k c t).DataIn N ↔ t.DataIn N := by
    match t with
    | .done r e => simp only [Tel.shiftV, Tel.DataIn, Ty.dataIn_shiftV, Eff.dataIn_shiftV]
    | .param _ a t => simp only [Tel.shiftV, Tel.DataIn, Ty.dataIn_shiftV, Tel.dataIn_shiftV]
  theorem Ty.dataInTys_shiftV {N : DataName → Prop} (k c : Nat) {as : List Ty} :
      Ty.DataInTys N (shiftVTys k c as) ↔ Ty.DataInTys N as := by
    match as with
    | [] => simp only [shiftVTys]
    | a :: as => simp only [shiftVTys, Ty.DataInTys, Ty.dataIn_shiftV, Ty.dataInTys_shiftV]
  theorem Eff.dataIn_shiftV {N : DataName → Prop} (k c : Nat) {e : Eff} :
      (Eff.shiftV k c e).DataIn N ↔ e.DataIn N := by
    match e with
    | .mk _ fs => simp only [Eff.shiftV, Eff.DataIn, Ty.dataInTys_shiftV]
end

theorem Eff.dataIn_iff {N : DataName → Prop} {e : Eff} : e.DataIn N ↔ ∀ t ∈ e.fails, t.DataIn N := by
  cases e; simp only [Eff.DataIn, Eff.fails, Ty.dataInTys_iff]

theorem Ty.dataIn_core {N : DataName → Prop} : ∀ {a : Ty}, a.DataIn N → a.core.DataIn N
  | .refined a _, h => Ty.dataIn_core (a := a) h
  | .base _, h | .opaque _ _, h | .data _ _, h | .list _, h | .fn _ _ _ _, h | .tvar _, h | .reference _, h
  | .lazy _, h | .cont _ _ _, h | .map _ _, h | .set _, h | .bytes, h | .dict _ _, h | .tapp _ _, h
  | .ctor _, h | .dependentFn _, h | .external _ _, h | .scoped _ _ _, h | .pathBases, h
  | .scopePattern _, h => h

theorem Ty.dataIn_toTel {N : DataName → Prop} : ∀ {ns : List String} {ps : List Ty} {r : Ty} {e : Eff},
    ns.length = ps.length → (Ty.toTel ns ps r e).DataIn N → Ty.DataInTys N ps ∧ r.DataIn N ∧ e.DataIn N
  | [], [], r, e, _, h => ⟨trivial, h.1, h.2⟩
  | _ :: ns, a :: ps, r, e, hl, h => by
    simp only [Ty.toTel, Tel.DataIn] at h
    have hlen : ns.length = (shiftVTys 1 0 ps).length := by
      rw [Nat.succ.inj hl]; clear hl h; induction ps with
      | nil => rfl
      | cons _ _ ih => simp only [shiftVTys, List.length_cons, ih]
    obtain ⟨hps, hr, he⟩ := Ty.dataIn_toTel (ns := ns) hlen h.2
    exact ⟨⟨h.1, (Ty.dataInTys_shiftV 1 0).mp hps⟩, (Ty.dataIn_shiftV 1 0).mp hr, (Eff.dataIn_shiftV 1 0).mp he⟩

mutual
  theorem Ty.dataIn_norm {N : DataName → Prop} {a : Ty} (h : a.DataIn N) : a.norm.DataIn N := by
    match a with
    | .data d as => exact ⟨h.1, Ty.dataInTys_norm h.2⟩
    | .list a | .reference a | .lazy a | .set a | .dict _ a => exact Ty.dataIn_norm (a := a) h
    | .fn _ ps r e => exact ⟨Ty.dataInTys_norm h.1, Ty.dataIn_norm h.2.1, Eff.dataIn_norm h.2.2⟩
    | .cont b t e => exact ⟨Ty.dataIn_norm h.1, Ty.dataIn_norm h.2.1, Eff.dataIn_norm h.2.2⟩
    | .map a b => exact ⟨Ty.dataIn_norm h.1, Ty.dataIn_norm h.2⟩
    | .tapp _ as | .external _ as => exact Ty.dataInTys_norm (as := as) h
    | .refined a p =>
      have hc := Ty.dataIn_core (Ty.dataIn_norm (a := a) h)
      simp only [Ty.norm, Ty.refineNorm]
      cases (a.norm.refinementPredicates ++ p.conjuncts) with
      | nil => exact hc
      | cons _ _ => exact hc
    | .dependentFn t =>
      have ht := Tel.dataIn_norm (t := t) h
      simp only [Ty.norm]
      unfold Ty.foldFn
      split
      · rename_i f hf
        have he := (Tel.fnView?_eq_some_iff _ _).mp hf
        rw [← he] at ht
        exact Ty.dataIn_toTel f.names_wf.1 ht
      · exact ht
    | .ctor _ | .base _ | .opaque _ _ | .tvar _ | .bytes | .scoped _ _ _ | .pathBases | .scopePattern _ => exact h
  theorem Tel.dataIn_norm {N : DataName → Prop} {t : Tel} (h : t.DataIn N) : (Tel.norm t).DataIn N := by
    match t with
    | .done r e => exact ⟨Ty.dataIn_norm h.1, Eff.dataIn_norm h.2⟩
    | .param _ a t => exact ⟨Ty.dataIn_norm h.1, Tel.dataIn_norm h.2⟩
  theorem Ty.dataInTys_norm {N : DataName → Prop} {as : List Ty} (h : Ty.DataInTys N as) :
      Ty.DataInTys N (Ty.normTys as) := by
    match as with
    | [] => trivial
    | a :: as => exact ⟨Ty.dataIn_norm h.1, Ty.dataInTys_norm h.2⟩
  theorem Eff.dataIn_norm {N : DataName → Prop} {e : Eff} (h : e.DataIn N) : (Eff.norm e).DataIn N := by
    match e with
    | .mk _ fs =>
      have hn := Ty.dataInTys_norm (as := fs) h
      simp only [Eff.norm, Eff.DataIn, Ty.dataInTys_iff] at hn ⊢
      exact fun t ht => hn t (Order.mem_sortUnique.mp ht)
end

/-- 型と行の像が全て N に入る置換の環境。 -/
def SubstEnv.DataIn (N : DataName → Prop) (θ : SubstEnv) : Prop :=
  (∀ i, (θ.types i).DataIn N) ∧ ∀ e ∈ θ.rows, e.DataIn N

theorem SubstEnv.DataIn.up {N : DataName → Prop} {θ : SubstEnv} (h : θ.DataIn N) : θ.up.DataIn N := by
  refine ⟨fun i => (Ty.dataIn_shiftV 1 0).mpr (h.1 i), fun e he => ?_⟩
  obtain ⟨e', he', rfl⟩ := List.mem_map.mp he
  exact (Eff.dataIn_shiftV 1 0).mpr (h.2 e' he')

theorem Ty.dataIn_rawApply {N : DataName → Prop} : ∀ {t : Ty} {as : List Ty}, t.DataIn N → Ty.DataInTys N as →
    (rawApply t as).DataIn N
  | .ctor (.data d), as, ht, has => ⟨ht, has⟩
  | .ctor .list, as, _, has | .ctor .set, as, _, has | .ctor .reference, as, _, has
  | .ctor .lazy, as, _, has => by
    cases as with
    | nil => trivial
    | cons a _ => exact has.1
  | .ctor .map, as, _, has => by
    match as with
    | [] => exact ⟨trivial, trivial⟩
    | [a] => exact ⟨has.1, trivial⟩
    | a :: b :: _ => exact ⟨has.1, has.2.1⟩
  | .tvar _, _, _, has => has
  | .refined a _, as, ht, has => Ty.dataIn_rawApply (t := a) ht has
  | .base _, _, ht, _ | .opaque _ _, _, ht, _ | .data _ _, _, ht, _ | .list _, _, ht, _
  | .fn _ _ _ _, _, ht, _ | .reference _, _, ht, _ | .lazy _, _, ht, _ | .cont _ _ _, _, ht, _
  | .map _ _, _, ht, _ | .set _, _, ht, _ | .bytes, _, ht, _ | .dict _ _, _, ht, _
  | .tapp _ _, _, ht, _ | .dependentFn _, _, ht, _ | .external _ _, _, ht, _
  | .scoped _ _ _, _, ht, _ | .pathBases, _, ht, _ | .scopePattern _, _, ht, _ => ht

mutual
  theorem Ty.dataIn_rawBind {N : DataName → Prop} {θ : SubstEnv} (hθ : θ.DataIn N) {a : Ty} (h : a.DataIn N) :
      (a.rawBind θ).DataIn N := by
    match a with
    | .data d as => exact ⟨h.1, Ty.dataInTys_rawBind hθ h.2⟩
    | .list a | .reference a | .lazy a | .set a | .dict _ a => exact Ty.dataIn_rawBind hθ (a := a) h
    | .refined a _ => exact Ty.dataIn_rawBind hθ (a := a) h
    | .fn _ ps r e => exact ⟨Ty.dataInTys_rawBind hθ h.1, Ty.dataIn_rawBind hθ h.2.1, Eff.dataIn_rawBind hθ h.2.2⟩
    | .cont b t e => exact ⟨Ty.dataIn_rawBind hθ h.1, Ty.dataIn_rawBind hθ h.2.1, Eff.dataIn_rawBind hθ h.2.2⟩
    | .map a b => exact ⟨Ty.dataIn_rawBind hθ h.1, Ty.dataIn_rawBind hθ h.2⟩
    | .tvar i => exact hθ.1 i
    | .tapp i as => exact Ty.dataIn_rawApply (hθ.1 i) (Ty.dataInTys_rawBind hθ (as := as) h)
    | .external _ as => exact Ty.dataInTys_rawBind hθ (as := as) h
    | .dependentFn t => exact Tel.dataIn_rawBind hθ (t := t) h
    | .ctor _ | .base _ | .opaque _ _ | .bytes | .scoped _ _ _ | .pathBases | .scopePattern _ => exact h
  theorem Tel.dataIn_rawBind {N : DataName → Prop} {θ : SubstEnv} (hθ : θ.DataIn N) {t : Tel} (h : t.DataIn N) :
      (Tel.rawBind θ t).DataIn N := by
    match t with
    | .done r e => exact ⟨Ty.dataIn_rawBind hθ h.1, Eff.dataIn_rawBind hθ h.2⟩
    | .param _ a t => exact ⟨Ty.dataIn_rawBind hθ h.1, Tel.dataIn_rawBind hθ.up h.2⟩
  theorem Ty.dataInTys_rawBind {N : DataName → Prop} {θ : SubstEnv} (hθ : θ.DataIn N) {as : List Ty}
      (h : Ty.DataInTys N as) : Ty.DataInTys N (rawBindTys θ as) := by
    match as with
    | [] => trivial
    | a :: as => exact ⟨Ty.dataIn_rawBind hθ h.1, Ty.dataInTys_rawBind hθ h.2⟩
  theorem Eff.dataIn_rawBind {N : DataName → Prop} {θ : SubstEnv} (hθ : θ.DataIn N) {e : Eff} (h : e.DataIn N) :
      (Eff.rawBind θ e).DataIn N := by
    match e with
    | .mk a fs =>
      have hfs := Ty.dataInTys_rawBind hθ (as := fs) h
      simp only [Eff.rawBind, Eff.DataIn, Ty.dataInTys_iff, List.mem_append] at hfs ⊢
      rintro t (ht | ht)
      · exact hfs t ht
      · simp only [rowFails, List.mem_flatMap] at ht
        obtain ⟨i, -, ht⟩ := ht
        cases hi : θ.rows[i]? with
        | none => simp [hi] at ht
        | some e =>
          simp only [hi] at ht
          exact Eff.dataIn_iff.mp (hθ.2 e (List.mem_of_getElem? hi)) t ht
end

theorem Ty.dataIn_subst {N : DataName → Prop} {a : Ty} {ts : List Ty} (ha : a.DataIn N)
    (hts : ∀ t ∈ ts, t.DataIn N) : (a.subst ts []).DataIn N := by
  refine Ty.dataIn_norm (Ty.dataIn_rawBind ⟨fun i => ?_, fun e he => by simp [typeEnvAt] at he⟩ ha)
  simp only [typeEnvAt, Nat.not_lt_zero, ite_false, Nat.sub_zero, shiftTypes_zero]
  split
  · rename_i hi
    rw [List.getElem?_eq_getElem hi, Option.getD_some]
    exact hts _ (List.getElem_mem hi)
  · trivial

mutual
  theorem Ty.Declared.dataIn {P : Program} {C Γ} {a : Ty} (hd : Ty.Declared P C Γ a) : a.DataIn P.HasData := by
    match a with
    | .data d as =>
      obtain ⟨⟨n, hn, -⟩, has⟩ := hd
      exact ⟨Or.inl hn.1, declaredTys_dataIn has⟩
    | .ctor (.data d) =>
      obtain ⟨n, hn⟩ := hd
      exact Or.inl hn.1
    | .list a | .reference a | .lazy a | .set a | .dict _ a => exact Ty.Declared.dataIn (a := a) hd
    | .refined a _ => exact Ty.Declared.dataIn (a := a) hd.1
    | .fn _ ps r e => exact ⟨declaredTys_dataIn hd.1, Ty.Declared.dataIn hd.2.1, declaredEff_dataIn hd.2.2⟩
    | .cont b t e => exact ⟨Ty.Declared.dataIn hd.1, Ty.Declared.dataIn hd.2.1, declaredEff_dataIn hd.2.2⟩
    | .map a b => exact ⟨Ty.Declared.dataIn hd.1, Ty.Declared.dataIn hd.2⟩
    | .tapp _ as => exact declaredTys_dataIn hd.2
    | .external _ as => exact declaredTys_dataIn hd.2
    | .dependentFn t => exact Tel.Declared.dataIn (t := t) hd
    | .ctor .list | .ctor .set | .ctor .map | .ctor .reference | .ctor .lazy | .base _ | .opaque _ _ | .tvar _
    | .bytes | .scoped _ _ _ | .pathBases | .scopePattern _ => trivial
  theorem Tel.Declared.dataIn {P : Program} {C Γ} {t : Tel} (hd : Tel.Declared P C Γ t) : t.DataIn P.HasData := by
    match t with
    | .done r e => exact ⟨Ty.Declared.dataIn hd.1, declaredEff_dataIn hd.2⟩
    | .param _ a t => exact ⟨Ty.Declared.dataIn hd.1, Tel.Declared.dataIn hd.2⟩
  theorem declaredTys_dataIn {P : Program} {C Γ} {as : List Ty} (hd : declaredTys P C Γ as) :
      Ty.DataInTys P.HasData as := by
    match as with
    | [] => trivial
    | a :: as => exact ⟨Ty.Declared.dataIn hd.1, declaredTys_dataIn hd.2⟩
  theorem declaredEff_dataIn {P : Program} {C Γ} {e : Eff} (hd : declaredEff P C Γ e) : e.DataIn P.HasData := by
    match e with
    | .mk _ fs => exact declaredTys_dataIn hd
end

/-! ### 住む値の逆向きの移送 -/

theorem Program.Extends.dataArity_rev (h : P.Extends P') {d n} (hd : P'.DataArity d n) (hn : P.HasData d) :
    P.DataArity d n := by
  obtain ⟨⟨c, cd, hc, he⟩, hall⟩ := hd
  exact ⟨⟨c, cd, h.consData hc he hn, he⟩, fun c' cd' hc' he' => hall c' cd' (h.cons _ _ hc') he'⟩

/-- 公開の欄の型が読む data 型の名前。 -/
def ScopePublic.PublicTy.dataNames : ScopePublic.PublicTy → List DataName
  | .string | .integer | .bytes => []
  | .list a => a.dataNames
  | .option a => "Option" :: a.dataNames
  | .data d => [d]

theorem ScopePublic.PublicTy.dataNames_of_dataIn {N : DataName → Prop} :
    ∀ {a : ScopePublic.PublicTy}, a.ty.DataIn N → ∀ d ∈ a.dataNames, N d
  | .string, _, _, hd | .integer, _, _, hd | .bytes, _, _, hd => by simp [dataNames] at hd
  | .list a, h, d, hd => dataNames_of_dataIn (a := a) h d hd
  | .option a, h, d, hd => by
    simp only [dataNames, List.mem_cons] at hd
    rcases hd with rfl | hd
    · exact h.1
    · exact dataNames_of_dataIn (a := a) h.2.1 d hd
  | .data e, h, d, hd => by
    simp only [dataNames, List.mem_singleton] at hd
    exact hd ▸ h.1

/-- 公開の宣言の一段の到達。名前の列の data 型の公開の構成子の欄が読む名前を足す。 -/
def ScopePublic.reachStep (R : List DataName) : List DataName :=
  (R ++ (ScopePublic.constructors.filter (fun c => c.2.1 ∈ R)).flatMap
    (fun c => c.2.2.flatMap ScopePublic.PublicTy.dataNames)).eraseDups

def ScopePublic.reach : Nat → List DataName → List DataName
  | 0, R => R
  | n + 1, R => ScopePublic.reach n (ScopePublic.reachStep R)

/-- At の誤り型から、公開の宣言の全ての data 型と Option へ届く。 -/
theorem ScopePublic.reach_all :
    (∀ d ∈ ScopePublic.all, d.name ∈ ScopePublic.reach 5 ["Scope.ScopeError"]) ∧
      "Option" ∈ ScopePublic.reach 5 ["Scope.ScopeError"] := by
  decide

/-- 公開の構成子を P' が持ち、P がその data 型に名前を持てば、欄の型が読む名前も P に名前を持つ。 -/
theorem ScopePublic.reach_sound (h : P.Extends P') (hwf : P.WellFormed) (hp : P'.HasScopePublic) :
    ∀ n R, (∀ d ∈ R, P.HasData d) → ∀ d ∈ ScopePublic.reach n R, P.HasData d := by
  intro n
  induction n with
  | zero => intro R hR; exact hR
  | succ n ih =>
    intro R hR
    apply ih
    intro d hd
    simp only [ScopePublic.reachStep, List.mem_eraseDups, List.mem_append, List.mem_flatMap,
      List.mem_filter, decide_eq_true_eq] at hd
    rcases hd with hd | ⟨⟨c, e, as⟩, ⟨hc, he⟩, a, ha, hda⟩
    · exact hR d hd
    · have hP' := hp.cons c e as hc
      have hPc : P.cons c = some ⟨e, 0, as.map ScopePublic.PublicTy.ty⟩ := h.consData hP' rfl (hR e he)
      have hs := (hwf.cons c _ hPc).2 a.ty (List.mem_map_of_mem ha)
      exact ScopePublic.PublicTy.dataNames_of_dataIn hs.2.1.declared.dataIn d hda

theorem Program.HasScopePublic.ofExtends_rev (h : P.Extends P') (hwf : P.WellFormed) (hp : P'.HasScopePublic)
    (hd : P.HasData "Scope.ScopeError") : P.HasScopePublic := by
  have hr := ScopePublic.reach_sound h hwf hp 5 ["Scope.ScopeError"] (by simp [hd])
  have hopt := hr _ ScopePublic.reach_all.2
  refine ⟨fun d hm => h.dataArity_rev (hp.arity d hm) (hr _ (ScopePublic.reach_all.1 d hm)),
    fun c d as hc => ?_, h.dataArity_rev hp.optionArity hopt, h.consData hp.optionSome rfl hopt,
    h.consData hp.optionNone rfl hopt⟩
  have hdm : d ∈ ScopePublic.all.map ScopePublic.PublicData.name := by
    simp only [ScopePublic.constructors, List.mem_flatMap, List.mem_map] at hc
    obtain ⟨dd, hdd, _, _, he⟩ := hc
    cases he
    exact List.mem_map_of_mem hdd
  obtain ⟨dd, hdd, rfl⟩ := List.mem_map.mp hdm
  exact h.consData (hp.cons c _ as hc) rfl (hr _ (ScopePublic.reach_all.1 dd hdd))

theorem ResultShape.StandardError.ofExtends_rev (h : P.Extends P') (hwf : P.WellFormed) {shape : ResultShape}
    (hs : shape.StandardError P') (hd : P.HasData "Scope.ScopeError") : shape.StandardError P := by
  obtain ⟨he, ha, ⟨cd, hc, hcd, rest⟩, hp⟩ := hs
  exact ⟨he, h.dataArity_rev ha hd, ⟨cd, h.consData hc hcd hd, hcd, rest⟩, hp.ofExtends_rev h hwf hd⟩

mutual
  theorem Inhabits.ofExtends (h : P.Extends P') {a v} (hi : Inhabits P a v) : Inhabits P' a v := by
    match hi with
    | .const => exact .const
    | .con hc hn hw hargs => exact .con (h.cons _ _ hc) hn hw (hargs.ofExtends h)
    | .atError hs => exact .atError (hs.ofExtends h)
    | .list he => exact .list (he.ofExtends h)
    | .refined hi hr => exact .refined (hi.ofExtends h) hr
    | .fn => exact .fn
    | .dependentFn => exact .dependentFn
    | .tvar => exact .tvar
    | .reference => exact .reference
    | .lazy => exact .lazy
    | .cont => exact .cont
    | .map => exact .map
    | .set => exact .set
    | .bytes => exact .bytes
    | .dict => exact .dict
    | .tapp => exact .tapp
    | .ctor => exact .ctor
    | .external => exact .external
    | .scoped => exact .scoped
    | .pathBases => exact .pathBases
    | .scopePattern => exact .scopePattern
    | .checked => exact .checked
    | .checkedRequest => exact .checkedRequest
    | .checkedAtOpaque => exact .checkedAtOpaque
  theorem InhabitsAll.ofExtends (h : P.Extends P') {as vs} (hi : InhabitsAll P as vs) : InhabitsAll P' as vs := by
    match hi with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (hv.ofExtends h) (hs.ofExtends h)
  theorem InhabitsEach.ofExtends (h : P.Extends P') {a vs} (hi : InhabitsEach P a vs) : InhabitsEach P' a vs := by
    match hi with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (hv.ofExtends h) (hs.ofExtends h)
end

mutual
  /-- P で名前を持つ data 型だけを読む型の P' の住む値は、P の住む値である。 -/
  theorem Inhabits.ofExtends_rev (h : P.Extends P') (hwf : P.WellFormed) {a v} (hi : Inhabits P' a v)
      (ha : a.DataIn P.HasData) : Inhabits P a v := by
    match hi with
    | .const => exact .const
    | .con (ts := ts) (cd := cd) hc hn hw hargs =>
      have hP := h.consData hc rfl ha.1
      have hts := Ty.dataInTys_iff.mp ha.2
      refine .con hP hn hw (hargs.ofExtends_rev h hwf (Ty.dataInTys_iff.mpr fun x hx => ?_))
      obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hx
      exact Ty.dataIn_subst ((hwf.cons _ cd hP).2 b hb).2.1.declared.dataIn hts
    | .atError hs => exact .atError (hs.ofExtends_rev h hwf ha.1)
    | .list he => exact .list (he.ofExtends_rev h hwf ha)
    | .refined hi hr => exact .refined (hi.ofExtends_rev h hwf ha) hr
    | .fn => exact .fn
    | .dependentFn => exact .dependentFn
    | .tvar => exact .tvar
    | .reference => exact .reference
    | .lazy => exact .lazy
    | .cont => exact .cont
    | .map => exact .map
    | .set => exact .set
    | .bytes => exact .bytes
    | .dict => exact .dict
    | .tapp => exact .tapp
    | .ctor => exact .ctor
    | .external => exact .external
    | .scoped => exact .scoped
    | .pathBases => exact .pathBases
    | .scopePattern => exact .scopePattern
    | .checked => exact .checked
    | .checkedRequest => exact .checkedRequest
    | .checkedAtOpaque => exact .checkedAtOpaque
  theorem InhabitsAll.ofExtends_rev (h : P.Extends P') (hwf : P.WellFormed) {as vs} (hi : InhabitsAll P' as vs)
      (ha : Ty.DataInTys P.HasData as) : InhabitsAll P as vs := by
    match hi with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (hv.ofExtends_rev h hwf ha.1) (hs.ofExtends_rev h hwf ha.2)
  theorem InhabitsEach.ofExtends_rev (h : P.Extends P') (hwf : P.WellFormed) {a vs} (hi : InhabitsEach P' a vs)
      (ha : a.DataIn P.HasData) : InhabitsEach P a vs := by
    match hi with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (hv.ofExtends_rev h hwf ha) (hs.ofExtends_rev h hwf ha)
end

/-- P で宣言済みの型の網羅性は、P と P' で同じである。 -/
theorem Program.extends_exhaustive {P P' : Program} : Program.ExtendsExhaustiveStatement P P' := by
  intro h hwf C Γ a ps hd
  have hn : a.norm.DataIn P.HasData := hd.norm.dataIn
  exact ⟨fun hex v hv => hex v (hv.ofExtends_rev h hwf hn), fun hex v hv => hex v (hv.ofExtends h)⟩

end
end Benitoite.Release.Refinement
