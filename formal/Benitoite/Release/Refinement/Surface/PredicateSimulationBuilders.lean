import Benitoite.Release.Refinement.Surface.PredicateSimulationStructure
import Benitoite.Release.Refinement.Surface.PredicateSimulationNameAlgebra
import Benitoite.Release.Refinement.Surface.PredicateSimulationReplyAvoid

/-! # Builderの応答と一段の対応

リスト内の関数値も値の対応で比較する。Builder操作には元の型付けを要求しない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

theorem BuilderRel.refl {source rows} (contents : BuilderContents) : BuilderRel source rows contents contents := by
  cases contents with
  | string text => exact .string text
  | bytes bytes => exact .bytes bytes
  | list values => exact .list (.refl values)

theorem BuilderRel.size {source rows left right} (h : BuilderRel source rows left right) : left.size = right.size := by
  cases h with
  | string text => rfl
  | bytes bytes => rfl
  | list values => exact values.length

theorem BuilderRel.limit {source rows left right} (h : BuilderRel source rows left right) : left.limit = right.limit := by
  cases h <;> rfl

theorem BuilderRel.snapshot {source rows left right} (h : BuilderRel source rows left right) :
    Value source rows left.snapshot right.snapshot := by
  cases h with
  | string text => exact .constant _
  | bytes bytes => exact .bytes bytes
  | list values => exact .list values

inductive BuilderReplyRel (source : Program) (rows : PredicateProjection.Table.Rows) : BuilderReply → BuilderReply → Prop
  | value {left right v w} : BuilderRel source rows left right → Value source rows v w →
      BuilderReplyRel source rows (.value left v) (.value right w)
  | error (reason) : BuilderReplyRel source rows (.error reason) (.error reason)

theorem BuilderReplyRel.refl {source rows} (reply : BuilderReply) : BuilderReplyRel source rows reply reply := by
  cases reply with
  | value contents value => exact .value (.refl contents) (.refl value)
  | error reason => exact .error reason

private theorem optionalBuilderReply_refl {source rows} (reply : Option BuilderReply) :
    Option.Rel (BuilderReplyRel source rows) reply reply := by
  cases reply with
  | none => exact .none
  | some reply => exact .some (.refl reply)

theorem Values.builderJoin {source rows values targets} (h : Values source rows values targets) :
    builderJoin values = builderJoin targets := by
  cases h with
  | nil => rfl
  | cons head tail => cases head with
    | constant c => cases c with
      | string text => simp only [Refinement.builderJoin,tail.builderJoin]
      | _ => rfl
    | _ => rfl

theorem BuilderRel.checkUpdate {source rows left right} (h : BuilderRel source rows left right) :
    BuilderReplyRel source rows (builderCheckUpdate left) (builderCheckUpdate right) := by
  cases h with
  | string text => exact .refl _
  | bytes bytes => exact .refl _
  | @list xs ys values =>
    change BuilderReplyRel source rows
      (if xs.length ≤ maxBuilderListLen then .value (.list xs) (.const .unit) else .error rValueTooLarge)
      (if ys.length ≤ maxBuilderListLen then .value (.list ys) (.const .unit) else .error rValueTooLarge)
    rw [values.length]
    by_cases good : ys.length ≤ maxBuilderListLen
    · simp only [ite_eq_left good]; exact .value (.list values) (.constant _)
    · simp only [ite_eq_right good]; exact .error _

