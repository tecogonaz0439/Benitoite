import Benitoite.Release.Refinement.ExternalModels
import Benitoite.Release.Refinement.StandardModelResponse
import Benitoite.Release.Refinement.StepLeafSelection

/-! # 通常資源の解放の関係と、解放の枠の八つの遷移・選択

解放応答に `ResourceRelease.response` を持つ表では、型付きの解放の枠の値は資源のopaque定数であり、
成功と全ての失敗の結果の両方が同じ関係に属する。ret・escape・error・exitの四つの開始の
成功・失敗の八つの遷移と、実行関数が選ぶ解放結果をこの関係から供給する。外部ハンドルは
通常資源に含めない。 -/
namespace Benitoite.Release.Refinement
noncomputable section

namespace ResourceRelease

/-- 解放応答がこの関係であり、資源名を対象の値型へ分類しない表。 -/
structure Table (B : Builtins) : Prop where
  release : B.releaseResponse = response B.isResource
  classification : ∀ name, B.isResource name = true → B.valKind name = none

/-- 任意のΨ・v・oで、型付き資源値は成功と全ての失敗のどの結果にも関係を満たす。 -/
theorem Table.release_all {P B Ψ v o} (table : Table B)
    (typed : HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)))
    (resource : B.isResource o = true) (r : Option Benitoite.Release.ErrKind) :
    B.releaseResponse v r := by
  rw [table.release]
  exact typed_response table.classification typed resource r

/-- CoreAssumptionsのrelease_existsと同じ量化で、成功の結果を証人に取る。 -/
theorem Table.release_exists {P B} (table : Table B) :
    ∀ Ψ v o, HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) →
      B.isResource o = true → ∃ r, B.releaseResponse v r :=
  fun _ _ _ typed resource => ⟨none, table.release_all typed resource none⟩

/-- 関係に属する値は、資源に分類した名前のopaque定数に限る。 -/
theorem Table.release_value {B v r} (table : Table B) (h : B.releaseResponse v r) :
    ∃ o i, v = .const (.opaque o i) ∧ B.isResource o = true := by
  rw [table.release] at h
  exact h

end ResourceRelease

namespace ExternalModels

/-- 三表の資源名は、TargetsのFile.Handleだけである。 -/
theorem ModelCase.resource_iff (m : ModelCase) (P : Program) (o : Benitoite.Release.OpaqueName) :
    (m.table P).isResource o = true ↔ m = .targets ∧ o = "File.Handle" := by
  cases m with
  | model => exact ⟨fun h => Bool.noConfusion h, fun h => nomatch h.1⟩
  | http => exact ⟨fun h => Bool.noConfusion h, fun h => nomatch h.1⟩
  | targets =>
    change (o == "File.Handle") = true ↔ _
    simp

/-- 三表は同じ解放の関係を持ち、資源名を対象の値型へ分類しない。 -/
theorem ModelCase.resource_table (m : ModelCase) (P : Program) :
    ResourceRelease.Table (m.table P) := by
  refine ⟨by cases m <;> rfl, ?_⟩
  intro name resource
  obtain ⟨rfl, rfl⟩ := (m.resource_iff P name).mp resource
  rfl

/-- 三表の解放欄を、成功と全ての失敗の結果で読む。 -/
theorem ModelCase.release_all (m : ModelCase) (P : Program) :
    ∀ Ψ v o, HasTypeV P (m.table P) Ψ [] [] [] v (.opaque o (.fixed .top)) →
      (m.table P).isResource o = true → ∀ r, (m.table P).releaseResponse v r :=
  fun _ _ _ typed resource r => (m.resource_table P).release_all typed resource r

/-- ModelとHttpでは、解放欄の資源の前提がFalseになる。 -/
theorem ModelCase.release_premise_false (m : ModelCase) (hm : m ≠ .targets) (P : Program)
    (o : Benitoite.Release.OpaqueName) : (m.table P).isResource o ≠ true :=
  fun h => hm ((m.resource_iff P o).mp h).1

