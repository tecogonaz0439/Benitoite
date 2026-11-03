# RV-L40.c-obstruction: L40.15 の停止の反例の独立レビュー

2026-11-03。対象はブランチ `m014/l40.c` の未コミットの作業木（基準 `4d27a9306e76b51f0686d04338a574053755dd4d`）、担当の [l40/c/results.md](../l40/c/results.md) の「停止の反例と変更前の差」と [l40/c/obstruction.lean](../l40/c/obstruction.lean)。git の操作、既存のファイルの変更、`lake build` はしていない。書いたのは本書と一時領域の補助の入力だけである。行番号は作業木の現在の版による。「主な十言明」と名付けた一覧は改造の文書に見当たらなかったので、[l00b.15/theorems.md](../l00b.15/theorems.md)「主な定理と量化の新旧」の保存・進行・実行関数の健全性・エフェクトの健全性・ラムダ名の系・対象の健全性・脱糖の各行を主な定理として照合した。

## 結論

| 問い | 判定 | 根拠の種類 |
|---|---|---|
| 反例は正しいか | 正しい。担当の results.md の表に挙がる10宣言を単独 Lean で再検査し、終了0、公理は許可三つだけ | 実行で確定 |
| 主な定理に当たるか | 当たる。L40.15 の中間の言明だけが強すぎるのではない。計画した進行（全 `StateTy` について Final 又は Step）は、現行の定義では偽である。主な定理の前提（`Program.WellFormed`・`Program.WellTyped`・`Program.EffectsOk`・`CoreAssumptions`・`σ.Valid`）を同時に満たす具体の P・B・σ でも反例の状態は型付きで行き詰まる。型付きの開始状態から一歩で同じ行き詰まりへ到達する例もあり、計画した保存と進行は同時には成り立たない | 実行で確定（補助の入力、第6節） |
| 旧の形式化の扱い | 旧 `Release` と `Core` は捕捉環境を持たない置換の意味論で、生の lambda そのものが関数の値であり、E_Lam は生の lambda に適用する。避ける制限は初めから要らず、L20・L30 で落ちた制限はない。穴は新しい判断が closure の意味論を入れたときに生じた | 読めば確定 |
| 処理系の実際 | 参照インタプリタと VM の実行時の値に生の lambda はなく、lambda の評価は常に捕捉付きの closure を作る。捕捉の値はレジスタか外側の捕捉から取る実行時の値である | 読めば確定 |
| 推す案 | 担当の第3案の最小の形。新しい構成子を足さず、`E_Lam` の前提の `q.view = .app (.closure signature body) ws` を「`q.view = .app f ws` かつ `closeVal Capture.empty f = .closure signature body`」に広げる | 判断（第4節） |

## 1. 反例の正否と主な定理への当たり

### 1.1 定義の読み

次の四点で行き詰まりが決まる。いずれも読めば確定する。

- `closeVal` の var の枝は捕捉の値をそのまま返す（`Release/Refinement/Capture.lean` 39行）。lam・dependentLam の枝は closure を作る（43・44行）が、var の枝の結果にはこの変換がかからない。`Closure.view` の app の枝は関数の位置に `closeVal q.capture f` を置く（72行）。
- `CaptureOk` は捕捉の値に `Ground` と、通常の型の位置の `ImageOk` だけを求める（`Typing.lean` 397・398行）。`ImageOk.ordinary` は値の型付けを求める（487〜489行）。生の lambda は `V_Lam`（153行）で型付くので、どちらの条件も生の lambda を除かない。
- `Step.E_Lam` は `q.view = .app (.closure signature body) ws` だけを受ける（`Semantics.lean` 80〜82行）。実行関数 `stepRun` も同じ形だけを照合する（`Step.lean` 62行）。生の lambda と dependentLam を関数の位置に持つ app に適用できる規則はほかにない。
- `StateTyE` の run の枝（`StateTyping.lean` 158〜160行）と `StateTy`（168〜169行）は、ストア・閉包・継続の型付けと閉性・Adequate を求めるだけで、到達可能性も値の形の条件も持たない。

