# 依頼: 脱糖の形式化の段階 C6a-1 の定義と証明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

フェーズ 1 と段階 C4・C5 で、型の情報を付けた表層の構文・表層の型付け・脱糖を `formal/Benitoite/Surface/` に定め、01-12「表層からの脱糖」と、`try`・`with`・`lazy`・ハンドラ・利用者の操作・型クラスについて性質 1（`desugar_typed`）と `surface_effect_soundness` を `sorry` なしで証明した。段階 C6 は脱糖だけで表す初回リリース版の拡張を足す。C6a-1（コミット a908b60）で、`Decimal` のリテラル（直接の負号 `negDecimal` を含む）、リストの展開（`listSpread`）、文字列補間（`interpolation`）を足し、`sorry` なしで証明まで済ませた。定義と証明を一度にレビューする。計画は `docs/2026-10-10-TODO-162-desugar-formalization-phase2/`（`plan.md` の C6、`study.md` の C6、`decisions.md` の P3・P4）にある。

実装担当に事前に与えた決まり（妥当性もレビューの対象とする）:

- 処理系と 01-12 の形が違うもの（補間の String の式と空の断片、展開の空の側の省略、`Decimal` の直接の負号）は、Lean を処理系に合わせる（P3）。
- 補間の連結は構文に持たせず、既存の `opPrim (.binary .add) (.base .string)` を使う。部分が 2 つ以上あるときだけ `E_Binary` と同じ前提を置く。
- `str_T`・`concat_T` に当たる呼ぶ値は表層の構文に式で持たせ、`directCallee` と `CallHead.apply` で扱う。
- 新しい入れ子の帰納型は作らず、並行したリストで持たせる。
- `let` の順は、補間では全部の式 → `str` の結果 → 連結の中間で、最後の連結だけが末尾の計算。部分が 1 つなら `return part`、0 なら `return ""`。

実装担当の完了の報告は同じディレクトリの `report.md` にある。まずそれを読むこと。変更は `git -C /Users/tecogonaz/src/Benitoite-C1 show a908b60` で見られる。

## 読むもの

- `formal/Benitoite/Surface/` の `Syntax.lean`・`Typing.lean`・`WellFormed.lean`・`Desugar.lean`・`Examples.lean`（C6a-1 で足した部分）と、`Lemmas/Extensions.lean`・`Lemmas/ExtensionsScoped.lean`、`Lemmas/CallHead.lean`・`Lemmas/Typing.lean`・`Lemmas/Scoped.lean` の変更。
- `formal/Benitoite/Release/` の `Syntax.lean`（`Const.decimal`・`Const.type`）・`Typing.lean`。
- 01-12 の「名前とリテラル」「基本型とコレクションの型」「リストの展開」「文字列補間」「型の情報を付けた表層の構文と型付け」。01-02「文字列補間」「リストの展開（初回リリース版）」、01-06「演算子の型付け」「式と文の型」、01-08 の評価の順。
- 処理系の `crates/benitoite/src/ir/desugar/exprs.rs` の `list`・`interpolation`・`unary`（照合が要る箇所だけ）。

## 観点

1. 脱糖の各場合が、処理系の脱糖（と、形が同じ部分は 01-12 の行）に一致するか。`let` の順、末尾の計算、空の断片と空の側の省略、部分が 0・1 の形、呼ぶ値の頭の番号のずらし。評価の順が 01-08 に合うか。
2. 表層の型付けが 01-06・01-12 を表すか。余計な制限や緩和。特に、補間の式の型を 7 つの基本型に限ったこと（01-06 の補間の型の規則と比べて狭すぎないか、型パラメータの式を補間する場合をどう扱うか）、呼ぶ値の純粋性の要求、`StringAddOk` を部分が 2 つ以上のときだけ求めること、`listSpread` の `concat` の型。
3. `directCallee_typed` の言明を一般化した変更（`Lemmas/CallHead.lean`）が、既存の証明と後の段階を妨げないか。
4. 性質 1 の言明が弱まっていないか。
5. 後の作業（C6a-2 のレコード、C6a-3 の定数、C6c の差分テストの拡張）の妨げと、差分テストで要りそうな正規化（呼ぶ値の写し方、断片の表し方）。
6. 01-12 の写しへの反映で直すべきこと（食い違いとして挙がった 4 件の書き方を含む）。

## 出力の形

指摘ごとに次を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。

- 重さ: 高（定理が偽になる・弱まる、または 01-12・01-02・01-06 と意味が違う）／中（後の段階の妨げ）／低（表記・コメント）
- 場所: ファイルと行
- 問題
- 原因の分類: 01-12 の規則の誤り／書き写しの誤り／表現の都合／その他
- 直し方の案

回答は日本語で書く。
