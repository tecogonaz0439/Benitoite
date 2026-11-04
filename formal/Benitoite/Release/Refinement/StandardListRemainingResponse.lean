import Benitoite.Release.Refinement.StandardListResponse
import Benitoite.Release.Refinement.StandardPureResults
import Init.Data.List.Sort.Lemmas

/-! Listの切出し・構造比較・整列と整数列の通常応答。
構造Equalityのfuelは左snapshotの入れ子の深さで初期化する。
Map縮約後のvalueは元valueの部分木なので深さは増えない。
この深さ境界とRust/Leanの全交換はこの通常型契約とは別に検証する。
-/
namespace Benitoite.Release.Refinement.StandardListRemainingResponse
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 2000000
open StandardCollections StandardScalar

mutual
 def snapshotDepth : Observation → Nat
  | .listValue xs | .setValue xs | .dataValue _ xs => slotDepth xs+1
  | .mapValue ks vs => max (slotDepth ks) (slotDepth vs)+1
  | _ => 1
 def slotDepth : List (Option Observation) → Nat
  | [] => 0
  | none::xs => slotDepth xs
  | some x::xs => max (snapshotDepth x) (slotDepth xs)
end

/-- スロット欠けを成功扱いせず、IEEE Equalityを構造の各葉で計算する。 -/
def equalityFuel : Nat → Observation → Observation → Option Bool
 | 0,_,_ => none
 | n+1,left,right =>
  let rec slots : List (Option Observation) → List (Option Observation) → Option Bool
   | [],[] => some true
   | [],_::_ | _::_,[] => some false
   | some a::as,some b::bs => do
      if ← equalityFuel n a b then slots as bs else some false
   | _,_ => none
  let rec entries : List (List Nat × Option Observation) → List (List Nat × Option Observation) → Option Bool
   | [],[] => some true
   | [],_::_ | _::_,[] => some false
   | (k,some a)::as,(l,some b)::bs =>
      if k != l then some false else do
       if ← equalityFuel n a b then entries as bs else some false
   | _,_ => none
  match left,right with
  | .integer a,.integer b => some (a==b)
  | .character a,.character b => some (a==b)
  | .float64 a,.float64 b => some (ieeeCompare 52 11 a.toNat b.toNat .eq)
  | .float32 a,.float32 b => some (ieeeCompare 23 8 a.toNat b.toNat .eq)
  | .decimal a s,.decimal b t => some (a * (10:Int)^t == b * (10:Int)^s)
  | .boolean a,.boolean b => some (a==b)
  | .unitValue,.unitValue => some true
  | .string a,.string b => some (a==b)
  | .bytesValue a,.bytesValue b =>
      if a.all (·≤255) && b.all (·≤255) then some (a==b) else none
  | .listValue a,.listValue b => if a.length != b.length then some false else slots a b
  | .dataValue c a,.dataValue d b => if c != d || a.length != b.length then some false else slots a b
  | .mapValue ks vs,.mapValue ls ws => do
      let a ← mapKeys ks vs
      let b ← mapKeys ls ws
      entries (a.mergeSort (fun a b => compare a.1 b.1 != .gt))
        (b.mergeSort (fun a b => compare a.1 b.1 != .gt))
  | .setValue a,.setValue b => do
      let x ← keySetCodes a []
      let y ← keySetCodes b []
      some (sortCodes x == sortCodes y)
  | _,_ => none

def structuralEqual (a b : Val) : Option Bool := do
 let x ← a.toTerm?.bind (fun t => t.observe (fun _ => none))
 let y ← b.toTerm?.bind (fun t => t.observe (fun _ => none))
 equalityFuel (snapshotDepth x) x y

def containsResult : List Val → Val → Option Bool
 | [],_ => some false
 | a::as,b => do if ← structuralEqual a b then some true else containsResult as b

private def floatOrder (m e a b : Nat) : Ordering :=
 if ieeeNaN m e a then if ieeeNaN m e b then .eq else .gt
 else if ieeeNaN m e b then .lt
 else if ieeeCompare m e a b .lt then .lt
 else if ieeeCompare m e a b .gt then .gt else .eq

