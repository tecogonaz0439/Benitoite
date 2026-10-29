import Benitoite.Surface.CheckProgramSound
import Benitoite.Surface.ScopeSound

/-!
# 型検査器の入口への必須の判定の受理の組み込み（L50.2）

型検査器の入口 `CheckTables.checkProgram`（表層の型付けの検査）に、必須の判定の受理 `ScopeAccept.acceptBody`
（L40.4）を組み込んだ入口 `checkProgramAccepted` と、プログラム全体の受理の述語 `Accepted`（全ての定義と実装の
メソッドの本体の受理）を置く。入口が成功すれば、表層の型付けの結論（`CheckedUnder`）と `Accepted` の両方が成り
立つ（`checkProgramAccepted_sound`・`checkProgramAccepted_empty`）。設計書 07-04「証明する性質」の「必須の判定の
受理の組み込み」に従う。

- 出現の解決 `primResolve`: 本体の出現のうち、組み込みの名前（`primName`）を頭に持つ直接の呼び出しを、標準の
  所有元のその名前へ解決する。型の情報を付けた表層の構文では、組み込みの名前は名前の解決を終えた標準の宣言で
  あり、同じ綴りの利用者の関数は `funName` で現れる（`standardTable` の `apiAt` に入らない）。
- 本体の入口: 定義の名前と番号 0 の鍵（区間解析と同じ）と、引数（辞書の引数を含む）の位置に番号 `0..n-1` を
  割り当てた束縛番号の土台 `entryScope n`。
- 受理は精度の説明であり、主定理の前提にしない。対象健全性は型付けから別に示している（設計書 07-04）。コアの
  実行と表層の評価（`ScopeLower.ReachBlock`）の対応の補題は置かない（設計者の決定、RV-L40 中3）。
-/

namespace Benitoite.Surface.CheckAccept

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept
open Benitoite.Surface.CheckTables

/-- 受理の入力。Result の Ok の構成子の名前、Scope の規則の表（宣言の名前から規則）、必須の判定の上限、実装の
メソッドの本体の鍵の定義の名前。 -/
structure AcceptInput where
  ok : Release.ConName
  rules : String → Option (ScopeRule Release.Val)
  limits : Limits
  methodKey : String → String → String

/-- 規則を持たない受理の入力（旧の像。Scope の規則の項目がない表）。どの本体も受理する（`acceptProgram_noRules`）。 -/
def AcceptInput.noRules : AcceptInput := ⟨"Ok", fun _ => none, ⟨⟨0, 0⟩, ⟨0, 0⟩⟩, fun i m => i ++ "." ++ m⟩

/-- 本体の始まりの鍵（区間解析と同じく番号 0 から数える）。 -/
def bodyKey (name : String) : Key := ⟨name, 0⟩

/-- 引数の位置に番号 `0..n-1` を割り当てた束縛番号の土台。次の番号は n である。 -/
def entryScope (n : Nat) : Interval.BindingScope := ⟨List.range n, n⟩

theorem entryScope_valid (n : Nat) : ∀ id ∈ (entryScope n).positions, id < (entryScope n).nextId := by
  intro id h
  simpa [entryScope] using h

/-- 本体の出現の解決。組み込みの名前を頭に持つ直接の呼び出しを、標準の所有元のその名前へ解決する。 -/
def primResolve (key : Key) (body : Block) : Key → Option Resolved := fun k =>
  match (occurrences key body).find? (fun p => decide (p.1 = k)) with
  | some (_, .call (.primName b _ _ _) _ _ _) => some ⟨.standard, b⟩
  | _ => none

/-- 本体の Scope の表。 -/
def tableFor (A : AcceptInput) (key : Key) (body : Block) : ScopeTable Release.Val :=
  standardTable (primResolve key body) A.rules

/-- 一つの本体の受理。 -/
def acceptFn (A : AcceptInput) (name : String) (nlocals : Nat) (body : Block) : Except (Key × CoverFailure) Unit :=
  acceptBody A.ok (tableFor A (bodyKey name) body) A.limits (bodyKey name) (entryScope nlocals) body

/-- 定義の本体の受理。局所の位置は辞書の引数と値の引数である（`checkDef` の環境と同じ）。 -/
def acceptDef (A : AcceptInput) (name : String) (d : Def) : Except (Key × CoverFailure) Unit :=
  acceptFn A name (d.dictTys ++ d.params).length d.body

/-- 実装のメソッドの本体の受理。局所の位置は辞書の引数を含む内部の名前の列である。 -/
def acceptMethod (A : AcceptInput) (impl meth : String) (mi : Check.MethodInput) : Except (Key × CoverFailure) Unit :=
  acceptFn A (A.methodKey impl meth) mi.names.length mi.body

