import Benitoite.Surface.Syntax
import Benitoite.Surface.Desugar
import Benitoite.Release.Typing

/-!
# 表層の型付け（C1・C2・C4・C5a-1・C6a-1・C6a-2・C6a-3・C7b-2）

`HasType D B op C Γ R p e a ε` は制約 C、局所環境 Γ、最も内側の戻り値型 R、
位置 p のもとでの判断である。型の推論ではなく、構文に付いた情報を検査する。
末尾の `return` の型は R に具体化する。関数本体の Unit という表層の条件は、
`Exits` と戻り値型 Unit の条件で検査し、脱糖後の本体の結果型を R として判断する。
型の包含は Release の `Ty.Le`、多相な使用は `SatAll` と `admits` を使う。
-/

namespace Benitoite.Surface

open Benitoite.Release

mutual
  /-- 01-12「型クラス」: V-Dict・受け取った辞書・V-Super の写し。 -/
  inductive DictEv.HasType (D : Declarations) (B : Builtins) :
      List TParam → List (Option Ty) → DictEv → Ty → Prop
    -- V-Dict: I[T̄](V̄) : Dict[Cl, τ[T̄/β̄]]。
    | impl {C Γ i ts ds id} :
        D.impls i = some id → SatAll B C ts id.tparams →
        DictEv.HasTypes D B C Γ ds (id.dictTys.map (Ty.subst ts [])) →
        DictEv.HasType D B C Γ (.impl i ts ds) (.dict id.cls (id.target.subst ts []))
    -- 01-12 の辞書の決め方: 型パラメータの制約は受け取った辞書の引数 d を使う。
    | local {C Γ j cl τ} : Γ[j]? = some (some (.dict cl τ)) →
        DictEv.HasType D B C Γ (.local j) (.dict cl τ)
    -- V-Super: V : Dict[Cl, τ]、S が Cl の上位なら V↑S : Dict[S, τ]。
    | super {C Γ d cl τ cd s} :
        DictEv.HasType D B C Γ d (.dict cl τ) → D.classes cl = some cd → s ∈ cd.supers →
        DictEv.HasType D B C Γ (.super d s) (.dict s τ)

  inductive DictEv.HasTypes (D : Declarations) (B : Builtins) :
      List TParam → List (Option Ty) → List DictEv → List Ty → Prop
    | nil {C Γ} : DictEv.HasTypes D B C Γ [] []
    | cons {C Γ d ds a as} :
        DictEv.HasType D B C Γ d a → DictEv.HasTypes D B C Γ ds as →
        DictEv.HasTypes D B C Γ (d :: ds) (a :: as)
end

/-- else if の続きは if の構文だけである。 -/
inductive IsIf : Expr → Prop
  -- 01-12「リスト、ラムダ、条件分岐、match」: else if 以下を閉じた if にする。
  | ite {c y n} : IsIf (.ite c y n)
  -- 同じ行: else if の連鎖。
  | elseIf {c y n} : IsIf n → IsIf (.elseIf c y n)
  -- 同じ行: 連鎖の最後が else を持たない場合。
  | ifOnly {c y} : IsIf (.ifOnly c y)

/-- E_Binary と同じ連結演算子の前提。部分が二つ以上の補間だけが要求する。 -/
def StringAddOk (B : Builtins) (op : OpPrim) (C : List TParam) : Prop :=
  ∃ b ts s, op (.binary .add) (.base .string) = some (b, ts) ∧ ts = [] ∧
    B.sig b = some s ∧ ts.length = s.ntys ∧ s.neffs = 0 ∧ s.admits C ts ∧
    fnTy s.names s.params s.ret s.eff ts [] = .fn ["left", "right"] [.base .string, .base .string] (.base .string) Eff.empty

/-- 解決済みの Show の辞書とメソッドを、宣言表の純粋な一引数の契約で検査する。
識別名は交換形式と同じく抽象的に扱う（設計書 01-12「die の先行モデル」）。 -/
def DieShowOk (D : Declarations) (B : Builtins) (C : List TParam)
    (Γ : List (Option Ty)) (dict : DictEv) (showMethod : MethName) (errorTy : Ty) : Prop :=
  ∃ cl cd ms, DictEv.HasType D B C Γ dict (.dict cl errorTy) ∧
    D.classes cl = some cd ∧ cd.methods showMethod = some ms ∧
    ms.tparams = [] ∧ ms.neffs = 0 ∧ ms.names = ["x"] ∧ ms.params = [.tvar 0] ∧
    ms.ret = .base .string ∧ ms.eff = Eff.empty

/-- 既存の終了操作の種類・所属エフェクトと、T への具体化を検査する。 -/
def DieExitOk (B : Builtins) (C : List TParam) (exit : PrimName) (t : Ty) : Prop :=
  ∃ s, B.sig exit = some s ∧ s.kind = .exit ∧ s.opEff = some "Process.Exit" ∧
    s.ntys = 1 ∧ s.neffs = 0 ∧ NamesWF s.names s.params ∧ s.admits C [t] ∧
    fnTy s.names s.params s.ret s.eff [t] [] =
      .fn ["code"] [.base .integer] t (Eff.single "Process.Exit")

