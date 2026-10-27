# Z01b の結果

着手: 2026-10-27 11:24:59 JST。終了: 2026-10-27 11:39:05 JST。所要時間: 14分06秒。

## 対象と制約

基準 B_WORK・開始時 HEAD は `67d6123c21dc5a47360d3045212f020eafaaf22b`、ブランチは `mod012/Z01b`。開始時の作業ツリーに差分はなかった。Z01b の版上げと候補の照合を担当した。今回の依頼の補足を plan の割り当てより優先し、K2・release 水準・Rust/Cargo/Lean/elan の勧告照合は取りまとめへ渡す。Lean・言語の規則・主な定理・公理は変更していない。`private/` とそこを指すリンクは読まず、Git の変更操作は行っていない。

## 変更

- `crates/benitoite/Cargo.toml` の package.version を一度だけ 0.0.12 へ上げた。根の Cargo.toml に版指定はない。`cargo update --offline -p benitoite` と `cargo update --offline --manifest-path fuzz/Cargo.toml -p benitoite` をそれぞれ一度実行し、終了0だった。二 lock の差分が、benitoite の版の一行ずつだけであることを照合した。依存の一括更新・取得は行っていない。
- Z01a の判断と取りまとめの受け入れに従い、コンポーネントハンドルの上限による受理範囲の縮小を理由に BREAKING_CHANGES へ 0.0.12 を登録した。`language "0.0.11"` は E0908、0.0.12 は受理、それより後は E0907。0.0.12 の移行案内にはゲストのハンドル解放と、局所区間警告・追加の報告欄・derive の確認を含めた。過去の登録と案内は保った。
- README、英語リファレンス、install、同梱 Skill、訳、01-02 の成功例、06-09 の登録表と説明を同期した。0.0.12 の移行節を追加し、過去の移行節と CHANGELOG の 0.0.11 以下が変更前と一致することを確認した。0.0.11 とのハンドル上限の比較も保った。
- CHANGELOG の Unreleased を `0.0.12 (San Benito)` に改め、ソースだけのリリースの冒頭文・`--version` の出力・互換性と移行の表をそろえた。新しい空の Unreleased と性能の増減は書いていない。Z01a の全項目を保持した。
- 成功用の language 宣言・設定・診断の期待値を候補へ更新した。固定の依存ハッシュ三種は、処理系を呼ばずに文書化された二段階の SHA-256 の規則で再計算した。[変更前後](hash-updates.json)に記録した。hash-match と hash-mismatch の計算値の期待、package コマンドの期待値も同期した。
- `cargo run -p benitoite --example gen_skill` は終了0、19.24秒だった。生成参照と bundle.rs は手で編集していない。今回の変更による生成ファイルの差分はなく、作業末の skill_generated でも鮮度の照合に成功した。

テスト変更には test-audit の作成時の関門を適用した。観察する契約は、宣言位置ごとの受理境界・診断位置・最初の該当版・全移行案内の版順である。登録漏れ、旧宣言の誤受理、将来版の誤受理、案内の欠落を、既存の表の拡張で捕まえる。公開範囲や差し込み口を増やさず、新しい重複テストも加えていない。成功入力の版とハッシュの更新は、別の拒否でテストの目的が隠れないようにするためである。

Rust の行数は、本番が +9/−0行、テストが +54/−45行（src 内の cfg(test) 以後と tests をテストとして集計）。テストの削除・監査キャンペーンは行っていない。

## ビルドと実 CLI

既存の書き込み可能なキャッシュ `CARGO_HOME=<tmp>/benitoite-s02a/cargo` を使った。`cargo build --release -p benitoite` は終了0、ビルド表示は1分11秒。derive の読者も候補で照合するため、`cargo build --release -p benitoite --example derive_inventory` を追加し、終了0、1分01秒だった。実 CLI は `<repo>/target/release/benitoite`、derive の読者は同じ release の example を使った。

