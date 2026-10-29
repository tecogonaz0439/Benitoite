# V10.3c: 公開候補のreleaseと手動の照合

2026-10-30 JST。候補 `5de2594ad523fba4f38fa63f7a1b306e8a23eb0c` に対し、RとPを完了した。Rのcheck.shは終了0、release_stackは10成功、依存の勧告は別保存先での一度の再確認で両対象とも照合済み0件だった。Pの最終照合は148コマンド全件一致である。初回のDB取得不能、記録用照合器の誤り、CLI入力の補完前の不一致を下に残す。独立レビュー・受け入れ・集約・タグ・配布・pushは取りまとめと設計者の担当である。

## 対象の状態と入力

| 07-03の欄 | 記録 |
|---|---|
| 作業・基準・HEAD | V10.3bの記録とV10.3c。B0は `6124775788579e60530f55fb85570f26ef7fa900`、B_WORKと対象HEADは `5de2594ad523fba4f38fa63f7a1b306e8a23eb0c`、ブランチ `m013/v10.3c`。開始時の追跡・index差分は空（[開始状態](initial-state.json)） |
| 変更の範囲 | v10.3b/・v10.3c/の記録・候補照合入力と、security-advisories.md末尾への追記だけ。本番・設計書・テスト・計画を変えていない。状態を変えるgit操作をしていない |
| 入力 | 両manifest・両lock・deny.toml・Rust/Lean固定ファイル・Cargo/build.rsのハッシュは開始状態、Pの事前期待値と73ケースの入力ハッシュは[expectations.json](expectations.json)と[ハッシュ](expectations.sha256)、その由来は[R40.3](../r40.3/handoff.md)とK10.2の独立期待値。初稿は[保存した期待値](expectations-attempt2.json)を保つ |
| 構成・道具 | macOS/arm64、aarch64-apple-darwin、Cargo既定機能gc-mark-sweep、release。Rust/Cargo1.98.1、Python3.9.6、cargo-deny0.20.2。formalでのLean4.34.1・elan4.2.4の版照会だけも行った（[実版](environment.json)）。道具の導入・更新なし |
| 引用 | 全比較の候補への[F-Q更新票](f-q.md)、changeの下記引用、[一覧の照合](inventory.md)に、元結果・以後の変更・同一性の理由・担当と日付を記す。別OS/32ビット/機能を外した構成へ広げない |
| 最終状態 | [最終の確認](final-state.json.gz)にHEAD・ブランチ・index差分、変更の一覧、未コミット差分と未追跡入力を含む記録のSHA-256、lock前後、バイナリのハッシュを残す。自己参照する最終状態ファイル自身は一覧から除く |

## R: release

まず `scripts/check.sh --level release --base 6124775788579e60530f55fb85570f26ef7fa900 --dry-run` を一度実行した。[dry-run](release-dry-run.log)は終了0、選択はrelease_stackとadvisoriesの2単位である。続けて、同じ指定を `/usr/bin/time -p` の直下に置いて一度だけ実行した。

```sh
/usr/bin/time -p scripts/check.sh --level release --base 6124775788579e60530f55fb85570f26ef7fa900
```

[全ログ](release.log)と[実行記録](release-execution.json)を保存した。check.sh自身は `selected checks passed` まで到達して終了0、timeの終了も0である。要約器やパイプを挟んだ終了ではない。2026-10-30 07:55:01〜07:56:30 JST、Python外側88.477471秒、timeはreal88.47・user338.60・sys3.61秒だった。

| 単位・対象 | 結果 |
|---|---|
| release_stack | `python3 -B scripts/check/run_ignored.py --kind release-stack --configuration release` が `cargo test --release -p benitoite --lib -- pipeline::tests::stages_fit_the_measured_stack_ --include-ignored` を実行。10成功・失敗0・ignored0・measured0・filter1,404。テスト実行32.31秒、最初の最適化ビルドはCargo表示54.92秒。要求件数10を満たした |
| advisories初回: ワークスペース | `UNVERIFIED`、生のcargo-deny終了1。既定のDBロックを読み取り専用の場所へ取得できないため、照合不能。勧告を観測しなかったことを検出0件へ読み替えない |
| advisories初回: fuzz | 同じく `UNVERIFIED`、生の終了1。片方で止めず両対象を実行。単位の終了は方針どおり0 |
| advisories再確認: ワークスペース | `CHECKED: 0 advisories`、IDなし、生の終了0 |
| advisories再確認: fuzz | `CHECKED: 0 advisories`、IDなし、生の終了0。両対象がclearなので、この再確認の依存全体を検出0件とする |

