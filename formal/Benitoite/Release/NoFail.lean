import Benitoite.Release.TypeComposition

/-!
# 署名由来の NoFail 文脈と行の代入

NoFail は最外の Fail 列と行の条件である。型の中の潜在 Fail は禁じない。
Q は本体から推論せず、宣言の署名の字面から得る（0.0.8 の R7・R47）。
-/

namespace Benitoite.Release

abbrev NoFailCtx := Nat → Prop

def Qempty : NoFailCtx := fun _ => False

def QLe (Q Q' : NoFailCtx) : Prop := ∀ i, Q i → Q' i

mutual
  /-- 型内部の全署名の、明示の Fail と並ぶ行。 -/
  def QTy : Ty → NoFailCtx
    | .base _ | .opaque _ | .tvar _ | .bytes | .ctor _ => Qempty
    | .data _ as | .tapp _ as => QTys as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => QTy a
    | .map a b => fun i => QTy a i ∨ QTy b i
    | .fn _ ps r e => fun i => QTys ps i ∨ QTy r i ∨ QEff e i
    | .cont a b e => fun i => QTy a i ∨ QTy b i ∨ QEff e i
  def QTys : List Ty → NoFailCtx
    | [] => Qempty
    | t :: ts => fun i => QTy t i ∨ QTys ts i
  def QEff : Eff → NoFailCtx
    | .mk atoms fs => fun i =>
        (fs ≠ [] ∧ atoms (.rho i) = true) ∨ QTys fs i
end

def Qsig (ps : List Ty) (ret : Ty) (e : Eff) : NoFailCtx :=
  fun i => QTys ps i ∨ QTy ret i ∨ QEff e i

mutual
  /-- 宣言の既存の行の範囲から Q の範囲が得られる。 -/
  theorem QTy.scoped {pe : Nat → Prop} (t : Ty) (h : t.RowsIn pe) :
      ∀ i, QTy t i → pe i := by
    cases t <;> simp only [Ty.RowsIn, QTy] at h ⊢
    all_goals first
      | exact fun _ hi => hi.elim
      | exact QTy.scoped _ h
      | exact QTys.scoped _ h
      | skip
    case fn ns ps r e =>
      intro i hi
      rcases hi with hi | hi | hi
      · exact QTys.scoped ps h.1 i hi
      · exact QTy.scoped r h.2.1 i hi
      · exact QEff.scoped e h.2.2 i hi
    case cont a b e =>
      intro i hi
      rcases hi with hi | hi | hi
      · exact QTy.scoped a h.1 i hi
      · exact QTy.scoped b h.2.1 i hi
      · exact QEff.scoped e h.2.2 i hi
    case map a b =>
      intro i hi
      exact hi.elim (QTy.scoped a h.1 i) (QTy.scoped b h.2 i)

  theorem QTys.scoped {pe : Nat → Prop} (ts : List Ty) (h : Ty.RowsInList pe ts) :
      ∀ i, QTys ts i → pe i := by
    cases ts with
    | nil => exact fun _ hi => hi.elim
    | cons t ts =>
      intro i hi
      exact hi.elim (QTy.scoped t h.1 i) (QTys.scoped ts h.2 i)

  theorem QEff.scoped {pe : Nat → Prop} (e : Eff) (h : e.RowsIn pe) :
      ∀ i, QEff e i → pe i := by
    cases e with
    | mk a fs =>
      intro i hi
      exact hi.elim (fun hi => h.1 i hi.2) (QTys.scoped fs h.2 i)
end

theorem Qsig.scoped {pe : Nat → Prop} {ps : List Ty} {ret : Ty} {e : Eff}
    (hp : Ty.RowsInList pe ps) (hr : ret.RowsIn pe) (he : e.RowsIn pe) :
    ∀ i, Qsig ps ret e i → pe i := by
  intro i hi
  rcases hi with hi | hi | hi
  · exact QTys.scoped ps hp i hi
  · exact QTy.scoped ret hr i hi
  · exact QEff.scoped e he i hi

def NoFail (Q : NoFailCtx) (e : Eff) : Prop :=
  e.fails = [] ∧ ∀ i, Eff.mem e (.rho i) → Q i

def RowTransport (Qs Qt : NoFailCtx) (es : List Eff) : Prop :=
  ∀ i, Qs i → NoFail Qt (Eff.rowImage es i)

/-- 空の生の Fail 列と、意味上の Fail の不在は同値である。 -/
theorem Eff.fails_eq_nil_iff (e : Eff) : e.fails = [] ↔ ∀ t, ¬ Eff.memFail e t := by
  constructor
  · intro h t ht
    obtain ⟨x, hx, _⟩ := ht
    simp [h] at hx
  · intro h
    cases hf : e.fails with
    | nil => rfl
    | cons t ts => exact (h t ⟨t, by rw [hf]; exact List.mem_cons_self, rfl⟩).elim

/-- 所属による形は正規化や一般の行代入にも使える。 -/
theorem NoFail.iff_mem (Q : NoFailCtx) (e : Eff) :
    NoFail Q e ↔ (∀ t, ¬ Eff.memFail e t) ∧ ∀ i, Eff.mem e (.rho i) → Q i := by
  simp only [NoFail, Eff.fails_eq_nil_iff]

@[simp] theorem NoFail.norm_iff (Q : NoFailCtx) (e : Eff) :
    NoFail Q (Eff.norm e) ↔ NoFail Q e := by
  simp only [NoFail.iff_mem, Eff.norm_memFail, Eff.mem_norm]

theorem NoFail.empty (Q : NoFailCtx) : NoFail Q Eff.empty :=
  ⟨rfl, fun _ h => (Eff.mem_empty _ |>.mp h).elim⟩

theorem NoFail.row_iff (Q : NoFailCtx) (i : Nat) : NoFail Q (Eff.row i) ↔ Q i := by
  simp only [NoFail, Eff.row, Eff.ofAtoms, Eff.fails, true_and]
  constructor
  · intro h; exact h i (by simp [Eff.mem, Eff.test, Eff.atoms])
  · intro h j hj
    have : j = i := by simpa [Eff.mem, Eff.test, Eff.atoms] using hj
    exact this ▸ h

theorem NoFail.mono {Q Q' : NoFailCtx} {e : Eff} (hq : QLe Q Q') (h : NoFail Q e) :
    NoFail Q' e := ⟨h.1, fun i hi => hq i (h.2 i hi)⟩

theorem QLe.empty (Q : NoFailCtx) : QLe Qempty Q := fun _ h => h.elim

theorem QLe.refl (Q : NoFailCtx) : QLe Q Q := fun _ => id

theorem QLe.trans {Q Q' Q'' : NoFailCtx} (h : QLe Q Q') (h' : QLe Q' Q'') :
    QLe Q Q'' := fun i hi => h' i (h i hi)

theorem NoFail.not_memFail {Q : NoFailCtx} {e : Eff} (h : NoFail Q e) (t : Ty) :
    ¬ Eff.memFail e t := (Eff.fails_eq_nil_iff e).mp h.1 t

theorem NoFail.empty_iff (e : Eff) :
    NoFail Qempty e ↔ e.fails = [] ∧ ∀ i, ¬ Eff.mem e (.rho i) := Iff.rfl

/-- 和の後にも、最外に Fail がなく、行は同じ Q に属する。 -/
theorem NoFail.union_iff (Q : NoFailCtx) (e f : Eff) :
    NoFail Q (Eff.union e f) ↔ NoFail Q e ∧ NoFail Q f := by
  simp only [NoFail.iff_mem, Eff.memFail_union, Eff.mem_union]
  constructor
  · intro h
    exact ⟨⟨fun t ht => h.1 t (Or.inl ht), fun i hi => h.2 i (Or.inl hi)⟩,
      ⟨fun t ht => h.1 t (Or.inr ht), fun i hi => h.2 i (Or.inr hi)⟩⟩
  · rintro ⟨he, hf⟩
    exact ⟨fun t ht => ht.elim (he.1 t) (hf.1 t),
      fun i hi => hi.elim (he.2 i) (hf.2 i)⟩

theorem NoFail.union {Q : NoFailCtx} {e f : Eff} (he : NoFail Q e) (hf : NoFail Q f) :
    NoFail Q (Eff.union e f) := (NoFail.union_iff Q e f).mpr ⟨he, hf⟩

/-- 効果を狭めると NoFail は保たれる。 -/
theorem NoFail.sub {Q : NoFailCtx} {e f : Eff} (h : NoFail Q f) (hs : Eff.Sub e f) :
    NoFail Q e := (NoFail.iff_mem Q e).mpr
  ⟨fun t ht => h.not_memFail t (hs.2 t ht), fun i hi => h.2 i (hs.1 _ hi)⟩

/-- 型の移動は行の番号を変えず、空の Fail 列を保つ。 -/
theorem NoFail.shift_iff (Q : NoFailCtx) (e : Eff) (k c : Nat) :
    NoFail Q (Eff.shift k c e) ↔ NoFail Q e := by
  cases e with
  | mk a fs =>
    cases fs with
    | nil => rfl
    | cons t ts =>
      constructor
      · intro h
        have hn := h.not_memFail (t.shift k c)
        apply False.elim
        apply hn
        rw [Eff.shift, Eff.norm_memFail]
        exact ⟨t.rawShift k c, List.mem_cons_self, by
          simp only [Ty.shift_eq_norm_rawShift, Ty.norm_idem]⟩
      · intro h; cases h.1

theorem NoFail.shift {Q : NoFailCtx} {e : Eff} (h : NoFail Q e) (k c : Nat) :
    NoFail Q (Eff.shift k c e) := (NoFail.shift_iff Q e k c).mpr h

/-- 一般の代入でも、Q の各行の像が NoFail なら NoFail を保つ。 -/
theorem NoFail.bind {Qs Qt : NoFailCtx} {e : Eff} (θ : SubstEnv)
    (hr : RowTransport Qs Qt θ.rows) (h : NoFail Qs e) : NoFail Qt (Eff.bind θ e) := by
  apply (NoFail.iff_mem _ _).mpr
  constructor
  · intro t ht
    rcases (Eff.memFail_bind θ e t).mp ht with ⟨x, hx, _⟩ | ⟨i, hi, hit⟩
    · exact h.not_memFail x hx
    · exact (hr i (h.2 i hi)).not_memFail t hit
  · intro j hj
    rcases (Eff.mem_bind θ e (.rho j)).mp hj with ⟨l, hl, _⟩ | ⟨i, hi, hij⟩
    · cases hl
    · exact (hr i (h.2 i hi)).2 j hij

@[simp] theorem RowTransport.nil_iff (Qs Qt : NoFailCtx) :
    RowTransport Qs Qt [] ↔ QLe Qs Qt := by
  simp only [RowTransport, Eff.rowImage, List.getElem?_nil, Option.getD_none, NoFail.row_iff, QLe]

theorem RowTransport.refl (Q : NoFailCtx) : RowTransport Q Q [] :=
  (RowTransport.nil_iff Q Q).mpr (QLe.refl Q)

/-- cutoff により型の像を移動しても、NoFail の文脈の行番号は変わらない。 -/
theorem RowTransport.at {Qs Qt : NoFailCtx} {es : List Eff}
    (h : RowTransport Qs Qt es) (c : Nat) (ts : List Ty) :
    RowTransport Qs Qt (SubstEnv.at c ts es).rows := by
  intro i hi
  have hr := h i hi
  change NoFail Qt (Eff.rowImage (es.map (Eff.rawShift c 0)) i)
  cases hf : es[i]? with
  | none => simpa [Eff.rowImage, List.getElem?_map, hf] using hr
  | some f =>
    have hrf : NoFail Qt f := by simpa [Eff.rowImage, hf] using hr
    have hn := (NoFail.norm_iff Qt (Eff.rawShift c 0 f)).mp (hrf.shift c 0)
    simpa [Eff.rowImage, List.getElem?_map, hf] using hn

/-- 任意の型 cutoff での同時代入。全行の具体化は要求しない。 -/
theorem noFail_substAt {Qs Qt : NoFailCtx} {e : Eff} {es : List Eff}
    (hr : RowTransport Qs Qt es) (h : NoFail Qs e) (c : Nat) (ts : List Ty) :
    NoFail Qt (Eff.substAt c ts es e) :=
  NoFail.bind (SubstEnv.at c ts es) (hr.at c ts) h

/-- 列の map による合成には、最初の Q の行が列の範囲内にある条件を使う。 -/
theorem RowTransport.compose_scoped {Q0 Q1 Q2 : NoFailCtx} {es es' : List Eff}
    (hs : ∀ i, Q0 i → i < es.length) (h : RowTransport Q0 Q1 es)
    (h' : RowTransport Q1 Q2 es') (c : Nat) (ts : List Ty) :
    RowTransport Q0 Q2 (es.map (Eff.substAt c ts es')) := by
  intro i hi
  have hei : i < es.length := hs i hi
  have hf := h i hi
  simpa only [Eff.rowImage, List.getElem?_map, List.getElem?_eq_getElem hei,
    Option.map_some, Option.getD_some] using noFail_substAt h' hf c ts

/-- 有限列の外の恒等像も含む、一般の行代入の合成。 -/
theorem RowTransport.compose {Qs Qm Qt : NoFailCtx} (θ φ : SubstEnv)
    (h : RowTransport Qs Qm θ.rows) (h' : RowTransport Qm Qt φ.rows) :
    RowTransport Qs Qt (θ.compose φ).rows := by
  intro i hi
  rw [Eff.rowImage_compose]
  exact NoFail.bind φ h' (h i hi)

/-- 捕捉する枠の上限と、正規形から生のエラー型の一致を得る。 -/
theorem failure_upper_bound {E E' : Ty} {Rest : Eff}
    (hE : E.Canonical) (hE' : E'.Canonical) (hr : NoFail Qempty Rest)
    (h : Eff.memFail (Eff.union (Eff.singleFail E) Rest) E') : E' = E := by
  rcases (Eff.memFail_union _ _ _).mp h with h | h
  · have hn := (Eff.memFail_singleFail _ _).mp h
    exact hE'.symm.trans (hn.symm.trans hE)
  · exact (hr.not_memFail E' h).elim

/-- 空の Fail 列かどうかは正規化によらない。 -/
theorem Eff.norm_fails_eq_nil (e : Eff) : (Eff.norm e).fails = [] ↔ e.fails = [] := by
  simp only [Eff.fails_eq_nil_iff, Eff.norm_memFail]

theorem QTys.mem_iff (ts : List Ty) (i : Nat) : QTys ts i ↔ ∃ t ∈ ts, QTy t i := by
  induction ts with
  | nil => simp [QTys, Qempty]
  | cons t ts ih => simp only [QTys, ih, List.mem_cons, exists_eq_or_imp]

/-- 重複除去・整列は署名の Q を変えない。 -/
theorem QTys.sortUnique_iff (ts : List Ty) (i : Nat) :
    QTys (Order.sortUnique tyCompare ts) i ↔ QTys ts i := by
  simp only [QTys.mem_iff, Order.mem_sortUnique]

mutual
  theorem QTy.norm_iff (t : Ty) (i : Nat) : QTy t.norm i ↔ QTy t i := by
    cases t <;> simp only [Ty.norm, QTy, QTy.norm_iff, QTys.norm_iff, QEff.norm_iff]

  theorem QTys.norm_iff (ts : List Ty) (i : Nat) : QTys (Ty.normTys ts) i ↔ QTys ts i := by
    cases ts with
    | nil => rfl
    | cons t ts => simp only [Ty.normTys, QTys, QTy.norm_iff, QTys.norm_iff]

  theorem QEff.norm_iff (e : Eff) (i : Nat) : QEff (Eff.norm e) i ↔ QEff e i := by
    cases e with
    | mk a fs =>
      have hn := Eff.norm_fails_eq_nil (.mk a fs)
      simp only [Eff.norm, Eff.fails] at hn
      simp only [Eff.norm, QEff, not_congr hn, QTys.sortUnique_iff, QTys.norm_iff]
end

mutual
  theorem QTy.rawShift_iff (k c : Nat) (t : Ty) (i : Nat) :
      QTy (t.rawShift k c) i ↔ QTy t i := by
    cases t <;> simp only [Ty.rawShift, QTy, QTy.rawShift_iff, QTys.rawShift_iff, QEff.rawShift_iff]

  theorem QTys.rawShift_iff (k c : Nat) (ts : List Ty) (i : Nat) :
      QTys (Ty.rawShiftTys k c ts) i ↔ QTys ts i := by
    cases ts with
    | nil => rfl
    | cons t ts => simp only [Ty.rawShiftTys, QTys, QTy.rawShift_iff, QTys.rawShift_iff]

  theorem QEff.rawShift_iff (k c : Nat) (e : Eff) (i : Nat) :
      QEff (Eff.rawShift k c e) i ↔ QEff e i := by
    cases e with
    | mk a fs =>
      have hn : Ty.rawShiftTys k c fs = [] ↔ fs = [] := by
        rw [Ty.rawShiftTys_eq_map, List.map_eq_nil_iff]
      simp only [Eff.rawShift, QEff, not_congr hn, QTys.rawShift_iff]
end

theorem QTy.shift_iff (k c : Nat) (t : Ty) (i : Nat) :
    QTy (t.shift k c) i ↔ QTy t i := by
  rw [Ty.shift_eq_norm_rawShift, QTy.norm_iff, QTy.rawShift_iff]

theorem QEff.shift_iff (k c : Nat) (e : Eff) (i : Nat) :
    QEff (Eff.shift k c e) i ↔ QEff e i := by
  rw [Eff.shift, QEff.norm_iff, QEff.rawShift_iff]

end Benitoite.Release
