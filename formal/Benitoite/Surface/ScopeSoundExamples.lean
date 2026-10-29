import Benitoite.Surface.ScopeSound
import Benitoite.Surface.ScopeAcceptExamples

/-!
# Scope の接続定理の小例（L40.6）

`Surface.ScopeSound` の接続定理を、本番の実例の表の δ を規則にした表（`productionRules`）と小さな表層の本体で確かめる
（設計書 01-12「Scope の局所解析の接続定理」）。文字列の解析器・ホストのパターンの解析・要求の対象・出現の解決はこの例の
ためのものであり、処理系の解析器・名前解決との一致の証拠ではない。

- 接続定理の前提が満たせること（受理・出現・記録の添字を小さな `decide` で確かめる）と、検査の成功値・射影の引数が
  `/data/**` に属すること。
- 旧 Scope の IP の成否: CIDR `10.0.0.0/8` の範囲の中と外の IPv4 アドレスで、旧の検査の成否と、本番の実例の表の要求の
  検査の δ の成否が一致する。
- 未知と予算の停止: 局所の文字列のパターンの検査（由来の未知）と上限 0 の解析（予算の超過）では、狭い範囲の列を拒否し、
  Top の列だけを受理する。接続定理は推論した範囲が Top のとき契約も Top であることを結論する。
- 警告の解析との分離: 必須の判定と予算の超過は区間解析の成分と予算を読まない。
-/

namespace Benitoite.Surface.ScopeSoundExamples

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept
open Benitoite.Surface.ScopeSound
open Benitoite.Surface.ScopeLowerExamples (dataTree defn at_ wide scope0 unitTy str matchOk)
open Benitoite.Surface.ScopeAcceptExamples (reasonOf)
open Scope.Domain (Range Target)

/-! ## 本番の δ を規則にした表 -/

def target : Target := .path ["data", "a.txt"]

def pat : String → Option Range := fun s => if s = "/data/**" then some dataTree else none
def tgt : String → Option Target := fun s => if s = "/data/a.txt" then some target else none

/-- CIDR `10.0.0.0/8` と、その中と外の IPv4 アドレス。 -/
def net10 : Scope.Domain.HostPattern := .ip (.cidr (Scope.Domain.CIDR.v4 0x0A000000 8))
def inside : Scope.Domain.HostTarget := .ip (Scope.Domain.IPAddr.v4 0x0A010203)
def outside : Scope.Domain.HostTarget := .ip (Scope.Domain.IPAddr.v4 0xC0A80001)

def port443 : Scope.Domain.Port := ⟨443, by decide⟩

def hostPattern : String → Option Scope.Domain.HostPattern := fun s => if s = "10.0.0.0/8" then some net10 else none

/-- 要求の `url` の欄の例。要求 1 は範囲の中、要求 2 は範囲の外の IPv4 アドレスの 443 番を指す。 -/
def urlOf (n : Nat) : String := if n = 1 then "https://10.1.2.3/" else "https://192.168.0.1/"

/-- 例の URL の解析（形式化の外側の解析器の代わりの小さな関数）。 -/
def parseUrl (u : String) : Option Target :=
  if u = "https://10.1.2.3/" then some (.endpoint ⟨inside, port443⟩)
  else if u = "https://192.168.0.1/" then some (.endpoint ⟨outside, port443⟩)
  else none

/-- 要求のレコードから `url` の欄を取り出して解析する、要求の実効の endpoint。 -/
def reqTarget : Val → Option Target := ModelHttp.urlTarget parseUrl

/-- 要求 n のレコード。 -/
def reqOf (n : Nat) : Val := ModelHttp.Examples.mkReq (urlOf n)

theorem reqTarget_one : reqTarget (reqOf 1) = some (.endpoint ⟨inside, port443⟩) := by
  simp [reqTarget, reqOf, urlOf, parseUrl, ModelHttp.urlTarget, ModelHttp.requestUrl, ModelHttp.Examples.mkReq]

theorem reqTarget_two : reqTarget (reqOf 2) = some (.endpoint ⟨outside, port443⟩) := by
  simp [reqTarget, reqOf, urlOf, parseUrl, ModelHttp.urlTarget, ModelHttp.requestUrl, ModelHttp.Examples.mkReq]

