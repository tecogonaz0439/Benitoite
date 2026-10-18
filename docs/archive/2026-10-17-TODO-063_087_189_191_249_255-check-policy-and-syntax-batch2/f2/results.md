# F2 の実装記録

基準 B: `2b962263861d836364dc332e543d327cbed2cbb4`（F1 取り込み後）。コミットと docs/todo の変更は行わない。

テスト作成時の関門の四問:

1. 公開の型検査・独立 IR 検査・実行結果・CLI の診断を境界に、Result との変換、非再開、解放順と一度だけの解放、子タスクと lazy の制限を守る。
2. 成功と失敗の二重の包み込み、二重評価、後続要素の実行、E の消失、解放時の回収によるエラー値の消失、解放失敗や die の誤捕捉、子での親の非再開節の使用を捕まえる。
3. F1 の手書きの handle は標準の変換関数とその NoFail の伝播を検査しない。既存の VM の表に変換の対照を加える。Writer の実物の転送で解放順と回数を確かめ、子プロセスのサイズ制限で解放失敗を発生させる。golden の成功例は参照実行器との接続、IO の順序のテストは完了順の差、局所特殊構成は安全点を越える値の保持をそれぞれ守る。
4. 本番の公開範囲・注入・フラグは増やさない。通常の標準ソースと既存の実行経路を使う。

## 実装した範囲

Failure.bnt に fromResult の match と toResult の handle を実装した。エラー型と NoFail は通常のシグネチャから得る。型検査器・脱糖・VM・GC 本体・formal/ は変更しない。現行設計、英語リファレンスの実行例、Skill の手書きの説明と生成物を更新した。

## 検査

作業中は関係する vm_handlers、vm_lazy、io_modes の新規テスト、l10_console_clock_process の新規テスト、f2- の golden に限定した。作業末の検査結果は次のとおりである。

作業末は R82 の固定した指定の dry-run が終了 0 となり、36 ターゲットとの一致と、spec_examples/reference_examples/skill_docs が tests_related に含まれて重複しないことを確認してから実行した。以下の外側の時間はプロセスの起動から終了までであり、ビルド時間を含む。

| 検査 | 終了状態 | 外側の時間 |
|---|---:|---:|
| work F2 | 0 | 429.631 秒 |
| clippy | 0 | 7.235 秒 |
| heap-verify | 0 | 72.507 秒 |
| gc-stress | 0 | 75.782 秒 |

実行したコマンド:

```sh
scripts/check.sh --level work --base 2b962263861d836364dc332e543d327cbed2cbb4 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,spec_examples,reference_examples,skill_docs --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
cargo clippy --all-targets
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --test vm_handlers --test vm_lazy
cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --test vm_handlers --test vm_lazy
```

通常の work は一度で成功した。lib は 1,204 件成功・既存の ignored 21 件、全 36 統合ターゲットは成功した。生成物の照合、仕様集計、ソースの規約、fmt も成功した。局所の各特殊構成は vm_handlers の 2 件と vm_lazy の 1 件がすべて成功した。全 target の clippy も成功した。文書のローカルリンクの対象と新しい見出しへのリンクを確認した。



## 計画との差と失敗の処置

- R82: 依頼の全 target の clippy を一度実行するため、work の lint_default を外す。全統合ターゲットは開始時の 36 件に固定する。
- R83: 関数呼び出しへの明示的な型引数は既存の構文で拒否される。E の指定は結果か body の型注釈とし、設計案の案内をそろえた。
- 追加テストの初回入力では、import の位置、ブロックの式、引数ラベル、関数型の括弧、ラムダの return を既存の構文に合わせて修正した。Cargo の局所フィルタを二つ並べた指定は引数エラーとなったため、ターゲットごとに分けた。
- 既存の IO の順序の実行器は Reader の解放が仕事を送らない契約を assert している。これを保ち、Writer の解放の検査を vm_handlers に置いた。io_modes には二つの子が実物の読み込み後に各自で Result を返す対照を加えた。
- 解放失敗の既存の診断は、通常の打ち切り・return では一つの runtime 報告の notes に二件を含み、die では二つの release 報告となる。新しい期待をこの既存契約に合わせ、二件の順序と件数を検査する。既存の assert・期待・ignore は変更しない。

## 後続への申し送り

F3 は計画どおり CLI の入口と交換 11/4 の Fail・NoFail の実データを接続する。版と訳の更新は V1 に残す。