/-- Rust List.sortの比較器。NaNは最後、符号付き零とNaN同士は同順位。 -/
def scalarCompare : Val → Val → Option Ordering
 | .const (.integer a),.const (.integer b) => some (compare a.toInt b.toInt)
 | .const (.integer8 a),.const (.integer8 b)
 | .const (.integer16 a),.const (.integer16 b)
 | .const (.integer32 a),.const (.integer32 b)
 | .const (.unsignedInteger16 a),.const (.unsignedInteger16 b)
 | .const (.unsignedInteger32 a),.const (.unsignedInteger32 b)
 | .const (.unsignedInteger64 a),.const (.unsignedInteger64 b) => some (compare a b)
 | .const (.byte a),.const (.byte b) => some (compare a b)
 | .const (.character a),.const (.character b) => some (compare a.toNat b.toNat)
 | .const (.float64 a),.const (.float64 b) => some (floatOrder 52 11 a.toNat b.toNat)
 | .const (.float32 a),.const (.float32 b) => some (floatOrder 23 8 a.toNat b.toNat)
 | .const (.decimal a s),.const (.decimal b t) => some (compare (a*(10:Int)^t) (b*(10:Int)^s))
 | .const (.string a),.const (.string b) => some (compare (a.toList.map Char.toNat) (b.toList.map Char.toNat))
 | _,_ => none

def sortLE (a b : Val) : Bool := (scalarCompare a b).getD .eq != .gt

def sortValid : List Val → Bool
 | [] => true
 | x::xs => (x::xs).all (fun y => (scalarCompare x y).isSome)

def sortReply (xs : List Val) : Outcome :=
 if sortValid xs then .val (.list (xs.mergeSort sortLE)) else .err "InternalComparison"

def containsReply (xs : List Val) (x : Val) : Outcome :=
 match containsResult xs x with
 | some b => .val (.const (.boolean b))
 | none => .err "InternalComparison"

inductive API where
 | head | tail | get | take | drop | contains | sort
 deriving DecidableEq

def API.name : API → PrimName
 | .head => "List.head" | .tail => "List.tail" | .get => "List.get"
 | .take => "List.take" | .drop => "List.drop" | .contains => "List.contains" | .sort => "List.sort"
def API.names : API → List String
 | .get => ["xs","i"] | .take | .drop => ["xs","n"]
 | .contains => ["xs","x"] | _ => ["xs"]
def API.inputs (a : Ty) : API → List Ty
 | .get | .take | .drop => [.list a,.base .integer]
 | .contains => [.list a,a] | _ => [.list a]
def API.result (a : Ty) : API → Ty
 | .head | .get => .data "Option" [a]
 | .tail => .data "Option" [.list a]
 | .contains => .base .boolean | _ => .list a
def API.constraint : API → TParam
 | .contains => {equality:=true} | _ => {}
/-- orderedは現TParamの欄にないため、実際の型の集合をadmissionで検査する。 -/
def orderedType (a : Ty) : Prop := match scalarTypeCore a with
 | some .integer | some .integer8 | some .integer16 | some .integer32
 | some .unsignedInteger16 | some .unsignedInteger32 | some .unsignedInteger64
 | some .byte | some .character | some .float | some .float32 | some .decimal | some .string => True
 | _ => False

def API.signature (sat : List TParam → Ty → TParam → Prop) (api : API) : PrimSig :=
 ⟨[⟨api.constraint,.value⟩],0,api.names,api.inputs (.tvar 0),api.result (.tvar 0),Eff.empty,
  (fun C ts => ts.length=1 ∧
    (api=.contains → ∀ (i : Nat) (t : Ty) (p : TParam),
      ts[i]?=some t → [api.constraint][i]?=some p → sat C t p) ∧
    (api=.sort → ∀ t ∈ ts, orderedType t)),.pure,none,[],.untargeted⟩

def clipped (n : Benitoite.Release.Integer64Value) : Nat := min n.toInt.toNat 4294967295

def at? (xs : List Val) (n : Benitoite.Release.Integer64Value) : Option Val :=
 if 0≤n.toInt ∧ n.toInt≤4294967295 then xs[n.toInt.toNat]? else none

