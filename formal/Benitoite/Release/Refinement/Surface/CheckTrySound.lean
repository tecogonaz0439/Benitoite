import Benitoite.Release.Refinement.Surface.CheckSoundSupport

/-! 二つの腕の検査と、try の本体・表示・終了の検査を表層の規則へ接続する。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckCompare CheckFormation CheckTry

private abbrev RuleSound (source : Expr) (g : Guide) : Prop :=
  ∀ {q rows Δ C Γ Φ R p path a ε}, q.Sound → BuilderSupport q.formation.atoms Δ →
    CtxSupport q.formation.atoms Γ → ReturnSupport q.formation.atoms R →
    ExprSupport q source → a.Support (· ∈ q.formation.atoms) → ε.Support (· ∈ q.formation.atoms) →
    g.Support q.formation.atoms → checkExprAt q rows Δ C Γ Φ R p path source a ε g = true →
    HasTypeQ q.D q.B q.opPrim (CheckAdmissible.NoFailCtxOf rows) Δ C Γ Φ R p source a ε

private theorem result_rule {h ge u error ok err source} (ih : ExprSoundAt ge) :
    RuleSound (.tryResult [u, error] ok err source) (.node .E_TryResult h [ge]) := by
  intro q rows Δ C Γ Φ R p path a ε hq hΔ hΓ hR hsrc ha he hg hc
  have hc := (Bool.and_eq_true_iff.mp hc).2
  try dsimp only at hc
  split at hc
  · rename_i d t1 e1 cd ret hp hcd hr
    have hs := resultParts_sound hq hΓ ha hsrc.1.2.1 hp
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    obtain ⟨hn, hf, ho, heq, hrty, hk, hann, hbody⟩ := hc
    have hret : ret.Support (· ∈ q.formation.atoms) := hR
    have hre := (rawTyEq_spec hret (show (Ty.data d [u, error]).Support (· ∈ q.formation.atoms) from hsrc.1)).mp hrty
    have hd : cd.data = d := by
      obtain ⟨cd', hc', hd⟩ := hs.constructor
      have hh : cd' = cd := Option.some.inj (hc'.symm.trans hcd)
      exact hh ▸ hd
    have hb := ih (e := source) (a := .data d [a, error]) hq hΔ hΓ hR hsrc.2 ⟨ha, hsrc.1.2.1, trivial⟩ he hg.2.1 hbody
    exact .E_TryResult hcd (of_decide_eq_true hn)
      (CheckArguments.tysEq_sound (hq.formation.fields _ _ hcd) (by trivial) hf) hd
      (congrArg some hre) (CheckFormation.argsKinded_sound hq.formation.ctors hk)
      (annotation_sound hq hΓ hsrc.1 hann) hs.annotation hs.ordinarySuccess (of_decide_eq_true ho)
      hs.successPattern hs.sameSuccess hs.failurePattern
      ((normTyEq_spec hs.failureSupport hsrc.1.2.1).mp heq) hb hs.exhaustive
  · cases hc

private theorem option_rule {h ge u someCon noneCon source} (ih : ExprSoundAt ge) :
    RuleSound (.tryOption [u] someCon noneCon source) (.node .E_TryOption h [ge]) := by
  intro q rows Δ C Γ Φ R p path a ε hq hΔ hΓ hR hsrc ha he hg hc
  have hc := (Bool.and_eq_true_iff.mp hc).2
  try dsimp only at hc
  split at hc
  · rename_i d t1 cd ret hp hcd hr
    have hs := optionParts_sound hq hΓ ha hp
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    obtain ⟨hn, hf, hrty, hk, hann, hbody⟩ := hc
    have hret : ret.Support (· ∈ q.formation.atoms) := hR
    have hre := (rawTyEq_spec hret (show (Ty.data d [u]).Support (· ∈ q.formation.atoms) from hsrc.1)).mp hrty
    have hd : cd.data = d := by
      obtain ⟨cd', hc', hd⟩ := hs.constructor
      have hh : cd' = cd := Option.some.inj (hc'.symm.trans hcd)
      exact hh ▸ hd
    have hb := ih (e := source) (a := .data d [a]) hq hΔ hΓ hR hsrc.2 ⟨ha, trivial⟩ he hg.2.1 hbody
    exact .E_TryOption hcd (of_decide_eq_true hn) (List.isEmpty_iff.mp hf) hd
      (congrArg some hre) (CheckFormation.argsKinded_sound hq.formation.ctors hk)
      (annotation_sound hq hΓ hsrc.1 hann) hs.annotation hs.ordinarySuccess
      hs.successPattern hs.sameSuccess hs.failurePattern hb hs.exhaustive
  · cases hc

