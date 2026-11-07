import Benitoite.Exchange.Convert
import Benitoite.Release.Refinement.Finite

/-! 型と効果を、有限の原子の一覧に対する支持の証拠とともに形成する。 -/
namespace Benitoite.Exchange.FormationTypes

namespace R
export Benitoite.Release.Refinement (Ty Eff Atom Tel)
end R

private theorem signatureTel_support (atoms : List R.Atom) (names : List String)
    (params : List R.Ty) (ret : R.Ty) (eff : R.Eff)
    (hp : Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) params) (hr : ret.Support (· ∈ atoms))
    (he : eff.Support (· ∈ atoms)) :
    (Benitoite.Release.Refinement.signatureTel names params ret eff).Support (· ∈ atoms) := by
  induction names generalizing params with
  | nil => exact ⟨hr, he⟩
  | cons name names ih =>
    cases params with
    | nil => exact ⟨hr, he⟩
    | cons param params => exact ⟨hp.1, ih params hp.2⟩

mutual
  /-- 型のすべての子と潜在効果を保持し、支持を各構成子で組み立てる。 -/
  def formedTy (atoms : List R.Atom) (ty : Ty) :
      Except String {a : R.Ty // a.Support (· ∈ atoms)} := do
    match ty with
    | .base name => return ⟨.base (← baseTy name), trivial⟩
    | .opaque name ix => return ⟨.opaque name ix, trivial⟩
    | .data name args =>
      let args ← formedTys atoms args
      return ⟨.data name args.val, args.property⟩
    | .list elem =>
      let elem ← formedTy atoms elem
      return ⟨.list elem.val, elem.property⟩
    | .fn names params ret eff =>
      checkNames names params.length
      let params ← formedTys atoms params
      let ret ← formedTy atoms ret
      let eff ← formedEff atoms eff
      return ⟨.fn names params.val ret.val eff.val, params.property, ret.property, eff.property⟩
    | .tvar index => return ⟨.tvar index, trivial⟩
    | .reference elem =>
      let elem ← formedTy atoms elem
      return ⟨.reference elem.val, elem.property⟩
    | .lazyT elem =>
      let elem ← formedTy atoms elem
      return ⟨.lazy elem.val, elem.property⟩
    | .map key value =>
      let key ← formedTy atoms key
      let value ← formedTy atoms value
      return ⟨.map key.val value.val, key.property, value.property⟩
    | .set elem =>
      let elem ← formedTy atoms elem
      return ⟨.set elem.val, elem.property⟩
    | .bytes => return ⟨.bytes, trivial⟩
    | .dict cls arg =>
      let arg ← formedTy atoms arg
      return ⟨.dict cls arg.val, arg.property⟩
    | .tapp index args =>
      let args ← formedTys atoms args
      return ⟨.tapp index args.val, args.property⟩
    | .ctor head => return ⟨.ctor head.toRelease, trivial⟩
    | .refined base predicate =>
      let base ← formedTy atoms base
      return ⟨.refined base.val predicate, base.property⟩
    | .dependentFn names params ret eff =>
      checkNames names params.length
      let params ← formedTys atoms params
      let ret ← formedTy atoms ret
      let eff ← formedEff atoms eff
      return ⟨.dependentFn (Benitoite.Release.Refinement.signatureTel names params.val ret.val eff.val),
        signatureTel_support atoms names params.val ret.val eff.val params.property ret.property eff.property⟩
    | .cont argument result eff =>
      let argument ← formedTy atoms argument
      let result ← formedTy atoms result
      let eff ← formedEff atoms eff
      return ⟨.cont argument.val result.val eff.val, argument.property, result.property, eff.property⟩
    | .external id args =>
      let args ← formedTys atoms args
      return ⟨.external (.mk id) args.val, args.property⟩
    | .scoped name kind ix => return ⟨.scoped name kind ix, trivial⟩
    | .pathBases => return ⟨.pathBases, trivial⟩
    | .scopePattern kind => return ⟨.scopePattern kind, trivial⟩
  termination_by 2 * sizeOf ty + 1
  decreasing_by all_goals simp_wf <;> omega

  /-- 型の列の順と長さを保ち、全項目の支持を返す。 -/
  def formedTys (atoms : List R.Atom) (types : List Ty) :
      Except String {as : List R.Ty // Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) as} := do
    match types with
    | [] => return ⟨[], trivial⟩
    | ty :: types =>
      let ty ← formedTy atoms ty
      let types ← formedTys atoms types
      return ⟨ty.val :: types.val, ty.property, types.property⟩
  termination_by 2 * sizeOf types + 1
  decreasing_by all_goals simp_wf <;> omega

  /-- 所属する名前と行の原子を有限列から読み、Failの型の支持も保持する。 -/
  def formedEff (atoms : List R.Atom) (eff : Eff) :
      Except String {e : R.Eff // e.Support (· ∈ atoms)} := do
    let listed := eff.filterMap Atom.toRelease
    if hlisted : listed.all (fun atom => atoms.contains atom) = true then
      let fails ← formedFails atoms eff
      let raw : R.Eff := ⟨Eff.readAtoms eff, fails.val⟩
      have support : raw.Support (· ∈ atoms) := by
        refine ⟨?_, fails.property⟩
        intro atom hatom
        have hm : atom ∈ listed := List.contains_iff_mem.mp hatom
        exact List.contains_iff_mem.mp (List.all_eq_true.mp hlisted atom hm)
      if fails.val.isEmpty then
        return ⟨Eff.namesToRelease eff, by
          refine ⟨support.1, trivial⟩⟩
      return ⟨raw.normWith atoms, Benitoite.Release.Refinement.Eff.normWith_support atoms raw support⟩
    else throw "effect atom is not in the formation atom list"
  termination_by 2 * sizeOf eff + 1
  decreasing_by all_goals simp_wf <;> omega

  /-- Failの順を保った型の列。名前と行の原子はこの列へ混ぜない。 -/
  def formedFails (atoms : List R.Atom) (eff : Eff) :
      Except String {as : List R.Ty // Benitoite.Release.Refinement.Ty.SupportList (· ∈ atoms) as} := do
    match eff with
    | [] => return ⟨[], trivial⟩
    | .fail ty :: rest =>
      let ty ← formedTy atoms ty
      let rest ← formedFails atoms rest
      return ⟨ty.val :: rest.val, ty.property, rest.property⟩
    | _ :: rest => formedFails atoms rest
  termination_by 2 * sizeOf eff
  decreasing_by all_goals simp_wf <;> omega
end

end Benitoite.Exchange.FormationTypes