def rules : Rules := productionRules pat tgt hostPattern reqTarget

/-- 番号 1 を `Scope.checkPathIn`、番号 7 を `Scope.pathInValue` へ解決する。 -/
def resolve (key : Key) : Option Resolved :=
  if key = at_ 1 then some ⟨.standard, checkPathName⟩
  else if key = at_ 7 then some ⟨.standard, pathValueName⟩
  else none

def table : ScopeTable Val := standardTable resolve rules.lookup

theorem table_sound : TableSound (models "Ok" ⟨pat, tgt⟩) table :=
  Rules.lookup_sound (productionRules_sound pat tgt hostPattern reqTarget) resolve

/-! ## 検査・`case Result.Ok`・射影の本体 -/

/-- `Scope.checkPathIn[/data/**](pattern: pat, path: raw)`。 -/
def checkP (p : Expr) (rs : List Range) : Expr :=
  .call (.primName checkPathName [] [] rs) [some "pattern", some "path"] [0, 1] (.cons p (.cons (.local 0) .nil))

/-- `Scope.pathInValue[/data/**](path: p)`（p は Ok の腕の束縛、位置 0）。 -/
def projP (rs : List Range) : Expr :=
  .call (.primName pathValueName [] [] rs) [some "path"] [0] (.cons (.local 0) .nil)

/-- `let r = Scope.checkPathIn[/data/**]("/data/**", raw)`（番号 1）、
`match r { Ok(p) => Scope.pathInValue[/data/**](p); Error(e) => () }`（腕の本体は番号 7）。 -/
def body : Block := .bind .bind unitTy (checkP (str "/data/**") [dataTree]) (.last (matchOk 0 (.last (projP [dataTree]))))

def records : Records := (analyzeBody "Ok" table wide (at_ 1) scope0 body).2

-- 受理する（検査の範囲は規則の添字 `/data/**` を覆い、射影の範囲は Ok の値の必須の判定 `/data/**` を覆う）。
#guard reasonOf (acceptBody "Ok" table wide (at_ 1) scope0 body) == none
-- 射影の範囲を `/data/a/**` に狭めると notCovered、検査の範囲を狭めても notCovered で拒否する。
#guard reasonOf (acceptBody "Ok" table wide (at_ 1) scope0
  (.bind .bind unitTy (checkP (str "/data/**") [dataTree])
    (.last (matchOk 0 (.last (projP [.path (.tree ["data", "a"])])))))) == some (at_ 7, .notCovered)
#guard reasonOf (acceptBody "Ok" table wide (at_ 1) scope0
  (.bind .bind unitTy (checkP (str "/data/**") [.path (.tree ["data", "a"])])
    (.last (matchOk 0 (.last (projP [dataTree])))))) == some (at_ 1, .notCovered)

theorem ok_of_reasonOf {α : Type} {x : Except α Unit} (h : reasonOf x = none) : x = .ok () := by
  cases x with
  | ok u => rfl
  | error e => cases h

theorem body_accepted : acceptBody "Ok" table wide (at_ 1) scope0 body = .ok () := ok_of_reasonOf (by decide)

theorem occ_check : (at_ 1, checkP (str "/data/**") [dataTree]) ∈ occurrences (at_ 1) body :=
  List.mem_of_getElem? (i := 0) rfl

theorem occ_proj : (at_ 7, projP [dataTree]) ∈ occurrences (at_ 1) body :=
  List.mem_of_getElem? (i := 6) rfl

theorem proj_args :
    contractOrder [0] (lowerArgs (argsKey (at_ 7) (.primName pathValueName [] [] [dataTree])) (.cons (.local 0) .nil)) =
      some [.loc 0] := by decide

theorem record7 : ∀ p ∈ records, p.1 = at_ 7 → p.2.requiredIndex 0 = dataTree := by decide

theorem rule7 : table.ruleAt (at_ 7) = some rules.pathValue := rfl

theorem rule1 : table.ruleAt (at_ 1) = some rules.checkPath := rfl

