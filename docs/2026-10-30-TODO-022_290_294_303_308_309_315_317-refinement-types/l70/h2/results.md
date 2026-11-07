# L70 群 H2 の結果

担当: Claude（Opus 5.5）。作業ブランチ `m014/l70.h`。B_WORK `698f2350b9f9adff5a10dc2038dec87b8f2b8978`（作業の開始時に HEAD と一致することを確かめた）、段の開始版 B_STAGE `657b3ae713040e78826d2f19cd7b8ac9f415a6d6`。旧の言明と証明は `git show <B_STAGE>:<ファイル>` で読んだ。

群 H の段の照合（[../h/legacy.md](../h/legacy.md)）が「失った保証」とした31行（重い18・軽い13）を、篩付きの核と表層の上で述べ直した。重い18行は全て述べ直し、軽い13行のうち9行を述べ直した。新しい公理・`sorry`・既定 import からの除外はなく、既存の言明と規則は変えていない（変えた Lean のファイルは行を足しただけである。照合は [../verify.py](../verify.py) の第1節）。旧の保証が篩付きの規則の下で成り立たない例は見つからなかった。

## 時刻

外側の時間（`date` の読み）である。能動時間と待ち時間は分けていない。

| 単位 | 開始 | 終了 |
|---|---|---|
| 読む（依頼文・共通依頼文・legacy.md・旧の言明） | 2026-11-07 19:30 | 19:40 |
| 1. 構築器の一歩の通常セルと事象の性質 | 19:40 | 19:43 |
| 2. 補間の部分の判定の完全性 | 19:43 | 19:44 |
| 3. Scope の局所解析の接続 | 19:44 | 20:05 |
| 4. 例（表層の main からの IO の事象への到達） | 20:05 | 20:16 |
| 4の追加（取りまとめの指示）: Log・型付きの失敗・脱糖の番号の例 | 20:16 | 20:22 |
| 4の追加（取りまとめの判断 3）: 観測を持つ main の例と誤った規則の反例 | 20:42 | 20:47 |
| 5. 記録と文書、既定ビルド・公理監査・照合 | 20:22 | 20:41 |

見込み（構築器 1〜2時間、補間 1〜2時間、Scope 4〜10時間、例 1〜2時間）はどれも下回った。6時間ごとの途中の報告の区切りには達していない。

## 足した・変えたモジュール

| モジュール | 状態 | 内容 |
|---|---|---|
| `Release.Refinement.BuilderStore` | 足した | 構築器の一歩・捕捉・再開・保存継続の破棄とストアのセル |
| `Release.Refinement.HandlerStoreExamples` | 変えた（末尾に足した） | 上の定理の具体の状態での適用例3つ |
| `Release.Refinement.Surface.CheckSupport` | 変えた（足した） | `interpAllowed_complete`・`interpAllowed_spec` と適用例 |
| `Release.Refinement.Surface.ScopeEval` | 足した | 局所解析の一段の具体の評価と健全性 |
| `Release.Refinement.Surface.ScopeReach` | 足した | 表層の具体の評価（到達）と局所解析の健全性、出現の番号の一致 |
| `Release.Refinement.Surface.ScopeConnection` | 足した | 出現の受理と接続定理 |
| `Release.Refinement.Surface.ScopeConnectionExamples` | 足した | 接続定理の具体の適用例 |
| `Release.Refinement.SurfaceTargetReachExamples` | 足した | 表層の対象健全性の前提を満たし IO の事象へ到達する main |
| `Release.Refinement.SurfaceTargetObservedExamples` | 足した | 観測を持つ読取りの事象へ到達する main と、誤った規則の反例 |
| `Release.Refinement.Surface.LogExamples` | 足した | Log の操作の検査器の受理と拒否 |
| `Release.Refinement.Surface.FailureExamples` | 足した | 型付きの失敗の検査器の受理と拒否 |
| `Release.Refinement.FailureExamples` | 足した | Result の変換の四つの有限遷移 |
| `Release.Refinement.Surface.BuilderExamples` | 足した | 構築器の脱糖の番号 |

足した11モジュールは全て既定 import（`formal/Benitoite.lean`）に入れた。一覧は [changes.json](changes.json)。

## 旧の行ごとの記録

旧の名前は [../h/legacy.md](../h/legacy.md) の「失った」の31行である。完全名は接頭辞 `Benitoite.Release.Refinement.` を省く（`R.` と書く）。

