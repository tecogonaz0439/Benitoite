# S03 の実装結果

2026-10-25。基準 B_WORK と作業開始時の HEAD は、どちらも `661dbdd34a27576a3ddbc982d1f0f6bf8c5bdbf0`。開始時の差分はなかった。S03 の実装と指定の work を終え、独立レビュー・受け入れを取りまとめへ渡す。

## 変更

- `deny.toml` に RustSec の `db-urls` と空の `ignore` を明記した。既存の licenses・graph は維持し、sources 検査は加えていない。
- `scripts/check/advisories.py` を追加した。二 manifest へ共通設定と `--locked` を渡し、生の stdout/stderr・終了状態と表示単位の終了を分けて保存する。JSON の診断・完了要約・終了状態を照合して、対象別に勧告あり・照合済み0件・未照合を表示する。一方の検出・取得不能・設定エラーでも他方を試す。全体0件は両対象が照合済み0件の場合に限る。勧告あり・取得不能・道具不在は表示と記録を伴う終了0、設定・実行器の誤りは終了1とした。
- `scripts/check.sh` で依存 manifest・二 lock・deny 設定を変える work、差分の有無によらない change/release、全水準の名指しへ接続した。stage の名指しにも `--test` は不要である。旧 only/full と `legacy-commands.json` は変更していない。
- 方針自己検査の既存の表と外部 cargo のダブルを拡張した。07-03、AGENTS、公開の共通雛形、今回の依頼文・計画の古くなる説明をそろえ、preflight の末尾へ実装結果を追記した。実行後の変更は結果・生記録の保存と文書、および check.sh の説明コメント一行だけであり、検査対象の振る舞いは変えていない。

## 検査と終了状態

作業末の環境は `CARGO_HOME=<tmp>` である。先行作業が用意した書き込み可能な Cargo キャッシュを使った。DB の指定は実行器が保存する設定の写しへ `db-path` だけを加えるためのもので、共通設定の原本を編集するものではない。二対象とも同じ写しを使った。

作業末の指定は次のとおりである。同じ指定へ `--dry-run` を付けて確認し、その後 `/usr/bin/time -l` で包んで一度実行した。検査本体の終了はラッパー内で `work-exit.txt` へ別に保存した。

```sh
scripts/check.sh --level work --base 661dbdd34a27576a3ddbc982d1f0f6bf8c5bdbf0 --only policy_selftest,advisories
```

| 実行 | 終了状態・結果 | 外側の時間・記録 |
|---|---|---|
| 上記の dry-run | 0。policy_selftest と advisories、二コマンドと DB の差し替えを表示。外部道具は非実行 | [dry-run.log](dry-run.log) |
| `/usr/bin/time -l` で包んだ上記 work | 検査本体0。方針自己検査25件成功、二対象とも照合済み0件 | time の real は19.94秒。dry-run と起動・保存を含む外側の Python 計測は19.957秒。[work.log](work.log)、[work-summary.json](work-summary.json)、[work-exit.txt](work-exit.txt) |
| 計時ツール | 1。検査終了後に `sysctl kern.clockrate: Operation not permitted` | サンドボックスによる制限で maximum resident set size は取得不能。メモリ計測のための検査の反復は行っていない |
| `git diff --check` と変更した文書の相対リンク・フェンス・末尾空白の静的点検 | 0 | 外側の時間は未計測。Rust/Lean の検査は追加していない |

開発途中には、関係する検査だけを直接実行した。

| コマンド | 結果 | 時間・記録 |
|---|---|---|
| `python3 -B scripts/check/test_policy.py AdvisoriesTests PolicyTests.test_work_mapping_and_all_integration_containment PolicyTests.test_change_mapping_conditional_checks_and_stops PolicyTests.test_release_and_long_runner_connections` | 6件成功 | 外側は未計測、unittest 内部5.892秒。[development-local.log](development-local.log) |
| `python3 -B scripts/check/test_policy.py` | 25件中の複数ケースが失敗。下記の準備・期待値を修正 | 外側は未計測、unittest 内部15.966秒。[development-policy-failed.log](development-policy-failed.log) |
| `python3 -B scripts/check/test_policy.py AdvisoriesTests PolicyTests.test_change_execution_configurations_and_containment PolicyTests.test_work_diff_range_includes_staged_untracked_deleted_and_renamed` | 修正後5件成功 | 外側は未計測、unittest 内部3.359秒。[development-corrected.log](development-corrected.log) |

