import Benitoite.Release.TargetTable
import Benitoite.Release.Lemmas.TargetSound
import Benitoite.Release.Lemmas.PrimRanges

/-!
# 二つの信頼条件を満たす組み込みの関数の実例（L20.7）

`Model.assumptions`（IO を持たない表）の新版である（RV-L00 軽6）。旧の条件 `CoreAssumptions` と対象一致の条件
`TargetAgreement` の両方を満たす組み込みの関数の表を一つ作り、定理の前提が空虚に成り立っていないことを確かめる。
表の項目は次の六つである。

| 項目 | 種類 | 形 | 署名 | δ・応答・観測 |
|---|---|---|---|---|
| `Reference.get`・`Reference.set` | 可変のセル | — | `Model` と同じ | ストアの規則 |
| `Scope.checkPathIn` | pure | — | 問 22 の表（`TargetTable.checkPathIn`） | 動的なパターンと具体化した R の両方を確かめる（問 24 の 6） |
| `print` | io | 対象なし | `(text: String) -> Unit uses Console.Write` | `()`、観測は空 |
| `exit` | exit | 対象なし | `(code: Integer) -> Unit uses Process.Exit` | `exit(n)`、観測は空 |
| `File.writeTextIn` | io | 単一の対象 | 問 22 の表（`TargetTable.writeTextIn`） | `Ok(())` か `Err(e)`、観測は最初の引数の対象一つ |
| `File.readText` | io | 旧 Top（`topTargeted .path`） | `(path: String) -> Result[String, IOError] uses File.Read` | `Ok("")` か `Err(e)`、観測は文字列の引数を解析した path の対象（RV-L40 軽8） |

文字列のパターンと対象の解析は形式化の外側であり、関数 `pat`・`tgt` を引数に取る。`Result` の構成子はプログラムの
側の宣言であり、仮定は `Ok`・`Err` を宣言したプログラム（`HasResult`）について成り立つ。範囲付きの値型は資源の型に
しない。資源の型は不透明型 `File.Handle` 一つであり、解放の応答は常に `none` である（`release_exists` の前提を満たす
値があることは `handle_release`。RV-L40 軽8）。範囲付きの IO の項目を持つこの表で、範囲付きの効果を宣言したプログラムに `progress` を当てる例と、L20.1 の
反例の状態が案 BA の `BuiltinOnly` のもとで `StateTy` に入る例を末尾に置く。

三つの実例の表の役割（L50.3 の整理）: `Model.assumptions` は対象の種類を持たない表（旧の像。範囲付きの値型も IO の
項目も持たない）、本ファイルの `ModelTargets.assumptions` は `Scope.checkPathIn`・`File.writeTextIn` の範囲付きの
項目、`Release.ModelHttp.assumptions` は Http の三項目を持つ。Http の項目を本ファイルの表に足さず別の表にしたのは、
本ファイルの仮定の証明を三項目の分だけ広げるより、同じ形の別の表にするほうが小さいためである（L40.3b）。`Result` の
構成子の宣言と表によらない補題（`okDecl`・`errDecl`・`ok_typed`・`err_typed`・`singleton_of_admissible`・
`ref_scoped_get`・`ref_scoped_set`）は本ファイルにだけ置き、`ModelHttp` はそれを使う。
-/

namespace Benitoite.Release.ModelTargets

open Benitoite.Release
open Scope.Domain (Range Target Kind)

/-- `Result` の構成子の宣言（プログラムの側）。 -/
def okDecl : ConDecl := ⟨"Result", 2, [.tvar 0]⟩
def errDecl : ConDecl := ⟨"Result", 2, [.tvar 1]⟩

/-- プログラムが `Ok`・`Err` を `Result` の構成子として宣言している。 -/
def HasResult (P : Program) : Prop := P.cons "Ok" = some okDecl ∧ P.cons "Err" = some errDecl

def printSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["text"]
  params := [.base .string]
  ret := .base .unit
  eff := Eff.single "Console.Write"
  admits := fun _ ts => ts = []
  kind := .io
  opEff := some "Console.Write"

/-- 旧 Top の形の IO の項目 `File.readText(path: String) -> Result[String, IOError] uses File.Read`。範囲の変数を
持たず、効果は Top の原子一つ、観測は種類 path の対象だけである（`topTargeted .path`）。 -/
def readTextSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["path"]
  params := [.base .string]
  ret := .data "Result" [.base .string, TargetTable.ioErrorTy]
  eff := Eff.single "File.Read"
  admits := fun _ ts => ts = []
  kind := .io
  opEff := some "File.Read"
  shape := .topTargeted .path

def exitSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["code"]
  params := [.base .integer]
  ret := .base .unit
  eff := Eff.single "Process.Exit"
  admits := fun _ ts => ts = []
  kind := .exit
  opEff := some "Process.Exit"

/-- 検査の失敗と書き込みの失敗の値（不透明型の定数）。 -/
def scopeFailure : Val := .const (.opaque "Scope.ScopeError" 0)
def ioFailure : Val := .const (.opaque "IOError" 0)

/-- 検査の結果の型引数（範囲 r で具体化した `Result[Scope.PathIn[r], Scope.ScopeError]` の引数）。 -/
def checkTys (r : Range) : List Ty := [.opaque "Scope.PathIn" (.fixed r), TargetTable.scopeErrorTy]

/-- 書き込みの結果の型引数（`Result[Unit, IOError]` の引数）。 -/
def writeTys : List Ty := [.base .unit, TargetTable.ioErrorTy]

/-- 読み込みの結果の型引数（`Result[String, IOError]` の引数）。 -/
def readTys : List Ty := [.base .string, TargetTable.ioErrorTy]

/-- 旧 Top の読み込みの観測。文字列の引数を解析した対象が種類 path なら、その対象一つである。 -/
def readObs (tgt : String → Option Target) : List Val → List Target
  | [.const (.string raw)] =>
      match tgt raw with
      | some t => if t.kind = .path then [t] else []
      | none => []
  | _ => []

/-- 検査の δ（問 24 の 6、案 A）。動的なパターン q と具体化した範囲 r の両方に対象が属し、種類が path のときだけ
`Ok(checked(t))` を返す。それ以外は `Err` を返す。 -/
def checkRun (pat : String → Option Range) (tgt : String → Option Target) (r : Range) : List Val → Outcome
  | [.const (.string ps), .const (.string raw)] =>
      match pat ps, tgt raw with
      | some q, some t =>
          if t.kind = .path ∧ q.Mem t ∧ r.Mem t then .val (.con "Ok" (checkTys r) [.checked t])
          else .val (.con "Err" (checkTys r) [scopeFailure])
      | _, _ => .val (.con "Err" (checkTys r) [scopeFailure])
  | _ => .val (.con "Err" (checkTys r) [scopeFailure])

