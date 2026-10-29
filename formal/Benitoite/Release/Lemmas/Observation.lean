import Benitoite.Release.Theorems
import Benitoite.Release.Examples
import Benitoite.Release.Lemmas.PrimRanges

/-!
# IO の観測の欄（問 8 の O1）

IO の応答の関係 `Builtins.ioResponse` は、応答と、その応答で作用した対象の観測（`Scope.Domain.Target` の有限列）を
受け取る。事象 `Event.io` は観測を持ち、`Oracle` は応答と観測の組を返す（設計書 01-12「実行の規則」）。観測は状態に
入らないので、遷移の先の状態は応答だけで決まる。

本ファイルは次を示す。

- 観測を捨てた欄が旧の欄と同値であること（問 18 の行 3）。`io_kind`・`io_typed`・`io_exists` の欄の本体を
  `Builtins.IOKindField` などとして書き、観測を捨てた応答の関係 `Builtins.ioResponseNoObs` で読んだ旧の形
  （`Builtins.IOKindNoObs` など。L20.6 の前の欄の字面）との同値を示す。観測を持たない旧の表の像
  （`liftNoObs`。観測は常に空）では、観測を捨てた関係は旧の関係そのものである。
- `step_sound` の `horacle` の新しい形（観測を量化する）から、観測を捨てた関係についての旧の形が従い、旧の表の
  像では旧の形から新しい形が従うこと（問 18 の行 9）。
- 事象に観測を持つ遷移は E-IO・E-IOErr・E-Exit だけであり、観測は応答の関係が許すものであること。
- 旧 Top の HTTP の操作は、リダイレクトの追従先を観測に含められ、追従先に最初の URL と同じ対象を求めないこと
  （小例 `ObservationExamples`）。

観測と範囲の対応（`io_target`）はこの欄に含めない。対象の一致の信頼条件は L20.7 で別の構造体に置く（問 7・問 9）。
-/

namespace Benitoite.Release

open Scope.Domain (Target)

variable {P : Program} {B : Builtins}

/-! ## 観測を捨てた応答の関係 -/

/-- 観測を持たない応答の関係の型（L20.6 の前の `Builtins.ioResponse` の型）。 -/
abbrev IOResponseNoObs := PrimName → List Ty → List Eff → List Val → Outcome → Prop

/-- 観測を捨てた応答の関係。応答 o は、何かの観測とともに起こりうるときに起こりうる。 -/
def Builtins.ioResponseNoObs (B : Builtins) : IOResponseNoObs :=
  fun b ts es ws o => ∃ obs, B.ioResponse b ts es ws o obs

/-- 観測を持たない旧の表の応答の関係を、観測が常に空の関係として読む（旧の表の像）。 -/
def liftNoObs (R : IOResponseNoObs) : PrimName → List Ty → List Eff → List Val → Outcome → List Target → Prop :=
  fun b ts es ws o obs => R b ts es ws o ∧ obs = []

/-- 旧の表の像では、観測を捨てた関係は旧の関係そのものである。 -/
theorem Builtins.ioResponseNoObs_liftNoObs {R : IOResponseNoObs} (hB : B.ioResponse = liftNoObs R) :
    B.ioResponseNoObs = R := by
  funext b ts es ws o
  apply propext
  simp only [Builtins.ioResponseNoObs, hB, liftNoObs]
  exact ⟨fun ⟨_, h, _⟩ => h, fun h => ⟨[], h, rfl⟩⟩

/-! ## 三つの欄の本体と、観測を捨てた旧の形 -/

/-- `io_kind` の欄の本体（字面は `Builtins.Assumptions` のとおり）。 -/
def Builtins.IOKindField (B : Builtins) : Prop :=
  ∀ b s ts es ws o obs, B.sig b = some s → B.ioResponse b ts es ws o obs →
    (s.kind = .io ∧ ∀ n, o ≠ .exit n) ∨ (s.kind = .exit ∧ ∀ v, o ≠ .val v)