def tail? : List Val → Option Val
 | [] => none | _::xs => some (.list xs)

def delta (api : API) (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
 if b=api.name ∧ es=[] ∧ rs=[] then match ts with
 | [a] => match api,ws with
   | .head,[.list xs] => some (.val (optionValue a xs.head?))
   | .tail,[.list xs] => some (.val (optionValue (.list a) (tail? xs)))
   | .sort,[.list xs] => some (sortReply xs)
   | .get,[.list xs,.const (.integer n)] => some (.val (optionValue a (at? xs n)))
   | .take,[.list xs,.const (.integer n)] => some (.val (.list (xs.take (clipped n))))
   | .drop,[.list xs,.const (.integer n)] => some (.val (.list (xs.drop (clipped n))))
   | .contains,[.list xs,x] => some (containsReply xs x)
   | _,_ => none
 | _ => none
 else none

private theorem instantiated (sat) (api : API) (a : Ty) (na : a.norm = a) (wa : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] (api.signature sat).tel) [a] [] =
      Ty.toTel api.names (api.inputs a) (api.result a) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases api <;> simp [API.signature,API.names,API.inputs,API.result,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
    Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,Tel.bind,Tel.rawBind,
    Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
    na,substAtoms_nil,instAtoms_nil,rowFails,emptyRange,Ty.toTel,
    Ty.shiftV,shiftVTys,Eff.shiftV,Ty.shiftV_of_wf_zero wa]

private theorem arguments {P B Ψ ts es rs ws r e} (api : API)
    (h : BuiltinArgs P B Ψ api.name (api.signature B.sat) ts es rs ws r e) :
    ∃ a, ts = [a] ∧ es = [] ∧ rs = [] ∧ Ty.Annotation P [] [] a ∧
      a.norm = a ∧ Ordinary a ∧ TypeArgsKinded P [] [a] [.value] ∧ HasTypeVsQ P B Ψ Qempty [] [] [] ws (api.inputs a) ∧
      r = api.result a ∧ e = Eff.empty := by
  have count := h.admissible.typeCount
  change ts.length = 1 at count
  rcases ts with _ | ⟨a,ts⟩
  · cases count
  have tail : ts = [] := List.length_eq_zero_iff.mp (by simpa using count)
  subst ts
  have rows : es = [] := List.length_eq_zero_iff.mp h.admissible.rowCount
  have ranges : rs = [] := List.length_eq_zero_iff.mp h.ranges.1
  subst es; subst rs
  have ha := h.signature.types a (by simp)
  have na : a.norm = a := (h.types a (by simp)).2
  have args := h.arguments
  rw [instantiated B.sat api a na ha.wf] at args
  have names : NamesWF api.names (api.inputs a) := by cases api <;> simp [API.names,API.inputs,NamesWF]
  obtain ⟨values,result,effect⟩ := args.toTelValues names
  have nr : (api.result a).norm = api.result a := by cases api <;> simp [API.result,Ty.norm,na]
  have ni : Ty.normTys (api.inputs a) = api.inputs a := by cases api <;> simp [API.inputs,Ty.norm,na]
  exact ⟨a,rfl,rfl,rfl,ha,na,h.admissible.typeScope a (by simp) |>.2,
    (by simpa [API.signature,TypeCtx.kinds] using h.signature.kinds),ni ▸ values,h.result.2.symm.trans (result.trans nr),h.effect.2.symm.trans effect⟩

private theorem closed_elements {xs : List Val} (h : Val.ClosedList 0 0 xs) : ∀ x ∈ xs, x.Ground := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    intro y hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact h.1
    · exact ih h.2 y hy

private theorem adequate_elements {σ : PathEnv} {xs : List Val} (h : adequateVals σ xs) :
    ∀ x ∈ xs, x.Adequate σ := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    intro y hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact h.1
    · exact ih h.2 y hy

private theorem close_elements {xs : List Val} (h : ∀ x ∈ xs, x.Ground) : Val.ClosedList 0 0 xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x (by simp),ih (fun y hy => h y (by simp [hy]))⟩

