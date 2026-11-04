import Benitoite.Release.Refinement.StandardCollectionResponse
import Benitoite.Release.Refinement.StandardCollectionBodies

/-! # 同じ有限宣言を使う Map/Set の本番読者 -/
namespace Benitoite.Release.Refinement.StandardCollectionModel
noncomputable section
open StandardCollections StandardBodies StandardKeyTyping

def declarations : List DataDecl := [
  ⟨"Option",1,[("Option.Some",[.tvar 0]),("Option.None",[])]⟩,
  ⟨"Pair",2,[("Pair.Pair",[.tvar 0,.tvar 1])]⟩]

def constructors : List ConName := (declarations.flatMap DataDecl.entries).map Prod.fst

def summaries := Benitoite.Release.dataSummaries (declarations.map DataDecl.summaryInput)

def program : Program where
  defs := fun name =>
    if name = "List.map" then some (collectionListDefinition false)
    else if name = "List.filter" then some (collectionListDefinition true)
    else if name = "Pair.first" then some (collectionPairProjection false)
    else if name = "Pair.second" then some (collectionPairProjection true)
    else if name = "Map.map" then (collectionHigherRow true false).definition
    else if name = "Map.filter" then (collectionHigherRow true true).definition
    else if name = "Set.map" then (collectionHigherRow false false).definition
    else if name = "Set.filter" then (collectionHigherRow false true).definition
    else none
  cons := fun c => (declarations.flatMap DataDecl.entries).lookup c
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

def mapAPIs : List MapAPI := [.empty,.fromList,.toList,.get,.set,.remove,.contains,.size,.keys,.values]
def setAPIs : List SetAPI := [.empty,.fromList,.toList,.contains,.add,.remove,.size,.union,.intersection,.difference]

def builtins : Builtins where
  sat := fun C a p => Benitoite.Release.satB summaries C (carrier a) p = true
  sig := fun name =>
    ((mapAPIs.find? (fun api => api.name == name)).map (fun api => api.signature
      (fun C a p => Benitoite.Release.satB summaries C (carrier a) p = true))).orElse (fun _ =>
    (setAPIs.find? (fun api => api.name == name)).map (fun api => api.signature
      (fun C a p => Benitoite.Release.satB summaries C (carrier a) p = true)))
  delta := fun name ts es rs ws => if name.startsWith "Map."
    then mapDelta constructors name ts es rs ws else setDelta constructors name ts es rs ws
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  refGet := "Reference.get"
  refSet := "Reference.set"

def table : Table program builtins :=
  ⟨declarations,by decide,by decide,rfl,by decide,fun _ _ _ => Iff.rfl⟩

private theorem cons_mem {c cd} (h : program.cons c = some cd) :
    (c,cd) ∈ declarations.flatMap DataDecl.entries := by
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp h
  rw [eq]
  exact List.mem_append_right _ (List.mem_cons_self ..)

theorem pair_arity : program.DataArity "Pair" 2 := by
  refine ⟨⟨"Pair.Pair",_,rfl,rfl⟩,?_⟩
  intro c cd h same
  have mem := cons_mem h
  change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
  simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all

theorem valid : program.VarianceValid := by
  constructor
  · intro d info h; cases h
  · intro c cd h
    have mem := cons_mem h
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals
      constructor
      · intro info h; cases h
      · intro a ha
        simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
        all_goals first | subst a | (rcases ha with rfl | rfl)
        all_goals refine ⟨⟨?_,?_,?_⟩,?_,?_⟩
        all_goals simp [Ty.WF,Ty.Sorted,Ty.Declared,Ty.HasKind,TypeCtx.valueParam,
          Ty.VarianceOK,Program.varianceFor,Variance.accepts,program]

/-- 四本とも、同じ具体的な P/B と計算した制約表へ適用される。 -/
theorem typed (map filter : Bool) : (collectionHigherRow map filter).BodyTyped program builtins := by
  apply collectionHigher_body_typed table map filter
  · intro _; exact pair_arity
  · intro _; rfl
  · intro _ second; cases second <;> rfl
  · intro build; cases map <;> cases build <;> rfl
  · cases filter <;> rfl

example : (collectionHigherRow true false).BodyTyped program builtins := typed true false
example : (collectionHigherRow true true).BodyTyped program builtins := typed true true
example : (collectionHigherRow false false).BodyTyped program builtins := typed false false
example : (collectionHigherRow false true).BodyTyped program builtins := typed false true

private theorem collection_declarations : MapSetDeclarations program := by
  refine ⟨rfl,pair_arity,?_,rfl,rfl,?_⟩
  · intro c cd h same
    have mem := cons_mem h
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all
  · refine ⟨⟨"Option.Some",_,rfl,rfl⟩,?_⟩
    intro c cd h same
    have mem := cons_mem h
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all

