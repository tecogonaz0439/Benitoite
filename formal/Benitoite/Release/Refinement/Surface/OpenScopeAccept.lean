import Benitoite.Release.Refinement.Surface.ScopeAccept
import Benitoite.Release.Refinement.Surface.OpenBody
import Benitoite.Release.Refinement.Surface.CheckFormationBase
import Benitoite.Release.Refinement.Surface.PredicateCalls

/-! # 開いた範囲契約の受理

型で保持する範囲を転送する規則は、範囲を具体化する前に引数の型から選ぶ。
閉じた局所の由来を読む規則と区別し、同じ範囲変数の被覆を全ての具体化について確認する。
-/
namespace Benitoite.Release.Refinement.Surface.OpenScopeAccept
open Scope.Domain ScopeState ScopeLower ScopeAccept

/-- 一つの対象引数の型が保持する範囲を読む標準の規則。範囲の選択は構成子から定まり、外から関数や健全性の仮定を受け取らない。 -/
inductive Rule where
  | pathWiden | requestWiden | pathValue | requestValue | readText | readBytes | send
  | writeText | appendText | writeBytes | appendBytes
  deriving DecidableEq

def Rule.name : Rule → String
  | .pathWiden => "Scope.widenPathIn"
  | .requestWiden => "Http.widenRequestIn"
  | .pathValue => "Scope.pathInValue"
  | .requestValue => "Http.requestInValue"
  | .readText => "File.readTextIn"
  | .readBytes => "File.readBytesIn"
  | .send => "Http.sendIn"
  | .writeText => "File.writeTextIn"
  | .appendText => "File.appendTextIn"
  | .writeBytes => "File.writeBytesIn"
  | .appendBytes => "File.appendBytesIn"

def Rule.kind : Rule → Kind
  | .pathWiden | .pathValue | .readText | .readBytes
  | .writeText | .appendText | .writeBytes | .appendBytes => .path
  | .requestWiden | .requestValue | .send => .endpoint

def Rule.typeName : Rule → String
  | .pathWiden | .pathValue | .readText | .readBytes
  | .writeText | .appendText | .writeBytes | .appendBytes => "Scope.PathIn"
  | .requestWiden | .requestValue | .send => "Http.RequestIn"

/-- 外側の篩を除いて、指定した対象型が保持する範囲を読む。 -/
def sourceRange (rule : Rule) : Ty → Option RangeIx
  | .refined a _ => sourceRange rule a
  | .opaque name ix => if name = rule.typeName then some ix else none
  | .scoped name k ix => if name = rule.typeName ∧ k = rule.kind then some ix else none
  | _ => none

/-- 一回の規則の選択。必須の位置は0であり、明示拡大の行き先がある場合は型付けの許容が検査する。 -/
structure Selection where
  source : RangeIx
  contracts : List RangeIx
  deriving DecidableEq

/-- 範囲を持つ引数は宣言順の位置0にある。書き込みの内容は別の引数であり、範囲の選択に使わない。 -/
def Rule.arity : Rule → Nat
  | .writeText | .appendText | .writeBytes | .appendBytes => 2
  | _ => 1

/-- 書いた順と契約位置を対応させ、位置0が元のパラメータ参照である直接呼出しを選ぶ。 -/
def selectExpr (rules : List Rule) (locals : List (Option Ty)) : Expr → Option Selection
  | .call (.primName b [] [] ix) labels positions args => do
    let rule ← rules.find? (fun rule => decide (rule.name = b))
    if positions.Perm (List.range rule.arity) ∧ args.length = rule.arity ∧ labels.length = rule.arity then do
      let target ← (positions.zip (PredicateCalls.expressions args)).lookup 0
      let .local i := PredicateCalls.stripParens target | none
      let a ← (locals[i]?).join
      let source ← sourceRange rule a
      return ⟨source, ix⟩
    else none
  | _ => none

/-- 直接の末尾呼出しの選択。局所の注釈を由来として信用せず、関数パラメータの型だけを読む。 -/
def select (rules : List Rule) (params : List Ty) : Block → Option Selection
  | .last e => selectExpr rules (params.reverse.map some) e
  | _ => none

