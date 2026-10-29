import Benitoite.Release.Theorems
import Benitoite.Release.TargetTable
import Benitoite.Release.Lemmas.TargetSound
import Benitoite.Release.Lemmas.PrimRanges
import Benitoite.Release.Lemmas.Membership
import Benitoite.Release.ModelTargets

/-!
# 検査済みの要求の値と Http の項目の実例（L40.3b・L40.3c）

`Http.RequestIn` の値は、検査した同じ要求と実効の endpoint を保持する（決定の判断 7）。値の形は検査済みの要求の値
`Val.checkedRequest t req`（`t` は実効の endpoint の対象、`req` は `Http.ClientRequest` のレコードの閉じた値）であり、
型付けは規則 V-CheckedRequest で行う（設計書 01-12「構文」「型付け規則」）。本モジュールは、旧の条件
`CoreAssumptions` と対象一致の条件 `TargetAgreement` の両方を満たし、Http の三項目を持つ組み込みの関数の表を置き、
検査した要求が `Http.sendIn` まで保たれることと、一段・到達先の対象健全性が Http の項目に当たることを例で確かめる。

| 項目 | 種類 | 形 | 署名 | δ・応答・観測 |
|---|---|---|---|---|
| `Reference.get`・`Reference.set` | 可変のセル | — | `Model` と同じ | ストアの規則 |
| `Http.checkRequestIn` | pure | — | 問 22 の表（`TargetTable.checkRequestIn`） | 動的な範囲と具体化した R の両方を確かめ、成功値は渡された要求のレコードをそのまま保持する |
| `Http.requestInValue` | pure | — | 問 22 の表（`TargetTable.requestInValue`） | 検査済みの要求の値から保持するレコードを返す |
| `Http.sendIn` | io | 単一の対象 | 問 22 の表（`TargetTable.sendIn`） | `Ok(response)` か `Err(e)`、観測は要求の endpoint 一つ（リダイレクトを追わない） |

ホストのパターンとポートの組の解析 `hostPat`、要求のレコードの値から実効の endpoint を得る処理 `reqTarget`（`url` の欄の
取り出しと URL の解析）は形式化の外側であり、関数として引数に取る（設計書 07-04「形式化で仮定するもの」）。例では、
`url` の欄を取り出して文字列の解析に渡す `urlTarget` を使う。誤り型 `Http.RequestCheckError` の構成子（問 23）、
`Result` の構成子、`Http.ClientRequest` のレコードの構成子はプログラムの側の宣言であり、仮定はそれらを宣言した
プログラム（`HasHttp`）について成り立つ。

検査の δ は、型の注釈に型の変数を含まない要求だけを保持する。δ の結果には `OutcomeTy` が `Val.VarsIn 0` を求め、
V-CheckedRequest の前提には置けない（`Val.VarsIn` は型付けの規則より後のモジュールで定義する）ためである。判定は、
`Val.VarsIn 0` の十分条件である計算できる判定 `groundVal`（定数・Bytes・リスト・構成子だけからなり、構成子の型引数が
基本の型・Bytes・データ型・リストだけからなる値。`groundVal_varsIn`）で行う。`Http.ClientRequest` のレコードの値は
この形であり、実装の要求についてこの判定は成り立つと読解では判断できる。型 `Http.ClientRequest` を持つ全ての値が
`groundVal` を満たすことは、Lean では示していない（標準形の補題は後の課題）。
-/

namespace Benitoite.Release.ModelHttp

open Benitoite.Release
open Scope.Domain (Range Target Kind)

-- `Result` の構成子の宣言と、表によらない補題は `ModelTargets` のものを使う（L50.3 の実例の整理）。
open Benitoite.Release.ModelTargets (okDecl errDecl ok_typed err_typed singleton_of_admissible ref_scoped_get ref_scoped_set)

def invalidUrlDecl : ConDecl := ⟨"Http.RequestCheckError", 0, [.base .string]⟩
def scopeDecl : ConDecl := ⟨"Http.RequestCheckError", 0, [TargetTable.scopeErrorTy]⟩

/-- `Http.ClientRequest` のレコードの欄 `headers` の要素の型 `Pair[String, String]`（データ型の名前はプログラムの側の
宣言の名前であり、ここでは `Pair` とする）。 -/
def pairTy : Ty := .data "Pair" [.base .string, .base .string]

/-- `Http.ClientRequest` のレコードの構成子。欄は Rust の `Http.bnt` の宣言の順に `method: String`、`url: String`、
`headers: List[Pair[String, String]]`、`body: Bytes`、`timeoutMilliseconds: Integer` である。データ型の名前は
`TargetTable.clientRequestTy` の名前と同じである。 -/
def clientRequestDecl : ConDecl :=
  ⟨"Http.ClientRequest", 0, [.base .string, .base .string, .list pairTy, .bytes, .base .integer]⟩

/-- プログラムが `Ok`・`Err`、`Http.RequestCheckError` の二つの構成子（問 23）と `Http.ClientRequest` のレコードの構成子を
宣言している。 -/
def HasHttp (P : Program) : Prop :=
  P.cons "Ok" = some okDecl ∧ P.cons "Err" = some errDecl ∧
    P.cons "Http.RequestCheckError.InvalidUrl" = some invalidUrlDecl ∧
    P.cons "Http.RequestCheckError.Scope" = some scopeDecl ∧
    P.cons "Http.ClientRequest" = some clientRequestDecl

/-- 検査の結果の型引数（範囲 r で具体化した `Result[Http.RequestIn[r], Http.RequestCheckError]` の引数）。 -/
def checkTys (r : Range) : List Ty := [.opaque "Http.RequestIn" (.fixed r), TargetTable.requestCheckErrorTy]

/-- 送信の結果の型引数（`Result[Http.Response, NetworkError]` の引数）。 -/
def sendTys : List Ty := [TargetTable.responseTy, TargetTable.networkErrorTy]

/-- 検査の失敗の値。URL の不良（要求から endpoint を得られない）と、範囲の失敗（パターン・端点・所属）。 -/
def invalidUrl : Val := .con "Http.RequestCheckError.InvalidUrl" [] [.const (.string "")]
def scopeFailure : Val := .con "Http.RequestCheckError.Scope" [] [.const (.opaque "Scope.ScopeError" 0)]

/-- 送信の応答の値と通信の失敗の値（不透明型の定数）。 -/
def response : Val := .const (.opaque "Http.Response" 0)
def networkFailure : Val := .const (.opaque "NetworkError" 0)

def defaultTimeout : Integer64Value := ⟨30000, by decide⟩

/-- 既定の要求のレコード（`Http.clientRequest("", "")` と同じ欄の値）。要求の射影は、要求を保持しない値（V-Checked で
`Http.RequestIn` を持つ検査済みの対象の値など）と、型の変数を含む要求を保持する値にこれを返す。 -/
def defaultRequest : Val :=
  .con "Http.ClientRequest" []
    [.const (.string ""), .const (.string ""), .list [], .bytesV [], .const (.integer defaultTimeout)]

/-- 要求のレコードの値の `url` の欄（第 1 欄）。 -/
def requestUrl : Val → Option String
  | .con "Http.ClientRequest" _ [_, .const (.string u), _, _, _] => some u
  | _ => none

