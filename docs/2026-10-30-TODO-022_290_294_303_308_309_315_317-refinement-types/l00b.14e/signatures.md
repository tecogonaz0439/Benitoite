# L00b.14e: 節の引数と resume の完全署名

2026-11-01。B_WORK は `c64c0dc376b85185744303c4752d1f1bb34967af`、指定ブランチは `m014/l00b.14e` である。git 操作は行わない。名前空間は `Benitoite.Release.Refinement` とする。初回の実装前の契約は [signatures-initial.md](signatures-initial.md) に保存した。今回の再開の初めに承認済みの条件と補助の署名を書き、レビューを待たず実装した。以下は所見対応後の最終の契約である。暗黙の変数も含む Lean の出力は [public-api.log](public-api.log)、公開36宣言の全名は [public-names.json](public-names.json) にある。

## 前提の変更の新旧

中1への承認に従い、`Builtins.CoreAssumptions` に旧 Release と同じ欄を戻した。

```lean
state_effect : B.effects stateEff = some []
```

従来の Refinement にはこの欄も `Program.EffectsOk` もなく、今回の `drop_rel_const` は未実装であった。追加した四つの解放時の保存補題は、`(hdecl : P.EffectsOk B)`・`(hA : Builtins.CoreAssumptions P B)` と開始の `StateTyE` を入力にする。`NoStateHandled` はこれらから導く補助であり、主な定理の独立した前提には置かない。既存の代表にある `hA` も新しい欄を含む同じ構造体を指す。`operation_one` は `hx`・`hy` を開始の型付けから導くため、これらを入力から除いた。到達の型付けを仮定しない。

旧 Release の `Program`・`Builtins` は Refinement の型と異なり、そのまま `EffectsOk` の引数にはできない。承認済みの代案として、旧定義の三連言を文字どおり写した。異なるのは名前空間と引数の型だけであり、条件の追加・削除はない。`verify.py` でも空白を除いた定義本体を照合する。`ContTy`・`StateTyE`、型付け・遷移の規則、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変更しない。

## 代表の対象と後段の義務

`operation_one` は単相・一引数、空の `dictParams`、pure の呼出し元、`x.Normal`・`y.Normal`、空のコード型置換の固定点を対象とする。hcap・切り出す k1・継続末尾 k2 は任意である。resume/HRet/drop は任意の捕捉から得る定数の view を対象とする。追加の escape は pure の定数の閉包、error/exit の解放は任意の開始の状態を対象とする。

`capture_tel`・`result_tel` は任意の長さの依存列と任意の捕捉を扱う。後段に残るのはこれらの補題の作成ではなく、操作の開始の逆転・節の型付け・割当てへの合成である。`split_fail`・`fail_input` も本番に置き、`E_OpFail` 全体は型置換の補題の後に扱う。

| 族 | 初回の予定 | 所見対応後の実際 |
|---|---|---|
| 必須の Step | E_Op/E_Resume/E_HRet/E_Drop の4種 | 4種 |
| 追加候補 | E_OpFail/E_OpPrim/E_ResumeErr/E_DropRel の4種 | E_ResumeErr/E_DropRel の2種。E_OpFail/E_OpPrim は L20 |
| 解放時の伝播 | 初回は L20 | E_EscDropRel/E_ErrDropRel/E_ExitDropRel の3種を追加。合計9種の代表 |
| 継続 | 全10構成子 | split_handle/resume_append、state_end/prepend_releases、split_fail/fail_input で全10構成子 |
| ストア | CellOk の既存6形 | 移送・割当て・used 化を再利用 |
| 型付けの逆転 | 値29・計算24構成子 | 部分型・正規化・効果拡大を含む全形を列挙 |
| 公開 | 初回17宣言 | 定義5・補題31の36宣言。CoreAssumptions.state_effect の射影も検査 |

