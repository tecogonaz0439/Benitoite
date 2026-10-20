import Benitoite.Surface.CheckSupport
import Benitoite.Surface.BuilderCheck
import Benitoite.Surface.AdmissibleCheck
import Benitoite.Surface.SingleFailCheck

/-! 表層の型・エフェクトを構造的な再帰で計算する検査。
経路は外側から子の番号を積み、番号は 0 から数える。
式の子は元の構文での式・ブロック・並びの順に番号を付ける。
パイプの右辺も元の式の子を保つ（呼び出しの関数は [1, 0]）。
Exprs・HoleArgs・辞書引数は、並びの経路に平らな添字を一つ加える。
個数の不一致は並びの経路、要素の型の不一致はその要素の経路で報告する。
ブロックの式は 0、続きは 1。腕のガードは 0、本体は 1、続きは 2。
ハンドラの節の本体は 0、続きは 1。節の型の探索も同じ経路を使う。
die の子は入力 0・説明 1・Result の辞書 2 とする。
実装のメソッドは [0, i]、上位の所属検査は [1, i]、辞書は [2, i] とする。
全体の条件はその構文の経路、子の検査後の型・エフェクトの条件は子の経路で報告する。
handle の探索中は resume の引数のエフェクトを継続ごとの要求として保持する。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。
-/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

structure Input where
  D : Declarations
  B : Builtins
  satDec : SatDec
  admitsDec : AdmitsDec
  opPrim : OpPrim
  ctors : DataName → List ConName
  atoms : List Atom
  /-- 宣言の入口で計算し、本体の再帰では増やさない。 -/
  noFailRows : List Bool := []

inductive ResumeMode where
  | strict | relaxed
  deriving DecidableEq

structure Error where
  path : List Nat
  reason : String
  deriving Repr, DecidableEq

abbrev Result (α : Type) := Except Error α
abbrev Inferred := Ty × Eff

def child (path : List Nat) (i : Nat) : List Nat := path ++ [i]

def require (path : List Nat) (reason : String) (ok : Bool) : Result Unit :=
  if ok then pure () else throw ⟨path, reason⟩

def lookup (path : List Nat) (reason : String) (x : Option α)
    (valid : α → Bool := fun _ => true) : Result α :=
  match x with
  | some a => if valid a then pure a else throw ⟨path, "invalid checked input"⟩
  | none => throw ⟨path, reason⟩

/-- 入力の条件を分岐させても、渡された値や注釈を変換しない。 -/
def guardResult (path : List Nat) (inputOK : Bool) (x : Result α) : Result α :=
  if inputOK then x else throw ⟨path, "invalid checked input"⟩

def accept (q : Input) (n : Nat) (path : List Nat) (expected : Ty) (actual : Inferred) : Result Eff := do
  require path "type is not included in the expected type" ((cleanTy q.atoms n expected && tyLe q.atoms actual.1 expected) && singleTyCheck q.atoms q.noFailRows expected)
  pure actual.2

def acceptEff (q : Input) (path : List Nat) (expected actual : Eff) : Result Unit :=
  require path "effect exceeds the allowed effect" (effSub q.atoms actual expected && singleEffCheck q.atoms q.noFailRows expected)

def join (q : Input) (n : Nat) (path : List Nat) (a b : Ty) : Result Ty :=
  lookup path "branch types have no join" (tyJoin q.atoms a b) (fun t => cleanTy q.atoms n t && singleTyCheck q.atoms q.noFailRows t)

def fnView (path : List Nat) : Ty → Result (List String × List Ty × Ty × Eff)
  | .fn names ps r ε => pure (names, ps, r, ε)
  | _ => throw ⟨path, "expected a function type"⟩

def dictView (path : List Nat) : Ty → Result (ClassName × Ty)
  | .dict cl t => pure (cl, t)
  | _ => throw ⟨path, "expected a dictionary type"⟩

def remainingEffect (e : Eff) : Eff := .mk e.atoms []

def singleFailure (atoms : List Atom) (e : Ty) : Eff := .mk (fun _ => false) [e.normWith atoms]

def union (q : Input) (a b : Eff) : Eff := unionEff q.atoms a b

def substParams (atoms : List Atom) (ts : List Ty) (es : List Eff) (ps : List Ty) : List Ty :=
  substTysAt atoms 0 ts es ps

def fieldTypes (ps : List Ty) (positions : List Nat) : List Ty :=
  positions.map fun i => (ps[i]?).getD (.base .unit)

/-- 燃料を使い切ったら失敗する。成功の根拠は後の厳密な検査である。 -/
def fixedEffects (q : Input) (path : List Nat) (step : Eff → Result Eff) : Nat → Eff → Result Eff
  | 0, _ => throw ⟨path, "handler effect iteration exhausted its fuel"⟩
  | n + 1, ε => do
      let next ← step ε
      let ε' := union q ε next
      if effEq q.atoms ε ε' then pure ε else fixedEffects q path step n ε'

mutual
  def checkDict (q : Input) (C : List TParam) (Γ : List (Option Ty))
      (path : List Nat) (d : DictEv) : Result Ty :=
    guardResult path true <| match d with
    | .local j => do
        let a ← lookup path "dictionary local is missing or hidden" ((Γ[j]?).join) (fun _ => true)
        let _ ← dictView path a
        pure a
    | .clause scope i depth => do
        require path "clause dictionary scope mismatch"
          (decide (i < scope.dictCount) && decide (Γ.length = depth + 1 + scope.arity + scope.dictCount + scope.outer))
        let a ← lookup path "clause dictionary is missing" ((Γ[depth + scope.slot i]?).join)
        let _ ← dictView path a
        pure a
    | .impl i ts ds => do
        let id ← lookup path "unknown dictionary implementation" (q.D.impls i)
          (fun _ => true)
        require path "implementation type arguments fail constraints" (satAll q.satDec C ts id.tparams)
        checkDictsAt q C Γ (child path 0) 0 ds (substParams q.atoms ts [] id.dictTys)
        pure (.dict id.cls (substTy q.atoms ts [] id.target))
    | .super d s => do
        let (cl, t) ← dictView (child path 0) (← checkDict q C Γ (child path 0) d)
        let cd ← lookup path "unknown dictionary class" (q.D.classes cl)
        require path "class is not a superclass" (cd.supers.contains s)
        pure (.dict s t)

  def checkDictsAt (q : Input) (C : List TParam) (Γ : List (Option Ty))
      (path : List Nat) (index : Nat) : List DictEv → List Ty → Result Unit
    | [], [] => pure ()
    | d :: ds, a :: as => do
        let t ← checkDict q C Γ (child path index) d
        require (child path index) "dictionary type mismatch" (tyEq q.atoms t a)
        checkDictsAt q C Γ path (index + 1) ds as
    | _, _ => throw ⟨path, "dictionary argument count mismatch"⟩
end

def checkDicts (q : Input) (C : List TParam) (Γ : List (Option Ty))
    (path : List Nat) (ds : List DictEv) (ts : List Ty) : Result Unit :=
  guardResult path true
    (checkDictsAt q C Γ path 0 ds ts)

