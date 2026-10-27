# 作業 S01 の結果

2026-10-24。基準 B_WORK と開始時の HEAD はともに `73d12d068d55aa55e342520c51f9fba9e7913bbf`、作業ブランチは `mod012/S01` である。開始時の作業ツリーに差分はなかった。S01 の TLS 依存と関連する設計書だけを更新し、git の変更操作は行っていない。

## 変更

| 対象 | 変更後 | 確認したこと |
|---|---|---|
| `crates/benitoite/Cargo.toml` | rustls `=0.23.46` | `default-features = false` と `std`・`tls12` を維持 |
| `Cargo.lock`・`fuzz/Cargo.lock` | rustls 0.23.46、rustls-webpki 0.103.16、webpki-root-certs 1.0.10 | 二つの lock に各一版だけがあり、同じ版と checksum を解決 |
| 同上 | ureq 3.4.2、rustls-graviola 0.4.0、rustls-platform-verifier 0.7.1 | 変更せずに解決できた |
| `docs/design/03-interop/03-01-library-structure.md` | TLS の版・機能・二つの lock と修正版の出典を追記 | 修正版の勧告六件を一次資料で確認。一般の失効確認を保証する記述にはしていない |

ルートの lock で変更したパッケージは TLS の三つだけである。fuzz の lock は開始時に Benitoite 0.0.9 の依存を記録していたため、Cargo による解決で現行 manifest の Benitoite 0.0.11 と既存依存 unicode-width 0.2.2 も同期された。これ以外のパッケージを更新・削除していない。全外部取得元は両 lock とも `registry+https://github.com/rust-lang/crates.io-index` のままである。

## コマンドと検査

依存更新は、`cargo update -p <package> --precise <version>` と `cargo update --manifest-path fuzz/Cargo.toml -p <package> --precise <version>` を順に実行した。対応は rustls=0.23.46、rustls-webpki=0.103.16、webpki-root-certs=1.0.10 である。六回とも終了0。更新の外側の時間は未計測である。

既定の Cargo キャッシュへの書き込みはサンドボックスで拒否されるため、取得・検査では `CARGO_HOME=<scratch>/cargo` を使った。`<scratch>` は書き込み可能な一時ディレクトリである。既存の index を一時領域へ複写し、既存の source/cache は読み取り用のリンクから参照し、新しい二クレートは一時領域へ取得した。`rust-toolchain.toml` の Rust 1.98.1 を維持した。

| 実行したコマンド・対象 | 終了状態 | 外側の時間・最大常駐量 |
|---|---|---|
| `scripts/check.sh --level work --base 73d12d068d55aa55e342520c51f9fba9e7913bbf --dry-run` | 0。fmt、lint_default、lib_default、全統合の tests_related、source_rules、skill_generated、spec_tally、licenses を選択 | 約0.02秒。メモリ計測なし |
| `/usr/bin/time -l scripts/check.sh --level work --base 73d12d068d55aa55e342520c51f9fba9e7913bbf` | 検査本体0（`selected checks passed` に到達し `exit 0`）。計時ラッパー1（下記の環境制限） | 682.44秒（11分22.44秒）。maximum resident set size は取得不能 |
| `cargo tree --manifest-path <manifest> --locked --target <target> --edges features --invert rustls-webpki`（二つの manifest × 三構成） | 六回とも0。各経路は rustls-webpki 0.103.16 | 合計0.82秒。メモリ計測なし |
| `cargo tree --manifest-path <manifest> --locked --target <target> --invert webpki-root-certs`（同上） | 六回とも0。対象構成では経路なし | 合計1.24秒。メモリ計測なし |
| 設計書の相対リンク先・フェンス・末尾空白・非公開/絶対パスのリンク不在と `git diff --check` | 0 | 0.019秒。メモリ計測なし |

上の manifest は `Cargo.toml` と `fuzz/Cargo.toml`、構成は `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl` である。六つの依存グラフの rustls の機能は `log`・`logging`・`std`・`tls12`、ureq は `_rustls`・`_tls`・`platform-verifier`・`rustls-no-provider` だった。直接依存の機能指定と暗号 provider を変えていない。Linux のグラフでは rustls-platform-verifier → rustls-webpki の経路も更新版へつながる。構成別の確認は依存グラフの照合であり、Linux 上の実行検査ではない。

work は一度実行した。fmt、examples を含む clippy、lib 全件（1,271成功・失敗0・既存の ignore 21）、全統合40ターゲット（378成功・失敗0・既存の ignore 10）、規約、Skill の再生成照合、仕様集計の自己検査と集計、ライセンスをすべて通過した。テストの期待値・ignore・時間制限は変更していない。HTTP では次の既存テストを含む。

