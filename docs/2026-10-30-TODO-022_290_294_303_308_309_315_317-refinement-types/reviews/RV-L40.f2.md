# RV-L40.f2: L40 群 F2（L40.29、.33〜.35）の独立レビュー

2026-11-04。対象はブランチ `m014/l40.f2` の未コミットの作業木、基準 `2719963cf6c41badadbd3589fd150179f34fe075`（HEAD と一致）。新しい本番の4モジュール（`StandardIntegerFailure`・`IntervalFlowLeaves`・`FirstFailure`・`IntervalControlLeaves`）、既定 import の追加、01-12 と 07-04 の写し、`l40/f2/` の記録を見た。

読んだもの: 担当への依頼と担当の報告、`l40/detail.md` の第2節「数値の正常結果と Stop」、第4節 F07 と「短い試行の状態」、第5節の L40.29・.33〜.35 と群 F2 の行、第6〜10節、`l40/f2/` の results.md・obligations.md・verification.json・audit-summary.json・inputs-final.json・checks.json・verify.py。Lean は新しい4ファイルの全文、`StandardInteger.lean` の `integerOutcome`・`integerChecked`・`integerFloorDelta`・`integerAbsoluteDelta`・`integerBitsDelta`・`integerDelta_shift`、`Interval/Eval.lean` の `EvalPartial`（分岐と照合の構成子）・`EvalArms` 三種・`EvalBlock`、`Shared/Approximation.lean` の `ValueApprox.Mem`・`FlowApprox.ResultMem`、`Shared/Interval.lean` の `join`、`IntervalConnection.lean` の `ValueRel`・`typed_returned_mark`、前段の `l20/n/h04-handoff.lean` と `h04-counterexample.lean`。処理系は `builtins/funcs/` の `operators.rs`（`int_divide`・`int_modulo`）・`operators/signed.rs`・`operators/unsigned.rs`・`narrow_integer.rs`・`integer.rs`（床演算・absolute・`shift_amount`・`shiftRightUnsigned`）・`unsigned_integer64.rs`・`width_bits.rs`。

git の操作（読み取りを除く）、既存のファイルの変更、`lake build`、cargo の実行はしていない。Lean の検査は `formal/` を作業ディレクトリに `lake env lean -M 12288` で行い、確かめのファイルは `<tmp>/rv-l40-f2/` に置いた。

## 結論

**条件付き可**（重0・中1・軽4・情報3）。

L40.29 は七整数型の全幅を `IntKind` で量化し、実 `OperationResult`・δ から正常値と拒否を分けている。符号付き最小値の absolute と床商・通常の商の overflow、同じ入力の床剰余の正常な 0、非零除数の床剰余の表現可能性、0除算、shift の count の域外の拒否は、いずれも一般の定理であり具体例だけではない。Rust の実装とも、読んだ範囲と Integer8・UnsignedInteger16 の境界値で一致した。F07 の5定義は detail の字面どおりで、01-12 の写しとも一致する。左右の Mem と局所規則の所属は実定義から証明されており、Block 14 と腕 3×6 の構成子には一対一の入口がある。真偽の枝の具体の読者は、誤った所属の否定が意味を持つ形になっている。L40.34 は前段の受渡しと反例を字面どおり本番へ移したもので、同じ neg の反例の否定と受理を保ち、解析との一致は結論していない。新しい公理はなく、既存の formal の変更は `formal/Benitoite.lean` の import 4行だけである。

