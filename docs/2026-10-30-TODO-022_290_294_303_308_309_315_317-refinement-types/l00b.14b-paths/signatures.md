# L00b.14b-paths: 経路条件の完全署名と決定

2026-11-01。取りまとめの判断（plan の「計画の変更と取りまとめへの確認点」の先頭）に従い、HasTypeArmsQ 自身へ Option Term の添字を加えた。観測なしの別の判断は作らない。前回の停止はこの添字に対する承認待ちであり、今回の判断で解消した。D19 の反例は得ていない。

本書、[公開署名の検査入力](public-api.lean)、その完全な出力 [1](public-api-1.log)・[2](public-api-2.log) を一組の署名とする。出力は宣言の境界で分けた。新旧の規則、公開する補助、主な操作を含む171署名を記録している。完全名の一覧は [public-names.json](public-names.json) にある。以下の表で省略した型パラメータも、この出力には含まれる。

## 新旧の規則

略記として M(obs, alts) = pathFacts obs (matchedTests alts)、X(obs, alts) = pathFacts obs (excludedTests alts) とする。liftMany、bindParams、localExtend と R の shift は既存の定義を使う。

| 規則 | 開始版 | 新規則 |
|---|---|---|
| C_If | hv : v : Boolean、m と n は同じ Φ | v.toTerm? = some t を保持し、m は boolCond t true :: Φ、n は boolCond t false :: Φ |
| C_Match | 入力値の型と腕の導出を共有するが観測がない | obs : Option Term を腕と共有する。some t のとき v.toTerm? = some t と ∃ sort, t.HasSort Γ sort を保持する |
| plain | 束縛後の本体・残りの腕に同じ Φ | 本体へ M ++ Φ、残りの腕へ X ++ Φ を渡す |
| guarded | guard は Boolean、本体・残りの腕は同じ Φ | guard は純粋な Boolean{p}。guard は M ++ Φ、本体は p.open true :: liftMany (M ++ Φ)、残りは元の Φ |
| K_Guard | 評価前から本体の閉じた ClosureTy を要求する | GuardBodyTy に、条件前の CaptureOk と条件下のソースの本体の導出を保持する。結果型を入力型とし、真の結果から条件を足して ClosureTy を作る |

C_Match の obs = none は常に選べる。関数など観測できない値から事実を作らない。観測できる値にも none を選べるため、経路条件を必要としない旧導出を狭めない。

```lean
-- HasTypeArmsQ の R と arms の間へ観測の添字を追加した。
HasTypeArmsQ (P : Program) (B : Builtins) :
  StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty →
  Option Term → List Arm → Ty → Ty → Eff → (Δ : LocalCtx := []) → Prop
```

plain は次の四つを前提とする。期待する結果 b と効果 e、戻り先 R、局所文脈 L の添字は結論と共通である。

```lean
hp : AltsTy P alts a δ
hw : FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts))
hb : HasTypeCQ P B Ψ Q C (bindParams Γ δ)
  (liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
  (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
  (localExtend δ.length L)
hs : HasTypeArmsQ P B Ψ Q C Γ
  (pathFacts obs (excludedTests alts) ++ Φ) R obs arms a b e L
-- 結論: HasTypeArmsQ ... Γ Φ R obs (.mk alts none body :: arms) a b e L
```

guarded は hp・hw に加え、次の四つを前提とする。guard の構文を観測項にせず、その結果の型の p を使う。

```lean
hgp : Ty.Annotation P C (hideConts (bindParams Γ δ)) (.refined (.base .boolean) p)
hg : HasTypeCQ P B Ψ Q C (hideConts (bindParams Γ δ))
  (liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ)) none guard
  (.refined (.base .boolean) p) Eff.empty (localExtend δ.length L)
hb : HasTypeCQ P B Ψ Q C (bindParams Γ δ)
  (p.open (.boolean true) :: liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
  (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
  (localExtend δ.length L)
hs : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L
-- 結論: HasTypeArmsQ ... Γ Φ R obs (.mk alts (some guard) body :: arms) a b e L
```

## 事実を作る定義と観測の像

[PathFacts.lean](../../../formal/Benitoite/Release/Refinement/PathFacts.lean) に次を置いた。FactsWF と Pred.WellFormed、およびその基礎の map 補題は、Typing より前で使うため Context/Facts から移した。定義の内容は変えていない。

