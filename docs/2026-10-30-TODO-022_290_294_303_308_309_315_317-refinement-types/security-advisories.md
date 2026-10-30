# セキュリティの勧告の照合（改造の最初）

照合日: 2026-10-30（+0900）。担当: 取りまとめ。手順はスキル security-advisories に従った。

## 入力

| 項目 | 値 |
|---|---|
| 対象のコミット | `80e8127a4f7edff946529153b2002666cc35edc1`（san_benito。未コミットの差分なし） |
| `Cargo.lock` | `075ddfa31b648a04030efcbfb30365910dff6d8de62b0e903b57d28dc5e6324d`（照合の前後で同じ） |
| `fuzz/Cargo.lock` | `d38cf1d0837d41512c9bd5137cfe25fcd923d82fecb600bcef2c8e26c346330b`（照合の前後で同じ） |
| `deny.toml` | `be3a44ae7ba8be1804238592020094f8c49b5e9e9ed2fc0f625d6d72f5ab5d31`（有効な設定も同じ。DB の場所の指定なし） |
| `Cargo.toml` | `a5eaf5d181e3bfc169e2c8e632b56bd71b943c08366bb4e2bbc858ce40269dec` |
| `fuzz/Cargo.toml` | `d8045b5ce1533133739c8b3e53c09c7d88fb0f7ce8252f5640028a73d14a16e2` |

## ワークスペースと fuzz の依存

コマンド: `python3 -B scripts/check/advisories.py`（開始 2026-10-30T11:04:31+0900、終了 11:04:35+0900、単位の終了 0）。cargo-deny 0.20.2。DB は https://github.com/RustSec/advisory-db を照合時に取得し、コミットは `ee1a49a2769a24a596afc1c20cb33748d2769586`（2026-10-29T15:05:38+01:00）であった。

| 対象 | 状態 | 生の終了状態 | 検出 |
|---|---|---|---|
| workspace | CHECKED: 0 advisories | 0 | なし |
| fuzz | CHECKED: 0 advisories | 0 | なし |

両対象が照合済み・検出0件なので、依存全体で検出0件である。保存した記録: [advisories/20261030T020432Z/](advisories/20261030T020432Z/report.json)（パスは `<repo>`・`<home>`・`<tmp>` に置換済み）。

## Rust・Cargo・Lean・elan

候補の版は固定版と手元の実行版で確かめた。Lean と elan は、この改造ではまだ Lean 担当から候補の版を受け取っていないので、固定版と実行版で照合した。一次資料は 2026-10-30 11:05〜11:07 頃（+0900）に取得した。

| 対象 | 固定版 | 実行版 | 確かめた一次資料 | 結論 |
|---|---|---|---|---|
| Rust | `rust-toolchain.toml` の `1.98.1` | `rustc 1.98.1 (48a229cea 2026-09-01)` | [rust-lang/rust の勧告](https://github.com/rust-lang/rust/security/advisories)（6件、最新は 2025-10-01 の GHSA-rv9c-3mvf-cw9h。影響は 1.87.0 以上 1.89.0 未満の Cygwin の対象だけ）、[Rust の告知](https://blog.rust-lang.org/)（10-26 まで。10-01 以後の5件の題名に CVE・security の語はない） | 対象外 |
| Cargo | Rust に付属 | `cargo 1.98.1 (797e8a9bc 2026-08-05)` | [rust-lang/cargo の勧告](https://github.com/rust-lang/cargo/security/advisories)（7件、最新は 2026-05-25 の GHSA-p688-r7jv-fm6f・GHSA-jq42-7mfv-hm57。Rust 1.96.0 で修正） | 対象外 |
| Lean | `formal/lean-toolchain` の v4.34.1 | `formal/` で `Lean (version 4.34.1, … commit 5045d0056413266e57c625dcd7c365b10e377c52, Release)` | [leanprover/lean4 の勧告](https://github.com/leanprover/lean4/security/advisories)（公開の勧告なし）、[リリースの一覧](https://github.com/leanprover/lean4/releases)（最新 v4.36.0-rc2、安定版の最新 v4.35.0。一覧の説明に security・CVE・soundness・kernel の語はない） | 対象外 |
| elan | 固定ファイルなし | `elan 4.2.4 (227caca13 2026-08-25)` | [leanprover/elan の勧告](https://github.com/leanprover/elan/security/advisories)（公開の勧告なし）、[リリースの一覧](https://github.com/leanprover/elan/releases)（最新 v4.2.4） | 対象外 |

0.0.13 の公開候補の再照合（2026-10-30 06:10 頃）との差はない。既知の Lean の CVE-2026-72844・CVE-2026-72711 は、0.0.12 の照合が修正のコミットを v4.34.1 の祖先に確かめた。

未照合の範囲: fuzz と `check-heap.sh` が使う nightly の Rust と Miri、elan の Rust の依存、Lean の release notes の本文、CVE の記録の検索、Rust の告知の個別の本文、試作の Lean の検査に使う別の機械の Rust と Lean。

## 評価と設計者の判断

新しい勧告はなく、改造へ組み込む更新の候補はない。

設計者の判断（2026-10-30）: 組み込まない。依存とツールチェーンの更新をこの改造に加えず、改造の名前の TODO の番号も変えない。
