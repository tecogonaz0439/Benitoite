import Benitoite.Release.Refinement.Embedding
import Benitoite.Release.Refinement.HiddenCaptureBoundary

/-! # 旧の構文の像の状態の局所参照

旧の構文の状態は、実行時の閉包・照合・枠・セルの捕捉を全て空にして埋め込む（`embedState`）。型の付いた状態の
局所の不変条件（`LocalStateInvariant`）は捕捉の値を型付きの位置についてだけ調べるが、旧の像には捕捉の位置が
ないので、型の付かない隠れた位置を持つ反例（`CaptureLocalRefsBoundary.hidden_slot_read_localrefs`）の形は
現れない。旧の局所参照の保証は、この像の範囲で新しい不変条件から得る（設計書 01-12「篩を含む状態の型付け」）。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 枠が持つ捕捉（let の閉包、handle の捕捉、guard の捕捉と本体の閉包）。 -/
def Frame.captures : Frame → List Capture
  | .letF q => [q.capture]
  | .handleF cap _ => [cap]
  | .guardF _ cap _ _ body => [cap, body.capture]
  | .mark | .update _ | .release _ | .drop _ => []

/-- 継続の全ての枠の捕捉。 -/
def Cont.captures (k : Cont) : List Capture := k.flatMap Frame.captures

/-- セルが持つ捕捉（遅延の閉包と、保存した継続の枠）。 -/
def Cell.captures : Cell → List Capture
  | .thunk q => [q.capture]
  | .cont k => Cont.captures k
  | .builder _ | .val _ | .done _ | .used => []

/-- 状態が最上位に持つ捕捉（実行中の閉包か照合の捕捉、継続の枠、ストアのセル）が全て空である。 -/
def State.CapturesEmpty : State → Prop
  | .run q k μ => q.capture = Capture.empty ∧ (∀ cap ∈ Cont.captures k, cap = Capture.empty) ∧
      ∀ l c, μ l = some c → ∀ cap ∈ c.captures, cap = Capture.empty
  | .matchRun _ cap _ _ k μ => cap = Capture.empty ∧ (∀ cap ∈ Cont.captures k, cap = Capture.empty) ∧
      ∀ l c, μ l = some c → ∀ cap ∈ c.captures, cap = Capture.empty
  | .error _ k μ | .exit _ _ k μ => (∀ cap ∈ Cont.captures k, cap = Capture.empty) ∧
      ∀ l c, μ l = some c → ∀ cap ∈ c.captures, cap = Capture.empty

theorem embedCont_captures (k : Benitoite.Release.Cont) : ∀ cap ∈ Cont.captures (embedCont k), cap = Capture.empty := by
  induction k with
  | nil => intro cap h; cases h
  | cons f k ih =>
    intro cap h
    simp only [Cont.captures, embedCont, List.map_cons, List.flatMap_cons, List.mem_append] at h
    rcases h with h | h
    · cases f <;> simp [embedFrame, Frame.captures, Closure.pure, Closure.capture] at h <;>
        first | exact h | (rcases h with h | h <;> exact h)
    · exact ih cap h

theorem embedStore_captures (μ : Benitoite.Release.Store) :
    ∀ l c, embedStore μ l = some c → ∀ cap ∈ c.captures, cap = Capture.empty := by
  intro l c hc cap hcap
  simp only [embedStore, Option.map_eq_some_iff] at hc
  obtain ⟨c0, _, rfl⟩ := hc
  cases c0 with
  | thunk m => simpa [embedCell, Cell.captures, Closure.pure, Closure.capture] using hcap
  | cont k => exact embedCont_captures k cap hcap
  | builder _ | val _ | done _ | used => simp [embedCell, Cell.captures] at hcap

/-- 旧の構文の状態の像は、最上位の全ての捕捉が空である。 -/
theorem embedState_capturesEmpty (s : Benitoite.Release.State) : (embedState s).CapturesEmpty := by
  cases s with
  | run m k μ => exact ⟨rfl, embedCont_captures k, embedStore_captures μ⟩
  | matchRun v arms next k μ => exact ⟨rfl, embedCont_captures k, embedStore_captures μ⟩
  | error rs k μ => exact ⟨embedCont_captures k, embedStore_captures μ⟩
  | exit n rs k μ => exact ⟨embedCont_captures k, embedStore_captures μ⟩

/-- 空の捕捉には位置がないので、捕捉の全ての位置についての条件は、型付きの位置に限らず成り立つ。 -/
theorem Capture.empty_all_slots (Q : Option Val → Prop) : ∀ ov ∈ Capture.empty.values, Q ov := by
  intro ov h; cases h

/-- 旧の構文の状態の像が型付きなら、局所の不変条件が成り立ち、その状態の最上位の捕捉は全て空である。
したがって、不変条件が型付きの位置だけを調べることによる制限（隠れた位置の閉包の専用参照）は、この像には
現れない。 -/
theorem embedState_local_invariant {P B σ Eb} {s : Benitoite.Release.State}
    (h : StateTyE P B σ Eb (embedState s)) :
    LocalStateInvariant P B σ (embedState s) ∧ (embedState s).CapturesEmpty :=
  ⟨h.local_invariant, embedState_capturesEmpty s⟩

/-- 隠れた位置の反例の状態は、捕捉が空でないので旧の構文の像ではない。 -/
theorem hidden_capture_not_embedded :
    ¬ (State.run (.mk (Capture.empty.extend (.closure (.done (.base .unit) Eff.empty)
      (.pure (.builderOp .string .copy (.loc 7) [])))) (.ret (.const .unit))) [] Store.empty).CapturesEmpty := by
  intro h
  have he := h.1
  simp [Closure.capture, Capture.extend, Capture.empty, Capture.values] at he

/-- 返却だけの旧の状態の像に適用する。 -/
example (P : Program) (B : Builtins) (σ : PathEnv) :
    (embedState (.run (.ret (.const .unit)) [] (fun _ => none))).CapturesEmpty :=
  (embedState_local_invariant (P := P) (B := B) (σ := σ) (Eb := Eff.empty) (by
    have he : embedState (.run (.ret (.const .unit)) [] (fun _ => none)) =
        .run (Closure.pure (.ret (.const .unit))) [] Store.empty := by
      simp only [embedState, embedCont, List.map_nil]
      rfl
    rw [he]
    exact (CaptureLocalRefsBoundary.empty_capture_accepts P B σ).1)).2

end
end Benitoite.Release.Refinement
