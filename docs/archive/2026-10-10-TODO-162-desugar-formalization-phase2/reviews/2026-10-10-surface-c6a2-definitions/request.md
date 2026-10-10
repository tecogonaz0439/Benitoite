# 依頼: 脱糖の形式化の段階 C6a-2 の定義と証明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

フェーズ 1 と段階 C4・C5・C6a-1 で、型の情報を付けた表層の構文・表層の型付け・脱糖を `formal/Benitoite/Surface/` に定め、性質 1（`desugar_typed`）と `surface_effect_soundness` を `sorry` なしで証明した。C6a-2（コミット dd8dd5e）で、レコードの構築・更新・パターンと、フィールドを取り出す関数（`desugarProgram` が Σ に加える定義）、レコードの条件 `RecordsOk` を足し、`sorry` なしで証明まで済ませた。定義と証明を一度にレビューする。計画は `docs/2026-10-10-TODO-162-desugar-formalization-phase2/`（`plan.md` の C6、`study.md` の C6、`decisions.md` の P3・P4）にある。

実装担当に事前に与えた決まり（妥当性もレビューの対象とする）:

- レコードは構成子を一つだけ持つデータ型として表す（`Release` にレコードの構成はない）。`desugarExpr` と `Pattern.toCore` は宣言の表を受け取らないので、構成子・型引数・フィールドの位置・フィールドの総数を構文に持たせる。
- 更新とフィールドを取り出す関数は、処理系の形に合わせる（書き換えるフィールドを `_` にする、取り出すフィールドだけを変数にする。01-12 は全フィールドを変数に束縛する）。
- 更新の網羅性は、型付けの規則の前提に `Exhaustive` を置いてよい。フィールドを取り出す関数の網羅性は `RecordsOk`（構成子が一つだけ）から導く。
- フィールドを取り出す関数は `Program.accessors : FunName → Option (ConName × Nat)` から作り、`defs` を先に引く一つの検索（`Program.lookupFun`）で `declarations.funs` と `desugarProgram.defs` の両方を定義する。

実装担当の完了の報告は同じディレクトリの `report.md` にある。まずそれを読むこと。変更は `git -C /Users/tecogonaz/src/Benitoite-C1 show dd8dd5e` で見られる。

## 読むもの

- `formal/Benitoite/Surface/` の `Syntax.lean`・`Typing.lean`・`WellFormed.lean`・`Desugar.lean`・`Examples.lean`（C6a-2 で足した部分）と、`Lemmas/Records.lean`、`Lemmas/Program.lean`・`Lemmas/Typing.lean`・`Lemmas/CallHead.lean`・`Lemmas/Invariants.lean` の変更。
- `formal/Benitoite/Release/` の `Syntax.lean`・`Typing.lean`（`V_Con`・`C_Match`・`PatTy`・`Exhaustive`・`Def.WellTyped`・`Program.WellTyped`）。
- 01-12「レコード」と「型の情報を付けた表層の構文と型付け」。01-02「レコード（初回リリース版）」、01-05「レコード（初回リリース版）」、01-06 のデータ型の型パラメータの扱い。
- 処理系の `crates/benitoite/src/ir/desugar/exprs.rs` の `record`、`decls.rs` の `getters`、`patterns.rs` の `Pattern::Record`（照合が要る箇所だけ）。

## 観点

1. 脱糖の各場合が、処理系の脱糖（と、形が同じ部分は 01-12 の行）に一致するか。構築の評価の順と並べ替え、更新の `let` の順・分岐のパターン・束縛の番号とずらし、パターンの束縛の順、フィールドを取り出す関数の定義の形。
2. 表層の型付けが 01-05・01-06・01-12 を表すか。余計な制限や緩和。特に、位置の置換の前提、更新の前提（位置が空でないこと、網羅性）、パターンに独立した規則を置かないこと、フィールドを取り出す関数の型（型パラメータに制約を持たせない、エフェクトが空）、`RecordsOk` の内容（重ならない条件と一つの検索の関係）。
3. `Program.lookupFun` の優先の順と、`HasMain`・`main_typed`・既存の補題との整合。性質 1 の言明が弱まっていないか（前提を余計に使っていないか、`RecordsOk` が型検査を通ったプログラムで成り立つか）。
4. 表層の型付けが広くなった点（報告の 3）が、性質 1 を偽にしないか。パターンの位置の重複や範囲外を排除していないことの影響。
5. 後の作業（C6a-3 のトップレベルの定数、C6c-2 の差分テストの拡張、C7 のパターンの拡張）の妨げと、差分テストで要りそうな対応（パターンの束縛の順、フィールドを取り出す関数の名前、書き出しの `definitions()`）。
6. 01-12 の写しへの反映で直すべきこと。

## 出力の形

指摘ごとに次を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。

- 重さ: 高（定理が偽になる・弱まる、または 01-12・01-02・01-05・01-06 と意味が違う）／中（後の段階の妨げ）／低（表記・コメント）
- 場所: ファイルと行
- 問題
- 原因の分類: 01-12 の規則の誤り／書き写しの誤り／表現の都合／その他
- 直し方の案

回答は日本語で書く。
