import Benitoite.Surface.DesugarRange
import Benitoite.Release.ModelTargets
import Benitoite.Release.ModelHttp
import Benitoite.Checked.Scope
import Benitoite.Surface.ScopeOccurrence

/-!
# Scope の接続定理（L40.6）

Scope の局所解析（`Surface.ScopeState`・`Surface.ScopeLower`）と型検査器の受理（`Surface.ScopeAccept`）を、脱糖した
コアの項と本番の型付け・δ へ接続する（設計書 01-12「Scope の局所解析の接続定理」、07-04「証明する性質」）。

- 検査の成功値（`scope_check_connection`）: 受理した本体の評価が検査の直接の呼び出しの文へ到達し、呼び出しが `Ok(w)`
  を返すなら、w は対象 t を保持し、t は局所解析が推論した範囲 R（抽象の結果の由来の添字）に属する。型検査器が受理して
  脱糖がコアの項 `.prim b ts es rs` へ書いた範囲の列の位置 0 の範囲 S は R を覆い、t は S に属する。
- 射影・拡大が指す値（`scope_local_connection`）: 受理した本体の評価が、局所の位置 i を引数にする射影・拡大の呼び出しの
  文へ到達するなら、その文の記録の必須の判定の添字 R（推論した範囲）を、コアの項の範囲の列の位置 0 の範囲 S が覆う。
  R が Top でなければ、位置 i の値は R と S の両方に属する対象を保持し、コアの入力の型 `O[S]` を持つ
  （`scope_local_typed`）。R が Top（由来の未知・予算の超過）なら、受理する S は Top だけである。
- 同じ R（`evalScope_core_step`）: Scope の規則の実行を本番の表の δ（`deltaRun`）にした表では、局所解析の評価関係
  `EvalScope` の値は、同じ範囲の列を持つコアの組み込みの呼び出しの E-Prim の値と同じである。L20.7・L40.3b の実例の表
  （`Release.ModelTargets`・`Release.ModelHttp`）の検査の δ は Scope の検査の契約を満たし（`modelTargets_contract`・
  `modelHttp_contract`）、それを規則にした表は健全である（`productionRules_sound`）。`Http.checkRequestIn` の成功値は
  渡された要求を保持する検査済みの要求の値である。
- 旧 Scope の小モデルとの対応（`CheckedPath.hasTypeV`・`CheckedEndpoint.hasTypeV`・`makePath_checkRun`・
  `makeEndpoint_checkRun`）: 旧の検査済みの値（`Checked.Scope`）の対象は、新しい値の形の検査済みの対象の値として、
  パターンの範囲を添字に持つ範囲付きの値型 `Scope.PathIn[R]`・`Http.RequestIn[R]` を持つ。旧の検査が成功する入力では、
  本番の実例の表の検査の δ は、具体化した範囲 r が対象を含むときだけ `Ok` を返す（IP アドレスと CIDR を含む）。

接続定理の前提は、表の健全性（`TableSound`）、受理（`acceptBody`）、表層の具体の評価（`ReachBlock`・`RhsEval`）、
出現の番号の一致（同じ式が出現の一覧の番号 k にあり、評価が番号 k の文の始まりに到達すること）だけである。区間解析
（`Interval.RangeState`・警告の解析）の結果を読まない。出現の番号の一致は、到達した文の右辺を添字に持つ到達
`ScopeOccurrence.ReachAtBlock` から得る（`ScopeOccurrence.reachAt_occurrences`、L50.4）。系 `*_at` は `hreach` と `hocc`
の代わりにその到達だけを前提に取る。
-/

namespace Benitoite.Surface.ScopeSound

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept
open Scope.Domain (Range Target)

/-! ## 本番の δ を規則の実行にする -/

/-- 本番の表 B の組み込みの関数 b の δ を、Scope の規則の実行（範囲の列と引数から値）にする。値を返す結果だけを
値とし、誤り・終了は値なしとする。 -/
def deltaRun (B : Builtins) (b : PrimName) (ts : List Ty) (es : List Eff) :
    List Range → List Val → Option Val :=
  fun rs vs =>
    match B.delta b ts es rs vs with
    | some (.val v) => some v
    | _ => none

theorem deltaRun_eq_some {B : Builtins} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {vs : List Val} {v : Val} : deltaRun B b ts es rs vs = some v ↔ B.delta b ts es rs vs = some (.val v) := by
  unfold deltaRun
  constructor
  · intro h
    split at h
    · next v' hd => cases h; exact hd
    · cases h
  · intro h
    rw [h]

/-- 同じ R の接続。Scope の規則の実行が本番の δ なら、局所解析の評価関係が返す値は、同じ範囲の列 rs を持つコアの
組み込みの呼び出しが E-Prim で返す値と同じである。 -/
theorem evalScope_core_step {T : ScopeTable Val} {k : Key} {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule)
    {B : Builtins} {b : PrimName} {ts : List Ty} {es : List Eff} (hrun : rule.run = deltaRun B b ts es)
    {rs : List Range} {vs : List Val} {v : Val} (hev : EvalScope T k rs vs v) {s : PrimSig} (hs : B.sig b = some s)
    (hpure : s.kind = .pure) (P : Release.Program) (K : Cont) (σ : Store) :
    Release.Step P B (.run (.app (.prim b ts es rs) vs) K σ) none (.run (.ret v) K σ) := by
  cases hev with
  | apply rule' _ identified run =>
    rw [hrule] at identified
    cases identified
    rw [hrun] at run
    exact .E_Prim hs hpure (deltaRun_eq_some.mp run)

/-- `Result.Ok` の値の形。 -/
theorem okPayload_eq_some {ok : ConName} {v w : Val} (h : okPayload ok v = some w) :
    ∃ ts, v = .con ok ts [w] := by
  unfold okPayload at h
  split at h
  · next c ts w' =>
    split at h
    · next hc => cases h; subst hc; exact ⟨ts, rfl⟩
    · cases h
  · cases h

/-! ## 範囲の種類 -/

