import Benitoite.Release.WellFormed

/-!
# 型付けから従うラムダの契約名

ラムダの名前の整形式を、項全体の型付けから導く。変数の範囲の条件からラムダ自身の
名前の連言を取り除いても、型付きの項では同じ条件となることを示す。
型注釈の整形式は `Ty.VarsIn` に保持し、項の名前と区別する。
-/

namespace Benitoite.Release

mutual
  def Val.LambdaNamesWF : Val → Prop
    | .var _ => True
    | .const _ => True
    | .fnRef _ _ _ => True
    | .prim _ _ _ => True
    | .lam names params body => NamesWF names params ∧ Comp.LambdaNamesWF body
    | .con _ _ args => Val.LambdaNamesWFList args
    | .list elems => Val.LambdaNamesWFList elems
    | .op _ _ => True
    | .loc _ => True
    | .mapV ks vs => Val.LambdaNamesWFList ks ∧ Val.LambdaNamesWFList vs
    | .setV elems => Val.LambdaNamesWFList elems
    | .bytesV _ => True
    | .dict _ _ args => Val.LambdaNamesWFList args
    | .super v _ => Val.LambdaNamesWF v

  def Val.LambdaNamesWFList : List Val → Prop
    | [] => True
    | v :: vs => Val.LambdaNamesWF v ∧ Val.LambdaNamesWFList vs

  def Comp.LambdaNamesWF : Comp → Prop
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
end


mutual
  /-- ラムダ自身の名前の条件を除いた変数の範囲。型注釈の整形式は保持する。 -/
  def Val.VarsInNoLamNames (n : Nat) (pe : Nat → Prop) : Val → Prop
    | .var _ => True
    | .const _ => True
    | .fnRef _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    | .prim _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    | .lam _ params body => Ty.VarsInList n pe params ∧ Comp.VarsInNoLamNames n pe body
    | .con _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInNoLamNamesList n pe args
    | .list elems => Val.VarsInNoLamNamesList n pe elems
    | .op _ tys => Ty.VarsInList n pe tys
    | .loc _ => True
    | .mapV ks vs => Val.VarsInNoLamNamesList n pe ks ∧ Val.VarsInNoLamNamesList n pe vs
    | .setV elems => Val.VarsInNoLamNamesList n pe elems
    | .bytesV _ => True
    | .dict _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInNoLamNamesList n pe args
    | .super v _ => Val.VarsInNoLamNames n pe v

  def Val.VarsInNoLamNamesList (n : Nat) (pe : Nat → Prop) : List Val → Prop
    | [] => True
    | v :: vs => Val.VarsInNoLamNames n pe v ∧ Val.VarsInNoLamNamesList n pe vs

  def Comp.VarsInNoLamNames (n : Nat) (pe : Nat → Prop) : Comp → Prop
    | .ret v => Val.VarsInNoLamNames n pe v
    | .letIn m m' => Comp.VarsInNoLamNames n pe m ∧ Comp.VarsInNoLamNames n pe m'
    | .app f args => Val.VarsInNoLamNames n pe f ∧ Val.VarsInNoLamNamesList n pe args
    | .ite v m m' => Val.VarsInNoLamNames n pe v ∧ Comp.VarsInNoLamNames n pe m ∧ Comp.VarsInNoLamNames n pe m'
    | .match v arms => Val.VarsInNoLamNames n pe v ∧ Arm.VarsInNoLamNamesList n pe arms
    | .lazyC m => Comp.VarsInNoLamNames n pe m
    | .escape v => Val.VarsInNoLamNames n pe v
    | .use v m => Val.VarsInNoLamNames n pe v ∧ Comp.VarsInNoLamNames n pe m
    | .handle m h => Comp.VarsInNoLamNames n pe m ∧ Clause.VarsInNoLamNamesList n pe h
    | .resume k v => Val.VarsInNoLamNames n pe k ∧ Val.VarsInNoLamNames n pe v
    | .meth d _ tys effs args =>
        Val.VarsInNoLamNames n pe d ∧ Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs ∧ Val.VarsInNoLamNamesList n pe args

  def Arm.VarsInNoLamNamesList (n : Nat) (pe : Nat → Prop) : List Arm → Prop
    | [] => True
    | .mk _ none m :: arms => Comp.VarsInNoLamNames n pe m ∧ Arm.VarsInNoLamNamesList n pe arms
    | .mk _ (some g) m :: arms =>
        Comp.VarsInNoLamNames n pe g ∧ Comp.VarsInNoLamNames n pe m ∧ Arm.VarsInNoLamNamesList n pe arms

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.VarsInNoLamNamesList (n : Nat) (pe : Nat → Prop) : List Clause → Prop
    | [] => True
    | .mk _ _ k m :: cs => Comp.VarsInNoLamNames (n + k) pe m ∧ Clause.VarsInNoLamNamesList n pe cs
