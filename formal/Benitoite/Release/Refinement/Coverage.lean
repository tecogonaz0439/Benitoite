import Benitoite.Release.Refinement.CoverageRefinement
import Benitoite.Release.Refinement.ScopePublicTyping
import Benitoite.Release.Refinement.ClosedDecidable
import Benitoite.Release.Refinement.TermStructuralEq

/-!
# 篩付きの型の網羅性の有限判定

パターンの行列を型の形ごとに特殊化し、燃料切れを不明として保持する。
判定は型付けと同じ宣言の表を読む（設計書 01-12「篩を読む網羅性と値の意味」）。
-/
namespace Benitoite.Release.Refinement

/-- 一覧には、宣言のあるすべての構成子を含める。余分な名前と重複は許す。 -/
def CtorsComplete (P : Program) (ctors : DataName → List ConName) : Prop :=
  ∀ c cd, P.cons c = some cd → c ∈ ctors cd.data

/-- 一つの本体から見て、将来の形を考慮するデータ型の指定。
宣言そのものの属性とは分ける（設計書 02-05「本体の後の検査」）。 -/
abbrev CoverageView := DataName → Bool

/-- 将来の構成子を加えずに判定する view。 -/
def closedView : CoverageView := fun _ => false

/-- 反例の形。区間の端は符号位置を含めて `Int` のまま保持する。
`other` は列のどのリテラル・範囲にも照合しない残りの値、`wild` は任意の値を表す。
`future d` は指定された型の将来の形であり、現在の値の存在を主張しない。
`long min before after` は長さ `min` 以上のリストである。 -/
inductive CoverageWitness where
  | wild
  | other
  | future (d : DataName)
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

/-- 評価には同じ共有型の正規化前の代入を使う。潜在効果の正規化は照合の形を変えない。 -/
def substTy (ts : List Ty) (a : Ty) : Ty := a.rawBind (typeEnvAt 0 ts [])
def substTys (ts : List Ty) (as : List Ty) : List Ty := as.map (substTy ts)

/-- 計算用の置換は、規範の型の置換と正規化の後で一致する。 -/
theorem substTy_norm (ts : List Ty) (a : Ty) : (substTy ts a).norm = a.subst ts [] := rfl

theorem inhabitsAll_of_norm {P : Program} {as : List Ty} {vs : List Val}
    (h : InhabitsAll P (as.map Ty.norm) vs) : InhabitsAll P as vs := by
  induction as generalizing vs with
  | nil => cases h; exact .nil
  | cons a as ih => cases h with
    | cons hv hs => exact .cons ((Inhabits.norm_all_iff a _).mp hv) (ih hs)

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
  match ty.core, p with
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
  let ends := match ty.core, p with
    | .base .integer, .const (.integer n) => some (n.toInt, n.toInt)
    | .base .integer, .range (.integer lo) (.integer hi) => some (lo.toInt, hi.toInt)
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

/-- Character の二つの値域を、列の下端と上端の直後でも分割する。 -/
def charBounds (column : List Pat) : List Int :=
  [0, 0xD800, 0xE000, 0x110000] ++
    (column.filterMap (interval (.base .character))).flatMap fun (lo, hi) => [lo, hi + 1]

/-- 有効なスカラー値だけを含む閉区間。サロゲートと値域外は列挙しない。 -/
def charPartition (column : List Pat) : List (Int × Int) :=
  (segments (charBounds column)).filter fun (lo, hi) =>
    0 ≤ lo && lo ≤ hi && hi < 0x110000 && (hi < 0xD800 || 0xE000 ≤ lo)

/-- Integer の境界計算は Int のままで行い、max64 + 1 を有界定数に戻さない。 -/
def integerBounds (column : List Pat) : List Int :=
  [min64, max64 + 1] ++
    (column.filterMap (interval (.base .integer))).flatMap fun (lo, hi) => [lo, hi + 1]

/-- 値域内の最小区間。覆われない区間も全域の判定のために保持する。 -/
def integerAtoms (column : List Pat) : List (Int × Int) :=
  (segments (integerBounds column)).filter fun (lo, hi) =>
    min64 ≤ lo && lo ≤ hi && hi ≤ max64

def integerCovered (column : List Pat) (lo hi : Int) : Bool :=
  (column.filterMap (interval (.base .integer))).any fun (a, b) => a ≤ lo && hi ≤ b

/-- 穴が一つでもあれば other を先頭に置く。区間の順と分割は保つ。 -/
def integerHasOther (column : List Pat) : Bool :=
  (integerAtoms column).any fun (lo, hi) => !integerCovered column lo hi

inductive Shape where
  | con (c : ConName) (fields : List Ty)
  | invalidCon (c : ConName)
  | future (d : DataName)
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

/-- 列は問いの先頭も含む。整数は全域を覆うときだけ `other` を除く。 -/
def shapes (P : Program) (ctors : DataName → List ConName) (ty : Ty)
    (column : List Pat) : List Shape :=
  match ty.core with
  | .data d ts => (ctors d).map fun c =>
      match conFields P d ts c with
      | some fields => .con c fields
      | none => .invalidCon c
  | .base .boolean => [.boolean true, .boolean false]
  | .base .unit => [.unit]
  | .base .character =>
      (charPartition column).map fun (lo, hi) => .interval true lo hi
  | .base .integer =>
      let covered := (integerAtoms column).filter fun (lo, hi) => integerCovered column lo hi
      (if integerHasOther column then [.other] else []) ++
        covered.map (fun (lo, hi) => .interval false lo hi)
  | .base .string =>
      let strings := column.filterMap fun p =>
        match p with | .const (.string s) => some s | _ => none
      .other :: strings.eraseDups.map Shape.string
  | .list a =>
      let (exactEnd, front, back) := listBounds column
      let min := max exactEnd (front + back)
      (List.range min).map (fun n => .exact n a) ++ [.long min front back a]
  | _ => [.other]

/-- view 付き判定の列挙。既知の形の順序を保ち、指定された data にだけ将来の形を足す。
view 付き判定の全再帰で同じ指定を使う（設計書 02-05「本体の後の検査」）。 -/
def shapesWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (ty : Ty) (column : List Pat) : List Shape :=
  shapes P ctors ty column ++ match ty.core with
    | .data d _ => if view d then [.future d] else []
    | _ => []

/-- 閉じた view は、形の順序と件数を変えずに列挙する。 -/
theorem shapesWithView_closed (P : Program) (ctors : DataName → List ConName)
    (ty : Ty) (column : List Pat) :
    shapesWithView P ctors closedView ty column = shapes P ctors ty column := by
  unfold shapesWithView
  split <;> simp [closedView]

/-- 将来の形を加えても、既知の構成子を含む元の形は一つも失わない。 -/
theorem mem_shapesWithView {P : Program} {ctors : DataName → List ConName}
    {ty : Ty} {column : List Pat} {s : Shape} (view : CoverageView)
    (h : s ∈ shapes P ctors ty column) : s ∈ shapesWithView P ctors view ty column := by
  exact List.mem_append_left _ h

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
  | .future d => .future d
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
        | .integer n => .interval false n.toInt n.toInt
        | .character c => .interval true (Int.ofNat c.toNat) (Int.ofNat c.toNat)
        | .boolean b => .boolean b
        | .unit => .unit
        | .string s => .string s
        | _ => .wild
    | .con c ps => .con c (queryWitnessList ps)
    | .range lo hi => match lo, hi with
        | .integer lo, .integer hi => .interval false lo.toInt hi.toInt
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
def usefulFuelWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView) :
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
            let r := usefulFuelWithView P ctors view fuel typesTail (rows.map List.tail) tail
            { r with witness := r.witness.map (CoverageWitness.wild :: ·) }
          else
            let ss := shapesWithView P ctors view ty column
            if !isWild q && !(ss.any fun s => (specialize q s).isSome) then fallback query else
            firstUseful (fun s =>
              match specialize q s with
              | none => ⟨none, false⟩
              | some args =>
                  let fields := s.fields
                  let r := usefulFuelWithView P ctors view fuel (fields ++ typesTail)
                    (specializeRows s rows) (args ++ tail)
                  match r.witness with
                  | none => r
                  | some ws =>
                      if ws.length = fields.length + tail.length then
                        { r with witness := some (s.witness (ws.take fields.length) :: ws.drop fields.length) }
                      else fallback query r.fuelExhausted) ss
      | _, _ => fallback query

/-- 将来の形を考慮しない入力を判定する。 -/
def usefulFuel (P : Program) (ctors : DataName → List ConName) :
    Nat → List Ty → List (List Pat) → List Pat → UsefulnessResult :=
  usefulFuelWithView P ctors closedView

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
def overlapsFuelWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView) :
    Nat → Ty → Pat → Pat → Bool
  | 0, _, _, _ => false
  | fuel + 1, ty, a, b =>
      if isWild a || isWild b then true else
      (shapesWithView P ctors view ty [a, b]).any fun s =>
        match specialize a s, specialize b s with
        | some xs, some ys =>
            xs.length == ys.length &&
              (s.fields.zip (xs.zip ys)).all (fun (t, x, y) => overlapsFuelWithView P ctors view fuel t x y)
        | _, _ => false

/-- 閉じた view の重なり判定。 -/
def overlapsFuel (P : Program) (ctors : DataName → List ConName) :
    Nat → Ty → Pat → Pat → Bool :=
  overlapsFuelWithView P ctors closedView

/-! ## 照合と値の並びの補題 -/

