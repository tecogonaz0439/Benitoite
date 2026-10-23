# W2R の実装結果

2026-10-23、W2R 実装担当。基準 B_WORK と開始時の HEAD は `a21025354e1c08dae16b8ae089e9349831e5deed`、ブランチは `mod011/W2R` である。開始時に差分はなかった。private の参照と git の変更操作は行っていない。対象は段 II のレビュー RV-II の修正だけである。

## RV-II の各指摘への対応

| 指摘 | 受け入れ | 修正内容 |
|---|---|---|
| H1 | 受け入れ | 推奨案 1 を採った。内部の `HeapCore::alloc_str_parts` を `&[&str]` に戻し、検査と書き込みが同じ不変スライスを辿るようにした。内部に `alloc_str_space_padded(epoch, len, before, s, after)` を加え、前後の空白と `&str` を直接書く。検査付きの和が領域の長さと一致することを確保前に照合する。各 `unsafe` は一操作とし、直前の `// SAFETY:` は先頭の O2・O3 を名指しして範囲・非重複の根拠を記した。heap モジュール先頭の H12 の説明にも専用経路を加えた |
| M1 | 受け入れ | `runtime::heap::ctx` に表形式の lib テスト 1 件を追加した。先頭・末尾、空の元文字列、0 個の空白、多バイト文字・結合文字、結果のバイト列と元の内容、論理上限の直上での拒否を確認する。拒否時の確保件数も比較する。Miri の既存の選択に入る |
| L1 | 受け入れ | `string.rs` の重複した `CheckedLen::bytes` を削除し、公開の層の `ValueCtx::alloc_str_space_padded` を論理上限の検査の場所とした |
| L2 | 受け入れ | 03-01 の「理由:」に、String の純粋な関数の集合を構成によって変えないため、組込み向けの構成でも依存を共通に含める旨を加えた |
| L3 | 受け入れ | 03-06 の境界・二モードと、四関数の契約の決定に、それぞれ D12・D13 に基づく「理由:」を加えた |
| L4 | 受け入れ | 単体テストを `padding_counts_spaces_and_output_bytes` へ改名した。統合テストのコメントは、安全点後の読み直しと、gc-stress 構成で各安全点に回収が起きる条件を明記した |
| L5 | 受け入れ | 03-01 の表の欄を `unicode-width` に揃え、版は既存の直下の箇条に残した |

## test-audit の作成時の関門

追加したテストは `space_padded_strings_preserve_bytes_and_reject_oversize_before_allocation` の 1 件である。守る契約は、公開の層を経て作る文字列の正しい初期化・UTF-8 と、確保前の上限検査である。空白を書く位置・個数の誤り、バイトの欠落、元の領域への書き込み、表示の幅とバイト数の取り違え、上限検査より先に確保する退行で失敗する。

既存の文字列片の lib テストは空白追加の専用経路を通らず、六関数の統合テストは Miri の対象に入らないため、ヒープの公開の層に主となるテストを置いた。期待値は固定した文字列のバイト列と固定した資源エラーを使う。実装の呼び出し回数の注入やテスト専用の本番 API は要らない。H1 は引数の型と安全性の根拠の誤りを直すものであり、RV-II の方針どおり、悪意のある反復子による未定義動作の再現テストは加えていない。新規のテストは専用の確保経路を Miri で検査するための契約のテストであり、旧実装で失敗した退行テストとは扱わない。

既存のテストは削除していない。L1 で削除したのは本番の重複した上限検査である。L4 は検査内容を変えず、名前とコメントの主張を検査内容へ揃えた。保持した既存の単体テストは空白の個数と出力バイト数、統合テストは標準宣言・実行器の接続と gc-stress での保持を守るために必要である。ignore・時間制限・大きさ・期待値を緩めていない。

## 検査の割り当てと実行結果

| コマンド | 終了状態 | 外側の時間 |
|---|---:|---:|
| `cargo test -p benitoite --lib space_padded_strings_preserve_bytes_and_reject_oversize_before_allocation` | 0 | 13.467 秒 |
| `scripts/check.sh --level work --base a21025354e1c08dae16b8ae089e9349831e5deed --test runtime_builtins --test cli_process --test stdlib_doc_examples --test reference_examples --test skill_docs --test golden --dry-run` | 0 | 0.074 秒 |
| `scripts/check.sh --level work --base a21025354e1c08dae16b8ae089e9349831e5deed --test runtime_builtins --test cli_process --test stdlib_doc_examples --test reference_examples --test skill_docs --test golden` | 0 | 770.417 秒 |
| `scripts/check.sh --level work --base a21025354e1c08dae16b8ae089e9349831e5deed --only heap_local,stress_local --test runtime_builtins --test golden --dry-run` | 0 | 0.009 秒 |
| `scripts/check.sh --level work --base a21025354e1c08dae16b8ae089e9349831e5deed --only heap_local,stress_local --test runtime_builtins --test golden` | 0 | 641.514 秒 |
| `python3 /private/tmp/benitoite-w2r-doccheck.py` | 0 | 0.057 秒 |
| `cargo fmt --all`（作業末の検査より前の整形） | 0 | 未計時 |
| `python3 /private/tmp/benitoite-w2r-finalcheck.py`（変更 9 ファイルの末尾空白・最終改行、結果の途中状態なし、`git diff --check`） | 0 | 0.057 秒 |

