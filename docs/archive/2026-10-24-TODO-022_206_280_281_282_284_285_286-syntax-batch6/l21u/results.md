# L21U の結果

- 着手: 2026-10-26 06:01:07 JST（資料の点検後、実装着手時に記録）。
- 終了: 2026-10-26 06:17:52 JST。所要時間は16分45秒である。
- B_WORK・開始時と終了時の HEAD: `060eee90a4a43b2b88b780546ee96954291aeb56`。

**状態: L21U（Q-opaque-L2）の実装、写し、保存済み実交換との型・構成子・値の照合、指定 work は完了した。独立レビューと受け入れは取りまとめへ引き渡す。** 中心二命題の本文、公開入口の主定理の言明、既存公理を変えていない。停止条件に当たる変更や判断待ちはない。

## 基準と変更範囲

枝は `mod012/L21U`。開始時の作業ツリーに差分はなかった。plan.md「計画の変更（2026-10-26、A18a の停止を受けて）」の L21U の行、依頼の補足、a18a の調べの案 A に従った。private/ とそれを指すリンクは読まず、Git の変更操作・担当の委任・docs/todo の変更・コミット・取り込み・公開は行っていない。公開の rtk・japanese-tech-writing・test-audit を使用した。

| 変更ファイル | 内容 |
|---|---|
| [Eval.lean](../../../../formal/Benitoite/Interval/Eval.lean) | RangeNames に実交換から受け取る checkedConstructor を追加。所有元と構成子を RangeRecord にまとめ、rangeValue へ渡す。成功値を三欄の con に統一し、rangeStoredValue の some/none によって正確な射影と未知の正常値・失敗を分ける |
| [RangeState.lean](../../../../formal/Benitoite/Interval/RangeState.lean) | CheckedModels を、由来の二端点と具体値の三欄・有界な value・所属を対応させる関係へ変更。キーと束縛番号を実値に含めない |
| [Range.lean](../../../../formal/Benitoite/Interval/Range.lean) | 三欄保存・小モデルとの対応・全域性・正確な射影・Result と Ok の由来・同じ局所値への射影の依存証明を更新。内部の認定にも所有元と構成子の組を渡す |
| [EvalClosed.lean](../../../../formal/Benitoite/Interval/EvalClosed.lean) | 認定した三欄から保存された value を射影する。未知の表現から結果を選ぶことはせず none を返す |
| [RangeBorrowed.lean](../../../../formal/Benitoite/Interval/RangeBorrowed.lean)・[BudgetRange.lean](../../../../formal/Benitoite/Interval/BudgetRange.lean) | 射影の同定情報を所有元と構成子の組に変更。走査・tick・保持・停止の処理は保つ |
| [Examples.lean](../../../../formal/Benitoite/Interval/Examples.lean)・[SyntacticReachExamples.lean](../../../../formal/Benitoite/Interval/SyntacticReachExamples.lean) | 成功値の観察を三欄へ変更。未知の表現の導出と閉じた評価器の表を更新。既存の計上・停止・区間・警告の期待値は保つ |
| [01-12](../../../design/01-spec/01-12-core-calculus.md)・[07-04](../../../design/07-quality/07-04-formal-semantics.md) | 成功値・由来・認定・未知の導出の説明と定義の写しを更新。A1 の「三欄へ統一していない」という限界を削除し、実交換との照合範囲と未比較範囲を記す |
| 本ディレクトリ | 実交換の確認器、Lean の照合入力、公理依存・契約・固定表・計上の点検、検査記録 |

Examples と SyntacticReachExamples は合計 **50行追加・41行削除**。それ以外の Lean 六ファイルは **158行追加・195行削除**である（Range にある既存例の更新も含む）。Rust の本番・テスト、標準ソース、型とエフェクトの規則、Release・Surface、依存、固定表、ツールチェーン、lakefile.toml は変更していない。

## 実値・由来・射影の契約

成功値は次の形であり、専用の `checkedRange` は削除した。

```lean
.con record.owner [] record.constructor
  [.integer minimum, .integer maximum, .integer value]
```

三欄はすべて有界な Integer64Value である。rangeCheck は Checked.Range.make で逆転・所属を検査し、成功時には元の三入力を保存する。小モデルの Int を直接値の欄へ持ち込まないため、rangeValueUnrepresentable は不要になり削除した。検査キーは RangeOrigin.checkKey、成功値の束縛番号は RangeLocalFact.checked に保持する。ResultModels は、同じ標準規則と二端点に対する実際の検査結果との一致を定める。ResultModels・CheckedModels と具体値との関係は呼び出しキーによらず、キーは由来の認定と記録の側にある（L21V で記述を訂正）。

