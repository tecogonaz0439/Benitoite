import Benitoite.Release.Refinement.StandardListResponse

namespace Benitoite.Release.Refinement.StandardBytesResponse
open StandardScalar StandardCollections

inductive API where
  | stringBytes | stringCharacters | bytesLength | bytesFromList | bytesToList
  deriving DecidableEq

def API.name : API → PrimName
  | .stringBytes => "String.byteLength" | .stringCharacters => "String.characterCount"
  | .bytesLength => "Bytes.length" | .bytesFromList => "Bytes.fromList" | .bytesToList => "Bytes.toList"

def API.names : API → List String
  | .stringBytes | .stringCharacters => ["s"] | .bytesFromList => ["bs"] | _ => ["b"]

def API.inputs : API → List Ty
  | .stringBytes | .stringCharacters => [.base .string]
  | .bytesFromList => [.list (.base .byte)] | _ => [.bytes]

def API.result : API → Ty
  | .bytesFromList => .bytes | .bytesToList => .list (.base .byte) | _ => .base .integer

def API.signature (api : API) : PrimSig :=
  ⟨[],0,api.names,api.inputs,api.result,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private def byteValues : List Val → Option (List Nat)
  | [] => some []
  | .const (.byte n) :: xs => if n ≤ 255 then (byteValues xs).map (n :: ·) else none
  | _ => none

/-- 既存のBytes導入/射影を実名と同じ列へ接続する二行の部分δ。 -/
def bytesListDelta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  match b,ts,es,rs,ws with
  | "Bytes.fromList",[],[],[],[.list xs] => (byteValues xs).map (fun ns => .val (.bytesV ns))
  | "Bytes.toList",[],[],[],[.bytesV ns] =>
      if ns.all (· ≤ 255) then some (.val (.list (ns.map (fun n => .const (.byte n))))) else none
  | _,_,_,_,_ => none

def API.delta : API → PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  | .bytesFromList | .bytesToList => bytesListDelta | _ => lengthDelta

private theorem instantiated (api : API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.result Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases api <;> simp [emptyRange,API.signature,API.inputs,API.result,API.names,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys]

private theorem arguments {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = api.result ∧ e = Eff.empty ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] ws api.inputs := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have h := args.arguments
  rw [instantiated] at h
  have names : NamesWF api.names api.inputs := by cases api <;> simp [API.names,API.inputs,NamesWF]
  obtain ⟨values,ar,ee⟩ := h.toTelValues names
  have na : api.result.norm = api.result := by cases api <;> rfl
  have ni : Ty.normTys api.inputs = api.inputs := by cases api <;> rfl
  exact ⟨rfl,rfl,rfl,args.result.2.symm.trans (ar.trans na),args.effect.2.symm.trans ee,
    ni ▸ values⟩

private theorem scalar_shape {P B Ψ v} (base : BaseTy)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base base)) :
    ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base base := by
  exact h.canonical_scalar rfl

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


private theorem byte_values (xs : List UInt8) :
    byteValues (xs.map (fun v => .const (.byte v.toNat))) = some (xs.map UInt8.toNat) := by
  induction xs with
  | nil => rfl
  | cons v xs ih =>
    have bound : v.toNat ≤ 255 := by have := v.toNat_lt; omega
    simp [byteValues,bound,ih]

private theorem typed_bytes {P B Ψ xs}
    (typed : HasTypeEachQ P B Ψ Qempty [] [] [] xs (.base .byte)) :
    ∃ bytes : List UInt8, xs = bytes.map (fun v => .const (.byte v.toNat)) := by
  induction xs with
  | nil => exact ⟨[],rfl⟩
  | cons v xs ih =>
    cases typed with
    | cons h hs =>
      obtain ⟨c,rfl,hc,tag⟩ := h.canonical_scalar rfl
      cases c <;> cases tag
      rename_i n
      let b : UInt8 := UInt8.ofNatLT n (by change n < 256; change n ≤ 255 at hc; omega)
      obtain ⟨bs,rfl⟩ := ih hs
      exact ⟨b::bs,rfl⟩

