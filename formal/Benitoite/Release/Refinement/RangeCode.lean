import Benitoite.Release.Refinement.RangeSubst
import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.Telescope

/-! # 項の範囲変数の置換 -/
namespace Benitoite.Release.Refinement

noncomputable def BuilderKind.mapRanges (ρ : Nat → RangeIx) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (a.rawMapRanges ρ)

mutual
  noncomputable def Val.mapRanges (ρ : Nat → RangeIx) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f (tys.map (Ty.rawMapRanges ρ)) (effs.map (Eff.rawMapRanges ρ)) (rs.map (mapIx ρ))
    | .prim b tys effs rs => .prim b (tys.map (Ty.rawMapRanges ρ)) (effs.map (Eff.rawMapRanges ρ)) (rs.map (mapIx ρ))
    | .lam names params body => .lam names (params.map (Ty.rawMapRanges ρ)) (Comp.mapRanges ρ body)
    | .dependentLam t body => .dependentLam (Tel.rawMapRanges ρ t) (Comp.mapRanges ρ body)
    | .closure t body => .closure t body
    | .con c tys args => .con c (tys.map (Ty.rawMapRanges ρ)) (Val.mapRangesList ρ args)
    | .list elems => .list (Val.mapRangesList ρ elems)
    | .op o tys => .op o (tys.map (Ty.rawMapRanges ρ))
    | .raise t e => .raise (Ty.rawMapRanges ρ t) (Ty.rawMapRanges ρ e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.mapRangesList ρ ks) (Val.mapRangesList ρ vs)
    | .setV elems => .setV (Val.mapRangesList ρ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (Ty.rawMapRanges ρ)) (Val.mapRangesList ρ args)
    | .super v cl => .super (Val.mapRanges ρ v) cl
    | .externalRef f tys => .externalRef f (tys.map (Ty.rawMapRanges ρ))
    | .externalHandle h tys => .externalHandle h (tys.map (Ty.rawMapRanges ρ))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  noncomputable def Val.mapRangesList (ρ : Nat → RangeIx) : List Val → List Val
    | [] => []
    | v :: vs => Val.mapRanges ρ v :: Val.mapRangesList ρ vs

  noncomputable def Comp.mapRanges (ρ : Nat → RangeIx) : Comp → Comp
    | .builderLet k body => .builderLet (BuilderKind.mapRanges ρ k) (Comp.mapRanges ρ body)
    | .builderOp k op r args => .builderOp (BuilderKind.mapRanges ρ k) op r (Val.mapRangesList ρ args)
    | .ret v => .ret (Val.mapRanges ρ v)
    | .letIn m n => .letIn (Comp.mapRanges ρ m) (Comp.mapRanges ρ n)
    | .app f args => .app (Val.mapRanges ρ f) (Val.mapRangesList ρ args)
    | .ite v m n => .ite (Val.mapRanges ρ v) (Comp.mapRanges ρ m) (Comp.mapRanges ρ n)
    | .match v arms => .match (Val.mapRanges ρ v) (Arm.mapRangesList ρ arms)
    | .lazyC m => .lazyC (Comp.mapRanges ρ m)
    | .escape v => .escape (Val.mapRanges ρ v)
    | .use v m => .use (Val.mapRanges ρ v) (Comp.mapRanges ρ m)
    | .handle m h => .handle (Comp.mapRanges ρ m) (Clause.mapRangesList ρ h)
    | .resume k v => .resume (Val.mapRanges ρ k) (Val.mapRanges ρ v)
    | .externalCall f tys args => .externalCall f (tys.map (Ty.rawMapRanges ρ)) (Val.mapRangesList ρ args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := Ty.rawMapRanges ρ sh.errorType}
        (match bs with | none => none | some b => some (b.mapRanges ρ)) (p.mapRanges ρ) (v.mapRanges ρ) (mapIx ρ ix)
    | .meth d m tys effs args => .meth (Val.mapRanges ρ d) m (tys.map (Ty.rawMapRanges ρ)) (effs.map (Eff.rawMapRanges ρ)) (Val.mapRangesList ρ args)

  noncomputable def Arm.mapRangesList (ρ : Nat → RangeIx) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.mapRanges ρ m) :: Arm.mapRangesList ρ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.mapRanges ρ g))
          (Comp.mapRanges ρ m) :: Arm.mapRangesList ρ arms

  noncomputable def Clause.mapRangesList (ρ : Nat → RangeIx) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.mapRanges ρ m) :: Clause.mapRangesList ρ cs
    | .fail e m :: cs => .fail (Ty.rawMapRanges ρ e) (Comp.mapRanges ρ m) :: Clause.mapRangesList ρ cs
