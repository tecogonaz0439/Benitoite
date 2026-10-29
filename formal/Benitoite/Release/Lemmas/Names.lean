import Benitoite.Release.WellFormed

/-!
# 型付けから従うラムダの契約名

ラムダの名前の整形式を、項全体の型付けから導く。変数の範囲の条件からラムダ自身の
名前の連言を取り除いても、型付きの項では同じ条件となることを示す。
型注釈の整形式は `Ty.VarsIn` に保持し、項の名前と区別する。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


mutual
  def Val.LambdaNamesWF : Val → Prop
    | .var _ => True
    | .const _ => True
    | .fnRef _ _ _ => True
    | .prim _ _ _ _ => True
    | .lam names params body => NamesWF names params ∧ Comp.LambdaNamesWF body
    | .con _ _ args => Val.LambdaNamesWFList args
    | .list elems => Val.LambdaNamesWFList elems
    | .op _ _ => True
    | .raise _ _ => True
    | .loc _ => True
    | .mapV ks vs => Val.LambdaNamesWFList ks ∧ Val.LambdaNamesWFList vs
    | .setV elems => Val.LambdaNamesWFList elems
    | .bytesV _ => True
    | .checked _ => True
    | .checkedRequest _ _ => True
    | .dict _ _ args => Val.LambdaNamesWFList args
    | .super v _ => Val.LambdaNamesWF v

  def Val.LambdaNamesWFList : List Val → Prop
    | [] => True
    | v :: vs => Val.LambdaNamesWF v ∧ Val.LambdaNamesWFList vs

  def Comp.LambdaNamesWF : Comp → Prop
    | .builderLet _ body => Comp.LambdaNamesWF body
    | .builderOp _ _ _ args => Val.LambdaNamesWFList args
    | .ret v => Val.LambdaNamesWF v
    | .letIn m m' => Comp.LambdaNamesWF m ∧ Comp.LambdaNamesWF m'
    | .app f args => Val.LambdaNamesWF f ∧ Val.LambdaNamesWFList args
    | .ite v m m' => Val.LambdaNamesWF v ∧ Comp.LambdaNamesWF m ∧ Comp.LambdaNamesWF m'
    | .match v arms => Val.LambdaNamesWF v ∧ Arm.LambdaNamesWFList arms
    | .lazyC m => Comp.LambdaNamesWF m
    | .escape v => Val.LambdaNamesWF v
    | .use v m => Val.LambdaNamesWF v ∧ Comp.LambdaNamesWF m
    | .handle m h => Comp.LambdaNamesWF m ∧ Clause.LambdaNamesWFList h
    | .resume k v => Val.LambdaNamesWF k ∧ Val.LambdaNamesWF v
    | .meth d _ _ _ args =>
        Val.LambdaNamesWF d ∧ Val.LambdaNamesWFList args

  def Arm.LambdaNamesWFList : List Arm → Prop
    | [] => True
    | .mk _ none m :: arms => Comp.LambdaNamesWF m ∧ Arm.LambdaNamesWFList arms
    | .mk _ (some g) m :: arms =>
        Comp.LambdaNamesWF g ∧ Comp.LambdaNamesWF m ∧ Arm.LambdaNamesWFList arms

  /-- 節の本体に含まれるラムダも、名前の整形式の対象とする。 -/
  def Clause.LambdaNamesWFList : List Clause → Prop
    | [] => True
    | .mk _ _ _ m :: cs => Comp.LambdaNamesWF m ∧ Clause.LambdaNamesWFList cs
    | .fail _ m :: cs => Comp.LambdaNamesWF m ∧ Clause.LambdaNamesWFList cs
end


