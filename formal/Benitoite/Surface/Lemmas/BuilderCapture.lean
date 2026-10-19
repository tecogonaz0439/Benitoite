import Benitoite.Surface.Lemmas.Typing

/-!
# 構築器のセル番号とコアの自由変数

束縛の個数だけ番号を換算し、通常のコアの型付けから利用不能な位置の不参照を得る。
設計書 01-12「構築器の局所文脈と旧構文の意味」に対応する。
-/
namespace Benitoite.Surface
open Benitoite.Release

/-- 内側で増えた番号は自由変数ではない。外側の番号だけを元の述語で調べる。 -/
def liftReads (n : Nat) (p : Nat → Prop) (i : Nat) : Prop := i < n ∨ p (i - n)

mutual
  /-- クロージャの内部も含め、実際のコアが読む自由変数の条件。 -/
  def Val.Reads (p : Nat → Prop) : Val → Prop
    | .var i => p i
    | .lam _ ps body => Comp.Reads (liftReads ps.length p) body
    | .con _ _ vs | .list vs | .setV vs | .dict _ _ vs => Vals.Reads p vs
    | .mapV ks vs => Vals.Reads p ks ∧ Vals.Reads p vs
    | .super v _ => Val.Reads p v
    | .const .. | .fnRef .. | .prim .. | .op .. | .raise .. | .loc .. | .bytesV .. => True
  def Vals.Reads (p : Nat → Prop) : List Val → Prop
    | [] => True
    | v :: vs => Val.Reads p v ∧ Vals.Reads p vs
  def Comp.Reads (p : Nat → Prop) : Comp → Prop
    | .ret v | .escape v => Val.Reads p v
    | .letIn m n => Comp.Reads p m ∧ Comp.Reads (liftReads 1 p) n
    | .app f vs | .meth f _ _ _ vs => Val.Reads p f ∧ Vals.Reads p vs
    | .ite v m n => Val.Reads p v ∧ Comp.Reads p m ∧ Comp.Reads p n
    | .match v arms => Val.Reads p v ∧ Arms.Reads p arms
    | .lazyC m => Comp.Reads p m
    | .use v m => Val.Reads p v ∧ Comp.Reads p m
    | .handle m cs => Comp.Reads p m ∧ Clauses.Reads p cs
    | .resume k v => Val.Reads p k ∧ Val.Reads p v
  def Arms.Reads (p : Nat → Prop) : List Arm → Prop
    | [] => True
    | .mk alts g body :: rest =>
        (∀ m, g = some m → Comp.Reads (liftReads (Arm.bindersOf alts) p) m) ∧
        Comp.Reads (liftReads (Arm.bindersOf alts) p) body ∧ Arms.Reads p rest
  def Clauses.Reads (p : Nat → Prop) : List Clause → Prop
    | [] => True
    | .mk _ n _ body :: rest => Comp.Reads (liftReads (n + 1) p) body ∧ Clauses.Reads p rest
    | .fail _ body :: rest => Comp.Reads (liftReads 2 p) body ∧ Clauses.Reads p rest
end

/-- 型のある位置だけを許す。none の位置と範囲外は許さない。 -/
def EnvReads (p : Nat → Prop) (Γ : List (Option Ty)) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → p i

namespace EnvReads
 theorem cons {p Γ} (h : EnvReads p Γ) (t : Option Ty) : EnvReads (liftReads 1 p) (t :: Γ) := by
  intro i a hi
  cases i with
  | zero => exact Or.inl (by decide)
  | succ i => exact Or.inr (h i a hi)
 theorem append {p Γ} (h : EnvReads p Γ) (xs : List (Option Ty)) :
     EnvReads (liftReads xs.length p) (xs ++ Γ) := by
  intro i a hi
  by_cases hx : i < xs.length
  · exact Or.inl hx
  · exact Or.inr (h (i - xs.length) a (by simpa only [List.getElem?_append_right (Nat.le_of_not_gt hx)] using hi))
 theorem hide {p Γ} (h : EnvReads p Γ) : EnvReads p (hideConts Γ) := by
  intro i a hi
  exact h i a (hideConts_get.mp hi).1
 theorem shift {p Γ} (h : EnvReads p Γ) (n : Nat) : EnvReads p (shiftEnv n Γ) := by
  intro i a hi
  simp only [shiftEnv, List.getElem?_map] at hi
  obtain ⟨t, ht, ha⟩ := Option.map_eq_some_iff.mp hi
  cases t with
  | none => cases ha
  | some t => exact h i t ht
