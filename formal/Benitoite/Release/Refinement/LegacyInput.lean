import Benitoite.Release.Refinement.LegacyDeclarations
import Benitoite.Release.Refinement.ProgramWellFormed

/-! # 旧構文の表現・注釈・束縛の入力 -/
namespace Benitoite.Release.Refinement
noncomputable section

structure LegacyInputCtx where
  kinds : List TyKind
  constraints : List Benitoite.Release.TParam
  nr : Nat
  nv : Nat

def LegacyInputCtx.values (Δ : LegacyInputCtx) (n : Nat) : LegacyInputCtx :=
  { Δ with nv := Δ.nv + n }
def LegacyInputCtx.types (Δ : LegacyInputCtx) (ps : List Benitoite.Release.TParam)
    (ks : List TyKind) : LegacyInputCtx :=
  { Δ with kinds := ks ++ Δ.kinds, constraints := ps ++ Δ.constraints }
def LegacyInputCtx.closed : LegacyInputCtx := ⟨[], [], 0, 0⟩

def LegacyTypeInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (a : Benitoite.Release.Ty) (kind : TyKind) : Prop :=
  (embedTy a).HasKind (embedProgramWithKinds K P0) Δ.kinds kind ∧
  (embedTy a).WF Δ.nr Δ.kinds.length Δ.nv ∧
  (embedTy a).Sorted (List.replicate Δ.nv none) ∧
  (embedTy a).Declared (embedProgramWithKinds K P0) (legacyTypeCtx Δ.constraints Δ.kinds) (List.replicate Δ.nv none) ∧
  (embedTy a).RangesScoped Δ.nr

def LegacyTypesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (ts : List Benitoite.Release.Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind),
    ts[i]? = some a → ks[i]? = some k →
      LegacyTypeInput K P0 Δ a k ∧ (k = .value → Ordinary (embedTy a))

def LegacyRowsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (es : List Benitoite.Release.Eff) : Prop :=
  ∀ e ∈ es, LegacyTypeInput K P0 Δ (.fn [] [] (.base .unit) e) .value

def LegacyBuilderInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) (k : Benitoite.Release.BuilderKind) : Prop :=
  LegacyTypeInput K P0 Δ k.contents .value ∧ Ordinary (embedTy k.contents)

