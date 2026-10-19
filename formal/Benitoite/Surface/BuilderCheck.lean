import Benitoite.Surface.CheckSupport
import Benitoite.Surface.AdmissibleCheck
import Benitoite.Surface.SingleFailCheck

/-!
# 専用操作の参照先の有限検査

宣言と具体化後の型を検査し、参照先の契約を脱糖後の再検査へ委ねない。
対応する規則は設計書 01-12「構築器の専用操作と脱糖」である。
-/
namespace Benitoite.Surface
open Benitoite.Release CheckTools

mutual
  theorem builder_vars_rows {n pe t} (hc : TyOK n t) (hr : t.RowsIn pe) : t.VarsIn n pe := by
    cases t <;> simp only [TyOK, Ty.VarsIn] at hc ⊢ <;> simp only [Ty.RowsIn] at hr
    all_goals first | trivial | exact hc | exact False.elim hc | skip
    case data d ts => exact builder_varsList_rows hc hr
    case list t => exact builder_vars_rows hc hr
    case reference t => exact builder_vars_rows hc hr
    case lazy t => exact builder_vars_rows hc hr
    case set t => exact builder_vars_rows hc hr
    case dict c t => exact builder_vars_rows hc hr
    case fn ns ps r e => exact ⟨hc.1, builder_varsList_rows hc.2.1 hr.1,
      builder_vars_rows hc.2.2.1 hr.2.1, builder_eff_rows hc.2.2.2.1 hr.2.2, hc.2.2.2.2⟩
    case map a b => exact ⟨builder_vars_rows hc.1 hr.1, builder_vars_rows hc.2 hr.2⟩
    case tapp i ts => exact ⟨hc.1, builder_varsList_rows hc.2 hr⟩
  theorem builder_varsList_rows {n pe ts} (hc : Ty.VarsInList n (fun _ => True) ts)
      (hr : Ty.RowsInList pe ts) : Ty.VarsInList n pe ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨builder_vars_rows hc.1 hr.1, builder_varsList_rows hc.2 hr.2⟩
  theorem builder_eff_rows {n pe e} (hc : Eff.VarsIn n (fun _ => True) e)
      (hr : e.RowsIn pe) : Eff.VarsIn n pe e := by
    cases e with
    | mk a fs => exact ⟨hr.1, builder_varsList_rows hc.2 hr.2⟩
end

/-- 署名そのものの型変数と行の範囲を検査する。 -/
def builderSignatureCheck (atoms : List Atom) (nt ne : Nat) (ns : List String)
    (ps : List Ty) (ret : Ty) (eff : Eff) : Bool :=
  namesWF ns ps && cleanTys atoms nt ps && cleanTy atoms nt ret &&
    cleanTys atoms nt eff.fails && rowsTysCheck atoms ne ps &&
    rowsTyCheck atoms ne ret && rowsEffCheck atoms ne eff

theorem builderSignatureCheck_sound {atoms nt ne ns ps ret eff}
    (ha : Ty.AtomsIn atoms (.fn ns ps ret eff))
    (h : builderSignatureCheck atoms nt ne ns ps ret eff = true) :
    NamesWF ns ps ∧ Ty.VarsInList nt (· < ne) ps ∧ ret.VarsIn nt (· < ne) ∧ Eff.VarsIn nt (· < ne) eff := by
  simp only [builderSignatureCheck, Bool.and_eq_true_iff] at h
  obtain ⟨⟨⟨⟨⟨⟨hn, hp⟩, hr⟩, hf⟩, hpr⟩, hrr⟩, her⟩ := h
  have hfc := (cleanTys_spec nt (Eff.fails eff) (by cases eff; exact ha.2.2.2)).mp hf
  have hec : Eff.VarsIn nt (fun _ => True) eff := by
    cases eff
    exact ⟨fun _ _ => trivial, hfc⟩
  exact ⟨(namesWF_spec _ _).mp hn,
    builder_varsList_rows ((cleanTys_spec nt ps ha.1).mp hp) ((rowsTysCheck_spec ne ps ha.1).mp hpr),
    builder_vars_rows ((cleanTy_spec nt ret ha.2.1).mp hr) ((rowsTyCheck_spec ne ret ha.2.1).mp hrr),
    builder_eff_rows hec ((rowsEffCheck_spec ne eff ha.2.2).mp her)⟩

