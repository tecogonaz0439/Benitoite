# 宣言情報の範囲対応と停止作業の再開

## 対象と状態

B_WORK は `42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab`、作業先は `m013/r30.2c` である。R30.2c の未コミットの実装・検査・記録を引き継いだ。範囲対応と局所検査、同梱例の移行、derive の自己検査、最終の W-R が成功し、R30.2c と今回の担当する実装・検査を完了した。取りまとめの独立レビューと受け入れは別に行う。

`private/`・それを指すリンク・`docs/todo/` は読んでいない。Git の状態を変える操作、依存とツールチェーンの変更、`lake build`・`check-formal.sh`・short は行っていない。別ディレクトリの R30.3c は変更していない。既存の勧告照合と設計者の「組み込まない」の判断を引き継いだ。

## 設計と実装

[設計と見込み](design.md)を着手後30分以内にまとめ、残り1.5〜3時間と見積もった。4時間を超えないため続行した。公開の AGENTS.md に従って Rust と Python を別担当へ配り、契約の照合と[担当間のレビュー](review.md)を行った。

宣言情報の版は **4**、意味ハッシュの版は **4** とした。型の application と効果の原子へ `ix` を加え、既存の交換の表現で `{"fixed":"top"}`・閉じた範囲の `{"fixed":範囲}`・`{"rvar":番号}` を区別する。署名は `rkinds`・`admission`・`shape` に、変数の種類、拡大の被覆条件、IOの対象の形を保持する。型の一覧の `rangeKind` と照合し、変数番号と種類、閉じた範囲、被覆と対象の位置の参照を検査する。IP の全幅は最終 JSON で整数として保持する。

Rust は収集済みの標準署名の登録を読み、Scheme とともに検査して出力する。通常の関数を除いたり、添字を Top に置き換えたりしない。effect operation は従来から `functions` の対象外であり、今回も一覧の意味を広げていない。Python は全欄を検証し、意味型・意味効果・意味署名から宣言、依存レコード、カスタム関数、選択した Trait 実装の各ハッシュへ反映する。位置、元の注釈、表示文字列は意味のハッシュから除く。

非Topの診断用の型表示は交換のJSONを使い、新しい正規の表示を作っていない。範囲変数を持つカスタム関数は、選ばれた関数名と `range-polymorphic signatures are unsupported` を含む理由で拒否する。生成器の対応型を広げず、非Topの未対応の生成注釈も理由付きで拒否する。

## 互換と確認済み manifest

設定は版1、manifest・receipt・生成記録の外枠は版3を保つ。manifest と生成記録は `inventoryVersion: 4`・`hashVersion: 4` とする。生成本文とテンプレートの規則を変えないため、`GENERATOR_VERSION` は `3.1.0-syntax-batch5` のままである。receipt は正確な manifest のハッシュと `recordSha256` に結び付ける。

旧 manifest の保存済みバイト列と SHA-256 は変えない。ただし新版の apply は旧 inventory/hash 版を `derive.incompatible_manifest` で拒否する。新しい preview は入力と道具・バイナリのハッシュと意味構造を含むため、新しい確認済みのハッシュが必要である。旧記録の check は `derive.migration_required` を返し、新 preview は旧本文を旧 `outputSha256` で認証して、旧記録と `semanticHashesComparable: false` を移行欄へ残す。

同梱例は source diff が空であることと両領域の本文のハッシュが変わらないことを確認し、確認した manifest の SHA-256 `cd48e8313244510c654f0a86cb7b63f2ed078557b6de48a30c15678ed6e080e5` を指定して適用した。意味ハッシュと生成記録だけが変わった。[移行の照合](example-migration-review.json)に旧版・新版と本文のハッシュを残した。例のソース自体は変更せず、File・Scope・Http の import は自己検査の一時コピーへ加えた。

## 作成時の関門と検査の境界

