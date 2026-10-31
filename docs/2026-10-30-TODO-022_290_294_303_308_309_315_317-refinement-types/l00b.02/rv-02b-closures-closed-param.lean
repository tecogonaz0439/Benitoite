import Benitoite

namespace Benitoite.Release.Refinement.RvClosedParam
noncomputable section

def scalar : Ty := .base .integer8
def unitT : Ty := .base .unit
def seven : Val := .const (.integer8 7)
def R (d : Nat) : Ty := .refined scalar (.eq (.var 0) (.var (d+1)))
def T (d : Nat) : Ty := .fn ["u"] [R d] unitT Eff.empty
def Γ0 : Ctx := [some scalar]
def cap : Capture := .mk [some seven]
def m : Comp := .ret (.lam ["u"] [R 0] (.ret (.const .unit)))
def n : Comp := .app (.lam ["g"] [T 1] (.ret (.const .unit))) [.var 0]

/-! ## 否定の側の逆転 -/

theorem le_fn_forward {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) :
    ∀ ns ps r e, a.core = .fn ns ps r e → ∃ e', b.core = .fn ns ps r e' := by
  match h with
  | .refl => intro ns ps r e he; exact ⟨e,he⟩
  | .trans h1 h2 =>
    intro ns ps r e he
    obtain ⟨e1,he1⟩ := le_fn_forward h1 _ _ _ _ he
    exact le_fn_forward h2 _ _ _ _ he1
  | .fn_effect _ => intro ns ps r e he; simp only [Ty.core,Ty.fn.injEq] at he; obtain ⟨rfl,rfl,rfl,rfl⟩ := he; exact ⟨_,rfl⟩
  | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ | .scoped _ | .scoped_forget => intro ns ps r e he; simp [Ty.core] at he
  | .forget => intro ns ps r e he; exact ⟨e,he⟩
  | .introduce _ _ => intro ns ps r e he; exact ⟨e,he⟩
  | .refine h1 _ _ _ => intro ns ps r e he; exact le_fn_forward h1 _ _ _ _ he

theorem le_fn_backward {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) :
    ∀ ns ps r e, b.core = .fn ns ps r e → ∃ e', a.core = .fn ns ps r e' := by
  match h with
  | .refl => intro ns ps r e he; exact ⟨e,he⟩
  | .trans h1 h2 =>
    intro ns ps r e he
    obtain ⟨e1,he1⟩ := le_fn_backward h2 _ _ _ _ he
    exact le_fn_backward h1 _ _ _ _ he1
  | .fn_effect _ => intro ns ps r e he; simp only [Ty.core,Ty.fn.injEq] at he; obtain ⟨rfl,rfl,rfl,rfl⟩ := he; exact ⟨_,rfl⟩
  | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ | .scoped _ => intro ns ps r e he; simp [Ty.core] at he
  | .scoped_forget => intro ns ps r e he; simp [Ty.core] at he
  | .forget => intro ns ps r e he; exact ⟨e,he⟩
  | .introduce _ _ => intro ns ps r e he; exact ⟨e,he⟩
  | .refine h1 _ _ _ => intro ns ps r e he; exact le_fn_backward h1 _ _ _ _ he

