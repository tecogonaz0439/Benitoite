# L25 `Encoding` と `Hash`

- 依存する作業: [L03](L03-bytes.md)
- 難易度: 1（1〜5。README の「作業一覧」）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/L25-encoding-and-hash

## 目的

Base64 の符号化と復号の `Benitoite.Encoding` の 4 の関数と、SHA-256 の `Benitoite.Hash` の 1 の関数の本体を、`base64` と `sha2` を使って書く。10-15 の部分 41（`encoding::DECLS`）と部分 42（`hash::DECLS`）である。

| 項目 | 権限 |
|---|---|
| `Encoding.base64Encode`・`base64Decode`・`base64UrlEncode`・`base64UrlDecode` | `Pure` |
| `Hash.sha256` | `Pure` |

依存の理由: 引数と結果が `Bytes` の値である（L03）。

## 読む設計書の節

- [テキストとデータの処理](../../design/03-interop/03-08-text-and-data.md)の「Encoding」「Hash」
- ADR: [0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)

インターフェース:

- [標準ライブラリの追加](../10-interfaces/10-15-stdlib-additions.md)の「テキストとデータ」の表と `Encoding.bnt`・`Hash.bnt`
- [IO とネットワークの追加](../10-interfaces/10-16-io-and-network-additions.md)の「使うクレート」の `base64`・`sha2`

## 作るもの

- `src/builtins/funcs/encoding.rs`・`hash.rs` の 5 項目の本体と単体テスト。`base64` と `sha2` を依存に加える（10-16 の表の指定）

## 手順の要点

- `base64Encode`: 標準の文字の表（RFC 4648 の 4 節）で `=` の詰め物を付ける（`base64::engine::general_purpose::STANDARD`）。
- `base64Decode`: 同じ表で、詰め物を必須とする。空白や改行を含むか、形が正しくなければ `Result.Error`。`STANDARD` の設定が詰め物を必須とし、空白を拒むことをテストで確かめる。
- `base64UrlEncode`・`base64UrlDecode`: URL とファイルの名前に使える表（RFC 4648 の 5 節）で、詰め物を付けない（`URL_SAFE_NO_PAD`）。復号で詰め物のある入力を受け付けるかは 03-08 が「詰め物のない Base64 を読んだ」とだけ定めるので、`URL_SAFE_NO_PAD` の振る舞い（詰め物を拒む）のままとし、完了の報告に書く。
- `sha256`: 32 バイトのハッシュ値の `Bytes`。
- 符号化の結果の長さと復号の結果の長さを、確保の前に確かめる。符号化（`base64Encode`・`base64UrlEncode`）は、結果の長さを `base64::encoded_len(入力の長さ, 詰め物の有無)` で求め（`None` は上限を超えたものとして扱う）、`CheckedLen::bytes` で `MAX_STRING_BYTES` と比べてから、`StrBuf` に書いて `alloc_str_buf` で文字列の値を作る（L03 の `Bytes.toHex` と同じ経路。U3 の `builtins/funcs/bytes.rs` の `to_hex` と `checked_encoded_len`）。復号の結果は入力より短いので、復号した `Vec<u8>` を `alloc_bytes` に渡すだけで足りる（`alloc_bytes` が長さを確かめる）。
- `base64Decode`・`base64UrlDecode` の `Result.Error` の理由の文は、`encoding` の子のモジュール `text` に英語の定数で置く（実装の規約の「文言」）。`base64::DecodeError` の種類ごとに文を分けなくてよい。
- スクリプトのテストを書くときは、非公式のモジュールを取り込みの名前で取り込む（`import Benitoite.Unofficial.Encoding`・`import Benitoite.Unofficial.Hash`。[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md) の決定 3）。03-08 の例の `import Benitoite.Hash` の形をそのまま写すと、E0321 になる。

## 受け入れテスト

- RFC 4648 の 10 節の試験の値（`""`・`"f"`・`"fo"`・`"foo"`・`"foob"`・`"fooba"`・`"foobar"`）の符号化と復号。URL 用の表で `+`・`/` の代わりに `-`・`_` になる入力。
- 復号の誤り: 詰め物のない標準の Base64、空白を含む入力、表にない文字、長さの誤り。
- SHA-256: 空のバイト列と `"abc"` の値が、FIPS 180-4 の例の値と一致する。例の値は、出典（NIST の文書の URL）をテストのコメントに書き、作業の中で確かめた値を使う。手元の `shasum -a 256` で空の入力と `abc` のハッシュ値を求めて確かめてよい（`printf '' | shasum -a 256`、`printf 'abc' | shasum -a 256`）。

## 完了条件

- `scripts/check.sh` が通る
- 受け入れテストのすべての場合を確かめるテストがある
- 10-15 の項目の名前・権限・引数の数と位置を変えていない
- `base64`・`sha2` の版と、URL 用の復号の詰め物の扱いを完了の報告に書いている

## 確認の観点

- [実装の確認の観点](../00-common/00-04-review-checklist.md)の「組み込みの関数」の行。
- 試験の値を、確かめないまま書いていないか。

## 難易度の理由

クレートの関数を呼ぶだけであり、判断はほとんどない。
