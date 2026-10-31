import Lean
import Benitoite

namespace Benitoite.Release.Refinement.ClosureR2
noncomputable section
set_option linter.unusedSimpArgs false
@[simp] theorem close_base (cap : Capture) (b : BaseTy) : cap.closeTy (.base b) = .base b :=
  Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := .base b) trivial _
@[simp] theorem close_base_at (cap : Capture) (n : Nat) (b : BaseTy) : cap.closeTyAt n (.base b) = .base b :=
  Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := .base b) trivial _
@[simp] theorem close_empty (cap : Capture) : cap.closeEff Eff.empty = Eff.empty := substEffValues_empty _
@[simp] theorem close_empty_at (cap : Capture) (n : Nat) : cap.closeEffAt n Eff.empty = Eff.empty := substEffValues_empty _


def scalar : Ty := .base .integer8
def unitT : Ty := .base .unit
def seven : Val := .const (.integer8 7)
def R (d : Nat) : Ty := .refined scalar (.eq (.var 0) (.var (d+1)))
def T (d : Nat) : Ty := .fn ["u"] [R d] unitT Eff.empty
def Γ0 : Ctx := [some scalar]
def cap : Capture := .mk [some seven]
def m : Comp := .ret (.lam ["u"] [R 0] (.ret (.const .unit)))
def n : Comp := .app (.lam ["g"] [T 1] (.ret (.const .unit))) [.var 0]

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

theorem wrap {P B Ψ Ψs body a e}
    (hv : StoreTy.CaptureView cap Ψs Ψ)
    (hb : HasTypeC P B Ψs [] Γ0 [] none body a e)
    (ha : Ty.Annotation P [] Γ0 (.dependentFn (.done a e)))
    (hstable : Ψs.WF ∨ body.BuilderLocFree := by exact Or.inr (by simp [Comp.BuilderLocFree,Arms.BuilderLocFree])) :
    ClosureTy P B Ψ [] none (.mk cap body) (cap.closeTy a) (cap.closeEff e) :=
  ClosureTy.capture (capture_typed P B Ψ) hv hb LocalCtx.NoBuilders.empty ha rfl (by intros; contradiction) hstable

theorem wrap_open {P B Ψ Ψs body a e}
    (hv : StoreTy.CaptureView cap Ψs Ψ)
    (hb : OpenCodeTy P B Ψs Qempty [] Γ0 [] none body a e [])
    (ha : Ty.Annotation P [] Γ0 (.dependentFn (.done a e))) :
    ClosureTy P B Ψ [] none (.mk cap body) (cap.closeTy a) (cap.closeEff e) :=
  ClosureTy.capture_open (capture_typed P B Ψ) hv hb LocalCtx.NoBuilders.empty ha rfl (by intros; contradiction)

theorem done_ann {P Γ a} (ha : Ty.Annotation P [] Γ a) :
    Ty.Annotation P [] Γ (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,trivial,rfl⟩,⟨ha.sorted,trivial⟩,⟨ha.declared,trivial⟩⟩

theorem q0_typed (P : Program) (B : Builtins) :
    ClosureTy P B StoreTy.empty [] none q0 unitT Eff.empty := by
  have hh := wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap)
    (.C_Let (m_typed P B _) (n_typed P B _ _) (show unitT.Declared P [] Γ0 from trivial))
    (done_ann (show Ty.Annotation P [] Γ0 unitT from ⟨trivial,trivial,trivial⟩)) (Or.inl StoreTy.WF.empty)
  simpa [unitT,q0] using hh

def s0 : State := .run q0 [] Store.empty
def s1 : State := .run (.mk cap m) [.letF (.mk cap n)] Store.empty

theorem s0_step (P : Program) (B : Builtins) (σ : PathEnv) : Step P B σ s0 none s1 :=
  .E_Let (q := q0) rfl

theorem s0_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ s0 := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,unitT,unitT,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,q0_typed P B,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨trivial,trivial,trivial⟩,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · simp [q0,cap,m,n,seven,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [q0,cap,m,n,seven,T,R,scalar,unitT,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.NotContCore,Ty.core,Capture.values]
  · intro f hf; cases hf
  · intro l c hc; cases hc

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

theorem q2_typed (P : Program) (B : Builtins) :
    ClosureTy P B StoreTy.empty [] none q2 (.base .integer) Eff.empty :=
  by
  have hh := wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap)
    (.C_BuilderLet (contents0_ann P) (kinded P _ (R_kind P 0)) (body0_typed P B _) (show (Ty.base .integer).Declared P [] Γ0 from trivial))
    (done_ann (a := .base .integer) ⟨trivial,trivial,trivial⟩) (Or.inl StoreTy.WF.empty)
  simpa [q2] using hh

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