/-- 表示の対象型と、解決済みメソッドの純粋な String の契約を別々に検査する。 -/
def checkDieShow (q : Input) (C : List TParam) (Γ : List (Option Ty))
    (path : List Nat) (dict : DictEv) (method : MethName) (errorTy : Ty) : Result Unit := do
  let (cl, t) ← dictView path (← checkDict q C Γ path dict)
  require path "die dictionary target type mismatch" (tyEq q.atoms t errorTy)
  let cd ← lookup path "unknown die dictionary class" (q.D.classes cl)
  let ms ← lookup path "unknown die display method" (cd.methods method)
  require path "invalid die display method contract"
    (ms.tparams.isEmpty && (ms.neffs == 0) && (ms.names == ["x"]) &&
      tysEq q.atoms ms.params [.tvar 0] && tyEq q.atoms ms.ret (.base .string) &&
      effEq q.atoms ms.eff emptyEff)

/-- 通常の exit の具体化を確認し、原子集合から終了の効果が欠落した入力も拒否する。 -/
def checkDieExit (q : Input) (C : List TParam) (path : List Nat)
    (exit : PrimName) (t : Ty) : Result Unit := do
  let s ← lookup path "unknown die exit primitive" (q.B.sig exit)
    (fun _ => true)
  require path "invalid die exit primitive"
    (decide (s.kind = .exit) && (s.opEff == some "Process.Exit") &&
      (s.ntys == 1) && (s.neffs == 0) && namesWF s.names s.params)
  require path "die exit type arguments are not admitted" (q.admitsDec exit C [t])
  require path "Process.Exit effect is outside atoms" (q.atoms.contains (.name "Process.Exit"))
  require path "die exit type mismatch"
    (tyEq q.atoms (fnTyCheck q.atoms s.names s.params s.ret s.eff [t] [])
      (.fn ["code"] [.base .integer] t (singleEff q.atoms (.name "Process.Exit"))))

/-- 継続の番号は Γ の末尾から数えた束縛の位置 Γ.length - (k + 1)。
先頭への束縛追加で変わらない。節の継続は Γ.length + n であり、
入れ子の節の継続は外側のすべての束縛より大きな番号を持つ。
同じ handle の節どうしでは番号を共有してよい。要求はその handle の反復で消費する。 -/
abbrev Requests := List (Nat × Eff)

structure CheckState where
  requests : Requests := []
  strictConts : List Nat := []

/-- 状態を返す内部の検査。式のエフェクトと継続への要求を別々に保持する。 -/
abbrev Checking (α : Type) := StateT CheckState Result α

/-- 節の継続は、操作の引数を足した後の先頭に置く。 -/
def clauseKeys (base : Nat) : Clauses → List Nat
  | .nil => []
  | .cons _ n _ _ rest ndicts => (base + ndicts + n) :: clauseKeys base rest

def requestedEffect (q : Input) (keys : List Nat) (requests : Requests) : Eff :=
  requests.foldl (fun ε r => if keys.contains r.1 then union q ε r.2 else ε) emptyEff

def fixedEffectsR (q : Input) (path : List Nat) (step : Eff → Checking Eff) :
    Nat → Eff → Checking Eff
  | 0, _ => throw ⟨path, "handler effect iteration exhausted its fuel"⟩
  | n + 1, ε => do
      let next ← step ε
      let ε' := union q ε next
      if effEq q.atoms ε ε' then pure ε else fixedEffectsR q path step n ε'

/-- 元の計算をそのまま検査し、注釈と結果の型は書き換えない。 -/
def guardInferred (q : Input) (path : List Nat) (x : Checking Inferred)
    (inputOK : Bool := true) : Checking Inferred :=
  if inputOK then do
    let result ← x
    require path "multiple Fail types or an unrestricted row at a Fail position"
      (singleTyCheck q.atoms q.noFailRows result.1 && singleEffCheck q.atoms q.noFailRows result.2)
    pure result
  else throw ⟨path, "invalid input annotations or environment"⟩

