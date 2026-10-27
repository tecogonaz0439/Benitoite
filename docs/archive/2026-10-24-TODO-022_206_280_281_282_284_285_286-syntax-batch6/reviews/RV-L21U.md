# RV-L21U: 作業 L21U の定義・言明・仮定のレビュー

- 日付: 2026-10-26
- 担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）
- 対象: コミット `a7944afa` を取り出した別の作業ディレクトリ（`<review>`）。差分の基準は `060eee90`（L21U の追加）。差分の範囲は `formal/Benitoite/Interval/` の Eval・Range・RangeState・EvalClosed・BudgetRange・RangeBorrowed・Examples・SyntacticReachExamples の8ファイル、01-12・07-04、l21u の記録と確認器、reviews/RV-L21T.md と応答、time-policy.md の1行である。`formal/` の Interval の外、`lakefile.toml`、`crates/`（固定表 `crates/benitoite/testdata/interval-budget/` を含む）、`scripts/`、`Cargo.toml`・`Cargo.lock` は差分がない。
- 照合した文書: plan.md「計画の変更（2026-10-26、A18a の停止を受けて）」の L21U の行と前後の段落、a18a/opaque-study.md の Q-opaque-L2 の行、a18a/surface-export/builtins.json の `data:212`・`data:525`・`data:529` の宣言、l21u/results.md・check-surface-types.py・surface-check.lean・internal-statement-diff.json・axioms.log・formal-final.log、reviews/RV-L21T.md と RV-L21T-response.md、`formal/Benitoite/Checked/Range.lean`（`CheckedInteger`・`rawMake`・`erase`・`make_ok`）。
- 方法: 読み取り、`git diff`・`git show`・grep による照合だけで行った。変更した8ファイルについて基準と HEAD の宣言を抜き出し、定理は最初の `:=` まで、定義は本文全体を比べた（読み捨ての小さな Python スクリプト）。旧表現（`checkedRange`・`rangeValueOther`・`rangeValueCon`・`rangeValueError`・`rangeValueUnrepresentable`）、`OpaqueName`・「不透明」、交換の番号（`data:`・`con:`）の残りを Lean と設計書で探した。追加行の証明の穴・公理・特殊な指定を探し、`decide +kernel` の件数を基準とファイルごとに比べた。計算機のメモリの都合で `lake build`・`lake env lean`・cargo は実行していない。既定ビルドの成功、sorry 拒否、`#print axioms` の結果、`surface-check.lean` と Examples の `#guard` の成功は、l21u/results.md と l21u の formal-final.log・work.log・axioms.log・surface-check.json・examples-final.json の記録に依った。

## 所見の要約

| 区分 | 件数 |
|---|---:|
| 重大 | 0 |
| 中 | 0 |
| 軽 | 5 |

判定: 受け入れ。

中心二命題 `NormalSoundness`・`WarningSoundness` の本文は基準と同じである。`Models`・`SlotModels`・`AbstractSlot`・`topSlot`（差分のないファイル）、`RangeOrigin.ResultModels`・`RangeLocalFact.Models`・`RangeState.Models`、`EvalPartial`・`Unmodeled`・`UnknownAt`・`rangeCallBinding`・`NormalTyped`・`IsOk`・`OkPayload`・`rangeResultNames` の本文も基準と同じである。公開の入口の主定理（`analyze_normal_sound`・`analyze_warning_sound` など）は変更したファイルの外にあり、言明は変わらない。axioms.log では、両主定理の依存は `propext`・`Classical.choice`・`Quot.sound` だけである（記録に依った）。

言明を変えた定理は14件で、l21u/results.md の一覧と internal-statement-diff.json に一致する。新しい定理は `range_payload_stored` の1件、消えた定理はない。`RangeOrigin.CheckedModels` は表現を `checkedRange` から三欄の `.con` に移した。値の側の所属と有界性は旧定義（`CheckedInteger.bounded` と `IntegerRepresentable`）と同じ強さである。一方、呼び出しキーの一致は条件から外れた（軽3）。`CheckedModels` が現れるのは補助の `RangeState.Models` の中だけであり、公開の入口は空または忘却済みの記録から始まる。このため、この変更は公開の言明に影響しない。言明を変えた内部の補助定理の新しい前提（`range_value_exact` の `stored`、`range_value_origin_mem` などの `origin.names.record` の照合）は、呼び出し元で `range_payload_stored` と `range_value_origin_source` から構成されている。呼び出し元の言明は変わっていない。

