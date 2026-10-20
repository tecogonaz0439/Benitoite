# T4 本体ごとの使用位置・捕捉と生存の解析

基準B_WORKは `0ea85437385b46a44abf241ddcdae8015db14639`（開始時の `git merge-base HEAD san_benito`）である。開始時の作業差分はない。コミットとdocs/todoの変更は行わない。

## 実装と判断

BodyAnalysisで下位IRの範囲・通常値の使用位置と束縛位置・本体ごとの初出順の捕捉を一度作り、補助原型と共有した。後続の読み出しは範囲の借用で和を表す。生存解析は出口集合の保存・複製を除き、待機中の作業の重複を避けた。詳細と計画からのずれはR165・R166に記した。専用保持先の追加はB2へ残し、通常値の索引と分ける。

## テストの関門と入力

既存の再利用の公開出力のテストに、複数のLetと分岐の後で入力を再び読む関数を加えた。接尾範囲を一段取り違えて早く再利用する変更を捕まえる。既存の単一の返却式の例ではこの連鎖を通らない。vm_lazyの既存の表には、兄弟の局所束縛とラムダ・lazyの多段の捕捉を確保の前後で読む例を加えた。独立した期待文字列とVMの二方式の結果で確認し、索引の自己比較はしない。公開範囲やテスト専用の本番の機能は増やしていない。

通常構成の既存の期待は変えていない。Kに従ったstressの大きさはR166に固定した。縮める場合も結果・報告位置・循環・根の全assertを残す。下位IRの容量上限の入力は大きさ自体が契約であり、実行する深い構造ではないため縮めない。

## 途中の検査

- `cargo test -p benitoite --lib bytecode::codegen::tests:: --no-fail-fast`: 終了0、20件成功、テスト本体50.89秒。初期の索引切り替えを確認した。呼び出しの記録の取り違えで同じ対象を重ねて起動したため、作業末では重ねない。
- `BENITOITE_GOLDEN_FILTER=c12-lazy-deferred cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test golden golden_suite -- --nocapture`: 終了0、外側10.920秒（ビルド待ちを含む）、テスト本体0.26秒。golden 1件・VM/参照評価1件一致・整形1件、stress除外0件。この短い試走を全対象の見込みへ外挿しない。作業末はビルド別30〜60分の仮枠とする。
- 追加したsuffixの初稿は、最後のPairを作る前にxsを別レジスタへ読み終える入力だったため、許されるConRを拒む新規assertで失敗した（外側5.056秒、調査10.142秒）。既存の期待や本番の再利用を変えず、新しい入力を最後の構成子の引数でもxsを読む形へ直した。

- `cargo test -p benitoite --lib bytecode::codegen::tests::reused_input_is_rejected_when_live_captured_or_constructor_sizes_differ`: 修正後は終了0、1件成功、外側9.723秒。
- `cargo test -p benitoite --lib bytecode::liveness::tests::`: 終了0、8件成功、外側22.002秒（並行したビルドの待ちを含む）。1,200個の無作為な原型を独立した経路・レジスタ状態の探索と比較する既存テストを含む。
- `cargo test -p benitoite --test vm_lazy`: 初稿の新規例の型名BoolがE0301となった（外側23.938秒）。Booleanへ直し、終了0、1件成功、外側1.693秒。二つの実行方式で多段の捕捉を確認した。
- `cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test vm_reference_cells retried_update_trace_keeps_the_update_call_site`: 終了0、1件成功、外側1.438秒。小さい反復数と予算でも更新の呼び直しと報告位置が維持される。

初期のコード生成の検査と重複起動分は外側の時間を取得し損ねた。上記の外側時間を明記した試走以降は、子プロセスの開始から終了までを計測した。作業末は計画どおり一度だけ走らせ、失敗時は古くなった単位だけを直す。

## 作業末の検査

T4のworkは同じ指定のdry-runで選択を確認してから一度だけ実行した。lint_defaultはR166に従ってall-targetsのclippyへ置き換えた。workと補完の検査は全て終了0であり、完了検査の再実行はない。

| 検査 | 終了 | 外側の時間 | 結果 |
|---|---:|---:|---|
| dry-run | 0 | 0.017秒 | 基準・名指し10単位・統合6ターゲットの選択を確認 |
| work | 0 | 1131.204秒 | lib 1,225件成功（既存ignore 21件）、指定統合は既定12件・heap-verify 12件・gc-stress 9件成功。docは通常17件とcompile_fail 17件成功（既存ignore 1件）。release_stack 10件成功。fmt・規約・生成Skillの照合・仕様集計も成功 |
| clippy | 0 | 11.618秒 | all-targets、警告なし |
| bytecode-heap | 0 | 73.450秒 | bytecode::の34件成功、残るlib 1,219件はフィルタで選択外 |
| bytecode-stress | 0 | 78.078秒 | bytecode::の34件成功、残るlib 1,219件はフィルタで選択外 |

実行した指定は次のとおりである。

dry-run:

```sh
scripts/check.sh --level work --base 0ea85437385b46a44abf241ddcdae8015db14639 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack,doc_default,heap_local,stress_local --test verify --test golden --test vm_handlers --test vm_lazy --test vm_reference_cells --test call_allocations --dry-run
```

work:

```sh
scripts/check.sh --level work --base 0ea85437385b46a44abf241ddcdae8015db14639 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,release_stack,doc_default,heap_local,stress_local --test verify --test golden --test vm_handlers --test vm_lazy --test vm_reference_cells --test call_allocations
```

clippy:

```sh
cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep
```

bytecode-heap:

```sh
cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify bytecode::
```

bytecode-stress:

```sh
cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify,gc-stress bytecode::
```

workのgoldenは三構成とも796入力を選び、参照評価との比較284件とcheckモードのコアIR比較64件が一致した。gc-stressは既存の `testdata/eval/list_hof_long.bnt` 一件を従来どおり除外する。今回の除外追加・ignore追加はない。call_allocationsは既存の `cfg(not(feature = "gc-stress"))` に従い、stressでは0件である。goldenのテスト本体は既定53.97秒、heap-verify 56.33秒、gc-stress 546.54秒だった。短い試走だけでは分からなかった全件の時間をここに記録する。workとclippy・二つのlib補完の外側時間の合計は1,294.350秒（約21分34秒）であり、提示した仮枠を超えていない。

既存のassertの削除・緩和、テストの削除、新しいignoreはない。test-auditの関門を通した追加は、既存の再利用テスト内の関数一つと、vm_lazyの既存の表の一行である。Rust本番の差分は追加413行・削除178行（純増235行）、Rustテストの差分は追加59行・削除4行（純増55行）である。

検査後の変更はこの結果記録とplanの試走の実施状況の追記だけである。生成Skillには差分がない。`git diff --check` は終了0。変更はcodegen・liveness・関係するテスト、設計02-07/02-08・07-04、Dのdecisions/plan/t4/resultsに限る。formal/とdocs/todoには変更がなく、コミットは作成していない。


## 申し送り

B2は専用保持先を通常値のKey・ordinary・通常の捕捉一覧へ混ぜずに追加する。実行中と保存継続の根を同じ安全点の境界で確認する。形式化した構文・定理・公理は変更していない。