theorem lam_core {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ ns ps b, v = .lam ns ps b → ∃ r e, a.core = .fn ns ps r e := by
  match h with
  | .V_Lam _ _ _ _ _ => intro ns ps b he; cases he; exact ⟨_,_,rfl⟩
  | .V_Sub hv hl _ _ _ =>
    intro ns ps b he
    obtain ⟨r,e,hc⟩ := lam_core hv _ _ _ he
    obtain ⟨e',he'⟩ := le_fn_forward hl _ _ _ _ hc
    exact ⟨r,e',he'⟩
  | .V_Refine hv .. => intro ns ps b he; exact lam_core hv _ _ _ he
  | .V_Var .. | .V_Const .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
    .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
    .V_Super .. | .V_List .. => intro ns ps b he; cases he

theorem var_core {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ i ns ps r e, v = .var i → a.core = .fn ns ps r e →
      ∃ x e', Γ[i]? = some (some x) ∧ x.core = .fn ns ps r e' := by
  match h with
  | .V_Var hi _ => intro i ns ps r e he hc; cases he; exact ⟨_,_,hi,hc⟩
  | .V_Sub hv hl _ _ _ =>
    intro i ns ps r e he hc
    obtain ⟨e',he'⟩ := le_fn_backward hl _ _ _ _ hc
    exact var_core hv _ _ _ _ _ he he'
  | .V_Refine hv .. => intro i ns ps r e he hc; exact var_core hv _ _ _ _ _ he hc
  | .V_Lam .. | .V_Const .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
    .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
    .V_Super .. | .V_List .. => intro i ns ps r e he; cases he

theorem app_inv {P B Ψ Q C Γ Φ R0 c a e L} (h : HasTypeCQ P B Ψ Q C Γ Φ R0 c a e L) :
    ∀ ns x b arg, c = .app (.lam ns [x] b) [arg] → HasTypeVQ P B Ψ Q C Γ Φ arg x := by
  match h with
  | .C_App (ns := ns0) (as := as) hv hs =>
    intro ns x b arg he
    cases he
    obtain ⟨r,e,hc⟩ := lam_core hv _ _ _ rfl
    simp only [Ty.core,Ty.fn.injEq] at hc
    obtain ⟨_,rfl,_,_⟩ := hc
    cases hs with
    | cons hx _ => exact hx
  | .C_DependentApp hv _ =>
    intro ns x b arg he
    cases he
    obtain ⟨r,e,hc⟩ := lam_core hv _ _ _ rfl
    simp [Ty.core] at hc
  | .C_Sub hm .. | .C_Eff hm .. => intro ns x b arg he; exact app_inv hm _ _ _ _ he
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. | .C_Match .. | .C_Lazy .. |
    .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => intro ns x b arg he; cases he

theorem wf_core {nr nt nv : Nat} {a : Ty} {ns ps r e} (h : a.WF nr nt nv) (hc : a.core = .fn ns ps r e) :
    Ty.WFList nr nt nv ps := by
  cases a with
  | fn ns' ps' r' e' =>
    simp only [Ty.core,Ty.fn.injEq] at hc
    obtain ⟨_,rfl,_,_⟩ := hc
    exact h.2.1
  | refined a p => exact wf_core h.1 hc
  | _ => simp [Ty.core] at hc

theorem cont_let {P B σ Ψ R0 ε k a b Eb Re} (h : ContTy P B σ Ψ R0 ε k a b Eb Re) :
    ∀ q k', k = .letF q :: k' → ∃ a1 R1 c e, ClosureTy P B Ψ [a1] R1 q c e := by
  induction h with
  | K_Let hq _ _ _ _ _ => intro q k' he; cases he; exact ⟨_,_,_,_,hq⟩
  | K_Sub _ _ ih => exact ih
  | _ => intro q k' he; cases he

theorem n_not_closed_input {P B Ψ a1 R1 c e} : ¬ ClosureTy P B Ψ [a1] R1 (.mk cap n) c e := by
  intro h
  cases h with
  | mk hc hb hps _ _ _ _ _ =>
    have harg := app_inv hb _ _ _ _ rfl
    obtain ⟨x,e',hi,hx⟩ := var_core harg 0 _ _ _ _ rfl rfl
    have ha := (hps a1 (by simp)).1
    simp only [bindParams,List.reverse_cons,List.reverse_nil,List.nil_append,List.map_cons,List.map_nil,
      List.singleton_append,List.getElem?_cons_zero,Option.some.injEq,List.length_cons,List.length_nil] at hi
    subst hi
    rw [Ty.shiftV_of_wf_zero ha] at hx
    have hw := wf_core ha hx
    have hr := hw.1
    simp [R,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn] at hr

/-! ## 型付き状態と遷移 -/


theorem T_shift : (T 0).shiftV 1 0 = T 1 := rfl

theorem scalar_ann (P : Program) (C : List TParam) (Γ : Ctx) : Ty.Annotation P C Γ scalar :=
  ⟨trivial,trivial,trivial⟩


theorem R0_sorted : (R 0).Sorted Γ0 :=
  ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩

theorem R0_declared (P : Program) : (R 0).Declared P [] Γ0 :=
  ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩

def Γ1 : Ctx := Γ0.extend (T 0)

theorem R1_sorted : (R 1).Sorted Γ1 :=
  ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩

theorem R1_declared (P : Program) : (R 1).Declared P [] Γ1 :=
  ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩

theorem capture_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none Γ0 [] cap := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi
    cases i with
    | zero => cases hi; trivial
    | succ i => simp [Γ0] at hi
  · intro i a hi
    cases i with
    | zero => exact ⟨seven,rfl⟩
    | succ i => simp [Γ0] at hi
  · intro i a hi
    cases i with
    | zero => cases hi; exact ⟨trivial,trivial⟩
    | succ i => simp [Γ0] at hi
  · intro p hp; cases hp
  · intro ov ho v hv
    simp [cap,Capture.values] at ho
    subst ho
    cases hv; trivial
  · intro i a hi
    cases i with
    | zero =>
      cases hi
      refine .ordinary (by simp [scalar]) ?_
      exact .V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide)
    | succ i => simp [Γ0] at hi
  · intro p hp
    simp [Γ0,Ctx.facts,scalar,Ty.assume] at hp

theorem T0_ann (P : Program) : Ty.Annotation P [] Γ0 (T 0) :=
  ⟨by simp [T,R,scalar,unitT,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Γ0,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.NotContCore,Ty.core],
   ⟨⟨R0_sorted,trivial⟩,trivial,trivial⟩,⟨⟨R0_declared P,trivial⟩,trivial,trivial⟩⟩

theorem m_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeC P B Ψ [] Γ0 [] none m (T 0) Eff.empty := by
  refine .C_Return (.V_Lam ?_ (T0_ann P).wf (T0_ann P).sorted ?_ (T0_ann P).declared)
  · exact ⟨rfl,by decide⟩
  · exact .C_Return (.V_Const trivial)

theorem n_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (Δ : LocalCtx) :
    HasTypeCQ P B Ψ Qempty [] Γ1 [] none n unitT Eff.empty Δ := by
  have ha : Ty.Annotation P [] Γ1 (.fn ["g"] [T 1] unitT Eff.empty) :=
    ⟨by simp [T,R,scalar,unitT,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Γ1,Γ0,Ctx.extend,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.NotContCore,Ty.core],
     ⟨⟨⟨⟨R1_sorted,trivial⟩,trivial,trivial⟩,trivial⟩,trivial,trivial⟩,
     ⟨⟨⟨⟨R1_declared P,trivial⟩,trivial,trivial⟩,trivial⟩,trivial,trivial⟩⟩
  refine .C_App (.V_Lam ?_ ha.wf ha.sorted ?_ ha.declared) (.cons (.V_Var rfl ?_) .nil)
  · exact ⟨rfl,by decide⟩
  · exact .C_Return (.V_Const trivial)
  · simp [T]

def q0 : Closure := .mk cap (.letIn m n)

theorem q0_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ClosureTy P B Ψ [] none q0 unitT Eff.empty := by
  have hb : HasTypeC P B Ψ [] Γ0 [] none (.letIn m n) unitT Eff.empty :=
    .C_Let (m_typed P B Ψ) (n_typed P B Ψ _) trivial
  have hca : cap.closeTyAt 0 unitT = unitT := Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := unitT) trivial _
  have hce : cap.closeEffAt 0 Eff.empty = Eff.empty := substEffValues_empty _
  have hh := ClosureTy.mk (ps := []) (Rs := none) (a := unitT) (e := Eff.empty) (capture_typed P B Ψ)
    (by simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,liftMany_eq,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hb)
    (by simp) rfl
    (by simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,hca] using (⟨trivial,trivial,trivial⟩ : Ty.Annotation P [] [] unitT))
    (by simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,hca,hce] using (⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩ : Ty.Annotation P [] [] (.dependentFn (.done unitT Eff.empty))))
    (by intro r h; cases h) (by intro r h; cases h)
  simpa only [List.length_nil,hca,hce,q0] using hh