```lean
inductive PathTest where
  | constructor (name : ConName)
  | nonempty
  | excluded (name : ConName)
  | literal (value : PathLiteral)
  | integerRange (lo hi : Int)
  | characterRange (lo hi : Char)
  | empty
  | negated (test : PathTest)
  | either (left right : PathTest)
def PathTest.predicate : PathTest → Term → Pred
-- constructor c: constructorIs t c
-- nonempty: lt (integer 0) (measure listLength t)
-- excluded c: not (constructorIs t c)
def pathFacts : Option Term → List PathTest → List Pred
-- none は []、some t は各 PathTest の predicate t の列。
def matchedTests : List Alt → List PathTest
def excludedTests : List Alt → List PathTest
```

PathLiteral は integer Int・character Char・boolean Bool・string String・unit の5場合である。pathLiteral? は、PatTy が許す原典の Integer（64 bit）・Character・Boolean・String・Unit のリテラルだけを写す。Float/Decimal/Byte/幅別整数/opaque などは現行のパターンとして許されず、事実も作らない。範囲は PatTy の Integer/Character の二種類である。

literal は整数なら eq、それ以外は対応する sort の compare eq、範囲は両端を含む二つの le の And、empty は List 長さの eq 0 とする。negated/either は Not/Or である。PathTest.predicate の bind と root_sorted は構造帰納で閉じた。

patternTest? : Pat → Option PathTest は、構成子の根、上記リテラル、範囲、空 List、要素を要求する List の非空を作る。alternativesTest : List Alt → Option PathTest は全選択肢の事実の Or を作る。matchedTests は全選択肢が同じ事実なら従来の単一事実を保ち、異なっても全選択肢に事実があれば Or を作り、一つでも事実がなければ空列を返す。

excludedTest? : Pat → Option PathTest はリテラル・範囲の否定、空 List の後の非空、全欄が wild 又は var の構成子の否定を作る。excludedTests は全選択肢について作れた否定の列を返す。成功時に根の事実を作れる構成子でも、欄の照合が失敗しうる場合は、その根の否定を作らない。従って Or の後続の否定も excludedTest? が作れるものだけである。irrefutableField は wild/var の二形だけを受け付ける。入れ子の構成子の唯一性は調べない。guarded の後続へは除外も guard の偽も渡さない。

値の置換の観測像は `obs.bind (termBind? (valEnv σ).values)` とする。値の移動は全域の改名なので `obs.map (termBind (renEnv ξ).values)`、型の移動と narrow は obs のままである。subst_under_none は upSubst 1 σ の部分的な像を使う。

`pathFacts_bind` は FactsWF と ImagesSorted・ImageReferences から、事実列を predBind した結果が、この部分的な観測像で再構成する事実列と等しいことを示す。元の事実列が非空なら、根に sort があり termBind? は成功する。空列なら観測を失っても事実列は空である。Option.map termBind による整数0の既定値は使わない。値の変化を無条件に観測できるという仮定も加えない。

## 旧導出と主な操作

HasTypeVQ・HasTypeCQ の subst、subst_under_none、shift_values、shift_types、narrow の前提と結論は変えていない。[primary-api-baseline.log](primary-api-baseline.log) は前回停止時の公開出力から抜いた10署名であり、[primary-api-comparison.json](primary-api-comparison.json) が空白を除く一致を記録する。B_WORK のソースを git で取り出した比較ではない。

相互帰納の腕の節は、承認された obs の像を結論へ持つ。旧規則は次の補題で読める。

| 補題 | 提供するもの |
|---|---|
| HasTypeVQ.weaken_conditions / HasTypeCQ.weaken_conditions / HasTypeArmsQ.weaken_conditions / ImageOk.weaken_conditions | 元の Φ の各事実を新しい条件から導ければ、同じ値・計算・腕・像をその条件で型付ける |
| HasTypeCQ.if_legacy | 旧 if の二本の導出から新 C_If。Boolean の観測は値の型付けから得る |
| HasTypeArmsQ.plain_legacy | obs = none で旧 plain の導出を読む |
| HasTypeArmsQ.guarded_legacy | 旧 Boolean guard を Boolean{truth} にし、本体を条件の下へ弱化する |
| HasTypeCQ.match_legacy | 同じ HasTypeArmsQ の obs = none から旧 C_Match を読む |

