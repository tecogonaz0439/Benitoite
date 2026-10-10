import Benitoite.Surface.Lemmas.Typing
import Benitoite.Surface.Lemmas.Scoped
import Benitoite.Surface.Lemmas.SubstClean

/-! 定義の導出から、脱糖したプログラムと入口の型付けを得る。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {B : Builtins} {op : OpPrim}

theorem desugar_wellFormed (hwf : p.WellFormed) (hwt : p.WellTyped B op) :
    (desugarProgram op p).WellFormed := by
  refine ⟨?_, hwf.2.1, hwf.2.2.1, ?_, ?_⟩
  · intro f dd hd
    cases hs : p.defs f with
    | none =>
        cases ha : p.accessors f with
        | none => simp [desugarProgram, Program.lookupFun, hs, ha] at hd
        | some ck =>
            obtain ⟨c, k⟩ := ck
            obtain ⟨_, cd, hc, hk, _⟩ := hwf.2.2.2.2.2.2.2 f c k ha
            simp only [desugarProgram, Program.lookupFun, hs, ha, hc,
              Option.map_some, Option.some.injEq] at hd
            subst dd
            exact accessorDef_scoped (hwf.2.1 _ _ hc) hk
    | some d =>
      simp only [desugarProgram, Program.lookupFun, hs, Option.some.injEq] at hd
      subst dd
      have hds := hs
      have sc := hwf.1 f d hds
      exact ⟨Ty.varsInList_of_forall (by
          intro t ht
          rcases List.mem_append.mp ht with ht | ht
          · exact varsInList_mem (d.toFunDecl.dictTys_scoped sc.2.2.2.1) ht
          · exact varsInList_mem sc.1 ht),
        sc.2.1, sc.2.2.1, HasBlock.desugar_scoped (hwt.1 f d hds).2 sc.2.2.2.2⟩
  · exact hwf.2.2.2.2.2.1
  · intro i dd hd
    obtain ⟨id, hs, heq⟩ := Option.map_eq_some_iff.mp hd
    cases heq
    have sc := hwf.2.2.2.2.2.2.1 i id hs
    refine ⟨sc.1, sc.2.1, ?_, ?_⟩
    · intro s u hu
      obtain ⟨d, hd, heq⟩ := Option.map_eq_some_iff.mp hu
      cases heq
      exact DictEv.toVal_scoped d (sc.2.2.1 s d hd)
    · intro cd m ms body hc hm hb
      obtain ⟨b, hbody, heq⟩ := Option.map_eq_some_iff.mp hb
      cases heq
      obtain ⟨cd', hc', _, _, hmethods, _⟩ := hwt.2.2 i id hs
      have he : cd' = cd := Option.some.inj (hc'.symm.trans hc)
      subst cd'
      obtain ⟨b', hb', _, htyped⟩ := hmethods m ms hm
      have he : b' = b := Option.some.inj (hb'.symm.trans hbody)
      subst b'
      exact HasBlock.desugar_scoped htyped (sc.2.2.2 cd m ms b hc hm hbody)

