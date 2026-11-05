import Benitoite.Release.Refinement.StandardModelScoped
import Benitoite.Release.Refinement.StandardModelProgram

/-! # 合成表の全28欄の条件と対象の条件

合成プログラムと合成表について、`Builtins.CoreAssumptions` の全28欄（置換の8・外部の3・応答の4・
独自の13）と、別の構造体の `TargetAgreement` の1欄を、同じ表の行の証拠から組み立てる。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- IOと終了の全行は、効果の表と同じ効果の所属・範囲の形を持つ。 -/
theorem io_op (P : Program) :
    ∀ b s, (builtins P).sig b = some s → (s.kind = .io ∨ s.kind = .exit) → (builtins P).ShapeOk b s := by
  intro b s lookup kind
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b s).mp lookup
  have io := io_classes row kind
  cases row
  case p157 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p157 (l := "File.Write") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩
  case p158 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p158 (l := "File.Write") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩
  case p159 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p159 (l := "File.Read") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩
  case p160 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p160 (l := "File.Read") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl⟩
  case p161 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p161 (l := "File.Read") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩
  case p162 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p162 (l := "File.Write") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩
  case p163 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p163 (l := "File.Write") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl, "Scope.PathIn", rfl, rfl⟩
  case p187 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p187 (l := "Http.Connect") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl, "Http.RequestIn", rfl, rfl⟩
  case p372 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p372 (l := "Process.Exit") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl⟩
  case p373 =>
    obtain ⟨bs, hb, hm⟩ := effects_member .p373 (l := "Console.Write") rfl (by decide)
    exact ⟨_, bs, rfl, rfl, hb, hm, rfl, rfl, rfl⟩
  all_goals cases io

/-- 発行の種類の行は、Example.pathBasesの一行で、発行の八欄とEnvironmentの所属を持つ。 -/
theorem pathBases_shape (P : Program) :
    ∀ b s, (builtins P).sig b = some s → s.kind = .pathBases → s.PathBasesShape (builtins P) b := by
  intro b s lookup kind
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b s).mp lookup
  cases row
  all_goals first
    | (exfalso; revert kind; decide)
    | (obtain ⟨bs, hb, hm⟩ := effects_member .p156 (l := "Process.Environment") rfl (by decide)
       exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, bs, hb, hm⟩)

/-- 操作の効果を持つ署名の種類は、io・exit・pathBasesである。 -/
theorem opEff_io (P : Program) :
    ∀ b s l, (builtins P).sig b = some s → s.opEff = some l →
      s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases := by
  intro b s l lookup op
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b s).mp lookup
  exact opEff_classes row (by simp [op])

/-- 参照と明示遅延の行の許容は、型引数の個数だけを読む。 -/
theorem store_admits (P : Program) :
    ∀ b s C ts, (builtins P).sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
      s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts := by
  intro b s C ts lookup pure io exit issue count
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b s).mp lookup
  cases row
  all_goals first
    | exact count
    | exact absurd rfl pure
    | exact absurd rfl io
    | exact absurd rfl exit
    | exact absurd rfl issue

/-- 型付きの全資源値について、合成表の解放の関係は応答を持つ。 -/
theorem release_exists (P : Program) :
    ∀ Ψ v o, HasTypeV P (builtins P) Ψ [] [] [] v (.opaque o (.fixed .top)) →
      (builtins P).isResource o = true → ∃ r, (builtins P).releaseResponse v r :=
  fun Ψ v o typed resource => ⟨none, release_all P Ψ v o typed resource none⟩

/-- 合成プログラムと合成表は、任意の外部宣言について全28欄の条件を満たす。 -/
theorem core (externals : List (ExternalKey × ExternalDecl)) :
    Builtins.CoreAssumptions (program externals) (builtins (program externals)) where
  toSubstitutionAssumptions := substitution_assumptions _
  toExternalAssumptions := external_assumptions _
  toResponseAssumptions := response_assumptions externals
  sig_scoped := sig_scoped externals
  sat_unconstrained := fun _ _ => ModelConstraints.sat_unconstrained _ _ _
  admits_sat := admits_sat _
  release_exists := release_exists _
  pathBases_shape := pathBases_shape _
  io_op := io_op _
  opEff_io := opEff_io _
  effect_ops := effect_ops _
  state_effect := state_effect _
  ref_get := ref_get _
  ref_set := ref_set _
  store_shape := store_shape _
  store_admits := store_admits _

/-- 合成表の全IO応答は、署名の形の対象の条件を満たす。 -/
theorem targets (externals : List (ExternalKey × ExternalDecl)) :
    Builtins.TargetAgreement (program externals) (builtins (program externals)) :=
  target_agreement externals

/-- 外部宣言の構造検証を受け取る形からも、同じ全28欄と対象の条件を得る。 -/
example (externals : List (ExternalKey × ExternalDecl)) (_hw : (program externals).ExternalWF) :
    Builtins.CoreAssumptions (program externals) (builtins (program externals)) ∧
      Builtins.TargetAgreement (program externals) (builtins (program externals)) :=
  ⟨core externals, targets externals⟩

end
end Benitoite.Release.Refinement.StandardModel