初回の[reportと生出力・設定](advisories-initial/report.json)を保持し、次のコマンドで別のDB保存先を一度だけ使った。release全体とrelease_stackの再実行はしていない。

```sh
python3 -B scripts/check/advisories.py --db-path target/v10.3c/advisory-dbs
```

[再確認のログ](advisories-recheck.log)・[外側2.311897秒・終了0](advisories-recheck.json)・[対象別のreportと生出力・設定](advisories-recheck/report.json)を保存した。原設定は共通deny.toml、`--locked`を両manifestへ指定し、db-pathだけを設定の写しへ加えた。ignoreとlockを変更していない。

| 入力・DB | 値 |
|---|---|
| 対象構成 | deny.tomlのaarch64-apple-darwin・x86_64-unknown-linux-musl・aarch64-unknown-linux-musl、各manifestの機能選択。全構成の実ビルドを意味しない |
| 共通設定SHA-256 | `be3a44ae7ba8be1804238592020094f8c49b5e9e9ed2fc0f625d6d72f5ab5d31` |
| 再確認の設定の写しSHA-256 | `dea149fc86af1965015f1aed075fa2eeac4f3f83ab4adc1f29e49da7001345e9`。置換前の実入力の値。保存出力のパスは実行器が伏せた |
| ワークスペースlockの前後SHA-256 | `075ddfa31b648a04030efcbfb30365910dff6d8de62b0e903b57d28dc5e6324d`、初回・再確認とも不変 |
| fuzz lockの前後SHA-256 | `d38cf1d0837d41512c9bd5137cfe25fcd923d82fecb600bcef2c8e26c346330b`、初回・再確認とも不変 |
| DB | `https://github.com/RustSec/advisory-db`、commit `ee1a49a2769a24a596afc1c20cb33748d2769586` |
| 取得日時 | ワークスペース2026-10-29T22:57:13.907156Z、fuzz2026-10-29T22:57:14.724900Z |

