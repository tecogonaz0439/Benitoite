# RV-L20.j: L20 群 J・K（L20.97〜.105）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.j` の未コミットの作業木、基準 `bc518cf2`（san_benito の先端）。依頼文 `L20.j-prompt.md`、担当の報告、`l20/j/` の記録（results.md・signatures.md・axioms.lean・declarations.json・audit-summary.json・checks.json・logs.json・inventory.py）、`l20/detail.md` の S00・S02・S09・S10、全76遷移の分担、L20.97〜.105 の行と義務の表、`plan.md` の確認点、`l20/d/results.md` の「L20.103 への申し送り（E_OpPrim）」、`RV-L20.d.md` の中2・軽8、`RV-L20.a2.md` の `split_fail_annotated`、`l20/i/results.md` の「計画との差」を読んだ。新規の Lean 7ファイルを全文読み、既存の変更は `git diff` で読んだ。補助の入力は `<tmp>/rv-l20-j/` に置き、既存のファイルを変えていない。

## 総合判定

**条件付き可**。重 0 件、中 1 件、軽 6 件。

状態の葉の言明はそのまま受け入れてよい。10の葉の行先は Semantics の該当の規則の結論と一字ずつ同じで、σ と Eb を保つ。規則の前提のほかに受けるのは P.WellFormed・P.WellTyped B・B.CoreAssumptions P と元の StateTyE だけであり、組込みの操作だけが既存の `P.EffectsOk B` を加えて受ける。行先のコードの型付け、`MatchPathsEvaluated`、`CaptureContextRegular`、`SourceScoped` を前提に持つ葉はない。代表の限定（δ=0、ret_const、一引数、辞書なし）は外れている。RV-L20.d の中2（Φ の共有と `hc`）は E_OpPrim に引き継がれていない。公理の監査は再実行して同じ出力（SHA-256 一致）を得た。

条件は中1の一点である。O167 の二つの拒否例は既定ビルドに置かれているが、受理と拒否の対照になっていない。`reject_guard_unknown_elimination` の拒否は guard の型に依存せず、unknown を使った意味がない。補助の入力で受理側を閉じたので、本番への追加は小さい。言明・規則・公理は変わらない。

## 所見

### 中

#### 中1: O167 の二つの拒否例が受理と拒否の対照になっておらず、一方は unknown に依存しない（読めば確定、Lean で確認）

- 場所: `formal/Benitoite/Release/Refinement/MatchStateExamples.lean` 142〜179行（`reject_guard_unknown_elimination`・`reject_false_fact_to_tail`）、`l20/j/results.md` の O167 の行（「受理例と対照にして既定importへ含める」）、`l20/detail.md` の L20.99・O167（「受理と拒否の対照で保持」）。
- 問題点1: `reject_guard_unknown_elimination` は三つの連言である。(a) `true` を返す guard が `Boolean{unknown}` に型付く、(b) その述語の評価が none、(c) guard 付きの腕一つの列が Boolean を網羅しない。(c) は (a)(b) と結び付いていない。guard 付きの腕は `unguardedPats` に入らないので、(c) は guard の型と無関係に成り立つ。補助の入力 `check1.lean` で、任意の guard `g`・本体・選択肢について同じ (c) を同じ証明で閉じた。unknown の guard で網羅性の除外をしないことの例としては、名前と中身が対応していない。
- 問題点2: `reject_false_fact_to_tail` の拒否には意味がある。否定の言明はすべての導出を量化するので、guard `false` が `Boolean{truth}` に型付く場合も含む。その否定 `¬truth` を後続へ渡す規則なら Φ が矛盾し、13 が Month に型付く。ただし、この受理側が本番にない。第一の連言は guard の型付けを示すだけで、後続の受理を示さない。
- 問題点3: results.md は「受理例と対照にして」と書くが、対になる受理例を名指ししていない。`guard_execution` などは受理の例だが、同じ腕列・同じ後続の本体に対する対照ではない。
- 確認: 補助の入力 `check2.lean` で、偽の事実 `[.falsity]` の下で `thirteen : monthType` を `V_Refine` と `Entails.false_elim` で閉じた（`lake env lean -M 12288` で終了0）。`check1.lean` の (c) の一般化も終了0で、依存は公理3種である。
- 修正案: (1) `reject_false_fact_to_tail` に受理側の連言を足す。偽の事実の下で後続の本体 `.ret thirteen` が `monthType` に型付くこと（`check2.lean` の形）である。(2) `reject_guard_unknown_elimination` は、拒否が guard の型に依存しないことを言明に表す。guard を任意に量化し、対照として同じ選択肢を guard なしにした列が網羅することを足す。unknown の連言を残すなら、unknown の guard が真を返しても後続の網羅性の判定に入らないことを示す、と目的を書く。(3) results.md の O167 の行に、対照の組を名指しする。

