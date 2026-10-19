# G2: Show・Orderの生成

基準のコミット（B_WORK）は `1fa2953d897f7c4f47479f6cd0266b181c078d9d`。作業開始時の差分はない。コミットとdocs/todoの変更は行わない。

## 変更

- inventoryの設定へ独立したshow/orderの真偽値を加え、trueの場合だけTraitと依存ソースを読み込む。
- 解決済みの実装の頭・型引数・クラス制約を辿り、辞書の欠落と実装の重複を生成前に拒否する。認証済みの同じ対象・クラス・管理領域の実装だけを置換する。生成対象を依存順に並べ、選んだ辞書の意味情報を記録する。
- 欄順のShowと、最初の非Equalで終えるOrderを通常のimplementとして生成し、本番formatterへ渡す。不透明レコードの同モジュールでの明示要求を受理し、traitTargetに確認用のopaqueと選択を記録する。JSON/Propertyの無検査の構築の拒否を保つ。
- 設定例・道具とinventoryのREADME・03-06・07-04の内外の対応・英語リファレンス・手書きSkillを更新した。gen_skillを実行し、生成物に差分がないことを確認した。

## 検査

作業途中はTraitGenerationの新規ケースと、その修正対象だけを実行した。最初の実行は、テスト入力のAssertのimport/効果名・呼び出し、mainの不足、不透明宣言の可視性、再適用の戻り値の期待に誤りがあった。既存の入力と公開APIに合わせて新規のテスト入力だけを直した。既存assertは変更していない。

作業末は次を各一度実行した。時間は各プロセスの起動前から終了後までを外側で計った値であり、検査の合計は210.701秒である。rtk proxyを経由して実行した。

| コマンド | 終了 | 外側の時間 | 結果 |
|---|---|---|---|
| `scripts/check.sh --level work --base 1fa2953d897f7c4f47479f6cd0266b181c078d9d --test declarations --test golden --test reference_examples --test skill_examples --test skill_docs --dry-run` | 0 | 1秒未満 | fmt・lint_default・lib_default・tests_related・source_rules・skill_generated・spec_tally・python_syntax・migrate_selftestsを選択。追加の全件特殊構成・formalは選ばない |
| 上と同じ指定のwork（`--dry-run`なし） | 0 | 152.726秒 | lib 1211件成功（既存のignore 21件）、declarations 7件・golden 2件・reference_examples 1件・skill_docs 8件・skill_examples 3件成功。fmt・通常clippy・規約・生成物・仕様集計・Python構文・移行道具の自己検査も成功 |
| `cargo build -p benitoite --example derive_inventory --bin benitoite` | 0 | 1.007秒 | 読み取り用exampleと実CLIをビルド |
| `python3 -B tools/derive/test_derive.py` | 0 | 45.612秒 | 既存27件と新規6件の全33件成功。通常check/test、再生成照合、手書き保護、旧記録の移行要求・復旧も維持 |
| `cargo clippy --all-targets` | 0 | 11.356秒 | exampleを含む全ターゲットのlint成功 |

途中の `cargo build -p benitoite --example derive_inventory --bin benitoite` と、編集としての `cargo fmt`・`cargo run -p benitoite --example gen_skill` は終了0。新規テストの絞り込み実行は次のとおりであり、外側の時間は計っていない。

- `python3 -B tools/derive/test_derive.py TraitGeneration` は、入力の修正途中の2回は終了1、修正後の1回は終了0（5件成功）。
- `python3 -B tools/derive/test_derive.py TraitGeneration.test_review_apply_runtime_field_order_dependencies_opaque_and_replay TraitGeneration.test_handwritten_dictionary_for_data_and_generic_record_is_used` は、入力と再適用の期待の修正途中の2回が終了1。後続のTraitGeneration全件実行で両件の成功を確認した。
- `python3 -B tools/derive/test_derive.py TraitGeneration.test_another_authenticated_region_cannot_authorize_replacing_an_implementation TraitGeneration.test_review_apply_runtime_field_order_dependencies_opaque_and_replay` は終了0（2件成功）。

workのやり直しはない。検査後に変更したのは本結果の記録だけである。formal/を変えていないためlake buildを追加せず、change・release・全形式化比較・特殊構成は取りまとめへ残す。

## test-auditの作成時の四問

1. preview/apply/通常check/test/derive checkの実境界で、表示・比較の欄順と短絡、明示要求、辞書依存、領域外の手書き保護を守る。
2. 欄を逆順にする、非Equalの後も比較する、依存へ暗黙のクラスを追加する、別領域の記録で置換を許す、falseを生成要求とする退行で失敗する。短絡は、後の欄の比較を実行すると0除算になる手書き辞書を実VMへ渡して確かめる。
3. 既存のJSON/Propertyテストはimplementを生成せず、この辞書依存・重複・短絡を確かめない。独立指定と四機能の併用は表形式の一件にまとめ、拒否も一件の表にまとめた。
4. 本番API・フラグ・テスト専用の差し込み口は増やさず、一時プロジェクトと実reader/formatter/CLIを使う。別領域の保護は、本文のSHA-256が一致する旧管理領域の記録を入力にし、拒否後に全ファイルが不変であることを確かめる。

新規テスト6件。既存テストの削除・期待値の緩和・ignoreの追加はない。

本番コード（Rust exampleとderive.py）の差分は168行追加・14行削除、test_derive.pyは196行追加・削除なしである。

## 計画との差と申し送り

R173に判断を記録した。空レコードは現行仕様と既存assertを保ってE0201で拒否する。テンプレートの空の欄はEmpty()/Equalになるが、現行の実ソースの受け入れ成功とは数えない。組み込みの制約と本体の検査は通常check/testに委ね、Pythonに型構文・名前の解決器を作らない。

formal/・処理系本体・公開シグネチャ・GCは変更していない。G4へは、同梱People/Addressの旧本文・設定・記録の一度の移行とPropertyの新APIへの切り替えを残す。GENERATOR_VERSIONは計画の2.0.0-syntax-batch3、Show/Orderのテンプレート版は1である。日本語訳はV1へ残す。
