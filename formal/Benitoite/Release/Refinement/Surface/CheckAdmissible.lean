import Benitoite.Release.Refinement.Surface.CheckCompare
import Benitoite.Release.Refinement.Admissible
import Benitoite.Release.Refinement.Surface.CheckFormation

/-!
# 署名由来の Q と NoFail の計算

Q は宣言の行数個の Bool とする。NoFail の判定は最外の Fail 列と行だけを調べる。
支持条件は既存の checker と同じ再帰的な有限支持から渡す。
-/

namespace Benitoite.Release.Refinement.Surface.CheckAdmissible

/-- 計算用 Q の範囲外は NoFail とみなさない。 -/
def NoFailCtxOf (q : List Bool) : NoFailCtx := fun i => q[i]?.getD false = true

@[simp] theorem NoFailCtxOf_nil : NoFailCtxOf [] = Qempty := by
  funext i
  simp [NoFailCtxOf, Qempty]


mutual
  def qTyAt (i : Nat) : Ty → Bool
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ | .scoped _ _ _ | .pathBases | .scopePattern _ => false
    | .data _ as | .tapp _ as | .external _ as => qTysAt i as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => qTyAt i a
    | .map a b => qTyAt i a || qTyAt i b
    | .fn _ ps r e => qTysAt i ps || (qTyAt i r || qEffAt i e)
    | .cont a b e => qTyAt i a || (qTyAt i b || qEffAt i e)
    | .dependentFn t => qTelAt i t
  def qTelAt (i : Nat) : Tel → Bool
    | .done r e => qTyAt i r || qEffAt i e
    | .param _ a t => qTyAt i a || qTelAt i t
  def qTysAt (i : Nat) : List Ty → Bool
    | [] => false
    | t :: ts => qTyAt i t || qTysAt i ts
  def qEffAt (i : Nat) : Eff → Bool
    | .mk atoms fs => (!fs.isEmpty && atoms (.rho i)) || qTysAt i fs
end

/-- 入力の署名だけを辿り、本体を参照しない。 -/
def signatureQ (ne : Nat) (ps : List Ty) (ret : Ty) (e : Eff) : List Bool :=
  (List.range ne).map fun i => qTysAt i ps || (qTyAt i ret || qEffAt i e)

/-- 型内部の潜在効果を再検査せず、最外の Fail と行を判定する。 -/
def noFailCheck (atoms : List Atom) (q : List Bool) (e : Eff) : Bool :=
  e.fails.isEmpty && atoms.all (fun a => match a with
    | .name _ _ => true
    | .rho i => !e.test (.rho i) || q[i]?.getD false)

/-- Qcallee の全行について、caller の Q で行の像を検査する。 -/
def rowTransportCheck (atoms : List Atom) (qs qt : List Bool) (es : List Eff) : Bool :=
  (List.range qs.length).all fun i =>
    !qs[i]?.getD false || match es[i]? with
      | none => false
      | some e => noFailCheck atoms qt e

mutual
  theorem qTyAt_spec (i : Nat) (t : Ty) : qTyAt i t = true ↔ QTy t i := by
    cases t <;> simp only [qTyAt, QTy, Qempty, Bool.false_eq_true, Bool.or_eq_true,
      qTyAt_spec, qTysAt_spec, qEffAt_spec, qTelAt_spec]

  theorem qTelAt_spec (i : Nat) (t : Tel) : qTelAt i t = true ↔ QTel t i := by
    cases t with
    | done r e => simp only [qTelAt, QTel, Bool.or_eq_true, qTyAt_spec, qEffAt_spec]
    | param n a t => simp only [qTelAt, QTel, Bool.or_eq_true, qTyAt_spec, qTelAt_spec]

  theorem qTysAt_spec (i : Nat) (ts : List Ty) : qTysAt i ts = true ↔ QTys ts i := by
    cases ts with
    | nil => simp [qTysAt, QTys, Qempty]
    | cons t ts => simp only [qTysAt, QTys, Bool.or_eq_true, qTyAt_spec, qTysAt_spec]

  theorem qEffAt_spec (i : Nat) (e : Eff) : qEffAt i e = true ↔ QEff e i := by
    cases e with
    | mk a fs =>
      simp only [qEffAt, QEff, Bool.or_eq_true, Bool.and_eq_true, Bool.not_eq_true',
        qTysAt_spec, List.isEmpty_eq_false_iff]
