# L00b.14a: 一引数の依存βの完全署名

2026-11-01。ブランチは `m014/l00b.14a`、B_WORK は `0fbd34415aa659922378aa9769bac6e513bd061e`。git 操作と work は行わない。本書を本番の実装より先に置いた。名前空間は `Benitoite.Release.Refinement` である。既存の主定理・判断・信頼条件の欄は変えない。

## 置換と実行時の捕捉の接続

以下の暗黙引数の型は既存判断から推論する。`P : Program`、`B : Builtins`、`Ψ : StoreTy`、`Q : NoFailCtx`、`C : List TParam`、`Γ : Ctx`、`Φ : List Pred`、`R : Option Ty`、`a x : Ty`、`e : Eff`、`body : Comp`、`v : Val` である。

```lean
theorem HasTypeCQ.open_one {P B Ψ Q C Γ Φ R body a e x v}
  (hb : HasTypeCQ P B Ψ Q C (Γ.extend x) (Φ.map Pred.lift) R body a e [])
  (hA : Builtins.SubstitutionAssumptions P B) (hΨ : Ψ.WF)
  (hx : Ty.Annotation P C Γ x) (hΓ : Ctx.WF 0 C.length Γ)
  (hv : HasTypeVQ P B Ψ Q C Γ Φ v x) :
  HasTypeCQ P B Ψ Q C Γ Φ (R.map (substTyValues (openValue v)))
    (body.subst (openValue v) LocalRef.bound)
    (substTyValues (openValue v) a) (substEffValues (openValue v) e) []

theorem Capture.empty_closeTel {t : Tel} (hw : t.WF 0 0 0) (hn : t.Normal) :
  Capture.empty.closeTel t = t

theorem Capture.instantiate_one {name : String} {x a : Ty} {e : Eff} (v : Val)
  (hw : (Tel.param name x (.done a e)).WF 0 0 0)
  (hn : (Tel.param name x (.done a e)).Normal) :
  (Capture.empty.extend v).closeTy a = substTyValues (openValue v) a ∧
  (Capture.empty.extend v).closeEff e = substEffValues (openValue v) e

theorem HasTypeTelArgsQ.one {P B Ψ Q C Γ Φ name x a e v}
  (ht : Ty.Annotation P C Γ (.dependentFn (.param name x (.done a e))))
  (hΓ : Ctx.WF 0 C.length Γ) (hv : HasTypeVQ P B Ψ Q C Γ Φ v x) :
  HasTypeTelArgsQ P B Ψ Q C Γ Φ [v] (.param name x (.done a e))
    (substTyValues (openValue v) a) (substEffValues (openValue v) e)

theorem ClosureTy.dependent_one {P B Ψ name x a e body v}
  (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
  (hn : (Tel.param name x (.done a e)).Normal)
  (hb : HasTypeC P B Ψ [] (Ctx.extend [] x) [] (some a) body a e)
  (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground) :
  ClosureTy P B Ψ [] (some (substTyValues (openValue v) a))
    ((Closure.pure body).apply [v])
    (substTyValues (openValue v) a) (substEffValues (openValue v) e)
```

`open_one` は任意の Γ/Φ を扱う。状態の代表は外側の捕捉なし・型/行引数なし・一引数の正規形の依存列とする。実行時の本体は置換した Comp に取り替えず、`Closure.apply` が作る捕捉環境を残す。

## 同じ契約と固定 Eb の状態遷移

```lean
theorem ContTy.markPush {P B σ Ψ ε k a b Eb Re}
  (h : ContTy P B σ Ψ none ε k a b Eb Re) (ha : Ty.Annotation P [] [] a) :
  ContTy P B σ Ψ (some a) ε (markPush k) a b Eb Re

theorem StateTyE.dependent_beta_one
  {P B σ Ψ μ name x a e body v k b ε Eb}
  (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
  (hn : (Tel.param name x (.done a e)).Normal)
  (hh : hideBuilders Ψ = Ψ)
  (hb : HasTypeC P B Ψ [] (Ctx.extend [] x) [] (some a) body a e)
  (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
  (hcv : closeVal Capture.empty v = v)
  (hs : StoreOk P B σ Ψ μ)
  (hk : ContTy P B σ Ψ none ε k (substTyValues (openValue v) a) b Eb none)
  (he : Eff.Sub (substEffValues (openValue v) e) ε)
  (hbody : body.Adequate σ) (hval : v.Adequate σ)
  (hcbody : body.ClosedAt 0 1) (hck : k.Closed) (hcμ : μ.Closed) :
  StateTyE P B σ Eb
    (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) ∧
  Step P B σ
    (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) none
    (.run ((Closure.pure body).apply [v]) (markPush k) μ) ∧
  StateTyE P B σ Eb (.run ((Closure.pure body).apply [v]) (markPush k) μ)
```