/-- 観測を持たない関係 R で読んだ旧の `io_kind`（L20.6 の前の字面）。 -/
def Builtins.IOKindNoObs (B : Builtins) (R : IOResponseNoObs) : Prop :=
  ∀ b s ts es ws o, B.sig b = some s → R b ts es ws o →
    (s.kind = .io ∧ ∀ n, o ≠ .exit n) ∨ (s.kind = .exit ∧ ∀ v, o ≠ .val v)

/-- `io_typed` の欄の本体。 -/
def Builtins.IOTypedField (P : Program) (B : Builtins) : Prop :=
  ∀ Ψ b s rs ts es ws o obs, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.RangeAdmissible b s rs →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    B.ioResponse b ts es ws o obs → OutcomeTy P B Ψ o (Ty.subst ts es (s.inst rs).ret)

/-- 観測を持たない関係 R で読んだ旧の `io_typed`。 -/
def Builtins.IOTypedNoObs (P : Program) (B : Builtins) (R : IOResponseNoObs) : Prop :=
  ∀ Ψ b s rs ts es ws o, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.RangeAdmissible b s rs →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    R b ts es ws o → OutcomeTy P B Ψ o (Ty.subst ts es (s.inst rs).ret)

/-- `io_exists` の欄の本体。 -/
def Builtins.IOExistsField (P : Program) (B : Builtins) : Prop :=
  ∀ Ψ b s rs ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.RangeAdmissible b s rs →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    ∃ o obs, B.ioResponse b ts es ws o obs

/-- 観測を持たない関係 R で読んだ旧の `io_exists`。 -/
def Builtins.IOExistsNoObs (P : Program) (B : Builtins) (R : IOResponseNoObs) : Prop :=
  ∀ Ψ b s rs ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → B.RangeAdmissible b s rs →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) →
    ∃ o, R b ts es ws o

/-- 三つの欄は、上の本体の字面のとおりである。 -/
theorem Builtins.CoreAssumptions.ioKind_field (hb : B.CoreAssumptions P) : B.IOKindField := hb.io_kind

theorem Builtins.CoreAssumptions.ioTyped_field (hb : B.CoreAssumptions P) : B.IOTypedField P := hb.io_typed

theorem Builtins.CoreAssumptions.ioExists_field (hb : B.CoreAssumptions P) : B.IOExistsField P := hb.io_exists

/-- 観測を捨てた `io_kind` は旧の `io_kind` と同値である（問 18 の行 3）。 -/
theorem Builtins.ioKind_iff_noObs (B : Builtins) : B.IOKindField ↔ B.IOKindNoObs B.ioResponseNoObs := by
  constructor
  · rintro h b s ts es ws o hs ⟨obs, hr⟩
    exact h b s ts es ws o obs hs hr
  · intro h b s ts es ws o obs hs hr
    exact h b s ts es ws o hs ⟨obs, hr⟩

/-- 観測を捨てた `io_typed` は旧の `io_typed` と同値である（問 18 の行 3）。 -/
theorem Builtins.ioTyped_iff_noObs (P : Program) (B : Builtins) :
    B.IOTypedField P ↔ B.IOTypedNoObs P B.ioResponseNoObs := by
  constructor
  · rintro h Ψ b s rs ts es ws o hs hk hrs htl hel had hargs ⟨obs, hr⟩
    exact h Ψ b s rs ts es ws o obs hs hk hrs htl hel had hargs hr
  · intro h Ψ b s rs ts es ws o obs hs hk hrs htl hel had hargs hr
    exact h Ψ b s rs ts es ws o hs hk hrs htl hel had hargs ⟨obs, hr⟩

/-- 観測を捨てた `io_exists` は旧の `io_exists` と同値である（問 18 の行 3）。 -/
theorem Builtins.ioExists_iff_noObs (P : Program) (B : Builtins) :
    B.IOExistsField P ↔ B.IOExistsNoObs P B.ioResponseNoObs := by
  constructor
  · intro h Ψ b s rs ts es ws hs hk hrs htl hel had hargs
    obtain ⟨o, obs, hr⟩ := h Ψ b s rs ts es ws hs hk hrs htl hel had hargs
    exact ⟨o, obs, hr⟩
  · intro h Ψ b s rs ts es ws hs hk hrs htl hel had hargs
    obtain ⟨o, obs, hr⟩ := h Ψ b s rs ts es ws hs hk hrs htl hel had hargs
    exact ⟨o, obs, hr⟩

