# 主な定理の契約の照合

開始時に保存したソースと現在のソースで、次の10定理の宣言の引数・前提・結論（証明本体の前まで）を、空白を除いて照合した。レビュー修正後もすべて一致した。照合した宣言の SHA-256 と判定は [main-contracts-result.json](main-contracts-result.json) に保存した。型付け判断が読む `Ty.LeQ` には同じ `P` が追加されている。これ以外の主定理の前提の追加、結論の弱化はない。

| 定理 | ファイル | 結果 |
|---|---|---|
| `HasTypeVQ.shift_values` | `formal/Benitoite/Release/Refinement/TypingShift.lean` | 一致 |
| `HasTypeCQ.shift_values` | `formal/Benitoite/Release/Refinement/TypingShift.lean` | 一致 |
| `HasTypeVQ.shift_types` | `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean` | 一致 |
| `HasTypeCQ.shift_types` | `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean` | 一致 |
| `HasTypeVQ.subst` | `formal/Benitoite/Release/Refinement/SubstTyping.lean` | 一致 |
| `HasTypeCQ.subst` | `formal/Benitoite/Release/Refinement/SubstTyping.lean` | 一致 |
| `HasTypeVQ.subst_under_none` | `formal/Benitoite/Release/Refinement/SubstTyping.lean` | 一致 |
| `HasTypeCQ.subst_under_none` | `formal/Benitoite/Release/Refinement/SubstTyping.lean` | 一致 |
| `HasTypeVQ.narrow` | `formal/Benitoite/Release/Refinement/Narrowing.lean` | 一致 |
| `HasTypeCQ.narrow` | `formal/Benitoite/Release/Refinement/Narrowing.lean` | 一致 |

この文字の照合だけを証明の成立の証拠にはしない。全体のLeanビルドと、四本の相互証明を含む公理依存の照合を併せて実行した。
