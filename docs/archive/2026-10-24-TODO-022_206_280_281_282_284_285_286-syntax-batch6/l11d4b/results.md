# 作業 L11d4b の結果

2026-10-24。L11d4b の実装と指定 work を完了した。独立レビュー・受け入れは取りまとめの担当である。基準 B_WORK と着手時の HEAD は `b4ccf770e101fbc2522a3123d2c01c5e08f4ec9f`、ブランチは `mod012/L11d4b`、着手時の差分はなかった。private/ とそれを指すスキルのリンクは読まず、git の変更操作は行っていない。他の results.md には追記していない。他の状態の検査結果は引用していない。

## 変更と受け渡す契約

`formal/Benitoite/Interval/BudgetCause.lean` を追加し、`formal/Benitoite.lean` の既定 import に接続した。定義・証明済みの言明の写しを 01-12「区間解析の予算付きの式とフロー」と 07-04「01-12 との対応」に加えた。処理系・評価関係・予算計上・既存の定理の言明と証明・公理は変更していない。

- `CauseIn` は、警告キーの範囲と、同じキー・対象演算への Reached に対する拒否原因の一致を組にする。`Causal` は、その性質を warningsRev の ListExtension の追加分だけに課す。入力に既にある警告は、別の定義や部分木の警告でもよい。
- `causal_bind_append` は、子ごとの Causal、TraceKeys、範囲の分離を引数として、保存列の追加順と実行順の trace を分けて合成する。`causal_bind_follow` は成功した Walk の番号消費を使い、`causal_bind_root` は子と親自身の一番号を分ける。前半が停止した場合は、後続の子の性質を要求しない。
- `causal_absent` は、既存の Located から未実行部分の範囲と空 trace に対する原因を得る。Silent な番号走査は警告の追加なしとして扱う。`causal_saveWarnings`・`causal_own` は、候補の保存途中の停止も含む。
- `own_add_cause`・`own_div_cause` は、正常な二引数の近似への所属から、あふれ・除数0の局所の原因を示す。`expr_normal_next`・`block_normal_next`・`binary_operands` は、同じ成功実行の正常値所属と次キーの消費を合わせる。`causal_add_of_operands`・`causal_div_of_operands` は、左右の実際の中間 Context を経て、続く own の保存した追加分へ接続する。
- `branch_entry_of_success`・`arm_entry_of_success` は、具体評価の選択に対応する入口と Models を得る。`causal_branch_selected`・`causal_arm_selected` は選んだ子の Causal を明示的に要求する。各 `_absent` 補題は、解析し得る入口ごとの空 trace に対する Causal と、番号走査の Silent を分けて要求する。子の警告の健全性を証明済みとして隠した仮定は置いていない。

## 実行した検査

コマンドはリポジトリの根を基準とし、lake は formal/ で実行した。シェル操作は原則 rtk proxy を通した。時間を数値で記したものは Python の time.monotonic() による外側の時間である。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `git status --short`・`git branch --show-current`・`git rev-parse HEAD`（読み取りのみ）、指定文書・現行定義・設計書の確認 | 0。指定された基準とブランチ、着手時の差分なしを確認 | 未計測 |
| `lake env lean Benitoite/Interval/BudgetCause.lean`（実装中の反復） | 初回1、修正後0。後半の補題を加えた反復も一度1となり、修正後と最終の局所検査は0 | 未計測 |
| `lake build Benitoite.Interval.BudgetCause` | 0。新モジュールをビルド。既存 Flow.lean:710 の unnecessarySimpa の警告だけが再表示された | 未計測 |
| `lake env lean /tmp/benitoite-l11d4b-probe.lean`（局所例と公理依存の照合） | 初回1、次の修正も1、最終0。下記の固定期待値と21宣言の公理依存を確認 | 0.338秒、0.345秒、0.351秒 |
| `scripts/check.sh --level work --base b4ccf770e101fbc2522a3123d2c01c5e08f4ec9f --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様集計の自己検査と集計、仕様例、既定 lake build と未証明の穴の拒否を選択 | 0.013秒 |
| `scripts/check.sh --level work --base b4ccf770e101fbc2522a3123d2c01c5e08f4ec9f --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功。本実行は一度だけ | 11.090秒 |
| `git diff --check`、最終の変更範囲・HEAD・結果記録のリンクと書式の確認 | 0。変更は新モジュール・既定 import・01-12・07-04・本記録だけ | 未計測 |

