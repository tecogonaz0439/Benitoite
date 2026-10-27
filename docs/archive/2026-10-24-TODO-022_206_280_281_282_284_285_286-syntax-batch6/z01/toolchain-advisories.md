# ツールチェーンの勧告の照合（公開候補 0.0.12）

担当: Claude Code のサブエージェント（Opus 5.5、取りまとめが依頼）。取りまとめが受け入れた。

## 照合の概要

- 照合の開始は 2026-10-27 11:06 JST（02:06Z）、終了は 11:15 JST（02:15Z）である。以下の時刻は取得した時点の UTC で記す。
- リポジトリは読むだけとし、書き換えていない。読んだのは `rust-toolchain.toml`（`channel = "1.98.1"`）、`formal/lean-toolchain`（`leanprover/lean4:v4.34.1`）、`formal/lakefile.toml`、`formal/lake-manifest.json`（`"packages": []`）、`.cargo/config.toml`、両 `Cargo.lock` の `source` 行、`deny.toml`、`scripts/fuzz-short.sh`。
- 候補の版は依頼の値（2026-10-27 に取りまとめが確認した実行版）を使った。手元で `rustc`・`cargo`・`lean`・`elan` は実行していない。上流のタグとコミットを次のように照らし、依頼の値と一致することを確かめた。
  - rust-lang/rust のタグ `1.98.1` は commit `48a229ceaefd…` を指す（`rustc 1.98.1 (48a229cea …)` と一致）。
  - rust-lang/cargo の commit `797e8a9bca27…`（2026-08-05、`[beta 1.98] …`）の `Cargo.toml` では、cargo の crate の版は `0.99.0` である。
  - leanprover/lean4 のタグ `v4.34.1` は commit `5045d0056413266e…` を指す（`lean --version` の commit と一致）。
  - leanprover/elan のタグ `v4.2.4` は commit `227caca13372…` を指す（`elan 4.2.4 (227caca13 …)` と一致）。
- 取得には curl を使った。`gh` は手元になかったので、GitHub の公開 API を認証なしで呼んだ。取得した資料の写しは作業用の一時領域に置き、リポジトリには入れていない（上の URL と取得時刻で取り直せる）。
- ツールチェーンを網羅的に照合するのは今回が初めてである。2026-10-24 の最初の照合（P2）はツールチェーンを網羅していないため、差分の比較はしていない。

## Rust（rustc 1.98.1、aarch64-apple-darwin）

### 確認した資料

| 資料 | URL | 取得（UTC） |
|---|---|---|
| rust-lang/rust のリポジトリの勧告（API） | https://api.github.com/repos/rust-lang/rust/security-advisories （画面は https://github.com/rust-lang/rust/security/advisories ） | 2026-10-27T02:06:56Z |
| Rust のブログ（一覧と feed） | https://blog.rust-lang.org/ 、https://blog.rust-lang.org/feed.xml | 2026-10-27T02:11:51Z |
| Rust 1.98.1 の告知 | https://blog.rust-lang.org/2026/09/03/Rust-1.98.1/ | 2026-10-27T02:11:51Z |
| Rust 1.99.0 と 1.99.1 の告知 | https://blog.rust-lang.org/2026/10/01/Rust-1.99.0/ 、https://blog.rust-lang.org/2026/10/15/Rust-1.99.1/ | 2026-10-27T02:12:22Z |
| Miri の告知 | https://blog.rust-lang.org/2026/09/21/github-actions-leaking-secrets-when-miri-output-is-cached/ | 2026-10-27T02:11:51Z |
| CVE-2025-11233 の記録 | https://www.cve.org/CVERecord?id=CVE-2025-11233 （API: https://cveawg.mitre.org/api/cve/CVE-2025-11233 ） | 2026-10-27T02:07:09Z |
| NVD のキーワード検索（`rust-lang`・`rustc compiler`・`Rust standard library`） | https://services.nvd.nist.gov/rest/json/cves/2.0 | 2026-10-27T02:09:14Z、02:13:07Z |

