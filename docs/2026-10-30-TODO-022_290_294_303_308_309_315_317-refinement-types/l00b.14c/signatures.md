# L00b.14c: Reference と StoreOk の完全署名

2026-11-01。指定ブランチは `m014/l00b.14c`、B_WORK は `b5a00e9aed5eb80022b01e135aaffd6f7783ff01` である。git の操作は行わない。本書を実装前に記録し、独立レビューを待たずに実装する。名前空間は `Benitoite.Release.Refinement` である。既存の型付け判断・遷移の構成子・主定理の結論は変えない。信頼条件の変更は、再開時に承認された CoreAssumptions と StoreShape の強化だけである。

## 定義とストアの移送

新しい判断は追加しない。場所の追加は、既存の `Store.set` と同じ更新をストア型にも使う補助 `StoreTy.put` で表す。

```lean
def StoreTy.put (Ψ : StoreTy) (l : Nat) (x : LocTy) : StoreTy :=
  fun i => if i = l then some x else Ψ i

theorem StoreTy.extends_put {Ψ l x} (h : Ψ l = none) : Ψ.Extends (Ψ.put l x)

theorem HasTypeVQ.store_extend {P B Ψ Q C Γ Φ v a Ψ'}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    HasTypeVQ P B Ψ' Q C Γ Φ v a

theorem GuardBodyTy.store {P B Ψ R q input a e Ψ'}
    (h : GuardBodyTy P B Ψ R q input a e)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    GuardBodyTy P B Ψ' R q input a e

theorem ContTy.store {P B σ Ψ R ε k a b Eb Re Ψ'}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    ContTy P B σ Ψ' R ε k a b Eb Re

theorem CellOk.store {P B σ Ψ l c Ψ'}
    (h : CellOk P B σ Ψ l c)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    CellOk P B σ Ψ' l c

theorem StoreOk.write_reference {P B σ Ψ μ l a b v}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.ref b))
    (he : b.norm = a.norm) (hn : a.Normal)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ Ψ (μ.set l (.val v))

theorem StoreOk.allocate_reference {P B σ Ψ μ l a v}
    (h : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hl : μ l = none) (ht : Ty.Annotation P [] [] a) (hn : a.Normal)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ (Ψ.put l (.ref a)) (μ.set l (.val v))
```

`CaptureOk.store`、`ClosureTy.store` は既存の入口を使う。`StoreOk` の単純な拡張だけを主張しない。ストア型の領域を広げる場合は、実ストアにも対応するセルを置き、有限性・WF・Declared・領域一致・既存セルの移送を示す。

## 開始の型付けからの逆転と保存

代表は空の捕捉の実行時の呼出しである。継続・ストア・最終の型と Eb は任意とする。値の型引数は篩を含んでよく、Reference の内容型の照合は正規化後等号を使う。参照4種の StoreShape は型パラメータの kind を `.value` と定める。CoreAssumptions の ref_get/ref_set と store_shape/store_admits から、update が使う型付き get/set を導く。ReferencePrimitives の別仮定は取らない。

```lean
theorem HasTypeTelArgsQ.pullback {P B Ψ ws t u a e}
    (ht : Ty.Annotation P [] [] (.dependentFn t))
    (hr : TelClosure [] [] t u)
    (ha : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e) :
    ∃ b f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t b f ∧
      Ty.LeQ [] [] b a ∧ Eff.Covers [] [] e f

theorem HasTypeCQ.primitive_call {P B Ψ R code a e L b ts es rs ws s}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hg : ∀ v ∈ ws, v.Ground)
    (hc : code = .app (.prim b ts es rs) ws) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f

theorem StateTyE.reference_new {P B σ Eb b ts es rs v k μ s l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [v])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refNew) (hl : μ l = none) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))

theorem StateTyE.reference_get {P B σ Eb b ts es rs l k μ s v}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refGet) (hl : μ l = some (.val v)) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)

theorem StateTyE.reference_set {P B σ Eb b ts es rs l v k μ s}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,v])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refSet) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))

theorem StateTyE.reference_update {P B σ Eb b ts es rs l runtime body k μ s}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb
      (.run (Closure.pure (.app (.prim b ts es rs) [.loc l,.closure runtime body])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .refUpdate) :
    StateTyE P B σ Eb
      (.run (Closure.pure (.letIn (.app (.prim B.refGet (Ty.normTys ts) [] []) [.loc l])
        (.letIn (.app ((Val.closure runtime body).rename (· + 1)) [.var 0])
          (.app (.prim B.refSet (Ty.normTys ts) [] []) [.loc l,.var 0])))) k μ)

```