/-- セルの操作も通常関数も、行を持たない宣言に限る。 -/
def BuilderPrimRef.check (atoms : List Atom) (B : Builtins) (ad : AdmitsDec)
    (nf : List Bool) (C : List TParam) (r : BuilderPrimRef) (kind : PrimKind)
    (names : List String) (ps : List Ty) (ret : Ty) (eff : Eff) : Bool :=
  match B.sig r.name with
  | none => false
  | some s =>
      decide (s.kind = kind) && decide (s.neffs = 0) &&
      builderSignatureCheck atoms s.ntys s.neffs s.names s.params s.ret s.eff &&
      decide (r.types.length = s.ntys) && cleanTys atoms C.length r.types && ad r.name C r.types &&
      singleTyCheck atoms nf (fnTyCheck atoms s.names s.params s.ret s.eff r.types []) &&
      tyEq atoms (fnTyCheck atoms s.names s.params s.ret s.eff r.types []) (.fn names ps ret eff)

theorem BuilderPrimRef.check_sound {atoms} {B : Builtins} {ad nf C} {r : BuilderPrimRef} {kind names ps ret eff}
    (hB : B.AtomsIn atoms) (had : AdmitsDecSound B ad)
    (ht : Tys.AtomsIn atoms r.types) (hout : Ty.AtomsIn atoms (.fn names ps ret eff))
    (h : r.check atoms B ad nf C kind names ps ret eff = true) :
    r.Ok B C (NoFailCtxOf nf) kind names ps ret eff := by
  cases hs : B.sig r.name with
  | none => simp [BuilderPrimRef.check, hs] at h
  | some s =>
      simp only [BuilderPrimRef.check, hs, Bool.and_eq_true_iff, decide_eq_true_eq] at h
      obtain ⟨⟨⟨⟨⟨⟨⟨hk, he⟩, hsc⟩, hn⟩, hts⟩, ha⟩, hsingle⟩, hshape⟩ := h
      have has := hB r.name s hs
      have hscope := builderSignatureCheck_sound has hsc
      have hai := fnTyCheck_atoms (names := s.names) (es := []) has.1 has.2.1 has.2.2 ht (by simp)
      have hi := fnTyCheck_eq s.names s.params s.ret s.eff r.types []
        (tysAtoms_iff.mp ht) (by simp) has.1 has.2.1 has.2.2
      have hclean := (cleanTys_spec C.length r.types ht).mp hts
      refine ⟨s, hs, hk, hscope.1, hscope, he, hn, ?_, had _ _ _ _ hs ha, ?_, ?_⟩
      · intro t hm
        have hc := Ty.VarsInList.iff.mp hclean t hm
        exact ⟨Ty.VarsIn.wf _ hc, by intro b a e heq; subst t; exact hc⟩
      · rw [← hi]; exact (singleTyCheck_spec _ hai).mp hsingle
      · rw [← hi]; exact tyEq_sound hai hout hshape

/-- 純粋な参照先は組み込み、または辞書引数のない通常関数である。 -/
def BuilderPureRef.check (atoms : List Atom) (D : Declarations) (B : Builtins)
    (sd : SatDec) (ad : AdmitsDec) (nf : List Bool) (C : List TParam)
    (r : BuilderPureRef) (names : List String) (ps : List Ty) (ret : Ty) : Bool :=
  match r with
  | .prim r => r.check atoms B ad nf C .pure names ps ret Eff.empty
  | .funRef f ts => match D.funs f with
    | none => false
    | some d => d.dictParams.isEmpty && decide (d.neffs = 0) &&
        builderSignatureCheck atoms d.tparams.length d.neffs d.names d.params d.ret d.eff &&
        decide (ts.length = d.tparams.length) && cleanTys atoms C.length ts && satAll sd C ts d.tparams &&
        singleTyCheck atoms nf (fnTyCheck atoms d.names d.params d.ret d.eff ts []) &&
        tyEq atoms (fnTyCheck atoms d.names d.params d.ret d.eff ts []) (.fn names ps ret Eff.empty)

