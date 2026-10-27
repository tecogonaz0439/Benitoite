# RV-L21T: 作業 L21T の定義・言明・仮定のレビュー

- 日付: 2026-10-26
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: コミット `045a6708` を取り出した別の作業ディレクトリ（`<review>`）。差分の基準は `f6ed14a8`（A18a の停止の記録と L21T の追加）。差分の範囲は `formal/Benitoite/Interval/` の Eval・Range・RangeState・BudgetRange・EvalClosed・Examples の6ファイル、01-12・07-04、l21t の記録と確認器、time-policy.md の1行である。`formal/` の Interval の外、`lakefile.toml`、`crates/`（固定表 `crates/benitoite/testdata/interval-budget/` を含む）は差分がない。
- 照合した文書: plan.md「計画の変更（2026-10-26、A18a の停止を受けて）」（L21T の行と、Q-opaque-L2 を行わない段落）、decisions.md の D15（追記を含む）・D18、a18a/results.md、a18a/opaque-study.md（案 A・B・第三案 C の比較）、a18a/surface-export/ の保存した交換（corpus.json・stdlib.json・builtins.json）、l21t/results.md・check-surface-types.py・surface-types.json・axioms.lean・axioms-final.log・formal-final.log・work.log、reviews/RV-C3.md（軽1 と形式）。言語仕様は 01-12「構文」、01-03「公開（初回リリース版）」、03-06 の Range の節、00-04 の「不透明型」の行、02-04 の E0340 の行。
- 方法: 読み取り、`git diff`・`git show`・grep による照合だけで行った。変更した6ファイルについて基準と HEAD の宣言を抜き出し、定理は最外側の `:=` まで、定義は本文全体を比べた（読み捨ての小さな Python スクリプト。抽出が後続の例まで含んだ `WarningSoundness`・`RangeOrigin.ResultModels`・`EvalClosed.map` の3件は、差分の hunk の位置で本文が不変であることを確かめた）。`.opaque`・`OpaqueName`・「不透明」の残りを Lean と設計書で探した。追加行の証明の穴・公理・特殊な指定を探し、`decide +kernel` の件数を基準とファイルごとに比べた。計算機のメモリの都合で `lake build`・`lake env lean`・cargo は実行していない。既定ビルドの成功、sorry 拒否、`#print axioms` の結果は l21t/results.md と、l21t の formal-final.log・work.log・axioms-final.log の記録に依った。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 0 |
| 軽 | 4 |

判定: 受け入れ。

中心二命題 `NormalSoundness`・`WarningSoundness` の本文は基準と同じである。`Models`・`SlotModels`・`LocalsModels`・`AbstractSlot`・`topSlot`（`Environment.lean`、差分なし）、`RangeOrigin.CheckedModels`・`ResultModels`（コメントだけの変更）、`EvalPartial`・`EvalArguments`・`Unmodeled`・`UnknownAt`・`rangeCallBinding`・`NormalTyped` も基準と同じである。公開の入口の主定理（`analyze_normal_sound`・`analyze_warning_sound`・`analyzeBase_*`・`analyzeBody_*`・`analyzeExpr_*`・`*_syntactic_reach`・`*_independent_sound` など）は、変更した6ファイルの外にあり、言明は変わらない。公理、`Builtins.Assumptions`、旧主定理、`lakefile.toml` も変わらない。

言明を変えた定理は13件で、l21t/results.md の記録（型の符号化だけの9件と、内部補助条件を加えた4件）と一致する。後者の `range_result_ok_models`・`range_ok_payload_models`・`range_match_ok_models` が受け取る `origin.names.ok ≠ origin.names.err` は、公開の入口に至る経路のすべてで既存の `range_result_match_distinct`（`rangeResultMatch` の認定）から構成されている（`baseResultArmEnv_ranges`・`range_match_selected_ok_models`）。条件を加えた理由も正しい。owner と error、ok と err が同じ名前の `RangeNames` では、型の頭だけで Error を除けず、旧言明は偽になる。一方、`range_bind_ok_models` には今、呼び出し元がない（軽1）。

