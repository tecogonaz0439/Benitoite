import Benitoite.Release.Refinement.Surface.CheckFormationData

/-! 型注釈・kind・具体化した依存列の形成の検査。 -/
namespace Benitoite.Release.Refinement.Surface.CheckFormation

theorem CtxSupport.extend {s Γ a} (hΓ : CtxSupport s Γ) (ha : a.Support (· ∈ s)) :
    CtxSupport s (Γ.extend a) := by
  intro i b hi
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    exact (Ty.support_shiftV_iff _ _ _ _).mpr ha
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some x => cases x with
      | none => simp [hg] at hi
      | some c =>
        simp only [hg, Option.map_some, Option.some.injEq] at hi
        cases hi
        exact (Ty.support_shiftV_iff _ _ _ _).mpr (hΓ i c hg)

theorem CtxSupport.declarationSelf {s Γ self} (hΓ : CtxSupport s Γ)
    (ha : ∀ a, self = some a → a.Support (· ∈ s)) : CtxSupport s (Γ.declarationSelf self) := by
  cases self with
  | none => exact hΓ
  | some a => exact hΓ.extend (ha a rfl)

def fieldCheck (q : Input) (P : Refinement.Program) (Γ : Ctx) (path : List Nat) (t : Term) (ref : FieldRef) : Bool :=
  match dataCheck q P Γ t (q.hints path), P.cons ref.constructor with
  | some (d, ts), some cd => match cd.args[ref.position]? with
    | some a => decide (d = ref.owner ∧ cd.data = ref.owner ∧ cd.ntys = ts.length) &&
        (wfTy q 0 cd.ntys 0 a && decide ((substTy q ts [] a).HasSort ref.result))
    | none => false
  | _, _ => false

theorem fieldCheck_sound {q P C Γ path t ref} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (h : fieldCheck q P Γ path t ref = true) : ref.Declared P C Γ t := by
  unfold fieldCheck at h
  split at h
  · rename_i d ts cd ht hc
    split at h
    · rename_i a ha
      simp only [Bool.and_eq_true, decide_eq_true_eq] at h
      obtain ⟨hd, hts⟩ := dataCheck_sound hq hΓ (hq.hints path) ht
      have hs := Ty.SupportList.iff.mp (hq.fields _ _ hc) a (List.mem_of_getElem? ha)
      refine ⟨ts, cd, a, h.1.1 ▸ hd, hc, h.1.2.1, h.1.2.2, ha, wfTy_sound hs h.2.1, ?_⟩
      simpa only [substTy_eq (q := q) (es := []) hs hts (by simp)] using h.2.2
    · cases h
  · cases h