@[simp] theorem matchList_cons (p : Pat) (ps : List Pat) (v : Val) (vs : List Val) :
    (matchList (p :: ps) (v :: vs)).isSome =
      ((matchVal p v).isSome && (matchList ps vs).isSome) := by
  simp only [matchList]
  cases matchVal p v <;> cases matchList ps vs <;> rfl

theorem matchList_length {ps : List Pat} {vs : List Val}
    (h : (matchList ps vs).isSome) : ps.length = vs.length := by
  induction ps generalizing vs with
  | nil => cases vs <;> simp_all [matchList]
  | cons p ps ih =>
      cases vs with
      | nil => simp [matchList] at h
      | cons v vs => simp only [matchList_cons, Bool.and_eq_true] at h; simp [ih h.2]

@[simp] theorem matchList_append (ps qs : List Pat) (xs ys : List Val)
    (h : ps.length = xs.length) :
    (matchList (ps ++ qs) (xs ++ ys)).isSome =
      ((matchList ps xs).isSome && (matchList qs ys).isSome) := by
  induction ps generalizing xs with
  | nil => cases xs <;> simp_all [matchList]
  | cons p ps ih =>
      cases xs with
      | nil => simp at h
      | cons x xs =>
          simp only [List.length_cons, Nat.add_right_cancel_iff] at h
          simp [ih xs h, Bool.and_assoc]

theorem matchList_split (ps qs : List Pat) (vs : List Val) :
    (matchList (ps ++ qs) vs).isSome =
      ((matchList ps (vs.take ps.length)).isSome &&
       (matchList qs (vs.drop ps.length)).isSome) := by
  induction ps generalizing vs with
  | nil => simp [matchList]
  | cons p ps ih =>
      cases vs with
      | nil => simp [matchList]
      | cons v vs => simp [ih, Bool.and_assoc]

@[simp] theorem matchVal_wild {p : Pat} (hp : isWild p = true) (v : Val) :
    (matchVal p v).isSome = true := by
  cases p <;> simp_all [isWild, matchVal]

theorem matchList_wild {ps : List Pat} {vs : List Val}
    (hp : ps.all isWild = true) (hl : ps.length = vs.length) :
    (matchList ps vs).isSome = true := by
  induction ps generalizing vs with
  | nil => cases vs <;> simp_all [matchList]
  | cons p ps ih =>
      cases vs with
      | nil => simp at hl
      | cons v vs =>
          simp only [List.all_cons, Bool.and_eq_true] at hp
          simp only [List.length_cons, Nat.add_right_cancel_iff] at hl
          simp [matchVal_wild hp.1, ih hp.2 hl]

