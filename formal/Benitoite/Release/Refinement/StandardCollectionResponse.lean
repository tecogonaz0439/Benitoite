import Benitoite.Release.Refinement.StandardMapSet

/-! # 全引数の型付き入力から具体的なコレクション応答を読む -/
namespace Benitoite.Release.Refinement.StandardCollections
noncomputable section

private theorem count_response {P B Ψ} (ws : List Val) (n : Nat) :
    Outcome.Typed P B Ψ (countReply n) (.base .integer) ∧
    AdequateResult ws (countReply n) ∧ (∀ i, countReply n ≠ .exit i) := by
  unfold countReply
  cases StandardScalar.integerConvert .integer64 n with
  | none => exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp⟩
  | some v =>
    exact ⟨⟨.V_Const trivial,by trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩

/-- 純粋 Map 宣言の有限な構文分類。 -/
inductive MapAPI where
  | empty | fromList | toList | get | set | remove | contains | size | keys | values
  deriving DecidableEq

def MapAPI.name : MapAPI → PrimName
  | .empty => "Map.empty" | .fromList => "Map.fromList" | .toList => "Map.toList"
  | .get => "Map.get" | .set => "Map.set" | .remove => "Map.remove"
  | .contains => "Map.contains" | .size => "Map.size" | .keys => "Map.keys" | .values => "Map.values"

def MapAPI.names : MapAPI → List String
  | .empty => [] | .fromList => ["pairs"] | .get | .remove | .contains => ["m","k"]
  | .set => ["m","k","value"] | _ => ["m"]

def MapAPI.inputs (a b : Ty) : MapAPI → List Ty
  | .empty => [] | .fromList => [.list (.data "Pair" [a,b])]
  | .get | .remove | .contains => [.map a b,a]
  | .set => [.map a b,a,b] | _ => [.map a b]

def MapAPI.result (a b : Ty) : MapAPI → Ty
  | .empty | .fromList | .set | .remove => .map a b
  | .toList => .list (.data "Pair" [a,b]) | .get => .data "Option" [b]
  | .contains => .base .boolean | .size => .base .integer | .keys => .list a | .values => .list b

def MapAPI.signature (sat : List TParam → Ty → TParam → Prop) (api : MapAPI) : PrimSig :=
  ⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,api.names,api.inputs (.tvar 0) (.tvar 1),
    api.result (.tvar 0) (.tvar 1),Eff.empty,
    (fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam),
      ts[i]? = some t → [TParam.keyC,{}][i]? = some p → sat C t p),
    .pure,none,[],.untargeted⟩

private theorem map_api_tel (api : MapAPI) (a b : Ty) (na : a.norm = a) (nb : b.norm = b)
    (wa : a.WF 0 0 0) (wb : b.WF 0 0 0) (sat) :
    instantiatedTel (Tel.instR [] (api.signature sat).tel) [a,b] [] =
      Ty.toTel api.names (api.inputs a b) (api.result a b) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases api <;> simp [MapAPI.signature,MapAPI.names,MapAPI.inputs,MapAPI.result,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
    Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,Tel.bind,Tel.rawBind,
    Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
    na,nb,substAtoms_nil,instAtoms_nil,rowFails,emptyRange,Ty.toTel,
    Ty.shiftV,shiftVTys,Eff.shiftV,Ty.shiftV_of_wf_zero wa,Ty.shiftV_of_wf_zero wb]