### 見つかった勧告

rust-lang/rust のリポジトリの勧告は 6 件である。どの勧告も、影響する版の上限が 1.98.1 より前にある。

| ID | 影響箇所 | 影響する版 | 修正版 |
|---|---|---|---|
| GHSA-rv9c-3mvf-cw9h / CVE-2025-11233 | std の Path。tier 3 の Cygwin の対象だけ | 1.87.0 以上 1.89.0 未満 | 1.89.0 |
| GHSA-2xg3-7mm6-98jj / CVE-2024-43402 | std::process::Command。Windows のバッチファイル | 1.81.0 未満 | 1.81.0 |
| GHSA-q455-m56c-85mh / CVE-2024-24576 | 同上 | 1.77.2 未満 | 1.77.2 |
| GHSA-r9cc-f5pr-p3j2 / CVE-2022-21658 | std::fs::remove_dir_all | 1.58.0 以下 | 1.58.1 |
| GHSA-rcv6-wg5m-24v6 / CVE-2021-42574 | rustc。双方向の上書きの符号位置 | 1.56.0 以下 | 1.56.1 |
| GHSA-phjm-8x66-qw4r / CVE-2019-16760 | Cargo の依存の取得（Rust 1.26.0 より前） | 1.25.0 以下 | 1.26.0 |

ブログの一覧にあるセキュリティの告知で rustc と std にかかるものは、上の表を超えない。Cargo の告知は次節で扱う。NVD の検索でも、rustc と std の新しい CVE は見つからなかった。検索の結果に出た CVE（RustCrypto の cmov、Linux カーネルの Rust の arm64 の設定、jsonwebtoken）は、どれもツールチェーンの勧告ではない。

勧告ではないが、照合の途中で次の告知を読んだ。

- Rust 1.98.1 は、1.98.0 の vtable の誤コンパイル（null の関数ポインタ）を直した点版である。候補はこの修正を含む版である。
- Rust 1.99.1（2026-10-15）は、以前の版からの退行を三つ直した。x86_64 での FFI の bool の戻り値の誤コンパイル、一部の対象の `wcslen` の欠落、rustup の proxy を介さないと macOS で rust-lld が libLLVM を読み込めない問題である。どれも CVE と勧告の付かない不具合の修正である。1.98.1 がどれに該当するかは告知に書かれておらず、判定していない。
- 2026-09-21 の Miri の告知によれば、`cargo miri` は環境変数を `target/` に保存する。そのため、GitHub Actions で `target/` を cache すると秘密が漏れうる。このリポジトリには `.github/` がなく、Miri は `scripts/check-heap.sh` から nightly で手元で実行するだけである。告知が示す漏洩の経路（CI の cache）はこのプロジェクトにない。ただし nightly の版は候補の範囲の外なので、照合していない。

### 判定

**対象外**である。根拠は次の二つである。

- 見つかった勧告は、どれも影響する版が 1.89.0 より前である。
- 影響の箇所（Cygwin の対象、Windows のバッチファイル）は、このプロジェクトのビルドとテストの構成（aarch64-apple-darwin）とも重ならない。

処理系はソースだけを配布する。std の勧告の影響を受けうるのは、利用者が自分でビルドした実行ファイルである。その場合の Rust の版は、`rust-toolchain.toml` の 1.98.1 になる。

未照合の範囲は三つある。

- fuzz と `check-heap.sh` が使う nightly の Rust と Miri の版を照合していない。
- rustup の版を照合していない。rustup 1.29.2 の告知（2026-10-20）は、依存の rustls-webpki と webpki-root-certs を CVE-2026-111943 と RUSTSEC-2026-0382 のために更新したと述べる。rustup は依頼の四つの対象に入らず、その CVE の記録も取得していない。
- 1.99.1 で直した退行のうち、1.98.1 がどれに該当するかを判定していない。