弱化と guarded_legacy は既存の ValueAssumptions と StoreTy.WF を使う。新しい公理や型付けの構成子を弱化のために追加しない。観測なしの古い判断を別に置いたものではない。

## GuardBodyTy と保存の署名

GuardBodyTy は相互三族とは独立の一構成子である。条件前の CaptureOk、本体の開いた導出、結果の閉じた行の Annotation、局所参照の解決、R の閉鎖を保持する。結果の Annotation を閉じた形で保持する理由は、開始の StateTyE の最終結果の注釈を使うためである。ソースの行全体の Annotation を新たに要求する案は採らない。本体の閉じた ClosureTy は前提に含めない。

```lean
inductive GuardBodyTy (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty) :
    Closure → Ty → Ty → Eff → Prop where
  | mk {cap code0 code Γ Φ Rs p a e L ρ} :
      CaptureOk P B Ψ R Γ Φ cap →
      Ty.Annotation P [] Γ (.refined (.base .boolean) p) →
      HasTypeCQ P B Ψ Qempty [] Γ (p.open (.boolean true) :: Φ) Rs code0 a e L →
      CaptureLocals Ψ cap.env L ρ → code = code0.resolveLocals ρ →
      Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))) →
      cap.closeR Rs = R → (∀ r, Rs = some r → r.Declared P [] Γ) →
      GuardBodyTy P B Ψ R (.mk cap code)
        (cap.closeTy (.refined (.base .boolean) p)) (cap.closeTy a) (cap.closeEff e)
```

| 公開補題 | 入力と結論 |
|---|---|
| ClosureTy.ite_selected、StateTyE.if_true / if_false | 開始の閉包又は状態と実際の if の view から選んだ枝を型付ける。追加の組み込み仮定はない |
| GuardBodyTy.of_true | pending と true の結果型での HasTypeV から、本体の ClosureTy |
| ClosureTy.ret_const | 開始 ClosureTy と定数を返す view から、その定数を最終の結果型で型付ける。既存の SubstitutionAssumptions と StoreTy.WF を使う |
| StateTyE.guard_true | 開始 StateTyE、ret true の view、既存の SubstitutionAssumptions から本体の StateTyE |
| StateTyE.guard_false | 開始 StateTyE と ret false の view から後続の matchRun の StateTyE |
| HasTypeCQ.match_arms | C_Sub・C_Normal・C_Eff を逆転し、全腕の導出を最終の型・効果へ変換する |
| ClosureTy.open_zero / match_source | 入力なしの閉包からソースの文脈・条件・導出・捕捉・局所参照の解決を取り出す |
| HasTypeVQ.close_ground と VsQ / EachQ の節 | CaptureOk とソース・捕捉の閉性から、実際の closeVal の Ground。値29場合を含む相互証明 |
| StateTyE.match_start / match_skip | 開始 StateTyE と実際の view 又は照合の失敗から次の matchRun |
| StateTyE.match_body_zero | 開始 StateTyE、選択した無 guard の腕、束縛数0、firstAlt の実際の成功、下記の評価入力から本体の StateTyE |

StateTy.guard_true / guard_false / match_start / match_skip / match_body_zero も提供する。ContTy の K_Sub の連鎖も逆転する。true では結果型の事実を addEntailed で捕捉へ足し、false では元の照合全体の ClosureTy を再構成する。if と match の評価成功は addEvaluated で捕捉へ足す。**到達する State・StateTyE に経路条件の欄は追加しない。**

## match の評価の補助入力と提供範囲

```lean
def PathsEvaluated (v : Val) (tests : List PathTest) : Prop :=
  ∀ p ∈ pathFacts v.toTerm? tests, p.evalClosed = some true

def MatchPathsEvaluated (v : Val) (arms : List Arm) (next : Nat) : Prop :=
  (∀ i alts guard body, arms[i]? = some (.mk alts guard body) → i < next → guard = none →
    PathsEvaluated v (excludedTests alts)) ∧
  (∀ alts guard body, arms[next]? = some (.mk alts guard body) →
    PathsEvaluated v (matchedTests alts))
```

