# V10.3b: 四ツールの勧告の再照合（取りまとめ、2026-10-30 06:03〜06:10 JST）

対象: 作業ディレクトリ l00（m013/v10.1d、HEAD 7179a302）。版の照会はリポジトリの根と formal/ で行った。道具の導入・更新はしていない。

| 対象 | 固定版 | 実行版 | 当日確認した一次資料 | 結果と最初の照合（2026-10-27 の記録）との差 |
|---|---|---|---|---|
| Rust | rust-toolchain.toml `channel = "1.98.1"` | `rustc 1.98.1 (48a229cea 2026-09-01)`、commit 48a229ceaefd4985c50990b14116b6d856af0985、aarch64-apple-darwin、LLVM 22.1.8 | https://github.com/rust-lang/rust/security/advisories（6件、最新 2025-10-01 の GHSA-rv9c-3mvf-cw9h、Cygwin のパス区切り）、https://blog.rust-lang.org/（10-26 までの12件。CVE を含む記事はない。10-15 Rust 1.99.1、10-20 rustup 1.29.2、09-21 Miri の出力の cache で GitHub Actions の秘密が漏れる件、09-17 標的型の攻撃への注意） | 対象外。最初の照合との差なし（新しい勧告なし）。09-21 の記事は GitHub Actions の Miri の出力の cache の件で、このプロジェクトは GitHub Actions を使わない（記事の本文は読んでいない） |
| Cargo | Rust に付属 | `cargo 1.98.1 (797e8a9bc 2026-08-05)`、commit 797e8a9bca276c1c9f9f738d2a20f484fa4eea9d | https://github.com/rust-lang/cargo/security/advisories（7件、最新 2026-05-25 の2件 GHSA-p688-r7jv-fm6f・GHSA-jq42-7mfv-hm57） | 対象外。差なし。2026-05-25 の2件は最初の照合のとおり修正済みの版 |
| Lean | formal/lean-toolchain `leanprover/lean4:v4.34.1` | formal/ で `Lean (version 4.34.1, arm64-apple-darwin24.6.0, commit 5045d0056413266e57c625dcd7c365b10e377c52, Release)` | https://github.com/leanprover/lean4/security/advisories（公開の勧告なし）、https://github.com/leanprover/lean4/releases（v4.36.0-rc2 10-27 まで。一覧の説明に security・CVE・カーネルの健全性の修正の語はない。本文は読んでいない） | 対象外。差なし（最初の照合以後の新しいリリースは v4.36.0-rc2 だけ）。既知の CVE-2026-72844・CVE-2026-72711 は 0.0.12 の照合が修正のコミットを v4.34.1 の祖先に確かめた。CVE の記録の検索は今回していない |
| elan | 固定ファイルなし（Lean 担当からの候補の版の引き渡しなし） | `elan 4.2.4 (227caca13 2026-08-25)` | https://github.com/leanprover/elan/security/advisories（公開の勧告なし）、https://github.com/leanprover/elan/releases（最新 v4.2.4。説明に security・CVE の語はない） | 対象外。差なし |

未照合の範囲: 最初の照合と同じ（fuzz と check-heap.sh の nightly の Rust と Miri、elan の Rust の依存、Lean の release notes の本文、別の機械の Rust と Lean）。加えて今回は CVE の記録の検索と Rust の告知の個別の本文を読んでいない。二 lock の依存は release の advisories に任せる。
