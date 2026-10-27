# L29R の実装結果

着手（最初の時刻取得）: **2026-10-26 19:00:29 JST**。終了: **2026-10-26 19:15:59 JST**。所要時間: **15分30秒**。時刻取得より前の指示の読み込みは、この計測に含めていない。

**状態: RV-C5 の中1・中2・軽1・軽3の修正、局所検査、指定 work、定義・言明・仮定の差分確認を完了した。独立レビューと受け入れは取りまとめへ引き渡す。**

B_WORK と HEAD はともに `e44ab9c0588e1cdfc0ead2e7a3a82f30e522fa63`、ブランチは `mod012/L29R`。着手時の未コミット差分はなかった。plan の「計画の変更（2026-10-26、RV-C5 を受けて）」の L29R 行、前提・契約・L28・L29・検査の割り当て、RV-C5 と対応、l27a〜l29 の結果、decisions の D5・D15・D17・D20、README の設計者の決定、preflight、study の9.4、現行設計書と実装を確認した。private/ とそこを指すリンクは読まず、git の変更操作と担当の委任を行っていない。

## 変更した範囲

| 対象 | 内容 |
|---|---|
| [Exchange.lean](../../../../formal/Benitoite/Interval/Exchange.lean) の Top 判定（中1） | 根の型と、別本体の元の型表の末尾の型を使う既存の分類を保ち、整数・Boolean 以外では `nonIntegerOther` だけを判定する。Unit の全正常値を Integer64 の Bottom だけで非Topと数えない |
| 同上の本体の期待（中2） | `BodyExpected.analyzed Expected` と `BodyExpected.notAnalyzed Json` を区別する。元定義の expected と別本体の expectedBodies の両方で `{"notAnalyzed": 停止理由}` を読める。未着手の本体に期待があれば停止理由まで照合する。通常の期待が残る場合、停止理由が異なる場合、解析済みの本体へ未着手を期待した場合は不一致となる |
| 同上の入力全体の期待（中2） | input に任意の `expected` を加え、`after`・`phaseStops`・`counts` の各欄を独立に指定可能にした。指定した欄だけを最終報告と厳密に比較し、不一致を input の mismatches と matched・accepted へ反映する。counts を指定する場合は五つの専用射影を全て要求する。段の順序・位置・分類・保存済み状態も比較する |
| [ExchangeExamples.lean](../../../../formal/Benitoite/Interval/ExchangeExamples.lean)（軽1） | profile の拒否を future に変更し、`unsupported interval profile` という意図した理由まで `#guard` で確認する。BodyExpected と Input の欄追加に伴う既存例の取り出しも更新した |
| [IntervalDiff/Main.lean](../../../../formal/IntervalDiff/Main.lean)（軽3） | INPUT と REPORT を `IO.FS.realPath` で比較する。まだ存在しない REPORT は親ディレクトリの実パスとファイル名を使う。同一なら読み込み・書き込みの前に終了2となる。報告先の解決に失敗した場合も、元の REPORT の指定をエラーへ残す |
| [test_interval_exchange.py](../../../../formal/tests/test_interval_exchange.py) | l28・l29 から引き継ぐ同じ入力生成・実CLIの境界に、Unit の Top、未着手の元定義・別本体、古い期待の拒否、入力全体の三欄、段停止の位置・順序・context、深い不正欄、パス別名の退行例を追加した。既存の whole-budget-0/1 は未着手の期待と最終状態・段停止・件数を明示する形に改めた |
| [01-12 の写し](../../../design/01-spec/01-12-core-calculus.md#区間解析の独立交換の読者)・[07-04 の対応](../../../design/07-quality/07-04-formal-semantics.md#区間解析の独立交換の読者) | 交換の型・欄・Top分類・未着手と入力全体の比較・パスの判定を実装とそろえた。見出しは改名していない |

入力全体の期待の形は次のとおりである。after・phaseStops・counts はそれぞれ省略できる。停止理由は coverage と同じ halt、または保存済みの理由がない場合の `"entryUnavailable"` とする。未知の欄・停止段・停止理由、欠けた件数、不正な状態や十進文字列は深い位置でも読者が拒否する。

```json
{
  "expected": {
    "after": {"body": {"operations": "0", "temporary": "0", "saved": "0", "peak": "0"}, "whole": {"operations": "0", "saved": "0", "peak": "0"}},
    "phaseStops": [{"phase": "whole", "reason": {"kind": "exceeded", "scope": "whole", "resource": "operations"}}],
    "counts": {"inputDefinitions": "1", "unsupportedBodies": "0", "bodyBudgetExceeded": "0", "unidentifiedBodies": "0", "wholeBudgetSkipped": "1"}
  }
}
```

上は全体操作上限0の入力全体の期待であり、その元定義の expected は `{"notAnalyzed":{"kind":"exceeded","scope":"whole","resource":"operations"}}` とする。未着手の照合は正常範囲の比較件数へ足さない。深さで停止した解析済み本体の正常範囲の除外、空・全Top・深さ除外を受け入れない条件、mayFail を観測専用とする条件は保っている。既存の l28・l29 の検査記録とZIPは過去の実施記録として変更していない。

## 修正前の再現と局所検査

[修正前の観測](reproduction.json)と同名の入力・報告で、中1と中2を既存の実行器から再現した。Unit の1本体は matched・accepted が真、informativeCount が1、終了0だった。全体操作上限0・1は通常の正常値の期待が残っていても matched・accepted が真、終了0だった。[パスの再現](path-reproduction.json)では `./` の別名とシンボリックリンクの両方で終了0となり、入力が報告で上書きされた。再現は本作業が作った入力だけで行った。

修正後は同じ性質を局所の検査で次のように確認した。

| 観点 | 確認した結果 |
|---|---|
| Unit だけの正常範囲 | matched は真、informativeCount は0、allTop で accepted は偽、終了1 |
| 全体操作上限0・1に古い正常値の期待を残す | 未着手本体の mismatches が notAnalyzed、matched と accepted は偽、終了1 |
| 未着手の期待を正しく明示 | 元定義と未発見の別本体の両方で停止理由が一致する。入力全体の状態・段停止・専用射影の件数も一致し、他の比較対象を持つコーパスは終了0 |
| 停止理由・after・phaseStops・counts の一箇所の誤り | 停止理由、最終操作数、段の分類・位置・順序・context、wholeBudgetSkipped の不一致で終了1 |
| 解析済み本体へ notAnalyzed を期待 | 元定義と別本体の両方で不一致、終了1 |
| 任意の入力全体の期待 | after・phaseStops・counts を一つずつ指定しても、それぞれ比較が成功する |
| 読者の厳密さ | notAnalyzed と通常欄の混在、深い未知欄、未知の停止理由・段、不正な番号・件数、件数の欠落を終了2で拒否する |
| INPUT と REPORT の同一 | 同じ文字列、`./`、`..`、シンボリックリンクを終了2で拒否し、入力内容を保持する |

最終の局所検査は **134回の実CLI起動、終了0**。五profileの主となる固定コーパスは引き続き解析174本体、閉じた評価器109本体を比較し、評価65本体を理由付きで除外した。[profile-manifest.json](profile-manifest.json)・[comparison-summary.json](comparison-summary.json)・[fuel-selection.json](fuel-selection.json)に件数を残す。domain の除外は整数の域内シフトの unknownFailure 46件と Byte 系の notClosedOrFuel 16件であり、対象構文の評価関係へ Byte の具体規則を追加していない。これらの件数は Lean と独立期待値の比較であり、Rust の解析・実 VM との比較件数は0である。

[全入力と報告のZIP](test-records.zip)と[各ファイルのSHA-256](test-records-index.json)に、初回の失敗を含む1,871ファイルを保存した。ZIPの全内容を元の内容・ハッシュと照合した後、本作業が作った展開済みの検査出力だけを片付けた。最終の生記録は ZIP 内の `tests-verified/` である。ビルド生成物は削除していない。

## 中心二命題・参照定義・主定理・公理

[点検器](audit.py)は B_WORK の git blob と作業ツリーを比較する。[検査前の詳細](audit-report-before.json)と[検査後の詳細](audit-report-after.json)を保存する。既存の formal・crates・fuzz・scripts・manifest 等の **4,492ファイル中、変更したのは交換のLean・読者例・Main・局所検査の4ファイルだけ**であり、残る4,488ファイルはバイト単位で一致する。既存Leanの名前付き定理3,434件について、言明の文字列だけでなく本文と参照定義のファイル全体を照合した。

| 言明・参照定義 | 差分とその意味の向き |
|---|---|
| NormalSoundness・WarningSoundness の本文・前提・結論 | Eval.lean 全体が一致。中心二命題の変更・弱化なし |
| EvalPartial・EvalBlock・EvalInput・Unmodeled・UnknownAt | 同上。未知を具体規則に置き換える変更なし |
| ConcreteValue・StandardRule・StandardBinding・EvalStandard・standardCallHead | 同上。具体値・評価規則・標準の認定・操作の扱いの変更なし |
| evalClosed と健全性定理 | EvalClosed.lean 全体が一致。unknown の選択と Byte の未対応を保つ |
| targetOperationAt・arithmeticOperationAt・WarningLocated | Sound.lean 全体が一致。演算の同定と公開の警告位置の集合の拡大・縮小なし |
| concreteRule・syntacticReachChildren・CallReach | SyntacticReach.lean・CallReach.lean 全体が一致。構文的な到達可能性や未認定callの除外を変更していない |
| AbstractSlot・AbstractEnv・SlotModels・LocalsModels・Models | Domain.lean・Environment.lean 全体が一致。Models の前提を強めていない |
| RangeState.Models と由来 | RangeState.lean 全体が一致。成功値・保存関係の変更なし |
| 解析・識別・予算・全体駆動と公開入口の主定理 | Analyze・BudgetAnalyze・BudgetSound・BudgetNormal・BudgetWhole・BudgetRange・BudgetDomainScan・BudgetSelect・Identity 等を含む、交換以外の既存Lean全体が一致。操作数・保持数・停止位置を変更していない |
| 旧主定理・Builtins.Assumptions・公理 | 交換・読者例・Main以外の既存Lean全体が一致。新しい公理・前提・結論の変更なし。変更した交換側にも theorem・axiom・sorry を追加していない |
| Rust・VM・予算の固定表・既存六入口・設定 | crates・fuzz・scripts・既存の設定全体が一致。interval-budget の固定表、lakefile.toml の `-M 12288` と既定ターゲット、既存六入口の登録も不変 |
| 01-12・07-04 | 交換の読者・比較と実行器の写しだけを更新。中心二命題・評価関係・解析規則・既存主定理の写しは変更していない |

[axioms.lean](axioms.lean)と[照会結果](axioms.log)で中心二命題と公開定理等の計16宣言を確認した。依存公理は既存の propext・Classical.choice・Quot.sound の範囲であり、fixed_at_disjoint_failed は propext・Quot.sound だけだった。sorry・新しい公理・解析器や評価器を kernel で計算する例を加えていない。

[work-inputs-sha256.json](work-inputs-sha256.json)には、変更したLean・Python・設計書の6ファイルを固定した。作業末検査後にこれらは変更していない。`git diff --check` も成功した。

## 検査と計測

実行場所は `<repo>`、Lean の入口は `<repo>/formal`。固定版 Lean 4.34.1・Rust 1.98.1を使った。作業末の Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。シェルでは rtk proxy を使い、[run.py](run.py)がコマンド・開始時刻・終了状態・外側時間をJSON、出力を同名のlogへ保存した。記録のパスは `<repo>`・`<home>`・`<tmp>` に伏せた。

| 検査 | 終了・外側時間 | 記録 |
|---|---|---|
| 読者の単体検査（`lake env lean -M 6144 Benitoite/Interval/Exchange.lean`） | 0・1.271秒 | reader-first.json・log |
| 読者例の単体検査（同じ -M、ExchangeExamples.lean） | 0・0.890秒 | examples-first.json・log |
| Mainの単体検査（同じ -M、IntervalDiff/Main.lean） | 0・0.618秒 | main-first.json・log |
| 依存順の逐次ビルド | 0・43.605秒、258モジュール | sequential-build.json、module-build.json・log |
| 最終の逐次更新 | 読者・例・Main・root・実行器が各0（3.471・0.998・0.690・0.686・0.594秒） | reader／examples／main／root／executable-final-build の各JSON・log |
| 更新済み確認（`lake --no-build build`） | 0・0.155秒 | ready.json・log |
| 局所検査の初回 | 1・3.467秒、報告先のエラーのパス表記で失敗 | tests-first.json・log、ZIP内の tests-first/ |
| 局所検査の最終実行 | **0・3.954秒、134起動の期待した結果を確認** | tests-verified.json・log、ZIP内の tests-verified/ |
| 公理の照会（`lake env lean -M 6144`） | 0・0.642秒 | axioms.json・log |
| 指定 work の dry-run | 0・0.009秒、基準と三単位を確認 | dry-run.json・log |
| 指定 work の検査本体 | **0・3.334秒、三単位すべて成功** | [work-check.json](work-check.json)・[出力](work.log) |
| 外側の `/usr/bin/time -l` | **1・3.359秒、検査後の資源統計取得を拒否された** | [work.json](work.json)・同上の出力 |

指定のコマンドは次のとおりである。先に同じ指定へ `--dry-run` を付けた。作業末の本体は[work-check.py](work-check.py)から一度だけ実行し、その外側を `/usr/bin/time -l` で包んだ。仕様集計の自己検査と集計、仕様例7件（失敗0・ignored 0、テスト本体2.92秒）、既定lake buildとsorry拒否を通過した。初回リリース版の完了条件の未記入はnoneだった。

```sh
scripts/check.sh --level work --base e44ab9c0588e1cdfc0ead2e7a3a82f30e522fa63 --only formal_build,spec_examples,spec_tally
python3 -B formal/tests/test_interval_exchange.py --output docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l29r/tests-verified
```

**最大常駐量（maximum resident set size）はサンドボックスの制約で取得できなかった。** 検査本体が終了0となった後、time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。real/user/sys は3.35/3.75/0.30秒である。検査の失敗やメモリ超過とは扱わず、未取得を0とも記録していない。統計の取得だけを目的とした再実行はしていない。

Leanは常に一プロセスずつ実行した。[build.py](build.py)は依存順に一モジュールずつ処理し、終了状態を確認してから次を起動する。既定ターゲットの更新済み確認を通した後、work から既定lake buildを実行した。単体検査のメモリは `-M 6144`、時間上限は300秒、例のビルドは25秒、Soundは175秒とし、上限の引き上げはしていない。lakefile.toml の `-M 12288` を保った。時間・メモリの上限、終了143による停止はなく、ビルドを背景に残したまま別の編集へ進んでいない。

## 途中の失敗とテストの作成時の関門

最初の手作りの再現入力では、Unit の Surface 表現と評価値の表現を object としていたため、それぞれ読者が拒否した。既存の交換の表現に従って文字列 `"unit"` へ直してから中1の誤受け入れを再現した。入力の拒否を中1の再現成功とは数えていない。

局所検査の初回は、存在しない REPORT の親を実パスへ解決する際のIOエラーが親名だけになり、既存の期待 `absent/report.json` を含まなくなって失敗した。Main のエラーに元の REPORT の指定を添え、既存の期待を保った。修正後の tests-second と、段停止の独立期待を増やした tests-final、最終ソースを再ビルドした tests-verified はすべて終了0だった。Leanの単体検査とビルドにコンパイル失敗はなかった。

作成時の関門で守る契約は、実CLIの比較・終了状態、全Topの受け入れ拒否、元定義と別本体の未着手の期待、入力全体の予算・段停止・件数、入力を上書きしないパスの判定である。未着手の期待や最終状態の読み捨て、他の型のBottomによる非Topの誤判定、停止段の順序・位置の取り違え、同じファイルへの別名による上書きという退行で失敗する。既存の検査は全体予算の入力に古い正常値の期待を残したまま成功を要求し、UnitのTopも検査していなかったため、その同じCLI境界の表を修正・拡張した。未知profileの例は読者の境界で拒否理由まで確認した。準備は既存の共通関数と表を使い、テスト専用の本番フラグ・注入口・公開範囲の拡大はない。低価値テストの削除、上限・ignore・期待の緩和はしていない。

基準との差分は本番の交換とMainが計107行追加・27行削除、Leanの読者例とPythonの検査が計124行追加・11行削除、設計書が計15行追加・7行削除である。

## 計画との差と申し送り

対象範囲の拡大、停止条件への該当、見込み上端の2倍による中断はない。言語規則・中心二命題・公開主定理・Models・公理を変えないと進めない点は見つからなかった。中3・軽2は取りまとめによる計画の対応済みの範囲であり、この枝では変更していない。別の関係状態の検査結果を引用して省いた検査はない。

| 残る手順 | 担当と受け渡す内容 | 見込み |
|---|---|---|
| L29Rの独立レビュー・受け入れ、コミット・取り込み | 取りまとめ。中1・中2・軽1・軽3、定義・言明・仮定の差分、同じパスへの書き込み拒否を確認する | 不明 |
| 実交換・Rust解析・全関係定義・実VMとの比較と検査 | X01〜X03。未着手の期待は notAnalyzed を明示し、入力全体の after・phaseStops・counts も照合する。域内unknownとByteの評価不能を比較済み件数へ加えない | 計画による。今回の実測からは不明 |
| 全比較への接続・K1・独立レビュー・受け入れ | X04〜X05／取りまとめ。既存六入口と新入口を同じ関係状態で閉じる | 計画による。今回の実測からは不明 |

Rust・VM・予算固定表・設定は変更していない。stage・change・release・short・check-formal.sh全体は、この枝の割り当てでは実施していない。コミット・取り込み・docs/todoの更新・保管・公開は取りまとめの担当である。

## 取りまとめのレビュー（2026-10-26）

受け入れる。RV-C5 の中1・中2・軽1・軽3 を閉じる。変更は交換の読者・比較・実行器・例・局所の検査・設計書の写しで、区間解析の定義・定理は変わらず、sorry・公理・`decide +kernel` の追加はない。修正前の誤った受け入れと入力の上書きを再現してから直している。中3・軽2 は計画の X03c の表で閉じたので、区切り C5 を閉じる。X01a へ進む。