private theorem resultDie_rule {h ge t ok err dict showMethod exit source} (ih : ExprSoundAt ge) :
    RuleSound (.tryResultDie t ok err dict showMethod exit source none) (.node .E_TryResultDie h [ge]) := by
  intro q rows Δ C Γ Φ R p path a ε hq hΔ hΓ hR hsrc ha he hg hc
  have hc := (Bool.and_eq_true_iff.mp hc).2
  try dsimp only at hc
  split at hc
  · rename_i d t1 e1 hp
    have hs := resultParts_sound hq hΓ hsrc.1 (hg.1.ty 0) hp
    split at hc
    · rename_i ts ds tx dx hshow hexit
      simp only [allChecks, Bool.and_eq_true, and_true] at hc
      obtain ⟨hta, _, _, hbody, hvs, hls, hcs, hvx, hlx, hcx⟩ := hc
      have hta := (rawTyEq_spec hsrc.1 ha).mp hta
      subst a
      have ht := hsrc.1
      have hsource : (Ty.data d [t, h.ty 0]).Support (· ∈ q.formation.atoms) := ⟨ht, (hg.1.ty 0), trivial⟩
      have hb := ih hq hΔ hΓ hR hsrc.2.2.1 hsource he hg.2.1 hbody
      have hx := head_sound hq hΓ (CheckArguments.primitive_empty_support (b := exit) (ts := [t]) hq.tables ⟨ht, trivial⟩) hg.1 hexit
      have hsh := head_sound hq hΓ (show CheckArguments.HeadInputsSupport q.formation q.B
          (.methName dict showMethod [] [] [] [] []) from ⟨hsrc.2.1, trivial, by simp⟩) hg.1 hshow
      have hds : ds = [] := hsh.2.2
      have hdx : dx = [] := hx.2.2
      subst ds
      subst dx
      have hΓs := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [.data d [t, h.ty 0], e1] from ⟨hsource, hs.failureSupport, trivial⟩)
      have hshowArgs := valsTel_sound hq hΓ hΓs (by trivial)
        (tel_shift_support hsh.2.1 2 0) (hg.1.ty 1) (hg.1.eff 0) hg.1 hvs
      have hshowLe := subtype_sound (hg.1.ty 1) (by trivial) hg.1 hls
      have hshowEff := covers_sound (Γ := bindParams Γ [.data d [t, h.ty 0], e1]) (Φ := liftMany 2 Φ) (hg.1.eff 0) ((Eff.support_iff _).mp (effect_shift_support he 2 0)).2 hcs
      have hΓx := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [.data d [t, h.ty 0], e1, .base .string] from ⟨hsource, hs.failureSupport, trivial, trivial⟩)
      have hexitArgs := valsTel_sound hq hΓ hΓx (by trivial)
        (tel_shift_support hx.2.1 3 0) (hg.1.ty 2) (hg.1.eff 1) hg.1 hvx
      have hexitLe := subtype_sound (hg.1.ty 2) (type_shift_support ht 3 0) hg.1 hlx
      have hexitEff := covers_sound (Γ := bindParams Γ [.data d [t, h.ty 0], e1, .base .string]) (Φ := liftMany 3 Φ) (hg.1.eff 1) ((Eff.support_iff _).mp (effect_shift_support he 3 0)).2 hcx
      exact .E_TryResultDie hs.annotation hs.ordinarySuccess hs.successPattern hs.sameSuccess hs.failurePattern hb hs.exhaustive hsh.1 hshowArgs hshowLe hshowEff hx.1 hexitArgs hexitLe hexitEff
    · cases hc
  · cases hc