公開の `test-audit` の作成時の関門に従った。Rust の宣言情報の境界では、従来の二つの検査の版と添字の期待値を追随させ、標準署名の範囲関係と利用者の設定キーの保持を守る二つの検査を加えた。後者は今回の出力器の実装中に見つけた失敗を修正前に再現した。Python では実 reader を消費する境界に一つの範囲検証の検査を加え、既存の移行検査を表にして今回と同じ旧版を加えた。実装内の差し込み口、テスト用だけの公開範囲、無視する対象は増やしていない。テスト契約の削除はない。

Rust の独立期待値は Scope と Http の検査・射影・拡大の実署名、範囲変数の番号と種類、coversの向き、Top、閉じたパスとIPv6の端点を含む。Python は閉じた範囲と効果の独立期待値、宣言・署名・効果のハッシュの変化、不正な添字と範囲、IPv6の整数、非ASCIIの効果添字の順、カスタム関数の明示拒否、旧承認と本文の保護を検査する。Rust の出力だけでは、このPythonの消費・生成管理の失敗を検出できないため、境界を分けている。

## 初回の失敗と修正

1. 引き継いだ二つの宣言情報の失敗は、[R30.2cのログ](../r30.2c/work-recheck.log)に残る。期待値を緩めず、出力器と消費側へ範囲の情報を加えて解決した。
2. `bits`・`family` など利用者の合法なJSONキーをIPの材料と誤認して整数化する問題を、[修正前の検査](serializer-before.log)で再現した（終了101）。出力器に範囲と利用者データの文脈を設け、設定とmetadataを変換から除外した。修正後は同じ検査が成功した。
3. inventory/hashだけを更新し生成器版を保つ移行では、previewの `migration` がnullになっていた。[初回previewの確認](migration-before.json)を残した。移行条件へ両版を加え、旧記録と比較不能の印を保持した。対応するPythonの旧版記録の検査は修正前に失敗し、修正後に成功した。
4. 範囲の追加検査に、同じnominal型の異なる範囲を二つのFailure型にする不適切な入力を入れ、E0514で失敗した（[ログ](declarations-final.log)）。この言語規則を変えず入力を除いた。続いてIPの1と10の整列の期待を誤って逆転させたため失敗した（[ログ](declarations-recheck.log)）。最終JSONではbitsの後にfamilyに先立つカンマがあり、正順は1→10である。期待を訂正した。この二数について旧整列処理の退行は再現しておらず、最終JSONで整列する処理は契約を明示する整備として残した。
5. derive全自己検査の初回は49件成功・1件エラー、終了1だった（[ログ](derive-selftest.log)）。例の生成記録を移行する前に実行したため、その一件が `derive.migration_required` になった。記録を認証して移行し、全50件の成功を確認した。clippyの修正後に読取器を再ビルドし、最終バイナリでも全50件を再確認した。
6. W-R初回はclippyのenumの未列挙分岐二箇所で終了1だった（[ログ](work.log)）。分岐を列挙し、型の範囲の種類を既存の分岐で一緒に求めるよう修正した。
7. W-Rの二回目はlib全件と宣言情報を含む統合ターゲットを通過し、goldenで終了1となった（[ログ](work-recheck.log)）。R30.2cでTraitへimportと空行を加えたため、既存のE0701のsecondary位置が2行・35バイト動いていた。原文のShowの位置305〜309バイト、13行14〜18列を独立に確かめ、期待値だけを最小更新した。診断コード・文言・primaryは保ち、[単独フィルタ](golden-position.log)で成功を確認した。最終のW-Rは同じ指定で再実行した。
8. 停止記録を更新するPythonのhere-documentは文字コードのSyntaxErrorで終了した。ファイルの書き込み前の失敗であり、apply_patchで同じ更新を行った。

## 申し送りと片付け

BNTの公開名、Showの出力、型とエフェクトの意味、Leanの定義・主定理・Assumptionsは変えていない。追加の範囲外編集も不要であり、4時間の見込みを含む停止条件には該当しない。R30.2cの依存の反転と既存の表示・計時の記録を採る。取りまとめによる独立レビューと取り込み、取り込み後のshort、Rust/Leanの全比較、公開候補の照合は従来の担当と時期を維持する。

