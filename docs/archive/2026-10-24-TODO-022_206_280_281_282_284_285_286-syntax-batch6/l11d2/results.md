# 作業 L11d2 の結果

2026-10-24。L11d2 の実装と指定 work を完了した。独立レビュー・受け入れは取りまとめの担当であり、本記録で完了とはしない。基準 B_WORK と着手時の HEAD は `35b6ae4a4a169caaaba5306841a3c78ba72e1511`、ブランチは `mod012/L11d2`、着手時の差分はなかった。private/ とそこを指すスキルのリンクは読まず、git の変更操作は行っていない。他の results.md には追記していない。

## 変更と後続へ渡す契約

`formal/Benitoite/Interval/BudgetTraversal.lean` を新設し、既定の `formal/Benitoite.lean` へ import を加えた。証明用の関数 numberFrom、命題 Traversal・Walk と33補題を定めた。実行する解析・予算・識別規則の定義は変更していない。BudgetWalk.lean は、証明の対象範囲を説明する先頭コメントだけを更新した。01-12「区間解析の予算付きの式とフロー」と 07-04「01-12 との対応」に、今回閉じた定義と言明を写した。

- Traversal は、対象列を visited ++ rest に分け、出力の対応列 = reverse (numberFrom 入力の次キー visited) ++ 入力の対応列、出力の次キー = advanceKey 入力の次キー visited.length とする。成功した場合だけ rest = [] を要求する。入力からある対応列が現在の部分木の要素であるとは要求しない。
- Walk は、任意の上限・初期 Context に対する Traversal である。walk_bind は成功した前半だけ全長を使って後半を接続し、前半で停止したら後半を未訪問として残す。scope の枠の確保・返却、numbering の停止分類、scan・identify・警告保存・own・branch にも同じ契約を接続した。
- skip_walk は、skipExpr・skipChildren・skipExprs・skipHoles・skipBlock・skipArms・skipClauses・skipOptional の八つについて、任意の深さの Walk を同時に示す。全53構成子と相互帰納の容器を対象にする。analysis_walk は、expr・shortCircuit・block・armList について同じ契約を示す。値を解析する部分と skip する部分の先行順を共通にした。
- numberFrom_zipIdx・numberFrom_numbered は、証明用の再帰列と既存の番号付けの一致を示す。Walk.success と各入口の `_success` は、完走時の消費が surfaceSize・blockSize・armsSize、または短絡の左右の surfaceSize の和であることと、全対応列の保存を示す。
- Traversal.prefix と expr_prefix・skipExpr_prefix は、途中停止でも追加分が全番号列の接頭辞であることと、次キーがその長さだけ進むことを示す。停止は、最後の識別後の式の計上や警告保存でも起こるため、停止から真の接頭辞であるとは結論しない。Walk.identities により、成否によらない追加分の所属を L11d1 の ListExtension と接続できる。

numberFrom・先行順の平坦な列は証明用であり、実行する解析に無制限の事前走査を加えていない。同じ深さの旧解析との等式を仮定せず、予算付きの各定義について深さの帰納法で証明した。

## L26 と後続の枝との境界

今回の入力は、既に根のキーを与えられた一つの Surface の式または容器である。この入力内で、解析した部分と skip した部分が既存の surfacePreorder・numbered に従うことを示した。

L26 には、モジュール付き定義名・境界ごとの本体名、本体の根を .block で包むかとそのキー、別本体の番号の起点と親の先行順との対応、別本体の有界の全列挙、元 AST の NodeId/span・合成節点との対応を残す。今回の部分木の走査の補題を、本体の発見・命名や元 AST との対応まで示したものとして扱わない。

正常値の中心定理への接続は L11d3、警告の健全性と WarningLocated は L11d4 に残す。今回の `_success` の完走前提は番号消費の補題だけのものであり、正常値・警告の中心命題へ前提を加えるものではない。親の L11 は未完了である。Rust/VM との比較も今回の対象外である。

## 独立例と作成時の関門

test-audit の作成時の関門を通し、既存の BudgetAnalysisExamples.lean に比較例を一つ追加した。非零の開始番号20と別定義の既存対応一件から、解析と skip の完走、同じ操作上限8での途中停止を比べる。短絡で飛ばす match の guard・const 本体も番号を使い、後続の除算の警告は29、完走後の次番号は32となる。途中停止では、解析は24、skip は26を次番号とし、いずれも既存の接尾辞を残す。

守る契約は、キーの定義名・番号・構文の順序、既存の対応の保持、後続の警告の番号、停止時の未取得の分類である。未到達の guard や埋込み本体を飛ばす、番号を詰める、追加順を逆転する、保存列を消す退行で失敗する。既存例には、解析・skip の完全な対応列を非零の開始番号と非空の既存列から比べるものがなかった。実際の入口を使い、テスト用の公開範囲・差し込み口を追加していない。期待値は固定した番号・構文名の列であり、surfacePreorder・numbered・numberFrom から生成していない。既存のテストは削除・緩和していない。実行する解析のコードの増減は0行、証明用の新ファイルは546行、既定 import は1行、独立例は42行増加した。

