# 実装プラン

作業は直列に進める。どの作業も、メインの作業ディレクトリで作業ごとのブランチ（`mod/<作業>`）の上で Codex（GPT-6.1-Sol、high）が実装し、終えたらすぐ `san_benito` に取り込む。レビュー（Opus）は取り込んだコミットを `git show` で読み、直しは後のコミットで行う。作業ごとには関係するテスト・回収の強制の構成の関係するテスト・clippy・fmt だけを走らせ、`scripts/check.sh` と性能の短い測定は最後に一度だけ行う。設計書・言語リファレンス・CHANGELOG の未リリースの節・`gen_skill` の生成物は、各作業が同じ変更で直す。テストを加えるときは、スキル `test-audit` の作成時の関門を通し、退行のテストは直す前のコード（または一時的に壊したコード）で落ちることを確かめて報告に書く。

各作業の内容は `study.md` の部と節で示す（「173 部 1.4 節」は「TODO-173 の調査」の部の 1.4 節、「HTTP 部」は「TODO-208・TODO-215 の調査」の部）。部の中の推奨と `decisions.md` が違うときは、`decisions.md` を正とする。以下の `$GCS` は次の機能の指定を表す（`scripts/check.sh` の「gc-stress (mark-sweep)」と同じ構成）。zsh では語に分かれないので、機能の指定をそのまま書く。`cargo test` は `--` の前にフィルタを一つしか受け付けないので、二つ以上は `--` の後に書く。

```sh
GCS='--no-default-features --features gc-mark-sweep,heap-verify,gc-stress'
DEF='--no-default-features --features gc-mark-sweep'
```

どの作業の完了の条件にも、最後に次を含める（以下では省く）。

```sh
cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep
cargo fmt --all --check
```

V1（確保と印付け）と V4（構造の `=`）は VM の速さに響きうるので、取り込んだ直後にオーケストレータが fib・loop の短い測定（`tools/bench/gate.py`、取り出した前の版と交互）を行う。

## 作業 V1: ヒープの内部（TODO-173、Q3・R6・R8）

`src/runtime/heap/` だけを変える。

0. 手順 0（変える前に行う）: 揺らぐ 3 件を既定の機能で走らせ、結果を報告に書く（173 部 8.1 節の W2 の手順 0）。`cargo test -p benitoite --lib $DEF -- vm::tests::dead_large_list vm::tests::tail_window vm::tests::suspended_callers`。
1. 確保の通し番号の `ObjId`（Q3）: 確保ごとにヒープの中で一意な 64 ビットの番号を振り、`object_id`・`object_ids` はその番号を返す。置き場所は、heap-verify のない構成では頭の空きを使い、32 バイトの表明が通るかを確かめる。heap-verify の構成で頭を大きくする必要があれば、その構成の表明だけを改める。どちらの構成でも本番（heap-verify なし）の対象ごとの記憶を増やさないことを目標とし、増やす必要があれば作業を止めて報告する。`ObjId` の `///` の「番地から作る」を改める。`HeapCore::same_object` は番地の比較に改める。番地であることを表明する内部のテスト（173 部 1.2 節の (E)）を、「異なる対象は異なる ID」「解放した番地に作った対象は別の ID」を確かめる形に改める。
2. 回収ごとの番号の印（R6）: 173 部 2.3 節の案 (a)。番号は回収の状態（`mode::State` など）に `u64` で置き、`stats.collections` は使わない。掃き出しで印を消す書き込みが要らなくなるなら除く。内部の層の `//!` の不変条件の一覧（M1 など）と `// SAFETY:` の引用を合わせる。印付けの途中で panic する Host（Trace の実装）を使い、次の回収が到達できる子を解放しないことを確かめるテストを加える（直す前のコードで落ちることを確かめる）。
3. `Decimal` の表明: 173 部 5.1 節の `const` の表明。
4. rustdoc: 173 部 3.2 節の文案を、`runtime/heap/mod.rs` の `//!`、`Heap::collect`、`NoGcCtx::load`（と `take`）の `///` に書く。シグネチャは変えない。
5. 設計書: 02-09「メモリの管理」に、根の列挙の漏れを heap-verify の構成では世代の照合で見つけ、既定の構成では見つけないことと、対象の識別（`ObjId`）が確保の通し番号であることを、それぞれ一文で足す。印の表し方は書かない（R8）。