theorem s2_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ s2 := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,.base .integer,.base .integer,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,q2_typed P B,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨trivial,trivial,trivial⟩,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · simp [q2,cap,body0,seven,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · have hc : cap.Closed := by simp [cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Val.ClosedAt]
    have h0 : (R 0).WF 0 0 1 := by simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
    have h1 : (R 1).WF 0 0 2 := by simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
    refine ⟨hc,h0,?_,?_,trivial⟩
    · change (renameKind (shiftIndex 1 0) kind0 |> fun k => match k with | .list a => a.WF 0 0 2 | _ => True)
      rw [kind_shift]; exact h1
    · change 0 < 2
      omega
  · intro f hf; cases hf
  · intro l c hc; cases hc


/-- レビューのs1_untypedの反転。ソースの入力はT(0)、実行時の入力はcloseTy T(0)。 -/
theorem n_closure (P : Program) (B : Builtins) :
    ClosureTy P B StoreTy.empty [cap.closeTy (T 0)] none (.mk cap n) unitT Eff.empty := by
  have ht := (capture_typed P B StoreTy.empty).substOk.annotation (T0_ann P)
  have hh := ClosureTy.mk (ss := [T 0]) (Rs := none) (a := unitT) (e := Eff.empty)
    (capture_typed P B StoreTy.empty) (StoreTy.CaptureView.refl StoreTy.WF.empty cap 1)
    (.typed (n_typed P B _ [none]) (Or.inr (by simp [n,Comp.BuilderLocFree]))) (LocalCtx.NoBuilders.empty.localExtend 1)
    (by intro a ha; have he := List.mem_singleton.mp ha; subst a; exact T0_ann P)
    (by intro a ha; simp only [List.map_cons,List.map_nil,List.mem_singleton] at ha; subst a; exact ht)
    rfl (by exact ⟨trivial,trivial,trivial⟩)
    (by simpa only [unitT,close_base_at,close_empty_at] using (done_ann (P := P) (Γ := bindParams [] ([T 0].map cap.closeTy)) (a := unitT) ⟨trivial,trivial,trivial⟩))
    (by intros; contradiction) (by intros; contradiction)
  simpa [unitT] using hh

theorem s1_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ s1 := by
  have ht := (capture_typed P B StoreTy.empty).substOk.annotation (T0_ann P)
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,cap.closeTy (T 0),unitT,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,(by simpa using wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) (m_typed P B _) (done_ann (T0_ann P)) (Or.inl StoreTy.WF.empty)),
    (⟨fun _ h => h,fun _ h => h⟩ : Eff.Sub _ _), .K_Let (c := unitT) (e1 := Eff.empty) (by simpa [unitT,Ty.shiftV,Eff.shiftV,renameEff,Eff.empty] using n_closure P B) ?_ ht (⟨fun _ h => h,fun _ h => h⟩ : Eff.Sub _ _) (.K_Empty (⟨fun _ h => h,fun _ h => h⟩ : Eff.Sub _ _) ⟨trivial,trivial,trivial⟩),?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · simp [cap,n,seven,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [cap,m,seven,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [cap,m,seven,R,scalar,unitT,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.NotContCore,Ty.core,Capture.values]
  · intro f hf
    have he := List.mem_singleton.mp hf; subst f
    simp [Frame.Closed,cap,n,seven,T,R,scalar,unitT,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.NotContCore,Ty.core,Capture.values]
  · intro l c hc; cases hc

def sourceBuilder : StoreTy := fun l => if l = 0 then some (.builder kind0) else none
def runtimeBuilder : StoreTy := fun l => if l = 0 then some (.builder (substKind cap.env kind0)) else none

theorem builder_view : StoreTy.CaptureView cap sourceBuilder runtimeBuilder := by
  intro l x hx
  by_cases hl : l = 0
  · subst l; simp [sourceBuilder] at hx; subst x; rfl
  · simp [sourceBuilder,hl] at hx

theorem builder_store (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ runtimeBuilder (Store.empty.set 0 (.builder (substKind cap.env kind0).empty)) := by
  have ht := (capture_typed P B StoreTy.empty).substOk.annotation (contents0_ann P)
  refine ⟨⟨1,?_⟩,?_,?_,?_,?_⟩
  · intro l hl; simp [Store.set,Store.empty,show l ≠ 0 by omega]
  · intro l x hx
    by_cases hl : l = 0
    · subst l; simp [runtimeBuilder] at hx; subst x; exact ht.wf
    · simp [runtimeBuilder,hl] at hx
  · intro l x hx
    by_cases hl : l = 0
    · subst l; simp [runtimeBuilder] at hx; subst x; exact ht.declared
    · simp [runtimeBuilder,hl] at hx
  · intro l x hx
    by_cases hl : l = 0
    · subst l; simp [Store.set]
    · simp [runtimeBuilder,hl] at hx
  · intro l c hc
    by_cases hl : l = 0
    · subst l; simp [Store.set] at hc; subst c
      exact ⟨.list (cap.closeTy (R 0)),rfl,⟨by decide,⟨(by simpa [Capture.closeTy,kind0,BuilderKind.contents] using (show Ty.Annotation P [] [] (substTyValues cap.env (R 0)) from ⟨ht.wf,ht.sorted,ht.declared⟩)),HasTypeEachQ.nil⟩⟩,trivial⟩
    · simp [Store.set,Store.empty,hl] at hc

theorem body1_typed (P : Program) (B : Builtins) :
    HasTypeC P B sourceBuilder [] Γ0 [] none body1 (.base .integer) Eff.empty := by
  rw [body1_eq]
  exact .C_BuilderOp (contents0_ann P) (kinded P _ (R_kind P 0)) (.loc rfl) .nil

/-- レビューのs3_untypedの反転。ソースの種類とセルの閉じた種類を別に保持する。 -/
theorem s3_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ s3 := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,runtimeBuilder,none,.base .integer,.base .integer,Eff.empty,Eff.empty,
    builder_store P B σ,(by simpa using wrap_open builder_view (by rw [body1_eq]; exact .builderOp (contents0_ann P) (kinded P _ (R_kind P 0)) (.loc rfl) .nil) (done_ann (a := .base .integer) ⟨trivial,trivial,trivial⟩)),(⟨fun _ h => h,fun _ h => h⟩ : Eff.Sub _ _),
    .K_Empty (⟨fun _ h => h,fun _ h => h⟩ : Eff.Sub _ _) ⟨trivial,trivial,trivial⟩,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · rw [body1_eq]; simp [cap,seven,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · rw [body1_eq]
    refine ⟨by simp [cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Val.ClosedAt],?_,trivial,trivial⟩
    change (R 0).WF 0 0 1
    simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · intro f hf; cases hf
  · intro l c hc
    by_cases hl : l = 0
    · subst l; simp [Store.set] at hc; subst c; trivial
    · simp [Store.set,Store.empty,hl] at hc

abbrev subRefl (e : Eff) : Eff.Sub e e := ⟨fun _ h => h,fun _ h => h⟩

def oneTy (x : LocTy) : StoreTy := fun l => if l = 0 then some x else none

theorem one_wf {x : LocTy} (h : x.WF) : (oneTy x).WF := by
  intro l y hy; by_cases hl : l = 0
  · subst l; simp [oneTy] at hy; subst y; exact h
  · simp [oneTy,hl] at hy

theorem one_declared {P x} (h : LocTy.Declared P x) : StoreTy.Declared P (oneTy x) := by
  intro l y hy; by_cases hl : l = 0
  · subst l; simp [oneTy] at hy; subst y; exact h
  · simp [oneTy,hl] at hy

theorem one_store {P B σ x c} (hw : x.WF) (hd : LocTy.Declared P x)
    (hc : CellOk P B σ (oneTy x) 0 c) :
    StoreOk P B σ (oneTy x) (Store.empty.set 0 c) := by
  refine ⟨⟨1,?_⟩,one_wf hw,one_declared hd,?_,?_⟩
  · intro l hl; simp [Store.set,Store.empty,show l ≠ 0 by omega]
  · intro l y hy; by_cases hl : l = 0
    · subst l; simp [Store.set]
    · simp [oneTy,hl] at hy
  · intro l y hy; by_cases hl : l = 0
    · subst l; simp [Store.set] at hy; subst y; exact hc
    · simp [Store.set,Store.empty,hl] at hy

theorem one_closed {c} (h : c.Closed) : (Store.empty.set 0 c).Closed := by
  intro l y hy; by_cases hl : l = 0
  · subst l; simp [Store.set] at hy; subst y; exact h
  · simp [Store.set,Store.empty,hl] at hy

theorem run_state {P B σ Ψ μ R q k a b e Eb}
    (hv : σ.Valid) (hb : BuiltinOnly P B Eb) (hs : StoreOk P B σ Ψ μ)
    (hq : ClosureTy P B Ψ [] R q a e) (hk : ContTy P B σ Ψ R e k a b Eb none)
    (ha : q.Adequate σ) (hc : q.ClosedAt 0) (hkc : k.Closed) (hmc : μ.Closed) :
    StateTy P B σ (.run q k μ) :=
  ⟨hv,Eb,hb,Ψ,R,a,b,e,e,hs,hq,subRefl e,hk,ha,hc,hkc,hmc⟩

theorem empty_builtin (P : Program) (B : Builtins) : BuiltinOnly P B Eff.empty :=
  ⟨rfl,by intro a ha; cases ha⟩

def refΓ : Ctx := Γ0.extend (.reference (R 0))
def refCap : Capture := cap.extend (.loc 0)
def refTy : Ty := cap.closeTy (R 0)
def refΨ : StoreTy := oneTy (.ref refTy)
def refμ : Store := Store.empty.set 0 (.val seven)

def emptyBuiltins : Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := ""
  refSet := ""

theorem ref_ann (P : Program) : Ty.Annotation P [] [] refTy :=
  (capture_typed P emptyBuiltins StoreTy.empty).substOk.annotation
    ⟨(contents0_ann P).wf,(contents0_ann P).sorted,(contents0_ann P).declared⟩

theorem seven_ref (P : Program) (B : Builtins) (Ψ : StoreTy) : HasTypeV P B Ψ [] [] [] seven refTy := by
  change HasTypeV P B Ψ [] [] [] seven (.refined scalar (.eq (.var 0) (.integer 7)))
  refine .V_Refine (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide)) rfl rfl ?_ ?_ ?_ trivial ?_
  · exact ⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨trivial,rfl⟩⟩
  · simp [Pred.WF,Pred.VarsIn,Term.VarsIn]
  · exact .eq_refl
  · exact ⟨⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩,trivial⟩

theorem ref_store (P : Program) (B : Builtins) (σ : PathEnv) : StoreOk P B σ refΨ refμ :=
  one_store (ref_ann P).wf (ref_ann P).declared ⟨refTy,rfl,seven_ref P B _,trivial⟩

theorem Rref_sorted : (R 1).Sorted refΓ :=
  ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩
theorem Rref_declared (P : Program) : (R 1).Declared P [] refΓ :=
  ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩

theorem ref_capture (P : Program) (B : Builtins) : CaptureOk P B refΨ none refΓ [] refCap := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi
    cases i with
    | zero => cases hi; change (R 1).WF 0 0 2; simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
    | succ i => cases i with
      | zero => cases hi; trivial
      | succ i => simp [refΓ,Γ0,Ctx.extend] at hi
  · intro i a hi
    cases i with
    | zero => exact ⟨.loc 0,rfl⟩
    | succ i => cases i with
      | zero => exact ⟨seven,rfl⟩
      | succ i => simp [refΓ,Γ0,Ctx.extend] at hi
  · intro i a hi
    cases i with
    | zero => cases hi; exact ⟨Rref_sorted,Rref_declared P⟩
    | succ i => cases i with
      | zero => cases hi; exact ⟨trivial,trivial⟩
      | succ i => simp [refΓ,Γ0,Ctx.extend] at hi
  · intro p hp; cases hp
  · intro ov ho v he
    simp [refCap,cap,Capture.extend,Capture.values] at ho
    rcases ho with rfl | rfl <;> cases he <;> trivial
  · intro i a hi
    cases i with
    | zero =>
      cases hi
      refine .ordinary (by simp [Ty.Ordinary,refΓ,Γ0,Ctx.extend,R,Ty.shiftV,renameTy]) ?_
      change HasTypeV P B refΨ [] [] [] (.loc 0) (.reference refTy)
      exact .V_LocRef rfl (ref_ann P).declared
    | succ i => cases i with
      | zero => cases hi; exact .ordinary (by simp [Ty.Ordinary,scalar,Ty.shiftV,renameTy]) (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide))
      | succ i => simp [refΓ,Γ0,Ctx.extend] at hi
  · intro p hp; simp [refΓ,Γ0,Ctx.extend,Ctx.facts,scalar,R,Ty.shiftV,renameTy,Ty.assume] at hp

def varAlt : List Alt := [⟨.var,[0]⟩]
def matchBody : Comp := .ret (.const .unit)
def wildAlt : List Alt := [⟨.wild,[]⟩]
def refMatchUse : Comp := .app (.lam ["r"] [.reference (R 2)] (.ret (.const .unit))) [.var 0]
def matchArms : List Arm := [.mk wildAlt (some (.ret (.const (.boolean false)))) matchBody,
  .mk varAlt none refMatchUse]
def matchQ : Closure := .mk refCap (.match (.var 0) matchArms)
def matchState (next : Nat) : State := .matchRun (.loc 0) refCap matchArms next [] refμ

theorem var_alts (P : Program) (a : Ty) : AltsTy P varAlt a [a] := by
  refine ⟨by simp [varAlt],rfl,?_,?_⟩
  · intro alt ha; simp [varAlt] at ha; subst alt; rfl
  · intro alt ha; have he := List.mem_singleton.mp ha; subst alt
    exact ⟨[a],.P_Var,List.Perm.refl _,rfl⟩

theorem wild_alts (P : Program) (a : Ty) : AltsTy P wildAlt a [] := by
  refine ⟨by simp [wildAlt],rfl,?_,?_⟩
  · intro alt ha; simp [wildAlt] at ha; subst alt; rfl
  · intro alt ha; have he := List.mem_singleton.mp ha; subst alt
    exact ⟨[],.P_Wild,List.Perm.refl _,rfl⟩

theorem ref_match_use_typed (P : Program) (B : Builtins) :
    HasTypeCQ P B refΨ Qempty [] (refΓ.extend (.reference (R 1))) [] none refMatchUse unitT Eff.empty [none] := by
  have hr : Ty.Annotation P [] (refΓ.extend (.reference (R 1))) (R 2) :=
    ⟨by simp [refΓ,Γ0,Ctx.extend,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core],
     ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,
     ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩⟩
  have ha : Ty.Annotation P [] (refΓ.extend (.reference (R 1)))
      (.fn ["r"] [.reference (R 2)] unitT Eff.empty) :=
    ⟨⟨⟨rfl,by decide⟩,⟨hr.wf,trivial⟩,trivial,trivial,rfl⟩,
     ⟨⟨hr.sorted,trivial⟩,trivial,trivial⟩,⟨⟨hr.declared,trivial⟩,trivial,trivial⟩⟩
  exact .C_App (.V_Lam ⟨rfl,by decide⟩ ha.wf ha.sorted (.C_Return (.V_Const trivial)) ha.declared)
    (.cons (.V_Var rfl (by simp [Ty.Ordinary,Ty.shiftV,renameTy])) .nil)

theorem match_arms (P : Program) (B : Builtins) :
    HasTypeArms P B refΨ [] refΓ [] none matchArms (.reference (R 1)) unitT Eff.empty :=
  .guarded (wild_alts P _) (.C_Return (.V_Const trivial)) (.C_Return (.V_Const trivial))
    (.plain (var_alts P _) (ref_match_use_typed P B) (.nil ⟨trivial,trivial,trivial⟩))

theorem match_exhaustive (P : Program) : Exhaustive P (.reference (R 1)) (unguardedPats matchArms) := by
  intro v hv; exact ⟨.var,by simp [matchArms,varAlt,unguardedPats],by simp [matchVal]⟩

theorem match_closure (P : Program) (B : Builtins) : ClosureTy P B refΨ [] none matchQ unitT Eff.empty := by
  have hh := ClosureTy.capture (ref_capture P B) (StoreTy.CaptureView.refl (one_wf (x := .ref refTy) (ref_ann P).wf) refCap)
    (.C_Match (.V_Var (i := 0) rfl (by simp [Ty.Ordinary,Ty.shiftV,renameTy,R])) (match_arms P B) (match_exhaustive P))
    LocalCtx.NoBuilders.empty (done_ann (a := unitT) ⟨trivial,trivial,trivial⟩) rfl (by intros; contradiction) (Or.inl (one_wf (x := .ref refTy) (ref_ann P).wf))
  simpa [unitT,matchQ] using hh

theorem match_prefix (next : Nat) (hn : next ≤ 1) : MatchPrefix (.loc 0) matchArms next := by
  intro arm ha hg
  have he : next = 0 ∨ next = 1 := by omega
  rcases he with rfl | rfl
  · simp at ha
  · simp [matchArms] at ha; subst arm; cases hg

theorem match_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid)
    (next : Nat) (hn : next ≤ 1) : StateTy P B σ (matchState next) := by
  refine ⟨hv,Eff.empty,empty_builtin P B,refΨ,none,unitT,unitT,Eff.empty,Eff.empty,
    ref_store P B σ,⟨.var 0,rfl,match_closure P B⟩,subRefl _,
    .K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩,trivial,?_,match_prefix next hn,trivial,?_,?_,?_,one_closed trivial⟩
  · simp [refCap,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,Capture.extend,Val.Adequate]
  · simp [matchArms,refMatchUse,adequateVals,show Arm.bindersOf varAlt = 1 from rfl,matchBody,adequateVals,adequateArms,Comp.Adequate,Val.Adequate]
  · simp [refCap,cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Capture.extend,Val.ClosedAt,matchArms,refMatchUse,adequateVals,show Arm.bindersOf varAlt = 1 from rfl,matchBody,unitT,R,scalar,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Val.ClosedList,Arm.ClosedList,Comp.ClosedAt]
  · intro f hf; cases hf

theorem match_before_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run matchQ [] refμ) := by
  apply run_state hv (empty_builtin P B) (ref_store P B σ) (match_closure P B)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [matchQ,refCap,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,Capture.extend,Closure.Adequate,
      Comp.Adequate,Val.Adequate,matchArms,refMatchUse,adequateVals,show Arm.bindersOf varAlt = 1 from rfl,matchBody,adequateVals,adequateArms]
  · simp [matchQ,refCap,cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Capture.extend,Closure.ClosedAt,
      Comp.ClosedAt,Val.ClosedAt,matchArms,refMatchUse,adequateVals,show Arm.bindersOf varAlt = 1 from rfl,matchBody,unitT,R,scalar,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Val.ClosedList,Arm.ClosedList]
  · intro f hf; cases hf
  · exact one_closed trivial

