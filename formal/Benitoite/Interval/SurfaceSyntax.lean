import Benitoite.Surface.Syntax
import Benitoite.Interval.Eval
import Benitoite.Release.Refinement.Surface.SourceRename

/-!
# 区間解析へ渡す表層の構文

区間解析の入力には、型の篩を持たない構文を使う。新しい表層の型の篩と依存する注釈を消し、
式と子の順序を保存する。消した型の情報から、型付けやエフェクトの被覆を主張しない。
旧構文の持上げは、新しい脱糖と独立評価の対応に使う（設計書 01-12「区間解析の対象構文の評価関係」）。
-/
namespace Benitoite.Interval.SurfaceSyntax

/-- 起点や secrets による範囲は、型の情報を使わない解析では Top とする。 -/
def eraseRange : Benitoite.Release.Refinement.RangeExpr → Scope.Domain.Range
  | .absolute r => r
  | .based _ _ | .secrets => .top

def eraseIndex : Benitoite.Release.Refinement.RangeIx → Scope.Signature.Ix
  | .fixed r => .fixed (eraseRange r)
  | .rvar i => .rvar i

mutual
  /-- 型の注釈から篩と値の依存を除く。解析はこの注釈で権限を判定しない。 -/
  def eraseTy : Benitoite.Release.Refinement.Ty → Benitoite.Release.Ty
    | .base b => .base b
    | .opaque n r => .opaque n (eraseIndex r)
    | .data n as => .data n (eraseTys as)
    | .list a => .list (eraseTy a)
    | .fn ns ps r e => .fn ns (eraseTys ps) (eraseTy r) (eraseEff e)
    | .tvar i => .tvar i
    | .reference a => .reference (eraseTy a)
    | .lazy a => .lazy (eraseTy a)
    | .cont a b e => .cont (eraseTy a) (eraseTy b) (eraseEff e)
    | .map a b => .map (eraseTy a) (eraseTy b)
    | .set a => .set (eraseTy a)
    | .bytes => .bytes
    | .dict c a => .dict c (eraseTy a)
    | .tapp i as => .tapp i (eraseTys as)
    | .ctor c => .ctor c
    | .refined a _ => eraseTy a
    | .dependentFn t => eraseTel t
    | .external (.mk n) _ => .opaque ("%external:" ++ toString n) (.fixed .top)
    | .scoped n _ r => .opaque n (eraseIndex r)
    | .pathBases => .opaque "Scope.PathBases" (.fixed .top)
    | .scopePattern _ => .opaque "Scope.Pattern" (.fixed .top)
  def eraseTys : List Benitoite.Release.Refinement.Ty → List Benitoite.Release.Ty
    | [] => []
    | a :: as => eraseTy a :: eraseTys as
  def eraseEff : Benitoite.Release.Refinement.Eff → Benitoite.Release.Eff
    | .mk atoms fails => .mk (fun a => atoms (Benitoite.Release.Refinement.embedAtom a)) (eraseTys fails)
  def eraseTel : Benitoite.Release.Refinement.Tel → Benitoite.Release.Ty
    | .done a e => .fn [] [] (eraseTy a) (eraseEff e)
    | .param n a t => match eraseTel t with
      | .fn ns ps r e => .fn (n :: ns) (eraseTy a :: ps) r e
      | a' => .fn [n] [eraseTy a] a' Benitoite.Release.Eff.empty
end

/-- 演算子は同じ種類へ写す。 -/
def eraseBinOp : Benitoite.Release.Refinement.Surface.BinOp → Benitoite.Surface.BinOp
  | .add => .add | .sub => .sub | .mul => .mul | .div => .div | .intDiv => .intDiv | .mod => .mod
  | .eq => .eq | .ne => .ne | .lt => .lt | .le => .le | .gt => .gt | .ge => .ge

def liftBinOp : Benitoite.Surface.BinOp → Benitoite.Release.Refinement.Surface.BinOp
  | .add => .add | .sub => .sub | .mul => .mul | .div => .div | .intDiv => .intDiv | .mod => .mod
  | .eq => .eq | .ne => .ne | .lt => .lt | .le => .le | .gt => .gt | .ge => .ge

def eraseOperator : Benitoite.Release.Refinement.Surface.Operator → Benitoite.Surface.Operator
  | .binary o => .binary (eraseBinOp o) | .neg => .neg

def liftPosition : Benitoite.Surface.Position → Benitoite.Release.Refinement.Surface.Position
  | .tail => .tail | .other => .other

