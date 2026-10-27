# Z01a の結果

着手: 2026-10-27 11:06:15 JST。終了: 2026-10-27 11:23:39 JST。所要時間: 17分24秒。

基準 B_WORK: `dbd5b64432c04699a21a43b77abdf2e00bf9d348`。ブランチ: `mod012/Z01a`。開始時の作業ツリーに差分はない。

訳の同期・互換性判断・CHANGELOG の Unreleased・Z01b への引き渡しを担当する。言語の規則・Lean・Rust のソース・版の数字は変更しない。

## 変更と訳の照合

正としたのは、集約 results.md の「訳の引き渡し」、U03b の translation-inventory.json（手書き4ファイル81項目）、U03R の追加一覧（10項目）、G01R の検査方法の追加と、現在の英語原文である。過去の一覧の行番号だけでなく、原文の見出しと本文を照合した。生成14ファイルの参照には訳を作らず、同梱の Skill に日本語を加えていない。

| 同期先 | 同期した内容 |
|---|---|
| `docs/ja/reference/benitoite.md` | 検査報告の共通・対象の追加欄、区間解析の範囲と件数・予算・使用量・集計、局所の警告の全節、幅付き整数の既存の定数警告との区別、Log のファイル/JSON のコード・出力・失敗・エフェクト、HTTP の未知の値と check の例、derive の事前拒否と現行版、Range の function summary |
| `docs/ja/skill/SKILL.md` | 診断から警告例への案内、coverage と受理条件の分離、未知・未対応・予算停止、版を固定した英語リファレンスへの参照、Log の出力先、derive の事前拒否・純粋な対象への移動・現行版と再確認の手順 |
| `docs/ja/skill/references/idioms.md` | 警告の完全なスクリプトと説明の表、一次位置と条件付きの失敗、Range の成功値の例、HTTP の小節への移動と案内、ログのテキスト/JSON の全例・期待出力、G01R のゴールデンでの検査の説明 |
| `docs/ja/skill/references/inspection.md` | 導入、追加欄、受理条件の正となる英語参照、局所の区間解析の全節（coverage・件数・段停止・使用量・集計・deny-warnings・限界・版固定の二リンク） |

coverage は、本体を持たない対象が件数0の `all`、一つ以上ある本体が全て型検査で無効なら `none`、有効・無効の混在は `some` という区別を同期した。W0404 の一次位置は `n: n` のラベルでなく値の式 `n` である。HTTP の例は小節へ移し、旧位置には案内だけを置いた。function summary・対象構文の評価関係・区間解析の訳語は用語集にそろえた。今回の訳に到達記録を新たに導入する原文はない。

コンポーネントハンドルの上限は、既存の CHANGELOG と 02-09・03-10、`external/runtime.rs` の専用定数・共通の Store 作成・統計で照合した。英語リファレンスの実行上限と Skill の WIT の節にも、同時生存100,000個・状態を持つ呼び出し間の保持・R0906・必要数を表示しないこと・`resource.drop` による再利用・統計の `component_handles` を追記し、対応する二つの訳を同期した。用語は「コンポーネントハンドル（component handle）」とし、言語の外部ハンドルだけを数えるものではないと説明した。英語の変更はこの二段落と CHANGELOG だけである。

## 互換性の判断と Z01b の担当

この表は RV-G 軽7、plan の Z01a、D6・D10〜D12・D22・D28、過去版の CHANGELOG と 06-09、`modules/package.rs` の登録表を踏まえた判断である。CHANGELOG の移行表への掲載と、言語の版の E0908 の登録を区別する。

