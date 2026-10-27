# 作業 L11d4 の結果

2026-10-24。**未完了。事前点検で再分割が必要と判断し、実装前で停止した。** 基準 B_WORK と着手時・検査後の HEAD は `2d595e58c2d8bfc83e0816f6137ff666dccfe049`、ブランチは `mod012/L11d4`、着手時の差分はなかった。変更は本記録だけである。private/ とそれを指すスキルのリンクは読まず、git の変更操作は行っていない。他の results.md には追記していない。

## 事前点検で確認した残りの接続

L11d1〜L11d3 の補題と入口は既に実装されている。L11d の停止時に挙がった保存列の合成、番号の消費と接頭辞、正常値の帰納法を、今回もう一度作る必要はない。残っているのは、次の警告の証明である。以下は証明の接続範囲の点検であり、健全性の反例や定理・公理の変更の必要を発見したという報告ではない。

| 現在の箇所 | 利用できる契約と残りの接続 |
|---|---|
| `BudgetProof.lean` の ListExtension・Saved・Spec・spec_bind・spec_scope | 成功・停止とも、既存の保存列と今回の追加分を区別して合成できる。ただし警告の述語は呼び出し側から受け取る。expr・shortCircuit・block・armList が追加した警告について、キーの範囲・構文上の演算・拒否原因を満たす述語を実際に証明する部分が残る。 |
| `BudgetWalk.lean` の skip 群、`BudgetTraversal.lean` の skip_walk・analysis_walk・Walk.identities | 識別対応列と次キーの契約は閉じている。Walk は warningsRev の条件を持たないため、それだけから「番号だけの走査が警告を追加しない」や「警告と対応列の演算が一致する」は導けない。全 skip 群の警告保存の補題と、実際の解析の警告位置の帰納法を接続する必要がある。番号走査の定義や全構成子の分類を変更する必要を見つけたものではない。 |
| `BudgetAnalyze.lean` の own・saveWarnings、`BudgetProof.lean` の saveWarnings_progress・spec_saveWarnings | own が作る候補の位置・演算・原因を示せば、候補保存の途中で停止した場合も、その述語を追加済みの候補へ渡せる。元からある警告に現在の部分木の性質を要求しないこと、own の前後の保存列を区別することが必要である。 |
| `BudgetNormal.lean` の expr_normal・block_normal・armList_normal、`BudgetTraversal.lean` の成功時の番号消費の補題 | 両オペランドの解析に成功した時点での正常値所属と、後続の子を始める正確なキーを得られる。これらを同じ中間 Context に適用して、演算自身の警告原因へ接続する必要がある。Success は停止した実行に条件を課さないため、停止時に残った警告の健全性は別に示す。 |
| `Sound.lean` の Good・Good.append・Good.follow・Good.root、own_add_good・own_div_good | 既存証明は、警告と trace のキー範囲を分離し、子と親、異なる枝・腕の事象を混同しない。これらは private であり、新しい保存列の証明に再利用するなら、言明・証明を変えずに利用範囲を整理するか、同じ性質の補助補題を置く必要がある。base_warning_sound の帰納法は旧解析を対象とするため、新入口にそのまま適用できない。 |
| `BudgetAnalyze.lean` の Parameters・Report.toAnalysisResult・analyze、`BudgetNormal.lean` の analyze_normal_sound | 任意の上限・初期消費・深さについて、正常値の中心命題への接続は済んでいる。新しい警告位置・拒否原因の帰納法をこの同じ入口の WarningLocated・WarningSoundness へ接続する。完走や事前の警告健全性を中心命題の前提に加えない。 |

警告位置は評価導出なしで全ての対象構文について示し、警告原因は Models と具体評価の下で示す必要がある。未実行の枝にも解析が作った警告があり得るため、原因の証明には、その警告の範囲に到達事象がない場合も必要になる。したがって、原因の帰納法から先に位置の証明を省く方針にはしない。

## 既存定義の実評価

一時ファイル `/tmp/benitoite-l11d4-preflight.lean` に、既存定義を呼ぶ二つの `#eval` と後述の公理依存の照合を置いた。リポジトリ内の Lean の定義・証明・独立例は変更していない。