/-- 書き込みの観測。最初の引数が検査済みの対象の値（か検査済みの要求の値）なら、その対象一つである。 -/
def firstTarget : List Val → List Target
  | .checked t :: _ => [t]
  | .checkedRequest t _ :: _ => [t]
  | _ => []

def exitCode : List Val → Int
  | [.const (.integer n)] => n.toInt
  | _ => 1

/-- 仮定を満たす組み込みの関数の表。 -/
def builtins (pat : String → Option Range) (tgt : String → Option Target) : Builtins where
  sig := fun b =>
    if b = "Reference.get" then some Model.refGetSig
    else if b = "Reference.set" then some Model.refSetSig
    else if b = "print" then some printSig
    else if b = "exit" then some exitSig
    else if b = "File.writeTextIn" then some TargetTable.writeTextIn
    else if b = "Scope.checkPathIn" then some TargetTable.checkPathIn
    else if b = "File.readText" then some readTextSig
    else none
  delta := fun b _ _ rs ws =>
    if b = "Scope.checkPathIn" then
      match rs with
      | [r] => some (checkRun pat tgt r ws)
      | _ => none
    else none
  ioResponse := fun b _ _ ws o obs =>
    (b = "print" ∧ o = .val (.const .unit) ∧ obs = []) ∨
    (b = "exit" ∧ o = .exit (exitCode ws) ∧ obs = []) ∨
    (b = "File.writeTextIn" ∧
      (o = .val (.con "Ok" writeTys [.const .unit]) ∨ o = .val (.con "Err" writeTys [ioFailure])) ∧
      obs = firstTarget ws) ∨
    (b = "File.readText" ∧
      (o = .val (.con "Ok" readTys [.const (.string "")]) ∨ o = .val (.con "Err" readTys [ioFailure])) ∧
      obs = readObs tgt ws)
  releaseResponse := fun _ r => r = none
  isResource := fun o => o == "File.Handle"
  effects := fun l =>
    if l = stateEff then some []
    else if l = "Console.Write" then some ["print"]
    else if l = "Process.Exit" then some ["exit"]
    else if l = "File.Write" then some ["File.writeTextIn"]
    else if l = "File.Read" then some ["File.readText"]
    else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"
  effKind := TargetTable.effKind
  valKind := TargetTable.valKind
  admitsR := fun b rs => (b = "File.writeTextIn" ∨ b = "Scope.checkPathIn") ∧ rs.length = 1

section

variable {pat : String → Option Range} {tgt : String → Option Target}

theorem sig_cases {b : PrimName} {s : PrimSig} (h : (builtins pat tgt).sig b = some s) :
    (b = "Reference.get" ∧ s = Model.refGetSig) ∨ (b = "Reference.set" ∧ s = Model.refSetSig) ∨
    (b = "print" ∧ s = printSig) ∨ (b = "exit" ∧ s = exitSig) ∨
    (b = "File.writeTextIn" ∧ s = TargetTable.writeTextIn) ∨ (b = "Scope.checkPathIn" ∧ s = TargetTable.checkPathIn) ∨
    (b = "File.readText" ∧ s = readTextSig) := by
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
  · cases h; exact .inr (.inr (.inr (.inr (.inl ⟨by assumption, rfl⟩))))
  split at h
  · cases h; exact .inr (.inr (.inr (.inr (.inr (.inl ⟨by assumption, rfl⟩)))))
  split at h
  · cases h; exact .inr (.inr (.inr (.inr (.inr (.inr ⟨by assumption, rfl⟩)))))
  · cases h

theorem effects_cases {l : EffName} {bs : List PrimName} (h : (builtins pat tgt).effects l = some bs) :
    (l = stateEff ∧ bs = []) ∨ (l = "Console.Write" ∧ bs = ["print"]) ∨ (l = "Process.Exit" ∧ bs = ["exit"]) ∨
    (l = "File.Write" ∧ bs = ["File.writeTextIn"]) ∨ (l = "File.Read" ∧ bs = ["File.readText"]) := by
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

theorem sig_print : (builtins pat tgt).sig "print" = some printSig := by simp [builtins]
theorem sig_exit : (builtins pat tgt).sig "exit" = some exitSig := by simp [builtins]
theorem sig_write : (builtins pat tgt).sig "File.writeTextIn" = some TargetTable.writeTextIn := by simp [builtins]
theorem sig_check : (builtins pat tgt).sig "Scope.checkPathIn" = some TargetTable.checkPathIn := by simp [builtins]
theorem sig_read : (builtins pat tgt).sig "File.readText" = some readTextSig := by simp [builtins]

theorem printSig_scoped : printSig.Scoped := by
  simp [PrimSig.Scoped, printSig, PrimSig.ntys, PrimSig.nranges, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.VarsIn,
    Eff.single, Eff.ofAtoms]

theorem exitSig_scoped : exitSig.Scoped := by
  simp [PrimSig.Scoped, exitSig, PrimSig.ntys, PrimSig.nranges, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.VarsIn,
    Eff.single, Eff.ofAtoms]

theorem readTextSig_scoped : readTextSig.Scoped := by
  simp [PrimSig.Scoped, readTextSig, PrimSig.ntys, PrimSig.nranges, NamesWF, Ty.VarsInList, Ty.VarsIn, Eff.VarsIn,
    Eff.single, Eff.ofAtoms, TargetTable.ioErrorTy]

theorem write_scoped : TargetTable.writeTextIn.Scoped :=
  TargetTable.entries_scoped ("File.writeTextIn", _) (by
    unfold TargetTable.entries
    exact .tail _ (.tail _ (.tail _ (.tail _ (.head _)))))

theorem check_scoped : TargetTable.checkPathIn.Scoped :=
  TargetTable.entries_scoped ("Scope.checkPathIn", _) (by
    unfold TargetTable.entries
    exact .tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.tail _ (.head _))))))))))

/-- 範囲の列の許容から、一つの範囲の項目の列は一つの範囲である。 -/
theorem singleton_of_admissible {B : Builtins} {b : PrimName} {s : PrimSig} {rs : List Range} {k : Kind}
    (hk : s.rkinds = [k]) (h : B.RangeAdmissible b s rs) : ∃ r, rs = [r] := by
  have hlen := h.length
  rw [PrimSig.nranges, hk] at hlen
  match rs, hlen with
  | [r], _ => exact ⟨r, rfl⟩