L20 の全状態の保存の枠の内数は、多相・dictParams・非正規形・コードの型置換、任意の closeVal、複数引数での操作全体の合成、失敗節と組み込み節、used/drop 全体、代表の条件を除いた全保存である。一般の `hy`・`hxn`・`hyn`・`hbn` の除去は型置換の補題の後の義務とする。正規形の一引数の代表では `hy` を導けたので削除済みである。`io_op` が現在の CoreAssumptions にない点と E_OpPrim での要否も L20 で調べる。Lazy/Reference と共通の閉包・ストアの一般化は重複加算しない。L30 は Rust との照合、L40 は進行と全 canonical forms への接続を受け持つ。

## guard の言明の範囲

`guard_effect` は**先頭**が `guardF` の型付き継続について `R = none` と `e = Eff.empty` を示す。`operation_under_guard_false` は、その先頭 guard の直前にある対象の単相・一引数・pure の操作呼出しが型付かないことを示す。guard の式の内側にハンドラがあり、そのハンドラが操作を処理する場合はこの定理の対象外である。「guard の評価中には一切の操作が起きない」という言明へ広げない。継続内部の `GuardBodyTy`・`K_Update` の証拠の保持は、切り出し・接続の全構成子の帰納で別に示す。

## 境界の作成時の関門

篩を持つ入力から節の事実を読み、依存する篩の結果を resume し、継続がその事実を読む元の5遷移と負例を維持する。未使用の破棄では、空でない解放列を前置し、State を保持し、セルを used にする4入口を追加する。レビューの反例の表を再現し、旧表が state_effect を満たさないことと、State の予約だけを直すと EffectsOk が衝突を拒むことを分ける。失敗節の具体の型付けから二つの入口を使う。二引数では第二の入力型と結果が先行する引数を参照する正例から捕捉と結果の一致を導く。結論の StateTyE・CaptureOk を入力に仮定しない。保護した rv-* とレビュー本文は [protected-inputs.json](protected-inputs.json) のハッシュで照合する。

## 補助の契約の決定の記録

| 採る案 | 理由 | 捨てた案 |
|---|---|---|
| 旧 CoreAssumptions の state_effect と旧 EffectsOk の写し | 中1の反例で消された State を、旧と同じ条件で予約し、利用者の効果と分離する。承認済み | NoStateHandled を主な定理へ独立して仮定する、新しい別のプログラム条件を作る |
| NoStateHandled から state_end/prepend_releases を証明し、遷移で導出して使う | 解放列の State・型付け・閉性を保存できる | 解放後の StateTyE を補助入力にする |
| Fail の結果行を `.mk et.atoms ec.fails` にする | K_Handle_Fail の原子と Fail を分けて保存する | 通常の split_handle の noFail 条件で失敗節を扱う |
| capture_tel/result_tel を任意の捕捉と依存列に公開する | 二引数を含め、結果の置換を既存の Capture.instantiate から導ける | 複数引数の捕捉と結果の照合自体を L20 に残す |
| hx を HasTypeTelArgsQ.param、hy を SignatureInstance.result の逆転から導く | Normal の下の注釈を開始から得られる | 導ける注釈を operation_one の入力に残す |
| escape は pure の定数のまま、error/exit は任意の状態で保存する | 同じ解放列と used 化を使い、任意の closeVal の保存を仮定しない | 全 escape の保存が完成したとする |
| K_Handle の証拠を HandlerFrameTy にまとめる | 同じ Γ/Φ/ソースの注釈を切り出し後に使う | 閉じた型だけを保持して hcap の契約を捨てる |
| EndsWithHandle と caller の行の Covers で接続する | 継続末尾を元の行に接続できる | 行の等号又は到達の型付けを別仮定にする |
| 節の実行では Fail を保ち、原子だけを末尾の行へ広げる | StateTyE の Sub を構成できる | Covers を Sub と同一視する、StateTyE を変える |
| D19 は既存の addEvaluated/addEntailed/close_entails を使う | 閉じた評価から導く事実を捕捉の契約で読める | 状態の Φ、新しい handler_input_evaluated の重複の入口 |
| resume は格納型の正規形で値を受け取り、R を照合する | ソースの継続変数を捕捉の置換で場所に直せる | StoreTy/CellOk に Sorted を追加する |