条件は中1である。L40.33 の「選択枝」の読者が `ite` の真偽の2構成子だけで、`elseIf`・`ifOnly`・条件の異常終了・`block`・`match` から腕への接続がない。不足の分を、既存の局所規則で閉じる読者として加えるか、L70 へ残すことを理由とともに記録し、写しの「選択した枝」の範囲をそれに合わせる。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 中1 | 中 | `IntervalFlowLeaves.lean` の枝の入口（`if_true_leaf`・`if_false_leaf`）、01-12・07-04 の `IntervalFlowLeaves` の段落 | detail 第5節 L40.33 の完了の判定は「実 return/選択枝/腕/Block の構成から normal/returned を作る読者」、F07 の表は「枝・腕: 実際に選択した同じ枝/腕の所属→joinF の対応成分」である。`EvalPartial` の分岐の構成子は `iteTrue/iteFalse/iteAbrupt`・`elseIfTrue/elseIfFalse/elseIfAbrupt`・`ifOnlyTrue/ifOnlyFalse/ifOnlyAbrupt` の9つあり、本番の入口は `iteTrue`・`iteFalse` の2つだけである。`EvalPartial.block`（Block から式へ）と `matchInteger/matchWidth/matchResult/matchAbrupt`（照合値と腕から式へ）の入口もない。新しい2ファイルに `elseIf`・`ifOnly`・`iteAbrupt`・`.block`・`match*` は0件である。腕の側は3×6の全構成子を扱うが、式の `match` へ上げる入口がないので、腕の所属が式の結果の所属にならない。写しは「選択した枝・腕の結果は joinF の対応する成分へ入る」と一般に書いており、実装より広く読める | 不足の7構成子と `block`・`match` 4構成子に、`join_left/right`・`seq_tail`・`seq_abrupt` を使う入口を加える。`ifOnlyFalse` は通常値の Unit を `normalF .unknown`（又は Unit を含む近似）で受ける。既存の局所規則で閉じることは `<tmp>/rv-l40-f2/Branch.lean`（elseIfFalse・ifOnlyFalse・iteAbrupt の3例、終了0）で確かめた。加えない構成子があれば、L70 に残す理由を results.md に書き、写しの「選択した枝」を実際に扱う構成子の名前に改める。`matchOtherNormal/matchOtherFailed` は other Result であり、L70 に残す範囲として明記する | 読めば確定（構成子の照合）、実行で確定（修正の形） |
| 軽1 | 軽 | `IntervalControlLeaves.lean` の `error_let_member`・`error_mark_member`、01-12 の「let・mark の error は元の状態と failed の所属だけから同じ理由列を保ち」、07-04 の「error は failed の所属と同じ理由列…を保持する」 | 二つの定理の第3の連言 `f.ResultMem (EvalOutcome.failed reason).toApprox` は前提 `mem` そのものであり、`reason` は状態の理由列 `errors` と結ばれていない。所属の部分は任意の `f`・`reason` で前提を返すだけで、制御の葉への「同じ値の所属の供給」の内容を持たない。`errors` が何であっても `reason := .zeroDivisor`・`mayFail = true` の `f` で成り立つことを `<tmp>/rv-l40-f2/Check.lean` で確かめた。理由列の保存は既存の `StateTyE.error_let/error_mark` の結果であり、所属から得たものではない。写しの「failed の所属だけから同じ理由列を保ち」は因果を逆に読ませる | 所属の連言を除いて Step と型付けの保存だけを返すか、残すなら `reason` と `errors` の関係（例えば、同じ失敗の位置の理由の写像）を前提に置いて意味のある形にする。写しは「error は元の StateTyE だけから同じ理由列で型付けを保つ。failed の所属は変えずに引き継ぐ」のように、所属を根拠に書かない | 読めば確定、実行で確定 |
| 軽2 | 軽 | `IntervalFlowLeaves.lean` の匿名の適用例35件の大半 | 依頼文と AGENTS.md は「公開した入口には、既定ビルドの中で具体の適用例か本番の読者を置く」とする。`return_leaf`・`if_true_leaf`・`if_false_leaf`・`block_last`・`arms_body` は具体の読者（`boolean_branches`・`wildcard_return_arm`）から使われる。残りの `block_*`（bind・discard・seq・pattern・各 abrupt・末尾の束縛・builderBind）、`arms_skip`・`arms_guard*`、`width_arms_*`・`result_arms_*` の全部は、同じ署名を変数のまま書き直した例だけで、具体の値・構文への適用がない。順次の規則で head の値を束縛した tail の所属を使うこと、guard の真偽と異常終了の区別、幅付きと Result の腕の選択は、どの具体例でも確かめられていない | 少なくとも、正常な bind（head の通常値を束縛した tail の return）、guard の真と偽、幅付きの腕、Result の腕の body の4系列に、`boolean_branches` と同じ形の具体例を一つずつ置く。誤った成分（normal と returned の取り違え）の否定も添える | 読めば確定 |
| 軽3 | 軽 | `StandardIntegerFailure.lean` の `binary_delta_split`・`divMod_delta_split` | overflow の枝が `= .err "IntegerOverflow"` だけで、その数学値が値域外であるという条件を返さない。同じファイルの `integerChecked_split`・`neg_delta_split`・`floor_delta_split`・`absolute_split` は条件を返している。`divMod_delta_split` は `modulo = true` でも overflow の選言を残す（`modulo_normal` が別に正常を示すので偽ではないが、読者は場合を分けられない）。通常の商の overflow が最小値÷−1 に限ることを示す定理もない（`signed_minimum_stops` は逆向きだけ） | 二つの定理の overflow の枝に `integerChecked_split` が与える `n < k.min ∨ k.max < n` を残し、`divMod_delta_split` は modulo の場合に overflow の選言を除いた形に分ける。必要なら「非零除数の通常の商の overflow は符号付きの最小値÷−1 に限る」を足す | 読めば確定 |
| 軽4 | 軽 | 01-12「標準契約と数値の正常応答」の `StandardIntegerFailure` の段落の末文 | 「Range の正常な Result.Error と、独立評価の failed の区分は保つ。」とあるが、このモジュールに Range の Result.Error を扱う定義・定理はない。results.md は「Range の Result.Error を failed に変える規則ではない」と正しく書いており、写しは何かを証明したように読める | 「`integerFailure` は整数の応答の写像であり、Range の Result.Error を扱わない」と改めるか、末文を除く | 読めば確定 |
| 情報1 | 情報 | `IntervalControlLeaves.typed_first_failure`、`FirstFailure` | `typed_first_failure` は `source.inputs` と `first_failure_handoff` の連言で、二つは互いに使い合わない。第二候補の受渡しは任意の `B` の pure の δ の観測であり、L40.29 の整数の δ（`integerDelta` の理由 IntegerOverflow・DivisionByZero・ArgumentOutOfDomain）と結ぶ読者はない。反例も玩具の `B` を使う。detail は合成を L70 に残すので完了の判定には反しない | 群 G の受渡し表に、「最初の失敗の位置の δ を `integerDelta` の具体の理由へ結ぶのは L70」と一行で書く | 読めば確定 |
| 情報2 | 情報 | L40.34 の所要（54秒） | 前段の `h04-counterexample.lean` との差は、import、`first_error`・`pure_failure` の private の解除、`revised_candidate_valid` から `first_failure_handoff` への改名、docstring 一件、`#print axioms` の除去、適用例2件だけである。`BeforeError`・`BeforeErrorSteps`・`FirstFailureHandoff` は `h04-handoff.lean` と字面が一致する。detail の「前段の first_error/pure_failure を本番へ移し」に合っており、短い所要はこの移植で説明できる | なし | 読めば確定 |
| 情報3 | 情報 | `StandardIntegerFailure.shift_inside` | 正常枝は「ある `v` について δ が `.val v`」を `rfl` で示すだけで、値がシフトの結果であることは述べない。値は群 D の `integerBitsDelta` の定義が定め、L40.29 の完了の判定（正常と Stop の分離）には足りる | 値を使う後段の読者が要るときに、`integerWrap` の形の等式を足す | 読めば確定 |

