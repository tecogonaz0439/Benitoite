# L2a: Failの規則と言明の文書レビュー

基準Bと開始時HEADは `3f599141daee721d3a44cdee3163de2e2da71b05`（L1d取り込み済み）である。開始時の作業ツリーに差分はなかった。AGENTS.md、planの共通条件と関門K、designの249と段2、decisionsのR7/R14/R17/R21/R24・R36〜R45、L1b/cの完了記録とL1dの結果を確認した。文章にはjapanese-tech-writing、シェル操作にはrtkを使用した。

## 変更と判断

- [statements.md](statements.md)を新設し、L0のL2の下書きを現在のTy/EffR・再帰的なWF・正規化する代入・有限支持の検査へ合わせた。署名全体のQsig、最外のNoFail、Admissibleと部分的な代入のRowTransport、七判断の型・値の代入の全言明、Fail操作・一つの型束縛・C_Handle_Fail/K_Handle_Fail、K1の伝播とE′=E・v:E、CellOk・drop・有限遷移の四例をコード片で具体化した。既存の主な三性質・性質1・健全性11件とプログラム全体の言明も載せた。
- [decisions.mdのR46〜R50](../decisions.md#r46-l2aのqを判断の添字に置く案)に比較と選択を追記した。Qは判断の添字、閉じた入口は空Qの別名とする。Fail節はTだけを束縛・代入し、継続用0番はnoneにする。保存継続の効果は `norm (Rest ∪ ec)` とし、RestのStateも既存のK_Dropへ渡す。
- [plan.md](../plan.md#作業l2b-releaseの失敗捕捉保存と進行)でL2bを360〜720分、L2cを240〜480分へ見直し、内訳と段2・全体の計画上の合計を更新した。検査・独立レビュー待ちは別であり、既に行ったL1の実績をこの見積もりへ置き換えていない。L2aの対象欄にも、依頼済みの判断の記録と再見積もりの更新を明記した。

正式なformal/・処理系・テスト・現行設計の写し・docs/todo/は変更していない。コミットは作成していない。L0の文書と先行作業の記録も変更していない。

## 定義・全言明・仮定の自己点検

| 論点 | 確認した契約 |
|---|---|
| Qの由来と置き場所 | Qsigは型の全構成子と各usesを読む。本体から増やさず、メソッドはクラスの元の署名を使う。表から引く案と判断の添字の案を比較した |
| 代入の範囲 | 全具体化のAdmissibleに対象効果の全行の範囲を含める。型だけの部分的な置換にはrowImageの残存を明示したRowTransportを使い、全具体化の範囲検査は省かない |
| Fail節の束縛と実行 | Eは外側で固定、rigidなTだけ一つを束縛・代入する。値環境はnone・error・外側の順。探索はOpRef.failだけで行い、E/E′を比べない |
| 捕捉安全 | K1の伝播とK_Handle_Failの穴の上限・NoFail・Canonicalから生のE′=Eとv:Eを導く言明とした。Eの一致・捕捉安全・Releaseの単一Failは前提にしない |
| 保存継続とストア | 末尾のK_Handle_Failとその下のK_Empty、Ψ κのT/t/cap/Rh、CellOkのR/ein、既存のK_Dropへ渡すStateの包含を明示した |
| 主な定理 | 閉じた入口の前提と結論を保つ。型付けとWellTypedの内部へQを接続し、公理・Builtins.Assumptionsの欄・未検査の捕捉安全を追加しない |
| Surfaceと検査器 | 単一Failは具体化後の表層で直接検査する。内部版から従来の公開する健全性11件と元のプログラム全体へつなぎ、外側の前提を増やさない。Legacyの拒否を再導入しない |

この点検は文書の契約の確認であり、新しい規則の証明を終えたという意味ではない。RV2のL2a後の独立レビューは本作業では実施していない。オーケストレータがこの文書をレビューへ回し、定義・全言明・仮定を確認してからL2bへ進む。

## 検査と結果

外側の時間は `/usr/bin/time -p` のrealである。特記以外はリポジトリの根で実行した。完了検査は同じ基準のdry-runを確認してから一度だけ実行した。

| コマンド・対象 | 終了状態 | 外側の時間 | 結果 |
|---|---:|---:|---|
| formal/で `rtk proxy lake env lean /private/tmp/benitoite-l2a-statements.lean` | 0 | 0.64秒 | [出力](statements-elaboration.log)。既存モデルだけで表せる五ブロックの型を確認。証明は行わない |
| `scripts/check.sh --level work --base 3f599141daee721d3a44cdee3163de2e2da71b05 --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.02秒 | [選択](work-dry-run.log)。計画の三単位だけを名指しで選択 |
| 同じ指定から `--dry-run` を外して実行 | 0 | 7.88秒 | [出力](work.log)。仕様集計の自己検査と集計、仕様例7件、sorryを拒む未変更の既定のlake buildが成功 |

最初の局所の確認はstatements.mdから、NoFailCtxで始まるQの定義、RowTransportで始まる代入条件とGoal、ProgressGoalで始まる主な三性質、末尾の二つのnamespaceの計五つのLeanブロックを抽出した。`import Benitoite` と `noncomputable section` の後、最初の三ブロックを専用のnamespaceに入れ、末尾の二ブロックを元のnamespaceで型検査した。新しいHasTypeCQやFailの構成子に依存する片は含めていない。既存の公開する13言明をGoalへ写した際の、名前付きの前提を参照していないという警告が74件ある。エラーは0件であり、前提を消して警告を抑える変更はしていない。この確認を新しい捕捉規則の証明の代わりにしない。

完了検査後は文書内の既存の値置換の言明を全七判断分へ展開しただけであり、検査済みの正式な入力と上の五ブロックは変えていない。成功済みの三単位を繰り返していない。Rustのソースを変えていないため、全lib・clippy・fmt・関連統合の追加実行、gc-stress・all-targets・check-formal.sh全体は行っていない。既存のassertの削除、期待値の緩和、ignoreはない。

変更したMarkdown四ファイルのローカルリンク90件は見出しまで成功し、新規文書を含む末尾の空白・最終改行と `git diff --check` も成功した。これらの軽い確認の時間は計測していない。計画の編集用の一時Pythonは標準入力の文字コードのエラーで書き込み前に終了したため、同じ変更をapply_patchで適用した。検査の失敗ではなく、正式なソースへの影響はない。

## 計画との差と後続への申し送り

計画がL2aで選ぶとした点をR46〜R50で具体化し、依頼どおりL2b/cの見積もりを改めた。範囲を超える仕様変更、主な定理の前提・結論の変更、新しい公理やBuiltins.Assumptionsの追加、既存の結論の弱化は行っていない。L2aの文書作業と指定の完了検査は完了した。

L2bでは独立レビュー後、Qと新構成子を七判断の補助へ接続し、K1・捕捉・保存継続・解放・主な三性質を定義と証明の同じ変更で取り込む。L2cはその後、Qの計算と具体化後の単一Failをstrict/relaxed・支持保存・最小効果へ接続し、従来の健全性11件・元の入力のcheckProgram_sound/empty・脱糖の結論を維持する。新しい言明の証明はL2b/cの担当であり、今回の未変更の正式モデルのビルドから引用しない。