private theorem resultDieMessage_rule {h ge gm t ok err dict showMethod exit source message} (ih : ExprSoundAt ge) (im : ExprSoundAt gm) :
    RuleSound (.tryResultDie t ok err dict showMethod exit source (some message)) (.node .E_TryResultDieMessage h [ge, gm]) := by
  intro q rows Δ C Γ Φ R p path a ε hq hΔ hΓ hR hsrc ha he hg hc
  have hc := (Bool.and_eq_true_iff.mp hc).2
  try dsimp only at hc
  split at hc
  · rename_i d t1 e1 hp
    have hs := resultParts_sound hq hΓ hsrc.1 (hg.1.ty 0) hp
    split at hc
    · rename_i ts ds tx dx hshow hexit
      simp only [allChecks, Bool.and_eq_true, and_true] at hc
      obtain ⟨hta, _, _, hbody, hmessage, hvs, hls, hcs, hvx, hlx, hcx⟩ := hc
      have hta := (rawTyEq_spec hsrc.1 ha).mp hta
      subst a
      have ht := hsrc.1
      have hsource : (Ty.data d [t, h.ty 0]).Support (· ∈ q.formation.atoms) := ⟨ht, (hg.1.ty 0), trivial⟩
      have hb := ih hq hΔ hΓ hR hsrc.2.2.1 hsource he hg.2.1 hbody
      have hm := im hq hΔ (CtxSupport.hide hΓ) (show ReturnSupport q.formation.atoms none from True.intro)
        hsrc.2.2.2 (show (Ty.base .string).Support (· ∈ q.formation.atoms) from True.intro)
        (empty_effect_support _) hg.2.2.1 hmessage
      have hx := head_sound hq hΓ (CheckArguments.primitive_empty_support (b := exit) (ts := [t]) hq.tables ⟨ht, trivial⟩) hg.1 hexit
      have hsh := head_sound hq hΓ (show CheckArguments.HeadInputsSupport q.formation q.B
          (.methName dict showMethod [] [] [] [] []) from ⟨hsrc.2.1, trivial, by simp⟩) hg.1 hshow
      have hds : ds = [] := hsh.2.2
      have hdx : dx = [] := hx.2.2
      subst ds
      subst dx
      have hΓs := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [.data d [t, h.ty 0], e1, .base .string] from ⟨hsource, hs.failureSupport, trivial, trivial⟩)
      have hshowArgs := valsTel_sound hq hΓ hΓs (by trivial)
        (tel_shift_support hsh.2.1 3 0) (hg.1.ty 1) (hg.1.eff 0) hg.1 hvs
      have hshowLe := subtype_sound (hg.1.ty 1) (by trivial) hg.1 hls
      have hshowEff := covers_sound (Γ := bindParams Γ [.data d [t, h.ty 0], e1, .base .string]) (Φ := liftMany 3 Φ) (hg.1.eff 0) ((Eff.support_iff _).mp (effect_shift_support he 3 0)).2 hcs
      have hΓx := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [.data d [t, h.ty 0], e1, .base .string, .base .string] from ⟨hsource, hs.failureSupport, trivial, trivial, trivial⟩)
      have hexitArgs := valsTel_sound hq hΓ hΓx (by trivial)
        (tel_shift_support hx.2.1 4 0) (hg.1.ty 2) (hg.1.eff 1) hg.1 hvx
      have hexitLe := subtype_sound (hg.1.ty 2) (type_shift_support ht 4 0) hg.1 hlx
      have hexitEff := covers_sound (Γ := bindParams Γ [.data d [t, h.ty 0], e1, .base .string, .base .string]) (Φ := liftMany 4 Φ) (hg.1.eff 1) ((Eff.support_iff _).mp (effect_shift_support he 4 0)).2 hcx
      exact .E_TryResultDieMessage hs.annotation hs.ordinarySuccess hs.successPattern hs.sameSuccess hs.failurePattern hb hs.exhaustive hm hsh.1 hshowArgs hshowLe hshowEff hx.1 hexitArgs hexitLe hexitEff
    · cases hc
  · cases hc

