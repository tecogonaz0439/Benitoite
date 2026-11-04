import Benitoite.Release.Refinement.StandardByteStringResponse
import Benitoite.Release.Refinement.StandardCharacterData

/-! # 同じCharacterから構成する分類と文字列の応答 -/
namespace Benitoite.Release.Refinement.StandardCharacterResponse
noncomputable section
set_option maxRecDepth 5000

inductive API where
 | toString | isASCIIDigit | isASCIIWhitespace | isAlphabetic | isNumeric
 | isWhitespace | isUppercase | isLowercase | toUppercase | toLowercase
 deriving DecidableEq

def API.name : API → String
 | .toString => "Character.toString"
 | .isASCIIDigit => "Character.isASCIIDigit"
 | .isASCIIWhitespace => "Character.isASCIIWhitespace"
 | .isAlphabetic => "Character.isAlphabetic"
 | .isNumeric => "Character.isNumeric"
 | .isWhitespace => "Character.isWhitespace"
 | .isUppercase => "Character.isUppercase"
 | .isLowercase => "Character.isLowercase"
 | .toUppercase => "Character.toUppercase"
 | .toLowercase => "Character.toLowercase"

def API.result : API → Ty
 | .toString | .toUppercase | .toLowercase => .base .string
 | _ => .base .boolean

def API.signature (api : API) : PrimSig :=
 ⟨[],0,["c"],[.base .character],api.result,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

private def inRanges (n : Nat) (rs : List (Nat × Nat)) : Bool :=
 rs.any fun (lo,hi) => lo ≤ n && n ≤ hi
private def caseString (c : Char) (mapping : List (Nat × List Nat)) : String :=
 String.ofList (((mapping.lookup c.toNat).getD [c.toNat]).map Char.ofNat)

def API.value (api : API) (c : Char) : Val := match api with
 | .toString => .const (.string (String.ofList [c]))
 | .toUppercase => .const (.string (caseString c StandardCharacterData.upper))
 | .toLowercase => .const (.string (caseString c StandardCharacterData.lower))
 | .isASCIIDigit => .const (.boolean ('0'.toNat ≤ c.toNat && c.toNat ≤ '9'.toNat))
 | .isASCIIWhitespace => .const (.boolean (c == ' ' || c == '\t' || c == '\n' || c == '\r'))
 | .isAlphabetic => .const (.boolean (inRanges c.toNat StandardCharacterData.alphabetic))
 | .isNumeric => .const (.boolean (inRanges c.toNat StandardCharacterData.numeric))
 | .isWhitespace => .const (.boolean (inRanges c.toNat StandardCharacterData.whitespace))
 | .isUppercase => .const (.boolean (inRanges c.toNat StandardCharacterData.uppercase))
 | .isLowercase => .const (.boolean (inRanges c.toNat StandardCharacterData.lowercase))

def API.delta (api : API) (name : PrimName) (ts : List Ty) (es : List Eff)
 (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
 if name=api.name ∧ ts=[] ∧ es=[] ∧ rs=[] then
  match ws with | [.const (.character c)] => some (.val (api.value c)) | _ => none
 else none

private theorem instantiated (api : API) :
 instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
 Ty.toTel ["c"] [.base .character] api.result Eff.empty := by
 have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]
 cases api <;> simp [emptyRange,API.signature,API.result,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
  Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
  Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,
  Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]

private theorem arguments {P B Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
 ts=[] ∧ es=[] ∧ rs=[] ∧ a=api.result ∧ e=Eff.empty ∧
 ∃ c : Char, ws=[.const (.character c)] := by
 have ts0 : ts=[] := List.length_eq_zero_iff.mp args.admissible.typeCount
 have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst ts; subst es; subst rs
 have values := args.arguments
 rw [instantiated] at values
 obtain ⟨values,ar,ee⟩ := values.toTelValues (by simp [NamesWF])
 cases values with | cons typed rest =>
  cases rest
  obtain ⟨c,rfl,_,tag⟩ := typed.canonical_scalar rfl
  cases c <;> cases tag
  have norm : api.result.norm=api.result := by cases api <;> rfl
  exact ⟨rfl,rfl,rfl,args.result.2.symm.trans (ar.trans norm),args.effect.2.symm.trans ee,_,rfl⟩

/-- 入力のscalarを逆転し、有限表の同じ結果を通常型へ接続する。 -/
theorem response {P B Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
 ∃ out, api.delta api.name ts es rs ws=some out ∧ Outcome.Typed P B Ψ out a ∧
 AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 obtain ⟨rfl,rfl,rfl,rfl,rfl,c,rfl⟩ := arguments api args
 refine ⟨.val (api.value c),by simp [API.delta],?_,?_,by intro i; simp⟩
 · cases api <;> exact ⟨.V_Const trivial,trivial⟩
 · cases api <;> intro σ _ _ <;> trivial

def API.all : List API := [.toString,.isASCIIDigit,.isASCIIWhitespace,.isAlphabetic,.isNumeric,
 .isWhitespace,.isUppercase,.isLowercase,.toUppercase,.toLowercase]
def lookup (b : PrimName) : Option PrimSig :=
 API.all.findSome? (fun api => if b=api.name then some api.signature else none)
def table (base : Builtins) : Builtins :=
 {base with sig := lookup,delta := fun b ts es rs ws =>
  API.all.findSome? (fun api => api.delta b ts es rs ws)}

/-- 全十実名について同じ有限表のlookupとδを読む。 -/
theorem table_response {P base Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs P (table base) Ψ api.name api.signature ts es rs ws a e) :
 (table base).sig api.name=some api.signature ∧
 ∃ out, (table base).delta api.name ts es rs ws=some out ∧
 Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 obtain ⟨rfl,rfl,rfl,rfl,rfl,c,rfl⟩ := arguments api args
 have h := response api args
 refine ⟨?_,?_⟩
 · cases api <;> simp [table,lookup,API.all,API.name,List.findSome?]
 · obtain ⟨out,delta,typed,adequate,nonexit⟩ := h
   refine ⟨out,?_,typed,adequate,nonexit⟩
   have eq : out=.val (api.value c) := (Option.some.inj (by simpa [API.delta] using delta)).symm
   subst out
   cases api <;> simp [table,API.all,API.delta,API.name,List.findSome?]

example {P base Ψ ts es rs ws a e} (api : API)
 (args : BuiltinArgs P (table base) Ψ api.name api.signature ts es rs ws a e) := table_response api args
example : API.value .toUppercase 'ß' = .const (.string "SS") := by rfl
example : API.value .isNumeric '½' = .const (.boolean true) := by rfl
end
end Benitoite.Release.Refinement.StandardCharacterResponse
