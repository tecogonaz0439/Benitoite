# RV-L20-fix の結果: L20 のレビューの指摘（中1・中2・軽8・軽9）の修正

## 作業と状態

| 欄 | 内容 |
|---|---|
| 作業 | RV-L20-fix（`reviews/RV-L20.md` の「対応（取りまとめ）」の中1・中2・軽8・軽9）。担当は Claude のサブエージェント |
| B_WORK | `037864d93faa976ead5e9298fb55746afa0b1b03`（本線、RV-L20 の記録の後）。作業用のディレクトリ `<wt>`、ブランチ `m013/rv-l20-fix`。git の状態は変えていない |
| 状態 | **完了**。既定の全体のビルドが sorry なしで通る |
| 閉じた範囲 | 依頼の 1〜5 |
| 未完 | なし |
| 停止条件 | 該当しない。七つの主定理のうち字面が変わったのは `surface_effect_soundness` の `hb` だけで、前提を弱める向きである。結論の弱化、公理の追加、`Builtins.Assumptions` の欄の変更はない |

## 変えた宣言

| 宣言（ファイル） | 変更前（B_WORK） | 変更後 |
|---|---|---|
| `Surface.surface_effect_soundness`（`Surface/Theorems.lean`） | `(hb : B.Assumptions (desugarProgram opPrim p))`。証明は `hb.sig_scoped` と `hb.core` を使う | `(hb : B.CoreAssumptions (desugarProgram opPrim p))`。証明は `hb.sig_scoped` と `hb` を直接使う。結論と他の前提は同じ。説明のコメントに「旧の条件 CoreAssumptions だけを求め、対象一致の条件を求めない」を加えた |
| `Surface.program_effect_soundness`（`Surface/Examples.lean`、利用側） | 全体の `Release.Model.assumptions …` を渡す | 射影 `(Release.Model.assumptions …).core` を渡す。言明は同じ |

`Surface.desugar_typed` の字面は変えていない。`program_desugar_typed`（`Surface/Examples.lean`）は `desugar_typed` に全体の仮定の `.sig_scoped` を渡しており、変える必要がなかった。

```lean
-- 変更前
(hb : B.Assumptions (desugarProgram opPrim p))
-- 変更後
(hb : B.CoreAssumptions (desugarProgram opPrim p))
```

## 消した宣言

| 宣言（ファイル） | 理由 | 利用側の置き換え |
|---|---|---|
| `Release.stateTy_iff_old`（`Release/Lemmas/PresHelpers.lean`） | 前提が型の付く状態で必ず偽になり、空に成り立つ（RV-L20 中2） | 利用する宣言はなかった（`formal/` の全 `.lean` を検索）。`StateTy` については `stateTy_of_old`（旧の定義で型の付く状態は新しい定義でも型が付く）だけを主張する。旧の像での同値は `BuiltinOnly.iff_old` が担う |

## コメントの修正（軽8）

`Release/Lemmas/TargetSound.lean` と `Release/ShapeOk.lean` の先頭のコメントの「L00.03 の模型の」を「L00.03 のモデルの」に直した。依頼の範囲外のファイル（`Release/EffectCover.lean`、`Scope/CompatExamples.lean`、`Scope/Signature.lean`、`Scope/RepresentationExamplesI.lean`）にも「模型」が残っている（申し送り 1）。

## 設計書の変更（07-04）

| 箇所 | 変更 |
|---|---|
| 「証明する性質」の L20.7 の信頼条件の分離の【決定】 | `surface_effect_soundness` の `hb` の型も `B.Assumptions (desugarProgram opPrim p)` から `B.CoreAssumptions (desugarProgram opPrim p)` に変えたこと（前提を弱める字面の変更）を書いた。「言明の字面を変えずに全体の信頼条件を受け取り」を除き、「`hb` の欄 `sig_scoped` で性質 1 を使い、`hb` をそのまま性質 3 へ渡す」とした |
| 「証明する性質」の BA の【決定】 | `stateTy_iff_old` による `StateTy` の同値の文を除き、「`StateTy` については `stateTy_of_old` だけを示す」とした |
| 「01-12 との対応」の BA・信頼条件の分離の行 | 同値の根拠から `stateTy_iff_old` を外し、`BuiltinOnly.iff_old` を同値、`stateTy_of_old` を片向きの包含として分けて書いた |
| 「証明する性質」の L20.4 の V-Checked の【決定】（軽9） | 「範囲が Top の不透明型の網羅性は以前と同値」「範囲の変数を持たず範囲が Top だけの型と表では、前提の内容は以前と同値」を、補題が示す内容に絞った。対象の種類を持たない表では `release_exists` が以前と同値（`release_exists_iff_old` ほか）、網羅性は照合する値の型が最上位で範囲 Top の不透明型のとき以前と同値（`Exhaustive.opaqueTop_iff`）。入れ子の型の中の不透明型の網羅性と `delta_typed`・`io_typed`・`io_exists` の同値は補題として示していないと書いた |

