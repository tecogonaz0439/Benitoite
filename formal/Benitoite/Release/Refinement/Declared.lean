import Benitoite.Release.Refinement.Kinds
import Benitoite.Release.Refinement.ValueClosed

/-!
# 観測する欄と名目の宣言の照合

有限の FieldRef 自身を証拠とせず、受け手の型と宣言表の欄型を読む。
構成子の欄は不変である。モジュールの可視性はこの表からは検査しない。
-/
namespace Benitoite.Release.Refinement

/-- data の受け手が持つ名目型と型引数。内部 snapshot は元の構成子を保つ。 -/
inductive Term.HasData (P : Program) (Γ : Ctx) : Term → DataName → List Ty → Prop where
  | var {i a d ts} : Γ[i]? = some (some a) → a.norm.core = .data d ts →
      Term.HasData P Γ (.var i) d ts
  | value {c slots d ts cd} : P.cons c = some cd → cd.data = d →
      cd.ntys = ts.length → slots.length = cd.args.length →
      Term.HasData P Γ (.dataValue c slots) d ts
  | field {ref t ts cd a d us} : Term.HasData P Γ t ref.owner ts →
      P.cons ref.constructor = some cd → cd.data = ref.owner → cd.ntys = ts.length →
      cd.args[ref.position]? = some a → a.WF 0 cd.ntys 0 → (a.subst ts []).HasSort ref.result →
      (a.subst ts []).norm.core = .data d us →
      Term.HasData P Γ (.field ref t) d us

def FieldRef.Declared (P : Program) (_C : List TParam) (Γ : Ctx) (receiver : Term) (ref : FieldRef) : Prop :=
  ∃ ts cd a, Term.HasData P Γ receiver ref.owner ts ∧
    P.cons ref.constructor = some cd ∧ cd.data = ref.owner ∧ cd.ntys = ts.length ∧
    cd.args[ref.position]? = some a ∧ a.WF 0 cd.ntys 0 ∧ (a.subst ts []).HasSort ref.result

mutual
  def Term.Declared (P : Program) (C : List TParam) (Γ : Ctx) : Term → Prop
    | .var i => Γ.Readable i
    | .field ref t => Term.Declared P C Γ t ∧ FieldRef.Declared P C Γ t ref
    | .measure _ t | .neg t | .scale _ t => Term.Declared P C Γ t
    | .add a b => Term.Declared P C Γ a ∧ Term.Declared P C Γ b
    | .listValue xs | .setValue xs => declaredSlots P C Γ xs
    | .mapValue ks vs => declaredSlots P C Γ ks ∧ declaredSlots P C Γ vs
    | .dataValue c xs => declaredSlots P C Γ xs ∧ ∃ cd, P.cons c = some cd ∧ xs.length = cd.args.length
    | _ => True
  def declaredSlot (P : Program) (C : List TParam) (Γ : Ctx) : Option Term → Prop
    | none => True
    | some t => Term.Declared P C Γ t
  def declaredSlots (P : Program) (C : List TParam) (Γ : Ctx) : List (Option Term) → Prop
    | [] => True
    | x :: xs => declaredSlot P C Γ x ∧ declaredSlots P C Γ xs
end

def Ctx.declarationSelf (Γ : Ctx) : Option Ty → Ctx
  | none => Γ
  | some a => Γ.extend a

def Pred.Declared (P : Program) (C : List TParam) (Γ : Ctx) (self : Option Ty) : Pred → Prop
  | .truth | .falsity => True
  | .eq a b | .le a b | .lt a b | .compare _ _ a b =>
      let Δ := Γ.declarationSelf self
      a.Declared P C Δ ∧ b.Declared P C Δ
  | .floatClass _ _ a | .decimalRepresented a | .charactersIn a _ _ | .member _ a _ =>
      a.Declared P C (Γ.declarationSelf self)
  | .constructorIs a c =>
      let Δ := Γ.declarationSelf self
      a.Declared P C Δ ∧ ∃ d ts cd, Term.HasData P Δ a d ts ∧ P.cons c = some cd ∧ cd.data = d
  | .and p q | .or p q => Pred.Declared P C Γ self p ∧ Pred.Declared P C Γ self q
  | .not p => Pred.Declared P C Γ self p

mutual
  def Ty.Declared (P : Program) (C : List TParam) (Γ : Ctx) : Ty → Prop
    | .base _ | .bytes | .opaque _ _ | .scoped _ _ _ | .pathBases | .scopePattern _ | .tvar _ => True
    | .data d as => (∃ n, P.DataArity d n ∧ as.length = n) ∧ declaredTys P C Γ as
    | .external _ as | .tapp _ as => declaredTys P C Γ as
    | .ctor (.data d) => ∃ n, P.DataArity d n
    | .ctor _ => True
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.Declared P C Γ a
    | .fn _ ps r e => declaredTys P C Γ ps ∧ Ty.Declared P C Γ r ∧ declaredEff P C Γ e
    | .dependentFn t => Tel.Declared P C Γ t
    | .cont b t e => Ty.Declared P C Γ b ∧ Ty.Declared P C Γ t ∧ declaredEff P C Γ e
    | .map a b => Ty.Declared P C Γ a ∧ Ty.Declared P C Γ b
    | .refined a p => Ty.Declared P C Γ a ∧ Pred.Declared P C Γ (some a) p
  def Tel.Declared (P : Program) (C : List TParam) (Γ : Ctx) : Tel → Prop
    | .done r e => Ty.Declared P C Γ r ∧ declaredEff P C Γ e
    | .param _ a t => Ty.Declared P C Γ a ∧ Tel.Declared P C (Γ.extend a) t
  def declaredTys (P : Program) (C : List TParam) (Γ : Ctx) : List Ty → Prop
    | [] => True
    | a :: as => Ty.Declared P C Γ a ∧ declaredTys P C Γ as
  def declaredEff (P : Program) (C : List TParam) (Γ : Ctx) : Eff → Prop
    | .mk _ fs => declaredTys P C Γ fs
end

/-- 欄の名前・位置と、具体化後の型から結果 sort を取り出す。 -/
theorem FieldRef.Declared.witness {P C Γ receiver ref} (h : FieldRef.Declared P C Γ receiver ref) :
    ∃ ts cd a, Term.HasData P Γ receiver ref.owner ts ∧ P.cons ref.constructor = some cd ∧
      cd.data = ref.owner ∧ cd.ntys = ts.length ∧ cd.args[ref.position]? = some a ∧
      a.WF 0 cd.ntys 0 ∧ (a.subst ts []).HasSort ref.result := h

end Benitoite.Release.Refinement
