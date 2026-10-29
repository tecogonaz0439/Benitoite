# L40.2 の結果: Scope の局所状態・規則の表・予算と忘却

2026-10-28。plan-l10-l50「L40」の表の L40.2 の行を、取りまとめが用意した作業用のディレクトリ（`<wt>`、ブランチ `m013/l40.2`）で行った。担当は Claude のサブエージェントである。git の状態は変えていない（コミットは取りまとめが行う）。

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | L40.2（Scope の局所状態・規則の表・予算と忘却） |
| B_WORK | `d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea`（L20.4 の取り込みの後の本線） |
| 閉じた範囲 | L00.05 の形を本番の値 `Release.Val` と `Scope.Domain` の範囲・被覆で具体化した定義（事実と値の対応、検査・射影・拡大の六つの規則、出現の同定の表、一段・多段の評価）。各規則の `RuleSound`、表と適用の健全性、必須の判定が Range の成分と予算を読まないこと、`apiAt` に利用者の関数が入らないこと。必須の判定の予算（Range の警告の予算と別の状態、上限は引数、計上点・保持の数え方・忘却の費用・超過の理由）と、超過で Top を返すことの健全性。01-12 の新しい二節と 07-04 の行 |
| 未完 | なし（計画の行の範囲で）。表層の構文からの対応・番号の新規性の不変条件は L40.3、型の制約への接続は L40.4 |
| 適用した前提の変更の行 | なし。本番の型付け・主定理・`Builtins.Assumptions`・既存の Lean のファイルは変えていない |
| 停止条件 | 該当なし |