private theorem adequate_elements_intro {σ : PathEnv} {xs : List Val} (h : ∀ x ∈ xs, x.Adequate σ) :
    adequateVals σ xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x (by simp),ih (fun y hy => h y (by simp [hy]))⟩

private theorem each_elements {P B Ψ a xs} (h : ∀ x ∈ xs, HasTypeVQ P B Ψ Qempty [] [] [] x a) :
    HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
  induction xs with
  | nil => exact .nil
  | cons x xs ih => exact .cons (h x (by simp)) (ih (fun y hy => h y (by simp [hy])))

private theorem list_contents {P B Ψ a v} (ha : Ty.Annotation P [] [] a)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.list a)) :
    ∃ xs, v = .list xs ∧ HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
  obtain ⟨xs,b,rfl,hs,le⟩ := typed.canonical_list rfl
  exact ⟨xs,rfl,each_elements (fun x hx => .V_Sub (hs.member hx) le ha.wf ha.sorted ha.declared)⟩


private theorem list_safe {P B Ψ a} (ws ys : List Val)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] (.list ys) (.list a))
    (ground : ∀ w ∈ ws, w.Ground)
    (origin : ∀ y ∈ ys, (y ∈ ws) ∨ ∃ xs, Val.list xs ∈ ws ∧ y ∈ xs) :
    Outcome.Typed P B Ψ (.val (.list ys)) (.list a) ∧ AdequateResult ws (.val (.list ys)) ∧
      (∀ i, Outcome.val (.list ys) ≠ .exit i) := by
  refine ⟨⟨typed,close_elements ?_⟩,?_,by intro i; simp⟩
  · intro y hy
    rcases origin y hy with direct | ⟨xs,member,elem⟩
    · exact ground y direct
    · exact closed_elements (ground (.list xs) member) y elem
  · intro σ _ inputs
    apply adequate_elements_intro
    intro y hy
    rcases origin y hy with direct | ⟨xs,member,elem⟩
    · exact inputs y direct
    · exact adequate_elements (inputs (.list xs) member) y elem

private theorem option_safe {P B Ψ a} (ws : List Val) (value : Option Val)
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1)
 (ha : Ty.Annotation P [] [] a) (kinded : TypeArgsKinded P [] [a] [.value])
 (safe : ∀ v, value=some v → Outcome.Typed P B Ψ (.val v) a ∧ AdequateResult ws (.val v)) :
 Outcome.Typed P B Ψ (.val (optionValue a value)) (.data "Option" [a]) ∧
 AdequateResult ws (.val (optionValue a value)) ∧ (∀ i, Outcome.val (optionValue a value)≠.exit i) := by
 have ann : Ty.Annotation P [] [] (.data "Option" [a]) :=
  ⟨⟨ha.wf,trivial⟩,⟨ha.sorted,trivial⟩,⟨⟨1,arity,rfl⟩,ha.declared,trivial⟩⟩
 cases value with
 | none =>
  exact ⟨⟨.V_Con noneDecl rfl kinded (by simp) .nil ann,
    by simpa [optionValue,Val.Ground,Val.ClosedAt] using
      (And.intro ha.wf (show Val.ClosedList 0 0 [] from trivial))⟩,
    by intro σ _ _; trivial,by intro i; simp⟩
 | some v =>
  obtain ⟨⟨hv,hg⟩,ha'⟩ := safe v rfl
  have ht : HasTypeVQ P B Ψ Qempty [] [] [] (optionValue a (some v)) (.data "Option" [a]) := by
   apply HasTypeVQ.V_Con someDecl rfl kinded ?_ ?_ ann
   · intro t ht; cases List.mem_singleton.mp ht; simp [Ty.WF]
   · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,SubstEnv.up] using
      (show HasTypeVsQ P B Ψ Qempty [] [] [] [v] [a.norm] from .cons (.V_Normal hv) .nil)
  refine ⟨⟨ht,?_⟩,?_,by intro i; simp⟩
  · simpa [optionValue,Val.Ground,Val.ClosedAt,Val.ClosedList] using And.intro ha.wf hg
  · intro σ valid inputs
    exact ⟨ha' σ valid inputs,trivial⟩

