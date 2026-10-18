import Benitoite.Release.Effect

/-!
# 型と行の同時代入

入力の Fail の型を再帰して置き換え、選んだ行の像を合流する。
挿入した像には同じ代入を再適用しない（設計書 01-12「コア計算と脱糖」）。
-/

namespace Benitoite.Release

/-- 正規化前の型構成子への適用。 -/
def TyCon.rawApply : TyCon → List Ty → Ty
  | .data d, as => .data d as
  | .list, as => .list (as.headD (.base .unit))
  | .set, as => .set (as.headD (.base .unit))
  | .map, as => .map (as.headD (.base .unit)) (as.tail.headD (.base .unit))
  | .reference, as => .reference (as.headD (.base .unit))
  | .lazy, as => .lazy (as.headD (.base .unit))

/-- 型の種類が合わないときの扱いは元の型を返す。 -/
def Ty.rawApplyTo (t : Ty) (as : List Ty) : Ty :=
  match t with
  | .ctor c => c.rawApply as
  | .tvar i => .tapp i as
  | t => t

noncomputable def TyCon.apply (c : TyCon) (as : List Ty) : Ty := c.rawApply (Ty.normTys as)
noncomputable def Ty.applyTo (t : Ty) (as : List Ty) : Ty :=
  match t with
  | .ctor c => c.apply as
  | .tvar i => .tapp i (Ty.normTys as)
  | t => t.norm

/-- 型変数の像と、有限範囲の行変数の像。 -/
structure SubstEnv where
  types : Nat → Ty
  rows : List Eff

/-- 変数の移動を一般の代入の像として与える。 -/
def SubstEnv.shift (k c : Nat) : SubstEnv :=
  ⟨fun i => .tvar (if i < c then i else i + k), []⟩

/-- 行の原子の置換は型を含まない。 -/
def Eff.substAtoms (es : List Eff) (a : Atom → Bool) : Atom → Bool := fun x =>
  let kept := match x with
    | .name l => a (.name l)
    | .rho i => if i < es.length then false else a (.rho i)
  kept || (List.range es.length).any (fun i =>
    a (.rho i) && match es[i]? with
      | some e => e.test x
      | none => false)

/-- 元の行の所属で像を選ぶ。像の Fail の内部には同じ代入を適用しない。 -/
def Eff.rowFails (es : List Eff) (a : Atom → Bool) : List Ty :=
  ((List.range es.length).filter (fun i => a (.rho i))).flatMap (fun i =>
    match es[i]? with
    | some e => e.fails
    | none => [])

/-- 空の原子集合から行を具体化しても原子は増えない。 -/
theorem Eff.substAtoms_false (es : List Eff) : Eff.substAtoms es (fun _ => false) = fun _ => false := by
  funext a
  cases a <;> simp [Eff.substAtoms]

/-- 空の原子集合では、選ばれる行の像はない。 -/
theorem Eff.rowFails_false (es : List Eff) : Eff.rowFails es (fun _ => false) = [] := by
  unfold Eff.rowFails
  rw [show List.filter (fun _ => false) (List.range es.length) = [] from
    List.filter_eq_nil_iff.mpr (by simp)]
  rfl

@[simp] theorem Eff.substAtoms_nil (a : Atom → Bool) : Eff.substAtoms [] a = a := by
  funext x
  cases x <;> simp [Eff.substAtoms]

@[simp] theorem Eff.rowFails_nil (a : Atom → Bool) : Eff.rowFails [] a = [] := rfl

