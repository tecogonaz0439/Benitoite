# 依頼: 形式検証の段階 B2 の、証明を終えた後の定義と言明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

関数型スクリプト言語 Benitoite の設計書の「コア計算と脱糖」（01-12）の規則を Lean 4 で書き写し、進行と保存・エフェクトの健全性を証明している（形式検証の段階 2）。段階 B2（`Map`・`Set`・`Bytes`、型クラスの辞書と高カインド型）の定義と定理の言明は、前回あなたにレビューしてもらった（資料 1 に指摘と対応）。その後、証明を書き上げ、`Theorems.lean` の四つの定理（`step_sound`・`progress`・`preservation`・`effect_soundness`）は `sorry` なしで通った。公理は `propext`・`Classical.choice`・`Quot.sound` だけで、`lake build` に警告はない。

証明の作業では、前回のレビューへの対応（資料 1）のほかに、定義と言明を変えていない。組み込みの関数についての仮定（`Builtins.Assumptions`）も段階 B1 から変えていない。

段階 B1 の同じ時点のレビューでは、仮定どうしが矛盾していて定理が空虚に成り立つ、という誤りが見つかった。今回もその種類の誤りがないかを特に見てほしい。証明の本体は Lean が検査したのでレビューしない。

## 見てほしいこと

1. 前回の指摘への対応（資料 1 の `response.md` の 3 件）が正しく、新しい問題を持ち込んでいないか。特に、辞書の引数の型を `(ClassName × Nat)` の組で表したこと（`ImplDecl.dictParams`・`ImplDecl.dictTys`）と、`ImplDecl.WellTyped` に加えた域の一致の条件（`isSome` の等式）。
2. 定理の前提（`Program.WellFormed`・`Program.WellTyped`・`Program.EffectsOk`・`Builtins.Assumptions`）が、型クラスを使う実際のプログラムで満たせるか。前提が満たせないか、型クラスの実装を持つプログラムでは満たせない（定理が型クラスについて空虚になる）ことはないか。資料 3 の `Examples.lean` の型クラスの例（`Semigroup`・`Monoid`・`SemigroupBox`）は、前提を満たすはずのプログラムとして書いた。満たさない箇所があれば示す。
3. 定理の言明（資料 3 の `Theorems.lean`）が 01-12 の性質を弱めていないか。`progress` に加えた前提 `P.WellTyped B` が妥当か。
4. 07-04 の記述（資料 2）が、形式化の定義と一致しているか。
5. そのほか、定理が空虚に成り立つ、または 01-12 と意味が違う原因が見えるか。

必要な資料はすべてこの依頼に含めた。リポジトリのファイルを読む必要はない。どうしても確かめたいことがあるときだけ、読む範囲を行で絞って読むこと。

## 出力の形

指摘ごとに次を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。

- 重さ: 高（定理が空虚、または 01-12 の性質より弱い、または 01-12 と意味が違う）／中（誤解を招く）／低（表記・説明）
- 場所: ファイルと行（01-12 の場合は規則名）
- 問題
- 原因の分類: 01-12 の規則の誤り／書き写しの誤り／表現の都合／その他
- 直し方の案

回答は日本語で書く。

## 資料 1: 前回のレビューの指摘と対応

### report.md

1. **重さ: 高 — `progress` に、メソッドと上位の辞書の存在を保証する前提がない。**

   **場所:** `formal/Benitoite/Release/Theorems.lean` の `progress`（提示資料に行番号なし）、`Typing.lean` 273–279 行・341–345 行・387–397 行、`Semantics.lean` 90–96 行・116–126 行。

   **問題:** B2 の `progress` は、この言明のままでは偽である。`V_Dict` は実装の宣言が存在することだけを使い、その実装が `D-Impl` を満たすことを要求しない。一方、`E_Meth` には呼ぶメソッドの本体の存在、`E_Super` には取り出す上位の辞書の存在が必要である。これらを保証する `P.WellTyped B` が、`progress` の前提にない。

   例えば、次のプログラムで反例になる。

   ```text
   型クラス C[P]:
     m() : P ! {}

   実装 I:
     型パラメータなし、辞書の引数なし、対象 Integer、型クラス C
     methods はすべて none
   ```

   `I[]()` は `V_Dict` により `Dict[C, Integer]` 型を持ち、`I[]().m[;]()` は `C_Meth` により `Integer ! {}` 型を持つ。したがって、空の継続と空のストアを持つ状態に `StateTy` が成り立つ。しかし、メソッドの本体がないため `E_Meth` を使えず、辞書が `↑` の形でもないため `E_Super` も使えない。最終状態でもない。

   同様に、宣言上は上位の型クラスを持つ実装で、対応する `id.supers s` を `none` にすれば、上位の辞書を使うメソッド呼び出しが停止する。どちらの反例も `Program.WellFormed` だけでは排除できない。

   **原因の分類:** その他（B2 に広げた定理の前提の不足）。

   **直し方の案:** `progress` に `hwt : P.WellTyped B` を加える。01-12 の性質 2 が型の付いた定義の集まり Σ を前提とすることにも合う。進行に必要な条件だけを分離するなら、実装が属する型クラスの各メソッドと各上位の辞書の存在を保証する条件でも足りるが、現状の `Program.WellTyped` を使う方が対応は明確である。`Builtins.Assumptions` に追加する条件ではない。

2. **重さ: 高 — 実装の辞書の引数に、辞書以外の値を渡せる。**

   **場所:** `formal/Benitoite/Release/Syntax.lean` 274–280 行、`Typing.lean` 273–276 行・387–394 行。01-12 の実装の定義の構文、V-Dict、D-Impl。

   **問題:** 01-12 の実装の引数 `d̄` は、実装の型パラメータの制約に対応する `Dict[Cl', β']` 型の辞書である。Lean では `dictParams : List Ty` に任意の型を書け、`ImplDecl.WellTyped` もその形を検査しない。このため、対応表に記されていない型付けの緩和がある。

   例えば、型クラス `C[P]` が `m() : P ! {}` を持つとき、次の形の実装が Lean では受け入れられる。

   ```text
   impl I[](x : Integer) : Dict[C, Integer] = {
     m = return x
   }
   ```

   `dictParams := [Integer]`、メソッドの本体を `.ret (.var 0)` とすれば、`ImplDecl.WellTyped` と `ImplDecl.Scoped` が成り立つ。`I[](7).m[;]()` も型が付き、7 を返す。しかし、01-12 の実装の構文では `Integer` 型の引数をこの位置に書けない。

   この緩和による進行・保存の反例は見えないが、01-12 の実装の定義の写しにはなっていない。「高カインド型の種類を検査しない」という対応表の説明では、この違いを説明できない。

   **原因の分類:** 書き写しの誤り。

   **直し方の案:** `dictParams` を制約の辞書だけで表す構造にするか、`ImplDecl.WellTyped` に各要素が `Dict[Cl', β']` の形である条件を加える。01-12 の記法どおりに制約の対象を実装の型パラメータに限るなら、型クラスの名前と型パラメータの番号の組で表し、番号の範囲も検査できる。

3. **重さ: 中 — 実装のメソッドと上位の辞書について、宣言と定義の域の一致が条件になっていない。**

   **場所:** `formal/Benitoite/Release/Typing.lean` 387–394 行、`WellFormed.lean` 125–130 行。01-12 の D-Impl、資料 2 の「型クラスの実装」。

   **問題:** `ImplDecl.WellTyped` は、型クラスが宣言したメソッドと上位の型クラスについて、対応する定義の存在と型付けを検査する。一方、実装側に宣言のないメソッドや上位の辞書があっても受け入れる。

   特に、宣言のないメソッドの本体は、`ImplDecl.Scoped` の 129–130 行の条件の対象にもならない。したがって、その本体に範囲外の型の変数やエフェクト変数があっても、`Program.WellFormed` が成り立つ。資料 3 の「実装の定義のメソッドの本体についても、宣言した変数に限られることを言明する」という説明と、格納された本体全体の扱いが一致していない。

   型の付いたメソッド呼び出しは型クラスの宣言を引くので、余分なメソッドをこの方法で呼ぶことはできない。そのため、これだけで進行・保存が偽になる反例ではない。ただし、余分な欄を実装の定義の一部として扱うのか、形式化上の無視される欄として扱うのかが未記載である。

   **原因の分類:** 表現の都合（関数で表した定義の域の扱いが未記載）。

   **直し方の案:** 実装のメソッドの域が型クラスのメソッドの域と一致し、上位の辞書の域が `cd.supers` と一致する条件を加える。その条件があれば、現在の `ImplDecl.Scoped` のメソッド本体の検査も全本体を対象とする。余分な欄を無視する表現を採る場合は、対応表にその解釈を記し、「実装の定義」「全本体」の範囲もそれに合わせて限定する。

問題なし — メソッドの型の番号付けと `ImplDecl.methTy` は整合している。メソッドの型パラメータが `0..g-1`、型クラスの引数 P が g であり、`substAt g [id.target] []` は P を置き換え、実装の型パラメータを g だけずらす。

問題なし — E-Meth の型の置き換え `ss ++ ts` と値の置き換え `vs ++ ws` は、D-Impl の環境と一致している。`binds` と `instantiate` がともに並びを逆順に扱うため、番号 0 は最後のメソッド引数を指し、その外側に実装の辞書の引数が並ぶ。関数の境界の `markPush` も、01-12 の読み替えに一致している。

問題なし — E-Super の一歩の取り出しと、外側の `↑` を残す再帰は、ADR 0305 後の規則に一致している。`P.WellTyped B` のもとでは、D-Impl が取り出す上位の辞書の存在と型を保証する。辞書の参照が循環する場合も、一歩の遷移が存在するため、非停止性だけを理由に進行は破れない。

問題なし — `Ty.applyTo` の既定の値について、提示された定義から置き換え・ずらしとの可換性を破る反例は見えない。通常の型の外側の形はこれらの操作で変わらず、`tapp` の置き換え結果も `tvar` や `ctor` そのものにはならない。`TyCon.apply` が不足する引数を `Unit` で補い、余分な引数を無視する処理も、この可換性を妨げない。型の種類を検査しない緩和は対応表に記載されており、この緩和だけによる進行・保存の反例は見えない。

問題なし — V-Map・V-Set の並びの長さ、鍵の制約、型の変数の範囲の条件、および V-Bytes は、記載された表現の違いの範囲で規則に対応している。鍵の順序と重複の条件を外す緩和も、対応表で明示されている。

問題なし — 辞書・マップ・集合・バイト列・`tapp`・`ctor` の網羅性を「どの値も属する」とする定義は、型の付いた値に対する網羅性を保証するための強い条件である。辞書を構成子パターンだけで照合できるような緩和にはなっていない。

問題なし — B2 の値と計算に対する `VarsIn`、型と値の置き換え、変数の番号の変更は、追加された各構成を再帰的に処理している。辞書の引数も `HasTypeVs` で検査されるため、継続の変数を辞書に包むだけで V-Var の制限や `hideConts` を回避する反例は見えない。

問題なし — `preservation` と `effect_soundness` の言明は、B2 のために結論を弱めていない。エフェクトの健全性は、到達した各状態からのすべての事象付き遷移と、未処理の利用者の操作を排除する形を保っている。型の種類を検査しない緩和や、追加されたコレクション・辞書によって、この二つの言明が偽になる反例は見えない。

問題なし — `Builtins.Assumptions` と `Program.EffectsOk` に、資料 3 にない B2 固有の仮定は追加されていない。辞書の実行はプログラムの定義で定まり、コレクションを返す δ と IO の応答は既存の型の保存の仮定で扱えるため、B2 固有の組み込みの仮定を追加する必要は見えない。指摘 1 の修正は、プログラムの型付けの前提を `progress` に加えることで行える。

問題なし — 提示された 01-12 の型クラスとコレクションの規則について、ADR 0305 以外に、規則そのものが進行・保存を破る具体的な反例は見えない。
### response.md

# レビューへの対応

GPT-6.1-Sol（effort `medium`）に依頼した（`request.md`、回答は `report.md`）。消費したトークンは 99,662。

| # | 指摘 | 対応 |
|---|---|---|
| 1 | `progress` の前提に `P.WellTyped B` がなく、メソッドの本体や上位の型クラスの辞書を持たない実装で進行が偽になる | `progress` に前提 `hwt : P.WellTyped B` を加えた。段階 B1 では要らなかったので外していたが、段階 B2 では E-Meth・E-Super の遷移があることを D-Impl から導く。01-12 の性質 2 も、型の付いた Σ を前提とする |
| 2 | 実装の辞書の引数の型に、辞書の型以外の任意の型を書ける（書き写しの誤り） | 辞書の引数の型を、型クラスと実装の型パラメータの番号の組（`ImplDecl.dictParams : List (ClassName × Nat)`）で表し、型は `ImplDecl.dictTys` で `Dict[Cl', β']` にする。`ImplDecl.Scoped` は番号の範囲を確かめる |
| 3 | 実装の定義に、型クラスが宣言していないメソッドや上位の型クラスの辞書があっても受け入れる | `ImplDecl.WellTyped`（D-Impl）に、実装のメソッドと上位の辞書の域が、型クラスの宣言のメソッドと上位の型クラスに一致することを加えた（01-06 の「宣言にないメソッドは定義できない」）。07-04 の対応表に記した |

01-12 の規則の誤りの指摘はなかった。定義を書く過程で見つけた E-Super の誤り（ADR 0305）について、レビューは、遷移に改めた規則が進行を保つことを確かめた。

## 資料 2: 07-04 の抜粋（進め方の段階 B2 の記述、仮定、対応表）と ADR 0305

```markdown
### 進め方

【決定】段階 2 は、初回リリース版の実装と並行して、次の段で進める。段階 2 の完了は、初回リリース版の完了条件に含めない（ADR 0293）。段階 B は、制御の構成を扱う段階 B1 と、型の構成を扱う段階 B2 に分ける（[ADR 0298](../../../../../formal/reviews/decisions/0298-split-stage-b-into-control-and-types.md)）。

| 段 | 対象 | 証明する定理 |
|---|---|---|
| 段階 A | 01-12 の「構文」「型付け規則」「実行の規則」（最小実行版の範囲） | 性質 2 と性質 3 の、同章に書かれた最小実行版の形 |
| 段階 B1 | 段階 A に、01-12 の「初回リリース版の拡張」のうち、型パラメータの組み込みの制約、基本型 `Byte`・`Decimal` と中身を見せない型、ストア（可変のセルと明示遅延）、関数の境界と `escape`、解放の枠と実行時エラーの継続（`with`）、プロセスの終了、エフェクトの名前と開始状態、ハンドラ（型パラメータを持つ操作を含む）を加える | 性質 2 と性質 3 の、同章が示す初回リリース版の読み替えの形 |
| 段階 B2 | 段階 B1 に、`Map`・`Set`・`Bytes` と鍵の型、型クラスの辞書（高カインド型を含む）を加える | 同上 |

段階 B1 は、段階 A の定義と証明を写して広げ、別の名前空間（`formal/` の `Benitoite.Release`）に置く。段階 A の定義と証明は、最小実行版のものとして残す。段階 B2 は、段階 B1 の定義と証明を同じ名前空間で広げる。

段階 A と段階 B は、それぞれの対象の定理に証明を省いた箇所（`sorry`）が残らず、仮定が次節の「形式化で仮定するもの」に挙げたものだけになったときに完了とする（[ADR 0294](../../../../../formal/reviews/decisions/0294-lean-4-for-formal-verification.md)）。

段階 A は 2026-09-30 に完了した。性質 2・3 と、遷移を計算する関数と遷移の関係の一致を証明した。定理が使う公理は、Lean の標準の `propext` と `Quot.sound` だけである。定義と定理の言明は、証明の前に Codex のレビューを経た（[ADR 0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md)）。

段階 B1 は 2026-09-30 に完了した。性質 2・3 と、遷移を計算する関数が返す遷移が関係の遷移であること（健全性）を証明した。定理が使う公理は、Lean の標準の `propext`・`Classical.choice`・`Quot.sound` だけである。定義と定理の言明は、証明の前に Codex のレビューを経た（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)、[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）。証明の作業では、01-12 の規則の誤りを二つ見つけて直し（[ADR 0301](../../../../../formal/reviews/decisions/0301-subsumption-on-continuation-input.md)、[ADR 0302](../../../../../formal/reviews/decisions/0302-k-handle-clause-effect-within-below.md)）、型の変数の表し方と型の正しさの前提を改めた（次節の対応の表）。証明の後の Codex のレビューで、仮定どうしの矛盾（型引数の個数を問わないストアの操作の制約）と、01-12 の継続の型の書ける範囲の抜けを指摘され、仮定を直し、01-12 を直した（[ADR 0303](../../../../../formal/reviews/decisions/0303-no-continuation-types-in-terms.md)）。仮定が矛盾しないことは、仮定を満たす組み込みの関数の例（`formal/` の `Model.lean`）で確かめる。

段階 B2 は 2026-09-30 に完了した。段階 B1 の定理を、`Map`・`Set`・`Bytes` と型クラスの辞書（高カインド型を含む）を加えた定義について証明した。定理が使う公理は、段階 B1 と同じである。定義と定理の言明は、証明の前に Codex のレビューを経た。定義を書く過程で、01-12 の E-Super の誤りを見つけて直した（[ADR 0305](../../../../../formal/reviews/decisions/0305-e-super-as-transition-at-method-call.md)）。進行の定理は、段階 B1 と違い、プログラムに型が付くことを前提に持つ。実装の定義がメソッドの本体と上位の型クラスの辞書を持つことを、D-Impl から導くためである。組み込みの関数についての仮定は加えていない。

### 形式化で仮定するもの

【方針】01-12 は、組み込みの関数の型と値（関数 δ）と IO の応答を、ほかの章に委ねている。形式化では、これらの中身を定義せず、次の性質を定理の仮定として与える。Lean の `axiom` としては置かず、定理の引数（`formal/` の `Builtins.Assumptions`）として明示する。

| 仮定 | 内容 | 01-12 の根拠 |
|---|---|---|
| δ の型の保存 | 型 `(Ā) → B ! ε` の IO を行わない組み込みの関数 `b[T̄; Ē]` に、置き換えた型 `Āθ` の値を渡すと、`δ(b[T̄; Ē], W̄)` は定義されていて、型 `Bθ` の値か `error(r)` を返す（θ = [T̄/ᾱ, Ē/ρ̄]。[ADR 0296](../../../../../formal/reviews/decisions/0296-delta-receives-type-arguments.md)） | 「実行の規則」の E-Prim・E-Err |
| IO の応答の型 | 型 `(Ā) → B ! ε` の IO を行う組み込みの関数 `b[T̄; Ē]` に型 `Āθ` の値を渡したときの応答は、型 `Bθ` の値か `error(r)` である | 「確かめる性質」の性質 2 の「IO の応答は、関数の戻り値の型の値であるとする」 |
| IO の応答の存在 | IO を行う組み込みの関数 `b[T̄; Ē]` に型 `Āθ` の値を渡すと、起こりうる応答が少なくとも一つある | E-IO・E-IOErr で遷移できること（性質 2 の進行） |
| 組み込みの関数のエフェクト | IO を行う組み込みの関数の型のエフェクトは、組み込みのエフェクトの名前（最小実行版では `IO`）を含む | 性質 3 が IO の事象の不在を型から導くための前提 |
| 組み込みの関数の型の変数 | 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う | 01-12 は名前の束縛として暗黙に前提する |
| 制約の保存 | 型パラメータの制約（V-Prim の「T̄ が b の型パラメータの制約を満たす」）を満たす型は、型とエフェクトの置き換えの後も制約を満たす | E-Fun の置き換えの後も V-Prim が成り立つための前提 |

「組み込みの関数のエフェクト」は、01-12 に明文の規則がなく、[エフェクト](../../../../../formal/reviews/01-spec/01-07-effects.md)が組み込みの関数ごとに与えるエフェクトから読み取れる性質である。「制約の保存」は、最小実行版では制約が演算子の型の集まりと等値の型に限られ、型パラメータが制約を満たさないので成り立つ。

【方針】段階 B1 では、上の表の仮定を初回リリース版の組み込みの関数に広げ、次の仮定を加える。

| 仮定 | 内容 | 01-12 の根拠 |
|---|---|---|
| 制約の保存（広げたもの） | 制約の並びの内側 C1 を残し、外側 C0 を、C0 の制約を満たす閉じた型で置き換えても、組み込みの関数の制約と組み込みの制約（等値の型・鍵の型）は満たされる。C1 の型の変数だけを使う型が制約を満たせば、外側に並びを加えても満たす。組み込みの関数の制約を満たす型引数は、その関数の型パラメータの組み込みの制約も満たす | E-Fun・E-Op の置き換えの後も V-Prim・V-Fun が成り立つための前提（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)） |
| δ と IO の応答の値 | δ と IO の応答が返す値は、型の変数を含まない | 実行中の項が型の変数を含まないことを保つための前提 |
| IO の応答の種類 | IO を行う組み込みの関数の応答は値か `error(r)`、プロセスの終了の関数の応答は `exit(n)` か `error(r)` である | 「プロセスの終了」の「E-Exit は、b が終了状態を指定したプロセスの終了の関数のときに使い、この関数には E-IO を使わない」 |
| 組み込みのエフェクトの操作 | IO を行う組み込みの関数とプロセスの終了の関数は、組み込みのエフェクト L の操作であり、型のエフェクトは `{L}` だけで、エフェクト変数を持たない。組み込みのエフェクトの操作の一覧の関数は、そのエフェクトの操作である。`State` は操作を持たない組み込みのエフェクトである | 「ハンドラ」の「組み込みのエフェクトの操作は、外部に作用する操作を行う組み込みの関数 b である」「State は操作を持たず」 |
| ストアの操作の型 | `Reference.new`・`get`・`set`・`update` と `Lazy.force` の型は、01-07 と 01-06 が定める形であり、個数の合う型引数ならどれも受け入れる | 「ストア」の箇条 |
| 解放の応答の存在 | リソースの型の値の解放の事象には、起こりうる応答が少なくとも一つある | E-Release・E-RelErr で遷移できること（性質 2 の進行） |

次の二つは、仮定ではなく定理の前提として言明する。

- プログラムの定義の集まり Σ に型が付くこと（すべての定義が 01-12 の「定義」の型付けを満たすこと。段階 B2 では、すべての実装の定義が D-Impl を満たすことを含む）。
- 各定義の中の型パラメータとエフェクト変数が、その定義が宣言したものに限られること、構成子の引数の型の中の型パラメータが、代数的データ型が宣言したものに限られること。01-12 は名前の束縛として暗黙に前提するが、形式化では変数を番号で表すので、別に言明する。段階 B1 では、定義の型（引数、戻り値、エフェクト）と本体、操作の宣言の型について言明する。本体の範囲は、E-Fun の後の状態が型の変数を含まないことに要る。段階 B2 では、型クラスのメソッドの型と、実装の定義（辞書の引数の型、対象、上位の型クラスの辞書、メソッドの本体）についても言明する。
- 段階 B1 では、エフェクトの宣言が操作の宣言と合っていること、利用者が宣言したエフェクトの名前が組み込みのエフェクトの名前と重ならないこと。

### 道具と置き場所

【決定】証明支援系には Lean 4 を使う。形式化は、リポジトリの根の `formal/` に Lake のプロジェクトとして置き、処理系の Cargo のワークスペースには含めない。Lean の版は `lean-toolchain` で固定する。検査は `lake build` で行い、完了条件の共通の検査（`scripts/check.sh`）には含めない。外部のライブラリには初めは依存せず、依存を加えるときは ADR に記録する（[ADR 0294](../../../../../formal/reviews/decisions/0294-lean-4-for-formal-verification.md)）。

【方針】抽象機械の遷移は、関係として定義するとともに、一歩の遷移を計算する関数としても定義し、両者が一致することを証明する。関数の形は、小さなコア計算のプログラムを Lean の中で実行し、01-12 の規則の書き写しの誤りを証明の前に見つけるために使う。段階 B1 の関数は、新しい場所と応答の選び方を固定するので、型が付いた状態について、関数が返す遷移が関係の遷移であること（健全性）だけを証明する。

### 01-12 との対応

【決定】01-12 を正とし、Lean の定義は 01-12 の規則の写しとする。食い違ったときは Lean の定義を 01-12 に合わせる。01-12 の規則の誤りと判断したときは、ADR を添えて 01-12 を直してから Lean の定義を合わせる（[ADR 0295](../../../../../formal/reviews/decisions/0295-core-calculus-chapter-normative-over-formalization.md)）。

【決定】Lean の定義の名前は、01-12 の規則の名前に対応させる（規則 `E-Op` の遷移は構成子 `E_Op`、規則 `C-Sub` の計算の型付けは構成子 `C_Sub`、規則 `K-Handle` の継続の型付けは構成子 `K_Handle` とする）。01-12 の節と形式化の対応は、次の表で管理する。形式化のために 01-12 と違う形で書いた箇所は、「表現の違い」の欄にその内容と理由を記す。

| 01-12 の節 | 段 | 表現の違い |
|---|---|---|
| 構文 | 段階 A | 項の変数は de Bruijn の番号で表す（`λ(x1, …, xn). M` の本体では番号 0 が xn）。型パラメータとエフェクト変数は、宣言した関数の中での番号で表す。エフェクトの集合は、エフェクトの原子から真偽値への関数で表す（並びの違いを型の等しさに持ち込まないため）。定数は Lean の値で表し、`type(c)` を関数として定める。`IOError` の値は番号で区別する。エフェクトの集合を関数で表すので、01-12 にない無限集合も表せる。このため形式化の型付けは 01-12 より広い（01-12 の型付けの導出は、どれも形式化の型付けの導出になる）。広い型付けについて証明した性質 2・3 は、01-12 の型付けについても成り立つ |
| 型付け規則（値、計算、パターン、定義） | 段階 A | Γ は型の並びで、先頭が番号 0 の変数の型である。P-Con の「変数はすべて異なる」は、変数を番号で表すので要らない。C-Match の網羅性は、01-05 の検査の手順ではなく、「型 A の値の形をしたどの値にも照合する分岐がある」こととして定める。値の形の集合は、型の付いた閉じた値の集合より広く、関数の型と型パラメータにはどの値も、構成子の値には型引数によらず属する。広い集合について網羅的なら、型の付いた値についても網羅的である（01-05 の検査がこの性質を満たすことは対象外）。組み込みの関数の型と制約は、前述の仮定の欄として与える |
| 実行の規則 | 段階 A | `S → S'` と `S —ℓ→ S'` を、IO の事象の有無をラベルに持つ一つの関係で表す。E-Prim・E-Err と E-IO・E-IOErr のどちらを使うかは、組み込みの関数ごとに IO を行うかの印で決める。E-Lam と E-Fun の「引数の並びと束縛する変数の並びが対応する」ことは、01-12 では記法 `M[W̄/x̄]` が暗黙に前提するので、個数の一致を遷移の前提として明示する。遷移を計算する関数も定め、関係と一致することを一歩について定理として言明する。この関数が使う IO の応答の関数は、同じ入力に同じ応答を返すので、同じ呼び出しへの応答が途中で変わる遷移の列は再現できない。この関数は例の実行を調べる道具として使う |
| 末尾呼び出しの保証、置き換えてよい等式 | 対象外 | |
| 表層からの脱糖 | 対象外（性質 1） | |
| 初回リリース版の拡張: モジュール、トップレベルの定数、リストの展開、レコード、文字列補間 | 対象外（脱糖だけで表す） | |
| 初回リリース版の拡張: 型パラメータの組み込みの制約 | 段階 B1 | 型付けの判断は、型パラメータの制約の並び（型の変数の番号の順）を持つ。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、組み込みの関数の欄として与える |
| 初回リリース版の拡張: 基本型 `Byte`・`Decimal`、中身を見せない型 | 段階 B1 | 中身を見せない型は名前で表し、リソースの型かどうかを組み込みの関数の欄として与える |
| 初回リリース版の拡張: ストア | 段階 B1 | ストアは場所から中身への関数とし、有限であることはストアの型付けの条件にする。ストアの操作を行う組み込みの関数は、組み込みの関数の種類で区別し、その型は仮定として与える。`Reference.update` の遷移は、`Reference.get`・`Reference.set` の名前を組み込みの関数の欄として与えて書く |
| 初回リリース版の拡張: 関数の境界と `escape`、`with`、プロセスの終了 | 段階 B1 | 解放の事象の応答は、組み込みの関数の欄として与える。プロセスの終了の関数は組み込みの関数の種類の一つとし、その応答 `exit(n)` に E-Exit を使う。IO の事象は、型引数とエフェクト引数を含めない（応答の関係には渡す）。`escape`・実行時エラー・終了の状態が `drop` の枠を通るときの扱い（01-12「ハンドラ」の箇条）を、規則 E-EscDrop・E-EscDropRel・E-ErrDrop・E-ErrDropRel・E-ExitDrop・E-ExitDropRel として書く。E-EscLet・E-ErrPop・E-ExitPop は、枠の種類ごとの規則に分けて書く |
| 初回リリース版の拡張: エフェクトの名前と開始状態 | 段階 B1 | エフェクトの名前は、モジュールと名前の組を一つの文字列で表す。組み込みのエフェクトとその操作の一覧は、組み込みの関数の欄として与える |
| 初回リリース版の拡張: ハンドラ | 段階 B1 | 型の変数を内側から数えた番号（de Bruijn の番号）で表す。節は操作の型パラメータを番号 0 から順に束縛し、節の外側の型（環境の型、`handle` の式の型、R）の番号を、束縛した個数だけずらす（値が節の中へ入っても型を書き換えずに済むため）。実行中の項は型の変数を含まないので、E-Fun と E-Op の置き換えは閉じた型を入れる。V-Lam と `lazy` の検査で環境から継続の型の変数を除くことは、環境の要素を `none` に置き換えて表す（番号をずらさないため）。E-Op は節の本体に操作の型引数の置き換えを施す（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。継続の型の値を `resume` の第一引数に限る規則（[ADR 0300](../../../../../formal/reviews/decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）は、V-Var の前提と、`resume` の第一引数ごとの規則 C-Resume（節の変数）・C-ResumeL（継続の場所）で表す。組み込みの操作の E-Op は、規則 E-OpPrim として分けて書く。同じ操作の節が二つあるときは、最初の節を選ぶ |
| 確かめる性質（初回リリース版の読み替え） | 段階 B1 | ストアの型付けの「Ψ と σ の場所が一致する」と K-Drop の `State` の条件（ADR 0300）は、01-12 のとおりに書く。継続の末尾の R を `none` とする状態の型付けの条件（[ADR 0299](../../../../../formal/reviews/decisions/0299-state-continuation-ends-with-no-escape.md)）は、継続の型付けの末尾の R の添字で表す。状態の型付けに、状態の中の項が型の変数を含まないことを加える（01-12 は実行を `main` から始めるので暗黙に成り立つ）。継続の型付けに、継続の末尾での R を添字として加え、ストアの継続の型付けの「末尾の `handle` の枠に K-Handle を R_κ で使う」を表す。性質 3 の「IO の事象を伴う遷移をしない」は、解放の事象を含むすべての事象を伴わないこととして言明する（より強い形）。性質 3 の「M がエフェクト変数を含まない」に、型の変数を含まないことを加える（型パラメータのない環境で型が付くので暗黙に成り立つ）。性質 3 の `· ⊢c M` の R は `none` とする。項に現れない型を型付けが選べる規則（V-List の要素の型、C-Escape の型、分岐のない `match` の型、K-Empty・K-Mark・K-Handle の型）に、その型が束縛された型の変数だけを使う（型が正しい）ことを前提として加える（01-12 は暗黙に前提する。置き換えの補題に要る）。項の型は継続の型を含まない（継続の型は項に書けない） |
| 初回リリース版の拡張: `Map`・`Set`・`Bytes` | 段階 B2 | マップの値は、鍵の並びと値の並びの組で表し、V-Map に二つの並びの長さが等しいことを加える。バイト列の要素は、`Byte` の定数と同じく自然数で表す。V-Map・V-Set の「A は鍵の型である」は、組み込みの制約 `key` を満たすこととして、組み込みの関数の欄で判定する。マップと集合の値を鍵の順序で並べ、同じ鍵を含まないことは、型付けの条件にしない（型付けは 01-12 より広い）。V-Map・V-Set の鍵と値の型に、V-List と同じく、型が正しいことを前提として加える。網羅性の値の形では、マップ・集合・バイト列の型にどの値も属するとする |
| 初回リリース版の拡張: 型クラス | 段階 B2 | 型クラスのメソッドの型と実装の定義は、型の変数を番号で表す。メソッドの型では、メソッドの型パラメータが番号 0 から、型クラスの引数 P がその次の番号である。実装のメソッドの本体では、メソッドの型パラメータを内側に、実装の型パラメータを外側に並べ、値の変数は辞書の引数 d̄ の後にメソッドの引数 x̄ を並べる。実装の定義のメソッドの定義 D は、型パラメータと型を D-Impl が型クラスの宣言から決めるので、本体だけを持つ。辞書の引数 d̄ の型 `Dict[Cl', β']` は、型クラス Cl' と型パラメータ β' の番号の組で表す。D-Impl には、実装の定義が、型クラスが宣言したメソッドと上位の型クラスについてだけ本体と辞書を持つことを加える（01-06「型クラスの実装」の「宣言にないメソッドは定義できない」）。型構成子 φ は型の一つの形として表し、高カインドの型パラメータの型引数には、型構成子か高カインドの型パラメータを書く。型の置き換えで α[Ā] の α を型構成子に置き換えるときは、その型構成子を Ā に適用した型にする。型の種類（型パラメータが値の型か型構成子か、型構成子がとる型引数の個数）は検査しないので、形式化の型付けは 01-12 より広い。E-Super は、メソッドの呼び出しの辞書から `↑` を一段取り出す遷移として書く（[ADR 0305](../../../../../formal/reviews/decisions/0305-e-super-as-transition-at-method-call.md)）。網羅性の値の形では、辞書の型、α[Ā]、型構成子にどの値も属するとする |
| 初回リリース版の拡張: 末尾呼び出しの保証の読み替え | 対象外 | |
| 確かめる性質 | 性質 2・3 は段階 A・B。性質 1 は対象外 | |

段階 A の表現は、2026-09-30 に定義と定理の言明を書いた時点のものである。証明の作業で扱いにくいと分かれば改める（[OPEN-069](../../../../../formal/reviews/open-issues.md#open-069)）。

```

