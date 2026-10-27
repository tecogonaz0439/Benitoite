# S04 の実装結果

2026-10-25。基準 B_WORK と開始時の HEAD はともに `100ab3753ed99f954f7b93f9a8329e2554de54ae`、ブランチは `mod012/S04`。開始時に差分はなかった。

## 変更

AGENTS.md「改造の進め方」、公開の実装プランと共通依頼文の雛形、公開の git-workflow を更新した。改造のディレクトリを作った後、対象と実装プランの確定前に依存とツールチェーンの勧告を評価し、組み込むか別に対応するかを設計者が決める。照合日・対象・根拠・未照合の範囲・判断を改造の記録と計画へ残し、取りまとめが起動前に確認して担当へ必要な条件を写す。候補でも二 lock と Rust/Cargo・Lean/elan の固定版を再照合し、新しい勧告・未照合を表示・記録・報告する。新しい勧告を検査の不合格条件や受け入れの停止条件にせず、次の改造の最初の判断へ引き継ぐ。最初に対応すると決めた項目の完了条件は保つ。

CHANGELOG の Unreleased に TLS・Wasmtime の修正版、Store ごとの取っ手の上限と R0906、照合と公開手順、保存記録のパス置換を記した。版上げと性能の増減の記述はしていない。

補足に従い `scripts/check/advisories.py` の保存記録のパスを置換した。照合と実ログからの DB コミットの取得を終えてから、stdout/stderr・設定の写し・report.json のリポジトリの根を `<repo>`、ホームを `<home>`、一時ディレクトリを `<tmp>` にする。macOS の `/var` と `/private/var`、`/tmp` と `/private/tmp` の表記に対応し、長いパスから置換する。実行に使う設定と表示は元のパスを保ち、出力の他のバイトと終了状態は変えない。report.json の `path_redaction` に置換の実施と、設定の SHA-256 が置換前の入力の値であることを記す。07-03 の記録の説明を同じ状態へそろえた。

## 版と出典の照合

