import Benitoite.Release.Typing
import Benitoite.Release.Lemmas.TySubst

/-!
# 網羅性の検査の手順と健全性（TODO-162、E1a-1・E1a-2・E1b-1）

02-05「本体の後の検査」の有用性の手順を、Q3・Q4 の決定に従って定義する。
`none` だけを健全性の主張に使う。反例は、実在する値とは限らない（残りの値や空の型の構成子も含む）。
任意の燃料について健全性を証明する。既存の型付け・照合・実行の定義は変更しない。
-/

namespace Benitoite.Release

/-- 一覧には、宣言のあるすべての構成子を含める。余分な名前と重複は許す。 -/
def CtorsComplete (P : Program) (ctors : DataName → List ConName) : Prop :=
  ∀ c cd, P.cons c = some cd → c ∈ ctors cd.data

/-- 反例の形。区間の端は符号位置を含めて `Int` のまま保持する。
`other` は列のどのリテラル・範囲にも照合しない残りの値、`wild` は任意の値を表す。
`long min before after` は長さ `min` 以上のリストである。 -/
inductive CoverageWitness where
  | wild
  | other
  | con (c : ConName) (args : List CoverageWitness)
  | invalidCon (c : ConName)
  | boolean (b : Bool)
  | unit
  | interval (character : Bool) (lo hi : Int)
  | string (s : String)
  | exact (elems : List CoverageWitness)
  | long (min : Nat) (before after : List CoverageWitness)
  deriving Repr

/-- 燃料切れを差分テストで数えられるように、判定とは別に記録する。 -/
structure UsefulnessResult where
  witness : Option (List CoverageWitness)
  fuelExhausted : Bool := false
  deriving Repr

namespace Coverage

def isWild : Pat → Bool
  | .wild | .var => true
  | _ => false

