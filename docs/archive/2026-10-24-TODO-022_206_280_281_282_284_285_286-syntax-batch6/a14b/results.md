# A14b の結果

2026-10-25。基準 B_WORK と開始時の HEAD は `b679d1db6667a9d27d420651c11fb72b3adc1f74`、作業枝は `mod012/A14b`。開始時に未コミット差分・未追跡入力はなかった。plan.md「計画の変更（2026-10-25、RV-C2 を受けて）」の A14b を実装した。

## 変更と Lean との対応

UnsignedInteger64 と別名 UnsignedInteger の片辺が一点の定数倍を、親で直接解析する経路へ接続した。`arithmetic.rs` は両辺が一点なら左を定数とし、各端点を u64 の値域で確かめてから u128 へ変換して積を求める。u128 のまま対象型の上限と比較し、正常区間との交差を求めた後で端点を i128 へ戻す。積自体を先に i128 で求めたり、変換したりしない。

正常値・失敗可能性・警告候補の判定は Lean の `Arithmetic.mulBounds`・`mulNormal`・`mulMayOverflow`・`mulAlwaysOverflows` と `Sound.baseOwnKind` に合わせた。両辺が複数値なら Top と失敗可能性を保ち、候補を作らない。一部だけが型域外なら正常値との交差を渡し、候補を作らない。全域外だけをあふれ候補にする。子に正常値がなければ、親に候補や正常値を復活させない。

`flow.rs` は UnsignedInteger64 の乗算を未対応へ送る除外だけを外した。`BudgetAnalyze.expr` と同じ左辺・右辺・演算自身の順序、子の失敗可能性と return、左辺の失敗後の右辺の skip を既存の経路で保つ。`BudgetAnalyze.own`・`saveWarnings` に対応する候補の作業枠・保存・追加・返却の順序と回数は変更していない。整数の種類付きの位置、忘却、条件環境、比較、match の計上を追加・変更していない。

診断も同じ積の端点を読み、型域との交差前の値を u128 で表示する。最大 u64 の二乗 `340282366920938463426481119284349108225` を、i128 の上限へ丸めず W0402 の注記へ表示する。01-04 と 02-05 は、この接続後の範囲と中間計算の型へ更新した。

## テストの作成時の関門

既存の型検査の二表を拡張した。正常区間の表は、UnsignedInteger64 と別名について、左右反転・0倍・1倍・最大値同士の積・部分的なあふれ・両辺が複数値の Top・中間失敗・右辺の skip・return を観察する。診断の表は最大値の二乗と区間の積について、型名・交差前の結果区間・許容範囲・一次位置・由来を観察する。既存の表はこの型の乗算を除外し、固定表も幅付きの形を持たないため、u128 の積の切り詰めや、未対応の経路による事実の忘却を検出できなかった。

本物の名前解決・型検査・入力収集を通し、期待値は数学上の端点と Lean の定義から固定した。本番にテスト専用の公開範囲・引数・状態を増やしていない。新しいテスト関数と削除したテスト関数はともに0件であり、既存の上限・入力・期待値を緩めていない。

## 途中の検査と修正

コマンドはリポジトリの根で実行した。Cargo は `rtk proxy` を通して生の出力を保存した。最初の二回を除き、外側の経過時間を Python の monotonic 時計で測定した。

| コマンド（Cargo の引数） | 終了 | 外側の時間・結果 | 記録 |
|---|---:|---|---|
| `cargo test -p benitoite --lib arithmetic_keeps_each_width_and_intermediate_failure -- --nocapture`（テスト追加の初回） | 101 | 外側未計測。診断の行を別の表に挿入していたためコンパイル失敗 | [arithmetic-before.log](arithmetic-before.log) |
| 同じコマンド（テストの配置を修正、実装前） | 101 | 外側未計測。Cargo のビルド11.13秒・テスト0.54秒。`n * 2u64` の実値 Top と期待 `[2,6]` の不一致を再現 | [arithmetic-before-2.log](arithmetic-before-2.log) |
| `cargo test -p benitoite --lib arithmetic_ -- --nocapture`（実装後の初回） | 101 | 24.118秒。ResultBounds とメソッドの可視範囲の不一致を警告として拒否 | [arithmetic-after.log](arithmetic-after.log)・[終了記録](arithmetic-after-result.json) |
| 同じコマンド（可視範囲の修正後） | 0 | 8.547秒、12件成功 | [arithmetic-after-2.log](arithmetic-after-2.log)・[終了記録](arithmetic-after-2-result.json) |
| `cargo test -p benitoite --test call_allocations bounded -- --nocapture --test-threads=1` | 0 | 26.590秒、指定の2件成功 | [allocations-local.log](allocations-local.log)・[終了記録](allocations-local-result.json) |
| `cargo test -p benitoite --lib budget_matches_lean -- --nocapture` | 0 | 2.723秒、本体表と全体／集計表の2テスト成功 | [budget-local.log](budget-local.log)・[終了記録](budget-local-result.json) |

コンパイル失敗は、テストの行の配置を正し、結果区間を返すメソッドの可視範囲を実際の利用側である interval 内へ狭めて修正した。lint の許可や検査条件は変更していない。実装前の区間の不一致は、本番の乗算を接続した後に成功した。

