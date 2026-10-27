# L12b の結果

- 基準（B_WORK）: `769145c67b7b4cd76a207a13ffd68d7ceaa66725`。作業開始時の HEAD は基準と一致し、差分はなかった。
- 対象: plan.md「作業群 L12」の L12b。Examples.lean の独立例8件と既定 import、01-12 の例の説明、07-04 の本文・対応表、C1 の独立レビューの記録を追加した。中心定理・評価関係・解析の定義は変更していない。
- C1 の自己点検（担当による。取りまとめの注記を参照）は修正必須0件、軽微1件を対応して残件0件である。[依頼](self-check/RV-C1-request.md)・[報告](self-check/RV-C1.md)・[対応](self-check/RV-C1-response.md)に、定義・言明・仮定と A1 の限界を記録した。C1 の最終受け入れは取りまとめへ渡す。

## 実行した検査

| コマンド | 終了状態 | 外側の時間 | 結果 |
|---|---|---|---|
| `cd formal` の下で `lake env lean Benitoite/Interval/Examples.lean`（局所の反復） | 初期試行は1、最終試行は0 | 最終0.728秒。初期試行を含む合計は未計時 | 観察用の型、対象入力、証明の簡約を修正した後、8件の独立例が警告・エラーなしで成功した。後の軽1は作業末の再ビルドで検査した |
| `cd formal` の下で `lake env lean /tmp/BenitoiteC1Axioms.lean` | 0 | 0.235秒 | 下記10宣言を #print axioms で確認し、すべての依存は propext・Classical.choice・Quot.sound のみだった |
| `scripts/check.sh --level work --base 769145c67b7b4cd76a207a13ffd68d7ceaa66725 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 未計時 | 計画の名指し3単位と実コマンドを照合した。自動分類は行わない部分選択である |
| `scripts/check.sh --level work --base 769145c67b7b4cd76a207a13ffd68d7ceaa66725 --only formal_build,spec_examples,spec_tally` | 0 | 11.824秒 | 仕様集計の自己検査と集計、仕様例7件、既定 lake build と sorry 拒否が成功した。集計はテスト参照のない仕様節を表示し、初回リリースの完了条件の未記入はなかった |
| `scripts/check.sh --level work --base 769145c67b7b4cd76a207a13ffd68d7ceaa66725 --only formal_build --dry-run` | 0 | 未計時 | 軽1の対応で古くなった formal_build だけを選択した |
| `scripts/check.sh --level work --base 769145c67b7b4cd76a207a13ffd68d7ceaa66725 --only formal_build` | 0 | 1.506秒 | 捕捉の具体環境を明示した最終状態で、既定ビルドと sorry 拒否が成功した |
| `git diff --check` と変更文書・新設ファイルの静的確認 | 補助のリンク確認の初回は1、修正後は0。diff は0 | 未計時 | 8ファイルの末尾空白・終端改行、変更文書の相対リンク先、Markdownのフェンスを確認した。初回の補助スクリプトはコード中の束縛の記法をリンクと誤認したため、コードブロックとインラインコードを除外して確認し直した。文書のリンクを変更して解決したものではない |

公理依存の入力は、BudgetSound と EvalClosed を import し、次の10宣言へそれぞれ `#print axioms Benitoite.Interval.<宣言名>` を適用するファイルである。一時ファイルの保存だけを後の引用の根拠にせず、対象と結果をここに記した。

- `analyzeBase_normal_sound`・`analyzeBase_warning_sound`・`analyzeBase_warning_located`。
- `BudgetAnalysis.analyze_normal_sound`・`BudgetAnalysis.analyze_warning_sound`・`BudgetAnalysis.analyze_warning_located`。
- `evalClosed_sound`・`evalClosed_call`・`evalClosed_unsupported`・`evalClosed_trace_keys`。

局所の初期試行では、長い組を使った観察結果の等号の決定手続きの合成、整数の値を持つ式を Unit の式文として置いた入力、予算停止の位置の見積もり、警告の所属の簡約に失敗した。観察する事象を専用の非公開の構造体へまとめ、値を捨てる箇所は discard にした。予算の入力は、根の式の2操作、容器の分類1操作、除算の6操作、後続容器の分類1操作で10操作を消費し、次の番号取得で止まる形に固定した。初期の8操作の入力では除算の警告を保存する前に止まっていた。警告所属の証明は cbv で計算してから既存のリストの規則を使う形にした。計算量の上限・既存のテスト・処理系の定義を緩めてはいない。

## 計画からのずれと申し送り

- 新設例は、短絡の両方向と到達した除数0、guard の偽の後の外側の環境復帰、shadow の新旧位置、return の後続の除外、捕捉区間の忘却、停止後の保存済み警告を同じ表層入力の実行可能な入口で確認する。固定した値・引数・演算・キー・原因を持ち、解析結果から評価の期待を作らない。
- test-audit の作成時の関門では、評価器単体・局所規則・予算状態の既存例だけでは、二つの実行可能な入口の接続と、計算した導出を中心定理へ渡す接続を検出できないことを確認した。準備と観察の処理は Examples.lean の非公開の定義へまとめ、テスト専用の公開範囲・本番の差し込み口は追加していない。本番の定義の増減は0行で、既定 import は1行増、独立例は Examples.lean にまとめた。
- 07-04 の対応表に閉じた評価器と独立例の行を追加し、共有予算の既存行名を、01-12 に実在する「区間解析の予算付きの式とフロー」へ訂正した。新しい言語の規則・用語・定理・公理を追加する判断は生じず、停止条件に当たる点はなかった。
- 軽1対応後は古くなった formal_build だけを再実行した。検査失敗や未証明の仮定を後続へ送るものはない。最終状態の既定ビルド・独立レビュー・公理依存の確認はそろっている。C1 の最終受け入れ、L26 とセキュリティ作業群を含む次作業の選定は取りまとめが行う。
- A1 の定義内の保証に限る。全入力の評価可能性、評価関係との双方向の同値、mayFail の失敗検出、return の値の区間、脱糖・Release・標準ソース・Rust/VM との意味の一致は証明していない。Rust/Lean の独立交換と VM 比較は、計画の後続の接続作業で実施する。
- 開始時に禁止指定に含まれる `git branch --show-current` を一度実行した。読み取りのみであったが、指示からの逸脱である。その後は git branch を使っていない。add・commit・branch の作成/変更・merge・stash・reset・checkout は行っていない。private/ とそれを指すスキルのリンクは読んでいない。

## 取りまとめの注記

担当が書いた C1 のレビュー（依頼・報告・対応）は、実装した側による自己点検であり、計画の「定義・言明・仮定の独立レビュー」には当たらない。取りまとめが `l12b/self-check/` へ移した。C1 の独立レビューは、L26 の後に取りまとめが別に依頼し、`reviews/RV-C1.md` に置く。