### 1.2 担当の入力の再検査

`obstruction.lean` を一時領域へ写し（SHA-256 が原本と一致）、`formal/` で `lake env lean -M 12288` により検査した。終了0である。results.md の表の9行に挙がる10宣言（`raw_typed`・`capture`・`state`・`direct_lambda_closes`・`captured_lambda_remains`・`view`・`no_runtime_closure`・`formed_application`・`stateTy`・`no_step`）はすべて型検査を通った。

### 1.3 主な定理の前提を満たす具体の表

担当の反例は任意の P・B について述べるので、前提を満たす P・B が存在しなければ主な定理は空虚に真になる。そこで、本番の `CaptureReadBoundary.lean` 7〜172行の具体の表（定義は空の Program と、Reference の get/set と純粋な組み込みを一つ持つ Builtins）を private を外して写し、次を証明した（補助の入力の `progress_premises_counterexample`、終了0、公理は許可三つだけ）。

- `modelProgram.WellFormed`、`modelProgram.WellTyped modelBuiltins`、`modelProgram.EffectsOk modelBuiltins`、`modelBuiltins.CoreAssumptions modelProgram`
- 具体の `σ0` について `σ0.Valid`
- 担当の状態 `s` について `StateTy modelProgram modelBuiltins σ0 s`
- 任意の event・dest について Step がない
- `s` は `.run q k μ` で `q.view` は ret の形でない（旧の `State.Final` に当たる形でない）

新しい `State.Final` と新しい進行の定理はまだ Lean にない。旧の `State.Final`（`Release/Semantics.lean` 332〜336行）と同じ形で定義する限り、`s` は Final でない。したがって、計画した進行（l00b.15/theorems.md「主な定理と量化の新旧」の進行の行）は、現行の `StateTy` の定義のままでは証明できない。

### 1.4 型付きの開始状態から到達する例

到達可能な状態に限ればよいかを確かめるため、捕捉に生の lambda を持つ closure をコードに直接書いた開始状態を作った（補助の入力の `reachable_counterexample`、終了0、公理は許可三つだけ）。

- `bad := .closure (.done Unit {}) ⟨[生の lam], app (var 0) []⟩`、`start := .app bad []`
- `start` は空の文脈・空の効果で `HasTypeC` を持つ（`V_Closure` と、`CaptureOk` が生の lambda を受けることによる）
- `s0 := .run (Closure.pure start) [] ∅` は `StateTy`
- `s0` から `E_Lam` で `s1 := .run ⟨[生の lam], app (var 0) []⟩ [mark] ∅` へ一歩で遷移する
- `s1` からはどの Step もなく、`s1` の view は ret の形でない

保存が成り立てば `s1` は型付きなので、進行が偽になる。すなわち、現行の定義では計画した保存と進行の少なくとも一方が偽である。到達可能な状態へ主な定理を限っても、この例は除けない。

ただし、`Program.WellFormed` は宣言の本体に `SourceScoped` を求め、`SourceScoped` は closure の構文を受けない（`SourceScope.lean` 59行）。このため、上の例はプログラムの宣言の本体からは作れず、開始の項に closure を直接書いたときに生じる。開始の項を `SourceScoped` に限っても、δ・IO・外部の応答が捕捉に生の lambda を持つ closure を返す経路は残る。`delta_typed` の結論は `Outcome.Typed`（`HasTypeV` と `Ground`）だけであり、この closure は型付くので、表の条件はこの応答を除かない。`E_Prim` は応答を `Closure.pure (.ret v)` に置き、`closeVal` は closure の内側の捕捉を変えない（`Capture.lean` 45行）。この経路は読めば導けるが、Lean で具体の表を構成していない（実行しないと分からない部分として残す）。

### 1.5 影響しない範囲