`primitive_call` の ground は開始状態の閉性から得る。型付き計算だけから ground が従うとはしない。`pullback` は論理の移送で閉じるため、組み込みの仮定とストアの WF を受け取らない。`ClosureTy.pure_primitive` が空の捕捉の閉包を逆転し、既存の ValueAssumptions と StoreTy.WF を用いて Φ を除去する。補助の逆転は V_Normal/V_Sub/V_Refine と C_Normal/C_Sub/C_Eff、fn と dependentFn の両入口、TelClosure の推移を扱う。最終の全31公開宣言の完全署名は [public-api.log](public-api.log) にある。

## 観測・snapshot と経路条件

```lean
theorem reference_no_sort (a : Ty) : (Ty.reference a).sort? = none
theorem reference_no_observation (l : Nat) : (Val.loc l).toTerm? = none
theorem reference_no_observed_fact (l : Nat) (tests : List PathTest) :
    pathFacts (Val.loc l).toTerm? tests = []

theorem CaptureOk.reference_write_snapshot {P B σ Ψ μ R Γ Φ cap l a b v p}
    (hA : Builtins.ValueAssumptions P B) (hs : StoreOk P B σ Ψ μ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : Entails (Γ.facts ++ Φ) p)
    (hl : Ψ l = some (.ref b)) (he : b.norm = a.norm) (hn : a.Normal)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ Ψ (μ.set l (.val v)) ∧ CaptureOk P B Ψ R Γ Φ cap ∧
      Entails [] (predBind (valEnv cap.env).values p)
```

Reference を含む data では根の観測を残し、その欄だけが none になる。境界で data の型付け、欄の観測失敗、RootShape、実際の firstAlt、matched/excluded の事実を同じ値で検査する。if/match の整数 snapshot と、guard 内の set は、経路規則の入口と `GuardBodyTy.store`／`CaptureOk.store` に接続する。

## 場合の数と境界の関門

初回の予定は参照の実際の Step 4場合、CellOk の移送7形、ContTy 10構成子、GuardBodyTy 1構成子であった。Cell の列挙を照合した結果、7形は誤数であり、builder・val・thunk・done・cont・used の6形である。builder の内容3形はその内数である。参照の4遷移・Cellの6形・ContTyの10構成子・GuardBodyTyの1構成子を実装した。値29・計算24・相互三族76・Step76の構成子は増減しない。境界は ref(3)・get・snapshot の束縛・set(9)・snapshot の返却の実際の遷移列を組み、現内容の観測の型付け不可を対にする。

`test-audit` の作成時の関門: 守る契約は、不変な捕捉の事実と可変セルの内容の分離、ストアの領域拡張、待機する guard の捕捉の保存である。セルを観測可能にする、data 全体の観測を落とす、store 移送で Φ を捨てる、allocation で既存セルを移さない退行を捕まえる。先行の境界には参照への書込みと snapshot の対がない。実際の判断・遷移を使い、テスト専用の本番の差込み口は作らない。

## 補助契約の決定の記録

| 採る案 | 理由 | 捨てる案 |
|---|---|---|
| 既存の store 移送から GuardBodyTy/ContTy/CellOk を組む | 捕捉の facts は同一の証拠を保ち、セルの現内容に依存しない | 状態へ別の Φ や精密なストアの論理モデルを足す |
| allocation はストア型と実ストアの両方を更新する | StoreOk の領域条件と有限性を満たす | 実セルなしに StoreTy だけを広げる |
| 代表の呼出し元は空の捕捉とし、実際の Step と組にする new/set に closeVal の一致を入力にする | 全 closeVal の型保存を L20 より先取りしない。開始の StateTyE の StoreOk・継続を逆転して使う | 到達の ClosureTy/StateTyE を補助入力として仮定する |
| 承認済みの CoreAssumptions と StoreShape の強化から ReferencePrimitives を導く | 抽象の B でも get/set の存在と適切な kind を保証する | 具体の表だけを照合する、ReferencePrimitives を別仮定として残す |
| 参照欄は部分的な観測の none とする | data の根の構成子の事実は観測できる | Reference の内容を整数の既定値に変える、data の全観測を捨てる |

