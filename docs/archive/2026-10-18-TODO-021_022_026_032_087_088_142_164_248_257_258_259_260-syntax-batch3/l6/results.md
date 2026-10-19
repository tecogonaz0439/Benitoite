# L6 実装の区切りの記録

続行L6c2で全体の捕捉禁止を閉じた。現在の完了状態と検査は[続行の結果](../l6c2/results.md)を参照する。以下は前回の区切り時点の記録であり、未完了の記述もその時点を表す。

2026-10-18、Codex。**L6は未完了である。** 文脈の残量により、既定の全体ビルドがsorryなしで通る正式な状態で区切った。基準B_WORKは `d0e4f09b86c0d8170e7c6f2c0f4117bd7609b26b`（L5取り込み後の開始版）で、開始時の作業ツリーはクリーンだった。コミットとdocs/todo/の変更は行っていない。未達の定理を公理や仮定で通した箇所はない。検討中の未ビルド差分は残していない。

## できたこと

- Block.builderBind、B_BuilderBind、congrΔとBuilderFree、Scoped/AtomsIn/Exitsの全読者を接続した。最後の宣言は後続.emptyからUnit/Stateを得る。
- builderInit→Reference.newを内部のletでつなぎ、外側のletから後続へ一つのセルだけを渡す。builderBlock_desugar_typedを、後続のfillBuilders環境での帰納の結論から証明した。clean・scopedと、別入口のBlockSequenceも接続した。
- checkerは通常型のcleanと単一Fail、Stateの支持、種類と参照先を検査する。strict/relaxedの支持保存とstrictの健全性の帰納へ、専用位置を追加した内部四条件を渡す。CheckSoundSequenceとWalkは後続の子0を明示的に扱う。宣言だけで終わる場合も参照先の組み込みを収集する。
- 公開の健全性11件、単一Fail、programのsound/empty/under/contracts、性質1と表層のエフェクト健全性を新構文でビルドした。外側の言明・公開の前提の定義・Releaseの型/効果/ステップ・Builtins.Assumptionsは変えていない。
- BuilderCaptureに、実際のコアの自由参照を束縛数で数えるReadsと、Γのnoneの位置を読めないことの型付けからの証明を置いた。生成箇所の各部分導出のbuilderExprBoundary_no_capture、通常節とFail節の不参照、通常の結果のcleanを証明した。部分適用、辞書付き関数・メソッド・操作の値化、構成子の値化、lambda/lazyを生成箇所の補題で扱う。
- BuilderCaptureAllに、通常の計算のセルの利用を許し、コアのlam/lazyC/節の自由参照を制限するCapturesを定義した。Reads/Capturesのrename、Reads→Captures、shift/shiftUnder、初期化の捕捉なし、**式の捕捉保存を仮定した**HasBlockQ.captures_of_exprを証明した。二ファイルとも正式importに含み、既定ビルドの外へ隠していない。
- BuilderExamplesへ19個のexampleを追加した（従来8個と合わせ27個）。三種類の末尾宣言、lambda/lazy/部分適用のcallee・固定引数・partialCon・通常節・Fail節・return・タスク用関数への引き渡しの拒否、先行copyのlambda/部分適用/partialConへの捕捉、copyの安定性、分岐・複数セル、handle本体と節内の宣言を越える有限のresumeを確かめた。既存の例と期待値は保った。
- 01-12と07-04へ今回定義・証明した範囲を写し、R153へ表現と配置の判断を書いた。L5の「宣言はまだない」という現在では事実に合わない記述を更新したが、L6全体の完了や全体の捕捉定理を証明済みとはしていない。

規則と既定分岐のある照合を含む全読者、共通の関門K、test-auditの四問は[rule-review.md](rule-review.md)に記録した。形式化の定義・証明・入口は追加741行・削除10行、BuilderExamplesは追加116行・削除0行である（新規の証明2ファイルを含む）。Rustの処理系・Rustテストの差分は0行。既存のassert削除・期待値の緩和・ignore追加は0件である。

## 残りと次に続ける手順

**R131の全体のbuilders_no_captureが残る。境界の部分導出の補題だけで完了にしない。** 現在のbuilderExprBoundary_no_captureは生成箇所に限定したReadsの結論であり、任意の式/ブロックのコア全体のCapturesを結論する定理ではない。HasBlockQ.captures_of_exprのpreserve引数もまだ閉じていない。