private theorem subset_safe {P B Ψ a} (xs ys : List Val)
 (ha : Ty.Annotation P [] [] a) (each : HasTypeEachQ P B Ψ Qempty [] [] [] xs a)
 (ground : (Val.list xs).Ground) (sub : ∀ y ∈ ys, y ∈ xs) :
 Outcome.Typed P B Ψ (.val (.list ys)) (.list a) ∧
 AdequateResult [.list xs] (.val (.list ys)) ∧ (∀ i, Outcome.val (.list ys)≠.exit i) := by
 exact list_safe [.list xs] ys (.V_List (each_elements (fun y hy => each.member (sub y hy))) ha.wf ha.sorted ha.declared)
  (by intro w hw; cases List.mem_singleton.mp hw; exact ground)
  (fun y hy => Or.inr ⟨xs,by simp,sub y hy⟩)

private theorem selected_safe {P B Ψ a} (xs : List Val) (value : Option Val)
 (each : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (ground : (Val.list xs).Ground)
 (sub : ∀ v, value=some v → v ∈ xs) :
 ∀ v, value=some v → Outcome.Typed P B Ψ (.val v) a ∧ AdequateResult [.list xs] (.val v) := by
 intro v hv
 exact ⟨⟨each.member (sub v hv),closed_elements ground v (sub v hv)⟩,
  fun σ _ inputs => adequate_elements (inputs (.list xs) (by simp)) v (sub v hv)⟩

private theorem integer_shape {P B Ψ v}
 (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base .integer)) :
 ∃ n : Benitoite.Release.Integer64Value, v=.const (.integer n) := by
 obtain ⟨c,rfl,hc,tag⟩ := h.canonical_scalar rfl
 cases c <;> cases tag
 exact ⟨_,rfl⟩

/-- 元要素の型と保持値から、実headの通常応答を構成する。 -/
theorem head_selected {P B Ψ a xs}
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1) (ha : Ty.Annotation P [] [] a)
 (kinded : TypeArgsKinded P [] [a] [.value])
 (each : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (ground : (Val.list xs).Ground) :
 Outcome.Typed P B Ψ (.val (optionValue a xs.head?)) (.data "Option" [a]) ∧
 AdequateResult [.list xs] (.val (optionValue a xs.head?)) ∧
 (∀ i, Outcome.val (optionValue a xs.head?) ≠ .exit i) := by
 apply option_safe _ _ someDecl noneDecl arity ha kinded
 apply selected_safe xs xs.head? each ground
 intro v h
 cases xs with
 | nil => cases h
 | cons x xs => cases Option.some.inj h; simp

/-- 残りの列の同じ要素を返す実tailの通常応答。 -/
theorem tail_selected {P B Ψ a xs}
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1) (ha : Ty.Annotation P [] [] a)
 (kinded : TypeArgsKinded P [] [a] [.value])
 (each : HasTypeEachQ P B Ψ Qempty [] [] [] xs a) (ground : (Val.list xs).Ground) :
 Outcome.Typed P B Ψ (.val (optionValue (.list a) (tail? xs))) (.data "Option" [.list a]) ∧
 AdequateResult [.list xs] (.val (optionValue (.list a) (tail? xs))) ∧
 (∀ i, Outcome.val (optionValue (.list a) (tail? xs)) ≠ .exit i) := by
 have listAnn : Ty.Annotation P [] [] (.list a) := ⟨ha.wf,ha.sorted,ha.declared⟩
 have listKind : TypeArgsKinded P [] [.list a] [.value] := by
  refine ⟨rfl,?_⟩
  rintro (_|i) t k ht hk
  · cases Option.some.inj ht; cases Option.some.inj hk
    exact ⟨(kinded.2 0 a .value rfl rfl).1,by intro _ b t e h; cases h⟩
  · simp at ht
 apply option_safe _ _ someDecl noneDecl arity listAnn listKind
 intro v hv
 cases xs with
 | nil => cases hv
 | cons x xs =>
  cases Option.some.inj hv
  have hs := subset_safe (x::xs) xs ha each ground (fun y hy => List.mem_cons_of_mem x hy)
  exact ⟨hs.1,hs.2.1⟩