/-- 旧の表の像では、三つの欄は旧の関係 R で読んだ旧の欄と同値である。 -/
theorem Builtins.ioFields_iff_old_of_liftNoObs (P : Program) {R : IOResponseNoObs} (hB : B.ioResponse = liftNoObs R) :
    (B.IOKindField ↔ B.IOKindNoObs R) ∧ (B.IOTypedField P ↔ B.IOTypedNoObs P R) ∧
      (B.IOExistsField P ↔ B.IOExistsNoObs P R) := by
  have h := Builtins.ioResponseNoObs_liftNoObs hB
  refine ⟨?_, ?_, ?_⟩
  · rw [← h]; exact B.ioKind_iff_noObs
  · rw [← h]; exact Builtins.ioTyped_iff_noObs P B
  · rw [← h]; exact Builtins.ioExists_iff_noObs P B

/-! ## 範囲の量化の旧の形との合成 -/

/-- 観測を持たない関係 R で読んだ、範囲の列もない旧の `io_typed`（L20.5 の前の字面）。 -/
def Builtins.IOTypedOldNoObs (P : Program) (B : Builtins) (R : IOResponseNoObs) : Prop :=
  ∀ Ψ b s ts es ws o, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    R b ts es ws o → OutcomeTy P B Ψ o (Ty.subst ts es s.ret)

/-- 観測を持たない関係 R で読んだ、範囲の列もない旧の `io_exists`。 -/
def Builtins.IOExistsOldNoObs (P : Program) (B : Builtins) (R : IOResponseNoObs) : Prop :=
  ∀ Ψ b s ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    ∃ o, R b ts es ws o

/-- 範囲の列のない旧の `io_typed` も、観測を捨てると観測を持たない旧の形と同値である。範囲の量化の同値
`Builtins.io_typed_iff_old` と合わせると、範囲の変数のない表では今の欄が L20.5 の前の欄と同値になる。 -/
theorem Builtins.ioTypedOld_iff_noObs (P : Program) (B : Builtins) :
    B.IOTypedOld P ↔ B.IOTypedOldNoObs P B.ioResponseNoObs := by
  constructor
  · rintro h Ψ b s ts es ws o hs hk htl hel had hargs ⟨obs, hr⟩
    exact h Ψ b s ts es ws o obs hs hk htl hel had hargs hr
  · intro h Ψ b s ts es ws o obs hs hk htl hel had hargs hr
    exact h Ψ b s ts es ws o hs hk htl hel had hargs ⟨obs, hr⟩

/-- `io_exists` についての同じ同値。 -/
theorem Builtins.ioExistsOld_iff_noObs (P : Program) (B : Builtins) :
    B.IOExistsOld P ↔ B.IOExistsOldNoObs P B.ioResponseNoObs := by
  constructor
  · intro h Ψ b s ts es ws hs hk htl hel had hargs
    obtain ⟨o, obs, hr⟩ := h Ψ b s ts es ws hs hk htl hel had hargs
    exact ⟨o, obs, hr⟩
  · intro h Ψ b s ts es ws hs hk htl hel had hargs
    obtain ⟨o, obs, hr⟩ := h Ψ b s ts es ws hs hk htl hel had hargs
    exact ⟨o, obs, hr⟩

/-- 範囲の変数のない表で、今の `io_typed` の欄は、範囲の列も観測もない旧の欄と同値である（範囲の量化と観測の
量化の二つの変更の合成）。 -/
theorem Builtins.ioTyped_iff_oldNoObs {P : Program} {B : Builtins} (hB : B.RangeFree)
    (hsc : ∀ b s, B.sig b = some s → s.Scoped) :
    B.IOTypedField P ↔ B.IOTypedOldNoObs P B.ioResponseNoObs := by
  rw [← Builtins.ioTypedOld_iff_noObs, ← Builtins.io_typed_iff_old hB hsc]
  exact ⟨fun h b s hs rs hrs Ψ ts es ws o obs hk htl hel had hargs hr =>
      h Ψ b s rs ts es ws o obs hs hk hrs htl hel had hargs hr,
    fun h Ψ b s rs ts es ws o obs hs hk hrs htl hel had hargs hr =>
      h b s hs rs hrs Ψ ts es ws o obs hk htl hel had hargs hr⟩