## Cargo（cargo 1.98.1、crate の版 0.99.0）

### 確認した資料

| 資料 | URL | 取得（UTC） |
|---|---|---|
| rust-lang/cargo のリポジトリの勧告（API と個別の本文） | https://api.github.com/repos/rust-lang/cargo/security-advisories （画面は https://github.com/rust-lang/cargo/security/advisories ） | 2026-10-27T02:06:57Z、02:12:36Z |
| CVE-2026-5222 の記録 | https://www.cve.org/CVERecord?id=CVE-2026-5222 | 2026-10-27T02:07:07Z |
| CVE-2026-5223 の記録 | https://www.cve.org/CVERecord?id=CVE-2026-5223 | 2026-10-27T02:07:08Z |
| CVE-2026-33056 の記録と Rust の告知 | https://www.cve.org/CVERecord?id=CVE-2026-33056 、https://blog.rust-lang.org/2026/03/21/cve-2026-33056/ | 2026-10-27T02:12:22Z |
| CVE-2026-5222 と 5223 の告知 | https://blog.rust-lang.org/2026/05/25/cve-2026-5222/ 、https://blog.rust-lang.org/2026/05/25/cve-2026-5223/ （CVE の記録の参照先。一覧に載ることを確かめた） | 2026-10-27T02:11:51Z |
| cargo の commit 797e8a9bc の `Cargo.toml` と `Cargo.lock` | https://raw.githubusercontent.com/rust-lang/cargo/797e8a9bc/Cargo.toml 、同 `/Cargo.lock` | 2026-10-27T02:12:36Z |

### 見つかった勧告

GHSA の範囲は cargo の crate の版で書かれている。対応する Rust の版は CVE の記録による。

| ID | 影響箇所 | 影響する版 | 修正版 |
|---|---|---|---|
| GHSA-p688-r7jv-fm6f / CVE-2026-5222 | 第三者の登録簿の sparse index の URL の正規化。登録簿の間で資格情報を共有してしまう | Cargo 1.68.0 以上 1.96.0 未満（crate 0.97.0 未満） | Rust 1.96.0（crate 0.97.0） |
| GHSA-jq42-7mfv-hm57 / CVE-2026-5223 | 第三者の登録簿の crate の tarball の symlink。他の crate の cache を上書きする。crates.io の利用者は影響を受けない | Cargo 1.0.0 以上 1.96.0 未満（crate 0.97.0 未満） | Rust 1.96.0（crate 0.97.0） |
| CVE-2026-33056（tar crate、GHSA-j4xf-2g29-59ph） | Cargo が使う tar の展開。symlink を辿り、任意のディレクトリの権限を変える | tar 0.4.45 未満 | tar 0.4.45。Cargo は Rust 1.94.1 で更新 |
| GHSA-wrrj-h57r-vx9p / CVE-2023-40030 | timing の報告への JavaScript の注入 | 1.60.0 以上 1.72 未満 | 1.72 |
| GHSA-j3xp-wfr4-hx87 / CVE-2023-38497 | crate の展開で umask を守らない | crate 0.72.1 以下 | 0.72.2 |
| GHSA-r5w3-xm58-jv6j / CVE-2022-46176 | SSH のホスト鍵を検証しない | crate 0.67.0 以下 | 0.67.1 |
| GHSA-rfj2-q3h3-hm5j / CVE-2022-36113 | 悪意のある crate の展開で任意のファイルを壊す | crate 0.65.0 未満 | 0.65.0 |
| GHSA-2hvr-h6gw-qrxp / CVE-2022-36114 | 悪意のある crate の展開でファイルシステムを埋める | crate 0.65.0 未満 | 0.65.0 |

### 判定

**対象外**である。根拠は次の三つである。