/-- コピー・長さ・追加・一括追加の成功、不適合、不変の失敗payloadを全て対応させる。 -/
theorem BuilderRel.apply {source rows left right values targets}
    (contents : BuilderRel source rows left right) (arguments : Values source rows values targets) (op : BuilderOp) :
    Option.Rel (BuilderReplyRel source rows) (builderApply op left values) (builderApply op right targets) := by
  cases arguments with
  | nil => cases op with
    | copy => exact .some (.value contents contents.snapshot)
    | length => cases contents with
      | string text => exact optionalBuilderReply_refl _
      | bytes bytes => exact optionalBuilderReply_refl _
      | @list xs ys values =>
        by_cases good : xs.length ≤ maxBuilderListLen
        · have sourceGood : (BuilderContents.list xs).size ≤ (BuilderContents.list xs).limit := good
          have targetGood : (BuilderContents.list ys).size ≤ (BuilderContents.list ys).limit := by
            change ys.length ≤ maxBuilderListLen
            exact values.length ▸ good
          have same : (BuilderContents.list xs).lengthValue sourceGood = (BuilderContents.list ys).lengthValue targetGood := by
            apply Subtype.ext
            exact congrArg Int.ofNat values.length
          simp only [builderApply,dite_eq_left sourceGood,dite_eq_left targetGood]
          rw [same]
          exact Option.Rel.some (.value (.list values) (.constant _))
        · have sourceBad : ¬(BuilderContents.list xs).size ≤ (BuilderContents.list xs).limit := good
          have targetBad : ¬(BuilderContents.list ys).size ≤ (BuilderContents.list ys).limit := by
            change ¬ys.length ≤ maxBuilderListLen
            exact values.length ▸ good
          simp only [builderApply,dite_eq_right sourceBad,dite_eq_right targetBad]
          exact Option.Rel.none
    | append | appendAll => cases contents <;> exact .none
  | cons head tail => cases tail with
    | cons other rest => cases head with
      | constant c => cases c <;> cases contents <;> cases op <;> exact .none
      | _ => cases contents <;> cases op <;> exact .none
    | nil => cases op with
      | copy | length => exact .none
      | append => cases contents with
        | string text => cases head with
          | constant c => cases c with
            | string added => exact .some ((BuilderRel.string (text ++ added)).checkUpdate)
            | _ => exact .none
          | _ => exact .none
        | list values => exact .some ((BuilderRel.list (values.append (.cons head .nil))).checkUpdate)
        | bytes bytes => cases head with
          | constant c => cases c with
            | byte added => exact .some ((BuilderRel.bytes (bytes ++ [added])).checkUpdate)
            | _ => exact .none
          | _ => exact .none
      | appendAll => cases contents with
        | string text => cases head with
          | list values =>
            simp only [builderApply,values.builderJoin]
            exact optionalBuilderReply_refl _
          | _ => exact .none
        | list values => cases head with
          | list targets => exact .some ((BuilderRel.list (values.append targets)).checkUpdate)
          | _ => exact .none
        | bytes bytes => cases head with
          | bytes added => exact .some ((BuilderRel.bytes (bytes ++ added)).checkUpdate)
          | _ => exact .none

def BuilderReplyAvoid (keys : List PrimName) : BuilderReply → Prop
  | .value contents value => BuilderAvoid keys contents ∧ ValueAvoid keys value
  | .error _ => True

def OptionalBuilderReplyAvoid (keys : List PrimName) : Option BuilderReply → Prop
  | none => True
  | some reply => BuilderReplyAvoid keys reply

theorem BuilderAvoid.snapshot {keys contents} (avoid : BuilderAvoid keys contents) :
    ValueAvoid keys contents.snapshot := by
  cases contents with
  | string text => exact ValueAvoid.constant _ _
  | bytes values => exact ValueAvoid.bytes _
  | list values => exact ValueAvoid.list avoid

theorem BuilderAvoid.checkUpdate {keys contents} (avoid : BuilderAvoid keys contents) :
    BuilderReplyAvoid keys (builderCheckUpdate contents) := by
  cases contents with
  | string text | list values =>
    unfold builderCheckUpdate
    split
    · exact ⟨avoid,ValueAvoid.constant _ _⟩
    · trivial
  | bytes values =>
    change BuilderReplyAvoid keys
      (if (BuilderContents.bytes values).size ≤ (BuilderContents.bytes values).limit then
        if values.all (· < 256) then .value (.bytes values) (.const .unit) else .error rBuilderInvalidByte
       else .error rValueTooLarge)
    split
    · split
      · exact ⟨avoid,ValueAvoid.constant _ _⟩
      · trivial
    · trivial