`StateTy.dependent_beta_one` は同じ全引数・前提に `hσ : σ.Valid` と `hEb : BuiltinOnly P B Eb` を加え、上の前後の `StateTyE` を `StateTy` にした三項の連言を返す。存在量化する b、現在の行 ε、ストアの Ψ/μ は両側で同じ証人を使い、σ と Eb も同じまま保つ。開始状態・到達状態の型付けを結論として構成するため、到達状態を前提にしない。

## facts と外部応答の入口

`HasTypeVQ.facts` に渡す観測は `toTerm? = some t` である。既定の整数0を実観測とみなさない。境界では `groundVal_ground` で bool の成功から Ground を得る。外部応答には既存の `Builtins.ExternalAssumptions.checked_typed` と `externalReceive` の成功を使い、受信後の `Outcome.Typed` から元の結果型の値の型付けを得てから facts を読む。Carrier から篩の事実を読む規則は足さない。必要な外部受信の補助署名は、実装前の本書への追記で具体化する。

## 場合の数と境界の入力

予定は依存βの代表1場合（E_Lam）、markPush の2形（既存の mark／それ以外）である。mark の排除は ContTy の10構成子を尽くす。新しい構成子は加えず、既存の相互三族76場合・Step76場合を保つ。一般の相互置換を証明し直す作業ではなく、完成済みの入口を特殊化する。

境界は、実引数7が結果の述語 `self = x` と Fail の型へ入る一引数を使う。実際の E_Lam の前後で StateTy を構成し、到達した本体の return 値を型付け、L00b.13 の facts から `7 = 7` を取り出す。`7 = 8` や `False` は導けないことを論理の健全性で確かめる。負例は別の整形式違反で拒まれたことを成功と数えない。

## 補助の契約の決定の記録

| 論点 | 採った案・理由 | 捨てた案・主定理を制限しない理由 |
|---|---|---|
| 状態の代表 | 外側捕捉なし・一引数・正規形の列で、任意の本体/実引数/継続/参照やlazyのあるストアを扱う | 全保存の前提へこの制限を追加しない。一般の捕捉・非正規形は下表に残す |
| builder の非捕捉 | 代表のストアには `hideBuilders Ψ = Ψ` を使う。V_DependentLam の本体の読み手と一致させる | hide の一般移送を暗黙に済ませない。一般のストアの復元は L20 の義務であり、StateTy の定義は変えない |
| 実行時のβ | 捕捉に実引数を足し、型/効果の置換と一致する補題で結ぶ | 実行の本体を Comp.subst へ変えない。SubstTyping の特殊化と本番 Step の双方を残す |
| 契約の正規化 | 元の列の WF と Normal を明示し、閉じた像との等号を証明する | WF だけから Normal を仮定しない。一般の fn/dependentFn の逆転・変換は L40 に残す |
| 閉じた事実 | CaptureOk.extend と既存の facts を使う | Φ を状態に新設しない。D19 の方式と一般の open_one の量化を保つ |

## 全βへ残す言明・依存・配分

能動時間は実測ではなく、後続の既存枠の内数である。同じ証明を二段へ加算しない。

| 残る言明 | 依存 | 能動時間の見込み | 送り先 |
|---|---|---:|---|
| 任意の引数列で Closure.apply の結果を Tel.instantiate の同じ結果/効果で型付ける | extendTel、Capture.instantiate、全本体/局所参照の対応 | 2〜4時間 | L20 |
| 多相の型/行/範囲引数を含む E_Fun/E_Meth の本体具体化と契約の一致 | 型/行/範囲/値の交換・宣言の WellTyped | 3〜6時間 | L20 |
| 外側の捕捉 Γ/Φ と hideConts/hideBuilders を通る Closure.apply の型付け | 捕捉したΦの代表（L00b.14b）、CaptureOk.extendTel、局所参照 | 2〜4時間 | L20 |
| C_App/C_DependentApp、V_Sub/V_Normal/V_Refine の全逆転から実際の関数の契約を得て開始の契約へ戻す | inv_closure、TelClosure の引数反変・結果/効果共変 | 3〜6時間 | L40 |
| fn/dependentFn と raw の注釈が正規化を通るβで同じ契約を保つ | fnCore、normalization、NamesWF、RuntimeShape | 1〜3時間 | L40 |
| 一般の builder ストア/局所参照を持つ閉包の復元と StoreOk/ContTy の全保存 | ストアの単調性・局所解決・全枠 | 2〜4時間 | L20 |
| δ/IO/外部受信の全βに対する facts と同じ固定 Eb の合成 | 応答の型付け、受信検査、全 canonical forms | 2〜4時間 | L40 |