/-- `io_exists` についての同じ合成。 -/
theorem Builtins.ioExists_iff_oldNoObs {P : Program} {B : Builtins} (hB : B.RangeFree)
    (hsc : ∀ b s, B.sig b = some s → s.Scoped) :
    B.IOExistsField P ↔ B.IOExistsOldNoObs P B.ioResponseNoObs := by
  rw [← Builtins.ioExistsOld_iff_noObs, ← Builtins.io_exists_iff_old hB hsc]
  exact ⟨fun h b s hs rs hrs Ψ ts es ws hk htl hel had hargs =>
      h Ψ b s rs ts es ws hs hk hrs htl hel had hargs,
    fun h Ψ b s rs ts es ws hs hk hrs htl hel had hargs =>
      h b s hs rs hrs Ψ ts es ws hk htl hel had hargs⟩

/-! ## `Oracle` と `step_sound` の `horacle` -/

/-- 観測を持たない旧の応答の選び方を、観測を常に空とする `Oracle` として読む。 -/
def Oracle.ofNoObs (oracle0 : PrimName → List Ty → List Eff → List Val → Outcome) : Oracle :=
  fun b ts es ws => (oracle0 b ts es ws, [])

/-- `step_sound` の `horacle` の新しい形から、観測を捨てた関係と `oracle` の応答の成分についての旧の形が従う
（問 18 の行 9）。 -/
theorem horacle_noObs {oracle : Oracle}
    (h : ∀ b ts es ws o obs, B.ioResponse b ts es ws o obs →
      B.ioResponse b ts es ws (oracle b ts es ws).1 (oracle b ts es ws).2) :
    ∀ b ts es ws o, B.ioResponseNoObs b ts es ws o →
      B.ioResponseNoObs b ts es ws (oracle b ts es ws).1 := by
  rintro b ts es ws o ⟨obs, hr⟩
  exact ⟨_, h b ts es ws o obs hr⟩

/-- 旧の表の像では、旧の `horacle` から、観測を空とする `Oracle.ofNoObs` についての新しい形が従う。上の
`horacle_noObs` とあわせて、旧の表の像の上で新旧の `horacle` は同じ条件である。 -/
theorem horacle_of_noObs {R : IOResponseNoObs} (hB : B.ioResponse = liftNoObs R)
    {oracle0 : PrimName → List Ty → List Eff → List Val → Outcome}
    (h : ∀ b ts es ws o, R b ts es ws o → R b ts es ws (oracle0 b ts es ws)) :
    ∀ b ts es ws o obs, B.ioResponse b ts es ws o obs →
      B.ioResponse b ts es ws (Oracle.ofNoObs oracle0 b ts es ws).1 (Oracle.ofNoObs oracle0 b ts es ws).2 := by
  intro b ts es ws o obs hr
  rw [hB] at hr ⊢
  exact ⟨h b ts es ws o hr.1, rfl⟩

/-! ## 観測を持つ遷移 -/

