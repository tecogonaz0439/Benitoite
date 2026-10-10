import Benitoite.Surface.CheckTools

/-! 表層の規則の、型付けの判断以外の前提の判定。 -/
namespace Benitoite.Surface.CheckTools
open Benitoite.Release

mutual
  def wfTy (n : Nat) : Ty → Bool
    | .data _ ts => wfTys n ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => wfTy n t
    | .fn ps r _ => wfTys n ps && wfTy n r
    | .tvar i => decide (i < n)
    | .cont b t _ | .map b t => wfTy n b && wfTy n t
    | .tapp i ts => decide (i < n) && wfTys n ts
    | _ => true
  def wfTys (n : Nat) : List Ty → Bool
    | [] => true
    | t :: ts => wfTy n t && wfTys n ts
end

mutual
  theorem wfTy_spec (n : Nat) : (t : Ty) → (wfTy n t = true ↔ Ty.WF n t)
    | .base b => by simp [wfTy, Ty.WF]
    | .opaque o => by simp [wfTy, Ty.WF]
    | .data d ts => by simp [wfTy, Ty.WF, wfTys_spec n ts]
    | .list t => by simp [wfTy, Ty.WF, wfTy_spec n t]
    | .fn ps r e => by simp [wfTy, Ty.WF, wfTys_spec n ps, wfTy_spec n r]
    | .tvar i => by simp [wfTy, Ty.WF]
    | .reference t => by simp [wfTy, Ty.WF, wfTy_spec n t]
    | .lazy t => by simp [wfTy, Ty.WF, wfTy_spec n t]
    | .cont b t e => by simp [wfTy, Ty.WF, wfTy_spec n b, wfTy_spec n t]
    | .map b t => by simp [wfTy, Ty.WF, wfTy_spec n b, wfTy_spec n t]
    | .set t => by simp [wfTy, Ty.WF, wfTy_spec n t]
    | .bytes => by simp [wfTy, Ty.WF]
    | .dict cl t => by simp [wfTy, Ty.WF, wfTy_spec n t]
    | .tapp i ts => by simp [wfTy, Ty.WF, wfTys_spec n ts]
    | .ctor c => by simp [wfTy, Ty.WF]
  theorem wfTys_spec (n : Nat) : (ts : List Ty) → (wfTys n ts = true ↔ Ty.WFList n ts)
    | [] => by simp [wfTys, Ty.WFList]
    | t :: ts => by simp [wfTys, Ty.WFList, wfTy_spec n t, wfTys_spec n ts]
end

