# L6 の実装結果

検査済みListの独立小モデルとLogの適用例を実装した。既定のlake buildはsorryなしで成功した。主定理・Builtins.Assumptions・既存のモデルを変更せず、コミットとdocs/todo/の変更は行っていない。

## 基準と変更

B_WORKは `8a188ddc63ba5c1b772a65185822701ca9be5007`（開始時の `git merge-base HEAD san_benito`）。開始時の未コミット差分はなかった。

- `Checked/ListLength.lean`: 数学上のList/Intによる長さの検査。成功と四つの不等式の同値、invalidBounds・outOfRangeそれぞれの失敗の同値、端点の失敗の優先順、minimum/maximum/実長/対象の保存を証明した。
- `Checked/ListIndex.lean`: 添字の成功・失敗の同値、添字と対象の保存、保存した要素と元のListのその位置の一致を証明した。負数を自然数へ変換する前にIntの範囲条件を検査する。二つの失敗型はIntだけを保持し、Listを含まない。
- `Checked/NonEmptyList.lean`: head/tailを保持し、成功と非空・失敗と空の同値、fromList/toListの両方向、head/tailの射影、純粋なmapとList.mapの一致を証明した。
- `Surface/LogExamples.lean`: Level/Value/Attribute/Record/Locationの通常宣言と、emit/enabled・Console出力の有限の組み込み表を作った。既存の公開checkExprで両操作、完全なハンドラ、両操作の送り直し、不完全なハンドラでのLogの残存、処理後のConsole.Writeの残存を検査した。公開checkDefで純粋な宣言の拒否、checkProgramで通常関数5件の成功も確認した。位置は展開済みのレコードとリテラルであり、新しい原始操作や効果消去規則はない。
- `Benitoite.lean`・`formal/README.md`・01-12・07-04: 四モジュールを既定importへ追加し、定義・保証の写しと対応表、公理確認23件を反映した。構文の章01-02・診断表・標準ソースは変更しておらず、生成Skillの更新は不要である。

## 検査

途中は次の新規ファイルだけを `formal/` で `lake env lean <ファイル>` に渡した。既存の広い検査は重ねていない。

- `Benitoite/Checked/ListLength.lean`
- `Benitoite/Checked/ListIndex.lean`
- `Benitoite/Checked/NonEmptyList.lean`
- `Benitoite/Surface/LogExamples.lean`

途中の失敗は、負の下端の分岐の算術証明、非空の証明、Leanの予約語を使った補助名、Defの構造体の記法を直して解消した。Logの5関数の全検査は既定の200000 heartbeatsで打ち切られたため、その定理だけ上限を800000にした。証明はrflのままで、入力と期待結果を変えていない。途中の試行の全ログと外側時間は保存していない。

作業末は同じ基準と指定でdry-runを確認した後、次を一度実行した。

```sh
scripts/check.sh --level work --base 8a188ddc63ba5c1b772a65185822701ca9be5007 --only formal_build,spec_examples,spec_tally
```

| 検査 | 終了状態・結果 | 外側時間 |
|---|---|---|
| 上記のdry-run | 0。指定した三単位だけを選択 | 0.010秒 |
| 上記の実検査 | 0。spec_tallyの自己検査と集計、spec_examplesの7件、既定lake buildとsorry拒否が成功 | 14.084秒 |
| 開始時の既存公理一覧 | 0。READMEの既存246件を保存 | 0.649秒 |
| 作業末の既存・追加公理一覧 | 0。既存246件は開始時と完全一致。L1開始前の40件とも一致。追加23件を含む269件が標準三公理の範囲 | 1.098秒 |
| ソース確認 | 主定理・Assumptions・モデル・公開checker等8ファイルが基準と同一。Lean 202ファイルにsorry/sorryAx・axiom宣言なし。既存importの除去なし、git diff --checkは0 | 0.193秒 |

dry-runの正確な時間と出力は[dry-run-timing.json](dry-run-timing.json)・[dry-run.log](dry-run.log)、実検査は[work-timing.json](work-timing.json)・[work.log](work.log)にある。公理確認のimportと名前は[baseline-axioms.lean](baseline-axioms.lean)・[axioms.lean](axioms.lean)、出力は[baseline-axioms.log](baseline-axioms.log)・[axioms.log](axioms.log)、比較は[axioms-comparison.json](axioms-comparison.json)に保存した。コマンド・作業ディレクトリ・時間は同名の `*-timing.json` にある。作業末は保存した入力を `/private/tmp/batch4-axioms.lean` に写し、`formal/` で `lake env lean /private/tmp/batch4-axioms.lean` を実行した。L1開始前の比較元は `l1/axioms-before.txt` である。

最初の公理一覧の抽出ではREADME内の `open Benitoite.Core` を取り込まず、先頭5件の名前が未解決となった。保存した入力の5件を完全修飾名へ直して開始時の確認を通した。定理・import・公理は変更していない。標準三公理はpropext・Classical.choice・Quot.soundであり、新しい公理や仮定はない。

ソース確認の詳細は[source-audit.json](source-audit.json)にある。今回の状態で実行した結果であり、別状態の成功を引用していない。Rustを変更していないため全lib・clippy・fmtは追加せず、gc-stress・all-targets・check-formal.sh全体・stage/change/releaseは実行していない。

## 計画との差とテストの関門

計画からのずれはない。補助の表現の具体化だけで実装でき、decisions.mdへの新しいR項目を要する不一致はなかった。

test-auditの作成時の関門: 既存のChecked.Rangeは単一のIntを対象とし、Listの保存・添字・非空の契約を扱わないため、三つの小モデルの公開の作成・読み出しを境界に一般の成功／失敗の同値を証明した。Logの既存例もなく、部分的な操作の処理で効果を消す退行、節の送り直しや出力の効果を失う退行は、公開checkerの厳密な結果で検出する。宣言表は実際の型・フィールドを持ち、内部のcheckerを代用していない。既存のassert・期待値・exampleは変更せず、テスト専用の本体APIも加えていない。深い再帰・大きなListの入力は追加していない。

Rust本体・テストの行数の増減は0。Leanの小モデルは166行、既定importは4行、Logの例は141行を追加し、既存のLeanの定義・証明・例の削除は0行である。

## 後の作業への申し送り

- L7はLogExamplesの標準型と二操作・Console出力の材料、展開済みLocation、完全な処理・送り直し・外側効果の例を交換13/5の独立入力へ対応させる。この例だけで交換やRustとの全比較を完了したとは扱わない。
- G1/G2は通常コード・名前解決・位置の展開・標準ソース・出力へ接続する。有限のLogの例は既存checkerへの適用例であり、実出力や標準ソースの全実装の証明ではない。
- G3は保存欄・失敗の優先順・公開境界と独立期待値を照合する。長さと添字のIntegerでの表現可能性をMAX_LIST_LENと対応付け、通常Listと要素の共有、効果を持つmapの順序・一回性・失敗の伝播も確認する。小モデルのmapはLeanの純粋な関数だけを対象とする。
- 主定理の前提・結論、Builtins.Assumptionsと通常State/Fail/Log/IO・リソース解放の規則は維持している。既定ビルドと既存・追加の公理の記録をRV2へ渡せる。
