import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.PredicateRowCollection
import Benitoite.Release.Refinement.Surface.Theorems

/-! # 名前解決で生成する内部名と元の核構文の名前 -/
namespace Benitoite.Release.Refinement.Surface.PredicateGeneratedNames
noncomputable section

private def operationNames : Benitoite.Release.OpRef → List PrimName
  | .prim name => [name]
  | _ => []

mutual
  /-- 値に含まれる全ての組込み名。閉包のコードと捕捉値も含める。 -/
  def valueNames : Val → List PrimName
    | .prim name _ _ _ => [name]
    | .lam _ _ body | .dependentLam _ body => compNames body
    | .closure _ body => closureNames body
    | .con _ _ values | .list values | .setV values | .dict _ _ values => valuesNames values
    | .mapV keys values => valuesNames keys ++ valuesNames values
    | .super value _ | .checkedRequest _ value => valueNames value
    | .checkedAt _ _ _ value => optionalNames value
    | .atError detail => valueNames detail.originalPattern ++ valueNames detail.originalTarget
    | _ => []
  def valuesNames : List Val → List PrimName
    | [] => []
    | value :: rest => valueNames value ++ valuesNames rest
  def optionalNames : Option Val → List PrimName
    | none => []
    | some value => valueNames value
  def slotsNames : List (Option Val) → List PrimName
    | [] => []
    | value :: rest => optionalNames value ++ slotsNames rest
  def captureNames : Capture → List PrimName
    | .mk values => slotsNames values
  def closureNames : Closure → List PrimName
    | .mk capture body => captureNames capture ++ compNames body
  /-- 実際の脱糖後の全ての計算を辿る。起点の発行とハンドラの組込み名も含める。 -/
  def compNames : Comp → List PrimName
    | .builderLet _ body | .lazyC body => compNames body
    | .builderOp _ _ _ values | .externalCall _ _ values => valuesNames values
    | .ret value | .escape value => valueNames value
    | .letIn left right => compNames left ++ compNames right
    | .app function values => valueNames function ++ valuesNames values
    | .ite value yes no => valueNames value ++ compNames yes ++ compNames no
    | .match value arms => valueNames value ++ armsNames arms
    | .use value body => valueNames value ++ compNames body
    | .handle body clauses => compNames body ++ clausesNames clauses
    | .resume left right => valueNames left ++ valueNames right
    | .issuePathBases name => [name]
    | .checkAt _ _ _ bases pattern input _ => optionalNames bases ++ valueNames pattern ++ valueNames input
    | .meth dictionary _ _ _ values => valueNames dictionary ++ valuesNames values
  def armsNames : List Arm → List PrimName
    | [] => []
    | .mk _ guard body :: rest => (match guard with | none => [] | some g => compNames g) ++
        compNames body ++ armsNames rest
  def clausesNames : List Clause → List PrimName
    | [] => []
    | .mk operation _ _ body :: rest => operationNames operation ++ compNames body ++ clausesNames rest
    | .fail _ body :: rest => compNames body ++ clausesNames rest
end

/-- 構成済みの内部行の名前を、重ねた表の全層から集める。 -/
def builtinNames : Check.BuiltinSource → List PrimName
  | .predicates _ rows => rows.map Prod.fst
  | .resolved base rows => builtinNames base ++ rows.map Prod.fst
  | .standard _ | .custom _ | .unrestrictedRanges _ => []

/-- 全本体を実際に脱糖してから組込み名を集め、演算子の解決や隠れた呼出しも含める。 -/
def sourceNames (q : Check.Input) (p : Program) : List PrimName :=
  (q.defs.flatMap fun name => match p.defs name with
    | none => [] | some d => compNames (desugarBlock q.opPrim .tail d.body)) ++
  (q.impls.flatMap fun name => match p.impls name with
    | none => [] | some id => q.methods.flatMap fun method => match id.methods method with
      | none => [] | some body => compNames (desugarBlock q.opPrim .tail body))

def forbidden (q : Check.Input) (p : Program) : List PrimName :=
  sourceNames q p ++ builtinNames q.builtinSource

theorem source_def {q : Check.Input} {p : Program} {name d key}
    (listed : name ∈ q.defs) (found : p.defs name = some d)
    (member : key ∈ compNames (desugarBlock q.opPrim .tail d.body)) : key ∈ sourceNames q p := by
  apply List.mem_append_left
  apply List.mem_flatMap.mpr
  exact ⟨name, listed, by simpa only [found] using member⟩

