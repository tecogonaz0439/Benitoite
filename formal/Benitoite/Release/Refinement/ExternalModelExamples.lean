import Benitoite.Release.Refinement.ExternalModelTransport
import Benitoite.Release.Refinement.ExternalSignatureLeaves

/-! # 有限の外部署名における正常受信と篩拒否 -/
namespace Benitoite.Release.Refinement.ExternalModelExamples
noncomputable section

/-- 五つの非ハンドル形。Listと同名のdataの深さは記号のまま扱う。 -/
inductive Shape where
  | unit | integer | list (depth : Nat) | data (depth : Nat) | mapKey

def filtered (a : Ty) (accept : Bool) : Ty :=
  if accept then .refined a (.not .falsity) else .refined a .falsity

def nestedType (data : Bool) : Nat → Ty → Ty
  | 0, a => a
  | n+1, a => if data then .data "ExternalBox" [nestedType data n a]
    else .list (nestedType data n a)

def nestedValue (data : Bool) (a : Ty) : Nat → Val
  | 0 => .const (.integer ⟨0,by decide⟩)
  | n+1 => if data then .con "ExternalBox.Box" [nestedType data n a] [nestedValue data a n]
    else .list [nestedValue data a n]

def Shape.type : Shape → Bool → Ty
  | .unit, b => filtered (.base .unit) b
  | .integer, b => filtered (.base .integer) b
  | .list n, b => nestedType false (n+1) (filtered (.base .integer) b)
  | .data n, b => nestedType true (n+1) (filtered (.base .integer) b)
  | .mapKey, b => .map (filtered (.base .integer) b) (.base .integer)

def Shape.raw : Shape → Bool → Val
  | .unit, _ => .const .unit
  | .integer, _ => .const (.integer ⟨0,by decide⟩)
  | .list n, b => nestedValue false (filtered (.base .integer) b) (n+1)
  | .data n, b => nestedValue true (filtered (.base .integer) b) (n+1)
  | .mapKey, _ => .mapV [.const (.integer ⟨0,by decide⟩)] [.const (.integer ⟨0,by decide⟩)]

def signature (s : Shape) (accept : Bool) : ExternalSignature :=
  ⟨⟨0⟩,"result",[],[],.done (s.type accept) Eff.empty,[]⟩

def program (s : Shape) (accept : Bool) : Program :=
  { ScopeDeclarations.program with
    cons := fun c => if c = "ExternalBox.Box" then some ⟨"ExternalBox",1,[.tvar 0]⟩
      else ScopeDeclarations.program.cons c
    externals := [(.function ⟨0⟩,.function ⟨0⟩ (signature s accept))] }

private theorem box_lookup {s b c cd} (lookup : (program s b).cons c = some cd)
    (owner : cd.data = "ExternalBox") :
    c = "ExternalBox.Box" ∧ cd = ⟨"ExternalBox",1,[.tvar 0]⟩ := by
  dsimp [program] at lookup
  split at lookup
  · cases lookup; exact ⟨by assumption,rfl⟩
  · have mem := List.lookup_eq_some_iff.mp lookup
    obtain ⟨pre,post,equal,_⟩ := mem
    have member : (c,cd) ∈ (ScopeDeclarations.http.flatMap StandardKeyTyping.DataDecl.entries) := by
      rw [equal]; simp
    obtain ⟨d, hd, he⟩ := List.mem_flatMap.mp member
    obtain ⟨_, _, eq⟩ := List.mem_map.mp he
    cases eq
    have names : ∀ d ∈ ScopeDeclarations.http, d.name ≠ "ExternalBox" := by decide
    exact absurd owner (names d hd)

private theorem box_arity (s : Shape) (b : Bool) : (program s b).DataArity "ExternalBox" 1 := by
  constructor
  · exact ⟨"ExternalBox.Box",⟨"ExternalBox",1,[.tvar 0]⟩,by simp [program],rfl⟩
  · intro c cd lookup owner
    obtain ⟨_,rfl⟩ := box_lookup lookup owner
    rfl

private theorem filtered_properties (base : BaseTy) (b : Bool) (P : Program) :
    Ty.Annotation P [] [] (filtered (.base base) b) ∧
    (filtered (.base base) b).Canonical ∧
    (filtered (.base base) b).HasKind P [] .value ∧
    (filtered (.base base) b).RowsIn (· < 0) := by
  cases b <;> refine ⟨?_,rfl,?_,?_⟩
  all_goals first
    | (constructor <;> simp [filtered,Ty.WF,Ty.Sorted,Ty.Declared,Pred.WF,Pred.Sorted,Pred.Declared,Pred.VarsIn,Ty.NotContCore])
    | (simp [filtered,Ty.HasKind,Ty.NotContCore])
    | trivial