mutual
  def Val.VarsInNoLamNames (n : Nat) (pe : Nat → Prop) (v : Val) (depth : Nat := 0) : Prop :=
    match v with
    | .var _ => True
    | .const _ => True
    | .fnRef _ tys effs => Ty.VarsInList 0 n pe tys ∧ Eff.VarsInList 0 n pe effs
    | .prim _ tys effs _ => Ty.VarsInList 0 n pe tys ∧ Eff.VarsInList 0 n pe effs
    | .lam _ params body => Ty.VarsInList 0 n pe params ∧ Comp.VarsInNoLamNames n pe body (depth + params.length)
    | .con _ tys args => Ty.VarsInList 0 n pe tys ∧ Val.VarsInNoLamNamesList n pe args depth
    | .list elems => Val.VarsInNoLamNamesList n pe elems depth
    | .op _ tys => Ty.VarsInList 0 n pe tys
    | .raise t e => Ty.VarsIn 0 n pe t ∧ Ty.VarsIn 0 n pe e
    | .loc _ => True
    | .mapV ks vs => Val.VarsInNoLamNamesList n pe ks depth ∧ Val.VarsInNoLamNamesList n pe vs depth
    | .setV elems => Val.VarsInNoLamNamesList n pe elems depth
    | .bytesV _ => True
    | .checked _ => True
    | .checkedRequest _ _ => True
    | .dict _ tys args => Ty.VarsInList 0 n pe tys ∧ Val.VarsInNoLamNamesList n pe args depth
    | .super v _ => Val.VarsInNoLamNames n pe v depth

  def Val.VarsInNoLamNamesList (n : Nat) (pe : Nat → Prop) (vs : List Val) (depth : Nat := 0) : Prop :=
    match vs with
    | [] => True
    | v :: vs => Val.VarsInNoLamNames n pe v depth ∧ Val.VarsInNoLamNamesList n pe vs depth

  def Comp.VarsInNoLamNames (n : Nat) (pe : Nat → Prop) (m : Comp) (depth : Nat := 0) : Prop :=
    match m with
    | .builderLet k body => (match k with | .list a => Ty.VarsIn 0 n pe a | _ => True) ∧
        Comp.VarsInNoLamNames n pe body (depth + 1)
    | .builderOp k _ r args => (match k with | .list a => Ty.VarsIn 0 n pe a | _ => True) ∧
        r.Scoped depth ∧ Val.VarsInNoLamNamesList n pe args depth
    | .ret v => Val.VarsInNoLamNames n pe v depth
    | .letIn m m' => Comp.VarsInNoLamNames n pe m depth ∧ Comp.VarsInNoLamNames n pe m' (depth + 1)
    | .app f args => Val.VarsInNoLamNames n pe f depth ∧ Val.VarsInNoLamNamesList n pe args depth
    | .ite v m m' => Val.VarsInNoLamNames n pe v depth ∧ Comp.VarsInNoLamNames n pe m depth ∧ Comp.VarsInNoLamNames n pe m' depth
    | .match v arms => Val.VarsInNoLamNames n pe v depth ∧ Arm.VarsInNoLamNamesList n pe arms depth
    | .lazyC m => Comp.VarsInNoLamNames n pe m depth
    | .escape v => Val.VarsInNoLamNames n pe v depth
    | .use v m => Val.VarsInNoLamNames n pe v depth ∧ Comp.VarsInNoLamNames n pe m depth
    | .handle m h => Comp.VarsInNoLamNames n pe m depth ∧ Clause.VarsInNoLamNamesList n pe h depth
    | .resume k v => Val.VarsInNoLamNames n pe k depth ∧ Val.VarsInNoLamNames n pe v depth
    | .meth d _ tys effs args =>
        Val.VarsInNoLamNames n pe d depth ∧ Ty.VarsInList 0 n pe tys ∧ Eff.VarsInList 0 n pe effs ∧ Val.VarsInNoLamNamesList n pe args depth

  def Arm.VarsInNoLamNamesList (n : Nat) (pe : Nat → Prop) (arms : List Arm) (depth : Nat := 0) : Prop :=
    match arms with
    | [] => True
    | .mk alts none m :: arms => Comp.VarsInNoLamNames n pe m (depth + Arm.bindersOf alts) ∧ Arm.VarsInNoLamNamesList n pe arms depth
    | .mk alts (some g) m :: arms =>
        Comp.VarsInNoLamNames n pe g (depth + Arm.bindersOf alts) ∧ Comp.VarsInNoLamNames n pe m (depth + Arm.bindersOf alts) ∧ Arm.VarsInNoLamNamesList n pe arms depth

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.VarsInNoLamNamesList (n : Nat) (pe : Nat → Prop) (cs : List Clause) (depth : Nat := 0) : Prop :=
    match cs with
    | [] => True
    | .mk _ arity k m :: cs => Comp.VarsInNoLamNames (n + k) pe m (depth + arity + 1) ∧ Clause.VarsInNoLamNamesList n pe cs depth
    | .fail e m :: cs => Ty.VarsIn 0 n pe e ∧ Comp.VarsInNoLamNames (n + 1) pe m (depth + 2) ∧ Clause.VarsInNoLamNamesList n pe cs depth
end


variable {P : Program} {B : Builtins}

