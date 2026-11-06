import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.CheckPropositional

/-!
# ソースと署名からの検査用証明書の構成

型と値の構造から、部分型・辞書・実引数の有限な候補を作る。
候補には型付けや含意の証明を格納せず、検査の成功は独立の再検査で判定する
（設計書 01-12「篩を含む表層の検査と受理」）。
-/
namespace Benitoite.Release.Refinement.Surface.CheckInfer
open CheckSubtyping CheckArguments CheckCompare

/-- 交換の証明書だけを読む。規則の木や中間の型・効果の表は持たない。 -/
structure Certificates where
  logic : List Nat → Nat → Option ExchangeCertificate := fun _ _ => none

/-- 明示された証明書を優先し、省略時は同じ前提又は閉じた述語の証明を試みる。 -/
def logicProof (certs : Certificates) (Φ : List Pred) (path : List Nat) (index : Nat)
    (goal : Pred) : LogicCertificate :=
  let raw : ExchangeCertificate := match certs.logic path index with
    | some proof => proof
    | none =>
        match ((Pred.ofConjuncts Φ).conjuncts.zipIdx.find? (fun (p, _) => predEq p goal)) with
        | some (_, i) => { certificate := .use i, actions := [] }
        | none =>
            let closed : ExchangeCertificate := { certificate := .leaf ⟨goal, .closed, [], []⟩, actions := [] }
            if goal.closedTrue then closed
            else (CheckPropositional.candidate Φ goal).getD closed
  { certificate := raw.certificate, actions := raw.actions, query := some ⟨path, Φ, goal⟩ }

mutual
  private def tyNodes : Ty → Nat
    | .data _ ts | .tapp _ ts | .external _ ts => 1 + typesNodes ts
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => 1 + tyNodes a
    | .fn _ ps a e => 1 + typesNodes ps + tyNodes a + effNodes e
    | .cont a b e => 1 + tyNodes a + tyNodes b + effNodes e
    | .map a b => 1 + tyNodes a + tyNodes b
    | .dependentFn t => 1 + telNodes t
    | _ => 1
  private def typesNodes : List Ty → Nat
    | [] => 1
    | a :: as => 1 + tyNodes a + typesNodes as
  private def telNodes : Tel → Nat
    | .done a e => 1 + tyNodes a + effNodes e
    | .param _ a t => 1 + tyNodes a + telNodes t
  private def effNodes : Eff → Nat
    | .mk _ fs => 1 + typesNodes fs
end

mutual
  private theorem tyNodes_shiftV (a : Ty) (k c : Nat) : tyNodes (a.shiftV k c) = tyNodes a := by
    cases a <;> simp only [Ty.shiftV, tyNodes]
    all_goals first | rfl | skip
    case data | tapp | external => rw [typesNodes_shiftV]
    case list | reference | lazy | set | dict | refined => rw [tyNodes_shiftV]
    case fn => rw [typesNodes_shiftV, tyNodes_shiftV, effNodes_shiftV]
    case cont => rw [tyNodes_shiftV, tyNodes_shiftV, effNodes_shiftV]
    case map => rw [tyNodes_shiftV, tyNodes_shiftV]
    case dependentFn => rw [telNodes_shiftV]
  private theorem typesNodes_shiftV (as : List Ty) (k c : Nat) :
      typesNodes (shiftVTys k c as) = typesNodes as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [shiftVTys, typesNodes, tyNodes_shiftV, typesNodes_shiftV]
  private theorem telNodes_shiftV (t : Tel) (k c : Nat) : telNodes (t.shiftV k c) = telNodes t := by
    cases t with
    | done a e => simp only [Tel.shiftV, telNodes, tyNodes_shiftV, effNodes_shiftV]
    | param n a t => simp only [Tel.shiftV, telNodes, tyNodes_shiftV, telNodes_shiftV]
  private theorem effNodes_shiftV (e : Eff) (k c : Nat) : effNodes (e.shiftV k c) = effNodes e := by
    cases e with
    | mk atoms fs => simp only [Eff.shiftV, effNodes, typesNodes_shiftV]
end

private theorem typesNodes_pos (as : List Ty) : 1 ≤ typesNodes as := by
  cases as <;> simp only [typesNodes] <;> omega

