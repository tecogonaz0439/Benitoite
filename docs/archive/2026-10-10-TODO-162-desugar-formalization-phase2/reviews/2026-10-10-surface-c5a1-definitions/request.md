# 依頼: 脱糖の形式化の段階 C5a-1 の定義のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

フェーズ 1（段階 C1〜C3）と段階 C4 で、型の情報を付けた表層の構文・表層の型付け・脱糖を `formal/Benitoite/Surface/` に定め、01-12「表層からの脱糖」（基本の言語）と、`try`・`with`・`lazy`・ハンドラ・`resume`・利用者の操作について性質 1（`desugar_typed`）と `surface_effect_soundness` を証明した。段階 C5 は型クラスを足す。C5a-1（コミット f5d0ccc）で、辞書の根拠（`DictEv`）、制約を持つ関数の辞書の引数（`FunDecl.dictParams`）、制約を持つ関数とメソッドを値として使う形（`funDicts`・`methName`、ラムダに脱糖）、型クラスと実装の表（実装のメソッドの本体と表層の D-Impl を含む）を足した。呼び出しの組み立て（`directCallee`・`callComp`）は変えておらず、制約を持つ関数とメソッドの直接の呼び出しを処理系と同じ形にするのは後の C5a-2 である。定理の言明は変えず、値として使う二つのラムダの型保存と、実装の表の型保存（D-Impl）の 3 か所が `sorry` である（後半の C5b-1 で証明する）。計画は `docs/2026-10-10-TODO-162-desugar-formalization-phase2/`（`plan.md` の C5、`study.md` の C5、`decisions.md` の P3・P4・P6・P7・P9）にある。

実装担当に事前に与えた決まり（妥当性もレビューの対象とする）:

- 辞書の根拠は計算を作らずに `Release.Val`（`.dict`・`.var`・`.super`）へ直接移す。受け取った辞書は環境 Γ の普通の位置に置き（P6）、`DictEv.local j` は `Γ[j]? = some (some (.dict cl τ))` を前提にする。
- `Release.Def` は辞書の欄を持たないので、表層の `FunDecl` に `dictParams` を持たせ、脱糖は `params := dictTys ++ params` を出す。本体の環境は `binds (dictTys ++ params)`。既存の `E_Fun` は `dictParams = []` の関数に限る。
- メソッドを値として使う形は `return λ(ȳ:Ā). V.m[S̄; Ē](Ū, ȳ)` で、Ū の値を `Comp.meth` の引数の前に置く。θ は `Ty.subst (ss ++ [τ]) es`。`MethSig` は自身の制約の辞書の個数を持たないので、表層の型付けは `us.length` で `ms.params.map θ` を前後に分ける（表層の型付けが広くなる）。
- 実装の定義の表層の型付けは `Release.ImplDecl.WellTyped` の写しで、メソッドの本体は `.tail` で脱糖する。
- 高カインドの型のために構文や型付けを狭めない。
- 処理系との表し方の違い（上位の型クラスの指し方、辞書の別の欄、型パラメータの番号の並び）は、後の差分テストの書き出しで取る。

実装担当の完了の報告は同じディレクトリの `report.md` にある。まずそれを読むこと。変更は `git -C /Users/tecogonaz/src/Benitoite-C1 show f5d0ccc` で見られる。

## 読むもの

- `formal/Benitoite/Surface/` の `Syntax.lean`・`Typing.lean`・`WellFormed.lean`・`Desugar.lean`・`Examples.lean`（C5a-1 で足した部分を中心に）と、`Lemmas/` の変更（`Invariants.lean`・`Typing.lean`・`Program.lean`・`Scoped.lean`）。
- `formal/Benitoite/Release/` の `Syntax.lean`（`Def`・`MethSig`・`ClassDecl`・`ImplDecl`）・`Typing.lean`（`V_Fun`・`V_Dict`・`V_Super`・`C_Meth`・`ImplDecl.WellTyped`・`Program.WellTyped`）・`WellFormed.lean`（`ClassDecl.Scoped`・`ImplDecl.Scoped`）・`Subst.lean`。
- 01-12「型クラス」（V-Dict・V-Super・C-Meth・D-Impl、辞書の決め方の文、表層の脱糖の表）と「型の情報を付けた表層の構文と型付け」。01-06「型クラス（初回リリース版）」。
- 処理系の脱糖（`crates/benitoite/src/ir/desugar/dicts.rs`・`exprs.rs` の `name_expr`・`prepare`・`decls.rs` の `implementation`）は照合が要る箇所だけ。

## 観点

1. 脱糖の各場合が、01-12 の表の行と処理系の脱糖に一致するか。特に、値として使う形のラムダの中で辞書の値の番号をずらすこと、`Comp.meth` の引数の並び（Ū と値の引数）、制約を持つ関数の定義の `params`、実装のメソッドの本体と上位の型クラスの辞書。
2. 表層の型付けの規則が 01-06・01-12 を表すか。余計な制限や緩和。特に、`DictEv` の型付け（`V_Dict` の制約の検査、`V_Super` の上位の型クラス）、`E_FunDicts`・`E_MethName` の型（値の引数だけの関数の型）と前提、`us.length` で分けることの広さ、実装の定義の型付け（宣言との対応、環境と制約の並び、`Exits ∨ ret = Unit`）、表の条件の振り分け（`WellFormed` と `WellTyped`）。
3. 構文が許すのに脱糖の場合や型付けの規則がない要素、またはその逆。01-02・01-06 で誤りになる形を表層の構文が表せてしまうか（それが性質 1 を偽にするか）。
4. このままの定義で、性質 1 が偽になる反例が見えるか（前提の不足を含む）。特に、残った 3 か所の `sorry` が証明できる見込みか（`report.md` の 7 の見込みの妥当性）。見えるなら原因を、01-12 の規則の誤り／書き写しの誤り／表現の都合に分ける。
5. 後の作業（C5a-2 の呼び出しの頭の形、C5c の差分テストの拡張、高カインドの型の例）を足すときの妨げ。特に、`funDicts`・`methName` が値の引数の型の注釈を構文に持つことと、C5a-2 で直接の呼び出しにするときの形の整合。
6. ADR 0312 の制限（操作の型パラメータに型クラスの制約を書けない）を外した版を C5 の後に試すこと（`plan.md` の C5 の追加の作業）への妨げと、この定義でその抜けを見つけられる見込み。

## 出力の形

指摘ごとに次を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。

- 重さ: 高（定理が偽になる、または 01-12・01-06 と意味が違う）／中（証明で問題になる、後の段階の妨げ）／低（表記・コメント）
- 場所: ファイルと行
- 問題
- 原因の分類: 01-12 の規則の誤り／書き写しの誤り／表現の都合／その他
- 直し方の案

回答は日本語で書く。