この入力には本体の型付け、到達の ClosureTy・StateTyE、Entails を含めない。CaptureOk.paths_evaluate が実際の値の観測とソースの観測を一致させ、addEvaluatedFacts が有限列の閉じた評価から捕捉を構成する。ソースの腕の導出は開始の StateTyE から逆転する。境界ではこの入力を具体の評価で与える。

E_MatchBody のこの代表は束縛数0である。firstAlt の成否から事実の評価を導く部分は下記 MatchFacts で閉じた。閉じた AltsTy・実際の値の型付け・閉じた事実の WF/Sorted の導出を開始の状態から合成し、束縛値を型付ける部分と、一般の E_MatchBody・E_MatchGuard の開始状態からの保存は L20 に残す。E_MatchGuard の変数一個の例は実際の前後を構成するが、一般の開始の逆転の定理とは数えない。型付け規則や利用者の記述をこの代表に限定していない。

## 場合の数と後段

| 対象 | 予定 | 実装・検査 |
|---|---:|---:|
| 相互三族 | 14族・76場合 | 14族・76場合 |
| 値 / 計算 / Step / ContTy | 29 / 24 / 76 / 10 | 同じ |
| 追加の PathTest / PathLiteral / GuardBodyTy | 9 / 5 / 1 | 9 / 5 / 1 |
| if と guard の開始状態からの保存 | 4遷移 | 4遷移 |
| 追加の match の開始状態からの代表 | 開始・skip・本体 | 3遷移。本体は上記の補助入力と束縛数0 |

L20 には一般のパターン束縛と全状態の保存、L30 には O054 の開いた Boolean の等号の合同・定数の相異、L40 には標準の比較組み込みの実表・canonical forms・実行との接続、L70 には主定理への合成と規範の切替を残す。O054 の or_elim・not_intro は既に Logic と LogicSound にあり、未実装とは数えない。

## 決定の記録

| 採った案 | 理由 | 採らなかった案 |
|---|---|---|
| HasTypeArmsQ に obs を追加 | 取りまとめの承認に従い、C_Match と被検査値を共有する | 別名の判断を本番へ入れ、旧判断を残す |
| 値の置換は Option.bind termBind? | 観測の失敗と全域の termBind の既定値を区別する | Option.map termBind を無条件に使う |
| 根・リテラル・範囲・空/非空と、全選択肢の Or を足す | 成功した選択肢の事実から Or を導ける | 一部の選択肢だけの事実を全体に足す |
| 無 guard で全欄が wild/var の構成子を除外する | 欄の数を型で揃えると欄の照合は失敗しない | 欄を絞るパターンや guard の失敗から根を除く |
| guard の真の条件は結果型から読む | guard は計算であり、ソースの guard 自体の観測は使わない | guard を値として観測する |
| guard の偽の事実を後続へ渡さない | 腕の束縛が後続の文脈にはない | 偽の guard を構成子の除外とする |
| GuardBodyTy に閉じた結果の注釈を保持 | 開始の状態の最終の結果の注釈を使い、ソースの追加の行の注釈を要求しない | 評価前の本体の ClosureTy を要求する |
| match の代表は評価だけを補助入力にする | L20 の束縛の保存を先取りせず D19 の実際の閉鎖を調べる | 到達の型付けを補助入力にする |
| let c の接続は L30 後の条件付きの形として記録する | apart は現行の Entails で導けない | 前提 apart を満たす現在の導出があるとする |

## 短絡の項と境界

処理系の finish_logic_binary の読解では、and は if lhs then rhs else false、or は if lhs then true else rhs に脱糖する。Lean の Comp に専用の and/or はない。従って右辺は C_If の真又は偽の条件を読む。Rust と Lean の実行比較は行っていない。

boundary の Guard.signature は、比較結果の Boolean の self と整数引数の関係を宣言する。Guard.let_if_connect は L30 の規則を足した後の C_Let・C_If の接続の形である。入力 apart は rv-14bp-t2 の apart_not_derivable により現行の Entails では導けず、現在適用できる導出ではない。結果型の偽の側を not(self=true) で書けば真の枝は apart なしで閉じる。O054 が必須なのは self=false の宣言を真の枝で読む場合と、変数の条件の偽の枝を読む場合である。

ShortCircuit.short_circuit_reads_left は、実際の脱糖の形 let c = if a then b else false; if c … を apart なしで型付け、真の枝で a の事実を読む。短絡の偽の側を変数の条件から読む部分は O054 として L30 に残す。