利用者は古い道具で未完の適用・復旧を終え、読取器をビルドし直して新しいpreviewを確認する必要がある。旧manifestのハッシュやreceiptを新版の承認に読み替えない。範囲の正規の表示は後続担当へ残し、この作業では交換表現を使う。

target外への一時ビルドと基準版の展開、新しい `CARGO_TARGET_DIR` は作っていない。自己検査の一時プロジェクトは各TemporaryDirectoryの終了時に削除された。通常のビルドと例の確認成果物はtarget内へ残した。[片付けの記録](cleanup.json)のとおり、外部の片付けは残っていない。

## 確かめとR30.2cの完了

| 契約・対象 | 結果 | 根拠 |
|---|---|---|
| 指定の既存宣言情報二件 | 成功。`inventory_json_preserves_resolved_types_order_spans_and_input_hashes` と `inventory_v2_preserves_kinds_anonymous_implementations_and_opaque_boundaries` | [局所5件](declarations-verified.log)、W-Rのdeclarations全件 |
| 範囲変数を持つ署名の独立期待値 | Scope・Httpの検査・射影・拡大、番号・種類・被覆の向きが一致 | [局所検査](declarations-verified.log) |
| Topと閉じた範囲、IPの整数精度 | パス・端点・IPv6の全幅を保持。範囲違いで意味のハッシュが変わる | 同上、[最終自己検査](derive-selftest-current.log) |
| File・Scope・Httpを加えた例のpreview/check | 一時コピーへ三つともimportを追加し、previewのdiffが空、derive checkと通常のcheck/testが成功 | `PropertyGeneration.test_json_and_property_two_modules_all_basic_types_and_containers`、[全50件](derive-selftest-current.log) |
| 範囲変数を持つカスタム関数の設定 | 指定したScopeの関数を理由付きで拒否し、入力を変えない | `Management.test_range_inventory_validation_hashing_and_custom_refusal`、同上 |
| 旧manifest・記録の移行と本文の保護 | 旧承認を拒否し、旧記録と比較不能の印を保持。変更済み本文を拒否 | `Management.test_older_inventory_record_requires_new_review_and_protects_old_body`、同上 |
| 同梱例の記録の移行 | source diffなし・本文ハッシュ不変で移行、最終バイナリのcheckが成功 | [照合](example-migration-review.json)、[最終check](example-current-check.log) |
| 作業末W-R | 終了0。lib全件と42統合ターゲットで1,857件成功・失敗0件・32件無視 | [全ログ](work-final.log)、[対象別集計](test-counts.json) |
| R30.2cで未到達の36統合ターゲット | 全て実行済み。未到達は0件 | [旧一覧との照合](test-counts.json) |
| fmt・clippy・ソース規約・Skill生成物・仕様集計 | 全て成功。生成物に追加差分なし | W-Rの各区間 |
| Python道具 | 構文検査、source-migrate 6件、try-actions-migrate 10件が成功。derive全50件も別途成功 | W-Rと[自己検査](derive-selftest-current.log) |

最終のlibは1,392件成功・22件無視、統合ターゲットは465件成功・10件無視だった。検査の対象と既存のignoreは変えていない。最終W-Rのdry-runは、`fmt`・`lint_default`・`lib_default`・`tests_related`・`source_rules`・`skill_generated`・`spec_tally`・`python_syntax`・`migrate_selftests`を選んだ（[選択と理由](work-final-dry.log)）。derive自身の自己検査は選ばれないため、READMEの `python3 -B tools/derive/test_derive.py` を別に実行した。

最終W-Rは `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab` である。[記録器](run-record.py)が `/usr/bin/time -p` の内側で対象を起動し、check.shの戻り値を直接保存した。終了0、子の時間467.731秒、外側467.756秒であり、外側のreal/user/sysは467.75/1472.88/29.15秒だった（[計時](work-final.json)・[timeの出力](work-final-time.log)）。`time -l`は使っていない。

最大常駐量の補助値は `getrusage(RUSAGE_CHILDREN).ru_maxrss` の原値1,423,327,232バイト、1,357.390625 MiB（約1.326 GiB）だった。子孫の最大値であり、並行プロセス全体の常駐量の合計ではない。ログとコマンドの手元の絶対パスは、保存前に `<wt>`・`<home>` へ伏せた。

