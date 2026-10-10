import Benitoite.Exchange.Syntax

namespace Benitoite.Exchange
open Lean

def Atom.toRelease : Atom → Benitoite.Release.Atom
  | .name s => .name s
  | .rho i => .rho i

def Eff.toRelease (e : Eff) : Benitoite.Release.Eff := fun a => e.any (fun b => b.toRelease == a)

/-- 脱糖は原子を新しく作らない。入力に現れた有限の原子だけを調べる。 -/
def fromEff (atoms : Eff) (e : Benitoite.Release.Eff) : Eff := atoms.filter (fun a => e a.toRelease)

partial def collectAtoms : Json → Eff
  | .arr xs => xs.toList.flatMap collectAtoms
  | j@(.obj xs) => match (fromJson? j : Except String Atom) with
      | .ok a => [a]
      | .error _ => xs.toArray.toList.flatMap (fun (_, v) => collectAtoms v)
  | _ => []

/-- 比較の前に全エフェクトを同じ有限の原子の順にする。ほかの並びは保つ。 -/
partial def canonicalJson (atoms : Eff) : Json → Json
  | .arr xs =>
      match (xs.toList.mapM (fromJson? · : Json → Except String Atom)) with
      | .ok es => toJson (atoms.filter (fun a => es.contains a))
      | .error _ => .arr (xs.map (canonicalJson atoms))
  | .obj xs => Json.mkObj (xs.toArray.toList.map (fun (k, v) => (k, canonicalJson atoms v)))
  | j => j

def baseTy : String → Except String Benitoite.Release.BaseTy
  | "Integer" => .ok .integer | "Float" => .ok .float
  | "String" => .ok .string | "Character" => .ok .character
  | "Boolean" => .ok .boolean | "Unit" => .ok .unit
  | "Byte" => .ok .byte | "Decimal" => .ok .decimal
  | n => .error s!"unknown base type: {n}"

def baseName : Benitoite.Release.BaseTy → String
  | .integer => "Integer" | .float => "Float" | .string => "String"
  | .character => "Character" | .boolean => "Boolean" | .unit => "Unit"
  | .byte => "Byte" | .decimal => "Decimal"

def TyCon.toRelease : TyCon → Benitoite.Release.TyCon
  | .data n => .data n | .list => .list | .set => .set | .map => .map
  | .reference => .reference | .lazyT => .lazy

def fromTyCon : Benitoite.Release.TyCon → TyCon
  | .data n => .data n | .list => .list | .set => .set | .map => .map
  | .reference => .reference | .lazy => .lazyT

partial def Ty.toRelease : Ty → Except String Benitoite.Release.Ty
  | .base n => return .base (← baseTy n)
  | .opaque n => return .opaque n
  | .data n ts => return .data n (← ts.mapM Ty.toRelease)
  | .list t => return .list (← t.toRelease)
  | .fn ps r e => return .fn (← ps.mapM Ty.toRelease) (← r.toRelease) e.toRelease
  | .tvar i => return .tvar i
  | .reference t => return .reference (← t.toRelease)
  | .lazyT t => return .lazy (← t.toRelease)
  | .map k v => return .map (← k.toRelease) (← v.toRelease)
  | .set t => return .set (← t.toRelease)
  | .bytes => return .bytes
  | .dict cl t => return .dict cl (← t.toRelease)
  | .tapp i ts => return .tapp i (← ts.mapM Ty.toRelease)
  | .ctor h => return .ctor h.toRelease

partial def fromTy (atoms : Eff) : Benitoite.Release.Ty → Except String Ty
  | .base t => return .base (baseName t)
  | .opaque n => return .opaque n
  | .data n ts => return .data n (← ts.mapM (fromTy atoms))
  | .list t => return .list (← fromTy atoms t)
  | .fn ps r e => return .fn (← ps.mapM (fromTy atoms)) (← fromTy atoms r) (fromEff atoms e)
  | .tvar i => return .tvar i
  | .reference t => return .reference (← fromTy atoms t)
  | .lazy t => return .lazyT (← fromTy atoms t)
  | .map k v => return .map (← fromTy atoms k) (← fromTy atoms v)
  | .set t => return .set (← fromTy atoms t)
  | .bytes => return .bytes
  | .dict cl t => return .dict cl (← fromTy atoms t)
  | .tapp i ts => return .tapp i (← ts.mapM (fromTy atoms))
  | .ctor h => return .ctor (fromTyCon h)
  | _ => throw "unsupported Release type"