mutual
  def checkExprR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (p : Position) (path : List Nat) (e : Expr) : Checking Inferred :=
    guardInferred q path (match e with
    | .builderOp o i args k => do
        require path "invalid local builder kind"
          (match Δ.kindAt i with
           | none => false
           | some actual => tyEq q.atoms actual.contents k.contents)
        let ε ← checkTypesR q mode Δ C Γ R (child path 0) 0 args (o.params k)
        pure (o.result k, ε)
    | .local i => do
        let a ← lookup path "local is missing or hidden" ((Γ[i]?).join)
        require path "continuations cannot be used as ordinary locals" (notCont a)
        pure (a, emptyEff)
    | .constE a body => do
        let ε ← accept q C.length (child path 0) a (← checkExprR q mode [] C [] R .other (child path 0) body)
        acceptEff q (child path 0) emptyEff ε
        pure (a, emptyEff)
    | .funName f ts es => do
        let d ← lookup path "unknown function" (q.D.funs f)
          (fun _ => true)
        require path "function contract names are not well formed" (namesWF d.names d.params)
        require path "function core names are not well formed" (namesWF d.coreNames (d.dictTys ++ d.params))
        require path "function type arguments fail constraints" (satAll q.satDec C ts d.tparams)
        require path "function effect argument count mismatch" (es.length == d.neffs)
        require path "function needs dictionaries" d.dictParams.isEmpty
        require path "function instantiation violates scope or NoFail"
          (instantiationCheck q.atoms q.noFailRows C.length d.neffs (d.dictTys ++ d.params) d.ret d.eff ts es)
        pure (fnTyCheck q.atoms d.names d.params d.ret d.eff ts es, emptyEff)
    | .funDicts f ts es ds names ps => do
        let d ← lookup path "unknown function" (q.D.funs f)
          (fun _ => true)
        require path "function contract names are not well formed" (namesWF d.names d.params)
        require path "function core names are not well formed" (namesWF d.coreNames (d.dictTys ++ d.params))
        require path "function type arguments fail constraints" (satAll q.satDec C ts d.tparams)
        require path "function effect argument count mismatch" (es.length == d.neffs)
        require path "function does not take dictionaries" (nonemptyList d.dictParams)
        require path "function contract annotation mismatch" (names == d.names)
        require path "function parameter annotation mismatch" (tysEq q.atoms ps (substParams q.atoms ts es d.params))
        checkDicts q C Γ (child path 0) ds (substParams q.atoms ts [] d.dictTys)
        require path "function instantiation violates scope or NoFail"
          (instantiationCheck q.atoms q.noFailRows C.length d.neffs (d.dictTys ++ d.params) d.ret d.eff ts es)
        pure (fnTyCheck q.atoms d.names d.params d.ret d.eff ts es, emptyEff)
    | .methName d m ts es ds names ps => do
        let (cl, τ) ← dictView (child path 0) (← checkDict q C Γ (child path 0) d)
        let cd ← lookup path "unknown class" (q.D.classes cl)
        let ms ← lookup path "unknown method" (cd.methods m)
          (fun _ => true)
        require path "method contract names are not well formed" (namesWF ms.names ms.params)
        require path "method contract annotation mismatch" (names == ms.names.drop ds.length)
        require path "method type arguments fail constraints" (satAll q.satDec C ts ms.tparams)
        require path "method effect argument count mismatch" (es.length == ms.neffs)
        let params := substParams q.atoms (ts ++ [τ]) es ms.params
        checkDicts q C Γ (child path 1) ds (params.take ds.length)
        require path "method parameter annotation mismatch" (tysEq q.atoms ps (params.drop ds.length))
        require path "method still has dictionary parameters" (headNotDict ps)
        require path "method instantiation violates scope or NoFail"
          (instantiationCheck q.atoms q.noFailRows C.length ms.neffs ms.params ms.ret ms.eff (ts ++ [τ]) es)
        pure (.fn names ps (substTy q.atoms (ts ++ [τ]) es ms.ret) (substEffAt q.atoms 0 (ts ++ [τ]) es ms.eff), emptyEff)
    | .primName b ts es => do
        let s ← lookup path "unknown primitive" (q.B.sig b)
          (fun _ => true)
        require path "primitive contract names are not well formed" (namesWF s.names s.params)
        require path "primitive type argument count mismatch" (ts.length == s.ntys)
        require path "primitive effect argument count mismatch" (es.length == s.neffs)
        require path "primitive type arguments are not admitted" (q.admitsDec b C ts)
        require path "primitive instantiation violates scope or NoFail"
          (instantiationCheck q.atoms q.noFailRows C.length s.neffs s.params s.ret s.eff ts es)
        pure (fnTyCheck q.atoms s.names s.params s.ret s.eff ts es, emptyEff)
    | .raise t e => do
        require path "Fail.raise types are not well formed" (wfTy q.atoms C.length t && wfTy q.atoms C.length e)
        pure (.fn ["error"] [e] t (singleFailure q.atoms e), emptyEff)
    | .handleFail E t body clause => do
        require path "Fail handler types are not well formed" (cleanTy q.atoms C.length E && cleanTy q.atoms C.length t)
        let eb ← accept q C.length (child path 0) t (← checkBlockR q mode Δ C Γ R .other (child path 0) body)
        let rest := remainingEffect eb
        require path "Fail handler remainder violates NoFail" (noFailCheck q.atoms q.noFailRows rest)
        acceptEff q path (union q (singleFailure q.atoms E) rest) eb
        let env := none :: some (shiftTy q.atoms 1 0 E) :: Γ.map (Option.map (shiftTy q.atoms 1 0))
        let eh ← accept q (C.length + 1) (child path 1) (shiftTy q.atoms 1 0 t)
          (← checkBlockR q mode [] (({} : TParam) :: C) env (R.map (shiftTy q.atoms 1 0)) .other (child path 1) clause)
        let ec := substEffAt q.atoms 0 [.base .unit] [] eh
        require path "Fail clause effect mentions its rigid result type"
          (wfTys q.atoms C.length ec.fails && effEq q.atoms (shiftEff q.atoms 1 0 ec) eh)
        pure (t, union q rest ec)
    | .opName o ts => do
        let od ← lookup path "unknown operation" (q.D.ops o)
          (fun _ => true)
        require path "operation contract names are not well formed" (namesWF od.names od.params)
        require path "operation type arguments fail constraints" (satAll q.satDec C ts od.tparams)
        require path "operation needs dictionaries" od.dictParams.isEmpty
        require path "operation effect is outside atoms" (q.atoms.contains (.name od.eff))
        pure (fnTyCheck q.atoms od.names od.params od.ret (singleEff q.atoms (.name od.eff)) ts [], emptyEff)
    | .opDicts o ts ds names ps => do
        let od ← lookup path "unknown operation" (q.D.ops o)
        require path "operation contract names are not well formed" (namesWF od.names od.params)
        require path "operation public names are not well formed" (namesWF od.valueNames od.valueParams)
        require path "operation type arguments fail constraints" (satAll q.satDec C ts od.tparams)
        require path "operation dictionary prefix mismatch" (tysEq q.atoms od.params (od.dictTys ++ od.valueParams))
        require path "operation internal names mismatch" (od.names == internalNames ds.length ++ od.valueNames)
        require path "operation contract annotation mismatch" (names == od.valueNames)
        require path "operation parameter annotation mismatch" (tysEq q.atoms ps (substParams q.atoms ts [] od.valueParams))
        checkDicts q C Γ (child path 0) ds (substParams q.atoms ts [] od.dictTys)
        require path "operation effect is outside atoms" (q.atoms.contains (.name od.eff))
        pure (fnTyCheck q.atoms od.valueNames od.valueParams od.ret (singleEff q.atoms (.name od.eff)) ts [], emptyEff)
    | .nullCon c ts => do
        let cd ← lookup path "unknown constructor" (q.D.cons c)
          (fun _ => true)
        require path "constructor type argument count mismatch" (ts.length == cd.ntys)
        require path "constructor takes arguments" cd.args.isEmpty
        pure (.data cd.data ts, emptyEff)
    | .conValue c ts names ps => do
        let cd ← lookup path "unknown constructor" (q.D.cons c)
          (fun _ => true)
        require path "constructor type argument count mismatch" (ts.length == cd.ntys)
        require path "constructor contract annotation mismatch" (names == q.D.constructorNames c cd)
        require path "constructor contract names are not well formed" (namesWF names ps)
        require path "constructor parameter annotation mismatch" (tysEq q.atoms ps (substParams q.atoms ts [] cd.args))
        require path "nullary constructor is not a function" (nonemptyList ps)
        pure (.fn names ps (.data cd.data ts) emptyEff, emptyEff)
    | .literal l => pure (l.toConst.type, emptyEff)
    | .negInt _ => pure (.base .integer, emptyEff)
    | .negFloat _ => pure (.base .float, emptyEff)
    | .negDecimal _ _ => pure (.base .decimal, emptyEff)
    | .negInteger8 _ => pure (.base .integer8, emptyEff)
    | .negInteger16 _ => pure (.base .integer16, emptyEff)
    | .negInteger32 _ => pure (.base .integer32, emptyEff)
    | .negFloat32 _ => pure (.base .float32, emptyEff)
    | .unit => pure (.base .unit, emptyEff)
    | .paren e => checkExprR q mode Δ C Γ R p (child path 0) e
    | .block body => checkBlockR q mode Δ C Γ R p (child path 0) body
    | .conCall c ts args => do
        let cd ← lookup path "unknown constructor" (q.D.cons c)
          (fun _ => true)
        require path "constructor type argument count mismatch" (ts.length == cd.ntys)
        let ε ← checkTypesR q mode Δ C Γ R (child path 0) 0 args (substParams q.atoms ts [] cd.args)
        pure (.data cd.data ts, ε)
    | .record c ts positions args => do
        let cd ← lookup path "unknown record constructor" (q.D.cons c)
          (fun _ => true)
        require path "record type argument count mismatch" (ts.length == cd.ntys)
        require path "record fields are not a permutation" (natPerm positions (List.range cd.args.length))
        let ε ← checkTypesR q mode Δ C Γ R (child path 0) 0 args (fieldTypes (substParams q.atoms ts [] cd.args) positions)
        pure (.data cd.data ts, ε)
    | .recordUpdate c ts n positions base args => do
        let cd ← lookup path "unknown record constructor" (q.D.cons c)
          (fun _ => true)
        require path "record type argument count mismatch" (ts.length == cd.ntys)
        require path "record field count mismatch" (n == cd.args.length)
        require path "record update is empty" (nonemptyList positions)
        require path "record update has duplicate fields" (natNodup positions)
        require path "record field is outside the record" (positionsInRange positions n)
        let a := Ty.data cd.data ts
        let εb ← accept q C.length (child path 0) a (← checkExprR q mode Δ C Γ R .other (child path 0) base)
        let εa ← checkTypesR q mode Δ C Γ R (child path 1) 0 args (fieldTypes (substParams q.atoms ts [] cd.args) positions)
        require path "record update pattern is not exhaustive"
          (recordUpdateExhaustive q.D q.ctors cd ts c n positions)
        pure (a, union q εb εa)
    | .call f labels positions args => do
        let (a, εf) ← checkExprR q mode Δ C Γ R .other (child path 0) f
        let (names, ps, r, εcall) ← fnView (child path 0) a
        require path "call labels and positions do not match the contract" (callOk names ps false labels positions)
        let εargs ← checkTypesR q mode Δ C Γ R (child path 1) 0 args (sourceTypes ps positions)
        pure (r, union q εf (union q εargs εcall))
    | .pipe lhs rhs =>
        match rhs with
        | .call f labels positions args => do
            let (a, εf) ← checkExprR q mode Δ C Γ R .other (child (child path 1) 0) f
            let (names, params, r, εcall) ← fnView (child (child path 1) 0) a
            let t ← lookup (child (child path 1) 0) "pipe call has no first parameter" params.head?
            let εl ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) lhs)
            require (child path 1) "pipe labels and positions do not match the contract" (callOk names params true labels positions)
            let εargs ← checkTypesR q mode Δ C Γ R (child (child path 1) 1) 0 args (sourceTypes params positions)
            pure (r, union q εl (union q εf (union q εargs εcall)))
        | .conCall c ts args => do
            let cd ← lookup (child path 1) "unknown pipe constructor" (q.D.cons c)
              (fun _ => true)
            require (child path 1) "constructor type argument count mismatch" (ts.length == cd.ntys)
            let ps := substParams q.atoms ts [] cd.args
            let t ← lookup (child path 1) "pipe constructor has no first parameter" ps.head?
            let εl ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) lhs)
            let εargs ← checkTypesR q mode Δ C Γ R (child (child path 1) 0) 0 args ps.tail
            pure (.data cd.data ts, union q εl εargs)
        | .conValue c ts names ps => do
            let cd ← lookup (child path 1) "unknown pipe constructor" (q.D.cons c)
              (fun _ => true)
            require (child path 1) "constructor type argument count mismatch" (ts.length == cd.ntys)
            require (child path 1) "constructor contract annotation mismatch" (names == q.D.constructorNames c cd)
            require (child path 1) "constructor contract names are not well formed" (namesWF names ps)
            require (child path 1) "constructor parameter annotation mismatch" (tysEq q.atoms ps (substParams q.atoms ts [] cd.args))
            require (child path 1) "bare pipe constructor must be unary" (ps.length == 1)
            let t ← lookup (child path 1) "pipe constructor has no parameter" ps.head?
            let εl ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) lhs)
            pure (.data cd.data ts, εl)
        | rhs => do
            require (child path 1) "invalid pipe value" (pipeValue rhs)
            let (a, εf) ← checkExprR q mode Δ C Γ R .other (child path 1) rhs
            let (names, ps, r, εcall) ← fnView (child path 1) a
            require (child path 1) "pipe value must have one parameter and one name"
              ((ps.length == 1) && (names.length == 1))
            let t ← lookup (child path 1) "pipe value has no parameter" ps.head?
            let εl ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) lhs)
            pure (r, union q εl (union q εf εcall))
    | .partialCall f names args r ε => do
        require path "partial call has no holes" (nonemptyList args.holeTypes)
        let (a, εf) ← checkExprR q mode [] C (hideConts Γ) (some r) .other (child path 0) f
        let (calleeNames, ps, r0, εcall) ← fnView (child path 0) a
        require path "partial call contract annotation mismatch" (names == calleeNames)
        require path "partial call labels and positions do not match the contract"
          (callOk names ps false args.labels args.positions)
        require path "partial call hole names are not well formed" (namesWF (args.holeNames names) args.holeTypes)
        let εargs ← checkHoleArgsR q mode [] C (hideConts Γ) (some r) (child path 1) 0 args (sourceTypes ps args.positions)
        require path "partial call result type mismatch" (tyLe q.atoms r0 r)
        acceptEff q path ε (union q εf (union q εargs εcall))
        pure (.fn (args.holeNames names) args.holeTypes r ε, emptyEff)
    | .partialCon c ts args => do
        let cd ← lookup path "unknown partial constructor" (q.D.cons c)
          (fun _ => true)
        require path "constructor type argument count mismatch" (ts.length == cd.ntys)
        require path "partial constructor has no holes" (nonemptyList args.holeTypes)
        require path "partial constructor labels or positions are invalid" (constructorHolesOk args cd.args.length)
        require path "record construction cannot contain holes" (q.D.conFields c).isNone
        let names := args.holeNames (positionalNames args.positions.length)
        require path "partial constructor hole names are not well formed" (namesWF names args.holeTypes)
        let r := Ty.data cd.data ts
        let εargs ← checkHoleArgsR q mode [] C (hideConts Γ) (some r) (child path 0) 0 args (substParams q.atoms ts [] cd.args)
        require path "partial constructor effect is not well formed" (cleanTys q.atoms C.length εargs.fails)
        pure (.fn names args.holeTypes r (Eff.normWith q.atoms εargs), emptyEff)
    | .binary o t lhs rhs => do
        require path "binary operator type is not allowed" ((Operator.binary o).allowed t)
        let (b, ts) ← lookup path "operator has no primitive" (q.opPrim (.binary o) t)
        let s ← lookup path "unknown operator primitive" (q.B.sig b)
          (fun _ => true)
        require path "operator type argument count mismatch" (ts.length == s.ntys)
        require path "operator takes effect arguments" (s.neffs == 0)
        require path "operator type arguments are not admitted" (q.admitsDec b C ts)
        let (names, ps, r, ε) ← fnView path (fnTyCheck q.atoms s.names s.params s.ret s.eff ts [])
        require path "binary operator parameter names mismatch" (names == ["left", "right"])
        require path "binary operator parameter types mismatch" (tysEq q.atoms ps [t, t])
        acceptEff q path emptyEff ε
        let εl ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) lhs)
        let εr ← accept q C.length (child path 1) t (← checkExprR q mode Δ C Γ R .other (child path 1) rhs)
        pure (r, union q εl εr)
    | .neg t e => do
        require path "negation type is not allowed" (Operator.neg.allowed t)
        let (b, ts) ← lookup path "negation has no primitive" (q.opPrim .neg t)
        require path "negation has type arguments" ts.isEmpty
        let s ← lookup path "unknown negation primitive" (q.B.sig b)
          (fun _ => true)
        require path "negation type argument count mismatch" (ts.length == s.ntys)
        require path "negation takes effect arguments" (s.neffs == 0)
        require path "negation type arguments are not admitted" (q.admitsDec b C ts)
        require path "negation primitive type mismatch"
          (tyEq q.atoms (fnTyCheck q.atoms s.names s.params s.ret s.eff ts []) (.fn ["value"] [t] t emptyEff))
        let ε ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        pure (t, ε)
    | .not e => do
        let ε ← accept q C.length (child path 0) (.base .boolean) (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        pure (.base .boolean, ε)
    | .and lhs rhs | .or lhs rhs => do
        let εl ← accept q C.length (child path 0) (.base .boolean) (← checkExprR q mode Δ C Γ R .other (child path 0) lhs)
        let εr ← accept q C.length (child path 1) (.base .boolean) (← checkExprR q mode Δ C Γ R p (child path 1) rhs)
        pure (.base .boolean, union q εl εr)
    | .list a es => do
        require path "list element type is not well formed" (wfTy q.atoms C.length a)
        let ε ← checkEachR q mode Δ C Γ R (child path 0) 0 es a
        pure (.list a, ε)
    | .listSpread a f before spread after => do
        require path "list element type is not well formed" (wfTy q.atoms C.length a)
        require (child path 0) "list concatenation is not a direct callee" (isDirect f)
        let εf ← accept q C.length (child path 0) (.fn ["xs", "ys"] [.list a, .list a] (.list a) emptyEff)
          (← checkExprR q mode Δ C Γ R .other (child path 0) f)
        acceptEff q (child path 0) emptyEff εf
        let εb ← checkEachR q mode Δ C Γ R (child path 1) 0 before a
        let εs ← accept q C.length (child path 2) (.list a) (← checkExprR q mode Δ C Γ R .other (child path 2) spread)
        let εa ← checkEachR q mode Δ C Γ R (child path 3) 0 after a
        pure (.list a, union q εb (union q εs εa))
    | .interpolation parts es fs => do
        require path "interpolation type is not allowed" (interpAllowed parts)
        let ε ← checkTypesR q mode Δ C Γ R (child path 0) 0 es (InterpPart.exprTypes parts)
        let εf ← checkTypesR q mode Δ C Γ R (child path 1) 0 fs (InterpPart.converterTypes parts)
        acceptEff q (child path 1) emptyEff εf
        require (child path 1) "interpolation converter is not a direct callee" (allDirect fs)
        require path "interpolation string addition is invalid"
          (decide (InterpPart.count parts < 2) || stringAddOk q.atoms q.B q.opPrim q.admitsDec C)
        pure (.base .string, ε)
    | .lam names ps r ε body => do
        require path "lambda contract names are not well formed" (namesWF names ps)
        require path "lambda body does not exit" (lamBodyOk body r)
        let εb ← accept q C.length (child path 0) r
          (← checkBlockR q mode [] C (binds ps ++ hideConts Γ) (some r) .tail (child path 0) body)
        acceptEff q (child path 0) ε εb
        pure (.fn names ps r ε, emptyEff)
    | .ite cond yes no => do
        let εc ← accept q C.length (child path 0) (.base .boolean) (← checkExprR q mode Δ C Γ R .other (child path 0) cond)
        let (ay, εy) ← checkBlockR q mode Δ C Γ R p (child path 1) yes
        let (an, εn) ← checkBlockR q mode Δ C Γ R p (child path 2) no
        let a ← join q C.length path ay an
        pure (a, union q εc (union q εy εn))
    | .elseIf cond yes no => do
        require (child path 2) "else-if continuation is not an if" (isIf no)
        let εc ← accept q C.length (child path 0) (.base .boolean) (← checkExprR q mode Δ C Γ R .other (child path 0) cond)
        let (ay, εy) ← checkBlockR q mode Δ C Γ R p (child path 1) yes
        let (an, εn) ← checkExprR q mode Δ C Γ R p (child path 2) no
        let a ← join q C.length path ay an
        pure (a, union q εc (union q εy εn))
    | .ifOnly cond yes => do
        let εc ← accept q C.length (child path 0) (.base .boolean) (← checkExprR q mode Δ C Γ R .other (child path 0) cond)
        let εy ← accept q C.length (child path 1) (.base .unit) (← checkBlockR q mode Δ C Γ R p (child path 1) yes)
        pure (.base .unit, union q εc εy)
    | .matchE b e arms => do
        require path "match has no arms" (nonemptyArms arms)
        let (a, εe) ← checkExprR q mode Δ C Γ R .other (child path 0) e
        let εarms ← checkArmsR q mode Δ C Γ R p (child path 1) arms a b
        require path "match is not exhaustive" (matchExhaustive q.D q.ctors a arms)
        pure (b, union q εe εarms)
    | .returnE a e => do
        let r ← lookup path "return is outside a function" R
        match p with
        | .tail =>
            let ε ← accept q C.length (child path 0) r (← checkExprR q mode Δ C Γ (some r) .tail (child path 0) e)
            pure (r, ε)
        | .other =>
            require path "return annotation is not well formed" (wfTy q.atoms C.length a)
            let ε ← accept q C.length (child path 0) r (← checkExprR q mode Δ C Γ (some r) .other (child path 0) e)
            pure (a, ε)
    | .tryResult retArgs ok err e => do
        let cdo ← lookup path "unknown Result success constructor" (q.D.cons ok)
        let cde ← lookup path "unknown Result error constructor" (q.D.cons err)
        require path "invalid Result constructors"
          ((cdo.ntys == 2) && (cde.ntys == 2) && tysEq q.atoms cdo.args [.tvar 0] &&
            tysEq q.atoms cde.args [.tvar 1] && (cdo.data == cde.data))
        require path "Result return argument count mismatch" (retArgs.length == 2)
        let r ← lookup path "try is outside a function" R
        require path "Result return type mismatch" (tyEq q.atoms r (.data cdo.data retArgs))
        let errTy := (retArgs[1]?).getD (.base .unit)
        let (a, ε) ← checkExprR q mode Δ C Γ R .other (child path 0) e
        match a with
        | .data d [t, e'] =>
            require (child path 0) "Result input type mismatch" ((d == cdo.data) && tyEq q.atoms e' errTy)
            require path "Result try is not exhaustive" (tryResultExhaustive q.D q.ctors d t e' ok err)
            pure (t, ε)
        | _ => throw ⟨child path 0, "try input is not a Result"⟩
    | .tryOption retArgs someCon noneCon e => do
        let cds ← lookup path "unknown Option success constructor" (q.D.cons someCon)
        let cdn ← lookup path "unknown Option empty constructor" (q.D.cons noneCon)
        require path "invalid Option constructors"
          ((cds.ntys == 1) && (cdn.ntys == 1) && tysEq q.atoms cds.args [.tvar 0] &&
            cdn.args.isEmpty && (cds.data == cdn.data))
        require path "Option return argument count mismatch" (retArgs.length == 1)
        let r ← lookup path "try is outside a function" R
        require path "Option return type mismatch" (tyEq q.atoms r (.data cds.data retArgs))
        let (a, ε) ← checkExprR q mode Δ C Γ R .other (child path 0) e
        match a with
        | .data d [t] =>
            require (child path 0) "Option input type mismatch" (d == cds.data)
            require path "Option try is not exhaustive" (tryOptionExhaustive q.D q.ctors d t someCon noneCon)
            pure (t, ε)
        | _ => throw ⟨child path 0, "try input is not an Option"⟩
    | .tryResultDie t ok err dict method exit e message => do
        let cdo ← lookup path "unknown Result success constructor" (q.D.cons ok)
        let cde ← lookup path "unknown Result error constructor" (q.D.cons err)
        require path "invalid Result constructors"
          ((cdo.ntys == 2) && (cde.ntys == 2) && tysEq q.atoms cdo.args [.tvar 0] &&
            tysEq q.atoms cde.args [.tvar 1] && (cdo.data == cde.data))
        let (a, ε) ← checkExprR q mode Δ C Γ R .other (child path 0) e
        match a with
        | .data d [actual, et] =>
            require (child path 0) "Result die input type mismatch"
              ((d == cdo.data) && tyEq q.atoms actual t)
            require path "Result try is not exhaustive" (tryResultExhaustive q.D q.ctors d t et ok err)
            checkDieShow q C Γ (child path 2) dict method et
            checkDieExit q C path exit t
            checkDieMessageR q mode Δ C Γ (child path 1) message
            pure (t, union q ε (singleEff q.atoms (.name "Process.Exit")))
        | _ => throw ⟨child path 0, "try input is not a Result"⟩
    | .tryOptionDie t someCon noneCon exit e message => do
        let cds ← lookup path "unknown Option success constructor" (q.D.cons someCon)
        let cdn ← lookup path "unknown Option empty constructor" (q.D.cons noneCon)
        require path "invalid Option constructors"
          ((cds.ntys == 1) && (cdn.ntys == 1) && tysEq q.atoms cds.args [.tvar 0] &&
            cdn.args.isEmpty && (cds.data == cdn.data))
        let (a, ε) ← checkExprR q mode Δ C Γ R .other (child path 0) e
        match a with
        | .data d [actual] =>
            require (child path 0) "Option die input type mismatch"
              ((d == cds.data) && tyEq q.atoms actual t)
            require path "Option try is not exhaustive" (tryOptionExhaustive q.D q.ctors d t someCon noneCon)
            checkDieExit q C path exit t
            checkDieMessageR q mode Δ C Γ (child path 1) message
            pure (t, union q ε (singleEff q.atoms (.name "Process.Exit")))
        | _ => throw ⟨child path 0, "try input is not an Option"⟩
    | .withE o e body => do
        require path "with type is not a resource" (q.B.isResource o)
        require path "State effect is outside atoms" (q.atoms.contains (.name stateEff))
        let εe ← accept q C.length (child path 0) (.opaque o) (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        let (a, εb) ← checkBlockR q mode (none :: Δ) C (some (.opaque o) :: Γ) R .other (child path 1) body
        pure (a, union q εe (union q εb (singleEff q.atoms (.name stateEff))))
    | .lazyE body => do
        let (a, ε) ← checkBlockR q mode [] C (hideConts Γ) none .other (child path 0) body
        acceptEff q (child path 0) emptyEff ε
        pure (.lazy a, emptyEff)
    | .handleE body cs => do
        let (t0, εbody) ← checkBlockR q mode Δ C Γ R .other (child path 0) body
        let h := handled q.D.patternProgram q.B cs.skeleton
        let initial := diffEff q.atoms εbody h
        -- 型の探索で生じた要求は捨て、確定した型での反復で集め直す。
        let (t, _) ← (inferClauseTypesR q Δ C Γ R (child path 1) cs t0 initial).run {}
        let keys := clauseKeys Γ.length cs
        let ε ← fixedEffectsR q path
          (fun ε => do
            let (actual, st) ← (checkClausesR q .relaxed Δ C Γ R (child path 1) cs t ε).run {}
            modify fun outer => { outer with requests :=
              outer.requests ++ st.requests.filter (fun r => !keys.contains r.1) }
            pure (union q actual (requestedEffect q keys st.requests)))
          (q.atoms.length + 1) initial
        -- 自分の継続は厳密に検査し、外側の継続には外側の印を使う。
        let saved := (← get).strictConts
        modify fun st => { st with strictConts := keys ++ saved }
        let _ ← checkClausesR q mode Δ C Γ R (child path 1) cs t ε
        modify fun st => { st with strictConts := saved }
        require (child path 0) "handler body result type mismatch" (cleanTy q.atoms C.length t && tyLe q.atoms t0 t)
        acceptEff q (child path 0) (union q ε h) εbody
        pure (t, ε)
    | .resume k e => do
        let a ← lookup path "continuation is missing or hidden" ((Γ[k]?).join)
        match a with
        | .cont b t ε =>
            let εarg ← accept q C.length (child path 0) b (← checkExprR q mode Δ C Γ R .other (child path 0) e)
            let key := Γ.length - (k + 1)
            if mode == .strict || (← get).strictConts.contains key then
              acceptEff q (child path 0) ε εarg
            else
              modify fun st => { st with requests := (key, εarg) :: st.requests }
            pure (t, ε)
        | _ => throw ⟨path, "resume local is not a continuation"⟩) true

  def checkBlockR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (p : Position) (path : List Nat) (body : Block) : Checking Inferred :=
    guardInferred q path (match body with
    | .builderBind k rest => do
        require path "invalid builder content type" (cleanTy q.atoms C.length k.contents && singleTyCheck q.atoms q.noFailRows k.contents)
        checkBlockR q mode (some k :: Δ) C (none :: Γ) R p (child path 0) rest
    | .empty => pure (.base .unit, emptyEff)
    | .last e => checkExprR q mode Δ C Γ R p (child path 0) e
    | .lastBind _ t e => do
        let ε ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        pure (.base .unit, ε)
    | .lastDiscard e => do
        let (_, ε) ← checkExprR q mode Δ C Γ R .other (child path 0) e
        pure (.base .unit, ε)
    | .bind _ t e rest => do
        let ε ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        let (a, εs) ← checkBlockR q mode (none :: Δ) C (some t :: Γ) R p (child path 1) rest
        pure (a, union q ε εs)
    | .discard e rest => do
        let (_, ε) ← checkExprR q mode Δ C Γ R .other (child path 0) e
        let (a, εs) ← checkBlockR q mode Δ C Γ R p (child path 1) rest
        pure (a, union q ε εs)
    | .seq e rest => do
        let ε ← accept q C.length (child path 0) (.base .unit) (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        require (child path 0) "expression before another statement always exits" (!exprExits e)
        let (a, εs) ← checkBlockR q mode Δ C Γ R p (child path 1) rest
        pure (a, union q ε εs)
    | .lastPat _ pat t e => do
        require path "binding pattern is trivial or invalid" (nontrivial pat && patternValid pat)
        let _ ← lookup path "binding pattern type mismatch" (surfacePatTy q.atoms q.D pat t)
        require path "binding pattern is not exhaustive" (bindingExhaustive q.D q.ctors t pat)
        let ε ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        pure (.base .unit, ε)
    | .bindPat _ pat t e rest => do
        require path "binding pattern is trivial or invalid" (nontrivial pat && patternValid pat)
        let δ ← lookup path "binding pattern type mismatch" (surfacePatTy q.atoms q.D pat t)
        require path "binding pattern is not exhaustive" (bindingExhaustive q.D q.ctors t pat)
        let ε ← accept q C.length (child path 0) t (← checkExprR q mode Δ C Γ R .other (child path 0) e)
        let (a, εs) ← checkBlockR q mode (List.replicate δ.length none ++ Δ) C (binds δ ++ Γ) R p (child path 1) rest
        pure (a, union q ε εs)) true

  /-- 説明は外側の return と継続を隠す。内側の lambda は通常の境界を作る。 -/
  def checkDieMessageR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam)
      (Γ : List (Option Ty)) (path : List Nat) : Option Expr → Checking Unit
    | none => pure ()
    | some message => do
        let ε ← accept q C.length path (.base .string)
          (← checkExprR q mode Δ C (hideConts Γ) none .other path message)
        acceptEff q path emptyEff ε

  def checkTypesR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (path : List Nat) (index : Nat) : Exprs → List Ty → Checking Eff
    | .nil, [] => pure emptyEff
    | .cons e es, a :: as => do
        let ε ← accept q C.length (child path index) a (← checkExprR q mode Δ C Γ R .other (child path index) e)
        let εs ← checkTypesR q mode Δ C Γ R path (index + 1) es as
        pure (union q ε εs)
    | _, _ => throw ⟨path, "argument count mismatch"⟩

  def checkEachR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (path : List Nat) (index : Nat) : Exprs → Ty → Checking Eff
    | .nil, _ => pure emptyEff
    | .cons e es, a => do
        let ε ← accept q C.length (child path index) a (← checkExprR q mode Δ C Γ R .other (child path index) e)
        let εs ← checkEachR q mode Δ C Γ R path (index + 1) es a
        pure (union q ε εs)

  def checkHoleArgsR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (path : List Nat) (index : Nat) : HoleArgs → List Ty → Checking Eff
    | .nil, [] => pure emptyEff
    | .expr _ _ e args, a :: as => do
        let ε ← accept q C.length (child path index) a (← checkExprR q mode Δ C Γ R .other (child path index) e)
        let εs ← checkHoleArgsR q mode Δ C Γ R path (index + 1) args as
        pure (union q ε εs)
    | .hole _ _ t args, a :: as => do
        require (child path index) "hole annotation type mismatch" (cleanTy q.atoms C.length a && tyLe q.atoms t a)
        checkHoleArgsR q mode Δ C Γ R path (index + 1) args as
    | _, _ => throw ⟨path, "hole argument count mismatch"⟩

  def checkArmsR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (p : Position) (path : List Nat) : Arms → Ty → Ty → Checking Eff
    | .nil, _, b => do
        require path "match result type is not well formed" (wfTy q.atoms C.length b)
        pure emptyEff
    | .cons alts guard body rest, a, b => do
        require path "match alternative is invalid" (alternativesValid alts)
        let δ ← lookup path "match alternatives have inconsistent bindings"
          (altsTy q.atoms q.D.patternProgram (Alternative.toCoreList alts) a)
        let env := binds δ ++ Γ
        match guard with
        | none => pure ()
        | some g =>
            let εg ← accept q C.length (child path 0) (.base .boolean)
              (← checkExprR q mode (List.replicate δ.length none ++ Δ) C (hideConts env) none .other (child path 0) g)
            acceptEff q (child path 0) emptyEff εg
        let ε ← accept q C.length (child path 1) b (← checkBlockR q mode (List.replicate δ.length none ++ Δ) C env R p (child path 1) body)
        let εs ← checkArmsR q mode Δ C Γ R p (child path 2) rest a b
        pure (union q ε εs)

  def checkClausesR (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (path : List Nat) : Clauses → Ty → Eff → Checking Eff
    | .nil, _, _ => pure emptyEff
    | .cons o n ntys body rest ndicts, t, ε => do
        let sg ← lookup path "unknown handler operation" (opSig q.D.patternProgram q.B o)
          (fun _ => wfTys q.atoms C.length ε.fails)
        require path "handler operation names are not well formed" (namesWF sg.names sg.params)
        require path "handler operation arity mismatch" ((ndicts == opDictCount q.D.patternProgram o) && (ndicts + n == sg.params.length))
        require path "handler operation type parameter count mismatch" (ntys == sg.tparams.length)
        let result := shiftTy q.atoms ntys 0 t
        let env := some (.cont sg.ret result (shiftEff q.atoms ntys 0 ε)) ::
          (binds sg.params ++ Γ.map (Option.map (shiftTy q.atoms ntys 0)))
        let εb ← accept q (sg.tparams ++ C).length (child path 0) result
          (← checkBlockR q mode [] (sg.tparams ++ C) env (R.map (shiftTy q.atoms ntys 0)) .other (child path 0) body)
        let εouter := substEffAt q.atoms 0 (List.replicate ntys (.base .unit)) [] εb
        -- 探索中の候補は節の効果をまだ覆わない。内外の包含は確定後に検査する。
        if mode == .strict || (← get).strictConts.contains (Γ.length + ndicts + n) then do
          acceptEff q (child path 0) (shiftEff q.atoms ntys 0 ε) εb
          acceptEff q (child path 0) ε εouter
        else pure ()
        let εs ← checkClausesR q mode Δ C Γ R (child path 1) rest t ε
        pure (union q εouter εs)

  /-- 節の型を外側に戻し、ずらし直して一致することを確かめてから結ぶ。 -/
  def inferClauseTypesR (q : Input) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
      (R : Option Ty) (path : List Nat) : Clauses → Ty → Eff → Checking Ty
    | .nil, t, _ => pure t
    | .cons o n ntys body rest ndicts, t, ε => do
        let sg ← lookup path "unknown handler operation" (opSig q.D.patternProgram q.B o)
          (fun _ => wfTys q.atoms C.length ε.fails)
        require path "handler operation names are not well formed" (namesWF sg.names sg.params)
        require path "handler operation arity mismatch" ((ndicts == opDictCount q.D.patternProgram o) && (ndicts + n == sg.params.length))
        require path "handler operation type parameter count mismatch" (ntys == sg.tparams.length)
        let result := shiftTy q.atoms ntys 0 t
        let env := some (.cont sg.ret result (shiftEff q.atoms ntys 0 ε)) ::
          (binds sg.params ++ Γ.map (Option.map (shiftTy q.atoms ntys 0)))
        let (a, _) ← checkBlockR q .relaxed [] (sg.tparams ++ C) env (R.map (shiftTy q.atoms ntys 0)) .other (child path 0) body
        let outer := substTy q.atoms (List.replicate ntys (.base .unit)) [] a
        require (child path 0) "handler result mentions an operation type parameter"
          (tyEq q.atoms (shiftTy q.atoms ntys 0 outer) a)
        let t' ← join q C.length (child path 0) t outer
        inferClauseTypesR q Δ C Γ R (child path 1) rest t' ε
end

/-- Q 付きの内部入口は状態だけを空にする。公開入口は Δ も空にする。 -/
def checkExprQ (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (p : Position) (path : List Nat) (e : Expr) : Result Inferred :=
  (checkExprR q mode Δ C Γ R p path e).run' {}

def checkBlockQ (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (p : Position) (path : List Nat) (body : Block) : Result Inferred :=
  (checkBlockR q mode Δ C Γ R p path body).run' {}

def checkTypesQ (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (es : Exprs) (ts : List Ty) : Result Eff :=
  guardResult path true
    ((checkTypesR q mode Δ C Γ R path 0 es ts).run' {})

def checkEachQ (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (es : Exprs) (a : Ty) : Result Eff :=
  guardResult path true
    ((checkEachR q mode Δ C Γ R path 0 es a).run' {})

def checkHoleArgsQ (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (args : HoleArgs) (ts : List Ty) : Result Eff :=
  guardResult path true
    ((checkHoleArgsR q mode Δ C Γ R path 0 args ts).run' {})

def checkArmsQ (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (p : Position) (path : List Nat) (arms : Arms) (a b : Ty) : Result Eff :=
  guardResult path true
    ((checkArmsR q mode Δ C Γ R p path arms a b).run' {})

def checkClausesQ (q : Input) (mode : ResumeMode) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (cs : Clauses) (t : Ty) (ε : Eff) : Result Eff :=
  guardResult path true
    ((checkClausesR q mode Δ C Γ R path cs t ε).run' {})

def inferClauseTypesQ (q : Input) (Δ : BuilderCtx) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (cs : Clauses) (t : Ty) (ε : Eff) : Result Ty :=
  guardResult path true
    ((inferClauseTypesR q Δ C Γ R path cs t ε).run' {})

/-- 宣言の外の従来の入口は、NoFail を仮定しない。 -/
def checkExpr (q : Input) (mode : ResumeMode) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (p : Position) (path : List Nat) (e : Expr) : Result Inferred :=
  checkExprQ { q with noFailRows := [] } mode [] C Γ R p path e

def checkBlock (q : Input) (mode : ResumeMode) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (p : Position) (path : List Nat) (body : Block) : Result Inferred :=
  checkBlockQ { q with noFailRows := [] } mode [] C Γ R p path body

def checkTypes (q : Input) (mode : ResumeMode) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (es : Exprs) (ts : List Ty) : Result Eff :=
  checkTypesQ { q with noFailRows := [] } mode [] C Γ R path es ts

def checkEach (q : Input) (mode : ResumeMode) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (es : Exprs) (a : Ty) : Result Eff :=
  checkEachQ { q with noFailRows := [] } mode [] C Γ R path es a

def checkHoleArgs (q : Input) (mode : ResumeMode) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (args : HoleArgs) (ts : List Ty) : Result Eff :=
  checkHoleArgsQ { q with noFailRows := [] } mode [] C Γ R path args ts

def checkArms (q : Input) (mode : ResumeMode) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (p : Position) (path : List Nat) (arms : Arms) (a b : Ty) : Result Eff :=
  checkArmsQ { q with noFailRows := [] } mode [] C Γ R p path arms a b

def checkClauses (q : Input) (mode : ResumeMode) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (cs : Clauses) (t : Ty) (ε : Eff) : Result Eff :=
  checkClausesQ { q with noFailRows := [] } mode [] C Γ R path cs t ε

def inferClauseTypes (q : Input) (C : List TParam) (Γ : List (Option Ty))
    (R : Option Ty) (path : List Nat) (cs : Clauses) (t : Ty) (ε : Eff) : Result Ty :=
  inferClauseTypesQ { q with noFailRows := [] } [] C Γ R path cs t ε

/-- 定義の宣言した戻り値型とエフェクトで本体を受け入れる。 -/
def checkDef (q : Input) (path : List Nat) (d : Def) : Result Unit := do
  require path "function signature has an out-of-scope row"
    (rowsTysCheck q.atoms d.neffs d.params && rowsTyCheck q.atoms d.neffs d.ret && rowsEffCheck q.atoms d.neffs d.eff)
  let bodyQ := { q with noFailRows := signatureQ d.neffs d.params d.ret d.eff }
  require path "function contract names are not well formed" (namesWF d.names d.params)
  require path "function body does not exit" (lamBodyOk d.body d.ret)
  let ε ← accept bodyQ d.tparams.length (child path 0) d.ret
    (← checkBlockQ bodyQ .strict [] d.tparams (binds (d.dictTys ++ d.params)) (some d.ret) .tail (child path 0) d.body)
  acceptEff bodyQ (child path 0) d.eff ε

/-- 実装の実名は位置による局所束縛へ変換する前に保持する。 -/
structure MethodInput where
  names : List String
  body : Block

/-- checker の入力は、型付き表層からは消えるメソッドの実名も持つ。 -/
structure ImplInput extends ImplSig where
  supers : ClassName → Option DictEv
  methods : MethName → Option MethodInput

/-- 名前を検査する入口と、性質 1 が使う本体の射影を区別する。 -/
def ImplInput.decl (id : ImplInput) : ImplDecl :=
  { id.toImplSig with supers := id.supers, methods := fun m => (id.methods m).map MethodInput.body }

/-- 添字は一覧の位置であり、名前が重複しても各位置を検査する。 -/
def checkMethods (q : Input) (path : List Nat) (id : ImplInput) (cd : ClassDecl)
    (views : MethName → CoverageView) :
    List MethName → Nat → Result Unit
  | [], _ => pure ()
  | m :: rest, index => do
      let methodPath := child path index
      let bodyQ : Input := { q with D := q.D.withView (views m) }
      match cd.methods m, id.methods m with
      | none, none => pure ()
      | some ms, some method =>
          require methodPath "implementation method parameter names mismatch" (method.names == ms.names)
          require methodPath "implementation method contract names are not well formed" (namesWF ms.names ms.params)
          require methodPath "method signature has an out-of-scope row"
            (rowsTysCheck q.atoms ms.neffs ms.params && rowsTyCheck q.atoms ms.neffs ms.ret && rowsEffCheck q.atoms ms.neffs ms.eff)
          let body := method.body
          let result := substTyAt q.atoms ms.tparams.length [id.target] [] ms.ret
          let params := ms.params.map (substTyAt q.atoms ms.tparams.length [id.target] [])
          require methodPath "implementation method body does not exit" (lamBodyOk body result)
          let ε ← accept { bodyQ with noFailRows := signatureQ ms.neffs ms.params ms.ret ms.eff } (ms.tparams ++ id.tparams).length methodPath result
            (← checkBlockQ { bodyQ with noFailRows := signatureQ ms.neffs ms.params ms.ret ms.eff } .strict [] (ms.tparams ++ id.tparams)
              (binds (id.dictTys.map (shiftTy q.atoms ms.tparams.length 0) ++ params))
              (some result) .tail methodPath body)
          acceptEff { bodyQ with noFailRows := signatureQ ms.neffs ms.params ms.ret ms.eff } methodPath (substEffAt q.atoms ms.tparams.length [id.target] [] ms.eff) ε
      | _, _ => throw ⟨methodPath, "implementation method set mismatch"⟩
      checkMethods q path id cd views rest (index + 1)

def checkSuperFlags (path : List Nat) (id : ImplInput) (cd : ClassDecl) :
    List ClassName → Nat → Result Unit
  | [], _ => pure ()
  | s :: rest, index => do
      require (child path index) "implementation superclass set mismatch"
        ((id.supers s).isSome == cd.supers.contains s)
      checkSuperFlags path id cd rest (index + 1)

def checkSuperDicts (q : Input) (path : List Nat) (id : ImplInput) :
    List ClassName → Nat → Result Unit
  | [], _ => pure ()
  | s :: rest, index => do
      let dictPath := child path index
      let d ← lookup dictPath "implementation superclass dictionary is missing" (id.supers s)
      let t ← checkDict q id.tparams (binds id.dictTys) dictPath d
      require dictPath "implementation superclass dictionary type mismatch" (tyEq q.atoms t (.dict s id.target))
      checkSuperDicts q path id rest (index + 1)

/-- 一覧の外の表の空欄は健全性の前提で保証する。 -/
def checkImpl (q : Input) (methodNames : List MethName) (superNames : List ClassName)
    (path : List Nat) (id : ImplInput)
    (views : MethName → CoverageView := fun _ => q.D.view) : Result Unit := do
  let cd ← lookup path "unknown implementation class" (q.D.classes id.cls) (fun _ => true)
  checkMethods q (child path 0) id cd views methodNames 0
  checkSuperFlags (child path 1) id cd superNames 0
  require path "superclass list does not contain all declared superclasses"
    (cd.supers.all (superNames.contains ·))
  checkSuperDicts q (child path 2) id cd.supers 0

end Benitoite.Surface.Check
