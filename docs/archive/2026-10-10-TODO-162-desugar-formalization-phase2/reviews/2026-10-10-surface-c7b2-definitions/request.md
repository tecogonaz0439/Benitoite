# 依頼: 段階 C7b（表層の `match` の脱糖先の移しと、表層へのパターンの拡張）の定義と言明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

- 段階 C7a（コミット 1afd008・c43451f・e2e7f80）で、コア計算 `Release` にパターンの拡張を加え、性質 2・3 を証明した。加えたのは、範囲とリストのパターン、選択肢 `Alt`（`pat`・`slots`）、`Arm`、`Comp.matchX`、`C_MatchX`・`AltsTy`・`HasTypeXArms`。そのレビューは `formal/reviews/2026-10-10-release-c7a1-definitions/`。
- 設計者の決定（`docs/2026-10-10-TODO-162-desugar-formalization-phase2/decisions.md`）:
  - P2: 案 (ii)（コアの照合を広げる）を正式に採った。
  - P12: ガードの中の `resume` を言語の規則で禁じる（処理系の修正は別の改造 docs/todo の TODO-190）。
  - P13: 表層の `match` をすべて `Comp.matchX` に脱糖する。
- C7b は二つの作業で行った。どちらも `sorry` なしで証明まで済んでいる。
  - C7b-1（コミット c57e2e1）: 表層の構文を変えずに、脱糖の 7 か所（`match`・`try` の 2 種類・パターン束縛の 2 種類・レコードの更新・フィールドを取り出す関数）が出す照合を、選択肢一つ・恒等・ガードなしの `matchX` に移した。差分テストの Lean 側の変換（`Exchange/Convert.lean` の `fromComp`）は、その形の `matchX` を交換形式の `match` に変える。
  - C7b-2（コミット f57da11）: 表層に範囲とリストのパターン、`slots` を持つ選択肢、省略できるガードを足した。型付け（`HasArms.plain`・`guarded`、`Pattern.Valid`、`Arms.unguardedPatterns`）、脱糖、範囲の条件、性質 1 の証明、例を広げた。
- 実装担当の報告は同じディレクトリの `report.md`（C7b-2）にある。まずそれを読むこと。変更は次のコマンドで見られる。
  - `git -C /Users/tecogonaz/src/Benitoite-C1 show c57e2e1`
  - `git -C /Users/tecogonaz/src/Benitoite-C1 show f57da11`
- 差分テストにパターンの拡張を入れるのは、次の作業 C7c である。

## 読むもの

- `formal/Benitoite/Surface/` の `Syntax.lean`・`Typing.lean`・`Desugar.lean`・`WellFormed.lean`・`Examples.lean`（C7b で足した例）と、`Lemmas/` の変更（`Patterns.lean`・`Typing.lean`・`Scoped.lean`・`Sequence.lean`）。
- `formal/Benitoite/Release/` の `Syntax.lean`・`Subst.lean`・`Typing.lean` のパターンの拡張の部分。
- 言語の規則:
  - 01-05: 「パターン」「パターンの拡張（初回リリース版）」「match の意味」「網羅性の検査」「選ばれない分岐の検査」。
  - 01-06: `resume` の制限。
  - 01-12: 「パターン」・C-Match。「初回リリース版の拡張」の表のパターンの拡張の行は、C7 の前の記述で、後で改める。
  - 02-06: 「パターンの拡張」。
- 処理系の型検査のパターンの拡張（`crates/benitoite/src/typeck/` の `pattern_ext.rs`・`patterns.rs` など）。照合が要る箇所だけ読めばよい。

## 観点

1. 表層の型付けが 01-05・01-06 と処理系の型検査を写しているか。余計な制限や緩和がないか。特に次の点。
   - 範囲の両端と `lo ≤ hi`。
   - リストの形（残りがなければ後の要素がない）。
   - 選択肢の束縛（同じ変数を同じ型で束縛すること。`slots` と `AltsTy` での表し方）。
   - ガードの型付け（P12 の写し方。`hideConts`・R なし・空のエフェクト・`Boolean`）。
   - 網羅性（ガード付きの分岐を除き、選択肢を別々に数える）。
   - パターン束縛の左辺に範囲とリストを書けること。
   - 報告の 3 の「言語との既知の差」（`Character` のすべての値を覆う範囲を束縛の左辺に書ける）を残してよいか。
2. 脱糖が処理系のコア IR（`crates/benitoite/src/ir/core_ir.rs` の `Match`・`MatchRow`・`MatchArm`）と同じ意味を持つか。
   - 選択肢の順と束縛の並べ替え。
   - ガードの位置と変数の付け替え。
   - 照合する値の `let`。
3. `Arms.Exits`（必ず抜けるの判定）・範囲の条件・網羅性の関数の定義が正しいか。
4. 性質 1 の言明（`desugar_typed` と `surface_effect_soundness`）と前提が変わっていないか。補題が言明を弱めていないか。例が意図どおりのことを確かめているか（特に、ガードの中の外側の `resume` に型が付かないことの例）。
5. 次の作業 C7c の妨げになる点。C7c では、処理系の分岐の行を分岐ごとにまとめ、選択肢の `VarId` から `slots` を求め、ガード・範囲・リストのパターンを交換形式に足す。報告の 6 の見込みも見ること。
6. `Comp.match` を `Release` から消すかどうかについての所見。表層の脱糖はもう使わない。消したときに失うものと、残す理由の有無。

## 出力の形

指摘ごとに、次を書く。重要なものから並べる。

- 重さ:
  - 高: 定理が偽になる・弱まる、または 01-05・01-06・01-12 と意味が違う。
  - 中: 証明や後の段階の妨げ。
  - 低: 表記・コメント。
- 場所。
- 問題。
- 原因の分類。
- 直し方の案。

問題がない観点は「問題なし」と一行で書く。観点 6 には所見を必ず書く。回答は日本語で書く。