mutual
  /-- 型引数だけの置換の評価用の写し。既存の Ty.substAt は整礎再帰なので使わない。
  深さ 0 の型置換は、置換する型を shift する必要がなく、空のエフェクト置換は恒等である。 -/
  def substTy (ts : List Ty) : Ty → Ty
    | .base b => .base b
    | .opaque o => .opaque o
    | .data d args => .data d (substTys ts args)
    | .list a => .list (substTy ts a)
    | .fn ps r eff => .fn (substTys ts ps) (substTy ts r) eff
    | .tvar i => if i < ts.length then (ts[i]?).getD (.tvar i) else .tvar (i - ts.length)
    | .reference a => .reference (substTy ts a)
    | .lazy a => .lazy (substTy ts a)
    | .cont b t eff => .cont (substTy ts b) (substTy ts t) eff
    | .map k v => .map (substTy ts k) (substTy ts v)
    | .set a => .set (substTy ts a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (substTy ts a)
    | .tapp i args =>
        if i < ts.length then Ty.applyTo ((ts[i]?).getD (.tvar i)) (substTys ts args)
        else .tapp (i - ts.length) (substTys ts args)
    | .ctor c => .ctor c
  def substTys (ts : List Ty) : List Ty → List Ty
    | [] => []
    | a :: as => substTy ts a :: substTys ts as
end

mutual
  /-- 評価用の型置換と Inhabits.con の既存の置換を接続する。 -/
  theorem substTy_eq (ts : List Ty) : (a : Ty) → substTy ts a = Ty.subst ts [] a
    | .base _ => by simp [substTy, Ty.subst, Ty.substAt]
    | .opaque _ => by simp [substTy, Ty.subst, Ty.substAt]
    | .data _ as => by simp [substTy, Ty.subst, Ty.substAt, substTys_eq]
    | .list a => by simp [substTy, Ty.subst, Ty.substAt, substTy_eq ts a]
    | .fn ps r e => by
        simp [substTy, Ty.subst, Ty.substAt, substTys_eq, substTy_eq ts r, Eff.substRho_nil]
    | .tvar i => by simp [substTy, Ty.subst, Ty.substAt, Ty.shift_zero]
    | .reference a => by simp [substTy, Ty.subst, Ty.substAt, substTy_eq ts a]
    | .lazy a => by simp [substTy, Ty.subst, Ty.substAt, substTy_eq ts a]
    | .cont b t e => by
        simp [substTy, Ty.subst, Ty.substAt, substTy_eq ts b, substTy_eq ts t, Eff.substRho_nil]
    | .map k v => by simp [substTy, Ty.subst, Ty.substAt, substTy_eq ts k, substTy_eq ts v]
    | .set a => by simp [substTy, Ty.subst, Ty.substAt, substTy_eq ts a]
    | .bytes => by simp [substTy, Ty.subst, Ty.substAt]
    | .dict _ a => by simp [substTy, Ty.subst, Ty.substAt, substTy_eq ts a]
    | .tapp i as => by simp [substTy, Ty.subst, Ty.substAt, substTys_eq, Ty.shift_zero]
    | .ctor _ => by simp [substTy, Ty.subst, Ty.substAt]

  theorem substTys_eq (ts : List Ty) : (as : List Ty) → substTys ts as = as.map (Ty.subst ts [])
    | [] => rfl
    | a :: as => by simp only [substTys, List.map_cons]; rw [substTy_eq, substTys_eq]
end

/-- 宣言の所属と型引数の数も検査し、`Inhabits.con` と同じ型置換をする。 -/
def conFields (P : Program) (d : DataName) (ts : List Ty) (c : ConName) :
    Option (List Ty) := do
  let cd ← P.cons c
  if cd.data = d ∧ cd.ntys = ts.length then
    some (substTys ts cd.args)
  else none

/-- 行の先頭を照合しないものとして除く検査。問いの失敗は有用とする。
型パラメータなどでは値の形が任意なので、非ワイルドカードの問いを有用側に倒す。 -/
def compatible (P : Program) (ty : Ty) (p : Pat) : Bool :=
  if isWild p then true else
  match ty, p with
  | .base .integer, .const (.integer _) => true
  | .base .integer, .range (.integer _) (.integer _) => true
  | .base .character, .const (.character _) => true
  | .base .character, .range (.character _) (.character _) => true
  | .base .boolean, .const (.boolean _) => true
  | .base .unit, .const .unit => true
  | .base .string, .const (.string _) => true
  | .data d ts, .con c ps =>
      match conFields P d ts c with
      | some fields => ps.length == fields.length
      | none => false
  | .list _, .list _ _ _ => true
  | _, _ => false

/-- Integer と Character を混ぜない。逆向きの区間は空なので端の一覧には加えない。 -/
def interval (ty : Ty) (p : Pat) : Option (Int × Int) :=
  let ends := match ty, p with
    | .base .integer, .const (.integer n) => some (n, n)
    | .base .integer, .range (.integer lo) (.integer hi) => some (lo, hi)
    | .base .character, .const (.character c) => some (Int.ofNat c.toNat, Int.ofNat c.toNat)
    | .base .character, .range (.character lo) (.character hi) =>
        some (Int.ofNat lo.toNat, Int.ofNat hi.toNat)
    | _, _ => none
  ends.filter fun e => e.1 ≤ e.2

/-- 挿入整列。整礎再帰を使う標準の mergeSort は評価例で使わない。 -/
def insertEnd (x : Int) : List Int → List Int
  | [] => [x]
  | y :: ys => if x ≤ y then x :: y :: ys else y :: insertEnd x ys

def sortEnds : List Int → List Int
  | [] => []
  | x :: xs => insertEnd x (sortEnds xs)

/-- 元の端から、v 以下の最大の端を求める。整列と重複除去には依存しない。 -/
def lowerEnd (bounds : List Int) (v : Int) : Option Int :=
  bounds.foldl (fun best x =>
    if x ≤ v then some ((best.map (max x)).getD x) else best) none

/-- 元の端から、v より大きい最小の端を求める。上端はこの端から 1 を引いた値。 -/
def upperEnd (bounds : List Int) (v : Int) : Option Int :=
  bounds.foldl (fun best x =>
    if v < x then some ((best.map (min x)).getD x) else best) none

/-- 値を含む区間を、端の極値から直接求める。両側の端がないときは区間なし。 -/
def intervalAt (bounds : List Int) (v : Int) : Option (Int × Int) := do
  let lo ← lowerEnd bounds v
  let next ← upperEnd bounds v
  pure (lo, next - 1)

/-- 整列と重複除去は反例の列挙順だけに使い、区間自体は元の端から求める。 -/
def segments (bounds : List Int) : List (Int × Int) :=
  (sortEnds bounds).eraseDups.filterMap (intervalAt bounds)

inductive Shape where
  | con (c : ConName) (fields : List Ty)
  | invalidCon (c : ConName)
  | boolean (b : Bool)
  | unit
  | interval (character : Bool) (lo hi : Int)
  | string (s : String)
  | exact (n : Nat) (elem : Ty)
  | long (min front back : Nat) (elem : Ty)
  | other

def Shape.fields : Shape → List Ty
  | .con _ fields => fields
  | .exact n a => List.replicate n a
  | .long _ front back a => List.replicate (front + back) a
  | _ => []

/-- exactEnd は残りのないパターンがないとき 0。そうでなければ最大長 + 1。 -/
def listBounds (column : List Pat) : Nat × Nat × Nat :=
  column.foldl (fun (exactEnd, front, back) p =>
    match p with
    | .list before none after => (max exactEnd (before.length + after.length + 1), front, back)
    | .list before (some _) after => (exactEnd, max front before.length, max back after.length)
    | _ => (exactEnd, front, back)) (0, 0, 0)

/-- 列は問いの先頭も含む。区間の隙間を外側とともに `other` に含める。
サロゲートだけの区間を除き、それ以外の端は Char に戻さない。 -/
def shapes (P : Program) (ctors : DataName → List ConName) (ty : Ty)
    (column : List Pat) : List Shape :=
  match ty with
  | .data d ts => (ctors d).map fun c =>
      match conFields P d ts c with
      | some fields => .con c fields
      | none => .invalidCon c
  | .base .boolean => [.boolean true, .boolean false]
  | .base .unit => [.unit]
  | .base .integer | .base .character =>
      let chars := match ty with | .base .character => true | _ => false
      let intervals := column.filterMap (interval ty)
      let bounds := intervals.flatMap fun (lo, hi) => [lo, hi + 1]
      let covered := (segments bounds).filter fun (lo, hi) =>
        intervals.any (fun (a, b) => a ≤ lo && hi ≤ b) &&
          !(chars && lo ≥ 0xD800 && hi ≤ 0xDFFF)
      .other :: covered.map (fun (lo, hi) => .interval chars lo hi)
  | .base .string =>
      let strings := column.filterMap fun p =>
        match p with | .const (.string s) => some s | _ => none
      .other :: strings.eraseDups.map Shape.string
  | .list a =>
      let (exactEnd, front, back) := listBounds column
      let min := max exactEnd (front + back)
      (List.range min).map (fun n => .exact n a) ++ [.long min front back a]
  | _ => [.other]

/-- 型と合う定数しか特殊化しない。リストの残りなしは before ++ after の固定長。 -/
def specialize (p : Pat) (s : Shape) : Option (List Pat) :=
  if isWild p then some (List.replicate s.fields.length .wild) else
  match p, s with
  | .con c ps, .con d fields =>
      if c = d ∧ ps.length = fields.length then some ps else none
  | .const (.boolean a), .boolean b => if a = b then some [] else none
  | .const .unit, .unit => some []
  | .const (.string a), .string b => if a = b then some [] else none
  | p, .interval chars lo hi => do
      let (a, b) ← interval (if chars then .base .character else .base .integer) p
      if a ≤ lo ∧ hi ≤ b then some [] else none
  | .list before rest after, .exact n _ =>
      let count := before.length + after.length
      if (if rest.isSome then count ≤ n else count = n) then
        some (before ++ List.replicate (n - count) .wild ++ after)
      else none
  | .list before (some _) after, .long min front back _ =>
      let count := before.length + after.length
      if count ≤ min ∧ before.length ≤ front ∧ after.length ≤ back then
        some (before ++ List.replicate (front + back - count) .wild ++ after)
      else none
  | _, _ => none

def specializeRows (s : Shape) (rows : List (List Pat)) : List (List Pat) :=
  rows.filterMap fun row => do
    let p ← row.head?
    let args ← specialize p s
    pure (args ++ row.tail)

def Shape.witness (s : Shape) (args : List CoverageWitness) : CoverageWitness :=
  match s with
  | .con c _ => .con c args
  | .invalidCon c => .invalidCon c
  | .boolean b => .boolean b
  | .unit => .unit
  | .interval chars lo hi => .interval chars lo hi
  | .string s => .string s
  | .exact _ _ => .exact args
  | .long min front _ _ => .long min (args.take front) (args.drop front)
  | .other => .other

mutual
  /-- 空の行列・不整合・燃料切れでは問いの形を保存する。Float の比較は行わない。 -/
  def queryWitness : Pat → CoverageWitness
    | .wild | .var => .wild
    | .const c => match c with
        | .integer n => .interval false n n
        | .character c => .interval true (Int.ofNat c.toNat) (Int.ofNat c.toNat)
        | .boolean b => .boolean b
        | .unit => .unit
        | .string s => .string s
        | _ => .wild
    | .con c ps => .con c (queryWitnessList ps)
    | .range lo hi => match lo, hi with
        | .integer lo, .integer hi => .interval false lo hi
        | .character lo, .character hi => .interval true (Int.ofNat lo.toNat) (Int.ofNat hi.toNat)
        | _, _ => .wild
    | .list before rest after => match rest with
        | none => .exact (queryWitnessList before ++ queryWitnessList after)
        | some _ =>
            .long (before.length + after.length) (queryWitnessList before) (queryWitnessList after)
  def queryWitnessList : List Pat → List CoverageWitness
    | [] => []
    | p :: ps => queryWitness p :: queryWitnessList ps
end

def fallback (q : List Pat) (exhausted : Bool := false) : UsefulnessResult :=
  ⟨some (queryWitnessList q), exhausted⟩

/-- 構成子の順に、最初の有用な反例を選ぶ。 -/
def firstUseful (f : Shape → UsefulnessResult) : List Shape → UsefulnessResult
  | [] => ⟨none, false⟩
  | s :: ss =>
      let r := f s
      if r.witness.isSome then r else firstUseful f ss

/-- 燃料だけを一つずつ減らす構造的な再帰。各段で長さの違う行を落とす。
燃料切れ、不整合、どの構成子にも特殊化できない非ワイルドカードの問いは有用とする。 -/
def usefulFuel (P : Program) (ctors : DataName → List ConName) :
    Nat → List Ty → List (List Pat) → List Pat → UsefulnessResult
  | 0, _, _, q => fallback q true
  | fuel + 1, tys, matrix, query =>
      let rows := matrix.filter fun row => row.length == query.length && row.length == tys.length
      if tys.length != query.length then fallback query else
      match tys, query with
      | [], [] => if rows.isEmpty then ⟨some [], false⟩ else ⟨none, false⟩
      | ty :: typesTail, q :: tail =>
          if !compatible P ty q then fallback query else
          let rows := rows.filter fun row => (row.head?).any (compatible P ty)
          if rows.any (List.all · isWild) then ⟨none, false⟩ else
          if rows.isEmpty then fallback query else
          let column := rows.filterMap List.head? ++ [q]
          if column.all isWild then
            let r := usefulFuel P ctors fuel typesTail (rows.map List.tail) tail
            { r with witness := r.witness.map (CoverageWitness.wild :: ·) }
          else
            let ss := shapes P ctors ty column
            if !isWild q && !(ss.any fun s => (specialize q s).isSome) then fallback query else
            firstUseful (fun s =>
              match specialize q s with
              | none => ⟨none, false⟩
              | some args =>
                  let fields := s.fields
                  let r := usefulFuel P ctors fuel (fields ++ typesTail)
                    (specializeRows s rows) (args ++ tail)
                  match r.witness with
                  | none => r
                  | some ws =>
                      if ws.length = fields.length + tail.length then
                        { r with witness := some (s.witness (ws.take fields.length) :: ws.drop fields.length) }
                      else fallback query r.fuelExhausted) ss
      | _, _ => fallback query

mutual
  /-- ワイルドカードでない節の数 N。 -/
  def nodes : Pat → Nat
    | .wild | .var => 0
    | .con _ ps => 1 + nodesList ps
    | .list before _ after => 1 + nodesList before + nodesList after
    | _ => 1
  def nodesList : List Pat → Nat
    | [] => 0
    | p :: ps => nodes p + nodesList ps
end

mutual
  /-- 入力の構成子の節ごとに、宣言のデータ型の全構成子の引数数を足す。
  宣言のない構成子は 0。リストは前後の長さも足す。 -/
  def arityBudget (P : Program) (ctors : DataName → List ConName) : Pat → Nat
    | .con c ps =>
        ((P.cons c).map (fun cd =>
          ((ctors cd.data).map (fun name =>
            ((P.cons name).map (fun decl => decl.args.length)).getD 0)).sum)).getD 0 +
          arityBudgetList P ctors ps
    | .list before _ after =>
        before.length + after.length + arityBudgetList P ctors before + arityBudgetList P ctors after
    | _ => 0
  def arityBudgetList (P : Program) (ctors : DataName → List ConName) : List Pat → Nat
    | [] => 0
    | p :: ps => arityBudget P ctors p + arityBudgetList P ctors ps
end

/-- N * (A + 1) + 初めの列数 + 1。十分性は主張せず、燃料切れは別に記録する。 -/
def fuelFor (P : Program) (ctors : DataName → List ConName)
    (tys : List Ty) (rows : List (List Pat)) (q : List Pat) : Nat :=
  let ps := rows.flatten ++ q
  nodesList ps * (arityBudgetList P ctors ps + 1) + max tys.length q.length + 1

/-- 処理系の overlaps の特殊化を燃料について構造的に再帰する。
非ワイルドカードの再帰では入力の子だけを比較し、増えたワイルドカードでは直ちに止まる。 -/
def overlapsFuel (P : Program) (ctors : DataName → List ConName) :
    Nat → Ty → Pat → Pat → Bool
  | 0, _, _, _ => false
  | fuel + 1, ty, a, b =>
      if isWild a || isWild b then true else
      (shapes P ctors ty [a, b]).any fun s =>
        match specialize a s, specialize b s with
        | some xs, some ys =>
            xs.length == ys.length &&
              (s.fields.zip (xs.zip ys)).all (fun (t, x, y) => overlapsFuel P ctors fuel t x y)
        | _, _ => false

/-! ## 照合と値の並びの補題 -/

@[simp] theorem matchList_cons (p : Pat) (ps : List Pat) (v : Val) (vs : List Val) :
    (Pat.matchList (p :: ps) (v :: vs)).isSome =
      ((Pat.matchVal p v).isSome && (Pat.matchList ps vs).isSome) := by
  simp only [Pat.matchList]
  cases Pat.matchVal p v <;> cases Pat.matchList ps vs <;> rfl

theorem matchList_length {ps : List Pat} {vs : List Val}
    (h : (Pat.matchList ps vs).isSome) : ps.length = vs.length := by
  induction ps generalizing vs with
  | nil => cases vs <;> simp_all [Pat.matchList]
  | cons p ps ih =>
      cases vs with
      | nil => simp [Pat.matchList] at h
      | cons v vs => simp only [matchList_cons, Bool.and_eq_true] at h; simp [ih h.2]

@[simp] theorem matchList_append (ps qs : List Pat) (xs ys : List Val)
    (h : ps.length = xs.length) :
    (Pat.matchList (ps ++ qs) (xs ++ ys)).isSome =
      ((Pat.matchList ps xs).isSome && (Pat.matchList qs ys).isSome) := by
  induction ps generalizing xs with
  | nil => cases xs <;> simp_all [Pat.matchList]
  | cons p ps ih =>
      cases xs with
      | nil => simp at h
      | cons x xs =>
          simp only [List.length_cons, Nat.add_right_cancel_iff] at h
          simp [ih xs h, Bool.and_assoc]

theorem matchList_split (ps qs : List Pat) (vs : List Val) :
    (Pat.matchList (ps ++ qs) vs).isSome =
      ((Pat.matchList ps (vs.take ps.length)).isSome &&
       (Pat.matchList qs (vs.drop ps.length)).isSome) := by
  induction ps generalizing vs with
  | nil => simp [Pat.matchList]
  | cons p ps ih =>
      cases vs with
      | nil => simp [Pat.matchList]
      | cons v vs => simp [ih, Bool.and_assoc]

@[simp] theorem matchVal_wild {p : Pat} (hp : isWild p = true) (v : Val) :
    (Pat.matchVal p v).isSome = true := by
  cases p <;> simp_all [isWild, Pat.matchVal]

theorem matchList_wild {ps : List Pat} {vs : List Val}
    (hp : ps.all isWild = true) (hl : ps.length = vs.length) :
    (Pat.matchList ps vs).isSome = true := by
  induction ps generalizing vs with
  | nil => cases vs <;> simp_all [Pat.matchList]
  | cons p ps ih =>
      cases vs with
      | nil => simp at hl
      | cons v vs =>
          simp only [List.all_cons, Bool.and_eq_true] at hp
          simp only [List.length_cons, Nat.add_right_cancel_iff] at hl
          simp [matchVal_wild hp.1, ih hp.2 hl]

@[simp] theorem matchList_replicate (vs : List Val) :
    (Pat.matchList (List.replicate vs.length .wild) vs).isSome = true := by
  apply matchList_wild <;> simp [isWild]

theorem inhabitsAll_length {P : Program} {ts : List Ty} {vs : List Val}
    (h : InhabitsAll P ts vs) : ts.length = vs.length := by
  induction ts generalizing vs with
  | nil => cases h; rfl
  | cons a ts ih => cases h with | cons _ ht => simp [ih ht]

theorem inhabitsAll_append {P : Program} {ts us : List Ty} {xs ys : List Val}
    (h : InhabitsAll P ts xs) (h' : InhabitsAll P us ys) :
    InhabitsAll P (ts ++ us) (xs ++ ys) := by
  induction ts generalizing xs with
  | nil => cases h; exact h'
  | cons a ts ih => cases h with | cons hv ht => exact .cons hv (ih ht)

theorem inhabitsEach_take {P : Program} {a : Ty} {vs : List Val}
    (h : InhabitsEach P a vs) (n : Nat) : InhabitsEach P a (vs.take n) := by
  induction vs generalizing n with
  | nil => simp; exact .nil
  | cons v vs ih =>
      cases h with | cons hv ht =>
        cases n with
        | zero => exact .nil
        | succ n => exact .cons hv (ih ht n)

theorem inhabitsEach_drop {P : Program} {a : Ty} {vs : List Val}
    (h : InhabitsEach P a vs) (n : Nat) : InhabitsEach P a (vs.drop n) := by
  induction vs generalizing n with
  | nil => simp; exact .nil
  | cons v vs ih =>
      cases h with | cons hv ht =>
        cases n with
        | zero => exact .cons hv ht
        | succ n => exact ih ht n

theorem inhabitsEach_all {P : Program} {a : Ty} {vs : List Val}
    (h : InhabitsEach P a vs) : InhabitsAll P (List.replicate vs.length a) vs := by
  induction vs with
  | nil => exact .nil
  | cons v vs ih =>
      cases h with | cons hv ht =>
        simp only [List.length_cons, List.replicate_succ]; exact .cons hv (ih ht)

@[simp] theorem matchVal_list (before after : List Pat) (rest : Option ListRest) (vs : List Val) :
    (Pat.matchVal (.list before rest after) (.list vs)).isSome =
      (decide (if rest.isSome then before.length + after.length ≤ vs.length
        else before.length + after.length = vs.length) &&
       (Pat.matchList before (vs.take before.length)).isSome &&
       (Pat.matchList after (vs.drop (vs.length - after.length))).isSome) := by
  cases rest with
  | none =>
      simp only [Pat.matchVal, Option.isSome_none, Bool.false_eq_true, ↓reduceIte]
      split <;> (cases Pat.matchList before (vs.take before.length) <;>
        cases Pat.matchList after (vs.drop (vs.length - after.length)) <;> simp_all)
  | some r =>
      simp only [Pat.matchVal, Option.isSome_some, ↓reduceIte]
      split <;> (cases Pat.matchList before (vs.take before.length) <;>
        cases Pat.matchList after (vs.drop (vs.length - after.length)) <;> simp_all)

/-! ## 区間の端と列挙 -/

theorem snoc_induction {α : Type} {motive : List α → Prop}
    (hnil : motive []) (hsnoc : ∀ xs x, motive xs → motive (xs ++ [x])) (xs : List α) :
    motive xs := by
  have h : ∀ ys : List α, motive ys.reverse := by
    intro ys
    induction ys with
    | nil => exact hnil
    | cons y ys ih => simpa using hsnoc ys.reverse y ih
  simpa using h xs.reverse

def LowerSpec (bounds : List Int) (v : Int) : Option Int → Prop
  | none => ∀ x ∈ bounds, v < x
  | some lo => lo ∈ bounds ∧ lo ≤ v ∧ ∀ x ∈ bounds, x ≤ v → x ≤ lo

def UpperSpec (bounds : List Int) (v : Int) : Option Int → Prop
  | none => ∀ x ∈ bounds, x ≤ v
  | some hi => hi ∈ bounds ∧ v < hi ∧ ∀ x ∈ bounds, v < x → hi ≤ x

theorem lowerEnd_spec (bounds : List Int) (v : Int) :
    LowerSpec bounds v (lowerEnd bounds v) := by
  induction bounds using snoc_induction with
  | hnil => simp [lowerEnd, LowerSpec]
  | hsnoc xs x ih =>
      simp only [lowerEnd, List.foldl_append, List.foldl_cons, List.foldl_nil]
      change LowerSpec (xs ++ [x]) v
        (if x ≤ v then some (((lowerEnd xs v).map (max x)).getD x) else lowerEnd xs v)
      cases he : lowerEnd xs v <;> simp only [he, LowerSpec] at ih
      · by_cases hx : x ≤ v <;> simp [hx, LowerSpec, List.mem_append] <;> grind
      · by_cases hx : x ≤ v <;> simp [hx, LowerSpec, List.mem_append, Int.max_def] <;> grind

theorem upperEnd_spec (bounds : List Int) (v : Int) :
    UpperSpec bounds v (upperEnd bounds v) := by
  induction bounds using snoc_induction with
  | hnil => simp [upperEnd, UpperSpec]
  | hsnoc xs x ih =>
      simp only [upperEnd, List.foldl_append, List.foldl_cons, List.foldl_nil]
      change UpperSpec (xs ++ [x]) v
        (if v < x then some (((upperEnd xs v).map (min x)).getD x) else upperEnd xs v)
      cases he : upperEnd xs v <;> simp only [he, UpperSpec] at ih
      · by_cases hx : v < x <;> simp [hx, UpperSpec, List.mem_append] <;> grind
      · by_cases hx : v < x <;> simp [hx, UpperSpec, List.mem_append, Int.min_def] <;> grind

theorem lowerEnd_some {bounds : List Int} {v lo : Int} (h : lowerEnd bounds v = some lo) :
    lo ∈ bounds ∧ lo ≤ v ∧ ∀ x ∈ bounds, x ≤ v → x ≤ lo := by
  simpa [h, LowerSpec] using lowerEnd_spec bounds v

theorem upperEnd_some {bounds : List Int} {v hi : Int} (h : upperEnd bounds v = some hi) :
    hi ∈ bounds ∧ v < hi ∧ ∀ x ∈ bounds, v < x → hi ≤ x := by
  simpa [h, UpperSpec] using upperEnd_spec bounds v

theorem lowerEnd_none {bounds : List Int} {v : Int} :
    lowerEnd bounds v = none ↔ ∀ x ∈ bounds, v < x := by
  constructor
  · intro h; simpa [h, LowerSpec] using lowerEnd_spec bounds v
  · intro h
    cases he : lowerEnd bounds v with
    | none => rfl
    | some lo => have hl := lowerEnd_some he; have := h lo hl.1; omega

theorem upperEnd_none {bounds : List Int} {v : Int} :
    upperEnd bounds v = none ↔ ∀ x ∈ bounds, x ≤ v := by
  constructor
  · intro h; simpa [h, UpperSpec] using upperEnd_spec bounds v
  · intro h
    cases he : upperEnd bounds v with
    | none => rfl
    | some hi => have hl := upperEnd_some he; have := h hi hl.1; omega

theorem lowerEnd_eq {bounds : List Int} {v lo : Int}
    (hm : lo ∈ bounds) (hl : lo ≤ v) (hmax : ∀ x ∈ bounds, x ≤ v → x ≤ lo) :
    lowerEnd bounds v = some lo := by
  cases he : lowerEnd bounds v with
  | none => have := lowerEnd_none.mp he lo hm; omega
  | some x =>
      have hx := lowerEnd_some he
      have := hmax x hx.1 hx.2.1
      have := hx.2.2 lo hm hl
      congr 1; omega

theorem upperEnd_eq {bounds : List Int} {v hi : Int}
    (hm : hi ∈ bounds) (hl : v < hi) (hmin : ∀ x ∈ bounds, v < x → hi ≤ x) :
    upperEnd bounds v = some hi := by
  cases he : upperEnd bounds v with
  | none => have := upperEnd_none.mp he hi hm; omega
  | some x =>
      have hx := upperEnd_some he
      have := hmin x hx.1 hx.2.1
      have := hx.2.2 hi hm hl
      congr 1; omega

@[simp] theorem mem_insertEnd (v x : Int) (xs : List Int) :
    v ∈ insertEnd x xs ↔ v = x ∨ v ∈ xs := by
  induction xs with
  | nil => simp [insertEnd]
  | cons y ys ih => simp only [insertEnd]; split <;> simp [ih, or_left_comm]

@[simp] theorem mem_sortEnds (v : Int) (xs : List Int) : v ∈ sortEnds xs ↔ v ∈ xs := by
  induction xs with
  | nil => simp [sortEnds]
  | cons x xs ih => simp [sortEnds, ih]

/-- 問いの端が含まれるなら、値を含む区間を列挙から取り出せる。 -/
theorem segments_cover {bounds : List Int} {a b v : Int}
    (ha : a ∈ bounds) (hb : b + 1 ∈ bounds) (hav : a ≤ v) (hvb : v ≤ b) :
    ∃ lo hi, (lo, hi) ∈ segments bounds ∧ a ≤ lo ∧ lo ≤ v ∧ v ≤ hi ∧ hi ≤ b := by
  have hlo : ∃ lo, lowerEnd bounds v = some lo := by
    cases he : lowerEnd bounds v with
    | none => have := lowerEnd_none.mp he a ha; omega
    | some lo => exact ⟨lo, rfl⟩
  have hhi : ∃ hi, upperEnd bounds v = some hi := by
    cases he : upperEnd bounds v with
    | none => have := upperEnd_none.mp he (b + 1) hb; omega
    | some hi => exact ⟨hi, rfl⟩
  obtain ⟨lo, hlo⟩ := hlo
  obtain ⟨next, hhi⟩ := hhi
  have hl := lowerEnd_some hlo
  have hu := upperEnd_some hhi
  have hal := hl.2.2 a ha hav
  have hnb := hu.2.2 (b + 1) hb (by omega)
  have hl' : lowerEnd bounds lo = some lo :=
    lowerEnd_eq hl.1 (by omega) (fun x hx hxlo => hl.2.2 x hx (by omega))
  have hu' : upperEnd bounds lo = some next := by
    apply upperEnd_eq hu.1 (by omega)
    intro x hx hxl
    have hvx : v < x := by
      by_cases hn : v < x
      · exact hn
      · have := hl.2.2 x hx (by omega)
        omega
    exact hu.2.2 x hx hvx
  refine ⟨lo, next - 1, ?_, hal, hl.2.1, by omega, by omega⟩
  apply List.mem_filterMap.mpr
  exact ⟨lo, by simpa using hl.1, by simp [intervalAt, hl', hu']⟩

/-! ## リストの前後の特殊化 -/

/-- 間のワイルドカードは束縛を加えず、照合の成功に影響しない。 -/
theorem padded_match (before after : List Pat) (xs : List Val)
    (h : before.length + after.length ≤ xs.length) :
    (Pat.matchList (before ++ List.replicate (xs.length - (before.length + after.length)) .wild ++ after) xs).isSome =
      ((Pat.matchList before (xs.take before.length)).isSome &&
       (Pat.matchList after (xs.drop (xs.length - after.length))).isSome) := by
  rw [List.append_assoc, matchList_split, matchList_split]
  have hm : ((xs.drop before.length).take (xs.length - (before.length + after.length))).length =
      xs.length - (before.length + after.length) := by simp; omega
  have hw : (Pat.matchList (List.replicate (xs.length - (before.length + after.length)) .wild)
      ((xs.drop before.length).take (xs.length - (before.length + after.length)))).isSome = true := by
    apply matchList_wild <;> simp [isWild, hm]
  simp only [List.length_replicate, hw, Bool.true_and, List.drop_drop]
  have he : before.length + (xs.length - (before.length + after.length)) = xs.length - after.length := by omega
  rw [he]

/-- 長いリストで再帰に渡す値の並び。 -/
def longValues (front back : Nat) (xs : List Val) : List Val :=
  xs.take front ++ xs.drop (xs.length - back)

theorem longValues_length {front back : Nat} {xs : List Val}
    (h : front + back ≤ xs.length) : (longValues front back xs).length = front + back := by
  simp [longValues]; omega

theorem longValues_take {front back n : Nat} {xs : List Val}
    (h : front + back ≤ xs.length) (hn : n ≤ front) :
    (longValues front back xs).take n = xs.take n := by
  rw [longValues, List.take_append_of_le_length (by simp; omega), List.take_take]
  congr 1; omega

theorem longValues_suffix {front back n : Nat} {xs : List Val}
    (h : front + back ≤ xs.length) (hn : n ≤ back) :
    (longValues front back xs).drop ((longValues front back xs).length - n) =
      xs.drop (xs.length - n) := by
  rw [longValues_length h, longValues, List.drop_append]
  have hz : (xs.take front).drop (front + back - n) = [] := by
    apply List.drop_eq_nil_iff.mpr; simp; omega
  rw [hz, List.nil_append, List.length_take, List.drop_drop]
  congr 1; omega

theorem longValues_inhabits {P : Program} {a : Ty} {xs : List Val} {front back : Nat}
    (hx : InhabitsEach P a xs) (h : front + back ≤ xs.length) :
    InhabitsAll P (List.replicate (front + back) a) (longValues front back xs) := by
  have hl := inhabitsEach_all (inhabitsEach_take hx front)
  have hr := inhabitsEach_all (inhabitsEach_drop hx (xs.length - back))
  have hh := inhabitsAll_append hl hr
  simpa [longValues, List.replicate_append_replicate, List.length_take, List.length_drop,
    Nat.min_eq_left (by omega : front ≤ xs.length), Nat.sub_sub_self (by omega : back ≤ xs.length)] using hh

/-- 前後の最大長を増やしても、リストの照合の成否は変わらない。 -/
theorem long_match (before after : List Pat) (r : ListRest) (xs : List Val)
    (front back : Nat) (h : front + back ≤ xs.length)
    (hb : before.length ≤ front) (ha : after.length ≤ back) :
    (Pat.matchList (before ++ List.replicate (front + back - (before.length + after.length)) .wild ++ after)
      (longValues front back xs)).isSome =
      (Pat.matchVal (.list before (some r) after) (.list xs)).isSome := by
  have hc : before.length + after.length ≤ xs.length := by omega
  have hp := padded_match before after (longValues front back xs) (by rw [longValues_length h]; omega)
  rw [longValues_take h hb, longValues_suffix h ha, longValues_length h] at hp
  simpa [matchVal_list, hc] using hp

def ListBoundsSpec (column : List Pat) (bounds : Nat × Nat × Nat) : Prop :=
  ∀ before rest after, Pat.list before rest after ∈ column →
    match rest with
    | none => before.length + after.length + 1 ≤ bounds.1
    | some _ => before.length ≤ bounds.2.1 ∧ after.length ≤ bounds.2.2

theorem listBounds_spec (column : List Pat) : ListBoundsSpec column (listBounds column) := by
  induction column using snoc_induction with
  | hnil => simp [ListBoundsSpec]
  | hsnoc xs p ih =>
      simp only [listBounds, List.foldl_append, List.foldl_cons, List.foldl_nil]
      change ListBoundsSpec (xs ++ [p])
        (match p with
        | .list before none after => (max (listBounds xs).1 (before.length + after.length + 1), (listBounds xs).2)
        | .list before (some _) after => ((listBounds xs).1,
            max (listBounds xs).2.1 before.length, max (listBounds xs).2.2 after.length)
        | _ => listBounds xs)
      intro before rest after hm
      simp only [List.mem_append, List.mem_singleton] at hm
      rcases hm with hm | rfl
      · have hh := ih before rest after hm
        cases p <;> cases rest <;> simp_all [ListBoundsSpec]
        all_goals split <;> simp_all <;> omega
      · cases rest <;> simp <;> omega

/-! ## 値を表す形と照合の復元 -/

inductive Represents : Shape → Val → List Val → Prop
  | other (v) : Represents .other v []
  | con (c fields ts xs) (hl : fields.length = xs.length) :
      Represents (.con c fields) (.con c ts xs) xs
  | boolean (b) : Represents (.boolean b) (.const (.boolean b)) []
  | unit : Represents .unit (.const .unit) []
  | string (s) : Represents (.string s) (.const (.string s)) []
  | integer (lo hi n) (hl : lo ≤ n) (hh : n ≤ hi) :
      Represents (.interval false lo hi) (.const (.integer n)) []
  | character (lo hi : Int) (c : Char) (hl : lo ≤ Int.ofNat c.toNat) (hh : Int.ofNat c.toNat ≤ hi) :
      Represents (.interval true lo hi) (.const (.character c)) []
  | exact (a xs) : Represents (.exact xs.length a) (.list xs) xs
  | long (a min front back xs) (hm : min ≤ xs.length) (hf : front + back ≤ min) :
      Represents (.long min front back a) (.list xs) (longValues front back xs)

theorem Represents.length {s v xs} (h : Represents s v xs) : s.fields.length = xs.length := by
  cases h with
  | long a min front back xs hm hf => simpa [Shape.fields] using (longValues_length (by omega : front + back ≤ xs.length)).symm
  | _ => simp [Shape.fields, *]

theorem interval_integer_sound {p : Pat} {a b n : Int}
    (h : interval (.base .integer) p = some (a, b)) (ha : a ≤ n) (hb : n ≤ b) :
    (Pat.matchVal p (.const (.integer n))).isSome = true := by
  cases p with
  | const c => cases c <;> simp_all [interval, Pat.matchVal, Const.matches, Option.filter] <;> omega
  | range lo hi =>
      cases lo <;> cases hi <;> simp_all [interval, Pat.matchVal, Const.inRange, Option.filter] <;> omega
  | _ => simp [interval] at h

theorem interval_character_sound {p : Pat} {a b : Int} {c : Char}
    (h : interval (.base .character) p = some (a, b))
    (ha : a ≤ Int.ofNat c.toNat) (hb : Int.ofNat c.toNat ≤ b) :
    (Pat.matchVal p (.const (.character c))).isSome = true := by
  cases p with
  | const k =>
      cases k <;> simp_all [interval, Pat.matchVal, Const.matches, Option.filter]
      rename_i k
      have he : k.toNat = c.toNat := by omega
      exact Char.toNat_inj.mp he
  | range lo hi =>
      cases lo <;> cases hi <;> simp_all [interval, Pat.matchVal, Const.inRange, Option.filter] <;> omega
  | _ => simp [interval] at h

theorem Represents.restore {s : Shape} {v : Val} {xs : List Val}
    (hr : Represents s v xs) {p : Pat} {ps : List Pat}
    (hs : specialize p s = some ps) (hm : (Pat.matchList ps xs).isSome = true) :
    (Pat.matchVal p v).isSome = true := by
  by_cases hw : isWild p = true
  · exact matchVal_wild hw v
  have hw' : isWild p = false := by cases he : isWild p <;> simp_all
  cases hr with
  | other v => cases p <;> simp_all [specialize, isWild]
  | con c fields ts xs hl =>
      cases p <;> simp [specialize, isWild] at hs hw'
      obtain ⟨⟨rfl, _⟩, rfl⟩ := hs
      simpa [Pat.matchVal] using hm
  | boolean b =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i k
      cases k <;> simp at hs
      obtain ⟨rfl, rfl⟩ := hs
      simp [Pat.matchVal, Const.matches]
  | unit =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i k
      cases k <;> simp at hs
      simp [Pat.matchVal, Const.matches]
  | string b =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i k
      cases k <;> simp at hs
      obtain ⟨rfl, rfl⟩ := hs
      simp [Pat.matchVal, Const.matches]
  | integer lo hi n hl hh =>
      simp only [specialize, hw', Bool.false_eq_true, ↓reduceIte] at hs
      change (interval (.base .integer) p).bind (fun ab => if ab.1 ≤ lo ∧ hi ≤ ab.2 then some [] else none) = some ps at hs
      cases he : interval (.base .integer) p with
      | none => simp [he] at hs
      | some ab =>
          obtain ⟨a, b⟩ := ab
          simp [he] at hs
          exact interval_integer_sound he (by omega) (by omega)
  | character lo hi c hl hh =>
      simp only [specialize, hw', Bool.false_eq_true, ↓reduceIte] at hs
      change (interval (.base .character) p).bind (fun ab => if ab.1 ≤ lo ∧ hi ≤ ab.2 then some [] else none) = some ps at hs
      cases he : interval (.base .character) p with
      | none => simp [he] at hs
      | some ab =>
          obtain ⟨a, b⟩ := ab
          simp [he] at hs
          exact interval_character_sound he (by omega) (by omega)
  | exact a xs =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i before rest after
      cases rest with
      | none =>
          simp at hs
          obtain ⟨hc, rfl⟩ := hs
          have hp := padded_match before after xs (by omega)
          rw [List.append_assoc] at hp
          rw [hp] at hm
          simpa [matchVal_list, hc, Bool.and_assoc] using hm
      | some r =>
          simp at hs
          obtain ⟨hc, rfl⟩ := hs
          have hp := padded_match before after xs hc
          rw [List.append_assoc] at hp
          rw [hp] at hm
          simpa [matchVal_list, hc, Bool.and_assoc] using hm
  | long a min front back xs hmin hfb =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i before rest after
      cases rest with
      | none => simp at hs
      | some r =>
          simp at hs
          obtain ⟨hc, rfl⟩ := hs
          have hp := long_match before after r xs front back (by omega) hc.2.1 hc.2.2
          rw [List.append_assoc] at hp
          rwa [hp] at hm

/-- ワイルドカードの問いは、選んだ形の引数数だけワイルドカードを渡す。 -/
theorem specialize_wild {q : Pat} {s : Shape} {v : Val} {xs : List Val}
    (hq : isWild q = true) (hr : Represents s v xs) :
    ∃ ps, specialize q s = some ps ∧ (Pat.matchList ps xs).isSome = true := by
  refine ⟨List.replicate s.fields.length .wild, by simp [specialize, hq], ?_⟩
  simp [hr.length]

theorem integer_interval_of_match {P : Program} {q : Pat} {n : Int}
    (hw : isWild q = false) (hc : compatible P (.base .integer) q = true)
    (hm : (Pat.matchVal q (.const (.integer n))).isSome = true) :
    ∃ a b, interval (.base .integer) q = some (a, b) ∧ a ≤ n ∧ n ≤ b := by
  cases q with
  | const c =>
      cases c <;> simp_all [isWild, compatible, Pat.matchVal, Const.matches]
      exact ⟨n, n, by simp [interval], by omega, by omega⟩
  | range a b =>
      cases a <;> cases b <;> simp_all [isWild, compatible, Pat.matchVal, Const.inRange]
      rename_i a b
      exact ⟨a, b, by simp [interval, Option.filter, show a ≤ b by omega], hm.1, hm.2⟩
  | _ => simp_all [isWild, compatible]

theorem character_interval_of_match {P : Program} {q : Pat} {c : Char}
    (hw : isWild q = false) (hc : compatible P (.base .character) q = true)
    (hm : (Pat.matchVal q (.const (.character c))).isSome = true) :
    ∃ a b, interval (.base .character) q = some (a, b) ∧ a ≤ (c.toNat : Int) ∧ (c.toNat : Int) ≤ b := by
  cases q with
  | const k =>
      cases k <;> simp_all [isWild, compatible, Pat.matchVal, Const.matches]
      exact ⟨(c.toNat : Int), (c.toNat : Int), by simp [interval], by omega, by omega⟩
  | range a b =>
      cases a <;> cases b <;> simp_all [isWild, compatible, Pat.matchVal, Const.inRange]
      rename_i a b
      exact ⟨(a.toNat : Int), (b.toNat : Int),
        by simp [interval, Option.filter, show a.toNat ≤ b.toNat by omega], by omega, by omega⟩
  | _ => simp_all [isWild, compatible]

/-- 列に含まれる問いの区間を、列挙された区間で細分する。 -/
theorem shapes_interval_cover (P : Program) (ctors : DataName → List ConName)
    (chars : Bool) (column : List Pat) (q : Pat) (a b n : Int)
    (hq : q ∈ column)
    (hi : interval (if chars then .base .character else .base .integer) q = some (a, b))
    (ha : a ≤ n) (hb : n ≤ b)
    (hv : chars = true → n < 55296 ∨ 57343 < n) :
    ∃ lo hh, Shape.interval chars lo hh ∈
      shapes P ctors (if chars then .base .character else .base .integer) column ∧
      lo ≤ n ∧ n ≤ hh ∧ a ≤ lo ∧ hh ≤ b := by
  let ty : Ty := if chars then .base .character else .base .integer
  let intervals := column.filterMap (interval ty)
  let bounds := intervals.flatMap fun (a, b) => [a, b + 1]
  have hm : (a, b) ∈ intervals := List.mem_filterMap.mpr ⟨q, hq, hi⟩
  have hba : a ∈ bounds := List.mem_flatMap.mpr ⟨(a,b), hm, by simp⟩
  have hbb : b + 1 ∈ bounds := List.mem_flatMap.mpr ⟨(a,b), hm, by simp⟩
  obtain ⟨lo, hh, hs, hal, hln, hnh, hhb⟩ := segments_cover hba hbb ha hb
  have hcovered : intervals.any (fun (a,b) => decide (a ≤ lo) && decide (hh ≤ b)) = true :=
    List.any_eq_true.mpr ⟨(a,b), hm, by simp [hal, hhb]⟩
  have hscalar : (chars && decide (lo ≥ 0xD800) && decide (hh ≤ 0xDFFF)) = false := by
    cases chars <;> simp_all <;> omega
  refine ⟨lo, hh, ?_, hln, hnh, hal, hhb⟩
  have hfiltered : (lo, hh) ∈ (segments bounds).filter (fun (lo, hh) =>
      intervals.any (fun (a,b) => decide (a ≤ lo) && decide (hh ≤ b)) &&
      !(chars && decide (lo ≥ 0xD800) && decide (hh ≤ 0xDFFF))) := by
    simp only [List.mem_filter]; exact ⟨hs, by simp [hcovered, hscalar]⟩
  cases chars <;> simp only [shapes]
  all_goals
    right
    apply List.mem_map.mpr
    refine ⟨(lo,hh), ?_, rfl⟩
    simpa [ty, intervals, bounds] using hfiltered

theorem char_scalar (c : Char) :
    (c.toNat : Int) < 55296 ∨ 57343 < (c.toNat : Int) := by
  have hc := c.valid
  change c.toNat < 55296 ∨ 57343 < c.toNat ∧ c.toNat < 1114112 at hc
  omega

/-- 先頭の値の照合を、形の引数の照合に移すための全前提。 -/
def ShapeStep (P : Program) (ctors : DataName → List ConName) (ty : Ty)
    (column : List Pat) (q : Pat) (v : Val) : Prop :=
  ∃ s xs ps, s ∈ shapes P ctors ty column ∧ Represents s v xs ∧
    InhabitsAll P s.fields xs ∧ specialize q s = some ps ∧ (Pat.matchList ps xs).isSome = true

theorem shapeStep_wild {P : Program} {ctors : DataName → List ConName} {ty : Ty}
    {column : List Pat} {q : Pat} {v : Val} {s : Shape} {xs : List Val}
    (hs : s ∈ shapes P ctors ty column) (hr : Represents s v xs)
    (hi : InhabitsAll P s.fields xs) (hw : isWild q = true) :
    ShapeStep P ctors ty column q v := by
  obtain ⟨ps, hp, hm⟩ := specialize_wild hw hr
  exact ⟨s, xs, ps, hs, hr, hi, hp, hm⟩

theorem shapeStep_other {P : Program} {ctors : DataName → List ConName} {ty : Ty}
    {column : List Pat} {q : Pat} {v : Val}
    (hs : Shape.other ∈ shapes P ctors ty column) (hw : isWild q = true) :
    ShapeStep P ctors ty column q v :=
  shapeStep_wild hs (.other v) .nil hw

theorem shapeStep_integer {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {n : Int}
    (hq : q ∈ column) (hc : compatible P (.base .integer) q = true)
    (hm : (Pat.matchVal q (.const (.integer n))).isSome = true) :
    ShapeStep P ctors (.base .integer) column q (.const (.integer n)) := by
  by_cases hw : isWild q = true
  · exact shapeStep_other (by simp [shapes]) hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  obtain ⟨a,b, hi, ha,hb⟩ := integer_interval_of_match hw' hc hm
  obtain ⟨lo,hh, hs,hl,hu,hal,hhb⟩ := shapes_interval_cover P ctors false column q a b n hq hi ha hb (by simp)
  refine ⟨.interval false lo hh, [], [], hs, .integer lo hh n hl hu, .nil, ?_, rfl⟩
  simp [specialize, hw', hi, hal, hhb]

theorem shapeStep_character {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {c : Char}
    (hq : q ∈ column) (hc : compatible P (.base .character) q = true)
    (hm : (Pat.matchVal q (.const (.character c))).isSome = true) :
    ShapeStep P ctors (.base .character) column q (.const (.character c)) := by
  by_cases hw : isWild q = true
  · exact shapeStep_other (by simp [shapes]) hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  obtain ⟨a,b, hi, ha,hb⟩ := character_interval_of_match hw' hc hm
  obtain ⟨lo,hh, hs,hl,hu,hal,hhb⟩ := shapes_interval_cover P ctors true column q a b ((c.toNat : Int))
    hq hi ha hb (fun _ => char_scalar c)
  refine ⟨.interval true lo hh, [], [], hs, .character lo hh c hl hu, .nil, ?_, rfl⟩
  simp [specialize, hw', hi, hal, hhb]

theorem shapeStep_list {P : Program} {ctors : DataName → List ConName}
    {a : Ty} {column : List Pat} {q : Pat} {xs : List Val}
    (hq : q ∈ column) (hc : compatible P (.list a) q = true)
    (hx : InhabitsEach P a xs) (hm : (Pat.matchVal q (.list xs)).isSome = true) :
    ShapeStep P ctors (.list a) column q (.list xs) := by
  let bounds := listBounds column
  let min := max bounds.1 (bounds.2.1 + bounds.2.2)
  have hfront : bounds.2.1 + bounds.2.2 ≤ min := Nat.le_max_right _ _
  have hexact : bounds.1 ≤ min := Nat.le_max_left _ _
  by_cases hlen : xs.length < min
  · have hs : Shape.exact xs.length a ∈ shapes P ctors (.list a) column := by
      simp only [shapes, List.mem_append]
      left
      apply List.mem_map.mpr
      exact ⟨xs.length, List.mem_range.mpr hlen, rfl⟩
    have hr : Represents (.exact xs.length a) (.list xs) xs := .exact a xs
    have hi : InhabitsAll P (Shape.exact xs.length a).fields xs := by
      simpa [Shape.fields] using inhabitsEach_all hx
    by_cases hw : isWild q = true
    · exact shapeStep_wild hs hr hi hw
    have hw' : isWild q = false := by cases he : isWild q <;> simp_all
    cases q <;> simp [isWild, compatible] at hc hw'
    rename_i before rest after
    have hmc := hm
    simp only [matchVal_list, Bool.and_eq_true, decide_eq_true_eq] at hmc
    have hcount : before.length + after.length ≤ xs.length := by
      cases rest <;> simp_all <;> omega
    refine ⟨.exact xs.length a, xs,
      before ++ List.replicate (xs.length - (before.length + after.length)) .wild ++ after,
      hs, hr, hi, ?_, ?_⟩
    · simp [specialize, isWild, hmc.1.1]
    · rw [padded_match before after xs hcount]
      simp [hmc.1.2, hmc.2]
  · have hmin : min ≤ xs.length := by omega
    have hs : Shape.long min bounds.2.1 bounds.2.2 a ∈ shapes P ctors (.list a) column := by
      simp [shapes, min, bounds]
    have hr : Represents (.long min bounds.2.1 bounds.2.2 a) (.list xs)
        (longValues bounds.2.1 bounds.2.2 xs) := .long a min _ _ xs hmin hfront
    have hi : InhabitsAll P (Shape.long min bounds.2.1 bounds.2.2 a).fields
        (longValues bounds.2.1 bounds.2.2 xs) :=
      longValues_inhabits hx (by omega)
    by_cases hw : isWild q = true
    · exact shapeStep_wild hs hr hi hw
    have hw' : isWild q = false := by cases he : isWild q <;> simp_all
    cases q <;> simp [isWild, compatible] at hc hw'
    rename_i before rest after
    have hbound := listBounds_spec column before rest after hq
    have hmc := hm
    simp only [matchVal_list, Bool.and_eq_true, decide_eq_true_eq] at hmc
    cases rest with
    | none =>
        simp only [Option.isSome_none, Bool.false_eq_true, ↓reduceIte] at hmc
        change before.length + after.length + 1 ≤ bounds.1 at hbound
        omega
    | some r =>
        change before.length ≤ bounds.2.1 ∧ after.length ≤ bounds.2.2 at hbound
        have hcount : before.length + after.length ≤ min := by omega
        refine ⟨.long min bounds.2.1 bounds.2.2 a, longValues bounds.2.1 bounds.2.2 xs,
          before ++ List.replicate (bounds.2.1 + bounds.2.2 - (before.length + after.length)) .wild ++ after,
          hs, hr, hi, ?_, ?_⟩
        · simp [specialize, isWild, hbound, hcount]
        · rwa [long_match before after r xs _ _ (by omega) hbound.1 hbound.2]

theorem shapeStep_con {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {c : ConName} {cd : ConDecl} {ts tys : List Ty} {xs : List Val}
    (hctors : CtorsComplete P ctors) (hdecl : P.cons c = some cd) (hn : cd.ntys = ts.length)
    (hx : InhabitsAll P (cd.args.map (Ty.subst ts [])) xs)
    (hc : compatible P (.data cd.data ts) q = true)
    (hm : (Pat.matchVal q (.con c tys xs)).isSome = true) :
    ShapeStep P ctors (.data cd.data ts) column q (.con c tys xs) := by
  let fields := substTys ts cd.args
  have hf : conFields P cd.data ts c = some fields := by simp [conFields, hdecl, hn, fields]
  have hi : InhabitsAll P fields xs := by simpa [fields, substTys_eq] using hx
  have hs : Shape.con c fields ∈ shapes P ctors (.data cd.data ts) column := by
    apply List.mem_map.mpr
    exact ⟨c, hctors c cd hdecl, by simp [hf]⟩
  have hr : Represents (.con c fields) (.con c tys xs) xs := .con c fields tys xs (inhabitsAll_length hi)
  by_cases hw : isWild q = true
  · exact shapeStep_wild hs hr hi hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [isWild, compatible] at hc hw'
  rename_i d ps
  simp only [Pat.matchVal] at hm
  split at hm
  · rename_i he
    subst d
    have hp : ps.length = fields.length := by
      have hl := matchList_length hm
      exact hl.trans hr.length.symm
    exact ⟨.con c fields, xs, ps, hs, hr, hi, by simp [specialize, isWild, hp], hm⟩
  · simp_all

theorem shapeStep_boolean {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {b : Bool}
    (hc : compatible P (.base .boolean) q = true)
    (hm : (Pat.matchVal q (.const (.boolean b))).isSome = true) :
    ShapeStep P ctors (.base .boolean) column q (.const (.boolean b)) := by
  have hs : Shape.boolean b ∈ shapes P ctors (.base .boolean) column := by cases b <;> simp [shapes]
  by_cases hw : isWild q = true
  · exact shapeStep_wild hs (.boolean b) .nil hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [compatible, isWild] at hc hw'
  rename_i k
  cases k <;> simp at hc
  simp [Pat.matchVal, Const.matches] at hm
  subst b
  exact ⟨.boolean _, [], [], hs, .boolean _, .nil, by simp [specialize, isWild], rfl⟩

theorem shapeStep_unit {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat}
    (hc : compatible P (.base .unit) q = true)
    (hm : (Pat.matchVal q (.const .unit)).isSome = true) :
    ShapeStep P ctors (.base .unit) column q (.const .unit) := by
  have hs : Shape.unit ∈ shapes P ctors (.base .unit) column := by simp [shapes]
  by_cases hw : isWild q = true
  · exact shapeStep_wild hs .unit .nil hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [compatible, isWild] at hc hw'
  rename_i k
  cases k <;> simp at hc
  exact ⟨.unit, [], [], hs, .unit, .nil, by simp [specialize, isWild], rfl⟩

theorem shapeStep_string {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {s : String} (hq : q ∈ column)
    (hc : compatible P (.base .string) q = true)
    (hm : (Pat.matchVal q (.const (.string s))).isSome = true) :
    ShapeStep P ctors (.base .string) column q (.const (.string s)) := by
  by_cases hw : isWild q = true
  · exact shapeStep_other (by simp [shapes]) hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [compatible, isWild] at hc hw'
  rename_i k
  cases k <;> simp at hc
  simp [Pat.matchVal, Const.matches] at hm
  subst s
  rename_i str
  have hs : Shape.string str ∈ shapes P ctors (.base .string) column := by
    simp only [shapes, List.mem_cons]
    right
    apply List.mem_map.mpr
    refine ⟨_, List.mem_eraseDups.mpr (List.mem_filterMap.mpr ⟨_, hq, rfl⟩), rfl⟩
  exact ⟨.string _, [], [], hs, .string _, .nil, by simp [specialize, isWild], rfl⟩

/-- 問いが照合する値に対応する形と、特殊化した問いの照合を取り出す。 -/
theorem shapes_cover {P : Program} {ctors : DataName → List ConName}
    {ty : Ty} {column : List Pat} {q : Pat} {v : Val}
    (hctors : CtorsComplete P ctors) (hq : q ∈ column) (hv : Inhabits P ty v)
    (hc : compatible P ty q = true) (hm : (Pat.matchVal q v).isSome = true) :
    ShapeStep P ctors ty column q v := by
  cases hv with
  | const =>
      rename_i c
      cases c with
      | integer n => exact shapeStep_integer hq hc hm
      | character c => exact shapeStep_character hq hc hm
      | boolean b => exact shapeStep_boolean hc hm
      | unit => exact shapeStep_unit hc hm
      | string s => exact shapeStep_string hq hc hm
      | _ =>
          apply shapeStep_other (by simp [Const.type, shapes])
          cases q <;> simp_all [Const.type, compatible, isWild]
  | con hd hn hx => exact shapeStep_con hctors hd hn hx hc hm
  | list hx => exact shapeStep_list hq hc hx hm
  | _ =>
      apply shapeStep_other (by simp [shapes])
      cases q <;> simp_all [compatible, isWild]

/-! ## 行列の特殊化と燃料についての帰納法 -/

theorem firstUseful_none {f : Shape → UsefulnessResult} {ss : List Shape}
    (h : (firstUseful f ss).witness = none) : ∀ s ∈ ss, (f s).witness = none := by
  induction ss with
  | nil => simp
  | cons s ss ih =>
      simp only [firstUseful] at h
      split at h
      · rename_i hs
        rw [h] at hs
        simp at hs
      · rename_i hs
        have hn : (f s).witness = none := by
          cases he : (f s).witness <;> simp_all
        intro x hx
        rcases List.mem_cons.mp hx with rfl | hx
        · exact hn
        · exact ih h x hx

theorem specializeRows_restore {s : Shape} {v : Val} {xs vs : List Val}
    {rows : List (List Pat)} {row : List Pat} (hr : Represents s v xs)
    (hlen : ∀ r ∈ rows, r.length = vs.length + 1)
    (hrow : row ∈ specializeRows s rows) (hm : (Pat.matchList row (xs ++ vs)).isSome = true) :
    ∃ r ∈ rows, (Pat.matchList r (v :: vs)).isSome = true := by
  obtain ⟨r, hmem, he⟩ := List.mem_filterMap.mp hrow
  cases r with
  | nil => simp at he
  | cons p ps =>
      change ((specialize p s).bind (fun args => some (args ++ ps))) = some row at he
      cases hs : specialize p s with
      | none => simp [hs] at he
      | some args =>
          simp only [hs, Option.bind_some, Option.some.injEq] at he
          subst row
          have hl := hlen (p :: ps) hmem
          have hmLen := matchList_length hm
          simp only [List.length_cons, List.length_append] at hl hmLen
          have ha : args.length = xs.length := by omega
          rw [matchList_append args ps xs vs ha] at hm
          simp only [Bool.and_eq_true] at hm
          exact ⟨p :: ps, hmem, by simp [hr.restore hs hm.1, hm.2]⟩

/-- 燃料切れは有用と答えるので、任意の燃料について健全である。 -/
theorem usefulFuel_none_sound (P : Program) (ctors : DataName → List ConName)
    (hc : CtorsComplete P ctors) (fuel : Nat) :
    ∀ tys rows q vs, (usefulFuel P ctors fuel tys rows q).witness = none →
      InhabitsAll P tys vs → (Pat.matchList q vs).isSome = true →
      ∃ row ∈ rows, (Pat.matchList row vs).isSome = true := by
  induction fuel with
  | zero => intro tys rows q vs h; simp [usefulFuel, fallback] at h
  | succ fuel ih =>
      intro tys matrix query vs h hv hq
      simp only [usefulFuel] at h
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
                          have hn : (usefulFuel P ctors fuel tys (rows.map List.tail) qs).witness = none := by
                            change ((usefulFuel P ctors fuel tys (rows.map List.tail) qs).witness.map
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
                        · let ss := shapes P ctors ty column
                          change (if !isWild q && !(ss.any fun s => (specialize q s).isSome) then fallback (q :: qs) else _).witness = none at h
                          split at h
                          · simp [fallback] at h
                          · obtain ⟨s, xs, args, hs, hr, hxs, hspec, hargs⟩ :=
                              shapes_cover (column := column) hc (by simp [column]) hv hcompat' hq.1
                            have hn := firstUseful_none h s hs
                            change (match specialize q s with
                              | none => (⟨none, false⟩ : UsefulnessResult)
                              | some args => _).witness = none at hn
                            rw [hspec] at hn
                            let r := usefulFuel P ctors fuel (s.fields ++ tys) (specializeRows s rows) (args ++ qs)
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

/-- 入力の大きさから燃料を決めた有用性の判定と燃料切れの記録。 -/
def usefulReport (P : Program) (ctors : DataName → List ConName) (tys : List Ty)
    (rows : List (List Pat)) (q : List Pat) : UsefulnessResult :=
  Coverage.usefulFuel P ctors (Coverage.fuelFor P ctors tys rows q) tys rows q

/-- `some` が有用、`none` が有用でないことを表す。 -/
def useful (P : Program) (ctors : DataName → List ConName) (tys : List Ty)
    (rows : List (List Pat)) (q : List Pat) : Option (List CoverageWitness) :=
  (usefulReport P ctors tys rows q).witness

/-- Q3 の行列を位置付きで集める。前の分岐はガードなし、同じ分岐はガードを問わない。 -/
def precedingAlternatives (arms : List Arm) (i j : Nat) : List ((Nat × Nat) × Pat) :=
  (arms.take i).zipIdx.flatMap (fun (arm, k) =>
    if arm.guard.isNone then arm.alts.zipIdx.map (fun (alt, l) => ((k, l), alt.pat)) else []) ++
    ((arms[i]?).map (fun arm =>
      (arm.alts.take j).zipIdx.map (fun (alt, l) => ((i, l), alt.pat)))).getD []

/-- 有用性の判定と覆っている選択肢の選択は、同じ前の行を使う。 -/
def precedingPats (arms : List Arm) (i j : Nat) : List Pat :=
  (precedingAlternatives arms i j).map Prod.snd

/-- 二つのパターンの重なり。ワイルドカード・変数はどのパターンとも重なる。
再帰の深さは入力の非ワイルドカードの節の総数以下なので、それに 1 を足して渡す。 -/
def overlaps (P : Program) (ctors : DataName → List ConName) (ty : Ty) (a b : Pat) : Bool :=
  Coverage.overlapsFuel P ctors (Coverage.nodes a + Coverage.nodes b + 1) ty a b

/-- 単独で覆う最初の選択肢を優先する。なければ覆う最小の接頭辞の中で重なるものを選ぶ。
位置と順は処理系の covering_alternatives と同じ。前の行の集め方だけ Q3 に従う。 -/
def coveringAlternatives (P : Program) (ctors : DataName → List ConName) (ty : Ty)
    (arms : List Arm) (i j : Nat) : List (Nat × Nat) :=
  match (arms[i]?).bind (fun arm => (arm.alts[j]?).map Alt.pat) with
  | none => []
  | some target =>
      let previous := precedingAlternatives arms i j
      match previous.find? (fun (_, p) => (useful P ctors [ty] [[p]] [target]).isNone) with
      | some (pos, _) => [pos]
      | none =>
          match previous.zipIdx.find? (fun (_, k) =>
            (useful P ctors [ty]
              ((previous.take (k + 1)).map (fun (_, p) => [p])) [target]).isNone) with
          | none => []
          | some (_, k) =>
              ((previous.take (k + 1)).filter (fun (_, p) => overlaps P ctors ty p target)).map Prod.fst

structure MatchCoverage where
  uncovered : Option CoverageWitness
  unreachable : List (Nat × Nat)
  /-- 選ばれない位置ごとの覆っている分岐。同じ分岐は除き、昇順で重複なし。 -/
  coveredBy : List ((Nat × Nat) × List Nat)
  fuelExhausted : Bool
  deriving Repr

def MatchCoverage.exhaustive (r : MatchCoverage) : Bool := r.uncovered.isNone

/-- 選ばれない位置は分岐・選択肢の順。網羅性の行列は unguardedPats の順。 -/
def checkMatch (P : Program) (ctors : DataName → List ConName) (a : Ty)
    (arms : List Arm) : MatchCoverage :=
  let checked := arms.zipIdx.flatMap fun (arm, i) =>
    arm.alts.zipIdx.map fun (alt, j) =>
      ((i, j), usefulReport P ctors [a] ((precedingPats arms i j).map (fun p => [p])) [alt.pat])
  let all := usefulReport P ctors [a] ((unguardedPats arms).map (fun p => [p])) [.wild]
  let unreachable := checked.filterMap (fun (pos, r) => if r.witness.isNone then some pos else none)
  { uncovered := all.witness.map (fun ws => ws.headD .wild)
    unreachable := unreachable
    coveredBy := unreachable.map (fun (i, j) =>
      -- 選択肢の位置は昇順で得られるため、分岐番号の除外と重複除去だけで昇順を保つ。
      ((i, j), (((coveringAlternatives P ctors a arms i j).map Prod.fst).filter (· != i)).eraseDups))
    fuelExhausted := all.fuelExhausted || checked.any (fun (_, r) => r.fuelExhausted) }

def irrefutable (P : Program) (ctors : DataName → List ConName) (a : Ty) (p : Pat) : Bool :=
  (useful P ctors [a] [[p]] [.wild]).isNone

/-- slots の整合を仮定しない、パターンの照合だけによる選択。
前のガード付き分岐は、ガードが偽になる可能性があるので条件から外す。
firstAlt と実行の規則への接続は、slots が整うという前提のもとで E1b 以降に行う。 -/
def AlternativeSelected (arms : List Arm) (i j : Nat) (v : Val) : Prop :=
  ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
    (∀ p ∈ unguardedPats (arms.take i), ¬ (Pat.matchVal p v).isSome) ∧
    (∀ prior ∈ arm.alts.take j, ¬ (Pat.matchVal prior.pat v).isSome) ∧
    (Pat.matchVal alt.pat v).isSome

/-- 補題 U。パターンの型付け・行の長さの整合を前提にしない。 -/
theorem useful_none_sound (P : Program) (ctors : DataName → List ConName)
    (tys : List Ty) (rows : List (List Pat)) (q : List Pat)
    (hc : CtorsComplete P ctors) (h : useful P ctors tys rows q = none) :
    ∀ vs, InhabitsAll P tys vs → (Pat.matchList q vs).isSome →
      ∃ row ∈ rows, (Pat.matchList row vs).isSome := by
  intro vs hv hm
  exact Coverage.usefulFuel_none_sound P ctors hc _ tys rows q vs h hv hm

/-- 一列の行列から、元のパターンの照合を取り出す。 -/
theorem useful_singleton_none_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (ps : List Pat) (q : Pat) (hc : CtorsComplete P ctors)
    (h : useful P ctors [a] (ps.map (fun p => [p])) [q] = none)
    (v : Val) (hv : Inhabits P a v) (hq : (Pat.matchVal q v).isSome = true) :
    ∃ p ∈ ps, (Pat.matchVal p v).isSome = true := by
  have hm : (Pat.matchList [q] [v]).isSome = true := by simp [Pat.matchList, hq]
  obtain ⟨row, hr, hm⟩ := useful_none_sound P ctors [a] (ps.map (fun p => [p])) [q] hc h
    [v] (.cons hv .nil) hm
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hr
  exact ⟨p, hp, by simpa [Coverage.matchList_cons, Pat.matchList] using hm⟩


/-- 系 1: ガードのない選択肢による網羅性。 -/
theorem checkMatch_exhaustive_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (hc : CtorsComplete P ctors)
    (h : (checkMatch P ctors a arms).exhaustive = true) :
    Exhaustive P a (unguardedPats arms) := by
  have hu : useful P ctors [a] ((unguardedPats arms).map (fun p => [p])) [.wild] = none := by
    change ((usefulReport P ctors [a] ((unguardedPats arms).map (fun p => [p])) [.wild]).witness.map
      (fun ws => ws.headD .wild)).isNone = true at h
    simpa [useful] using h
  intro v hv
  exact useful_singleton_none_sound P ctors a (unguardedPats arms) .wild hc hu v hv rfl


/-- 系 1: 束縛の左辺の網羅性。 -/
theorem irrefutable_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (p : Pat) (hc : CtorsComplete P ctors)
    (h : irrefutable P ctors a p = true) : Exhaustive P a [p] := by
  have hu : useful P ctors [a] [[p]] [.wild] = none := by
    simpa [irrefutable] using h
  intro v hv
  exact useful_singleton_none_sound P ctors a [p] .wild hc hu v hv rfl


/-- ガードのない分岐の一覧を、分岐と選択肢の所属で特徴付ける。 -/
theorem mem_unguardedPats (arms : List Arm) (p : Pat) :
    p ∈ unguardedPats arms ↔
      ∃ arm ∈ arms, arm.guard.isNone = true ∧ ∃ alt ∈ arm.alts, alt.pat = p := by
  induction arms with
  | nil => simp [unguardedPats]
  | cons arm arms ih =>
      cases arm with | mk alts guard body =>
        cases guard <;> simp [unguardedPats, Arm.guard, Arm.alts, ih] <;> grind

/-- 前の行は、前のガードのない分岐か、同じ分岐の前の選択肢である。 -/
theorem precedingPats_mem {arms : List Arm} {i j : Nat} {arm : Arm} {p : Pat}
    (ha : arms[i]? = some arm) (hp : p ∈ precedingPats arms i j) :
    p ∈ unguardedPats (arms.take i) ∨ ∃ prior ∈ arm.alts.take j, prior.pat = p := by
  obtain ⟨⟨pos, pat⟩, hm, he⟩ := List.mem_map.mp hp
  simp only at he
  subst pat
  change (pos, p) ∈ _ ++ _ at hm
  rcases List.mem_append.mp hm with hm | hm
  · obtain ⟨⟨prev,k⟩, hprev, hpat⟩ := List.mem_flatMap.mp hm
    change (pos,p) ∈ (if prev.guard.isNone then
      prev.alts.zipIdx.map (fun (alt,l) => ((k,l),alt.pat)) else []) at hpat
    split at hpat
    · rename_i hg
      obtain ⟨⟨alt,l⟩, halt, he⟩ := List.mem_map.mp hpat
      have hpa := congrArg (fun pair => pair.2) he
      left
      apply (mem_unguardedPats _ _).mpr
      refine ⟨prev, ?_, hg, alt, ?_, hpa⟩
      · exact List.mem_of_getElem? (List.mem_zipIdx_iff_getElem?.mp hprev)
      · exact List.mem_of_getElem? (List.mem_zipIdx_iff_getElem?.mp halt)
    · simp at hpat
  · simp only [ha, Option.map_some, Option.getD_some] at hm
    obtain ⟨⟨alt,l⟩, halt, he⟩ := List.mem_map.mp hm
    right
    exact ⟨alt, List.mem_of_getElem? (List.mem_zipIdx_iff_getElem?.mp halt), congrArg (fun pair => pair.2) he⟩

/-- 報告された位置には選択肢があり、その前の行に対して有用でない。 -/
theorem checkMatch_unreachable_lookup {P : Program} {ctors : DataName → List ConName}
    {a : Ty} {arms : List Arm} {i j : Nat}
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
      useful P ctors [a] ((precedingPats arms i j).map (fun p => [p])) [alt.pat] = none := by
  change (i,j) ∈ List.filterMap _ (arms.zipIdx.flatMap _) at h
  obtain ⟨⟨pos,r⟩, hm, he⟩ := List.mem_filterMap.mp h
  change (if r.witness.isNone then some pos else none) = some (i,j) at he
  split at he
  · rename_i hn
    simp only [Option.some.injEq] at he
    subst pos
    obtain ⟨⟨arm,k⟩, harm, halts⟩ := List.mem_flatMap.mp hm
    obtain ⟨⟨alt,l⟩, halt, hr⟩ := List.mem_map.mp halts
    have hpos := congrArg (fun pair => pair.1) hr
    simp only [Prod.mk.injEq] at hpos
    obtain ⟨rfl,rfl⟩ := hpos
    have hreport := congrArg (fun pair => pair.2) hr
    dsimp only at hreport
    subst r
    exact ⟨arm, alt, List.mem_zipIdx_iff_getElem?.mp harm,
      List.mem_zipIdx_iff_getElem?.mp halt, by simpa [useful] using hn⟩
  · simp at he

/-- 系 2: パターンの照合の上で選ばれないこと。実行の規則についてはまだ主張しない。 -/
theorem checkMatch_unreachable_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (i j : Nat) (hc : CtorsComplete P ctors)
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ v, Inhabits P a v → ¬ AlternativeSelected arms i j v := by
  obtain ⟨arm, alt, ha, hal, hu⟩ := checkMatch_unreachable_lookup h
  intro v hv hsel
  obtain ⟨arm', alt', ha', hal', hprev, hprior, hm⟩ := hsel
  have hearm : arm' = arm := Option.some.inj (ha'.symm.trans ha)
  subst arm'
  have healt : alt' = alt := Option.some.inj (hal'.symm.trans hal)
  subst alt'
  obtain ⟨p, hp, hpm⟩ := useful_singleton_none_sound P ctors a (precedingPats arms i j) alt.pat hc hu v hv hm
  rcases precedingPats_mem ha hp with hprevp | ⟨prior, hpri, hpat⟩
  · exact hprev p hprevp hpm
  · apply hprior prior hpri
    simpa only [hpat] using hpm

/-! ## 評価できる例

手順の入口で、診断の位置・網羅性・反例の形を検査する。既存の実行例はこの手順を呼ばない。
要求された仕様の例に加え、補題 U を偽にする長さの不一致、定数の種類の混同、
問いを区間の分割に含めない誤りを検出する。準備と期待結果は手順から独立して書く。
-/

namespace CoverageExamples

def program : Program where
  defs _ := none
  cons c := if c = "L" ∨ c = "R" then
    some { data := "Choice", ntys := 1, args := [.tvar 0] } else none
  ops _ := none
  effects _ := none
  classes _ := none
  impls _ := none

def ctors : DataName → List ConName
  | "Choice" => ["L", "R"]
  | _ => []

theorem ctors_complete : CtorsComplete program ctors := by
  intro c cd h
  by_cases hc : c = "L" ∨ c = "R"
  · simp [program, hc] at h
    subst cd
    rcases hc with rfl | rfl <;> simp [ctors]
  · simp [program, hc] at h

def intTy : Ty := .base .integer
def boolTy : Ty := .base .boolean

/-- レビューの反例: 入力には現れない Big の 50 引数を特殊化すると列が増える。 -/
def wideProgram : Program :=
  { program with cons := fun c =>
      if c = "Small" then some { data := "T", ntys := 0, args := [] }
      else if c = "Big" then some { data := "T", ntys := 0, args := List.replicate 50 boolTy }
      else if c = "Pair" then some { data := "P", ntys := 0, args := [.data "T" [], boolTy] }
      else none }

def wideCtors : DataName → List ConName
  | "T" => ["Small", "Big"]
  | "P" => ["Pair"]
  | _ => []

def charTy : Ty := .base .character
def int (n : Int) : Pat := .const (.integer n)
def bool (b : Bool) : Pat := .const (.boolean b)
def chars (lo hi : Nat) : Pat := .range (.character (Char.ofNat lo)) (.character (Char.ofNat hi))

def plain (ps : List Pat) : Arm :=
  .mk (ps.map (fun p => ⟨p, []⟩)) none (.ret (.const .unit))

def guarded (ps : List Pat) : Arm :=
  .mk (ps.map (fun p => ⟨p, []⟩)) (some (.ret (.const (.boolean true)))) (.ret (.const .unit))

def wideArms : List Arm :=
  [plain [.con "Pair" [.con "Small" [], bool true]],
   plain [.con "Pair" [.wild, bool false]], plain [.con "Pair" [.wild, bool true]]]

example : let r := checkMatch wideProgram wideCtors (.data "P" []) wideArms
    (r.exhaustive, r.unreachable, r.fuelExhausted) = (true, [], false) := by decide

/-- 入れ子の反例を、DecidableEq を持つ平たい印の並びに移して比較する。 -/
inductive Tag where
  | wild | other
  | con (c : ConName) (arity : Nat)
  | invalidCon (c : ConName)
  | boolean (b : Bool)
  | unit
  | interval (character : Bool) (lo hi : Int)
  | string (s : String)
  | exact (length : Nat)
  | long (min front back : Nat)
  deriving DecidableEq, Repr

mutual
  def summarize : CoverageWitness → List Tag
    | .wild => [.wild]
    | .other => [.other]
    | .con c args => .con c args.length :: summarizeList args
    | .invalidCon c => [.invalidCon c]
    | .boolean b => [.boolean b]
    | .unit => [.unit]
    | .interval chars lo hi => [.interval chars lo hi]
    | .string s => [.string s]
    | .exact elems => .exact elems.length :: summarizeList elems
    | .long min before after =>
        .long min before.length after.length :: (summarizeList before ++ summarizeList after)
  def summarizeList : List CoverageWitness → List Tag
    | [] => []
    | w :: ws => summarize w ++ summarizeList ws
end

def inspect (a : Ty) (arms : List Arm) : Option (List Tag) × List (Nat × Nat) × Bool :=
  let r := checkMatch program ctors a arms
  (r.uncovered.map summarize, r.unreachable, r.fuelExhausted)

/-- case _ の後の case 0 は選ばれない。 -/
example : inspect intTy [plain [.wild], plain [int 0]] = (none, [(1, 0)], false) := by decide

/-- ガードの付いた分岐自身も判定する。case _ の後の case 1 if g は選ばれない。 -/
example : let r := checkMatch program ctors intTy [plain [.wild], guarded [int 1]]
    (r.exhaustive, r.unreachable, r.coveredBy, r.fuelExhausted) =
      (true, [(1, 0)], [((1, 0), [0])], false) := by decide

/-- 単独で覆う最初の選択肢を優先し、なければ最小の接頭辞の重なる行だけを示す。
同じ分岐の番号は除き、複数の選択肢を持つ前の分岐の番号は一度だけ示す。 -/
example : ([
    (intTy, [plain [.wild], plain [int 1], plain [int 1]]),
    (boolTy, [plain [bool true], plain [bool false], plain [.wild]]),
    (boolTy, [plain [bool true], plain [bool false], plain [bool true], plain [bool false],
      plain [.wild]]),
    (intTy, [plain [int 99], plain [.range (.integer 1) (.integer 5)],
      plain [.range (.integer 6) (.integer 10)], plain [.range (.integer 1) (.integer 10)]]),
    (intTy, [plain [.range (.integer 1) (.integer 5)], plain [.range (.integer 6) (.integer 10)],
      plain [.range (.integer 1) (.integer 20)], plain [.range (.integer 1) (.integer 10)]]),
    (boolTy, [plain [bool true, bool false], plain [.wild]]),
    (intTy, [plain [int 1, int 1]]),
    (intTy, [guarded [int 1, int 1]]),
    (intTy, [guarded [int 1], plain [int 1], plain [int 1]]),
    (boolTy, [plain [bool true], guarded [bool false, .wild]]),
    (.list boolTy, [plain [.list [bool true] none []], plain [.list [bool false] none []],
      plain [.list [.wild] none []]])] : List (Ty × List Arm)).map
    (fun (ty, arms) => (checkMatch program ctors ty arms).coveredBy) =
    [[((1, 0), [0]), ((2, 0), [0])], [((2, 0), [0, 1])],
     [((2, 0), [0]), ((3, 0), [1]), ((4, 0), [0, 1])], [((3, 0), [1, 2])],
     [((3, 0), [2])], [((1, 0), [0])], [((0, 1), [])], [((0, 1), [])],
     [((2, 0), [1])], [((1, 1), [0])], [((2, 0), [0, 1])]] := by decide

/-- 覆う選択肢自体は同じ分岐も含める。存在しない位置なら空の並びを返す。 -/
example : [coveringAlternatives program ctors intTy [guarded [int 1, int 1]] 0 1,
    coveringAlternatives program ctors intTy [plain [int 1]] 1 0,
    coveringAlternatives program ctors intTy [plain [int 1]] 0 1] =
    [[(0, 0)], [], []] := by decide

/-- 重なりは値の種類・区間の交わり・構成子の引数・リストの対応する位置で判定する。
ワイルドカードと変数だけは型や相手の形を問わない。 -/
example : ([
    (intTy, .var, .const (.string "x")),
    (intTy, int 1, .range (.integer 1) (.integer 5)),
    (intTy, int 6, .range (.integer 1) (.integer 5)),
    (charTy, chars 97 109, chars 109 122),
    (charTy, chars 97 108, chars 109 122),
    (boolTy, bool true, bool false),
    (.base .unit, .const .unit, .const .unit),
    (.base .string, .const (.string "x"), .const (.string "y")),
    (.data "Choice" [boolTy], .con "L" [bool true], .con "L" [bool false]),
    (.data "Choice" [boolTy], .con "L" [bool true], .con "L" [.wild]),
    (.data "Choice" [boolTy], .con "L" [.wild], .con "R" [.wild]),
    (.list boolTy, .list [bool true] (some .skip) [], .list [] (some .skip) [bool false]),
    (.list boolTy, .list [bool true] none [], .list [] (some .skip) [bool false]),
    (.list boolTy, .list [] none [], .list [.wild] none [])] : List (Ty × Pat × Pat)).map
    (fun (ty, a, b) => overlaps program ctors ty a b) =
    [true, true, false, true, false, false, true, false, false, true, false, true, false, false] :=
  by decide

/-- Boolean の網羅性と、欠けた false の反例。 -/
example : ([[], [bool true], [bool true, bool false]] : List (List Pat)).map
    (fun ps => inspect boolTy (ps.map (fun p => plain [p]))) =
    [(some [.wild], [], false), (some [.boolean false], [], false), (none, [], false)] := by decide

/-- [] だけでは長さ 1 以上が欠ける。[] と [_, ..] なら網羅する。 -/
example : inspect (.list boolTy) [plain [.list [] none []]] =
    (some [.long 1 0 0], [], false) := by decide

example : inspect (.list boolTy)
    [plain [.list [] none []], plain [.list [.wild] (some .skip) []]] =
    (none, [], false) := by decide

/-- 同じ分岐の重複はガードの有無によらず選ばれない（Q3）。 -/
example : [plain [int 1, int 1], guarded [int 1, int 1]].map
    (fun arm => inspect intTy [arm]) =
    [(some [.other], [(0, 1)], false), (some [.wild], [(0, 1)], false)] := by decide

/-- ガードのある前の分岐は、後の分岐を覆わない。 -/
example : inspect intTy [guarded [int 1], plain [int 1], plain [.wild]] =
    (none, [], false) := by decide

/-- サロゲートだけの区間には Character の値がない。連続した問いは選ばれない。
10FFFF は Char.ofNat で書く。範囲の全体を覆っても網羅とは判定しない。 -/
example : inspect charTy
    [plain [chars 97 0xD7FF], plain [chars 0xE000 0x10FFFF], plain [chars 97 0x10FFFF]] =
    (some [.other], [(2, 0)], false) := by decide

example : inspect charTy [plain [chars 0 0x10FFFF]] = (some [.other], [], false) := by decide

/-- 問いを端の分割に含めないと、0 と 2 の間の 1 を見落とす。 -/
example : (useful program ctors [intTy] [[int 0], [int 2]]
    [.range (.integer 0) (.integer 2)]).map (List.flatMap summarize) =
    some [.interval false 1 1] := by decide

/-- 列の文字列の重複と、新しい文字列の問い。 -/
example : inspect (.base .string)
    [plain [.const (.string "old")], plain [.const (.string "old")], plain [.wild]] =
    (none, [(1, 0)], false) := by decide

example : (useful program ctors [.base .string] [[.const (.string "old")]]
    [.const (.string "new")]).map (List.flatMap summarize) = some [.string "new"] := by decide

/-- 型引数を置換し、構成子の引数に同じデータ型を入れたパターンを検査する。 -/
def nestedTy : Ty := .data "Choice" [.data "Choice" [boolTy]]
def nestedRows : List Arm :=
  [plain [.con "L" [.con "L" [.wild]]],
   plain [.con "L" [.con "R" [.wild]]], plain [.con "R" [.wild]]]

example : inspect nestedTy nestedRows = (none, [], false) := by decide

example : inspect nestedTy
    [plain [.con "L" [.con "L" [.wild]]],
     plain [.con "L" [.con "R" [bool true]]], plain [.con "R" [.wild]]] =
    (some [.con "L" 1, .con "R" 1, .boolean false], [], false) := by decide

/-- Unit と必ず照合するリスト。空リストだけの束縛は必ず照合しない。 -/
example : [irrefutable program ctors (.base .unit) (.const .unit),
    irrefutable program ctors (.list boolTy) (.list [] (some .bind) []),
    irrefutable program ctors (.list boolTy) (.list [] none [])] = [true, true, false] := by decide

/-- rest = none の after を捨てると、長さ 1 の重複を見落とす。 -/
example : inspect (.list boolTy)
    [plain [.list [] none [.var]], plain [.list [.wild] none []], plain [.wild]] =
    (none, [(1, 0)], false) := by decide

/-- 長いリストの前後を独立して特殊化する。false..true の分岐が欠ける。 -/
example : inspect (.list boolTy)
    [plain [.list [] none []], plain [.list [.wild] none []],
     plain [.list [bool true] (some .skip) [.wild]],
     plain [.list [bool false] (some .skip) [bool false]]] =
    (some [.long 2 1 1, .boolean false, .boolean true], [], false) := by decide

/-- 長さの違う全ワイルドカード行は、問いを覆わない。 -/
example : ([ [[]], [[.wild, .wild]], [[.wild], [.wild, .wild]] ] : List (List (List Pat))).map
    (fun rows => (useful program ctors [intTy] rows [.wild]).isSome) =
    [true, true, false] := by decide

/-- 定数・範囲の種類が列の型と違う行は照合しない。問いなら有用側に倒す。 -/
example : ([.const (.character 'a'), .range (.character 'a') (.character 'z'),
    .range (.integer 0) (.character 'z'), .const (.boolean true), .const .unit,
    .const (.string "97"), .const (.float 0.0), .const (.byte 97),
    .const (.decimal 97 0), .const (.opaque "O" 97)] : List Pat).map
    (fun p => ((useful program ctors [intTy] [[p]] [int 97]).isSome,
      (useful program ctors [intTy] [[.wild]] [p]).isSome)) =
    List.replicate 10 (true, true) := by decide

example : ([.const (.integer 97), .range (.integer 0) (.integer 127)] : List Pat).map
    (fun p => (useful program ctors [charTy] [[p]] [.const (.character 'a')]).isSome) =
    [true, true] := by decide

/-- 型の列が尽きた、宣言と引数数が違う、型パラメータの非ワイルドカードの問い（Q4）。 -/
example : [(useful program ctors [] [[.wild]] [.wild]).isSome,
    (useful program ctors [.data "Choice" [boolTy]] [[.wild]] [.con "L" []]).isSome,
    (useful program ctors [.data "Choice" []] [[.wild]] [.con "L" [.wild]]).isSome,
    (useful program ctors [.data "Other" [boolTy]] [[.wild]] [.con "L" [.wild]]).isSome,
    (useful program ctors [.tvar 0] [[.con "L" [.wild]]] [.con "L" [.wild]]).isSome] =
    [true, true, true, true, true] := by decide

/-- 余分な一覧の名前は値のない構成子として扱い、保守的な反例になりうる。 -/
example : ((checkMatch program (fun d => "missing" :: ctors d) (.data "Choice" [boolTy])
    [plain [.con "L" [.wild]], plain [.con "R" [.wild]]]).uncovered.map summarize) =
    some [.invalidCon "missing"] := by decide

/-- 宣言のない構成子の行が落ち、空の行列に対して有用と判定する。 -/
example : inspect (.data "Empty" []) [plain [.con "missing" []]] =
    (some [.wild], [], false) := by decide

/-- 燃料切れは有用側に倒し、記録を残す。 -/
example : (Coverage.usefulFuel program ctors 0 [boolTy] [[.wild]] [.wild]).fuelExhausted = true ∧
    (Coverage.usefulFuel program ctors 0 [boolTy] [[.wild]] [.wild]).witness.isSome := by decide

/-- slots が不整合でも、パターンの照合を覆う行に数える。firstAlt はここで失敗するが、
この言明の選択の定義は slots を使わない。 -/
def malformedSlots : List Arm :=
  [.mk [⟨.wild, [5]⟩] none (.ret (.const .unit)), plain [.wild]]

example : inspect intTy malformedSlots = (none, [(1, 0)], false) := by decide

example : (firstAlt (.const (.integer 0)) (malformedSlots.headD (plain [])).alts).isNone = true ∧
    (Pat.matchVal .wild (.const (.integer 0))).isSome := by decide

end CoverageExamples

end Benitoite.Release
