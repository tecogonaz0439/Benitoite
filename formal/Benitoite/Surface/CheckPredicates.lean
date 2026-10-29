import Benitoite.Surface.CheckTools
import Benitoite.Surface.FinitePredicates

/-! 表層の規則の、型付けの判断以外の前提の判定。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。
-/
namespace Benitoite.Surface.CheckTools
open Benitoite.Release

/-- 解析済み書式の空指定・範囲・併用を、型の推論より前に検査する。 -/
def formatSyntaxValid (s : FormatSpec) : Bool := decide s.SyntaxValid

theorem formatSyntaxValid_spec (s : FormatSpec) :
    formatSyntaxValid s = true ↔ s.SyntaxValid := by simp [formatSyntaxValid]

/-- 書式の型集合は閉じており、型変数や利用者定義のShowを受理しない。 -/
def formatCompatible (t : Ty) (s : FormatSpec) : Bool := decide (s.Compatible t)

theorem formatCompatible_spec (t : Ty) (s : FormatSpec) :
    formatCompatible t s = true ↔ s.Compatible t := by simp [formatCompatible]

/-- 構文の妥当性と型の適合の両方を要求する。 -/
def formatValid (t : Ty) (s : FormatSpec) : Bool :=
  formatSyntaxValid s && formatCompatible t s

theorem formatValid_spec (t : Ty) (s : FormatSpec) :
    formatValid t s = true ↔ s.Valid t := by
  simp [formatValid, FormatSpec.Valid, formatSyntaxValid_spec, formatCompatible_spec]

/-- 型付けの名前の整形式と同じ条件を有限の一覧で検査する。 -/
def namesWF (names : List String) (params : List Ty) : Bool :=
  decide (names.length = params.length) && decide names.Nodup

theorem namesWF_spec (names : List String) (params : List Ty) :
    namesWF names params = true ↔ NamesWF names params := by simp [namesWF, NamesWF]

/-- Rust の位置情報を、契約名とソース順のラベルから独立に検査する。 -/
def callOk (names : List String) (params : List Ty) (inserted : Bool)
    (labels : List (Option String)) (positions : List Nat) : Bool :=
  namesWF names params && decide (labels.length = positions.length) &&
    decide (((if inserted then [0] else []) ++ positions).Perm (List.range params.length)) &&
    ((decide (labels = []) && decide (positions = [])) ||
      (decide (inserted = false) && decide (params.length = 1) &&
        decide (labels = [none]) && decide (positions = [0])) ||
      (decide (labels = positions.map (fun i => names[i]?)) && labels.all Option.isSome))

theorem callOk_spec (names : List String) (params : List Ty) (inserted : Bool)
    (labels : List (Option String)) (positions : List Nat) :
    callOk names params inserted labels positions = true ↔ CallOk names params inserted labels positions := by
  simp [callOk, CallOk, namesWF_spec, List.all_eq_true, and_assoc, or_assoc]

/-- 直接の構成子の穴はラベルなしの宣言順に限る。 -/
def constructorHolesOk (args : HoleArgs) (n : Nat) : Bool :=
  decide (args.labels = List.replicate n none) && decide (args.positions = List.range n)

theorem constructorHolesOk_spec (args : HoleArgs) (n : Nat) :
    constructorHolesOk args n = true ↔ args.ConstructorOk n := by
  simp [constructorHolesOk, HoleArgs.ConstructorOk]

/-- 入力の正規化を行わず、有限支持上の判定へ接続する。 -/
def canonicalEff := Finite.canonicalEff
def wfTy := Finite.wfTy
def wfTys := Finite.wfTys
def wfEff := Finite.wfEff
def cleanTy := Finite.cleanTy
def cleanTys := Finite.cleanTys
def cleanEff := Finite.cleanEff
def cleanTopEff := Finite.cleanTopEff

theorem canonicalEff_spec {atoms e} (he : Eff.AtomsIn atoms e) :
    canonicalEff atoms e = true ↔ Eff.Canonical e := Finite.canonicalEff_spec he

theorem wfTy_spec {atoms} (n : Nat) (t : Ty) (ha : t.AtomsIn atoms) :
    wfTy atoms n t = true ↔ Ty.WF 0 n t := Finite.wfTy_spec n t ha