## 変更と接続

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Surface/ScopeState.lean` | 新規。名前空間 `Benitoite.Surface.ScopeState`。`Scope.Inference`・`Scope.RangeCover`・`Interval.Budget`・`Release.Lemmas.Membership` を import する |
| `formal/Benitoite/Surface/ScopeStateExamples.lean` | 新規。名前空間 `Benitoite.Surface.ScopeStateExamples`。小例と `#guard` |
| `formal/Benitoite.lean` | 既定の import の末尾に上の二つを加えた |
| `docs/design/01-spec/01-12-core-calculus.md` | 「操作の対象の範囲の領域と被覆」の後に「Scope の局所解析の状態と規則の表」「Scope の局所解析の予算と忘却」の二節を加えた（区間解析の節と同じ【決定】・写し・定理の表・独立例の構成）。` ```text ` のブロックは加えていない |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」の「操作の対象の範囲の領域と被覆」の行の後に、二節に対応する行を加えた（「Rust は未接続」） |
| `l40.2/` | 本書と生のログ |

import の範囲: 新しいモジュールが推移的に読む区間解析のモジュールは `Interval.BindingScope`・`Interval.Identity`・`Interval.Budget`・`Interval.Domain` だけであり（import の行を辿って確かめた）、`Interval.RangeState`・`Interval.Eval`・警告の解析（`Flow`・`Analyze`・`Sound`・`Budget*` の走査）は読まない。`RangeState` は変えていない（印 RS 0）。`Interval.Budget` は超過の補足の型 `LimitFailure` と、分離の言明に使う区間解析の予算の状態の型のためだけに読む。

見出しの参照: 新しい見出し「Scope の局所解析の状態と規則の表」「Scope の局所解析の予算と忘却」を `git grep` で探し、参照は新しいモジュールの先頭のコメントだけであることを確かめた。

## 置いた定義と定理

すべて `formal/Benitoite/Surface/ScopeState.lean`、名前空間 `Benitoite.Surface.ScopeState`（`open Benitoite.Scope.Inference`、`Scope.Domain` からは `Range`・`Target`・`Kind` だけを開く）。theorem は 55件（ほかに private の補題 1件）。未証明の theorem と `sorry` はない。

| 群 | 定義 | 定理 |
|---|---|---|
| 値と事実の対応 | `Locals`、`okPayload`（`Result.Ok` の成功値を構成子の名前で読む）、`CheckedModels`（`.checked t` で種類が合い由来の添字に属する）、`ResultModels`、`Parsers`（文字列の解析。形式化の外側）、`factModel`、`models` | `checkedModels_iff`、`models_fact`、`models_lit`、`checkedModels_hasTypeV`（V-Checked で範囲付きの値型を持つ） |
| 必須の判定 | `argIndex`（抽象の引数の添字。再照合つき） | `argIndex_readLocal`、`argIndex_sound`、`requiredIndex_checked`、`requiredIndex_hasTypeV` |
| 検査の規則 | `CheckSpec`、`CheckSpec.BoundSound`、`CheckSpec.Contract`（案 A の δ の契約）、`checkRule`、`checkDelta`（具体の δ）、`pathCheck`（`Scope.checkPathIn`）、`requestCheck`（`Http.checkRequestIn`） | `checkRule_sound`、`checkRule_index_agrees`、`checkDelta_contract`、`checkDelta_ok_mem`、`checkDelta_known_redundant`、`pathCheck_boundSound`、`requestCheck_unknown_boundSound` |
| 射影と拡大の規則 | `projectRule`（`Scope.pathInValue`・`Http.requestInValue`）、`pathValueRun`、`widenRun`、`widenRule`（`Scope.widenPathIn`・`Http.widenRequestIn`） | `projectRule_sound`、`widenRule_sound`、`widenRun_same`、`widenRun_memK`、`widenRun_hasTypeV` |
| 表 | `Owner`、`Resolved`、`standardTable`、宣言の名前 6、`ruleDeclarations`、`Rules`、`Rules.lookup`、`Rules.Sound`、`Boundary`（形式化の外側の関数と Result の表し方）、`Boundary.rules`、`Boundary.models` | `standardTable_apiAt`、`standardTable_user_ruleAt`、`standardTable_user`、`Rules.lookup_mem`、`Rules.lookup_sound`、`standardTable_apply_sound`、`Boundary.rules_sound` |
| 一段 | `Arg`、`absArg`、`EvalArg`、`EvalArgs`、`Step`（`call`・`okArm`・`alias`・`unknown`・`join`）、`StepEval`、`absStep`、`absSteps`、`StepsEval` | `absArgs_models`、`absStep_sound`、`absSteps_sound` |
| 予算 | `LimitFailure`（`Interval.Budget.LimitFailure` の別名）、`Cap`、`Limits`（既定値なし）、`Budget`、`Budget.initial`、`heldItems`、`readCost`、`argCost`、`stepCost`、`Budget.admit`、`Budget.Within`、`Budget.enter`、`Budget.leave` | `Budget.admit_ok`、`Budget.admit_error`、`Budget.enter_whole`、`Budget.leave_whole`、`Budget.leave_body` |
| 忘却と超過 | `blindStep`、`Run`（`running`・`stopped`）、`Run.state`、`Run.budget`、`ExceedReason.budgetExceeded`、`Run.exceeded`、`Run.step`、`Run.steps`、`Run.enter`、`Run.leave`、`NoFacts`、`Run.Good` | `noFacts_forgetAll`、`noFacts_empty`、`noFacts_blindStep`、`noFacts_requiredIndex`、`Run.step_good`、`Run.steps_good`、`Run.enter_good`、`Run.leave_good`、`Run.exceeded_requiredIndex`、`Run.steps_stopped`、`Run.steps_running`、`blindStep_models`、`Run.step_models`、`Run.steps_models`、`Run.enter_models`、`Run.leave_models`、`Run.leave_exceeded` |
| Range との分離 | `Analyses`（Range の事実と予算、Scope の `Run`）、`Analyses.toLocalState`、`Analyses.stepScope`、`Analyses.chargeRange` | `Analyses.toLocalState_toScope`、`Analyses.required_range_independent`、`Analyses.stepScope_separate`、`Analyses.chargeRange_scope`、`Analyses.localState_range_independent` |

計画の言明との対応:

- 検査・射影・拡大の `RuleSound` と `apply_sound`: `checkRule_sound`・`projectRule_sound`・`widenRule_sound`、`Rules.lookup_sound`・`standardTable_apply_sound`・`Boundary.rules_sound`。射影と拡大は事実を作らないので `RuleSound` は自明であり、拡大の内容（同じ値、被覆による所属と型の保存）は `widenRun_same`・`widenRun_memK`・`widenRun_hasTypeV` が示す。
- 必須の判定が Range の成分を読まないこと: `Analyses.required_range_independent`・`Analyses.stepScope_separate`・`Analyses.localState_range_independent`（構成で成り立ち、`rfl` で閉じる）。
- `apiAt` に利用者の関数が入らないこと: `standardTable_apiAt`（返す宣言は標準の所有元に解決したもの）と `standardTable_user`（利用者のモジュールに解決した出現は同じ綴りでも規則を持たない）。
- 予算と忘却（問24 の 1〜5、DET-08）: 1 は `Budget` を区間解析の `Interval.Budget.State` と別の型にし、`Analyses.chargeRange_scope` などで互いに影響しないことを示した。2 は `stepCost`・`heldItems`（事実を持つ位置ごとに一項、由来は事実に含める）。3 は `Limits` に既定値を置かず全ての定理を任意の上限で述べた。4 は `ExceedReason.budgetExceeded` と補足 `LimitFailure`（本体か全体か、操作数か保持数か）。5 は忘却を `forgetAll`（位置を保ち事実だけを消す）とし、費用を事実を持つ位置の数にした。
- 超過で Top を返すことの健全性: `Run.steps_models`（上限の値によらず対応を保つ）と `Run.exceeded_requiredIndex`（止まった状態の必須の判定は全ての位置で Top）。精度については `Run.steps_running`（上限内で終われば予算のない解析と同じ状態）。

## 確かめた例

`formal/Benitoite/Surface/ScopeStateExamples.lean`（theorem 9件、`#guard` 33件）。大きな `decide` は使っていない（`#guard` と、4段以内の抽象の計算の小さな `decide`、具体の δ の `rfl` だけ）。