mutual
  def LegacyValueInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : Benitoite.Release.Val → Prop
    | .var _ | .loc _ => True
    | .const c => ConstOK B (embedConst c)
    | .bytesV bs => ∀ b ∈ bs, b ≤ 255
    | .fnRef f ts es => ∃ fd, P0.defs f = some fd ∧
        LegacyTypeInput K P0 ⟨K.functionParams f, fd.tparams, 0, 0⟩
          (.fn fd.names fd.params fd.ret fd.eff) .value ∧
        LegacyTypesInput K P0 Δ ts (K.functionParams f) ∧ LegacyRowsInput K P0 Δ es
    | .prim b ts es rs => ∃ s0 s, B0.sig b = some s0 ∧ B.sig b = some s ∧
        s.tparams.length = s0.tparams.length ∧
        LegacyTypeInput K P0 ⟨s.tparams.map TParamDecl.kind, s0.tparams, s0.nranges, 0⟩
          (.fn s0.names s0.params s0.ret s0.eff) .value ∧
        LegacyTypesInput K P0 Δ ts (s.tparams.map TParamDecl.kind) ∧ LegacyRowsInput K P0 Δ es ∧
        (∀ r ∈ rs, (embedRange r).WF ∧ (embedRange r).Canonical)
    | .op o ts => ∃ od, P0.ops o = some od ∧
        LegacyTypeInput K P0 ⟨List.replicate od.tparams.length .value, od.tparams, 0, 0⟩
          (.fn od.names od.params od.ret (Benitoite.Release.Eff.single od.eff)) .value ∧
        LegacyTypesInput K P0 Δ ts (List.replicate od.tparams.length .value)
    | .raise a e => (LegacyTypeInput K P0 Δ a .value ∧ Ordinary (embedTy a)) ∧
        (LegacyTypeInput K P0 Δ e .value ∧ Ordinary (embedTy e))
    | .lam ns ps body => Benitoite.Release.NamesWF ns ps ∧
        (∀ a ∈ ps, LegacyTypeInput K P0 Δ a .value) ∧ LegacyCompInput K P0 B0 B (Δ.values ps.length) body
    | .con c ts vs => (∃ cd, P0.cons c = some cd ∧
        LegacyTypesInput K P0 Δ ts (List.replicate cd.ntys .value)) ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .dict i ts vs => (∃ id, P0.impls i = some id ∧
        LegacyTypeInput K P0 ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩
          id.target (K.classArgument id.cls) ∧
        (∀ a ∈ id.dictTys, LegacyTypeInput K P0
          ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩ a .value) ∧
        LegacyTypesInput K P0 Δ ts (List.replicate id.tparams.length .value)) ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .list vs | .setV vs => LegacyValuesInput K P0 B0 B Δ vs
    | .mapV ks vs => LegacyValuesInput K P0 B0 B Δ ks ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .super v _ => LegacyValueInput K P0 B0 B Δ v
    | .checked target => ∃ o, B0.valKind o = some target.kind ∧
        B.valKind o = some target.kind ∧ B.valContent o = none
    | .checkedRequest target req => LegacyValueInput K P0 B0 B .closed req ∧
        groundVal (embedVal req) = true ∧ (embedVal req).reqTarget = some target ∧
        (∃ o T0, B0.valKind o = some .endpoint ∧ B.valKind o = some .endpoint ∧
          B0.valContent o = some T0 ∧ B.valContent o = some (embedTy T0))
  def LegacyValuesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Val → Prop
    | [] => True
    | v :: vs => LegacyValueInput K P0 B0 B Δ v ∧ LegacyValuesInput K P0 B0 B Δ vs
  def LegacyCompInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : Benitoite.Release.Comp → Prop
    | .builderLet k body => LegacyBuilderInput K P0 Δ k ∧ LegacyCompInput K P0 B0 B (Δ.values 1) body
    | .builderOp k _ _ vs => LegacyBuilderInput K P0 Δ k ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .ret v | .escape v => LegacyValueInput K P0 B0 B Δ v
    | .letIn m n => LegacyCompInput K P0 B0 B Δ m ∧ LegacyCompInput K P0 B0 B (Δ.values 1) n
    | .app v vs => LegacyValueInput K P0 B0 B Δ v ∧ LegacyValuesInput K P0 B0 B Δ vs
    | .ite v m n => LegacyValueInput K P0 B0 B Δ v ∧ LegacyCompInput K P0 B0 B Δ m ∧ LegacyCompInput K P0 B0 B Δ n
    | .match v arms => LegacyValueInput K P0 B0 B Δ v ∧ LegacyArmsInput K P0 B0 B Δ arms
    | .lazyC m => LegacyCompInput K P0 B0 B Δ m
    | .use v m => LegacyValueInput K P0 B0 B Δ v ∧ LegacyCompInput K P0 B0 B Δ m
    | .handle m cs => LegacyCompInput K P0 B0 B Δ m ∧ LegacyClausesInput K P0 B0 B Δ cs
    | .resume k v => LegacyValueInput K P0 B0 B Δ k ∧ LegacyValueInput K P0 B0 B Δ v
    | .meth v m ts es vs => LegacyValueInput K P0 B0 B Δ v ∧
        (∃ cl cd ms, P0.classes cl = some cd ∧ cd.methods m = some ms ∧
          LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl],
            ms.tparams ++ [({} : Benitoite.Release.TParam)], 0, 0⟩
            (.fn ms.names ms.params ms.ret ms.eff) .value ∧
          LegacyTypesInput K P0 Δ ts (K.methodParams cl m)) ∧
        LegacyRowsInput K P0 Δ es ∧ LegacyValuesInput K P0 B0 B Δ vs
  def LegacyArmsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with | none => True
                          | some g => LegacyCompInput K P0 B0 B (Δ.values (Benitoite.Release.Arm.bindersOf alts)) g) ∧
        LegacyCompInput K P0 B0 B (Δ.values (Benitoite.Release.Arm.bindersOf alts)) body ∧
        LegacyArmsInput K P0 B0 B Δ arms
  def LegacyClausesInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
      (B0 : Benitoite.Release.Builtins) (B : Builtins)
      (Δ : LegacyInputCtx) : List Benitoite.Release.Clause → Prop
    | [] => True
    | .mk o n k body :: cs =>
        (∃ sg, Benitoite.Release.opSig P0 B0 o = some sg ∧
          k = sg.tparams.length ∧ n = sg.params.length ∧
          LegacyTypeInput K P0 ⟨List.replicate k .value, sg.tparams, 0, 0⟩
            (.fn sg.names sg.params sg.ret (Benitoite.Release.Eff.single sg.eff)) .value ∧
          LegacyCompInput K P0 B0 B ((Δ.types sg.tparams (List.replicate k .value)).values (n+1)) body) ∧
        LegacyClausesInput K P0 B0 B Δ cs
    | .fail e body :: cs => LegacyTypeInput K P0 Δ e .value ∧
        LegacyCompInput K P0 B0 B ((Δ.types [({} : Benitoite.Release.TParam)] [.value]).values 2) body ∧
        LegacyClausesInput K P0 B0 B Δ cs
