import Benitoite.Release.Refinement.Step
import Benitoite.Release.Semantics

namespace Benitoite.Release.Refinement
noncomputable section


def embedBuilderKind : Benitoite.Release.BuilderKind → BuilderKind
  | .string => .string
  | .list a => .list (embedTy a)
  | .bytes => .bytes

mutual
  def embedVal : Benitoite.Release.Val → Val
    | .var i => .var i
    | .const c => .const (embedConst c)
    | .fnRef f ts es => .fnRef f (embedTys ts) (es.map embedEff)
    | .prim b ts es rs => .prim b (embedTys ts) (es.map embedEff) (rs.map embedRange)
    | .lam ns ps body => .lam ns (embedTys ps) (embedComp body)
    | .con c ts vs => .con c (embedTys ts) (embedVals vs)
    | .list vs => .list (embedVals vs)
    | .op o ts => .op o (embedTys ts)
    | .raise a e => .raise (embedTy a) (embedTy e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (embedVals ks) (embedVals vs)
    | .setV vs => .setV (embedVals vs)
    | .bytesV bs => .bytesV bs
    | .dict i ts vs => .dict i (embedTys ts) (embedVals vs)
    | .super v s => .super (embedVal v) s
    | .checked t => .checked t
    | .checkedRequest t v => .checkedRequest t (embedVal v)
  def embedVals : List Benitoite.Release.Val → List Val
    | [] => []
    | v :: vs => embedVal v :: embedVals vs
  def embedComp : Benitoite.Release.Comp → Comp
    | .builderLet b m => .builderLet (embedBuilderKind b) (embedComp m)
    | .builderOp b op r vs => .builderOp (embedBuilderKind b) op r (embedVals vs)
    | .ret v => .ret (embedVal v)
    | .letIn m n => .letIn (embedComp m) (embedComp n)
    | .app f vs => .app (embedVal f) (embedVals vs)
    | .ite v m n => .ite (embedVal v) (embedComp m) (embedComp n)
    | .match v arms => .match (embedVal v) (embedArms arms)
    | .lazyC m => .lazyC (embedComp m)
    | .escape v => .escape (embedVal v)
    | .use v m => .use (embedVal v) (embedComp m)
    | .handle m h => .handle (embedComp m) (embedClauses h)
    | .resume k v => .resume (embedVal k) (embedVal v)
    | .meth v m ts es vs => .meth (embedVal v) m (embedTys ts) (es.map embedEff) (embedVals vs)
  def embedArm : Benitoite.Release.Arm → Arm
    | .mk alts none body => .mk alts none (embedComp body)
    | .mk alts (some g) body => .mk alts (some (embedComp g)) (embedComp body)
  def embedArms : List Benitoite.Release.Arm → List Arm
    | [] => []
    | arm :: arms => embedArm arm :: embedArms arms
  def embedClause : Benitoite.Release.Clause → Clause
    | .mk o n k m => .mk o n k (embedComp m)
    | .fail e m => .fail (embedTy e) (embedComp m)
  def embedClauses : List Benitoite.Release.Clause → List Clause
    | [] => []
    | c :: cs => embedClause c :: embedClauses cs
end

def embedDef (d : Benitoite.Release.Def) : Def :=
  ⟨d.tparams.map embedTParam, d.neffs, d.names, embedParameters d.params,
    (embedTy d.ret).shiftV d.params.length 0, (embedEff d.eff).shiftV d.params.length 0, embedComp d.body⟩

def embedConDecl (d : Benitoite.Release.ConDecl) : ConDecl := ⟨d.data, d.ntys, embedTys d.args⟩

def embedOpDecl (d : Benitoite.Release.OpDecl) : OpDecl :=
  ⟨d.eff, d.tparams, d.names, embedParameters d.params, (embedTy d.ret).shiftV d.params.length 0, d.dictParams⟩

def embedImplDecl (d : Benitoite.Release.ImplDecl) : ImplDecl :=
  ⟨d.tparams, d.dictParams, d.cls, embedTy d.target,
    fun c => (d.supers c).map embedVal, fun m => (d.methods m).map embedComp⟩

def embedProgram (P : Benitoite.Release.Program) : Program :=
  ⟨fun f => (P.defs f).map embedDef, fun c => (P.cons c).map embedConDecl,
    fun o => (P.ops o).map embedOpDecl, P.effects, fun c => (P.classes c).map embedClassDecl,
    (fun i => (P.impls i).map embedImplDecl), [], fun _ => none⟩

@[simp] theorem embedProgram_externals (P : Benitoite.Release.Program) : (embedProgram P).externals = [] := rfl

@[simp] theorem embedProgram_dataInfo (P : Benitoite.Release.Program) :
    (embedProgram P).dataInfo = (fun _ => none) := rfl

@[simp] theorem embedProgram_varianceFor (P : Benitoite.Release.Program) (d : DataName) (n : Nat) :
    (embedProgram P).varianceFor d n = List.replicate n .invariant := rfl

/-- 旧の値の像を空の捕捉で閉じた、実行時の保持値の像。 -/
def embedHeldVal (v : Benitoite.Release.Val) : Val := closeVal Capture.empty (embedVal v)

def embedFrame : Benitoite.Release.Frame → Frame
  | .letF m => .letF (.pure (embedComp m))
  | .mark => .mark
  | .update l => .update l
  | .release v => .release (embedVal v)
  | .handleF h => .handleF Capture.empty (embedClauses h)
  | .drop k => .drop k
  | .guardF v arms next body => .guardF (embedHeldVal v) Capture.empty (embedArms arms) next (.pure (embedComp body))

def embedCont (k : Benitoite.Release.Cont) : Cont := k.map embedFrame

def embedBuilderContents : Benitoite.Release.BuilderContents → BuilderContents
  | .string s => .string s
  | .list _ vs => .list (embedVals vs)
  | .bytes bs => .bytes bs

def embedCell : Benitoite.Release.Cell → Cell
  | .builder c => .builder (embedBuilderContents c)
  | .val v => .val (embedVal v)
  | .thunk m => .thunk (.pure (embedComp m))
  | .done v => .done (embedVal v)
  | .cont k => .cont (embedCont k)
  | .used => .used

def embedLocTy : Benitoite.Release.LocTy → LocTy
  | .builder b => .builder (embedBuilderKind b)
  | .ref a => .ref (embedTy a)
  | .lazy a => .lazy (embedTy a)
  | .cont a b e r => .cont (embedTy a) (embedTy b) (embedEff e) (r.map embedTy)

def embedStoreTy (Ψ : Benitoite.Release.StoreTy) : StoreTy := fun l => (Ψ l).map embedLocTy

def embedStore (μ : Benitoite.Release.Store) : Store := fun l => (μ l).map embedCell

/-- 全域の構文変換である。閉じた旧状態の型付けの対応は LegacyStateTyping が証明する。一段遷移の対応は証明しない。 -/
def embedState : Benitoite.Release.State → State
  | .run m k μ => .run (.pure (embedComp m)) (embedCont k) (embedStore μ)
  | .matchRun v arms next k μ => .matchRun (embedHeldVal v) Capture.empty (embedArms arms) next (embedCont k) (embedStore μ)
  | .error rs k μ => .error rs (embedCont k) (embedStore μ)
  | .exit n rs k μ => .exit n rs (embedCont k) (embedStore μ)

def embedOutcome : Benitoite.Release.Outcome → Outcome
  | .val v => .val (embedVal v)
  | .err r => .err r
  | .exit n => .exit n

def embedEvent : Benitoite.Release.Event → Event
  | .io b vs out obs => .io b (embedVals vs) (embedOutcome out) obs
  | .release v r => .release (embedVal v) r

@[simp] theorem embedVals_length (vs : List Benitoite.Release.Val) : (embedVals vs).length = vs.length := by
  induction vs <;> simp_all [embedVals]

@[simp] theorem embedCont_length (k : Benitoite.Release.Cont) : (embedCont k).length = k.length := List.length_map ..

theorem embedStore_set (μ : Benitoite.Release.Store) (l : Nat) (c : Benitoite.Release.Cell) :
    embedStore (μ.set l c) = (embedStore μ).set l (embedCell c) := by
  funext i; simp only [embedStore, Benitoite.Release.Store.set, Store.set]; split <;> rfl

end
end Benitoite.Release.Refinement
