import Benitoite.Release.Refinement.Surface.ScopeReach
import Benitoite.Release.Refinement.Surface.ScopeSound
import Benitoite.Release.Refinement.Surface.CheckAcceptBase
import Benitoite.Release.Refinement.Surface.Desugar
import Benitoite.Release.Refinement.Step
import Benitoite.Release.Refinement.HeldValues

/-!
# Scope の接続定理

Scope の局所解析（`Surface.ScopeLower`）と受理（`Surface.ScopeAccept`・`Surface.OpenScopeAccept`・
`Surface.CheckAccept`）を、表層の具体の評価（`Surface.ScopeReach`）と脱糖した核の項の実行へ接続する
（設計書 01-12「Scope の局所解析の接続定理」、07-04「証明する性質」）。

- 出現の受理（`OccurrenceAccepted`）: 一つの出現の呼び出しを、局所解析の記録で照らして受理したこと。閉じた由来の
  本体の受理は全ての出現でこれを与え（`OccurrenceAccepted.of_body`）、範囲を具体化する本体の受理は、型が保持する
  範囲を選ぶ規則が選ばなかった出現でこれを与える（`OccurrenceAccepted.of_open`）。プログラム全体の受理
  （`Accepted`。`acceptProgram_sound` の結論）は、定義の本体で `OccurrenceAccepted.of_def` を、実装メソッドの本体
  （閉じた由来の受理。`Accepted.method_body`）で `OccurrenceAccepted.of_body` を通してこれを与える。
- 検査の成功値（`scope_check_connection`）: 受理した出現の検査の直接の呼び出しへ評価が到達し、呼び出しが `Ok(w)` を
  返すなら、w は対象 t を保持し、t は局所解析が推論した範囲 R に属し、型検査器が受理した範囲の列の位置 0 の範囲 S は
  R を覆い、t は S に属する。
- 射影・拡大が指す値（`scope_local_connection`）: 局所の位置 i を引数にする射影・拡大の呼び出しの文へ到達するなら、
  その文の記録の必須の判定の添字 R を S が覆い、R が Top なら S も Top であり、R が Top でなければ位置 i の値は
  R と S の両方に属する対象を保持する。型付けの系（`scope_local_typed`）は、その値が核の範囲付きの型を持つことを示す。
- 核の実行の形（`scope_check_core`）: 規則の実行を本番の表の δ にした表では、脱糖した核の項（同じ範囲の列を持つ
  組み込みの呼び出し）が E_Prim で同じ値へ進み、その値の成功値について検査の成功値の接続が成り立つ。
- `Http.checkRequestIn`（`http_check_connection`）: 本番の規則の表で、検査の成功値は渡された要求を保持する検査済みの
  要求の値であり、その実効の endpoint は R と S に属する。

前提は、表の健全性・出現の受理・表層の具体の評価だけであり、区間解析の結果を読まない。
-/

namespace Benitoite.Release.Refinement.Surface.ScopeSound

open Benitoite.Scope.Inference
open ScopeState ScopeLower ScopeAccept
open Benitoite.Scope.Domain (Range Target)

noncomputable section

/-- 閉じた絶対範囲の列を、核の範囲の具体化の列にする。 -/
abbrev fixedRanges (rs : List Range) : List RangeIx := rs.map (fun r => RangeIx.fixed (.absolute r))

/-! ## 本番の δ を規則の実行にする -/

/-- 型引数と効果引数を持つ組み込みの関数 b の δ を、Scope の規則の実行にする。δ は核の E_Prim と同じく正規化した
型引数と効果引数で呼ぶ。値を返す結果だけを値とする。 -/
def deltaRunAt (B : Builtins) (b : PrimName) (ts : List Ty) (es : List Eff) :
    List Range → List Refinement.Val → Option Refinement.Val :=
  fun rs vs =>
    match B.delta b (Ty.normTys ts) (es.map Eff.norm) (rs.map .absolute) vs with
    | some (.val v) => some v
    | _ => none