/-- `url` の欄を取り出して文字列の解析 `parse` に渡す、要求から実効の endpoint を得る処理（例が `reqTarget` に使う）。 -/
def urlTarget (parse : String → Option Target) (v : Val) : Option Target :=
  (requestUrl v).bind parse

/-! ### 型の変数を含まない要求の判定 -/

mutual
  /-- 基本の型・Bytes・データ型・リストだけからなる型か。 -/
  def groundTy : Ty → Bool
    | .base _ | .bytes => true
    | .data _ args => groundTys args
    | .list a => groundTy a
    | _ => false

  def groundTys : List Ty → Bool
    | [] => true
    | a :: as => groundTy a && groundTys as
end

mutual
  /-- 定数・Bytes・リスト・構成子だけからなり、構成子の型引数が `groundTy` である値か。 -/
  def groundVal : Val → Bool
    | .const _ | .bytesV _ => true
    | .list elems => groundVals elems
    | .con _ tys args => groundTys tys && groundVals args
    | _ => false

  def groundVals : List Val → Bool
    | [] => true
    | v :: vs => groundVal v && groundVals vs
end

mutual
  theorem groundTy_varsIn {pe : Nat → Prop} : ∀ (t : Ty), groundTy t = true → Ty.VarsIn 0 0 pe t
    | .base _, _ => trivial
    | .bytes, _ => trivial
    | .data _ args, h => groundTys_varsIn args (by simpa [groundTy] using h)
    | .list a, h => groundTy_varsIn a (by simpa [groundTy] using h)
    | .opaque _ _, h | .fn _ _ _ _, h | .tvar _, h | .reference _, h | .lazy _, h | .cont _ _ _, h | .map _ _, h
    | .set _, h | .dict _ _, h | .tapp _ _, h | .ctor _, h => by simp [groundTy] at h

  theorem groundTys_varsIn {pe : Nat → Prop} : ∀ (ts : List Ty), groundTys ts = true → Ty.VarsInList 0 0 pe ts
    | [], _ => trivial
    | a :: as, h => by
        simp only [groundTys, Bool.and_eq_true] at h
        exact ⟨groundTy_varsIn a h.1, groundTys_varsIn as h.2⟩
end

mutual
  /-- `groundVal` は `Val.VarsIn 0` の十分条件である。 -/
  theorem groundVal_varsIn {pe : Nat → Prop} {d : Nat} : ∀ (v : Val), groundVal v = true → Val.VarsIn 0 pe v d
    | .const _, _ => by simp [Val.VarsIn]
    | .bytesV _, _ => by simp [Val.VarsIn]
    | .list elems, h => by
        simp only [Val.VarsIn]
        exact groundVals_varsIn elems (by simpa [groundVal] using h)
    | .con _ tys args, h => by
        simp only [groundVal, Bool.and_eq_true] at h
        simp only [Val.VarsIn]
        exact ⟨groundTys_varsIn tys h.1, groundVals_varsIn args h.2⟩
    | .var _, h | .fnRef _ _ _, h | .prim _ _ _ _, h | .lam _ _ _, h | .op _ _, h | .raise _ _, h | .loc _, h
    | .mapV _ _, h | .setV _, h | .dict _ _ _, h | .super _ _, h | .checked _, h | .checkedRequest _ _, h => by
        simp [groundVal] at h

  theorem groundVals_varsIn {pe : Nat → Prop} {d : Nat} :
      ∀ (vs : List Val), groundVals vs = true → Val.VarsInList 0 pe vs d
    | [], _ => by simp [Val.VarsInList]
    | v :: vs, h => by
        simp only [groundVals, Bool.and_eq_true] at h
        simp only [Val.VarsInList]
        exact ⟨groundVal_varsIn v h.1, groundVals_varsIn vs h.2⟩
end

/-- 要求の検査の δ（問 24 の 6、案 A）。要求 req が型の変数を含まず（`groundVal`）、ホストのパターンとポートの組から得た動的な範囲 q と、
具体化した範囲 r の両方に要求の実効の endpoint t が属し、種類が endpoint のときだけ、渡された要求 req をそのまま保持する
`Ok(checkedRequest(t, req))` を返す。要求から endpoint を得られなければ（型の変数を含む要求も）`InvalidUrl`、そのほかは
`Scope` の誤りを返す。 -/
def checkRun (hostPat : String → Int → Int → Option Range) (reqTarget : Val → Option Target)
    (r : Range) : List Val → Outcome
  | [.const (.string hp), .const (.integer lo), .const (.integer hi), req] =>
      if groundVal req then
        match reqTarget req with
        | none => .val (.con "Err" (checkTys r) [invalidUrl])
        | some t =>
            match hostPat hp lo.toInt hi.toInt with
            | some q =>
                if t.kind = .endpoint ∧ q.Mem t ∧ r.Mem t then .val (.con "Ok" (checkTys r) [.checkedRequest t req])
                else .val (.con "Err" (checkTys r) [scopeFailure])
            | none => .val (.con "Err" (checkTys r) [scopeFailure])
      else .val (.con "Err" (checkTys r) [invalidUrl])
  | _ => .val (.con "Err" (checkTys r) [invalidUrl])

/-- 要求の射影の δ。検査済みの要求の値から保持する要求のレコードをそのまま返す。要求を保持しない値と、型の変数を含む
要求を保持する値（検査の δ はどちらも作らない）には既定の要求を返す。 -/
def valueRun : List Val → Outcome
  | [.checkedRequest _ req] => if groundVal req then .val req else .val defaultRequest
  | _ => .val defaultRequest

/-- 送信の観測。最初の引数が保持する対象（検査済みの要求の値なら実効の endpoint）一つである。 -/
def firstTarget : List Val → List Target
  | v :: _ => v.target?.toList
  | [] => []

/-- 仮定を満たす組み込みの関数の表。 -/
def builtins (hostPat : String → Int → Int → Option Range) (reqTarget : Val → Option Target) :
    Builtins where
  sig := fun b =>
    if b = "Reference.get" then some Model.refGetSig
    else if b = "Reference.set" then some Model.refSetSig
    else if b = "Http.checkRequestIn" then some TargetTable.checkRequestIn
    else if b = "Http.requestInValue" then some TargetTable.requestInValue
    else if b = "Http.sendIn" then some TargetTable.sendIn
    else none
  delta := fun b _ _ rs ws =>
    if b = "Http.checkRequestIn" then
      match rs with
      | [r] => some (checkRun hostPat reqTarget r ws)
      | _ => none
    else if b = "Http.requestInValue" then some (valueRun ws)
    else none
  ioResponse := fun b _ _ ws o obs =>
    b = "Http.sendIn" ∧ (o = .val (.con "Ok" sendTys [response]) ∨ o = .val (.con "Err" sendTys [networkFailure])) ∧
      obs = firstTarget ws
  releaseResponse := fun _ r => r = none
  isResource := fun _ => false
  effects := fun l =>
    if l = stateEff then some []
    else if l = "Http.Connect" then some ["Http.sendIn"]
    else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"
  effKind := TargetTable.effKind
  valKind := TargetTable.valKind
  admitsR := fun b rs =>
    (b = "Http.checkRequestIn" ∨ b = "Http.requestInValue" ∨ b = "Http.sendIn") ∧ rs.length = 1
  valContent := TargetTable.valContent

section

variable {hostPat : String → Int → Int → Option Range} {reqTarget : Val → Option Target}