評価関係では、`EvalStandard` の rangeValue の規則を3本（正確な射影、未知の正常値、未知の失敗）に整理した。正確な射影は `rangeStoredValue record input = some value` を、未知の二規則は `= none` を前提とするので、規則は重ならない。`range_value_exact` は意味を保つ。未知の規則は旧規則より多くの入力（`other`、誤った所有元・構成子・型引数・欄数・欄の型の `.con`、`rangeError`、型の違う値）に導出を与える。中心二命題が量化する実行を増やす向きであり、主張は弱まらない。外した `rangeValueUnrepresentable` は、消した `checkedRange` の表現だけを対象にしていた。`ConcreteValue.integer` は Integer64 だけを持つので、三欄は表現可能な値に限られる。未知の表現への導出は欠けていない。構成子の同定は実交換から来ており、Lean と設計書に交換の番号は現れない。計上と固定表も変わっていない。残る所見は、設計書と補助定理の文言の食い違い（軽1・軽3・軽5）、独立の補助定理の言明の弱まり（軽2）、前回の所見の対応の誤り（軽4）であり、中心二命題と公開の入口の保証には影響しない。

## 軽

### 軽1 01-12 の標準束縛の【決定】に、旧表現の説明が残る（読めば確定）

- 場所: 01-12「区間解析の対象構文の評価関係」の、標準束縛の評価規則の【決定】（1266行）。「成功は三欄と所属、失敗は…を保存する。`range_success_fields` は成功値の呼び出しのキー・三欄・所属の保存を示す。`rangeValue` は同じ所有元の成功値から、表現可能な value を取り出す。」
- 問題: L21U の後の Lean では、`rangeCheck` は呼び出しキーを使わない（`Eval.lean` 300行の `_key`）。成功値 `rangePayload names.record lo hi value` も、キーと所属の証拠を持たない。`range_success_fields` の結論は `output = rangePayload names.record lo hi value ∧ InRange …` であり、キーを含まない。`rangeValue` は所有元だけでなく構成子・型引数なし・三欄・各欄の Integer64 型を `rangeStoredValue` で認定する。三欄はもとから有界なので、「表現可能な value」という限定はもう要らない。同じ章の1184行と1325行以降は新しい表現に直したが、この段落だけが旧表現のまま残った。
- 修正案: 「成功は元の三入力を三欄に、失敗は…を保存する。`range_success_fields` は成功値が元の三入力の三欄であり、value が閉区間に属することを示す。`rangeValue` は、`rangeStoredValue` が所有元・レコード構成子・型引数・三欄の型を認定した値から、保存した value を取り出す。」のように直す。
- 時期: L21U の後の修正の枝（RV-L21T の残りと合わせる）。

### 軽2 `range_check_small_model` の成功の場合で、小モデルの三欄と成功値の三欄の対応が言明から抜けた（読めば確定）

- 場所: `Range.lean` 95行の `range_check_small_model` の `.ok raw` の腕。01-12 の表の `range_check_small_model` の行（1318行）。results.md の内部言明の表の同じ行。
- 問題: 新しい言明は `∃ checked, rangeCheck … = .normal (rangePayload names.record lo hi value) ∧ Checked.Range.erase checked = raw` である。基準では成功値が `checked` を含んでいた（`.checkedRange names.owner key checked`）ので、二つ目の連言が成功値の三欄と `raw` を結んでいた。今は `checked` が成功値に現れない。二つ目の連言は「`raw` は何かの `CheckedInteger` を消した値である」という、成功値と無関係な事実になった。`raw = ⟨lo.toInt, hi.toInt, value.toInt⟩` は `rawMake` を展開すれば分かるが、言明には書かれていない。01-12 の表は「rawMake の成功の三欄…が標準の検査規則と一致することを示す」と書き、results.md は「erase の対応は保持」と書く。この定理は独立の補助定理であり、`formal/` のどこからも呼ばれない。そのため、公開の保証には影響しない。
- 修正案: `.ok raw` の腕を `rangeCheck names key lo hi value = .normal (rangePayload names.record lo hi value) ∧ raw = ⟨lo.toInt, hi.toInt, value.toInt⟩` にする。`erase_make` を通す形を残すなら、`∃ checked, Checked.Range.make lo.toInt hi.toInt value.toInt = .ok checked ∧ Checked.Range.erase checked = raw ∧ rangeCheck … = .normal (rangePayload names.record checked.minimum … )` のように、成功値の三欄を `checked` から作る形にする。results.md の行も直す。
- 時期: L21U の後の修正の枝。