| 旧の名前 | 重さ | 述べ直した定理の完全名、又は述べ直さない理由 | 旧との違い |
|---|---|---|---|
| `OrdinaryStoreEq` | 軽い | `R.OrdinaryStoreEq`（関係。`refl`・`set_nonval` と、`builder_new_frame`・`builder_update_frame`） | 旧の `symm`・`trans` は読者がないので置いていない |
| `builder_step_no_event` | 重い | `R.builder_step_no_event` | 旧は計算項そのものを状態に持った。篩付きの核の状態は閉包を持つので、専用項の判定は閉包の view（`q.view.IsBuilder`）で述べる |
| `builder_step_frame` | 重い | `R.builder_step_frame` | 同上。後続の状態の四つの形（run・error・exit・matchRun）のストアについて述べる |
| `capture_builder_cell` | 重い | `R.capture_builder_cell` | 篩付きの状態の型付け `StoreOk P B σ Ψ μ` は起点の環境 σ を持つ。広げたストア型の下での `BuilderCellOk` は、篩付きの型付けのストアの拡張（`CellOk.store`）が値の信頼条件 `B.ValueAssumptions P` を要るので、それを前提に足した（主定理の `CoreAssumptions` から得られる。具体の表 `HandlerStoreExamples` の `model_core.values` で適用した）。ストア型の更新は `StoreTy.put` |
| `resume_builder_cell` | 重い | `R.resume_builder_cell` | 起点の環境 σ を持つ `StoreOk` で述べる。ほかは同じ |
| `BuilderOnlyFrames` | 軽い | `R.BuilderOnlyFrames` | 同じ |
| `builder_frames_releases_nil` | 軽い | `R.builder_frames_releases_nil` | 同じ |
| `drop_local_silent` | 重い | `R.drop_local_silent`（と `R.drop_local_frame`） | 値を返す状態を閉包の view（`q.view = .ret v`）で述べ、後続の状態は `Closure.pure (.ret v)` を持つ。前提 `releases saved = []` は旧と同じ。旧の escape・error・exit の版は legacy.md の31行に入っていないので置いていない |
| `dedicated_lowering` | 軽い | `R.Surface.BuilderExamples.dedicated_lowering` | 同じ本体と、旧と同じ期待の核の項（独立に書いた）で照合する |
| `scope_check_connection` | 重い | `R.Surface.ScopeSound.scope_check_connection`（系 `scope_check_connection_at`・`accepted_check_connection`） | 前提の「本体の受理と出現の所属」を「出現の受理」（`OccurrenceAccepted`）に弱めた（本体の受理から `OccurrenceAccepted.of_body` で得る）。結論の範囲 S は、旧の「`rs[0]? = some S` なる全ての S」と別の定理 `scope_check_range` の存在を合わせ、`∃ S, rs[0]? = some S ∧ …` とした |
| `scope_local_connection` | 重い | `R.Surface.ScopeSound.scope_local_connection`（系 `scope_local_connection_at`） | 前提は同上。旧の前提 `rs[0]? = some S` を外し、S の存在を結論にした |
| `scope_local_typed` | 重い | `R.Surface.ScopeSound.scope_local_typed` | 篩付きの核の型付け V_Checked は名前が内容型を持たないこと、V_CheckedRequest は内容型・`groundVal`・`reqTarget` を要るので、値の形と内容の前提をその形で書いた（旧の前提 `hc` に当たる）。型は `scoped name kd (fixed (absolute S))`。値の型付けから前提を得る旧の系 `scope_local_typed_of_typed` は31行に入っていないので置いていない |
| `scope_check_core` | 重い | `R.Surface.ScopeSound.scope_check_core` | 規則の実行は、核の E_Prim と同じく正規化した型引数と効果引数で δ を呼ぶ `deltaRunAt`。核の状態は閉包を持つので、`q.view` が組み込みの呼び出しである状態について E_Prim を結論する。脱糖の等式に加え、直接の頭の脱糖（`directCallee`）も結論に入れた |
| `http_check_connection` | 重い | `R.Surface.ScopeSound.http_check_connection` | 篩付きの本番の規則の表（`productionRules pathTable host`。Ok の構成子の名前が `"Result.Error"` と異なる全ての ok）で述べる。成功値は `checkedRequest (endpoint t) req` |
| `reachAt_occurrences` | 軽い | `R.Surface.ScopeLower.reachAt_occurrences` | 旧は `ReachBlock` と `ReachAtBlock` の二つの帰納の関係を持った。右辺を添字に持つ `ReachAtBlock` だけを帰納の関係にし、`ReachBlock` をその存在で定義した |
| `main_reach` | 軽い | `R.Surface.TargetReachExamples.main_reach`、`R.Surface.TargetObservedExamples.main_observed` | 旧の例の main は Result の照合と `File.writeTextIn` を持ち、観測は `/data/a.txt` だった。`main_reach` の main は `print("hi")` を呼び、観測は空である。`main_observed` の main は Top のパスの読取り `File.readText("/data/a.txt")` を呼び効果 `{File.Read}` を宣言し、観測 `/data/a.txt` を持つ事象へ到達し、その観測を宣言した効果が許す。範囲付きの書き込みと Result の照合は使わない |
| `wrong_rule_unsound` | 軽い | `R.Surface.TargetObservedExamples.wrong_rule_unsound`（`narrow_rejected`） | 旧の反例は、節の添字の許容（`ClauseIxOk`）を外した誤った規則を使った。新しい反例は、効果の名前だけを照合して範囲を照合しない誤った包含（`NameOnlyCovers`）を使う。誤った規則は `/etc/passwd` を読む main を効果 `{File.Read["/data/**"]}` で受け入れ（本番の型付けで得た効果 `{File.Read}` をこの包含で広げる `WrongTyped`）、開始状態から到達した読取りの事象は上限の許さない `/etc/passwd` を観測する。`narrow_rejected` は、本番の規則がこの main をその効果で型付けないことを到達先の対象健全性から導く（旧の `handleEtc_rejected` に当たる） |
| `emit_checked` | 軽い | `R.Surface.LogExamples.emit_checked`・`handled_checked`・`partial_retains_log`・`console_pure_rejected` | 旧の例は Log.Record などの通常のレコードとプログラム全体の検査（`checkProgram`）を持った。新しい例は操作の引数を String と Integer にし、式と定義の検査器で受理と拒否を対照する |
| `Surface.Check.FailureExamples`・`Release.FailureExamples` | 軽い | `R.Surface.FailureExamples.raised_checked`・`caught_checked`・`failure_rejected`、`R.FailureExamples.fromResult_ok`・`fromResult_error`・`toResult_return`・`toResult_raise` | 表層の例は旧の約30の例のうち、直接の raise・同じ型の捕捉・別の型への raise し直し・型の取り違えの拒否・予約した0番の拒否を置いた。核の例は具体の型（Integer・String）と値で四つの有限遷移を示す。旧の変換の型付けの例（`toResult_typed` など）は置いていない |
| `interpAllowed_spec` | 重い | `R.Surface.Check.interpAllowed_spec`（`interpAllowed_complete`） | 同じ（判定と条件の同値） |
| `Prepared.writeEffNames` | 軽い | 述べ直さない。要らなくなった: 篩付きの交換の出力（`SurfaceCheck` の入口）は効果を書き出さず、交換の入力の効果を Lean の中で比べる（`SurfaceCheck/Batch.lean` の `effEq`）。書き出しの関数 `Exchange.fromEffNames` は `Exchange.Convert` に残り、読者は `Exchange.RangeExamples` の `#guard` だけである。旧の `Prepared` への包装だけが除かれた | — |
| `Prepared.writeEffNames_complete` | 軽い | 述べ直さない。同上。書き出しの完全性は関数の水準で `Exchange.fromEffNames_ok`・`fromEffNames_complete_of_atomsIn` が残る | — |
| `requestLitBound_known_ports_wf` | 軽い | 述べ直さない。篩付きの `requestLitBound` は区間の整形式（`PortRange.WF`）を定義の中の条件にして既知にする。接続定理はこの補題を使わず（旧でも読者がなかった）、読者のない補題を置かない決まりに従った | — |
| `RhsEval` | 重い | `R.Surface.ScopeLower.RhsEval` | 頭の判定 `directHead` は篩付きの表層の `funName` の4引数の形 |
| `ArmEnter` | 重い | `R.Surface.ScopeLower.ArmEnter` | 同じ。篩付きの表層の照合の腕の文脈は照合する値を一つ束縛するので、`ReachAtExpr.matchArms` が値を一つ積んだ局所で腕へ入る（`scrutIndex` は元の位置に1を足す） |
| `ReachBlock` | 重い | `R.Surface.ScopeLower.ReachBlock`（`ReachAtBlock` の存在）と `ReachAtExpr`・`ReachAtExprs`・`ReachAtArms`・`ReachAtClauses` | 上の二点 |
| `rhsEval_step` | 重い | `R.Surface.ScopeLower.rhsEval_step` | 同じ |
| `armEnter_steps` | 重い | `R.Surface.ScopeLower.armEnter_steps` | 同じ |
| `analyzeBody_sound` | 重い | `R.Surface.ScopeLower.analyzeBody_sound`（一段の健全性 `R.Surface.ScopeState.absStep_sound`・`Run.step_models`） | 事実の対応は篩付きの `models ok pattern`（旧は解析器の組 `Parsers`） |
| `analyzeBody_requiredIndex` | 重い | `R.Surface.ScopeLower.analyzeBody_requiredIndex`（`R.Surface.ScopeState.requiredIndex_checked`） | 同上 |
| `analyzeBody_numbered` | 軽い | 述べ直さない。束縛番号の新規性の不変条件は、旧でも接続定理の証明に使われず読者がなかった。要る読者がないので置いていない | — |