最初の2026-10-27の照合からDBのcommitとbenitoiteの製品版を含むlockのハッシュは変わったが、検出0件という結果の差はない。四ツールの当日の一次資料の照合は[V10.3bの結果](../v10.3b/results.md)と[security-advisoriesの追記](../security-advisories.md#公開候補の再照合2026-10-30)を引く。nightly Rust/Miri、elanの依存と候補版の引き渡しなし、Lean release notes本文、別機、今回のCVE検索とRust告知の個別本文という未照合の範囲を保つ。

## P: 候補の照合

追跡差分がない状態を確認してから `BENITOITE_BUILD_DIRTY=false cargo build --release -p benitoite` を実行し、終了0・31.050924秒だった（[ビルド直前の状態と指定の理由](build-state.json)、[実行記録](build.json)、[ログ](build.log)）。`build.rs`はdirtyを自動採取しないため、この指定は検証した状態の明示である。ビルド直前の未追跡は本作業の結果記録だけで、製品への未コミット差分はない。commitはGitから取得し、環境変数で上書きしていない。

| 項目 | 最終結果 |
|---|---|
| 実CLIとproducer | version=0.0.13、commit=`5de2594ad523fba4f38fa63f7a1b306e8a23eb0c`、dirty=false、target=aarch64-apple-darwin。由来はcommit=git・dirty=environment。全報告と全Skillのproducerが一致（[version.json](version.json)） |
| 実行ファイルSHA-256 | `a3f6610893bf6d38a9ae43b58e66f7b763de92298a47a8a2c015e7bda3d3b737`。全照合と最終確認で不変 |
| 補完後に固定した期待値SHA-256 | `d7ac00da6eb012f1cce6dca09d2862340e15530b37f6474b0e7e777604e1015f`（空の main を補完後に固定した値。初稿は `7285b8e460ebf3d4e8c7650820cc936992bff3e8c9dfc9d1685f9e100a720a27`）。初稿と補完理由も保存 |
| R40.3の報告 | 26入力50コマンド。check・test --check・test --doc --checkの終了、単一JSON報告、complete/executed、aggregateEffects、個々の宣言上限、bounds、診断コードと四理由、ソース本文ハッシュが一致。実行は常にexecuted=false |
| K10.2の代表拒否 | RequiredのnotCovered/unknownSource、request-widenのunknownSource、効果上限のnotCovered/atomicCoverOnlyの5ケースが一致。三入力は下記の空main補完を先に固定して使用。Rust/Leanの直接比較として新しく数えていない |
| 完全／部分ハンドラ | R40.3の完全3種・部分3種・上限不足3種に加え、V10.3aの旧11操作File.Read・旧12操作File.Write・旧sendのみHttp.Connectの3入力を照合。宣言なしの三入力は各E0501で、部分ハンドラの効果が残る |
| 言語版の境界 | 同じ三入力の `language "0.0.12"` 版は各E0908。三効果に言及する新しい注記とhelpが事前固定の文字列に完全一致。移行手順・例を加えていない |
| 名前だけのallow-effects | runとtestの各入口でFile.Writeを受理、空はE0512、不正な利用者名Reportと範囲付き指定は使い方の誤り（終了2）で、E0512と区別。純粋入力と利用者エフェクトを完全に処理した純粋入力は空を受理。計12コマンド。実行したmain/test本体に実IOなし |
| 報告の境界 | 非Top/Top、同名の複数原子と冗長宣言、処理後の純粋性・利用者名非表示、狭い型の転送と射影の制限、未知/未完了、doc check/errorの空を照合。空のdoc Effects/testsを純粋の証拠へ読み替えない |
| Skill | listの全73論理名をshow。物理ファイルと索引・二つのライセンスを含み、漏れ・余分・重複0。全本文・byteLength・contentHashとレンダリング後の版が一致（[全件の表](skill-audit.json)） |
| 合計 | 73ケース＋version＋skill list＋73 show＝148コマンド、148一致・最終不一致0（[全コマンド・終了・時間と判定](candidate-check.json)、[照合台本](check-candidate.py)、outputs/のstdout・stderrと個別実行記録） |

新しい外部宛先への実IOはしていない。非実行のcheck/test/docでは、保持endpoint等の文字列を解析しても通信しない。run/testの名前の照合には本体が純粋な固定入力を使った。実行時権限制御・実体の隔離・DNS/TLS副次通信の制限・内容の流れの保証を追加していない。外部ハンドラの母集団・件数は不明であり、0件としない。

## 初回の不一致と記録用スクリプトの修正

Pの最初の実行は、照合器がSkillのCLI一覧とbundleのソースの並び順を等しいと仮定して停止した。CLIは辞書順、bundleはライセンスを末尾に置くため、論理名の集合は一致する。名前の一意性・集合・物理ファイル・本文の照合を保って、過剰な順序の仮定を除いた（[初回の記録](candidate-attempt1.json)、outputs-attempt1/）。製品の修正ではない。

二回目は143/148一致で、[5件の不一致](candidate-attempt2.json)を保存した。うち2件はprojection-repaired・show-matchが@testを持たないのに照合器が1件以上を要求した誤りで、元の独立期待値どおり空を認めた。残る3件はK10.2のRequired入力にmainがなく、公開CLIが目的のE0519より先にE0414を返したものである。元の固定ソース・初稿の期待値・出力を保持し、sampleの本文と型・効果を変更せず、空のmainだけを末尾に追加した派生入力をv10.3c/inputs/へ保存した。期待する拒否コード・理由を出力に合わせて変えたものではない。[入力の差と理由・旧新ハッシュ](input-corrections.json)を記し、新しいハッシュを固定してから再実行した。三回目は148件全て一致した。

一覧の補助照合も最初は標準宣言の `public effect` の先頭を `effect` と仮定して読取り中に停止した。出力や製品を書き換える前の補助スクリプトの誤りであり、実際の構文へ合わせた[audit-inventory.py](audit-inventory.py)で照合を終えた。Rのテスト失敗や本番コードの退行はなく、全比較の入力の変更、引用不能、J3による追加実行はない。

## 一覧・F-Q・changeの引用

[候補一覧](inventory.md)は英語・日本語7組・README・CHANGELOG・二lock・ライセンス・生成物67件・Skill73論理名・ソースだけの配布を対応付けた。期待した0.0.13との食い違いはない。ソースarchiveのプレビューや正式archiveは作成しておらず、正式な集約・タグ・archiveとP-finalはV10.3eに残る。

[F-Q更新票](f-q.md)はV10.1d/V10.1dbにV10.1cの2テスト修正を以後の変更として加えた。関係入力4,680件のうち4,678一致、変更2件はV10.1cの保存済みハッシュに一致、欠落0。formalの409項目、七実行ファイルと最終manifestは一致した。全比較の成功段と影響段の再確認を合わせた判定を候補へ引用し、新しい全体の終了0を得たとはしていない。

改造全体の回帰は、取りまとめの[V10.1c「三回目のchange」](../v10.1c/results.md#三回目の-change取りまとめ2026-10-30)を引用する。B_WORK `7179a3026fcf2b463c1ec933aefd23256be6dc93` とV10.1ca/cbの未コミット差分を含む状態で、全17単位が終了0・real3,994.08秒だった。既定3,269・heap3,283・stress1,884・doc34・long_only60成功、各失敗0、ignoredは順に54/54/32/1、依存両対象0件である。formal_buildは元のchangeで実行した結果であり、今回再実行した意味ではない。T-D50件・T-C39件の成功も同記録を引く。候補への差分は検査後の記録・取り込みで、当該検査の意味上の入力は不変であることをrelation-auditとソース差分で確認した（Codex、2026-10-30）。最初の二回のchangeの失敗は元記録のまま残す。

## 文書作業末の確認

W-Dは `scripts/check.sh --level work --base 5de2594ad523fba4f38fa63f7a1b306e8a23eb0c --dry-run` で選択0件・文書だけであることを確認し、同じ指定からdry-runだけを外して一度実行した。終了0・外側0.174462秒で、新しいRust/Leanのビルドやテストは選ばれていない（[dry-run](work-dry-run.log)、[実行ログ](work.log)、[実行記録](work.json)）。補助Pythonの構文、リンク、手元の絶対パスの不在、許可された範囲だけの変更、lockとバイナリの不変、全入力・結果のハッシュを最終確認した。W-D後の追記はこの実行結果と文書確認の記録だけである。

## 最大常駐量・時間・引き渡し

Rは指定どおり `/usr/bin/time -p` で計時し、同方式からRSSは得られないため、macOSの `getrusage(RUSAGE_CHILDREN).ru_maxrss` を補助値として保存した。Rは4,671,275,008 bytes＝4,454.875 MiB＝4.350464 GiB、Pのreleaseビルドは2,923,986,944 bytes＝2,788.531250 MiB＝2.723175 GiBだった。各記録器が起動した子孫の最大値であり、同時常駐量の合計やOS timeのRSS原値とはしない。PのCLI照合全体のRSSは未計測である。

開始は2026-10-30 07:54:17 JST。終了と外側の所要は[最終状態](final-state.json.gz)に記す。Rの待ち88.48秒、DB再確認2.31秒、Pのビルド31.05秒を含む。読解・記録と待ちは一部重なり、能動時間を厳密には分離計時していない。見込み1〜2時間と4時間の停止条件の範囲内であり、回答待ちはない。

今回の結果を取りまとめへ渡す。四ツールの未照合、F-Qの既存の限界、外部ハンドラ・32ビット等の未確認を保つ。独立レビュー・設計者の受け入れ・保管・集約・タグ・P-final・配布は完了した扱いにしない。private/とそこを指すスキル、docs/todoは読まず、lake build・scripts/check-formal.sh・交換の再書き出しを実行していない。