- 規則の表と必須の判定: `/data/**` のリテラルによる直接の検査の Result の由来、同じ `Ok` 値（番号 2）の添字が `/data/**` であること、元の引数が Top のままであること、射影と拡大が選ぶ範囲が引数の必須の判定と同じであること、検査へ渡す範囲が由来の添字と同じであること、射影と拡大の結果が由来を持たないこと。`table_sound`（例の表の健全性を `Boundary.rules_sound` から得る）、`check_checked`（具体の評価で得た位置 0 の値は `/data/**` に属する検査済みの対象の値）。
- 精度を失う境界: 未知のパターン、別名、再包装、合流（位置の数は保つ）、同じ綴りの利用者の関数（`user_not_identified`）、番号の食い違いで Top。
- δ: `delta_ok`（範囲内の対象で `Ok (.checked t)`）、`delta_outside`（範囲外で `Ok` なし）、`delta_top_same`（Top で具体化しても同じ成功値）、`widen_root`（`/data/**` から `/**` へ同じ値を返し、`PathIn["/**"]` の型を持つ）、`widen_not_covered`（`/database/**` へは値を返さない）。
- 予算: 上限内で予算のない解析と同じ結果、計上の操作数（直接の検査 3、`Ok` の腕 2、忘却 2）、本体・全体の操作数と保持数の超過の理由、超過の後の Top と位置の数、拒否した計上で予算が変わらないこと、内側の本体の全体の保持数の超過が外側へ及び、本体の操作数の超過が及ばないこと。`budgeted_sound`（任意の上限で具体の評価に対応する）。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 最初の全体のビルド（基準の生成物を作り直す。新しいファイルなし） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。434ジョブ | 171.62 秒（排他の待ち 0 秒） | [lake-build-first.log](lake-build-first.log) |
| 局所の単一ファイル（途中、5回） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Surface/ScopeState.lean` | 1・2回目が 1（下の「失敗と修正」）、3回目以降 0（出力なし） | 各 1〜11 秒 | 本書 |
| モジュールのビルド（小例の検査のため） | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ> Benitoite.Surface.ScopeState` | 0 | 0.98 秒 | [lake-build-module.log](lake-build-module.log) |
| 小例の単一ファイル（2回。2回目は意図して失敗する `#guard` を一時ファイルに足し、検査が走ることを確かめた） | `cd <wt>/formal && lake env lean -M 12288 Benitoite/Surface/ScopeStateExamples.lean` | 0（一時ファイルは意図した `#guard` の失敗だけ） | 各 1 秒未満 | 本書 |
| 作業末の全体のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <ログ>` | 0。436ジョブ、`Built Benitoite.Surface.ScopeState`・`ScopeStateExamples`、`Build completed successfully`。`sorry` の出現 0、新しいファイルの警告なし | 2.51 秒（排他の待ち 63 秒を別に要した） | [lake-build.log](lake-build.log) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <一時ファイル>/axioms.lean`（新しい theorem 64件と旧の主定理 7件、計 71件） | 0 | 0.62 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |
| work の dry-run | `cd <wt> && scripts/check.sh --level work --base d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea --dry-run` | 0。選択は `spec_tally`・`spec_examples`（01-12 の変更による）と `formal_build`（`formal/Benitoite.lean` の変更による）。plan-l10-l50「work の割り当て」の見込み（01-12 か 07-04 を変えた枝）と一致 | 数秒 | [work-check-dry-run.log](work-check-dry-run.log) |
| work | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base d95f76181f7a6f52a6df6ef1b1a7982b1ef73cea` | 0。`spec_tally` の自己検査と集計、`spec_examples` 7件成功、`formal_build` 成功、`selected checks passed` | 9.84 秒 | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |

公理: 71件とも `propext`・`Classical.choice`・`Quot.sound` の部分集合だけに依存する（三つ全て 11、`propext`・`Quot.sound` 27、`propext` だけ 27、依存なし 6）。`sorryAx` と独自の公理はない。旧の主定理は `progress`・`preservation`・`effect_soundness`・`effect_soundness_noLamNames`・`step_sound`・`desugar_typed`・`surface_effect_soundness` である（変えていないことの確かめ）。`Interval` の既存の定理は、ファイルを変えずに全体のビルドで通った（点検のみ）。

Rust の lib 全件・clippy・fmt は選ばれず、加えていない。`scripts/check-formal.sh` は実行していない（K10 と最終の関係状態の担当）。

## 最大常駐量

`/usr/bin/time -l`（macOS）の `maximum resident set size` の原値（バイト）。一度に一つの検査だけを走らせた。

| 実行 | 原値 | MiB | GiB |
|---|---:|---:|---:|
| 最初の全体のビルド（基準の生成物を作り直した。並行するジョブの中で最大のプロセスの値） | 2648768512 | 2526.1 | 2.47 |
| 作業末の全体のビルド（新しい二つのモジュールだけを作った） | 1518059520 | 1447.7 | 1.41 |
| work の検査全体（`spec_examples` の cargo、`spec_tally`、ビルド済みの `formal_build` を含む一括の値） | 1383628800 | 1319.5 | 1.29 |
| 公理の確かめ（`import Benitoite` の全体を読む単一ファイル） | 1508245504 | 1438.4 | 1.40 |

work の値は一括の実行の中で最大のプロセスの値であり、どのプロセスかは `time` から分からない。局所の単一ファイルは計時していない。`-M 12288` は変えていない。

## 失敗と修正

- 局所の検査の1回目が終了1。(1) `Release.Val` の `match v, h with | .checked t, h => …` が三か所で `maximum recursion depth` になった（相互帰納の値の型の場合分けの展開）。`unfold CheckedModels at h; split at h` で示す補題 `checkedModels_iff` を置き、各所はこれを使う形に直した。(2) `requiredIndex_checked` の言明の `∃ o t` の型を推論できなかった。`(o : Origin) (t : Target)` と書いた。(3) `checkDelta_contract` で `okPayload` を展開した後の `if True` が残った。`ite_true` を `simp only` に足した。`if_pos`・`if_neg` の非推奨の警告は `ite_eq_left`・`ite_eq_right` に改めた。
- 2回目が終了1。(1) `Rules.lookup_mem`・`Rules.lookup_sound` の `repeat split` と `simp_all` が、文字列の等号の決定で heartbeats の上限を超えた。宣言の名前ごとの `by_cases` と `ite_eq_left`・`ite_eq_right` の書き換えに直した。(2) `NoFacts` の量化の変数の型を推論できなかった（`GetElem?` の型クラスの問題）。`(i : Nat) (f : ScopeFact)` と書いた。
- 3回目以降は終了0。`Run.steps_running` の `(f := by assumption)` を `next f _ =>` で名前を付ける形に整えた後も終了0。小例のファイルは最初から終了0だった。
- 作業末の全体のビルド・公理・work は最後の状態で一度ずつ走らせた。

## ずれと申し送り

### 計画からのずれ

1. 新しいファイルを二つにした。本体（`Surface/ScopeState.lean`）と小例（`Surface/ScopeStateExamples.lean`）を分け、本体に例の解析器と表を置かないようにした。
2. 一段の言語（`Arg`・`Step`・`StepEval`・`absStep`）の本番の値の版を L40.2 に置いた。計上点（問24 の 2）を定めるのに一段が要り、L40.3 の行が「`call`・`okArm`・`alias`・`unknown` へ対応させる」と、この構成子を前提にしているためである。表層の構文からの対応・入口・合流の位置・番号の新規性の不変条件は置いていない（L40.3）。
3. 名前空間は `Benitoite.Surface.ScopeState` とした。採用定義の名前（`ScopeState.empty` など）と同じ最後の成分の宣言を本名前空間の直下に置くと名前の解決で前に来るので、`empty`・`extend`・`forgetAll`・`readLocal`・`requiredIndex`・`Models` などの名前の宣言を直下に置いていない。
4. `Http.checkRequestIn` の型検査器の範囲の読み取り（`requestCheck` の `bound`）は引数にし、その健全性を `Boundary.rules_sound` の条件にした。採用定義の抽象の引数のリテラル `AbsArg.lit` は文字列だけを持ち、本番の対応 `models` はリテラルを文字列の定数に対応させるので、整数のポートのリテラルを既知にする読み取りを置けなかったためである（常に未知を返す読み取りの健全性だけを示した）。
5. 条件の射影（`ScopeFact.pattern`）を作る規則は置いていない（問22 で初段に加えない）。事実の対応 `factModel` には採用定義の構成子として `pattern` の場合を置いた。

### L40.3 への申し送り

6. 表層の直接の標準呼び出し・一度の保存・`case Result.Ok`・別名・未知の呼び出しを `Step` の構成子へ、引数を `Arg` へ写す。`const` の直接参照は `Arg.lit` へ写す想定で、`pathCheck` はリテラルだけを既知にする。射影の結果を局所に保存してから渡す場合は `Arg.loc` になり既知にならない（問24 の 7。`#guard` で確かめたのは局所の文字列の場合）。
7. 整数のリテラルの扱い（上の 4）を決める必要がある。`Http.checkRequestIn` の端点を既知にするには、`models` の `lit` の対応か `AbsArg` の読み取りの側で整数のリテラルを表す方法が要る。採用定義の `AbsArg` を変えずに済む形（`Boundary.requestBound` と、その `BoundSound` の証明）を推す。
8. 本体の入口・出口は `Run.enter`・`Run.leave` を使う。全体の上限の超過は内側にも外側にも及び、本体の上限の超過は及ばない（`Run.leave_exceeded`）。番号の新規性の不変条件（`BindingScope.fresh_valid`）は `Run` の状態に載せていない。