theorem BuilderPureRef.check_sound {atoms} {D : Declarations} {B : Builtins} {sd ad nf C} {r : BuilderPureRef} {names ps ret}
    (hD : D.AtomsIn atoms) (hB : B.AtomsIn atoms)
    (hsd : SatDecSound B sd) (had : AdmitsDecSound B ad)
    (ht : builderValAtoms atoms r.toVal) (hout : Ty.AtomsIn atoms (.fn names ps ret Eff.empty))
    (h : r.check atoms D B sd ad nf C names ps ret = true) :
    r.Ok D B C (NoFailCtxOf nf) names ps ret := by
  cases r with
  | prim r => exact BuilderPrimRef.check_sound hB had ht hout h
  | funRef f ts =>
      cases hd : D.funs f with
      | none => simp [BuilderPureRef.check, hd] at h
      | some d =>
          simp only [BuilderPureRef.check, hd, Bool.and_eq_true_iff, decide_eq_true_eq] at h
          obtain ⟨⟨⟨⟨⟨⟨⟨hdict, he⟩, hsc⟩, hn⟩, hts⟩, ha⟩, hsingle⟩, hshape⟩ := h
          have has := (hD.1 f d hd).1
          have hscope := builderSignatureCheck_sound has hsc
          have hai := fnTyCheck_atoms (names := d.names) (es := []) has.1 has.2.1 has.2.2 ht (by simp)
          have hi := fnTyCheck_eq d.names d.params d.ret d.eff ts []
            (tysAtoms_iff.mp ht) (by simp) has.1 has.2.1 has.2.2
          have hclean := (cleanTys_spec C.length ts ht).mp hts
          refine ⟨d, hd, hscope.1, List.isEmpty_iff.mp hdict, hscope, he, hn, ?_,
            satAll_sound hsd ha, ?_, ?_⟩
          · intro t hm
            have hc := Ty.VarsInList.iff.mp hclean t hm
            exact ⟨Ty.VarsIn.wf _ hc, by intro b a e heq; subst t; exact hc⟩
          · rw [← hi]; exact (singleTyCheck_spec _ hai).mp hsingle
          · rw [← hi]; exact tyEq_sound hai hout hshape

/-- セルの三参照は同じ型引数を持つ。 -/
def BuilderCellRefs.check (atoms : List Atom) (B : Builtins) (ad : AdmitsDec)
    (nf : List Bool) (C : List TParam) (k : BuilderKind) (r : BuilderCellRefs) : Bool :=
  tysEq atoms r.newRef.types [k.contents] && tysEq atoms r.getRef.types [k.contents] &&
  tysEq atoms r.setRef.types [k.contents] &&
  r.newRef.check atoms B ad nf C .refNew ["value"] [k.contents] k.cell (Eff.single stateEff) &&
  r.getRef.check atoms B ad nf C .refGet ["reference"] [k.cell] k.contents (Eff.single stateEff) &&
  r.setRef.check atoms B ad nf C .refSet ["reference", "value"] [k.cell, k.contents] (.base .unit) (Eff.single stateEff)

