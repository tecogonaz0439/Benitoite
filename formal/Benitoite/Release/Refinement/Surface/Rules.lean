import Benitoite.Release.Refinement.Surface.Typing
import Benitoite.Release.Refinement.Surface.Desugar
import Benitoite.Release.Refinement.Surface.Transport

/-!
# 篩付きの型の表層の型付けの規則

`HasTypeQ D B op Q Δ C Γ Φ R p e a ε` は、宣言の表 D、組み込みの表 B、演算子の表 op、NoFail の文脈 Q、構築器の文脈 Δ、
型パラメータの文脈 C、値の文脈 Γ、事実の列 Φ、最も内側の戻り値型 R、位置 p のもとで、式 e が型 a と効果 ε を持つという
判断である（設計書 01-12「型の情報を付けた表層の構文と型付け」）。型の推論ではなく、構文に付いた情報を検査する。

型の宣言の照合（宣言済み・kind・部分型・パターン・網羅性）は、宣言の表から作る核のプログラム `D.core` で行う。部分型は
`Ty.LeQ`、効果の包含は一原子の被覆 `Eff.Covers` で比べる。名前付き関数・組み込みの関数・操作の参照は依存列の型を持ち、
呼出しは、各実引数を書いた順に元の文脈で型付け、脱糖が束縛する変数の文脈で依存列を変数の列に沿って照合し、結果型を
束縛を含まない型へ部分型で戻す。分岐は、条件の値を束縛した文脈で条件の真偽から導ける事実を、各枝の事実の列に加えてよい。
-/

namespace Benitoite.Release.Refinement.Surface

mutual
  /-- 01-12「型クラス」: 型検査が決めた辞書の型付け。V-Dict・受け取った辞書・節の辞書・V-Super の写しである。 -/
  inductive DictEv.HasType (D : Declarations) (B : Builtins) : TypeCtx → Ctx → DictEv → Ty → Prop
    | impl {C Γ i ts ds is} :
        D.impls i = some is → SatAll B C ts is.tparams → TypeAnnotations D.core C Γ ts →
        TypeArgsKinded D.core C ts (List.replicate is.tparams.length .value) →
        (∀ a ∈ is.dictTys, a.WF 0 is.tparams.length 0) → is.target.WF 0 is.tparams.length 0 →
        DictEv.HasTypes D B C Γ ds (is.dictTys.map (Ty.subst ts [])) →
        Ty.Annotation D.core C Γ (.dict is.cls (is.target.subst ts [])) →
        DictEv.HasType D B C Γ (.impl i ts ds) (.dict is.cls (is.target.subst ts []))
    | local {C Γ j cl τ} : Γ[j]? = some (some (.dict cl τ)) →
        DictEv.HasType D B C Γ (.local j) (.dict cl τ)
    | clause {C Γ s i depth cl τ} : Γ[depth + s.slot i]? = some (some (.dict cl τ)) →
        DictEv.HasType D B C Γ (.clause s i depth) (.dict cl τ)
    | super {C Γ d cl τ cd s} :
        DictEv.HasType D B C Γ d (.dict cl τ) → D.classes cl = some cd → s ∈ cd.supers →
        Ty.Declared D.core C Γ τ →
        DictEv.HasType D B C Γ (.super d s) (.dict s τ)

  inductive DictEv.HasTypes (D : Declarations) (B : Builtins) : TypeCtx → Ctx → List DictEv → List Ty → Prop
    | nil {C Γ} : DictEv.HasTypes D B C Γ [] []
    | cons {C Γ d ds a as} :
        DictEv.HasType D B C Γ d a → DictEv.HasTypes D B C Γ ds as →
        DictEv.HasTypes D B C Γ (d :: ds) (a :: as)
end

mutual
  /-- 呼出しの実引数の値。脱糖が束縛した変数、元の文脈 Γ0 で型付けた辞書を k 個の束縛の下へ移した値、脱糖が置く定数、
  またはそれらを要素とするリストである。 -/
  inductive ArgVal (D : Declarations) (B : Builtins) (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) :
      Val → Ty → Prop
    | var {j a} : Γ[j]? = some (some a) → Ordinary a → ArgVal D B C Γ0 k Γ Φ (.var j) a
    | dict {d a} : DictEv.HasType D B C Γ0 d a →
        ArgVal D B C Γ0 k Γ Φ (d.toVal.rename (· + k)) (a.shiftV k 0)
    | const {c} : ConstOK B c → ArgVal D B C Γ0 k Γ Φ (.const c) c.type
    | list {vs a} : Ty.Annotation D.core C Γ a → ArgElems D B C Γ0 k Γ Φ vs a →
        ArgVal D B C Γ0 k Γ Φ (.list vs) (.list a)
    /-- 値の観測から篩を導入する。値の項について篩が事実から導けることを求める（核の V-Refine）。 -/
    | refine {v a q t s} : ArgVal D B C Γ0 k Γ Φ v a → v.toTerm? = some t → a.HasSort s →
        Pred.Sorted Γ (some a) q → Pred.WF (Γ.length + 1) q → Entails (Γ.facts ++ Φ) (q.open t) →
        Ty.Declared D.core C Γ a → Pred.Declared D.core C Γ (some a) q →
        ArgVal D B C Γ0 k Γ Φ v (.refined a q)

  /-- リストの要素の値。各要素は自分の型から要素の型へ部分型で入る。 -/
  inductive ArgElems (D : Declarations) (B : Builtins) (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) :
      List Val → Ty → Prop
    | nil {a} : ArgElems D B C Γ0 k Γ Φ [] a
    | cons {v b a vs} : ArgVal D B C Γ0 k Γ Φ v b → Ty.LeQ D.core Γ Φ b a → ArgElems D B C Γ0 k Γ Φ vs a →
        ArgElems D B C Γ0 k Γ Φ (v :: vs) a
end

/-- 実引数の値の列を依存列に沿って渡す。各値は自分の型から引数の型へ部分型で入り、後続の型は渡した値で具体化する。 -/
inductive ValsTel (D : Declarations) (B : Builtins) (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) :
    List Val → Tel → Ty → Eff → Prop
  | done {a e} : Ty.Annotation D.core C Γ (.dependentFn (.done a e)) →
      ValsTel D B C Γ0 k Γ Φ [] (.done a e) a e
  | param {name a rest v av vs r e} : Ty.Annotation D.core C Γ a → ArgVal D B C Γ0 k Γ Φ v av →
      Ty.LeQ D.core Γ Φ av a →
      ValsTel D B C Γ0 k Γ Φ vs (Tel.bind (Tel.argumentsEnv v) rest) r e →
      ValsTel D B C Γ0 k Γ Φ (v :: vs) (.param name a rest) r e

/-- 実引数の値の列を、依存しない型の列へ一つずつ部分型で渡す。 -/
inductive ValsTys (D : Declarations) (B : Builtins) (C : TypeCtx) (Γ0 : Ctx) (k : Nat) (Γ : Ctx) (Φ : List Pred) :
    List Val → List Ty → Prop
  | nil : ValsTys D B C Γ0 k Γ Φ [] []
  | cons {v av a vs as} : Ty.Annotation D.core C Γ a → ArgVal D B C Γ0 k Γ Φ v av → Ty.LeQ D.core Γ Φ av a →
      ValsTys D B C Γ0 k Γ Φ vs as → ValsTys D B C Γ0 k Γ Φ (v :: vs) (a :: as)

/-- view が将来の構成子を許す data 型へ、未知の構成子を加えたプログラム。 -/
structure ViewFutureExtension (view : CoverageView) (P P' : Refinement.Program) : Prop where
  keep : ∀ c cd, P.cons c = some cd → P'.cons c = some cd
  future : ∀ c cd, P'.cons c = some cd → P.cons c = none → view cd.data = true
  same : P' = { P with cons := P'.cons }

/-- ソースの照合の網羅性。view が将来の形を許す data 型に未知の構成子を加えたどのプログラムでも網羅する。
既定の `closedView` では核の網羅性と同値である。 -/
def ViewExhaustive (D : Declarations) (view : CoverageView) (a : Ty) (ps : List Pat) : Prop :=
  ∀ P' : Refinement.Program, ViewFutureExtension view D.core P' → Exhaustive P' a ps

/-- 直接の呼出しの頭の型付け。頭の値を束縛せずに呼ぶ式（名前付き関数・組み込みの関数・操作・外部関数・メソッド）が、
辞書を含む全引数の依存列 t を持つ。辞書 ds は値の引数より前に渡す。 -/
inductive CallHeadTy (D : Declarations) (B : Builtins) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) :
    Expr → Tel → List DictEv → Prop
  | fn {f fd ts es rs} : D.funs f = some fd → fd.dictParams = [] → NamesWF fd.coreNames fd.coreParams →
      RangesFit rs fd.rangeParams →
      Admissible B C Γ.length (TypeCtx.constraints fd.tparams) fd.neffs
        (Qsig fd.coreParams fd.ret fd.eff) Q ts es fd.eff →
      SignatureInstance D.core C Γ (rangeTel rs fd.tel) (TypeCtx.kinds fd.tparams) ts es →
      CallHeadTy D B Q C Γ (.funName f ts es (rs.map RangeIx.fixed)) (instantiatedTel (rangeTel rs fd.tel) ts es) []
  | fnDicts {f fd ts es ds names ps rs} : D.funs f = some fd → fd.dictParams ≠ [] →
      NamesWF fd.coreNames fd.coreParams → RangesFit rs fd.rangeParams →
      Admissible B C Γ.length (TypeCtx.constraints fd.tparams) fd.neffs
        (Qsig fd.coreParams fd.ret fd.eff) Q ts es fd.eff →
      SignatureInstance D.core C Γ (rangeTel rs fd.tel) (TypeCtx.kinds fd.tparams) ts es →
      CallHeadTy D B Q C Γ (.funDicts f ts es ds names ps (rs.map RangeIx.fixed))
        (instantiatedTel (rangeTel rs fd.tel) ts es) ds
  | prim {b s ts es rs} : B.sig b = some s → B.RangeAdmissible b s rs →
      NamesWF s.names s.params → PrimitiveAdmissible C Γ.length s Q ts es →
      SignatureInstance D.core C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es →
      CallHeadTy D B Q C Γ (.primName b ts es (rs.map RangeIx.fixed))
        (instantiatedTel (Tel.instR rs s.tel) ts es) []
  | op {o od ts} : D.ops o = some od → od.dictParams = [] → NamesWF od.names od.params →
      SatAll B C ts od.tparams →
      SignatureInstance D.core C Γ od.tel (List.replicate od.tparams.length .value) ts [] →
      CallHeadTy D B Q C Γ (.opName o ts) (instantiatedTel od.tel ts []) []
  | opDicts {o od ts ds names ps} : D.ops o = some od → od.dictParams ≠ [] → NamesWF od.names od.params →
      SatAll B C ts od.tparams →
      SignatureInstance D.core C Γ od.tel (List.replicate od.tparams.length .value) ts [] →
      CallHeadTy D B Q C Γ (.opDicts o ts ds names ps) (instantiatedTel od.tel ts []) ds
  | meth {d cl τ cd m ms ss es us names ps} :
      DictEv.HasType D B C Γ d (.dict cl τ) → D.classes cl = some cd → cd.methods m = some ms →
      NamesWF ms.names ms.params → SatAll B C ss (TypeCtx.constraints ms.tparams) →
      SignatureInstance D.core C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es →
      MethodRowsAdmissible C Γ.length Q ms es →
      CallHeadTy D B Q C Γ (.methName d m ss es us names ps) (instantiatedTel ms.tel (ss ++ [τ]) es) us
  /-- 01-12「外部の型と関数」: 外部関数の名前。依存列は宣言の依存列を型引数で具体化したもので、辞書を持たない。 -/
  | external {f d ts} : D.core.externalFunction f = some d → ExternalCallAdmissible D.core B C d ts →
      CallHeadTy D B Q C Γ (.externalName f ts) (Tel.bind (typeEnv ts) d.parameters) []