theorem checkPathIn_ret (r : Range) :
    Ty.subst [] [] (TargetTable.checkPathIn.inst [r]).ret =
      .data "Result" [.opaque "Scope.PathIn" (.fixed r), TargetTable.scopeErrorTy] := by
  simp [TargetTable.checkPathIn, TargetTable.pureIn, TargetTable.resultTy, TargetTable.pathIn,
    TargetTable.scopeErrorTy, Ty.instR, Ty.rawInstR, Ty.norm, Ty.subst, Ty.substAt, Scope.Signature.Ix.inst]

theorem writeTextIn_ret (r : Range) :
    Ty.subst [] [] (TargetTable.writeTextIn.inst [r]).ret = .data "Result" writeTys := by
  simp [TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.resultTy, TargetTable.ioErrorTy, writeTys,
    Ty.instR, Ty.rawInstR, Ty.norm, Ty.subst, Ty.substAt]

theorem unit_ret (rs : List Range) (s : PrimSig) (h : s.ret = .base .unit) :
    Ty.subst [] [] (s.inst rs).ret = .base .unit := by
  simp [h, Ty.instR, Ty.rawInstR, Ty.norm, Ty.subst, Ty.substAt]

/-- 結果の型の `Ok` の値の型付け。表によらない（`ModelHttp` も使う）。 -/
theorem ok_typed {P : Program} {B : Builtins} (hP : P.cons "Ok" = some okDecl) {Ψ : StoreTy} {a e : Ty} {v : Val}
    (hv : HasTypeV P B Ψ [] [] v (Ty.shift 0 0 a)) :
    HasTypeV P B Ψ [] [] (.con "Ok" [a, e] [v]) (.data "Result" [a, e]) :=
  .V_Con (cd := okDecl) hP rfl (.cons (by simpa [okDecl, Ty.subst, Ty.substAt] using hv) .nil)

/-- `Err` の値の型付け。表によらない（`ModelHttp` も使う）。 -/
theorem err_typed {P : Program} {B : Builtins} (hP : P.cons "Err" = some errDecl) {Ψ : StoreTy} {a e : Ty} {v : Val}
    (hv : HasTypeV P B Ψ [] [] v (Ty.shift 0 0 e)) :
    HasTypeV P B Ψ [] [] (.con "Err" [a, e] [v]) (.data "Result" [a, e]) :=
  .V_Con (cd := errDecl) hP rfl (.cons (by simpa [errDecl, Ty.subst, Ty.substAt] using hv) .nil)

theorem scopeError_closed : Ty.VarsIn 0 0 (fun _ => True) TargetTable.scopeErrorTy := by
  simp [TargetTable.scopeErrorTy, Ty.VarsIn]

/-- 検査の δ の結果は型 `Result[Scope.PathIn[r], Scope.ScopeError]` を持つ。成功値の所属は δ の確かめだけから従う。 -/
theorem checkRun_typed {P : Program} (hP : HasResult P) {Ψ : StoreTy} (r : Range) (ws : List Val) :
    OutcomeTy P (builtins pat tgt) Ψ (checkRun pat tgt r ws)
      (.data "Result" [.opaque "Scope.PathIn" (.fixed r), TargetTable.scopeErrorTy]) := by
  have herr : OutcomeTy P (builtins pat tgt) Ψ (.val (.con "Err" (checkTys r) [scopeFailure]))
      (.data "Result" [.opaque "Scope.PathIn" (.fixed r), TargetTable.scopeErrorTy]) :=
    ⟨err_typed hP.2 (by simpa [checkTys, scopeFailure, TargetTable.scopeErrorTy, Const.type, Ty.shift_opaque] using
        (HasTypeVQ.V_Const (P := P) (B := builtins pat tgt) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
          (c := .opaque "Scope.ScopeError" 0))),
      by simp [checkTys, scopeFailure, TargetTable.scopeErrorTy, Val.VarsIn, Ty.VarsInList, Ty.VarsIn, Val.VarsInList]⟩
  unfold checkRun
  split
  · next ps raw =>
      split
      · next q t _ _ =>
          split
          · next hc =>
              refine ⟨ok_typed hP.1 ?_, ?_⟩
              · simpa [checkTys, Ty.shift_opaque] using
                  (HasTypeVQ.V_Checked (P := P) (B := builtins pat tgt) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
                    (o := "Scope.PathIn") (R := r) (t := t)
                    (by simp [builtins, TargetTable.valKind, hc.1]) hc.2.2)
              · simp [checkTys, TargetTable.scopeErrorTy, Val.VarsIn, Ty.VarsInList, Ty.VarsIn, Val.VarsInList]
          · exact herr
      · exact herr
  · exact herr

/-- 検査の δ の契約（案 A。L40.2 の `CheckSpec.Contract` と同じ内容）。`Ok` の成功値は検査済みの対象の値であり、
対象は種類 path を持ち、動的なパターン q と具体化した範囲 r の両方に属する。 -/
theorem checkRun_contract {r : Range} {ws : List Val} {ts : List Ty} {w : Val}
    (h : checkRun pat tgt r ws = .val (.con "Ok" ts [w])) :
    ∃ ps raw q t, ws = [.const (.string ps), .const (.string raw)] ∧ pat ps = some q ∧ tgt raw = some t ∧
      w = .checked t ∧ t.kind = .path ∧ q.Mem t ∧ r.Mem t := by
  unfold checkRun at h
  split at h
  · next ps raw =>
      split at h
      · next q t hq ht =>
          split at h
          · next hc =>
              simp only [Outcome.val.injEq, Val.con.injEq, List.cons.injEq, and_true] at h
              exact ⟨ps, raw, q, t, rfl, hq, ht, by simp_all, hc⟩
          · simp at h
      · simp at h
  · simp at h

theorem ref_scoped_get : Model.refGetSig.Scoped :=
  (Model.assumptions Model.emptyProgram).sig_scoped "Reference.get" _ (by simp [Model.builtins])
theorem ref_scoped_set : Model.refSetSig.Scoped :=
  (Model.assumptions Model.emptyProgram).sig_scoped "Reference.set" _ (by simp [Model.builtins])

end

/-- 旧 Top の読み込みの項目の結果の型（範囲の変数を持たないので、具体化は型を変えない）。 -/
theorem readText_ret (rs : List Range) :
    Ty.subst [] [] (readTextSig.inst rs).ret = .data "Result" readTys := by
  simp [readTextSig, readTys, TargetTable.ioErrorTy, Ty.instR, Ty.rawInstR, Ty.norm, Ty.subst, Ty.substAt]

