import Benitoite.Release.Lemmas.BuilderTyping
import Benitoite.Release.Lemmas.StepSound
import Benitoite.Release.Lemmas.LocalInvariant
import Benitoite.Release.Examples
import Benitoite.Release.Model

/-!
# 専用操作の実行の具体例

実行の入口から、Unicode のバイト長・追記の順序・失敗時の内容不変を独立した期待値で確認する。
設計書 01-12「構築器の専用セルの内容と上限」に対応する。
-/
namespace Benitoite.Release.BuilderExamples

variable (P : Program) (B : Builtins)

/-- String は文字数ではなく UTF-8 のバイト数を返す。 -/
theorem unicode_length :
    step P B (fun _ _ _ _ => .val (.const .unit)) (fun _ => none) (fun _ => 0)
      (.run (.builderOp .string .length (.loc 3) []) []
        (Store.empty.set 3 (.builder (.string "あ")))) =
    some (none, .run (.ret (.const (.integer ⟨3, by decide⟩))) []
      ((Store.empty.set 3 (.builder (.string "あ"))).set 3 (.builder (.string "あ")))) := rfl

/-- appendAll は要素のソース順を保つ。 -/
theorem string_appendAll :
    step P B (fun _ _ _ _ => .val (.const .unit)) (fun _ => none) (fun _ => 0)
      (.run (.builderOp .string .appendAll (.loc 3)
        [.list [.const (.string "あ"), .const (.string "b")]]) []
        (Store.empty.set 3 (.builder (.string "a")))) =
    some (none, .run (.ret (.const .unit)) []
      ((Store.empty.set 3 (.builder (.string "a"))).set 3 (.builder (.string "aあb")))) := rfl

/-- List の追記も要素を逆転しない。 -/
theorem list_appendAll :
    step P B (fun _ _ _ _ => .val (.const .unit)) (fun _ => none) (fun _ => 0)
      (.run (.builderOp (.list (.base .byte)) .appendAll (.loc 3)
        [.list [.const (.byte 2), .const (.byte 3)]]) []
        (Store.empty.set 3 (.builder (.list (.base .byte) [.const (.byte 1)])))) =
    some (none, .run (.ret (.const .unit)) []
      ((Store.empty.set 3 (.builder (.list (.base .byte) [.const (.byte 1)]))).set 3
        (.builder (.list (.base .byte) [.const (.byte 1), .const (.byte 2), .const (.byte 3)])))) := rfl

/-- Byte の最大値は追記できる。 -/
theorem byte_append :
    step P B (fun _ _ _ _ => .val (.const .unit)) (fun _ => none) (fun _ => 0)
      (.run (.builderOp .bytes .append (.loc 3) [.const (.byte 255)]) []
        (Store.empty.set 3 (.builder (.bytes [0])))) =
    some (none, .run (.ret (.const .unit)) []
      ((Store.empty.set 3 (.builder (.bytes [0]))).set 3 (.builder (.bytes [0, 255])))) := rfl

/-- Nat の抽象 Byte の範囲外は、元のセル内容を保持して失敗する。 -/
theorem invalid_byte_atomic :
    step P B (fun _ _ _ _ => .val (.const .unit)) (fun _ => none) (fun _ => 0)
      (.run (.builderOp .bytes .append (.loc 3) [.const (.byte 256)]) []
        (Store.empty.set 3 (.builder (.bytes [7])))) =
    some (none, .error [rBuilderInvalidByte] [] (Store.empty.set 3 (.builder (.bytes [7])))) := rfl

/-- R0902 の分岐は、候補の大きさを検査してから元のストアのまま失敗へ進む。 -/
theorem overflow_atomic {kind op l args k σ c candidate}
    (hl : σ l = some (.builder c))
    (ha : builderApply op c args = some (builderCheckUpdate candidate))
    (hb : candidate.kind.limit < candidate.size) :
    Step P B (.run (.builderOp kind op (.loc l) args) k σ) none
      (.error [rValueTooLarge] k σ) := by
  rw [builderCheckUpdate_overflow hb] at ha
  exact .E_BuilderErr hl ha

/-- 通常の let を挟むと、後続の専用番号も一つずれる。 -/
def dedicatedProgram : Comp :=
  .builderLet .string (.letIn (.builderOp .string .append (.bound 0) [.const (.string "あ")])
    (.builderOp .string .copy (.bound 1) []))