theorem sig_cases {b : PrimName} {s : PrimSig} (h : (builtins hostPat reqTarget).sig b = some s) :
    (b = "Reference.get" ∧ s = Model.refGetSig) ∨ (b = "Reference.set" ∧ s = Model.refSetSig) ∨
    (b = "Http.checkRequestIn" ∧ s = TargetTable.checkRequestIn) ∨
    (b = "Http.requestInValue" ∧ s = TargetTable.requestInValue) ∨ (b = "Http.sendIn" ∧ s = TargetTable.sendIn) := by
  simp only [builtins] at h
  split at h
  · cases h; exact .inl ⟨by assumption, rfl⟩
  split at h
  · cases h; exact .inr (.inl ⟨by assumption, rfl⟩)
  split at h
  · cases h; exact .inr (.inr (.inl ⟨by assumption, rfl⟩))
  split at h
  · cases h; exact .inr (.inr (.inr (.inl ⟨by assumption, rfl⟩)))
  split at h
  · cases h; exact .inr (.inr (.inr (.inr ⟨by assumption, rfl⟩)))
  · cases h

theorem effects_cases {l : EffName} {bs : List PrimName} (h : (builtins hostPat reqTarget).effects l = some bs) :
    (l = stateEff ∧ bs = []) ∨ (l = "Http.Connect" ∧ bs = ["Http.sendIn"]) := by
  simp only [builtins] at h
  split at h
  · cases h; exact .inl ⟨by assumption, rfl⟩
  split at h
  · cases h; exact .inr ⟨by assumption, rfl⟩
  · cases h

theorem sig_check : (builtins hostPat reqTarget).sig "Http.checkRequestIn" = some TargetTable.checkRequestIn := by
  simp [builtins]
theorem sig_value : (builtins hostPat reqTarget).sig "Http.requestInValue" = some TargetTable.requestInValue := by
  simp [builtins]
theorem sig_send : (builtins hostPat reqTarget).sig "Http.sendIn" = some TargetTable.sendIn := by simp [builtins]

theorem send_scoped : TargetTable.sendIn.Scoped :=
  TargetTable.entries_scoped ("Http.sendIn", _) (by
    unfold TargetTable.entries
    exact .tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.head _)))))))))

theorem check_scoped : TargetTable.checkRequestIn.Scoped :=
  TargetTable.entries_scoped ("Http.checkRequestIn", _) (by
    unfold TargetTable.entries
    exact .tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _
      (.head _)))))))))))

theorem value_scoped : TargetTable.requestInValue.Scoped :=
  TargetTable.entries_scoped ("Http.requestInValue", _) (by
    unfold TargetTable.entries
    exact .tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _
      (.tail _ (.head _)))))))))))))

theorem checkRequestIn_ret (r : Range) :
    Ty.subst [] [] (TargetTable.checkRequestIn.inst [r]).ret = .data "Result" (checkTys r) := by
  simp [TargetTable.checkRequestIn, TargetTable.pureIn, TargetTable.resultTy, TargetTable.requestIn, checkTys,
    TargetTable.requestCheckErrorTy, Ty.instR, Ty.rawInstR, Ty.norm, Ty.subst, Ty.substAt, Scope.Signature.Ix.inst]

theorem requestInValue_ret (r : Range) :
    Ty.subst [] [] (TargetTable.requestInValue.inst [r]).ret = TargetTable.clientRequestTy := by
  simp [TargetTable.requestInValue, TargetTable.pureIn, TargetTable.clientRequestTy, Ty.instR,
    Ty.rawInstR, Ty.rawInstRTys, Ty.norm, Ty.normTys, Ty.subst, Ty.substAt, Ty.substTysAt]

theorem sendIn_ret (r : Range) :
    Ty.subst [] [] (TargetTable.sendIn.inst [r]).ret = .data "Result" sendTys := by
  simp [TargetTable.sendIn, TargetTable.ioIn, TargetTable.resultTy, TargetTable.responseTy,
    TargetTable.networkErrorTy, sendTys, Ty.instR, Ty.rawInstR, Ty.norm, Ty.subst, Ty.substAt]

theorem checkRequestIn_params (r : Range) :
    (TargetTable.checkRequestIn.inst [r]).params.map (Ty.subst [] []) =
      [.base .string, .base .integer, .base .integer, TargetTable.clientRequestTy] := by
  simp [TargetTable.checkRequestIn, TargetTable.pureIn, TargetTable.clientRequestTy, Ty.instTarget,
    Ty.subst, Ty.substAt, Ty.substTysAt]

theorem requestIn_params (r : Range) :
    (TargetTable.requestInValue.inst [r]).params.map (Ty.subst [] []) = [.opaque "Http.RequestIn" (.fixed r)] := by
  simp [TargetTable.requestInValue, TargetTable.pureIn, TargetTable.requestIn, Ty.instTarget,
    Scope.Signature.Ix.inst, Ty.subst, Ty.substAt]

theorem sendIn_params (r : Range) :
    (TargetTable.sendIn.inst [r]).params.map (Ty.subst [] []) = [.opaque "Http.RequestIn" (.fixed r)] := by
  simp [TargetTable.sendIn, TargetTable.ioIn, TargetTable.requestIn, Ty.instTarget, Scope.Signature.Ix.inst,
    Ty.subst, Ty.substAt]

theorem invalidUrl_typed {P : Program} (hP : HasHttp P) {Ψ : StoreTy} :
    HasTypeV P (builtins hostPat reqTarget) Ψ [] [] invalidUrl TargetTable.requestCheckErrorTy :=
  .V_Con (cd := invalidUrlDecl) hP.2.2.1 rfl
    (.cons (by simpa [invalidUrlDecl, Const.type, Ty.subst, Ty.substAt] using
      (HasTypeVQ.V_Const (P := P) (B := builtins hostPat reqTarget) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
        (c := .string ""))) .nil)

theorem scopeFailure_typed {P : Program} (hP : HasHttp P) {Ψ : StoreTy} :
    HasTypeV P (builtins hostPat reqTarget) Ψ [] [] scopeFailure TargetTable.requestCheckErrorTy :=
  .V_Con (cd := scopeDecl) hP.2.2.2.1 rfl
    (.cons (by simpa [scopeDecl, TargetTable.scopeErrorTy, Const.type, Ty.subst, Ty.substAt, Ty.subst_opaque] using
      (HasTypeVQ.V_Const (P := P) (B := builtins hostPat reqTarget) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
        (c := .opaque "Scope.ScopeError" 0))) .nil)

theorem checkTys_closed (r : Range) (w : Val) (hw : Val.VarsIn 0 (fun _ => True) w) (c : ConName) :
    Val.VarsIn 0 (fun _ => True) (.con c (checkTys r) [w]) := by
  simp [checkTys, TargetTable.requestCheckErrorTy, Val.VarsIn, Ty.VarsInList, Ty.VarsIn, Val.VarsInList, hw]

theorem pairTy_wf : Ty.WF 0 0 pairTy := by simp [pairTy, Ty.WF, Ty.WFList]