/-- 七つの多相API。Optionには原型引数のkindをそのまま使う。 -/
theorem response {P B Ψ ts es rs ws r e} (api : API)
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1)
 (args : BuiltinArgs P B Ψ api.name (api.signature B.sat) ts es rs ws r e) :
 ∃ out, delta api api.name ts es rs ws=some out ∧ Outcome.Typed P B Ψ out r ∧
 AdequateResult ws out ∧ (∀ i,out≠.exit i) := by
 obtain ⟨a,rfl,rfl,rfl,ha,na,ordinary,kinded,values,rfl,rfl⟩ := arguments api args
 cases api with
 | head =>
  cases values with | cons typed rest =>
   cases rest
   obtain ⟨xs,rfl,each⟩ := list_contents ha typed
   have g : (Val.list xs).Ground := args.ground _ (by simp)
   refine ⟨.val (optionValue a xs.head?),by simp [delta],
    option_safe _ _ someDecl noneDecl arity ha kinded (selected_safe xs xs.head? each g ?_)⟩
   intro v h
   cases xs with
   | nil => cases h
   | cons x xs => cases Option.some.inj h; simp
 | tail =>
  cases values with | cons typed rest =>
   cases rest
   obtain ⟨xs,rfl,each⟩ := list_contents ha typed
   have g : (Val.list xs).Ground := args.ground _ (by simp)
   have listAnn : Ty.Annotation P [] [] (.list a) := ⟨ha.wf,ha.sorted,ha.declared⟩
   have listKind : TypeArgsKinded P [] [.list a] [.value] := by
    refine ⟨rfl,?_⟩
    rintro (_|i) t k ht hk
    · cases Option.some.inj ht; cases Option.some.inj hk
      exact ⟨(kinded.2 0 a .value rfl rfl).1,by intro _ b t e h; cases h⟩
    · simp at ht
   refine ⟨.val (optionValue (.list a) (tail? xs)),by simp [delta],
    option_safe _ _ someDecl noneDecl arity listAnn listKind ?_⟩
   intro v hv
   cases xs with
   | nil => cases hv
   | cons x xs =>
    cases Option.some.inj hv
    have hs := subset_safe (x::xs) xs ha each g (fun y hy => List.mem_cons_of_mem x hy)
    exact ⟨hs.1,hs.2.1⟩
 | get =>
  cases values with | cons typed rest => cases rest with | cons index rest =>
   cases rest
   obtain ⟨xs,rfl,each⟩ := list_contents ha typed
   obtain ⟨n,rfl⟩ := integer_shape index
   have g : (Val.list xs).Ground := args.ground _ (by simp)
   have safe := option_safe [.list xs] (at? xs n) someDecl noneDecl arity ha kinded
    (selected_safe xs (at? xs n) each g (by
     intro v hv; unfold at? at hv; split at hv
     · exact List.mem_of_getElem? hv
     · cases hv))
   refine ⟨.val (optionValue a (at? xs n)),by simp [delta],safe.1,?_,safe.2.2⟩
   intro σ valid inputs
   exact safe.2.1 σ valid (by intro w hw; cases List.mem_singleton.mp hw; exact inputs _ (by simp))
 | take =>
  cases values with | cons typed rest => cases rest with | cons count rest =>
   cases rest
   obtain ⟨xs,rfl,each⟩ := list_contents ha typed
   obtain ⟨n,rfl⟩ := integer_shape count
   have g : (Val.list xs).Ground := args.ground _ (by simp)
   have safe := subset_safe xs (xs.take (clipped n)) ha each g (fun _ hy => List.mem_of_mem_take hy)
   refine ⟨.val (.list (xs.take (clipped n))),by simp [delta],safe.1,?_,safe.2.2⟩
   intro σ valid inputs
   exact safe.2.1 σ valid (by intro w hw; cases List.mem_singleton.mp hw; exact inputs _ (by simp))
 | drop =>
  cases values with | cons typed rest => cases rest with | cons count rest =>
   cases rest
   obtain ⟨xs,rfl,each⟩ := list_contents ha typed
   obtain ⟨n,rfl⟩ := integer_shape count
   have g : (Val.list xs).Ground := args.ground _ (by simp)
   have safe := subset_safe xs (xs.drop (clipped n)) ha each g (fun _ hy => List.mem_of_mem_drop hy)
   refine ⟨.val (.list (xs.drop (clipped n))),by simp [delta],safe.1,?_,safe.2.2⟩
   intro σ valid inputs
   exact safe.2.1 σ valid (by intro w hw; cases List.mem_singleton.mp hw; exact inputs _ (by simp))
 | contains =>
  cases values with | cons typed rest => cases rest with | cons element rest =>
   cases rest
   obtain ⟨xs,rfl,each⟩ := list_contents ha typed
   rename_i x
   refine ⟨containsReply xs x,by simp [delta],?_,?_,?_⟩
   all_goals unfold containsReply; cases containsResult xs x
   all_goals first | trivial | (exact ⟨.V_Const trivial,trivial⟩) | (intro σ _ _; trivial) | (intro i; simp)
 | sort =>
  cases values with | cons typed rest =>
   cases rest
   obtain ⟨xs,rfl,each⟩ := list_contents ha typed
   have g : (Val.list xs).Ground := args.ground _ (by simp)
   have safe := subset_safe xs (xs.mergeSort sortLE) ha each g
    (fun y hy => (List.mergeSort_perm xs sortLE).mem_iff.mp hy)
   refine ⟨sortReply xs,by simp [delta],?_,?_,?_⟩
   all_goals unfold sortReply; split
   all_goals first | exact safe.1 | exact safe.2.1 | exact safe.2.2 | trivial | (intro σ _ _; trivial) | (intro i; simp)

