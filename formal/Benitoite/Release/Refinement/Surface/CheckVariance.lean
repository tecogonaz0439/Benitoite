import Benitoite.Release.Refinement.Surface.CheckFormation
import Benitoite.Release.Refinement.VarianceValidation

/-!
# 宣言の変性の有限検査

宣言した変性と、全構成子の欄・制約・公開境界の構文上の出現を照合する。出現しない型引数は不変だけを受理する。
型付けや単調性を入力の信頼条件にしない（設計書 01-12「data の変性」）。
-/
namespace Benitoite.Release.Refinement.Surface.CheckVariance

instance varianceAcceptsDecidable (v : Variance) (p : Polarity) : Decidable (v.accepts p) := by
  cases v <;> cases p <;> unfold Variance.accepts <;> infer_instance

def parameterAccepts (vs : List Variance) (i : Nat) (p : Polarity) : Bool :=
  match vs[i]? with
  | none => false
  | some v => decide (v.accepts p)

theorem parameterAccepts_spec (vs : List Variance) (i : Nat) (p : Polarity) :
    parameterAccepts vs i p = true ↔ ∃ v, vs[i]? = some v ∧ v.accepts p := by
  unfold parameterAccepts
  cases vs[i]? <;> simp

mutual
  def ty (P : Refinement.Program) (vs : List Variance) (p : Polarity) : Ty → Bool
    | .tvar i => parameterAccepts vs i p
    | .data d as => args P vs p (P.varianceFor d as.length) as
    | .list a | .lazy a => ty P vs p a
    | .fn _ ps r e => tys P vs p.flip ps && (ty P vs p r && eff P vs p e)
    | .map k a => ty P vs .both k && ty P vs p a
    | .reference a | .set a | .dict _ a => ty P vs .both a
    | .cont a b e => ty P vs .both a && (ty P vs .both b && eff P vs .both e)
    | .tapp i as => parameterAccepts vs i .both && tys P vs .both as
    | .external _ as => tys P vs .both as
    | .refined a _ => ty P vs p a
    | .dependentFn t => tel P vs p t
    | _ => true
  def tel (P : Refinement.Program) (vs : List Variance) (p : Polarity) : Tel → Bool
    | .done r e => ty P vs p r && eff P vs p e
    | .param _ a t => ty P vs p.flip a && tel P vs p t
  def eff (P : Refinement.Program) (vs : List Variance) (_p : Polarity) : Eff → Bool
    | .mk _ fs => tys P vs .both fs
  def tys (P : Refinement.Program) (vs : List Variance) (p : Polarity) : List Ty → Bool
    | [] => true
    | a :: as => ty P vs p a && tys P vs p as
  def args (P : Refinement.Program) (vs : List Variance) (p : Polarity) : List Variance → List Ty → Bool
    | [], [] => true
    | v :: vs', a :: as => ty P vs (p.compose v) a && args P vs p vs' as
    | _, _ => false
end

mutual
  theorem ty_spec (P : Refinement.Program) (vs : List Variance) (p : Polarity) (a : Ty) :
      ty P vs p a = true ↔ a.VarianceOK P vs p := by
    cases a <;> simp only [ty, Ty.VarianceOK, Bool.and_eq_true, 
      parameterAccepts_spec, ty_spec, tel_spec, eff_spec, tys_spec, args_spec]
  theorem tel_spec (P : Refinement.Program) (vs : List Variance) (p : Polarity) (t : Tel) :
      tel P vs p t = true ↔ t.VarianceOK P vs p := by
    cases t <;> simp only [tel, Tel.VarianceOK, Bool.and_eq_true, ty_spec, tel_spec, eff_spec]
  theorem eff_spec (P : Refinement.Program) (vs : List Variance) (p : Polarity) (e : Eff) :
      eff P vs p e = true ↔ e.VarianceOK P vs p := by
    cases e
    exact tys_spec P vs .both _
  theorem tys_spec (P : Refinement.Program) (vs : List Variance) (p : Polarity) (as : List Ty) :
      tys P vs p as = true ↔ varianceTysOK P vs p as := by
    cases as <;> simp only [tys, varianceTysOK, Bool.and_eq_true, ty_spec, tys_spec]
  theorem args_spec (P : Refinement.Program) (vs : List Variance) (p : Polarity)
      (variance : List Variance) (as : List Ty) :
      args P vs p variance as = true ↔ varianceArgsOK P vs p variance as := by
    cases variance <;> cases as <;>
      simp only [args, varianceArgsOK, Bool.and_eq_true, Bool.false_eq_true, ty_spec, args_spec]
end

