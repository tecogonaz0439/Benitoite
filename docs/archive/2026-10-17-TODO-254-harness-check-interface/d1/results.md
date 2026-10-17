# D1 現行の設計書の章間の照合

## 目的と変更

個別の実装で更新した現行設計を、CLI・検査報告・実行器・ビルドスクリプト・環境入力・Skill の実装と照合し、章間に残った古い記述と適用範囲の漏れを直した。開始時のブランチは `mod254/D1`、HEAD は `13f6cf6e4a57f60d1e967af3f8bce5e8df0040a5`、作業ツリーに変更はなかった。

| 変更ファイル | 変更内容 |
|---|---|
| `docs/design/02-impl/02-01-pipeline.md` | 経路表に非実行の test を追加。段内の上限照合、契約抽出と AST の破棄、入口ごとのソース表の解放を補足 |
| `docs/design/02-impl/02-02-source-and-spans.md` | ソース識別を main と test の両報告へ適用。入口ごとの ID、順序、sourceSets、重複とハッシュの限界を明記 |
| `docs/design/02-impl/02-10-diagnostics.md` | 単一報告と従来の標準エラー出力を区別。testCheckReport の usageError、警告・不具合の内包、非実行時の集計なしを反映。ソースの or die が未接続と読める古い説明を修正 |
| `docs/design/05-platform/05-01-distribution.md` | リリース版と形式の版、formats による能力判定を区別 |
| `docs/design/06-tooling/06-01-cli.md` | 章の範囲、完全な報告の判定、test の Effects の形、標準入出力の例外、出力失敗による終了状態1の優先を明記 |
| `docs/design/06-tooling/06-04-test-runner.md` | 章の範囲と外部宣言の静的な照合を補足。通常の実行結果と非実行の出力を区別 |
| `docs/design/06-tooling/06-06-agent-skills.md` | 「権限を表示する機能を持たない」とする説明を置き換え、検査報告・完全性の確認・上限の利用と保証の限界を記載。手読みだけで確認済みの集合へ収まるという断定を除去 |
| `docs/design/07-quality/07-03-compiler-testing.md` | build.rs の rust 分類と all-targets、build_info の長いテストを既存の検査へ対応 |
| `docs/design/README.md` | 上記の章の範囲と目次を一致させた。CLI の package と、プロパティベーステストを含めない範囲も本文に揃えた |
| 本書 | 章・実装・契約の照合、共通の関門 K、検査と申し送り |

Rust の本体・テスト、公開の型・シグネチャ・CLI 引数・JSON の契約は変更していない。章と見出しの追加・改名はなく、spec 印や gen_skill の参照を直す必要はない。全変更章の見出しとコードブロックが HEAD と同一であることを確認した。

## 章と実装の対応

design.md の文書対応表のうち、D1 が担当する全章を照合した。英語文書・Skill 本文・生成元の改訂と訳、版と E0908 の変更表、CHANGELOG は後続作業の範囲として区別した。