### 軽3 呼び出しキーが `ResultModels`・`CheckedModels` の意味から外れたのに、文書は意味の上でキーに対応させると読める（読めば確定）

- 場所: `RangeState.lean` 58行の `ResultModels` のコメント「この検査が返した Result だけを表す」、67行の `CheckedModels`。07-04「01-12 との対応」の257行の「`range_checked_origin_models`・`range_checked_models_mem` は由来の呼び出しキーと同じ成功値の三欄を対応させ」。01-12 の1522行の「それぞれの呼び出しキーと局所位置に対応させる」。results.md の「実値・由来・射影の契約」の「ResultModels は従来どおり、同じキー・二端点に対する実際の検査結果との一致を定める」。
- 問題: `rangeCheck` がキーを使わなくなったので、`ResultModels origin result` は `origin.checkKey` によらない。同じ `names` と同じ二端点を持つ別の検査が返した Result も、この関係を満たす。`CheckedModels` の本文にもキーは現れない。基準では成功値がキーを含んでいたので、この二つの関係はキーで個体を区別していた。今、個体を区別するのは `RangeLocalFact.checked` の束縛番号と、解析の認定（`rangeCallOrigin` の `origin.checkKey = input.key`）だけである。区間は二端点だけで決まるので、健全性は損なわれない。Examples の「二つ目の成功値は…[0,10] を共有しない」の例も、基準のキーの照合を二端点の照合（`bounds`）に置き換えた。そのうえで、端点の違う二個体を区別できている。しかし、上の4箇所の書き方では、キーが具体値との関係の条件に残っているように読める。
- 修正案: `ResultModels` のコメントを「同じ標準規則と二端点の検査が返し得る Result を表す。具体値は呼び出しキーによらない」の趣旨に直す。07-04 の257行は「由来の二端点と同じ成功値の三欄を対応させ」とし、キーは解析の認定と記録の側にあると書く。results.md の文から「同じキー・」を除く。01-12 の1522行は、解析の記録がキーと局所位置を持つことを述べる文として残してよいが、具体値の関係がキーで区別するとは書かない。
- 時期: L21U の後の修正の枝。

### 軽4 RV-L21T の軽3 のコメント「不透明な Result」が残っているのに、対応済みと記録した（読めば確定）

- 場所: `Eval.lean` 651行の `RangeNames.OkPayload` のコメント「不透明な Result からの Ok 抽出にも導出を残すが、三欄を仮定しない。」。RV-L21T-response.md の軽3 の行（「L21U で消えた」「対応済み（L21U）」）。results.md「取りまとめのレビュー（2026-10-26）」の「軽3 の `OpaqueName`・コメントはこの変更で消えた」。
- 問題: `borrowRangeValueCall` の `OpaqueName` は `RangeRecord × Nat` に変わり、解消した。一方、651行のコメントは基準（653行）から一字も変わっていない。ここでの「不透明」は、`other` で表した「内部を読まない Result」の意味である。D18 の区別（公開境界の「不透明」とコアの `.opaque`）と紛らわしい点は、RV-L21T のとおり残る。
- 修正案: コメントを「内部を読まない other の Result からの Ok 抽出にも導出を残すが、三欄を仮定しない。」に直す。応答と results.md の記述を「`OpaqueName` は L21U で解消、コメントは修正の枝で直す」に改める。
- 時期: L21U の後の修正の枝。

### 軽5 01-12 の新しい【決定】が、実装していない同定の手順を処理系の動作として書く（読めば確定）

