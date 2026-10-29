# 大きな記録の保管

2026-10-30、V10.3d。

原本の大きさと SHA-256 は下表のとおりである。gzip は `gzip -9n` で作成し、展開したバイト列が原本と一致することを確かめた。本文が記す原本の件数・ハッシュは変えていない。移動分は取りまとめがリポジトリ外へ保管する。

| 原本名 | 原本 bytes | 原本 SHA-256 | 現在の保存 |
|---|---:|---|---|
| `work-inputs.json` | 747909 | `fce59a1eee7eb16fb75cceb26f7afa211f0953bad904e27cb55c4e8467d34e88` | [work-inputs.json.gz](work-inputs.json.gz)（143469 bytes） |
| `r40.3b-final-inputs.json` | 748177 | `ffee8273add29b25b5d113c414aa956cd7a00cf3a889b86182663878338efcfa` | [r40.3b-final-inputs.json.gz](r40.3b-final-inputs.json.gz)（143573 bytes） |
| `final-inputs.json` | 748014 | `5d7c0fdb7c2e587cf195d194914b0c83a1a9ba78dc452a010c3f12e92ed0c274` | [final-inputs.json.gz](final-inputs.json.gz)（143512 bytes） |
| `r40.3b-work-inputs.json` | 748072 | `9d485c2a752d4e5b7b1977b685b0a565d79f55b83de92d99eeff0ade51952323` | [r40.3b-work-inputs.json.gz](r40.3b-work-inputs.json.gz)（143528 bytes） |

読み方・台本の入力の復元、全33件と重複の一覧は [保管一覧](../v10.3d/large-files.md)による。元の実行で使ったファイル名と、現在の圧縮ファイル名を混同しない。過去の状態スナップショットは現在版から作り直せない。元の同じ内容は基準 `03ad23bef73ab265cdced5336e6b9f21ce7b7166` の追跡木から `git show <基準>:<元のリポジトリ相対パス>` でも取得できる。検査・測定そのものの再実行はしていない。