/-- 実Builderの全操作は、保持していた要素と引数から生成鍵を増やさない。 -/
theorem BuilderAvoid.apply {keys contents values} (avoid : BuilderAvoid keys contents)
    (arguments : ValuesAvoid keys values) (op : BuilderOp) :
    OptionalBuilderReplyAvoid keys (builderApply op contents values) := by
  cases op with
  | copy => cases values with
    | nil => exact ⟨avoid,avoid.snapshot⟩
    | cons value rest => trivial
  | length => cases values with
    | nil =>
      simp only [builderApply]
      split
      · exact ⟨avoid,ValueAvoid.constant _ _⟩
      · trivial
    | cons value rest => trivial
  | append =>
    cases values with
    | nil => cases contents <;> trivial
    | cons value rest => cases rest with
      | cons other tail => cases contents <;> cases value <;> simp [builderApply,OptionalBuilderReplyAvoid]
      | nil =>
        have element := (ValuesAvoid.cons.mp arguments).1
        cases contents with
        | list before =>
          exact BuilderAvoid.checkUpdate (contents := .list (before ++ [value]))
            (ValuesAvoid.append.mpr ⟨avoid,ValuesAvoid.cons.mpr ⟨element,ValuesAvoid.nil _⟩⟩)
        | string text => cases value with
          | const constant => cases constant with
            | string added => exact BuilderAvoid.checkUpdate (contents := .string (text ++ added)) trivial
            | _ => trivial
          | _ => trivial
        | bytes before => cases value with
          | const constant => cases constant with
            | byte added => exact BuilderAvoid.checkUpdate (contents := .bytes (before ++ [added])) trivial
            | _ => trivial
          | _ => trivial
  | appendAll =>
    cases values with
    | nil => cases contents <;> trivial
    | cons value rest => cases rest with
      | cons other tail => cases contents <;> cases value <;> simp [builderApply,OptionalBuilderReplyAvoid]
      | nil =>
        have element := (ValuesAvoid.cons.mp arguments).1
        cases contents with
        | list before => cases value with
          | list added =>
            exact BuilderAvoid.checkUpdate (contents := .list (before ++ added))
              (ValuesAvoid.append.mpr ⟨avoid,element.list_inv⟩)
          | _ => trivial
        | bytes before => cases value with
          | bytesV added => exact BuilderAvoid.checkUpdate (contents := .bytes (before ++ added)) trivial
          | _ => trivial
        | string text => cases value with
          | list added =>
            simp only [builderApply]
            cases joined : builderJoin added with
            | none => trivial
            | some result => exact BuilderAvoid.checkUpdate (contents := .string (text ++ result)) trivial
          | _ => trivial

theorem structural_builder_operation {source rows P Q B C σ q r kind op location values targets k l μ ν contents updated value}
    (first : q.view = .builderOp kind op (.loc location) values)
    (second : r.view = .builderOp kind op (.loc location) targets)
    (arguments : Values source rows values targets) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (found : μ location = some (.builder contents)) (reply : builderApply op contents values = some (.value updated value)) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_BuilderOp first found reply) := by
  obtain ⟨targetContents,targetFound,related⟩ := hμ.lookup found
  cases related with
  | @builder left right contents =>
    have output := contents.apply arguments op
    rw [reply] at output
    cases targetReply : builderApply op right targets with
    | none => rw [targetReply] at output; cases output
    | some response =>
      rw [targetReply] at output
      cases output with
      | some related => cases related with
        | value next result => exact ⟨_,.E_BuilderOp second targetFound targetReply,
            .run (.pure (.ret result)) hk (hμ.set (.builder next))⟩

theorem structural_builder_error {source rows P Q B C σ q r kind op location values targets k l μ ν contents reason}
    (first : q.view = .builderOp kind op (.loc location) values)
    (second : r.view = .builderOp kind op (.loc location) targets)
    (arguments : Values source rows values targets) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (found : μ location = some (.builder contents)) (reply : builderApply op contents values = some (.error reason)) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_BuilderErr first found reply) := by
  obtain ⟨targetContents,targetFound,related⟩ := hμ.lookup found
  cases related with
  | @builder left right contents =>
    have output := contents.apply arguments op
    rw [reply] at output
    cases targetReply : builderApply op right targets with
    | none => rw [targetReply] at output; cases output
    | some response =>
      rw [targetReply] at output
      cases output with
      | some related => cases related with
        | error reason => exact ⟨_,.E_BuilderErr second targetFound targetReply,.error hk hμ⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