/-- 同じ有限表の全20宣言から、同じδへの型付き応答を読む。 -/
theorem map_reply (api : MapAPI) {Ψ ts es rs ws r e}
    (args : BuiltinArgs program builtins Ψ api.name (api.signature builtins.sat) ts es rs ws r e) :
    builtins.sig api.name = some (api.signature builtins.sat) ∧
    ∃ out, builtins.delta api.name ts es rs ws = some out ∧
      Outcome.Typed program builtins Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  constructor
  · cases api <;> rfl
  · obtain ⟨out,delta,rest⟩ := map_api_response api table valid
      collection_declarations args
    refine ⟨out,?_,rest⟩
    cases api <;> simpa [builtins,MapAPI.name,table,constructors] using delta

theorem set_reply (api : SetAPI) {Ψ ts es rs ws r e}
    (args : BuiltinArgs program builtins Ψ api.name (api.signature builtins.sat) ts es rs ws r e) :
    builtins.sig api.name = some (api.signature builtins.sat) ∧
    ∃ out, builtins.delta api.name ts es rs ws = some out ∧
      Outcome.Typed program builtins Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  constructor
  · cases api <;> rfl
  · obtain ⟨out,delta,rest⟩ := set_api_response api table valid args
    refine ⟨out,?_,rest⟩
    cases api <;> simpa [builtins,SetAPI.name,table,constructors] using delta



/-- 同じ有限表のMap更新・削除を、返す値のmeasureで読む。 -/
theorem map_update_measures {Ψ a b ks vs entries k v code}
    (hk : HasTypeEachQ program builtins Ψ Qempty [] [] [] ks a)
    (hv : HasTypeEachQ program builtins Ψ Qempty [] [] [] vs b)
    (ha : Ty.Annotation program [] [] a) (hb : Ty.Annotation program [] [] b)
    (sat : builtins.sat [] a.norm TParam.keyC)
    (key : HasTypeVQ program builtins Ψ Qempty [] [] [] k a)
    (value : HasTypeVQ program builtins Ψ Qempty [] [] [] v b)
    (normal : normalizedMap constructors ks vs = some entries) (hcode : valKeyCode k = some code)
    (η : ObservationEnvModel) :
    (∃ out, builtins.delta "Map.set" [a,b] [] [] [.mapV ks vs,k,v] = some (.val (mapValue out)) ∧
      (Term.measure .mapSize (.mapValue (Val.toTermSlots (out.map MapEntry.key)) (Val.toTermSlots (out.map MapEntry.value)))).observe η =
        some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length else entries.length+1)))) ∧
    (∃ out, builtins.delta "Map.remove" [a,b] [] [] [.mapV ks vs,k] = some (.val (mapValue out)) ∧
      (Term.measure .mapSize (.mapValue (Val.toTermSlots (out.map MapEntry.key)) (Val.toTermSlots (out.map MapEntry.value)))).observe η =
        some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length-1 else entries.length)))) := by
  constructor
  · simpa [builtins] using map_set_measure table valid hk hv ha hb sat key value normal hcode η
  · simpa [builtins] using map_remove_measure table valid hk hv ha hb sat normal hcode η

/-- Setの更新・削除も、再正規化された実measureを読む。 -/
theorem set_update_measures {Ψ a xs entries x code}
    (hx : HasTypeEachQ program builtins Ψ Qempty [] [] [] xs a)
    (ha : Ty.Annotation program [] [] a) (sat : builtins.sat [] a.norm TParam.keyC)
    (value : HasTypeVQ program builtins Ψ Qempty [] [] [] x a)
    (normal : normalizedSet constructors xs = some entries) (hcode : valKeyCode x = some code)
    (η : ObservationEnvModel) :
    (∃ out, builtins.delta "Set.add" [a] [] [] [.setV xs,x] = some (.val (setValue out)) ∧
      (Term.measure .setSize (.setValue (Val.toTermSlots (out.map MapEntry.key)))).observe η =
        some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length else entries.length+1)))) ∧
    (∃ out, builtins.delta "Set.remove" [a] [] [] [.setV xs,x] = some (.val (setValue out)) ∧
      (Term.measure .setSize (.setValue (Val.toTermSlots (out.map MapEntry.key)))).observe η =
        some (.integer (Int.ofNat (if code ∈ entries.map MapEntry.code then entries.length-1 else entries.length)))) := by
  constructor
  · simpa [builtins] using set_add_measure table valid hx ha sat value normal hcode η
  · simpa [builtins] using set_remove_measure table valid hx ha sat normal hcode η