### 軽

#### 軽1: NoFail の cutoff の対照の記述が実物より多い（Lean で確認）

- 場所: `OperationStateExamples.lean` 127〜143行、07-04 の追加段落「型 cutoff=2、内部に row7 を含む非空の型像、外の row9 の同じ置換像について」、results.md の L20.102 の行。
- 問題点1: 置換する対象は `Eff.row 9` で、型変数を含まない。型像の中身は結果に現れない。`check1.lean` で、任意の型像 `x` について `Eff.substAt 2 [x] [] (Eff.row 9)` が `row 9` を含むことを閉じた。「内部に row7 を含む」は検査に効いていない。対照が確かめるのは、型像が一つある置換で行の番号がずれないこと（型像と行像を別の名前空間として扱うこと）である。この点には意味がある。
- 問題点2: 受理側は既存の `NoFail.substAt` の適用、拒否側は同じ像の直接の計算である。L20.102 の「範囲外変数を行に持つ Handle→Op の全保存の葉を含め、NoFail の cutoff を実像で確認する」の「実像」は、`row_handle_operation_resume` の型像 `rowType` ではない。その葉の中の行の移送は `es = []` で自明に閉じる。
- 修正案: 07-04 と results.md の記述を「型像一つ・cutoff 2 の置換が行 9 の番号を保ち、Q9 で受理し Qempty で拒否する」に改める。「row7」を残すなら効かないことを書くか、例から外す。

#### 軽2: 設計書が、残っている代表の葉に触れなくなった（読めば確定）

- 場所: 07-04 の葉の表の「if・guard・match」「節・resume・破棄」の行、01-12 の 3415 行の段落。Lean は `MatchPaths.lean` 460〜681行、`HandlerOperation.lean` 261行、`HandlerPreservation.lean` 227行。
- 問題点: 基準の 07-04 は `match_body_zero` と `MatchPathsEvaluated`、`HandlerOperation` の一引数の操作を書いていた。変更後の 07-04 と 01-12 はこれらに触れない。しかし `StateTyE.match_body_zero`・`StateTy.match_body_zero`・`MatchPathsEvaluated`・`StateTyE.operation_one`・`StateTyE.resume_const` は既定 import の中に残る。`HandlerOperation` は 07-04 のどの行にも名前が出なくなった。設計書は実装している内容を書く、という規約からずれる。
- 修正案: 取りまとめが、代表の葉を消すか残すかを決める。残すなら 07-04 の表に「一般の葉に置き換わった代表として残る」と一文で書き、`HandlerOperation` を対応の表に入れる。消すなら同じ変更で読者がないことを確かめる。

#### 軽3: `PatTy.bindings_annotation`・`AltsTy.bindings_annotation` の `P.WellFormed` は使われていない（Lean で確認）

- 場所: `PatternMatchAnnotations.lean` 30〜216行。
- 問題点: `hP` は相互帰納の再帰呼出しへ渡されるだけで、証明のどこにも使われない。補助の入力 `check3.lean` で、`hP` を除いた写しが終了0で通った。主定理の入力から供給できるので、新しい信頼条件ではない。言明が必要以上に強い前提を持つだけである。
- 修正案: `hP` を除く。読者の `match_body`・`match_guard` の呼出しから `hP` を外す。

#### 軽4: 設計書の追加の文の用語と書き方（読めば確定）