theorem BuilderCellRefs.check_sound {atoms B ad nf C k} {r : BuilderCellRefs}
    (hB : B.AtomsIn atoms) (had : AdmitsDecSound B ad)
    (hk : Ty.AtomsIn atoms k.contents) (he : Eff.AtomsIn atoms (Eff.single stateEff))
    (ht : builderValAtoms atoms r.newRef.toVal ∧ builderValAtoms atoms r.getRef.toVal ∧ builderValAtoms atoms r.setRef.toVal)
    (h : r.check atoms B ad nf C k = true) : r.Ok B C (NoFailCtxOf nf) k := by
  simp only [BuilderCellRefs.check, Bool.and_eq_true_iff] at h
  obtain ⟨⟨⟨⟨⟨hn, hg⟩, hs⟩, hnew⟩, hget⟩, hset⟩ := h
  exact ⟨tysEq_sound ht.1 ⟨hk, trivial⟩ hn, tysEq_sound ht.2.1 ⟨hk, trivial⟩ hg,
    tysEq_sound ht.2.2 ⟨hk, trivial⟩ hs,
    BuilderPrimRef.check_sound hB had ht.1 ⟨⟨hk, trivial⟩, hk, he⟩ hnew,
    BuilderPrimRef.check_sound hB had ht.2.1 ⟨⟨hk, trivial⟩, hk, he⟩ hget,
    BuilderPrimRef.check_sound hB had ht.2.2 ⟨⟨hk, hk, trivial⟩, trivial, he⟩ hset⟩

/-- 種類別の純粋操作をすべて検査する。 -/
def BuilderRefs.checkPure (atoms : List Atom) (D : Declarations) (B : Builtins)
    (sd : SatDec) (ad : AdmitsDec) (nf : List Bool) (C : List TParam) : BuilderRefs → Bool
  | .string _ add join len =>
      add.check atoms D B sd ad nf C ["left", "right"] [.base .string, .base .string] (.base .string) &&
      join.check atoms D B sd ad nf C ["xs", "separator"] [.list (.base .string), .base .string] (.base .string) &&
      len.check atoms D B sd ad nf C ["s"] [.base .string] (.base .integer)
  | .list t _ append cat len =>
      append.check atoms D B sd ad nf C ["xs", "x"] [.list t, t] (.list t) &&
      cat.check atoms D B sd ad nf C ["xs", "ys"] [.list t, .list t] (.list t) &&
      len.check atoms D B sd ad nf C ["xs"] [.list t] (.base .integer)
  | .bytes _ empty fromList cat len =>
      empty.check atoms D B sd ad nf C [] [] .bytes &&
      fromList.check atoms D B sd ad nf C ["bs"] [.list (.base .byte)] .bytes &&
      cat.check atoms D B sd ad nf C ["a", "b"] [.bytes, .bytes] .bytes &&
      len.check atoms D B sd ad nf C ["b"] [.bytes] (.base .integer)

theorem BuilderRefs.checkPure_sound {atoms} {D : Declarations} {B : Builtins} {sd ad nf C} {r : BuilderRefs}
    (hD : D.AtomsIn atoms) (hB : B.AtomsIn atoms)
    (hsd : SatDecSound B sd) (had : AdmitsDecSound B ad)
    (hk : Ty.AtomsIn atoms r.kind.contents) (ht : r.ForRefs (builderValAtoms atoms))
    (h : r.checkPure atoms D B sd ad nf C = true) : r.PureOk D B C (NoFailCtxOf nf) := by
  cases r with
  | string c add join len =>
      have h := Bool.and_eq_true_iff.mp h
      exact ⟨BuilderPureRef.check_sound hD hB hsd had ht.2.1 (by simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]) (Bool.and_eq_true_iff.mp h.1).1,
        BuilderPureRef.check_sound hD hB hsd had ht.2.2.1 (by simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]) (Bool.and_eq_true_iff.mp h.1).2,
        BuilderPureRef.check_sound hD hB hsd had ht.2.2.2 (by simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]) h.2⟩
  | list t c append cat len =>
      have h := Bool.and_eq_true_iff.mp h
      exact ⟨BuilderPureRef.check_sound hD hB hsd had ht.2.1 ⟨⟨hk, hk, trivial⟩, hk, emptyEff_atoms _⟩ (Bool.and_eq_true_iff.mp h.1).1,
        BuilderPureRef.check_sound hD hB hsd had ht.2.2.1 ⟨⟨hk, hk, trivial⟩, hk, emptyEff_atoms _⟩ (Bool.and_eq_true_iff.mp h.1).2,
        BuilderPureRef.check_sound hD hB hsd had ht.2.2.2 ⟨⟨hk, trivial⟩, trivial, emptyEff_atoms _⟩ h.2⟩
  | bytes c empty fromList cat len =>
      have h := Bool.and_eq_true_iff.mp h
      have h' := Bool.and_eq_true_iff.mp h.1
      exact ⟨BuilderPureRef.check_sound hD hB hsd had ht.2.1 (by simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]) (Bool.and_eq_true_iff.mp h'.1).1,
        BuilderPureRef.check_sound hD hB hsd had ht.2.2.1 (by simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]) (Bool.and_eq_true_iff.mp h'.1).2,
        BuilderPureRef.check_sound hD hB hsd had ht.2.2.2.1 (by simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]) h'.2,
        BuilderPureRef.check_sound hD hB hsd had ht.2.2.2.2 (by simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]) h.2⟩

