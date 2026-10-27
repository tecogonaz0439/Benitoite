# 作業 L11d1 の結果

2026-10-24。L11d1 の補助補題の実装と指定 work は完了した。基準 B_WORK と着手時の HEAD は `67ed35403d349aee9771d86f0db6b3e47ae195a0`。着手時の差分はなかった。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。独立レビューと受け入れは取りまとめの担当であり、本記録で完了とはしない。

## 変更と後続へ渡す契約

`formal/Benitoite/Interval/BudgetProof.lean` を新設し、既定の `formal/Benitoite.lean` から import した。実行する解析と予算の定義は変えず、三つの証明用の命題と20補題を加えた。

- ListExtension は「出力列 = 追加分 ++ 入力列」と、追加分の各要素の性質を表す。Saved は警告列と識別対応の列の二つを扱う。入力からある要素には、現在の部分木についての性質を要求しない。
- Spec は成功値の性質と、成功・停止に共通の Saved を組にする。spec_bind は実際の成功値と中間 Context を後続へ渡し、先行が停止した場合には後続の契約を要求しない。spec_scope は枠の確保での停止と、内部の実行後の一時項目の返却を扱う。scan・numbering・identify・saveWarnings も同じ Spec で合成できる。
- identify_success は成功値が入力の next であること、次番号を一つ進め、そのキーと式の対応を一件追加することを示す。identify_stopped は停止時の警告列・対応列・次キー・未対応の記録の保持を示す。
- saveWarnings_progress は候補列を written ++ rest に分け、出力の警告列が reverse written ++ 入力の警告列であることを成否によらず示す。成功時には rest が空である。対応列・次キー・未対応の記録も保持する。

01-12「区間解析の予算付きの式とフロー」と 07-04「01-12 との対応」に、これらの定義と言明の写しを加えた。任意の予算についての中心二定理と WarningLocated を、この補助補題だけから証明済みとはしていない。

番号付けの対象となる部分木の大きさと番号消費の一致、skip 群と解析した部分の接頭辞の対応は L11d2 に残す。今回の identify の定理は一出現だけの契約であり、L26 の本体名・全列挙・元 AST との対応には進んでいない。L11d3 の正常値、L11d4 の警告と WarningLocated、Rust/VM との接続も未実施である。親の L11 は未完了である。

## 局所例と作成時の関門

test-audit の作成時の関門を通し、既存の BudgetAnalysisExamples.lean に比較例を一つ追加した。空でない警告列と対応列を持つ Context から、二候補の保存の途中停止と完走を比べる。守る契約は、既存の接尾辞の保持、候補の追加順、拒否した候補の除外、作業枠の返却と保存数である。既存例には、候補の途中で止まる非空の入力保存列の確認がなかった。列を消す・順序を逆にする・拒否した候補を追加する退行で失敗する。既存の保存入口を使い、テスト用の公開範囲や差し込み口は追加していない。期待する警告のキー・原因・停止理由・保存数は固定値として書き、検査対象の処理から生成していない。

## 実行した検査

コマンドはリポジトリの根を基準とする。lake のコマンドだけは formal/ で実行した。シェルは原則として rtk proxy を通した。作業末の dry-run・work と公理依存の照合は Python の time.monotonic() で外側を測定した。局所の Lean の時間は実行ツールによる概数である。他の状態の結果は引用していない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `git status --short`・`git rev-parse HEAD`（読み取りのみ） | 0。上記の基準と着手時の差分なしを確認 | 未計測 |
| `lake env lean Benitoite/Interval/BudgetProof.lean`（証明作成中の反復） | 最終0。三つの命題と20補題を確認 | 各回おおむね0.3〜0.5秒 |
| `lake env lean Benitoite/Interval/BudgetAnalysisExamples.lean`（局所例の確認） | 最終0。追加した比較例を含め成功 | 最終約0.44秒 |
| `scripts/check.sh --level work --base 67ed35403d349aee9771d86f0db6b3e47ae195a0 --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様集計の自己検査と集計、仕様例、既定 lake build と未証明の穴の拒否を選択 | 0.010秒 |
| `scripts/check.sh --level work --base 67ed35403d349aee9771d86f0db6b3e47ae195a0 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功 | 9.421秒 |
| `lake env lean /tmp/benitoite-l11d1-axioms.lean`（下表の27宣言への `#print axioms`） | 0。追加の公理依存は下表の範囲 | 0.320秒 |
| `git diff --check` と最終の対象ファイルの文章・差分確認 | 0。末尾空白・差分の範囲を確認 | 未計測 |

証明作成中の局所コンパイルは、モナドの展開が期待する形と一致しない箇所、レコードを引数にする改行の構文、リスト連結の簡約で失敗した。既存の Analysis の定義に合わせて展開と証明項を修正し、言明の前提・結論は緩めずに解消した。追加例の最初のコンパイルは Except の等式の Decidable を合成できず失敗したため、同じ停止理由の判定を構成子の照合で書き、最終実行で成功した。指定 work 本実行の失敗はない。

spec_tally は参照印のない節を表示したが、初回リリース版の未記入の完了条件は none であり、集計は成功した。

## 公理依存と計画からのずれ

新しい補題の接頭辞は `Benitoite.Interval.BudgetAnalysis` である。既存の七宣言とともに `#print axioms` で確認した。

| 対象 | 公理依存 |
|---|---|
| ListExtension.mono・spec_mono | なし |
| ListExtension.trans・ListExtension.member・Saved.trans・spec_bind・spec_numbering | propext |
| ListExtension.refl・Saved.refl・spec_pure・spec_throw・spec_scan・spec_scan_agrees | propext・Quot.sound |
| spec_scope・identify_success・identify_stopped・spec_identify・saveWarnings_progress・saveWarnings_success・spec_saveWarnings | propext・Classical.choice・Quot.sound |
| Interval.analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located | propext・Classical.choice・Quot.sound |
| Release.progress・preservation・effect_soundness、Surface.desugar_typed | propext・Classical.choice・Quot.sound |

旧主定理・中心命題の前提と結論、公理・Builtins.Assumptions は変更していない。言語の規則の変更や公理の追加を必要とする行き詰まりはなかった。計画からの範囲のずれはなく、合成補題は既存の定義と証明を変更しない新しい BudgetProof.lean にまとめた。検査表に枝の行がない点は依頼の補足の指定に従った。他の results.md には追記していない。

次は取りまとめの独立レビュー・受け入れの後、L11d2 が今回の一出現の契約と保存列の合成を使い、番号走査の対応を証明する。レビュー・受け入れと後続の作業時間は本作業では計測していない。
