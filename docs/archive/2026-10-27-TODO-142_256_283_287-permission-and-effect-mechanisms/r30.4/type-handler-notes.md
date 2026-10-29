# Http.sendIn の型とハンドラの実ソース

## 対象と作成時の関門

開始版は B_WORK `98b420af9bf9e6de4eea81bab140efb835529bd9` である。入力は `crates/benitoite/tests/scoped_calls/http_io.rs` に置き、通常の `pipeline::check_text`、脱糖、コア IR の再検査を使う。内部の `PendingIo` の状態へ直接値を差し込まず、宣言表をテスト用の署名へ差し替えない。

公開の `test-audit` の作成時の四つの問いに対し、次のように判断した。

| 問い | 判断 |
|---|---|
| 守る振る舞い | sendIn の対象入力と潜在効果の同じ列、関数値の期待入力型、完全性の新操作への追随、節引数の所属と不変添字、節自身の外部効果 |
| 捕まえる退行 | 前置きの Top 分類へ落ちる、入力と効果の列がずれる、期待型を使わない、古い send だけで Connect を消す、節の型から局所の所属を作る、節の別対象 IO を消す |
| 既存では不足する理由 | R20 の検査は仮の署名、File の検査は path の本番署名であり、Http の登録・endpoint の二欄と二つの Connect 操作を通さない |
| 本番の差し込み口 | 不要。公開の解析入口とその型・診断を使う。似た入力は五つの表形式のテストにまとめる |

## 入力型・潜在効果・PendingIo

`http_single_target_signature_follows_input_and_expected_function_input` は、本番の `Benitoite.Network.Http.sendIn` を解決した束縛について、`Single { kind: Endpoint, position: 0 }`、一つの範囲変数、引数と `Http.Connect` の同じ `rvar 0` を独立期待値と照合する。普通のソースの各出現の列、関数型の第1引数、潜在効果の三者も照合する。

| 実ソースの経路 | 確認した範囲と診断 |
|---|---|
| `RequestIn["api.example", 443]` を直接渡す | 入力・潜在効果・出現の列が全て同じ endpoint |
| その入力型を期待して `Http.sendIn` の関数値を返す | 同じ endpoint |
| 期待入力型のない未使用の関数値を `bind` する | Top |
| `ClientRequest` を直接渡す | E0401 |

`http_io_constraints_choose_check_index_and_top_cannot_be_narrowed_afterward` は、check の成功型への明示の注釈、既知の直接条件だけの場合、裸の `RequestIn` を受ける通常関数を経由する場合を比較した。前二者は `api.example:443`、最後は Top になった。Top に確定した成功値を狭く widen する追加の形は E0519 `notCovered` で拒否された。

本番の `typeck/scoped_calls.rs::scope_shape` は、対象位置の入力を一時の型変数へ置き換えて `PendingIo` に保持する。制約を解く部分は成功型の具体化を終えてから対象の解を読み、同じ一要素の列で署名と潜在効果を具体化する。期待型が最後までなければ Top とする。この実装の読解と上の実ソースを対応させ、四経路の仮の署名の検査だけで接続済みとしない。

## 節の引数の射影・拡大

`http_handler_clause_projection_and_widen_require_local_facts_for_non_top` は、全ての射影・拡大を `bind` の右辺に直接置く。節の S は保護本体の効果から選び、外側の宣言を選択の根拠にしない。

| 節の引数と S | bind の右辺の呼び出し | 確認した結果 |
|---|---|---|
| `RequestIn["api.example", 443]`、同じ狭い S | `Http.requestInValue(request: captured)` | E0519 `unknownSource` |
| 同上 | `Http.widenRequestIn`、戻り注釈 `["**.example", 400..500]` | E0519 `unknownSource` |
| 裸の RequestIn、S=Top | `Http.requestInValue(request: captured)` | 受理 |
| 同上 | `Http.widenRequestIn`、戻り注釈 Top | 受理 |
| 同上 | `Http.widenRequestIn`、戻り注釈 `["**.example", 400..500]` | E0519 `unknownSource` |

狭い節引数には局所の検査の事実がないので、bind に移しても射影・拡大を受理しない。同じ狭い型を受ける関数へ直接転送する形と、広い不変添字の入力へ転送する形も比較した。前者は受理、後者は E0401 で拒否された。これは File の結果と同じ制限であり、README の設計者の決定を保つ。

## 完全性と節自身の効果

`http_handlers_require_both_operations_and_keep_captured_input_invariant` は、旧 `Http.send` だけの節で保護本体の send を処理する形でも `Http.Connect` が残ることを確かめた。上限に Connect を書けば受理し、上限を省けば E0501 で拒否された。sendIn の節も加えた完全なハンドラでは、上限なしを受理した。