`rangeStoredValue` は所有元・構成子・型引数なし・三欄・各欄の Integer64 型を照合する。認定できれば保存された value を正確に返す。所属や検査由来を射影そのものの前提にはせず、`range_value_exact` が認定した値の全評価結果をこの正常整数に限定する。閉区間への所属は CheckedModels と実際の評価導出から別に証明する。

認定できない値には `rangeValueUnknown`・`rangeValueUnknownFailed` を置き、任意の正常 Integer64 と未知の失敗を許す。誤った所有元・構成子・型引数・欄数・欄の型の con、other、rangeError の導出を残す。some/none が排他的なので、未知の規則は正確な射影に重ならない。`range_value_total` は同じ data 型の全具体値への導出を構成する。Models・SlotModels を強めて値を除外していない。

閉じた評価器は既知の三欄だけを決定的に射影し、未知の表現には none を返す。Result の包装・型・腕選択の認定は同じ data 型を使う。Ok と Error の区別に必要な非等号は、L21T と同じく既存の Result 認定から渡す。

## 保存した実交換との照合

[確認器](check-surface-types.py)は L21T の確認器を本ディレクトリへ写し、所有元・構成子の同定を追加した。a18a/surface-export の JSON・ソース・元の確認器は変更していない。

所有元は、upperEndpoint の解決済み checkInteger の標準署名の戻り値から取得する。同じ型と value の引数、recheck の局所引数の型を照合する。その所有元をキーに builtins の dataDecls を引き、引数なしのレコード・唯一の構成子・三つの Integer64 の引数・欄順 minimum/maximum/value を確認する。構成子の name を直接取得し、typeName・constructorName などの表示名から同定番号を推測しない。Result の Ok/Error は組み込み Result 宣言の型引数の位置から取得する。

| 項目 | 保存した実交換から得た値・結果 |
|---|---|
| CheckedInteger の所有元 | `data:525` |
| レコード構成子 | `con:525:0` |
| 三欄 | minimum、maximum、value。三つとも Integer64 |
| checkInteger の戻り値 | `.data result [.data owner [], .data error []]` と一致 |
| checkInteger の三引数 | 三つとも Integer64 で一致 |
| value の引数・戻り値 | `.data owner []`・Integer64 で一致 |
| 成功値・Result の包装・射影 | 実交換の名前を使った Lean の入力で、三欄 `(0,10,5)`・Result.Ok の型と構成子・射影5が一致 |

[型と同定の結果](surface-types.json)に、元の宣言、全四箇所の型の比較、JSON・Lean 定義・生成した入力の SHA-256 を保存した。allEqual は true である。[生成した Lean の照合入力](surface-check.lean)も `-M 6144`・300秒上限で検査し、[終了0](surface-check.json)だった。型・構成子・値の生成と射影を実際の Lean 定義で確かめている。

これは保存済み range.bnt の交換との局所照合である。全 Range 入力・六入口の全比較・実 VM との意味の一致まで確認した結果にはしていない。Rust の変更は必要なかった。

## 中心二命題・参照定義・公理の差分

[契約の確認器](contract-check.py)・[確認結果](contract-check.json)・[内部言明の全差分](internal-statement-diff.json)を保存した。**既存の名前付き定理3,436件の言明がバイト単位で一致**し、実値の表現と構成子の同定を扱う内部補助言明14件を更新した。公開の解析入口の主定理の言明はすべて一致する。Interval の外の formal は全ファイルが基準と一致する。

