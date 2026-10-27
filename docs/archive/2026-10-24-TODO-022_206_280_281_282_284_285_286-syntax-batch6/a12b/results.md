# A12b の結果

2026-10-25。基準 B_WORK と開始時の HEAD は `9c1d9a1e4cfbacb11be78fd12b0d1a1deaece3b9`、作業ブランチは `mod012/A12b` である。A12b の文書の同期と割り当てられた検査を完了した。独立レビュー・S-A1・受け入れは取りまとめへ引き渡す。

## 変更と照合

06-01 に「区間解析の追加報告」を加え、A12a の `cli/check_report.rs::interval_value`、test の報告の集約、`typeck/interval/summary.rs`、02-05「区間解析の報告の集計」と照合した。06-04・02-10・06-06 と、手書きの `skill/references/inspection.md`・`skill/SKILL.md` を同じ契約へそろえた。

- 報告全体と各 Target の `intervalAnalysis` に、basis、coverage、元定義数、四件数、phaseStops の資源別内訳、usage の五欄を記載した。本体出力と段停止、元定義と別本体、件数と消費量、和と最大値を区別した。
- all/some/none、型検査前失敗・未着手・正常な空の探索・探索失敗、件数0でも未完の範囲が残る場合、重複入口と doc の生成例の集約を記載した。`--deny-warnings` で拒否しても集計を保持することと、全体上限により後続の警告と strict 時の受理が変わりうることも明記した。
- coverage は報告の受け入れ判定に関わらず、complete は型・エフェクトの検査と契約抽出の完了を表す。警告がないことは all でも安全を意味しない。この読み方を、ハーネスが宣言上限を人間へ説明する手順にそろえた。形式番号・既存の必須欄・status・受け入れ条件は変えていない。

厳密な既存読者は読み取りで照合した。tools/・scripts/・処理系本体・統合テストの `checkReport`・`testCheckReport`・`aggregateEffects` と未知欄の拒否を検索し、報告を読むコードは `tests/cli_process.rs` と `tests/test_command.rs` に確認できた。前者の `report_without_interval_extension` は A12a で追加済みであり、全体と各 Target の追加欄の存在を確認してその欄だけを取り除き、既存必須欄の完全一致比較を維持している。後者は JSON の値から必要な欄を読む。main/test の契約・位置・ソース識別、探索と実行の一致、失敗・警告昇格・中断・doc の版の比較、および coverage と受け入れの独立性の既存テストを照合した。A12b ではこれらのテストを変更せず、指定外の CLI 統合テストの再実行もしていない。リポジトリ外の全読者との互換性まで確認したとは扱わない。形式変更や読者の破壊的変更を必要とする箇所は見つからなかった。

## 検査

実行した work の指定は次のとおりであり、先に同じ指定へ `--dry-run` を付けて選択と理由を確認した。

```sh
scripts/check.sh --level work --base 9c1d9a1e4cfbacb11be78fd12b0d1a1deaece3b9 --only spec_examples,spec_tally,reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples
```

| 実行・対象 | 結果 | 外側の時間・記録 |
|---|---|---|
| 同じ指定の dry-run | 終了0。計画の6単位だけを選択 | 0.013秒。[ログ](work-dry-run.log)、[実行記録](work-dry-run.json) |
| `/usr/bin/time -l` で包んだ work | 検査本体は終了0、全選択単位が成功。time 自身は終了1 | 26.414秒。[ログ](work.log)、[実行記録](work.json) |
| tests_related | skill_examples 3件、stdlib_doc_examples 1件成功 | 上記 work 内 |
| spec_examples・reference_examples・skill_docs | 順に7件・1件・8件成功。上記と合計20件、失敗・ignored 0件 | 上記 work 内 |
| spec_tally | 自己検査成功、完了条件の未記入は none。テスト参照のない仕様節の一覧は通常の集計出力として記録 | 上記 work 内 |
| skill_generated | gen_skill の実行と前後の照合に成功。生成物と bundle.rs に差分なし | 上記 work 内 |
| 差分と相対リンク | `git diff --check` 成功。変更した6文書の相対リンクと参照先見出し213件を確認 | 補助の読み取り点検 |

time の表示は26.41 real / 24.19 user / 4.35 sys であった。最大常駐量は、サンドボックスが `sysctl kern.clockrate` を `Operation not permitted` として拒否したため取得できなかった。検査本体の終了状態は time と別に保存し、time の終了1を検査失敗とは混同していない。生ログの手元の絶対パスは `<repo>`・`<home>`・`<tmp>` に伏せた。

検査の不合格や修正後の再実行はなかった。補助の相対リンク点検の初回は、単純な正規表現がコード内の型と引数をリンクと誤認して停止した。コードを除外して Markdown のリンクだけを読むよう点検用の一時処理を修正し、上記213件を確認した。文書の変更は不要であった。

## 計画からのずれと申し送り

対象の6文書と本ディレクトリの結果・ログだけを変更した。Rust・テスト・Lean・生成文書の生成元は変更していない。指定した work の skill_generated が生成器を実行して照合したため、別の再生成は重ねなかった。Rust の全 lib・clippy・fmt、stage/change/release、Lean のビルドや比較、性能測定は追加していない。言語規則、主要定理の前提・結論、公理について判断を要する変更は発生していない。

同梱 Skill の v0.0.11 への固定リンクは、既存必須欄と受け入れ規則の参照として保ち、追加の intervalAnalysis まで同版が説明するように読める文を修正した。追加欄は同梱 inspection.md に記述した。U02/U03・Z01 は、後続の解析拡張との整合、最終版を指す参照先と日本語訳を担当する。A12b で公開前の v0.0.12 のリンクや版上げを先取りしていない。

取りまとめは独立レビュー後、A12 全体の S-A1 の検査と受け入れへ進む。今回の成功を CLI 全統合や Rust/Lean 全比較の実行結果として引用しない。A12b が受け持つ未実施・不合格の検査と判断待ちは残っていない。

git の変更操作は行っていない。private/ と、それを指すスキルのシンボリックリンクは参照していない。work 開始後の変更は本結果記録の追加だけであり、検査対象の6文書は変更していない。

## 取りまとめのレビュー（2026-10-25）

同梱の Skill（SKILL.md・inspection.md）は、`intervalAnalysis` を `complete` と分けて読むこと、`coverage` が受け入れの判定に関わらないこと、`all` でも警告がないことは安全を意味しないこと、`--deny-warnings` の下で無関係な定義の追加が全体の予算を尽くして後の警告を消しうることを、ハーネスの読み方として書いている。既存の受け入れの規則と版を固定した参照は保たれている。受け入れる。