theorem wfTys_spec {atoms} (n : Nat) (ts : List Ty) (ha : Tys.AtomsIn atoms ts) :
    wfTys atoms n ts = true ↔ Ty.WFList 0 n ts := Finite.wfTys_spec n ts ha

theorem wfEff_spec {atoms} (n : Nat) (e : Eff) (ha : e.AtomsIn atoms) :
    wfEff atoms n e = true ↔ Eff.WF 0 n e ∧ Eff.Canonical e := Finite.wfEff_spec n e ha

theorem cleanTy_spec {atoms} (n : Nat) (t : Ty) (ha : t.AtomsIn atoms) :
    cleanTy atoms n t = true ↔ Ty.VarsIn 0 n (fun _ => True) t := Finite.cleanTy_spec n t ha

theorem cleanTys_spec {atoms} (n : Nat) (ts : List Ty) (ha : Tys.AtomsIn atoms ts) :
    cleanTys atoms n ts = true ↔ Ty.VarsInList 0 n (fun _ => True) ts := Finite.cleanTys_spec n ts ha

theorem cleanEff_spec {atoms} (n : Nat) (e : Eff) (ha : e.AtomsIn atoms) :
    cleanEff atoms n e = true ↔ Eff.VarsIn 0 n (fun _ => True) e ∧ Eff.Canonical e :=
  Finite.cleanEff_spec n e ha

mutual
  def exprExits : Expr → Bool
    | .returnE _ _ => true
    | .ite _ y n => blockExits y && blockExits n
    | .elseIf _ y n => blockExits y && exprExits n
    | .paren e => exprExits e
    | .block body => blockExits body
    | .matchE _ _ arms => armsExits arms
    | .withE _ _ b => blockExits b
    | _ => false
  def blockExits : Block → Bool
    | .builderBind _ rest => blockExits rest
    | .last e => exprExits e
    | .seq e rest => exprExits e || blockExits rest
    | .bind _ _ _ rest | .discard _ rest | .bindPat _ _ _ _ rest => blockExits rest
    | _ => false
  def armsExits : Arms → Bool
    | .nil => true
    | .cons _ _ body rest => blockExits body && armsExits rest
end

mutual
  theorem exprExits_spec : (e : Expr) → (exprExits e = true ↔ e.Exits)
    | .returnE _ _ => by simp [exprExits, Expr.Exits]
    | .ite _ y n => by simp [exprExits, Expr.Exits, blockExits_spec y, blockExits_spec n]
    | .elseIf _ y n => by simp [exprExits, Expr.Exits, blockExits_spec y, exprExits_spec n]
    | .paren e => by simp [exprExits, Expr.Exits, exprExits_spec e]
    | .block body => by simp [exprExits, Expr.Exits, blockExits_spec body]
    | .matchE _ _ a => by simp [exprExits, Expr.Exits, armsExits_spec a]
    | .withE _ _ b => by simp [exprExits, Expr.Exits, blockExits_spec b]
    | .builderOp _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .local _ => by simp [exprExits, Expr.Exits]
    | .constE _ _ => by simp [exprExits, Expr.Exits]
    | .funName _ _ _ => by simp [exprExits, Expr.Exits]
    | .funDicts _ _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .opDicts _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .methName _ _ _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .primName _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .opName _ _ => by simp [exprExits, Expr.Exits]
    | .raise _ _ => by simp [exprExits, Expr.Exits]
    | .handleFail _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .nullCon _ _ => by simp [exprExits, Expr.Exits]
    | .conValue _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .literal _ => by simp [exprExits, Expr.Exits]
    | .negInt _ => by simp [exprExits, Expr.Exits]
    | .negFloat _ => by simp [exprExits, Expr.Exits]
    | .negDecimal _ _ => by simp [exprExits, Expr.Exits]
    | .negInteger8 _ => by simp [exprExits, Expr.Exits]
    | .negInteger16 _ => by simp [exprExits, Expr.Exits]
    | .negInteger32 _ => by simp [exprExits, Expr.Exits]
    | .negFloat32 _ => by simp [exprExits, Expr.Exits]
    | .unit => by simp [exprExits, Expr.Exits]
    | .conCall _ _ _ => by simp [exprExits, Expr.Exits]
    | .record _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .recordUpdate _ _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .call _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .pipe _ _ => by simp [exprExits, Expr.Exits]
    | .partialCall _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .partialCon _ _ _ => by simp [exprExits, Expr.Exits]
    | .binary _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .neg _ _ => by simp [exprExits, Expr.Exits]
    | .not _ => by simp [exprExits, Expr.Exits]
    | .and _ _ => by simp [exprExits, Expr.Exits]
    | .or _ _ => by simp [exprExits, Expr.Exits]
    | .list _ _ => by simp [exprExits, Expr.Exits]
    | .listSpread _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .interpolation _ _ _ => by simp [exprExits, Expr.Exits]
    | .lam _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .ifOnly _ _ => by simp [exprExits, Expr.Exits]
    | .tryResult _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .tryOption _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .tryResultDie _ _ _ _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .tryOptionDie _ _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .lazyE _ => by simp [exprExits, Expr.Exits]
    | .handleE _ _ => by simp [exprExits, Expr.Exits]
    | .resume _ _ => by simp [exprExits, Expr.Exits]
  theorem blockExits_spec : (b : Block) → (blockExits b = true ↔ b.Exits)
    | .last e => by simp [blockExits, Block.Exits, exprExits_spec e]
    | .seq e b => by simp [blockExits, Block.Exits, exprExits_spec e, blockExits_spec b]
    | .builderBind _ b => by simp [blockExits, Block.Exits, blockExits_spec b]
    | .bind _ _ _ b => by simp [blockExits, Block.Exits, blockExits_spec b]
    | .discard _ b => by simp [blockExits, Block.Exits, blockExits_spec b]
    | .bindPat _ _ _ _ b => by simp [blockExits, Block.Exits, blockExits_spec b]
    | .empty => by simp [blockExits, Block.Exits]
    | .lastBind _ _ _ => by simp [blockExits, Block.Exits]
    | .lastDiscard _ => by simp [blockExits, Block.Exits]
    | .lastPat _ _ _ _ => by simp [blockExits, Block.Exits]
  theorem armsExits_spec : (a : Arms) → (armsExits a = true ↔ a.Exits)
    | .nil => by simp [armsExits, Arms.Exits]
    | .cons _ _ b a => by simp [armsExits, Arms.Exits, blockExits_spec b, armsExits_spec a]
