# 0328. `Path.withExtension` の区切り、`Path.join` の空の `base`、`Json` の浮動小数点の書き方を決める

- 状態: 採択
- 日付: 2026-10-07
- 関連章: [テキストとデータの処理](../03-interop/03-08-text-and-data.md)
- 関連 ADR: [0137](0137-first-release-library-scope.md), [0138](0138-crates-and-licenses-for-stdlib.md), [0322](0322-stdlib-details-from-u3-preflight.md)

## 背景

2026-10-07 に、実装プランの L20（`Path`）と L21（`Json`）の作業文書の事前点検で、03-08 が定めていない点が三つ見つかった。どれも設計者が判断した。

1. `Path.withExtension(path, extension)` の `extension` が区切りの `/` を含むとき。Rust 1.98.1 の標準ライブラリの `PathBuf::with_extension`・`set_extension` は、拡張子に区切りが入ると panic する（標準ライブラリの `path.rs` の `validate_extension`。手元の配布物のソースで確かめた）。03-08 の表は、この場合の値を定めていなかった。
2. `Path.join(base, child)` で `base` が空のとき。03-08 の表は「`base` の後に区切りを挟んで `child` を続けたパス」と定めるので、字面どおりなら `Path.join("", "a")` は絶対パスの `"/a"` になる。一方、`Path.parent("a")` は `Option.Some("")` を返す（L20 の作業文書が Rust の `Path::parent` に合わせて定めた）。このままでは、`Path.join(parent, fileName)` で元のパスを組み立て直すと、相対パスが絶対パスに変わる。
3. `Json.stringify`・`Json.stringifyPretty` の有限の `Float` の書き方。03-08 は、小数点と指数を持たない数を `Json.Value.Integer` として読む（ADR 0322 の決定 1）。`Float` の `1.0` を最短の形の `1` と書くと、読み直したときに `Json.Value.Integer(1)` になり、往復で値が変わる。

## 決定

1. `Path.withExtension(path, extension)` の `extension` が区切り（Unix では `/`）を含むときは、引数の定義域の外（実行時エラー `ArgumentOutOfDomain`）とする。
2. `Path.join(base, child)` で `base` が空のときは、`child` をそのまま返す。`base` が区切りで終わるときは、区切りを重ねずに `child` を続ける。`child` が絶対パスなら `child` とする 03-08 の定めは変えない。`child` が空のときは、Rust の `Path::join` と同じく、`base` の後に区切りを付けたパスとする（`Path.join("a", "")` は `"a/"`。`base` が空か区切りで終わるときは `base` のまま）。
3. `Json.stringify`・`Json.stringifyPretty` は、有限の `Float` を、必ず小数点（`.`）か指数を含む形で書く（`1.0`、`-0.0`、`1e+300` など。serde_json 1.0.151 の出力と同じ形）。書いた文字列を `Json.parse` で読み直すと、同じ `Json.Value.Float` になる。これで、`Integer` と `Float` の区別が文字列化と解析の往復で保たれる。

## 検討した代替案

- 1 で、`extension` を文字列としてそのまま続ける案（`Path.withExtension("a", "b/c")` が `"a.b/c"` を返す）。結果はディレクトリ `a.b` の下のパスになり、意図しないパスを誤りなく黙って作る。ADR 0322 の決定 2（Csv の区切りを ASCII に限る）と同じく、扱えない引数は定義域の外として実行時に報告する方を採る。
- 2 で、字面どおり区切りを挟む案（`Path.join("", "a")` が `"/a"`）。`Path.parent("a")` が `Option.Some("")` を返すので、親とファイル名からパスを組み立て直すと、相対パスが絶対パスに変わる。Rust の `Path::join` も、空の `base` には区切りを足さない。
- 3 で、最短の形で書く案（`1.0` を `1` と書く）。読み直すと `Json.Value.Integer` になり、`Json.asInteger` などの結果が往復の前後で変わる。

## 帰結

- 03-08「Path」の表の `Path.join`・`Path.withExtension` の行と、「Json」の文字列化の箇条に決定 1〜3 を書く。
- 実装プランの L20・L21 の作業文書に反映する。`Path.withExtension` は、panic を避けるため Rust の `with_extension` を使わずに書く。凍結したコードとシグネチャは変えない。