/-- 任意のP・Ψ・番号で、Targetsの型付きFile.Handle定数は解放欄の前提を満たす。 -/
theorem targets_resource_input (P : Program) (Ψ : StoreTy) (i : Nat) :
    HasTypeV P (targets P) Ψ [] [] [] (.const (.opaque "File.Handle" i))
      (.opaque "File.Handle" (.fixed .top)) ∧ (targets P).isResource "File.Handle" = true :=
  ⟨.V_Const ⟨rfl, rfl⟩, rfl⟩

/-- Targetsの型付き資源の解放は、成功と任意の失敗の両方を許し、整数と外部ハンドルを断る。 -/
example (P : Program) (Ψ : StoreTy) (i : Nat) (r : Benitoite.Release.ErrKind) (h : ExternalHandle)
    (ts : List Ty) :
    (targets P).releaseResponse (.const (.opaque "File.Handle" i)) none ∧
    (targets P).releaseResponse (.const (.opaque "File.Handle" i)) (some r) ∧
    ¬ (targets P).releaseResponse (.const (.integer8 0)) none ∧
    ¬ (targets P).releaseResponse (.externalHandle h ts) (some r) := by
  have input := targets_resource_input P Ψ i
  have all := ModelCase.release_all .targets P Ψ _ _ input.1 input.2
  refine ⟨all none, all (some r), ?_, ?_⟩
  · intro hr
    obtain ⟨o, j, hv, _⟩ := (ModelCase.resource_table .targets P).release_value hr
    cases hv
  · intro hr
    obtain ⟨o, j, hv, _⟩ := (ModelCase.resource_table .targets P).release_value hr
    cases hv

/-- ModelとHttpの解放欄は、前提の否定で閉じる。 -/
example (P : Program) (o : Benitoite.Release.OpaqueName) :
    (ModelCase.model.table P).isResource o ≠ true ∧ (ModelCase.http.table P).isResource o ≠ true :=
  ⟨ModelCase.release_premise_false .model (by intro h; cases h) P o,
   ModelCase.release_premise_false .http (by intro h; cases h) P o⟩

end ExternalModels

namespace StandardModel

/-- 合成表は通常資源の関係を持ち、唯一の資源名File.Handleを対象の値型へ分類しない。 -/
theorem resource_table (P : Program) : ResourceRelease.Table (builtins P) := by
  refine ⟨rfl, ?_⟩
  intro name resource
  obtain rfl := (resource_iff P name).mp resource
  rfl

/-- 任意のP・Ψ・番号で、合成表の型付きFile.Handle定数は解放の前提を満たす。 -/
theorem resource_input (P : Program) (Ψ : StoreTy) (i : Nat) :
    HasTypeV P (builtins P) Ψ [] [] [] (.const (.opaque "File.Handle" i))
      (.opaque "File.Handle" (.fixed .top)) ∧ (builtins P).isResource "File.Handle" = true :=
  ⟨.V_Const ⟨rfl, rfl⟩, rfl⟩

/-- 合成表の解放欄は、任意の型付き資源値に成功と全ての失敗の結果を与える。 -/
theorem release_all (P : Program) :
    ∀ Ψ v o, HasTypeV P (builtins P) Ψ [] [] [] v (.opaque o (.fixed .top)) →
      (builtins P).isResource o = true → ∀ r, (builtins P).releaseResponse v r :=
  fun _ _ _ typed resource r => (resource_table P).release_all typed resource r

/-- 参照と明示遅延の種類を持つ合成表の行は、Reference.getとReference.setの二行だけである。 -/
theorem Primitive.store_rows (row : Primitive)
    (hk : row.signature.kind = .refNew ∨ row.signature.kind = .refGet ∨
      row.signature.kind = .refSet ∨ row.signature.kind = .refUpdate ∨
      row.signature.kind = .force) :
    row = .p279 ∨ row = .p280 := by
  cases row
  all_goals first
    | exact Or.inl rfl
    | exact Or.inr rfl
    | (exfalso; revert hk; decide)