| 参照される定義・言明 | 差分と向き | 保持した保証・制限 |
|---|---|---|
| NormalSoundness・WarningSoundness | 本文を含め不変 | 量化・前提・結論を保持 |
| EvalPartial・Unmodeled・UnknownAt・rangeCallBinding・NormalTyped | 本文は不変。参照する標準規則・具体値の表現を下記のとおり変更 | 対象構文の具体規則と未知の構文の境界、型内の任意値と失敗を許す方針を保持 |
| ConcreteValue・ConcreteValue.type | checkedRange を削除し、既存の con を使う。整数・other・rangeError・con の型の規則は不変 | 成功値を有界な三整数に統一。con の内部を型だけで認定したことにはしない |
| RangeNames・RangeRecord・StandardRule | 成功構成子を追加し、rangeValue に所有元と構成子を渡す | 表示名による推測をしない。標準表・出現の同定表を引く手順は保持 |
| rangeCheck・EvalStandard・rangeStoredValue | 検査成功を具体的な三欄へ写し、認定した三欄の旧未知規則を正確な射影に置換。それ以外には未知の正常値・失敗を残す | range_value_exact と range_value_total を保持。未知を全削除して健全性を空虚にする変更をしない |
| StandardRule.finish・resultType・IsOk・OkPayload・ResultView・rangeResultNames/Viewable | 本文は不変。argumentType だけは RangeRecord.owner を読む | Result の所有元・型引数・構成子・payload の型の照合と other の近似を保持 |
| RangeOrigin.CheckedModels | 有界な number と三欄の一致・所属へ変更。値に含めていたキーを由来に分離 | 型と端点が同じだけの任意値へ由来を付けない。由来の取得・保存・束縛番号の認定は従来どおり |
| AbstractSlot・SlotModels・Models・topSlot・ResultModels・RangeState.Models | 本文は不変 | Models・SlotModels に新しい条件を加えて未知の値を除外しない。補助関係の内部で三欄と由来を接続 |
| targetOperationAt・concreteRule・Reached・構文的な到達可能性・CallReach | 不変 | 警告の対象・到達・未認定 call の境界を保持 |
| rangeValueCall/Origin・borrowRangeValueCall・BudgetScan.rangeValueSource/rangeValue | 同定の一項を所有元から所有元と構成子の組へ変更。照合は同じ箇所で行う | 走査の順序・回数・保持項目数・停止位置を保持。異なる構成子の規則へ成功由来を誤用しない |
| Analyze・BudgetAnalyze・BudgetScan・BudgetRangeBorrow・BudgetDiscover・BudgetChildren・Budget・BudgetWhole・Sound などの本体 | 全文不変 | 解析の駆動・計上・独立入力・本体境界の規則を保持 |
| Builtins.Assumptions・旧主定理・既存公理 | 不変 | 新しい公理と証明の穴を加えない |

内部補助言明14件の変更は次のとおりである。新しい公開の前提は加えていない。

| 言明 | 変更 |
|---|---|
| range_success_fields・range_success_representable | 専用の checked の存在から、元の三入力を保存した con の一致と所属・有界性へ変更 |
| range_check_small_model | rawMake の成功値と標準規則の成功値を扱う。L21U の言明では raw と成功値の三欄の直接の対応が抜けたため、L21V で両者が元の三入力に等しいことを言明に戻した |
| range_value_exact | 小モデルの value の有界性から、三欄を認定した rangeStoredValue の結果へ内部条件を変更。任意の導出の結果が保存した value に限ることを証明 |
| range_success_projection・range_evaluated_projection | 同じ三欄の一致・実際の正常整数への射影導出・元の閉区間への所属を結論する形へ変更 |
| range_other_possible・range_other_at_possible・range_value_total | 所有元と構成子の組を受け取り、同じ data 型への未知の正常値と全域性を保持 |
| range_checked_models_mem | 三欄に保存した有界な number と、その所属を取り出す形へ変更 |
| range_value_origin_source・range_value_origin_mem・range_value_interval_mem・range_value_origin_total | 呼び出しの同定を owner 単体から owner と constructor の組に更新。同じ位置・記録・実際の評価との対応と全域性を保持 |

[公理依存の入力](axioms.lean)・[出力](axioms.log)は85宣言を確認し、依存は propext・Classical.choice・Quot.sound の範囲内だった。range_value_total・range_value_exact・range_result_ok_models・range_payload_stored・range_success_fields は propext だけである。sorry・admit・独自公理・native_decide は追加していない。

## 例の作成時の関門

守る契約は、実交換で同定した正しい三欄を正確に射影し、認定できない表現には任意の正常 Integer64 と未知の失敗の導出を残すこと、閉じた評価器が未知の結果を選ばないことである。誤った所有元・構成子・型引数・欄数・欄の型を認定する、未知の規則を削除する、保存した value 以外を射影する変更で失敗する。

既存の RangeSurface の表を更新して、上記の不正な表現と other・rangeError を一つのリストへまとめた。各行について任意の正常整数と失敗の導出を作り、閉じた評価器では none になることを確かめる。正しい三欄の5への射影も同じ境界で確かめた。L21T の「任意の con は未知」という旧例は、正しい三欄が具体規則になったため、新しい認定・未知の境界に合わせた。既存の端点・一点・二個体・保存・射影・後続算術の例は保持し、成功値の観察方法だけを三欄に変えた。最終点検では、未知規則をそのまま言い直す汎用の例を重複として削除し、具体的な表現の認定を確認する表を残した。

