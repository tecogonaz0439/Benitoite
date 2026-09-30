import Benitoite.Core.Typing

/-!
# 実行の規則（段階 A）

設計書 01-12「実行の規則」の抽象機械を書き写す。遷移を関係 `Step` で定め、
同じ遷移を計算する関数 `step` も定める（設計書 07-04「道具と置き場所」）。`step` は、
小さなコア計算のプログラムを Lean の中で実行して、書き写しの誤りを証明の前に見つけるために使う。

01-12 との表現の違い:

- 遷移 `S → S'` と `S —ℓ→ S'` を、ラベル `Option Event` を持つ一つの関係で表す。
  `none` が IO を伴わない遷移、`some ℓ` が IO の事象 ℓ を伴う遷移である。
- E-Prim と E-Err は IO を行わない組み込みの関数に、E-IO と E-IOErr は IO を行う組み込みの関数に
  使う。どちらに当たるかは `PrimSig.io` で決める。
-/

namespace Benitoite.Core

/-- IO の事象 `b(W̄) ↦ V` または `b(W̄) ↦ error(r)`。 -/
structure Event where
  prim : PrimName
  args : List Val
  outcome : Outcome

/-- 継続の枠。01-12 の `F ::= let x ⇐ □ in N`。N の中で番号 0 が x を指す。 -/
inductive Frame where
  | letF (n : Comp)

/-- 継続。01-12 の `K ::= [] | F :: K`。 -/
abbrev Cont := List Frame

/-- 状態。01-12 の `S ::= ⟨M, K⟩ | error(r)`。 -/
inductive State where
  | run (m : Comp) (k : Cont)
  | error (r : ErrKind)

/-- 遷移。01-12「実行の規則」の E-Let から E-IOErr まで。構成子の名前は規則の名前に対応させる。 -/
inductive Step (P : Program) (B : Builtins) : State → Option Event → State → Prop
  | E_Let {m n k} :
      Step P B (.run (.letIn m n) k) none (.run m (.letF n :: k))
  | E_Return {v n k} :
      Step P B (.run (.ret v) (.letF n :: k)) none (.run (n.instantiate [v]) k)
  | E_Lam {ps body ws k} :
      ws.length = ps.length →
      Step P B (.run (.app (.lam ps body) ws) k) none (.run (body.instantiate ws) k)
  | E_Fun {f ts es ws k d} :
      P.defs f = some d →
      ws.length = d.params.length → ts.length = d.ntys → es.length = d.neffs →
      Step P B (.run (.app (.fnRef f ts es) ws) k) none
        (.run ((d.body.substTy ts es).instantiate ws) k)
  | E_IfT {m n k} :
      Step P B (.run (.ite (.const (.boolean true)) m n) k) none (.run m k)
  | E_IfF {m n k} :
      Step P B (.run (.ite (.const (.boolean false)) m n) k) none (.run n k)
  | E_Match {v arms k m ws} :
      firstMatch v arms = some (m, ws) →
      Step P B (.run (.match v arms) k) none (.run (m.instantiate ws) k)
  | E_Prim {b ts es ws k s v} :
      B.sig b = some s → s.io = false → B.delta b ts es ws = some (.val v) →
      Step P B (.run (.app (.prim b ts es) ws) k) none (.run (.ret v) k)
  | E_Err {b ts es ws k s r} :
      B.sig b = some s → s.io = false → B.delta b ts es ws = some (.err r) →
      Step P B (.run (.app (.prim b ts es) ws) k) none (.error r)
  | E_IO {b ts es ws k s v} :
      B.sig b = some s → s.io = true → B.ioResponse b ts es ws (.val v) →
      Step P B (.run (.app (.prim b ts es) ws) k) (some ⟨b, ws, .val v⟩) (.run (.ret v) k)
  | E_IOErr {b ts es ws k s r} :
      B.sig b = some s → s.io = true → B.ioResponse b ts es ws (.err r) →
      Step P B (.run (.app (.prim b ts es) ws) k) (some ⟨b, ws, .err r⟩) (.error r)