/-- 参照と明示遅延の種類を持つ合成表の全lookupは、ModelTargetsの同じ署名の行である。 -/
theorem store_lookup {P b s} (lookup : (builtins P).sig b = some s)
    (hk : s.kind = .refNew ∨ s.kind = .refGet ∨ s.kind = .refSet ∨ s.kind = .refUpdate ∨
      s.kind = .force) :
    (b = "Reference.get" ∨ b = "Reference.set") ∧ ModelTargets.builtins.sig b = some s := by
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff P b s).mp lookup
  rcases Primitive.store_rows row hk with rfl | rfl
  · exact ⟨Or.inl rfl, rfl⟩
  · exact ⟨Or.inr rfl, rfl⟩

/-- 合成表はReference.newとReference.updateとLazy.forceの種類の行を持たない。 -/
theorem no_store_transitions {P b s} (lookup : (builtins P).sig b = some s) :
    s.kind ≠ .refNew ∧ s.kind ≠ .refUpdate ∧ s.kind ≠ .force := by
  refine ⟨fun hk => ?_, fun hk => ?_, fun hk => ?_⟩
  all_goals
    obtain ⟨hb, same⟩ := store_lookup lookup (by simp [hk])
    rcases hb with rfl | rfl
    all_goals
      have := Option.some.inj (same.symm.trans rfl)
      subst this
      cases hk

/-- 合成表の全lookupで、PathBases以外の種類の署名は参照と明示遅延の形を満たす。 -/
theorem store_shape (P : Program) :
    ∀ b s, (builtins P).sig b = some s → s.kind ≠ .pathBases → s.StoreShape := by
  intro b s lookup hk
  cases kind : s.kind
  case pathBases => exact (hk kind).elim
  case pure | io | exit => simp only [PrimSig.StoreShape, kind]
  all_goals
    exact ModelTargets.store_shape (store_lookup lookup (by simp [kind])).2 hk

/-- 合成表は台帳の各行の名前でその行の署名を返す。 -/
theorem row_lookup (P : Program) (row : Primitive) :
    (builtins P).sig row.name = some row.signature := by
  show signature row.name = _
  rw [signature, primitive_lookup]
  rfl

/-- 合成表のReferenceの取得・設定の名前は、それぞれの種類の署名へ解決する。 -/
theorem ref_get (P : Program) :
    ∃ s, (builtins P).sig (builtins P).refGet = some s ∧ s.kind = .refGet :=
  ⟨_, row_lookup P .p279, rfl⟩

theorem ref_set (P : Program) :
    ∃ s, (builtins P).sig (builtins P).refSet = some s ∧ s.kind = .refSet :=
  ⟨_, row_lookup P .p280, rfl⟩

/-- 合成する二つのReferenceの行は、型引数の種類が[value]で、元の依存列が宣言した行に収まり、
操作の効果を持たない。 -/
theorem reference_rows {P b s} (lookup : (builtins P).sig b = some s)
    (hk : s.kind = .refGet ∨ s.kind = .refSet) :
    s.StoreShape ∧ s.tparams.map TParamDecl.kind = [.value] ∧ s.tel.RowsIn (· < s.neffs) ∧
      s.opEff = none := by
  have store : s.kind = .refNew ∨ s.kind = .refGet ∨ s.kind = .refSet ∨ s.kind = .refUpdate ∨
      s.kind = .force := by
    rcases hk with hk | hk <;> simp [hk]
  obtain ⟨hb, same⟩ := store_lookup lookup store
  have shape := ModelTargets.store_shape same (by rcases hk with hk | hk <;> simp [hk])
  refine ⟨shape, ?_, shape.sourceTelRows store, ?_⟩
  · rcases hk with hk | hk <;> simp only [PrimSig.StoreShape, hk] at shape <;> exact shape.2.2.2.2.2.2.2
  · rcases hb with rfl | rfl <;> cases Option.some.inj (same.symm.trans rfl) <;> rfl