/-- 演算子の表は構文の注釈を同じ位置で読み、返す型だけを新しい核へ写す。 -/
def liftOp (op : Benitoite.Surface.OpPrim) : Benitoite.Release.Refinement.Surface.OpPrim := fun o a =>
  (op (eraseOperator o) (eraseTy a)).map fun (b, ts) => (b, Benitoite.Release.Refinement.embedTys ts)

def eraseLiteral : Benitoite.Release.Refinement.Surface.Literal → Benitoite.Surface.Literal
  | .integer n => .integer n | .float x => .float x | .decimal n s => .decimal n s
  | .string s => .string s | .character c => .character c | .boolean b => .boolean b
  | .integer8 n => .integer8 n | .integer16 n => .integer16 n | .integer32 n => .integer32 n
  | .byte n => .byte n | .unsignedInteger16 n => .unsignedInteger16 n
  | .unsignedInteger32 n => .unsignedInteger32 n | .unsignedInteger64 n => .unsignedInteger64 n
  | .float32 n => .float32 n

def liftLiteral : Benitoite.Surface.Literal → Benitoite.Release.Refinement.Surface.Literal
  | .integer n => .integer n | .float x => .float x | .decimal n s => .decimal n s
  | .string s => .string s | .character c => .character c | .boolean b => .boolean b
  | .integer8 n => .integer8 n | .integer16 n => .integer16 n | .integer32 n => .integer32 n
  | .byte n => .byte n | .unsignedInteger16 n => .unsignedInteger16 n
  | .unsignedInteger32 n => .unsignedInteger32 n | .unsignedInteger64 n => .unsignedInteger64 n
  | .float32 n => .float32 n

def eraseBindKind : Benitoite.Release.Refinement.Surface.BindKind → Benitoite.Surface.BindKind
  | .bind => .bind | .shadow => .shadow

def liftBindKind : Benitoite.Surface.BindKind → Benitoite.Release.Refinement.Surface.BindKind
  | .bind => .bind | .shadow => .shadow

def eraseBuilderKind : Benitoite.Release.Refinement.BuilderKind → Benitoite.Release.BuilderKind
  | .string => .string | .list a => .list (eraseTy a) | .bytes => .bytes

def liftBuilderKind : Benitoite.Release.BuilderKind → Benitoite.Release.Refinement.BuilderKind
  | .string => .string | .list a => .list (Benitoite.Release.Refinement.embedTy a) | .bytes => .bytes

mutual
  def erasePattern : Benitoite.Release.Refinement.Surface.Pattern → Benitoite.Surface.Pattern
    | .wild => .wild | .var => .var | .integer n => .integer n | .negInt n => .negInt n
    | .string s => .string s | .character c => .character c | .boolean b => .boolean b | .unit => .unit
    | .range a b => .range a.legacy b.legacy
    | .list xs r ys => .list (erasePatterns xs) r (erasePatterns ys)
    | .con q c xs => .con q c (erasePatterns xs)
    | .record c n ps xs => .record c n ps (erasePatterns xs)
  def erasePatterns : List Benitoite.Release.Refinement.Surface.Pattern → List Benitoite.Surface.Pattern
    | [] => [] | p :: ps => erasePattern p :: erasePatterns ps
end

mutual
  def liftPattern : Benitoite.Surface.Pattern → Benitoite.Release.Refinement.Surface.Pattern
    | .wild => .wild | .var => .var | .integer n => .integer n | .negInt n => .negInt n
    | .string s => .string s | .character c => .character c | .boolean b => .boolean b | .unit => .unit
    | .range a b => .range (Benitoite.Release.Refinement.embedConst a) (Benitoite.Release.Refinement.embedConst b)
    | .list xs r ys => .list (liftPatterns xs) r (liftPatterns ys)
    | .con q c xs => .con q c (liftPatterns xs)
    | .record c n ps xs => .record c n ps (liftPatterns xs)
  def liftPatterns : List Benitoite.Surface.Pattern → List Benitoite.Release.Refinement.Surface.Pattern
    | [] => [] | p :: ps => liftPattern p :: liftPatterns ps
end

def eraseAlternative (a : Benitoite.Release.Refinement.Surface.Alternative) : Benitoite.Surface.Alternative := ⟨erasePattern a.pat, a.slots⟩
def liftAlternative (a : Benitoite.Surface.Alternative) : Benitoite.Release.Refinement.Surface.Alternative := ⟨liftPattern a.pat, a.slots⟩