private theorem nested_properties (isData : Bool) (n : Nat) (a : Ty) (s : Shape) (b : Bool)
    (ann : Ty.Annotation (program s b) [] [] a) (normal : a.Canonical)
    (kind : a.HasKind (program s b) [] .value) (rows : a.RowsIn (· < 0))
    (value : ∀ unit, ExternalValueType (program s b) ⟨0⟩ unit a)
    (absent : ∀ path id, ¬ ExternalOccurrence (program s b) a path id) :
    Ty.Annotation (program s b) [] [] (nestedType isData n a) ∧
    (nestedType isData n a).Canonical ∧
    (nestedType isData n a).HasKind (program s b) [] .value ∧
    (nestedType isData n a).RowsIn (· < 0) ∧
    (∀ unit, ExternalValueType (program s b) ⟨0⟩ unit (nestedType isData n a)) ∧
    (∀ path id, ¬ ExternalOccurrence (program s b) (nestedType isData n a) path id) := by
  induction n with
  | zero => exact ⟨ann,normal,kind,rows,value,absent⟩
  | succ n ih =>
    cases isData with
    | false =>
      refine ⟨⟨ih.1.wf,ih.1.sorted,ih.1.declared⟩,?_,ih.2.2.1,ih.2.2.2.1,(fun _ => .list (ih.2.2.2.2.1 false)),?_⟩
      · change Ty.list _ = Ty.list _
        exact congrArg Ty.list ih.2.1
      · intro path id h
        cases h with | element h => exact ih.2.2.2.2.2 _ _ h
    | true =>
      let t := nestedType true n a
      have sub : (Ty.tvar 0).subst [t] [] = t := by
        simpa only [Ty.Canonical,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,
          List.length_singleton,Nat.lt_irrefl,Nat.sub_zero,Nat.zero_lt_one,↓reduceIte,
          List.getElem?_cons_zero,Option.getD_some,shiftTypes_zero] using ih.2.1
      refine ⟨?_,?_,?_,?_,?_,?_⟩
      · exact ⟨⟨ih.1.wf,trivial⟩,⟨ih.1.sorted,trivial⟩,
          ⟨⟨1,box_arity s b,rfl⟩,ih.1.declared,trivial⟩⟩
      · change Ty.data _ [t.norm] = Ty.data _ [t]
        rw [ih.2.1]
      · exact ⟨TyCon.arity_data (box_arity s b),ih.2.2.1,trivial⟩
      · exact ⟨ih.2.2.2.1,trivial⟩
      · intro unit
        apply ExternalValueType.data ["ExternalBox.Box"]
        · simp
        · simp
        · intro c; constructor
          · intro mem; simp only [List.mem_singleton] at mem; subst c
            exact ⟨⟨"ExternalBox",1,[.tvar 0]⟩,by simp [program],rfl⟩
          · rintro ⟨cd,lookup,owner⟩
            exact List.mem_singleton.mpr (box_lookup lookup owner).1
        · exact box_arity s b
        · intro c cd lookup owner field member
          obtain ⟨_,rfl⟩ := box_lookup lookup owner
          simp only [List.mem_singleton] at member
          subst field
          rw [sub]
          exact ih.2.2.2.2.1 true
      · intro path id h
        cases h with
        | field lookup owner count slot occ =>
          obtain ⟨_,rfl⟩ := box_lookup lookup owner
          have member := List.mem_of_getElem? slot
          simp only [List.mem_singleton] at member
          subst_vars
          rw [sub] at occ
          exact ih.2.2.2.2.2 _ _ occ

private theorem shape_properties (s : Shape) (b : Bool) (root : Shape) (flag : Bool) :
    Ty.Annotation (program root flag) [] [] (s.type b) ∧
    (s.type b).Canonical ∧ (s.type b).HasKind (program root flag) [] .value ∧
    (s.type b).RowsIn (· < 0) ∧
    ExternalValueType (program root flag) ⟨0⟩ true (s.type b) ∧
    (∀ path id, ¬ ExternalOccurrence (program root flag) (s.type b) path id) := by
  cases s with
  | unit =>
    have prop := filtered_properties .unit b (program root flag)
    refine ⟨prop.1,prop.2.1,prop.2.2.1,prop.2.2.2,?_,?_⟩
    · cases b <;> first | exact .refined .unit | exact .refined .unit
    · cases b <;> intro path id h
      · cases h with | refined h => cases h
      · cases h with | refined h => cases h
  | integer =>
    have prop := filtered_properties .integer b (program root flag)
    refine ⟨prop.1,prop.2.1,prop.2.2.1,prop.2.2.2,?_,?_⟩
    · cases b <;> first | exact .refined (.scalar trivial) | exact .refined (.scalar trivial)
    · cases b <;> intro path id h
      · cases h with | refined h => cases h
      · cases h with | refined h => cases h
  | list n =>
    have prop := filtered_properties .integer b (program root flag)
    have value : ∀ unit, ExternalValueType (program root flag) ⟨0⟩ unit (filtered (.base .integer) b) := by
      cases b <;> intro unit
      · exact .refined (.scalar trivial)
      · exact .refined (.scalar trivial)
    have absent : ∀ path id, ¬ ExternalOccurrence (program root flag) (filtered (.base .integer) b) path id := by
      cases b <;> intro path id h
      · cases h with | refined h => cases h
      · cases h with | refined h => cases h
    have out := nested_properties false (n+1) _ root flag prop.1 prop.2.1 prop.2.2.1 prop.2.2.2 value absent
    exact ⟨out.1,out.2.1,out.2.2.1,out.2.2.2.1,out.2.2.2.2.1 true,out.2.2.2.2.2⟩
  | data n =>
    have prop := filtered_properties .integer b (program root flag)
    have value : ∀ unit, ExternalValueType (program root flag) ⟨0⟩ unit (filtered (.base .integer) b) := by
      cases b <;> intro unit
      · exact .refined (.scalar trivial)
      · exact .refined (.scalar trivial)
    have absent : ∀ path id, ¬ ExternalOccurrence (program root flag) (filtered (.base .integer) b) path id := by
      cases b <;> intro path id h
      · cases h with | refined h => cases h
      · cases h with | refined h => cases h
    have out := nested_properties true (n+1) _ root flag prop.1 prop.2.1 prop.2.2.1 prop.2.2.2 value absent
    exact ⟨out.1,out.2.1,out.2.2.1,out.2.2.2.1,out.2.2.2.2.1 true,out.2.2.2.2.2⟩
  | mapKey =>
    have prop := filtered_properties .integer b (program root flag)
    refine ⟨⟨⟨prop.1.wf,trivial⟩,⟨prop.1.sorted,trivial⟩,⟨prop.1.declared,trivial⟩⟩,?_,
      ⟨prop.2.2.1,trivial⟩,⟨prop.2.2.2,trivial⟩,?_,?_⟩
    · cases b <;> rfl
    · exact .map (by cases b <;> exact ⟨trivial,by decide,by decide⟩) (.scalar trivial)
    · intro path id h
      cases h with
      | key h => exact (ExternalSignatureLeaves.key_no_occurrence
            (a := filtered (.base .integer) b)
            (by cases b <;> exact ⟨trivial,by decide,by decide⟩)) h
      | value h => cases h