## 観点ごとの根拠

### 1. 完了の判定と義務

L40.29。全定理が `k : IntKind` と二値を量化し、具体の値に依存しない。`integerChecked_split` は正常（同じ数学値・同じ定数・`ValueRel`）と overflow（値域外）の二択を、`binary_checked`・`neg_checked`・`divMod_checked` は実 `OperationResult` がその検査であることを示す。`floor_delta_split` は 0除算・正常・overflow の三択、`floorModulo_normal` は全七幅で非零の除数の床剰余が表現可能であることを `Int.tmod` の評価から示す。`signed_minimum_stops` は `k.min < 0`・`a = k.min`・`b = −1` から absolute・床商・通常の商の overflow と床剰余の正常な0をともに結論する。前提は互いに両立し（Integer8 の具体値で確かめた）、空疎ではない。`shift_outside` は三つのシフトの任意の幅・任意の域外の count について、ビット値を計算する前の拒否を示す。後続の演算は使っていない。不足は軽3の overflow の条件の欠落である。

L40.33。`joinV`・`normalF`・`returnF`・`joinF`・`seqF` は detail F07 の字面と一致する。`joinV_mem` は全構成子の組を場合分けして左右の Mem を示しており、異幅の整数は unknown（Mem が常に真）に落ちるので健全である。`return_mem`・`join_left/right`・`seq_tail`・`seq_abrupt` は `EvalOutcome` の三形を全部扱う。各入口は子の導出と同じ `outcome` の所属から、親の導出を構成子で作り、所属を局所規則で結論する。親の導出の分解は結論せず、detail の「親実行の子への分解は L70」と合う。`boolean_branches` は真の枝で returned true、偽の枝で normal false を作り、`flow.NormalMem (.boolean true)` と `flow.ReturnedMem (.boolean false)` の否定を示す。`flow` の normal は `.boolean true false`、returned は `.boolean false true` に計算されるので、否定は成分の取り違えを実際に排除している。detail の「二系の書換えだけ」「任意 returned への所属だけ」でないことは満たす。不足は中1（分岐の構成子の範囲）と軽2（具体例の範囲）である。

