# M2b 版・通常入力・固定ハッシュの同時更新の結果

## 目的と変更

開始時の HEAD は `1107a8f66b58b17352a344a60f0788c01e3cba30`、ブランチは `mod254/M2b`、作業ツリーに差分はなかった。M2a の編集73件の元の SHA-256 と置換件数が全件一致することを確かめ、提供版を一度だけ `0.0.7` へ上げた。変更ファイルと前後のハッシュ、再生成対象、残る旧版表記のファイル別の分類は [inputs.json](inputs.json) に記録した。

| 対象 | 変更 |
|---|---|
| `crates/benitoite/Cargo.toml`、ルート `Cargo.lock` | 自身の版だけを更新。lock の依存・checksum・解決結果は不変 |
| 通常の testdata 50件、Rust の生成入力と厳密な期待値 | 通常宣言を0.0.7へ更新。`runtime_builtins.rs` と tools の参照解11本には固定宣言がなく、変更不要と再確認 |
| `src/modules/tests.rs`、版診断の golden | entry/config/dependency の各場所で旧0.0.6の拒否、現行0.0.7の受理、未来0.0.8の拒否を検査。旧0.0.4/5/6の主文・全 notes/helps・順序・空の edits を厳密に比較 |
| `src/modules/hash.rs`、`tests/package_command.rs`、hash-match | 変更後の全入力を Python hashlib で独立計算し、正の固定ハッシュ三組を更新 |
| hash-mismatch の診断 | R30に従い、共有する依存の変更後の `computed:` だけを更新。入力と `expected:` のゼロのハッシュを保持 |
| `CHANGELOG.md`、現行設計3章、英語リファレンスと導入 | Unreleasedを `0.0.7 (San Benito)` へ改題。通常宣言・現行版・版境界・互換性の変更表を更新し、ソースのみの提供と明記 |
| Skill の生成物56件 | `gen_skill` から再生成。全件で既存内容と一致し、二回目の生成も同一。手書き5文書と版の placeholder を保持 |
| `decisions.md`、本ディレクトリ | R30と実施結果・確認表・[CLIの実測](cli-observations.json)を記録 |

型・公開シグネチャ・JSON の形式の変更はない。提供版の更新により、M1で登録済みの0.0.7の互換性の変更が実際の版検査へ適用される。処理本体のロジック、構文・型の規則・脱糖、formal/ は変更していない。

## 固定ハッシュと Skill

| 対象 | 変更後の SHA-256（`sha256:` の後の値） |
|---|---|
| hashkit（hash-matchの固定値とhash-mismatchの計算結果） | `5d12e17f6e1522ec49837e741d7b5a28145b94f6aa6ab95c6b72b683c534dd65` |
| modules-hash-fixture | `dfa96801c59264be45ff137fedbfd84bf176c3941b66c751cadbca0692c82fec` |
| package-command-words | `ec9bf643e50197c98e9aa736bb08ef612cf253cb682ef4936f800cf57dacbbed` |

hashkitはディスクの実入力、残る二組はRustのCONFIG/READとfixtureの実バイト列を取り出して検算した。UTF-8の相対パス順、各ファイルのhashと二つの空白・パス・LFからなる集約行、CRLF・非UTF-8・末尾改行を保った。M2aの予定値と三組とも一致した。報告用の不変な単一本文のhash `14c52fc2838594adb45ee1ec151457617d8e5ed2347dbb1ba70d6570ced86307` も、実際のRust文字列から独立計算して一致した。

0.0.7の実行ファイルの `skill list/show/install` を一時ディレクトリで照合した。全62文書のインストール後のバイト長とhashが一覧と一致し、`SKILL.md` のshowとインストール後の本文も一致した。版置換後の `SKILL.md` は26,298バイト、SHA-256は `4999bf2f2b69b2d6d37390d45aa62e2dc5d43a4820395fb0789fc2c255802a7e` だった。配布へ日本語訳を含めていない。

## 残る0.0.6の全件分類

版更新後の `git grep -n '0\.0\.6'` の残り72ファイル・477行を全件分類した。一致行数は同じ行の複数出現を一件として数える。新規のm2b記録は、この時点では未追跡なので集計外である。取り込み後のm2b記録も過去の基準・移行・実測を記した作業記録として保持する。全パスと行番号は inputs.json の `oldVersionSearch.files` にある。

| 分類 | ファイル数 | 一致行数 | 保持する理由・担当 |
|---|---:|---:|---|
| docs/archive | 26 | 227 | 読み取り専用の過去資料 |
| CHANGELOG | 1 | 5 | 旧版の節4行と、新版の移行前の宣言の説明1行 |
| 旧版の検査と全文診断 | 3 | 14 | modules/package.rs、modules/tests.rs、older-languageの診断。合成版の検査と実版での旧宣言の拒否を保持 |
| 旧版の整形の検査 | 3 | 4 | fmt/headerの入力・出力、fmt_command.rs。版の綴りを変えない整形の契約 |
| 現行設計の過去の変更の説明 | 3 | 4 | 01-03・06-09の0.0.6の変更表と、06-01の診断/testResults形式1の説明 |
| 今回の依頼・判断・計画・調査・実測の記録 | 29 | 192 | 移行前の基準値と観測時の出力。過去のd3/z6の採取記録も保持 |
| 日本語リファレンスと導入 | 2 | 18 | M3aへ引き渡し。M2bでは版の数字も含めて変更しない |
| 日本語Skill | 4 | 4 | M3bへ引き渡し。M2bでは翻訳元の版の数字も変更しない |
| harness-response.md | 1 | 9 | R28の0.0.6から採取した実出力例。M3b/F2で最終ビルドから再採取 |
| 未分類・意図しない通常入力の取り残し | 0 | 0 | 上記の保持・後続担当が明確なもの以外は残っていない |