/-- Top でない範囲に属する対象の種類は、範囲の種類である。 -/
theorem mem_kind {R : Range} {t : Target} (h : R.Mem t) (hne : R ≠ .top) : R.kind? = some t.kind := by
  cases R <;> cases t <;> first | exact absurd rfl hne | rfl | exact h.elim

/-! ## 検査の成功値の接続 -/

/-- 表層の具体の評価が、Scope の規則を持つ組み込みの名前の直接の呼び出しを値 v へ評価するなら、契約の順の引数の列 xs
と値の列 vs があり、局所の評価の上で規則を評価した値である（`RhsEval` の逆転）。表層の具体の評価は規則を評価する
範囲の列を量化する（どの具体化の範囲でも規則は健全である）。 -/
theorem rhsEval_prim {T : ScopeTable Val} {k : Key} {env : Locals} {b : PrimName} {ts : List Ty} {es : List Eff}
    {rs : List Range} {labels positions} {args : Exprs} {v : Val} {rule : ScopeRule Val}
    (hrule : T.ruleAt k = some rule)
    (h : RhsEval T k env (.call (.primName b ts es rs) labels positions args) (some v)) :
    ∃ xs vs rs', contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs ∧
      EvalArgs T env xs vs ∧ EvalScope T k rs' vs v := by
  cases h with
  | callStd _ hargs hord heval =>
    obtain ⟨xs, hxs, hev⟩ := contractOrder_evalArgs (argEvals_lower hargs) hord
    exact ⟨xs, _, _, hxs, hev, heval⟩
  | callOther missing => rw [hrule] at missing; cases missing
  | indirect hd => simp [directHead] at hd
  | other hc => simp [callOrLocal] at hc

/-- 接続定理（検査の成功値）。受理した本体の評価が、番号 k の文の始まりへ到達し、その文の右辺の検査の直接の呼び出し
（出現の一覧の番号 k の同じ式）が `Ok(w)` を返すなら、次が成り立つ。

- 記録の状態 st と契約の順の引数 xs と値の列 vs があり、規則の実行は vs で v を返した（コアの項と同じ範囲の列 rs で
  実行した場合は `scope_check_core`）。
- w は対象 t を保持し（`Val.target?`）、t は検査の種類を持ち、局所解析が推論した範囲 R（抽象の結果の由来の添字。
  続く `Ok` の腕の成功値の事実の添字）に属する。
- 型検査器が受理した範囲の列 rs の位置 0 の範囲 S（脱糖がコアの項 `.prim b ts es rs` へ書く範囲。
  `desugar_primName`）は R を覆い、t は S に属する。