end

/-- 実際に選ばれた旧の保持値の型との対応。構文側の存在量化だけでは代用しない。 -/
def LegacyHeldTypeInput (B0 : Benitoite.Release.Builtins) (B : Builtins)
    (v : Benitoite.Release.Val) (a : Benitoite.Release.Ty) : Prop :=
  match v with
  | .checked target => ∃ o range, a = .opaque o (.fixed range) ∧
      B0.valKind o = some target.kind ∧ B.valKind o = some target.kind ∧ B.valContent o = none ∧
      Scope.Domain.Range.MemK target.kind range target
  | .checkedRequest target _ => ∃ o range T0, a = .opaque o (.fixed range) ∧
      B0.valKind o = some .endpoint ∧ B.valKind o = some .endpoint ∧
      B0.valContent o = some T0 ∧ B.valContent o = some (embedTy T0) ∧
      Scope.Domain.Range.MemK .endpoint range target
  | .var _ | .const _ | .fnRef _ _ _ | .prim _ _ _ _ | .lam _ _ _ | .con _ _ _ |
      .list _ | .op _ _ | .raise _ _ | .loc _ | .mapV _ _ | .setV _ | .bytesV _ |
      .dict _ _ _ | .super _ _ => True

def LegacyLocInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Δ : LegacyInputCtx) : Benitoite.Release.LocTy → Prop
  | .builder k => LegacyBuilderInput K P0 Δ k
  | .ref a | .lazy a => LegacyTypeInput K P0 Δ a .value
  | .cont a b e r => LegacyTypeInput K P0 Δ a .value ∧ LegacyTypeInput K P0 Δ b .value ∧
      LegacyRowsInput K P0 Δ [e] ∧ (∀ t ∈ r.toList, LegacyTypeInput K P0 Δ t .value)

def LegacyContextInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (Ψ : Benitoite.Release.StoreTy) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) (Δ : LegacyInputCtx) : Prop :=
  Δ.constraints = C ∧ Δ.nv = Γ.length ∧ Δ.kinds.length = C.length ∧
  (∀ l lt, Ψ l = some lt → LegacyLocInput K P0 .closed lt) ∧
  (∀ (i : Nat) (a : Benitoite.Release.Ty), Γ[i]? = some (some a) → LegacyTypeInput K P0 Δ a .value ∧
    Ty.Annotation (embedProgramWithKinds K P0) (legacyTypeCtx C Δ.kinds) (Γ.map (Option.map embedTy)) (embedTy a))

