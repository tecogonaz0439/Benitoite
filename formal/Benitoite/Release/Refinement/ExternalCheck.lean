import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.Carrier
import Benitoite.Release.Refinement.Adequate
import Benitoite.Release.Refinement.ClosedEvaluation

/-!
# 外部から受信した値の全入れ子の篩の検査

carrierは篩の述語を信用しない。dataの欄は元の宣言を具体化して辿る。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

def Outcome.Typed (P : Program) (B : Builtins) (Ψ : StoreTy) (out : Outcome) (a : Ty) : Prop :=
  match out with
  | .val v => HasTypeV P B Ψ [] [] [] v a ∧ v.Ground
  | .err _ | .exit _ => True


/-- some trueだけを成功とし、失敗と偽をともに拒否する。 -/
def Pred.closedTrue (p : Pred) : Bool := p.evalClosed == some true

theorem Pred.closedTrue_entails {p : Pred} (h : p.closedTrue = true) :
    p.WF 0 ∧ p.Sorted [] none ∧ Entails [] p := by
  have he : p.evalClosed = some true := by simpa [Pred.closedTrue] using h
  unfold Pred.evalClosed at he
  split at he
  · rename_i hw
    exact ⟨hw.1, hw.2, .ground hw.1 hw.2 (by simpa [Pred.evalClosed, hw] using he)⟩
  · cases he

mutual
  def externalCheck (P : Program) (v : Val) : Ty → Bool
    | .refined a p => externalCheck P v a &&
        (match a.sort? with
        | none => p.closedTrue
        | some _ => match v.toTerm? with
          | none => false
          | some t => (p.open t).closedTrue)
    | .base b => match v with
      | .const c => match c.type with | .base k => decide (k = b) | _ => false
      | _ => false
    | .bytes => match v with
      | .bytesV bs => bs.all (· ≤ 255) | _ => false
    | .external id _ => match v with
      | .externalHandle h _ => h.typeId == id | _ => false
    | .list a => match v with
      | .list vs => externalCheckEach P vs a | _ => false
    | .map a b => match v with
      | .mapV ks vs => decide (ks.length = vs.length) && externalCheckEach P ks a && externalCheckEach P vs b
      | _ => false
    | .set a => match v with
      | .setV vs => externalCheckEach P vs a | _ => false
    | .data d ts => match v with
      | .con c _ vs => match P.cons c with
        | none => false
        | some cd => decide (cd.data = d ∧ cd.ntys = ts.length) &&
            externalCheckFields P vs (cd.args.map (Ty.subst ts []))
      | _ => false
    | _ => false
  termination_by a => (sizeOf v, sizeOf a)
  def externalCheckEach (P : Program) (vs : List Val) (a : Ty) : Bool := match vs with
    | [] => true
    | v::vs => externalCheck P v a && externalCheckEach P vs a
  termination_by (sizeOf vs, sizeOf a)
  def externalCheckFields (P : Program) (vs : List Val) (as : List Ty) : Bool := match vs,as with
    | [],[] => true
    | v::vs,a::as => externalCheck P v a && externalCheckFields P vs as
    | _,_ => false
  termination_by (sizeOf vs, sizeOf as)
end