theorem dedicatedProgram_typed {R} :
    HasTypeC P B StoreTy.empty [] [] R dedicatedProgram (.base .string) Eff.empty := by
  exact .C_BuilderLet trivial (.C_Let
    (.C_BuilderOp trivial (.bound rfl) (.cons .V_Const .nil))
    (.C_BuilderOp trivial (.bound rfl) .nil))

/-- 専用 new・通常 let・copy を通し、値と専用セルの内容を確認する。 -/
theorem dedicatedProgram_run :
    (match run P B (fun _ _ _ _ => .val (.const .unit)) (fun _ => none) (fun _ => 0) 5
        (.run dedicatedProgram [] Store.empty) [] with
      | (.run (.ret (.const (.string s))) [] σ, evs) => some (s, σ 0, evs)
      | _ => none) = some ("あ", some (.builder (.string "あ")), []) := rfl

/-- 実在するモデルで、この専用プログラムの全有限接頭辞を主定理へ接続する。 -/
theorem dedicatedProgram_prefixes {s}
    (hsteps : Steps Model.emptyProgram Model.builtins (.run dedicatedProgram [] Store.empty) s) :
    StateTy Model.emptyProgram Model.builtins s ∧ LocalStateInvariant Model.emptyProgram Model.builtins s ∧
      (∀ ev s', ¬ Step Model.emptyProgram Model.builtins s (some ev) s') := by
  have hc : dedicatedProgram.ClosedNoEffVars := by
    simp [dedicatedProgram, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Val.VarsInList, LocalRef.Scoped]
  have hinit := stateTyE_init Model.emptyProgram_wellFormed (Model.assumptions _) (dedicatedProgram_typed _ _) hc
  have hs := local_steps_invariant Model.emptyProgram_wellFormed Model.emptyProgram_wellTyped
    Model.emptyProgram_effectsOk (Model.assumptions _) (stateTy_iff.mpr ⟨_, builtinOnly_empty, hinit⟩) hsteps
  exact ⟨hs.1, hs.2, (effect_soundness Model.emptyProgram_wellFormed Model.emptyProgram_wellTyped
    Model.emptyProgram_effectsOk (Model.assumptions _) (dedicatedProgram_typed _ _) hc s hsteps).1⟩

/-- 捕捉した継続の外側と節の内側で、別々の専用セルを使う。 -/
def resumedProgram : Comp :=
  .handle
    (.builderLet .string
      (.letIn (.builderOp .string .append (.bound 0) [.const (.string "before")])
        (.letIn (.app (.op "ask" []) [])
          (.letIn (.builderOp .string .append (.bound 2) [.const (.string "after")])
            (.builderOp .string .copy (.bound 3) [])))))
    [.mk (.user "ask") 0 0
      (.builderLet .string
        (.letIn (.builderOp .string .append (.bound 0) [.const (.string "inside")])
          (.resume (.var 2) (.const (.integer ⟨7, by decide⟩)))))]

/-- 再開後も元のセルへ追記し、節のセルと混ぜず、解放事象を足さない。 -/
theorem resumedProgram_run :
    (match run Examples.program Examples.builtins Examples.oracle (fun _ => none) Examples.fresh 40
        (.run resumedProgram [] Store.empty) [] with
      | (.run (.ret (.const (.string s))) [] σ, evs) => some (s, σ 0, σ 1, σ 2, evs)
      | _ => none) = some ("beforeafter", some (.builder (.string "beforeafter")), some .used,
        some (.builder (.string "inside")), []) := rfl

/-- 実行場所の専用参照も通常のラムダへ捕捉できない。 -/
theorem dedicated_location_not_captured {Ψ Q C Γ l a}
    (h : HasTypeVQ P B Ψ Q C Γ
      (.lam [] [] (.builderOp .string .copy (.loc l) [])) a) : False := by
  have hf := builder_value_no_free_local h
  exact hf.1

/-- ラムダの内側で新しい構築器を作ることは許す。 -/
theorem dedicated_inside_lambda :
    HasTypeV P B StoreTy.empty [] [] (.lam [] [] dedicatedProgram)
      (.fn [] [] (.base .string) Eff.empty) := by
  refine .V_Lam (by simp [NamesWF]) (by simp [Ty.WF, Ty.WFList, NamesWF, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm]) ?_
  exact dedicatedProgram_typed P B

end Benitoite.Release.BuilderExamples