private theorem nat_bytes (ns : List Nat) (bound : ∀ n ∈ ns, n ≤ 255) :
    ∃ bytes : List UInt8, bytes.map UInt8.toNat = ns := by
  induction ns with
  | nil => exact ⟨[],rfl⟩
  | cons n ns ih =>
    have hn := bound n (by simp)
    let b : UInt8 := UInt8.ofNatLT n (by change n < 256; omega)
    obtain ⟨bs,eq⟩ := ih (fun m hm => bound m (by simp [hm]))
    exact ⟨b::bs,by simp [eq,b]⟩

private theorem list_byte_safe (xs : List UInt8) (ws : List Val) :
    (bytesToList xs).Ground ∧ AdequateResult ws (.val (bytesToList xs)) := by
  constructor
  · change Val.ClosedList 0 0 (xs.map (fun v => .const (.byte v.toNat)))
    induction xs with
    | nil => trivial
    | cons x xs ih => exact ⟨trivial,ih⟩
  · intro σ _ _
    change adequateVals σ (xs.map (fun v => .const (.byte v.toNat)))
    induction xs with
    | nil => trivial
    | cons x xs ih => exact ⟨trivial,ih⟩

/-- 三つの長さと二つのBytes相互変換を全型付き入力から構成する。 -/
theorem response {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ∃ out, api.delta api.name ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments api args
  cases api with
  | stringBytes =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .string typed
      cases c <;> cases tag
      rename_i s
      exact ⟨countReply s.utf8ByteSize,rfl,count_response _ _⟩
  | stringCharacters =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .string typed
      cases c <;> cases tag
      rename_i s
      exact ⟨countReply s.toList.length,rfl,count_response _ _⟩
  | bytesLength =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨ns,rfl⟩ := typed.canonical_bytes rfl
      have bound := (typed.inv_bytesV rfl).1
      refine ⟨countReply ns.length,?_,count_response _ _⟩
      change (if ns.all (· ≤ 255) then some _ else none) = some _
      exact ite_eq_left (List.all_eq_true.mpr (by simpa using bound))
  | bytesFromList =>
    cases values with | cons typed rest =>
      cases rest
      have ha : Ty.Annotation P [] [] (.base .byte) := ⟨trivial,trivial,trivial⟩
      obtain ⟨xs,rfl,each⟩ := list_contents ha typed
      obtain ⟨bs,rfl⟩ := typed_bytes each
      refine ⟨.val (bytesFromList bs),?_,⟨(bytesFromList_typed P B Ψ bs).1,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp⟩
      change (byteValues _).map _ = some _
      rw [byte_values]; rfl
  | bytesToList =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨ns,rfl⟩ := typed.canonical_bytes rfl
      have bound := (typed.inv_bytesV rfl).1
      obtain ⟨bs,eq⟩ := nat_bytes ns bound
      subst ns
      refine ⟨.val (bytesToList bs),?_,⟨bytesToList_typed P B Ψ bs,(list_byte_safe bs []).1⟩,
        (list_byte_safe bs _).2,by intro i; simp⟩
      change (if (bs.map UInt8.toNat).all (· ≤ 255) then some _ else none) = some _
      rw [ite_eq_left (List.all_eq_true.mpr (by simpa using bound))]
      simp only [bytesToList,List.map_map]
      rfl

private def apis : List API := [.stringBytes,.stringCharacters,.bytesLength,.bytesFromList,.bytesToList]

def lookup (b : PrimName) : Option PrimSig :=
  apis.findSome? fun api => if b = api.name then some api.signature else none

theorem lookup_name (api : API) : lookup api.name = some api.signature := by
  cases api <;> simp [lookup,apis,API.name,List.findSome?]

def table (base : Builtins) : Builtins :=
  {base with sig := lookup,delta := fun b ts es rs ws =>
    if b = "Bytes.fromList" ∨ b = "Bytes.toList" then bytesListDelta b ts es rs ws
    else lengthDelta b ts es rs ws}

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

def Relation : API → List Val → Outcome → Prop
  | .stringBytes,[.const (.string s)],.val (.const (.integer n)) => n.toInt = s.utf8ByteSize
  | .stringCharacters,[.const (.string s)],.val (.const (.integer n)) => n.toInt = s.toList.length
  | .bytesLength,[.bytesV ns],.val (.const (.integer n)) => n.toInt = ns.length
  | .bytesFromList,[.list xs],.val (.bytesV ns) =>
      xs = ns.map (fun n => .const (.byte n)) ∧ xs.length = ns.length
  | .bytesToList,[.bytesV ns],.val (.list xs) =>
      xs = ns.map (fun n => .const (.byte n)) ∧ xs.length = ns.length
  | _,_,.err _ => True
  | _,_,_ => False

private theorem count_relation (api : API) (ws : List Val) (n : Nat)
    (normal : ∀ v : Benitoite.Release.Integer64Value,
      v.toInt = n → Relation api ws (.val (.const (.integer v)))) :
    Relation api ws (countReply n) := by
  cases converted : integerConvert .integer64 n with
  | none => cases api <;> simp [countReply,converted,Relation]
  | some value =>
    rw [countReply,converted]
    exact normal value ((integerConvert_some .integer64 n value).mp converted)

/-- 同じ応答と元列の二長・byte列・長さを読む。 -/
theorem relation {P B Ψ ts es rs ws a e out} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e)
    (delta : api.delta api.name ts es rs ws = some out) : Relation api ws out := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments api args
  cases api with
  | stringBytes =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .string typed
      cases c <;> cases tag
      rename_i s
      have eq : out = countReply s.utf8ByteSize := (Option.some.inj delta).symm
      rw [eq]; exact count_relation _ _ _ (fun _ same => same)
  | stringCharacters =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .string typed
      cases c <;> cases tag
      rename_i s
      have eq : out = countReply s.toList.length := (Option.some.inj delta).symm
      rw [eq]; exact count_relation _ _ _ (fun _ same => same)
  | bytesLength =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨ns,rfl⟩ := typed.canonical_bytes rfl
      have bound := (typed.inv_bytesV rfl).1
      change (if ns.all (· ≤ 255) then some (countReply ns.length) else none) = some out at delta
      rw [ite_eq_left (List.all_eq_true.mpr (by simpa using bound))] at delta
      have eq : out = countReply ns.length := (Option.some.inj delta).symm
      rw [eq]; exact count_relation _ _ _ (fun _ same => same)
  | bytesFromList =>
    cases values with | cons typed rest =>
      cases rest
      have ha : Ty.Annotation P [] [] (.base .byte) := ⟨trivial,trivial,trivial⟩
      obtain ⟨xs,rfl,each⟩ := list_contents ha typed
      obtain ⟨bs,rfl⟩ := typed_bytes each
      change (byteValues _).map _ = some out at delta
      rw [byte_values] at delta
      have eq : out = .val (bytesFromList bs) := (Option.some.inj delta).symm
      rw [eq]
      exact ⟨by simp [List.map_map],by simp⟩
  | bytesToList =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨ns,rfl⟩ := typed.canonical_bytes rfl
      have bound := (typed.inv_bytesV rfl).1
      change (if ns.all (· ≤ 255) then some (.val (.list (ns.map (fun n => .const (.byte n))))) else none) = some out at delta
      rw [ite_eq_left (List.all_eq_true.mpr (by simpa using bound))] at delta
      have eq : out = .val (.list (ns.map (fun n => .const (.byte n)))) := (Option.some.inj delta).symm
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

end Benitoite.Release.Refinement.StandardBytesResponse
