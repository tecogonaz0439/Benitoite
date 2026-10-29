import Benitoite.Scope.SignatureExamples
import Benitoite.Scope.InferenceExamples
import Benitoite.Scope.CompatExamples

/-!
# 非空の例と切り替えの整合（L00.07 のモデル）

0.0.13 の L00.07 の例である。採用定義（`Scope.Domain`・`Scope.Signature`・`Scope.Inference`・`Scope.TopCompat`）と、
それを直接使うモデル（`SignatureExamples`・`InferenceExamples`・`CompatExamples`）を使い、空の表や Top だけの上限では
確かめられない形を、非 Top の範囲の具体の例で示す。既存の定義と定理を変えない。

置いた例は次のとおりである。IO の観測は、採用定義の観測の条件 `ShapeTargets`（計画済みの信頼条件 `io_target` の
内容）を満たす観測について述べる。

1. 純粋な検査から狭い値を作り、その値を非 Top の IO の引数へ渡す（L00.03 の δ と L00.05 の局所解析から、
   値の型付け・具体化の許容・観測の条件まで）。
2. 明示拡大と同じ値の転送（拡大は同じ値を返し、IO が観測する対象は検査した対象と同じ）。
3. 捕捉した操作の節が別の対象へ操作する例と、利用者の操作の (c) の例（`saveToFile` の形）。
   ハンドラの意味（本番の `E_Op`・`E_OpPrim`・`handled`）はモデルにない。名前全体の除去を効果の原子の列の上の
   `removeName` で写し、節の本体の IO の具体化した効果が外側の上限と一致する部分だけを示す。`removeName`・
   `handledBound` は本番の `handled` の写しであり、採用定義ではない（L30 で本番の `handled` と節の効果の計算に置き換える）。
4. 対象なしの旧の IO の観測が空であること。
5. 採用定義の一般化した効果（`TopCompat.GEff`）を、範囲の位置 `Ix` を持つ非 Top の原子に当てる例と、Top の旧の例。
6. 範囲付きの値の所属を新しい葉の規則で型付ける形（採用した案 A。L00.08 の一括の問い、問 6）。

L00.08 で、採らなかった案 (ii) の原子の具体化（5 節）と、値の所属の案 B・C の比較（6 節）を消した。L00.04 の
観測を持つ小さな機械（`Scope.TargetExamples`）を消したので、1〜4 節の事象と遷移を使う例は、観測の条件と値の
型付けだけで書き直すか消した。消した例は L30 が本番の定義の上に置き直す（`reviews/L00.08b-target-statements.md`
の「L30 の義務」）。本番の接続（Release の型付け・遷移・主定理、Surface の検査と脱糖）は証明していない。
-/

namespace Benitoite.Scope.SwitchExamples

open Benitoite.Scope.Domain
open Benitoite.Scope.Signature
open Benitoite.Scope.SignatureExamples

/-! ## 共通の補助 -/

/-- 種類が path の範囲への所属は、対象が path であることを含む。 -/
theorem mem_path_kind {p : PathPattern} {t : Target} (h : (Range.path p).Mem t) : t.kind = .path := by
  cases t <;> simp_all [Range.Mem, Target.kind]

def dataTreeA : Target := .path ["data", "a.txt"]
def outsideTarget : Target := .path ["etc", "passwd"]

theorem dataTree_wf : dataTree.WF := by decide

/-- 非 Top の上限 `File.Write[R]`。 -/
def fileWrite (R : Range) : List Atom := [.name "File.Write" (.fixed R)]

theorem exampleTable_valKind_pathIn : exampleTable.valKind pathInName = some .path := rfl

/-- 範囲付きの値の型付けは、表の `valKind` の値だけによる。 -/
theorem pathIn_typed_iff {w : Val} {R : Range} :
    HasTypeV exampleTable.valKind w (pathIn (.fixed R)) ↔ ∃ t, w = .checked t ∧ t.kind = .path ∧ R.Mem t := by
  constructor
  · intro h
    cases w with
    | checked t => exact ⟨t, rfl, by simpa [exampleTable_valKind_pathIn, eq_comm] using h.1, h.2⟩
    | handle n =>
      cases R with
      | top => simp [HasTypeV, pathIn, exampleTable_valKind_pathIn] at h
      | _ => simp [HasTypeV, pathIn] at h
    | _ => simp [HasTypeV, pathIn] at h
  · rintro ⟨t, rfl, hk, hm⟩
    exact ⟨by rw [exampleTable_valKind_pathIn, hk], hm⟩