| 観点と対象章 | 照合した実装と結果 |
|---|---|
| 抽出・所有・破棄（02-01・02-11） | cli/mod.rs の prepare_script、inspection.rs、test_runner の prepare・compile_tests・run_limited・run_prepared と両 check_report を確認。段内で深い AST と型表・IR を捨てる。run は同じ検査結果を照合後にコンパイルし、上限付き test は全入口の成果物を保持して消費する。上限なしは入口ごとに準備・実行する。再読・再検査・再コンパイルはしない。02-11 は既に一致しており変更不要 |
| ソースと診断（02-02・02-10・06-01） | check_report::sources・diagnostic_value、content_hash、test_runner/check_report を確認。元の全バイト列、Target 順・FileId 順、重複を分ける ID、空の sourceSets と null、診断との対応を保つ。usageError の kind:check・code:null・primary:null は報告内だけの例外であり、既存の診断形式1を変えない |
| 形式・出力先・状態（06-01・06-04） | cli::execute の VersionJson 分岐と build_info、両報告の value・usage_error・write、実行器の reject_all・finish・report を確認。九つの formats はすべて [1]。報告の診断は stdout の単一 JSON に内包し、stderr へ重ねない。ok/0、checkError・usageError/2、internalError/3、test の interrupted/130、書き込み・flush 失敗/1 を照合した。部分成功でも全体が不完全なら aggregateEffects は null |
| 対象の選択・全体拒否（02-11・06-01・06-04） | select_test_entries・collect_tests・run_limited を確認。通常実行と非実行の入口・関数の選択、指定順・宣言順・重複・下位パッケージの除外を共有する。上限付きの全体拒否は結果行なし、passed/failed=0、filesNotRun=全入口数。探索失敗・使い方の誤り・対象未確定の不具合は集計なし。準備前と最初の実行前の中断の確認、拒否時の再読なしは R26 と一致 |
| エフェクトと shell（02-01・06-01・06-06・07-01） | inspection・effect_limit と types::builtin::effect_name を確認。宣言上限と13原子的正規名、IO.All の十個への展開、Assert.Check を含む test の和、refs と expr_types で判定する shell の式の参照を照合した。空集合と不明を区別し、到達性や実際の操作対象は推定しない |
| 環境入力（03-07・06-01・07-01） | builtins/funcs/process.rs の入力検証と共通の execute を確認。DYLD_/LD_、ASCII の大小、空値・同値・LD_RUN_PATH、既存の不正入力の優先、InvalidInput と非起動、継承の不変を照合。03-07・07-01 は既に一致しており変更不要 |
| ビルド情報（05-01・06-01・07-03） | build.rs・cli/build_info.rs と check.sh の classify を読んで確認。明示値・由来・不明、Git の根・worktree・アーカイブ、存在する HEAD/ref/packed-refs/logs/HEAD だけの監視、未検知時の再採取条件は既存の記述と一致。classify の crates/* が rust を選ぶ。分類の静的な確認であり dry-run の実績とは扱わない |
| Skill（06-01・06-06） | skill/mod.rs の解析・一覧検証・render_document・document_metadata・実行を確認。論理名の完全一致、全件の辞書順、SKILL.md だけの版の置換、同じ本文の長さ・ハッシュ、HOME の遅延、出力失敗を照合した。R27 に従い、論理名と導入・除去のパスのエスケープを、すべての使い方の誤りへの保証へ広げない |
| 版・パッケージ（01-03・06-09） | modules/package.rs の BREAKING_CHANGES・版の判定と比較。現在の0.0.6までの記述は実装と一致。0.0.7 の E0908 の登録を先置きせず、両章は変更しない。CLI やビルドの事情を01-specへ追加していない |
| 保証の範囲（07-01・06-06） | 静的な集合の包含と実行時の権限制御・OS の隔離を区別した。同じ File.Write の対象・内容や Process.Run の起動先は固定できない。報告のハッシュと上限はスナップショットを保証しない。07-01 の既存の記述と一致 |

## 共通の関門 K と形式化

既存の assert・期待値・ignore・負の入力は一切変更していない。テストの新設・変更・削除がないため、test-audit の作成時の関門にかける新しいケースはない。既存の CLI・実行器・文書のテストを使い、同じ契約を文字列検索だけで重ねるテストや本番の差し込み口を作っていない。本番の Rust コードとテストの行数の増減は各0である。

新しい文言定数、所有データ、公開 API、可変な大域の状態、フラグ、unsafe、unwrap/expect、添字、AST の走査は追加していない。diag::codes・標準ソースの文書コメント・生成元を変更しておらず、gen_skill の再生成は不要である。harness-response.md の公開契約も変えていない。

R4 と07-04「01-12 との対応」を再確認した。今回の差分は現行設計と目次・作業記録だけであり、構文・型の受理規則・推論・脱糖・形式化は変えていない。したがって07-04の表、01-12、formal/ は変更せず、lake build と check-formal は対象外とした。

## 検査

開始前に検査名を知らせ、既定構成（gc-mark-sweep、gc-stressなし）で次を実行した。コマンドの出力整理には rtk を使った。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。テスト実行89.44秒 |
| `cargo test -p benitoite --test spec_examples --test reference_examples --test skill_docs --test cli_process --test test_command` | 5 suites、77 passed、0 failed。テスト実行計26.16秒 |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 対応表の13章と設計目次の相対リンク・見出し参照 | 一時的な Python の検証で528リンクの参照先と31フラグメントを確認。コード内の構文例をリンクと誤認しないよう除外した |
| JSON の例 | design.md の8例、harness-response.md の7例を JSON として解析。現行の対象14文書には json fence の例はない。状態・必須欄・出力先の表は上記の実装と照合 |
| 見出し・コードブロック・変更範囲 | 設計9ファイルの見出しとコードブロックは HEAD と同一。Rust・formal/・01-spec の差分なし |
| `git diff --check` | 終了状態0 |

秒数は rtk が集計したテスト実行時間であり、ビルドの待ち時間を含めない。長いテストの ignore を外す実行と check-heap.sh は行っていない。依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress の構成も実行していない。これらと段末の検査はオーケストレータが最終的なツリーで行う。この個別作業の検査を、段末検査・G6・公開前の全体検査の完了とは扱わない。

## 計画との差と申し送り

D1 の範囲内で既存記述を実装に揃えたものであり、新しい契約や実装上の計画変更はない。新しい R 判断は追加していない。docs/todo/ の更新、コミット、版の更新、保管は行っていない。

D2a は英語のリファレンスと導入手順、D2b は Skill 本文・手書き参照と必要な生成物を更新する。06-06 に追加したのは実装済みの CLI をハーネスが利用できる手順であり、同梱 SKILL.md が既にこの手順へ移行したとは記していない。D3 は六機能と回答文の最終照合、M1/M2 は E0908・CHANGELOG と0.0.7への移行、M3 は訳を担当する。

san_benito への取り込み、scripts/check.sh・gc-stress と段末の検査、G6 のレビューはオーケストレータへ引き継ぐ。D3 段末の指定は `rust,default_lib,spec_examples,reference_examples,skill,spec_coverage` である。
