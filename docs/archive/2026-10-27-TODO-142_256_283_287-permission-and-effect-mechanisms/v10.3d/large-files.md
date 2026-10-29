# 200 KiB 超の記録33件の保管

2026-10-30。閾値は204,800 bytes。開始時の33件を原本で数え、30件を gzip -9n で圧縮した。既存の gzip 3件は V10.3d でいったん追跡木から外したが、RV-V10.3 中1への対応（V10.3db）で元の位置へ戻した。K10.3 の引用の元の記録なので、200 KiB の決まりの例外として追跡木に残す（設計者の委任による取りまとめの判断、2026-10-30）。全原本の bytes と SHA-256、圧縮後の値は [JSON](large-files.json)、文書リンクの変更は [一覧](large-file-link-changes.json)による。

## 原本一覧

| 原本（改造内） | 原本 bytes | 原本 SHA-256 | 保存方法 | 保存 bytes |
|---|---:|---|---|---:|
| `r10.4/cli-before.json` | 1189512 | `0a1ee27cbbefa467623cbc920edbee90b7640f0dcad7e6cc5038d621eb4ecc34` | gzip | 35475 |
| `r10.4/cli-after.json` | 1189512 | `29172d2dc1ea86409ce8f395961a907aebff9340ca6ac2cab2c58db8f26570c5` | gzip | 35477 |
| `v10.3c/final-state.json` | 330439 | `5d77405dc781bd3bea389c9a8161fb450d2a12da8fdd1a96ecdaff6969ae6f80` | gzip | 41308 |
| `r10.5/cli-before.json` | 1190093 | `2ce2cc217e84d845afced2f7e04d512e6d608546a30693ac6122b0323703d9e7` | gzip | 35452 |
| `r10.5/cli-provenance-before.json` | 1186524 | `9c92fb6113b2f4353729b127e4c7369599320617202e5c01b415e947e1e0c1a8` | gzip | 35422 |
| `r10.5/cli-provenance-after.json` | 1189512 | `935d85b873b51fb53aaf101515ae41fa0cd6030272b27904239b3357b40998cb` | gzip | 35475 |
| `r10.5/cli-after.json` | 1190093 | `20c3487e708c2dba7e7d6dd3cdf458ad1103fffd19177357a799c8b89f39b82f` | gzip | 35453 |
| `r40.3/work-inputs.json` | 747909 | `fce59a1eee7eb16fb75cceb26f7afa211f0953bad904e27cb55c4e8467d34e88` | gzip | 143469 |
| `r40.3/r40.3b-final-inputs.json` | 748177 | `ffee8273add29b25b5d113c414aa956cd7a00cf3a889b86182663878338efcfa` | gzip | 143573 |
| `r40.3/final-inputs.json` | 748014 | `5d7c0fdb7c2e587cf195d194914b0c83a1a9ba78dc452a010c3f12e92ed0c274` | gzip | 143512 |
| `r40.3/r40.3b-work-inputs.json` | 748072 | `9d485c2a752d4e5b7b1977b685b0a565d79f55b83de92d99eeff0ade51952323` | gzip | 143528 |
| `l20.2/trial/trial-1.diff` | 213350 | `cf5f662427418759d797bf9d7afb534de9fc8d0858afbb47bd20668cbf01b098` | gzip | 44787 |
| `r10.2b/cli-before.json` | 1189518 | `6607c3f9754110165163c9bf835f7af49e462260319c70db8cf214d1a9fc24b9` | gzip | 35422 |
| `r10.2b/cli-final.json` | 1189518 | `8e0c84c9d9d0461f1e9e5acaedc9b509cd8c15d1b119f2ddfa4fad290124d33c` | gzip | 35422 |
| `r10.2b/cli-after.json` | 1189518 | `1f46db28f511c2b098313fd01d7ee5ee4df505651c7698be82f91904db97dbed` | gzip | 35421 |
| `r30.2c/initial-import-measurements.json` | 230445 | `3f6fe1018e3811d0b4fe834cacf72674d13f2cbafaa20ef004dd2adefcdaad6b` | gzip | 23699 |
| `r30.2c/import-measurements.json` | 230735 | `5ed1bde1f13813d56119c3766bc844869de7bb9d48017b16502ec1afb8d5b838` | gzip | 23741 |
| `r20.6/r20.6b-before-inputs.json` | 762140 | `4480d852becdeed2cb569e19e4bd8e549e78e85bc8851e6acbd5adc1b43604f1` | gzip | 142208 |
| `r20.6/r20.6b-after-inputs.json` | 762140 | `4480d852becdeed2cb569e19e4bd8e549e78e85bc8851e6acbd5adc1b43604f1` | gzip | 142208 |
| `l00.06/population.json` | 687882 | `eeab064a40fe13b32460d86559b5315078594e90dcbe4a01977d8e746a3cb900` | gzip | 25063 |
| `r10.6/cli-b0.json` | 1190099 | `b76ed82a349478d1a92c907d92e6f777647f1f3ca9ad669605a344c0d573ffb1` | gzip | 35403 |
| `r10.6/cli-bwork.json` | 1190093 | `558f9dd0d7f8f1d53d5bfb487ad404f1e7d6a3172f1252563b79c55f4fcb7d21` | gzip | 35452 |
| `r10.6/cli-after.json` | 1190093 | `0448e00bdec052414b3e6af6e912a854a1ec8c3a58a6addc05a13b002ba7e28f` | gzip | 35452 |
| `ub20.01/probes.json` | 231896 | `1844615278921c3d3732c7327554247d435374d2dacc6c59bc4bd9e228666c85` | gzip | 9386 |
| `r30.5/work-inputs.json` | 876929 | `f21216995c8f85b565bfec98c67120ec30ffd6a6c18d805aba7536ff73d01896` | gzip | 163569 |
| `r30.5/cost-inputs/seven-io-100.json` | 283982 | `1ebaeecf0db5a3006b447e327952eed749b59b462cd4f665187b54850bdfe6c2` | gzip | 5121 |
| `r30.3/inputs.json` | 761656 | `783bd6c7d74f578dbc181175a3033ee3157262eb8f14dc989b6af1f8ba8f75b6` | gzip | 142066 |
| [`k10.3/initial-state.json.gz`](../k10.3/initial-state.json.gz) | 475206 | `d5ee54bee107a2aba16856f48c297aab2bff6c7498622f88f5b7d7260ee73bdb` | 原位置に保持（例外） | 475206 |
| [`k10.3/source-state.json.gz`](../k10.3/source-state.json.gz) | 301209 | `6bcf00c922975ab666eeb872a64b5b591f56e17837426ae817867dd3d16b84e5` | 原位置に保持（例外） | 301209 |
| `r10.2a/cli-before.json` | 1189518 | `ed3ed6f296d9635cc9e499d10bdb78b79ce406edf4eaa79b26fd8b3518e84cdb` | gzip | 35423 |
| `r10.2a/cli-after.json` | 1189518 | `9251c0d9932c189fb52ac50688bc35da0e24fe739013e9729bb7e88e752b4f51` | gzip | 35424 |
| [`v10.1b/local-evidence.tar.gz`](../v10.1b/local-evidence.tar.gz) | 379850 | `fd90f65327f5213fa179829cb8b73c7c8044322f5a3a812789b106a542bb35e0` | 原位置に保持（例外） | 379850 |
| `r20.3/implementation.patch` | 274165 | `6a8421fb3f4907a6e2da0ca8679be35bbea681fecd946ac73be8457ed68601a8` | gzip | 67798 |