/-- `File.writeTextIn` を R で具体化すると、効果は `File.Write[R]` の一原子である。 -/
theorem writeTextIn_eff (R : Range) : (writeTextIn.inst [R]).eff = fileWrite R := rfl

/-- `File.writeTextIn` の具体化は、範囲の種類と整形式性だけで許される（`exampleTable` の制約は自明）。 -/
theorem writeTextIn_admissible {R : Range} (hwf : R.WF) (hfit : R.FitsKind .path) :
    RangeAdmissible exampleTable "File.writeTextIn" writeTextIn [R] :=
  ⟨⟨hfit, trivial⟩, by intro r hr; simp at hr; subst hr; exact hwf, trivial⟩

/-- 書き込みの観測は、採用定義の観測の条件（`ShapeTargets` の単一の対象の形）と値の型付けから、引数の値が保持する
同じ対象一つで、R に種類に相対的に属する。応答の中身を読まない。 -/
theorem write_obs_of_shape {R : Range} {w : Val} {x : String} {obs : List Target}
    (hw : HasTypeV exampleTable.valKind w (pathIn (.fixed R)))
    (hobs : ShapeTargets Val.target? writeTextIn.shape [w, .str x] obs) :
    ∃ t, w = .checked t ∧ obs = [t] ∧ R.MemK .path t := by
  obtain ⟨t, rfl, hk, hm⟩ := pathIn_typed_iff.mp hw
  obtain ⟨t', ht', rfl⟩ := ShapeTargets.single_eq (k := .path) (p := 0) hobs
  have he : t' = t := by simpa [Val.target?] using ht'.symm
  rw [he]
  exact ⟨t, rfl, rfl, hk, hm⟩

/-! ## 1. 純粋な検査から狭い値を作り、非 Top の IO へ渡す -/

/-- L00.03 の検査の δ が `Ok` を返せば、成功値は具体化した R に属する path の対象を保持する。 -/
theorem checkPathDelta_ok {pp : String → Option Range} {pt : String → Option Target} {R : Range}
    {pat raw : String} {w : Val} (h : checkPathDelta pp pt [R] [.str pat, .str raw] = some (.ok w)) :
    ∃ t, w = .checked t ∧ t.kind = .path ∧ R.Mem t := by
  simp only [checkPathDelta, Option.some.injEq] at h
  split at h
  · next q t _ _ =>
    split at h
    · next hc => cases h; exact ⟨t, rfl, hc.1, hc.2.2⟩
    · cases h
  · cases h

/-- 純粋な検査の成功値をそのまま `File.writeTextIn` へ渡すと、引数は `PathIn[R]` で型付き、効果は `File.Write[R]`、
観測の条件を満たす観測は検査した同じ対象一つで R に属する。 -/
theorem check_then_write {pp : String → Option Range} {pt : String → Option Target} {R : Range}
    {pat raw x : String} {w : Val} (h : checkPathDelta pp pt [R] [.str pat, .str raw] = some (.ok w)) :
    HasTypeVs exampleTable.valKind [w, .str x] (writeTextIn.inst [R]).params ∧
      (writeTextIn.inst [R]).eff = fileWrite R ∧
      ∀ obs, ShapeTargets Val.target? writeTextIn.shape [w, .str x] obs →
        ∃ t, w = .checked t ∧ obs = [t] ∧ R.MemK .path t := by
  obtain ⟨t, rfl, hk, hm⟩ := checkPathDelta_ok h
  have hw : HasTypeV exampleTable.valKind (.checked t) (pathIn (.fixed R)) := pathIn_typed_iff.mpr ⟨t, rfl, hk, hm⟩
  exact ⟨.cons hw (.cons trivial .nil), rfl, fun obs hobs => write_obs_of_shape hw hobs⟩