private def under (n : Nat) (ρ : Nat → Option Nat) : Nat → Option Nat :=
  fun i => if i < n then some i else (ρ (i-n)).map (·+n)

private def removeFirst (ρ : Nat → Option Nat) : Nat → Option Nat
  | 0 => none | i+1 => ρ i

mutual
  private def eraseDictAt (ρ : Nat → Option Nat) : Benitoite.Release.Refinement.Surface.DictEv → Benitoite.Surface.DictEv
    | .impl i ts ds => .impl i (eraseTys ts) (eraseDictsAt ρ ds)
    | .local i => .local ((ρ i).getD 0)
    | .clause s i d => .local ((ρ (d+s.slot i)).getD 0)
    | .super d c => .super (eraseDictAt ρ d) c
  private def eraseDictsAt (ρ : Nat → Option Nat) : List Benitoite.Release.Refinement.Surface.DictEv → List Benitoite.Surface.DictEv
    | [] => [] | d :: ds => eraseDictAt ρ d :: eraseDictsAt ρ ds
end

mutual
  def liftDict : Benitoite.Surface.DictEv → Benitoite.Release.Refinement.Surface.DictEv
    | .impl i ts ds => .impl i (Benitoite.Release.Refinement.embedTys ts) (liftDicts ds)
    | .local i => .local i
    | .clause s i d => .clause ⟨s.outer,s.arity,s.dictCount⟩ i d
    | .super d c => .super (liftDict d) c
  def liftDicts : List Benitoite.Surface.DictEv → List Benitoite.Release.Refinement.Surface.DictEv
    | [] => [] | d :: ds => liftDict d :: liftDicts ds
end

def eraseFormat (s : Benitoite.Release.Refinement.Surface.FormatSpec) : Benitoite.Surface.FormatSpec :=
  ⟨(match s.kind with | .default => .default | .d => .d | .b => .b | .o => .o | .x => .x | .upperX => .upperX | .f => .f | .s => .s | .c => .c),
   (match s.align with | .default => .default | .left => .left | .right => .right | .center => .center),
   (match s.sign with | .default => .default | .plus => .plus),s.alternate,s.zero,s.width,s.precision⟩

def liftFormat (s : Benitoite.Surface.FormatSpec) : Benitoite.Release.Refinement.Surface.FormatSpec :=
  ⟨(match s.kind with | .default => .default | .d => .d | .b => .b | .o => .o | .x => .x | .upperX => .upperX | .f => .f | .s => .s | .c => .c),
   (match s.align with | .default => .default | .left => .left | .right => .right | .center => .center),
   (match s.sign with | .default => .default | .plus => .plus),s.alternate,s.zero,s.width,s.precision⟩

def erasePart : Benitoite.Release.Refinement.Surface.InterpPart → Benitoite.Surface.InterpPart
  | .text t => .text t | .stringExpr => .stringExpr | .converted a => .converted (eraseTy a)
  | .formatted a s => .formatted (eraseTy a) (eraseFormat s)

def liftPart : Benitoite.Surface.InterpPart → Benitoite.Release.Refinement.Surface.InterpPart
  | .text t => .text t | .stringExpr => .stringExpr | .converted a => .converted (Benitoite.Release.Refinement.embedTy a)
  | .formatted a s => .formatted (Benitoite.Release.Refinement.embedTy a) (liftFormat s)

