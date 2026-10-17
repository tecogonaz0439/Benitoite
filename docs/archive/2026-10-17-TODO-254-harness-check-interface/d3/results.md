# D3 ハーネスへの回答と六機能の照合の結果

## 目的と変更

BH-022〜027 とハーネスの補足を、san_benito のコミット `2cc62c88355dfe70396836aac7f5e90f645fdaff` の実装に照合し、harness-response.md を単独で渡せる状態にした。作業ブランチは mod254/D3、開始時の HEAD は同コミット、差分はなかった。

| ファイル | 変更 |
|---|---|
| [harness-response.md](../harness-response.md) | 基準コミット、0.0.7 の提供予定・未公開、実装中に契約が変われば更新する前提を冒頭に記載。仮の JSON を実出力に置換し、版0.0.6と提供予定版の関係、抜粋の範囲、必須欄と配列順を説明。保証の限界を一節へ集約 |
| [decisions.md](../decisions.md) | R28 に、版の更新前の実出力と大きな報告を抜粋で提示する判断を追加 |
| [contracts.md](contracts.md) | 六依頼と testSummary・Assert.Check・LD_RUN_PATH の三補足、全 formats キー、失敗・部分結果・限界の確認表 |
| [cli-observations.json](cli-observations.json) | 基準コミット、入力8件、CLI 22実行の引数・終了状態・stdout/stderr。Skill の raw 本文と SKILL.md は重複を避け、長さとハッシュを保存 |
| 本書 | 共通の関門 K、検査結果、後の作業の分担 |

型・シグネチャ・引数・JSON・診断・終了状態の契約は変えていない。処理系、Rust のテスト、formal/、docs/design/、同梱の Skill の本文と生成物は未変更である。design.md の訂正を要する実装との差は見つからなかった。

## 共通の関門 K

plan.md の D3、design.md の全六機能と「ハーネスへの契約と残る危険」、decisions.md の Q1〜Q14 と適用済みの補足を根拠にした。AGENTS.md、japanese-tech-writing、rtk の規約に従った。

テストの新設・変更・削除はない。既存の assert、期待値、負の入力、ignore を変えていない。test-audit の作成時の関門にかける新しいケースはなく、観測可能な契約は既存の CLI・test・外部コマンド・文書のテストで検査した。文字列検索だけの新規テスト、テスト専用の本番 API、未使用の本番コードを加えていない。

外部向け回答から、作業 ID と内部文書への言及を除いた。本文の JSON 例9件を実出力と構造で比較し、入力の BNT 例2件もバイト単位で確認した。実例の8呼び出しを別の一時ディレクトリで再実行し、stdout/stderr と終了状態が採取記録と一致した。入口の全バイト列の SHA-256、Source/Target/診断の ID の対応、部分失敗と純粋・空の成功、上限拒否と通常 test の空の成功を照合した。LD_RUN_PATH の確認では InvalidInput と子の marker が作られないことを確認した。

## 検査

検査名を事前に知らせ、既定構成（gc-mark-sweep、gc-stress の機能なし、既存の ignore を含めない）で実施した。以下は同じ処理系・埋め込み内容に対する結果である。生成を二回実行しても内容は変わらなかった。

| コマンド・確認 | 結果 |
|---|---|
| `cargo build -p benitoite --bin benitoite` | 終了状態0。基準コミットのソースから実出力を採取 |
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。テスト実行87.05秒 |
| `cargo test -p benitoite --test cli_process --test test_command --test l13_external_commands --test spec_examples --test reference_examples --test skill_docs --test skill_examples` | 7 suites、87 passed、0 failed。テスト実行計38.39秒 |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| `cargo run -p benitoite --example gen_skill`（2回） | 両方終了状態0。各回の前後で Skill 内のファイルと bundle.rs の計60件の SHA-256 が全件一致、生成物の差分なし |
| 実出力例・JSON・契約表・相対リンク | 一時的な Python で JSON 例9件、BNT 例2件、実例8呼び出しの再現、全9 formats キー、六依頼の各節、内部参照の不在を検査。contracts.md の表と入力・出力・既存テストを照合。相対リンク7件の参照先が存在 |
| `git diff --check` | 終了状態0 |

秒数はテスト実行時間であり、ビルド待ちを含めない。コマンドの出力整理には rtk を使い、JSON の採取と照合では生の出力を使った。

依頼に従い scripts/check.sh は dry-run も含め実行せず、gc-stress の構成、全体の検査、check-heap.sh、長いテストも実行していない。formal/ は未変更のため lake build は対象外である。個別検査の結果で D3 の段末検査・G6 のレビュー・公開前の全体検査を完了したとは扱わない。

## 計画との差と申し送り

実装と公開契約の計画変更はない。回答文の例を実測値へ直すため、照合用の入力・完全な出力を d3/cli-observations.json に保存した。抜粋と版の扱いは R28 の推す案に記録した。check.sh と gc-stress の検査を省いた点は今回の明示指示による。コミット、docs/todo/ の変更、版の更新、保管、タグの作成・公開は行っていない。

harness-response.md は今回の時点で設計者からハーネス担当へ渡せる。後の実装で契約を変えたら同時に更新する。M1/M2b で移行案内・版・language 宣言を実装し、0.0.7 の最終出力の版・ハッシュを取り直す。F2 では実在するタグと最終の検査結果を通知する。san_benito への取り込み、scripts/check.sh・gc-stress・D3 段末検査、G6 のレビューはオーケストレータへ引き継ぐ。