/-- 接続定理（射影の引数）の具体化。本体の評価が射影の文（番号 7）へ到達すれば、引数の位置 0 の値は、推論した範囲
`/data/**` と、型検査器が受理してコアの項へ書いた範囲 `/data/**` に属する対象を保持する。 -/
theorem proj_arg_in_data {env env' : Locals} (h : ReachBlock table (at_ 1) env body (at_ 7) env') {v : Val}
    (found : env'[0]? = some (some v)) : ∃ t, v.target? = some t ∧ dataTree.Mem t := by
  obtain ⟨st, hmem, -, -, hval⟩ := scope_local_connection (L := wide) (scope := scope0) table_sound body_accepted h
    occ_proj proj_args rule7 (projectRule_index _) found (S := dataTree) rfl
  have hidx : st.requiredIndex 0 = dataTree := record7 _ hmem rfl
  obtain ⟨t, ht, -, hm⟩ := hval (by rw [hidx]; decide)
  exact ⟨t, ht, hm⟩

/-- 同じ値が検査済みの対象の値なら、コアの入力の型 `Scope.PathIn[/data/**]`（`Scope.pathInValue` を `[/data/**]` で
具体化した引数の型）を持つ。 -/
theorem proj_arg_typed {env env' : Locals} (h : ReachBlock table (at_ 1) env body (at_ 7) env') {v : Val}
    (found : env'[0]? = some (some v)) (hv : ∀ t c, v ≠ .checkedRequest t c) {P : Release.Program} {Ψ : StoreTy} :
    HasTypeVs P ModelTargets.Examples.B Ψ [] [] [v] (TargetTable.pathInValue.inst [dataTree]).params := by
  rw [pathInValue_inst_params]
  refine .cons ?_ .nil
  exact scope_local_typed (L := wide) (scope := scope0) table_sound body_accepted h occ_proj proj_args rule7
    (projectRule_index _) found (S := dataTree) rfl (by decide) (kd := .path) rfl rfl
    (fun t c hc => absurd hc (hv t c))

/-- 接続定理（検査の成功値）の具体化。本体の評価が検査の文（番号 1）の右辺を `Ok(w)` に評価すれば、w は推論した範囲
`/data/**` と型検査器の範囲 `/data/**` に属する対象を保持する。 -/
theorem check_ok_in_data {env env' : Locals} (h : ReachBlock table (at_ 1) env body (at_ 1) env') {v w : Val}
    (hrhs : RhsEval table (at_ 1) env' (checkP (str "/data/**") [dataTree]) (some v))
    (hw : okPayload "Ok" v = some w) : ∃ t, w.target? = some t ∧ dataTree.Mem t := by
  obtain ⟨st, xs, vs, -, hxs, -, t, ht, -, -, hS⟩ := scope_check_connection (L := wide) (scope := scope0) table_sound
    body_accepted h occ_check hrhs rule1 hw
  exact ⟨t, ht, (hS dataTree rfl).2⟩

/-- 同じ R でのコアの実行。検査の規則の評価関係は、同じ範囲の列 `[/data/**]` を持つコアの項 `.prim` の E-Prim と
同じ値を返す（L20.7 の実例の表の δ）。 -/
theorem check_core_step :
    Release.Step (ModelTargets.Examples.progOf ModelTargets.Examples.dataTree) (ModelTargets.builtins pat tgt)
      (.run (.app (.prim checkPathName [] [] [dataTree]) [.const (.string "/data/**"), .const (.string "/data/a.txt")])
        [] Store.empty) none
      (.run (.ret (.con "Ok" (ModelTargets.checkTys dataTree) [.checked target])) [] Store.empty) := by
  have hc : target.kind = .path ∧ dataTree.Mem target ∧ dataTree.Mem target := by decide
  have hδ : (ModelTargets.builtins pat tgt).delta checkPathName [] [] [dataTree]
      [.const (.string "/data/**"), .const (.string "/data/a.txt")] =
        some (.val (.con "Ok" (ModelTargets.checkTys dataTree) [.checked target])) := by
    simp [ModelTargets.builtins, ModelTargets.checkRun, checkPathName, pat, tgt, hc]
  exact evalScope_core_step rule1 rfl (evalScope_of_delta rule1 rfl hδ) (s := TargetTable.checkPathIn)
    ModelTargets.sig_check rfl _ _ _

/-! ## 旧 Scope の IP の成否と本番の要求の検査 -/

/-- 旧 Scope: CIDR `10.0.0.0/8` の中の IPv4 アドレスの 443 番は成功し、外のアドレスは範囲外で失敗する。 -/
theorem old_ip_inside : ∃ v, Checked.Scope.makeEndpoint net10 inside 443 443 443 = .ok v :=
  (Checked.Scope.makeEndpoint_success_iff _ _ _ _ _).mpr (by decide)

theorem old_ip_outside :
    Checked.Scope.makeEndpoint net10 outside 443 443 443 = .error (.outsideScope (.host net10) (.host outside)) :=
  ((Checked.Scope.makeEndpoint_outside_iff _ _ _ _ _ (by decide) (by decide) (by decide) (by decide)).1).mpr
    (by decide)

def i443 : Integer64Value := ⟨443, by decide⟩

def checkArgs (n : Nat) : List Val :=
  [.const (.string "10.0.0.0/8"), .const (.integer i443), .const (.integer i443), reqOf n]

def netRange : Range := .endpoint ⟨net10, ⟨port443, port443⟩⟩

/-- 本番の要求の検査（L40.3b の実例の表の δ）は、範囲の中の要求を、同じ要求を保持する `Ok` で返す（旧 Scope の成功に
対応。具体化した範囲は Top と CIDR の範囲のどちらでも同じ）。 -/
theorem new_ip_inside (r : Range) (hr : r = .top ∨ r = netRange) :
    ModelHttp.checkRun (hostPatOf hostPattern) reqTarget r (checkArgs 1) =
      .val (.con "Ok" (ModelHttp.checkTys r)
        [.checkedRequest (.endpoint ⟨inside, port443⟩) (reqOf 1)]) := by
  obtain ⟨v, hv⟩ := old_ip_inside
  have hvt : v.toTarget = .endpoint ⟨inside, port443⟩ := by
    obtain ⟨-, hh, -, -, hp, -⟩ := Checked.Scope.makeEndpoint_ok _ _ _ _ _ v hv
    simp only [Checked.Scope.CheckedEndpoint.toTarget, Checked.Scope.CheckedEndpoint.toEndpoint, hh,
      Checked.Scope.CheckedEndpoint.portValue, hp]
    rfl
  have h := makeEndpoint_checkRun hv (hostPattern := hostPattern) (hp := "10.0.0.0/8") (by simp [hostPattern])
    (reqTarget := reqTarget) (req := reqOf 1) (ModelHttp.Examples.mkReq_closed _) (by rw [hvt]; exact reqTarget_one)
    (lo' := i443) (hi' := i443)
    rfl rfl r
  rw [hvt] at h
  have hm : r.Mem (.endpoint ⟨inside, port443⟩) := by rcases hr with rfl | rfl <;> decide
  rw [ite_eq_left hm] at h
  exact h

/-- 範囲の外の要求は `Err` になる（旧 Scope の範囲外の失敗に対応）。 -/
theorem new_ip_outside (r : Range) :
    ModelHttp.checkRun (hostPatOf hostPattern) reqTarget r (checkArgs 2) =
      .val (.con "Err" (ModelHttp.checkTys r) [ModelHttp.scopeFailure]) := by
  have hq : hostPatOf hostPattern "10.0.0.0/8" i443.toInt i443.toInt = some netRange := by
    simp [hostPatOf, hostPattern, Integer64Value.toInt, i443, Scope.Domain.Port.ofInt?, netRange, port443]
  have hc : ¬ ((Target.endpoint ⟨outside, port443⟩).kind = .endpoint ∧ netRange.Mem (.endpoint ⟨outside, port443⟩) ∧
      r.Mem (.endpoint ⟨outside, port443⟩)) := fun h => absurd h.2.1 (by decide)
  have hcl : ModelHttp.groundVal (reqOf 2) = true := ModelHttp.Examples.mkReq_closed _
  simp only [ModelHttp.checkRun, checkArgs, hcl, ite_true, reqTarget_two, hq, ite_eq_right hc]

/-- 旧 Scope の検査済みの IP のエンドポイントは、新しい値の形で `Http.RequestIn[10.0.0.0/8:443]` を持つ。 -/
theorem old_ip_typed {P : Release.Program} {Ψ : StoreTy} :
    ∃ v : Checked.Scope.CheckedEndpoint, Checked.Scope.makeEndpoint net10 inside 443 443 443 = .ok v ∧
      HasTypeV P (ModelHttp.builtins (hostPatOf hostPattern) reqTarget) Ψ [] [] (.checked v.toTarget)
        (.opaque "Http.RequestIn" (.fixed v.toRange)) := by
  obtain ⟨v, hv⟩ := old_ip_inside
  exact ⟨v, hv, CheckedEndpoint.hasTypeV v rfl⟩

/-! ## 未知と予算の停止 -/

/-- 局所の文字列をパターンにする検査（由来の未知）。 -/
def bodyLocal (rs : List Range) : Block := .bind .bind unitTy (checkP (.local 0) rs) (.last .unit)

-- 由来の未知: 狭い範囲は unknownSource で拒否し、Top だけを受理する。
#guard reasonOf (acceptBody "Ok" table wide (at_ 1) scope0 (bodyLocal [dataTree])) == some (at_ 1, .unknownSource)
#guard reasonOf (acceptBody "Ok" table wide (at_ 1) scope0 (bodyLocal [.top])) == none
-- 予算の超過（上限 0）: 狭い範囲は budgetExceeded で拒否し、Top だけを受理する。
#guard reasonOf (acceptBody "Ok" table ⟨⟨0, 0⟩, ⟨0, 0⟩⟩ (at_ 1) scope0 (bodyLocal [dataTree])) ==
  some (at_ 1, .budgetExceeded)
-- 上限 0 では記録の必須の判定は全て Top になり、射影（番号 7）の狭い範囲は budgetExceeded で拒否する。リテラルの
-- パターンの検査（番号 1）の範囲は局所の事実を読まないので、超過しても既知のままである。
#guard (analyzeBody "Ok" table ⟨⟨0, 0⟩, ⟨0, 0⟩⟩ (at_ 1) scope0 body).1.exceeded.isSome
#guard ((analyzeBody "Ok" table ⟨⟨0, 0⟩, ⟨0, 0⟩⟩ (at_ 1) scope0 body).2.all fun p => p.2.requiredIndex 0 == .top)
#guard reasonOf (acceptBody "Ok" table ⟨⟨0, 0⟩, ⟨0, 0⟩⟩ (at_ 1) scope0 body) == some (at_ 7, .budgetExceeded)

/-- 推論した範囲が Top の位置（由来の未知・予算の超過）では、接続定理は契約が Top であることだけを結論し、値の所属を
主張しない。受理した上限 0 の本体は、検査の範囲の列が Top のときだけである。 -/
theorem budget_top_only (rs : List Range) (hrs : rs = [dataTree] ∨ rs = [.top]) :
    reasonOf (acceptBody "Ok" table ⟨⟨0, 0⟩, ⟨0, 0⟩⟩ (at_ 1) scope0 (bodyLocal rs)) = none ↔ rs = [.top] := by
  rcases hrs with rfl | rfl <;> decide

/-! ## 警告の解析との分離 -/

/-- 必須の判定とその予算の超過は、区間解析の成分と予算を読まない（`Analyses.required_range_independent`）。接続定理の
前提（表の健全性・受理・表層の評価）も区間解析の結果を含まない。 -/
theorem required_independent_of_range {RF : Type} (a : Analyses RF) (r : List (Option RF))
    (b : Interval.Budget.State) (i : Nat) :
    ({ a with range := r, rangeBudget := b }).scope.state.requiredIndex i = a.scope.state.requiredIndex i :=
  (Analyses.required_range_independent a r b i).1

end Benitoite.Surface.ScopeSoundExamples