| 割り当て量のテスト | 確保した総バイト数 | 元の上限 |
|---|---:|---:|
| `long_constant_chain_has_bounded_check_allocations` | 442,662,821 | 536,870,912（512 MiB 未満） |
| `repeated_constant_diagnostics_share_bounded_origin_work` | 254,897,076 | 268,435,456（256 MiB 未満） |

割り当て量は A14a の申し送りと二件とも一致した。上限・入力・期待値は変更していない。

固定表三表・生成元・再生成器・README の7ファイルは基準とバイト単位で一致し、[fixed-input-sha256.json](fixed-input-sha256.json) に記録した。表の更新や再生成は行っていない。Rust の既存の比較は、本体5,398行・全体1,126行・集計1,126行の保存済みの表を読み、すべて成功した。この成功を全構文・任意深さ・全関係状態の比較の完了とは扱わない。

## 作業末の work

実行前に `scripts/check.sh --level work --base b679d1db6667a9d27d420651c11fb72b3adc1f74 --dry-run` を実行した。終了0、外側0.092秒で、fmt、examples を含む lint_default、lib_default、全統合の tests_related、source_rules、skill_generated、spec_tally が選択された。仕様の例の検査は全統合に含まれる。[work-dry-run.log](work-dry-run.log)・[終了記録](work-dry-run-result.json) に保存した。

同じ基準で `scripts/check.sh --level work --base b679d1db6667a9d27d420651c11fb72b3adc1f74` を一度実行し、`/usr/bin/time -l` で包んだ。統合ターゲットを絞る `--test` は付けていない。検査本体は終了0、外側426.087秒、time の real は426.12秒だった。再実行・結果の引用による省略は行っていない。[work.log](work.log)・[work-result.json](work-result.json)・[work-time.log](work-time.log) に保存した。

| 検査 | 結果 |
|---|---|
| fmt | 成功 |
| lint_default | lib・tests・examples、`--no-default-features --features gc-mark-sweep` で成功 |
| lib_default | 1,306件成功・失敗0件・21件 ignored（70.90秒） |
| tests_related | 全40統合ターゲット、382件成功・失敗0件・10件 ignored。仕様・リファレンスの例、既存の割り当て量も含む |
| source_rules | 仮置きの許可と unsafe の許可の検査が成功 |
| skill_generated | 生成器による照合が成功。生成物に差分なし |
| spec_tally | 仕様集計の自己検査と集計が成功 |

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告し、計時ラッパーは終了1となった。内側の検査本体の終了0と区別し、最大常駐量を測定済みとは扱わない。計時の外側は `rtk proxy /usr/bin/time -l python3 <tmp>/benitoite-a14b-run.py work scripts/check.sh --level work --base b679d1db6667a9d27d420651c11fb72b3adc1f74` とし、Python はコマンドを一度実行して検査本体の終了状態と monotonic 時計の経過時間を保存・返却した。

## 計画からのずれと申し送り

UnsignedInteger64 の定数倍を接続し、正確な結果区間を診断へ渡すため、arithmetic.rs に加えて flow.rs・diagnostics.rs と既存の幅別テストを変更した。変更に対応する01-04・02-05も同じ枝で更新した。公開の型検査の署名・報告の欄、型とエフェクトの規則、実行時検査、Lean の定義・中心二命題・主定理の前提・結論・公理は変更していない。VM値・ヒープの不変条件・安全点を越える保持も変更していない。

A14c は六幅の比較の認定・絞り込み・短絡の条件環境・match と幅付きの固定表を接続する。A15 は全幅の診断・文書・生成 Skill と、その区切りの検査を担当する。既存の見出し名は参照の更新を受け持つ U02 まで保持した。

Lean のビルド、Rust/Lean・VM の全比較、stage・change・release、heap/stress、性能比較は本枝の割り当て外として実行していない。32ビット環境での実行・クロスビルドも未実施であり、言語の型域や中間計算へ usize を使っていない。独立レビュー・受け入れ・コミット・取り込みと後続の検査は取りまとめが担当する。

private/ とそこを指すスキルのリンクは参照せず、git の変更操作、docs/todo の更新、コミット・取り込み・公開は行っていない。


## 最終点検

作業末の work 開始後に、本番 Rust・テスト・設計書・固定表を変更していない。以後の編集は本結果・ハッシュ・検査記録と、生ログの手元の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せる処理だけである。変更した実装・テスト・設計書6ファイルの [final-inputs-sha256.json](final-inputs-sha256.json) は検査開始時と終了後に全件一致し、固定表など7ファイルも基準との完全一致を再確認した。

本番 Rust の差分は85行追加・24行削除、テスト Rust は78行追加・15行削除である。テスト関数の削除はなく、既存の二表へ行を追加した。`git diff --check` と本結果の相対リンクの確認は成功した。

A14b が受け持つ未実施・不合格の検査と、言語規則・主要定理についての判断待ちは残っていない。最大常駐量の取得不能と後続の担当範囲は上記のとおりである。独立レビューと受け入れを取りまとめへ引き渡す。

## 取りまとめのレビュー（2026-10-25）

UnsignedInteger64 の定数倍を u128 で求め、型域と比べて切り詰めた後に i128 へ戻す。`arithmetic.rs` の `as i128` の二つは、直前で u64 の値域に収まることを確かめた後の変換で、理由のコメントがある（AGENTS.md「数値の変換」の値が収まることが明らかな箇所）。最大 u64 の二乗を W0402 の区間に正確に表示する。固定表は基準と一致する。受け入れる。