/-! Lean の実行方式によっては NaN のペイロードが変わる。ビットを捨てて比較しない。
Rust の検査済みの Float リテラルは有限値だけであり、C3 の入力ではこの失敗は起きない。 -/
def floatFromBits (bits : UInt64) : Except String Float := do
  let value := Float.ofBits bits
  if value.toBits != bits then throw s!"Float bits cannot round-trip: {bits}"
  return value

def Const.toRelease : Const → Except String Benitoite.Release.Const
  | .integer n => return .integer n
  | .decimal n scale => return .decimal n scale
  | .float bits => return .float (← floatFromBits bits)
  | .string s => return .string s
  | .character n => if n ≤ 0x10ffff && !(0xd800 ≤ n && n ≤ 0xdfff)
      then return .character (Char.ofNat n) else throw "invalid Unicode scalar"
  | .boolean b => return .boolean b
  | .unit => return .unit

def fromConst : Benitoite.Release.Const → Except String Const
  | .integer n => return .integer n
  | .decimal n scale => return .decimal n scale
  | .float x => return .float x.toBits
  | .string s => return .string s
  | .character c => return .character c.toNat
  | .boolean b => return .boolean b
  | .unit => return .unit
  | _ => throw "unsupported Release constant"

def ListRest.toRelease : ListRest → Benitoite.Release.ListRest
  | .skip => .skip | .bind => .bind

def fromListRest : Benitoite.Release.ListRest → ListRest
  | .skip => .skip | .bind => .bind

partial def Pattern.toSurface : Pattern → Except String Benitoite.Surface.Pattern
  | .wild => return .wild | .var => return .var
  | .con n ps => return .con none n (← ps.mapM Pattern.toSurface)
  | .record n count positions ps => do
      if positions.length != ps.length || positions.eraseDups != positions ||
          positions.any (fun i => i >= count) then throw "invalid record pattern positions"
      return .record n count positions (← ps.mapM Pattern.toSurface)
  | .range lo hi => do
      match lo, hi with
      | .integer _, .integer _ | .character _, .character _ =>
          return .range (← lo.toRelease) (← hi.toRelease)
      | _, _ => throw "invalid range endpoint types"
  | .list before rest after => do
      if rest.isNone && !after.isEmpty then throw "list suffix without rest"
      return .list (← before.mapM Pattern.toSurface) (rest.map ListRest.toRelease) (← after.mapM Pattern.toSurface)
  | .unsupported n => throw s!"unsupported surface pattern: {n}"
  | .const c => match c with
      | .integer n => if n < 0 then return .negInt n.natAbs else return .integer n.toNat
      | .string s => return .string s
      | .character _n => do
          let .character c ← c.toRelease | throw "expected character"
          return .character c
      | .boolean b => return .boolean b
      | .unit => return .unit
      | .float _ => throw "Float pattern outside C3"
      | .decimal .. => throw "Decimal pattern outside C6c-1"

partial def fromPattern : Benitoite.Release.Pat → Except String Pattern
  | .wild => return .wild | .var => return .var
  | .const c => return .const (← fromConst c)
  | .con n ps => return .con n (← ps.mapM fromPattern)
  | .range lo hi => return .range (← fromConst lo) (← fromConst hi)
  | .list before rest after => return .list (← before.mapM fromPattern) (rest.map fromListRest) (← after.mapM fromPattern)

def binOp : String → Except String Benitoite.Surface.BinOp
  | "add" => return .add | "sub" => return .sub | "mul" => return .mul
  | "div" => return .div | "intDiv" => return .intDiv | "mod" => return .mod
  | "eq" => return .eq | "ne" => return .ne | "lt" => return .lt
  | "le" => return .le | "gt" => return .gt | "ge" => return .ge
  | s => throw s!"unknown binary operator: {s}"

def operatorName : Benitoite.Surface.Operator → String
  | .neg => "neg"
  | .binary b => match b with
      | .add => "add" | .sub => "sub" | .mul => "mul" | .div => "div"
      | .intDiv => "intDiv" | .mod => "mod" | .eq => "eq" | .ne => "ne"
      | .lt => "lt" | .le => "le" | .gt => "gt" | .ge => "ge"

def makeOpPrim (atoms : Eff) (entries : List OperatorEntry) : Benitoite.Surface.OpPrim := fun op ty =>
  entries.findSome? fun entry =>
    if entry.op != operatorName op then none
    else if entry.operand.isNone || (fromTy atoms ty).toOption == entry.operand then
      some (entry.name, op.typeArgs ty)
    else none

def OpRef.toRelease : OpRef → Benitoite.Release.OpRef
  | .user n => .user n | .prim n => .prim n

