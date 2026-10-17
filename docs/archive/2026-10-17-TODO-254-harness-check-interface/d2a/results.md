# D2a 英語リファレンスと導入の手順

## 目的と変更

利用者向けの英語文書を、実装済みのハーネス向け CLI と保証の範囲へ揃えた。開始時のブランチは `mod254/D2a`、HEAD は `6de12f531efcec22880c663f949dfd8123c56a15`、作業ツリーに変更はなかった。

| 変更ファイル | 内容 |
|---|---|
| `docs/reference/benitoite.md` | 版と形式の問い合わせ、非実行の main/test の報告、各欄と不明値・完全性・出力先・終了状態、shell の参照範囲、ソース識別、エフェクト上限と E0512、test の全体拒否、環境入力の拒否と継承を追加。既存の die の診断と test の failure.die も説明 |
| `docs/reference/install.md` | 能力の問い合わせ、Skill の list/show と本文・長さ・ハッシュ、検査報告と上限の利用、ビルド情報の入力・由来・監視の限界・再採取、環境入力と隔離の限界を追加 |
| 本書 | 共通の関門 K、文書と実装の照合、検査と申し送りを記録 |

Rust の本体・テスト、埋め込み内容、公開の型・シグネチャ・引数・JSON の契約は変更していない。文書の版と既存の例は0.0.6を保ち、0.0.7への一斉更新は行っていない。

## 契約の照合

design.md の段1〜4、decisions.md の Q1〜Q12・R1〜R6・R8〜R9・R11・R13〜R16・R18〜R20・R23〜R27と、D1 後の現行設計を根拠にした。CLI の実装は `cli/mod.rs`、`cli/build_info.rs`、`cli/inspection.rs`、`cli/check_report.rs`、`cli/effect_limit.rs`、`cli/tools/test_runner/`、`cli/tools/skill/mod.rs`、`build.rs`、`builtins/funcs/process.rs` と照合した。

| 観点 | 照合した内容 |
|---|---|
| 引数 | report は `=` のみ、明示 diagnostics=text の拒否、test --check の実行専用オプションの拒否、報告の認識範囲と分離値の消費、allow-effects の両構文・13正規名・空集合・不正値・実行専用の範囲 |
| 形式と状態 | 九つの formats はすべて [1]。単一報告の必須欄、ok/0・checkErrorとusageError/2・internalError/3・testのinterrupted/130、書き込み失敗/1、JSON Linesとの出力先の違い、失敗時の完成報告の限界 |
| 診断 | usageError 内だけの kind:check・code:null。既存の kind:die・code:null と、test の reason:exit に付く failure.die を区別。診断形式1に新しい行や欄を足す説明にしていない |
| 検査対象と契約 | 通常実行と非実行で同じ入口・テストを選ぶ。宣言上限、IO.All の十個への展開、Assert.Check の保持、空と不明、部分成功と全体の完全性、到達性を調べない shell の式の参照を説明 |
| ソース | 同じソース表の元の全バイト列、対象に含むもの・含まないもの、報告内だけの ID、重複した明示パス、表示パスの限界を説明。報告から後の実行のソースを固定しない |
| 実行の上限 | 同じ検査済みプログラムのコンパイル、test の全準備後の開始、全体拒否時の集計と filesNotRun、同じエフェクト内の対象・内容・コマンドの変更を拒否できないことを説明 |
| ビルド情報 | 明示入力・不明・値ごとの由来、dirty の notCollected、存在する HEAD/ref/packed-refs/logs/HEAD の監視、検知できない更新と再採取条件。実行時の Git 状態や完全なソースの証明へ広げていない |
| 環境入力 | DYLD_/LD_ 全体の ASCII の大小を区別しない拒否、空値・同値・LD_RUN_PATH、既存の不正入力の優先、InvalidInput と非起動、親からの継承の不変。Process.Run を許せば env やシェルで設定できる限界を07-01と揃えた |
| Skill | 全論理名と辞書順、完全一致と不正名、HOMEとディスク上の文書を読まない取得、SKILL.md の版の置換、同じ本文の長さとハッシュ、JSON の失敗で空の成功を返さないことを説明 |

## 共通の関門 K

既存の assert・期待値・ignore・負の入力を変更していない。抽出器 `tests/doc_examples/mod.rs` と照合し、英語リファレンスの既存の22例（run 18、error 2、test 1、check 1）と、それに付く files/output/diagnostic/stderr の各ブロックが HEAD と完全に同一であることを確認した。`benitoite test` の fence は実行する例のままとし、説明用のブロックへ変えていない。追加したシェルの呼び出し例は sh、JSON の出力例は json とした。

テストを新設・変更・削除していないため、test-audit の作成時の関門にかける新しいケースはない。観測可能な CLI と文書の例は既存の適切な境界のテストで検査し、同じ契約を文字列検索だけで重ねるテストやテスト専用の本番 API は加えなかった。本番コードと Rust テストの行数の増減は各0である。

生成元・診断表・標準ソースの文書コメント・harness-response.md の公開契約を変えていないため、gen_skill と新しい R 判断は不要である。構文・型の規則・脱糖・形式化を変えておらず、R4 に従い formal/ と07-04の表は変更していない。

## 検査

検査名を事前に知らせ、既定構成（gc-mark-sweep、gc-stressなし）で次を実行した。計画では文書だけの D2a に K-R は不要だが、今回の依頼に従ってライブラリテスト・clippy・fmt も実施した。コマンドの出力整理には rtk を使った。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。テスト実行77.63秒 |
| `cargo test -p benitoite --test reference_examples --test spec_examples --test cli_process --test test_command --test skill_docs` | 5 suites、77 passed、0 failed。テスト実行計16.08秒 |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 文書のローカルリンクと見出し参照 | 一時的な Python の確認で67リンク・61フラグメントの参照先を検証 |
| JSON・fence・版 | JSON の2例を解析。全 fence の対応、既存22例と期待値の不変、0.0.7の先行記載がないことを確認 |
| 実際の CLI 出力との照合 | 統合テストでビルドした実行ファイルを一時的な Python から呼び、版のJSON例のbuild以外の全欄と九形式、checkとtestのusageError、両報告の成功・非実行・集合、E0512による全入口拒否の集計、Skillの取得本文・版置換・UTF-8の長さ・SHA-256と一覧の一致を確認。スクリプトは一時ディレクトリに置き、リポジトリには追加していない |
| `git diff --check` | 終了状態0 |

秒数はテスト実行時間であり、ビルド待ちを含めない。依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress・check-heap.sh・ignore を外す長いテストも実行していない。formal/ は未変更であり lake build は対象外である。scripts/check.sh と gc-stress、段末の検査はオーケストレータが最終ツリーで行う。この結果を段末検査・G6・公開前の全体検査の完了とは扱わない。

## 計画との差と申し送り

文書の更新は D2a の範囲内であり、実装・公開契約の計画変更や新たな判断はない。文書だけでも K-R を実施し、check.sh を実行しない点は今回の明示指示による。コミット、docs/todo/ の更新、版の更新、保管は行っていない。

D2b は Skill の手書き文書・生成元・必要な生成物を同じ契約へ揃える。D3 は六機能と harness-response.md の最終照合、M2b は英語文書とコード例を含む0.0.7への一斉更新、M3 は日本語訳を担当する。本作業は Skill 本文が既に新しい手順へ移行したとは説明していない。

san_benito への取り込み、scripts/check.sh・gc-stress・D3段末の検査・G6のレビューはオーケストレータへ引き継ぐ。