/-- 具体の解析器。`/data/**` を解析し、`/data/a.txt` と `/etc/passwd` を対象として解析する。 -/
def pp0 : String → Option Range
  | "/data/**" => some dataTree
  | _ => none

def pt0 : String → Option Target
  | "/data/a.txt" => some dataTreeA
  | "/etc/passwd" => some outsideTarget
  | _ => none

-- 範囲の内側の対象は成功し、外側の対象は動的な確かめで誤りになる（Top の上限に頼らない非空の例）。
#guard checkPathDelta pp0 pt0 [dataTree] [.str "/data/**", .str "/data/a.txt"] == some (.ok (.checked dataTreeA))
#guard checkPathDelta pp0 pt0 [dataTree] [.str "/data/**", .str "/etc/passwd"] == some (.err .unit)

theorem check_then_write_example (obs : List Target)
    (hobs : ShapeTargets Val.target? writeTextIn.shape [.checked dataTreeA, .str "x"] obs) : obs = [dataTreeA] := by
  obtain ⟨-, -, h⟩ := check_then_write (pp := pp0) (pt := pt0) (pat := "/data/**") (raw := "/data/a.txt")
    (x := "x") (R := dataTree) (w := .checked dataTreeA) (by decide)
  obtain ⟨t, ht, hobs', -⟩ := h obs hobs
  cases ht
  exact hobs'

