# 0184. 許可を組み込みのエフェクトの単位で与え、シェルによる実行だけを別の許可にする

- 状態: 採択（シェルによる実行の許可が許す範囲を [0215](0215-shell-permission-allows-run-commands-via-shell.md) で定めた）
- 日付: 2026-09-29
- 関連章: [エフェクト](../01-spec/01-07-effects.md), [IO のモジュール](../03-interop/03-07-io-modules.md), [ネットワークのモジュール](../03-interop/03-09-network.md), [ランタイム](../02-impl/02-09-runtime.md)
- 関連する未決事項: [OPEN-052](../open-issues.md#open-052), [OPEN-055](../open-issues.md#open-055)

## 背景

実行時の権限制御は、権限の種類（`read`・`write`・`run`・`shell`・`environment`・`exit`）を単位にしていた（[ADR 0074](0074-static-permission-check-by-name-reference.md) の決定 1、[ADR 0147](0147-remove-permission-declaration-syntax.md) の決定 3）。一方、組み込みのエフェクトは、IO を `File.Read`・`File.Write`・`Process.Run`・`Process.Environment`・`Process.Exit` などに分けている（[ADR 0116](0116-builtin-fine-grained-effects.md)、[ADR 0130](0130-builtin-effect-names-and-placement.md)）。ネットワークは `Http.Listen`・`Http.Connect` である（[ADR 0140](0140-network-separated-from-local-io.md)）。権限の種類とエフェクトは、ほぼ一対一に対応するが、名前が違う。例外は、`Process.run` と `Process.shell` の二つで、エフェクトはどちらも `Process.Run` であるのに対し、権限の種類は `run` と `shell` に分かれる。

サーバモードでは、登録するときにスクリプトのエフェクトを表示し、方針と比べる（[ADR 0183](0183-single-policy-for-all-permission-layers.md)）。許可の単位をどちらに揃えるかを決める必要があった（[OPEN-052](../open-issues.md#open-052)）。

## 決定

1. 許可は、許可を要する組み込みのエフェクトを単位とし、それぞれに対象を添えて与える。

   | エフェクト | 対象 |
   |---|---|
   | `File.Read` | パス |
   | `File.Write` | パス |
   | `Process.Run` | コマンド |
   | `Process.Environment` | 環境変数の名前 |
   | `Process.Exit` | なし |
   | `Http.Listen` | 待ち受けるアドレス |
   | `Http.Connect` | 接続先 |

2. シェルによる実行（`Process.shell`）は、エフェクトは `Process.Run` のままとし、許可は `Process.Run` とは別に与える。`Process.Run` の許可は、シェルによる実行を許さない。シェルでは、実行する内容が実行時まで分からないからである。プログラムがシェルによる実行を要するかは、`Process.shell` を名前で参照しているかで判定する（[ADR 0074](0074-static-permission-check-by-name-reference.md) の決定 2）。
3. 許可を要しないエフェクト（`Console.Write`・`Console.Read`・`Clock.Time`・`Random.Generate`・`State`・`Assert.Check`）と、許可を要しない操作（`Process.arguments`・`Process.scriptDirectory`・`Process.workingDirectory`）は、[エフェクト](../01-spec/01-07-effects.md)の定めのままとする。
4. 権限の種類（`read`・`write`・`run`・`shell`・`environment`・`exit`）は用いない。
5. 対象の照合は、パスは [ADR 0072](0072-permission-path-matching.md)、コマンドは [ADR 0073](0073-run-permission-command-matching.md) に従う。`Http.Listen` と `Http.Connect` の対象の書き方と照合は、[OPEN-052](../open-issues.md#open-052) で決める。シェルの許可の書き方は、方針のファイルの形とあわせて、サーバモードの章で定める。

## 検討した代替案

- **権限の種類（`read` など）にネットワークを加えたものを単位にする**: 01-07 の設計をそのまま使える。しかし、エフェクトの名前と権限の名前の二つの語彙が並び、利用者は対応を覚える必要がある。登録のときに表示するエフェクトと、方針の単位も食い違う。
- **組み込みのエフェクトだけを単位にし、シェルを区別しない**: 規則は最も単純である。しかし、`git` の起動を許可すると、シェルによる任意のコマンドの実行も許可したことになる。

## 帰結

- 登録のときに表示するエフェクトと方針の単位が同じなので、利用者は二つを見比べて判断できる。エフェクトによる判定（ADR 0183）も、この単位で行う。
- [ADR 0074](0074-static-permission-check-by-name-reference.md) の決定 1 の権限の種類と、[ADR 0147](0147-remove-permission-declaration-syntax.md) の決定 3 のうち権限の種類を、この ADR で置き換える。名前での参照による判定（ADR 0074 の決定 2）は、シェルによる実行の判定に使う。
- [IO のモジュール](../03-interop/03-07-io-modules.md)と[ネットワークのモジュール](../03-interop/03-09-network.md)の「要する権限」の欄は、エフェクトとシェルの許可で書く。
