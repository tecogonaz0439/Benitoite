# 0101. 型と標準ライブラリの名前を、省略しない英単語で書く

- 状態: 採択（権限の宣言の構文を [0147](0147-remove-permission-declaration-syntax.md) で削除した。権限の種類の名前は残る）
- 日付: 2026-09-28
- 関連章: [基本型の意味論](../01-spec/01-04-types-basic.md), [エフェクト](../01-spec/01-07-effects.md), [構文](../01-spec/01-02-syntax.md), [標準ライブラリ](../03-interop/03-06-stdlib.md)
- 関連する未決事項: [OPEN-012](../open-issues.md#open-012)

## 背景

キーワードは、省略しない英単語で書くことにした（[ADR 0092](0092-unabbreviated-keywords.md)）。型と prelude の名前には、人間が書く量を減らすための省略形が残っていた（`Int`、`Bool`、`Char`、`Ref`、`Caps`、`Console.println`、`Process.args` など）。

Benitoite のスクリプトを主に書くのは LLM であり、利用者がコードに直接触るのは表面の小さな修正に限られる（[目的と設計原則](../00-overview/00-01-goals.md)）。書く量を減らす利点は小さく、省略しない語の方が、プログラマでない利用者にも意味を推測しやすい。

## 決定

1. 型、prelude と std の関数、権限の宣言の名前は、省略しない英単語で書く。
2. 利用者が頭字語のまま見聞きする語（`IO`、`UTF8`、`ASCII`、`NaN` など）は、頭字語で書く（[ADR 0091](0091-acronyms-in-uppercase.md)）。定着していない頭字語は語で書く（FS は `FileSystem`）。`Result.Ok` の `Ok` も、定着した語として残す。
3. `Float` は、浮動小数点数の型の名前として定着しているので、そのまま残す。
4. 既存の名前を次のように改める。

| 改める前 | 改めた後 |
|---|---|
| `Int`、`Bool`、`Char` | `Integer`、`Boolean`、`Character` |
| `Ref[T]` | `Reference[T]` |
| `Caps`、`ExecCap`、`ExitCap`、`FSWriteCap` | `Capabilities`、`ExecuteCapability`、`ExitCapability`、`FileSystemWriteCapability` |
| `Caps.exec`、`Caps.exit`、`Caps.fsWrite` | `Capabilities.execute`、`Capabilities.exit`、`Capabilities.fileSystemWrite` |
| `Console.print`、`Console.println`、`Console.eprintln` | `Console.write`、`Console.writeLine`、`Console.writeErrorLine` |
| `Int.abs`、`Float.abs`、`Int.min`、`Int.max`、`Int.mod`、`Int.floorDiv` | `Integer.absolute`、`Float.absolute`、`Integer.minimum`、`Integer.maximum`、`Integer.modulo`、`Integer.floorDivide` |
| `Float.ceil`、`Float.sqrt` | `Float.ceiling`、`Float.squareRoot` |
| `Char.fromInt`、`Char.toInt` | `Character.fromInteger`、`Character.toInteger` |
| `String.chars`、`String.fromChars`、`String.charAt`、`String.charCount`、`String.charSlice` | `String.characters`、`String.fromCharacters`、`String.characterAt`、`String.characterCount`、`String.characterSlice` |
| `List.concat`、`Process.args` | `List.concatenate`、`Process.arguments` |
| 権限の `env` | `environment` |

## 検討した代替案

- **省略形のままにする**: 多くの言語で見慣れた名前であり、書く量が少ない。しかし、キーワードを省略しない語にしたこと（ADR 0092）と揃わず、プログラマでない利用者には意味を推測しにくい。
- **`Float` も省略しない形（`FloatingPoint`）にする**: 規則に例外がなくなる。しかし、この名前で数の型を表す言語は見当たらず、かえって読み手と LLM を迷わせる。
- **出力の関数を `Console.print`・`Console.printLine`・`Console.printErrorLine` にする**: いまの名前を省略しない形に直したものである。採った `write` の系統は、C# の `Console.WriteLine` に近い。

## 帰結

- 設計書の全章の型と関数の名前、例の中の変数名（`caps` を `capabilities` にするなど）を改める。ADR 0006・0063・0069・0070・0074・0091 の本文は書き換えず、状態欄に本 ADR で改めたことを記す。
- 最小実行版の処理系と[言語リファレンス](../../../reference/benitoite-minimal.md)は、旧い名前のままであり、設計の段階では直さない。
- 省略しない名前と省略形のどちらが LLM の書き誤りを減らすかは確かめていない。[OPEN-012](../open-issues.md#open-012) の測定の対象として検討する。
