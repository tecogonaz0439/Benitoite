# F3 の実装記録

基準 B: `3a3ef9e73b460b0d89f3ae039147a0e6a61cc9b1`（F2 取り込み後）。コミットと docs/todo の変更は行わない。

## テスト作成時の関門の四問

1. CLI の終了状態・診断・非実行の報告、および型検査から交換を経て Lean の六入口までの型・効果・節の契約を守る。
2. 未処理の Fail を main/@test で許す、Fail を expanded や許可名へ混ぜる、Fail のエラー型・節の型束縛・署名由来の NoFail を交換で落とす退行を捕まえる。
3. 既存の入口の表には型付き Fail がなく、VM の成功は交換の欠落を検出しない。既存の CLI の表へ対照を加え、局所交換は既存の出力器と独立入力の検査を使う。toResult の Rest 違反は実ソースと対応する交換の負例で検査する。
4. 本番の公開 API・差し込み口・フラグを増やさない。

## 実装した範囲

CLI の契約抽出で Fail と未確定の NoFail の取り残しを拒否する。main/@test の E0506、許可名からの除外、報告形式は既存の経路を保ち、run・check・test・test --check の CLI で正負の対照を追加した。

交換 11/4 で Fail のエラー型内部を再帰して出力し、関数型・型引数と行の具体化・全 Header・標準関数とメソッド・節へ接続した。標準 raise は通常の操作表へ登録せず専用の値へ写し、handleFail とコアの Fail 節は外側で固定した E と T 一個の束縛を保つ。局所比較で見つかった直接呼び出しの差は、Rust の prepare を Lean の確定した脱糖へ合わせた（R84）。

局所交換の実ソースは次の対応である。独立入力 `formal/tests/batch2-exchange/corpus.json` の定義順の番号は 0 起点で示す。

| 実ソースの入力 | 定義数 | 独立入力との対応と固有の確認 |
|---|---:|---|
| failure-polymorphic | 4 | 定義 1 の raise、定義 3 の Fail と同じ uses の NoFail。任意の T/E、fromResult/toResult、標準の署名、ラムダの効果。Fail を潜在効果に持つ関数型を、単独とプログラム内の網羅性の両形式へ渡す |
| failure-handlers | 4 | 定義 2 の handleFail とコアの Fail 節。固定 E の別型への再 raise、節の T だけの束縛、返す関数の潜在効果、エラー型内部の Fail |
| failure-values | 5 | NoFail を持つメソッド・実装・呼び出し、raise の穴とパイプ。独立入力の署名の Q と、既存の名前付き呼び出しの規則を実ソースで接続 |
| failure-nofail | 1 | 定義 3 の NoFail。明示 Fail を引数の署名から除いた同じ変更を、Rust と交換の両方へ適用して toResult の Rest 違反を拒否 |

## 計画との差と途中の失敗

- R84: 既存の入口の宣言検査と許可名の表はすでに契約を満たすため変更しない。Rust の raise の直接呼び出しだけを、確定済みの Lean の形へ合わせる。初回の局所比較は raiseValue/translated の 2 定義で let の形が不一致となり、修正後の局所比較は一致した。Lean の定義・定理・公理・仮定には触れない。
- R85: 自動 dry-run の 7 単位から lint_default を除き、依頼の全 target の clippy を別に一度行う。残る 6 単位と開始時の全 36 統合ターゲットを plan に固定した。
- 追加テストの準備中は、診断コードの Option、EffectDef の欄、String.characterCount の既存名に入力を修正した。通常の test の拒否は空の stdout ではなく、既存の testSummary の filesNotRun=1・passed=0・failed=0 を確認する。既存の assert・期待値・ignore は変更しない。
- main/@test の拒否は開始版で既に成功しており、追加した CLI の対照は既存契約の保持を確認する。脱糖の差は修正前の局所比較で失敗を確認した。

- 最終の点検で、単独の局所網羅性が整数型だけを比較していたため、実ソースの関数型の Fail を単独・プログラム内の両形式へ追加した。変更した二つの書き出しと fmt、古くなった局所比較だけを更新し、lib と他の統合ターゲットは重ねない。

