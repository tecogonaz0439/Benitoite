# L00b.14b: 捕捉した Φ の完全署名

2026-11-01。指定ブランチは `m014/l00b.14b`、B_WORK は `b32ef9c93b89e43131a1c96831a4eadfb6fa9512` である。RV-L00b.14b の対応前に以下へ改め、同じ起動で実装する。初回の署名は [initial-signatures.md](initial-signatures.md) に残す。名前空間は `Benitoite.Release.Refinement`、暗黙引数の型は既存の判断に従う。本番の新規ファイルは `formal/Benitoite/Release/Refinement/CapturedFacts.lean` とし、集約の `formal/Benitoite.lean` に import する。既存判断・遷移・主定理・信頼条件の欄は変えない。新しい定義や公理は置かず、既存判断の補題を追加する。

## 評価成功からの事実と捕捉の再構成

```lean
theorem CaptureOk.evaluated_fact {p : Pred}
    (he : p.evalClosed = some true) : Entails [] p

theorem CaptureOk.addEntailed {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ p)
    (hf : Entails [] (predBind (valEnv cap.env).values p)) :
    CaptureOk P B Ψ R Γ (p :: Φ) cap

theorem CaptureOk.addEvaluated {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Pred.WellFormed P [] Γ p)
    (he : (predBind (valEnv cap.env).values p).evalClosed = some true) :
    CaptureOk P B Ψ R Γ (p :: Φ) cap

theorem CaptureOk.close_entails {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Entails (Γ.facts ++ Φ) p) :
    Entails [] (predBind (valEnv cap.env).values p)

theorem HasTypeTelArgsQ.captured_one {P B Ψ Γ Φ cap n x a e v}
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param n x (.done a e))))
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy x)) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (cap.closeTel (.param n x (.done a e)))
      ((cap.extend v).closeTy a) ((cap.extend v).closeEff e)
```

`evaluated_fact` は評価成功だけから D19 の閉じた導出を得る。evalClosed 自身が WF と Sorted を検査するため、hc・hp は受け取らない。`addEntailed` は仮定なしの導出を使って新しい一条件を既存の Φ に足し、古い facts は元の導出を再利用する。`addEvaluated` はその系であり、hp は元の Φ の整形式の欄を満たすために使う。`close_entails` は有限構文の bind と cut で条件を閉じる。引数を延長する入口には既存の `CaptureOk.extend` と `CaptureOk.facts_extend` をそのまま使い、同じ署名の包みは増やさない。

## `.closure` 呼出しの状態代表

次は保存定理ではなく同時構成である。開始の `StateTyE` を逆転せず、同じ捕捉・本体・引数・継続の証拠から両状態を作る。捕捉 Γ/Φ は任意であり、実行時の `.closure` の値を `E_Lam` へ渡す。結果・効果・return は同じ `cap.extend v` で閉じ、Ψ・μ・σ・ε・b・Eb は両側で同じ証人である。

```lean
theorem StateTyE.captured_beta_one
    {P B σ Ψ μ R Γ Φ cap name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ
      (.param name x (.done a e)) body)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param name x (.done a e))))
    (hv : HasTypeV P B Ψ [] [] [] v (cap.closeTy x)) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k ((cap.extend v).closeTy a) b Eb none)
    (he : Eff.Sub ((cap.extend v).closeEff e) ε)
    (hcap : cap.Adequate σ) (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hccap : cap.Closed) (hcbody : body.ClosedAt 0 (cap.values.length + 1))
    (hck : k.Closed) (hcμ : μ.Closed) :
    StateTyE P B σ Eb
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) ∧
    Step P B σ
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) none
      (.run (.mk (cap.extend v) body) (markPush k) μ) ∧
    StateTyE P B σ Eb (.run (.mk (cap.extend v) body) (markPush k) μ)

theorem StateTy.captured_beta_one
    {P B σ Ψ μ R Γ Φ cap name x a e body v k b ε Eb}
    (hA : Builtins.ValueAssumptions P B)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ
      (.param name x (.done a e)) body)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param name x (.done a e))))
    (hv : HasTypeV P B Ψ [] [] [] v (cap.closeTy x)) (hg : v.Ground)
    (hcv : closeVal Capture.empty v = v)
    (hs : StoreOk P B σ Ψ μ)
    (hR : ∀ r, R = some r → r.WF 0 0 0 ∧ r.Declared P [] [] ∧ r.Normal)
    (hk : ContTy P B σ Ψ R ε k ((cap.extend v).closeTy a) b Eb none)
    (he : Eff.Sub ((cap.extend v).closeEff e) ε)
    (hcap : cap.Adequate σ) (hbody : body.Adequate σ) (hval : v.Adequate σ)
    (hccap : cap.Closed) (hcbody : body.ClosedAt 0 (cap.values.length + 1))
    (hck : k.Closed) (hcμ : μ.Closed)
    (hσ : σ.Valid) (hEb : BuiltinOnly P B Eb) :
    StateTy P B σ
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) ∧
    Step P B σ
      (.run (Closure.pure (.app
        (.closure (cap.closeTel (.param name x (.done a e))) (.mk cap body)) [v])) k μ) none
      (.run (.mk (cap.extend v) body) (markPush k) μ) ∧
    StateTy P B σ (.run (.mk (cap.extend v) body) (markPush k) μ)
```

