# 報告側の固定入力と独立期待値

期待値は公開契約から独立に定め、実行前に固定した。`handoff.json` とその SHA-256 を正とする。期待値だけの差替えは認めず、相違は入力・理由・後続の判断とともに記録する。実 IO の観測と Rust/Lean の比較は K10 に残す。

既存25入力は報告側の固定入力（K10.2 が比較する群の部分集合）である。R40.3b で check 例を1件追加し、全26入力とした。以下の群はこの一覧では満たさず、K10.2 が実行前に独立入力と期待値を固定する。

- host の one/many、IP の exact/CIDR、v6、ポート範囲、mapped の拒否。
- `Http.checkRequestIn`・`widenRequestIn`・射影、および widen の受理と拒否。
- 旧 Scope の IP と E0459〜E0462、同じ綴りの利用者関数。
- 略記と実ソースの位置、番号付けの停止と最後の Run の超過の区別、内側だけの超過。
- Lean 側の Required の添字・cover・nonTopRanges の独立期待値。

| ファイル | 期待する終了・契約または診断 | SHA-256 |
|---|---|---|
| [pure.bnt](inputs/pure.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `fba7175f66172925e88653ea4f560a154fbe98f575d3de8fe40179f31824f3f1` |
| [top.bnt](inputs/top.bnt) | `0 / {"basis":"declaredUpperBound","expanded":["File.Read"],"bounds":[{"name":"File.Read","scope":{"kind":"all"}}]}` | `bba7188e9219fbfcb9dbe4370ba48b75a6ed4258702f8c3b74cd990410b3a298` |
| [non-top.bnt](inputs/non-top.bnt) | `0 / {"basis":"declaredUpperBound","expanded":["File.Write"],"bounds":[{"name":"File.Write","scope":{"kind":"pathTree","path":"/data"}}]}` | `0343bd5fb6dcaf5c011f018b849cab4fd993213cb520218dd4aba051fccf1a8a` |
| [redundant.bnt](inputs/redundant.bnt) | `0 / {"basis":"declaredUpperBound","expanded":["File.Read"],"bounds":[{"name":"File.Read","scope":{"kind":"all"}},{"name":"File.Read","scope":{"kind":"pathExact","path":"/data/a"}},{"name":"File.Read","scope":{"kind":"pathTree","path":"/data"}}]}` | `a73d2bcbc0f3517d51625bd3d3c2877fcd851b79f336bdb2416459f15ef01382` |
| [handled-user-pure.bnt](inputs/handled-user-pure.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `d32b4806d3bf646a59675f8eb8a415f50c43a9617b8dffbc1d1034a35227570d` |
| [handled-scoped-write.bnt](inputs/handled-scoped-write.bnt) | `0 / {"basis":"declaredUpperBound","expanded":["File.Write"],"bounds":[{"name":"File.Write","scope":{"kind":"pathTree","path":"/data/reports"}}]}` | `7ce419aa27567e5bf8ba2ddb0e93cfae3aa3f234742e2003b14909868372afa5` |
| [not-covered.bnt](inputs/not-covered.bnt) | `2 / E0519 notCovered` | `8c26a0c13384ee7c6458ac5ffe2c4d97fa70ea7caf0c77cd52cd48969e3abf82` |
| [atomic-cover-only.bnt](inputs/atomic-cover-only.bnt) | `2 / E0519 atomicCoverOnly` | `1d6a7ee2041b6df0c3bc3b33100220076804cd70189f3bde89e21324b0000e18` |
| [unknown-source.bnt](inputs/unknown-source.bnt) | `2 / E0519 unknownSource` | `255d418c35c77f668316dfe691f4a2700a35ec1dd3b8ef09268c392b5df39a56` |
| [budget-exceeded.bnt](inputs/budget-exceeded.bnt) | `2 / E0519 budgetExceeded` | `df179321213e83537d23dbcfbe527d506afb3727cdc57dcd26ac3af9dd441b6d` |
| [show-rejected.bnt](inputs/show-rejected.bnt) | `2 / E0705` | `28ea2c356b673ff4a36207b760810ccc5425416847336ad77a835518bde177f2` |
| [projection-repaired.bnt](inputs/projection-repaired.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `07843877ccb33e11dfa2996233efd9d579c41830b9504e91f284b05e0c090dc4` |
| [show-match.bnt](inputs/show-match.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `563e1c4d0a383985a4b864eba5ccadb276b128e3e9408abe51c44b7f69993c75` |
| [user-unhandled.bnt](inputs/user-unhandled.bnt) | `2 / E0506` | `70823dee85360a5d7b5c3dbc56cdb8a93f52d4be5081904c6faaf3fe2d928304` |
| [user-scope-rejected.bnt](inputs/user-scope-rejected.bnt) | `2 / E0513` | `435de74f27370ddb13c23e69433b6cb9c99d116cc031b2b2dd88a765a9af2d4a` |
| [read-complete.bnt](inputs/read-complete.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `367811c7bf54d02a74011fa0366b9b3388153883f141acd0f4544386d76aded3` |
| [read-partial.bnt](inputs/read-partial.bnt) | `0 / {"basis":"declaredUpperBound","expanded":["File.Read"],"bounds":[{"name":"File.Read","scope":{"kind":"pathTree","path":"/data"}}]}` | `297d096b4174401f069cfb804c0c9adf1207824b60f020742716670573dfae71` |
| [read-missing-upper.bnt](inputs/read-missing-upper.bnt) | `2 / E0501` | `5101647cc7b4d2d76a62000ea5bd39a7b47ea0ebc78a0eb3f4df72350f21402e` |
| [write-complete.bnt](inputs/write-complete.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `ce90e9d7905f50a2be301e43e0f183cfafb8bb6dfb51c771defeda746c4feb45` |
| [write-partial.bnt](inputs/write-partial.bnt) | `0 / {"basis":"declaredUpperBound","expanded":["File.Write"],"bounds":[{"name":"File.Write","scope":{"kind":"pathTree","path":"/data"}}]}` | `ff0a9bbf9e32dcfbd839ebc4aa2d039809830901295c26314f0b79bd97e87df9` |
| [write-missing-upper.bnt](inputs/write-missing-upper.bnt) | `2 / E0501` | `f1b61e51b3480ca7af98c60208ed759e1e03dca30736083cfcd277f8cd92a2bf` |
| [connect-complete.bnt](inputs/connect-complete.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `2f01a8a351b76b2f804dcb4f244ce5eb790eb86996b715301cf9b88345c194f8` |
| [connect-partial.bnt](inputs/connect-partial.bnt) | `0 / {"basis":"declaredUpperBound","expanded":["Http.Connect"],"bounds":[{"name":"Http.Connect","scope":{"kind":"endpoint","host":{"kind":"exact","name":"api.example"},"ports":{"minimum":443,"maximum":443}}}]}` | `4b6d9c5b5378e85f95289d020c204623d3ad4b8fee16b7fdd6295bb602fef3e3` |
| [connect-missing-upper.bnt](inputs/connect-missing-upper.bnt) | `2 / E0501` | `f7806e1a8b236c967c004ec375fcd9383f6c50792009ff3421564c0a6e4bbac7` |
| [doc-error.bnt](inputs/doc-error.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]}` | `9f7b2393783c281e346db87f25f0722a1e31e2066ed42bc5cefe0b6c7b77daca` |
| [doc-check.bnt](inputs/doc-check.bnt) | `0 / {"basis":"declaredUpperBound","expanded":[],"bounds":[]} / tests: []` | `07044f3856fb4a29cc03e87a323ce94b9add869b00c2e2497393a1b49825c982` |
