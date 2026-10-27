# 作業 L11a の結果

2026-10-24。L11a の実装と指定 work を完了した。独立レビュー・受け入れは取りまとめの担当であり、本記録はその完了を主張しない。基準 B_WORK と着手時の HEAD は `63623fd28e2f20ca7a24a1e770e3d5f81cb0f001`、ブランチは `mod012/L11a`、着手時の差分はなかった。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。

## 実行した検査

コマンドはリポジトリの根を基準とし、`lake` のみ `formal/` で実行した。シェル経由では原則として `rtk proxy` を使った。work 本実行の外側の時間は Python の `time.monotonic()` で計測した。局所 Lean の時間は実行ツールが返した外側の時間を丸めたものである。過去の結果の引用は行っていない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| 読み取りの `git status --short`・`git branch --show-current`・`git rev-parse HEAD` | 0。上記の初期状態を確認 | 未計測 |
| `lake env lean Benitoite/Interval/Budget.lean`（開発途中の初回・2回目） | 各1。補助証明の簡約不足を検出。下記の修正後に成功 | 約0.37秒・0.53秒 |
| `lake env lean Benitoite/Interval/Budget.lean`（修正後） | 0 | 約0.54秒 |
| `lake build Benitoite.Interval.Budget Benitoite.Interval.BudgetExamples`（独立例の追加後、成功時の正確な計上の補題の追加後に各一度） | 各0、16 jobs。六つの独立例を含む | 約0.86秒・0.85秒 |
| `lake env lean /private/tmp/benitoite-l11a-axioms.lean`（新規公開定理26件の `#print axioms` を生成して実行） | 0。依存の和集合は Lean 標準の `propext`・`Classical.choice`・`Quot.sound` のみ。`sorryAx`・追加の独自公理なし | 約0.19秒 |
| `scripts/check.sh --level work --base 63623fd28e2f20ca7a24a1e770e3d5f81cb0f001 --only formal_build,spec_examples,spec_tally --dry-run` | 0。spec_tally・spec_examples・formal_build の三単位を名指しすることを確認 | 未計測 |
| `scripts/check.sh --level work --base 63623fd28e2f20ca7a24a1e770e3d5f81cb0f001 --only formal_build,spec_examples,spec_tally` | 0。一度実行。仕様集計の自己検査・集計、仕様例7件（失敗・ignore とも0）、既定 `lake build` と `sorry` 拒否が成功 | **9.247秒** |
| `git diff --check` と新規ファイルを含む末尾空白・フェンス・見出しの静的確認 | 0。最終の確認も実施 | 未計測 |

spec_tally は、予算の新節を含む「テストの参照印がない節」を表示した。完了条件の未記入は none であり、集計は成功している。新節の証拠は `BudgetExamples.lean` の六つの独立例と Budget の定理であり、Rust のテストを追加したと扱わない。

初回の局所 Lean の失敗は、Valid の展開前の `decide`、資源別の match と二段の条件分岐、確保の let の展開不足によるものだった。2回目は、保存・返却の証明で match と保持数の定義を展開しきれていなかった。必要な場合分けと定義の展開後に `simp`・`omega` で閉じ、定義や言明を弱めずに修正した。静的確認の初回も、通常の補助関数名 `admit` を未証明の穴と誤判定したため終了1となった。確認対象を公理宣言・未証明の穴へ直して再実行し、成功した。実際の Lean の未証明の穴の拒否は指定 work に委ねている。

## 計画との差と作成時の関門

L11a の範囲からの変更はない。`Budget.lean` に予算状態と遷移・26件の公開補題を追加し、独立例は同じディレクトリの `BudgetExamples.lean` に分けた。両方を既定の `formal/Benitoite.lean` に import した。01-12「区間解析の予算の状態と計上」と07-04「01-12 との対応」に、閉じた定義・言明と保証の範囲を反映した。言語規則、旧主定理、中心命題の前提と結論、公理・`Builtins.Assumptions` の変更はない。

