# 大きな保存物の同定

200 KiB（204,800 bytes）を超えるため本文を写さなかった記録である。元の内容は読み取り専用で照合した。パスはリポジトリの根からの相対位置であり、恒久保管先を意味しない。台本6件と小さいログ・報告は [saved-files.json](saved-files.json) に写し元と写し先のハッシュを分けて記した。

| 元のパス | bytes | SHA-256 |
|---|---:|---|
| `target/v10.1d-logs/cited.json` | 802915 | `b3b772512e49b8d3fb89116ae8e35030b0a4b2b295d63dfa7d0556e3760b7bcd` |
| `target/v10.1d-logs/compare.json` | 637539 | `59dd9f534d4e16b19be0c0e5c5c3d32008b8a0bc9bff9037befea915fd8e814c` |
| `target/desugar-diff/v10.1d/builtin-report.json` | 524565 | `ba061d3150f0afddec23433ee80922bdfb69be18f98017a1c5c673acd61d583c` |
| `target/desugar-diff/v10.1d/surface-check/report.json` | 13308347 | `67c0eeba03b40042b8b00dd63db70b2cdea83e95670d38800c9d35015d8ee10b` |
| `target/desugar-diff/v10.1d/named-programs-corpus.json` | 343291355 | `5bff0451e759527428e8aef0eae4052324c95a6e547de408075ff2abf4522321` |
| `target/desugar-diff/v10.1d/named-programs-builtins.json` | 96997515 | `9b204273fca502c96bb1eb50ec6a96b5f661fd4a687d952320c89188812d7304` |
| `target/desugar-diff/v10.1d/named-programs-stdlib.json` | 3789926 | `97db6a9d03d1e46eda18fb4939374592cc0826f4f821460538ef7a2ff41334fb` |
| `target/desugar-diff/v10.1d/named-programs-coverage.json` | 8173401 | `43e6d051d15f1b3510bdcc9c154dc1350e378b23d5d8d42b2f78bb0b4245102b` |
| `target/coverage-diff/v10.1d/future-report.json` | 8923154 | `2a572cdcc4081771e69a4f9f833c2318d72e3f1654c383cd1a2fa81f8430f88d` |
| `target/interval-diff/v10.1d/input-manifest.json` | 276948 | `106815c6322d0abbc8de0a6c26fc0d0d91b6f88b0f6eeae8c4b9003b01154dfc` |
| `target/interval-diff/v10.1d/manifest.json` | 2243167 | `7d46994a68d7c514e7f3d55a1e4b63e2a1e02ebb7936c85058de0ee5ff83ef56` |

出力全体のファイル一覧・件数・個別の大きさと SHA-256 は上記の最終 manifest にある。再生成する場合のコマンドは [phase-a.sh](phase-a.sh)・[phase-b1.sh](phase-b1.sh)・[phase-b2.sh](phase-b2.sh)、旧新の合成と引用の方法は [compare.py](compare.py)・[cite.py](cite.py) に残した。本記録作業ではこれらを起動していない。
