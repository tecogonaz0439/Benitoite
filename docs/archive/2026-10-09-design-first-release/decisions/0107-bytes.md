# 0107. 変更できないバイト列の型 `Bytes` を設け、リテラルは設けない

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [標準ライブラリ](../03-interop/03-06-stdlib.md), [エフェクト](../01-spec/01-07-effects.md), [基本型の意味論](../01-spec/01-04-types-basic.md)
- 関連する未決事項: [OPEN-043](../open-issues.md#open-043)

## 背景

最小実行版は、ファイルを UTF-8 の文字列としてだけ読める（[ADR 0012](0012-invalid-utf8-input.md)）。画像などのバイナリのファイルと、UTF-8 以外の文字コードのテキストは扱えない。

バイト列の型は、言語によって変更できるもの（Kotlin の `ByteArray`、OCaml の `Bytes`）と、変更できないもの（Python の `bytes`、Haskell の `ByteString`、Elm の `Bytes`）がある。リテラルは Python と Rust が `b"…"` の形で持つ。これらの言語の扱いは、一次資料で確かめていない。

## 決定

1. prelude に、変更できないバイト列の型 `Bytes` を設ける。要素は `Byte` である（[ADR 0105](0105-byte-type.md)）。`Bytes` は等値の型である。
2. リテラルは設けない。次の関数で作る。`Bytes.fromList`（`List[Byte]` から）、`Bytes.fromIntegers`（`List[Integer]` から。範囲の外の値があれば `Option.None`）、`Bytes.fromHex`（16 進の文字列から）、`Bytes.fromBinary`（2 進の文字列から）、`String.toUTF8`。16 進と 2 進の文字列は、区切りとして `_` と空白を書ける。
3. 位置を指定する関数は、位置が正しくなければ `Option.None` を返す（[ADR 0006](0006-basic-types-semantics.md) の方針と同じ）。
4. 固定幅の数を読み書きする関数（`Bytes.readUnsigned`・`Bytes.readSigned`・`Bytes.fromUnsigned`・`Bytes.fromSigned`）を設ける。バイト数は 1〜8 とし、バイト順は prelude の型 `ByteOrder`（構成子は `BigEndian`・`LittleEndian`）で指定する。
5. 文字列との変換は UTF-8 に限る。`String.fromUTF8` は、正しくない UTF-8 なら `Option.None` を返す。
6. IO の関数に `File.readBytes` と `File.writeBytes` を加える。書き込みは `FileSystemWriteCapability` を要する。
7. 実装は、連続したバイトの領域とする。部分を取り出すときは、同じ領域を共有する。

## 検討した代替案

- **`ByteArray`（Kotlin）と名付ける**: Kotlin に揃う。しかし、Kotlin の `ByteArray` は変更できる配列であり、意味が違う。
- **`b"…"` のリテラルを設ける**: 定数を短く書ける。しかし、字句の規則（エスケープ、ASCII の外の文字）が増える。定数は `Bytes.fromHex("89504e47")` で書ける。
- **固定幅の数を読む関数を幅ごとに設ける（`readUnsigned32BigEndian` など）**: 名前で意味が分かる。しかし、幅とバイト順と符号の組み合わせで関数が多くなる。

## 帰結

- 幅の違う整数の型がなくても、バイナリの形式を読み書きできる。
- `Bytes` は文字コードを仮定しないので、UTF-8 以外の文字コードのテキストもバイト列として保持できる。UTF-8 以外の文字コードとの変換と、Base64 などの符号化は、[OPEN-043](../open-issues.md#open-043) で検討する。
