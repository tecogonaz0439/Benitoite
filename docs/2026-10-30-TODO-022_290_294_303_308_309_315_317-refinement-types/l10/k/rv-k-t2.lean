import Benitoite.Release.Refinement.LegacyValues
/-! 高 kind の `.tapp` を署名に持つ関数を、実際の V_Fun 全入力と新判断まで通す。 -/
namespace RVK2
open Benitoite.Release.Refinement
noncomputable section

def optionDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, []⟩
def eE : Benitoite.Release.Eff := Benitoite.Release.Eff.empty
def unit : Benitoite.Release.Ty := .base .unit
def fd : Benitoite.Release.Def :=
  ⟨[{}], 0, ["x"], [.tapp 0 [unit]], unit, eE, .ret (.const .unit)⟩
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [.constructor 1], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => some fd, cons := fun _ => some optionDecl, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B0 : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def B : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def opt : Benitoite.Release.Ty := .ctor (.data "Option")
def result : Benitoite.Release.Ty := Benitoite.Release.fnTy fd.names fd.params fd.ret fd.eff [opt] []


theorem subst_eff : Benitoite.Release.Eff.substAt 0 [opt] [] eE = eE := by
  show Benitoite.Release.EffR.mk _ [] = Benitoite.Release.EffR.mk _ []
  congr 1
  funext x
  cases x <;> rfl
theorem result_eq : result = .fn ["x"] [.data "Option" [unit]] unit eE := by
  show Benitoite.Release.Ty.fn ["x"] [.data "Option" [unit]] unit (Benitoite.Release.Eff.substAt 0 [opt] [] eE) = _
  rw [subst_eff]

theorem arity : (embedProgramWithKinds K P0).DataArity "Option" 1 := by
  refine ⟨⟨"None", embedConDecl optionDecl, rfl, rfl⟩, ?_⟩
  intro c cd hc _
  change some (embedConDecl optionDecl) = some cd at hc
  cases hc; rfl
theorem opt_kind : (embedTy opt).HasKind (embedProgramWithKinds K P0) [] (.constructor 1) := TyCon.arity_data arity
theorem unit_input (Δ : LegacyInputCtx) : LegacyTypeInput K P0 Δ unit .value := ⟨trivial, trivial, trivial, trivial, trivial⟩

theorem canon : (embedEff eE).Canonical := embed_canonical rfl
theorem atoms : Eff.RangesScoped 0 (embedEff eE) := by
  refine ⟨?_, trivial⟩
  intro name ix h
  cases ix with
  | fixed _ => trivial
  | rvar i => simp [embedEff, eE, embedAtoms, Atom.toOld?] at h
theorem rows_nil (Δ : LegacyInputCtx) : LegacyRowsInput K P0 Δ [] := by simp [LegacyRowsInput]

theorem result_input (Δ : LegacyInputCtx) (h : Δ.nr = 0) : LegacyTypeInput K P0 Δ result .value := by
  rw [result_eq]; obtain ⟨κ, c, nr, nv⟩ := Δ; subst h
  refine ⟨⟨⟨rfl, by simp⟩, ⟨⟨(TyCon.arity_data arity), ⟨trivial, trivial⟩⟩, trivial⟩, trivial, trivial⟩,
    ⟨⟨rfl, by simp⟩, ⟨⟨trivial, trivial⟩, trivial⟩, trivial, trivial, canon⟩, embedTy_sorted _ _,
    ⟨⟨⟨⟨1, arity, rfl⟩, trivial, trivial⟩, trivial⟩, trivial, trivial⟩, ⟨⟨⟨trivial, trivial⟩, trivial⟩, trivial, atoms⟩⟩

theorem source_input : LegacyTypeInput K P0 ⟨[.constructor 1], [{}], 0, 0⟩
    (.fn fd.names fd.params fd.ret fd.eff) .value := by
  refine ⟨⟨⟨rfl, by simp [fd]⟩, ⟨⟨rfl, ⟨trivial, trivial⟩⟩, trivial⟩, trivial, trivial⟩,
    ⟨⟨rfl, by simp [fd]⟩, ⟨⟨Nat.zero_lt_succ 0, ⟨trivial, trivial⟩⟩, trivial⟩, trivial, trivial, canon⟩,
    embedTy_sorted _ _, ⟨⟨⟨trivial, trivial⟩, trivial⟩, trivial, trivial⟩, ⟨⟨⟨trivial, trivial⟩, trivial⟩, trivial, atoms⟩⟩

theorem syntax_ : LegacyValueInput K P0 B0 B .closed (.fnRef "f" [opt] []) := by
  refine ⟨fd, rfl, source_input, ⟨rfl, ?_⟩, rows_nil _⟩
  intro i a k ha hk
  cases i with
  | zero =>
    simp only [K, List.getElem?_cons_zero, Option.some.injEq] at ha hk; subst a; subst k
    exact ⟨opt_kind, trivial, trivial, ⟨1, arity⟩, trivial⟩
  | succ i => simp at ha


theorem old_q : ∀ i, ¬ Benitoite.Release.Qsig fd.params fd.ret fd.eff i := by
  intro i h
  simp [Benitoite.Release.Qsig, fd, Benitoite.Release.QTys, Benitoite.Release.QTy, Benitoite.Release.QEff, unit, eE, Benitoite.Release.Eff.empty, Benitoite.Release.Eff.ofAtoms, Benitoite.Release.Qempty] at h

theorem old_admissible : Benitoite.Release.Admissible B0 [] fd.tparams fd.neffs
    (Benitoite.Release.Qsig fd.params fd.ret fd.eff) Benitoite.Release.Qempty [opt] [] fd.eff := by
  refine ⟨⟨rfl, by intros; trivial⟩, ?_, rfl, by simp, ?_, ?_, ?_⟩
  · intro t ht; simp only [List.mem_singleton] at ht; subst t
    exact ⟨trivial, by intro b r e h; cases h⟩
  · exact ⟨by intro i h; simp [fd, eE, Benitoite.Release.Eff.empty, Benitoite.Release.Eff.ofAtoms] at h, trivial⟩
  · intro i h; exact (old_q i h).elim
  · intro i h; exact (old_q i h).elim

def store : Benitoite.Release.StoreTy := fun _ => none
def node : LegacyJudgment := .value [] store Benitoite.Release.Qempty [] [] (.fnRef "f" [opt] []) result

theorem ctx : LegacyNodeContext K P0 [] store [] [] := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

/-- 高 kind の `.tapp` を読む実際の旧の葉の全入力。 -/
theorem node_input : LegacyOutputInput K P0 B0 B node :=
  .node (.V_Fun (d := fd) rfl (by simp [Benitoite.Release.NamesWF, fd]) old_admissible)
    ⟨ctx, syntax_, trivial, by intro a ha; simp only [List.mem_singleton] at ha; subst a; exact result_input _ rfl⟩ (by simp)

theorem tel_eq : (embedDefWithKinds (K.functionParams "f") fd).tel =
    .param "x" (.tapp 0 [.base .unit]) (.done ((embedTy unit).shiftV 1 0) ((embedEff eE).shiftV 1 0)) := rfl


/-- 実際の宣言に対する LegacyDeclarationsInput。 -/
theorem decls : LegacyDeclarationsInput K P0 B0 B := by
  refine ⟨?_, (by intro o od h; cases h), (by intro _ _ _ _ h; cases h), (by intro i id h; cases h)⟩
  intro f d h; cases h
  exact ⟨source_input, trivial⟩
#print axioms node_input
#print axioms decls
end
end RVK2
