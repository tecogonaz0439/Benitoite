# 作業 L11d4a の結果

2026-10-24。L11d4a の実装と指定 work を完了した。基準 B_WORK と着手時の HEAD は `182a4d21c86421cd697d715131fb640872abbf79`、ブランチは `mod012/L11d4a`、着手時の差分はなかった。private/ とそれを指すスキルのリンクは読まず、git の変更操作は行っていない。他の results.md は変更していない。独立レビュー・受け入れは取りまとめの担当であり、本記録では完了と扱わない。

## 変更と受け渡す契約

変更は次の5ファイルである。既存の解析の定義・評価規則・中心命題・公理・Builtins.Assumptions は変更していない。

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Interval/BudgetLocated.lean` | 警告列を変更しない skip 群の証明、追加分の位置と対象演算の合成、全解析の帰納法、同じ analyze 入口の WarningLocated を新設 |
| `formal/Benitoite.lean` | BudgetLocated を既定の import へ接続 |
| `docs/design/01-spec/01-12-core-calculus.md` | 証明済みの位置の述語と言明を「区間解析の予算付きの式とフロー」へ反映 |
| `docs/design/07-quality/07-04-formal-semantics.md` | 位置の保証と、未接続の警告原因・Rust/VM との境界を反映 |
| 本記録 | 検査・計画との差・申し送り |

`skip_silent` は全8種の skip 群について、任意の予算・入力 Context で、成功・停止とも出力の警告列が入力と等しいことを示す。`analysis_located` は expr・shortCircuit・block・armList の追加警告について、その部分木の番号列に属する出現があり、targetOperationAt が警告の対象演算に一致することを同時に示す。`located_bind` は前半の成功時だけ Walk.success で中間の次キーを合わせる。`located_identified`・`own_warning_origin`・`located_own` は、親自身の候補を、取得に成功した親のキーと構文へ結び付ける。

後続が直接利用できる `expr_located`・`shortCircuit_located`・`block_located`・`armList_located` は、元の保存列と今回の追加分を ListExtension で分ける。expr_located は既存の numbered による位置を結論する。元からある警告に、今の部分木への所属や対象演算の一致を要求しない。いずれも任意の fuel・limits・Context を量化し、停止の有無を前提にしない。

`analyzeExpr_warning_located` は空の警告列から始める入口の出力全体へ位置の性質を写す。`analyze_warning_located : WarningLocated analyze` は L11d3 と同じ analyze・Parameters に接続しており、評価導出・完走・予算内・事前の警告健全性を前提に加えていない。

## 実行した検査

コマンドはリポジトリの根を基準とし、lake の局所検査だけは formal/ で実行した。シェルは原則として rtk proxy を通した。指定 work と公理依存の確認は Python の time.monotonic() で外側の時間を測った。他の状態の検査結果は引用していない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `git status --short`・`git rev-parse HEAD`・ブランチ名の読み取り、指定文書と現行定義の確認 | 0。基準・ブランチと差分なしを確認 | 未計測 |
| `lake env lean Benitoite/Interval/BudgetLocated.lean`（作成中の6回） | 3回終了1、修正後の3回は終了0。最後の実行では入口の WarningLocated まで成功 | 未計測 |
| `scripts/check.sh --level work --base 182a4d21c86421cd697d715131fb640872abbf79 --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様参照印の自己検査と集計、仕様例、既定 lake build と未証明の穴の拒否を選択 | 0.016秒 |
| `scripts/check.sh --level work --base 182a4d21c86421cd697d715131fb640872abbf79 --only formal_build,spec_examples,spec_tally` | 0。集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功。本実行は一度だけ | 11.208秒 |
| `lake env lean /tmp/benitoite-l11d4a-axioms.lean` | 0。下記13宣言の公理依存を確認 | 0.320秒 |
| 結果記録用の書式・相対リンクの Python 検査（初回） | 1。既存のコード表記のラムダをリンクと誤認したため、コードを除いてリンクを調べるよう検査側を修正 | 未計測 |
| `git diff --check`、変更5ファイルの末尾空白・Markdown のフェンス・既存の相対リンク・最終 HEAD と変更範囲の確認 | 0。HEAD は基準と同じ、変更範囲は上記5ファイル | 未計測 |

作成中の最初の終了1は、Silent の定義を明示的に展開する intro、scope 内部の出力型、spec_pure の識別対応の述語、branch の skip に対する Walk の指定不足によるものだった。二回目は scope の状態を場合分けした後の簡約不足であり、内部実行の等式による簡約を補った。三回目の失敗は腕列の証明での継続行のインデントであり、none の分岐を複数行に直した。解析や定理の条件を緩める修正は行っていない。

spec_tally は参照印のない節を一覧表示したが、初回リリース版の未記入の完了条件は none であり、集計は成功した。仕様例・既存の独立例・検査の期待値は変更していない。段・改造・公開候補の全件検査と Rust/Lean の全比較は先取りしていない。

一時ファイルは BudgetLocated・BudgetNormal を import し、次の宣言に `#print axioms` を実行した。この記録は位置の証明の依存の確認であり、後続で行う旧主定理を含む全体照合を代替しない。

| 対象 | 公理依存 |
|---|---|
| BudgetAnalysis.own_warning_origin | propext |
| BudgetAnalysis.skip_silent・analysis_located・expr_located・shortCircuit_located・block_located・armList_located・analyzeExpr_warning_located・analyze_warning_located | propext・Classical.choice・Quot.sound |
| BudgetAnalysis.analyze_normal_sound、Interval.analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located | propext・Classical.choice・Quot.sound |

## 計画との差と申し送り

停止条件に該当する問題や、未解決の判断はない。設計書は、今回実際に閉じた位置の保証だけを同じ変更で反映した。警告原因を含む写し全体の照合は L11d4c に残す。番号のための事前走査や、同じ深さの旧解析との等式は追加していない。

| 担当・時期 | 残る範囲 | 見込み時間 |
|---|---|---:|
| 取りまとめ、L11d4b の前 | 本作業の定義・言明・仮定の独立レビューと受け入れ | 不明 |
| L11d4b | 警告原因の保存列用の合成補題。今回の位置の定理と成功時の番号消費を利用できる。子の性質を仮定する補題では引数に明示する | 計画の1〜2時間 |
| L11d4c | 警告原因の相互帰納法と WarningSoundness、写し全体と旧・新の公理依存の照合 | 計画の2〜3時間 |
| L26 | 本体名・別本体の全列挙・元 AST の NodeId/span との対応。今回の部分木の位置の証明と区別する | 不明 |
| 後続 X | Rust/Lean・VM との比較。今回の Lean ビルドの成功から一致を結論しない | 不明 |

本作業は位置と対象演算の一致を閉じたものであり、警告位置で演算が失敗することを結論する WarningSoundness は未接続である。親 L11 の完了や、L12・A11・L27 へ渡す任意の予算での中心二定理の閉鎖としては扱わない。