end
noncomputable def BuilderKind.mapRangesN (ρ : Nat → RangeIx) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (a.mapRanges ρ)

mutual
  noncomputable def Val.mapRangesN (ρ : Nat → RangeIx) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f (tys.map (Ty.mapRanges ρ)) (effs.map (Eff.mapRanges ρ)) (rs.map (mapIx ρ))
    | .prim b tys effs rs => .prim b (tys.map (Ty.mapRanges ρ)) (effs.map (Eff.mapRanges ρ)) (rs.map (mapIx ρ))
    | .lam names params body => .lam names (params.map (Ty.mapRanges ρ)) (Comp.mapRangesN ρ body)
    | .dependentLam t body => .dependentLam (Tel.mapRanges ρ t) (Comp.mapRangesN ρ body)
    | .closure t body => .closure t body
    | .con c tys args => .con c (tys.map (Ty.mapRanges ρ)) (Val.mapRangesListN ρ args)
    | .list elems => .list (Val.mapRangesListN ρ elems)
    | .op o tys => .op o (tys.map (Ty.mapRanges ρ))
    | .raise t e => .raise (Ty.mapRanges ρ t) (Ty.mapRanges ρ e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.mapRangesListN ρ ks) (Val.mapRangesListN ρ vs)
    | .setV elems => .setV (Val.mapRangesListN ρ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (Ty.mapRanges ρ)) (Val.mapRangesListN ρ args)
    | .super v cl => .super (Val.mapRangesN ρ v) cl
    | .externalRef f tys => .externalRef f (tys.map (Ty.mapRanges ρ))
    | .externalHandle h tys => .externalHandle h (tys.map (Ty.mapRanges ρ))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  noncomputable def Val.mapRangesListN (ρ : Nat → RangeIx) : List Val → List Val
    | [] => []
    | v :: vs => Val.mapRangesN ρ v :: Val.mapRangesListN ρ vs

  noncomputable def Comp.mapRangesN (ρ : Nat → RangeIx) : Comp → Comp
    | .builderLet k body => .builderLet (BuilderKind.mapRangesN ρ k) (Comp.mapRangesN ρ body)
    | .builderOp k op r args => .builderOp (BuilderKind.mapRangesN ρ k) op r (Val.mapRangesListN ρ args)
    | .ret v => .ret (Val.mapRangesN ρ v)
    | .letIn m n => .letIn (Comp.mapRangesN ρ m) (Comp.mapRangesN ρ n)
    | .app f args => .app (Val.mapRangesN ρ f) (Val.mapRangesListN ρ args)
    | .ite v m n => .ite (Val.mapRangesN ρ v) (Comp.mapRangesN ρ m) (Comp.mapRangesN ρ n)
    | .match v arms => .match (Val.mapRangesN ρ v) (Arm.mapRangesListN ρ arms)
    | .lazyC m => .lazyC (Comp.mapRangesN ρ m)
    | .escape v => .escape (Val.mapRangesN ρ v)
    | .use v m => .use (Val.mapRangesN ρ v) (Comp.mapRangesN ρ m)
    | .handle m h => .handle (Comp.mapRangesN ρ m) (Clause.mapRangesListN ρ h)
    | .resume k v => .resume (Val.mapRangesN ρ k) (Val.mapRangesN ρ v)
    | .externalCall f tys args => .externalCall f (tys.map (Ty.mapRanges ρ)) (Val.mapRangesListN ρ args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := Ty.mapRanges ρ sh.errorType}
        (match bs with | none => none | some b => some (b.mapRangesN ρ)) (p.mapRangesN ρ) (v.mapRangesN ρ) (mapIx ρ ix)
    | .meth d m tys effs args => .meth (Val.mapRangesN ρ d) m (tys.map (Ty.mapRanges ρ)) (effs.map (Eff.mapRanges ρ)) (Val.mapRangesListN ρ args)

  noncomputable def Arm.mapRangesListN (ρ : Nat → RangeIx) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.mapRangesN ρ m) :: Arm.mapRangesListN ρ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.mapRangesN ρ g))
          (Comp.mapRangesN ρ m) :: Arm.mapRangesListN ρ arms

  noncomputable def Clause.mapRangesListN (ρ : Nat → RangeIx) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.mapRangesN ρ m) :: Clause.mapRangesListN ρ cs
    | .fail e m :: cs => .fail (Ty.mapRanges ρ e) (Comp.mapRangesN ρ m) :: Clause.mapRangesListN ρ cs