列の閉じた Annotation と Normal は捕捉の `substOk.telAnnotation` と `Tel.norm_idem` から得る。ソースの注釈がすでに正規形であることを新たに要求しない。`hcv` は呼出し元の空の捕捉で実引数を読む際にのみ使う。任意の実引数で外せることは主張しない。

## 場合の数と境界の作成時の関門

初回は公開補題6本を予定した。今回の対応後は公開補題7本、判断・遷移の構成子の増減0である。`CaptureOk.mk` の8欄のうち事実の欄を Γ.facts・新条件・既存 Φ の3場合に分ける。評価器の各構成子の証明は既存の `Entails.ground` の健全性を使い、重ねて数えない。呼出しの代表は E_Lam の1場合、境界の分岐は E_IfT と E_IfF の2場合を通す。ContTy10・計算24・相互三族76・Step76は変更しない。

境界 `boundary.lean` は、捕捉した整数の条件を閉じた評価で登録し、`Integer{0 ≤ self}` の実引数を延長する。追加後の Γ.facts の非空性、延長前後の Φ の位置、実際の `.closure` 呼出しと分岐後の `StateTy`、本体の篩導入と閉じた結果の型付けを同じ入力で検査する。誤った閉じた事実・型付けの否定と、環境を捨てる案の反例も置く。

この境界が守る独立の契約は、型付き像だけでは得られない Φ を評価成功から再構成し、Γ の名前を実行時の型から除いた後にも本体の型付けで使うことである。空の Φ と篩のない引数の前段の境界では、facts の欄を落とす退行や捕捉環境の破棄を捕まえられない。本番の判断と実際の Step/StateTy を使い、テスト専用の本番の差し込み口は作らない。負例では型の整形式や型付き像の欠落とは別に、事実の誤りを理由として否定する。

## 補助契約の決定の記録

| 論点 | 採る案・理由 | 捨てた案 |
|---|---|---|
| 評価による Φ の登録 | 既存 CaptureOk と一条件の WellFormed、閉じた導出から addEntailed で cons する。評価に成功する条件は同じ入口で作れる。導出だけがある条件は addEntailed を使う | Φ の充足を型付き像から仮定する案、評価失敗を成功として扱う案 |
| 状態代表の形 | 既存 closure_one・hideConts_any・extend・facts_extend と markPush を使う同時構成。閉じた契約は計算で一致させる | 開始の StateTy の一般逆転を未証明で使う案、状態へ別の Φ を足す案 |
| 分岐との接続 | 境界で捕捉環境を同じに保つ E_IfT/F の前後を構成する。現行 C_If は枝へ新たな Φ を追加しない | 実際には存在しない述語評価の Step や分岐規則を追加する案 |
| 反例の配置 | 本番の CaptureOk・Entails・閉じ方の上で境界に保持し、公理依存も調べる | 独立の小模型だけで偽とする案 |

これらは補助の証明の入口の選択であり、主定理の一般の導出を除かない。主な定理の前提と結論・新しい公理・提供範囲・利用者の書ける形・精密な外部状態を変更しない。状態の代表の限定と、後の一般化の義務は分ける。

## 捕捉 Φ に残る言明と配分

規則の追加と K_Guard の変更は L00b.14b-paths で、L20 の相互補題へ進む前に扱う。paths の二行の見込みは、計画の同作業の3〜8時間の枠を共有し、個別の配分は未見積もりである。それ以外は既存の L20/L40 の枠の内数である。全状態の保存は既存の枠のまま、この表の外である。以下の和を O008 全体の残りとしない。