完了の条件:

```sh
cargo test -p benitoite --lib runtime::heap
cargo test -p benitoite --lib $DEF runtime::heap
cargo test -p benitoite --lib $GCS runtime::heap
cargo test -p benitoite --lib -- vm::tests runtime::map
```

`scripts/check-heap.sh` は最後の検査で走らせる（オーケストレータが行う）。

## 作業 V2: VM の回収のテスト（TODO-173）

173 部 1.2 節の (A) と (C)、8.1 節の W2。V1 の通し番号を前提とする。

1. (A) の 3 件（`dead_large_list_is_reclaimed_after_its_last_use`、`tail_window_old_objects_are_cleared_at_collection`、`suspended_callers_release_old_arguments_and_results_before_collection`）を見直す。テストが `list::tail` で自分で作る捨てる対象を集めないよう、元のリストの対象だけを集める形にするか、集め方の意図をコメントに書く。名前・変数名・コメントを今の永続ベクタの表現に合わせる。
2. (C) を「明示の `heap.collect` の直後、確保を挟まずに `object_ids()` に含まれる」確かめに改める（`heap_constants_keep_identity_when_only_the_cache_roots_them` と、`vm/dispatch/numeric.rs`・`collections.rs`・`traits/tests.rs` の定数のテスト）。
3. 定数表を引く 5 か所を `vm/dispatch/test_support.rs` の補助の関数にまとめる（`constants.last()` の 4 か所もまとめるかは作業の判断）。

完了の条件:

```sh
cargo test -p benitoite --lib vm::
cargo test -p benitoite --lib $DEF vm::
cargo test -p benitoite --lib $GCS -- vm::tests vm::dispatch::numeric vm::dispatch::collections vm::dispatch::traits
```

## 作業 V3: 検査の道具と文書（TODO-173、Q4・R7・R9）

1. `scripts/check.sh`:
   - `rust` を選んだときに、既定の機能の Clippy（`cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep`）を走らせる。
   - 既定の機能のライブラリのテスト（`cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep`）を新しい検査の名前（例: `default_lib`）として加え、`--only` で名指ししたとき、`--full` のとき、`runtime::heap` を変えたとき（`check-heap.sh` を選ぶのと同じ条件）にだけ走らせる。
   - `allow(unsafe_code)` の場所の検査（173 部 5.2 節の `check_unsafe_allows`）を、`rust` を選んだときに走らせる。
   - `--dry-run` の表示と、選ぶ理由の文言を合わせる。
2. 07-03「実装の規約と静的な検査」と「ヒープとランタイムの確かめ方（初回リリース版）」: 検査の表に三つの検査を加え、「デバッグのビルドでのヒープの検証器」を heap-verify の構成と書き直す（173 部 7 節）。既定の機能のライブラリのテストを一度走らせて時間を測り、07-03 に書く。
3. AGENTS.md: `#[allow]` の表の「`src/runtime/heap/` の内部の層のファイル」を、検査の一覧と同じ書き方（`src/runtime/heap/core.rs` と `src/runtime/heap/core/`）に改める。ディレクトリ構成の表の `scripts/` の行に、既定の機能のライブラリのテストを走らせる条件を一文で足す。

docs/todo の TODO-161 への書き足し（R7）はオーケストレータが行う。

完了の条件:

```sh
scripts/check.sh --dry-run --base <V3 の前のコミット>
scripts/check.sh --only default_lib
bash -n scripts/check.sh
```

## 作業 V4: 構造の `=` と鍵の比較の共有（TODO-220、R1〜R3・R5）

220 部 4.1・4.2・5 節。

