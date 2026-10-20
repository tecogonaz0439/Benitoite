# B1 の結果

基準は `c0c46e7855a91e51cc41e6ec076211bc5bdac72d`（開始時の `git merge-base HEAD san_benito`）である。コミットと docs/todo の変更は行わない。

## 入力の大きさとテストの関門

予約前の論理上限超過を実 Host の操作で確かめるため、String は同じ 1 MiB の文字列を共有する 1,024 要素のリスト、List は同じ一要素のリストを24回自己連結した論理長 2^24 の共有入力を使う。既に一つ追記した構築器へ appendAll し、R0902・内容不変・予約呼び出し0回を確認する。大きさそのものが論理上限の契約なので、既定・heap-verify・gc-stress・Miriで同じ大きさを保つ。構築器に1 GiBの出力や2^24個のSlotを予約させない。共有しない長い入力は作らない。他の新規入力はリスト長64以下、再帰なしとする。

主な検査の持ち主は実ヒープ上の構築器入口である。copy後の追記がsnapshotを変える退行、ListのTrace漏れ、容量再計数の漏れ、予約前の部分追記を捕まえる。既存検査は旧Reference経路と汎用Hostを対象とし、この三つの私有バッファを通らない。外部依存の予約だけを私有traitで差し替え、公開の試験API・環境変数・unsafeを増やさない。診断は既存のStopから報告までの表へ一行追加する。

## 検査

作業末の実行は、planのB1行と補完行に従う。R170によりlint_defaultだけを同じ作業末の全ターゲットclippyへ置き換えた。workのdry-runは終了0で、指定した単位とruntime_builtins、Miri二構成・到達可能性比較への接続を確認した。完了した結果と外側の時間は下表に記す。

途中は `cargo check -p benitoite --lib`、`cargo test -p benitoite --lib runtime::heap::builders::`、`cargo test -p benitoite --lib runtime::report::tests::stops_choose_codes_and_fill_arguments` だけを実行した。生成Skillは `cargo run -p benitoite --example gen_skill` で再生成した。構築器5件と報告の既存テスト1件は成功した。

途中のコンパイルでは、ResourceErrorを網羅するexternal/statsの新しい分岐と、テスト補助の寿命の共有が不足していたため修正した。新規テストではlive_bytesを回収前の使用量と誤認して失敗したため、回収前はallocated_bytes、回収後はlive_bytesで確かめ、容量だけの増分を独立に照合する検査も加えた。既存テストの期待値・assert・ignoreは変えていない。

作業末の最初のclippyは終了101、外側8.911秒だった。checked_mulとunwrap_orの併用、関数ポインタ型の複雑さ、新規テストの列挙型のワイルドカードが原因であった。checked_mulを明示したmatchへ直し、関数ポインタ型に私有の別名を付け、列挙分岐を明示した。lintの許可は追加していない。未実行だったworkと補完を含めて検査を継続した。

最初のworkはMiriの論理上限検査中に中断した（終了130、ログ作成から中断後の記録まで約459秒）。heap-verifyのstrが同じ断片のUTF-8を繰り返し検査し、Stringの事前走査だけで1 GiBを再走査するためである。R171に従って長さの取得を修正した。入力・期待値・assertは維持し、ignoreは追加していない。修正後の構築器の局所5件は再び成功した。

再実行は、変更で古くなったfmt・既定/heapのclippy・lib・doc・heap_checksに絞った。最初のworkで成功済みのruntime_builtins三構成・規約・生成物・仕様集計は、R171で入力や契約を変えていないため重ねなかった。R171の入口はB1ではVMや既存組み込みに接続せず、新しい構築器のStringの事前走査だけが呼ぶ。補完の局所lib二構成は未実行だったため、work後に実行し、両構成とも成功した。

## 作業末のコマンドと結果