O008/O051 は今回の代表と一般化を区別する。閉包環境を捨てる既存の反例を変えない。Reference/Lazy/節/resume は L00b.14b〜.14e の代表と L20/L40 の全保存の義務のまま残す。

### 実装前の補足: 評価済みの実引数

状態の代表には `hcv : closeVal Capture.empty v = v` を明記する。Ground なソースの lam は closeVal で closure に変わるため、Ground だけで値の不変は導けない。評価済みの整数・保持値・場所・closure や、それらからなる不変な値ではこの等号を示せる。未評価のソースのラムダを実引数にする一般化は、値の閉じ方の型保存として L20 に含める。これは補助の代表の限定であり、StateTy/Step/主定理の前提に加えない。署名を具体化した後に実装する。

## return の葉と受信後の facts の追加署名

```lean
theorem HasTypeCQ.ret_value {P B Ψ Q C Γ Φ R m a e L v}
  (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hm : m = .ret v) :
  HasTypeVQ P B Ψ Q C Γ Φ v a

theorem Builtins.ExternalAssumptions.received_facts
  {P B Ψ f d ts vs a e out obs v t}
  (h : Builtins.ExternalAssumptions P B) (hw : P.ExternalWF)
  (hd : P.externalFunction f = some d) (ha : ExternalArgs P B Ψ d ts vs a e)
  (hr : B.externalResponse f ts vs out obs)
  (hrec : externalReceive P d ts vs out = some (.val v)) (σ : PathEnv)
  (ht : v.toTerm? = some t) :
  HasTypeV P B Ψ [] [] [] v a ∧ v.Ground ∧ v.Adequate σ ∧
    ∀ p ∈ a.assume, Entails [] (p.open t)
```

ret_value は計算の24場合を尽くし、C_Sub の部分型と C_Eff/C_Normal を通る。全計算・全状態の逆転は新設しない。received_facts は既存の received_value からのみ元の型付けを取り出す。外部の信頼条件の欄は増やさない。

## 境界の確定と追加の申し送り

境界の effect は `Fail[Integer{self = x}]` であり、実引数7を代入すると `Fail[Integer{self = 7}]` となる。Fail を処理する継続を実際に構成し、両状態の末尾の効果を empty に固定する。計算の型付けを一引数の置換で移し、ret_value で到達した本体の return 値を取り出してから facts を適用する。StateTy 全体から任意の return の型を反転する一般補題は L40 に残す。

受信の境界は、元の篩付きの結果型を持つ外部宣言・整形式の表・三つの応答仮定を実際に構成する。受信の成功と E_External を計算して接続する。結論の型付けを仮定しない。外部の carrier は、誤った篩を持つ値でも構成できることを対照として示し、受信検査で拒まれることを確かめる。

`hcv` を供給する一般の closeVal の型保存は L20 の捕捉の枠（上表の2〜4時間）に含める。hcv を主定理へ足して量化を制限する案は採らない。最初の ContTy の数え方を11から10へ訂正した。新しい構成子を削ったものではなく、監査のメタデータで実数を照合する。

## StateTy の省略しない署名

```lean
theorem StateTy.dependent_beta_one
    {P B σ Ψ μ name x a e body v k b ε Eb}
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hh : hideBuilders Ψ = Ψ)
    (hb : HasTypeC P B Ψ [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hk : ContTy P B σ Ψ none ε k (substTyValues (openValue v) a) b Eb none)
    (he : Eff.Sub (substEffValues (openValue v) e) ε)
    (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hcbody : body.ClosedAt 0 1) (hck : k.Closed) (hcμ : μ.Closed)
    (hσ : σ.Valid) (hEb : BuiltinOnly P B Eb) :
    StateTy P B σ
      (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) ∧
    Step P B σ
      (.run (Closure.pure (.app (.dependentLam (.param name x (.done a e)) body) [v])) k μ) none
      (.run ((Closure.pure body).apply [v]) (markPush k) μ) ∧
    StateTy P B σ (.run ((Closure.pure body).apply [v]) (markPush k) μ)
```

手書きの公開補題は10本、私有補題は1本である。暗黙引数の推論を含む完全署名は [public-api.lean](initial-public-api.lean) とその [出力](initial-public-api.log) で照合する。生成された matcher 等は公開APIの件数から分け、公理監査では省かない。