def fromOpRef : Benitoite.Release.OpRef → OpRef
  | .user n => .user n | .prim n => .prim n

partial def DictEv.toSurface : DictEv → Except String Benitoite.Surface.DictEv
  | .impl n ts ds => return .impl n (← ts.mapM Ty.toRelease) (← ds.mapM DictEv.toSurface)
  | .local i => return .local i
  | .super d cl => return .super (← d.toSurface) cl

def InterpPart.toSurface : InterpPart → Except String Benitoite.Surface.InterpPart
  | .text s => return .text s
  | .stringExpr => return .stringExpr
  | .converted t => do
      let .base n := t | throw "non-basic converted interpolation type"
      if !["Integer", "Float", "Character", "Boolean", "Byte", "Decimal"].contains n then
        throw "invalid converted interpolation type"
      return .converted (← t.toRelease)

mutual
  partial def Expr.toSurface (constants : List (String × Benitoite.Surface.Expr) := []) : Expr → Except String Benitoite.Surface.Expr
    | .constName name => do
        let some e := (constants.find? (fun p => p.1 == name)).map Prod.snd
          | throw s!"missing expanded constant: {name}"
        return e
    | .local i => return .local i
    | .funDicts n ts es ds ps _ => return .funDicts n (← ts.mapM Ty.toRelease) (es.map Eff.toRelease) (← ds.mapM DictEv.toSurface) (← ps.mapM Ty.toRelease)
    | .methName d n ts es ds ps _ => return .methName (← d.toSurface) n (← ts.mapM Ty.toRelease) (es.map Eff.toRelease) (← ds.mapM DictEv.toSurface) (← ps.mapM Ty.toRelease)
    | .opName n ts => return .opName n (← ts.mapM Ty.toRelease)
    | .funName n ts es => return .funName n (← ts.mapM Ty.toRelease) (es.map Eff.toRelease)
    | .primName n ts es => return .primName n (← ts.mapM Ty.toRelease) (es.map Eff.toRelease)
    | .nullCon n ts => return .nullCon n (← ts.mapM Ty.toRelease)
    | .conValue n ts ps => return .conValue n (← ts.mapM Ty.toRelease) (← ps.mapM Ty.toRelease)
    | .literal c => match c with
        | .integer n => if n < 0 then return .negInt n.natAbs else return .literal (.integer n.toNat)
        | .decimal n scale => do
            if n < 0 then throw "negative Decimal literal coefficient"
            return .literal (.decimal n scale)
        | .float b => return .literal (.float (← floatFromBits b))
        | .string s => return .literal (.string s)
        | .character _n => do
            let .character c ← c.toRelease | throw "expected character"
            return .literal (.character c)
        | .boolean b => return .literal (.boolean b)
        | .unit => return .unit
    | .unit => return .unit
    | .paren e => return .paren (← e.toSurface constants)
    -- 交換形式は符号込みの結果を持つ。表層の negFloat は反転前の値を持つ。
    | .negFloat bits => return .negFloat (-(← floatFromBits bits))
    | .negDecimal n scale => do
        if n < 0 then throw "negative negDecimal coefficient"
        return .negDecimal n scale
    | .record n ts positions es => do
        if positions.length != es.length || positions.mergeSort (· ≤ ·) != List.range es.length then
          throw "invalid record construction positions"
        return .record n (← ts.mapM Ty.toRelease) positions (← toExprs constants es)
    | .recordUpdate n ts count positions base es => do
        if positions.isEmpty || positions.length != es.length || positions.eraseDups != positions ||
            positions.any (fun i => i >= count) then throw "invalid record update positions"
        return .recordUpdate n (← ts.mapM Ty.toRelease) count positions (← base.toSurface constants) (← toExprs constants es)
    | .conCall n ts es => return .conCall n (← ts.mapM Ty.toRelease) (← toExprs constants es)
    | .call f es => return .call (← f.toSurface constants) (← toExprs constants es)
    | .pipe a b => return .pipe (← a.toSurface constants) (← b.toSurface constants)
    | .partialCall f es r e => return .partialCall (← f.toSurface constants) (← toHoles constants es) (← r.toRelease) e.toRelease
    | .partialCon n ts es => return .partialCon n (← ts.mapM Ty.toRelease) (← toHoles constants es)
    | .binary op t a b => return .binary (← binOp op) (← t.toRelease) (← a.toSurface constants) (← b.toSurface constants)
    | .neg t e => return .neg (← t.toRelease) (← e.toSurface constants)
    | .not e => return .not (← e.toSurface constants)
    | .and a b => return .and (← a.toSurface constants) (← b.toSurface constants)
    | .or a b => return .or (← a.toSurface constants) (← b.toSurface constants)
    | .list t es => return .list (← t.toRelease) (← toExprs constants es)
    | .listSpread t f before e after => do
        let f ← f.toSurface constants
        if (Benitoite.Surface.directCallee f).isNone then throw "indirect list concat"
        return .listSpread (← t.toRelease) f (← toExprs constants before) (← e.toSurface constants) (← toExprs constants after)
    | .interpolation ps es fs => do
        let ps ← ps.mapM InterpPart.toSurface
        if es.length != (Benitoite.Surface.InterpPart.exprTypes ps).length ||
            fs.length != (Benitoite.Surface.InterpPart.converterTypes ps).length then
          throw "interpolation part/expression/converter count mismatch"
        let converted ← fs.mapM (Expr.toSurface constants)
        if converted.any (fun f => (Benitoite.Surface.directCallee f).isNone) then
          throw "indirect interpolation converter"
        return .interpolation ps (← toExprs constants es) (← toExprs constants fs)
    | .lam ps r e b => return .lam (← ps.mapM Ty.toRelease) (← r.toRelease) e.toRelease (← b.toSurface constants)
    | .ite c y n => return .ite (← c.toSurface constants) (← y.toSurface constants) (← n.toSurface constants)
    | .elseIf c y n => return .elseIf (← c.toSurface constants) (← y.toSurface constants) (← n.toSurface constants)
    | .ifOnly c y => return .ifOnly (← c.toSurface constants) (← y.toSurface constants)
    | .matchE r e as => return .matchE (← r.toRelease) (← e.toSurface constants) (← toArms constants as)
    | .returnE r e => return .returnE (← r.toRelease) (← e.toSurface constants)
    | .tryResult ts ok err e => return .tryResult (← ts.mapM Ty.toRelease) ok err (← e.toSurface constants)
    | .tryOption ts someCon noneCon e => return .tryOption (← ts.mapM Ty.toRelease) someCon noneCon (← e.toSurface constants)
    | .withE o e b => return .withE o (← e.toSurface constants) (← b.toSurface constants)
    | .lazyE b => return .lazyE (← b.toSurface constants)
    | .handleE b cs => return .handleE (← b.toSurface constants) (← toClauses constants cs)
    | .resume k e => return .resume k (← e.toSurface constants)
  partial def toClauses (constants : List (String × Benitoite.Surface.Expr) := []) : List SurfaceClause → Except String Benitoite.Surface.Clauses
    | [] => return .nil
    | .mk op arity ntys b :: cs => return .cons op.toRelease arity ntys (← b.toSurface constants) (← toClauses constants cs)
  partial def toExprs (constants : List (String × Benitoite.Surface.Expr) := []) : List Expr → Except String Benitoite.Surface.Exprs
    | [] => return .nil
    | e :: es => return .cons (← e.toSurface constants) (← toExprs constants es)
  partial def toHoles (constants : List (String × Benitoite.Surface.Expr) := []) : List HoleArg → Except String Benitoite.Surface.HoleArgs
    | [] => return .nil
    | .expr e :: es => return .expr (← e.toSurface constants) (← toHoles constants es)
    | .hole t :: es => return .hole (← t.toRelease) (← toHoles constants es)
  partial def toArms (constants : List (String × Benitoite.Surface.Expr) := []) : List Arm → Except String Benitoite.Surface.Arms
    | [] => return .nil
    | .mk alts g b :: as => do
        let alts ← alts.mapM fun a => do
          let p ← a.pat.toSurface
          if a.slots.mergeSort (· ≤ ·) != List.range p.binders then throw "invalid alternative slots"
          pure ({ pat := p, slots := a.slots } : Benitoite.Surface.Alternative)
        let some first := alts.head? | throw "empty alternatives"
        if first.slots != List.range first.pat.binders then throw "nonidentity first alternative"
        if alts.any (fun a => a.slots.length != first.slots.length) then throw "alternative binder counts differ"
        return .cons alts (← g.mapM (Expr.toSurface constants)) (← b.toSurface constants) (← toArms constants as)
  partial def Block.toSurface (constants : List (String × Benitoite.Surface.Expr) := []) : Block → Except String Benitoite.Surface.Block
    | .empty => return .empty
    | .last e => return .last (← e.toSurface constants)
    | .lastBind k t e => return .lastBind (if k then .shadow else .bind) (← t.toRelease) (← e.toSurface constants)
    | .lastDiscard e => return .lastDiscard (← e.toSurface constants)
    | .bind k t e b => return .bind (if k then .shadow else .bind) (← t.toRelease) (← e.toSurface constants) (← b.toSurface constants)
    | .discard e b => return .discard (← e.toSurface constants) (← b.toSurface constants)
    | .seq e b => return .seq (← e.toSurface constants) (← b.toSurface constants)
    | .lastPat k p t e => return .lastPat (if k then .shadow else .bind) (← p.toSurface) (← t.toRelease) (← e.toSurface constants)
    | .bindPat k p t e b => return .bindPat (if k then .shadow else .bind) (← p.toSurface) (← t.toRelease) (← e.toSurface constants) (← b.toSurface constants)
