import Benitoite.Surface.CheckSoundControl

/-! 厳密な検査から宣言的な型付けを導く契約。探索の収束は前提にしない。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

/-- 出力の原子集合の保存は、型比較を相互帰納法で接続するためにも使う。 -/
theorem checkExpr_sound {q C Γ R p path e a ε}
    (hq : q.Sound) (he : e.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkExpr q .strict C Γ R p path e = .ok (a, ε)) :
    HasType q.D q.B q.opPrim C Γ R p e a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  exact checkExpr_of_mutual (mutualSoundness q) hq he hΓ hR h

theorem checkBlock_sound {q C Γ R p path body a ε}
    (hq : q.Sound) (hb : body.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R)
    (h : checkBlock q .strict C Γ R p path body = .ok (a, ε)) :
    HasBlock q.D q.B q.opPrim C Γ R p body a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  exact checkBlock_of_mutual (mutualSoundness q) hq hb hΓ hR h

theorem checkArms_sound {q C Γ R p path arms a b ε}
    (hq : q.Sound) (ha : arms.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (hin : a.AtomsIn q.atoms) (hout : b.AtomsIn q.atoms)
    (h : checkArms q .strict C Γ R p path arms a b = .ok ε) :
    HasArms q.D q.B q.opPrim C Γ R p arms a b ε ∧ ε.AtomsIn q.atoms := by
  exact checkArms_of_mutual (mutualSoundness q) hq ha hΓ hR hin hout h

/-- 節の判断は許容 ε を使う。返した実際の和はその部分集合である。 -/
theorem checkClauses_sound {q C Γ R path cs t ε actual}
    (hq : q.Sound) (hc : cs.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : t.AtomsIn q.atoms) (hε : ε.AtomsIn q.atoms)
    (h : checkClauses q .strict C Γ R path cs t ε = .ok actual) :
    HasClauses q.D q.B q.opPrim C Γ R cs t ε ∧
      Eff.Sub actual ε ∧ actual.AtomsIn q.atoms := by
  exact checkClauses_of_mutual (mutualSoundness q) hq hc hΓ hR ht hε h

theorem checkTypes_sound {q C Γ R path es ts ε}
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkTypes q .strict C Γ R path es ts = .ok ε) :
    HasTypes q.D q.B q.opPrim C Γ R es ts ε ∧ ε.AtomsIn q.atoms := by
  exact checkTypes_of_mutual (mutualSoundness q) hq he hΓ hR ht h

theorem checkEach_sound {q C Γ R path es a ε}
    (hq : q.Sound) (he : es.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ha : a.AtomsIn q.atoms)
    (h : checkEach q .strict C Γ R path es a = .ok ε) :
    HasEach q.D q.B q.opPrim C Γ R es a ε ∧ ε.AtomsIn q.atoms := by
  exact checkEach_of_mutual (mutualSoundness q) hq he hΓ hR ha h

theorem checkHoleArgs_sound {q C Γ R path args ts ε}
    (hq : q.Sound) (ha : args.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (hR : ReturnAtoms q.atoms R) (ht : Tys.AtomsIn q.atoms ts)
    (h : checkHoleArgs q .strict C Γ R path args ts = .ok ε) :
    HasHoleArgs q.D q.B q.opPrim C Γ R args ts ε ∧ ε.AtomsIn q.atoms := by
  exact checkHoleArgs_of_mutual (mutualSoundness q) hq ha hΓ hR ht h

theorem checkDict_sound {q C Γ path d a}
    (hq : q.Sound) (hd : d.AtomsIn q.atoms) (hΓ : Env.AtomsIn q.atoms Γ)
    (h : checkDict q C Γ path d = .ok a) :
    DictEv.HasType q.D q.B C Γ d a ∧ a.AtomsIn q.atoms := by
  exact checkDict_of_dictionary (dictionarySoundness q) hq hd hΓ h

theorem checkDicts_sound {q C Γ path ds ts}
    (hq : q.Sound) (hd : DictEvs.AtomsIn q.atoms ds) (hΓ : Env.AtomsIn q.atoms Γ)
    (ht : Tys.AtomsIn q.atoms ts)
    (h : checkDicts q C Γ path ds ts = .ok ()) :
    DictEv.HasTypes q.D q.B C Γ ds ts := by
  exact checkDicts_of_dictionary (dictionarySoundness q) hq hd hΓ ht h

theorem checkDef_sound {q path d} (hq : q.Sound) (hd : d.AtomsIn q.atoms)
    (h : checkDef q path d = .ok ()) : Def.WellTyped q.D q.B q.opPrim d := by
  exact checkDef_of_mutual (mutualSoundness q) hq hd h

theorem checkImpl_sound {q methods supers path id}
    (hq : q.Sound) (hi : id.AtomsIn q.atoms)
    (hn : ImplNamesComplete q id methods supers)
    (h : checkImpl q methods supers path id = .ok ()) :
    ImplDecl.WellTyped q.D q.B q.opPrim id := by
  exact checkImpl_of_checker (checkerSoundness q) hq hi hn h

end Benitoite.Surface.Check
