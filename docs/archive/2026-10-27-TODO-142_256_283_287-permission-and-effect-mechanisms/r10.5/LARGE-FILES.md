# 大きな記録の保管

2026-10-30、V10.3d。

原本の大きさと SHA-256 は下表のとおりである。gzip は `gzip -9n` で作成し、展開したバイト列が原本と一致することを確かめた。本文が記す原本の件数・ハッシュは変えていない。移動分は取りまとめがリポジトリ外へ保管する。

| 原本名 | 原本 bytes | 原本 SHA-256 | 現在の保存 |
|---|---:|---|---|
| `cli-before.json` | 1190093 | `2ce2cc217e84d845afced2f7e04d512e6d608546a30693ac6122b0323703d9e7` | [cli-before.json.gz](cli-before.json.gz)（35452 bytes） |
| `cli-provenance-before.json` | 1186524 | `9c92fb6113b2f4353729b127e4c7369599320617202e5c01b415e947e1e0c1a8` | [cli-provenance-before.json.gz](cli-provenance-before.json.gz)（35422 bytes） |
| `cli-provenance-after.json` | 1189512 | `935d85b873b51fb53aaf101515ae41fa0cd6030272b27904239b3357b40998cb` | [cli-provenance-after.json.gz](cli-provenance-after.json.gz)（35475 bytes） |
| `cli-after.json` | 1190093 | `20c3487e708c2dba7e7d6dd3cdf458ad1103fffd19177357a799c8b89f39b82f` | [cli-after.json.gz](cli-after.json.gz)（35453 bytes） |

読み方・台本の入力の復元、全33件と重複の一覧は [保管一覧](../v10.3d/large-files.md)による。元の実行で使ったファイル名と、現在の圧縮ファイル名を混同しない。過去の状態スナップショットは現在版から作り直せない。元の同じ内容は基準 `03ad23bef73ab265cdced5336e6b9f21ce7b7166` の追跡木から `git show <基準>:<元のリポジトリ相対パス>` でも取得できる。検査・測定そのものの再実行はしていない。