mutual
  inductive HasType (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → Position → Expr → Ty → Eff → Prop
    -- 01-12「名前とリテラル」: 局所の束縛の名前 x。01-06「多相」: 局所は単相。
    | E_Local {C Γ R p i a} :
        Γ[i]? = some (some a) → (∀ b t ε, a ≠ .cont b t ε) →
        HasType D B opPrim C Γ R p (.local i) a Eff.empty
    -- 01-06「定数の型（初回リリース版）」: 宣言の型と本体の判断の型が同じで、エフェクトは空。
    -- P5: 使用位置の C・R を保ち、Γ だけを空にする。本体は非末尾位置で検査する。
    -- 書ける式の種類と実行時エラーにならないことは、この判断では検査しない。
    | E_Const {C Γ R p a body} :
        HasType D B opPrim C [] R .other body a Eff.empty →
        HasType D B opPrim C Γ R p (.constE a body) a Eff.empty
    -- 01-12「名前とリテラル」: トップレベルの関数 f。01-06「多相」「エフェクト変数の具体化」。
    -- 01-12「型クラス」第 4 行との区別: この規則は辞書の引数を持たない f に限る。
    | E_Fun {C Γ R p f d ts es} :
        D.funs f = some d → NamesWF d.names d.params →
        NamesWF d.coreNames (d.dictTys ++ d.params) → SatAll B C ts d.tparams → es.length = d.neffs → d.dictParams = [] →
        HasType D B opPrim C Γ R p (.funName f ts es) (fnTy d.names d.params d.ret d.eff ts es) Eff.empty
    -- 01-12「型クラス」第 4 行: return λ(ȳ:Ā). f[T̄; Ē](Ū, ȳ)。Ā は値の引数だけ。
    | E_FunDicts {C Γ R p f d ts es ds names ps} :
        D.funs f = some d → NamesWF d.names d.params →
        NamesWF d.coreNames (d.dictTys ++ d.params) → SatAll B C ts d.tparams → es.length = d.neffs →
        d.dictParams ≠ [] → names = d.names → ps = d.params.map (Ty.subst ts es) →
        DictEv.HasTypes D B C Γ ds (d.dictTys.map (Ty.subst ts [])) →
        HasType D B opPrim C Γ R p (.funDicts f ts es ds names ps)
          (fnTy d.names d.params d.ret d.eff ts es) Eff.empty
    -- 同表第 2 行: return λ(ȳ:Ā). V.m[S̄; Ē](Ū, ȳ)。C-Meth の θ = subst (ss ++ [τ]) es。
    -- MethSig は辞書数を持たないため、us.length で分け、値引数の先頭が辞書型でないことを検査する。
    | E_MethName {C Γ R p d cl τ cd m ms ss es us names ps} :
        DictEv.HasType D B C Γ d (.dict cl τ) → D.classes cl = some cd → cd.methods m = some ms → NamesWF ms.names ms.params →
        names = ms.names.drop us.length → SatAll B C ss ms.tparams → es.length = ms.neffs →
        DictEv.HasTypes D B C Γ us ((ms.params.map (Ty.subst (ss ++ [τ]) es)).take us.length) →
        ps = (ms.params.map (Ty.subst (ss ++ [τ]) es)).drop us.length →
        (∀ a ∈ ps.head?, ∀ cl t, a ≠ .dict cl t) →
        HasType D B opPrim C Γ R p (.methName d m ss es us names ps)
          (.fn names ps (ms.ret.subst (ss ++ [τ]) es) (Eff.substRho es ms.eff)) Eff.empty
    -- 01-12「名前とリテラル」: prelude の関数 M.g。V-Prim と同じ admits を検査する。
    | E_Prim {C Γ R p b s ts es} :
        B.sig b = some s → NamesWF s.names s.params → ts.length = s.ntys → es.length = s.neffs → s.admits C ts →
        HasType D B opPrim C Γ R p (.primName b ts es) (fnTy s.names s.params s.ret s.eff ts es) Eff.empty
    -- 01-12「ハンドラ」: 操作を値として使う。V-Op と同じ宣言と制約を検査する。
    | E_Op {C Γ R p o od ts} :
        D.ops o = some od → NamesWF od.names od.params → SatAll B C ts od.tparams →
        HasType D B opPrim C Γ R p (.opName o ts)
          (fnTy od.names od.params od.ret (Eff.single od.eff) ts []) Eff.empty
    -- 01-12「名前とリテラル」: 引数のない構成子。01-05「値の構築」。
    | E_NullCon {C Γ R p c cd ts} :
        D.cons c = some cd → ts.length = cd.ntys → cd.args = [] →
        HasType D B opPrim C Γ R p (.nullCon c ts) (.data cd.data ts) Eff.empty
    -- 01-12「名前とリテラル」: 引数を持つ構成子を値として使う。
    | E_ConValue {C Γ R p c cd ts names ps} :
        D.cons c = some cd → ts.length = cd.ntys →
        names = D.constructorNames c cd → NamesWF names ps →
        ps = cd.args.map (Ty.subst ts []) → ps ≠ [] →
        HasType D B opPrim C Γ R p (.conValue c ts names ps)
          (.fn names ps (.data cd.data ts) Eff.empty) Eff.empty
    -- 01-12「名前とリテラル」: リテラル。01-06「式と文の型」: 基本型の各行。
    | E_Literal {C Γ R p l} :
        HasType D B opPrim C Γ R p (.literal l) l.toConst.type Eff.empty
    -- 01-12「名前とリテラル」: -n。01-06「式と文の型」: Integer。
    | E_NegInt {C Γ R p n} :
        HasType D B opPrim C Γ R p (.negInt n) (.base .integer) Eff.empty
    -- 01-12「名前とリテラル」: 直接の -x。01-06「式と文の型」: Float。
    | E_NegFloat {C Γ R p x} :
        HasType D B opPrim C Γ R p (.negFloat x) (.base .float) Eff.empty
    -- 01-06「演算子の型付け」と Decimal の基本型。直接の - は定数に含める。
    | E_NegDecimal {C Γ R p n scale} :
        HasType D B opPrim C Γ R p (.negDecimal n scale) (.base .decimal) Eff.empty
    -- 01-12「名前とリテラル」: 幅付きの直接の負号も、空のエフェクトの定数である。
    | E_NegInteger8 {C Γ R p n} :
        HasType D B opPrim C Γ R p (.negInteger8 n) (.base .integer8) Eff.empty
    | E_NegInteger16 {C Γ R p n} :
        HasType D B opPrim C Γ R p (.negInteger16 n) (.base .integer16) Eff.empty
    | E_NegInteger32 {C Γ R p n} :
        HasType D B opPrim C Γ R p (.negInteger32 n) (.base .integer32) Eff.empty
    | E_NegFloat32 {C Γ R p bits} :
        HasType D B opPrim C Γ R p (.negFloat32 bits) (.base .float32) Eff.empty
    -- 01-12「名前とリテラル」: ()。01-06「式と文の型」: Unit。
    | E_Unit {C Γ R p} : HasType D B opPrim C Γ R p .unit (.base .unit) Eff.empty
    -- 01-12「名前とリテラル」: (e)。01-08「末尾呼び出し」: 位置を引き継ぐ。
    | E_Paren {C Γ R p e a ε} :
        HasType D B opPrim C Γ R p e a ε → HasType D B opPrim C Γ R p (.paren e) a ε
    -- 01-05「レコード」・01-06「式と文の型」。評価は書いた順、型は各宣言の位置。
    | E_Record {C Γ R p c cd ts positions args ε} :
        D.cons c = some cd → ts.length = cd.ntys →
        positions.Perm (List.range cd.args.length) →
        HasTypes D B opPrim C Γ R args
          (positions.map fun i => ((cd.args.map (Ty.subst ts []))[i]?).getD (.base .unit)) ε →
        HasType D B opPrim C Γ R p (.record c ts positions args) (.data cd.data ts) ε
    -- 01-05「レコード」: 型引数を base と共通にし、位置の重複と範囲外を排除する。
    -- 一分岐の網羅性は E_TryResult と同じく入力の型付けで検査する。
    | E_RecordUpdate {C Γ R p c cd ts n positions base args εb εa} :
        D.cons c = some cd → ts.length = cd.ntys → n = cd.args.length →
        positions ≠ [] → positions.Nodup → (∀ i ∈ positions, i < n) →
        HasType D B opPrim C Γ R .other base (.data cd.data ts) εb →
        HasTypes D B opPrim C Γ R args
          (positions.map fun i => ((cd.args.map (Ty.subst ts []))[i]?).getD (.base .unit)) εa →
        Exhaustive D.patternProgram (.data cd.data ts) [recordUpdatePattern c n positions] →
        HasType D B opPrim C Γ R p (.recordUpdate c ts n positions base args)
          (.data cd.data ts) (Eff.union εb εa)
    -- 01-12「呼び出し」: 構成子の呼び出し。01-05「値の構築」、01-06「エフェクトの包含」。
    | E_ConCall {C Γ R p c cd ts args ε} :
        D.cons c = some cd → ts.length = cd.ntys →
        HasTypes D B opPrim C Γ R args (cd.args.map (Ty.subst ts [])) ε →
        HasType D B opPrim C Γ R p (.conCall c ts args) (.data cd.data ts) ε
    -- 01-12「呼び出し」: そのほかの呼び出し。01-06「式のエフェクト」: 関数・引数・呼び出しの和。
    | E_Call {C Γ R p f labels positions args names ps a εf εargs εcall} :
        HasType D B opPrim C Γ R .other f (.fn names ps a εcall) εf →
        CallOk names ps false labels positions →
        HasTypes D B opPrim C Γ R args (sourceTypes ps positions) εargs →
        HasType D B opPrim C Γ R p (.call f labels positions args) a (Eff.union εf (Eff.union εargs εcall))
    -- 01-02「パイプ」: 左辺を位置 0 に挿入し、残る引数をソース順で検査する。
    | E_PipeCall {C Γ R p lhs f labels positions args names t ps a εl εf εargs εcall} :
        HasType D B opPrim C Γ R .other lhs t εl →
        HasType D B opPrim C Γ R .other f (.fn names (t :: ps) a εcall) εf →
        CallOk names (t :: ps) true labels positions →
        HasTypes D B opPrim C Γ R args (sourceTypes (t :: ps) positions) εargs →
        HasType D B opPrim C Γ R p (.pipe lhs (.call f labels positions args)) a
          (Eff.union εl (Eff.union εf (Eff.union εargs εcall)))
    -- 同規則の構成子の呼び出し。右辺の式自体は呼び出さない。
    | E_PipeConCall {C Γ R p lhs c cd ts args t ps εl εargs} :
        D.cons c = some cd → ts.length = cd.ntys →
        cd.args.map (Ty.subst ts []) = t :: ps →
        HasType D B opPrim C Γ R .other lhs t εl →
        HasTypes D B opPrim C Γ R args ps εargs →
        HasType D B opPrim C Γ R p (.pipe lhs (.conCall c ts args))
          (.data cd.data ts) (Eff.union εl εargs)
    -- 規則 2 の裸の構成子名: 一引数の構成子を呼ぶ。
    | E_PipeConValue {C Γ R p lhs c cd ts names ps t εl} :
        D.cons c = some cd → ts.length = cd.ntys →
        names = D.constructorNames c cd → NamesWF names ps →
        ps = cd.args.map (Ty.subst ts []) → ps = [t] →
        HasType D B opPrim C Γ R .other lhs t εl →
        HasType D B opPrim C Γ R p (.pipe lhs (.conValue c ts names ps)) (.data cd.data ts) εl
    -- 規則 2。括弧・プレースホルダの呼び出しもここに属する。
    | E_PipeApply {C Γ R p lhs rhs name t a εl εf εcall} :
        rhs.PipeValue → HasType D B opPrim C Γ R .other lhs t εl →
        HasType D B opPrim C Γ R .other rhs (.fn [name] [t] a εcall) εf →
        HasType D B opPrim C Γ R p (.pipe lhs rhs) a (Eff.union εl (Eff.union εf εcall))
    -- 01-06「式と文の型」: 展開したラムダの本体として検査する。
    -- 新しい引数はソースに見えないので Γ に加えない。番号は脱糖の出力でずらす。
    | E_PartialCall {C Γ R p f names args ps r0 r ε εf εargs εcall} :
        args.holeTypes ≠ [] →
        HasType D B opPrim C (hideConts Γ) (some r) .other f (.fn names ps r0 εcall) εf →
        CallOk names ps false args.labels args.positions →
        NamesWF (args.holeNames names) args.holeTypes →
        HasHoleArgs D B opPrim C (hideConts Γ) (some r) args (sourceTypes ps args.positions) εargs →
        Ty.Le r0 r → Eff.Sub (Eff.union εf (Eff.union εargs εcall)) ε →
        HasType D B opPrim C Γ R p (.partialCall f names args r ε) (.fn (args.holeNames names) args.holeTypes r ε) Eff.empty
    -- 同じ展開の構成子版。戻り値型は構成子の属する型。
    | E_PartialCon {C Γ R p c cd ts args r εargs} :
        D.conFields c = none → D.cons c = some cd → ts.length = cd.ntys → args.holeTypes ≠ [] →
        args.ConstructorOk cd.args.length →
        NamesWF (args.holeNames (positionalNames args.positions.length)) args.holeTypes →
        HasHoleArgs D B opPrim C (hideConts Γ) (some r) args
          (cd.args.map (Ty.subst ts [])) εargs →
        Ty.Le (.data cd.data ts) r →
        HasType D B opPrim C Γ R p (.partialCon c ts args)
          (.fn (args.holeNames (positionalNames args.positions.length)) args.holeTypes r εargs) Eff.empty
    -- 01-12「演算子」: e1 ⊕ e2。01-06「演算子の型付け」「等値の型」。
    -- 算術と比較の型の集まりは Operator.allowed、等値の制約は B.sig の admits、結果型は fnTy で検査する。02-06 に従い eq/ne だけ [T]。
    -- 算術は (T,T)→T、比較と等値は (T,T)→Boolean という表を B.sig に与える。
    | E_Binary {C Γ R p o t b ts s lhs rhs a εl εr} :
        (Operator.binary o).allowed t = true →
        opPrim (.binary o) t = some (b, ts) → ts = (Operator.binary o).typeArgs t →
        B.sig b = some s → NamesWF s.names s.params → ts.length = s.ntys → s.neffs = 0 → s.admits C ts →
        fnTy s.names s.params s.ret s.eff ts [] = .fn ["left", "right"] [t, t] a Eff.empty →
        HasType D B opPrim C Γ R .other lhs t εl → HasType D B opPrim C Γ R .other rhs t εr →
        HasType D B opPrim C Γ R p (.binary o t lhs rhs) a (Eff.union εl εr)
    -- 01-12「演算子」: -e（直接の整数・Float リテラルを除く）。01-06「演算子の型付け」: (T)→T。
    | E_Neg {C Γ R p t b ts s e ε} :
        Operator.neg.allowed t = true →
        opPrim .neg t = some (b, ts) → ts = [] → B.sig b = some s →
        ts.length = s.ntys → s.neffs = 0 → s.admits C ts →
        fnTy s.names s.params s.ret s.eff ts [] = .fn ["value"] [t] t Eff.empty →
        HasType D B opPrim C Γ R .other e t ε → HasType D B opPrim C Γ R p (.neg t e) t ε
    -- 01-12「演算子」: not e。01-06「式と文の型」: Boolean。
    | E_Not {C Γ R p e ε} :
        HasType D B opPrim C Γ R .other e (.base .boolean) ε →
        HasType D B opPrim C Γ R p (.not e) (.base .boolean) ε
    -- 01-12「演算子」: e1 and e2。01-08「末尾呼び出し」: 右辺だけ位置を引き継ぐ。
    | E_And {C Γ R p lhs rhs εl εr} :
        HasType D B opPrim C Γ R .other lhs (.base .boolean) εl →
        HasType D B opPrim C Γ R p rhs (.base .boolean) εr →
        HasType D B opPrim C Γ R p (.and lhs rhs) (.base .boolean) (Eff.union εl εr)
    -- 01-12「演算子」: e1 or e2。01-06「式と文の型」「式のエフェクト」。
    | E_Or {C Γ R p lhs rhs εl εr} :
        HasType D B opPrim C Γ R .other lhs (.base .boolean) εl →
        HasType D B opPrim C Γ R p rhs (.base .boolean) εr →
        HasType D B opPrim C Γ R p (.or lhs rhs) (.base .boolean) (Eff.union εl εr)
    -- 01-12「リスト、ラムダ、条件分岐、match」: [e1,…,en]。01-06「式と文の型」。
    | E_List {C Γ R p a es ε} :
        Ty.WF C.length a → HasEach D B opPrim C Γ R es a ε →
        HasType D B opPrim C Γ R p (.list a es) (.list a) ε
    -- 01-06「式と文の型」: 要素は T、展開の式は List[T]。concat_T は純粋な直接の頭。
    | E_ListSpread {C Γ R p a f h before spread after εb εs εa} :
        Ty.WF C.length a → directCallee f = some h →
        HasType D B opPrim C Γ R .other f (.fn ["xs", "ys"] [.list a, .list a] (.list a) Eff.empty) Eff.empty →
        HasEach D B opPrim C Γ R before a εb →
        HasType D B opPrim C Γ R .other spread (.list a) εs →
        HasEach D B opPrim C Γ R after a εa →
        HasType D B opPrim C Γ R p (.listSpread a f before spread after) (.list a)
          (Eff.union εb (Eff.union εs εa))
    -- 01-06「演算子の型付け」: 幅付きの七種を含む基本型を補間し、結果は String。
    -- 01-12「文字列補間」: String の式の変換関数は持たず、str_T は純粋な直接の頭。
    | E_Interpolation {C Γ R p parts es fs ε} :
        InterpPart.Allowed parts → HasTypes D B opPrim C Γ R es (InterpPart.exprTypes parts) ε →
        HasTypes D B opPrim C Γ R fs (InterpPart.converterTypes parts) Eff.empty → fs.AllDirect →
        (2 ≤ InterpPart.count parts → StringAddOk B opPrim C) →
        HasType D B opPrim C Γ R p (.interpolation parts es fs) (.base .string) ε
    -- 01-12「リスト、ラムダ、条件分岐、match」: lambda(x̄) B。01-06「必ず抜ける文」、01-12「関数の境界と escape」。
    | E_Lam {C Γ R p names ps r ε body} :
        NamesWF names ps → (body.Exits ∨ r = .base .unit) →
        HasBlock D B opPrim C (binds ps ++ hideConts Γ) (some r) .tail body r ε →
        HasType D B opPrim C Γ R p (.lam names ps r ε body) (.fn names ps r ε) Eff.empty
    -- 01-12 同節: if e then B1 else B2。01-06「式と文の型」「エフェクトの包含」。
    | E_If {C Γ R p cond yes no a εc εy εn} :
        HasType D B opPrim C Γ R .other cond (.base .boolean) εc →
        HasBlock D B opPrim C Γ R p yes a εy → HasBlock D B opPrim C Γ R p no a εn →
        HasType D B opPrim C Γ R p (.ite cond yes no) a (Eff.union εc (Eff.union εy εn))
    -- 01-12 同節: else if。続きの if を一つの分岐とする。
    | E_ElseIf {C Γ R p cond yes no a εc εy εn} :
        HasType D B opPrim C Γ R .other cond (.base .boolean) εc →
        HasBlock D B opPrim C Γ R p yes a εy → HasType D B opPrim C Γ R p no a εn →
        IsIf no →
        HasType D B opPrim C Γ R p (.elseIf cond yes no) a (Eff.union εc (Eff.union εy εn))
    -- 01-12 同節: else なし。01-06「式と文の型」: Unit。
    | E_IfOnly {C Γ R p cond yes εc εy} :
        HasType D B opPrim C Γ R .other cond (.base .boolean) εc →
        HasBlock D B opPrim C Γ R p yes (.base .unit) εy →
        HasType D B opPrim C Γ R p (.ifOnly cond yes) (.base .unit) (Eff.union εc εy)
    -- 01-05「match の意味」「網羅性の検査」、01-06「式と文の型」。
    -- ソースだけに view 付きの条件を課し、合成照合は現在の値の Exhaustive を保つ。
    | E_Match {C Γ R p e arms a b εe εarms} :
        arms ≠ .nil →
        HasType D B opPrim C Γ R .other e a εe →
        HasArms D B opPrim C Γ R p arms a b εarms →
        ViewExhaustive D D.view a arms.unguardedPatterns →
        HasType D B opPrim C Γ R p (.matchE b e arms) b (Eff.union εe εarms)
    -- 01-12「return」: 末尾位置。01-06「式と文の型」の任意の型を R に具体化し、構文の注釈は使わない。
    | E_ReturnTail {C Γ r a e ε} :
        HasType D B opPrim C Γ (some r) .tail e r ε →
        HasType D B opPrim C Γ (some r) .tail (.returnE a e) r ε
    -- 01-12「return」: 末尾でない位置。01-12「関数の境界と escape」: 任意の結果型。
    | E_ReturnOther {C Γ r a e ε} :
        Ty.WF C.length a → HasType D B opPrim C Γ (some r) .other e r ε →
        HasType D B opPrim C Γ (some r) .other (.returnE a e) a ε
    -- 01-12「関数の境界と escape」: Result の try。01-09「try」: E は同じ型であり、変換しない。
    -- Inhabits は同じデータ型の全構成子を含むため、二つの分岐の網羅性を別に検査する。
    | E_TryResult {C Γ R p ok err cdo cde e t u e' ε} :
        D.cons ok = some cdo → D.cons err = some cde →
        cdo.ntys = 2 → cde.ntys = 2 → cdo.args = [.tvar 0] → cde.args = [.tvar 1] →
        cdo.data = cde.data → R = some (.data cdo.data [u, e']) →
        HasType D B opPrim C Γ R .other e (.data cdo.data [t, e']) ε →
        Exhaustive D.patternProgram (.data cdo.data [t, e']) [.con ok [.var], .con err [.var]] →
        HasType D B opPrim C Γ R p (.tryResult [u, e'] ok err e) t ε
    -- 同節: Option の try。01-09「try」: 最も内側の戻り値の型も Option である。
    | E_TryOption {C Γ R p someCon noneCon cds cdn e t u ε} :
        D.cons someCon = some cds → D.cons noneCon = some cdn →
        cds.ntys = 1 → cdn.ntys = 1 → cds.args = [.tvar 0] → cdn.args = [] →
        cds.data = cdn.data → R = some (.data cds.data [u]) →
        HasType D B opPrim C Γ R .other e (.data cds.data [t]) ε →
        Exhaustive D.patternProgram (.data cds.data [t]) [.con someCon [.var], .con noneCon []] →
        HasType D B opPrim C Γ R p (.tryOption [u] someCon noneCon e) t ε
    -- 01-12「die の先行モデル」: R を制限せず、表示と説明は純粋な String とする。
    -- 説明の直接の脱出と外側の resume を除き、内側の lambda は自分の境界を持つ。
    | E_TryResultDie {C Γ R p ok err cdo cde e t et ε dict showMethod exit message} :
        D.cons ok = some cdo → D.cons err = some cde →
        cdo.ntys = 2 → cde.ntys = 2 → cdo.args = [.tvar 0] → cde.args = [.tvar 1] →
        cdo.data = cde.data →
        HasType D B opPrim C Γ R .other e (.data cdo.data [t, et]) ε →
        Exhaustive D.patternProgram (.data cdo.data [t, et]) [.con ok [.var], .con err [.var]] →
        DieShowOk D B C Γ dict showMethod et → DieExitOk B C exit t →
        (∀ m, message = some m →
          HasType D B opPrim C (hideConts Γ) none .other m (.base .string) Eff.empty) →
        HasType D B opPrim C Γ R p (.tryResultDie t ok err dict showMethod exit e message)
          t (Eff.union ε (Eff.single "Process.Exit"))
    | E_TryOptionDie {C Γ R p someCon noneCon cds cdn e t ε exit message} :
        D.cons someCon = some cds → D.cons noneCon = some cdn →
        cds.ntys = 1 → cdn.ntys = 1 → cds.args = [.tvar 0] → cdn.args = [] →
        cds.data = cdn.data →
        HasType D B opPrim C Γ R .other e (.data cds.data [t]) ε →
        Exhaustive D.patternProgram (.data cds.data [t]) [.con someCon [.var], .con noneCon []] →
        DieExitOk B C exit t →
        (∀ m, message = some m →
          HasType D B opPrim C (hideConts Γ) none .other m (.base .string) Eff.empty) →
        HasType D B opPrim C Γ R p (.tryOptionDie t someCon noneCon exit e message)
          t (Eff.union ε (Eff.single "Process.Exit"))
    -- 01-10「リソースの型」「with の構文」: 本体の型と、束縛・本体・解放のエフェクトの和。
    -- 01-12「解放の枠」: 本体は非末尾位置。束縛は後続のリソースの式にも見える。
    | E_With {C Γ R p o e body a εe εbody} :
        B.isResource o = true → HasType D B opPrim C Γ R .other e (.opaque o) εe →
        HasBlock D B opPrim C (some (.opaque o) :: Γ) R .other body a εbody →
        HasType D B opPrim C Γ R p (.withE o e body) a
          (Eff.union εe (Eff.union εbody (Eff.single stateEff)))
    -- 01-06「明示遅延の型」、01-12「ストア」「関数の境界」「ハンドラ」: 純粋な本体。
    -- R = none は try と途中の return を禁じ、hideConts は外側の継続を隠す。
    | E_Lazy {C Γ R p body a} :
        HasBlock D B opPrim C (hideConts Γ) none .other body a Eff.empty →
        HasType D B opPrim C Γ R p (.lazyE body) (.lazy a) Eff.empty
    -- 01-06「エフェクトの宣言とハンドラの型付け」、01-12「ハンドラ」: C-Handle の宣言的な形。
    | E_Handle {C Γ R p body cs t εbody ε} :
        HasBlock D B opPrim C Γ R .other body t εbody →
        Eff.Sub εbody (Eff.union ε (handled D.patternProgram B cs.skeleton)) →
        HasClauses D B opPrim C Γ R cs t ε →
        HasType D B opPrim C Γ R p (.handleE body cs) t ε
    -- 同節: C-Resume。引数の計算と再開は同じ許容エフェクト ε で検査する。
    | E_Resume {C Γ R p k e b t ε} :
        Γ[k]? = some (some (.cont b t ε)) → HasType D B opPrim C Γ R .other e b ε →
        HasType D B opPrim C Γ R p (.resume k e) t ε
    -- 01-06「エフェクトの包含」「式のエフェクト」。最も外側の関数型だけを広げる。
    | E_Sub {C Γ R p e a a' ε ε'} :
        HasType D B opPrim C Γ R p e a ε → Ty.Le a a' → Eff.Sub ε ε' →
        HasType D B opPrim C Γ R p e a' ε'

  inductive HasTypes (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → Exprs → List Ty → Eff → Prop
    -- 01-06「式と文の型」: 引数がない呼び出し。
    | nil {C Γ R} : HasTypes D B opPrim C Γ R .nil [] Eff.empty
    -- 01-06「式と文の型」「エフェクトの包含」: 引数は書いた順で、各位置の型に受け入れる。
    | cons {C Γ R e es a as ε εs} :
        HasType D B opPrim C Γ R .other e a ε → HasTypes D B opPrim C Γ R es as εs →
        HasTypes D B opPrim C Γ R (.cons e es) (a :: as) (Eff.union ε εs)

  inductive HasEach (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → Exprs → Ty → Eff → Prop
    -- 01-06「式と文の型」: 空のリストの要素型は型検査が具体化済み。
    | nil {C Γ R a} : HasEach D B opPrim C Γ R .nil a Eff.empty
    -- 01-06「式と文の型」「エフェクトの包含」: リストの各要素。
    | cons {C Γ R e es a ε εs} :
        HasType D B opPrim C Γ R .other e a ε → HasEach D B opPrim C Γ R es a εs →
        HasEach D B opPrim C Γ R (.cons e es) a (Eff.union ε εs)

  inductive HasHoleArgs (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → HoleArgs → List Ty → Eff → Prop
    | nil {C Γ R} : HasHoleArgs D B opPrim C Γ R .nil [] Eff.empty
    | expr {C Γ R label position e args a as ε εs} :
        HasType D B opPrim C Γ R .other e a ε → HasHoleArgs D B opPrim C Γ R args as εs →
        HasHoleArgs D B opPrim C Γ R (.expr label position e args) (a :: as) (Eff.union ε εs)
    | hole {C Γ R label position t a args as ε} :
        Ty.Le t a → HasHoleArgs D B opPrim C Γ R args as ε →
        HasHoleArgs D B opPrim C Γ R (.hole label position t args) (a :: as) ε

  inductive HasArms (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → Position → Arms → Ty → Ty → Eff → Prop
    -- 空の分岐でも結果型の WF を要求する（Release.HasTypeArms.nil）。
    | nil {C Γ R p a b} : Ty.WF C.length b →
        HasArms D B opPrim C Γ R p .nil a b Eff.empty
    | plain {C Γ R p alts body rest a b ε εs δ} :
        Alternative.Valid alts → AltsTy D.patternProgram (Alternative.toCoreList alts) a δ →
        HasBlock D B opPrim C (binds δ ++ Γ) R p body b ε →
        HasArms D B opPrim C Γ R p rest a b εs →
        HasArms D B opPrim C Γ R p (.cons alts none body rest) a b (Eff.union ε εs)
    | guarded {C Γ R p alts guard body rest a b ε εs δ} :
        Alternative.Valid alts → AltsTy D.patternProgram (Alternative.toCoreList alts) a δ →
        HasType D B opPrim C (hideConts (binds δ ++ Γ)) none .other guard (.base .boolean) Eff.empty →
        HasBlock D B opPrim C (binds δ ++ Γ) R p body b ε →
        HasArms D B opPrim C Γ R p rest a b εs →
        HasArms D B opPrim C Γ R p (.cons alts (some guard) body rest) a b (Eff.union ε εs)

  /-- C-Handle の節と同じ環境。操作の引数と継続の引数は宣言の型をそのまま使う。 -/
  inductive HasClauses (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → Clauses → Ty → Eff → Prop
    | nil {C Γ R t ε} : HasClauses D B opPrim C Γ R .nil t ε
    | cons {C Γ R o n ntys body cs t ε sg} :
        opSig D.patternProgram B o = some sg → NamesWF sg.names sg.params → n = sg.params.length → ntys = sg.tparams.length →
        HasBlock D B opPrim (sg.tparams ++ C)
          (some (.cont sg.ret (t.shift ntys 0) ε) :: (binds sg.params ++ shiftEnv ntys Γ))
          (R.map (Ty.shift ntys 0)) .other body (t.shift ntys 0) ε →
        HasClauses D B opPrim C Γ R cs t ε →
        HasClauses D B opPrim C Γ R (.cons o n ntys body cs) t ε

  inductive HasBlock (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
      List TParam → List (Option Ty) → Option Ty → Position → Block → Ty → Eff → Prop
    -- 01-12「ブロック」: { }。01-06「式と文の型」: Unit。
    | B_Empty {C Γ R p} : HasBlock D B opPrim C Γ R p .empty (.base .unit) Eff.empty
    -- 01-12「ブロック」: { e }。01-08「末尾呼び出し」: 最後の式へ位置を渡す。
    | B_Last {C Γ R p e a ε} :
        HasType D B opPrim C Γ R p e a ε → HasBlock D B opPrim C Γ R p (.last e) a ε
    -- 01-12「ブロック」: { bind x <- e }、shadow も同じ。01-06: 最後が束縛なら Unit。
    | B_LastBind {C Γ R p k t e ε} :
        HasType D B opPrim C Γ R .other e t ε →
        HasBlock D B opPrim C Γ R p (.lastBind k t e) (.base .unit) ε
    -- 01-12「ブロック」: { bind _ <- e }。最後の束縛の行の _ の場合。
    | B_LastDiscard {C Γ R p e t ε} :
        HasType D B opPrim C Γ R .other e t ε →
        HasBlock D B opPrim C Γ R p (.lastDiscard e) (.base .unit) ε
    -- 01-12「ブロック」: { bind x <- e; s̄ }、shadow も同じ。01-06「多相」: 単相。
    | B_Bind {C Γ R p k t e rest a ε εs} :
        HasType D B opPrim C Γ R .other e t ε →
        HasBlock D B opPrim C (some t :: Γ) R p rest a εs →
        HasBlock D B opPrim C Γ R p (.bind k t e rest) a (Eff.union ε εs)
    -- 01-12「ブロック」: { bind _ <- e; s̄ }。_ は表層の環境を増やさない。
    | B_Discard {C Γ R p e rest t a ε εs} :
        HasType D B opPrim C Γ R .other e t ε → HasBlock D B opPrim C Γ R p rest a εs →
        HasBlock D B opPrim C Γ R p (.discard e rest) a (Eff.union ε εs)
    -- 01-12「ブロック」: { e; s̄ }。01-06: 式文は Unit、必ず抜ける文の後は不可。
    | B_Seq {C Γ R p e rest a ε εs} :
        HasType D B opPrim C Γ R .other e (.base .unit) ε → ¬ e.Exits →
        HasBlock D B opPrim C Γ R p rest a εs →
        HasBlock D B opPrim C Γ R p (.seq e rest) a (Eff.union ε εs)
    -- 01-12「ブロック」: 最後の bind p。変数と _ は既存の規則を使う。
    | B_LastPat {C Γ R p k pat t e ε δ} :
        pat.Nontrivial → pat.Valid → PatTy D.patternProgram pat.toCore t δ →
        ViewExhaustive D D.view t [pat.toCore] →
        HasType D B opPrim C Γ R .other e t ε →
        HasBlock D B opPrim C Γ R p (.lastPat k pat t e) (.base .unit) ε
    -- 必ず照合するとは一分岐で網羅すること。束縛の並びは Release と同じ。
    | B_BindPat {C Γ R p k pat t e rest a ε εs δ} :
        pat.Nontrivial → pat.Valid → PatTy D.patternProgram pat.toCore t δ →
        ViewExhaustive D D.view t [pat.toCore] →
        HasType D B opPrim C Γ R .other e t ε →
        HasBlock D B opPrim C (binds δ ++ Γ) R p rest a εs →
        HasBlock D B opPrim C Γ R p (.bindPat k pat t e rest) a (Eff.union ε εs)
    -- 01-06「エフェクトの包含」: 分岐のブロックの結果を受け入れる。
    | B_Sub {C Γ R p body a a' ε ε'} :
        HasBlock D B opPrim C Γ R p body a ε → Ty.Le a a' → Eff.Sub ε ε' →
        HasBlock D B opPrim C Γ R p body a' ε'
end

-- 01-12「トップレベルの関数」「型クラス」、01-06「式のエフェクト」「必ず抜ける文」。
-- 辞書の引数 d̄ と値の引数 x̄ をこの順で束縛し、R := B とする。
def Def.WellTyped (D : Declarations) (B : Builtins) (opPrim : OpPrim) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  (d.body.Exits ∨ d.ret = .base .unit) ∧
    HasBlock D B opPrim d.tparams (binds (d.dictTys ++ d.params)) (some d.ret) .tail d.body d.ret d.eff

-- 01-12「型クラス」D-Impl: d̄, x̄j:Ājθ; Bjθ ⊢ Mj : Bjθ ! εjθ、d̄ ⊢ Ui : Dict[Si, τ]。
def ImplDecl.WellTyped (D : Declarations) (B : Builtins) (opPrim : OpPrim) (id : ImplDecl)
    (views : MethName → CoverageView := fun _ => D.view) : Prop :=
  ∃ cd, D.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      (body.Exits ∨ id.methTy ms ms.ret = .base .unit) ∧
      HasBlock (D.withView (views m)) B opPrim (ms.tparams ++ id.tparams)
        (binds (id.dictTys.map (Ty.shift ms.tparams.length 0) ++ ms.params.map (id.methTy ms)))
        (some (id.methTy ms ms.ret)) .tail body (id.methTy ms ms.ret) ms.eff) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      DictEv.HasType D B id.tparams (binds id.dictTys) u (.dict s id.target))

-- 01-12「トップレベルの関数」: 全定義を、あらかじめ集めた宣言のもとで検査する。
def Program.WellTyped (p : Program) (B : Builtins) (opPrim : OpPrim) : Prop :=
  (∀ f d, p.defs f = some d → d.WellTyped (p.declarationsFor (p.functionViews f)) B opPrim) ∧
    (∀ l os, p.effects l = some os → B.effects l = none) ∧
    (∀ i id, p.impls i = some id → id.WellTyped p.declarations B opPrim (p.methodViews i))

/-- 01-07「プログラムの入口」の条件の写し。main の戻り値は Unit または
Result[Unit,String] であり、この条件は健全性の証明には使わない。 -/
def MainReturn (a : Ty) : Prop :=
  a = .base .unit ∨ a = .data "Result" [.base .unit, .base .string]

/-- 01-07 の入口の条件を表す。定義だけの型の保存には要求しない。
01-07 の許すエフェクトの名前は表の外で定めるため、集合 allowed を引数とする。 -/
def Program.HasMain (p : Program) (allowed : Eff) : Prop :=
  ∃ d, p.defs "main" = some d ∧ d.tparams = [] ∧ d.neffs = 0 ∧ d.names = [] ∧ d.params = [] ∧
    MainReturn d.ret ∧ Eff.Sub d.eff allowed

/-! 型付けの境界で、ソース順と契約順が異なる具体入力を検査する。 -/
namespace DefinitionExamples

private def intTy : Ty := .base .integer
private def boolTy : Ty := .base .boolean
private def askDecl : OpDecl :=
  { eff := "Ask", tparams := [], names := ["a", "b"], params := [intTy, boolTy], ret := intTy }
private def combineSig : MethSig :=
  { tparams := [], neffs := 0, names := ["a", "b"], params := [intTy, boolTy],
    ret := intTy, eff := Eff.empty }
private def combineClass : ClassDecl :=
  { supers := [], methods := fun m => if m = "combine" then some combineSig else none }
private def decls : Declarations :=
  { funs := fun _ => none,
    cons := fun c => if c = "Pair" then some ⟨"Pair", 0, [intTy, boolTy]⟩
      else if c = "Tuple" then some ⟨"Tuple", 0, [intTy, boolTy]⟩ else none,
    conFields := fun c => if c = "Pair" then some ["first", "second"] else none,
    ops := fun o => if o = "ask" then some askDecl else none,
    classes := fun c => if c = "Combine" then some combineClass else none }

private def reversed : Exprs := .cons (.literal (.boolean true)) (.cons (.literal (.integer 7)) .nil)
private def holes : HoleArgs := .hole (some "b") 1 boolTy (.hole (some "a") 0 intTy .nil)

-- 通常・穴・パイプの判断は同じ型付き callee を使う。引数の型はソース順に Boolean, Integer。
example (B : Builtins) (op : OpPrim) :
    HasType decls B op [] [some (.fn ["a", "b"] [intTy, boolTy] intTy Eff.empty)] none .other
      (.call (.local 0) [some "b", some "a"] [1, 0] reversed) intTy Eff.empty := by
  apply HasType.E_Call (names := ["a", "b"]) (ps := [intTy, boolTy])
    (εf := Eff.empty) (εargs := Eff.empty) (εcall := Eff.empty)
  · apply HasType.E_Local rfl
    intro b t ε h; cases h
  · dsimp [CallOk, NamesWF]
    decide
  · exact HasTypes.cons HasType.E_Literal (HasTypes.cons HasType.E_Literal HasTypes.nil)

example (B : Builtins) (op : OpPrim) :
    HasType decls B op [] [some (.fn ["a", "b"] [intTy, boolTy] intTy Eff.empty)] none .other
      (.partialCall (.local 0) ["a", "b"] holes intTy Eff.empty)
      (.fn ["b", "a"] [boolTy, intTy] intTy Eff.empty) Eff.empty := by
  apply HasType.E_PartialCall (ps := [intTy, boolTy]) (r0 := intTy)
    (εf := Eff.empty) (εargs := Eff.empty) (εcall := Eff.empty)
  · dsimp [holes, HoleArgs.holeTypes]
    decide
  · apply HasType.E_Local rfl
    intro b t ε h; cases h
  · dsimp [holes, HoleArgs.labels, HoleArgs.positions, CallOk, NamesWF]
    decide
  · dsimp [holes, HoleArgs.holeNames, HoleArgs.holeTypes, NamesWF]
    decide
  · exact HasHoleArgs.hole (Or.inl rfl) (HasHoleArgs.hole (Or.inl rfl) HasHoleArgs.nil)
  · exact Or.inl rfl
  · exact fun _ h => h

example (B : Builtins) (op : OpPrim) :
    HasType decls B op [] [some (.fn ["a", "b"] [intTy, boolTy] intTy Eff.empty)] none .other
      (.pipe (.literal (.integer 7))
        (.call (.local 0) [some "b"] [1] (.cons (.literal (.boolean true)) .nil))) intTy Eff.empty := by
  apply HasType.E_PipeCall (names := ["a", "b"]) (ps := [boolTy])
    (εl := Eff.empty) (εf := Eff.empty) (εargs := Eff.empty) (εcall := Eff.empty)
  · exact HasType.E_Literal
  · apply HasType.E_Local rfl
    intro b t ε h; cases h
  · dsimp [CallOk, NamesWF]
    decide
  · exact HasTypes.cons HasType.E_Literal HasTypes.nil

-- 操作も同じラベル検査を通り、開始するエフェクトだけが異なる。
example (B : Builtins) (op : OpPrim) :
    HasType decls B op [] [] none .other
      (.call (.opName "ask" []) [some "b", some "a"] [1, 0] reversed) intTy (Eff.single "Ask") := by
  apply HasType.E_Call (names := ["a", "b"]) (ps := [intTy, boolTy])
    (εf := Eff.empty) (εargs := Eff.empty) (εcall := Eff.single "Ask")
  · have h := HasType.E_Op (D := decls) (B := B) (opPrim := op) (C := []) (Γ := [])
        (R := none) (p := .other) (o := "ask") (ts := []) (od := askDecl) rfl
        (by unfold NamesWF askDecl; decide) ⟨rfl, by intro i t p h; simp at h⟩
    have he : Eff.substRho [] (Eff.single "Ask") = Eff.single "Ask" := by
      funext a; cases a <;> simp [Eff.substRho]
    simpa only [fnTy, askDecl, List.map_cons, List.map_nil, intTy, boolTy, Ty.subst, Ty.substAt, he] using h
  · dsimp [CallOk, NamesWF]
    decide
  · exact HasTypes.cons HasType.E_Literal (HasTypes.cons HasType.E_Literal HasTypes.nil)

-- 辞書の local は呼び出しラベルには含まれない。
example (B : Builtins) (op : OpPrim) :
    HasType decls B op [] [some (.dict "Combine" intTy)] none .other
      (.call (.methName (.local 0) "combine" [] [] [] ["a", "b"] [intTy, boolTy])
        [some "b", some "a"] [1, 0] reversed) intTy Eff.empty := by
  apply HasType.E_Call (names := ["a", "b"]) (ps := [intTy, boolTy])
    (εf := Eff.empty) (εargs := Eff.empty) (εcall := Eff.empty)
  · have h := HasType.E_MethName (D := decls) (B := B) (opPrim := op) (C := [])
        (Γ := [some (.dict "Combine" intTy)]) (R := none) (p := .other)
        (d := .local 0) (m := "combine") (ss := []) (es := []) (us := [])
        (names := ["a", "b"]) (ps := [intTy, boolTy])
        (cl := "Combine") (τ := intTy) (cd := combineClass) (ms := combineSig)
        (DictEv.HasType.local rfl) rfl rfl (by unfold NamesWF combineSig; decide) rfl
        ⟨rfl, by intro i t p h; simp at h⟩ rfl DictEv.HasTypes.nil
        (by simp [combineSig, intTy, boolTy, Ty.subst, Ty.substAt])
        (by intro a h cl t; simp only [List.head?_cons, Option.mem_def, Option.some.injEq] at h
            subst a; intro h; cases h)
    have he : Eff.substRho [] Eff.empty = Eff.empty := by
      funext a; cases a <;> simp [Eff.substRho, Eff.empty]
    simpa only [combineSig, intTy, Ty.subst, Ty.substAt, he] using h
  · dsimp [CallOk, NamesWF]
    decide
  · exact HasTypes.cons HasType.E_Literal (HasTypes.cons HasType.E_Literal HasTypes.nil)

-- 直接の構成子の穴は argN、構成子の関数値はレコードのフィールド名を使う。
example (B : Builtins) (op : OpPrim) :
    HasType decls B op [] [] none .other
      (.partialCon "Tuple" [] (.hole none 0 intTy (.expr none 1 (.literal (.boolean true)) .nil)))
      (.fn ["arg1"] [intTy] (.data "Tuple" []) Eff.empty) Eff.empty := by
  apply HasType.E_PartialCon (cd := ⟨"Tuple", 0, [intTy, boolTy]⟩) (r := .data "Tuple" []) (εargs := Eff.empty) rfl rfl rfl
  · dsimp [HoleArgs.holeTypes]
    decide
  · dsimp [HoleArgs.ConstructorOk, HoleArgs.labels, HoleArgs.positions]; decide
  · dsimp [NamesWF, HoleArgs.holeNames, HoleArgs.holeTypes, HoleArgs.positions, positionalNames]
    decide
  · simpa only [intTy, boolTy, Ty.subst, Ty.substAt, List.map_cons, List.map_nil, Literal.toConst, Const.type, Eff.union, Eff.empty] using
      (HasHoleArgs.hole (D := decls) (B := B) (opPrim := op) (C := []) (Γ := hideConts [])
        (R := some (.data "Tuple" [])) (label := none) (position := 0) (t := intTy)
        (a := intTy) (ε := Eff.empty) (Or.inl rfl)
        (HasHoleArgs.expr (label := none) (position := 1) (a := boolTy)
          (ε := Eff.empty) (εs := Eff.empty) (HasType.E_Literal (l := .boolean true)) HasHoleArgs.nil))
  · exact Or.inl rfl

example (B : Builtins) (op : OpPrim) :
    HasType decls B op [] [] none .other (.conValue "Pair" [] ["first", "second"] [intTy, boolTy])
      (.fn ["first", "second"] [intTy, boolTy] (.data "Pair" []) Eff.empty) Eff.empty := by
  apply HasType.E_ConValue (cd := ⟨"Pair", 0, [intTy, boolTy]⟩) rfl rfl rfl
  · unfold NamesWF; decide
  · simp [intTy, boolTy, Ty.subst, Ty.substAt]
  · decide

-- 誤った位置・重複・漏れ・混在・位置 0 の二重指定を、ラベル検査の境界で拒否する。
example : ¬ CallOk ["a", "b"] [intTy, boolTy] false [some "b", some "a"] [0, 1] := by unfold CallOk NamesWF; decide
example : ¬ CallOk ["a", "b"] [intTy, boolTy] false [some "a", some "a"] [0, 0] := by unfold CallOk NamesWF; decide
example : ¬ CallOk ["a", "b"] [intTy, boolTy] false [some "a"] [0] := by unfold CallOk NamesWF; decide
example : ¬ CallOk ["a", "b"] [intTy, boolTy] false [some "a", none] [0, 1] := by unfold CallOk NamesWF; decide
example : ¬ CallOk ["a", "b"] [intTy, boolTy] true [some "a"] [0] := by unfold CallOk NamesWF; decide
example : ¬ CallOk ["a", "b"] [intTy, boolTy] true [none] [1] := by unfold CallOk NamesWF; decide
example : ¬ CallOk ["a", "b"] [intTy, boolTy] false [some "a", some "other"] [0, 1] := by unfold CallOk NamesWF; decide
example : ¬ ([0, 2] : List Nat).Perm (List.range 2) := by decide
example : ¬ CallOk ["a", "a"] [intTy, boolTy] false [some "a", some "a"] [0, 1] := by unfold CallOk NamesWF; decide
example : ¬ HoleArgs.ConstructorOk (.hole (some "arg1") 0 intTy .nil) 1 := by
  unfold HoleArgs.ConstructorOk HoleArgs.labels HoleArgs.positions; decide
example : CallOk ["value"] [intTy] false [none] [0] := by unfold CallOk NamesWF; decide
example : CallOk [] [] false [] [] := by unfold CallOk NamesWF; decide
example : CallOk ["value"] [intTy] true [] [] := by unfold CallOk NamesWF; decide

end DefinitionExamples

end Benitoite.Surface
