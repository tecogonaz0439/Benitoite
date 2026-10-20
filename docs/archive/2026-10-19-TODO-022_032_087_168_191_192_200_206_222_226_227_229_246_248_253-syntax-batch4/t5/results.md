# T5 宣言由来の診断・同名型・幅付き整数の警告

基準B_WORKは `cd850d5313e31c37b4c47f8defca28ba2a3f95c7`（開始時の `git merge-base HEAD san_benito`）である。開始時の差分はない。コミットとdocs/todoの変更は行っていない。

## 実装と判断

型変数間の辺を番号で共有し、元の型の形と理由、値側で確定した束縛、宣言へ移した不一致の値側の型を保持する。包んだ値・演算子・再束縛・Option/Listの部分パターン・tryの成功型もこの関係で判断する。移した報告の採否と根の無効化を分けた。値側の型でも失敗する要求は元の使用位置に残す。成功する単一化の順序と結果は変更しない。非公開の補助モジュールへの分割と表現の具体化はR167に記した。

診断内の型を先に集め、衝突する別宣言だけを共通の表で修飾する。根、入口、import別名、依存、関数とFailの内部に適用する。既存のTyNamesの欄とTy::showのシグネチャは保ち、修飾表を受け取る内部の描画を追加した。E1010の実装とpreludeの宣言の識別による案内は維持した。

整数モジュールの標準束縛・演算・幅の表を候補選択と評価で共用する。Integer64とUnsignedIntegerの転送関数は基本の関数とは別束縛なので明示的に含めた。型ごとの検査付き演算を使い、u64をi64へ狭めない。既存の定数式と予算の範囲を保ち、一般の利用者関数は評価しない。

02-05・02-10と07-04の対象外の行を更新した。Leanの定義は変更していない。R168に従い、作業末のlint_defaultを依頼のall-targetsのclippyへ置き換える。

## テストの関門

主な持ち主は公開の型検査である。三つの表形式のテストで、設計10節の再現全種と修正した対照、独立したBooleanの要求と本当のList[String]、宣言どうしの衝突を守る。既存の単純な変数の使用のテストでは、包んだ型・部分パターン・try成功型・幅別の標準関数と依存の同名型を通らない。非公開の関数を直接検査せず、テスト専用の本番の差し込み口も追加していない。

追加した宣言由来の診断と警告のテストは修正前に失敗した。同名型のテストも、本体の該当4ファイルを開始版へ一時的に戻して、expected Box, found Boxのために失敗することを確認し、必ず作業中の内容へ復元した。最初の試行は新しいtext関数だけを戻し忘れて未使用警告で停止したため証拠に数えず、4ファイルをそろえた試行だけを使う。

CLIでは描画と重大度・終了状態に固有の退行を捕まえるため、代表4件のJSONとテキストを追加した。新規の期待値を生成後、型の向き・一次/副位置・理由・幅と警告の位置・3件の警告とmoduloの警告なし・denyの終了2を読み合わせた。既存のprelude_shadowed_typeの二つの期待ファイルは、短名のResult同士の衝突をmain.ResultとBenitoite.Resultへ区別する変更だけを手で反映した。コード・位置・注記・help・終了状態は保ち、期待を緩めていない。既存assertの削除、ignoreへの変更、テストの削除はない。大きな入力は追加していない。

## 途中の検査

- `cargo test -p benitoite --lib diagnostics_batch4 -- --nocapture`: 最初は終了101。Listの偽のE0401と幅付き関数の警告不足を確認した。中間では演算子の集まりの偽のE0405、try成功型の解決前に出る偽の使用診断を修正した。外側の時間は初期の試行では未計測である。
- `cargo test -p benitoite --lib diagnostics_batch4::same_named_types_use_one_qualification_table -- --nocapture`（型表示と解決の4ファイルを開始版へ戻した対照）: 終了101、外側4.889秒。expected Box, found Boxを返す意図した失敗。
- `cargo test -p benitoite --lib typeck::tests -- --nocapture`: 中間は終了101。確定済みの変数の使用まで保留すると、先の引数の誤りから抑えるべきリストと非関数の呼び出しの診断が残った。確定済みの束縛を区別し、等しい型の部分への誤りの伝播も直した。最終の局所確認は44件成功、終了0、外側11.58秒。
- `cargo test -p benitoite --lib diagnostics_batch4 -- --nocapture`: 根・入口・依存と間接呼び出しの対照を含む3件成功、終了0、外側24.21秒（再ビルドを含む）。
- `BENITOITE_BLESS=1 BENITOITE_GOLDEN_FILTER=batch4- cargo test -p benitoite --test golden golden_suite -- --nocapture`: 新規4件の期待値を生成。終了0、外側19.73秒。整形4件、checkコア1件、stress除外0件。
- `BENITOITE_GOLDEN_FILTER=prelude_shadowed_type cargo test -p benitoite --test golden golden_suite -- --nocapture`: 終了101、外側0.27秒。同名型の修飾による二つのラベルの差だけを確認し、上記の意味で期待値を更新した。
- `cargo run -p benitoite --example gen_skill`: 終了0、外側5.32秒。再生成後の追跡ファイルに差分はない。

## 作業末の検査

次の同じ指定に `--dry-run` を付けた確認は終了0であり、6単位と四つの関連統合ターゲットだけが選ばれた。その後、次のworkを一度実行した。

```sh
scripts/check.sh --level work --base cd850d5313e31c37b4c47f8defca28ba2a3f95c7 --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test golden --test declarations --test checked_args --test test_command
```

終了0、外側139.83秒。fmt、lib 1228件成功・既存ignore 21件、checked_args 8件・declarations 7件・golden 2件・test_command 46件成功、規約、Skill再生成の一致、仕様集計の自己検査がすべて成功した。仕様集計の初回リリース完了条件の空欄は0である。未参照節の一覧は従来どおり表示される。

R168の `cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep` は最初に終了101、外側10.35秒。新しいprovenanceの単一の列挙型を扱うワイルドカード4箇所と、新規テストの同じ処理を持つ二分岐を指摘した。型の処理の全場合を明記し、Pattern/Tryの選択を既存と同じ条件のifにし、テストの二条件を論理和へまとめた。意味と期待値は変えていない。work全体は再起動せず、この修正後の関連3件・fmt・clippyだけを再確認した。規約の許可、生成元、仕様、goldenの入力と期待値はこの修正では変わらない。


再確認は全て終了0。`cargo test -p benitoite --lib diagnostics_batch4 -- --nocapture` は3件成功、外側21.61秒（clippyとのビルド待ちを含む）。同じall-targetsのclippyは外側11.43秒、`cargo fmt --check` は外側2.53秒で成功した。

本番のRustは +735 / −67行、テストとgoldenの入力・期待値・設定は +358 / −2行である。テストの削除はない。既存の2行の削除は同名型の描画期待値の置き換えに対応し、新しい内容で同じ2行を加えている。

## 申し送り

stage2、改造全体のchangeと形式化の全比較、公開候補のreleaseは取りまとめの割り当てに残す。V1の移行案内には、幅付き整数の標準関数でもW0401/W0402が増え、--deny-warningsで終了2となることを反映する。版とCHANGELOGは本作業では変更しない。