/-- rangeの資源上限は元のCheckedLenと同じ2^24要素である。 -/
def rangePayload (start stop : Benitoite.Release.Integer64Value) : Except String (List Benitoite.Release.Integer64Value) := do
 let count := (stop.toInt-start.toInt).toNat
 if count>16777216 then throw "ResourceLimit"
 (List.range count).mapM fun (n : Nat) =>
  match integerConvert .integer64 (start.toInt+(n:Int)) with
  | some value => pure value
  | none => throw "IntegerOverflow"

def rangeReply (start stop : Benitoite.Release.Integer64Value) : Outcome :=
 StandardPureResults.reply (.list .integer) (rangePayload start stop)

def rangeSignature : PrimSig :=
 ⟨[],0,["start","stop"],[.base .integer,.base .integer],.list (.base .integer),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

def rangeDelta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
 if b="List.range" ∧ ts=[] ∧ es=[] ∧ rs=[] then
  match ws with
  | [.const (.integer start),.const (.integer stop)] => some (rangeReply start stop)
  | _ => none
 else none

private theorem range_instantiated :
 instantiatedTel (Tel.instR [] rangeSignature.tel) [] [] =
 Ty.toTel ["start","stop"] [.base .integer,.base .integer] (.list (.base .integer)) Eff.empty := by
 have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]
 simp [rangeSignature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
  Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,Tel.bind,Tel.rawBind,
  Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
  substAtoms_nil,instAtoms_nil,rowFails,emptyRange,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV]

theorem range_response {P B Ψ ts es rs ws a e}
 (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩)
 (arity : P.DataArity "Option" 1)
 (args : BuiltinArgs P B Ψ "List.range" rangeSignature ts es rs ws a e) :
 ∃ out, rangeDelta "List.range" ts es rs ws=some out ∧ Outcome.Typed P B Ψ out a ∧
 AdequateResult ws out ∧ (∀ i,out≠.exit i) := by
 have ht : ts=[] := List.length_eq_zero_iff.mp args.admissible.typeCount
 have he : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have hr : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst ts; subst es; subst rs
 have values := args.arguments
 rw [range_instantiated] at values
 obtain ⟨hvs,ar,ee⟩ := values.toTelValues (by simp [NamesWF])
 have result : a=.list (.base .integer) := args.result.2.symm.trans ar
 subst a
 cases hvs with | cons hs rest => cases rest with | cons ht rest =>
  cases rest
  obtain ⟨start,rfl⟩ := integer_shape hs
  obtain ⟨stop,rfl⟩ := integer_shape ht
  exact ⟨rangeReply start stop,by simp [rangeDelta],
   StandardPureResults.reply_safe someDecl noneDecl arity (.list .integer) (rangePayload start stop) _⟩

