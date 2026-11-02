# RV-L20.n: L20 群 N（L20.115〜.122）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.n` の未コミットの作業木、基準 `14dc5648`（san_benito の先端）。依頼文 `L20.n-prompt.md`、担当の報告 `L20.n-report.md`、`l20/n/` の記録（results.md・leaves.md・signatures.md・declarations.md・h04-handoff.md・h04-handoff.lean・各 json・inventory.py・validate.py・axioms.lean と監査の一覧）、`l20/detail.md` の S05・S10・S11・J04（S11 の本文と J20-4）・G07・L20.115〜.122 の行・全76遷移の分担の表・義務の表の該当の行、`plan.md` の確認点の先頭の数行、`l20/l/results.md`、`reviews/RV-L20.l.md` を読んだ。新規の Lean 5本（ControlLeafSelection・FunctionViewGeneral・IntervalConnection・IntervalConnectionExamples・StepLeafSelection）は全文、既存の変更は `git diff` で読んだ。照合のために `Semantics.lean` の Step 全体、`Step.lean` の `stepRun`、`StoreReplyLeaves.lean` の `StoreReplyInputs`、`Interval/Eval.lean` の ConcreteValue・EvalEvent・EvalArms、`Interval/ApproxAdapter.lean`、`TermSyntax.lean` の `termBind` を読んだ。補助の入力は `<tmp>/rv-l20-n/` に置き、既存のファイルを変えていない。

## 総合判定

**条件付き可**（重0・中3・軽7、計10件）。

.115〜.117 は可である。全76遷移の表は、行の名前の集合だけでなく、各行が指す葉の実在・ソース側の一般の StateTyE・行先・Step 構成子の使用を、Lean の型の印字とソースの照合で全行確かめた（「確認した事項」1）。欠け・重複・代表の葉の混入・行先のコードの型付けを仮定する葉はなかった。新しい制御7遷移の行先は Semantics の規則と一字ずつ一致し、σ・Eb を保つ。`termBind?` の成功と `getD` の既定値に到達しないことの証明は正しい。公理依存は独立の対象の一覧でも許可三公理だけだった。

条件は .118〜.122 の三件である。中1は、値の関係 `ValueRel` が近似の一致だけで、Unit・構造値・Result の tag を区別しないことである。腕の接続は独立評価の選択と実際の照合を別々の入力として受け、両者が同じ腕を選ぶことを関係から導けない。中2は、独立評価の腕の構成子のうち `.body` だけを接続し、`skip`・`guardTrue`・`guardFalse` を接続していないことである。中3は、H04 への第二の候補の実行側の結論が `Runs` の定義の展開だけで得られ、`failures` を具体化する義務を署名に持たないことである。いずれも主な10言明・型付け規則・公理には触れない。処置は、関係の定義の強化（中1）、接続の追加か L40/L70 への明示の移送（中2）、候補の署名の修正（中3）であり、取りまとめが選ぶ。

## 所見

### 中

#### 中1: `ValueRel` は近似の一致だけで、構造値と Result の tag を区別せず、腕の選択の一致を関係から導けない（読めば確定、Lean で確認）

- 場所: `IntervalConnection.lean` 13〜15行（`ValueRel`）、339〜388行（`connect_integer_arm`・`connect_width_arm`・`connect_result_arm`）、`IntervalConnectionExamples.lean` 114〜124行（`result_arm` とその docstring「所有元・tag・payload を同じ選択へ渡す」）、h04-handoff.md の「構文と環境」の行、01-12・07-04 の追加段落「Unit や構造値など共有近似が other に写す値について、この関係だけから内部の等号は導かない」。
- 問題点: `ConcreteValue.toApprox` は整数7幅と Boolean 以外の全構成子（`unit`・`other`・`rangeError`・`con`）を `.other` に写し、`Val.toApprox` も `.const` 以外を `.other` に写す。したがって `ValueRel` は、独立評価の Unit・Result・範囲エラーの値と、整数・Boolean の定数でない任意の実値（別の tag の構成子を含む）を結ぶ。補助の入力 `h04_trivial.lean`（終了0）で、`ValueRel (.con "Result" [] "Result.Ok" [.unit]) (.con "Result.Error" [] [.const .unit])` と `ValueRel .unit (.con "Result.Error" [] [])` を閉じた。設計書はこの限界を書いているので、文書の誤りではない。問題は後段への形である。
  - `connect_result_arm` は `ResultSelection … tag … selected` と `firstAlt runtimeValue … = some ws` を独立の入力として受け、両者が同じ腕を選ぶことを結論も前提も持たない。`ValueRel value runtimeValue` からは tag の一致を導けないので、L40/L70 が「実行で選ばれた腕と独立評価の選んだ腕が同じ」を示すには、`ValueRel` より強い関係が要る。整数・幅の腕は値が近似で決まるので導ける見込みがあるが、その補題もない。
  - `EnvRel`・`EnvRelAt` は局所変数の値を `ValueRel` でしか保たないので、let で束縛した Result を後で照合する場合、環境の関係から tag を取り出せない。
  - 例 `result_arm` は変数パターンの腕だけを使うので、tag の取り違えを検出しない。docstring の「tag を同じ選択へ渡す」は実物より強い。