- 場所: 01-12 の新しい節「操作と保存継続の状態」、07-04 の追加段落。
- 問題点1: 「組込み」が5か所ある。基準の 01-12 は「組み込み」を138か所で使い、「組込み」は0か所である。
- 問題点2: 基準の文書にない語を足している。「分割証人」「前置辞書」「末尾被覆」「失敗操作」「通常操作」である。用語集にもない。
- 問題点3: 新しい節の最初の段落に【決定】があるが、直後の「理由:」がない。中身は証明の範囲の説明なので、【決定】の印が合わない。
- 問題点4: 「既存の Program.EffectsOk」の「既存の」は変更を基準にした語である。01-12 の「lambda は closeVal が作る実際の closure を引数に使う」は適用例の細部で、どの lambda か本文から読めない。07-04 の「prefix の非 handled と EffectsOk を組み合わせて組込みの節の範囲 S の被覆を導く」は主語が `split_handle` に読めるが、組み合わせるのは `operation_primitive` である。
- 修正案: 「組み込み」に揃える。新しい語は既存の表現（「分割の同じ証拠」「前に置く辞書の引数」など）に言い換えるか、用語集に足す。【決定】を外すか理由を書く。「既存の」を除き、主語を `operation_primitive` にし、lambda の文は 07-04 の例の説明へ移す。

#### 軽5: 記録の小ささと測定の欠け（読めば確定）

- 場所: `l20/j/results.md` の O027 の行と「検査」、`checks.json` の `rss`、`logs.json`、`signatures.md` の冒頭。
- 問題点1: RSS を本体・計測器とも採っていない。設計者の既存の指示は、Lean の作業末の検査を `/usr/bin/time -l` で包み、最大常駐量を results.md に残すことである。依頼文にこの指示がないので、担当の誤りではなく依頼の欠けである。参考として、本レビューで新規7ファイルを単独に検査した最大常駐量は 0.82〜1.14 GB（`HandlerGeneral` が最大）、時間は 0.35〜2.86 秒だった。
- 問題点2: `logs.json` は途中の失敗を含む131件の大きさと SHA-256 を持つ（21 KB）。0 バイトのログも含む。results.md が主なログ5件を表に挙げているので、131件の一覧は記録として大きい。
- 問題点3: `signatures.md` は `inventory.py` が実装後のソースから作り直す形で、「先に書く」署名の版が残っていない。冒頭の「実装前に固定・補正した」は、記録からは確かめられない。
- 修正案: 取りまとめが依頼文の雛形に RSS の採取を足す。`logs.json` は主なログに絞るか、件数と全体のハッシュだけにする。`signatures.md` の冒頭は「実装後のソースから抽出した」と実物どおりに書く。

#### 軽6: 具体例の前提の表が同時に満たせることを示していない（読めば確定）

- 場所: `OperationStateExamples.lean` の `row_handle_operation_resume`（`hop : P.ops "Example.identity" = some declaration`）、`primitive_pathBases`（`hsig : B.sig "Example.pathBases" = some primitiveSig` と `B.CoreAssumptions P`・`P.EffectsOk B`）。
- 問題点: 初期状態の型付けは具体に構成しているが、プログラムの表と組み込みの表は仮定である。たとえば `primitive_pathBases` は、`B.effects processEnvironmentEff` が `"Example.pathBases"` を含むこと（`pathBases_shape` の membership）を、仮定の組から暗に要求する。各条件を読む限り矛盾はないが、満たす P・B は示されていない。前の群の例と同じ形であり、表の充足は L50/L60 の担当である。
- 修正案: results.md に「表の充足は仮定」と一文で書く。可能なら旧 Release のモデルの表に操作を一つ足した具体の P・B で一度適用する。

## 確認した事項

### 1. 行先と規則の一致

`Semantics.lean` の結論と各葉の結論を照合した。

