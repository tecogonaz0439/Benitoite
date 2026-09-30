# L21 `Json`

- 依存する作業: [L02](L02-map-and-set-functions.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。テストを含む）
- ブランチ: impl/L21-json

## 目的

JSON の値の型 `Json.Value` の解析と文字列化の 3 の組み込みの関数の本体を、`serde_json` を使って書く。10-15 の部分 37（`json::DECLS`）である。値を調べる 8 の関数（`Json.get`・`at`・`asString` など）は L00 が置いたソースの関数であり、本作業はスクリプトのテストで確かめる。

| 項目 | 権限 |
|---|---|
| `Json.parse`・`Json.stringify`・`Json.stringifyPretty` | `Pure` |
| `Json.get`・`at`・`asString`・`asInteger`・`asFloat`・`asBoolean`・`asArray`・`asObject`（ソース） | — |

依存の理由: `Json.Value.Object` は `Map[String, Json.Value]` であり、解析と文字列化で `runtime::map` を使う。`Map.get` などのソースの関数のテストに L02 の関数を使う。

## 読む設計書の節

- [テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)の「Json」（`Json.Value`・`Json.ParseError`、数の分け方、同じ鍵、等値の型、`line`・`column`、関数の表と箇条）、「共通の規則」
- [標準ライブラリ](../../design/03-interop/03-06-stdlib.md)の「作る値の大きさの上限」
- ADR: [0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)、[0012](../../design/decisions/0012-invalid-utf8-input.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Json.bnt`、「構成子のタグ」の `JSON_VALUE_*`、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `serde_json`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `runtime::map`（`map_from_sorted` など）、`runtime::list`

## 作るもの

- `src/builtins/funcs/json.rs` の 3 項目の本体と単体テスト。`serde_json` を依存に加える（10-16 の表の指定）
- ソースの関数を確かめるスクリプトのテスト

## 手順の要点

- 解析: `serde_json::from_str::<serde_json::Value>` で読み、言語の値に変える。入れ子の深い入力でも Rust の再帰を深くしないように、`serde_json::Value` から言語の値への変換は明示の積み重ね（`Vec`）で書く（00-02「再帰の深さ」）。`serde_json` 1.0.151 の解析は、既定で入れ子の深さを 128 に抑える（2026-09-30 に配布物の `src/de.rs` の `remaining_depth: 128` で確かめた）。この上限を超えた入力は解析の誤りになることを確かめ、`Json.ParseError` の `message` にクレートの理由を入れる。上限を外す機能（`unbounded_depth`）は使わない。
- 数の分け方（03-08）: 小数点と指数を持たず `i64` に収まる数は `Json.Value.Integer`、それ以外は `Json.Value.Float`。`serde_json` が `u64` で返す `i64` の範囲を超える整数は `Float` にする。`Float` の範囲を超える数は解析の誤り（`serde_json` が誤りにすることを確かめる）。
- オブジェクト: `Map` で表し、同じ鍵が二つ以上あれば後のメンバの値を使う。`serde_json::Value::Object` は、機能 `preserve_order` を入れなければ `BTreeMap` である（同じく `src/map.rs` で確かめた）。同じ鍵を後の値で置き換えることは、テストで確かめる。鍵の順序（文字列の `<`）でマップを作る。
- `line` と `column` は 1 から数え、`column` は行の中の文字位置に 1 を足した値である（03-08）。`serde_json::Error::column` は、文書では「1 から数えた列」とだけあり、文字位置かバイト位置かは【要検証】であり、クレートの文書とテストで確かめる。バイト位置なら、入力の該当の行から文字位置に直す。
- 文字列化: メンバを鍵の順で書く（マップの順がそのまま鍵の順）。制御文字、`"`、`\` をエスケープし、ほかの文字はそのまま書く。NaN と無限大の `Float` は `null` と書く。`stringifyPretty` は改行を入れ、入れ子ごとに 2 個の空白で字下げする。`serde_json::to_string`・`to_string_pretty` の出力がこの規則に合うかを確かめ、合わない点（`Float` の数の書き方など）は自前で書く。`Float` の書き方は `Float.toString` と一致させる必要はないが、読み直して同じ値になる形にする。
- 結果の文字列の大きさを、確保の前に確かめる（`StrBuf`）。
- ソースの関数（`Json.get` など）は L00 が置いた。変えずに、スクリプトで確かめる。

## 受け入れテスト

- 項目ごとの単体テスト: 各種の値（`null`・真偽・整数・負の整数・`i64` の最大値と最大値 + 1・小数・指数・文字列（エスケープ、Unicode のエスケープ `é` とサロゲートの組）・配列・オブジェクト・入れ子）の解析と文字列化の往復。前後の空白を許す。同じ鍵を二つ持つオブジェクトで後の値。深さ 128 を超える入れ子で解析の誤り。正しくない JSON（末尾のコンマ、閉じない文字列）で `Json.ParseError` の `line`・`column` が 03-08 の定義どおり（複数行、ASCII でない文字の後の誤りを含む）。
- 文字列化: メンバが鍵の順、NaN と無限大が `null`、`stringifyPretty` の字下げが 2 個の空白。
- 深い値: 深さ 1000 の配列を文字列化しても（`serde_json` の外で作った値なので深さの上限に当たらない）Rust の再帰でスタックを使い尽くさない。
- スクリプト: `Json.get`・`at`・`asFloat`（`Integer` を `Float` にする）などの値。03-08 の `totalAmount` の例と同じ形のスクリプトが期待どおりの値を返す。`Json.Value` の `=` が使える。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- `serde_json` の版、`column` の【要検証】の結果、自前で書いた部分を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、値の変換で Rust の再帰を使っていないか。
- `serde_json` の既定の振る舞い（深さの上限、数の分け方）に頼る箇所を、テストで確かめているか。

## 難易度の理由

クレートが解析と文字列化の大部分を行うが、数の分け方、誤りの位置の数え方、出力の書き方を 03-08 の定めに合わせ、深い値の変換を再帰なしで書く必要がある。
