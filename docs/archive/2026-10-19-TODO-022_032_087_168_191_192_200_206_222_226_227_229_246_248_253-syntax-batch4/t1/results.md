# T1 の実装結果

T1を完了した。RV2とZ1の指摘反映を前提に、Integer全域の網羅性、列挙と記憶の資源予算、診断と局所交換を接続した。コミットとdocs/todo/の変更は行っていない。

基準B_WORKは開始時の `git merge-base HEAD san_benito` の `be7dc868eb821e39a111720c021bd4d201104ccb` である。開始時に未コミット差分はなかった。先の着手前確認の未完了記録を、本実装の結果へ更新した。

## 変更

- `patterns.rs`・`limits.rs`: 開始/終了の端点を整列して一度走査し、Integerの最小区間を合併せずに保つ。全域を覆う場合だけotherを除き、上端+1はi128のまま扱う。Stringは出現順の配列と挿入済み集合を使う。R102の探索セルと三つの追加予算を独立に確認し、記憶のハッシュ衝突は構造の等値で照合する。キー・結果の複製と保存、形の列挙を延ばす前に予算を確認する。
- `pattern_ext.rs`・`text.rs`・診断表: 公開Coverage APIの結果と型は保ち、内部の診断入口だけが具体的な整数を選ぶ。一点の穴は診断で0、交換でotherの表示 `_` とする。E0609には四つの資源上限を示し、gen_skillで生成した診断の文書も更新した。
- `ir/decision.rs`: 全域の整数に不要な既定分岐を作らない。従来の文字の全域と同じ判定を整数へ広げた。新しいgoldenはVMの二方式・参照評価・整形を通り、verifyとlibのコード生成corpusにも含まれる。
- テストと現行設計書: 全域・分割全域・一点/複数の穴・端点・ガード・Integer64・レコードの相関、予算超過と独立した型誤りの保持を確認する。900行の整数/文字列の実ソースは先頭・末尾・不一致の六つの実行結果を確かめる。01-05・02-05・02-06と07-04の接続状況を更新した。Rust本体は差引272行、Rustテストは差引425行増である。

## 作業末の検査

コマンド・終了状態・外側時間は [commands.jsonl](commands.jsonl)、出力は各ラベルと同名の `.log` に保存した。固定したB_WORKとplanのT1行をdry-runで確認し、次のworkを一度実行した。今回の依頼のall-targets lintはR159に従い別の一回へ置き換えた。

```sh
scripts/check.sh --level work --base be7dc868eb821e39a111720c021bd4d201104ccb --only fmt,lib_default,tests_related,source_rules,skill_generated,spec_tally --test coverage_export --test golden --test verify --test spec_examples
cargo clippy -p benitoite --all-targets --no-default-features --features gc-mark-sweep
```

| 検査 | 終了状態と結果 | 外側時間 |
|---|---|---:|
| workのdry-run | 0、指定した単位と四つの統合ターゲットだけを選択 | 0.015秒 |
| all-targets clippy | 初回101。追加したテストのArcの複製2箇所を `Arc::clone` へ修正後、0。警告なし | 初回10.014秒、修正後0.973秒 |
| 上記work | 1。fmt成功、lib 1,222件成功・既存ignore 21件、coverage_export 3件成功・既存formalのignore 1件。goldenのOptionの反例の期待が一件だけ古かったため停止 | 126.607秒 |
| `cargo test -p benitoite --test golden --test verify --test spec_examples` | 0。古い診断期待を更新後、golden 2テスト（795ケース）、spec_examples 7件、verify 2件が成功 | 116.357秒 |
| `cargo test -p benitoite --test coverage_export export_coverage -- --include-ignored --nocapture` | 0。R160の計数表現の修正後に再生成。通常10,020件、view付き10,028件。Rustの予算停止0、探索セルの最大2,714 | 13.753秒 |
| `cargo clippy -p benitoite --test coverage_export --no-default-features --features gc-mark-sweep` | 0、R160で変更したターゲットだけを更新。警告なし | 0.373秒 |
| `scripts/check.sh --level work --base be7dc868eb821e39a111720c021bd4d201104ccb --only fmt,source_rules,skill_generated,spec_tally` | 同じ指定のdry-runが0、実検査も0。更新後のfmt、残っていた規約・生成物・仕様集計が成功。初回リリースの未記入条件なし | dry-run 0.011秒、実検査3.286秒 |
| `cargo run -q -p benitoite -- check <t1/tree-check.bnt>` | 0。13・16・24群の二欄trueの例が公開checkを通過 | 36.734秒（実行ファイルのビルドを含む） |
| `git diff --check`、局所交換用Pythonの構文確認 | 0 | 計時なし |