- 候補の Cargo 1.98.1 の crate の版は 0.99.0 であり、最も新しい 2026 年の二件の修正版 0.97.0（Rust 1.96.0）より新しい。
- 同じ commit の `Cargo.lock` は tar 0.4.46 を固定している。これは CVE-2026-33056 の修正版 0.4.45 以上である。
- そのほかの勧告も、影響する版が Rust 1.72 より前である。

このプロジェクトでの使い方も、影響の前提と重ならない。両 `Cargo.lock` の依存はすべて `registry+https://github.com/rust-lang/crates.io-index` から取得しており（404 行）、第三者の登録簿を使わない。CVE-2026-5222、5223、33056 は、どれも第三者の登録簿か悪意のある crate を前提とする。未照合の範囲は、nightly の Cargo（fuzz の `cargo +nightly fuzz`）の版である。

## Lean（leanprover/lean4:v4.34.1、commit 5045d005）

### 確認した資料

| 資料 | URL | 取得（UTC） |
|---|---|---|
| leanprover/lean4 のリポジトリの勧告（API） | https://api.github.com/repos/leanprover/lean4/security-advisories （画面は https://github.com/leanprover/lean4/security/advisories ） | 2026-10-27T02:06:57Z |
| CVE-2026-72844 の記録 | https://www.cve.org/CVERecord?id=CVE-2026-72844 （API: https://cveawg.mitre.org/api/cve/CVE-2026-72844 。記録の更新日は 2026-10-26） | 2026-10-27T02:07:06Z |
| CVE-2026-72844 の上流の issue と修正の PR | https://github.com/leanprover/lean4/issues/14576 、https://github.com/leanprover/lean4/pull/14577 （merge commit `a39eab69e1ee…`） | 2026-10-27T02:07:30Z |
| oss-security の告知（2 件） | https://www.openwall.com/lists/oss-security/2026/08/02/1 、https://www.openwall.com/lists/oss-security/2026/10/26/2 | 2026-10-27T02:07 頃 |
| CVE-2026-72711 の記録 | https://www.cve.org/CVERecord?id=CVE-2026-72711 | 2026-10-27T02:09:54Z |
| CVE-2026-72711 の上流の issue と修正の PR と告知 | https://github.com/leanprover/lean4/issues/14484 、https://github.com/leanprover/lean4/pull/14498 （merge commit `7346219967…`）、https://www.openwall.com/lists/oss-security/2026/10/26/3 | 2026-10-27T02:10:02Z |
| 公式のリリースの一覧（最新 40 件）と版の間の commit の比較 | https://api.github.com/repos/leanprover/lean4/releases 、`compare/<base>...<head>` | 2026-10-27T02:07:58Z〜02:11:20Z |
| 健全性（soundness）の修正の PR と未解決の issue の検索 | https://api.github.com/search/issues | 2026-10-27T02:10:52Z、02:14:02Z |
| NVD のキーワード検索（`leanprover`・`Lean 4`・`Lean theorem prover`） | https://services.nvd.nist.gov/rest/json/cves/2.0 | 2026-10-27T02:09:14Z、02:13:07Z |

公式のリリースの記録の本文は、どの版も release notes（例: https://lean-lang.org/doc/reference/latest/releases/v4.34.1/ ）への一文のリンクだけだった。release notes の頁は取得していない。修正が入ったかどうかは、git の commit の祖先の関係で確かめた。

### 見つかった勧告

leanprover/lean4 のリポジトリの勧告は 0 件である。CVE の記録には、カーネルの勧告が 2 件ある。

**CVE-2026-72844**（CNA: VulnCheck、CWE-843、CVSS 3.1 は 6.3）