private theorem toTel_nodes (names : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    telNodes (Ty.toTel names ps r e) ≤ typesNodes ps + tyNodes r + effNodes e := by
  induction names generalizing ps r e with
  | nil =>
      simp only [Ty.toTel, telNodes]
      have hp := typesNodes_pos ps
      omega
  | cons name names ih =>
      cases ps with
      | nil => simp only [Ty.toTel, telNodes, typesNodes]; omega
      | cons a ps =>
          simp only [Ty.toTel, telNodes, typesNodes]
          have hh := ih (shiftVTys 1 0 ps) (r.shiftV 1 0) (e.shiftV 1 0)
          simp only [typesNodes_shiftV, tyNodes_shiftV, effNodes_shiftV] at hh
          omega

private def leWeight (a b : Ty) : Nat := 3 * (tyNodes a + tyNodes b) + 2
private def functionWeight (t u : Tel) : Nat := 3 * (telNodes t + telNodes u) + 1
private def telescopeWeight (t u : Tel) : Nat := 3 * (telNodes t + telNodes u)
private def argumentsWeight (as bs : List Ty) : Nat := 3 * (typesNodes as + typesNodes bs)

mutual
  private def leFuel (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
      (path : List Nat) (index : Nat) :
      (fuel : Nat) → (a b : Ty) → leWeight a b < fuel → LeCertificate
    | 0, _, _, h => False.elim (Nat.not_lt_zero _ h)
    | n+1, a, b, h =>
      if rawTyEq q.formation.atoms a b then .refl a else
      if normTyEq q.formation.atoms a b then .convert a b else
      match ha : a, hb : b with
      | .refined x p, .refined y r =>
          .refine (leFuel q certs Γ Φ (path ++ [0]) 0 n x y (by
            simp_all only [leWeight, tyNodes] <;> omega)) p r
            (logicProof certs (p :: assumptions Γ Φ x) path index r)
      | .refined x p, b =>
          .trans (.forget x p) (leFuel q certs Γ Φ (path ++ [0]) 0 n x b (by
            simp_all only [leWeight, tyNodes] <;> omega))
      | a, .refined y r =>
          .trans (leFuel q certs Γ Φ (path ++ [0]) 0 n a y (by
            simp_all only [leWeight, tyNodes] <;> omega))
            (.introduce y r (logicProof certs (assumptions Γ Φ y) path index r))
      | .list x, .list y => .list (leFuel q certs Γ Φ path index n x y (by
          simp_all only [leWeight, tyNodes] <;> omega))
      | .lazy x, .lazy y => .lazy (leFuel q certs Γ Φ path index n x y (by
          simp_all only [leWeight, tyNodes] <;> omega))
      | .map k x, .map l y =>
          if normTyEq q.formation.atoms k l then
            .trans (.mapValue k (leFuel q certs Γ Φ path index n x y (by
              simp_all only [leWeight, tyNodes] <;> omega)))
              (.convert (.map k y) (.map l y))
          else .convert a b
      | .scoped o k x, .scoped p l y =>
          if decide (o = p ∧ k = l) then .scoped o k x y else .convert a b
      | .scoped o k x, .opaque p y =>
          if decide (o = p) then .trans (.scopedForget o k x) (.convert (.opaque o x) (.opaque p y))
          else .convert a b
      | .data d xs, .data e ys =>
          if decide (d = e) then
            .data d (argumentsFuel q certs Γ Φ path index n (q.D.core.varianceFor d xs.length) xs ys (by
              simp_all only [leWeight, argumentsWeight, tyNodes] <;> omega))
          else .convert a b
      | .fn ns ps r e, .fn ms qs t f =>
          if decide (ns = ms) && tysEq q.formation.atoms ps qs && rawTyEq q.formation.atoms r t then
            .trans (.fnEffect ns ps r e f) (.convert (.fn ns ps r f) b)
          else functionFuel q certs Γ Φ path index n a b (Ty.toTel ns ps r e) (Ty.toTel ms qs t f) (by
            have hl := toTel_nodes ns ps r e
            have hr := toTel_nodes ms qs t f
            simp_all only [leWeight, functionWeight, tyNodes] <;> omega)
      | .dependentFn t, .dependentFn u => functionFuel q certs Γ Φ path index n a b t u (by
          simp_all only [leWeight, functionWeight, tyNodes] <;> omega)
      | .fn ns ps r e, .dependentFn t => functionFuel q certs Γ Φ path index n a b (Ty.toTel ns ps r e) t (by
          have hl := toTel_nodes ns ps r e
          simp_all only [leWeight, functionWeight, tyNodes] <;> omega)
      | .dependentFn t, .fn ns ps r e => functionFuel q certs Γ Φ path index n a b t (Ty.toTel ns ps r e) (by
          have hr := toTel_nodes ns ps r e
          simp_all only [leWeight, functionWeight, tyNodes] <;> omega)
      | _, _ => .convert a b
  termination_by structural fuel _ _ _ => fuel

  private def functionFuel (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
      (path : List Nat) (index : Nat) :
      (fuel : Nat) → Ty → Ty → (t u : Tel) → functionWeight t u < fuel → LeCertificate
    | 0, _, _, _, _, h => False.elim (Nat.not_lt_zero _ h)
    | n+1, a, b, t, u, h =>
      match telescopeFuel q certs Γ Φ path index n t u (by
        simp_all only [functionWeight, telescopeWeight] <;> omega) with
      | none => .convert a b
      | some c => .trans (.convert a (.dependentFn t))
          (.trans (.dependentFn (.tail (.refl t) c)) (.convert (.dependentFn u) b))
  termination_by structural fuel _ _ _ _ _ => fuel

  private def telescopeFuel (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
      (path : List Nat) (index : Nat) :
      (fuel : Nat) → (t u : Tel) → telescopeWeight t u < fuel → Option TelCertificate
    | 0, _, _, h => False.elim (Nat.not_lt_zero _ h)
    | n+1, .done a e, .done b f, h => some (.done (leFuel q certs Γ Φ path index n a b (by
        simp_all only [leWeight, telescopeWeight, telNodes] <;> omega)) e f)
    | n+1, .param name a rest, .param other b tail, h =>
        if name = other then do
          let cs ← telescopeFuel q certs (Γ.extend b) (Φ.map Pred.lift) (path ++ [1]) 0 n rest tail (by
            simp_all only [telescopeWeight, telNodes] <;> omega)
          pure (.param name (leFuel q certs Γ Φ (path ++ [0]) index n b a (by
            simp_all only [leWeight, telescopeWeight, telNodes] <;> omega)) cs)
        else none
    | _+1, _, _, _ => none
  termination_by structural fuel _ _ _ => fuel

  private def argumentsFuel (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
      (path : List Nat) (index : Nat) :
      (fuel : Nat) → List Variance → (as bs : List Ty) → argumentsWeight as bs < fuel → TypeArgsCertificate
    | 0, _, _, _, h => False.elim (Nat.not_lt_zero _ h)
    | _+1, [], [], [], _ => .nil
    | n+1, .covariant :: ks, a :: as, b :: bs, h =>
        .covariant (leFuel q certs Γ Φ (path ++ [0]) index n a b (by
          simp_all only [leWeight, argumentsWeight, typesNodes] <;> omega))
          (argumentsFuel q certs Γ Φ (path ++ [1]) 0 n ks as bs (by
            simp_all only [argumentsWeight, typesNodes] <;> omega))
    | n+1, .contravariant :: ks, a :: as, b :: bs, h =>
        .contravariant (leFuel q certs Γ Φ (path ++ [0]) index n b a (by
          simp_all only [leWeight, argumentsWeight, typesNodes] <;> omega))
          (argumentsFuel q certs Γ Φ (path ++ [1]) 0 n ks as bs (by
            simp_all only [argumentsWeight, typesNodes] <;> omega))
    | n+1, .invariant :: ks, a :: as, b :: bs, h =>
        .invariant a b (argumentsFuel q certs Γ Φ (path ++ [1]) 0 n ks as bs (by
          simp_all only [argumentsWeight, typesNodes] <;> omega))
    | _+1, _, _, _, _ => .nil
  termination_by structural fuel _ _ _ _ => fuel
end

/-- 型の有限な構造から部分型の候補を作り、含意の位置で交換の証明書を読む。
型の節数から十分な再帰の深さを導き、各再帰でその十分性を保つ。打切りによる拒否は生じない。 -/
def inferLe (q : Check.Input) (certs : Certificates) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (index : Nat) (source target : Ty) : LeCertificate :=
  leFuel q certs Γ Φ path index (4 * (tyNodes source + tyNodes target + 1)) source target (by
    simp only [leWeight]
    omega)

mutual
  /-- 辞書の宣言と局所の文脈から、その型と検査の案内を計算する。 -/
  def inferDict (q : Check.Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat) :
      DictEv → Option (Ty × DictGuide)
    | .local i => do
        let a ← (Γ[i]?).join
        pure (a, .local)
    | .clause scope i depth => do
        let a ← (Γ[depth + scope.slot i]?).join
        pure (a, .clause)
    | .impl i ts ds => do
        let id ← q.D.impls i
        let gs ← inferDicts q C Γ (path ++ [0]) ds
        pure (.dict id.cls (CheckFormation.substTy q.formation ts [] id.target), .impl gs)
    | .super d s => do
        let (.dict owner a, g) ← inferDict q C Γ (path ++ [0]) d | none
        pure (.dict s a, .super owner a g)
  termination_by d => sizeOf d
  decreasing_by all_goals (simp_wf <;> omega)

  def inferDicts (q : Check.Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat) :
      List DictEv → Option (List DictGuide)
    | [] => some []
    | d :: ds => do
        let (_, g) ← inferDict q C Γ (path ++ [0]) d
        let gs ← inferDicts q C Γ (path ++ [1]) ds
        pure (g :: gs)
  termination_by ds => sizeOf ds
  decreasing_by all_goals (simp_wf <;> omega)
end

/-- メソッドの頭だけが辞書の所有クラスと対象型を必要とする。 -/
def inferHeadGuide (q : Check.Input) (C : TypeCtx) (Γ : Ctx) (path : List Nat) : Expr → Option HeadGuide
  | .methName d _ _ _ _ _ _ => do
      let (.dict owner target, dg) ← inferDict q C Γ path d | none
      pure (.method owner target dg)
  | _ => some .plain

mutual
  private def valueDictionary (k : Nat) : Val → Option DictEv
    | .var j => if k ≤ j then some (.local (j-k)) else none
    | .dict i ts vs => do
        let ds ← valuesDictionaries k vs
        pure (.impl i (ts.map (fun a => a.renameValues (unshiftValue k 0))) ds)
    | .super d c => do
        let d ← valueDictionary k d
        pure (.super d c)
    | _ => none
  termination_by v => sizeOf v
  decreasing_by all_goals (simp_wf <;> omega)

  private def valuesDictionaries (k : Nat) : List Val → Option (List DictEv)
    | [] => some []
    | v :: vs => do
        let d ← valueDictionary k v
        let ds ← valuesDictionaries k vs
        pure (d :: ds)
  termination_by vs => sizeOf vs
  decreasing_by all_goals (simp_wf <;> omega)
end

mutual
  /-- 値の実引数の型を計算し、必要なら同じ値について篩を導入する候補を作る。 -/
  def inferArg (q : Check.Input) (certs : Certificates) (C : TypeCtx) (Γ0 : Ctx) (k : Nat)
      (Γ : Ctx) (Φ : List Pred) (path : List Nat) (v : Val) (expected : Ty) : Option (Ty × ArgGuide) := do
    match expected with
    | .refined base p =>
        let (actual, guide) ← inferArg q certs C Γ0 k Γ Φ (path ++ [0]) v base
        let some sort := actual.sort? | none
        let some t := v.toTerm? | none
        pure (.refined actual p, .refine actual p sort
          (logicProof certs (Γ.facts ++ Φ) path 0 (p.open t)) guide)
    | _ => match v with
      | .var j => do
          let a ← (Γ[j]?).join
          pure (a, ArgGuide.var)
      | .const c => pure (c.type, ArgGuide.const)
      | .list vs => do
          let .list a := expected | none
          let gs ← inferElems q certs C Γ0 k Γ Φ (path ++ [0]) vs a
          pure (.list a, .list gs)
      | _ => do
          let d ← valueDictionary k v
          let (a, dg) ← inferDict q C Γ0 path d
          pure (a.shiftV k 0, .dictionary d a dg)
  termination_by (sizeOf v, sizeOf expected)
  decreasing_by all_goals (simp_wf <;> omega)

  def inferElems (q : Check.Input) (certs : Certificates) (C : TypeCtx) (Γ0 : Ctx) (k : Nat)
      (Γ : Ctx) (Φ : List Pred) (path : List Nat) : List Val → Ty → Option (List ElemGuide)
    | [], _ => some []
    | v :: vs, a => do
        let (b, g) ← inferArg q certs C Γ0 k Γ Φ (path ++ [0]) v a
        let gs ← inferElems q certs C Γ0 k Γ Φ (path ++ [1]) vs a
        pure (.mk b g (inferLe q certs Γ Φ (path ++ [0]) 1 b a) :: gs)
  termination_by vs a => (sizeOf vs, sizeOf a)
  decreasing_by all_goals (simp_wf <;> omega)
end

/-- 位置ごとの期待型に対し、値の実引数と部分型の候補を並べる。 -/
def inferValsTys (q : Check.Input) (certs : Certificates) (C : TypeCtx) (Γ0 : Ctx) (k : Nat)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) : List Val → List Ty → Option (List ElemGuide)
  | [], [] => some []
  | v :: vs, a :: as => do
      let (b, g) ← inferArg q certs C Γ0 k Γ Φ (path ++ [1]) v a
      let gs ← inferValsTys q certs C Γ0 k Γ Φ (path ++ [2]) vs as
      pure (.mk b g (inferLe q certs Γ Φ path 0 b a) :: gs)
  | _, _ => none

/-- 実引数を宣言順に具体化し、依存列の末尾の型と効果も計算する。 -/
def inferValsTel (q : Check.Input) (certs : Certificates) (C : TypeCtx) (Γ0 : Ctx) (k : Nat)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) : List Val → Tel → Option (Ty × Eff × List ElemGuide)
  | [], .done a e => some (a, e, [])
  | v :: vs, .param _ a rest => do
      let (b, g) ← inferArg q certs C Γ0 k Γ Φ (path ++ [1]) v a
      let (r, e, gs) ← inferValsTel q certs C Γ0 k Γ Φ (path ++ [2]) vs
        (CheckFormation.bindValueTel q.formation v rest)
      pure (r, e, .mk b g (inferLe q certs Γ Φ path 0 b a) :: gs)
  | _, _ => none


mutual
  private def binderRoutes (q : Check.Input) (pattern : Pat) (type : Ty)
      (route : List FieldRef) (raw : Nat) : List (Nat × List FieldRef × Ty) :=
    match pattern with
    | .var => [(raw, route, type)]
    | .con c ps => match q.D.cons c, (type.normWith q.formation.atoms).core with
      | some cd, .data owner ts =>
          if cd.data = owner ∧ cd.ntys = ts.length then
            binderRoutesList q c cd.data ts ps cd.args route raw 0
          else []
      | _, _ => []
    | _ => []
  termination_by sizeOf pattern
  decreasing_by all_goals (simp_wf <;> omega)

  private def binderRoutesList (q : Check.Input) (constructor : ConName) (owner : DataName) (ts : List Ty) :
      List Pat → List Ty → List FieldRef → Nat → Nat → List (Nat × List FieldRef × Ty)
    | [], _, _, _, _ => []
    | p :: ps, a :: as, route, raw, position =>
        let type := CheckFormation.substTy q.formation ts [] a
        let here := match type.sort? with
          | none => []
          | some sort => binderRoutes q p type (route ++ [⟨owner, constructor, position, sort⟩]) raw
        here ++ binderRoutesList q constructor owner ts ps as route (raw + p.binders) (position + 1)
    | _, _, _, _, _ => []
  termination_by ps _ _ _ _ => sizeOf ps
  decreasing_by all_goals (simp_wf <;> omega)
end

/-- 単一の構成子のパターンから、整数欄と List の長さに使う束縛の経路を計算する。 -/
def inferFieldLinks (q : Check.Input) (alts : List Alt) (scrutineeType : Ty) : List FieldLink :=
  match alts with
  | [alt@⟨.con _ _, _⟩] =>
      (binderRoutes q alt.pat scrutineeType [] 0).flatMap fun (raw, route, type) =>
        if route.isEmpty then [] else
        match alt.slots.zipIdx.find? (fun (i, _) => decide (i = raw)), type.sort? with
        | some (_, slot), some .integer => [⟨slot, raw, route, none⟩]
        | some (_, slot), some .list => [⟨slot, raw, route, some .listLength⟩]
        | _, _ => []
  | _ => []

end Benitoite.Release.Refinement.Surface.CheckInfer