- 場所: 01-12「区間解析のRangeの評価規則と小モデル」の1325行の【決定】の「実交換の checkInteger の戻り値と value の引数の型から所有元を取得し、その所有元のレコード宣言の構成子を同定する。型名・構成子の表示名から推測しない。」。同じ節の1311行の「解決済みの表と実ソースの宣言の一致は、この関係の証明には含めない」。
- 問題: `RangeNames`（`checkedConstructor` を含む）は、`StandardRule.rangeCheck` の引数として外から与える値である。`formal/` にも `crates/benitoite/src/` にも、交換から `RangeNames` を作るコードはない（`RangeNames` を含むのは Interval の7ファイルだけで、どれも名前を受け取るか、例で合成した名前を使う）。交換から所有元と構成子を取り出す手順は、改造のディレクトリの確認器 `l21u/check-surface-types.py` が、保存した `range.bnt` の交換一つについて行っただけである。設計書は処理系が今実装している内容だけを書くので、1325行は、実装した動作として書くには強すぎる。同じ節の1311行とも食い違って読める。07-04 の122行（「保存した実交換の型・レコード構成子宣言から同定し、新しい定義との一致を確認した」）は、確認の事実として正しく書けている。
- 修正案: 1325行を「`RangeNames` は CheckedInteger の所有元とレコード構成子の同一性を持ち、`RangeNames.record` がこの二つを `RangeRecord` にまとめて `StandardRule.rangeValue` へ渡す。標準表の名前が実交換の宣言と一致することは入力の条件であり、評価規則は型名や構成子の表示名を照合しない。」のように、入力の条件と照合しないことの宣言に直す。保存した交換との照合の事実は、07-04 の A1 の段落に置いたままでよい。
- 時期: L21U の後の修正の枝（遅くとも A18b）。

## RV-L21T の所見の解消状況

| RV-L21T の所見 | L21U の後の状態 | 根拠 |
|---|---|---|
| 軽1 `range_bind_ok_models` の呼び出し元がなく、例が Ok の認定を通らない | 残る | `range_bind_ok_models`（`Range.lean` 598行）を使う箇所は `formal/` にない。1606行の例は今も「Ok の束縛を合成する」と書くが、`checkedModels` を既知の payload から直接作る（1654行）。01-12 の1403行は今も4件の補題が非等号を受け取ると書き、`range_bind_ok_models` を含める |
| 軽2 07-04 の「同じ不透明型」、01-12 の経緯の書き方 | 07-04 の2箇所と 01-12 の「この段階では」は解消。01-12 の「成功型とエラー型がともに data となったため」（1403行）は残る | 07-04 の257行・253行相当は「同じ data 型」に直った。旧1327行の段落は書き換えで消えた |
| 軽3 `OpaqueName` と「不透明」のコメント | `OpaqueName` は解消。コメントは残る（本書の軽4） | `RangeBorrowed.lean` 246行は `Option (RangeRecord × Nat)`。`Eval.lean` 651行は基準と同じ |
| 軽4 E0340 の言い換え | 残る | 01-12 の1293行は今も「外部からの構築・分解・欄の取得と更新を E0340 で拒否する」と書き、01-03 を参照しない |

## 確かめて問題がなかった観点