- 影響箇所: カーネルの型検査である。射影の式が名指しする構造と、射影される値の型の一致を確かめていなかった。加えて、`environment::add_inductive`（`src/kernel/inductive.cpp`）が、入れ子の帰納型の適用のパラメータの引数を検査しなかった。このため、プロセスの中で動くメタプログラムが、公理なしの `False` の証明をカーネルに受理させられる。悪用には、悪意のあるメタプログラムをプロセスの中で実行することが要る（例: 悪意のある Lake の依存をビルドする・import する）。
- 影響する版（記録の `affected`）: `0` 以上 `4.32.2` 未満は affected、`4.32.2` は unaffected、`4.33.0-rc1` は affected。`defaultStatus` は unaffected である。2026-10-25 の oss-security の告知は、影響を「v4.31.0 以下と 2026-07-27 以前の nightly」、修正を「2026-07-29 以降の nightly と v4.32.2」と書く。
- 上流の修正: PR #14577（`fix: missing check at kernel inductive declaration`、2026-07-28 に master へ取り込み、commit `a39eab69`）。
- v4.34.1 との照合: `compare/a39eab69…...v4.34.1` は `ahead 102, behind 0` であり、修正の commit は v4.34.1 の祖先である。v4.32.2 と v4.33.0 は `diverged` であり、別の commit として backport した形になる。
- 関連の修正 #14616（カーネルが作る `_nested` の補助の型を名指す宣言を拒む）と #14621（入れ子の帰納型の宣言の再検査）も、v4.34.1 の祖先にある（`behind 0`）。

**CVE-2026-72711**（CNA: VulnCheck）

- 影響箇所: カーネルの `environment::add_opaque` である。opaque の宣言の本体に、束縛されない自由変数が残っていないかを確かめていなかった。このため、型検査器の推論の cache を汚すメタプログラムが、型 `False` の opaque の定数を受理させられる。
- 影響する版: `0` 以上 `4.32.2` 未満。告知の修正版は v4.32.2、v4.33.0、2026-07-23 以降の nightly である。
- 上流の修正: PR #14498（`fix: kernel to check opaque values for fvars`、2026-07-22、commit `7346219967…`）。v4.32.1 にも backport（`ab7de84bc1`）が入っているが、記録は「4.32.2 で修正」と書く。この食い違いは v4.34.1 の判定には関わらない。
- v4.34.1 との照合: `compare/7346219…...v4.34.1` は `ahead 158, behind 0` であり、修正は v4.34.1 の祖先である。

**CVE のない健全性の修正**（参考）。v4.34.0-rc1 から v4.34.1 までの安定版の分岐には、次の修正が backport として入っている。

- カーネル: #14806（`is_def_eq` の cache の順序への依存）、#14807 と #14843（`is_prop` が sort を要求する）、#14808（生成した再帰子の型検査）、#14582（宣言する型の出現の一様性）、#14849（`Nat` の数値の大きさの上限）。
- ランタイムの参照の計数: #14838（あふれたときに凍結する）、#15241（凍結した計数を連鎖の解放で保つ）、#15288（あふれた対象を他のスレッドと共有するときに子に印を付ける）、#15307（#15289 の backport）。

この分岐を最後に更新したのは 2026-09-24（v4.34.1）である。それより後に master へ入った健全性の修正は、キーワードの検索（`soundness`、`proof of False`、`kernel`）では見つからなかった。新しい安定版 v4.35.0（2026-10-12）があるが、それを求める勧告は見つかっていない。

検索で見つかった未解決の issue のうち、健全性に関わるものは次のとおりである。勧告や CVE は付いていない。

- #15717: `ST.Ref` の定義で、`BaseIO` の中の任意の二つの `Type` の間の安全でない cast ができる。
- #12746: `proj_idx` の切り詰め。
- #7463: `@[csimp]` で公理と `unsafe` を証明へ持ち込める。
- #10760: section の変数の可視性の検証。

NVD の検索では、ほかに CVE-2026-32732 が見つかった。これは Lean 4 の VS Code 拡張の XSS であり、ツールチェーンの勧告ではない。

### 判定

**対象外**である。根拠は次の三つである。

