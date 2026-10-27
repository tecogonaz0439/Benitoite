# A07 の結果

再開後の A07 の実装と work の全選択単位の検査を完了した。独立レビュー・stage・short・受け入れは取りまとめへ渡す。

## 最初の起動の停止

2026-10-25。基準 B_WORK は `398eb1449a3d4e09bcfddac45de5727d5ed84fd3`。作業は未完了である。

### 停止の理由

依頼の補足にある「使う予定があり今は未使用のものが残るときは、許可を別の箇所へ書き足さず、止めて報告する」に該当した。A07 の実装前に、`src/typeck/interval/mod.rs` の一時的な `#![allow(dead_code)]` と説明のコメントだけを外して `cargo check -p benitoite --lib` を実行したところ、未使用の警告が20件出た。`build.warnings` が警告を拒否するため、終了101となった。

A07 が警告へ接続する候補の欄だけでなく、A08〜A12 の後続作業が使う予定の部品も未使用である。次の対応は、plan.md「受け渡す契約」と各作業の節、A02〜A06 の「計画からのずれと申し送り」「取りまとめのレビュー」に基づく。

| 未使用と報告された部品 | 使用予定と根拠 |
|---|---|
| `BodyReport.coverage`・`usage`・`numbered`・`order` 等 | A11 の消費・停止の受け入れ、A12 の報告の接続。A02 は内部状態と実消費を A12/X へ引き渡している |
| `EmbeddedBody.owner`・`ordinal`・`kind`・`body`、`definition`・`parent_key` | A10 の lambda/lazy/handler 節の別本体解析。契約表「束縛・境界」「識別」の元定義と別本体の番号対応に使う部品 |
| `Operation::JoinItem` | A08 の条件環境の合流と、A11 の Lean と同じ計上。現時点では未構築 |

このうち別本体の解析と非実行報告は A07 の範囲外であり、使用予定のある部品を消して完了にすることも、別の場所に許可を移すこともしていない。`Operation::JoinItem` の具体的な接続箇所など、後続作業の実装で確定する内容を、この点検で実装済みとは扱わない。

このほか `Candidate` の欄、`Analysis.candidates`、`OperationKey`、`IdentityMap.definition`・`key`、`Occurrences.get`、`Interval.contains`・`is_subset_of`、`Operation::Origin`、`Item::RangeOrigin`・`RecordField`、`NumberingBudget`・`NumberingResource`・`IdentityStop::Budget`、`BodySource.span`、`BodyInput.operand_types`・`operand_type`、`Handling`・`SurfaceForm.handling` も未使用と報告された。全20件の原文は [dead-code-check.log](dead-code-check.log) に保存した。全ての部品の削除可否を確定した記録ではない。後続作業が使う部品の存在を確認した時点で、依頼の停止条件を適用した。

### 実行した検査

| コマンドと対象状態 | 終了状態 | 外側の時間・最大常駐量 |
|---|---|---|
| `rtk cargo check -p benitoite --lib`。一時的な許可とコメントだけを外した状態 | Cargo 終了101。未使用警告20件 | 初回は `/usr/bin/time -l` で包んでいないため、時間と最大常駐量は未取得 |
| `/usr/bin/time -l cargo check -p benitoite --lib`。同じ状態で停止理由のログを保存 | Cargo は警告20件を拒否。外側のコマンドは終了1 | `0.09 real / 0.04 user / 0.04 sys`。`time: sysctl kern.clockrate: Operation not permitted` となり、最大常駐量は取得不能 |

二回目は保存用にキャッシュ済みの診断を再確認したものであり、作業全体の検査成功を示さない。生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に置き換えて保存した。

### 計画からのずれと申し送り

- 完了条件の一時的な許可の解除が、後続作業で使う未使用部品と両立しないことを事前点検で確認したため、A07 の実装を停止した。新しい W0401/W0402 の診断・重複排除・由来の補助位置、設計書と診断表の更新、Skill の再生成は未実施である。
- 点検のために外した属性とコメントは元の位置・内容へ戻した。AGENTS.md の一時的な許可の行も残した。ソース・設計書・テスト・生成物の変更はなく、今回追加したものは本記録と点検ログだけである。
- `scripts/check.sh --level work --base 398eb1449a3d4e09bcfddac45de5727d5ed84fd3` の dry-run と本実行は、実装を停止したため未実施である。全 lib・全統合・lint・fmt・生成物照合の成功を主張しない。
- `call_allocations` の指定二件も未実施である。候補・環境・診断の保持を変更しておらず、割り当て量を追加した結果はない。再開する A07 担当が実装途中に二件を確認し、作業末の work を担当する。上限・入力・期待値は変更していない。
- 再開には、取りまとめ・設計者が、一時的な許可の解除と後続作業向け部品の扱いについて方針を決める必要がある。A07 の範囲拡張や許可の継続を担当判断で実施していない。再開時期は未定である。
- A04・A05 のレビューが A11 へ回した計上の順序、A10 が担当する未対応の形の独立した子には変更を加えていない。言語の規則、Lean の定義・主定理・前提・結論・公理、実行時検査も変更していない。
- stage・short・独立レビュー・受け入れは取りまとめの担当であり、A07 再開・実装と work の完了後に行う。Lean のビルド・全比較、heap/stress、change/release は実行していない。git の変更操作は行っていない。


