# work/ の記録の写し

改造の文書が出どころとして引いていた `work/` の下の記録を、取りまとめが 2026-10-30 にここへ写した（H28）。`work/` は永久の保管場所ではないので、保管の後はこの写しを引く。文字の記録は手元の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せて写し、伏せた場合は写しの SHA-256 を別に記した。200 KiB を超える機械の記録は gzip で圧縮し、圧縮しても超えるものと第三者の文書（Web ページの HTML、ライブラリのソースと README）は写さず、大きさと原本の SHA-256 だけを残した。論文の PDF の5件は、設計者の指示（2026-10-30）で 200 KiB の決まりの例外としてそのまま写した。論文の利用の許諾（再配布の可否）は確かめていない（PDF の中から読み取れた許諾の表示は書体のものだけだった）。一覧の機械の記録は [index.json](index.json)、写しへのリンクの付け替えは [h28-relink-by-coordinator.json](../../v10.3d/h28-relink-by-coordinator.json) にある。

## 写さなかったもの

| 元のパス | bytes | SHA-256 | 理由 |
|---|---:|---|---|
| `work/m013/scratch/P1b/start.json` | 2011817 | `7f320acbd0e1f50adcbca5c41d8f45eae8d56b4643346b6ab134bb2cb3415877` | 圧縮しても 200 KiB を超えるので写さない |
| `work/m013/scratch/S1/effectful-dynamic.hs` | 43596 | `e70a0337dbc9ff2f64d754c728a9791298ac184918c29202afc45be8cf370721` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/effectful-exception.hs` | 17183 | `d1518cf4c3acf11ce1a14576aae74fe42333eb8f12f649ce64d2bb8834f6e4b8` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/effectful-reader.hs` | 2122 | `a8017aff86351c7d9745cf4463fe806a1f1df20b2f9e2fe5afede970afd78c9b` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/fused-catch.hs` | 1188 | `05d12506a42710868db979354fb4071d89695b9353f93c1bb7da6d7ea26735ab` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/fused-exception.hs` | 6268 | `d80dac42338045e3ca822ca5960c68ccabdb1c21a67debb918b9235fb4b1ab4d` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/fused-exceptions-readme.md` | 2135 | `3360063d05ff39c76927b7d4cc756711f4b82c59af2200e1b09ec46435a3158e` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/fused-exceptions-tree.json` | 4752 | `5e51ff4d75b17d7526dc09a18379eea081fea178eaa31f7d8211b8c3340a4fef` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/fused-reader.hs` | 1402 | `7bf05b3bf5d272e112393f903619087174f94539abca1c0fb60160de70ca1476` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/fused-readme.md` | 22621 | `50f6173505396f8b4c119144e8e13f6528749d3adb26ab2e327b2ed304dec622` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/heftia-core.html` | 358768 | `94c025907053b9fe86158803e978197ad856f138d9bf2384f9e046deee71b1a6` | 第三者の文書なので写さない |
| `work/m013/scratch/S1/heftia-reader.html` | 2542 | `ce4a81d3eff4d0a02fa986a22055fcf65be53b0a563dee4156aca8f64ed1586f` | 第三者の文書なので写さない |
| `work/m013/scratch/S1/heftia-readme.md` | 29047 | `87ccf963334021138a2db43b4d330fb592fd8ed7bbddeae2e12c758edeefc568` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/heftia-unlift.html` | 19199 | `be0b16921da58357a8a495399e0ccf92db374dc23adba836091e13cb3802ca66` | 第三者の文書なので写さない |
| `work/m013/scratch/S1/koka-tour.md` | 73800 | `6939f84d633921848e5f40459f2eaf6a00773c3b3575003ece986507b259653f` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/polysemy-error.hs` | 10027 | `e0a82256918d02f9f3e1bdd23abff4be770700f96e34d95102fb1b126ed91699` | 第三者のライブラリのソースと文書なので写さない |
| `work/m013/scratch/S1/polysemy-nondet.hs` | 4028 | `28bb94d398391295af50f0a7367457808130b6fed83c118306fcd764137d4f49` | 第三者のライブラリのソースと文書なので写さない |
| `work/scratch/IF10.04/dry-run.json` | — | — | 2026-10-30 の時点で work/ に残っていない |
| `work/scratch/IF10.05/dry-run.json` | — | — | 2026-10-30 の時点で work/ に残っていない |
| `work/scratch/IF10.06/dry-run.json` | — | — | 2026-10-30 の時点で work/ に残っていない |
| `work/scratch/IF10.07/dry-run.json` | — | — | 2026-10-30 の時点で work/ に残っていない |
| `work/scratch/IF10.08/dry-run.json` | — | — | 2026-10-30 の時点で work/ に残っていない |

写したファイルは 137 件である（一覧は index.json）。写しの文書の中の相対リンクは、当時の置き場所を基準にした原文のままである。ただし、`m013/spikes/SF/findings.md` の docs/todo へのリンクだけは文字の参照へ直した（RV-V10.3 軽3、V10.3db）。