mutual
  /-- 型付けは、入れ子を含む全ラムダの名前の整形式を保証する。 -/
  theorem HasTypeVQ.lambdaNamesWF {Ψ C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) :
      v.LambdaNamesWF := by
    match h with
    | .V_Var _ _ => trivial
    | .V_Const => trivial
    | .V_Fun .. => trivial
    | .V_Prim .. => trivial
    | .V_Op _ _ _ => trivial
    | .V_Raise _ _ => trivial
    | .V_Lam hn hw hb => exact ⟨hn, HasTypeCQ.lambdaNamesWF hb⟩
    | .V_Con _ _ hs => exact HasTypeVsQ.lambdaNamesWF hs
    | .V_List hs _ => exact HasTypeEachQ.lambdaNamesWF hs
    | .V_LocRef _ => trivial
    | .V_LocLazy _ => trivial
    | .V_Map hk hv _ _ _ _ => exact ⟨HasTypeEachQ.lambdaNamesWF hk, HasTypeEachQ.lambdaNamesWF hv⟩
    | .V_Set hs _ _ => exact HasTypeEachQ.lambdaNamesWF hs
    | .V_Bytes => trivial
    | .V_Dict _ _ hs => exact HasTypeVsQ.lambdaNamesWF hs
    | .V_Super hv _ _ =>
        simp only [Val.LambdaNamesWF]; exact HasTypeVQ.lambdaNamesWF hv
    | .V_Sub hv _ hw => exact HasTypeVQ.lambdaNamesWF hv
    | .V_Checked _ _ => trivial
    | .V_CheckedRequest _ _ _ _ => trivial

  theorem HasTypeVsQ.lambdaNamesWF {Ψ C Γ vs as} (h : HasTypeVsQ P B Ψ Q C Γ vs as) :
      Val.LambdaNamesWFList vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨HasTypeVQ.lambdaNamesWF hv, HasTypeVsQ.lambdaNamesWF hs⟩

  theorem HasTypeEachQ.lambdaNamesWF {Ψ C Γ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a) :
      Val.LambdaNamesWFList vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨HasTypeVQ.lambdaNamesWF hv, HasTypeEachQ.lambdaNamesWF hs⟩

  theorem HasTypeCQ.lambdaNamesWF {Δl : LocalCtx} {Ψ C Γ R m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε Δl) :
      m.LambdaNamesWF := by
    match h with
    | .C_BuilderLet _ hb => simp only [Comp.LambdaNamesWF]; exact HasTypeCQ.lambdaNamesWF hb
    | .C_BuilderOp _ _ ha => simp only [Comp.LambdaNamesWF]; exact HasTypeVsQ.lambdaNamesWF ha
    | .C_Return hv => exact HasTypeVQ.lambdaNamesWF hv
    | .C_Sub hm _ _ hw => exact HasTypeCQ.lambdaNamesWF hm
    | .C_Eff hm _ => exact HasTypeCQ.lambdaNamesWF hm
    | .C_Let hm hn => exact ⟨HasTypeCQ.lambdaNamesWF hm, HasTypeCQ.lambdaNamesWF hn⟩
    | .C_App hf hs => exact ⟨HasTypeVQ.lambdaNamesWF hf, HasTypeVsQ.lambdaNamesWF hs⟩
    | .C_If hv hm hn => exact ⟨HasTypeVQ.lambdaNamesWF hv, HasTypeCQ.lambdaNamesWF hm, HasTypeCQ.lambdaNamesWF hn⟩
    | .C_Match hv hs _ => exact ⟨HasTypeVQ.lambdaNamesWF hv, HasTypeArmsQ.lambdaNamesWF hs⟩
    | .C_Lazy hm =>
        simp only [Comp.LambdaNamesWF]; exact HasTypeCQ.lambdaNamesWF hm
    | .C_Escape hv _ => exact HasTypeVQ.lambdaNamesWF hv
    | .C_Use hv _ hm _ => exact ⟨HasTypeVQ.lambdaNamesWF hv, HasTypeCQ.lambdaNamesWF hm⟩
    | .C_Handle hm _ hs => exact ⟨HasTypeCQ.lambdaNamesWF hm, HasTypeClausesQ.lambdaNamesWF hs⟩
    | .C_Handle_Fail hm _ _ hc => exact ⟨HasTypeCQ.lambdaNamesWF hm, HasFailureClause.lambdaNamesWF hc⟩
    | .C_Resume _ hv => exact ⟨trivial, HasTypeVQ.lambdaNamesWF hv⟩
    | .C_ResumeL _ hv => exact ⟨trivial, HasTypeVQ.lambdaNamesWF hv⟩
    | .C_Meth hv _ _ _ _ _ _ hs => exact ⟨HasTypeVQ.lambdaNamesWF hv, HasTypeVsQ.lambdaNamesWF hs⟩

  theorem HasTypeArmsQ.lambdaNamesWF {Δl : LocalCtx} {Ψ C Γ R arms a b ε} (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δl) :
      Arm.LambdaNamesWFList arms := by
    match h with
    | .nil _ => trivial
    | .plain _ hm hs => exact ⟨HasTypeCQ.lambdaNamesWF hm, HasTypeArmsQ.lambdaNamesWF hs⟩
    | .guarded _ hg hm hs => exact ⟨HasTypeCQ.lambdaNamesWF hg, HasTypeCQ.lambdaNamesWF hm, HasTypeArmsQ.lambdaNamesWF hs⟩

  theorem HasTypeClausesQ.lambdaNamesWF {Δl : LocalCtx} {Ψ C Γ R εb cs t ε} (h : HasTypeClausesQ P B Ψ Q C Γ R εb cs t ε Δl) :
      Clause.LambdaNamesWFList cs := by
    match h with
    | .nil => trivial
    | .cons _ _ _ _ _ hm hs => exact ⟨HasTypeCQ.lambdaNamesWF hm, HasTypeClausesQ.lambdaNamesWF hs⟩
  theorem HasFailureClause.lambdaNamesWF {Δl : LocalCtx} {Ψ C Γ E R h t ε}
      (hc : HasFailureClause P B Ψ Q C Γ E R h t ε Δl) : Clause.LambdaNamesWFList h := by
    match hc with
    | .one _ _ _ hb => exact ⟨HasTypeCQ.lambdaNamesWF hb, trivial⟩

