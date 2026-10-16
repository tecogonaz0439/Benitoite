# P1 の移行候補の確認表

## 確認表の読み方

Q6/R1 の範囲をファイルに対応付けた一覧である。[baseline.md](baseline.md) の HEAD と入力ハッシュを比較元とする。下表の数は study の簡易字句走査の候補であり、実行可能な手本や AST の TryExpr の数ではない。計 646 候補 / 166 ファイルをすべて載せる。行はホスト内の位置であり、同じ行の複数候補も数に含む。

「実行例を確認」は、コードブロックだけでなくインライン・コメント・文字列内の例も確認するという意味である。構文名・EBNF・IR の擬似記法・他言語の比較・移行前の引用は保持理由を記録する。各例の処置と契約の確定は M2〜M4 で行い、この表を未確認のまま自動適用しない。main/一回限りは die、再利用は return を基本とし、伝播を教える main、純粋な例、ベンチマークの同じ仕事量を保つ場合は return にする。

| 群 | 候補数 / ファイル数 | 担当と基本の扱い |
|---|---:|---|
| 標準ライブラリの実装 | 3 / 2 | M4、or return。公開の戻り値・uses・失敗値を維持 |
| testdata | 195 / 66 | 裸の検査として保持。入力・期待値・失敗理由を一律移行しない |
| 現在の tools の .bnt | 133 / 38 | bench 88 / 27、skill-eval 45 / 11。M4 で手本を明示。性能測定/LLM 評価はしない |
| Rust ホスト | 206 / 38 | 検査/開発生成器と、診断/Skill の生成元を区別。下表参照 |
| 英語リファレンス | 7 / 1 | M3c、実行例を確認 |
| Skill 手書き | 36 / 4 | M3c、実行例を確認 |
| 現行設計書のブロック | 23 / 12 | M3a/M3b、実行例と記法を区別 |
| 日本語訳 | 43 / 5 | M8、最終の英語版と照合 |
| Skill 生成物のブロック | 0 / 0 | 0 は更新不要を意味しない。生成元から作り直す |

## 旧抽出の全候補

