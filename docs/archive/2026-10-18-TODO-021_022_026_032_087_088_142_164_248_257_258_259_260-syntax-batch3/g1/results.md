# G1: inventory版2と消費側・ハッシュ・移行の境界

## 基準と変更

- B_WORK: `fb1e2f1d4623e388a34f42542829b22d43e17de1`（作業開始時HEAD）。コミットとdocs/todoの変更は行わない。
- derive_inventoryを版2へ切り替え、Type/Head/Kind・署名・効果とtypes/classes/implementationsを明示した。匿名・多相implement、管理領域、正規化した可視性、opaqueと宣言元からの構築・検査可否、専用構築器の分類を出力する。内部Debugは表示用metadataに限る。
- Pythonの読者が未知のタグ・キー、番号・種類・引数数・契約名と可視性の不整合を拒否する。生成は型の木から判断し、意味のキーを選んで正準JSONをハッシュする。位置・表示・無関係な関数を意味ハッシュに含めない。
- 記録・manifestを版2、generatorVersionを2.0.0-syntax-batch3へ切り替えた。旧記録のcheckはmigration_required、旧manifestのapplyはincompatible_manifestとする。previewは旧本文のbytesを旧出力ハッシュと照合し、旧記録をmigration欄に残して新旧の意味ハッシュを比較済みと扱わない。再適用と記録書込失敗後の復旧は共通のreceiptの仕組みを保つ。
- 不透明型自身のJSON復号・Property生成器・縮小器の自動生成は、record/dataと宣言モジュール内でも拒否する。不透明型の欄は全体の手書きカスタム関数を明示した場合だけ使い、通常のcheck/testまで確認する。
- 03-06・07-04の対象外の対応表、example/道具のREADME、Skillの開発用案内を更新した。formal/と主定理は変えない。

## テスト作成時の四問

1. 観察する契約: declarationsの実入口の版2JSON、Pythonの読取境界と意味ハッシュ、実CLIの生成拒否、preview/apply/checkと本文保護、生成した関数の通常のcheck/testである。新しいRustの例で二引数の種類・匿名多相実装・管理領域・不透明型の属性を確かめる。
2. 捕まえる退行: unsupported/Debugへの逆戻り、匿名実装の欠落、未知の木や範囲外の番号の受理、表示の変更による無意味な無効化、opaqueの不変条件の迂回、旧manifestの読み替え、旧本文への手書き変更の上書きである。
3. 既存検査との差: 旧declarations例は新しい種類と匿名実装を表さず、VMの既存テストは外部JSON・生成記録を読まない。旧管理テストに新しい境界の表を加え、実際の出力・ファイル・CLIを用いる。固定関数を使う既存管理テストは残し、opaqueの拒否は本番CLI、手書きカスタムの受理は本番テンプレートとVMで確かめる。
4. 専用の差し込み口: 追加しない。既存の宣言収集/example、Pythonの読者/Manager、本番CLIを用いる。

既存のassertを削除・緩和しない。版1の型タグ・表示欄の期待は、版2の構造とmetadataの厳密な期待へ移した。R124で指定された同梱例の一件だけは、旧記録のcheck成功をmigration_requiredへ変えた。通常check/testと元の実行結果のassertは維持し、previewの本文差分空と版2の提案・旧記録非変更を確認する。これは版の契約を変更した結果であり、移行後の一致の主張はG4が復元する。

## 検査

完了した。次のコマンドはリポジトリの根で実行した。`B_WORK`は上記の完全なIDである。検査の入口内に含まれるlib・関連統合・clippy・fmtを直接重ねていない。

| コマンド | 終了状態・外側の時間 | 結果 |
|---|---|---|
| `scripts/check.sh --level work --base "$B_WORK" --test declarations --dry-run` | 0、1秒未満 | 選択と理由を確認。特殊GC構成・全統合・形式化は選ばない |
| `scripts/check.sh --level work --base "$B_WORK" --test declarations` | 1、11.58秒 | fmt成功、lint_defaultのcollapsible_ifで停止。lib以降は未実施 |
| `scripts/check.sh --level work --base "$B_WORK" --only fmt,lint_default,lib_default,tests_related,source_rules,skill_generated,spec_tally,python_syntax,migrate_selftests --test declarations --dry-run` | 0、1秒未満 | 失敗・未実施と古くなる単位だけの補完を確認 |
| 同じ補完指定の本実行（dry-runなし） | 0、78.80秒 | fmt・lint成功、lib 1211件成功（既存の長いテスト等21件は既定どおりignore）、declarations 7件成功。source_rules・skill_generated・spec_tally・Python構文成功。source-migrate 6件・try-actions-migrate 6件成功 |
| `cargo build -p benitoite --example derive_inventory --bin benitoite` | 0、0.95秒 | exampleとCLIの実ビルド成功 |
| `python3 -B tools/derive/test_derive.py` | 0、37.24秒 | 27件すべて成功。実際のinventory・formatter・CLI/VM・ファイルの読み書きを使用 |
| `cargo clippy --all-targets` | 0、11.04秒 | 全ターゲットの追加clippy成功 |