/-- 内容の型は三種類を区別し、分類の比較にも使える。 -/
theorem BuilderKind.contents_injective {k l : BuilderKind} (h : k.contents = l.contents) : k = l := by
  cases k <;> cases l <;> simp_all [BuilderKind.contents]

/-- 専用位置との一致を先に検査し、参照先の宣言を照合する。 -/
def BuilderRefs.check (atoms : List Atom) (D : Declarations) (B : Builtins)
    (sd : SatDec) (ad : AdmitsDec) (nf : List Bool) (C : List TParam)
    (Δ : BuilderCtx) (i : Nat) (r : BuilderRefs) : Bool :=
  match Δ.kindAt i with
  | none => false
  | some k => tyEq atoms k.contents r.kind.contents &&
      r.cells.check atoms B ad nf C r.kind && r.checkPure atoms D B sd ad nf C

theorem BuilderRefs.check_sound {atoms} {D : Declarations} {B : Builtins} {sd ad nf C Δ i} {r : BuilderRefs}
    (hD : D.AtomsIn atoms) (hB : B.AtomsIn atoms)
    (hsd : SatDecSound B sd) (had : AdmitsDecSound B ad)
    (hΔ : BuilderCtx.AtomsIn atoms Δ)
    (hk : Ty.AtomsIn atoms r.kind.contents) (ht : r.ForRefs (builderValAtoms atoms))
    (he : Eff.AtomsIn atoms (Eff.single stateEff))
    (h : r.check atoms D B sd ad nf C Δ i = true) : r.Ok D B C (NoFailCtxOf nf) Δ i := by
  cases hi : Δ.kindAt i with
  | none => simp [BuilderRefs.check, hi] at h
  | some k =>
      simp only [BuilderRefs.check, hi, Bool.and_eq_true_iff] at h
      have heq := BuilderKind.contents_injective (tyEq_sound (hΔ i k hi) hk h.1.1)
      subst k
      exact ⟨hi, BuilderCellRefs.check_sound hB had hk he ht.1 h.1.2,
        BuilderRefs.checkPure_sound hD hB hsd had hk ht h.2⟩

/-- 操作の契約内にある支持は、内容の型から得られる。 -/
theorem BuilderOp.params_atoms {k : BuilderKind} {atoms} (o : BuilderOp)
    (h : Ty.AtomsIn atoms k.contents) : Tys.AtomsIn atoms (o.params k) := by
  cases o <;> cases k <;> simp_all [BuilderOp.params, BuilderKind.item, BuilderKind.contents, Ty.SupportList, Ty.Support]

theorem BuilderOp.result_atoms {k : BuilderKind} {atoms} (o : BuilderOp)
    (h : Ty.AtomsIn atoms k.contents) : Ty.AtomsIn atoms (o.result k) := by
  cases o <;> first | exact h | trivial

end Benitoite.Surface