/-- 全ての深さで、有限の外部署名は八欄の整形式条件を満たす。 -/
theorem program_externalWF (s : Shape) (b : Bool) : (program s b).ExternalWF := by
  have prop := shape_properties s b s b
  have wf : (signature s b).WF (program s b) := by
    refine ⟨rfl,rfl,?_,⟨prop.2.2.1,by simp [kindsEff,kindsList,Eff.empty]⟩,?_,by simp [signature],.done prop.2.2.2.2.1 rfl,?_⟩
    · exact ⟨⟨prop.1.wf,trivial,rfl⟩,⟨prop.1.sorted,trivial⟩,⟨prop.1.declared,trivial⟩⟩
    · intro use
      simp only [signature,List.not_mem_nil,false_iff]
      intro site
      cases site with | result occurrence => exact prop.2.2.2.2.2 _ _ occurrence
    · exact ⟨prop.2.2.2.1,by simp [Eff.RowsIn,Ty.RowsInList,Eff.empty]⟩
  exact ⟨by simp [program],by
    intro key decl member
    simp only [program,List.mem_singleton,Prod.mk.injEq] at member
    rcases member with ⟨rfl,rfl⟩
    exact ⟨rfl,wf⟩⟩

/-- ストアを制限せず、同じ表と宣言の型付き入力を供給する。 -/
theorem arguments (s : Shape) (b : Bool) (B : Builtins) (Ψ : StoreTy) :
    ExternalArgs (program s b) B Ψ (signature s b) [] [] (s.type b) Eff.empty := by
  have prop := shape_properties s b s b
  have bind : Tel.bind (typeEnv []) (signature s b).parameters = .done (s.type b) Eff.empty := by
    have h := Tel.substAt_nil_of_wf (c := 0) [] (signature s b).parameters
      ⟨prop.1.wf,trivial,rfl⟩
    change Tel.bind (typeEnv []) (signature s b).parameters = _ at h
    simpa only [signature,Tel.norm,show (s.type b).norm = s.type b from prop.2.1,
      show Eff.norm Eff.empty = Eff.empty from rfl] using h
  refine ⟨⟨rfl,⟨rfl,by intros i t k hi; cases hi⟩,
    ⟨rfl,by intros i t p hi; cases hi⟩,by simp [TypeAnnotations]⟩,?_,by simp,by simp,
    ⟨prop.1.wf,prop.2.1⟩,⟨trivial,rfl⟩⟩
  rw [bind]
  exact .done ⟨⟨prop.1.wf,trivial,rfl⟩,⟨prop.1.sorted,trivial⟩,⟨prop.1.declared,trivial⟩⟩

private theorem nested_carrier (isData : Bool) (n : Nat) (b : Bool) (s : Shape)
    (flag : Bool) (B : Builtins) (Ψ : StoreTy) :
    ExternalCarrier (program s flag) B Ψ
      (nestedValue isData (filtered (.base .integer) b) n)
      (nestedType isData n (filtered (.base .integer) b)) := by
  have prop := filtered_properties .integer b (program s flag)
  have value : ∀ unit, ExternalValueType (program s flag) ⟨0⟩ unit (filtered (.base .integer) b) := by
    cases b <;> intro unit
    · exact .refined (.scalar trivial)
    · exact .refined (.scalar trivial)
  have absent : ∀ path id, ¬ ExternalOccurrence (program s flag)
      (filtered (.base .integer) b) path id := by
    cases b <;> intro path id h
    · cases h with | refined h => cases h
    · cases h with | refined h => cases h
  have props := fun n => nested_properties isData n _ s flag prop.1 prop.2.1
    prop.2.2.1 prop.2.2.2 value absent
  induction n with
  | zero =>
    cases b with
    | false => exact .refined (.scalar (.V_Const trivial)) prop.1
    | true => exact .refined (.scalar (.V_Const trivial)) prop.1
  | succ n ih =>
    cases isData with
    | false => exact .list (.cons ih .nil) (props n).1
    | true =>
      let t := nestedType true n (filtered (.base .integer) b)
      have sub : (Ty.tvar 0).subst [t] [] = t := by
        simpa only [Ty.Canonical,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,
          List.length_singleton,Nat.lt_irrefl,Nat.sub_zero,Nat.zero_lt_one,↓reduceIte,
          List.getElem?_cons_zero,Option.getD_some,shiftTypes_zero] using (props n).2.1
      apply ExternalCarrier.data (cd := ⟨"ExternalBox",1,[.tvar 0]⟩)
      · simp [program]
      · rfl
      · refine ⟨rfl,?_⟩
        intro i arg k ht hk
        have member :=  List.mem_of_getElem? ht
        have kt := List.mem_of_getElem? hk
        simp only [List.mem_singleton] at member
        have keq : k = .value := by simpa using kt
        subst arg; subst k
        exact ⟨(props n).2.2.1,by
          cases n <;> cases b <;> simp [nestedType,filtered]⟩
      · intro a mem; simp only [List.mem_singleton] at mem; subst a; exact Nat.zero_lt_one
      · change ExternalCarrierFields _ _ _ [_] [Ty.subst [t] [] (.tvar 0)]
        rw [sub]
        exact .cons ih .nil
      · exact (props (n+1)).1