失敗の原因は、新しい環境変数を除くための一括編集がダブルの条件式にも掛かり、cargo-deny を常に不在と返していたこと、共有の準備へ置いた不要な manifest が既存テストの片付けで消され差分になったこと、change へ増えた照合コマンドの期待値が古かったことである。条件式を直し、準備を二 lock だけに絞り、新しい change の呼び出しを期待値へ加えた。旧集合の固定記録は変更していない。修正後の局所検査と、作業末の全25件で確認した。

## 実際の二照合

`cargo deny --version` は終了0、`cargo-deny 0.20.2` だった。生の記録と共通設定・使用した写しは [advisories/](advisories/) に保存した。[report.json](advisories/report.json) には実際の argv、開始・終了日時、二 lock の前後のハッシュ、DB の情報、生の終了と表示単位の終了がある。

実コマンドは二つとも `cargo deny --format json --log-level debug --manifest-path <manifest> --config <保存した共通設定の写し> --locked check advisories` である。DB は各照合で更新した。

| 対象 | manifest | 生の終了・照合結果 | DB取得日時（UTC） | 実行器が測った外側の時間 |
|---|---|---|---|---|
| ワークスペース | `Cargo.toml` | 0、照合済み・検出0件、IDなし | 2026-10-24T17:59:47.373442Z | 約1.557秒 |
| fuzz | `fuzz/Cargo.toml` | 0、照合済み・検出0件、IDなし | 2026-10-24T17:59:48.232108Z | 約0.851秒 |

両対象の DB は `https://github.com/RustSec/advisory-db`、コミットは `21d909e4c8bd4e14c7aea58bf980c881a0053ab1` である。三つの対象構成は `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl`。機能の指定は共通設定と既存の manifest のままで、全機能への拡大や既定機能の無効化を追加していない。取得不能を0件へ読み替えた結果ではなく、両対象の完了要約が errors/warnings/notes/helps とも0だった。

| 入力 | SHA-256 |
|---|---|
| `Cargo.lock`（前後一致） | `f63fed7d012a331fb653d1f5e7e17a8833dc15ac7c3423ae447b45003968b0d2` |
| `fuzz/Cargo.lock`（前後一致） | `0cca6d39a47673bbb1e4bf42722983a7c7bdbf2cfbe9f75df46163e26842dc0c` |
| `deny.toml` 原本 | `be3a44ae7ba8be1804238592020094f8c49b5e9e9ed2fc0f625d6d72f5ab5d31` |
| 実行時の設定の写し | `26629fab81a7d6c3ccff6fbf99435a1a6add20763862ec5595b7a0b89f547f6e` |

## テストの作成時の関門

守る契約は、検査入口から観測できる選択・二対象への設定/lock不変指定・表示・記録・終了状態である。現実的な退行として、文書だけの change での選択漏れ、一方の失敗での打ち切り、未照合の0件表示、非0終了の一括無視、設定エラーの成功扱い、旧集合の増減を捕まえる。既存の自己検査には三状態の外部出力と二 manifest の接続がなかったため、その境界で表とケースを拡張した。代用するのは外部 cargo だけで、分類と判定は本物のシェルと Python を通す。自己検査からネットワークは呼ばず、テストだけの本番の差し込み口は増やしていない。DB の差し替えは実際のサンドボックス環境でも使った機能である。

既存テストの削除はない。実行器241行を追加、check.sh は33行追加・11行削除、test_policy.py は146行追加・4行削除（作業末の実装状態）。依存の確認に必要な失敗・未照合の区別を同じ入口で確かめ、既存の legacy 固定記録と release_stack の成功10件の要求を保った。

## 計画との差と申し送り

- S03 の範囲・推す案・指定の work に従った。書き込み可能な DB のために共通設定の写しを使ったことと、最大常駐量を取得できなかったことが環境上の差である。新しい勧告はなかった。
- `private/` とそこを指すリンクは読んでいない。このリポジトリの git の変更操作は行っていない。形式化・01-12・07-04、Rust の処理系・テスト・同梱生成物・二 lock は変更していない。言語の規則・主定理・公理について判断を要する点はなかった。
- S04 は最初と最後の照合の公開手順、S05 は独立して呼べるスキルを担当する。二 lock の検出0件だけをツールチェーンの網羅的な照合や、S01/S02 の挙動の受け入れとして扱わない。独立レビューと取り込み・受け入れは取りまとめが行う。