## 再開後の実装（2026-10-25）

基準 B_WORK・HEAD は `398eb1449a3d4e09bcfddac45de5727d5ed84fd3`、ブランチは `mod012/A07` である。上の停止記録は最初の起動時の状態であり、以下は設計者が接続後の未使用部品の削除を認めた後の作業である。git の変更操作と private/ の読み取りは行っていない。

W0401/W0402 の局所候補を既存診断へ接続した。元 NodeId・原因・一次位置の組で旧定数警告を優先し、新候補を本体順・先行順にまとめる。候補の元の記録順は変更しない。閉区間・型の値域・局所性の注記と最大8箇所の束縛・比較の補助位置を付けた。別名には束縛時点の由来を渡し、後の比較を遡って付けない。01-04・02-05・02-10 と診断表を更新し、gen_skill で生成参照を更新した。

接続後に mod.rs の一時的な許可とコメント、および AGENTS.md の許可表の一時的な行を削除した。許可属性は追加していない。型・エフェクトの規則、通常の受理、実行時検査、Lean の定義・定理・前提・結論・公理は変更していない。

## 再開後の検査

初回の work は終了1、外側339.261秒（time は339.25 real / 1207.21 user / 47.55 sys）だった。fmt・clippy・全 lib（1291成功/21 ignored）は成功し、全統合の test_command の2件で停止した。source_rules・skill_generated・spec_tally へは未到達である。最大常駐量は `time: sysctl kern.clockrate: Operation not permitted` により取得不能。[work.log](work.log) に初回の失敗を残す。修正後の検査は下へ追記する。

| 局所検査 | 結果 |
|---|---|
| `rtk cargo test -p benitoite --lib typeck::interval:: -- --nocapture` | 19件成功、1293件除外。テスト0.40秒 |
| `rtk cargo test -p benitoite --test declarations local_intervals_report_only_reached_arithmetic_failures -- --exact --nocapture` | 1件成功、25件除外。テスト0.94秒 |
| `rtk proxy cargo test -p benitoite --test call_allocations bounded -- --nocapture` | 2件成功。外側13.220秒。[allocations.log](allocations.log) |
| `cargo run -p benitoite --example gen_skill`（rtk経由） | 終了0。生成参照を更新 |

割り当て量は、20,000定数が454,943,955バイト（上限536,870,912）、5,000定数・1,000診断が267,178,210バイト（上限268,435,456）だった。上限・入力・期待値は変更していない。

途中の失敗: 最初の接続のコンパイルで Warnings と Provenance の公開範囲の不一致を修正した。未使用部品の削除後はテストの旧初期化欄も削除した。CLI の新テストは当初オプションをスクリプト名の後へ置いたため usageError となり、その修正途中ではスクリプト引数自体を落とした。テストの呼び出しを直し、処理系の受理規則や期待する診断を緩めていない。

## 未使用部品の整理とテストの監査

`BodyReport.coverage` と `usage` の観測欄だけを `cfg(test)` にした。前者は任意の小予算での停止分類と無効本体の除外、後者は途中停止を含む一時環境の返却・全体との消費の保存を確かめる。この情報は現在の公開診断に現れず、CLI からは未対応・停止・警告なしを区別できないため、独立した内部契約の観測として残す。新しいテスト専用の差し込み口は増やしていない。

番号付けだけの NumberingBudget/NumberingResource と専用の停止列挙子を削除し、番号付けテストを本番の Budget に変更した。保存上限だけでなく作業枠を含む保持上限を使い、停止時の取得済み接頭辞を引き続き確認する。別本体の未接続の一覧・命名・親番号対応を直接写す二つのテストは、その部品とともに削除した。元定義の出現・元位置・定数展開・合成節点・停止接頭辞のテストは残した。Report の order/numbered と、結果を別に二重保存する outputs のためだけの照合も削除した。

## 計画からのずれと申し送り

