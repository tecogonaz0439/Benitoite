# 作業 L11d の結果

2026-10-24。**未完了。事前点検で証明の再分割が必要と判断し、実装前で停止した。** 基準 B_WORK と着手時の HEAD は `8803d6801758a65903979048a4ad647cf43e18a4`、ブランチは `mod012/L11d`、着手時の差分はなかった。変更は本記録だけである。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。

## 事前点検で確認した証明の接続

L11c の定義・補助定理と、Sound.lean の既存の三つの中心的な言明を照合した。次の表は実装と証明の構造を示す。健全性に反する具体評価を見つけたとの報告ではない。

| 箇所 | L11d で必要な接続 |
|---|---|
| `BudgetWalk.lean:28` の Analysis、`:31` の scan、`:37` の scope | Analysis は成功・停止のどちらでも Context を返す。局所の scan_preserves_saved だけでは、bind と scope をまたぐ保存列の接尾辞の保持や、新しく追加した警告の由来を示せない。成功値の性質と停止時までの状態の性質を同時に合成する補題が必要である。任意の入力 Context に既にある警告を、現在の部分木から生成した警告と混同しない言明にする。 |
| `BudgetWalk.lean:82` の相互再帰と `BudgetAnalyze.lean:48` の相互再帰 | 値を解析する expr・block・armList と、値を解析しない skip 群が同じ next を進める。右の子や後続腕の警告キーを具体評価の childKey・advanceKey と対応させるには、完走した部分が消費した番号数と、停止までの保存対応が先行順の接頭辞であることが必要である。全53構成子と相互帰納容器を持つ skip 群には、この対応の定理がまだない。 |
| `BudgetAnalyze.lean:50` の expr、`:120` の shortCircuit | 深さの消費が既存の analyzeBaseExpr と異なる。同じ Nat を渡した旧解析と結果が等しいとして、既存の定理を適用する方法は使えない。下記の実評価で、この等式が成立しない例を確認した。 |
| `BudgetAnalyze.lean:15` の saveWarnings、`:28` の own、`:197` の report | own は子を解析してから候補を保存する。候補の保存後、別の枝や番号走査で停止しても、その候補は出力に残る。完走した解析の正常値の一致だけでは、途中停止した出力の警告健全性を導けない。停止以前の各候補について、オペランドの正常値の所属と、評価事象とのキー・演算の一致を保つ必要がある。 |
| `Sound.lean:603`・`:1114`・`:1628` の相互再帰 | 正常値、WarningLocated、警告の既存証明は、深さによる純粋な解析を直接展開する。予算付きの解析については、共有状態の実行を分解し、局所走査が成功した場合の `_agrees` と、子の帰納法の仮定を接続する証明が必要である。既存の private な補助補題の再利用範囲も整理する必要がある。 |
| `Eval.lean:1185`・`:1193`、`Sound.lean:1057` | NormalSoundness・WarningSoundness・WarningLocated は、AbstractEnv → EvalInput → Budget → AnalysisResult の解析を受け取る。新しい入口は Report を返すため、任意の Limits・Budget.State・深さを受け取る入口と AnalysisResult への射影を定め、上の証明をここへ閉じる必要がある。既存の命題へ「完走した場合だけ」や「警告が既に健全である場合だけ」という前提を加えない。 |

番号の接続のうち、先行順の消費と停止時の接頭辞は L11d の警告位置の証明にも必要である。本体の命名・全列挙、元 AST との対応まで L11d へ移す案ではない。L26 を全て先に終えなければ証明不能だと判断したものでもない。取りまとめが、L11d 内で閉じる最小の番号補題と、L26 へ残す全走査の契約を明示することを勧める。

## 実評価と公理依存の確認

同じ深さでの旧解析との単純な一致を調べるため、次を一時ファイルに置き、formal/ で `lake env lean /tmp/benitoite-l11d-preflight.lean` を実行した。既存テストの変更・追加はない。

```lean
import Benitoite.Interval.BudgetAnalyze
open Benitoite.Interval Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release
#eval do
  let env := AbstractEnv.ofLocals []
  let key : OperationKey := ⟨"Probe.shortCircuit", 0⟩
  let source : Expr := .and (.literal (.boolean false)) (.literal (.boolean true))
  let old := analyzeBaseExpr 2 env key source
  let current := analyzeExpr {} {} 2 env key source
  return (old.boolean, current.approx.boolean, current.coverage)
```

結果は `((true, false), (true, true), Coverage.stopped Halt.depth)` だった。旧解析は偽の正常値に絞り、新解析は shortCircuit の追加の深さの消費によって停止し Top に退く。この例は、同じ深さでの両解析の結果の等式に対する反例である。正常値・警告の健全性の反例ではなく、深さの規則を変える根拠にしない。深さを十分増やした完走時の対応や、直接の健全性の帰納法を検討する必要がある。

同じ一時ファイルで既存の12宣言に `#print axioms` を実行し、次を確認した。再実行用には上記 import に `Benitoite.Release.Theorems` と `Benitoite.Surface.Theorems` を加える。新しい定理の公理依存の照合を済ませた記録ではない。