mutual
  private def eraseExprAt (ρ : Nat → Option Nat) : Benitoite.Release.Refinement.Surface.Expr → Benitoite.Surface.Expr
    | .local i => match ρ i with | some j => .local j | none => .funName "" [] []
    | .builderOp op i args kind => .builderOp op ((ρ i).getD 0) (eraseExprsAt ρ args) (eraseBuilderKind kind)
    | .constE ty body => .constE (eraseTy ty) (eraseExprAt ρ body)
    | .funName f tys effs _ => .funName f (eraseTys tys) (effs.map eraseEff)
    | .funDicts f tys effs dicts names params _ => .funDicts f (eraseTys tys) (effs.map eraseEff) (eraseDictsAt ρ dicts) names (eraseTys params)
    | .methName dict m tys effs dicts names params => .methName (eraseDictAt ρ dict) m (eraseTys tys) (effs.map eraseEff) (eraseDictsAt ρ dicts) names (eraseTys params)
    | .primName b tys effs ranges => .primName b (eraseTys tys) (effs.map eraseEff) (ranges.map fun r => match r with | .fixed r => eraseRange r | .rvar _ => .top)
    | .opName o tys => .opName o (eraseTys tys)
    | .opDicts o tys dicts names params => .opDicts o (eraseTys tys) (eraseDictsAt ρ dicts) names (eraseTys params)
    | .raise result error => .raise (eraseTy result) (eraseTy error)
    | .handleFail error result body clause => .handleFail (eraseTy error) (eraseTy result) (eraseBlockAt ρ body) (eraseBlockAt (under 2 ρ) clause)
    | .nullCon c tys => .nullCon c (eraseTys tys)
    | .conValue c tys names params => .conValue c (eraseTys tys) names (eraseTys params)
    | .literal l => .literal (eraseLiteral l)
    | .negInt n => .negInt n
    | .negFloat x => .negFloat x
    | .negDecimal n scale => .negDecimal n scale
    | .negInteger8 n => .negInteger8 n
    | .negInteger16 n => .negInteger16 n
    | .negInteger32 n => .negInteger32 n
    | .negFloat32 bits => .negFloat32 bits
    | .unit => .unit
    | .paren e => .paren (eraseExprAt ρ e)
    | .block body => .block (eraseBlockAt ρ body)
    | .conCall c tys args => .conCall c (eraseTys tys) (eraseExprsAt ρ args)
    | .record c tys positions args => .record c (eraseTys tys) positions (eraseExprsAt ρ args)
    | .recordUpdate c tys n positions base args => .recordUpdate c (eraseTys tys) n positions (eraseExprAt ρ base) (eraseExprsAt ρ args)
    | .call callee labels positions args => .call (eraseExprAt ρ callee) labels positions (eraseExprsAt ρ args)
    | .pipe lhs rhs => .pipe (eraseExprAt ρ lhs) (eraseExprAt ρ rhs)
    | .partialCall callee names args ret eff => .partialCall (eraseExprAt ρ callee) names (eraseHoleArgsAt ρ args) (eraseTy ret) (eraseEff eff)
    | .partialCon c tys args => .partialCon c (eraseTys tys) (eraseHoleArgsAt ρ args)
    | .binary op operandTy lhs rhs => .binary (eraseBinOp op) (eraseTy operandTy) (eraseExprAt ρ lhs) (eraseExprAt ρ rhs)
    | .neg operandTy e => .neg (eraseTy operandTy) (eraseExprAt ρ e)
    | .not e => .not (eraseExprAt ρ e)
    | .and lhs rhs => .and (eraseExprAt ρ lhs) (eraseExprAt ρ rhs)
    | .or lhs rhs => .or (eraseExprAt ρ lhs) (eraseExprAt ρ rhs)
    | .list elemTy elems => .list (eraseTy elemTy) (eraseExprsAt ρ elems)
    | .listSpread elemTy concat before spread after => .listSpread (eraseTy elemTy) (eraseExprAt ρ concat) (eraseExprsAt ρ before) (eraseExprAt ρ spread) (eraseExprsAt ρ after)
    | .interpolation parts es converters => .interpolation (parts.map erasePart) (eraseExprsAt ρ es) (eraseExprsAt ρ converters)
    | .lam names params ret eff body => .lam names (eraseTys params) (eraseTy ret) (eraseEff eff) (eraseBlockAt (under params.length ρ) body)
    | .ite cond yes no => .ite (eraseExprAt ρ cond) (eraseBlockAt ρ yes) (eraseBlockAt ρ no)
    | .elseIf cond yes no => .elseIf (eraseExprAt ρ cond) (eraseBlockAt ρ yes) (eraseExprAt ρ no)
    | .ifOnly cond yes => .ifOnly (eraseExprAt ρ cond) (eraseBlockAt ρ yes)
    | .matchE resultTy scrutinee arms => .matchE (eraseTy resultTy) (eraseExprAt ρ scrutinee) (eraseArmsAt (removeFirst ρ) arms)
    | .returnE resultTy e => .returnE (eraseTy resultTy) (eraseExprAt ρ e)
    | .tryResult retArgs ok err e => .tryResult (eraseTys retArgs) ok err (eraseExprAt ρ e)
    | .tryOption retArgs someCon noneCon e => .tryOption (eraseTys retArgs) someCon noneCon (eraseExprAt ρ e)
    | .tryResultDie successTy ok err dict showMethod exit e message => .tryResultDie (eraseTy successTy) ok err (eraseDictAt ρ dict) showMethod exit (eraseExprAt ρ e) (eraseMaybeAt ρ message)
    | .tryOptionDie successTy someCon noneCon exit e message => .tryOptionDie (eraseTy successTy) someCon noneCon exit (eraseExprAt ρ e) (eraseMaybeAt ρ message)
    | .withE o e body => .withE o (eraseExprAt ρ e) (eraseBlockAt (under 1 ρ) body)
    | .lazyE body => .lazyE (eraseBlockAt ρ body)
    | .handleE body clauses => .handleE (eraseBlockAt ρ body) (eraseClausesAt ρ clauses)
    | .resume k e => .resume ((ρ k).getD 0) (eraseExprAt ρ e)
    | .externalName _ _ => .funName "" [] []
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def eraseExprsAt (ρ : Nat → Option Nat) : Benitoite.Release.Refinement.Surface.Exprs → Benitoite.Surface.Exprs
    | .nil => .nil
    | .cons head tail => .cons (eraseExprAt ρ head) (eraseExprsAt ρ tail)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def eraseHoleArgsAt (ρ : Nat → Option Nat) : Benitoite.Release.Refinement.Surface.HoleArgs → Benitoite.Surface.HoleArgs
    | .nil => .nil
    | .expr label position head tail => .expr label position (eraseExprAt ρ head) (eraseHoleArgsAt ρ tail)
    | .hole label position ty tail => .hole label position (eraseTy ty) (eraseHoleArgsAt ρ tail)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def eraseArmsAt (ρ : Nat → Option Nat) : Benitoite.Release.Refinement.Surface.Arms → Benitoite.Surface.Arms
    | .nil => .nil
    | .cons alts guard body rest => .cons (alts.map eraseAlternative) (eraseMaybeAt (under (Benitoite.Release.Arm.bindersOf (Benitoite.Release.Refinement.Surface.Alternative.toCoreList alts)) ρ) guard) (eraseBlockAt (under (Benitoite.Release.Arm.bindersOf (Benitoite.Release.Refinement.Surface.Alternative.toCoreList alts)) ρ) body) (eraseArmsAt ρ rest)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def eraseClausesAt (ρ : Nat → Option Nat) : Benitoite.Release.Refinement.Surface.Clauses → Benitoite.Surface.Clauses
    | .nil => .nil
    | .cons op arity ntys body rest dictCount => .cons op arity ntys (eraseBlockAt (under (arity+dictCount+1) ρ) body) (eraseClausesAt ρ rest) dictCount
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def eraseBlockAt (ρ : Nat → Option Nat) : Benitoite.Release.Refinement.Surface.Block → Benitoite.Surface.Block
    | .builderBind kind rest => .builderBind (eraseBuilderKind kind) (eraseBlockAt (under 1 ρ) rest)
    | .empty => .empty
    | .last e => .last (eraseExprAt ρ e)
    | .lastBind kind boundTy e => .lastBind (eraseBindKind kind) (eraseTy boundTy) (eraseExprAt ρ e)
    | .lastDiscard e => .lastDiscard (eraseExprAt ρ e)
    | .bind kind boundTy e rest => .bind (eraseBindKind kind) (eraseTy boundTy) (eraseExprAt ρ e) (eraseBlockAt (under 1 ρ) rest)
    | .discard e rest => .discard (eraseExprAt ρ e) (eraseBlockAt ρ rest)
    | .seq e rest => .seq (eraseExprAt ρ e) (eraseBlockAt ρ rest)
    | .lastPat kind pattern boundTy e => .lastPat (eraseBindKind kind) (erasePattern pattern) (eraseTy boundTy) (eraseExprAt ρ e)
    | .bindPat kind pattern boundTy e rest => .bindPat (eraseBindKind kind) (erasePattern pattern) (eraseTy boundTy) (eraseExprAt ρ e) (eraseBlockAt (under pattern.binders ρ) rest)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  private def eraseMaybeAt (ρ : Nat → Option Nat) : Option Benitoite.Release.Refinement.Surface.Expr → Option Benitoite.Surface.Expr
    | none => none | some e => some (eraseExprAt ρ e)

  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
