import Benitoite.Surface.CheckSoundControl

/-! 実装の実名を検査成功から宣言名へ接続し、本体と上位辞書の型付けを導く。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

/-- 有限の一覧にないメソッドと上位辞書が空欄であるという、従来の完全性の条件。 -/
def ImplNamesComplete (q : Input) (id : ImplInput)
    (methods : List MethName) (supers : List ClassName) : Prop :=
  (∀ cd, q.D.classes id.cls = some cd → ∀ m, m ∉ methods → cd.methods m = none) ∧
  (∀ m, m ∉ methods → id.methods m = none) ∧
  (∀ s, s ∉ supers → id.supers s = none)

/-- 一つのメソッドの成功経路。型付けの証明はブロックの契約に任せる。 -/
def MethodChecked (q : Input) (id : ImplInput) (ms : MethSig) (method : MethodInput) : Prop :=
  method.names = ms.names ∧ NamesWF ms.names ms.params ∧
  (rowsTysCheck q.atoms ms.neffs ms.params && rowsTyCheck q.atoms ms.neffs ms.ret && rowsEffCheck q.atoms ms.neffs ms.eff) = true ∧
  ∃ path a ε out,
    lamBodyOk method.body (substTyAt q.atoms ms.tparams.length [id.target] [] ms.ret) = true ∧
    checkBlockQ { q with noFailRows := signatureQ ms.neffs ms.params ms.ret ms.eff } .strict (ms.tparams ++ id.tparams)
      (binds (id.dictTys.map (shiftTy q.atoms ms.tparams.length 0) ++
        ms.params.map (substTyAt q.atoms ms.tparams.length [id.target] [])))
      (some (substTyAt q.atoms ms.tparams.length [id.target] [] ms.ret)) .tail path method.body = .ok (a, ε) ∧
    accept { q with noFailRows := signatureQ ms.neffs ms.params ms.ret ms.eff } (ms.tparams ++ id.tparams).length path (substTyAt q.atoms ms.tparams.length [id.target] [] ms.ret) (a, ε) = .ok out ∧
    acceptEff { q with noFailRows := signatureQ ms.neffs ms.params ms.ret ms.eff } path (substEffAt q.atoms ms.tparams.length [id.target] [] ms.eff) out = .ok ()

theorem checkMethods_entry {q path id cd names index views}
    (h : checkMethods q path id cd views names index = .ok ()) :
    ∀ m ∈ names, (id.methods m).isSome = (cd.methods m).isSome ∧
      ∀ ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
        MethodChecked ({ q with D := q.D.withView (views m) } : Input) id ms body := by
  induction names generalizing index with
  | nil => intro m hm; cases hm
  | cons m names ih =>
      simp only [checkMethods] at h
      have hh : checkMethods q path id cd views names (index + 1) = .ok () ∧
          (id.methods m).isSome = (cd.methods m).isSome ∧
          (∀ ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
            MethodChecked ({ q with D := q.D.withView (views m) } : Input) id ms body) := by
        cases hms : cd.methods m with
        | none =>
            cases hbody : id.methods m with
            | none => exact ⟨by simpa [hms, hbody] using h, by simp⟩
            | some body => simp [hms, hbody, Bind.bind, Except.bind] at h
        | some ms =>
            cases hbody : id.methods m with
            | none => simp [hms, hbody, Bind.bind, Except.bind] at h
            | some body =>
                simp only [hms, hbody] at h
                obtain ⟨uNames, hNames, h⟩ := bind_ok h
                obtain ⟨uWF, hWF, h⟩ := bind_ok h
                obtain ⟨uRows, hRows, h⟩ := bind_ok h
                obtain ⟨v, hv, h⟩ := bind_ok h
                obtain ⟨⟨a, ε⟩, hb, h⟩ := bind_ok h
                obtain ⟨out, ha, h⟩ := bind_ok h
                obtain ⟨u, hf, hrest⟩ := bind_ok h
                refine ⟨hrest, rfl, ?_⟩
                intro ms' he
                have eqms : ms = ms' := by simpa [hms] using he
                subst ms'
                refine ⟨body, rfl, eq_of_beq (require_ok hNames).1,
                  (namesWF_spec _ _).mp (require_ok hWF).1, (require_ok hRows).1, child path index, a, ε, out, (require_ok hv).1, hb, ha, ?_⟩
                cases u; exact hf
      intro k hk
      rcases List.mem_cons.mp hk with rfl | hk
      · exact hh.2
      · exact ih hh.1 k hk