end

mutual
  theorem Val.varsIn_iff_noLamNames (n : Nat) (pe : Nat → Prop) {depth : Nat} : (v : Val) →
      Val.VarsIn n pe v depth ↔ Val.VarsInNoLamNames n pe v depth ∧ Val.LambdaNamesWF v
    | .var _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .const _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .fnRef _ tys effs => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .prim _ tys effs _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .lam names params body => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Comp.varsIn_iff_noLamNames n pe body] <;>
          grind only
    | .con _ tys args => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsInList_iff_noLamNames n pe args] <;>
          grind only
    | .list elems => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsInList_iff_noLamNames n pe elems] <;>
          grind only
    | .op _ tys => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .raise _ _ => by simp [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF]
    | .loc _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .mapV ks vs => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsInList_iff_noLamNames n pe ks,
          Val.varsInList_iff_noLamNames n pe vs] <;>
          grind only
    | .setV elems => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsInList_iff_noLamNames n pe elems] <;>
          grind only
    | .bytesV _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .checked _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .checkedRequest _ _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .dict _ tys args => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsInList_iff_noLamNames n pe args] <;>
          grind only
    | .super v _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe v] <;>
          grind only
  theorem Val.varsInList_iff_noLamNames (n : Nat) (pe : Nat → Prop) {depth : Nat} : (vs : List Val) →
      Val.VarsInList n pe vs depth ↔ Val.VarsInNoLamNamesList n pe vs depth ∧ Val.LambdaNamesWFList vs
    | [] => by
        simp only [Val.VarsInList, Val.VarsInNoLamNamesList, Val.LambdaNamesWFList] <;>
          grind only
    | v :: vs => by
        simp only [Val.VarsInList, Val.VarsInNoLamNamesList, Val.LambdaNamesWFList,
          Val.varsIn_iff_noLamNames n pe v, Val.varsInList_iff_noLamNames n pe vs] <;>
          grind only
  theorem Comp.varsIn_iff_noLamNames (n : Nat) (pe : Nat → Prop) {depth : Nat} : (m : Comp) →
      Comp.VarsIn n pe m depth ↔ Comp.VarsInNoLamNames n pe m depth ∧ Comp.LambdaNamesWF m
    | .builderLet k body => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF,
          Comp.varsIn_iff_noLamNames n pe body]
        grind only
    | .builderOp k op r args => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF,
          Val.varsInList_iff_noLamNames n pe args]
        grind only
    | .ret v => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe v] <;>
          grind only
    | .letIn m m' => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Comp.varsIn_iff_noLamNames n pe m,
          Comp.varsIn_iff_noLamNames n pe m'] <;>
          grind only
    | .app f args => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe f,
          Val.varsInList_iff_noLamNames n pe args] <;>
          grind only
    | .ite v m m' => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe v,
          Comp.varsIn_iff_noLamNames n pe m, Comp.varsIn_iff_noLamNames n pe m'] <;>
          grind only
    | .match v arms => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe v,
          Arm.varsInList_iff_noLamNames n pe arms] <;>
          grind only
    | .lazyC m => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Comp.varsIn_iff_noLamNames n pe m] <;>
          grind only
    | .escape v => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe v] <;>
          grind only
    | .use v m => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe v,
          Comp.varsIn_iff_noLamNames n pe m] <;>
          grind only
    | .handle m h => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Comp.varsIn_iff_noLamNames n pe m,
          Clause.varsInList_iff_noLamNames n pe h] <;>
          grind only
    | .resume k v => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe k,
          Val.varsIn_iff_noLamNames n pe v] <;>
          grind only
    | .meth d _ tys effs args => by
        simp only [Comp.VarsIn, Comp.VarsInNoLamNames, Comp.LambdaNamesWF,
          Val.varsIn_iff_noLamNames n pe d, Val.varsInList_iff_noLamNames n pe args] <;>
          grind only
  theorem Arm.varsInList_iff_noLamNames (n : Nat) (pe : Nat → Prop) {depth : Nat} : (arms : List Arm) →
      Arm.VarsInList n pe arms depth ↔ Arm.VarsInNoLamNamesList n pe arms depth ∧ Arm.LambdaNamesWFList arms
    | [] => by
        simp only [Arm.VarsInList, Arm.VarsInNoLamNamesList, Arm.LambdaNamesWFList] <;>
          grind only
    | .mk _ none m :: arms => by
        simp only [Arm.VarsInList, Arm.VarsInNoLamNamesList, Arm.LambdaNamesWFList,
          Comp.varsIn_iff_noLamNames n pe m, Arm.varsInList_iff_noLamNames n pe arms] <;>
          grind only
    | .mk _ (some g) m :: arms => by
        simp only [Arm.VarsInList, Arm.VarsInNoLamNamesList, Arm.LambdaNamesWFList,
          Comp.varsIn_iff_noLamNames n pe g, Comp.varsIn_iff_noLamNames n pe m,
          Arm.varsInList_iff_noLamNames n pe arms] <;>
          grind only
  theorem Clause.varsInList_iff_noLamNames (n : Nat) (pe : Nat → Prop) {depth : Nat} : (cs : List Clause) →
      Clause.VarsInList n pe cs depth ↔ Clause.VarsInNoLamNamesList n pe cs depth ∧ Clause.LambdaNamesWFList cs
    | [] => by
        simp only [Clause.VarsInList, Clause.VarsInNoLamNamesList, Clause.LambdaNamesWFList] <;>
          grind only
    | .mk _ _ k m :: cs => by
        simp only [Clause.VarsInList, Clause.VarsInNoLamNamesList, Clause.LambdaNamesWFList,
          Comp.varsIn_iff_noLamNames (n + k) pe m, Clause.varsInList_iff_noLamNames n pe cs] <;>
          grind only
    | .fail e m :: cs => by
        simp only [Clause.VarsInList, Clause.VarsInNoLamNamesList, Clause.LambdaNamesWFList,
          Comp.varsIn_iff_noLamNames (n + 1) pe m, Clause.varsInList_iff_noLamNames n pe cs]
        grind only

end

/-- 型付きの値では、変数の範囲にあるラムダ名の条件を別途仮定する必要がない。 -/
theorem HasTypeVQ.varsIn_iff_noLamNames {Ψ C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) (n : Nat) (pe : Nat → Prop) :
    Val.VarsIn n pe v ↔ Val.VarsInNoLamNames n pe v := by
  rw [Val.varsIn_iff_noLamNames, and_iff_left h.lambdaNamesWF]

/-- 初期の計算も、型付けから全ラムダの名前の条件を導ける。 -/
theorem HasTypeCQ.varsIn_iff_noLamNames {Δl : LocalCtx} {Ψ C Γ R m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε Δl) (n : Nat) (pe : Nat → Prop) :
    Comp.VarsIn n pe m ↔ Comp.VarsInNoLamNames n pe m := by
  rw [Comp.varsIn_iff_noLamNames, and_iff_left h.lambdaNamesWF]

end Benitoite.Release