def s0 : State := .run q0 [] Store.empty
def s1 : State := .run (.mk cap m) [.letF (.mk cap n)] Store.empty

theorem s0_step (P : Program) (B : Builtins) (σ : PathEnv) : Step P B σ s0 none s1 :=
  .E_Let (q := q0) rfl

theorem s1_untyped (P : Program) (B : Builtins) (σ : PathEnv) : ¬ StateTy P B σ s1 := by
  rintro ⟨_,Eb,_,Ψ,R0,a,b,e,e1,_,_,_,hk,_⟩
  obtain ⟨a1,R1,c,e',hq⟩ := cont_let hk _ _ rfl
  exact n_not_closed_input hq

theorem s0_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ s0 := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,unitT,unitT,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,q0_typed P B _,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨trivial,trivial,trivial⟩,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · simp [q0,cap,m,n,seven,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [q0,cap,m,n,seven,T,R,scalar,unitT,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.NotContCore,Ty.core,Capture.values]
  · intro f hf; cases hf
  · intro l c hc; cases hc

/-- `StateTy`は`Step`で保たれない（依存するletの入力）。 -/
theorem preservation_fails (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    ∃ s s', StateTy P B σ s ∧ Step P B σ s none s' ∧ ¬ StateTy P B σ s' :=
  ⟨s0,s1,s0_typed P B σ hv,s0_step P B σ,s1_untyped P B σ⟩

#print axioms preservation_fails

/-! ## 捕捉に依存する構築器の種類 -/

def kind0 : BuilderKind := .list (R 0)
def body0 : Comp := .builderOp (renameKind (shiftIndex 1 0) kind0) .length (.bound 0) []
def q2 : Closure := .mk cap (.builderLet kind0 body0)

def Γ2 : Ctx := Γ0.extendNone

theorem contents0_ann (P : Program) : Ty.Annotation P [] Γ0 kind0.contents :=
  ⟨by simp [kind0,BuilderKind.contents,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Γ0,Ty.NotContCore,Ty.core],
   R0_sorted,R0_declared P⟩

theorem R1_sorted' : (R 1).Sorted Γ2 :=
  ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩
theorem R1_declared' (P : Program) : (R 1).Declared P [] Γ2 :=
  ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩

theorem kind_shift : renameKind (shiftIndex 1 0) kind0 = .list (R 1) := by
  simp only [kind0,renameKind,←Ty.shiftV_eq_renameTy]
  rfl

theorem kinded (P : Program) (a : Ty) (ha : a.HasKind P [] .value) : TypeArgsKinded P [] [a] [.value] := by
  refine ⟨rfl,[],rfl,?_⟩
  intro i x k hx hk
  cases i with
  | zero => cases hx; cases hk; exact ha
  | succ i => simp at hx

theorem R_kind (P : Program) (d : Nat) : (R d).HasKind P [] .value := ⟨trivial,by simp [scalar,Ty.NotContCore,Ty.core]⟩

theorem body0_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] Γ2 [] none body0 (.base .integer) Eff.empty
      (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind0)) []) := by
  have ha : Ty.Annotation P [] Γ2 (renameKind (shiftIndex 1 0) kind0).contents := by
    rw [kind_shift]
    exact ⟨by simp [BuilderKind.contents,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Γ2,Γ0,Ctx.extendNone,Ty.NotContCore,Ty.core],
      R1_sorted',R1_declared' P⟩
  have hk : TypeArgsKinded P [] [(renameKind (shiftIndex 1 0) kind0).contents] [.value] := by
    rw [kind_shift]; exact kinded P _ (R_kind P 1)
  exact .C_BuilderOp ha hk (.bound rfl) .nil

