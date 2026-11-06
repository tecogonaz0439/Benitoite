import Benitoite.Release.Refinement.Surface.ScopedProof

/-! # 範囲深さが零のスコープ保存

範囲深さを一般化した各定理に零を与えると、範囲を持たない場合の元の型で適用できる。
-/
namespace Benitoite.Release.Refinement.Surface.NoRangeScopedExamples
open Benitoite.Release.Refinement.Surface
variable {B : Builtins}

-- DictEv.Scoped.toVal
example {nt ne} : ∀ {nv : Nat} {d : DictEv}, d.Scoped nt ne nv (nr := 0) → d.toVal.SourceScoped 0 nt ne nv := by
  exact DictEv.Scoped.toVal

-- DictEv.ScopedList.toValList
example {nt ne} : ∀ {nv : Nat} {ds : List DictEv}, DictEv.ScopedList nt ne nv (nr := 0) ds → scopedValues 0 nt ne nv (DictEv.toValList ds) := by
  exact DictEv.ScopedList.toValList

-- directCallee_scoped
example {nt ne nv k f h ws} (hf : f.Scoped nt ne nv (nr := 0)) (hd : directCallee f = some h) (hw : scopedValues 0 nt ne (nv + k) ws) : ((h.rename (· + k)).apply ws).SourceScoped 0 nt ne (nv + k) := by
  exact directCallee_scoped hf hd hw

-- recordUpdateValues_scoped
example {nt ne nv c n positions m} (hpos : positions.length = m) : scopedValues 0 nt ne (nv + m + (recordUpdatePattern c n positions).binders) (recordUpdateValues c n positions (boundVars m)) := by
  exact recordUpdateValues_scoped hpos

-- exitCall_scoped
example {nt ne nv : Nat} {t : Ty} {exit : PrimName} {c : Const} (k : Nat) {m : Nat} (ht : t.SourceScoped 0 nt ne nv) (hm : nv + k = m) : (Comp.app (.prim exit [t.shiftV k 0] [] []) [.const c]).SourceScoped 0 nt ne m := by
  exact exitCall_scoped k ht hm

-- recordUpdateValues_scoped'
example {nt ne nv c n positions m M} (hpos : positions.length = m) (he : nv + m + (recordUpdatePattern c n positions).binders = M) : scopedValues 0 nt ne M (recordUpdateValues c n positions (boundVars m)) := by
  exact recordUpdateValues_scoped' hpos he

-- spreadFinish_scoped
example {nt ne nv k f h before s after} (hf : f.Scoped nt ne nv (nr := 0)) (hd : directCallee f = some h) (hb : scopedValues 0 nt ne (nv + k) before) (hs : s.SourceScoped 0 nt ne (nv + k)) (ha : scopedValues 0 nt ne (nv + k) after) : (spreadFinish (h.rename (· + k)) before s after).SourceScoped 0 nt ne (nv + k) := by
  exact spreadFinish_scoped hf hd hb hs ha

-- JoinTy.scoped
example {D Γ0 tadd k Γ' Φ' depth left rest e b} {op : OpPrim} {nt ne : Nat} (h : JoinTy D B C Γ0 tadd k Γ' Φ' depth left rest e) (hop : op (.binary .add) (.base .string) = some (b, [])) : ∀ {n m : Nat}, left.SourceScoped 0 nt ne m → scopedValues 0 nt ne n rest → n + depth = m → (joinStringFrom op depth left rest).SourceScoped 0 nt ne m := by
  exact JoinTy.scoped h hop

-- JoinPartsTy.scoped
example {D Γ0 op k Γ' Φ' acc e} {nt ne m : Nat} (h : JoinPartsTy D B Q C Γ0 op k Γ' Φ' acc e) (hacc : scopedValues 0 nt ne m acc) : (joinStringParts op acc).SourceScoped 0 nt ne m := by
  exact JoinPartsTy.scoped h hacc

-- InterpTy.scoped
example {D Γ0 op k Γ' Φ' ps vs fs acc e} {nt ne nv : Nat} (h : InterpTy D B Q C Γ0 op k Γ' Φ' ps vs fs acc e) : fs.Scoped nt ne nv (nr := 0) → scopedValues 0 nt ne (nv + k) vs → scopedValues 0 nt ne (nv + k) acc → (interpolate op ps vs ((directHeads fs).map (CallHead.rename (· + k))) acc).SourceScoped 0 nt ne (nv + k) := by
  exact InterpTy.scoped h

-- holeTypes_scoped
example {nt ne nv} : ∀ {args : HoleArgs}, args.Scoped nt ne nv (nr := 0) → scopedTypes 0 nt ne nv args.holeTypes := by
  exact holeTypes_scoped

-- argVals_scoped
example {nt ne} : ∀ (args : HoleArgs) (nv d : Nat), args.fixedCount ≤ d → scopedValues 0 nt ne (nv + args.holeTypes.length + d) (args.argVals d) := by
  exact argVals_scoped

-- fixedShift_scoped
example {nt ne nv} (n : Nat) {ms : List Comp} (h : ∀ m ∈ ms, m.SourceScoped 0 nt ne nv) : ∀ m ∈ ms.map (Comp.rename (· + n)), m.SourceScoped 0 nt ne (nv + n) := by
  exact fixedShift_scoped n h

-- HasTypeQ.scoped
example {D op Q Δ C Γ Φ R p e a ε ne} (h : HasTypeQ D B op Q Δ C Γ Φ R p e a ε) (hs : e.Scoped C.length ne Γ.length (nr := 0)) : (desugarExpr op p e).SourceScoped 0 C.length ne Γ.length := by
  exact HasTypeQ.scoped h hs

-- HasFixedQ.scoped
example {D op Q Δ C Γ Φ R args as ε ne} (h : HasFixedQ D B op Q Δ C Γ Φ R args as ε) (hs : args.Scoped C.length ne Γ.length (nr := 0)) : ∀ m ∈ fixedComps op args, m.SourceScoped 0 C.length ne Γ.length := by
  exact HasFixedQ.scoped h hs

-- HasTypesQ.scoped
example {D op Q Δ C Γ Φ R es as ε ne} (h : HasTypesQ D B op Q Δ C Γ Φ R es as ε) (hs : es.Scoped C.length ne Γ.length (nr := 0)) : ∀ m ∈ desugarExprs op es, m.SourceScoped 0 C.length ne Γ.length := by
  exact HasTypesQ.scoped h hs

-- HasArmsQ.scoped
example {D op Q Δ C Γ Φ R p arms a b ε ne} (h : HasArmsQ D B op Q Δ C Γ Φ R p arms a b ε) (hs : arms.Scoped C.length ne Γ.length (nr := 0)) : scopedArms 0 C.length ne Γ.length (desugarArms op p arms) := by
  exact HasArmsQ.scoped h hs

-- HasClausesQ.scoped
example {D op Q Δ C Γ Φ R εb cs t ε ne} (h : HasClausesQ D B op Q Δ C Γ Φ R εb cs t ε) (hs : cs.Scoped C.length ne Γ.length (nr := 0)) : scopedClauses 0 C.length ne Γ.length (desugarClauses op cs) := by
  exact HasClausesQ.scoped h hs

-- HasBlockQ.scoped
example {D op Q Δ C Γ Φ R p body a ε ne} (h : HasBlockQ D B op Q Δ C Γ Φ R p body a ε) (hs : body.Scoped C.length ne Γ.length (nr := 0)) : (desugarBlock op p body).SourceScoped 0 C.length ne Γ.length := by
  exact HasBlockQ.scoped h hs

end Benitoite.Release.Refinement.Surface.NoRangeScopedExamples