意味の変更後に完了時の一式を繰り返していない。初回workの修正後は、古くなったfmtと失敗・未実施の単位だけを補完した。spec_tallyの未参照節の一覧は表示上の情報であり、未記入の初回リリース完了条件は0件である。生成物の照合による追加差分はない。

途中の局所確認は次のとおりである。時間は出力の実行時間であり、外側の計時をしていないものはその旨を示す。

| コマンド・選択 | 結果 |
|---|---|
| `cargo check -p benitoite --example derive_inventory` | 0、Cargo表示5.32秒 |
| `cargo build -p benitoite --example derive_inventory --bin benitoite`（実装途中） | 0、Cargo表示3.16秒 |
| `python3 -B tools/derive/test_derive.py Management.test_preview_apply_check_reapply_and_empty_second_diff JsonGeneration.test_imports_preserve_module_doc` | 0、2件・5.123秒 |
| `cargo test -p benitoite --test declarations inventory_` | 101、既存例1件成功、新例の入力誤記1件失敗・0.19秒 |
| `cargo test -p benitoite --test declarations inventory_v2` | 入力修正後0、1件・0.11秒 |
| `cargo build -p benitoite --example derive_inventory` | 0、Cargo表示0.85秒 |
| `python3 -B tools/derive/test_derive.py Management.test_v2_reader_and_semantic_hash_contract Management.test_opaque_record_and_data_generation_refused_in_owner_module Management.test_v1_migration_review_and_modified_region_protection JsonGeneration.test_unsupported_lossy_missing_dependency_and_wrong_custom_signatures PropertyGeneration.test_json_and_property_two_modules_all_basic_types_and_containers` | 1、5件中3件が依存走査の引数更新漏れで失敗・5.823秒 |
| `python3 -B tools/derive/test_derive.py Management.test_opaque_record_and_data_generation_refused_in_owner_module JsonGeneration.test_unsupported_lossy_missing_dependency_and_wrong_custom_signatures PropertyGeneration.test_json_and_property_two_modules_all_basic_types_and_containers PropertyGeneration.test_property_only_nested_option_private_record_and_custom_unsupported_field` | 修正後、4件中3件成功。不要なimport要求で同梱例のみ失敗・4.176秒 |
| `python3 -B tools/derive/test_derive.py PropertyGeneration.test_json_and_property_two_modules_all_basic_types_and_containers` | 修正後0、1件・0.968秒 |
| `python3 -B tools/derive/test_derive.py Management.test_opaque_fields_use_explicit_checked_custom_functions` | 新例のResultメソッド名の誤記で1。andThenへ直した後0、1件・1.357秒 |

編集手順として`cargo fmt`を用い、最後に`git diff --check`を確認した。これらの外側の時間は未計測である。

途中はdeclarationsのinventory関係と、tools/derive/test_derive.pyの変更に関係するケースだけを実行した。入力の誤記（標準モジュール名・data構文・Result.andThen）、依存レコードを辿る呼び出しの引数の更新漏れ、型注釈でpreludeのList/Option等へ不要なimportを要求する問題を修正し、関係ケースの成功を確認した。

初回workはfmt成功後、構築器モジュールの分類にある入れ子のifをclippyが拒否した。条件を連ねて直し、古くなるfmtと失敗・未実施の単位だけを計画の補完指定で実行し、成功した。

## 計画との差と申し送り

R180に開始版・追加clippy・schema.rsへの分割・構築器の分類とreceiptの境界を記録した。依存のあるRust実装やLeanの変更は不要であった。形式化の全比較・GC特殊構成・全統合テストはG1で実行しない。

G2ではopaqueの拒否条件をJSON/Property要求に限定して、宣言元での明示要求のShow/Orderを許す。inventoryの解決済みclass/targetとsourceRegionを使ってShow/Orderの実装重複を確認し、選んだクラス実装の依存をimplementationDependenciesへ追加する。JSON/Propertyの現行テンプレートでは同欄は空列である。G4はProperty.libraryVersion（現行1.0.0）とテンプレートの版を新APIへ合わせ、People/Address・設定・記録を新previewの確認とapplyで一度だけ移す。その後、test_json_and_property_two_modules_all_basic_types_and_containersのderive check成功・preview差分空の主張を復元する。同梱の版1記録はこの作業で変更していない。