- セルに生の lambda を置いても行き詰まらない。セルからの読み出しは `Closure.pure (.ret v)` を作り、次の view が空の捕捉で閉じて closure に変える（補助の入力の `cell_read_closes`、rfl）。RV-L20.s「観点2」の所見はセルについて正しく、捕捉からの読み出しは調べていなかった。
- 照合の値・guard の値・解放の値は関数として適用されないので、生の lambda を持っても行き詰まらない（読めば確定）。
- `effect_soundness`・`step_sound` は行き詰まりでは破れない。破れるのは進行と、保存との組み合わせである。

## 2. 旧の形式化での扱い

旧 `Release` の `Frame`・`State` に捕捉環境はなく、値は置換でコードに埋め込む（`Release/Semantics.lean` 26〜60行）。`E_Lam` は `.run (.app (.lam names ps body) ws) k σ` を `body.instantiate ws` へ移す（133〜135行）。`Core/Semantics.lean` の `E_Lam`（44行）も同じ形である。旧の `progress`（`Release/Theorems.lean` 39〜43行）は `P.WellTyped B`・`P.EffectsOk B`・`B.CoreAssumptions P` と全 `StateTy` を前提にし、到達可能性を前提にしない。生の lambda がそのまま関数の値なので、除く条件が要らなかった。

新しい判断では、`closeVal` がコードの位置の lambda だけを closure に変え、`E_Lam` が closure だけを受ける。一方、`CaptureOk` は捕捉の値の形を限らない。L20 の旧導出の埋め込みは捕捉を空にし、保持する値を `closeVal Capture.empty (embedVal v)` とする（plan の 2026-11-03 の L20.145 の判断、`LegacyStateTyping.lean`）ので、埋め込みの像は実行時の値の形を保つ。旧から移すべき制限が落ちたのではなく、L00b の closure の意味論の導入のときに、捕捉から読む値の形を誰も確かめなかったことが原因である。l40/detail.md の F03 の「実際の q.view で生の lam/dependentLam が closure へ変わる点は closeVal の定義を使って15で接続する」という前提は、捕捉から読む場合に誤りである。

## 3. 処理系の実際

参照インタプリタの値（`crates/benitoite/src/refinterp/value.rs` 17〜44行）に lambda の形はなく、関数は `Value::Func(Rc<Closure>)` だけである。`Closure` は本体の識別と捕捉した値の列を持つ（61〜65行）。lambda の評価（`refinterp/eval.rs` 276〜289行）は、本体の自由変数を環境から取り出して closure を作る。VM では、lambda は `Opcode::Closure` の命令に変換し（`bytecode/codegen/emit.rs` 1257〜1272行）、捕捉の出どころは作る側のレジスタか作る側の捕捉に限る（`bytecode/program.rs` 77〜82行の `CaptureSource`）。呼び出しは関数の値を要求する（`vm/dispatch.rs` 569〜571行）。したがって、実行中に捕捉される値は常に実行時の値であり、ソースの lambda が捕捉に入る経路はない（読めば確定。関係する範囲だけを読んだ）。

## 4. 代案の比較

基準は、主な定理の言明の形と量化を変えない、利用者の書ける形を狭めない、新しい公理を足さない、追随する本番の範囲が小さい、旧に倣える案を優先する、の五つである。所要は読んだ範囲からの目安であり、実測ではない。

