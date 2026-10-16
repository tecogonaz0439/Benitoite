# try の処置の交換形式の独立入力

corpus 10・型表 3・網羅性 3 を六つの実行ファイルへ渡す。`corpus.json` の期待コアは手書きであり、Lean の脱糖や Rust の書き出しから生成しない。`test_try_exchange.py` が共通の CLI 呼び出しを `test_named_exchange.py` と共有し、`scripts/check-formal.sh` から実行する。

| 定義 | 確かめる契約 |
|---|---|
| fn:0〜3 | Result/Option の die と説明の有無。入力一回、失敗側の説明・表示・exit の順、局所参照の移動 |
| fn:4〜7 | Result/Option の裸／明示 return が同じ表層の規則へ写る。Show の制約は不要 |
| fn:8 | 説明の中の lambda と、その宣言した効果 A を保持する。lambda の値を作る説明自体は純粋 |
| fn:9 | 実装辞書の名前 Show を保持する。標準参照は class:7・meth:9・prim:8 とし、局所パラメータ show・exit の綴りで選び直さない |
| fn:10 | 入力と説明の lambda を辿り、その宣言した効果を入力 B・説明 A の順で保持する |

型検査に必要な Show のメソッドと exit の型・効果は宣言表から渡す。実装辞書の署名は標準ライブラリの sidecar に信頼表として明示する。`Result` と `Option` の二分岐に対する閉じた網羅性も同じ型表で検査する。二つの網羅性入口にはそれぞれ二件の独立入力を渡す。

処置はタグで区別する。裸は `tryResult`/`tryOption`、明示 return は `tryResultReturn`/`tryOptionReturn`、die は `tryResultDie`/`tryOptionDie` である。die は `ty`・構成子・`inner`・`exit`・`message`、Result はさらに `dict`・`showMethod` を必須とする。`message: null` と空文字列の説明は異なる。新しいタグを corpus 8/9 へ混ぜた入力、必須欄欠落、別の処置用の欄は拒否する。

ここで検査するのは交換された参照の保持と検証である。この独立入力だけではソースの名前解決と実行時の報告は検査しない。Rust の lib の検査は cfg(test) の共通 parser の入口から型検査・脱糖した Result/Option の Die を、同じ交換器で出力し、この入力の表層と期待コアに照合する。標準のクラス・メソッド・exit の識別名は、解決済みの標準束縛番号と組み込みの表に照合する。本番 parser からの一貫した比較は、Die の本番受理後に行う。

```sh
(cd formal && lake build)
python3 -I formal/tests/test_try_exchange.py
```