theorem match_transition (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run matchQ [] refμ) ∧
    Step P B σ (.run matchQ [] refμ) none (matchState 0) ∧ StateTy P B σ (matchState 0) :=
  ⟨match_before_typed P B σ hv,.E_Match (q := matchQ) rfl,match_typed P B σ hv 0 (by decide)⟩

def guardBody : Closure := .mk refCap matchBody
def guardQ : Closure := .mk refCap (.ret (.const (.boolean false)))
def guardK : Cont := [.guardF (.loc 0) refCap matchArms 1 guardBody]
def guardState : State := .run guardQ guardK refμ

theorem ref_wrap {P B body a}
    (hb : HasTypeC P B refΨ [] refΓ [] none body a Eff.empty)
    (ha : Ty.Annotation P [] refΓ a) :
    ClosureTy P B refΨ [] none (.mk refCap body) (refCap.closeTy a) Eff.empty := by
  simpa using ClosureTy.capture (ref_capture P B)
    (StoreTy.CaptureView.refl (one_wf (x := .ref refTy) (ref_ann P).wf) refCap)
    hb LocalCtx.NoBuilders.empty (done_ann ha) rfl (by intros; contradiction) (Or.inl (one_wf (x := .ref refTy) (ref_ann P).wf))

theorem guard_cont (P : Program) (B : Builtins) (σ : PathEnv) :
    ContTy P B σ refΨ none Eff.empty guardK (.base .boolean) unitT Eff.empty none := by
  refine .K_Guard (Rs := none) (as := unitT) (es := Eff.empty)
    (ref_capture P B) (StoreTy.CaptureView.refl (one_wf (x := .ref refTy) (ref_ann P).wf) refCap)
    (.V_Var (i := 0) rfl (by simp [Ty.Ordinary,Ty.shiftV,renameTy,R])) (.typed (match_arms P B) (Or.inl (one_wf (x := .ref refTy) (ref_ann P).wf)))
    (done_ann (a := unitT) (P := P) (Γ := refΓ) ⟨trivial,trivial,trivial⟩).declared
    (by intros; contradiction) (match_exhaustive P) rfl rfl (close_base _ _) (close_empty _)
    (by simpa [guardBody,matchBody,unitT] using ref_wrap (P := P) (B := B) (.C_Return (.V_Const (c := .unit) trivial)) (a := unitT) ⟨trivial,trivial,trivial⟩)
    (subRefl _) (match_prefix 1 (by decide)) (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩) ?_
  simp [Frame.Adequate,guardBody,matchBody,refMatchUse,adequateVals,show Arm.bindersOf varAlt = 1 from rfl,matchArms,unitT,R,scalar,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Val.ClosedList,refCap,cap,seven,Capture.values,Capture.extend,
    Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate,adequateArms]