private theorem shape_carrier (s : Shape) (b : Bool) (B : Builtins)
    (keys : B.sat [] (filtered (.base .integer) b).norm TParam.keyC) (Ψ : StoreTy) :
    ExternalCarrier (program s b) B Ψ (s.raw b) (s.type b) := by
  cases s with
  | unit =>
    cases b with
    | false => exact .refined (.scalar (.V_Const trivial)) (filtered_properties .unit false _).1
    | true => exact .refined (.scalar (.V_Const trivial)) (filtered_properties .unit true _).1
  | integer => exact nested_carrier false 0 b .integer b B Ψ
  | list n => exact nested_carrier false (n+1) b (.list n) b B Ψ
  | data n => exact nested_carrier true (n+1) b (.data n) b B Ψ
  | mapKey =>
    have scalar : ExternalCarrier (program .mapKey b) B Ψ
        (.const (.integer ⟨0,by decide⟩)) (filtered (.base .integer) b) :=
      nested_carrier false 0 b .mapKey b B Ψ
    exact .map (.cons scalar .nil) (.cons (.scalar (.V_Const trivial)) .nil) rfl keys
      (filtered_properties .integer b _).1 ⟨trivial,trivial,trivial⟩

private theorem nested_normal (isData : Bool) (n : Nat) (b : Bool) :
    (nestedType isData n (filtered (.base .integer) b)).norm =
      nestedType isData n (filtered (.base .integer) b) := by
  induction n with
  | zero => cases b <;> rfl
  | succ n ih =>
    cases isData with
    | false => exact congrArg Ty.list ih
    | true => exact congrArg (fun a => Ty.data "ExternalBox" [a]) ih


private theorem nested_ground (isData : Bool) (n : Nat) (b : Bool) :
    (nestedValue isData (filtered (.base .integer) b) n).Ground := by
  have hw : ∀ n, (nestedType isData n (filtered (.base .integer) b)).WF 0 0 0 := by
    intro n
    induction n with
    | zero => exact (filtered_properties .integer b ScopeDeclarations.program).1.wf
    | succ n ih => cases isData <;> simp_all [nestedType,Ty.WF,Ty.WFList]
  induction n with
  | zero => trivial
  | succ n ih =>
    cases isData with
    | false => exact ⟨ih,trivial⟩
    | true => exact ⟨by intro a mem; simp only [List.mem_singleton] at mem; subst a; exact hw n,
        ih,trivial⟩

private theorem nested_check (isData : Bool) (n : Nat) (b : Bool) (s : Shape) (flag : Bool) :
    externalCheck (program s flag) (nestedValue isData (filtered (.base .integer) b) n)
      (nestedType isData n (filtered (.base .integer) b)) = b := by
  induction n with
  | zero => cases b <;> simp [nestedType,nestedValue,filtered,externalCheck,Const.type,Val.toTerm?,Ty.sort?,Pred.open,predBind,Pred.closedTrue,Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalWith,Pred.atomValue,Pred.atomReady]
  | succ n ih =>
    cases isData with
    | false => simpa [nestedType,nestedValue,externalCheck,externalCheckEach] using ih
    | true =>
      have sub : Ty.subst [nestedType true n (filtered (.base .integer) b)] [] (.tvar 0) =
          nestedType true n (filtered (.base .integer) b) := by
        simpa only [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,
          List.length_singleton,Nat.lt_irrefl,Nat.sub_zero,Nat.zero_lt_one,↓reduceIte,
          List.getElem?_cons_zero,Option.getD_some,shiftTypes_zero] using nested_normal true n b
      simpa [nestedType,nestedValue,externalCheck,program,externalCheckFields,sub] using ih

private theorem shape_ground (s : Shape) (b : Bool) : (s.raw b).Ground := by
  cases s with
  | unit | integer | mapKey => trivial
  | list n => exact nested_ground false (n+1) b
  | data n => exact nested_ground true (n+1) b

private theorem shape_check (s : Shape) (b : Bool) :
    externalCheck (program s b) (s.raw b) (s.type b) = b := by
  cases s with
  | unit | integer | mapKey => cases b <;> simp [Shape.type,Shape.raw,filtered,externalCheck,externalCheckEach,Const.type,Val.toTerm?,Ty.sort?,Pred.open,predBind,Pred.closedTrue,Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalWith,Pred.atomValue,Pred.atomReady]
  | list n => exact nested_check false (n+1) b _ b
  | data n => exact nested_check true (n+1) b _ b

/-- 同じ有限宣言の型付き入力に、正常な生の値又は篩違反の生の値を供給する。 -/
theorem raw_response (s : Shape) (b : Bool) (base : Builtins)
    (keys : base.sat [] (filtered (.base .integer) b).norm TParam.keyC)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) (Ψ : StoreTy) :
    (program s b).ExternalWF ∧
    ExternalArgs (program s b) (ExternalModel.builtins (program s b) base release) Ψ
      (signature s b) [] [] (s.type b) Eff.empty ∧
    (ExternalModel.builtins (program s b) base release).externalResponse ⟨0⟩ [] []
      (.val (s.raw b)) [] ∧ externalCheck (program s b) (s.raw b) (s.type b) = b := by
  have args := arguments s b base Ψ
  exact ⟨program_externalWF s b, arguments s b _ Ψ,
    ExternalModel.response_value (by simp [program,Program.externalFunction]) args.instantiate
      (shape_carrier s b base keys) (shape_ground s b),shape_check s b⟩