| 対象 | 公理依存 |
|---|---|
| Interval.analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located | propext・Classical.choice・Quot.sound |
| Release.progress・preservation・effect_soundness、Surface.desugar_typed | propext・Classical.choice・Quot.sound |
| BudgetAnalysis.scan_preserves_saved・report_warnings・report_stopped | なし |
| BudgetAnalysis.numbering_context・report_after | propext |

## 停止の根拠と取りまとめへの分割案

[共通依頼文](../implementation-request.md)「依頼する内容」は、「開始時の事前点検で収まらないと分かったら、取りまとめが対象・中間の不変条件・後続IDを追記して分割してから依頼し直す」と定める。[plan.md](../plan.md)「前提と依存」も、着手時または最初の30分の点検で再分割する手順を定める。L11d の時間欄は不明であり、点検で明らかになった上記の証明を初回45〜60分の着手枠で閉じる見込みを立てられなかったため、この規定に従って実装前で停止した。L11c の補助定理を中心定理の代わりに扱ったり、未証明の補題を公理にして進めたりしていない。

次の表は取りまとめへの案であり、新しい枝IDや plan.md を確定したものではない。時間はソースの接続範囲からの暫定見積もりであり、証明実装の実測ではない。各枝の最初の短い試行で見直す。

| 順序 | 範囲と次へ渡す条件 | 実装・記録の暫定見込み | 検査・測定・レビュー・受け入れ |
|---|---|---:|---|
| 1 | Analysis の bind・scope・scan・identify・saveWarnings について、成功値と、成功・停止に共通の保存列の性質を合成する。既存の保存列と新しい追加分を区別する。 | 1〜2時間 | 指定 work 三単位。Lean 1〜5分、仕様例・集計は初回不明。独立レビュー・受け入れは取りまとめ担当、時間不明。性能測定は対象外。 |
| 2 | skip 群と実際に解析した部分の完走時の番号消費、途中停止時の接頭辞を示す。L26 の本体命名・全列挙と重複しない境界を固定する。 | 1〜2時間 | 同じ三単位と、定義・言明・仮定の独立レビュー。所要時間は上と同じ。 |
| 3 | 任意の予算での expr・shortCircuit・block・armList の正常値の帰納法を閉じ、入口の NormalSoundness へ接続する。停止時は Top として扱い、完走前提を中心命題へ加えない。 | 1〜2時間 | 同じ三単位、公理依存の照合、独立レビュー。証明修正・受け入れの時間は不明。 |
| 4 | 停止までに追加した警告の範囲・演算・原因を合成し、WarningLocated と WarningSoundness を閉じる。01-12・07-04 の写しを揃え、L11 全体を受け入れる。 | 2〜4時間。必要ならこの枝も最初に分割する | 同じ三単位と旧・新定理の公理依存の照合、定義・言明・仮定の独立レビュー・受け入れ。時間不明。Rust/VM の比較は計画の後続 X に残す。 |

言語の規則、旧主定理、中心命題の前提・結論、公理を変更する必要があるとの反例や証明失敗は得ていない。今回は D15 の定理・公理の停止条件による停止ではなく、作業規模の事前点検による停止である。設計書は証明済みの保証だけを書く規約に従い、01-12・07-04 の保証を広げていない。

## 実行した検査

コマンドはリポジトリの根を基準とする。Lean の一時ファイルだけは formal/ で実行した。原則として rtk proxy を使った。読み取りの外側の時間は未計測であり、個別の実評価は実行ツールの時間、work 本実行は Python の time.monotonic() で計測した。他の状態の検査結果は引用していない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `git status --short`・`git branch --show-current`・`git rev-parse HEAD`（読み取りのみ） | 0。上記の着手状態を確認 | 未計測 |
| AGENTS.md・共通依頼文・plan・decisions・README・preflight・L11/L11b/L11c の記録・study 8.4・現行定義と設計書の読み取り | 0。広い出力の一部は表示上限で切れたため、関係箇所を範囲指定して確認 | 未計測 |
| `lake env lean /tmp/benitoite-l11d-preflight.lean` | 0。同じ深さでの両解析の差と、既存12宣言の公理依存を上記のとおり確認 | 約0.20秒 |
| `scripts/check.sh --level work --base 8803d6801758a65903979048a4ad647cf43e18a4 --only formal_build,spec_examples,spec_tally --dry-run` | 0。spec_tally の自己検査と集計、spec_examples、既定 lake build と未証明の穴の拒否を確認 | 未計測 |
| `scripts/check.sh --level work --base 8803d6801758a65903979048a4ad647cf43e18a4 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功 | 8.325秒 |

spec_tally は参照印のない節を一覧表示した。初回リリース版の未記入の完了条件は none であり、集計は成功した。変更は結果記録だけであり、新しい Lean の定義・定理の検査を成功させたものとは扱わない。最終の読み取りの差分確認と、本記録の相対リンク・フェンス・末尾空白の確認は終了0だった（外側の時間は未計測）。

## 申し送り

L11d・親の L11 の完了条件は満たしていない。指定 work が成功しても、今回追加していない予算付き解析の中心二定理・WarningLocated の証拠にはならない。L12・A11・L27 等へ、任意の予算についての健全性が閉じたとは渡せない。次は取りまとめが証明の範囲・中間の条件・依存・検査を再分割して再依頼する。独立レビュー・受け入れも取りまとめの担当であり、今回済ませたものとして扱わない。
