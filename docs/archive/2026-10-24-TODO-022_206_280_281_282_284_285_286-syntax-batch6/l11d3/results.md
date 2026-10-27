# 作業 L11d3 の結果

2026-10-24。L11d3 の実装と指定 work を完了した。独立レビュー・受け入れは取りまとめの担当であり、本記録で完了とはしない。基準 B_WORK と着手時・検査後の HEAD は `828bd8cf31f5ee7e950ffe0ae72e36248b383854`、ブランチは `mod012/L11d3`、着手時の差分はなかった。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。他の results.md には追記していない。

## 変更と後続へ渡す契約

`formal/Benitoite/Interval/BudgetNormal.lean` を新設し、既定の `formal/Benitoite.lean` から import した。成功値の命題 Success と24補題を定め、任意の予算に対する正常値の中心定理へ接続した。実行する expr・shortCircuit・block・armList、skip 群、局所走査、予算の計上と停止の定義は変更していない。

- Success work post は、任意の Limits・Context で成功した値が post を満たすことを表す。success_bind・success_before・success_scope は実際の中間状態を通して成功値を合成し、停止した実行に成功値を要求しない。success_scan_agrees は既存の局所走査の成功時の一致を使い、success_branch_selected は具体評価で選ばれた枝と同じ環境へ接続する。
- expr_normal・block_normal・armList_normal と短絡の二補題は、予算付きの解析を直接辿る相互帰納法で、成功値が NormalCovered を満たすことを示す。二項演算は binary_normal で子の所属と演算の正常値を合成する。shortCircuit_normal は and・or の EvalPartial から、補助解析の成功値の所属を直接得る入口である。同じ深さの旧解析との等式を仮定していない。
- これらの正常値の補題は、任意の入力 Context に対して成立し、評価側のキーと解析側の次キーの一致を要求しない。警告欄の変更が正常値の所属を変えないことを contains_warnings・success_own で使う。番号走査の完走を正常値の前提に加えない。警告の位置については L11d2 の Traversal を別に用いる。
- report_normal・analyzeExpr_normal は、成功時の所属と、停止時の baseUnknown の全値域への所属を同じ Report へ接続する。深さ0、操作・保持の上限、初期の消費量、停止理由についての制約を付けない。
- BudgetAnalyze.lean に Parameters（limits・state・fuel）、Report.toAnalysisResult、analyze を加えた。射影の normal は入力の型との一致と近似への所属の論理積、mayFail・warnings は Report の近似の同名の欄である。analyze_normal_sound は、この入口が既存の `NormalSoundness Models analyze` をそのまま満たすことを示す。完走・予算内・事前の警告健全性の前提を加えていない。

既存の Sound.lean の正常値の合成と環境対応の14補題、NormalTyped・NormalCovered を、新しい証明から使えるよう private から通常の宣言へ変更し、説明を付けた。これらの定義・言明・証明本体、旧主定理と既存の中心命題の前提・結論は変えていない。01-12「区間解析の予算付きの式とフロー」と 07-04「01-12 との対応」に、今回閉じた定義と言明を写した。

## 独立例と作成時の関門

test-audit の作成時の関門を通し、BudgetAnalysisExamples.lean に共通の解析結果の入口を使う比較例を一つ追加した。短絡式 `false and true` について、深さ4で完走したときは偽だけを正常値に含み、深さ2と操作上限0で停止したときは両方の真偽を含むことを確かめる。停止時でも、Boolean の入力に Integer の値を含めない。

守る契約は、共通の射影での完走時の精度、停止時の全値域、入力の型との一致である。常に Top を返す、停止した部分を狭い結果として返す、射影の型との一致を落とす退行で失敗する。既存例は Report までを対象とし、今回加えた AnalysisResult の入口は対象にしていなかった。実際の入口を使い、テストのための公開範囲・差し込み口を加えていない。期待する具体値は固定し、解析結果から生成していない。既存のテストの削除・緩和はない。

実行する既存の解析の変更は0行であり、中心命題への入口を16行加えた。新しい証明ファイルは552行、既定 import は1行増加した。独立例のファイルは import の差し替えを含め17行追加・1行削除（差し引き16行増加）である。Sound.lean は公開範囲の変更と説明の追加だけで32行追加・16行削除、BudgetAnalyze.lean は入口と先頭コメントの更新で17行追加・1行削除である。

例の初回は Ty の等式の Decidable を合成できず、射影と型の等式を簡約してから判定する形へ直した。その後、完走を深さ3とした期待値が失敗した。skipExpr が飛ばす右辺を識別した後、skipChildren にも正の深さが必要なことを定義と実評価で確認した。深さ2・3は停止、4・5は完走であり、完走側の入力を4に修正した。解析の深さの規則と、停止時に両真偽を含む期待は変えていない。最終の比較例は成功した。

## 実行した検査