mutual
  /-- 正規化前の型への同時代入。 -/
  def Ty.rawBind (θ : SubstEnv) : Ty → Ty
    | .base b => .base b
    | .opaque o => .opaque o
    | .data d as => .data d (Ty.rawBindTys θ as)
    | .list a => .list (Ty.rawBind θ a)
    | .fn ns ps r e => .fn ns (Ty.rawBindTys θ ps) (Ty.rawBind θ r) (Eff.rawBind θ e)
    | .tvar i => θ.types i
    | .reference a => .reference (Ty.rawBind θ a)
    | .lazy a => .lazy (Ty.rawBind θ a)
    | .cont b t e => .cont (Ty.rawBind θ b) (Ty.rawBind θ t) (Eff.rawBind θ e)
    | .map a b => .map (Ty.rawBind θ a) (Ty.rawBind θ b)
    | .set a => .set (Ty.rawBind θ a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (Ty.rawBind θ a)
    | .tapp i as => (θ.types i).rawApplyTo (Ty.rawBindTys θ as)
    | .ctor c => .ctor c
  termination_by structural t => t

  def Ty.rawBindTys (θ : SubstEnv) : List Ty → List Ty
    | [] => []
    | a :: as => Ty.rawBind θ a :: Ty.rawBindTys θ as
  termination_by structural as => as

  /-- 入力の Fail 型だけへ再帰してから行の像を連結する。 -/
  def Eff.rawBind (θ : SubstEnv) : Eff → Eff
    | .mk a fs => .mk (Eff.substAtoms θ.rows a) (Ty.rawBindTys θ fs ++ Eff.rowFails θ.rows a)
  termination_by structural e => e
end

/-- 公開する代入はすべて正規化した結果を返す。 -/
noncomputable def Ty.bind (θ : SubstEnv) (t : Ty) : Ty := (t.rawBind θ).norm
noncomputable def Eff.bind (θ : SubstEnv) (e : Eff) : Eff := Eff.norm (Eff.rawBind θ e)
noncomputable def Ty.bindTys (θ : SubstEnv) (as : List Ty) : List Ty := as.map (Ty.bind θ)

/-- cutoff の内側を保持し、範囲内の像を移動して挿入する。行の像も同じ数だけ移動する。 -/
def SubstEnv.at (c : Nat) (ts : List Ty) (es : List Eff) : SubstEnv :=
  ⟨fun i => if i < c then .tvar i
    else if i - c < ts.length then ((ts[i - c]?).getD (.tvar i)).rawShift c 0
    else .tvar (i - ts.length), es.map (Eff.rawShift c 0)⟩

/-- 正規化前の有限列による代入。 -/
def Ty.rawSubstAt (c : Nat) (ts : List Ty) (es : List Eff) (t : Ty) : Ty :=
  t.rawBind (SubstEnv.at c ts es)

def Eff.rawSubstAt (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff) : Eff :=
  Eff.rawBind (SubstEnv.at c ts es) e

noncomputable def Eff.substAt (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff) : Eff :=
  Eff.norm (Eff.rawSubstAt c ts es e)

mutual
  /-- 型と行を同時に置き換える。再帰するのは入力の型だけであり、挿入した像には再適用しない。 -/
  noncomputable def Ty.substAt (c : Nat) (ts : List Ty) (es : List Eff) : Ty → Ty
    | .base ι => .base ι
    | .opaque o => .opaque o
    | .data d args => .data d (Ty.substTysAt c ts es args)
    | .list a => .list (Ty.substAt c ts es a)
    | .fn names params ret eff =>
        .fn names (Ty.substTysAt c ts es params) (Ty.substAt c ts es ret) (Eff.substAt c ts es eff)
    | .tvar i =>
        if i < c then .tvar i
        else if i - c < ts.length then ((ts[i - c]?).getD (.tvar i)).shift c 0
        else .tvar (i - ts.length)
    | .reference a => .reference (Ty.substAt c ts es a)
    | .lazy a => .lazy (Ty.substAt c ts es a)
    | .cont b t eff => .cont (Ty.substAt c ts es b) (Ty.substAt c ts es t) (Eff.substAt c ts es eff)
    | .map a b => .map (Ty.substAt c ts es a) (Ty.substAt c ts es b)
    | .set a => .set (Ty.substAt c ts es a)
    | .bytes => .bytes
    | .dict cl τ => .dict cl (Ty.substAt c ts es τ)
    | .tapp i args =>
        if i < c then .tapp i (Ty.substTysAt c ts es args)
        else if i - c < ts.length then
          Ty.applyTo (((ts[i - c]?).getD (.tvar i)).shift c 0) (Ty.substTysAt c ts es args)
        else .tapp (i - ts.length) (Ty.substTysAt c ts es args)
    | .ctor φ => .ctor φ
  termination_by structural t => t

  /-- 型の引数列も同じ構造再帰で置き換える。 -/
  noncomputable def Ty.substTysAt (c : Nat) (ts : List Ty) (es : List Eff) : List Ty → List Ty
    | [] => []
    | a :: as => Ty.substAt c ts es a :: Ty.substTysAt c ts es as
  termination_by structural as => as
end

noncomputable def Eff.substRho (es : List Eff) (e : Eff) : Eff := Eff.substAt 0 [] es e

/-- 行の有限の列の外では恒等像を使う。 -/
def Eff.rowImage (es : List Eff) (i : Nat) : Eff := (es[i]?).getD (Eff.row i)

/-- 合成は型の像と行の像の両方へ次の代入を施す。 -/
noncomputable def SubstEnv.compose (θ φ : SubstEnv) : SubstEnv :=
  ⟨fun i => Ty.bind φ (θ.types i),
    (List.range (max θ.rows.length φ.rows.length)).map (fun i => Eff.bind φ (Eff.rowImage θ.rows i))⟩

@[simp] theorem Ty.rawBindTys_eq_map (θ : SubstEnv) (as : List Ty) :
    Ty.rawBindTys θ as = as.map (Ty.rawBind θ) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [Ty.rawBindTys, List.map_cons, ih]

@[simp] theorem Ty.substTysAt_eq_map (c : Nat) (ts : List Ty) (es : List Eff) (as : List Ty) :
    Ty.substTysAt c ts es as = as.map (Ty.substAt c ts es) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [Ty.substTysAt, List.map_cons, ih]

@[simp] theorem Ty.shiftTys_eq_map (k c : Nat) (as : List Ty) :
    Ty.shiftTys k c as = as.map (Ty.shift k c) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [Ty.shiftTys, List.map_cons, ih]

@[simp] theorem Ty.bindTys_eq_map (θ : SubstEnv) (as : List Ty) :
    Ty.bindTys θ as = as.map (Ty.bind θ) := rfl

/-- 生の行の像の連結の所属を、元の行の所属と選んだ像で特徴付ける。 -/
theorem Eff.mem_rowFails {es : List Eff} {a : Atom → Bool} {t : Ty} :
    t ∈ Eff.rowFails es a ↔ ∃ i e, es[i]? = some e ∧ a (.rho i) = true ∧ t ∈ e.fails := by
  simp only [Eff.rowFails, List.mem_flatMap, List.mem_filter, List.mem_range]
  constructor
  · rintro ⟨i, ⟨hi, ha⟩, ht⟩
    refine ⟨i, es[i], List.getElem?_eq_getElem hi, ha, ?_⟩
    simpa only [List.getElem?_eq_getElem hi] using ht
  · rintro ⟨i, e, he, ha, ht⟩
    exact ⟨i, ⟨(List.getElem?_eq_some_iff.mp he).1, ha⟩, by simpa only [he] using ht⟩

end Benitoite.Release
