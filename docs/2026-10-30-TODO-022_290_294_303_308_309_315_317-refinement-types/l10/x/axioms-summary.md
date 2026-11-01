# 公理依存と場合の数

変更した全15モジュールの宣言を Lean の環境から列挙し、private と生成した宣言を含めて `#print axioms` を実行した。旧五主定理と旧三モデルも含む1,359宣言である。境界は名前空間の全43宣言を同様に確認した。

依存は `propext`・`Quot.sound`・`Classical.choice` だけで、`sorryAx` と独自公理は0件である。全名の生の出力は [large-records.md](large-records.md)、モジュールごとの件数と全場合の集計は [axioms-summary.json](axioms-summary.json)、構成子の完全名は [case-matrix.tsv](case-matrix.tsv) を参照する。

| 族 | 実際の数 |
|---|---:|
| INHABITS | 28 |
| PATTERN | 11 |
| SCOPED_VALUE | 3 |
| MEANING | 28 |
| OBSERVATION_ORDER | 9 |
| TERM | 20 |
| PREDICATE | 14 |
| TYPING | 76 |

型付けの76構成子×4本=304枝は既存の相互証明の照合件数であり、新しい304証明の件数ではない。[typing-transports.tsv](typing-transports.tsv) に76行×4欄を保存した。対応する四ファイルは開始時から不変であり、変更後の全 import の下で再検査した。