/-- 宣言本体を構文として走査する。型付き本体の結論を入力にしない。 -/
def LegacyDeclarationsInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop :=
  (∀ f fd, P0.defs f = some fd →
    LegacyTypeInput K P0 ⟨K.functionParams f, fd.tparams, 0, 0⟩
      (.fn fd.names fd.params fd.ret fd.eff) .value ∧
    LegacyCompInput K P0 B0 B ⟨K.functionParams f, fd.tparams, 0, fd.params.length⟩ fd.body) ∧
  (∀ o od, P0.ops o = some od →
    LegacyTypeInput K P0 ⟨List.replicate od.tparams.length .value, od.tparams, 0, 0⟩
      (.fn od.names od.params od.ret (Benitoite.Release.Eff.single od.eff)) .value ∧
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    (embedOpDecl od).params.take od.dictParams.length =
      od.dictParams.map (fun p => Ty.dict p.1 (.tvar p.2))) ∧
  (∀ cl cd m ms, P0.classes cl = some cd → cd.methods m = some ms →
    LegacyTypeInput K P0 ⟨K.methodParams cl m ++ [K.classArgument cl], ms.tparams ++ [({} : Benitoite.Release.TParam)], 0, 0⟩
      (.fn ms.names ms.params ms.ret ms.eff) .value) ∧
  (∀ i id, P0.impls i = some id →
    LegacyTypeInput K P0 ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩
      id.target (K.classArgument id.cls) ∧
    (∀ a ∈ id.dictTys, LegacyTypeInput K P0
      ⟨List.replicate id.tparams.length .value, id.tparams, 0, 0⟩ a .value) ∧
    (∀ s v, id.supers s = some v → LegacyValueInput K P0 B0 B
      ⟨List.replicate id.tparams.length .value, id.tparams, 0, id.dictTys.length⟩ v) ∧
    (∀ cl m ms body, P0.classes id.cls = some cl → cl.methods m = some ms → id.methods m = some body →
      LegacyCompInput K P0 B0 B
        ⟨K.methodParams id.cls m ++ List.replicate id.tparams.length .value,
          ms.tparams ++ id.tparams, 0, id.dictTys.length + ms.params.length⟩ body))

/-- 操作の辞書の添字と先頭の一致を、宣言の形成へ渡す。 -/
theorem LegacyDeclarationsInput.op_dictionaryInputs {K P0 B0 B o od}
    (h : LegacyDeclarationsInput K P0 B0 B) (lookup : P0.ops o = some od) :
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    (embedOpDecl od).params.take od.dictParams.length =
      od.dictParams.map (fun p => Ty.dict p.1 (.tvar p.2)) :=
  (h.2.1 o od lookup).2

/-- 実装の辞書型の kind は既存の型入力から得る（設計書 01-12「旧判断の適格な入力」）。 -/
theorem LegacyDeclarationsInput.impl_dictionaryKinds {K P0 B0 B i id}
    (h : LegacyDeclarationsInput K P0 B0 B) (lookup : P0.impls i = some id) :
    ∀ a ∈ (embedImplDecl id).dictTys,
      a.HasKind (embedProgramWithKinds K P0)
        (List.replicate id.tparams.length .value) .value := by
  intro a ha
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp ha
  have oldMem : Benitoite.Release.Ty.dict p.1 (.tvar p.2) ∈ id.dictTys :=
    List.mem_map.mpr ⟨p, hp, rfl⟩
  exact ((h.2.2.2 i id lookup).2.1 _ oldMem).1

end
end Benitoite.Release.Refinement