途中の局所検査は `cargo check -p benitoite --lib`、`cargo test -p benitoite --lib typeck::patterns::tests -- --nocapture`、同じ指定の `typeck::pattern_ext::tests`、coverage_exportの新規テスト二件、新規goldenに限定した。全libと指定した統合対象を途中で重ねていない。型検査の17件、判定APIの15件、900行の実行、標準モジュールの型検査の成功を確認した。途中の全試行の外側時間は保存していない。

[local-budget-counts.log](local-budget-counts.log)には整数/文字列の900行の計数を保存した。探索セルは双方815,403、列挙/キー仕事量は整数12,327,449・文字列12,128,141、記憶セルは双方408,150、文字列キーは0/1,531,283バイトであり、R102の上限を変えずに収まる。専用の性能測定は実施していない。

## 局所の交換

[check_local_exchange.py](check_local_exchange.py) が本番Rustの出力を二つのLean CLIへ渡す。新しい入力はcoverage_exportの通常テストが本番lexer・改行判定・parserを通し、公開checkの診断とCoverage APIの結果を独立した厳密な期待値で確認して書き出す。三ソースと版4の独立Coverage、二組のプログラムCoverageと宣言表は [exchange/](exchange/) に保存した。版4は既存の互換読者で受け付けられ、13/5の新構文へ読み替えていない。

| 読者・入力 | 結果 | 外側時間 |
|---|---|---:|
| coverageDiff、全域・分割全域・一点の穴 | 終了0、3件一致・不一致0・燃料切れ0 | 0.189秒 |
| coverageProgramDiff、全域・分割全域 | 終了0、match 2件受理・対象外0・燃料切れ0 | 0.226秒 |
| coverageProgramDiff、一点の穴 | 期待どおり終了1。match 1件を非網羅として拒否し、反例 `_`・到達不能なし・燃料切れ0まで厳密に確認 | 0.050秒 |
| coverageDiff、通常corpus | 終了0、10,020件一致・不一致0・燃料切れ0 | 2.704秒 |
| coverageDiff、view付きcorpus | 終了0、10,028件一致・不一致0・燃料切れ0 | 2.710秒 |

最初の三つは [local-exchange.log](local-exchange.log) に記録し、その後の通常corpusの読み込みで止まった。R160の修正後は成功済みの三つを重ねず、`python3 -B <t1>/check_local_exchange.py --random-only` で後の二つだけを実行した（全体7.615秒）。各CLIの完全なコマンドとcorpusのSHA-256は [exchange/commands.json](exchange/commands.json)、新しい三判定のコマンドは同Pythonと最初のログにある。通常corpusは乱数種0〜9,999と20境界、view付きは同じ種の10,000件と28境界で再生成できる。

view付きの完全な報告は、全ての乱択例もboundaryResultsへ載せる既存の実装のため約8.9 MBになる。全件数・不一致0・燃料切れ0は完全な報告で確認した後、[future-summary.json](exchange/future-summary.json) に計数・28境界・完全な報告のSHA-256を残した。重複する一致済みの乱択10,000件の詳細だけを保管対象から省き、完全な報告は `target/formal-t1-integer/future-full-report.json` へ移した。再実行すると同じ手順で要約する。

## 失敗の修正と計画との差