L40.34。情報2のとおり前段の字面を保つ。`old_candidate_false` は後続の neg の拒否に実 δ の一致を求める全称命題を否定し、`revised_counterexample_accepted` は同じ反例で先の neg の位置・同じ実引数・`LeftError` を受け取る。`FirstFailureHandoff` は型付けや解析の所属を前提にせず、結論も最初の位置の分解と pure の δ の観測だけで、解析との無条件の一致を含まない。

L40.35。`escape_mark_member` は既存の `typed_returned_mark` を元の `StateTyE`・実 view・`ValueRel` で呼び、到達型と `EndState` に加えて、returned の値を `normalF f.returned` の通常成分へ移す。値の型付けは `normal_state_member` が元の `ClosureTy` の `ret_view_typed` から取り出し、別に仮定した値型を再掲していない（RV-L00b.13 軽1 の受け口に合う）。let・handler の escape は `ValueRel.close` による同じ値の移送である。error・exit の4葉の所属の内容は軽1のとおりである。第一候補は results.md の表で F1 の `tracked_failure_sound` を引用し、第二候補・全体の合成の残りと別の行に記録している。

義務。obligations.md の F2 の12行（O038・O058・O062・O090・O091・O124・O137・O169 ほか）は「担当分完了」と後段を分けて書き、全体の閉鎖を0行としている。O091・O169 の「normal/returned の局所所属」は中1の範囲を除いて対応する。

### 2. L40.29 と処理系の一致

`integerOutcome` の理由の写像（overflow→IntegerOverflow、zeroDivisor→DivisionByZero、残り→ArgumentOutOfDomain）は、Rust の `RuntimeError` の使い分けと一致する。

- 符号付きの absolute は `checked_abs` の失敗が IntegerOverflow（`narrow_integer.rs`・`integer.rs`）、符号なしは元の値（`unsigned!` の `absolute_value`、`unsigned_integer64.rs`）である。
- 床商は 0除算を先に検査し、`checked_div` の失敗（最小値÷−1）を IntegerOverflow とする。床剰余と通常の剰余は `checked_rem(b).unwrap_or(0)` で最小値 mod −1 が 0 になる（`int_modulo`、`signed.rs` の modulo、`narrow_integer.rs`）。符号なしの商と剰余は 0除算だけを返す。
- shift の count は `shift_amount(n, BITS−1, …)` が `u32::try_from` の失敗（負）と `BITS−1` を超える値を ArgumentOutOfDomain で拒否する。Lean の `count < 0 ∨ width ≤ count` と同じである。左シフトは幅から出たビットを捨て（`a << amount`）、Lean は `integerWrap` で同じ値になる。`shiftRightUnsigned` は符号付きの Integer8/16/32 と Integer（64）にだけあり、`integerDelta_shift` の `available` の条件と一致する。

