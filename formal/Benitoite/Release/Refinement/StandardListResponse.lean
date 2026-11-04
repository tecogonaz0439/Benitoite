import Benitoite.Release.Refinement.StandardDecimalResponse

namespace Benitoite.Release.Refinement.StandardListResponse
noncomputable section
open StandardCollections

inductive API where
  | length | isEmpty | prepend | append | concatenate | reverse
  deriving DecidableEq

def API.name : API → PrimName
  | .length => "List.length" | .isEmpty => "List.isEmpty" | .prepend => "List.prepend"
  | .append => "List.append" | .concatenate => "List.concatenate" | .reverse => "List.reverse"

def API.names : API → List String
  | .prepend | .append => ["xs","x"] | .concatenate => ["xs","ys"] | _ => ["xs"]

def API.inputs (a : Ty) : API → List Ty
  | .prepend | .append => [.list a,a] | .concatenate => [.list a,.list a] | _ => [.list a]

def API.result (a : Ty) : API → Ty
  | .length => .base .integer | .isEmpty => .base .boolean | _ => .list a

def API.signature (api : API) : PrimSig :=
  ⟨[TypeCtx.valueParam],0,api.names,api.inputs (.tvar 0),api.result (.tvar 0),Eff.empty,
    (fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩

def API.delta : API → PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  | .length | .isEmpty => lengthDelta | .prepend | .append => insertDelta | _ => sequenceDelta

private theorem instantiated (api : API) (a : Ty) (na : a.norm = a) (wa : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] api.signature.tel) [a] [] =
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
    (h : BuiltinArgs P B Ψ api.name api.signature ts es rs ws r e) :
    ∃ a, ts = [a] ∧ es = [] ∧ rs = [] ∧ Ty.Annotation P [] [] a ∧
      a.norm = a ∧ Ordinary a ∧ HasTypeVsQ P B Ψ Qempty [] [] [] ws (api.inputs a) ∧
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
  rw [instantiated api a na ha.wf] at args
  have names : NamesWF api.names (api.inputs a) := by cases api <;> simp [API.names,API.inputs,NamesWF]
  obtain ⟨values,result,effect⟩ := args.toTelValues names
  have nr : (api.result a).norm = api.result a := by cases api <;> simp [API.result,Ty.norm,na]
  have ni : Ty.normTys (api.inputs a) = api.inputs a := by cases api <;> simp [API.inputs,Ty.norm,na]
  exact ⟨a,rfl,rfl,rfl,ha,na,h.admissible.typeScope a (by simp) |>.2,
    ni ▸ values,h.result.2.symm.trans (result.trans nr),h.effect.2.symm.trans effect⟩

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


private theorem count_response {P B Ψ} (ws : List Val) (n : Nat) :
    Outcome.Typed P B Ψ (countReply n) (.base .integer) ∧ AdequateResult ws (countReply n) ∧
      (∀ i, countReply n ≠ .exit i) := by
  unfold countReply
  cases StandardScalar.integerConvert .integer64 n with
  | none => exact ⟨by trivial,by intro σ _ _; trivial,by intro i; simp⟩
  | some value => exact ⟨⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩

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

/-- 型引数と全実引数を保持し、通常の六実名の同じ応答を型付ける。 -/
theorem response {P B Ψ ts es rs ws r e} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws r e) :
    ∃ out, api.delta api.name ts es rs ws = some out ∧ Outcome.Typed P B Ψ out r ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨a,rfl,rfl,rfl,ha,na,ordinary,values,rfl,rfl⟩ := arguments api args
  cases api with
  | length =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,_⟩ := list_contents ha typed
      exact ⟨countReply xs.length,rfl,count_response _ _⟩
  | isEmpty =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,_⟩ := list_contents ha typed
      exact ⟨.val (.const (.boolean xs.isEmpty)),rfl,⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp⟩
  | prepend =>
    cases values with | cons typed rest => cases rest with | cons element rest =>
      cases rest
      obtain ⟨xs,rfl,each⟩ := list_contents ha typed
      rename_i x
      obtain ⟨ys,delta,ht,_⟩ := insert_reply ha each element false
      have eq : ys = x :: xs := Val.list.inj (Outcome.val.inj (Option.some.inj delta)).symm
      subst ys
      refine ⟨.val (.list (x::xs)),rfl,list_safe _ _ ht args.ground ?_⟩
      intro y hy; rcases List.mem_cons.mp hy with rfl | hy
      · exact Or.inl (by simp)
      · exact Or.inr ⟨xs,by simp,hy⟩
  | append =>
    cases values with | cons typed rest => cases rest with | cons element rest =>
      cases rest
      obtain ⟨xs,rfl,each⟩ := list_contents ha typed
      rename_i x
      obtain ⟨ys,delta,ht,_⟩ := insert_reply ha each element true
      have eq : ys = xs ++ [x] := Val.list.inj (Outcome.val.inj (Option.some.inj delta)).symm
      subst ys
      refine ⟨.val (.list (xs++[x])),rfl,list_safe _ _ ht args.ground ?_⟩
      intro y hy; rcases List.mem_append.mp hy with hy | hy
      · exact Or.inr ⟨xs,by simp,hy⟩
      · have eq : y = x := List.mem_singleton.mp hy
        subst y; exact Or.inl (by simp)
  | concatenate =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨xs,rfl,hx⟩ := list_contents ha hl
      obtain ⟨ys,rfl,hy⟩ := list_contents ha hr
      have reply := concatenate_reply ha hx hy
      refine ⟨.val (.list (xs++ys)),reply.1,list_safe _ _ reply.2.1 args.ground ?_⟩
      intro y member; rcases List.mem_append.mp member with left | right
      · exact Or.inr ⟨xs,by simp,left⟩
      · exact Or.inr ⟨ys,by simp,right⟩
  | reverse =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,each⟩ := list_contents ha typed
      have reply := reverse_reply ha each
      refine ⟨.val (.list xs.reverse),reply.1,list_safe _ _ reply.2.1 args.ground ?_⟩
      intro y member; exact Or.inr ⟨xs,by simp,by simpa using member⟩

