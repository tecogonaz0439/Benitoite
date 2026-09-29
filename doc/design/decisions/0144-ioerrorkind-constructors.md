# 0144. `IOErrorKind` の構成子を 9 個で確定し、構成子を加えることを互換性を壊す変更として扱う

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [エラー処理](../01-spec/01-09-errors.md), [IO のモジュール](../03-interop/03-07-io-modules.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-034](../open-issues.md#open-034)（本 ADR で決着）, [OPEN-040](../open-issues.md#open-040)

## 背景

IO の失敗の種類を表す prelude の型 `IOErrorKind` を、構成子を公開する代数的データ型とした（[ADR 0065](0065-ioerror-kind.md)）。構成子を後から加えると、すべての構成子を並べた `case` が網羅性の検査で誤りになるので、初回リリース版のファイルとプロセスの API を定めるときに一覧を確定することにしていた（[OPEN-034](../open-issues.md#open-034)）。IO のモジュールの関数の一覧の草稿（[IO のモジュール](../03-interop/03-07-io-modules.md)）で、構成子を 9 個とする案を示した。

ネットワークの操作は IO と分けた（[ADR 0140](0140-network-separated-from-local-io.md)）。ネットワークの失敗は `IOError` ではなく `NetworkError` で表す（[ADR 0145](0145-network-error.md)）。

他の言語の調べた結果は[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「IO の失敗の種類」に記録した。要点は次のとおりである。

- Rust の `std::io::ErrorKind` は安定版で 40 近くの種類を持ち、版ごとに増やしている。Python は、エラー番号をすべて写すことを「foolish, pointless」として、15 ほどのサブクラスにまとめた（PEP 3151）。Go の `io/fs` は 5 つの値だけを持つ。
- どの言語も「その他」を表すものを持つ。Rust は、利用者が作る誤りの `Other` と別に、分類していない OS の誤りを入れる隠れた `Uncategorized` を持つ。
- 種類を後から加えても利用者のコードを壊さないために、Rust は `#[non_exhaustive]` で `_` の分岐を必須にし、Swift は `@unknown default` を必須にしたうえで、新しい構成子を扱っていないと警告する。Haskell は構成子を見せず、判定の関数だけを見せる。Gleam と Flix の列挙には、このような仕組みがない。

## 決定

1. `IOErrorKind` の構成子を、`NotFound`・`PermissionDenied`・`AlreadyExists`・`IsDirectory`・`NotDirectory`・`DirectoryNotEmpty`・`InvalidUTF8`・`InvalidInput`・`Other` の 9 個で確定する。
2. どの構成子にも当たらない失敗は、`Other` で表す。分類していない失敗を入れる構成子は、`Other` と別に設けない。
3. `IOErrorKind` は普通の代数的データ型のままとし、`case` で `_` の分岐を必須にする仕組みは設けない。構成子を加えることは、互換性を壊す変更として扱う。メジャーバージョンが 0 の間は、この変更をしてよい（[ADR 0090](0090-version-numbers-and-codenames.md)）。
4. `_` の分岐を必須にする仕組み（Rust の `#[non_exhaustive]`、Swift の `@unknown default` に当たるもの）を設けるかは、正式リリース版（1.0.0）の前に [OPEN-040](../open-issues.md#open-040) で決める。

## 検討した代替案

- **Rust と同じくらい細かく分ける**: 失敗ごとに異なる処理を書ける。しかし、スクリプトが種類ごとに分けて扱う失敗は限られ、構成子が多いと `case` を書くときに選びにくい。ディスクが一杯、装置をまたいだ移動などは、`IOError.message` で理由を示せば足りる。
- **`IOErrorKind` の `case` で `_` を今から必須にする**: 後から構成子を加えても、利用者のコードを壊さない。しかし、この仕組みは標準ライブラリの型だけでなくパッケージの型にも要るものであり、パッケージの扱い（[OPEN-049](../open-issues.md#open-049)）とあわせて一つの規則として決めるほうがよい。0.x の間は、構成子を加えても互換性の約束に反しない。
- **構成子を見せず、判定の関数だけを見せる（Haskell と同じ）**: 構成子を加えても利用者のコードを壊さない。しかし、ADR 0065 の「`case` で分けられる」ことを改めることになり、失敗の種類を網羅的に扱う書き方ができなくなる。
- **`Other` と別に、分類していない失敗を入れる構成子を設ける（Rust の `Uncategorized`）**: 後で分類を細かくしても、`Other` の意味が変わらない。しかし、利用者から見て二つの区別が分かりにくく、どちらも `_` で扱うことになる。

## 帰結

- [OPEN-034](../open-issues.md#open-034) を決着とする。
- 各関数が返しうる構成子は、[IO のモジュール](../03-interop/03-07-io-modules.md)の「IOErrorKind と関数の対応」で示す。
- 後の版で、ある失敗を `Other` から新しい構成子に移すと、`Other` の分岐でその失敗を扱っていたコードの振る舞いが変わる。この変更も、互換性を壊す変更として扱う。
