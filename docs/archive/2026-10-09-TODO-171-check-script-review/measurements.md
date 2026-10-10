# 検査の時間の測定

2026-10-09 に、開発機（macOS arm64、CPU 10 個）で、`b356074` の時点のソースを測った。ビルドの結果はあらかじめ揃っていた（ビルドの段の時間は、変更がない場合の確かめだけの時間である）。測定のスクリプトと生の記録はリポジトリの外に置いた。

## `scripts/check.sh` の段ごとの時間

`check.sh` と同じコマンドを、同じ順に段ごとに走らせた。

| 段 | コマンドの要点 | 時間（秒） |
|---|---|---|
| 書式 | `cargo fmt --all --check` | 0 |
| lint | `cargo clippy --workspace --all-targets`（機能 `gc-mark-sweep,heap-verify,alloc-stats`） | 5 |
| テスト | `cargo test --workspace`（機能 `gc-mark-sweep,heap-verify`）。ビルドの確かめ 15 秒を含まない | 791 |
| 回収の強制 | `cargo test --workspace --lib --tests`（機能に `gc-stress` を加える）。ビルドの確かめ 15 秒を含まない | 837 |
| 仮置きの許可の残り | `grep` | 0 |
| 仕様の網羅の道具 | `spec_coverage.py --self-test` | 0 |
| ライセンス | `cargo deny check licenses` | 0 |
| 計 | | 約 1,660（約 28 分） |

時間のほとんどは、テストと回収の強制の 2 回の全体実行である。

## テストの段の内訳

`cargo test` は、テストのバイナリを一つずつ順に走らせる。バイナリの中のテストは並べて走らせる（既定でスレッドは CPU の数）。したがって段の時間は、バイナリごとの時間の和であり、各バイナリの時間は、その中で最も長いテストで決まる。

| バイナリ | テスト | 回収の強制 | 中のテスト |
|---|---|---|---|
| 単体テスト（lib） | 459 秒 | 476 秒 | 806 件。最も長い 1 件が 407〜421 秒 |
| `tests/golden.rs` | 152 秒 | 190 秒 | 1 件（`golden_suite`）。506 のスクリプトを順に実行する |
| `tests/vm_handlers.rs` | 42 秒 | 41 秒 | 1 件 |
| `tests/vm_reference_cells.rs` | 41 秒 | 41 秒 | 1 件 |
| `tests/verify.rs` | 25 秒 | 25 秒 | |
| `tests/random_programs.rs` | 23 秒 | 16 秒 | |
| ほかの 26 のバイナリ | 各 7 秒以下、計 30 秒ほど | 同程度 | |

## 単体テストの長いもの

nightly の Rust の `--report-time` で、テストごとの時間を測った（機能は `check.sh` と同じ。nightly の非推奨の警告を許すために `CARGO_BUILD_WARNINGS=warn` を与えた）。806 件の時間の和は、テストで 1,304 秒、回収の強制で 1,699 秒である。

| テスト | テスト（秒） | 回収の強制（秒） |
|---|---|---|
| `vm::dispatch::handlers::tests::million_completed_handlers_use_constant_space_but_pending_resumes_grow` | 407 | 421 |
| `vm::tests::deep_returns_collect_requested_allocations_without_rust_recursion` | 6 未満 | 236 |
| `runtime::map::tests::million_element_trees_support_updates_and_union_shares_the_large_input` | 114 | 120 |
| `vm::dispatch::tasks::tests::a_million_inherited_tail_resumes_fit_a_small_stack` | 14 | 107 |
| `runtime::list::tests::repeated_cuts_of_joined_lists_preserve_sequences` | 99 | 105 |
| `runtime::list::tests::million_appends_gets_and_repeated_splits_do_not_recurse` | 97 | 102 |
| `runtime::list::tests::hundred_thousand_short_concatenations_match_vec` | 83 | 84 |
| `vm::dispatch::handlers::tests::dropping_one_hundred_thousand_continuations_does_not_accumulate_stack` | 55 | 58 |
| `cli::tests::codegen_limit_is_a_run_error_but_check_succeeds` | 50 | 48 |
| `vm::dispatch::traits::tests::tail_methods_repeat_a_million_times_and_resize_windows` | 9 | 47 |
| `runtime::heap::core::mode::tests::million_linked_and_nested_fields_use_bounded_rust_stack` | 42 | 39 |
| `runtime::heap::ctx::r04_tests::r04_million_linked_and_nested_objects_free_without_recursion` | 39 | 37 |

10 秒を超える単体テストは約 20 件で、どれも百万規模の構造や深い再帰で、処理系が Rust の再帰を使わないこと・空間が一定であることを確かめるテストである（AGENTS.md「再帰の深さ」の「処理系のテストは、深い入れ子と長いリストの場合を含める」）。

## 仕様の網羅の道具の本番の集計

`python3 tools/spec-coverage/spec_coverage.py` は 0.1 秒で終わり、終了状態 1 になる（`secf1-*.bnt` の印の誤り。README の「範囲」の 5）。

## 改造の後の時間（2026-10-10）

同じ開発機で、改造の後のソースを測った。

| 検査 | 時間（秒） | 改造の前 |
|---|---|---|
| テスト（長いテストを除く。処理系を変えたときの選んだ検査） | 259 | 791 |
| 回収の強制（長いテストを除く。同上） | 268 | 837 |
| 全体の検査（`scripts/check.sh --full`。長いテストを含む） | 1,342（約 22 分） | 約 1,660（長いテストは含んでいた） |
| `scripts/check-heap.sh`（Miri。ヒープを変えたときの選んだ検査） | 288 | 測っていない |

長いテストを除くと、単体テストのバイナリは 40 秒、ゴールデンテストは並べて 32 秒（回収の強制で 51 秒）になった。残りの大きなものは、テスト関数が 1 本だけの `tests/vm_handlers.rs`（41 秒）と `tests/vm_reference_cells.rs`（41 秒）、`tests/verify.rs`（25 秒）である。

全体の検査の初めの試みでは、`list_hof_long` を参照インタプリタとの差分比較にも含めたため、ゴールデンテストが 1 時間 49 分を超えても終わらず、止めた（[decisions.md](decisions.md) の「5.」）。
