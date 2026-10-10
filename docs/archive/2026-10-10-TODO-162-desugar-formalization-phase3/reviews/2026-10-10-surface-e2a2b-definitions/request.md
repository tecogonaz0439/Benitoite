# 依頼: 段階 E2a-2b（表層の型付けの検査の関数と健全性の言明）の定義と言明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

- 改造 TODO-162 のフェーズ 3 の段階 E2 は、処理系の型検査の出力（型の情報を付けた表層の構文）に Lean の表層の型付けで型が付くかを検査する関数を書き、その健全性を証明する。計画は `docs/2026-10-10-TODO-162-desugar-formalization-phase3/`（`study.md` の E2、`decisions.md` の Q9〜Q15、`plan.md`）。
- E2a-2a（3ff438c）で判定の道具を作り、そのレビュー（`formal/reviews/2026-10-10-surface-e2a2a-definitions/`。`handling.md` に扱い）を経て、E2a-2b（このレビューの対象のコミット）で検査の関数の全体と健全性の言明を書いた。証明は後半の E2b で行う。
- 実装担当の報告は同じディレクトリの `report.md`。変更は `git -C /Users/tecogonaz/src/Benitoite-C1 show HEAD~0 --stat` と、`formal/Benitoite/Surface/` の `CheckSupport.lean`・`Check.lean`・`CheckSound.lean`・`CheckExamples.lean` で見られる（基準は 6e6c4d9）。
- 依頼文からの変更: `B_LastBind` は、規則の結論に注釈 `t` が現れるので、式の最小の型を求めた後に注釈 `t` への包含を確かめる。

## 読むもの

- 上の四つのファイルと、E2a-2a の `CheckTools.lean`・`CheckPredicates.lean`・`CheckPatterns.lean`。
- `formal/Benitoite/Surface/Typing.lean`（全規則）、`Surface/Syntax.lean`、`Surface/Examples.lean`。
- `formal/Benitoite/Release/Typing.lean`・`Subst.lean`・`Coverage.lean`。

## 観点

1. 健全性の言明 11 件と `Input.Sound` が正しいか（偽になる入力がないか）。前提が強すぎて意味が薄れていないか、足りないか。特に、厳密な印に限ること、`ImplNamesComplete` などの有限の一覧の前提、原子の前提の範囲、出力の型とエフェクトの `AtomsIn` を結論に含めたこと。
2. 検査の関数が表層の型付けの規則を正しく写しているか（74 規則の対応の表を報告の 4 で確かめる）。型を決める位置（`E_ReturnTail`・`E_ReturnOther`・`E_List`・`B_LastBind`・`B_LastDiscard`・`B_Discard`・`E_Call` の εcall・`E_PartialCon`・`ite` の結び・パイプの形）、`handle`（t の結び、ε の緩い反復と厳密な再検査）、網羅性の判定、名前から作るエフェクトの `atoms.contains`、`E_Binary` の `OpPrimTypeArgs`。規則より厳しい（型が付くのに失敗する）箇所は、健全性を損なわないが、後の E2c で処理系の出力を検査するときの偽の不一致になる。そうした箇所を挙げ、E2c で問題になりそうかを評価する。
3. 後半 E2b（証明）が成り立つか。報告の 7 の見込みと分け方の案（E2b-1 道具と基本の言語、E2b-2 制御と型クラス、E2b-3 拡張とパターン）を評価する。
4. 例が意図どおりのことを確かめているか。
5. 次の E2c（処理系の書き出しから入力を作り、全定義を検査する）の妨げになる点。

## 出力の形

指摘ごとに、重さ（高: 言明が偽・弱い、または規則と意味が違う。中: 証明や E2c の妨げ。低: 表記）、場所、問題、修正案を書く。重要なものから並べる。最後に、E2b と E2c へ進んでよいかの判断を一文で書く。