end

partial def constantNames : Json → List String
  | .arr xs => xs.toList.flatMap constantNames
  | j@(.obj xs) =>
      if let .ok o := j.getObjVal? "constName" then
        ((o.getObjVal? "name").bind Json.getStr?).toOption.toList
      else xs.toArray.toList.flatMap (fun (_,v) => constantNames v)
  | _ => []

structure ConstantState where
  cache : List (String × Benitoite.Surface.Expr) := []
  active : List String := []

/-- 展開中の名前は循環、完成した値は共有する。使用位置の環境を渡さない。 -/
partial def expandConstant (table : List ConstantEntry) (name : String) :
    StateT ConstantState (Except String) Unit := do
  let state ← get
  if state.cache.any (fun p => p.1 == name) then return
  if state.active.contains name then throw s!"cyclic constant: {name}"
  let some entry := table.find? (fun e => e.name == name) | throw s!"missing constant: {name}"
  modify fun s => { s with active := name :: s.active }
  for dependency in (constantNames (toJson entry.body)).eraseDups do
    expandConstant table dependency
  let body ← entry.body.toSurface (← get).cache
  let value := Benitoite.Surface.Expr.constE (← entry.ty.toRelease) body
  modify fun s => { s with cache := (name, value) :: s.cache, active := s.active.tail }

