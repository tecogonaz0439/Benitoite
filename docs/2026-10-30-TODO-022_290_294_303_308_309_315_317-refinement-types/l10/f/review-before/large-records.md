# 大きな生の記録

100,000バイトを超える出力は一時領域へ保存し、改造には置かない。再実行の入力は [../axioms.lean](../axioms.lean)、入口は [verify.py](verify.py) である。手元の絶対パスは記録しない。正規化した全宣言名と依存は200件ずつ axioms-names-*.json に保存する。

| 記録 | 一時領域の生出力 | 大きさ（bytes） | SHA-256 |
|---|---|---:|---|
| initial-axioms-result.json | `<tmp>/benitoite-l10-f-neq6ktpg/axioms-output.txt` | 415769 | `52cbef9a6c3c2b7c263a15089b4a8c19ba21324f2506aa7963b05c6ba2ac08ff` |
| axioms-result.json | `<tmp>/benitoite-l10-f-xu2r4sve/axioms-output.txt` | 2109143 | `c1a1dbb238dc6e5db5616f0184f1aa0afc05de8139e7cb79513cf5f983d50434` |

初回は空の Exchange を拒んだ途中終了であり、最終の成功の証拠には使わない。最終のLean実行は終了0で、同じ生出力の集計器だけをアポストロフィを含む完全名へ直した。再集計による生出力の変更はない。

開始時の入力ハッシュの大きな一括出力も `<tmp>/benitoite-l10-f-glaeo4tz/before-sha256.json` に移した。大きさは179636 bytes、SHA-256 は `bba40579b1728492a076e8f8b198cc684bc70a939c6e6dea19a0fd92f3d17f4a`。照合に使う同じ辞書は before-sha256-*.json へ250入力ずつ分割し、before-sha256.json を索引とした。
