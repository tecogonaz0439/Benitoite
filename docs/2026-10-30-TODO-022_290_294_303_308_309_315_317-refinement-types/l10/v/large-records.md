# 大きい生の記録

100,000 byte を超える生の記録は `<tmp>` に置き、改造には大きさと SHA-256 を保存する。`<tmp>` は保存先の区分であり、手元の絶対パスではない。最終の検証入力と小さい出力は本ディレクトリに保存した。初回の公理依存と差分の古い識別は、現在の修正後の識別で置き換えた。

| 保存先 | byte | SHA-256 | 内容 |
|---|---:|---|---|
| `<tmp>/l10-v-axioms.log` | 621339 | `e38f4f82f2da63af16d85919009a88f2a2e76951dd88514e1c222da29dfb0dc5` | 全変更モジュールと旧主定理・モデルの公理依存の出力 |
| `<tmp>/l10-v-before.tar.gz` | 1628305 | `bfeda3a27835a1d54320afbd8dbfeed1fdafaa32cd675fbc1c1b0e7339f31ff9` | 初回開始時の Lean ソースの写し |
| `<tmp>/l10-v-current.diff` | 184287 | `eee4476a134a1d4c86342c62d6bd30907ed6fbcdd1c3691046f91e279ef907d5` | 初回開始時の写しとの全 Lean 差分（新規6モジュールを含む） |
| `<tmp>/l10-v-fix-before.tar.gz` | 2031235 | `e268df393c18f39c7c48bd608bf3c14a8f6eb98f6ada8eae65163ab7667f2894` | 今回の再開時の Lean と設計書三章の写し |
| `<tmp>/l10-v-review-fix.diff` | 65614 | `4f662be4e42adb414f47120cd10bf07a1256c7ea94a0aad605288aac1c439cc3` | 今回のレビュー修正の全差分（Lean 6・設計書3） |

公理依存は [axioms-summary.md](axioms-summary.md)、初回からの差分の識別は [source-state.json](source-state.json)、今回の修正だけの識別は [review-fix-state.json](review-fix-state.json) にある。