- 修正案: 次のどちらかを取りまとめが選ぶ。(a) `ValueRel` を、整数・Boolean は近似の一致、Unit は `.const .unit`、`con` は所有元・tag・引数の再帰的な関係、`rangeError`・`other` は明示の対応、と構成子ごとに定義し直し、`connect_result_arm` に「同じ選択肢の実照合」を `ResultSelection` と `firstAlt` の一致として結論させる。(b) 今の定義を残すなら、results.md・h04-handoff.md・01-12・07-04 に「腕の選択の一致は関係から導かず、選択と実照合を別の入力として受ける。構造値の関係の強化は L40/L70 の担当」と書き、`result_arm` の docstring を実物どおりに改め、L40/L70 の完了条件へ移す。S11 の「構文・値・環境の関係」が後段で定義の変更を要するので、(a) を推す。

#### 中2: 独立評価の腕の `skip`・`guardTrue`・`guardFalse` と実行の関係がなく、.121 の「照合/guard/next と独立評価の腕を合わせる」が `.body` だけで閉じている（読めば確定）

- 場所: `Interval/Eval.lean` 1172〜1203行（`EvalArms` の `nil`・`skip`・`body`・`guardTrue`・`guardFalse`・`guardAbrupt`。Width/Result も同じ形）、`IntervalConnection.lean` 339〜405行、results.md の L20.121 の行（「match の skip/guard、guard の真偽と失敗を実際の Steps で合成する」）、detail.md の L20.121 の行。
- 問題点: 三種類の `connect_*_arm` は、いずれも先頭の腕が guard なしで照合に成功する `.body` 構成子だけを結論する。`runs_match_skip`・`runs_match_guard`・`runs_guard_true`・`runs_guard_false`・`runs_guard_failed` は実行側の Steps だけを合成し、`EvalArms.skip`・`guardTrue`・`guardFalse` を結論にも前提にも持たない。具体例 `guards`・`skipped_arm` も独立評価を含まない。results.md の「残る場合」の表が L40/L70 に送るのは `nil` の unknown と `guardAbrupt` の returned だけであり、`skip`・`guardTrue`・`guardFalse` の接続が残ることは書いていない。guard の本体のコードの改名（`arms_code_cons` の guard の枝）と、guard の独立評価の環境（腕の束縛を前置した env）を結ぶ補題もない。
- 修正案: `connect_*_arm_skip`（実際の `firstAlt … = none` と独立評価の選択なしから `EvalArms.skip` と次の腕の実行）、`connect_*_arm_guard_true`・`_guard_false`（guard の `EvalPartial` の normal の Boolean と `runs_match_guard`・`runs_guard_*` から `EvalArms.guardTrue`・`guardFalse`）を足す。足さない場合は、results.md の L20.121 の判定を「`.body` の接続と、実行側の skip・guard の合成」に改め、残る三構成子を「残る場合」の表と L40/L70 の完了条件へ明示して移す。

#### 中3: H04 の第二の候補は、実行側の結論が `Runs` の定義の展開であり、`failures` の具体化の義務を署名に持たない（読めば確定、Lean で確認）

- 場所: `l20/n/h04-handoff.lean` 16〜35行、h04-handoff.md の「実行の結論」の行（「実行との関係の引数 failures は、同じ算術/δの拒否と実際の理由列で具体化し、その適合を証明する」）。
- 問題点: 第二の候補の結論の前半 `∃ events μ' rs, Steps … (.error rs k μ') ∧ failures reason rs` は、仮定 `Runs P B σ failures (.mk cap code) k μ (.failed reason)` の定義の展開だけで得られる。補助の入力 `h04_trivial.lean` で、`EnvRelAt`・code の等号・`EvalPartial`・`TrackedFailure` を使わずに閉じた。後半の `ResultMem (.failed reason)` は P・B・σ・failures・cap・code を含まない解析の命題で、第一の候補と同じ種類の主張である。したがって、第二の候補の仮定 `EnvRelAt concrete cap ξ` と code の等号は使われず、`failures` は全称で量化されているので、H04 が「同じ算術/δの拒否と実際の理由列で具体化し、その適合を証明する」義務は署名のどこにも現れない。J04 が求める第一の候補（mayFail）は文面に合っており、この所見は第二の候補だけに当たる。
- 修正案: 第二の候補を削るか、実際の課題を表す形へ改める。後者の例は、`failures` を全称で量化せず、算術・δの拒否と ErrKind の列の対応を定義した具体の関係（例えば `FailureMatches reason rs`）に固定し、実行の Runs が独立評価と同じ理由で失敗することを結論する形である。どの向き（独立評価から実行か、実行から独立評価か）を H04 と L70 のどちらが受け持つかも h04-handoff.md に書く。現在の候補を残す場合は、h04-handoff.md の「実行の結論」の行を「前半は Runs の定義から直ちに得る。failures の具体化と適合は署名に含まない」と改める。