実装中の初回失敗は、Causal.mono の証明で省略した `.mono` が自身への再帰と解釈されたこと、bind の停止分岐で Causal とモナドの定義の展開が足りなかったこと、scope の内部実行の組を分解していなかったことによる。ListExtension.mono を明示し、必要な展開と場合分けを加えた。後半の失敗は、apply が並べた未解決の引数と証明の箇条の順が合わなかったこと、腕の継続の戻り値型を推論できなかったことによる。refine の引数を明示し、継続の型を Option AbstractEnv → Analysis α とした。定理の仮定・結論を弱めた修正ではない。

局所例の二度の失敗は、DecidableEq のない解析結果・警告列と、定義に隠れた Contains・Mem に `decide` を適用したことによる。固定結果の等式はカーネルによる簡約の `rfl`、整数の所属は具体的な不等式へ change して反射律で示した。解析や期待値は変えていない。

局所例では、開始キーを `Probe.cause` の40、入力警告を別定義 `Probe.previous` の7に固定した。1 intDiv 0 の own が新候補を保存した後、式の訪問の操作上限0で停止しても、出力列が `[新候補, 入力警告]`、次キーが元の40であることを確認した。同じ実行について causal_own・own_div_cause・causal_bind を適用し、新候補だけに拒否原因の性質を示した。別の固定期待値では、保持上限3で二候補の二件目が拒否され、同じ一件の追加分と入力の接尾辞だけが残ることを確認した。

test-audit の作成時の関門では、既存 BudgetAnalysisExamples の途中停止・既存列の保持・未選択枝の例が実行時の契約を既に検査していることを確認した。今回の追加は証明用の合成であり、その実行例を重ねる常設テストやテスト専用の公開口は加えていない。既存テストの削除・期待値の緩和もない。Lean の証明モジュールは413行の追加、常設テストの行数の増減は0行である。

spec_tally は参照印のない節を一覧表示したが、初回リリース版の未記入の完了条件は none であり、集計は成功した。stage・change・release や Rust/Lean の全比較は先取りしていない。

## 公理依存・計画からのずれ・申し送り

局所ファイルで `#print axioms` を実行した21宣言は、今回の causal_bind_append・causal_bind_follow・causal_bind_root・causal_absent・causal_add_of_operands・causal_div_of_operands・causal_branch_selected・causal_branch_absent・causal_arm_selected・causal_arm_absent・branch_entry_of_success・arm_entry_of_success と、既存の analyze_normal_sound・analyze_warning_located・analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located・Release.progress・Release.preservation・Release.effect_soundness・Surface.desugar_typed である。causal_absent の依存は propext・Quot.sound、ほか20宣言は propext・Classical.choice・Quot.sound だった。新しい公理と Builtins.Assumptions の追加はない。

計画からの範囲のずれと、判断待ちで停止した点はない。指定された合成補題を独立した BudgetCause.lean にまとめ、同じ変更で既定 import と設計書の写しへ接続した。警告原因の相互帰納法を先取りしたものではない。

L11d4c は、これらを使って expr・shortCircuit・block・armList の追加警告の Causal を閉じ、空の警告列から始める同じ analyze の WarningSoundness へ接続する。兄弟や未実行部分の排除には eval_trace_keys・block_trace_keys・arms_trace_keys と、今回の範囲の合成を使える。子の正常値の所属と実際の次キーは、成功した中間 Context の等式を渡して得る。停止した実行には正常値の成功を要求せず、既に追加した警告を Causal の保存列の性質として扱う。

L11d4c での中心定理の接続、そこでの公理依存の最終照合と L11 全体の独立レビュー・受け入れは未実施であり、担当は L11d4c と取りまとめである。今回の補題を中心定理の完了や Rust へ進む受け入れ済みの区切りとして扱わない。01-12・07-04 にもこの保証の範囲を明記した。