theorem guard_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ guardState := by
  apply run_state hv (empty_builtin P B) (ref_store P B σ)
    (by simpa [guardQ] using ref_wrap (P := P) (B := B) (.C_Return (.V_Const (c := .boolean false) trivial)) (a := .base .boolean) ⟨trivial,trivial,trivial⟩)
    (guard_cont P B σ)
  · simp [guardQ,refCap,cap,seven,Capture.values,Capture.extend,Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate]
  · simp [guardQ,refCap,cap,seven,Capture.values,Capture.extend,Capture.Closed,captureSlotsClosed,Closure.ClosedAt,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f
    simp [Val.Ground,Frame.Closed,guardBody,matchBody,refMatchUse,adequateVals,show Arm.bindersOf varAlt = 1 from rfl,matchArms,unitT,R,scalar,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Val.ClosedList,refCap,cap,seven,Capture.values,Capture.extend,
      Capture.Closed,captureSlotsClosed,Closure.ClosedAt,Comp.ClosedAt,Val.ClosedAt,Arm.ClosedList]
  · exact one_closed trivial

theorem guard_push (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (matchState 0) ∧ Step P B σ (matchState 0) none guardState ∧ StateTy P B σ guardState :=
  ⟨match_typed P B σ hv 0 (by decide),.E_MatchGuard (ws := []) (alts := wildAlt) (guard := .ret (.const (.boolean false))) (body := matchBody) rfl rfl,guard_typed P B σ hv⟩

theorem guard_false (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ guardState ∧ Step P B σ guardState none (matchState 1) ∧ StateTy P B σ (matchState 1) :=
  ⟨guard_typed P B σ hv,.E_GuardF rfl,match_typed P B σ hv 1 (by decide)⟩

def unitQ : Closure := .mk cap (.ret (.const .unit))
def pureUnit : Closure := Closure.pure (.ret (.const .unit))

theorem unit_q {P B Ψ} (hw : Ψ.WF) : ClosureTy P B Ψ [] none unitQ unitT Eff.empty := by
  simpa [unitQ,unitT,Const.type] using wrap (StoreTy.CaptureView.refl hw cap)
    (.C_Return (.V_Const (c := .unit) trivial)) (done_ann (P := P) (Γ := Γ0) (a := unitT) ⟨trivial,trivial,trivial⟩)

theorem pure_unit {P B Ψ R} (hw : Ψ.WF)
    (hr : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] []) :
    ClosureTy P B Ψ [] R pureUnit unitT Eff.empty :=
  ClosureTy.pure (.C_Return (.V_Const (c := .unit) trivial)) (done_ann (P := P) (Γ := []) (a := unitT) ⟨trivial,trivial,trivial⟩) hr hw

theorem unit_adequate (σ : PathEnv) : unitQ.Adequate σ := by
  simp [unitQ,cap,seven,Closure.Adequate,Capture.Adequate,Capture.values,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
theorem unit_closed : unitQ.ClosedAt 0 := by
  simp [unitQ,cap,seven,Closure.ClosedAt,Capture.Closed,Capture.values,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
theorem pure_adequate (σ : PathEnv) : pureUnit.Adequate σ := by
  simp [pureUnit,Closure.pure,Capture.empty,Closure.Adequate,Capture.Adequate,Capture.values,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
theorem pure_closed : pureUnit.ClosedAt 0 := by
  simp [pureUnit,Closure.pure,Capture.empty,Closure.ClosedAt,Capture.Closed,Capture.values,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]

theorem unit_state {P B σ Ψ μ} (hv : σ.Valid) (hs : StoreOk P B σ Ψ μ) (hm : μ.Closed) :
    StateTy P B σ (.run unitQ [] μ) :=
  run_state hv (empty_builtin P B) hs (unit_q hs.wf) (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
    (unit_adequate σ) unit_closed (by intro f hf; cases hf) hm

theorem pure_state {P B σ Ψ μ} (hv : σ.Valid) (hs : StoreOk P B σ Ψ μ) (hm : μ.Closed) :
    StateTy P B σ (.run pureUnit [] μ) :=
  run_state hv (empty_builtin P B) hs (pure_unit hs.wf (by intros; contradiction))
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩) (pure_adequate σ) pure_closed (by intro f hf; cases hf) hm

def callQ : Closure := Closure.pure (.app (.dependentLam (.done unitT Eff.empty) (.ret (.const .unit))) [])

theorem call_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run callQ [] Store.empty) := by
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ)
    (ClosureTy.pure (a := unitT) (e := Eff.empty)
      (.C_DependentApp (args := []) (.V_DependentLam (done_ann (P := P) (Γ := []) (a := unitT) ⟨trivial,trivial,trivial⟩) (.done (.C_Return (.V_Const (c := .unit) trivial))))
        (.done (done_ann (P := P) (Γ := []) (a := unitT) ⟨trivial,trivial,trivial⟩)))
      (done_ann (P := P) (Γ := []) (a := unitT) ⟨trivial,trivial,trivial⟩) (by intros; contradiction) StoreTy.WF.empty)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [callQ,Closure.pure,Capture.empty,Closure.Adequate,Capture.Adequate,Capture.values,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [callQ,Closure.pure,Capture.empty,unitT,Closure.ClosedAt,Capture.Closed,Capture.values,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Tel.WF,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem mark_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run pureUnit [.mark] Store.empty) :=
  run_state hv (empty_builtin P B) (StoreOk.empty P B σ)
    (pure_unit StoreTy.WF.empty (R := some unitT) (by intro r hr; cases hr; exact ⟨trivial,trivial⟩))
    (.K_Mark (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩) ⟨trivial,trivial,trivial⟩)
    (pure_adequate σ) pure_closed (by intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial)
    (by intro l c hc; cases hc)

theorem mark_push (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run callQ [] Store.empty) ∧
    Step P B σ (.run callQ [] Store.empty) none (.run pureUnit [.mark] Store.empty) ∧
    StateTy P B σ (.run pureUnit [.mark] Store.empty) :=
  ⟨call_typed P B σ hv,.E_Lam (q := callQ) (signature := Capture.empty.closeTel (.done unitT Eff.empty)) (body := pureUnit) (ws := []) rfl rfl,mark_typed P B σ hv⟩

theorem mark_pop (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run pureUnit [.mark] Store.empty) ∧
    Step P B σ (.run pureUnit [.mark] Store.empty) none (.run pureUnit [] Store.empty) ∧
    StateTy P B σ (.run pureUnit [] Store.empty) :=
  ⟨mark_typed P B σ hv,.E_Mark rfl,pure_state hv (StoreOk.empty P B σ) (by intro l c hc; cases hc)⟩

theorem masked_capture {P B Ψ R cap}
    (hg : ∀ ov ∈ cap.values, ∀ v, ov = some v → v.Ground) :
    CaptureOk P B Ψ R (List.replicate cap.values.length none) [] cap := by
  have hn : ∀ (i : Nat) (a : Ty), (List.replicate cap.values.length (none : Option Ty))[i]? ≠ some (some a) := by
    intro i a; simp only [List.getElem?_replicate]; split <;> simp
  refine .mk (fun i a h => (hn i a h).elim) (by simp) (fun i a h => (hn i a h).elim)
    (fun i a h => (hn i a h).elim) (by intros p hp; cases hp) hg
    (fun i a h => (hn i a h).elim) ?_
  intro p hp
  obtain ⟨i,a,q,hi,_,_⟩ := Ctx.mem_facts.mp (by simpa using hp)
  exact (hn i a hi).elim

theorem masked_unit {P B Ψ cap} (hw : Ψ.WF)
    (hg : ∀ ov ∈ cap.values, ∀ v, ov = some v → v.Ground) :
    ClosureTy P B Ψ [] none (.mk cap (.ret (.const .unit))) unitT Eff.empty := by
  have hh := ClosureTy.capture (P := P) (B := B) (Rs := none) (masked_capture (R := none) hg) (StoreTy.CaptureView.refl hw cap)
    (.C_Return (.V_Const (c := .unit) trivial)) LocalCtx.NoBuilders.empty
    (done_ann (P := P) (a := unitT) ⟨trivial,trivial,trivial⟩) rfl (by intros; contradiction) (Or.inr (by simp [Comp.BuilderLocFree]))
  simpa [unitT,Const.type] using hh

def failH : List Clause := [.fail unitT (.ret (.const .unit))]
def raised : Comp := .app (.raise unitT unitT) [.const .unit]
def failQ : Closure := .mk cap raised
def failK : Cont := [.handleF cap failH]
def handledQ : Closure := .mk cap (.handle raised failH)
def contLocTy : LocTy := .cont unitT unitT Eff.empty none
def contΨ : StoreTy := oneTy contLocTy
def contμ : Store := Store.empty.set 0 (.cont failK)
def usedμ : Store := Store.empty.set 0 .used
def clauseCap : Capture := cap.extendMany [.const .unit,.loc 0]
def clauseQ : Closure := .mk clauseCap (.ret (.const .unit))
def dropK : Cont := [.drop 0]

theorem failure_clause (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasFailureClause P B Ψ Qempty [] Γ0 [] unitT none failH unitT Eff.empty [] := by
  refine .one ⟨trivial,trivial,trivial⟩ ⟨trivial,trivial,trivial⟩ ?_ (.C_Return (.V_Const trivial))
  intro e he; have he := List.mem_singleton.mp he; subst e
  exact ⟨⟨⟨rfl,by decide⟩,trivial,trivial,trivial,rfl⟩,⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩⟩

theorem raise_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeC P B Ψ [] Γ0 [] none raised unitT (Eff.singleFail unitT) := by
  refine .C_App (.V_Raise ?_) (.cons (.V_Const trivial) .nil)
  exact ⟨⟨⟨rfl,by decide⟩,⟨trivial,trivial⟩,trivial,⟨trivial,trivial⟩,rfl⟩,
    ⟨⟨trivial,trivial⟩,trivial,⟨trivial,trivial⟩⟩,⟨⟨trivial,trivial⟩,trivial,⟨trivial,trivial⟩⟩⟩

theorem fail_sub : Eff.Sub (Eff.singleFail unitT) (Eff.union (Eff.singleFail unitT) Eff.empty) := by
  refine ⟨?_,?_⟩
  · intro a ha; cases ha
  · intro t ht
    rw [Eff.union,Eff.norm_memFail]
    simpa only [Eff.memFail,Eff.fails,Eff.empty,List.append_nil] using ht

theorem fail_cont (P : Program) (B : Builtins) (σ : PathEnv) (Ψ : StoreTy) :
    ContTy P B σ Ψ none (Eff.singleFail unitT) failK unitT unitT Eff.empty none := by
  refine .K_Handle_Fail (ec := Eff.empty) (rest := Eff.empty) (E := unitT)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩) (Eff.Covers.refl [] [] _) ⟨rfl,by intro i hi; cases hi⟩
    (capture_typed P B _) (failure_clause P B _) rfl (close_base _ _) (close_empty _) (close_base _ _)
    (by intros; contradiction) (Eff.Covers.refl [] [] _) ⟨trivial,trivial,trivial⟩ ?_
  simp [Frame.Adequate,failH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,adequateClauses,Comp.Adequate,Val.Adequate]

theorem fail_frame_closed : (Frame.handleF cap failH).Closed := by
  simp [Frame.Closed,failH,unitT,cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Clause.ClosedList,Comp.ClosedAt,Val.ClosedAt,Ty.WF]

theorem fail_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run failQ failK Store.empty) := by
  have hq : ClosureTy P B StoreTy.empty [] none failQ unitT (Eff.singleFail unitT) := by
    have hh := wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) (raise_typed P B _)
      (show Ty.Annotation P [] Γ0 (.dependentFn (.done unitT (Eff.singleFail unitT))) from
          ⟨⟨trivial,⟨trivial,trivial⟩,rfl⟩,⟨trivial,⟨trivial,trivial⟩⟩,⟨trivial,⟨trivial,trivial⟩⟩⟩) (Or.inl StoreTy.WF.empty)
    simpa [failQ,unitT,Capture.closeEff,Capture.closeTy,substEffValues_singleFail,Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := .base .unit) trivial] using hh
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ) hq (fail_cont P B σ _)
  · simp [failQ,raised,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [failQ,raised,cap,seven,Capture.values,unitT,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f; exact fail_frame_closed
  · intro l c hc; cases hc

theorem cont_store (P : Program) (B : Builtins) (σ : PathEnv) : StoreOk P B σ contΨ contμ :=
  one_store ⟨trivial,trivial,trivial,rfl,by intros; contradiction⟩
    ⟨trivial,trivial,trivial,by intros; contradiction⟩
    ⟨unitT,unitT,Eff.empty,none,rfl,⟨[],cap,failH,rfl⟩,none,Eff.singleFail unitT,fail_cont P B σ _⟩

theorem used_store (P : Program) (B : Builtins) (σ : PathEnv) : StoreOk P B σ contΨ usedμ :=
  one_store ⟨trivial,trivial,trivial,rfl,by intros; contradiction⟩
    ⟨trivial,trivial,trivial,by intros; contradiction⟩ ⟨unitT,unitT,Eff.empty,none,rfl⟩

theorem drop_cont (P : Program) (B : Builtins) (σ : PathEnv) :
    ContTy P B σ contΨ none Eff.empty dropK unitT unitT Eff.empty none :=
  .K_Drop rfl (by intro h; cases h) (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)

theorem clause_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run clauseQ dropK contμ) := by
  have hg : ∀ ov ∈ clauseCap.values, ∀ v, ov = some v → v.Ground := by
    intro ov ho v he
    simp [clauseCap,cap,seven,Capture.extendMany,Capture.extend,Capture.values] at ho
    rcases ho with rfl | rfl | rfl <;> cases he <;> trivial
  apply run_state hv (empty_builtin P B) (cont_store P B σ)
    (masked_unit (cont_store P B σ).wf hg) (drop_cont P B σ)
  · simp [clauseQ,clauseCap,cap,seven,Capture.values,Capture.extendMany,Capture.extend,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [clauseQ,clauseCap,cap,seven,Capture.values,Capture.extendMany,Capture.extend,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial
  · exact one_closed (by change failK.Closed; intro f hf; have he := List.mem_singleton.mp hf; subst f; exact fail_frame_closed)

theorem continuation_new (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run failQ failK Store.empty) ∧
    Step P B σ (.run failQ failK Store.empty) none (.run clauseQ dropK contμ) ∧
    StateTy P B σ (.run clauseQ dropK contμ) := by
  refine ⟨fail_before P B σ hv,?_,clause_typed P B σ hv⟩
  have he : (.ret (.const .unit) : Comp).substTy [unitT] [] = .ret (.const .unit) := rfl
  exact .E_OpFail (q := failQ) (k1 := []) (k2 := []) (T := unitT) (E' := unitT)
    (E := unitT) (body := .ret (.const .unit)) (κ := 0) rfl ⟨rfl,rfl,by intro cap h hf; cases hf⟩ rfl

def resumeQ : Closure := .mk cap (.resume (.loc 0) (.const .unit))

theorem drop_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run unitQ dropK usedμ) :=
  run_state hv (empty_builtin P B) (used_store P B σ) (unit_q (used_store P B σ).wf)
    (drop_cont P B σ) (unit_adequate σ) unit_closed
    (by intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial) (one_closed trivial)

theorem drop_pop (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run unitQ dropK usedμ) ∧
    Step P B σ (.run unitQ dropK usedμ) none (.run pureUnit [] usedμ) ∧
    StateTy P B σ (.run pureUnit [] usedμ) :=
  ⟨drop_typed P B σ hv,.E_Drop rfl rfl,pure_state hv (used_store P B σ) (one_closed trivial)⟩

theorem resume_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run resumeQ dropK contμ) := by
  have hq : ClosureTy P B contΨ [] none resumeQ unitT Eff.empty := by
    have hh := wrap (P := P) (B := B) (StoreTy.CaptureView.refl (cont_store P B σ).wf cap)
      (.C_ResumeL (l := 0) rfl (.V_Const (c := .unit) trivial) (show unitT.Declared P [] Γ0 from trivial))
      (done_ann (P := P) (Γ := Γ0) (a := unitT) ⟨trivial,trivial,trivial⟩)
    simpa [resumeQ,unitT] using hh
  apply run_state hv (empty_builtin P B) (cont_store P B σ) hq (drop_cont P B σ)
  · simp [resumeQ,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [resumeQ,cap,seven,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial
  · exact one_closed (by change failK.Closed; intro f hf; have he := List.mem_singleton.mp hf; subst f; exact fail_frame_closed)

theorem resume_after (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run pureUnit (failK ++ dropK) usedμ) := by
  have hq : ClosureTy P B contΨ [] none pureUnit unitT (Eff.singleFail unitT) := by
    apply ClosureTy.pure (.C_Eff (.C_Return (.V_Const (c := .unit) trivial)) ?_) ?_ (by intros; contradiction) (used_store P B σ).wf
    · exact Eff.Sub.covers ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx)⟩
    · exact ⟨⟨trivial,⟨trivial,trivial⟩,rfl⟩,⟨trivial,⟨trivial,trivial⟩⟩,⟨trivial,⟨trivial,trivial⟩⟩⟩
  have hk : ContTy P B σ contΨ none (Eff.singleFail unitT) (failK ++ dropK) unitT unitT Eff.empty none := by
    refine .K_Handle_Fail (ec := Eff.empty) (rest := Eff.empty) (E := unitT)
      (drop_cont P B σ) (Eff.Covers.refl [] [] _) ⟨rfl,by intro i hi; cases hi⟩
      (capture_typed P B _) (failure_clause P B _) rfl (close_base _ _) (close_empty _) (close_base _ _)
      (by intros; contradiction) (Eff.Covers.refl [] [] _) ⟨trivial,trivial,trivial⟩ ?_
    simp [Frame.Adequate,failH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,adequateClauses,Comp.Adequate,Val.Adequate]
  apply run_state hv (empty_builtin P B) (used_store P B σ) hq hk (pure_adequate σ) pure_closed
  · intro f hf; simp [failK,dropK] at hf
    rcases hf with rfl | rfl
    · exact fail_frame_closed
    · trivial
  · exact one_closed trivial

theorem resume_transition (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run resumeQ dropK contμ) ∧
    Step P B σ (.run resumeQ dropK contμ) none (.run pureUnit (failK ++ dropK) usedμ) ∧
    StateTy P B σ (.run pureUnit (failK ++ dropK) usedμ) :=
  by
  have hm : contμ.set 0 .used = usedμ := by
    funext l; by_cases hl : l = 0 <;> simp [contμ,usedμ,Store.set,hl]
  refine ⟨resume_before P B σ hv,?_,resume_after P B σ hv⟩
  rw [←hm]
  exact .E_Resume (κ := 0) (v := .const .unit) (k' := failK) rfl rfl

/-- Failの枠を通常のretが通過する経路も、同じStoreTyの下で型付く。 -/
theorem fail_handle_pop (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run pureUnit (failK ++ dropK) usedμ) ∧
    Step P B σ (.run pureUnit (failK ++ dropK) usedμ) none (.run pureUnit dropK usedμ) ∧
    StateTy P B σ (.run pureUnit dropK usedμ) := by
  refine ⟨resume_after P B σ hv,.E_HRet rfl,?_⟩
  exact run_state hv (empty_builtin P B) (used_store P B σ)
    (pure_unit (used_store P B σ).wf (by intros; contradiction)) (drop_cont P B σ)
    (pure_adequate σ) pure_closed
    (by intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial) (one_closed trivial)

def handleUnit : Closure := .mk cap (.handle (.ret (.const .unit)) [])
def emptyHandleK : Cont := [.handleF cap []]

theorem empty_handle_cont (P : Program) (B : Builtins) (σ : PathEnv) :
    ContTy P B σ StoreTy.empty none Eff.empty emptyHandleK unitT unitT Eff.empty none := by
  refine .K_Handle (ec := Eff.empty) (eb := Eff.empty) (Rs := none) (ts := unitT) (ecs := Eff.empty) (ebs := Eff.empty)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩) (Eff.Covers.refl [] [] _) ?_
    (capture_typed P B _) .nil rfl (close_base _ _) (close_empty _) (close_empty _)
    (done_ann (P := P) (Γ := Γ0) (a := unitT) ⟨trivial,trivial,trivial⟩)
    trivial (by intros; contradiction) ⟨trivial,trivial,trivial⟩ ?_
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx)⟩
  · simp [Frame.Adequate,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,adequateClauses,Val.Adequate]

theorem handle_push (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    Step P B σ (.run handleUnit [] Store.empty) none (.run unitQ emptyHandleK Store.empty) ∧
    StateTy P B σ (.run unitQ emptyHandleK Store.empty) := by
  refine ⟨.E_Handle rfl,?_⟩
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ) (unit_q StoreTy.WF.empty)
    (empty_handle_cont P B σ) (unit_adequate σ) unit_closed
  · intro f hf; have he := List.mem_singleton.mp hf; subst f
    exact ⟨unit_closed.1,trivial⟩
  · intro l c hc; cases hc

def forceSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["x"]
  params := [.lazy unitT]
  ret := unitT
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .force
  opEff := none

def refNewSig : PrimSig := {forceSig with
  params := [scalar]
  ret := .reference scalar
  eff := Eff.single stateEff
  kind := .refNew}

def testB : Builtins := {emptyBuiltins with
  sig := fun b => if b = "force" then some forceSig else if b = "new" then some refNewSig else none
  effects := fun _ => some []
  isResource := fun _ => true
  releaseResponse := fun _ _ => True}

theorem force_range_tel : Tel.instR [] forceSig.tel = .param "x" (.lazy unitT) (.done unitT Eff.empty) := by
  simp [forceSig,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms_rangeAt,instAtoms_nil,Tel.norm,Ty.norm,Eff.norm,unitT,Eff.empty]

theorem force_inst_tel : instantiatedTel (Tel.instR [] forceSig.tel) [] [] =
    .param "x" (.lazy unitT) (.done unitT Eff.empty) := by
  rw [force_range_tel]
  simp [instantiatedTel,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Eff.norm,
    typeEnvAt,SubstEnv.up,instAtoms_nil,substAtoms_nil,rowFails,rawBindTys,unitT,Eff.empty]

theorem arguments_done_unit (v : Val) : Tel.bind (Tel.argumentsEnv v) (.done unitT Eff.empty) = .done unitT Eff.empty := by
  rw [←valEnv_openValue,Tel.bind_done]
  change Tel.done unitT (substEffValues (openValue v) Eff.empty) = Tel.done unitT Eff.empty
  rw [substEffValues_empty]

theorem force_prim (P : Program) (Ψ : StoreTy) (Γ : Ctx) :
    HasTypeV P testB Ψ [] Γ [] (.prim "force" [] [] [])
      (.dependentFn (.param "x" (.lazy unitT) (.done unitT Eff.empty))) := by
  rw [←force_inst_tel]
  refine .V_Prim (P := P) (B := testB) (b := "force") (s := forceSig) rfl ?_ ⟨rfl,by decide⟩ ?_ ?_
  · refine ⟨rfl,?_,?_,Or.inl ?_⟩
    · intro i r k hr; cases hr
    · intro r hr; cases hr
    · intro r hr; cases hr
  · refine ⟨rfl,trivial,?_,rfl,?_,?_,?_,?_⟩
    · intro t ht; cases ht
    · intro e he; cases he
    · exact ⟨(by intro i hi; cases hi),trivial⟩
    · intro i hi; simp [forceSig,Qsig,QTys,QTy,QEff,Qempty,Eff.empty,unitT] at hi
    · intro i hi; simp [forceSig,Qsig,QTys,QTy,QEff,Qempty,Eff.empty,unitT] at hi
  · refine ⟨?_,by simp [TypeAnnotations],?_,by simp [RowAnnotations],?_⟩
    · rw [force_range_tel]; exact ⟨trivial,trivial,trivial,rfl⟩
    · exact ⟨rfl,[],rfl,by intro i t k ht; cases ht⟩
    · rw [force_inst_tel]; exact ⟨⟨trivial,trivial,trivial,rfl⟩,⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩⟩

def thunkΨ : StoreTy := oneTy (.lazy unitT)
def thunkμ : Store := Store.empty.set 0 (.thunk unitQ)
def doneμ : Store := Store.empty.set 0 (.done (.const .unit))
def forceQ : Closure := Closure.pure (.app (.prim "force" [] [] []) [.loc 0])

theorem thunk_store (P : Program) (σ : PathEnv) : StoreOk P testB σ thunkΨ thunkμ := by
  apply one_store (x := .lazy unitT) (c := .thunk unitQ) trivial trivial
  have hw : (hideBuilders thunkΨ).WF := by
    have he : hideBuilders thunkΨ = thunkΨ := by
      funext l; by_cases hl : l = 0 <;> simp [hideBuilders,thunkΨ,oneTy,hl]
    rw [he]; exact one_wf (x := .lazy unitT) trivial
  exact ⟨unitT,rfl,unit_q hw,unit_adequate σ⟩

theorem done_store (P : Program) (σ : PathEnv) : StoreOk P testB σ thunkΨ doneμ :=
  one_store trivial trivial ⟨unitT,rfl,.V_Const trivial,trivial⟩

theorem force_before (P : Program) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P testB σ (.run forceQ [] thunkμ) := by
  have hc : HasTypeC P testB thunkΨ [] [] [] none (.app (.prim "force" [] [] []) [.loc 0]) unitT Eff.empty :=
    .C_DependentApp (force_prim P _ _) (.param ⟨trivial,trivial,trivial⟩ (.V_LocLazy rfl trivial)
      (by rw [arguments_done_unit]; exact .done (done_ann (P := P) (Γ := []) (a := unitT) ⟨trivial,trivial,trivial⟩)))
  apply run_state hv (empty_builtin P testB) (thunk_store P σ)
    (ClosureTy.pure hc (done_ann ⟨trivial,trivial,trivial⟩) (by intros; contradiction) (thunk_store P σ).wf)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [forceQ,Closure.pure,Capture.empty,Closure.Adequate,Capture.Adequate,Capture.values,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [forceQ,Closure.pure,Capture.empty,Closure.ClosedAt,Capture.Closed,Capture.values,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList]
  · intro f hf; cases hf
  · exact one_closed unit_closed

theorem update_typed (P : Program) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P testB σ (.run unitQ [.update 0] thunkμ) :=
  run_state hv (empty_builtin P testB) (thunk_store P σ) (unit_q (thunk_store P σ).wf)
    (.K_Update rfl (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)) (unit_adequate σ) unit_closed
    (by intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial) (one_closed unit_closed)

theorem update_push (P : Program) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P testB σ (.run forceQ [] thunkμ) ∧
    Step P testB σ (.run forceQ [] thunkμ) none (.run unitQ [.update 0] thunkμ) ∧
    StateTy P testB σ (.run unitQ [.update 0] thunkμ) :=
  ⟨force_before P σ hv,.E_Force (q := forceQ) (b := "force") (ts := []) (es := []) (rs := [])
    (s := forceSig) rfl rfl rfl rfl,update_typed P σ hv⟩

theorem update_pop (P : Program) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P testB σ (.run unitQ [.update 0] thunkμ) ∧
    Step P testB σ (.run unitQ [.update 0] thunkμ) none (.run pureUnit [] doneμ) ∧
    StateTy P testB σ (.run pureUnit [] doneμ) := by
  have hm : thunkμ.set 0 (.done (.const .unit)) = doneμ := by
    funext l; by_cases hl : l = 0 <;> simp [thunkμ,doneμ,Store.set,hl]
  refine ⟨update_typed P σ hv,?_,pure_state hv (done_store P σ) (one_closed trivial)⟩
  rw [←hm]; exact .E_Update rfl

def stateE : Eff := Eff.single stateEff
def resource : Val := .const (.opaque "Resource" 0)
def useQ : Closure := .mk cap (.use resource (.ret (.const .unit)))
def releaseK : Cont := [.release resource]

theorem state_builtin {P} (hp : P.effects stateEff = none) : BuiltinOnly P testB stateE := by
  refine ⟨rfl,?_⟩
  intro a ha
  have he : a = .name stateEff (.fixed .top) := of_decide_eq_true ha
  subst a
  exact ⟨stateEff,.fixed .top,rfl,hp,rfl⟩

theorem state_sub : Eff.Sub Eff.empty stateE :=
  ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx)⟩

theorem state_unit {P Ψ} (hw : Ψ.WF) : ClosureTy P testB Ψ [] none unitQ unitT stateE := by
  have he : cap.closeEff stateE = stateE := Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := stateE) trivial rfl _
  have hh := wrap (P := P) (B := testB) (StoreTy.CaptureView.refl hw cap)
    (.C_Eff (.C_Return (.V_Const (c := .unit) trivial)) state_sub.covers)
    (show Ty.Annotation P [] Γ0 (.dependentFn (.done unitT stateE)) from ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩)
  simpa [unitQ,unitT,Const.type,he] using hh

theorem release_cont (P : Program) (σ : PathEnv) :
    ContTy P testB σ StoreTy.empty none stateE releaseK unitT unitT stateE none :=
  .K_Release (.V_Const ⟨rfl,rfl⟩) trivial rfl rfl (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)

theorem release_typed {P σ} (hv : σ.Valid) (hp : P.effects stateEff = none) :
    StateTy P testB σ (.run unitQ releaseK Store.empty) :=
  run_state hv (state_builtin hp) (StoreOk.empty P testB σ) (state_unit StoreTy.WF.empty)
    (release_cont P σ) (unit_adequate σ) unit_closed
    (by intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial)
    (by intro l c hc; cases hc)

theorem use_typed {P σ} (hv : σ.Valid) (hp : P.effects stateEff = none) :
    StateTy P testB σ (.run useQ [] Store.empty) := by
  have he : cap.closeEff stateE = stateE := Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := stateE) trivial rfl _
  have hc : HasTypeC P testB StoreTy.empty [] Γ0 [] none (.use resource (.ret (.const .unit))) unitT stateE :=
    .C_Use (.V_Const ⟨rfl,rfl⟩) rfl (.C_Eff (.C_Return (.V_Const trivial)) state_sub.covers) rfl
  have hq := wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) hc
    (show Ty.Annotation P [] Γ0 (.dependentFn (.done unitT stateE)) from ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩)
  apply run_state hv (state_builtin hp) (StoreOk.empty P testB σ) (by simpa [useQ,unitT,he] using hq)
    (.K_Empty (subRefl stateE) (a := unitT) ⟨trivial,trivial,trivial⟩)
  · simp [useQ,resource,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [useQ,resource,cap,seven,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem release_push {P σ} (hv : σ.Valid) (hp : P.effects stateEff = none) :
    StateTy P testB σ (.run useQ [] Store.empty) ∧
    Step P testB σ (.run useQ [] Store.empty) none (.run unitQ releaseK Store.empty) ∧
    StateTy P testB σ (.run unitQ releaseK Store.empty) :=
  ⟨use_typed hv hp,.E_Use rfl,release_typed hv hp⟩

theorem release_pop {P σ} (hv : σ.Valid) (hp : P.effects stateEff = none) :
    StateTy P testB σ (.run unitQ releaseK Store.empty) ∧
    Step P testB σ (.run unitQ releaseK Store.empty) (some (.release resource none)) (.run pureUnit [] Store.empty) ∧
    StateTy P testB σ (.run pureUnit [] Store.empty) :=
  ⟨release_typed hv hp,.E_Release rfl trivial,pure_state hv (StoreOk.empty P testB σ) (by intro l c hc; cases hc)⟩

def lazyBody : Closure := .mk cap (.ret (.var 0))
def lazyQ : Closure := .mk cap (.lazyC (.ret (.var 0)))
def dependentLazyΨ : StoreTy := oneTy (.lazy refTy)
def dependentLazyμ : Store := Store.empty.set 0 (.thunk lazyBody)
def lazyResult : Closure := Closure.pure (.ret (.loc 0))

theorem source_refined_var (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] Γ0 [] (.var 0) (R 0) := by
  refine .V_Refine (.V_Var (i := 0) (a := scalar) rfl (by simp [Ty.Ordinary,scalar])) rfl rfl R0_sorted.2 ?_ .eq_refl trivial (R0_declared P).2
  simp [R,Γ0,Pred.WF,Pred.VarsIn,Term.VarsIn]

theorem lazy_body {P B Ψ} (hw : Ψ.WF) : ClosureTy P B Ψ [] none lazyBody refTy Eff.empty := by
  simpa [lazyBody,refTy] using wrap (StoreTy.CaptureView.refl hw cap)
    (.C_Return (source_refined_var P B Ψ))
    (done_ann (P := P) (Γ := Γ0) (a := R 0) ⟨(contents0_ann P).wf,R0_sorted,R0_declared P⟩)

theorem dependent_lazy_store (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ dependentLazyΨ dependentLazyμ := by
  have hw : (hideBuilders dependentLazyΨ).WF := by
    have he : hideBuilders dependentLazyΨ = dependentLazyΨ := by
      funext l; by_cases hl : l = 0 <;> simp [hideBuilders,dependentLazyΨ,oneTy,hl]
    rw [he]; exact one_wf (x := .lazy refTy) (ref_ann P).wf
  apply one_store (x := .lazy refTy) (c := .thunk lazyBody) (ref_ann P).wf (ref_ann P).declared
  refine ⟨refTy,rfl,lazy_body hw,?_⟩
  simp [lazyBody,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]

theorem lazy_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run lazyQ [] Store.empty) := by
  have hc : HasTypeC P B StoreTy.empty [] Γ0 [] none (.lazyC (.ret (.var 0))) (.lazy (R 0)) Eff.empty :=
    .C_Lazy (.C_Return (source_refined_var P B _)) ⟨(contents0_ann P).wf,R0_sorted,R0_declared P⟩
  have hq : ClosureTy P B StoreTy.empty [] none lazyQ (.lazy refTy) Eff.empty := by
    have hh := wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) hc
      (done_ann ⟨(contents0_ann P).wf,R0_sorted,R0_declared P⟩)
    simpa [lazyQ,refTy,Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm] using hh
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ) hq
    (.K_Empty (subRefl _) ⟨(ref_ann P).wf,(ref_ann P).sorted,(ref_ann P).declared⟩)
  · simp [lazyQ,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [lazyQ,cap,seven,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem lazy_after (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run lazyResult [] dependentLazyμ) := by
  have ha : Ty.Annotation P [] [] (.lazy refTy) := ⟨(ref_ann P).wf,(ref_ann P).sorted,(ref_ann P).declared⟩
  apply run_state hv (empty_builtin P B) (dependent_lazy_store P B σ)
    (ClosureTy.pure (.C_Return (.V_LocLazy (l := 0) rfl (ref_ann P).declared))
      (done_ann ha) (by intros; contradiction) (dependent_lazy_store P B σ).wf)
    (.K_Empty (subRefl _) ha)
  · simp [lazyResult,Closure.pure,Capture.empty,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [lazyResult,Closure.pure,Capture.empty,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; cases hf
  · apply one_closed
    change lazyBody.ClosedAt 0
    simp [lazyBody,cap,seven,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]

theorem lazy_new (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run lazyQ [] Store.empty) ∧
    Step P B σ (.run lazyQ [] Store.empty) none (.run lazyResult [] dependentLazyμ) ∧
    StateTy P B σ (.run lazyResult [] dependentLazyμ) :=
  ⟨lazy_before P B σ hv,.E_Lazy rfl rfl,lazy_after P B σ hv⟩

theorem new_range_tel : Tel.instR [] refNewSig.tel = .param "x" scalar (.done (.reference scalar) stateE) := by
  simp [refNewSig,forceSig,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms_rangeAt,instAtoms_nil,Tel.norm,Ty.norm,Eff.norm,scalar,stateE,Eff.single]

theorem new_inst_tel : instantiatedTel (Tel.instR [] refNewSig.tel) [] [] =
    .param "x" scalar (.done (.reference scalar) stateE) := by
  rw [new_range_tel]
  simp [instantiatedTel,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Eff.norm,
    typeEnvAt,SubstEnv.up,instAtoms_nil,substAtoms_nil,rowFails,rawBindTys,scalar,stateE,Eff.single]

theorem arguments_done_ref_state (v : Val) :
    Tel.bind (Tel.argumentsEnv v) (.done (.reference scalar) stateE) = .done (.reference scalar) stateE := by
  rw [←valEnv_openValue,Tel.bind_done]
  exact congrArg (Tel.done (.reference scalar))
    (Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := stateE) trivial rfl _)

theorem new_prim (P : Program) (Ψ : StoreTy) (Γ : Ctx) :
    HasTypeV P testB Ψ [] Γ [] (.prim "new" [] [] [])
      (.dependentFn (.param "x" scalar (.done (.reference scalar) stateE))) := by
  rw [←new_inst_tel]
  refine .V_Prim (P := P) (B := testB) (b := "new") (s := refNewSig) rfl ?_ ⟨rfl,by decide⟩ ?_ ?_
  · refine ⟨rfl,?_,?_,Or.inl ?_⟩
    · intro i r k hr; cases hr
    · intro r hr; cases hr
    · intro r hr; cases hr
  · refine ⟨rfl,trivial,?_,rfl,?_,?_,?_,?_⟩
    · intro t ht; cases ht
    · intro e he; cases he
    · exact ⟨(by intro i hi; cases hi),trivial⟩
    · intro i hi; simp [refNewSig,forceSig,Qsig,QTys,QTy,QEff,Qempty,Eff.single,scalar] at hi
    · intro i hi; simp [refNewSig,forceSig,Qsig,QTys,QTy,QEff,Qempty,Eff.single,scalar] at hi
  · refine ⟨?_,by simp [TypeAnnotations],?_,by simp [RowAnnotations],?_⟩
    · rw [new_range_tel]; exact ⟨trivial,trivial,trivial,rfl⟩
    · exact ⟨rfl,[],rfl,by intro i t k ht; cases ht⟩
    · rw [new_inst_tel]; exact ⟨⟨trivial,trivial,trivial,rfl⟩,⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩⟩

def newQ : Closure := .mk cap (.app (.prim "new" [] [] []) [.var 0])
def scalarRefΨ : StoreTy := oneTy (.ref scalar)
def scalarRefμ : Store := Store.empty.set 0 (.val seven)

theorem scalar_ref_store (P : Program) (σ : PathEnv) : StoreOk P testB σ scalarRefΨ scalarRefμ :=
  one_store trivial trivial ⟨scalar,rfl,.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide),trivial⟩

theorem ref_new_before {P σ} (hv : σ.Valid) (hp : P.effects stateEff = none) :
    StateTy P testB σ (.run newQ [] Store.empty) := by
  have hc : HasTypeC P testB StoreTy.empty [] Γ0 [] none (.app (.prim "new" [] [] []) [.var 0]) (.reference scalar) stateE :=
    .C_DependentApp (new_prim P _ _)
      (.param (scalar_ann P [] Γ0) (.V_Var rfl (by simp [scalar,Ty.Ordinary]))
        (by rw [arguments_done_ref_state]; exact .done ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩))
  have hce : cap.closeEff stateE = stateE := Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := stateE) trivial rfl _
  have hca : cap.closeTy (.reference scalar) = .reference scalar := Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := .reference scalar) trivial _
  have hq : ClosureTy P testB StoreTy.empty [] none newQ (.reference scalar) stateE := by
    have hh := wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) hc
      (show Ty.Annotation P [] Γ0 (.dependentFn (.done (.reference scalar) stateE)) from
        ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩)
    simpa [newQ,hce,hca] using hh
  apply run_state hv (state_builtin hp) (StoreOk.empty P testB σ) hq
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [newQ,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [newQ,cap,seven,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem ref_new_after (P : Program) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P testB σ (.run lazyResult [] scalarRefμ) := by
  apply run_state hv (empty_builtin P testB) (scalar_ref_store P σ)
    (ClosureTy.pure (.C_Return (.V_LocRef (l := 0) rfl trivial))
      (done_ann (a := .reference scalar) ⟨trivial,trivial,trivial⟩) (by intros; contradiction) (scalar_ref_store P σ).wf)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [lazyResult,Closure.pure,Capture.empty,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [lazyResult,Closure.pure,Capture.empty,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; cases hf
  · exact one_closed trivial

theorem ref_new {P σ} (hv : σ.Valid) (hp : P.effects stateEff = none) :
    StateTy P testB σ (.run newQ [] Store.empty) ∧
    Step P testB σ (.run newQ [] Store.empty) none (.run lazyResult [] scalarRefμ) ∧
    StateTy P testB σ (.run lazyResult [] scalarRefμ) :=
  ⟨ref_new_before hv hp,.E_RefNew (q := newQ) (b := "new") (ts := []) (es := []) (rs := [])
    (s := refNewSig) rfl rfl rfl rfl,ref_new_after P σ hv⟩

theorem let_push (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ s0 ∧ Step P B σ s0 none s1 ∧ StateTy P B σ s1 :=
  ⟨s0_typed P B σ hv,s0_step P B σ,s1_typed P B σ hv⟩

theorem builder_new (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ s2 ∧ Step P B σ s2 none s3 ∧ StateTy P B σ s3 :=
  ⟨s2_typed P B σ hv,s2_step P B σ,s3_typed P B σ hv⟩

theorem let_unit_input (P : Program) (B : Builtins) :
    ClosureTy P B StoreTy.empty [unitT] none pureUnit unitT Eff.empty := by
  have hh := ClosureTy.mk (ss := [unitT]) (Rs := none) (a := unitT) (e := Eff.empty)
    (CaptureOk.empty P B StoreTy.empty none) (StoreTy.CaptureView.refl StoreTy.WF.empty Capture.empty 1)
    (.typed (.C_Return (.V_Const (c := .unit) trivial)) (Or.inl StoreTy.WF.empty))
    (LocalCtx.NoBuilders.empty.localExtend 1)
    (by intro a ha; have he := List.mem_singleton.mp ha; subst a; exact ⟨trivial,trivial,trivial⟩)
    (by intro a ha; simp only [List.map_cons,List.map_nil,unitT,close_base,List.mem_singleton] at ha; subst a; exact ⟨trivial,trivial,trivial⟩)
    rfl
    (by simpa only [unitT,close_base_at] using (show Ty.Annotation P [] (bindParams [] ([unitT].map Capture.empty.closeTy)) unitT from ⟨trivial,trivial,trivial⟩))
    (by simpa only [unitT,close_base_at,close_empty_at] using (done_ann (P := P) (Γ := bindParams [] ([unitT].map Capture.empty.closeTy)) (a := unitT) ⟨trivial,trivial,trivial⟩))
    (by intros; contradiction) (by intros; contradiction)
  simpa [pureUnit,Closure.pure,unitT] using hh

theorem let_return_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run pureUnit [.letF pureUnit] Store.empty) :=
  run_state hv (empty_builtin P B) (StoreOk.empty P B σ)
    (pure_unit StoreTy.WF.empty (by intros; contradiction))
    (.K_Let (c := unitT) (e1 := Eff.empty)
      (by simpa [unitT,Ty.shiftV,Eff.shiftV,renameEff,Eff.empty] using let_unit_input P B)
      (pure_adequate σ) ⟨trivial,trivial,trivial⟩ (subRefl _)
      (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)) (pure_adequate σ) pure_closed
    (by intro f hf; have he := List.mem_singleton.mp hf; subst f; exact ⟨pure_closed.1,trivial⟩)
    (by intro l c hc; cases hc)

theorem let_return_after (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run (pureUnit.apply [.const .unit]) [] Store.empty) := by
  have hg : ∀ ov ∈ (Capture.empty.extend (.const .unit)).values, ∀ v, ov = some v → v.Ground := by
    intro ov ho v he; have h : ov = some (.const .unit) := List.mem_singleton.mp ho
    have hv : v = .const .unit := Option.some.inj (he.symm.trans h)
    subst v; trivial
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ) (masked_unit StoreTy.WF.empty hg)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [pureUnit,Closure.pure,Closure.apply,Capture.empty,Capture.extendMany,Capture.extend,Capture.values,
      Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [pureUnit,Closure.pure,Closure.apply,Capture.empty,Capture.extendMany,Capture.extend,Capture.values,
      Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem let_pop (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run pureUnit [.letF pureUnit] Store.empty) ∧
    Step P B σ (.run pureUnit [.letF pureUnit] Store.empty) none (.run (pureUnit.apply [.const .unit]) [] Store.empty) ∧
    StateTy P B σ (.run (pureUnit.apply [.const .unit]) [] Store.empty) :=
  ⟨let_return_before P B σ hv,.E_Return rfl,let_return_after P B σ hv⟩

def nestedBody : Comp := .letIn (.ret (.const .unit)) (.builderOp (.list (R 1)) .length (.loc 0) [])
def nestedBoundBody : Comp := .letIn (.ret (.const .unit)) (.builderOp (.list (R 2)) .length (.bound 1) [])
def nestedBuilderQ : Closure := .mk cap (.builderLet kind0 nestedBoundBody)
def nestedAfterQ : Closure := .mk cap nestedBody

theorem nested_R_ann (P : Program) : Ty.Annotation P [] (Γ0.extendNone |>.extend unitT) (R 2) :=
  ⟨by simp [Γ0,Ctx.extendNone,Ctx.extend,unitT,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core],
   ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,
   ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩⟩

theorem nested_source_typed (P : Program) (B : Builtins) :
    HasTypeC P B StoreTy.empty [] Γ0 [] none (.builderLet kind0 nestedBoundBody) (.base .integer) Eff.empty := by
  refine .C_BuilderLet (contents0_ann P) (kinded P _ (R_kind P 0)) ?_ trivial
  refine .C_Let (a := unitT) (.C_Return (.V_Const trivial)) ?_ trivial
  exact .C_BuilderOp ⟨(nested_R_ann P).wf,(nested_R_ann P).sorted,(nested_R_ann P).declared⟩ (kinded P _ (R_kind P 2)) (.bound rfl) .nil

theorem nested_open_typed (P : Program) (B : Builtins) :
    OpenCodeTy P B sourceBuilder Qempty [] Γ0 [] none nestedBody (.base .integer) Eff.empty [] := by
  refine .letIn (a := unitT) (.typed (.C_Return (.V_Const trivial)) (Or.inr (by simp [Comp.BuilderLocFree]))) ?_ trivial
  have ha : Ty.Annotation P [] (Γ0.extend unitT) (R 1) :=
    ⟨by simp [Γ0,Ctx.extend,unitT,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core],
     ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,
     ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩⟩
  exact .builderOp ⟨ha.wf,ha.sorted,ha.declared⟩ (kinded P _ (R_kind P 1)) (.loc rfl) .nil

theorem nested_subst : nestedBoundBody.subst builderValueSubst (builderLocalSubst 0) = nestedBody := by
  rfl

theorem nested_builder_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run nestedBuilderQ [] Store.empty) := by
  have hq : ClosureTy P B StoreTy.empty [] none nestedBuilderQ (.base .integer) Eff.empty := by
    simpa [nestedBuilderQ] using wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) (nested_source_typed P B)
      (done_ann (P := P) (Γ := Γ0) (a := .base .integer) ⟨trivial,trivial,trivial⟩) (Or.inl StoreTy.WF.empty)
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ) hq
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [nestedBuilderQ,nestedBoundBody,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · refine ⟨unit_closed.1,?_,?_⟩
    · exact (contents0_ann P).wf
    · refine ⟨trivial,?_⟩
      refine ⟨?_,?_,trivial⟩
      · exact (nested_R_ann P).wf
      · change 1 < 3; omega
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem nested_builder_after (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run nestedAfterQ [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) := by
  have hq : ClosureTy P B runtimeBuilder [] none nestedAfterQ (.base .integer) Eff.empty := by
    simpa [nestedAfterQ] using wrap_open builder_view (nested_open_typed P B)
      (done_ann (P := P) (Γ := Γ0) (a := .base .integer) ⟨trivial,trivial,trivial⟩)
  apply run_state hv (empty_builtin P B) (builder_store P B σ) hq (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [nestedAfterQ,nestedBody,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · refine ⟨unit_closed.1,trivial,?_,trivial,trivial⟩
    change (R 1).WF 0 0 2
    simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · intro f hf; cases hf
  · exact one_closed trivial

theorem nested_builder_new (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run nestedBuilderQ [] Store.empty) ∧
    Step P B σ (.run nestedBuilderQ [] Store.empty) none
      (.run nestedAfterQ [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) ∧
    StateTy P B σ (.run nestedAfterQ [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) := by
  refine ⟨nested_builder_before P B σ hv,?_,nested_builder_after P B σ hv⟩
  have hh := Step.E_BuilderNew (P := P) (B := B) (σ := σ) (q := nestedBuilderQ)
    (kind := substKind cap.env kind0) (body := nestedBoundBody) (k := []) (μ := Store.empty) (l := 0) rfl rfl
  simpa only [nestedBuilderQ,Closure.capture,nested_subst,nestedAfterQ] using hh

def unitΓ : Ctx := Γ0.extend unitT
def unitCap : Capture := cap.extend (.const .unit)
def inputBuilderQ : Closure := .mk cap (.builderOp (.list (R 1)) .length (.loc 0) [])
def inputBuilderResult : Closure := .mk unitCap (.builderOp (.list (R 1)) .length (.loc 0) [])

theorem R_unit_ann (P : Program) : Ty.Annotation P [] unitΓ (R 1) :=
  ⟨by simp [unitΓ,Γ0,Ctx.extend,unitT,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core],
   ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,
   ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩⟩

theorem unit_capture (P : Program) (B : Builtins) : CaptureOk P B runtimeBuilder none unitΓ [] unitCap := by
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi
    cases i with
    | zero => cases hi; trivial
    | succ i => cases i with
      | zero => cases hi; trivial
      | succ i => simp [unitΓ,Γ0,Ctx.extend] at hi
  · intro i a hi
    cases i with
    | zero => exact ⟨.const .unit,rfl⟩
    | succ i => cases i with
      | zero => exact ⟨seven,rfl⟩
      | succ i => simp [unitΓ,Γ0,Ctx.extend] at hi
  · intro i a hi
    cases i with
    | zero => cases hi; exact ⟨trivial,trivial⟩
    | succ i => cases i with
      | zero => cases hi; exact ⟨trivial,trivial⟩
      | succ i => simp [unitΓ,Γ0,Ctx.extend] at hi
  · intro p hp; cases hp
  · intro ov ho v he
    simp [unitCap,cap,seven,Capture.extend,Capture.values] at ho
    rcases ho with rfl | rfl <;> cases he <;> trivial
  · intro i a hi
    cases i with
    | zero => cases hi; exact .ordinary (by simp [unitT,Ty.Ordinary,Ty.shiftV,renameTy]) (.V_Const trivial)
    | succ i => cases i with
      | zero => cases hi; exact .ordinary (by simp [scalar,Ty.shiftV,Ty.Ordinary,renameTy]) (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide))
      | succ i => simp [unitΓ,Γ0,Ctx.extend] at hi
  · intro p hp; simp [unitΓ,Γ0,Ctx.extend,Ctx.facts,scalar,unitT,Ty.shiftV,Ty.assume] at hp

theorem input_builder_closure (P : Program) (B : Builtins) (σ : PathEnv) :
    ClosureTy P B runtimeBuilder [unitT] none inputBuilderQ (.base .integer) Eff.empty := by
  have ha := R_unit_ann P
  have hh := ClosureTy.mk (ss := [unitT]) (Rs := none) (a := .base .integer) (e := Eff.empty)
    (capture_typed P B runtimeBuilder) (builder_view.shift (builder_store P B σ).wf)
    (.builderOp (kind := .list (R 1)) (op := .length) (ref := .loc 0) (args := []) ⟨ha.wf,ha.sorted,ha.declared⟩ (kinded P _ (R_kind P 1)) (.loc rfl) .nil)
    (LocalCtx.NoBuilders.empty.localExtend 1)
    (by intro a hi; have he := List.mem_singleton.mp hi; subst a; exact ⟨trivial,trivial,trivial⟩)
    (by intro a hi; simp only [List.map_cons,List.map_nil,unitT,close_base,List.mem_singleton] at hi; subst a; exact ⟨trivial,trivial,trivial⟩)
    rfl ⟨trivial,trivial,trivial⟩
    (by simpa only [close_base_at,close_empty_at] using (done_ann (P := P)
      (Γ := bindParams [] ([unitT].map cap.closeTy)) (a := .base .integer) ⟨trivial,trivial,trivial⟩))
    (by intros; contradiction) (by intros; contradiction)
  simpa [unitT,inputBuilderQ] using hh

theorem input_builder_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run unitQ [.letF inputBuilderQ] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) := by
  apply run_state hv (empty_builtin P B) (builder_store P B σ) (unit_q (builder_store P B σ).wf)
    (.K_Let (c := .base .integer) (e1 := Eff.empty)
      (by simpa [Ty.shiftV,Eff.shiftV,renameEff,Eff.empty] using input_builder_closure P B σ)
      (by simp [inputBuilderQ,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals])
      ⟨trivial,trivial,trivial⟩ (subRefl _) (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩))
    (unit_adequate σ) unit_closed
  · intro f hf; have he := List.mem_singleton.mp hf; subst f
    refine ⟨unit_closed.1,(R_unit_ann P).wf,trivial,trivial⟩
  · exact one_closed trivial

theorem input_builder_after (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run inputBuilderResult [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) := by
  have hvw : StoreTy.CaptureView unitCap (sourceBuilder.shiftBuilders 1) runtimeBuilder := by
    intro l x hx; by_cases hl : l = 0
    · subst l; simp [StoreTy.shiftBuilders,sourceBuilder] at hx; subst x; rfl
    · simp [StoreTy.shiftBuilders,sourceBuilder,hl] at hx
  have ha := R_unit_ann P
  have hq : ClosureTy P B runtimeBuilder [] none inputBuilderResult (.base .integer) Eff.empty := by
    have hh := ClosureTy.capture_open (Rs := none) (unit_capture P B) hvw
      (.builderOp (kind := .list (R 1)) (op := .length) (ref := .loc 0) (args := []) ⟨ha.wf,ha.sorted,ha.declared⟩ (kinded P _ (R_kind P 1)) (.loc rfl) .nil)
      LocalCtx.NoBuilders.empty (done_ann (P := P) (Γ := unitΓ) (a := .base .integer) ⟨trivial,trivial,trivial⟩)
      rfl (by intros; contradiction)
    simpa [inputBuilderResult,BuilderOp.resultType] using hh
  apply run_state hv (empty_builtin P B) (builder_store P B σ) hq (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [inputBuilderResult,unitCap,cap,seven,Capture.values,Capture.extend,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · refine ⟨?_,(R_unit_ann P).wf,trivial,trivial⟩
    simp [unitCap,cap,seven,Capture.values,Capture.extend,Capture.Closed,captureSlotsClosed,Val.ClosedAt]
  · intro f hf; cases hf
  · exact one_closed trivial

theorem input_builder_return (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run unitQ [.letF inputBuilderQ] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) ∧
    Step P B σ (.run unitQ [.letF inputBuilderQ] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) none
      (.run inputBuilderResult [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) ∧
    StateTy P B σ (.run inputBuilderResult [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) :=
  ⟨input_builder_before P B σ hv,.E_Return rfl,input_builder_after P B σ hv⟩

theorem handle_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run handleUnit [] Store.empty) := by
  have hc : HasTypeC P B StoreTy.empty [] Γ0 [] none (.handle (.ret (.const .unit)) []) unitT Eff.empty :=
    .C_Handle (.C_Return (.V_Const trivial))
      ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx)⟩ .nil
  have hq : ClosureTy P B StoreTy.empty [] none handleUnit unitT Eff.empty := by
    simpa [handleUnit,unitT] using wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) hc
      (done_ann ⟨trivial,trivial,trivial⟩) (Or.inl StoreTy.WF.empty)
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ) hq
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [handleUnit,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateClauses]
  · simp [handleUnit,cap,seven,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Clause.ClosedList]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem handle_push_checked (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run handleUnit [] Store.empty) ∧
    Step P B σ (.run handleUnit [] Store.empty) none (.run unitQ emptyHandleK Store.empty) ∧
    StateTy P B σ (.run unitQ emptyHandleK Store.empty) :=
  ⟨handle_before P B σ hv,handle_push P B σ hv⟩

theorem fail_handle_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run handledQ [] Store.empty) := by
  have hc : HasTypeC P B StoreTy.empty [] Γ0 [] none (.handle raised failH) unitT Eff.empty := by
    have hh := HasTypeCQ.C_Handle_Fail (rest := Eff.empty) (ec := Eff.empty) (raise_typed P B StoreTy.empty)
      fail_sub ⟨rfl,by intro i hi; cases hi⟩ (failure_clause P B StoreTy.empty)
    exact hh
  have hq : ClosureTy P B StoreTy.empty [] none handledQ unitT Eff.empty := by
    simpa [handledQ,unitT] using wrap (StoreTy.CaptureView.refl StoreTy.WF.empty cap) hc
      (done_ann ⟨trivial,trivial,trivial⟩) (Or.inl StoreTy.WF.empty)
  apply run_state hv (empty_builtin P B) (StoreOk.empty P B σ) hq
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [handledQ,raised,failH,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateClauses,adequateVals]
  · simp [handledQ,raised,failH,cap,seven,unitT,Capture.values,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Clause.ClosedList,Ty.WF,Val.ClosedList]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem handle_fail_push (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run handledQ [] Store.empty) ∧
    Step P B σ (.run handledQ [] Store.empty) none (.run failQ failK Store.empty) ∧
    StateTy P B σ (.run failQ failK Store.empty) :=
  ⟨fail_handle_before P B σ hv,.E_Handle rfl,fail_before P B σ hv⟩

/-- 開いた場所の種類を固定したままHasTypeCQだけを使う案は、内側のletで失敗する。 -/
theorem old_builder_inv {P B Ψ Q C Γ Φ R0 c a e L} (h : HasTypeCQ P B Ψ Q C Γ Φ R0 c a e L) :
    ∀ kind, c = .builderOp kind .length (.loc 0) [] → Ψ 0 = some (.builder kind) := by
  match h with
  | .C_BuilderOp _ _ hr _ => intro kind he; cases he; cases hr with | loc hl => exact hl
  | .C_Sub hm .. | .C_Eff hm .. => intro kind he; exact old_builder_inv hm kind he
  | .C_BuilderLet .. | .C_App .. | .C_DependentApp .. | .C_Return .. | .C_Let .. | .C_If .. | .C_Match .. | .C_Lazy .. |
    .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => intro kind he; cases he

theorem old_nested_store_obstruction {P B Ψ Q C Γ Φ R0 c a e L} (h : HasTypeCQ P B Ψ Q C Γ Φ R0 c a e L) (hΨ : Ψ = sourceBuilder) :
    ∀ m, c = .letIn m (.builderOp (.list (R 1)) .length (.loc 0) []) → False := by
  match h with
  | .C_Let _ hn _ =>
    intro m he; cases he
    have hb := old_builder_inv hn (.list (R 1)) rfl
    rw [hΨ] at hb
    simp [sourceBuilder,kind0,R] at hb
  | .C_Sub hm .. | .C_Eff hm .. => intro m he; exact old_nested_store_obstruction hm hΨ m he
  | .C_BuilderOp .. | .C_BuilderLet .. | .C_App .. | .C_DependentApp .. | .C_Return .. | .C_If .. | .C_Match .. | .C_Lazy .. |
    .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => intro m he; cases he

def builderArms : List Arm := [.mk varAlt (some (.ret (.const (.boolean false))))
    (.builderOp (.list (R 1)) .length (.loc 0) []),
  .mk varAlt none (.builderOp (.list (R 1)) .length (.loc 0) [])]
def builderMatchQ : Closure := .mk cap (.match (.var 0) builderArms)
def builderMatchState : State := .matchRun seven cap builderArms 0 []
  (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))

theorem builder_arms (P : Program) (B : Builtins) :
    OpenArmsTy P B sourceBuilder Qempty [] Γ0 [] none builderArms scalar (.base .integer) Eff.empty [] := by
  have ha : Ty.Annotation P [] (Γ0.extend scalar) (R 1) :=
    ⟨by simp [Γ0,Ctx.extend,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core],
     ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,
     ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩⟩
  have hb : OpenCodeTy P B (sourceBuilder.shiftBuilders 1) Qempty [] (Γ0.extend scalar) [] none
      (.builderOp (.list (R 1)) .length (.loc 0) []) (.base .integer) Eff.empty [none] :=
    .builderOp ⟨ha.wf,ha.sorted,ha.declared⟩ (kinded P _ (R_kind P 1)) (.loc rfl) .nil
  exact .guarded (var_alts P _) (.typed (.C_Return (.V_Const trivial)) (Or.inr (by simp [Comp.BuilderLocFree]))) hb
    (.plain (var_alts P _) hb (.nil ⟨trivial,trivial,trivial⟩))

theorem builder_match_closure (P : Program) (B : Builtins) :
    ClosureTy P B runtimeBuilder [] none builderMatchQ (.base .integer) Eff.empty := by
  have hx : Exhaustive P scalar (unguardedPats builderArms) := by
    intro v hv; exact ⟨.var,by simp [builderArms,varAlt,unguardedPats],by simp [matchVal]⟩
  have hh := wrap_open builder_view (.match (.V_Var (i := 0) rfl (by simp [scalar,Ty.Ordinary]))
    (builder_arms P B) hx) (done_ann (P := P) (Γ := Γ0) (a := .base .integer) ⟨trivial,trivial,trivial⟩)
  simpa [builderMatchQ] using hh

theorem builder_match_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run builderMatchQ [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) := by
  apply run_state hv (empty_builtin P B) (builder_store P B σ) (builder_match_closure P B)
    (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [builderMatchQ,builderArms,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateArms,adequateVals]
  · refine ⟨unit_closed.1,by change 0 < 1; omega,?_⟩
    exact ⟨trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial⟩
  · intro f hf; cases hf
  · exact one_closed trivial

theorem builder_match_after (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ builderMatchState := by
  refine ⟨hv,Eff.empty,empty_builtin P B,runtimeBuilder,none,.base .integer,.base .integer,Eff.empty,Eff.empty,
    builder_store P B σ,⟨.var 0,rfl,builder_match_closure P B⟩,subRefl _,
    .K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩,trivial,?_,?_,trivial,?_,?_,?_,one_closed trivial⟩
  · exact unit_adequate σ |>.1
  · intro arm ha; cases ha
  · simp [builderArms,adequateArms,Comp.Adequate,Val.Adequate,adequateVals]
  · exact ⟨unit_closed.1,⟨trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial,⟨(R_unit_ann P).wf,trivial,trivial⟩,trivial⟩⟩
  · intro f hf; cases hf

theorem builder_match_transition (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run builderMatchQ [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) ∧
    Step P B σ (.run builderMatchQ [] (Store.empty.set 0 (.builder (substKind cap.env kind0).empty))) none builderMatchState ∧
    StateTy P B σ builderMatchState :=
  ⟨builder_match_before P B σ hv,.E_Match rfl,builder_match_after P B σ hv⟩

end
end Benitoite.Release.Refinement.ClosureR2

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (n,_) =>
    if (`Benitoite.Release.Refinement.ClosureR2).isPrefixOf n then some n else none
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for n in names do
    elabCommand (← `(#print axioms $(mkIdent n)))