### 軽

#### 軽1: validate.py は表の名前の集合だけを照合し、69・7 の件数は定数で書かれている（読めば確定、実行で確認）

- 場所: `l20/n/validate.py` 40〜46行、`validation.json` の `general_inherited`・`general_added`、results.md の「署名・全遷移・import の照合」の行、leaves.md の第3列。
- 問題点: validate.py は Semantics の構成子名と表の第1列の集合を比べるが、第2列の葉が実在するか、その葉が同名の構成子を使うか、ソース側が一般の StateTyE かは確かめない。`69`・`7` は計算せず書き込んだ値である。本レビューは全76行を機械的に照合し、結果は表と一致した（「確認した事項」1）ので、表の誤りではない。leaves.md の第3列「元状態と同名の Step の前提」は、Step を結論に持たず StateTyE だけを返す16行（if・match・guard・handler・操作）や、WellFormed などを受ける `match_body`、`Builtins.SubstitutionAssumptions` を受ける `guard_true`（`CoreAssumptions.substitutions` で供給できる）の前提を正確に表していない。
- 修正案: validate.py に、第2列の宣言の実在と、本文に同名の構成子 `.E_X` が現れること（store_reply の行は内側の葉）の検査を足し、件数を表から数える。leaves.md の第3列は、Step を返す葉と StateTyE だけを返す葉を分け、`guard_true` の SubstitutionAssumptions の供給元を書く。

#### 軽2: 空き場所の選択を実行関数に結ぶ式は builder と Lazy だけで、fresh を使う他の4枝にはない（読めば確定）

- 場所: `StepLeafSelection.lean` 89〜113行、`Step.lean` の `stepRun`（`fresh` を使う枝は refNew・op・raise・io/exit/pathBases の節あり・lazyC・builderLet の6つ）、01-12・07-04 の追加段落「selectFresh は空き場所が存在するストアでその場所を選ぶ」。
- 問題点: `StoreOk.selectFresh_empty` は一般の補題なので、E_RefNew・E_Op・E_OpFail・E_OpPrim の前提 `μ l = none` も同じく供給できる。ただし `step … Store.selectFresh … = some (…)` と Step を同時に結ぶ式は `step_builder_new_selected`・`step_lazy_selected` の二つだけで、解放の選択も `releaseStep` の補助の式だけである。results.md の L20.116 の「selectFresh は有限なストアの同じ空き場所を選ぶ」と矛盾はしないが、L70 の step_sound がどの式を新たに要するかが記録から分からない。`selected_primitive_step` の oracle が `if sg.kind = .pure then oracle else B.selectOracle` であるのは、pure が oracle を読まないので `B.selectOracle` 一つで書け、例の `simpa only [ite_self]` も要らなくなる。
- 修正案: 残る4枝と解放の枠の step の式を足すか、results.md の L20.116 に「step の式は builder・Lazy・δ・IO・releaseStep。refNew・op・raise・節ありの組み込みの step の式と解放の枠の step の式は L70」と書く。oracle は `B.selectOracle` に統一する。

#### 軽3: signatures.md は定義の本体を載せず、関係の定義を固定しない（読めば確定）

- 場所: `l20/n/signatures.md` 150行（`def ValueRel … : Prop` で終わる）、320行（`def TrackedFailure … : Prop`）、同様に EnvRel・ExprCode・BlockCode・ArmsCode・ResultRel・EndState・Runs・EnvRelAt・ArmBodyConnection・選択の三関数。validate.py の `headers` は ` :=` で切る。
- 問題点: S11 の成果は関係の**定義**そのものなので、型の署名だけでは何を固定したかが記録から読めない。`TrackedFailure` の中身は h04-handoff.md の表にあるが、`ValueRel`（中1）・`EndState`・`Runs` の中身は Lean を読まないと分からない。
- 修正案: signatures.md の S11 の定義（とくに ValueRel・EnvValuesRel・ResultRel・EndState・Runs・EnvRelAt・ArmBodyConnection・TrackedFailure）に本体を載せる。大きさは数 KB の増加で、上限の内に収まる。

#### 軽4: 制御7遷移の具体の適用は E_EscMark の一構成子だけである（読めば確定）