コマンドはリポジトリの根を基準とする。lake のコマンドだけは formal/ で実行した。シェルは原則として rtk proxy を通した。作業末の dry-run・work と公理依存の照合は Python の time.monotonic() で外側を測った。局所検査の時間は実行ツールまたはビルド表示による概数である。他の状態の結果は引用していない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| 着手時の状態・HEAD・ブランチの読み取り、指定文書と現行の定義・設計書の確認 | 0。指定の基準と差分なしを確認 | 未計測 |
| `lake build Benitoite.Interval.Sound`、`lake build Benitoite.Interval.BudgetTraversal`、`lake build Benitoite.Interval.BudgetNormal` と `lake env lean Benitoite/Interval/BudgetNormal.lean`（作成中の反復） | 最終0。補助補題と中心定理を未証明の穴なしで確認 | BudgetNormal の最終局所ビルドは約13秒 |
| `lake env lean /tmp/benitoite-l11d3-probe.lean` | 0。短絡の深さ2・3の停止と4・5の完走を確認 | 約0.2秒 |
| `lake env lean Benitoite/Interval/BudgetAnalysisExamples.lean`（作成中の反復） | 最終0。追加した比較例を含め成功 | 最終約0.53秒 |
| `scripts/check.sh --level work --base 828bd8cf31f5ee7e950ffe0ae72e36248b383854 --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様集計の自己検査と集計、仕様例、既定 lake build と未証明の穴の拒否を選択 | 0.011秒 |
| `scripts/check.sh --level work --base 828bd8cf31f5ee7e950ffe0ae72e36248b383854 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功。一度だけ実行 | 40.765秒 |
| `lake env lean /tmp/benitoite-l11d3-axioms.lean`（新規28宣言と既存7定理への `#print axioms`） | 0。下表の範囲を確認 | 0.322秒 |
| `git diff --check`、変更ファイルの文章・差分・Markdown フェンス・末尾空白・未証明の穴の確認、最終 HEAD の照合 | 0。対象範囲と基準の保持を確認 | 未計測 |

証明作成中の局所コンパイルでは、モナドの展開、射影の簡約、match の局所変数の指定、走査の一致の補題の引数指定で失敗した。実行する定義に合わせて証明を修正し、言明の前提・結論を緩めずに解消した。入口の射影の改行による構文上の誤りも修正した。相互帰納法の精緻化では既定の heartbeat を超えたため、この相互ブロックだけ `maxHeartbeats 800000` とした。これは Lean の証明の精緻化の探索予算であり、解析の fuel・操作数・保持数の上限や検査の時間制限は変えない。指定 work 本実行に失敗はない。

spec_tally は参照印のない節を一覧表示したが、初回リリース版の未記入の完了条件は none であり、集計は成功した。段・改造・候補の全件検査と Rust/Lean の全比較は先取りしていない。

## 公理依存・計画からのずれ・申し送り

新規宣言の名前空間は Benitoite.Interval.BudgetAnalysis である。再実行する場合は BudgetNormal・Release.Theorems・Surface.Theorems を import し、BudgetNormal の25宣言、Parameters・Report.toAnalysisResult・analyze と下表の既存7定理へ `#print axioms` を実行する。

| 対象 | 公理依存 |
|---|---|
| Success・success_any・success_pure・success_throw・success_unsupported・Parameters | なし |
| success_bind・contains_warnings・success_before・success_any_covered・success_unknown_after・report_normal・Report.toAnalysisResult | propext |
| success_scan_agrees・own_contains | propext・Quot.sound |
| success_scope・success_own・success_branch_selected・expr_normal・binary_normal・shortCircuit_short_normal・shortCircuit_right_normal・block_normal・armList_normal・shortCircuit_normal・analyzeExpr_normal・analyze_normal_sound・analyze | propext・Classical.choice・Quot.sound |
| Interval.analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located | propext・Classical.choice・Quot.sound |
| Release.progress・preservation・effect_soundness、Surface.desugar_typed | propext・Classical.choice・Quot.sound |

旧主定理・中心命題の前提と結論、言語の規則、公理・Builtins.Assumptions は変更していない。停止条件に当たる反例や変更の必要はなかった。範囲のずれはなく、証明は新しい BudgetNormal.lean にまとめた。検査表に L11d3 の行がない点は、依頼の補足で指定された三単位を使った。

次は取りまとめが定義・言明・仮定を独立レビューし、受け入れ後に L11d4 へ渡す。L11d4 は、今回定めた Parameters・射影・analyze をそのまま警告の中心命題と WarningLocated の入口に使える。expr_normal・block_normal・armList_normal は任意の中間 Context に適用でき、評価側のキーに合わせ直す前提も要らない。保存列と新しい警告の区別には L11d1 の補題、警告キーと出現の対応には L11d2 の補題を併用する。

任意の予算に対する WarningSoundness・WarningLocated、L11 全体の受け入れは未完了である。本体の命名・別本体の全列挙・元 AST との対応は L26、Rust/VM との比較は後続の X 作業の範囲であり、今回の正常値の定理から結論しない。独立レビュー・受け入れと後続作業の時間は取りまとめ担当、時間不明である。
