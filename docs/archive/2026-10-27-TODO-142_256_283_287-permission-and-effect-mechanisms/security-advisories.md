# 0.0.13 のセキュリティの勧告の照合

AGENTS.md「改造の進め方」の手順 2 とスキル security-advisories に従い、改造の最初に、ワークスペースと fuzz の依存、および Rust・Cargo・Lean・elan の固定版を勧告と照合した。照合と記録は取りまとめが行った。

## 入力

| 項目 | 値 |
|---|---|
| 照合の日時 | 2026-10-27 14:33〜14:45（+0900） |
| HEAD | `d0678ddb7e82da77715ea2e01ef974d06d41814b`（v0.0.12）。未コミットの差分は、この改造のディレクトリ（未追跡）だけで、manifest・lock・設定は HEAD のまま |
| `Cargo.toml` | `a5eaf5d181e3bfc169e2c8e632b56bd71b943c08366bb4e2bbc858ce40269dec` |
| `Cargo.lock`（前後一致） | `56231868e475eec4710ffcf2bda766a377facebddee5d6b646f4df3824161fc5` |
| `fuzz/Cargo.toml` | `d8045b5ce1533133739c8b3e53c09c7d88fb0f7ce8252f5640028a73d14a16e2` |
| `fuzz/Cargo.lock`（前後一致） | `b4a6253aa895fae5f2ddaa391630f8b57be24b2615af9b1452ed19d14e872a5d` |
| `deny.toml` | `be3a44ae7ba8be1804238592020094f8c49b5e9e9ed2fc0f625d6d72f5ab5d31`（db-path の写しは使っていない） |
| `rust-toolchain.toml` | `channel = "1.98.1"`（SHA-256 `4d7d5425fe623392e565a964fc135c563c316ce125058199eb40b2953ba6ecbb`） |
| `formal/lean-toolchain` | `leanprover/lean4:v4.34.1`（SHA-256 `d5edba4e4b8faad9c1baeadb265716d20d03be4d1a2647dc5e35b0c0325bea7b`） |

対象構成は `deny.toml` の aarch64-apple-darwin・x86_64-unknown-linux-musl・aarch64-unknown-linux-musl、機能は既存の manifest の選択である。ignore はない。

## ワークスペースと fuzz の依存

`python3 -B scripts/check/advisories.py` で照合した。cargo-deny 0.20.2。二つのコマンドは `cargo deny --format json --log-level debug --manifest-path <manifest> --config deny.toml --locked check advisories`（manifest は `Cargo.toml` と `fuzz/Cargo.toml`）。

| 対象 | DB の取得（UTC） | DB のコミット | 状態・生の終了 |
|---|---|---|---|
| ワークスペース | 2026-10-27T05:33:13.730036Z | `3279c99911354c400e1d41e47c7d60e39258b147` | 照合済み・検出0件、ID なし、生の終了0 |
| fuzz | 2026-10-27T05:33:15.365476Z | `3279c99911354c400e1d41e47c7d60e39258b147` | 照合済み・検出0件、ID なし、生の終了0 |

表示単位の終了は0。両対象とも照合を終えて検出0件なので、依存全体を検出0件とする。取得不能を0件へ読み替えたものではない。生の出力・設定の写し・対象別の結果は [advisories/report.json](advisories/report.json) と同じディレクトリに保存した（手元のパスは実行器が `<repo>`・`<home>`・`<tmp>` に置き換えた。設定の SHA-256 は置換前の値）。

0.0.12 の公開候補の照合（同じ日の 02:43 UTC、同じ DB のコミット・同じ lock）との差はない。

## Rust・Cargo・Lean・elan

候補の版は、固定版と手元の実行版で確かめた。Lean と elan は、この改造ではまだ Lean 担当から候補の版を受け取っていないので、固定版と手元の実行版で照合した。