- 場所: `ControlLeafSelection.lean` 42〜67行（`control_for_model`・`concrete_control_leaf`）、`IntervalConnectionExamples.lean` 225〜239行（`unit_escape` も E_EscMark）。
- 問題点: `control_leaf` の読者はあるが、具体の状態に適用したのは escape から mark への一例だけで、`escape_let`・`escape_handler` と四つの pop の葉は同時に満たせる表で適用されていない。各葉は一般に証明されており前提も少ないので空虚の心配は小さいが、RV-L20.l 軽2 と同じ形の範囲の限定である。`EnvRel.length` の読者も、空の環境で `0 = 0` を得る `arm_code_and_environment` だけである。
- 修正案: 同じ `control_for_model` の形で、let の枠と handler の枠の escape、error と exit の pop の各一例を足す。足さない場合は results.md に「具体の適用は E_EscMark だけ」と書く。

#### 軽5: 関数 view の契約の前提 `t.Support (· ∈ s)` の供給元が記録にない（読めば確定）

- 場所: `FunctionViewGeneral.lean` 9〜17行（`Tel.function_view_contract`）、detail.md の L20.117 の行（「支持なし版は同位置の原子関数の等号で閉じる場合だけ追加し、他は支持を供給する」）、results.md の L20.117 の行。
- 問題点: 支持なしの版を置かない判断は記録どおりである。ただし「他は支持を供給する」の供給元（型付けや WF から `Support` を導く補題、または呼出し側が持つ有限の原子の列）が results.md・01-12 のどこにも書かれていない。具体例 `view_observation_model` は支持を手で構成している。
- 修正案: 後段がどこから `Support` を得るか（既存の補題名か、L70 の担当か）を results.md の L20.117 の「後続との境界」に一行書く。

#### 軽6: `concrete_interval_control` は実行と型付きの状態を並べるだけで、両者を結ばない（読めば確定）

- 場所: `IntervalConnectionExamples.lean` 241〜248行、results.md の「宣言と具体の読者」の表、01-12・07-04 の追加段落の最後。
- 問題点: 結論の `Runs … code [.mark] … (.normal .unit) []` は任意の P・B・σ で成り立つ `binding_and_return` の再掲で、終状態を存在量化する。`StateTyE … (.run (Closure.pure (.ret (.const .unit))) [] Store.empty)` は手で作った別の元状態 `[.mark]` の escape から `typed_returned_mark` で得たもので、`code` の型付けからも、Runs の終状態からも導いていない。同じ表の WellFormed・WellTyped・CoreAssumptions を同時に満たすという主張は正しいが、「戻り先の型と途中 return の実行を同時に満たす」は、同じ実行の終状態が型付くと読める。
- 修正案: docstring と results.md を「同じ具体の表で、途中 return の実行と、escape から mark を外す型付きの葉を、それぞれ満たす」と改める。

#### 軽7: 局所の合成は子の実行から親の実行を作る向きだけで、任意の実行を分解する向きと腕の束縛の個数の一致は後段に残る（読めば確定。後段への申し送り）

- 場所: `IntervalConnection.lean` 56〜59行（`Runs` は Steps の存在）、115〜185行、339〜388行の `hcode`（`upRen ws.length ξ`）と 420〜428行の `arms_code_cons`（`upRen (Arm.bindersOf …) (·+1)`）。
- 問題点: `Runs` は実行の存在であり、`let_normal` などは子の Runs から親の Runs を作る。失敗の所属の健全性を実行から述べるには、与えられた親の実行を子の実行へ分解する補題（Step の行先が規則で決まることの利用）が要る。results.md は「全独立評価からの実行の対応」「逆方向の完全性」を後段とするが、分解の向きが要ることは書いていない。また、腕の接続の `hcode` は `ws.length` で改名し、脱糖は `Arm.bindersOf` で改名するので、`firstAlt` の結果の長さと束縛の数の一致を後段が供給する必要がある。
- 修正案: h04-handoff.md の「全体の合成」の行に、実行の分解の補題と `(firstAlt v alts = some ws) → ws.length = Arm.bindersOf alts` の補題を、H04 か L70 の入力として一行ずつ書く。

## 確認した事項

### 1. 全76遷移の表の機械的な照合

leaves.md の76行を抜き出し、補助の入力で次を確かめた。

