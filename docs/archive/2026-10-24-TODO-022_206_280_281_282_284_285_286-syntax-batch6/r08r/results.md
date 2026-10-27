# R08R の作業結果

2026-10-24。基準 B_WORK と着手時の HEAD は `00fd7dfd48c81e2c244ce2d9fd6d0c8b85ad9e55`、ブランチは `mod012/R08R`。着手時の追跡ファイルの差分はなく、未追跡の入力は `reviews/RV-R08.md` だけだった。

[対応表](../reviews/RV-R08-response.md)に全10件の対応と箇所を記録した。

## 実行した検査

コマンドはリポジトリの根で実行し、`/usr/bin/time -p rtk proxy` で外側の実時間を測った。下表ではこの共通部分を省く。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `python3 -B tools/derive/test_derive.py JsonGeneration.test_unsupported_lossy_missing_dependency_and_wrong_custom_signatures PropertyGeneration.test_unsupported_dependencies_and_custom_signatures_refuse_before_artifacts` | 0。修正した既存の署名表2件が成功。別モジュールのファイル uses を純粋さの診断で拒否し、全ファイルの非書き込みも確認 | 3.56秒 |
| `cargo run -p benitoite --example gen_skill` | 0。標準ソースの変更に合わせ再生成したが、生成参照と bundle は差分なし | 8.86秒 |
| `scripts/check.sh --level work --base 00fd7dfd48c81e2c244ce2d9fd6d0c8b85ad9e55 --test skill_docs --test skill_examples --test reference_examples --test stdlib_doc_examples --test desugar_export --test spec_examples --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・python_syntax・migrate_selftests を選択。derive 自己検査は選ばないため直接実行する | 0.11秒 |
| `cargo build -p benitoite --bin benitoite --example derive_inventory` | 0。derive 自己検査用の実 CLI と inventory を現行ソースからビルド | 2.92秒 |
| 読み取りの Python による文書点検（標準入力） | 0。変更・作成した文書14点、相対リンクとアンカー225件、フェンス・末尾空白・絶対パスの不在を確認。スクリプトは保存していない | 0.07秒 |
| `scripts/check.sh --level work --base 00fd7dfd48c81e2c244ce2d9fd6d0c8b85ad9e55 --test skill_docs --test skill_examples --test reference_examples --test stdlib_doc_examples --test desugar_export --test spec_examples` | 1。fmt・clippy 成功。lib は1270成功・1失敗・21 ignored。Log の非公開入口の追加で登録が1件増え、既存の登録表の固定件数が古いことが原因。後続単位は停止により未実行 | 114.92秒 |
| `python3 -B tools/derive/test_derive.py` | 0。実 CLI・inventory を使用し49件すべて成功 | 98.89秒 |

| `cargo test -p benitoite --lib builtins::table::tests::table_names_parts_capabilities_and_schemes_are_consistent` | 0。失敗した登録表の1件が成功 | 5.28秒 |
| `scripts/check.sh --level work --base 00fd7dfd48c81e2c244ce2d9fd6d0c8b85ad9e55 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test skill_docs --test skill_examples --test reference_examples --test stdlib_doc_examples --test desugar_export --test spec_examples --dry-run` | 0。修正で古くなった fmt・clippy と、初回停止後の未実行単位を選択 | 0.02秒 |
| `scripts/check.sh --level work --base 00fd7dfd48c81e2c244ce2d9fd6d0c8b85ad9e55 --only fmt,lint_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test skill_docs --test skill_examples --test reference_examples --test stdlib_doc_examples --test desugar_export --test spec_examples` | 0。fmt・lib/tests/examples の clippy・指定統合50件（既存 ignored 1件）・ソース規約・生成参照・仕様集計・Python 構文・source-migrate 6件・try-actions 10件が成功 | 52.36秒 |
| 読み取りの Python による文書点検（記録更新後・標準入力） | 0。文書14点、相対リンクとアンカー226件、フェンス・末尾空白・絶対パスの不在を確認 | 0.07秒 |
| `git diff --check` | 0。追跡差分の空白検査成功。未追跡の対応表と本記録は上の文書点検で確認 | 0.02秒 |

## 検査の最終状態

lib は初回の1270件と修正後の1件が成功し、既存 ignored は21件である。関連統合テストは desugar_export 30件、reference_examples 1件、skill_docs 8件、skill_examples 3件、spec_examples 7件、stdlib_doc_examples 1件が成功した。未解決の失敗はない。生成参照と bundle に差分はない。検査後に加えたのは終了状態と時間の記録だけであり、本番コードと検査入力は変えていない。

本番の変更は log.rs と Log.bnt の合計で追加28行・削除7行（差し引き21行増）、テストは test_derive.py と table.rs の合計で追加25行・削除10行（差し引き15行増）である。テストの削除・追加はなく、既存の表と登録件数を変更した。今回の対応と無関係な既存テストの監査・削除は行っていない。

## 計画との差と申し送り

- 作業末の work は指定の自動選択で一度実行したが、上記の登録表テストで停止した。`builtins/table.rs` の Log 件数4→5、全件510→511、純粋な登録435→436を更新し、登録の重複・権限・署名の検査は保った。修正はテストの期待構成だけであり、本番の振る舞いはその後変えていない。成功した lib 1270件は繰り返さず、失敗した1件を直接再検査して成功した。fmt・clippy と停止後の未実行単位は、同じ基準・統合ターゲットを保った work の `--only` で実行して成功した。
- 軽2で withTextLogger の従来の診断名を保つため、log.rs に加えて Log.bnt の非公開入口を変更した。公開の署名と生成器・inventory・manifest 等の版は変えていない。
- 1 GiB の再現テストは追加していない。StrBuf に既存の上限の縮小機構がなく、テスト専用の差し込み口も追加しない。
- 過去の移行節の旧版表記は保持した。日本語訳は Z01a で同期し、06-06・03-08 に対応する訳の有無と Skill の主語の明示を確認する。
- private/ とそこを指すスキルのリンクは読んでいない。git は読み取りだけに使い、変更操作は行っていない。取り込み・独立レビュー後の段の受け入れは取りまとめが担当する。

## 取りまとめのレビューでの修正

担当が軽2のために足した非公開の組み込み関数 `Log.formatTextRecord`（と Log.bnt の宣言、登録表テストの件数の更新）を、取りまとめが戻した。1 GiB を超える場合の報告名だけのために組み込みの表を広げる理由が弱いためである。withTextLogger は公開の `Log.formatRecord` を呼ぶので、その上限超過は `Log.formatRecord` と報告する。既定の emit は `Log.emit` のままである。戻した後の検査は下の追記に記す。

戻した後の検査（取りまとめ）: `scripts/check.sh --level work --base 00fd7dfd48c81e2c244ce2d9fd6d0c8b85ad9e55 --test skill_docs --test skill_examples --test reference_examples --test stdlib_doc_examples --test desugar_export --test spec_examples` を `--dry-run` で確かめた後に一度実行した。終了0、外側の時間 155.69 秒。fmt・lib/tests/examples の clippy・lib 1271件（ignored 21）・統合6ターゲット 50件（ignored 1）・ソース規約・Skill 生成物・仕様集計・Python 構文・移行器と derive の自己検査が成功した。
