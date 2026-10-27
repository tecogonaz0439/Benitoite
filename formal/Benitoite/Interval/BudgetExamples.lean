import Benitoite.Interval.Budget

/-!
# 予算の境界と本体をまたぐ状態の独立例

小さい固定上限を使い、拒否された消費、返却後の再確保、保存項目の寿命を確かめる
（設計書 01-12「区間解析の予算の状態と計上」）。
-/
namespace Benitoite.Interval.Budget

-- 0回・0項では最初の追加を拒否する。全体だけ0の場合も別の理由になる。
example :
    let bodyZero : Limits := ⟨⟨0, 0⟩, ⟨10, 10⟩⟩
    let wholeZero : Limits := ⟨⟨10, 10⟩, ⟨0, 0⟩⟩
    charge bodyZero {} .expression = .stopped (.exceeded ⟨.body, .operations⟩) {} ∧
    reserve bodyZero {} .environment .temporary = .stopped (.exceeded ⟨.body, .items⟩) {} ∧
    charge wholeZero {} .classification = .stopped (.exceeded ⟨.whole, .operations⟩) {} ∧
    reserve wholeZero {} .identity .saved = .stopped (.exceeded ⟨.whole, .items⟩) {} := by decide

-- 上限ちょうどまで成功する。次の本体は新しい本体予算を使うが、全体3回で止まる。
example :
    let limits : Limits := ⟨⟨2, 10⟩, ⟨3, 10⟩⟩
    let first := (charge limits {} .expression).state
    let second := (charge limits first .environmentRead).state
    let next := finishBody second
    let third := (charge limits next .joinItem).state
    second.body.operations = 2 ∧ second.whole.operations = 2 ∧
    charge limits second .environmentWrite =
      .stopped (.exceeded ⟨.body, .operations⟩) second ∧
    third.body.operations = 1 ∧ third.whole.operations = 3 ∧
    charge limits third .origin = .stopped (.exceeded ⟨.whole, .operations⟩) third := by decide

-- 同じ内容を別の場所へ保存する場合も一項ずつ使う。拒否は最大値も増やさない。
-- 返却で枠を再利用できるが、最大同時保持の履歴は減らない。
example :
    let limits : Limits := ⟨⟨10, 2⟩, ⟨10, 10⟩⟩
    let first := (reserve limits {} .environment .temporary).state
    let second := (reserve limits first .environment .temporary).state
    let freed := release second .temporary 1 (by decide)
    let reused := reserve limits freed .stackFrame .temporary
    second.bodyHeld = 2 ∧ second.body.peak = 2 ∧ second.whole.peak = 2 ∧
    reserve limits second .recordField .temporary =
      .stopped (.exceeded ⟨.body, .items⟩) second ∧
    freed.bodyHeld = 1 ∧ freed.wholeHeld = 1 ∧ freed.body.peak = 2 ∧
    reused = .ok second := by decide

-- 本体終了後の警告と対応表は全体の保持に残り、後の本体の確保を制限する。
-- 削除した保存項目は全体へ返却される。全体の最大値は保存する。
example :
    let limits : Limits := ⟨⟨10, 2⟩, ⟨10, 2⟩⟩
    let warning := (reserve limits {} .warning .saved).state
    let indexed := (reserve limits warning .identity .saved).state
    let next := finishBody indexed
    let freed := releaseSaved next 1 (by decide)
    let result := (reserve limits freed .auxiliary .temporary).state
    next.body = {} ∧ next.whole.saved = 2 ∧ next.wholeHeld = 2 ∧ next.whole.peak = 2 ∧
    reserve limits next .rangeOrigin .saved =
      .stopped (.exceeded ⟨.whole, .items⟩) next ∧
    result.bodyHeld = 1 ∧ result.wholeHeld = 2 ∧ result.body.peak = 1 ∧
    result.whole.peak = 2 := by decide

-- 一時項目から保存項目への移動は複製を作らない。保存項目の明示削除も別に返す。
example :
    let limits : Limits := ⟨⟨10, 3⟩, ⟨10, 3⟩⟩
    let first := (reserve limits {} .warning .temporary).state
    let second := (reserve limits first .identity .saved).state
    let third := (reserve limits second .stackFrame .temporary).state
    let saved := save third 1 (by decide)
    let deleted := release saved .saved 1 (by decide)
    let next := finishBody deleted
    saved.bodyHeld = 3 ∧ saved.savedHeld = 2 ∧ saved.body.temporary = 1 ∧
    deleted.bodyHeld = 2 ∧ deleted.savedHeld = 1 ∧
    next.wholeHeld = 1 ∧ next.savedHeld = 1 ∧ next.whole.peak = 3 ∧ next.body.peak = 0 := by decide

-- 番号の未取得は通常の超過と区別し、原因と最後の実消費を保つ。
example :
    let limits : Limits := ⟨⟨2, 10⟩, ⟨1, 10⟩⟩
    let first := (charge limits {} .numbering).state
    let stopped := (charge limits first .numbering).forNumbering
    stopped = .stopped (.unidentified ⟨.whole, .operations⟩) first ∧
    stopped.state.whole.operations = 1 ∧
    (Step.ok first).forNumbering = .ok first := by decide

end Benitoite.Interval.Budget
