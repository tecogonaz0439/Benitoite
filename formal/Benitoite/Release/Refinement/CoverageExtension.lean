import Benitoite.Release.Refinement.Coverage

/-! 設計書 01-12「網羅性」の構成子を追加した後の網羅性。現在の実行の定理とは分ける。 -/
namespace Benitoite.Release.Refinement

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
      | none => simp [compatible, Ty.core, isWild, hc] at h
      | some fields =>
        have he : conFields Q d ts c = some fields := by
          unfold conFields at hc ⊢
          cases hp : P.cons c with
          | none => simp [hp] at hc
          | some cd => simpa [hp, ext.preserve c cd hp] using hc
        simpa [compatible, Ty.core, isWild, hc, he] using h
    | _ => simpa only [compatible, Ty.core, isWild] using h
  | refined a p => exact compatible_extension ext (ty := a) h
  | base b =>
    cases q with
    | const c => cases b <;> cases c <;> simp_all [compatible, Ty.core, isWild]
    | range lo hi => cases b <;> cases lo <;> cases hi <;> simp_all [compatible, Ty.core, isWild]
    | _ => simpa only [compatible, Ty.core, isWild] using h
  | _ => cases q <;> simpa only [compatible, Ty.core, isWild] using h

/-- 新しい構成子は future で表す。既存の構成子の欄は Q の値として再帰する。 -/
theorem shapes_extension_cover {P Q : Program} {ctors : DataName → List ConName}
    {view : CoverageView} (ext : ConstructorExtension P Q view)
    (hc : CtorsComplete P ctors)
    {ty : Ty} {column : List Pat} {q : Pat} {v : Val}
    (hq : q ∈ column) (hv : Inhabits Q ty v)
    (hcompat : compatible P ty q = true) (hm : (matchVal q v).isSome = true) :
    ∃ s xs ps, s ∈ shapesWithView P ctors view ty column ∧ Represents s v xs ∧
      InhabitsAll Q s.fields xs ∧ specialize q s = some ps ∧
      (matchList ps xs).isSome = true := by
  cases hv with
  | @con c ts tys xs cd hd hn _ hx =>
    cases hp : P.cons c with
    | some old =>
      have he := ext.preserve c old hp
      have eq : old = cd := Option.some.inj (he.symm.trans hd)
      subst old
      let fields := substTys ts cd.args
      have hf : conFields P cd.data ts c = some fields := by simp [conFields, hp, hn, fields]
      have hi : InhabitsAll Q fields xs := by
        apply inhabitsAll_of_norm
        simpa only [fields, substTys, List.map_map, Function.comp_def, substTy_norm] using hx
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
      simp only [matchVal] at hm
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
        simp only [matchVal] at hm
        split at hm
        · rename_i he
          subst d
          simp [conFields, hp] at hcompat
        · simp_all
      have hs : Shape.future cd.data ∈ shapesWithView P ctors view (.data cd.data ts) column := by
        simp [shapesWithView, ext.added c cd hd hp]
      exact ⟨_, [], [], hs, .future _ _, .nil, by simp [specialize, hw, Shape.fields], rfl⟩
  | @const c =>
      obtain ⟨s,xs,ps,hs,hr,_,hp,hm⟩ := shapes_cover hc hq (Inhabits.const (P := P) (c := c)) hcompat hm
      refine ⟨s,xs,ps,mem_shapesWithView view hs,hr,?_,hp,hm⟩
      cases hr <;> exact .nil
  | list hx =>
      obtain ⟨s,xs,ps,hs,hr,hi,hp,hm⟩ := shapeStep_list (P := Q) (ctors := ctors) hq
        (compatible_extension ext hcompat) hx hm
      exact ⟨s,xs,ps,mem_shapesWithView view (by simpa only [shapes, Ty.core] using hs),hr,hi,hp,hm⟩
  | @refined a φ v hv _ => exact shapes_extension_cover (ty := a) ext hc hq hv hcompat hm
  | @atError detail herr =>
      obtain ⟨_, _, ⟨cd, hd, hdata, hn, hargs⟩, hp⟩ := herr
      have hi : InhabitsAll Q atErrorFields detail.values := Detail.values_inhabits hp detail
      cases hP : P.cons "Scope.ScopeError.At" with
      | some old =>
          have hold : old = cd := Option.some.inj ((ext.preserve _ _ hP).symm.trans hd)
          subst old
          have hf : conFields P "Scope.ScopeError" [] "Scope.ScopeError.At" = some atErrorFields := by
            simp [conFields, hP, hdata, hn, hargs, substTys, substTy, atErrorFields,
              atDetailType, Ty.rawBind, rawBindTys]
          have hs : Shape.con "Scope.ScopeError.At" atErrorFields ∈
              shapesWithView P ctors view atErrorType column := by
            apply mem_shapesWithView
            apply List.mem_map.mpr
            exact ⟨_, by simpa only [hdata] using hc _ _ hP, by simp [hf]⟩
          have hr : Represents (.con "Scope.ScopeError.At" atErrorFields) (.atError detail) detail.values :=
            .atError _ _ (by simp [atErrorFields, Detail.values])
          by_cases hw : isWild q = true
          · obtain ⟨ps, hp, hm⟩ := specialize_wild hw hr
            exact ⟨_, _, ps, hs, hr, hi, hp, hm⟩
          have hw' : isWild q = false := by cases he : isWild q <;> simp_all
          cases q <;> simp [isWild, compatible, atErrorType, Ty.core] at hcompat hw'
          rename_i c ps
          simp only [matchVal] at hm
          split at hm
          · rename_i he
            subst c
            have hl : ps.length = atErrorFields.length := (matchList_length hm).trans hr.length.symm
            exact ⟨_, _, ps, hs, hr, hi, by simp [specialize, isWild, hl], hm⟩
          · simp_all
      | none =>
          have hw : isWild q = true := by
            by_cases hw : isWild q = true
            · exact hw
            have hw' : isWild q = false := by cases he : isWild q <;> simp_all
            exfalso
            cases q <;> simp [isWild, compatible, atErrorType, Ty.core] at hcompat hw'
            rename_i c ps
            simp only [matchVal] at hm
            split at hm
            · rename_i he
              subst c
              simp [conFields, hP] at hcompat
            · simp_all
          have hview : view "Scope.ScopeError" = true := hdata ▸ ext.added _ _ hd hP
          have hs : Shape.future "Scope.ScopeError" ∈ shapesWithView P ctors view atErrorType column := by
            simp [shapesWithView, atErrorType, hview]
          exact ⟨_, [], [], hs, .future _ _, .nil, by simp [specialize, hw, Shape.fields], rfl⟩
  | _ =>
      have hw : isWild q = true := by cases q <;> simp_all [compatible, Ty.core, isWild]
      exact ⟨.other, [], [], mem_shapesWithView view (by simp [shapes, Ty.core]), .other _, .nil,
        by simp [specialize, hw, Shape.fields], rfl⟩

