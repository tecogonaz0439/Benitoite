import Benitoite.Release.Refinement.ProgramTyping
import Benitoite.Release.Refinement.PathFacts
import Benitoite.Release.Refinement.VarianceValidation
import Benitoite.Release.Refinement.External
import Benitoite.Release.Refinement.ProgramWellFormed

/-!
# 型の宣言が同じプログラムの間の型の判断の移し

表層の型付けは、型の宣言の照合（宣言済み・kind・部分型・パターン・網羅性）を、関数の定義と実装の本体を持たない
宣言の表のプログラムで行う（設計書 01-12「型の情報を付けた表層の構文と型付け」）。脱糖したプログラムは本体だけが違うので、
構成子・操作・エフェクト・型クラス・外部宣言・変性の宣言が同じ二つのプログラムの間で、これらの判断を移す。
-/

namespace Benitoite.Release.Refinement

/-- 型の判断が読む宣言の欄が同じであること。関数の定義と実装の本体は比べない。 -/
structure Program.SameTypes (P Q : Program) : Prop where
  cons : P.cons = Q.cons
  ops : P.ops = Q.ops
  effects : P.effects = Q.effects
  classes : P.classes = Q.classes
  externals : P.externals = Q.externals
  dataInfo : P.dataInfo = Q.dataInfo

namespace Program.SameTypes

variable {P Q : Program}

theorem symm (h : P.SameTypes Q) : Q.SameTypes P :=
  ⟨h.cons.symm, h.ops.symm, h.effects.symm, h.classes.symm, h.externals.symm, h.dataInfo.symm⟩

theorem varianceFor (h : P.SameTypes Q) (d : DataName) (n : Nat) :
    P.varianceFor d n = Q.varianceFor d n := by
  simp only [Program.varianceFor, h.dataInfo]

theorem dataArity (h : P.SameTypes Q) (d : DataName) (n : Nat) :
    P.DataArity d n ↔ Q.DataArity d n := by
  simp only [Program.DataArity, h.cons]

theorem dataArity_eq (h : P.SameTypes Q) : P.DataArity = Q.DataArity := by
  funext d n
  simp only [Program.DataArity, h.cons]

open Classical in
private theorem choose_congr {f g : DataName → Nat → Prop} (e : f = g) (d : DataName) :
    (if h : ∃ n, f d n then some (Classical.choose h) else none) =
      (if h : ∃ n, g d n then some (Classical.choose h) else none) := by
  subst e; rfl

theorem tyConArity (h : P.SameTypes Q) : TyCon.arity P = TyCon.arity Q := by
  funext c
  cases c with
  | data d => exact choose_congr h.dataArity_eq d
  | _ => rfl

theorem externalType (h : P.SameTypes Q) (id : ExternalId) :
    P.externalType id = Q.externalType id := by
  simp only [Program.externalType, h.externals]

end Program.SameTypes

variable {P Q : Program}

/-! ## 部分型 -/

mutual
  theorem Ty.LeQ.sameTypes {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) (hs : P.SameTypes Q) : Ty.LeQ Q Γ Φ a b := by
    match h with
    | .refl => exact .refl
    | .convert e => exact .convert e
    | .trans h g => exact .trans (h.sameTypes hs) (g.sameTypes hs)
    | .fn_effect e => exact .fn_effect e
    | .list h => exact .list (h.sameTypes hs)
    | .lazy h => exact .lazy (h.sameTypes hs)
    | .map_value e h => exact .map_value e (h.sameTypes hs)
    | .forget => exact .forget
    | .introduce s e => exact .introduce s e
    | .refine h s t e => exact .refine (h.sameTypes hs) s t e
    | .dependentFn h => exact .dependentFn (h.sameTypes hs)
    | .scoped c => exact .scoped c
    | .scoped_forget => exact .scoped_forget
    | .data (d := d) (as := as) h => exact .data (by rw [← hs.varianceFor d as.length]; exact h.sameTypes hs)
  theorem TelLe.sameTypes {Γ Φ t u} (h : TelLe P Γ Φ t u) (hs : P.SameTypes Q) : TelLe Q Γ Φ t u := by
    match h with
    | .done h e => exact .done (h.sameTypes hs) e
    | .param h t => exact .param (h.sameTypes hs) (t.sameTypes hs)
  theorem TelClosure.sameTypes {Γ Φ t u} (h : TelClosure P Γ Φ t u) (hs : P.SameTypes Q) :
      TelClosure Q Γ Φ t u := by
    match h with
    | .refl => exact .refl
    | .tail h g => exact .tail (h.sameTypes hs) (g.sameTypes hs)
  theorem TypeArgsLe.sameTypes {Γ Φ vs as bs} (h : TypeArgsLe P Γ Φ vs as bs) (hs : P.SameTypes Q) :
      TypeArgsLe Q Γ Φ vs as bs := by
    match h with
    | .nil => exact .nil
    | .covariant_cons h t => exact .covariant_cons (h.sameTypes hs) (t.sameTypes hs)
    | .contravariant_cons h t => exact .contravariant_cons (h.sameTypes hs) (t.sameTypes hs)
    | .invariant_cons e t => exact .invariant_cons e (t.sameTypes hs)
