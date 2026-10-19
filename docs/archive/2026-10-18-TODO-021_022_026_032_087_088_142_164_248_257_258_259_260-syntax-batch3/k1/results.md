# K1の結果

## RV2 の直し

- 軽1: formal/README.mdへChecked・ResultLaws・Monad2Examples・構築器の各モジュール、test_batch3、既存30件と分けた公理の確認例を追加した。
- 軽2: 07-04の構築器の対応表を段階C・Eの拡張へ直し、任意のΓ・Δについて全体のCapturesを示す二定理を明記した。
- 軽3: builders_ordinary_resultのdocstring・01-12・07-04・formal/README.mdに、既存のcleanによる型の範囲条件の再確認であり、セルの逸出の禁止ではないと明記した。名前と言明は変えていない。
- 軽4: 01-12・07-04に、標準関数そのものの同定はLeanの保証外であり、Rustの解決済み束縛と交換の照合で確かめると明記した。
- 軽5: B3の完了条件に、test_batch3の独立入力と--rust-dirの両経路をcheck-formal.shから呼び、manifestの期待件数を照合すると追記した。
- 軽6: K1のopaqueと実装済みT1〜T3を07-04の対応表へ追加した。定数検査・inventory/derive・Property・doctestは各接続作業をplan.mdに明記した。
- 元のRV2はwork/m009/RV2.mdからreviews/RV2.mdへ無変更で保存した。

## 基準と実装

B_WORK: `c4310604f3982f7daab323920615945c2ba3ffef`。コミットとdocs/todo/の変更は行っていない。

@opaqueの属性条件、使用位置と宣言元によるE0340、opaque型内部の公開契約の免除、宣言収集の印と所有元、Skillの属性表示を実装した。通常の型・VM値・全構成子/欄・網羅性の表を保つ。仕様・英語リファレンスと生成Skillも同じ変更で更新した。

## テスト作成時の関門

属性の適用条件はparserの公開出力、全使用入口の拒否と診断はresolverの公開出力を持ち主とする。既存テストは型名の公開と内部表現を分離しない。decl収集は本体を辿らない独立の生成道具向け契約として、印・所有元・非公開補助型・完全な表を確かめる。型検査の境界では、equalityの内部構造とガード付きワイルドカードによる非網羅の拒否を確かめる。CLIのgoldenは公開API/implementの実行結果とE0340の位置・補助位置・help、fmt_commandはdocと属性・公開修飾の保存と再整形を守る。テスト専用の本番APIは増やさない。

既存のassert削除・期待の緩和・ignore追加はない。既存goldenのc11-attribute-unknown.diag.jsonは、未知属性のhelpに新しい有効属性@opaqueを列挙するため、期待する一覧へ同じ属性を追加した。拒否のE0801・位置・他の期待は保つ。新テストの準備中に、重複import・構文上許されない空match・goldenのディレクトリ配置・明示importと関数名・Showの明示呼び出しの誤りを検出し、入力を修正した。空の型としての誤受理は、構文検査を通るガード付きワイルドカードで検査する。

## 検査

作業中はparserの対象群・opaqueのresolver/宣言/整形・追加したgoldenだけを実行した。終了時の検査と時間は下の表に記録した。初回workはfmt成功後のlintでwildcard_enum_match_armにより停止した。BindingKindの対象外を全列挙へ直し、変更で古くなったfmt・lintと、その先の未実施の検査を実行した。

## 計画からのずれと申し送り

R159を参照。型別名の構築機能は追加せず既存拒否を保つ。RV2の修正を合わせて実施した。Scope/Rangeの具体APIとその例はK3/K4、inventory版2のJSON境界はG1、標準関数同定とtest_batch3の全経路の接続はB3が担当する。

## 終了時の結果

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---|
| `scripts/check.sh --level work --base c4310604f3982f7daab323920615945c2ba3ffef --test '*' --dry-run` | 0。fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・formal_buildを選択 | 初回0.083秒、修正後は未計時 |
| 同じ指定のwork（初回） | 1。fmt成功後、lintのwildcard_enum_match_armで停止。後続は未実施 | 7.588秒 |
| 同じ指定のwork（修正後） | 0。lib 1,211件成功、既存のignore 21件。全統合ターゲット・source_rules・生成物照合・仕様集計・既定のlake buildとsorry検査が成功 | 388.183秒 |
| `cargo clippy --all-targets` | 0。R156の補完も成功 | 10.718秒 |
| `lake env lean /tmp/k1-batch3-axioms.lean`（formal/で実行、READMEの追加ブロックを無変更で抽出） | 0。10件とも標準公理だけ、sorryAxなし | 0.701秒 |

全統合テストは38ターゲット、成功271件、失敗0件、既存のignore 7件であった。spec_examples・reference_examples・skill_docsを含むため、同じ対象を別途繰り返していない。formal_buildが既定のlake buildを実行したため、直接のビルドを重ねていない。

途中の局所検査は `cargo test -p benitoite --lib syntax::parser::items -- --nocapture`（12件成功）、`cargo test -p benitoite --lib opaque_representation -- --nocapture`（1件成功）、`cargo test -p benitoite --test declarations opaque -- --nocapture`（2件成功）、`cargo test -p benitoite --test fmt_command opaque -- --nocapture`（1件成功）、`BENITOITE_GOLDEN_FILTER=k1-opaque cargo test -p benitoite --test golden golden_suite -- --nocapture`（2ケース、VM/参照実行の一致1件）である。いずれも最終の修正済み入力で終了0。局所検査の外側の時間は未計時である。編集手順の `cargo run -p benitoite --example gen_skill` も終了0で生成し直した。未知属性の期待一覧と新しいE0340のgoldenは内容を読んで照合した。

Rustの本番コードは追加138行・削除8行、テストコードは追加224行・削除0行（同居ファイルは最初のcfg(test)以後をテストに分類、golden入力・期待・生成物は別）である。削除したテストはない。

ログはwork.log・work-first.log・work-dry-run.log・clippy-all-targets.log・axioms.logに置いた。RV2の写しはcmpで元ファイルと一致した。変更文書のMarkdownファイルへの相対リンク321件に不存在はなく、git diff --checkも成功した。