theorem q2_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ClosureTy P B Ψ [] none q2 (.base .integer) Eff.empty := by
  have hb : HasTypeC P B Ψ [] Γ0 [] none (.builderLet kind0 body0) (.base .integer) Eff.empty :=
    .C_BuilderLet (contents0_ann P) (kinded P _ (R_kind P 0)) (body0_typed P B Ψ) trivial
  have hca : cap.closeTyAt 0 (.base .integer) = .base .integer := Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := .base .integer) trivial _
  have hce : cap.closeEffAt 0 Eff.empty = Eff.empty := substEffValues_empty _
  have hh := ClosureTy.mk (ps := []) (Rs := none) (a := .base .integer) (e := Eff.empty) (capture_typed P B Ψ)
    (by simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,liftMany_eq,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hb)
    (by simp) rfl
    (by simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,hca] using (⟨trivial,trivial,trivial⟩ : Ty.Annotation P [] [] (.base .integer)))
    (by simpa only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,hca,hce] using (⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩ : Ty.Annotation P [] [] (.dependentFn (.done (.base .integer) Eff.empty))))
    (by intro r h; cases h) (by intro r h; cases h)
  simpa only [List.length_nil,hca,hce,q2] using hh

def body1 : Comp := body0.subst builderValueSubst (builderLocalSubst 0)
def s2 : State := .run q2 [] Store.empty
def s3 : State := .run (.mk cap body1) [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))