end

theorem DataObservationLe.sameTypes {d as bs} (h : DataObservationLe P d as bs) (hs : P.SameTypes Q) :
    DataObservationLe Q d as bs := by
  unfold DataObservationLe at h ⊢
  rw [← hs.varianceFor]
  exact h.sameTypes hs

/-! ## 宣言済み -/

theorem Term.HasData.sameTypes {Γ t d ts} (h : Term.HasData P Γ t d ts) (hs : P.SameTypes Q) :
    Term.HasData Q Γ t d ts := by
  induction h with
  | var hi hc => exact .var hi hc
  | value hc hd hn hl => exact .value (hs.cons ▸ hc) hd hn hl
  | field _ hc hd hn ha hw hr hcore ih => exact .field ih (hs.cons ▸ hc) hd hn ha hw hr hcore
  | widen _ ho ih => exact .widen ih (ho.sameTypes hs)

theorem FieldRef.Declared.sameTypes {C Γ t ref} (h : FieldRef.Declared P C Γ t ref) (hs : P.SameTypes Q) :
    FieldRef.Declared Q C Γ t ref := by
  obtain ⟨ts, cd, a, hd, hc, h1, h2, h3, h4, h5⟩ := h
  exact ⟨ts, cd, a, hd.sameTypes hs, hs.cons ▸ hc, h1, h2, h3, h4, h5⟩

mutual
  theorem Term.Declared.sameTypes {C Γ} : ∀ {t : Term}, Term.Declared P C Γ t → P.SameTypes Q →
      Term.Declared Q C Γ t
    | .var _, h, _ => h
    | .field _ t, h, hs => ⟨Term.Declared.sameTypes (t := t) h.1 hs, h.2.sameTypes hs⟩
    | .measure _ t, h, hs => Term.Declared.sameTypes (t := t) h hs
    | .neg t, h, hs => Term.Declared.sameTypes (t := t) h hs
    | .scale _ t, h, hs => Term.Declared.sameTypes (t := t) h hs
    | .add a b, h, hs => ⟨Term.Declared.sameTypes (t := a) h.1 hs, Term.Declared.sameTypes (t := b) h.2 hs⟩
    | .listValue xs, h, hs => declaredSlots.sameTypes (xs := xs) h hs
    | .setValue xs, h, hs => declaredSlots.sameTypes (xs := xs) h hs
    | .mapValue ks vs, h, hs => ⟨declaredSlots.sameTypes (xs := ks) h.1 hs, declaredSlots.sameTypes (xs := vs) h.2 hs⟩
    | .dataValue _ xs, h, hs => ⟨declaredSlots.sameTypes (xs := xs) h.1 hs, by
        obtain ⟨cd, hc, hl⟩ := h.2; exact ⟨cd, hs.cons ▸ hc, hl⟩⟩
    | .integer _, h, _ | .float64 _, h, _ | .float32 _, h, _ | .character _, h, _ | .string _, h, _
    | .boolean _, h, _ | .unitValue, h, _ | .decimal _ _, h, _ | .bytesValue _, h, _
    | .targetValue _ _, h, _ => h
  theorem declaredSlots.sameTypes {C Γ} : ∀ {xs : List (Option Term)}, declaredSlots P C Γ xs →
      P.SameTypes Q → declaredSlots Q C Γ xs
    | [], h, _ => h
    | none :: xs, h, hs => ⟨trivial, declaredSlots.sameTypes (xs := xs) h.2 hs⟩
    | some t :: xs, h, hs => ⟨Term.Declared.sameTypes (t := t) h.1 hs, declaredSlots.sameTypes (xs := xs) h.2 hs⟩
