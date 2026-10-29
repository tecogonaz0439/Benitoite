# R10.5 のコード指摘と R10 の残りの修正

B_WORK は `3fc9b3f88c039e61bf797b1da574e5275028253d` である。`private/` と `docs/todo/` は読まず、git の状態を変える操作を行っていない。

| 指摘 | 修正 |
|---|---|
| RV-R10.5 軽3 | `typeck/text.rs` の `INVALID_RANGE_SIGNATURE`・`INVALID_RANGE_INSTANTIATION` を削除し、`decls.rs`・`context.rs` の終了状態3の呼び出し元へ同じ説明を戻した |
| RV-R10.5 軽4 | `BuiltinEffectId::{FILE_READ, FILE_WRITE, HTTP_CONNECT}` と `BuiltinTypeId::REGEX_PATTERN` を定めた。`scope_kind` の分類、`types/signature.rs` の既存テスト3件、`types/mod.rs` の既存表示テストの生の番号をこれらの定数へ置き換えた。表の並びと番号は変更していない |
| RV-R10.5 軽6 | `signature_valid` を `declaration_valid`（名前・型・効果と範囲変数の配置）、`admission_valid`（Covers の番号と種類）、`io_shape_valid`（操作と対象位置）へ分けた。`admission_valid` を `admits` でも使い、条件の重複を除いた |
| 同 軽6 の具体化 | `Body::instantiate` では範囲変数0個の署名をそのまま型／行の具体化へ渡す。`check_range_signatures` が宣言時に検査済みであり、不正な宣言は先行する `invalid` の検査で拒否される。現在の登録済み署名は全て0個なので、呼び出しごとの再検査と複写を省ける。範囲変数を持つ署名に対する公開 `instantiate`・`instantiate_top` の検査契約は保った |
| R10 の残りの点検 | `resolve/text.rs` の `SCOPE_INTERNAL` も終了状態3の説明だった。定数を削除し、`resolve/scope.rs` の `internal` 呼び出しへ同じ文字列を戻した |

署名の許容・被覆の向き・種類・IO の形の条件は変えていない。新しい API、依存、言語の値の保持やヒープの不変条件、Lean、scripts を変更していない。停止条件に該当する発見はない。

テストは既存の契約を保った定数への置換だけであり、追加・削除はない。作成時の関門は、(1) 署名の整形式・許容・具体化と効果表示を守る、(2) 種類や具体化の取り落としで失敗する、(3) 契約を既存テストが担うので重複したテストを足さない、(4) 本番の差し込み口を増やさない、とした。

`cargo test -p benitoite --lib types::signature::tests` は終了0、既存3件成功・失敗0・無視0である。ビルド16.41秒、テスト0.01秒を [局所ログ](signature-local.log) に記録した。この検査の後に行った変更は、`resolve` の説明文字列の移動と `context.rs` のコメントの追加だけであり、これらの最終検査は親の W-R に含める。全 lib、clippy、fmt の検査は重ねて実行していない。