- `leaves_check.lean`（`lake env lean -M 12288`、終了0）: 第2列の76の宣言（store_reply の行は store_reply）を `#check @名前` で印字した。欠けは0。
- 印字した型とソースの本文の照合（Python の補助、`leaves_check.out` を読む）:
  - 76行すべてで、ソース側は `StateTyE P B σ Eb (…)` の一般の元状態であり、P・B・σ・Eb・捕捉・継続・ストアは全称で量化されている。代表の名前（`match_body_zero`・`handler_return_const`・`drop_used_const`・`resume_const`・`drop_rel_const`・`esc_drop_rel_const`）は表に現れない。
  - Step を結論に持つ60行のうち55行は、葉（store_reply を指す行は store_reply の場合分けが呼ぶ内側の葉）の本文に同名の構成子 `.E_X` が現れる。残る PathBases・At の5行は store_reply の場合分けで内側の葉へ対応する。store_reply は `StoreReplyInputs` の同名の構成子から同じ `Step P B σ s event dest` を返すので、表で store_reply を指す13行の行先の一致は型で保証される。
  - Step を結論に持たない16件（if 2・match 4・guard 4・handler・操作6）は、結論の行先を Semantics の同名の構成子の結論と一字ずつ比べ、すべて一致した。
  - 仮定の頭を列挙し、主定理の入力（WellFormed・WellTyped・CoreAssumptions・σ.Valid・EffectsOk）、元の StateTyE、Step の前提（view・lookup・照合・応答・空き場所・個数の等号）以外のものを探した。該当は `guard_true` の `Builtins.SubstitutionAssumptions` だけで、`CoreAssumptions.substitutions` から得られる。行先のコードの型付け（ClosureTy・HasTypeCQ・ContTy を行先について）を仮定する葉は0である。
- 件数は builder 3・呼出し4・At 等8・分岐照合10・δ/IO 5・Reference 4・Lazy 6・use 解放9・handler 17・let 等10で、detail の表と一致した。

### 2. 新しい制御7遷移

- `ControlLeafInputs` の7構成子の前提と行先は、Semantics 241〜249行・271〜272行・282〜283行の同名の構成子と一字ずつ一致した。`control_leaf` は Step を各葉から返すので、機械的にも保証される。
- `escape_let`・`escape_handler` は escape の値の型を元の戻り先 `R = some r` から `ClosureTy.escape_view_value` で取り出し、結果の注釈を元の継続枠（`let_inv` の `ClosureTy` と `let_result_annotation`、`handler_tail_annotated` の K_Handle/K_Handle_Fail/K_Sub）から得る。行先の型付けを入力に持たない。`escape_mark` は `mark_inv` と `normal_return_tail` で元の継続から結果の R を得る。四つの pop は元の継続の逆転だけを使う。結論はすべて同じ σ・Eb の StateTyE である。
- `escape_value` は HasTypeCQ の全構成子を覆い、C_Sub・C_Normal・C_Eff を構造的な再帰で下りる。

### 3. 選択・関数 view・観測

- `selectOracle`・`selectRelease`・`selectFresh` は存在するときだけ選び、`_response`・`selectFresh_empty` の補題はその存在を前提に持つ。任意の入力で存在を結論しない。`step_io_selected` は `io_exists` で選び `io_kind` で値・エラー・終了を分ける。`ContTy.selected_release` は既存の `release_response_exists` を使い、Ground・Adequate を加えない。`selected_primitive_step` の BuiltinArgs は元の導出 `app_view_typed`・`primitive_call` と捕捉の Ground から得ている。
- `CaptureOk.termBind_success` は `Term.hasSort_bind` に CaptureOk の Transport を渡して `termBind? … = some u` を得て、`termBind` の定義 `(termBind? ν t).getD (.integer 0)` を `Option.getD_some` で書き換える。既定値 `.integer 0` に到達しないことの証明として正しい。`captured_observation` は `closeVal_observation` と `Val.toTerm_subst_optional` で同じ u を得る。
- `Tel.function_view_contract` の名前・個数・NamesWF・Nodup・foldFnWith の一致は、既存の `fnViewWith?_eq_some_iff` と `foldFnWith_eq_foldFn` の系であり正しい。

### 4. 独立評価との関係

- 定義は主定理を仮定しない。`ResultRel`・`EndState` は normal・returned・failed を別の構成子で区別し、`ResultRel` の異なる構成子の組は False である。`Runs` は実際の有限な Steps を要求するので空虚でない。`failures` は明示の引数で、`Assumptions` の欄や信頼条件ではない。
- `const_integer_exact` は7幅（Integer・Integer8・16・32・UnsignedInteger16・32・64）を場合分けし、ConstOK から幅付きの値を作って `c = embedConst …` を返す。`const_integer_same_value` は `.integer kind n` の単射性で同じ n に揃える。元の定数そのものの等号であり、`constOK_toApprox` の存在の読み替えではない。`integer_values` は全7幅を量化した読者である。
- `normal_shared_iff` は `ConcreteValue.type` の一致を明示の前提に持つ。
- `typed_returned_mark` は元状態と実際の escape から既存の `escape_mark` で行先の StateTyE を作り、観測の一致は呼出し側の入力である。
- `EnvRelAt.insert`・`extend`・`extendMany` と `upRen` の合成の補題は正しく、`inserted_scrutinee` は腕の変数0と照合値を越える外側の変数2を同時に読む。
- 独立評価の失敗は、二項演算・否定・標準 API の拒否の記録か、unknown から生じる（`Interval/Eval.lean` の `.failed` の出現）。したがって `TrackedFailure` の「同じ trace の rejected」は、reason ≠ unknown の失敗では通常成り立つ。Range の検査のように rejected を記録して normal の Result を返す場合があるので、trace の rejected が失敗の原因と別の演算のものである可能性は、H04 が実際の解析で確かめる点である（実行しないと分からない）。