private theorem optionDie_rule {h ge t someCon noneCon exit source} (ih : ExprSoundAt ge) :
    RuleSound (.tryOptionDie t someCon noneCon exit source none) (.node .E_TryOptionDie h [ge]) := by
  intro q rows Δ C Γ Φ R p path a ε hq hΔ hΓ hR hsrc ha he hg hc
  have hc := (Bool.and_eq_true_iff.mp hc).2
  try dsimp only at hc
  split at hc
  · rename_i d t1 tx ds hp hexit
    have hs := optionParts_sound hq hΓ hsrc.1 hp
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    obtain ⟨hta, _, hbody, hvx, hlx, hcx⟩ := hc
    have hta := (rawTyEq_spec hsrc.1 ha).mp hta
    subst a
    have ht := hsrc.1
    have hsource : (Ty.data d [t]).Support (· ∈ q.formation.atoms) := ⟨ht, trivial⟩
    have hb := ih hq hΔ hΓ hR hsrc.2.1 hsource he hg.2.1 hbody
    have hx := head_sound hq hΓ (CheckArguments.primitive_empty_support (b := exit) (ts := [t]) hq.tables ⟨ht, trivial⟩) hg.1 hexit
    have hds : ds = [] := hx.2.2
    subst ds
    have hΓx := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [.data d [t], .base .string] from ⟨hsource, trivial, trivial⟩)
    have hexitArgs := valsTel_sound hq hΓ hΓx (by trivial)
      (tel_shift_support hx.2.1 2 0) (hg.1.ty 1) (hg.1.eff 0) hg.1 hvx
    have hexitLe := subtype_sound (hg.1.ty 1) (type_shift_support ht 2 0) hg.1 hlx
    have hexitEff := covers_sound (Γ := bindParams Γ [.data d [t], .base .string]) (Φ := liftMany 2 Φ) (hg.1.eff 0) ((Eff.support_iff _).mp (effect_shift_support he 2 0)).2 hcx
    exact .E_TryOptionDie hs.annotation hs.ordinarySuccess hs.successPattern hs.sameSuccess hs.failurePattern hb hs.exhaustive hx.1 hexitArgs hexitLe hexitEff
  · cases hc

private theorem optionDieMessage_rule {h ge gm t someCon noneCon exit source message} (ih : ExprSoundAt ge) (im : ExprSoundAt gm) :
    RuleSound (.tryOptionDie t someCon noneCon exit source (some message)) (.node .E_TryOptionDieMessage h [ge, gm]) := by
  intro q rows Δ C Γ Φ R p path a ε hq hΔ hΓ hR hsrc ha he hg hc
  have hc := (Bool.and_eq_true_iff.mp hc).2
  try dsimp only at hc
  split at hc
  · rename_i d t1 tx ds hp hexit
    have hs := optionParts_sound hq hΓ hsrc.1 hp
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    obtain ⟨hta, _, hbody, hmessage, hvx, hlx, hcx⟩ := hc
    have hta := (rawTyEq_spec hsrc.1 ha).mp hta
    subst a
    have ht := hsrc.1
    have hsource : (Ty.data d [t]).Support (· ∈ q.formation.atoms) := ⟨ht, trivial⟩
    have hb := ih hq hΔ hΓ hR hsrc.2.1 hsource he hg.2.1 hbody
    have hm := im hq hΔ (CtxSupport.hide hΓ) (show ReturnSupport q.formation.atoms none from True.intro)
      hsrc.2.2 (show (Ty.base .string).Support (· ∈ q.formation.atoms) from True.intro)
      (empty_effect_support _) hg.2.2.1 hmessage
    have hx := head_sound hq hΓ (CheckArguments.primitive_empty_support (b := exit) (ts := [t]) hq.tables ⟨ht, trivial⟩) hg.1 hexit
    have hds : ds = [] := hx.2.2
    subst ds
    have hΓx := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [.data d [t], .base .string, .base .string] from ⟨hsource, trivial, trivial, trivial⟩)
    have hexitArgs := valsTel_sound hq hΓ hΓx (by trivial)
      (tel_shift_support hx.2.1 3 0) (hg.1.ty 1) (hg.1.eff 0) hg.1 hvx
    have hexitLe := subtype_sound (hg.1.ty 1) (type_shift_support ht 3 0) hg.1 hlx
    have hexitEff := covers_sound (Γ := bindParams Γ [.data d [t], .base .string, .base .string]) (Φ := liftMany 3 Φ) (hg.1.eff 0) ((Eff.support_iff _).mp (effect_shift_support he 3 0)).2 hcx
    exact .E_TryOptionDieMessage hs.annotation hs.ordinarySuccess hs.successPattern hs.sameSuccess hs.failurePattern hb hs.exhaustive hm hx.1 hexitArgs hexitLe hexitEff
  · cases hc