theorem source_method {q : Check.Input} {p : Program} {name id method body key}
    (listed : name ∈ q.impls) (found : p.impls name = some id)
    (methodListed : method ∈ q.methods) (methodFound : id.methods method = some body)
    (member : key ∈ compNames (desugarBlock q.opPrim .tail body)) : key ∈ sourceNames q p := by
  apply List.mem_append_right
  apply List.mem_flatMap.mpr
  refine ⟨name, listed, ?_⟩
  rw [found]
  exact List.mem_flatMap.mpr ⟨method, methodListed, by simpa only [methodFound] using member⟩

mutual
  theorem dictionary_names (dictionary : DictEv) : valueNames dictionary.toVal = [] := by
    cases dictionary <;> simp only [DictEv.toVal, valueNames, dictionaryList_names, dictionary_names]
  theorem dictionaryList_names (dictionaries : List DictEv) : valuesNames (DictEv.toValList dictionaries) = [] := by
    cases dictionaries <;> simp only [DictEv.toValList, valuesNames, dictionary_names,
      dictionaryList_names, List.nil_append]
end

theorem accessor_names (constructor : ConName) (declaration : ConDecl) (field : Nat) :
    compNames (accessorDef constructor declaration field).body = [] := by
  rfl

theorem tester_names (constructor : ConName) (declaration : ConDecl) :
    compNames (testerDef constructor declaration).body = [] := by
  rfl

/-- 脱糖で補うgetterとtesterを含め、核の全ての関数本体の名前は有限の元本体の一覧に含まれる。 -/
theorem kernel_def_names {q : Check.Input} {p : Program}
    (complete : ∀ name d, p.defs name = some d → name ∈ q.defs)
    {name d key} (found : (desugarProgram q.opPrim p).defs name = some d)
    (member : key ∈ compNames d.body) : key ∈ sourceNames q p := by
  rcases lookupFun_desugar found with ⟨source, lookup, rfl⟩ |
    ⟨_, constructor, field, declaration, _, _, rfl⟩ | ⟨_, _, constructor, declaration, _, _, rfl⟩
  · exact source_def (complete name source lookup) lookup member
  · rw [accessor_names] at member
    cases member
  · rw [tester_names] at member
    cases member

theorem kernel_method_names {q : Check.Input} {p : Program}
    {name id method body key} (listed : name ∈ q.impls) (methodListed : method ∈ q.methods)
    (found : (desugarProgram q.opPrim p).impls name = some id)
    (methodFound : id.methods method = some body) (member : key ∈ compNames body) :
    key ∈ sourceNames q p := by
  change (p.impls name).map (desugarImpl q.opPrim) = some id at found
  cases source : p.impls name with
  | none => simp only [source, Option.map_none, reduceCtorEq] at found
  | some original =>
    simp only [source, Option.map_some, Option.some.injEq] at found
    subst id
    change (original.methods method).map (desugarBlock q.opPrim .tail) = some body at methodFound
    cases lookup : original.methods method with
    | none => simp only [lookup, Option.map_none, reduceCtorEq] at methodFound
    | some originalBody =>
      simp only [lookup, Option.map_some, Option.some.injEq] at methodFound
      subst body
      exact source_method listed source methodListed lookup member

/-- 上位辞書の生成は辞書の証拠だけを値へ写し、組込み名を含まない。 -/
theorem kernel_super_names {q : Check.Input} {p : Program} {name id superclass value}
    (found : (desugarProgram q.opPrim p).impls name = some id)
    (selected : id.supers superclass = some value) : valueNames value = [] := by
  change (p.impls name).map (desugarImpl q.opPrim) = some id at found
  cases source : p.impls name with
  | none => simp only [source, Option.map_none, reduceCtorEq] at found
  | some original =>
    simp only [source, Option.map_some, Option.some.injEq] at found
    subst id
    change (original.supers superclass).map DictEv.toVal = some value at selected
    cases lookup : original.supers superclass with
    | none => simp only [lookup, Option.map_none, reduceCtorEq] at selected
    | some dictionary =>
      simp only [lookup, Option.map_some, Option.some.injEq] at selected
      subst value
      exact dictionary_names dictionary

end
end Benitoite.Release.Refinement.Surface.PredicateGeneratedNames