Lean で次の境界値を `rfl` で確かめた（`<tmp>/rv-l40-f2/Check.lean`、終了0）。Integer8 の床商 −7÷2=−4、床剰余 −7 mod 2=1・7 mod −2=−1、−128÷−1 の床商・通常の商の overflow、床剰余と通常の剰余の 0、absolute(−128) の overflow・absolute(−127)=127、64≪1=−128、1≪7=−128、−1 の論理右シフト 1=127、−128≫7=−1、count 8 と −1 の拒否、5÷0 の DivisionByZero。UnsignedInteger16 の 0−1 の overflow、65535≪15=32768、count 16 の拒否。いずれも Rust の i8・u16 の結果と同じである。

### 3. F07 の定義の形

`joinV` の5節、`normalF a = ⟨a,bottom,false⟩`、`returnF f = ⟨bottom, joinV f.normal f.returned, f.mayFail⟩`、`joinF`、`seqF f g = ⟨g.normal, joinV f.returned g.returned, f.mayFail || g.mayFail⟩` は detail F07 の記述と一致する。ResultMem の規則は、return（三形）、順次（正常な head の値を束縛した tail と、head の returned/failed の伝播）、枝（`ite` のみ。中1）、腕（3×6）、Block（14構成子に一対一）である。正常な `bind` は `some value :: env.locals`、`bindPat` は同じ `PatternLocals` の束縛列の環境の tail を使い、abrupt の入口は tail の導出を受けない。guard の腕は `seqF h (joinF f g)` で、異常終了は `seq_abrupt`、真偽は `seq_tail` を通る。末尾の束縛・discard・pattern の結果は `seqF f (normalF .unknown)` であり、正常値 Unit は unknown に属するので健全である。

### 4. 署名・十言明・型付け・δ・公理

`git diff --stat 2719963c -- formal` は `formal/Benitoite.lean` の5行（import 4行と空行）だけである。新しい4ファイルは未追跡の追加で、既存の Lean のソースは変わっていない（verify.py の997本の照合とも一致）。新しい4ファイルを単独で検査し、いずれも終了0だった。`sorry`・`axiom`・`#eval`・工程の ID・手元の絶対パスは0件である。`#print axioms` を主な11定理（`signed_minimum_stops`・`floorModulo_normal`・`shift_outside`・`boolean_branches`・`wildcard_return_arm`・`first_failure_handoff`・`old_candidate_false`・`revised_counterexample_accepted`・`boolean_mark`・`escape_mark_member`・`typed_first_failure`）に実行し、すべて `propext`・`Classical.choice`・`Quot.sound` だけだった。全宣言の監査は担当の記録（78,752宣言、新公理0）を引用し、再実行していない。

### 5. 設計書の写し

01-12 の二つの ` ```lean ` のブロックは、`IntervalFlowLeaves.lean` と `FirstFailure.lean` の字面にそのまま含まれる（スクリプトで照合）。` ```text ` のブロックは増えていないので、`spec_examples` の読者に影響しない。改造の段名と未実装の作業は書いていない。言い回しの不一致は軽1・軽4、範囲の書き過ぎは中1である。07-04 の表の4行は各モジュールの内容と合う。

### 6. 記録

`inputs-final.json` の7ファイルの SHA-256 は今の作業木と一致した。`l40/f2/` は28ファイル・計314,385バイトで、100,000 バイトを超えるファイルはない。手元の絶対パス・`private/` の内容・docs/todo へのリンクはない（verify.py の docs/todo の語はリンクを拒む正規表現である）。checks.json の終了1の8件は results.md の「局所検査の失敗」に対応し、最後の単独検査・既定ビルド・work（11.160秒）は終了0である。

