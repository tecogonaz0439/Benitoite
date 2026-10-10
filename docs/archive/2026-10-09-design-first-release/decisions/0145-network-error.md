# 0145. ネットワークの失敗を、prelude の `NetworkError` と `NetworkErrorKind` で表す

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [エラー処理](../01-spec/01-09-errors.md), [ネットワークのモジュール](../03-interop/03-09-network.md), [標準ライブラリ](../03-interop/03-06-stdlib.md), [並行処理](../01-spec/01-11-concurrency.md), [コア計算と脱糖](../01-spec/01-12-core-calculus.md), [他の言語の調査記録](../08-appendix/08-03-language-surveys.md)
- 関連する未決事項: [OPEN-034](../open-issues.md#open-034), [OPEN-040](../open-issues.md#open-040)

## 背景

ネットワークの操作を、`Benitoite.Network` の下のモジュールに置き、IO と分けた（[ADR 0140](0140-network-separated-from-local-io.md)）。HTTP のクライアントとサーバの関数の草稿（[ネットワークのモジュール](../03-interop/03-09-network.md)）は、失敗を `Result[T, IOError]` で返し、名前を解決できない、接続を拒まれたなどの失敗の構成子を `IOErrorKind` に加えることを検討していた（[ADR 0142](0142-http-api-shape.md)）。

他の言語の調べた結果は[他の言語の調査記録](../08-appendix/08-03-language-surveys.md)の「IO の失敗の種類」に記録した。接続を拒まれた・途中で切れた・時間切れは、Rust・Deno・Python がそれぞれ ConnectionRefused・ConnectionReset・TimedOut と呼ぶ。名前を解決できない失敗は、Java と Flix が UnknownHost と呼び、Rust には当たる種類がない。

## 決定

1. ネットワークの操作の失敗を、`IOError` と別の型 `NetworkError` で表す。ネットワークの関数は、失敗しうるときに `Result[T, NetworkError]` を返す。
2. `NetworkError` は、`IOError` と同じく中身を見せない prelude の型であり、等値の型ではない。関数 `NetworkError.kind` と `NetworkError.message` を持つ。
3. 失敗の種類を表す型 `NetworkErrorKind` を prelude に置く。構成子を公開する代数的データ型であり、等値の型である。構成子は次の 9 個とする。

   | 構成子 | 失敗 |
   |---|---|
   | `HostNotFound` | 名前を解決できない |
   | `ConnectionRefused` | 接続を拒まれた |
   | `ConnectionReset` | 接続が途中で切れた |
   | `TimedOut` | 時間切れ |
   | `AddressInUse` | 待ち受けるアドレスとポートが使われている |
   | `InvalidHTTPData` | 受け取った内容が、HTTP として正しくない |
   | `InvalidInput` | URL やアドレスの形式が正しくない |
   | `PermissionDenied` | OS が操作を拒んだ。権限の宣言による拒否は、これではなく実行時エラーとする |
   | `Other` | 上のどれにも当たらない。TLS の証明書の検証の失敗を含む |

4. `HostNotFound`・`ConnectionRefused`・`ConnectionReset`・`TimedOut`・`AddressInUse` は、HTTP に限らないネットワークの失敗を表す。`InvalidHTTPData` は HTTP に固有の失敗であり、後の版で HTTP 以外のプロトコルを加えても、その失敗には使わない。
5. 構成子を加えることの扱いと `Other` の扱いは、`IOErrorKind` と同じとする（[ADR 0144](0144-ioerrorkind-constructors.md)）。

## 検討した代替案

- **`IOErrorKind` にネットワークの失敗の構成子を加える**: 失敗の型が一つで済み、IO とネットワークの両方を使う関数で `Result.mapError` が要らない。しかし、ネットワークの操作を IO と分けた（ADR 0140）のに、失敗の型だけが IO に属することになる。ファイルの操作だけを行うスクリプトの `case` にも、ネットワークの失敗の構成子が現れる。
- **`NetworkError` と `NetworkErrorKind` を `Benitoite.Network.Http` の中に置く**: HTTP を使わないスクリプトからは見えない。しかし、`Http.NetworkErrorKind.TimedOut` と長くなり、後の版で TCP のモジュールを加えたときに、同じ型を共有できない。`IOError` も、IO のモジュールと別に prelude に置いている。
- **TLS の証明書の検証の失敗に構成子を設ける**: 失敗の原因が型で分かる。しかし、証明書の問題は、プログラムの中で分けて扱うより、原因を見て直すことが多い。理由は `NetworkError.message` で示す。

## 帰結

- 03-09 の関数の型の `IOError` を `NetworkError` に改める。
- IO とネットワークの両方の失敗を返す関数は、`Result.mapError` でどちらかの型にそろえる。
- prelude の中身を見せない型に `NetworkError` が加わる。コア計算の中身を見せない型の集まりにも加える。
