import Benitoite.Release.Refinement.Step

/-!
# 通常の match と handle による Result の変換の有限遷移

核の通常の照合と非再開の節で、Result の値の取り出しと失敗の Result への変換を、成功と失敗の四つの有限遷移で示す。
捕捉の後は、破棄した保存継続のセルが使用済みになる（設計書 01-12「実行の規則」）。
-/
namespace Benitoite.Release.Refinement.FailureExamples
noncomputable section

private def intTy : Ty := .base .integer
private def strTy : Ty := .base .string
private def seven : Val := .const (.integer ⟨7, by decide⟩)
private def okValue (v : Val) : Val := .con "Result.Ok" [intTy, strTy] [v]
private def errorValue (v : Val) : Val := .con "Result.Error" [intTy, strTy] [v]

private def fromResult (v : Val) : Comp :=
  .match v
    [.mk [⟨.con "Result.Ok" [.var], [0]⟩] none (.ret (.var 0)),
     .mk [⟨.con "Result.Error" [.var], [0]⟩] none (.app (.raise intTy strTy) [.var 0])]

private def failClause : List Clause := [.fail strTy (.ret (errorValue (.var 1)))]
private def toResult (body : Comp) : Comp := .handle (.letIn body (.ret (okValue (.var 0)))) failClause

private def bad : Val := .const (.string "bad")

/-- 成功の値の照合は、最初の腕で中身を取り出す。 -/
theorem fromResult_ok (P : Program) (B : Builtins) (σ : PathEnv) :
    Steps P B σ (.run (Closure.pure (fromResult (okValue seven))) [] Store.empty) []
      (.run (Closure.mk (Capture.empty.extendMany [seven]) (.ret (.var 0))) [] Store.empty) :=
  .cons (.E_Match rfl) (.cons (.E_MatchBody (next := 0) rfl rfl) .nil)

/-- 失敗の値の照合は、最初の腕を飛ばし、二つ目の腕で同じ値を raise する。 -/
theorem fromResult_error (P : Program) (B : Builtins) (σ : PathEnv) :
    Steps P B σ (.run (Closure.pure (fromResult (errorValue bad))) [] Store.empty) []
      (.run (Closure.mk (Capture.empty.extendMany [bad]) (.app (.raise intTy strTy) [.var 0])) [] Store.empty) :=
  .cons (.E_Match rfl) (.cons (.E_MatchSkip (next := 0) rfl rfl) (.cons (.E_MatchBody (next := 1) rfl rfl) .nil))

/-- 正常に返る本体は、節を使わず成功の値になる。 -/
theorem toResult_return (P : Program) (B : Builtins) (σ : PathEnv) :
    Steps P B σ (.run (Closure.pure (toResult (.ret seven))) [] Store.empty) []
      (.run (Closure.pure (.ret (okValue seven))) [] Store.empty) :=
  .cons (.E_Handle rfl) (.cons (.E_Let rfl) (.cons (.E_Return rfl) (.cons (.E_HRet rfl) .nil)))

/-- raise する本体は、非再開の節で失敗の値になり、破棄した保存継続のセルは使用済みになる。 -/
theorem toResult_raise (P : Program) (B : Builtins) (σ : PathEnv) :
    ∃ μ, Steps P B σ (.run (Closure.pure (toResult (.app (.raise intTy strTy) [bad]))) [] Store.empty) []
      (.run (Closure.pure (.ret (errorValue bad))) [] μ) ∧ μ 0 = some .used :=
  ⟨_, .cons (.E_Handle rfl) (.cons (.E_Let rfl)
    (.cons (.E_OpFail (κ := 0) (k1 := [.letF (Closure.mk Capture.empty (.ret (okValue (.var 0))))]) (k2 := [])
      rfl ⟨rfl, rfl, by simp [NoHandler]⟩ rfl) (.cons (.E_DropRel rfl rfl) .nil))),
    by simp [Store.set]⟩

end
end Benitoite.Release.Refinement.FailureExamples
