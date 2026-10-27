# C1Rb1 の結果

2026-10-24。基準 B_WORK は `f83261aa333c64b12271231b2292ae34b5e27577`、作業枝は `mod012/C1Rb1`。開始時の HEAD は基準と一致し、未コミット差分はなかった。private/ と、そこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

## 担当範囲と申し送り

C1Rb1 の担当範囲を実装し、指定の work を通した。WarningRegion.lean に警告領域を定義し、具体規則と UnknownAt の排他、未知の根と内側の除外、元の先行順・キーとの一致、WarningInRegion から WarningLocated への含意を示した。BudgetRegion.lean の analysis_within と各 `_warning_region` は、任意の上限・初期消費・深さ・入力 Context について、expr・shortCircuit・block・armList の追加警告だけが入力の領域に属すことを示す。既存の警告列は接尾辞として残し、その要素へ現在の領域への所属を要求しない。

analyzeExpr・analyze の全出力警告と、入口の忘却・全体上限の事前停止を含む analyzeBody の全出力警告にも接続した。Models・評価導出・完走・予算内・事前の警告健全性は前提にしていない。中心二命題・評価関係・旧主定理・公理・Builtins.Assumptions と、実行する解析・予算の消費は変更していない。定義・証明・独立例は formal/Benitoite.lean の既定 import に接続し、01-12・07-04 へ写した。用語集に警告領域を加え、[RV-C1-response](../reviews/RV-C1-response.md) には中1・中5の今回の対応だけを追記した。

計画の機能範囲からのずれと、判断待ちによる停止はない。作業末の検査は、計画表に C1Rb1 の行がないため、依頼の補足が指定した三単位を使った。書き込み可能な一時 CARGO_HOME を使用したことと、最大常駐量を取得できなかったことは、下記の環境上の制限である。

C1Rb2 は、独立した Expr/Block の結果と警告を親から分け、予算・次キー・識別列を共有する保存・復帰を接続する。C1Rb3 は D8a の未知の子へ本接続し、各独立入力について今回の領域の保証を維持する。未知の内側を親の領域に含めたり、その警告を親の列へ混ぜたりしていない。C1Rc の検査全体の駆動・別本体発見・深さの扱いも先取りしていない。独立レビューと受け入れは取りまとめの担当であり、C1Rb 全体・中1と中5全体の受け入れを今回だけで閉じない。

## 実行した検査

Lean のビルドは直列に実行した。lake build には lakefile.toml の `-M 12288` が適用され、一ファイルの検査にも全て `-M 12288` を指定した。

| コマンド・対象 | 終了状態 | 外側時間 |
|---|---|---|
| `cd formal && lake env lean -M 12288 Benitoite/Interval/WarningRegion.lean` | 初期の局所検査は1。型の分岐・相互再帰の証明・簡約を修正後0 | 未計測（複数回） |
| `cd formal && lake build Benitoite.Interval.WarningRegion` | 0。定義と補助補題を確認 | 未計測（複数回） |
| `cd formal && lake env lean -M 12288 Benitoite/Interval/BudgetRegion.lean` | 初期の局所検査は1。印を忘れた列の対応と、構成子ごとの等式の適用を修正後0 | 未計測（複数回） |
| `cd formal && lake build Benitoite.Interval.WarningRegionExamples` | 初期は1。例で観察する演算の等号と withE の引数型、相互再帰の定義の等式による簡約を修正後0。固定期待値は変更していない | 未計測（複数回） |
| 下記の指定に `--dry-run` を付けた実行 | 0。spec_tally・spec_examples・formal_build の三単位だけを選択 | 未計測（1秒未満） |
| 下記の指定の本実行（一度） | 検査本体0。三単位とも成功 | Python の monotonic による8.596631333秒。time の real は8.63秒 |
| `cd formal && lake env lean -M 12288 /private/tmp/c1rb1-axioms.lean` | 0。下記の新定理の公理依存を確認 | ツールの外側時間0.218秒 |
| `git diff --check`（読み取り） | 0 | 未計測 |

```sh
scripts/check.sh --level work --base f83261aa333c64b12271231b2292ae34b5e27577 --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base f83261aa333c64b12271231b2292ae34b5e27577 --only formal_build,spec_examples,spec_tally
```

本実行は `/usr/bin/time -l python3 /private/tmp/c1rb1-run-work.py` で包み、Python の subprocess から上記コマンドを実行した。前作業が用意した書き込み可能な一時 CARGO_HOME を使い、依存の版・検査入力・構成は変更していない。spec_examples は7成功・0失敗・0無視であった。spec_tally は自己検査と本番集計に成功し、初回リリースの完了条件の未記入はなし。テスト参照のない仕様節の一覧は通常の集計出力である。formal_build は既定 lake build と sorry 拒否に成功した。

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告し、time 自体は終了1となった。Python が別に保存した検査本体の終了状態は0であり、両者を区別する。一時ログは `/private/tmp/c1rb1-work.log`、検査本体の終了状態と外側時間は `/private/tmp/c1rb1-work.json` に保存した。別の状態へ結果を引用するための記録ではない。

公理依存の確認では concreteRule_known、unknown_warning_excluded、WarningInRegion.located、analysis_within、expr・shortCircuit・block・armList の各 warning_region、analyze_warning_region、analyzeBody_warning_region を対象にした。依存の和集合は `propext`・`Classical.choice`・`Quot.sound` だけであり、新しい公理や sorry はない。

## 独立例の作成時の関門

test-audit を適用した。新しい三つの例の主な契約は、未知の内側の演算を親の警告領域から除外し、後続の元のキーを保つことである。既存の位置の検査では、未知の内側でも targetOperationAt が演算を認定するため、この所属の誤りを区別できない。WarningRegionExamples は先行順を手で数えたキーと演算を期待値にし、未知の list・未対応の乗算・with・handle と、const・括弧・整数の可能性がある腕の guard と本体を比較する。実行の到達の存在は主張しない。同じ部分木を独立した根として与える場合の領域も確認する。実装から期待値を作る処理や、テストだけの公開の差し込み口は加えていない。