end

mutual
  def patternValid : Pattern → Bool
    | .range (.integer lo) (.integer hi) => decide (lo.toInt ≤ hi.toInt)
    | .range (.character lo) (.character hi) => decide (lo.toNat ≤ hi.toNat)
    | .con _ _ ps | .record _ _ _ ps => patternsValid ps
    | .list before rest after => patternsValid before && patternsValid after &&
        (rest.isSome || after.isEmpty)
    | _ => true
  def patternsValid : List Pattern → Bool
    | [] => true
    | p :: ps => patternValid p && patternsValid ps
end

mutual
  theorem patternValid_spec : (p : Pattern) → (patternValid p = true ↔ p.Valid)
    | .wild => by simp [patternValid, Pattern.Valid]
    | .var => by simp [patternValid, Pattern.Valid]
    | .integer _ => by simp [patternValid, Pattern.Valid]
    | .negInt _ => by simp [patternValid, Pattern.Valid]
    | .string _ => by simp [patternValid, Pattern.Valid]
    | .character _ => by simp [patternValid, Pattern.Valid]
    | .boolean _ => by simp [patternValid, Pattern.Valid]
    | .unit => by simp [patternValid, Pattern.Valid]
    | .range lo hi => by cases lo <;> cases hi <;> simp [patternValid, Pattern.Valid]
    | .con _ _ ps => by simp [patternValid, Pattern.Valid, patternsValid_spec ps]
    | .record _ _ _ ps => by simp [patternValid, Pattern.Valid, patternsValid_spec ps]
    | .list before rest after => by
        cases rest <;> simp [patternValid, Pattern.Valid, patternsValid_spec before, patternsValid_spec after, and_assoc]
  theorem patternsValid_spec : (ps : List Pattern) → (patternsValid ps = true ↔ Pattern.ValidList ps)
    | [] => by simp [patternsValid, Pattern.ValidList]
    | p :: ps => by simp [patternsValid, Pattern.ValidList, patternValid_spec p, patternsValid_spec ps]
end

def alternativesValid (alts : List Alternative) : Bool := alts.all fun a => patternValid a.pat