/-- 同じ純粋署名の全 BuiltinArgs から、実値の列と型引数を回収する。 -/
private theorem map_api_arguments {P B Ψ ts es rs ws r e} (api : MapAPI)
    (h : BuiltinArgs P B Ψ api.name (api.signature B.sat) ts es rs ws r e) :
    ∃ a b, ts = [a,b] ∧ es = [] ∧ rs = [] ∧
      Ty.Annotation P [] [] a ∧ Ty.Annotation P [] [] b ∧
      a.norm = a ∧ b.norm = b ∧ Ordinary a ∧ Ordinary b ∧
      B.sat [] a.norm TParam.keyC ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] ws (api.inputs a b) ∧ r = api.result a b := by
  have count := h.admissible.typeCount
  change ts.length = 2 at count
  rcases ts with _ | ⟨a,ts⟩
  · cases count
  rcases ts with _ | ⟨b,ts⟩
  · cases count
  have tail : ts = [] := List.length_eq_zero_iff.mp (by simpa using count)
  subst ts
  have rows : es = [] := List.length_eq_zero_iff.mp h.admissible.rowCount
  have ranges : rs = [] := List.length_eq_zero_iff.mp h.ranges.1
  subst es; subst rs
  have ha := h.signature.types a (by simp)
  have hb := h.signature.types b (by simp)
  have na : a.norm = a := (h.types a (by simp)).2
  have nb : b.norm = b := (h.types b (by simp)).2
  have sat : B.sat [] a.norm TParam.keyC := h.admissible.admits.2 0 _ _ rfl rfl
  have args := h.arguments
  rw [map_api_tel api a b na nb ha.wf hb.wf B.sat] at args
  have names : NamesWF api.names (api.inputs a b) := by cases api <;> simp [MapAPI.names,MapAPI.inputs,NamesWF]
  have values := args.toTelValues names
  have resultNormal : (api.result a b).norm = api.result a b := by
    cases api <;> simp [MapAPI.result,Ty.norm,Ty.normTys,na,nb]
  have normInputs : Ty.normTys (api.inputs a b) = api.inputs a b := by
    cases api <;> simp [MapAPI.inputs,Ty.norm,Ty.normTys,na,nb]
  exact ⟨a,b,rfl,rfl,rfl,ha,hb,na,nb,h.admissible.typeScope a (by simp) |>.2,
    h.admissible.typeScope b (by simp) |>.2,sat,normInputs ▸ values.1,
    h.result.2.symm.trans (values.2.1.trans resultNormal)⟩


private theorem closed_elements {xs : List Val} (h : Val.ClosedList 0 0 xs) : ∀ x ∈ xs, x.Ground := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    intro y hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact h.1
    · exact ih h.2 y hy

private theorem adequate_elements {σ : PathEnv} {xs : List Val} (h : adequateVals σ xs) :
    ∀ x ∈ xs, x.Adequate σ := by
  induction xs with
  | nil => simp
  | cons x xs ih =>
    intro y hy
    rcases List.mem_cons.mp hy with rfl | hy
    · exact h.1
    · exact ih h.2 y hy

private theorem close_elements {xs : List Val} (h : ∀ x ∈ xs, x.Ground) : Val.ClosedList 0 0 xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x (by simp),ih (fun y hy => h y (by simp [hy]))⟩

private theorem adequate_elements_intro {σ : PathEnv} {xs : List Val} (h : ∀ x ∈ xs, x.Adequate σ) :
    adequateVals σ xs := by
  induction xs with
  | nil => trivial
  | cons x xs ih => exact ⟨h x (by simp),ih (fun y hy => h y (by simp [hy]))⟩

private theorem each_elements {P B Ψ a xs} (h : ∀ x ∈ xs, HasTypeVQ P B Ψ Qempty [] [] [] x a) :
    HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
  induction xs with
  | nil => exact .nil
  | cons x xs ih => exact .cons (h x (by simp)) (ih (fun y hy => h y (by simp [hy])))

private theorem list_contents {P B Ψ a v} (ha : Ty.Annotation P [] [] a)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.list a)) :
    ∃ xs, v = .list xs ∧ HasTypeEachQ P B Ψ Qempty [] [] [] xs a := by
  obtain ⟨xs,b,rfl,hs,le⟩ := typed.canonical_list rfl
  exact ⟨xs,rfl,each_elements (fun x hx => .V_Sub (hs.member hx) le ha.wf ha.sorted ha.declared)⟩

private theorem key_code {P B Ψ a v} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (typed : HasTypeVQ P B Ψ Qempty [] [] [] v a)
    (sat : B.sat [] a.norm TParam.keyC) : ∃ c, valKeyCode v = some c := by
  obtain ⟨t,c,term,code⟩ := StandardKeyTyping.KeyObservation.code
    (StandardKeyTyping.key_table_sound table valid sat) typed (fun _ => none)
  exact ⟨c,by simp [valKeyCode,term,code]⟩

private theorem list_projection_ground {cs ks vs entries} (normal : normalizedMap cs ks vs = some entries)
    (ground : (Val.mapV ks vs).Ground) (value : Bool) :
    (Val.list (entries.map (if value then MapEntry.value else MapEntry.key))).Ground := by
  apply close_elements
  intro x hx
  obtain ⟨e,he,rfl⟩ := List.mem_map.mp hx
  have mem := normalized_map_members normal e he
  cases value
  · exact closed_elements ground.1 _ mem.1
  · exact closed_elements ground.2 _ mem.2