- CVE-2026-72844 の影響する版は 4.32.2 未満と 4.33.0-rc1 であり、v4.34.1 は記録の影響範囲に入らない。上流の修正の commit `a39eab69` も v4.34.1 の祖先にある。
- CVE-2026-72711 の影響する版は 4.32.2 未満であり、修正の commit `7346219` は v4.34.1 の祖先にある。
- 上記の CVE のない健全性の修正も、v4.34.1 に入っている。

このプロジェクトでの使い方からも、影響は小さい。Lean は形式検証の証明の検査にだけ使い、処理系に含めない。`formal/lake-manifest.json` に Lake の依存はない（`"packages": []`）。二つの CVE は悪意のあるメタプログラムを前提とするが、このプロジェクトで実行するメタプログラムは自前の `formal/` だけである。

未照合の範囲は三つある。

- release notes の頁を取得していない。
- 2026-09-24 より後の健全性の修正の有無は、キーワードの検索の範囲でしか確かめていない。
- 未解決の issue（#15717 など）が、このプロジェクトの定理に関わるかを評価していない。

## elan（elan 4.2.4、commit 227caca1）

### 確認した資料

| 資料 | URL | 取得（UTC） |
|---|---|---|
| leanprover/elan のリポジトリの勧告（API） | https://api.github.com/repos/leanprover/elan/security-advisories （画面は https://github.com/leanprover/elan/security/advisories ） | 2026-10-27T02:06:58Z |
| 公式のリリースの一覧（最新 8 件） | https://api.github.com/repos/leanprover/elan/releases | 2026-10-27T02:11:20Z |
| 変更履歴 | https://raw.githubusercontent.com/leanprover/elan/master/CHANGELOG.md | 2026-10-27T02:11:40Z |
| v4.2.4 より後の commit | https://api.github.com/repos/leanprover/elan/compare/v4.2.4...master | 2026-10-27T02:11:40Z |
| 2026-06-01 以降に取り込んだ PR と、security の issue の検索 | https://api.github.com/search/issues | 2026-10-27T02:10:52Z、02:14:02Z |
| NVD のキーワード検索（`leanprover/elan`・`elan toolchain`・`Lean toolchain manager`） | https://services.nvd.nist.gov/rest/json/cves/2.0 | 2026-10-27T02:09:14Z、02:13:07Z |

### 見つかった勧告

勧告は見つからなかった。

- リポジトリの勧告は 0 件だった。
- NVD の検索は 0 件、security を含む issue の検索も 0 件だった。
- リリースの記録の本文は空である。変更履歴の 4.2.4（2026-08-25）は、導入済みの toolchain での終了状態 0 と、`elan toolchain gc` の panic の修正だけを記す。4.2.0〜4.2.3 にもセキュリティの修正の記述はない。
- v4.2.4 より後の commit は二つあり、release index の圧縮（#209）と Windows の表示の修正（#212）である。
- 2026-06 以降の PR のうち、#205（`zip = "7.2.0"`、2026-07-16）は yank された crate の問題への対処である。v4.2.4 はこれより後の版である。

### 判定

**対象外**である。根拠は、確認した範囲で elan 自体の勧告が 0 件であることである。このプロジェクトでは、elan を Lean の導入にだけ使う。

未照合の範囲は二つある。

- elan の Rust の依存（zip など）を RustSec の勧告と照合していない。
- 認証なしの API で見えるのは、公開済みのリポジトリの勧告だけである。

## 照合の限界（共通）

- GitHub の `security-advisories` の API が返すのは、公開済みのリポジトリの勧告だけである。非公開の草案と、GitHub Advisory Database の全体（他のリポジトリが報告した勧告）は含まない。
- NVD と GitHub の issue の検索はキーワードで行った。検索に一致しない記録や、結果の上限を超えた記録を見落としうる。カーネルの検索は全 82 件のうち 60 件だけを見た。
- 手元の実行版の `--version` は、依頼の値で照らした。この照合では実行していない。
