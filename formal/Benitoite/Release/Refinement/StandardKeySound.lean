import Benitoite.Release.Refinement.StandardKeySummary
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.ValueFacts
import Benitoite.Release.Refinement.ScopePublicTyping

/-! # 型付きの有限値から鍵の構造を得る -/
namespace Benitoite.Release.Refinement.StandardKeyTyping
noncomputable section

private def Aggregate : Val → Prop
  | .con .. | .list .. | .mapV .. | .setV .. | .bytesV .. => True
  | _ => False

private theorem annotation_core {P C Γ a} (h : Ty.Annotation P C Γ a) :
    Ty.Annotation P C Γ a.norm.core := ⟨h.norm.wf.core,h.norm.sorted.core,h.norm.declared.core⟩

private theorem aggregate_annotation {P B Ψ Q C Γ Φ a v}
    (typed : HasTypeVQ P B Ψ Q C Γ Φ v a) (aggregate : Aggregate v) :
    Ty.Annotation P C Γ a.norm.core := by
  match typed with
  | .V_Con _ _ _ _ _ ha => exact annotation_core ha
  | .V_List _ hw hs hd => exact annotation_core ⟨hw,hs,hd⟩
  | .V_Map _ _ _ _ ha hb =>
    exact annotation_core ⟨⟨ha.wf,hb.wf⟩,⟨ha.sorted,hb.sorted⟩,⟨ha.declared,hb.declared⟩⟩
  | .V_Set _ _ ha => exact annotation_core ⟨ha.wf,ha.sorted,ha.declared⟩
  | .V_Bytes _ => exact ⟨trivial,trivial,trivial⟩
  | .V_Sub _ _ hw hs hd => exact annotation_core ⟨hw,hs,hd⟩
  | .V_Normal h => simpa only [Ty.norm_idem] using aggregate_annotation h aggregate
  | .V_Refine h .. => simpa only [Ty.refined_norm_core] using aggregate_annotation h aggregate
  | .V_Var .. | .V_Const .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Raise .. | .V_Dict .. | .V_Super .. | .V_LocRef .. | .V_LocLazy .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. => cases aggregate

private theorem arguments_ordinary {P Γ Φ vs as bs}
    (h : TypeArgsLe P Γ Φ vs as bs) (ha : ∀ a ∈ as, Ordinary a) : ∀ b ∈ bs, Ordinary b := by
  match h with
  | .nil => intro b hb; cases hb
  | .covariant_cons le tail =>
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact le.notContCore.mp (ha _ (List.mem_cons_self ..))
    · exact arguments_ordinary tail (fun a h => ha a (List.mem_cons_of_mem _ h)) b hb
  | .contravariant_cons le tail =>
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact le.notContCore.mpr (ha _ (List.mem_cons_self ..))
    · exact arguments_ordinary tail (fun a h => ha a (List.mem_cons_of_mem _ h)) b hb
  | .invariant_cons eq tail =>
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact (Ty.ordinary_norm _).mp (eq ▸ (Ty.ordinary_norm _).mpr (ha _ (List.mem_cons_self ..)))
    · exact arguments_ordinary tail (fun a h => ha a (List.mem_cons_of_mem _ h)) b hb

private def ObservedKey (v : Val) (η : ObservationEnvModel) : Prop :=
  ∃ t o, v.toTerm? = some t ∧ t.Closed ∧ t.observe η = some o ∧ o.KeyShape

private theorem slots_from_members (vs : List Val) (η : ObservationEnvModel)
    (each : ∀ v ∈ vs, ObservedKey v η) :
    Observation.KeySlots (observeSlots η (Val.toTermSlots vs)) := by
  induction vs with
  | nil => exact .nil
  | cons v vs ih =>
    obtain ⟨t,o,ht,_,ho,shape⟩ := each v (List.mem_cons_self ..)
    simpa [Val.toTermSlots,observeSlots,ht,ho] using
      (Observation.KeySlots.cons shape (ih (fun v h => each v (List.mem_cons_of_mem _ h))))