end

@[simp] theorem signatureQ_length (ne : Nat) (ps : List Ty) (r : Ty) (e : Eff) :
    (signatureQ ne ps r e).length = ne := by simp [signatureQ]

/-- 範囲外の Q を捨てたことを明示する、無条件の一致。 -/
theorem signatureQ_spec (ne : Nat) (ps : List Ty) (r : Ty) (e : Eff) (i : Nat) :
    NoFailCtxOf (signatureQ ne ps r e) i ↔ i < ne ∧ Qsig ps r e i := by
  by_cases hi : i < ne
  · simp [NoFailCtxOf, signatureQ, hi,
      qTyAt_spec, qTysAt_spec, qEffAt_spec, Qsig]
  · simp [NoFailCtxOf, hi]

/-- 最外の支持だけで判定の完全性と健全性が得られる。
既存の再帰的な AtomsIn はこの支持を含む。 -/
theorem noFailCheck_spec {atoms : List Atom} {q : List Bool} {e : Eff}
    (ha : ∀ a, Eff.mem e a → a ∈ atoms) :
    noFailCheck atoms q e = true ↔ NoFail (NoFailCtxOf q) e := by
  simp only [noFailCheck, Bool.and_eq_true, List.isEmpty_iff, List.all_eq_true]
  constructor
  · rintro ⟨hf, h⟩
    refine ⟨hf, fun i hi => ?_⟩
    have ht := h (.rho i) (ha _ hi)
    simpa only [hi, Bool.not_true, Bool.false_or, NoFailCtxOf] using ht
  · rintro ⟨hf, hr⟩
    refine ⟨hf, fun a _ => ?_⟩
    cases a with
    | name _ => rfl
    | rho i =>
      by_cases hi : Eff.mem e (.rho i)
      · have hq := hr i hi
        simpa only [hi, Bool.not_true, Bool.false_or, NoFailCtxOf] using hq
      · have hi' : e.test (.rho i) = false := Bool.eq_false_iff.mpr hi
        simp only [hi', Bool.not_false, Bool.true_or]

/-- 支持外の行を黙って落とさず、既存の支持の証拠を要求する。 -/
theorem noFailCheck_atoms_spec {atoms : List Atom} {q : List Bool} {e : Eff}
    (ha : e.Support (· ∈ atoms)) :
    noFailCheck atoms q e = true ↔ NoFail (NoFailCtxOf q) e :=
  noFailCheck_spec (by cases e; exact ha.1)

/-- 全具体化用の判定は、範囲外の恒等行に逃げずに列の要素を要求する。 -/
theorem rowTransportCheck_sound {atoms qs qt es}
    (ha : ∀ e ∈ es, e.Support (· ∈ atoms))
    (h : rowTransportCheck atoms qs qt es = true) :
    RowTransport (NoFailCtxOf qs) (NoFailCtxOf qt) es := by
  intro i hi
  have his : i < qs.length := by
    by_cases hs : i < qs.length
    · exact hs
    · have hn : qs[i]? = none := List.getElem?_eq_none (Nat.le_of_not_gt hs)
      simp [NoFailCtxOf, hn] at hi
  have ht := List.all_eq_true.mp h i (List.mem_range.mpr his)
  change (!qs[i]?.getD false || _) = true at ht
  rw [show qs[i]?.getD false = true from hi] at ht
  simp only [Bool.not_true, Bool.false_or] at ht
  cases he : es[i]? with
  | none => simp [he] at ht
  | some e =>
    have hec : noFailCheck atoms qt e = true := by simpa [he] using ht
    exact (noFailCheck_atoms_spec (ha e (List.mem_of_getElem? he))).mp hec


mutual
  def rowsTyCheck (atoms : List Atom) (ne : Nat) : Ty → Bool
    | .data _ ts | .tapp _ ts | .external _ ts => rowsTysCheck atoms ne ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t | .refined t _ => rowsTyCheck atoms ne t
    | .fn _ ps r e => rowsTysCheck atoms ne ps && rowsTyCheck atoms ne r && rowsEffCheck atoms ne e
    | .cont a b e => rowsTyCheck atoms ne a && rowsTyCheck atoms ne b && rowsEffCheck atoms ne e
    | .map a b => rowsTyCheck atoms ne a && rowsTyCheck atoms ne b
    | .dependentFn t => rowsTelCheck atoms ne t
    | _ => true
  def rowsTelCheck (atoms : List Atom) (ne : Nat) : Tel → Bool
    | .done r e => rowsTyCheck atoms ne r && rowsEffCheck atoms ne e
    | .param _ a t => rowsTyCheck atoms ne a && rowsTelCheck atoms ne t
  def rowsTysCheck (atoms : List Atom) (ne : Nat) : List Ty → Bool
    | [] => true
    | t :: ts => rowsTyCheck atoms ne t && rowsTysCheck atoms ne ts
  def rowsEffCheck (atoms : List Atom) (ne : Nat) : Eff → Bool
    | .mk a fs => atoms.all (fun x => match x with
        | .name _ _ => true
        | .rho i => !a (.rho i) || decide (i < ne)) && rowsTysCheck atoms ne fs
end

private theorem rowsAtoms_spec {atoms : List Atom} {a : Atom → Bool} {ne : Nat}
    (ha : ∀ x, a x = true → x ∈ atoms) :
    atoms.all (fun x => match x with
      | .name _ _ => true
      | .rho i => !a (.rho i) || decide (i < ne)) = true ↔
      ∀ i, a (.rho i) = true → i < ne := by
  rw [List.all_eq_true]
  constructor
  · intro h i hi
    have ht := h (.rho i) (ha _ hi)
    simpa only [hi, Bool.not_true, Bool.false_or, decide_eq_true_eq] using ht
  · intro h x _
    cases x with
    | name _ => rfl
    | rho i =>
      by_cases hi : a (.rho i) = true
      · simp [hi, h i hi]
      · simp [Bool.eq_false_iff.mpr hi]

mutual
  theorem rowsTyCheck_spec {atoms} (ne : Nat) (t : Ty) (ha : t.Support (· ∈ atoms)) :
      rowsTyCheck atoms ne t = true ↔ t.RowsIn (· < ne) := by
    cases t <;> simp only [Ty.Support] at ha
    all_goals simp only [rowsTyCheck, Ty.RowsIn, Bool.and_eq_true]
    all_goals first | rfl | (simp; done) | exact rowsTyCheck_spec ne _ ha | exact rowsTysCheck_spec ne _ ha | skip
    case dependentFn t => exact rowsTelCheck_spec ne t ha
    case fn ns ps r e =>
      rw [rowsTysCheck_spec ne ps ha.1, rowsTyCheck_spec ne r ha.2.1, rowsEffCheck_spec ne e ha.2.2]
      exact and_assoc
    case cont a b e =>
      rw [rowsTyCheck_spec ne a ha.1, rowsTyCheck_spec ne b ha.2.1, rowsEffCheck_spec ne e ha.2.2]
      exact and_assoc
    case map a b => rw [rowsTyCheck_spec ne a ha.1, rowsTyCheck_spec ne b ha.2]
  theorem rowsTelCheck_spec {atoms} (ne : Nat) (t : Tel) (ha : t.Support (· ∈ atoms)) :
      rowsTelCheck atoms ne t = true ↔ t.RowsIn (· < ne) := by
    cases t with
    | done r e => simp only [rowsTelCheck, Tel.RowsIn, Bool.and_eq_true,
        rowsTyCheck_spec ne r ha.1, rowsEffCheck_spec ne e ha.2]
    | param n a t => simp only [rowsTelCheck, Tel.RowsIn, Bool.and_eq_true,
        rowsTyCheck_spec ne a ha.1, rowsTelCheck_spec ne t ha.2]
  theorem rowsTysCheck_spec {atoms} (ne : Nat) (ts : List Ty) (ha : Ty.SupportList (· ∈ atoms) ts) :
      rowsTysCheck atoms ne ts = true ↔ Ty.RowsInList (· < ne) ts := by
    cases ts with
    | nil => simp [rowsTysCheck, Ty.RowsInList]
    | cons t ts =>
      simp only [rowsTysCheck, Ty.RowsInList, Bool.and_eq_true,
        rowsTyCheck_spec ne t ha.1, rowsTysCheck_spec ne ts ha.2]
  theorem rowsEffCheck_spec {atoms} (ne : Nat) (e : Eff) (ha : e.Support (· ∈ atoms)) :
      rowsEffCheck atoms ne e = true ↔ e.RowsIn (· < ne) := by
    cases e with
    | mk a fs =>
      simp only [rowsEffCheck, Eff.RowsIn, Bool.and_eq_true,
        rowsTysCheck_spec ne fs ha.2, rowsAtoms_spec ha.1]
end


mutual
  /-- 宣言の既存の行の範囲から Q の範囲が得られる。 -/
  theorem qTy_scoped {pe : Nat → Prop} (t : Ty) (h : t.RowsIn pe) :
      ∀ i, QTy t i → pe i := by
    cases t <;> simp only [Ty.RowsIn, QTy] at h ⊢
    all_goals first
      | exact fun _ hi => hi.elim
      | exact qTy_scoped _ h
      | exact qTys_scoped _ h
      | skip
    case dependentFn t => exact qTel_scoped t h
    case fn ns ps r e =>
      intro i hi
      rcases hi with hi | hi | hi
      · exact qTys_scoped ps h.1 i hi
      · exact qTy_scoped r h.2.1 i hi
      · exact qEff_scoped e h.2.2 i hi
    case cont a b e =>
      intro i hi
      rcases hi with hi | hi | hi
      · exact qTy_scoped a h.1 i hi
      · exact qTy_scoped b h.2.1 i hi
      · exact qEff_scoped e h.2.2 i hi
    case map a b =>
      intro i hi
      exact hi.elim (qTy_scoped a h.1 i) (qTy_scoped b h.2 i)

  theorem qTel_scoped {pe : Nat → Prop} (t : Tel) (h : t.RowsIn pe) :
      ∀ i, QTel t i → pe i := by
    cases t with
    | done r e => exact fun i hi => hi.elim (qTy_scoped r h.1 i) (qEff_scoped e h.2 i)
    | param n a t => exact fun i hi => hi.elim (qTy_scoped a h.1 i) (qTel_scoped t h.2 i)

  theorem qTys_scoped {pe : Nat → Prop} (ts : List Ty) (h : Ty.RowsInList pe ts) :
      ∀ i, QTys ts i → pe i := by
    cases ts with
    | nil => exact fun _ hi => hi.elim
    | cons t ts =>
      intro i hi
      exact hi.elim (qTy_scoped t h.1 i) (qTys_scoped ts h.2 i)

  theorem qEff_scoped {pe : Nat → Prop} (e : Eff) (h : e.RowsIn pe) :
      ∀ i, QEff e i → pe i := by
    cases e with
    | mk a fs =>
      intro i hi
      exact hi.elim (fun hi => h.1 i hi.2) (qTys_scoped fs h.2 i)
end

theorem qSig_scoped {pe : Nat → Prop} {ps : List Ty} {ret : Ty} {e : Eff}
    (hp : Ty.RowsInList pe ps) (hr : ret.RowsIn pe) (he : e.RowsIn pe) :
    ∀ i, Qsig ps ret e i → pe i := by
  intro i hi
  rcases hi with hi | hi | hi
  · exact qTys_scoped ps hp i hi
  · exact qTy_scoped ret hr i hi
  · exact qEff_scoped e he i hi

/-- 行の範囲が適格なら、有限な Q の列が元の全ての行と一致する。 -/
theorem signatureQ_scoped {ne : Nat} {ps : List Ty} {r : Ty} {e : Eff}
    (hp : Ty.RowsInList (· < ne) ps) (hr : r.RowsIn (· < ne))
    (he : e.RowsIn (· < ne)) (i : Nat) :
    NoFailCtxOf (signatureQ ne ps r e) i ↔ Qsig ps r e i := by
  rw [signatureQ_spec]
  exact ⟨And.right, fun hi => ⟨qSig_scoped hp hr he i hi, hi⟩⟩

/-- 型の像に、範囲・型・値の上限と Ordinary を要求する。 -/
def typeScopeCheck (q : CheckFormation.Input) (C : TypeCtx) (nv : Nat) (ts : List Ty) : Bool :=
  ts.all fun a => CheckFormation.wfTy q 0 C.length nv a && decide (Ordinary a)

def instantiationCheck (q : CheckFormation.Input) (caller : List Bool) (C : TypeCtx) (nv ne : Nat)
    (ps : List Ty) (ret : Ty) (e : Eff) (ts : List Ty) (es : List Eff) : Bool :=
  typeScopeCheck q C nv ts && es.all (CheckFormation.wfEff q 0 C.length nv) && decide (es.length = ne) &&
    rowsTysCheck q.atoms ne ps && rowsTyCheck q.atoms ne ret && rowsEffCheck q.atoms ne e &&
      rowTransportCheck q.atoms (signatureQ ne ps ret e) caller es

structure InstantiationConditions (C : TypeCtx) (nv ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  typeScope : ∀ t ∈ ts, Ty.WF 0 C.length nv t ∧ Ordinary t
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF 0 C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es

theorem instantiationCheck_conditions {q : CheckFormation.Input} {caller : List Bool} {C : TypeCtx} {nv ne : Nat} {ps : List Ty} {ret : Ty} {e : Eff} {ts : List Ty} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) ps) (hr : ret.Support (· ∈ q.atoms)) (he : e.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (h : instantiationCheck q caller C nv ne ps ret e ts es = true) :
    InstantiationConditions C nv ne (Qsig ps ret e) (NoFailCtxOf caller) ts es e := by
  simp only [instantiationCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨⟨htc, hec⟩, hn⟩, hpc⟩, hrc⟩, hec'⟩, hq⟩ := h
  have hps := (rowsTysCheck_spec ne ps hp).mp hpc
  have hrs := (rowsTyCheck_spec ne ret hr).mp hrc
  have hes' := (rowsEffCheck_spec ne e he).mp hec'
  refine ⟨?_, hn, ?_, ?_, ?_, ?_⟩
  · intro a ha
    have hc := List.all_eq_true.mp htc a ha
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    exact ⟨CheckFormation.wfTy_sound (Ty.SupportList.iff.mp ht a ha) hc.1, hc.2⟩
  · intro f hf
    exact CheckFormation.wfEff_sound (hes f hf) (List.all_eq_true.mp hec f hf)
  · simpa only [hn] using hes'
  · intro i hi
    simpa only [hn] using qSig_scoped hps hrs hes' i hi
  · have ht' := rowTransportCheck_sound hes hq
    intro i hi
    exact ht' i ((signatureQ_scoped hps hrs hes' i).mpr hi)

