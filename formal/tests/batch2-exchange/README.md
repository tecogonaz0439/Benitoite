# 交換11/4の独立入力

型付きFail、NoFailの行、操作と節の辞書を五形式・六入口で検査する。corpusの期待コアは手書きであり、Leanの脱糖やRustの書き出しを使って生成しない。既存のnamed-exchangeから宣言表の準備を共有し、新しい契約の七定義に絞っている。旧版互換の主な検査は既存の四つの交換テストが受け持つ。

| 定義 | 独立して確認する内容 |
|---|---|
| fn:8 | ShowIntの実装。辞書の参照元となる実装メソッド |
| fn:101 | Fail[String]のraise。間接の呼び出しとして、関数値と引数を順に評価 |
| fn:102 | 非再開の捕捉。コアのFail節にエラー型を保持 |
| fn:103 | 固定Failと行の署名。noFail=trueを本体と独立に再計算 |
| fn:104 | 制約付き操作の直接呼び出し。辞書を値引数の前へ置く |
| fn:105 | 操作の値化。辞書を捕えるラムダの型と潜在効果 |
| fn:106 | 辞書付きの通常節。節の制約0番を操作値へ捕え、継続0番を保つ |

coverageは関数型内のFail、レコードのパターン、Characterの全域の三件、coverage-programは関数型内のFailと既存のパターン二件を持つ。Pythonの変異入力で、新欄の混入・必須欄の欠落・個数・型番号・行番号・NoFail・節の所属・異なるFailの欠落を検査する。複数Failの内部上限は読めるが、表層の単一Failの検査は別に失敗する。

```sh
python3 -B formal/tests/test_batch2_exchange.py
```

O2/F3の局所Rust出力は、同じコマンドに `--rust-dir target/formal-batch2-op` または `--rust-dir target/formal-batch2-failure` を付けて読む。このオプションは存在する11/4の五形式を必須とし、Cargoを起動しない。完全な交換契約と切り替えの担当は改造のL4bの文書に記録する。