/-- プログラム全体の受理。名前の一覧の順に全ての定義と、全ての実装の全てのメソッドの本体を受理し、最初に拒否した
出現の鍵と理由を返す。 -/
def acceptProgram (A : AcceptInput) (m : Materials) (names : Names) : Except (Key × CoverFailure) Unit := do
  allOk names.defs fun n =>
    match m.program.defs n with
    | some d => acceptDef A n d
    | none => .ok ()
  allOk names.impls fun i =>
    match lookup m.impls i with
    | some im => allOk im.methods fun (mn, mi) => acceptMethod A i mn mi
    | none => .ok ()

/-- プログラム全体の受理の述語（RV-L40 中3）。全ての定義の本体と、全ての実装の全てのメソッドの本体を受理する。 -/
def Accepted (A : AcceptInput) (m : Materials) : Prop :=
  (∀ n d, m.program.defs n = some d → acceptDef A n d = .ok ()) ∧
    ∀ i im, lookup m.impls i = some im → ∀ mn mi, (mn, mi) ∈ im.methods → acceptMethod A i mn mi = .ok ()

theorem allOk_of_forall {α ε : Type} {xs : List α} {f : α → Except ε Unit} (h : ∀ x ∈ xs, f x = .ok ()) :
    allOk xs f = .ok () := by
  induction xs with
  | nil => rfl
  | cons y ys ih =>
    simp only [allOk, h y (List.mem_cons_self ..)]
    exact ih fun x hx => h x (List.mem_cons_of_mem _ hx)

private theorem bind_unit_ok {ε : Type} {r s : Except ε Unit} (h : (r >>= fun _ => s) = .ok ()) :
    r = .ok () ∧ s = .ok () := by
  cases r with
  | error e => cases h
  | ok u => cases u; exact ⟨rfl, h⟩

/-- 全体の受理の健全性。名前の一覧が全ての定義と実装を含めば、受理したプログラムは `Accepted` を満たす。 -/
theorem acceptProgram_sound {A : AcceptInput} {m : Materials} {names : Names}
    (hdefs : ∀ n d, m.program.defs n = some d → n ∈ names.defs)
    (himpls : ∀ i im, lookup m.impls i = some im → i ∈ names.impls)
    (h : acceptProgram A m names = .ok ()) : Accepted A m := by
  obtain ⟨h1, h2⟩ := bind_unit_ok h
  refine ⟨fun n d hd => ?_, fun i im hi mn mi hmi => ?_⟩
  · have := allOk_ok h1 n (hdefs n d hd)
    simpa only [hd] using this
  · have := allOk_ok h2 i (himpls i im hi)
    simp only [hi] at this
    exact allOk_ok this (mn, mi) hmi

theorem impls_complete (m : Materials) : ∀ i im, lookup m.impls i = some im → i ∈ m.names.impls := by
  intro i im h
  exact List.mem_map.mpr ⟨(i, im), lookup_mem h, rfl⟩

/-- `m.names` を使う全体の受理の健全性。 -/
theorem acceptProgram_sound_names {A : AcceptInput} {m : Materials} (h : acceptProgram A m m.names = .ok ()) :
    Accepted A m :=
  acceptProgram_sound (names_complete m).1 (impls_complete m) h

/-- 規則のない表では、一つの本体の受理は常に成功する。 -/
theorem acceptFn_noRules {A : AcceptInput} (hA : ∀ d, A.rules d = none) (name : String) (n : Nat) (body : Block) :
    acceptFn A name n body = .ok () := by
  unfold acceptFn acceptBody
  apply allOk_of_forall
  intro p _
  have hocc : acceptOccurrence (tableFor A (bodyKey name) body)
      (analyzeBody A.ok (tableFor A (bodyKey name) body) A.limits (bodyKey name) (entryScope n) body).2
      (analyzeBody A.ok (tableFor A (bodyKey name) body) A.limits (bodyKey name) (entryScope n) body).1.exceeded.isSome
      p.1 p.2 = .ok () := by
    have hrule : ∀ k, (tableFor A (bodyKey name) body).ruleAt k = none := by
      intro k
      simp only [ScopeTable.ruleAt, tableFor, standardTable]
      cases (primResolve (bodyKey name) body k) with
      | none => rfl
      | some r =>
        rcases r with ⟨o, d⟩
        cases o <;> simp [hA]
    unfold acceptOccurrence
    split
    · split <;> simp [acceptCall, hrule]
    · rfl
  simp only [hocc]

