import Benitoite.Release.Refinement.StandardModelNumericRows
import Benitoite.Release.Refinement.StandardModelOperatorRows
import Benitoite.Release.Refinement.StandardModelSubstitution

/-! # 合成表の全行の種類の分類と応答・効果・対象の条件

合成表の377行を種類で分け、純粋な361行（数値166・演算子109・文字列とコレクション79・範囲付きの
純粋な6と %List.getFront）の契約、IOと終了の10行の契約、参照と明示遅延の5行、発行の1行から、
`Builtins.ResponseAssumptions`・`TargetAgreement` と効果・形の欄を同じ表で組み立てる。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- 種類がpureの行は、四つの純粋な行の分類のいずれかに入る。 -/
theorem pure_classes (row : Primitive) (pure : row.signature.kind = .pure) :
    row.numeric = true ∨ row.operator = true ∨ row.collection = true ∨ row.scopePure = true := by
  cases row
  all_goals first
    | exact Or.inl rfl
    | exact Or.inr (Or.inl rfl)
    | exact Or.inr (Or.inr (Or.inl rfl))
    | exact Or.inr (Or.inr (Or.inr rfl))
    | (exfalso; revert pure; decide)

/-- 種類がpureの全行の全BuiltinArgsは、合成表のδで型付きの非exitの応答を持つ。 -/
theorem pure_rows (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (pure : row.signature.kind = .pure) : PureRow (program externals) row.name := by
  rcases pure_classes row pure with h | h | h | h
  · exact numeric_rows externals row h
  · exact operator_rows _ row h
  · exact collection_rows externals row h
  · exact scope_rows externals row h

set_option maxHeartbeats 4000000 in
/-- 種類がioかexitの行は、IOと終了の10行である。 -/
theorem io_classes (row : Primitive) (kind : row.signature.kind = .io ∨ row.signature.kind = .exit) :
    row.io = true := by
  cases row
  all_goals first
    | rfl
    | (exfalso; revert kind; decide)

/-- 行の出典の表がその行の名前でIO応答を持つなら、その行はIOと終了の10行である。 -/
theorem response_classes {row : Primitive} {ts es ws out obs}
    (h : row.provider.ioResponse row.name ts es ws out obs) : row.io = true := by
  cases row
  all_goals first
    | rfl
    | (exfalso; exact h)
    | (exfalso
       rcases h with ⟨op, _, hn, _⟩ | ⟨hn, _⟩ | ⟨hn, _⟩ | ⟨hn, _⟩
       · cases op <;> exact absurd hn (by decide)
       all_goals exact absurd hn (by decide))
    | (exfalso
       obtain ⟨hn, _⟩ := h
       exact absurd hn (by decide))

/-- 操作の効果を持つ行の種類は、io・exit・pathBasesである。 -/
theorem opEff_classes (row : Primitive) (h : row.signature.opEff ≠ none) :
    row.signature.kind = .io ∨ row.signature.kind = .exit ∨ row.signature.kind = .pathBases := by
  cases row
  all_goals first
    | exact Or.inl rfl
    | exact Or.inr (Or.inl rfl)
    | exact Or.inr (Or.inr rfl)
    | exact absurd rfl h

private theorem lookup_row {P b s} (lookup : (builtins P).sig b = some s) :
    ∃ row : Primitive, b = row.name ∧ s = row.signature := by
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b s).mp lookup
  exact ⟨row, rfl, rfl⟩