評価関係では `EvalStandard` に四つの規則を加えただけで、既存の規則は変えていない。型が `.data owner []` になって `range_value_total` の対象に加わる値（`types = []` の一般の `.con`、同じ所有元の `rangeError`）にも、任意の正常 Integer64 と未知の失敗の導出がある。`checkedRange` への正確な射影とは構成子で分かれるので、`range_value_exact` の言明・証明は変わらず、意味も保たれる。実交換の型との一致、解析器の計上、固定表の不変も確かめた。残る所見は、補助定理の使用と例の弱まり（軽1）と、Lean と設計書の文言の残り（軽2〜軽4）であり、保証の向きには影響しない。

## 軽

### 軽1 `range_bind_ok_models` の呼び出し元がなくなり、合成の例がこの補題と `range_result_ok_models` を通らなくなった（読めば確定）

- 場所: `Range.lean` の `range_bind_ok_models`（621行付近）と、末尾近くの例「実際の成功値 5 と三欄を使い、Result の保存・Ok の束縛・直接射影を合成する」（1632行付近）。01-12「区間解析のResultの保存とOk束縛」の表の `range_bind_ok_models`・`range_match_ok_models` の行と、その下の「Ok と Error の構成子の非等号は…」の段落。l21t/results.md の「中心二命題・参照定義・補助言明・公理」の表。
- 問題: 基準では、この例は `range_bind_ok_models saved fromCheck known` と `range_result_ok_models fromCheck known` で、Result の由来（`ResultModels`）と Ok の認定（`IsOk`）から `CheckedModels` を導いていた。L21T は、任意の `names` に非等号を作れなかったため、`checkedModels` を既知の payload から直接作り、`range_extend_models` で束縛後の対応を組み立てる形に変えた。この結果、次の三点が生じた。
  - `range_bind_ok_models` は、`formal/` のどこからも使われない。新しい前提 `different` は、どの経路でも構成されていない。
  - 例は今も「Ok の束縛を合成する」と書くが、Ok の認定から三欄を導く段を通らない。中身は「既知の三欄を持つ値を束縛すれば射影できる」に弱まった。
  - results.md の表は、この補題を含む3件について「認定済み Result では既存の rangeResultMatch から構成する」と書く。`range_bind_ok_models` には当たらない。
  
  公開の定理の保証には影響しない。`range_result_ok_models` は `range_ok_payload_models` を通して公開の入口の経路で使われている。
- 修正案: 例に `(different : names.ok ≠ names.err)` の仮定を加えるか、`names` を具体的な名前（同じファイルの別の例の `"Std.Result.Ok"`・`"Std.Result.Error"`）に固定する。そのうえで、`range_bind_ok_models different saved fromCheck known` と `range_result_ok_models different fromCheck known` を使う形に戻す。例を戻さない場合は、`range_bind_ok_models` を消すか、01-12 の表の行に「独立の補題であり、解析の証明からは使わない」と書く。results.md の該当の行も直す。
- 時期: L21U（成功値の表現を変えるときに同じ補題と例を触る）。

### 軽2 07-04「01-12 との対応」の Range の段落に「同じ不透明型」が残り、同じ文書の追記と食い違う（読めば確定）

- 場所: 07-04「01-12 との対応」の253行（「`range_value_total` は同じ不透明型の全具体表現に導出を与え」）と257行（「`RangeNames.OkPayload` は other の Result から任意の同じ不透明型の成功値を取り出す導出も残す」）。
- 問題: L21T は同じ節の273行に「Range の型は `.data owner []` に揃え」る段落を加えた。しかし、253行・257行は書き換えていない。今の Lean では、`range_value_total` の対象は `.data owner []` 型であり、`OkPayload.other` の payload の型も `.data names.owner []` である。253行は、加えた `rangeValueCon`・`rangeValueError` にも触れない。plan.md の L21T の行は 07-04 の説明を直すことを範囲に含める。
- 修正案: 253行を「`range_value_total` は同じ `.data owner []` 型の全具体表現（other・checkedRange・一般の con・rangeError）に導出を与え」に、257行を「同じ `.data owner []` 型の成功値」に直す。あわせて、273行の段落と重なる記述を一方に寄せる。01-12 の追記にある「成功型とエラー型がともに data となったため」（1386行付近）は変更の経緯の書き方なので、「成功型とエラー型はともに data であり」に直す。「一般の三欄の `.con` も、この段階では」（1327行付近）の「この段階では」は、L21U で表現を変えるときに文ごと見直す。
- 時期: L21U と同じ変更（遅くとも A18b）。

### 軽3 Lean に `OpaqueName` の型別名と「不透明」のコメントが残る（読めば確定）