## 実行した検査

| 検査 | 内容 | 結果 | 外側の時間 |
|---|---|---|---:|
| `<tmp>/rv-l40-f2/Check.lean` | Integer8・UnsignedInteger16 の境界値21件の `rfl`、error 葉の所属が前提そのものである例、主な11定理の `#print axioms` | 終了0、許可三公理だけ | 約0.7秒 |
| `<tmp>/rv-l40-f2/Branch.lean` | 中1の修正の形（elseIfFalse・ifOnlyFalse・iteAbrupt の入口） | 終了0 | 約0.7秒 |
| 新しい4ファイルの単独検査 | `lake env lean -M 12288 Benitoite/Release/Refinement/<各>.lean` | 4件とも終了0、出力なし | 各数秒以内 |
| 写しの照合 | 01-12 の lean ブロックが本番の字面に含まれるか | 2件とも一致 | 1秒未満 |
| 記録の照合 | 最終入力の SHA-256、記録の大きさ、絶対パスの混入 | 一致、超過・混入なし | 1秒未満 |

## 再レビュー（再開1）

2026-11-04。担当の報告（再開1）と `l40/f2/results.md` の「再開1」、処置した部分の Lean（`StandardIntegerFailure` の `binary_delta_split`・`divMod_delta_split`・`tdiv_outside_minimum`・`division_overflow_iff`、`IntervalFlowLeaves` の新しい12入口と具体の読者8本、`IntervalControlLeaves` の error の2葉）、01-12・07-04 の変更した段落を読んだ。`lake build`・cargo・作業木を変える git の操作はしていない。

### 結論

**可**（重0・中0・軽2・情報3）。

中1は処置済みである。分岐9構成子・式の `block`・`matchInteger/matchWidth/matchResult/matchAbrupt` の入口は、それぞれ実際の構成子で親の導出を作り、既存の局所規則（`join_left/right`・`seq_tail`・`seq_abrupt`）で所属を結論する。具体の読者は具体の構文と環境に適用され、returned の側（`.boolean false true`）と normal の側（`.boolean true false`）に誤った値の所属がないことを示しており、否定の両側が意味を持つ。正常な bind の読者 `bound_boolean_return` は、head の true を実際に束縛した環境で tail の `local 0` を読む。`result_match_return` は標準の名前の `rangeResultMatch = some` と `ResultView.ok` を `rfl` で満たす。`matchOtherNormal/Failed` を L70 に残す理由（腕の導出を前提に持たず、結果は型だけが合う任意の通常値になる）は、`Eval.lean` の構成子の前提と一致し、妥当である。01-12・07-04 の写しは扱う構成子を名前で列挙しており、実装と一致する。

軽1〜4と情報1も処置済みである。`division_overflow_iff` は一般の `k`・`a`・`b` について両方向を証明しており、→ の方向は `tdiv_outside_minimum` が商の値域外から `k.min < 0 ∧ a = k.min ∧ b = −1` を導く。error の2葉は所属の前提と結論を除き、`source` だけを使う形になった。使わない前提は残っていない。既存の formal の変更は、まだ `formal/Benitoite.lean` の import だけである。

