import Benitoite.Release.Lemmas.TargetPropagation

/-!
# 一段の対象健全性（L30.4）

継続の末尾の効果 Eb を固定した状態の型付け `StateTyE P B Eb s` のもとで、一段の遷移 `Step P B s (some ev) s'` の事象の
観測が Eb に許されることを示す（`step_target_sound`）。言明の構成要素は次のとおり固定し、言明の引数にしない
（RV-PL10 中6、RV-L00 中1・中2）。

- 観測: L20.6 で `Event.io` に足した観測の欄の射影 `Event.obs`。解放の事象は観測を持たない。
- 許可: L10.5 の許可の関係の κ を表の `effKind` にした `Builtins.Allows`（Top の被覆は名前の種類に相対的）。
- 信頼条件: 旧の条件 `CoreAssumptions` と対象一致の条件 `TargetAgreement`。対象健全性そのものは仮定しない。
- 結論: 事象の操作 b の署名 e と、その操作の名前 l（`e.opEff = some l`）を通し、観測の対象はどれも Eb の名前 l の
  原子が許す。別の名前の原子では許さない（`Eff.allows_union_other_name`）。

公開の `StateTy` は末尾の効果を存在量化するので、末尾の範囲について何も言わない（BA。RV-L10「BA のもとで残る危険」
(a)）。そのため言明は初期の ε を末尾に固定できる `StateTyE` で述べる。到達先の言明は L30.5 が置く。

場合ごとの閉じ方は次のとおりである。

- E-IO・E-IOErr・E-Exit: 観測を持つ事象の遷移はこの三つだけである（`Step.io_inv`）。呼び出しの型付けの反転
  （`inv_prim_app`）で、引数は具体化した署名の引数の型を持つ。対象一致の条件から、観測は具体化した署名の効果の
  名前 l の原子に許され（`TargetAgreement.obs_allowed`）、処理する枠がないので継続の末尾の効果 Eb に届く
  （`ContTy.allows_end_of_prim_call`）。
- 解放の事象（E-Release ほか）: 観測を持たない（`Event.obs_release`）。
- E-OpPrim・E-Op: 事象を伴わない。節の本体は、枠の下の継続の先頭の効果に含まれる効果で型付き（節の型付けの反転
  `HasTypeClausesQ.find`）、その効果が許す対象は、処理する枠が枠の下の継続になければ Eb が許す
  （`StateTyE.clause_allows`。SK §4）。捕捉された組み込みの呼び出しの対象は、節の添字を選ぶ枠の穴の効果に許される
  （`StateTyE.opPrim_clause_allows`）。節が実行する IO は、保存の定理で同じ Eb の状態から出る E-IO の事象であり、
  上の場合で扱う。
-/

namespace Benitoite.Release

open Scope.Domain (Target)

variable {P : Program} {B : Builtins}

/-! ## 事象の観測 -/

/-- 事象の観測（L20.6 で `Event.io` に足した観測の欄の射影）。解放の事象は観測を持たない。 -/
def Event.obs : Event → List Target
  | .io _ _ _ obs => obs
  | .release _ _ => []

@[simp] theorem Event.obs_io (b : PrimName) (ws : List Val) (o : Outcome) (obs : List Target) :
    (Event.io b ws o obs).obs = obs := rfl

/-- 解放の事象は観測を持たない。 -/
@[simp] theorem Event.obs_release (v : Val) (r : Option ErrKind) : (Event.release v r).obs = [] := rfl

/-! ## 別の名前の原子は許可を足さない -/

/-- 上限に別の名前の原子を足しても、名前 l の対象の許可は変わらない（RV-L00 中1 の反例を閉じる形）。許可の関係は
名前を通すので、たとえば `File.Read` の原子を上限に足しても、`File.Write` の操作の対象は許されない。 -/
theorem Eff.allows_union_other_name {κ : EffName → Option Scope.Domain.Kind} {ε : Eff} {l m : EffName}
    {ix : Scope.Signature.Ix} {t : Target} (hne : m ≠ l) :
    Eff.Allows κ (Eff.union ε (Eff.singleAt m ix)) l t ↔ Eff.Allows κ ε l t := by
  rw [Eff.allows_union]
  constructor
  · rintro (h | ⟨k, r, -, hm, -⟩)
    · exact h
    · rw [Eff.mem_singleAt] at hm
      simp only [Atom.name.injEq] at hm
      exact absurd hm.1.symm hne
  · exact Or.inl