途中の失敗を直したため、今回のW-Rの本検査は計3回である。初回はclippyで終了1・外側3.810秒、二回目はgoldenで終了1・299.032秒、最終は終了0・467.756秒だった。失敗ログを残し、最終の成功へ合算していない。途中の直接のlib全件の再実行、追加のignore、検査範囲の縮小は行っていない。

## コマンド・終了・計時の一覧

以下は根から実行した対象コマンドである。全ての行にcheck自身の終了、外側の秒、最大常駐量のMiBを示す。各計時JSONには実行日時、子の時間、外側の起動形式、最大常駐量の原値と単位も残す。各 `*-time.log` は同じラベルの `/usr/bin/time -p` の出力である。

| 記録 | 対象コマンド | 終了 | 外側の秒 | 最大常駐量 MiB | 計時 |
|---|---|---:|---:|---:|---|
| [declarations](declarations.log) | `cargo test -p benitoite --test declarations inventory_ -- --nocapture` | 0 | 2.898 | 585.953 | [JSON](declarations.json) |
| [build-readers](build-readers.log) | `cargo build -p benitoite --example derive_inventory --bin benitoite` | 0 | 0.849 | 510.531 | [JSON](build-readers.json) |
| [example-old-record](example-old-record.log) | `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | 1 | 0.068 | 21.359 | [JSON](example-old-record.json) |
| [python-focused](python-focused.log) | `python3 -B tools/derive/test_derive.py Management.test_v4_reader_and_semantic_hash_contract Management.test_range_inventory_validation_hashing_and_custom_refusal FileEffects.test_inventory_file_uses_and_original_byte_boundary` | 0 | 2.436 | 190.719 | [JSON](python-focused.json) |
| [example-preview](example-preview.log) | `python3 -B tools/derive/derive.py preview --root tools/derive/examples --config tools/derive/examples/derive.json --out target/r30.2d/example-review` | 0 | 1.188 | 173.891 | [JSON](example-preview.json) |
| [serializer-before](serializer-before.log) | `cargo test -p benitoite --test declarations inventory_json_keeps_user_key_mappings_as_strings -- --exact --nocapture` | 101 | 1.689 | 586.828 | [JSON](serializer-before.json) |
| [declarations-final](declarations-final.log) | `cargo test -p benitoite --test declarations inventory_ -- --nocapture` | 101 | 2.008 | 587.203 | [JSON](declarations-final.json) |
| [build-readers-final](build-readers-final.log) | `cargo build -p benitoite --example derive_inventory --bin benitoite` | 0 | 0.749 | 509.344 | [JSON](build-readers-final.json) |
| [example-preview-final](example-preview-final.log) | `python3 -B tools/derive/derive.py preview --root tools/derive/examples --config tools/derive/examples/derive.json --out target/r30.2d/example-review-final` | 0 | 0.444 | 174.547 | [JSON](example-preview-final.json) |
| [declarations-recheck](declarations-recheck.log) | `cargo test -p benitoite --test declarations inventory_ -- --nocapture` | 101 | 1.770 | 586.234 | [JSON](declarations-recheck.json) |
| [derive-selftest](derive-selftest.log) | `python3 -B tools/derive/test_derive.py` | 1 | 87.508 | 199.031 | [JSON](derive-selftest.json) |
| [example-apply](example-apply.log) | `python3 -B tools/derive/derive.py apply --root tools/derive/examples --config tools/derive/examples/derive.json --manifest target/r30.2d/example-review-final/manifest.json --manifest-sha256 cd48e8313244510c654f0a86cb7b63f2ed078557b6de48a30c15678ed6e080e5` | 0 | 0.656 | 179.953 | [JSON](example-apply.json) |
| [work-dry](work-dry.log) | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run` | 0 | 0.133 | 11.328 | [JSON](work-dry.json) |
| [example-check](example-check.log) | `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | 0 | 0.379 | 174.312 | [JSON](example-check.json) |
| [declarations-verified](declarations-verified.log) | `cargo test -p benitoite --test declarations inventory_ -- --nocapture` | 0 | 1.784 | 585.875 | [JSON](declarations-verified.json) |
| [work](work.log) | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab` | 1 | 3.810 | 262.312 | [JSON](work.json) |
| [derive-selftest-verified](derive-selftest-verified.log) | `python3 -B tools/derive/test_derive.py` | 0 | 88.516 | 198.000 | [JSON](derive-selftest-verified.json) |
| [work-recheck-dry](work-recheck-dry.log) | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run` | 0 | 0.135 | 11.281 | [JSON](work-recheck-dry.json) |
| [build-reader-current](build-reader-current.log) | `cargo build -p benitoite --example derive_inventory` | 0 | 0.644 | 510.625 | [JSON](build-reader-current.json) |
| [example-current-check](example-current-check.log) | `python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json` | 0 | 0.428 | 174.328 | [JSON](example-current-check.json) |
| [work-recheck](work-recheck.log) | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab` | 1 | 299.032 | 1223.984 | [JSON](work-recheck.json) |
| [derive-selftest-current](derive-selftest-current.log) | `python3 -B tools/derive/test_derive.py` | 0 | 147.002 | 199.641 | [JSON](derive-selftest-current.json) |
| [golden-position](golden-position.log) | `env BENITOITE_GOLDEN_FILTER=todo178-orphan-standard cargo test -p benitoite --test golden golden_suite -- --exact --nocapture` | 0 | 0.599 | 74.641 | [JSON](golden-position.json) |
| [work-final-dry](work-final-dry.log) | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run` | 0 | 0.145 | 11.234 | [JSON](work-final-dry.json) |
| [work-final](work-final.log) | `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab` | 0 | 467.756 | 1357.391 | [JSON](work-final.json) |

## R30.2e: RV-R30.2d への対応

2026-10-29。[独立レビュー](../reviews/RV-R30.2d.md)の中1・軽2・軽4・軽5・軽6に対応した。B_WORK は引き続き `42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab` である。今回の編集は、[R30.2cの結果](../r30.2c/results.md)、[deriveのREADME](../../../../tools/derive/README.md)、03-06、本節の文書4件に限る。Rust・Python・標準ソース・テスト・生成物は変更していない。

| 指摘 | 対応 |
|---|---|
| 中1 | R30.2cの「import だけの check の費用」に、標準ソースへの `git grep -n '^import Benitoite.Trait'` の全5件（Json・Json.Codec・Csv・Range・NonEmptyList）を表で加えた。レビューアのJson +1.39 ms・Csv +1.42 msと、残る3件の未測定を区別した。これらの利用者も新たにScopeを読むことと、設計者が影響範囲を知って採った日（2026-10-29）を記した。新しい測定は行っていない |
| 軽2 | R30.2cの互換性の節に、`Trait.limited` がE0303「no member」からE0330「not public」へ変わり `<benitoite>/Trait.bnt:99` を指すこと、`Scope.limited` は「no member」となることを追記した。公開の契約は変わらない |
| 軽4 | READMEに同期箇所を明記する案を採った。Pythonの `validate_inventory` 内の `effect_kind` がRustの `BuiltinEffectId::scope_kind` の写しであること、両ソースへのリンク、現在の対応表、組み込みのエフェクトを追加・変更するときの同期の必要を記した。原子のJSON構造は変えていない |
| 軽5 | READMEに現在の出力の範囲を明記する案を採った。効果の操作は宣言一覧の外にあり、`shape` は現在 `untargeted` だけを出力し、`single`・`topTargeted` は出力に現れないと記した。テストは追加していない |
| 軽6 | 03-06の「範囲パラメータ」を用語集の「範囲変数」にそろえた。追跡済みのファイルを `private/`・`docs/todo/`・スキルのディレクトリ・過去の保管文書を除いて検索し、現行設計書の該当はこの1件だけと確認した。ほかの6件は今回の編集範囲外の検討資料（`study/user-effect-scopes.md` の5件、`ub10/results.md` の1件）で、将来の宣言構文案のため変更していない |

指定の `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --dry-run` は終了0だった（[選択のログ](r30.2e-dry.log)・[終了と計時](r30.2e-dry.json)）。既存差分を含めて `fmt`・`lint_default`・`lib_default`・`tests_related`・`source_rules`・`skill_generated`・`spec_tally`・`python_syntax`・`migrate_selftests` が選ばれた。今回変えたREADMEにより選ばれたのは後二つである。文書だけの作業にRust全libを追加しない規約に従い、`--only python_syntax,migrate_selftests` でこの二つだけを実行した。これは文書変更の部分選択であり、W-R全体の再実行とは呼ばない。R30.2dのW-Rの結果は上に残す。

| 検査 | check.sh自身の終了 | 外側の秒 | 結果・記録 |
|---|---:|---:|---|
| 指定のdry-run | 0 | 0.140 | [選択と理由](r30.2e-dry.log)、[計時](r30.2e-dry.json) |
| `scripts/check.sh --level work --base 42d22f72f0e1719f39d26abb9fa75c95d1b1f2ab --only python_syntax,migrate_selftests` | 0 | 4.499 | Python構文検査、source-migrate 6件、try-actions-migrate 10件が成功。[ログ](r30.2e-doc-check.log)、[計時](r30.2e-doc-check.json)、[time出力](r30.2e-doc-check-time.log) |

既存の `run-record.py` を使い、対象を `/usr/bin/time -p` の内側で起動してcheck.sh自身の戻り値を直接保存した。検査は一度で成功した。子の時間は4.476秒、外側のreal/user/sysは4.49/2.72/0.55秒だった。最大常駐量の補助値は `getrusage(RUSAGE_CHILDREN).ru_maxrss` の78,036,992バイト、74.421875 MiBであり、子孫の最大値であって並行プロセスの合計ではない。手元の絶対パスは保存前に伏せた。文書のリンク・空白と変更範囲も確認した。

`private/`・そこを指すスキルのリンク・`docs/todo/` は読んでいない。レビュー記録と `rv-probes/` は変更せず、gitの状態を変える操作、`lake build`・`check-formal.sh`・shortは行っていない。target外への一時ビルドや展開、新しい `CARGO_TARGET_DIR` は作っていない。軽3の後の課題への転記は取りまとめの担当のままとする。

開始時に取得した既存ファイルのSHA-256と終了時の値を照合し、上の文書4件以外の既存差分・ログ・レビュー記録・再現入力が不変であることを確認した。[今回だけの差分](r30.2e-changes.patch)と[変更範囲の照合](r30.2e-verification.json)を残した。

2026-10-29 06:53:07 UTCに時計を取得して開始し、文書と検査結果の確認を含め外側は概算6分、能動時間も概算6分だった。検査の待ちは上の4.499秒である。見込みの20〜40分と停止条件の1時間半を超えていない。

## 差分と時間

[行数の記録](diff-counts.json)はB_WORKからの差分であり、引き継いだR30.2cも含む。今回のRust出力器は234行追加・32行削除（新モジュール164行を含む）、Python本番は141行追加・24行削除である。今回のRustの宣言情報テストは125行追加・5行削除、Pythonテストは141行追加・33行削除、goldenの位置は1行追加・1行削除であり、テスト契約の削除はない。処理系本体のRustの振る舞いは変えていない。

最初に取得した時計は2026-10-29 06:08:24 UTC（15:08:24 JST）であり、その前にREADMEと依頼条件の読み込みを始めていた。最終W-Rは06:35:20 UTCに終わった。記録の最終確認を含めた外側は着手から概算35分、能動時間は概算25分である。読書開始時の厳密な時計と能動時間の分離計時は取っていない。Rust・Python・レビューの担当は並行していたため、その時間を親の外側へ加算しない。主要な待ち時間はW-Rの二回目299.032秒、最終467.756秒、最終バイナリのderive自己検査147.002秒であり、文書作成や他の検査との重なりがある。見込みの上端と4時間の停止条件は超えていない。