### L40.4・L40.5・L40.6 への申し送り

9. L40.4: 必須の判定の添字は `ScopeState.requiredIndex`（`Run.state` の上）、超過の理由は `Run.exceeded`（`ExceedReason.budgetExceeded` と補足 `LimitFailure`）で得る。DET-05 の残りの理由（`notCovered`・`atomicCoverOnly`・`unknownSource`）の列挙は置いていない。明示拡大の規則の `index` は元の範囲 R だけを返し、行き先 S は戻り値の注釈から型検査器が決める（`widenRun` は [R, S] の二つを受け取る）。
10. L40.5: `checkRule_index_agrees` が本番の値の上の `checkRule_index_agrees` である。本書の検査の δ（`checkDelta`）は局所解析の規則の δ であり、L20.7 の署名の表の項目の δ ではない。両者をつなぐには、表の項目の δ が `CheckSpec.Contract` を満たすことを示す形を推す。
11. L40.6: 接続定理の材料は `requiredIndex_checked`・`requiredIndex_hasTypeV`（必須の判定の添字が本番の値の型付けで値に付く）、`checkedModels_hasTypeV`、`checkDelta_ok_mem`（δ だけから所属）、`widenRun_hasTypeV` である。

### L40.7・L40.8

12. plan-l10-l50 の L40 は L40.6 までであり、L40.7・L40.8 の行はない。申し送りはない。