## 作業末の検査

自動 dry-run は終了 0 で 7 単位を選んだ。R85 の名指しに固定した同じ基準・全 36 ターゲットの dry-run も終了 0 となり、選択と理由を確認してから work を一度実行した。lib は 1,204 件成功・失敗 0 件・既存の ignored 21 件、全 36 統合ターゲットが成功した。既存の try/die・許可上限・非実行報告を含む。生成 Skill の照合と仕様集計、ソースの規約も成功した。

外側の時間は起動から終了までで、ビルド時間を含む。

| 検査 | 終了状態 | 外側の時間 |
|---|---:|---:|
| work F3 | 0 | 435.221 秒 |
| 網羅性入力の追加後の二つの書き出し | 0 | 5.505 秒 |
| 更新後の fmt | 0 | 2.109 秒 |
| 全 target の clippy | 0 | 6.865 秒 |
| 独立入力 7 件と局所 Rust 出力の六入口 | 0 | 1.499 秒 |
| Rest 違反・署名の Q と manifest の照合 | 0 | 0.115 秒 |

実行したコマンド:

```sh
scripts/check.sh --level work --base 3a3ef9e73b460b0d89f3ae039147a0e6a61cc9b1 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test build_info --test call_allocations --test cli_process --test coverage_export --test desugar_export --test external_signals --test fmt_command --test golden --test http_descriptor_exhaustion --test http_exchange_release --test interrupt_process --test io_modes --test l10_console_clock_process --test l13_external_commands --test l21_json --test l23_csv --test l24_time --test l30_http_server --test l31_http_serve_and_helpers --test l32_http_client --test named_arguments --test network_faults --test open_062 --test open_062_http --test package_command --test random_programs --test reference_examples --test runtime_builtins --test skill_docs --test skill_examples --test spec_examples --test test_command --test verify --test vm_handlers --test vm_lazy --test vm_reference_cells
cargo test -p benitoite --test desugar_export export_batch2_
cargo fmt --all --check
cargo clippy --all-targets
python3 -B formal/tests/test_batch2_exchange.py --rust-dir target/formal-batch2-failure
python3 -B crates/benitoite/tests/desugar_export/check_failure.py --rust-dir target/formal-batch2-failure --report docs/2026-10-17-TODO-063_087_189_191_249_255-check-policy-and-syntax-batch2/f3/exchange-results.json
```

局所出力は、通常の書き出しテストが生成する無視対象の `target/formal-batch2-failure/` の五形式と、同所の実ソースを入力とする。Fail の関数型は単独の網羅性とプログラム内の網羅性でも保持され、4 入力・14 定義の比較、Rest の具体化違反、署名由来の Q の不一致の拒否が成功した。件数と負例の結果は `exchange-results.json` に保存した。

全体の check-formal.sh、all-targets の test、特殊構成、lake build は実行していない。formal/ は変更していない。検査の失敗は作業中の準備と脱糖の局所比較だけで、作業末の work と全 target の clippy は一度で成功した。最後の追加後は古くなった二つの書き出し・fmt・局所比較だけを更新した。変更文書の新規記述にはローカルリンクを追加しておらず、参照する既存の見出しを確認した。最終の `git diff --check` も成功した。

本番の Rust は 10 行追加・2 行削除（差し引き +8 行）、テストと書き出し・照合器・manifest は 439 行追加・52 行削除（差し引き +387 行）である。既存のテストは削除せず、共通の五形式の出力と網羅性入力の準備を共用した。

## 後続への申し送り

RV3 は段 3〜4 の辞書と Fail の接続をレビューする。P1 は文字の判定を接続した後、型付きの失敗と辞書を含む本番入力全件の check-formal.sh と全件 manifest の照合を行う。今回の局所比較を全比較の成功として引用しない。F3 の局所件数と Rest の負例は交換 manifest の batch2Failure に追加し、既存の本番全件の分類・件数は変更していない。版全体と翻訳の更新は V1 に残す。