private def apis : List API := [.length,.isEmpty,.prepend,.append,.concatenate,.reverse]

def lookup (b : PrimName) : Option PrimSig :=
  apis.findSome? fun api => if b = api.name then some api.signature else none

theorem lookup_name (api : API) : lookup api.name = some api.signature := by
  cases api <;> simp [lookup,apis,API.name,List.findSome?]

def table (base : Builtins) : Builtins :=
  {base with sig := lookup,delta := fun b ts es rs ws =>
    if b = "List.length" ∨ b = "List.isEmpty" then lengthDelta b ts es rs ws
    else if b = "List.prepend" ∨ b = "List.append" then insertDelta b ts es rs ws
    else sequenceDelta b ts es rs ws}

theorem table_response {P base Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P (table base) Ψ api.name api.signature ts es rs ws a e) :
    (table base).sig api.name = some api.signature ∧
    ∃ out, (table base).delta api.name ts es rs ws = some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  refine ⟨lookup_name api,?_⟩
  obtain ⟨out,delta,rest⟩ := response api args
  refine ⟨out,?_,rest⟩
  cases api <;> simpa [table,API.name,API.delta] using delta

example {P base Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P (table base) Ψ api.name api.signature ts es rs ws a e) :
    (table base).sig api.name = some api.signature ∧
    ∃ out, (table base).delta api.name ts es rs ws = some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  table_response api args

/-- 同じ元列・返却列の関係。停止応答へ正常値の長さは要求しない。 -/
def Relation : API → List Val → Outcome → Prop
  | .length,[.list xs],.val (.const (.integer n)) => n.toInt = xs.length
  | .isEmpty,[.list xs],.val (.const (.boolean b)) => b = xs.isEmpty
  | .prepend,[.list xs,x],.val (.list ys) => ys = x::xs ∧ ys.length = xs.length + 1
  | .append,[.list xs,x],.val (.list ys) => ys = xs++[x] ∧ ys.length = xs.length + 1
  | .concatenate,[.list xs,.list ys],.val (.list zs) => zs = xs++ys ∧ zs.length = xs.length + ys.length
  | .reverse,[.list xs],.val (.list ys) => ys = xs.reverse ∧ ys.length = xs.length
  | _,_,.err _ => True
  | _,_,_ => False

theorem relation {P B Ψ ts es rs ws a e out} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e)
    (delta : api.delta api.name ts es rs ws = some out) : Relation api ws out := by
  obtain ⟨a,rfl,rfl,rfl,ha,na,ordinary,values,rfl,rfl⟩ := arguments api args
  cases api with
  | length =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,_⟩ := list_contents ha typed
      have eq : out = countReply xs.length := (Option.some.inj delta).symm
      subst out
      cases converted : StandardScalar.integerConvert .integer64 xs.length with
      | none => simp [countReply,converted,Relation]
      | some value =>
        simp only [countReply,converted,Relation]
        exact (StandardScalar.integerConvert_some .integer64 xs.length value).mp converted
  | isEmpty =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,_⟩ := list_contents ha typed
      have eq : out = .val (.const (.boolean xs.isEmpty)) := (Option.some.inj delta).symm
      rw [eq]; rfl
  | prepend =>
    cases values with | cons typed rest => cases rest with | cons element rest =>
      cases rest
      obtain ⟨xs,rfl,each⟩ := list_contents ha typed
      rename_i x
      have eq : out = .val (.list (x::xs)) := (Option.some.inj delta).symm
      rw [eq]; exact ⟨rfl,by simp⟩
  | append =>
    cases values with | cons typed rest => cases rest with | cons element rest =>
      cases rest
      obtain ⟨xs,rfl,each⟩ := list_contents ha typed
      rename_i x
      have eq : out = .val (.list (xs++[x])) := (Option.some.inj delta).symm
      rw [eq]; exact ⟨rfl,by simp⟩
  | concatenate =>
    cases values with | cons left rest => cases rest with | cons right rest =>
      cases rest
      obtain ⟨xs,rfl,_⟩ := list_contents ha left
      obtain ⟨ys,rfl,_⟩ := list_contents ha right
      have eq : out = .val (.list (xs++ys)) := (Option.some.inj delta).symm
      rw [eq]; exact ⟨rfl,by simp⟩
  | reverse =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,_⟩ := list_contents ha typed
      have eq : out = .val (.list xs.reverse) := (Option.some.inj delta).symm
      rw [eq]; exact ⟨rfl,by simp⟩

theorem related_response {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ∃ out, api.delta api.name ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧ Relation api ws out := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response api args
  exact ⟨out,delta,typed,adequate,nonexit,relation api args delta⟩

example {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :=
  related_response api args

end
end Benitoite.Release.Refinement.StandardListResponse