/-- 合成表のFile.Handleの解放と、Reference.getの行の形・名前の解決・種類の除外を読む。 -/
example (P : Program) (Ψ : StoreTy) (r : Benitoite.Release.ErrKind) :
    ((builtins P).releaseResponse (.const (.opaque "File.Handle" 0)) none ∧
      (builtins P).releaseResponse (.const (.opaque "File.Handle" 0)) (some r)) ∧
    (Primitive.p279.signature.StoreShape ∧ Primitive.p279.signature.tparams.map TParamDecl.kind = [.value] ∧
      Primitive.p279.signature.kind ≠ .refNew) ∧
    (∃ s, (builtins P).sig (builtins P).refGet = some s ∧ s.kind = .refGet) ∧
    (∃ s, (builtins P).sig (builtins P).refSet = some s ∧ s.kind = .refSet) := by
  have input := resource_input P Ψ 0
  have all := release_all P Ψ _ _ input.1 input.2
  have lookup := row_lookup P .p279
  have rows := reference_rows lookup (Or.inl rfl)
  exact ⟨⟨all none, all (some r)⟩,
    ⟨store_shape P _ _ lookup (by decide), rows.2.1, (no_store_transitions lookup).1⟩,
    ref_get P, ref_set P⟩

end StandardModel

/-- 解放の枠の値は、型付きの資源のopaque値である。 -/
theorem ContTy.release_resource {P B σ Ψ R e k a b Eb Re v}
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) :
    ∃ o, HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) ∧ B.isResource o = true := by
  generalize hh : (.release v :: k) = frames at h
  induction h with
  | K_Release hv _ hr _ _ => cases hh; exact ⟨_, hv, hr⟩
  | K_Sub _ _ ih => exact ih hh
  | _ => cases hh

/-- 通常資源の関係を持つ表では、解放の枠の値は成功と全ての失敗の結果で関係を満たす。 -/
theorem ContTy.release_all {P B σ Ψ R e k a b Eb Re v} (table : ResourceRelease.Table B)
    (h : ContTy P B σ Ψ R e (.release v :: k) a b Eb Re) (r : Option Benitoite.Release.ErrKind) :
    B.releaseResponse v r := by
  obtain ⟨_, typed, resource⟩ := h.release_resource
  exact table.release_all typed resource r

/-- 通常資源の関係を持つ表では、型付きの解放の枠は外部ハンドルを持たない。 -/
theorem ContTy.release_not_external {P B σ Ψ R e k a b Eb Re h ts} (table : ResourceRelease.Table B)
    (frames : ContTy P B σ Ψ R e (.release (.externalHandle h ts) :: k) a b Eb Re) : False := by
  obtain ⟨o, typed, resource⟩ := frames.release_resource
  obtain ⟨_, hv⟩ := ResourceRelease.canonical typed (table.classification o resource)
  cases hv

private theorem run_release_all {P B σ Eb q v k μ} (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ)) (r : Option Benitoite.Release.ErrKind) :
    B.releaseResponse v r := by
  obtain ⟨_, _, _, _, _, _, _, _, _, hk, _⟩ := h
  exact hk.release_all table r

private theorem error_release_all {P B σ Eb rs v k μ} (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.error rs (.release v :: k) μ)) (r : Option Benitoite.Release.ErrKind) :
    B.releaseResponse v r := by
  obtain ⟨_, _, _, _, _, _, hk, _⟩ := h
  exact hk.release_all table r

private theorem exit_release_all {P B σ Eb n rs v k μ} (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.exit n rs (.release v :: k) μ)) (r : Option Benitoite.Release.ErrKind) :
    B.releaseResponse v r := by
  obtain ⟨_, _, _, _, _, _, hk, _⟩ := h
  exact hk.release_all table r