### 5. H04 への受渡し

- 第一の候補は、同じ AbstractEnv・ConcreteEnv・EvalInput・Parameters・Failure・EvalTrace を全称で量化し、Models・同じ EvalPartial の failed・TrackedFailure から `analyze … .mayFail = true` を結論する。J04 の「同じ入力・同じ評価・同じ失敗理由に対して mayFail=true」に合う。予算に成功条件を足していない。前提の変更は見当たらない。`h04-handoff.lean` を `lake env lean -M 12288` で再実行し、終了0を確かめた。
- 候補は `#check` の命題で、公理・定理・本番の仮定としては置かれていない。未証明の部分は h04-handoff.md と results.md で太字で区別されている。第二の候補は中3。

### 6. 公理・署名・設計書・記録

- 新規5ファイルと既存の変更に `sorry`・`axiom`・`admit`・`unsafe`・`partial`・`opaque` はない。既定 import に新規5モジュールがある。既定の `lake build` は 857 jobs で成功し、変更した9モジュールに警告はない。
- 公理の監査は、新規5モジュールの公開の宣言と既存の変更の11宣言、計90対象を独自に `#print axioms` で印字した。依存は propext・Classical.choice・Quot.sound だけだった。担当の監査（10モジュール879定数と86明示対象）の一覧は改造内にあり、inventory.json の17ファイルの SHA-256 は作業木と一致した。
- signatures.md の抜き取り（`selected_primitive_step`・`termBind_success`・`connect_bind`・`connect_bind_failed`）はソースと一致した。定義の本体がないことは軽3。
- 01-12 と 07-04 の追加段落は同一で、変更の経緯の文はない。前提（WellFormed・WellTyped・CoreAssumptions、元状態だけ、σ.Valid の不使用）は各葉の実物と一致した。「構成する」は StateTyE・Step、「保持する」は残継続とストアに使われ、実物どおりである。代表の6葉の位置付けも書かれている。新しい Lean のコメントに作業 ID はない。
- 記録に手元の絶対パス、`work/`・`reference/` の参照、docs/todo へのリンクはない。改造内の記録は計114 KB で、最大は signatures.md の32 KB である。inventory.py と validate.py は改造内の一覧と json を書き出す小さな台本で、再生成の手段として妥当である。ただし実行すると改造内のファイルを書き換えるので、本レビューは実行せず、ハッシュを独自に照合した。

## 補助の入力

`<tmp>/rv-l20-n/` に置いた。

| ファイル | 内容 | 結果 |
|---|---|---|
| `leaves_check.lean`・`.out` | leaves.md の76行の葉の `#check @名前` | 終了0、欠け0、41,975 バイト |
| `leaves_meta.lean`・`.out` | 証明の値の定数を調べる試み | 取り込んだ定理の値が環境に載らず不採用。照合は `leaves_check.out` とソースの本文で行った |
| `axioms_rv.lean`・`.out`・`.time` | 新規の公開宣言と既存の変更の90対象の `#print axioms` | 終了0、3公理だけ、最大常駐量 1,660,977,152 バイト（`/usr/bin/time -l`、手元の arm64/macOS） |
| `h04.out` | `h04-handoff.lean` の再実行 | 終了0 |
| `h04_trivial.lean`・`.out` | 中3の展開と、中1の `ValueRel` の二例 | 終了0、診断なし |

## 再レビュー（再開1・2）

2026-11-02。担当の報告 `L20.n-r1-report.md`（中1で停止）・`L20.n-r2-report.md`、`plan.md` の確認点の先頭の2行（取りまとめの判断）、`l20/n/strengthening-blockers.md`、results.md の再開の節、h04-handoff.lean、validate.py・validation.json を読んだ。Lean は IntervalConnection・IntervalConnectionExamples・IntervalRelationBoundary の該当箇所を読んだ。補助の入力は `<tmp>/rv-l20-n/` に足した。

### 判定

**条件付き可**（前回の中1・中2・軽1・軽6 は閉じた。前回の中3 は定義の展開の問題が閉じたが、新しい中1 が残る。新しい所見は中1・軽3）。