```markdown
# 0305. E-Super を、メソッドの呼び出しの辞書から上位の型クラスの辞書を取り出す遷移として定める

- 状態: 採択
- 日付: 2026-09-30
- 関連章: [コア計算と脱糖](../../../../../formal/reviews/01-spec/01-12-core-calculus.md)、[形式意味論と検証](../../../../../formal/reviews/07-quality/07-04-formal-semantics.md)
- 関連する未決事項: なし

## 背景

[コア計算と脱糖](../../../../../formal/reviews/01-spec/01-12-core-calculus.md)の「型クラス」は、E-Super を遷移ではなく値の等しさとして定めていた。`I[T̄](V̄)↑Sj` は、I の定義の Sj の辞書 Uj に置き換えを施した `Uj[T̄/β̄][V̄/d̄]` と同じ値である。E-Meth は、メソッドの呼び出しの辞書が実装の辞書 `I[T̄](V̄)` の形のときに使うので、`↑` を含む辞書でメソッドを呼ぶと、この等しさで実装の辞書に行き着いてから E-Meth を使う。

形式検証の段階 B2（[形式意味論と検証](../../../../../formal/reviews/07-quality/07-04-formal-semantics.md)）の定義を書く過程で、この等しさでは実装の辞書に行き着かない、型の付いたコア計算のプログラムがあると分かった。D-Impl は、上位の型クラスの辞書 Uj に型が付くことだけを求める。次の二つの実装の定義は、どちらも D-Impl を満たす（`Group` の上位の型クラスが `Monoid`、`Monoid` の上位の型クラスが `Semigroup` とする）。

```text
impl I[]() : Dict[Monoid, X] = { Semigroup = G[]()↑Monoid↑Semigroup; … }
impl G[]() : Dict[Group, X]  = { Monoid = I[](); … }
```

`I[]()↑Semigroup` は `G[]()↑Monoid↑Semigroup` と等しく、`G[]()↑Monoid` は `I[]()` と等しいので、元の `I[]()↑Semigroup` に戻る。この値と等しい値は、どれも `↑` を含み、実装の辞書の形にならない。したがって、`(I[]()↑Semigroup).combine(…)` は E-Meth を使えず、遷移できない。この状態は最終の状態でもないので、01-12 の性質 2（進行）が成り立たない。

脱糖はこのような辞書を作らない。脱糖は、上位の型クラスの辞書の型が具体的な型構成子なら、その実装の辞書を直接作り、`↑` を使うのは受け取った辞書の引数に対してだけである。しかし、性質 2 は型の付いたコア計算のプログラムについての性質であり、脱糖が作るプログラムに限っていない。

## 決定

1. E-Super を、メソッドの呼び出しの辞書 V から `↑` を一段取り出す遷移として定める。`I[T̄](V̄)↑Sj ⇝ Uj[T̄/β̄][V̄/d̄]` とし、`V ⇝ V'` のとき `V↑S ⇝ V'↑S` とする。`V ⇝ V'` のとき、`⟨V.m[S̄; Ē](W̄), K⟩ → ⟨V'.m[S̄; Ē](W̄), K⟩` である。
2. `↑` を含む辞書は、メソッドの呼び出しの辞書になるまで値のまま受け渡す。E-Meth は、これまでどおり実装の辞書の形の辞書に使う。
3. 型の付いた閉じた辞書は、実装の辞書か、型の付いた閉じた辞書に `↑` を付けたものである。したがって、メソッドの呼び出しは、E-Meth か E-Super のどちらかで遷移できる。背景の例では、E-Super の遷移が終わらない。

## 検討した代替案

- **値の等しさのまま、D-Impl に条件を加える**: 上位の型クラスの辞書 Uj の先頭を、実装の辞書か、辞書の引数に `↑` を重ねたものに限る。等しさで実装の辞書に行き着くことを示すには、加えて、上位の型クラスの関係が循環しないことと、実装の対象が型パラメータそのものでないことを、コア計算の条件にする必要がある。これらは[型システム](../../../../../formal/reviews/01-spec/01-06-type-system.md)が表層で検査する条件であり、コア計算の規則に写すと規則が大きくなる。
- **性質 2 を、脱糖が作るプログラムに限る**: 性質 2 の言明に、脱糖の像であることを加える必要があり、段階 2 で脱糖を形式化しない方針（[ADR 0293](0293-formal-verification-stage-2-alongside-first-release.md)）と合わない。

## 帰結

- 01-12 の「型クラス」の E-Super と、その説明の段落を改める。
- 処理系は変えない。VM の `SUPER` は、`↑` を一段取り出す命令であり（[バイトコード](../../../../../formal/reviews/02-impl/02-07-bytecode.md)）、遷移の数え方のほかは同じ働きをする。脱糖は背景の例のような辞書を作らないので、観測できる振る舞いは変わらない。
- 形式化（`formal/`）の段階 B2 は、この規則を写す。
```

## 資料 3: Lean の定義と定理（全文）

### formal/Benitoite/Release/Syntax.lean

```lean
     1	/-!
     2	# コア計算の構文（段階 B）
     3	
     4	設計書 01-12「コア計算と脱糖」の「初回リリース版の拡張」のうち、コア計算に構成を加えるものを書き写す。
     5	段階 B1 は、制御の構成（ストア、`escape`、`with`、プロセスの終了、エフェクトの名前、ハンドラ）と、型パラメータの
     6	組み込みの制約（OPEN-070、ADR 0297）を加えた。段階 B2 は、`Map`・`Set`・`Bytes` と、型クラスの辞書
     7	（高カインド型を含む）を加える（設計書 07-04「進め方」）。段階 A（`Benitoite.Core`）の定義は最小実行版の
     8	ものとして残し、段階 B は別の名前空間に写して広げる。段階 B2 は、段階 B1 の定義を同じ名前空間で広げる。
     9	
    10	段階 A からの表現の違い（設計書 07-04「01-12 との対応」の表に記す）:
    11	
    12	- 型の変数は、内側から数えた de Bruijn の番号で表す。関数の定義の本体では、定義の型パラメータが
    13	  `0..n-1` である。`handle` の節は、操作の型パラメータを番号 `0..k-1` に束縛し、節の外側の型の変数の番号を
    14	  k だけずらす（01-06「エフェクトの宣言とハンドラの型付け」の「その型パラメータをほかの何とも等しくない型として
    15	  扱う」）。閉じた値は、節の内側へ運んでも変わらない。
    16	- エフェクトの原子は、エフェクトの名前（モジュールと名前の組を一つの文字列で表す）とエフェクト変数である。
    17	- 組み込みの関数のうち、ストアの操作（`Reference.new` など）とプロセスの終了は、組み込みの関数の種類
    18	  （`PrimKind`）で区別する。
    19	- 高カインドの型パラメータの型引数は、型構成子 `Ty.ctor φ` か、高カインドの型パラメータ `Ty.tvar j` である。
    20	  型の置き換えは、`α[Ā]`（`Ty.tapp`）の α を型構成子に置き換えるとき、その型構成子を Ā に適用した型にする
    21	  （`Ty.applyTo`）。型の種類（型パラメータが値の型か型構成子か、型構成子がとる型引数の個数）は検査しない。
    22	-/
    23	
    24	namespace Benitoite.Release
    25	
    26	/-- エフェクトの名前。01-12「エフェクトの名前と開始状態」の `L`。宣言したモジュールと名前の組を、
    27	一つの文字列で表す。 -/
    28	abbrev EffName := String
    29	
    30	/-- 状態を扱う組み込みの関数と解放のエフェクト `State`（01-07「可変のセル（初回リリース版）」）。 -/
    31	def stateEff : EffName := "State"
    32	
    33	/-- エフェクトの原子。01-12 の `e ::= L | ρ`。 -/
    34	inductive Atom where
    35	  | name (l : EffName)
    36	  | rho (i : Nat)
    37	  deriving DecidableEq, Repr
    38	
    39	/-- エフェクトの集合。 -/
    40	def Eff := Atom → Bool
    41	
    42	namespace Eff
    43	
    44	def empty : Eff := fun _ => false
    45	
    46	/-- 名前一つの集合 `{L}`。 -/
    47	def single (l : EffName) : Eff := fun a => a == .name l
    48	
    49	def Sub (ε ε' : Eff) : Prop := ∀ a, ε a = true → ε' a = true
    50	
    51	def union (ε ε' : Eff) : Eff := fun a => ε a || ε' a
    52	
    53	/-- エフェクト変数の置き換え `ε[Ē/ρ̄]`（段階 A と同じ）。 -/
    54	def substRho (es : List Eff) (ε : Eff) : Eff := fun a =>
    55	  let kept := match a with
    56	    | .name l => ε (.name l)
    57	    | .rho i => if i < es.length then false else ε (.rho i)
    58	  kept || (List.range es.length).any (fun i =>
    59	    ε (.rho i) && match es[i]? with
    60	      | some e => e a
    61	      | none => false)
    62	
    63	end Eff
    64	
    65	/-- 基本型。01-12 の `ι`（初回リリース版の `Byte`・`Decimal` を含む）。 -/
    66	inductive BaseTy where
    67	  | integer | float | string | character | boolean | unit | byte | decimal
    68	  deriving DecidableEq, Repr
    69	
    70	abbrev DataName := String
    71	abbrev ConName := String
    72	abbrev FunName := String
    73	abbrev PrimName := String
    74	abbrev OpName := String
    75	/-- 中身を見せない型の名前（`IOError`・`NetworkError`・リソースの型など）。01-12 の `O`。 -/
    76	abbrev OpaqueName := String
    77	abbrev ClassName := String
    78	abbrev ImplName := String
    79	abbrev MethName := String
    80	
    81	/-- 型構成子 φ（01-12「型クラス」の `τ ::= A | φ`）。型引数を与えずに書いた型構成子であり、高カインドの
    82	型パラメータの型引数と、型構成子を引数にとる型クラスの辞書の型に現れる。高カインドの型パラメータそのものを
    83	型構成子として書く形は、型の変数 `Ty.tvar` で表す。 -/
    84	inductive TyCon where
    85	  | data (d : DataName)
    86	  | list
    87	  | set
    88	  | map
    89	  | reference
    90	  | lazy
    91	
    92	/-- 型。01-12 の型に、初回リリース版の拡張が加える型を加えたもの。
    93	`tvar i` は番号 i の型パラメータ。`cont b t ε` は継続の型 `Cont(B → T ! ε)`。`dict cl τ` は辞書の型
    94	`Dict[Cl, τ]`、`tapp i Ā` は型構成子を表す型パラメータの適用 `α[Ā]`、`ctor φ` は型構成子 φ である。 -/
    95	inductive Ty where
    96	  | base (ι : BaseTy)
    97	  | opaque (o : OpaqueName)
    98	  | data (d : DataName) (args : List Ty)
    99	  | list (a : Ty)
   100	  | fn (params : List Ty) (ret : Ty) (eff : Eff)
   101	  | tvar (i : Nat)
   102	  | reference (a : Ty)
   103	  | lazy (a : Ty)
   104	  | cont (b : Ty) (t : Ty) (eff : Eff)
   105	  | map (k : Ty) (v : Ty)
   106	  | set (a : Ty)
   107	  | bytes
   108	  | dict (cl : ClassName) (τ : Ty)
   109	  | tapp (i : Nat) (args : List Ty)
   110	  | ctor (φ : TyCon)
   111	
   112	/-- 型パラメータに付けた組み込みの制約（01-06「組み込みの制約（初回リリース版）」、ADR 0297）。 -/
   113	structure TParam where
   114	  equality : Bool := false
   115	  key : Bool := false
   116	
   117	/-- 鍵の型であるという制約（V-Map・V-Set の「A は鍵の型である」）。 -/
   118	def TParam.keyC : TParam := { key := true }
   119	
   120	/-- 定数。`O` の型の値（`IOError` の値、リソースなど）は、型の名前と番号で表す。 -/
   121	inductive Const where
   122	  | integer (n : Int)
   123	  | float (x : Float)
   124	  | string (s : String)
   125	  | character (c : Char)
   126	  | boolean (b : Bool)
   127	  | unit
   128	  | byte (n : Nat)
   129	  | decimal (n : Int) (scale : Nat)
   130	  | opaque (o : OpaqueName) (id : Nat)
   131	
   132	def Const.type : Const → Ty
   133	  | .integer _ => .base .integer
   134	  | .float _ => .base .float
   135	  | .string _ => .base .string
   136	  | .character _ => .base .character
   137	  | .boolean _ => .base .boolean
   138	  | .unit => .base .unit
   139	  | .byte _ => .base .byte
   140	  | .decimal _ _ => .base .decimal
   141	  | .opaque o _ => .opaque o
   142	
   143	/-- パターンの定数の照合。P-Const は `Float`・`Byte`・`Decimal` と `O` の型の値をパターンに許さないので、
   144	その四つは等しいと判定しない。 -/
   145	def Const.matches : Const → Const → Bool
   146	  | .integer a, .integer b => a == b
   147	  | .string a, .string b => a == b
   148	  | .character a, .character b => a == b
   149	  | .boolean a, .boolean b => a == b
   150	  | .unit, .unit => true
   151	  | _, _ => false
   152	
   153	inductive Pat where
   154	  | wild
   155	  | var
   156	  | const (c : Const)
   157	  | con (c : ConName) (args : List Pat)
   158	
   159	/-- 節が処理する操作。利用者が宣言したエフェクトの操作と、組み込みのエフェクトの操作
   160	（外部に作用する組み込みの関数）がある（01-12「ハンドラ」）。 -/
   161	inductive OpRef where
   162	  | user (o : OpName)
   163	  | prim (b : PrimName)
   164	  deriving DecidableEq
   165	
   166	mutual
   167	  /-- 値。 -/
   168	  inductive Val where
   169	    | var (i : Nat)
   170	    | const (c : Const)
   171	    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff)
   172	    | prim (b : PrimName) (tys : List Ty) (effs : List Eff)
   173	    | lam (params : List Ty) (body : Comp)
   174	    | con (c : ConName) (tys : List Ty) (args : List Val)
   175	    | list (elems : List Val)
   176	    /-- 利用者が宣言したエフェクトの操作 `op[T̄]`。 -/
   177	    | op (o : OpName) (tys : List Ty)
   178	    /-- ストアの場所 ℓ（可変のセルと明示遅延）と、継続の場所 κ。 -/
   179	    | loc (l : Nat)
   180	    /-- マップ `{V1 ↦ W1, …, Vn ↦ Wn}`。鍵の並びと値の並びで表す。 -/
   181	    | mapV (keys : List Val) (vals : List Val)
   182	    /-- 集合 `{V1, …, Vn}`。 -/
   183	    | setV (elems : List Val)
   184	    /-- バイト列 `bytes(k1, …, kn)`。ki は `Byte` の値（`Const.byte` と同じく自然数で表す）。 -/
   185	    | bytesV (bs : List Nat)
   186	    /-- 実装の辞書 `I[T̄](V̄)`。 -/
   187	    | dict (i : ImplName) (tys : List Ty) (args : List Val)
   188	    /-- 上位の型クラスの辞書 `V↑S`。 -/
   189	    | super (v : Val) (s : ClassName)
   190	
   191	  inductive Comp where
   192	    | ret (v : Val)
   193	    | letIn (m : Comp) (n : Comp)
   194	    | app (f : Val) (args : List Val)
   195	    | ite (v : Val) (m n : Comp)
   196	    | «match» (v : Val) (arms : List (Pat × Comp))
   197	    /-- `lazy M` -/
   198	    | lazyC (m : Comp)
   199	    /-- `escape V` -/
   200	    | escape (v : Val)
   201	    /-- `use V in M` -/
   202	    | use (v : Val) (m : Comp)
   203	    /-- `handle M with H` -/
   204	    | handle (m : Comp) (h : List Clause)
   205	    /-- `resume κ V`。κ は節の変数か、継続の場所。 -/
   206	    | resume (k : Val) (v : Val)
   207	    /-- メソッドの呼び出し `V.m[S̄; Ē](W̄)`。 -/
   208	    | meth (d : Val) (m : MethName) (tys : List Ty) (effs : List Eff) (args : List Val)
   209	
   210	  /-- 節 `op(x̄) k ⇒ N`。`arity` は x̄ の個数、`ntys` は操作の型パラメータの個数である。N の中で、番号 0 が k、
   211	  番号 1 から n が x̄ を最後の引数から順に指す。操作の型パラメータは、N の中の型の変数の番号 `0..ntys-1` である。 -/
   212	  inductive Clause where
   213	    | mk (op : OpRef) (arity : Nat) (ntys : Nat) (body : Comp)
   214	end
   215	
   216	def Clause.op : Clause → OpRef
   217	  | .mk o _ _ _ => o
   218	
   219	def Clause.arity : Clause → Nat
   220	  | .mk _ n _ _ => n
   221	
   222	def Clause.ntys : Clause → Nat
   223	  | .mk _ _ k _ => k
   224	
   225	def Clause.body : Clause → Comp
   226	  | .mk _ _ _ m => m
   227	
   228	/-- トップレベルの関数の定義。`fn f[ᾱ : c̄; ρ̄](x̄:Ā) : B ! ε = M`。`tparams` は型パラメータと、その
   229	組み込みの制約である（ADR 0297）。 -/
   230	structure Def where
   231	  tparams : List TParam
   232	  neffs : Nat
   233	  params : List Ty
   234	  ret : Ty
   235	  eff : Eff
   236	  body : Comp
   237	
   238	def Def.ntys (d : Def) : Nat := d.tparams.length
   239	
   240	structure ConDecl where
   241	  data : DataName
   242	  ntys : Nat
   243	  args : List Ty
   244	
   245	/-- 利用者が宣言したエフェクトの操作 `function op[ᾱ](x̄: Ā) -> B` の宣言。型は
   246	`∀ᾱ. (Ā) → B ! {L}` である（01-06「エフェクトの宣言とハンドラの型付け」）。 -/
   247	structure OpDecl where
   248	  eff : EffName
   249	  tparams : List TParam
   250	  params : List Ty
   251	  ret : Ty
   252	
   253	/-- 型クラスのメソッドの型 `∀γ̄ ρ̄. (Ā) → B ! ε`（01-12 の C-Meth）。型の中では、メソッドの型パラメータ γ̄ が
   254	番号 `0..g-1`（g は γ̄ の個数）、型クラスの引数 P が番号 g である。メソッドが自分の型クラスの制約を持つときは、
   255	Ā がその制約ごとの辞書の型を値の引数の前に含む。 -/
   256	structure MethSig where
   257	  tparams : List TParam
   258	  neffs : Nat
   259	  params : List Ty
   260	  ret : Ty
   261	  eff : Eff
   262	
   263	/-- 型クラスの宣言。上位の型クラスの並びと、メソッドの型。 -/
   264	structure ClassDecl where
   265	  supers : List ClassName
   266	  methods : MethName → Option MethSig
   267	
   268	/-- 実装の定義 `impl I[β̄](d̄ : Dict[Cl', β̄']) : Dict[Cl, τ] = { S1 = U1, …, Sl = Ul; m1 = D1, …, mk = Dk }`。
   269	型の中では、実装の型パラメータ β̄ が番号 `0..b-1` である。`dictParams` は辞書の引数 d̄ の型 `Dict[Cl', β']` を、
   270	型クラス Cl' と型パラメータ β' の番号の組で表す。`target` は τ、
   271	`supers` は上位の型クラスごとの辞書 U、`methods` はメソッドごとの本体の定義 D の本体である。D の型パラメータ、
   272	引数と戻り値の型、エフェクトは、D-Impl が型クラスの宣言から決めるので、本体だけを持つ。メソッドの本体の中では、
   273	メソッドの型パラメータ γ̄ が番号 `0..g-1`、実装の型パラメータ β̄ が番号 `g..g+b-1` であり、値の変数は
   274	辞書の引数 d̄ の後にメソッドの引数 x̄ を束縛した並びである。 -/
   275	structure ImplDecl where
   276	  tparams : List TParam
   277	  dictParams : List (ClassName × Nat)
   278	  cls : ClassName
   279	  target : Ty
   280	  supers : ClassName → Option Val
   281	  methods : MethName → Option Comp
   282	
   283	/-- 辞書の引数 d̄ の型 `Dict[Cl', β']` の並び。 -/
   284	def ImplDecl.dictTys (id : ImplDecl) : List Ty :=
   285	  id.dictParams.map fun p => .dict p.1 (.tvar p.2)
   286	
   287	/-- プログラム。定義の集まり Σ、型の宣言、エフェクトの宣言、型クラスの宣言と実装の定義。 -/
   288	structure Program where
   289	  defs : FunName → Option Def
   290	  cons : ConName → Option ConDecl
   291	  ops : OpName → Option OpDecl
   292	  /-- 利用者が宣言したエフェクトの操作の一覧。 -/
   293	  effects : EffName → Option (List OpName)
   294	  classes : ClassName → Option ClassDecl
   295	  impls : ImplName → Option ImplDecl
   296	
   297	end Benitoite.Release
```

