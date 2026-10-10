# 依頼: 段階 E2a-2a（表層の型付けの検査のための判定の道具）の定義と言明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

- 改造 TODO-162 のフェーズ 3 の段階 E2 は、処理系の型検査の出力（型の情報を付けた表層の構文）に Lean の表層の型付け（`formal/Benitoite/Surface/Typing.lean` の `HasType` など）で型が付くかを検査する関数を書き、その健全性（検査が成功すれば `HasType`）を証明する。計画は `docs/2026-10-10-TODO-162-desugar-formalization-phase3/`（`study.md` の E2、`decisions.md` の Q9〜Q15、`plan.md`）。
- 設計者の決定: Q9（表層の構文の上で、入力の全原子の有限の集合 `atoms` の上で判定し、原子の前提を健全性の定理に置く）、Q10（最小の型とエフェクトを自分で求める）、Q12（構文の全体を一度に定義する）、Q14（組み込みの制約は判定の関数で）、Q15（E2 のレビューは Opus と Astra）。
- 検査の関数は二つの作業に分けた。E2a-2a（コミット 3ff438c）で判定の道具を作った。次の E2a-2b で検査の関数の全体と健全性の言明を書く。E2a-2b を始める前に、道具の形（特に原子の前提 `AtomsIn` と判定の関数の健全性の言明の前提）が、検査の関数の健全性の証明に足りるかを確かめたい。
- 実装担当の報告は同じディレクトリの `report.md`。変更は `git -C /Users/tecogonaz/src/Benitoite-C1 show 3ff438c` で見られる。
- E2a-2b の方針の控え（事前点検で決めたこと）: `handle` の型 t は本体の最小の型、ε は反復の間だけ `E_Resume` の包含を緩める印で求め、確定した ε で厳密にもう一度検査する。健全性の前提は、式の注釈に加えて Γ・R・宣言の表の全項目・組み込みの関数の表の全項目の `AtomsIn`、`SatDecSound`・`AdmitsDecSound`、`CtorsComplete`。`E_With` の `State` と `E_Op` のエフェクトの名前は検査の関数の中で `atoms.contains` を確かめる。

## 読むもの

- `formal/Benitoite/Surface/` の `CheckTools.lean`・`CheckPredicates.lean`・`CheckPatterns.lean`・`CheckToolsExamples.lean`。
- `formal/Benitoite/Surface/Typing.lean`（全規則）、`Surface/Syntax.lean`。
- `formal/Benitoite/Release/` の `Syntax.lean`（`Eff`・`Atom`・`Ty`）、`Typing.lean`（`Eff.Sub`・`Ty.Le`・`SatAll`・`PatTy`・`AltsTy`）、`Subst.lean`（`Ty.shift`・`Ty.substAt`・`Eff.substRho`）、`Coverage.lean`（`useful`・`irrefutable` と健全性の系）。

## 観点

1. `AtomsIn` の定義と、判定の関数（`effSub`・`effEq`・`tyEq`・`tyLe`・`unionEff`・`singleEff`）の健全性の言明が正しいか。前提が足りるか・強すぎないか。特に、エフェクト変数（rho）、`Eff.substRho`、型の置き換え、`shift` を通った後に `AtomsIn` が保たれる言明（`substRho_atoms` など。`sorry` のもの）が成り立つか（偽でないか）。
2. 規則の前提の真偽値の版（`CheckPredicates.lean`）が元の Prop と一致するか（`↔` の言明の向きと形）。挙げ漏れた前提がないか（報告の 3 の表と `Typing.lean` の全規則を照らす）。
3. `patTy`・`altsTy`・`checkAlts` と網羅性の包みが、`PatTy`・`AltsTy`・`Exhaustive` の前提を正しく判定するか。`sorry` の言明が偽でないか。
4. この道具で、E2a-2b の検査の関数の健全性（`HasType` を導く）が証明できるか。足りない道具や、形を変えた方がよい道具（例: 両側の `AtomsIn` を要する等しさの判定を、検査の関数のどの位置で使うと前提が満たせないか）。
5. 構造的な再帰で `decide` で評価できる形になっているか（例が通っているか）。

## 出力の形

指摘ごとに、重さ（高: 言明が偽・弱い、または E2a-2b の健全性の証明を妨げる。中: 証明や後の段階の手間。低: 表記）、場所、問題、修正案を書く。重要なものから並べる。最後に、E2a-2b へ進んでよいかの判断を一文で書く。