| 案 | 変える定義 | 追随する読者 | 主な定理の前提・意味への影響 | 区分 | 所要の目安 |
|---|---|---|---|---|---|
| 3' 推奨（第3案の最小の形） | `Step.E_Lam` の前提を「`q.view = .app f ws`、`closeVal Capture.empty f = .closure signature body`、`ws.length = signature.arity`」にする。構成子は増やさない。`stepRun` の closure の枝も同じ照合にする | `E_Lam` を名指しする `Semantics`・`DependentBeta`・`ClosureStateLeaves`・`CapturedFacts`、`Step` の全場合分け（多くは自動で閉じる見込みだが実行しないと分からない）、`step` の補題、E_Lam の保存の葉に生の lam・dependentLam の場合を足す（`close_value_typed` に `CaptureOk.empty` を渡し、既存の closure の葉へ渡す）、01-12・07-04 の写し | `StateTy`・型付け・`CoreAssumptions` は変わらない。言明の字面も変わらない。`Step` は、今どの規則も適用できない状態にだけ遷移を加える。closure の場合は `closeVal Capture.empty` が恒等なので現行と同じ（`closure_fixed`）。到達先は、同じ lambda をコードに直接書いて閉じた closure へ現行の `E_Lam` を適用した到達先と同じ（`captured_closes`・`same_target`）。遷移は一意のまま | 実行の規則の拡張（量化を狭めず、不変条件も写さない） | 2〜5時間 |
| 1 実行時の値の条件を捕捉に保持する | 値の位置（con・list・map・set・dict・super の成分）に生の lam・dependentLam を含まない条件を Val に定義し、`CaptureOk` の `Ground` の欄に連言で加える（closure の内側は `V_Closure` の `CaptureOk` が受け持つ） | `CaptureOk` を作る補題と呼び出し（`extend` の一致約63箇所、`extendHidden` 5、`extendCont` 3、`extendTel` 2、`match_extend` 3、作り直す系の補題44件の一部）、L20 で受け入れたモジュールを含む。新しい補題は「条件を満たす捕捉での `closeVal` の結果は条件を満たす」、`firstAlt` の結果、辞書の成分 | 言明の字面は変わらない。`StateTy` と値の型付けは、捕捉に生の lambda を持つ closure を除く分だけ狭くなる。`delta_typed`・`io_typed`・`io_exists`・`release_exists`・`external_typed` の内容も、型付きの値の範囲を通じて変わる（07-04 に V_Checked と同じ形で記録が要る） | 実行時に成り立つ不変条件を型付きの状態へ写す。除く状態は処理系では生じず、利用者の書ける形も狭めない。ただし、そうした closure を返す組み込みの表は条件を満たさなくなる | 5〜12時間 |
| 2 捕捉から読むときに変換する | `closeVal` の var の枝を `closeVal Capture.empty (cap.env i)` 相当にする。構造的な再帰にならないので、空捕捉で閉じる関数を先に別に定義する必要がある | `closeVal` を読むほぼ全体（`close_value_typed` の V_Var の場合、`CaptureApplicationAlgebra`・`CloseApplication`・`TypeValueExchange`・`Capture.typed_meaning`・`close_ground`、`v = closeVal cap vs` を持つ K_Guard と matchRun、`closeVal cap (.var i) = cap.env i` を rfl で使う全箇所）。δ が受け取る値も変わる（`CaptureReadBoundary` の観測） | `StateTy` は変わらないが、すべての変数の読み出しの意味が変わる。到達可能な状態で振る舞いが変わらないことを示すには、案1と同じ条件が結局要る | 実行の規則の変更（全変数の読み出し） | 8〜20時間。危険が大きい |
| 4 到達可能な状態に主な定理を限る | 進行の量化を到達可能な状態へ狭め、到達の不変条件を別に証明する | 進行・保存の全体 | 量化を弱める。しかも第1.4節の例は型付きの状態から一歩で到達し、開始の項を `SourceScoped` に限っても δ の経路が残るので、案1と同じ条件を到達の不変条件として別に要する | 保証の範囲を狭める | 採らない |

推す案は 3' である。理由は次の三つである。

1. 主な定理の前提（`StateTy`・型付け・`CoreAssumptions`）と量化を一切変えず、`Step` に加える遷移は、今どの規則も適用できない状態に限られる。保存の義務は増えるが、結論は弱まらない。
2. 旧の `E_Lam`（生の lambda に適用し、本体へ実引数を代入する）と 01-12 の E-Lam（`(λ[n̄](x̄:Ā). M)(W̄)`、01-12 の321・867行）に倣う形である。捕捉の値は `Ground` なので、空の捕捉で閉じても意味は変わらず、到達先は実行時の closure を適用したときと同じになる。処理系では生の lambda が実行時に現れないので、Rust との比較の対象は変わらない。
3. 構成子の数も76葉の数も変わらず、追随は `E_Lam` の4モジュールと葉一つが中心で、L20 で受け入れた型付けのモジュールに触れない。