| 対象 | 現在の状態と確認した根拠 |
|---|---|
| TLS と二 lock | rustls `0.23.46`、rustls-webpki `0.103.16`、webpki-root-certs `1.0.10` が両方で一致。03-01 の版・provider・検証器の説明は S01 の更新後と一致し、追加の訂正は不要だった。修正版の範囲は [0349](https://rustsec.org/advisories/RUSTSEC-2026-0349.html)・[0382](https://rustsec.org/advisories/RUSTSEC-2026-0382.html)・[0383](https://rustsec.org/advisories/RUSTSEC-2026-0383.html)でも再確認した |
| Wasmtime と二 lock | Wasmtime `49.0.4`、Cranelift `0.136.4`、内部クレートと Pulley は `49.0.4`。両 lock の関連25パッケージがこの版で一致し、[49.0.4 のリリース](https://github.com/bytecodealliance/wasmtime/releases/tag/v49.0.4)と配布ソースを照合した。直接の wasmparser/wasm-encoder は `0.258.3` のまま |
| 03-01・02-09・03-10 の出典 | 取得済み49.0.4の配布ソースの build.rs、Cargo.toml、component の call/post-return・hostcall fuel・非公開エラー・取っ手の上限と原因の文言を確認した。シグナル・Mach ports・config の既存の行アンカーも該当箇所を指す。現在の説明に旧版のリンクは残っておらず、追加の訂正は不要だった |
| 02-09 の過去の実測 | 2026-10-13 の Fuzzy の燃料の測定は Wasmtime `49.0.2` の記録として保った。新しい版の測定へ読み替えていない |
| 02-09・02-10・03-10 の取っ手 | Store ごとの100,000個の上限、drop 後の再利用、必要数を使わない R0906 が S02b の実装と対応する。追加の訂正は不要だった |
| 固定するツールチェーン | Rust は rust-toolchain.toml の `1.98.1`。Lean/elan の候補の版は Lean 担当の引き渡し情報から受け取る手順にした。本作業ではツールチェーンの勧告の網羅的な照合を行っていない |

第6弾の最初の照合は [preflight の P2](../preflight.md#第6弾の最初の依存の勧告照合p22026-10-24)であり、2026-10-24 に二対象で同じ19件を検出し、設計者が第6弾へ組み込むと決めた。ツールチェーンまで網羅した記録には広げない。先行 S01〜S03 の記録と、S02b 後の short を B0 と実行できず B1 へ切り替えた[取りまとめの判断](../results.md#s02b-の後の-short-と基準の切り替え取りまとめ2026-10-25)を確認した。先行検査を別の状態へ引用する受け入れ判断はしていない。

## テストの作成時の関門と途中の確認

守る契約は、検査入口が保存するすべての勧告記録から手元のパスを伏せ、分類・DB 情報の取得・実コマンドのパスを保つことである。現実的な退行は stdout/stderr・report.json・設定のいずれかの置換漏れと、DB の実パスを先に伏せてコミットを取得できなくなることである。既存の自己検査にはパスを含む出力のケースがなかったため、実際のシェルと Python の入口から保存ファイルを読む一件を追加した。代用は既存の外部 cargo だけで、Git・Python・分類と保存処理は本物を使う。本番の差し込み口は増やしていない。

| コマンド・確認 | 終了と結果 | 外側の時間 |
|---|---|---|
| `python3 -B scripts/check/test_policy.py AdvisoriesTests.test_saved_evidence_redacts_local_paths_after_database_lookup`（修正前） | 1。report.json に絶対パスが残るため意図した失敗を確認 | 未計測、unittest 内部0.757秒 |
| `python3 -B scripts/check/test_policy.py AdvisoriesTests`（修正後） | 0、4件成功。既存の設定の写しの検査は、伏せたパスを再度開かず、保存ディレクトリから読むように直した | 未計測、unittest 内部3.061秒 |
| 二 lock と49.0.4配布ソース・行アンカーの読み取り確認 | 0。上表の版と根拠が一致 | 未計測 |

読み取り確認の最初の一時スクリプトは Python 3.9.6 に tomllib がないため失敗した。追加の依存は入れず、lock の name/version の行を読む確認に直して成功した。リポジトリの実装や検査の不具合ではない。

## 作業末の検査

補足で実行器も変わるため、plan.md の S04 の work 行を方針自己検査と実際の二 lock の照合へ更新した。同じ基準と名指しの dry-run を確認後、次の work を `/usr/bin/time -l` で包んで一度実行した。検査本体の終了値は内側のシェルで別に保存し、計時ツールの終了と分けた。

```sh
scripts/check.sh --level work --base 100ab3753ed99f954f7b93f9a8329e2554de54ae --only policy_selftest,advisories
```

| 実行 | 終了と結果 | 外側の時間・記録 |
|---|---|---|
| 上記の dry-run | 0。方針自己検査と勧告の実行器、二 manifest の共通設定・lock 不変の指定を確認 | [dry-run.log](dry-run.log) |
| `/usr/bin/time -l` で包んだ work | **検査本体0**。方針自己検査26件成功、失敗0。勧告は二対象とも照合済み・検出0件 | time の real **19.91秒**。dry-run と起動・保存を含む外側の Python 計測は **19.928秒**。[work.log](work.log)、[work-summary.json](work-summary.json) |
| 計時ツール | 1。検査の終了後に `sysctl kern.clockrate: Operation not permitted` | サンドボックスの制限で **maximum resident set size は取得不能**。メモリ計測のための反復はしていない |
| 保存記録のパスの確認 | 0。実照合で保存された9ファイルに手元のリポジトリ・ホーム・一時ディレクトリの絶対パスなし。report.json に置換の実施と DB のコミットあり | 未計測。生記録と設定は [advisories/](advisories/)、要約は [report.json](advisories/report.json) |

実行時は `CARGO_HOME=<tmp>/benitoite-s02a/cargo` と `BENITOITE_ADVISORY_DB_PATH=<tmp>/benitoite-s04/db` を使った。共通設定の原本は変えず、有効な写しに db-path だけを加え、二対象へ同じ写しを渡した。対象構成は共通設定の `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl` で、機能を選ぶフラグは追加していない。道具は `cargo-deny 0.20.2`、両方の DB は `https://github.com/RustSec/advisory-db` のコミット `21d909e4c8bd4e14c7aea58bf980c881a0053ab1` だった。今回取得・更新して照合し、同じ lock だけを理由に先行結果を引用していない。

| 対象 | DB取得日時（UTC） | 生の終了・状態 | lockのSHA-256（前後一致） |
|---|---|---|---|
| ワークスペース | 2026-10-24T18:10:35.459551Z | 0、照合済み・検出0件、IDなし | `f63fed7d012a331fb653d1f5e7e17a8833dc15ac7c3423ae447b45003968b0d2` |
| fuzz | 2026-10-24T18:10:36.295944Z | 0、照合済み・検出0件、IDなし | `0cca6d39a47673bbb1e4bf42722983a7c7bdbf2cfbe9f75df46163e26842dc0c` |

S03 の照合から新しい勧告はなかった。この結果をツールチェーンの網羅的な照合や各攻撃入力の再現の証拠にはしない。

実行器は追加41行・削除1行、方針自己検査は追加41行・削除1行である（空行とコメントを含む）。既存テストの削除、テストだけの本番 API・フラグ・ラッパーの追加はない。今回候補にして残したテストや監査による削除はなく、保存記録の契約を一件で確かめた。

変更した Markdown 9ファイルの相対リンク131件・アンカー・フェンス・末尾空白・手元の絶対パスと非公開のリンクの不在、および `git diff --check` の静的確認も終了0だった。読み取りの Python での外側の時間は0.063秒。S05 が作る四箇所の参照先だけは未作成として区別した。作業末の work 後に変えたのは結果と記録だけであり、実装と検査の入力は変えていない。

## 申し送り

- 公開手順の具体的な照合方法のリンク先 `.claude/skills/security-advisories/SKILL.md` は S05 が作る。S04 末では未作成であり、AGENTS・二雛形・git-workflow の四箇所の参照を S05 が閉じる。S04 はスキル本体・リンクの新設へ広げていない。
- CRL/OneCRL と Linux 利用者向けの ca-certificates 更新の案内は docs/todo の TODO-284、sources 検査・Dependabot・独立した Lean 検査器の評価は TODO-286 の残件として取りまとめへ渡す。依存の修正版だけで一般の失効確認を実装したとは扱わない。
- 候補での二 lock と Rust/Cargo・Lean/elan の勧告の再照合は Z01b の担当である。Lean/elan の候補の版の引き渡し情報を受け取り、未取得の版や未照合の範囲を記録する。
- formal/・01-12・07-04、Rust の処理系・テスト・生成物・依存と二 lock は変更していない。言語の規則・主定理・公理の変更が要る点はなかった。private/ とそこを指すリンクは読まず、このリポジトリの git の変更操作は行っていない。
- 独立レビュー・取り込み・受け入れは取りまとめの担当であり、本作業の自己点検を独立レビューの完了としない。

計画からの差は、依頼の補足でパス置換と退行一件を加え、それに合わせ work の割り当てを二単位の名指しへ更新した点、および上記のメモリ計測の環境制限である。S04 の実装と担当する検査を完了した。S05 での参照先の作成と、独立レビューを取りまとめへ渡す。