| 規則 | 葉 | 行先 | 規則の前提と葉の入力 |
|---|---|---|---|
| E_MatchBody | `StateTyE.match_body` | `.run (Closure.mk (cap.extendMany ws) body) k μ` | `arms[next]? = some (.mk alts none body)`・`firstAlt … = some ws` と同じ |
| E_MatchGuard | `StateTyE.match_guard` | guard の閉包と `.guardF v cap arms (next+1) (Closure.mk (cap.extendMany ws) body) :: k` | 同上（guard は some） |
| E_ErrPopGuard・E_ExitPopGuard | `err_pop_guard`・`exit_pop_guard` | `.error rs k μ`・`.exit n rs k μ` | 規則の前提なし。葉も元の状態だけ |
| E_Handle | `handle_step` | `.run (Closure.mk q.capture m) (.handleF q.capture h :: k) μ` | view のみ |
| E_HRet | `handler_return` | `.run (Closure.pure (.ret v)) k μ` | view のみ |
| E_Op | `operation_all` | `hcap.extendMany (ws ++ [.loc κ])`・`c.body.substTy ts []`・`.drop κ :: k2`・`μ.set κ (.cont (k1 ++ [.handleF hcap h]))` | view・SplitAt・findClause・`μ κ = none` と同じ |
| E_OpFail | `operation_failure` | `hcap.extendMany [v, .loc κ]`・`body.substTy [T] []` ほか同上 | view・SplitAt・`μ κ = none` と同じ |
| E_OpPrim | `operation_primitive` | E_Op と同じ形 | `B.sig b = some s`・kind の三分類・SplitAt・findClause・`μ κ = none` と同じ。加えて `P.EffectsOk B` |
| E_Resume | `resume_all` | `.run (Closure.pure (.ret v)) (k' ++ k) (μ.set κ .used)` | view・`μ κ = some (.cont k')` と同じ |

全葉の結論は同じ `StateTyE P B σ Eb` で、σ と Eb を固定する。行先のコードの型付けを入力に持つ葉はない。guard の真偽の葉は既存の `guard_true`・`guard_false` で、`match_guard` の行先からの適用を `MatchStateExamples.guard_execution` が示す。

### 2. 代表の限定

`match_body`・`match_guard` は任意の arms・n・alts・ws を量化し、束縛の数 δ は照合から決まる。obs が none のときは事実を足さない（`matched_facts`・`excluded_facts` の none の枝）。`operation_all` は任意の ts・ws と `findClause` が返す節を扱い、`od.params` 全体を使う。`handler_return` と `resume_all` は任意の値、`resume_all` は任意の保存継続を扱う。`handle_step` は通常と失敗の handler の両方を逆転する。前置する辞書を持つ操作の具体例はないが、一般の葉の量化は限定していない。

### 3. 前提の供給

- `match_body`・`match_guard` の事実は、元の matchRun 状態が持つ `MatchPrefix` と現在の照合成功から作る。guard 付きの腕は `MatchPrefix` の対象外で、`HasTypeArmsQ.guarded` の後続は元の Φ で検査する（`capture_plain_success`・`capture_guard_success` の guarded の succ の枝）。`MatchPrefix.guard_advance` は guard 付きの腕を飛ばすだけで、guard の否定を事実にしない。
- `CaptureContextRegular` は `CaptureOk.contextRegular` から得るだけで、独立の前提にない（`MatchStateLeaves` 169・342行、`HandlerGeneral` 78行）。`RuntimeTypeSubst` に `SourceScoped` はない。
- `P.EffectsOk B` は、Refinement の主な定理の前提の位置へ置くと既に決めている（`plan.md` の 2026-11-01 の RV-L00b.14e の項）。旧 Release の主定理も同じ前提を持つ。したがって新しい信頼条件ではない。
- `operation_primitive` は CoreAssumptions の `io_op`・`pathBases_shape`・`admits_sat`・`sig_scoped` を使う。`es = []` は `PrimitiveAdmissible.rowCount` と `s.neffs = 0` から導き、規則の `c.body.substTy ts []` が es を捨てることと合う。

### 4. E_OpPrim と Φ の分離

呼出し側は `read_values` が返す閉じた値の型付け（Φ = []）、節側は `split_handle` の `HandlerFrameTy` の Γ・Φ である。`S02Internal.substC` へは `hi.closedInput (hB.admits_sat …)` の内部入力と節の本体を直接渡し、`type_subst_op_body` を経由しない。通常の操作も、RV-L20.d の後に Φ0 と Φ を分けた `type_subst_op_body` を使う。範囲の被覆は、`split_handle` の新しい成分、`EffectsOk.operation_not_handled`、`ClauseRangeIs` から同じ分割の証拠で導く。

### 5. 強化した二つの補題