end
noncomputable def Capture.mapRanges (ρ : Nat → RangeIx) : Capture → Capture
  | .mk vs => .mk (vs.map (Option.map (Val.mapRanges ρ)))

noncomputable def Closure.mapRanges (ρ : Nat → RangeIx) : Closure → Closure
  | .mk cap m => .mk (cap.mapRanges ρ) (m.mapRanges ρ)

noncomputable def Val.substR (c : Nat) (rs : List RangeExpr) (v : Val) : Val :=
  match rs with | [] => v | _ => v.mapRangesN (rangeAt c rs)
noncomputable def Comp.substR (c : Nat) (rs : List RangeExpr) (m : Comp) : Comp :=
  match rs with | [] => m | _ => m.mapRangesN (rangeAt c rs)
noncomputable def Val.instR (rs : List RangeExpr) (v : Val) : Val := v.substR 0 rs
noncomputable def Comp.instR (rs : List RangeExpr) (m : Comp) : Comp := m.substR 0 rs

/-- 種類の列に適合する、閉じた範囲の具体化。 -/
def RangesFit (rs : List RangeExpr) (ks : List Scope.Domain.Kind) : Prop :=
  rs.length = ks.length ∧
  (∀ (i : Nat) (r : RangeExpr) (k : Scope.Domain.Kind),
    rs[i]? = some r → ks[i]? = some k → r.FitsKind k) ∧
  (∀ r ∈ rs, r.WF ∧ r.Canonical)

/-- 利用者の関数では、種類に適合するすべての具体化を許す。 -/
def Def.RangeAdmissible (d : Def) (rs : List RangeExpr) : Prop := RangesFit rs d.rkinds

/-- 空の具体化は元の引数列を保ち、非空の具体化では範囲の置換と正規化を行う。 -/
noncomputable def Def.instTel (d : Def) (rs : List RangeExpr) : Tel :=
  match rs with | [] => d.tel | _ => Tel.instR rs d.tel

@[simp] theorem mapIx_id (r : RangeIx) : mapIx RangeIx.rvar r = r := by cases r <;> rfl
@[simp] theorem mapAtomRanges_id (a : Atom) : mapAtomRanges RangeIx.rvar a = a := by
  cases a <;> simp [mapAtomRanges]
@[simp] theorem mapRangeAtoms_id (a : Atom → Bool) : mapRangeAtoms RangeIx.rvar a = a := by
  classical
  funext x
  simp [mapRangeAtoms]

mutual
  @[simp] theorem Ty.rawMapRanges_id (a : Ty) : a.rawMapRanges RangeIx.rvar = a := by
    cases a <;> simp only [Ty.rawMapRanges, mapIx_id, mapRangesTys_id,
      Ty.rawMapRanges_id, Tel.rawMapRanges_id, Eff.rawMapRanges_id]
  @[simp] theorem Tel.rawMapRanges_id (t : Tel) : Tel.rawMapRanges RangeIx.rvar t = t := by
    cases t <;> simp only [Tel.rawMapRanges, Ty.rawMapRanges_id, Eff.rawMapRanges_id,
      Tel.rawMapRanges_id]
  @[simp] theorem mapRangesTys_id (as : List Ty) : mapRangesTys RangeIx.rvar as = as := by
    cases as <;> simp only [mapRangesTys, Ty.rawMapRanges_id, mapRangesTys_id]
  @[simp] theorem Eff.rawMapRanges_id (e : Eff) : Eff.rawMapRanges RangeIx.rvar e = e := by
    cases e; simp only [Eff.rawMapRanges, mapRangeAtoms_id, mapRangesTys_id]
