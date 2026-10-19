# L2の独立期待値とM1への対応

ResultLawsは純粋な小モデルであり、Monad2Examplesは本体の型付き表層からコアまでの具体例である。両者の一致を証明する全体定理は設けていない。Rustと標準の`.bnt`への接続はM1で行う。この記録はM1の入力と期待値を固定するものであり、Rustで実行済みとは扱わない。

## 宣言と辞書

- Functor2のmap、Applicative2のpure/apply、Monad2のflatMapはdesign 6.1の署名と引数名を使う。applyの契約名はfs/x、他の二引数メソッドはx/fである。コールバックの契約名はvalueとする。
- ResultとUserResultは成功型が先で、Ok(A)とError(X)を持つ別の二引数dataである。UserResultも三クラスを実装する。Leanの全プログラム検査では実装の実名、上位辞書、全メソッド本体を検査する。
- `genericMap`は型パラメータA/B/X/FとF: Monad2の辞書を受け、Monad2→Applicative2→Functor2の二段の射影でmapを呼ぶ。脱糖後の引数名は `%dict1, x, f`、辞書の型は `Dict[Monad2,F]`、辞書の局所番号は2である。
- map/flatMapの値化も、二つの値引数を束縛したラムダの中へ外側の辞書を移し、番号2で読む。mapの受け手には二段の上位射影を保つ。
- `result_constructor_wf`・`result_constructor_sat`・`constructor_dictionary_checked`は裸のResultの入口を確認する。Leanの型表現にkindの添字はないため、Rustのkind検査の成功や拒否の証明ではない。

## 独立した実行入力

両型で同じ12件を使う。成功型A/BはInteger、XはString、通常のコールバックの効果は空である。以下の期待値は小モデルのmap/apply等やコアの実行から生成せず、表に固定した。Leanの`cases`、`expressions_checked`、`executions_expected`が所有元の検査である。M1では実ソースから型検査→辞書の脱糖→VM→局所交換へ通し、同じ結果を得ることを確かめる。

| 入力 | 期待値 | 辞書・値化の境界 |
|---|---|---|
| map(Ok(7), 常に42を返す関数) | Ok(42) | 二段の上位射影 |
| map(Error("input"), 同じ関数) | Error("input") | mapを値化して呼ぶ |
| flatMap(Ok(7), valueをOkに包む関数) | Ok(7) | flatMapを値化して呼ぶ |
| flatMap(Ok(7), Error("callback")を返す関数) | Error("callback") | 直接呼び出し |
| flatMap(Error("input"), valueをOkに包む関数) | Error("input") | flatMapを値化して呼ぶ |
| pure(7) | Ok(7) | Applicative2への射影 |
| apply(Ok(常に42を返す関数), Ok(7)) | Ok(42) | Applicative2への射影 |
| apply(Ok(同じ関数), Error("input")) | Error("input") | 同上 |
| apply(Error("function"), Ok(7)) | Error("function") | 同上 |
| apply(Error("function"), Error("input")) | Error("function") | 関数側のErrorを優先 |
| genericMap(Ok(7), 常に42を返す関数) | Ok(42) | 関数の前置辞書と上位射影 |
| genericMap(Error("input"), 同じ関数) | Error("input") | 同上 |

M1ではこれに加え、design 6.1のコールバックの0/1回と、引数式がソース順に評価されることを観察可能な効果で確認する。L2の純粋な実行例だけを回数や評価順の証明として扱わない。

## 拒否入力

- `Result[Integer,String]`に渡すflatMapのコールバックが`Result[Integer,Integer]`を返す入力は、コールバックの結果型の位置で拒否する。Leanでは経路`[1,1]`、理由`type is not included in the expected type`である。Rustでは既存の型不一致の診断を使い、Xを暗黙に変換しない。
- `Monad2[UserResult]`の辞書で`Result`のmapの引数注釈を満たそうとする入力は、メソッドの型注釈の不一致で拒否する。Leanでは経路`[]`、理由`method parameter annotation mismatch`である。M1では実ソースの辞書解決と対象の対応も確認する。
- Rustの型構成子の種類・重複・孤児実装の拒否は既存規則を使う。ここでRustの新しい診断コードやkind検査の定理を設けてはいない。

## 保証の境界

本体の六実装はmap/flatMapを分岐で直接書き、外部の関数署名を信頼していない。M1の標準実装はdesign 6.1どおりResult.map/andThenへ委譲する。委譲と本体例の対応は上の独立期待値で照合する（R146）。任意の利用者辞書がMonadの法則を満たすことは、型検査だけでは保証しない。全形式化比較はL7と改造末の割り当てに従う。
