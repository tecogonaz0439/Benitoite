# D2b Skill の手書き文書と生成物

## 目的と変更

実行ファイルに埋め込む英語の Skill を、D2a の英語リファレンスと実装済みの公開契約へ揃えた。開始時のブランチは `mod254/D2b`、HEAD は `1933be4f` であり、作業ツリーに変更はなかった。

| 変更ファイル | 内容 |
|---|---|
| `crates/benitoite/skill/SKILL.md` | 版・能力と Skill の取得、非実行の検査報告、成功条件、確認済み集合を実行へ渡す手順、Assert.Check、上限と隔離の違い、環境入力の制約を反映 |
| `crates/benitoite/skill/references/idioms.md` | 検査から実行までの手順、九つの形式、ビルド情報、報告の各欄・不明・部分結果・終了状態、shell の参照、元バイト列のハッシュ、test の全体拒否、Skill の取得を説明。外部コマンドとテストの節も更新 |
| `crates/benitoite/skill/references/common-mistakes.md` | 診断と報告・実行の取り違え、E0512、空と不明、Assert.Check、全体拒否、禁止された環境入力の直し方を追加 |
| `crates/benitoite/skill/references/language-comparison.md` | 他言語のプロセス API との環境入力の違いと、検査報告・上限を使う手順を追加 |
| `crates/benitoite/src/prelude/stdlib/IO/Process.bnt` | run/runAttached、shell、Command.environment の文書コメントを詳しくし、LD_RUN_PATH・ASCII の比較・空値・同値・エラーの順序・非起動・継承と隔離の限界を反映 |
| `crates/benitoite/skill/references/stdlib/IO.Process.md` | 上記の標準ソースから gen_skill で再生成 |
| 本書 | 共通の関門 K、検査、後の作業への申し送りを記録 |

処理本体、Rust のテスト、公開の型・シグネチャ・引数・JSON の契約は変更していない。標準ソースも文書コメントだけを変えた。`generate.rs` の変更は不要であり、生成物は手で編集していない。gen_skill は references 全体と bundle.rs を書き直したが、内容の差分が生じた生成物は IO.Process.md だけである。診断表の E0512 は既に生成物と一致していた。

## 契約と共通の関門 K

plan.md の D2b、design.md の段1〜5、decisions.md の Q1〜Q12・R1〜R5・R11・R13〜R16・R18〜R20・R26〜R27、D2a 後の英語リファレンスを根拠とし、CLI と Skill の取得・生成、Process の実装と照合した。

- 集合は宣言した上限であり、未使用の宣言も含む。IO.All の十個への展開、Assert.Check の保持、未知を空としないこと、部分成功を全体成功としないことを揃えた。
- 報告と既存 JSON Lines の出力先、usageError 内だけの kind:check・code:null、非実行と実行時の集計、終了状態と出力失敗を区別した。
- shell の式の参照は検査対象全体を調べ、到達可能性を保証しない。報告のハッシュも実行するソースを固定しない。同じエフェクト集合内で操作対象や内容が変わりうることを示した。
- 環境の拒否は常に明示設定だけに適用し、継承は変えない。env やシェルによる設定を防ぐ保証へ広げず、禁止変数を親の環境へ移す回避方法も勧めていない。
- Skill の取得は埋め込み本文を使う。版の置換後の本文・バイト数・ハッシュは install と一致し、失敗を空の成功文書としない。

既存の assert・期待値・ignore・負の入力を変えていない。手書き文書の既存の実行・検査・test・エラーの例と、それに付く files/output/diagnostic/stderr の各ブロックは HEAD と完全に同一である。追加した CLI 呼び出し例は sh とし、既存の `benitoite test` の例を説明用に変えていない。SKILL.md は191行であり、500行未満の制限を保った。

テストの新設・変更・削除はないため、test-audit の作成時の関門にかける新しいケースはない。観測可能なコード例、生成物と生成元の一致、埋め込み・取得・導入した本文の一致は既存の文書テストと CLI のテストが守る。文字列検索だけで同じ契約を重ねるテスト、テスト専用の本番 API は加えていない。Rust の処理本体とテストの行数の増減は各0である。

metadata の `{{benitoite-version}}` は一か所のまま保持した。既存のコード例の language 宣言や処理系の版は変えず、0.0.7 への一斉更新を行っていない。公開契約に変更はなく、harness-response.md と新たな R 判断の追加は不要である。構文・型の規則・脱糖も変えておらず、R4 に従い formal/・01-12・07-04 の表は変更していない。

## 検査

検査名を事前に知らせ、既定構成（gc-mark-sweep、gc-stress なし）で実施した。コマンドの出力整理には rtk を使った。

| コマンド・確認 | 結果 |
|---|---|
| `cargo run -p benitoite --example gen_skill`（2回） | 両方終了状態0。2回目の前後で文書59件と bundle.rs の計60ファイルの SHA-256 が全件一致 |
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。テスト実行82.79秒 |
| `cargo test -p benitoite --test reference_examples --test skill_docs --test skill_examples --test spec_examples --test cli_process` | 5 suites、45 passed、0 failed。テスト実行計18.81秒 |
| `cargo clippy --workspace --all-targets` | 終了状態0、指摘なし |
| `cargo fmt --all --check` | 終了状態0 |
| 相対リンク・見出し参照、fence と placeholder | 一時的な Python の確認で46リンクの参照先とフラグメント、手書き文書の既存の検査対象ブロックと期待値の不変、版の placeholder 一か所を確認 |
| `git diff --check` | 終了状態0 |

秒数はテスト実行時間であり、ビルド待ちを含めない。依頼に従い scripts/check.sh は dry-run も含めて実行せず、gc-stress・check-heap.sh・ignore を外す長いテストも実行していない。formal/ は未変更であり lake build は対象外である。scripts/check.sh と gc-stress、D3 の段末検査はオーケストレータが最終ツリーで行う。本作業の個別検査で段末・G6・公開前の全体検査を完了したとは扱わない。

## 計画との差と申し送り

文書の更新は D2b の範囲内であり、実装・公開契約の計画変更や新たな判断はない。check.sh を実行しない点は今回の明示指示に従った。コミット、docs/todo/ の更新、版の更新、保管は行っていない。

D3 では harness-response.md と六機能の契約を最終照合する。M2b では既存のコード例を含めて0.0.7へ一斉更新し、生成元から再生成する。M3b ではこの英語正の変更を Skill の日本語訳へ反映する。san_benito への取り込み、scripts/check.sh・gc-stress・D3 段末検査・G6 のレビューはオーケストレータへ引き継ぐ。
