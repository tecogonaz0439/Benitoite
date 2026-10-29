# 宣言情報の JSON の未対応（解決済み）

## 解決

設計者は2026-10-29に範囲をJSONへ保持する案を採り、編集範囲に `tools/derive/` と出力器を加えた。R30.2dで宣言情報と意味ハッシュを版4へ上げ、型・効果の添字と署名の範囲変数・被覆条件・対象の形を保持した。旧manifestを拒否し、旧記録は本文を認証して新previewで移行する。範囲のTop化と通常関数の除外は行っていない。

指定の二つの宣言情報のテスト、標準署名の独立期待値、File・Scope・Httpのimportを加えた例のpreview/check、カスタム関数の範囲多相の明示拒否、deriveの全50件の自己検査は成功した。W-Rの最終結果と時間は[再開後の結果](../r30.2d/results.md)と[元作業の完了記録](results.md#再開後の完了検査)に集める。

以下は初回停止時の原因と判断の記録であり、未解決の作業の指示ではない。

## 初回停止時の再現と影響

`Show[Scope.ScopeError]` を Trait へ移し、Trait が Scope を import すると、従来 Trait だけを読んだ宣言収集でも Scope の三つの範囲付き標準署名を読む。通常の型検査・実行と表示の照合は成功したが、宣言情報を開発用 JSON へ変換する段階で失敗する。

W-R の二回目は lib 1,392件成功・22件無視の後、`declarations` の次の二つが失敗した。同ターゲットでは29件成功・2件失敗・1件無視である。

- `inventory_json_preserves_resolved_types_order_spans_and_input_hashes`（`crates/benitoite/tests/declarations.rs:332`）
- `inventory_v2_preserves_kinds_anonymous_implementations_and_opaque_boundaries`（同 `:536`）

どちらも `derive_inventory::inventory` が `invalid declaration inventory type, kind, or signature` を返す。[W-R のログ](work-recheck.log)を再現の記録とする。このテストの入力と期待値は変えていない。

## 失敗する接続

`crates/benitoite/examples/derive_inventory/mod.rs` の `inventory` は、宣言収集が読み込んだ全モジュールの通常関数を `functions` の表へ出力する。その `function` は合併済みの `decl_types` の Scheme を `signature` へ渡す。

`Scope.checkPathIn`・`pathInValue`・`widenPathIn` は、認定された標準署名として範囲変数を持つ。`crates/benitoite/examples/derive_inventory/schema.rs` の `Output::ty` は `Ty::Con` の添字が `RangeIndex::TOP` 以外ならエラーを返す（54〜55行）。現在の JSON の型は `tag`・`head`・`arguments` だけで、範囲の情報を表せない。

受け取り側の `tools/derive/derive.py` の `validate_inventory` 内の `ty` も、その三欄を厳密に要求する（400行）。`signature` も既存の七欄を要求し、範囲パラメータの欄を持たない（423行）。出力器だけに範囲の欄を追加しても、受け取り側が拒否する。

## 初回の範囲で行わなかった修正

範囲変数を保持して直すには、開発用 JSON の型と署名の形式、Rust の出力器、Python の検証・意味ハッシュ・型の表示と対応する検査をそろえる必要がある。`tools/derive/` は今回の編集許可の外にある。将来の範囲付きの型の直接の欄と、カスタムの関数として選ばれた標準関数も含めて、出力する意味を決める必要がある。

範囲変数を Top へ置き換えると、標準署名が持つ範囲の関係を宣言情報から失う。JSON に出さない関数を黙って増やすと、読み込んだ通常関数を列挙する既存の契約を変える。どちらも今回の回避策にはしなかった。公開型を別モジュールへ移す案も、型の同一性・公開名・別名・組み込みの認定への影響を再検討する必要があるため、適用していない。

このため、BNT の公開名・Show の出力・型とエフェクトの規則は変更せず、W-R が失敗した状態を残して実装を停止した。当時の差分を取り込み可能とはしなかった。続行の候補は、取りまとめが宣言情報の範囲対応をこの枝へ追加し、`tools/derive/` とその契約・検査まで編集範囲を広げることだった。停止時には未調査部分の所要時間は不明だった。

## 初回停止時に残した検査

| 手順 | 見込み |
|---|---:|
| JSON の形式・範囲対応の設計と編集範囲の判断 | 不明 |
| 出力器・受け取り側・意味ハッシュ等の実装と局所検査 | 不明 |
| 宣言情報の既存二入力と `tools/derive/` の自己検査 | 不明 |
| 変更で古くなる W-R の検査と、未到達の36統合ターゲット・生成物等の完了 | 5〜15分を目安に、変更後の dry-run で再見積もり |
| short の性能比較 | 取り込み後に取りまとめが実施。既存の目安は15分以内、ビルドは別 |
| 独立レビュー・受け入れ | 不明 |

上の未調査の見込みは停止時のものである。採用した設計と実施した検査は[範囲対応の設計と見込み](../r30.2d/design.md#見込みと検査の割り当て)と[結果](../r30.2d/results.md)を正とする。取りまとめの独立レビュー・受け入れ、short、Rust/Lean全比較の担当と時期は変えない。