- 診断の根拠の保存と未使用許可の削除のため、interval の flow/environment/input/identity/budget/domain/mod と関連テスト、AGENTS.md も変更した。
- A04・A05 のレビューから A11 へ渡った計上順・括弧の枠数・番号付けと値の二走査の違いを直していない。A10 が担当する未対応の形の独立した子も実装していない。
- A10 は独立入力と別本体を追加するとき、親の候補に続く independentRev.reverse の入力順を診断の統合へ接続する。現在は存在する親候補を本体順・先行順に読む。
- 取りまとめが独立レビュー・stage S-A0・short 比較・受け入れを担当する。Lean ビルド・全比較、heap/stress、change/release は A07 の割り当て外である。

削除した部品の復元元はすべて基準 `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` である。後続は必要になった部品だけを履歴から戻し、その時点で使う経路へ接続する。

| ファイル（crates/benitoite/src/typeck/interval/ 以下） | 削除した部品 | 使用予定の作業 | 復元元 |
|---|---|---|---|
| budget.rs | Operation::JoinItem | A08/A11 | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| budget.rs | Item::RangeOrigin | A16〜A18/A11 | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| budget.rs | Item::RecordField | A19〜A20/A11 | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| domain.rs | Interval::contains / is_subset_of | X02/X03（必要な場合） | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| identity.rs | BoundaryKind、EmbeddedBody の全欄・definition・parent_key、IdentityMap.bodies、Walker の境界保存 | A10 | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| identity.rs | NumberingBudget、NumberingResource、IdentityStop::Budget、NumberingAccounting と局所予算の実装 | 復元不要。本番 Budget を使用 | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| input.rs | BodySource::span | A10/A12（必要な場合） | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| input.rs | BodyInput.operand_types / operand_type と収集 | A13〜A21/X01（必要な場合） | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| input.rs | Handling / SurfaceForm::handling | A10 | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |
| mod.rs | BodyReport.order / numbered、AnalysisState.outputs と二重保存 | A11/A12/X01/X02（必要な場合） | `398eb1449a3d4e09bcfddac45de5727d5ed84fd3` |

`Operation::Origin` は新しい由来の保存・取得で使用するため残した。02-05 の分類・別本体表・入力表の記述を、削除後の実装へそろえた。Lean の数学的な分類・manifest と定理は変更していない。


### 初回 work の新警告の確認と修正

新しい警告は、`tests/test_command.rs` の共有入力 MIXED の `crashes` 一箇所で、各検査・実行につき W0401 が1件である。28行目の `bind n <- 0` に続く29行目の `1 div n` の除数が `[0,0]` となる。`crashes` は実行時エラーを意図するテスト関数であり、枝や return に遮られた位置ではない。通常モードの検査は終了0、実行時は従来どおり R0101 を記録する。

| 失敗したテスト | 新警告の件数と意図 | 対応 |
|---|---|---|
| mixed_results_are_reported_in_the_text_form | sum.bnt の crashes に1件。成功2件・失敗5件の混在を報告する意図を保つ | stderr を警告1件の全文へ更新。stdout の実行時失敗の期待値と入力は維持 |
| check_does_not_run_user_code_or_write_result_lines | mixed.bnt を検査する text/JSON/単一報告と実行で各1件。検査で実行しないことを保つ | text は同じ全文、JSON は警告1件・W0401 を照合。出力とファイルの非変更、実行時の変更の確認を維持 |

ゴールデンと例の期待値は変更していない。この二件以外は、初回が実行した範囲に新警告による失敗はなかった。

自己点検で、A07 が新しく追加した由来の走査表・積み重ね・補助位置の一時保持と、候補に保存する補助位置の計上漏れを修正した。保存を拒否された場合は候補と補助位置の予約を返し、一時項目も全て返す。既存の任意予算停止の19件で再確認した（成功19件、テスト0.35秒）。A04/A05 から A11 へ回した差には触れていない。番号付けの保存5項の完了例は、新しい共通予算では作業枠も含めた保持10項で完了、9項で停止する境界へ置き換えた。緩い保持上限で完了だけを確かめる形にしていない。


### 削除したテストの根拠

| 名前・場所（interval/identity/tests.rs） | 検出していた差と使用経路 | 削除の理由・残る検査 |
|---|---|---|
| boundaries_keep_original_preorders_and_clause_order | 未接続の EmbeddedBody の境界番号・節順・範囲・命名と parent_key の表。Walker はこの表を保存するだけで、本番の読み手がいなかった | A01 が後続の別本体解析のために用意した部品を、取りまとめの指示で一緒に撤去する。A10 が使う段階で実装とテストを復元する。元定義の式の順序・元位置は残る source_order_negative_literals_and_return_keep_surface_keys / embedded_constants_use_original_types_and_multiple_occurrences が確認する |
| failure_clause_and_empty_lambda_keep_body_ranges | Fail の節と空ラムダの、同じ未使用の一覧・親範囲の表。型検査・値の走査には使われていなかった | 同じ部品の先取りのテストであり、現段階では公開の診断へ接続されていない。A10 の接続時に必要な契約を復元する。型検査の本体収集は accepted_polymorphic_failure_calls_are_collected、元の出現の接頭辞は numbering_stops_with_prefix_instead_of_renumbering を残す |

