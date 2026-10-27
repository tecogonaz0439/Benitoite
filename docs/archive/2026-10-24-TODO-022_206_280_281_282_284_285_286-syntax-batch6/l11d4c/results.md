# 作業 L11d4c の結果

2026-10-24。L11d4c の実装と指定 work は完了した。独立レビューと受け入れは取りまとめの担当である。基準 B_WORK と作業後の HEAD は `31c652d7de679cdca9b7a0d8b98e488cf57a12de`、ブランチは `mod012/L11d4c` である。

前回の起動は Codex の「Selected model is at capacity」で打ち切られていた。着手時にあった未追跡の `formal/Benitoite/Interval/BudgetSound.lean` を引き継ぎ、残っていた `sorry` を全て解消した。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。他の results.md には追記していない。

## 変更と計画との対応

| ファイル | 変更 |
|---|---|
| `formal/Benitoite/Interval/BudgetSound.lean` | 式・短絡・全 Block 形・整数の腕列の警告原因を相互帰納法で閉じ、analyzeExpr_warning_sound と analyze_warning_sound を証明した。成功・停止に共通する追加警告を対象とし、既存の警告列には現在の部分木の性質を要求しない |
| `formal/Benitoite.lean` | BudgetSound を既定の import に追加した |
| `docs/design/01-spec/01-12-core-calculus.md` | 「区間解析の予算付きの式とフロー」に、各帰納法の前提と結論、同じ analyze の WarningSoundness への接続を写した |
| `docs/design/07-quality/07-04-formal-semantics.md` | 「01-12 との対応」と対象の一覧を更新し、共有予算付きの中心二定理と WarningLocated が閉じた範囲を示した |
| 本記録 | 基準・検査・修正・公理依存・申し送りを記録した |

実行した子には Models と評価導出を渡し、実行しない枝・腕・後続には位置の保証から空 trace の原因を得る。成功した中間 Context の正常値所属と番号消費を使い、子と親自身の演算、条件と枝、guard と本体・後続腕を分けて合成した。偽の guard から進む後続腕には元の環境を渡す。腕の先頭の解析の略記と先行順の列は証明内だけで使い、実行する解析や予算の計上を変更していない。

作業範囲に計画からのずれはない。検査の割り当て表に L11d4c の行がないため、依頼文の補足で指定された三単位を使った。

analyze_warning_sound の言明は既存の `WarningSoundness Models analyze` である。先行作業の analyze_normal_sound・analyze_warning_located と同じ入口・Parameters を使う。解析の完走・予算内・事前の警告健全性を中心命題の前提に加えていない。旧主定理・中心命題・評価関係・Builtins.Assumptions は変更せず、公理も追加していない。言語の規則に関する未決事項や停止条件への該当はない。

## 実行した検査

コマンドはリポジトリの根を基準とし、lake は formal/ で実行した。シェルは原則として rtk proxy を通した。指定 work と公理依存の照合は Python の time.monotonic() で外側の時間を測った。他の状態の検査結果は引用していない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `git status --short`・`git rev-parse HEAD`・`git branch --show-current`（読み取りのみ）、指定文書・現行の定義の確認 | 0。基準・ブランチと、引き継いだ未追跡ファイルを確認 | 未計測 |
| `lake env lean Benitoite/Interval/BudgetSound.lean`（実装中の反復） | 初回0だが未完成の sorry が残っていた。追加実装中に1となった後、最終0。最終の局所検査は警告なし、sorry なし | 未計測 |
| `scripts/check.sh --level work --base 31c652d7de679cdca9b7a0d8b98e488cf57a12de --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様集計の自己検査と集計、仕様例、既定 lake build と未証明の穴の拒否を選択 | 0.016秒 |
| `scripts/check.sh --level work --base 31c652d7de679cdca9b7a0d8b98e488cf57a12de --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功。本実行は一度だけ | 42.766秒 |
| `lake env lean /tmp/benitoite-l11d4c-axioms.lean` | 0。既定の Benitoite を import し、新しい公開定理32件と既存定理9件に #print axioms を実行 | 0.621秒 |
| `git diff --check`、最終の変更範囲・未追跡ファイルの空白・文書のフェンスと相対リンクの確認 | 0 | 未計測 |

実装中の失敗は、予約語を使ったパターン変数、継続や guard 本体の暗黙引数の未確定、先行順の長さと blockSize・guardSize の書き換え不足によるものだった。変数名・引数・長さの補題を補った。腕の解析の略記では、同じ形の match の補助関数が異なるため単純な型の一致で渡せず、解析の等しさを合同性で示してから Causal を渡した。不要な simpa を整理した際の括弧の脱落も修正した。文書更新用の Python の標準入力で文字コードエラーが一度あったため、文字列を Unicode のエスケープで渡して更新した。いずれも指定 work の前に解消し、言明・評価規則・検査の期待値を緩めていない。

spec_tally は参照印のない節を表示したが、初回リリース版の未記入の完了条件は none であり、集計は成功した。今回の変更ではテストの追加・変更は行っていない。

最終の文書確認用の一時スクリプトは、初回に既存の数式中の記法を相対リンクと誤認して停止した。フェンスとインラインコードをリンク検査から除くよう確認用スクリプトを直し、終了0を確認した。文書側のリンクの修正は不要だった。

## 公理依存の照合

一時ファイルは `import Benitoite` から、BudgetSound の公開定理32件と、予算付きの正常値・位置の定理、旧解析の三定理、Release の三主定理、Surface の脱糖の型保存を照合した。

| 対象 | 公理依存 |
|---|---|
| preorder_expr_length・silent_unsupported | なし |
| blockSize_bind・blockSize_discard・blockSize_seq・blockSize_bindPat・Causal.parent・trace_follow | propext・Quot.sound |
| 上記以外の BudgetSound の公開定理24件（expr_causal・短絡の二定理・block_causal・armList_causal・analyzeExpr_warning_sound・analyze_warning_sound を含む） | propext・Classical.choice・Quot.sound |
| BudgetAnalysis.analyze_normal_sound・analyze_warning_located、Interval.analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located | propext・Classical.choice・Quot.sound |
| Release.progress・preservation・effect_soundness、Surface.desugar_typed | propext・Classical.choice・Quot.sound |

新しい中心定理と既存の中心定理・旧主定理の依存集合は一致した。照合した41宣言に sorryAx や新しい公理への依存はない。

## 申し送り

L11 の共有予算付きの入口では、正常値・警告の中心二定理と WarningLocated の実装が揃った。L11d4c の範囲の未接続・未実施の検査はない。取りまとめは、定義・言明・仮定の独立レビューと L11 全体の受け入れを行ってから、後続作業の前提にする。

本体名・別本体の全列挙・元 AST との対応は L26、実行可能な土台の区切りと C1 は L12、Rust/Lean と VM の全比較は後続の X 作業の範囲である。段・改造・公開候補の検査や check-formal.sh の全比較を先取りしていない。コミットと取り込み、docs/todo の更新も取りまとめへ渡す。