mutual
  def declaredTerm (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Term → Bool
    | .var i => decide (Γ.Readable i)
    | .field ref t => declaredTerm q P C Γ (path ++ [0]) t && fieldCheck q P Γ (path ++ [1]) t ref
    | .measure _ t | .neg t | .scale _ t => declaredTerm q P C Γ (path ++ [0]) t
    | .add a b => declaredTerm q P C Γ (path ++ [0]) a && declaredTerm q P C Γ (path ++ [1]) b
    | .listValue xs | .setValue xs => declaredSlots q P C Γ path xs
    | .mapValue ks vs => declaredSlots q P C Γ (path ++ [0]) ks && declaredSlots q P C Γ (path ++ [1]) vs
    | .dataValue c xs => declaredSlots q P C Γ (path ++ [0]) xs &&
        (match P.cons c with | some cd => decide (xs.length = cd.args.length) | none => false)
    | _ => true
  def declaredSlot (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Option Term → Bool
    | none => true
    | some t => declaredTerm q P C Γ path t
  def declaredSlots (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : List (Option Term) → Bool
    | [] => true
    | x :: xs => declaredSlot q P C Γ (path ++ [0]) x && declaredSlots q P C Γ (path ++ [1]) xs
end

mutual
  theorem declaredTerm_sound {q P C Γ path t} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
      (h : declaredTerm q P C Γ path t = true) : t.Declared P C Γ := by
    cases t <;> simp only [declaredTerm, Bool.and_eq_true, decide_eq_true_eq] at h
    case var => exact h
    case field ref t => exact ⟨declaredTerm_sound hq hΓ h.1, fieldCheck_sound hq hΓ h.2⟩
    case measure m t => exact declaredTerm_sound (t := t) hq hΓ h
    case neg t => exact declaredTerm_sound (t := t) hq hΓ h
    case scale n t => exact declaredTerm_sound (t := t) hq hΓ h
    case add a b => exact ⟨declaredTerm_sound hq hΓ h.1, declaredTerm_sound hq hΓ h.2⟩
    case listValue | setValue => exact declaredSlots_sound hq hΓ h
    case mapValue ks vs => exact ⟨declaredSlots_sound hq hΓ h.1, declaredSlots_sound hq hΓ h.2⟩
    case dataValue c xs =>
      refine ⟨declaredSlots_sound hq hΓ h.1, ?_⟩
      cases hc : P.cons c with
      | none => simp [hc] at h
      | some cd => exact ⟨cd, rfl, by simpa only [hc, decide_eq_true_eq] using h.2⟩
    all_goals trivial
  theorem declaredSlot_sound {q P C Γ path t} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
      (h : declaredSlot q P C Γ path t = true) : Refinement.declaredSlot P C Γ t := by
    cases t with
    | none => trivial
    | some t => exact declaredTerm_sound hq hΓ h
  theorem declaredSlots_sound {q P C Γ path ts} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
      (h : declaredSlots q P C Γ path ts = true) : Refinement.declaredSlots P C Γ ts := by
    cases ts with
    | nil => trivial
    | cons t ts =>
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨declaredSlot_sound hq hΓ hh.1, declaredSlots_sound hq hΓ hh.2⟩
end

def constructorCheck (q : Input) (P : Refinement.Program) (Γ : Ctx) (path : List Nat) (t : Term) (c : ConName) : Bool :=
  match dataCheck q P Γ t (q.hints path), P.cons c with
  | some (d, _), some cd => decide (cd.data = d)
  | _, _ => false

theorem constructorCheck_sound {q P Γ path t c} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (h : constructorCheck q P Γ path t c = true) :
    ∃ d ts cd, Term.HasData P Γ t d ts ∧ P.cons c = some cd ∧ cd.data = d := by
  unfold constructorCheck at h
  split at h
  · rename_i d ts cd ht hc
    exact ⟨d, ts, cd, (dataCheck_sound hq hΓ (hq.hints path) ht).1, hc, of_decide_eq_true h⟩
  · cases h

def declaredPred (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (self : Option Ty)
    (path : List Nat) : Pred → Bool
  | .truth | .falsity => true
  | .eq a b | .le a b | .lt a b | .compare _ _ a b =>
      declaredTerm q P C (Γ.declarationSelf self) (path ++ [0]) a &&
        declaredTerm q P C (Γ.declarationSelf self) (path ++ [1]) b
  | .floatClass _ _ a | .decimalRepresented a | .charactersIn a _ _ | .member _ a _ =>
      declaredTerm q P C (Γ.declarationSelf self) (path ++ [0]) a
  | .constructorIs a c => declaredTerm q P C (Γ.declarationSelf self) (path ++ [0]) a &&
      constructorCheck q P (Γ.declarationSelf self) (path ++ [1]) a c
  | .and p r | .or p r => declaredPred q P C Γ self (path ++ [0]) p && declaredPred q P C Γ self (path ++ [1]) r
  | .not p => declaredPred q P C Γ self (path ++ [0]) p

theorem declaredPred_sound {q P C Γ self path p} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (hself : ∀ a, self = some a → a.Support (· ∈ q.atoms))
    (h : declaredPred q P C Γ self path p = true) : p.Declared P C Γ self := by
  have hs := hΓ.declarationSelf hself
  cases p <;> simp only [declaredPred, Bool.and_eq_true] at h
  case truth | falsity => trivial
  case eq | le | lt | compare => exact ⟨declaredTerm_sound hq hs h.1, declaredTerm_sound hq hs h.2⟩
  case floatClass | decimalRepresented | charactersIn | member => exact declaredTerm_sound hq hs h
  case constructorIs a c => exact ⟨declaredTerm_sound hq hs h.1, constructorCheck_sound hq hs h.2⟩
  case and | or => exact ⟨declaredPred_sound hq hΓ hself h.1, declaredPred_sound hq hΓ hself h.2⟩
  case not p => exact declaredPred_sound (p := p) hq hΓ hself h

mutual
  def declaredTy (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Ty → Bool
    | .base _ | .bytes | .opaque _ _ | .scoped _ _ _ | .pathBases | .scopePattern _ | .tvar _ => true
    | .data d as => decide (dataArity q P d = some as.length) && declaredTys q P C Γ path as
    | .external id as =>
        (match P.externalType id with
        | some td => decide (td.id = id ∧ as.length = td.arity)
        | none => false) && declaredTys q P C Γ path as
    | .tapp i as => decide ((TypeCtx.kinds C)[i]? = some (.constructor as.length)) && declaredTys q P C Γ path as
    | .ctor (.data d) => (dataArity q P d).isSome
    | .ctor _ => true
    | .list a | .reference a | .lazy a | .set a | .dict _ a => declaredTy q P C Γ path a
    | .fn _ ps r e => declaredTys q P C Γ (path ++ [0]) ps &&
        (declaredTy q P C Γ (path ++ [1]) r && declaredEff q P C Γ (path ++ [2]) e)
    | .dependentFn t => declaredTel q P C Γ path t
    | .cont b t e => declaredTy q P C Γ (path ++ [0]) b &&
        (declaredTy q P C Γ (path ++ [1]) t && declaredEff q P C Γ (path ++ [2]) e)
    | .map a b => declaredTy q P C Γ (path ++ [0]) a && declaredTy q P C Γ (path ++ [1]) b
    | .refined a p => declaredTy q P C Γ (path ++ [0]) a && declaredPred q P C Γ (some a) (path ++ [1]) p
  def declaredTel (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Tel → Bool
    | .done r e => declaredTy q P C Γ (path ++ [0]) r && declaredEff q P C Γ (path ++ [1]) e
    | .param _ a t => declaredTy q P C Γ (path ++ [0]) a && declaredTel q P C (Γ.extend a) (path ++ [1]) t
  def declaredTys (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : List Ty → Bool
    | [] => true
    | a :: as => declaredTy q P C Γ (path ++ [0]) a && declaredTys q P C Γ (path ++ [1]) as
  def declaredEff (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Eff → Bool
    | .mk _ fs => declaredTys q P C Γ path fs
end

mutual
  theorem declaredTy_sound {q P C Γ path a} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
      (ha : a.Support (· ∈ q.atoms)) (h : declaredTy q P C Γ path a = true) : a.Declared P C Γ := by
    cases a <;> simp only [declaredTy, Bool.and_eq_true, decide_eq_true_eq, Ty.Support] at h ha
    case base | bytes | «opaque» | «scoped» | pathBases | scopePattern | tvar => trivial
    case data d as => exact ⟨⟨as.length, dataArity_sound hq.ctors h.1, rfl⟩, declaredTys_sound hq hΓ ha h.2⟩
    case external id as =>
      refine ⟨?_, declaredTys_sound hq hΓ ha h.2⟩
      cases ht : P.externalType id with
      | none => simp [ht] at h
      | some td => exact ⟨td, rfl, by simpa only [ht, decide_eq_true_eq] using h.1⟩
    case tapp i as => exact ⟨h.1, declaredTys_sound hq hΓ ha h.2⟩
    case ctor c =>
      cases c <;> try trivial
      rename_i d
      change (dataArity q P d).isSome = true at h
      cases he : dataArity q P d with
      | none => simp [he] at h
      | some n => exact ⟨n, dataArity_sound hq.ctors he⟩
    case list a | reference a | lazy a | set a => exact declaredTy_sound (a := a) hq hΓ ha h
    case dict cl a => exact declaredTy_sound (a := a) hq hΓ ha h
    case fn ns ps r e => exact ⟨declaredTys_sound hq hΓ ha.1 h.1,
      declaredTy_sound hq hΓ ha.2.1 h.2.1, declaredEff_sound hq hΓ ha.2.2 h.2.2⟩
    case dependentFn => exact declaredTel_sound hq hΓ ha h
    case cont b t e => exact ⟨declaredTy_sound hq hΓ ha.1 h.1,
      declaredTy_sound hq hΓ ha.2.1 h.2.1, declaredEff_sound hq hΓ ha.2.2 h.2.2⟩
    case map a b => exact ⟨declaredTy_sound hq hΓ ha.1 h.1, declaredTy_sound hq hΓ ha.2 h.2⟩
    case refined a p => exact ⟨declaredTy_sound hq hΓ ha h.1,
      declaredPred_sound hq hΓ (by intro b hb; cases hb; exact ha) h.2⟩
  theorem declaredTel_sound {q P C Γ path t} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
      (ht : t.Support (· ∈ q.atoms)) (h : declaredTel q P C Γ path t = true) : t.Declared P C Γ := by
    cases t with
    | done r e =>
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨declaredTy_sound hq hΓ ht.1 hh.1, declaredEff_sound hq hΓ ht.2 hh.2⟩
    | param n a t =>
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨declaredTy_sound hq hΓ ht.1 hh.1, declaredTel_sound hq (hΓ.extend ht.1) ht.2 hh.2⟩
  theorem declaredTys_sound {q P C Γ path as} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
      (ht : Ty.SupportList (· ∈ q.atoms) as) (h : declaredTys q P C Γ path as = true) :
      Refinement.declaredTys P C Γ as := by
    cases as with
    | nil => trivial
    | cons a as =>
      have hh := Bool.and_eq_true_iff.mp h
      exact ⟨declaredTy_sound hq hΓ ht.1 hh.1, declaredTys_sound hq hΓ ht.2 hh.2⟩
  theorem declaredEff_sound {q P C Γ path e} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
      (he : e.Support (· ∈ q.atoms)) (h : declaredEff q P C Γ path e = true) :
      Refinement.declaredEff P C Γ e := by
    cases e with
    | mk a fs => exact declaredTys_sound hq hΓ he.2 h
end

/-- 整形式・sort・宣言済みの三条件を、同じ型について検査する。 -/
def annotation (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) (a : Ty) : Bool :=
  wfTy q 0 C.length Γ.length a && (sortedTy Γ a && declaredTy q P C Γ path a)

theorem annotation_sound {q P C Γ path a} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (ha : a.Support (· ∈ q.atoms)) (h : annotation q P C Γ path a = true) : Ty.Annotation P C Γ a := by
  simp only [annotation, Bool.and_eq_true] at h
  exact ⟨wfTy_sound ha h.1, sortedTy_sound h.2.1, declaredTy_sound hq hΓ ha h.2.2⟩

def annotations (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : List Ty → Bool
  | [] => true
  | a :: as => annotation q P C Γ (path ++ [0]) a && annotations q P C Γ (path ++ [1]) as

theorem annotations_sound {q P C Γ path as} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (ha : Ty.SupportList (· ∈ q.atoms) as) (h : annotations q P C Γ path as = true) : TypeAnnotations P C Γ as := by
  cases as with
  | nil => intro a h; cases h
  | cons a as =>
    have hh := Bool.and_eq_true_iff.mp h
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact annotation_sound hq hΓ ha.1 hh.1
    · exact annotations_sound hq hΓ ha.2 hh.2 b hb

def argsKinded (q : Input) (P : Refinement.Program) (C : TypeCtx) : List Ty → List TyKind → Bool
  | [], [] => true
  | a :: as, k :: ks => kindTy q P (TypeCtx.kinds C) a k &&
      (decide (Ordinary a) && argsKinded q P C as ks)
  | _, _ => false

theorem argsKinded_sound {q P C as ks} (hq : CtorsComplete P q.ctors) (h : argsKinded q P C as ks = true) :
    TypeArgsKinded P C as ks := by
  induction as generalizing ks with
  | nil => cases ks <;> simp_all [argsKinded, TypeArgsKinded]
  | cons a as ih =>
    cases ks with
    | nil => cases h
    | cons k ks =>
      simp only [argsKinded, Bool.and_eq_true, decide_eq_true_eq] at h
      obtain ⟨hlen, hrest⟩ := ih h.2.2
      refine ⟨by simp [hlen], ?_⟩
      intro i t l ht hl
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at ht hl
        subst t; subst l
        exact ⟨kindTy_sound hq h.1, fun _ => h.2.1⟩
      | succ i => exact hrest i t l ht hl

def rowAnnotations (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat) (es : List Eff) : Bool :=
  annotations q P C Γ path (es.map (fun e => Ty.fn [] [] (.base .unit) e))

theorem rowAnnotations_sound {q P C Γ path es} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (he : ∀ e ∈ es, e.Support (· ∈ q.atoms)) (h : rowAnnotations q P C Γ path es = true) :
    RowAnnotations P C Γ es := by
  have hs : Ty.SupportList (· ∈ q.atoms) (es.map (fun e => Ty.fn [] [] (.base .unit) e)) := by
    apply Ty.SupportList.iff.mpr
    intro a ha
    obtain ⟨e, he', rfl⟩ := List.mem_map.mp ha
    exact ⟨trivial, trivial, he e he'⟩
  have hh := annotations_sound hq hΓ hs h
  intro e hm
  exact hh _ (List.mem_map.mpr ⟨e, hm, rfl⟩)

def instTel (q : Input) (t : Tel) (ts : List Ty) (es : List Eff) : Tel :=
  Tel.normWith q.atoms (Tel.rawBind (typeEnvAt 0 ts es) t)

theorem instTel_eq {q t ts es} (ht : t.Support (· ∈ q.atoms)) (hs : Ty.SupportList (· ∈ q.atoms) ts)
    (he : ∀ e ∈ es, e.Support (· ∈ q.atoms)) : instTel q t ts es = instantiatedTel t ts es :=
  Tel.normWith_eq_norm q.atoms _ (Tel.rawBind_support _ _ _ _ ht
    (typeEnvAt_support_of_imp 0 ts es (Ty.SupportList.iff.mp hs) he (fun _ h => h)))

theorem instTel_support {q t ts es} (ht : t.Support (· ∈ q.atoms)) (hs : Ty.SupportList (· ∈ q.atoms) ts)
    (he : ∀ e ∈ es, e.Support (· ∈ q.atoms)) : (instTel q t ts es).Support (· ∈ q.atoms) := by
  rw [instTel_eq ht hs he]
  exact Tel.norm_support _ (Tel.rawBind_support _ _ _ _ ht
    (typeEnvAt_support_of_imp 0 ts es (Ty.SupportList.iff.mp hs) he (fun _ h => h)))

/-- 宣言側の閉性、実引数の形成、具体化した結果の形成を全て検査する。 -/
def signatureInstance (q : Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) (path : List Nat)
    (t : Tel) (ks : List TyKind) (ts : List Ty) (es : List Eff) : Bool :=
  wfTy q 0 ks.length 0 (.dependentFn t) &&
    (annotations q P C Γ (path ++ [0]) ts &&
      (argsKinded q P C ts ks &&
        (rowAnnotations q P C Γ (path ++ [1]) es &&
          (es.all (kindEff q P (TypeCtx.kinds C)) &&
            annotation q P C Γ (path ++ [2]) (.dependentFn (instTel q t ts es))))))

theorem signatureInstance_sound {q P C Γ path t ks ts es} (hq : q.Sound P) (hΓ : CtxSupport q.atoms Γ)
    (ht : t.Support (· ∈ q.atoms)) (hs : Ty.SupportList (· ∈ q.atoms) ts)
    (he : ∀ e ∈ es, e.Support (· ∈ q.atoms))
    (h : signatureInstance q P C Γ path t ks ts es = true) : SignatureInstance P C Γ t ks ts es := by
  simp only [signatureInstance, Bool.and_eq_true] at h
  refine ⟨wfTy_sound ht h.1, annotations_sound hq hΓ hs h.2.1,
    argsKinded_sound hq.ctors h.2.2.1, rowAnnotations_sound hq hΓ he h.2.2.2.1, ?_, ?_⟩
  · intro e hm
    exact kindEff_sound hq.ctors (List.all_eq_true.mp h.2.2.2.2.1 e hm)
  · have ha := annotation_sound (a := .dependentFn (instTel q t ts es)) hq hΓ (instTel_support ht hs he) h.2.2.2.2.2
    simpa only [instTel_eq ht hs he] using ha

end Benitoite.Release.Refinement.Surface.CheckFormation