/-- 既定の要求は `Http.ClientRequest` のレコードの型を持つ。 -/
theorem defaultRequest_typed {P : Program} (hP : HasHttp P) {B : Builtins} {Ψ : StoreTy} :
    HasTypeV P B Ψ [] [] defaultRequest TargetTable.clientRequestTy := by
  refine .V_Con (cd := clientRequestDecl) hP.2.2.2.2 rfl ?_
  simp only [clientRequestDecl, List.map, Ty.subst, Ty.substAt]
  refine .cons .V_Const (.cons .V_Const (.cons (.V_List .nil ?_) (.cons .V_Bytes (.cons .V_Const .nil))))
  simpa [pairTy, Ty.substAt, Ty.substTysAt] using pairTy_wf

theorem defaultRequest_closed : Val.VarsIn 0 (fun _ => True) defaultRequest := by
  simp [defaultRequest, Val.VarsIn, Val.VarsInList, Ty.VarsInList]

/-- 要求の検査の δ の結果は型 `Result[Http.RequestIn[r], Http.RequestCheckError]` を持つ。要求の引数が
`Http.ClientRequest` のレコードの型を持つことから、成功値は V-CheckedRequest で型付く（保持する要求の導出は、引数の導出
そのものである）。 -/
theorem checkRun_typed {P : Program} (hP : HasHttp P) {Ψ : StoreTy} (r : Range) (ws : List Val)
    (hw : HasTypeVs P (builtins hostPat reqTarget) Ψ [] [] ws
      [.base .string, .base .integer, .base .integer, TargetTable.clientRequestTy]) :
    OutcomeTy P (builtins hostPat reqTarget) Ψ (checkRun hostPat reqTarget r ws) (.data "Result" (checkTys r)) := by
  have herr : ∀ e, HasTypeV P (builtins hostPat reqTarget) Ψ [] [] e TargetTable.requestCheckErrorTy →
      Val.VarsIn 0 (fun _ => True) e →
      OutcomeTy P (builtins hostPat reqTarget) Ψ (.val (.con "Err" (checkTys r) [e])) (.data "Result" (checkTys r)) :=
    fun e he hc => ⟨err_typed hP.2.1 (by simpa [checkTys, TargetTable.requestCheckErrorTy, Ty.shift] using he),
      checkTys_closed r e hc _⟩
  have hinv := herr _ (invalidUrl_typed hP) (by simp [invalidUrl, Val.VarsIn, Ty.VarsInList, Val.VarsInList])
  have hsc := herr _ (scopeFailure_typed hP) (by simp [scopeFailure, Val.VarsIn, Ty.VarsInList, Val.VarsInList])
  unfold checkRun
  split
  · next hp lo hi req =>
      split
      · split
        · exact hinv
        · next t _ =>
            split
            · next q _ =>
                split
                · next hc =>
                    -- 要求の引数の導出が、V-CheckedRequest の保持する要求の前提になる。
                    have hreq : HasTypeV P (builtins hostPat reqTarget) Ψ [] [] req TargetTable.clientRequestTy := by
                      cases hw with
                      | cons _ hw => cases hw with
                        | cons _ hw => cases hw with
                          | cons _ hw => cases hw with
                            | cons h4 _ => exact h4
                    refine ⟨ok_typed hP.1 ?_, checkTys_closed r _ (by simp [Val.VarsIn]) _⟩
                    simpa [checkTys, Ty.shift_opaque] using
                      (HasTypeVQ.V_CheckedRequest (P := P) (B := builtins hostPat reqTarget) (Ψ := Ψ) (Q := Qempty)
                        (C := []) (Γ := []) (o := "Http.RequestIn") (R := r) (t := t) (req := req)
                        (T := TargetTable.clientRequestTy)
                        (by simp [builtins, TargetTable.valKind, hc.1]) hc.2.2 rfl hreq)
                · exact hsc
            · exact hsc
      · exact hinv
  · exact hinv

/-- 要求の検査の δ の契約（案 A。L40.2 の `CheckSpec.Contract` の要求の版）。`Ok` の成功値は検査済みの要求の値で
あり、渡された要求のレコード（型の変数を含まない値）をそのまま保持し、実効の endpoint は種類 endpoint を持ち、動的な
範囲 q と具体化した範囲 r の両方に属する。 -/
theorem checkRun_contract {r : Range} {ws : List Val} {ts : List Ty} {w : Val}
    (h : checkRun hostPat reqTarget r ws = .val (.con "Ok" ts [w])) :
    ∃ hp lo hi req q t, ws = [.const (.string hp), .const (.integer lo), .const (.integer hi), req] ∧
      groundVal req = true ∧ reqTarget req = some t ∧ hostPat hp lo.toInt hi.toInt = some q ∧
      w = .checkedRequest t req ∧ t.kind = .endpoint ∧ q.Mem t ∧ r.Mem t := by
  unfold checkRun at h
  split at h
  · next hp lo hi req =>
      split at h
      · next hcl =>
          split at h
          · simp at h
          · next t ht =>
              split at h
              · next q hq =>
                  split at h
                  · next hc =>
                      simp only [Outcome.val.injEq, Val.con.injEq, List.cons.injEq, and_true] at h
                      exact ⟨hp, lo, hi, req, q, t, rfl, hcl, ht, hq, by simp_all, hc⟩
                  · simp at h
              · simp at h
      · simp at h
  · simp at h

/-- 要求の射影の δ の結果は型 `Http.ClientRequest` を持つ。検査済みの要求の値なら、保持する要求のレコードそのもので
あり、その型付けは V-CheckedRequest の保持する要求の前提である。 -/
theorem valueRun_typed {P : Program} (hP : HasHttp P) {Ψ : StoreTy} (r : Range) (ws : List Val)
    (hw : HasTypeVs P (builtins hostPat reqTarget) Ψ [] [] ws [.opaque "Http.RequestIn" (.fixed r)]) :
    OutcomeTy P (builtins hostPat reqTarget) Ψ (valueRun ws) TargetTable.clientRequestTy := by
  have hdef : OutcomeTy P (builtins hostPat reqTarget) Ψ (.val defaultRequest) TargetTable.clientRequestTy :=
    ⟨defaultRequest_typed hP, defaultRequest_closed⟩
  unfold valueRun
  split
  · next req =>
      split
      · next hcl =>
          cases hw with
          | cons h1 _ =>
              obtain ⟨o, R, A, hT, -, -, hA, hc⟩ := h1.inv_checkedRequest rfl
              simp only [Ty.opaque.injEq] at hT
              obtain ⟨rfl, -⟩ := hT
              simp only [builtins, TargetTable.valContent, Option.some.injEq] at hA
              subst hA
              exact ⟨hc, groundVal_varsIn _ hcl⟩
      · exact hdef
  · exact hdef

end