/-- 正常側は受信値の型・閉性・全σの適格性を、拒否側は篩エラーと全σの適格性を示す。 -/
theorem receive_pair (s : Shape) (base : Builtins)
    (keys : ∀ b, base.sat [] (filtered (.base .integer) b).norm TParam.keyC)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) (Ψ : StoreTy) (σ : PathEnv) :
    (externalReceive (program s true) (signature s true) [] [] (.val (s.raw true)) =
      some (.val (s.raw true)) ∧
      HasTypeV (program s true) (ExternalModel.builtins (program s true) base release) Ψ [] [] []
        (s.raw true) (s.type true) ∧ (s.raw true).Ground ∧ (s.raw true).Adequate σ) ∧
    (externalReceive (program s false) (signature s false) [] [] (.val (s.raw false)) =
      some (.err "ExternalRefinement") ∧ (s.raw false).Adequate σ) := by
  have good := raw_response s true base (keys true) release Ψ
  have bad := raw_response s false base (keys false) release Ψ
  have lookup : ∀ b, (program s b).externalFunction ⟨0⟩ = some (signature s b) := by
    intro b; simp [program,Program.externalFunction]
  exact ⟨ExternalModel.receive_value good.1 (lookup true) good.2.1 good.2.2.1 good.2.2.2 σ,
    (ExternalModel.receive_reject bad.1 (lookup false) bad.2.1 bad.2.2.1 bad.2.2.2).1,
    (ExternalModel.receive_reject bad.1 (lookup false) bad.2.1 bad.2.2.1 bad.2.2.2).2.1 σ⟩

/-- 整数の値を読む篩 `0 < self`。 -/
def positiveType : Ty := .refined (.base .integer) (.lt (.integer 0) (.var 0))

def positiveSignature : ExternalSignature :=
  ⟨⟨0⟩,"positive",[],[],.done positiveType Eff.empty,[]⟩

def positiveProgram : Program :=
  { ScopeDeclarations.program with
    externals := [(.function ⟨0⟩,.function ⟨0⟩ positiveSignature)] }

/-- 一つの宣言と表で、`0 < self` が1を正常受信し0を篩拒否する。 -/
theorem positive_receive_pair (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) (Ψ : StoreTy) (σ : PathEnv) :
    positiveProgram.ExternalWF ∧
    ExternalArgs positiveProgram (ExternalModel.builtins positiveProgram base release) Ψ
      positiveSignature [] [] positiveType Eff.empty ∧
    (ExternalModel.builtins positiveProgram base release).externalResponse ⟨0⟩ [] []
      (.val (.const (.integer ⟨1,by decide⟩))) [] ∧
    (ExternalModel.builtins positiveProgram base release).externalResponse ⟨0⟩ [] []
      (.val (.const (.integer ⟨0,by decide⟩))) [] ∧
    (externalReceive positiveProgram positiveSignature [] [] (.val (.const (.integer ⟨1,by decide⟩))) =
      some (.val (.const (.integer ⟨1,by decide⟩))) ∧
      HasTypeV positiveProgram (ExternalModel.builtins positiveProgram base release) Ψ [] [] []
        (.const (.integer ⟨1,by decide⟩)) positiveType ∧
      (Val.const (.integer ⟨1,by decide⟩)).Ground ∧
      (Val.const (.integer ⟨1,by decide⟩)).Adequate σ) ∧
    (externalReceive positiveProgram positiveSignature [] [] (.val (.const (.integer ⟨0,by decide⟩))) =
      some (.err "ExternalRefinement") ∧ (Val.const (.integer ⟨0,by decide⟩)).Adequate σ) := by
  have ann : Ty.Annotation positiveProgram [] [] positiveType := by
    constructor <;> simp [positiveType,Ty.WF,Ty.Sorted,Ty.Declared,Pred.WF,Pred.VarsIn,
      Pred.Sorted,Pred.Declared,Ty.NotContCore,Term.VarsIn,Term.HasSort,Term.References,
      Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Term.Declared,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Ty.core]
  have wf : positiveProgram.ExternalWF := by
    have signatureWF : positiveSignature.WF positiveProgram := by
      refine ⟨rfl,rfl,?_,⟨by simp [positiveType,Ty.HasKind,Ty.NotContCore],by simp [kindsEff,kindsList,Eff.empty]⟩,?_,
        by simp [positiveSignature],.done (.refined (.scalar trivial)) rfl,?_⟩
      · exact ⟨⟨ann.wf,trivial,rfl⟩,⟨ann.sorted,trivial⟩,⟨ann.declared,trivial⟩⟩
      · intro use
        simp only [positiveSignature,List.not_mem_nil,false_iff]
        intro site
        cases site with | result occurrence => cases occurrence with | refined h => cases h
      · exact ⟨trivial,by simp [Eff.RowsIn,Ty.RowsInList,Eff.empty]⟩
    refine ⟨by simp [positiveProgram],?_⟩
    intro key decl member
    simp only [positiveProgram,List.mem_singleton,Prod.mk.injEq] at member
    rcases member with ⟨rfl,rfl⟩
    exact ⟨rfl,signatureWF⟩
  have args : ∀ B, ExternalArgs positiveProgram B Ψ positiveSignature [] [] positiveType Eff.empty := by
    intro B
    refine ⟨⟨rfl,⟨rfl,by intros i t k hi; cases hi⟩,
      ⟨rfl,by intros i t p hi; cases hi⟩,by simp [TypeAnnotations]⟩,?_,by simp,by simp,
      ⟨ann.wf,rfl⟩,⟨trivial,rfl⟩⟩
    have bind : Tel.bind (typeEnv []) positiveSignature.parameters = .done positiveType Eff.empty := by
      have h := Tel.substAt_nil_of_wf (c := 0) [] positiveSignature.parameters ⟨ann.wf,trivial,rfl⟩
      change Tel.bind (typeEnv []) positiveSignature.parameters = _ at h
      simpa only [positiveSignature,Tel.norm,show positiveType.norm = positiveType from rfl,
        show Eff.norm Eff.empty = Eff.empty from rfl] using h
    rw [bind]
    exact .done ⟨⟨ann.wf,trivial,rfl⟩,⟨ann.sorted,trivial⟩,⟨ann.declared,trivial⟩⟩
  have lookup : positiveProgram.externalFunction ⟨0⟩ = some positiveSignature := rfl
  have raw : ∀ (i : Integer64Value),
      (ExternalModel.builtins positiveProgram base release).externalResponse ⟨0⟩ [] []
        (.val (.const (.integer i))) [] := by
    intro i
    exact ExternalModel.response_value lookup (args base).instantiate
      (fun _ => .refined (.scalar (.V_Const trivial)) ann) (by trivial)
  have good : externalCheck positiveProgram (.const (.integer ⟨1,by decide⟩)) positiveType = true := by
    simp [positiveType,externalCheck,Const.type,Val.toTerm?,Ty.sort?,Pred.open,predBind,
      Pred.closedTrue,Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalWith,
      Pred.atomValue,Pred.atomReady,Term.VarsIn,Term.HasSort,Term.References,Term.Shape,
      termReady,integerAs,Integer64Value.toInt,Term.observe,Observation.sort,observeAs,Term.interpret]
  have bad : externalCheck positiveProgram (.const (.integer ⟨0,by decide⟩)) positiveType = false := by
    simp [positiveType,externalCheck,Const.type,Val.toTerm?,Ty.sort?,Pred.open,predBind,
      Pred.closedTrue,Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalWith,
      Pred.atomValue,Pred.atomReady,Term.VarsIn,Term.HasSort,Term.References,Term.Shape,
      termReady,integerAs,Integer64Value.toInt,Term.observe,Observation.sort,observeAs,Term.interpret]
  exact ⟨wf,args _,raw ⟨1,by decide⟩,raw ⟨0,by decide⟩,
    ExternalModel.receive_value wf lookup (args _) (raw ⟨1,by decide⟩) good σ,
    (ExternalModel.receive_reject (release := release) wf lookup (args _) (raw ⟨0,by decide⟩) bad).1,
    (ExternalModel.receive_reject (release := release) wf lookup (args _) (raw ⟨0,by decide⟩) bad).2.1 σ⟩

