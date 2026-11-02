import Benitoite.Release.Refinement.CaptureTransport
import Benitoite.Release.Refinement.TypeShiftTyping

/-! # 文脈の正則性の保存（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement

mutual
  theorem Ty.References.shiftTypes {Γ Δ a k c} (h : Ty.References Γ a)
      (hm : TypeCtxMap k c Γ Δ) : Ty.References Δ (shiftTypes k c a) := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ | ctor _ => trivial
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.References.shiftTypes (a := a) h hm
    | data _ as | external _ as | tapp _ as => exact referencesTys_shiftTypes (as := as) h hm
    | dependentFn t => exact Tel.References.shiftTypes (t := t) h hm
    | fn ns ps r e => exact ⟨referencesTys_shiftTypes h.1 hm,
        Ty.References.shiftTypes h.2.1 hm,referencesEff_shiftTypes h.2.2 hm⟩
    | cont b t e => exact ⟨Ty.References.shiftTypes h.1 hm,
        Ty.References.shiftTypes h.2.1 hm,referencesEff_shiftTypes h.2.2 hm⟩
    | map a b => exact ⟨Ty.References.shiftTypes h.1 hm,Ty.References.shiftTypes h.2 hm⟩
    | refined a p =>
      refine ⟨Ty.References.shiftTypes h.1 hm,?_⟩
      simpa only [upValues_id,predBind_id] using
        Pred.references_bind h.2 (fun i => some (.var i))
          (fun ho => (Ty.ordinary_shiftTypes a k c).mpr ho) hm.references
  theorem Tel.References.shiftTypes {Γ Δ t k c} (h : Tel.References Γ t)
      (hm : TypeCtxMap k c Γ Δ) : Tel.References Δ (shiftTelTypes k c t) := by
    cases t with
    | done a e => exact ⟨Ty.References.shiftTypes h.1 hm,referencesEff_shiftTypes h.2 hm⟩
    | param n a t => exact ⟨Ty.References.shiftTypes h.1 hm,Tel.References.shiftTypes h.2 (hm.extend a)⟩
  theorem referencesTys_shiftTypes {Γ Δ as k c} (h : referencesTys Γ as)
      (hm : TypeCtxMap k c Γ Δ) : referencesTys Δ (shiftTypesList k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.References.shiftTypes h.1 hm,referencesTys_shiftTypes h.2 hm⟩
  theorem referencesEff_shiftTypes {Γ Δ e k c} (h : Eff.References Γ e)
      (hm : TypeCtxMap k c Γ Δ) : Eff.References Δ (shiftRowsTypes k c e) := by
    cases e with
    | mk atoms fs => exact referencesTys_shiftTypes (as := fs) h hm
end

theorem Ctx.Ordered.shiftE {Γ : Ctx} (h : Γ.Ordered) (k : Nat) : (Γ.shiftE k).Ordered := by
  intro i a hi
  have hm := TypeCtxMap.shiftEAt Γ k 0
  simp only [Ctx.shiftE,Ctx.shiftEAt,List.getElem?_map] at hi
  cases hg : Γ[i]? with
  | none => simp [hg] at hi
  | some ob => cases ob with
    | none => simp [hg] at hi
    | some b =>
      simp only [hg,Option.map_some,Option.some.injEq] at hi
      subst a
      apply (h i b hg).shiftTypes
      refine ⟨by simp [Ctx.shiftE,Ctx.shiftEAt],?_⟩
      intro j t ht
      obtain ⟨hij,ht⟩ := Ctx.lookup_outer.mp ht
      exact Ctx.lookup_outer.mpr ⟨hij,hm.lookup j t ht⟩

theorem Ctx.Regular.shiftE {P C Γ} (h : Ctx.Regular P C Γ) (extra : TypeCtx) :
    Ctx.Regular P (extra ++ C) (Γ.shiftE extra.length) := by
  have hm := TypeCtxMap.shiftEAt Γ extra.length 0
  have hC : TypeParamRenaming C (extra ++ C) (shiftIndex extra.length 0) := by
    simpa only [shiftIndex_add] using TypeParamRenaming.prefix C extra
  have ann : ∀ (i : Nat) (a : Ty), (Γ.shiftE extra.length)[i]? = some (some a) →
      Ty.Annotation P (extra ++ C) (Γ.shiftE extra.length) a := by
    intro i a hi
    simp only [Ctx.shiftE,Ctx.shiftEAt,List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some ob => cases ob with
      | none => simp [hg] at hi
      | some b =>
        simp only [hg,Option.map_some,Option.some.injEq] at hi
        subst a
        exact hm.annotation (by simp; omega) ⟨h.wf i b hg,h.sorted i b hg,h.declared i b hg⟩ hC
  exact ⟨fun i a hi => (ann i a hi).wf,fun i a hi => (ann i a hi).sorted,
    fun i a hi => (ann i a hi).declared,h.ordered.shiftE extra.length⟩

theorem OpSig.regular_context {P C Γ t e} (sg : OpSig) (h : Ctx.Regular P C Γ)
    (hp : BinderTypes.Annotations P (sg.tparams ++ C) (Γ.shiftE sg.tparams.length) sg.params)
    (hc : Ty.Annotation P (sg.tparams ++ C) ((Γ.shiftE sg.tparams.length).extendMany sg.params)
      (sg.continuation t e)) : Ctx.Regular P (sg.tparams ++ C) (sg.context Γ t e) :=
  (hp.extendMany (h.shiftE sg.tparams)).extend hc

theorem failureContext_regular {P C Γ E} (h : Ctx.Regular P C Γ) (he : Ty.Annotation P C Γ E) :
    Ctx.Regular P (TypeCtx.valueParam :: C) (failureContext Γ E) := by
  have hm := TypeCtxMap.shiftEAt Γ 1 0
  have hC : TypeParamRenaming C (TypeCtx.valueParam :: C) (shiftIndex 1 0) := by
    simpa only [shiftIndex_add,List.singleton_append,List.length_cons,List.length_nil] using TypeParamRenaming.prefix C [TypeCtx.valueParam]
  have hE := hm.annotation (by simp) he hC
  exact ((h.shiftE [TypeCtx.valueParam]).extend hE).extendNone

theorem reject_forward_or_cyclic_context {Γ : Ctx}
    (h : (∃ i j, Γ.Depends i j ∧ j ≤ i) ∨ ∃ i, Relation.TransGen Γ.Depends i i) :
    ¬ Γ.Ordered := by
  intro ho
  rcases h with ⟨i,j,hd,hji⟩ | ⟨i,hc⟩
  · have := ho.depends_lt hd; omega
  · exact Ctx.no_dependency_cycle ho i hc


namespace ContextOrderExamples

def selfRef : Ty := .refined (.base .integer) (.eq (.var 0) (.var 1))
def okTy : Ty := .base .integer
def bwdRef : Ty := .refined (.base .integer) (.eq (.var 0) (.var 2))
def fwd : Ctx := [some selfRef]
def back : Ctx := [some bwdRef,some okTy]

theorem fwd_dep : fwd.Depends 0 0 := by
  refine ⟨selfRef,rfl,?_⟩
  simp [selfRef,fwd,Ctx.without,Ty.References,Pred.References,Pred.VarsIn,Term.VarsIn,
    Ctx.Readable,Ordinary,Ty.core]

theorem fwd_rejected : ¬ fwd.Ordered :=
  reject_forward_or_cyclic_context (.inl ⟨0,0,fwd_dep,Nat.le_refl _⟩)

theorem back_ordered : back.Ordered := by
  intro i a hi
  cases i with
  | zero =>
    cases hi
    simp [bwdRef,back,Ctx.outer,Ty.References,Pred.References,Pred.VarsIn,Term.VarsIn,
      Ctx.Readable,Ordinary,Ty.core,okTy]
  | succ i =>
    cases i with
    | zero => cases hi; simp [okTy,Ty.References]
    | succ i => simp [back] at hi

end ContextOrderExamples

end Benitoite.Release.Refinement