### formal/Benitoite/Release/Subst.lean

```lean
     1	import Benitoite.Release.Syntax
     2	
     3	/-!
     4	# 置き換えとパターンの照合（段階 B）
     5	
     6	段階 A（`Benitoite.Core`）の置き換えを、段階 B の構成に広げる。型の変数は de Bruijn の番号で表す
     7	（`Syntax.lean` の冒頭）。型の置き換え `Ty.substAt c ts es` は、`c` 個の型の変数を束縛した内側で、
     8	番号 `c` から `c + ts.length - 1` の型の変数を `ts` の型（`c` だけずらしたもの）に置き換え、
     9	それより大きい番号を `ts` の長さだけ詰める。型構成子を表す型パラメータの適用 `α[Ā]` の α を置き換えるときは、
    10	置き換えた型を Ā に適用する（`Ty.applyTo`）。
    11	-/
    12	
    13	namespace Benitoite.Release
    14	
    15	/-! ## 型とエフェクトの置き換え -/
    16	
    17	/-- 型構成子 φ を型引数 Ā に適用した型。型引数の個数が φ と合わないときの値は使わない（どれも置き換えと
    18	可換になるように、足りない型引数を `Unit` で補う）。 -/
    19	def TyCon.apply : TyCon → List Ty → Ty
    20	  | .data d, as => .data d as
    21	  | .list, as => .list (as.headD (.base .unit))
    22	  | .set, as => .set (as.headD (.base .unit))
    23	  | .map, as => .map (as.headD (.base .unit)) (as.tail.headD (.base .unit))
    24	  | .reference, as => .reference (as.headD (.base .unit))
    25	  | .lazy, as => .lazy (as.headD (.base .unit))
    26	
    27	/-- `α[Ā]` の α を t に置き換えた型。t が型構成子なら Ā に適用し、型構成子を表す型パラメータなら、その適用に
    28	する。t がそれ以外の型のとき（型の種類が合わないとき）は t のままにする。 -/
    29	def Ty.applyTo (t : Ty) (as : List Ty) : Ty :=
    30	  match t with
    31	  | .ctor φ => φ.apply as
    32	  | .tvar j => .tapp j as
    33	  | t => t
    34	
    35	/-- 型の変数の番号を、`c` 以上のものだけ `k` ずらす。 -/
    36	def Ty.shift (k c : Nat) : Ty → Ty
    37	  | .base ι => .base ι
    38	  | .opaque o => .opaque o
    39	  | .data d args => .data d (args.map (Ty.shift k c))
    40	  | .list a => .list (Ty.shift k c a)
    41	  | .fn params ret eff => .fn (params.map (Ty.shift k c)) (Ty.shift k c ret) eff
    42	  | .tvar i => if i < c then .tvar i else .tvar (i + k)
    43	  | .reference a => .reference (Ty.shift k c a)
    44	  | .lazy a => .lazy (Ty.shift k c a)
    45	  | .cont b t eff => .cont (Ty.shift k c b) (Ty.shift k c t) eff
    46	  | .map a b => .map (Ty.shift k c a) (Ty.shift k c b)
    47	  | .set a => .set (Ty.shift k c a)
    48	  | .bytes => .bytes
    49	  | .dict cl τ => .dict cl (Ty.shift k c τ)
    50	  | .tapp i args => .tapp (if i < c then i else i + k) (args.map (Ty.shift k c))
    51	  | .ctor φ => .ctor φ
    52	
    53	def Ty.substAt (c : Nat) (ts : List Ty) (es : List Eff) : Ty → Ty
    54	  | .base ι => .base ι
    55	  | .opaque o => .opaque o
    56	  | .data d args => .data d (args.map (Ty.substAt c ts es))
    57	  | .list a => .list (Ty.substAt c ts es a)
    58	  | .fn params ret eff =>
    59	      .fn (params.map (Ty.substAt c ts es)) (Ty.substAt c ts es ret) (Eff.substRho es eff)
    60	  | .tvar i =>
    61	      if i < c then .tvar i
    62	      else if i - c < ts.length then ((ts[i - c]?).getD (.tvar i)).shift c 0
    63	      else .tvar (i - ts.length)
    64	  | .reference a => .reference (Ty.substAt c ts es a)
    65	  | .lazy a => .lazy (Ty.substAt c ts es a)
    66	  | .cont b t eff => .cont (Ty.substAt c ts es b) (Ty.substAt c ts es t) (Eff.substRho es eff)
    67	  | .map a b => .map (Ty.substAt c ts es a) (Ty.substAt c ts es b)
    68	  | .set a => .set (Ty.substAt c ts es a)
    69	  | .bytes => .bytes
    70	  | .dict cl τ => .dict cl (Ty.substAt c ts es τ)
    71	  | .tapp i args =>
    72	      if i < c then .tapp i (args.map (Ty.substAt c ts es))
    73	      else if i - c < ts.length then
    74	        Ty.applyTo (((ts[i - c]?).getD (.tvar i)).shift c 0) (args.map (Ty.substAt c ts es))
    75	      else .tapp (i - ts.length) (args.map (Ty.substAt c ts es))
    76	  | .ctor φ => .ctor φ
    77	
    78	/-- 型の置き換え θ = [T̄/ᾱ, Ē/ρ̄]（束縛の外側での置き換え）。 -/
    79	def Ty.subst (ts : List Ty) (es : List Eff) : Ty → Ty := Ty.substAt 0 ts es
    80	
    81	mutual
    82	  def Val.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Val → Val
    83	    | .var i => .var i
    84	    | .const k => .const k
    85	    | .fnRef f tys effs => .fnRef f (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substRho es))
    86	    | .prim b tys effs => .prim b (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substRho es))
    87	    | .lam params body => .lam (params.map (Ty.substAt c ts es)) (Comp.substTyAt c ts es body)
    88	    | .con k tys args => .con k (tys.map (Ty.substAt c ts es)) (Val.substTyAtList c ts es args)
    89	    | .list elems => .list (Val.substTyAtList c ts es elems)
    90	    | .op o tys => .op o (tys.map (Ty.substAt c ts es))
    91	    | .loc l => .loc l
    92	    | .mapV ks vs => .mapV (Val.substTyAtList c ts es ks) (Val.substTyAtList c ts es vs)
    93	    | .setV elems => .setV (Val.substTyAtList c ts es elems)
    94	    | .bytesV bs => .bytesV bs
    95	    | .dict i tys args => .dict i (tys.map (Ty.substAt c ts es)) (Val.substTyAtList c ts es args)
    96	    | .super v cl => .super (Val.substTyAt c ts es v) cl
    97	
    98	  def Val.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Val → List Val
    99	    | [] => []
   100	    | v :: vs => Val.substTyAt c ts es v :: Val.substTyAtList c ts es vs
   101	
   102	  def Comp.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Comp → Comp
   103	    | .ret v => .ret (Val.substTyAt c ts es v)
   104	    | .letIn m n => .letIn (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
   105	    | .app f args => .app (Val.substTyAt c ts es f) (Val.substTyAtList c ts es args)
   106	    | .ite v m n => .ite (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
   107	    | .match v arms => .match (Val.substTyAt c ts es v) (Comp.substTyAtArms c ts es arms)
   108	    | .lazyC m => .lazyC (Comp.substTyAt c ts es m)
   109	    | .escape v => .escape (Val.substTyAt c ts es v)
   110	    | .use v m => .use (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m)
   111	    | .handle m h => .handle (Comp.substTyAt c ts es m) (Clause.substTyAtList c ts es h)
   112	    | .resume k v => .resume (Val.substTyAt c ts es k) (Val.substTyAt c ts es v)
   113	    | .meth d m tys effs args =>
   114	        .meth (Val.substTyAt c ts es d) m (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substRho es))
   115	          (Val.substTyAtList c ts es args)
   116	
   117	  def Comp.substTyAtArms (c : Nat) (ts : List Ty) (es : List Eff) :
   118	      List (Pat × Comp) → List (Pat × Comp)
   119	    | [] => []
   120	    | (p, m) :: arms => (p, Comp.substTyAt c ts es m) :: Comp.substTyAtArms c ts es arms
   121	
   122	  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
   123	  def Clause.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Clause → List Clause
   124	    | [] => []
   125	    | .mk o n k m :: cs => .mk o n k (Comp.substTyAt (c + k) ts es m) :: Clause.substTyAtList c ts es cs
   126	end
   127	
   128	/-- 01-12 の `Mθ`。 -/
   129	def Comp.substTy (ts : List Ty) (es : List Eff) (m : Comp) : Comp := Comp.substTyAt 0 ts es m
   130	
   131	def Val.substTy (ts : List Ty) (es : List Eff) (v : Val) : Val := Val.substTyAt 0 ts es v
   132	
   133	/-! ## 値の置き換え -/
   134	
   135	mutual
   136	  def Pat.binders : Pat → Nat
   137	    | .wild => 0
   138	    | .var => 1
   139	    | .const _ => 0
   140	    | .con _ args => Pat.bindersList args
   141	
   142	  def Pat.bindersList : List Pat → Nat
   143	    | [] => 0
   144	    | p :: ps => Pat.binders p + Pat.bindersList ps
   145	end
   146	
   147	def upRen (k : Nat) (ξ : Nat → Nat) (i : Nat) : Nat :=
   148	  if i < k then i else ξ (i - k) + k
   149	
   150	mutual
   151	  def Val.rename (ξ : Nat → Nat) : Val → Val
   152	    | .var i => .var (ξ i)
   153	    | .const c => .const c
   154	    | .fnRef f tys effs => .fnRef f tys effs
   155	    | .prim b tys effs => .prim b tys effs
   156	    | .lam params body => .lam params (Comp.rename (upRen params.length ξ) body)
   157	    | .con c tys args => .con c tys (Val.renameList ξ args)
   158	    | .list elems => .list (Val.renameList ξ elems)
   159	    | .op o tys => .op o tys
   160	    | .loc l => .loc l
   161	    | .mapV ks vs => .mapV (Val.renameList ξ ks) (Val.renameList ξ vs)
   162	    | .setV elems => .setV (Val.renameList ξ elems)
   163	    | .bytesV bs => .bytesV bs
   164	    | .dict i tys args => .dict i tys (Val.renameList ξ args)
   165	    | .super v cl => .super (Val.rename ξ v) cl
   166	
   167	  def Val.renameList (ξ : Nat → Nat) : List Val → List Val
   168	    | [] => []
   169	    | v :: vs => Val.rename ξ v :: Val.renameList ξ vs
   170	
   171	  def Comp.rename (ξ : Nat → Nat) : Comp → Comp
   172	    | .ret v => .ret (Val.rename ξ v)
   173	    | .letIn m n => .letIn (Comp.rename ξ m) (Comp.rename (upRen 1 ξ) n)
   174	    | .app f args => .app (Val.rename ξ f) (Val.renameList ξ args)
   175	    | .ite v m n => .ite (Val.rename ξ v) (Comp.rename ξ m) (Comp.rename ξ n)
   176	    | .match v arms => .match (Val.rename ξ v) (Comp.renameArms ξ arms)
   177	    | .lazyC m => .lazyC (Comp.rename ξ m)
   178	    | .escape v => .escape (Val.rename ξ v)
   179	    | .use v m => .use (Val.rename ξ v) (Comp.rename ξ m)
   180	    | .handle m h => .handle (Comp.rename ξ m) (Clause.renameList ξ h)
   181	    | .resume k v => .resume (Val.rename ξ k) (Val.rename ξ v)
   182	    | .meth d m tys effs args => .meth (Val.rename ξ d) m tys effs (Val.renameList ξ args)
   183	
   184	  def Comp.renameArms (ξ : Nat → Nat) : List (Pat × Comp) → List (Pat × Comp)
   185	    | [] => []
   186	    | (p, m) :: arms => (p, Comp.rename (upRen p.binders ξ) m) :: Comp.renameArms ξ arms
   187	
   188	  def Clause.renameList (ξ : Nat → Nat) : List Clause → List Clause
   189	    | [] => []
   190	    | .mk o n k m :: cs => .mk o n k (Comp.rename (upRen (n + 1) ξ) m) :: Clause.renameList ξ cs
   191	end
   192	
   193	def upSubst (k : Nat) (σ : Nat → Val) (i : Nat) : Val :=
   194	  if i < k then .var i else (σ (i - k)).rename (· + k)
   195	
   196	mutual
   197	  def Val.subst (σ : Nat → Val) : Val → Val
   198	    | .var i => σ i
   199	    | .const c => .const c
   200	    | .fnRef f tys effs => .fnRef f tys effs
   201	    | .prim b tys effs => .prim b tys effs
   202	    | .lam params body => .lam params (Comp.subst (upSubst params.length σ) body)
   203	    | .con c tys args => .con c tys (Val.substList σ args)
   204	    | .list elems => .list (Val.substList σ elems)
   205	    | .op o tys => .op o tys
   206	    | .loc l => .loc l
   207	    | .mapV ks vs => .mapV (Val.substList σ ks) (Val.substList σ vs)
   208	    | .setV elems => .setV (Val.substList σ elems)
   209	    | .bytesV bs => .bytesV bs
   210	    | .dict i tys args => .dict i tys (Val.substList σ args)
   211	    | .super v cl => .super (Val.subst σ v) cl
   212	
   213	  def Val.substList (σ : Nat → Val) : List Val → List Val
   214	    | [] => []
   215	    | v :: vs => Val.subst σ v :: Val.substList σ vs
   216	
   217	  def Comp.subst (σ : Nat → Val) : Comp → Comp
   218	    | .ret v => .ret (Val.subst σ v)
   219	    | .letIn m n => .letIn (Comp.subst σ m) (Comp.subst (upSubst 1 σ) n)
   220	    | .app f args => .app (Val.subst σ f) (Val.substList σ args)
   221	    | .ite v m n => .ite (Val.subst σ v) (Comp.subst σ m) (Comp.subst σ n)
   222	    | .match v arms => .match (Val.subst σ v) (Comp.substArms σ arms)
   223	    | .lazyC m => .lazyC (Comp.subst σ m)
   224	    | .escape v => .escape (Val.subst σ v)
   225	    | .use v m => .use (Val.subst σ v) (Comp.subst σ m)
   226	    | .handle m h => .handle (Comp.subst σ m) (Clause.substList σ h)
   227	    | .resume k v => .resume (Val.subst σ k) (Val.subst σ v)
   228	    | .meth d m tys effs args => .meth (Val.subst σ d) m tys effs (Val.substList σ args)
   229	
   230	  def Comp.substArms (σ : Nat → Val) : List (Pat × Comp) → List (Pat × Comp)
   231	    | [] => []
   232	    | (p, m) :: arms => (p, Comp.subst (upSubst p.binders σ) m) :: Comp.substArms σ arms
   233	
   234	  def Clause.substList (σ : Nat → Val) : List Clause → List Clause
   235	    | [] => []
   236	    | .mk o n k m :: cs => .mk o n k (Comp.subst (upSubst (n + 1) σ) m) :: Clause.substList σ cs
   237	end
   238	
   239	/-- 01-12 の `M[W̄/x̄]`。束縛した順の最後の値が番号 0 に当たる。 -/
   240	def instSubst (ws : List Val) (i : Nat) : Val :=
   241	  if i < ws.length then (ws.reverse[i]?).getD (.var i) else .var (i - ws.length)
   242	
   243	def Comp.instantiate (ws : List Val) (m : Comp) : Comp :=
   244	  Comp.subst (instSubst ws) m
   245	
   246	def Val.instantiate (ws : List Val) (v : Val) : Val :=
   247	  Val.subst (instSubst ws) v
   248	
   249	/-! ## パターンの照合と分岐の選択（段階 A と同じ） -/
   250	
   251	mutual
   252	  def Pat.matchVal : Pat → Val → Option (List Val)
   253	    | .wild, _ => some []
   254	    | .var, v => some [v]
   255	    | .const c, .const c' => if c.matches c' then some [] else none
   256	    | .con c ps, .con c' _ args =>
   257	        if c = c' then Pat.matchList ps args else none
   258	    | _, _ => none
   259	
   260	  def Pat.matchList : List Pat → List Val → Option (List Val)
   261	    | [], [] => some []
   262	    | p :: ps, v :: vs => do
   263	        let a ← Pat.matchVal p v
   264	        let b ← Pat.matchList ps vs
   265	        pure (a ++ b)
   266	    | _, _ => none
   267	end
   268	
   269	def firstMatch (v : Val) : List (Pat × Comp) → Option (Comp × List Val)
   270	  | [] => none
   271	  | (p, m) :: arms =>
   272	      match Pat.matchVal p v with
   273	      | some ws => some (m, ws)
   274	      | none => firstMatch v arms
   275	
   276	end Benitoite.Release
```

### formal/Benitoite/Release/Typing.lean