/-- 規則のない受理の入力（旧の像）では、全体の受理は常に成功する。 -/
theorem acceptProgram_noRules {A : AcceptInput} (hA : ∀ d, A.rules d = none) (m : Materials) (names : Names) :
    acceptProgram A m names = .ok () := by
  unfold acceptProgram
  rw [allOk_of_forall (fun n _ => by
    cases m.program.defs n with
    | none => rfl
    | some d => exact acceptFn_noRules hA _ _ _)]
  exact allOk_of_forall fun i _ => by
    cases lookup m.impls i with
    | none => rfl
    | some im => exact allOk_of_forall fun _ _ => acceptFn_noRules hA _ _ _

/-! ## 入口 -/

/-- 入口の失敗。表層の型付けの検査の誤りか、必須の判定の拒否（出現の鍵と DET-05 の理由）。 -/
inductive EntryError where
  | typing (e : Check.Error)
  | cover (key : Key) (reason : CoverFailure)
  deriving Repr

/-- 型検査器の入口。表層の型付けを検査し、成功したら全ての本体の必須の判定を受理する。 -/
def checkProgramAccepted (q : Check.Input) (A : AcceptInput) (m : Materials) (names : Names) :
    Except EntryError Unit :=
  match checkProgram q m names with
  | .error e => .error (.typing e)
  | .ok () =>
    match acceptProgram A m names with
    | .error (k, f) => .error (.cover k f)
    | .ok () => .ok ()

theorem checkProgramAccepted_ok {q : Check.Input} {A : AcceptInput} {m : Materials} {names : Names}
    (h : checkProgramAccepted q A m names = .ok ()) :
    checkProgram q m names = .ok () ∧ acceptProgram A m names = .ok () := by
  unfold checkProgramAccepted at h
  split at h
  · cases h
  · next hc =>
    split at h
    · cases h
    · next ha => exact ⟨hc, ha⟩

/-- 規則のない受理の入力では、入口は型付けの検査と同じ結果を返す（旧の像）。 -/
theorem checkProgramAccepted_noRules {q : Check.Input} {A : AcceptInput} (hA : ∀ d, A.rules d = none)
    {m : Materials} {names : Names} :
    checkProgramAccepted q A m names = .ok () ↔ checkProgram q m names = .ok () := by
  refine ⟨fun h => (checkProgramAccepted_ok h).1, fun h => ?_⟩
  unfold checkProgramAccepted
  rw [h, acceptProgram_noRules hA m names]

/-- 入口の健全性。`checkProgram_under` と同じ前提で、表層の型付けの結論と全体の受理の述語の両方を得る。 -/
theorem checkProgramAccepted_sound {q : Check.Input} {A : AcceptInput} {m : Materials}
    (hq : q.Sound) (hd : ∀ n d, m.program.defs n = some d → d.AtomsIn q.atoms)
    (hi : ∀ n id, m.program.impls n = some id → id.AtomsIn q.atoms)
    (him : ∀ n id, lookup (m.impls.map fun (n,i) => (n,i.input)) n = some id →
      Check.ImplNamesComplete q id m.names.methods m.names.supers)
    (hext : Extends q.D m.program.declarations)
    (h : checkProgramAccepted q A m m.names = .ok ()) : CheckedUnder m.program q ∧ Accepted A m := by
  obtain ⟨hc, ha⟩ := checkProgramAccepted_ok h
  exact ⟨checkProgram_under hq (names_complete m) hd hi him hext hc, acceptProgram_sound_names ha⟩

/-- 信頼する宣言が空の場合の入口の健全性。プログラムは表層の型付け `p.WellTyped` を満たし、全体の受理の述語を
満たす（`checkProgram_empty` の入口版）。 -/
theorem checkProgramAccepted_empty {m : Materials} {S raw b select atoms} {A : AcceptInput}
    (hf : m.trustedFuns = []) (hi : m.trustedImpls = [])
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgramAccepted
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) A m m.names = .ok ()) :
    m.program.WellTyped (builtins S (primEntries S raw) b) (makeOpPrim select) ∧ Accepted A m := by
  obtain ⟨hc', ha⟩ := checkProgramAccepted_ok h
  exact ⟨checkProgram_empty hf hi hd hb hdefs himpls hc hn hc', acceptProgram_sound_names ha⟩

/-! ## 接続定理への適用 -/

/-- 健全な規則の項目から作った本体の表は健全である。 -/
theorem tableFor_sound {M : FactModels Release.Val} {R : Rules} (hR : R.Sound M) (A : AcceptInput)
    (hA : A.rules = R.lookup) (key : Key) (body : Block) : TableSound M (tableFor A key body) := by
  unfold tableFor
  rw [hA]
  exact Rules.lookup_sound hR _