theorem alternativesValid_spec (alts : List Alternative) :
    alternativesValid alts = true ↔ Alternative.Valid alts := by
  simp [alternativesValid, Alternative.Valid, List.all_eq_true, patternValid_spec]

def isIf : Expr → Bool
  | .ite _ _ _ | .ifOnly _ _ => true
  | .elseIf _ _ n => isIf n
  | _ => false

theorem isIf_spec : (e : Expr) → (isIf e = true ↔ IsIf e)
  | .ite _ _ _ => by constructor; intro _; exact .ite; intro _; rfl
  | .ifOnly _ _ => by constructor; intro _; exact .ifOnly; intro _; rfl
  | .elseIf c y n => by
      constructor
      · intro h; exact .elseIf ((isIf_spec n).mp h)
      · intro h; cases h with
        | elseIf hn => exact (isIf_spec n).mpr hn
  | .raise _ _ => by constructor <;> intro h <;> cases h
  | .handleFail _ _ _ _ => by constructor <;> intro h <;> cases h
  | .builderOp _ _ _ _ => by constructor <;> intro h <;> cases h
  | .local _ => by constructor <;> intro h <;> cases h
  | .constE _ _ => by constructor <;> intro h <;> cases h
  | .funName _ _ _ => by constructor <;> intro h <;> cases h
  | .funDicts _ _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .opDicts _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .methName _ _ _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .primName _ _ _ _ => by constructor <;> intro h <;> cases h
  | .opName _ _ => by constructor <;> intro h <;> cases h
  | .nullCon _ _ => by constructor <;> intro h <;> cases h
  | .conValue _ _ _ _ => by constructor <;> intro h <;> cases h
  | .literal _ => by constructor <;> intro h <;> cases h
  | .negInt _ => by constructor <;> intro h <;> cases h
  | .negFloat _ => by constructor <;> intro h <;> cases h
  | .negDecimal _ _ => by constructor <;> intro h <;> cases h
  | .negInteger8 _ => by constructor <;> intro h <;> cases h
  | .negInteger16 _ => by constructor <;> intro h <;> cases h
  | .negInteger32 _ => by constructor <;> intro h <;> cases h
  | .negFloat32 _ => by constructor <;> intro h <;> cases h
  | .unit => by constructor <;> intro h <;> cases h
  | .paren _ => by constructor <;> intro h <;> cases h
  | .block _ => by constructor <;> intro h <;> cases h
  | .conCall _ _ _ => by constructor <;> intro h <;> cases h
  | .record _ _ _ _ => by constructor <;> intro h <;> cases h
  | .recordUpdate _ _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .call _ _ _ _ => by constructor <;> intro h <;> cases h
  | .pipe _ _ => by constructor <;> intro h <;> cases h
  | .partialCall _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .partialCon _ _ _ => by constructor <;> intro h <;> cases h
  | .binary _ _ _ _ => by constructor <;> intro h <;> cases h
  | .neg _ _ => by constructor <;> intro h <;> cases h
  | .not _ => by constructor <;> intro h <;> cases h
  | .and _ _ => by constructor <;> intro h <;> cases h
  | .or _ _ => by constructor <;> intro h <;> cases h
  | .list _ _ => by constructor <;> intro h <;> cases h
  | .listSpread _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .interpolation _ _ _ => by constructor <;> intro h <;> cases h
  | .lam _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .matchE _ _ _ => by constructor <;> intro h <;> cases h
  | .returnE _ _ => by constructor <;> intro h <;> cases h
  | .tryResult _ _ _ _ => by constructor <;> intro h <;> cases h
  | .tryOption _ _ _ _ => by constructor <;> intro h <;> cases h
  | .tryResultDie _ _ _ _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .tryOptionDie _ _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .withE _ _ _ => by constructor <;> intro h <;> cases h
  | .lazyE _ => by constructor <;> intro h <;> cases h
  | .handleE _ _ => by constructor <;> intro h <;> cases h
  | .resume _ _ => by constructor <;> intro h <;> cases h

def nontrivial : Pattern → Bool
  | .wild | .var => false
  | _ => true

theorem nontrivial_spec (p : Pattern) : nontrivial p = true ↔ p.Nontrivial := by
  cases p <;> simp [nontrivial, Pattern.Nontrivial]

def pipeValue : Expr → Bool
  | .call _ _ _ _ | .conCall _ _ _ | .conValue _ _ _ _ => false
  | _ => true