theorem deltaRunAt_eq_some {B : Builtins} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range}
    {vs : List Refinement.Val} {v : Refinement.Val} :
    deltaRunAt B b ts es rs vs = some v ↔
      B.delta b (Ty.normTys ts) (es.map Eff.norm) (rs.map .absolute) vs = some (.val v) := by
  unfold deltaRunAt
  constructor
  · intro h
    split at h
    · next v' hd => cases h; exact hd
    · cases h
  · intro h
    rw [h]

/-- 同じ R の接続。Scope の規則の実行が本番の δ なら、局所解析の評価関係が返す値は、同じ範囲の列を持つ核の
組み込みの呼び出しが E_Prim で返す値と同じである。 -/
theorem evalScope_core_step {T : ScopeTable Refinement.Val} {k : Key} {rule : ScopeRule Refinement.Val}
    (hrule : T.ruleAt k = some rule) {B : Builtins} {b : PrimName} {ts : List Ty} {es : List Eff}
    (hrun : rule.run = deltaRunAt B b ts es) {rs : List Range} {vs : List Refinement.Val} {v : Refinement.Val}
    (hev : EvalScope T k rs vs v) {s : PrimSig} (hs : B.sig b = some s) (hpure : s.kind = .pure)
    (P : Benitoite.Release.Refinement.Program) (σ : PathEnv) {q : Closure}
    (hq : q.view = .app (.prim b ts es (fixedRanges rs)) vs) (K : Cont) (μ : Store) :
    Benitoite.Release.Refinement.Step P B σ (.run q K μ) none (.run (Closure.pure (.ret v)) K μ) := by
  cases hev with
  | apply rule' _ identified run =>
    rw [hrule] at identified
    cases identified
    rw [hrun] at run
    refine .E_Prim (rs := rs.map .absolute) ?_ hs hpure (deltaRunAt_eq_some.mp run)
    rw [hq]
    simp [fixedRanges, List.map_map, Function.comp_def]

/-- 規則の評価関係の逆転。 -/
theorem evalScope_run {T : ScopeTable Refinement.Val} {k : Key} {rule : ScopeRule Refinement.Val}
    (hrule : T.ruleAt k = some rule) {rs : List Range} {vs : List Refinement.Val} {v : Refinement.Val}
    (hev : EvalScope T k rs vs v) : rule.run rs vs = some v := by
  cases hev with
  | apply rule' _ identified run =>
    rw [hrule] at identified
    cases identified
    exact run

/-! ## 出現の受理 -/

/-- 本体 body の番号 k の出現 e を、その本体の局所解析の記録で照らして受理したこと。 -/
def OccurrenceAccepted (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key)
    (scope : Interval.BindingScope) (body : Block) (k : Key) (e : Expr) : Prop :=
  acceptOccurrence T (analyzeBody ok T L key scope body).2 (analyzeBody ok T L key scope body).1.exceeded.isSome
    k e = .ok ()

/-- 閉じた由来の本体の受理は、全ての出現の受理を与える。 -/
theorem OccurrenceAccepted.of_body {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} (h : ScopeAccept.acceptBody ok T L key scope body = .ok ())
    {k : Key} {e : Expr} (hocc : (k, e) ∈ occurrences key body) : OccurrenceAccepted ok T L key scope body k e :=
  acceptBody_occurrence h k e hocc

