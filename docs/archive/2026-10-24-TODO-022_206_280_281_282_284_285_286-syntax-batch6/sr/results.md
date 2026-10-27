# SR: RV-S への対応結果

2026-10-25。基準 B_WORK と開始・終了時の HEAD は `ff99531fc777a298fbb0c17ce678de767bcba884`、ブランチは `mod012/SR`。開始時の差分はなかった。ユーザーの依頼に従い、private/ とそれを指すスキルを読まず、作業対象リポジトリの git の変更操作は行っていない。

## 修正と所見の対応

[RV-S-response.md](../reviews/RV-S-response.md) の表で中1〜中3・軽1〜軽9を対応付けた。変更は検査スクリプト・方針の自己検査・公開手順と設計書・既存記録の訂正である。Rust/Lean のソース、依存の版、作業ツリーの manifest と二 lock は変更していない。

`--locked` による lock 更新の拒否を入力の誤りとし、`ERROR: input/configuration/executor`、理由 `lock needs update (--locked)`、表示単位の終了1を返すようにした。勧告あり・取得不能・道具不在を表示して終了0にする D25・D26 の扱いは保った。fuzz の manifest/lock の変更は rust と advisories を選び、ルートだけを調べる licenses は選ばない。

版上げ後の二 lock の同期手順を git-workflow と Z01a の Z01b への引き渡し条件に加えた。49.0.2 には生存する取っ手の上限がなく、0.0.11 から受理範囲が狭まることを 02-09 と CHANGELOG に記した。BREAKING_CHANGES への登録の要否は Z01a が判断する。確認した一次資料は Wasmtime 49.0.2/49.0.4 の配布ソースの `src/runtime/component/store.rs` である。49.0.4 の `DEFAULT_MAX_COMPONENT_HANDLES = 100_000` と `HandleCounter`、49.0.2 に同じ制限がないことを照合した。GitHub の該当版の取得は失敗したため、手元の配布ソースで確認し、02-09 には版付きの上流リンクを残した。対象限定の更新と `--offline` の意味は [Cargo の公式資料](https://doc.rust-lang.org/cargo/commands/cargo-update.html)で確認した。

## テストの作成時の関門と局所確認

既存の `AdvisoriesTests.test_target_states_raw_evidence_and_exit_status` の表へ、実出力の lock 拒否と旧形式の文言を追加した。守る契約は入力不整合の表示と終了1、片方が誤りでも両対象を試すことである。既存の取得失敗の行では入力不整合を区別する退行を捕まえられない。別の検査入口や公開フラグは加えていない。分類の二表も fuzz で licenses を選ばない期待へ改めた。テストの削除、期待の緩和はない。実行器とシェルの合計は差し引き8行増、自己検査は9行増で、新しいテストメソッドはない。

| コマンド・確認 | 終了と結果 | 外側の時間 |
|---|---|---:|
| `python3 -B scripts/check/test_policy.py AdvisoriesTests.test_target_states_raw_evidence_and_exit_status PolicyTests.test_work_mapping_and_all_integration_containment PolicyTests.test_change_mapping_conditional_checks_and_stops`（修正前） | 1。3メソッドの6ケースが意図どおり失敗。lock 拒否3ケースの終了0と fuzz の licenses 選択3ケースを検出 | 外側未計測、unittest表示3.910秒 |
| 同じ局所コマンド（修正後） | 0、3メソッド成功 | 外側未計測、unittest表示4.618秒 |

## 中1・中3の実入力での確認

`git archive`（読み取り）で `73d12d068d55aa55e342520c51f9fba9e7913bbf` の manifest・二 lock・Cargo の対象解決に必要なソースを `<tmp>/snapshot` に展開した。現行の `deny.toml` と `scripts/check/advisories.py` の写しを使い、実行器の根の解決をその一時コピーへ向けた。入力パスを指定する新しい引数は不要だった。作業ツリーの lock を変更していない。

元の二 lock の SHA-256 は次のとおりである。

- `73d12d06:Cargo.lock`: `1e927633cff09381e6947b65130b7c897d7df07c3124686d98e8cc1077d07b84`。
- `73d12d06:fuzz/Cargo.lock`: `9a84233a8434a5d58faf4866673b119b7c3145e1436266d78fc432266faab953`。

元の fuzz lock は benitoite 0.0.9 のままで、manifest は0.0.11だった。旧実行器では `UNVERIFIED`・終了0となる問題を再現し、修正後の実行器では同じ入力が `ERROR`・`lock needs update (--locked)`・終了1となることを確認した。workspace の19件の勧告はどちらの実行でも表示された。

その後、一時コピーだけで `cargo update --offline --manifest-path <tmp>/snapshot/fuzz/Cargo.toml -p benitoite` を実行した。差分は benitoite 0.0.9→0.0.11 と欠けていた unicode-width 0.2.2 の追加だけで、rustls/Wasmtime 等の外部依存の版は保った。[入力調整の差分](fuzz-input-sync.diff)と[実入力のハッシュ](old-input-sha256.json)を保存した。この状態で現行実行器を実行し、二対象とも19件の `ADVISORIES FOUND` と全ID・検出版・一次資料URL・`Solution: Upgrade to ...` の表示を確認した。生の cargo-deny は各1、表示単位は0である。

| 試行・コマンド | 終了と結果 | 外側の時間 | 保存記録 |
|---|---|---:|---|
| 旧実行器の写しで `python3 -B <tmp>/snapshot/scripts/check/advisories.py --db-path <tmp>/benitoite-sr/db` | 単位0。workspace19件、fuzzはlock拒否をUNVERIFIEDと分類 | 3.012秒 | [端末記録](original.log)、[report](original-advisories/report.json) |
| 修正後の写しで同じ入力とコマンド | 単位1。workspace19件、fuzzは入力の誤りと区別 | 3.503秒 | [端末記録](locked.log)、[report](locked-advisories/report.json) |
| 上記の fuzz lock の対象限定・offline同期 | 0、2パッケージだけを同期 | 0.230秒 | [同期記録](sync.log)、[差分](fuzz-input-sync.diff) |
| 修正後の写しで同期済みの一時入力を照合（同じコマンド） | 単位0。両対象 `ADVISORIES FOUND`、各19件、各生終了1 | 1.680秒 | [端末記録](findings.log)、[report](findings-advisories/report.json) |

Rust/Cargo は1.98.1、cargo-deny は0.20.2、aarch64 macOS。取得済みの依存は `CARGO_HOME=<tmp>/benitoite-s02a/cargo` を使った。共通設定の写しに `db-path` だけを加え、ignore は空のまま、三対象 `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl` を照合した。機能を選ぶ追加フラグはない。DB は `https://github.com/RustSec/advisory-db`、コミット `21d909e4c8bd4e14c7aea58bf980c881a0053ab1` である。開始・終了・取得日時は各 report のUTC値を参照する。設定のハッシュはパス置換前の実入力を示す。

両対象で表示された19件は次のとおりである（修正版は今回の cargo-deny の表示を転記）。Wasmtime の14件を含み、最初に対応すると決めた19件と一致する。

| 勧告 | 検出版 | 表示された修正版 |
|---|---|---|
| [RUSTSEC-2026-0346](https://rustsec.org/advisories/RUSTSEC-2026-0346.html) | rustls 0.23.45 | Upgrade to >=0.23.46 (try `cargo update -p rustls`) |
| [RUSTSEC-2026-0347](https://rustsec.org/advisories/RUSTSEC-2026-0347.html) | rustls 0.23.45 | Upgrade to >=0.23.46 (try `cargo update -p rustls`) |
| [RUSTSEC-2026-0348](https://rustsec.org/advisories/RUSTSEC-2026-0348.html) | rustls 0.23.45 | Upgrade to >=0.23.46 (try `cargo update -p rustls`) |
| [RUSTSEC-2026-0349](https://rustsec.org/advisories/RUSTSEC-2026-0349.html) | rustls 0.23.45 | Upgrade to >=0.23.46 (try `cargo update -p rustls`) |
| [RUSTSEC-2026-0382](https://rustsec.org/advisories/RUSTSEC-2026-0382.html) | rustls-webpki 0.103.15 | Upgrade to >=0.103.16, <0.104.0-alpha.1 OR >=0.104.0-alpha.8 (try `cargo update -p rustls-webpki`) |
| [RUSTSEC-2026-0353](https://rustsec.org/advisories/RUSTSEC-2026-0353.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0354](https://rustsec.org/advisories/RUSTSEC-2026-0354.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0355](https://rustsec.org/advisories/RUSTSEC-2026-0355.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0356](https://rustsec.org/advisories/RUSTSEC-2026-0356.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0357](https://rustsec.org/advisories/RUSTSEC-2026-0357.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0358](https://rustsec.org/advisories/RUSTSEC-2026-0358.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0359](https://rustsec.org/advisories/RUSTSEC-2026-0359.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0360](https://rustsec.org/advisories/RUSTSEC-2026-0360.html) | wasmtime 49.0.2 | Upgrade to >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0361](https://rustsec.org/advisories/RUSTSEC-2026-0361.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0362](https://rustsec.org/advisories/RUSTSEC-2026-0362.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0363](https://rustsec.org/advisories/RUSTSEC-2026-0363.html) | wasmtime 49.0.2 | Upgrade to >=36.0.18, <37.0.0 OR >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0364](https://rustsec.org/advisories/RUSTSEC-2026-0364.html) | wasmtime 49.0.2 | Upgrade to >=48.0.6, <49.0.0 OR >=49.0.3 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0378](https://rustsec.org/advisories/RUSTSEC-2026-0378.html) | wasmtime 49.0.2 | Upgrade to >=48.0.7, <49.0.0 OR >=49.0.4 (try `cargo update -p wasmtime`) |
| [RUSTSEC-2026-0379](https://rustsec.org/advisories/RUSTSEC-2026-0379.html) | wasmtime 49.0.2 | Upgrade to >=36.0.19, <37.0.0 OR >=48.0.7, <49.0.0 OR >=49.0.4 (try `cargo update -p wasmtime`) |

## 作業末の検査

基準と名指しは依頼と plan の SR 行で固定した。同じ指定に `--dry-run` を付けて選択と理由を確認し、作業末の検査を一度実行した。

```sh
scripts/check.sh --level work --base ff99531fc777a298fbb0c17ce678de767bcba884 --only policy_selftest,advisories,python_syntax
```

| 検査 | 終了・件数と結果 | 時間・最大常駐量 |
|---|---|---|
| 同じ指定の dry-run | 0。python_syntax・policy_selftest・advisoriesの部分選択を確認 | 0.014秒 |
| 上記の work を `/usr/bin/time -l` と検査本体の終了を保存するラッパーで実行 | **検査本体0**。Python構文検査成功、方針自己検査26件成功（3シェルの構文と旧legacyの照合を含む）、現行二lockとも照合済み・検出0件、生の終了も各0 | 外側20.492秒、time表示20.48秒。time自体はsandboxの `sysctl kern.clockrate: Operation not permitted` で終了1。timeの最大常駐量は取得不能。補助の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` は77,840,384 bytes |

[dry-run](dry-run.log)、[端末の記録](work.log)、[終了・時間・二 lock の前後のハッシュ](work-status.json)、[実照合のreport](work-advisories/report.json)を保存した。stdout/stderr・設定の写しも各 report の隣にある。現行の二 lock のハッシュは実行前後と基準で一致し、旧入力の実測も含めて作業ツリーのlockに差分はない。既存の19件への対応を確認する先行S群の結果は今回の実行へ引用していない。Rust/Cargo/Lean/elan全体の勧告を今回網羅して確認したものでもない。

最終の静的点検は `git diff --check` が終了0。変更したMarkdownと結果・対応表の13ファイルについて相対リンク242件とフェンスを確認し、所見12件の対応行、S01〜S05・SRの保存物に手元の絶対パスがないこと、基準と現行の二lockがバイト単位で一致することも確認した。検査後の変更は結果の記録だけであり、検査の入力は変更していない。

## 計画からのずれと申し送り

- 中3の元の fuzz lock は manifest と不一致で、`--locked` のままでは照合できなかった。中1の実例として失敗を残した上で、一時コピー内だけを最小同期して19件を照合した。作業ツリーの lock を変えない条件は保ち、調整前後の証拠を分けた。
- 最初の一時展開では Python 3.9 にない `tarfile.extractall(filter=...)` が失敗したため、読み取りで作った git archive を tar で展開する方法へ直した。リポジトリの入力には影響しない。
- 版上げ・二lockの同期と差分の照合、BREAKING_CHANGESへの登録の要否はZ01a/Z01bへ引き渡す。SRでは版を上げず、互換性の区分の判断を先取りしていない。
- レビューとS群の受け入れは取りまとめが行う。READMEの既存の勧告照合の決定は確認済みで、重ねて記述していない。
