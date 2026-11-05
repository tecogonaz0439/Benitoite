import Benitoite.Release.Refinement.TypeSubstFormation
import Benitoite.Release.Refinement.HandlerContracts

/-! 型置換と固定した宣言表の行支持（設計書 07-04「01-12 との対応」）。 -/
namespace Benitoite.Release.Refinement.TypeSubstRowObstruction
noncomputable section
set_option maxHeartbeats 2000000

def inner : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def ioSig : PrimSig := {
  tparams := [], neffs := 0, names := ["f"], params := [inner],
  ret := .base .unit, eff := Eff.single "IO", admits := fun _ _ => True,
  kind := .io, opEff := some "IO" }

theorem no_rows : ¬ ioSig.tel.RowsIn (· < ioSig.neffs) := by
  intro h
  exact Nat.not_lt_zero 0 (h.1.2.2.1 0 (by rfl))

theorem clause_sig_rejects_row {P B e sg} (hs : B.sig "bad" = some ioSig) :
    ¬ ClauseSig P B e (.prim "bad") sg := by
  intro h
  exact no_rows (h.sourceTelRows rfl hs)

def inputTy : Ty := .reference inner
def rows : List Eff := [Eff.empty]
def sourceCtx : Ctx := [some inputTy, some (.scopePattern .endpoint)]
def targetCtx : Ctx := sourceCtx.bindTypes (typeEnvAt 0 [] rows)

theorem input_wf : inputTy.WF 0 0 0 := by
  simp [inputTy, inner, Ty.WF, Ty.WFList, Eff.WF, Eff.row, NamesWF, Eff.Canonical, Eff.norm]

theorem input_not_rowfree : ¬ inputTy.RowsIn (· < 0) := by
  intro h
  exact Nat.not_lt_zero 0 (h.2.2.1 0 (by rfl))

theorem input_changes : inputTy.substAt 0 [] rows ≠ inputTy.norm := by
  intro h
  have hm := congrArg (fun a : Ty => match a with
    | .reference (.fn _ _ _ e) => Eff.test e (.rho 0)
    | _ => false) h
  simp [inputTy, inner, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    Ty.normTys, rawBindTys, Eff.rawBind, Eff.norm, rows, typeEnvAt, Eff.test,
    Eff.row, Eff.empty, Eff.atoms, substAtoms, instAtoms, rowFails] at hm

/-- 行束縛を持たない内容型は、自由な行変数を持てない。 -/
theorem at_rejects_row {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    (hc : B.valContent name = some inputTy) :
    ¬ AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index := by
  intro h
  cases h with
  | mk _ _ _ _ ht _ _ _ =>
    rcases ht with ⟨_, hn⟩ | ⟨hs, _, hr⟩
    · simp [hc] at hn
    · cases Option.some.inj (hs.symm.trans hc)
      exact input_not_rowfree hr
  | text _ _ _ _ ht _ _ _ =>
    rcases ht with ⟨_, hn⟩ | ⟨hs, _, hr⟩
    · simp [hc] at hn
    · cases Option.some.inj (hs.symm.trans hc)
      exact input_not_rowfree hr

def tokenCon : ConDecl := ⟨"Token", 1, []⟩
def externalProgram : Program := {
  defs := fun _ => none, cons := fun c => if c = "Token" then some tokenCon else none,
  ops := fun _ => none, effects := fun _ => none,
  classes := fun _ => none, impls := fun _ => none }
def phantomTy : Ty := .data "Token" [inner]
def externalSignature : ExternalSignature := {
  component := .mk 0, displayName := "phantom", tparams := [], kinds := [],
  parameters := .done phantomTy Eff.empty, uses := [] }

theorem external_not_rowfree : ¬ externalSignature.parameters.RowsIn (· < 0) := by
  intro h
  exact Nat.not_lt_zero 0 (h.1.1.2.2.1 0 (by rfl))

theorem external_rejects_row : ¬ externalSignature.WF externalProgram :=
  fun h => external_not_rowfree h.sourceTelRows

end
end Benitoite.Release.Refinement.TypeSubstRowObstruction
