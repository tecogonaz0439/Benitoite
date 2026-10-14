# PureJson

Benitoite で JSON の解析と出力を実装する、比較のためのパッケージである。処理系の `Benitoite.Unofficial.Json` と同じ `Json.Value` と `Json.ParseError` を使う。

公開する関数は `Parser.parse`、`Parser.stringify`、`Parser.stringifyPretty` の三つである。値を取り出す `get`・`at`・`as*` は、標準ライブラリの `Json` の関数をそのまま使える。補助の宣言は `public(package)` とし、依存する側に公開しない。

`testdata/packages/json-pure-same/main.bnt` のように、入口から取り込む。

```text
dependency PureJson
  path "../libraries.files/pure-json"
end dependency
import PureJson.Parser
```

| ファイル | 役割 |
|---|---|
| `Parser.bnt` | 三つの公開関数と、継続を明示した解析。配列とオブジェクトの入れ子は 127 段まで受け付ける |
| `Scan.bnt` | 一度だけ UTF-8 にしたバイトの走査。誤りのときに行と文字の列を求める |
| `Strings.bnt` | エスケープ、UTF-16 のサロゲートの対、文字列の出力 |
| `Numbers.bnt` | 数の文法と字面による種類の区別。`Float.toString` から JSON の書式への変換と、十進の中点の丸めの補正 |
| `Writer.bnt` | 明示の作業列による出力。言語の呼び出しの深さを値の深さで増やさない |
| `Parts.bnt` | 部分を 64 個ごとに結合し、最後に全体を結合する |
| `Text.bnt` | 解析の誤りの文言 |

部分を 64 個ごとに結合するのは、参照インタプリタが組み込みのリスト操作のたびに値を変換する費用を抑えるためである。部分の数によるリストの上限を避け、出力のバイトは部分の結合と最後の結合で二度写す。

比較は CLI のゴールデンに置く。`json-pure-same` は値・診断・二つの出力、`json-pure-depth-array` と `json-pure-depth-object` は解析の深さの境界を確かめる。比較の補助は隣のテスト用パッケージ `json-checks` にある。

リポジトリの根で実行する。

```sh
BENITOITE_GOLDEN_FILTER=packages/json-pure cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=packages/json-pure cargo test -p benitoite --no-default-features --features gc-mark-sweep,gc-stress --test golden
target/debug/benitoite fmt --check crates/benitoite/testdata/packages/libraries.files/pure-json
```

比較表では負のゼロも出力のバイトで比較する。非有限値は `null` と書く。深さ 1,000 の値の出力は単発の確認で扱い、回収を安全点ごとに強制する構成で長時間になるため、常設のゴールデンには含めない。
