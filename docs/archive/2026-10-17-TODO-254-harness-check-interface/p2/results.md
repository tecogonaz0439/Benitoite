# P2 インターフェースと受け入れ条件の照合

## 目的と変更範囲

2026-10-17、実装前の型の使用箇所、panic と失敗の境界、test の所有関係、判断と受け入れ条件を現 HEAD で照合した。[型・所有関係の確認表](interfaces.md) と [受け入れ条件の対応表](acceptance.md) を作成し、P2 の文書作業を完了した。

変更ファイルは本書、`p2/interfaces.md`、`p2/acceptance.md` の三つである。処理系・テスト・現行の設計書・formal/・生成物・docs/todo/ は変更していない。型・公開シグネチャ・CLI・JSON の契約も変更していない。コミット、0.0.7 への版の更新、タグの作成、公開は行っていない。

## 基準と確認結果

| 項目 | 結果 |
|---|---|
| 開始時のブランチ・HEAD | `mod254/P2`、`c232d0bdc6098e7eb4a7b0261576628fd641b9fe` |
| 開始時の dirty | `git status --short` は空。無視されたファイルは含めない |
| 前提 | AGENTS.md、目的と設計原則、plan の K/P2 と後続作業、design、decisions の Q1〜Q14・R1〜R10・R12、README/request/answers と P1 の確認表を照合 |
| 型の使用箇所 | Options/PathArgs/Command/Prepared/TestFn/Summary の定義・全構築と分岐・全呼び出し元を rg で列挙し、別の同名型を区別。新しい欄の導入時点を R7 と対応 |
| 失敗・所有 | execute_script/prepare/run_body/invoke と pipeline の panic 境界を図示。認識後の usageError/checkError/internalError と出力失敗、認識前・外側の保証外を区別。通常の逐次実行と上限付きの全保持・破棄を対応 |
| 抽出の根拠 | E0512 は src/testdata で未使用、原子的エフェクト13個、IO.Allは10個。Source.text() は元の全バイト。標準 IO.Process の未読/既読の索引欠落、refs 全値と shell の束縛比較を確認 |
| 公開シグネチャ | collect_tests の Result 化は計画済みで、現呼び出しは compile_tests の一箇所。parse_args、parse_test_args、test_entries、run_skill などは計画どおり既存の型・可視性を維持できる。予期しない変更は不要 |
| Q/R と受け入れ条件 | Q1〜Q14 と R1〜R10・R12 を全件対応。CLI の出力・非実行・部分失敗・全体拒否・ビルド・環境・Skill・移行と、検査の持ち主を記録。後続の未実施検査を成功扱いにしない |
| check の分類 | check.sh の check_names と classify を読んだ。build.rs/CLI は crates/* により rust、今回の三文書は docs/* により検査なし。スクリプトの変更は不要。実行による確認とは区別 |
| 形式化 | 07-04「01-12 との対応」を再読し、R4 を維持。CLI が既存の契約を読む処理と IOError の入力条件に留まり、構文・型の受理・脱糖を変更しないため、07-04/01-12/formal/ の変更は不要 |

## 共通の関門 K

| 関門 | 結果 |
|---|---|
| K1 テストの維持 | assert・期待値・ignore は変更していない。本番コードとテストの行数の増減は各0 |
| K2 test-audit | テストの新設・変更はない。[受け入れ条件の対応表](acceptance.md) に、後続テストの契約・現実的な退行・既存で不足する理由・差し込み口不要を対応させた |
| K3 規約と受け渡し | 所有データだけを段の外へ返すこと、AST/IR を段内で捨てること、ソース再読・二重検査をしないことを呼び出し元と対応。新しい本番 API・フラグ・可変な大域の状態は加えていない |
| K4 文書との対応 | 実装前の条件を改造ディレクトリ内に留めた。design/decisions/plan/harness-response の訂正を要する新しい判断は見つからず、R の追記はない。生成元・公開契約も変更していないため gen_skill は実行しない |
| K5 各作業の検査 | P2 の計画では Rust の検査は不要だが、今回の依頼を優先して下表の検査も実施した |
| K6/K7 検査の分担 | 今回の依頼に従い check.sh は dry-run を含めて実行していない。分類と検査名は静的に確認し、dry-run の実績に読み替えない。分類外停止は観測していない |
| K8 受け渡し | 本書と二つの確認表に基準・変更・検査・未実施と担当を記録した |

## 実施した検査

開始前に検査名を知らせ、既定構成（default の gc-mark-sweep、gc-stressなし）で実行した。Cargo コマンドには `rtk` を前置した。検査後も変更は本作業の文書だけである。

| コマンド・検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 成功。1,194 passed、既存の21 ignored、80.92秒 |
| `cargo test -p benitoite --test cli_process --test test_command --test interrupt_process --test skill_docs` | 成功。4スイート、45 passed、17.10秒 |
| `cargo clippy --workspace --all-targets` | 成功。指摘なし |
| `cargo fmt --all --check` | 成功 |
| 文書のリンク・表・JSON・対応・空白の確認 | 成功。三文書のローカルリンク10件、表12個の列数、Q1〜Q14/R1〜R10・R12の対応、末尾改行・行末空白を検査。design/harness-response のJSON例15件も構文を確認。P2文書にJSON例は追加していない |
| `git diff --check` と新規三文書の空白検査 | 成功 |

check.sh、gc-stress、heap/full、長いテストの明示実行、両構成の全ターゲットのテスト、check-formal.sh、lake build は実施していない。今回の文書変更は formal/ に触れないため、lake build の条件には該当しない。新機能の受け入れテストや G1 のレビュー・段末の検査も未実施であり、P2 の完了へ含めない。

## 計画との差と申し送り

計画からの設計・公開契約のずれはない。検査の分担だけ今回の依頼を優先し、文書作業でも指定の Cargo 検査を実施し、check.sh は実行しなかった。オーケストレータが取り込み対象のツリーで check.sh の選択と必要な検査、gc-stress を実施する。

次は V1a である。build.rs の本番接続と独立した実ビルドを行い、R2/R10 の環境・監視条件・二回目の非再コンパイルを実測する。P2 で確認した静的な分類を、その成功の代わりにしない。

後続作業は各自の開始時に型の使用箇所と E0512 を再検索する。T1c に Prepared.inspection を先置きせず、T2a の request_index/SelectedEntry も T2b まで追加しない。A2a/A2b は canonicalize を含む run_input と全テスト原型の準備を全体開始前に済ませ、再探索・再検査へ戻さない。型の推論や脱糖へ変更が広がれば R4 を先に再判定する。