end


variable {P : Program} {B : Builtins}

mutual
  /-- 型付けは、入れ子を含む全ラムダの名前の整形式を保証する。 -/
  theorem HasTypeV.lambdaNamesWF {Ψ C Γ v a} (h : HasTypeV P B Ψ C Γ v a) :
      v.LambdaNamesWF := by
    match h with
    | .V_Var _ _ => trivial
    | .V_Const => trivial
    | .V_Fun _ _ _ _ => trivial
    | .V_Prim _ _ _ _ _ => trivial
    | .V_Op _ _ _ => trivial
    | .V_Lam hn hb => exact ⟨hn, HasTypeC.lambdaNamesWF hb⟩
    | .V_Con _ _ hs => exact HasTypeVs.lambdaNamesWF hs
    | .V_List hs _ => exact HasTypeEach.lambdaNamesWF hs
    | .V_LocRef _ => trivial
    | .V_LocLazy _ => trivial
    | .V_Map hk hv _ _ _ _ => exact ⟨HasTypeEach.lambdaNamesWF hk, HasTypeEach.lambdaNamesWF hv⟩
    | .V_Set hs _ _ => exact HasTypeEach.lambdaNamesWF hs
    | .V_Bytes => trivial
    | .V_Dict _ _ hs => exact HasTypeVs.lambdaNamesWF hs
    | .V_Super hv _ _ =>
        simp only [Val.LambdaNamesWF]; exact HasTypeV.lambdaNamesWF hv
    | .V_Sub hv _ => exact HasTypeV.lambdaNamesWF hv

  theorem HasTypeVs.lambdaNamesWF {Ψ C Γ vs as} (h : HasTypeVs P B Ψ C Γ vs as) :
      Val.LambdaNamesWFList vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨HasTypeV.lambdaNamesWF hv, HasTypeVs.lambdaNamesWF hs⟩

  theorem HasTypeEach.lambdaNamesWF {Ψ C Γ vs a} (h : HasTypeEach P B Ψ C Γ vs a) :
      Val.LambdaNamesWFList vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨HasTypeV.lambdaNamesWF hv, HasTypeEach.lambdaNamesWF hs⟩

  theorem HasTypeC.lambdaNamesWF {Ψ C Γ R m a ε} (h : HasTypeC P B Ψ C Γ R m a ε) :
      m.LambdaNamesWF := by
    match h with
    | .C_Return hv => exact HasTypeV.lambdaNamesWF hv
    | .C_Sub hm _ _ => exact HasTypeC.lambdaNamesWF hm
    | .C_Let hm hn => exact ⟨HasTypeC.lambdaNamesWF hm, HasTypeC.lambdaNamesWF hn⟩
    | .C_App hf hs => exact ⟨HasTypeV.lambdaNamesWF hf, HasTypeVs.lambdaNamesWF hs⟩
    | .C_If hv hm hn => exact ⟨HasTypeV.lambdaNamesWF hv, HasTypeC.lambdaNamesWF hm, HasTypeC.lambdaNamesWF hn⟩
    | .C_Match hv hs _ => exact ⟨HasTypeV.lambdaNamesWF hv, HasTypeArms.lambdaNamesWF hs⟩
    | .C_Lazy hm =>
        simp only [Comp.LambdaNamesWF]; exact HasTypeC.lambdaNamesWF hm
    | .C_Escape hv _ => exact HasTypeV.lambdaNamesWF hv
    | .C_Use hv _ hm _ => exact ⟨HasTypeV.lambdaNamesWF hv, HasTypeC.lambdaNamesWF hm⟩
    | .C_Handle hm _ hs => exact ⟨HasTypeC.lambdaNamesWF hm, HasTypeClauses.lambdaNamesWF hs⟩
    | .C_Resume _ hv => exact ⟨trivial, HasTypeV.lambdaNamesWF hv⟩
    | .C_ResumeL _ hv => exact ⟨trivial, HasTypeV.lambdaNamesWF hv⟩
    | .C_Meth hv _ _ _ _ _ hs => exact ⟨HasTypeV.lambdaNamesWF hv, HasTypeVs.lambdaNamesWF hs⟩

  theorem HasTypeArms.lambdaNamesWF {Ψ C Γ R arms a b ε} (h : HasTypeArms P B Ψ C Γ R arms a b ε) :
      Arm.LambdaNamesWFList arms := by
    match h with
    | .nil _ => trivial
    | .plain _ hm hs => exact ⟨HasTypeC.lambdaNamesWF hm, HasTypeArms.lambdaNamesWF hs⟩
    | .guarded _ hg hm hs => exact ⟨HasTypeC.lambdaNamesWF hg, HasTypeC.lambdaNamesWF hm, HasTypeArms.lambdaNamesWF hs⟩

  theorem HasTypeClauses.lambdaNamesWF {Ψ C Γ R cs t ε} (h : HasTypeClauses P B Ψ C Γ R cs t ε) :
      Clause.LambdaNamesWFList cs := by
    match h with
    | .nil => trivial
    | .cons _ _ _ _ hm hs => exact ⟨HasTypeC.lambdaNamesWF hm, HasTypeClauses.lambdaNamesWF hs⟩