mutual
  def paramOccurs (i : Nat) : Ty → Bool
    | .tvar j => decide (i = j)
    | .tapp j as => decide (i = j) || paramsOccur i as
    | .data _ as | .external _ as => paramsOccur i as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => paramOccurs i a
    | .fn _ ps r e => paramsOccur i ps || (paramOccurs i r || paramOccursEff i e)
    | .cont a b e => paramOccurs i a || (paramOccurs i b || paramOccursEff i e)
    | .map a b => paramOccurs i a || paramOccurs i b
    | .dependentFn t => paramOccursTel i t
    | _ => false
  def paramsOccur (i : Nat) : List Ty → Bool
    | [] => false
    | a :: as => paramOccurs i a || paramsOccur i as
  def paramOccursEff (i : Nat) : Eff → Bool
    | .mk _ fs => paramsOccur i fs
  def paramOccursTel (i : Nat) : Tel → Bool
    | .done r e => paramOccurs i r || paramOccursEff i e
    | .param _ a t => paramOccurs i a || paramOccursTel i t
end

mutual
  theorem paramOccurs_spec (i : Nat) (a : Ty) : paramOccurs i a = true ↔ a.ParamOccurs i := by
    cases a <;> simp only [paramOccurs, Ty.ParamOccurs, Bool.or_eq_true, Bool.false_eq_true,
      decide_eq_true_eq, paramOccurs_spec, paramsOccur_spec, paramOccursEff_spec, paramOccursTel_spec]
  theorem paramsOccur_spec (i : Nat) (as : List Ty) : paramsOccur i as = true ↔ Refinement.paramsOccur i as := by
    cases as <;> simp only [paramsOccur, Refinement.paramsOccur, Bool.or_eq_true, Bool.false_eq_true,
      paramOccurs_spec, paramsOccur_spec]
  theorem paramOccursEff_spec (i : Nat) (e : Eff) : paramOccursEff i e = true ↔ e.ParamOccurs i := by
    cases e
    exact paramsOccur_spec i _
  theorem paramOccursTel_spec (i : Nat) (t : Tel) : paramOccursTel i t = true ↔ t.ParamOccurs i := by
    cases t <;> simp only [paramOccursTel, Tel.ParamOccurs, Bool.or_eq_true,
      paramOccurs_spec, paramOccursEff_spec, paramOccursTel_spec]
end

def CtorsComplete (P : Refinement.Program) (names : List ConName) : Prop :=
  ∀ c cd, P.cons c = some cd → c ∈ names

def DataComplete (P : Refinement.Program) (names : List DataName) : Prop :=
  ∀ d info, P.dataInfo d = some info → d ∈ names

/-- 構成子の実際の lookup と所属する data 名を照合し、欄の全てを調べる。 -/
def occursInFields (P : Refinement.Program) (names : List ConName) (d : DataName) (i : Nat) : Bool :=
  names.any fun c => match P.cons c with
    | none => false
    | some cd => decide (cd.data = d) && cd.args.any (paramOccurs i)

theorem occursInFields_spec {P names d i} (hn : CtorsComplete P names) :
    occursInFields P names d i = true ↔ P.ParamOccursInFields d i := by
  simp only [occursInFields, List.any_eq_true]
  constructor
  · rintro ⟨c, _, h⟩
    split at h
    · cases h
    · rename_i cd hc
      obtain ⟨he, ha⟩ := Bool.and_eq_true_iff.mp h
      obtain ⟨a, hmem, ho⟩ := List.any_eq_true.mp ha
      exact ⟨c, cd, a, hc, of_decide_eq_true he, hmem, (paramOccurs_spec i a).mp ho⟩
  · rintro ⟨c, cd, a, hc, hd, ha, ho⟩
    refine ⟨c, hn c cd hc, ?_⟩
    simp only [hc, Bool.and_eq_true, decide_eq_true_eq]
    exact ⟨hd, List.any_eq_true.mpr ⟨a, ha, (paramOccurs_spec i a).mpr ho⟩⟩

/-- 非出現の位置を不変として検査する。位置の番号は列を一つ進めるごとに一つ増やす。 -/
def unusedParameters (P : Refinement.Program) (ctors : List ConName) (d : DataName) : Nat → List Variance → Bool
  | _, [] => true
  | offset, v :: vs => (occursInFields P ctors d offset || decide (v = .invariant)) &&
      unusedParameters P ctors d (offset + 1) vs