end

@[simp] theorem Ty.rawMapRanges_id_fun : Ty.rawMapRanges RangeIx.rvar = id := funext Ty.rawMapRanges_id
@[simp] theorem Eff.rawMapRanges_id_fun : Eff.rawMapRanges RangeIx.rvar = id := funext Eff.rawMapRanges_id
@[simp] theorem mapIx_id_fun : mapIx RangeIx.rvar = id := funext mapIx_id

@[simp] theorem rangeAt_nil (c : Nat) : rangeAt c [] = RangeIx.rvar := by
  funext i
  simp [rangeAt]

@[simp] theorem BuilderKind.mapRanges_id (k : BuilderKind) : k.mapRanges RangeIx.rvar = k := by
  cases k <;> simp [BuilderKind.mapRanges]

mutual
  @[simp] theorem Val.mapRanges_id (v : Val) : v.mapRanges RangeIx.rvar = v := by
    cases v <;> simp [Val.mapRanges, Val.mapRangesList_id, Comp.mapRanges_id, Val.mapRanges_id]
  termination_by structural v
  @[simp] theorem Val.mapRangesList_id (vs : List Val) : Val.mapRangesList RangeIx.rvar vs = vs := by
    cases vs <;> simp [Val.mapRangesList, Val.mapRanges_id, Val.mapRangesList_id]
  termination_by structural vs
  @[simp] theorem Comp.mapRanges_id (m : Comp) : m.mapRanges RangeIx.rvar = m := by
    cases m with
    | checkAt k o sh bs p v ix =>
      cases bs <;> simp only [Comp.mapRanges, Ty.rawMapRanges_id, Val.mapRanges_id, mapIx_id]
    | _ => simp [Comp.mapRanges, Val.mapRanges_id, Val.mapRangesList_id,
        Comp.mapRanges_id, Arm.mapRangesList_id, Clause.mapRangesList_id]
  termination_by structural m
  @[simp] theorem Arm.mapRangesList_id (as : List Arm) : Arm.mapRangesList RangeIx.rvar as = as := by
    cases as with
    | nil => rfl
    | cons a as => cases a with
      | mk alts guard body => cases guard <;>
          simp [Arm.mapRangesList, Comp.mapRanges_id, Arm.mapRangesList_id]
  termination_by structural as
  @[simp] theorem Clause.mapRangesList_id (cs : List Clause) : Clause.mapRangesList RangeIx.rvar cs = cs := by
    cases cs with
    | nil => rfl
    | cons c cs => cases c <;>
        simp [Clause.mapRangesList, Comp.mapRanges_id, Clause.mapRangesList_id]
  termination_by structural cs
end

@[simp] theorem Val.instR_nil (v : Val) : v.instR [] = v := by simp [Val.instR, Val.substR]
@[simp] theorem Comp.instR_nil (m : Comp) : m.instR [] = m := by simp [Comp.instR, Comp.substR]
@[simp] theorem Def.instTel_nil (d : Def) : d.instTel [] = d.tel := by simp [Def.instTel]

/-- 実行時に、すべての範囲引数が固定範囲であることを検査する。 -/
def closedRanges : List RangeIx → Option (List RangeExpr)
  | [] => some []
  | .fixed r :: rs => (closedRanges rs).map (r :: ·)
  | .rvar _ :: _ => none

@[simp] theorem closedRanges_fixed (rs : List RangeExpr) :
    closedRanges (rs.map RangeIx.fixed) = some rs := by
  induction rs <;> simp_all [closedRanges]

