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
- ADR: [0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)、[0012](../../design/decisions/0012-invalid-utf8-input.md)、[0322](../../design/decisions/0322-stdlib-details-from-u3-preflight.md)（決定 1）、[0328](../../design/decisions/0328-path-and-json-details-from-u3-preflight.md)（決定 3）

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Json.bnt`、「構成子のタグ」の `JSON_VALUE_*`、「レコードの値の作り方」
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `serde_json`
- [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の `runtime::map`（`map_from_sorted` など）、`runtime::list`

## 作るもの

- `src/builtins/funcs/json.rs` の 3 項目の本体と単体テスト。`serde_json` を依存に加える（10-16 の表の指定。機能 `arbitrary_precision` を有効にする）
- ソースの関数を確かめるスクリプトのテスト

## 手順の要点

- 解析: `serde_json::from_str::<serde_json::Value>` で読み、言語の値に変える。入れ子の深い入力でも Rust の再帰を深くしないように、`serde_json::Value` から言語の値への変換は明示の積み重ね（`Vec`）で書く（00-02「再帰の深さ」）。`serde_json` 1.0.151 の解析は、既定で入れ子の深さを 128 に抑える（2026-09-30 に配布物の `src/de.rs` の `remaining_depth: 128` で確かめた）。この上限を超えた入力は解析の誤りになることを、受け入れテストで確かめる（深さの上限 128 は 03-08 が定めていないクレートの値なので、テストで固定する）。`Json.ParseError` の `message` にはクレートの理由を入れる。`serde_json::Error` の `Display` は理由の後に ` at line X column Y` を付けるので、この部分を除いた文を `message` にする（行と列は `line`・`column` の欄で返す）。上限を外す機能（`unbounded_depth`）は使わない。
- 数の分け方（03-08、ADR 0322 の決定 1）: `serde_json` の機能 `arbitrary_precision` を有効にし、`serde_json::Number::as_str` で数の元の字面を読んで決める。字面が小数点と指数（`.`・`e`・`E`）を持たず `i64` に収まれば `Json.Value.Integer`、それ以外は字面を `f64` として読んだ `Json.Value.Float` とする。`i64` の範囲を超える整数も `Float` になる。`-0` は `Json.Value.Integer(0)`、`-0.0` は `Json.Value.Float(-0.0)` である（機能を入れない `serde_json` は `-0` を −0.0 の浮動小数点として読み、`-0.0` と見分けられない）。`arbitrary_precision` は字面を正規化することがある（配布物の `src/de.rs` の `parse_any_number`・`scan_exponent` で確かめた。小数点も指数もない整数で、正なら `u64`、負なら `i64` に収まるものは数に読み直してから字面に戻すので、`-0` は `0` になる。指数の `E` は `e` になる。指数の符号は書かれたときだけ残る）ので、判定は小数点と指数の有無と `i64` への読み込みだけで行い、字面の細かい形に頼らない。
- `Float` の範囲を超える数（`1e400` など）は解析の誤りとする（03-08）。`arbitrary_precision` では `serde_json` がこれを誤りにしない（字面を残すだけ）ので、本作業が見つける。`line`・`column` はその数の字面の先頭の位置にする。位置は、`serde_json::from_str` の解析に成功した後、範囲を超える `Float` があれば入力を字句として先頭から走査し直し（文字列の中の文字を数と取り違えないように、文字列とエスケープを読み飛ばす）、その数の字面の位置を求める形で求める。`serde::de::DeserializeSeed`・`Visitor` で読んで数の字面を受け取る形は使わない（`serde_json` 1.0.151 は `serde` でなく `serde_core` に依存し、`arbitrary_precision` では数が私的な鍵（`$serde_json::private::Number`）の付いた構造として届くため）。位置をテストで固定する。この誤りの `message` の文言は、`json` の子のモジュール `text` の定数に置く（00-02「文言」）。
- オブジェクト: `Map` で表し、同じ鍵が二つ以上あれば後のメンバの値を使う。`map_from_sorted` は組の数の上限を確かめないので、組の並びの長さを先に `CheckedLen::elements` で確かめてから渡す（配列から作るリストも同じく先に確かめる）。`serde_json::Value::Object` は、機能 `preserve_order` を入れなければ `BTreeMap` である（同じく `src/map.rs` で確かめた）。同じ鍵を後の値で置き換えることは、テストで確かめる。鍵の順序（文字列の `<`）でマップを作る。
- `line` と `column` は 1 から数え、`column` は行の中の文字位置に 1 を足した値である（03-08）。`serde_json::Error::column` は、1 から数えた行の中のバイトの列（誤りのバイトの、行の先頭からのバイト位置 + 1）を返し、改行の直後で入力が終わると 0 になる（`serde_json` 1.0.151 の `src/read.rs` の `position_of_index` と `peek_position`、`src/error.rs` の `column` の文書で確かめた）。serde の `column` を c として、入力の該当の行の先頭から c バイトの範囲に始まる文字の数を `column` とする（これ以上 1 を足さない）。c = 0 なら 1 とする。
- 文字列化: `serde_json::to_string`・`to_string_pretty` は値を Rust の再帰で辿るので使わず、言語の値を明示の積み重ね（`Vec`）で辿って自前で書く（00-02「再帰の深さ」）。メンバを鍵の順で書く（マップの順がそのまま鍵の順）。制御文字（U+0000〜U+001F）、`"`、`\` をエスケープし、ほかの文字はそのまま書く。DEL（U+007F）は 03-08 の「制御文字」に含めず、エスケープしない（`serde_json` の出力と同じ）。NaN と無限大の `Float` は `null` と書く。`stringifyPretty` は `serde_json` の `PrettyFormatter` と同じ形で書く（改行を入れ、入れ子ごとに 2 個の空白で字下げし、メンバは `"k": v` と書き、空の配列とオブジェクトは `[]`・`{}`）。有限の `Float` は、必ず小数点（`.`）か指数を含む形で書き（`1.0`、`-0.0`、`1e+300` など。`serde_json` 1.0.151 の出力と同じ形）、読み直すと同じ `Json.Value.Float` になるようにする（03-08、ADR 0328 の決定 3）。Rust の `f64` の `Display` は `1.0` を `1` と書くので、そのままでは使えない。`Float.toString` と一致させる必要はない。
- 結果の文字列の大きさを、確保の前に確かめる（`StrBuf`）。
- ソースの関数（`Json.get` など）は L00 が置いた。変えずに、スクリプトで確かめる。
- スクリプトのテストでは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Json`。[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-08 の例の `import Benitoite.Json` の形をそのまま写すと、E0321 になる。

## 受け入れテスト

- 項目ごとの単体テスト: 各種の値（`null`・真偽・整数・負の整数・`i64` の最大値と最大値 + 1（`Float`）・`i64` の最小値・`-0`（`Integer(0)`）・`-0.0`（`Float(-0.0)`。符号のビットまで確かめる）・`0.0` と `1E2`（`Float`）・小数・指数・文字列（エスケープ、Unicode のエスケープ `\u00e9` とサロゲートの組）・配列・オブジェクト・入れ子）の解析と文字列化の往復。前後の空白を許す。同じ鍵を二つ持つオブジェクトで後の値。深さの上限を超える入れ子で解析の誤り（境目は次の「深い値」の項目）。`Float` の範囲を超える数（`1e400`、`-1e400`）で解析の誤りとその位置。正しくない JSON（末尾のコンマ、閉じない文字列）で `Json.ParseError` の `line`・`column` が 03-08 の定義どおり（複数行、ASCII でない文字の後の誤り、改行の直後で入力が終わる場合（`"[1,\n"` など。serde の `column` が 0 になる）を含む）。
- 文字列化: `Float(1.0)` が `1.0`、`Float(-0.0)` が `-0.0`、`Float(100.0)`（`1E2` を読んだ値）が `.` か指数を含む形で、読み直すと `Float` のまま（`Integer` にならない）。メンバが鍵の順、NaN と無限大が `null`、`stringifyPretty` の字下げが 2 個の空白で `"k": v` の形、空の配列とオブジェクトが `[]`・`{}`、制御文字のエスケープ、DEL をエスケープしないこと。`ParseError` の `message` が ` at line` を含まない。
- 深い値: 深さ 1000 の配列を文字列化しても（`serde_json` の外で作った値なので深さの上限に当たらない）Rust の再帰でスタックを使い尽くさない。解析の深さの上限の境目を確かめる（`src/de.rs` の `check_recursion` は 128 から 1 ずつ減らして 0 で誤りにするので、配列を 127 段入れ子にした入力は受け付け、128 段で誤りになる見込みである。実際の境目をテストで固定し、完了の報告に書く）。
- スクリプト: `Json.get`・`at`・`asFloat`（`Integer` を `Float` にする）などの値。03-08 の `totalAmount` の例と同じ形のスクリプトが期待どおりの値を返す。`Json.Value` の `=` が使える。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置、L00 が置いたソースを変えていない
- `serde_json` の版、`column` を文字位置に直した方法を完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。とくに、値の変換で Rust の再帰を使っていないか。
- `serde_json` の既定の振る舞い（深さの上限、数の分け方）に頼る箇所を、テストで確かめているか。`arbitrary_precision` の字面から数を分けているか（`as_i64`・`as_f64` の結果だけで分けると、`1.0` などを取り違えうる）。

## 難易度の理由

クレートが解析と文字列化の大部分を行うが、数の分け方、誤りの位置の数え方、出力の書き方を 03-08 の定めに合わせ、深い値の変換を再帰なしで書く必要がある。