end

theorem Pred.Declared.sameTypes {C Γ self} : ∀ {p : Pred}, Pred.Declared P C Γ self p → P.SameTypes Q →
    Pred.Declared Q C Γ self p
  | .truth, h, _ | .falsity, h, _ => h
  | .eq _ _, h, hs | .le _ _, h, hs | .lt _ _, h, hs | .compare _ _ _ _, h, hs =>
      ⟨h.1.sameTypes hs, h.2.sameTypes hs⟩
  | .floatClass _ _ _, h, hs | .decimalRepresented _, h, hs | .charactersIn _ _ _, h, hs
  | .member _ _ _, h, hs => Term.Declared.sameTypes h hs
  | .constructorIs _ _, h, hs => ⟨h.1.sameTypes hs, by
      obtain ⟨d, ts, cd, hd, hc, he⟩ := h.2; exact ⟨d, ts, cd, hd.sameTypes hs, hs.cons ▸ hc, he⟩⟩
  | .and p q, h, hs | .or p q, h, hs =>
      ⟨Pred.Declared.sameTypes (p := p) h.1 hs, Pred.Declared.sameTypes (p := q) h.2 hs⟩
  | .not p, h, hs => Pred.Declared.sameTypes (p := p) h hs

mutual
  theorem Ty.Declared.sameTypes {C} : ∀ {Γ : Ctx} {a : Ty}, Ty.Declared P C Γ a → P.SameTypes Q →
      Ty.Declared Q C Γ a
    | _, .base _, h, _ | _, .bytes, h, _ | _, .opaque _ _, h, _ | _, .scoped _ _ _, h, _
    | _, .pathBases, h, _ | _, .scopePattern _, h, _ | _, .tvar _, h, _ => h
    | _, .data _ as, h, hs => ⟨by
        obtain ⟨n, hn, hl⟩ := h.1; exact ⟨n, (hs.dataArity _ _).mp hn, hl⟩,
        declaredTys.sameTypes (as := as) h.2 hs⟩
    | _, .external id as, h, hs => ⟨by rw [← hs.externalType]; exact h.1, declaredTys.sameTypes (as := as) h.2 hs⟩
    | _, .tapp _ as, h, hs => ⟨h.1, declaredTys.sameTypes (as := as) h.2 hs⟩
    | _, .ctor (.data _), h, hs => by
        obtain ⟨n, hn⟩ := h; exact ⟨n, (hs.dataArity _ _).mp hn⟩
    | _, .ctor .list, h, _ | _, .ctor .set, h, _ | _, .ctor .map, h, _ | _, .ctor .reference, h, _
    | _, .ctor .lazy, h, _ => h
    | _, .list a, h, hs | _, .reference a, h, hs | _, .lazy a, h, hs | _, .set a, h, hs
    | _, .dict _ a, h, hs => Ty.Declared.sameTypes (a := a) h hs
    | _, .fn _ ps r e, h, hs =>
        ⟨declaredTys.sameTypes (as := ps) h.1 hs, Ty.Declared.sameTypes (a := r) h.2.1 hs,
          declaredEff.sameTypes (e := e) h.2.2 hs⟩
    | _, .dependentFn t, h, hs => Tel.Declared.sameTypes (t := t) h hs
    | _, .cont b t e, h, hs =>
        ⟨Ty.Declared.sameTypes (a := b) h.1 hs, Ty.Declared.sameTypes (a := t) h.2.1 hs,
          declaredEff.sameTypes (e := e) h.2.2 hs⟩
    | _, .map a b, h, hs => ⟨Ty.Declared.sameTypes (a := a) h.1 hs, Ty.Declared.sameTypes (a := b) h.2 hs⟩
    | _, .refined a p, h, hs => ⟨Ty.Declared.sameTypes (a := a) h.1 hs, h.2.sameTypes hs⟩
  theorem Tel.Declared.sameTypes {C} : ∀ {Γ : Ctx} {t : Tel}, Tel.Declared P C Γ t → P.SameTypes Q →
      Tel.Declared Q C Γ t
    | _, .done r e, h, hs => ⟨Ty.Declared.sameTypes (a := r) h.1 hs, declaredEff.sameTypes (e := e) h.2 hs⟩
    | _, .param _ a t, h, hs => ⟨Ty.Declared.sameTypes (a := a) h.1 hs, Tel.Declared.sameTypes (t := t) h.2 hs⟩
  theorem declaredTys.sameTypes {C} : ∀ {Γ : Ctx} {as : List Ty}, declaredTys P C Γ as → P.SameTypes Q →
      declaredTys Q C Γ as
    | _, [], h, _ => h
    | _, a :: as, h, hs => ⟨Ty.Declared.sameTypes (a := a) h.1 hs, declaredTys.sameTypes (as := as) h.2 hs⟩
  theorem declaredEff.sameTypes {C} : ∀ {Γ : Ctx} {e : Eff}, declaredEff P C Γ e → P.SameTypes Q →
      declaredEff Q C Γ e
    | _, .mk _ fs, h, hs => declaredTys.sameTypes (as := fs) h hs