`docs/ja` は本文と版の数字を分けずにM3a/M3bで更新する。翻訳元が旧版のまま数字だけを0.0.7に変えない。fuzzの既知の旧 `Cargo.lock` は別件としてバイト列を保持し、再解決していない。referenceとアーカイブは変更していない。

## 共通の関門Kと検査

test-auditの作成時の関門では、版境界を所有する既存の読み込みのテスト表を拡張した。守る契約は各ヘッダ位置での旧版・現行版・未来版の受理と診断の全件・全文・順序である。版だけを変えて直前の版を受理してしまう退行や、最初の変更しか案内しない退行を捕まえる。既存の合成版の検査は実版との接続を確かめないため、既存の実版の表で確かめる。本番のテスト専用APIやフラグは不要であり、追加していない。

既存のassert・ignoreの数を維持し、期待値の部分一致化やテストの削除はしていない。意図して変わる期待値はM2aの表とR30に記録した。処理本体のコードの行数増減は0、Rustのテストの行数は差し引き11行増である。新しいテスト関数は追加せず、既存の表へ対照例を一行追加した。

実施前に検査名を知らせた。gc-stressを含めず、既存のignoreを維持した。scripts/check.shはdry-runを含め依頼で禁止されているため実行していない。分類の分岐を読むと、今回の変更はrust・licenses・spec_examples・spec_coverage・skill・reference_examplesを選び、分類外・long/heap/formalの追加には当たらない。これはdry-runの実績ではない。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存21 ignored。124.17秒 |
| 指定の9統合テスト | 104 passed、0 failed。107.86秒 |
| `cargo test --workspace --all-targets` | 直列の再実行で2631 passed、0 failed、既存49 ignored（48スイート）。437.55秒 |
| `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify --all-targets` | 2645 passed、0 failed、既存49 ignored（48スイート）。603.66秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| gen_skill | 56件を二回生成し、元の内容とも一致 |
| Pythonによる独立照合 | 編集前の73件と置換件数、正のhash三組、R30の診断、不変の単一本文hash、参照解11本とruntime_builtins.rs、生成56件、lockの変更範囲を確認して一致 |
| CLIの版境界 | 0.0.6はE0908・2、0.0.7は受理・0、未来0.0.8はE0907・2、無宣言は受理・0 |
| CLIの版とSkill | 版0.0.7、formatsの全9キー、Skill全62文書の長さ・hash・インストール後の本文が一致 |
| 文書・差分 | 変更した文書の相対リンクの宛先、JSON、表、`git diff --check`を確認 |

9統合テストのコマンドは `cargo test -p benitoite --test package_command --test golden --test cli_process --test test_command --test runtime_builtins --test reference_examples --test skill_docs --test skill_examples --test spec_examples` である。最初の実行はgoldenのR30の計算結果のhashだけで失敗した。補正前の入力とゼロの期待hashを保ち、診断のcomputedだけを更新してから同じコマンドを再実行した。

全ターゲットの最初の既定構成の実行では、`interrupt_process` の `sigint_at_sort_end_overrides_a_unit_return` と `sigint_at_sort_end_overrides_a_result_error_return` が準備通知の30秒待ちで失敗した。両構成を同じtargetディレクトリで並行実行したため、実行ファイルの差し替えや負荷が影響した可能性がある。heap-verify構成の全検査の成功後、ほかのCargo検査が動いていない状態で既定構成の同じコマンドを再実行し、これら二件を含む全48スイートが成功した。再実行に際してソース・テスト・30秒の上限・スレッド数の指定は変更していない。今後は構成を直列にして実行する。

## 計画との差と申し送り

M2aの73件にhash-mismatchの診断を一件加えた点が差である。最小の判断をR30の推す案として追記した。正の固定値三組だけでなく、負の診断にも共有入力の計算結果が含まれることを後の版更新時に確認する。公開契約は変わらないため、harness-responseの公開形式の修正は不要である。

コミット、docs/todoの編集、保管・タグ・公開は行っていない。scripts/check.sh・gc-stress・長いテストの明示実行・heap/full・LLMを呼ぶ評価は実施していない。formal/に触れておらず、lake buildの条件に該当しない。個別の検査の成功を段末・G7・公開の完了とは扱わない。

- M3a/M3b: 日本語訳の版・本文・例を英語正へ合わせ、R29のinspectionの新訳も追加する。
- M3b/F2: 最終ビルドから回答文のproducer/build・ソースhash・Skillの長さ/hashを再採取する。今回のCLI実測を公開済みのタグの証拠にしない。
- オーケストレータ: コミットとsan_benitoへの取り込み、scripts/check.sh・gc-stressと段末の追加検査、G7・最終検査を行う。licenses・spec_coverageも共通の検査で確認する。