private theorem pairs_from_slots {ks vs}
    (hk : Observation.KeySlots ks) (hv : Observation.KeySlots vs) (lengths : ks.length = vs.length) :
    Observation.KeyPairs ks vs := by
  induction ks generalizing vs with
  | nil =>
    have eq : vs = [] := List.length_eq_zero_iff.mp lengths.symm
    subst vs
    exact .nil
  | cons k ks ih =>
    cases hk with
    | cons hk hs =>
      cases vs with
      | nil => simp at lengths
      | cons v vs =>
        cases hv with
        | cons hv ht => exact .cons hk hv (ih hs ht (by simpa using lengths))

private theorem closed_observed_term {P B Ψ Q a v t s}
    (typed : HasTypeVQ P B Ψ Q [] [] [] v a) (term : v.toTerm? = some t) (sort : a.HasSort s) :
    t.Closed := by
  obtain ⟨u,hu,_,closed⟩ := typed.closed_observation sort
  cases Option.some.inj (hu.symm.trans term)
  exact closed

private theorem constant_key (c : Const) (η : ObservationEnvModel) (S : Benitoite.Release.SummaryTable)
    (sat : Benitoite.Release.satisfiesB S [] true (carrier c.type) = true) :
    ObservedKey (.const c) η := by
  cases c with
  | integer n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | integer8 n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | integer16 n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | integer32 n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | unsignedInteger16 n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | unsignedInteger32 n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | unsignedInteger64 n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | byte n => exact ⟨_,_,rfl,trivial,rfl,.integer _⟩
  | decimal c s => exact ⟨_,_,rfl,trivial,rfl,.decimal _ _⟩
  | character c => exact ⟨_,_,rfl,trivial,rfl,.character _⟩
  | boolean b => exact ⟨_,_,rfl,trivial,rfl,.boolean _⟩
  | unit => exact ⟨_,_,rfl,trivial,rfl,.unit⟩
  | string s => exact ⟨_,_,rfl,trivial,rfl,.string _⟩
  | float64 | float32 | «opaque» => simp [carrier,Const.type,Benitoite.Release.satisfiesB] at sat

private theorem core_sort {a t : Ty} {s : «Sort»} (eq : a.norm.core = t) (sort : t.HasSort s) : a.HasSort s :=
  (Ty.hasSort_norm a s).mp ((Ty.hasSort_core a.norm s).mp (eq.symm ▸ sort))

/-- At の診断の観測の欄は、九欄の公開形の鍵の観測である。 -/
private theorem atError_key (detail : AtError) (η : ObservationEnvModel) :
    Observation.KeySlots (observeSlots η [some detail.publicTree.toTerm]) := by
  obtain ⟨o, ho, hk⟩ := detail.publicTree_typed.key η
  simpa [observeSlots, ho] using Observation.KeySlots.cons hk .nil