@[simp] theorem matchList_replicate (vs : List Val) :
    (matchList (List.replicate vs.length .wild) vs).isSome = true := by
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
    (matchVal (.list before rest after) (.list vs)).isSome =
      (decide (if rest.isSome then before.length + after.length ≤ vs.length
        else before.length + after.length = vs.length) &&
       (matchList before (vs.take before.length)).isSome &&
       (matchList after (vs.drop (vs.length - after.length))).isSome) := by
  cases rest with
  | none =>
      simp only [matchVal, Option.isSome_none, Bool.false_eq_true, ↓reduceIte]
      split <;> (cases matchList before (vs.take before.length) <;>
        cases matchList after (vs.drop (vs.length - after.length)) <;> simp_all)
  | some r =>
      simp only [matchVal, Option.isSome_some, ↓reduceIte]
      split <;> (cases matchList before (vs.take before.length) <;>
        cases matchList after (vs.drop (vs.length - after.length)) <;> simp_all)

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
    (matchList (before ++ List.replicate (xs.length - (before.length + after.length)) .wild ++ after) xs).isSome =
      ((matchList before (xs.take before.length)).isSome &&
       (matchList after (xs.drop (xs.length - after.length))).isSome) := by
  rw [List.append_assoc, matchList_split, matchList_split]
  have hm : ((xs.drop before.length).take (xs.length - (before.length + after.length))).length =
      xs.length - (before.length + after.length) := by simp; omega
  have hw : (matchList (List.replicate (xs.length - (before.length + after.length)) .wild)
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
    (matchList (before ++ List.replicate (front + back - (before.length + after.length)) .wild ++ after)
      (longValues front back xs)).isSome =
      (matchVal (.list before (some r) after) (.list xs)).isSome := by
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
  | future (d v) : Represents (.future d) v []
  | con (c fields ts xs) (hl : fields.length = xs.length) :
      Represents (.con c fields) (.con c ts xs) xs
  | atError (fields : List Ty) (detail : AtError) (hl : fields.length = detail.values.length) :
      Represents (.con "Scope.ScopeError.At" fields) (.atError detail) detail.values
  | boolean (b) : Represents (.boolean b) (.const (.boolean b)) []
  | unit : Represents .unit (.const .unit) []
  | string (s) : Represents (.string s) (.const (.string s)) []
  | integer (lo hi : Int) (n : Integer64Value) (hl : lo ≤ n.toInt) (hh : n.toInt ≤ hi) :
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

theorem interval_integer_sound {p : Pat} {a b : Int} {n : Integer64Value}
    (h : interval (.base .integer) p = some (a, b)) (ha : a ≤ n.toInt) (hb : n.toInt ≤ b) :
    (matchVal p (.const (.integer n))).isSome = true := by
  cases p with
  | const c => cases c <;> simp_all [interval, Ty.core, matchVal, patternMatches, Option.filter] <;> omega
  | range lo hi =>
      cases lo <;> cases hi <;> simp_all [interval, Ty.core, matchVal, patternRange, Option.filter] <;> omega
  | _ => simp [interval] at h

theorem interval_character_sound {p : Pat} {a b : Int} {c : Char}
    (h : interval (.base .character) p = some (a, b))
    (ha : a ≤ Int.ofNat c.toNat) (hb : Int.ofNat c.toNat ≤ b) :
    (matchVal p (.const (.character c))).isSome = true := by
  cases p with
  | const k =>
      cases k <;> simp_all [interval, Ty.core, matchVal, patternMatches, Option.filter]
      rename_i k
      have he : k.toNat = c.toNat := by omega
      exact Char.toNat_inj.mp he
  | range lo hi =>
      cases lo <;> cases hi <;> simp_all [interval, Ty.core, matchVal, patternRange, Option.filter] <;> omega
  | _ => simp [interval] at h

theorem Represents.restore {s : Shape} {v : Val} {xs : List Val}
    (hr : Represents s v xs) {p : Pat} {ps : List Pat}
    (hs : specialize p s = some ps) (hm : (matchList ps xs).isSome = true) :
    (matchVal p v).isSome = true := by
  by_cases hw : isWild p = true
  · exact matchVal_wild hw v
  have hw' : isWild p = false := by cases he : isWild p <;> simp_all
  cases hr with
  | other v => cases p <;> simp_all [specialize, isWild]
  | future d v => cases p <;> simp_all [specialize, isWild]
  | con c fields ts xs hl =>
      cases p <;> simp [specialize, isWild] at hs hw'
      obtain ⟨⟨rfl, _⟩, rfl⟩ := hs
      simpa [matchVal] using hm
  | atError fields detail hl =>
      cases p <;> simp [specialize, isWild] at hs hw'
      obtain ⟨⟨rfl, _⟩, rfl⟩ := hs
      simpa [matchVal] using hm
  | boolean b =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i k
      cases k <;> simp at hs
      obtain ⟨rfl, rfl⟩ := hs
      simp [matchVal, patternMatches]
  | unit =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i k
      cases k <;> simp at hs
      simp [matchVal, patternMatches]
  | string b =>
      cases p <;> simp [specialize, isWild] at hs hw'
      rename_i k
      cases k <;> simp at hs
      obtain ⟨rfl, rfl⟩ := hs
      simp [matchVal, patternMatches]
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
    ∃ ps, specialize q s = some ps ∧ (matchList ps xs).isSome = true := by
  refine ⟨List.replicate s.fields.length .wild, by simp [specialize, hq], ?_⟩
  simp [hr.length]

theorem integer_interval_of_match {P : Program} {q : Pat} {n : Integer64Value}
    (hw : isWild q = false) (hc : compatible P (.base .integer) q = true)
    (hm : (matchVal q (.const (.integer n))).isSome = true) :
    ∃ a b, interval (.base .integer) q = some (a, b) ∧ a ≤ n.toInt ∧ n.toInt ≤ b := by
  cases q with
  | const c =>
      cases c <;> simp_all [isWild, compatible, matchVal, patternMatches]
      exact ⟨n.toInt, n.toInt, by simp [interval, Ty.core, hm], by omega, by omega⟩
  | range a b =>
      cases a <;> cases b <;> simp_all [isWild, compatible, matchVal, patternRange]
      rename_i a b
      exact ⟨a.toInt, b.toInt, by simp [interval, Ty.core, Option.filter, show a.toInt ≤ b.toInt by omega], hm.1, hm.2⟩
  | _ => simp_all [isWild, compatible]

theorem character_interval_of_match {P : Program} {q : Pat} {c : Char}
    (hw : isWild q = false) (hc : compatible P (.base .character) q = true)
    (hm : (matchVal q (.const (.character c))).isSome = true) :
    ∃ a b, interval (.base .character) q = some (a, b) ∧ a ≤ (c.toNat : Int) ∧ (c.toNat : Int) ≤ b := by
  cases q with
  | const k =>
      cases k <;> simp_all [isWild, compatible, matchVal, patternMatches]
      exact ⟨(c.toNat : Int), (c.toNat : Int), by simp [interval], by omega, by omega⟩
  | range a b =>
      cases a <;> cases b <;> simp_all [isWild, compatible, matchVal, patternRange]
      rename_i a b
      exact ⟨(a.toNat : Int), (b.toNat : Int),
        by simp [interval, Ty.core, Option.filter, show a.toNat ≤ b.toNat by omega], by omega, by omega⟩
  | _ => simp_all [isWild, compatible]

/-- 分割の区間の内部に、別の分割端はない。 -/
theorem segments_refine {bounds : List Int} {lo hi n x : Int}
    (hs : (lo, hi) ∈ segments bounds) (hl : lo ≤ n) (hh : n ≤ hi) (hx : x ∈ bounds) :
    (x ≤ n → x ≤ lo) ∧ (n < x → hi < x) := by
  obtain ⟨v, _, he⟩ := List.mem_filterMap.mp hs
  unfold intervalAt at he
  cases helo : lowerEnd bounds v with
  | none => simp [helo] at he
  | some l =>
    cases hehi : upperEnd bounds v with
    | none => simp [helo, hehi] at he
    | some h =>
      simp [helo, hehi] at he
      have hlow := lowerEnd_some helo
      have hupp := upperEnd_some hehi
      constructor
      · intro hxn
        by_cases hxv : x ≤ v
        · have := hlow.2.2 x hx hxv; omega
        · have := hupp.2.2 x hx (by omega); omega
      · intro hnx
        by_cases hxv : x ≤ v
        · have := hlow.2.2 x hx hxv; omega
        · have := hupp.2.2 x hx (by omega); omega

/-- 列挙した区間の両端は元の境界に由来する。 -/
theorem segments_ends {bounds : List Int} {lo hi : Int}
    (hs : (lo, hi) ∈ segments bounds) :
    lo ∈ bounds ∧ hi + 1 ∈ bounds ∧ lo ≤ hi := by
  obtain ⟨v, _, he⟩ := List.mem_filterMap.mp hs
  unfold intervalAt at he
  cases hl : lowerEnd bounds v with
  | none => simp [hl] at he
  | some l =>
    cases hh : upperEnd bounds v with
    | none => simp [hl, hh] at he
    | some h =>
      simp only [hl, hh, Option.pure_def] at he
      have hlow := lowerEnd_some hl
      have hupp := upperEnd_some hh
      obtain ⟨rfl, rfl⟩ := he
      exact ⟨hlow.1, by simpa using hupp.1, by omega⟩

/-- 同じ値を含む最小区間は一つである。 -/
theorem segments_unique {bounds : List Int} {lo hi lo' hi' n : Int}
    (hs : (lo, hi) ∈ segments bounds) (hs' : (lo', hi') ∈ segments bounds)
    (hl : lo ≤ n) (hh : n ≤ hi) (hl' : lo' ≤ n) (hh' : n ≤ hi') :
    (lo, hi) = (lo', hi') := by
  have ends := segments_ends hs
  have ends' := segments_ends hs'
  have a := (segments_refine hs hl hh ends'.1).1 hl'
  have b := (segments_refine hs' hl' hh' ends.1).1 hl
  have c := (segments_refine hs hl hh ends'.2.1).2 (by omega)
  have d := (segments_refine hs' hl' hh' ends.2.1).2 (by omega)
  congr 1 <;> omega

/-- 有界整数の各値は、全域内の最小区間のちょうど一つに属する。 -/
theorem integer_partition_unique (column : List Pat) (n : Integer64Value) :
    ∃ atom, (atom ∈ integerAtoms column ∧ atom.1 ≤ n.toInt ∧ n.toInt ≤ atom.2) ∧
      ∀ other, (other ∈ integerAtoms column ∧ other.1 ≤ n.toInt ∧ n.toInt ≤ other.2) → other = atom := by
  have bounds := n.toInt_bounds
  have ends (x : Int) (hx : x ∈ [min64, max64 + 1]) : x ∈ integerBounds column :=
    List.mem_append_left _ hx
  obtain ⟨lo, hi, hs, hmin, hl, hh, hmax⟩ :=
    segments_cover (ends min64 (by simp)) (ends (max64 + 1) (by simp)) bounds.1 bounds.2
  refine ⟨(lo, hi), ⟨List.mem_filter.mpr ⟨hs, by simp [hmin, hmax]; omega⟩, hl, hh⟩, ?_⟩
  intro (lo', hi') h
  exact segments_unique (List.mem_filter.mp h.1).1 hs h.2.1 h.2.2 hl hh

/-- 問いに照合する値を含む最小区間は、その問いの全体にも含まれる。 -/
theorem integer_atom_query {column : List Pat} {q : Pat} {a b lo hi n : Int}
    (hq : q ∈ column) (hqint : interval (.base .integer) q = some (a, b))
    (hs : (lo, hi) ∈ integerAtoms column) (hl : lo ≤ n) (hh : n ≤ hi)
    (ha : a ≤ n) (hb : n ≤ b) : a ≤ lo ∧ hi ≤ b := by
  have hm := List.mem_filterMap.mpr ⟨q, hq, hqint⟩
  have ends (x : Int) (hx : x ∈ [a, b + 1]) : x ∈ integerBounds column :=
    List.mem_append_right _ (List.mem_flatMap.mpr ⟨(a, b), hm, hx⟩)
  have hseg := (List.mem_filter.mp hs).1
  exact ⟨(segments_refine hseg hl hh (ends a (by simp))).1 ha,
    by have := (segments_refine hseg hl hh (ends (b + 1) (by simp))).2 (by omega); omega⟩

/-- 区間の被覆は、その区間の各値について元の列の被覆と同値である。 -/
theorem integer_covered_iff {column : List Pat} {lo hi n : Int}
    (hs : (lo, hi) ∈ integerAtoms column) (hl : lo ≤ n) (hh : n ≤ hi) :
    integerCovered column lo hi = true ↔
      ∃ q ∈ column, ∃ a b, interval (.base .integer) q = some (a, b) ∧ a ≤ n ∧ n ≤ b := by
  constructor
  · intro h
    obtain ⟨⟨a, b⟩, hm, hc⟩ := List.any_eq_true.mp h
    obtain ⟨q, hq, he⟩ := List.mem_filterMap.mp hm
    simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
    exact ⟨q, hq, a, b, he, by omega, by omega⟩
  · rintro ⟨q, hq, a, b, he, ha, hb⟩
    have h := integer_atom_query hq he hs hl hh ha hb
    exact List.any_eq_true.mpr ⟨(a, b), List.mem_filterMap.mpr ⟨q, hq, he⟩, by simp [h.1, h.2]⟩

/-- 全域内の値には、列挙済みの被覆区間か、実際に必要な other がある。 -/
theorem integer_shapes_complete (P : Program) (ctors : DataName → List ConName)
    (column : List Pat) (n : Integer64Value) :
    ∃ s, s ∈ shapes P ctors (.base .integer) column ∧
      Represents s (.const (.integer n)) [] := by
  obtain ⟨⟨lo, hi⟩, hs, _⟩ := integer_partition_unique column n
  by_cases hc : integerCovered column lo hi = true
  · refine ⟨.interval false lo hi, ?_, .integer lo hi n hs.2.1 hs.2.2⟩
    apply List.mem_append_right
    exact List.mem_map.mpr ⟨(lo, hi), List.mem_filter.mpr ⟨hs.1, hc⟩, rfl⟩
  · have ho : integerHasOther column = true :=
      List.any_eq_true.mpr ⟨(lo, hi), hs.1, by simp [hc]⟩
    exact ⟨.other, by simp [shapes, Ty.core, ho], .other _⟩

/-- 整数のパターンから得た区間の端は、必ず値域内にある。 -/
theorem integer_interval_bounds {q : Pat} {a b : Int}
    (h : interval (.base .integer) q = some (a, b)) : min64 ≤ a ∧ b ≤ max64 := by
  cases q <;> simp [interval, Ty.core, Option.filter] at h
  case const c =>
    cases c <;> simp at h
    rename_i n
    obtain ⟨rfl, rfl⟩ := h
    exact n.toInt_bounds
  case range l r =>
    cases l <;> cases r <;> simp at h
    rename_i l r
    obtain ⟨_, rfl, rfl⟩ := h
    exact ⟨l.toInt_bounds.1, r.toInt_bounds.2⟩

/-- 入力の区間を覆う最小区間を、分割したまま取り出す。 -/
theorem shapes_interval_cover (P : Program) (ctors : DataName → List ConName)
    (column : List Pat) (q : Pat) (a b n : Int)
    (hq : q ∈ column) (hi : interval (.base .integer) q = some (a, b))
    (ha : a ≤ n) (hb : n ≤ b) :
    ∃ lo hh, Shape.interval false lo hh ∈ shapes P ctors (.base .integer) column ∧
      lo ≤ n ∧ n ≤ hh ∧ a ≤ lo ∧ hh ≤ b := by
  have bounds := integer_interval_bounds hi
  let value : Integer64Value := ⟨n, by omega, by omega⟩
  obtain ⟨⟨lo, hh⟩, hs, _⟩ := integer_partition_unique column value
  have he := integer_atom_query hq hi hs.1 hs.2.1 hs.2.2 ha hb
  refine ⟨lo, hh, ?_, hs.2.1, hs.2.2, he.1, he.2⟩
  apply List.mem_append_right
  exact List.mem_map.mpr ⟨(lo, hh), List.mem_filter.mpr ⟨hs.1,
    (integer_covered_iff hs.1 hs.2.1 hs.2.2).mpr ⟨q, hq, a, b, hi, ha, hb⟩⟩, rfl⟩

/-- 全ての Char は、サロゲートを含まない列挙済みの区間に属する。 -/
theorem char_partition_cover (column : List Pat) (c : Char) :
    ∃ lo hi, (lo, hi) ∈ charPartition column ∧ lo ≤ (c.toNat : Int) ∧ (c.toNat : Int) ≤ hi := by
  have hc := c.valid
  change c.toNat < 55296 ∨ 57343 < c.toNat ∧ c.toNat < 1114112 at hc
  have hb (x : Int) (h : x ∈ ([0, 0xD800, 0xE000, 0x110000] : List Int)) :
      x ∈ charBounds column := List.mem_append_left _ h
  have hz := hb 0 (by simp)
  have he := hb 0x110000 (by simp)
  obtain ⟨lo, hi, hs, hlo, hlc, hch, hhi⟩ :=
    segments_cover hz (b := 0x10FFFF) (by simpa using he)
      (v := (c.toNat : Int)) (by omega) (by omega)
  have hscalar : hi < 0xD800 ∨ 0xE000 ≤ lo := by
    rcases hc with hc | hc
    · have := (segments_refine hs hlc hch (hb 0xD800 (by simp))).2 (by omega)
      exact Or.inl (by omega)
    · have := (segments_refine hs hlc hch (hb 0xE000 (by simp))).1 (by omega)
      exact Or.inr this
  exact ⟨lo, hi, List.mem_filter.mpr ⟨hs, by simp [hlo, hscalar]; omega⟩, hlc, hch⟩

/-- 問いの端も分割に含まれるため、値を含む区間全体が問いの範囲内にある。 -/
theorem char_partition_query {column : List Pat} {q : Pat} {a b : Int} {c : Char}
    (hq : q ∈ column) (hi : interval (.base .character) q = some (a, b))
    (ha : a ≤ (c.toNat : Int)) (hb : (c.toNat : Int) ≤ b) :
    ∃ lo hh, (lo, hh) ∈ charPartition column ∧ lo ≤ (c.toNat : Int) ∧
      (c.toNat : Int) ≤ hh ∧ a ≤ lo ∧ hh ≤ b := by
  obtain ⟨lo, hh, hs, hl, hu⟩ := char_partition_cover column c
  have hm := List.mem_filterMap.mpr ⟨q, hq, hi⟩
  have ends : ∀ x ∈ ([a, b + 1] : List Int), x ∈ charBounds column := by
    intro x hx
    exact List.mem_append_right _ (List.mem_flatMap.mpr ⟨(a,b), hm, hx⟩)
  have hal := (segments_refine (List.mem_filter.mp hs).1 hl hu (ends a (by simp))).1 ha
  have hhb := (segments_refine (List.mem_filter.mp hs).1 hl hu (ends (b+1) (by simp))).2 (by omega)
  exact ⟨lo, hh, hs, hl, hu, hal, by omega⟩

/-- 先頭の値の照合を、形の引数の照合に移すための全前提。 -/
def ShapeStep (P : Program) (ctors : DataName → List ConName) (ty : Ty)
    (column : List Pat) (q : Pat) (v : Val) : Prop :=
  ∃ s xs ps, s ∈ shapes P ctors ty column ∧ Represents s v xs ∧
    InhabitsAll P s.fields xs ∧ specialize q s = some ps ∧ (matchList ps xs).isSome = true

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
    {column : List Pat} {q : Pat} {n : Integer64Value}
    (hq : q ∈ column) (hc : compatible P (.base .integer) q = true)
    (hm : (matchVal q (.const (.integer n))).isSome = true) :
    ShapeStep P ctors (.base .integer) column q (.const (.integer n)) := by
  by_cases hw : isWild q = true
  · obtain ⟨s, hs, hr⟩ := integer_shapes_complete P ctors column n
    exact shapeStep_wild hs hr (by cases hr <;> exact .nil) hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  obtain ⟨a,b, hi, ha,hb⟩ := integer_interval_of_match hw' hc hm
  obtain ⟨lo,hh, hs,hl,hu,hal,hhb⟩ := shapes_interval_cover P ctors column q a b n.toInt hq hi ha hb
  refine ⟨.interval false lo hh, [], [], hs, .integer lo hh n hl hu, .nil, ?_, rfl⟩
  simp [specialize, hw', hi, hal, hhb]

theorem shapeStep_character {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {c : Char}
    (hq : q ∈ column) (hc : compatible P (.base .character) q = true)
    (hm : (matchVal q (.const (.character c))).isSome = true) :
    ShapeStep P ctors (.base .character) column q (.const (.character c)) := by
  by_cases hw : isWild q = true
  · obtain ⟨lo, hi, hs, hl, hh⟩ := char_partition_cover column c
    exact shapeStep_wild (List.mem_map.mpr ⟨(lo, hi), hs, rfl⟩) (.character lo hi c hl hh) .nil hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  obtain ⟨a,b, hi, ha,hb⟩ := character_interval_of_match hw' hc hm
  obtain ⟨lo,hh, hs,hl,hu,hal,hhb⟩ := char_partition_query hq hi ha hb
  refine ⟨.interval true lo hh, [], [], List.mem_map.mpr ⟨(lo,hh), hs, rfl⟩,
    .character lo hh c hl hu, .nil, ?_, rfl⟩
  simp [specialize, hw', hi, hal, hhb]

theorem shapeStep_list {P : Program} {ctors : DataName → List ConName}
    {a : Ty} {column : List Pat} {q : Pat} {xs : List Val}
    (hq : q ∈ column) (hc : compatible P (.list a) q = true)
    (hx : InhabitsEach P a xs) (hm : (matchVal q (.list xs)).isSome = true) :
    ShapeStep P ctors (.list a) column q (.list xs) := by
  let bounds := listBounds column
  let min := max bounds.1 (bounds.2.1 + bounds.2.2)
  have hfront : bounds.2.1 + bounds.2.2 ≤ min := Nat.le_max_right _ _
  have hexact : bounds.1 ≤ min := Nat.le_max_left _ _
  by_cases hlen : xs.length < min
  · have hs : Shape.exact xs.length a ∈ shapes P ctors (.list a) column := by
      simp only [shapes, Ty.core, List.mem_append]
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
      simp [shapes, Ty.core, min, bounds]
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
    (hm : (matchVal q (.con c tys xs)).isSome = true) :
    ShapeStep P ctors (.data cd.data ts) column q (.con c tys xs) := by
  let fields := substTys ts cd.args
  have hf : conFields P cd.data ts c = some fields := by simp [conFields, hdecl, hn, fields]
  have hi : InhabitsAll P fields xs := by
    apply inhabitsAll_of_norm
    simpa only [fields, substTys, List.map_map, Function.comp_def, substTy_norm] using hx
  have hs : Shape.con c fields ∈ shapes P ctors (.data cd.data ts) column := by
    apply List.mem_map.mpr
    exact ⟨c, hctors c cd hdecl, by simp [hf]⟩
  have hr : Represents (.con c fields) (.con c tys xs) xs := .con c fields tys xs (inhabitsAll_length hi)
  by_cases hw : isWild q = true
  · exact shapeStep_wild hs hr hi hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [isWild, compatible] at hc hw'
  rename_i d ps
  simp only [matchVal] at hm
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
    (hm : (matchVal q (.const (.boolean b))).isSome = true) :
    ShapeStep P ctors (.base .boolean) column q (.const (.boolean b)) := by
  have hs : Shape.boolean b ∈ shapes P ctors (.base .boolean) column := by cases b <;> simp [shapes, Ty.core]
  by_cases hw : isWild q = true
  · exact shapeStep_wild hs (.boolean b) .nil hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [compatible, Ty.core, isWild] at hc hw'
  rename_i k
  cases k <;> simp at hc
  simp [matchVal, patternMatches] at hm
  subst b
  exact ⟨.boolean _, [], [], hs, .boolean _, .nil, by simp [specialize, isWild], rfl⟩

theorem shapeStep_unit {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat}
    (hc : compatible P (.base .unit) q = true)
    (hm : (matchVal q (.const .unit)).isSome = true) :
    ShapeStep P ctors (.base .unit) column q (.const .unit) := by
  have hs : Shape.unit ∈ shapes P ctors (.base .unit) column := by simp [shapes, Ty.core]
  by_cases hw : isWild q = true
  · exact shapeStep_wild hs .unit .nil hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [compatible, Ty.core, isWild] at hc hw'
  rename_i k
  cases k <;> simp at hc
  exact ⟨.unit, [], [], hs, .unit, .nil, by simp [specialize, isWild], rfl⟩

theorem shapeStep_string {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {s : String} (hq : q ∈ column)
    (hc : compatible P (.base .string) q = true)
    (hm : (matchVal q (.const (.string s))).isSome = true) :
    ShapeStep P ctors (.base .string) column q (.const (.string s)) := by
  by_cases hw : isWild q = true
  · exact shapeStep_other (by simp [shapes, Ty.core]) hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [compatible, Ty.core, isWild] at hc hw'
  rename_i k
  cases k <;> simp at hc
  simp [matchVal, patternMatches] at hm
  subst s
  rename_i str
  have hs : Shape.string str ∈ shapes P ctors (.base .string) column := by
    simp only [shapes, Ty.core, List.mem_cons]
    right
    apply List.mem_map.mpr
    refine ⟨_, List.mem_eraseDups.mpr (List.mem_filterMap.mpr ⟨_, hq, rfl⟩), rfl⟩
  exact ⟨.string _, [], [], hs, .string _, .nil, by simp [specialize, isWild], rfl⟩

private theorem public_subst_wf (a : ScopePublic.PublicTy) (n : Nat) : a.ty.WF 0 n 0 :=
  groundTy_wf (ScopePublic.PublicTy.ground a)

mutual
  private theorem publicTree_inhabits {P : Program} (hp : P.HasScopePublic)
      {t : ScopePublic.PublicTree} {a : ScopePublic.PublicTy} (h : t.Typed a) :
      Inhabits P a.ty t.toVal := by
    match h with
    | .text s => exact Inhabits.const (c := .string s)
    | .integer n => exact Inhabits.const (c := .integer n)
    | .bytes _ => exact .bytes
    | .list _ hs => exact .list (publicTrees_each hp hs)
    | .none _ => exact .con hp.optionNone rfl (by simp) .nil
    | .some (a := a) _ hx =>
      refine .con hp.optionSome rfl ?_ ?_
      · intro b hb; cases List.mem_singleton.mp hb; exact Nat.zero_lt_one
      · simpa [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt,
          ScopePublic.PublicTy.norm_ty] using InhabitsAll.cons (publicTree_inhabits hp hx) InhabitsAll.nil
    | .con (c := c) (d := d) (as := as) hl hs =>
      refine .con (hp.cons c d as (ScopePublic.lookup_mem hl)) rfl ?_ ?_
      · intro b hb; obtain ⟨a, _, rfl⟩ := List.mem_map.mp hb
        exact public_subst_wf a 0
      · simpa [List.map_map, Function.comp_def, ScopePublic.PublicTy.subst_ty]
          using publicTrees_all hp hs
  private theorem publicTrees_all {P : Program} (hp : P.HasScopePublic)
      {ts : List ScopePublic.PublicTree} {as : List ScopePublic.PublicTy}
      (h : ScopePublic.PublicTree.TypedAll ts as) :
      InhabitsAll P (as.map ScopePublic.PublicTy.ty) (ScopePublic.PublicTree.toVals ts) := by
    match h with
    | .nil => exact .nil
    | .cons hx hs => exact .cons (publicTree_inhabits hp hx) (publicTrees_all hp hs)
  private theorem publicTrees_each {P : Program} (hp : P.HasScopePublic)
      {ts : List ScopePublic.PublicTree} {a : ScopePublic.PublicTy}
      (h : ScopePublic.PublicTree.TypedEach ts a) :
      InhabitsEach P a.ty (ScopePublic.PublicTree.toVals ts) := by
    match h with
    | .nil => exact .nil
    | .cons hx hs => exact .cons (publicTree_inhabits hp hx) (publicTrees_each hp hs)
end

/-- 公開の宣言を持つ表で、At の診断の欄は同じ欄の型に所属する。 -/
theorem Detail.values_inhabits {P : Program} (hp : P.HasScopePublic) (detail : AtError) :
    InhabitsAll P atErrorFields detail.values :=
  .cons (publicTree_inhabits hp detail.publicTree_typed) .nil

private theorem shapeStep_atError {P : Program} {ctors : DataName → List ConName}
    {column : List Pat} {q : Pat} {detail : AtError}
    (hctors : CtorsComplete P ctors)
    (herr : ResultShape.StandardError P ⟨"Result", "Ok", "Error", atErrorType⟩)
    (hc : compatible P atErrorType q = true)
    (hm : (matchVal q (.atError detail)).isSome = true) :
    ShapeStep P ctors atErrorType column q (.atError detail) := by
  obtain ⟨_, _, ⟨cd, hd, hdata, hn, hargs⟩, hp⟩ := herr
  have hi : InhabitsAll P atErrorFields detail.values := Detail.values_inhabits hp detail
  have hf : conFields P "Scope.ScopeError" [] "Scope.ScopeError.At" = some atErrorFields := by
    simp [conFields, hd, hdata, hn, hargs, substTys, substTy, atErrorFields,
      atDetailType, Ty.rawBind, rawBindTys]
  have hs : Shape.con "Scope.ScopeError.At" atErrorFields ∈ shapes P ctors atErrorType column := by
    apply List.mem_map.mpr
    exact ⟨_, by simpa only [hdata] using hctors _ _ hd, by simp [hf]⟩
  have hr : Represents (.con "Scope.ScopeError.At" atErrorFields) (.atError detail) detail.values :=
    .atError _ _ (by simp [atErrorFields, Detail.values])
  by_cases hw : isWild q = true
  · exact shapeStep_wild hs hr hi hw
  have hw' : isWild q = false := by cases he : isWild q <;> simp_all
  cases q <;> simp [isWild, compatible, atErrorType, Ty.core] at hc hw'
  rename_i c ps
  simp only [matchVal] at hm
  split at hm
  · rename_i he
    subst c
    have hl : ps.length = atErrorFields.length := (matchList_length hm).trans hr.length.symm
    exact ⟨_, _, ps, hs, hr, hi, by simp [specialize, isWild, hl], hm⟩
  · simp_all

/-- 問いが照合する値に対応する形と、特殊化した問いの照合を取り出す。 -/
theorem shapes_cover {P : Program} {ctors : DataName → List ConName}
    {ty : Ty} {column : List Pat} {q : Pat} {v : Val}
    (hctors : CtorsComplete P ctors) (hq : q ∈ column) (hv : Inhabits P ty v)
    (hc : compatible P ty q = true) (hm : (matchVal q v).isSome = true) :
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
          apply shapeStep_other (by simp [Const.type, Ty.core, shapes])
          cases q <;> simp_all [Const.type, Ty.core, compatible, isWild]
  | con hd hn _ hx => exact shapeStep_con hctors hd hn hx hc hm
  | @refined a φ v hv _ => exact shapes_cover (ty := a) hctors hq hv hc hm
  | atError hs => exact shapeStep_atError hctors hs hc hm
  | list hx => exact shapeStep_list hq hc hx hm
  | _ =>
      apply shapeStep_other (by simp [shapes, Ty.core])
      cases q <;> simp_all [compatible, Ty.core, isWild]

termination_by sizeOf ty
decreasing_by
  simp_all
  omega

/-- 現在の値の特殊化の証拠は、任意の view で列挙した形にも残る。
将来の形に現在の値を割り当てる前提は加えない。 -/
theorem shapesWithView_cover {P : Program} {ctors : DataName → List ConName}
    {ty : Ty} {column : List Pat} {q : Pat} {v : Val} (view : CoverageView)
    (hctors : CtorsComplete P ctors) (hq : q ∈ column) (hv : Inhabits P ty v)
    (hc : compatible P ty q = true) (hm : (matchVal q v).isSome = true) :
    ∃ s xs ps, s ∈ shapesWithView P ctors view ty column ∧ Represents s v xs ∧
      InhabitsAll P s.fields xs ∧ specialize q s = some ps ∧
      (matchList ps xs).isSome = true := by
  obtain ⟨s, xs, ps, hs, hr, hi, hp, hm⟩ := shapes_cover hctors hq hv hc hm
  exact ⟨s, xs, ps, mem_shapesWithView view hs, hr, hi, hp, hm⟩

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
    (hrow : row ∈ specializeRows s rows) (hm : (matchList row (xs ++ vs)).isSome = true) :
    ∃ r ∈ rows, (matchList r (v :: vs)).isSome = true := by
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
theorem usefulFuelWithView_none_sound_of_cover (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView) (Q : Program)
    (cover : ∀ {ty column q v}, q ∈ column → Inhabits Q ty v →
      compatible P ty q = true → (matchVal q v).isSome = true →
      ∃ s xs ps, s ∈ shapesWithView P ctors view ty column ∧ Represents s v xs ∧
        InhabitsAll Q s.fields xs ∧ specialize q s = some ps ∧
        (matchList ps xs).isSome = true) (fuel : Nat) :
    ∀ tys rows q vs, (usefulFuelWithView P ctors view fuel tys rows q).witness = none →
      InhabitsAll Q tys vs → (matchList q vs).isSome = true →
      ∃ row ∈ rows, (matchList row vs).isSome = true := by
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
                    exact ⟨r, hm, by simp [hr, matchList]⟩
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
                              have hmt : (matchList ps vs).isSome = true := by simpa only [List.tail_cons] using hm
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
                            have hqa : (matchList (args ++ qs) (xs ++ vs)).isSome = true := by
                              rw [matchList_append args qs xs vs (matchList_length hargs)]
                              simp [hargs, hq.2]
                            obtain ⟨r, hrr, hmatch⟩ := ih (s.fields ++ tys) (specializeRows s rows) (args ++ qs)
                              _ hrec (inhabitsAll_append hxs hvs) hqa
                            obtain ⟨r, hrr, hmatch⟩ := specializeRows_restore hr
                              (by intro r hr; have hl := hlength r hr; simpa using hl) hrr hmatch
                            exact ⟨r, hsub r hrr, hmatch⟩

/-- 燃料切れは有用と答えるので、任意の燃料について健全である。 -/
theorem usefulFuelWithView_none_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView) (hc : CtorsComplete P ctors) (fuel : Nat) :
    ∀ tys rows q vs, (usefulFuelWithView P ctors view fuel tys rows q).witness = none →
      InhabitsAll P tys vs → (matchList q vs).isSome = true →
      ∃ row ∈ rows, (matchList row vs).isSome = true :=
  usefulFuelWithView_none_sound_of_cover P ctors view P
    (shapesWithView_cover view hc) fuel

/-- 閉じた入口も同じ前提・結論で健全である。 -/
theorem usefulFuel_none_sound (P : Program) (ctors : DataName → List ConName)
    (hc : CtorsComplete P ctors) (fuel : Nat) :
    ∀ tys rows q vs, (usefulFuel P ctors fuel tys rows q).witness = none →
      InhabitsAll P tys vs → (matchList q vs).isSome = true →
      ∃ row ∈ rows, (matchList row vs).isSome = true :=
  usefulFuelWithView_none_sound P ctors closedView hc fuel

end Coverage

/-- 入力の大きさから燃料を決めた有用性の判定と燃料切れの記録。 -/
def usefulReportWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (tys : List Ty) (rows : List (List Pat)) (q : List Pat) : UsefulnessResult :=
  Coverage.usefulFuelWithView P ctors view (Coverage.fuelFor P ctors tys rows q) tys rows q

/-- 入力から燃料を求める、閉じた view の入口。 -/
def usefulReport (P : Program) (ctors : DataName → List ConName) (tys : List Ty)
    (rows : List (List Pat)) (q : List Pat) : UsefulnessResult :=
  usefulReportWithView P ctors closedView tys rows q

/-- `some` が有用、`none` が有用でないことを表す。 -/
def usefulWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (tys : List Ty) (rows : List (List Pat)) (q : List Pat) : Option (List CoverageWitness) :=
  (usefulReportWithView P ctors view tys rows q).witness

/-- 閉じた型についての有用性。 -/
def useful (P : Program) (ctors : DataName → List ConName) (tys : List Ty)
    (rows : List (List Pat)) (q : List Pat) : Option (List CoverageWitness) :=
  usefulWithView P ctors closedView tys rows q

namespace Coverage

/-- 長さが閉じた整数 n に等しいという篩。 -/
def lengthType (a : Ty) (n : Int) : Ty :=
  .refined (.list a) (.eq (.measure .listLength (.var 0)) (.integer n))

/-- 要素を制約しない、ちょうど n 個の List のパターン。 -/
def exactLengthPattern (n : Nat) : Pat := .list (List.replicate n .wild) none []

private theorem length_eq_eval (xs : List Val) (n : Int) :
    (Pred.eq (.measure .listLength (.var 0)) (.integer n)).evalWith
      (selfModel (fun _ => none) (.list xs)) = some (decide ((xs.length : Int) = n)) := by
  simp [Pred.evalWith, Pred.atomReady, Pred.atomValue, termReady, integerAs, observeAs,
    selfModel, selfObservation, Val.toTerm?, Term.observe, Term.interpret, Observation.sort,
    Observation.measure, MatchFacts.observeSlots_length, Val.toTermSlots_eq_map]

/-- 閉じた長さは任意であり、要素の観測可能性を要求しない。負の長さの型は空である。 -/
theorem length_exhaustive (P : Program) (a : Ty) (n : Int) :
    Exhaustive P (lengthType a n) [exactLengthPattern n.toNat] := by
  intro v hv
  obtain ⟨hc, hp⟩ := hv.refined_inv _ _ rfl
  obtain ⟨xs, rfl, _⟩ := hc.list_inv _ rfl
  have hn : (xs.length : Int) = n := by
    change (Pred.eq (.measure .listLength (.var 0)) (.integer n)).evalWith _ ≠ some false at hp
    rw [length_eq_eval] at hp
    simpa using hp
  have hlen : xs.length = n.toNat := by omega
  refine ⟨exactLengthPattern n.toNat, by simp, ?_⟩
  have hm : (matchList (List.replicate n.toNat .wild) xs).isSome = true :=
    matchList_wild (by simp [isWild]) (by simpa using hlen.symm)
  simp [exactLengthPattern, matchVal, ← hlen, matchList]

/-- 型の篩で制限された初期領域。plain は篩を芯へ忘れた通常の行列判定へ渡す。 -/
inductive InitialDomain : Ty → Type where
  | plain (a : Ty) : InitialDomain a
  | empty (a : Ty) : InitialDomain (.refined a .falsity)
  | month : InitialDomain monthType
  | nonempty (a : Ty) : InitialDomain (nonemptyType a)
  | length (a : Ty) (n : Int) : InitialDomain (lengthType a n)

/-- 初期領域を型の形と有限な述語の構文から選ぶ。 -/
def initialDomain : (a : Ty) → InitialDomain a
  | .refined a .falsity => .empty a
  | .refined (.base .integer) p =>
      if hp : predEq p monthPredicate = true then ((predEq_spec _ _).mp hp).symm ▸ InitialDomain.month else .plain _
  | .refined (.list a) p =>
      if hp : predEq p nonemptyPredicate = true then ((predEq_spec _ _).mp hp).symm ▸ InitialDomain.nonempty a
      else match p with
      | .eq (.measure .listLength (.var 0)) (.integer n) => .length a n
      | _ => .plain _
  | a => .plain a

def InitialDomain.baseType {a : Ty} : InitialDomain a → Ty
  | .plain a | .empty a => a
  | .month => .base .integer
  | .nonempty a | .length a _ => .list a

def InitialDomain.query {a : Ty} : InitialDomain a → Pat
  | .plain _ | .empty _ => .wild
  | .month => monthPattern
  | .nonempty _ => headRestPattern
  | .length _ n => exactLengthPattern n.toNat

theorem InitialDomain.member {P : Program} {a : Ty} (d : InitialDomain a) {v : Val}
    (hv : Inhabits P a.norm v) :
    Inhabits P d.baseType v ∧ (matchVal d.query v).isSome = true := by
  cases d with
  | plain a => exact ⟨(Inhabits.norm_all_iff _ _).mp hv, rfl⟩
  | empty a =>
      obtain ⟨p, hp, _⟩ := empty_refinement_exhaustive P a v hv
      cases hp
  | month =>
      obtain ⟨p, hp, hm⟩ := month_exhaustive P v hv
      cases List.mem_singleton.mp hp
      exact ⟨(((Inhabits.norm_all_iff _ _).mp hv).refined_inv _ _ rfl).1, hm⟩
  | nonempty a =>
      obtain ⟨p, hp, hm⟩ := nonempty_exhaustive P a v hv
      cases List.mem_singleton.mp hp
      exact ⟨(((Inhabits.norm_all_iff _ _).mp hv).refined_inv _ _ rfl).1, hm⟩
  | length a n =>
      obtain ⟨p, hp, hm⟩ := length_exhaustive P a n v hv
      cases List.mem_singleton.mp hp
      exact ⟨(((Inhabits.norm_all_iff _ _).mp hv).refined_inv _ _ rfl).1, hm⟩

/-- 初期領域の問いを行列へ渡す。空型は値を持たないので、空の腕も網羅的である。 -/
def domainReport (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} (d : InitialDomain a) (ps : List Pat) : UsefulnessResult :=
  match d with
  | .empty _ => ⟨none, false⟩
  | _ => usefulReportWithView P ctors view [d.baseType] (ps.map (fun p => [p])) [d.query]


/-- 閉区間の端をMonthの初期領域へ切り詰める。 -/
def monthTarget (p : Pat) : Option Pat :=
  if isWild p then some monthPattern else
  match p with
  | .const (.integer n) => if 1 ≤ n.toInt ∧ n.toInt ≤ 12 then some p else none
  | .range (.integer lo) (.integer hi) =>
      let lo := if lo.toInt < 1 then (⟨1, by decide⟩ : Integer64Value) else lo
      let hi := if 12 < hi.toInt then (⟨12, by decide⟩ : Integer64Value) else hi
      if Integer64Value.toInt lo ≤ Integer64Value.toInt hi then some (.range (.integer lo) (.integer hi)) else none
  | _ => some p

/-- 初期領域内での元の候補の照合を保つ候補。扱う形では領域で制限し、他の形は保守的に残す。 -/
def InitialDomain.target {a : Ty} (d : InitialDomain a) (p : Pat) : Option Pat :=
  match d with
  | .plain _ => some p
  | .empty _ => none
  | .month => monthTarget p
  | .nonempty _ =>
      if isWild p then some headRestPattern else
      match p with
      | .list before none after => if before.length + after.length = 0 then none else some p
      | .list [] (some _) [] => some headRestPattern
      | _ => some p
  | .length _ n =>
      if n < 0 then none else
      if isWild p then some (exactLengthPattern n.toNat) else
      match p with
      | .list before rest after =>
          let count := before.length + after.length
          if (if rest.isSome then count ≤ n.toNat else count = n.toNat) then
            some (.list (before ++ List.replicate (n.toNat - count) .wild ++ after) none [])
          else none
      | _ => some p

/-- 候補が初期領域に値を持たない場合は、先行腕がなくても有用でない。 -/
def domainAlternativeReport (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} (d : InitialDomain a) (ps : List Pat) (p : Pat) : UsefulnessResult :=
  match d.target p with
  | none => ⟨none, false⟩
  | some target => usefulReportWithView P ctors view [d.baseType]
      (ps.map (fun p => [p])) [target]


end Coverage

/-- 設計書 02-05「本体の後の検査」の行列を位置付きで集める。前の分岐はガードなし、同じ分岐はガードを問わない。 -/
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
def overlapsWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (ty : Ty) (a b : Pat) : Bool :=
  Coverage.overlapsFuelWithView P ctors view (Coverage.nodes a + Coverage.nodes b + 1) ty a b

/-- 閉じた型についての重なり。 -/
def overlaps (P : Program) (ctors : DataName → List ConName) (ty : Ty) (a b : Pat) : Bool :=
  overlapsWithView P ctors closedView ty a b

/-- 単独で覆う最初の選択肢を優先する。なければ覆う最小の接頭辞の中で重なるものを選ぶ。
位置と順は処理系の covering_alternatives と同じ。前の行はガードなしの分岐と同じ分岐の前の選択肢から集める。 -/
def coveringAlternativesWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (ty : Ty) (arms : List Arm) (i j : Nat) : List (Nat × Nat) :=
  match (arms[i]?).bind (fun arm => (arm.alts[j]?).map Alt.pat) with
  | none => []
  | some target =>
      if ((Coverage.initialDomain ty).target target).isNone then [] else
      let previous := precedingAlternatives arms i j
      match previous.find? (fun (_, p) => (Coverage.domainAlternativeReport P ctors view (Coverage.initialDomain ty) [p] target).witness.isNone) with
      | some (pos, _) => [pos]
      | none =>
          match previous.zipIdx.find? (fun (_, k) =>
            (Coverage.domainAlternativeReport P ctors view (Coverage.initialDomain ty)
              ((previous.take (k + 1)).map Prod.snd) target).witness.isNone) with
          | none => []
          | some (_, k) =>
              ((previous.take (k + 1)).filter (fun (_, p) => overlapsWithView P ctors view ty p
                (((Coverage.initialDomain ty).target target).getD target))).map Prod.fst

/-- 覆っている選択肢の説明に閉じた view を使う。 -/
def coveringAlternatives (P : Program) (ctors : DataName → List ConName) (ty : Ty)
    (arms : List Arm) (i j : Nat) : List (Nat × Nat) :=
  coveringAlternativesWithView P ctors closedView ty arms i j

structure MatchCoverage where
  uncovered : Option CoverageWitness
  unreachable : List (Nat × Nat)
  /-- 選ばれない位置ごとの覆っている分岐。同じ分岐は除き、昇順で重複なし。 -/
  coveredBy : List ((Nat × Nat) × List Nat)
  fuelExhausted : Bool
  deriving Repr

def MatchCoverage.exhaustive (r : MatchCoverage) : Bool := r.uncovered.isNone

/-- 選ばれない位置は分岐・選択肢の順。網羅性の行列は unguardedPats の順。 -/
def checkMatchWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (a : Ty) (arms : List Arm) : MatchCoverage :=
  let checked := arms.zipIdx.flatMap fun (arm, i) =>
    arm.alts.zipIdx.map fun (alt, j) =>
      ((i, j), Coverage.domainAlternativeReport P ctors view (Coverage.initialDomain a) (precedingPats arms i j) alt.pat)
  let all := Coverage.domainReport P ctors view (Coverage.initialDomain a) (unguardedPats arms)
  let unreachable := checked.filterMap (fun (pos, r) => if r.witness.isNone then some pos else none)
  { uncovered := all.witness.map (fun ws => ws.headD .wild)
    unreachable := unreachable
    coveredBy := unreachable.map (fun (i, j) =>
      -- 選択肢の位置は昇順で得られるため、分岐番号の除外と重複除去だけで昇順を保つ。
      ((i, j), (((coveringAlternativesWithView P ctors view a arms i j).map Prod.fst).filter (· != i)).eraseDups))
    fuelExhausted := all.fuelExhausted || checked.any (fun (_, r) => r.fuelExhausted) }

/-- 将来の形を考慮しない match の判定。 -/
def checkMatch (P : Program) (ctors : DataName → List ConName) (a : Ty)
    (arms : List Arm) : MatchCoverage :=
  checkMatchWithView P ctors closedView a arms

/-- 束縛の左辺の網羅性にも、ソースの照合と同じ view を使う。 -/
def irrefutableWithView (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    (a : Ty) (p : Pat) : Bool :=
  (Coverage.domainReport P ctors view (Coverage.initialDomain a) [p]).witness.isNone

/-- 閉じた型の束縛の左辺の判定。 -/
def irrefutable (P : Program) (ctors : DataName → List ConName) (a : Ty) (p : Pat) : Bool :=
  irrefutableWithView P ctors closedView a p

/-- slots の整合を仮定しない、パターンの照合だけによる選択。
前のガード付き分岐は、ガードが偽になる可能性があるので条件から外す。
firstAlt と実行の規則への接続には、slots が整うという前提が必要である。 -/
def AlternativeSelected (arms : List Arm) (i j : Nat) (v : Val) : Prop :=
  ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
    (∀ p ∈ unguardedPats (arms.take i), ¬ (matchVal p v).isSome) ∧
    (∀ prior ∈ arm.alts.take j, ¬ (matchVal prior.pat v).isSome) ∧
    (matchVal alt.pat v).isSome

/-- 補題 U。パターンの型付け・行の長さの整合を前提にしない。 -/
theorem usefulWithView_none_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView)
    (tys : List Ty) (rows : List (List Pat)) (q : List Pat)
    (hc : CtorsComplete P ctors) (h : usefulWithView P ctors view tys rows q = none) :
    ∀ vs, InhabitsAll P tys vs → (matchList q vs).isSome →
      ∃ row ∈ rows, (matchList row vs).isSome := by
  intro vs hv hm
  exact Coverage.usefulFuelWithView_none_sound P ctors view hc _ tys rows q vs h hv hm

/-- 閉じた view の入口の健全性。 -/
theorem useful_none_sound (P : Program) (ctors : DataName → List ConName)
    (tys : List Ty) (rows : List (List Pat)) (q : List Pat)
    (hc : CtorsComplete P ctors) (h : useful P ctors tys rows q = none) :
    ∀ vs, InhabitsAll P tys vs → (matchList q vs).isSome →
      ∃ row ∈ rows, (matchList row vs).isSome :=
  usefulWithView_none_sound P ctors closedView tys rows q hc h

/-- 一列の行列から、元のパターンの照合を取り出す。 -/
theorem usefulWithView_singleton_none_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView)
    (a : Ty) (ps : List Pat) (q : Pat) (hc : CtorsComplete P ctors)
    (h : usefulWithView P ctors view [a] (ps.map (fun p => [p])) [q] = none)
    (v : Val) (hv : Inhabits P a v) (hq : (matchVal q v).isSome = true) :
    ∃ p ∈ ps, (matchVal p v).isSome = true := by
  have hm : (matchList [q] [v]).isSome = true := by simp [matchList, hq]
  obtain ⟨row, hr, hm⟩ := usefulWithView_none_sound P ctors view [a] (ps.map (fun p => [p])) [q] hc h
    [v] (.cons hv .nil) hm
  obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hr
  exact ⟨p, hp, by simpa [Coverage.matchList_cons, matchList] using hm⟩

/-- 閉じた view の入口の健全性。 -/
theorem useful_singleton_none_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (ps : List Pat) (q : Pat) (hc : CtorsComplete P ctors)
    (h : useful P ctors [a] (ps.map (fun p => [p])) [q] = none)
    (v : Val) (hv : Inhabits P a v) (hq : (matchVal q v).isSome = true) :
    ∃ p ∈ ps, (matchVal p v).isSome = true :=
  usefulWithView_singleton_none_sound P ctors closedView a ps q hc h v hv hq


namespace Coverage

private theorem regionReport_sound (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} (d : InitialDomain a) (ps : List Pat) (hc : CtorsComplete P ctors)
    (h : usefulWithView P ctors view [d.baseType] (ps.map (fun p => [p])) [d.query] = none) :
    Exhaustive P a ps := by
  intro v hv
  obtain ⟨hb, hq⟩ := InitialDomain.member d hv
  exact usefulWithView_singleton_none_sound P ctors view _ ps _ hc h v hb hq

/-- 初期領域の選択と行列の成功から、元の篩付きの型の網羅性を得る。 -/
theorem domainReport_sound (P : Program) (ctors : DataName → List ConName) (view : CoverageView)
    {a : Ty} (d : InitialDomain a) (ps : List Pat) (hc : CtorsComplete P ctors)
    (h : (domainReport P ctors view d ps).witness = none) : Exhaustive P a ps := by
  cases d with
  | empty a =>
      intro v hv
      obtain ⟨p, hp, _⟩ := empty_refinement_exhaustive P a v hv
      cases hp
  | plain a => exact regionReport_sound P ctors view (.plain a) ps hc h
  | month => exact regionReport_sound P ctors view .month ps hc h
  | nonempty a => exact regionReport_sound P ctors view (.nonempty a) ps hc h
  | length a n => exact regionReport_sound P ctors view (.length a n) ps hc h


private theorem monthTarget_member {p : Pat} {v : Val}
    (hd : (matchVal monthPattern v).isSome = true)
    (hm : (matchVal p v).isSome = true) :
    ∃ target, monthTarget p = some target ∧ (matchVal target v).isSome = true := by
  by_cases hw : isWild p = true
  · exact ⟨monthPattern, by simp [monthTarget, hw], hd⟩
  have hw' : isWild p = false := by cases h : isWild p <;> simp_all
  cases v <;> simp [monthPattern, matchVal, patternRange] at hd
  rename_i c
  cases c <;> simp at hd
  rename_i n
  cases p with
  | const c =>
      cases c <;> simp_all [monthTarget, isWild, matchVal, patternMatches]
      exact ⟨_, ⟨by simpa [Integer64Value.toInt] using hd, rfl⟩, by simpa [matchVal, patternMatches] using hm⟩
  | range lo hi =>
      cases lo <;> cases hi <;> simp_all [monthTarget, isWild, matchVal, patternRange]
      rename_i lo hi
      simp only [Integer64Value.toInt] at *
      by_cases hl : lo.val < 1 <;> by_cases hh : 12 < hi.val <;>
        refine ⟨_, ⟨?_, rfl⟩, ?_⟩ <;>
        simp [hl, hh, Integer64Value.toInt, matchVal, patternRange] <;> omega
  | _ => exact ⟨_, by simp [monthTarget, hw'], hm⟩

/-- 領域内で候補に照合する値は、共通部分のパターンにも照合する。 -/
theorem InitialDomain.target_member {P : Program} {a : Ty} (d : InitialDomain a)
    {p : Pat} {v : Val} (hv : Inhabits P a.norm v)
    (hm : (matchVal p v).isSome = true) :
    ∃ target, d.target p = some target ∧ (matchVal target v).isSome = true := by
  obtain ⟨hb, hd⟩ := d.member hv
  cases d with
  | plain a => exact ⟨p, rfl, hm⟩
  | empty a =>
      obtain ⟨p, hp, _⟩ := empty_refinement_exhaustive P a v hv
      cases hp
  | month => exact monthTarget_member hd hm
  | nonempty a =>
      obtain ⟨xs, rfl, _⟩ := hb.list_inv _ rfl
      by_cases hw : isWild p = true
      · exact ⟨headRestPattern, by simp [InitialDomain.target, hw], hd⟩
      have hw' : isWild p = false := by cases h : isWild p <;> simp_all
      change (matchVal headRestPattern (.list xs)).isSome = true at hd
      have hn : 1 ≤ xs.length := by
        simp only [headRestPattern, matchVal_list, Option.isSome_some, ↓reduceIte,
          List.length_cons, List.length_nil, Nat.add_zero, Bool.and_eq_true,
          decide_eq_true_eq] at hd
        exact hd.1.1
      cases p with
      | list before rest after =>
          cases rest with
          | none =>
              have hc : before.length + after.length = xs.length := by
                simp only [matchVal_list, Option.isSome_none, Bool.false_eq_true, ↓reduceIte,
                  Bool.and_eq_true, decide_eq_true_eq] at hm
                exact hm.1.1
              refine ⟨_, ?_, hm⟩
              simp only [InitialDomain.target, hw', Bool.false_eq_true, ↓reduceIte]
              simp only [ite_eq_right_iff]; intro h; omega
          | some rest =>
              cases before <;> cases after <;>
                first | exact ⟨headRestPattern, rfl, hd⟩ | exact ⟨_, rfl, hm⟩
      | _ => exact ⟨_, by simp [InitialDomain.target, hw'], hm⟩
  | length a n =>
      obtain ⟨xs, rfl, _⟩ := hb.list_inv _ rfl
      have he : (xs.length : Int) = n := by
        obtain ⟨_, hp⟩ := ((Inhabits.norm_all_iff _ _).mp hv).refined_inv _ _ rfl
        change (Pred.eq (.measure .listLength (.var 0)) (.integer n)).evalWith _ ≠ some false at hp
        rw [length_eq_eval] at hp
        simpa using hp
      have hnon : ¬n < 0 := by omega
      have hlen : xs.length = n.toNat := by omega
      by_cases hw : isWild p = true
      · exact ⟨exactLengthPattern n.toNat, by simp [InitialDomain.target, hnon, hw], hd⟩
      have hw' : isWild p = false := by cases h : isWild p <;> simp_all
      cases p with
      | list before rest after =>
          have hc : (if rest.isSome then before.length + after.length ≤ xs.length
              else before.length + after.length = xs.length) := by
            simp only [matchVal_list, Bool.and_eq_true, decide_eq_true_eq] at hm
            exact hm.1.1
          have hle : before.length + after.length ≤ xs.length := by
            cases rest <;> simp_all
          refine ⟨.list (before ++ List.replicate (n.toNat - (before.length + after.length)) .wild ++ after) none [], ?_, ?_⟩
          · simp [InitialDomain.target, hnon, hw', ← hlen, hc]
          · have hp := padded_match before after xs hle
            simp only [matchVal_list, Bool.and_eq_true, decide_eq_true_eq] at hm
            have hp' : (matchList (before ++ List.replicate (n.toNat - (before.length + after.length)) .wild ++ after) xs).isSome = true := by
              rw [← hlen, hp]
              simp only [Bool.and_eq_true]; exact ⟨hm.1.2, hm.2⟩
            have hl : (before ++ List.replicate (n.toNat - (before.length + after.length)) Pat.wild ++ after).length = xs.length := by
              simp only [List.length_append, List.length_replicate]
              omega
            simp only [matchVal_list, Option.isSome_none, Bool.false_eq_true, ↓reduceIte,
              hl, List.length_nil, Nat.add_zero, decide_true, Bool.true_and,
              List.take_length, hp', Nat.sub_zero, List.drop_length, matchList, Option.isSome_some]

      | _ => exact ⟨_, by simp [InitialDomain.target, hnon, hw'], hm⟩

/-- 初期領域内で候補を選べる値は、有用でないという報告の先行行に照合する。 -/
theorem domainAlternativeReport_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView) {a : Ty} (d : InitialDomain a) (ps : List Pat) (p : Pat)
    (hc : CtorsComplete P ctors)
    (h : (domainAlternativeReport P ctors view d ps p).witness = none)
    (v : Val) (hv : Inhabits P a.norm v) (hm : (matchVal p v).isSome = true) :
    ∃ prior ∈ ps, (matchVal prior v).isSome = true := by
  obtain ⟨target, ht, hm⟩ := d.target_member hv hm
  obtain ⟨hb, _⟩ := d.member hv
  simp only [domainAlternativeReport, ht] at h
  exact usefulWithView_singleton_none_sound P ctors view d.baseType ps target hc h v hb hm


end Coverage

/-- 系 1: ガードのない選択肢による網羅性。 -/
theorem checkMatchWithView_exhaustive_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView)
    (a : Ty) (arms : List Arm) (hc : CtorsComplete P ctors)
    (h : (checkMatchWithView P ctors view a arms).exhaustive = true) :
    Exhaustive P a (unguardedPats arms) := by
  apply Coverage.domainReport_sound P ctors view (Coverage.initialDomain a) (unguardedPats arms) hc
  change ((Coverage.domainReport P ctors view (Coverage.initialDomain a) (unguardedPats arms)).witness.map
    (fun ws => ws.headD .wild)).isNone = true at h
  simpa using h

/-- 閉じた view の入口の健全性。 -/
theorem checkMatch_exhaustive_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (hc : CtorsComplete P ctors)
    (h : (checkMatch P ctors a arms).exhaustive = true) :
    Exhaustive P a (unguardedPats arms) :=
  checkMatchWithView_exhaustive_sound P ctors closedView a arms hc h


/-- 系 1: 束縛の左辺の網羅性。 -/
theorem irrefutableWithView_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView)
    (a : Ty) (p : Pat) (hc : CtorsComplete P ctors)
    (h : irrefutableWithView P ctors view a p = true) : Exhaustive P a [p] := by
  apply Coverage.domainReport_sound P ctors view (Coverage.initialDomain a) [p] hc
  simpa [irrefutableWithView] using h

/-- 閉じた view の入口の健全性。 -/
theorem irrefutable_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (p : Pat) (hc : CtorsComplete P ctors)
    (h : irrefutable P ctors a p = true) : Exhaustive P a [p] :=
  irrefutableWithView_sound P ctors closedView a p hc h


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
theorem checkMatchWithView_unreachable_lookup {P : Program} {ctors : DataName → List ConName}
    {view : CoverageView} {a : Ty} {arms : List Arm} {i j : Nat}
    (h : (i, j) ∈ (checkMatchWithView P ctors view a arms).unreachable) :
    ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
      (Coverage.domainAlternativeReport P ctors view (Coverage.initialDomain a) (precedingPats arms i j) alt.pat).witness = none := by
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
      List.mem_zipIdx_iff_getElem?.mp halt, by simpa [usefulWithView] using hn⟩
  · simp at he

/-- 閉じた view の入口の健全性。 -/
theorem checkMatch_unreachable_lookup {P : Program} {ctors : DataName → List ConName}
    {a : Ty} {arms : List Arm} {i j : Nat}
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
      (Coverage.domainAlternativeReport P ctors closedView (Coverage.initialDomain a) (precedingPats arms i j) alt.pat).witness = none :=
  checkMatchWithView_unreachable_lookup (view := closedView) h

/-- 系 2: パターンの照合の上で選ばれないこと。この言明はパターン照合に関するものである。 -/
theorem checkMatchWithView_unreachable_sound (P : Program) (ctors : DataName → List ConName)
    (view : CoverageView)
    (a : Ty) (arms : List Arm) (i j : Nat) (hc : CtorsComplete P ctors)
    (h : (i, j) ∈ (checkMatchWithView P ctors view a arms).unreachable) :
    ∀ v, Inhabits P a v → ¬ AlternativeSelected arms i j v := by
  obtain ⟨arm, alt, ha, hal, hu⟩ := checkMatchWithView_unreachable_lookup h
  intro v hv hsel
  obtain ⟨arm', alt', ha', hal', hprev, hprior, hm⟩ := hsel
  have hearm : arm' = arm := Option.some.inj (ha'.symm.trans ha)
  subst arm'
  have healt : alt' = alt := Option.some.inj (hal'.symm.trans hal)
  subst alt'
  obtain ⟨p, hp, hpm⟩ := Coverage.domainAlternativeReport_sound P ctors view (Coverage.initialDomain a) (precedingPats arms i j) alt.pat hc hu v ((Inhabits.norm_all_iff a v).mpr hv) hm
  rcases precedingPats_mem ha hp with hprevp | ⟨prior, hpri, hpat⟩
  · exact hprev p hprevp hpm
  · apply hprior prior hpri
    simpa only [hpat] using hpm

/-- 閉じた view の入口の健全性。 -/
theorem checkMatch_unreachable_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (i j : Nat) (hc : CtorsComplete P ctors)
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ v, Inhabits P a v → ¬ AlternativeSelected arms i j v :=
  checkMatchWithView_unreachable_sound P ctors closedView a arms i j hc h


end Benitoite.Release.Refinement