/-- 旧 Top の読み込みの観測は種類 path の対象だけである。 -/
theorem readObs_kind {tgt : String → Option Target} (ws : List Val) : ∀ t ∈ readObs tgt ws, t.kind = .path := by
  intro t ht
  unfold readObs at ht
  split at ht
  · split at ht
    · split at ht
      · next hk => simp only [List.mem_singleton] at ht; subst ht; exact hk
      · simp at ht
    · simp at ht
  · simp at ht

/-- 新版の実例: `Ok`・`Err` を宣言したどのプログラムについても、旧の条件と対象一致の条件の両方を満たす。 -/
theorem assumptions (pat : String → Option Range) (tgt : String → Option Target) (P : Program) (hP : HasResult P) :
    (builtins pat tgt).Assumptions P where
  sig_scoped := by
    intro b s h
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩
    · exact ref_scoped_get
    · exact ref_scoped_set
    · exact printSig_scoped
    · exact exitSig_scoped
    · exact write_scoped
    · exact check_scoped
    · exact readTextSig_scoped
  admits_subst := by
    intro b s C0 C1 ts ts' es' h ha _ _
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | simpa [Model.refGetSig, Model.refSetSig] using ha
      | (simp only [printSig, exitSig, readTextSig, TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.checkPathIn,
          TargetTable.pureIn] at ha ⊢
         subst ha; rfl)
  sat_subst := fun _ _ _ _ _ _ _ _ _ => trivial
  sat_unconstrained := fun _ _ => trivial
  admits_sat := by
    intro b s C ts h ha
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | exact ⟨by simpa [Model.refGetSig, Model.refSetSig] using ha, fun _ _ _ _ _ => trivial⟩
      | (simp only [printSig, exitSig, readTextSig, TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.checkPathIn,
          TargetTable.pureIn] at ha ⊢
         subst ha
         exact ⟨rfl, fun _ _ _ h _ => by simp at h⟩)
  sat_local := fun _ _ _ _ _ _ => trivial
  admits_local := by
    intro b s C1 C0 ts h _ ha
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;> exact ha
  delta_typed := by
    intro Ψ b s rs ts es ws h hk hR htl hel _ _
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨rfl, rfl⟩ | ⟨-, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, printSig, exitSig, readTextSig, TargetTable.writeTextIn,
        TargetTable.ioIn] at hk)
    obtain ⟨r, rfl⟩ := singleton_of_admissible rfl hR
    have hts : ts = [] := List.eq_nil_of_length_eq_zero htl
    have hes : es = [] := List.eq_nil_of_length_eq_zero hel
    subst hts hes
    refine ⟨checkRun pat tgt r ws, by simp [builtins], ?_, ?_⟩
    · intro n hn
      unfold checkRun at hn
      split at hn
      · split at hn
        · split at hn <;> cases hn
        · cases hn
      · cases hn
    · rw [checkPathIn_ret]
      exact checkRun_typed hP r ws
  io_kind := by
    intro b s ts es ws o obs h hr
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      simp only [builtins] at hr
    · simp at hr
    · simp at hr
    · obtain ⟨-, rfl, -⟩ := hr.resolve_right (by simp)
      exact .inl ⟨rfl, by simp⟩
    · obtain ⟨-, rfl, -⟩ := (hr.resolve_left (by simp)).resolve_right (by simp)
      exact .inr ⟨rfl, by simp⟩
    · obtain ⟨-, ho, -⟩ := ((hr.resolve_left (by simp)).resolve_left (by simp)).resolve_right (by simp)
      refine .inl ⟨rfl, fun n => ?_⟩
      rcases ho with rfl | rfl <;> simp
    · simp at hr
    · obtain ⟨-, ho, -⟩ := ((hr.resolve_left (by simp)).resolve_left (by simp)).resolve_left (by simp)
      refine .inl ⟨rfl, fun n => ?_⟩
      rcases ho with rfl | rfl <;> simp
  io_typed := by
    intro Ψ b s rs ts es ws o obs h hk hR htl hel _ _ hr
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkPathIn, TargetTable.pureIn] at hk)
    all_goals
      have hts : ts = [] := List.eq_nil_of_length_eq_zero htl
      have hes : es = [] := List.eq_nil_of_length_eq_zero hel
      subst hts hes
      simp only [builtins] at hr
    · obtain ⟨-, rfl, -⟩ := hr.resolve_right (by simp)
      rw [unit_ret rs printSig rfl]
      exact ⟨by simpa [Const.type] using (HasTypeVQ.V_Const (P := P) (B := builtins pat tgt) (Ψ := Ψ) (Q := Qempty)
        (C := []) (Γ := []) (c := .unit)), by simp [Val.VarsIn]⟩
    · obtain ⟨-, rfl, -⟩ := (hr.resolve_left (by simp)).resolve_right (by simp)
      trivial
    · obtain ⟨-, ho, -⟩ := ((hr.resolve_left (by simp)).resolve_left (by simp)).resolve_right (by simp)
      obtain ⟨r, rfl⟩ := singleton_of_admissible rfl hR
      rw [writeTextIn_ret]
      rcases ho with rfl | rfl
      · exact ⟨ok_typed hP.1 (by simpa [writeTys, Const.type, Ty.shift] using
            (HasTypeVQ.V_Const (P := P) (B := builtins pat tgt) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
              (c := .unit))),
          by simp [writeTys, TargetTable.ioErrorTy, Val.VarsIn, Ty.VarsInList, Ty.VarsIn, Val.VarsInList]⟩
      · exact ⟨err_typed hP.2 (by simpa [writeTys, ioFailure, TargetTable.ioErrorTy, Const.type, Ty.shift_opaque] using
            (HasTypeVQ.V_Const (P := P) (B := builtins pat tgt) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
              (c := .opaque "IOError" 0))),
          by simp [writeTys, ioFailure, TargetTable.ioErrorTy, Val.VarsIn, Ty.VarsInList, Ty.VarsIn,
            Val.VarsInList]⟩
    · obtain ⟨-, ho, -⟩ := ((hr.resolve_left (by simp)).resolve_left (by simp)).resolve_left (by simp)
      rw [readText_ret]
      rcases ho with rfl | rfl
      · exact ⟨ok_typed hP.1 (by simpa [readTys, Const.type, Ty.shift] using
            (HasTypeVQ.V_Const (P := P) (B := builtins pat tgt) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
              (c := .string ""))),
          by simp [readTys, TargetTable.ioErrorTy, Val.VarsIn, Ty.VarsInList, Ty.VarsIn, Val.VarsInList]⟩
      · exact ⟨err_typed hP.2 (by simpa [readTys, ioFailure, TargetTable.ioErrorTy, Const.type, Ty.shift_opaque] using
            (HasTypeVQ.V_Const (P := P) (B := builtins pat tgt) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
              (c := .opaque "IOError" 0))),
          by simp [readTys, ioFailure, TargetTable.ioErrorTy, Val.VarsIn, Ty.VarsInList, Ty.VarsIn,
            Val.VarsInList]⟩
  io_exists := by
    intro Ψ b s rs ts es ws h hk _ _ _ _ _
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkPathIn, TargetTable.pureIn] at hk)
    · exact ⟨_, _, .inl ⟨rfl, rfl, rfl⟩⟩
    · exact ⟨_, _, .inr (.inl ⟨rfl, rfl, rfl⟩)⟩
    · exact ⟨_, _, .inr (.inr (.inl ⟨rfl, .inl rfl, rfl⟩))⟩
    · exact ⟨_, _, .inr (.inr (.inr ⟨rfl, .inl rfl, rfl⟩))⟩
  io_op := by
    intro b s h hk
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      try (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkPathIn, TargetTable.pureIn] at hk)
    · exact ⟨"Console.Write", ["print"], rfl, rfl, by simp [builtins, stateEff], by simp, rfl, rfl, rfl⟩
    · exact ⟨"Process.Exit", ["exit"], rfl, rfl, by simp [builtins, stateEff], by simp, rfl, rfl, rfl⟩
    · exact TargetTable.ioIn_shapeOk (bs := ["File.writeTextIn"]) (by simp [builtins, stateEff]) (by simp) rfl rfl rfl
    · exact ⟨"File.Read", ["File.readText"], rfl, rfl, by simp [builtins, stateEff], by simp, rfl, rfl, rfl⟩
  effect_ops := by
    intro l bs b h hb
    rcases effects_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      simp only [List.mem_singleton, List.not_mem_nil] at hb
    · subst hb; exact ⟨printSig, sig_print, .inl rfl, rfl⟩
    · subst hb; exact ⟨exitSig, sig_exit, .inr rfl, rfl⟩
    · subst hb; exact ⟨_, sig_write, .inl rfl, rfl⟩
    · subst hb; exact ⟨readTextSig, sig_read, .inl rfl, rfl⟩
  opEff_io := by
    intro b s l h hl
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | (exfalso; simp [Model.refGetSig, Model.refSetSig, TargetTable.checkPathIn, TargetTable.pureIn] at hl)
      | exact .inl rfl
      | exact .inr rfl
  state_effect := by simp [builtins]
  store_shape := by
    intro b s h
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      simp [PrimSig.StoreShape, PrimSig.ntys, Model.refGetSig, Model.refSetSig, printSig, exitSig, readTextSig,
        TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.checkPathIn, TargetTable.pureIn]
  store_admits := by
    intro b s C ts h h1 h2 h3 hl
    rcases sig_cases h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩ <;>
      first
      | simpa [PrimSig.ntys, Model.refGetSig, Model.refSetSig] using hl
      | (exfalso; simp [printSig, exitSig, readTextSig, TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.checkPathIn,
          TargetTable.pureIn] at h1 h2 h3)
  ref_get := ⟨Model.refGetSig, by simp [builtins], rfl⟩
  ref_set := ⟨Model.refSetSig, by simp [builtins], rfl⟩
  release_exists := fun _ _ _ _ _ => ⟨none, rfl⟩
  io_target := by
    intro Ψ b s rs ts es ws o obs h hk _ _ _ _ _ hr
    rcases sig_cases h with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      simp only [builtins] at hr
    · simp at hr
    · simp at hr
    · obtain ⟨-, -, rfl⟩ := hr.resolve_right (by simp)
      rfl
    · obtain ⟨-, -, rfl⟩ := (hr.resolve_left (by simp)).resolve_right (by simp)
      rfl
    · obtain ⟨-, -, rfl⟩ := ((hr.resolve_left (by simp)).resolve_left (by simp)).resolve_right (by simp)
      -- 単一の対象の形: 最初の引数が検査済みの対象なら観測はその対象一つ、そうでなければ旧 Top の形で空。
      match ws with
      | [] => simp [PrimSig.shapeAt, TargetTable.writeTextIn, TargetTable.ioIn, firstTarget,
          Scope.Signature.ShapeTargets]
      | .checked t :: _ => simp [PrimSig.shapeAt, TargetTable.writeTextIn, TargetTable.ioIn, firstTarget,
          Val.target?, Scope.Signature.ShapeTargets]
      | .checkedRequest t _ :: _ => simp [PrimSig.shapeAt, TargetTable.writeTextIn, TargetTable.ioIn, firstTarget,
          Val.target?, Scope.Signature.ShapeTargets]
      | .var _ :: _ | .const _ :: _ | .fnRef _ _ _ :: _ | .prim _ _ _ _ :: _ | .lam _ _ _ :: _ | .con _ _ _ :: _
        | .list _ :: _ | .op _ _ :: _ | .raise _ _ :: _ | .loc _ :: _ | .mapV _ _ :: _ | .setV _ :: _
        | .bytesV _ :: _ | .dict _ _ _ :: _ | .super _ _ :: _ =>
          simp [PrimSig.shapeAt, TargetTable.writeTextIn, TargetTable.ioIn, firstTarget, Val.target?,
            Scope.Signature.ShapeTargets]
    · simp at hr
    · obtain ⟨-, -, rfl⟩ := ((hr.resolve_left (by simp)).resolve_left (by simp)).resolve_left (by simp)
      -- 旧 Top の形: 観測は種類 path の対象だけである。
      exact readObs_kind ws

