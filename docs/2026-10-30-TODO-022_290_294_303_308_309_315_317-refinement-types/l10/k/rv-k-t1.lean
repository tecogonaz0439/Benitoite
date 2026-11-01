import Benitoite.Release.Refinement.LegacyValues
/-! 節の操作の署名: 組み込みの操作の元の署名に範囲外の型変数があっても、全入力が成り立ち、
新しい節の型付け（sg.WF）は成り立たない。 -/
namespace RVK1
open Benitoite.Release.Refinement
noncomputable section

def oldSig : Benitoite.Release.PrimSig := {
  tparams := [], neffs := 0, names := ["x"], params := [.tvar 0], ret := .base .unit,
  eff := Benitoite.Release.Eff.single "E", admits := fun _ _ => True, kind := .pure, opEff := some "E" }
def newSig : PrimSig := {
  tparams := [], neffs := 0, names := ["x"], params := embedParameters [.tvar 0],
  ret := (embedTy (.base .unit)).shiftV 1 0,
  eff := (embedEff (Benitoite.Release.Eff.single "E")).shiftV 1 0,
  admits := fun _ _ => True, kind := .pure, opEff := some "E" }
def B0 : Benitoite.Release.Builtins := {
  sig := fun _ => some oldSig, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => some ["op"],
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def B : Builtins := {
  sig := fun _ => some newSig, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => some ["op"],
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }


theorem kinds_wf : K.WF P0 := ⟨(by intro f d h; cases h), (by intro cl cd m ms h; cases h)⟩
theorem decls : LegacyDeclarationsInput K P0 B0 B :=
  ⟨(by intro f d h; cases h), (by intro f d h; cases h), (by intro _ _ _ _ h; cases h), (by intro f d h; cases h)⟩
theorem sigs : LegacyPrimSignature oldSig newSig :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, fun _ _ => Iff.rfl⟩
theorem tables : LegacyTables K P0 B0 B := by
  refine ⟨?_, ?_, rfl, rfl, rfl, rfl, rfl, rfl, ?_, ?_, ?_, ?_, ?_⟩
  · intro b s0 h; cases h; exact ⟨newSig, rfl, sigs⟩
  · intro C a p; exact Iff.rfl
  · intro o; rfl
  · intro b rs; exact Iff.rfl
  · intro c cd _ _ h; cases h
  · intro c cd h; cases h
  · intro c cd h; cases h

def store : Benitoite.Release.StoreTy := fun _ => none
def unit : Benitoite.Release.Ty := .base .unit
def C0 : List Benitoite.Release.TParam := [{}]
def eE : Benitoite.Release.Eff := Benitoite.Release.Eff.empty
def body : Benitoite.Release.Comp := .ret (.const .unit)
def clause : Benitoite.Release.Clause := .mk (.prim "b") 1 0 body
def sg0 : Benitoite.Release.OpSig := ⟨[], ["x"], [.tvar 0], .base .unit, "E"⟩

theorem clause_sig : Benitoite.Release.ClauseSig P0 B0 eE (.prim "b") sg0 :=
  ⟨.top, Or.inl rfl, rfl⟩

theorem eff_norm : Benitoite.Release.Eff.norm eE = eE :=
  Benitoite.Release.Eff.canonical_ofAtoms _
theorem shift_empty : Benitoite.Release.Eff.shift 0 0 eE = eE := by
  rw [Benitoite.Release.Eff.shift_zero_norm, eff_norm]
theorem shift_unit : Benitoite.Release.Ty.shift 0 0 unit = unit := by
  rw [Benitoite.Release.Ty.shift_zero_norm]; rfl

def Γc : List (Option Benitoite.Release.Ty) := [some (.cont unit unit eE), some (.tvar 0)]

theorem input_unit (Δ : LegacyInputCtx) : LegacyTypeInput K P0 Δ unit .value :=
  ⟨trivial, trivial, trivial, trivial, trivial⟩
theorem row (Δ : LegacyInputCtx) : LegacyRowsInput K P0 Δ [eE] := by
  intro e he
  simp only [List.mem_singleton] at he; subst e
  refine ⟨⟨⟨rfl, by simp⟩, trivial, trivial, trivial⟩, ?_, ⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩, ?_⟩
  · exact ⟨⟨rfl, by simp⟩, trivial, trivial, trivial, embed_canonical rfl⟩
  · refine ⟨trivial, trivial, ?_, trivial⟩
    intro name ix h
    cases ix with
    | fixed _ => trivial
    | rvar i => simp [embedAtoms, Atom.toOld?] at h

theorem input_tvar (n : Nat) : LegacyTypeInput K P0 ⟨[.value], C0, 0, n⟩ (.tvar 0) .value :=
  ⟨rfl, Nat.zero_lt_succ 0, trivial, trivial, trivial⟩
theorem input_cont (n : Nat) : LegacyTypeInput K P0 ⟨[.value], C0, 0, n⟩ (.cont unit unit eE) .value := by
  have h := (row ⟨[.value], C0, 0, n⟩) eE (by simp)
  exact ⟨⟨trivial, trivial, h.1.2.2.2⟩, ⟨trivial, trivial, h.2.1.2.2.2.1, h.2.1.2.2.2.2⟩, ⟨trivial, trivial, h.2.2.1.2.2⟩,
    ⟨trivial, trivial, h.2.2.2.1.2.2⟩, ⟨trivial, trivial, h.2.2.2.2.2.2⟩⟩

theorem ctx_child : LegacyNodeContext K P0 [.value] store.hideBuilders C0 Γc := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h
    match i, h with
    | 0, h => simp only [Γc, List.getElem?_cons_zero, Option.some.injEq] at h; subst a
              exact ⟨input_cont _, (input_cont 2).annotation_at rfl rfl _⟩
    | 1, h => simp only [Γc, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.some.injEq] at h; subst a
              exact ⟨input_tvar _, (input_tvar 2).annotation_at rfl rfl _⟩
    | n+2, h => simp [Γc] at h

abbrev Q0 := Benitoite.Release.Qempty
theorem const_input : LegacyOutputInput K P0 B0 B (.value [.value] store.hideBuilders Q0 C0 Γc (.const .unit) unit) :=
  .node .V_Const ⟨ctx_child, trivial, trivial, by intro a ha; simp at ha; subst a; exact input_unit _⟩ (by simp)
theorem child_input : LegacyOutputInput K P0 B0 B
    (.comp [.value] store.hideBuilders Q0 C0 Γc none body unit eE []) :=
  .node .C_Return ⟨ctx_child, trivial, by intro a ha; simp at ha; subst a; exact input_unit _, row _, by simp [LegacyNodeLocal]⟩
    (by intro c hc; simp only [List.mem_singleton] at hc; subst c; exact const_input)

theorem ctx_root : LegacyNodeContext K P0 [.value] store C0 [] := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

theorem syntax_body (Δ : LegacyInputCtx) : LegacyCompInput K P0 B0 B Δ body := trivial
theorem syntax_clause : LegacyClausesInput K P0 B0 B ⟨[.value], C0, 0, 0⟩ [clause] :=
  ⟨⟨sg0, rfl, rfl, rfl, trivial⟩, trivial⟩

theorem rows2 (Δ : LegacyInputCtx) : LegacyRowsInput K P0 Δ [eE, eE] := by
  intro e he; apply row Δ e; simp at he; simp [he]

theorem nil_input : LegacyOutputInput K P0 B0 B (.clauses [.value] store Q0 C0 [] none eE [] unit eE []) :=
  .node .Clauses_nil ⟨ctx_root, trivial, by intro a ha; simp at ha; subst a; exact input_unit _, rows2 _, by simp [LegacyNodeLocal]⟩ (by simp)

/-- 旧の節・文脈・kind・構文の全入力が成り立つ。 -/
theorem clause_input : LegacyOutputInput K P0 B0 B (.clauses [.value] store Q0 C0 [] none eE [clause] unit eE []) := by
  refine .node (.Clauses_cons clause_sig (by simp [Benitoite.Release.NamesWF, sg0]) rfl rfl trivial) ⟨ctx_root, syntax_clause,
    by intro a ha; simp at ha; subst a; exact input_unit _, rows2 _, by simp [LegacyNodeLocal]⟩ ?_
  intro c hc
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hc
  rcases hc with rfl | rfl
  · have g : (Benitoite.Release.binds sg0.params ++ Benitoite.Release.shiftEnv 0 []) = [some (.tvar 0)] := rfl
    simp only [sg0, List.length_nil, List.replicate_zero, List.nil_append, shift_unit, shift_empty, g] at *
    exact child_input
  · exact nil_input

theorem old_holds : LegacyJudgment.OldHolds P0 B0 (.clauses [.value] store Q0 C0 [] none eE [clause] unit eE []) :=
  clause_input.old

/-- 同じ節の新しい判断は無い。 -/
theorem no_new {Ψ : StoreTy} {Q C Γ Φ R eb t e Δ} :
    ¬ HasTypeClausesQ (embedProgramWithKinds K P0) B Ψ Q C Γ Φ R eb (embedClauses [clause]) t e Δ := by
  intro h
  cases h with
  | cons hs _ _ _ hwf _ _ =>
    obtain ⟨S, _, hop⟩ := hs
    simp only [opSigAt] at hop
    change some _ = some _ at hop
    cases hop
    exact Nat.not_lt_zero 0 hwf.1.1

#print axioms clause_input
#print axioms no_new
#print axioms tables
end
end RVK1