1. BuilderCaptureAllで、任意のpvとEnvReads pv ΓのもとでHasTypeQの脱糖がComp.Captures pvを満たす相互帰納を閉じる。中核の結論は `Comp.Captures pv (desugarExpr op pos e)`。既存の型保存と同じAligned/Clean・Scoped・EnvClean・戻り値の条件を内部で使う。式の並び・Each/HoleArgs・Armsと全Blockの子も接続する。
2. letChain/sequence/callComp、record/更新、補間、spread、try/die、builderOpの展開についてCapturesの合成補題を追加する。直接の頭やBuilderRefsの値は新しいクロージャを作らない。rename/shift/shiftUnderは実装済みである。生成箇所はclosure_empty→既存型保存→HasTypeCQ.reads→Comp.Reads.capturesを使える。通常節はHasClausesQ.closure_emptyからの既存型保存とReadsを使い、Fail節は二位置のliftReadsを使う。
3. ブロックの全場合の証明はcaptures_of_exprにある。相互帰納でこれを使う際、グローバルな再帰関数を高階引数preserveに渡すだけではLeanが構造的な減少を判定できない可能性がある。既存のHasTypeQ/HasBlockQ.desugarと同様に、子の部分導出への直接の相互帰納として同じ場合を組む方法を採れる。
4. EnvReadsをBuilderCtx.aligned_envReadsで具体化し、実際のコアの全lam/lazyC/節がその場所のΔの外側のセルを参照しないbuilders_no_captureを述べる。局所宣言を加えた先の任意の部分導出にも適用する。公開入口が空Δだから自明になるだけの定理にはしない。
5. 01-12/07-04の捕捉の記述とR153、resultsの未完の記録を実際に閉じた言明へ更新する。新しい捕捉定理も#print axiomsに足す。計画の完了条件を再照合し、変更で古くなった検査だけを実行する。今回のspec_examples/spec_tallyの入力を変えていなければ同じ状態で重ねて実行しない。結果の別状態への引用には07-03の必要欄を補う。

L7の交換版12・独立入力と、後のRust接続へはまだ引き渡さない。主定理の前提/結論変更、保証の縮小、公理/Builtins.Assumptions追加を要する問題には出会っていない。

## 言明・定義と公理

[contracts-comparison.json](contracts-comparison.json)は、公開21言明、Input.Sound・BuilderInvariant・Def/ImplDecl/Program.WellTyped・Program.WellFormedの6定義、旧七判断の規則、checkerの旧処理、Releaseの4ファイル、既存の具体例の保存を開始版と比較した記録である。新しい構文をWellTyped/WellFormedから除外する条件は足していない。

[READMEの全30件の公理依存](axioms.txt)は[開始版に保存されていたL5の出力](axioms-start.txt)とバイト単位で一致した。[入力](axioms.lean)もREADMEのコードブロックの全一覧と一致する。新規・接続した[内部補題15件](internal-axioms.txt)も標準のpropext・Classical.choice・Quot.soundの範囲内で、sorryAx・Lean.ofReduceBool・独自公理はない。[比較の要約](axioms-comparison.json)を保存した。開始版の保存出力は比較対象であり、今回のビルドの代わりに引用していない。

## 検査

区切りを確かめるため、計画指定の三単位を一度実行した。L6の未達の捕捉定理について成功を主張するものではない。完全なコマンド・cwd・終了状態・外側の時間は[check-times.json](check-times.json)にある。

| コマンド（Dは本改造のディレクトリ） | 終了状態 | 外側の時間 | 記録 |
|---|---|---|---|
| `scripts/check.sh --level work --base d0e4f09b86c0d8170e7c6f2c0f4117bd7609b26b --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.011秒 | [work-dry-run.txt](work-dry-run.txt) |
| `scripts/check.sh --level work --base d0e4f09b86c0d8170e7c6f2c0f4117bd7609b26b --only formal_build,spec_examples,spec_tally` | 0 | 60.788秒 | [work.txt](work.txt) |
| `lake env lean <D>/l6/axioms.lean` | 0 | 0.68秒 | [axioms.txt](axioms.txt) |
| `lake env lean <D>/l6/internal-axioms.lean` | 0 | 0.684秒 | [internal-axioms.txt](internal-axioms.txt) |

workのspec_tallyは自己検査と集計に成功し、仕様例は7件成功・失敗0・ignore0、formal_buildは既定の全体lake buildとsorryの検査に成功した。途中は変更に関係するLeanのモジュールのlake buildだけを実行し、外側の時間は集計していない。途中の失敗はkindの等式を除去した後の再帰でLeanが構造的減少を追えなかったこと、初期値のListの型の範囲、支持の和と通常の和の区別、具体例のreturn/束縛位置・宣言の書式、述語の式の展開の不足であり、定理の結論や既存のテストを弱めずに修正した。

Rustは変更していないため全lib・全統合・clippy・fmt・gc-stress・check-formal全体は実行していない。構文の章・標準ソース・診断表は変えていないためgen_skillの再生成は不要である。独立レビューやL6全体の受け入れは未実施である。

## 計画からのずれ

L6の宣言とchecker・全体の既存主定理への接続はできたが、新規の全体の捕捉定理が残るため、本セッションでは完了に至らなかった。R153は初期値の内部let、証明の等式除去の順序、捕捉の補助の配置を具体化したものであり、保証を減らす決定ではない。計画の範囲と停止条件を保ち、次のセッションも同じL6として続ける。