## L20・L30・L40 へ残す分

L20 は任意の捕捉を持つ呼出し元、特に境界の s4（`.mk capR` の get）と s7（`.mk capX` の set）の closeVal・Φ の閉じ方と実際の view の合成、全状態への合成を扱う。L30 は開いた Boolean の定数の相異と等号の合同（O054）と、update の f の仮引数名が `value` に限られる形式側の条件を Rust と照合する。L40 は一般の canonical forms と本番の組み込み表への接続を扱う。今回の4代表を全状態の保存とは数えない。署名の補助の細部を変更した場合は、ここへ採否と理由を追記し、主な定理等の五つの境界に触れる場合だけ停止する。

## 実装中の補助契約の確定

- `pullback` と `primitive_call` は論理の移送だけで閉じ、SubstitutionAssumptions と StoreTy.WF は不要だったため、この二つの入力を除く。`primitive_call` には上記の ground を明示する。閉じた呼出しの逆転は `ClosureTy.pure_primitive` として別に公開し、ここで既存の ValueAssumptions と StoreTy.WF を使う。
- update の実際の展開に現れる型引数は、`Closure.view` が閉じた `Ty.normTys ts` である。到達の署名をこの像へ合わせる。生の ts を使った形は、非正規形の型引数では実際の Step の到達ではない。
- update の get/set は、存在と PrimKind だけでは型付かない。型パラメータの kind も必要である。承認された強化では、CoreAssumptions に存在の二欄を加え、参照4種の StoreShape に型パラメータの kind 条件を加える。ReferencePrimitives の定義は変えず、下記の構成補題の結論として使う。到達の型付けを補助入力として要求しない。

```lean
def ReferencePrimitives (P : Program) (B : Builtins) (ts : List Ty) : Prop :=
  ∃ a, Ty.normTys ts = [a] ∧
    HasTypeV P B StoreTy.empty [] [] [] (.prim B.refGet (Ty.normTys ts) [] [])
      (.fn ["reference"] [.reference a] a (Eff.single stateEff)) ∧
    HasTypeV P B StoreTy.empty [] [] [] (.prim B.refSet (Ty.normTys ts) [] [])
      (.fn ["reference","value"] [.reference a,a] (.base .unit) (Eff.single stateEff))

```

`ReferencePrimitives` は内容型と二つの型付きの値の存在命題である。次の完全署名で任意の閉じた適格な内容型について構成する。閉じた型でないもの、constructor kind の型引数、Ordinary でないものを無条件に許すという意味ではない。これらの条件は、型付き呼出しの既存の SignatureInstance・PrimitiveAdmissible から得る。

```lean
theorem Builtins.CoreAssumptions.reference_primitives {P B ts a}
    (hA : Builtins.CoreAssumptions P B) (hts : Ty.normTys ts = [a])
    (ha : Ty.Annotation P [] [] a) (hn : a.Normal) (ho : a.Ordinary)
    (hk : a.HasKind P [] .value) : ReferencePrimitives P B ts
```

get/set の依存列の宣言・具体化・kind・適格性・結果の注釈を構成し、非依存の fn へ正規化する。update の保存は開始の BuiltinArgs から上記の条件を取り出してこの補題を呼ぶ。hops の別仮定はない。

update の状態の代表の関数値は、実行時の `.closure runtime body` とする。この形では `rename` が値を保ち、閉包の Ground と Adequate を二つの let の下でもそのまま使える。関数の型は篩を含む任意の内容型 a の a→a であり、関数本体の型付けを仮定から除かない。`update_body` の計算の型付けは任意の f で閉じるが、状態の閉性と Adequate を全 callable に移す一般化は L20 に残す。全 Val/Comp の改名の閉性をこの作業で追加する案は採らない。`StateTyE.reference_update` の完全署名の f を `.closure runtime body` に置換し、closeVal の一致は計算で閉じるので入力から除く。

## 実際の Step と代表を組にする入口