/-- Set.fromList の縮約後の個数は元列の長さ以下である。 -/
theorem from_list_bound {Ψ a xs}
    (hx : HasTypeEachQ program builtins Ψ Qempty [] [] [] xs a)
    (sat : builtins.sat [] a.norm TParam.keyC) :
    ∃ entries, builtins.delta "Set.fromList" [a] [] [] [.list xs] = some (.val (setValue entries)) ∧ entries.length ≤ xs.length := by
  obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat constructors (xs.map (fun _ => .const .unit)) (by simp)
  exact ⟨entries,by simp [builtins,setDelta,normalizedSet,normal],normalized_map_length_le normal⟩

example {Ψ a b xs} (ha : Ty.Annotation program [] [] a) (hb : Ty.Annotation program [] [] b)
    (ordinary : Ordinary a ∧ Ordinary b) (na : a.Normal) (nb : b.Normal)
    (sat : builtins.sat [] a.norm TParam.keyC)
    (typed : HasTypeEachQ program builtins Ψ Qempty [] [] [] xs (.data "Pair" [a,b])) :
    ∃ entries, builtins.delta "Map.fromList" [a,b] [] [] [.list xs] = some (.val (mapValue entries)) ∧
      HasTypeVQ program builtins Ψ Qempty [] [] [] (mapValue entries) (.map a b) := by
  simpa [builtins] using map_fromList_reply table valid collection_declarations ha hb ordinary na nb sat typed constructors

example {Ψ a b ks vs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots ks)) (normal : normalizedMap constructors ks vs = some entries)
    (n : Benitoite.Release.Integer64Value) (success : countReply entries.length = .val (.const (.integer n))) :
    builtins.delta "Map.size" [a,b] [] [] [.mapV ks vs] = some (.val (.const (.integer n))) ∧
    HasTypeVQ program builtins Ψ Qempty [] [] [] (.const (.integer n)) (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Term.measure .mapSize (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))).observe η = some (.integer n.toInt) := by
  simpa [builtins] using map_size_reply (P := program) (B := builtins) (Ψ := Ψ) (a := a) (b := b) η closed normal n success

example {Ψ a xs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots (Val.toTermSlots xs)) (normal : normalizedSet constructors xs = some entries)
    (n : Benitoite.Release.Integer64Value) (success : countReply entries.length = .val (.const (.integer n))) :
    builtins.delta "Set.size" [a] [] [] [.setV xs] = some (.val (.const (.integer n))) ∧
    HasTypeVQ program builtins Ψ Qempty [] [] [] (.const (.integer n)) (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Term.measure .setSize (.setValue (Val.toTermSlots xs))).observe η = some (.integer n.toInt) := by
  simpa [builtins] using set_size_reply (P := program) (B := builtins) (Ψ := Ψ) (a := a) η closed normal n success

