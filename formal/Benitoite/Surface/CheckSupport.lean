import Benitoite.Surface.CheckPatterns

/-! 検査全体の原子集合の前提と、型の結び・エフェクトの差。 -/
namespace Benitoite.Surface.CheckTools
open Benitoite.Release

def tyJoin (atoms : List Atom) (a b : Ty) : Option Ty :=
  match a, b with
  | .fn ps r ε, .fn qs s ε' =>
      if tysEq atoms ps qs && tyEq atoms r s then
        some (.fn ps r (unionEff atoms ε ε')) else none
  | _, _ => if tyEq atoms a b then some a else none

theorem tyJoin_sound {atoms a b j} (ha : Ty.AtomsIn atoms a)
    (hb : Ty.AtomsIn atoms b) (h : tyJoin atoms a b = some j) :
    Ty.Le a j ∧ Ty.Le b j := by
  cases a <;> cases b <;> simp only [tyJoin] at h
    <;> split at h <;> simp only [Option.some.injEq, reduceCtorEq] at h
    <;> try (subst j; exact ⟨Or.inl rfl, Or.inl (tyEq_sound ha hb ‹_›).symm⟩)
  rename_i ps r ε qs s ε' hh
  have ⟨hp, hr⟩ := Bool.and_eq_true_iff.mp hh
  have ep := tysEq_sound ha.1 hb.1 hp
  have er := tyEq_sound ha.2.1 hb.2.1 hr
  subst qs; subst s; subst j
  rw [unionEff_eq ha.2.2 hb.2.2]
  constructor
  · exact Or.inr ⟨ps, r, ε, Eff.union ε ε', rfl, rfl, by
      intro a he; simp [Eff.union, he]⟩
  · exact Or.inr ⟨ps, r, ε', Eff.union ε ε', rfl, rfl, by
      intro a he; simp [Eff.union, he]⟩

theorem tyJoin_atoms {atoms a b j} (ha : Ty.AtomsIn atoms a)
    (h : tyJoin atoms a b = some j) : Ty.AtomsIn atoms j := by
  cases a <;> cases b <;> simp only [tyJoin] at h
    <;> split at h <;> simp only [Option.some.injEq, reduceCtorEq] at h <;> try (subst j; exact ha)
  subst j
  exact ⟨ha.1, ha.2.1, unionEff_atoms _ _ _⟩

def diffEff (atoms : List Atom) (ε h : Eff) : Eff :=
  fun a => atoms.contains a && ε a && !h a

theorem diffEff_cover {atoms ε h} (ha : Eff.AtomsIn atoms ε) :
    Eff.Sub ε (Eff.union (diffEff atoms ε h) h) := by
  intro a he
  have hm : atoms.contains a = true := List.elem_eq_true_of_mem (ha a he)
  cases hh : h a <;> simp only [Eff.union, diffEff, hm, he, hh, Bool.not_false, Bool.not_true, Bool.true_and, Bool.or_true, Bool.or_false]

theorem diffEff_atoms (atoms : List Atom) (ε h : Eff) :
    Eff.AtomsIn atoms (diffEff atoms ε h) := by
  intro a ha
  have hh : atoms.contains a = true := ((Bool.and_eq_true_iff.mp ha).1 |> Bool.and_eq_true_iff.mp).1
  exact List.mem_of_elem_eq_true hh

theorem diffEff_mono {atoms ε ε' h} (hh : Eff.Sub ε ε') :
    Eff.Sub (diffEff atoms ε h) (diffEff atoms ε' h) := by
  intro a ha
  have ⟨hmhe, hn⟩ := Bool.and_eq_true_iff.mp ha
  have ⟨hm, he⟩ := Bool.and_eq_true_iff.mp hmhe
  simp only [diffEff, hm, hh a he, hn, Bool.true_and]

theorem singleEff_eq_contains {atoms : List Atom} {l : EffName}
    (h : atoms.contains (.name l) = true) : singleEff atoms (.name l) = Eff.single l :=
  singleEff_eq (List.mem_of_elem_eq_true h)

end Benitoite.Surface.CheckTools

namespace Benitoite.Release
open Benitoite.Surface.CheckTools

def Env.AtomsIn (atoms : List Atom) (Γ : List (Option Ty)) : Prop :=
  ∀ t, some t ∈ Γ → Ty.AtomsIn atoms t

theorem Env.atoms_nil (atoms : List Atom) : Env.AtomsIn atoms [] := by
  intro t ht; cases ht

theorem Env.atoms_get {atoms Γ t} {i : Nat} (h : Env.AtomsIn atoms Γ)
    (hg : Γ[i]? = some (some t)) : Ty.AtomsIn atoms t :=
  h t (List.mem_of_getElem? hg)

theorem Env.atoms_binds {atoms ts} (h : Tys.AtomsIn atoms ts) : Env.AtomsIn atoms (binds ts) := by
  intro t ht
  simp only [binds, List.mem_map, Option.some.injEq, List.mem_reverse] at ht
  obtain ⟨u, hu, rfl⟩ := ht
  exact tysAtoms_iff.mp h u hu

theorem Env.atoms_append {atoms Γ Δ} (h : Env.AtomsIn atoms Γ) (h' : Env.AtomsIn atoms Δ) :
    Env.AtomsIn atoms (Γ ++ Δ) := by
  intro t ht; rcases List.mem_append.mp ht with ht | ht
  · exact h t ht
  · exact h' t ht

theorem Env.atoms_cons {atoms Γ t} (h : Env.AtomsIn atoms Γ) (ht : Ty.AtomsIn atoms t) :
    Env.AtomsIn atoms (some t :: Γ) := by
  intro u hu; simp only [List.mem_cons, Option.some.injEq] at hu
  rcases hu with rfl | hu
  · exact ht
  · exact h u hu

theorem Env.atoms_hideConts {atoms Γ} (h : Env.AtomsIn atoms Γ) :
    Env.AtomsIn atoms (hideConts Γ) := by
  intro t ht
  obtain ⟨o, ho, he⟩ := List.mem_map.mp ht
  cases o with
  | none => simp at he
  | some u => cases u <;> simp at he <;> subst t <;> exact h _ ho

theorem Env.atoms_shiftEnv {atoms Γ} (h : Env.AtomsIn atoms Γ) (n : Nat) :
    Env.AtomsIn atoms (shiftEnv n Γ) := by
  intro t ht
  obtain ⟨o, ho, he⟩ := List.mem_map.mp ht
  cases o with
  | none => cases he
  | some u => simp only [Option.map_some, Option.some.injEq] at he
              subst t; exact shift_atoms (h u ho) n 0

def Builtins.AtomsIn (atoms : List Atom) (B : Builtins) : Prop :=
  ∀ b s, B.sig b = some s → Ty.AtomsIn atoms (.fn s.params s.ret s.eff)
end Benitoite.Release

namespace Benitoite.Surface
open Benitoite.Release

def Declarations.AtomsIn (atoms : List Atom) (D : Declarations) : Prop :=
  (∀ f d, D.funs f = some d →
    Ty.AtomsIn atoms (.fn d.params d.ret d.eff) ∧ Tys.AtomsIn atoms d.dictTys) ∧
  (∀ c cd, D.cons c = some cd → Tys.AtomsIn atoms cd.args) ∧
  (∀ o od, D.ops o = some od → Tys.AtomsIn atoms od.params ∧ Ty.AtomsIn atoms od.ret) ∧
  (∀ cl cd m ms, D.classes cl = some cd → cd.methods m = some ms →
    Ty.AtomsIn atoms (.fn ms.params ms.ret ms.eff)) ∧
  (∀ i id, D.impls i = some id → Ty.AtomsIn atoms id.target ∧ Tys.AtomsIn atoms id.dictTys)

mutual
  def DictEv.AtomsIn (atoms : List Atom) : DictEv → Prop
    | .impl _ ts ds => Tys.AtomsIn atoms ts ∧ DictEvs.AtomsIn atoms ds
    | .local _ => True
    | .super d _ => d.AtomsIn atoms
  def DictEvs.AtomsIn (atoms : List Atom) : List DictEv → Prop
    | [] => True
    | d :: ds => d.AtomsIn atoms ∧ DictEvs.AtomsIn atoms ds
end

def InterpParts.AtomsIn (atoms : List Atom) (parts : List InterpPart) : Prop :=
  ∀ t, .converted t ∈ parts → Ty.AtomsIn atoms t

mutual
  def Expr.AtomsIn (atoms : List Atom) : Expr → Prop
    | .constE t e => t.AtomsIn atoms ∧ e.AtomsIn atoms
    | .funName _ ts es | .primName _ ts es =>
        Tys.AtomsIn atoms ts ∧ ∀ ε ∈ es, ε.AtomsIn atoms
    | .funDicts _ ts es ds ps => Tys.AtomsIn atoms ts ∧
        (∀ ε ∈ es, ε.AtomsIn atoms) ∧ DictEvs.AtomsIn atoms ds ∧ Tys.AtomsIn atoms ps
    | .methName d _ ts es ds ps => d.AtomsIn atoms ∧ Tys.AtomsIn atoms ts ∧
        (∀ ε ∈ es, ε.AtomsIn atoms) ∧ DictEvs.AtomsIn atoms ds ∧ Tys.AtomsIn atoms ps
    | .opName _ ts | .nullCon _ ts => Tys.AtomsIn atoms ts
    | .conValue _ ts ps => Tys.AtomsIn atoms ts ∧ Tys.AtomsIn atoms ps
    | .paren e | .not e | .resume _ e => e.AtomsIn atoms
    | .conCall _ ts es | .record _ ts _ es => Tys.AtomsIn atoms ts ∧ es.AtomsIn atoms
    | .recordUpdate _ ts _ _ e es => Tys.AtomsIn atoms ts ∧ e.AtomsIn atoms ∧ es.AtomsIn atoms
    | .call f es => f.AtomsIn atoms ∧ es.AtomsIn atoms
    | .pipe a b | .and a b | .or a b => a.AtomsIn atoms ∧ b.AtomsIn atoms
    | .partialCall f args r ε => f.AtomsIn atoms ∧ args.AtomsIn atoms ∧
        r.AtomsIn atoms ∧ ε.AtomsIn atoms
    | .partialCon _ ts args => Tys.AtomsIn atoms ts ∧ args.AtomsIn atoms
    | .binary _ t a b => t.AtomsIn atoms ∧ a.AtomsIn atoms ∧ b.AtomsIn atoms
    | .neg t e | .returnE t e => t.AtomsIn atoms ∧ e.AtomsIn atoms
    | .list t es => t.AtomsIn atoms ∧ es.AtomsIn atoms
    | .listSpread t f before e after => t.AtomsIn atoms ∧ f.AtomsIn atoms ∧
        before.AtomsIn atoms ∧ e.AtomsIn atoms ∧ after.AtomsIn atoms
    | .interpolation parts es fs => InterpParts.AtomsIn atoms parts ∧ es.AtomsIn atoms ∧ fs.AtomsIn atoms
    | .lam ps r ε b => Tys.AtomsIn atoms ps ∧ r.AtomsIn atoms ∧ ε.AtomsIn atoms ∧ b.AtomsIn atoms
    | .ite c y n => c.AtomsIn atoms ∧ y.AtomsIn atoms ∧ n.AtomsIn atoms
    | .elseIf c y n => c.AtomsIn atoms ∧ y.AtomsIn atoms ∧ n.AtomsIn atoms
    | .ifOnly c y => c.AtomsIn atoms ∧ y.AtomsIn atoms
    | .matchE t e arms => t.AtomsIn atoms ∧ e.AtomsIn atoms ∧ arms.AtomsIn atoms
    | .tryResult ts _ _ e | .tryOption ts _ _ e => Tys.AtomsIn atoms ts ∧ e.AtomsIn atoms
    | .withE _ e b => e.AtomsIn atoms ∧ b.AtomsIn atoms
    | .lazyE b => b.AtomsIn atoms
    | .handleE b cs => b.AtomsIn atoms ∧ cs.AtomsIn atoms
    | _ => True
  def Exprs.AtomsIn (atoms : List Atom) : Exprs → Prop
    | .nil => True
    | .cons e es => e.AtomsIn atoms ∧ es.AtomsIn atoms
  def HoleArgs.AtomsIn (atoms : List Atom) : HoleArgs → Prop
    | .nil => True
    | .expr e es => e.AtomsIn atoms ∧ es.AtomsIn atoms
    | .hole t es => t.AtomsIn atoms ∧ es.AtomsIn atoms
  def Block.AtomsIn (atoms : List Atom) : Block → Prop
    | .empty => True
    | .last e | .lastDiscard e => e.AtomsIn atoms
    | .lastBind _ t e | .lastPat _ _ t e => t.AtomsIn atoms ∧ e.AtomsIn atoms
    | .bind _ t e b | .bindPat _ _ t e b => t.AtomsIn atoms ∧ e.AtomsIn atoms ∧ b.AtomsIn atoms
    | .discard e b | .seq e b => e.AtomsIn atoms ∧ b.AtomsIn atoms
  def Arms.AtomsIn (atoms : List Atom) : Arms → Prop
    | .nil => True
    | .cons _ g b rest => (∀ e, g = some e → e.AtomsIn atoms) ∧ b.AtomsIn atoms ∧ rest.AtomsIn atoms
  def Clauses.AtomsIn (atoms : List Atom) : Clauses → Prop
    | .nil => True
    | .cons _ _ _ b rest => b.AtomsIn atoms ∧ rest.AtomsIn atoms
end

def Def.AtomsIn (atoms : List Atom) (d : Def) : Prop :=
  Ty.AtomsIn atoms (.fn (d.dictTys ++ d.params) d.ret d.eff) ∧ d.body.AtomsIn atoms

def ImplDecl.AtomsIn (atoms : List Atom) (id : ImplDecl) : Prop :=
  id.target.AtomsIn atoms ∧ Tys.AtomsIn atoms id.dictTys ∧
  (∀ s d, id.supers s = some d → d.AtomsIn atoms) ∧
  (∀ m b, id.methods m = some b → b.AtomsIn atoms)

def OpPrimTypeArgs (op : OpPrim) : Prop :=
  ∀ o t b ts, op o t = some (b, ts) → ts = o.typeArgs t

theorem Declarations.atoms_con {atoms} {D : Declarations} (h : D.AtomsIn atoms) :
    CheckTools.ConAtomsIn atoms D.patternProgram := h.2.1

theorem OpPrimTypeArgs.atoms {atoms op o t b ts} (h : OpPrimTypeArgs op)
    (ht : t.AtomsIn atoms) (ho : op o t = some (b, ts)) : Tys.AtomsIn atoms ts := by
  rw [h o t b ts ho]
  cases o with
  | neg => trivial
  | binary o => cases o <;> simp [Operator.typeArgs, Tys.AtomsIn, ht]

end Benitoite.Surface