## 続き2: 照合の成否からの事実の健全性

事前署名は今回の実装に先立って本書へ記録した。最終の署名は公開出力に含まれる。新しい [MatchFacts.lean](../../../formal/Benitoite/Release/Refinement/MatchFacts.lean) は次を提供する。名前空間は Benitoite.Release.Refinement.MatchFacts である。

```lean
theorem matched_true {v ws alts test t}
    (hf : firstAlt v alts = some ws) (hm : test ∈ matchedTests alts)
    (ht : v.toTerm? = some t) :
    (test.predicate t).evalWith (fun _ => none) = some true

theorem excluded_true {P alts a δ v test t}
    (ha : AltsTy P alts a δ) (hv : RootShape P a v)
    (hf : firstAlt v alts = none) (hm : test ∈ excludedTests alts)
    (ht : v.toTerm? = some t) :
    (test.predicate t).evalWith (fun _ => none) = some true
```

matched_evalClosed_true / excluded_evalClosed_true は、それぞれ上の入力に (test.predicate t).WF 0 と Sorted [] none を足して evalClosed = some true を返す。matched_paths_true / excluded_paths_true は、同じ内容を事実列の PathsEvaluated にまとめる。評価の成功・Entails・本体や到達の型付けは仮定しない。

成功の証明は firstAlt_some_mem、pattern_test_true、alternatives_test_true を使う。構成子・非空だけでなく、リテラル・範囲・空 List・Or の事実を含む。失敗の証明は firstAlt_none_all と pattern_excluded_true を使う。PatTy.binders_length・PatTys.binders_length、matchVal_binders・matchList_binders、selectSlots_total により、AltsTy の slots の妥当性から実際の各選択肢の失敗を得る。slots=[] という制限は加えない。

除外の根の形の入力は、再レビューに従って RootShape へ替えた。RootShape.scalar/list/data と PatTys.arity_length を使い、値幅・構成子の欄数・At の欄数を観測の sort だけで代用しない。rootShape_of_typing が閉じた値の型付けからこの入力を構成する。At の場合は V_AtError の shape.Declared にある7欄の宣言から根の形を得る。閉じた WF/Sorted は、関数の欄を none として観測することと両立する。一般の開始状態から閉じた腕・値の型付け・WF/Sorted を構成する合成は L20 に残す。

## 腕の取り出しと決定の記録

HasTypeArmsQ.capture_plain_zero は任意の δ を返す公開補題 HasTypeArmsQ.capture_plain へ一般化した。入力の開始の腕の導出・CaptureOk・観測の一致・実際の値・選択した位置・MatchPathsEvaluated は同じ趣旨で、結論は ∃ δ Ξ, AltsTy P alts a δ ∧ CaptureOk … Γ Ξ cap ∧ HasTypeCQ … (bindParams Γ δ) (liftMany δ.length Ξ) … である。match_body_zero は δ.length=0 からこの補題を使う。

HasTypeArmsQ.guard_context は再レビューに従って削除した。prior が Φ の前にあるだけでは先行する無 guard の腕の除外を取り出せず、利用先もない。L20 で必要なら、開始の状態と捕捉に合う guard の取り出しを必要な形で作る。

| 採った案 | 理由 | 採らなかった案 |
|---|---|---|
| リテラル5種、範囲2種を PathTest で扱う | 既存の Term/Pred と PatTy で表せ、置換の規則を変えずに閉じる | Float/Decimal/Byte/幅別整数など、現行のパターンとして許されないものにも事実を作る |
| 空 List の本体へ長さ0、後続へ非空を足す | 同じ根の measure で作れ、実際の照合の成否から証明できる | 本体側の事実を省く |
| Or の本体は全選択肢の Or、後続は作れた全否定の列 | 成功では一選択肢の事実で足り、失敗では各選択肢が失敗する | 一つでも本体の事実がない Or に部分的な事実を渡す |
| 構成子の全欄は wild/var のみで除外を認める | 構文で失敗しないことを証明できる | 入れ子の構成子の唯一性を解析する。型による全域性を新たに判定する |
| 欄を絞る構成子は根を除外しない | Box(4) は Box(3) に失敗するが not(constructorIs Box) は偽になる。境界に実行可能な反例と否定の導出不可を残した | 引数付きなら一律に根を除く |
| guard_context を削除する | prior の内容がなく利用先もない。L20 の guard の取り出しは必要な形で作る | 任意の prior だけを返す補助を残す |
| 公開の健全性は AltsTy と RootShape から証明する | RootShape は閉じた型付けから導け、要素や欄の内部に Inhabits を要求しない | evalClosed = some true を入力に置く。Inhabits の範囲を変える |

