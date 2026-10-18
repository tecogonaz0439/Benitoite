# O2 の実装結果

基準BはO1取り込みの `0583575376a305930dd8097922b6901670b70871` とする。コミットとdocs/todoの変更は行わない。

## テスト追加の関門

1. 制約付き操作の値化・穴・パイプ、外側と節の辞書0番、入れ子と節内ラムダの捕捉について、公開パイプラインからの結果を守る。交換では11/4の五形式を六入口へ渡し、辞書・型・公開名・評価順の保存を守る。
2. 辞書を公開引数へ数える、外側のParamとClauseを混同する、ラムダの自由変数を落とす、名前順に評価する、交換で根拠や節の辞書を落とす退行で失敗する。
3. O1の実行表は直接呼び出しと単純な値化を扱うが、穴・パイプ・二つの0番・入れ子の組み合わせを扱わない。既存の実行表へ行を加え、同じソースを参照実行器との比較と交換へ渡す。交換はVMでは検出できない表層とコアの独立比較を担当する。IRの拒否は既存の独立検査の変異表を保つ。
4. 本番への差し込み口は増やさず、既存のパイプライン・実行器・交換器とテスト用の共通入力を使う。

## 検査の記録

作業末のworkと局所交換の結果を後述する。途中の確認は次のとおりである。

- `cargo test -p benitoite --test vm_handlers scripts_connect_real_codegen_to_handlers_and_runtime`: 初回は共通入力の準備でTraitを二重importし失敗。準備を修正後、追加六例を含め成功（テスト本体12.63秒）。
- `cargo test -p benitoite --test random_programs constrained_operation_call_forms_differential`: 共通の六例についてDirect/RequestのVMと参照実行器が一致（2.28秒）。後に追加した三例は作業末の全統合で確認する。
- `cargo test -p benitoite --test desugar_export export_batch2_op`: 初回のコンパイルでDictExpr.ClauseのsupersとClauseInfoの欄を取り違えたため修正し、成功。段階的に入力を増やした最後の局所実行は八入力・17定義（1.69秒）。
- `cargo test -p benitoite --lib typed_try_exchange_matches_independent_corpus_ten`: 成功（1.86秒）。旧独立入力のHeaderに新版の必須の空のeffParamsだけを補った。
- `cargo test -p benitoite --test named_arguments operations_use_declared_names_and_handlers_bind_independent_local_names`: 新しい多相操作の誤ラベル例で、引数不備による未確定型のE0407も発生した。公開名の診断を分離するため、操作値に具体的な関数型を付けてから呼ぶ準備へ変更し、元の全期待値を保って成功（1.10秒）。
- Leanの局所desugarDiff: 六入力・13定義一致、対象外0件。surfaceCheckAll: 八入力・17定義一致、mismatched/outOfScope/q11/lazyRestriction/preparationFailureはいずれも0件。
- 局所surfaceCheckAllの初回はファイル名stdlib-decls.jsonと契約のstdlib.jsonの不一致で終了2。局所の出力だけを契約の名前へ移して修正した。
- 単独coverageDiffの局所確認はcoverage.jsonをプログラム内の形式で出していたため終了2。公開のcheck_match/check_bindingから単独形式を作る処理を追加し、coverage-program.jsonと分けた。workでその修正前に統合バイナリのビルドが始まっていたため、作業末の後に古くなったexport_batch2_opとfmtだけを更新する。

上記の秒数は途中のテスト本体の時間である。作業末の記録はコンパイル・起動を含む外側の時間で残す。


## 変更と計画からの差

交換器はopDicts、節の五つの自然数による根拠と上位辞書、辞書を前置した操作宣言・コア節を出力する。公開の名前・値引数の数は保つ。O1後のOpDef.arityが辞書も含むことに合わせ、交換器の等値assertは「値引数数」から「宣言の辞書数＋値引数数」へ改めた。期待を緩めず、宣言から正確な合計を求める。五形式・版の一覧・manifest・英語の説明・現行設計をそろえた。Skillを再生成したが、生成物の実差分はなかった。

判断はR76（旧独立入力の意味を保った11/4への切り替え）とR77（依頼のclippyと名指しの全36ターゲット）へ記録した。本番のRust・VM・根・Leanの規則に追加修正は要らなかった。既存assertの削除、診断の期待の緩和、ignoreの追加は行っていない。


## 作業末の検査

Bは冒頭のO1取り込みで固定し、自動dry-run（終了0）、名指しへの変更時の指定誤り（終了2）、全36ターゲットを明記した同じ指定のdry-run（終了0）を経て、workの入口を一度実行した。名指しはR77とplan.mdのwork O2に記録した。

```sh
scripts/check.sh --level work --base 0583575376a305930dd8097922b6901670b70871 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally,formal_build --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
```

| 検査 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| 上記work | 0 | 404.452秒 | libは1201件成功・既存ignored 21件。全36統合は241件成功・既存ignored 7件。規約・Skill再生成の差分確認・仕様集計・既定のlake buildとsorryの拒否も成功 |
| `cargo test -p benitoite --test desugar_export export_batch2_op` | 0 | 5.289秒 | 修正後の五形式を再生成。1件成功。workの統合バイナリに含まれなかった局所修正だけを更新 |
| `cargo fmt --all --check` | 0 | 2.101秒 | 局所書き出しの追加とコメントの修正後のfmtだけを更新 |
| `cargo clippy --all-targets` | 0 | 5.999秒 | 依頼の全target。workのlint_defaultは重ねていない |
| `python3 -B formal/tests/test_batch2_exchange.py --rust-dir target/formal-batch2-op` | 0 | 2.227秒 | 独立した正負入力の7テストと、Rustの9入力・19定義の六入口での局所比較が成功。対象外・準備失敗は0件 |

局所出力は `target/formal-batch2-op/` のcorpus.json・builtins.json・stdlib.json・coverage.json・coverage-program.jsonである。単独の網羅性はIntegerの全域パターン1件、プログラム内の網羅性は9入力の各coverage関数を含む。Failの原子は出力せず、通常節のfailureType=null、各行のnoFail=falseを明示する。

変更した文書のローカルリンク368件（見出しを含む）は欠落0件で成功（外側0.078秒）。インラインのコードとコードブロックはリンクから除いた。表と差分を確認し、`git diff --check`も終了0で成功した。exchange-manifest.jsonとrouting-manifest.jsonは、BのJSONへ版の更新だけを加えた値と完全一致することを確認し、件数・分類・理由を変えていない。全件のcheck-formal.sh、stage、all-targetsのtest、特殊構成の検査は追加していない。

## 申し送り

- F3は11/4の切り替えを繰り返さず、Failの原子・failureType・署名由来のnoFailの実値とexport_batch2_failureを追加する。
- P1とV1がcheck-formal.sh全体と全件manifestを確認する。今回の辞書の局所比較と、P1前の文字の既知差を区別する。
- 段3の集約では同じ関係状態の局所接続の結果を扱い、計画どおりstageの再実行は置かない。未コミットの差分をO1取り込みのBへ適用した状態での結果である。
- 本番のRust・VMの根・Leanの定義と証明は変更していない。コミットとdocs/todoの変更も行っていない。