end

theorem Ty.Annotation.sameTypes {C Γ a} (h : Ty.Annotation P C Γ a) (hs : P.SameTypes Q) :
    Ty.Annotation Q C Γ a :=
  ⟨h.wf, h.sorted, h.declared.sameTypes hs⟩

theorem TypeAnnotations.sameTypes {C Γ ts} (h : TypeAnnotations P C Γ ts) (hs : P.SameTypes Q) :
    TypeAnnotations Q C Γ ts := fun t ht => (h t ht).sameTypes hs

theorem RowAnnotations.sameTypes {C Γ es} (h : RowAnnotations P C Γ es) (hs : P.SameTypes Q) :
    RowAnnotations Q C Γ es := fun e he => (h e he).sameTypes hs

theorem FactsWF.sameTypes {C Γ Φ} (h : FactsWF P C Γ Φ) (hs : P.SameTypes Q) : FactsWF Q C Γ Φ :=
  fun p hp => ⟨(h p hp).wf, (h p hp).sorted, (h p hp).declared.sameTypes hs⟩

/-! ## kind -/

mutual
  theorem Ty.HasKind.sameTypes {K} : ∀ {a : Ty} {k : TyKind}, Ty.HasKind P K a k → P.SameTypes Q →
      Ty.HasKind Q K a k
    | a, .constructor n, h, hs => by
        cases a <;> simp only [Ty.HasKind] at h ⊢ <;> try exact h
        rw [← hs.tyConArity]; exact h
    | .base _, .value, h, _ | .bytes, .value, h, _ | .opaque _ _, .value, h, _ | .scoped _ _ _, .value, h, _
    | .pathBases, .value, h, _ | .scopePattern _, .value, h, _ | .tvar _, .value, h, _ | .ctor _, .value, h, _ => h
    | .data _ as, .value, h, hs => ⟨by rw [← hs.tyConArity]; exact h.1, kindsList.sameTypes (as := as) h.2 hs⟩
    | .external _ as, .value, h, hs => kindsList.sameTypes (as := as) h hs
    | .list a, .value, h, hs | .reference a, .value, h, hs | .lazy a, .value, h, hs
    | .set a, .value, h, hs => Ty.HasKind.sameTypes (a := a) h hs
    | .dict _ a, .value, h, hs => by
        obtain ⟨cd, hc, hk⟩ := h; exact ⟨cd, hs.classes ▸ hc, Ty.HasKind.sameTypes (a := a) hk hs⟩
    | .fn _ ps r e, .value, h, hs =>
        ⟨h.1, kindsList.sameTypes (as := ps) h.2.1 hs, Ty.HasKind.sameTypes (a := r) h.2.2.1 hs,
          kindsEff.sameTypes (e := e) h.2.2.2 hs⟩
    | .dependentFn t, .value, h, hs => kindsTel.sameTypes (t := t) h hs
    | .cont b t e, .value, h, hs =>
        ⟨Ty.HasKind.sameTypes (a := b) h.1 hs, Ty.HasKind.sameTypes (a := t) h.2.1 hs,
          kindsEff.sameTypes (e := e) h.2.2 hs⟩
    | .map a b, .value, h, hs => ⟨Ty.HasKind.sameTypes (a := a) h.1 hs, Ty.HasKind.sameTypes (a := b) h.2 hs⟩
    | .tapp _ as, .value, h, hs => ⟨h.1, kindsList.sameTypes (as := as) h.2 hs⟩
    | .refined a _, .value, h, hs => ⟨Ty.HasKind.sameTypes (a := a) h.1 hs, h.2⟩
  theorem kindsTel.sameTypes {K} : ∀ {t : Tel}, kindsTel P K t → P.SameTypes Q → kindsTel Q K t
    | .done r e, h, hs => ⟨Ty.HasKind.sameTypes (a := r) h.1 hs, kindsEff.sameTypes (e := e) h.2 hs⟩
    | .param _ a t, h, hs => ⟨Ty.HasKind.sameTypes (a := a) h.1 hs, kindsTel.sameTypes (t := t) h.2 hs⟩
  theorem kindsList.sameTypes {K} : ∀ {as : List Ty}, kindsList P K as → P.SameTypes Q → kindsList Q K as
    | [], h, _ => h
    | a :: as, h, hs => ⟨Ty.HasKind.sameTypes (a := a) h.1 hs, kindsList.sameTypes (as := as) h.2 hs⟩
  theorem kindsEff.sameTypes {K} : ∀ {e : Eff}, kindsEff P K e → P.SameTypes Q → kindsEff Q K e
    | .mk _ fs, h, hs => kindsList.sameTypes (as := fs) h hs