作業末の work は plan.md の work W2 と同じ指定で一度実行し、heap_checks・doc_default も自動選択されて成功した。局所の特殊構成は W2 と同じ `--only heap_local,stress_local --test runtime_builtins --test golden` とし、work で済んだ doc_default は重ねなかった。両指定は本実行の前に同じ基準・引数の dry-run を確認した。指定された work・局所特殊構成に失敗・打ち切り・省略・再実行はない。

| 対象 | 件数と結果 |
|---|---|
| lib_default | 1,257 件成功・失敗 0・既存の ignore 21 件 |
| cli_process / golden / reference_examples | 31 / 2 / 1 件成功 |
| runtime_builtins / skill_docs / stdlib_doc_examples | 17 / 8 / 1 件成功 |
| doc_default | no_run の例 17 件成功・既存の ignore 1 件、compile_fail の例 17 件成功 |
| fmt / lint_default / lint_heap | すべて成功 |
| source_rules / skill_generated / spec_tally | すべて成功。生成物の再生成による差分なし |
| heap_checks: Miri 通常確保 | 59 件成功・失敗 0・既存の ignore 1 件。新しい空白追加経路のテストを含む |
| heap_checks: Miri 個別確保 | 52 件成功・失敗 0・既存の ignore 1 件。同じ新規テストを含む |
| heap_checks: 到達可能性の比較 | BENITOITE_HEAP_RANDOM_CASES=20000。51 件成功・失敗 0・既存の ignore 2 件 |
| heap_local | heap-verify 構成の golden 2 件・runtime_builtins 17 件成功。失敗・ignore は 0 |
| stress_local | heap-verify と gc-stress 構成の golden 2 件・runtime_builtins 17 件成功。失敗・ignore は 0 |
| 文書の静的確認 | 03-01・03-06 の相対リンク・アンカー 119 件、フェンス・末尾空白・最終改行を確認し成功 |

追加した lib テストは、最初の局所実行で 1 件成功した。H1 の修正前での未定義動作の再現と、退行テストとしての失敗確認は行っていない。M1 の契約のテストとして追加した理由は前節に記した。

外側の時間は Python の `time.monotonic()` で `subprocess.run` 全体を測った。途中報告で Miri のテスト出力の時間を外側の実測時間として扱ったが、work 全体の外側は 770.417 秒であり、その報告と「目安の 2 倍を超えた」という判断を訂正した。heap_checks 単独の外側の時間は分離していない。原因調査で試みた `ps -axo pid,ppid,etime,pcpu,comm` は環境の制限で拒否され、プロセスごとの詳細は取得できなかった。検査の失敗ではなく、指定された検査はすべて完了した。

実行の補助ログと計時の JSON は `/private/tmp/benitoite-w2r-*.log`・`/private/tmp/benitoite-w2r-*.json`、計時器は `/private/tmp/benitoite-w2r-run.py`、文書確認は `/private/tmp/benitoite-w2r-doccheck.py` にある。これは通常の作業の結果記録であり、別の状態の結果を引用していない。取りまとめが後で引用する際は 07-03 の引用条件の全欄を保存する。

## 計画からのずれと申し送り

- W2R の節が plan.md にないため、起動依頼に従って RV-II と work W2 の指定を使った。基準は起動依頼の B_WORK に置き換えた。
- 専用経路の追加に合わせ、`runtime/heap/mod.rs` の H12 の説明も更新した。保証・言語の規則・Lean の定義と定理・公理は変えていない。
- 幅の表がバイナリの大きさに与える影響は測定していない。実行ファイルの増分の測定は今回の計画の対象外であり、必要になれば取りまとめが Z1 または組込み向けの構成の項目で測定を割り当てる。
- コミット・取り込み、取り込み後の short、独立レビューと受け入れ、後の段へ進む判断は取りまとめが行う。docs/todo と公開の操作は担当外である。

## 差分と取りまとめへの受け渡し

Rust の差分は、本番のコードが 41 行追加・15 行削除、テストが 53 行追加・2 行削除である（コメントを含む）。本番の差分は core.rs の専用入口、ctx.rs の接続、mod.rs の不変条件の説明、string.rs の重複検査の削除である。ctx.rs に加えた 50 行と、display_width.rs・runtime_builtins.rs の名前・コメントの変更をテストへ数えた。ほかに設計書 2 ファイルとこの結果記録を変更した。

W2R が受け持つ実装と検査は完了した。未解決の言語の規則の判断、Lean の主な定理の前提・結論の変更、公理の追加を要する点はない。後の手順は取りまとめへ渡す。

| 手順 | 担当 | 見込み時間 |
|---|---|---:|
| 差分の独立レビューと取り込み | 取りまとめ | 15〜25分 |
| 取り込み後の short と判断 | 取りまとめ | 15分以内＋ビルド時間は不明 |
| RV-II の修正と検査結果の照合・受け入れ | 取りまとめ | 5〜10分 |
| 幅の表によるバイナリの大きさの測定が必要かの判断 | 取りまとめ。必要時は Z1 または組込み向けの構成の項目へ割り当てる | 不明 |