| 照合 | 結果 |
|---|---|
| `--version`・`--version=json` | 0.0.12。人間向けの二行は `benitoite 0.0.12` と `Unicode 17.0.0`。JSON の Unicode・表示幅 Unicode は17.0.0。build.commit は基準の完全 ID、target は aarch64-apple-darwin、dirty は null、provenance.dirty は notCollected |
| `--licenses` | 終了0。MIT/Apache-2.0 の選択と、第三者ライセンス一覧をこのビルドに含まない旨を出力。通常のソースビルドについての install の説明と一致。正式なバイナリ配布用の一覧を作成したとは扱わない |
| 局所警告の `check --report=json`・`check --diagnostics=json` | Skill の三警告の例で W0401・W0402・W0404 を確認。通常は終了0、`--deny-warnings` は終了2。report は stdout の単一 JSON、stderr は空。JSON Lines は stdout が空、stderr に三件。警告の一次位置・区間・条件付き失敗の注記は保存した報告で確認 |
| `check` の intervalAnalysis | 全体と各 target に存在し、basis は localIntervals。通常時は status:ok、deny 時は checkError。解析と受理を別々に照合 |
| 警告の例の `run --allow-effects=` | 終了0、出力なし。main から呼ばない関数内の警告であり、実行時の失敗を断定しない |
| `test --check --report=json` | 一時入力に @test を一つ追加。通常は終了0、deny 時は終了2。testCheckReport と全体・target の intervalAnalysis を確認。テスト本体は実行していない |
| ファイル／JSON Lines の Log の例 | 英語リファレンスの二つの完全な例を一時領域へ抽出し、check/report と run を実施。宣言上限は File.Write・File.Read・Console.Write・State・Process.Exit。明示した同じ許可集合で終了0。stdout は文書の期待出力と一致し、events.log／events.jsonl のバイト列とも一致 |
| derive の事前拒否 | 通常の check/run は通るファイル単位 uses Log の対象で、JSON と Property の preview が各終了1、derive.file_effects。元の宣言・位置・対象・選択機能を示す。ソースと設定のハッシュは前後一致、確認用ディレクトリは未作成 |
| `fmt --check <入力>` | 一時入力を fmt した後、終了0 |
| `language` の実 CLI | 0.0.11 は E0908・終了2、0.0.12 は終了0、0.0.13 は E0907・終了2 |
| `skill install --project --agent codex` | 一時プロジェクトへ終了0でインストール。ライセンスを含む73文書を、skill list と skill show の JSON、生成元／手書き元、抽出したファイルに照合。全文・バイト数・SHA-256 が一致。producer の版と build は --version=json と一致 |
| 版を固定した URL の見出し | 抽出した inspection.md の v0.0.12 の二 URL と、候補の英語本文の Interval analysis coverage／Local interval warnings を照合。公開タグの URL の解決確認はタグ後に取りまとめが行う |
| ソース配布の対象・除外 | `git archive --format=tar HEAD` をメモリ内で読み、13,976項目を確認。Cargo と二 lock、ソース・設計書・英語リファレンス・Skill・ライセンス・formal を含む。private、docs/todo、reference、Git 管理情報、ビルド生成物を含まない。追跡された Skill の七リンクも private を指さない。HEAD は未変更なので、候補の未コミット内容を収録した正式アーカイブの確認ではない。タグ付きアーカイブは未作成 |

実 CLI の [コマンド・出力・終了状態](cli-evidence.json)、[derive の記録](derive-evidence.json)、[Skill の全文照合後のハッシュ](skill-checks.json)、[一時入力のハッシュ](cli-input-hashes.json)、[ライセンス出力のハッシュ](licenses.sha256)、[配布対象の記録](archive-check.json)を残した。一時入力の本文はリポジトリへ置いていない。

照合用スクリプトでは三つの期待の誤りを修正した。最初はソースビルドの --licenses に第三者一覧があると誤って仮定し、次に二番目のログ例の読み戻す先を events.log とし、最後に Skill の版の値に付く引用符を考慮していなかった。実際の文書と出力に合わせ、第三者一覧なしの表示、events.jsonl、引用符付きの値を正しく照合した。これらは処理系の失敗ではなく、処理系を変更していない。ハッシュ同期用の補助スクリプトも、git ls-files の非 ASCII パスの引用表示に対応せず停止したため、NUL 区切りへ改めて再実行した。

## 作業末の検査

事前の [dry-run](dry-run.log) は終了0。次の九単位を選択した。文書例三種は全統合ターゲットへ含まれるため、別実行を省くという表示を確認した。

```sh
scripts/check.sh --level work --base 67d6123c21dc5a47360d3045212f020eafaaf22b --dry-run
/usr/bin/time -l sh -c 'scripts/check.sh --level work --base 67d6123c21dc5a47360d3045212f020eafaaf22b; code=$?; echo "$code" > <tmp>/benitoite-z01b/work-exit; exit "$code"'
```

本実行は一度だけ行った。検査本体の終了と計時ツールの終了を区別するため、time の内側のシェルから検査の終了状態も保存した。キャッシュと勧告 DB の書き込み先は一時領域を使い、二照合は共通の deny.toml の写しに db-path だけを加えた同じ設定・--locked を使う。