/-- 同じ宣言の二つの生応答から、値に依存する受理と拒否を読む。 -/
example (base : Builtins) (release : Val → Option Benitoite.Release.ErrKind → Prop)
    (Ψ : StoreTy) (σ : PathEnv) :
    externalReceive positiveProgram positiveSignature [] [] (.val (.const (.integer ⟨1,by decide⟩))) =
      some (.val (.const (.integer ⟨1,by decide⟩))) ∧
    externalReceive positiveProgram positiveSignature [] [] (.val (.const (.integer ⟨0,by decide⟩))) =
      some (.err "ExternalRefinement") := by
  have pair := positive_receive_pair base release Ψ σ
  exact ⟨pair.2.2.2.2.1.1,pair.2.2.2.2.2.1⟩

def handleDeclaration : ExternalTypeDecl := ⟨⟨0⟩,⟨0⟩,"Handle",0,0⟩
def handle (identity : Nat) : Val := .externalHandle ⟨⟨0⟩,⟨0⟩,0,identity⟩ []
def handleType (b : Bool) : Ty := if b then .external ⟨0⟩ [] else filtered (.external ⟨0⟩ []) false

def handleSignature (b : Bool) : ExternalSignature :=
  { ExternalSignatureLeaves.handleSignature ⟨0⟩ "state" ⟨0⟩ with
    parameters := .param "handle" (.external ⟨0⟩ [])
      (.done (handleType b) ExternalSignatureLeaves.stateEffect) }

def handleProgram (b : Bool) : Program :=
  { ScopeDeclarations.program with externals := [(.type ⟨0⟩,.type handleDeclaration),
    (.function ⟨0⟩,.function ⟨0⟩ (handleSignature b))] }

private theorem handle_annotation (b flag : Bool) (Γ : Ctx) :
    Ty.Annotation (handleProgram flag) [] Γ (handleType b) := by
  cases b <;> constructor
  all_goals simp [handleType,filtered,Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,Ty.Declared,declaredTys,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Ty.NotContCore,handleProgram,
    Program.externalType,handleDeclaration]

