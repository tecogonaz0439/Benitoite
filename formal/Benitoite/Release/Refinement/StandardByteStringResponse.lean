import Benitoite.Release.Refinement.StandardScalarResponse

/-! # Byteの十進文字列変換と全型付き入力の応答 -/
namespace Benitoite.Release.Refinement.StandardByteStringResponse
noncomputable section

def signature : PrimSig :=
 ⟨[],0,["b"],[.base .byte],.base .string,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

def delta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
 (ws : List Val) : Option Outcome :=
 match name,ts,es,rs,ws with
 | "Byte.toString",[],[],[],[.const (.byte b)] =>
   if b≤255 then some (.val (.const (.string (toString b)))) else none
 | _,_,_,_,_ => none

private theorem instantiated :
 instantiatedTel (Tel.instR [] signature.tel) [] [] =
 .param "b" (.base .byte) (.done (.base .string) Eff.empty) := by
 have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]
 simp [emptyRange,signature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
  Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
  Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
  Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]

private theorem arguments {P B Ψ ts es rs ws a e}
 (args : BuiltinArgs P B Ψ "Byte.toString" signature ts es rs ws a e) :
 ts=[] ∧ es=[] ∧ rs=[] ∧ a=.base .string ∧ e=Eff.empty ∧
 ∃ b : Nat, b≤255 ∧ ws=[.const (.byte b)] := by
 have ts0 : ts=[] := List.length_eq_zero_iff.mp args.admissible.typeCount
 have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
 have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
 subst ts; subst es; subst rs
 have values := args.arguments
 rw [instantiated] at values
 change HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
  (Ty.toTel ["b"] [.base .byte] (.base .string) Eff.empty) a e at values
 obtain ⟨values,ar,ee⟩ := values.toTelValues (by simp [NamesWF])
 cases values with | cons typed rest =>
  cases rest
  obtain ⟨c,rfl,hc,tag⟩ := typed.canonical_scalar rfl
  cases c <;> cases tag
  rename_i b
  exact ⟨rfl,rfl,rfl,args.result.2.symm.trans ar,args.effect.2.symm.trans ee,b,hc,rfl⟩

/-- 元のbという引数を保ち、出力型や正常値を前提にせず応答を構成する。 -/
theorem response {P B Ψ ts es rs ws a e}
 (args : BuiltinArgs P B Ψ "Byte.toString" signature ts es rs ws a e) :
 ∃ out, delta "Byte.toString" ts es rs ws=some out ∧ Outcome.Typed P B Ψ out a ∧
 AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
 obtain ⟨rfl,rfl,rfl,rfl,rfl,b,bound,rfl⟩ := arguments args
 exact ⟨.val (.const (.string (toString b))),by simp [delta,bound],
  ⟨.V_Const trivial,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩

def table (base : Builtins) : Builtins :=
 {base with sig := fun b => if b="Byte.toString" then some signature else none,delta := delta}

theorem table_response {P base Ψ ts es rs ws a e}
 (args : BuiltinArgs P (table base) Ψ "Byte.toString" signature ts es rs ws a e) :
 (table base).sig "Byte.toString"=some signature ∧
 ∃ out, (table base).delta "Byte.toString" ts es rs ws=some out ∧
 Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) :=
 ⟨by rfl,response args⟩

example {P base Ψ ts es rs ws a e}
 (args : BuiltinArgs P (table base) Ψ "Byte.toString" signature ts es rs ws a e) :
 ∃ out, (table base).delta "Byte.toString" ts es rs ws=some out ∧
 Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) :=
 (table_response args).2
example : delta "Byte.toString" [] [] [] [.const (.byte 255)]=
 some (.val (.const (.string "255"))) := rfl
end
end Benitoite.Release.Refinement.StandardByteStringResponse