## 検査

| 検査 | コマンド | 終了 | 外側の時間 | 記録 |
|---|---|---|---|---|
| 既定の全体のビルド | `cd <wt>/formal && <repo>/work/m013/lake-build-locked.sh <tmp>/build1.log`（外側を `/usr/bin/time -l` で包んだ） | 0 | 246.85 秒（排他の待ち 76 秒を含む。ビルドそのものは 170.51 秒）。448 ジョブ。sorry の警告 0 件。変えたファイルに新しい警告はない | [lake-build.log](lake-build.log) |
| 作業末の検査の選択 | `cd <wt> && scripts/check.sh --level work --base 037864d93faa976ead5e9298fb55746afa0b1b03 --dry-run` | 0 | — | [work-check-dry-run.log](work-check-dry-run.log)。選ばれたのは `formal_build` だけ（理由は `PresHelpers.lean` の変更） |
| 作業末の検査 | `cd <wt> && /usr/bin/time -l scripts/check.sh --level work --base 037864d93faa976ead5e9298fb55746afa0b1b03` | 0 | 0.24 秒（直前のビルドで全ジョブが最新のため） | [work-check.log](work-check.log)・[work-check-time.txt](work-check-time.txt) |
| 公理の依存 | `cd <wt>/formal && /usr/bin/time -l lake env lean -M 12288 <rv-l20-fix>/axioms.lean` | 0 | 0.80 秒 | [axioms.lean](axioms.lean)・[axioms.log](axioms.log)・[axioms-time.txt](axioms-time.txt) |

公理: `surface_effect_soundness` と `stateTy_of_old` は、どちらも `propext`・`Classical.choice`・`Quot.sound` だけに依存する。`sorryAx` と独自の公理はない。

## 最大常駐量

macOS の `/usr/bin/time -l` の `maximum resident set size`（バイト）。

| 対象 | 原値 | 換算 |
|---|---|---|
| 全体のビルド（排他の道具の中の `lake build` の計時、並列のビルド全体） | 3147415552 | 3001.6 MiB（2.93 GiB） |
| 作業末の検査（`check.sh` の全体） | 69894144 | 66.7 MiB |
| 公理の検査（`lake env lean -M 12288`、単一のプロセス） | 1512603648 | 1442.5 MiB（1.41 GiB） |

## 失敗と修正

なし。最初のビルドで通った。

## ずれと申し送り

1. 「模型」は依頼の範囲外の 4 ファイルのコメントに残っている（`Release/EffectCover.lean` の 1 箇所、`Scope/CompatExamples.lean`・`Scope/Signature.lean`・`Scope/RepresentationExamplesI.lean`）。L00.01・L00.06 の比較用のモデルを指す語である。直すかは取りまとめに返す。
2. 01-12 で `surface_effect_soundness` に触れるのは die の節の一文（「`desugar_typed` と `surface_effect_soundness` は前提と結論を変えず両場合を含む」）だけである。die の追加についての記述であり、今回の `hb` の変更と矛盾しないので、編集の範囲外として変えていない。
3. `Release/Lemmas/Membership.lean` の先頭のコメント（「範囲が Top の不透明型では網羅性の判断を変えない」）は範囲外なので変えていない。`Exhaustive.opaqueTop_iff` の言明のとおり最上位の型についての記述として読める。
4. 停止の表の `hb` の行に表層を加えることと、L20.7 の results の主定理の表の記述（`stateTy_iff_old` と、`surface_effect_soundness` の「字面は同じ」）の扱いは、取りまとめの作業である。L20.7 の results は記録のまま変えていない。

## 時間

| 項目 | 時刻・時間 |
|---|---|
| 開始 | 04:33 ごろ |
| 全体のビルド | 04:41:04〜04:45:11（排他の待ち 76 秒を含む） |
| 作業末の検査 | 04:46:27（0.24 秒） |
| 終了 | 04:48 ごろ |
| 外側の所要 | 約 15 分 |
| 能動時間 | 約 12 分（ビルドの待ちを除く）。見込み 0.3〜1 時間の範囲内 |