theorem pipeValue_spec (e : Expr) : pipeValue e = true ↔ e.PipeValue := by
  cases e <;> simp [pipeValue, Expr.PipeValue]

def isDirect (e : Expr) : Bool := (directCallee e).isSome

theorem isDirect_spec (e : Expr) : isDirect e = true ↔ ∃ h, directCallee e = some h := by
  simp [isDirect, Option.isSome_iff_exists]

def allDirect : Exprs → Bool
  | .nil => true
  | .cons e es => isDirect e && allDirect es

theorem allDirect_spec : (es : Exprs) → (allDirect es = true ↔ es.AllDirect)
  | .nil => by simp [allDirect, Exprs.AllDirect]
  | .cons e es => by simp [allDirect, Exprs.AllDirect, isDirect_spec, allDirect_spec es]

/-- 型の構造だけを見る。関数型のエフェクトを比較する必要はない。 -/
def convertedAllowed : Ty → Bool
  | .base .integer | .base .float | .base .character | .base .boolean
    | .base .byte | .base .decimal | .base .integer8 | .base .integer16
    | .base .integer32 | .base .unsignedInteger16 | .base .unsignedInteger32
    | .base .unsignedInteger64 | .base .float32 => true
  | _ => false

def interpAllowed : List InterpPart → Bool
  | [] => true
  | .converted t :: ps => convertedAllowed t && interpAllowed ps
  | .formatted t s :: ps => formatValid t s && interpAllowed ps
  | _ :: ps => interpAllowed ps

theorem convertedAllowed_spec (t : Ty) : convertedAllowed t = true ↔
    (t = .base .integer ∨ t = .base .float ∨ t = .base .character ∨
     t = .base .boolean ∨ t = .base .byte ∨ t = .base .decimal ∨
     t = .base .integer8 ∨ t = .base .integer16 ∨ t = .base .integer32 ∨
     t = .base .unsignedInteger16 ∨ t = .base .unsignedInteger32 ∨
     t = .base .unsignedInteger64 ∨ t = .base .float32) := by
  cases t <;> simp [convertedAllowed]
  rename_i b; cases b <;> simp

/-- 書式なしの型集合と書式付きの妥当性を、型判断の条件と同じ範囲で判定する。 -/
theorem interpAllowed_spec : (ps : List InterpPart) →
    (interpAllowed ps = true ↔ InterpPart.Allowed ps)
  | [] => by simp [interpAllowed, InterpPart.Allowed]
  | .converted t :: ps => by
      simp [interpAllowed, InterpPart.Allowed, convertedAllowed_spec, interpAllowed_spec ps]
  | .formatted t s :: ps => by
      simp [interpAllowed, InterpPart.Allowed, formatValid_spec, interpAllowed_spec ps]
  | .text _ :: ps => by simp [interpAllowed, InterpPart.Allowed, interpAllowed_spec ps]
  | .stringExpr :: ps => by simp [interpAllowed, InterpPart.Allowed, interpAllowed_spec ps]

def notCont : Ty → Bool
  | .cont _ _ _ => false
  | _ => true

theorem notCont_spec (a : Ty) : notCont a = true ↔ ∀ b t ε, a ≠ .cont b t ε := by
  cases a <;> simp [notCont]

def headNotDict (ps : List Ty) : Bool :=
  match ps with
  | .dict _ _ :: _ => false
  | _ => true

theorem headNotDict_spec (ps : List Ty) :
    headNotDict ps = true ↔ ∀ a ∈ ps.head?, ∀ cl t, a ≠ .dict cl t := by
  cases ps with
  | nil => simp [headNotDict]
  | cons a ps => cases a <;> simp [headNotDict]

def isUnit : Ty → Bool
  | .base .unit => true
  | _ => false

theorem isUnit_spec (t : Ty) : isUnit t = true ↔ t = .base .unit := by
  cases t <;> simp [isUnit]
  rename_i b; cases b <;> simp

def lamBodyOk (body : Block) (r : Ty) : Bool := blockExits body || isUnit r

theorem lamBodyOk_spec (body : Block) (r : Ty) :
    lamBodyOk body r = true ↔ body.Exits ∨ r = .base .unit := by
  simp [lamBodyOk, blockExits_spec, isUnit_spec]

