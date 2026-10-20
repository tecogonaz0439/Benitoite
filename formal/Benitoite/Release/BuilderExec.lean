import Benitoite.Release.BuilderContents

/-!
# 専用内容に対する一操作

更新を返す前に長さと Byte の値域を検査する。失敗時には更新後の内容を返さないため、
呼び出し元は元のストアを保持できる。設計書 01-12「構築器の専用セルの内容と上限」に対応する。
-/
namespace Benitoite.Release

/-- R0902 に対応する内部報告。通常のエフェクトや事象ではない。 -/
def rValueTooLarge : ErrKind := "ValueTooLarge"

/-- Nat で抽象化した Byte のうち、実装に存在しない値を拒否する内部報告。 -/
def rBuilderInvalidByte : ErrKind := "BuilderInvalidByte"

/-- 失敗には更新後の内容を含めず、部分更新を表さない。 -/
inductive BuilderReply where
  | value (contents : BuilderContents) (result : Val)
  | error (reason : ErrKind)

/-- 通常値の String の列を、順序を保って連結する。 -/
def builderJoin : List Val → Option String
  | [] => some ""
  | .const (.string s) :: vs => (builderJoin vs).map (s ++ ·)
  | _ => none

/-- 追記の候補の検査。上限超過は R0902、抽象 Byte の範囲外は専用の内部報告にする。 -/
def builderCheckUpdate (c : BuilderContents) : BuilderReply :=
  if c.size ≤ c.kind.limit then
    match c with
    | .bytes bs =>
        if bs.all (· < 256) then .value c (.const .unit) else .error rBuilderInvalidByte
    | _ => .value c (.const .unit)
  else .error rValueTooLarge

/-- 通常引数の形が合わなければ none。型付きの呼び出しでは型の逆転から形を得る。 -/
def builderApply (op : BuilderOp) (c : BuilderContents) (args : List Val) : Option BuilderReply :=
  match op, c, args with
  | .copy, c, [] => some (.value c c.snapshot)
  | .length, c, [] =>
      if h : c.size ≤ c.kind.limit then
        some (.value c (.const (.integer (c.lengthValue h))))
      else none
  | .append, .string s, [.const (.string t)] => some (builderCheckUpdate (.string (s ++ t)))
  | .appendAll, .string s, [.list vs] =>
      (builderJoin vs).map fun t => builderCheckUpdate (.string (s ++ t))
  | .append, .list a vs, [v] => some (builderCheckUpdate (.list a (vs ++ [v])))
  | .appendAll, .list a vs, [.list ws] => some (builderCheckUpdate (.list a (vs ++ ws)))
  | .append, .bytes bs, [.const (.byte b)] => some (builderCheckUpdate (.bytes (bs ++ [b])))
  | .appendAll, .bytes bs, [.bytesV cs] => some (builderCheckUpdate (.bytes (bs ++ cs)))
  | _, _, _ => none

/-- 更新が成功した候補は論理上限に収まる。 -/
theorem builderCheckUpdate_bound {c c' v}
    (h : builderCheckUpdate c = .value c' v) : c' = c ∧ c'.size ≤ c'.kind.limit := by
  unfold builderCheckUpdate at h
  split at h
  · rename_i hb
    cases c with
    | string _ => cases h; exact ⟨rfl, hb⟩
    | list _ _ => cases h; exact ⟨rfl, hb⟩
    | bytes bs =>
        change (if bs.all (· < 256) then _ else _) = _ at h
        split at h <;> cases h
        exact ⟨rfl, hb⟩
  · cases h

/-- 更新の成功は Byte の値域も保つ。 -/
theorem builderCheckUpdate_validBytes {c c' v}
    (h : builderCheckUpdate c = .value c' v) : c'.ValidBytes := by
  unfold builderCheckUpdate at h
  split at h
  · cases c with
    | string _ => cases h; trivial
    | list _ _ => cases h; trivial
    | bytes bs =>
        change (if bs.all (· < 256) then _ else _) = _ at h
        split at h
        · rename_i hb
          cases h
          simpa only [BuilderContents.ValidBytes, List.all_eq_true, decide_eq_true_eq] using hb
        · cases h
  · cases h

/-- 内容が上限を超えると、候補を公開せず R0902 相当の失敗になる。 -/
theorem builderCheckUpdate_overflow {c : BuilderContents} (h : c.kind.limit < c.size) :
    builderCheckUpdate c = .error rValueTooLarge := by
  simp [builderCheckUpdate, Nat.not_le.mpr h]

/-- copy は抽象の不変内容をそのまま返す。 -/
theorem builder_copy_contents (c : BuilderContents) :
    builderApply .copy c [] = some (.value c c.snapshot) := rfl

/-- length の有界整数の根拠はセルの論理上限だけである。 -/
theorem builder_length_contents {P B Ψ k c} (h : BuilderCellOk P B Ψ k c) :
    builderApply .length c [] = some (.value c (.const (.integer (c.lengthValue h.length_bound)))) := by
  simp [builderApply, h.length_bound]

/-- 後のセル内容を引数に取っても、既に取り出した値の構造は変わらない。 -/
theorem snapshot_structure_stable {c old : BuilderContents} {v : Val}
    (h : builderApply .copy c [] = some (.value old v)) (updated : BuilderContents) :
    v = c.snapshot ∧ builderApply .copy updated [] = some (.value updated updated.snapshot) := by
  cases h
  exact ⟨rfl, rfl⟩

end Benitoite.Release