削除した一覧から後続の本体を解析しているように扱わないことが主な注意点である。復元表で A10 へ明示し、残る番号付け・任意予算の検査と全 lib・全統合で、現在の経路を確かめる。由来と診断の新しいテストは本物の型検査・CLI を使い、テストダブルや本番のテスト専用の引数は追加していない。

再検査中に diagnostics.rs・origins.rs の内部公開メソッドへ説明の文書コメントを追加した。実行するコード・入力・期待値の変更はない。


補足の申し送り: A13〜A15 が演算と幅を拡張するとき、diagnostics.rs の結果区間・型・型の全値域の表示も拡張する。現在の実装は A07 の範囲の Integer64 加算・整数除算・剰余に限る。32ビット環境での実行・クロスビルドは未実施であり、端点と中間値は i128、番号と予算は u64、由来の番号は上限内の u32 として点検した。


## 修正後の最終結果

作業末のコマンドは、初回と同じ基準・指定である。

```sh
/usr/bin/time -l scripts/check.sh --level work --base 398eb1449a3d4e09bcfddac45de5727d5ed84fd3
```

| 検査 | 終了状態・件数 | 外側の時間・最大常駐量 | 記録 |
|---|---|---|---|
| 修正後の同じ指定の dry-run | 終了0。fmt、examples を含む lint、全 lib、全統合、source_rules、skill_generated、spec_tally | 0.081秒 | [work-recheck-dry-run.log](work-recheck-dry-run.log) |
| 修正後の work | 全選択単位が成功。`selected checks passed` に到達し、check.sh の work 分岐は終了0。time の計測ラッパーは終了1 | 外側424.460秒。time は424.45 real / 1268.85 user / 47.85 sys。`sysctl kern.clockrate: Operation not permitted` のため最大常駐量は取得不能 | [work-recheck.log](work-recheck.log) |
| 全 lib（work 内） | 成功1291件、失敗0件、ignored 21件 | テスト70.69秒。上の外側の時間に含む | 同上 |
| 全40統合ターゲット（work 内） | 成功380件、失敗0件、ignored 10件。spec_examples・reference_examples・skill_examples・test_command も含む | 上の外側の時間に含む | 同上 |
| 修正後の局所 test_command 全件 | 成功52件、失敗0件 | テスト4.09秒、外側は未計測 | 直接 `rtk proxy cargo test -p benitoite --test test_command -- --nocapture` |
| 修正後の割り当て量二件 | 終了0、成功2件、1件除外。20,000定数454,943,955バイト、5,000定数・1,000診断267,178,210バイト | 外側13.534秒。テスト9.92秒 | [allocations-final.log](allocations-final.log)。`rtk proxy cargo test -p benitoite --test call_allocations bounded -- --nocapture` |
| CLI の新しい JSON/deny-warnings の局所検査 | 成功1件、32件除外。通常終了0、deny-warnings は終了2、一次・補助の元位置を照合 | テスト1.15秒、外側は未計測 | 直接 `rtk proxy cargo test -p benitoite --test cli_process local_interval_warnings_keep_json_locations_and_deny_exit -- --exact --nocapture` |
| 文書コメント追加後の fmt | 終了0 | 外側は未計測 | `rtk cargo fmt --all --check` |
| 差分の空白の検査 | 終了0 | 外側は未計測 | `rtk git diff --check` |

計測ラッパーの終了1は検査不合格として扱わない。全選択単位の成功表示と、check.sh の成功時の終了0への到達を確認した。最大常駐量を取得したとは記さない。保存した全ログで、手元の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せたことも確認した。

初回の検査後に由来の計上と関連テストを修正したため、古くなった fmt・lint・全 lib・全統合を再実行し、初回が到達しなかった source_rules・生成物照合・仕様集計も実行した。最後の追加変更は説明の文書コメント、02-05 の警告一覧での既存仕様の参照の明確化、本結果記録であり、文書コメント追加後の fmt も確認した。

### 行数と受け渡し

B_WORK との差分をファイル単位で数えると、本番側の Rust ファイルは追加384行・削除311行（差し引き73行）、テストの Rust ファイルは追加307行・削除103行（差し引き204行）である。未追跡の新しい diagnostics.rs・origins.rs も含めた。

A07 の未実施の検査はない。段の stage S-A0、B0 との short、独立レビューと受け入れは取りまとめが A07 の後に担当する。A10 の独立入力・別本体、A11 の Lean との全計上の一致、A12 の利用者向け非実行報告、X の全比較を先取りして完了にしていない。Lean・ヒープ・実行時検査の変更、依存更新、git の変更操作は行っていない。