end

theorem TypeArgsKinded.sameTypes {C ts ks} (h : TypeArgsKinded P C ts ks) (hs : P.SameTypes Q) :
    TypeArgsKinded Q C ts ks :=
  ⟨h.1, fun i a k ha hk => ⟨(h.2 i a k ha hk).1.sameTypes hs, (h.2 i a k ha hk).2⟩⟩

theorem SignatureInstance.sameTypes {C Γ t ks ts es} (h : SignatureInstance P C Γ t ks ts es)
    (hs : P.SameTypes Q) : SignatureInstance Q C Γ t ks ts es :=
  ⟨h.source, h.types.sameTypes hs, h.kinds.sameTypes hs, h.rows.sameTypes hs,
    fun e he => (h.rowKinds e he).sameTypes hs, h.result.sameTypes hs⟩

/-! ## パターンと網羅性 -/

mutual
  theorem PatTy.sameTypes {p a δ} (h : PatTy P p a δ) (hs : P.SameTypes Q) : PatTy Q p a δ := by
    match h with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const h => exact .P_Const h
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List hb ha hr => exact .P_List (hb.sameTypes hs) (ha.sameTypes hs) hr
    | .P_Convert e h => exact .P_Convert e (h.sameTypes hs)
    | .P_Refined h => exact .P_Refined (h.sameTypes hs)
    | .P_Con hc hn hw hps => exact .P_Con (hs.cons ▸ hc) hn hw (hps.sameTypes hs)
  theorem PatTys.sameTypes {ps as δ} (h : PatTys P ps as δ) (hs : P.SameTypes Q) : PatTys Q ps as δ := by
    match h with
    | .nil => exact .nil
    | .cons h t => exact .cons (h.sameTypes hs) (t.sameTypes hs)
end

theorem AltsTy.sameTypes {alts a δ} (h : AltsTy P alts a δ) (hs : P.SameTypes Q) : AltsTy Q alts a δ := by
  obtain ⟨h1, h2, h3, h4⟩ := h
  exact ⟨h1, h2, h3, fun alt ha => by
    obtain ⟨γ, hp, hperm, hsel⟩ := h4 alt ha
    exact ⟨γ, hp.sameTypes hs, hperm, hsel⟩⟩