/-- 選んだ組込みの操作一覧に属する発行専用の関数を、処理する節として書かない。
利用者の操作一覧を選んだラベルと、それ以外の種類の組込みはこの条件で断らない。 -/
def ClauseAllowed (D : Declarations) (B : Builtins) (o : OpRef) : Prop :=
  ∀ b s l bs, o = .prim b → B.sig b = some s → D.effects l = none →
    B.effects l = some bs → b ∈ bs → s.kind ≠ .pathBases

/-- 穴を含む引数のうち、固定の式の個数。 -/
def HoleArgs.fixedCount : HoleArgs → Nat
  | .nil => 0
  | .expr _ _ _ rest => rest.fixedCount + 1
  | .hole _ _ _ rest => rest.fixedCount

/-- 穴のラムダの本体で、固定の式を全て束縛した後の実引数の値（ソース順）。固定の式は右に残る固定の式の個数の変数、
穴は m 個の固定の式の下へ移したラムダの引数である。 -/
def HoleArgs.argVals (m : Nat) : HoleArgs → List Val
  | .nil => []
  | .expr _ _ _ rest => .var rest.fixedCount :: rest.argVals m
  | .hole _ _ _ rest => .var (rest.holeTypes.length + m) :: rest.argVals m

/-- 01-12「リストの展開」の連結の型付け。脱糖がすべての要素と展開の式を k 個の束縛にした文脈 Γ' で、展開の前の値・展開の
値・後の値から連結の結果を作る。空の側の連結は作らず、両側が非空なら最初の連結の結果を束縛して二度目を呼ぶ。
連結の頭 f は元の文脈 Γ で依存列 t と辞書 ds を持つ。 -/
inductive SpreadTy (D : Declarations) (B : Builtins) (C : TypeCtx) (Γ : Ctx) (t : Tel) (ds : List DictEv) (k : Nat)
    (Γ' : Ctx) (Φ' : List Pred) : List Val → Val → List Val → Ty → Eff → Prop
  | only {s b0 b e} : ArgVal D B C Γ k Γ' Φ' s b0 → Ty.LeQ D.core Γ' Φ' b0 b → Ty.Annotation D.core C Γ' b →
      SpreadTy D B C Γ t ds k Γ' Φ' [] s [] b e
  | front {s x xs r e' b e} :
      ValsTel D B C Γ k Γ' Φ' (ds.map (fun d => d.toVal.rename (· + k)) ++ [s, .list (x :: xs)]) (Tel.shiftV k 0 t) r e' →
      Ty.LeQ D.core Γ' Φ' r b → Eff.Covers Γ' Φ' e e' → Ty.Annotation D.core C Γ' b →
      SpreadTy D B C Γ t ds k Γ' Φ' [] s (x :: xs) b e
  | back {y ys s r e' b e} :
      ValsTel D B C Γ k Γ' Φ' (ds.map (fun d => d.toVal.rename (· + k)) ++ [.list (y :: ys), s]) (Tel.shiftV k 0 t) r e' →
      Ty.LeQ D.core Γ' Φ' r b → Eff.Covers Γ' Φ' e e' → Ty.Annotation D.core C Γ' b →
      SpreadTy D B C Γ t ds k Γ' Φ' (y :: ys) s [] b e
  | middle {y ys s x xs r1 e1 r2 e2 b e} :
      ValsTel D B C Γ k Γ' Φ' (ds.map (fun d => d.toVal.rename (· + k)) ++ [.list (y :: ys), s]) (Tel.shiftV k 0 t)
        r1 e1 →
      Ordinary r1 → Ty.Annotation D.core C Γ' r1 → Eff.Covers Γ' Φ' e e1 →
      ValsTel D B C Γ (k + 1) (Γ'.extend r1) (Φ'.map Pred.lift)
        (ds.map (fun d => d.toVal.rename (· + (k + 1))) ++ [.var 0, .list (Val.renameList (· + 1) (x :: xs))])
        (Tel.shiftV (k + 1) 0 t) r2 e2 →
      Ty.LeQ D.core (Γ'.extend r1) (Φ'.map Pred.lift) r2 (b.shiftV 1 0) →
      Eff.Covers (Γ'.extend r1) (Φ'.map Pred.lift) (Eff.shiftV 1 0 e) e2 → Ty.Annotation D.core C Γ' b →
      SpreadTy D B C Γ t ds k Γ' Φ' (y :: ys) s (x :: xs) b e

/-- 01-12「文字列補間」の連結。左の値と、depth 個の中間の束縛の下へ移した右の値を、文字列の連結の組み込みの関数で
左から結ぶ。最後の連結だけを束縛しない。 -/
inductive JoinTy (D : Declarations) (B : Builtins) (C : TypeCtx) (Γ0 : Ctx) (tadd : Tel) :
    Nat → Ctx → List Pred → Nat → Val → List Val → Eff → Prop
  | last {k Γ' Φ' depth left right r e' e} :
      ValsTel D B C Γ0 k Γ' Φ' [left, right.rename (· + depth)] (Tel.shiftV k 0 tadd) r e' →
      Ty.LeQ D.core Γ' Φ' r (.base .string) → Eff.Covers Γ' Φ' e e' →
      JoinTy D B C Γ0 tadd k Γ' Φ' depth left [right] e
  | step {k Γ' Φ' depth left right x xs r e' e} :
      ValsTel D B C Γ0 k Γ' Φ' [left, right.rename (· + depth)] (Tel.shiftV k 0 tadd) r e' →
      Ordinary r → Ty.Annotation D.core C Γ' r → Eff.Covers Γ' Φ' e e' →
      JoinTy D B C Γ0 tadd (k + 1) (Γ'.extend r) (Φ'.map Pred.lift) (depth + 1) (.var 0) (x :: xs) (Eff.shiftV 1 0 e) →
      JoinTy D B C Γ0 tadd k Γ' Φ' depth left (right :: x :: xs) e

/-- 補間の部分の連結。部分が無ければ空の文字列、一つならその値、二つ以上なら連結の組み込みの関数で結ぶ。 -/
inductive JoinPartsTy (D : Declarations) (B : Builtins) (Q : NoFailCtx) (C : TypeCtx) (Γ0 : Ctx) (opPrim : OpPrim) :
    Nat → Ctx → List Pred → List Val → Eff → Prop
  | empty {k Γ' Φ' e} : JoinPartsTy D B Q C Γ0 opPrim k Γ' Φ' [] e
  | single {k Γ' Φ' v b0 e} : ArgVal D B C Γ0 k Γ' Φ' v b0 → Ty.LeQ D.core Γ' Φ' b0 (.base .string) →
      JoinPartsTy D B Q C Γ0 opPrim k Γ' Φ' [v] e
  | many {k Γ' Φ' v x xs b tadd e} : opPrim (.binary .add) (.base .string) = some (b, []) →
      CallHeadTy D B Q C Γ0 (.primName b [] [] []) tadd [] →
      JoinTy D B C Γ0 tadd k Γ' Φ' 0 v (x :: xs) e →
      JoinPartsTy D B Q C Γ0 opPrim k Γ' Φ' (v :: x :: xs) e

/-- 01-12「文字列補間」の部分の型付け。式の値は束縛済みで、変換の頭 fs を元の文脈 Γ0 で型付ける。変換の結果を一つずつ
束縛し、集めた部分 acc を最後に連結する。 -/
inductive InterpTy (D : Declarations) (B : Builtins) (Q : NoFailCtx) (C : TypeCtx) (Γ0 : Ctx) (opPrim : OpPrim) :
    Nat → Ctx → List Pred → List InterpPart → List Val → Exprs → List Val → Eff → Prop
  | done {k Γ' Φ' vs fs acc e} : JoinPartsTy D B Q C Γ0 opPrim k Γ' Φ' acc e →
      InterpTy D B Q C Γ0 opPrim k Γ' Φ' [] vs fs acc e
  | text {k Γ' Φ' s ps vs fs acc e} :
      InterpTy D B Q C Γ0 opPrim k Γ' Φ' ps vs fs (if s = "" then acc else acc ++ [.const (.string s)]) e →
      InterpTy D B Q C Γ0 opPrim k Γ' Φ' (.text s :: ps) vs fs acc e
  | stringExpr {k Γ' Φ' ps v vs fs acc e} :
      InterpTy D B Q C Γ0 opPrim k Γ' Φ' ps vs fs (acc ++ [v]) e →
      InterpTy D B Q C Γ0 opPrim k Γ' Φ' (.stringExpr :: ps) (v :: vs) fs acc e
  | converted {k Γ' Φ' c ps v vs f fs acc t ds r e' e} :
      CallHeadTy D B Q C Γ0 f t ds →
      ValsTel D B C Γ0 k Γ' Φ' (ds.map (fun d => d.toVal.rename (· + k)) ++ [v]) (Tel.shiftV k 0 t) r e' →
      Ordinary r → Ty.Annotation D.core C Γ' r → Eff.Covers Γ' Φ' e e' →
      InterpTy D B Q C Γ0 opPrim (k + 1) (Γ'.extend r) (Φ'.map Pred.lift) ps (Val.renameList (· + 1) vs) fs
        (Val.renameList (· + 1) acc ++ [.var 0]) (Eff.shiftV 1 0 e) →
      InterpTy D B Q C Γ0 opPrim k Γ' Φ' (.converted c :: ps) (v :: vs) (.cons f fs) acc e
  | formatted {k Γ' Φ' c spec ps v vs f fs acc t ds r e' e} :
      CallHeadTy D B Q C Γ0 f t ds →
      ValsTel D B C Γ0 k Γ' Φ' (ds.map (fun d => d.toVal.rename (· + k)) ++ v :: spec.arguments) (Tel.shiftV k 0 t)
        r e' →
      Ordinary r → Ty.Annotation D.core C Γ' r → Eff.Covers Γ' Φ' e e' →
      InterpTy D B Q C Γ0 opPrim (k + 1) (Γ'.extend r) (Φ'.map Pred.lift) ps (Val.renameList (· + 1) vs) fs
        (Val.renameList (· + 1) acc ++ [.var 0]) (Eff.shiftV 1 0 e) →
      InterpTy D B Q C Γ0 opPrim k Γ' Φ' (.formatted c spec :: ps) (v :: vs) (.cons f fs) acc e

/-- 照合する値（腕の文脈の番号 0）の観測。値の型が sort を持つときだけ観測する。 -/
noncomputable def scrutObs (Γ : Ctx) : Option Term :=
  open Classical in if ∃ s, (Term.var 0).HasSort Γ s then some (.var 0) else none

mutual
  inductive HasTypeQ (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
      BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Position → Expr → Ty → Eff → Prop
    /-- 専用位置は通常値の環境から読まず、通常引数の効果だけを残す。 -/
    | E_BuilderOp {Δ C Γ Φ R p op i args kind as ε} :
        Δ[i]? = some (some kind) → Ty.Annotation D.core C Γ kind.contents →
        TypeArgsKinded D.core C [kind.contents] [.value] →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTys D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ) (boundVars as.length)
          (op.parameters (renameKind (· + as.length) kind)) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.builderOp op i args kind) (op.resultType kind) ε
    /-- 01-12「名前とリテラル」: 局所の束縛の名前 x。 -/
    | E_Local {Δ C Γ Φ R p i a} :
        Γ[i]? = some (some a) → Ordinary a →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.local i) a Eff.empty
    /-- 01-06「定数の型」: 局所の値をすべて隠した同じ長さの文脈で本体を型付ける。 -/
    | E_Const {Δ C Γ Φ R p a body} :
        HasTypeQ D B opPrim Q [] C (Γ.map fun _ => none) [] R .other body a Eff.empty →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.constE a body) a Eff.empty
    /-- 01-12「名前とリテラル」: トップレベルの関数 f。辞書の引数を持たない関数に限る。 -/
    | E_Fun {Δ C Γ Φ R p f ts es rs t} :
        CallHeadTy D B Q C Γ (.funName f ts es rs) t [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.funName f ts es rs) (.dependentFn t) Eff.empty
    /-- 01-12「型クラス」の表の第 4 行: return λ(ȳ:Ā). f[T̄; Ē](Ū, ȳ)。Ā は値の引数だけ。 -/
    | E_FunDicts {Δ C Γ Φ R p f ts es ds names ps rs t r ε r' e'} :
        CallHeadTy D B Q C Γ (.funDicts f ts es ds names ps rs) t ds →
        NamesWF names ps → Ty.Annotation D.core C Γ (.fn names ps r ε) →
        ValsTel D B C (hideConts Γ) ps.length (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (ds.map (fun d => d.toVal.rename (· + ps.length)) ++ boundVars ps.length)
          (Tel.shiftV ps.length 0 t) r' e' →
        Ty.LeQ D.core (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) r' (r.shiftV ps.length 0) →
        Eff.Covers (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) (Eff.shiftV ps.length 0 ε) e' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.funDicts f ts es ds names ps rs) (.fn names ps r ε) Eff.empty
    /-- 同表第 2 行: return λ(ȳ:Ā). V.m[S̄; Ē](Ū, ȳ)。 -/
    | E_MethName {Δ C Γ Φ R p d m ss es us names ps t r ε r' e'} :
        CallHeadTy D B Q C Γ (.methName d m ss es us names ps) t us →
        NamesWF names ps → Ty.Annotation D.core C Γ (.fn names ps r ε) →
        ValsTel D B C (hideConts Γ) ps.length (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (us.map (fun u => u.toVal.rename (· + ps.length)) ++ boundVars ps.length)
          (Tel.shiftV ps.length 0 t) r' e' →
        Ty.LeQ D.core (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) r' (r.shiftV ps.length 0) →
        Eff.Covers (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) (Eff.shiftV ps.length 0 ε) e' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.methName d m ss es us names ps) (.fn names ps r ε) Eff.empty
    /-- 01-12「名前とリテラル」: prelude の関数 M.g。型検査器が選んだ範囲の列で具体化する。 -/
    | E_Prim {Δ C Γ Φ R p b ts es rs t} :
        CallHeadTy D B Q C Γ (.primName b ts es rs) t [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.primName b ts es rs) (.dependentFn t) Eff.empty
    /-- 01-12「ハンドラ」: 標準 Fail.raise。 -/
    | E_Raise {Δ C Γ Φ R p t e} :
        Ty.Annotation D.core C Γ (.fn ["error"] [e] t (Eff.singleFail e)) →
        Ordinary t → Ordinary e → t.HasKind D.core (TypeCtx.kinds C) .value →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.raise t e) (.fn ["error"] [e] t (Eff.singleFail e)) Eff.empty
    /-- 型付け後の非再開の一節。C-Handle-Fail の写し。 -/
    | E_HandleFail {Δ C Γ Φ R p E t body clause eb rest ec} :
        HasBlockQ D B opPrim Q Δ C Γ Φ R .other body t eb →
        Eff.Sub eb (Eff.union (Eff.singleFail E) rest) → NoFail Q rest →
        Ty.Annotation D.core C Γ E → Ty.Annotation D.core C Γ t → RowAnnotations D.core C Γ [ec] →
        HasBlockQ D B opPrim Q [] (TypeCtx.valueParam :: C) (failureContext Γ E) (liftMany 2 Φ)
          (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) .other clause
          ((shiftTypes 1 0 t).shiftV 2 0) ((shiftRowsTypes 1 0 ec).shiftV 2 0) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.handleFail E t body clause) t (Eff.union rest ec)
    /-- 01-12「ハンドラ」: 操作を値として使う。 -/
    | E_Op {Δ C Γ Φ R p o ts t} :
        CallHeadTy D B Q C Γ (.opName o ts) t [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.opName o ts) (.dependentFn t) Eff.empty
    /-- 01-12「形式化した操作の制約と節の辞書」: 辞書を値の作成時に捕え、公開の引数だけをラムダで受ける。 -/
    | E_OpDicts {Δ C Γ Φ R p o ts ds names ps t r ε r' e'} :
        CallHeadTy D B Q C Γ (.opDicts o ts ds names ps) t ds →
        NamesWF names ps → Ty.Annotation D.core C Γ (.fn names ps r ε) →
        ValsTel D B C (hideConts Γ) ps.length (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (ds.map (fun d => d.toVal.rename (· + ps.length)) ++ boundVars ps.length)
          (Tel.shiftV ps.length 0 t) r' e' →
        Ty.LeQ D.core (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) r' (r.shiftV ps.length 0) →
        Eff.Covers (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) (Eff.shiftV ps.length 0 ε) e' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.opDicts o ts ds names ps) (.fn names ps r ε) Eff.empty
    /-- 01-12「外部の型と関数」: 外部関数を値として使う。 -/
    | E_ExternalName {Δ C Γ Φ R p f d ts} :
        D.core.externalFunction f = some d → ExternalCallAdmissible D.core B C d ts →
        SignatureInstance D.core C Γ d.parameters d.kinds ts [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.externalName f ts)
          (.dependentFn (instantiatedTel d.parameters ts [])) Eff.empty
    /-- 01-12「名前とリテラル」: 引数のない構成子。 -/
    | E_NullCon {Δ C Γ Φ R p c cd ts} :
        D.cons c = some cd → ts.length = cd.ntys → cd.args = [] →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) →
        Ty.Annotation D.core C Γ (.data cd.data ts) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.nullCon c ts) (.data cd.data ts) Eff.empty
    /-- 01-12「名前とリテラル」: 引数を持つ構成子を値として使う。 -/
    | E_ConValue {Δ C Γ Φ R p c cd ts names ps} :
        D.cons c = some cd → ts.length = cd.ntys →
        names = D.constructorNames c cd → NamesWF names ps →
        ps = cd.args.map (Ty.subst ts []) → ps ≠ [] →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Ty.Annotation D.core C Γ (.fn names ps (.data cd.data ts) Eff.empty) →
        ValsTys D B C Γ ps.length (bindParams (hideConts Γ) ps) (liftMany ps.length Φ) (boundVars ps.length)
          (cd.args.map (Ty.subst (shiftTs ps.length ts) [])) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.conValue c ts names ps)
          (.fn names ps (.data cd.data ts) Eff.empty) Eff.empty
    /-- 篩の導入: 脱糖が値をそのまま返す式は、その値の項について篩が事実から導けるとき篩付きの型を持つ
    （核の V-Refine）。 -/
    | E_Refine {Δ C Γ Φ R p e a q v t s ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R p e a ε → e.valueOf? = some v → v.toTerm? = some t → a.HasSort s →
        Pred.Sorted Γ (some a) q → Pred.WF (Γ.length + 1) q → Entails (Γ.facts ++ Φ) (q.open t) →
        Ty.Annotation D.core C Γ a → Pred.Declared D.core C Γ (some a) q →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p e (.refined a q) ε
    /-- 01-12「名前とリテラル」: リテラル。値域は核の定数の適格性で検査する。 -/
    | E_Literal {Δ C Γ Φ R p l} :
        ConstOK B l.toConst →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.literal l) l.toConst.type Eff.empty
    | E_NegInt {Δ C Γ Φ R p n} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.negInt n) (.base .integer) Eff.empty
    | E_NegFloat {Δ C Γ Φ R p x} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.negFloat x) (.base .float) Eff.empty
    | E_NegDecimal {Δ C Γ Φ R p n scale} :
        ConstOK B (.decimal (-n) scale) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.negDecimal n scale) (.base .decimal) Eff.empty
    | E_NegInteger8 {Δ C Γ Φ R p n} : ConstOK B (.integer8 (-Int.ofNat n)) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.negInteger8 n) (.base .integer8) Eff.empty
    | E_NegInteger16 {Δ C Γ Φ R p n} : ConstOK B (.integer16 (-Int.ofNat n)) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.negInteger16 n) (.base .integer16) Eff.empty
    | E_NegInteger32 {Δ C Γ Φ R p n} : ConstOK B (.integer32 (-Int.ofNat n)) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.negInteger32 n) (.base .integer32) Eff.empty
    | E_NegFloat32 {Δ C Γ Φ R p bits} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.negFloat32 bits) (.base .float32) Eff.empty
    | E_Unit {Δ C Γ Φ R p} : HasTypeQ D B opPrim Q Δ C Γ Φ R p .unit (.base .unit) Eff.empty
    | E_Block {Δ C Γ Φ R p body a ε} :
        HasBlockQ D B opPrim Q Δ C Γ Φ R p body a ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.block body) a ε
    | E_Paren {Δ C Γ Φ R p e a ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R p e a ε → HasTypeQ D B opPrim Q Δ C Γ Φ R p (.paren e) a ε
    /-- 01-05「レコード」: 評価は書いた順、型は各宣言の位置。 -/
    | E_Record {Δ C Γ Φ R p c cd ts positions args as ε} :
        D.cons c = some cd → ts.length = cd.ntys →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Ty.Annotation D.core C Γ (.data cd.data ts) →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTys D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
          (recordFields positions.length positions (boundVars as.length) (.const .unit))
          (cd.args.map (Ty.subst (shiftTs as.length ts) [])) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.record c ts positions args) (.data cd.data ts) ε
    /-- 01-05「レコード」: 型引数を base と共通にし、位置の重複と範囲外を排除する。 -/
    | E_RecordUpdate {Δ C Γ Φ R p c cd ts n positions base args as δ ε} :
        D.cons c = some cd → ts.length = cd.ntys → n = cd.args.length → positions.length = as.length →
        Ty.Annotation D.core C Γ (.data cd.data ts) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other base (.data cd.data ts) ε →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        AltsTy D.core [⟨recordUpdatePattern c n positions, List.range (recordUpdatePattern c n positions).binders⟩]
          ((Ty.data cd.data ts).shiftV (as.length + 1) 0) δ →
        ValsTys D B C (bindParams (bindParams Γ (.data cd.data ts :: as)) δ) 0
          (bindParams (bindParams Γ (.data cd.data ts :: as)) δ)
          (liftMany δ.length (liftMany (as.length + 1) Φ))
          (recordUpdateValues c n positions (boundVars as.length))
          (cd.args.map (Ty.subst (shiftTs (as.length + 1 + δ.length) ts) [])) →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Exhaustive D.core (.data cd.data ts) [recordUpdatePattern c n positions] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.recordUpdate c ts n positions base args) (.data cd.data ts) ε
    /-- 01-05「レコード」の欄の依存: 欄の篩を record 全体の篩へ写した型で構築する。束縛した欄の値から作る
    構成子の項について全体の篩が導けることを求める。 -/
    | E_RecordRefined {Δ C Γ Φ R p c cd rd ts positions args as ε} :
        D.records c = some rd → D.cons c = some cd → ts.length = cd.ntys →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Ty.Annotation D.core C Γ (.refined (.data cd.data ts) (rd.refinement c)) →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTys D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
          (recordFields positions.length positions (boundVars as.length) (.const .unit))
          (cd.args.map (Ty.subst (shiftTs as.length ts) [])) →
        Entails ((bindParams Γ as).facts ++ liftMany as.length Φ)
          ((liftRef as.length (rd.refinement c)).open
            (.dataValue c (Val.toTermSlots (recordFields positions.length positions (boundVars as.length) (.const .unit))))) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.record c ts positions args) (.refined (.data cd.data ts) (rd.refinement c)) ε
    /-- 同じ欄の依存を持つ record の更新。書き換えた後の構成子の項について全体の篩が導けることを求める。 -/
    | E_RecordUpdateRefined {Δ C Γ Φ R p c cd rd ts n positions base args as δ ε} :
        D.records c = some rd → D.cons c = some cd → ts.length = cd.ntys → n = cd.args.length →
        positions.length = as.length →
        Ty.Annotation D.core C Γ (.refined (.data cd.data ts) (rd.refinement c)) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other base (.data cd.data ts) ε →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        AltsTy D.core [⟨recordUpdatePattern c n positions, List.range (recordUpdatePattern c n positions).binders⟩]
          ((Ty.data cd.data ts).shiftV (as.length + 1) 0) δ →
        ValsTys D B C (bindParams (bindParams Γ (.data cd.data ts :: as)) δ) 0
          (bindParams (bindParams Γ (.data cd.data ts :: as)) δ)
          (liftMany δ.length (liftMany (as.length + 1) Φ))
          (recordUpdateValues c n positions (boundVars as.length))
          (cd.args.map (Ty.subst (shiftTs (as.length + 1 + δ.length) ts) [])) →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Exhaustive D.core (.data cd.data ts) [recordUpdatePattern c n positions] →
        Entails ((bindParams (bindParams Γ (.data cd.data ts :: as)) δ).facts ++
            liftMany δ.length (liftMany (as.length + 1) Φ))
          ((liftRef (as.length + 1 + δ.length) (rd.refinement c)).open
            (.dataValue c (Val.toTermSlots (recordUpdateValues c n positions (boundVars as.length))))) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.recordUpdate c ts n positions base args)
          (.refined (.data cd.data ts) (rd.refinement c)) ε
    /-- 01-12「呼び出し」: 構成子の呼び出し。 -/
    | E_ConCall {Δ C Γ Φ R p c cd ts args as ε} :
        D.cons c = some cd → ts.length = cd.ntys →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Ty.Annotation D.core C Γ (.data cd.data ts) →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTys D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ) (boundVars as.length)
          (cd.args.map (Ty.subst (shiftTs as.length ts) [])) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.conCall c ts args) (.data cd.data ts) ε
    /-- 01-12「呼び出し」: 直接の頭の呼び出し。頭は束縛せず、引数を書いた順に束縛してから宣言の位置順に渡す。 -/
    | E_CallDirect {Δ C Γ Φ R p f labels positions args t ds as r e b ε} :
        CallHeadTy D B Q C Γ f t ds →
        CallOk ((t.names).drop ds.length) (telBinders t - ds.length) false labels positions →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTel D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
          (ds.map (fun d => d.toVal.rename (· + as.length)) ++
            recordFields as.length positions (boundVars as.length) (.const .unit))
          (Tel.shiftV as.length 0 t) r e →
        Ty.LeQ D.core (bindParams Γ as) (liftMany as.length Φ) r (b.shiftV as.length 0) →
        Eff.Covers (bindParams Γ as) (liftMany as.length Φ) (Eff.shiftV as.length 0 ε) e →
        Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.call f labels positions args) b ε
    /-- 01-12「外部の型と関数」: 外部関数の直接の呼出し。引数を書いた順に束縛してから宣言の位置順に渡す。 -/
    | E_CallExternal {Δ C Γ Φ R p f d ts labels positions args as r e b ε} :
        D.core.externalFunction f = some d → ExternalCallAdmissible D.core B C d ts →
        CallOk (d.parameters.names) (telBinders d.parameters) false labels positions →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTel D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ)
          (recordFields as.length positions (boundVars as.length) (.const .unit))
          (Tel.bind (typeEnv ts) d.parameters) r e →
        Ty.LeQ D.core (bindParams Γ as) (liftMany as.length Φ) r (b.shiftV as.length 0) →
        Eff.Covers (bindParams Γ as) (liftMany as.length Φ) (Eff.shiftV as.length 0 ε) e →
        Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.call (.externalName f ts) labels positions args) b ε
    /-- 01-12「呼び出し」: そのほかの呼び出し。呼ぶ値を先に束縛する。 -/
    | E_Call {Δ C Γ Φ R p f labels positions args t as r e b ε} :
        directCallee f = none →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other f (.dependentFn t) ε →
        CallOk t.names (telBinders t) false labels positions →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTel D B C Γ (as.length + 1) (bindParams Γ (.dependentFn t :: as)) (liftMany (as.length + 1) Φ)
          (recordFields as.length positions (boundVars as.length) (.const .unit))
          (Tel.shiftV (as.length + 1) 0 t) r e →
        Ty.LeQ D.core (bindParams Γ (.dependentFn t :: as)) (liftMany (as.length + 1) Φ) r
          (b.shiftV (as.length + 1) 0) →
        Eff.Covers (bindParams Γ (.dependentFn t :: as)) (liftMany (as.length + 1) Φ)
          (Eff.shiftV (as.length + 1) 0 ε) e →
        Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.call f labels positions args) b ε
    /-- 01-02「パイプ」: 左辺を先に束縛し、構成子の最初の欄に渡す。 -/
    | E_PipeConCall {Δ C Γ Φ R p lhs c cd ts args tl as ε} :
        D.cons c = some cd → ts.length = cd.ntys →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Ty.Annotation D.core C Γ (.data cd.data ts) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs tl ε →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTys D B C Γ (as.length + 1) (bindParams Γ (tl :: as)) (liftMany (as.length + 1) Φ)
          (.var as.length :: boundVars as.length) (cd.args.map (Ty.subst (shiftTs (as.length + 1) ts) [])) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.pipe lhs (.conCall c ts args)) (.data cd.data ts) ε
    /-- 同規則の裸の構成子名: 左辺を一引数の構成子に渡す。 -/
    | E_PipeConValue {Δ C Γ Φ R p lhs c cd ts names ps tl ε} :
        D.cons c = some cd → ts.length = cd.ntys →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Ty.Annotation D.core C Γ (.data cd.data ts) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs tl ε →
        ValsTys D B C Γ 1 (bindParams Γ [tl]) (liftMany 1 Φ) [.var 0] (cd.args.map (Ty.subst (shiftTs 1 ts) [])) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.pipe lhs (.conValue c ts names ps)) (.data cd.data ts) ε
    /-- 同規則の直接の頭の呼出し。左辺を位置 0 に挿入し、残る引数を書いた順に束縛する。 -/
    | E_PipeCallDirect {Δ C Γ Φ R p lhs f labels positions args tl t ds as r e b ε} :
        CallHeadTy D B Q C Γ f t ds →
        CallOk ((t.names).drop ds.length) (telBinders t - ds.length) true labels positions →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs tl ε →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTel D B C Γ (as.length + 1) (bindParams Γ (tl :: as)) (liftMany (as.length + 1) Φ)
          (ds.map (fun d => d.toVal.rename (· + (as.length + 1))) ++
            recordFields (as.length + 1) (0 :: positions) (.var as.length :: boundVars as.length) (.const .unit))
          (Tel.shiftV (as.length + 1) 0 t) r e →
        Ty.LeQ D.core (bindParams Γ (tl :: as)) (liftMany (as.length + 1) Φ) r (b.shiftV (as.length + 1) 0) →
        Eff.Covers (bindParams Γ (tl :: as)) (liftMany (as.length + 1) Φ) (Eff.shiftV (as.length + 1) 0 ε) e →
        Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.pipe lhs (.call f labels positions args)) b ε
    /-- 同規則のそのほかの呼出し。左辺、呼ぶ値、引数の順に束縛する。 -/
    | E_PipeCall {Δ C Γ Φ R p lhs f labels positions args tl t as r e b ε} :
        directCallee f = none →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs tl ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other f (.dependentFn t) ε →
        CallOk t.names (telBinders t) true labels positions →
        HasTypesQ D B opPrim Q Δ C Γ Φ R args as ε →
        ValsTel D B C Γ (as.length + 2) (bindParams Γ (tl :: .dependentFn t :: as)) (liftMany (as.length + 2) Φ)
          (recordFields (as.length + 1) (0 :: positions) (.var (as.length + 1) :: boundVars as.length) (.const .unit))
          (Tel.shiftV (as.length + 2) 0 t) r e →
        Ty.LeQ D.core (bindParams Γ (tl :: .dependentFn t :: as)) (liftMany (as.length + 2) Φ) r
          (b.shiftV (as.length + 2) 0) →
        Eff.Covers (bindParams Γ (tl :: .dependentFn t :: as)) (liftMany (as.length + 2) Φ)
          (Eff.shiftV (as.length + 2) 0 ε) e →
        Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.pipe lhs (.call f labels positions args)) b ε
    /-- 同規則 2 の直接の頭: 左辺だけを渡す。 -/
    | E_PipeApplyDirect {Δ C Γ Φ R p lhs rhs tl t ds r e b ε} :
        rhs.PipeValue → CallHeadTy D B Q C Γ rhs t ds →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs tl ε →
        ValsTel D B C Γ 1 (bindParams Γ [tl]) (liftMany 1 Φ)
          (ds.map (fun d => d.toVal.rename (· + 1)) ++ [.var 0]) (Tel.shiftV 1 0 t) r e →
        Ty.LeQ D.core (bindParams Γ [tl]) (liftMany 1 Φ) r (b.shiftV 1 0) →
        Eff.Covers (bindParams Γ [tl]) (liftMany 1 Φ) (Eff.shiftV 1 0 ε) e →
        Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.pipe lhs rhs) b ε
    /-- 同規則 2: 呼ぶ値を左辺の後に束縛して、左辺だけを渡す。 -/
    | E_PipeApply {Δ C Γ Φ R p lhs rhs tl t r e b ε} :
        rhs.PipeValue → directCallee rhs = none →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs tl ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other rhs (.dependentFn t) ε →
        ValsTel D B C Γ 2 (bindParams Γ [tl, .dependentFn t]) (liftMany 2 Φ) [.var 1] (Tel.shiftV 2 0 t) r e →
        Ty.LeQ D.core (bindParams Γ [tl, .dependentFn t]) (liftMany 2 Φ) r (b.shiftV 2 0) →
        Eff.Covers (bindParams Γ [tl, .dependentFn t]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) e →
        Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.pipe lhs rhs) b ε
    /-- 01-12「表層からの脱糖」の前段: 直接の頭の部分適用 f(a1,…,_,…,an)。穴を引数とするラムダを作り、本体で固定の式を
    書いた順に束縛してから頭を宣言の位置順に呼ぶ。固定の式はラムダの本体の中で、継続を隠した元の文脈で型付ける。 -/
    | E_PartialCallDirect {Δ C Γ Φ R p f names args r ε t ds as r' e'} :
        args.holeTypes ≠ [] → CallHeadTy D B Q C Γ f t ds →
        CallOk ((t.names).drop ds.length) (telBinders t - ds.length) false args.labels args.positions →
        NamesWF (args.holeNames names) args.holeTypes →
        Ty.Annotation D.core C Γ (.fn (args.holeNames names) args.holeTypes r ε) →
        HasFixedQ D B opPrim Q [] C (hideConts Γ) Φ (some r) args as ε →
        ValsTel D B C Γ (args.holeTypes.length + as.length)
          (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ))
          (ds.map (fun d => d.toVal.rename (· + (args.holeTypes.length + as.length))) ++
            recordFields args.positions.length args.positions (args.argVals as.length) (.const .unit))
          (Tel.shiftV (args.holeTypes.length + as.length) 0 t) r' e' →
        Ty.LeQ D.core (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ)) r' (r.shiftV (args.holeTypes.length + as.length) 0) →
        Eff.Covers (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ))
          (Eff.shiftV (args.holeTypes.length + as.length) 0 ε) e' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p
          (.partialCall f names args (r.shiftV args.holeTypes.length 0) (Eff.shiftV args.holeTypes.length 0 ε))
          (.fn (args.holeNames names) args.holeTypes r ε) Eff.empty
    /-- 同前段: 値の部分適用。呼ぶ値をラムダの本体で先に一度だけ評価する。 -/
    | E_PartialCall {Δ C Γ Φ R p f names args r ε t as r' e'} :
        directCallee f = none → args.holeTypes ≠ [] →
        HasTypeQ D B opPrim Q [] C (hideConts Γ) Φ (some r) .other f (.dependentFn t) ε →
        CallOk t.names (telBinders t) false args.labels args.positions →
        NamesWF (args.holeNames names) args.holeTypes →
        Ty.Annotation D.core C Γ (.fn (args.holeNames names) args.holeTypes r ε) →
        HasFixedQ D B opPrim Q [] C (hideConts Γ) Φ (some r) args as ε →
        ValsTel D B C Γ (args.holeTypes.length + (as.length + 1))
          (bindParams (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
          (recordFields args.positions.length args.positions (args.argVals (as.length + 1)) (.const .unit))
          (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t) r' e' →
        Ty.LeQ D.core (bindParams (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) r'
          (r.shiftV (args.holeTypes.length + (as.length + 1)) 0) →
        Eff.Covers (bindParams (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
          (Eff.shiftV (args.holeTypes.length + (as.length + 1)) 0 ε) e' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p
          (.partialCall f names args (r.shiftV args.holeTypes.length 0) (Eff.shiftV args.holeTypes.length 0 ε))
          (.fn (args.holeNames names) args.holeTypes r ε) Eff.empty
    /-- 同前段: 結果型か効果が穴の値を参照する直接の頭の部分適用。穴を引数とし、結果を穴の束縛の下で読む依存する
    ラムダを作る。固定の式は戻り値型を持たない継続を隠した元の文脈で型付け、その効果は結果の効果に被覆される。 -/
    | E_PartialCallDirectDep {Δ C Γ Φ R p f names args ret eff εf t ds as r' e'} :
        args.holeTypes ≠ [] → CallHeadTy D B Q C Γ f t ds →
        CallOk ((t.names).drop ds.length) (telBinders t - ds.length) false args.labels args.positions →
        NamesWF (args.holeNames names) args.holeTypes →
        (¬ ∃ (r0 : Ty) (e0 : Eff), ret = r0.shiftV args.holeTypes.length 0 ∧
          eff = Eff.shiftV args.holeTypes.length 0 e0) →
        Ty.Annotation D.core C Γ (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) →
        Ty.Annotation D.core C (bindParams (hideConts Γ) args.holeTypes) ret →
        HasFixedQ D B opPrim Q [] C (hideConts Γ) Φ none args as εf →
        Eff.Covers (bindParams (hideConts Γ) args.holeTypes) (liftMany args.holeTypes.length Φ) eff
          (Eff.shiftV args.holeTypes.length 0 εf) →
        ValsTel D B C Γ (args.holeTypes.length + as.length)
          (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ))
          (ds.map (fun d => d.toVal.rename (· + (args.holeTypes.length + as.length))) ++
            recordFields args.positions.length args.positions (args.argVals as.length) (.const .unit))
          (Tel.shiftV (args.holeTypes.length + as.length) 0 t) r' e' →
        Ty.LeQ D.core (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ)) r' (ret.shiftV as.length 0) →
        Eff.Covers (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ)) (Eff.shiftV as.length 0 eff) e' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.partialCall f names args ret eff)
          (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) Eff.empty
    /-- 同前段: 結果型か効果が穴の値を参照する値の部分適用。 -/
    | E_PartialCallDep {Δ C Γ Φ R p f names args ret eff εf t as r' e'} :
        directCallee f = none → args.holeTypes ≠ [] →
        HasTypeQ D B opPrim Q [] C (hideConts Γ) Φ none .other f (.dependentFn t) εf →
        CallOk t.names (telBinders t) false args.labels args.positions →
        NamesWF (args.holeNames names) args.holeTypes →
        (¬ ∃ (r0 : Ty) (e0 : Eff), ret = r0.shiftV args.holeTypes.length 0 ∧
          eff = Eff.shiftV args.holeTypes.length 0 e0) →
        Ty.Annotation D.core C Γ (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) →
        Ty.Annotation D.core C (bindParams (hideConts Γ) args.holeTypes) ret →
        HasFixedQ D B opPrim Q [] C (hideConts Γ) Φ none args as εf →
        Eff.Covers (bindParams (hideConts Γ) args.holeTypes) (liftMany args.holeTypes.length Φ) eff
          (Eff.shiftV args.holeTypes.length 0 εf) →
        ValsTel D B C Γ (args.holeTypes.length + (as.length + 1))
          (bindParams (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ))
          (recordFields args.positions.length args.positions (args.argVals (as.length + 1)) (.const .unit))
          (Tel.shiftV (args.holeTypes.length + (as.length + 1)) 0 t) r' e' →
        Ty.LeQ D.core (bindParams (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) r' (ret.shiftV (as.length + 1) 0) →
        Eff.Covers (bindParams (bindParams (hideConts Γ) args.holeTypes)
            ((Ty.dependentFn t :: as).map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany (as.length + 1) (liftMany args.holeTypes.length Φ)) (Eff.shiftV (as.length + 1) 0 eff) e' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.partialCall f names args ret eff)
          (.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) Eff.empty
    /-- 同前段: 構成子の部分適用 T.C(a1,…,_,…,an)。実引数は位置の順に構成子へ渡す。 -/
    | E_PartialCon {Δ C Γ Φ R p c cd ts args r ε as} :
        D.cons c = some cd → ts.length = cd.ntys → args.holeTypes ≠ [] → args.ConstructorOk cd.args.length →
        NamesWF (args.holeNames (positionalNames args.positions.length)) args.holeTypes →
        TypeArgsKinded D.core C ts (List.replicate cd.ntys .value) → (∀ t ∈ cd.args, t.WF 0 cd.ntys 0) →
        Ty.Annotation D.core C Γ (.data cd.data ts) →
        Ty.Annotation D.core C Γ (.fn (args.holeNames (positionalNames args.positions.length)) args.holeTypes r ε) →
        HasFixedQ D B opPrim Q [] C (hideConts Γ) Φ (some r) args as ε →
        ValsTys D B C Γ (args.holeTypes.length + as.length)
          (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ)) (args.argVals as.length)
          (cd.args.map (Ty.subst (shiftTs (args.holeTypes.length + as.length) ts) [])) →
        Ty.LeQ D.core (bindParams (bindParams (hideConts Γ) args.holeTypes) (as.map (Ty.shiftV args.holeTypes.length 0)))
          (liftMany as.length (liftMany args.holeTypes.length Φ))
          (.data cd.data (shiftTs (args.holeTypes.length + as.length) ts))
          (r.shiftV (args.holeTypes.length + as.length) 0) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.partialCon c ts args)
          (.fn (args.holeNames (positionalNames args.positions.length)) args.holeTypes r ε) Eff.empty
    /-- 01-12「演算子」: e1 ⊕ e2。表の組み込みの関数を二つの束縛した値で呼ぶ。 -/
    | E_Binary {Δ C Γ Φ R p o t b s ts lhs rhs r e a ε} :
        (Operator.binary o).allowed t = true →
        opPrim (.binary o) t = some (b, ts) → ts = (Operator.binary o).typeArgs t →
        CallHeadTy D B Q C Γ (.primName b ts [] []) s [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs t ε → HasTypeQ D B opPrim Q Δ C Γ Φ R .other rhs t ε →
        ValsTel D B C Γ 2 (bindParams Γ [t, t]) (liftMany 2 Φ) [.var 1, .var 0] (Tel.shiftV 2 0 s) r e →
        Ty.LeQ D.core (bindParams Γ [t, t]) (liftMany 2 Φ) r (a.shiftV 2 0) →
        Eff.Covers (bindParams Γ [t, t]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) e →
        Ty.Annotation D.core C Γ a →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.binary o t lhs rhs) a ε
    /-- 01-12「演算子」: -e。 -/
    | E_Neg {Δ C Γ Φ R p t b s ts e0 r e ε} :
        Operator.neg.allowed t = true → opPrim .neg t = some (b, ts) → ts = [] →
        CallHeadTy D B Q C Γ (.primName b ts [] []) s [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e0 t ε →
        ValsTel D B C Γ 1 (bindParams Γ [t]) (liftMany 1 Φ) [.var 0] (Tel.shiftV 1 0 s) r e →
        Ty.LeQ D.core (bindParams Γ [t]) (liftMany 1 Φ) r (t.shiftV 1 0) →
        Eff.Covers (bindParams Γ [t]) (liftMany 1 Φ) (Eff.shiftV 1 0 ε) e →
        Ty.Annotation D.core C Γ t →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.neg t e0) t ε
    /-- 01-12「演算子」: not e。 -/
    | E_Not {Δ C Γ Φ R p e a ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e a ε →
        Ordinary a → Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.not e) (.base .boolean) ε
    /-- 01-12「演算子」: e1 and e2。右辺は左辺が真である事実の下で型付けてよい。 -/
    | E_And {Δ C Γ Φ R p lhs rhs a Φr ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs a ε →
        Ordinary a → Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean) →
        (∀ q ∈ Φr, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0)) →
        HasTypeQ D B opPrim Q Δ C Γ Φr R p rhs (.base .boolean) ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.and lhs rhs) (.base .boolean) ε
    /-- 01-12「演算子」: e1 or e2。右辺は左辺が偽である事実の下で型付けてよい。 -/
    | E_Or {Δ C Γ Φ R p lhs rhs a Φr ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other lhs a ε →
        Ordinary a → Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean) →
        (∀ q ∈ Φr, Entails ((Γ.extend a).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (q.shiftV 1 0)) →
        HasTypeQ D B opPrim Q Δ C Γ Φr R p rhs (.base .boolean) ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.or lhs rhs) (.base .boolean) ε
    /-- 01-12「リスト、ラムダ、条件分岐、match」: [e1,…,en]。 -/
    | E_List {Δ C Γ Φ R p a es as ε} :
        Ty.Annotation D.core C Γ a → HasTypesQ D B opPrim Q Δ C Γ Φ R es as ε →
        ValsTys D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ) (boundVars as.length)
          (List.replicate as.length (a.shiftV as.length 0)) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.list a es) (.list a) ε
    /-- 同節の篩の導入: 要素を束縛した後のリストの値の項について篩が事実から導けるとき、篩付きのリストの型を持つ。 -/
    | E_ListRefined {Δ C Γ Φ R p a es as q ε} :
        Ty.Annotation D.core C Γ (.refined (.list a) q) → HasTypesQ D B opPrim Q Δ C Γ Φ R es as ε →
        ValsTys D B C Γ as.length (bindParams Γ as) (liftMany as.length Φ) (boundVars as.length)
          (List.replicate as.length (a.shiftV as.length 0)) →
        Entails ((bindParams Γ as).facts ++ liftMany as.length Φ)
          ((liftRef as.length q).open (.listValue (Val.toTermSlots (boundVars as.length)))) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.list a es) (.refined (.list a) q) ε
    /-- 01-12「リストの展開」: 前の要素・展開の式・後の要素を書いた順に束縛し、連結の頭で結果のリストを作る。 -/
    | E_ListSpread {Δ C Γ Φ R p a f before s after bs ts as t ds ε} :
        CallHeadTy D B Q C Γ f t ds → Ty.Annotation D.core C Γ (.list a) →
        HasTypesQ D B opPrim Q Δ C Γ Φ R before bs ε → HasTypeQ D B opPrim Q Δ C Γ Φ R .other s ts ε →
        HasTypesQ D B opPrim Q Δ C Γ Φ R after as ε →
        SpreadTy D B C Γ t ds (bs.length + (as.length + 1)) (bindParams Γ (bs ++ ts :: as))
          (liftMany (bs.length + (as.length + 1)) Φ)
          (Val.renameList (· + (as.length + 1)) (boundVars bs.length)) (.var as.length) (boundVars as.length)
          ((Ty.list a).shiftV (bs.length + (as.length + 1)) 0) (Eff.shiftV (bs.length + (as.length + 1)) 0 ε) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.listSpread a f before s after) (.list a) ε
    /-- 01-12「文字列補間」: 式を書いた順に束縛し、変換の結果を束縛してから部分を左から連結する。 -/
    | E_Interpolation {Δ C Γ Φ R p parts es fs as ε} :
        InterpPart.Allowed parts → as = InterpPart.exprTypes parts →
        HasTypesQ D B opPrim Q Δ C Γ Φ R es as ε →
        InterpTy D B Q C Γ opPrim as.length (bindParams Γ as) (liftMany as.length Φ) parts (boundVars as.length) fs []
          (Eff.shiftV as.length 0 ε) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.interpolation parts es fs) (.base .string) ε
    /-- 01-12 同節: lambda(x̄) B。引数は外側の文脈の型を持つ。 -/
    | E_Lam {Δ C Γ Φ R p names ps r ε body} :
        NamesWF names ps → Ty.Annotation D.core C Γ (.fn names ps r ε) →
        HasBlockQ D B opPrim Q [] C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) .tail body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.lam names ps r ε body) (.fn names ps r ε) Eff.empty
    /-- 01-12 同節: if e then B1 else B2。各枝は条件の真偽から導ける事実の下で型付けてよい。 -/
    | E_If {Δ C Γ Φ R p cond yes no a b Φy Φn ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other cond a ε →
        Ordinary a → Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean) →
        (∀ q ∈ Φy, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0)) →
        (∀ q ∈ Φn, Entails ((Γ.extend a).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (q.shiftV 1 0)) →
        HasBlockQ D B opPrim Q Δ C Γ Φy R p yes b ε → HasBlockQ D B opPrim Q Δ C Γ Φn R p no b ε →
        Ty.Declared D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.ite cond yes no) b ε
    /-- 01-12 同節: else if。 -/
    | E_ElseIf {Δ C Γ Φ R p cond yes no a b Φy Φn ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other cond a ε →
        Ordinary a → Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean) →
        (∀ q ∈ Φy, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0)) →
        (∀ q ∈ Φn, Entails ((Γ.extend a).facts ++ boolCond (.var 0) false :: Φ.map Pred.lift) (q.shiftV 1 0)) →
        HasBlockQ D B opPrim Q Δ C Γ Φy R p yes b ε → HasTypeQ D B opPrim Q Δ C Γ Φn R p no b ε →
        Ty.Declared D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.elseIf cond yes no) b ε
    /-- 01-12 同節: else なし。 -/
    | E_IfOnly {Δ C Γ Φ R p cond yes a Φy ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other cond a ε →
        Ordinary a → Ty.LeQ D.core (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean) →
        (∀ q ∈ Φy, Entails ((Γ.extend a).facts ++ boolCond (.var 0) true :: Φ.map Pred.lift) (q.shiftV 1 0)) →
        HasBlockQ D B opPrim Q Δ C Γ Φy R p yes (.base .unit) ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.ifOnly cond yes) (.base .unit) ε
    /-- 01-05「match の意味」「網羅性の検査」。照合する値を束縛した文脈の外で各腕を型付ける。 -/
    | E_Match {Δ C Γ Φ R p e arms a b ε} :
        arms ≠ .nil → Ordinary a →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e a ε →
        HasArmsQ D B opPrim Q (localExtend 1 Δ) C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p arms
          (a.shiftV 1 0) (b.shiftV 1 0) (Eff.shiftV 1 0 ε) →
        ViewExhaustive D D.view a arms.unguardedPatterns →
        Ty.Annotation D.core C Γ a → Ty.Annotation D.core C Γ b →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.matchE b e arms) b ε
    /-- 01-12「return」: 末尾位置。 -/
    | E_ReturnTail {Δ C Γ Φ r a e ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ (some r) .tail e r ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ (some r) .tail (.returnE a e) r ε
    /-- 01-12「return」: 末尾でない位置。任意の結果型。 -/
    | E_ReturnOther {Δ C Γ Φ r a e ε} :
        Ty.Annotation D.core C Γ a → Ordinary r → HasTypeQ D B opPrim Q Δ C Γ Φ (some r) .other e r ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ (some r) .other (.returnE a e) a ε
    /-- 01-12「関数の境界と escape」: Result の try。照合の二つの腕のパターンの型付けを前提に持つ。 -/
    | E_TryResult {Δ C Γ Φ R p ok err d cde e t u e' t1 e1 ε} :
        D.cons err = some cde → cde.ntys = 2 → cde.args = [.tvar 1] →
        cde.data = d → R = some (.data d [u, e']) →
        TypeArgsKinded D.core C [u, e'] [.value, .value] → Ty.Annotation D.core C Γ (.data d [u, e']) →
        Ty.Annotation D.core C Γ (.data d [t, e']) → Ordinary t1 → Ordinary e1 →
        PatTy D.core (.con ok [.var]) (.data d [t, e']) [t1] → t1.norm = t.norm →
        PatTy D.core (.con err [.var]) (.data d [t, e']) [e1] → e1.norm = e'.norm →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.data d [t, e']) ε →
        Exhaustive D.core (.data d [t, e']) [.con ok [.var], .con err [.var]] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.tryResult [u, e'] ok err e) t ε
    /-- 同節: Option の try。 -/
    | E_TryOption {Δ C Γ Φ R p someCon noneCon d cdn e t u t1 ε} :
        D.cons noneCon = some cdn → cdn.ntys = 1 → cdn.args = [] →
        cdn.data = d → R = some (.data d [u]) →
        TypeArgsKinded D.core C [u] [.value] → Ty.Annotation D.core C Γ (.data d [u]) →
        Ty.Annotation D.core C Γ (.data d [t]) → Ordinary t1 →
        PatTy D.core (.con someCon [.var]) (.data d [t]) [t1] → t1.norm = t.norm →
        PatTy D.core (.con noneCon []) (.data d [t]) [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.data d [t]) ε →
        Exhaustive D.core (.data d [t]) [.con someCon [.var], .con noneCon []] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.tryOption [u] someCon noneCon e) t ε
    /-- 01-12「die の先行モデル」: Result の or die。失敗側は誤りの値を表示のメソッドで String にし、終了の組み込みの
    関数を 1 で呼ぶ。表示は照合の束縛の下、終了はさらに原因の束縛の下で型付ける。 -/
    | E_TryResultDie {Δ C Γ Φ R p ok err d e t et t1 e1 ε dict showMethod exit ts rs es' tx r ex} :
        Ty.Annotation D.core C Γ (.data d [t, et]) → Ordinary t1 →
        PatTy D.core (.con ok [.var]) (.data d [t, et]) [t1] → t1.norm = t.norm →
        PatTy D.core (.con err [.var]) (.data d [t, et]) [e1] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.data d [t, et]) ε →
        Exhaustive D.core (.data d [t, et]) [.con ok [.var], .con err [.var]] →
        CallHeadTy D B Q C Γ (.methName dict showMethod [] [] [] [] []) ts [] →
        ValsTel D B C Γ 2 (bindParams Γ [.data d [t, et], e1]) (liftMany 2 Φ) [.var 0] (Tel.shiftV 2 0 ts) rs es' →
        Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1]) (liftMany 2 Φ) rs (.base .string) →
        Eff.Covers (bindParams Γ [.data d [t, et], e1]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) es' →
        CallHeadTy D B Q C Γ (.primName exit [t] [] []) tx [] →
        ValsTel D B C Γ 3 (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ)
          [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 3 0 tx) r ex →
        Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) r (t.shiftV 3 0) →
        Eff.Covers (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) (Eff.shiftV 3 0 ε) ex →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.tryResultDie t ok err dict showMethod exit e none) t ε
    /-- 同規則の説明付き。説明は継続を隠した元の文脈で、戻り値型を持たない純粋な String として型付ける。 -/
    | E_TryResultDieMessage {Δ C Γ Φ R p ok err d e t et t1 e1 ε dict showMethod exit ts rs es' tx r ex m} :
        Ty.Annotation D.core C Γ (.data d [t, et]) → Ordinary t1 →
        PatTy D.core (.con ok [.var]) (.data d [t, et]) [t1] → t1.norm = t.norm →
        PatTy D.core (.con err [.var]) (.data d [t, et]) [e1] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.data d [t, et]) ε →
        Exhaustive D.core (.data d [t, et]) [.con ok [.var], .con err [.var]] →
        HasTypeQ D B opPrim Q Δ C (hideConts Γ) Φ none .other m (.base .string) Eff.empty →
        CallHeadTy D B Q C Γ (.methName dict showMethod [] [] [] [] []) ts [] →
        ValsTel D B C Γ 3 (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) [.var 1]
          (Tel.shiftV 3 0 ts) rs es' →
        Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) rs (.base .string) →
        Eff.Covers (bindParams Γ [.data d [t, et], e1, .base .string]) (liftMany 3 Φ) (Eff.shiftV 3 0 ε) es' →
        CallHeadTy D B Q C Γ (.primName exit [t] [] []) tx [] →
        ValsTel D B C Γ 4 (bindParams Γ [.data d [t, et], e1, .base .string, .base .string]) (liftMany 4 Φ)
          [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 4 0 tx) r ex →
        Ty.LeQ D.core (bindParams Γ [.data d [t, et], e1, .base .string, .base .string]) (liftMany 4 Φ) r
          (t.shiftV 4 0) →
        Eff.Covers (bindParams Γ [.data d [t, et], e1, .base .string, .base .string]) (liftMany 4 Φ)
          (Eff.shiftV 4 0 ε) ex →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.tryResultDie t ok err dict showMethod exit e (some m)) t ε
    /-- 同節: Option の or die。原因は固定の String である。 -/
    | E_TryOptionDie {Δ C Γ Φ R p someCon noneCon d e t t1 ε exit tx r ex} :
        Ty.Annotation D.core C Γ (.data d [t]) → Ordinary t1 →
        PatTy D.core (.con someCon [.var]) (.data d [t]) [t1] → t1.norm = t.norm →
        PatTy D.core (.con noneCon []) (.data d [t]) [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.data d [t]) ε →
        Exhaustive D.core (.data d [t]) [.con someCon [.var], .con noneCon []] →
        CallHeadTy D B Q C Γ (.primName exit [t] [] []) tx [] →
        ValsTel D B C Γ 2 (bindParams Γ [.data d [t], .base .string]) (liftMany 2 Φ)
          [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 2 0 tx) r ex →
        Ty.LeQ D.core (bindParams Γ [.data d [t], .base .string]) (liftMany 2 Φ) r (t.shiftV 2 0) →
        Eff.Covers (bindParams Γ [.data d [t], .base .string]) (liftMany 2 Φ) (Eff.shiftV 2 0 ε) ex →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.tryOptionDie t someCon noneCon exit e none) t ε
    /-- 同規則の説明付き。 -/
    | E_TryOptionDieMessage {Δ C Γ Φ R p someCon noneCon d e t t1 ε exit tx r ex m} :
        Ty.Annotation D.core C Γ (.data d [t]) → Ordinary t1 →
        PatTy D.core (.con someCon [.var]) (.data d [t]) [t1] → t1.norm = t.norm →
        PatTy D.core (.con noneCon []) (.data d [t]) [] →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.data d [t]) ε →
        Exhaustive D.core (.data d [t]) [.con someCon [.var], .con noneCon []] →
        HasTypeQ D B opPrim Q Δ C (hideConts Γ) Φ none .other m (.base .string) Eff.empty →
        CallHeadTy D B Q C Γ (.primName exit [t] [] []) tx [] →
        ValsTel D B C Γ 3 (bindParams Γ [.data d [t], .base .string, .base .string]) (liftMany 3 Φ)
          [.const (.integer ⟨1, by decide⟩)] (Tel.shiftV 3 0 tx) r ex →
        Ty.LeQ D.core (bindParams Γ [.data d [t], .base .string, .base .string]) (liftMany 3 Φ) r (t.shiftV 3 0) →
        Eff.Covers (bindParams Γ [.data d [t], .base .string, .base .string]) (liftMany 3 Φ) (Eff.shiftV 3 0 ε) ex →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.tryOptionDie t someCon noneCon exit e (some m)) t ε
    /-- 01-10「with の構文」: 本体は束縛の下で型付け、効果は State を含む。 -/
    | E_With {Δ C Γ Φ R p o e body a ε} :
        B.isResource o = true → HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.opaque o (.fixed .top)) ε →
        HasBlockQ D B opPrim Q (localExtend 1 Δ) C (Γ.extend (.opaque o (.fixed .top))) (Φ.map Pred.lift)
          (R.map (Ty.shiftV 1 0)) .other body (a.shiftV 1 0) (Eff.shiftV 1 0 ε) →
        (Eff.shiftV 1 0 ε).test (.name stateEff (.fixed .top)) = true →
        Ty.Declared D.core C Γ a →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.withE o e body) a ε
    /-- 01-06「明示遅延の型」: 純粋な本体。 -/
    | E_Lazy {Δ C Γ Φ R p body a} :
        HasBlockQ D B opPrim Q [] C (hideConts Γ) Φ none .other body a Eff.empty →
        Ty.Annotation D.core C Γ a →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.lazyE body) (.lazy a) Eff.empty
    /-- 01-12「ハンドラ」: C-Handle の宣言的な形。 -/
    | E_Handle {Δ C Γ Φ R p body cs t εbody ε} :
        HasBlockQ D B opPrim Q Δ C Γ Φ R .other body t εbody →
        Eff.Sub εbody (Eff.union ε (handled D.core B cs.skeleton)) →
        HasClausesQ D B opPrim Q Δ C Γ Φ R εbody cs t ε →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.handleE body cs) t ε
    /-- 同節: C-Resume。 -/
    | E_Resume {Δ C Γ Φ R p k e b t ε} :
        Γ[k]? = some (some (.cont b t ε)) → Ordinary b → HasTypeQ D B opPrim Q Δ C Γ Φ R .other e b ε →
        Ty.Declared D.core C Γ t →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p (.resume k e) t ε
    /-- 01-06「エフェクトの包含」: 部分型と一原子の被覆で広げる。 -/
    | E_Sub {Δ C Γ Φ R p e a a' ε ε'} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R p e a ε → Ty.LeQ D.core Γ Φ a a' → Eff.Covers Γ Φ ε' ε →
        Ty.Annotation D.core C Γ a' →
        HasTypeQ D B opPrim Q Δ C Γ Φ R p e a' ε'

  inductive HasTypesQ (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
      BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Exprs → List Ty → Eff → Prop
    | nil {Δ C Γ Φ R ε} : HasTypesQ D B opPrim Q Δ C Γ Φ R .nil [] ε
    | cons {Δ C Γ Φ R e es a as ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e a ε → HasTypesQ D B opPrim Q Δ C Γ Φ R es as ε →
        HasTypesQ D B opPrim Q Δ C Γ Φ R (.cons e es) (a :: as) ε

  inductive HasEachQ (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
      BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Exprs → Ty → Eff → Prop
    | nil {Δ C Γ Φ R a ε} : HasEachQ D B opPrim Q Δ C Γ Φ R .nil a ε
    | cons {Δ C Γ Φ R e es a ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e a ε → HasEachQ D B opPrim Q Δ C Γ Φ R es a ε →
        HasEachQ D B opPrim Q Δ C Γ Φ R (.cons e es) a ε

  /-- 穴を含む引数の固定の式を書いた順に型付ける。穴は型を持たず、ラムダの引数になる。 -/
  inductive HasFixedQ (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
      BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → HoleArgs → List Ty → Eff → Prop
    | nil {Δ C Γ Φ R ε} : HasFixedQ D B opPrim Q Δ C Γ Φ R .nil [] ε
    | expr {Δ C Γ Φ R label position e rest a as ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e a ε → HasFixedQ D B opPrim Q Δ C Γ Φ R rest as ε →
        HasFixedQ D B opPrim Q Δ C Γ Φ R (.expr label position e rest) (a :: as) ε
    | hole {Δ C Γ Φ R label position t rest as ε} : HasFixedQ D B opPrim Q Δ C Γ Φ R rest as ε →
        HasFixedQ D B opPrim Q Δ C Γ Φ R (.hole label position t rest) as ε

  /-- 照合の分岐。腕の文脈 Γ の番号 0 は照合する値である。各腕の本体はパターンの束縛を加えた文脈で、照合の経路の
  事実（この腕の選択肢が照合したこと）、束縛した欄と欄の観測の等号の事実、ガードが真であることの事実の下で型付ける。
  後続の腕は、ガードのない腕の除外の事実を受け取る（核の腕の型付けと同じ事実）。 -/
  inductive HasArmsQ (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
      BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Position → Arms → Ty → Ty → Eff → Prop
    | nil {Δ C Γ Φ R p a b ε} : HasArmsQ D B opPrim Q Δ C Γ Φ R p .nil a b ε
    | plain {Δ C Γ Φ R p alts body rest a b ε δ links} :
        Alternative.Valid alts → AltsTy D.core (Alternative.toCoreList alts) a δ →
        LinksValid (Alternative.toCoreList alts) δ.length links →
        FactsWF D.core C (bindParams Γ δ) (fieldFacts δ.length (scrutObs Γ) links) →
        FactsWF D.core C Γ (pathFacts (scrutObs Γ)
          (matchedTests (Alternative.toCoreList alts) ++ excludedTests (Alternative.toCoreList alts))) →
        HasBlockQ D B opPrim Q (localExtend δ.length Δ) C (bindParams Γ δ)
          (fieldFacts δ.length (scrutObs Γ) links ++
            liftMany δ.length (pathFacts (scrutObs Γ) (matchedTests (Alternative.toCoreList alts)) ++ Φ))
          (R.map (Ty.shiftV δ.length 0)) p body (b.shiftV δ.length 0) (Eff.shiftV δ.length 0 ε) →
        HasArmsQ D B opPrim Q Δ C Γ (pathFacts (scrutObs Γ) (excludedTests (Alternative.toCoreList alts)) ++ Φ) R p
          rest a b ε →
        HasArmsQ D B opPrim Q Δ C Γ Φ R p (.cons alts none body rest) a b ε
    | guarded {Δ C Γ Φ R p alts guard body rest a b ε δ links q} :
        Alternative.Valid alts → AltsTy D.core (Alternative.toCoreList alts) a δ →
        LinksValid (Alternative.toCoreList alts) δ.length links →
        FactsWF D.core C (bindParams Γ δ) (fieldFacts δ.length (scrutObs Γ) links) →
        FactsWF D.core C Γ (pathFacts (scrutObs Γ)
          (matchedTests (Alternative.toCoreList alts) ++ excludedTests (Alternative.toCoreList alts))) →
        Ty.Annotation D.core C (hideConts (bindParams Γ δ)) (.refined (.base .boolean) q) →
        HasTypeQ D B opPrim Q (localExtend δ.length Δ) C (hideConts (bindParams Γ δ))
          (fieldFacts δ.length (scrutObs Γ) links ++
            liftMany δ.length (pathFacts (scrutObs Γ) (matchedTests (Alternative.toCoreList alts)) ++ Φ))
          none .other guard (.refined (.base .boolean) q) Eff.empty →
        HasBlockQ D B opPrim Q (localExtend δ.length Δ) C (bindParams Γ δ)
          (q.open (.boolean true) :: (fieldFacts δ.length (scrutObs Γ) links ++
            liftMany δ.length (pathFacts (scrutObs Γ) (matchedTests (Alternative.toCoreList alts)) ++ Φ)))
          (R.map (Ty.shiftV δ.length 0)) p body (b.shiftV δ.length 0) (Eff.shiftV δ.length 0 ε) →
        HasArmsQ D B opPrim Q Δ C Γ Φ R p rest a b ε →
        HasArmsQ D B opPrim Q Δ C Γ Φ R p (.cons alts (some guard) body rest) a b ε

  /-- C-Handle の節と同じ環境。操作の型は保護本体の効果から選んだ節の添字で具体化する。 -/
  inductive HasClausesQ (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
      BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Eff → Clauses → Ty → Eff → Prop
    | nil {Δ C Γ Φ R εb t ε} : HasClausesQ D B opPrim Q Δ C Γ Φ R εb .nil t ε
    | cons {Δ C Γ Φ R εb o n ntys body cs t ε sg ndicts} :
        ClauseAllowed D B o → ClauseSig D.core B εb o sg → NamesWF sg.names sg.params → ndicts + n = sg.params.length →
        ntys = sg.tparams.length → sg.WF →
        HasBlockQ D B opPrim Q [] (sg.tparams ++ C) (sg.context Γ t ε)
          (liftMany (sg.params.length + 1) Φ)
          (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length + 1) 0)) .other body
          ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length + 1) 0)
          ((shiftRowsTypes sg.tparams.length 0 ε).shiftV (sg.params.length + 1) 0) →
        HasClausesQ D B opPrim Q Δ C Γ Φ R εb cs t ε →
        HasClausesQ D B opPrim Q Δ C Γ Φ R εb (.cons o n ntys body cs ndicts) t ε

  inductive HasBlockQ (D : Declarations) (B : Builtins) (opPrim : OpPrim) (Q : NoFailCtx) :
      BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Position → Block → Ty → Eff → Prop
    /-- 01-12「構築器の局所宣言と捕捉」: セルは通常値の位置を隠したまま束縛する。 -/
    | B_BuilderBind {Δ C Γ Φ R p k rest a ε} :
        Ty.Annotation D.core C Γ k.contents → TypeArgsKinded D.core C [k.contents] [.value] →
        HasBlockQ D B opPrim Q (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) Δ) C Γ.extendNone
          (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p rest (a.shiftV 1 0) (Eff.shiftV 1 0 ε) →
        Ty.Declared D.core C Γ a →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.builderBind k rest) a ε
    | B_Empty {Δ C Γ Φ R p} : HasBlockQ D B opPrim Q Δ C Γ Φ R p .empty (.base .unit) Eff.empty
    | B_Last {Δ C Γ Φ R p e a ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R p e a ε → HasBlockQ D B opPrim Q Δ C Γ Φ R p (.last e) a ε
    | B_LastBind {Δ C Γ Φ R p k t e ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e t ε →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.lastBind k t e) (.base .unit) ε
    | B_LastDiscard {Δ C Γ Φ R p e t ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e t ε →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.lastDiscard e) (.base .unit) ε
    | B_Bind {Δ C Γ Φ R p k t e rest a ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e t ε →
        HasBlockQ D B opPrim Q (localExtend 1 Δ) C (Γ.extend t) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) p
          rest (a.shiftV 1 0) (Eff.shiftV 1 0 ε) →
        Ty.Declared D.core C Γ a →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.bind k t e rest) a ε
    | B_Discard {Δ C Γ Φ R p e rest t a ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e t ε → HasBlockQ D B opPrim Q Δ C Γ Φ R p rest a ε →
        Ty.Declared D.core C Γ a →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.discard e rest) a ε
    | B_Seq {Δ C Γ Φ R p e rest a ε} :
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e (.base .unit) ε → ¬ e.Exits →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p rest a ε →
        Ty.Declared D.core C Γ a →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.seq e rest) a ε
    | B_LastPat {Δ C Γ Φ R p k pat t e ε δ} :
        pat.Nontrivial → pat.Valid → PatTy D.core pat.toCore t δ →
        ViewExhaustive D D.view t [pat.toCore] → Ty.Annotation D.core C Γ t → Ordinary t →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e t ε →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.lastPat k pat t e) (.base .unit) ε
    | B_BindPat {Δ C Γ Φ R p k pat t e rest a ε δ} :
        pat.Nontrivial → pat.Valid → PatTy D.core pat.toCore t δ →
        ViewExhaustive D D.view t [pat.toCore] → Ty.Annotation D.core C Γ t → Ordinary t →
        HasTypeQ D B opPrim Q Δ C Γ Φ R .other e t ε →
        HasBlockQ D B opPrim Q (localExtend δ.length Δ) C (bindParams Γ δ) (liftMany δ.length Φ)
          (R.map (Ty.shiftV δ.length 0)) p rest (a.shiftV δ.length 0) (Eff.shiftV δ.length 0 ε) →
        Ty.Annotation D.core C Γ a →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p (.bindPat k pat t e rest) a ε
    | B_Sub {Δ C Γ Φ R p body a a' ε ε'} :
        HasBlockQ D B opPrim Q Δ C Γ Φ R p body a ε → Ty.LeQ D.core Γ Φ a a' → Eff.Covers Γ Φ ε' ε →
        Ty.Annotation D.core C Γ a' →
        HasBlockQ D B opPrim Q Δ C Γ Φ R p body a' ε'
end

/-! `Surface.Typing` で固定した判断の型と一致する。 -/
example : ExprJudgment := HasTypeQ
example : ExprsJudgment := HasTypesQ
example : EachJudgment := HasEachQ
/-- 穴を持つ引数の判断は、固定の式の型の列を持つ。穴の型は式の構文に付いている。 -/
example : HoleArgsJudgment := HasFixedQ
example : DictJudgment := DictEv.HasType
example : ArmsJudgment := HasArmsQ
example : ClausesJudgment := HasClausesQ
example : BlockJudgment := HasBlockQ

end Benitoite.Release.Refinement.Surface