private theorem value_key {P B Ψ Q a v} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Q [] [] [] v a) (sat : B.sat [] a.norm TParam.keyC)
    (η : ObservationEnvModel) : ObservedKey v η := by
  let S := Benitoite.Release.dataSummaries (table.declarations.map DataDecl.summaryInput)
  have sc : Benitoite.Release.satisfiesB S [] true (carrier a.norm.core) = true := by
    rw [carrier_core]
    exact (table.sat_eq _ _ _).mp sat
  cases ht : a.norm.core with
  | base b =>
    obtain ⟨c,rfl,_,_⟩ := typed.canonical_scalar ht
    have hc := (typed.inv_const rfl).2
    apply constant_key c η S
    rw [←carrier_norm c.type,←carrier_core c.type.norm,←hc]
    exact sc
  | list b =>
    have hb : a.norm.listCore = some b := by
      rw [←Ty.listCore_core a.norm,ht]
      rfl
    obtain ⟨xs,c,rfl,each,le⟩ := (HasTypeVQ.V_Normal typed).canonical_list hb
    have ann := aggregate_annotation typed trivial
    rw [ht] at ann
    have ba : Ty.Annotation P [] [] b := ⟨ann.wf,ann.sorted,ann.declared⟩
    have bsat : B.sat [] b.norm TParam.keyC := by
      apply (table.sat_eq _ _ _).mpr
      simpa only [Benitoite.Release.satB,TParam.keyC,ite_true,carrier_norm] using
        (show Benitoite.Release.satisfiesB S [] true (carrier b) = true from (by simpa only [ht,carrier,Benitoite.Release.satisfiesB] using sc))
    have shape := slots_from_members xs η (fun w hw => value_key table valid
      (.V_Sub (each.member hw) le ba.wf ba.sorted ba.declared) bsat η)
    exact ⟨_,_,rfl,closed_observed_term typed rfl (core_sort ht rfl),rfl,.list shape⟩
  | data d us =>
    rcases typed.canonical_data ht with ⟨c,ts,xs,rfl⟩ | ⟨detail,rfl⟩
    · obtain ⟨cd,hc,hn,hkind,_,fields,us',he,rel⟩ := typed.inv_con rfl
      have same := Ty.data.inj (he.symm.trans ht)
      cases same.1
      cases same.2
      have ann := aggregate_annotation typed trivial
      rw [ht] at ann
      have ordinary : ∀ t ∈ Ty.normTys ts, Ordinary t := by
        intro t ht
        obtain ⟨u,hu,rfl⟩ := List.mem_map.mp (by simpa only [Ty.normTys_eq_map] using ht)
        exact (Ty.ordinary_norm _).mpr (hkind.ordinary u hu)
      have targetOrd := arguments_ordinary rel ordinary
      have dsat : B.sat [] (.data cd.data us) TParam.keyC := by
        apply (table.sat_eq _ _ _).mpr
        simpa only [Benitoite.Release.satB,TParam.keyC,ite_true] using (show Benitoite.Release.satisfiesB S [] true (carrier (.data cd.data us)) = true from (by simpa only [ht] using sc))
      have shape := slots_from_members xs η (by
        intro w hw
        obtain ⟨i,hi,hv⟩ := List.mem_iff_getElem.mp hw
        have lengths := fields.length
        have bi : i < cd.args.length := by simp only [List.length_map] at lengths; omega
        have hf : cd.args[i]? = some cd.args[i] := by simp [bi]
        obtain ⟨w',hw',wt⟩ := typed.con_field_by_type hc ht hf valid ann.data_args targetOrd
        have eq : w' = w := by simpa only [List.getElem?_eq_getElem hi,hv,Option.some.injEq] using hw'.symm
        subst w'
        exact value_key table valid wt (table.key_field valid hc (List.getElem_mem bi) dsat) η)
      exact ⟨_,_,rfl,closed_observed_term typed rfl (core_sort ht rfl),rfl,.data shape⟩
    · exact ⟨_,_,rfl,closed_observed_term typed rfl (core_sort ht rfl),rfl,
        .data (atError_key detail η)⟩
  | map k b =>
    obtain ⟨ks,vs,rfl⟩ := typed.canonical_map ht
    obtain ⟨k0,b0,k',b',keys,values,lengths,ksat,_,_,hmap,_,le⟩ := typed.inv_mapV rfl
    have same := Ty.map.inj (hmap.symm.trans ht)
    cases same.1
    cases same.2
    have ann := aggregate_annotation typed trivial
    rw [ht] at ann
    have ba : Ty.Annotation P [] [] b := ⟨ann.wf.2,ann.sorted.2,ann.declared.2⟩
    have bsat : B.sat [] b.norm TParam.keyC := by
      apply (table.sat_eq _ _ _).mpr
      simpa only [Benitoite.Release.satB,TParam.keyC,ite_true,carrier_norm] using
        (show Benitoite.Release.satisfiesB S [] true (carrier b) = true from (by
          have pair : Benitoite.Release.satisfiesB S [] true (carrier k) = true ∧
              Benitoite.Release.satisfiesB S [] true (carrier b) = true := by
            simpa only [ht,carrier,Benitoite.Release.satisfiesB,Bool.and_eq_true] using sc
          exact pair.2))
    have hk := slots_from_members ks η (fun w hw => value_key table valid (keys.member hw) ksat η)
    have hv := slots_from_members vs η (fun w hw => value_key table valid
      (.V_Sub (values.member hw) le ba.wf ba.sorted ba.declared) bsat η)
    have len : (observeSlots η (Val.toTermSlots ks)).length = (observeSlots η (Val.toTermSlots vs)).length := by
      simpa only [observeSlots_length,Val.toTermSlots_eq_map,List.length_map] using lengths
    exact ⟨_,_,rfl,closed_observed_term typed rfl (core_sort ht rfl),rfl,.map (pairs_from_slots hk hv len)⟩
  | set b =>
    obtain ⟨xs,rfl⟩ := typed.canonical_set ht
    obtain ⟨c,_,each,sat,_,_,_⟩ := typed.inv_setV rfl
    have shape := slots_from_members xs η (fun w hw => value_key table valid (each.member hw) sat η)
    exact ⟨_,_,rfl,closed_observed_term typed rfl (core_sort ht rfl),rfl,.set shape⟩
  | bytes =>
    obtain ⟨bs,rfl⟩ := typed.canonical_bytes ht
    obtain ⟨bound,_⟩ := typed.inv_bytesV rfl
    exact ⟨_,_,rfl,closed_observed_term typed rfl (core_sort ht rfl),rfl,
      .bytes (by simpa only [List.all_eq_true,decide_eq_true_eq] using bound)⟩
  | refined b p => exact False.elim (Ty.core_not_refined a.norm b p ht)
  | fn | dependentFn | tvar | «opaque» | reference | lazy | cont | dict | tapp | ctor |
      external | «scoped» | pathBases | scopePattern =>
    simp [ht,carrier,Benitoite.Release.satisfiesB] at sc