`split_handle` は結論に連言を一つ足し、`split_fail_annotated` は存在の連言を一つ足した。前提は変わらず、既存の結論はそのまま残る。既存の読者は `HandlerOperation.operation_one` の一か所で、追加の成分を `_` で受ける。`split_fail_annotated` の新しい成分は `K_Handle_Fail` の構成子の欄そのもので、別の証拠と同一視していない。`operation_failure` が `fail_input` の別の証拠から使うのは `cap.closeTy E` の等号だけで、この値は Γ に依存しない。`HasTypeCQ.operation_call` の一引数の言明は保たれ、補助の `operation_call_aux` を一般化しただけである。Typing・StateTyping・ConstraintAssumptions の差分はない。

### 6. 公理と記録

- `l20/j/axioms.lean` を再実行し、終了0、4.4秒だった。出力 1,906,403 バイトの SHA-256 `3016081804c1…a8ee9` は、results.md の `benitoite-j-k-axioms-complete.log` と一致した。579定数（AUDIT_TYPE 579件、AUDIT_MODULE 12件）、依存する公理の名前は propext・Classical.choice・Quot.sound だけ、warning 0 件である。
- 新規7ファイルを単独で `lake env lean -M 12288` で検査し、すべて終了0、診断なしだった。
- `declarations.json` の12ファイルの大きさと SHA-256 は現在の作業木と一致した。新規7モジュールの手書きの宣言は 6+4+19+74+27+8+29＝167件、全体289件である。`checks.json` の 01-12・07-04・Benitoite.lean の SHA-256 も一致した。
- 署名の一覧は `operation_primitive` を抜き取り、ソースと一字ずつ一致した。
- 公開の記録に手元の絶対パスと docs/todo へのリンクはない。
- 13行の義務（O038・O046・O051・O056・O058・O138・O143・O167・O005・O016・O084・O027・O118）は detail の担当の単位と合う。O167 は中1、O027 は軽5を参照する。
- `RuntimeTypeSubst` の公開5成分のうち Comp 以外の4成分は、相互帰納の中の読者だけを持つ。results.md がこの関係を書いているので、所見にしない。

## 補助の入力

`<tmp>/rv-l20-j/` に置き、`formal/` で `lake env lean -M 12288` により実行した。いずれも終了0で、依存は公理3種である。

| ファイル | 内容 |
|---|---|
| `check1.lean` | 任意の型像で `Eff.substAt 2 [x] [] (Eff.row 9)` が行9を含むこと、型像なしの受理、guard を任意にした網羅性の拒否、主な葉の `#print axioms` と `#check` |
| `check2.lean` | 偽の事実の下での `thirteen : monthType` の型付け（中1の受理側） |
| `check3.lean` | `P.WellFormed` を除いた `PatternMatchAnnotations` の写し（軽3） |
| `axioms.out` | `l20/j/axioms.lean` の再実行の出力（SHA-256 は results.md と一致） |

## 再レビュー（再開1）

2026-11-02。担当の報告 `L20.j-r1-report.md`、`l20/j/results.md` の「独立レビュー所見への対応（再開1）」「再開1の検査」、変更後の `MatchStateExamples.lean`・`OperationStateExamples.lean`・`PatternMatchAnnotations.lean`・`MatchStateLeaves.lean`、07-04 の該当の段落を読んだ。対象は中1・軽1・軽3・軽6 の処置である。補助の入力は `<tmp>/rv-l20-j/check4.lean` に置いた。検査の途中で別の `lake build` が動いていたので、終わるのを待ってから単独の検査を行った。

### 判定

**可**。中1・軽1・軽3・軽6 は閉じた。新しい所見はない。4ファイルを単独で `lake env lean -M 12288` で検査し、すべて終了0で診断はなかった。最大常駐量は 0.83〜0.86 GB である。新しい例の公理の依存は、`row_concrete_model` を含めて propext・Classical.choice・Quot.sound だけである。

### 中1: 閉じた