- R158は、公開の型を変えずに診断と交換の表示を分ける入口と、記憶の計数を具体化した。最初の試行で空の行列の全ての整数欄を具体化した結果、Treeの未指定欄まで変わったため、その処理は元の問いの形を保つよう戻した。具体値は列挙した区間/otherと、整数を直接照合する全域の穴に限定した。新しいソーステストのspanの期待も、`n with`全体ではなく実際のscrutinee `n` の1バイトへ修正した。
- R159は、型検査を通った新しいgoldenが下位化で `empty pattern matrix` となったため、文字の全域にある既定分岐の省略を整数へ広げた。最初の失敗はgolden本体0.24秒、その後の局所goldenは終了0、外側5.688秒である。下位IRの既定分岐がないことと五つの境界値もlibで確かめる。T2/T3の共有・試行予算は変えていない。依頼のall-targets lintへの置換も同番号へ記した。
- R160は、旧い種類別計数の `integer` キーがL7の整数定数の検査と衝突したため、全種類と件数を保持した配列にした。最初の局所交換は3.099秒で通常corpusの読み込みに失敗し、先頭の一件と計数へ絞って再現した。Leanの範囲検査と既存のassertは変えていない。
- 既存のInteger全域の「非網羅」の期待は成功へ、全域後の `_` はE0602へ更新した。旧い非網羅のIntegerと `Option.Some(1)` のgoldenは、未被覆区間の下端を表示する仕様に合わせ、反例と修正案を具体値へ更新した。E0609のgoldenも四上限の表示へ厳密に更新した。診断の件数・位置・終了状態の検査は残し、期待を緩めていない。

最初のworkの失敗後、Rust本体は変更していない。診断期待の更新に関係するgoldenと、未実行だったverify/spec_examplesを補完し、R160で変更した書き出し・そのターゲットのlint、更新後のfmtと残りの単位だけを実行した。全libと成功済みのCoverage通常テストを再実行していない。

## 入力の大きさとテストの関門

Coverage の予算そのものを守る入力は、実行時のGCを使わない判定APIの900行、1100欄のレコードと800個の明示パターン、既存の12群のBooleanの組合せである。これらは大きさを下げると予算の拒否を再現できないため、既定・heap・stressでも同じ大きさを保つ。探索・列挙・記憶・文字列キーの閾値はR102から変えない。実ソースからVMまで通す分岐選択の入力は既定・heapで900行、stressでは64行とする。触った深いソースの既存テストは通常の450/900等の深さを保ち、stressだけ16にする。新しいgoldenは深い再帰・長いList・大きな共有合成を含まない。

主な境界は公開のCoverage判定API、実ソースの型検査、CLIのgolden、二つのCoverage交換CLIである。APIの固定予算だけでは型検査の診断の位置と独立した別の誤りの保持、VMの分岐選択、交換のotherの表示を捕まえられないため、それぞれの境界で独立した厳密な期待値を使う。三つの追加予算は枯渇直前の内部状態から本物の探索を通し、上限ちょうどの成功と1単位超過の拒否を確かめる。本体のテスト専用API・フラグ・大域状態は追加しない。既存のassertの削除・ignore化は行わない。

## 後の作業への申し送り

- T2以降は本実装を前提にできる。新しい公開型やシグネチャは追加していない。Integer全域の後の `_` はE0602であり、診断の具体値と交換の `_` を混同しない。
- 13/16/24群は公開checkまで成功した。DAG/T3による実行への接続と性能の受け入れはT3・M1へ渡す。900行の整数/文字列の先頭・末尾・不一致は本作業で実行済みである。
- 旧corpusの種類別計数は配列になった。必要な内容は全て保持している。局所交換の集約は [../results.md](../results.md) に記した。
- 版全体のstage/change/release、gc-stress・heap検査、check-formal.sh全体は取りまとめの割り当てに残す。formal/は変更しておらず、既定lake buildは本作業では追加していない。全形式化比較の成功や版全体の受け入れ完了を主張する記録ではない。