L20 の一般の guard の入口は、hgp の hideConts から本体の文脈への Annotation の変換を依然必要とする。rv-14bp-t5 が閉じたのは観測の像の sort である。主な VQ/CQ の10署名は維持した。rv-* と独立レビュー本文・plan は変更しない。

## 続き3: 根の形の入力と型付けからの構成

事前署名は今回の実装に先立って本書へ記録した。最終の完全署名は公開出力にある。RootShape は型の根で分岐し、List の要素や構成子の欄を再帰的に調べない。

```lean
def RootShape (P : Program) : Ty → Val → Prop
  | .base base, v => ∃ c, v = .const c ∧ c.type = .base base
  | .list _, v => ∃ elems, v = .list elems
  | .data _ _, v =>
      (∃ c tys args cd, v = .con c tys args ∧ P.cons c = some cd ∧ args.length = cd.args.length) ∨
      (∃ detail cd, v = .atError detail ∧ P.cons "Scope.ScopeError.At" = some cd ∧
        cd.args.length = detail.values.length)
  | .refined a _, v => RootShape P a v
  | _, _ => True

theorem rootShape_of_typing {P B Ψ Q C Φ v a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v a) : RootShape P a v

theorem excluded_paths_true_of_typing {P B Ψ Q C Φ alts a δ v}
    (ha : AltsTy P alts a δ) (hv : HasTypeVQ P B Ψ Q C [] Φ v a)
    (hm : firstAlt v alts = none)
    (hw : ∀ p ∈ pathFacts v.toTerm? (excludedTests alts), p.WF 0 ∧ p.Sorted [] none) :
    PathsEvaluated v (excludedTests alts)
```

RootShape.core/refineNorm/norm/subtype は篩・正規化・部分型で根の形を移す。typed_values_length は構成子の欄数を得る。rootShape_of_typing は VQ の29場合を扱い、V_CheckedAt と scoped_forget も通る。追加の Builtins の仮定、ストアの整形式、評価成功や到達の型付けは要求しない。値の文脈は [] であり、Q・型パラメータ・Φ は任意である。

excluded_true・excluded_evalClosed_true・excluded_paths_true と、literal/range/constructor/empty の失敗の補助は Inhabits の入力を RootShape に替えた。閉じた型付けを入力とする入口 excluded_true_of_typing・excluded_evalClosed_true_of_typing・excluded_paths_true_of_typing も提供する。主な VQ/CQ の10署名は変更しない。

match-boundary の CheckedAt は CheckedWitness と opaque の注釈を補助入力に、V_CheckedAt → scoped_forget → List/構成子の型付けを構成する。list_excluded_from_typing/box_excluded_from_typing は閉じた値の型付けとパターンの型付けだけを入力とし、実際の firstAlt の失敗を証明して除外を評価する。list_example/box_example はそれらへ構成した型付けを渡す。List の正規化を通る root の例もある。

| 採った案 | 理由 | 採らなかった案 |
|---|---|---|
| 根の形だけを RootShape で述べる | List の要素・構成子の欄が checkedAt でも、除外に必要な形は型付けから導ける | Inhabits に checkedAt を追加して Exhaustive の量化範囲を変える |
| data の根では宣言と欄数だけを保持 | 構成子の否定で使うのは根と欄数であり、欄の再帰的な型適合は不要 | InhabitsAll を補助の前提として残す |
| guard_context を削除する | 任意の prior の内容を特定できず、L20 の保存に必要な捕捉を構成できない | 利用先のない補助を残す |

Inhabits と Exhaustive の定義は変えていない。checkedAt_not_inhabits と list_checkedAt_not_inhabits を境界にも残した。HasTypeV から Inhabits への全域の含意は現在成り立たない。Exhaustive を型付き値全域の進行へ接続する側の不足は L20 の入力として残し、今回の除外の健全性の前提には使わない。L20 は一般の guard に必要な取り出しを、その段で必要な形に作る。
