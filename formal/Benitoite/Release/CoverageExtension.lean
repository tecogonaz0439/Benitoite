import Benitoite.Release.Coverage

/-! 設計書 01-12「網羅性」の構成子を追加した後の網羅性。現在の実行の定理とは分ける。 -/
namespace Benitoite.Release

/-- 既存の構成子の宣言を保ち、view が真の型にだけ新しい構成子を追加する。
構成子以外の表は Inhabits と Exhaustive が参照しないため制約しない。 -/
structure ConstructorExtension (P Q : Program) (view : CoverageView) : Prop where
  preserve : ∀ c cd, P.cons c = some cd → Q.cons c = some cd
  added : ∀ c cd, Q.cons c = some cd → P.cons c = none → view cd.data = true

namespace Coverage

/-- 既存の宣言を保つ拡張は、照合可能な問いを失わない。 -/
theorem compatible_extension {P Q : Program} {view : CoverageView}
    (ext : ConstructorExtension P Q view) {ty : Ty} {q : Pat}
    (h : compatible P ty q = true) : compatible Q ty q = true := by
  cases ty with
  | data d ts =>
    cases q with
    | con c ps =>
      cases hc : conFields P d ts c with
      | none => simp [compatible, isWild, hc] at h
      | some fields =>
        have he : conFields Q d ts c = some fields := by
          unfold conFields at hc ⊢
          cases hp : P.cons c with
          | none => simp [hp] at hc
          | some cd => simpa [hp, ext.preserve c cd hp] using hc
        simpa [compatible, isWild, hc, he] using h
    | _ => simpa only [compatible, isWild] using h
  | base b =>
    cases q with
    | const c => cases b <;> cases c <;> simp_all [compatible, isWild]
    | range lo hi => cases b <;> cases lo <;> cases hi <;> simp_all [compatible, isWild]
    | _ => simpa only [compatible, isWild] using h
  | _ => cases q <;> simpa only [compatible, isWild] using h