本番のために必要な rangePayload・rangeStoredValue を通し、テスト専用の入口・引数・フラグを加えていない。解析器・閉じた評価器の具体実行は #guard のままで、kernel の decide・rfl・simp で実行していない。実交換の照合は、合成した名前の例だけでは検出できない同定・三欄順の不一致を確認する別の境界である。テスト数を減らすための監査や、既存期待値の緩和は行っていない。

## 検査・途中の失敗・メモリ

実行場所は `<repo>`。Lean は固定版4.34.1。lakefile.toml の `-M 12288` を保った。[local-build.py](local-build.py)で import の依存順に一モジュールずつビルドし、Lean の検査を重ねず、各子の終了状態を確認した。既定ビルド前の `lake --no-build build` は351ターゲットが最新であることを確認した。単体の例と照会は `-M 6144`、Examples は25秒、ほかは300秒上限で実行した。ビルド中の Sound は175秒上限で32.703秒、Examples は25秒上限で5.132秒だった。時間上限・メモリ不足による停止はない。

| コマンド・検査 | 終了と結果 | 外側の時間・記録 |
|---|---|---|
| Eval の局所直列ビルド | 0、依存51モジュール | 19.942秒。[直列記録](sequential-build.jsonl)・[全試行のログ](sequential-build.log) |
| Range の修正後の局所直列ビルド | 0、依存55モジュール | 9.993秒 |
| BudgetWhole・EvalClosed と依存証明 | 0、依存86モジュール | 113.381秒 |
| `lake env lean -M 6144 Benitoite/Interval/Examples.lean` | 初回1、修正後0 | 初回5.019秒、修正後4.991秒。[初回](examples.log)・[修正後](examples-fixed.json) |
| 全259モジュールの直列ビルド | 0 | 56.354秒 |
| `lake --no-build build` | 0、351ターゲットが最新 | 0.153秒。[記録](default-up-to-date.json) |
| 同じ基準と指定の work の dry-run | 0、指定三単位だけを選択 | 0.010秒。[記録](dry-run.json)・[選択](dry-run.log) |
| 指定 work、一度、time で計測 | **検査本体0、三単位成功。計測器1** | **3.380秒**。[全出力](work.log)・[終了記録](work.json) |
| spec_examples（上の work に含む） | 7件成功、失敗0・ignored 0 | 2.90秒 |
| spec_tally（上の work に含む） | 自己検査・集計成功。完了条件の未記入 none | 未参照節の一覧は表示される |
| formal_build（上の work に含む） | 既定ビルド・sorry 拒否が成功 | キャッシュ済み。上の work に含む |
| 重複例の削除後の Examples の単体検査 | 0、同じ25秒上限・-M 6144 | 4.902秒。[記録](examples-final.json) |
| 同じ変更後の既定 import の直列再構築 | 0、依存249モジュール | 45.505秒。直列記録に追記 |
| formal_build だけの再検査 | **検査本体0、計測器1**。同じ基準・指定の dry-run 後に実行 | 0.169秒。[出力](formal-final.log)・[記録](formal-final.json) |
| 実交換から生成した surface-check.lean | 0 | 0.343秒。[記録](surface-check.json) |
| 公理依存の照会85件 | 0 | 0.310秒。[記録](axioms.json) |
| 契約・計上・固定表・記録の最終点検 | 0 | [点検器](final-review.py)・[結果](final-review.json) |

指定した作業末のコマンドは次のとおりである。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使用した。Rust を変更していないので、依頼どおり指定三単位を使い、Rust の全 lib・全統合を追加していない。

```sh
scripts/check.sh --level work --base 060eee90a4a43b2b88b780546ee96954291aeb56 --only formal_build,spec_examples,spec_tally --dry-run
/usr/bin/time -l /bin/zsh docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l21u/run-work.sh
```

run-work.sh は dry-run と同じ基準・指定の本検査を実行し、`L21U_CHECK_EXIT_STATUS=0` を保存する。**最大常駐量（maximum resident set size）は取得不能**だった。計測器が `sysctl kern.clockrate: Operation not permitted` で終了1になったためである。本体の終了0と混同していない。time の real/user/sys は3.37/3.70/0.27秒である。この計測は依存の直列再構築後の work に限り、途中の再コンパイルの最大量ではない。

作業末の三単位の後、重複した汎用例の削除で Examples だけを変えたため、単体検査・既定 import の直列再構築と、同じ B_WORK の `--only formal_build` の dry-run・本検査を追加した。仕様例・集計の入力は変わらず、この二単位は繰り返していない。再検査も time で包み、`L21U_FORMAL_EXIT_STATUS=0` を確認した。計測器は同じ sysctl の拒否で終了1となり、最大常駐量は取得不能だった。

