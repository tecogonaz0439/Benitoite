# L00b.14a: レビュー対応後の完全署名

2026-11-01。B_WORK は `0fbd34415aa659922378aa9769bac6e513bd061e`、ブランチ指定は `m014/l00b.14a`。RV-L00b.14a の取りまとめの追記と plan の先頭の判断に従い、以下へ改める。初回の署名は [initial-signatures.md](initial-signatures.md) に残す。主な定理・信頼条件の欄・新しい公理・提供範囲・利用者の書ける形・精密な外部状態は変えない。

## 実装前に固定する署名の変更

StateTyE.dependent_beta_one と StateTy.dependent_beta_one は、暗黙引数 R を追加し、呼出し元の ContTy と開始の ClosureTy の R を一般にする。hideBuilders Ψ=Ψ を外し、本体の型付けを hideBuilders Ψ で受け取る。既存の Builtins.ValueAssumptions P B を hA として受け取る。R=some の型には、開始の ClosureTy.pure が読む次の証拠を受け取る。

```lean
(hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
```

定理は開始の StateTyE からの逆転を含まない同時構成である。開始と到達の Ψ・μ・具体化した結果型・b・ε・Eb・σ は同じである。開始は R、関数の本体の return 契約は some av であり、markPush の併合に対応する ContTy を構成する。

追加する公開補題の署名は次のとおりである。共通名前空間は Benitoite.Release.Refinement、暗黙引数の型は既存判断から推論する。

```lean
theorem ContTy.mark_inv {P B σ Ψ R ε k0 a b Eb Re}
  (h : ContTy P B σ Ψ R ε k0 a b Eb Re) :
  ∀ k, k0 = .mark :: k → ∃ r R', R = some r ∧ Ty.LeQ [] [] a r ∧
    ContTy P B σ Ψ R' ε k r b Eb Re

theorem markPush.eq_cons_or_merge (k : Cont) :
  markPush k = .mark :: k ∨ ∃ tail, k = .mark :: tail ∧ markPush k = k

theorem ContTy.markPush {P B σ Ψ R ε k a b Eb Re}
  (h : ContTy P B σ Ψ R ε k a b Eb Re) (ha : Ty.Annotation P [] [] a) :
  ContTy P B σ Ψ (some a) ε (markPush k) a b Eb Re

theorem Cont.Closed.markPush {k : Cont} (h : k.Closed) : (markPush k).Closed

theorem HasTypeCQ.store_extend {P B store Q C Γ Φ R m a e L}
  (hb : HasTypeCQ P B store Q C Γ Φ R m a e L) {store'}
  (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.Extends store') :
  HasTypeCQ P B store' Q C Γ Φ R m a e L

theorem StoreTy.hide_extends (Ψ : StoreTy) : (hideBuilders Ψ).Extends Ψ

theorem CaptureOk.hideConts_any {P B Ψ R R' Γ Φ cap}
  (h : CaptureOk P B Ψ R Γ Φ cap) : CaptureOk P B Ψ R' (hideConts Γ) Φ cap

theorem ClosureTy.closure_one {P B Ψ Γ Φ cap n x a e code v}
  (hA : Builtins.ValueAssumptions P B) (hW : Ψ.WF)
  (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
  (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ
    (.param n x (.done a e)) code)
  (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param n x (.done a e))))
  (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy x)) (hg : v.Ground) :
  ClosureTy P B Ψ [] (some ((cap.extend v).closeTy a)) (.mk (cap.extend v) code)
    ((cap.extend v).closeTy a) ((cap.extend v).closeEff e)
```

同じ markPush の形の判定を二度証明する代わりに eq_cons_or_merge を使い、ContTy と Closed の双方を閉じる。旧の私有 not_mark は不要なので残さない。任意の R の補題は、補助入力の不要な ∃ _ : True を外して直接 ContTy を返す。

CaptureOk.hideConts_any は捕捉の Γ を本体の hideConts Γ へ移し、隠した継続を読む ImageOk を残さないので R を自由に移せる。補助の hideMap は私有とする。store_extend は既存の shift_values の移動数0から導き、新しい信頼条件を作らない。closure_one はこの移送から捕捉を延長し、本体を Ψ へ戻して ClosureTy.capture を使う。

## 現在の代表の限定と外した限定

StateTyE/StateTy の代表は、呼ばれる側がソースの `.dependentLam` の直書きであり、呼出しのコードは外側の捕捉を持たない Closure.pure である。一引数・型/行/範囲の実引数なし・WF かつ Normal な依存列を扱う。本体の局所参照は空で、Γ はその一引数だけ、Φ は空である。実引数は Ground かつ hcv を満たす。関数本体・実引数・継続・ストアの閉性と固定 σ への適格性も、既存 StateTyE の要件として受け取る。