/-! ## 例

文字列の解析は、例のための小さな関数 `pat`・`tgt` で与える（`/data/**`・`/tmp/**` のパターンと `/data/a.txt` の対象）。 -/

namespace Examples

/-- `/data/**` と `/tmp/**`。 -/
def range : Range := .path (.tree ["data"])
def tmpRange : Range := .path (.tree ["tmp"])

/-- `/data/a.txt`。 -/
def target : Target := .path ["data", "a.txt"]

def pat : String → Option Range := fun s =>
  if s = "/data/**" then some range else if s = "/tmp/**" then some tmpRange else none

def tgt : String → Option Target := fun s => if s = "/data/a.txt" then some target else none

/-- 例の表。 -/
abbrev B : Builtins := builtins pat tgt

def str (x : String) : Val := .const (.string x)

/-! ### 検査の δ は動的なパターンと具体化した R の両方を確かめる（問 24 の 6） -/

/-- パターン `/data/**` の検査を `[/data/**]` で具体化すると、`/data/a.txt` は `Ok(checked(/data/a.txt))` になる。 -/
theorem check_ok :
    B.delta "Scope.checkPathIn" [] [] [range] [str "/data/**", str "/data/a.txt"] =
      some (.val (.con "Ok" (checkTys range) [.checked target])) := by
  have hc : target.kind = .path ∧ range.Mem target ∧ range.Mem target := by decide
  simp [B, builtins, checkRun, str, pat, tgt, hc]