| ファイル（リポジトリ相対） | 候補数 | ホストの行 | 次の扱い |
|---|---:|---|---|
| `crates/benitoite/examples/stack_probe/support.rs` | 2 | 160, 172 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/skill/SKILL.md` | 1 | 125 | M3c: 実行例/記法を確認 |
| `crates/benitoite/skill/references/common-mistakes.md` | 1 | 363 | M3c: 実行例/記法を確認 |
| `crates/benitoite/skill/references/idioms.md` | 33 | 50, 52, 121, 129, 130, 131, 176, 177, 179, 223, 224, 225, 227, 228, 232, 288, 289, 295, 318, 321, 323, 343, 345, 378, 409, 410, 411, 421, 425, 426, 428, 429, 640 | M3c: 実行例/記法を確認 |
| `crates/benitoite/skill/references/language-comparison.md` | 1 | 176 | M3c: 実行例/記法を確認 |
| `crates/benitoite/src/builtins/funcs/console/tests.rs` | 1 | 181 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/builtins/funcs/file/path_tests.rs` | 4 | 785, 786, 787, 788 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/builtins/funcs/file/resource_tests.rs` | 20 | 544, 545, 550, 551, 585, 586, 587, 588, 672, 739, 879, 880, 980, 990, 1000, 1013, 1024, 1035, 1047, 1059 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/src/builtins/funcs/file/tests.rs` | 8 | 358, 400, 434, 435 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/src/builtins/funcs/http_server/tests.rs` | 3 | 288, 303, 310 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/src/builtins/funcs/regex/tests.rs` | 10 | 151, 160, 210, 243, 324, 334, 354, 365, 366, 482 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/src/cli/tools/formatter/print/tests.rs` | 4 | 144, 159, 322, 331 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/cli/tools/skill/generate.rs` | 1 | 69 | M3/M5: Skill 生成元の構文の説明を確認 |
| `crates/benitoite/src/diag/codes.rs` | 11 | 223, 259, 638, 753, 758, 759, 760, 765, 766 | M3: E0201 question の修正例。他は記法/診断として個別確認 |
| `crates/benitoite/src/diag/render/help_tests.rs` | 1 | 534 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/ir/desugar/tests.rs` | 3 | 148, 768, 772 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/prelude/stdlib/IO/File.bnt` | 1 | 68 | M4: or return、契約維持 |
| `crates/benitoite/src/prelude/stdlib/Network/Http.bnt` | 2 | 73, 80 | M4: or return、契約維持 |
| `crates/benitoite/src/refinterp/tests.rs` | 7 | 175, 530, 573, 575, 619 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/src/runtime/io/http/tests.rs` | 2 | 1102, 1293 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/src/runtime/run/tests/test_entry.rs` | 2 | 173, 174 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/syntax/parser/effects.rs` | 6 | 775, 810, 817, 846, 850, 851 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/syntax/parser/mod.rs` | 1 | 2195 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/syntax/parser/patterns_ext.rs` | 2 | 458, 460 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/typeck/effects/mod.rs` | 1 | 76 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/typeck/effects/tests.rs` | 26 | 357, 471, 476, 489, 494, 499, 504, 516, 521, 531, 537, 543, 546, 549, 552, 555, 561, 564, 687, 699, 731, 733, 737, 743, 746 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/src/typeck/tests.rs` | 1 | 917 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/src/vm/dispatch/tasks/tests/cancellation.rs` | 1 | 1668 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/testdata/acceptance/json_summary.bnt` | 3 | 23, 24, 29 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/acceptance/process_run.bnt` | 3 | 9, 12, 14 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/acceptance/process_shell.bnt` | 2 | 9, 11 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/acceptance/test_replaces_effects.bnt` | 1 | 9 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/concurrency/c12-cancelled-reader.bnt` | 1 | 22 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/effects/c11-try-not-result.bnt` | 1 | 3 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/effects/f04_resources.bnt` | 4 | 5, 6, 7, 8 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/effects/first-release-try.bnt` | 3 | 7, 12, 13 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/effects/first-release-with.bnt` | 2 | 4, 5 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/eval/named_contracts.bnt` | 1 | 11 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/eval/named_escape.bnt` | 1 | 16 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/eval/named_partials.bnt` | 1 | 36 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/handlers/c12-builtin-port.bnt` | 1 | 9 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/handlers/c12-discard-reader.bnt` | 1 | 16 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/handlers/first-release-port.bnt` | 1 | 5 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/handlers/secf1-clause-local.bnt` | 1 | 17 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-close-reader-twice.bnt` | 1 | 10 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-process-exit-flush.bnt` | 2 | 10, 11 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-reader-lines.bnt` | 5 | 9, 10, 11, 12, 13 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-stdin-lines.bnt` | 4 | 8, 9, 10, 11 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-stdin-remaining.bnt` | 3 | 8, 10, 12 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-with-reader-release.bnt` | 2 | 12, 14 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-with-return-release.bnt` | 1 | 10 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-with-try-release.bnt` | 2 | 10, 12 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/c12-write-append.bnt` | 3 | 9, 10, 11 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-console-bytes.bnt` | 2 | 7, 10 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-console-lines.bnt` | 3 | 8, 9, 10 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-file-paths.bnt` | 16 | 10, 11, 14, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 40, 41, 42 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-file-resources.bnt` | 15 | 9, 14, 20, 22, 23, 24, 25, 26, 28, 29, 31, 33, 34, 36, 38 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-json-total.bnt` | 3 | 8, 9, 19 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-process-attached.bnt` | 1 | 8 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-process-commands.bnt` | 2 | 10, 14 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/io/l40-process-environment.bnt` | 3 | 10, 13, 14 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/address-in-use.bnt` | 1 | 8 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/redirect.bnt` | 7 | 9, 10, 12, 19, 21, 22, 24 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/respond-twice.bnt` | 3 | 8, 10, 11 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/routes-and-post.bnt` | 8 | 24, 44, 48, 49, 51, 52, 53, 54 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/status-above-range.bnt` | 2 | 8, 10 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/status-below-range.bnt` | 2 | 8, 10 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/status-informational.bnt` | 2 | 8, 10 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/todo194-json-parse-server.bnt` | 8 | 22, 33, 40, 44, 45, 46, 47, 48 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/todo198-cancelled-accept-reregisters.bnt` | 7 | 20, 26, 27, 29, 30, 31, 33 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/network/unanswered-exchange.bnt` | 4 | 8, 10, 14, 15 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/json-pure-depth-array/main.bnt` | 2 | 17, 18 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/json-pure-depth-object/main.bnt` | 1 | 17 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/json-pure-same/main.bnt` | 5 | 103, 104, 107, 108, 109 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/json-wasm-same/main.bnt` | 8 | 81, 86, 183, 184, 187, 188, 194, 195 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/libraries.files/pure-json/Numbers.bnt` | 2 | 14, 15 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/libraries.files/pure-json/Parser.bnt` | 7 | 12, 39, 43, 47, 51, 55, 105 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/libraries.files/pure-json/Strings.bnt` | 3 | 21, 61, 69 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/libraries.files/wasm-json/Codec.bnt` | 1 | 19 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/todo-handler/deps/todo/Store.bnt` | 1 | 11 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/wasm-hash-same/main.bnt` | 1 | 23 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/packages/wasm-regex-same/main.bnt` | 1 | 50 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/stdlib/l40-csv.bnt` | 4 | 8, 11, 13, 16 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/stdlib/l40-encoding-hash.bnt` | 2 | 15, 16 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/stdlib/l40-json.bnt` | 3 | 8, 13, 17 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/stdlib/l40-regex.bnt` | 3 | 8, 12, 14 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/stdlib/l40-time.bnt` | 4 | 8, 13, 16, 18 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/syntax/c11-try-catch.bnt` | 1 | 3 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/syntax/f04_try.bnt` | 1 | 3 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/test/handler_replacement.bnt` | 1 | 6 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/test/result_error.bnt` | 2 | 10, 16 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/types/todo178-e0439-try-match.bnt` | 1 | 3 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/types/todo178-placeholder-try-error.bnt` | 1 | 7 | 裸の検査/補助入力として保持 |
| `crates/benitoite/testdata/types/todo178-placeholder-try-run.bnt` | 1 | 8 | 裸の検査/補助入力として保持 |
| `crates/benitoite/tests/http_descriptor_exhaustion.rs` | 4 | 24, 26, 31, 36 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/http_exchange_release.rs` | 6 | 28, 29, 34, 55, 64, 66 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/interrupt_process.rs` | 3 | 337, 338, 395 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/tests/io_modes.rs` | 8 | 359, 360, 389, 390, 391, 419, 421, 470 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/l13_external_commands.rs` | 7 | 118, 124, 127, 129, 153, 186, 225 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/tests/l21_json.rs` | 4 | 65, 103, 104, 120 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/l30_http_server.rs` | 9 | 160, 163, 164, 349, 489, 569, 597, 600, 601 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/tests/l31_http_serve_and_helpers.rs` | 2 | 290, 342 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/tests/l32_http_client.rs` | 17 | 124, 132, 152, 159, 160, 161, 162, 163, 164, 194, 196, 201, 205, 516, 539, 562, 564 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/tests/named_arguments.rs` | 2 | 701, 703 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/network_faults.rs` | 4 | 220, 222, 227, 228 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/tests/open_062.rs` | 6 | 688, 689, 745, 910, 996, 997 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/open_062_http.rs` | 5 | 261, 263, 392, 405, 407 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/random_programs/generator.rs` | 7 | 623, 624, 882, 883, 1124, 1131, 1182 | 裸の検査/開発生成器として保持。連結/生成断片は M2 の範囲確定待ち |
| `crates/benitoite/tests/runtime_builtins.rs` | 3 | 125, 188, 189 | 裸の検査/開発生成器として保持 |
| `crates/benitoite/tests/vm_handlers.rs` | 2 | 112, 119 | 裸の検査/開発生成器として保持 |
| `docs/design/01-spec/01-01-lexical.md` | 1 | 88 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/01-spec/01-02-syntax.md` | 1 | 822 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/01-spec/01-07-effects.md` | 2 | 225, 301 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/01-spec/01-09-errors.md` | 2 | 52, 53 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/01-spec/01-10-resources.md` | 3 | 35, 36, 37 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/01-spec/01-11-concurrency.md` | 2 | 139, 149 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/02-impl/02-03-frontend.md` | 1 | 68 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/03-interop/03-07-io-modules.md` | 2 | 159, 165 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/03-interop/03-08-text-and-data.md` | 3 | 121, 122, 169 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/03-interop/03-09-network.md` | 2 | 104, 111 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/06-tooling/06-04-test-runner.md` | 2 | 68, 85 | M3a/M3b: 実行例/記法を確認 |
| `docs/design/08-appendix/08-04-fp-syntax-comparison.md` | 2 | 1103, 1104 | M3a/M3b: 実行例/記法を確認 |
| `docs/ja/reference/benitoite.md` | 7 | 596, 598, 1045, 1046, 1051, 1052, 1053 | M8: 英語版から訳す |
| `docs/ja/skill/SKILL.md` | 1 | 132 | M8: 英語版から訳す |
| `docs/ja/skill/references/common-mistakes.md` | 1 | 366 | M8: 英語版から訳す |
| `docs/ja/skill/references/idioms.md` | 33 | 53, 55, 124, 132, 133, 134, 179, 180, 182, 226, 227, 228, 230, 231, 235, 291, 292, 298, 321, 324, 326, 346, 348, 381, 412, 413, 414, 424, 428, 429, 431, 432, 643 | M8: 英語版から訳す |
| `docs/ja/skill/references/language-comparison.md` | 1 | 179 | M8: 英語版から訳す |
| `docs/reference/benitoite.md` | 7 | 593, 595, 1042, 1043, 1048, 1049, 1050 | M3c: 実行例/記法を確認 |
| `tools/bench/programs/http.bnt` | 5 | 23, 27, 38, 39, 40 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/Runner.bnt` | 5 | 14, 15, 21, 29, 31 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/hash-a.bnt` | 3 | 10, 11, 12 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/hash-c-fast.bnt` | 3 | 15, 16, 17 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/hash-c-list.bnt` | 3 | 15, 16, 17 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/json-a.bnt` | 9 | 17, 18, 19, 20, 29, 34, 40, 48, 53 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/json-b.bnt` | 9 | 22, 23, 24, 25, 34, 39, 45, 53, 58 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/json-c.bnt` | 10 | 15, 16, 17, 18, 23, 28, 41, 42, 46, 47 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/regex-a.bnt` | 5 | 10, 11, 12, 14, 15 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/regex-c-once.bnt` | 4 | 15, 16, 17, 19 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wasm/regex-c-resource.bnt` | 5 | 15, 16, 17, 19, 20 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/Runner.bnt` | 4 | 8, 9, 10, 11 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/flags.bnt` | 1 | 122 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/large-bytes-adapter.bnt` | 1 | 10 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/large-bytes-typed.bnt` | 5 | 10, 11, 12, 13, 14 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/large-bytes.bnt` | 1 | 12 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/maps.bnt` | 1 | 13 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/nested.bnt` | 1 | 10 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/numbers.bnt` | 1 | 43 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/primitives.bnt` | 1 | 18 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/records.bnt` | 1 | 30 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/short-numbers-adapter.bnt` | 3 | 10, 11, 13 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/short-numbers-typed.bnt` | 1 | 10 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/short-numbers.bnt` | 3 | 12, 13, 15 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/tuples.bnt` | 1 | 29 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/utf16.bnt` | 1 | 12 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/bench/wit-transfer/variants.bnt` | 1 | 42 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/csv_report/reference.bnt` | 8 | 13, 14, 15, 21, 22, 23, 24, 31 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/dir_walk/reference.bnt` | 5 | 5, 11, 21, 23, 30 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/error_handling/reference.bnt` | 1 | 16 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/file_process/reference.bnt` | 2 | 12, 15 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/http_client/reference.bnt` | 13 | 13, 14, 15, 24, 25, 27, 28, 29, 30, 31, 32, 40 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/json_convert/reference.bnt` | 4 | 19, 20, 28, 30 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/json_summary/reference.bnt` | 4 | 21, 22, 27, 28 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/process_run/reference.bnt` | 2 | 6, 8 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/process_shell/reference.bnt` | 2 | 5, 9 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/regex_text/reference.bnt` | 3 | 6, 7, 8 | M4: 実行例を確認（bench は return で仕事量維持） |
| `tools/skill-eval/tasks/write_tests/reference.bnt` | 1 | 13 | M4: 実行例を確認（bench は return で仕事量維持） |

## 旧抽出の外側と保留の確認先

全追跡入力と補完の位置は [inputs.json](inputs.json) の files / raw_hits にある。try がないファイルも一覧に含めているので、新しい生成断片や版・属性の変更が必要になったときも元のハッシュを比較できる。

| 確認先 | P1 での扱いと次の担当 |
|---|---|
| docs/reference/benitoite-minimal.md | try 0 件を確認。旧版用なので、新しい構文を追加しない |
| crates/benitoite/examples/ の .bnt と Rust | 現在、try の抽出候補は stack_probe/support.rs の 2 件のみ。深さ/スタックの開発生成器なので保持。今後、手本を出力する生成器を足したら M4 の対象 |
| docs/design/01-spec/01-09-errors.md:39〜44、docs/reference/benitoite.md:578〜595 | 構文名とインラインの実行例が混在。記法の try と、伝播を教える実行例の return を区別して M3 で確認 |
| Skill の SKILL.md、common-mistakes.md、language-comparison.md のインライン | ブロックの候補数に含まれない例も M3c で確認。他言語の try/catch と用語だけの try を機械的に書き換えない |
| diag/codes.rs:223 → lexical/unknown_symbol.diag.json と diag/render/help_tests.rs | E0201 question の例を M3 で or return に変更。主文・位置・終了状態・元の誤りを維持し、新 help 全文を厳密に比較 |
| skill/references/grammar.md、diagnostics.md、stdlib/ と日本語訳 | 手で生成物を直さない。M3〜M5 の生成元の修正と gen_skill、M8 の訳で対応 |
| tests/random_programs/generator.rs、tests/desugar_export/、fuzz/ | 裸の入力、生成件数、期待、必要項目、対象外理由を保持。意味を試す入力へ一律に処置を付けない |
| Rust の format!/concat!/include_str と補間内の Benitoite | raw_hits はホストの位置の補完のみ。分割・復号・連結・生成後の本文の確定は M1/M2。未確定の範囲を自動編集しない |
| language の宣言と package の固定ハッシュ | study_language_declarations と raw_hits を併用。M6a で通常/古い/未来/不正な版、ハッシュ不一致の検査を分類し patch を確認してから M7 で適用 |
| tools/named-arguments-migrate/ | 前回用の道具。M1 はホストの復号/ハッシュ等の共通部分だけを再利用し、旧 BASE と意味判定を今回に読ませない |
| reference/・docs/archive/・過去の測定記録・tools/syntax-measure/ | 歴史資料として適用しない。追跡されている除外ファイルの件数は excluded_tracked_counts に記録 |

P1 の段階では個々の実行例の die/return、説明文、uses・戻り値・mapError の変更は未確定である。これは M2〜M4 の責務であり、P1 の候補一覧が適用を承認するものではない。M5 で裸の検査の基準と照合し、手本/記法/移行前/検査/歴史資料/保留の件数を最終確定する。