example {Ψ a xs ys left right} (hx : HasTypeEachQ program builtins Ψ Qempty [] [] [] xs a)
    (hy : HasTypeEachQ program builtins Ψ Qempty [] [] [] ys a) (ha : Ty.Annotation program [] [] a)
    (sat : builtins.sat [] a.norm TParam.keyC)
    (hl : normalizedSet constructors xs = some left) (hr : normalizedSet constructors ys = some right)
    (name : PrimName) (known : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference")
    (η : ObservationEnvModel) :
    ∃ out, builtins.delta name [a] [] [] [.setV xs,.setV ys] = some (.val (setValue out)) ∧
      (Term.measure .setSize (.setValue (Val.toTermSlots (out.map MapEntry.key)))).observe η = some (.integer out.length) := by
  obtain ⟨out,delta,measure⟩ := set_algebra_measure table valid hx hy ha sat hl hr name known η
  refine ⟨out,?_,measure⟩
  rcases known with rfl | rfl | rfl <;> simpa [builtins] using delta

example {a xs ys left right} (hl : normalizedSet constructors xs = some left)
    (hr : normalizedSet constructors ys = some right) :
    ∃ out, builtins.delta "Set.union" [a] [] [] [.setV xs,.setV ys] = some (.val (setValue out)) ∧
      max left.length right.length ≤ out.length ∧ out.length ≤ left.length+right.length := by
  simpa [builtins] using set_union_reply_bounds a hl hr

example {a xs ys left right} (hl : normalizedSet constructors xs = some left)
    (hr : normalizedSet constructors ys = some right)
    (name : PrimName) (known : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference") :
    ∃ out, builtins.delta name [a] [] [] [.setV xs,.setV ys] = some (.val (setValue out)) ∧
      ∀ c, c ∈ out.map MapEntry.code ↔
        if name = "Set.union" then c ∈ left.map MapEntry.code ∨ c ∈ right.map MapEntry.code
        else if name = "Set.intersection" then c ∈ left.map MapEntry.code ∧ c ∈ right.map MapEntry.code
        else c ∈ left.map MapEntry.code ∧ c ∉ right.map MapEntry.code := by
  obtain ⟨out,delta,codes⟩ := set_algebra_reply_codes a hl hr name known
  refine ⟨out,?_,codes⟩
  rcases known with rfl | rfl | rfl <;> simpa [builtins] using delta

private def decimal (n : Int) (s : Nat) : Val := .const (.decimal n s)
private def unit : Val := .const .unit
private def callback : Val := .lam ["value"] [.base .unit] (.ret (.var 0))
private def constantCallback : Val := .lam ["value"] [.base .unit] (.ret (.const .unit))
private def callbackType : Ty := .fn ["value"] [.base .unit] (.base .unit) Eff.empty

example : callback.toTerm? = none := by rfl
example : constantCallback.toTerm? = none := by rfl

/-- 数値昇順と、同鍵の最初の表現・最後の値を同時に読む。 -/
example : mapDelta constructors "Map.keys" [.base .decimal,.base .unit] [] []
    [.mapV [decimal 20 1,decimal (-1) 0,decimal 2 0] [unit,unit,unit]] =
      some (.val (.list [decimal (-1) 0,decimal 20 1])) := by cbv

example : mapDelta constructors "Map.values" [.base .decimal,.fn ["value"] [.base .unit] (.base .unit) Eff.empty] [] []
    [.mapV [decimal 10 1,decimal 1 0] [constantCallback,callback]] = some (.val (.list [callback])) := by cbv

example : mapDelta constructors "Map.set" [.base .decimal,callbackType] [] []
    [.mapV [decimal 10 1] [constantCallback],decimal 1 0,callback] =
      some (.val (.mapV [decimal 10 1] [callback])) := by cbv

example : setDelta constructors "Set.fromList" [.base .decimal] [] []
    [.list [decimal 20 1,decimal (-1) 0,decimal 2 0]] =
      some (.val (.setV [decimal (-1) 0,decimal 20 1])) := by cbv

example : setDelta constructors "Set.union" [.base .decimal] [] []
    [.setV [decimal 10 1],.setV [decimal 1 0,decimal 2 0]] =
      some (.val (.setV [decimal 10 1,decimal 2 0])) := by cbv

example : setDelta constructors "Set.intersection" [.base .decimal] [] []
    [.setV [decimal 10 1,decimal 2 0],.setV [decimal 1 0]] =
      some (.val (.setV [decimal 10 1])) := by cbv

example : setDelta constructors "Set.difference" [.base .decimal] [] []
    [.setV [decimal 10 1,decimal 2 0],.setV [decimal 1 0]] =
      some (.val (.setV [decimal 2 0])) := by cbv

example : mapDelta constructors "Map.get" [.base .unit,.base .unit] [] [] [.mapV [] [],unit] =
    some (.val (.con "Option.None" [.base .unit] [])) := by cbv

example : mapDelta constructors "Map.fromList" [.base .unit,.base .unit] [] [] [.list [unit]] = none := by cbv
example : setDelta constructors "Set.add" [.base .unit] [Eff.empty] [] [.setV [],unit] = none := by cbv
example : mapDelta constructors "Map.keys" [.base .unit] [] [] [.mapV [] []] = none := by cbv
example : mapDelta constructors "Map.keys" [.base .unit,.base .unit] [] [.top] [.mapV [] []] = none := by cbv

example : ((mapInsert [2,0,1,0] (decimal 1 0) callback
    [⟨[2,0,1,0],decimal 10 1,constantCallback⟩]).find? (fun e => [2,0,1,0] == e.code)).map
      (fun e => (e.key,e.value)) = some (decimal 10 1,callback) := by
  simpa [List.find?] using map_insert_original [2,0,1,0] (decimal 1 0) callback [⟨[2,0,1,0],decimal 10 1,constantCallback⟩]

example : setDelta constructors "Set.contains" [.set (.base .decimal)] [] []
    [.setV [.setV [decimal 10 1]],.setV [decimal 1 0]] = some (.val (.const (.boolean true))) := by cbv

example : mapDelta constructors "Map.remove" [.base .decimal,callbackType] [] []
    [.mapV [decimal 10 1] [callback],decimal 1 0] = some (.val (.mapV [] [])) := by cbv

example : setDelta constructors "Set.union" [.base .unit] [] [] [.setV [],.setV []] = some (.val (.setV [])) := by cbv

example : program.defs "List.map" = (listHigherRow false).definition := by
  exact (collectionListDefinition_eq false).symm
example : program.defs "List.filter" = (listHigherRow true).definition := by
  exact (collectionListDefinition_eq true).symm

end
end Benitoite.Release.Refinement.StandardCollectionModel