条件は r1 中1 だけである。H04 の第二の候補が任意の B・op を量化し、δ と独立評価の算術の適合を仮定に持たないため、証明できない見込みが高い。署名の修正で足り、Lean の本体の変更は要らない。

### 前回の所見の処置の確認

#### 中1（閉じた）

- `ValueRel`・`ValuesRel` は相互帰納の関係になった。Unit は `.const .unit`、Boolean は同じ真偽、7幅の整数はそれぞれ同じ幅の `embedConst` の定数、構造値は同じ tag と、引数の `ValuesRel` による再帰的な関係で結ぶ。範囲エラーは欄の整数列で結ぶ。`other` は観測が `.other` で変数でない値だけを受ける。Unit と構成子、tag の違い、入れ子の引数の違いは関係しない。
- `result_tag_contrast` には、Ok と Error の取り違え・Unit と構成子の取り違え・入れ子の引数の不一致の三つの拒否と、Error の腕を飛ばして Ok の腕を選ぶ受理がある。受理の側は `result_selection_related` を通るので、実際の `firstAlt` と束縛列を関係から導いている。どちらも意味のある対照である。
- `ValueRel.of_ground` は、強い関係から観測の一致を取り出す向きに変わった。`typed_returned_mark` は `ValueRel c v` を入力に受ける。読者の `unit_escape` は `ValueRel.unit` を構成して渡している。`unitRel`・`integerRel`・`sample_relation` も構成子から作っており、仮定のまま流している読者はない。`strengthening-blockers.md` の二つの反例（`ground_signature_obstruction`・`marked_signature_obstruction`）は、同じ具体の表の下で旧署名が偽になることを示し、取りまとめの判断の根拠として足りる。
- `connect_result_arm` は、`result_selection_related` で実際の `firstAlt` と `ValuesRel selected ws` を導き、実行の入力を `branch` としてその ws について受ける。前回の「選択と実照合を別々に受ける」は解消した。
- 「`.other` が両 tag を許す Result の一意な選択」を定理にしない判断は妥当である。`ResultView.otherOk`・`otherError` は独立評価の側の過大な近似であり、後段に要るのは一意性ではない。後段に要るのは、実行の tag に合う独立評価の選択が存在することである。ただし、その選択の payload と実値の payload の関係は、`ValueRel.other` からは得られない（r1 軽1）。

#### 中2（閉じた）

`connect_arm_skip`・`connect_arm_guard_true`・`connect_arm_guard_false` は、`ArmInput` の三種類（Integer・幅・Result）について、独立評価の `skip`・`guardTrue`・`guardFalse` と、実行の `E_MatchSkip`・`E_MatchGuard`・`E_GuardT`/`E_GuardF` の Steps を、ともに結論する。`independent_arm_guards`・`independent_arm_skip` が三種類と真偽の両方に適用している。独立評価の `Miss` と実行の `firstAlt … = none`、guard の独立評価と実行の guard は、呼出し側が別々に供給する形である。results.md にそう書かれており、受け入れられる。

#### 中3（展開の問題は閉じた。r1 中1 が残る）

第二の候補は、入力の Runs の `failures` を `fun _ _ => True` とし、結論で具体の関係を要求する形になった。具体の関係は、同じ trace の拒否の事象について、`op` が選ぶ組み込みの δ が関係する実引数で err を返し、その理由が実際の理由列に入ることである。標準関数の場合は、実際の呼出しが空でない理由列で失敗することである。したがって `Runs` の展開だけでは閉じず、適合の義務が署名に現れている。

#### 軽1・軽6・その他

- 軽1: validate.py は葉の実在、`store_reply` の場合分けをたどった構成子への到達（60行）、StateTyE だけを返す16行の列挙、69・7 の計算を行う。validation.json の `constructor_evidence` は前回の本レビューの機械的な照合と一致した。StateTyE だけを返す16行の行先の照合は台本の対象外だが、前回の確認で済んでいる。
- 軽6: `concrete_interval_control` は、`code` から五つの実遷移（E_Let・E_Return・E_Let・E_Return・E_EscMark）で到達する同じ終状態に、`EndState` と `StateTyE` を持つ形になった。型付けは別の元状態から作った葉の結論を使うが、同じ状態についての主張になっている。
- `_unsafe_rec`: `firstResultAlt` を `List.foldr` で定義し直し、コンパイラが生成する定数をなくした。監査の例外は ClosureTyping の既存の2件のままである。計算の意味は `result_selection_first` で独立評価の選択と結ばれているので、書き直しは妥当である。
- 新規・変更の Lean に `sorry`・`axiom`・`admit`・`unsafe`・`partial`・`opaque` はない。IntervalRelationBoundary は既定 import にある。既定の `lake build` は 858 jobs で成功した。公開の106宣言を独自に `#print axioms` で印字し、依存は propext・Classical.choice・Quot.sound だけだった。`h04-handoff.lean` も終了0だった。