/-- 実例: `Ok`・`Err` と `Http.RequestCheckError` の構成子を宣言したどのプログラムについても、旧の条件と対象一致の
条件の両方を満たす。 -/
theorem assumptions (hostPat : String → Int → Int → Option Range) (reqTarget : Val → Option Target) (P : Program)
    (hP : HasHttp P) : (builtins hostPat reqTarget).Assumptions P where
  sig_scoped := by
    intro b s h
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩
    · exact ref_scoped_get
    · exact ref_scoped_set
    · exact check_scoped
    · exact value_scoped
    · exact send_scoped
  admits_subst := by
    intro b s C0 C1 ts ts' es' h ha _ _
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | simpa [Model.refGetSig, Model.refSetSig] using ha
      | (simp only [TargetTable.checkRequestIn, TargetTable.requestInValue, TargetTable.sendIn, TargetTable.ioIn,
          TargetTable.pureIn] at ha ⊢
         subst ha; rfl)
  sat_subst := fun _ _ _ _ _ _ _ _ _ => trivial
  sat_unconstrained := fun _ _ => trivial
  admits_sat := by
    intro b s C ts h ha
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | exact ⟨by simpa [Model.refGetSig, Model.refSetSig] using ha, fun _ _ _ _ _ => trivial⟩
      | (simp only [TargetTable.checkRequestIn, TargetTable.requestInValue, TargetTable.sendIn, TargetTable.ioIn,
          TargetTable.pureIn] at ha ⊢
         subst ha
         exact ⟨rfl, fun _ _ _ h _ => by simp at h⟩)
  sat_local := fun _ _ _ _ _ _ => trivial
  admits_local := by
    intro b s C1 C0 ts h _ ha
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;> exact ha
  delta_typed := by
    intro Ψ b s rs ts es ws h hk hR htl hel _ hw
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨-, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.sendIn, TargetTable.ioIn] at hk)
    all_goals
      have hts : ts = [] := List.eq_nil_of_length_eq_zero htl
      have hes : es = [] := List.eq_nil_of_length_eq_zero hel
      subst hts hes
      obtain ⟨r, rfl⟩ := singleton_of_admissible rfl hR
    · refine ⟨checkRun hostPat reqTarget r ws, by simp [builtins], ?_, ?_⟩
      · intro n hn
        unfold checkRun at hn
        split at hn
        · split at hn
          · split at hn
            · cases hn
            · split at hn
              · split at hn <;> cases hn
              · cases hn
          · cases hn
        · cases hn
      · rw [checkRequestIn_ret]
        rw [checkRequestIn_params] at hw
        exact checkRun_typed hP r ws hw
    · refine ⟨valueRun ws, by simp [builtins], ?_, ?_⟩
      · intro n hn
        unfold valueRun at hn
        split at hn
        · split at hn <;> cases hn
        · cases hn
      · rw [requestInValue_ret]
        rw [requestIn_params] at hw
        exact valueRun_typed hP r ws hw
  io_kind := by
    intro b s ts es ws o obs h hr
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      simp only [builtins] at hr
    · simp at hr
    · simp at hr
    · simp at hr
    · simp at hr
    · obtain ⟨-, ho, -⟩ := hr
      refine .inl ⟨rfl, fun n => ?_⟩
      rcases ho with rfl | rfl <;> simp
  io_typed := by
    intro Ψ b s rs ts es ws o obs h hk hR htl hel _ _ hr
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkRequestIn, TargetTable.requestInValue,
        TargetTable.pureIn] at hk)
    have hts : ts = [] := List.eq_nil_of_length_eq_zero htl
    have hes : es = [] := List.eq_nil_of_length_eq_zero hel
    subst hts hes
    simp only [builtins] at hr
    obtain ⟨-, ho, -⟩ := hr
    obtain ⟨r, rfl⟩ := singleton_of_admissible rfl hR
    rw [sendIn_ret]
    rcases ho with rfl | rfl
    · exact ⟨ok_typed hP.1 (by simpa [sendTys, response, TargetTable.responseTy, Const.type, Ty.shift_opaque] using
          (HasTypeVQ.V_Const (P := P) (B := builtins hostPat reqTarget) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
            (c := .opaque "Http.Response" 0))),
        by simp [sendTys, response, TargetTable.responseTy, TargetTable.networkErrorTy, Val.VarsIn, Ty.VarsInList,
          Ty.VarsIn, Val.VarsInList]⟩
    · exact ⟨err_typed hP.2.1 (by simpa [sendTys, networkFailure, TargetTable.networkErrorTy, Const.type,
          Ty.shift_opaque] using
          (HasTypeVQ.V_Const (P := P) (B := builtins hostPat reqTarget) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
            (c := .opaque "NetworkError" 0))),
        by simp [sendTys, networkFailure, TargetTable.responseTy, TargetTable.networkErrorTy, Val.VarsIn,
          Ty.VarsInList, Ty.VarsIn, Val.VarsInList]⟩
  io_exists := by
    intro Ψ b s rs ts es ws h hk _ _ _ _ _
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkRequestIn, TargetTable.requestInValue,
        TargetTable.pureIn] at hk)
    exact ⟨_, _, rfl, .inl rfl, rfl⟩
  io_op := by
    intro b s h hk
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkRequestIn, TargetTable.requestInValue,
        TargetTable.pureIn] at hk)
    exact TargetTable.ioIn_shapeOk (bs := ["Http.sendIn"]) (by simp [builtins, stateEff]) (by simp) rfl rfl rfl
  effect_ops := by
    intro l bs b h hb
    rcases effects_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      simp only [List.mem_singleton, List.not_mem_nil] at hb
    subst hb; exact ⟨_, sig_send, .inl rfl, rfl⟩
  opEff_io := by
    intro b s l h hl
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkRequestIn, TargetTable.requestInValue,
          TargetTable.pureIn] at hl)
      | exact .inl rfl
  state_effect := by simp [builtins]
  store_shape := by
    intro b s h
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      simp [PrimSig.StoreShape, PrimSig.ntys, Model.refGetSig, Model.refSetSig, TargetTable.checkRequestIn,
        TargetTable.requestInValue, TargetTable.sendIn, TargetTable.ioIn, TargetTable.pureIn]
  store_admits := by
    intro b s C ts h h1 h2 h3 hl
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | simpa [PrimSig.ntys, Model.refGetSig, Model.refSetSig] using hl
      | (exfalso; simp [TargetTable.checkRequestIn, TargetTable.requestInValue, TargetTable.sendIn, TargetTable.ioIn,
          TargetTable.pureIn] at h1 h2 h3)
  ref_get := ⟨Model.refGetSig, by simp [builtins], rfl⟩
  ref_set := ⟨Model.refSetSig, by simp [builtins], rfl⟩
  release_exists := fun _ _ _ _ _ => ⟨none, rfl⟩
  io_target := by
    intro Ψ b s rs ts es ws o obs h hk _ _ _ _ _ hr
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      simp only [builtins] at hr
    · simp at hr
    · simp at hr
    · simp at hr
    · simp at hr
    · obtain ⟨-, -, rfl⟩ := hr
      -- 単一の対象の形: 最初の引数が対象を保持すれば観測はその対象一つ、そうでなければ旧 Top の形で空。
      match ws with
      | [] => simp [PrimSig.shapeAt, TargetTable.sendIn, TargetTable.ioIn, firstTarget,
          Scope.Signature.ShapeTargets]
      | v :: _ =>
          cases hv : v.target? with
          | none => simp [PrimSig.shapeAt, TargetTable.sendIn, TargetTable.ioIn, firstTarget, hv,
              Scope.Signature.ShapeTargets]
          | some t => simp [PrimSig.shapeAt, TargetTable.sendIn, TargetTable.ioIn, firstTarget, hv,
              Scope.Signature.ShapeTargets]

/-! ## 旧の像

L40.3b の前の表（`Model.builtins`）と L20.7 の実例の表（`ModelTargets.builtins`）は値が保持する要求の型を持たず
（`valContent` は既定の全て `none`）、検査済みの要求の値はそれらの表でどの型も持たない
（`HasTypeVQ.not_checkedRequest_of_noValContent`）。 -/

theorem model_noValContent : Model.builtins.NoValContent := fun _ => rfl