/-- 具体化した R（`/tmp/**`）が対象を含まなければ、動的なパターンが対象を含んでも `Err` になる。 -/
theorem check_range_rejects :
    B.delta "Scope.checkPathIn" [] [] [tmpRange] [str "/data/**", str "/data/a.txt"] =
      some (.val (.con "Err" (checkTys tmpRange) [scopeFailure])) := by
  have hc : ¬ (target.kind = .path ∧ range.Mem target ∧ tmpRange.Mem target) := by decide
  simp [B, builtins, checkRun, str, pat, tgt, hc]

/-- 動的なパターン（`/tmp/**`）が対象を含まなければ、具体化した R が対象を含んでも `Err` になる。 -/
theorem check_pattern_rejects :
    B.delta "Scope.checkPathIn" [] [] [range] [str "/tmp/**", str "/data/a.txt"] =
      some (.val (.con "Err" (checkTys range) [scopeFailure])) := by
  have hc : ¬ (target.kind = .path ∧ tmpRange.Mem target ∧ range.Mem target) := by decide
  simp [B, builtins, checkRun, str, pat, tgt, hc]

/-! ### 範囲付きの効果を宣言したプログラム

L20.1 の反例と同じ形のプログラム。定義 `f : () -> Unit uses File.Write[ix]`（本体は `return ()`）と、`Result` の構成子を
持つ。 -/

def resultCons : ConName → Option ConDecl := fun c =>
  if c = "Ok" then some okDecl else if c = "Err" then some errDecl else none

def writeDef (ix : Scope.Signature.Ix) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.singleAt "File.Write" ix
  body := .ret (.const .unit)

def progOf (ix : Scope.Signature.Ix) : Program :=
  ⟨fun f => if f = "f" then some (writeDef ix) else none, resultCons, fun _ => none, fun _ => none,
    fun _ => none, fun _ => none⟩

/-- `/data/**` の範囲の位置。 -/
def dataTree : Scope.Signature.Ix := .fixed range

theorem dataTree_wf : dataTree.WF 0 := Atom.ix_wf_fixed 0 range

theorem progOf_defs {ix f d} (h : (progOf ix).defs f = some d) : d = writeDef ix := by
  simp only [progOf] at h
  split at h
  · cases h; rfl
  · cases h

theorem progOf_hasResult (ix : Scope.Signature.Ix) : HasResult (progOf ix) := by
  simp [HasResult, progOf, resultCons]

theorem writeDef_eff_wf (ix : Scope.Signature.Ix) (h : ix.WF 0) :
    Eff.VarsIn 0 0 (· < 0) (Eff.singleAt "File.Write" ix) := by
  refine ⟨fun i hi => by simp at hi, trivial, fun x hx => ?_⟩
  simp only [beq_iff_eq] at hx
  subst hx
  exact h

theorem progOf_wellFormed {ix : Scope.Signature.Ix} (hix : ix.WF 0) : (progOf ix).WellFormed := by
  refine ⟨?_, ?_, fun _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩
  · intro f d h
    rw [progOf_defs h]
    exact ⟨by simp [NamesWF, writeDef], by simp [writeDef, Ty.VarsInList], by simp [writeDef, Ty.VarsIn],
      writeDef_eff_wf ix hix, by simp [writeDef, Comp.VarsIn, Val.VarsIn]⟩
  · intro c cd h
    simp only [progOf, resultCons] at h
    split at h
    · cases h; simp [ConDecl.Scoped, okDecl, Ty.VarsInList, Ty.VarsIn]
    · split at h
      · cases h; simp [ConDecl.Scoped, errDecl, Ty.VarsInList, Ty.VarsIn]
      · cases h

theorem empty_sub_singleAt (l : EffName) (ix : Scope.Signature.Ix) : Eff.Sub Eff.empty (Eff.singleAt l ix) :=
  ⟨fun a h => ((Eff.mem_empty a).mp h).elim, fun t h => ((Eff.memFail_empty t).mp h).elim⟩

theorem progOf_wellTyped (ix : Scope.Signature.Ix) : (progOf ix).WellTyped B := by
  refine ⟨?_, fun _ _ h => (by cases h)⟩
  intro f d h
  rw [progOf_defs h]
  exact ⟨by simp [NamesWF, writeDef], .C_Eff (.C_Return .V_Const) (Eff.covers_empty _)⟩

theorem progOf_effectsOk (ix : Scope.Signature.Ix) : (progOf ix).EffectsOk B :=
  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

/-- 例のプログラムについて、新版の実例の仮定（旧の条件と対象一致の条件）が成り立つ。 -/
theorem progOf_assumptions (ix : Scope.Signature.Ix) : B.Assumptions (progOf ix) :=
  assumptions pat tgt (progOf ix) (progOf_hasResult ix)

/-- 呼び出し `f()`。 -/
def callF : Comp := .app (.fnRef "f" [] []) []

theorem writeDef_admissible (ix : Scope.Signature.Ix) :
    Admissible B [] [] 0 (Qsig [] (.base .unit) (Eff.singleAt "File.Write" ix)) Qempty [] []
      (Eff.singleAt "File.Write" ix) where
  types := ⟨rfl, fun i _ _ h => by simp at h⟩
  typeScope := fun t h => by simp at h
  rowCount := rfl
  rowScope := fun f h => by simp at h
  sourceRows := by
    simp only [Eff.singleAt, Eff.ofAtoms, Eff.RowsIn, Ty.RowsInList]
    refine ⟨fun i h => ?_, trivial⟩
    simp at h
  sourceQ := fun i h => by
    simp [Qsig, QTys, QTy, QEff, Eff.singleAt, Eff.ofAtoms, Qempty] at h
  noFailRows := fun i h => by
    simp [Qsig, QTys, QTy, QEff, Eff.singleAt, Eff.ofAtoms, Qempty] at h

theorem callF_typed (ix : Scope.Signature.Ix) :
    HasTypeC (progOf ix) B StoreTy.empty [] [] none callF (.base .unit)
      (Eff.substAt 0 [] [] (Eff.singleAt "File.Write" ix)) :=
  .C_App (.V_Fun (d := writeDef ix) (by simp [progOf]) (by simp [NamesWF, writeDef])
    (writeDef_admissible ix)) .nil

