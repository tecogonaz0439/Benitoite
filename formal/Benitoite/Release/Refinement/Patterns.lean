import Benitoite.Release.Refinement.RuntimeMatch
import Benitoite.Release.Refinement.RefinementObservation
import Benitoite.Release.Refinement.AtContracts
import Benitoite.Release.Refinement.TypeRenaming

/-! パターンの束縛列と、実行時の照合が読む値の形。 -/
namespace Benitoite.Release.Refinement

def unguardedPats : List Arm → List Pat
  | [] => []
  | .mk alts none _ :: arms => alts.map Alt.pat ++ unguardedPats arms
  | .mk _ (some _) _ :: arms => unguardedPats arms

def restTys (rest : Option ListRest) (a : Ty) : List Ty :=
  match rest with | some .bind => [.list a] | _ => []

mutual
  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop where
    | P_Wild {a} : PatTy P .wild a []
    | P_Var {a} : PatTy P .var a [a]
    | P_Const {c} : c.patternAllowed = true → PatTy P (.const c) (embedConst c).type []
    | P_RangeInt {lo hi : Integer64Value} :
        PatTy P (.range (.integer lo) (.integer hi)) (.base .integer) []
    | P_RangeChar {lo hi : Char} :
        PatTy P (.range (.character lo) (.character hi)) (.base .character) []
    | P_List {before rest after a δb δa} :
        PatTys P before (List.replicate before.length a) δb →
        PatTys P after (List.replicate after.length a) δa →
        (rest = none → after = []) →
        PatTy P (.list before rest after) (.list a) (δb ++ restTys rest a ++ δa)
    | P_Convert {p a b δ} : a.norm = b.norm → PatTy P p a δ → PatTy P p b (δ.map Ty.norm)
    | P_Refined {p a φ δ} : PatTy P p a δ → PatTy P p (.refined a φ) δ
    | P_Con {c ps cd ts δ} : P.cons c = some cd → ts.length = cd.ntys →
        (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) →
        PatTys P ps (cd.args.map (Ty.subst ts [])) δ →
        PatTy P (.con c ps) (.data cd.data ts) δ
  inductive PatTys (P : Program) : List Pat → List Ty → List Ty → Prop where
    | nil : PatTys P [] [] []
    | cons {p ps a as δ δs} : PatTy P p a δ → PatTys P ps as δs →
        PatTys P (p :: ps) (a :: as) (δ ++ δs)
end

/- 構成子の一覧は型付けと同じP.consを読む。篩は self で false と確定する値だけを除く。 -/
mutual
  inductive Inhabits (P : Program) : Ty → Val → Prop where
    | const {c} : Inhabits P c.type (.const c)
    | con {c ts tys args cd} : P.cons c = some cd → cd.ntys = ts.length →
        (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) →
        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
        Inhabits P (.data cd.data ts) (.con c tys args)
    | atError {detail} : ResultShape.StandardError P
        ⟨"Result", "Ok", "Error", atErrorType⟩ →
        Inhabits P atErrorType (.atError detail)
    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
    | fn {ns ps r e v} : Inhabits P (.fn ns ps r e) v
    | dependentFn {t v} : Inhabits P (.dependentFn t) v
    | tvar {i v} : Inhabits P (.tvar i) v
    | reference {a v} : Inhabits P (.reference a) v
    | lazy {a v} : Inhabits P (.lazy a) v
    | cont {b t e v} : Inhabits P (.cont b t e) v
    | map {a b v} : Inhabits P (.map a b) v
    | set {a v} : Inhabits P (.set a) v
    | bytes {v} : Inhabits P .bytes v
    | dict {cl a v} : Inhabits P (.dict cl a) v
    | tapp {i as v} : Inhabits P (.tapp i as) v
    | ctor {c v} : Inhabits P (.ctor c) v
    | external {id ts v} : Inhabits P (.external id ts) v
    | scoped {o k ix v} : Inhabits P (.scoped o k ix) v
    | pathBases {v} : Inhabits P .pathBases v
    | scopePattern {k v} : Inhabits P (.scopePattern k) v
    | refined {a p v} : Inhabits P a v → RefinementPossible p v → Inhabits P (.refined a p) v
    | checked {o r t} : Inhabits P (.opaque o (.fixed r)) (.checked t)
    | checkedRequest {o r t req} : Inhabits P (.opaque o (.fixed r)) (.checkedRequest t req)
    | checkedAtOpaque {o ix r snapshot target req} :
        Inhabits P (.opaque o ix) (.checkedAt r snapshot target req)
  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop where
    | nil : InhabitsAll P [] []
    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)
  inductive InhabitsEach (P : Program) : Ty → List Val → Prop where
    | nil {a} : InhabitsEach P a []
    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
end

def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
  ∀ v, Inhabits P a.norm v → ∃ p ∈ ps, (matchVal p v).isSome

def AltsTy (P : Program) (alts : List Alt) (a : Ty) (δ : List Ty) : Prop :=
  alts ≠ [] ∧ δ.length = Arm.bindersOf alts ∧
  (∀ alt, alts.head? = some alt → alt.slots = List.range alt.pat.binders) ∧
  ∀ alt ∈ alts, ∃ γ, PatTy P alt.pat a γ ∧
    alt.slots.Perm (List.range γ.length) ∧ selectSlots γ alt.slots = some δ

theorem AltsTy.witness {P alts a δ} (h : AltsTy P alts a δ) :
    ∃ p γ slots, PatTy P p a γ ∧ selectSlots γ slots = some δ := by
  cases alts with
  | nil => exact (h.1 rfl).elim
  | cons alt alts =>
    obtain ⟨γ, hp, _, hs⟩ := h.2.2.2 alt (by simp)
    exact ⟨alt.pat, γ, alt.slots, hp, hs⟩

end Benitoite.Release.Refinement