R=none と hideBuilders Ψ=Ψ の限定は外した。R=some の既存の mark は mark_inv を通して併合する。任意のストアを扱い、本体を hideBuilders Ψ で受け取ってから既存の ValueAssumptions で Ψ へ移す。hR の WF/Declared/Normal は開始の ClosureTy.pure が使う証拠であり、新しい主定理の前提ではない。

closure_one は別の入口として、評価済みの閉包の任意の捕捉 Γ/Φ と一引数を扱う。DependentClosureTy の中身である CaptureOk と TelBodyTy を入力に取り、本体の hideConts Γ と捕捉の Γ を hideConts_any で合わせる。この補題は開始の StateTyE や V_Closure の導出を逆転しない。したがって `.closure` の値を呼ぶ場合の状態全体への接続は残件である。

## 全βへ残す言明・依存・配分

以下の見積もりは β の遷移に限り、後続の既存枠の内数である。全状態の保存は L20/L40 の既存の枠のままで、この表の外である。表の和を O008 全体の残りの見積もりとしない。

| 残る言明 | 依存 | 能動時間の見込み | 送り先 |
|---|---|---:|---|
| 多引数・零引数の一般の Closure.apply と Tel.instantiate の型付け | extendTel、Capture.instantiate、本体と局所参照 | 2〜4時間 | L20 |
| 多相の型・行・範囲引数を持つ E_Fun/E_Meth の契約と本体の一致 | 四名前空間の交換、宣言の WellTyped | 3〜6時間 | L20 |
| `.closure` の値を呼ぶ場合の状態への接続と捕捉した Γ/Φ の契約の一致 | 今回の closure_one・hideConts_any、L00b.14b の捕捉Φの代表 | 1〜3時間 | L20 |
| 開始の StateTyE の導出から C_App/C_DependentApp・V_Closure/V_Sub/V_Normal/V_Refine を逆転し、同じ開始契約へ戻す | inv_closure、TelClosure の変性と被覆 | 3〜6時間 | L40 |
| fn/dependentFn と生の注釈の正規化を通るβ | fnCore、正規化、NamesWF、RuntimeShape | 1〜3時間 | L40 |
| hcv を外すための closeVal の型保存と、開始の a[v]/e[v] と到達の a[closeVal v]/e[closeVal v] の一致 | closeVal_observation、rv-14a-t3 の観測が同じ場合の契約の一致 | 1〜3時間 | L20 |
| β の遷移で局所参照を持つ本体・捕捉を復元し、同じ StoreOk/ContTy を使う | store_extend、CaptureLocals、局所解決 | 2〜4時間 | L20 |
| δ/IO/外部受信の葉を、β の遷移の同じ契約と固定 Eb に合成する | canonical forms、応答の型付け、受信検査 | 2〜4時間 | L40 |

R=some と mark の併合、および builder を隠したストアから Ψ への移送は今回閉じたので、残件に数えない。

## 証拠の読み方と L00b.14b への申し送り

境界の実質の証拠は concrete_result・returned_typed・wrong_result_untyped・wrong_received の組である。具体化した型と実際の値の型付け、誤った型付けの否定、受信の拒否を合わせて確認する。returned_fact の 7=7 は eq_refl だけでも導けるため、それ単独を型付けと実行の接続の根拠にしない。

concrete_beta_with_fact の StateTy と値の型付けは同じ本体の導出から別々に作る。received_step は StateTy を構成せず、received_facts とは receive_success を共有する。同じ受信の成功と元の型付けを使うことを示したもので、StateTy からの逆転ではない。

L00b.14b は closure_one と hideConts_any を入口にし、DependentClosureTy が捕捉を Γ/R=none、本体を hideConts Γ で読む差を合わせる。篩のある引数型、たとえば `Integer{0 ≤ self}` を渡し、CaptureOk.extend の facts の欄が空でない境界を置く。今回の引数型は Integer で、その経路の非空の確認は含めない。任意の Φ が型付き像だけで保存されるとは仮定しない。

## 現在の公開補題の全署名

以下は本番の全手書き公開補題の署名である。型の推論を展開した出力は [public-api.log](public-api.log) に置く。私有・生成宣言も公理監査では省かない。

```lean
theorem HasTypeCQ.open_one {P B Ψ Q C Γ Φ R body a e x v}
    (hb : HasTypeCQ P B Ψ Q C (Γ.extend x) (Φ.map Pred.lift) R body a e [])
    (hA : Builtins.SubstitutionAssumptions P B) (hΨ : Ψ.WF)
    (hx : Ty.Annotation P C Γ x) (hΓ : Ctx.WF 0 C.length Γ)
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v x) :
    HasTypeCQ P B Ψ Q C Γ Φ (R.map (substTyValues (openValue v)))
      (body.subst (openValue v) LocalRef.bound)
      (substTyValues (openValue v) a) (substEffValues (openValue v) e) []
```