theorem checkSuperFlags_entry {path id cd names index}
    (h : checkSuperFlags path id cd names index = .ok ()) :
    ∀ s ∈ names, (id.supers s).isSome = decide (s ∈ cd.supers) := by
  induction names generalizing index with
  | nil => intro s hs; cases hs
  | cons s names ih =>
      obtain ⟨u, hu, hrest⟩ := bind_ok h
      intro k hk
      rcases List.mem_cons.mp hk with rfl | hk
      · have he := eq_of_beq (require_ok hu).1
        simpa using he
      · exact ih hrest k hk

theorem checkSuperDicts_entry {q path id names index}
    (h : checkSuperDicts q path id names index = .ok ()) :
    ∀ s ∈ names, ∃ d dictPath a, id.supers s = some d ∧
      checkDict q id.tparams (binds id.dictTys) dictPath d = .ok a ∧
      tyEq q.atoms a (.dict s id.target) = true := by
  induction names generalizing index with
  | nil => intro s hs; cases hs
  | cons s names ih =>
      obtain ⟨d, hd, h⟩ := bind_ok h
      obtain ⟨a, ha, h⟩ := bind_ok h
      obtain ⟨u, hu, hrest⟩ := bind_ok h
      intro k hk
      rcases List.mem_cons.mp hk with rfl | hk
      · exact ⟨d, child path index, a, lookup_ok hd, ha, (require_ok hu).1⟩
      · exact ih hrest k hk

/-- 実名の一致と宣言名の整形式は、検査成功から得る。外部の仮定ではない。 -/
def ImplInput.ContractsMatch (D : Declarations) (id : ImplInput) : Prop :=
  ∀ cd, D.classes id.cls = some cd → ∀ m ms, cd.methods m = some ms →
    ∃ method, id.methods m = some method ∧ method.names = ms.names ∧ NamesWF ms.names ms.params

theorem checkImpl_contracts {q methods supers path id views}
    (hn : ImplNamesComplete q id methods supers)
    (h : checkImpl q methods supers path id views = .ok ()) : id.ContractsMatch q.D := by
  obtain ⟨cd, hc, h⟩ := bind_ok h
  obtain ⟨u, hm, _⟩ := bind_ok h
  have hcd := lookup_ok hc
  intro cd' hc' m ms hms
  have eqcd : cd = cd' := Option.some.inj (hcd.symm.trans hc')
  subst cd'
  have hmem : m ∈ methods := by
    by_cases hmem : m ∈ methods
    · exact hmem
    · have he := hn.1 cd hcd m hmem
      rw [hms] at he
      contradiction
  obtain ⟨method, hm, hnames, hwf, _⟩ := (checkMethods_entry (by cases u; exact hm) m hmem).2 ms hms
  exact ⟨method, hm, hnames, hwf⟩