途中の失敗は次のとおりである。実装と例は同じ契約・期待値で修正した。

- Range の最初のビルドが終了1となった。旧 CheckedModels の存在証明を分解するコードが二箇所残り、rangePayload を展開して型を読む簡約、閉じた整数の条件を decide する箇所、例へ渡す同定情報にも旧表現が残っていた。新しい number・三欄・所属を取り出す形にし、型の簡約と同定の引数を合わせた。修正後の Range と依存全体は終了0だった。全試行のログに初回を残す。
- Examples の最初の単体検査が終了1となった。RangeRecord.owner と RangeNames.owner の一致が、限定した simp only では簡約されなかった。RangeNames.record の展開を加え、同じ期待値のまま約5秒・終了0を確認した。

- 最後の点検器は、更新後の結果が自身の生成予定の final-review.json へリンクしていることを、ファイル生成前に拒否した。生成予定の自分自身の出力だけをリンク点検から除き、他のリンクは存在確認するよう修正した。Lean・検査本体の失敗ではない。修正後の点検は終了0である。

## 固定表・計上・計画との差・申し送り

**A11 の固定表・生成元・再生成器・README の7ファイルは B_WORK と全バイト一致する。再生成していない。** BudgetRange は戻す同定情報の型と同じ箇所の同一性の照合だけを変更した。所有元から所有元と構成子の組への置換後に、ファイル全体が基準と一致することを final-review.py で確認した。RangeBorrowed と純粋な認定も同じ置換だけで一致する。tick・走査順・保持項目数・停止位置の処理に変更はない。

既存の RangeSurface・RangeC3 の費用・保持・停止・区間・警告の期待値は変更せずにビルドが通った。保存済み固定表の元入力は標準表を空にして Range の認定を持たないため、本枝で新たに期待値が変わる形は見つかっていない。固定表の計算は繰り返していない。L20d が報告済みの旧固定表との差（本体47形・全体と集計各7形）は [既存の影響表](../l20d/reference-impact.md)を引き継ぎ、A18a の担当へ残す。本枝で追加の差を作ったことにはしない。

指定の範囲からの拡張はなく、checkedRange は不要になったため削除した。確認器と比較用 Lean 入力だけで実交換の同定を渡せたので、Rust の追加は不要だった。実装・設計書・固定表などの関係入力は、上の最後の再検査後に変更していない。

| 担当・時期 | 残る検査・レビュー・受け入れ | 見込み |
|---|---|---|
| 取りまとめ、A18a 再開前 | L21U の定義・言明・仮定の独立レビュー。内部14言明、未知の導出、実交換の構成子との一致、計上の不変を確認して受け入れる | 調べの目安45〜90分 |
| A18a、L21U の受け入れ後 | 新しい RangeRecord・RangeNames と三欄の値を使い、全 Range 入力・元 Surface と番号を接続。計画に従う固定表の追加・Rust の操作数・保持・停止・分類の照合、割り当て量・全統合を含む work、レビューと受け入れ | 計画では2〜4時間。構成子の接続の追加枠は調べで0.5〜1時間 |
| A18b・X02・X03b・取りまとめ、計画の区切り | 文書・生成物の全体整合、区間と費用、実 VM の三欄・成否・逆転優先・射影・到達の比較、六入口を含む全比較と受け入れ | 計画に従う。今回の関係状態では未実施のため不明 |

L21U 自身が受け持つ未実施・不合格の検査は残っていない。実 VM との比較・check-formal.sh 全体・stage・change・release・独立レビュー・受け入れは、計画の後続へ引き渡す。

## 取りまとめのレビュー（2026-10-26）

中心二命題の本文は基準と同じで、sorry・公理・`decide +kernel` の追加はない。formal に交換の番号（`data:525` など）を書き込んでおらず、構成子の同定は実交換から渡す。固定表と計上は不変、Rust の変更はない。L21U の起動の後に届いた RV-L21T の軽の所見のうち、軽2 の 07-04 の「同じ不透明型」と軽3 の `OpaqueName` はこの変更で消えた（軽3 のコメントは残っていた。RV-L21U の軽4。L21V で other の内部を読まないという説明に修正）。残る軽1（`range_bind_ok_models` を通る例）・軽2 の 01-12 の経緯の書き方・軽4（E0340 の言い換え）は、定義の独立レビュー（RV-L21U）の所見と合わせて直す。