theorem modelTargets_noValContent (pat : String → Option Range) (tgt : String → Option Target) :
    (ModelTargets.builtins pat tgt).NoValContent := fun _ => rfl

/-! ## 検査した要求が `Http.sendIn` まで保たれること

一般の表の引数（`hostPat`・`reqTarget`）について示す。要求の検査の δ が `Ok(w)` を返すなら、w は渡された要求のレコード
req をそのまま保持し、射影 `Http.requestInValue` は w から同じ req を返す。w を `Http.sendIn` に渡したときの応答の関係の
観測は、検査で得た実効の endpoint t だけであり、t は具体化した範囲 r に属する。 -/

theorem check_send_preserves {hostPat : String → Int → Int → Option Range} {reqTarget : Val → Option Target}
    {r : Range} {hp : String} {lo hi : Integer64Value} {req : Val} {ts : List Ty} {w : Val}
    (h : checkRun hostPat reqTarget r [.const (.string hp), .const (.integer lo), .const (.integer hi), req] =
      .val (.con "Ok" ts [w])) :
    valueRun [w] = .val req ∧
      ∃ t, w = .checkedRequest t req ∧ reqTarget req = some t ∧ r.Mem t ∧
        (builtins hostPat reqTarget).ioResponse "Http.sendIn" [] [] [w] (.val (.con "Ok" sendTys [response])) [t] := by
  obtain ⟨hp', lo', hi', req', q, t, hws, hcl, ht, -, rfl, -, -, hr⟩ := checkRun_contract h
  simp only [List.cons.injEq, Val.const.injEq, Const.string.injEq, Const.integer.injEq, and_true] at hws
  obtain ⟨-, -, -, rfl⟩ := hws
  exact ⟨by simp [valueRun, hcl], t, rfl, ht, hr, rfl, .inl rfl, rfl⟩

/-! ## 例

`api.example.com:443` の範囲と、その範囲に属する要求のレコードを、例のための小さな関数 `hostPat`・`parseUrl` で与える。
要求から endpoint を得る処理は、`url` の欄を取り出して `parseUrl` に渡す `urlTarget parseUrl` である。 -/

namespace Examples

/-- `api.example.com` のポート 443 の範囲と、同じポートの `other.example.com` の範囲。 -/
def apiRange : Range := .endpoint ⟨.name (.exact ["api", "example", "com"]), ⟨443, 443⟩⟩
def otherRange : Range := .endpoint ⟨.name (.exact ["other", "example", "com"]), ⟨443, 443⟩⟩

/-- 要求の実効の endpoint `api.example.com:443`。 -/
def apiT : Target := .endpoint ⟨.name ["api", "example", "com"], 443⟩

def timeout30s : Integer64Value := ⟨30000, by decide⟩

/-- 欄 `headers` の要素 `Pair("Accept", "text/plain")`。 -/
def acceptHeader : Val :=
  .con "Pair" [.base .string, .base .string] [.const (.string "Accept"), .const (.string "text/plain")]

/-- 要求のレコード `Http.ClientRequest(method: "GET", url: "https://api.example.com/", headers: [acceptHeader],
body: Bytes.empty(), timeoutMilliseconds: 30000)` を作る。 -/
def mkReq (url : String) : Val :=
  .con "Http.ClientRequest" []
    [.const (.string "GET"), .const (.string url), .list [acceptHeader], .bytesV [], .const (.integer timeout30s)]

def apiUrl : String := "https://api.example.com/"

def req : Val := mkReq apiUrl

def hostPat : String → Int → Int → Option Range := fun hp lo hi =>
  if hp = "api.example.com" ∧ lo = 443 ∧ hi = 443 then some apiRange else none

/-- 例の URL の解析（形式化の外側の解析器の代わりの小さな関数）。 -/
def parseUrl (u : String) : Option Target := if u = apiUrl then some apiT else none

def reqTarget : Val → Option Target := urlTarget parseUrl

theorem reqTarget_req : reqTarget req = some apiT := by
  simp [reqTarget, urlTarget, requestUrl, req, mkReq, parseUrl]

theorem mkReq_closed (u : String) : groundVal (mkReq u) = true := rfl

theorem req_closed : groundVal req = true := mkReq_closed _

/-- 例の表。 -/
abbrev B : Builtins := builtins hostPat reqTarget

def port443 : Integer64Value := ⟨443, by decide⟩

def checkArgs : List Val :=
  [.const (.string "api.example.com"), .const (.integer port443), .const (.integer port443), req]

/-- 検査済みの要求の値。 -/
def checkedReq : Val := .checkedRequest apiT req

/-- 検査の δ は、パターン `api.example.com:443` を `[api.example.com:443]` で具体化すると、渡された要求をそのまま保持する
`Ok(checkedRequest(api.example.com:443, req))` を返す。 -/
theorem check_ok :
    B.delta "Http.checkRequestIn" [] [] [apiRange] checkArgs = some (.val (.con "Ok" (checkTys apiRange) [checkedReq])) := by
  have hc : apiT.kind = .endpoint ∧ apiRange.Mem apiT ∧ apiRange.Mem apiT := by decide
  simp [B, builtins, checkRun, checkArgs, checkedReq, hostPat, reqTarget_req, req_closed, port443,
    Integer64Value.toInt, hc]

/-- 具体化した R（`other.example.com:443`）が endpoint を含まなければ、動的な範囲が含んでも `Err` になる。 -/
theorem check_range_rejects :
    B.delta "Http.checkRequestIn" [] [] [otherRange] checkArgs =
      some (.val (.con "Err" (checkTys otherRange) [scopeFailure])) := by
  have hc : ¬ (apiT.kind = .endpoint ∧ apiRange.Mem apiT ∧ otherRange.Mem apiT) := by decide
  simp [B, builtins, checkRun, checkArgs, hostPat, reqTarget_req, req_closed, port443, Integer64Value.toInt, hc]

/-- 要求から endpoint を得られなければ `InvalidUrl` になる。 -/
theorem check_invalid_url :
    B.delta "Http.checkRequestIn" [] [] [apiRange]
        [.const (.string "api.example.com"), .const (.integer port443), .const (.integer port443),
          mkReq "not a url"] =
      some (.val (.con "Err" (checkTys apiRange) [invalidUrl])) := by
  have hu : parseUrl "not a url" = none := by simp [parseUrl, apiUrl]
  simp [B, builtins, checkRun, reqTarget, urlTarget, requestUrl, hu, mkReq]

/-- 射影は、検査済みの要求の値から保持する要求のレコード `req` を返す。 -/
theorem value_ok : B.delta "Http.requestInValue" [] [] [apiRange] [checkedReq] = some (.val req) := by
  simp [B, builtins, valueRun, checkedReq, req_closed]

/-- 検査した要求が `Http.sendIn` まで保たれる: 検査の δ の成功値を送信に渡すと、射影は同じ req を返し、送信の観測は
検査した endpoint だけである。 -/
theorem check_then_send :
    valueRun [checkedReq] = .val req ∧
      ∃ t, checkedReq = .checkedRequest t req ∧ reqTarget req = some t ∧ apiRange.Mem t ∧
        B.ioResponse "Http.sendIn" [] [] [checkedReq] (.val (.con "Ok" sendTys [response])) [t] := by
  have h : checkRun hostPat reqTarget apiRange checkArgs = .val (.con "Ok" (checkTys apiRange) [checkedReq]) := by
    have := check_ok
    simpa [B, builtins] using this
  exact check_send_preserves h