- `wrapped_certificate_failure_is_other_not_invalid_http_data`: rustls の証明書エラーから完了の値までの分類が成功。
- `l32_http_client`: 通常要求・リダイレクト・時間切れ・接続拒否など9件が成功。
- `http_exchange_release`: 取消後の解放とファイル worker の継続、部分応答後の実行時エラー、SIGINT の3件が成功。

`/usr/bin/time -l` はコマンド終了後の `sysctl kern.clockrate` が `Operation not permitted` となり、メモリ統計を表示せず終了1になる。`/usr/bin/time -l /usr/bin/true` でも同じ状態を再現した。検査本体と計時ラッパーの終了を区別し、取得不能の最大常駐量を0として記録しない。work の全件検査をメモリ計測だけのために反復しない。

## 更新後の勧告照合（T-S）

`cargo deny --version` は終了0、`cargo-deny 0.20.2` だった。ルートの `deny.toml` を一時領域へ写し、`[advisories]` の `db-path` だけを一時領域へ設定した。追跡する `deny.toml`、対象構成、ignore は変更していない。DB は各照合時に更新した。

最初の二照合も TLS 5件の消失と既知の Wasmtime 14件を検出した（外側の時間はルート1.34秒、fuzz 1.57秒）。ただし計時ツールの終了1と生の終了を分けて保存できていなかったため、終了値を保存するシェルのラッパーと Python の `getrusage(RUSAGE_CHILDREN)` を併用し、二照合の計測を取り直した。取り直しも `/usr/bin/time -l` で包んだ。以下は取り直しの結果であり、最初の二照合と加算しない。

| 対象 | コマンド（`CARGO_HOME` は上記、`<config>` は一時設定） | 生の終了 | 外側の時間 | 取得日時（UTC） |
|---|---|---|---|---|
| ワークスペース | `cargo deny --config <config> --locked check advisories` | 1（`advisories FAILED`、既知14件） | 0.816秒 | 2026-10-24T14:06:21.563289+00:00 |
| fuzz | `cargo deny --manifest-path fuzz/Cargo.toml --config <config> --locked check advisories` | 1（同じ14件） | 0.803秒 | 2026-10-24T14:06:22.398358+00:00 |

二照合を実行した親 Python での `getrusage(RUSAGE_CHILDREN).ru_maxrss` の累積最大常駐量は **77,643,776 bytes** だった。これは二照合とその計時ラッパーを含む子プロセスの最大値であり、二回目だけの値ではない。バイト単位は手元の macOS SDK の `getrusage(2)` の説明で確認した。

両照合の DB は `https://github.com/RustSec/advisory-db`、コミットは `21d909e4c8bd4e14c7aea58bf980c881a0053ab1` である。対象構成は元の三構成のまま。各入力の SHA-256 は次のとおりである。

| 入力 | SHA-256 |
|---|---|
| `Cargo.lock` | `042212629ad901d5460cd6d0aa26dd8be951f66b0d6f8af7f48f8cc6d4c58fd1` |
| `fuzz/Cargo.lock` | `711d03dc07a946d73a7ee671637d5544edc573cc35948fbc8f5c3372ea2de084` |
| 元の `deny.toml` | `810721145d1a767d1011e2359a6d38460a075f9f911d3923c7e1b92d4c65cde1` |

両照合で検出した一意の ID は `RUSTSEC-2026-0353`・`0354`・`0355`・`0356`・`0357`・`0358`・`0359`・`0360`・`0361`・`0362`・`0363`・`0364`・`0378`・`0379` の14件で、クレートは Wasmtime 49.0.2 である。二対象で重複した28件とは数えない。TLS の `0346`・`0347`・`0348`・`0349`・`0382` は検出されず、初回照合の既知19件から5件減った。新しい勧告はない。`0383` は対象構成の照合に出ないため、両 lock の webpki-root-certs 1.0.10 を別途確認した。

## 計画からのずれと申し送り

- fuzz の lock では、TLS の三クレートに加え、現行 manifest に必要な Benitoite の版と unicode-width を同期した。
- 最大常駐量の計測には上記の環境制限がある。work の取得不能は明記し、勧告照合は補助計測で二照合の最大値を取得した。
- HTTP の既存テストの確認には公開の test-audit の基準を使った。テストと本体のソースは変更していない。攻撃入力の再現、一般の証明書失効確認、Linux の証明書検証を実行した証拠にはしない。
- 残る既知の Wasmtime 14件は計画どおり S02a へ渡す。勧告照合で修正版として示された49系列は49.0.4である。S02b の取っ手の制限も本作業の範囲に含めていない。
- `formal/`・01-12・07-04 は変更も検査もしていない。言語規則や定理・公理の判断を要する点はなかった。
- 独立レビューと S 作業群の受け入れは取りまとめが後続の区切りで行う。本記録は他の状態の検査結果を引用したものではない。