`http_complete_handler_leaves_its_own_other_endpoint_io_outside` は、保護本体を `api.example:443` とし、完全な二節のうち sendIn の節自身が `logs.example:8443` へ送る形である。外側の上限を logs のみとすれば受理し、api のみとすれば E0519 `notCovered` で拒否された。節の呼び出しも保護本体の対象へ置き換えない。

Lean は読取りだけで照合した。`Release/TargetTable.lean::sendIn` は一つの endpoint、対象位置0、`requestIn 0` と同じ効果の添字を持つ。`Surface/ClauseIxRule.lean::clauseIxIn` は範囲変数を持つ組み込みの操作であれば `clauseRangeIn atoms e l` を使い、保護本体の効果 e から節の添字を選ぶ。今回この定義・規則・証明を変えていない。widen の列 `[R,S]` と `Covers { outer: 1, inner: 0 }` も変えていない。

## 局所検査

| 検査 | コマンド | 結果・外側の時間・補助 RSS |
|---|---|---|
| 本番の型・節 | `cargo test -p benitoite --test scoped_calls http_io:: -- --nocapture` | 5成功・失敗0・無視0・フィルタ除外29、終了0、11.485394875秒、2,289,795,072 bytes（2,183.71875 MiB）。[ログ](scoped-http-initial.log)・[計時](scoped-http-initial.json) |
| Skill 手書きの例、初回 | `cargo test -p benitoite --test skill_examples code_examples_in_hand_written_documents_behave_as_written -- --exact --nocapture` | 終了101、6.387438166秒、676,986,880 bytes（645.625 MiB）。[ログ](skill-handwritten-initial.log)・[計時](skill-handwritten-initial.json) |
| 同じ例、修正後 | 同上 | Rust の1件成功・失敗0・無視0・フィルタ除外3、文書の63例成功、終了0、8.693358秒、1,465,368,576 bytes（1,397.484375 MiB）。[ログ](skill-handwritten-fixed.log)・[計時](skill-handwritten-fixed.json) |

`run-record.py` は対象を `/usr/bin/time -p` で包み、子の終了を直接保存する。RSS は macOS の `getrusage(RUSAGE_CHILDREN)` による子孫の最大値の補助値であり、合計ではない。Skill の初回の失敗は、新しい check-only の例が `main` を持たず E0414 になったためである。空の Unit の main を加えた後、同じ例の入口を再実行して通った。型とハンドラの5件は初回成功だった。

Skill の生成参照の照合は生成前に重ねて実行せず、gen_skill の後の W-R が受け持つ。作業末の W-R の記録は results.md を正とする。テストの削除と、本番のテスト専用の入口の追加はない。

## 参照実行器の HTTP 実通信の制限

実通信担当が通常の差分比較の入口から sendIn を実行すると、参照側は `HTTP runtime unavailable` で停止した。次の本番の契約を照合した結果、テストの adapter へランタイムを足すだけでは HTTP 実通信を参照実行器へ接続できないと判断した。旧 send も同じ制限を持つ。

| ソース | 確認した契約 |
|---|---|
| `src/builtins/iface.rs::IoServices::runtime_view` | VM の `IoView` は Some、参照インタプリタとテスト用の実装は既定の None。利用する組み込みの関数は None のとき `Stop::Internal` を返す |
| `src/builtins/funcs/http_client.rs::start_send` | 旧 send と sendIn は共通して、通信前のネットワークの失敗の表を `runtime_view` から読む。この口がなければ `HTTP runtime unavailable` で停止する |
| `src/refinterp/convert.rs::BuiltinBridge::call_decl_scoped` | 呼び出し元の IO を常に `resources::Io` で包んでから、組み込みの本体へ渡す。外側の `ReferenceIo` に口を加えるだけでは内側へ渡らない |
| `src/refinterp/resources.rs::Io` | 独自のリソースの表を持ち、`runtime_view` を base へ転送しない。`reference_and_fixed_services_do_not_expose_vm_runtime_views` が、参照側と固定 IO が VM 専用の口を公開しない契約を検査する |
| `tests/golden/differential.rs::ReferenceIo` | 固定入力と出力の捕捉を持つ通常の差分比較用の実装であり、VM の IoRuntime を持たない |

この枝では、参照側の VM 専用の口を公開したり、口がないことを「失敗の表が空」と読み替えたりしない。HTTP の実通信を参照実行器へ広げる変更は行わず、実通信は VM の Direct と Request で確認する。参照側の停止を比較成功や実通信の確認済みとして数えない。要求の純粋な保持・射影・拡大と節の型の検査、実通信の確認範囲も区別する。実通信の最初の失敗と最終の対象・結果は results.md と実通信担当の記録を正とする。