termination_by sizeOf v
decreasing_by
  all_goals simp_wf
  all_goals subst_vars
  all_goals simp_all
  all_goals first
    | (have hs := List.sizeOf_lt_of_mem hw; omega)
    | (have hs := List.sizeOf_lt_of_mem (List.getElem_mem hi); omega)

private theorem slots_eq_map (η : ObservationEnvModel) (ts : List (Option Term)) :
    observeSlots η ts = ts.map (fun t => t.bind (Term.observe η)) := by
  induction ts with
  | nil => rfl
  | cons t ts ih => cases t <;> simp [observeSlots,ih]

/-- 具体の判定表と同じ宣言から、任意の型付きの有限値の鍵構造を得る。 -/
theorem key_table_sound {P B} (table : Table P B) (valid : P.VarianceValid) {a : Ty}
    (sat : B.sat [] a.norm TParam.keyC) : KeyObservation P B a :=
  fun typed η => value_key table valid typed sat η

theorem key_values_sound {P B Ψ Q vs as} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeVsQ P B Ψ Q [] [] [] vs as)
    (sat : ∀ a ∈ as, B.sat [] a.norm TParam.keyC) (η : ObservationEnvModel) :
    Observation.KeySlots ((Val.toTermSlots vs).map (fun t => t.bind (Term.observe η))) := by
  induction vs generalizing as with
  | nil => cases typed; exact .nil
  | cons v vs ih =>
    cases typed with
    | cons h hs =>
      obtain ⟨t,o,ht,_,ho,shape⟩ := key_table_sound table valid (sat _ (List.mem_cons_self ..)) h η
      simpa [Val.toTermSlots,ht,ho] using
        (Observation.KeySlots.cons shape (ih hs (fun a ha => sat a (List.mem_cons_of_mem _ ha))))

theorem key_each_sound {P B Ψ Q vs a} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] vs a) (sat : B.sat [] a.norm TParam.keyC)
    (η : ObservationEnvModel) :
    Observation.KeySlots ((Val.toTermSlots vs).map (fun t => t.bind (Term.observe η))) := by
  rw [←slots_eq_map]
  exact slots_from_members vs η (fun v hv => key_table_sound table valid sat (typed.member hv) η)

theorem key_closed_slots {P B Ψ Q vs a} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] vs a) (sat : B.sat [] a.norm TParam.keyC) :
    Key.ClosedSlots (Val.toTermSlots vs) := by
  intro slot hs t ht
  rw [Val.toTermSlots_eq_map] at hs
  obtain ⟨v,hv,eq⟩ := List.mem_map.mp hs
  obtain ⟨u,o,hu,closed,_,_⟩ := key_table_sound table valid sat (typed.member hv) (fun _ => none)
  cases Option.some.inj (hu.symm.trans (eq.trans ht))
  exact closed

