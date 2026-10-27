# C1Rb3a の結果

2026-10-25。基準 B_WORK は `fa54d153f2fc1df7469a2a64838974ed6da26207`。開始時の HEAD は基準と一致し、未コミット差分はなかった。指定の枝は `mod012/C1Rb3a`。private/ と、そこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

## 変更と保持した契約

C1Rb3a の実装を終えた。`BudgetIndependentRun.lean` を新設し、prepareIndependent・captureIndependent・independentWith の実行定義を移した。同ファイルは BudgetWalk だけを import し、解析本体とその証明を import しない。BudgetAnalyze はこれを import し、expr・block の相互再帰の後に IndependentInput.run と independent を定義する。これにより、解析本体から independentWith へ内部走査を渡すための import の循環を解消した。

任意の内部走査に対する prepareIndependent_walk・captureIndependent_walk・independentWith_walk は、BudgetTraversal の analysis_walk より前へ移した。independentWith_silent は BudgetLocated の解析の位置の証明より前へ移し、上位の captureIndependent_head に頼らず保存定義から直接証明した。各補題の言明は保ち、Walk の三補題は証明本文も保った。入力自身の正常値・警告原因・領域と保存列の証明は、BudgetIndependent・BudgetIndependentSound に残した。

移動した実行定義5件は、名前・型・本文が基準と一致することを文字列で照合した。対象の既存宣言141件の名前と既存定理101件の言明を保ち、リポジトリ内の Lean import グラフに循環がないことも静的に確認した。既存の解析の分岐、予算の計上、番号の消費、候補と独立入力の保存は変えていない。中心二命題・評価関係・旧主定理・公理・Builtins.Assumptions の変更はない。

新モジュールを formal/Benitoite.lean の既定 import に加え、01-12「区間解析の独立入力の保存と保証」と07-04の対応箇所へ、移動後の所在と依存を反映した。所見ごとの対応は reviews/RV-C1-response.md へ追記した。

## 実行した検査

指定の三単位だけを work として一度実行した。Lean のビルドと単一ファイル検査は重ねて走らせていない。lake build の各プロセスには formal/lakefile.toml の `-M 12288` が適用され、単一ファイル検査にも同じ上限を指定した。

```sh
scripts/check.sh --level work --base fa54d153f2fc1df7469a2a64838974ed6da26207 --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base fa54d153f2fc1df7469a2a64838974ed6da26207 --only formal_build,spec_examples,spec_tally
(cd formal && lake env lean -M 12288 /private/tmp/benitoite-c1rb3a-axioms.lean)
git diff --check
```

work 本実行と公理依存の確認は、それぞれ `/usr/bin/time -l python3` で包み、Python の subprocess から記載のコマンドを起動した。Cargo には既存の書込み可能な一時 CARGO_HOME を使った。依存の版と検査範囲は変えていない。

| 検査・コマンド | 終了状態 | 外側の時間 |
|---|---|---|
| 指定の work の dry-run | 0。spec_tally・spec_examples・formal_build の三単位を選択 | 未計測（1秒未満） |
| 指定の work 本実行（一度） | 検査本体0。三単位とも成功 | Python monotonic 41.005秒、time real 41.03秒 |
| 仕様例（work 内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測。テスト実行器の表示3.78秒 |
| 仕様集計（work 内） | 自己検査と集計に成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 形式化（work 内） | 既定 lake build と sorry 拒否に成功。既存の独立例も含む | 個別の外側時間は未計測 |
| 公理依存の確認（単一ファイル） | Lean 本体0。下記8補題・定理の依存は propext・Classical.choice・Quot.sound だけ | Python monotonic 0.315秒、time real 0.34秒 |
| 実行定義・移動した証明・宣言名・import の静的照合 | 0。一致と循環なしを確認 | 未計測 |
| git diff --check（読み取り） | 0 | 未計測 |

公理依存の確認対象は independentWith_silent・prepareIndependent_walk・captureIndependent_walk・independentWith_walk・independent_saves・independent_walk・analyze_normal_sound・analyze_warning_sound である。既存例と定理の再ビルドで移動後の接続を検査したため、テストや固定期待値の変更は加えていない。

最大常駐量（maximum resident set size）は取得できなかった。二つの `/usr/bin/time -l` はともに `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。Python が取得した検査本体と Lean 本体の終了状態0とは区別する。検査本体の失敗や、それに伴う再実行はなかった。一時ログ・終了状態・時間は `/private/tmp/benitoite-c1rb3a-work.{log,json}` と `/private/tmp/benitoite-c1rb3a-axioms.{log,json}` に置いた。別の状態への結果の引用を目的とする記録ではない。

## 計画からのずれと申し送り

実装範囲に計画からのずれはない。検査表に C1Rb3a の行がないため、依頼の補足で名指しされた三単位を使った。メモリ計測の制限は上記のとおりである。言語の規則・主な定理の前提と結論・公理について、設計者の判断を要する変更は生じていない。

C1Rb3b は、BudgetAnalyze から independentWith を使って D8a の未知の子へ接続する。番号の合成には BudgetTraversal の independentWith_walk、親の候補の分離には BudgetLocated の independentWith_silent を、各解析の証明より前から使える。analysis_keepsInputs に頼る run_saves の置換、入れ子の保存列、接続後の正常値・位置・原因・領域の証明は、予定どおり C1Rb3b に残る。C1Rb3c は接続後の文書・契約表・分類表・用語集を全体で照合する。

今回の自己確認だけで独立レビューと受け入れを閉じない。取りまとめが C1Rb3a の独立レビューと受け入れを行う。中1・中5、C1Rb3 と親 C1Rb 全体の受け入れは未完である。