/-- useの開始は解放の枠を積み、その値は成功と全ての失敗の結果で関係を満たす。 -/
theorem StateTyE.use_release_all {P B σ Eb q v m k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .use v m) :
    (Step P B σ (.run q k μ) none (.run (.mk q.capture m) (.release v :: k) μ) ∧
      StateTyE P B σ Eb (.run (.mk q.capture m) (.release v :: k) μ)) ∧
    ∀ r, B.releaseResponse v r := by
  have next := h.use_all hP hPB hB hv
  exact ⟨next, run_release_all table next.2⟩

/-- retの開始で、成功の解放と全ての失敗の解放がともに遷移し、型付けを保つ。 -/
theorem StateTyE.release_return_all {P B σ Eb q w v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ)) (hv : q.view = .ret w) :
    (Step P B σ (.run q (.release v :: k) μ) (some (.release v none))
        (.run (Closure.pure (.ret w)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.ret w)) k μ)) ∧
    ∀ r, Step P B σ (.run q (.release v :: k) μ) (some (.release v (some r))) (.error [r] k μ) ∧
      StateTyE P B σ Eb (.error [r] k μ) :=
  ⟨h.return_release hP hPB hB hv (run_release_all table h none),
   fun _ => h.return_release_failure hv (run_release_all table h _)⟩

/-- escapeの開始で、成功の解放と全ての失敗の解放がともに遷移し、型付けを保つ。 -/
theorem StateTyE.release_escape_all {P B σ Eb q w v k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ)) (hv : q.view = .escape w) :
    (Step P B σ (.run q (.release v :: k) μ) (some (.release v none))
        (.run (Closure.pure (.escape w)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.escape w)) k μ)) ∧
    ∀ r, Step P B σ (.run q (.release v :: k) μ) (some (.release v (some r))) (.error [r] k μ) ∧
      StateTyE P B σ Eb (.error [r] k μ) :=
  ⟨h.escape_release hP hPB hB hv (run_release_all table h none),
   fun _ => h.escape_release_failure hv (run_release_all table h _)⟩

/-- errorの開始で、成功の解放と全ての失敗の解放がともに遷移し、型付けを保つ。 -/
theorem StateTyE.release_error_all {P B σ Eb rs v k μ} (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.error rs (.release v :: k) μ)) :
    (Step P B σ (.error rs (.release v :: k) μ) (some (.release v none)) (.error rs k μ) ∧
      StateTyE P B σ Eb (.error rs k μ)) ∧
    ∀ r, Step P B σ (.error rs (.release v :: k) μ) (some (.release v (some r)))
        (.error (rs ++ [r]) k μ) ∧ StateTyE P B σ Eb (.error (rs ++ [r]) k μ) :=
  ⟨h.error_release (error_release_all table h none),
   fun _ => h.error_release_failure (error_release_all table h _)⟩

/-- exitの開始で、成功の解放と全ての失敗の解放がともに遷移し、型付けを保つ。 -/
theorem StateTyE.release_exit_all {P B σ Eb n rs v k μ} (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.exit n rs (.release v :: k) μ)) :
    (Step P B σ (.exit n rs (.release v :: k) μ) (some (.release v none)) (.exit n rs k μ) ∧
      StateTyE P B σ Eb (.exit n rs k μ)) ∧
    ∀ r, Step P B σ (.exit n rs (.release v :: k) μ) (some (.release v (some r)))
        (.exit n (rs ++ [r]) k μ) ∧ StateTyE P B σ Eb (.exit n (rs ++ [r]) k μ) :=
  ⟨h.exit_release (exit_release_all table h none),
   fun _ => h.exit_release_failure (exit_release_all table h _)⟩

