# 大きな記録の保管

2026-10-30、V10.3d。

原本の大きさと SHA-256 は下表のとおりである。gzip は `gzip -9n` で作成し、展開したバイト列が原本と一致することを確かめた。本文が記す原本の件数・ハッシュは変えていない。移動分は取りまとめがリポジトリ外へ保管する。

| 原本名 | 原本 bytes | 原本 SHA-256 | 現在の保存 |
|---|---:|---|---|
| `cli-before.json` | 1189518 | `6607c3f9754110165163c9bf835f7af49e462260319c70db8cf214d1a9fc24b9` | [cli-before.json.gz](cli-before.json.gz)（35422 bytes） |
| `cli-final.json` | 1189518 | `8e0c84c9d9d0461f1e9e5acaedc9b509cd8c15d1b119f2ddfa4fad290124d33c` | [cli-final.json.gz](cli-final.json.gz)（35422 bytes） |
| `cli-after.json` | 1189518 | `1f46db28f511c2b098313fd01d7ee5ee4df505651c7698be82f91904db97dbed` | [cli-after.json.gz](cli-after.json.gz)（35421 bytes） |

読み方・台本の入力の復元、全33件と重複の一覧は [保管一覧](../v10.3d/large-files.md)による。元の実行で使ったファイル名と、現在の圧縮ファイル名を混同しない。過去の状態スナップショットは現在版から作り直せない。元の同じ内容は基準 `03ad23bef73ab265cdced5336e6b9f21ce7b7166` の追跡木から `git show <基準>:<元のリポジトリ相対パス>` でも取得できる。検査・測定そのものの再実行はしていない。