private theorem handle_signature_wf (b : Bool) : (handleSignature b).WF (handleProgram b) := by
  have original := ExternalSignatureLeaves.handle_wf (P := handleProgram b) handleDeclaration
    (by simp [handleProgram,handleDeclaration,Program.externalType]) rfl "state"
  cases b with
  | true => exact original
  | false =>
    refine {original with annotation := ?_,kinded := ?_,uses_exact := ?_,shape := ?_}
    · constructor
      · exact ⟨trivial,⟨(handle_annotation false false [some (.external ⟨0⟩ [])]).wf,trivial,rfl⟩⟩
      · exact ⟨trivial,(handle_annotation false false [some (.external ⟨0⟩ [])]).sorted,trivial⟩
      · exact ⟨(handle_annotation true false []).declared,(handle_annotation false false [some (.external ⟨0⟩ [])]).declared,trivial⟩
    · exact ⟨trivial,⟨trivial,by intros a t e h; cases h⟩,by simp [kindsEff,kindsList,ExternalSignatureLeaves.stateEffect]⟩
    · intro use
      change use ∈ (ExternalSignatureLeaves.handleSignature handleDeclaration.component "state" handleDeclaration.id).uses ↔ _
      rw [original.uses_exact use]
      constructor
      · intro h; cases h with
        | argument h => exact .argument h
        | next h => cases h with | result h => exact .next (.result (.refined h))
      · intro h; cases h with
        | argument h => exact .argument h
        | next h => cases h with | result h => cases h with | refined h => exact .next (.result h)
    · exact .param (.handle (td := handleDeclaration) (by simp [handleProgram,handleDeclaration,Program.externalType]) rfl rfl rfl rfl)
        (.done (.refined (.handle (td := handleDeclaration) (by simp [handleProgram,handleDeclaration,Program.externalType]) rfl rfl rfl rfl)) rfl)