end EnvReads

variable {P : Release.Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
mutual
 theorem HasTypeVQ.reads {C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a)
     {pv} (hp : EnvReads pv Γ) : Val.Reads pv v := by
  match h with
  | .V_Var hi _ =>
      simp only [Val.Reads] <;> exact hp _ _ hi
  | .V_Const | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes => simp only [Val.Reads]
  | .V_Lam _ _ hb => simpa only [Val.Reads, binds_length] using HasTypeCQ.reads hb (hp.hide.append _)
  | .V_Con _ _ hs | .V_Dict _ _ hs =>
      simp only [Val.Reads] <;> exact HasTypeVsQ.reads hs hp
  | .V_List hs _ | .V_Set hs _ _ =>
      simp only [Val.Reads] <;> exact HasTypeEachQ.reads hs hp
  | .V_Map hk hv _ _ _ _ =>
      simp only [Val.Reads] <;> exact ⟨HasTypeEachQ.reads hk hp, HasTypeEachQ.reads hv hp⟩
  | .V_Super hv _ _ | .V_Sub hv _ _ =>
      first | exact HasTypeVQ.reads hv hp | simpa only [Val.Reads] using HasTypeVQ.reads hv hp
 theorem HasTypeVsQ.reads {C Γ vs ts} (h : HasTypeVsQ P B Ψ Q C Γ vs ts)
     {pv} (hp : EnvReads pv Γ) : Vals.Reads pv vs := by
  match h with
  | .nil => simp only [Vals.Reads]
  | .cons hv hs =>
      simp only [Vals.Reads] <;> exact ⟨HasTypeVQ.reads hv hp, HasTypeVsQ.reads hs hp⟩
 theorem HasTypeEachQ.reads {C Γ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a)
     {pv} (hp : EnvReads pv Γ) : Vals.Reads pv vs := by
  match h with
  | .nil => simp only [Vals.Reads]
  | .cons hv hs =>
      simp only [Vals.Reads] <;> exact ⟨HasTypeVQ.reads hv hp, HasTypeEachQ.reads hs hp⟩
 theorem HasTypeCQ.reads {C Γ R m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε)
     {pv} (hp : EnvReads pv Γ) : Comp.Reads pv m := by
  match h with
  | .C_Return hv | .C_Escape hv _ => simpa only [Comp.Reads] using HasTypeVQ.reads hv hp
  | .C_Sub hm _ _ _ | .C_Eff hm _ =>
      exact HasTypeCQ.reads hm hp
  | .C_Let hm hn =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeCQ.reads hm hp, HasTypeCQ.reads hn (hp.cons _)⟩
  | .C_App hf hs =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeVQ.reads hf hp, HasTypeVsQ.reads hs hp⟩
  | .C_If hv hm hn =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeVQ.reads hv hp, HasTypeCQ.reads hm hp, HasTypeCQ.reads hn hp⟩
  | .C_Match hv ha _ =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeVQ.reads hv hp, HasTypeArmsQ.reads ha hp⟩
  | .C_Lazy hm =>
      simp only [Comp.Reads] <;> exact HasTypeCQ.reads hm hp.hide
  | .C_Use hv _ hm _ =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeVQ.reads hv hp, HasTypeCQ.reads hm hp⟩
  | .C_Handle hm _ hc =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeCQ.reads hm hp, HasTypeClausesQ.reads hc hp⟩
  | .C_Handle_Fail hm _ _ hc =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeCQ.reads hm hp, HasFailureClause.reads hc hp⟩
  | .C_Resume hi hv =>
      simp only [Comp.Reads, Val.Reads] <;> exact ⟨hp _ _ hi, HasTypeVQ.reads hv hp⟩
  | .C_ResumeL _ hv =>
      simp only [Comp.Reads, Val.Reads] <;> exact ⟨trivial, HasTypeVQ.reads hv hp⟩
  | .C_Meth hv _ _ _ _ _ _ hs =>
      simp only [Comp.Reads] <;> exact ⟨HasTypeVQ.reads hv hp, HasTypeVsQ.reads hs hp⟩
 theorem HasTypeArmsQ.reads {C Γ R arms a b ε} (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε)
     {pv} (hp : EnvReads pv Γ) : Arms.Reads pv arms := by
  match h with
  | .nil _ => simp only [Arms.Reads]
  | .plain ha hb hr =>
      simp only [Arms.Reads]
      refine ⟨by simp, ?_, HasTypeArmsQ.reads hr hp⟩
      simpa only [binds_length, ha.2.1] using HasTypeCQ.reads hb (hp.append _)
  | .guarded ha hg hb hr =>
      simp only [Arms.Reads]
      refine ⟨?_, ?_, HasTypeArmsQ.reads hr hp⟩
      · intro m hm; cases hm
        simpa only [binds_length, ha.2.1] using HasTypeCQ.reads hg (hp.append _).hide
      · simpa only [binds_length, ha.2.1] using HasTypeCQ.reads hb (hp.append _)
 theorem HasTypeClausesQ.reads {C Γ R cs t ε} (h : HasTypeClausesQ P B Ψ Q C Γ R cs t ε)
     {pv} (hp : EnvReads pv Γ) : Clauses.Reads pv cs := by
  match h with
  | .nil => simp only [Clauses.Reads]
  | .cons _ _ hn _ _ hb hr =>
      simp only [Clauses.Reads]
      refine ⟨?_, HasTypeClausesQ.reads hr hp⟩
      have ht := HasTypeCQ.reads hb ((hp.shift _).append (_ :: _))
      simpa only [List.length_cons, binds_length, hn] using ht
 theorem HasFailureClause.reads {C Γ E R cs t ε} (h : HasFailureClause P B Ψ Q C Γ E R cs t ε)
     {pv} (hp : EnvReads pv Γ) : Clauses.Reads pv cs := by
  match h with
  | .one _ _ _ hb =>
      simp only [Clauses.Reads] <;> exact ⟨HasTypeCQ.reads hb ((hp.shift _).append [none, some _]), trivial⟩
end

/-- 利用不能な位置の値を読めないことから、外側の構築器の番号を除外する。 -/
theorem BuilderCtx.aligned_envReads {Γ Δ} (h : BuilderCtx.Aligned Γ Δ) :
    EnvReads (fun i => Δ.kindAt i = none) Γ := by
  intro i a hi
  cases hk : Δ.kindAt i with
  | none => rfl
  | some k => have hx := h.2 i k hk; rw [hi] at hx; cases hx

/-- 空分類表で検査する境界の本体は、外側のセル番号を自由に参照しない。
後続の局所宣言を含む任意の部分導出に適用でき、内側の束縛は Reads が数える。 -/
theorem builderBoundary_no_capture {p : Program} {view B op Q C Γ Δ R pos body a ε pe}
    (ha : BuilderCtx.Aligned Γ Δ) (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasBlockQ (p.declarationsFor view) B op Q [] C Γ R pos body a ε)
    (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    Comp.Reads (fun i => Δ.kindAt i = none) (desugarBlock op pos body) :=
  HasTypeCQ.reads (HasBlock.desugar hwf hsig h sc hΓ hR) (BuilderCtx.aligned_envReads ha)

/-- 結果の型の範囲条件 TyOK を既存の clean から再確認する。
セルの逸出の禁止を主張する定理ではなく、Reference 型一般も禁止しない。 -/
theorem builders_ordinary_result {p : Program} {view B op Q C Γ Δ R pos body a ε pe}
    (hc : BuilderCtx.Clean C.length Δ) (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasBlockQ (p.declarationsFor view) B op Q Δ C Γ R pos body a ε)
    (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) : TyOK C.length a :=
  HasBlockQ.clean hc hwf hsig h sc hΓ hR

/-- 実際にコアの lambda または lazyC を作る式。捕捉の結論ではなく、生成箇所の分類である。 -/
def Expr.EmitsClosure : Expr → Prop
  | .funDicts .. | .methName .. | .opDicts .. | .conValue .. |
    .partialCall .. | .partialCon .. | .lam .. | .lazyE .. => True
  | _ => False

/-- 生成箇所の型付けは、外側の分類表を一切読まない。同じ構文と型を保って空表へ移せる。 -/
theorem HasTypeQ.closure_empty {D B op Q Δ C Γ R pos e a ε}
    (h : HasTypeQ D B op Q Δ C Γ R pos e a ε) (site : e.EmitsClosure) :
    HasTypeQ D B op Q [] C Γ R pos e a ε := by
  match h with
  | .E_BuilderOp hr ha => simp only [Expr.EmitsClosure] at site
  | .E_Local h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_Const h0 => simp only [Expr.EmitsClosure] at site
  | .E_Fun h0 h1 h2 h3 h4 h5 h6 h7 => simp only [Expr.EmitsClosure] at site
  | .E_FunDicts h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 => exact .E_FunDicts h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10
  | .E_MethName h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 h12 => exact .E_MethName h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 h12
  | .E_Prim h0 h1 h2 h3 h4 h5 h6 => simp only [Expr.EmitsClosure] at site
  | .E_Raise h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_HandleFail h0 h1 h2 h3 h4 h5 h6 => simp only [Expr.EmitsClosure] at site
  | .E_Op h0 h1 h2 h3 => simp only [Expr.EmitsClosure] at site
  | .E_OpDicts h0 h1 h2 h3 h4 h5 h6 h7 h8 => exact .E_OpDicts h0 h1 h2 h3 h4 h5 h6 h7 h8
  | .E_NullCon h0 h1 h2 => simp only [Expr.EmitsClosure] at site
  | .E_ConValue h0 h1 h2 h3 h4 h5 => exact .E_ConValue h0 h1 h2 h3 h4 h5
  | .E_Literal  => simp only [Expr.EmitsClosure] at site
  | .E_NegInt  => simp only [Expr.EmitsClosure] at site
  | .E_NegFloat  => simp only [Expr.EmitsClosure] at site
  | .E_NegDecimal  => simp only [Expr.EmitsClosure] at site
  | .E_NegInteger8  => simp only [Expr.EmitsClosure] at site
  | .E_NegInteger16  => simp only [Expr.EmitsClosure] at site
  | .E_NegInteger32  => simp only [Expr.EmitsClosure] at site
  | .E_NegFloat32  => simp only [Expr.EmitsClosure] at site
  | .E_Unit  => simp only [Expr.EmitsClosure] at site
  | .E_Paren h0 => simp only [Expr.EmitsClosure] at site
  | .E_Record h0 h1 h2 h3 => simp only [Expr.EmitsClosure] at site
  | .E_RecordUpdate h0 h1 h2 h3 h4 h5 h6 h7 h8 => simp only [Expr.EmitsClosure] at site
  | .E_ConCall h0 h1 h2 => simp only [Expr.EmitsClosure] at site
  | .E_Call h0 h1 h2 h3 => simp only [Expr.EmitsClosure] at site
  | .E_PipeCall h0 h1 h2 h3 h4 => simp only [Expr.EmitsClosure] at site
  | .E_PipeConCall h0 h1 h2 h3 h4 => simp only [Expr.EmitsClosure] at site
  | .E_PipeConValue h0 h1 h2 h3 h4 h5 h6 => simp only [Expr.EmitsClosure] at site
  | .E_PipeApply h0 h1 h2 h3 => simp only [Expr.EmitsClosure] at site
  | .E_PartialCall h0 h1 h2 h3 h4 h5 h6 h7 => exact .E_PartialCall h0 h1 h2 h3 h4 h5 h6 h7
  | .E_PartialCon h0 h1 h2 h3 h4 h5 h6 h7 h8 => exact .E_PartialCon h0 h1 h2 h3 h4 h5 h6 h7 h8
  | .E_Binary h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 => simp only [Expr.EmitsClosure] at site
  | .E_Neg h0 h1 h2 h3 h4 h5 h6 h7 h8 => simp only [Expr.EmitsClosure] at site
  | .E_Not h0 => simp only [Expr.EmitsClosure] at site
  | .E_And h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_Or h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_List h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_ListSpread h0 h1 h2 h3 h4 h5 => simp only [Expr.EmitsClosure] at site
  | .E_Interpolation h0 h1 h2 h3 h4 => simp only [Expr.EmitsClosure] at site
  | .E_Lam h0 h1 h2 => exact .E_Lam h0 h1 h2
  | .E_If h0 h1 h2 h3 => simp only [Expr.EmitsClosure] at site
  | .E_ElseIf h0 h1 h2 h3 h4 => simp only [Expr.EmitsClosure] at site
  | .E_IfOnly h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_Match h0 h1 h2 h3 => simp only [Expr.EmitsClosure] at site
  | .E_ReturnTail h0 => simp only [Expr.EmitsClosure] at site
  | .E_ReturnOther h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_TryResult h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 => simp only [Expr.EmitsClosure] at site
  | .E_TryOption h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 => simp only [Expr.EmitsClosure] at site
  | .E_TryResultDie h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 h11 => simp only [Expr.EmitsClosure] at site
  | .E_TryOptionDie h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 => simp only [Expr.EmitsClosure] at site
  | .E_With h0 h1 h2 => simp only [Expr.EmitsClosure] at site
  | .E_Lazy h0 => exact .E_Lazy h0
  | .E_Handle h0 h1 h2 => simp only [Expr.EmitsClosure] at site
  | .E_Resume h0 h1 => simp only [Expr.EmitsClosure] at site
  | .E_Sub h0 h1 h2 h3 => exact .E_Sub (HasTypeQ.closure_empty h0 site) h1 h2 h3

/-- どの局所宣言の内側でも、その部分導出で作る実際のコアの全自由参照が
外側のセル番号を避ける。Reads は生成した lambda の引数と内部の let を数えるので、
部分適用の callee・固定引数から生じた lambda も同じ結論に含む。 -/
theorem builderExprBoundary_no_capture {p : Program} {view B op Q C Γ Δ R pos e a ε pe}
    (ha : BuilderCtx.Aligned Γ Δ) (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasTypeQ (p.declarationsFor view) B op Q Δ C Γ R pos e a ε)
    (site : e.EmitsClosure) (sc : e.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    Comp.Reads (fun i => Δ.kindAt i = none) (desugarExpr op pos e) :=
  HasTypeCQ.reads (HasType.desugar hwf hsig (h.closure_empty site) sc hΓ hR)
    (BuilderCtx.aligned_envReads ha)

/-- 節の列では本体が初めから空分類表である。続きも同じ条件で移す。 -/
theorem HasClausesQ.closure_empty {D B op Q Δ C Γ R cs a ε}
    (h : HasClausesQ D B op Q Δ C Γ R cs a ε) :
    HasClausesQ D B op Q [] C Γ R cs a ε := by
  match h with
  | .nil => exact .nil
  | .cons h0 h1 h2 h3 h4 h5 h6 => exact .cons h0 h1 h2 h3 h4 h5 (HasClausesQ.closure_empty h6)

/-- 通常節のコアの本体も、節の引数・継続・辞書の位置を除いた外側のセルを読まない。 -/
theorem builderClauses_no_capture {p : Program} {view B op Q C Γ Δ R cs a ε pe}
    (ha : BuilderCtx.Aligned Γ Δ) (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasClausesQ (p.declarationsFor view) B op Q Δ C Γ R cs a ε)
    (sc : cs.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) (ht : TyOK C.length a) :
    Clauses.Reads (fun i => Δ.kindAt i = none) (desugarClauses op cs) := by
  have hc := HasClausesQ.desugar (BuilderCtx.aligned_empty _) (BuilderCtx.clean_empty _)
    hwf hsig h.closure_empty sc hΓ hR ht
  rw [fillBuilders.empty] at hc
  exact HasTypeClausesQ.reads hc (BuilderCtx.aligned_envReads ha)

/-- Fail 節は予約した継続とエラーの二位置を数える。外側の型を shift しても
セル番号の不参照は変わらない。 -/
theorem builderFailClause_no_capture {p : Program} {view B op Q C Γ Δ R E pos clause a ε pe}
    (ha : BuilderCtx.Aligned Γ Δ) (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped)
    (h : HasBlockQ (p.declarationsFor view) B op Q [] C
      (none :: some E :: shiftEnv 1 Γ) R pos clause a ε)
    (sc : clause.Scoped C.length pe (none :: some E :: shiftEnv 1 Γ).length)
    (hΓ : EnvClean C.length (none :: some E :: shiftEnv 1 Γ))
    (hR : ∀ r, R = some r → TyOK C.length r) :
    Comp.Reads (liftReads 2 (fun i => Δ.kindAt i = none)) (desugarBlock op pos clause) :=
  HasTypeCQ.reads (HasBlock.desugar hwf hsig h sc hΓ hR)
    (((BuilderCtx.aligned_envReads ha).shift 1).append [none, some E])

end Benitoite.Surface