## 取りまとめの追加の指示への対応

2026-11-07 の取りまとめの指示（Log・型付きの失敗・脱糖の番号の旧の例を置き直す）に従い、上の表の `emit_checked`・`FailureExamples`・`dedicated_lowering` の行の例を置いた。交換の効果の名前の書き出しは、上の表の二行のとおり要らなくなったと判断した。

## 例の作り方

- 検査器の例（`LogExamples`・`Surface.FailureExamples`）は検査の関数の結果を `cbv` で評価する（`CheckOpenAcceptanceExamples` と同じ方法）。`with_unfolding_all rfl` と `decide +kernel` は呼出しの検査で簡約が止まった。`#eval` と `native_decide` は使っていない。`LogExamples` の単独の検査は約28秒である。
- `ScopeConnectionExamples` の受理（`acceptBody`・`acceptProgram`）は `rfl` で計算した。
- `SurfaceTargetReachExamples` の表層の型付けは導出を手で書き（`RangeSignatureExample` の組込みの呼出しの型付けと同じ形）、開始状態からの4段は遷移の規則の構成子と `rfl` で書いた。
- `set_option maxHeartbeats`・`maxRecDepth` は置いていない。

## 既定ビルド・公理監査・照合

| 検査 | コマンド | 開始 | 終了状態 | 外側の時間 |
|---|---|---|---|---|
| 既定ビルド | 共有ロックの下で `lake build`（作業木の formal） | 20:23:10 | 0（2333 ジョブ） | 205秒（最大常駐量 5,018,894,336 バイト、`/usr/bin/time -l`、手元 M4） |
| 公理監査 | [audit.py](audit.py) `prepare`・`run`・`analyze`（共有ロックの下で `lake env lean -M 12288`） | 20:31:09 | 0 | 15.6秒（[audit-run.json](audit-run.json)） |
| 段の照合 | [../verify.py](../verify.py) `--tmp <群 H の一時領域> --h2-tmp <群 H2 の一時領域>` | 下の「段の照合の実行」 | | |

