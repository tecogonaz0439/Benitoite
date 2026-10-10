# 依頼: 脱糖の形式化の段階 C6a-3 の定義と証明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

C6a-3（コミット 90dce19）で、`formal/Benitoite/Surface/` にトップレベルの定数の参照を足した。`decisions.md` の P5 のとおり、定数の参照を、注釈の型と本体をその場で埋め込んだ `Expr.constE ty body` で表し、脱糖は本体の脱糖そのもの、型付けは使う位置の制約の並びと R、空の局所の環境で本体を `.other` の位置で検査する（`E_Const`）。`sorry` なしで証明まで済んでいる。実装担当の報告は同じディレクトリの `report.md` にある。変更は `git -C /Users/tecogonaz/src/Benitoite-C1 show HEAD` で見られる。

## 読むもの

- `formal/Benitoite/Surface/` の `Syntax.lean`・`Typing.lean`・`WellFormed.lean`・`Desugar.lean`・`Examples.lean`・`Lemmas/Typing.lean`（C6a-3 で足した部分）。
- 01-12「トップレベルの定数」、01-06「定数の型（初回リリース版）」、01-02「定数（初回リリース版）」、01-03 の定数の参照の循環の記述。`docs/2026-10-10-TODO-162-desugar-formalization-phase2/decisions.md` の P5。
- 処理系の `crates/benitoite/src/ir/core_ir.rs` の定数の定義と `ConstRef`（照合が要る箇所だけ）。

## 観点

1. 脱糖と型付けが 01-12・01-06 を表すか。本体のエフェクトを空と求めること、注釈の型と本体の型を等しくすること、`Expr.Exits` を `False` にすること、範囲の条件（値の変数 0 個）。
2. 表層の型付けが広くなった点（報告の 3）が、性質 1 を偽にしないか。R を保つことで、形式化した広い入力で本体に `return` や `try` に型が付く場合の扱い。
3. 弱化の証明（`RenOk [] Γ id` と `HasTypeC.rename`・`Comp.rename_id`）が正しく、性質 1 の言明が弱まっていないか。
4. 後の作業 C6c-3（処理系の `ConstRef` を定数の本体の脱糖結果に置き換えて比べる）で要りそうな対応と、同じ定数の各参照が同じ注釈と本体を持つことを書き出しでどう保証するか。
5. 01-12 の写しへの反映で直すべきこと。

## 出力の形

指摘ごとに、重さ（高／中／低）・場所・問題・原因の分類・直し方の案を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。回答は日本語で書く。