end

/-- 型注釈を消し、内側の束縛と照合対象のスロットを区別して構文を写す。 -/
def eraseExpr (source : Benitoite.Release.Refinement.Surface.Expr) : Benitoite.Surface.Expr :=
  eraseExprAt some source

@[simp] theorem eraseExpr_unit : eraseExpr .unit = .unit := by
  simp only [eraseExpr, eraseExprAt]

/-- 型注釈を消し、内側の束縛と照合対象のスロットを区別して構文を写す。 -/
def eraseBlock (source : Benitoite.Release.Refinement.Surface.Block) : Benitoite.Surface.Block :=
  eraseBlockAt some source

mutual
  def liftExpr : Benitoite.Surface.Expr → Benitoite.Release.Refinement.Surface.Expr
    | .local i => .local i
    | .builderOp op i args kind => .builderOp op i (liftExprs args) (liftBuilderKind kind)
    | .constE ty body => .constE (Benitoite.Release.Refinement.embedTy ty) (liftExpr body)
    | .funName f tys effs => .funName f (Benitoite.Release.Refinement.embedTys tys) (effs.map Benitoite.Release.Refinement.embedEff) []
    | .funDicts f tys effs dicts names params => .funDicts f (Benitoite.Release.Refinement.embedTys tys) (effs.map Benitoite.Release.Refinement.embedEff) (liftDicts dicts) names (Benitoite.Release.Refinement.embedTys params) []
    | .methName dict m tys effs dicts names params => .methName (liftDict dict) m (Benitoite.Release.Refinement.embedTys tys) (effs.map Benitoite.Release.Refinement.embedEff) (liftDicts dicts) names (Benitoite.Release.Refinement.embedTys params)
    | .primName b tys effs ranges => .primName b (Benitoite.Release.Refinement.embedTys tys) (effs.map Benitoite.Release.Refinement.embedEff) (ranges.map fun r => .fixed (.absolute r))
    | .opName o tys => .opName o (Benitoite.Release.Refinement.embedTys tys)
    | .opDicts o tys dicts names params => .opDicts o (Benitoite.Release.Refinement.embedTys tys) (liftDicts dicts) names (Benitoite.Release.Refinement.embedTys params)
    | .raise result error => .raise (Benitoite.Release.Refinement.embedTy result) (Benitoite.Release.Refinement.embedTy error)
    | .handleFail error result body clause => .handleFail (Benitoite.Release.Refinement.embedTy error) (Benitoite.Release.Refinement.embedTy result) (liftBlock body) (liftBlock clause)
    | .nullCon c tys => .nullCon c (Benitoite.Release.Refinement.embedTys tys)
    | .conValue c tys names params => .conValue c (Benitoite.Release.Refinement.embedTys tys) names (Benitoite.Release.Refinement.embedTys params)
    | .literal l => .literal (liftLiteral l)
    | .negInt n => .negInt n
    | .negFloat x => .negFloat x
    | .negDecimal n scale => .negDecimal n scale
    | .negInteger8 n => .negInteger8 n
    | .negInteger16 n => .negInteger16 n
    | .negInteger32 n => .negInteger32 n
    | .negFloat32 bits => .negFloat32 bits
    | .unit => .unit
    | .paren e => .paren (liftExpr e)
    | .block body => .block (liftBlock body)
    | .conCall c tys args => .conCall c (Benitoite.Release.Refinement.embedTys tys) (liftExprs args)
    | .record c tys positions args => .record c (Benitoite.Release.Refinement.embedTys tys) positions (liftExprs args)
    | .recordUpdate c tys n positions base args => .recordUpdate c (Benitoite.Release.Refinement.embedTys tys) n positions (liftExpr base) (liftExprs args)
    | .call callee labels positions args => .call (liftExpr callee) labels positions (liftExprs args)
    | .pipe lhs rhs => .pipe (liftExpr lhs) (liftExpr rhs)
    | .partialCall callee names args ret eff => .partialCall (liftExpr callee) names (liftHoleArgs args) (Benitoite.Release.Refinement.embedTy ret) (Benitoite.Release.Refinement.embedEff eff)
    | .partialCon c tys args => .partialCon c (Benitoite.Release.Refinement.embedTys tys) (liftHoleArgs args)
    | .binary op operandTy lhs rhs => .binary (liftBinOp op) (Benitoite.Release.Refinement.embedTy operandTy) (liftExpr lhs) (liftExpr rhs)
    | .neg operandTy e => .neg (Benitoite.Release.Refinement.embedTy operandTy) (liftExpr e)
    | .not e => .not (liftExpr e)
    | .and lhs rhs => .and (liftExpr lhs) (liftExpr rhs)
    | .or lhs rhs => .or (liftExpr lhs) (liftExpr rhs)
    | .list elemTy elems => .list (Benitoite.Release.Refinement.embedTy elemTy) (liftExprs elems)
    | .listSpread elemTy concat before spread after => .listSpread (Benitoite.Release.Refinement.embedTy elemTy) (liftExpr concat) (liftExprs before) (liftExpr spread) (liftExprs after)
    | .interpolation parts es converters => .interpolation (parts.map liftPart) (liftExprs es) (liftExprs converters)
    | .lam names params ret eff body => .lam names (Benitoite.Release.Refinement.embedTys params) (Benitoite.Release.Refinement.embedTy ret) (Benitoite.Release.Refinement.embedEff eff) (liftBlock body)
    | .ite cond yes no => .ite (liftExpr cond) (liftBlock yes) (liftBlock no)
    | .elseIf cond yes no => .elseIf (liftExpr cond) (liftBlock yes) (liftExpr no)
    | .ifOnly cond yes => .ifOnly (liftExpr cond) (liftBlock yes)
    | .matchE resultTy scrutinee arms => .matchE (Benitoite.Release.Refinement.embedTy resultTy) (liftExpr scrutinee) (liftArms arms)
    | .returnE resultTy e => .returnE (Benitoite.Release.Refinement.embedTy resultTy) (liftExpr e)
    | .tryResult retArgs ok err e => .tryResult (Benitoite.Release.Refinement.embedTys retArgs) ok err (liftExpr e)
    | .tryOption retArgs someCon noneCon e => .tryOption (Benitoite.Release.Refinement.embedTys retArgs) someCon noneCon (liftExpr e)
    | .tryResultDie successTy ok err dict showMethod exit e message => .tryResultDie (Benitoite.Release.Refinement.embedTy successTy) ok err (liftDict dict) showMethod exit (liftExpr e) (liftMaybe message)
    | .tryOptionDie successTy someCon noneCon exit e message => .tryOptionDie (Benitoite.Release.Refinement.embedTy successTy) someCon noneCon exit (liftExpr e) (liftMaybe message)
    | .withE o e body => .withE o (liftExpr e) (liftBlock body)
    | .lazyE body => .lazyE (liftBlock body)
    | .handleE body clauses => .handleE (liftBlock body) (liftClauses clauses)
    | .resume k e => .resume k (liftExpr e)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  def liftExprs : Benitoite.Surface.Exprs → Benitoite.Release.Refinement.Surface.Exprs
    | .nil => .nil
    | .cons head tail => .cons (liftExpr head) (liftExprs tail)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  def liftHoleArgs : Benitoite.Surface.HoleArgs → Benitoite.Release.Refinement.Surface.HoleArgs
    | .nil => .nil
    | .expr label position head tail => .expr label position (liftExpr head) (liftHoleArgs tail)
    | .hole label position ty tail => .hole label position (Benitoite.Release.Refinement.embedTy ty) (liftHoleArgs tail)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  def liftArms : Benitoite.Surface.Arms → Benitoite.Release.Refinement.Surface.Arms
    | .nil => .nil
    | .cons alts guard body rest =>
        let n := Benitoite.Release.Arm.bindersOf (Benitoite.Surface.Alternative.toCoreList alts)
        .cons (alts.map liftAlternative)
          ((liftMaybe guard).map (Benitoite.Release.Refinement.Surface.SourceRename.expr (Benitoite.Release.upRen n (·+1))))
          (Benitoite.Release.Refinement.Surface.SourceRename.block (Benitoite.Release.upRen n (·+1)) (liftBlock body))
          (liftArms rest)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  def liftClauses : Benitoite.Surface.Clauses → Benitoite.Release.Refinement.Surface.Clauses
    | .nil => .nil
    | .cons op arity ntys body rest dictCount => .cons op arity ntys (liftBlock body) (liftClauses rest) dictCount
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  def liftBlock : Benitoite.Surface.Block → Benitoite.Release.Refinement.Surface.Block
    | .builderBind kind rest => .builderBind (liftBuilderKind kind) (liftBlock rest)
    | .empty => .empty
    | .last e => .last (liftExpr e)
    | .lastBind kind boundTy e => .lastBind (liftBindKind kind) (Benitoite.Release.Refinement.embedTy boundTy) (liftExpr e)
    | .lastDiscard e => .lastDiscard (liftExpr e)
    | .bind kind boundTy e rest => .bind (liftBindKind kind) (Benitoite.Release.Refinement.embedTy boundTy) (liftExpr e) (liftBlock rest)
    | .discard e rest => .discard (liftExpr e) (liftBlock rest)
    | .seq e rest => .seq (liftExpr e) (liftBlock rest)
    | .lastPat kind pattern boundTy e => .lastPat (liftBindKind kind) (liftPattern pattern) (Benitoite.Release.Refinement.embedTy boundTy) (liftExpr e)
    | .bindPat kind pattern boundTy e rest => .bindPat (liftBindKind kind) (liftPattern pattern) (Benitoite.Release.Refinement.embedTy boundTy) (liftExpr e) (liftBlock rest)
  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
  def liftMaybe : Option Benitoite.Surface.Expr → Option Benitoite.Release.Refinement.Surface.Expr
    | none => none | some e => some (liftExpr e)

  termination_by source => sizeOf source
  decreasing_by all_goals (simp_wf <;> omega)
