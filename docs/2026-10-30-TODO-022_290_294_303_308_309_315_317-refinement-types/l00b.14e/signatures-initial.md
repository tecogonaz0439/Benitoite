# L00b.14e: 節の引数と resume の完全署名

2026-11-01。B_WORK は `c64c0dc376b85185744303c4752d1f1bb34967af`、指定ブランチは `m014/l00b.14e` である。git 操作は行わない。実装前にこの署名を記録し、レビューを待たずに進める。名前空間は `Benitoite.Release.Refinement` とする。補助の細部の変更は末尾に理由と採否を追記する。

最終の公開は定義1・補題16の17宣言である。暗黙の変数を含む現在の完全署名は [public-api.log](public-api.log)、全名は [public-names.json](public-names.json) にある。以下の初稿の `handler_input_evaluated` は末尾の決定により新設を取りやめた。

## 定義と公開補題の契約

既存の判断・遷移・信頼条件を正とする。新しい公理、状態の Φ、精密な外部状態は追加しない。以下の `HandlerFrameTy` は K_Handle の前提をまとめる補助であり、新しい状態の不変条件ではない。

```lean
def HandlerFrameTy (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty)
    (cap : Capture) (h : List Clause) (t : Ty) (ec eb : Eff) : Prop :=
  ∃ Γ Φ Rs ts ecs ebs,
    CaptureOk P B (hideBuilders Ψ) R Γ Φ cap ∧
    HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs ebs h ts ecs [] ∧
    cap.closeR Rs = R ∧ cap.closeTy ts = t ∧ cap.closeEff ecs = ec ∧ cap.closeEff ebs = eb ∧
    Ty.Annotation P [] [] (.dependentFn (.done t ec)) ∧
    Ty.Annotation P [] Γ ts ∧ (∀ a, Rs = some a → a.Declared P [] Γ)

theorem ContTy.nil_inv {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hk : k = []) :
    Ty.LeQ [] [] a b ∧ Eff.Sub ε Eb ∧ R = Re ∧ Ty.Annotation P [] [] b

theorem ContTy.resume_append {P B σ Ψ R ε saved a t ec Rh}
    (hs : ContTy P B σ Ψ R ε saved a t ec Rh) (hend : EndsWithHandle saved)
    {k u b Eb Re e} (hl : Ty.LeQ [] [] t u)
    (hk : ContTy P B σ Ψ Rh e k u b Eb Re) (he : Eff.Covers [] [] e ec) :
    ContTy P B σ Ψ R ε (saved ++ k) a b Eb Re

theorem ContTy.split_handle {P B σ Ψ R ε k a b Eb Re cap cs k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap cs :: k2) (hn : handles cs .fail = false) :
    ∃ t ec eb et Rh,
      ContTy P B σ Ψ R ε (k1 ++ [.handleF cap cs]) a t ec Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧
      Eff.Sub eb (Eff.union ec (handled P B cs)) ∧
      HandlerFrameTy P B Ψ Rh cap cs t ec eb

theorem StoreOk.use_continuation {P B σ Ψ μ l a t ec R}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont a t ec R)) :
    StoreOk P B σ Ψ (μ.set l .used)

theorem StoreOk.allocate_continuation {P B σ Ψ μ l a t ec R saved}
    (hs : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hf : μ l = none) (hw : LocTy.WF (.cont a t ec R))
    (hd : LocTy.Declared P (.cont a t ec R)) (hend : EndsWithHandle saved)
    (hk : ∃ R0 e0, ContTy P B σ Ψ R0 e0 saved a t ec R) :
    StoreOk P B σ (Ψ.put l (.cont a t ec R)) (μ.set l (.cont saved))
```

主な保存の代表は、開始の StateTyE を逆転し、実際の Step と到達の StateTyE を組で返す。操作は単相・一引数で、入力と再開値に篩を許し、結果は操作の引数を参照してよい。節の本体の空の型置換が固定点である代表を先に閉じる。型置換によるコード正規化の全保存を先取りしない。hcap と継続末尾は任意とする。再開と返却は閉じた定数の view の代表とし、任意の ret の closeVal は .14d と共通の L20 の残件とする。