基準の指定は全て上記のB_WORKで固定した。次の二つのworkは、それぞれ同じ引数に `--dry-run` を付けて選択を確認した（終了0）。終了130のworkは、成功した単位だけを記録し、work全体の成功には数えない。

```sh
# 最初のwork。heap_checksのMiri中にR171の修正のため中断した。
scripts/check.sh --level work --base c0c46e7855a91e51cc41e6ec076211bc5bdac72d --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,doc_default,heap_local,stress_local,lint_heap,heap_checks --test runtime_builtins

# R171で古くなった単位の再検査。
scripts/check.sh --level work --base c0c46e7855a91e51cc41e6ec076211bc5bdac72d --only fmt,lint_heap,lib_default,doc_default,heap_checks

# R170の既定構成のclippy。R171後も同じ指定で再検査した。
cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep

# planのB1の補完行。
cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify runtime::heap::
cargo test -p benitoite --lib --no-default-features --features gc-mark-sweep,heap-verify,gc-stress runtime::heap::
```

| 実行 | 終了状態・結果 | 外側の時間 |
|---|---|---|
| 最初のwork | 130で中断。fmt・lint_heap・lib_default・tests_related・doc_default・source_rules・skill_generated・spec_tally・heap_local・stress_localは成功。lib 1,233件、runtime_builtinsは既定/heap/stress各10件、docは通常17件とcompile_fail 17件 | 約459秒。ログ作成から中断後の記録まで |
| R171後の既定clippy | 0。全ターゲット、警告なし | 6.761秒 |
| R171後のwork | 0。fmt・lint_heap・lib_default・doc_default・heap_checksが成功。lib 1,233件、docは通常17件とcompile_fail 17件 | 726.975秒 |
| 補完のheap-verify局所lib | 0。50件成功、既存のlong 2件は計画どおり通常実行の対象外 | 2.860秒 |
| 補完のheap-verify+gc-stress局所lib | 0。50件成功、同じ既存のlong 2件は対象外 | 32.131秒（ビルドを含む） |

heap_checksはcheck-heap.sh全体を実行した。Miriの通常構成は57件成功、対象ごとの確保は51件成功し、各1件の既存のMiri専用ignoreを保った。新しい構築器5件は両構成とも成功した。続く到達可能性比較は `BENITOITE_HEAP_RANDOM_CASES=20000`、各320操作で、50件成功した。これを局所libの既定24系列の結果と混同しない。Miriのテスト内部に表示された経過時間を実時間へ換算せず、上表ではPythonのmonotonic時計による外側の実測だけを使った。

最終差分の空白検査 `git diff --check` は終了0。未追跡の新規Rust二ファイルと本記録も行末空白を確認した。既存テストのassert削除・期待値の緩和・ignore追加はない。formalは変更せず、形式化の全比較・全all-targetsテスト・ベンチマークは実行していない。

## 計画からのずれと申し送り

R169に、applyの可変借用とhost_mutの内部入口を共有する変更、B1での入口のコンパイルとexternal/statsの網羅的分類を記した。R170に、依頼のall-targetsのclippyへの置換、R171に、不変文字列の見出しから追加長を読む変更を記した。公開のHeap・host_mutの署名、ObjKind、unsafe、formalの定義は変更していない。

B2は `runtime::heap::builders::{new, apply}` を専用SlotとVMへ接続する。applyの引数列は受け手を含まない通常値だけであり、NoGc区間を閉じる前に戻り値を根へ保存する。既定のReference実行経路はB1では切り替えない。独立参照評価・継続・タスクの保持はB2へ残る。入口の関数ポインタ型を検査する無名constは、B2の実呼び出しの接続後に外せる。

処理系の本番コードは差し引き430行増、テストコードは414行増である（runtime/report.rsの新規テスト行をテスト側に計上し、文書・生成Skillは除く）。既存テストの削除や整理は行っていない。B1の完了条件と補完は全て成功し、B2へ渡せる状態である。