end

mutual
  /-- 型の篩を持たない注釈の持上げと消去は、元の注釈を保つ。 -/
  theorem eraseTy_embed (a : Benitoite.Release.Ty) :
      eraseTy (Benitoite.Release.Refinement.embedTy a) = a := by
    cases a <;> simp only [Benitoite.Release.Refinement.embedTy, eraseTy]
    all_goals try rfl
    case «opaque» o ix => cases ix <;> rfl
    all_goals simp only [eraseTy_embed, eraseTys_embed, eraseEff_embed]
  theorem eraseTys_embed (as : List Benitoite.Release.Ty) :
      eraseTys (Benitoite.Release.Refinement.embedTys as) = as := by
    cases as <;> simp only [Benitoite.Release.Refinement.embedTys, eraseTys, eraseTy_embed, eraseTys_embed]
  theorem eraseEff_embed (e : Benitoite.Release.Eff) :
      eraseEff (Benitoite.Release.Refinement.embedEff e) = e := by
    cases e with
    | mk atoms fails =>
      simp only [Benitoite.Release.Refinement.embedEff, eraseEff, eraseTys_embed]
      congr 1
      funext a
      exact Benitoite.Release.Refinement.embedAtoms_embed atoms a
end

/-- パターンの束縛と外側の値を保ち、隠れた照合対象への参照は未知の値にする。 -/
example :
    eraseExpr
      (.matchE (.refined (.base .integer) .truth) (.local 0)
        (.cons [⟨.var,[0]⟩] none
          (.last (.binary .add (.base .integer) (.local 0) (.local 2))) .nil)) =
      Benitoite.Surface.Expr.matchE (.base .integer) (.local 0)
        (.cons [⟨.var,[0]⟩] none
          (.last (.binary .add (.base .integer) (.local 0) (.local 1))) .nil) ∧
    eraseExpr
      (.matchE (.base .integer) (.local 0)
        (.cons [⟨.var,[0]⟩] none (.last (.local 1)) .nil)) =
      Benitoite.Surface.Expr.matchE (.base .integer) (.local 0)
        (.cons [⟨.var,[0]⟩] none (.last (.funName "" [] [])) .nil) ∧
    Benitoite.Interval.classify (.funName "" [] []) = .unknownValue := by
  constructor
  · simp [eraseExpr, eraseExprAt, eraseArmsAt, eraseBlockAt, eraseMaybeAt, under, removeFirst,
      eraseTy, eraseBinOp, eraseAlternative, erasePattern,
      Benitoite.Release.Arm.bindersOf,
      Benitoite.Release.Refinement.Surface.Alternative.toCoreList,
      Benitoite.Release.Refinement.Surface.Alternative.toCore,
      Benitoite.Release.Refinement.Surface.Pattern.toCore, Benitoite.Release.Pat.binders]
  constructor
  · simp [eraseExpr, eraseExprAt, eraseArmsAt, eraseBlockAt, eraseMaybeAt, under, removeFirst,
      eraseTy, eraseAlternative, erasePattern,
      Benitoite.Release.Arm.bindersOf,
      Benitoite.Release.Refinement.Surface.Alternative.toCoreList,
      Benitoite.Release.Refinement.Surface.Alternative.toCore,
      Benitoite.Release.Refinement.Surface.Pattern.toCore, Benitoite.Release.Pat.binders]
  · rfl

end Benitoite.Interval.SurfaceSyntax
