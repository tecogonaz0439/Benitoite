# G1 の実装と検査

基準B_WORK: `88764abd40932537bfbb557b9f09e26aba5a5286`（開始時の `git merge-base HEAD san_benito`）。コミットとdocs/todoの変更は行わない。formalには触れていない。

## 変更と範囲

標準LogのLevel/Value/Attribute/Recordとemit/enabledの宣言、SourceLocation.Location/hereをpreludeへ追加した。Log.Logだけを組み込み登録で識別し、usesの同名内部宣言、正規名Log、IO.All除外、main/testの宣言上限と許可・報告へ接続した。既存のcheck_report/effect_limitは共通の正規名変換を使うので、その二ファイルへ分岐を重ねていない。

位置はパイプラインの名前解決後・型検査前に通常レコードへ展開する。docも元コメントのSourceMapをこの時点で渡し、Unicode列・定義位置・import別名・利用者同名との区別を確かめた。既定Logの実出力・水準選択・補助関数は未接続であり、この作業の完了と同一視しない。

現行設計01-01/02/03/07、02-04/05、03-06/07、06-01、07-04と生成Skillをそろえた。recordの名前の扱い、私有の位置展開入口、lintの置換はR187/R188、標準追加による固定件数の期待の更新はR189に記録した。

## 作業末の検査

G1行を同じ基準のdry-runで確認した。lint_defaultは依頼のall-targetsのclippyへ置き換えた。spec_examples/reference_examples/skill_docsは全統合ターゲットに包含されるため、check.shによる重複の省略に従う。

| コマンド | 終了状態 | 外側の時間 |
|---|---:|---:|
| `scripts/check.sh --level work --base 88764abd40932537bfbb557b9f09e26aba5a5286 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test '*'` | 1 | 94.172秒 |
| `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` | 101 | 8.861秒 |
| `cargo test -p benitoite --lib builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent` | 0 | 6.515秒 |
| `cargo test -p benitoite --lib modules::tests::prelude_order_kinds_and_clock_dependency` | 0 | 0.123秒 |
| `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` | 0 | 10.197秒 |
| `scripts/check.sh --level work --base 88764abd40932537bfbb557b9f09e26aba5a5286 --only fmt,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test '*'` | 1 | 125.155秒 |
| `BENITOITE_GOLDEN_FILTER=names/unknown_module cargo test -p benitoite --test golden` | 0 | 0.161秒 |
| `scripts/check.sh --level work --base 88764abd40932537bfbb557b9f09e26aba5a5286 --only tests_related,source_rules,skill_generated,spec_tally --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test property_library --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test stdlib_doc_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells` | 0 | 201.515秒 |

最初のlib全件は1244成功・2失敗・既存ignore21件であった。失敗は組み込み表とprelude順序の旧件数の期待である。R189の追加分を厳密な期待へ反映し、この二件だけを再実行して各1成功とした。既存assertを削除・緩和していない。

最初のclippyは、新しい宣言走査の列挙型ワイルドカードを拒否した。挙動を変えず非対象の全構成子を明示し、全ターゲットの再実行を通した。成功済みlib全件は繰り返さず、未実行のwork単位と変更後のfmtを継続した。

途中の局所検査は、checked_argsのsource_location、declarations/test_command/cli_processのlog_、test_commandのsource_locationsおよびlog_handlers_receiveを使った。いずれも最後の実行は成功した。局所試行は外側の一括計時をしていない。試行中のコンパイル誤りと、新規ハンドラ例のresume引数の取り違えは修正し、診断の期待や観察対象を緩めていない。

全統合ターゲットの最初の実行はgoldenで停止した。801ケース中、names/unknown_moduleのE0302の類似名候補へ新しいpreludeのLogが増えた一件だけが不一致であった。R190に従ってJSON全体の厳密な期待へLogを足し、`BENITOITE_GOLDEN_FILTER=names/unknown_module`でそのケースを再実行して成功した。先に成功した9ターゲットを繰り返さず、golden以後の30ターゲットを名指しして全40ターゲットを完了した。golden入力ソースは変えておらず、コード生成・verifyのcorpusもそのまま検査した。

最後のwork継続は終了0で、未実行だったsource_rules・skill_generated・spec_tallyも成功した。spec_tallyに未記入の初回リリース受け入れ条件はなかった。RustとBNTの差分は、生成bundleを含む本番503行追加・37行削除、テスト227行追加・4行削除である。削除4行は固定件数の期待値行の差し替えであり、既存assertとテストを削除・ignoreにしていない。テスト専用の本番APIを増やしていない。git diff --checkも成功した。

## 申し送り

G2はsrc/builtins/funcs/log.rsの二つの既定処理を既存IOへ接続し、Log.bntへ通常の補助関数・型クラス・ハンドラを追加する。未接続の既定処理は現在Internalを返す。SourceLocation.hereの実行入口も展開漏れをInternalとして拒否する。標準宣言の本番交換、両IO方式の既定出力・一回性・順序・失敗はG2の検査へ残す。版の変更・翻訳・全形式化比較・改造全体の検査は後段へ残す。

作業末の外側の計時の合計は446.699秒である（失敗・修正後の実行を含む。実装時間と局所試行は含めない）。