以下に公開定義の内容と補題の完全署名を記す。証明本体は相対リンク先の本番ソースにある。

## HandlerContinuation

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
```

## HandlerStore

```lean
theorem StoreOk.use_continuation {P B σ Ψ μ l a t ec R}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont a t ec R)) :
    StoreOk P B σ Ψ (μ.set l .used)

theorem StoreOk.allocate_continuation {P B σ Ψ μ l a t ec R saved}
    (h : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hl : μ l = none) (hw : LocTy.WF (.cont a t ec R))
    (hd : LocTy.Declared P (.cont a t ec R)) (hend : EndsWithHandle saved)
    (hk : ∃ R0 e0, ContTy P B σ Ψ R0 e0 saved a t ec R) :
    StoreOk P B σ (Ψ.put l (.cont a t ec R)) (μ.set l (.cont saved))
```

## HandlerEffects

```lean
def Program.EffectsOk (P : Program) (B : Builtins) : Prop :=
  (∀ l os o, P.effects l = some os → o ∈ os → ∃ od, P.ops o = some od ∧ od.eff = l) ∧
    (∀ o od, P.ops o = some od → ∃ os, P.effects od.eff = some os ∧ o ∈ os) ∧
    (∀ l os, P.effects l = some os → B.effects l = none)

def NoStateHandled (P : Program) (B : Builtins) : Prop := ∀ h, ¬ (handled P B h).mem (.name stateEff (.fixed .top))

theorem ContTy.state_end {P B σ Ψ R ε k a b Eb Re} (hN : NoStateHandled P B)
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hs : ε.mem (.name stateEff (.fixed .top))) : Eb.mem (.name stateEff (.fixed .top))

theorem ContTy.prepend_releases {P B σ Ψ R0 e0 saved a0 t ec r} (hN : NoStateHandled P B)
    (hs : ContTy P B σ Ψ R0 e0 saved a0 t ec r)
    {R ε k a b Eb Re} (hk : ContTy P B σ Ψ R ε k a b Eb Re)
    (hc : ec.mem (.name stateEff (.fixed .top)) → ε.mem (.name stateEff (.fixed .top))) : ContTy P B σ Ψ R ε (releases saved ++ k) a b Eb Re

theorem Program.EffectsOk.noStateHandled {P B}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B) : NoStateHandled P B
```

## HandlerFailure

```lean
theorem ContTy.fail_input {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2 E'}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) (hn : NoHandler k1 .fail)
    (hf : ε.memFail E') :
    ∃ R1 Γ Φ Es Rs ts ecs, CaptureOk P B (hideBuilders Ψ) R1 Γ Φ cap ∧
      HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ Es Rs [.fail E0 body] ts ecs [] ∧
      (cap.closeTy Es).norm = E'.norm

theorem ContTy.split_fail {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) :
    ∃ t ec et Rh, ContTy P B σ Ψ R ε (k1 ++ [.handleF cap [.fail E0 body]]) a t (.mk et.atoms ec.fails) Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧ Eff.Sub (.mk et.atoms ec.fails) et
```

## HandlerCalls

```lean
theorem HasTypeCQ.operation_call {P B Ψ R o v a e L od}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o []) [v]) a e L)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel [] []) r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f

theorem ClosureTy.pure_operation {P B Ψ R a e o v od}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o []) [v])) a e)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel [] []) r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f

theorem ClosureTy.pure_operation_signature {P B Ψ R a e o v od}
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o []) [v])) a e)
    (hd : P.ops o = some od) :
    Ty.Annotation P [] [] (.dependentFn (instantiatedTel od.tel [] []))