| 単位 | 内容・結果 |
|---|---|
| fmt | cargo fmt --all --check |
| lint_default | lib・tests・examples、既定の gc-mark-sweep での clippy |
| lib_default | 既定 lib 全件 |
| tests_related | --test を省略した全統合ターゲット。spec_examples・reference_examples・skill_docs を含む |
| source_rules | 仮置きの許可・unsafe の許可の規約 |
| skill_generated | gen_skill と生成物の鮮度 |
| spec_tally | 仕様対応の自己検査と集計 |
| licenses | 許諾の設定の一致、cargo-deny のライセンス照合 |
| advisories | ワークスペースと fuzz の二 lock の勧告照合と表示 |

本実行は 2026-10-27 11:29:24 JST〜2026-10-27 11:37:32 JST、外側の時間 **488.004秒**。九単位すべて成功し、検査本体は **終了0**（selected checks passed）。[work.log](work.log) と [終了状態・外側の時間](work-summary.json)を保存した。検査後に変えたのは結果・証拠・勧告の集約記録だけであり、ソース・テスト・文書例・生成元は変えていない。

既定 lib は **1,333件成功・失敗0・ignored 21件**。全統合ターゲットは **40ターゲット・395件成功・失敗0・ignored 10件**。合計 1,728件成功、失敗0、ignored 31件。対象別の件数・時間は [test-counts.json](test-counts.json)。長い対象や形式化の書き出しの ignored は通常どおり実行せず、K2・release を先取りしていない。文書例・Skill の文書・ゴールデンテストも、この全統合実行に含まれる。

`/usr/bin/time -l` の最大常駐量（maximum resident set size）は取得できなかった。サンドボックスが `sysctl kern.clockrate` を拒否し、計時ツール自体は終了1となった。内側のシェルで保存した検査本体の終了は0である。補助の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` は **4,778,672,128 bytes**。これはラッパーの子プロセスの最大値であり、同時使用量の合計ではない。メモリの記録のために検査を反復していない。

依存勧告は二対象とも照合済み・検出0件、対象ごとの生の cargo-deny と表示単位はいずれも終了0。cargo-deny は0.20.2、DB は RustSec のコミット `3279c99911354c400e1d41e47c7d60e39258b147`。取得・照合は2026-10-27 02:37:30〜32 UTC、両 lock のハッシュは前後一致した。[生の出力・共通設定の写し・対象別結果](advisories/report.json)を永続的に保存し、[security-advisories.md](../security-advisories.md)へ追記した。Rust/Cargo/Lean/elan の勧告を照合済みとは扱わない。

実行環境は aarch64 macOS、Rust `1.98.1 (48a229cea 2026-09-01)`、Cargo `1.98.1 (797e8a9bc 2026-08-05)`、既定の gc-mark-sweep。版の実出力は [tool-versions.json](tool-versions.json)。

## 文書と状態の記録

[文書の静的照合](document-check.json)と [追加リンク23件の照合](new-links-check.json)では、過去の移行節の保持、二 lock の限定差分、英語と訳のコード・期待出力のフェンスの一致を確認した。install のシェル内の説明コメントは訳されるため完全一致の対象にしていない。[残した旧版の記述](remaining-version-references.log)は、過去の移行節・互換性の履歴・上限導入前との比較である。

[候補の差分とファイルのハッシュ](candidate-inputs.json)と [manifest・lock・設定・実行ファイルのハッシュ](tool-inputs.json)を保存した。これらは今回の候補の識別用であり、K2 や change/release の結果をこの枝で引用したものではない。取り込み・集約で変わる commit と producer は、その後の実候補で再照合する必要がある。

## 計画との差と申し送り

今回の依頼に従い、K2（check-formal 全体）・release 水準・ツールチェーンの勧告照合は実行していない。取りまとめが候補の取り込み後に担当する。タグ後は二 URL の見出しの解決、集約後は --version=json／Skill の producer と証拠、正式アーカイブは取り込まれた候補の内容と同梱物を再照合する。独立レビューと設計者の受け入れも取りまとめの担当である。

言語の規則・Lean の定理・公理について保留した判断はない。版上げと候補の範囲を越える実装変更は行っていない。

最終の差分確認と `git diff --check` は成功した。保存した記録に手元の絶対パスが残っていないことを確認した。今回の指定範囲は完了し、独立レビューへ渡せる状態である。

## 取りまとめのレビュー（2026-10-27）

受け入れる。版の上げ（Cargo.toml と二つの lock の benitoite の版だけ）、`BREAKING_CHANGES` の 0.0.12 の登録と文言（`modules/text.rs`）とその表のテスト、CHANGELOG の `0.0.12 (San Benito)` の節が 0.0.11 の形にそろうことを確かめた。K2・`--level release`・ツールチェーンの勧告の再照合は、取り込みの後に取りまとめが本体で行い、`z01/results.md` に書く。