def nonemptyArms : Arms → Bool
  | .nil => false
  | _ => true

theorem nonemptyArms_spec (a : Arms) : nonemptyArms a = true ↔ a ≠ .nil := by
  cases a <;> simp [nonemptyArms]

def nonemptyList {α : Type} (xs : List α) : Bool := !xs.isEmpty

theorem nonemptyList_spec {α : Type} (xs : List α) : nonemptyList xs = true ↔ xs ≠ [] := by
  cases xs <;> simp [nonemptyList]

def natPerm (xs ys : List Nat) : Bool := decide (xs.Perm ys)
def natNodup (xs : List Nat) : Bool := decide xs.Nodup
def positionsInRange (xs : List Nat) (n : Nat) : Bool := xs.all fun i => decide (i < n)

theorem natPerm_spec (xs ys : List Nat) : natPerm xs ys = true ↔ xs.Perm ys := by simp [natPerm]
theorem natNodup_spec (xs : List Nat) : natNodup xs = true ↔ xs.Nodup := by simp [natNodup]
theorem positionsInRange_spec (xs : List Nat) (n : Nat) :
    positionsInRange xs n = true ↔ ∀ i ∈ xs, i < n := by simp [positionsInRange, List.all_eq_true]

def stringAddOk (atoms : List Atom) (B : Builtins) (op : OpPrim)
    (admitsDec : AdmitsDec) (C : List TParam) : Bool :=
  match op (.binary .add) (.base .string) with
  | none => false
  | some (b, ts) => match B.sig b with
      | none => false
      | some s => ts.isEmpty && decide (ts.length = s.ntys) && decide (s.neffs = 0 ∧ s.nranges = 0) &&
          admitsDec b C ts && tyEq atoms (fnTyCheck atoms s.names s.params s.ret s.eff ts [])
            (.fn ["left", "right"] [.base .string, .base .string] (.base .string) Eff.empty)

theorem stringAddOk_sound {atoms B op admitsDec C}
    (had : AdmitsDecSound B admitsDec)
    (ha : ∀ b s, B.sig b = some s → Ty.AtomsIn atoms (.fn s.names s.params s.ret s.eff))
    (h : stringAddOk atoms B op admitsDec C = true) : StringAddOk B op C := by
  cases ho : op (.binary .add) (.base .string) with
  | none => simp [stringAddOk, ho] at h
  | some entry =>
      rcases entry with ⟨b, ts⟩
      cases hs : B.sig b with
      | none => simp [stringAddOk, ho, hs] at h
      | some s =>
          simp only [stringAddOk, ho, hs, Bool.and_eq_true_iff] at h
          rcases h with ⟨⟨⟨⟨hts, hlen⟩, heffs⟩, hadmits⟩, heq⟩
          have hnil : ts = [] := by simpa using hts
          subst ts
          have hat : Ty.AtomsIn atoms (fnTyCheck atoms s.names s.params s.ret s.eff [] []) :=
            substTy_atoms (ha b s hs) (by trivial) (by simp)
          have htarget : Ty.AtomsIn atoms
              (.fn ["left", "right"] [.base .string, .base .string] (.base .string) Eff.empty) := by
            simp [Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]
          have ht := tyEq_sound hat htarget heq
          refine ⟨b, [], s, ho, rfl, hs, of_decide_eq_true hlen,
            of_decide_eq_true heffs, had b C [] s hs hadmits, ?_⟩
          rw [fnTyCheck_eq _ _ _ _ _ _ (by simp) (by simp)
            (ha b s hs).1 (ha b s hs).2.1 (ha b s hs).2.2] at ht
          exact ht

end Benitoite.Surface.CheckTools

namespace Benitoite.Surface.CheckTools.FormatExamples
open Benitoite.Release

-- 書式の境界で、閉じた型集合と仕様の受理表を検査する。
-- 定数列や内部頭の表から期待値を作らず、型ごとの受理・拒否を指定する。
example : ([.integer, .integer8, .integer16, .integer32, .byte, .unsignedInteger16,
    .unsignedInteger32, .unsignedInteger64, .float, .float32, .decimal, .string,
    .character, .boolean] : List BaseTy).all
    (fun t => formatValid (.base t) { width := some 1 }) = true := by decide

