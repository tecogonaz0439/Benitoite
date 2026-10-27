# 第6弾のセキュリティの勧告の照合と対応

2026-10-27、G01R が既存の記録を集約した。これは新しい勧告照合の実行記録ではない。各照合時点の結果と入力を区別し、現在の安全性やツールチェーン全体の無影響を結論しない。公開候補での再照合は Z01b が本書へ追記する。

## 最初の照合と設計者の判断

2026-10-24、P2 はワークスペースと fuzz の依存を照合した。両対象で同じ19件を検出し、既知の TODO-284・285 と一致した。設計者は TLS・Wasmtime の修正版更新を第6弾へ組み込み、依存とツールチェーンの勧告照合の運用（TODO-286）も同じ改造へ加えると決めた。元の根拠・コマンド・失敗と再試行・入力のハッシュは [preflight.md の P2](preflight.md#第6弾の最初の依存の勧告照合p22026-10-24)、判断は [README の設計者の決定](README.md#設計者の決定2026-10-24lean-の作業の途中)と [decisions.md の D23〜D30](decisions.md#d23-tlsの依存の更新と今回の境界)にある。

| 対象 | 最初の版（二つの lock 共通） | 対応後の版（二つの lock 共通） |
|---|---|---|
| rustls | 0.23.45 | 0.23.46 |
| rustls-webpki | 0.103.15 | 0.103.16 |
| webpki-root-certs | 1.0.9 | 1.0.10 |
| Wasmtime と内部クレート | 49.0.2 | 49.0.4 |
| cranelift-codegen | 0.136.2 | 0.136.4 |

初回の19 ID は rustls の `RUSTSEC-2026-0346`〜`0349`、rustls-webpki の `RUSTSEC-2026-0382`、Wasmtime の `RUSTSEC-2026-0353`〜`0364`・`0378`・`0379` である。二対象の重複を足して38件とはしない。webpki-root-certs の `RUSTSEC-2026-0383` は対象構成のグラフに出ず検出されなかったが、lock に残る影響版を別に確認して S01 で更新した。

初回の道具は cargo-deny 0.20.2、DB は `https://github.com/RustSec/advisory-db` のコミット `1645308cb4766561b0b274d8c93f7033a766fc96`、取得・照合日は2026-10-24である。最初は DB ロックの書き込みをサンドボックスが拒否したため未照合だった。その後、設定の写しの `db-path` だけを書き込み可能な一時領域へ変え、二対象へ共通の設定と `--locked` を渡した再試行が19件を検出した。生の cargo-deny は両方終了1（脆弱性）であり、S03 以後の表示単位の終了状態とは別である。

対象構成は `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl`。ignore は加えていない。Rust は `rust-toolchain.toml` の1.98.1、Cargo も同ツールチェーンを使う。Lean は `formal/lean-toolchain` の v4.34.1。P2 は Rust・Cargo・Lean・elan の勧告を網羅的に照合していない。elan の候補の実行版を含むツールチェーンの情報は Z01b が引き渡しを受けて確認する。

## S01〜S05 の対応と照合の経過

以下は各作業時点の記録の要約である。詳細な API・機能・依存経路・失敗の修正・検査・出典は各 results.md に残す。

| 作業・元の記録 | 対応と確認 | 勧告の照合の結果 |
|---|---|---|
| [S01](s01/results.md) | TLS の三クレートを二 lock とも上表の修正版へ更新。暗号 provider・検証器・機能の境界を保持し、二 manifest × 三構成の依存経路を照合 | 2026-10-24 UTC 14:06:21〜22。両対象に既知の Wasmtime 14件が残り、生の終了1。TLS の検出5件は消失。0383 は lock の修正版を別に確認 |
| [S02a](s02a/results.md) | Wasmtime 49.0.4 と関連クレートを二 lock で同期。既存の外部関数・診断・機能の境界を確認。現構成では例外・非同期ゲストを拒否することを記録 | 2026-10-24 UTC 16:49:11〜12。両対象とも照合済み・検出0件、生の終了0。取得不能による0件ではない |
| [S02b](s02b/results.md) | Store ごとのコンポーネントハンドル上限100,000、必要数を使わない R0906 と統計を接続。実ゲストで境界・呼び出し間の保持・drop 後の再利用を確認 | 2026-10-24 UTC 17:33:43〜44。両対象とも照合済み・検出0件、生の終了0 |
| [S03](s03/results.md) | 二対象へ共通設定と `--locked` を渡す advisories 単位、三状態の表示・生記録・終了状態、自動選択と公開の検査規約を接続 | 2026-10-24 UTC 17:59:47〜48。両対象とも照合済み・検出0件、生の終了0。表示単位も終了0。[生記録と対象別結果](s03/advisories/report.json) |
| [S04](s04/results.md) | 改造の最初と候補での照合手順、出典、保存記録のパス置換を整備。TLS・Wasmtime の版と49.0.4配布ソースを横断照合 | 2026-10-24 UTC 18:10:35〜36。両対象とも照合済み・検出0件、生の終了0。表示単位も終了0。[生記録と対象別結果](s04/advisories/report.json) |
| [S05](s05/results.md) | 独立した security-advisories スキルを作成し、二依存グラフと四ツールを別に評価する手順を定義。担当が作れなかった相対リンクは取りまとめが作成・確認 | 新しい実照合は行っていない。机上確認と参照先の確認を、候補の勧告照合とは扱わない |

S01〜S04 の DB はコミット `21d909e4c8bd4e14c7aea58bf980c881a0053ab1` である。各実照合で取得・更新しており、同じ DB や lock だけを理由に先行結果を引用したものではない。道具は cargo-deny 0.20.2、三対象構成と機能の選択は共通設定・既存 manifest のままとした。

依存の対応の根拠は S01 の TLS 勧告六件と S02a の Wasmtime 勧告14件・49.0.4配布ソースにある。HTTP の一般の失効確認や、Linux 上での実行成功、個別の攻撃入力の再現までを更新と照合の成功から結論しない。残る CRL/OneCRL・Linux の証明書の案内、取得元の制限、Dependabot、Lean の独立した検査器の評価は S04 から取りまとめへ引き渡している。

## G01 の改造全体の検査での照合

[G01 の結果](g01/results.md)と [生の出力・対象別結果](g01/advisories/report.json)を集約する。G01 は HEAD `0b4979eba18082b89b7aee2c00648cf28b1551ee` の change で cargo-deny 0.20.2 を実行し、二対象とも照合済み・検出0件だった。新しい勧告は検出されなかった。これは G01 時点の記録であり、G01R による新しい照合ではない。

| 対象 | DB取得日時（UTC） | 状態・生の終了 | lock の SHA-256（前後一致） |
|---|---|---|---|
| ワークスペース | 2026-10-27T01:43:20.251846Z | 照合済み・検出0件、IDなし、終了0 | `f63fed7d012a331fb653d1f5e7e17a8833dc15ac7c3423ae447b45003968b0d2` |
| fuzz | 2026-10-27T01:43:21.164388Z | 照合済み・検出0件、IDなし、終了0 | `0cca6d39a47673bbb1e4bf42722983a7c7bdbf2cfbe9f75df46163e26842dc0c` |

共通設定は `deny.toml`、SHA-256 は `be3a44ae7ba8be1804238592020094f8c49b5e9e9ed2fc0f625d6d72f5ab5d31`。二コマンドは `cargo deny --format json --log-level debug --manifest-path <manifest> --config deny.toml --locked check advisories`、manifest は `Cargo.toml` と `fuzz/Cargo.toml`。両対象の DB は RustSec のコミット `3279c99911354c400e1d41e47c7d60e39258b147` である。表示単位の終了も0。初回19件を検出した DB と更新後の版・DBを区別する。

## 未照合の範囲と Z01b への引き渡し

Rust・Cargo・Lean・elan の固定版と実行版に対する網羅的な勧告照合は未実施である。二 lock の検出0件を、四ツールの確認済み0件や無影響へ読み替えない。Z01b は候補の二 lock を更新した DB で再照合し、Rust/Cargo の固定版、Lean 担当から受け取る Lean/elan の候補の版を、D30 と公開スキルの一次資料に照らして確認する。

Z01b は本書へ日時・候補の完全な ID と入力・構成・道具版・DB・根拠・対象別の状態・生の終了・表示単位の終了・新しい勧告と未取得の範囲を追記し、生記録を永続的に保存してリンクする。新しい勧告は取りまとめから設計者へ報告し、次の改造の最初の判断へ渡す。新しい勧告の検出や取得不能を不合格・受け入れ停止の条件にせず、最初に組み込むと決めた項目の完了条件は保持する。


## Z01b の版上げ後の二 lock の照合（2026-10-27）

今回の Z01b 依頼の補足により、K2・release 水準・Rust/Cargo/Lean/elan の勧告照合は、候補の取り込み後に取りまとめが担当する。本節は work で自動選択された依存の二照合だけの記録であり、ツールチェーンの勧告を確認済みとはしない。

基準と HEAD は `67d6123c21dc5a47360d3045212f020eafaaf22b`。未コミットで 0.0.12 へ上げた候補の入力は [Z01b の状態とハッシュ](z01b/candidate-inputs.json)、manifest・lock・設定の識別は [tool-inputs.json](z01b/tool-inputs.json)、実行の全体は [Z01b の結果](z01b/results.md)にある。依存の版は変えず、二 lock の変更は benitoite の版の一行ずつだけである。

`check.sh --level work --base 67d6123c21dc5a47360d3045212f020eafaaf22b` が2026-10-27 02:37:30〜32 UTC に二 manifest を照合した。cargo-deny は0.20.2、DB は `https://github.com/RustSec/advisory-db` のコミット `3279c99911354c400e1d41e47c7d60e39258b147`。取得・更新は今回の照合で行い、G01 の結果を引用して省いたものではない。

| 対象 | DB取得日時（UTC） | 状態・生の終了 | lock の SHA-256（前後一致） |
|---|---|---|---|
| ワークスペース | 2026-10-27T02:37:31.521872Z | 照合済み・検出0件、IDなし、生の終了0 | `56231868e475eec4710ffcf2bda766a377facebddee5d6b646f4df3824161fc5` |
| fuzz | 2026-10-27T02:37:32.486984Z | 照合済み・検出0件、IDなし、生の終了0 | `b4a6253aa895fae5f2ddaa391630f8b57be24b2615af9b1452ed19d14e872a5d` |

二コマンドは `cargo deny --format json --log-level debug --manifest-path <manifest> --config <effective-config> --locked check advisories`。manifest は `Cargo.toml` と `fuzz/Cargo.toml`。共通の `deny.toml` の SHA-256 は `be3a44ae7ba8be1804238592020094f8c49b5e9e9ed2fc0f625d6d72f5ab5d31`、書き込み可能な一時領域を使うため db-path だけを加えた写しの SHA-256 は `76ccb26edd3573a69e579c8515ebf90d9429a100e89fcce67d3cb9622ccd9721`（いずれも保存時のパス置換前）。対象構成は共通設定の aarch64-apple-darwin・x86_64-unknown-linux-musl・aarch64-unknown-linux-musl、機能は既存 manifest の選択である。

生の出力・設定の写し・対象別の結果は [z01b/advisories/report.json](z01b/advisories/report.json)と同じディレクトリへ保存した。二対象とも照合済み・検出0件、生の終了0、表示単位の終了0。最初の照合の19件に対応した修正版を保ち、G01 から新しい勧告は検出されなかった。取得不能を0件へ読み替えたものではない。ignore は加えていない。固定版のツールチェーンの勧告と、取り込み後の release 候補の照合は未実施であり、取りまとめへ引き渡す。

## 公開候補の再照合（取りまとめ、2026-10-27）

### 二 lock

候補 `6db695e16bc21eedda2002630f3474632f8b64a1`（Z01b の取り込み、作業ツリーの差分なし）で `scripts/check.sh --level release --base 706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8` が選んだ advisories 単位が、2026-10-27 02:43:01〜03 UTC に二 manifest を照合した。cargo-deny 0.20.2、DB は `https://github.com/RustSec/advisory-db` のコミット `3279c99911354c400e1d41e47c7d60e39258b147`（02:43:02 UTC に取得・更新）、共通の `deny.toml` の SHA-256 は `be3a44ae7ba8be1804238592020094f8c49b5e9e9ed2fc0f625d6d72f5ab5d31`、ignore はない。

| 対象 | 状態・生の終了 | lock の SHA-256（前後一致） |
|---|---|---|
| ワークスペース | 照合済み・検出0件、IDなし、生の終了0 | `56231868e475eec4710ffcf2bda766a377facebddee5d6b646f4df3824161fc5` |
| fuzz | 照合済み・検出0件、IDなし、生の終了0 | `b4a6253aa895fae5f2ddaa391630f8b57be24b2615af9b1452ed19d14e872a5d` |

表示単位の終了は0。生の出力・設定の写し・対象別の結果は [z01/advisories/](z01/advisories/report.json)（手元のパスを伏せた）。最初の照合（P2）の19件はすべて修正版で解消し、新しい勧告はない。この後の Z01K は固定の manifest（テストの期待の JSON）だけを変え、二 lock・manifest・`deny.toml` は変えていないので、この照合は最終の候補にも当てはまる。

### Rust・Cargo・Lean・elan

Opus 5.5 のサブエージェントが、2026-10-27 02:06〜02:15 UTC に一次資料で照合した（[記録](z01/toolchain-advisories.md)）。候補の版は取りまとめが手元で確かめた実行版で、固定版と一致する。

| 対象 | 候補の版（固定版と実行版） | 結論 |
|---|---|---|
| Rust | `rust-toolchain.toml` の 1.98.1、`rustc 1.98.1 (48a229cea 2026-09-01)`、aarch64-apple-darwin | 対象外。rust-lang/rust の勧告6件はどれも 1.89.0 で修正済み。ブログと NVD にも新しい勧告はない |
| Cargo | `cargo 1.98.1 (797e8a9bc 2026-08-05)`（crate の版 0.99.0） | 対象外。CVE-2026-5222・5223 は 0.97.0（Rust 1.96.0）で、同梱の tar の CVE-2026-33056 は 0.4.45 で修正済み |
| Lean | `formal/lean-toolchain` の v4.34.1、`Lean (version 4.34.1, … commit 5045d005…)` | 対象外。CVE-2026-72844（4.32.2 未満と 4.33.0-rc1）と CVE-2026-72711（4.32.2 未満）の修正のコミットは v4.34.1 の祖先にある |
| elan | `elan 4.2.4 (227caca13 2026-08-25)` | 対象外。リポジトリの勧告・NVD・変更履歴に勧告はない |

ツールチェーンを網羅的に照合したのは今回が初めてであり、最初の照合（P2）との差は比べられない。未照合の範囲: fuzz と `check-heap.sh` が使う nightly の Rust と Miri、elan の Rust の依存、Lean の release notes の頁（修正のコミットの祖先関係で確かめた）。

### 範囲外の気付き（設計者へ報告し、次の改造の最初の判断へ渡す）

手元の rustup は 1.29.1（`rustup 1.29.1 (d95a37b6a 2026-08-13)`）である。rustup 1.29.2 の告知（2026-10-20）は、依存の rustls-webpki と webpki-root-certs を CVE-2026-111943（RUSTSEC-2026-0382。TODO-284 と同じ eMudhra の中間 CA の件）のために更新したと述べる。rustup は四つの対象に入らず、配布物にも含まれないが、開発の環境でツールチェーンを取得するときの TLS の検証に関わる。rustup の CVE の記録は取得していない。手元の rustup を 1.29.2 以降へ上げるかは設計者が判断する。

設計者の判断（2026-10-27）: 手元の rustup を上げてよい。取りまとめが 13:30 に `rustup self update` で `rustup 1.29.2 (d8c92c676 2026-10-21)` へ上げた。rustc・cargo は 1.98.1 のまま変わらない。K2 と release の検査は rustup 1.29.1 のときに行ったが、rustup はツールチェーンの取得と切り替えだけを担い、使った rustc・cargo の版は同じなので、検査の結果に影響しない。