private theorem list_projection_adequate {cs ks vs entries σ} (normal : normalizedMap cs ks vs = some entries)
    (adequate : (Val.mapV ks vs).Adequate σ) (value : Bool) :
    (Val.list (entries.map (if value then MapEntry.value else MapEntry.key))).Adequate σ := by
  apply adequate_elements_intro
  intro x hx
  obtain ⟨e,he,rfl⟩ := List.mem_map.mp hx
  have mem := normalized_map_members normal e he
  cases value
  · exact adequate_elements adequate.1 _ mem.1
  · exact adequate_elements adequate.2 _ mem.2


set_option maxHeartbeats 1000000 in
/-- 十本の Map の全型付き入力に、同じ実δの応答を供給する。 -/
theorem map_api_response {P B Ψ ts es rs ws r e} (api : MapAPI)
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (args : BuiltinArgs P B Ψ api.name (api.signature B.sat) ts es rs ws r e) :
    ∃ out, mapDelta ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
        api.name ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨a,b,rfl,rfl,rfl,ha,hb,na,nb,oa,ob,sat,values,rfl⟩ := map_api_arguments api args
  let cs := (table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst
  have kinded : TypeArgsKinded P [] [a,b] [.value,.value] := args.signature.kinds
  have bKind : TypeArgsKinded P [] [b] [.value] := by
    refine ⟨rfl,?_⟩
    rintro (_|i) t k ht hk
    · cases Option.some.inj ht; cases Option.some.inj hk
      exact kinded.2 1 b .value rfl rfl
    · simp at ht
  have ordinary : Ordinary a ∧ Ordinary b := ⟨oa,ob⟩
  cases api with
  | empty =>
    cases values
    exact ⟨.val (.mapV [] []),(map_empty_reply (Ψ := Ψ) (Q := Qempty) (Φ := []) cs a b ha hb sat).1,
      ⟨(map_empty_reply (Ψ := Ψ) (Q := Qempty) (Φ := []) cs a b ha hb sat).2,by trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩
  | fromList =>
    cases values with
    | cons typed rest =>
      cases rest
      have pairAnn : Ty.Annotation P [] [] (.data "Pair" [a,b]) :=
        ⟨⟨ha.wf,hb.wf,trivial⟩,⟨ha.sorted,hb.sorted,trivial⟩,⟨⟨2,decls.pairArity,rfl⟩,ha.declared,hb.declared,trivial⟩⟩
      obtain ⟨xs,rfl,each⟩ := list_contents pairAnn typed
      obtain ⟨out,delta,typed,adequate⟩ := map_fromList_full table valid decls ha hb ordinary na nb sat each
        (args.ground _ (by simp)) cs
      exact ⟨.val out,delta,typed,adequate,by intro i; simp⟩
  | toList =>
    cases values with
    | cons typed rest =>
      cases rest
      obtain ⟨ks,vs,rfl,hk,hv,len⟩ := typed_map_components typed ha hb
      obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
      have reply := map_toList_reply decls hk hv ha hb kinded normal
      have ground := args.ground (.mapV ks vs) (by simp)
      refine ⟨_,reply.1,⟨reply.2.1,?_⟩,?_,by intro i; simp⟩
      · apply close_elements
        intro x hx
        obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
        have mem := normalized_map_members normal entry he
        exact ⟨by intro t ht; rcases List.mem_cons.mp ht with rfl | ht; exact ha.wf; cases List.mem_singleton.mp ht; exact hb.wf,
          closed_elements ground.1 _ mem.1,closed_elements ground.2 _ mem.2,trivial⟩
      · intro σ _ inputs
        have adequate := inputs (.mapV ks vs) (by simp)
        apply adequate_elements_intro
        intro x hx
        obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
        have mem := normalized_map_members normal entry he
        exact ⟨adequate_elements adequate.1 _ mem.1,adequate_elements adequate.2 _ mem.2,trivial⟩
  | get =>
    cases values with
    | cons typed rest =>
      cases rest with
      | cons query rest =>
        cases rest
        obtain ⟨ks,vs,rfl,hk,hv,len⟩ := typed_map_components typed ha hb
        obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
        obtain ⟨code,hcode⟩ := key_code table valid query sat
        have reply := map_get_reply (a := a) decls hv hb bKind normal hcode
        have ground := args.ground (.mapV ks vs) (by simp)
        cases found : entries.find? (fun entry => code == entry.code) with
        | none =>
          refine ⟨.val (.con "Option.None" [b] []),by simpa [optionValue,MapAPI.name,cs,found] using reply.1,
            ⟨by simpa [optionValue,MapAPI.result,found] using reply.2,?_⟩,by intro σ _ _; trivial,by intro i; simp⟩
          exact ⟨by intro t ht; cases List.mem_singleton.mp ht; exact hb.wf,trivial⟩
        | some entry =>
          have mem := normalized_map_members normal entry (List.mem_of_find?_eq_some found)
          refine ⟨.val (.con "Option.Some" [b] [entry.value]),by simpa [optionValue,MapAPI.name,cs,found] using reply.1,
            ⟨by simpa [optionValue,MapAPI.result,found] using reply.2,?_⟩,?_,by intro i; simp⟩
          · exact ⟨by intro t ht; cases List.mem_singleton.mp ht; exact hb.wf,closed_elements ground.2 _ mem.2,trivial⟩
          · intro σ _ inputs
            exact ⟨adequate_elements (inputs (.mapV ks vs) (by simp)).2 _ mem.2,trivial⟩
  | set =>
    cases values with
    | cons typed rest =>
      cases rest with
      | cons query rest =>
        cases rest with
        | cons value rest =>
          cases rest
          obtain ⟨ks,vs,rfl,hk,hv,len⟩ := typed_map_components typed ha hb
          obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
          obtain ⟨code,hcode⟩ := key_code table valid query sat
          obtain ⟨out,delta,ht,_⟩ := map_set_reply hk hv ha hb sat query value normal hcode
          have ground := args.ground
          have gs : (Val.mapV ks vs).Ground ∧ _ ∧ _ := ⟨ground (.mapV ks vs) (by simp),ground _ (List.mem_cons_of_mem _ (List.mem_cons_self ..)),ground _ (by simp only [List.mem_cons,List.not_mem_nil,or_false]; exact Or.inr (Or.inr rfl))⟩
          refine ⟨_,delta,⟨ht,map_update_ground a b normal hcode gs (.inl delta)⟩,?_,by intro i; simp⟩
          intro σ _ inputs
          obtain ⟨changed,removed,hd,_,_,good,_,_⟩ := map_update_ready a b normal hcode gs σ
            (inputs (.mapV ks vs) (by simp)) (inputs _ (by simp)) (inputs _ (by simp))
          have eq := Outcome.val.inj (Option.some.inj (delta.symm.trans hd))
          exact eq.symm ▸ good
  | remove =>
    cases values with
    | cons typed rest =>
      cases rest with
      | cons query rest =>
        cases rest
        obtain ⟨ks,vs,rfl,hk,hv,len⟩ := typed_map_components typed ha hb
        obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
        obtain ⟨code,hcode⟩ := key_code table valid query sat
        have reply := map_remove_reply hk hv ha hb sat normal hcode
        have gs : (Val.mapV ks vs).Ground ∧ _ ∧ (Val.const .unit).Ground :=
          ⟨args.ground _ (List.mem_cons_self ..),args.ground _ (List.mem_cons_of_mem _ (List.mem_cons_self ..)),trivial⟩
        refine ⟨_,reply.1,⟨reply.2.1,map_update_ground a b normal hcode gs (.inr reply.1)⟩,?_,by intro i; simp⟩
        intro σ _ inputs
        obtain ⟨changed,removed,_,hd,_,_,_,good⟩ := map_update_ready a b normal hcode gs σ
          (inputs (.mapV ks vs) (by simp)) (inputs _ (by simp)) trivial
        have eq := Outcome.val.inj (Option.some.inj (reply.1.symm.trans hd))
        exact eq.symm ▸ good
  | contains =>
    cases values with
    | cons typed rest =>
      cases rest with
      | cons query rest =>
        cases rest
        obtain ⟨ks,vs,rfl,hk,_,len⟩ := typed_map_components typed ha hb
        obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
        obtain ⟨code,hcode⟩ := key_code table valid query sat
        have reply := map_contains_reply (P := P) (B := B) (Ψ := Ψ) cs a b ks vs entries _ code normal hcode
        exact ⟨_,reply.1,⟨reply.2,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩
  | size =>
    cases values with
    | cons typed rest =>
      cases rest
      obtain ⟨entries,delta⟩ := map_size_from_typed table valid typed ha hb sat cs
      exact ⟨_,delta,count_response _ entries.length⟩
  | keys | values =>
    cases values with
    | cons typed rest =>
      cases rest
      obtain ⟨ks,vs,rfl,hk,hv,len⟩ := typed_map_components typed ha hb
      obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
      have reply := map_projections_reply hk hv ha hb normal
      have ground := args.ground (.mapV ks vs) (by simp)
      first
      | (refine ⟨_,reply.1.1,⟨reply.1.2,list_projection_ground normal ground false⟩,?_,by intro i; simp⟩
         intro σ _ inputs; exact list_projection_adequate normal (inputs _ (by simp)) false)
      | (refine ⟨_,reply.2.1.1,⟨reply.2.1.2,list_projection_ground normal ground true⟩,?_,by intro i; simp⟩
         intro σ _ inputs; exact list_projection_adequate normal (inputs _ (by simp)) true)


inductive SetAPI where
  | empty | fromList | toList | contains | add | remove | size | union | intersection | difference
  deriving DecidableEq

def SetAPI.name : SetAPI → PrimName
  | .empty => "Set.empty" | .fromList => "Set.fromList" | .toList => "Set.toList"
  | .contains => "Set.contains" | .add => "Set.add" | .remove => "Set.remove" | .size => "Set.size"
  | .union => "Set.union" | .intersection => "Set.intersection" | .difference => "Set.difference"

def SetAPI.names : SetAPI → List String
  | .empty => [] | .fromList => ["xs"] | .contains | .add | .remove => ["s","x"]
  | .union | .intersection | .difference => ["a","b"] | _ => ["s"]

def SetAPI.inputs (a : Ty) : SetAPI → List Ty
  | .empty => [] | .fromList => [.list a] | .contains | .add | .remove => [.set a,a]
  | .union | .intersection | .difference => [.set a,.set a] | _ => [.set a]

def SetAPI.result (a : Ty) : SetAPI → Ty
  | .toList => .list a | .contains => .base .boolean | .size => .base .integer | _ => .set a

def SetAPI.signature (sat : List TParam → Ty → TParam → Prop) (api : SetAPI) : PrimSig :=
  ⟨[⟨TParam.keyC,.value⟩],0,api.names,api.inputs (.tvar 0),api.result (.tvar 0),Eff.empty,
    (fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam),
      ts[i]? = some t → [TParam.keyC][i]? = some p → sat C t p),
    .pure,none,[],.untargeted⟩