theorem s2_step (P : Program) (B : Builtins) (σ : PathEnv) : Step P B σ s2 none s3 :=
  .E_BuilderNew (q := q2) rfl rfl

theorem R0_canonical : (R 0).norm = R 0 := Ty.canonical_of_wf (nr := 0) (nt := 0) (nv := 1)
  (by simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core])

theorem builderSubst_eq : builderValueSubst = openValue (.const .unit) := by
  funext i; cases i <;> rfl

theorem body1_eq : body1 = .builderOp (.list (R 0)) .length (.loc 0) [] := by
  have h : substTyValues builderValueSubst (R 1) = R 0 := by
    rw [builderSubst_eq]
    have := Ty.openValue_shift (R 0) (.const .unit)
    rw [R0_canonical] at this
    exact this
  simp only [body1,body0,kind_shift,Comp.subst,substKind,h]
  rfl

theorem builder_inv {P B Ψ Q C Γ Φ R0 c a e L} (h : HasTypeCQ P B Ψ Q C Γ Φ R0 c a e L) :
    ∀ k args, c = .builderOp k .length (.loc 0) args → Ψ 0 = some (.builder k) := by
  match h with
  | .C_BuilderOp _ _ hr _ => intro k args he; cases he; cases hr with | loc hl => exact hl
  | .C_Sub hm .. | .C_Eff hm .. => intro k args he; exact builder_inv hm _ _ he
  | .C_BuilderLet .. | .C_App .. | .C_DependentApp .. | .C_Return .. | .C_Let .. | .C_If .. | .C_Match .. | .C_Lazy .. |
    .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => intro k args he; cases he

theorem s3_untyped (P : Program) (B : Builtins) (σ : PathEnv) : ¬ StateTy P B σ s3 := by
  rintro ⟨_,Eb,_,Ψ,R0,a,b,e,e1,hs,hq,_⟩
  cases hq with
  | mk _ hb _ _ _ _ _ _ =>
    have hl := builder_inv hb _ _ body1_eq
    have hw := hs.wf 0 _ hl
    simp [LocTy.WF,R,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn] at hw

theorem s2_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ s2 := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,.base .integer,.base .integer,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,q2_typed P B _,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨trivial,trivial,trivial⟩,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · simp [q2,cap,body0,seven,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · have hc : cap.Closed := by simp [cap,seven,Capture.Closed,captureSlotsClosed,Val.ClosedAt]
    have h0 : (R 0).WF 0 0 1 := by simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
    have h1 : (R 1).WF 0 0 2 := by simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
    refine ⟨hc,h0,?_,?_,trivial⟩
    · change (renameKind (shiftIndex 1 0) kind0 |> fun k => match k with | .list a => a.WF 0 0 2 | _ => True)
      rw [kind_shift]; exact h1
    · change 0 < 2
      omega
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem builder_preservation_fails (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    ∃ s s', StateTy P B σ s ∧ Step P B σ s none s' ∧ ¬ StateTy P B σ s' :=
  ⟨s2,s3,s2_typed P B σ hv,s2_step P B σ,s3_untyped P B σ⟩

#print axioms builder_preservation_fails

end
end Benitoite.Release.Refinement.RvClosedParam
