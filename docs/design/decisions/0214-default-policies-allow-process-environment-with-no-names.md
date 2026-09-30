# 0214. 既定の方針は、`Process.Environment` を対象の名前を空にして許す

- 状態: 採択
- 日付: 2026-09-29
- 関連章: [エフェクト](../01-spec/01-07-effects.md), [セキュリティモデル](../07-quality/07-01-security-model.md), [サーバモード](../06-tooling/06-07-server.md)
- 関連する未決事項: [OPEN-055](../open-issues.md#open-055)

## 背景

`Process.arguments`・`Process.scriptDirectory`・`Process.workingDirectory` は、エフェクト `Process.Environment` を持つが、許可を要しない（[ADR 0184](0184-permissions-granted-per-builtin-effect.md) の決定 3）。一方、実行の前の判定は `main` の型のエフェクトで行い、方針が許さないエフェクトを含むプログラムを拒否する（[ADR 0183](0183-single-policy-for-all-permission-layers.md)）。`server exec` の既定の方針は `Process.Environment` を許さない（[ADR 0185](0185-default-policies-per-run-kind.md)）。このため、引数や作業ディレクトリを読むだけのスクリプトも、`server exec` の既定の方針では実行の前に拒否される。

## 決定

1. 既定の方針は、`Process.Environment` を、対象（環境変数の名前）の並びを空にして許す。この許可のもとで、スクリプトは引数と二つのディレクトリを読めるが、どの環境変数も読めない。
2. どの許可の単位でも、エフェクトを許すことと、対象の並びは別の指定とする。`File.Read` のパスの並びと同じ形である。対象の並びを空にして許したエフェクトは、実行の前の判定を通り、実行時にはどの対象の操作も許さない。

## 検討した代替案

- **`Process.Environment` を実行の前の判定から外す**: 既定の方針を変えずに済む。しかし、エフェクトごとに判定の規則が変わり、表示するエフェクトと判定するエフェクトが食い違う（[ADR 0184](0184-permissions-granted-per-builtin-effect.md) の帰結）。
- **三つの関数を別のエフェクトに移す**: 許可を要しない操作と要する操作が、エフェクトで分かれる。しかし、言語仕様の変更になり、エフェクトの数も増える。

## 帰結

- [ADR 0185](0185-default-policies-per-run-kind.md) の表の `server exec` の行のうち、`Process.Environment` を許可しないとした部分を、この ADR で改める。
- 方針のファイルでは、`"Process.Environment" = []` と書く（[サーバモード](../06-tooling/06-07-server.md)の「方針のファイル」）。