theorem closedRanges_eq_some (rs : List RangeIx) (ρ : List RangeExpr) :
    closedRanges rs = some ρ ↔ rs = ρ.map RangeIx.fixed := by
  induction rs generalizing ρ with
  | nil => cases ρ <;> simp [closedRanges]
  | cons ix rs ih =>
    cases ix with
    | rvar i => cases ρ <;> simp [closedRanges]
    | fixed r =>
      cases ρ with
      | nil => simp [closedRanges]
      | cons s ρ =>
        simp only [closedRanges, Option.map_eq_some_iff, List.map_cons, List.cons.injEq,
          RangeIx.fixed.injEq]
        constructor
        · rintro ⟨xs,hxs,h⟩
          obtain ⟨rfl,rfl⟩ := h
          exact ⟨rfl,(ih _).mp hxs⟩
        · rintro ⟨rfl,h⟩
          exact ⟨ρ,(ih _).mpr h,rfl,rfl⟩

/-- 固定範囲列の値の読み出し。未具体化の項の実行には `closedRanges` の成功を別に要求する。 -/
def rangeValues (rs : List RangeIx) : List RangeExpr :=
  rs.map (fun ix => match ix with | .fixed r => r | .rvar _ => .top)

@[simp] theorem rangeValues_fixed (rs : List RangeExpr) :
    rangeValues (rs.map RangeIx.fixed) = rs := by simp [rangeValues, List.map_map, Function.comp_def]

theorem fixed_ranges_of_wf0 {rs : List RangeIx} (h : ∀ ix ∈ rs, ix.WF 0) :
    ∃ ρ : List RangeExpr, rs = ρ.map RangeIx.fixed := by
  induction rs with
  | nil => exact ⟨[],rfl⟩
  | cons ix rs ih =>
    obtain ⟨ρ,rfl⟩ := ih (fun ix hx => h ix (List.mem_cons_of_mem _ hx))
    cases ix with
    | fixed r => exact ⟨r :: ρ,rfl⟩
    | rvar i => have hi := h (.rvar i) (by simp); cases Nat.not_lt_zero i hi

theorem Def.instTel_of_ne_nil (d : Def) {rs : List RangeExpr} (h : rs ≠ []) :
    d.instTel rs = Tel.instR rs d.tel := by cases rs <;> simp_all [Def.instTel]

noncomputable def Capture.instR (rs : List RangeExpr) (cap : Capture) : Capture :=
  match rs, cap with
  | [], _ => cap
  | _, .mk vs => .mk (vs.map (Option.map (Val.instR rs)))
noncomputable def Closure.instR (rs : List RangeExpr) (c : Closure) : Closure :=
  match rs, c with
  | [], _ => c
  | _, .mk cap m => .mk (cap.instR rs) (m.instR rs)
noncomputable def Arm.instRList (rs : List RangeExpr) (as : List Arm) : List Arm :=
  match rs with | [] => as | _ => Arm.mapRangesListN (rangeAt 0 rs) as
noncomputable def Clause.instRList (rs : List RangeExpr) (cs : List Clause) : List Clause :=
  match rs with | [] => cs | _ => Clause.mapRangesListN (rangeAt 0 rs) cs

theorem Tel.names_rawMapRanges (t : Tel) (ρ : Nat → RangeIx) :
    (Tel.rawMapRanges ρ t).names = t.names := by
  cases t with
  | done => rfl
  | param n a t => simpa only [Tel.rawMapRanges, Tel.names] using congrArg (n :: ·) (Tel.names_rawMapRanges t ρ)

@[simp] theorem Def.instTel_names (d : Def) (rs : List RangeExpr) :
    (d.instTel rs).names = d.tel.names := by
  cases rs with
  | nil => rfl
  | cons r rs => simp only [Def.instTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.names_norm, Tel.names_rawMapRanges]

/-- 各種類は Top による適格な具体化を持つ。 -/
theorem RangesFit.top (ks : List Scope.Domain.Kind) :
    RangesFit (ks.map (fun _ => RangeExpr.top)) ks := by
  refine ⟨by simp, ?_, ?_⟩
  · intro i r k hr hk
    obtain ⟨_,_,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using hr)
    exact Scope.Domain.Range.top_fitsKind k
  · intro r hr
    obtain ⟨_,_,rfl⟩ := List.mem_map.mp hr
    exact ⟨trivial,trivial⟩

end Benitoite.Release.Refinement