private def apis : List API := [.head,.tail,.get,.take,.drop,.contains,.sort]
def dispatch (b : PrimName) : Option API := apis.find? (fun api => b==api.name)
private theorem dispatch_name (api : API) : dispatch api.name=some api := by cases api <;> rfl

def lookup (sat : List TParam → Ty → TParam → Prop) (b : PrimName) : Option PrimSig :=
 if b="List.range" then some rangeSignature else (dispatch b).map (API.signature sat)

def table (base : Builtins) : Builtins :=
 {base with sig:=lookup base.sat,delta:=fun b ts es rs ws =>
  if b="List.range" then rangeDelta b ts es rs ws
  else (dispatch b).bind (fun api => delta api b ts es rs ws)}

theorem table_response {base Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ api.name
  (api.signature (table base).sat) ts es rs ws a e) :
 (table base).sig api.name=some (api.signature (table base).sat) ∧
 ∃ out, (table base).delta api.name ts es rs ws=some out ∧
 Outcome.Typed StandardCollectionModel.program (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i,out≠.exit i) := by
 have different : api.name≠"List.range" := by cases api <;> decide
 refine ⟨by simp [table,lookup,different,dispatch_name],?_⟩
 obtain ⟨out,hd,ht,ha,hn⟩ := response api rfl rfl StandardConversionResponse.option_arity args
 exact ⟨out,by simpa only [table,if_neg different,dispatch_name,Option.bind_some] using hd,ht,ha,hn⟩

theorem table_range_response {base Ψ ts es rs ws a e}
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ "List.range"
  rangeSignature ts es rs ws a e) :
 (table base).sig "List.range"=some rangeSignature ∧
 ∃ out, (table base).delta "List.range" ts es rs ws=some out ∧
 Outcome.Typed StandardCollectionModel.program (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i,out≠.exit i) := by
 refine ⟨by simp [table,lookup],?_⟩
 obtain ⟨out,hd,ht,ha,hn⟩ := range_response rfl rfl StandardConversionResponse.option_arity args
 exact ⟨out,by simpa only [table,ite_true] using hd,ht,ha,hn⟩

example {base Ψ ts es rs ws a e}
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ "List.range"
  rangeSignature ts es rs ws a e) := table_range_response args

example {base Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ api.name
  (api.signature (table base).sat) ts es rs ws a e) := table_response api args

example : structuralEqual (.list [.const (.float64 0x7ff8000000000000)])
 (.list [.const (.float64 0x7ff8000000000000)]) = some false := by
 simp only [structuralEqual,Val.toTerm?,Val.toTermSlots,Term.observe,observeSlots,Option.bind_some]
 simp [equalityFuel,equalityFuel.slots,snapshotDepth,slotDepth,Option.bind] <;> decide +kernel
example : structuralEqual (.list [.const (.float32 0)])
 (.list [.const (.float32 0x80000000)]) = some true := by
 simp only [structuralEqual,Val.toTerm?,Val.toTermSlots,Term.observe,observeSlots,Option.bind_some]
 simp [equalityFuel,equalityFuel.slots,snapshotDepth,slotDepth,Option.bind] <;> decide +kernel
example : structuralEqual (.const (.decimal 100 2)) (.const (.decimal 1 0)) = some true := by
 simp only [structuralEqual,Val.toTerm?,Term.observe,Option.bind_some]
 simp [equalityFuel,equalityFuel.slots,snapshotDepth,slotDepth,Option.bind] <;> decide +kernel
example : scalarCompare (.const (.float64 0x7ff8000000000000)) (.const (.float64 0))=some .gt := by decide +kernel
example : clipped ⟨-1,by decide⟩=0 := by decide +kernel
end
end Benitoite.Release.Refinement.StandardListRemainingResponse
