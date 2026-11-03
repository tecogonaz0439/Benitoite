import Benitoite.Release.Refinement.StandardContracts

/-! # 同じ有限列と要素を保持する内部の安全な参照 -/
namespace Benitoite.Release.Refinement.StandardBodies
noncomputable section

/-- 範囲の証拠を受け、同じ列の同じ位置の値とその型を返す。 -/
theorem safeGet {P B Ψ Q C Γ Φ xs T} (i : Nat)
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs T) (inside : i < xs.length) :
    ∃ v, xs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v T := by
  exact ⟨xs[i], by simp [inside], typed.member (List.getElem_mem inside)⟩

/-- 非空の証拠を受け、元の先頭そのものを返す。 -/
theorem safeHead {P B Ψ Q C Γ Φ xs T}
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs T) (nonempty : xs ≠ []) :
    ∃ v, xs.head? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v T := by
  cases xs with
  | nil => exact False.elim (nonempty rfl)
  | cons x xs => exact ⟨x, rfl, typed.member (by simp)⟩

/-- 元の列を捨てず、別の同長の列の要素は別にその列から得る。 -/
theorem safeGet_equalLength {P B Ψ Q C Γ Φ xs ys T U} (i : Nat)
    (original : HasTypeEachQ P B Ψ Q C Γ Φ xs T)
    (other : HasTypeEachQ P B Ψ Q C Γ Φ ys U)
    (lengths : xs.length = ys.length) (inside : i < xs.length) :
    (∃ v, xs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v T) ∧
    (∃ w, ys[i]? = some w ∧ HasTypeVQ P B Ψ Q C Γ Φ w U) :=
  ⟨safeGet i original inside, safeGet i other (lengths ▸ inside)⟩

/-- 任意の表とプログラムで同じ core 本体を検査する代表。 -/
private def identity : StandardContracts.Row :=
  ⟨"Example.identity", [], 0, .param "value" (.base .unit) (.done (.base .unit) Eff.empty),
    some (.ret (.var 0)), .core, []⟩

private theorem identity_typed (P : Program) (B : Builtins) : identity.BodyTyped P B := by
  refine ⟨_, rfl, ?_, ?_, ?_, .param (.done (.C_Return (.V_Var rfl ?_)))⟩
  · exact ⟨rfl, by decide⟩
  · simp [identity, Def.tel, signatureTel, Tel.names, Tel.inputs, Tel.result, Tel.effect, Ty.HasKind, kindsTel, kindsEff, kindsList, TypeCtx.kinds, Eff.empty]
  · exact ⟨⟨trivial, trivial, trivial, rfl⟩, ⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩⟩
  · intro b t e h; cases h

example (P : Program) (B : Builtins) :
    ∃ d : Def, d.tel = identity.tel ∧ d.WellTyped P B := by
  obtain ⟨d, hd, typed⟩ := identity_typed P B
  exact ⟨d, StandardContracts.Row.definition_tel hd, typed⟩

/-- 二列の型が異なっても、先頭と同じ添字の要素をそれぞれの列から得る。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) :
    (∃ v, [Val.const (.integer ⟨7,by decide⟩), .const (.integer ⟨8,by decide⟩)].head? = some v ∧
      HasTypeVQ P B Ψ Q [] [] [] v (.base .integer)) ∧
    ((∃ v, [Val.const (.integer ⟨7,by decide⟩), .const (.integer ⟨8,by decide⟩)][1]? = some v ∧
      HasTypeVQ P B Ψ Q [] [] [] v (.base .integer)) ∧
     (∃ w, [Val.const (.boolean false), .const (.boolean true)][1]? = some w ∧
      HasTypeVQ P B Ψ Q [] [] [] w (.base .boolean))) := by
  have xs : HasTypeEachQ P B Ψ Q [] [] []
      [.const (.integer ⟨7,by decide⟩), .const (.integer ⟨8,by decide⟩)] (.base .integer) :=
    .cons (.V_Const trivial) (.cons (.V_Const trivial) .nil)
  have ys : HasTypeEachQ P B Ψ Q [] [] []
      [.const (.boolean false), .const (.boolean true)] (.base .boolean) :=
    .cons (.V_Const trivial) (.cons (.V_Const trivial) .nil)
  exact ⟨safeHead xs (by intro h; cases h), safeGet_equalLength 1 xs ys rfl (by decide)⟩

end
end Benitoite.Release.Refinement.StandardBodies