次を追加する。`Closure.pure_primitive_view` は開始の閉性と値の一致から、型引数・行引数を正規化した実際の view を返す。`StateTyE.reference_new_transition`・`reference_get_transition`・`reference_set_transition`・`reference_update_transition` は、保存補題の入力に加え、new/set では実引数を closeVal で閉じても変わらない条件 hc を取り、対応する実際の `Step … none … ∧ StateTyE …` を返す。保存側の補助入力に到達の型付けを含めない。

```lean
theorem Closure.pure_primitive_view {b ts es rs ws}
    (h : (Closure.pure (.app (.prim b ts es rs) ws)).ClosedAt 0)
    (hc : closeVals Capture.empty ws = ws) :
    (Closure.pure (.app (.prim b ts es rs) ws)).view =
      .app (.prim b (Ty.normTys ts) (es.map Eff.norm) rs) ws
```

追加の補題 `BuiltinArgs.reference_new/get/set/update` は型付き実引数を解体し、内容型の Annotation・Normal（update は Ordinary と型引数の像も）と、実引数の型付け、結果型と State の等号を返す。`ClosureTy.pure_return` は開始の pure 閉包から戻り先の閉じ方を再利用して ret を型付ける。これらは既存の主定理の仮定変更を行わない。最終の完全署名は `public-api.log` に全公開名を列挙する。

## 最終照合と guard の扱い

2026-11-01。新規の本番モジュールは ReferenceStore・ReferenceCalls・ReferencePreservation の3本、既存の変更は集約 import の1行と ConstraintAssumptions の承認済み強化である。新規3モジュールの公開宣言は定義2本・補題29本。`ReferencePrimitives` 以外の新しい判断を置かず、既存の判断・遷移の構成子を変更しない。

既存の guarded 規則は guard に Eff.empty を要求する。guard の中で State を生じる set を直接行う形は、現在の規則では型付かない。境界の `guard_with_set_untyped` は、Boolean を返す `let _ = set(...); true` を結果型の不一致へ頼らず、内側の set の効果と Covers を逆転して否定する。捕捉については `pending_after_write`・`extension_guard` が、同じ GuardBodyTy を書込み後・拡張後にも保持する。今回、guard の純粋性を緩める規則は加えない。

`execution` は元の let のプログラムの9遷移を示す。`program_start` の静的な結果型は Integer である。get が返した3を捕捉した後の追加の Φ は、`snapshot_capture` が閉じた評価から作り、`body_reads_snapshot` と `final_typed` が set の後の返り値の篩に使う。元のソースの get が篩 `self < 8` を静的に推論したとは主張しない。match の追加の事実は実際の firstAlt の成功から `snapshot_matched_fact`・`match_snapshot_capture` を経て本体に渡す。全 let の途中状態を開始から一括して保存する定理は L20 に残る。

## 再開で確定した前提と境界

CoreAssumptions の新しい二欄は旧 Assumptions と同じ形である。

```lean
ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
```

StoreShape の `.refNew`・`.refGet`・`.refSet`・`.refUpdate` に、末尾の条件 `s.tparams.map TParamDecl.kind = [.value]` を加える。force の条件は変えない。値の型引数を使う4種を揃える案を採った。get/set だけへ加えて update の型付き引数から同じ value kind を得られないままにする案は採らない。旧モデルの型パラメータは embedTParam により value kind になるため、3表の既知の Reference 署名はこの条件を満たす。

境界は旧3モデルについて存在・PrimKind・型パラメータの value kind を6正例で照合する。旧モデル全体を篩の Builtins へ埋め込む定義は現行にはなく、今回追加していない。旧3モデルの全 Assumptions は既定ビルドと公理監査で再検査する。篩側では具体の4項目の表の全 CoreAssumptions を構成する。rv-14c-t3 と同じ constructor kind の get を持つ表は t3_not_core で拒否する。ReferencePrimitives を具体の表からだけ作って抽象の B の問題を残す案は採らない。

レビューの不変性の負例を境界へ写した。篩の内容型の正例はセルの水準に加え、small_get_pair・small_set_pair で実際の呼出しと保存まで示す。非正規形の型引数の raw_primitives も CoreAssumptions の構成補題を使う。rv-* の原本は変更しない。