### L20.7・R30 と取りまとめへ

13. 値の形 `Val.checked (t : Target)` は対象だけを持ち、`Http.RequestIn` の値が検査した同じ要求を保持すること（判断 7）を値の形で表さない。そのため `Http.requestInValue` の δ は値から要求を取り出せず、本書では射影の δ を任意の関数（`Boundary.requestValueRun`）とした。L20.7 の表の項目と R30 の実装で、要求を保持する値の表し方と、この射影の δ をどう扱うかを決める必要がある（本書で確かめたのは Lean の値の形の字面だけである）。

### R20 への申し送り

14. 上限の値は `Limits` の引数であり、既定値を置いていない。R20 の測定で本体と全体の操作数・保持数の値を決める。
15. 計上点は `stepCost` の表（呼び出しの同定 1・引数の読み取り 1・再照合 1・射影の適用 1・事実の書き込み 1・`Ok` の腕の読み取り 1・由来の写し 1・別名 1・忘却は事実を持つ位置の数）。型検査器が必須の判定を問い合わせるときの再照合は計上していない（局所の読み取りの再照合だけを数える）。報告の順は操作数を保持数より先に、本体を全体より先にした。Rust の実装はこの順と数え方に合わせるか、違えるなら Lean の側を直す必要がある。

### UB20・K10 への申し送り