theorem callF_closed : callF.ClosedNoEffVars := by
  simp [callF, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Eff.VarsInList, Val.VarsInList]

theorem substAt_singleAt (l : EffName) (ix : Scope.Signature.Ix) :
    Eff.substAt 0 [] [] (Eff.singleAt l ix) = Eff.singleAt l ix :=
  Eff.substAt_nil_of_wf [] _ (by
      simp [Eff.singleAt, Eff.ofAtoms, Eff.WF, Ty.WFList])
    (Eff.canonical_ofAtoms _)

/-- 範囲付きの組み込みのエフェクトの名前一つの効果は、案 BA の `BuiltinOnly` を満たす。 -/
theorem builtinOnly_write {P : Program} (hP : P.effects "File.Write" = none) (ix : Scope.Signature.Ix) :
    BuiltinOnly P B (Eff.singleAt "File.Write" ix) :=
  ⟨rfl, fun a ha => ⟨"File.Write", ix, (Eff.mem_singleAt _ _ _).mp ha, hP, by simp [B, builtins, stateEff]⟩⟩

/-- 同じ効果は、範囲の位置が Top でなければ旧の `BuiltinOnly` を満たさない（L20.1 の壁）。 -/
theorem not_builtinOnlyOld_write {P : Program} : ¬ BuiltinOnlyOld P B (Eff.singleAt "File.Write" dataTree) := by
  intro h
  obtain ⟨l, he, -⟩ := h.2 (.name "File.Write" dataTree) ((Eff.mem_singleAt _ _ _).mpr rfl)
  simp [dataTree, range, Atom.nameTop] at he

/-- 状態 `⟨f(), [], ∅⟩`。 -/
def s0 : State := .run callF [] Store.empty

/-- L20.1 の反例の状態（範囲付きの効果 `File.Write[/data/**]` を宣言した関数の呼び出し）は、案 BA の `BuiltinOnly`
のもとで公開の `StateTy` に入る。 -/
theorem s0_stateTy : StateTy (progOf dataTree) B s0 := by
  have h := stateTyE_init_eff (progOf_wellFormed dataTree_wf) (progOf_assumptions dataTree).core
    (callF_typed dataTree) callF_closed
  rw [substAt_singleAt] at h
  exact stateTy_iff.mpr ⟨_, builtinOnly_write rfl dataTree, h⟩

/-- 範囲付きの IO の項目を持つ表で、範囲付きの効果を宣言したプログラムに進行の定理が当たる（前提は旧の条件だけ）。 -/
theorem s0_progress : s0.Final ∨ ∃ l s', Step (progOf dataTree) B s0 l s' :=
  progress (progOf_wellTyped dataTree) (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core s0_stateTy

/-- 保存の定理を繰り返すと、型の付いた状態から到達する全ての状態に型が付く。 -/
theorem steps_stateTy {s s' : State} (hs : Steps (progOf dataTree) B s s') (h : StateTy (progOf dataTree) B s) :
    StateTy (progOf dataTree) B s' := by
  induction hs with
  | refl => exact h
  | step hst _ ih =>
      exact ih (preservation (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree) (progOf_effectsOk dataTree)
        (progOf_assumptions dataTree).core h hst)

/-- 保存の定理も同じ状態から到達する全ての状態に当たる。 -/
theorem s0_preservation {s : State} (hs : Steps (progOf dataTree) B s0 s) : StateTy (progOf dataTree) B s :=
  steps_stateTy hs s0_stateTy

/-! ### 範囲付きの IO の呼び出し

`File.writeTextIn[;;/data/**](checked(/data/a.txt), "x")`。 -/

def ioCall : Comp :=
  .app (.prim "File.writeTextIn" [] [] [range]) [.checked target, str "x"]

theorem write_admissible : B.RangeAdmissible "File.writeTextIn" TargetTable.writeTextIn [range] := by
  refine ⟨⟨?_, ?_, Or.inr ⟨Or.inl rfl, rfl⟩⟩, ?_⟩
  · exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

theorem write_prim_admissible : PrimitiveAdmissible [] (TargetTable.writeTextIn.inst [range]) Qempty [] [] :=
  PrimitiveAdmissible.of_noRows_inst write_scoped (by decide) rfl rfl rfl (by simp)

theorem write_params :
    (TargetTable.writeTextIn.inst [range]).params.map (Ty.subst [] []) =
      [.opaque "Scope.PathIn" (.fixed range), .base .string] := by
  simp [TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.pathIn, Ty.instTarget, Scope.Signature.Ix.inst,
    Ty.subst, Ty.substAt]

theorem ioCall_args {P : Program} {Ψ : StoreTy} :
    HasTypeVs P B Ψ [] [] [.checked target, str "x"] ((TargetTable.writeTextIn.inst [range]).params.map (Ty.subst [] [])) := by
  rw [write_params]
  exact .cons (.V_Checked rfl (by decide)) (.cons .V_Const .nil)

theorem ioCall_typed {P : Program} {Ψ : StoreTy} :
    HasTypeC P B Ψ [] [] none ioCall (Ty.subst [] [] (TargetTable.writeTextIn.inst [range]).ret)
      (Eff.substAt 0 [] [] (TargetTable.writeTextIn.inst [range]).eff) := by
  have hv := HasTypeVQ.V_Prim (P := P) (B := B) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := [])
    (b := "File.writeTextIn") (s := TargetTable.writeTextIn) (rs := [range]) (ts := []) (es := [])
    sig_write write_admissible ⟨rfl, by decide⟩ write_prim_admissible
  rw [fnTy_eq] at hv
  exact .C_App hv ioCall_args

theorem write_eff : Eff.substAt 0 [] [] (TargetTable.writeTextIn.inst [range]).eff =
    Eff.singleAt "File.Write" dataTree := by
  rw [PrimSig.inst_eff]
  simp only [TargetTable.writeTextIn, TargetTable.ioIn, Eff.instR_singleAt]
  exact substAt_singleAt _ _

theorem ioCall_closed : ioCall.ClosedNoEffVars := by
  simp [ioCall, str, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Eff.VarsInList, Val.VarsInList]

def ioState : State := .run ioCall [] Store.empty