theorem unusedParameters_sound {P ctors d offset vs} (hn : CtorsComplete P ctors)
    (h : unusedParameters P ctors d offset vs = true) :
    ∀ i v, vs[i]? = some v → ¬ P.ParamOccursInFields d (offset + i) → v = .invariant := by
  induction vs generalizing offset with
  | nil => intro i v hi; simp at hi
  | cons v vs ih =>
    have hh := Bool.and_eq_true_iff.mp h
    intro i variance hi hnone
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      subst variance
      rcases Bool.or_eq_true_iff.mp hh.1 with ho | hv
      · exact (hnone (by simpa only [Nat.add_zero] using (occursInFields_spec hn).mp ho)).elim
      · exact of_decide_eq_true hv
    | succ i =>
      apply ih hh.2 i variance hi
      simpa only [Nat.succ_eq_add_one, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hnone

/-- metadata の全欄を検査する。型引数の非出現も欄の実際の構文で判定する。 -/
def metadata (P : Refinement.Program) (ctors : List ConName) (d : DataName) (info : DataVarianceDecl) : Bool :=
  decide (info.variances.length = info.arity) &&
    (unusedParameters P ctors d 0 info.variances &&
      (info.requirements.all (ty P info.variances .both) &&
        info.publicBoundary.all (fun item => ty P info.variances item.1 item.2)))

theorem metadata_sound {P ctors d info} (hn : CtorsComplete P ctors)
    (h : metadata P ctors d info = true) :
    info.variances.length = info.arity ∧
      (∀ i v, info.variances[i]? = some v → (¬ P.ParamOccursInFields d i → v = .invariant)) ∧
      (∀ a ∈ info.requirements, Ty.VarianceOK P info.variances .both a) ∧
      (∀ item ∈ info.publicBoundary, Ty.VarianceOK P info.variances item.1 item.2) := by
  simp only [metadata, Bool.and_eq_true, decide_eq_true_eq] at h
  refine ⟨h.1, ?_, ?_, ?_⟩
  · intro i v hv hnone
    exact unusedParameters_sound hn h.2.1 i v hv (by simpa using hnone)
  · intro a ha
    exact (ty_spec P info.variances .both a).mp (List.all_eq_true.mp h.2.2.1 a ha)
  · intro item hi
    exact (ty_spec P info.variances item.1 item.2).mp (List.all_eq_true.mp h.2.2.2 item hi)

/-- 構成子の全欄に形成・kind・正の位置の変性を要求する。 -/
def constructor (q : CheckFormation.Input) (P : Refinement.Program) (path : List Nat) (cd : ConDecl) : Bool :=
  (match P.dataInfo cd.data with | none => true | some info => decide (info.arity = cd.ntys)) &&
    cd.args.all (fun a => CheckFormation.annotation q P (List.replicate cd.ntys TypeCtx.valueParam) [] path a &&
      (CheckFormation.kindTy q P (List.replicate cd.ntys .value) a .value &&
        ty P (P.varianceFor cd.data cd.ntys) .positive a))

theorem constructor_sound {q P path cd} (hq : q.Sound P)
    (hs : Ty.SupportList (· ∈ q.atoms) cd.args) (h : constructor q P path cd = true) :
    (∀ info, P.dataInfo cd.data = some info → info.arity = cd.ntys) ∧
      ∀ a ∈ cd.args, Ty.Annotation P (List.replicate cd.ntys TypeCtx.valueParam) [] a ∧
        Ty.HasKind P (List.replicate cd.ntys .value) a .value ∧
        Ty.VarianceOK P (P.varianceFor cd.data cd.ntys) .positive a := by
  have hh := Bool.and_eq_true_iff.mp h
  refine ⟨?_, ?_⟩
  · intro info hi
    simpa only [hi, decide_eq_true_eq] using hh.1
  · intro a ha
    have hc := Bool.and_eq_true_iff.mp (List.all_eq_true.mp hh.2 a ha)
    have hc' := Bool.and_eq_true_iff.mp hc.2
    exact ⟨CheckFormation.annotation_sound hq (by intro i t hi; cases hi)
      (Ty.SupportList.iff.mp hs a ha) hc.1,
      CheckFormation.kindTy_sound hq.ctors hc'.1, (ty_spec _ _ _ _).mp hc'.2⟩

def constructors (q : CheckFormation.Input) (P : Refinement.Program) : List ConName → Nat → Bool
  | [], _ => true
  | c :: cs, index =>
      (match P.cons c with | none => true | some cd => constructor q P [index] cd) &&
        constructors q P cs (index + 1)

theorem constructors_sound {q P names index} (h : constructors q P names index = true) :
    ∀ c cd, c ∈ names → P.cons c = some cd → ∃ path, constructor q P path cd = true := by
  induction names generalizing index with
  | nil => intro c cd hc; cases hc
  | cons c cs ih =>
    have hh := Bool.and_eq_true_iff.mp h
    intro name cd hn hd
    rcases List.mem_cons.mp hn with he | hn
    · subst name
      exact ⟨[index], by simpa only [hd] using hh.1⟩
    · exact ih hh.2 name cd hn hd

/-- 宣言名の一覧の全件を検査し、metadata と構成子のどちらも省かない。 -/
def check (q : CheckFormation.Input) (P : Refinement.Program) (dataNames : List DataName) (ctorNames : List ConName) : Bool :=
  dataNames.all (fun d => match P.dataInfo d with
    | none => true
    | some info => metadata P ctorNames d info) && constructors q P ctorNames 0

theorem check_sound {q P dataNames ctorNames} (hq : q.Sound P)
    (hd : DataComplete P dataNames) (hc : CtorsComplete P ctorNames)
    (h : check q P dataNames ctorNames = true) : P.VarianceValid := by
  have hh := Bool.and_eq_true_iff.mp h
  refine ⟨?_, ?_⟩
  · intro d info hi
    have hrow := List.all_eq_true.mp hh.1 d (hd d info hi)
    have hm : metadata P ctorNames d info = true := by simpa only [hi] using hrow
    exact metadata_sound hc hm
  · intro c cd hcd
    obtain ⟨path, ht⟩ := constructors_sound hh.2 c cd (hc c cd hcd) hcd
    exact constructor_sound hq (hq.fields c cd hcd) ht

/-! ## 出現・非出現・公開境界の対照 -/

namespace Examples

private def cellInfo (variance : Variance) (requirements : List Ty) (boundary : List (Polarity × Ty)) : DataVarianceDecl :=
  ⟨1, [variance], requirements, boundary⟩

private def cellConstructor (present : Bool) : ConDecl :=
  ⟨"Example.Cell", 1, if present then [.tvar 0] else []⟩

private def program (present : Bool) (variance : Variance)
    (requirements : List Ty := []) (boundary : List (Polarity × Ty) := []) : Refinement.Program where
  defs := fun _ => none
  cons := fun c => if c = "Example.Cell.make" then some (cellConstructor present) else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  dataInfo := fun d => if d = "Example.Cell" then some (cellInfo variance requirements boundary) else none

private def input : CheckFormation.Input := ⟨[], fun _ => ["Example.Cell.make"], []⟩

private theorem input_sound (present : Bool) (variance : Variance) (requirements : List Ty)
    (boundary : List (Polarity × Ty)) : input.Sound (program present variance requirements boundary) where
  ctors := by
    intro c cd hc
    simp only [program] at hc
    split at hc
    · cases hc
      simp [input, ‹c = "Example.Cell.make"›]
    · cases hc
  fields := by
    intro c cd hc
    simp only [program] at hc
    split at hc
    · cases hc
      cases present <;> trivial
    · cases hc

private theorem data_complete (present : Bool) (variance : Variance) (requirements : List Ty)
    (boundary : List (Polarity × Ty)) : DataComplete (program present variance requirements boundary) ["Example.Cell"] := by
  intro d info hi
  simp only [program] at hi
  split at hi
  · simp [‹d = "Example.Cell"›]
  · cases hi

private theorem ctors_complete (present : Bool) (variance : Variance) (requirements : List Ty)
    (boundary : List (Polarity × Ty)) : CtorsComplete (program present variance requirements boundary) ["Example.Cell.make"] := by
  intro c cd hc
  simp only [program] at hc
  split at hc
  · simp [‹c = "Example.Cell.make"›]
  · cases hc

/-- 正に出現する型引数の共変を受理し、実際の同じ欄の反変は拒否する。 -/
example : check input (program true .covariant) ["Example.Cell"] ["Example.Cell.make"] = true ∧
    check input (program true .contravariant) ["Example.Cell"] ["Example.Cell.make"] = false := ⟨by rfl, by rfl⟩

/-- 型引数が欄に出現しない場合は、不変だけを受理する。 -/
example : check input (program false .invariant) ["Example.Cell"] ["Example.Cell.make"] = true ∧
    check input (program false .covariant) ["Example.Cell"] ["Example.Cell.make"] = false := ⟨by rfl, by rfl⟩

/-- 構成子の欄だけを見て済ませず、制約の両極性と公開境界も検査する。 -/
example : check input (program true .covariant [.tvar 0]) ["Example.Cell"] ["Example.Cell.make"] = false ∧
    check input (program true .covariant [] [(.negative, .tvar 0)]) ["Example.Cell"] ["Example.Cell.make"] = false :=
  ⟨by rfl, by rfl⟩

/-- 前提を満たす非空の宣言に全体の健全性を適用する。 -/
example : (program true .covariant).VarianceValid :=
  check_sound (input_sound true .covariant [] []) (data_complete true .covariant [] [])
    (ctors_complete true .covariant [] []) (by rfl)

example : (program false .invariant).VarianceValid :=
  check_sound (input_sound false .invariant [] []) (data_complete false .invariant [] [])
    (ctors_complete false .invariant [] []) (by rfl)

end Examples

end Benitoite.Release.Refinement.Surface.CheckVariance
