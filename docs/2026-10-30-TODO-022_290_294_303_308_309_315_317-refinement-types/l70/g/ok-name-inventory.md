# 成功値の名前の写しの準備（判断2。L70.42 に依らない一覧）

2026-11-07 10:55。交換の Result の構成子の名前 `"Ok"`・`"Error"` を、新しい表層の実例の表と同じ `Result.Ok`・`Result.Error` へ写す位置と、交換へ書き戻す経路の一覧である。行番号は作業木の今の版（L70.42 の結合の前）のもので、結合の後に照らし直す。まだ変えていない。

## 写す位置（交換 → 新しい表層）

| ファイル・行 | 位置 | 種類 |
|---|---|---|
| `Exchange/Convert.lean` 431 | `Pattern.toSurface` の `.con` | パターン |
| 同 432〜435 | `Pattern.toSurface` の `.record` | パターン（record の構成子） |
| 同 579・580 | `Expr` の `.nullCon`・`.conValue` | 構成子の値 |
| 同 615〜627 | `.record`・`.recordUpdate`・`.conCall`・`.partialCon` | 構成子の呼出し |
| 同 967〜968 | 取得関数の構成子（`accessor`） | 宣言 |
| `Exchange/Builtins.lean` 272〜275 | `DataEntry.toMaterial` の構成子の名前 | 組込みの data の材料 |
| 同 247・266・287 | `DataEntry.info`・形の検査・`dataConstructors` | data の表 |
| `Exchange/CheckInput.lean` | `Materials` の `cons`・`conFields`・`dataInfo` と `constructorsOk`・記録の照合 | 宣言の表 |
| `Exchange/Observe.lean` | `acceptInput` の `ok` | 受理の入力 |

## 書き戻す経路（新しい表層 → 交換。逆に写す）

| ファイル・行 | 経路 | 比べる相手 |
|---|---|---|
| `Exchange/Convert.lean` 463 | `fromPattern` の `.con` | 処理系の脱糖の書き出し（desugarDiff） |
| 同 763 | `fromVal` の `.con` | 同 |
| 同 766〜 | `fromComp`（`fromVal`・`fromPattern` を通る） | 同 |
| `Interval/Exchange.lean` 337〜340・799〜 | 区間の具体値の `con` の読み取りと `actualJson` | 処理系の区間の期待値（intervalDiff） |
| `CoverageDiff/Main.lean`・`Release/Refinement/CoverageShow.lean` | 反例の表示の構成子の名前（表示の表を引く鍵） | 処理系の網羅性の診断 |

## 確かめること

- 写しは一つの有限表（`"Ok" ↦ "Result.Ok"`・`"Error" ↦ "Result.Error"`）とその逆で行い、往復で元に戻ることを補題で示す。
- 写した後に、desugarDiff・intervalDiff・coverageDiff の一致を L70.42 の新しい書き出しの少数の入力で確かめる。
- 受理の規則の健全性 `productionRules_sound` を `ok := "Result.Ok"` で適用し、中身のある主張にする（`Exchange.Observe.acceptInput`）。