theorem tryResult_step {h children} (ih : SoundBelow (.node .E_TryResult h children)) :
    ExprSoundAt (.node .E_TryResult h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  cases children with
  | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
  | cons ge children =>
    cases children with
    | cons g children => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
    | nil =>
      cases e <;> try { have hf : false = true := (Bool.and_eq_true_iff.mp hc).2; cases hf }
      case tryResult ts ok err source =>
        cases ts with
        | nil => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
        | cons u ts =>
          cases ts with
          | nil => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
          | cons error ts =>
            cases ts with
            | nil => exact result_rule ((ih ge (by simp +arith)).expr) hq hΔ hΓ hR hsrc ha he hg hc
            | cons t ts => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc

theorem tryOption_step {h children} (ih : SoundBelow (.node .E_TryOption h children)) :
    ExprSoundAt (.node .E_TryOption h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  cases children with
  | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
  | cons ge children =>
    cases children with
    | cons g children => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
    | nil =>
      cases e <;> try { have hf : false = true := (Bool.and_eq_true_iff.mp hc).2; cases hf }
      case tryOption ts someCon noneCon source =>
        cases ts with
        | nil => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
        | cons u ts =>
          cases ts with
          | cons t ts => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
          | nil => exact option_rule ((ih ge (by simp +arith)).expr) hq hΔ hΓ hR hsrc ha he hg hc

theorem tryResultDie_step {h children} (ih : SoundBelow (.node .E_TryResultDie h children)) :
    ExprSoundAt (.node .E_TryResultDie h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  cases children with
  | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
  | cons ge children =>
    cases children with
    | cons g children => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
    | nil =>
      cases e <;> try { have hf : false = true := (Bool.and_eq_true_iff.mp hc).2; cases hf }
      case tryResultDie t ok err dict showMethod exit source message =>
        cases message with
        | some message => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
        | none => exact resultDie_rule ((ih ge (by simp +arith)).expr) hq hΔ hΓ hR hsrc ha he hg hc

theorem tryResultDieMessage_step {h children} (ih : SoundBelow (.node .E_TryResultDieMessage h children)) :
    ExprSoundAt (.node .E_TryResultDieMessage h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  cases children with
  | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
  | cons ge children =>
    cases children with
    | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
    | cons gm children =>
      cases children with
      | cons g children => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
      | nil =>
        cases e <;> try { have hf : false = true := (Bool.and_eq_true_iff.mp hc).2; cases hf }
        case tryResultDie t ok err dict showMethod exit source message =>
          cases message with
          | none => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
          | some message => exact resultDieMessage_rule ((ih ge (by simp +arith)).expr) ((ih gm (by simp +arith)).expr) hq hΔ hΓ hR hsrc ha he hg hc

theorem tryOptionDie_step {h children} (ih : SoundBelow (.node .E_TryOptionDie h children)) :
    ExprSoundAt (.node .E_TryOptionDie h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  cases children with
  | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
  | cons ge children =>
    cases children with
    | cons g children => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
    | nil =>
      cases e <;> try { have hf : false = true := (Bool.and_eq_true_iff.mp hc).2; cases hf }
      case tryOptionDie t someCon noneCon exit source message =>
        cases message with
        | some message => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
        | none => exact optionDie_rule ((ih ge (by simp +arith)).expr) hq hΔ hΓ hR hsrc ha he hg hc

theorem tryOptionDieMessage_step {h children} (ih : SoundBelow (.node .E_TryOptionDieMessage h children)) :
    ExprSoundAt (.node .E_TryOptionDieMessage h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  cases children with
  | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
  | cons ge children =>
    cases children with
    | nil => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
    | cons gm children =>
      cases children with
      | cons g children => cases e <;> simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
      | nil =>
        cases e <;> try { have hf : false = true := (Bool.and_eq_true_iff.mp hc).2; cases hf }
        case tryOptionDie t someCon noneCon exit source message =>
          cases message with
          | none => simp only [checkExprAt, Bool.and_false, Bool.false_eq_true] at hc
          | some message => exact optionDieMessage_rule ((ih ge (by simp +arith)).expr) ((ih gm (by simp +arith)).expr) hq hΔ hΓ hR hsrc ha he hg hc

end Benitoite.Release.Refinement.Surface.Check