1. `runtime/equal.rs` の `values_equal` に、一定の歩数を超えてから、子を持つ対象の組 `(object_id(a), object_id(b))` を覚える仕組みを入れる。49 行のコメントを、同じ対象でも 1 回目は成分を調べる理由（NaN）と、2 回目から省く理由に書き直す。覚える集合は上限を設けない（R2）。確保の大きさの規約（02-09「一つの操作で作る値の大きさの上限」）に当たるかを確かめ、当たるなら確保の失敗を処理系の資源の不足として扱う形にする。
2. 同じ仕組みを `runtime/map/keys.rs` の `compare` に入れる（R3）。
3. テスト: 220 部 4.2 節の表のテスト（64 段の共有した木、葉だけ違う、NaN、`0.0` と `-0.0`、リストとマップの値、鍵の比較）。直す前のコードで `timeout` で止まることを確かめる。ゴールデンテストは置かない（R5）。
4. 設計書: 02-08「組み込みの関数の呼び出し」に 220 部 5 節の決定と理由を書く。

完了の条件:

```sh
cargo test -p benitoite --lib -- runtime::equal runtime::map runtime::assert builtins::funcs::list
cargo test -p benitoite --lib $GCS -- runtime::equal runtime::map
cargo test -p benitoite --test golden
```

## 作業 V5: 要求の対象の文法（TODO-208、Q1・R10・R11）

HTTP 部 2 節と 4 節の W1。`RequestReader::advance` で、対象の形と文字を確かめる補助の関数を `origin_target` の前に呼ぶ。Q1 の範囲（形: `*` は `OPTIONS` だけ、authority 形は `CONNECT` だけで port を確かめる（空・数字以外・65535 超は 400、0 は受け付ける）、`/` で始まらない起点形と `http`・`https` 以外の scheme の絶対形は 400。文字: `"`・`<`・`>` と 0x80 以上は 400）。単体テストの表を 2.5 節のとおり直し、新しく 400 にする場合と、受け付けたままにする文字（`[`・`]`・`\`・`^`・`` ` ``・`{`・`|`・`}`）の行を足す。03-09「サーバの接続と要求の読み方」、リファレンス、CHANGELOG（Incompatible changes）を直す。`Network.Http` の標準ライブラリのソースの文書のコメントを変えたら `gen_skill` で作り直す。

完了の条件:

```sh
cargo test -p benitoite --lib runtime::io::http
cargo test -p benitoite --test l30_http_server --test l31_http_serve_and_helpers
cargo test -p benitoite --test golden
cargo test -p benitoite --test reference_examples --test skill_docs
```

## 作業 V6: 拒否した接続の段階的な閉じ方（TODO-215、Q2・R12・R13）

HTTP 部 3 節と 4 節の W2。`Connection` に閉じる途中の段を足し、`advance` に `now` を渡し、`arm` の向きと `Armed::deadline` を直す（L1、上限 1 MiB・2 秒）。3.7 節のテストを、まず今の実装に対して macOS で走らせて結果を報告に書き（落ちるか、落ちないか）、そのうえで加える。期限と量の上限は、本物の時間を待たずに `now` を進める単体テストで確かめる。l30 の `request` の RST を許す分岐は残す（R13）。03-09・02-09 の 219 行の付近（`Http.Listener` の解放のときの閉じる途中の接続）、CHANGELOG（Fixed）を直す。

完了の条件:

```sh
cargo test -p benitoite --lib runtime::io::http
cargo test -p benitoite --lib $GCS runtime::io::http
cargo test -p benitoite --test l30_http_server --test l31_http_serve_and_helpers
cargo test -p benitoite --test golden
for i in $(seq 1 20); do cargo test -q -p benitoite --test l30_http_server <新しいテストの名前> || break; done
```

## 最後に行うこと（オーケストレータ）

1. レビューの指摘を領域ごとの作業（Z1〜）でまとめて直す。
2. 性能の関門の短い測定（`measurements.md`）。
3. `scripts/check.sh --base 3f9d721d`。V3 で `scripts/check.sh` を変えるので、どの種類にも当たらないファイルとして止まる見込みである。止まったら、設計者に `--full`・`--only`・`--none` のどれにするかを尋ねる。`runtime::heap` を変えるので `check-heap.sh` も走る。
4. docs/todo: TODO-173・208・215・220 を閉じ、TODO-161 に既定の構成の Miri を書き足し（R7）、R4 の新しい項目を加える。
5. 改造のディレクトリを `docs/archive/` へ移す。
