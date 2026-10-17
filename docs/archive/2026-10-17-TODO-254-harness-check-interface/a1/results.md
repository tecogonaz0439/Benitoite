# A1 上限の構文・E0512・run の接続

## 目的と変更

run の main の宣言上限を、`--allow-effects` の許す集合と実行前に照合する。検査に成功した同じ CheckedProgram の契約を段のスタックで抽出し、不足なら E0512 を加えて脱糖・コンパイルへ進まない。ソースの再読・検査の再実行・AST の段外への持ち出しは加えていない。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/cli/effect_limit.rs` | 新規。正規名の解析、組み込み ID の集合による包含、辞書順の集合表示、E0512 の生成 |
| `crates/benitoite/src/cli/mod.rs` | EffectLimit の再公開と Options.allow_effects、既定 None、両構文の解析、help と使い方の文言、run の検査後・脱糖前の照合、既存の解析テストへのスクリプト引数の対照追加 |
| `crates/benitoite/src/cli/check_report.rs` | 非実行の検査報告は prepare_script へ上限なしを渡す |
| `crates/benitoite/src/diag/codes.rs` | 未使用を確認した E0512 と主文・位置のラベル・注記・help・空集合の文言を登録 |
| `crates/benitoite/tests/cli_process.rs` | 包含・非実行・診断・失敗の優先順の実プロセスの表を追加。既存の usage と報告の表へ両構文と拒否の対照を追加 |
| `crates/benitoite/skill/references/diagnostics.md` | gen_skill で E0512 を生成。ほかの生成物には差分なし |
| `docs/design/06-tooling/06-01-cli.md` | オプションの表、受理・拒否・分離値の消費、包含の契約と保証の範囲 |
| `docs/design/02-impl/02-10-diagnostics.md` | E0512 の位置・集合の注記・help・終了状態と E05 系の区分 |
| `docs/design/02-impl/02-11-embedding.md` | run の検査成功後の照合と同じ成果物の受け渡し |
| `design.md`・`decisions.md`・`harness-response.md` | 内部の集合の表現と A1 の提供済み範囲、R21 の解消、R23 の判断 |
| 本書 | 共通の関門 K、検査と申し送り |

公開の変更は、非公開の集合を持つ EffectLimit と Options.allow_effects である。解析と比較の補助関数は cli 内だけに公開し、PathArgs.allow_effects と formats.effectLimit は追加していない。既存の型検査の規則と公開の parse_args のシグネチャは変えていない。上限の指定がなければ従来どおり実行する。

## テストの作成時の関門

守る観測可能な契約は、正規名だけの受理、宣言上限の包含、E0512 の診断全体と終了状態2、拒否時の非実行、通常の誤りと処理系の不具合の優先である。包含を本体の使用集合に狭める、ID と正規名を取り違える、上限の照合をコンパイルや実行の後へ動かす、分離値をサブコマンド・パス・報告の指定として拾う、といった退行を捕まえる。

主となる境界は実際の CLI の入力・出力・ファイル状態である。既存の検査報告は実行を始めないため、照合後の run の実行と拒否を比較できなかった。空集合、余分な許可、宣言だけのエフェクト、IO.All の展開、両構文とサブコマンドの前後・省略を一つの表で比較した。E0512 は JSON のオブジェクト全体を独立した期待値と等値比較する。ファイルを書き換える同じソースの拒否と成功を比べ、stdout と目印ファイルの内容を検査する。コンパイルの L0112 に当たる入力の main に State の宣言を加え、空の許可では E0512 が先に出ることも確かめる。

不正名、重複名、IO.All、未知名、利用者定義名、import の別名、`*`、空白と空の要素、二度の指定、値なしは既存の usage の表へ追加した。check と report の正逆順、分離値として消費される report の字面も既存の表で比較する。スクリプト以後の同名引数の保持は、既存の公開 parse_args のテストに対照を加えた。テスト専用の本番 API・フラグ・差し替えは不要である。

既存の assert と負の入力は保持した。削除、期待値の緩和、ignore の追加はない。既存の usage の完全一致の条件を新オプションにも広げた。新しい表の初回実行では、IO.All に対する既存の W0501 を成功時に想定しておらず失敗した。新しい表を、警告と E0512 のコード列・順序も厳密に比較する形に直した。既存の警告は変更していない。

Rust の本番コードは156行追加・10行削除（差し引き146行増）、テストは369行追加・1行削除（差し引き368行増、cli/mod.rs のテスト15行を含む）である。テストの削除1行は既存の完全一致の条件の拡張であり、assert の削除ではない。

## 検査

既定の構成（gc-mark-sweep）で実行した。コマンド出力の整理には rtk を使った。依頼に従い scripts/check.sh は dry-run も含め実行せず、gc-stress の構成も実行していない。

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --test cli_process run_effect_limits_check_declared_contracts_before_execution` | 新しい表の入力・診断を確認し、1 passed（その後の追加と整形を含む最終状態は下の全体実行で確認） |
| `cargo run -p benitoite --example gen_skill` | 終了状態0。生成物は手で編集せず、diagnostics.md だけに差分 |
| `cargo test -p benitoite --lib` | 1195 passed、0 failed、既存の21 ignored（82.76秒） |
| `cargo test -p benitoite --test cli_process --test skill_docs --test test_command` | 58 passed、0 failed（3 suites、20.30秒） |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 変更した Markdown の相対リンクと JSON ブロックの確認 | 6文書の相対リンク190件と JSON ブロック16件で成功 |
| `git diff --check` | 終了状態0 |

## 計画との差と申し送り

機能の範囲と実装順のずれはない。内部の集合を設計の Vec から非公開の BTreeSet としたことと、全体の契約を示す harness-response.md に A1 の提供済み範囲を区別したことを R23 に記録し、design.md も合わせた。R21 の暫定の扱いは、上限の解析・オプションの表・06-01・harness-response.md を同時に更新して解消した。

後続の A2a/A2b は test の準備の確認と上限の接続、A3/A4 は全体拒否・受け入れ表・formats.effectLimit の宣言を担当する。現在の test の上限指定は未提供であり、PathArgs に欄を先置きしていない。scripts/check.sh、gc-stress の構成、A4 の段末検査、G4 のレビューと san_benito への取り込みはオーケストレータへ引き継ぐ。本書は A1 個別作業の記録であり、段3全体を完了扱いにしない。

formal/・構文・型の規則・脱糖は変更していないため、R4 の判定を保ち、lake build は実行していない。docs/todo/ は変更せず、コミットは作成していない。