/-! ### 送信の呼び出しと対象健全性

`Result`・`Http.RequestCheckError`・`Http.ClientRequest`・`Pair` の構成子だけを宣言したプログラムで、`Http.sendIn[;;api.example.com:443](checkedReq)`
を初期の計算にする。 -/

/-- 例の `Pair` の構成子（型パラメータ二つ）。 -/
def pairDecl : ConDecl := ⟨"Pair", 2, [.tvar 0, .tvar 1]⟩

def httpCons : ConName → Option ConDecl := fun c =>
  if c = "Ok" then some okDecl
  else if c = "Err" then some errDecl
  else if c = "Http.RequestCheckError.InvalidUrl" then some invalidUrlDecl
  else if c = "Http.RequestCheckError.Scope" then some scopeDecl
  else if c = "Http.ClientRequest" then some clientRequestDecl
  else if c = "Pair" then some pairDecl
  else none

def httpProg : Program :=
  ⟨fun _ => none, httpCons, fun _ => none, fun _ => none, fun _ => none, fun _ => none⟩

theorem httpProg_hasHttp : HasHttp httpProg := by
  simp [HasHttp, httpProg, httpCons]

theorem httpProg_wellFormed : httpProg.WellFormed := by
  refine ⟨fun _ _ h => (by cases h), ?_, fun _ _ h => (by cases h), fun _ _ h => (by cases h),
    fun _ _ h => (by cases h)⟩
  intro c cd h
  simp only [httpProg, httpCons] at h
  split at h
  · cases h; simp [ConDecl.Scoped, okDecl, Ty.VarsInList, Ty.VarsIn]
  split at h
  · cases h; simp [ConDecl.Scoped, errDecl, Ty.VarsInList, Ty.VarsIn]
  split at h
  · cases h; simp [ConDecl.Scoped, invalidUrlDecl, Ty.VarsInList, Ty.VarsIn]
  split at h
  · cases h; simp [ConDecl.Scoped, scopeDecl, TargetTable.scopeErrorTy, Ty.VarsInList, Ty.VarsIn]
  split at h
  · cases h; simp [ConDecl.Scoped, clientRequestDecl, pairTy, Ty.VarsInList, Ty.VarsIn]
  split at h
  · cases h; simp [ConDecl.Scoped, pairDecl, Ty.VarsInList, Ty.VarsIn]
  · cases h

theorem httpProg_wellTyped : httpProg.WellTyped B :=
  ⟨fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

theorem httpProg_effectsOk : httpProg.EffectsOk B :=
  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

theorem httpProg_assumptions : B.Assumptions httpProg := assumptions hostPat reqTarget httpProg httpProg_hasHttp

def sendCall : Comp := .app (.prim "Http.sendIn" [] [] [apiRange]) [checkedReq]

theorem send_admissible : B.RangeAdmissible "Http.sendIn" TargetTable.sendIn [apiRange] := by
  refine ⟨⟨?_, ?_, Or.inr ⟨Or.inr (Or.inr rfl), rfl⟩⟩, ?_⟩
  · exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

theorem send_prim_admissible : PrimitiveAdmissible [] (TargetTable.sendIn.inst [apiRange]) Qempty [] [] :=
  PrimitiveAdmissible.of_noRows_inst send_scoped (by decide) rfl rfl rfl (by simp)

theorem acceptHeader_typed {Ψ : StoreTy} : HasTypeV httpProg B Ψ [] [] acceptHeader pairTy :=
  .V_Con (cd := pairDecl) (by simp [httpProg, httpCons]) rfl
    (.cons (by simp only [Ty.subst, Ty.substAt]; exact .V_Const)
      (.cons (by simp only [Ty.subst, Ty.substAt]; exact .V_Const) .nil))

/-- 要求のレコードは `Http.ClientRequest` の型を持つ（V-Con。五つの欄の型は `clientRequestDecl` の欄の型）。 -/
theorem mkReq_typed {Ψ : StoreTy} (u : String) :
    HasTypeV httpProg B Ψ [] [] (mkReq u) TargetTable.clientRequestTy := by
  refine .V_Con (cd := clientRequestDecl) (by simp [httpProg, httpCons]) rfl ?_
  simp only [clientRequestDecl, List.map, Ty.subst, Ty.substAt]
  refine .cons .V_Const (.cons .V_Const (.cons ?_ (.cons .V_Bytes (.cons .V_Const .nil))))
  refine .V_List (.cons ?_ .nil) ?_
  · simpa [pairTy, Ty.subst, Ty.substAt, Ty.substTysAt] using acceptHeader_typed
  · simpa [pairTy, Ty.substAt, Ty.substTysAt] using pairTy_wf

/-- 検査済みの要求の値は `Http.RequestIn[api.example.com:443]` の型を持つ（V-CheckedRequest。保持するレコードの導出は
`mkReq_typed`）。 -/
theorem checkedReq_typed {Ψ : StoreTy} :
    HasTypeV httpProg B Ψ [] [] checkedReq (.opaque "Http.RequestIn" (.fixed apiRange)) :=
  .V_CheckedRequest (T := TargetTable.clientRequestTy) rfl (by decide) rfl (mkReq_typed _)

/-- 構成子 `Http.ClientRequest` を宣言しないプログラム（`Model.emptyProgram`）では、検査済みの要求の値はどの型も
持たない。保持する要求の型付けはプログラムの宣言による。 -/
theorem checkedReq_not_typed_empty {Ψ : StoreTy} {Q : NoFailCtx} {C : List TParam} {Γ : List (Option Ty)} {T : Ty} :
    ¬ HasTypeVQ Model.emptyProgram B Ψ Q C Γ checkedReq T := by
  intro h
  obtain ⟨o, R, A, -, -, -, -, hr⟩ := h.inv_checkedRequest rfl
  obtain ⟨cd, hc, -⟩ := hr.inv_con rfl
  simp [Model.emptyProgram] at hc

/-- 別の範囲 `other.example.com:443` の型は持たない。 -/
theorem checkedReq_not_other {P : Program} {Ψ : StoreTy} :
    ¬ HasTypeV P B Ψ [] [] checkedReq (.opaque "Http.RequestIn" (.fixed otherRange)) := by
  intro h
  obtain ⟨o, R, n, hT, -, hm, -, -⟩ := h.inv_checkedRequest rfl
  simp only [Ty.opaque.injEq, Scope.Signature.Ix.fixed.injEq] at hT
  obtain ⟨rfl, rfl⟩ := hT
  revert hm; decide

theorem sendCall_args {Ψ : StoreTy} :
    HasTypeVs httpProg B Ψ [] [] [checkedReq] ((TargetTable.sendIn.inst [apiRange]).params.map (Ty.subst [] [])) := by
  rw [sendIn_params]
  exact .cons checkedReq_typed .nil

theorem sendCall_typed {Ψ : StoreTy} :
    HasTypeC httpProg B Ψ [] [] none sendCall (Ty.subst [] [] (TargetTable.sendIn.inst [apiRange]).ret)
      (Eff.substAt 0 [] [] (TargetTable.sendIn.inst [apiRange]).eff) := by
  have hv := HasTypeVQ.V_Prim (P := httpProg) (B := B) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
    (b := "Http.sendIn") (s := TargetTable.sendIn) (rs := [apiRange]) (ts := []) (es := [])
    sig_send send_admissible ⟨rfl, by decide⟩ send_prim_admissible
  rw [fnTy_eq] at hv
  exact .C_App hv sendCall_args