example : ([
    (.integer, { kind := .d }, true),
    (.integer8, { kind := .b, alternate := true }, true),
    (.integer16, { kind := .o, alternate := true }, true),
    (.integer32, { kind := .x, alternate := true }, true),
    (.byte, { kind := .upperX, alternate := true }, true),
    (.unsignedInteger16, { sign := .plus }, true),
    (.unsignedInteger32, { zero := true, width := some 8 }, true),
    (.unsignedInteger64, { kind := .d }, true),
    (.float, { kind := .f, precision := some 0 }, true),
    (.float32, { kind := .f, precision := some 28 }, true),
    (.decimal, { kind := .f, sign := .plus, zero := true, width := some 8, precision := some 2 }, true),
    (.string, { kind := .s, align := .right, width := some 4 }, true),
    (.character, { kind := .c, align := .center, width := some 4 }, true),
    (.boolean, { align := .left, width := some 4 }, true),
    (.integer, { kind := .f }, false),
    (.float, { kind := .d }, false),
    (.float32, { kind := .x }, false),
    (.decimal, { kind := .b }, false),
    (.string, { kind := .c }, false),
    (.character, { kind := .s }, false),
    (.boolean, { kind := .b }, false),
    (.string, { sign := .plus }, false),
    (.character, { zero := true, width := some 8 }, false),
    (.boolean, { sign := .plus }, false),
    (.unit, { width := some 8 }, false)
  ] : List (BaseTy × FormatSpec × Bool)).all
    (fun (t, s, expected) => formatValid (.base t) s == expected) = true := by decide

-- 他の条件は有効なまま、各境界と併用禁止を一つずつ越える。
example : ([
    ({}, false),
    ({ width := some 0 }, false),
    ({ width := some 1 }, true),
    ({ width := some 65535 }, true),
    ({ width := some 65536 }, false),
    ({ kind := .f, precision := some 0 }, true),
    ({ kind := .f, precision := some 28 }, true),
    ({ kind := .f, precision := some 29 }, false),
    ({ precision := some 2 }, false),
    ({ kind := .d, precision := some 2 }, false),
    ({ align := .right }, false),
    ({ zero := true }, false),
    ({ align := .right, zero := true, width := some 8 }, false),
    ({ kind := .d, alternate := true }, false),
    ({ kind := .f, alternate := true }, false)
  ] : List (FormatSpec × Bool)).all
    (fun (s, expected) => formatSyntaxValid s == expected) = true := by decide

example : formatValid (.list (.base .integer)) { width := some 8 } = false ∧
    formatValid (.data "User" []) { width := some 8 } = false ∧
    formatValid (.tvar 0) { width := some 8 } = false := by decide

-- 七定数の型だけでは見つからない、引数の順序・符号化・省略の退行を検査する。
example : match ({ kind := .f, sign := .plus, zero := true, width := some 8, precision := some 2 } :
      FormatSpec).constants (by decide) with
    | [.integer k, .integer a, .integer s, .boolean alt, .boolean z, .integer w, .integer p] =>
      (k.toInt, a.toInt, s.toInt, alt, z, w.toInt, p.toInt) = (6, 0, 1, false, true, 8, 2)
    | _ => False := by dsimp [FormatSpec.constants]; decide

example : match ({ kind := .s, align := .center, width := some 65535 } : FormatSpec).constants
      (by decide) with
    | [.integer k, .integer a, .integer s, .boolean alt, .boolean z, .integer w, .integer p] =>
      (k.toInt, a.toInt, s.toInt, alt, z, w.toInt, p.toInt) = (7, 3, 0, false, false, 65535, -1)
    | _ => False := by dsimp [FormatSpec.constants]; decide

example : (({ kind := .f } : FormatSpec).widthCode (by decide)).toInt = 0 := by decide
example : (({ kind := .f, precision := some 0 } : FormatSpec).precisionCode
    (by decide)).toInt = 0 := by decide

example : ({ kind := .f } : FormatSpec).fixedPrecision (.base .float) 2 = some 6 ∧
    ({ kind := .f } : FormatSpec).fixedPrecision (.base .float32) 2 = some 6 ∧
    ({ kind := .f } : FormatSpec).fixedPrecision (.base .decimal) 2 = some 2 ∧
    ({ kind := .f, precision := some 0 } : FormatSpec).fixedPrecision (.base .decimal) 2 = some 0 :=
  by decide

end Benitoite.Surface.CheckTools.FormatExamples