```lean
theorem Capture.empty_closeTel {t : Tel} (hw : t.WF 0 0 0) (hn : t.Normal) :
    Capture.empty.closeTel t = t
```

```lean
theorem Capture.instantiate_one {name : String} {x a : Ty} {e : Eff} (v : Val)
    (hw : (Tel.param name x (.done a e)).WF 0 0 0)
    (hn : (Tel.param name x (.done a e)).Normal) :
    (Capture.empty.extend v).closeTy a = substTyValues (openValue v) a ∧
    (Capture.empty.extend v).closeEff e = substEffValues (openValue v) e
```

```lean
theorem HasTypeTelArgsQ.one {P B Ψ Q C Γ Φ name x a e v}
    (ht : Ty.Annotation P C Γ (.dependentFn (.param name x (.done a e))))
    (hΓ : Ctx.WF 0 C.length Γ) (hv : HasTypeVQ P B Ψ Q C Γ Φ v x) :
    HasTypeTelArgsQ P B Ψ Q C Γ Φ [v] (.param name x (.done a e))
      (substTyValues (openValue v) a) (substEffValues (openValue v) e)
```

```lean
theorem ClosureTy.dependent_one {P B Ψ name x a e body v}
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B Ψ [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground) :
    ClosureTy P B Ψ [] (some (substTyValues (openValue v) a))
      ((Closure.pure body).apply [v])
      (substTyValues (openValue v) a) (substEffValues (openValue v) e)
```

```lean
theorem ContTy.mark_inv {P B σ Ψ R ε k0 a b Eb Re}
    (h : ContTy P B σ Ψ R ε k0 a b Eb Re) :
    ∀ k, k0 = .mark :: k → ∃ r R', R = some r ∧ Ty.LeQ [] [] a r ∧ ContTy P B σ Ψ R' ε k r b Eb Re
```

```lean
theorem markPush.eq_cons_or_merge (k : Cont) :
    markPush k = .mark :: k ∨ ∃ tail, k = .mark :: tail ∧ markPush k = k
```

```lean
theorem ContTy.markPush {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (ha : Ty.Annotation P [] [] a) :
    ContTy P B σ Ψ (some a) ε (markPush k) a b Eb Re
```

```lean
theorem Cont.Closed.markPush {k : Cont} (h : k.Closed) : (markPush k).Closed
```

```lean
theorem CaptureOk.hideConts_any {P B Ψ R R' Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R' (Refinement.hideConts Γ) Φ cap
```

```lean
theorem HasTypeCQ.store_extend {P B store Q C Γ Φ R m a e L} (hb : HasTypeCQ P B store Q C Γ Φ R m a e L) {store'}
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.Extends store') :
    HasTypeCQ P B store' Q C Γ Φ R m a e L
```

```lean
theorem StoreTy.hide_extends (Ψ : StoreTy) : (hideBuilders Ψ).Extends Ψ
```

```lean
theorem ClosureTy.closure_one {P B Ψ Γ Φ cap n x a e code v}
    (hA : Builtins.ValueAssumptions P B) (hW : Ψ.WF)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ (.param n x (.done a e)) code)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param n x (.done a e))))
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy x)) (hg : v.Ground) :
    ClosureTy P B Ψ [] (some ((cap.extend v).closeTy a)) (.mk (cap.extend v) code)
      ((cap.extend v).closeTy a) ((cap.extend v).closeEff e)
```

```lean
theorem StateTyE.dependent_beta_one
    {P B σ Ψ μ R name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B (hideBuilders Ψ) [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k (substTyValues (openValue v) a) b Eb none)
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

```lean
theorem StateTy.dependent_beta_one
    {P B σ Ψ μ R name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (ht : Ty.Annotation P [] [] (.dependentFn (.param name x (.done a e))))
    (hn : (Tel.param name x (.done a e)).Normal)
    (hb : HasTypeC P B (hideBuilders Ψ) [] (Ctx.extend [] x) [] (some a) body a e)
    (hv : HasTypeV P B Ψ [] [] [] v x) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k (substTyValues (openValue v) a) b Eb none)
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

```lean
theorem HasTypeCQ.ret_value {P B Ψ Q C Γ Φ R m a e L v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hm : m = .ret v) :
    HasTypeVQ P B Ψ Q C Γ Φ v a
```

```lean
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