/-- L00.05 の局所解析の最小例（直接の検査 → 一度の保存 → 同じ `Ok` 値 → 射影 → 再検査）で、必須の判定が
`/data/**` の添字を付けた位置の値は、その添字の型 `PathIn["/data/**"]` を持ち、`File.writeTextIn` の引数に渡せる。
同じ範囲を局所解析・値の型付け・具体化の許容へ渡す。 -/
theorem minimal_then_write {env env' : InferenceExamples.Locals} {v : InferenceExamples.CVal} (x : String)
    (hev : InferenceExamples.StepsEval InferenceExamples.toyTable env InferenceExamples.minimalSteps env')
    (found : env'[0]? = some (some v)) :
    HasTypeVs exampleTable.valKind [v.toSig, .str x] (writeTextIn.inst [dataTree]).params ∧
      RangeAdmissible exampleTable "File.writeTextIn" writeTextIn [dataTree] := by
  obtain ⟨ps, raw, t, rfl, ht⟩ := InferenceExamples.minimal_checked hev found
  have hk : t.kind = .path := mem_path_kind ht
  exact ⟨.cons (pathIn_typed_iff.mpr ⟨t, rfl, hk, ht⟩) (.cons trivial .nil),
    writeTextIn_admissible dataTree_wf (Or.inr rfl)⟩

/-! ## 2. 明示拡大と同じ値の転送 -/

def valA : Val := .checked dataTreeA

theorem valA_narrow : HasTypeV exampleTable.valKind valA (pathIn (.fixed dataA)) :=
  pathIn_typed_iff.mpr ⟨_, rfl, rfl, dataA_mem⟩

theorem widen_admissible : RangeAdmissible exampleTable "Scope.widenPathIn" widenPathIn [dataA, dataTree] :=
  ⟨by decide, by decide, ⟨dataA, dataTree, rfl, dataA_sub_dataTree⟩⟩

/-- 明示拡大は同じ値を返す。 -/
theorem widen_same_value : widenDelta [dataA, dataTree] [valA] = some valA := rfl

/-- 拡大した結果の値は広い添字の型を持つ（L00.03 の `widenPathIn_delta_typed` から）。 -/
theorem widen_typed : HasTypeV exampleTable.valKind valA (pathIn (.fixed dataTree)) := by
  obtain ⟨v, hv, hty⟩ := widenPathIn_delta_typed [dataA, dataTree] [valA] widen_admissible
    (.cons ⟨rfl, dataA_mem⟩ .nil)
  rw [widen_same_value] at hv
  cases hv
  exact hty

/-- 被覆しない拡大は具体化を許されない（`/data/**` から `/data/a.txt` へは狭められない）。 -/
theorem widen_not_admissible : ¬ RangeAdmissible exampleTable "Scope.widenPathIn" widenPathIn [dataTree, dataA] := by
  rintro ⟨-, -, r, s, h, hsub⟩
  simp only [List.cons.injEq, and_true] at h
  obtain ⟨rfl, rfl⟩ := h
  have := hsub (.path ["data", "b"]) ⟨["b"], rfl⟩
  simp [dataA, Range.Mem, PathPattern.Matches] at this

/-- 同じ値の転送: 拡大した値で広い上限 `File.Write["/data/**"]` の書き込みに渡すと、観測は拡大の前に検査した
対象と同じである。広い型で受け取っても、対象は広がらない。 -/
theorem widen_then_write_same_target {x : String} {obs : List Target}
    (hobs : ShapeTargets Val.target? writeTextIn.shape [valA, .str x] obs) :
    obs = [dataTreeA] ∧ dataA.Mem dataTreeA := by
  obtain ⟨t, ht, hobs', -⟩ := write_obs_of_shape widen_typed hobs
  cases ht
  exact ⟨hobs', dataA_mem⟩

/-! ## 3. 捕捉した操作の節と、利用者の操作（Q9 の (c)） -/

/-- 名前全体の除去を効果の原子の列の上で写したもの（本番の `Release.handled` は名前の全操作の節がそろうことを
求める。モデルはその条件を持たない）。範囲によらず、同じ名前の原子を全て除く。 -/
def removeName (l : String) (eff : List Atom) : List Atom :=
  eff.filter (fun a => match a with | .name m _ => m != l | .rho _ => true)

/-- ハンドラの外側の上限: 保護本体の効果から処理した名前を除き、節の本体の効果を加える（判断 11）。 -/
def handledBound (l : String) (bodyEff clauseEff : List Atom) : List Atom := removeName l bodyEff ++ clauseEff

def logsTree : Range := .path (.tree ["logs"])
def logT : Target := .path ["logs", "audit.txt"]

/-- 保護本体は `/data/**` へ書く。 -/
def bodyWrite : List Atom := fileWrite dataTree

/-- 3a: 節は捕捉した書き込みを再開せずに記録だけを `/logs/**` へ書く（別の対象へ操作する節）。 -/
def outerLog : List Atom := handledBound "File.Write" bodyWrite (fileWrite logsTree)

-- 外側の上限には節の対象だけが残り、保護本体の `/data/**` は残らない。節の添字 S は `/data/**`。
#guard outerLog == fileWrite logsTree
#guard clauseIndex "File.Write" bodyWrite == dataTree

/-- 捕捉した操作の引数（`/data/a.txt` の値。本体では `/data/**` の型）は、節の添字 S の型を持つ。 -/
theorem captured_arg_typed :
    HasTypeV exampleTable.valKind valA (pathIn (.fixed (clauseIndex "File.Write" bodyWrite))) :=
  clause_arg_typed (k := .path) rfl widen_typed ⟨dataTree, by simp [bodyWrite, fileWrite], fun _ h => h⟩

theorem logsTree_wf : logsTree.WF := by decide

/-- 節の本体の書き込みの具体化した効果は外側の上限そのものであり、観測は `/logs/**` に属する。 -/
theorem log_clause_obs {obs : List Target}
    (hobs : ShapeTargets Val.target? writeTextIn.shape [.checked logT, .str "entry"] obs) :
    (writeTextIn.inst [logsTree]).eff = outerLog ∧
      RangeAdmissible exampleTable "File.writeTextIn" writeTextIn [logsTree] ∧ ∀ t ∈ obs, logsTree.Mem t := by
  have hw : HasTypeV exampleTable.valKind (.checked logT) (pathIn (.fixed logsTree)) :=
    pathIn_typed_iff.mpr ⟨_, rfl, rfl, ⟨["audit.txt"], rfl⟩⟩
  refine ⟨by decide, writeTextIn_admissible logsTree_wf (Or.inr rfl), ?_⟩
  obtain ⟨t, -, hobs', hm⟩ := write_obs_of_shape hw hobs
  intro t' ht'
  rw [hobs'] at ht'
  simp at ht'
  subst ht'
  exact hm.2

/-- 外側の上限は保護本体の対象を許さない（処理した名前の対象は外側に残らない）。 -/
theorem outerLog_excludes_data : ¬ EffAllows exampleTable.effKind outerLog "File.Write" dataTreeA := by
  rintro ⟨k, R, -, hR, hm⟩
  have heq : outerLog = fileWrite logsTree := by decide
  rw [heq] at hR
  simp [fileWrite] at hR
  subst hR
  simp [logsTree, dataTreeA, Range.MemK, Range.Mem, PathPattern.Matches] at hm

/-- 3b: 節が捕捉した引数をそのまま範囲付きの書き込みへ転送する場合、外側の上限は S の原子を持ち、
節の書き込みの具体化した効果はその上限と同じで、引数は S の型を持つ。 -/
def outerForward : List Atom := handledBound "File.Write" bodyWrite (fileWrite (clauseIndex "File.Write" bodyWrite))

theorem forward_clause (x : String) :
    (writeTextIn.inst [clauseIndex "File.Write" bodyWrite]).eff = outerForward ∧
      HasTypeVs exampleTable.valKind [valA, .str x] (writeTextIn.inst [clauseIndex "File.Write" bodyWrite]).params := by
  have heq : outerForward = fileWrite (clauseIndex "File.Write" bodyWrite) := by decide
  rw [heq]
  exact ⟨rfl, .cons captured_arg_typed (.cons trivial .nil)⟩

/-! ### 3c: 利用者の操作の (c) の例（`saveToFile` の形） -/

/-- 利用者の操作の宣言の写し（本番の `Release.OpDecl` の `eff`・`names`・`params`・`ret`）。型引数・辞書は
この例に要らないので写さない。範囲の引数や範囲の変数の欄を持たない（Q9 の (c)）。 -/
structure UserOp where
  eff : String
  names : List String
  params : List VTy
  ret : VTy

/-- 本番の `V_Op` の効果 `Eff.single od.eff` に当たる原子。名前だけ（Top）である。 -/
def UserOp.atom (od : UserOp) : Atom := Atom.ofOld od.eff

def reportsTree : Range := .path (.tree ["data", "reports"])

/-- 利用者のエフェクト `Report` の操作 `save` の宣言の写し。引数 `path` は `Scope.PathIn["/data/reports/**"]`、
`text` は `String`、結果は `Unit` である（表層の構文は写さない）。引数の型の範囲は閉じた範囲として固定され、
範囲の変数を持たない。 -/
def saveOp : UserOp := ⟨"Report", ["path", "text"], [pathIn (.fixed reportsTree), .string], .unit⟩

/-- 保護本体は利用者の操作 `Report.save` を呼ぶ。 -/
def bodyReport : List Atom := [saveOp.atom]

/-- 節は `File.writeTextIn(path, text)` を行う。範囲は引数の型の固定の範囲である。 -/
def outerSave : List Atom := handledBound "Report" bodyReport (fileWrite reportsTree)

-- 処理した後の上限は `File.Write["/data/reports/**"]` だけで、利用者の名前 `Report` は残らない。
#guard outerSave == fileWrite reportsTree
-- 利用者の名前の原子は Top なので、節の添字は Top（利用者の操作の引数の型は宣言の固定の範囲で決まる）。
#guard clauseIndex "Report" bodyReport == .top

theorem outerSave_no_user : ∀ a ∈ outerSave, ∀ ix, a ≠ .name "Report" ix := by
  have heq : outerSave = fileWrite reportsTree := by decide
  rw [heq]
  intro a ha ix h
  simp [fileWrite] at ha
  subst ha
  injection h with h1
  exact absurd h1 (by decide)

/-- 利用者の操作は組み込みの表にない。対象の種類も操作の一覧も持たない（認定元は標準だけ）。 -/
theorem saveOp_not_builtin :
    exampleTable.sig "Report.save" = none ∧ exampleTable.effKind "Report" = none ∧
      exampleTable.effects "Report" = none := by
  refine ⟨rfl, rfl, rfl⟩

theorem reportsTree_wf : reportsTree.WF := by decide

/-- 節の本体の書き込み: 利用者の操作の引数が宣言の型で型付けば、節の `File.writeTextIn` の具体化した効果は外側の
上限 `File.Write["/data/reports/**"]` そのものであり、観測の条件を満たす観測はその範囲に属する。 -/
theorem save_clause {w : Val} {s : String} (hw : HasTypeVs exampleTable.valKind [w, .str s] saveOp.params) :
    (writeTextIn.inst [reportsTree]).eff = outerSave ∧
      ∀ obs, ShapeTargets Val.target? writeTextIn.shape [w, .str s] obs → ∀ t ∈ obs, reportsTree.Mem t := by
  have hw0 : HasTypeV exampleTable.valKind w (pathIn (.fixed reportsTree)) := by
    cases hw with
    | cons h _ => exact h
  have heq : outerSave = fileWrite reportsTree := by decide
  refine ⟨by rw [heq]; rfl, ?_⟩
  intro obs hobs t ht
  obtain ⟨t0, -, hobs', hm⟩ := write_obs_of_shape hw0 hobs
  rw [hobs'] at ht
  simp at ht
  subst ht
  exact hm.2

/-- 具体の非空の例: `/data/reports/2026.txt` を保存する。 -/
theorem save_example {obs : List Target}
    (hobs : ShapeTargets Val.target? writeTextIn.shape
      [.checked (.path ["data", "reports", "2026.txt"]), .str "ok"] obs) :
    obs = [.path ["data", "reports", "2026.txt"]] := by
  have hw : HasTypeV exampleTable.valKind (.checked (.path ["data", "reports", "2026.txt"])) (pathIn (.fixed reportsTree)) :=
    pathIn_typed_iff.mpr ⟨_, rfl, rfl, ⟨["2026.txt"], rfl⟩⟩
  obtain ⟨t, ht, hobs', -⟩ := write_obs_of_shape hw hobs
  cases ht
  exact hobs'

/-! ### 範囲の変数を利用者の宣言に置かせない条件の候補 -/

def ixNoVar : Ix → Bool
  | .fixed _ => true
  | .rvar _ => false

/-- 型に範囲の変数がない。 -/
def vtyNoRVar : VTy → Bool
  | .opaque _ ix => ixNoVar ix
  | .result a e => vtyNoRVar a && vtyNoRVar e
  | _ => true

/-- 利用者の宣言の条件の候補。置き場所は L00.08 が決める（`l00.07/results.md` の「範囲の変数の条件の置き場所」）。 -/
def UserOp.NoRVar (od : UserOp) : Bool := od.params.all vtyNoRVar && vtyNoRVar od.ret

#guard saveOp.NoRVar
#guard !({ saveOp with params := [pathIn (.rvar 0), .string] }).NoRVar
#guard !({ saveOp with ret := .result (pathIn (.rvar 0)) .unit }).NoRVar

/-- 範囲の変数のない型は、どの具体化でも変わらない（利用者の宣言を範囲で多相にできない）。 -/
theorem inst_of_noRVar {t : VTy} (rs : List Range) (h : vtyNoRVar t = true) : t.inst rs = t := by
  induction t with
  | «opaque» o ix => cases ix <;> simp_all [vtyNoRVar, ixNoVar, VTy.inst, Ix.inst]
  | result a e iha ihe =>
    simp only [vtyNoRVar, Bool.and_eq_true] at h
    simp [VTy.inst, iha h.1, ihe h.2]
  | _ => rfl

theorem saveOp_params_inst (rs : List Range) : saveOp.params.map (VTy.inst rs) = saveOp.params := by
  simp [saveOp, pathIn, VTy.inst, Ix.inst]

/-- 範囲の変数を添字に持つ型には値が属さない。条件を置かないと、範囲の変数を書いた利用者の操作は
呼び出せない操作になり、後に (a) で具体化を加えると黙って範囲の多相になる。 -/
theorem rvar_uninhabited {K : String → Option Kind} (v : Val) (o : String) (i : Nat) :
    ¬ HasTypeV K v (.opaque o (.rvar i)) := by
  cases v <;> simp [HasTypeV]

/-! ## 4. 対象なしの旧の IO -/

theorem printLine_inst (rs : List Range) : printLine.inst rs = printLine := by
  simp [Entry.inst, printLine, VTy.inst, Atom.ofOld, Atom.inst, Ix.inst]

/-- 対象なしの旧の IO の観測は空である（`io_target` の `untargeted` の形）。旧の項目はどの具体化でも変わらない。 -/
theorem print_obs_nil {ws : List Val} {obs : List Target}
    (hobs : ShapeTargets Val.target? printLine.shape ws obs) : obs = [] :=
  ShapeTargets.untargeted_nil hobs

/-! ## 5. 一般化した効果を非 Top の原子と Top の旧の例に当てる（L00.06 の申し送り 2） -/

section GEffExamples

open CompatExamples
open TopCompat

abbrev AtomI := RepresentationExamples.CandidateI.Atom

/-- 案 (i) の原子の非 Top の効果 `{File.Write["/data/a"]}`。 -/
def nonTopI : GEff AtomI := ⟨fun x => x == .name "File.Write" RepresentationExamples.CandidateI.dataA, []⟩

/-- 非 Top の効果は旧の効果の像にない。旧の補題ではこの効果について言明できない。 -/
theorem nonTopI_not_lifted (e : Release.Eff) : embI.lift e ≠ nonTopI := by
  intro h
  have hm : nonTopI.mem (.name "File.Write" RepresentationExamples.CandidateI.dataA) := by
    simp [GEff.mem, nonTopI]
  rw [← h] at hm
  obtain ⟨a, ha, -⟩ := embI.lift_mem hm
  cases a with
  | name l ix =>
    by_cases hix : ix = .fixed .top
    · simp [embI, RepresentationExamples.CandidateI.Atom.ofRelease, RepresentationExamples.CandidateI.dataA, hix] at ha
    · simp [embI, RepresentationExamples.CandidateI.Atom.ofRelease, hix] at ha
  | rho i => simp [embI, RepresentationExamples.CandidateI.Atom.ofRelease] at ha

/-- 一般化した補題は非 Top の効果にそのまま当たる。 -/
theorem nonTopI_union_empty :
    GEff.union nonTopI (GEff.union nonTopI GEff.empty) = GEff.union nonTopI nonTopI :=
  GEff.union_empty_right_nested _ _

/-- Top の旧の例は、互換の系から旧の言明のまま得る（案 (i) の埋め込み）。 -/
theorem oldTop_union_empty_I :
    Release.Eff.union (Release.Eff.single "File.Write")
        (Release.Eff.union (Release.Eff.single "File.Write") Release.Eff.empty) =
      Release.Eff.union (Release.Eff.single "File.Write") (Release.Eff.single "File.Write") :=
  embI.old_union_empty_right_nested _ _

/-- 範囲の位置 `Ix` を持つ原子（L00.03 のモデルの原子。案 (i) の `Atom.name l ix` の形）の埋め込み。本番の原子も
L10.2 で同じ形（`Release.Atom.name l ix`）になったので、埋め込みは範囲の位置をそのまま運ぶ。旧の原子は本番の
原子の Top の像（`Atom.TopImage`）であり、明示の Top の構築関数 `Atom.nameTop` で書く。 -/
def embIx : TopEmbedding Atom where
  ofRelease
    | .name l ix => .name l ix
    | .rho i => .rho i
  toRelease?
    | .name l ix => some (.name l ix)
    | .rho i => some (.rho i)
  to_of a := by cases a <;> rfl
  of_to {x a} h := by
    match x, h with
    | .name l ix, h => cases h; rfl
    | .rho i, h => cases h; rfl

/-- `Ix` の原子の非 Top の効果 `{File.Write["/data/**"]}`。 -/
def nonTopIx : GEff Atom := ⟨fun x => x == .name "File.Write" (.fixed dataTree), []⟩

/-- 旧の効果（原子がすべて Top の像にある本番の効果）の像に、非 Top の効果はない。 -/
theorem nonTopIx_not_lifted (e : Release.Eff) (he : ∀ a, Release.Eff.mem e a → a.TopImage) :
    embIx.lift e ≠ nonTopIx := by
  intro h
  have hm : nonTopIx.mem (.name "File.Write" (.fixed dataTree)) := by simp [GEff.mem, nonTopIx]
  rw [← h] at hm
  obtain ⟨a, ha, hea⟩ := embIx.lift_mem hm
  have htop := he a hea
  cases a with
  | name l ix =>
    simp only [embIx, SignatureExamples.Atom.name.injEq] at ha
    obtain ⟨rfl, hix⟩ := ha
    cases hix
    simp [Release.Atom.TopImage, dataTree] at htop
  | rho i => simp [embIx] at ha

/-- 一般化した補題は `Ix` の原子の非 Top の効果にもそのまま当たる。 -/
theorem nonTopIx_union_empty :
    GEff.union nonTopIx (GEff.union nonTopIx GEff.empty) = GEff.union nonTopIx nonTopIx :=
  GEff.union_empty_right_nested _ _

/-- 同じ旧の例を `Ix` の原子の埋め込みでも得る。 -/
theorem oldTop_union_empty_Ix :
    Release.Eff.union (Release.Eff.single "File.Write")
        (Release.Eff.union (Release.Eff.single "File.Write") Release.Eff.empty) =
      Release.Eff.union (Release.Eff.single "File.Write") (Release.Eff.single "File.Write") :=
  embIx.old_union_empty_right_nested _ _

#guard (embIx.lift (Release.Eff.single "File.Write")).atoms (.name "File.Write" Ix.top)
#guard !(embIx.lift (Release.Eff.single "File.Write")).atoms (.name "File.Write" (.fixed dataTree))

end GEffExamples

/-! ## 6. 範囲付きの値の所属の葉の規則（採用した案 A。L00.06 の申し送り 1: NT・NV） -/

namespace ValueTyping

/-- 案 A: 値に検査済みの対象の構成子を足し（NV）、所属を前提に持つ葉の規則を足す（NT）。 -/
inductive ValA where
  | str (s : String)
  | checked (t : Target)

def ValA.toSig : ValA → Val
  | .str s => .str s
  | .checked t => .checked t

inductive TyA (K : String → Option Kind) : ValA → VTy → Prop where
  | str {s : String} : TyA K (.str s) .string
  | checked {t : Target} {o : String} {r : Range} :
      K o = some t.kind → r.Mem t → TyA K (.checked t) (.opaque o (.fixed r))

/-- 案 A は L00.03 の値の型付け（所属の不変条件）と一致する。 -/
theorem tyA_iff (K : String → Option Kind) (v : ValA) (a : VTy) : TyA K v a ↔ HasTypeV K v.toSig a := by
  constructor
  · intro h
    cases h with
    | str => trivial
    | checked hk hm => exact ⟨hk, hm⟩
  · intro h
    cases v with
    | str s => cases a <;> first | exact .str | simp [ValA.toSig, HasTypeV] at h
    | checked t =>
      cases a with
      | «opaque» o ix =>
        cases ix with
        | fixed r => exact .checked h.1 h.2
        | rvar i => simp [ValA.toSig, HasTypeV] at h
      | _ => simp [ValA.toSig, HasTypeV] at h

/-- 案 A の逆転（標準形）。 -/
theorem tyA_canonical {K : String → Option Kind} {v : ValA} {o : String} {r : Range}
    (h : TyA K v (.opaque o (.fixed r))) : ∃ t, v = .checked t ∧ r.Mem t := by
  cases h with
  | checked _ hm => exact ⟨_, rfl, hm⟩

/-- 明示拡大・節の添字の所属の補題は値の型付けだけで閉じる。 -/
theorem tyA_widen {K : String → Option Kind} {v : ValA} {o : String} {r s : Range}
    (h : TyA K v (.opaque o (.fixed r))) (hs : Range.Sub r s) : TyA K v (.opaque o (.fixed s)) := by
  cases h with
  | checked hk hm => exact .checked hk (hs _ hm)

end ValueTyping

end Benitoite.Scope.SwitchExamples