既定ビルドの後に、新しいモジュールの警告（使わない simp の引数）を一つのファイルで直した。その後のビルドは下の「段の照合の実行」にある。

公理監査の結果（[audit.json](audit.json)。下の「取りまとめの判断への対応」の後の最後の実行）: 足した・変えた13モジュールの全宣言 2647（private 1846、マクロのスコープを持つ名前 0）を監査し、公理依存は許可した三公理（propext・Quot.sound・Classical.choice）の部分集合だけである。`sorryAx` 0、`axiom` の宣言 0。依存の組は、なし 925・propext 1297・Classical.choice + Quot.sound + propext 418・Quot.sound + propext 6・Quot.sound 1。述べ直した主な定理44名の型の SHA-256 と公理依存は audit.json の `required` にある。

段の照合の台本は、群 H の記録が群 H のコミットの作業木で作られていて、群 H2 の変更の後には第1節（変更の範囲）・第3節（宣言の比較の import の表）・第5節（コメントと heartbeat の再現）が作業木を読むために通らないので、次のとおり追随させた。

- 群 H の照合は群 H のコミット（`698f2350b`）の状態について行う。第3節は、そのコミットの formal を一時領域に取り出した import の表で `h/stage.py analyze` を再計算する。
- 群 H2 の照合を足した: 変更の一覧が [changes.json](changes.json) と一致すること、変えた Lean のファイルが群 H のコミットの行を消していないこと、足したモジュールが既定 import にあること、群 H2 の公理監査の記録の再計算、述べ直した41名が本番と文書にあること、群 H2 の Lean のファイルにコメントの工程 ID・heartbeat の設定・`sorry`・`#eval` がないこと。
- コメントの工程 ID と heartbeat の記録（`h/comments.json`・`h/heartbeats.json`）は群 H の作業木の記録なので再現の対象から外した（群 H2 の作業木では `comments.py` の対象のファイルの数が567から568に変わる。試しに実行して確かめ、記録は元に戻した）。