最初の入力は次のとおりである。one・zero はそれぞれ Integer64 のリテラル1・0とする。

```lean
env := AbstractEnv.ofLocals []
key := ⟨"Probe.warningStop", 40⟩
source := Expr.ite (.local 0)
  (.last (.binary .intDiv (.base .integer) one zero))
  (.last (.paren one))
limits := ⟨⟨14, 100⟩, ⟨10000, 10000⟩⟩
output := analyzeExpr limits {} 100 env key source
```

結果は本体の操作数超過で停止し、正常値の整数区間は Top、保存された警告は `(定義名 Probe.warningStop, 番号42, Integer64 の intDiv, zeroDivisor)` の一件だった。次キーは同じ定義名の45、消費操作数は14だった。警告の保存後に別の枝で停止する例であり、成功値だけの性質では、この出力に残った警告まで扱えないことを確認した。既存の BudgetAnalysisExamples の途中停止例と同じ形を、非零の開始番号で評価したものである。

二つ目は、`next = ⟨"Probe.current", 40⟩` の Context に、別の定義の警告 `⟨⟨"Probe.previous", 7⟩, .binary .intDiv (.base .integer), .zeroDivisor⟩` を一件だけ入れ、`expr 0 (AbstractEnv.ofLocals []) .unit {} ctx` を評価した。depth で停止し、その警告一件を保持し、識別対応は0件だった。任意の入力 Context に対する補題では、出力列全体に現在の部分木の性質を要求せず、ListExtension の追加分だけを対象にする必要がある。空の保存列から始める analyze の入口で初めて、出力警告全体の命題へ移す。

これらは、実装にある保存と停止の扱いの確認であり、中心命題に対する反例ではない。同じ深さの旧解析との等式を使う案も採っていない。

## 再分割の案と停止の理由

[共通依頼文](../implementation-request.md)「依頼する内容」は、「開始時の事前点検で収まらないと分かったら、取りまとめが対象・中間の不変条件・後続IDを追記して分割してから依頼し直す」と定める。[plan.md](../plan.md)「計画の変更（2026-10-24、L11d の事前点検を受けて）」の L11d4 欄も「着手時に収まらなければ、この枝も最初に分ける」と定める。

上記の接続には、評価導出に依存しない構文の帰納法と、評価・正常値・キー範囲を合わせる原因の帰納法の両方が残っている。保存列用の合成補題を含む実装・記録の暫定見込みを4〜7時間と判断した。今回の2〜4時間の枝へ全体を収める見通しを立てられなかったため、実装前で停止する。実装時間の測定結果に基づく見積もりではなく、必要な証明の接続範囲からの判断である。

次の表は取りまとめへの案であり、新しい枝IDや plan.md を確定したものではない。先行作業の定理を弱めず、各行で閉じた補題を渡す。原因の中心定理を、部分的に仮定したまま次へ渡す案ではない。

| 順序 | 範囲と次へ渡す条件 | 実装・記録の暫定見込み | 検査・測定・レビュー・受け入れ |
|---|---|---:|---|
| 1 | skip 群が警告を追加しないこと、expr・shortCircuit・block・armList の追加警告が当該部分木のキー範囲と対象演算に対応することを、任意の予算・入力 Context と停止を含めて示す。入口の WarningLocated を閉じる。 | 1〜2時間 | 指定 work 三単位。仕様例・集計と既定 Lean ビルド、未証明の穴の検査は1〜5分程度。定義・言明・仮定の独立レビューと受け入れは取りまとめ担当、時間不明。性能測定は対象外。 |
| 2 | 範囲を分離した警告原因の保存列用の合成補題を置く。子からの追加分と親の own の追加分、実行された部分と空 trace の部分を区別する。加算・除算の局所の原因、branch・腕の選択、成功した中間 Context での正常値と番号消費をつなぐ補題を閉じる。 | 1〜2時間 | 同じ三単位と独立レビュー。検査1〜5分程度、レビュー・受け入れは取りまとめ担当、時間不明。補助補題が子の性質を仮定する場合は、引数として明示する。 |
| 3 | 上の補題を使って、expr・shortCircuit・block・armList の警告原因の相互帰納法を全て閉じ、同じ analyze の WarningSoundness へ接続する。01-12・07-04 の写しを揃え、旧・新の定理の公理依存を照合する。 | 2〜3時間 | 同じ三単位、公理依存の照合、定義・言明・仮定の独立レビューと L11 全体の受け入れ。検査1〜5分程度、公理照合とレビュー・受け入れは時間不明、取りまとめ担当。Rust/VM の比較は後続 X の範囲。 |

