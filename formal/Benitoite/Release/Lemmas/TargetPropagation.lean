import Benitoite.Release.Lemmas.EffectSound
import Benitoite.Release.Lemmas.TargetSound

/-!
# 継続を通した対象の伝播（L30.3）

`ContTy.end_of_noHandler` の対象版を置く。計算の効果が名前 l の対象 t を許す（許可の関係 `Eff.Allows κ`）とき、
l を処理する `handle` の枠が継続になければ、継続の末尾の効果も同じ対象を許す（`ContTy.allows_end`）。許可の関係は
名前と範囲の位置を持つ原子の所属で決まり、継続の型付けは原子を、それを覆う同じ名前の原子として末尾へ運ぶ
（`ContTy.name_end_ix`）。被覆は許可の包含を与えるので（`Eff.allows_of_mem_covers`）、範囲付きの原子の許す対象は
末尾にも届く（L40.6c）。

場合ごとの形は次のとおりである。

- 処理されない操作（E-IO・E-IOErr・E-Exit の状態）: 組み込みの操作 b を処理する枠がなければ、b の具体化した署名の
  効果が許す対象は継続の末尾の効果が許す（`ContTy.allows_end_of_noHandler`・`ContTy.allows_end_of_prim_call`）。
- 捕捉の枠（E-OpPrim の状態）: 操作を処理する最も内側の枠の穴の効果（保護本体の効果）は、計算の効果が許す対象を
  許す（`ContTy.allows_hole_of_split`）。節は枠の下の継続の効果 εc で型付くので、節自身の範囲付きの IO が許される
  対象は、枠の下の継続の末尾の効果に残る（`ContTy.allows_clause_end`）。`handled(H)` は名前の原子を範囲によらず
  除くので（`handled_name`）、処理した名前の原子は外側の上限に残らず、ほかの名前の原子は同じ範囲の位置のまま
  外側の上限に残る（`Eff.mem_outer_of_not_handled`）。
- 解放の枠: 解放の枠と `drop` の枠は操作を処理しない（`releases_no_handle`）。E-DropRel などで捨てる継続の
  `releases(K')` を積んだ継続でも、処理する枠の条件は元の継続のものと同じであり（`NoHandler.releases_append`）、
  解放の枠を越えて対象が届く（`ContTy.allows_end_release`・`ContTy.allows_end_releases`）。

許可の関係の κ は任意である。対象健全性の言明（L30.4・L30.5）は κ を表の `effKind` にした `Builtins.Allows` で
使う（設計書 01-12「ハンドラ」）。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins} {κ : EffName → Option Scope.Domain.Kind}

/-! ## 一般の形 -/

/-- 継続の先頭の効果 ε が名前 l の対象 t を許し、l を処理する `handle` の枠が継続になければ、継続の末尾の効果 ε0 も
t を許す。 -/
theorem ContTy.allows_end {Ψ R ε k a b ε0 Re l t} (h : ContTy P B Ψ R ε k a b ε0 Re)
    (ha : Eff.Allows κ ε l t)
    (hno : ∀ hs, Frame.handleF hs ∈ k → Eff.test (handled P B hs) (.nameTop l) = false) :
    Eff.Allows κ ε0 l t := by
  obtain ⟨kd, r, hk, hm, ht⟩ := ha
  obtain ⟨r', hm', hc⟩ := h.name_end_ix hm hno
  exact Eff.allows_of_mem_covers hk hm' hc ht

/-! ## 処理されない操作 -/

/-- `ContTy.end_of_noHandler` の対象版。組み込みのエフェクト l の操作 b0 を処理する `handle` の枠が継続になければ、
継続の先頭の効果が許す l の対象は、継続の末尾の効果も許す。 -/
theorem ContTy.allows_end_of_noHandler (hdecl : P.EffectsOk B) {Ψ R ε k a b Eb Re l t bs b0}
    (hk : ContTy P B Ψ R ε k a b Eb Re) (hbs : B.effects l = some bs) (hb0 : b0 ∈ bs)
    (ha : Eff.Allows κ ε l t) (hno : NoHandler k (.prim b0)) : Eff.Allows κ Eb l t :=
  hk.allows_end ha (NoHandler.handled_false hdecl hbs hb0 hno)