/-- Map の縮約の存在には、値側の鍵制約を要求しない。 -/
theorem key_map_normal {P B Ψ Q ks a} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] ks a) (sat : B.sat [] a.norm TParam.keyC)
    (vs : List Val) (lengths : ks.length = vs.length) :
    ∃ entries, Key.normalizeMap (Val.toTermSlots ks) (Val.toTermSlots vs) = some entries := by
  let η : ObservationEnvModel := fun _ => none
  have shapes := key_each_sound table valid typed sat η
  rw [←slots_eq_map] at shapes
  obtain ⟨es,hes⟩ := shapes.mapKeys (observeSlots η (Val.toTermSlots vs))
    (by simpa only [observeSlots_length,Val.toTermSlots_eq_map,List.length_map] using lengths) []
  have h := Key.normalizeMap_length η (Val.toTermSlots ks) (Val.toTermSlots vs)
    (key_closed_slots table valid typed sat)
  change mapKeys (observeSlots η (Val.toTermSlots ks)) (observeSlots η (Val.toTermSlots vs)) = some es at hes
  rw [hes] at h
  cases hn : Key.normalizeMap (Val.toTermSlots ks) (Val.toTermSlots vs) with
  | none => simp only [Val.toTermSlots_eq_map] at hn; simp [hn] at h
  | some out => exact ⟨out,rfl⟩

theorem key_set_normal {P B Ψ Q xs a} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] xs a) (sat : B.sat [] a.norm TParam.keyC) :
    ∃ entries, Key.normalizeSet (Val.toTermSlots xs) = some entries := by
  let η : ObservationEnvModel := fun _ => none
  have shapes := key_each_sound table valid typed sat η
  rw [←slots_eq_map] at shapes
  obtain ⟨es,hes⟩ := shapes.setCodes []
  have h := Key.normalizeSet_length η (Val.toTermSlots xs) (key_closed_slots table valid typed sat)
  rw [hes] at h
  cases hn : Key.normalizeSet (Val.toTermSlots xs) with
  | none => simp only [Val.toTermSlots_eq_map] at hn; simp [hn] at h
  | some out => exact ⟨out,rfl⟩

example :
    (let S := Benitoite.Release.dataSummaries (Representatives.declarations.map DataDecl.summaryInput)
     [Ty.refined (.base .integer8) (.le (.integer 0) (.var 0)),.base .float,.base .float32,
      .set (.base .decimal),.bytes,.reference (.base .unit),.lazy (.base .unit),
      .opaque "Opaque" (.fixed .top),.scoped "Scoped" .path (.fixed .top),.pathBases,.scopePattern .path].map
       (fun a => Benitoite.Release.satB S [] (carrier a) TParam.keyC)) =
    [true,false,false,true,true,false,false,false,false,false,false] := by decide

example {P B Ψ Q xs a} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] xs a) (sat : B.sat [] a.norm TParam.keyC) :
    ∃ entries, Key.normalizeSet (Val.toTermSlots xs) = some entries :=
  key_set_normal table valid typed sat

example {P B Ψ Q vs as} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeVsQ P B Ψ Q [] [] [] vs as)
    (sat : ∀ a ∈ as, B.sat [] a.norm TParam.keyC) (η : ObservationEnvModel) :
    ∃ cs, keySlotCodes ((Val.toTermSlots vs).map (fun t => t.bind (Term.observe η))) = some cs :=
  (key_values_sound table valid typed sat η).codes

example {P B Ψ Q v a} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Q [] [] [] v a) (sat : B.sat [] a.norm TParam.keyC) :
    ∃ t c, v.toTerm? = some t ∧ Key.code? t = some c :=
  KeyObservation.code (key_table_sound table valid sat) typed (fun _ => none)

example {P B Ψ Q a ks} (table : Table P B) (valid : P.VarianceValid)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] ks a) (sat : B.sat [] a.norm TParam.keyC)
    (vs : List Val) (lengths : ks.length = vs.length) :
    ∃ entries, Key.normalizeMap (Val.toTermSlots ks) (Val.toTermSlots vs) = some entries :=
  key_map_normal table valid typed sat vs lengths

end
end Benitoite.Release.Refinement.StandardKeyTyping