前提は表の健全性と受理と表層の評価だけであり、検査の δ の契約を仮定しない（R への所属は規則の健全性から、S への所属は
被覆の健全性から得る）。 -/
theorem scope_check_connection {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    (hreach : ReachBlock T key env body k env') {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body) {v : Val}
    (hrhs : RhsEval T k env' (.call (.primName b ts es rs) labels positions args) (some v)) {C : CheckSpec}
    {run : List Range → List Val → Option Val} (hrule : T.ruleAt k = some (checkRule C run)) {w : Val}
    (hw : okPayload ok v = some w) :
    ∃ st xs vs, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
      contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs ∧
      (∃ rs', run rs' vs = some v) ∧
      ∃ t, w.target? = some t ∧ t.kind = C.kind ∧ (C.bound (xs.map (absArg T st))).index.Mem t ∧
        ∀ S, rs[0]? = some S → S.Covers (C.bound (xs.map (absArg T st))).index ∧ S.Mem t := by
  obtain ⟨st, hmem, hst⟩ := analyzeBody_sound (L := L) (scope := scope) hT hreach
  obtain ⟨xs, vs, rs', hxs, hev, heval⟩ := rhsEval_prim hrule hrhs
  have hargs := absArgs_models hT hst hev
  have habs : absApply T k (xs.map (absArg T st)) = some (.result ⟨k, C.kind, C.bound (xs.map (absArg T st))⟩) := by
    simp [absApply, hrule, checkRule]
  have hfact := apply_sound hT hargs heval habs 0
  obtain ⟨t, ht, hk, hm⟩ := checkedModels_iff.mp (hfact w hw)
  have hrun : run rs' vs = some v := by
    cases heval with
    | apply rule' _ identified hr =>
      rw [hrule] at identified
      cases identified
      exact hr
  refine ⟨st, xs, vs, hmem, hxs, ⟨rs', hrun⟩, t, ht, hk, hm, fun S hS => ?_⟩
  have hcov := acceptBody_sound hacc hocc hxs hrule st hmem 0 S (C.bound (xs.map (absArg T st))).index hS
    (by simp [checkRule])
  exact ⟨hcov, Range.Covers.sound hcov t hm⟩

/-- 接続定理（検査の成功値）の範囲の位置は空に成り立たない（RV-L40 軽4）。同じ前提のもとで、型検査器が受理した範囲の列は
位置 0 の範囲 S を持つ（`acceptRanges` が規則の選ぶ位置に契約の範囲を求める）。`scope_check_connection` の結論の
`∀ S, rs[0]? = some S → …` は、この S について成り立つ。 -/
theorem scope_check_range {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    (hreach : ReachBlock T key env body k env') {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body) {v : Val}
    (hrhs : RhsEval T k env' (.call (.primName b ts es rs) labels positions args) (some v)) {C : CheckSpec}
    {run : List Range → List Val → Option Val} (hrule : T.ruleAt k = some (checkRule C run)) :
    ∃ S, rs[0]? = some S := by
  obtain ⟨st, hmem, -⟩ := analyzeBody_sound (L := L) (scope := scope) hT hreach
  obtain ⟨xs, -, -, hxs, -, -⟩ := rhsEval_prim hrule hrhs
  exact acceptBody_some hacc hocc hxs hrule st hmem 0 (C.bound (xs.map (absArg T st))).index (by simp [checkRule])

/-! ## 射影・拡大が指す値の接続 -/

/-- 接続定理（射影・拡大が指す値）。受理した本体の評価が番号 k の文の始まりへ局所 env' で到達し、その文の右辺が局所の
位置 i を引数にする規則付きの直接の呼び出し（出現の一覧の番号 k の同じ式。規則の `index` は引数の必須の判定の添字。
射影 `projectRule` と拡大 `widenRule`）なら、記録の状態 st があり、st の位置 i の必須の判定の添字 R（推論した範囲）を、
型検査器が受理して脱糖がコアの項へ書いた範囲の列の位置 0 の範囲 S が覆う。R が Top なら S は Top であり、R が Top で
なければ、位置 i の値は R と S の両方に属する対象を保持する。 -/
theorem scope_local_connection {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    (hreach : ReachBlock T key env body k env') {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body) {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some [.loc i])
    {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Val} (found : env'[i]? = some (some v)) {S : Range} (hS : rs[0]? = some S) :
    ∃ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧ S.Covers (st.requiredIndex i) ∧
      (st.requiredIndex i = .top → S = .top) ∧
      (st.requiredIndex i ≠ .top → ∃ t, v.target? = some t ∧ (st.requiredIndex i).Mem t ∧ S.Mem t) := by
  obtain ⟨st, hmem, hst⟩ := analyzeBody_sound (L := L) (scope := scope) hT hreach
  have hcov : S.Covers (st.requiredIndex i) := by
    refine acceptBody_sound hacc hocc hxs hrule st hmem 0 S _ hS ?_
    show (rule.index [absArg T st (.loc i)])[0]? = some (st.requiredIndex i)
    rw [hidx]
    simp [absArg, argIndex_readLocal]
  refine ⟨st, hmem, hcov, fun htop => ?_, fun hne => ?_⟩
  · rw [htop] at hcov
    exact (Range.covers_top_iff S).mp hcov
  · obtain ⟨_, t, ht, -, -, hm⟩ := requiredIndex_checked hst found hne
    exact ⟨t, ht, hm, Range.Covers.sound hcov t hm⟩

/-- 接続定理（射影・拡大が指す値）の前提 `rs[0]? = some S` は、受理した本体の文へ到達すれば満たせる（RV-L40 軽4）。 -/
theorem scope_local_range {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    (hreach : ReachBlock T key env body k env') {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body) {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some [.loc i])
    {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a]) :
    ∃ S, rs[0]? = some S := by
  obtain ⟨st, hmem, -⟩ := analyzeBody_sound (L := L) (scope := scope) hT hreach
  exact acceptBody_some hacc hocc hxs hrule st hmem 0 (st.requiredIndex i)
    (by show (rule.index [absArg T st (.loc i)])[0]? = some (st.requiredIndex i); rw [hidx]; simp [absArg, argIndex_readLocal])

/-- 射影と拡大の規則の `index` は、引数の必須の判定の添字である。 -/
theorem projectRule_index (run : List Range → List Val → Option Val) (a : AbsArg) :
    (projectRule run).index [a] = [argIndex a] := rfl

theorem widenRule_index (a : AbsArg) : widenRule.index [a] = [argIndex a] := rfl

/-- 接続定理の型付けの系。狭い契約（Top でない S）を受理した射影・拡大の呼び出しの引数の値は、名前 o の種類と S の
種類が同じなら、コアの入力の型 `o[S]` を持つ（`TargetTable` の項目では `pathInValue_inst_params` などがコアの入力の
型を与える）。 -/
theorem scope_local_typed {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    (hreach : ReachBlock T key env body k env') {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body) {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some [.loc i])
    {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Val} (found : env'[i]? = some (some v)) {S : Range} (hS : rs[0]? = some S) (hSne : S ≠ .top)
    {Pr : Release.Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : List TParam} {Γ : List (Option Ty)}
    {name : OpaqueName} {kd : Scope.Domain.Kind} (hk : B.valKind name = some kd) (hfit : S.kind? = some kd)
    (hc : ∀ t c, v = .checkedRequest t c → ∃ A, B.valContent name = some A ∧ HasTypeVQ Pr B Ψ Qempty [] [] c A) :
    HasTypeVQ Pr B Ψ Q C Γ v (.opaque name (.fixed S)) := by
  obtain ⟨st, -, -, htop, hval⟩ :=
    scope_local_connection hT hacc hreach hocc hxs hrule hidx found hS
  have hne : st.requiredIndex i ≠ .top := fun h => hSne (htop h)
  obtain ⟨t, ht, -, hmS⟩ := hval hne
  have hkind : S.kind? = some t.kind := mem_kind hmS hSne
  rw [hfit] at hkind
  cases hkind
  exact target_hasTypeV ht hk hmS (hc t)

/-- `scope_local_typed` の前提 `hc` を値の型付けから得る系（RV-L40 軽7）。引数の値 v が同じプログラム Pr で名前 name の
不透明型（範囲の位置は任意）を持てば、v が検査済みの要求の値のとき、保持する要求は `valContent name` が与える型を持つ
（V-CheckedRequest の逆転 `HasTypeVQ.inv_checkedRequest`）。引数の値の型付けのストアの型付け Ψ' は結論の Ψ に含まれる
（`StoreTy.Sub Ψ' Ψ`。保持する要求の導出をストアの拡大 `HasTypeVQ.store` で移す）。NoFail の文脈・型の文脈・値の文脈は
両側で任意である。検査済みの対象の値と他の値では `hc` は空に成り立つ。

L40.3c で、引数の値の型付けのプログラムとストアを結論と独立に取る形から、同じプログラムとストアの包含を前提にする形へ
改めた。保持する要求はレコードの値であり、その型付けは構成子を宣言したプログラムによるので、別のプログラムでの型付け
から任意のプログラムでの型付けは得られない（`Release.ModelHttp.Examples.checkedReq_not_typed_empty`）。 -/
theorem scope_local_typed_of_typed {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    (hreach : ReachBlock T key env body k env') {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body) {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some [.loc i])
    {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Val} (found : env'[i]? = some (some v)) {S : Range} (hS : rs[0]? = some S) (hSne : S ≠ .top)
    {Pr : Release.Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : List TParam} {Γ : List (Option Ty)}
    {name : OpaqueName} {kd : Scope.Domain.Kind} (hk : B.valKind name = some kd) (hfit : S.kind? = some kd)
    {Ψ' : StoreTy} {Q' : NoFailCtx} {C' : List TParam} {Γ' : List (Option Ty)}
    {ix : Scope.Signature.Ix} (hv : HasTypeVQ Pr B Ψ' Q' C' Γ' v (.opaque name ix)) (hΨ : StoreTy.Sub Ψ' Ψ) :
    HasTypeVQ Pr B Ψ Q C Γ v (.opaque name (.fixed S)) :=
  scope_local_typed hT hacc hreach hocc hxs hrule hidx found hS hSne hk hfit fun t c hvc => by
    obtain ⟨o, R, A, hT', -, -, hA, hc⟩ := hv.inv_checkedRequest hvc
    cases hT'
    exact ⟨A, hA, hc.store hΨ⟩

/-! ## 署名の表の項目のコアの入力の型 -/

theorem pathInValue_inst_params (S : Range) :
    (TargetTable.pathInValue.inst [S]).params = [.opaque "Scope.PathIn" (.fixed S)] := by
  simp [PrimSig.inst, TargetTable.pathInValue, TargetTable.pureIn, TargetTable.pathIn, Ty.instTarget,
    Scope.Signature.Ix.inst]

theorem requestInValue_inst_params (S : Range) :
    (TargetTable.requestInValue.inst [S]).params = [.opaque "Http.RequestIn" (.fixed S)] := by
  simp [PrimSig.inst, TargetTable.requestInValue, TargetTable.pureIn, TargetTable.requestIn, Ty.instTarget,
    Scope.Signature.Ix.inst]

theorem widenRequestIn_inst_params (r s : Range) :
    (TargetTable.widenRequestIn.inst [r, s]).params = [.opaque "Http.RequestIn" (.fixed r)] := by
  simp [PrimSig.inst, TargetTable.widenRequestIn, TargetTable.pureIn, TargetTable.requestIn, Ty.instTarget,
    Scope.Signature.Ix.inst]

theorem checkPathIn_inst_ret (S : Range) :
    (TargetTable.checkPathIn.inst [S]).ret =
      TargetTable.resultTy (.opaque "Scope.PathIn" (.fixed S)) TargetTable.scopeErrorTy :=
  ModelTargets.checkPathIn_ret S

/-! ## 同じ R でのコアの実行 -/

/-- 同じ R の接続の逆向き。コアの組み込みの呼び出し `.prim b ts es rs` の δ が値 v を返すなら、規則の実行を本番の δ に
した表の評価関係は、同じ範囲の列 rs で同じ値を返す。 -/
theorem evalScope_of_delta {T : ScopeTable Val} {k : Key} {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule)
    {B : Builtins} {b : PrimName} {ts : List Ty} {es : List Eff} (hrun : rule.run = deltaRun B b ts es)
    {rs : List Range} {vs : List Val} {v : Val} (hδ : B.delta b ts es rs vs = some (.val v)) :
    EvalScope T k rs vs v :=
  .apply rule v hrule (by rw [hrun]; exact deltaRun_eq_some.mpr hδ)

/-- 接続定理（検査の成功値、コアの実行の形）。受理した本体の評価が番号 k の文の始まりへ局所 env' で到達し、その文の
右辺の検査の直接の呼び出しの引数が値の列 vs に評価され、検査の規則の実行が本番の表 B の δ であるとする。脱糖した
コアの項 `.prim b ts es rs`（型検査器が受理した範囲の列 rs をそのまま持つ）を同じ引数へ適用すると、E-Prim で δ の値 v へ
進む。v が `Ok(w)` なら、w は対象 t を保持し、t は推論した範囲 R に属し、rs の位置 0 の範囲 S は R を覆い、t は S に
属する。 -/
theorem scope_check_core {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    (hreach : ReachBlock T key env body k env') {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body)
    {vals vs : List Val} (hargs : ArgEvals T env' (argsKey k (.primName b ts es rs)) args vals)
    (hord : contractOrder positions vals = some vs) {B : Builtins} {C : CheckSpec}
    (hrule : T.ruleAt k = some (checkRule C (deltaRun B b ts es))) {v : Val}
    (hδ : B.delta b ts es rs vs = some (.val v)) {s : PrimSig} (hs : B.sig b = some s) (hpure : s.kind = .pure)
    (op : OpPrim) (pos : Position) (Pr : Release.Program) (K : Cont) (σ : Store) :
    desugarExpr op pos (.primName b ts es rs) = .ret (.prim b ts es rs) ∧
      Release.Step Pr B (.run (.app (.prim b ts es rs) vs) K σ) none (.run (.ret v) K σ) ∧
      ∀ w, okPayload ok v = some w →
        ∃ st xs, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
          contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs ∧
          ∃ t, w.target? = some t ∧ t.kind = C.kind ∧ (C.bound (xs.map (absArg T st))).index.Mem t ∧
            ∀ S, rs[0]? = some S → S.Covers (C.bound (xs.map (absArg T st))).index ∧ S.Mem t := by
  have heval : EvalScope T k rs vs v := evalScope_of_delta hrule rfl hδ
  have hrhs : RhsEval T k env' (.call (.primName b ts es rs) labels positions args) (some v) :=
    .callStd rfl hargs hord heval
  refine ⟨desugar_primName op pos b ts es rs, evalScope_core_step hrule rfl heval hs hpure Pr K σ, fun w hw => ?_⟩
  obtain ⟨st, xs, -, hmem, hxs, -, t, ht, hk, hm, hS⟩ := scope_check_connection hT hacc hreach hocc hrhs hrule hw
  exact ⟨st, xs, hmem, hxs, t, ht, hk, hm, hS⟩

/-! ## 本番の実例の表の検査の δ と Scope の契約 -/

/-- `Http.checkRequestIn` のホストのパターンと二つのポートから範囲を得る処理（Scope の検査の項目 `requestCheck` の
動的なパターンと同じ解析と変換）。L40.3b の実例の表 `ModelHttp.builtins` の引数 `hostPat` に渡す。 -/
def hostPatOf (hostPattern : String → Option Scope.Domain.HostPattern) : String → Int → Int → Option Range :=
  fun hp lo hi =>
    match hostPattern hp, Scope.Domain.Port.ofInt? lo, Scope.Domain.Port.ofInt? hi with
    | some h, some l, some u => some (.endpoint ⟨h, ⟨l, u⟩⟩)
    | _, _, _ => none

/-- 要求の値から実効の endpoint を得る処理。要求のレコードの値の対象（`ModelHttp` の引数 `reqTarget`）が endpoint の
ときだけその endpoint を返す（Scope の検査の項目 `requestCheck` の引数 `endpointOf` に渡す）。 -/
def reqEndpoint (reqTarget : Val → Option Target) (v : Val) : Option Scope.Domain.Endpoint :=
  match reqTarget v with
  | some (.endpoint e) => some e
  | _ => none

theorem requestCheck_pattern_hostPatOf (hostPattern : String → Option Scope.Domain.HostPattern)
    (endpointOf : Val → Option Scope.Domain.Endpoint) (bound : List AbsArg → Bound) (hp : String)
    (lo hi : Integer64Value) (req : Val) :
    (requestCheck hostPattern endpointOf bound).pattern [.const (.string hp), .const (.integer lo), .const (.integer hi), req] =
      hostPatOf hostPattern hp lo.toInt hi.toInt := by
  simp only [requestCheck, hostPatOf]
  cases hostPattern hp <;> cases Scope.Domain.Port.ofInt? lo.toInt <;> cases Scope.Domain.Port.ofInt? hi.toInt <;> rfl

/-- L20.7 の実例の表の `Scope.checkPathIn` の δ は、Scope の検査の項目 `pathCheck` の契約を満たす（同じ解析器）。 -/
theorem modelTargets_contract (pat : String → Option Range) (tgt : String → Option Target) :
    (pathCheck ⟨pat, tgt⟩).Contract "Ok" (deltaRun (ModelTargets.builtins pat tgt) "Scope.checkPathIn" [] []) := by
  intro rs vs v w hrun hw
  have hd := deltaRun_eq_some.mp hrun
  obtain ⟨ts, rfl⟩ := okPayload_eq_some hw
  match rs, hd with
  | [r], hd =>
    simp only [ModelTargets.builtins, ite_true, Option.some.injEq] at hd
    obtain ⟨ps, raw, q, t, rfl, hq, ht, rfl, hk, hqm, hrm⟩ := ModelTargets.checkRun_contract hd
    exact ⟨r, q, t, rfl, by simpa [pathCheck] using hq, by simpa [pathCheck] using ht, rfl, hk, hqm, hrm⟩
  | [], hd => simp [ModelTargets.builtins] at hd
  | _ :: _ :: _, hd => simp [ModelTargets.builtins] at hd

/-- L40.3b の実例の表の `Http.checkRequestIn` の δ は、Scope の検査の項目 `requestCheck` の契約を満たす。成功値は
渡された要求を保持する検査済みの要求の値であり、`Val.target?` が実効の endpoint を返す。 -/
theorem modelHttp_contract (hostPattern : String → Option Scope.Domain.HostPattern)
    (reqTarget : Val → Option Target) (bound : List AbsArg → Bound) :
    (requestCheck hostPattern (reqEndpoint reqTarget) bound).Contract "Ok"
      (deltaRun (ModelHttp.builtins (hostPatOf hostPattern) reqTarget) "Http.checkRequestIn" [] []) := by
  intro rs vs v w hrun hw
  have hd := deltaRun_eq_some.mp hrun
  obtain ⟨ts, rfl⟩ := okPayload_eq_some hw
  match rs, hd with
  | [r], hd =>
    simp only [ModelHttp.builtins, ite_true, Option.some.injEq] at hd
    obtain ⟨hp, lo, hi, req, q, t, rfl, -, hreq, hq, rfl, hk, hqm, hrm⟩ := ModelHttp.checkRun_contract hd
    refine ⟨r, q, t, rfl, by rw [requestCheck_pattern_hostPatOf]; exact hq, ?_, rfl, hk, hqm, hrm⟩
    cases t with
    | endpoint e => simp [requestCheck, reqEndpoint, hreq]
    | path _ => cases hk
    | host _ => cases hk
  | [], hd => simp [ModelHttp.builtins] at hd
  | _ :: _ :: _, hd => simp [ModelHttp.builtins] at hd

/-- L40.3b の実例の表の検査の δ の成功値は、渡された要求そのものを保持する。 -/
theorem modelHttp_ok_request {hostPattern : String → Option Scope.Domain.HostPattern}
    {reqTarget : Val → Option Target} {rs : List Range} {vs : List Val} {v w : Val}
    (hrun : deltaRun (ModelHttp.builtins (hostPatOf hostPattern) reqTarget) "Http.checkRequestIn" [] [] rs vs = some v)
    (hw : okPayload "Ok" v = some w) :
    ∃ t req, w = .checkedRequest t req ∧ vs[3]? = some req ∧ reqTarget req = some t := by
  have hd := deltaRun_eq_some.mp hrun
  obtain ⟨ts, rfl⟩ := okPayload_eq_some hw
  match rs, hd with
  | [r], hd =>
    simp only [ModelHttp.builtins, ite_true, Option.some.injEq] at hd
    obtain ⟨hp, lo, hi, req, q, t, rfl, -, hreq, -, rfl, -⟩ := ModelHttp.checkRun_contract hd
    exact ⟨t, req, rfl, rfl, hreq⟩
  | [], hd => simp [ModelHttp.builtins] at hd
  | _ :: _ :: _, hd => simp [ModelHttp.builtins] at hd

/-- Release の実例の表の検査の δ の成功値は、`Boundary.rules` の検査の δ（`checkDelta`）の成功値と同じ形である。
パスの検査（`ModelTargets.checkRun`）は `checkedOk`（検査済みの対象の値）、要求の検査（`ModelHttp.checkRun`）は
`requestOk`（渡された要求を保持する検査済みの要求の値）を返す（RV-L40 軽7）。 -/
theorem modelTargets_checkRun_checkedOk {pat : String → Option Range} {tgt : String → Option Target} {r : Range}
    {ws : List Val} {ts : List Ty} {w : Val} (h : ModelTargets.checkRun pat tgt r ws = .val (.con "Ok" ts [w])) :
    ∃ t, w = checkedOk ws t ∧ r.Mem t := by
  obtain ⟨_ps, _raw, _q, t, -, -, -, rfl, -, -, hrm⟩ := ModelTargets.checkRun_contract h
  exact ⟨t, rfl, hrm⟩

theorem modelHttp_checkRun_requestOk {hostPat : String → Int → Int → Option Range} {reqTarget : Val → Option Target}
    {r : Range} {ws : List Val} {ts : List Ty} {w : Val}
    (h : ModelHttp.checkRun hostPat reqTarget r ws = .val (.con "Ok" ts [w])) :
    ∃ t, w = requestOk ws t ∧ r.Mem t := by
  obtain ⟨_hp, _lo, _hi, _req, _q, t, rfl, -, -, -, rfl, -, -, hrm⟩ := ModelHttp.checkRun_contract h
  exact ⟨t, rfl, hrm⟩

/-- 本番の実例の表の δ を規則にした六つの項目。検査は L20.7 の `Scope.checkPathIn` と L40.3b の `Http.checkRequestIn`
の δ、要求の射影は L40.3b の `Http.requestInValue` の δ である。実例の表に `Scope.pathInValue` の δ はないので、パスの
射影の実行は値を返さない（射影の規則は事実を作らないので、健全性は実行によらない）。 -/
def productionRules (pat : String → Option Range) (tgt : String → Option Target)
    (hostPattern : String → Option Scope.Domain.HostPattern) (reqTarget : Val → Option Target) : Rules where
  checkPath := checkRule (pathCheck ⟨pat, tgt⟩) (deltaRun (ModelTargets.builtins pat tgt) "Scope.checkPathIn" [] [])
  checkRequest := checkRule (requestCheck hostPattern (reqEndpoint reqTarget) (requestLitBound hostPattern))
    (deltaRun (ModelHttp.builtins (hostPatOf hostPattern) reqTarget) "Http.checkRequestIn" [] [])
  pathValue := projectRule (fun _ _ => none)
  requestValue := projectRule (deltaRun (ModelHttp.builtins (hostPatOf hostPattern) reqTarget) "Http.requestInValue" [] [])
  widenPath := widenRule
  widenRequest := widenRule

/-- 本番の実例の表の δ を規則にした表は健全である。条件はない。 -/
theorem productionRules_sound (pat : String → Option Range) (tgt : String → Option Target)
    (hostPattern : String → Option Scope.Domain.HostPattern) (reqTarget : Val → Option Target) :
    (productionRules pat tgt hostPattern reqTarget).Sound (models "Ok" ⟨pat, tgt⟩) :=
  ⟨checkRule_sound (pathCheck_boundSound "Ok" ⟨pat, tgt⟩) (modelTargets_contract pat tgt),
   checkRule_sound (requestLitBound_boundSound "Ok" ⟨pat, tgt⟩ hostPattern (reqEndpoint reqTarget))
     (modelHttp_contract hostPattern reqTarget _),
   projectRule_sound _ _, projectRule_sound _ _, widenRule_sound _, widenRule_sound _⟩

/-- 接続定理の `Http.checkRequestIn` への適用。本番の実例の表の δ を規則にした表で、受理した本体の要求の検査の呼び出し
が `Ok(w)` を返すなら、w は渡された要求 req をそのまま保持する検査済みの要求の値 `checkedRequest t req` であり、実効の
endpoint t は推論した範囲 R に属し、型検査器が受理した範囲 S は R を覆い、t は S に属する。 -/
theorem http_check_connection {pat : String → Option Range} {tgt : String → Option Target}
    {hostPattern : String → Option Scope.Domain.HostPattern} {reqTarget : Val → Option Target}
    {resolve : Key → Option Resolved} {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    (hacc : acceptBody "Ok" (standardTable resolve (productionRules pat tgt hostPattern reqTarget).lookup) L key scope body =
      .ok ())
    {env env' : Locals} {k : Key}
    (hreach : ReachBlock (standardTable resolve (productionRules pat tgt hostPattern reqTarget).lookup) key env body k env')
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences key body) {v : Val}
    (hrhs : RhsEval (standardTable resolve (productionRules pat tgt hostPattern reqTarget).lookup) k env'
      (.call (.primName b ts es rs) labels positions args) (some v))
    (hres : resolve k = some ⟨.standard, checkRequestName⟩) {w : Val} (hw : okPayload "Ok" v = some w) :
    ∃ R t req, w = .checkedRequest t req ∧ reqTarget req = some t ∧ t.kind = .endpoint ∧ R.Mem t ∧
      ∀ S, rs[0]? = some S → S.Covers R ∧ S.Mem t := by
  have hT := Rules.lookup_sound (productionRules_sound pat tgt hostPattern reqTarget) resolve
  have hrule : (standardTable resolve (productionRules pat tgt hostPattern reqTarget).lookup).ruleAt k =
      some (productionRules pat tgt hostPattern reqTarget).checkRequest := by
    simp [ScopeTable.ruleAt, standardTable, hres, Rules.lookup, checkRequestName, checkPathName]
  obtain ⟨st, xs, vs, -, -, ⟨rs', hrun⟩, t, ht, hk, hm, hS⟩ :=
    scope_check_connection hT hacc hreach hocc hrhs hrule hw
  obtain ⟨t', req, rfl, -, hreq⟩ := modelHttp_ok_request hrun hw
  simp only [Val.target?, Option.some.injEq] at ht
  subst ht
  exact ⟨_, t', req, rfl, hreq, hk, hm, hS⟩

/-! ## 出現の番号の一致を到達から得る系（L50.4、RV-L50 中4）

各系は、`hreach : ReachBlock …` と `hocc : (k, e) ∈ occurrences key body` の代わりに、番号 k の文の始まりへ到達し、
その文の右辺が e であること（`ScopeOccurrence.ReachAtBlock … k env' e`）だけを前提に取る。`hocc` は
`ScopeOccurrence.reachAt_occurrences` が与える。 -/

open ScopeOccurrence in
/-- `scope_check_connection` の系。 -/
theorem scope_check_connection_at {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    (hreach : ReachAtBlock T key env body k env' (.call (.primName b ts es rs) labels positions args)) {v : Val}
    (hrhs : RhsEval T k env' (.call (.primName b ts es rs) labels positions args) (some v)) {C : CheckSpec}
    {run : List Range → List Val → Option Val} (hrule : T.ruleAt k = some (checkRule C run)) {w : Val}
    (hw : okPayload ok v = some w) :
    ∃ st xs vs, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
      contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs ∧
      (∃ rs', run rs' vs = some v) ∧
      ∃ t, w.target? = some t ∧ t.kind = C.kind ∧ (C.bound (xs.map (absArg T st))).index.Mem t ∧
        ∀ S, rs[0]? = some S → S.Covers (C.bound (xs.map (absArg T st))).index ∧ S.Mem t :=
  scope_check_connection hT hacc hreach.toReach (reachAt_occurrences hreach) hrhs hrule hw

open ScopeOccurrence in
/-- `scope_local_connection` の系。 -/
theorem scope_local_connection_at {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    (hreach : ReachAtBlock T key env body k env' (.call (.primName b ts es rs) labels positions args)) {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some [.loc i])
    {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Val} (found : env'[i]? = some (some v)) {S : Range} (hS : rs[0]? = some S) :
    ∃ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧ S.Covers (st.requiredIndex i) ∧
      (st.requiredIndex i = .top → S = .top) ∧
      (st.requiredIndex i ≠ .top → ∃ t, v.target? = some t ∧ (st.requiredIndex i).Mem t ∧ S.Mem t) :=
  scope_local_connection hT hacc hreach.toReach (reachAt_occurrences hreach) hxs hrule hidx found hS

open ScopeOccurrence in
/-- `scope_local_typed_of_typed` の系。 -/
theorem scope_local_typed_at {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    (hreach : ReachAtBlock T key env body k env' (.call (.primName b ts es rs) labels positions args)) {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some [.loc i])
    {rule : ScopeRule Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Val} (found : env'[i]? = some (some v)) {S : Range} (hS : rs[0]? = some S) (hSne : S ≠ .top)
    {Pr : Release.Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : List TParam} {Γ : List (Option Ty)}
    {name : OpaqueName} {kd : Scope.Domain.Kind} (hk : B.valKind name = some kd) (hfit : S.kind? = some kd)
    {Ψ' : StoreTy} {Q' : NoFailCtx} {C' : List TParam} {Γ' : List (Option Ty)}
    {ix : Scope.Signature.Ix} (hv : HasTypeVQ Pr B Ψ' Q' C' Γ' v (.opaque name ix)) (hΨ : StoreTy.Sub Ψ' Ψ) :
    HasTypeVQ Pr B Ψ Q C Γ v (.opaque name (.fixed S)) :=
  scope_local_typed_of_typed hT hacc hreach.toReach (reachAt_occurrences hreach) hxs hrule hidx found hS hSne hk hfit hv
    hΨ

open ScopeOccurrence in
/-- `scope_check_core` の系。 -/
theorem scope_check_core_at {ok : ConName} {P : Parsers} {T : ScopeTable Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (hT : TableSound (models ok P) T)
    (hacc : acceptBody ok T L key scope body = .ok ()) {env env' : Locals} {k : Key}
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    (hreach : ReachAtBlock T key env body k env' (.call (.primName b ts es rs) labels positions args))
    {vals vs : List Val} (hargs : ArgEvals T env' (argsKey k (.primName b ts es rs)) args vals)
    (hord : contractOrder positions vals = some vs) {B : Builtins} {C : CheckSpec}
    (hrule : T.ruleAt k = some (checkRule C (deltaRun B b ts es))) {v : Val}
    (hδ : B.delta b ts es rs vs = some (.val v)) {s : PrimSig} (hs : B.sig b = some s) (hpure : s.kind = .pure)
    (op : OpPrim) (pos : Position) (Pr : Release.Program) (K : Cont) (σ : Store) :
    desugarExpr op pos (.primName b ts es rs) = .ret (.prim b ts es rs) ∧
      Release.Step Pr B (.run (.app (.prim b ts es rs) vs) K σ) none (.run (.ret v) K σ) ∧
      ∀ w, okPayload ok v = some w →
        ∃ st xs, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
          contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs ∧
          ∃ t, w.target? = some t ∧ t.kind = C.kind ∧ (C.bound (xs.map (absArg T st))).index.Mem t ∧
            ∀ S, rs[0]? = some S → S.Covers (C.bound (xs.map (absArg T st))).index ∧ S.Mem t :=
  scope_check_core hT hacc hreach.toReach (reachAt_occurrences hreach) hargs hord hrule hδ hs hpure op pos Pr K σ

/-! ## 旧 Scope の小モデルとの対応 -/

section OldScope

variable {Pr : Release.Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : List TParam}
  {Γ : List (Option Ty)}

/-- 旧 Scope の検査済みのパスの対象は、新しい値の形の検査済みの対象の値として、パターンの範囲 `PathIn[R]` を持つ。 -/
theorem CheckedPath.hasTypeV (v : Checked.Scope.CheckedPath) (hk : B.valKind "Scope.PathIn" = some .path) :
    HasTypeVQ Pr B Ψ Q C Γ (.checked v.toTarget) (.opaque "Scope.PathIn" (.fixed v.toRange)) :=
  .V_Checked hk v.memK.2

/-- パターンの範囲を覆う範囲 r の `PathIn[r]` も持つ（旧 Scope の拡大 `makePath_widen` の新しい形）。 -/
theorem CheckedPath.hasTypeV_of_covers (v : Checked.Scope.CheckedPath) (hk : B.valKind "Scope.PathIn" = some .path)
    {r : Range} (h : r.Covers v.toRange) :
    HasTypeVQ Pr B Ψ Q C Γ (.checked v.toTarget) (.opaque "Scope.PathIn" (.fixed r)) :=
  .V_Checked hk (v.mem_of_covers h)

/-- 旧 Scope の検査済みのエンドポイント（ホスト名・IP アドレス）の対象は、`Http.RequestIn[R]`（R はホストのパターンと
ポートの組の範囲）を持つ検査済みの対象の値である。 -/
theorem CheckedEndpoint.hasTypeV (v : Checked.Scope.CheckedEndpoint) (hk : B.valKind "Http.RequestIn" = some .endpoint) :
    HasTypeVQ Pr B Ψ Q C Γ (.checked v.toTarget) (.opaque "Http.RequestIn" (.fixed v.toRange)) :=
  .V_Checked hk v.memK.2

theorem CheckedEndpoint.hasTypeV_of_covers (v : Checked.Scope.CheckedEndpoint)
    (hk : B.valKind "Http.RequestIn" = some .endpoint) {r : Range} (h : r.Covers v.toRange) :
    HasTypeVQ Pr B Ψ Q C Γ (.checked v.toTarget) (.opaque "Http.RequestIn" (.fixed r)) :=
  .V_Checked hk (v.mem_of_covers h)

end OldScope

/-- 旧 Scope のパスの検査が成功する入力では、L20.7 の実例の表の検査の δ は、具体化した範囲 r が対象を含むときだけ
旧の検査済みの値と同じ対象の `Ok` を返す。 -/
theorem makePath_checkRun {p : Scope.Domain.PathPattern} {w : Scope.Domain.Word} {v : Checked.Scope.CheckedPath}
    (h : Checked.Scope.makePath p w = .ok v) {pat : String → Option Range} {tgt : String → Option Target}
    {ps raw : String} (hp : pat ps = some (.path p)) (ht : tgt raw = some (.path w)) (r : Range) :
    ModelTargets.checkRun pat tgt r [.const (.string ps), .const (.string raw)] =
      if r.Mem v.toTarget then .val (.con "Ok" (ModelTargets.checkTys r) [.checked v.toTarget])
      else .val (.con "Err" (ModelTargets.checkTys r) [ModelTargets.scopeFailure]) := by
  obtain ⟨hvp, hvt, hm, -, -⟩ := Checked.Scope.makePath_ok p w v h
  have htv : v.toTarget = .path w := by simp [Checked.Scope.CheckedPath.toTarget, hvt]
  rw [htv]
  have hq : (Range.path p).Mem (.path w) := hm
  by_cases hr : r.Mem (.path w)
  · have hc : (Target.path w).kind = .path ∧ (Range.path p).Mem (.path w) ∧ r.Mem (.path w) := ⟨rfl, hq, hr⟩
    simp only [ModelTargets.checkRun, hp, ht, ite_eq_left hc, ite_eq_left hr]
  · have hc : ¬ ((Target.path w).kind = .path ∧ (Range.path p).Mem (.path w) ∧ r.Mem (.path w)) :=
      fun h => hr h.2.2
    simp only [ModelTargets.checkRun, hp, ht, ite_eq_right hc, ite_eq_right hr]

/-- 旧 Scope のエンドポイントの検査（ホスト名・IP アドレスと CIDR）が成功する入力では、L40.3b の実例の表の要求の検査の
δ は、具体化した範囲 r が実効の endpoint を含むときだけ、渡された要求を保持する `Ok(checkedRequest(t, req))` を返す。
要求の実効の endpoint は旧の検査済みの値の対象 t とし、要求のレコードは型の変数を含まないとする。 -/
theorem makeEndpoint_checkRun {p : Scope.Domain.HostPattern} {host : Scope.Domain.HostTarget} {lo hi port : Int}
    {v : Checked.Scope.CheckedEndpoint} (h : Checked.Scope.makeEndpoint p host lo hi port = .ok v)
    {hostPattern : String → Option Scope.Domain.HostPattern} {hp : String} (hhp : hostPattern hp = some p)
    {reqTarget : Val → Option Target} {req : Val} (hcl : ModelHttp.groundVal req = true)
    (hreq : reqTarget req = some v.toTarget)
    {lo' hi' : Integer64Value} (hlo : lo'.toInt = lo) (hhi : hi'.toInt = hi) (r : Range) :
    ModelHttp.checkRun (hostPatOf hostPattern) reqTarget r
        [.const (.string hp), .const (.integer lo'), .const (.integer hi'), req] =
      if r.Mem v.toTarget then .val (.con "Ok" (ModelHttp.checkTys r) [.checkedRequest v.toTarget req])
      else .val (.con "Err" (ModelHttp.checkTys r) [ModelHttp.scopeFailure]) := by
  obtain ⟨hvp, -, hvlo, hvhi, -⟩ := Checked.Scope.makeEndpoint_ok p host lo hi port v h
  have hpat : hostPatOf hostPattern hp lo'.toInt hi'.toInt = some v.toRange := by
    have h1 := v.ofInt?_minimum
    have h2 := v.ofInt?_maximum
    rw [hvlo] at h1
    rw [hvhi] at h2
    simp only [hostPatOf, hhp, hlo, hhi, h1, h2, Checked.Scope.CheckedEndpoint.toRange,
      Checked.Scope.CheckedEndpoint.toPattern, hvp]
  have hmem : v.toRange.Mem v.toTarget := v.memK.2
  have hk : v.toTarget.kind = .endpoint := rfl
  by_cases hr : r.Mem v.toTarget
  · simp only [ModelHttp.checkRun, hcl, ite_true, hreq, hpat, ite_eq_left (And.intro hk (And.intro hmem hr)),
      ite_eq_left hr]
  · have hc : ¬ (v.toTarget.kind = .endpoint ∧ v.toRange.Mem v.toTarget ∧ r.Mem v.toTarget) := fun h => hr h.2.2
    simp only [ModelHttp.checkRun, hcl, ite_true, hreq, hpat, ite_eq_right hc, ite_eq_right hr]

end Benitoite.Surface.ScopeSound