private theorem set_api_tel (api : SetAPI) (a : Ty) (na : a.norm = a) (wa : a.WF 0 0 0) (sat) :
    instantiatedTel (Tel.instR [] (api.signature sat).tel) [a] [] =
      Ty.toTel api.names (api.inputs a) (api.result a) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases api <;> simp [SetAPI.signature,SetAPI.names,SetAPI.inputs,SetAPI.result,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
    Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,
    Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
    na,substAtoms_nil,instAtoms_nil,rowFails,emptyRange,Ty.toTel,
    Ty.shiftV,shiftVTys,Eff.shiftV,Ty.shiftV_of_wf_zero wa]

private theorem set_api_arguments {P B Ψ ts es rs ws r e} (api : SetAPI)
    (h : BuiltinArgs P B Ψ api.name (api.signature B.sat) ts es rs ws r e) :
    ∃ a, ts = [a] ∧ es = [] ∧ rs = [] ∧ Ty.Annotation P [] [] a ∧ a.norm = a ∧
      B.sat [] a.norm TParam.keyC ∧ HasTypeVsQ P B Ψ Qempty [] [] [] ws (api.inputs a) ∧ r = api.result a := by
  have count := h.admissible.typeCount
  change ts.length = 1 at count
  rcases ts with _ | ⟨a,ts⟩
  · cases count
  have tail : ts = [] := List.length_eq_zero_iff.mp (by simpa using count)
  subst ts
  have rows : es = [] := List.length_eq_zero_iff.mp h.admissible.rowCount
  have ranges : rs = [] := List.length_eq_zero_iff.mp h.ranges.1
  subst es; subst rs
  have ha := h.signature.types a (by simp)
  have na : a.norm = a := (h.types a (by simp)).2
  have sat : B.sat [] a.norm TParam.keyC := h.admissible.admits.2 0 _ _ rfl rfl
  have args := h.arguments
  rw [set_api_tel api a na ha.wf B.sat] at args
  have names : NamesWF api.names (api.inputs a) := by cases api <;> simp [SetAPI.names,SetAPI.inputs,NamesWF]
  have values := args.toTelValues names
  have resultNormal : (api.result a).norm = api.result a := by cases api <;> simp [SetAPI.result,Ty.norm,na]
  have normInputs : Ty.normTys (api.inputs a) = api.inputs a := by cases api <;> simp [SetAPI.inputs,Ty.norm,na]
  exact ⟨a,rfl,rfl,rfl,ha,na,sat,normInputs ▸ values.1,h.result.2.symm.trans (values.2.1.trans resultNormal)⟩