16. `standardTable` は、出現の解決 `resolve` が所有元を正しく返すことを前提にする（解決は形式化の外側）。同じ綴りの利用者の関数を利用者のモジュールに解決することは、UB20 の解決器の点検と K10 の照合で確かめる。
17. K10（と L50.2）: 範囲の Lean の側の独立入力のうち、忘却と予算の停止は本書の `Run` と小例の値（操作数 3・2・2、超過の理由）を使える見込みである（確かめていない）。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 01:57 ごろ（JST、依頼文を読み始めた時刻。記録の最初の時刻は 02:07） |
| 終了 | 02:22 ごろ（本書の作成まで） |
| 外側の所要 | 約25分 |
| 能動時間 | 約21分（文書と既存の定義を読む約10分、定義と証明約5分、小例約2分、設計書約2分、本書約2分。ビルドと検査の待ちを除く） |
| ビルドの回数と時間 | 全体のビルド 2回（171.62 秒、2.51 秒）、モジュールのビルド 1回 0.98 秒、局所の単一ファイル 約9回（各 1〜11 秒）、公理の確かめ 1回 0.62 秒 |
| 検査 | work 1回 9.84 秒（dry-run 数秒） |
| 待ち | 排他の道具の待ち 63 秒（作業末のビルド。ほかの担当のビルドと見られる）。設計者の回答待ちなし |
| 見込みとの比較 | 見込み 0.6〜5時間の下端を下回った。上端の2倍（10時間）を超えていない |