| 残る言明 | 依存 | 能動時間の見込み | 送り先 |
|---|---|---:|---|
| 開始の StateTyE と V_Closure/V_Sub/TelClosure から同じ契約の捕捉と本体を取り出す | closure の逆転、部分型と列の変性 | 3〜6時間 | L40 |
| 多引数・零引数と多相の閉包に、捕捉 Φ の閉じ方を合成する | extendTel、型/行/範囲/値の交換、宣言の WellTyped | 3〜6時間 | L20 |
| 任意の closeVal 実引数について型付けと具体化契約を一致させ、hcv を外す | closeVal の型保存、観測の一致と bind の合同 | 1〜3時間 | L20 |
| 局所参照を持つ本体の捕捉 Φ と CaptureLocals を β・分岐へ接続する | capture_resolved、局所解決とストア拡張 | 2〜4時間 | L20 |
| if・短絡・match の型付けで Φ を増やす規則を追加し、移動・置換・狭めの全場合を閉じる | O056/O138、既存三族と source/annotation の整合 | 不明（paths の詳細化で見積もる） | L00b.14b-paths |
| K_Guard が条件の前の本体の導出を保持し、E_GuardT で条件を足して ClosureTy を作る形へ改める。E_GuardF 後の腕が ¬guard を読むかも決める | guard の規則、x=9 の再現、ContTy の既存の読み手 | 不明（paths の詳細化で見積もる） | L00b.14b-paths |
| 規則追加後の if・短絡・match の経路条件を、実際の観測と遷移へ接続する | 各観測の canonical forms、閉じた評価または値の型の facts、O054 の合同 | 3〜6時間 | L40 |
| guard の評価結果の型の事実から本体の条件を導き、E_GuardT/F の状態へ接続する | paths の K_Guard と規則の変更、addEntailed、guard の純粋性 | 不明（paths の代表の後に見積もる） | L20/L40 |
| 呼出し元の捕捉を持つ q.view と、.lam を閉じて .closure を作る側の型保存を接続する | closeVal の型保存、Γ/Φ/CaptureOk の V_Closure への接続 | 2〜4時間 | L20 |
| ContTy の各捕捉枠（let/handle/fail）を取り出す遷移で同じ Φ を再構成する | 各枠の逆転、節/return/resume、捕捉した契約の一致 | 3〜6時間 | L20 |

Reference・Lazy・節/resume の代表はそれぞれ L00b.14c〜.14e の担当とし、この作業で先取りしない。O008 は今回の代表と環境破棄の反例を、O051 は捕捉 Φ の代表だけを閉じる。全 StoreTy/ContTy の保存と O160 の取りまとめでの再提示は残る。

## L00b.14b-paths への申し送り

現行の型付けの全規則は Φ を保つか束縛に合わせて移動するだけで、空から非空の Φ を作らない。今回の境界の Φ は実プログラムから生じず、実行が条件を真にする接続は未検査である。次の作業で規則を追加する。今回、規則や K_Guard は変更しない。

[rv-14b-t1.lean](rv-14b-t1.lean) の ClosureTy.branch と boolCond_of_view は、真偽の変数を読む E_IfT/F の前提から、条件を加えた枝の閉包を型付ける補助の入力である。boolCond_evaluates も参照する。本番の addEntailed を、値の型の facts などから得る閉じた導出の入口に使う。addEvaluated は評価に成功する場合だけの系である。これらの補題だけでは、枝の導出を作る型付け規則の追加や、組み込み比較の結果から元の条件を導く O054 の接続は完成しない。

中2の再現は、`| x if x < 8 => x : Integer{self < 8}` を x=9 で実行し、E_GuardF へ進む途中の枠が型付くかを、規則を追加した後に確かめることである。現在の K_Guard は結果が分かる前に本体の ClosureTy を要求するため、真の条件を仮定した本体へそのまま使えない。条件の前の本体の導出を保持し、E_GuardT で閉じる案と、偽の側の後続の腕の扱いを次の作業で具体化する。今回この再現を実行済みとはしない。

軽3の追加の境界は、[rv-14b-t2.lean](rv-14b-t2.lean) の return_capture・returned_capture_typed・returned_capture_fact・closed_gamma_fact を本番の境界へ移す。Φ だけから値7に Integer{self<8} を与える導出と、Γ.facts の側の仮定を close_entails へ渡す入口を確かめる。型付けなしにも導ける閉じた数値の比較だけを、Φ と返り値の接続の主な証拠にしない。

L00b.14c へは軽4も申し送る。get で束縛した snapshot の Φ が後の set の後も CaptureOk.store で保たれることと、Reference を欄に持つ data ではその欄が欠落の観測となることを境界で確かめる。今回その作業へは進まない。