/-- 範囲を具体化する本体の受理は、型が保持する範囲を選ぶ規則が選ばなかった出現の受理を与える。 -/
theorem OccurrenceAccepted.of_open {rules : List OpenScopeAccept.Rule} {ks : List Scope.Domain.Kind}
    {params : List Ty} {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block}
    (h : OpenScopeAccept.acceptBody rules ks params ok T L key scope body = .ok ())
    {k : Key} {e : Expr} (hocc : (k, e) ∈ occurrences key body)
    (hsel : (OpenScopeAccept.selections rules params key body).lookup k = none) :
    OccurrenceAccepted ok T L key scope body k e := by
  unfold OpenScopeAccept.acceptBody at h
  split at h
  · next closed =>
    obtain ⟨-, accepted⟩ := Bool.and_eq_true_iff.mp closed
    have old : ScopeAccept.acceptBody ok T L key scope body = .ok () := by
      cases result : ScopeAccept.acceptBody ok T L key scope body with
      | error failure => simp only [result, Except.toBool, Bool.false_eq_true] at accepted
      | ok value => cases value; rfl
    exact OccurrenceAccepted.of_body old hocc
  · have hp := allOk_ok h (k, e) hocc
    dsimp only at hp
    have hsel' : (if (T.ruleAt k).isSome then (OpenScopeAccept.selections rules params key body).lookup k
        else none) = none := by split <;> simp [hsel]
    rw [hsel'] at hp
    simp only at hp
    unfold OccurrenceAccepted
    split at hp
    · assumption
    · cases hp

/-- 受理したプログラムの定義の本体の出現のうち、型が保持する範囲を選ぶ規則が選ばなかったものは受理されている。 -/
theorem OccurrenceAccepted.of_def {A : CheckAccept.AcceptInput} {q : Check.Input} {p : Program}
    (h : CheckAccept.Accepted A q p) {n : FunName} {d : Def} (hd : p.defs n = some d)
    {k : Key} {e : Expr} (hocc : (k, e) ∈ occurrences (CheckAccept.bodyKey n) d.body)
    (hsel : (OpenScopeAccept.selections A.openRules d.coreParams (CheckAccept.bodyKey n) d.body).lookup k = none) :
    OccurrenceAccepted A.ok (CheckAccept.tableFor A (CheckAccept.bodyKey n) d.body) A.limits
      (CheckAccept.bodyKey n) (CheckAccept.entryScope d.coreParams.length) d.body k e :=
  OccurrenceAccepted.of_open (h.def_body hd) hocc hsel

/-- 受理した出現の規則付きの呼び出しの範囲の列は、その出現の全ての記録の状態で、規則が選ぶ範囲を各位置で覆い、
規則が範囲を選ぶ全ての位置に契約の範囲を持つ。 -/
theorem OccurrenceAccepted.covers {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits} {key : Key}
    {scope : Interval.BindingScope} {body : Block} {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff}
    {rs : List Range} {labels positions args xs}
    (h : OccurrenceAccepted ok T L key scope body k (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (fixedRanges rs))) args) = some xs)
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule) :
    ∀ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T st)))[i]? = some r → ∃ S, rs[i]? = some S ∧ S.Covers r := by
  unfold OccurrenceAccepted at h
  simp only [fixedRanges, acceptOccurrence, absoluteRanges_fixed, hxs] at h
  intro st hst i r hr
  obtain ⟨S, hS⟩ := acceptCall_some h hrule st hst i r hr
  exact ⟨S, hS, acceptCall_sound h hrule st hst i S r hS hr⟩

/-! ## 検査の成功値の接続 -/

/-- 表層の具体の評価が、規則を持つ組み込みの名前の直接の呼び出しを値 v へ評価するなら、契約の順の引数の列 xs と
値の列 vs があり、局所の評価の上で規則を評価した値である（`RhsEval` の逆転）。 -/
theorem rhsEval_prim {T : ScopeTable Refinement.Val} {k : Key} {env : Locals} {b : PrimName} {ts : List Ty}
    {es : List Eff} {ix : List RangeIx} {labels positions} {args : Exprs} {v : Refinement.Val}
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule)
    (h : RhsEval T k env (.call (.primName b ts es ix) labels positions args) (some v)) :
    ∃ xs vs rs', contractOrder positions (lowerArgs (argsKey k (.primName b ts es ix)) args) = some xs ∧
      EvalArgs T env xs vs ∧ EvalScope T k rs' vs v := by
  cases h with
  | callStd _ hargs hord heval =>
    obtain ⟨xs, hxs, hev⟩ := contractOrder_evalArgs (argEvals_lower hargs) hord
    exact ⟨xs, _, _, hxs, hev, heval⟩
  | callOther missing => rw [hrule] at missing; cases missing
  | indirect hd => simp [directHead] at hd
  | other hc => simp [callOrLocal] at hc