/-- 有限の名前一覧の成功を、一覧外の空欄の契約と合わせて全称判断へ戻す。 -/
theorem checkImpl_of_checker {q methods supers path id views}
    (hs : ∀ view rows, CheckerSoundness ({ q with D := q.D.withView view, noFailRows := rows } : Input))
    (hq : q.Sound) (hi : id.decl.AtomsIn q.atoms) (hn : ImplNamesComplete q id methods supers)
    (h : checkImpl q methods supers path id views = .ok ()) :
    ImplDecl.WellTyped q.D q.B q.opPrim id.decl views := by
  obtain ⟨cd, hc, h⟩ := bind_ok h
  obtain ⟨u1, hm, h⟩ := bind_ok h
  obtain ⟨u2, hf, h⟩ := bind_ok h
  obtain ⟨u3, hall, hd⟩ := bind_ok h
  have hcd := lookup_ok hc
  have complete : ∀ s ∈ cd.supers, s ∈ supers := by
    intro s hmem
    exact List.mem_of_elem_eq_true (List.all_eq_true.mp (require_ok hall).1 s hmem)
  have methodEntry := checkMethods_entry (by cases u1; exact hm)
  have flags := checkSuperFlags_entry (by cases u2; exact hf)
  refine ⟨cd, hcd, ?_, ?_, ?_, ?_⟩
  · intro m
    by_cases hmem : m ∈ methods
    · exact by simpa [ImplInput.decl] using (methodEntry m hmem).1
    · simp [ImplInput.decl, hn.1 cd hcd m hmem, hn.2.1 m hmem]
  · intro s
    by_cases hmem : s ∈ supers
    · exact flags s hmem
    · have hnot : s ∉ cd.supers := fun h => hmem (complete s h)
      simp [ImplInput.decl, hn.2.2 s hmem, hnot]
  · intro m ms hms
    have hmem : m ∈ methods := by
      by_cases hmem : m ∈ methods
      · exact hmem
      · have he := hn.1 cd hcd m hmem
        rw [hms] at he; contradiction
    obtain ⟨method, hm, hNames, hWF, hRows, path', a, ε, out, hExit, hBlock, hAccept, hEff⟩ :=
      (methodEntry m hmem).2 ms hms
    have hb : id.decl.methods m = some method.body := by simp [ImplInput.decl, hm]
    have msAtoms := hq.declarations.2.2.2.1 id.cls cd m ms hcd hms
    have resultAtoms := substTyAt_atoms msAtoms.2.1 (atoms := q.atoms)
      (ts := [id.target]) (es := []) ⟨hi.1, trivial⟩ (by simp) ms.tparams.length
    have paramsAtoms := tysAtoms_map msAtoms.1
      (fun _ h => substTyAt_atoms h (ts := [id.target]) (es := [])
        ⟨hi.1, trivial⟩ (by simp) ms.tparams.length)
    have dictAtoms := tysAtoms_map hi.2.1
      (fun _ h => shiftTy_atoms h ms.tparams.length 0)
    have hb' := checkBlock_of_mutual (hs (views m) (signatureQ ms.neffs ms.params ms.ret ms.eff)).surface
      ((hq.withView (views m)).withNoFailRows (signatureQ ms.neffs ms.params ms.ret ms.eff))
      (hi.2.2.2 m method.body hb)
      (Env.atoms_binds (tysAtoms_append dictAtoms paramsAtoms))
      (fun t ht => by cases ht; exact resultAtoms) hBlock
    have hts : ∀ t ∈ [id.target], t.AtomsIn q.atoms := by
      intro t ht; simp only [List.mem_singleton] at ht; subst t; exact hi.1
    have hretEq := substTyAt_eq ms.tparams.length [id.target] [] ms.ret hts (by simp) msAtoms.2.1
    have hparamsEq := substTysAt_eq ms.tparams.length [id.target] [] ms.params hts (by simp)
      (tysAtoms_iff.mp msAtoms.1)
    simp only [substTysAt] at hparamsEq
    have heffEq := substEffAt_eq ms.tparams.length [id.target] [] ms.eff hts (by simp) msAtoms.2.2
    have hdictsEq : id.dictTys.map (shiftTy q.atoms ms.tparams.length 0) =
        id.dictTys.map (Ty.shift ms.tparams.length 0) :=
      List.map_congr_left (fun t ht => shiftTy_eq ms.tparams.length 0 t (tysAtoms_iff.mp hi.2.1 t ht))
    have effectAtoms := substEffAt_atoms msAtoms.2.2 (atoms := q.atoms)
      (ts := [id.target]) (es := []) ⟨hi.1, trivial⟩ (by simp) ms.tparams.length
    have hqs : NoFailCtxOf (signatureQ ms.neffs ms.params ms.ret ms.eff) = Qsig ms.params ms.ret ms.eff := by
      simp only [Bool.and_eq_true] at hRows
      funext i
      exact propext (signatureQ_scoped
        ((rowsTysCheck_spec ms.neffs ms.params msAtoms.1).mp hRows.1.1)
        ((rowsTyCheck_spec ms.neffs ms.ret msAtoms.2.1).mp hRows.1.2)
        ((rowsEffCheck_spec ms.neffs ms.eff msAtoms.2.2).mp hRows.2) i)
    have typed := accept_block_eff hb'.1 hb'.2.1 resultAtoms hb'.2.2 effectAtoms hAccept hEff
    refine ⟨method.body, hb, ?_, ?_⟩
    · simpa only [hretEq, ImplDecl.methTy, ImplInput.decl] using (lamBodyOk_spec _ _).mp hExit
    · simpa only [hqs, hretEq, hparamsEq, hdictsEq, heffEq, methTy_fun_eq, ImplDecl.methTy, ImplInput.decl] using typed
  · intro s hmem
    obtain ⟨d, dictPath, a, hds, ha, he⟩ := checkSuperDicts_entry hd s hmem
    have ht := checkDict_of_dictionary (hs q.D.view q.noFailRows).dictionaries ((hq.withView q.D.view).withNoFailRows q.noFailRows)
      (hi.2.2.1 s d hds)
      (Env.atoms_binds hi.2.1) ha
    have eqTy := tyEq_sound ht.2 (b := .dict s id.target) hi.1 he
    refine ⟨d, hds, ?_⟩
    change DictEv.HasType q.D q.B id.tparams (binds id.dictTys) d (.dict s id.target)
    rw [← eqTy]
    exact ht.1

end Benitoite.Surface.Check