/-- 組み込みの IO・終了の関数の呼び出しを処理する枠がないとき、具体化した署名の効果が許す対象は、継続の末尾の効果も
許す。具体化した署名の効果は操作の名前 l の原子一つなので（形の検査 `io_op`）、許す名前は l だけである。
E-IO・E-IOErr・E-Exit の事象の観測を末尾の効果へ運ぶ部品である（観測の許可は `TargetAgreement.obs_allowed`）。 -/
theorem ContTy.allows_end_of_prim_call (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P)
    {Ψ R a ε1 ε b' Eb Re b0 ts es rs ws k s0}
    (hm : HasTypeC P B Ψ [] [] R (.app (.prim b0 ts es rs) ws) a ε1) (hε : Eff.Sub ε1 ε)
    (hk : ContTy P B Ψ R ε k a b' Eb Re) (hsig : B.sig b0 = some s0) (hkd : s0.kind = .io ∨ s0.kind = .exit)
    (hno : NoHandler k (.prim b0)) :
    ∃ l, s0.opEff = some l ∧ ∀ l' t, Eff.Allows κ (s0.inst rs).eff l' t → l' = l ∧ Eff.Allows κ Eb l t := by
  obtain ⟨s', hs', _, _, _, _, _, hsub, _⟩ := inv_prim_app hm
  rw [hsig] at hs'; cases hs'
  obtain ⟨l, bs, ix, hl, hbs, hb0, heq⟩ := (hb.io_op b0 _ hsig hkd).eff_eq
  refine ⟨l, hl, fun l' t ha => ?_⟩
  obtain ⟨kd, r, hkd', hmem, ht⟩ := ha
  have hmem' := hmem
  rw [PrimSig.inst_eff, heq, Eff.instR_singleAt, Eff.mem_singleAt] at hmem'
  simp only [Atom.name.injEq] at hmem'
  obtain ⟨rfl, -⟩ := hmem'
  obtain ⟨a1, ha1, ha1c⟩ := hsub.1 _ (Eff.substAt_name hmem)
  obtain ⟨jx, rfl⟩ := ha1c.name_right
  exact ⟨rfl, hk.allows_end_of_noHandler hdecl hbs hb0
    (Eff.allows_of_mem_covers hkd' (hε.1 _ ha1) ha1c ht) hno⟩

/-! ## 捕捉の枠 -/

/-- 捕捉の枠への伝播。組み込みのエフェクト l の操作 b0 を処理する最も内側の `handle` の枠で継続を分けると、その枠の
穴の効果 εh（保護本体の効果。節の添字はここから選ぶ）は、継続の先頭の効果が許す l の対象を許す。 -/
theorem ContTy.allows_hole_of_split (hdecl : P.EffectsOk B) {Ψ R ε a b E Re hs k1 k2 l bs b0}
    (h : ContTy P B Ψ R ε (k1 ++ .handleF hs :: k2) a b E Re) (ho : handles hs .fail = false)
    (hbs : B.effects l = some bs) (hb0 : b0 ∈ bs) (hno : NoHandler k1 (.prim b0)) :
    ∃ t εh εb εc Rh, ContTy P B Ψ R ε (k1 ++ [.handleF hs]) a t εc Rh ∧ ContTy P B Ψ Rh εb k2 t b E Re ∧
      Eff.Covers εb εc ∧ HasTypeClauses P B Ψ [] [] Rh εh hs t εc ∧ Ty.WF 0 0 t ∧
      ∀ t', Eff.Allows κ ε l t' → Eff.Allows κ εh l t' := by
  obtain ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, h6⟩ := h.split ho
  refine ⟨t, εh, εb, εc, Rh, h1, h2, h3, h4, h5, fun t' ha => ?_⟩
  obtain ⟨kd, r, hk, hm, ht⟩ := ha
  obtain ⟨r', hm', hc⟩ := h6 l _ hm (NoHandler.handled_false hdecl hbs hb0 hno)
  exact Eff.allows_of_mem_covers hk hm' hc ht

/-- 節自身の IO の伝播。節は枠の下の継続の効果に被覆で含まれる効果 εc で型付く（K-Handle）。εc が許す名前 l の対象は、
l を処理する枠が枠の下の継続になければ、継続の末尾の効果も許す。処理した名前の原子は `handled(H)` が除くが、節の
効果 εc は `handled(H)` を含まないので、節が別の対象へ行う IO は外側の上限に残る。 -/
theorem ContTy.allows_clause_end {Ψ Rh εb k2 t b E Re εc l t'} (hk2 : ContTy P B Ψ Rh εb k2 t b E Re)
    (hsub : Eff.Covers εb εc) (ha : Eff.Allows κ εc l t')
    (hno : ∀ hs, Frame.handleF hs ∈ k2 → Eff.test (handled P B hs) (.nameTop l) = false) :
    Eff.Allows κ E l t' :=
  hk2.allows_end (hsub.sound ha) hno

/-- 名前全体の除去。`handled(H)` が名前 l を含めば、l のどの範囲の位置の原子も含む（範囲の一部だけを除かない）。 -/
theorem mem_handled_of_nameTop {hs : List Clause} {l : EffName} (h : Eff.mem (handled P B hs) (.nameTop l))
    (ix : Scope.Signature.Ix) : Eff.mem (handled P B hs) (.name l ix) :=
  (mem_handled_name_iff P B hs l ix .top).mpr h

/-- 外側の上限に残る原子。`εm ⊆ ε ∪ handled(H)`（C-Handle・K-Handle の前提）のもとで、`handled(H)` が含まない名前 l の
原子は、同じ範囲の位置のまま ε に残る。 -/
theorem Eff.mem_outer_of_not_handled {εm ε : Eff} {hs : List Clause} {l : EffName} {ix : Scope.Signature.Ix}
    (hsub : Eff.Sub εm (Eff.union ε (handled P B hs))) (hm : Eff.mem εm (.name l ix))
    (hno : Eff.test (handled P B hs) (.nameTop l) = false) : Eff.mem ε (.name l ix) := by
  have h := hsub.1 _ hm
  rw [Eff.mem_union] at h
  exact h.resolve_right (fun hx => by
    change Eff.test (handled P B hs) (.name l ix) = true at hx
    rw [handled_name, hno] at hx
    cases hx)

/-- 外側の上限に残る対象。`εm ⊆ ε ∪ handled(H)` のもとで、`handled(H)` が含まない名前 l について εm が許す対象は、
ε も許す。 -/
theorem Eff.allows_outer_of_not_handled {εm ε : Eff} {hs : List Clause} {l : EffName} {t : Scope.Domain.Target}
    (hsub : Eff.Sub εm (Eff.union ε (handled P B hs))) (ha : Eff.Allows κ εm l t)
    (hno : Eff.test (handled P B hs) (.nameTop l) = false) : Eff.Allows κ ε l t := by
  obtain ⟨kd, r, hk, hm, ht⟩ := ha
  exact ⟨kd, r, hk, Eff.mem_outer_of_not_handled hsub hm hno, ht⟩

/-! ## 解放の枠 -/

/-- `releases(K)` は解放の枠と `drop` の枠だけからなり、`handle` の枠を含まない。 -/
theorem releases_no_handle (k : Cont) (hs : List Clause) : Frame.handleF hs ∉ releases k := by
  intro h
  obtain ⟨-, ⟨v, hv⟩ | ⟨κ', hκ⟩⟩ := releases_sub k _ h
  · cases hv
  · cases hκ

/-- 捨てる継続の `releases(K')` を積んでも、操作を処理する枠の条件は変わらない。 -/
theorem NoHandler.releases_append {k' k : Cont} {o : OpRef} :
    NoHandler (releases k' ++ k) o ↔ NoHandler k o := by
  constructor
  · intro h hs hin
    exact h hs (List.mem_append_right _ hin)
  · intro h hs hin
    rcases List.mem_append.mp hin with hin | hin
    · exact absurd hin (releases_no_handle k' hs)
    · exact h hs hin

/-- 解放の枠を越えた伝播。解放の枠は先頭の効果を変えず操作を処理しないので、枠の下の継続に処理する枠がなければ、
先頭の効果が許す対象は継続の末尾の効果も許す。 -/
theorem ContTy.allows_end_release {Ψ R ε v k a b ε0 Re l t} (h : ContTy P B Ψ R ε (.release v :: k) a b ε0 Re)
    (ha : Eff.Allows κ ε l t)
    (hno : ∀ hs, Frame.handleF hs ∈ k → Eff.test (handled P B hs) (.nameTop l) = false) :
    Eff.Allows κ ε0 l t :=
  h.allows_end ha (fun hs hin => by
    rcases List.mem_cons.mp hin with he | hin
    · cases he
    · exact hno hs hin)

/-- E-DropRel・E-EscDropRel・E-ErrDropRel・E-ExitDropRel の後の継続 `releases(K') ++ K` での伝播。積んだ解放の枠は
操作を処理しないので、K に処理する枠がなければ、先頭の効果が許す対象は継続の末尾の効果も許す。 -/
theorem ContTy.allows_end_releases {Ψ R ε k' k a b ε0 Re l t}
    (h : ContTy P B Ψ R ε (releases k' ++ k) a b ε0 Re) (ha : Eff.Allows κ ε l t)
    (hno : ∀ hs, Frame.handleF hs ∈ k → Eff.test (handled P B hs) (.nameTop l) = false) :
    Eff.Allows κ ε0 l t :=
  h.allows_end ha (fun hs hin => by
    rcases List.mem_append.mp hin with hin | hin
    · exact absurd hin (releases_no_handle k' hs)
    · exact hno hs hin)

end Benitoite.Release
