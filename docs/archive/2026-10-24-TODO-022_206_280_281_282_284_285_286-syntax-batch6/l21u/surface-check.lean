import Benitoite.Interval.Range
import Benitoite.Interval.EvalClosed

-- 名前は保存した実交換の宣言と関数の型から取得した。同定番号を推測しない。
open Benitoite.Interval Benitoite.Release
private def names : RangeNames := ⟨"data:525", "con:525:0", "data:212", "data:529", "con:212:0", "con:212:1", "con:529:0", "con:529:1"⟩
private def key : OperationKey := ⟨"L21U.surface", 0⟩

example : (StandardRule.rangeValue names.record).argumentType = .data "data:525" [] := rfl
example : (StandardRule.rangeCheck names).resultType =
    .data "data:212" [.data "data:525" [], .data "data:529" []] := rfl
example : rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩ =
    .con "data:525" [] "con:525:0"
      [.integer ⟨0, by decide⟩, .integer ⟨10, by decide⟩, .integer ⟨5, by decide⟩] := rfl

#guard
  match rangeCheck names key ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩ with
  | .normal (.con owner [] constructor [.integer lo, .integer hi, .integer value]) =>
      owner == "data:525" && constructor == "con:525:0" &&
      (lo.toInt, hi.toInt, value.toInt) == (0, 10, 5)
  | _ => false
#guard
  let payload := rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩
  match ClosedEval.standard (.rangeValue names.record) key [payload] with
  | some ⟨.normal (.integer value), _⟩ => value.toInt == 5
  | _ => false
#guard
  match (StandardRule.rangeCheck names).finish
      (rangeCheck names key ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩) with
  | .normal (.con owner [.data checked [], .data error []] constructor
      [.con stored [] tag [.integer lo, .integer hi, .integer value]]) =>
      owner == "data:212" && checked == "data:525" && error == "data:529" && constructor == "con:212:0" &&
      stored == "data:525" && tag == "con:525:0" && (lo.toInt, hi.toInt, value.toInt) == (0, 10, 5)
  | _ => false