theorem ResultShape.StandardError.sameTypes {shape} (h : ResultShape.StandardError P shape)
    (hs : P.SameTypes Q) : ResultShape.StandardError Q shape := by
  obtain ⟨h1, h2, h3, h4⟩ := h
  refine ⟨h1, (hs.dataArity _ _).mp h2, ?_, ?_⟩
  · obtain ⟨cd, hc, hr⟩ := h3; exact ⟨cd, hs.cons ▸ hc, hr⟩
  · obtain ⟨a1, a2, a3, a4, a5⟩ := h4
    exact ⟨fun d hd => (hs.dataArity _ _).mp (a1 d hd), fun c d as hm => hs.cons ▸ a2 c d as hm,
      (hs.dataArity _ _).mp a3, hs.cons ▸ a4, hs.cons ▸ a5⟩

mutual
  theorem Inhabits.sameTypes {a v} (h : Inhabits P a v) (hs : P.SameTypes Q) : Inhabits Q a v := by
    match h with
    | .const => exact .const
    | .con hc hn hw ha => exact .con (hs.cons ▸ hc) hn hw (ha.sameTypes hs)
    | .atError h => exact .atError (h.sameTypes hs)
    | .list h => exact .list (h.sameTypes hs)
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
    | .refined h r => exact .refined (h.sameTypes hs) r
    | .checked => exact .checked
    | .checkedRequest => exact .checkedRequest
    | .checkedAtOpaque => exact .checkedAtOpaque
  theorem InhabitsAll.sameTypes {as vs} (h : InhabitsAll P as vs) (hs : P.SameTypes Q) : InhabitsAll Q as vs := by
    match h with
    | .nil => exact .nil
    | .cons h t => exact .cons (h.sameTypes hs) (t.sameTypes hs)
  theorem InhabitsEach.sameTypes {a vs} (h : InhabitsEach P a vs) (hs : P.SameTypes Q) : InhabitsEach Q a vs := by
    match h with
    | .nil => exact .nil
    | .cons h t => exact .cons (h.sameTypes hs) (t.sameTypes hs)
end

/-- 網羅性は値の型の住人の全称なので、逆向きの移しで移る。 -/
theorem Exhaustive.sameTypes {a ps} (h : Exhaustive P a ps) (hs : P.SameTypes Q) : Exhaustive Q a ps :=
  fun v hv => h v (hv.sameTypes hs.symm)

/-! ## 変性と外部宣言 -/

mutual
  theorem Ty.VarianceOK.sameTypes {vs} : ∀ {p : Polarity} {a : Ty}, Ty.VarianceOK P vs p a → P.SameTypes Q →
      Ty.VarianceOK Q vs p a
    | _, .tvar _, h, _ => h
    | _, .data d as, h, hs => by
        simp only [Ty.VarianceOK] at h ⊢; rw [← hs.varianceFor]; exact varianceArgsOK.sameTypes h hs
    | _, .list a, h, hs | _, .lazy a, h, hs => Ty.VarianceOK.sameTypes (a := a) h hs
    | _, .fn _ ps r e, h, hs => ⟨varianceTysOK.sameTypes (as := ps) h.1 hs, Ty.VarianceOK.sameTypes (a := r) h.2.1 hs,
        Eff.VarianceOK.sameTypes (e := e) h.2.2 hs⟩
    | _, .map k a, h, hs => ⟨Ty.VarianceOK.sameTypes (a := k) h.1 hs, Ty.VarianceOK.sameTypes (a := a) h.2 hs⟩
    | _, .reference a, h, hs | _, .set a, h, hs | _, .dict _ a, h, hs => Ty.VarianceOK.sameTypes (a := a) h hs
    | _, .cont a b e, h, hs => ⟨Ty.VarianceOK.sameTypes (a := a) h.1 hs, Ty.VarianceOK.sameTypes (a := b) h.2.1 hs,
        Eff.VarianceOK.sameTypes (e := e) h.2.2 hs⟩
    | _, .tapp _ as, h, hs => ⟨h.1, varianceTysOK.sameTypes (as := as) h.2 hs⟩
    | _, .external _ as, h, hs => varianceTysOK.sameTypes (as := as) h hs
    | _, .refined a _, h, hs => Ty.VarianceOK.sameTypes (a := a) h hs
    | _, .dependentFn t, h, hs => Tel.VarianceOK.sameTypes (t := t) h hs
    | _, .base _, h, _ | _, .opaque _ _, h, _ | _, .bytes, h, _ | _, .ctor _, h, _ | _, .scoped _ _ _, h, _
    | _, .pathBases, h, _ | _, .scopePattern _, h, _ => h
  theorem Tel.VarianceOK.sameTypes {vs} : ∀ {p : Polarity} {t : Tel}, Tel.VarianceOK P vs p t → P.SameTypes Q →
      Tel.VarianceOK Q vs p t
    | _, .done r e, h, hs => ⟨Ty.VarianceOK.sameTypes (a := r) h.1 hs, Eff.VarianceOK.sameTypes (e := e) h.2 hs⟩
    | _, .param _ a t, h, hs => ⟨Ty.VarianceOK.sameTypes (a := a) h.1 hs, Tel.VarianceOK.sameTypes (t := t) h.2 hs⟩
  theorem Eff.VarianceOK.sameTypes {vs} : ∀ {p : Polarity} {e : Eff}, Eff.VarianceOK P vs p e → P.SameTypes Q →
      Eff.VarianceOK Q vs p e
    | _, .mk _ fs, h, hs => varianceTysOK.sameTypes (as := fs) h hs
  theorem varianceTysOK.sameTypes {vs} : ∀ {p : Polarity} {as : List Ty}, varianceTysOK P vs p as → P.SameTypes Q →
      varianceTysOK Q vs p as
    | _, [], h, _ => h
    | _, a :: as, h, hs => ⟨Ty.VarianceOK.sameTypes (a := a) h.1 hs, varianceTysOK.sameTypes (as := as) h.2 hs⟩
  theorem varianceArgsOK.sameTypes {vs} : ∀ {p : Polarity} {ws : List Variance} {as : List Ty},
      varianceArgsOK P vs p ws as → P.SameTypes Q → varianceArgsOK Q vs p ws as
    | _, [], [], h, _ => h
    | _, _ :: ws, a :: as, h, hs => ⟨Ty.VarianceOK.sameTypes (a := a) h.1 hs, varianceArgsOK.sameTypes (ws := ws) (as := as) h.2 hs⟩
    | _, [], _ :: _, h, _ => h
    | _, _ :: _, [], h, _ => h