| 0.0.11 からの変更 | CHANGELOG の移行表 | BREAKING_CHANGES と理由 |
|---|---|---|
| コンポーネントハンドルの同時生存数を Store ごと100,000に制限する | **載せた**。従来成功できたゲストが R0906 で止まる。勧告への対応であり、不要なハンドルの解放が対処となる。メモリ・転送・コアの表の上限の変更では回避できない | **0.0.12 の登録が必要**。0.0.7 の環境変数の制限などと同様、通常実行で受理する範囲を狭める。既定値任せにも、警告だけの追加にも該当しない。登録の実装は Z01b が版上げと同時に行う |
| W0401/W0402 の区間への拡張、W0404 の追加、解析の全体予算による後続警告の欠落 | **載せた**。`--deny-warnings` で同じソースの検査結果が変わりうる。無関係な定義の追加による変化も説明した | **警告の追加自体を理由には登録しない**。通常の型・エフェクト検査の受理を保つという D6 と計画の判断に従う。警告がないことや `all` を成功の証明にしない |
| ファイル単位の `uses` を持つ対象への JSON/Property derive の事前拒否（既存領域を含む） | **載せた**。preview の受理と成果物を書き始める前の振る舞いが変わるため、移行方法が要る | **この変更は登録しない**。D10〜D12 の設計者の決定どおり、受理入力の生成本文・意味ハッシュ・記録と生成器版を保つ。Show/Order だけの対象は受理する。処理系の版上げと derive の版は別である |
| 報告と対象への `intervalAnalysis` の追加 | **載せた**。厳密な読者は未知の欄を拒む可能性があり、読者の対処を明示する | **登録しない**。追加欄であり、既存の必須欄、schema 1/2、status、complete、受理条件を変えない。診断 JSON Lines は版1のままで集計行も追加しない |
| W0401/W0402 の注記・副位置・文言、W0404 の診断の追加 | 上記の警告の行で説明する。位置・推論区間・条件を読む案内を置いた | 登録しない。警告の条件の拡張とその説明であり、既存の定数警告を優先する。表示する文言そのものを構文の受理と混同しない |
| `--wasm-stats` の `reached_limits.component_handles` と R0906 の必要数を持たない variant | 上限の行と実行上限の説明で扱う。別の重複行は作らない | 上限による互換性境界に含める。既存の四資源の必須欄を変更せず、上限超過時の新しい報告を追加する |
| Log.formatRecord の公開、ログの例 | 移行表には載せず、Unreleased の項目に載せた | 既存の書式・改行・フィルタの振る舞いを変えない純粋関数の公開であり登録不要 |
| TLS/Wasmtime の修正版、勧告の表示・記録、examples の lint、版説明の移動 | 既存の Unreleased の4項目を保ち、lint と版説明を補った。TLS/例外機能について未確認の受理変更を作らない | この作業で確認できた通常実行の制限はコンポーネントハンドル上限である。既存の provider/verifier・同期構成・例外対応を保つ。勧告の未照合は0件や無影響とせず、候補の照合は Z01b に渡す |

**英語リファレンスの 20 Compatibility に 0.0.12 への移行節、06-09 の表に 0.0.12 の行が必要である。** 理由はコンポーネントハンドル上限の通常実行への制限である。Z01b は BREAKING_CHANGES の登録と要約・移行文、両文書の現行の受理説明、CHANGELOG の language の移行行、対応する訳を同じ候補へそろえる。この枝では未実装の受理表を現行仕様として書かない。

登録後は `language "0.0.11"` とそれ以前が E0908、`"0.0.12"` が受理、それより新しい宣言が E0907 となる。根・依存を独立に照合し、宣言より後の該当する全変更を版順に案内する既存規則は保つ。移行ではソースと依存を確認し、ハンドルの寿命と警告を見直してから宣言を**現在の処理系の版**へ、依存のハッシュを現在の内容へ更新する。宣言の省略は現在の規則を使い、ソースを自動移行しない。旧版の案内の更新先を0.0.12へ一括置換しない。

## CHANGELOG と版上げ対象の引き渡し

Unreleased の既存4項目を保ち、区間解析と W0401/W0402、W0404、`intervalAnalysis`、`Log.formatRecord` と出力先、derive の事前拒否、examples の lint・版説明の移動を補った。移行表は上の判断に対応する4行である。コンポーネントハンドルの説明を既存項目と別の新規項目に重ねていない。性能の増減と版の見出しは追加していない。

`git grep -n '0\.0\.11'` は523ファイル・1,078行に一致した。全件と扱いは [版上げ対象の一覧](version-inventory.md)・[全ファイルと行の記録](version-inventory.json)にある。過去の記録と比較元の版として保つファイルを除く85ファイルを、更新・照合の一覧にした。Cargo の版、二つの lock、README、英語リファレンス・導入手順・Skill と訳、language の成功入力・診断・依存ハッシュを含む。検索に出ない `Version(0, 0, 11)` の登録表、Cargo から作る --version/producer、derive の版を据え置く点も一覧に書いた。

版上げ後の lock の同期は、`cargo update --offline -p benitoite` と `cargo update --offline --manifest-path fuzz/Cargo.toml -p benitoite` に限定する。一括更新せず両方の差分を確認する。キャッシュが不足したら不足を確認して取得し、同じ対象限定のコマンドを使う。

Z01b は、版上げと生成後の work、最終の関係状態の K2・release、二 lock と Rust/Cargo/Lean/elan の候補の勧告照合と `security-advisories.md` への追記、実 CLI・抽出 Skill・producer・同梱物・配布・移行案内の照合を担当する。`inspection.md` の v0.0.12 の二リンクに対応する `interval-analysis-coverage` と `local-interval-warnings` の見出しは候補の英語本文にある。タグ前は候補のコミットで、タグ後は公開した v0.0.12 で解決することを取りまとめが照合する。集約で変わる build のコミット情報と証拠も、集約後に再照合する。

## 検査