- 場所: `RangeBorrowed.lean` 246行の `borrowRangeValueCall (env : AbstractEnv) (input : EvalInput) : Option (OpaqueName × Nat)`。`Eval.lean` 653行の `RangeNames.OkPayload` のコメント「不透明な Result からの Ok 抽出にも導出を残すが」。
- 問題: L21T は `rangeValueCall`・`BudgetRange.rangeValueSource` の戻り値を `DataName × Nat` に直した。results.md も、最終点検で BudgetRange の `OpaqueName` を見つけて統一したと書く。しかし、同じ値を返す `borrowRangeValueCall` は `OpaqueName` のままである（`borrow_range_value_call_eq` で `rangeValueCall` と等しいことを示す関数）。`OpaqueName` と `DataName` はどちらも `String` の別名なので、ビルドと証明には影響しない。それでも、型だけを読む人には所有元が組み込みの不透明型の名前に見える。653行の「不透明な Result」は `other` で表した「内部を読まない Result」の意味である。これも、L21T が区別した組み込みの不透明型と紛らわしい。
- 修正案: `borrowRangeValueCall` の戻り値の型を `Option (DataName × Nat)` に直す。653行のコメントを「内部を読まない other の Result からの Ok 抽出にも…」に直す。
- 時期: L21U。

### 軽4 01-12 の新しい【決定】が E0340 の対象を言い換えて狭め、01-03 を参照しない（読めば確定）

- 場所: 01-12「区間解析のRangeの評価規則と小モデル」の二つ目の【決定】（1293行）の「名前解決が外部からの構築・分解・欄の取得と更新を E0340 で拒否する」。
- 問題: 規範は 01-03「公開（初回リリース版）」の271行にある。そこでは、外部での構成子の参照・値化・呼び出し・部分適用・パターン、レコードの構築・更新・パターン、自動アクセサの参照を E0340 の対象とする。01-12 の言い換えは、構成子の参照・値化・部分適用を明示せず、規範より狭く読める。03-06 の Range の節（157行）も「構築・更新・パターン・自動アクセサ」と書く。三章の表現がそろわず、01-12 は規範への参照を欠く。説明の筋（「不透明」は公開境界の意味であり、コアの `O`・`.opaque` とは別であること）は、01-12「構文」の84〜85行、00-04 の「不透明型」の定義、03-06 と一致しており、問題はない。
- 修正案: 「外部での内部表現の使用は、名前解決が E0340 で拒否する（[名前とモジュール](01-03-names-modules.md)の「公開（初回リリース版）」）」のように、規範を参照する形に直す。
- 時期: L21U と同じ変更（遅くとも A18b）。

## 確かめて問題がなかった観点