番号の証明は L11d2 の Walk・Traversal を再利用する。本体の命名・別本体の全列挙・元 AST との対応は L26 に残す。予算の定義や計上、言語の規則、正常値の中心定理、旧主定理、公理・Builtins.Assumptions を変更する案ではない。

## 実行した検査

コマンドはリポジトリの根を基準とし、lake だけは formal/ で実行した。シェルは原則として rtk proxy を通した。Lean の実評価と指定 work は、Python の time.monotonic() で外側の時間を測った。他の状態の結果は引用していない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| `git status --short`・`git rev-parse HEAD`・`git branch --show-current`（読み取りのみ）、指定文書と現行の定義・設計書の確認 | 0。上記の基準・ブランチと差分なしを確認 | 未計測 |
| `lake env lean /tmp/benitoite-l11d4-preflight.lean`（作成中の反復） | 初回1、最終0。二つの既存定義の実評価と、下表の既存12宣言の公理依存を確認 | 初回0.382秒、最終0.353秒 |
| `scripts/check.sh --level work --base 2d595e58c2d8bfc83e0816f6137ff666dccfe049 --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様集計の自己検査と集計、仕様例、既定 lake build と未証明の穴の拒否を選択 | 0.010秒 |
| `scripts/check.sh --level work --base 2d595e58c2d8bfc83e0816f6137ff666dccfe049 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功。本実行は一度だけ | 8.249秒 |
| `git diff --check`、結果記録の相対リンク・フェンス・末尾空白と最終 HEAD・変更範囲の確認 | 0。差分は本記録の新設だけ、HEAD は基準と同じ | 未計測 |

一時ファイルの初回は、Expr の型注釈がない構成子表記と、表示する組の型推論で失敗した。型注釈を補った後、TargetOperation の表示用インスタンスがなく失敗したため、演算と原因の一致を Bool へ射影して表示する形にした。この射影の等式表記でも推論に失敗したため、対象演算の構成子を match する形へ直した。その後は終了0だった。処理系・解析・証明・検査の期待値を修正したものではない。

spec_tally は参照印のない節を一覧表示したが、初回リリース版の未記入の完了条件は none であり、集計は成功した。指定 work は現在の状態を検査したものであり、今回追加していない警告中心定理・WarningLocated を検証したとは扱わない。段・改造・公開候補の全件検査と Rust/Lean の全比較は先取りしていない。

## 公理依存と申し送り

一時ファイルは BudgetNormal・Release.Theorems・Surface.Theorems を import し、次の既存12宣言に `#print axioms` を実行した。

| 対象 | 公理依存 |
|---|---|
| BudgetAnalysis.analyze_normal_sound、Interval.analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located | propext・Classical.choice・Quot.sound |
| Release.progress・preservation・effect_soundness、Surface.desugar_typed | propext・Classical.choice・Quot.sound |
| BudgetAnalysis.spec_bind | propext |
| BudgetAnalysis.spec_scope・spec_saveWarnings・expr_prefix | propext・Classical.choice・Quot.sound |

今回、新しい定義・定理は追加しておらず、任意の予算での警告中心定理・WarningLocated の公理依存を照合済みとはしない。01-12・07-04 は現在の保証と一致しているため変更していない。L11d4 と親の L11 は未完了であり、L12・A11・L27 等へ任意の予算での中心二定理と WarningLocated が閉じたとは渡せない。

次は取りまとめが分割の範囲・中間の不変条件・依存・検査を plan.md に確定して再依頼する。独立レビュー・受け入れも取りまとめの担当であり、今回済ませたものとは扱わない。