### 新しい所見

#### r1 中1: H04 の第二の候補は任意の B・op を量化し、δ と独立評価の算術の適合を仮定に持たないので、証明できない見込みが高い（机上の反例。Lean では再現していない）

- 場所: `l20/n/h04-handoff.lean` 18〜41行、h04-handoff.md の「実行の結論」の行。
- 問題点: 仮定は EnvRelAt・code の等号・EvalPartial の failed・TrackedFailure・実行の失敗だけで、B と op について何も仮定しない（CoreAssumptions も、op が選ぶ組み込みの δ と独立評価の算術の対応もない）。机上の反例は次のとおりである。独立評価の環境を x=1・y=min64 とし、`neg x + neg y` の形の式を考える。独立評価では、左の neg は正常、右の neg は overflow で拒否され、trace の拒否の事象は右の neg だけになる。B の δ は、neg が引数 1 のときだけ err を返し、min64 では値を返すように選ぶ。実行は左の neg で失敗するので、仮定の Runs は成り立つ。結論は「右の事象の引数 min64 で δ が err を返す」ことを要求するので偽である。左から評価する脱糖と、op の選び方を確かめていないので、Lean での再現は未確認である。
- 修正案: op が選ぶ組み込みの δ が、関係する引数で独立評価の算術と同じ成否を返すことを、明示の前提として加える（例えば `∀ event ∈ trace, …` の適合の述語。実際の表での充足は L40/L50 が示す）。あるいは結論を、実行が最初に失敗した位置の事象に限る形へ改める。H04 は最初にこの反例を Lean で再現してから署名を決める。主な定理の前提を変える必要は見当たらない。

#### r1 軽1: 未同定の Result（`other`）の腕では、payload の関係を得る入口がない（読めば確定。後段への申し送り）

- 場所: `IntervalConnection.lean` の `ValueRel.other`、results.md の再開の節「otherOk/otherError の同じ腕の一意な選択」の行。
- 問題点: results.md は、残る点を「一意な選択」として書いている。後段（L70 の、実行から独立評価を作る向き）に要るのは、実行の tag に合う `otherOk`/`otherError` の選択と、その payload が実値の payload と関係することである。`ValueRel.other` は実値の構造を何も持たないので、この腕の束縛列の `ValuesRel` は得られない。H04 の局所の合成には影響しない。
- 修正案: results.md の行を「一意性は要らない。要るのは実行の tag に合う選択の存在と payload の関係で、`other` の値からは得られない。L70 が実値から独立評価の値を構成するときに扱う」に改める。

#### r1 軽2: `ValueRel.con` は所有元と型引数を結ばないが、例の docstring は「所有元」を渡すと書く（読めば確定）

- 場所: `IntervalConnection.lean` の `ValueRel.con`（`owner`・`types` と実値の `ts` を結ばない）、`IntervalConnectionExamples.lean` の `result_arm` の docstring「所有元・tag・payload を同じ選択へ渡す」。
- 問題点: tag と引数の関係は正しいが、所有元は関係に含まれない。docstring は実物より強い。
- 修正案: docstring を「tag と payload」に改める。所有元の照合が後段で要るなら、その段の担当として記録する。

#### r1 軽3: `ValueRel.of_ground` の名前が中身に合わない（読めば確定）

- 場所: `IntervalConnection.lean` 94行。
- 問題点: Ground を受けなくなり、強い関係から観測の一致を返す補題になったが、名前が旧のままである。読者が旧の向き（近似から関係を作る）と誤読しやすい。
- 修正案: `ValueRel.toApprox_eq` などへ改名し、signatures.md・設計書の写しの参照を同じ変更で直す。

### 補助の入力（追加）

| ファイル | 内容 | 結果 |
|---|---|---|
| `axioms_r2.lean`・`.out`・`.time` | 再開2の新規・変更モジュールの公開の106宣言の `#print axioms` | 終了0、3公理だけ、最大常駐量 1,662,058,496 バイト（`/usr/bin/time -l`、手元の arm64/macOS） |
| `h04_r2.out` | 再開2の `h04-handoff.lean` の再実行 | 終了0 |

## 取りまとめの追記

2026-11-02。初回の中1は内部署名の変更を承認して閉じ（`plan.md`）、中2・中3と軽1〜7を再開2で処置した。再レビューの中1は、旧候補の偽を `h04-counterexample.lean` で再現し、候補の結論を最初に失敗した位置の事象に限って閉じた（`plan.md`）。軽1〜3は再開3で処置した。再開3の処置は H04 の候補の署名と記録・名前だけなので、局所の再レビューは行わない。処置の後の作業末の work は成功した。