```lean
theorem StateTyE.handler_return_const {P B σ Eb q c cap cs k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.handleF cap cs :: k) μ))
    (hv : q.view = .ret (.const c)) :
    Step P B σ (.run q (.handleF cap cs :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const c))) k μ)

theorem StateTyE.drop_used_const {P B σ Eb q c l k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret (.const c)) (hl : μ l = some .used) :
    Step P B σ (.run q (.drop l :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const c))) k μ)

theorem StateTyE.resume_const {P B σ Eb q l c k μ saved}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .resume (.loc l) (.const c)) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.const c))) (saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.const c))) (saved ++ k) (μ.set l .used))

theorem StateTyE.resume_used {P B σ Eb q l v k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .resume (.loc l) v) (hl : μ l = some .used) :
    Step P B σ (.run q k μ) none (.error [rResume] k μ) ∧
    StateTyE P B σ Eb (.error [rResume] k μ)
```

操作の代表では、宣言の注釈と正規形を入力にする。これは操作の結果や節の到達の型付けを仮定するものではない。宣言の注釈から CaptureOk.extend/extendCont を構成する。空の型置換の固定点の条件は、コードの型置換の一般補題へ送る分を明示するための代表の条件である。

```lean
theorem StateTyE.operation_one {P B σ Eb o name x y eff v cap cs k1 k2 k μ body l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb
      (.run (Closure.pure (.app (.op o []) [v])) k μ))
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hx : Ty.Annotation P [] [] x)
    (hy : Ty.Annotation P [] (Ctx.extend [] x) y)
    (hxn : x.Normal) (hyn : y.Normal)
    (hsp : SplitAt (.user o) k k1 cap cs k2)
    (hc : findClause cs (.user o) = some (.mk (.user o) 1 0 body))
    (hbn : body.substTy [] [] = body) (hf : μ l = none)
    (hv : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.app (.op o []) [v])) k μ) none
      (.run (.mk (cap.extendMany [v, .loc l]) body) (.drop l :: k2)
        (μ.set l (.cont (k1 ++ [.handleF cap cs])))) ∧
    StateTyE P B σ Eb
      (.run (.mk (cap.extendMany [v, .loc l]) body) (.drop l :: k2)
        (μ.set l (.cont (k1 ++ [.handleF cap cs]))))
```

補助の逆転・注釈の入口も実装前に記す。追加の補助は非公開である。

```lean
theorem HasTypeCQ.operation_call {P B Ψ R o v a e L od}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o []) [v]) a e L)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel [] []) r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f

-- 捕捉の閉じ方の代表。既存の二入口を実際の節の本体に使う。
theorem CaptureOk.handler_input_evaluated {P B Ψ R Γ Φ cap p}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hp : Pred.WellFormed P [] Γ p)
    (he : (predBind (valEnv cap.env).values p).evalClosed = some true) :
    CaptureOk P B Ψ R Γ (p :: Φ) cap ∧
      Entails [] (predBind (valEnv cap.env).values p)
```

公開する補助の追加・削除は決定の記録と最終の公開署名の出力に残す。

## 場合の数と後段

| 族 | 予定 |
|---|---|
| 今回の Step の代表 | 必須4種 E_Op/E_Resume/E_HRet/E_Drop。追加候補4種 E_OpFail/E_OpPrim/E_ResumeErr/E_DropRel |
| 継続の切り出し・接続 | ContTy の全10構成子。GuardBodyTy と K_Update の証拠をそのまま保持 |
| ストアの移送 | CellOk の既存6形を再利用 |
| 逆転 | 値29・計算24構成子。C_Sub/C_Normal/C_Eff と V_Sub/V_Normal/V_Refine を落とさない |

L20 は、多相節、複数引数、コードの型置換、任意の再開値・ret の closeVal、used/drop の error/exit/escape/release を含む全体、全状態の合成を受け持つ。Lazy/Reference と共通の閉包・ストア・継続の枠の内数として一度だけ数える。L30 は Rust のハンドラ・再開・使い切りの実装との照合、L40 は全 canonical forms と進行への接続を受け持つ。

## 境界の作成時の関門

守る契約は、篩付きの入力から節の事実を読み、依存する篩付きの結果を再開し、切り出した継続がその事実を読めること、捕捉の不変な事実と効果の保存、一度だけの使用である。入力又は結果の契約を落とす、ストアの更新で捕捉を失う、used を再開できる退行を検出する。既存の .14a〜.14d の境界は節から resume への同じ遷移列を持たない。既存の StateTyE/Step の入口を使い、専用の本番の差込み口は設けない。

## 補助の契約の決定の記録