案1は処理系の不変条件をそのまま写す点で筋がよく、設計者が「処理系に存在しない形への遷移を規則に置かない」ことを重く見るならこちらを採る。その場合は、組み込みの表の条件の内容が変わることを 07-04 に記録する必要があり、追随は案 3' の数倍になる見込みである。

## 5. 設計者の判断が要る点

1. 形式化の実行の規則（`Step.E_Lam` の前提）を広げることを認めるか。主な定理の言明の字面・前提・量化は変わらないが、主な定理が量化する `Step` の内容は変わる。案1を選ぶなら、型付けの規則（`CaptureOk`）と組み込みの表の条件の内容の変更を認めるかが問いになる。
2. 案 3' を採るとき、Lean の実行関数 `step` にも同じ場合を加えるか。`step_sound` は一方向なので、加えなくても健全性は保てる。規則と実行関数の対応を保つため、加えることを推す。
3. l40/detail.md の F03 の該当文（第2節）と、B15-Capture・B15-Fn-lam の再開の署名を、採る案に合わせて取りまとめが改める。L40.15 の他の20行の判定は本レビューの対象外である。

## 6. 実行した検査

いずれも `formal/` で実行した。既定ビルドの olean は担当の最終ビルドのものを使い、本番のソースは変えていない。

| 検査 | 入力 | 終了 | 外側の秒 | 公理 |
|---|---|---:|---:|---|
| 担当の反例の再検査と、主な定理の前提・到達する例・案 3' の確認 | `<tmp>/rv-l40-c/rv_l40c_check.lean`（18,390 bytes、SHA-256 `a165d9a58cb8a9b889547df2deff4252c3cd6eb8aa28a67cce0ace322743bb93`）を `lake env lean -M 12288` | 0 | 0.93 | `progress_premises_counterexample`・`reachable_counterexample`・`cell_read_closes`・`captured_closes` は propext・Classical.choice・Quot.sound だけ |

出力は `<tmp>/rv-l40-c/rv_l40c_check.out`（SHA-256 `59469109dc33abbca7aaf1063e5aa17980703bf5355998d5cb407c089bc18dd9`）である。途中の2回は補助の入力の誤り（補題の写し漏れ、`EffectsOk` の組の書き方、遷移の到達先の書き方）で終了1になり、直して再実行した。最大常駐量は、終了1になった初回の計測で約1.8 GB である。成功した回の常駐量は取得していない。

補助の入力は次の三つをこの順につないだものである。

1. [l40/c/obstruction.lean](../l40/c/obstruction.lean) の全文（SHA-256 `fb93bd98fdb838a5dfe1f9b81667ba1436274f703bd8a67d01b7d1f448305999`）
2. `set_option linter.unusedSimpArgs false`、`namespace Benitoite.Release.Refinement.RVL40c`、`noncomputable section` と、`formal/Benitoite/Release/Refinement/CaptureReadBoundary.lean`（SHA-256 `421f65153862f876388a165c822a047a0a865ea551f5e435325729a3edf3581d`）の7〜172行の各行の先頭の `private ` を除いたもの
3. 次の付録の全文

## 付録: 補助の入力の追加部分