/- 文列の各出現で見える元のパラメータの型。新しい束縛の位置は未知として加える。
ブロック式を辿るが、分岐・ラムダ・一般の引数式の内側では型を推測しない。 -/
mutual
  def contextsExpr (locals : List (Option Ty)) (e : Expr) : List (List (Option Ty)) :=
    locals :: (match e with
      | .block body => contextsBlock locals body
      | .paren e => contextsExpr locals e
      | _ => List.replicate ((Identity.surfacePreorder e).length - 1) [])
  def contextsBlock (locals : List (Option Ty)) : Block → List (List (Option Ty))
    | .empty => []
    | .builderBind _ rest => contextsBlock (none :: locals) rest
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => contextsExpr locals e
    | .bind _ _ e rest => contextsExpr locals e ++ contextsBlock (none :: locals) rest
    | .discard e rest | .seq e rest => contextsExpr locals e ++ contextsBlock locals rest
    | .bindPat _ pattern _ e rest => contextsExpr locals e ++
        contextsBlock (List.replicate pattern.binders none ++ locals) rest
end

private theorem surfacePreorder_length_pos (e : Expr) :
    0 < (Identity.surfacePreorder e).length := by
  rw [Identity.surfacePreorder.eq_def]
  exact Nat.zero_lt_succ _

mutual
  private theorem contextsExpr_length (locals : List (Option Ty)) (e : Expr) :
      (contextsExpr locals e).length = (Identity.surfacePreorder e).length := by
    have positive := surfacePreorder_length_pos e
    cases e <;> simp only [contextsExpr, List.length_cons, List.length_replicate]
    all_goals first
      | exact congrArg (· + 1) (contextsBlock_length _ _)
      | exact congrArg (· + 1) (contextsExpr_length _ _)
      | omega

  /-- 文脈の列は、元の先行順の出現列と同じ長さを持つ。 -/
  theorem contextsBlock_length (locals : List (Option Ty)) (body : Block) :
      (contextsBlock locals body).length = (Identity.preorderBlock body).length := by
    cases body <;> simp only [contextsBlock, Identity.preorderBlock, List.length_append,
      contextsExpr_length, contextsBlock_length, List.length_nil]
end

/-- 文脈との zip は、元の出現を一つも切り捨てない。 -/
theorem occurrences_zip_contexts_length (params : List Ty)
    (key : Benitoite.Scope.Inference.Key) (body : Block) :
    ((occurrences key body).zip (contextsBlock (params.reverse.map some) body)).length =
      (occurrences key body).length := by
  simp only [List.length_zip, contextsBlock_length, occurrences, List.length_map,
    List.length_zipIdx, Nat.min_self]

/-- 元の先行順の全出現と同じ番号で、パラメータから選べる範囲だけを記録する。 -/
def selections (rules : List Rule) (params : List Ty) (key : Benitoite.Scope.Inference.Key)
    (body : Block) : List (Benitoite.Scope.Inference.Key × Selection) :=
  ((occurrences key body).zip (contextsBlock (params.reverse.map some) body)).filterMap fun pair =>
    (selectExpr rules pair.2 pair.1.2).map (fun s => (pair.1.1, s))

/-- 具体化後の閉じた範囲。範囲変数をTopへ置き換えない。 -/
def close (rs : List RangeExpr) : RangeIx → Option RangeExpr
  | .fixed r => some r
  | .rvar i => rs[i]?

private theorem close_some {ks : List Kind} {rs : List RangeExpr} {ix : RangeIx}
    (hw : ix.WF ks.length) (hr : RangesFit rs ks) : ∃ r, close rs ix = some r := by
  cases ix with
  | fixed r => exact ⟨r, rfl⟩
  | rvar i =>
    have hi : i < rs.length := hr.1 ▸ hw
    exact ⟨rs[i], by simp [close, hi]⟩

/-- 同一の記号、Top、固定範囲間の被覆だけを確認する。異なる範囲変数間を推測しない。 -/
def covers (outer inner : RangeIx) : Bool :=
  if outer = inner then true
  else match outer, inner with
    | .fixed r, .fixed s => decide (r.Covers s)
    | .fixed .top, _ => true
    | _, _ => false