| 対象 | 版 | 確かめた一次資料（2026-10-27 14:40 頃 +0900） | 結論 |
|---|---|---|---|
| Rust | `rustc 1.98.1 (48a229cea 2026-09-01)`、aarch64-apple-darwin | [rust-lang/rust の勧告](https://github.com/rust-lang/rust/security/advisories)（6件、最新は 2025-10-01）、[Rust の告知](https://blog.rust-lang.org/)（10-26 までの10件） | 対象外。新しい勧告はない。2026-10-15 の Rust 1.99.1 は三つの回帰の修正で、告知は CVE や安全上の修正に触れていない |
| Cargo | `cargo 1.98.1 (797e8a9bc 2026-08-05)` | [rust-lang/cargo の勧告](https://github.com/rust-lang/cargo/security/advisories)（7件、最新は 2026-05-25 の2件） | 対象外。2026-05-25 の2件（CVE-2026-5222・5223）は、0.0.12 の照合が Cargo 0.97.0（Rust 1.96.0）で修正済みと確かめた。その後の勧告はない |
| Lean | `formal/lean-toolchain` の v4.34.1、`formal/` での実行版 `Lean (version 4.34.1, … commit 5045d0056413266e57c625dcd7c365b10e377c52, Release)` | [leanprover/lean4 の勧告](https://github.com/leanprover/lean4/security/advisories)（公開の勧告なし）、[リリースの一覧](https://github.com/leanprover/lean4/releases)（v4.36.0-rc1 まで）、CVE の検索 | 対象外。CVE は既知の CVE-2026-72844・CVE-2026-72711 だけで、0.0.12 の照合が修正のコミットを v4.34.1 の祖先に確かめた。新しい CVE は見つからなかった |
| elan | `elan 4.2.4 (227caca13 2026-08-25)` | [leanprover/elan の勧告](https://github.com/leanprover/elan/security/advisories)（公開の勧告なし） | 対象外 |

手元のリポジトリの根での `lean --version` は elan の既定の 4.35.0 を示すが、`formal/` では固定版の 4.34.1 が選ばれる。処理系の検査と形式化のビルドは `formal/` の固定版を使う。手元の rustup は 0.0.12 の公開の前に上げた `rustup 1.29.2 (d8c92c676 2026-10-21)` である。

未照合の範囲: fuzz と `check-heap.sh` が使う nightly の Rust と Miri、elan の Rust の依存、Lean の release notes の本文（リリースの一覧の説明は短く、本文は読んでいない）、試作の Lean の検査に使った別の機械の Rust と Lean（同じ版を入れたが、版の照合はしていない）。

## 評価と設計者の判断

新しい勧告はなく、改造へ組み込む更新はない。改造の名前の TODO の番号は変えない。

設計者の判断（2026-10-27）: 組み込まない。依存とツールチェーンの更新をこの改造に加えず、改造の名前の TODO の番号も変えない。

## 公開候補の再照合（2026-10-30）

取りまとめが2026-10-30 06:03〜06:10 JSTに一次資料を再照合した記録を転記した。[受領した記録](v10.3b/toolchain-handoff.md)と[大きさ・SHA-256](v10.3b/handoff-source.json)を保存した。本作業は資料の再取得を追加していない。以下の「対象外」は受領した記録の評価であり、末尾の未照合範囲を含む全面的な無影響の判断ではない。

対象: 作業ディレクトリ l00（m013/v10.1d、HEAD 7179a302）。版の照会はリポジトリの根と formal/ で行った。道具の導入・更新はしていない。

| 対象 | 固定版 | 実行版 | 当日確認した一次資料 | 結果と最初の照合（2026-10-27 の記録）との差 |
|---|---|---|---|---|
| Rust | rust-toolchain.toml `channel = "1.98.1"` | `rustc 1.98.1 (48a229cea 2026-09-01)`、commit 48a229ceaefd4985c50990b14116b6d856af0985、aarch64-apple-darwin、LLVM 22.1.8 | https://github.com/rust-lang/rust/security/advisories（6件、最新 2025-10-01 の GHSA-rv9c-3mvf-cw9h、Cygwin のパス区切り）、https://blog.rust-lang.org/（10-26 までの12件。CVE を含む記事はない。10-15 Rust 1.99.1、10-20 rustup 1.29.2、09-21 Miri の出力の cache で GitHub Actions の秘密が漏れる件、09-17 標的型の攻撃への注意） | 対象外。最初の照合との差なし（新しい勧告なし）。09-21 の記事は GitHub Actions の Miri の出力の cache の件で、このプロジェクトは GitHub Actions を使わない（記事の本文は読んでいない） |
| Cargo | Rust に付属 | `cargo 1.98.1 (797e8a9bc 2026-08-05)`、commit 797e8a9bca276c1c9f9f738d2a20f484fa4eea9d | https://github.com/rust-lang/cargo/security/advisories（7件、最新 2026-05-25 の2件 GHSA-p688-r7jv-fm6f・GHSA-jq42-7mfv-hm57） | 対象外。差なし。2026-05-25 の2件は最初の照合のとおり修正済みの版 |
| Lean | formal/lean-toolchain `leanprover/lean4:v4.34.1` | formal/ で `Lean (version 4.34.1, arm64-apple-darwin24.6.0, commit 5045d0056413266e57c625dcd7c365b10e377c52, Release)` | https://github.com/leanprover/lean4/security/advisories（公開の勧告なし）、https://github.com/leanprover/lean4/releases（v4.36.0-rc2 10-27 まで。一覧の説明に security・CVE・カーネルの健全性の修正の語はない。本文は読んでいない） | 対象外。差なし（最初の照合以後の新しいリリースは v4.36.0-rc2 だけ）。既知の CVE-2026-72844・CVE-2026-72711 は 0.0.12 の照合が修正のコミットを v4.34.1 の祖先に確かめた。CVE の記録の検索は今回していない |
| elan | 固定ファイルなし（Lean 担当からの候補の版の引き渡しなし） | `elan 4.2.4 (227caca13 2026-08-25)` | https://github.com/leanprover/elan/security/advisories（公開の勧告なし）、https://github.com/leanprover/elan/releases（最新 v4.2.4。説明に security・CVE の語はない） | 対象外。差なし |

未照合の範囲: 最初の照合と同じ（fuzz と check-heap.sh の nightly の Rust と Miri、elan の Rust の依存、Lean の release notes の本文、別の機械の Rust と Lean）。加えて今回は CVE の記録の検索と Rust の告知の個別の本文を読んでいない。二 lock の依存は release の advisories に任せる。

公開候補 CANDIDATE は `5de2594ad523fba4f38fa63f7a1b306e8a23eb0c` である。受領記録の照合時の HEAD は `7179a3026fcf2b463c1ec933aefd23256be6dc93` であり、候補まで Rust・Cargo・Lean の固定入力は不変である（[候補の状態](v10.3c/initial-state.json)、[関係状態の照合](v10.3c/relation-audit.json)）。elan の候補版の引き渡しなしという制限も保つ。最初の照合との差はなし。依存二対象の当日の状態・DB・lock・設定と初回の取得不能は、[R の結果](v10.3c/results.md#r-release)で別に記録する。