/-- retとescapeの開始で、実行関数が選ぶ解放結果は同じ関係に属し、同じ遷移と型付けを持つ。 -/
theorem StateTyE.release_selected_run {P B σ Eb oracle externalOracle fresh q w v k μ}
    {escape : Bool}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (table : ResourceRelease.Table B)
    (h : StateTyE P B σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = if escape then .escape w else .ret w) :
    B.releaseResponse v (B.selectRelease v) ∧
    ∃ dest, step P B σ oracle externalOracle B.selectRelease fresh (.run q (.release v :: k) μ) =
        some (some (.release v (B.selectRelease v)), dest) ∧
      Step P B σ (.run q (.release v :: k) μ) (some (.release v (B.selectRelease v))) dest ∧
      StateTyE P B σ Eb dest := by
  have exists_result : ∃ result, B.releaseResponse v result := ⟨none, run_release_all table h none⟩
  obtain ⟨computed, related⟩ := step_release_selected (P := P) (σ := σ) (oracle := oracle)
    (externalOracle := externalOracle) (fresh := fresh) (k := k) (μ := μ) hv exists_result
  refine ⟨Builtins.selectRelease_response exists_result, _, computed, related, ?_⟩
  cases escape <;> simp only [Bool.false_eq_true, ite_false, ite_true] at hv
  all_goals cases selected : B.selectRelease v
  · exact (h.release_return_all hP hPB hB table hv).1.2
  · exact ((h.release_return_all hP hPB hB table hv).2 _).2
  · exact (h.release_escape_all hP hPB hB table hv).1.2
  · exact ((h.release_escape_all hP hPB hB table hv).2 _).2

/-- errorの開始で、実行関数が選ぶ解放結果は同じ関係に属し、同じ遷移と型付けを持つ。 -/
theorem StateTyE.release_selected_error {P B σ Eb oracle externalOracle fresh rs v k μ}
    (table : ResourceRelease.Table B) (h : StateTyE P B σ Eb (.error rs (.release v :: k) μ)) :
    B.releaseResponse v (B.selectRelease v) ∧
    ∃ dest, step P B σ oracle externalOracle B.selectRelease fresh (.error rs (.release v :: k) μ) =
        some (some (.release v (B.selectRelease v)), dest) ∧
      Step P B σ (.error rs (.release v :: k) μ) (some (.release v (B.selectRelease v))) dest ∧
      StateTyE P B σ Eb dest := by
  refine ⟨error_release_all table h _, ?_⟩
  have leaves := h.release_error_all table
  cases selected : B.selectRelease v with
  | none =>
    exact ⟨_, by show releaseStep _ v _ _ = _; simp only [releaseStep, selected], leaves.1⟩
  | some r =>
    exact ⟨_, by show releaseStep _ v _ _ = _; simp only [releaseStep, selected], leaves.2 r⟩

/-- exitの開始で、実行関数が選ぶ解放結果は同じ関係に属し、同じ遷移と型付けを持つ。 -/
theorem StateTyE.release_selected_exit {P B σ Eb oracle externalOracle fresh n rs v k μ}
    (table : ResourceRelease.Table B) (h : StateTyE P B σ Eb (.exit n rs (.release v :: k) μ)) :
    B.releaseResponse v (B.selectRelease v) ∧
    ∃ dest, step P B σ oracle externalOracle B.selectRelease fresh (.exit n rs (.release v :: k) μ) =
        some (some (.release v (B.selectRelease v)), dest) ∧
      Step P B σ (.exit n rs (.release v :: k) μ) (some (.release v (B.selectRelease v))) dest ∧
      StateTyE P B σ Eb dest := by
  refine ⟨exit_release_all table h _, ?_⟩
  have leaves := h.release_exit_all table
  cases selected : B.selectRelease v with
  | none =>
    exact ⟨_, by show releaseStep _ v _ _ = _; simp only [releaseStep, selected], leaves.1⟩
  | some r =>
    exact ⟨_, by show releaseStep _ v _ _ = _; simp only [releaseStep, selected], leaves.2 r⟩