| 採る案 | 理由 | 捨てた案 |
|---|---|---|
| K_Handle の証拠を HandlerFrameTy にまとめる | 切り出し後も同じ Γ/Φ/ソースの契約を使用できる | 閉じた型だけを保持して hcap の CaptureOk を捨てる |
| EndsWithHandle を使って接続する | 空末尾の効果を caller の行へ被覆で接続できる | saved の末尾を任意の枠へ広げ、行の関係を仮定する |
| 定数の view を保存の代表にする | 既存の ret_const と D19 の評価から事実を閉じられる | 未完成の任意の closeVal の保存を仮定する |


## 呼出し元の閉じ方の補助署名（実装前）

```lean
theorem ClosureTy.pure_operation {P B Ψ R a e o v od}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o []) [v])) a e)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel [] []) r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f
```

pure_operation は空の捕捉に存在しうる Φ を閉じた導出で除去する。operation_call は fn/dependentFn と TelClosure の引数の反変を逆転する。空の ts を持つ代表のため、型引数の正規化・適格性を新しい信頼条件へしない。


```lean
theorem ContTy.return_annotation {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hRe : Re = none) :
    ∀ r, R = some r → Ty.Annotation P [] [] r
```

操作を捕捉する時点の R の注釈は、末尾の ContTy から得る。この補助を公開し、K_Let/K_Mark/K_Update/K_Guard と二種の handler を区別する。StoreTy へ Sorted を足す案は採らない。


```lean
theorem ClosureTy.widen_atoms {P B Ψ R q a ec et}
    (hq : ClosureTy P B Ψ [] R q a ec) (he : Eff.Covers [] [] et ec) :
    ClosureTy P B Ψ [] R q a (.mk et.atoms ec.fails) ∧
      Eff.Sub (.mk et.atoms ec.fails) et
```

再開と切り出しが返す関係は Covers であり、StateTyE の局所の行の接続は Sub である。節のソースの行の Fail を保ち、原子だけを末尾の行へ広げて接続する。Covers を Sub とみなす案や StateTyE の変更は採らない。これは既存の widen_atoms と同じ契約である。


```lean
theorem ContTy.guard_effect {P B σ Ψ R e frames a b Eb Re v cap arms next body k}
    (h : ContTy P B σ Ψ R e frames a b Eb Re)
    (he : frames = .guardF v cap arms next body :: k) : R = none ∧ e = Eff.empty

theorem StateTyE.operation_under_guard_false
    {P B σ Eb o name x y eff arg v cap arms next body k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o []) [arg]))
      (.guardF v cap arms next body :: k) μ))
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hxn : x.Normal) (hyn : y.Normal) : False
```

GuardBodyTy が pending のときの行は空である。操作の宣言の効果原子は空行に被覆されず、guard の評価中の操作呼出しは型付かない。切り出しで guard の証拠を保持することとは別の命題として確かめる。


## 補助の実装で確定した採否

| 採る案 | 理由 | 捨てた案 |
|---|---|---|
| `handler_input_evaluated` の新設を取りやめ、既存の `addEvaluated`・`addEntailed`・`close_entails` を使う | 初稿の補助は既存の二つの結論を組にするだけで、専用の本番の入口は不要であった | 境界だけが呼ぶ重複の公開補題を残す |
| 操作の代表に宣言の Annotation と Normal、空のコード型置換の固定点を明示する | 型置換の全保存と、生の注釈から正規形の注釈への逆方向を仮定せず、代表の範囲を示せる | 到達の ClosureTy を仮定する、型付け規則を正規形の宣言だけへ限定する |
| 切り出した継続の結果行を ec とし、節の実行の原子だけ et へ広げる | K_Handle の宣言の潜在効果を保存し、StateTyE の Sub を構成できる | ec と et の等号や Sub を別仮定にする |
| resume は任意の捕捉の定数の view から閉じた CQ を構成する | ソースの継続変数を CaptureOk.substOk で場所へ置換し、依存する結果と R の正規形を照合できる | 呼出し元を pure に限定する、閉じた型付けを補助入力にする |
| 再開時の値は格納型の正規形で受け取る | 生の格納型の Sorted を新しいストア不変条件にしない | CellOk.cont や ContTy の定義を強める |

`CoreAssumptions`・`ContTy`・`StateTyE` は変更していない。表の不足を示す反例も得ていない。今回の代表には既存の CoreAssumptions の射影で足りる。新しい公理・提供範囲・利用者の書ける形・精密な外部状態は変更しない。