```

## HandlerTelescope

```lean
def telExtend : Ctx → Tel → Ctx
  | Γ, .done .. => Γ
  | Γ, .param _ a t => telExtend (Γ.extend a) t

def telLift : List Pred → Tel → List Pred
  | Φ, .done .. => Φ
  | Φ, .param _ _ t => telLift (Φ.map Pred.lift) t

theorem telExtend_sig (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (Γ : Ctx) (hl : ns.length = ps.length) :
    telExtend Γ (signatureTel ns ps r e) = Γ.extendMany ps

theorem capture_tel {P B Ψ R} : (t : Tel) → ∀ {Γ Φ} {cap : Capture} {vs r f},
    CaptureOk P B Ψ R Γ Φ cap → Ty.Annotation P [] Γ (.dependentFn t) →
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) r f →
    (∀ v ∈ vs, v.Ground) →
    CaptureOk P B Ψ R (telExtend Γ t) (telLift Φ t) (cap.extendMany vs) ∧ vs.length = t.arity

theorem result_tel {P B Ψ vs r f} {cap : Capture} {t : Tel}
    (hargs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) r f)
    (hl : vs.length = t.arity) :
    r = (cap.extendMany vs).closeTy t.result ∧ f = (cap.extendMany vs).closeEff t.effect

theorem args_under_capture {P B Ψ vs r f} {cap : Capture} {t : Tel} (hw : t.WF 0 0 0)
    (hargs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t.norm r f) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) r f
```

## HandlerPreservation

```lean
theorem ContTy.return_annotation {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hRe : Re = none) :
    ∀ r, R = some r → Ty.Annotation P [] [] r

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

theorem StateTyE.resume_used {P B σ Eb q l v k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .resume (.loc l) v) (hl : μ l = some .used) :
    Step P B σ (.run q k μ) none (.error [rResume] k μ) ∧
    StateTyE P B σ Eb (.error [rResume] k μ)

theorem StateTyE.resume_const {P B σ Eb q l c k μ saved}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .resume (.loc l) (.const c)) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.const c))) (saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.const c))) (saved ++ k) (μ.set l .used))

theorem releases_mem (f : Frame) (k : Cont) (h : f ∈ releases k) : f ∈ k

theorem StateTyE.drop_rel_const {P B σ Eb q c l k μ saved} (hdecl : P.EffectsOk B)
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret (.const c)) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q (.drop l :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const c))) (releases saved ++ k) (μ.set l .used))

theorem StateTyE.esc_drop_rel_const {P B σ Eb c l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.escape (.const c))) (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    Step P B σ (.run (Closure.pure (.escape (.const c))) (.drop l :: k) μ) none
      (.run (Closure.pure (.escape (.const c))) (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.escape (.const c))) (releases saved ++ k) (μ.set l .used))

theorem StateTyE.err_drop_rel {P B σ Eb rs l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.error rs (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    Step P B σ (.error rs (.drop l :: k) μ) none
      (.error rs (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.error rs (releases saved ++ k) (μ.set l .used))

theorem StateTyE.exit_drop_rel {P B σ Eb n rs l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.exit n rs (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    Step P B σ (.exit n rs (.drop l :: k) μ) none
      (.exit n rs (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.exit n rs (releases saved ++ k) (μ.set l .used))
```

## HandlerOperation

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

theorem ClosureTy.widen_atoms {P B Ψ R q a ec et}
    (hq : ClosureTy P B Ψ [] R q a ec) (he : Eff.Covers [] [] et ec) :
    ClosureTy P B Ψ [] R q a (.mk et.atoms ec.fails) ∧ Eff.Sub (.mk et.atoms ec.fails) et

theorem StateTyE.operation_one {P B σ Eb o name x y eff v cap cs k1 k2 k μ body l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o []) [v])) k μ))
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
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