1. 言明と仮定: 変更した6ファイルで言明が変わった定理は13件である。その一覧は l21t/results.md と internal-statement-diff.json の記録に一致する。型の符号化だけの9件は、`range_finish_ok`・`range_ok_identity`・`range_other_possible`・`range_value_total`・`range_check_at_total`・`range_other_at_possible`・`range_result_names_type`・`range_result_models_type` と、Examples の `projection_run` である。消えた定理はない。公開の入口の主定理は変更したファイルの外にあり、参照する定義の変更でも意味は弱まらない（次項）。追加した `different` の前提は、`rangeResultNames` が `names.ok ≠ names.err` をもともと要求していることから得ている。解析・計上・公開の前提は増えていない。D15 の追記の範囲（内部の補助定理への条件の追加）に収まる。
2. 参照定義の向き: `EvalStandard` に `rangeValueCon`・`rangeValueConFailed`・`rangeValueError`・`rangeValueErrorFailed` を加えた。これは導出を増やす向きであり、中心二命題が量化する実行を増やすので、主張は弱まらない。型が `.data owner []` の `ConcreteValue` は、`other`・`checkedRange`・`rangeError`・`types = []` の `con` の四種に限られる。`range_value_total` はその全てに導出を構成する。`standardCall` の引数は `argumentType` で評価されるので、正常値はこの型を持つ。Range の引数について導出の欠落による空虚化はない。`.other (.opaque owner)` の旧規則は `.other (.data owner [])` に置き換わった。`argumentType` が data になったので、旧形の値は引数に来ない。`ConcreteValue`・`SlotModels`・`Models` に値を除く条件は加わっていない。`IsOk`・`OkPayload`・`ResultView`・`rangeResultNames`・`rangeResultViewable`・`resultView`・`StandardRule.finish`・`resultType` は、同じ置き換えを一貫して行っている。`range_result_match_view` も `types = []` の場合分けを加えて全域性を保つ。一般の match に来た `checkedRange` は従来どおり `matchOther*` に入る。閉じた評価器 `ClosedEval.standard` は、`checkedRange` だけを決定的に射影し、`other`・`con`・`rangeError` には `none` を返す（Examples の新しい `#guard` が確かめる）。`sameType` の `.opaque` の分岐、`withE` のリソースの `topSlot (some (.opaque owner))`（BudgetChildren・BudgetDiscover・Analyze）と BudgetChildrenExamples の例は変わらない。
3. 実交換との一致: l21t/check-surface-types.py は、a18a/surface-export/ の保存した交換をそのまま読む。a18a の確認器との差は、期待型を `{"data": {"name": …, "args": []}}` に変えたことと、Lean のファイルのハッシュの記録だけである。surface-types.json では、checkInteger の戻り値 `data:212[data:525[], data:529[]]`、三引数の Integer、value の引数 `data:525[]`、戻り値の Integer の四箇所が一致し、allEqual は true である。交換の読み取り（`Exchange/Syntax.lean` の `decodeTy`）は `data` を `.data name args` に写す。axioms.lean の末尾の二例は、`StandardRule` の型がこの期待型と同じであることを `rfl` で確かめる（成功は記録に依った）。builtins.json の CheckedInteger は三つの Integer の欄を持つ一構成子のレコードである。これは今、`rangeValueCon` の任意値の規則で扱われる。正確な射影は `checkedRange` に限られ、その点は 07-04 の A1 の限界に書かれている。
4. 解析器の計上: BudgetRange の変更は、`rangeNames`・`rangeNameResult`・`rangeMatch` の型のパターンと `rangeValueSource` の型別名だけである。`tick`・`frame`・走査の順序と回数・停止位置は変わらない。同じ表現の入力に対する計上は同じである。実交換の data の入力では、Result の認定が成功するようになる。これが L21T の目的である。固定表の元入力は標準表が空なので、影響を受けない。固定表7ファイル（`crates/benitoite/testdata/interval-budget/`）は差分がない。
5. 01-12・07-04: 01-12 の `RangeNames.IsOk` の写しは Lean と一致する。追加した識別子（`rangeValueCon`・`rangeValueError` など）は Lean に実在する。D18 の「不透明」を公開境界とする説明は、01-12「構文」の「`@opaque` のdata・レコードも内部構造を持つ `D` で表す」「`O` は等値を持たない組み込みの不透明型」と、00-04 の「不透明型」（`@opaque` の data・レコードと組み込みの型の両方を含む）に合う（言い換えの範囲は軽4）。07-04 の A1 の限界の追記（`.data owner []` を使うこと、`checkedRange` を使い一般の三欄の `.con` に統一していないこと）は、今の Lean と一致する。後者の一文は、取りまとめのレビューのとおり L21U で消す。
6. 証明の穴: 追加行に `sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`extern`・`unsafe`・`partial def`・`set_option`・`maxHeartbeats` はない。`decide +kernel` の件数は、変更した6ファイルのいずれも基準と同じである（Range 3件、Examples 32件）。追加・削除した `decide +kernel` の行はない。新しい例は、導出の構成と `#guard` による閉じた評価器の実行だけで、解析器や評価器を kernel で展開しない。公理の依存は、axioms-final.log の83宣言で propext・Classical.choice・Quot.sound の範囲内であり、sorryAx はない（記録に依った）。

## 読めば確定する所見と、実行しないと分からない点

- 読めば確定: 軽1〜軽4。軽1 の「呼び出し元がない」は `git grep` で確かめた。軽2〜軽4 は文言の照合で確かめた。
- 実行しないと分からない点: 既定ビルドの成功・sorry がないこと・公理依存・Examples の新しい `#guard` の成功（l21t/results.md、formal-final.log、work.log、axioms-final.log に依った）。surface-types.json は確認器の出力を読んだだけで、確認器は再実行していない。RV-C3 の軽1 の構造（`rangeCallBinding` が型を照合しないので、型の注記が標準表と違う入力には導出がない）は今も残る。今回は実交換の data の符号化に揃えて閉じた。全 Range 入力での一致は、計画どおり A18a・X02 で確かめる必要がある。