def Input.constantCache (input : Input) : Except String (List (String × Benitoite.Surface.Expr)) := do
  if (input.constants.map ConstantEntry.name).eraseDups.length != input.constants.length then
    throw "duplicate constant name"
  let (_, state) ← (input.constants.forM (fun e => expandConstant input.constants e.name)).run {}
  return state.cache

mutual
  partial def fromVal (atoms : Eff) : Benitoite.Release.Val → Except String Val
    | .var i => return .var i
    | .dict n ts ds => return .dict n (← ts.mapM (fromTy atoms)) (← ds.mapM (fromVal atoms))
    | .super d cl => return .super (← fromVal atoms d) cl
    | .op n ts => return .op n (← ts.mapM (fromTy atoms))
    | .const c => return .const (← fromConst c)
    | .fnRef n ts es => return .fnRef n (← ts.mapM (fromTy atoms)) (es.map (fromEff atoms))
    | .prim n ts es => return .prim n (← ts.mapM (fromTy atoms)) (es.map (fromEff atoms))
    | .lam ps b => return .lam (← ps.mapM (fromTy atoms)) (← fromComp atoms b)
    | .con n ts vs => return .con n (← ts.mapM (fromTy atoms)) (← vs.mapM (fromVal atoms))
    | .list vs => return .list (← vs.mapM (fromVal atoms))
    | _ => return .unsupported "Release.Val"
  partial def fromComp (atoms : Eff) : Benitoite.Release.Comp → Except String Comp
    | .ret v => return .ret (← fromVal atoms v)
    | .meth d n ts es vs => return .meth (← fromVal atoms d) n (← ts.mapM (fromTy atoms)) (es.map (fromEff atoms)) (← vs.mapM (fromVal atoms))
    | .letIn m n => return .letIn (← fromComp atoms m) (← fromComp atoms n)
    | .app f vs => return .app (← fromVal atoms f) (← vs.mapM (fromVal atoms))
    | .ite v m n => return .ite (← fromVal atoms v) (← fromComp atoms m) (← fromComp atoms n)
    | .match v arms => do
        let as ← arms.mapM fun
          | .mk alts guard body => do
              let alts ← alts.mapM fun a => do
                pure ({ pat := ← fromPattern a.pat, slots := a.slots } : Alternative)
              return CoreArm.mk alts (← guard.mapM (fromComp atoms)) (← fromComp atoms body)
        return .matchC (← fromVal atoms v) as
    | .escape v => return .escape (← fromVal atoms v)
    | .use v b => return .use (← fromVal atoms v) (← fromComp atoms b)
    | .lazyC b => return .lazyC (← fromComp atoms b)
    | .handle b cs => return .handle (← fromComp atoms b) (← cs.mapM (fromClause atoms))
    | .resume (.var k) v => return .resume k (← fromVal atoms v)
    | _ => return .unsupported "Release.Comp"
  partial def fromClause (atoms : Eff) : Benitoite.Release.Clause → Except String CoreClause
    | .mk op arity ntys b => return .mk (fromOpRef op) arity ntys (← fromComp atoms b)
