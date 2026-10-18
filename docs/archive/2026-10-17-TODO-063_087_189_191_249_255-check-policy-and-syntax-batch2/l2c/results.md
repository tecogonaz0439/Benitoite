# L2cの実装結果

## 基準と範囲

開始版Bは `0c6673533a8d358ce1aab5d29f64de9c4ac1bbab`。開始時の作業ツリーに差分はなかった。L2b後のSurfaceのFail節・単一Fail・最小効果・正負例を実装する。コミットとdocs/todoの変更は行わない。

## 例を加える前のtest-audit

1. 守る契約は、実際のSurface検査の入口におけるFailの捕捉・非再開・E固定とrigidなT、具体化後の単一Fail、署名だけから計算するQ、残りの効果と再raiseの保持である。
2. 通常節としてのFailの受理、noneの継続の再開、異なるFailを渡す二行の具体化、型内部の走査漏れ、残りの通常エフェクトや節のFailの消失を捕まえる。
3. 既存のL2bの例はReleaseの有限遷移を扱い、既存のNoFailCheckExamplesは行の像の判定を直接扱う。表層の新構文から公開のcheckExpr/checkDefを通す例が必要である。既存の準備は維持し、独立の新構文の表に正負の対照をまとめる。
4. 本物の検査器と脱糖の入口を使い、テストのための本番のフラグ・公開の拡大・大域の状態は加えない。

## 実装時の判断

専用の表層の非再開節、型付け後の結果型の注釈、最小効果の計算と新交換形式への引き継ぎはdecisions.mdのR60に記す。主な定理の外側の前提・結論、公理、Builtins.Assumptionsは変更しない。

## 変更した内容

- `Surface/Syntax`・`Typing`・`WellFormed`・`Desugar`にraiseと専用のFail捕捉を追加した。0番の継続を利用不能にし、Eの固定とT一つの束縛を保つ。残りの効果と節の効果を合流し、節の再raiseを除去しない。
- `SingleFail.lean`・`SingleFailCheck.lean`に、型の内部までの単一Failと計算用の判定、その一致の証明を置いた。具体化した値・呼び出し・部分適用・分岐の型付けへ前提を加え、strict/relaxedの結果・期待型・型の結び・許容効果でも検査する。関数とメソッドの最後の受け入れには、署名から得た同じQを渡す。
- `Lemmas/Invariants`・`Scoped`・`Typing`と検査器の支持保存・健全性の証明を更新した。既存の健全性11件、元のプログラム全体の健全性、脱糖の型保存の外側の言明を保つ。公開入口の成功からSingleTyとSingleEffも導く二つの補題を加えた。
- `Surface/FailureExamples.lean`に公開入口を通す30例を加え、既定のビルドへ含めた。既存の例の期待する型・効果・拒否条件は変えず、新しい前提の証明と新構成子の場合を補った。assertの削除・期待値の緩和・ignoreの追加はない。
- 01-12と07-04へ、Leanの表層の規則・判定と証明・未接続の境界を反映した。

## 検査

途中は関係するLeanモジュールだけをビルドした。主な対象は `Surface.Lemmas.Typing`、`Surface.Check`、`Surface.CheckComputeSound`、`Surface.SingleFailCheck`、`Surface.CheckSoundControl`、`Surface.FailureExamples`、`Surface.Examples` である。追加の前提・新構成子の相互帰納、計算用と数学上の型操作の一致、最終の受け入れへQを渡す接続で生じたビルド失敗を修正し、下表の局所ビルドとworkで確認した。途中の各試行では外側の全経過時間を採取しておらず、成功結果の引用には用いない。作業ディレクトリを誤指定した呼び出しも、formal/からやり直した。

| コマンド | 終了状態 | 外側の時間と結果 |
|---|---:|---|
| formal/で `lake build Benitoite` | 0 | 8.752秒。Leanライブラリと新旧の例を含む161ジョブが成功。[局所ビルドの記録](local-build.log)。その後の証明の不要な局所変数と空行の整理は、下のworkで検査した |
| 根で `scripts/check.sh --level work --base 0c6673533a8d358ce1aab5d29f64de9c4ac1bbab --only formal_build,spec_examples,spec_tally --dry-run` | 0 | 0.012秒。名指しの三単位だけを選択。[選択の記録](dry-run.log) |
| 上記から `--dry-run` を外した指定 | 0 | 62.191秒。仕様網羅性の自己検査・集計、仕様例7件、六実行ファイルを含む既定のlake buildとsorryの拒否が成功。[workの記録](work-check.log) |
| `git diff --check` と追加したローカルリンクの確認 | 0 | ツールの表示で1秒未満。空白の誤りとリンク先の欠落なし |

計画のworkはdry-runを確認してから一度だけ実行した。Rustは変更していないため、lib全件・clippy・fmtを追加していない。check.shの全体、gc-stress、check-formal.shの全比較は実行していない。

## 計画からのずれと申し送り

R60は表層の一節の表し方と結果型の注釈、R61はQを使うようになった最終の受け入れの接続を具体化したものである。L2cの範囲と完了条件は変えていない。公理・Builtins.Assumptions・主要定理の外側の前提と結論は変更していない。

L3a/bは、この表層の構文と単一Failの条件を保って操作の辞書を接続する。Fail節は専用の捕捉式なので、通常節の辞書と継続の束縛を加える際に混在させない。L4bは `raise`・`handleFail` とFailの型・効果を交換11/4へ接続し、六入口の独立入力と旧Rust出力の全比較を行う。今回の例で「別モジュール」とするものは名前解決済みの宣言参照であり、モジュールの解決自体の証明ではない。Rustの新機能への接続は段3以降に残る。

L2cは完了した。コミットとdocs/todoの変更は行っていない。