/-! ## 一段の対象健全性 -/

/-- 一段の対象健全性。継続の末尾の効果 Eb を固定した型の付いた状態が IO の事象を伴って遷移するとき、事象の操作 b は
署名 e と操作の名前 l を持ち、事象の観測の対象はどれも Eb の名前 l の原子が許す。信頼条件は `CoreAssumptions` と
`TargetAgreement` だけである（`P.EffectsOk B` はプログラムの宣言の条件で、主定理と同じ）。 -/
theorem step_target_sound (hdecl : P.EffectsOk B) (hc : B.CoreAssumptions P) (ht : B.TargetAgreement P)
    {Eb : Eff} {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hs : StateTyE P B Eb s) (hst : Step P B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows Eb l t := by
  -- 観測を持つ事象の遷移は、処理する枠のない組み込みの IO・終了の関数の呼び出しである。
  have hcall : ∃ ts es rs k σ e, s = .run (.app (.prim b ts es rs) ws) k σ ∧ B.sig b = some e ∧
      (e.kind = .io ∨ e.kind = .exit) ∧ NoHandler k (.prim b) ∧ B.ioResponse b ts es ws o obs := by
    cases hst with
    | E_IO hsig hkd hno hr => exact ⟨_, _, _, _, _, _, rfl, hsig, .inl hkd, hno, hr⟩
    | E_IOErr hsig hkd hno hr => exact ⟨_, _, _, _, _, _, rfl, hsig, hkd, hno, hr⟩
    | E_Exit hsig hkd hno hr => exact ⟨_, _, _, _, _, _, rfl, hsig, .inr hkd, hno, hr⟩
  obtain ⟨ts, es, rs, k, σ, e, rfl, hsig, hkd, hno, hr⟩ := hcall
  obtain ⟨Ψ, R, a, b', ε, ε1, -, hm, hε, hk, -⟩ := hs
  -- 呼び出しの型付けの反転: 引数は具体化した署名の引数の型を持ち、範囲の列は許容される。
  obtain ⟨e', he', htl, hel, had, hw, -, -, hR⟩ := inv_prim_app hm
  rw [hsig] at he'
  cases he'
  -- 対象一致の条件: 観測は具体化した署名の効果の名前 l の原子が許す。
  obtain ⟨l, hl, hobs⟩ := ht.obs_allowed hc hsig hkd hR htl hel had hw hr
  -- 継続を通した伝播: 処理する枠がないので、具体化した署名の効果が許す対象は末尾の効果 Eb が許す。
  obtain ⟨l0, hl0, hprop⟩ := ContTy.allows_end_of_prim_call (κ := B.effKind) hdecl hc hm hε hk hsig hkd hno
  rw [hl] at hl0
  cases hl0
  exact ⟨e, l, hsig, hl, fun t htm => (hprop l t (hobs t htm)).2⟩

/-- 全体の信頼条件のもとでの同じ定理。 -/
theorem step_target_sound_of_assumptions (hdecl : P.EffectsOk B) (hA : B.Assumptions P)
    {Eb : Eff} {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hs : StateTyE P B Eb s) (hst : Step P B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows Eb l t :=
  step_target_sound hdecl hA.core hA.target hs hst

/-- 一段の対象健全性の、事象の種類によらない形。どの事象の遷移でも、観測の対象は IO の事象の操作の名前の原子に
許される。解放の事象は観測を持たないので、主張は IO の事象についてのものである。 -/
theorem step_target_sound_event (hdecl : P.EffectsOk B) (hc : B.CoreAssumptions P) (ht : B.TargetAgreement P)
    {Eb : Eff} {s s' : State} {ev : Event} (hs : StateTyE P B Eb s) (hst : Step P B s (some ev) s') :
    ∀ t ∈ ev.obs, ∃ b ws o obs e l, ev = .io b ws o obs ∧ B.sig b = some e ∧ e.opEff = some l ∧
      B.Allows Eb l t := by
  intro t htm
  cases ev with
  | io b ws o obs =>
      obtain ⟨e, l, hsig, hl, hobs⟩ := step_target_sound hdecl hc ht hs hst
      exact ⟨b, ws, o, obs, e, l, rfl, hsig, hl, hobs t htm⟩
  | release v r => simp at htm

/-! ## 節の実行（E-OpPrim・E-Op の状態） -/

/-- 節の型付けの反転と、節自身の IO の外側の上限への伝播（E-OpPrim・E-Op の状態。SK §4）。操作 o（Fail でない）を
処理する最も内側の枠で継続を分け、その枠の節 c を選ぶ。c の本体は、節の添字を選ぶ枠の穴の効果 εh から決まる節の
操作の型 sg と、枠の下の継続の先頭の効果に含まれる効果 εc で型付く（`HasTypeClausesQ.find`）。節の本体の効果が許す
名前 l の対象は、l を処理する枠が枠の下の継続 k2 になければ、継続の末尾の効果 Eb が許す。節の本体の効果は名前を
差し引かれないので、節が保護本体と同じ名前の操作で別の対象へ行う IO も Eb に残る。 -/
theorem StateTyE.clause_allows {Eb : Eff} {m : Comp} {k : Cont} {σ : Store} {o : OpRef} {k1 k2 : Cont}
    {h : List Clause} {c : Clause} (hs : StateTyE P B Eb (.run m k σ)) (hne : o ≠ .fail)
    (hsplit : SplitAt o k k1 h k2) (hc : findClause h o = some c) :
    ∃ (Ψ : StoreTy) (Rh : Option Ty) (t : Ty) (εh εc : Eff) (sg : OpSig), ClauseSig P B εh o sg ∧ c.arity = sg.params.length ∧ c.ntys = sg.tparams.length ∧
      HasTypeC P B Ψ (sg.tparams ++ [])
        (some (.cont sg.ret (t.shift c.ntys 0) (Eff.shift c.ntys 0 εc)) :: (binds sg.params ++ shiftEnv c.ntys []))
        (Rh.map (Ty.shift c.ntys 0)) c.body (t.shift c.ntys 0) (Eff.shift c.ntys 0 εc) ∧
      ∀ l t', B.Allows (Eff.shift c.ntys 0 εc) l t' →
        (∀ hs', Frame.handleF hs' ∈ k2 → Eff.test (handled P B hs') (.nameTop l) = false) →
        B.Allows Eb l t' := by
  obtain ⟨Ψ, R, a, b, ε, ε1, -, -, -, hk, -⟩ := hs
  have ho := ContTy.selected_ordinary hk hne hsplit
  obtain ⟨rfl, -, -⟩ := hsplit
  obtain ⟨t, εh, εb, εc, Rh, -, hk2, hsub, hcl, -, -⟩ := hk.split ho
  obtain ⟨sg, hsg, harity, hntys, hew, hbody⟩ := hcl.find hc
  refine ⟨Ψ, Rh, t, εh, εc, sg, hsg, harity, hntys, hbody, fun l t' ha hno => ?_⟩
  -- 節の効果は閉じているので、型の変数のずらしは正規化だけである。
  have hshE : Eff.shift c.ntys 0 εc = Eff.norm εc := by
    rw [Eff.shift, Eff.rawShift_of_wf (c := 0) _ _ hew]
  rw [hshE] at ha
  exact ContTy.allows_clause_end hk2 hsub (Eff.allows_norm.mp ha) hno

/-- E-OpPrim の状態。組み込みの IO・終了の関数 b の呼び出しを、b の節を持つ最も内側の枠が捕捉するとき、
(1) 捕捉された呼び出しの具体化した署名の効果が許す対象は、節の添字を選ぶ枠の穴の効果 εh（保護本体の効果）が許し、
許す名前は署名の操作の名前 l だけである。(2) 節の本体の効果が許す対象は、処理する枠が枠の下の継続になければ、継続の
末尾の効果 Eb が許す（`StateTyE.clause_allows`）。 -/
theorem StateTyE.opPrim_clause_allows (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P)
    {Eb : Eff} {b0 : PrimName} {ts : List Ty} {es : List Eff} {rs : List Scope.Domain.Range} {ws : List Val}
    {k : Cont} {σ : Store} {s0 : PrimSig} {k1 k2 : Cont} {h : List Clause} {c : Clause}
    (hs : StateTyE P B Eb (.run (.app (.prim b0 ts es rs) ws) k σ)) (hsig : B.sig b0 = some s0)
    (hkd : s0.kind = .io ∨ s0.kind = .exit) (hsplit : SplitAt (.prim b0) k k1 h k2)
    (hc : findClause h (.prim b0) = some c) :
    ∃ l εh εc sg, s0.opEff = some l ∧ ClauseSig P B εh (.prim b0) sg ∧
      (∀ l' t, B.Allows (s0.inst rs).eff l' t → l' = l ∧ B.Allows εh l t) ∧
      ∀ l' t', B.Allows (Eff.shift c.ntys 0 εc) l' t' →
        (∀ hs', Frame.handleF hs' ∈ k2 → Eff.test (handled P B hs') (.nameTop l') = false) →
        B.Allows Eb l' t' := by
  obtain ⟨Ψ, R, a, b, ε, ε1, -, hm, hε, hk, -⟩ := hs
  have ho := ContTy.selected_ordinary hk (by simp) hsplit
  obtain ⟨rfl, -, hno1⟩ := hsplit
  obtain ⟨t, εh, εb, εc, Rh, -, hk2, hsub, hcl, -, hhole⟩ := hk.split ho
  -- 節の操作の型は、穴の効果 εh から選ぶ。
  obtain ⟨sg, hsg, -, -, hew, -⟩ := hcl.find hc
  -- 呼び出しの効果: 形の検査から、具体化した署名の効果は操作の名前 l の原子一つである。
  obtain ⟨s', hs'', _, _, _, _, _, hsubc, _⟩ := inv_prim_app hm
  rw [hsig] at hs''
  cases hs''
  obtain ⟨l, bs, ix, hl, hbs, hb0, heq⟩ := (hb.io_op b0 _ hsig hkd).eff_eq
  refine ⟨l, εh, εc, sg, hl, hsg, fun l' t0 ha => ?_, fun l' t1 ha hno => ?_⟩
  · obtain ⟨kd, r, hkd', hmem, htk⟩ := ha
    have hmem' := hmem
    rw [PrimSig.inst_eff, heq, Eff.instR_singleAt, Eff.mem_singleAt] at hmem'
    simp only [Atom.name.injEq] at hmem'
    obtain ⟨rfl, -⟩ := hmem'
    -- 呼び出しの原子は、それを覆う原子として計算の効果と穴の効果 εh に届く（L40.6c）。
    obtain ⟨a1, ha1, ha1c⟩ := hsubc.1 _ (Eff.substAt_name hmem)
    obtain ⟨jx, rfl⟩ := ha1c.name_right
    obtain ⟨r2, hm2, hc2⟩ := hhole l' _ (hε.1 _ ha1) (NoHandler.handled_false hdecl hbs hb0 hno1)
    exact ⟨rfl, Eff.allows_of_mem_covers hkd' hm2 (hc2.trans ha1c) htk⟩
  · have hshE : Eff.shift c.ntys 0 εc = Eff.norm εc := by
      rw [Eff.shift, Eff.rawShift_of_wf (c := 0) _ _ hew]
    rw [hshE] at ha
    exact ContTy.allows_clause_end hk2 hsub (Eff.allows_norm.mp ha) hno

end Benitoite.Release