end

/-! Release.Val.lam は効果注釈を持たないので、表層の注釈を出力順に別欄で比較する。
構成子を直接適用する pipe は conValue のラムダを作らない。 -/
mutual
  partial def Expr.lambdaEffects (constants : List ConstantEntry := []) : Expr → List Eff
    | .constName name => ((constants.find? (fun e => e.name == name)).map (fun e => e.body.lambdaEffects constants)).getD []
    | .lam _ _ e b => e :: b.lambdaEffects constants
    | .conValue .. => [[]]
    | .funDicts _ _ _ _ _ e | .methName _ _ _ _ _ _ e => [e]
    | .partialCall f es _ e => e :: (f.headLambdaEffects constants ++ holesEffects constants es)
    | .partialCon _ _ es => [] :: holesEffects constants es
    | .call f es => f.headLambdaEffects constants ++ es.flatMap (Expr.lambdaEffects constants)
    | .conCall _ _ es | .list _ es | .record _ _ _ es => es.flatMap (Expr.lambdaEffects constants)
    | .recordUpdate _ _ _ _ base es => base.lambdaEffects constants ++ es.flatMap (Expr.lambdaEffects constants)
    | .listSpread _ f before e after => before.flatMap (Expr.lambdaEffects constants) ++
        e.lambdaEffects constants ++ after.flatMap (Expr.lambdaEffects constants) ++ f.headLambdaEffects constants
    | .interpolation _ es fs => es.flatMap (Expr.lambdaEffects constants) ++ fs.flatMap (Expr.headLambdaEffects constants)
    | .pipe a b => a.lambdaEffects constants ++ (match b with
        | .conValue .. => []
        | .call f es => f.headLambdaEffects constants ++ es.flatMap (Expr.lambdaEffects constants)
        | other => other.headLambdaEffects constants)
    | .binary _ _ a b | .and a b | .or a b => a.lambdaEffects constants ++ b.lambdaEffects constants
    | .paren e | .neg _ e | .not e | .returnE _ e
      | .tryResult _ _ _ e | .tryOption _ _ _ e => e.lambdaEffects constants
    | .withE _ e b => e.lambdaEffects constants ++ b.lambdaEffects constants
    | .lazyE b => b.lambdaEffects constants
    | .resume _ e => e.lambdaEffects constants
    | .handleE b cs => b.lambdaEffects constants ++ cs.flatMap (fun (.mk _ _ _ b) => b.lambdaEffects constants)
    | .ite c y n => c.lambdaEffects constants ++ y.lambdaEffects constants ++ n.lambdaEffects constants
    | .elseIf c y n => c.lambdaEffects constants ++ y.lambdaEffects constants ++ n.lambdaEffects constants
    | .ifOnly c y => c.lambdaEffects constants ++ y.lambdaEffects constants
    | .matchE _ e as => e.lambdaEffects constants ++ as.flatMap (fun (.mk _ g b) => (g.map (Expr.lambdaEffects constants)).getD [] ++ b.lambdaEffects constants)
    | _ => []
  /-- 裸の辞書付きの名前は CallHead になり、値化のラムダを作らない。
  paren はこの分岐に含めず、内側の値化のエフェクトを保持する。 -/
  partial def Expr.headLambdaEffects (constants : List ConstantEntry := []) : Expr → List Eff
    | .funDicts .. | .methName .. => []
    | e => e.lambdaEffects constants
  partial def holesEffects (constants : List ConstantEntry := []) (es : List HoleArg) : List Eff := es.flatMap fun
    | .expr e => e.lambdaEffects constants | .hole _ => []
  partial def Block.lambdaEffects (constants : List ConstantEntry := []) : Block → List Eff
    | .empty => []
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => e.lambdaEffects constants
    | .bind _ _ e b | .discard e b | .seq e b | .bindPat _ _ _ e b => e.lambdaEffects constants ++ b.lambdaEffects constants
end

