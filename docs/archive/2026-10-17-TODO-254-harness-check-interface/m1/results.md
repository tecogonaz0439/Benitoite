# M1 移行対象と E0908 の変更表の準備の結果

## 目的と変更

0.0.7 へ版を上げる前に、互換性の変更の登録と移行対象を準備した。開始時の HEAD は `4051360bdf26f2e76ae98d4a5668d92bc866a801`、ブランチは `mod254/M1`、作業ツリーに差分はなかった。

| ファイル | 変更 |
|---|---|
| crates/benitoite/src/modules/package.rs | BREAKING_CHANGES の末尾へ0.0.7を登録。既存の合成版のテストへ本番の変更表と current=0.0.6/7 の対照を追加 |
| crates/benitoite/src/modules/text.rs | design の案どおり LOADER_ENVIRONMENT_CHANGE/MIGRATION を追加 |
| CHANGELOG.md | 先頭に Unreleased を新設し、六機能・E0512・全体の非実行・二接頭辞の拒否・language/ハッシュの移行を記載 |
| [inputs.md](inputs.md) | P1 を最新ツリーへ再照合。通常入力50件、Rust の合成入力、保持する負の検査・構文例・履歴、生成元と生成物、三組のハッシュの影響元・更新順を記録 |
| 本書 | 共通の関門 K、検査結果と引き継ぎを記録 |

公開の型・シグネチャ・CLI・JSON の契約を変更していない。実版は Cargo.toml/lock とも0.0.6である。E0908 の適用条件 `declared < change <= current` と版順の処理は変更していない。通常入力・固定ハッシュ・負の golden の期待値も未変更である。現行設計は実版0.0.6のまま正しいため、docs/design に0.0.7の受理を先に書いていない。harness-response の公開契約にも変更はない。

## 共通の関門 K とテストの作成時の関門

AGENTS.md、plan の K/M1、design「E0908 の変更表と 0.0.7」、decisions の Q10/Q11/Q13 と R12/R29、P1 と D3/Z6 の記録に従った。テスト・日本語の記録・シェルの実行には test-audit・japanese-tech-writing・rtk を適用した。

- 守る契約は、版境界の診断の主文・位置・全 notes/helps とその順、未来版の E0907、現在版の成功である。current=0.0.7 では旧0.0.4/5/6の全変更を独立した文字列の期待値で比較し、0.0.7を受理、0.0.8を拒否する。current=0.0.6 の対照では0.0.7の変更を出さない。
- 現実的な退行は、0.0.7の登録漏れ、案内の欠落・誤記、適用時期の誤り、古い版の案内の欠落・順序の変化である。既存の逆順の合成表は0.0.5/6だけを注入し、実版のモジュール読み込みはまだ0.0.6なので、新しい本番の登録漏れを捕まえられない。
- 新設のテスト関数や別の層の重複ケースを増やさず、既存の合成版のテストへ本番の変更表の対照を加えた。テスト専用の本番 API・フラグ・未使用コードは不要である。既存の assert・期待値・負の入力・ignore は一つも削除・緩和していない。
- 文言は modules/text にまとめた。AST の走査・破棄、所有関係、再検査、ソースの再読、unsafe・大域状態・公開 API は変更していない。構文・型付け・脱糖も変更せず、R4 に従い formal/ は対象外である。
- gen_skill を実行し、Skill の生成物と bundle.rs の内容が HEAD と一致することを確認した。生成物を手で編集していない。

scripts/check.sh は dry-run も含め依頼で禁止されているため実行していない。classify の分岐を読み、Rust の二ファイルは rust、CHANGELOG と改造の記録は検査を追加しない分岐であることを静的に確認した。これは dry-run の実績ではない。gc-stress と共通検査はオーケストレータへ渡し、個別検査の成功を段末や G7 の完了とは扱わない。

## 検査

実施前に検査名を知らせ、既定構成（gc-mark-sweep、gc-stress なし、既存の ignore を含めない）で実施した。Cargo の出力整理には rtk を使用した。

| コマンド・確認 | 結果 |
|---|---|
| `cargo test -p benitoite --lib version_check_reports_all_applicable_changes_in_version_order` | 1 passed、0 failed |
| `cargo test -p benitoite --lib` | 1197 passed、0 failed、既存の21 ignored。テスト実行90.37秒 |
| `cargo test -p benitoite --test package_command --test golden --test cli_process --test skill_docs` | 4スイート、49 passed、0 failed。テスト実行計70.15秒 |
| `cargo clippy --workspace --all-targets` | 成功、指摘なし |
| `cargo fmt --all --check` | 成功 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成物・bundle.rs の差分なし |
| Python hashlib による独立計算 | hash-match の2ファイル、modules/hash.rs の7ファイル、package_command.rs の2ファイルから、三組の現在の固定値と一致 |
| 通常入力と文書の照合 | P1 と M1 の50件のパス・行が全件一致。追加・変更した文書の相対リンク・見出し・末尾改行・行末空白を確認 |
| 版・生成物の維持 | Cargo.toml/lock が0.0.6、生成された Skill と bundle.rs が HEAD と同一 |
| `git diff --check` | 成功 |

scripts/check.sh、gc-stress の構成、全ターゲットのテスト、長いテストの明示実行、heap/full、LLM を呼ぶ評価は未実施である。formal/ は未変更のため lake build の条件に該当しない。

## 計画との差と申し送り

実装の計画変更はなく、R の追加を要する実態との差はなかった。検査の分担だけは今回の指示を優先した。コミット、docs/todo の変更、版の更新、改造ディレクトリの保管・タグ・公開は行っていない。

- M2a/M2b: inputs.md を基準に最新ツリーへ再照合し、版・通常入力・負の境界の期待値・正のハッシュ・生成物を同時に更新する。P1 後に加わった tests/cli_process.rs:590 と tests/test_command.rs の四件も含める。M1 の合成の current=0.0.6/7 は固定して保持する。
- M2b: CHANGELOG の Unreleased を0.0.7へ改題し、冒頭の未更新版0.0.6と予定表記も提供時点へ直す。0.0.6以前の履歴は保持する。
- M3a/M3b: Z6/R29 の inspection.md の訳の追加も含め、英語正と照合する。harness-response の版・build・ハッシュは最終の実行ファイルで再採取する。
- オーケストレータ: san_benito への取り込みとコミット、scripts/check.sh と gc-stress の構成の検査、G7 と段末・最終検査を実施する。