/-- 新しい構成子は future で表す。既存の構成子の欄は Q の値として再帰する。 -/
theorem shapes_extension_cover {P Q : Program} {ctors ctors' : DataName → List ConName}
    {view : CoverageView} (ext : ConstructorExtension P Q view)
    (hc : CtorsComplete P ctors) (hc' : CtorsComplete Q ctors')
    {ty : Ty} {column : List Pat} {q : Pat} {v : Val}
    (hq : q ∈ column) (hv : Inhabits Q ty v)
    (hcompat : compatible P ty q = true) (hm : (Pat.matchVal q v).isSome = true) :
    ∃ s xs ps, s ∈ shapesWithView P ctors view ty column ∧ Represents s v xs ∧
      InhabitsAll Q s.fields xs ∧ specialize q s = some ps ∧
      (Pat.matchList ps xs).isSome = true := by
  cases hv with
  | @con c ts tys xs cd hd hn hx =>
    cases hp : P.cons c with
    | some old =>
      have he := ext.preserve c old hp
      have eq : old = cd := Option.some.inj (he.symm.trans hd)
      subst old
      let fields := substTys ts cd.args
      have hf : conFields P cd.data ts c = some fields := by simp [conFields, hp, hn, fields]
      have hi : InhabitsAll Q fields xs := by
        apply inhabitsAll_erase_transfer hx
        simp only [fields, substTys, eraseTys_map, List.map_map]
        exact List.map_congr_left (fun a _ => erase_subst_raw ts a)
      have hs : Shape.con c fields ∈ shapesWithView P ctors view (.data cd.data ts) column := by
        apply mem_shapesWithView
        exact List.mem_map.mpr ⟨c, hc c cd hp, by simp [hf]⟩
      have hr : Represents (.con c fields) (.con c tys xs) xs := .con c fields tys xs (inhabitsAll_length hi)
      by_cases hw : isWild q = true
      · obtain ⟨ps, hp, hm⟩ := specialize_wild hw hr
        exact ⟨_, _, ps, hs, hr, hi, hp, hm⟩
      have hw' : isWild q = false := by cases he : isWild q <;> simp_all
      cases q <;> simp [isWild, compatible] at hcompat hw'
      rename_i d ps
      simp only [Pat.matchVal] at hm
      split at hm
      · rename_i he
        subst d
        have hl : ps.length = fields.length := (matchList_length hm).trans hr.length.symm
        exact ⟨_, _, ps, hs, hr, hi, by simp [specialize, isWild, hl], hm⟩
      · simp_all
    | none =>
      have hw : isWild q = true := by
        by_cases hw : isWild q = true
        · exact hw
        have hw' : isWild q = false := by cases he : isWild q <;> simp_all
        exfalso
        cases q <;> simp [isWild, compatible] at hcompat hw'
        rename_i d ps
        simp only [Pat.matchVal] at hm
        split at hm
        · rename_i he
          subst d
          simp [conFields, hp] at hcompat
        · simp_all
      have hs : Shape.future cd.data ∈ shapesWithView P ctors view (.data cd.data ts) column := by
        simp [shapesWithView, ext.added c cd hd hp]
      exact ⟨_, [], [], hs, .future _ _, .nil, by simp [specialize, hw, Shape.fields], rfl⟩
  | const =>
      obtain ⟨s,xs,ps,hs,hr,hi,hp,hm⟩ := shapes_cover hc' hq (.const) (compatible_extension ext hcompat) hm
      refine ⟨s,xs,ps,?_,hr,hi,hp,hm⟩
      apply mem_shapesWithView
      cases ‹Const› <;> simpa only [Const.type, shapes] using hs
  | list hx =>
      obtain ⟨s,xs,ps,hs,hr,hi,hp,hm⟩ := shapeStep_list (P := Q) (ctors := ctors') hq
        (compatible_extension ext hcompat) hx hm
      exact ⟨s,xs,ps,mem_shapesWithView view (by simpa only [shapes] using hs),hr,hi,hp,hm⟩
  | _ =>
      have hw : isWild q = true := by cases q <;> simp_all [compatible, isWild]
      exact ⟨.other, [], [], mem_shapesWithView view (by simp [shapes]), .other _, .nil,
        by simp [specialize, hw, Shape.fields], rfl⟩

/-- 追加後の値の特殊化を前提に、補題 U の燃料についての帰納法を一般化する。 -/
theorem usefulFuelWithView_extension_none_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView) (Q : Program)
    (cover : ∀ {ty column q v}, q ∈ column → Inhabits Q ty v →
      compatible P ty q = true → (Pat.matchVal q v).isSome = true →
      ∃ s xs ps, s ∈ shapesWithView P ctors view ty column ∧ Represents s v xs ∧
        InhabitsAll Q s.fields xs ∧ specialize q s = some ps ∧
        (Pat.matchList ps xs).isSome = true) (fuel : Nat) :
    ∀ tys rows q vs, (usefulFuelWithView P ctors view fuel tys rows q).witness = none →
      InhabitsAll Q tys vs → (Pat.matchList q vs).isSome = true →
      ∃ row ∈ rows, (Pat.matchList row vs).isSome = true := by
  induction fuel with
  | zero => intro tys rows q vs h; simp [usefulFuelWithView, fallback] at h
  | succ fuel ih =>
      intro tys matrix query vs h hv hq
      simp only [usefulFuelWithView] at h
      split at h
      · simp [fallback] at h
      · rename_i hlen
        have heq : tys.length = query.length := by simpa using hlen
        let rows0 := matrix.filter fun row => row.length == query.length && row.length == tys.length
        have hsub0 : ∀ r ∈ rows0, r ∈ matrix := fun r hr => (List.mem_filter.mp hr).1
        have hlen0 : ∀ r ∈ rows0, r.length = vs.length := by
          intro r hr
          have hh := (List.mem_filter.mp hr).2
          simp only [Bool.and_eq_true, beq_iff_eq] at hh
          exact hh.2.trans (inhabitsAll_length hv)
        cases tys with
        | nil =>
            cases hv
            cases query with
            | nil =>
                change (if rows0.isEmpty then (⟨some [], false⟩ : UsefulnessResult) else ⟨none, false⟩).witness = none at h
                have hn : rows0 ≠ [] := by intro he; simp [he] at h
                cases he : rows0 with
                | nil => exact False.elim (hn he)
                | cons r rs =>
                    have hmem : r ∈ rows0 := by rw [he]; simp
                    have hm : r ∈ matrix := hsub0 r hmem
                    have hl := hlen0 r hmem
                    have hr : r = [] := by simpa using hl
                    exact ⟨r, hm, by simp [hr, Pat.matchList]⟩
            | cons q qs => simp at heq
        | cons ty tys =>
            cases query with
            | nil => simp at heq
            | cons q qs =>
                cases hv with | @cons _ _ v vs hv hvs =>
                  simp only [matchList_cons, Bool.and_eq_true] at hq
                  change (if !compatible P ty q then fallback (q :: qs) else _).witness = none at h
                  split at h
                  · simp [fallback] at h
                  · rename_i hcompat
                    have hcompat' : compatible P ty q = true := by simpa using hcompat
                    let rows := rows0.filter fun row => row.head?.any (compatible P ty)
                    have hsub : ∀ r ∈ rows, r ∈ matrix := fun r hr => hsub0 r (List.mem_filter.mp hr).1
                    have hlength : ∀ r ∈ rows, r.length = vs.length + 1 := fun r hr => hlen0 r (List.mem_filter.mp hr).1
                    change (if rows.any (List.all · isWild) then (⟨none, false⟩ : UsefulnessResult) else _).witness = none at h
                    split at h
                    · rename_i hwild
                      obtain ⟨r, hr, hw⟩ := List.any_eq_true.mp hwild
                      exact ⟨r, hsub r hr, matchList_wild hw (by simpa using hlength r hr)⟩
                    · change (if rows.isEmpty then fallback (q :: qs) else _).witness = none at h
                      split at h
                      · simp [fallback] at h
                      · let column := rows.filterMap List.head? ++ [q]
                        change UsefulnessResult.witness (if column.all isWild then _ else _) = none at h
                        split at h
                        · rename_i hw
                          have hn : (usefulFuelWithView P ctors view fuel tys (rows.map List.tail) qs).witness = none := by
                            change ((usefulFuelWithView P ctors view fuel tys (rows.map List.tail) qs).witness.map
                              (CoverageWitness.wild :: ·)) = none at h
                            exact Option.map_eq_none_iff.mp h
                          obtain ⟨tail, ht, hm⟩ := ih tys (rows.map List.tail) qs _ hn hvs hq.2
                          obtain ⟨r, hr, rfl⟩ := List.mem_map.mp ht
                          cases r with
                          | nil => have hh := hlength [] hr; simp only [List.length_nil] at hh; omega
                          | cons p ps =>
                              have hp : p ∈ column := List.mem_append_left _ (List.mem_filterMap.mpr ⟨p :: ps, hr, rfl⟩)
                              have hpw := List.all_eq_true.mp hw p hp
                              have hmt : (Pat.matchList ps vs).isSome = true := by simpa only [List.tail_cons] using hm
                              exact ⟨p :: ps, hsub _ hr, by simp [matchVal_wild hpw, hmt]⟩
                        · let ss := shapesWithView P ctors view ty column
                          change (if !isWild q && !(ss.any fun s => (specialize q s).isSome) then fallback (q :: qs) else _).witness = none at h
                          split at h
                          · simp [fallback] at h
                          · obtain ⟨s, xs, args, hs, hr, hxs, hspec, hargs⟩ :=
                              cover (column := column) (by simp [column]) hv hcompat' hq.1
                            have hn := firstUseful_none h s hs
                            change (match specialize q s with
                              | none => (⟨none, false⟩ : UsefulnessResult)
                              | some args => _).witness = none at hn
                            rw [hspec] at hn
                            let r := usefulFuelWithView P ctors view fuel (s.fields ++ tys) (specializeRows s rows) (args ++ qs)
                            change (match r.witness with
                              | none => r
                              | some ws => if ws.length = s.fields.length + qs.length then
                                  { r with witness := some (s.witness (ws.take s.fields.length) :: ws.drop s.fields.length) }
                                else fallback (q :: qs) r.fuelExhausted).witness = none at hn
                            have hrec : r.witness = none := by
                              cases he : r.witness with
                              | none => rfl
                              | some ws =>
                                  rw [he] at hn
                                  dsimp only at hn
                                  split at hn <;> simp [fallback] at hn
                            have hqa : (Pat.matchList (args ++ qs) (xs ++ vs)).isSome = true := by
                              rw [matchList_append args qs xs vs (matchList_length hargs)]
                              simp [hargs, hq.2]
                            obtain ⟨r, hrr, hmatch⟩ := ih (s.fields ++ tys) (specializeRows s rows) (args ++ qs)
                              _ hrec (inhabitsAll_append hxs hvs) hqa
                            obtain ⟨r, hrr, hmatch⟩ := specializeRows_restore hr
                              (by intro r hr; have hl := hlength r hr; simpa using hl) hrr hmatch
                            exact ⟨r, hsub r hrr, hmatch⟩

end Coverage

/-- view 付きの成功は、許可された型の構成子を追加した後も網羅的である。
ctors' の完全性も明示し、空の型や入れ子・リストを除外しない。 -/
theorem usefulWithView_extension_exhaustive (P Q : Program)
    (ctors ctors' : DataName → List ConName) (view : CoverageView)
    (ext : ConstructorExtension P Q view) (hc : CtorsComplete P ctors)
    (hc' : CtorsComplete Q ctors') (a : Ty) (ps : List Pat)
    (h : usefulWithView P ctors view [a] (ps.map (fun p => [p])) [.wild] = none) :
    Exhaustive Q a ps := by
  intro v hv
  obtain ⟨row,hr,hm⟩ := Coverage.usefulFuelWithView_extension_none_sound P ctors view Q
    (Coverage.shapes_extension_cover ext hc hc') _ _ _ _ [v] h
    (.cons hv .nil) (by simp [Pat.matchList, Pat.matchVal])
  obtain ⟨p,hp,rfl⟩ := List.mem_map.mp hr
  exact ⟨p,hp,by simpa [Pat.matchList] using hm⟩

end Benitoite.Release