/-- 接続定理（検査の成功値）。受理した出現 k の検査の直接の呼び出しへ、受理した本体の評価が局所 env' で到達し、
呼び出しが `Ok(w)` を返すなら、記録の状態 st と契約の順の引数 xs と値の列 vs があり、規則の実行は vs で v を返した。
w は対象 t を保持し、t は検査の種類を持ち、局所解析が推論した範囲 R（抽象の結果の由来の添字）に属する。型検査器が
受理した範囲の列 rs の位置 0 の範囲 S は R を覆い、t は S に属する。検査の δ の契約を仮定しない（R への所属は
規則の健全性から、S への所属は被覆の健全性から得る）。 -/
theorem scope_check_connection {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    (hT : TableSound (models ok pattern) T) {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff}
    {rs : List Range} {labels positions} {args : Exprs}
    (hacc : OccurrenceAccepted ok T L key scope body k
      (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    {env env' : Locals} (hreach : ReachBlock T key env body k env') {v : Refinement.Val}
    (hrhs : RhsEval T k env' (.call (.primName b ts es (fixedRanges rs)) labels positions args) (some v))
    {C : CheckSpec} {run : List Range → List Refinement.Val → Option Refinement.Val}
    (hrule : T.ruleAt k = some (checkRule C run)) {w : Refinement.Val} (hw : okPayload ok v = some w) :
    ∃ st xs vs, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
      contractOrder positions (lowerArgs (argsKey k (.primName b ts es (fixedRanges rs))) args) = some xs ∧
      (∃ rs', run rs' vs = some v) ∧
      ∃ t, w.target? = some t ∧ t.kind = C.kind ∧ (C.bound (xs.map (absArg T st))).index.Mem t ∧
        ∃ S, rs[0]? = some S ∧ S.Covers (C.bound (xs.map (absArg T st))).index ∧ S.Mem t := by
  obtain ⟨st, hmem, hst⟩ := analyzeBody_sound (L := L) (scope := scope) hT hreach
  obtain ⟨xs, vs, rs', hxs, hev, heval⟩ := rhsEval_prim hrule hrhs
  have hargs := absArgs_models hT hst hev
  have habs : absApply T k (xs.map (absArg T st)) =
      some (.result ⟨k, C.kind, C.bound (xs.map (absArg T st))⟩) := by
    simp [absApply, hrule, checkRule]
  have hfact := apply_sound hT hargs heval habs 0
  obtain ⟨t, ht, hk, hm⟩ := checkedModels_iff.mp (hfact w hw)
  obtain ⟨S, hS, hcov⟩ := hacc.covers hxs hrule st hmem 0 _ rfl
  exact ⟨st, xs, vs, hmem, hxs, ⟨rs', evalScope_run hrule heval⟩, t, ht, hk, hm, S, hS, hcov,
    Range.Covers.sound hcov t hm⟩

/-! ## 射影・拡大が指す値の接続 -/

/-- 接続定理（射影・拡大が指す値）。受理した出現 k の、局所の位置 i を引数にする規則付きの直接の呼び出し（規則の
`index` は引数の必須の判定の添字。射影と明示拡大の `projectRule` はこれを満たす。`projectRule_index`）へ評価が局所 env' で到達するなら、記録の状態 st が
あり、型検査器が受理した範囲の列は位置 0 の範囲 S を持ち、S は st の位置 i の必須の判定の添字 R を覆う。R が Top なら
S は Top であり、R が Top でなければ、位置 i の値は R と S の両方に属する対象を保持する。 -/
theorem scope_local_connection {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    (hT : TableSound (models ok pattern) T) {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff}
    {rs : List Range} {labels positions} {args : Exprs}
    (hacc : OccurrenceAccepted ok T L key scope body k
      (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    {env env' : Locals} (hreach : ReachBlock T key env body k env') {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (fixedRanges rs))) args) = some [.loc i])
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Refinement.Val} (found : env'[i]? = some (some v)) :
    ∃ st S, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧ rs[0]? = some S ∧
      S.Covers (st.requiredIndex i) ∧ (st.requiredIndex i = .top → S = .top) ∧
      (st.requiredIndex i ≠ .top → ∃ t, v.target? = some t ∧ (st.requiredIndex i).Mem t ∧ S.Mem t) := by
  obtain ⟨st, hmem, hst⟩ := analyzeBody_sound (L := L) (scope := scope) hT hreach
  obtain ⟨S, hS, hcov⟩ := hacc.covers hxs hrule st hmem 0 (st.requiredIndex i)
    (by simp [hidx, absArg, argIndex_readLocal])
  refine ⟨st, S, hmem, hS, hcov, fun htop => ?_, fun hne => ?_⟩
  · rw [htop] at hcov
    exact (Range.covers_top_iff S).mp hcov
  · obtain ⟨_, t, ht, -, -, hm⟩ := requiredIndex_checked hst found hne
    exact ⟨t, ht, hm, Range.Covers.sound hcov t hm⟩

/-- 射影と明示拡大の規則の `index` は、引数の必須の判定の添字である。 -/
theorem projectRule_index (run : List Range → List Refinement.Val → Option Refinement.Val) (a : AbsArg) :
    (projectRule run).index [a] = [argIndex a] := rfl

/-- 対象を保持する検査済みの対象の値と検査済みの要求の値は、名前 name の種類と保持する内容が型付けの規則の前提を
満たせば、対象の属する範囲付きの型を持つ（規則 V_Checked・V_CheckedRequest）。 -/
theorem target_hasTypeV {P : Benitoite.Release.Refinement.Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx}
    {Φ : List Pred} {v : Refinement.Val} {t : Target} {S : Range} {name : OpaqueName} {kd : Scope.Domain.Kind}
    (ht : v.target? = some t) (hk : B.valKind name = some kd) (htk : t.kind = kd) (hm : S.Mem t)
    (hc : (v = .checked t ∧ B.valContent name = none) ∨
      ∃ req A, v = .checkedRequest t req ∧ kd = .endpoint ∧ B.valContent name = some A ∧
        HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧ req.reqTarget = some t) :
    HasTypeVQ P B Ψ Q C Γ Φ v (.scoped name kd (.fixed (.absolute S))) := by
  rcases hc with ⟨rfl, hn⟩ | ⟨req, A, rfl, rfl, hA, hreq, hg, hr⟩
  · exact .V_Checked hk hn ⟨htk, hm⟩
  · exact .V_CheckedRequest hk hA hreq hg hr ⟨htk, hm⟩

/-- 接続定理の型付けの系。狭い契約（Top でない S）を受理した射影・拡大の呼び出しの引数の値は、名前 name の種類が S の
種類と同じで、値の形と保持する内容が型付けの規則の前提を満たせば、核の入力の型 `name[S]` を持つ。 -/
theorem scope_local_typed {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    (hT : TableSound (models ok pattern) T) {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff}
    {rs : List Range} {labels positions} {args : Exprs}
    (hacc : OccurrenceAccepted ok T L key scope body k
      (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    {env env' : Locals} (hreach : ReachBlock T key env body k env') {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (fixedRanges rs))) args) = some [.loc i])
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Refinement.Val} (found : env'[i]? = some (some v))
    {S : Range} (hS : rs[0]? = some S) (hSne : S ≠ .top)
    {P : Benitoite.Release.Refinement.Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx}
    {Φ : List Pred}
    {name : OpaqueName} {kd : Scope.Domain.Kind} (hk : B.valKind name = some kd) (hfit : S.kind? = some kd)
    (hc : ∀ t, v.target? = some t → (v = .checked t ∧ B.valContent name = none) ∨
      ∃ req A, v = .checkedRequest t req ∧ kd = .endpoint ∧ B.valContent name = some A ∧
        HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧ req.reqTarget = some t) :
    HasTypeVQ P B Ψ Q C Γ Φ v (.scoped name kd (.fixed (.absolute S))) := by
  obtain ⟨st, S', -, hS', -, htop, hval⟩ := scope_local_connection hT hacc hreach hxs hrule hidx found
  rw [hS] at hS'
  cases hS'
  have hne : st.requiredIndex i ≠ .top := fun h => hSne (htop h)
  obtain ⟨t, ht, -, hmS⟩ := hval hne
  have hkind : S.kind? = some t.kind := Range.kind_of_mem hmS hSne
  rw [hfit] at hkind
  cases hkind
  exact target_hasTypeV ht hk rfl hmS (hc t ht)

/-! ## 核の実行の形 -/

/-- 接続定理（検査の成功値、核の実行の形）。受理した出現 k の検査の直接の呼び出しへ評価が局所 env' で到達し、
引数が値の列 vs に評価され、検査の規則の実行が本番の表 B の δ であるとする。脱糖は組み込みの名前を同じ範囲の列を
持つ核の項へ書き、それを同じ引数へ適用する核の状態は E_Prim で δ の値 v へ進む。v が `Ok(w)` なら、w は対象 t を
保持し、t は推論した範囲 R に属し、rs の位置 0 の範囲 S は R を覆い、t は S に属する。 -/
theorem scope_check_core {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    (hT : TableSound (models ok pattern) T) {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff}
    {rs : List Range} {labels positions} {args : Exprs}
    (hacc : OccurrenceAccepted ok T L key scope body k
      (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    {env env' : Locals} (hreach : ReachBlock T key env body k env')
    {vals vs : List Refinement.Val} (hargs : ArgEvals T env' (argsKey k (.primName b ts es (fixedRanges rs))) args vals)
    (hord : contractOrder positions vals = some vs) {B : Builtins} {Csp : CheckSpec}
    (hrule : T.ruleAt k = some (checkRule Csp (deltaRunAt B b ts es))) {v : Refinement.Val}
    (hδ : B.delta b (Ty.normTys ts) (es.map Eff.norm) (rs.map .absolute) vs = some (.val v))
    {s : PrimSig} (hs : B.sig b = some s) (hpure : s.kind = .pure)
    (op : OpPrim) (pos : Position) (P : Benitoite.Release.Refinement.Program) (σ : PathEnv) {q : Closure}
    (hq : q.view = .app (.prim b ts es (fixedRanges rs)) vs) (K : Cont) (μ : Store) :
    desugarExpr op pos (.primName b ts es (fixedRanges rs)) = .ret (.prim b ts es (fixedRanges rs)) ∧
      directCallee (.primName b ts es (fixedRanges rs)) = some (.app (.prim b ts es (fixedRanges rs)) []) ∧
      Benitoite.Release.Refinement.Step P B σ (.run q K μ) none (.run (Closure.pure (.ret v)) K μ) ∧
      ∀ w, okPayload ok v = some w →
        ∃ st xs, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
          contractOrder positions (lowerArgs (argsKey k (.primName b ts es (fixedRanges rs))) args) = some xs ∧
          ∃ t, w.target? = some t ∧ t.kind = Csp.kind ∧ (Csp.bound (xs.map (absArg T st))).index.Mem t ∧
            ∃ S, rs[0]? = some S ∧ S.Covers (Csp.bound (xs.map (absArg T st))).index ∧ S.Mem t := by
  have heval : EvalScope T k rs vs v := .apply _ v hrule (deltaRunAt_eq_some.mpr hδ)
  have hrhs : RhsEval T k env' (.call (.primName b ts es (fixedRanges rs)) labels positions args) (some v) :=
    .callStd rfl hargs hord heval
  refine ⟨by simp [desugarExpr], rfl, evalScope_core_step hrule rfl heval hs hpure P σ hq K μ, fun w hw => ?_⟩
  obtain ⟨st, xs, -, hmem, hxs, -, t, ht, hk, hm, hS⟩ := scope_check_connection hT hacc hreach hrhs hrule hw
  exact ⟨st, xs, hmem, hxs, t, ht, hk, hm, hS⟩

/-! ## `Http.checkRequestIn` への適用 -/

/-- 接続定理の `Http.checkRequestIn` への適用。本番の規則の表（`productionRules`）で、受理した出現の要求の検査の
呼び出しが `Ok(w)` を返すなら、w は渡された要求 req をそのまま保持する検査済みの要求の値 `checkedRequest t req` であり、
実効の endpoint t は推論した範囲 R に属し、型検査器が受理した範囲 S は R を覆い、t は S に属する。 -/
theorem http_check_connection {pathTable : String → Option Range} {host : String → Option Scope.Domain.HostPattern}
    {ok : ConName} (hne : ok ≠ "Result.Error") (facts : String → Option Range)
    {resolve : Key → Option Resolved} {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    (hacc : OccurrenceAccepted ok (standardTable resolve (productionRules pathTable host).lookup) L key scope body k
      (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    {env env' : Locals}
    (hreach : ReachBlock (standardTable resolve (productionRules pathTable host).lookup) key env body k env')
    {v : Refinement.Val}
    (hrhs : RhsEval (standardTable resolve (productionRules pathTable host).lookup) k env'
      (.call (.primName b ts es (fixedRanges rs)) labels positions args) (some v))
    (hres : resolve k = some ⟨.standard, checkRequestName⟩) {w : Refinement.Val} (hw : okPayload ok v = some w) :
    ∃ R t req, w = .checkedRequest (.endpoint t) req ∧ req.reqTarget = some (.endpoint t) ∧ R.Mem (.endpoint t) ∧
      ∃ S, rs[0]? = some S ∧ S.Covers R ∧ S.Mem (.endpoint t) := by
  have hT := Rules.lookup_sound (productionRules_sound pathTable host hne facts) resolve
  have hrule : (standardTable resolve (productionRules pathTable host).lookup).ruleAt k =
      some (productionRules pathTable host).checkRequest := by
    simp [ScopeTable.ruleAt, standardTable, hres, Rules.lookup, checkRequestName, checkPathName]
  obtain ⟨st, xs, vs, -, -, ⟨rs', hrun⟩, t, ht, -, hm, S, hS, hcov, hSm⟩ :=
    scope_check_connection hT hacc hreach hrhs hrule hw
  have hd := deltaRun_eq_some.mp hrun
  simp only [ModelHttp.builtins, ScopeSignatures.builtins, ScopeResponse.delta, RequestDelta.delta,
    checkRequestName, true_and, ↓reduceIte] at hd
  rw [ite_eq_right (by decide)] at hd
  match rs', hd with
  | [r], hd =>
    simp only [List.map_cons, List.map_nil, Option.some.injEq] at hd
    obtain ⟨-, -, -, req, endpoint, -, -, hreq, -, -, -, -, -, -, rfl⟩ := requestRun_ok hne hd hw
    simp only [Refinement.Val.target?, Option.some.injEq] at ht
    subst ht
    exact ⟨_, endpoint, req, rfl, hreq, hm, S, hS, hcov, hSm⟩
  | [], hd => simp at hd
  | _ :: _ :: _, hd => simp at hd

/-! ## 到達した文の右辺から出現を得る系

各系は、本体の受理と、番号 k の文の始まりへ到達しその文の右辺が呼び出し e であること（`ReachAtBlock`）を前提に取る。
出現の受理は `reachAt_occurrences` と `OccurrenceAccepted.of_body` が与える。 -/

/-- `scope_check_connection` の系。 -/
theorem scope_check_connection_at {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    (hT : TableSound (models ok pattern) T) (hacc : ScopeAccept.acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    {env env' : Locals}
    (hreach : ReachAtBlock T key env body k env' (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    {v : Refinement.Val}
    (hrhs : RhsEval T k env' (.call (.primName b ts es (fixedRanges rs)) labels positions args) (some v))
    {C : CheckSpec} {run : List Range → List Refinement.Val → Option Refinement.Val}
    (hrule : T.ruleAt k = some (checkRule C run)) {w : Refinement.Val} (hw : okPayload ok v = some w) :
    ∃ st xs vs, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
      contractOrder positions (lowerArgs (argsKey k (.primName b ts es (fixedRanges rs))) args) = some xs ∧
      (∃ rs', run rs' vs = some v) ∧
      ∃ t, w.target? = some t ∧ t.kind = C.kind ∧ (C.bound (xs.map (absArg T st))).index.Mem t ∧
        ∃ S, rs[0]? = some S ∧ S.Covers (C.bound (xs.map (absArg T st))).index ∧ S.Mem t :=
  scope_check_connection hT (OccurrenceAccepted.of_body hacc (reachAt_occurrences hreach)) ⟨_, hreach⟩ hrhs hrule hw

/-- `scope_local_connection` の系。 -/
theorem scope_local_connection_at {ok : ConName} {pattern : String → Option Range} {T : ScopeTable Refinement.Val}
    {L : Limits} {key : Key} {scope : Interval.BindingScope} {body : Block}
    (hT : TableSound (models ok pattern) T) (hacc : ScopeAccept.acceptBody ok T L key scope body = .ok ())
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    {env env' : Locals}
    (hreach : ReachAtBlock T key env body k env' (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    {i : Nat}
    (hxs : contractOrder positions (lowerArgs (argsKey k (.primName b ts es (fixedRanges rs))) args) = some [.loc i])
    {rule : ScopeRule Refinement.Val} (hrule : T.ruleAt k = some rule) (hidx : ∀ a, rule.index [a] = [argIndex a])
    {v : Refinement.Val} (found : env'[i]? = some (some v)) :
    ∃ st S, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧ rs[0]? = some S ∧
      S.Covers (st.requiredIndex i) ∧ (st.requiredIndex i = .top → S = .top) ∧
      (st.requiredIndex i ≠ .top → ∃ t, v.target? = some t ∧ (st.requiredIndex i).Mem t ∧ S.Mem t) :=
  scope_local_connection hT (OccurrenceAccepted.of_body hacc (reachAt_occurrences hreach)) ⟨_, hreach⟩ hxs
    hrule hidx found

/-- 受理したプログラムの定義の本体での `scope_check_connection` の系。型が保持する範囲を選ぶ規則が選ばなかった
出現に適用する。 -/
theorem accepted_check_connection {A : CheckAccept.AcceptInput} {q : Check.Input} {p : Program}
    {pattern : String → Option Range} (hn : CheckAccept.NamesComplete q p)
    (hp : CheckAccept.acceptProgram A q p = .ok ()) {n : FunName} {d : Def} (hd : p.defs n = some d)
    (hT : TableSound (models A.ok pattern) (CheckAccept.tableFor A (CheckAccept.bodyKey n) d.body))
    {k : Key} {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {labels positions} {args : Exprs}
    {env env' : Locals}
    (hreach : ReachAtBlock (CheckAccept.tableFor A (CheckAccept.bodyKey n) d.body) (CheckAccept.bodyKey n) env d.body
      k env' (.call (.primName b ts es (fixedRanges rs)) labels positions args))
    (hsel : (OpenScopeAccept.selections A.openRules d.coreParams (CheckAccept.bodyKey n) d.body).lookup k = none)
    {v : Refinement.Val}
    (hrhs : RhsEval (CheckAccept.tableFor A (CheckAccept.bodyKey n) d.body) k env'
      (.call (.primName b ts es (fixedRanges rs)) labels positions args) (some v))
    {C : CheckSpec} {run : List Range → List Refinement.Val → Option Refinement.Val}
    (hrule : (CheckAccept.tableFor A (CheckAccept.bodyKey n) d.body).ruleAt k = some (checkRule C run))
    {w : Refinement.Val} (hw : okPayload A.ok v = some w) :
    ∃ t, w.target? = some t ∧ t.kind = C.kind ∧ ∃ S, rs[0]? = some S ∧ S.Mem t := by
  obtain ⟨-, -, -, -, -, -, t, ht, hk, -, S, hS, -, hSm⟩ :=
    scope_check_connection hT
      (OccurrenceAccepted.of_def (CheckAccept.acceptProgram_sound hn hp) hd (reachAt_occurrences hreach) hsel)
      ⟨_, hreach⟩ hrhs hrule hw
  exact ⟨t, ht, hk, S, hS, hSm⟩

end
end Benitoite.Release.Refinement.Surface.ScopeSound