## 読み方と再現

圧縮したJSONは `gzip -dc <記録.json.gz>` で展開し、通常のJSONとして読む。原本のSHA-256は展開後のバイト列に対する値である。元からgzipだった復元3件の原本ハッシュは、元のgzipファイルのバイト列に対する値であり、展開後のJSONやtarの値ではない。再圧縮による二重gzipは行っていない。

過去の台本と manifest は当時のパス・コマンド・原本ハッシュを保持するため変更していない。[台本の候補一覧](large-file-readers.json)で同名を読む可能性を列挙した。元の台本が `.json` を直接読む場合は、読み取り用の一時ディレクトリへ必要な台本と入力を同じ相対配置で写し、`.gz` を元の名前へ展開してから使う。改造内の保管物へ展開して上書きしない。復元3件は上表の元の位置にあり、記録した gzip 自体の SHA-256 が一致することを確認済みである。これは入力の復元方法であり、ビルド・全比較を再実行する許可ではない。台本の内部のパスが固定の場合は、その作業の担当が復元先との対応を先に確認する。

復元3件は公開時の履歴集約後にも原本が残るよう、改造内の元の位置に保存する。過去の控えのブランチだけを原本の所在にしない。機械のスナップショットの採取時点、producer、差分を含む実行状態は現在の再生成で代えられない。元の生成・採取の手順は各親ディレクトリの results.md と台本による。不明な採取方法は不明のままとし、過去の出力と同一になるとは保証しない。

## 同じ内容

`r20.6/r20.6b-before-inputs.json` と `r20.6/r20.6b-after-inputs.json` は原本の SHA-256 が同じである。残る31件は原本のハッシュが互いに異なる。復元3件の大きさと SHA-256 は全件一致し、保存先は上表の原本へのリンクで示した。