def SurfaceDef.toSurface (d : SurfaceDef) (constants : List (String × Benitoite.Surface.Expr) := []) : Except String Benitoite.Surface.Def := do
  return {
    tparams := d.header.tparams.map (fun (e, k) => ⟨e, k⟩)
    dictParams := d.dictParams
    neffs := d.header.neffs
    params := ← d.header.params.mapM Ty.toRelease
    ret := ← d.header.ret.toRelease
    eff := d.header.eff.toRelease
    body := ← d.body.toSurface constants }

def OpEntry.toRelease (o : OpEntry) : Except String Benitoite.Release.OpDecl := do
  if o.header.neffs != 0 then throw "operation declares effect parameters"
  return {
    eff := o.eff
    tparams := o.header.tparams.map (fun (e, k) => ⟨e, k⟩)
    params := ← o.header.params.mapM Ty.toRelease
    ret := ← o.header.ret.toRelease }

/-- 表は一度だけ読み、表層のプログラムの表にする。脱糖はこの表をそのまま写す。 -/
def Input.operationProgram (input : Input) : Except String Benitoite.Surface.Program := do
  let ops ← input.ops.mapM (fun o => do return (o.name, ← o.toRelease))
  let classes ← input.classes.mapM (fun cl => do
    let methods ← cl.methods.mapM (fun m => do
      let sg : Benitoite.Release.MethSig := {
        tparams := m.header.tparams.map (fun (e,k) => ⟨e,k⟩)
        neffs := m.header.neffs
        params := ← m.header.params.mapM Ty.toRelease
        ret := ← m.header.ret.toRelease
        eff := m.header.eff.toRelease }
      return (m.name, sg))
    let decl : Benitoite.Release.ClassDecl := {
      supers := cl.supers
      methods := fun n => (methods.find? (fun m => m.1 == n)).map Prod.snd }
    return (cl.name, decl))
  let impls ← input.impls.mapM (fun i => do
    let decl : Benitoite.Surface.ImplDecl := {
      tparams := i.tparams.map (fun (e,k) => ⟨e,k⟩)
      dictParams := i.dictParams
      cls := i.cls
      target := ← i.target.toRelease
      supers := fun _ => none
      methods := fun _ => none }
    return (i.name, decl))
  let accessors ← (input.definitions.filterMap (fun d => match d.scope with
    | .accessor name con k decl _ => some (name, con, k, decl)
    | _ => none)).mapM (fun (name, con, k, decl) => do
      if k >= decl.args.length then throw "accessor index outside record"
      let cd : Benitoite.Release.ConDecl := {
        data := decl.data, ntys := decl.ntys, args := ← decl.args.mapM Ty.toRelease }
      return (name, con, k, cd))
  if (accessors.map (fun (n,_,_,_) => n)).eraseDups.length != accessors.length then
    throw "duplicate accessor name"
  return {
    defs := fun _ => none
    cons := fun n => (accessors.find? (fun (_,c,_,_) => c == n)).map (fun (_,_,_,cd) => cd)
    accessors := fun n => (accessors.find? (fun (f,_,_,_) => f == n)).map (fun (_,c,k,_) => (c,k))
    ops := fun n => (ops.find? (fun o => o.1 == n)).map Prod.snd
    effects := fun n => (input.effects.find? (fun e => e.name == n)).map EffectEntry.ops
    classes := fun n => (classes.find? (fun c => c.1 == n)).map Prod.snd
    impls := fun n => (impls.find? (fun i => i.1 == n)).map Prod.snd }

/-- HasClauses.cons の arity・ntys の前提を交換形式でも検査する。
JSON の全子を辿るので、プレースホルダ・ラムダ・遅延・入れ子の節も検査する。 -/
partial def validateClauses (program : Benitoite.Surface.Program)
    (prims : List PrimOpEntry) : Json → Except String Unit
  | .arr xs => xs.toList.forM (validateClauses program prims)
  | j@(.obj xs) => do
      if let .ok h := j.getObjVal? "handleE" then
        let cs ← (← h.getObjVal? "clauses").getArr?
        for c in cs do
          let .mk op arity ntys _ ← decodeSurfaceClause c
          let (expectedArity, expectedNtys) ← match op with
            | .user n => do
                let some od := program.ops n | throw s!"missing operation: {n}"
                pure (od.params.length, od.tparams.length)
            | .prim n => do
                let some od := prims.find? (fun p => p.name == n) | throw s!"missing primitive operation: {n}"
                pure (od.arity, od.ntys)
          if arity != expectedArity || ntys != expectedNtys then
            throw s!"clause signature mismatch: {toJson op}, arity={arity}/{expectedArity}, ntys={ntys}/{expectedNtys}"
      xs.toArray.toList.forM (fun (_, v) => validateClauses program prims v)
  | _ => pure ()