```lean
     1	import Benitoite.Release.Subst
     2	
     3	/-!
     4	# 型付け規則（段階 B）
     5	
     6	設計書 01-12 の型付け規則に、「初回リリース版の拡張」の制御の構成の型付けを加える。
     7	計算の判断は 01-12 の `Γ; R ⊢c M : A ! ε` であり、値の判断にはストアの型付け Ψ を加える。
     8	
     9	段階 A からの表現の違い:
    10	
    11	- 型付けの判断は、型パラメータの組み込みの制約の並び `C`（型の変数の番号の順）を持つ（ADR 0297）。V-Prim は
    12	  組み込みの関数の型パラメータの制約を `C` のもとで確かめ、V-Fun は型引数が関数の型パラメータの制約を
    13	  満たすことを確かめる。型が制約を満たすか（等値の型・鍵の型）は 01-06 に委ね、`Builtins.sat` で与える。
    14	- 環境 Γ の要素は `Option Ty` である。V-Lam の前提と `lazy M` の M の検査では、Γ から継続の型を持つ変数を
    15	  除く（01-12「ハンドラ」）。番号で表した変数を除くと番号がずれるので、要素を `none` に置き換えて表す。
    16	- 型クラスのメソッドの型と実装の定義は、型の変数を番号で表す（`Syntax.lean` の `MethSig`・`ImplDecl`）。
    17	  D-Impl のメソッドの本体の型付けは、メソッドの型パラメータを内側（番号 `0..g-1`）、実装の型パラメータを
    18	  外側に並べた制約の並びで行う。
    19	- `handle` の節が処理する操作の型パラメータは、節の中で型の変数の番号 `0..k-1` に束縛し、制約の並びの
    20	  先頭に加える（01-06「その型パラメータをほかの何とも等しくない型として扱う」）。節の外側の型（環境の型、
    21	  `handle` の式の型、R）は、節の中では番号を k だけずらす。
    22	-/
    23	
    24	namespace Benitoite.Release
    25	
    26	/-! ## 組み込みの関数 -/
    27	
    28	abbrev ErrKind := String
    29	
    30	/-- 組み込みの関数の結果。値、実行時エラー、プロセスの終了（E-Exit の `b(W̄) ↦ exit(n)`）。 -/
    31	inductive Outcome where
    32	  | val (v : Val)
    33	  | err (r : ErrKind)
    34	  | exit (n : Int)
    35	
    36	/-- 組み込みの関数の種類。ストアの規則（E-RefNew など）を使う関数は、E-Prim・E-IO を使わない
    37	（01-12「ストア：可変のセルと明示遅延」）。終了状態を指定したプロセスの終了の関数（`exit`）には、E-IO を使わず
    38	E-Exit を使う（01-12「プロセスの終了」）。 -/
    39	inductive PrimKind where
    40	  | pure | io | exit | refNew | refGet | refSet | refUpdate | force
    41	  deriving DecidableEq
    42	
    43	structure PrimSig where
    44	  tparams : List TParam
    45	  neffs : Nat
    46	  params : List Ty
    47	  ret : Ty
    48	  eff : Eff
    49	  /-- 型パラメータの制約（組み込みの制約と演算子の型の集まり）。制約の並び `C` のもとで判定する。 -/
    50	  admits : List TParam → List Ty → Prop
    51	  kind : PrimKind
    52	  /-- 組み込みのエフェクトの操作のとき、そのエフェクトの名前。 -/
    53	  opEff : Option EffName
    54	
    55	def PrimSig.ntys (s : PrimSig) : Nat := s.tparams.length
    56	
    57	/-- 組み込みの関数と、01-12 がほかの章に委ねているもの。 -/
    58	structure Builtins where
    59	  sig : PrimName → Option PrimSig
    60	  /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)（ADR 0296）。 -/
    61	  delta : PrimName → List Ty → List Eff → List Val → Option Outcome
    62	  /-- IO を行う組み込みの関数の応答として起こりうるもの。 -/
    63	  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → Prop
    64	  /-- 事象 `release(V)` の応答として起こりうるもの。`none` が `ok`、`some r` が `error(r)`。 -/
    65	  releaseResponse : Val → Option ErrKind → Prop
    66	  /-- リソースの型か。リソースの型の解放のエフェクト `rel(O_r)` は `{State}` である。 -/
    67	  isResource : OpaqueName → Bool
    68	  /-- 組み込みのエフェクトと、その操作。`State` は操作を持たない。 -/
    69	  effects : EffName → Option (List PrimName)
    70	  /-- 型が組み込みの制約を満たすか（01-06「等値の型」「鍵の型」）。制約の並び `C` のもとで判定する。 -/
    71	  sat : List TParam → Ty → TParam → Prop
    72	  /-- `Reference.get` と `Reference.set` の名前。`Reference.update` の遷移が使う。 -/
    73	  refGet : PrimName
    74	  refSet : PrimName
    75	
    76	def fnTy (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
    77	  Ty.subst ts es (.fn params ret eff)
    78	
    79	/-- 型引数 `ts` が、型パラメータの制約 `tps` を、制約の並び `C` のもとで満たす。制約の並びは、型の変数の番号の
    80	順（内側から）に並べる。 -/
    81	def SatAll (B : Builtins) (C : List TParam) (ts : List Ty) (tps : List TParam) : Prop :=
    82	  ts.length = tps.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → tps[i]? = some p → B.sat C t p
    83	
    84	/-! ## 操作 -/
    85	
    86	/-- 操作の型 `∀ᾱ. (Ā) → B ! {L}`。 -/
    87	structure OpSig where
    88	  tparams : List TParam
    89	  params : List Ty
    90	  ret : Ty
    91	  eff : EffName
    92	
    93	def opSig (P : Program) (B : Builtins) : OpRef → Option OpSig
    94	  | .user o => (P.ops o).map fun od => ⟨od.tparams, od.params, od.ret, od.eff⟩
    95	  | .prim b =>
    96	      match B.sig b with
    97	      | some s =>
    98	          match s.opEff with
    99	          | some l => some ⟨s.tparams, s.params, s.ret, l⟩
   100	          | none => none
   101	      | none => none
   102	
   103	/-- エフェクト L の操作の一覧。利用者が宣言したエフェクトか、組み込みのエフェクト。 -/
   104	def effOps (P : Program) (B : Builtins) (l : EffName) : Option (List OpRef) :=
   105	  match P.effects l with
   106	  | some os => some (os.map .user)
   107	  | none => (B.effects l).map (·.map .prim)
   108	
   109	/-- `handles(H, op)`。 -/
   110	def handles (h : List Clause) (o : OpRef) : Bool := h.any (fun c => c.op == o)
   111	
   112	/-- `handled(H)`。一つ以上の操作を持ち、そのすべての操作の節を H が持つエフェクトの集合。 -/
   113	def handled (P : Program) (B : Builtins) (h : List Clause) : Eff := fun a =>
   114	  match a with
   115	  | .name l =>
   116	      match effOps P B l with
   117	      | some (o :: os) => (o :: os).all (handles h)
   118	      | _ => false
   119	  | .rho _ => false
   120	
   121	/-! ## 型の正しさ -/
   122	
   123	mutual
   124	  /-- 型の中の型の変数の番号が `n` より小さい（その位置で束縛された型の変数だけを使う）。 -/
   125	  def Ty.WF (n : Nat) : Ty → Prop
   126	    | .base _ => True
   127	    | .opaque _ => True
   128	    | .data _ args => Ty.WFList n args
   129	    | .list a => Ty.WF n a
   130	    | .fn params ret _ => Ty.WFList n params ∧ Ty.WF n ret
   131	    | .tvar i => i < n
   132	    | .reference a => Ty.WF n a
   133	    | .lazy a => Ty.WF n a
   134	    | .cont b t _ => Ty.WF n b ∧ Ty.WF n t
   135	    | .map a b => Ty.WF n a ∧ Ty.WF n b
   136	    | .set a => Ty.WF n a
   137	    | .bytes => True
   138	    | .dict _ τ => Ty.WF n τ
   139	    | .tapp i args => i < n ∧ Ty.WFList n args
   140	    | .ctor _ => True
   141	
   142	  def Ty.WFList (n : Nat) : List Ty → Prop
   143	    | [] => True
   144	    | a :: as => Ty.WF n a ∧ Ty.WFList n as
   145	end
   146	
   147	/-! ## 型の包含 -/
   148	
   149	def Ty.Le (a a' : Ty) : Prop :=
   150	  a = a' ∨ ∃ ps r ε ε', a = .fn ps r ε ∧ a' = .fn ps r ε' ∧ Eff.Sub ε ε'
   151	
   152	/-! ## ストアの型付けと環境 -/
   153	
   154	/-- ストアの場所の型。可変のセル、明示遅延、継続（継続の型と、継続を作った節の R）。 -/
   155	inductive LocTy where
   156	  | ref (a : Ty)
   157	  | lazy (a : Ty)
   158	  | cont (b t : Ty) (ε : Eff) (r : Option Ty)
   159	
   160	/-- ストアの型付け Ψ。 -/
   161	abbrev StoreTy := Nat → Option LocTy
   162	
   163	/-- 環境から継続の型を持つ変数を除く。番号をずらさないように、要素を `none` にする。 -/
   164	def hideConts (Γ : List (Option Ty)) : List (Option Ty) :=
   165	  Γ.map fun o => match o with
   166	    | some (.cont _ _ _) => none
   167	    | x => x
   168	
   169	/-- 型の並びを、環境に加える形にする。 -/
   170	def binds (as : List Ty) : List (Option Ty) := as.reverse.map some
   171	
   172	/-- 環境の型の番号をずらす（節の内側に入るとき）。 -/
   173	def shiftEnv (k : Nat) (Γ : List (Option Ty)) : List (Option Ty) := Γ.map (Option.map (Ty.shift k 0))
   174	
   175	/-! ## パターンと網羅性 -/
   176	
   177	mutual
   178	  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop
   179	    | P_Wild {a} : PatTy P .wild a []
   180	    | P_Var {a} : PatTy P .var a [a]
   181	    | P_Const {c} :
   182	        (∀ x, c ≠ .float x) → (∀ n, c ≠ .byte n) → (∀ n s, c ≠ .decimal n s) →
   183	        (∀ o n, c ≠ .opaque o n) →
   184	        PatTy P (.const c) c.type []
   185	    | P_Con {c ps cd ts δ} :
   186	        P.cons c = some cd → ts.length = cd.ntys →
   187	        PatTys P ps (cd.args.map (Ty.subst ts [])) δ →
   188	        PatTy P (.con c ps) (.data cd.data ts) δ
   189	
   190	  inductive PatTys (P : Program) : List Pat → List Ty → List Ty → Prop
   191	    | nil : PatTys P [] [] []
   192	    | cons {p ps a as δ δs} :
   193	        PatTy P p a δ → PatTys P ps as δs → PatTys P (p :: ps) (a :: as) (δ ++ δs)
   194	end
   195	
   196	mutual
   197	  /-- 網羅性を考えるうえでの値の形。パターンが中を調べない型（関数の型、型パラメータ、セル、明示遅延、
   198	  継続、マップ、集合、バイト列、辞書、型パラメータの適用、型構成子）には、どの値も属するとする。 -/
   199	  inductive Inhabits (P : Program) : Ty → Val → Prop
   200	    | const {c} : Inhabits P c.type (.const c)
   201	    | con {c ts tys' args cd} :
   202	        P.cons c = some cd → cd.ntys = ts.length →
   203	        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
   204	        Inhabits P (.data cd.data ts) (.con c tys' args)
   205	    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
   206	    | fn {ps r ε v} : Inhabits P (.fn ps r ε) v
   207	    | tvar {i v} : Inhabits P (.tvar i) v
   208	    | reference {a v} : Inhabits P (.reference a) v
   209	    | lazy {a v} : Inhabits P (.lazy a) v
   210	    | cont {b t ε v} : Inhabits P (.cont b t ε) v
   211	    | map {a b v} : Inhabits P (.map a b) v
   212	    | set {a v} : Inhabits P (.set a) v
   213	    | bytes {v} : Inhabits P .bytes v
   214	    | dict {cl τ v} : Inhabits P (.dict cl τ) v
   215	    | tapp {i as v} : Inhabits P (.tapp i as) v
   216	    | ctor {φ v} : Inhabits P (.ctor φ) v
   217	
   218	  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop
   219	    | nil : InhabitsAll P [] []
   220	    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)
   221	
   222	  inductive InhabitsEach (P : Program) : Ty → List Val → Prop
   223	    | nil {a} : InhabitsEach P a []
   224	    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
   225	end
   226	
   227	def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
   228	  ∀ v, Inhabits P a v → ∃ p ∈ ps, (Pat.matchVal p v).isSome
   229	
   230	/-! ## 値と計算の型付け -/
   231	
   232	mutual
   233	  /-- `Γ ⊢v V : A`（制約の並び C とストアの型付け Ψ のもとで）。 -/
   234	  inductive HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) :
   235	      List TParam → List (Option Ty) → Val → Ty → Prop
   236	    /-- 継続の型の変数は、`resume` の第一引数にだけ書ける（C-Resume。ADR 0300）。 -/
   237	    | V_Var {Γ i a} : Γ[i]? = some (some a) → (∀ b t ε, a ≠ .cont b t ε) →
   238	        HasTypeV P B Ψ C Γ (.var i) a
   239	    | V_Const {Γ c} : HasTypeV P B Ψ C Γ (.const c) c.type
   240	    | V_Fun {Γ f d ts es} :
   241	        P.defs f = some d → SatAll B C ts d.tparams → es.length = d.neffs →
   242	        HasTypeV P B Ψ C Γ (.fnRef f ts es) (fnTy d.params d.ret d.eff ts es)
   243	    | V_Prim {Γ b s ts es} :
   244	        B.sig b = some s → ts.length = s.ntys → es.length = s.neffs → s.admits C ts →
   245	        HasTypeV P B Ψ C Γ (.prim b ts es) (fnTy s.params s.ret s.eff ts es)
   246	    | V_Op {Γ o od ts} :
   247	        P.ops o = some od → SatAll B C ts od.tparams →
   248	        HasTypeV P B Ψ C Γ (.op o ts) (fnTy od.params od.ret (Eff.single od.eff) ts [])
   249	    | V_Lam {Γ ps body r ε} :
   250	        HasTypeC P B Ψ C (binds ps ++ hideConts Γ) (some r) body r ε →
   251	        HasTypeV P B Ψ C Γ (.lam ps body) (.fn ps r ε)
   252	    | V_Con {Γ c ts args cd} :
   253	        P.cons c = some cd → ts.length = cd.ntys →
   254	        HasTypeVs P B Ψ C Γ args (cd.args.map (Ty.subst ts [])) →
   255	        HasTypeV P B Ψ C Γ (.con c ts args) (.data cd.data ts)
   256	    /-- V-List。要素の型は、その位置で束縛された型の変数だけを使う（空のリストの要素の型は項に現れないので、
   257	    型の正しさを前提に置く）。 -/
   258	    | V_List {Γ elems a} :
   259	        HasTypeEach P B Ψ C Γ elems a → Ty.WF C.length a → HasTypeV P B Ψ C Γ (.list elems) (.list a)
   260	    /-- `Ψ(ℓ) = A` のとき `ℓ : A`（01-12「確かめる性質」）。 -/
   261	    | V_LocRef {Γ l a} : Ψ l = some (.ref a) → HasTypeV P B Ψ C Γ (.loc l) (.reference a)
   262	    | V_LocLazy {Γ l a} : Ψ l = some (.lazy a) → HasTypeV P B Ψ C Γ (.loc l) (.lazy a)
   263	    /-- V-Map。鍵と値の型は、V-List と同じく、その位置で束縛された型の変数だけを使う。 -/
   264	    | V_Map {Γ ks vs a b} :
   265	        HasTypeEach P B Ψ C Γ ks a → HasTypeEach P B Ψ C Γ vs b → ks.length = vs.length →
   266	        B.sat C a TParam.keyC → Ty.WF C.length a → Ty.WF C.length b →
   267	        HasTypeV P B Ψ C Γ (.mapV ks vs) (.map a b)
   268	    | V_Set {Γ elems a} :
   269	        HasTypeEach P B Ψ C Γ elems a → B.sat C a TParam.keyC → Ty.WF C.length a →
   270	        HasTypeV P B Ψ C Γ (.setV elems) (.set a)
   271	    | V_Bytes {Γ bs} : HasTypeV P B Ψ C Γ (.bytesV bs) .bytes
   272	    /-- V-Dict。実装の型パラメータの制約を、型引数が満たす。 -/
   273	    | V_Dict {Γ i ts vs id} :
   274	        P.impls i = some id → SatAll B C ts id.tparams →
   275	        HasTypeVs P B Ψ C Γ vs (id.dictTys.map (Ty.subst ts [])) →
   276	        HasTypeV P B Ψ C Γ (.dict i ts vs) (.dict id.cls (id.target.subst ts []))
   277	    | V_Super {Γ v cl τ cd s} :
   278	        HasTypeV P B Ψ C Γ v (.dict cl τ) → P.classes cl = some cd → s ∈ cd.supers →
   279	        HasTypeV P B Ψ C Γ (.super v s) (.dict s τ)
   280	    | V_Sub {Γ v a a'} :
   281	        HasTypeV P B Ψ C Γ v a → Ty.Le a a' → HasTypeV P B Ψ C Γ v a'
   282	
   283	  inductive HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) :
   284	      List TParam → List (Option Ty) → List Val → List Ty → Prop
   285	    | nil {Γ} : HasTypeVs P B Ψ C Γ [] []
   286	    | cons {Γ v vs a as} :
   287	        HasTypeV P B Ψ C Γ v a → HasTypeVs P B Ψ C Γ vs as → HasTypeVs P B Ψ C Γ (v :: vs) (a :: as)
   288	
   289	  inductive HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) :
   290	      List TParam → List (Option Ty) → List Val → Ty → Prop
   291	    | nil {Γ a} : HasTypeEach P B Ψ C Γ [] a
   292	    | cons {Γ v vs a} :
   293	        HasTypeV P B Ψ C Γ v a → HasTypeEach P B Ψ C Γ vs a → HasTypeEach P B Ψ C Γ (v :: vs) a
   294	
   295	  /-- `Γ; R ⊢c M : A ! ε`。R は最も内側の関数の戻り値の型で、`none` は `escape` を許さない。 -/
   296	  inductive HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) :
   297	      List TParam → List (Option Ty) → Option Ty → Comp → Ty → Eff → Prop
   298	    | C_Return {Γ R v a} : HasTypeV P B Ψ C Γ v a → HasTypeC P B Ψ C Γ R (.ret v) a Eff.empty
   299	    | C_Sub {Γ R m a a' ε ε'} :
   300	        HasTypeC P B Ψ C Γ R m a ε → Ty.Le a a' → Eff.Sub ε ε' → HasTypeC P B Ψ C Γ R m a' ε'
   301	    | C_Let {Γ R m n a b ε} :
   302	        HasTypeC P B Ψ C Γ R m a ε → HasTypeC P B Ψ C (some a :: Γ) R n b ε →
   303	        HasTypeC P B Ψ C Γ R (.letIn m n) b ε
   304	    | C_App {Γ R f args as b ε} :
   305	        HasTypeV P B Ψ C Γ f (.fn as b ε) → HasTypeVs P B Ψ C Γ args as →
   306	        HasTypeC P B Ψ C Γ R (.app f args) b ε
   307	    | C_If {Γ R v m n a ε} :
   308	        HasTypeV P B Ψ C Γ v (.base .boolean) → HasTypeC P B Ψ C Γ R m a ε →
   309	        HasTypeC P B Ψ C Γ R n a ε → HasTypeC P B Ψ C Γ R (.ite v m n) a ε
   310	    | C_Match {Γ R v arms a b ε} :
   311	        HasTypeV P B Ψ C Γ v a → HasTypeArms P B Ψ C Γ R arms a b ε →
   312	        Exhaustive P a (arms.map Prod.fst) → HasTypeC P B Ψ C Γ R (.match v arms) b ε
   313	    /-- `Γ ⊢c M : A ! { }` のとき `Γ ⊢c lazy M : Lazy[A] ! { }`。M は R を持たない判断で、継続の型を持つ
   314	    変数を除いた環境で検査する（01-12「ストア」「関数の境界と escape」「ハンドラ」）。 -/
   315	    | C_Lazy {Γ R m a} :
   316	        HasTypeC P B Ψ C (hideConts Γ) none m a Eff.empty →
   317	        HasTypeC P B Ψ C Γ R (.lazyC m) (.lazy a) Eff.empty
   318	    /-- `Γ; R ⊢v V : R` のとき、`Γ; R ⊢c escape V : A ! ε`（任意の A と ε）。 -/
   319	    | C_Escape {Γ r v a ε} :
   320	        HasTypeV P B Ψ C Γ v r → Ty.WF C.length a → HasTypeC P B Ψ C Γ (some r) (.escape v) a ε
   321	    /-- C-Use。解放のエフェクト `rel(O_r) = {State}` を ε が含む。 -/
   322	    | C_Use {Γ R v o m b ε} :
   323	        HasTypeV P B Ψ C Γ v (.opaque o) → B.isResource o = true →
   324	        HasTypeC P B Ψ C Γ R m b ε → ε (.name stateEff) = true →
   325	        HasTypeC P B Ψ C Γ R (.use v m) b ε
   326	    /-- C-Handle。 -/
   327	    | C_Handle {Γ R m h t εm ε} :
   328	        HasTypeC P B Ψ C Γ R m t εm → Eff.Sub εm (Eff.union ε (handled P B h)) →
   329	        HasTypeClauses P B Ψ C Γ R h t ε →
   330	        HasTypeC P B Ψ C Γ R (.handle m h) t ε
   331	    /-- C-Resume（節の変数 k）と C-ResumeL（継続の場所 κ）。継続の型の値は、`resume` の第一引数に
   332	    だけ書ける（ADR 0300）。κ に `resume` するときは、κ を作った節の R が、いまの R と等しい。 -/
   333	    | C_Resume {Γ R i v b t ε} :
   334	        Γ[i]? = some (some (.cont b t ε)) → HasTypeV P B Ψ C Γ v b →
   335	        HasTypeC P B Ψ C Γ R (.resume (.var i) v) t ε
   336	    | C_ResumeL {Γ R l v b t ε} :
   337	        Ψ l = some (.cont b t ε R) → HasTypeV P B Ψ C Γ v b →
   338	        HasTypeC P B Ψ C Γ R (.resume (.loc l) v) t ε
   339	    /-- C-Meth。θ = [τ/P, S̄/γ̄, Ē/ρ̄] は、メソッドの型パラメータ γ̄ の番号 `0..g-1` を S̄ に、型クラスの引数 P の
   340	    番号 g を τ に置き換える。メソッドの型パラメータの制約を、型引数 S̄ が満たす。 -/
   341	    | C_Meth {Γ R v cl τ cd m ms ss es ws} :
   342	        HasTypeV P B Ψ C Γ v (.dict cl τ) → P.classes cl = some cd → cd.methods m = some ms →
   343	        SatAll B C ss ms.tparams → es.length = ms.neffs →
   344	        HasTypeVs P B Ψ C Γ ws (ms.params.map (Ty.subst (ss ++ [τ]) es)) →
   345	        HasTypeC P B Ψ C Γ R (.meth v m ss es ws) (ms.ret.subst (ss ++ [τ]) es) (Eff.substRho es ms.eff)
   346	
   347	  inductive HasTypeArms (P : Program) (B : Builtins) (Ψ : StoreTy) :
   348	      List TParam → List (Option Ty) → Option Ty → List (Pat × Comp) → Ty → Ty → Eff → Prop
   349	    | nil {Γ R a b ε} : Ty.WF C.length b → HasTypeArms P B Ψ C Γ R [] a b ε
   350	    | cons {Γ R p m arms a b ε δ} :
   351	        PatTy P p a δ → HasTypeC P B Ψ C (binds δ ++ Γ) R m b ε →
   352	        HasTypeArms P B Ψ C Γ R arms a b ε →
   353	        HasTypeArms P B Ψ C Γ R ((p, m) :: arms) a b ε
   354	
   355	  /-- C-Handle の各節 `op(x̄) k ⇒ N`：`Γ, x̄:Ā, k:Cont(B → T ! ε); R ⊢c N : T ! ε`。操作の型パラメータは、
   356	  節の中の型の変数の番号 `0..k-1` に束縛した、宣言の制約を持つ、ほかの型とは等しくない型の変数である。
   357	  節の外側の Γ・T・R の型は、番号を k だけずらす。 -/
   358	  inductive HasTypeClauses (P : Program) (B : Builtins) (Ψ : StoreTy) :
   359	      List TParam → List (Option Ty) → Option Ty → List Clause → Ty → Eff → Prop
   360	    | nil {Γ R t ε} : HasTypeClauses P B Ψ C Γ R [] t ε
   361	    | cons {Γ R o n k body cs t ε sg} :
   362	        opSig P B o = some sg → n = sg.params.length → k = sg.tparams.length →
   363	        HasTypeC P B Ψ (sg.tparams ++ C)
   364	          (some (.cont sg.ret (t.shift k 0) ε) :: (binds sg.params ++ shiftEnv k Γ))
   365	          (R.map (Ty.shift k 0)) body (t.shift k 0) ε →
   366	        HasTypeClauses P B Ψ C Γ R cs t ε →
   367	        HasTypeClauses P B Ψ C Γ R (.mk o n k body :: cs) t ε
   368	end
   369	
   370	/-! ## 定義とプログラム -/
   371	
   372	/-- 空のストアの型付け。定義の本体は場所を含まない。 -/
   373	def StoreTy.empty : StoreTy := fun _ => none
   374	
   375	/-- 定義に型が付く。`x1:A1, …, xn:An; B ⊢c M : B ! ε`（R := B）。 -/
   376	def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
   377	  HasTypeC P B StoreTy.empty d.tparams (binds d.params) (some d.ret) d.body d.ret d.eff
   378	
   379	/-- D-Impl のメソッドの型 `Ājθ`・`Bjθ`（θ = [τ/P]）。型クラスの引数 P の番号 g（メソッドの型パラメータの
   380	個数）を、実装の対象 τ に置き換える。 -/
   381	def ImplDecl.methTy (id : ImplDecl) (ms : MethSig) (t : Ty) : Ty :=
   382	  t.substAt ms.tparams.length [id.target] []
   383	
   384	/-- 実装の定義に型が付く（D-Impl）。実装の定義は、型クラスが宣言したメソッドと上位の型クラスについてだけ、
   385	本体と辞書を持つ。型クラスの各メソッドの本体を、実装の型パラメータの外側にメソッドの
   386	型パラメータを加えた制約の並びと、辞書の引数 d̄ の後にメソッドの引数 x̄ を並べた環境で、R := Bjθ として検査する。
   387	上位の型クラスの各辞書 U を、辞書の引数 d̄ の環境で検査する。 -/
   388	def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
   389	  ∃ cd, P.classes id.cls = some cd ∧
   390	    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
   391	    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
   392	    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
   393	      HasTypeC P B StoreTy.empty (ms.tparams ++ id.tparams)
   394	        (binds (id.dictTys.map (Ty.shift ms.tparams.length 0) ++ ms.params.map (id.methTy ms)))
   395	        (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret) ms.eff) ∧
   396	    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
   397	      HasTypeV P B StoreTy.empty id.tparams (binds id.dictTys) u (.dict s id.target))
   398	
   399	def Program.WellTyped (P : Program) (B : Builtins) : Prop :=
   400	  (∀ f d, P.defs f = some d → d.WellTyped P B) ∧ (∀ i id, P.impls i = some id → id.WellTyped P B)
   401	
   402	end Benitoite.Release
```