end

theorem Program.VarianceValid.sameTypes (h : P.VarianceValid) (hs : P.SameTypes Q) : Q.VarianceValid := by
  obtain ⟨h1, h2⟩ := h
  refine ⟨fun d info hd => ?_, fun c cd hc => ?_⟩
  · obtain ⟨a1, a2, a3, a4⟩ := h1 d info (hs.dataInfo ▸ hd)
    refine ⟨a1, fun i v hv hno => a2 i v hv (fun ho => hno ?_), fun a ha => (a3 a ha).sameTypes hs,
      fun it hi => (a4 it hi).sameTypes hs⟩
    obtain ⟨c, cd, a, hc, hd, ha, hp⟩ := ho
    exact ⟨c, cd, a, hs.cons ▸ hc, hd, ha, hp⟩
  · obtain ⟨b1, b2⟩ := h2 c cd (hs.cons ▸ hc)
    refine ⟨fun info hi => b1 info (hs.dataInfo ▸ hi), fun a ha => ?_⟩
    obtain ⟨c1, c2, c3⟩ := b2 a ha
    exact ⟨c1.sameTypes hs, c2.sameTypes hs, by rw [← hs.varianceFor]; exact c3.sameTypes hs⟩

theorem ExternalValueType.sameTypes {comp unit a} (h : ExternalValueType P comp unit a) (hs : P.SameTypes Q) :
    ExternalValueType Q comp unit a := by
  induction h with
  | scalar hb => exact .scalar hb
  | unit => exact .unit
  | bytes => exact .bytes
  | handle ht h1 h2 h3 h4 => exact .handle (by rw [← hs.externalType]; exact ht) h1 h2 h3 h4
  | list _ ih => exact .list ih
  | map hk _ ih => exact .map hk ih
  | flags cs hn h1 h2 hm ha hargs =>
    exact .flags cs hn h1 h2 (by intro c; rw [← hs.cons]; exact hm c) ((hs.dataArity _ _).mp ha)
      (fun c cd hc => hargs c cd (hs.cons ▸ hc))
  | data cs hn hne hm ha _ ih =>
    exact .data cs hn hne (by intro c; rw [← hs.cons]; exact hm c) ((hs.dataArity _ _).mp ha)
      (fun c cd hc hd a ham => ih c cd (hs.cons ▸ hc) hd a ham)
  | refined _ ih => exact .refined ih