/-- borrowの実ハンドル引数とownの篩付き結果を持つ、同じ有限宣言の整形式性。 -/
theorem handle_program_externalWF (b : Bool) : (handleProgram b).ExternalWF := by
  refine ⟨by simp [handleProgram],?_⟩
  intro key decl mem
  simp only [handleProgram,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · exact ⟨rfl,rfl⟩
  · exact ⟨rfl,handle_signature_wf b⟩

/-- 同じ宣言表で、実際のborrow引数とStateを持つ全ストアの入力を構成する。 -/
theorem handle_arguments (b : Bool) (B : Builtins) (Ψ : StoreTy) (identity : Nat) :
    ExternalArgs (handleProgram b) B Ψ (handleSignature b) [] [handle identity]
      (handleType b) ExternalSignatureLeaves.stateEffect := by
  have original := ExternalSignatureLeaves.handle_arguments (P := handleProgram b) B Ψ handleDeclaration
    (by simp [handleProgram,Program.externalType,handleDeclaration]) rfl identity
  cases b with
  | true => exact original
  | false =>
    refine ⟨⟨rfl,⟨rfl,by intros i t k hi; cases hi⟩,
      ⟨rfl,by intros i t p hi; cases hi⟩,by simp [TypeAnnotations]⟩,?_,original.ground,
      original.types,⟨(handle_annotation false false []).wf,rfl⟩,original.effect⟩
    have doneArgs := HasTypeTelArgsQ.done (P := handleProgram false) (B := B) (Ψ := Ψ)
      (Q := Qempty) (Φ := [])
      (show Ty.Annotation (handleProgram false) [] []
        (.dependentFn (.done (handleType false) ExternalSignatureLeaves.stateEffect)) from
        ⟨⟨(handle_annotation false false []).wf,trivial,rfl⟩,
          ⟨(handle_annotation false false []).sorted,trivial⟩,
          ⟨(handle_annotation false false []).declared,trivial⟩⟩)
    have typed := (ExternalSignatureLeaves.handle_typed_iff (P := handleProgram false)
      (B := B) (Ψ := Ψ) (Q := Qempty) (Φ := []) ⟨⟨0⟩,⟨0⟩,0,identity⟩ handleDeclaration
      (by simp [handleProgram,Program.externalType]) rfl (handle_annotation true false [])).mpr ⟨rfl,rfl⟩
    have tail : HasTypeTelArgsQ (handleProgram false) B Ψ Qempty [] [] [] []
        (Tel.bind (Tel.argumentsEnv (handle identity)) (.done (handleType false) ExternalSignatureLeaves.stateEffect))
        (handleType false) ExternalSignatureLeaves.stateEffect := by
      simpa only [handleType,filtered,Bool.false_eq_true,↓reduceIte,handle,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Tel.norm,
        Ty.norm,Ty.normTys,ExternalSignatureLeaves.stateEffect,Eff.rawBind,Tel.argumentsEnv,valEnv,
        instAtoms_nil,substAtoms_nil,rowFails,List.length_nil,List.range_zero,List.filter_nil,
        List.flatMap_nil,List.append_nil,Eff.norm,Order.sortUnique,predBind,Ty.refineNorm,Ty.core,Ty.refinementPredicates,Pred.conjuncts,Ty.packRefinements,Pred.ofConjuncts,List.nil_append] using doneArgs
    have args := HasTypeTelArgsQ.param (name := "handle") (handle_annotation true false []) typed tail
    simpa only [handleSignature,ExternalSignatureLeaves.handleSignature,handleType,filtered,Bool.false_eq_true,↓reduceIte,handle,
      Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Tel.norm,Ty.norm,Ty.normTys,
      ExternalSignatureLeaves.stateEffect,Eff.rawBind,typeEnv,typeEnvAt,SubstEnv.up,
      instAtoms_nil,substAtoms_nil,List.map_nil,rowFails,List.length_nil,List.range_zero,
      List.filter_nil,List.flatMap_nil,List.append_nil,Eff.norm,Order.sortUnique,predBind,Ty.refineNorm,Ty.core,Ty.refinementPredicates,Pred.conjuncts,Ty.packRefinements,Pred.ofConjuncts,List.nil_append] using args

/-- 同じ型ID/component/resourceの正常値も篩違反値も、生応答の関係に入る。 -/
theorem handle_raw_response (b : Bool) (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) (Ψ : StoreTy) (identity : Nat) :
    (handleProgram b).ExternalWF ∧
    ExternalArgs (handleProgram b) (ExternalModel.builtins (handleProgram b) base release) Ψ
      (handleSignature b) [] [handle identity] (handleType b) ExternalSignatureLeaves.stateEffect ∧
    (ExternalModel.builtins (handleProgram b) base release).externalResponse ⟨0⟩ [] [handle identity]
      (.val (handle identity)) [] ∧ externalCheck (handleProgram b) (handle identity) (handleType b) = b := by
  have carrier : ∀ Ψ, ExternalCarrier (handleProgram b) base Ψ (handle identity) (handleType b) := by
    intro store
    have typed := (ExternalSignatureLeaves.handle_typed_iff (P := handleProgram b)
      (B := base) (Ψ := store) (Q := Qempty) (Φ := []) ⟨⟨0⟩,⟨0⟩,0,identity⟩ handleDeclaration
      (by simp [handleProgram,Program.externalType]) rfl (handle_annotation true b [])).mpr ⟨rfl,rfl⟩
    cases b with
    | true => exact .handle typed
    | false => exact .refined (.handle typed) (handle_annotation false false [])
  exact ⟨handle_program_externalWF b,handle_arguments b _ Ψ identity,
    ExternalModel.response_value (by rfl)
      (handle_arguments b base Ψ identity).instantiate carrier (by simp [handle,Val.Ground,Val.ClosedAt]),
    by cases b <;> simp [handle,handleType,filtered,externalCheck,Ty.sort?,Pred.closedTrue,
      Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalWith,Pred.atomValue,Pred.atomReady]⟩

/-- 実ハンドルの受信でも、正常・篩拒否・err・exitの四葉を同じ宣言へ接続する。 -/
theorem handle_receive_pair (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop)
    (Ψ : StoreTy) (σ : PathEnv) (identity : Nat) :
    (externalReceive (handleProgram true) (handleSignature true) [] [handle identity]
      (.val (handle identity)) = some (.val (handle identity)) ∧
      HasTypeV (handleProgram true) (ExternalModel.builtins (handleProgram true) base release) Ψ [] [] []
        (handle identity) (handleType true) ∧ (handle identity).Ground ∧ (handle identity).Adequate σ) ∧
    (externalReceive (handleProgram false) (handleSignature false) [] [handle identity]
      (.val (handle identity)) = some (.err "ExternalRefinement") ∧ (handle identity).Adequate σ) ∧
    (∀ b r, (ExternalModel.builtins (handleProgram b) base release).externalResponse ⟨0⟩ [] [handle identity] (.err r) [] ∧
      externalReceive (handleProgram b) (handleSignature b) [] [handle identity] (.err r) = some (.err r) ∧
      ∀ n obs, ¬ (ExternalModel.builtins (handleProgram b) base release).externalResponse ⟨0⟩ [] [handle identity] (.exit n) obs) := by
  have good := handle_raw_response true base release Ψ identity
  have bad := handle_raw_response false base release Ψ identity
  have lookup : ∀ b, (handleProgram b).externalFunction ⟨0⟩ = some (handleSignature b) := by intro b; rfl
  exact ⟨ExternalModel.receive_value good.1 (lookup true) good.2.1 good.2.2.1 good.2.2.2 σ,
    ⟨(ExternalModel.receive_reject bad.1 (lookup false) bad.2.1 bad.2.2.1 bad.2.2.2).1,
     (ExternalModel.receive_reject bad.1 (lookup false) bad.2.1 bad.2.2.1 bad.2.2.2).2.1 σ⟩,
    fun b r => ExternalModel.receive_error_no_exit (release := release) (handle_arguments b _ Ψ identity) (lookup b) r⟩

/-- 入れ子のdata `ExternalBox` と外部関数の宣言を加えても、範囲IOが読むHTTP宣言の欄とarityは変わらない。 -/
theorem program_hasHttp (s : Shape) (b : Bool) : ScopeDeclarations.HasHttp (program s b) := by
  intro d hd
  have old := ScopeDeclarations.program_hasHttp d hd
  have different : d.name ≠ "ExternalBox" := by
    have names : ∀ d ∈ ScopeDeclarations.http, d.name ≠ "ExternalBox" := by decide
    exact names d hd
  have preserve : ∀ c cd, ScopeDeclarations.program.cons c = some cd → (program s b).cons c = some cd := by
    intro c cd lookup
    have diff : c ≠ "ExternalBox.Box" := by intro eq; subst c; cases lookup
    simpa only [program,ite_eq_right diff] using lookup
  refine ⟨⟨?_,?_⟩,?_⟩
  · obtain ⟨c,cd,lookup,owner⟩ := old.1.1
    exact ⟨c,cd,preserve c cd lookup,owner⟩
  · intro c cd lookup owner
    dsimp [program] at lookup
    split at lookup
    · cases lookup
      exact (different owner.symm).elim
    · exact old.1.2 c cd lookup owner
  · intro c member
    exact preserve _ _ (old.2 c member)

/-- ハンドルの専用表は通常の構成子宣言を変更しない。 -/
theorem handle_program_hasHttp (b : Bool) : ScopeDeclarations.HasHttp (handleProgram b) :=
  ScopeDeclarations.program_hasHttp

end
end Benitoite.Release.Refinement.ExternalModelExamples