- `reject_guard_unknown_elimination` は四つの連言になった。(c) は任意の guard `g` について「guard 付きの wild の腕は Boolean を網羅しない」、(d) は同じ wild の腕を guard なしにすると網羅する、である。同じパターンの guard の有無だけを変えた受理と拒否の対照で、O167 の「受理と拒否の対照」に当たる。
- unknown の連言 (a)(b) は、(c) とは量化の具体化（`g := .ret (.const (.boolean true))`）でだけ結び付く。拒否が unknown に依存するとは主張していない。docstring は「guard は型や真偽によらず網羅性に数えない」、07-04 は「unknown の型を持つ guard が真を返す場合も網羅性に数えない」と書き、どちらも実物に合う。名前に unknown が残るが、書き方は正直である。
- `reject_false_fact_to_tail` に受理側の連言が加わった。`[.falsity]` の下で後続と同じ本体 `.ret thirteen` が `monthType` に型付く。元の Φ での拒否と並ぶので、guard の否定（例えば `Boolean{truth}` の否定）を後続へ渡すように規則が変わると、この組が食い違う。対照として意味がある。受理側は前回の補助の入力 `check2.lean` と同じ形である。
- 参考: 07-04 の表の「if・guard・match」の行の「unknown と偽事実を後続へ渡すことの拒否」は、unknown の部分については網羅性に数えないことの対照なので、102行の書き方に揃えるとよい。受け入れの条件にはしない。

### 軽1: 閉じた

型像を `rowType`（Handle→Op→Resume の例と同じ型）に揃え、07-04 と results.md から row7 の説明を除いた。results.md と 07-04 は「型像一つ・cutoff 2 の置換が外の行9の番号を保つ」と書き、「置換の対象は型変数を持たず、型像の中の行は結果に影響しない」と明記している。`check4.lean` で、任意の型像 `x` について `Eff.substAt 2 [x] [] (Eff.row 9)` が `[.base .unit]` の場合と等しいことを閉じたので、この記述は正しい。

### 軽3: 閉じた

`PatTy.bindings_annotation`・`AltsTy.bindings_annotation` と二つの相互補助から `P.WellFormed` が外れた。`#check` で、前提が VarianceValid・CaptureOk・PatTy/AltsTy・注釈・閉じた型付け・照合成功だけであることを確かめた。読者の `match_body`・`match_guard` は呼出しから `hP` を外しただけで、言明は前回と同じである（`#check` で確認。`hP` は `close_value_typed` などに使うので残る）。

### 軽6: 閉じた

- `modelProgram` は操作 `Example.identity`（前回と同じ `declaration`）と効果 `Example.effect` を一つずつ持ち、他の表は空である。`modelBuiltins` は `Reference.get`・`Reference.set` の二署名、`state_effect` のための `stateEff ↦ some []`、常に真の `sat`、空の δ・IO 応答を持つ。
- `model_wellFormed`・`model_wellTyped`・`model_core` は、構造体の各欄を証明で埋める。仮定や `sorry` はない。`CoreAssumptions` の全欄（sat・admits の移送、`sig_scoped`、`admits_sat`、`release_exists`、`pathBases_shape`・`io_op`・`opEff_io`・`effect_ops`、`ref_get`・`ref_set`、`store_shape`・`store_admits` ほか）が具体の表で閉じている。
- 表は空虚ではない。`P.ops "Example.identity" = some declaration` が実際に成り立ち、Handle→Op→Resume が使う操作の宣言の検査（`ops` の欄の SourceScoped・RowsIn・HasKind・注釈）を、具体の宣言について行っている。`sat` が常に真なのは制約を持たない例なので弱く、表の条件の実表での充足（L50/L60）を代行しない。07-04 も「sat は常に真」と書いている。
- `row_concrete_model (σ : PathEnv)` は σ だけを引数にとり、`row_handle_operation_resume model_wellFormed model_wellTyped model_core (by simp [modelProgram])` で同じ opState と resumeState を得る。仮定なしの適用である。
- `primitive_pathBases` は変更されず、`hsig` と CoreAssumptions・EffectsOk を引き続き仮定で受ける。results.md の「計画との差」と 07-04 は「表の条件は仮定である」と書き分けている。

### 補助の入力

| ファイル | 内容 |
|---|---|
| `check4.lean` | `row_concrete_model`・二つの拒否例・NoFail の二例の `#print axioms`、`row_concrete_model`・`PatTy/AltsTy.bindings_annotation`・`match_body`・`match_guard` の `#check`、型像の中身が NoFail の対照の像に効かないことの等式 |

## 取りまとめの追記

2026-11-02。中1と軽1〜6を再開1で処置し、中1・軽1・軽3・軽6を局所に再レビューして可とした（上の節）。処置の後の作業末の work は成功した。具体の `modelProgram`・`modelBuiltins` は `sat` が常に真の弱い表であり、実際の組み込みの表での充足は L50/L60 の照合に残る。