基準と開始時・検査時の HEAD は `dbd5b64432c04699a21a43b77abdf2e00bf9d348`。Rust `1.98.1 (48a229cea 2026-09-01)`、Cargo `1.98.1 (797e8a9bc 2026-08-05)`、aarch64 macOS、既定の構成で実行した。書き込み可能な既存キャッシュ `CARGO_HOME=<tmp>/benitoite-s02a/cargo` を使った。作業末の指定は一度だけ実行し、先に同じ指定の `--dry-run` で六単位の選択と理由を確認した。

```sh
scripts/check.sh --level work --base dbd5b64432c04699a21a43b77abdf2e00bf9d348 \
  --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related \
  --test skill_examples --test stdlib_doc_examples --dry-run

/usr/bin/time -l scripts/check.sh --level work --base dbd5b64432c04699a21a43b77abdf2e00bf9d348 \
  --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related \
  --test skill_examples --test stdlib_doc_examples
```

実行記録は [dry-run.log](dry-run.log)、[work.log](work.log)、[work-summary.json](work-summary.json)。dry-run は終了0。本実行は 2026-10-27 11:21:22〜11:21:46 JST、検査本体は**終了0**（`selected checks passed`）、外側の時間は **24.162秒**である。計画の見込み3〜10分より短く、既存のビルド・依存キャッシュを使用した。

| 単位・中身 | 成功 | 失敗 | ignored |
|---|---:|---:|---:|
| tests_related: Skill の手書き文書例・警告例の一致（skill_examples） | 4 | 0 | 0 |
| tests_related: 標準ライブラリの文書例（stdlib_doc_examples） | 1 | 0 | 0 |
| spec_examples: 言語仕様と付録の例 | 7 | 0 | 0 |
| reference_examples: 英語リファレンスの例 | 1 | 0 | 0 |
| skill_docs: Skill の生成文書・構成の契約 | 8 | 0 | 0 |
| skill_generated: gen_skill の再生成と鮮度 | 成功、生成参照・bundle.rs に差分なし | 0 | — |
| spec_tally: 対応集計の自己検査と集計 | 成功。未記入の初回完了条件なし | 0 | — |

統合テストは合計21件成功、失敗0件である。spec_tally が表示するテスト参照のない節の一覧は集計の情報であり、検査の失敗ではない。Rust の全 lib・clippy・Lean・K2/release を追加していない。

最大常駐量（maximum resident set size）は `/usr/bin/time -l` では取得できなかった。`time: sysctl kern.clockrate: Operation not permitted` により、計時ツール自体の終了は1である。内側のシェルで検査本体の終了を別に保存し、0であることを確認した。補助の `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` は **1,401,798,656 bytes** だった。これはラッパーの子プロセスの最大値であり、同時使用量の合計ではない。計時のための検査の反復は行っていない。

文書の静的照合は [document-check.log](document-check.log) に保存した。英語と訳のコード・期待出力は、リファレンス105、Skill 4、idioms 64、inspection 2のフェンスが順序も含めて一致した（Skill の訳で従来から表示する frontmatter の text を除く）。U03b のコード・出力12項目と U03R の1項目も、原文全文が訳に存在することを確かめた。本文と表は、上の同期表に挙げた原文の各ブロックを読んで照合した。変更 Markdown の相対リンク・見出し参照・フェンス・非公開リンクと手元の絶対パスの不在、既存の Unreleased の4項目の保持、二つの固定リンク先に対応する見出し、`git diff --check` も成功した。

## 計画との差と完了の範囲

Z01a の訳・CHANGELOG の下書き・互換性判断・版上げ対象の引き渡しと、指定の検査は完了した。範囲の追加は、上限の説明が不足していた英語の二段落と対応する訳の同期であり、処理系の振る舞いを変えていない。環境による差は、計時ツールの最大常駐量を取得できなかった点である。検査後に変えたのは本結果と記録だけであり、検査対象の英語本文・例・生成元は変えていない。

0.0.12 の版上げ・互換性の登録と受理表・候補の照合・K2/release は Z01b、独立レビュー・受け入れ・集約とタグ後の再照合は取りまとめの担当である。Z01a で保留した言語の規則・Lean の定理・公理の判断はない。Rust・Lean・版と二つの lock に差分はなく、`private/` とそれを指すリンクは読んでいない。Git の変更操作も行っていない。

## 取りまとめのレビュー（2026-10-27）

受け入れる。CHANGELOG の Unreleased の追加と移行表の4行、英語リファレンスと Skill に足したコンポーネントハンドルの上限の段落、訳の4ファイルの差分を読んだ。コンポーネントハンドルの上限で 0.0.11 から受理範囲が狭まるので BREAKING_CHANGES に 0.0.12 を登録する判断は、過去の版の前例（版ごとに受理の境界を上げる）と合い、推奨どおりとする（設計者は外出中のため取りまとめが判断し、報告する）。版の見出し、Unreleased の中の空行、`language` の移行行は Z01b が 0.0.11 の節の形へ整える。