theorem instantiationCheck_admissible {q : CheckFormation.Input} {caller : List Bool} {B : Builtins} {C : TypeCtx} {nv ne : Nat} {tps : List TParam} {ps : List Ty} {ret : Ty} {e : Eff} {ts : List Ty} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) ps) (hr : ret.Support (· ∈ q.atoms)) (he : e.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (hs : SatAll B C ts tps)
    (h : instantiationCheck q caller C nv ne ps ret e ts es = true) :
    Admissible B C nv tps ne (Qsig ps ret e) (NoFailCtxOf caller) ts es e := by
  have hc := instantiationCheck_conditions hp hr he ht hes h
  exact ⟨hs, hc.typeScope, hc.rowCount, hc.rowScope, hc.sourceRows, hc.sourceQ, hc.noFailRows⟩

/-- メソッドの行の具体化。通常の型制約と型引数の検査とは分ける。 -/
def methodRowsCheck (q : CheckFormation.Input) (caller : List Bool) (C : TypeCtx) (nv : Nat)
    (ms : MethSig) (es : List Eff) : Bool :=
  decide (es.length = ms.neffs) && es.all (CheckFormation.wfEff q 0 C.length nv) &&
    rowsTysCheck q.atoms ms.neffs ms.params && rowsTyCheck q.atoms ms.neffs ms.ret &&
    rowsEffCheck q.atoms ms.neffs ms.eff && rowTransportCheck q.atoms
      (signatureQ ms.neffs ms.params ms.ret ms.eff) caller es

theorem methodRowsCheck_sound {q : CheckFormation.Input} {caller : List Bool} {C : TypeCtx} {nv : Nat} {ms : MethSig} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) ms.params) (hr : ms.ret.Support (· ∈ q.atoms))
    (he : ms.eff.Support (· ∈ q.atoms)) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (h : methodRowsCheck q caller C nv ms es = true) :
    MethodRowsAdmissible C nv (NoFailCtxOf caller) ms es := by
  simp only [methodRowsCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨⟨⟨⟨⟨hn, hfs⟩, hps⟩, hrs⟩, hes'⟩, hq⟩ := h
  have hp' := (rowsTysCheck_spec _ _ hp).mp hps
  have hr' := (rowsTyCheck_spec _ _ hr).mp hrs
  have he' := (rowsEffCheck_spec _ _ he).mp hes'
  refine ⟨hn, ?_, ?_, ?_, ?_⟩
  · intro f hf
    exact CheckFormation.wfEff_sound (hes f hf) (List.all_eq_true.mp hfs f hf)
  · simpa only [hn] using he'
  · intro i hi
    simpa only [hn] using qSig_scoped hp' hr' he' i hi
  · intro i hi
    exact rowTransportCheck_sound hes hq i ((signatureQ_scoped hp' hr' he' i).mpr hi)

/-- 組み込みの署名の構造と全依存列の行を検査する。許容判定は同じ署名の admits と別に照合する。 -/
def primitiveAdmissibleCheck (q : CheckFormation.Input) (caller : List Bool) (C : TypeCtx)
    (nv : Nat) (sg : PrimSig) (ts : List Ty) (es : List Eff) : Bool :=
  instantiationCheck q caller C nv sg.neffs sg.params sg.ret sg.eff ts es &&
    decide (ts.length = sg.tparams.length) && rowsTelCheck q.atoms es.length sg.tel

theorem primitiveAdmissibleCheck_sound {q : CheckFormation.Input} {caller : List Bool} {C : TypeCtx} {nv : Nat} {sg : PrimSig} {ts : List Ty} {es : List Eff}
    (hp : Ty.SupportList (· ∈ q.atoms) sg.params) (hr : sg.ret.Support (· ∈ q.atoms))
    (he : sg.eff.Support (· ∈ q.atoms)) (hTel : sg.tel.Support (· ∈ q.atoms))
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hes : ∀ f ∈ es, f.Support (· ∈ q.atoms))
    (hadmits : sg.admits (TypeCtx.constraints C) (Ty.normTys ts))
    (h : primitiveAdmissibleCheck q caller C nv sg ts es = true) :
    PrimitiveAdmissible C nv sg (NoFailCtxOf caller) ts es := by
  simp only [primitiveAdmissibleCheck, Bool.and_eq_true, decide_eq_true_eq] at h
  have hc := instantiationCheck_conditions hp hr he ht hes h.1.1
  exact ⟨h.1.2, hadmits, hc.typeScope, hc.rowCount, hc.rowScope, hc.sourceRows, hc.sourceQ,
    hc.noFailRows, (rowsTelCheck_spec _ _ hTel).mp h.2⟩

/-- 関数の全依存列だけから作る NoFail の有限な文脈。 -/
def telQ (ne : Nat) (t : Tel) : List Bool := (List.range ne).map fun i => qTelAt i t

theorem telQ_spec (ne : Nat) (t : Tel) (i : Nat) :
    NoFailCtxOf (telQ ne t) i ↔ i < ne ∧ QTel t i := by
  by_cases hi : i < ne
  · simp [NoFailCtxOf, telQ, hi, qTelAt_spec]
  · simp [NoFailCtxOf, telQ, hi]

theorem telQ_scoped {ne : Nat} {t : Tel} (h : t.RowsIn (· < ne)) (i : Nat) :
    NoFailCtxOf (telQ ne t) i ↔ QTel t i := by
  rw [telQ_spec]
  exact ⟨And.right, fun hi => ⟨qTel_scoped t h i hi, hi⟩⟩

end Benitoite.Release.Refinement.Surface.CheckAdmissible