theorem ExternalOccurrence.sameTypes {a path id} (h : ExternalOccurrence P a path id) (hs : P.SameTypes Q) :
    ExternalOccurrence Q a path id := by
  induction h with
  | root => exact .root
  | element _ ih => exact .element ih
  | key _ ih => exact .key ih
  | value _ ih => exact .value ih
  | field hc hd hn ha _ ih => exact .field (hs.cons ▸ hc) hd hn ha ih
  | refined _ ih => exact .refined ih

theorem ExternalUseAt.sameTypes {n t use} (h : ExternalUseAt P n t use) (hs : P.SameTypes Q) :
    ExternalUseAt Q n t use := by
  induction h with
  | argument ho => exact .argument (ho.sameTypes hs)
  | next _ ih => exact .next ih
  | result ho => exact .result (ho.sameTypes hs)

theorem ExternalTelWF.sameTypes {comp e t} (h : ExternalTelWF P comp e t) (hs : P.SameTypes Q) :
    ExternalTelWF Q comp e t := by
  induction h with
  | done ha he => exact .done (ha.sameTypes hs) he
  | param ha _ ih => exact .param (ha.sameTypes hs) ih

theorem ExternalSignature.WF.sameTypes {d} (h : ExternalSignature.WF P d) (hs : P.SameTypes Q) :
    ExternalSignature.WF Q d :=
  ⟨h.monomorphic, h.kinds, h.annotation.sameTypes hs, h.kinded.sameTypes hs,
    fun use => ⟨fun hu => ((h.uses_exact use).mp hu).sameTypes hs,
      fun hu => (h.uses_exact use).mpr (hu.sameTypes hs.symm)⟩,
    h.uses_unique, h.shape.sameTypes hs, h.sourceTelRows⟩

theorem Program.ExternalWF.sameTypes (h : P.ExternalWF) (hs : P.SameTypes Q) : Q.ExternalWF := by
  refine ⟨hs.externals ▸ h.unique, fun key decl hm => ?_⟩
  have hk := h.keys key decl (hs.externals ▸ hm)
  cases key <;> cases decl <;> simp only at hk ⊢
  · exact hk
  · exact ⟨hk.1, hk.2.sameTypes hs⟩

/-! ## 宣言の整形式 -/

theorem SignatureScoped.sameTypes {C ne t} (h : SignatureScoped P C ne t) (hs : P.SameTypes Q) :
    SignatureScoped Q C ne t :=
  ⟨h.1, h.2.1, h.2.2.1.sameTypes hs, h.2.2.2.sameTypes hs⟩

theorem ConDecl.Scoped.sameTypes {cd} (h : ConDecl.Scoped P cd) (hs : P.SameTypes Q) : ConDecl.Scoped Q cd :=
  fun a ha => ⟨(h a ha).1, (h a ha).2.1.sameTypes hs, (h a ha).2.2.sameTypes hs⟩

theorem OpDecl.Scoped.sameTypes {od} (h : OpDecl.Scoped P od) (hs : P.SameTypes Q) : OpDecl.Scoped Q od :=
  ⟨h.1, h.2.1, h.2.2.1, h.2.2.2.sameTypes hs⟩

theorem ClassDecl.Scoped.sameTypes {cl} (h : ClassDecl.Scoped P cl) (hs : P.SameTypes Q) : ClassDecl.Scoped Q cl :=
  fun m ms hm => ⟨(h m ms hm).1, (h m ms hm).2.sameTypes hs⟩

theorem Program.MetadataScoped.sameTypes (h : P.MetadataScoped) (hs : P.SameTypes Q) : Q.MetadataScoped := by
  intro d info hd
  obtain ⟨h1, h2, h3⟩ := h d info (hs.dataInfo ▸ hd)
  exact ⟨h1, fun c cd hc => h2 c cd (hs.cons ▸ hc),
    fun a ha => ⟨(h3 a ha).1, (h3 a ha).2.1.sameTypes hs, (h3 a ha).2.2.sameTypes hs⟩⟩

end Benitoite.Release.Refinement