/-- 送信の効果は `Http.Connect[api.example.com:443]` である。 -/
theorem send_eff : Eff.substAt 0 [] [] (TargetTable.sendIn.inst [apiRange]).eff =
    Eff.singleAt "Http.Connect" (.fixed apiRange) := by
  rw [PrimSig.inst_eff]
  simp only [TargetTable.sendIn, TargetTable.ioIn, Eff.instR_singleAt]
  exact ModelTargets.Examples.substAt_singleAt _ _

theorem sendCall_closed : sendCall.ClosedNoEffVars := by
  simp [sendCall, checkedReq, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Eff.VarsInList,
    Val.VarsInList]

def sendState : State := .run sendCall [] Store.empty

/-- 送信の呼び出しの状態は、末尾に `{Http.Connect[api.example.com:443]}` を固定した状態の型付けを持つ。 -/
theorem sendState_typedE : StateTyE httpProg B (Eff.singleAt "Http.Connect" (.fixed apiRange)) sendState := by
  have h := stateTyE_init_eff httpProg_wellFormed httpProg_assumptions.core sendCall_typed sendCall_closed
  rwa [send_eff] at h

/-- 処理する節がないので、応答の関係で進み、事象は検査済みの要求の値を引数に持ち、観測は検査した endpoint 一つ
である（リダイレクトを追わない）。 -/
theorem sendState_step :
    Step httpProg B sendState
      (some (.io "Http.sendIn" [checkedReq] (.val (.con "Ok" sendTys [response])) [apiT]))
      (.run (.ret (.con "Ok" sendTys [response])) [] Store.empty) :=
  .E_IO (s := TargetTable.sendIn) sig_send rfl (fun _ h => by cases h) ⟨rfl, .inl rfl, rfl⟩

/-- 遷移の水準でも同じである: 検査の呼び出しは E-Prim で `Ok(checkedReq)` に進み、その成功値 `checkedReq` の送信の
事象（`sendState_step`）は同じ要求を保持する値を引数に持ち、射影の呼び出しは同じ `req` に進む。 -/
theorem check_step {σ : Store} :
    Step httpProg B (.run (.app (.prim "Http.checkRequestIn" [] [] [apiRange]) checkArgs) [] σ) none
      (.run (.ret (.con "Ok" (checkTys apiRange) [checkedReq])) [] σ) :=
  .E_Prim sig_check rfl check_ok

theorem value_step {σ : Store} :
    Step httpProg B (.run (.app (.prim "Http.requestInValue" [] [] [apiRange]) [checkedReq]) [] σ) none
      (.run (.ret req) [] σ) :=
  .E_Prim sig_value rfl value_ok

/-- 射影の後に欄を読む。射影が返した要求のレコードを、`url` の欄だけを束縛する選択肢で照合する（表層の欄の参照
`request.url` の脱糖と同じ構成子の照合）。 -/
def urlAlt : Alt := ⟨.con "Http.ClientRequest" [.wild, .var, .wild, .wild, .wild], [0]⟩
def urlArm : Arm := .mk [urlAlt] none (.ret (.var 0))

theorem url_match : firstAlt req [urlAlt] = some [.const (.string apiUrl)] := rfl

/-- 射影の呼び出しは保持したレコード `req` に進み（`value_step`）、その照合は検査した要求の `url` の文字列に進む。 -/
theorem read_url_steps {k : Cont} {σ : Store} :
    Step httpProg B (.run (.match req [urlArm]) k σ) none (.matchRun req [urlArm] 0 k σ) ∧
      Step httpProg B (.matchRun req [urlArm] 0 k σ) none (.run (.ret (.const (.string apiUrl))) k σ) :=
  ⟨.E_Match, .E_MatchBody (alts := [urlAlt]) (body := .ret (.var 0)) rfl url_match⟩

/-- 射影の結果の型は `Http.ClientRequest` のレコードの型であり、`url` の欄（第 1 欄）は String を持つ。 -/
theorem projected_url_typed {Ψ : StoreTy} :
    ∃ cd, httpProg.cons "Http.ClientRequest" = some cd ∧ cd.args[1]? = some (.base .string) ∧
      HasTypeV httpProg B Ψ [] [] req TargetTable.clientRequestTy :=
  ⟨clientRequestDecl, by simp [httpProg, httpCons], rfl, mkReq_typed _⟩

/-- 対象一致の条件の単一の対象の形（endpoint）: 観測は対象の位置の引数が保持する endpoint ちょうど一つである。 -/
theorem send_io_target :
    Scope.Signature.ShapeTargets Val.target? (TargetTable.sendIn.shapeAt [checkedReq]) [checkedReq] [apiT] :=
  httpProg_assumptions.io_target StoreTy.empty "Http.sendIn" TargetTable.sendIn [apiRange] [] [] [checkedReq]
    (.val (.con "Ok" sendTys [response])) [apiT] sig_send (.inl rfl) send_admissible rfl rfl rfl sendCall_args
    ⟨rfl, .inl rfl, rfl⟩

/-- 一段の対象健全性を Http の項目に当てる。観測した endpoint `api.example.com:443` は、末尾の効果の
`Http.Connect` の原子が許す。 -/
theorem sendState_target_sound :
    ∀ t ∈ [apiT], B.Allows (Eff.singleAt "Http.Connect" (.fixed apiRange)) "Http.Connect" t := by
  obtain ⟨e, l, he, hl, h⟩ := step_target_sound httpProg_effectsOk httpProg_assumptions.core
    httpProg_assumptions.target sendState_typedE sendState_step
  rw [sig_send] at he
  cases he
  cases hl
  exact h

/-- 到達先の対象健全性を Http の項目に当てる。初期の効果 `{Http.Connect[api.example.com:443]}` で型付いた初期状態
（到達は零歩）から起こる送信の事象の観測は、初期の効果の `Http.Connect` の原子が許す。 -/
theorem sendState_reachable_target_sound :
    ∀ t ∈ [apiT], B.Allows (Eff.substAt 0 [] [] (TargetTable.sendIn.inst [apiRange]).eff) "Http.Connect" t := by
  obtain ⟨e, l, he, hl, h⟩ := reachable_target_sound httpProg_wellFormed httpProg_wellTyped httpProg_effectsOk
    httpProg_assumptions.core httpProg_assumptions.target sendCall_typed sendCall_closed .refl sendState_step
  rw [sig_send] at he
  cases he
  cases hl
  exact h

/-- 観測した endpoint は、効果の範囲の外の endpoint ではない: 範囲 `other.example.com:443` の `Http.Connect` は
`api.example.com:443` を許さない。 -/
theorem other_not_allows :
    ¬ B.Allows (Eff.singleAt "Http.Connect" (.fixed otherRange)) "Http.Connect" apiT := by
  rintro ⟨k, ix, -, hmem, hk⟩
  rw [Eff.mem_singleAt] at hmem
  simp only [Atom.name.injEq, Scope.Signature.Ix.fixed.injEq, true_and] at hmem
  subst hmem
  cases k <;> revert hk <;> decide

end Examples

end Benitoite.Release.ModelHttp