/-- Targetsの表で、四つの開始の選択の葉を同じ関係から読む。 -/
example (P : Program) (hp : ScopeDeclarations.HasFile P) (hP : P.WellFormed)
    (hPB : P.WellTyped (ExternalModels.targets P)) {σ Eb oracle externalOracle fresh q w v k μ rs n}
    {escape : Bool}
    (run : StateTyE P (ExternalModels.targets P) σ Eb (.run q (.release v :: k) μ))
    (hv : q.view = if escape then .escape w else .ret w)
    (error : StateTyE P (ExternalModels.targets P) σ Eb (.error rs (.release v :: k) μ))
    (exit : StateTyE P (ExternalModels.targets P) σ Eb (.exit n rs (.release v :: k) μ)) :
    (∃ dest, step P (ExternalModels.targets P) σ oracle externalOracle
        (ExternalModels.targets P).selectRelease fresh (.run q (.release v :: k) μ) =
        some (some (.release v ((ExternalModels.targets P).selectRelease v)), dest) ∧
      StateTyE P (ExternalModels.targets P) σ Eb dest) ∧
    (∃ dest, step P (ExternalModels.targets P) σ oracle externalOracle
        (ExternalModels.targets P).selectRelease fresh (.error rs (.release v :: k) μ) =
        some (some (.release v ((ExternalModels.targets P).selectRelease v)), dest) ∧
      StateTyE P (ExternalModels.targets P) σ Eb dest) ∧
    (∃ dest, step P (ExternalModels.targets P) σ oracle externalOracle
        (ExternalModels.targets P).selectRelease fresh (.exit n rs (.release v :: k) μ) =
        some (some (.release v ((ExternalModels.targets P).selectRelease v)), dest) ∧
      StateTyE P (ExternalModels.targets P) σ Eb dest) := by
  have table := ExternalModels.ModelCase.resource_table .targets P
  obtain ⟨_, d1, s1, _, t1⟩ := run.release_selected_run (oracle := oracle)
    (externalOracle := externalOracle) (fresh := fresh) hP hPB (ExternalModels.targets_core P hp) table hv
  obtain ⟨_, d2, s2, _, t2⟩ := error.release_selected_error (oracle := oracle)
    (externalOracle := externalOracle) (fresh := fresh) table
  obtain ⟨_, d3, s3, _, t3⟩ := exit.release_selected_exit (oracle := oracle)
    (externalOracle := externalOracle) (fresh := fresh) table
  exact ⟨⟨d1, s1, t1⟩, ⟨d2, s2, t2⟩, ⟨d3, s3, t3⟩⟩

/-- 三表と合成表のどれでも、型付きの解放の枠に外部ハンドルは現れない。 -/
example (m : ExternalModels.ModelCase) (P : Program) {σ Ψ R e k a b Eb Re h ts}
    (frames : ContTy P (m.table P) σ Ψ R e (.release (.externalHandle h ts) :: k) a b Eb Re)
    (standard : ContTy P (StandardModel.builtins P) σ Ψ R e (.release (.externalHandle h ts) :: k) a b Eb Re) :
    False ∧ False :=
  ⟨frames.release_not_external (m.resource_table P),
   standard.release_not_external (StandardModel.resource_table P)⟩

/-- 解放の枠の値の関係は全ての結果を許し、使用の開始から積んだ枠の値にも同じ関係を与える。 -/
example (P : Program) (hp : ScopeDeclarations.HasFile P) (hP : P.WellFormed)
    (hPB : P.WellTyped (ExternalModels.targets P)) {σ Eb q v m k μ}
    (h : StateTyE P (ExternalModels.targets P) σ Eb (.run q k μ)) (hv : q.view = .use v m)
    (r : Benitoite.Release.ErrKind) :
    (ExternalModels.targets P).releaseResponse v none ∧
      (ExternalModels.targets P).releaseResponse v (some r) := by
  have all := (h.use_release_all hP hPB (ExternalModels.targets_core P hp)
    (ExternalModels.ModelCase.resource_table .targets P) hv).2
  exact ⟨all none, all (some r)⟩

end
end Benitoite.Release.Refinement