mutual
  /-- 元の注釈・制約は保持するが、篩の真は含まない外部の値構造。 -/
  inductive ExternalCarrier (P : Program) (B : Builtins) (Ψ : StoreTy) : Val → Ty → Prop where
    | scalar {v b} : HasTypeV P B Ψ [] [] [] v (.base b) → ExternalCarrier P B Ψ v (.base b)
    | bytes {v} : HasTypeV P B Ψ [] [] [] v .bytes → ExternalCarrier P B Ψ v .bytes
    | handle {v id ts} : HasTypeV P B Ψ [] [] [] v (.external id ts) →
        ExternalCarrier P B Ψ v (.external id ts)
    | list {vs a} : ExternalCarrierEach P B Ψ vs a → Ty.Annotation P [] [] a →
        ExternalCarrier P B Ψ (.list vs) (.list a)
    | map {ks vs a b} : ExternalCarrierEach P B Ψ ks a → ExternalCarrierEach P B Ψ vs b →
        ks.length = vs.length → B.sat [] a.norm TParam.keyC →
        Ty.Annotation P [] [] a → Ty.Annotation P [] [] b → ExternalCarrier P B Ψ (.mapV ks vs) (.map a b)
    | set {vs a} : ExternalCarrierEach P B Ψ vs a → B.sat [] a.norm TParam.keyC →
        Ty.Annotation P [] [] a → ExternalCarrier P B Ψ (.setV vs) (.set a)
    | data {c cd ts vs} : P.cons c = some cd → ts.length = cd.ntys →
        TypeArgsKinded P [] ts (List.replicate cd.ntys .value) →
        (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        ExternalCarrierFields P B Ψ vs (cd.args.map (Ty.subst ts [])) →
        Ty.Annotation P [] [] (.data cd.data ts) → ExternalCarrier P B Ψ (.con c ts vs) (.data cd.data ts)
    | refined {v a p} : ExternalCarrier P B Ψ v a → Ty.Annotation P [] [] (.refined a p) →
        ExternalCarrier P B Ψ v (.refined a p)
  inductive ExternalCarrierEach (P : Program) (B : Builtins) (Ψ : StoreTy) : List Val → Ty → Prop where
    | nil {a} : ExternalCarrierEach P B Ψ [] a
    | cons {v vs a} : ExternalCarrier P B Ψ v a → ExternalCarrierEach P B Ψ vs a →
        ExternalCarrierEach P B Ψ (v::vs) a
  inductive ExternalCarrierFields (P : Program) (B : Builtins) (Ψ : StoreTy) : List Val → List Ty → Prop where
    | nil : ExternalCarrierFields P B Ψ [] []
    | cons {v vs a as} : ExternalCarrier P B Ψ v a → ExternalCarrierFields P B Ψ vs as →
        ExternalCarrierFields P B Ψ (v::vs) (a::as)
end

/-- selfの像が得られ、実際に閉じた篩の評価が成功する条件。 -/
def RefinementSucceeded (v : Val) (a : Ty) (p : Pred) : Prop := match a.sort? with
  | none => p.evalClosed = some true
  | some _ => ∃ t, v.toTerm? = some t ∧ (p.open t).evalClosed = some true

mutual
  /-- 値構造の各篩について、閉じた評価の成功だけを要求する。 -/
  inductive ExternalPredicates (P : Program) : Val → Ty → Prop where
    | scalar {v b} : ExternalPredicates P v (.base b)
    | bytes {v} : ExternalPredicates P v .bytes
    | handle {v id ts} : ExternalPredicates P v (.external id ts)
    | list {vs a} : ExternalPredicatesEach P vs a → ExternalPredicates P (.list vs) (.list a)
    | map {ks vs a b} : ExternalPredicatesEach P ks a → ExternalPredicatesEach P vs b →
        ExternalPredicates P (.mapV ks vs) (.map a b)
    | set {vs a} : ExternalPredicatesEach P vs a → ExternalPredicates P (.setV vs) (.set a)
    | data {c cd ts vs d} : P.cons c = some cd → cd.data = d →
        ExternalPredicatesFields P vs (cd.args.map (Ty.subst ts [])) →
        ExternalPredicates P (.con c ts vs) (.data d ts)
    | refined {v a p} : ExternalPredicates P v a → RefinementSucceeded v a p →
        ExternalPredicates P v (.refined a p)
  inductive ExternalPredicatesEach (P : Program) : List Val → Ty → Prop where
    | nil {a} : ExternalPredicatesEach P [] a
    | cons {v vs a} : ExternalPredicates P v a → ExternalPredicatesEach P vs a →
        ExternalPredicatesEach P (v::vs) a
  inductive ExternalPredicatesFields (P : Program) : List Val → List Ty → Prop where
    | nil : ExternalPredicatesFields P [] []
    | cons {v vs a as} : ExternalPredicates P v a → ExternalPredicatesFields P vs as →
        ExternalPredicatesFields P (v::vs) (a::as)
end

private def ExternalLeafShape (v : Val) : Ty → Prop
  | .base b => ∃ c, v = .const c ∧ c.type = .base b
  | .bytes => ∃ bs, v = .bytesV bs ∧ ∀ b ∈ bs, b ≤ 255
  | .external id _ => ∃ h ts, v = .externalHandle h ts ∧ h.typeId = id
  | .refined a _ => ExternalLeafShape v a
  | _ => True

private theorem leafShape_core (v : Val) (a : Ty) :
    ExternalLeafShape v a.core ↔ ExternalLeafShape v a := by
  cases a with
  | refined a p => exact leafShape_core v a
  | _ => rfl

private theorem leafShape_refineNorm (v : Val) (a : Ty) (p : Pred) :
    ExternalLeafShape v (a.refineNorm p) ↔ ExternalLeafShape v a := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> simp only [ExternalLeafShape, leafShape_core]

private theorem leafShape_norm (v : Val) (a : Ty) :
    ExternalLeafShape v a.norm ↔ ExternalLeafShape v a := by
  cases a <;> try rfl
  case refined a p => simp only [Ty.norm, leafShape_refineNorm, ExternalLeafShape, leafShape_norm]
  case dependentFn t => unfold Ty.norm Ty.foldFn; split <;> rfl

private theorem leafShape_le {Γ Φ a b v} (h : Ty.LeQ P Γ Φ a b) :
    ExternalLeafShape v a → ExternalLeafShape v b := by
  match h with
  | .refl => exact id
  | .convert he => intro hs; exact (leafShape_norm v b).mp (he ▸ (leafShape_norm v a).mpr hs)
  | .trans h₁ h₂ => exact fun hs => leafShape_le h₂ (leafShape_le h₁ hs)
  | .forget | .introduce _ _ => exact id
  | @Ty.LeQ.refine _ Γ Φ a b p q h _ _ _ => exact leafShape_le (a := a) (b := b) h
  | .data .. | .fn_effect .. | .list .. | .lazy .. | .map_value .. | .dependentFn .. | .scoped .. | .scoped_forget .. =>
    exact fun _ => trivial

private theorem leafShape_typed {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) : Γ = [] → ExternalLeafShape v a := by
  match h with
  | .V_Var hi _ => intro he; subst Γ; cases hi
  | @HasTypeVQ.V_Const _ _ Ψ Q C Γ Φ c hc =>
    intro _
    cases c <;> first | exact ⟨_,rfl,rfl⟩ | trivial
  | .V_ExternalHandle h td _ _ _ _ _ => intro _; exact ⟨h,_,rfl,rfl⟩
  | .V_Bytes hb => intro _; exact ⟨_,rfl,hb⟩
  | .V_Normal hv => intro he; exact (leafShape_norm _ _).mpr (leafShape_typed hv he)
  | .V_Sub hv hl _ _ _ => intro he; exact leafShape_le hl (leafShape_typed hv he)
  | @HasTypeVQ.V_Refine _ _ Ψ Q C Γ Φ v a t p sort hv _ _ _ _ _ _ _ =>
    intro he; exact leafShape_typed (a := a) hv he
  | .V_AtError hd => intro _; rw [hd.errorType_eq]; trivial
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Con .. | .V_Super .. | .V_List .. => intro _; trivial

mutual
  /-- carrierと各篩の評価成功から、受信後の検査の成功を導く。 -/
  theorem ExternalCarrier.accepted {P B Ψ v a} (h : ExternalCarrier P B Ψ v a)
      (hp : ExternalPredicates P v a) : externalCheck P v a = true := by
    cases h with
    | scalar hv =>
      obtain ⟨c,rfl,ht⟩ := leafShape_typed hv rfl
      simp [externalCheck,ht]
    | bytes hv =>
      obtain ⟨bs,rfl,hb⟩ := leafShape_typed hv rfl
      simpa [externalCheck, List.all_eq_true] using hb
    | handle hv =>
      obtain ⟨handle,ts,rfl,ht⟩ := leafShape_typed hv rfl
      simp [externalCheck,ht]
    | list h ha =>
      cases hp with | list hp => simpa only [externalCheck] using ExternalCarrierEach.accepted h hp
    | map hk hv hn hb ha ha' =>
      cases hp with | map hpk hpv =>
        simp only [externalCheck,hn,decide_true,Bool.true_and,Bool.and_eq_true]
        exact ⟨ExternalCarrierEach.accepted hk hpk, ExternalCarrierEach.accepted hv hpv⟩
    | set h hb ha =>
      cases hp with | set hp => simpa only [externalCheck] using ExternalCarrierEach.accepted h hp
    | data hd hn hk hw h ha =>
      cases hp with | data hd' _ hp =>
        have he := Option.some.inj (hd.symm.trans hd')
        cases he
        simpa [externalCheck,hd,hn] using ExternalCarrierFields.accepted h hp
    | @refined v a p h ha =>
      cases hp with | refined hp hsuc =>
        have ih := ExternalCarrier.accepted h hp
        simp only [externalCheck,ih,Bool.true_and]
        unfold RefinementSucceeded at hsuc
        cases hs : a.sort? with
        | none => simpa [hs,Pred.closedTrue] using hsuc
        | some s =>
          rw [hs] at hsuc
          obtain ⟨t,ht,he⟩ := hsuc
          simp [ht,Pred.closedTrue,he]
  theorem ExternalCarrierEach.accepted {P B Ψ vs a} (h : ExternalCarrierEach P B Ψ vs a)
      (hp : ExternalPredicatesEach P vs a) : externalCheckEach P vs a = true := by
    cases h with
    | nil => simp [externalCheckEach]
    | cons hv hs =>
      cases hp with | cons hpv hps =>
        simp only [externalCheckEach, Bool.and_eq_true]
        exact ⟨ExternalCarrier.accepted hv hpv,ExternalCarrierEach.accepted hs hps⟩
  theorem ExternalCarrierFields.accepted {P B Ψ vs as} (h : ExternalCarrierFields P B Ψ vs as)
      (hp : ExternalPredicatesFields P vs as) : externalCheckFields P vs as = true := by
    cases h with
    | nil => simp [externalCheckFields]
    | cons hv hs =>
      cases hp with | cons hpv hps =>
        simp only [externalCheckFields,Bool.and_eq_true]
        exact ⟨ExternalCarrier.accepted hv hpv,ExternalCarrierFields.accepted hs hps⟩
end

private theorem refine_checked {P B Ψ v a p}
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : Ty.Annotation P [] [] (.refined a p))
    (hc : (match a.sort? with
      | none => p.closedTrue
      | some _ => match v.toTerm? with | none => false | some t => (p.open t).closedTrue) = true) :
    HasTypeV P B Ψ [] [] [] v (.refined a p) := by
  rcases ha with ⟨hw,hs,hd⟩
  cases hsort : a.sort? with
  | none =>
    simp only [hsort] at hc
    obtain ⟨_,_,he⟩ := Pred.closedTrue_entails hc
    exact .V_Sub hv (.introduce hs.2 (he.weaken (by simp))) hw hs hd
  | some s =>
    simp only [hsort] at hc
    cases ht : v.toTerm? with
    | none => simp [ht] at hc
    | some t =>
      simp only [ht] at hc
      obtain ⟨_,_,he⟩ := Pred.closedTrue_entails hc
      exact .V_Refine hv hsort ht hs.2 hw.2.1 he hd.1 hd.2

mutual
  theorem ExternalCarrier.checked_typed {P B Ψ v a} (h : ExternalCarrier P B Ψ v a)
      (hc : externalCheck P v a = true) : HasTypeV P B Ψ [] [] [] v a := by
    cases h with
    | scalar hv | bytes hv | handle hv => exact hv
    | list he ha =>
      simp only [externalCheck] at hc
      exact .V_List (ExternalCarrierEach.checked_typed he hc) ha.wf ha.sorted ha.declared
    | map hk hv hn hb ha ha' =>
      simp only [externalCheck, Bool.and_eq_true] at hc
      exact .V_Map (ExternalCarrierEach.checked_typed hk hc.1.2)
        (ExternalCarrierEach.checked_typed hv hc.2) hn hb ha ha'
    | set hv hb ha =>
      simp only [externalCheck] at hc
      exact .V_Set (ExternalCarrierEach.checked_typed hv hc) hb ha
    | data hd hn hk hw he ha =>
      simp only [externalCheck, hd, Bool.and_eq_true] at hc
      exact .V_Con hd hn hk hw (ExternalCarrierFields.checked_typed he hc.2) ha
    | refined he ha =>
      simp only [externalCheck, Bool.and_eq_true] at hc
      exact refine_checked (ExternalCarrier.checked_typed he hc.1) ha hc.2
  theorem ExternalCarrierEach.checked_typed {P B Ψ vs a} (h : ExternalCarrierEach P B Ψ vs a)
      (hc : externalCheckEach P vs a = true) : HasTypeEachQ P B Ψ Qempty [] [] [] vs a := by
    cases h with
    | nil => exact .nil
    | cons hv hs =>
      simp only [externalCheckEach, Bool.and_eq_true] at hc
      exact .cons (ExternalCarrier.checked_typed hv hc.1) (ExternalCarrierEach.checked_typed hs hc.2)
  theorem ExternalCarrierFields.checked_typed {P B Ψ vs as} (h : ExternalCarrierFields P B Ψ vs as)
      (hc : externalCheckFields P vs as = true) : HasTypeVsQ P B Ψ Qempty [] [] [] vs as := by
    cases h with
    | nil => exact .nil
    | cons hv hs =>
      simp only [externalCheckFields, Bool.and_eq_true] at hc
      exact .cons (ExternalCarrier.checked_typed hv hc.1) (ExternalCarrierFields.checked_typed hs hc.2)
end

mutual
  /-- 外部の値構造には、実行に由来するScopeの保持値が入らない。 -/
  theorem ExternalCarrier.adequate {P B Ψ v a} (h : ExternalCarrier P B Ψ v a)
      (σ : PathEnv) : v.Adequate σ := by
    match h with
    | .scalar hv => obtain ⟨c,rfl,_⟩ := leafShape_typed hv rfl; trivial
    | .bytes hv => obtain ⟨bs,rfl,_⟩ := leafShape_typed hv rfl; trivial
    | .handle hv => obtain ⟨h,ts,rfl,_⟩ := leafShape_typed hv rfl; trivial
    | .list hv _ | .set hv _ _ => exact ExternalCarrierEach.adequate hv σ
    | .map hk hv _ _ _ _ => exact ⟨ExternalCarrierEach.adequate hk σ, ExternalCarrierEach.adequate hv σ⟩
    | .data _ _ _ _ hv _ => exact ExternalCarrierFields.adequate hv σ
    | .refined hv _ => exact ExternalCarrier.adequate hv σ
  theorem ExternalCarrierEach.adequate {P B Ψ vs a} (h : ExternalCarrierEach P B Ψ vs a)
      (σ : PathEnv) : adequateVals σ vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨ExternalCarrier.adequate hv σ,ExternalCarrierEach.adequate hs σ⟩
  theorem ExternalCarrierFields.adequate {P B Ψ vs as} (h : ExternalCarrierFields P B Ψ vs as)
      (σ : PathEnv) : adequateVals σ vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨ExternalCarrier.adequate hv σ,ExternalCarrierFields.adequate hs σ⟩
end

theorem externalCheckEach_eq_true_iff (P : Program) (vs : List Val) (a : Ty) :
    externalCheckEach P vs a = true ↔ ∀ v ∈ vs, externalCheck P v a = true := by
  induction vs with
  | nil => simp [externalCheckEach]
  | cons v vs ih => simp [externalCheckEach, ih]

/-- 外部の三条件の改訂で使う、篩を信頼しない応答の所属。 -/
def Outcome.Carrier (P : Program) (B : Builtins) (Ψ : StoreTy) (out : Outcome) (a : Ty) : Prop :=
  match out with
  | .val v => ExternalCarrier P B Ψ v a ∧ v.Ground
  | .err _ | .exit _ => True

def externalCheckedOutcome (P : Program) (a : Ty) : Outcome → Outcome
  | .val v => if externalCheck P v a then .val v else .err "ExternalRefinement"
  | .err e => .err e
  | .exit n => .exit n

theorem externalCheckedOutcome_typed {P B Ψ a out}
    (h : Outcome.Carrier P B Ψ out a) : Outcome.Typed P B Ψ (externalCheckedOutcome P a out) a := by
  cases out with
  | val v =>
    by_cases hc : externalCheck P v a = true
    · simp only [externalCheckedOutcome, hc, ↓reduceIte, Outcome.Typed]
      exact ⟨ExternalCarrier.checked_typed h.1 hc, h.2⟩
    · simp [externalCheckedOutcome, hc, Outcome.Typed]
  | err _ | exit _ => trivial

theorem externalCheckedOutcome_reject {P a v} (h : externalCheck P v a = false) :
    externalCheckedOutcome P a (.val v) = .err "ExternalRefinement" := by
  simp [externalCheckedOutcome, h]

end
end Benitoite.Release.Refinement