独立例は test-audit の作成時の関門を次のとおり通した。守る契約は、上限ちょうどまでの成功と0での拒否、拒否した実消費の保存、返却と再確保、本体をまたぐ累積操作数・保存項目、番号未取得の分類である。拒否候補を状態に採用する、本体終了で全体を初期化する、保存項目を落とす、削除しても返却しない、という退行で失敗する。既存の深さの打ち切りの例はこの新しい状態遷移を呼ばず、同じ失敗を検出できない。新しい予算の入口を直接使い、検査専用の差し込み口・ラッパーは追加していない。既存テストの変更・削除はなく、独立例のファイルを84行追加した。

## 後続への申し送り

- L11b は `Budget.charge` と `reserve` を実操作・実項目の追加直前に呼び、`Step.stopped` なら対象の操作・追加を行わない。操作と保持の単位は D16 と同じであり、追加の事前走査は Budget 自身にはない。どの走査で各項目が生じるかの接続は L11b の担当である。
- `Limits` の既定は本体が各100,000、全体が各1,000,000である。上限ちょうどは成功し、同時に両上限を超えた場合は本体を先に報告する。`StopReason.exceeded` の scope と resource で本体/全体・操作数/保持数を区別する。番号付けの呼び出し側は `Step.forNumbering` で unidentified へ分類し、元の超過原因と最後の状態を保つ。
- 本体の一時項目と保存項目を区別し、必要なら `save` で複製せず保存へ移す。現本体の削除は `release`、完了済み本体の保存項目の削除は `releaseSaved` で返す。いずれも過剰な返却を防ぐ個数の証拠を要求する。同じ内容を二か所に保存する場合は二回確保する。
- `finishBody` の前に当該 body の操作数・peak を記録する。終了は一時項目だけを返し、保存項目は whole.saved へ移す。全体の累積操作数と peak は初期化しない。`finish_saved`・`finish_held` が保存項目の総数と一時項目だけの返却を示す。
- L11c の共有状態の解析への逐次接続と Unknown への退避、既存警告の保持、L11d の任意の予算に対する中心二定理と WarningLocated の合成は未実施である。既存の `analyzeBase` は深さによる打ち切りのままであり、L11 全体の完了や C1 の受け入れとは扱わない。独立レビューと受け入れは取りまとめが本枝の後に行う。Rust/VM の全比較は本枝の検査範囲に含めていない。

## L11b の検査記録（依頼の補足による追記）

2026-10-24 の L11b の依頼の補足に従い、今回の三検査を追記した。上の L11a の本文は当時の記録として保つ。今回の基準 B_WORK・HEAD は `a99bc91ea98b45f9f5542b09a2b33401452269b9`、ブランチは `mod012/L11b`。L11b の変更と申し送りは [L11b の結果](../l11b/results.md)に記録した。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `scripts/check.sh --level work --base a99bc91ea98b45f9f5542b09a2b33401452269b9 --only formal_build,spec_examples,spec_tally --dry-run` | 0。spec_tally・spec_examples・formal_build の三単位を確認 | 約0.1秒 |
| `scripts/check.sh --level work --base a99bc91ea98b45f9f5542b09a2b33401452269b9 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功 | 13.983秒 |

work 本実行の外側の時間は Python の time.monotonic() で計測した。L11b の範囲の検査であり、L11 全体の完了・独立レビュー・受け入れは別に扱う。

## L11c の検査記録（依頼の補足による追記）

2026-10-24 の L11c の依頼の補足に従い、今回の三検査を追記した。上の L11a・L11b の記録は当時の記録として保つ。今回の基準 B_WORK・HEAD は `bfdffb78a55ab72648b7aa412442c308e1a38fe7`、ブランチは `mod012/L11c`。変更と申し送りは [L11c の結果](../l11c/results.md)に記録した。

| コマンド | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `scripts/check.sh --level work --base bfdffb78a55ab72648b7aa412442c308e1a38fe7 --only formal_build,spec_examples,spec_tally --dry-run` | 0。spec_tally・spec_examples・formal_build の三単位を確認 | 約0.1秒 |
| `scripts/check.sh --level work --base bfdffb78a55ab72648b7aa412442c308e1a38fe7 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功 | 14.054秒 |

work 本実行の外側の時間は Python の time.monotonic() で計測した。L11c の範囲の検査であり、任意の予算についての中心二定理と WarningLocated、L11 全体の完了・独立レビュー・受け入れは別に扱う。