/-- 遷移を 0 回以上続けたもの。ラベルは問わない。 -/
inductive Steps (P : Program) (B : Builtins) : State → State → Prop
  | refl {s} : Steps P B s s
  | step {s l s' s''} : Step P B s l s' → Steps P B s' s'' → Steps P B s s''

/-- IO の応答を選ぶ関数。IO を行う組み込みの関数 `b[T̄; Ē]` と引数 `W̄` から応答を返す。
同じ入力には常に同じ応答を返すので、同じ呼び出しへの応答が実行の途中で変わる遷移の列は、
`run` では再現できない。`run` は例の実行を調べる道具であり、`step` と `Step` の一致は一歩についてだけ言明する。 -/
abbrev Oracle := PrimName → List Ty → List Eff → List Val → Outcome

/-- 一歩の遷移を計算する関数。IO の応答は `oracle` から得る。遷移できないときは `none` を返す。
`step_sound`・`step_complete`（`Theorems.lean`）で `Step` と一致することを示す。 -/
def step (P : Program) (B : Builtins) (oracle : Oracle) :
    State → Option (Option Event × State)
  | .error _ => none
  | .run (.letIn m n) k => some (none, .run m (.letF n :: k))
  | .run (.ret v) (.letF n :: k) => some (none, .run (n.instantiate [v]) k)
  | .run (.ret _) [] => none
  | .run (.app (.lam ps body) ws) k =>
      if ws.length = ps.length then some (none, .run (body.instantiate ws) k) else none
  | .run (.app (.fnRef f ts es) ws) k =>
      match P.defs f with
      | some d =>
          if ws.length = d.params.length ∧ ts.length = d.ntys ∧ es.length = d.neffs then
            some (none, .run ((d.body.substTy ts es).instantiate ws) k)
          else none
      | none => none
  | .run (.app (.prim b ts es) ws) k =>
      match B.sig b with
      | none => none
      | some s =>
          if s.io then
            match oracle b ts es ws with
            | .val v => some (some ⟨b, ws, .val v⟩, .run (.ret v) k)
            | .err r => some (some ⟨b, ws, .err r⟩, .error r)
          else
            match B.delta b ts es ws with
            | some (.val v) => some (none, .run (.ret v) k)
            | some (.err r) => some (none, .error r)
            | none => none
  | .run (.app _ _) _ => none
  | .run (.ite (.const (.boolean true)) m _) k => some (none, .run m k)
  | .run (.ite (.const (.boolean false)) _ n) k => some (none, .run n k)
  | .run (.ite _ _ _) _ => none
  | .run (.match v arms) k =>
      match firstMatch v arms with
      | some (m, ws) => some (none, .run (m.instantiate ws) k)
      | none => none

/-- `step` を n 回まで続ける。値で終わるか、実行時エラーで止まるか、遷移できなくなるか、
n 回に達したら止める。IO の事象の列も返す。 -/
def run (P : Program) (B : Builtins) (oracle : Oracle) :
    Nat → State → List Event → State × List Event
  | 0, s, evs => (s, evs.reverse)
  | n + 1, s, evs =>
      match step P B oracle s with
      | none => (s, evs.reverse)
      | some (none, s') => run P B oracle n s' evs
      | some (some ev, s') => run P B oracle n s' (ev :: evs)

/-! ## 継続と状態の型付け -/

/-- `⊢k K : A ⇒ B`（01-12「確かめる性質」の K-Empty・K-Let）。 -/
inductive ContTy (P : Program) (B : Builtins) : Cont → Ty → Ty → Prop
  | K_Empty {a} : ContTy P B [] a a
  | K_Let {n k a c b ε} :
      HasTypeC P B [a] n c ε → ContTy P B k c b →
      ContTy P B (.letF n :: k) a b

/-- 状態 `⟨M, K⟩` に型が付く。`· ⊢c M : A ! ε` と `⊢k K : A ⇒ B` が成り立つ A、B、ε がある。 -/
def StateTy (P : Program) (B : Builtins) : State → Prop
  | .run m k => ∃ a b ε, HasTypeC P B [] m a ε ∧ ContTy P B k a b
  | .error _ => False

end Benitoite.Core