1. 言明と仮定: 変更した8ファイルで言明が変わった定理は14件である（`range_success_fields`・`range_success_representable`・`range_check_small_model`・`range_value_exact`・`range_success_projection`・`range_evaluated_projection`・`range_other_possible`・`range_other_at_possible`・`range_value_total`・`range_checked_models_mem`・`range_value_origin_source`・`range_value_origin_mem`・`range_value_interval_mem`・`range_value_origin_total`）。一覧は results.md と internal-statement-diff.json に一致する。`range_value_total` の型の前提は使われなくなり（`_typed`）、全入力に導出を与える形になった。言明は強まる向きである。`range_success_representable` の表現可能性の三項は、`Integer64Value` の型から直ちに出る。公開の前提は増えていない。
2. 参照定義の向き: `ConcreteValue` から `checkedRange` を消しただけで、他の構成子と `ConcreteValue.type` の規則は変わらない。`rangeStoredValue` は `.con owner [] constructor [.integer _, .integer _, .integer value]` の形だけを受け、所有元と構成子を `RangeRecord` と照合する。`.integer` は Integer64 だけを持つので、各欄の型の照合も形に含まれる。欄の数が3でないもの、型引数のあるもの、Integer64 以外の欄を持つものは `none` になる。`rangeCheck` の成功は元の三入力の `rangePayload` であり、`range_payload_stored` がその value を正確に読み出すことを示す。`range_value_exact` は `some`/`none` の排他性で証明され、未知の規則が正確な射影に重ならないことを保つ。`EvalClosed.standard` は認定した三欄だけを決定的に射影し、未認定の入力には `none` を返す。非決定的な規則から値を選ばない。`StandardRule.argumentType` は `record.owner` を読むだけで、型は L21T と同じである。`Models`・`SlotModels` に値を除く条件は加わっていない。
3. 構成子の同定: `l21u/check-surface-types.py` は、所有元を `upperEndpoint` の解決済み `checkInteger` の標準署名の戻り値の型引数から取る。その所有元をキーに builtins.json の `dataDecls` を引き、引数なしのレコードで構成子が一つであること、三つの Integer の引数、欄の順 minimum/maximum/value を確かめる。構成子の名前はその宣言の `name` をそのまま使い、`typeName`・`constructorName` の表示名は読まない。builtins.json の `data:525` は `isRecord: true`・`ntys: 0`・構成子 `con:525:0`・欄 `["minimum","maximum","value"]`・三つの Integer であり、確認器の記録と一致する。`formal/` と `docs/design/` に `data:`・`con:` の番号は現れない。番号は生成した照合入力 `l21u/surface-check.lean` の中だけにあり、Lean の定理の言明はどれも番号に依存しない。Lean の例は合成した名前（`"Std.Range.CheckedInteger.record"`、`"User.constructor"` など）を使い、誤った構成子との区別は名前の不一致だけに依っている。
4. 解析器の計上: BudgetRange の差分は、`rangeValueSource` の戻り値の型と `rangeValue` の照合（`origin.names.owner = owner` から `origin.names.record = owner`）、その証明の `by_cases` の3行だけである。`tick`・`frame`・走査の順序と回数・停止位置は変わらない。`RangeBorrowed` の差分も戻り値の型の1行だけである。固定表7ファイルは差分がない。
5. 01-12・07-04: 01-12 の `RangeRecord`・`rangePayload`・`rangeStoredValue`・`CheckedModels`・`rangeValueOrigin` の写しは Lean と一致する。新しく書いた識別子（`rangeValueUnknown`・`rangeValueUnknownFailed`・`range_payload_stored`・`RangeNames.record`）は Lean に実在する。07-04 の A1 の段落から「一般の三欄の `.con` には統一していない」の一文は消え、成功値の形と照合の範囲（保存した交換との局所照合で、全 Range 入力と VM との比較は未実施）に置き換わった。旧規則名と `checkedRange` は、設計書と Lean のどちらにも残っていない（軽1 の1266行は規則名ではなく旧表現の説明）。
6. 証明の穴: 追加行に `sorry`・`admit`・`axiom`・`native_decide`・`implemented_by`・`extern`・`unsafe`・`partial def`・`set_option`・`maxHeartbeats`・`decide +kernel` はない。`decide +kernel` の件数は、変更した8ファイルのいずれも基準と同じである（Range 3件、RangeBorrowed 2件、Examples 32件、SyntacticReachExamples 5件、ほかは0件）。新しい例は導出の構成と `#guard` による閉じた評価器の実行だけで、解析器や評価器を kernel で展開しない。axioms.log の85宣言の依存は `propext`・`Classical.choice`・`Quot.sound` の範囲内で、`sorryAx` はない（記録に依った）。

## 読めば確定する所見と、実行しないと分からない点

- 読めば確定: 軽1〜軽5 と、RV-L21T の残りの3件。軽2 の「呼び出し元がない」と軽5 の「交換から `RangeNames` を作るコードがない」は grep で確かめた。軽4 は基準との文字列の比較で確かめた。
- 実行しないと分からない点: 既定ビルドの成功、sorry がないこと、公理の依存、Examples の新しい `#guard`（未認定の8値の閉じた評価が `none`、正しい三欄の射影が5）、`surface-check.lean` の `rfl` と `#guard` の成功。いずれも l21u/results.md と同じディレクトリの記録に依った。確認器は再実行していない。surface-types.json と builtins.json の該当する宣言は、読んで一致を確かめた。全 Range 入力での型と構成子の一致、実 VM の三欄・成否・射影との一致は、計画どおり A18a・X02・X03 で確かめる必要がある。RV-C3 の軽1 の構造（`rangeCallBinding` は型を照合しないので、型の注記が標準表と違う入力には導出がない）は今も残り、A18a・X02 へ引き継ぐ。