### formal/Benitoite/Release/WellFormed.lean

```lean
     1	import Benitoite.Release.Typing
     2	
     3	/-!
     4	# 型とエフェクトの変数の範囲（段階 B）
     5	
     6	型の変数は de Bruijn の番号で表す（`Syntax.lean`）。`VarsIn n pe` は、項の中の型の変数の番号が、その位置で
     7	束縛されている個数（外側の `n` に、囲む節が束縛する個数を足したもの）より小さく、エフェクト変数の番号が
     8	`pe` を満たすことを表す。
     9	
    10	実行中の状態の項は、型の変数を含まない（`n = 0`）。01-12 では、実行は `⟨main[;](), [], ∅⟩` から
    11	始まり、型パラメータを束縛しない環境で型が付くので、この条件は暗黙に成り立っている。形式化では、
    12	E-Fun と E-Op が閉じた型だけを置き換えることを、この条件で示す。
    13	-/
    14	
    15	namespace Benitoite.Release
    16	
    17	def Eff.RhosIn (pe : Nat → Prop) (ε : Eff) : Prop :=
    18	  ∀ i, ε (.rho i) = true → pe i
    19	
    20	mutual
    21	  /-- 型の中の型の変数の番号が `n` より小さく、エフェクト変数の番号が `pe` を満たし、継続の型を含まない
    22	  （項の中に書ける型である）。 -/
    23	  def Ty.VarsIn (n : Nat) (pe : Nat → Prop) : Ty → Prop
    24	    | .base _ => True
    25	    | .opaque _ => True
    26	    | .data _ args => Ty.VarsInList n pe args
    27	    | .list a => Ty.VarsIn n pe a
    28	    | .fn params ret eff => Ty.VarsInList n pe params ∧ Ty.VarsIn n pe ret ∧ Eff.RhosIn pe eff
    29	    | .tvar i => i < n
    30	    | .reference a => Ty.VarsIn n pe a
    31	    | .lazy a => Ty.VarsIn n pe a
    32	    -- 継続の型は、項に書く型に含めない（01-12「ハンドラ」、ADR 0303）。
    33	    | .cont _ _ _ => False
    34	    | .map a b => Ty.VarsIn n pe a ∧ Ty.VarsIn n pe b
    35	    | .set a => Ty.VarsIn n pe a
    36	    | .bytes => True
    37	    | .dict _ τ => Ty.VarsIn n pe τ
    38	    | .tapp i args => i < n ∧ Ty.VarsInList n pe args
    39	    | .ctor _ => True
    40	
    41	  def Ty.VarsInList (n : Nat) (pe : Nat → Prop) : List Ty → Prop
    42	    | [] => True
    43	    | a :: as => Ty.VarsIn n pe a ∧ Ty.VarsInList n pe as
    44	end
    45	
    46	def Eff.RhosInList (pe : Nat → Prop) : List Eff → Prop
    47	  | [] => True
    48	  | e :: es => Eff.RhosIn pe e ∧ Eff.RhosInList pe es
    49	
    50	mutual
    51	  def Val.VarsIn (n : Nat) (pe : Nat → Prop) : Val → Prop
    52	    | .var _ => True
    53	    | .const _ => True
    54	    | .fnRef _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    55	    | .prim _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    56	    | .lam params body => Ty.VarsInList n pe params ∧ Comp.VarsIn n pe body
    57	    | .con _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInList n pe args
    58	    | .list elems => Val.VarsInList n pe elems
    59	    | .op _ tys => Ty.VarsInList n pe tys
    60	    | .loc _ => True
    61	    | .mapV ks vs => Val.VarsInList n pe ks ∧ Val.VarsInList n pe vs
    62	    | .setV elems => Val.VarsInList n pe elems
    63	    | .bytesV _ => True
    64	    | .dict _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInList n pe args
    65	    | .super v _ => Val.VarsIn n pe v
    66	
    67	  def Val.VarsInList (n : Nat) (pe : Nat → Prop) : List Val → Prop
    68	    | [] => True
    69	    | v :: vs => Val.VarsIn n pe v ∧ Val.VarsInList n pe vs
    70	
    71	  def Comp.VarsIn (n : Nat) (pe : Nat → Prop) : Comp → Prop
    72	    | .ret v => Val.VarsIn n pe v
    73	    | .letIn m m' => Comp.VarsIn n pe m ∧ Comp.VarsIn n pe m'
    74	    | .app f args => Val.VarsIn n pe f ∧ Val.VarsInList n pe args
    75	    | .ite v m m' => Val.VarsIn n pe v ∧ Comp.VarsIn n pe m ∧ Comp.VarsIn n pe m'
    76	    | .match v arms => Val.VarsIn n pe v ∧ Comp.VarsInArms n pe arms
    77	    | .lazyC m => Comp.VarsIn n pe m
    78	    | .escape v => Val.VarsIn n pe v
    79	    | .use v m => Val.VarsIn n pe v ∧ Comp.VarsIn n pe m
    80	    | .handle m h => Comp.VarsIn n pe m ∧ Clause.VarsInList n pe h
    81	    | .resume k v => Val.VarsIn n pe k ∧ Val.VarsIn n pe v
    82	    | .meth d _ tys effs args =>
    83	        Val.VarsIn n pe d ∧ Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs ∧ Val.VarsInList n pe args
    84	
    85	  def Comp.VarsInArms (n : Nat) (pe : Nat → Prop) : List (Pat × Comp) → Prop
    86	    | [] => True
    87	    | (_, m) :: arms => Comp.VarsIn n pe m ∧ Comp.VarsInArms n pe arms
    88	
    89	  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
    90	  def Clause.VarsInList (n : Nat) (pe : Nat → Prop) : List Clause → Prop
    91	    | [] => True
    92	    | .mk _ _ k m :: cs => Comp.VarsIn (n + k) pe m ∧ Clause.VarsInList n pe cs
    93	end
    94	
    95	/-! ## 宣言の変数の範囲 -/
    96	
    97	/-- 関数の定義の型（引数、戻り値、エフェクト）と本体は、宣言した型パラメータとエフェクト変数だけを使う。
    98	本体の範囲は、E-Fun の後の状態が型の変数を含まないことに要る。 -/
    99	def Def.Scoped (d : Def) : Prop :=
   100	  Ty.VarsInList d.ntys (· < d.neffs) d.params ∧ Ty.VarsIn d.ntys (· < d.neffs) d.ret ∧
   101	    Eff.RhosIn (· < d.neffs) d.eff ∧ Comp.VarsIn d.ntys (· < d.neffs) d.body
   102	
   103	def ConDecl.Scoped (cd : ConDecl) : Prop :=
   104	  Ty.VarsInList cd.ntys (fun _ => False) cd.args
   105	
   106	def OpDecl.Scoped (od : OpDecl) : Prop :=
   107	  Ty.VarsInList od.tparams.length (fun _ => False) od.params ∧
   108	    Ty.VarsIn od.tparams.length (fun _ => False) od.ret
   109	
   110	def PrimSig.Scoped (s : PrimSig) : Prop :=
   111	  Ty.VarsInList s.ntys (· < s.neffs) s.params ∧ Ty.VarsIn s.ntys (· < s.neffs) s.ret ∧
   112	    Eff.RhosIn (· < s.neffs) s.eff
   113	
   114	/-- メソッドの型は、メソッドの型パラメータ（番号 `0..g-1`）と型クラスの引数（番号 g）と、メソッドのエフェクト変数
   115	だけを使う。 -/
   116	def MethSig.Scoped (ms : MethSig) : Prop :=
   117	  Ty.VarsInList (ms.tparams.length + 1) (· < ms.neffs) ms.params ∧
   118	    Ty.VarsIn (ms.tparams.length + 1) (· < ms.neffs) ms.ret ∧ Eff.RhosIn (· < ms.neffs) ms.eff
   119	
   120	def ClassDecl.Scoped (cd : ClassDecl) : Prop :=
   121	  ∀ m ms, cd.methods m = some ms → ms.Scoped
   122	
   123	/-- 実装の定義の辞書の引数の型、対象、上位の型クラスの辞書は、実装の型パラメータだけを使い、エフェクト変数を
   124	使わない。メソッドの本体は、メソッドの型パラメータと実装の型パラメータ、メソッドのエフェクト変数だけを使う。 -/
   125	def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop :=
   126	  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
   127	    Ty.VarsIn id.tparams.length (fun _ => False) id.target ∧
   128	    (∀ s u, id.supers s = some u → Val.VarsIn id.tparams.length (fun _ => False) u) ∧
   129	    (∀ cd m ms body, P.classes id.cls = some cd → cd.methods m = some ms → id.methods m = some body →
   130	      Comp.VarsIn (ms.tparams.length + id.tparams.length) (· < ms.neffs) body)
   131	
   132	def Program.WellFormed (P : Program) : Prop :=
   133	  (∀ f d, P.defs f = some d → d.Scoped) ∧ (∀ c cd, P.cons c = some cd → cd.Scoped) ∧
   134	    (∀ o od, P.ops o = some od → od.Scoped) ∧ (∀ cl cd, P.classes cl = some cd → cd.Scoped) ∧
   135	    (∀ i id, P.impls i = some id → id.Scoped P)
   136	
   137	/-- 01-12 の性質 3 の「M がエフェクト変数を含まない」と、型パラメータを束縛しない環境の項であること。 -/
   138	def Comp.ClosedNoEffVars (m : Comp) : Prop :=
   139	  Comp.VarsIn 0 (fun _ => False) m
   140	
   141	end Benitoite.Release
```

### formal/Benitoite/Release/Semantics.lean