private theorem covers_sound {outer inner : RangeIx} (h : covers outer inner = true)
    {rs : List RangeExpr} {r : RangeExpr} (hi : close rs inner = some r) :
    ∃ s, close rs outer = some s ∧ s.Covers r := by
  unfold covers at h
  split at h
  · next he => subst outer; exact ⟨r, hi, .refl _⟩
  · cases outer with
    | rvar i => cases inner <;> cases h
    | fixed s =>
      cases inner with
      | fixed t =>
        cases hi
        exact ⟨s, rfl, of_decide_eq_true h⟩
      | rvar i =>
        cases s with
        | absolute s =>
          cases s with
          | top => exact ⟨.top, rfl, RangeExpr.top_covers r⟩
          | _ => cases h
        | based _ _ | secrets => cases h

/-- 選んだ位置に契約があり、範囲変数が宣言の内側にあり、記号的な被覆が成り立つことを確認する。 -/
def acceptSelection (ks : List Kind) (s : Selection) : Except CoverFailure Unit :=
  if s.source.WF ks.length then
    match s.contracts with
    | [] => .error .notCovered
    | contract :: _ => if covers contract s.source then .ok ()
      else .error (match contract, s.source with
        | .fixed _, .fixed _ => .notCovered
        | _, _ => .unknownSource)
  else .error .unknownSource

/-- 成功した記号的な選択は、全ての適格な具体化で、選んだ位置の契約と被覆を持つ。 -/
theorem acceptSelection_sound {ks : List Kind} {s : Selection}
    (h : acceptSelection ks s = .ok ()) (rs : List RangeExpr) (hr : RangesFit rs ks) :
    ∃ contract source target, s.contracts[0]? = some contract ∧ close rs s.source = some source ∧
      close rs contract = some target ∧ target.Covers source := by
  unfold acceptSelection at h
  split at h
  · next hw =>
    obtain ⟨source, hs⟩ := close_some hw hr
    cases hcs : s.contracts with
    | nil => simp only [hcs] at h; cases h
    | cons contract rest =>
      simp only [hcs] at h
      split at h
      · next hc =>
        obtain ⟨target, ht, hcover⟩ := covers_sound hc hs
        exact ⟨contract, source, target, by simp, hs, ht, hcover⟩
      · cases h
  · cases h

/-- 直接の末尾呼出しは、固定範囲と範囲変数を同じ規則で選ぶ。 -/
def chosen (rules : List Rule) (params : List Ty) (body : Block) : Option Selection :=
  select rules params body

/-- 空の範囲文脈で閉じた由来の判定が成功した本体を受理する。
それ以外は、各出現の記号側の全具体化の被覆、又は局所の由来を検査する。 -/
def acceptBody (rules : List Rule) (ks : List Kind) (params : List Ty)
    (ok : ConName) (T : Benitoite.Scope.Inference.ScopeTable Refinement.Val) (L : Limits)
    (key : Benitoite.Scope.Inference.Key) (scope : Interval.BindingScope) (body : Block) :
    Except (Benitoite.Scope.Inference.Key × CoverFailure) Unit :=
  if ks.isEmpty && (ScopeAccept.acceptBody ok T L key scope body).toBool then .ok () else
  let result := analyzeBody ok T L key scope body
  allOk (occurrences key body) fun pair =>
    let selected := if (T.ruleAt pair.1).isSome then
      (selections rules params key body).lookup pair.1 else none
    let checked := match selected with
      | some s => acceptSelection ks s
      | none => acceptOccurrence T result.2 result.1.exceeded.isSome pair.1 pair.2
    match checked with
    | .ok () => .ok ()
    | .error f => .error (pair.1, f)