private theorem set_algebra_response {P B Ψ a ws} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (ha : Ty.Annotation P [] [] a) (sat : B.sat [] a.norm TParam.keyC)
    (cs : List ConName) (name : PrimName)
    (known : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference")
    (values : HasTypeVsQ P B Ψ Qempty [] [] [] ws [.set a,.set a]) (ground : ∀ w ∈ ws, w.Ground) :
    ∃ out, setDelta cs name [a] [] [] ws = some out ∧
      Outcome.Typed P B Ψ out (.set a) ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  cases values with
  | cons left rest =>
    cases rest with
    | cons right rest =>
      cases rest
      obtain ⟨xs,rfl,hx⟩ := typed_set_components left ha
      obtain ⟨ys,rfl,hy⟩ := typed_set_components right ha
      obtain ⟨ls,hl⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
      obtain ⟨rs,hr⟩ := normalized_map_exists table valid hy sat cs (ys.map (fun _ => .const .unit)) (by simp)
      obtain ⟨out,delta,typed,_⟩ := set_algebra_reply hx hy ha sat hl hr name known
      have gs := And.intro (ground (.setV xs) (by simp)) (ground (.setV ys) (by simp))
      refine ⟨_,delta,⟨typed,set_algebra_ground a hl hr gs name known delta⟩,?_,by intro i; simp⟩
      intro σ _ inputs
      obtain ⟨out,hd,_,good⟩ := set_algebra_ready a hl hr gs σ
        (inputs (.setV xs) (by simp)) (inputs (.setV ys) (by simp)) name known
      have eq := Outcome.val.inj (Option.some.inj (delta.symm.trans hd))
      exact eq.symm ▸ good

set_option maxHeartbeats 1000000 in
/-- 十本の Set の全入力を、計算した鍵表から具体δへ接続する。 -/
theorem set_api_response {P B Ψ ts es rs ws r e} (api : SetAPI)
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (args : BuiltinArgs P B Ψ api.name (api.signature B.sat) ts es rs ws r e) :
    ∃ out, setDelta ((table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
        api.name ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out r ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨a,rfl,rfl,rfl,ha,na,sat,values,rfl⟩ := set_api_arguments api args
  let cs := (table.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst
  cases api with
  | empty =>
    cases values
    have reply := set_empty_reply (Ψ := Ψ) (Q := Qempty) (Φ := []) cs a ha sat
    exact ⟨_,reply.1,⟨reply.2,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩
  | fromList =>
    cases values with
    | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,hx⟩ := list_contents ha typed
      obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
      have reply := set_fromList_reply hx ha sat normal
      have ground := args.ground (.list xs) (by simp)
      refine ⟨_,reply.1,⟨reply.2,?_⟩,?_,by intro i; simp⟩
      · apply close_elements
        intro x hx
        obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
        exact closed_elements ground _ (normalized_set_members normal entry he)
      · intro σ _ inputs
        apply adequate_elements_intro
        intro x hx
        obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
        exact adequate_elements (inputs (.list xs) (by simp)) _ (normalized_set_members normal entry he)
  | toList =>
    cases values with
    | cons typed rest =>
      cases rest
      obtain ⟨xs,rfl,hx⟩ := typed_set_components typed ha
      obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
      have reply := set_toList_reply hx ha normal
      have ground := args.ground (.setV xs) (by simp)
      refine ⟨_,reply.1,⟨reply.2.1,?_⟩,?_,by intro i; simp⟩
      · apply close_elements
        intro x hx
        obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
        exact closed_elements ground _ (normalized_set_members normal entry he)
      · intro σ _ inputs
        apply adequate_elements_intro
        intro x hx
        obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
        exact adequate_elements (inputs (.setV xs) (by simp)) _ (normalized_set_members normal entry he)
  | contains =>
    cases values with
    | cons typed rest =>
      cases rest with
      | cons query rest =>
        cases rest
        obtain ⟨xs,rfl,hx⟩ := typed_set_components typed ha
        obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
        obtain ⟨code,hcode⟩ := key_code table valid query sat
        have reply := set_contains_reply (P := P) (B := B) (Ψ := Ψ) cs a xs entries _ code normal hcode
        exact ⟨_,reply.1,⟨reply.2,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩
  | add =>
    cases values with
    | cons typed rest =>
      cases rest with
      | cons query rest =>
        cases rest
        obtain ⟨xs,rfl,hx⟩ := typed_set_components typed ha
        obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
        obtain ⟨code,hcode⟩ := key_code table valid query sat
        obtain ⟨out,delta,typed,_⟩ := set_add_reply hx ha sat query normal hcode
        have gs := And.intro (args.ground (.setV xs) (by simp))
          (args.ground _ (List.mem_cons_of_mem _ (List.mem_cons_self ..)))
        refine ⟨_,delta,⟨typed,set_update_ground a normal hcode gs (.inl delta)⟩,?_,by intro i; simp⟩
        intro σ _ inputs
        obtain ⟨changed,removed,hd,_,_,good,_,_⟩ := set_update_ready a normal hcode gs σ
          (inputs (.setV xs) (by simp)) (inputs _ (List.mem_cons_of_mem _ (List.mem_cons_self ..)))
        have eq := Outcome.val.inj (Option.some.inj (delta.symm.trans hd))
        exact eq.symm ▸ good
  | remove =>
    cases values with
    | cons typed rest =>
      cases rest with
      | cons query rest =>
        cases rest
        obtain ⟨xs,rfl,hx⟩ := typed_set_components typed ha
        obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
        obtain ⟨code,hcode⟩ := key_code table valid query sat
        have reply := set_remove_reply hx ha sat normal hcode
        have gs := And.intro (args.ground (.setV xs) (by simp))
          (args.ground _ (List.mem_cons_of_mem _ (List.mem_cons_self ..)))
        refine ⟨_,reply.1,⟨reply.2.1,set_update_ground a normal hcode gs (.inr reply.1)⟩,?_,by intro i; simp⟩
        intro σ _ inputs
        obtain ⟨changed,removed,_,hd,_,_,_,good⟩ := set_update_ready a normal hcode gs σ
          (inputs (.setV xs) (by simp)) (inputs _ (List.mem_cons_of_mem _ (List.mem_cons_self ..)))
        have eq := Outcome.val.inj (Option.some.inj (reply.1.symm.trans hd))
        exact eq.symm ▸ good
  | size =>
    cases values with
    | cons typed rest =>
      cases rest
      obtain ⟨entries,delta⟩ := set_size_from_typed table valid typed ha sat cs
      exact ⟨_,delta,count_response _ entries.length⟩
  | union => exact set_algebra_response table valid ha sat cs "Set.union" (.inl rfl) values args.ground
  | intersection => exact set_algebra_response table valid ha sat cs "Set.intersection" (.inr (.inl rfl)) values args.ground
  | difference => exact set_algebra_response table valid ha sat cs "Set.difference" (.inr (.inr rfl)) values args.ground

/-- Mapの構築・射影の同じ型付き実値を、依存する結果契約からも使う。 -/
theorem map_selected {P B Ψ a b v} (build : Bool) (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (decls : MapSetDeclarations P)
    (ha : Ty.Annotation P [] [] a) (hb : Ty.Annotation P [] [] b)
    (ordinary : Ordinary a ∧ Ordinary b) (an : a.Normal) (bn : b.Normal)
    (kinded : TypeArgsKinded P [] [a,b] [.value,.value]) (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (if build then .list (.data "Pair" [a,b]) else .map a b))
    (ground : v.Ground) (cs : List ConName) :
    ∃ out : Val, mapDelta cs (if build then "Map.fromList" else "Map.toList") [a,b] [] [] [v] = some (.val out) ∧
      Outcome.Typed P B Ψ (.val out) (if build then .map a b else .list (.data "Pair" [a,b])) ∧
      AdequateResult [v] (.val out) ∧ (∀ n,Outcome.val out ≠ .exit n) := by
  cases build
  · obtain ⟨ks,vs,rfl,hk,hv,len⟩ := typed_map_components typed ha hb
    obtain ⟨entries,normal⟩ := normalized_map_exists table valid hk sat cs vs len
    have reply := map_toList_reply decls hk hv ha hb kinded normal
    refine ⟨_,reply.1,⟨reply.2.1,?_⟩,?_,by intro n h; cases h⟩
    · apply close_elements
      intro x hx
      obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
      have mem := normalized_map_members normal entry he
      exact ⟨by intro t ht; rcases List.mem_cons.mp ht with rfl | ht; exact ha.wf; cases List.mem_singleton.mp ht; exact hb.wf,
        closed_elements ground.1 _ mem.1,closed_elements ground.2 _ mem.2,trivial⟩
    · intro σ _ inputs
      have adequate := inputs (.mapV ks vs) (by simp)
      apply adequate_elements_intro
      intro x hx
      obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
      have mem := normalized_map_members normal entry he
      exact ⟨adequate_elements adequate.1 _ mem.1,adequate_elements adequate.2 _ mem.2,trivial⟩
  · have pairAnn : Ty.Annotation P [] [] (.data "Pair" [a,b]) :=
      ⟨⟨ha.wf,hb.wf,trivial⟩,⟨ha.sorted,hb.sorted,trivial⟩,⟨⟨2,decls.pairArity,rfl⟩,ha.declared,hb.declared,trivial⟩⟩
    obtain ⟨xs,rfl,each⟩ := list_contents pairAnn typed
    obtain ⟨out,delta,result,adequate⟩ := map_fromList_full table valid decls ha hb ordinary an bn sat each ground cs
    exact ⟨_,delta,result,adequate,by intro n h; cases h⟩

/-- Setの構築・射影は、同じ入力に由来する保持値だけを返す。 -/
theorem set_selected {P B Ψ a v} (build : Bool) (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) (ha : Ty.Annotation P [] [] a) (sat : B.sat [] a.norm TParam.keyC)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (if build then .list a else .set a))
    (ground : v.Ground) (cs : List ConName) :
    ∃ out : Val, setDelta cs (if build then "Set.fromList" else "Set.toList") [a] [] [] [v] = some (.val out) ∧
      Outcome.Typed P B Ψ (.val out) (if build then .set a else .list a) ∧
      AdequateResult [v] (.val out) ∧ (∀ n,Outcome.val out ≠ .exit n) := by
  cases build
  · obtain ⟨xs,rfl,hx⟩ := typed_set_components typed ha
    obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
    have reply := set_toList_reply hx ha normal
    refine ⟨_,reply.1,⟨reply.2.1,?_⟩,?_,by intro n h; cases h⟩
    · apply close_elements
      intro x hx
      obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
      exact closed_elements ground _ (normalized_set_members normal entry he)
    · intro σ _ inputs
      apply adequate_elements_intro
      intro x hx
      obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
      exact adequate_elements (inputs (.setV xs) (by simp)) _ (normalized_set_members normal entry he)
  · obtain ⟨xs,rfl,hx⟩ := list_contents ha typed
    obtain ⟨entries,normal⟩ := normalized_map_exists table valid hx sat cs (xs.map (fun _ => .const .unit)) (by simp)
    have reply := set_fromList_reply hx ha sat normal
    refine ⟨_,reply.1,⟨reply.2,?_⟩,?_,by intro n h; cases h⟩
    · apply close_elements
      intro x hx
      obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
      exact closed_elements ground _ (normalized_set_members normal entry he)
    · intro σ _ inputs
      apply adequate_elements_intro
      intro x hx
      obtain ⟨entry,he,rfl⟩ := List.mem_map.mp hx
      exact adequate_elements (inputs (.list xs) (by simp)) _ (normalized_set_members normal entry he)

end
end Benitoite.Release.Refinement.StandardCollections