/-- 受理したプログラムの定義の本体は、接続定理（`ScopeSound.scope_check_connection`）の前提 `hacc` を満たす。 -/
theorem Accepted.def_body {A : AcceptInput} {m : Materials} (h : Accepted A m) {n : String} {d : Def}
    (hd : m.program.defs n = some d) :
    acceptBody A.ok (tableFor A (bodyKey n) d.body) A.limits (bodyKey n) (entryScope (d.dictTys ++ d.params).length)
      d.body = .ok () :=
  h.1 n d hd

/-- 全体の受理から一つの定義の接続定理を得る。健全な規則の項目（例えば本番の実例の表の δ による `productionRules`）
で受理したプログラムの定義の本体の、Scope の検査の呼び出しが `Ok(w)` を返すなら、成功値の対象は推論した範囲に
属し、型検査器が受理した範囲 S はそれを覆い、対象は S に属する。 -/
theorem accepted_check_connection {P : Parsers} {R : Rules} {A : AcceptInput} {m : Materials}
    (hR : R.Sound (models A.ok P)) (hA : A.rules = R.lookup) (h : Accepted A m) {n : String} {d : Def}
    (hd : m.program.defs n = some d) {env env' : Locals} {k : Key}
    (hreach : ReachBlock (tableFor A (bodyKey n) d.body) (bodyKey n) env d.body k env')
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Scope.Domain.Range} {labels positions} {args : Exprs}
    (hocc : (k, .call (.primName b ts es rs) labels positions args) ∈ occurrences (bodyKey n) d.body) {v : Val}
    (hrhs : RhsEval (tableFor A (bodyKey n) d.body) k env' (.call (.primName b ts es rs) labels positions args)
      (some v)) {C : CheckSpec} {run : List Scope.Domain.Range → List Val → Option Val}
    (hrule : (tableFor A (bodyKey n) d.body).ruleAt k = some (checkRule C run)) {w : Val}
    (hw : okPayload A.ok v = some w) :
    ∃ st xs vs, (k, st) ∈ (analyzeBody A.ok (tableFor A (bodyKey n) d.body) A.limits (bodyKey n)
        (entryScope (d.dictTys ++ d.params).length) d.body).2 ∧
      contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs ∧
      (∃ rs', run rs' vs = some v) ∧
      ∃ t, w.target? = some t ∧ t.kind = C.kind ∧
        (C.bound (xs.map (absArg (tableFor A (bodyKey n) d.body) st))).index.Mem t ∧
        ∀ S, rs[0]? = some S → S.Covers (C.bound (xs.map (absArg (tableFor A (bodyKey n) d.body) st))).index ∧
          S.Mem t :=
  ScopeSound.scope_check_connection (tableFor_sound hR A hA _ _) (h.def_body hd) hreach hocc hrhs hrule hw

open ScopeOccurrence in
/-- `accepted_check_connection` の系（L50.4、RV-L50 中4）。到達した文の右辺を添字に持つ到達から、出現の番号の一致を
得る。 -/
theorem accepted_check_connection_at {P : Parsers} {R : Rules} {A : AcceptInput} {m : Materials}
    (hR : R.Sound (models A.ok P)) (hA : A.rules = R.lookup) (h : Accepted A m) {n : String} {d : Def}
    (hd : m.program.defs n = some d) {env env' : Locals} {k : Key}
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Scope.Domain.Range} {labels positions} {args : Exprs}
    (hreach : ReachAtBlock (tableFor A (bodyKey n) d.body) (bodyKey n) env d.body k env'
      (.call (.primName b ts es rs) labels positions args)) {v : Val}
    (hrhs : RhsEval (tableFor A (bodyKey n) d.body) k env' (.call (.primName b ts es rs) labels positions args)
      (some v)) {C : CheckSpec} {run : List Scope.Domain.Range → List Val → Option Val}
    (hrule : (tableFor A (bodyKey n) d.body).ruleAt k = some (checkRule C run)) {w : Val}
    (hw : okPayload A.ok v = some w) :
    ∃ st xs vs, (k, st) ∈ (analyzeBody A.ok (tableFor A (bodyKey n) d.body) A.limits (bodyKey n)
        (entryScope (d.dictTys ++ d.params).length) d.body).2 ∧
      contractOrder positions (lowerArgs (argsKey k (.primName b ts es rs)) args) = some xs ∧
      (∃ rs', run rs' vs = some v) ∧
      ∃ t, w.target? = some t ∧ t.kind = C.kind ∧
        (C.bound (xs.map (absArg (tableFor A (bodyKey n) d.body) st))).index.Mem t ∧
        ∀ S, rs[0]? = some S → S.Covers (C.bound (xs.map (absArg (tableFor A (bodyKey n) d.body) st))).index ∧
          S.Mem t :=
  accepted_check_connection hR hA h hd hreach.toReach (reachAt_occurrences hreach) hrhs hrule hw

end Benitoite.Surface.CheckAccept