theorem desugar_wellTyped (hwf : p.WellFormed) (hwt : p.WellTyped B op)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) : (desugarProgram op p).WellTyped B := by
  refine ⟨?_, ?_⟩
  · intro f dd hd
    cases hs : p.defs f with
    | none =>
        cases ha : p.accessors f with
        | none => simp [desugarProgram, Program.lookupFun, hs, ha] at hd
        | some ck =>
            obtain ⟨c, k⟩ := ck
            obtain ⟨_, cd, hc, hk, hu⟩ := hwf.2.2.2.2.2.2.2 f c k ha
            simp only [desugarProgram, Program.lookupFun, hs, ha, hc,
              Option.map_some, Option.some.injEq] at hd
            subst dd
            exact accessorDef_typed hc (hwf.2.1 _ _ hc) hk hu
    | some d =>
      simp only [desugarProgram, Program.lookupFun, hs, Option.some.injEq] at hd
      subst dd
      have hds := hs
      have sc := hwf.1 f d hds
      apply HasBlock.desugar hwf hsig (hwt.1 f d hds).2
      · simpa [binds_length, FunDecl.dictTys_length] using sc.2.2.2.2
      · have hh := EnvClean.binds (Γ := []) (cleanList_append
          (d.toFunDecl.dictTys_scoped (pe := fun _ => True) sc.2.2.2.1) (scopedList_clean sc.1))
          (by intro i t hi; simp at hi)
        simpa using hh
      · intro r he; cases he; exact scoped_clean sc.2.1
  · intro i dd hd
    obtain ⟨id, hid, heq⟩ := Option.map_eq_some_iff.mp hd
    cases heq
    have sc := hwf.2.2.2.2.2.2.1 i id hid
    obtain ⟨cd, hc, hm, hs, hmethods, hsupers⟩ := hwt.2.2 i id hid
    refine ⟨cd, hc, ?_, ?_, ?_, ?_⟩
    · intro m; simpa only [desugarImpl, Option.isSome_map] using hm m
    · intro s; simpa only [desugarImpl, Option.isSome_map] using hs s
    · intro m ms hms
      obtain ⟨body, hb, _, hbody⟩ := hmethods m ms hms
      have hsc := hwf.2.2.2.2.2.1 _ _ hc _ _ hms
      have htarget : Ty.VarsInList id.tparams.length (fun _ => True) [id.target] :=
        ⟨scoped_clean sc.2.1, trivial⟩
      have hret : TyOK (ms.tparams ++ id.tparams).length (id.methTy ms ms.ret) := by
        simpa only [Surface.ImplDecl.methTy, List.length_append, List.length_singleton] using
          substAt_clean ms.tparams.length [] htarget ms.ret (scoped_clean hsc.2.1)
      have hparams : Ty.VarsInList (ms.tparams.length + id.tparams.length) (fun _ => True)
          (ms.params.map (id.methTy ms)) :=
        substAtList_clean ms.tparams.length [] htarget ms.params (scopedList_clean hsc.1)
      have hdicts : Ty.VarsInList id.tparams.length (fun _ => True) id.dictTys := by
        unfold ImplSig.dictTys
        exact Ty.varsInList_of_forall (by
          intro t ht
          obtain ⟨q, hq, rfl⟩ := List.mem_map.mp ht
          exact sc.1 q hq)
      have hΓ : EnvClean (ms.tparams ++ id.tparams).length
          (binds (id.dictTys.map (Ty.shift ms.tparams.length 0) ++ ms.params.map (id.methTy ms))) := by
        have hclean := cleanList_append
          (by simpa only [Nat.add_comm] using shiftList_clean ms.tparams.length id.dictTys hdicts)
          hparams
        simpa only [List.length_append, List.length_singleton, List.append_nil] using
          EnvClean.binds (Γ := []) hclean (by intro j t hj; simp at hj)
      refine ⟨desugarBlock op .tail body, by simp only [desugarImpl, hb, Option.map_some], ?_⟩
      apply HasBlock.desugar (pe := (· < ms.neffs)) hwf hsig hbody
      · simpa only [List.length_append, binds_length, ImplSig.dictTys, List.length_map] using
          sc.2.2.2 cd m ms body hc hms hb
      · exact hΓ
      · intro r hr; cases hr; exact hret
    · intro s hmem
      obtain ⟨u, hu, hut⟩ := hsupers s hmem
      exact ⟨u.toVal, by simp only [desugarImpl, hu, Option.map_some], DictEv.HasType.toVal op hut⟩

theorem desugar_effectsOk (hwf : p.WellFormed) (hwt : p.WellTyped B op) :
    (desugarProgram op p).EffectsOk B := by
  exact ⟨hwf.2.2.2.1, hwf.2.2.2.2.1, hwt.2.1⟩

/-- HasMain の戻り値型の制限は、この入口の型付けには使わない。 -/
theorem main_typed (hwf : p.WellFormed) (hmain : p.HasMain Eff.empty) :
    ∃ a, HasTypeC (desugarProgram op p) B StoreTy.empty [] [] none
      (.app (.fnRef "main" [] []) []) a Eff.empty := by
  obtain ⟨d, hd, ht, he, hp, _, hε⟩ := hmain
  have hdict := d.dictParams_nil_of_tparams_nil (hwf.1 _ _ hd) ht
  have hd' : (desugarProgram op p).defs "main" = some (desugarDef op d) := by
    simp [desugarProgram, Program.lookupFun, hd]
  have hsat : SatAll B [] [] d.tparams := by
    rw [ht]; exact ⟨rfl, by intro i τ c hi; cases hi⟩
  have hf := HasTypeV.V_Fun (ts := []) (es := []) (Ψ := StoreTy.empty) (Γ := []) hd' hsat (by simpa [desugarDef] using he.symm)
  have hε' := Eff.sub_empty hε
  simp only [desugarDef, fnTy_eq, FunDecl.dictTys, hdict, hp, List.nil_append,
    hε', List.map_nil, Eff.substRho_empty] at hf
  exact ⟨_, .C_App hf .nil⟩

end Benitoite.Surface