## 実行した検査

コマンドはリポジトリの根を基準とする。lake だけは formal/ で実行した。シェルは原則として rtk proxy を通した。dry-run・work と公理依存の照合は Python の time.monotonic() で外側を測った。局所の Lean の時間は実行ツールによる概数である。他の状態の結果は引用していない。

| コマンド・対象 | 終了状態・結果 | 外側の時間 |
|---|---|---:|
| 着手時の git status・HEAD・ブランチの読み取り、指定文書と現行の定義・設計書の確認 | 0。指定の基準と差分なしを確認 | 未計測 |
| `lake env lean Benitoite/Interval/BudgetTraversal.lean`（証明作成中の反復） | 最終0。新しい定義・補題を未証明の穴なしで確認 | 最終約2.2秒 |
| `lake env lean /tmp/benitoite-l11d2-probe.lean`（局所例の入力の確認） | 最終0。完走と途中停止の位置を実評価。番号の期待値は構文順から固定 | 最終約0.23秒 |
| `lake env lean Benitoite/Interval/BudgetAnalysisExamples.lean` | 0。追加した比較例を含め成功 | 約0.5秒 |
| `lake env lean /tmp/benitoite-l11d2-axioms.lean`（新規36宣言と既存7定理の公理依存） | 0。下表の範囲を確認 | 2.180秒 |
| `scripts/check.sh --level work --base 35b6ae4a4a169caaaba5306841a3c78ba72e1511 --only formal_build,spec_examples,spec_tally --dry-run` | 0。仕様集計の自己検査と集計、仕様例、既定 lake build と未証明の穴の拒否を選択 | 0.010秒 |
| `scripts/check.sh --level work --base 35b6ae4a4a169caaaba5306841a3c78ba72e1511 --only formal_build,spec_examples,spec_tally` | 0。仕様集計の自己検査と集計、仕様例7件、既定 lake build と未証明の穴の拒否が成功。一度だけ実行 | 12.316秒 |
| `git diff --check` と変更・未追跡の7ファイルの末尾空白・Markdown フェンス・新証明の穴の確認、最終 HEAD の照合 | 0。書式と対象範囲を確認。HEAD は基準のまま | 未計測 |

証明作成中の局所コンパイルは、モナドの展開、レコード射影の簡約、列連結の結合順、相互再帰の式の展開で失敗した。guard の場合分けを遅らせた版では、展開した腕列の項に対してカーネルの型不一致も出たため、guard の場合分けを先に行う証明へ直した。証明の探索順による既定 heartbeat の超過は、未対応の場合を先に処理することで解消した。最終版は heartbeat の上限を変更していない。言明の前提・結論を緩めず、公理を追加せずに解消した。局所の一時ファイルは、レコードの改行・型推論・存在しないフィールドの参照を直して最終0にした。追加例と指定 work の本実行に失敗はない。

spec_tally は参照印のない節を一覧表示したが、初回リリース版の未記入の完了条件は none であり、集計は成功した。段・改造・候補の全件検査や Rust/Lean の全比較は先取りしていない。

## 公理依存・計画からのずれ・申し送り

新規宣言の名前空間は Benitoite.Interval.BudgetAnalysis である。再実行する場合は、新ファイルの内容を Release.Theorems・Surface.Theorems の import とともに一時ファイルへ写し、新規36宣言と下表の既存7定理に `#print axioms` を実行する。

| 対象 | 公理依存 |
|---|---|
| numberFrom・Traversal・Walk、advanceKey_zero・traversal_empty・walk_pure・walk_throw・walk_scan・walk_unsupported・numberFrom_zipIdx・numberFrom_numbered | なし |
| advanceKey_add・numberFrom_append・walk_bind・walk_numbering・walk_map・walk_bind_empty・numberFrom_length・Traversal.prefix・Walk.success・Walk.identities | propext |
| preorderBlock_length | propext・Quot.sound |
| walk_scope・walk_identify・walk_saveWarnings・walk_own・walk_branch・skip_walk・analysis_walk、skipExpr_success・expr_success・block_success・armList_success・shortCircuit_success・expr_prefix・skipExpr_prefix | propext・Classical.choice・Quot.sound |
| Interval.analyzeBase_normal_sound・analyzeBase_warning_sound・analyzeBase_warning_located | propext・Classical.choice・Quot.sound |
| Release.progress・preservation・effect_soundness、Surface.desugar_typed | propext・Classical.choice・Quot.sound |

旧主定理・中心命題の前提と結論、言語の規則、公理・Builtins.Assumptions は変更していない。停止条件に当たる反例や変更の必要はなかった。範囲のずれはなく、番号走査の証明を新しい BudgetTraversal.lean にまとめた。検査表に L11d2 行がない点は、依頼の補足で指定された三単位を使った。

次は取りまとめが定義・言明・仮定を独立レビューし、受け入れ後に L11d3 へ渡す。L11d3 は analysis_walk の各射影、各入口の success、成否に共通の prefix と Walk.identities を使える。独立レビューと受け入れは取りまとめ担当、時間不明である。