mutual
  def exprExits : Expr → Bool
    | .returnE _ _ => true
    | .ite _ y n => blockExits y && blockExits n
    | .elseIf _ y n => blockExits y && exprExits n
    | .paren e => exprExits e
    | .matchE _ _ arms => armsExits arms
    | .withE _ _ b => blockExits b
    | _ => false
  def blockExits : Block → Bool
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
    | .matchE _ _ a => by simp [exprExits, Expr.Exits, armsExits_spec a]
    | .withE _ _ b => by simp [exprExits, Expr.Exits, blockExits_spec b]
    | .local _ => by simp [exprExits, Expr.Exits]
    | .constE _ _ => by simp [exprExits, Expr.Exits]
    | .funName _ _ _ => by simp [exprExits, Expr.Exits]
    | .funDicts _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .methName _ _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .primName _ _ _ => by simp [exprExits, Expr.Exits]
    | .opName _ _ => by simp [exprExits, Expr.Exits]
    | .nullCon _ _ => by simp [exprExits, Expr.Exits]
    | .conValue _ _ _ => by simp [exprExits, Expr.Exits]
    | .literal _ => by simp [exprExits, Expr.Exits]
    | .negInt _ => by simp [exprExits, Expr.Exits]
    | .negFloat _ => by simp [exprExits, Expr.Exits]
    | .negDecimal _ _ => by simp [exprExits, Expr.Exits]
    | .unit => by simp [exprExits, Expr.Exits]
    | .conCall _ _ _ => by simp [exprExits, Expr.Exits]
    | .record _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .recordUpdate _ _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .call _ _ => by simp [exprExits, Expr.Exits]
    | .pipe _ _ => by simp [exprExits, Expr.Exits]
    | .partialCall _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .partialCon _ _ _ => by simp [exprExits, Expr.Exits]
    | .binary _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .neg _ _ => by simp [exprExits, Expr.Exits]
    | .not _ => by simp [exprExits, Expr.Exits]
    | .and _ _ => by simp [exprExits, Expr.Exits]
    | .or _ _ => by simp [exprExits, Expr.Exits]
    | .list _ _ => by simp [exprExits, Expr.Exits]
    | .listSpread _ _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .interpolation _ _ _ => by simp [exprExits, Expr.Exits]
    | .lam _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .ifOnly _ _ => by simp [exprExits, Expr.Exits]
    | .tryResult _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .tryOption _ _ _ _ => by simp [exprExits, Expr.Exits]
    | .lazyE _ => by simp [exprExits, Expr.Exits]
    | .handleE _ _ => by simp [exprExits, Expr.Exits]
    | .resume _ _ => by simp [exprExits, Expr.Exits]
  theorem blockExits_spec : (b : Block) → (blockExits b = true ↔ b.Exits)
    | .last e => by simp [blockExits, Block.Exits, exprExits_spec e]
    | .seq e b => by simp [blockExits, Block.Exits, exprExits_spec e, blockExits_spec b]
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
    | .range (.integer lo) (.integer hi) => decide (lo ≤ hi)
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
  | .local _ => by constructor <;> intro h <;> cases h
  | .constE _ _ => by constructor <;> intro h <;> cases h
  | .funName _ _ _ => by constructor <;> intro h <;> cases h
  | .funDicts _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .methName _ _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .primName _ _ _ => by constructor <;> intro h <;> cases h
  | .opName _ _ => by constructor <;> intro h <;> cases h
  | .nullCon _ _ => by constructor <;> intro h <;> cases h
  | .conValue _ _ _ => by constructor <;> intro h <;> cases h
  | .literal _ => by constructor <;> intro h <;> cases h
  | .negInt _ => by constructor <;> intro h <;> cases h
  | .negFloat _ => by constructor <;> intro h <;> cases h
  | .negDecimal _ _ => by constructor <;> intro h <;> cases h
  | .unit => by constructor <;> intro h <;> cases h
  | .paren _ => by constructor <;> intro h <;> cases h
  | .conCall _ _ _ => by constructor <;> intro h <;> cases h
  | .record _ _ _ _ => by constructor <;> intro h <;> cases h
  | .recordUpdate _ _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .call _ _ => by constructor <;> intro h <;> cases h
  | .pipe _ _ => by constructor <;> intro h <;> cases h
  | .partialCall _ _ _ _ => by constructor <;> intro h <;> cases h
  | .partialCon _ _ _ => by constructor <;> intro h <;> cases h
  | .binary _ _ _ _ => by constructor <;> intro h <;> cases h
  | .neg _ _ => by constructor <;> intro h <;> cases h
  | .not _ => by constructor <;> intro h <;> cases h
  | .and _ _ => by constructor <;> intro h <;> cases h
  | .or _ _ => by constructor <;> intro h <;> cases h
  | .list _ _ => by constructor <;> intro h <;> cases h
  | .listSpread _ _ _ _ _ => by constructor <;> intro h <;> cases h
  | .interpolation _ _ _ => by constructor <;> intro h <;> cases h
  | .lam _ _ _ _ => by constructor <;> intro h <;> cases h
  | .matchE _ _ _ => by constructor <;> intro h <;> cases h
  | .returnE _ _ => by constructor <;> intro h <;> cases h
  | .tryResult _ _ _ _ => by constructor <;> intro h <;> cases h
  | .tryOption _ _ _ _ => by constructor <;> intro h <;> cases h
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
  | .call _ _ | .conCall _ _ _ | .conValue _ _ _ => false
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
    | .base .byte | .base .decimal => true
  | _ => false

def interpAllowed : List InterpPart → Bool
  | [] => true
  | .converted t :: ps => convertedAllowed t && interpAllowed ps
  | _ :: ps => interpAllowed ps

theorem convertedAllowed_spec (t : Ty) : convertedAllowed t = true ↔
    (t = .base .integer ∨ t = .base .float ∨ t = .base .character ∨
     t = .base .boolean ∨ t = .base .byte ∨ t = .base .decimal) := by
  cases t <;> simp [convertedAllowed]
  rename_i b; cases b <;> simp

theorem interpAllowed_spec : (ps : List InterpPart) → (interpAllowed ps = true ↔ InterpPart.Allowed ps)
  | [] => by simp [interpAllowed, InterpPart.Allowed]
  | .converted t :: ps => by simp [interpAllowed, InterpPart.Allowed, convertedAllowed_spec, interpAllowed_spec ps]
  | .text _ :: ps => by simpa [interpAllowed, InterpPart.Allowed] using interpAllowed_spec ps
  | .stringExpr :: ps => by simpa [interpAllowed, InterpPart.Allowed] using interpAllowed_spec ps

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
      | some s => ts.isEmpty && decide (ts.length = s.ntys) && decide (s.neffs = 0) &&
          admitsDec b C ts && tyEq atoms (fnTyCheck s.params s.ret s.eff ts [])
            (.fn [.base .string, .base .string] (.base .string) Eff.empty)

theorem stringAddOk_sound {atoms B op admitsDec C}
    (had : AdmitsDecSound B admitsDec)
    (ha : ∀ b s, B.sig b = some s → Ty.AtomsIn atoms (.fn s.params s.ret s.eff))
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
          have hat : Ty.AtomsIn atoms (fnTyCheck s.params s.ret s.eff [] []) :=
            substTy_atoms (ha b s hs) (by trivial) (by simp)
          have htarget : Ty.AtomsIn atoms
              (.fn [.base .string, .base .string] (.base .string) Eff.empty) := by
            simp [Ty.AtomsIn, Tys.AtomsIn, Eff.AtomsIn, Eff.empty]
          have ht := tyEq_sound hat htarget heq
          refine ⟨b, [], s, ho, rfl, hs, of_decide_eq_true hlen,
            of_decide_eq_true heffs, had b C [] s hs hadmits, ?_⟩
          simpa only [fnTyCheck_eq] using ht

end Benitoite.Surface.CheckTools