```lean
     1	import Benitoite.Release.WellFormed
     2	
     3	/-!
     4	# 実行の規則（段階 B）
     5	
     6	設計書 01-12 の「実行の規則」を、「初回リリース版の拡張」のストア、`escape`、`with`、プロセスの終了、
     7	ハンドラの規則で広げたものを書き写す。構成子の名前は 01-12 の規則の名前に対応させる。
     8	
     9	01-12 との表現の違い:
    10	
    11	- E-Super は、値の等しさではなく、メソッドの呼び出しの辞書から `↑` を一段取り出す遷移として定める（ADR 0305）。
    12	- ストアは、場所から中身への関数とする。有限であることは、ストアの型付け（`StoreOk`）の条件にする。
    13	- 組み込みの操作の E-Op は、規則 E-OpPrim として分けて書く。
    14	- IO の事象は、組み込みの関数の名前、引数、応答からなり、型引数とエフェクト引数を含めない（ADR 0296）。
    15	  応答の関係は、型引数とエフェクト引数も受け取る。
    16	- `escape`、実行時エラーの状態、終了の状態が `drop κ` の枠を通るときの扱い（01-12「ハンドラ」の箇条）を、
    17	  E-EscDrop・E-EscDropRel・E-ErrDrop・E-ErrDropRel・E-ExitDrop・E-ExitDropRel の規則として書く。
    18	-/
    19	
    20	namespace Benitoite.Release
    21	
    22	/-- 継続の枠。 -/
    23	inductive Frame where
    24	  | letF (n : Comp)
    25	  | mark
    26	  | update (l : Nat)
    27	  | release (v : Val)
    28	  | handleF (h : List Clause)
    29	  | drop (k : Nat)
    30	
    31	abbrev Cont := List Frame
    32	
    33	/-- ストアの中身。 -/
    34	inductive Cell where
    35	  | val (v : Val)
    36	  | thunk (m : Comp)
    37	  | done (v : Val)
    38	  | cont (k : Cont)
    39	  | used
    40	
    41	abbrev Store := Nat → Option Cell
    42	
    43	def Store.empty : Store := fun _ => none
    44	
    45	def Store.set (σ : Store) (l : Nat) (c : Cell) : Store := fun l' => if l' = l then some c else σ l'
    46	
    47	/-- 状態。 -/
    48	inductive State where
    49	  | run (m : Comp) (k : Cont) (σ : Store)
    50	  | error (rs : List ErrKind) (k : Cont) (σ : Store)
    51	  | exit (n : Int) (rs : List ErrKind) (k : Cont) (σ : Store)
    52	
    53	/-- 事象。IO の事象 `b(W̄) ↦ …` と、解放の事象 `release(V) ↦ ok | error(r)`。 -/
    54	inductive Event where
    55	  | io (b : PrimName) (ws : List Val) (o : Outcome)
    56	  | release (v : Val) (r : Option ErrKind)
    57	
    58	/-- `mark ▷ K`。 -/
    59	def markPush : Cont → Cont
    60	  | .mark :: k => .mark :: k
    61	  | k => .mark :: k
    62	
    63	/-- `releases(K)`：K の中の `release` の枠と `drop` の枠だけを、順序を保って並べた継続。 -/
    64	def releases : Cont → Cont
    65	  | [] => []
    66	  | .release v :: k => .release v :: releases k
    67	  | .drop κ :: k => .drop κ :: releases k
    68	  | _ :: k => releases k
    69	
    70	/-- 節の並びから、操作 op の節を探す。 -/
    71	def findClause (h : List Clause) (o : OpRef) : Option Clause :=
    72	  h.find? (fun c => c.op == o)
    73	
    74	/-- 継続の中に、操作 op の節を持つ `handle` の枠がない。 -/
    75	def NoHandler (k : Cont) (o : OpRef) : Prop :=
    76	  ∀ h, Frame.handleF h ∈ k → handles h o = false
    77	
    78	/-- 状態が、継続のどの `handle` の枠も処理しない利用者の操作を呼ぶ。 -/
    79	def UnhandledOp : State → Prop
    80	  | .run (.app (.op o _) _) k _ => NoHandler k (.user o)
    81	  | _ => False
    82	
    83	/-- 継続を、op を処理する最も内側の `handle` の枠で分ける。`K = K1 ++ (handle □ with H) :: K2` で、
    84	K1 の中の `handle` の枠はどれも op の節を持たない。 -/
    85	def SplitAt (o : OpRef) (k k1 : Cont) (h : List Clause) (k2 : Cont) : Prop :=
    86	  k = k1 ++ .handleF h :: k2 ∧ handles h o = true ∧ NoHandler k1 o
    87	
    88	/-- 上位の型クラスの辞書の一歩の取り出し `V ⇝ V'`（E-Super）。`I[T̄](V̄)↑S ⇝ U[T̄/β̄][V̄/d̄]`（U は I の定義の
    89	S の辞書）であり、`V ⇝ V'` なら `V↑S ⇝ V'↑S` である。 -/
    90	def Val.superStep (P : Program) : Val → Option Val
    91	  | .super (.dict i ts vs) s =>
    92	      match P.impls i with
    93	      | some id => (id.supers s).map fun u => (u.substTy ts []).instantiate vs
    94	      | none => none
    95	  | .super v s => (Val.superStep P v).map fun v' => .super v' s
    96	  | _ => none
    97	
    98	/-- 継続の二度目の再開の実行時エラーの種類 `r_resume`。 -/
    99	def rResume : ErrKind := "ResumeTwice"
   100	
   101	/-- 遷移。 -/
   102	inductive Step (P : Program) (B : Builtins) : State → Option Event → State → Prop
   103	  | E_Let {m n k σ} : Step P B (.run (.letIn m n) k σ) none (.run m (.letF n :: k) σ)
   104	  | E_Return {v n k σ} :
   105	      Step P B (.run (.ret v) (.letF n :: k) σ) none (.run (n.instantiate [v]) k σ)
   106	  | E_Lam {ps body ws k σ} :
   107	      ws.length = ps.length →
   108	      Step P B (.run (.app (.lam ps body) ws) k σ) none (.run (body.instantiate ws) (markPush k) σ)
   109	  | E_Fun {f ts es ws k σ d} :
   110	      P.defs f = some d →
   111	      ws.length = d.params.length → ts.length = d.ntys → es.length = d.neffs →
   112	      Step P B (.run (.app (.fnRef f ts es) ws) k σ) none
   113	        (.run ((d.body.substTy ts es).instantiate ws) (markPush k) σ)
   114	  /-- E-Meth。メソッドの本体の型の変数は、メソッドの型パラメータ（番号 `0..g-1`）を S̄ に、実装の型パラメータを
   115	  T̄ に置き換える。値の変数は、辞書の引数 d̄ を V̄ に、メソッドの引数 x̄ を W̄ に置き換える。 -/
   116	  | E_Meth {i ts vs m ss es ws k σ id body cd ms} :
   117	      P.impls i = some id → id.methods m = some body → P.classes id.cls = some cd →
   118	      cd.methods m = some ms →
   119	      ws.length = ms.params.length → vs.length = id.dictTys.length → ts.length = id.tparams.length →
   120	      ss.length = ms.tparams.length → es.length = ms.neffs →
   121	      Step P B (.run (.meth (.dict i ts vs) m ss es ws) k σ) none
   122	        (.run ((body.substTy (ss ++ ts) es).instantiate (vs ++ ws)) (markPush k) σ)
   123	  /-- E-Super。メソッドの呼び出しの辞書が上位の型クラスの辞書 `V↑S` のとき、`↑` を一段取り出す（ADR 0305）。 -/
   124	  | E_Super {v v' m ss es ws k σ} :
   125	      v.superStep P = some v' →
   126	      Step P B (.run (.meth v m ss es ws) k σ) none (.run (.meth v' m ss es ws) k σ)
   127	  | E_IfT {m n k σ} :
   128	      Step P B (.run (.ite (.const (.boolean true)) m n) k σ) none (.run m k σ)
   129	  | E_IfF {m n k σ} :
   130	      Step P B (.run (.ite (.const (.boolean false)) m n) k σ) none (.run n k σ)
   131	  | E_Match {v arms k σ m ws} :
   132	      firstMatch v arms = some (m, ws) →
   133	      Step P B (.run (.match v arms) k σ) none (.run (m.instantiate ws) k σ)
   134	  | E_Prim {b ts es ws k σ s v} :
   135	      B.sig b = some s → s.kind = .pure → B.delta b ts es ws = some (.val v) →
   136	      Step P B (.run (.app (.prim b ts es) ws) k σ) none (.run (.ret v) k σ)
   137	  | E_Err {b ts es ws k σ s r} :
   138	      B.sig b = some s → s.kind = .pure → B.delta b ts es ws = some (.err r) →
   139	      Step P B (.run (.app (.prim b ts es) ws) k σ) none (.error [r] k σ)
   140	  /-- E-IO。組み込みの操作 b は、継続に b の節を持つ `handle` の枠がないときにだけ、E-IO を使う。 -/
   141	  | E_IO {b ts es ws k σ s v} :
   142	      B.sig b = some s → s.kind = .io → NoHandler k (.prim b) →
   143	      B.ioResponse b ts es ws (.val v) →
   144	      Step P B (.run (.app (.prim b ts es) ws) k σ) (some (.io b ws (.val v))) (.run (.ret v) k σ)
   145	  /-- E-IOErr。プロセスの終了の関数の、許可がないときの応答も `error(r)` である（01-12「プロセスの終了」）。 -/
   146	  | E_IOErr {b ts es ws k σ s r} :
   147	      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → NoHandler k (.prim b) →
   148	      B.ioResponse b ts es ws (.err r) →
   149	      Step P B (.run (.app (.prim b ts es) ws) k σ) (some (.io b ws (.err r))) (.error [r] k σ)
   150	  /-- E-Exit。終了状態を指定したプロセスの終了の関数にだけ使う。 -/
   151	  | E_Exit {b ts es ws k σ s n} :
   152	      B.sig b = some s → s.kind = .exit → NoHandler k (.prim b) →
   153	      B.ioResponse b ts es ws (.exit n) →
   154	      Step P B (.run (.app (.prim b ts es) ws) k σ) (some (.io b ws (.exit n))) (.exit n [] k σ)
   155	  -- ストア
   156	  | E_RefNew {b ts es v k σ s l} :
   157	      B.sig b = some s → s.kind = .refNew → σ l = none →
   158	      Step P B (.run (.app (.prim b ts es) [v]) k σ) none (.run (.ret (.loc l)) k (σ.set l (.val v)))
   159	  | E_RefGet {b ts es l k σ s v} :
   160	      B.sig b = some s → s.kind = .refGet → σ l = some (.val v) →
   161	      Step P B (.run (.app (.prim b ts es) [.loc l]) k σ) none (.run (.ret v) k σ)
   162	  | E_RefSet {b ts es l v k σ s} :
   163	      B.sig b = some s → s.kind = .refSet →
   164	      Step P B (.run (.app (.prim b ts es) [.loc l, v]) k σ) none
   165	        (.run (.ret (.const .unit)) k (σ.set l (.val v)))
   166	  /-- `Reference.update[A](ℓ, V)` は `let x ⇐ Reference.get[A](ℓ) in let y ⇐ V(x) in Reference.set[A](ℓ, y)`
   167	  と同じく遷移する。 -/
   168	  | E_RefUpdate {b ts es l f k σ s} :
   169	      B.sig b = some s → s.kind = .refUpdate →
   170	      Step P B (.run (.app (.prim b ts es) [.loc l, f]) k σ) none
   171	        (.run (.letIn (.app (.prim B.refGet ts []) [.loc l])
   172	                (.letIn (.app (f.rename (· + 1)) [.var 0])
   173	                  (.app (.prim B.refSet ts []) [.loc l, .var 0]))) k σ)
   174	  | E_Lazy {m k σ l} :
   175	      σ l = none →
   176	      Step P B (.run (.lazyC m) k σ) none (.run (.ret (.loc l)) k (σ.set l (.thunk m)))
   177	  | E_ForceDone {b ts es l k σ s v} :
   178	      B.sig b = some s → s.kind = .force → σ l = some (.done v) →
   179	      Step P B (.run (.app (.prim b ts es) [.loc l]) k σ) none (.run (.ret v) k σ)
   180	  | E_Force {b ts es l k σ s m} :
   181	      B.sig b = some s → s.kind = .force → σ l = some (.thunk m) →
   182	      Step P B (.run (.app (.prim b ts es) [.loc l]) k σ) none (.run m (.update l :: k) σ)
   183	  | E_Update {v l k σ} :
   184	      Step P B (.run (.ret v) (.update l :: k) σ) none (.run (.ret v) k (σ.set l (.done v)))
   185	  -- 関数の境界と `escape`
   186	  | E_Mark {v k σ} : Step P B (.run (.ret v) (.mark :: k) σ) none (.run (.ret v) k σ)
   187	  | E_EscLet {v n k σ} :
   188	      Step P B (.run (.escape v) (.letF n :: k) σ) none (.run (.escape v) k σ)
   189	  | E_EscHandle {v h k σ} :
   190	      Step P B (.run (.escape v) (.handleF h :: k) σ) none (.run (.escape v) k σ)
   191	  | E_EscMark {v k σ} : Step P B (.run (.escape v) (.mark :: k) σ) none (.run (.ret v) k σ)
   192	  -- 解放の枠
   193	  | E_Use {v m k σ} : Step P B (.run (.use v m) k σ) none (.run m (.release v :: k) σ)
   194	  | E_Release {w v k σ} :
   195	      B.releaseResponse v none →
   196	      Step P B (.run (.ret w) (.release v :: k) σ) (some (.release v none)) (.run (.ret w) k σ)
   197	  | E_RelErr {w v k σ r} :
   198	      B.releaseResponse v (some r) →
   199	      Step P B (.run (.ret w) (.release v :: k) σ) (some (.release v (some r))) (.error [r] k σ)
   200	  | E_EscRel {w v k σ} :
   201	      B.releaseResponse v none →
   202	      Step P B (.run (.escape w) (.release v :: k) σ) (some (.release v none)) (.run (.escape w) k σ)
   203	  | E_EscRelErr {w v k σ r} :
   204	      B.releaseResponse v (some r) →
   205	      Step P B (.run (.escape w) (.release v :: k) σ) (some (.release v (some r))) (.error [r] k σ)
   206	  -- 実行時エラーの状態
   207	  | E_ErrPopLet {rs n k σ} : Step P B (.error rs (.letF n :: k) σ) none (.error rs k σ)
   208	  | E_ErrPopMark {rs k σ} : Step P B (.error rs (.mark :: k) σ) none (.error rs k σ)
   209	  | E_ErrPopUpdate {rs l k σ} : Step P B (.error rs (.update l :: k) σ) none (.error rs k σ)
   210	  | E_ErrPopHandle {rs h k σ} : Step P B (.error rs (.handleF h :: k) σ) none (.error rs k σ)
   211	  | E_ErrRel {rs v k σ} :
   212	      B.releaseResponse v none →
   213	      Step P B (.error rs (.release v :: k) σ) (some (.release v none)) (.error rs k σ)
   214	  | E_ErrRelErr {rs v k σ r} :
   215	      B.releaseResponse v (some r) →
   216	      Step P B (.error rs (.release v :: k) σ) (some (.release v (some r))) (.error (rs ++ [r]) k σ)
   217	  -- プロセスの終了
   218	  | E_ExitPopLet {n rs m k σ} : Step P B (.exit n rs (.letF m :: k) σ) none (.exit n rs k σ)
   219	  | E_ExitPopMark {n rs k σ} : Step P B (.exit n rs (.mark :: k) σ) none (.exit n rs k σ)
   220	  | E_ExitPopUpdate {n rs l k σ} : Step P B (.exit n rs (.update l :: k) σ) none (.exit n rs k σ)
   221	  | E_ExitPopHandle {n rs h k σ} : Step P B (.exit n rs (.handleF h :: k) σ) none (.exit n rs k σ)
   222	  | E_ExitRel {n rs v k σ} :
   223	      B.releaseResponse v none →
   224	      Step P B (.exit n rs (.release v :: k) σ) (some (.release v none)) (.exit n rs k σ)
   225	  | E_ExitRelErr {n rs v k σ r} :
   226	      B.releaseResponse v (some r) →
   227	      Step P B (.exit n rs (.release v :: k) σ) (some (.release v (some r))) (.exit n (rs ++ [r]) k σ)
   228	  -- ハンドラ
   229	  | E_Handle {m h k σ} : Step P B (.run (.handle m h) k σ) none (.run m (.handleF h :: k) σ)
   230	  | E_HRet {v h k σ} : Step P B (.run (.ret v) (.handleF h :: k) σ) none (.run (.ret v) k σ)
   231	  /-- E-Op（利用者が宣言した操作）。節の本体に、操作の型引数の置き換えも施す。 -/
   232	  | E_Op {o ts ws k σ k1 h k2 c κ} :
   233	      SplitAt (.user o) k k1 h k2 → findClause h (.user o) = some c → σ κ = none →
   234	      Step P B (.run (.app (.op o ts) ws) k σ) none
   235	        (.run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
   236	          (σ.set κ (.cont (k1 ++ [.handleF h]))))
   237	  /-- E-Op（組み込みの操作）。継続に b の節を持つ `handle` の枠があるときは、E-IO の代わりに使う。 -/
   238	  | E_OpPrim {b ts es ws k σ s k1 h k2 c κ} :
   239	      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
   240	      SplitAt (.prim b) k k1 h k2 → findClause h (.prim b) = some c → σ κ = none →
   241	      Step P B (.run (.app (.prim b ts es) ws) k σ) none
   242	        (.run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
   243	          (σ.set κ (.cont (k1 ++ [.handleF h]))))
   244	  | E_Resume {κ v k σ k'} :
   245	      σ κ = some (.cont k') →
   246	      Step P B (.run (.resume (.loc κ) v) k σ) none (.run (.ret v) (k' ++ k) (σ.set κ .used))
   247	  | E_ResumeErr {κ v k σ} :
   248	      σ κ = some .used →
   249	      Step P B (.run (.resume (.loc κ) v) k σ) none (.error [rResume] k σ)
   250	  | E_Drop {v κ k σ} :
   251	      σ κ = some .used →
   252	      Step P B (.run (.ret v) (.drop κ :: k) σ) none (.run (.ret v) k σ)
   253	  | E_DropRel {v κ k σ k'} :
   254	      σ κ = some (.cont k') →
   255	      Step P B (.run (.ret v) (.drop κ :: k) σ) none
   256	        (.run (.ret v) (releases k' ++ k) (σ.set κ .used))
   257	  /-- `escape`、実行時エラーの状態、終了の状態が `drop κ` の枠を通るとき（01-12「ハンドラ」の箇条）。 -/
   258	  | E_EscDrop {v κ k σ} :
   259	      σ κ = some .used →
   260	      Step P B (.run (.escape v) (.drop κ :: k) σ) none (.run (.escape v) k σ)
   261	  | E_EscDropRel {v κ k σ k'} :
   262	      σ κ = some (.cont k') →
   263	      Step P B (.run (.escape v) (.drop κ :: k) σ) none
   264	        (.run (.escape v) (releases k' ++ k) (σ.set κ .used))
   265	  | E_ErrDrop {rs κ k σ} :
   266	      σ κ = some .used → Step P B (.error rs (.drop κ :: k) σ) none (.error rs k σ)
   267	  | E_ErrDropRel {rs κ k σ k'} :
   268	      σ κ = some (.cont k') →
   269	      Step P B (.error rs (.drop κ :: k) σ) none (.error rs (releases k' ++ k) (σ.set κ .used))
   270	  | E_ExitDrop {n rs κ k σ} :
   271	      σ κ = some .used → Step P B (.exit n rs (.drop κ :: k) σ) none (.exit n rs k σ)
   272	  | E_ExitDropRel {n rs κ k σ k'} :
   273	      σ κ = some (.cont k') →
   274	      Step P B (.exit n rs (.drop κ :: k) σ) none (.exit n rs (releases k' ++ k) (σ.set κ .used))
   275	
   276	inductive Steps (P : Program) (B : Builtins) : State → State → Prop
   277	  | refl {s} : Steps P B s s
   278	  | step {s l s' s''} : Step P B s l s' → Steps P B s' s'' → Steps P B s s''
   279	
   280	/-- 実行を終えた状態。`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)`。 -/
   281	def State.Final : State → Prop
   282	  | .run (.ret _) [] _ => True
   283	  | .error _ [] _ => True
   284	  | .exit _ _ [] _ => True
   285	  | _ => False
   286	
   287	/-! ## 遷移を計算する関数 -/
   288	
   289	/-- IO の応答を選ぶ関数（段階 A と同じく、同じ入力には同じ応答を返す）。 -/
   290	abbrev Oracle := PrimName → List Ty → List Eff → List Val → Outcome
   291	
   292	/-- 継続を、op を処理する最も内側の `handle` の枠で分ける。 -/
   293	def splitHandler (o : OpRef) : Cont → Option (Cont × List Clause × Cont)
   294	  | [] => none
   295	  | .handleF h :: k =>
   296	      if handles h o then some ([], h, k)
   297	      else (splitHandler o k).map fun (k1, h', k2) => (.handleF h :: k1, h', k2)
   298	  | f :: k => (splitHandler o k).map fun (k1, h', k2) => (f :: k1, h', k2)
   299	
   300	/-- 解放の枠を一つ処理する遷移（`ret`・`escape`・実行時エラー・終了の状態で共通）。 -/
   301	def releaseStep (rel : Val → Option ErrKind) (v : Val) (ok : State) (err : ErrKind → State) :
   302	    Option (Option Event × State) :=
   303	  match rel v with
   304	  | none => some (some (.release v none), ok)
   305	  | some r => some (some (.release v (some r)), err r)
   306	
   307	/-- 一歩の遷移を計算する関数。IO の応答は `oracle`、解放の応答は `rel`、新しい場所は `fresh` から得る。
   308	`step_sound`（`Theorems.lean`）で、`oracle`・`rel`・`fresh` が条件を満たすとき `Step` の遷移であることを示す。 -/
   309	def step (P : Program) (B : Builtins) (oracle : Oracle) (rel : Val → Option ErrKind)
   310	    (fresh : Store → Nat) : State → Option (Option Event × State)
   311	  | .run (.letIn m n) k σ => some (none, .run m (.letF n :: k) σ)
   312	  | .run (.ret v) (.letF n :: k) σ => some (none, .run (n.instantiate [v]) k σ)
   313	  | .run (.ret v) (.mark :: k) σ => some (none, .run (.ret v) k σ)
   314	  | .run (.ret v) (.update l :: k) σ => some (none, .run (.ret v) k (σ.set l (.done v)))
   315	  | .run (.ret w) (.release v :: k) σ =>
   316	      releaseStep rel v (.run (.ret w) k σ) (fun r => .error [r] k σ)
   317	  | .run (.ret v) (.handleF _ :: k) σ => some (none, .run (.ret v) k σ)
   318	  | .run (.ret v) (.drop κ :: k) σ =>
   319	      match σ κ with
   320	      | some .used => some (none, .run (.ret v) k σ)
   321	      | some (.cont k') => some (none, .run (.ret v) (releases k' ++ k) (σ.set κ .used))
   322	      | _ => none
   323	  | .run (.ret _) [] _ => none
   324	  | .run (.app (.lam ps body) ws) k σ =>
   325	      if ws.length = ps.length then some (none, .run (body.instantiate ws) (markPush k) σ) else none
   326	  | .run (.app (.fnRef f ts es) ws) k σ =>
   327	      match P.defs f with
   328	      | some d =>
   329	          if ws.length = d.params.length ∧ ts.length = d.ntys ∧ es.length = d.neffs then
   330	            some (none, .run ((d.body.substTy ts es).instantiate ws) (markPush k) σ)
   331	          else none
   332	      | none => none
   333	  | .run (.app (.op o ts) ws) k σ =>
   334	      match splitHandler (.user o) k with
   335	      | some (k1, h, k2) =>
   336	          match findClause h (.user o) with
   337	          | some c =>
   338	              let κ := fresh σ
   339	              some (none, .run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
   340	                (σ.set κ (.cont (k1 ++ [.handleF h]))))
   341	          | none => none
   342	      | none => none
   343	  | .run (.app (.prim b ts es) ws) k σ =>
   344	      match B.sig b with
   345	      | none => none
   346	      | some s =>
   347	          match s.kind, ws with
   348	          | .pure, _ =>
   349	              match B.delta b ts es ws with
   350	              | some (.val v) => some (none, .run (.ret v) k σ)
   351	              | some (.err r) => some (none, .error [r] k σ)
   352	              | _ => none
   353	          | .io, _ | .exit, _ =>
   354	              match splitHandler (.prim b) k with
   355	              | some (k1, h, k2) =>
   356	                  match findClause h (.prim b) with
   357	                  | some c =>
   358	                      let κ := fresh σ
   359	                      some (none, .run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ]))
   360	                        (.drop κ :: k2) (σ.set κ (.cont (k1 ++ [.handleF h]))))
   361	                  | none => none
   362	              | none =>
   363	                  match s.kind, oracle b ts es ws with
   364	                  | .io, .val v => some (some (.io b ws (.val v)), .run (.ret v) k σ)
   365	                  | _, .err r => some (some (.io b ws (.err r)), .error [r] k σ)
   366	                  | .exit, .exit n => some (some (.io b ws (.exit n)), .exit n [] k σ)
   367	                  | _, _ => none
   368	          | .refNew, [v] =>
   369	              let l := fresh σ
   370	              some (none, .run (.ret (.loc l)) k (σ.set l (.val v)))
   371	          | .refGet, [.loc l] =>
   372	              match σ l with
   373	              | some (.val v) => some (none, .run (.ret v) k σ)
   374	              | _ => none
   375	          | .refSet, [.loc l, v] => some (none, .run (.ret (.const .unit)) k (σ.set l (.val v)))
   376	          | .refUpdate, [.loc l, f] =>
   377	              some (none, .run (.letIn (.app (.prim B.refGet ts []) [.loc l])
   378	                (.letIn (.app (f.rename (· + 1)) [.var 0])
   379	                  (.app (.prim B.refSet ts []) [.loc l, .var 0]))) k σ)
   380	          | .force, [.loc l] =>
   381	              match σ l with
   382	              | some (.done v) => some (none, .run (.ret v) k σ)
   383	              | some (.thunk m) => some (none, .run m (.update l :: k) σ)
   384	              | _ => none
   385	          | _, _ => none
   386	  | .run (.app _ _) _ _ => none
   387	  | .run (.meth (.dict i ts vs) m ss es ws) k σ =>
   388	      match P.impls i with
   389	      | some id =>
   390	          match id.methods m, P.classes id.cls with
   391	          | some body, some cd =>
   392	              match cd.methods m with
   393	              | some ms =>
   394	                  if ws.length = ms.params.length ∧ vs.length = id.dictTys.length ∧
   395	                      ts.length = id.tparams.length ∧ ss.length = ms.tparams.length ∧ es.length = ms.neffs then
   396	                    some (none, .run ((body.substTy (ss ++ ts) es).instantiate (vs ++ ws)) (markPush k) σ)
   397	                  else none
   398	              | none => none
   399	          | _, _ => none
   400	      | none => none
   401	  | .run (.meth v m ss es ws) k σ =>
   402	      (v.superStep P).map fun v' => (none, .run (.meth v' m ss es ws) k σ)
   403	  | .run (.ite (.const (.boolean true)) m _) k σ => some (none, .run m k σ)
   404	  | .run (.ite (.const (.boolean false)) _ n) k σ => some (none, .run n k σ)
   405	  | .run (.ite _ _ _) _ _ => none
   406	  | .run (.match v arms) k σ =>
   407	      match firstMatch v arms with
   408	      | some (m, ws) => some (none, .run (m.instantiate ws) k σ)
   409	      | none => none
   410	  | .run (.lazyC m) k σ =>
   411	      let l := fresh σ
   412	      some (none, .run (.ret (.loc l)) k (σ.set l (.thunk m)))
   413	  | .run (.escape v) (.letF _ :: k) σ => some (none, .run (.escape v) k σ)
   414	  | .run (.escape v) (.handleF _ :: k) σ => some (none, .run (.escape v) k σ)
   415	  | .run (.escape v) (.mark :: k) σ => some (none, .run (.ret v) k σ)
   416	  | .run (.escape w) (.release v :: k) σ =>
   417	      releaseStep rel v (.run (.escape w) k σ) (fun r => .error [r] k σ)
   418	  | .run (.escape v) (.drop κ :: k) σ =>
   419	      match σ κ with
   420	      | some .used => some (none, .run (.escape v) k σ)
   421	      | some (.cont k') => some (none, .run (.escape v) (releases k' ++ k) (σ.set κ .used))
   422	      | _ => none
   423	  | .run (.escape _) _ _ => none
   424	  | .run (.use v m) k σ => some (none, .run m (.release v :: k) σ)
   425	  | .run (.handle m h) k σ => some (none, .run m (.handleF h :: k) σ)
   426	  | .run (.resume (.loc κ) v) k σ =>
   427	      match σ κ with
   428	      | some (.cont k') => some (none, .run (.ret v) (k' ++ k) (σ.set κ .used))
   429	      | some .used => some (none, .error [rResume] k σ)
   430	      | _ => none
   431	  | .run (.resume _ _) _ _ => none
   432	  | .error rs (.release v :: k) σ =>
   433	      releaseStep rel v (.error rs k σ) (fun r => .error (rs ++ [r]) k σ)
   434	  | .error rs (.drop κ :: k) σ =>
   435	      match σ κ with
   436	      | some .used => some (none, .error rs k σ)
   437	      | some (.cont k') => some (none, .error rs (releases k' ++ k) (σ.set κ .used))
   438	      | _ => none
   439	  | .error rs (_ :: k) σ => some (none, .error rs k σ)
   440	  | .error _ [] _ => none
   441	  | .exit n rs (.release v :: k) σ =>
   442	      releaseStep rel v (.exit n rs k σ) (fun r => .exit n (rs ++ [r]) k σ)
   443	  | .exit n rs (.drop κ :: k) σ =>
   444	      match σ κ with
   445	      | some .used => some (none, .exit n rs k σ)
   446	      | some (.cont k') => some (none, .exit n rs (releases k' ++ k) (σ.set κ .used))
   447	      | _ => none
   448	  | .exit n rs (_ :: k) σ => some (none, .exit n rs k σ)
   449	  | .exit _ _ [] _ => none
   450	
   451	/-- `step` を n 回まで続ける。 -/
   452	def run (P : Program) (B : Builtins) (oracle : Oracle) (rel : Val → Option ErrKind)
   453	    (fresh : Store → Nat) : Nat → State → List Event → State × List Event
   454	  | 0, s, evs => (s, evs.reverse)
   455	  | n + 1, s, evs =>
   456	      match step P B oracle rel fresh s with
   457	      | none => (s, evs.reverse)
   458	      | some (none, s') => run P B oracle rel fresh n s' evs
   459	      | some (some ev, s') => run P B oracle rel fresh n s' (ev :: evs)
   460	
   461	/-! ## 継続とストアの型付け -/
   462	
   463	/-- `R; ε ⊢k K : A ⇒ B ! ε0`（01-12「確かめる性質」）。最後の添字 `Rend` は、継続の末尾（空の継続）での
   464	R である。ストアの継続の型付けで、末尾の `handle` の枠を κ を作った節の R で型付けすることを表すために使う。 -/
   465	inductive ContTy (P : Program) (B : Builtins) (Ψ : StoreTy) :
   466	    Option Ty → Eff → Cont → Ty → Ty → Eff → Option Ty → Prop
   467	  | K_Empty {R ε a ε0} : Eff.Sub ε ε0 → Ty.WF 0 a → ContTy P B Ψ R ε [] a a ε0 R
   468	  | K_Let {R ε n k a c b ε0 ε1 Re} :
   469	      HasTypeC P B Ψ [] [some a] R n c ε1 → Eff.Sub ε1 ε → ContTy P B Ψ R ε k c b ε0 Re →
   470	      ContTy P B Ψ R ε (.letF n :: k) a b ε0 Re
   471	  | K_Mark {R' ε k a b ε0 Re} :
   472	      ContTy P B Ψ R' ε k a b ε0 Re → Ty.WF 0 a → ContTy P B Ψ (some a) ε (.mark :: k) a b ε0 Re
   473	  | K_Update {R ε l k a b ε0 Re} :
   474	      Ψ l = some (.lazy a) → ContTy P B Ψ R ε k a b ε0 Re →
   475	      ContTy P B Ψ none ε (.update l :: k) a b ε0 Re
   476	  | K_Release {R ε v o k a b ε0 Re} :
   477	      HasTypeV P B Ψ [] [] v (.opaque o) → B.isResource o = true → ε (.name stateEff) = true →
   478	      ContTy P B Ψ R ε k a b ε0 Re → ContTy P B Ψ R ε (.release v :: k) a b ε0 Re
   479	  /-- K-Handle。節は、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査する（ADR 0302）。 -/
   480	  | K_Handle {R ε εc h k t b ε0 Re} :
   481	      ContTy P B Ψ R ε k t b ε0 Re → Eff.Sub εc ε → HasTypeClauses P B Ψ [] [] R h t εc →
   482	      Ty.WF 0 t →
   483	      ContTy P B Ψ R (Eff.union εc (handled P B h)) (.handleF h :: k) t b ε0 Re
   484	  /-- K-Drop。捨てる継続の解放の枠を、この位置で実行できるように、κ の継続の型のエフェクトが `State` を
   485	  含むなら、ε も `State` を含む（ADR 0300）。 -/
   486	  | K_Drop {R ε κ k a b ε0 Re b' t' ε' R'} :
   487	      Ψ κ = some (.cont b' t' ε' R') → (ε' (.name stateEff) = true → ε (.name stateEff) = true) →
   488	      ContTy P B Ψ R ε k a b ε0 Re →
   489	      ContTy P B Ψ R ε (.drop κ :: k) a b ε0 Re
   490	  /-- K-Sub。継続が受け取る型を広げる（ADR 0301）。 -/
   491	  | K_Sub {R ε k a a' b ε0 Re} :
   492	      ContTy P B Ψ R ε k a' b ε0 Re → Ty.Le a a' → ContTy P B Ψ R ε k a b ε0 Re
   493	
   494	/-- 継続が `handle` の枠で終わる。 -/
   495	def EndsWithHandle (k : Cont) : Prop := ∃ k1 h, k = k1 ++ [.handleF h]
   496	
   497	/-- ストアの中身の型付け（01-12「確かめる性質」の箇条）。 -/
   498	def CellOk (P : Program) (B : Builtins) (Ψ : StoreTy) (l : Nat) : Cell → Prop
   499	  | .val v => ∃ a, Ψ l = some (.ref a) ∧ HasTypeV P B Ψ [] [] v a
   500	  | .thunk m => ∃ a, Ψ l = some (.lazy a) ∧ HasTypeC P B Ψ [] [] none m a Eff.empty
   501	  | .done v => ∃ a, Ψ l = some (.lazy a) ∧ HasTypeV P B Ψ [] [] v a
   502	  | .cont k => ∃ b t ε r, Ψ l = some (.cont b t ε r) ∧ EndsWithHandle k ∧
   503	      ∃ R' ε', ContTy P B Ψ R' ε' k b t ε r
   504	  | .used => ∃ b t ε r, Ψ l = some (.cont b t ε r)
   505	
   506	/-- ストアの場所の型は、型の変数を含まない。 -/
   507	def LocTy.WF : LocTy → Prop
   508	  | .ref a => Ty.WF 0 a
   509	  | .lazy a => Ty.WF 0 a
   510	  | .cont b t _ r => Ty.WF 0 b ∧ Ty.WF 0 t ∧ ∀ x, r = some x → Ty.WF 0 x
   511	
   512	/-- ストアがストアの型付けに合う。ストアは有限であり、Ψ が型を与える場所には中身がある（`dom Ψ = dom σ`。
   513	ADR 0300）。 -/
   514	def StoreOk (P : Program) (B : Builtins) (Ψ : StoreTy) (σ : Store) : Prop :=
   515	  (∃ n, ∀ l, n ≤ l → σ l = none) ∧ (∀ l x, Ψ l = some x → x.WF) ∧
   516	    (∀ l x, Ψ l = some x → σ l ≠ none) ∧
   517	    (∀ l c, σ l = some c → CellOk P B Ψ l c)
   518	
   519	/-- 継続の末尾で許すエフェクト Eb は、組み込みのエフェクトの名前の集合である。 -/
   520	def BuiltinOnly (P : Program) (B : Builtins) (ε : Eff) : Prop :=
   521	  ∀ a, ε a = true → ∃ l, a = .name l ∧ P.effects l = none ∧ (B.effects l).isSome
   522	
   523	/-! ## 状態の中の項が閉じていること -/
   524	
   525	def Frame.Closed : Frame → Prop
   526	  | .letF n => Comp.VarsIn 0 (fun _ => True) n
   527	  | .mark => True
   528	  | .update _ => True
   529	  | .release v => Val.VarsIn 0 (fun _ => True) v
   530	  | .handleF h => Clause.VarsInList 0 (fun _ => True) h
   531	  | .drop _ => True
   532	
   533	def Cont.Closed (k : Cont) : Prop := ∀ f ∈ k, f.Closed
   534	
   535	def Cell.Closed : Cell → Prop
   536	  | .val v => Val.VarsIn 0 (fun _ => True) v
   537	  | .thunk m => Comp.VarsIn 0 (fun _ => True) m
   538	  | .done v => Val.VarsIn 0 (fun _ => True) v
   539	  | .cont k => Cont.Closed k
   540	  | .used => True
   541	
   542	def Store.Closed (σ : Store) : Prop := ∀ l c, σ l = some c → c.Closed
   543	
   544	/-! ## 状態の型付け -/
   545	
   546	/-- 状態に型が付く（01-12「確かめる性質」の初回リリース版の状態の型付け）。継続の判断は、末尾の K-Empty を
   547	`R = none` で使う導出で満たす（ADR 0299）。加えて、状態の中の項が型の変数を含まないこと
   548	（`WellFormed.lean` の冒頭）を求める。 -/
   549	def StateTy (P : Program) (B : Builtins) : State → Prop
   550	  | .run m k σ => ∃ Ψ R a b ε ε1 Eb,
   551	      StoreOk P B Ψ σ ∧ HasTypeC P B Ψ [] [] R m a ε1 ∧ Eff.Sub ε1 ε ∧
   552	      ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
   553	      Comp.VarsIn 0 (fun _ => True) m ∧ Cont.Closed k ∧ Store.Closed σ
   554	  | .error _ k σ => ∃ Ψ R a b ε Eb,
   555	      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
   556	      Cont.Closed k ∧ Store.Closed σ
   557	  | .exit _ _ k σ => ∃ Ψ R a b ε Eb,
   558	      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ BuiltinOnly P B Eb ∧
   559	      Cont.Closed k ∧ Store.Closed σ
   560	
   561	end Benitoite.Release
```

### formal/Benitoite/Release/Assumptions.lean

```lean
     1	import Benitoite.Release.Semantics
     2	
     3	/-!
     4	# 形式化で仮定するもの（段階 B）
     5	
     6	段階 A の仮定（`Benitoite.Core.Builtins.Assumptions`）を、段階 B の組み込みの関数に広げる。
     7	設計書 07-04「形式化で仮定するもの」の表に対応する。仮定は `axiom` としては置かず、定理の引数として明示する。
     8	-/
     9	
    10	namespace Benitoite.Release
    11	
    12	/-- 組み込みの関数の結果が型 A を持つ。値は型の変数を含まない。 -/
    13	def OutcomeTy (P : Program) (B : Builtins) (Ψ : StoreTy) : Outcome → Ty → Prop
    14	  | .val v, a => HasTypeV P B Ψ [] [] v a ∧ Val.VarsIn 0 (fun _ => True) v
    15	  | .err _, _ => True
    16	  | .exit _, _ => True
    17	
    18	/-- 型パラメータの制約の並び `C0`（`C1` の外側）を、閉じた型 `ts` で置き換えられる。 -/
    19	def ClosedSat (B : Builtins) (C0 C1 : List TParam) (ts : List Ty) : Prop :=
    20	  (∀ t ∈ ts, Ty.WF 0 t) ∧ SatAll B C1 ts C0
    21	
    22	/-- 可変のセルと明示遅延の組み込みの関数の型（01-07「可変のセル（初回リリース版）」、01-06「明示遅延の型」）。 -/
    23	def PrimSig.StoreShape (s : PrimSig) : Prop :=
    24	  match s.kind with
    25	  | .refNew => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.tvar 0] ∧ s.ret = .reference (.tvar 0) ∧
    26	      s.eff = Eff.single stateEff
    27	  | .refGet => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0)] ∧ s.ret = .tvar 0 ∧
    28	      s.eff = Eff.single stateEff
    29	  | .refSet => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.reference (.tvar 0), .tvar 0] ∧
    30	      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
    31	  | .refUpdate => s.ntys = 1 ∧ s.neffs = 0 ∧
    32	      s.params = [.reference (.tvar 0), .fn [.tvar 0] (.tvar 0) Eff.empty] ∧
    33	      s.ret = .base .unit ∧ s.eff = Eff.single stateEff
    34	  | .force => s.ntys = 1 ∧ s.neffs = 0 ∧ s.params = [.lazy (.tvar 0)] ∧ s.ret = .tvar 0 ∧
    35	      s.eff = Eff.empty
    36	  | .pure => True
    37	  | .io => True
    38	  | .exit => True
    39	
    40	structure Builtins.Assumptions (P : Program) (B : Builtins) : Prop where
    41	  /-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う。 -/
    42	  sig_scoped : ∀ b s, B.sig b = some s → s.Scoped
    43	  /-- 制約の保存。制約の並びの `C1` の外側の `C0` を閉じた型で置き換えても、制約を満たす。 -/
    44	  admits_subst : ∀ b s C0 C1 ts ts' es', B.sig b = some s → s.admits (C1 ++ C0) ts →
    45	    ClosedSat B C0 C1 ts' → ts'.length = C0.length →
    46	    s.admits C1 (ts.map (Ty.substAt C1.length ts' es'))
    47	  sat_subst : ∀ C0 C1 t p ts' es', B.sat (C1 ++ C0) t p →
    48	    ClosedSat B C0 C1 ts' → ts'.length = C0.length → B.sat C1 (t.substAt C1.length ts' es') p
    49	  /-- 組み込みの関数の制約を満たす型引数は、その型パラメータの組み込みの制約も満たす。 -/
    50	  admits_sat : ∀ b s C ts, B.sig b = some s → s.admits C ts → SatAll B C ts s.tparams
    51	  /-- 制約の並び `C1` の型パラメータだけを使う型が制約を満たすかは、`C1` の外側の並びによらない。 -/
    52	  sat_local : ∀ C1 C0 t p, Ty.WF C1.length t → B.sat C1 t p → B.sat (C1 ++ C0) t p
    53	  admits_local : ∀ b s C1 C0 ts, B.sig b = some s → (∀ t ∈ ts, Ty.WF C1.length t) →
    54	    s.admits C1 ts → s.admits (C1 ++ C0) ts
    55	  /-- δ の型の保存（IO を行わない組み込みの関数）。 -/
    56	  delta_typed : ∀ Ψ b s ts es ws, B.sig b = some s → s.kind = .pure →
    57	    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    58	    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    59	    ∃ o, B.delta b ts es ws = some o ∧ (∀ n, o ≠ .exit n) ∧ OutcomeTy P B Ψ o (Ty.subst ts es s.ret)
    60	  /-- IO の応答の型。IO を行う関数の応答は値か `error(r)`、プロセスの終了の関数の応答は `exit(n)` か
    61	  `error(r)` である。 -/
    62	  io_kind : ∀ b s ts es ws o, B.sig b = some s → B.ioResponse b ts es ws o →
    63	    (s.kind = .io ∧ ∀ n, o ≠ .exit n) ∨ (s.kind = .exit ∧ ∀ v, o ≠ .val v)
    64	  io_typed : ∀ Ψ b s ts es ws o, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    65	    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    66	    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    67	    B.ioResponse b ts es ws o → OutcomeTy P B Ψ o (Ty.subst ts es s.ret)
    68	  /-- IO の応答の存在。 -/
    69	  io_exists : ∀ Ψ b s ts es ws, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    70	    ts.length = s.ntys → es.length = s.neffs → s.admits [] ts →
    71	    HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) →
    72	    ∃ o, B.ioResponse b ts es ws o
    73	  /-- IO を行う組み込みの関数は、組み込みのエフェクトの操作であり、型のエフェクトはそのエフェクトの
    74	  名前だけである。 -/
    75	  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    76	    ∃ l bs, s.opEff = some l ∧ s.eff = Eff.single l ∧ s.neffs = 0 ∧ B.effects l = some bs ∧ b ∈ bs
    77	  /-- 組み込みのエフェクトの操作は、そのエフェクトを `opEff` に持つ、IO を行う組み込みの関数である。 -/
    78	  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    79	    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit) ∧ s.opEff = some l
    80	  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l → (s.kind = .io ∨ s.kind = .exit)
    81	  /-- `State` は操作を持たない組み込みのエフェクトである。 -/
    82	  state_effect : B.effects stateEff = some []
    83	  /-- 可変のセルと明示遅延の組み込みの関数の型と、制約。これらの関数は、個数の合う型引数ならどれも受け入れる。 -/
    84	  store_shape : ∀ b s, B.sig b = some s → s.StoreShape
    85	  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io → s.kind ≠ .exit →
    86	    ts.length = s.ntys → s.admits C ts
    87	  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
    88	  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
    89	  /-- 解放の事象には、起こりうる応答が少なくとも一つある。 -/
    90	  release_exists : ∀ Ψ v o, HasTypeV P B Ψ [] [] v (.opaque o) → B.isResource o = true →
    91	    ∃ r, B.releaseResponse v r
    92	
    93	/-- エフェクトの宣言が、操作の宣言と合っている。利用者が宣言したエフェクトの名前は、組み込みのエフェクトの
    94	名前と重ならない。 -/
    95	def Program.EffectsOk (P : Program) (B : Builtins) : Prop :=
    96	  (∀ l os o, P.effects l = some os → o ∈ os → ∃ od, P.ops o = some od ∧ od.eff = l) ∧
    97	    (∀ o od, P.ops o = some od → ∃ os, P.effects od.eff = some os ∧ o ∈ os) ∧
    98	    (∀ l os, P.effects l = some os → B.effects l = none)
    99	
   100	end Benitoite.Release
```

### formal/Benitoite/Release/Theorems.lean

```lean
     1	import Benitoite.Release.Lemmas.StepSound
     2	
     3	/-!
     4	# 段階 B の定理
     5	
     6	設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性）の、初回リリース版の
     7	読み替えの形を、段階 B の範囲で言明し、証明する（段階 B2 で、型クラスとコレクションの構成を加えた）。証明の補題は `Lemmas/` に置く。
     8	
     9	段階 A と違い、遷移を計算する関数 `step` と遷移の関係の一致は、`step` が返す遷移が関係の遷移であること
    10	（`step_sound`）だけを言明する。`step` は例の実行を調べる道具であり、新しい場所と応答の選び方を固定するので、
    11	関係のすべての遷移を返すわけではない。
    12	-/
    13	
    14	namespace Benitoite.Release
    15	
    16	variable {P : Program} {B : Builtins}
    17	
    18	/-- 型が付いた状態について、`step` が返す遷移は `Step` の遷移である。`oracle` と `rel` は、起こりうる応答が
    19	あるときは、その一つを選ぶ。`fresh` は、有限なストアに中身のない場所を選ぶ。 -/
    20	theorem step_sound (hb : B.Assumptions P) (oracle : Oracle) (rel : Val → Option ErrKind) (fresh : Store → Nat)
    21	    (horacle : ∀ b ts es ws o, B.ioResponse b ts es ws o → B.ioResponse b ts es ws (oracle b ts es ws))
    22	    (hrel : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v))
    23	    (hfresh : ∀ σ : Store, (∃ n, ∀ l, n ≤ l → σ l = none) → σ (fresh σ) = none)
    24	    {s : State} {l : Option Event} {s' : State} :
    25	    StateTy P B s → step P B oracle rel fresh s = some (l, s') → Step P B s l s' := by
    26	  intro hs h
    27	  obtain ⟨Eb, _, hs⟩ := stateTy_iff.mp hs
    28	  exact step_soundE hb oracle rel fresh horacle hrel hfresh hs h
    29	
    30	/-- 進行。型が付いた状態は、`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)` のいずれかであるか、
    31	遷移できる。 -/
    32	theorem progress (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {s : State} :
    33	    StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s' := by
    34	  intro hs
    35	  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
    36	  exact progressE hwt hdecl hb hs hEb
    37	
    38	/-- 保存。型が付いた状態から遷移した先の状態も型が付く。 -/
    39	theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    40	    (hb : B.Assumptions P) {s : State} {l : Option Event} {s' : State} :
    41	    StateTy P B s → Step P B s l s' → StateTy P B s' := by
    42	  intro hs hst
    43	  obtain ⟨Eb, hEb, hs⟩ := stateTy_iff.mp hs
    44	  exact stateTy_iff.mpr ⟨Eb, hEb, preservationE hwf hwt hdecl hb hs hst⟩
    45	
    46	/-- エフェクトの健全性。`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` からの
    47	実行は、事象を伴う遷移（IO の事象と解放の事象）をせず、どの `handle` の枠も処理しない操作を呼ばない。
    48	`· ⊢c M` の R は `none` とする（実行を始める計算は関数の本体の外にあるので `escape` を許さない。ADR 0299）。 -/
    49	theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    50	    (hb : B.Assumptions P) {m : Comp} {a : Ty} :
    51	    HasTypeC P B StoreTy.empty [] [] none m a Eff.empty → m.ClosedNoEffVars →
    52	    ∀ s, Steps P B (.run m [] Store.empty) s →
    53	      (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s := by
    54	  intro hm hc s hsteps
    55	  have hs := steps_preserve hwf hwt hdecl hb hsteps (stateTyE_init hwf hb hm hc)
    56	  exact ⟨no_event hdecl hb hs, no_unhandledOp hdecl hs builtinOnly_empty⟩
    57	
    58	end Benitoite.Release
```

### formal/Benitoite/Release/Model.lean

```lean
     1	import Benitoite.Release.Theorems
     2	
     3	/-!
     4	# 仮定を満たす組み込みの関数の例（段階 B）
     5	
     6	`Builtins.Assumptions` が矛盾しない（定理が空虚に成り立っていない）ことを、仮定を満たす組み込みの関数の
     7	集まりを一つ作って確かめる。組み込みの関数は `Reference.get` と `Reference.set` の二つだけで、IO を行う関数も
     8	リソースの型も持たない。どのプログラムについても仮定を満たす。加えて、定義を持たないプログラムが定理の
     9	前提を満たし、エフェクトの健全性を具体的な計算に使えることを示す。
    10	-/
    11	
    12	namespace Benitoite.Release.Model
    13	
    14	open Benitoite.Release
    15	
    16	def refGetSig : PrimSig where
    17	  tparams := [{}]
    18	  neffs := 0
    19	  params := [.reference (.tvar 0)]
    20	  ret := .tvar 0
    21	  eff := Eff.single stateEff
    22	  admits := fun _ ts => ts.length = 1
    23	  kind := .refGet
    24	  opEff := none
    25	
    26	def refSetSig : PrimSig where
    27	  tparams := [{}]
    28	  neffs := 0
    29	  params := [.reference (.tvar 0), .tvar 0]
    30	  ret := .base .unit
    31	  eff := Eff.single stateEff
    32	  admits := fun _ ts => ts.length = 1
    33	  kind := .refSet
    34	  opEff := none
    35	
    36	def builtins : Builtins where
    37	  sig := fun b => if b = "Reference.get" then some refGetSig
    38	    else if b = "Reference.set" then some refSetSig else none
    39	  delta := fun _ _ _ _ => none
    40	  ioResponse := fun _ _ _ _ _ => False
    41	  releaseResponse := fun _ r => r = none
    42	  isResource := fun _ => false
    43	  effects := fun l => if l = stateEff then some [] else none
    44	  sat := fun _ _ _ => True
    45	  refGet := "Reference.get"
    46	  refSet := "Reference.set"
    47	
    48	theorem sig_cases {b s} (h : builtins.sig b = some s) : s = refGetSig ∨ s = refSetSig := by
    49	  simp only [builtins] at h
    50	  split at h
    51	  · cases h; exact Or.inl rfl
    52	  · split at h
    53	    · cases h; exact Or.inr rfl
    54	    · cases h
    55	
    56	theorem single_no_rho (i : Nat) : Eff.single stateEff (.rho i) = false := by
    57	  simp [Eff.single]
    58	
    59	theorem assumptions (P : Program) : builtins.Assumptions P where
    60	  sig_scoped := by
    61	    intro b s h
    62	    rcases sig_cases h with rfl | rfl <;>
    63	      exact ⟨by simp [Ty.VarsInList, Ty.VarsIn, PrimSig.ntys, refGetSig, refSetSig],
    64	        by simp [Ty.VarsIn, PrimSig.ntys, refGetSig, refSetSig],
    65	        fun i hi => by simp [refGetSig, refSetSig, single_no_rho] at hi⟩
    66	  admits_subst := by
    67	    intro b s C0 C1 ts ts' es' h ha _ _
    68	    rcases sig_cases h with rfl | rfl <;> simpa [refGetSig, refSetSig] using ha
    69	  sat_subst := fun _ _ _ _ _ _ _ _ _ => trivial
    70	  admits_sat := by
    71	    intro b s C ts h ha
    72	    rcases sig_cases h with rfl | rfl <;>
    73	      exact ⟨by simpa [refGetSig, refSetSig] using ha, fun _ _ _ _ _ => trivial⟩
    74	  sat_local := fun _ _ _ _ _ _ => trivial
    75	  admits_local := by
    76	    intro b s C1 C0 ts h _ ha
    77	    rcases sig_cases h with rfl | rfl <;> exact ha
    78	  delta_typed := by
    79	    intro Ψ b s ts es ws h hk
    80	    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
    81	  io_kind := fun _ _ _ _ _ _ _ h => h.elim
    82	  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ _ _ h => h.elim
    83	  io_exists := by
    84	    intro Ψ b s ts es ws h hk
    85	    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
    86	  io_op := by
    87	    intro b s h hk
    88	    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hk
    89	  effect_ops := by
    90	    intro l bs b h hb
    91	    simp only [builtins] at h
    92	    split at h
    93	    · cases h; simp at hb
    94	    · cases h
    95	  opEff_io := by
    96	    intro b s l h hl
    97	    rcases sig_cases h with rfl | rfl <;> simp [refGetSig, refSetSig] at hl
    98	  state_effect := by simp [builtins]
    99	  store_shape := by
   100	    intro b s h
   101	    rcases sig_cases h with rfl | rfl <;>
   102	      simp [PrimSig.StoreShape, PrimSig.ntys, refGetSig, refSetSig]
   103	  store_admits := by
   104	    intro b s C ts h _ _ _ hl
   105	    rcases sig_cases h with rfl | rfl <;> simpa [PrimSig.ntys, refGetSig, refSetSig] using hl
   106	  ref_get := ⟨refGetSig, by simp [builtins], rfl⟩
   107	  ref_set := ⟨refSetSig, by simp [builtins], rfl⟩
   108	  release_exists := fun _ _ _ _ _ => ⟨none, rfl⟩
   109	
   110	/-- 定義も宣言も持たないプログラム。 -/
   111	def emptyProgram : Program :=
   112	  ⟨fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none⟩
   113	
   114	theorem emptyProgram_wellFormed : emptyProgram.WellFormed :=
   115	  ⟨fun _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h),
   116	    fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩
   117	
   118	theorem emptyProgram_wellTyped : emptyProgram.WellTyped builtins :=
   119	  ⟨fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩
   120	
   121	theorem emptyProgram_effectsOk : emptyProgram.EffectsOk builtins :=
   122	  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩
   123	
   124	/-- `return ()` からの実行は、事象を伴う遷移をしない。 -/
   125	example : ∀ s, Steps emptyProgram builtins (.run (.ret (.const .unit)) [] Store.empty) s →
   126	    (∀ ev s', ¬ Step emptyProgram builtins s (some ev) s') ∧ ¬ UnhandledOp s :=
   127	  effect_soundness emptyProgram_wellFormed emptyProgram_wellTyped emptyProgram_effectsOk
   128	    (assumptions emptyProgram) (.C_Return .V_Const) trivial
   129	
   130	end Benitoite.Release.Model
```

### formal/Benitoite/Release/Examples.lean

```lean
     1	import Benitoite.Release.Semantics
     2	
     3	/-!
     4	# 抽象機械の実行の例（段階 B）
     5	
     6	小さなコア計算のプログラムを `run` で実行し、01-12 の初回リリース版の規則から期待する結果と比べる。
     7	期待と食い違うと `decide` が失敗し、`lake build` が止まる。
     8	-/
     9	
    10	namespace Benitoite.Release.Examples
    11	
    12	open Benitoite.Release
    13	
    14	def intTy : Ty := .base .integer
    15	def unitTy : Ty := .base .unit
    16	def int (n : Int) : Val := .const (.integer n)
    17	
    18	def sig (tps : List TParam) (ps : List Ty) (r : Ty) (e : Eff) (k : PrimKind)
    19	    (op : Option EffName := none) : PrimSig :=
    20	  { tparams := tps, neffs := 0, params := ps, ret := r, eff := e, admits := fun _ _ => True,
    21	    kind := k, opEff := op }
    22	
    23	/-- 例の組み込みの関数。`add` は IO を行わず、`print` は組み込みのエフェクト `Console.Write` の操作、
    24	`open`・`close` はリソースを扱う。`new`・`get`・`set`・`update`・`force` はストアの操作である。 -/
    25	def builtins : Builtins where
    26	  sig
    27	    | "add" => some (sig [] [intTy, intTy] intTy Eff.empty .pure)
    28	    | "print" => some (sig [] [intTy] unitTy (Eff.single "Console.Write") .io (some "Console.Write"))
    29	    | "exit" => some (sig [] [intTy] unitTy (Eff.single "Process.Exit") .exit (some "Process.Exit"))
    30	    | "new" => some (sig [{}] [.tvar 0] (.reference (.tvar 0)) (Eff.single stateEff) .refNew)
    31	    | "get" => some (sig [{}] [.reference (.tvar 0)] (.tvar 0) (Eff.single stateEff) .refGet)
    32	    | "set" => some (sig [{}] [.reference (.tvar 0), .tvar 0] unitTy (Eff.single stateEff) .refSet)
    33	    | "update" => some (sig [{}] [.reference (.tvar 0), .fn [.tvar 0] (.tvar 0) Eff.empty] unitTy
    34	        (Eff.single stateEff) .refUpdate)
    35	    | "force" => some (sig [{}] [.lazy (.tvar 0)] (.tvar 0) Eff.empty .force)
    36	    | _ => none
    37	  delta
    38	    | "add", _, _, [.const (.integer a), .const (.integer b)] =>
    39	        some (.val (.const (.integer (a + b))))
    40	    | _, _, _, _ => none
    41	  ioResponse
    42	    | "print", _, _, [_], o => o = .val (.const .unit)
    43	    | "exit", _, _, [.const (.integer n)], o => o = .exit n
    44	    | _, _, _, _, _ => False
    45	  releaseResponse _ r := r = none
    46	  isResource o := o == "File"
    47	  effects
    48	    | "Console.Write" => some ["print"]
    49	    | "Process.Exit" => some ["exit"]
    50	    | "State" => some []
    51	    | _ => none
    52	  sat _ _ _ := True
    53	  refGet := "get"
    54	  refSet := "set"
    55	
    56	def oracle : Oracle
    57	  | "exit", _, _, [.const (.integer n)] => .exit n
    58	  | _, _, _, _ => .val (.const .unit)
    59	
    60	def rel : Val → Option ErrKind := fun _ => none
    61	
    62	/-- 0 から 99 のうち、中身のない最初の場所。 -/
    63	def fresh (σ : Store) : Nat :=
    64	  ((List.range 100).find? fun l => match σ l with | none => true | some _ => false).getD 100
    65	
    66	def semigroupMeths : MethName → Option MethSig
    67	  | "combine" => some { tparams := [], neffs := 0, params := [.tvar 0, .tvar 0], ret := .tvar 0,
    68	                        eff := Eff.empty }
    69	  | _ => none
    70	
    71	def monoidMeths : MethName → Option MethSig
    72	  | "empty" => some { tparams := [], neffs := 0, params := [], ret := .tvar 0, eff := Eff.empty }
    73	  | _ => none
    74	
    75	def noSupers : ClassName → Option Val := fun _ => none
    76	
    77	def semigroupIntMeths : MethName → Option Comp
    78	  | "combine" => some (.app (.prim "add" [] []) [.var 1, .var 0])
    79	  | _ => none
    80	
    81	def monoidIntSupers : ClassName → Option Val
    82	  | "Semigroup" => some (.dict "SemigroupInt" [] [])
    83	  | _ => none
    84	
    85	def monoidIntMeths : MethName → Option Comp
    86	  | "empty" => some (.ret (int 0))
    87	  | _ => none
    88	
    89	/-- 環境は d, x, y の順（y が番号 0）。 -/
    90	def semigroupBoxMeths : MethName → Option Comp
    91	  | "combine" => some (.match (.var 1) [(.con "Box" [.var],
    92	      .match (.var 1) [(.con "Box" [.var],
    93	        .letIn (.meth (.var 4) "combine" [] [] [.var 1, .var 0])
    94	          (.ret (.con "Box" [.tvar 0] [.var 0])))])])
    95	  | _ => none
    96	
    97	def semigroupInt : ImplDecl where
    98	  tparams := []
    99	  dictParams := []
   100	  cls := "Semigroup"
   101	  target := intTy
   102	  supers := noSupers
   103	  methods := semigroupIntMeths
   104	
   105	def monoidInt : ImplDecl where
   106	  tparams := []
   107	  dictParams := []
   108	  cls := "Monoid"
   109	  target := intTy
   110	  supers := monoidIntSupers
   111	  methods := monoidIntMeths
   112	
   113	def semigroupBox : ImplDecl where
   114	  tparams := [{}]
   115	  dictParams := [("Semigroup", 0)]
   116	  cls := "Semigroup"
   117	  target := .data "Box" [.tvar 0]
   118	  supers := noSupers
   119	  methods := semigroupBoxMeths
   120	
   121	/-- 例のプログラム。
   122	
   123	- `effect Abort { fail[T](message: String) -> T }`
   124	- `effect Ask { ask() -> Integer }`
   125	- `f() : Integer ! {} = let _ ⇐ escape 7 in return 1`（途中の `return` に当たる）
   126	- `data Box[T] = Box(T)`
   127	- `trait Semigroup[T] { combine(x: T, y: T) -> T }`、`trait Monoid[T: Semigroup] { empty() -> T }`
   128	- `SemigroupInt : Semigroup[Integer]`（`combine` は `add`）、`MonoidInt : Monoid[Integer]`（`empty` は 0、
   129	  上位の型クラスの辞書は `SemigroupInt[]()`）
   130	- `SemigroupBox[T](d : Dict[Semigroup, T]) : Semigroup[Box[T]]`（`combine` は中身を d の `combine` で合わせる） -/
   131	def program : Program where
   132	  defs
   133	    | "f" => some { tparams := [], neffs := 0, params := [], ret := intTy, eff := Eff.empty,
   134	                    body := .letIn (.escape (int 7)) (.ret (int 1)) }
   135	    | _ => none
   136	  cons
   137	    | "Box" => some { data := "Box", ntys := 1, args := [.tvar 0] }
   138	    | _ => none
   139	  ops
   140	    | "fail" => some { eff := "Abort", tparams := [{}], params := [.base .string], ret := .tvar 0 }
   141	    | "ask" => some { eff := "Ask", tparams := [], params := [], ret := intTy }
   142	    | _ => none
   143	  effects
   144	    | "Abort" => some ["fail"]
   145	    | "Ask" => some ["ask"]
   146	    | _ => none
   147	  classes
   148	    | "Semigroup" => some { supers := [], methods := semigroupMeths }
   149	    | "Monoid" => some { supers := ["Semigroup"], methods := monoidMeths }
   150	    | _ => none
   151	  impls
   152	    | "SemigroupInt" => some semigroupInt
   153	    | "MonoidInt" => some monoidInt
   154	    | "SemigroupBox" => some semigroupBox
   155	    | _ => none
   156	
   157	inductive Result where
   158	  | returned (n : Int)
   159	  | returnedUnit
   160	  | boxed (n : Int)
   161	  | error (rs : List String)
   162	  | exited (n : Int)
   163	  | other
   164	  deriving DecidableEq, Repr
   165	
   166	def summarize : State × List Event → Result × Nat
   167	  | (s, evs) =>
   168	    let r := match s with
   169	      | .run (.ret (.const (.integer n))) [] _ => .returned n
   170	      | .run (.ret (.const .unit)) [] _ => .returnedUnit
   171	      | .run (.ret (.con "Box" _ [.const (.integer n)])) [] _ => .boxed n
   172	      | .error rs [] _ => .error rs
   173	      | .exit n _ [] _ => .exited n
   174	      | _ => .other
   175	    (r, evs.length)
   176	
   177	def exec (m : Comp) : Result × Nat :=
   178	  summarize (run program builtins oracle rel fresh 1000 (.run m [] Store.empty) [])
   179	
   180	def add (a b : Val) : Comp := .app (.prim "add" [] []) [a, b]
   181	
   182	/-! ## 例 -/
   183	
   184	/-- `handle (let x ⇐ fail[Integer]("bad") in add(x, 1)) with fail(m) k ⇒ return 0` は、`resume` せずに
   185	0 を返す（E-Handle、E-Op、E-DropRel）。 -/
   186	example : exec (.handle (.letIn (.app (.op "fail" [intTy]) [.const (.string "bad")]) (add (.var 0) (int 1)))
   187	    [.mk (.user "fail") 1 1 (.ret (int 0))]) = (.returned 0, 0) := by decide
   188	
   189	/-- `handle (let x ⇐ ask() in add(x, 1)) with ask() k ⇒ resume k 41` は 42 を返す（E-Resume、E-HRet、
   190	E-Drop）。 -/
   191	example : exec (.handle (.letIn (.app (.op "ask" []) []) (add (.var 0) (int 1)))
   192	    [.mk (.user "ask") 0 0 (.resume (.var 0) (int 41))]) = (.returned 42, 0) := by decide
   193	
   194	/-- 組み込みの操作 `print` を処理するハンドラの中の `print(3)` は、IO の事象を起こさない（E-OpPrim）。 -/
   195	example : exec (.handle (.app (.prim "print" [] []) [int 3])
   196	    [.mk (.prim "print") 1 0 (.resume (.var 0) (.const .unit))]) = (.returnedUnit, 0) := by decide
   197	
   198	/-- ハンドラがなければ、`print(3)` は IO の事象を一つ起こす（E-IO）。 -/
   199	example : exec (.app (.prim "print" [] []) [int 3]) = (.returnedUnit, 1) := by decide
   200	
   201	/-- 同じ継続を二度再開すると、実行時エラー `ResumeTwice` で止まる（E-ResumeErr）。 -/
   202	example : exec (.handle (.app (.op "ask" []) [])
   203	    [.mk (.user "ask") 0 0 (.letIn (.resume (.var 0) (int 1)) (.resume (.var 1) (int 2)))]) =
   204	    (.error ["ResumeTwice"], 0) := by decide
   205	
   206	/-- `let r ⇐ new[Integer](1) in let _ ⇐ set[Integer](r, 5) in get[Integer](r)` は 5 を返す
   207	（E-RefNew、E-RefSet、E-RefGet）。 -/
   208	example : exec (.letIn (.app (.prim "new" [intTy] []) [int 1])
   209	    (.letIn (.app (.prim "set" [intTy] []) [.var 0, int 5])
   210	      (.app (.prim "get" [intTy] []) [.var 1]))) = (.returned 5, 0) := by decide
   211	
   212	/-- `Reference.update` は、読んだ値に関数を適用して書き戻す（E-RefUpdate）。 -/
   213	example : exec (.letIn (.app (.prim "new" [intTy] []) [int 1])
   214	    (.letIn (.app (.prim "update" [intTy] []) [.var 0, .lam [intTy] (add (.var 0) (int 10))])
   215	      (.app (.prim "get" [intTy] []) [.var 1]))) = (.returned 11, 0) := by decide
   216	
   217	/-- `let l ⇐ lazy add(1, 2) in let _ ⇐ force(l) in force(l)` は 3 を返す。二度目の `force` は、一度目に
   218	保存した値を使う（E-Lazy、E-Force、E-Update、E-ForceDone）。 -/
   219	example : exec (.letIn (.lazyC (add (int 1) (int 2)))
   220	    (.letIn (.app (.prim "force" [intTy] []) [.var 0])
   221	      (.app (.prim "force" [intTy] []) [.var 1]))) = (.returned 3, 0) := by decide
   222	
   223	/-- `f()` の本体の `escape 7` は、`f` の呼び出しの結果として 7 を返す（E-Fun の `mark`、E-EscLet、
   224	E-EscMark）。 -/
   225	example : exec (.letIn (.app (.fnRef "f" [] []) []) (add (.var 0) (int 100))) = (.returned 107, 0) := by
   226	  decide
   227	
   228	/-- `use` したリソースは、本体を終えた後に解放の事象を一つ起こす（E-Use、E-Release）。 -/
   229	example : exec (.use (.const (.opaque "File" 1)) (.ret (int 1))) = (.returned 1, 1) := by decide
   230	
   231	/-- 終了の状態は、継続に残る解放の枠を実行してから終わる（E-Exit、E-ExitRel）。 -/
   232	example : exec (.use (.const (.opaque "File" 1)) (.app (.prim "exit" [] []) [int 3])) =
   233	    (.exited 3, 2) := by decide
   234	
   235	/-- `(MonoidInt[]()↑Semigroup).combine[;](1, 2)` は、上位の型クラスの辞書を取り出してから `combine` を呼び、
   236	3 を返す（E-Super、E-Meth）。 -/
   237	example : exec (.meth (.super (.dict "MonoidInt" [] []) "Semigroup") "combine" [] [] [int 1, int 2]) =
   238	    (.returned 3, 0) := by decide
   239	
   240	/-- `MonoidInt[]().empty[;]()` は 0 を返す（型クラスの引数を戻り値の型にだけ含むメソッド）。 -/
   241	example : exec (.meth (.dict "MonoidInt" [] []) "empty" [] [] []) = (.returned 0, 0) := by decide
   242	
   243	/-- `SemigroupBox[Integer](MonoidInt[]()↑Semigroup).combine[;](Box(1), Box(2))` は `Box(3)` を返す。実装の
   244	メソッドの本体は、辞書の引数 d を通して `Integer` の `combine` を呼ぶ（E-Meth の辞書の引数の置き換え）。 -/
   245	example : exec (.meth (.dict "SemigroupBox" [intTy] [.super (.dict "MonoidInt" [] []) "Semigroup"]) "combine"
   246	    [] [] [.con "Box" [intTy] [int 1], .con "Box" [intTy] [int 2]]) = (.boxed 3, 0) := by decide
   247	
   248	end Benitoite.Release.Examples
```

## 資料 4: 01-12 の型クラスとコレクションの節

```markdown
#### 基本型とコレクションの型

【方針】初回リリース版の基本型 `Byte`・`Decimal`（[基本型の意味論](01-04-types-basic.md)、[ADR 0105](../../../../../formal/reviews/decisions/0105-byte-type.md)、[ADR 0114](../../../../../formal/reviews/decisions/0114-decimal-type.md)）と、prelude の型 `Map[K, V]`・`Set[T]`・`Bytes`（[標準ライブラリ](../../../../../formal/reviews/03-interop/03-06-stdlib.md)、[ADR 0103](../../../../../formal/reviews/decisions/0103-map-and-set-ordered-by-key.md)、[ADR 0107](../../../../../formal/reviews/decisions/0107-bytes.md)）のために、次のものを加える。

```text
基本型      ι ::= … | Byte | Decimal
型          A ::= … | Map[A, B] | Set[A] | Bytes
値          V ::= … | {V1 ↦ W1, …, Vn ↦ Wn}       （マップ）
                  | {V1, …, Vn}                   （集合）
                  | bytes(k1, …, kn)              （バイト列。ki は Byte の値）

(V-Map)   Γ ⊢v Vi : A     Γ ⊢v Wi : B（各 i）     A は鍵の型である
          ─────────────────────────────────────────────
          Γ ⊢v {V1 ↦ W1, …, Vn ↦ Wn} : Map[A, B]

(V-Set)   Γ ⊢v Vi : A（各 i）     A は鍵の型である
          ─────────────────────────────
          Γ ⊢v {V1, …, Vn} : Set[A]

(V-Bytes) ki は Byte の値（各 i）
          ─────────────────────────────
          Γ ⊢v bytes(k1, …, kn) : Bytes
```

- 定数 c に、`Byte` と `Decimal` の値を加える。`Decimal` のリテラル（`1.25m` など。[字句構造](01-01-lexical.md)）は、`return c` に移す（c はリテラルが表す値）。`Byte` のリテラルはないので、`Byte` の値は組み込みの関数が返す。
- マップの鍵と集合の要素は、鍵の順序で並べ、同じ鍵（鍵の順序で等しいもの）を含まない。鍵の型は[型システム](01-06-type-system.md)の「鍵の型（初回リリース版）」で定める。マップ、集合、バイト列の値に当たる表層の構文はなく、これらの値は組み込みの関数（`Map.fromList`、`String.toUTF8` など）の δ か、IO の応答が返す。
- 定数 c に、`O` の型の値（`IOError`・`NetworkError` の値、タスク、リソース。後述の「エフェクトの名前と開始状態」）を加える。これらの値は、外部に作用する操作を行う組み込みの関数の応答か、タスクの集まりの関数が返し、表層に対応する構文はない。
- パターンで照合できない値（[代数的データ型とパターンマッチ](01-05-data-types.md)）が増えるので、P-Const の前提を「c は `Float`・`Byte`・`Decimal` の値でも、`O` の型の値でもない」に置き換える。マップ、集合、バイト列の値は定数ではないので、P-Const に現れない。

#### リストの展開
#### 型クラス

【方針】型クラスは、辞書（dictionary）を値として渡す形に移す（[型システム](01-06-type-system.md)の「型クラス（初回リリース版）」）。コア計算に次のものを加える。

```text
型          A ::= … | Dict[Cl, τ]              （型クラス Cl の、τ についての辞書）
                 | α[Ā]                        （型構成子を表す型パラメータ α の適用）
            τ ::= A | φ                        （φ は型構成子。高カインドの型パラメータを含む）
値          V ::= … | I[T̄](V̄)                  （実装 I の型パラメータを T̄ にし、実装の制約の辞書 V̄ を与えた辞書）
                 | V↑S                         （辞書 V から取り出した、上位の型クラス S の辞書）
計算        M ::= … | V.m[S̄; Ē](W̄)            （辞書 V のメソッド m を、m の型パラメータ S̄ とエフェクト変数 Ē で呼ぶ）
定義        d ::= … | impl I[β̄](d̄ : Dict[Cl', β̄']) : Dict[Cl, τ] = { S1 = U1, …, Sl = Ul; m1 = D1, …, mk = Dk }
```

- 実装の定義は、実装の型パラメータ β̄、実装の制約ごとの辞書の引数 d̄、メソッドごとの本体の定義 D を持つ。各 D は、トップレベルの関数の定義と同じ形である。
- 型クラスの制約を持つ関数は、制約ごとに `Dict[Cl, α]` 型の引数を、値の引数の前に持つ。この規則は、トップレベルの関数の定義 f と、実装の中のメソッドの定義 D の両方に当てはまる。メソッドが自分の型クラスの制約を持つとき、D の引数の並び x̄ は、その制約の辞書の引数を値の引数の前に含む。
- 型パラメータ α が型構成子を表すとき、型の中の `α[Ā]` は、α を置き換えた型構成子を Ā に適用した型である。
- 【決定】型クラス Cl が上位の型クラス S1, …, Sl を持つとき（[型システム](01-06-type-system.md)の「型クラス（初回リリース版）」）、Cl の実装の定義は、各 Sj の τ についての辞書 Uj を持つ（[ADR 0134](../../../../../formal/reviews/decisions/0134-standard-type-classes.md)）。Uj は値であり、実装の制約の辞書の引数 d̄ を使ってよい。`V↑S` は、辞書 V が持つ上位の型クラス S の辞書を取り出す。上位の型クラスの上位の型クラスの辞書は、`↑` を重ねて取り出す（`V↑Monoid↑Semigroup`）。
- 【決定】組み込みの制約（`equality`・`key`）は、辞書の引数を持たない（[ADR 0133](../../../../../formal/reviews/decisions/0133-builtin-equality-and-key-constraints.md)）。`=` は値の構造で比べる組み込みの操作であり、鍵の順序はすべての鍵の型の値に定まっているので、実行時に実装を選ぶ必要がない。組み込みの制約は、定義の型パラメータの制約としてコア計算に残す（後述の「型パラメータの組み込みの制約」、[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。V-Dict と C-Meth も、実装とメソッドの型パラメータについて、型引数が制約を満たすことを前提に持つ。
- 型クラスの引数を戻り値の型にだけ含むメソッド（`Monoid.empty()` など）のために、新しい規則は要らない。辞書は型検査が制約ごとに決め、脱糖はほかのメソッドの呼び出しと同じく、その辞書を使う。

```text
(V-Dict)  Σ に impl I[β̄](d̄ : Dict[Cl', β̄']) : Dict[Cl, τ] = { … } がある
          Γ ⊢v Vi : Dict[Cl'i, β'i][T̄/β̄]（各 i）
          ─────────────────────────────────────────────
          Γ ⊢v I[T̄](V̄) : Dict[Cl, τ[T̄/β̄]]

(V-Super) Γ ⊢v V : Dict[Cl, τ]     S は Cl の上位の型クラス
          ─────────────────────────────────────────────
          Γ ⊢v V↑S : Dict[S, τ]

(C-Meth)  Γ ⊢v V : Dict[Cl, τ]     Cl のメソッド m の型が ∀γ̄ ρ̄. (Ā) → B ! ε（型クラスの引数 P を含む）
          θ = [τ/P, S̄/γ̄, Ē/ρ̄]     Γ ⊢v Wi : Ai θ（各 i）
          （m が自分の型クラスの制約を持つとき、Ā はその制約ごとの Dict[Cl'', γ''] を値の引数の前に含む）
          ─────────────────────────────────────────────
          Γ ⊢c V.m[S̄; Ē](W̄) : Bθ ! εθ

(E-Meth)  ⟨I[T̄](V̄).m[S̄; Ē](W̄), K⟩  →  ⟨M θ [V̄/d̄][W̄/x̄], K ⟩
            ただし I の定義の m の本体が fn m[γ̄; ρ̄](x̄:Ā) : B ! ε = M であり、θ = [T̄/β̄, S̄/γ̄, Ē/ρ̄]
            （x̄ は、m 自身の制約の辞書の引数を含む）

(E-Super) ⟨V.m[S̄; Ē](W̄), K⟩  →  ⟨V'.m[S̄; Ē](W̄), K⟩     ただし V ⇝ V'
            I[T̄](V̄)↑Sj ⇝ Uj [T̄/β̄][V̄/d̄]（Uj は I の定義の Sj の辞書）     V ⇝ V' のとき V↑S ⇝ V'↑S

(D-Impl)  Cl[P] のメソッド mj の型を ∀γ̄j ρ̄j. (Āj) → Bj ! εj とし、θ = [τ/P] とする（各 j）
          Dj = fn mj[γ̄j; ρ̄j](x̄j:Ājθ) : Bjθ ! εjθ = Mj
          d̄ : Dict[Cl', β̄'], x̄j : Ājθ; Bjθ ⊢c Mj : Bjθ ! εjθ（各 j）
          Cl の上位の型クラスを S1, …, Sl とする     d̄ : Dict[Cl', β̄'] ⊢v Ui : Dict[Si, τ]（各 i）
          ─────────────────────────────────────────────
          impl I[β̄](d̄ : Dict[Cl', β̄']) : Dict[Cl, τ] = { S1 = U1, …, Sl = Ul; m1 = D1, …, mk = Dk } は型が付く
```

`↑` を含む辞書は値であり、メソッドの呼び出しの辞書になるまでそのまま受け渡す。メソッドの呼び出しの辞書が `↑` を含むときは、E-Super が `↑` を一段ずつ取り出し、実装の辞書 `I[T̄](V̄)` の形になったところで E-Meth を使う。V-Super と E-Super により、`↑` で取り出した辞書は、上位の型クラスの実装の辞書と同じ働きをする。E-Super を値の等しさでなく遷移として定めるのは、上位の型クラスの辞書が互いを指す実装の定義で、実装の辞書に行き着かずに進行が破れるのを避けるためである（[ADR 0305](../../../../../formal/reviews/decisions/0305-e-super-as-transition-at-method-call.md)。そのような定義では、E-Super の遷移が終わらない）。

D-Impl では、β̄、γ̄j、ρ̄j を、ほかの何とも等しくない型とエフェクトとして扱う。実装の本体の中で、実装の制約 `Cl'[β']` を満たす辞書が要るときは、対応する辞書の引数 d を使う。

脱糖は、型検査が各制約に決めた辞書を使う。制約の型が具体的な型構成子なら、その実装の辞書 `I[T̄](V̄)` を作る（実装の制約の辞書 V̄ も同じように決める）。制約の型が関数か実装の型パラメータなら、その関数か実装が受け取った辞書の引数を使う。受け取った辞書の引数が要る制約 `S[α]` そのものでなく、S を上位の型クラスに持つ型クラス C の制約 `C[α]` の辞書 d であれば、`d↑S` を使う（上位の型クラスを何段か辿るときは `↑` を重ねる）。メソッド自身の制約の辞書 Ū も、同じ規則で決める。実装の定義の上位の型クラスの辞書 U1, …, Ul も、実装の型パラメータの制約の辞書 d̄ を受け取った辞書の引数として、同じ規則で決める。

| 表層 | コア計算 |
|---|---|
| メソッドの呼び出し `Cl.m(e1, …, en)`（辞書は V、m 自身の制約の辞書は Ū） | `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in V.m[S̄; Ē](Ū, x1, …, xn)` |
| メソッドを値として使う `Cl.m` | `return λ(y1:A1, …, yn:An). V.m[S̄; Ē](Ū, y1, …, yn)`（`Ā` は値の引数の型） |
| 制約を持つ関数 `f` の呼び出し | 決めた辞書を、値の引数の前に並べて渡す |
| 制約を持つ関数 `f` を呼ばずに値として使う | `return λ(y1:A1, …, yn:An). f[T̄; Ē](Ū, y1, …, yn)`（Ū は決めた辞書、`Ā` は値の引数の型） |

#### 型パラメータの組み込みの制約

【方針】初回リリース版では、定義の型パラメータに組み込みの制約を持たせる（[ADR 0297](../../../../../formal/reviews/decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。実装の定義とメソッドの定義の型パラメータも同じく制約を持つ。

```text
定義        d ::= fn f[α1 : c1, …, αn : cn; ρ̄](x̄:Ā) : B ! ε = M     （ci は αi に付けた組み込みの制約の集まり。空でもよい）

(V-Fun)     Σ に fn f[ᾱ : c̄; ρ̄](x̄:Ā) : B ! ε = M がある     Δ ⊢ Ti : ci（各 i）     θ = [T̄/ᾱ, Ē/ρ̄]
            ─────────────────────────────────────────────
            Δ; Γ ⊢v f[T̄; Ē] : ((Ā) → B ! ε)θ
```

- Δ は、型付けの位置で有効な型パラメータと、その組み込みの制約の並びである。定義の本体は、その定義の型パラメータの並びを Δ として検査する。`handle` の節の本体は、節を囲む Δ に、操作の型パラメータを宣言の制約とともに加えて検査する（後述の「ハンドラ」）。ほかの規則は Δ をそのまま受け渡す。
- `Δ ⊢ T : c` は、型 T が制約 c を満たすことを表す。c が `equality` なら T は等値の型、`key` なら鍵の型である（[型システム](01-06-type-system.md)の「等値の型」「鍵の型（初回リリース版）」）。Δ の中で `equality` を付けた型パラメータは等値の型、`key` を付けた型パラメータは鍵の型として扱う。
- V-Prim の「T̄ が b の型パラメータの制約を満たす」は、Δ のもとで判定する。
- 組み込みの制約は辞書の引数を持たず、実行の規則は変わらない。

#### ストア：可変のセルと明示遅延
```