private theorem all_member (row : Primitive) : row ∈ Primitive.all := by
  obtain ⟨row', member, name, _⟩ := (builtins_lookup_iff (program []) row.name row.signature).mp
    (row_lookup _ row)
  have same := (primitive_lookup row).symm.trans (name ▸ primitive_lookup row')
  cases Option.some.inj same
  exact member

/-- 操作の効果 `l`（State以外）を持つ行は、合成表の効果の表の `l` の所属に入る。 -/
theorem effects_member (row : Primitive) {l : Benitoite.Release.EffName}
    (h : row.signature.opEff = some l) (state : l ≠ stateEff) :
    ∃ bs, effects l = some bs ∧ row.name ∈ bs := by
  have member : row ∈ Primitive.all.filter (fun r => r.signature.opEff == some l) :=
    List.mem_filter.mpr ⟨all_member row, by simp [h]⟩
  refine ⟨_, ?_, List.mem_map_of_mem member⟩
  have nonempty : (Primitive.all.filter (fun r => r.signature.opEff == some l)).isEmpty = false := by
    cases hrows : Primitive.all.filter (fun r => r.signature.opEff == some l)
    · rw [hrows] at member; cases member
    · rfl
  simp only [effects, state, nonempty, Bool.false_eq_true, ite_false]

/-- 効果の表の所属は、同じ効果を操作に持つio・exit・pathBasesの行の名前である。 -/
theorem effect_ops (P : Program) :
    ∀ l bs b, (builtins P).effects l = some bs → b ∈ bs →
      ∃ s, (builtins P).sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧
        s.opEff = some l := by
  intro l bs b hl hb
  change effects l = some bs at hl
  unfold effects at hl
  dsimp only at hl
  split at hl
  · cases Option.some.inj hl; cases hb
  · split at hl
    · cases hl
    · cases Option.some.inj hl
      obtain ⟨row, member, rfl⟩ := List.mem_map.mp hb
      have op : row.signature.opEff = some l := by simpa using (List.mem_filter.mp member).2
      exact ⟨row.signature, row_lookup P row, opEff_classes row (by simp [op]), op⟩

theorem state_effect (P : Program) : (builtins P).effects stateEff = some [] := by
  show effects stateEff = some []
  simp [effects]

/-- 合成表の純粋な行・IOの行・終了の行の応答の条件。 -/
theorem response_assumptions (externals : List (ExternalKey × ExternalDecl)) :
    (builtins (program externals)).ResponseAssumptions (program externals) where
  delta_typed := by
    intro Ψ b sg ts es rs ws a e lookup kind args
    obtain ⟨row, rfl, rfl⟩ := lookup_row lookup
    exact pure_rows externals row kind Ψ row.signature ts es rs ws a e lookup args
  io_typed := by
    intro Ψ b sg ts es rs ws a e out obs lookup kind args response
    obtain ⟨row, rfl, rfl⟩ := lookup_row lookup
    obtain ⟨typed, adequate, _⟩ := (io_rows externals row (io_classes row kind) Ψ row.signature ts es rs ws a e
      lookup args).1 out obs response
    exact ⟨typed, adequate⟩
  io_kind := by
    intro Ψ b sg ts es rs ws a e out obs lookup args response
    obtain ⟨row, rfl, rfl⟩ := lookup_row lookup
    have io : row.io = true := by
      obtain ⟨r, found, hr⟩ := response
      cases Option.some.inj (found.symm.trans (primitive_lookup row))
      exact response_classes hr
    exact ((io_rows externals row io Ψ row.signature ts es rs ws a e lookup args).1 out obs response).2.2.1
  io_exists := by
    intro Ψ b sg ts es rs ws a e lookup kind args
    obtain ⟨row, rfl, rfl⟩ := lookup_row lookup
    exact (io_rows externals row (io_classes row kind) Ψ row.signature ts es rs ws a e lookup args).2

/-- 合成表の全IO応答は、署名の形の対象の条件を満たす。 -/
theorem target_agreement (externals : List (ExternalKey × ExternalDecl)) :
    (builtins (program externals)).TargetAgreement (program externals) where
  io_target := by
    intro Ψ b sg ts es rs ws a e out obs lookup kind args response
    obtain ⟨row, rfl, rfl⟩ := lookup_row lookup
    exact ((io_rows externals row (io_classes row kind) Ψ row.signature ts es rs ws a e lookup args).1
      out obs response).2.2.2

end
end Benitoite.Release.Refinement.StandardModel