def fromHeader (atoms : Eff) (ts : List Benitoite.Release.TParam) (neffs : Nat)
    (ps : List Benitoite.Release.Ty) (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) : Except String Header := do
  return {
    tparams := ts.map (fun p => (p.equality, p.key))
    neffs := neffs
    params := ← ps.mapM (fromTy atoms)
    ret := ← fromTy atoms r
    eff := fromEff atoms e }

/-- 実装メソッドの頭は型クラス宣言から導く。上位辞書は実装ごとの一単位で比較する。 -/
def desugar (atoms : Eff) (entries : List OperatorEntry) (program : Benitoite.Surface.Program)
    (d : SurfaceDef) (constants : List (String × Benitoite.Surface.Expr))
    (table : List ConstantEntry) : Except String CoreDef := do
  let opPrim := makeOpPrim atoms entries
  let lambdaEffects := (d.body.lambdaEffects table).map (fun e => fromEff atoms e.toRelease)
  if let some name := d.implementation then
    let some id := program.impls name | throw s!"missing implementation: {name}"
    let some cl := program.classes id.cls | throw s!"missing class: {id.cls}"
    if let some m := d.method then
      let some ms := cl.methods m | throw s!"missing implementation method: {m}"
      let body ← d.body.toSurface constants
      let decl := { id with methods := fun n => if n == m then some body else none }
      let result := Benitoite.Surface.desugarImpl opPrim decl
      let some core := result.methods m | throw "missing desugared method"
      let header ← fromHeader atoms (ms.tparams ++ id.tparams) ms.neffs
        (ms.params.map (id.methTy ms)) (id.methTy ms ms.ret) ms.eff
      let surfaceHeader ← fromHeader atoms (← d.toSurface constants).tparams d.header.neffs
        ((← d.toSurface constants).dictTys ++ (← d.toSurface constants).params) (← d.header.ret.toRelease) d.header.eff.toRelease
      if canonicalJson atoms (toJson header) != canonicalJson atoms (toJson surfaceHeader) then
        throw s!"implementation method signature mismatch: {name}/{m}"
      return { header := header, body := ← fromComp atoms core, lambdaEffects := lambdaEffects, supers := [] }
    else
      if d.supers.map Prod.fst != cl.supers then throw "implementation supers do not match class declaration"
      let supers ← d.supers.mapM (fun (n,e) => do return (n, ← e.toSurface))
      let decl := { id with supers := fun n => (supers.find? (fun p => p.1 == n)).map Prod.snd }
      let result := Benitoite.Surface.desugarImpl opPrim decl
      let converted ← d.supers.mapM (fun (n,_) => do
        let some v := result.supers n | throw "missing desugared superclass"
        return (n, ← fromVal atoms v))
      let header ← fromHeader atoms result.tparams 0 [] (.base .unit) Benitoite.Release.Eff.empty
      return { header := header, body := .ret (.const .unit), lambdaEffects := [], supers := converted }
  else
    let result := Benitoite.Surface.desugarDef opPrim (← d.toSurface constants)
    return {
      header := ← fromHeader atoms result.tparams result.neffs result.params result.ret result.eff
      body := ← fromComp atoms result.body
      lambdaEffects := lambdaEffects
      supers := [] }
/-- Program.lookupFun と desugarProgram の経路を通して取得関数を比較する。 -/
def desugarAccessor (atoms : Eff) (entries : List OperatorEntry)
    (program : Benitoite.Surface.Program) (name con : String) (k : Nat)
    (decl : RecordConDecl) : Except String CoreDef := do
  let some (c, index) := program.accessors name | throw "missing accessor table entry"
  if c != con || index != k then throw "accessor table mismatch"
  let some cd := program.cons con | throw "missing record constructor"
  if cd.data != decl.data || cd.ntys != decl.ntys ||
      canonicalJson atoms (toJson (← cd.args.mapM (fromTy atoms))) !=
        canonicalJson atoms (toJson decl.args) then throw "record constructor table mismatch"
  let result := Benitoite.Surface.desugarProgram (makeOpPrim atoms entries) program
  let some d := result.defs name | throw "missing desugared accessor"
  return {
    header := ← fromHeader atoms d.tparams d.neffs d.params d.ret d.eff
    body := ← fromComp atoms d.body
    lambdaEffects := []
    supers := [] }
end Benitoite.Exchange