```lean

theorem unit_annotation {Γ : Ctx} : Ty.Annotation modelProgram [] Γ (.base .unit) :=
  ⟨trivial,trivial,trivial⟩

theorem model_effectsOk : modelProgram.EffectsOk modelBuiltins :=
  ⟨(by intro l os o h; cases h), (by intro o od h; cases h), (by intro l os h; cases h)⟩

/-! ## 1. 主定理の前提をすべて満たす具体の P・B・σ でも、反例の状態は型付きで行き詰まる -/

def σ0 : PathEnv := ⟨[],[],[],none,none,none⟩
theorem σ0_valid : σ0.Valid := by simp [PathEnv.Valid,σ0,Scope.Domain.PathWordWF]

open CaptureLambda in
theorem progress_premises_counterexample :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
    modelProgram.EffectsOk modelBuiltins ∧ modelBuiltins.CoreAssumptions modelProgram ∧
    σ0.Valid ∧ StateTy modelProgram modelBuiltins σ0 s ∧
    (∀ ev d, ¬ Step modelProgram modelBuiltins σ0 s ev d) ∧
    (∃ q k μ, s = .run q k μ ∧ ∀ v, q.view ≠ .ret v) :=
  ⟨model_wellFormed, model_wellTyped, model_effectsOk, model_core, σ0_valid,
    stateTy modelProgram modelBuiltins σ0_valid, fun _ _ => no_step,
    ⟨q, [], Store.empty, rfl, by intro v h; rw [view] at h; cases h⟩⟩

/-! ## 2. 型付きの閉じた開始の項から一歩で同じ行き詰まりへ到達する（closure の構文をコードに書く） -/

abbrev U : Ty := .base .unit
def rawLam : Val := .lam [] [] (.ret (.const .unit))
def badCap : Capture := Capture.empty.extend rawLam
def badCode : Comp := .app (.var 0) []
def bad : Val := .closure (.done U Eff.empty) (.mk badCap badCode)
def start : Comp := .app bad []
def s0 : State := .run (Closure.pure start) [] Store.empty
def s1 : State := .run (Closure.mk badCap badCode) [.mark] Store.empty

theorem badCap_ok : CaptureOk modelProgram modelBuiltins (hideBuilders StoreTy.empty) none
    (Ctx.extend [] (.fn [] [] U Eff.empty)) [] badCap := by
  have he : hideBuilders StoreTy.empty = StoreTy.empty := by funext i; rfl
  rw [he]
  simpa [badCap, rawLam, CaptureLambda.cap, CaptureLambda.raw, CaptureLambda.F, CaptureLambda.U,
    CaptureLambda.E] using CaptureLambda.capture modelProgram modelBuiltins

theorem bad_typed : HasTypeV modelProgram modelBuiltins StoreTy.empty [] [] [] bad
    (.dependentFn (.done U Eff.empty)) := by
  have hb : TelBodyTy modelProgram modelBuiltins (hideBuilders StoreTy.empty) Qempty []
      (hideConts (Ctx.extend [] (.fn [] [] U Eff.empty))) [] (.done U Eff.empty) badCode := by
    apply TelBodyTy.done
    apply HasTypeCQ.C_App (ns := []) (as := [])
    · apply HasTypeVQ.V_Var (a := .fn [] [] U Eff.empty)
      · rfl
      · trivial
    · exact .nil
  have hann : Ty.Annotation modelProgram [] (hideConts (Ctx.extend [] (.fn [] [] U Eff.empty)))
      (.dependentFn (.done U Eff.empty)) := unit_annotation.done_empty
  have he : badCap.closeTel (.done U Eff.empty) = .done U Eff.empty := by
    simp [Capture.closeTel,Tel.bind_done,Eff.bind,Eff.rawBind,Eff.empty,Eff.norm,rowFails,
      instAtoms_nil,substAtoms_nil,Ty.normTys,valEnv,Ty.bind,Ty.rawBind,Ty.norm]
  have hd := DependentClosureTy.mk badCap_ok hb hann (by rw [he]; exact unit_annotation.done_empty)
  exact .V_Closure unit_annotation.done_empty ⟨by trivial,by trivial,trivial⟩ (by rw [he] at hd; exact hd)

theorem start_typed : HasTypeC modelProgram modelBuiltins StoreTy.empty [] [] [] none start U Eff.empty := by
  apply HasTypeCQ.C_DependentApp bad_typed
  exact .done unit_annotation.done_empty

theorem s0_typed : StateTy modelProgram modelBuiltins σ0 s0 := by
  have hq := ClosureTy.pure start_typed unit_annotation.done_empty
    (by intros; contradiction) rfl (by intros; contradiction)
  refine ⟨σ0_valid, Eff.empty, ⟨rfl, by intro a ha; cases a <;> simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at ha⟩, ?_⟩
  refine ⟨StoreTy.empty,none,U,U,Eff.empty,Eff.empty,
    StoreOk.empty _ _ _,hq,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ unit_annotation,?_,?_,
    (by intro f hf; cases hf),(by intro l c hc; cases hc)⟩
  · simp [s0,start,bad,badCap,badCode,rawLam,Closure.pure,Closure.Adequate,Capture.Adequate,Capture.extend,
      Capture.empty,Capture.values,Val.Adequate,Comp.Adequate,adequateCaptureSlots,adequateVals]
  · simp [Closure.pure,start,bad,badCap,badCode,rawLam,Closure.ClosedAt,Capture.Closed,Capture.extend,
      Capture.empty,Capture.values,Val.ClosedAt,Comp.ClosedAt,Val.ClosedList,captureSlotsClosed,NamesWF,
      telBinders,Tel.WF,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WF,Ty.WFList] <;> trivial

theorem s0_step : Step modelProgram modelBuiltins σ0 s0 none s1 := by
  have h := Step.E_Lam (P := modelProgram) (B := modelBuiltins) (σ := σ0)
    (q := Closure.pure start) (signature := .done U Eff.empty) (body := .mk badCap badCode)
    (ws := []) (k := []) (μ := Store.empty) rfl rfl
  exact h

theorem s1_stuck {ev d} : ¬ Step modelProgram modelBuiltins σ0 s1 ev d := by
  intro h
  cases h <;> simp_all [s1,badCap,badCode,rawLam,Closure.view,closeVal,Capture.env,
    Capture.extend,Capture.empty,Capture.values,Closure.code,Closure.capture,closeVals]

/-- 進行と保存の両方を同じ前提で述べると、少なくとも一方が偽である。 -/
theorem reachable_counterexample :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
    modelProgram.EffectsOk modelBuiltins ∧ modelBuiltins.CoreAssumptions modelProgram ∧
    HasTypeC modelProgram modelBuiltins StoreTy.empty [] [] [] none start U Eff.empty ∧
    StateTy modelProgram modelBuiltins σ0 s0 ∧ Step modelProgram modelBuiltins σ0 s0 none s1 ∧
    (∀ ev d, ¬ Step modelProgram modelBuiltins σ0 s1 ev d) ∧
    (∀ v, (Closure.mk badCap badCode).view ≠ .ret v) :=
  ⟨model_wellFormed, model_wellTyped, model_effectsOk, model_core, start_typed, s0_typed, s0_step,
    fun _ _ => s1_stuck, by intro v h; cases h⟩

/-! ## 3. セルに生の lambda を置いても、読み出しは view で closure になる（対照） -/
theorem cell_read_closes :
    (Closure.pure (.ret rawLam)).view =
      .ret (.closure (Capture.empty.closeTel (lambdaShape [] [])) (.mk Capture.empty (.ret (.const .unit)))) := rfl


/-! ## 4. 案3の最小形（E_Lam の前提を `closeVal Capture.empty f` で読む）の確認 -/
/-- closure はそのまま。現行の E_Lam が発火する状態では前提が一致する。 -/
theorem closure_fixed (t : Tel) (q : Closure) : closeVal Capture.empty (.closure t q) = .closure t q := rfl
/-- 反例の捕捉から読んだ生 lambda も、空捕捉で閉じると零引数の closure になる。 -/
theorem captured_closes :
    closeVal Capture.empty (closeVal CaptureLambda.cap (.var 0)) =
      .closure (Capture.empty.closeTel (lambdaShape [] [])) (.mk Capture.empty (.ret (.const .unit))) ∧
    (Capture.empty.closeTel (lambdaShape [] [])).arity = 0 := ⟨rfl, rfl⟩
/-- 一般化した E_Lam の到達先は、ソースに直接書いた lambda に現行 E_Lam を適用した到達先と同じ。 -/
theorem same_target :
    (Closure.mk Capture.empty (.ret (.const .unit))).apply [] = Closure.mk Capture.empty (.ret (.const .unit)) := rfl
#print axioms captured_closes

#print axioms progress_premises_counterexample
#print axioms reachable_counterexample
#print axioms cell_read_closes

end
end Benitoite.Release.Refinement.RVL40c
```