/-- 観測を持つ事象の遷移は、処理する節のない組み込みの IO の呼び出し（E-IO・E-IOErr・E-Exit）であり、
応答と観測の組は応答の関係が許すものである。 -/
theorem Step.io_inv {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (h : Step P B s (some (.io b ws o obs)) s') :
    ∃ ts es rs k σ, s = .run (.app (.prim b ts es rs) ws) k σ ∧ NoHandler k (.prim b) ∧
      B.ioResponse b ts es ws o obs := by
  cases h with
  | E_IO _ _ hno hr => exact ⟨_, _, _, _, _, rfl, hno, hr⟩
  | E_IOErr _ _ hno hr => exact ⟨_, _, _, _, _, rfl, hno, hr⟩
  | E_Exit _ _ hno hr => exact ⟨_, _, _, _, _, rfl, hno, hr⟩

/-- 観測を捨てると、IO の事象の応答は観測を捨てた関係が許すものである。 -/
theorem Step.io_noObs {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (h : Step P B s (some (.io b ws o obs)) s') :
    ∃ ts es rs k σ, s = .run (.app (.prim b ts es rs) ws) k σ ∧ B.ioResponseNoObs b ts es ws o := by
  obtain ⟨ts, es, rs, k, σ, rfl, _, hr⟩ := h.io_inv
  exact ⟨ts, es, rs, k, σ, rfl, obs, hr⟩

/-! ## 小例: 旧 Top の HTTP のリダイレクト -/

namespace ObservationExamples

open Release.Examples (sig unitTy)

/-- 旧 Top の `Http.send` の形の項目。引数は URL の文字列であり、範囲の位置を持たない。 -/
def sendSig : PrimSig :=
  sig [] ["url"] [.base .string] unitTy (Eff.single "Http.Connect") .io (some "Http.Connect")

/-- ホスト名とポート 443 の endpoint の対象。 -/
def endpointOf (h : String) : Target := .endpoint ⟨.name [h], 443⟩

/-- 最初の URL の対象と、リダイレクトの追従先の対象。 -/
def firstTarget : Target := endpointOf "a.example"
def redirectTarget : Target := endpointOf "b.example"

def url : Val := .const (.string "https://a.example/")

/-- 旧 Top の HTTP の応答の関係の例。観測は endpoint の種類の対象の有限列なら何でもよく、リダイレクトを追従した
先を含めてよい。最初の URL の対象と同じであることを求めない。対象の一致（`io_target`）は L20.7 で別の信頼条件に
置くので、この関係には含めない。仮定 `Builtins.Assumptions` を満たす実例ではない。 -/
def builtins : Builtins :=
  { Release.Examples.builtins with
    sig := fun b => if b = "Http.send" then some sendSig else Release.Examples.builtins.sig b
    ioResponse := fun b ts es ws o obs =>
      if b = "Http.send" then (∃ u, ws = [.const (.string u)]) ∧ o = .val (.const .unit) ∧
        ∀ t ∈ obs, t.kind = .endpoint
      else Release.Examples.builtins.ioResponse b ts es ws o obs }

theorem redirectTarget_ne_first : redirectTarget ≠ firstTarget := by decide

/-- リダイレクトの追従先を含む観測を持つ E-IO の遷移。 -/
theorem redirect_step {P : Program} {σ : Store} :
    Step P builtins (.run (.app (.prim "Http.send" [] [] []) [url]) [] σ)
      (some (.io "Http.send" [url] (.val (.const .unit)) [firstTarget, redirectTarget]))
      (.run (.ret (.const .unit)) [] σ) :=
  .E_IO (s := sendSig) (by simp [builtins]) rfl (fun _ h => by cases h)
    (by simp [builtins, url, firstTarget, redirectTarget, endpointOf, Target.kind])

/-- 追従先だけを観測に持つ遷移もある。観測は最初の URL の対象を含まなくてよい。 -/
theorem redirect_only_step {P : Program} {σ : Store} :
    Step P builtins (.run (.app (.prim "Http.send" [] [] []) [url]) [] σ)
      (some (.io "Http.send" [url] (.val (.const .unit)) [redirectTarget]))
      (.run (.ret (.const .unit)) [] σ) :=
  .E_IO (s := sendSig) (by simp [builtins]) rfl (fun _ h => by cases h)
    (by simp [builtins, url, redirectTarget, endpointOf, Target.kind])

/-- 応答の関係は、最初の URL の対象と同じ一つの対象を観測に求めない。 -/
theorem not_requires_first :
    ∃ obs, builtins.ioResponse "Http.send" [] [] [url] (.val (.const .unit)) obs ∧ obs ≠ [firstTarget] ∧
      firstTarget ∉ obs :=
  ⟨[redirectTarget], by simp [builtins, url, redirectTarget, endpointOf, Target.kind],
    by simp [redirectTarget_ne_first], by simp [Ne.symm redirectTarget_ne_first]⟩

end ObservationExamples

end Benitoite.Release