termination_by sizeOf ty
decreasing_by
  simp_all
  omega

end Coverage

/-- 特定の問いの照合は、宣言を保つ任意の拡張先でも、元の行列の照合へ戻せる。 -/
theorem usefulWithView_extension_singleton_none_sound (P Q : Program)
    (ctors : DataName → List ConName) (view : CoverageView)
    (ext : ConstructorExtension P Q view) (hc : CtorsComplete P ctors)
    (a : Ty) (ps : List Pat) (q : Pat)
    (h : usefulWithView P ctors view [a] (ps.map (fun p => [p])) [q] = none)
    (v : Val) (hv : Inhabits Q a v) (hq : (matchVal q v).isSome = true) :
    ∃ p ∈ ps, (matchVal p v).isSome = true := by
  obtain ⟨row, hr, hm⟩ := Coverage.usefulFuelWithView_none_sound_of_cover P ctors view Q
    (Coverage.shapes_extension_cover ext hc) _ _ _ _ [v] h
    (.cons hv .nil) (by simpa [matchList] using hq)
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hr
  exact ⟨p, hp, by simpa [matchList] using hm⟩

/-- view 付きの成功は、許可された型の構成子を追加した後も網羅的である。
拡張先の構成子の有限な一覧を前提にせず、空の型や入れ子・リストを含む。 -/
theorem usefulWithView_extension_exhaustive (P Q : Program)
    (ctors : DataName → List ConName) (view : CoverageView)
    (ext : ConstructorExtension P Q view) (hc : CtorsComplete P ctors)
    (a : Ty) (ps : List Pat)
    (h : usefulWithView P ctors view [a] (ps.map (fun p => [p])) [.wild] = none) :
    Exhaustive Q a ps := by
  intro v hv
  exact usefulWithView_extension_singleton_none_sound P Q ctors view ext hc a ps .wild h
    v ((Inhabits.norm_all_iff a v).mp hv) rfl

end Benitoite.Release.Refinement