end

mutual
  theorem Val.varsIn_iff_noLamNames (n : Nat) (pe : Nat → Prop) : (v : Val) →
      Val.VarsIn n pe v ↔ Val.VarsInNoLamNames n pe v ∧ Val.LambdaNamesWF v
    | .var _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .const _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .fnRef _ tys effs => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF] <;>
          grind only
    | .prim _ tys effs => by
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
    | .dict _ tys args => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsInList_iff_noLamNames n pe args] <;>
          grind only
    | .super v _ => by
        simp only [Val.VarsIn, Val.VarsInNoLamNames, Val.LambdaNamesWF, Val.varsIn_iff_noLamNames n pe v] <;>
          grind only
  theorem Val.varsInList_iff_noLamNames (n : Nat) (pe : Nat → Prop) : (vs : List Val) →
      Val.VarsInList n pe vs ↔ Val.VarsInNoLamNamesList n pe vs ∧ Val.LambdaNamesWFList vs
    | [] => by
        simp only [Val.VarsInList, Val.VarsInNoLamNamesList, Val.LambdaNamesWFList] <;>
          grind only
    | v :: vs => by
        simp only [Val.VarsInList, Val.VarsInNoLamNamesList, Val.LambdaNamesWFList,
          Val.varsIn_iff_noLamNames n pe v, Val.varsInList_iff_noLamNames n pe vs] <;>
          grind only
  theorem Comp.varsIn_iff_noLamNames (n : Nat) (pe : Nat → Prop) : (m : Comp) →
      Comp.VarsIn n pe m ↔ Comp.VarsInNoLamNames n pe m ∧ Comp.LambdaNamesWF m
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
  theorem Arm.varsInList_iff_noLamNames (n : Nat) (pe : Nat → Prop) : (arms : List Arm) →
      Arm.VarsInList n pe arms ↔ Arm.VarsInNoLamNamesList n pe arms ∧ Arm.LambdaNamesWFList arms
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
  theorem Clause.varsInList_iff_noLamNames (n : Nat) (pe : Nat → Prop) : (cs : List Clause) →
      Clause.VarsInList n pe cs ↔ Clause.VarsInNoLamNamesList n pe cs ∧ Clause.LambdaNamesWFList cs
    | [] => by
        simp only [Clause.VarsInList, Clause.VarsInNoLamNamesList, Clause.LambdaNamesWFList] <;>
          grind only
    | .mk _ _ k m :: cs => by
        simp only [Clause.VarsInList, Clause.VarsInNoLamNamesList, Clause.LambdaNamesWFList,
          Comp.varsIn_iff_noLamNames (n + k) pe m, Clause.varsInList_iff_noLamNames n pe cs] <;>
          grind only
end

/-- 型付きの値では、変数の範囲にあるラムダ名の条件を別途仮定する必要がない。 -/
theorem HasTypeV.varsIn_iff_noLamNames {Ψ C Γ v a} (h : HasTypeV P B Ψ C Γ v a) (n : Nat) (pe : Nat → Prop) :
    Val.VarsIn n pe v ↔ Val.VarsInNoLamNames n pe v := by
  rw [Val.varsIn_iff_noLamNames, and_iff_left h.lambdaNamesWF]

/-- 初期の計算も、型付けから全ラムダの名前の条件を導ける。 -/
theorem HasTypeC.varsIn_iff_noLamNames {Ψ C Γ R m a ε} (h : HasTypeC P B Ψ C Γ R m a ε) (n : Nat) (pe : Nat → Prop) :
    Comp.VarsIn n pe m ↔ Comp.VarsInNoLamNames n pe m := by
  rw [Comp.varsIn_iff_noLamNames, and_iff_left h.lambdaNamesWF]

end Benitoite.Release
