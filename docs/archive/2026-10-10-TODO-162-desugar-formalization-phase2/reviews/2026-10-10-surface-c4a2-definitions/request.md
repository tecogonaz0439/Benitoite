# 依頼: 脱糖の形式化の段階 C4a-2 の定義のレビュー

あなたはレビュー担当である。Lean のファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

フェーズ 1（段階 C1〜C3）で、型の情報を付けた表層の構文・表層の型付け・脱糖を `formal/Benitoite/Surface/` に定め、01-12「表層からの脱糖」（基本の言語）の全体について性質 1（`desugar_typed`）と `surface_effect_soundness` を証明した。フェーズ 2 の段階 C4 で、`try`・`with`・`lazy` を加えて証明した（C4a-1・C4b-1。記録は `formal/reviews/2026-10-10-surface-c4a1-definitions/`）。C4a-2（コミット 9344b17）で、ハンドラ（`handle` の式と節）、節の中の `resume`、利用者の操作の名前（値として使う形と直接の呼び出し）と、表層のプログラムの操作とエフェクトの表を足した。定理の言明は変えず、節の本体の型保存の証明だけが `sorry` である（証明の不変条件 `EnvClean` を継続の変数を許す形に広げる後半の C4b-2 で証明する）。計画は `docs/2026-10-10-TODO-162-desugar-formalization-phase2/`（`plan.md` の C4、`study.md` の C4、`decisions.md` の P3・P4）にある。

実装担当に事前に与えた決まり（妥当性もレビューの対象とする）:

- 節の環境は `Release` の `C_Handle` と同じ形: `some (.cont sg.ret (t.shift k 0) ε) :: (binds sg.params ++ shiftEnv k Γ)`、制約の並びは `sg.tparams ++ C`、R は `R.map (Ty.shift k 0)`、節の本体の型は `t.shift k 0`、エフェクトはずらさない。表層の節は引数の型を持たず、arity と ntys が `opSig` と一致することを型付けで求める（arity は `_` を含む）。
- `opSig`・`handled` は、操作とエフェクトの表を写した `D.patternProgram` で引く。表層の節の並びから `Release.Clause` の並びを作る関数に `handled` を当て、脱糖の結果との一致の補題を置く。
- 範囲の条件は、節の本体を `nt + ntys`、`nv + 1 + arity` で検査し、`resume k e` は `k < nv`。節の中の型と `try` の `retArgs` は、節の型パラメータの分だけずらした形で持つ。
- `handle` の本体と節の本体は `.other`。R は本体でそのまま、節でずらす。`return`・`try` を禁じない。
- `resume` は継続の番号を明示し、型付けは `Γ[k]? = some (some (.cont b t ε))` と `e : b ! ε` から `t ! ε`。脱糖は `.letIn ⟦e⟧ (.resume (.var (k+1)) (.var 0))`。番号を明示するので、内側の節から外側の節の継続へ `resume` する項（処理系は作らない形）にも型が付く。
- 組み込みの操作の節は `OpRef.prim b`。
- 表の条件は `desugar_typed` の引数を増やさず、表層の `Program.WellFormed`（`OpDecl.Scoped`、操作と一覧の整合）と `Program.WellTyped`（`B` に依存する条件）に置く（P4）。
- `Expr.Exits` は変えない（`handle`・`resume` は必ず抜けない）。

実装担当の完了の報告は同じディレクトリの `report.md` にある。まずそれを読むこと。変更は `git -C /Users/tecogonaz/src/Benitoite-C1 show 9344b17` で見られる。

## 読むもの

- `formal/Benitoite/Surface/` の `Syntax.lean`・`Typing.lean`・`WellFormed.lean`・`Desugar.lean`・`Examples.lean`（C4a-2 で足した部分を中心に）と、`Lemmas/` の変更（`Calls.lean`・`Typing.lean` の `HasClauses.desugar`・`Program.lean`）。
- `formal/Benitoite/Release/` の `Syntax.lean`・`Typing.lean`（`C_Handle`・`C_Resume`・`V_Op`・`V_Var`・`HasTypeClauses`・`Clause`・`handled`・`opSig`・`effOps`）・`Assumptions.lean`（`EffectsOk`）・`WellFormed.lean`・`Subst.lean`。
- 01-12「ハンドラ」（表層の脱糖の表、C-Handle・C-Resume）と「型の情報を付けた表層の構文と型付け」。01-07「利用者が定義するエフェクトとハンドラ（初回リリース版）」。01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」「式と文の型」「必ず抜ける文」。
- 処理系の脱糖（`crates/benitoite/src/ir/desugar/effects.rs` の `handle`・`resume`、`ir/desugar/exprs.rs` の `direct_name`）は照合が要る箇所だけ。

## 観点

1. 脱糖の各場合が、01-12 の表の行と処理系の脱糖に一致するか。特に、節の引数と継続の変数の番号、入れ子の節での `resume` の番号、操作の型引数、組み込みの操作の節。
2. 表層の型付けの規則が 01-06・01-07・01-12 を表すか。余計な制限や緩和。特に、`E_Op` の前提（`Release` の `V_Op` が求めるものと比べて、型引数の条件の不足がないか）、`E_Handle` のエフェクトの条件、節の型パラメータの制約、`resume` のエフェクト、表の条件の振り分け（`WellFormed` と `WellTyped`）。
3. 構文が許すのに脱糖の場合や型付けの規則がない要素、またはその逆。01-02 で構文の誤りになる形を表層の構文が表せてしまうか（それが性質 1 を偽にするか）。
4. このままの定義で、性質 1 が偽になる反例が見えるか（前提の不足を含む）。特に、残った `sorry`（節の本体）が、`EnvClean` を広げれば証明できる見込みか。見えるなら原因を、01-12 の規則の誤り／書き写しの誤り／表現の都合に分ける。
5. 後の作業 C4c-2（差分テストの拡張）で、処理系の出力と比べるときに正規化や除外が要りそうな違い（`report.md` の 7 の申し送りの妥当性を含む）。
6. 後の段階（C4b-2 の `EnvClean` の拡張、C5 の型クラス、とくに ADR 0312 の制限（操作の型パラメータの型クラスの制約）を外した版を C5 の後に試すこと、C7 のパターンの拡張）を足すときの妨げ。

## 出力の形

指摘ごとに次を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。

- 重さ: 高（定理が偽になる、または 01-12・01-06・01-07 と意味が違う）／中（証明で問題になる、後の段階の妨げ）／低（表記・コメント）
- 場所: ファイルと行
- 問題
- 原因の分類: 01-12 の規則の誤り／書き写しの誤り／表現の都合／その他
- 直し方の案

回答は日本語で書く。