| # | 重さ | 場所 | 問題 | 修正案 | 根拠の種類 |
|---|---|---|---|---|---|
| 再軽1 | 軽 | `IntervalFlowLeaves` の `if_true_leaf`・`if_false_leaf`・`else_if_true_leaf`・`else_if_false_leaf`・`if_only_true_leaf`・`if_only_false_leaf` と、対応する `*_abrupt_leaf` | 同じ構文（ite・elseIf・ifOnly）について、真偽の入口は `joinF f g`（ifOnly は `joinF f (normalF .unknown)`）、異常終了の入口は `seqF h (joinF f g)` を結論する。条件の流れ `h` が前者に現れないので、同じ式の解析結果を一つの形で受ける後段は、`seq_tail` で橋を掛ける必要がある。match の入口は3つとも `seqF h f` で揃っている。橋は一行で済むことを `<tmp>/rv-l40-f2/R1.lean` で確かめた | 真偽の入口の結論を `seqF h (joinF f g)` に揃える（`seq_tail` を一段挟むだけ）か、L70 への受渡し表に「分岐の真偽の入口は条件の流れを含まない形で、`seq_tail` で揃える」と一行書く | 読めば確定、実行で確定 |
| 再軽2 | 軽 | `IntervalControlLeaves.error_let_member`・`error_mark_member` | 所属の前提と結論を除いたので、名前の `member` が中身と合わない。AGENTS.md の「名前と docstring は中身に合わせる」に反する。同じファイルの exit の2葉は `exit_let_typed` の形である | `error_let_typed`・`error_mark_typed` に改名し、適用例と 01-12・07-04 の参照（名前で引いていれば）を同じ変更で直す | 読めば確定 |
| 再情報1 | 情報 | `division_overflow_iff` の前提 `nonzero` | `b = 0` では両辺とも偽になるので、前提なしでも同値が成り立つ（`divMod_zero` で場合を分けて `<tmp>/rv-l40-f2/R1.lean` で証明した）。前提は証明の中で使われており、言明は偽にならない。読者の負担が一つ増えるだけである | 必要になったときに前提なしの系を足す。今は処置しなくてよい | 実行で確定 |
| 再情報2 | 情報 | `unit_if_only` | 肯定の側 `flow.NormalMem .other` は、`normalF .unknown` がどの値も含むので自明に真である（`.boolean true` でも成り立つ）。意味を持つのは `¬ flow.ReturnedMem .other` の側だけである。Unit を表す `ValueApprox` は unknown しかないので、今の近似ではこれ以上の区別はできない | なし | 実行で確定 |
| 再情報3 | 情報 | `abrupt_conditions` | `elseIfAbrupt` と `matchAbrupt` の所属は結論に入れていない（`_` で捨てている）。ただし、どちらも `if_abrupt_leaf` と同じ式 `seqF trueReturnFlow (joinF (normalF .bottom) (normalF .bottom))` に評価されるので、結論の `flow.ReturnedMem (.boolean true)` は四つの入口に共通の命題である | なし | 読めば確定 |

### 実行した検査

| 検査 | 内容 | 結果 | 外側の時間 |
|---|---|---|---:|
| `<tmp>/rv-l40-f2/R1.lean` | `division_overflow_iff` の前提なしの形、`unit_if_only` の肯定の側が自明であること、真偽と異常終了のフローの橋、再開1の9定理の `#print axioms` | 終了0。公理は `propext`・`Classical.choice`・`Quot.sound` だけ | 約1秒 |
| 新しい4ファイルの単独検査 | `lake env lean -M 12288 Benitoite/Release/Refinement/<各>.lean` | 4件とも終了0 | 各数秒 |
| 既存の formal の変更 | `git diff --stat 2719963c -- formal` | `formal/Benitoite.lean` の5行だけ | 1秒未満 |
| 記録の照合 | `inputs-final.json` の7ファイルの SHA-256、28ファイル・計330,815バイト・最大43,594バイト、絶対パスの混入 | 一致、100 KB の超過と混入はない | 1秒未満 |

## 取りまとめの追記

- 初回の中1・軽1〜4・情報1は担当の再開1で処置し、再レビュー（再開1）で可とした。再レビューの軽2件は担当の再開2で処置した（l40/f2/results.md の再開1・再開2）。情報2・3と再情報1〜3は処置しない。
- 群 F2 の作業末の work は終了0、420.51秒、最大常駐量 2,939,404,288 バイト（篩の部分の生成物を消して再ビルド。l40/f2/results.md）。
- 情報1（最初の失敗の位置の δ を `integerDelta` の具体の理由へ結ぶ接続）と `matchOtherNormal/matchOtherFailed` は L70 へ渡す。群 G の照合で受渡しの表に載っていることを確かめる。