/-- 空の範囲文脈での閉じた由来の全出現の被覆、又は選択に応じた全適格具体化の被覆を保持する。
閉じた由来の判定の成功は、任意の規則表について記号側の選択の被覆を含むとは限らないため、二つの結論を区別する。 -/
def BodyRanges (rules : List Rule) (ks : List Kind) (params : List Ty)
    (ok : ConName) (T : Benitoite.Scope.Inference.ScopeTable Refinement.Val) (L : Limits)
    (key : Benitoite.Scope.Inference.Key) (scope : Interval.BindingScope) (body : Block) : Prop :=
  (ks = [] ∧ ScopeAccept.BodyRanges ok T L key scope body) ∨
  let result := analyzeBody ok T L key scope body
  ∀ pair ∈ occurrences key body, (T.ruleAt pair.1).isSome = true →
    match (selections rules params key body).lookup pair.1 with
    | none => acceptOccurrence T result.2 result.1.exceeded.isSome pair.1 pair.2 = .ok ()
    | some s => ∀ rs, RangesFit rs ks →
      ∃ contract source target, s.contracts[0]? = some contract ∧ close rs s.source = some source ∧
        close rs contract = some target ∧ target.Covers source

theorem acceptBody_sound {rules ks params ok T L key scope body}
    (h : acceptBody rules ks params ok T L key scope body = .ok ()) :
    BodyRanges rules ks params ok T L key scope body := by
  unfold acceptBody at h
  split at h
  · next closed =>
    obtain ⟨empty, accepted⟩ := Bool.and_eq_true_iff.mp closed
    have old : ScopeAccept.acceptBody ok T L key scope body = .ok () := by
      cases result : ScopeAccept.acceptBody ok T L key scope body with
      | error failure => simp only [result, Except.toBool, Bool.false_eq_true] at accepted
      | ok value => cases value; rfl
    exact Or.inl ⟨List.nil_of_isEmpty empty, ScopeAccept.acceptBody_ranges_all old⟩
  · apply Or.inr
    dsimp only
    intro pair member present
    have hp := allOk_ok h pair member
    dsimp only at hp
    simp only [present, ite_true] at hp
    cases hs : (selections rules params key body).lookup pair.1 with
    | none =>
      simp only [hs] at hp ⊢
      split at hp
      · assumption
      · cases hp
    | some s =>
      simp only [hs] at hp ⊢
      cases ha : acceptSelection ks s with
      | error e => simp only [ha] at hp; cases hp
      | ok u => cases u; exact fun rs hr => acceptSelection_sound ha rs hr

/-- 範囲パラメータのない閉じた由来の判定が成功すれば、選択の有無によらず記号側を含む受理も成功する。 -/
theorem acceptBody_no_ranges_of_closed {rules params ok T L key scope body}
    (h : ScopeAccept.acceptBody ok T L key scope body = .ok ()) :
    acceptBody rules [] params ok T L key scope body = .ok () := by
  unfold acceptBody
  simp only [List.isEmpty_nil, h, Except.toBool, Bool.and_self, ↓reduceIte]

/-- 記号側が選ぶ出現のない閉じた本体は、閉じた由来の判定と同じ結果となる。 -/
@[simp] theorem acceptBody_no_ranges (rules : List Rule) (params : List Ty)
    (ok : ConName) (T : Benitoite.Scope.Inference.ScopeTable Refinement.Val) (L : Limits)
    (key : Benitoite.Scope.Inference.Key) (scope : Interval.BindingScope) (body : Block)
    (noneSelected : selections rules params key body = []) :
    acceptBody rules [] params ok T L key scope body = ScopeAccept.acceptBody ok T L key scope body := by
  by_cases accepted : ScopeAccept.acceptBody ok T L key scope body = .ok ()
  · rw [acceptBody_no_ranges_of_closed accepted, accepted]
  · have rejected : (ScopeAccept.acceptBody ok T L key scope body).toBool = false := by
      cases result : ScopeAccept.acceptBody ok T L key scope body with
      | error failure => rfl
      | ok value => cases value; exact False.elim (accepted result)
    unfold acceptBody
    simp only [List.isEmpty_nil, rejected, Bool.and_false]
    simp only [ScopeAccept.acceptBody, noneSelected, List.lookup_nil, ite_self]
    rfl

end Benitoite.Release.Refinement.Surface.OpenScopeAccept