/-- 範囲付きの IO の呼び出しの状態は `StateTy` に入る（末尾は `File.Write[/data/**]`）。 -/
theorem ioState_stateTy : StateTy (progOf dataTree) B ioState := by
  have h := stateTyE_init_eff (progOf_wellFormed dataTree_wf) (progOf_assumptions dataTree).core ioCall_typed ioCall_closed
  rw [write_eff] at h
  exact stateTy_iff.mpr ⟨_, builtinOnly_write rfl dataTree, h⟩

/-- 範囲付きの IO の呼び出しの状態に進行の定理が当たる。 -/
theorem ioState_progress : ioState.Final ∨ ∃ l s', Step (progOf dataTree) B ioState l s' :=
  progress (progOf_wellTyped dataTree) (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core ioState_stateTy

/-- 処理する節がないので、応答の関係で進み、事象は観測 `[/data/a.txt]` を持つ。 -/
theorem ioState_step {σ : Store} :
    Step (progOf dataTree) B (.run ioCall [] σ)
      (some (.io "File.writeTextIn" [.checked target, str "x"] (.val (.con "Ok" writeTys [.const .unit])) [target]))
      (.run (.ret (.con "Ok" writeTys [.const .unit])) [] σ) :=
  .E_IO (s := TargetTable.writeTextIn) sig_write rfl (fun _ h => by cases h) (.inr (.inr (.inl ⟨rfl, .inl rfl, rfl⟩)))

/-- 対象一致の条件から、観測した対象 `/data/a.txt` は具体化した効果 `File.Write[/data/**]` が許す（κ は表の
`effKind`）。 -/
theorem ioState_obs_allowed :
    ∀ t ∈ [target], B.Allows (TargetTable.writeTextIn.inst [range]).eff "File.Write" t := by
  obtain ⟨l, hl, h⟩ := (progOf_assumptions dataTree).obs_allowed (Ψ := StoreTy.empty) (ts := []) (es := [])
    (o := .val (.con "Ok" writeTys [.const .unit])) sig_write (.inl rfl) write_admissible rfl rfl rfl ioCall_args
    (.inr (.inr (.inl ⟨rfl, .inl rfl, rfl⟩)))
  cases hl
  exact h

/-! ### 旧 Top の形の IO の項目と資源の型（RV-L40 軽8）

`File.readText(path: "/data/a.txt")`（効果は Top の原子 `File.Read`）。形の検査（`ShapeOk`）と対象一致の条件
（`io_target`）が旧 Top の形 `topTargeted .path` で当たり、観測 `[/data/a.txt]` は空でない。 -/

def readCall : Comp := .app (.prim "File.readText" [] [] []) [str "/data/a.txt"]

/-- 旧 Top の形の項目は形の検査を通る（`io_op` の欄から得る）。 -/
theorem read_shapeOk : B.ShapeOk "File.readText" readTextSig :=
  (progOf_assumptions dataTree).io_op _ _ sig_read (.inl rfl)

theorem read_admissible : B.RangeAdmissible "File.readText" readTextSig [] := by
  refine ⟨⟨Scope.Domain.Range.fitsKinds_nil, ?_, Or.inl ?_⟩, ?_⟩ <;> intro r hr <;> cases hr

theorem read_args {P : Program} {Ψ : StoreTy} :
    HasTypeVs P B Ψ [] [] [str "/data/a.txt"] ((readTextSig.inst []).params.map (Ty.subst [] [])) := by
  have hp : (readTextSig.inst []).params.map (Ty.subst [] []) = [.base .string] := by
    simp [readTextSig, Ty.instTarget, Ty.subst, Ty.substAt]
  rw [hp]
  exact .cons .V_Const .nil

/-- 応答の関係が選ぶ観測は `[/data/a.txt]` である。 -/
theorem read_response :
    B.ioResponse "File.readText" [] [] [str "/data/a.txt"] (.val (.con "Ok" readTys [.const (.string "")])) [target] :=
  .inr (.inr (.inr ⟨rfl, .inl rfl, by simp [readObs, str, tgt, target]; rfl⟩))

/-- 対象一致の条件は、旧 Top の形の項目で空でない観測について当たる（観測の対象は種類 path である）。 -/
theorem read_io_target :
    Scope.Signature.ShapeTargets Val.target? (readTextSig.shapeAt [str "/data/a.txt"]) [str "/data/a.txt"] [target] :=
  (progOf_assumptions dataTree).io_target StoreTy.empty "File.readText" readTextSig [] [] [] _ _ _ sig_read (.inl rfl)
    read_admissible rfl rfl rfl read_args read_response

theorem read_io_target_kind : readTextSig.shapeAt [str "/data/a.txt"] = .topTargeted .path := rfl

/-- 処理する節がないので、応答の関係で進み、事象は観測 `[/data/a.txt]` を持つ。 -/
theorem read_step {σ : Store} :
    Step (progOf dataTree) B (.run readCall [] σ)
      (some (.io "File.readText" [str "/data/a.txt"] (.val (.con "Ok" readTys [.const (.string "")])) [target]))
      (.run (.ret (.con "Ok" readTys [.const (.string "")])) [] σ) :=
  .E_IO (s := readTextSig) sig_read rfl (fun _ h => by cases h) read_response

/-- 観測した対象 `/data/a.txt` は、項目の効果の Top の原子 `File.Read` が許す（`obs_allowed`）。 -/
theorem read_obs_allowed : ∀ t ∈ [target], B.Allows (readTextSig.inst []).eff "File.Read" t := by
  obtain ⟨l, hl, h⟩ := (progOf_assumptions dataTree).obs_allowed (Ψ := StoreTy.empty) (ts := []) (es := [])
    sig_read (.inl rfl) read_admissible rfl rfl rfl read_args read_response
  cases hl
  exact h

/-- 資源の型 `File.Handle` の値は型が付き、`release_exists` の前提を満たす（欄は空に成り立たない）。 -/
theorem handle_release {P : Program} (hP : HasResult P) :
    HasTypeV P B StoreTy.empty [] [] (.const (.opaque "File.Handle" 0)) (.opaqueTop "File.Handle") ∧
      B.isResource "File.Handle" = true ∧ ∃ r, B.releaseResponse (.const (.opaque "File.Handle" 0)) r := by
  have hv : HasTypeV P B StoreTy.empty [] [] (.const (.opaque "File.Handle" 0)) (.opaqueTop "File.Handle") := by
    simpa [Const.type] using (HasTypeVQ.V_Const (P := P) (B := B) (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Γ := [])
      (c := .opaque "File.Handle" 0))
  have hr : B.isResource "File.Handle" = true := rfl
  exact ⟨hv, hr, (assumptions pat tgt P hP).release_exists _ _ _ hv hr⟩

end Examples

end Benitoite.Release.ModelTargets