### 段の照合の実行

| 実行 | 開始 | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|---|
| 公理監査のやり直し（警告を直した後の既定ビルドの後） | 20:37:08 | 0 | 16.2秒 | 生の出力の SHA-256 は前回と同じ。記録 audit.json は同じ |
| `verify.py --tmp <群 H の一時領域> --h2-tmp <群 H2 の一時領域>` | 20:37:33 | 0 | 73秒（最大常駐量 2,290,860,032 バイト） | `verified: true`。群 H の変更42・群 H2 の変更23、群 H2 のモジュール10・宣言2582、必須の名前118。群 H の記録（h/ の JSON）は変わらない |
| 同じ照合（文書の最後の書き直しの後） | 20:39:33 | 0 | 73秒 | 同じ結果（`verified: true`） |
| 取りまとめの判断への対応の後の既定ビルド | 20:46:54 | 0 | 2秒（2334 ジョブ。差分のビルド） | 新しいモジュールの警告なし |
| 同じ後の公理監査 | 20:47:17 | 0 | 15.6秒 | 13モジュール・2647宣言、許可した三公理の外・sorryAx・axiom 宣言 0 |
| 同じ後の照合 | 20:48:24 | 0 | 71秒（最大常駐量 2,255,994,880 バイト） | `verified: true`。群 H2 の変更24・モジュール11・宣言2647、必須の名前121。群 H の記録は変わらない |

## 取りまとめの判断への対応（2026-11-07）

1. 範囲を具体化する本体の受理で、型が保持する範囲を選ぶ規則（`OpenScopeAccept.selections`）が選んだ出現の範囲は、`Benitoite.Release.Refinement.Surface.OpenScopeAccept.acceptSelection_sound` が与える（受理の全体からは `Benitoite.Release.Refinement.Surface.OpenScopeAccept.acceptBody_sound` の結論 `BodyRanges` の第二の場合）。結論は、範囲の文脈に合う全ての具体化について、選んだ契約の範囲が型の保持する範囲（`Selection.source`）を覆うことである。この出現は局所解析の記録で照らして受理されない（`OpenScopeAccept.acceptBody` は選ばれた出現に `acceptOccurrence` を呼ばない）ので、記録の状態の事実を前提にする接続定理（`OccurrenceAccepted` を前提に取る `scope_check_connection` など）の対象外である。
2. `l70/verify.py` の改め方は認められた。
3. 観測を持つ表層の main の例（`main_observed`）と誤った規則の反例（`wrong_rule_unsound`・`narrow_rejected`）を `SurfaceTargetObservedExamples` に置いた（上の表の `main_reach`・`wrong_rule_unsound` の行）。読取りの観測は文字列の解析の結果であり、`decide +kernel`（公理を足さないカーネルの評価）で計算した。`cbv` は既定の上限で timeout し、`rfl` は簡約が止まった。
4. `capture_builder_cell` の前提 `B.ValueAssumptions P` は、主定理が既に取る `CoreAssumptions` の一部であり新しい信頼条件ではないとして認められた。旧の言明との違いは上の表の同じ行に書いた。

## 計画からのずれ

- 旧の `requestLitBound_known_ports_wf`・`analyzeBody_numbered`、交換の効果の名前の書き出しの2名は述べ直していない（上の表の理由）。
- 段の照合の台本（`l70/verify.py`）を、群 H の照合を群 H のコミットの状態で行う形に改め、群 H2 の照合を足した。

## 後の作業への申し送り

- 範囲を具体化する本体の受理（`OpenScopeAccept.acceptBody`）で型が保持する範囲を選ぶ規則が選んだ出現は、記録で照らす接続定理の対象に含まれない。その出現の範囲は、全ての具体化での被覆（`acceptSelection_sound`）と型付けが与える。旧の形式化にはこの受理がなかった。
- 表層の具体の評価（`ReachAtBlock`）と脱糖した核の実行の一致は、旧と同じく結論しない。
- 範囲付きの書き込みと Result の照合を持つ表層の main の例は置いていない（観測を持つ例は Top のパスの読取りで置いた）。
