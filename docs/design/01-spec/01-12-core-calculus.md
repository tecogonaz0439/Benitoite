# コア計算と脱糖

- 状態: 確定
- 関連ADR: [0005](../decisions/0005-direct-style-effects.md), [0007](../decisions/0007-constructors-and-list.md), [0008](../decisions/0008-effect-variables.md), [0013](../decisions/0013-evaluation-order-and-tail-calls.md), [0014](../decisions/0014-fine-grain-cbv-core.md), [0045](../decisions/0045-late-detection-of-output-write-failure.md), [0046](../decisions/0046-effect-subsumption-at-all-flow-positions.md), [0048](../decisions/0048-ioerror-not-equality-type.md), [0055](../decisions/0055-top-level-functions-and-types-only.md), [0058](../decisions/0058-string-interpolation-of-base-types.md), [0081](../decisions/0081-subsumption-on-computation-results.md), [0096](../decisions/0096-explicit-return.md), [0097](../decisions/0097-prefix-try.md), [0099](../decisions/0099-qualified-option-result-constructors.md), [0102](../decisions/0102-pair-and-triple.md), [0103](../decisions/0103-map-and-set-ordered-by-key.md), [0105](../decisions/0105-byte-type.md), [0107](../decisions/0107-bytes.md), [0108](../decisions/0108-keyword-blocks-closed-by-end.md), [0109](../decisions/0109-lambda-keyword.md), [0110](../decisions/0110-if-then-end-if.md), [0111](../decisions/0111-case-of-when.md), [0112](../decisions/0112-pascal-style-operators.md), [0113](../decisions/0113-div-and-mod-operators.md), [0114](../decisions/0114-decimal-type.md), [0116](../decisions/0116-builtin-fine-grained-effects.md), [0117](../decisions/0117-capabilities-as-effects.md), [0118](../decisions/0118-effect-handlers.md), [0121](../decisions/0121-pattern-extensions.md), [0123](../decisions/0123-top-level-constants.md), [0124](../decisions/0124-type-aliases.md), [0128](../decisions/0128-prelude-and-benitoite-namespace.md), [0129](../decisions/0129-effects-declared-in-modules.md), [0130](../decisions/0130-builtin-effect-names-and-placement.md), [0133](../decisions/0133-builtin-equality-and-key-constraints.md), [0134](../decisions/0134-standard-type-classes.md), [0140](../decisions/0140-network-separated-from-local-io.md), [0145](../decisions/0145-network-error.md), [0146](../decisions/0146-runtime-errors-not-in-types.md), [0149](../decisions/0149-http-exchange-release-failure.md), [0150](../decisions/0150-resource-release-as-state.md), [0151](../decisions/0151-inherited-handlers-tail-resume-only.md), [0155](../decisions/0155-resume-not-in-lazy.md), [0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md), [0177](../decisions/0177-server-mode-after-first-release.md), [0184](../decisions/0184-permissions-granted-per-builtin-effect.md), [0254](../decisions/0254-return-type-after-arrow.md), [0255](../decisions/0255-bind-and-shadow.md), [0257](../decisions/0257-match-with-case-arms.md), [0272](../decisions/0272-list-spread-in-list-literals.md), [0293](../decisions/0293-formal-verification-stage-2-alongside-first-release.md), [0295](../decisions/0295-core-calculus-chapter-normative-over-formalization.md), [0296](../decisions/0296-delta-receives-type-arguments.md), [0297](../decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md), [0299](../decisions/0299-state-continuation-ends-with-no-escape.md), [0300](../decisions/0300-continuations-second-class-drop-state-and-store-domain.md), [0301](../decisions/0301-subsumption-on-continuation-input.md), [0302](../decisions/0302-k-handle-clause-effect-within-below.md), [0303](../decisions/0303-no-continuation-types-in-terms.md), [0305](../decisions/0305-e-super-as-transition-at-method-call.md), [0307](../decisions/0307-lean-definitions-normative-for-core-calculus.md)
- 未決事項: なし
- 移行元: [設計メモ](../sources/fp-language-design.md) 25.2

## 目的と範囲

言語の意味を定義するためのコア言語と、表層構文からの脱糖（desugaring）の規則。形式化の対象が言語の一部分である場合は、その範囲と残りの仕様との関係も示す。処理系が使うデータ構造と変換工程は[中間表現と脱糖](../02-impl/02-06-ir-and-lowering.md)が扱い、両者が同一の表現であることは前提としない。

現在の版は、最小実行版（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲と、初回リリース版の言語の機能（後述の「初回リリース版の拡張」）を定める。対象は、最小実行版のすべての構文と、初回リリース版で加える構文のうち、ライブラリの提供方法に依存しないものである。コア計算の構文、型付け規則、実行の規則（抽象機械）、末尾呼び出しの保証、表層からの脱糖を定める。

## 前提

表層の式の型、多相な名前を使うたびに置き換える型とエフェクトの集合、ラムダの引数の型は、[型システム](01-06-type-system.md)の型検査で決まっているものとする。脱糖はその結果を使う。型検査の誤りを含むプログラムは脱糖しない。

組み込みの演算と関数の値は、[基本型の意味論](01-04-types-basic.md)、[エフェクト](01-07-effects.md)、[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。本章はそれらを関数 δ と、IO の応答として参照する。

## 仕様

### 本章の位置付け

【決定】最小実行版の表層のプログラムの意味は、本章の規則でコア計算へ脱糖し、抽象機械で実行した結果として定める（[ADR 0014](../decisions/0014-fine-grain-cbv-core.md)）。[評価意味論](01-08-evaluation.md)の記述と本章の規則が食い違うときは、本章を正とする。

【決定】本章のコア計算の規則のうち、形式検証の段階 2 で形式化したもの（構文、型付け規則、実行の規則、初回リリース版の拡張のうちコア計算に構成を加えるもの、確かめる性質の性質 2・3）は、リポジトリの `formal/` の Lean の定義を正とする。本章のこれらの規則は、その写しである。写しと Lean の定義が食い違うときは、Lean の定義に従う。形式化が本章より広く定めた箇所（[形式意味論と検証](../07-quality/07-04-formal-semantics.md)の「01-12 との対応」の表に記したもの）は、Lean の定義に本章の条件を加えたものを規則とする。表層からの脱糖、末尾呼び出しの保証、置き換えてよい等式は、本章を正とする（[ADR 0307](../decisions/0307-lean-definitions-normative-for-core-calculus.md)）。

処理系は、本章の抽象機械と同じ観測できる振る舞い（IO の列と、終わり方）を示さなければならない。ただし、標準出力と標準エラー出力への書き込みの失敗は、[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」で例外として定める（[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）。処理系の内部の表現と手順は問わない。

コア計算は、項を値と計算に分ける（fine-grain call-by-value）。`return V` は値 V をそのまま結果とする計算であり、`let x ⇐ M in N` は計算 M の結果を x に束縛して計算 N を続ける。この二つは、モナドの単位（pure）と bind に当たる。

### 表記

規則は次の記号で書く。

| 記号 | 意味 |
|---|---|
| `x`, `y`, `z` | 変数 |
| `f` | トップレベルの関数の名前 |
| `b` | 組み込みの関数（演算子と、[標準ライブラリ](../03-interop/03-06-stdlib.md)で実装を「組み込み」とする prelude の関数） |
| `C` | 構成子 |
| `α` | 型パラメータ |
| `ρ` | エフェクト変数 |
| `X̄` | `X1, …, Xn`（n ≥ 0）の並び |
| `M[V/x]` | M の中の自由な x を V で置き換えたもの（束縛変数の名前は衝突しないよう付け替える） |

型付け規則は、横線の上に前提を、下に結論を書く。

### 構文

【方針】コア計算の型、値、計算、パターンは次のとおりである。

```text
型          A, B ::= ι | O | D[Ā] | List[A] | (Ā) → B ! ε | α
基本型      ι    ::= Integer | Float | String | Character | Boolean | Unit
中身を見せない prelude の型
            O    ::= IOError
エフェクト  ε    ::= { e1, …, en }          （有限集合。n ≥ 0）
            e    ::= IO | ρ

値          V, W ::= x
                   | c                       （定数）
                   | f[T̄; Ē]                 （トップレベルの関数）
                   | b[T̄; Ē]                 （組み込みの関数）
                   | λ(x1:A1, …, xn:An). M   （関数）
                   | C[T̄](V̄)                 （構成子を適用した値）
                   | [V1, …, Vn]             （リスト）

計算        M, N ::= return V
                   | let x ⇐ M in N
                   | V(W̄)
                   | if V then M else N
                   | match V { p1 ⇒ M1 | … | pn ⇒ Mn }

パターン    p    ::= _ | x | c | C(p̄)

定義        d    ::= fn f[ᾱ; ρ̄](x1:A1, …, xn:An) : B ! ε = M
```

- `D` は代数的データ型の名前であり、prelude の `Option` と `Result` を含む。
- `O` は中身を見せない prelude の型であり、基本型にも代数的データ型にも含めない（[ADR 0048](../decisions/0048-ioerror-not-equality-type.md)）。
- 定数 `c` は、`Integer`・`Float`・`String`・`Character` の値、`true`、`false`、`()`、および IO の関数が返す `IOError` の値である。`Integer` の定数は負の値を含む。
- `f[T̄; Ē]` と `b[T̄; Ē]` は、型パラメータを型 `T̄` で、エフェクト変数をエフェクトの集合 `Ē` で置き換えた関数を表す。
- プログラムは、定義の集まり Σ と、型の宣言の集まりである。[標準ライブラリ](../03-interop/03-06-stdlib.md)で実装を「ソース」とする prelude の関数（関数を引数にとる `List.map` など）は、Σ に含まれる定義として与える。

`(Ā) → B ! ε` は、表層の `function(Ā) -> B uses ε` に当たる。`ε` が空集合のときは、表層の `uses` のない関数の型に当たる。

【方針】エフェクトの集合の置き換え `ε[E/ρ]` は、`ρ ∈ ε` なら `(ε ∖ {ρ}) ∪ E`、そうでなければ `ε` とする。型の置き換えは、型の中のすべての関数の型のエフェクトにも適用する。

### 型付け規則

【方針】型付けは次の二つの判断からなる。Γ は、変数と型の組の並びである。

- `Γ ⊢v V : A`: 値 V は型 A を持つ。
- `Γ ⊢c M : A ! ε`: 計算 M は、型 A の値を結果とし、実行するとエフェクト ε のうちのものを起こしうる。

#### 値

```text
(V-Var)   x : A ∈ Γ
          ───────────────
          Γ ⊢v x : A

(V-Const) ─────────────────
          Γ ⊢v c : type(c)

(V-Fun)   Σ に fn f[ᾱ; ρ̄](x̄:Ā) : B ! ε = M がある     θ = [T̄/ᾱ, Ē/ρ̄]
          ─────────────────────────────────────────────────────
          Γ ⊢v f[T̄; Ē] : ((Ā) → B ! ε)θ

(V-Prim)  b の型が ∀ᾱ ρ̄. (Ā) → B ! ε である     T̄ が b の型パラメータの制約を満たす     θ = [T̄/ᾱ, Ē/ρ̄]
          ─────────────────────────────────────────────────────
          Γ ⊢v b[T̄; Ē] : ((Ā) → B ! ε)θ

(V-Lam)   Γ, x1:A1, …, xn:An ⊢c M : B ! ε
          ─────────────────────────────────────────
          Γ ⊢v λ(x1:A1, …, xn:An). M : (Ā) → B ! ε

(V-Con)   C は D[ᾱ] の構成子で、引数の型は C̄ である     Γ ⊢v Vi : Ci[T̄/ᾱ]（各 i）
          ─────────────────────────────────────────────────────
          Γ ⊢v C[T̄](V̄) : D[T̄]

(V-List)  Γ ⊢v Vi : A（各 i）
          ─────────────────────────────
          Γ ⊢v [V1, …, Vn] : List[A]

(V-Sub)   Γ ⊢v V : A     A ≤ A'
          ─────────────────────
          Γ ⊢v V : A'
```

`type(c)` は定数の型である。組み込みの関数の型と、型パラメータの制約（組み込みの制約 `equality`・`key`、演算子の型の集まりのどれかであること）は[型システム](01-06-type-system.md)と[標準ライブラリ](../03-interop/03-06-stdlib.md)で定める。

【決定】`A ≤ A'` は、A と A' が等しいか、A が `(Ā) → B ! ε`、A' が `(Ā) → B ! ε'` で `ε ⊆ ε'` であることを表す。`≤` は型の最も外側の関数の型のエフェクトにだけ働き、[型システム](01-06-type-system.md)の「エフェクトの包含」に当たる。V-Sub と後述の C-Sub は、値と計算の結果が現れるどの位置でも使えるので、[型システム](01-06-type-system.md)で包含の規則が働く位置（[ADR 0046](../decisions/0046-effect-subsumption-at-all-flow-positions.md)）をすべて含む（[ADR 0081](../decisions/0081-subsumption-on-computation-results.md)）。

#### 計算

```text
(C-Return) Γ ⊢v V : A
           ─────────────────────────
           Γ ⊢c return V : A ! { }

(C-Sub)    Γ ⊢c M : A ! ε     A ≤ A'     ε ⊆ ε'
           ─────────────────────────────────
           Γ ⊢c M : A' ! ε'

(C-Let)    Γ ⊢c M : A ! ε     Γ, x:A ⊢c N : B ! ε
           ──────────────────────────────────────
           Γ ⊢c let x ⇐ M in N : B ! ε

(C-App)    Γ ⊢v V : (A1, …, An) → B ! ε     Γ ⊢v Wi : Ai（各 i）
           ─────────────────────────────────────────────
           Γ ⊢c V(W1, …, Wn) : B ! ε

(C-If)     Γ ⊢v V : Boolean     Γ ⊢c M : A ! ε     Γ ⊢c N : A ! ε
           ──────────────────────────────────────────────
           Γ ⊢c if V then M else N : A ! ε

(C-Match)  Γ ⊢v V : A     ⊢p pi : A ⊣ Δi（各 i）     Γ, Δi ⊢c Mi : B ! ε（各 i）
           p1, …, pn は A について網羅的である
           ─────────────────────────────────────────────
           Γ ⊢c match V { p1 ⇒ M1 | … | pn ⇒ Mn } : B ! ε
```

C-Sub は、計算を実行するエフェクトを広げることに加えて、計算の結果の型を `≤` で広げる。例えば、次の `widen` の本体は、脱糖すると `make` の呼び出し `make[;]()` であり、C-App による結果の型は純粋な関数の型である。C-Sub でこれを `uses Console.Write` の関数の型に広げるので、`widen` の本体に宣言した戻り値の型が付く。呼び出しを `let` の左側に移さないので、末尾呼び出しも保たれる。

```text
function make() -> function() -> Unit
  return lambda() () end lambda
end function

function widen() -> (function() -> Unit uses Console.Write)
  return make()
end function
```

網羅的であることの定義は[代数的データ型とパターンマッチ](01-05-data-types.md)の「網羅性の検査」に従う。

#### パターン

`⊢p p : A ⊣ Δ` は、パターン p が型 A の値に照合し、変数と型の組の並び Δ を束縛することを表す。

```text
(P-Wild)  ⊢p _ : A ⊣ ·

(P-Var)   ⊢p x : A ⊣ x:A

(P-Const) c は Float の値でも IOError の値でもない
          ─────────────────────────────────────
          ⊢p c : type(c) ⊣ ·

(P-Con)   C は D[ᾱ] の構成子で、引数の型は C̄ である     ⊢p pi : Ci[T̄/ᾱ] ⊣ Δi（各 i）
          Δ1, …, Δn の変数はすべて異なる
          ─────────────────────────────────────────────
          ⊢p C(p1, …, pn) : D[T̄] ⊣ Δ1, …, Δn
```

#### 定義

定義 `fn f[ᾱ; ρ̄](x̄:Ā) : B ! ε = M` は、`x1:A1, …, xn:An ⊢c M : B ! ε` が成り立つときに型が付く。このとき、ᾱ と ρ̄ は、ほかの何とも等しくない型とエフェクトとして扱う。

実行時エラーを起こしうることは、型にもエフェクトにも現れない（[ADR 0146](../decisions/0146-runtime-errors-not-in-types.md)）。

### 実行の規則

【方針】実行は、次の状態のあいだの遷移で定める。

```text
状態        S ::= ⟨M, K⟩ | error(r)
継続        K ::= [] | F :: K
枠          F ::= let x ⇐ □ in N
```

`⟨M, K⟩` は、計算 M を実行し、その結果を継続 K に渡す状態である。継続は枠の並びであり、枠 `let x ⇐ □ in N` は「結果を x に束縛して N を続ける」ことを表す。`error(r)` は、種類 r の実行時エラーで停止した状態である。

遷移 `S → S'` は IO を伴わない遷移、`S —ℓ→ S'` は IO の事象 ℓ を伴う遷移である。

```text
(E-Let)    ⟨let x ⇐ M in N, K⟩              →  ⟨M, (let x ⇐ □ in N) :: K⟩
(E-Return) ⟨return V, (let x ⇐ □ in N) :: K⟩  →  ⟨N[V/x], K⟩
(E-Lam)    ⟨(λ(x̄:Ā). M)(W̄), K⟩              →  ⟨M[W̄/x̄], K⟩
(E-Fun)    ⟨f[T̄; Ē](W̄), K⟩                  →  ⟨Mθ[W̄/x̄], K⟩
             ただし Σ に fn f[ᾱ; ρ̄](x̄:Ā) : B ! ε = M があり、θ = [T̄/ᾱ, Ē/ρ̄]
(E-IfT)    ⟨if true then M else N, K⟩        →  ⟨M, K⟩
(E-IfF)    ⟨if false then M else N, K⟩       →  ⟨N, K⟩
(E-Match)  ⟨match V { p1 ⇒ M1 | … | pn ⇒ Mn }, K⟩  →  ⟨Mi σ, K⟩
             ただし i は match(pi, V) = σ となる最小の番号
(E-Prim)   ⟨b[T̄; Ē](W̄), K⟩                  →  ⟨return V, K⟩     δ(b[T̄; Ē], W̄) = V のとき
(E-Err)    ⟨b[T̄; Ē](W̄), K⟩                  →  error(r)          δ(b[T̄; Ē], W̄) = error(r) のとき
(E-IO)     ⟨b[T̄; Ē](W̄), K⟩  —b(W̄) ↦ V→      ⟨return V, K⟩
(E-IOErr)  ⟨b[T̄; Ē](W̄), K⟩  —b(W̄) ↦ error(r)→  error(r)
```

- E-Prim と E-Err は、IO を行わない組み込みの関数に使う。δ は、[基本型の意味論](01-04-types-basic.md)、[型システム](01-06-type-system.md)の「等値の型」（代数的データ型とリストの `=`）、[標準ライブラリ](../03-interop/03-06-stdlib.md)が定める関数の値、または実行時エラーの種類を返す。δ は型引数 T̄ とエフェクト引数 Ē も受け取り、呼び出しの型引数に合わせた型引数を持つ構成子の値を返してよい（`List.head[T]` が空のリストに返す `None[T]()` など。[ADR 0296](../decisions/0296-delta-receives-type-arguments.md)）。処理系は型を消して値を表すので、組み込みの関数の実装には型引数を渡さない。
- E-IO と E-IOErr は、IO を行う組み込みの関数（[エフェクト](01-07-effects.md)）に使う。応答 V または error(r) は、プログラムの外部の状態によって決まる。[エフェクト](01-07-effects.md)は、関数ごとに、応答として起こりうるものと、事象が外部の状態に与える変化を定める。応答として起こりうるものは、型引数とエフェクト引数にもよってよい。型引数は IO の事象の表記に含めず、観測できる振る舞いに含めない（[ADR 0296](../decisions/0296-delta-receives-type-arguments.md)）。例えば `File.readText` の応答は `Result.Ok(s)` か `Result.Error(e)` の値である。標準出力と標準エラー出力への書き込みの関数の応答は常に `()` とし、書き込みの失敗は抽象機械の規則ではなく[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」の例外として定める（[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）。したがって、最小実行版の IO を行う関数に、E-IOErr を使うものはない。初回リリース版では、解放したリソースの使用（後述の「解放の枠と実行時エラーの継続：`with`」）、応答の二度目の送信（`Http.respond`）、引数が定義域の外（`Process.exit` の終了状態など。[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」）に E-IOErr を使う。初回リリース版の後にサーバモードとあわせて加える権限の拒否（[エフェクト](01-07-effects.md)の「実行時の権限制御（サーバモード）」。[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）にも、E-IOErr を使う。引数が定義域の外の誤りは引数だけで決まるが、外部に作用する操作を行う組み込みの関数では、ほかの応答と同じく E-IOErr で表す。
- `Mθ` は、M の中の型とエフェクトに置き換え θ を適用したものである。

【方針】`match(p, V)` は、パターン p に値 V が照合するときに、束縛する変数への置き換え σ を返す。照合しないときは定義しない。

```text
match(_, V)                 = []
match(x, V)                 = [V/x]
match(c, c')                = []                    c と c' が等しいとき
match(C(p1, …, pn), C[T̄](V1, …, Vn))  = σ1 ∪ … ∪ σn    各 i で match(pi, Vi) = σi のとき
```

定数どうしの等しさは、`=` の意味（[基本型の意味論](01-04-types-basic.md)）に従う。

【方針】プログラムの実行は、状態 `⟨main[;](), []⟩` から始める。実行は次のいずれかで終わる。

| 終わり方 | 状態 |
|---|---|
| 値 V で終わる | `⟨return V, []⟩` に達する |
| 実行時エラーで停止する | `error(r)` に達する |
| 停止しない | 遷移が無限に続く |

プログラムの観測できる振る舞いは、遷移に伴う IO の事象の列と、終わり方（実行時エラーで停止するときは、その種類を含む）である。実行時エラーの報告に書く位置と呼び出しの履歴は、観測できる振る舞いに含めない。`main` の結果の値と実行時エラーを、処理系がどう報告するかは[エフェクト](01-07-effects.md)と[評価意味論](01-08-evaluation.md)で定める。

### 末尾呼び出しの保証

【決定】E-Let だけが継続を伸ばし、関数の呼び出しの遷移（E-Lam、E-Fun、E-Prim、E-IO）は継続を伸ばさない（[ADR 0013](../decisions/0013-evaluation-order-and-tail-calls.md)）。処理系が、呼び出しから戻った後に続ける計算を保持するために使う記憶域の量は、継続 K の長さの、プログラムごとに決まる定数倍を超えてはならない。枠から参照する値そのものが使う記憶域は、この量に数えない。

したがって、`let` の左側にない呼び出し（末尾呼び出し）を何度続けても、この記憶域は増えない。表層のどの呼び出しが末尾呼び出しになるかは、[評価意味論](01-08-evaluation.md)の「末尾呼び出し」にまとめる。

### 置き換えてよい等式

【方針】次の各等式の左辺と右辺は、どの継続のもとで実行しても同じ観測できる振る舞いを示す。処理系は、左辺を右辺に置き換えてよい。

```text
let x ⇐ return V in M             ＝  M[V/x]
let x ⇐ M in return x             ＝  M
let y ⇐ (let x ⇐ M in N) in P     ＝  let x ⇐ M in (let y ⇐ N in P)     （x は P に自由に現れない）
```

三つの等式は、それぞれモナドの左単位則、右単位則、結合則に当たる。置き換えは、実行時エラーを起こす演算を変えないので、実行時エラーの種類と報告する位置を変えない。二つ目の等式で呼び出しが末尾呼び出しになると、呼び出しの履歴に現れる段が減ることがある。右辺を左辺に置き換えることは許さない。例えば二つ目の等式で、M が末尾呼び出しであるときに右辺を左辺に置き換えると、その呼び出しが `let` の左側に移り、継続が伸びるからである。

### 表層からの脱糖

【方針】表層の式 e を、コア計算の計算 `⟦e⟧` に移す。規則の中の `x`、`y`、`t`、`z` は、ソースに現れない新しい変数である。`[T̄; Ē]` は、型検査がその名前を使う位置に決めた置き換えである。

#### 名前とリテラル

| 表層 | コア計算 |
|---|---|
| 局所の束縛の名前 `x` | `return x` |
| トップレベルの関数の名前 `f` | `return f[T̄; Ē]` |
| prelude の関数 `M.g` | `return b[T̄; Ē]`（b は `M.g` に当たる組み込みの関数。Σ に定義があるものは `return M.g[T̄; Ē]`） |
| 引数のない構成子 `T.C`、`Option.None` | `return C[T̄]()` |
| 引数を持つ構成子 `T.C`、`Option.Some` などを、呼び出さずに値として使う | `return λ(y1:A1, …, yn:An). return C[T̄](y1, …, yn)`（`Ā` は構成子の引数の型） |
| リテラル | `return c`（c はリテラルが表す値） |
| 単項の `-` を整数リテラルに直接適用した式 `-n` | `return c`（c は −n） |
| `()` | `return ()` |
| `(e)` | `⟦e⟧` |

#### 呼び出し

プレースホルダを含む呼び出しは、[構文](01-02-syntax.md)の規則でラムダに展開してから、次の規則で移す。

| 表層 | コア計算 |
|---|---|
| 構成子の呼び出し `T.C(e1, …, en)`、`Option.Some(e1)`、`Result.Ok(e1)`、`Result.Error(e1)`（[ADR 0007](../decisions/0007-constructors-and-list.md)） | `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return C[T̄](x1, …, xn)` |
| そのほかの呼び出し `e0(e1, …, en)` | `let y ⇐ ⟦e0⟧ in let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in y(x1, …, xn)` |
| パイプ `e1 \|> e2` | `let t ⇐ ⟦e1⟧ in ⟦e'⟧`（e' は、[構文](01-02-syntax.md)の規則で `t \|> e2` を展開した式） |

#### 演算子

`⊕_T` は、演算子 ⊕ をオペランドの型 T で使う組み込みの関数を表す。T は型検査が決めた型である。

| 表層 | コア計算 |
|---|---|
| `e1 ⊕ e2`（⊕ は `+ - * / div mod = <> < <= > >=`） | `let x ⇐ ⟦e1⟧ in let y ⇐ ⟦e2⟧ in ⊕_T(x, y)` |
| `-e`（上の `-n` を除く） | `let x ⇐ ⟦e⟧ in neg_T(x)` |
| `not e` | `let x ⇐ ⟦e⟧ in if x then return false else return true` |
| `e1 and e2` | `let x ⇐ ⟦e1⟧ in if x then ⟦e2⟧ else return false` |
| `e1 or e2` | `let x ⇐ ⟦e1⟧ in if x then return true else ⟦e2⟧` |

#### リスト、ラムダ、条件分岐、match

| 表層 | コア計算 |
|---|---|
| `[e1, …, en]` | `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return [x1, …, xn]` |
| `lambda(x1, …, xn) B end lambda` | `return λ(x1:A1, …, xn:An). ⟦B⟧`（`Ā` は型検査が決めた引数の型） |
| `if e then B1 else B2 end if` | `let x ⇐ ⟦e⟧ in if x then ⟦B1⟧ else ⟦B2⟧` |
| `if e then B1 else if …` | `else if` からの続きを、`end if` で閉じた一つの `if` として B2 に置き、上の規則で移す |
| `if e then B1 end if`（`else` なし） | `let x ⇐ ⟦e⟧ in if x then ⟦B1⟧ else return ()` |
| `match e with case p1 -> B1 … case pn -> Bn end match` | `let x ⇐ ⟦e⟧ in match x { p1' ⇒ ⟦B1⟧ \| … \| pn' ⇒ ⟦Bn⟧ }` |

パターン `pi'` は、表層のパターン `pi` から構成子の型名の修飾を除き、`-n` の形の整数リテラルを負の定数にしたものである。

#### ブロック

ブロック（関数とラムダの本体、`if` と `match` の分岐など、文の並び）は、先頭の文から順に移す。表の `{ … }` は、文の並びを表す本章の記法であり、表層の構文ではない（表層は波括弧を使わない。[ADR 0108](../decisions/0108-keyword-blocks-closed-by-end.md)）。`s̄` は残りの文の並び、B は文の並びである。

| 表層 | コア計算 |
|---|---|
| `{ }` | `return ()` |
| `{ e }`（最後の文が式） | `⟦e⟧` |
| `{ bind x <- e }`（最後の文が束縛の文） | `let x ⇐ ⟦e⟧ in return ()` |
| `{ bind x <- e; s̄ }`（型注釈 `bind x: T <- e` も同じ） | `let x ⇐ ⟦e⟧ in ⟦{ s̄ }⟧` |
| `{ bind _ <- e; s̄ }` | `let z ⇐ ⟦e⟧ in ⟦{ s̄ }⟧` |
| `{ bind p <- e; s̄ }`（初回リリース版。p が変数と `_` 以外の、必ず照合するパターン） | `let z ⇐ ⟦e⟧ in match z { p' ⇒ ⟦{ s̄ }⟧ }` |
| `{ bind p <- e }`（同上で、最後の文） | `let z ⇐ ⟦e⟧ in match z { p' ⇒ return () }` |
| `{ e; s̄ }`（式文） | `let z ⇐ ⟦e⟧ in ⟦{ s̄ }⟧` |

ここでの `;` は、文の区切り（改行）を表す。`shadow` で始まる束縛の文も、表の `bind` を `shadow` に置き換えた形として、`bind` と同じコア計算に移す。`bind` と `shadow` の違いは、左辺の変数がその位置で局所の名前として見えているかどうかの条件（[名前・スコープ・モジュール](01-03-names-modules.md)の「シャドーイング」）だけであり、この条件は脱糖の前に検査を終える（[ADR 0255](../decisions/0255-bind-and-shadow.md)）。コア計算の `let x ⇐ M in N` は N の中で外側の x を隠すので、`shadow x <- e` の後の文の x は、脱糖した後も `shadow` の束縛を指す。

#### `return`

`return` は、それが末尾位置（[評価意味論](01-08-evaluation.md)の「末尾呼び出し」）にあるかどうかで移し方を変える。

| 表層 | コア計算 |
|---|---|
| `return e`（末尾位置にあるもの） | `⟦e⟧` |
| `return e`（末尾位置にないもの） | `let x ⇐ ⟦e⟧ in escape x`（後述の「関数の境界と `escape`：途中の `return` と `try`」） |

末尾位置にある `return e` を `⟦e⟧` に移すので、`return f(x)` の呼び出しは末尾呼び出しになる。本体のブロックが必ず抜けない関数（[型システム](01-06-type-system.md)の「必ず抜ける文」）の戻り値の型は `Unit` であり、本体の終わりに達したときのブロックの値は `()` なので、本体をそのまま移せばよい。

#### トップレベルの関数

`function f[ᾱ, effect ρ̄](x1: A1, …, xn: An) -> B uses ε B0` を、定義 `fn f[ᾱ; ρ̄](x1:A1, …, xn:An) : B ! ε = ⟦B0⟧` に移す。`uses` を書かない関数の ε は空集合である。

### 初回リリース版の拡張

【方針】初回リリース版の機能は、脱糖だけで表すものと、コア計算に構成を加えるものに分かれる。

| 機能 | 表し方 |
|---|---|
| モジュールと import、公開 | 脱糖だけで表す。名前解決の後、すべてのモジュールの定義を一つの Σ にまとめる |
| レコード | 脱糖だけで表す。構成子が一つの代数的データ型にする |
| 文字列補間 | 脱糖だけで表す |
| リストの展開（リストリテラルの `..e`） | 脱糖だけで表す。展開の前後の要素を並べたリストと `e` の値を、`List.concatenate` に当たる組み込みの関数でつなぐ（後述の「リストの展開」、[ADR 0272](../decisions/0272-list-spread-in-list-literals.md)） |
| パターンの拡張（ガード、選択肢、範囲、リストのパターン） | 脱糖だけで表す。選択肢は同じ本体を共有する複数の分岐に、ガードは照合した後の `if` と次の分岐への移動に、範囲は比較に、リストのパターンは長さの比較と `List` の組み込みの関数による取り出しに移す（[ADR 0121](../decisions/0121-pattern-extensions.md)） |
| 複数行の文字列と raw 文字列 | 字句の段で文字列の定数と文字列補間に移すので、コア計算に現れない |
| 基本型 `Byte`・`Decimal`、型 `Map`・`Set`・`Bytes` | 型、定数、値を加える（後述） |
| トップレベルの定数 | 脱糖だけで表す。定数の名前を、その定数式を脱糖した計算に置き換える（後述） |
| 型の別名 | 型検査で展開するので、コア計算に現れない（[ADR 0124](../decisions/0124-type-aliases.md)） |
| ドキュメントコメント | 意味を持たないので、コア計算に現れない |
| 型クラス | 辞書の型と値、メソッドの呼び出しを加える |
| 型パラメータの組み込みの制約（`equality`・`key`） | 定義の型パラメータに制約を加え、V-Prim と V-Fun で使う（後述の「型パラメータの組み込みの制約」） |
| 可変のセル、明示遅延 | 状態にストアを加える |
| `try` | 関数の境界の印と、関数から抜ける計算 `escape` を使う。この二つは、途中の `return` のためにも使う（後述） |
| `with` | 解放の枠を加え、実行時エラーの状態に継続を持たせる |
| 組み込みの細かいエフェクト | エフェクトの名前を加える。まとめたエフェクト `IO.All` は、脱糖で、まとめたエフェクトの名前の集合に置き換える（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)） |
| エフェクトの宣言とハンドラ | 操作の呼び出し、`handle` の枠と `drop` の枠、一度だけ再開できる継続をストアに加える |
| 終了状態を指定したプロセスの終了 | 終了の状態を加える |

以下の規則は、前節までの規則に加えるか、置き換えるものである。前節までの規則のうち、ここで置き換えないものは初回リリース版でもそのまま使う。

#### モジュール

名前解決は、各モジュールのトップレベルの名前（エフェクトの名前と、エフェクトの操作を含む）を、モジュールの同一性（[名前・スコープ・モジュール](01-03-names-modules.md)）と組にした一意な名前に付け替える。標準ライブラリのモジュールの同一性は、`Benitoite` の名前空間の名前（`Benitoite.IO.File` など）である（[ADR 0128](../decisions/0128-prelude-and-benitoite-namespace.md)）。したがって、修飾に使った取り込みの名前によらず、同じモジュールの同じ名前は同じ一意な名前になる。脱糖は、プログラムを構成するすべてのモジュールの定義を一つの Σ にまとめ、型の宣言も一つの集まりにまとめる。公開の検査は脱糖の前に終える。コア計算には、モジュールも公開も現れない。

#### トップレベルの定数

定数 `const k: A = e` の名前 `k` を、`⟦e⟧` に置き換える（[ADR 0123](../decisions/0123-top-level-constants.md)）。`e` の中の定数の名前も同じく置き換える。定数どうしの参照は循環しない（[名前・スコープ・モジュール](01-03-names-modules.md)）ので、置き換えは終わる。定数式は、利用者が書いた関数の呼び出しとエフェクトを含まず、計算が実行時エラーの条件に当たらないことを型検査で確かめてある（[型システム](01-06-type-system.md)の「定数の型（初回リリース版）」）。したがって、`⟦e⟧` はどこで評価しても同じ値を返して終わり、定数を参照するたびに計算しても、プログラムの実行の前に一度だけ計算して値を共有しても、観測できる違いはない。

#### 基本型とコレクションの型

【方針】初回リリース版の基本型 `Byte`・`Decimal`（[基本型の意味論](01-04-types-basic.md)、[ADR 0105](../decisions/0105-byte-type.md)、[ADR 0114](../decisions/0114-decimal-type.md)）と、prelude の型 `Map[K, V]`・`Set[T]`・`Bytes`（[標準ライブラリ](../03-interop/03-06-stdlib.md)、[ADR 0103](../decisions/0103-map-and-set-ordered-by-key.md)、[ADR 0107](../decisions/0107-bytes.md)）のために、次のものを加える。

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

展開を含むリストリテラルは、要素と展開の式を書いた順に評価して束縛し、`concat_T`（`List.concatenate` に当たる組み込みの関数。T は要素の型）でつなぐ。

| 表層 | コア計算 |
|---|---|
| `[e1, …, ek, ..e, ek+1, …, en]` | `let x1 ⇐ ⟦e1⟧ in … let xk ⇐ ⟦ek⟧ in let s ⇐ ⟦e⟧ in let xk+1 ⇐ ⟦ek+1⟧ in … let xn ⇐ ⟦en⟧ in let y ⇐ concat_T([x1, …, xk], s) in concat_T(y, [xk+1, …, xn])` |

k が 0 のとき（展開が先頭）と k が n のとき（展開が末尾）も、同じ規則で移す。処理系は、空のリストとの `concat_T` を省いてよい。空のリストとの連結は元のリストを値とし、結果の長さも変わらないので、観測できる振る舞いが変わらないからである。

#### レコード

フィールド `f1: A1, …, fn: An` を宣言の順に持つレコード `R[ᾱ]` は、引数 `A1, …, An` をとる構成子 `C_R` を一つだけ持つ代数的データ型 `R[ᾱ]` として扱う。

| 表層 | コア計算 |
|---|---|
| `R(g1: e1, …, gn: en)`（`g` は書いた順のフィールド名） | `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return C_R[T̄](y1, …, yn)`（`yi` は、宣言の i 番目のフィールドを書いた位置の `xj`） |
| `R(..e, g1: e1, …, gk: ek)` | `let r ⇐ ⟦e⟧ in let x1 ⇐ ⟦e1⟧ in … let xk ⇐ ⟦ek⟧ in match r { C_R(z1, …, zn) ⇒ return C_R[T̄](y1, …, yn) }`（`yi` は、宣言の i 番目のフィールドを書き換えたなら対応する `xj`、そうでなければ `zi`。`T̄` は e の型 `R[T̄]` の型引数であり、更新の結果は e と同じ型を持つ） |
| フィールドを取り出す関数 `R.fi` | Σ の定義 `fn R.fi[ᾱ; ](r:R[ᾱ]) : Ai ! { } = match r { C_R(z1, …, zn) ⇒ return zi }` を参照する |
| パターン `R(g1: p1, …, gk: pk)`、`R(g1: p1, …, ..)` | `C_R(q1, …, qn)`（`qi` は、宣言の i 番目のフィールドを書いたなら対応する `pj'`、書いていなければ `_`） |

#### 文字列補間

`str_T` は、文字列補間で型 T の値を文字列にする組み込みの関数である（`String` はそのまま、`Integer`・`Float`・`Character`・`Byte`・`Decimal` はそれぞれの `toString`、`Boolean` は `"true"` か `"false"`。[基本型の意味論](01-04-types-basic.md)、[ADR 0058](../decisions/0058-string-interpolation-of-base-types.md)、[ADR 0114](../decisions/0114-decimal-type.md)）。

| 表層 | コア計算 |
|---|---|
| `"s0${e1}s1…${en}sn"` | `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in let y1 ⇐ str_T1(x1) in … let yn ⇐ str_Tn(xn) in` に続けて、`s0`、`y1`、`s1`、…、`yn`、`sn` を左から順に `+_String` で連結する計算 |

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
- 【決定】型クラス Cl が上位の型クラス S1, …, Sl を持つとき（[型システム](01-06-type-system.md)の「型クラス（初回リリース版）」）、Cl の実装の定義は、各 Sj の τ についての辞書 Uj を持つ（[ADR 0134](../decisions/0134-standard-type-classes.md)）。Uj は値であり、実装の制約の辞書の引数 d̄ を使ってよい。`V↑S` は、辞書 V が持つ上位の型クラス S の辞書を取り出す。上位の型クラスの上位の型クラスの辞書は、`↑` を重ねて取り出す（`V↑Monoid↑Semigroup`）。
- 【決定】組み込みの制約（`equality`・`key`）は、辞書の引数を持たない（[ADR 0133](../decisions/0133-builtin-equality-and-key-constraints.md)）。`=` は値の構造で比べる組み込みの操作であり、鍵の順序はすべての鍵の型の値に定まっているので、実行時に実装を選ぶ必要がない。組み込みの制約は、定義の型パラメータの制約としてコア計算に残す（後述の「型パラメータの組み込みの制約」、[ADR 0297](../decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。V-Dict と C-Meth も、実装とメソッドの型パラメータについて、型引数が制約を満たすことを前提に持つ。
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

`↑` を含む辞書は値であり、メソッドの呼び出しの辞書になるまでそのまま受け渡す。メソッドの呼び出しの辞書が `↑` を含むときは、E-Super が `↑` を一段ずつ取り出し、実装の辞書 `I[T̄](V̄)` の形になったところで E-Meth を使う。V-Super と E-Super により、`↑` で取り出した辞書は、上位の型クラスの実装の辞書と同じ働きをする。E-Super を値の等しさでなく遷移として定めるのは、上位の型クラスの辞書が互いを指す実装の定義で、実装の辞書に行き着かずに進行が破れるのを避けるためである（[ADR 0305](../decisions/0305-e-super-as-transition-at-method-call.md)。そのような定義では、E-Super の遷移が終わらない）。

D-Impl では、β̄、γ̄j、ρ̄j を、ほかの何とも等しくない型とエフェクトとして扱う。実装の本体の中で、実装の制約 `Cl'[β']` を満たす辞書が要るときは、対応する辞書の引数 d を使う。

脱糖は、型検査が各制約に決めた辞書を使う。制約の型が具体的な型構成子なら、その実装の辞書 `I[T̄](V̄)` を作る（実装の制約の辞書 V̄ も同じように決める）。制約の型が関数か実装の型パラメータなら、その関数か実装が受け取った辞書の引数を使う。受け取った辞書の引数が要る制約 `S[α]` そのものでなく、S を上位の型クラスに持つ型クラス C の制約 `C[α]` の辞書 d であれば、`d↑S` を使う（上位の型クラスを何段か辿るときは `↑` を重ねる）。メソッド自身の制約の辞書 Ū も、同じ規則で決める。実装の定義の上位の型クラスの辞書 U1, …, Ul も、実装の型パラメータの制約の辞書 d̄ を受け取った辞書の引数として、同じ規則で決める。

| 表層 | コア計算 |
|---|---|
| メソッドの呼び出し `Cl.m(e1, …, en)`（辞書は V、m 自身の制約の辞書は Ū） | `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in V.m[S̄; Ē](Ū, x1, …, xn)` |
| メソッドを値として使う `Cl.m` | `return λ(y1:A1, …, yn:An). V.m[S̄; Ē](Ū, y1, …, yn)`（`Ā` は値の引数の型） |
| 制約を持つ関数 `f` の呼び出し | 決めた辞書を、値の引数の前に並べて渡す |
| 制約を持つ関数 `f` を呼ばずに値として使う | `return λ(y1:A1, …, yn:An). f[T̄; Ē](Ū, y1, …, yn)`（Ū は決めた辞書、`Ā` は値の引数の型） |

#### 型パラメータの組み込みの制約

【方針】初回リリース版では、定義の型パラメータに組み込みの制約を持たせる（[ADR 0297](../decisions/0297-builtin-constraints-in-core-and-op-type-substitution.md)）。実装の定義とメソッドの定義の型パラメータも同じく制約を持つ。

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

【方針】状態に、ストア σ（場所 ℓ から中身への有限の対応）を加える。状態は `⟨M, K, σ⟩` とし、前節までの遷移は σ を変えずにそのまま持ち越す。

```text
値          V ::= … | ℓ                        （場所）
型          A ::= … | Reference[A] | Lazy[A]
ストアの中身      ::= V | thunk(M) | done(V)
計算        M ::= … | lazy M
枠          F ::= … | update ℓ □

(E-RefNew)   ⟨Reference.new[A](V), K, σ⟩       →  ⟨return ℓ, K, σ[ℓ ↦ V]⟩         ℓ は σ にない新しい場所
(E-RefGet)   ⟨Reference.get[A](ℓ), K, σ⟩       →  ⟨return σ(ℓ), K, σ⟩
(E-RefSet)   ⟨Reference.set[A](ℓ, V), K, σ⟩    →  ⟨return (), K, σ[ℓ ↦ V]⟩
(E-Lazy)     ⟨lazy M, K, σ⟩              →  ⟨return ℓ, K, σ[ℓ ↦ thunk(M)]⟩  ℓ は σ にない新しい場所
(E-ForceDone)⟨Lazy.force[A](ℓ), K, σ⟩    →  ⟨return V, K, σ⟩                 σ(ℓ) = done(V) のとき
(E-Force)    ⟨Lazy.force[A](ℓ), K, σ⟩    →  ⟨M, (update ℓ □) :: K, σ⟩        σ(ℓ) = thunk(M) のとき
(E-Update)   ⟨return V, (update ℓ □) :: K, σ⟩  →  ⟨return V, K, σ[ℓ ↦ done(V)]⟩
```

- `⟦lazy B end lazy⟧` は `lazy ⟦B⟧` である（B は文の並び）。`Γ ⊢c M : A ! { }` のとき `Γ ⊢c lazy M : Lazy[A] ! { }` とする。`Reference.new`・`Reference.get`・`Reference.set` の型は[エフェクト](01-07-effects.md)の「可変のセル（初回リリース版）」に従い、`State` を持つ。
- ストアの遷移は IO の事象を伴わない。ストアは観測できる振る舞いに含めない。
- `Reference.new`・`Reference.get`・`Reference.set`・`Reference.update`・`Lazy.force` の呼び出しには、E-Prim・E-Err・E-IO・E-IOErr を使わず、本節の規則だけを使う。
- `Reference.update[A](ℓ, V)` は、`let x ⇐ Reference.get[A](ℓ) in let y ⇐ V(x) in Reference.set[A](ℓ, y)` と同じく遷移する。V は純粋な関数なので、V の呼び出しはストアを変えない。並行に進むタスクの間でこの三つが一つのまとまりとして起きることは[並行処理](01-11-concurrency.md)で定める。
- `thunk(M)` の実行の途中で、同じ場所 ℓ を `Lazy.force` することはない。E-Lazy で ℓ を作る時点で M は ℓ を含まず、M の実行が ℓ に辿り着く経路もないからである。`lazy` の本体は純粋なので、本体の中でセルを読み書きして ℓ を取り出せない。束縛の文は再帰的な束縛ではなく、ラムダは自分自身を名前で参照できず、トップレベルには値を置けない（[ADR 0055](../decisions/0055-top-level-functions-and-types-only.md)）ので、ℓ を束縛した名前を M の中から参照する手段もない。

#### 関数の境界と `escape`：途中の `return` と `try`

【方針】途中の `return`（[ADR 0096](../decisions/0096-explicit-return.md)）と `try`（[ADR 0097](../decisions/0097-prefix-try.md)）のために、継続に関数の境界の印 `mark` を加える。途中の `return` は初回リリース版の機能ではないが、規則をこの節にまとめる。関数の呼び出しは、継続の先頭が `mark` でなければ `mark` を積み、先頭が `mark` なら積まない。

```text
枠          F ::= … | mark
計算        M ::= … | escape V

mark ▷ K  =  K            （K の先頭が mark のとき）
mark ▷ K  =  mark :: K    （それ以外）

(E-Lam)    ⟨(λ(x̄:Ā). M)(W̄), K, σ⟩   →  ⟨M[W̄/x̄], mark ▷ K, σ⟩            （前節の E-Lam を置き換える）
(E-Fun)    ⟨f[T̄; Ē](W̄), K, σ⟩       →  ⟨Mθ[W̄/x̄], mark ▷ K, σ⟩           （前節の E-Fun を置き換える）
(E-Meth)   右辺の継続を mark ▷ K とする                                    （前節の E-Meth を置き換える）
(E-Mark)   ⟨return V, mark :: K, σ⟩  →  ⟨return V, K, σ⟩
(E-EscLet) ⟨escape V, F :: K, σ⟩     →  ⟨escape V, K, σ⟩                  F が let の枠のとき
(E-EscMark)⟨escape V, mark :: K, σ⟩  →  ⟨return V, K, σ⟩
```

`try` は次のように移す。`try` は右の式全体にかかるので、パイプを含む式は、[構文](01-02-syntax.md)の規則で展開してから移す。

| 表層 | コア計算 |
|---|---|
| `try e`（`e` が `Result[T, E]`、関数の戻り値の型が `Result[U, E]`） | `let x ⇐ ⟦e⟧ in match x { Ok(y) ⇒ return y \| Error(z) ⇒ escape Error[U, E](z) }` |
| `try e`（`e` が `Option[T]`、関数の戻り値の型が `Option[U]`） | `let x ⇐ ⟦e⟧ in match x { Some(y) ⇒ return y \| None ⇒ escape None[U]() }` |

`escape V` の型付けには、最も内側の関数の戻り値の型 R を使う。計算の判断を `Γ; R ⊢c M : A ! ε` に広げ、V-Lam と定義の型付けは本体を `R := B` で検査する。`Γ; R ⊢v V : R` のとき、`Γ; R ⊢c escape V : A ! ε` が任意の A と ε について成り立つ。`lazy M` の M は、R を持たない判断で検査し、`escape` を含めない。したがって、`lazy` のブロックの中には、内側のラムダの中を除き、途中の `return` と `try` を書けない。`lazy` のブロックの中の `return` は、末尾位置にないものとして扱う。前節までの規則は、R をそのまま受け渡す。

`mark` を積むのは、継続の先頭が `mark` でないときに限るので、末尾呼び出しを何度続けても継続は伸びない。末尾呼び出しで関数 g から関数 h に移った後に h の中で `escape` すると、g の呼び出しの結果として返る。末尾位置の呼び出しの結果は g の結果でもあるので、これは表層の途中の `return` と `try` の意味（最も内側の関数から返る）と一致する。

#### 解放の枠と実行時エラーの継続：`with`

【方針】継続に、解放の枠を加え、実行時エラーの状態に継続を持たせる。

```text
枠          F ::= … | release V
計算        M ::= … | use V in M
状態        S ::= ⟨M, K, σ⟩ | error(r̄, K, σ)      （r̄ は実行時エラーの種類の並び）

(E-Use)       ⟨use V in M, K, σ⟩             →  ⟨M, (release V) :: K, σ⟩
(E-Release)   ⟨return W, (release V) :: K, σ⟩   —release(V) ↦ ok→       ⟨return W, K, σ⟩
(E-RelErr)    ⟨return W, (release V) :: K, σ⟩   —release(V) ↦ error(r)→  error(r, K, σ)
(E-EscRel)    ⟨escape W, (release V) :: K, σ⟩   —release(V) ↦ ok→       ⟨escape W, K, σ⟩
(E-EscRelErr) ⟨escape W, (release V) :: K, σ⟩   —release(V) ↦ error(r)→  error(r, K, σ)
(E-ErrPop)    error(r̄, F :: K, σ)             →  error(r̄, K, σ)       F が release の枠でないとき
(E-ErrRel)    error(r̄, (release V) :: K, σ)   —release(V) ↦ ok→       error(r̄, K, σ)
(E-ErrRelErr) error(r̄, (release V) :: K, σ)   —release(V) ↦ error(r)→  error(r̄ r, K, σ)
```

- 前節の E-Err と E-IOErr の右辺 `error(r)` は、`error(r, K, σ)` と読み替える。前節の終わり方の表の `error(r)` は、`error(r̄, [], σ)` に達することと読み替える。報告する実行時エラーは、r̄ の先頭であり、残りは解放の失敗として報告に加える（[リソース管理](01-10-resources.md)）。
- `use V in M` のエフェクトは、解放のエフェクト `State` を含む（[リソース管理](01-10-resources.md)、[ADR 0150](../decisions/0150-resource-release-as-state.md)）。事象 `release(V)` は、継続にどの `handle` の枠があっても、ハンドラを調べずに起こす。`State` はハンドラで処理できないので、この規則は `handle` の式の型付け（C-Handle）と矛盾しない。
- リソースが解放済みかどうかは、プログラムの外部の状態の一部とする。事象 `release(V)` は、応答が `ok` か `error(r)` かによらず、V を解放済みにする。`close` などの解放する関数も、応答が `Result.Error` であってもリソースを解放済みにする（[リソース管理](01-10-resources.md)）。
- 解放したリソースの使用は、そのリソースの操作の IO の応答 `error(r)`（E-IOErr）として扱う。δ は引数だけで値が決まる関数なので、外部の状態で決まるこの誤りを δ では表さない。
- 解放の失敗を実行時エラーにしないリソースの型（`Http.Exchange`。[リソース管理](01-10-resources.md)の「解放の失敗」、[ADR 0149](../decisions/0149-http-exchange-release-failure.md)）の V についての `release(V)` は、外部の状態によらず応答が常に `ok` である。したがって、E-RelErr・E-EscRelErr・E-ErrRelErr・E-ExitRelErr は、このリソースの型には使わない。
- 解放済みの V についての `release(V)` は、応答が常に `ok` であり、外部の状態を変えない。処理系はこの事象について何も行わず、観測できる振る舞いの IO の事象の列にも数えない。したがって、`close` で解放したリソースを `with` がもう一度解放することはない。

`with` は次のように移す。

| 表層 | コア計算 |
|---|---|
| `with x1 = e1, …, xn = en do B end with` | `let x1 ⇐ ⟦e1⟧ in use x1 in (let x2 ⇐ ⟦e2⟧ in use x2 in … (let xn ⇐ ⟦en⟧ in use xn in ⟦B⟧) …)` |

#### プロセスの終了

【方針】終了状態を指定したプロセスの終了（[エフェクト](01-07-effects.md)の「影響の大きい操作（初回リリース版）」）は、終了の状態に移る。終了の状態は、実行時エラーの状態と同じく、継続に残る解放の枠を内側から順に実行してから終わる。

```text
状態        S ::= … | exit(n, r̄, K, σ)      （n は終了状態、r̄ は解放の失敗の並び）

(E-Exit)       ⟨b[T̄; Ē](W̄), K, σ⟩            —b(W̄) ↦ exit(n)→        exit(n, ·, K, σ)
(E-ExitPop)    exit(n, r̄, F :: K, σ)          →  exit(n, r̄, K, σ)       F が release の枠でないとき
(E-ExitRel)    exit(n, r̄, (release V) :: K, σ)  —release(V) ↦ ok→       exit(n, r̄, K, σ)
(E-ExitRelErr) exit(n, r̄, (release V) :: K, σ)  —release(V) ↦ error(r)→  exit(n, r̄ r, K, σ)
```

- E-Exit は、b が終了状態を指定したプロセスの終了の関数のときに使い、この関数には E-IO を使わない。`·` は空の並びである。`Process.Exit` の許可がないときの応答は `error(r)`（E-IOErr）である（サーバモード）。
- `exit(n, r̄, [], σ)` に達したら、終了状態 n で終わる。r̄ が空でなければ、処理系は解放の失敗を標準エラー出力に報告する。終了状態は n のまま変えない（[エフェクト](01-07-effects.md)）。

#### エフェクトの名前と開始状態

【方針】初回リリース版のエフェクトの名前は、組み込みのエフェクトと、利用者が宣言したエフェクトである（[エフェクト](01-07-effects.md)）。どちらも、宣言したモジュールと名前の組で識別する（前述の「モジュール」、[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）。表層の `IO.All` は、脱糖で、`State` と `Benitoite.IO` の下のすべての組み込みのエフェクトの名前の集合に置き換える（[ADR 0130](../decisions/0130-builtin-effect-names-and-placement.md)）。表層の `IO`（最小実行版の書き方）は、初回リリース版では型検査の前の誤りであり、コア計算に移さない。リソースの型と、標準ライブラリのモジュールが宣言する中身を見せない型（`Regex.Pattern` など。[ADR 0168](../decisions/0168-regex-match-and-stdlib-opaque-values.md)）は、中身を見せない型として O に含める。

```text
            e ::= L | ρ                    （L はエフェクトの名前）
            O ::= IOError | NetworkError | Task[A] | リソースの型
```

- プログラムの実行は、`⟨main[;](), [], ∅⟩` から始める（[ADR 0117](../decisions/0117-capabilities-as-effects.md)）。
- 実行時の権限制御の許可は、コア計算に現れない。許可していない操作は、その操作の IO の応答 `error(r)`（E-IOErr）として表す。
- 本章の IO の事象、E-IO と E-IOErr、観測できる振る舞いの IO の事象の列は、初回リリース版では、ネットワークの操作を含む外部に作用する操作（[エフェクト](01-07-effects.md)、[ADR 0140](../decisions/0140-network-separated-from-local-io.md)）について定める。
- 並行処理のタスク（[並行処理](01-11-concurrency.md)）は、本章のコア計算に含めない。

#### ハンドラ

【方針】操作の呼び出しとハンドラのために、値に操作と継続の場所を、計算に `handle` と `resume` を、継続に `handle` の枠と `drop` の枠を加える（[ADR 0118](../decisions/0118-effect-handlers.md)）。

```text
値          V ::= … | op[T̄]                    （操作）
                  | κ                          （継続の場所）
型          A ::= … | Cont(B → A ! ε)          （継続の型。項に書く型には含めない）
計算        M ::= … | handle M with H
                  | resume κ V
節の並び    H ::= { op1(x̄1) k ⇒ N1 | … | opn(x̄n) k ⇒ Nn }
枠          F ::= … | handle □ with H | drop κ
ストアの中身      ::= … | cont(K) | used
```

- 操作 `op` は、エフェクト L の宣言が定める `∀ᾱ. (Ā) → B ! {L}` の型を持つ（V-Prim と同じく型付けする）。表層では、操作は L を宣言したモジュールの関数として書く（[ADR 0129](../decisions/0129-effects-declared-in-modules.md)）が、脱糖した後は、ほかの関数と区別した op である。組み込みのエフェクトの操作は、外部に作用する操作（IO とネットワークの操作）を行う組み込みの関数 b である。`State` は操作を持たず、`State` を型に持つ組み込みの関数（可変のセルとタスクの集まりの関数、`Task.await`、リソースを解放する関数）は op ではない。
- 節 `op(x̄) k ⇒ N` の k は、節の中で継続を指す変数である。表層の `resume(v)` は `resume k ⟦v⟧` に移す。
- `handles(H, op)` は、H が op の節を持つことを表す。`handled(H)` は、一つ以上の操作を持ち、そのすべての操作の節を H が持つエフェクトの集合である。操作を持たない `State` は、どの H の `handled(H)` にも含まれない。

型付けは次のとおりである。継続の型の値（節の変数 k と、継続の場所 κ）は、`resume` の第一引数にだけ書ける。V-Var は継続の型を持つ変数に型を付けず、継続の場所は値として型が付かない（[ADR 0300](../decisions/0300-continuations-second-class-drop-state-and-store-domain.md)。表層でも、節の継続は `resume(v)` の形でだけ使える）。継続の型は、節の変数 k の型として環境に現れるか、ストアの型付け Ψ に現れるだけであり、項に書く型（ラムダの引数の型注釈と、関数・組み込みの関数・操作・構成子の型引数）には、ほかの型の中に含む形も含めて書けない（[ADR 0303](../decisions/0303-no-continuation-types-in-terms.md)。型引数に書けると、型パラメータの変数に置き換えの後で継続の型が付く。表層には継続の型の構文がない）。V-Lam の前提と、`lazy M` の M の検査では、Γ から継続の型を持つ変数を除く。したがって、ラムダの本体と `lazy` の本体では `resume` に型が付かない（[ADR 0155](../decisions/0155-resume-not-in-lazy.md)）。

```text
(C-Handle) Γ; R ⊢c M : T ! εM     εM ⊆ ε ∪ handled(H)
           H の各節 op(x̄) k ⇒ N について、op : ∀ᾱ. (Ā) → B ! {L}、ᾱ はほかの何とも等しくない型として
             Γ, x̄:Ā, k:Cont(B → T ! ε); R ⊢c N : T ! ε
           ─────────────────────────────────────────────
           Γ; R ⊢c handle M with H : T ! ε

(C-Resume) k : Cont(B → T ! ε) ∈ Γ     Γ ⊢v V : B
           ─────────────────────────────────────
           Γ; R ⊢c resume k V : T ! ε
```

実行の規則は次のとおりである。K1 ++ K2 は継続の連結、`releases(K)` は K の中の `release` の枠と `drop` の枠だけを、順序を保って並べた継続である。

```text
(E-Handle)   ⟨handle M with H, K, σ⟩                   →  ⟨M, (handle □ with H) :: K, σ⟩
(E-HRet)     ⟨return V, (handle □ with H) :: K, σ⟩      →  ⟨return V, K, σ⟩
(E-Op)       ⟨op[T̄](W̄), K1 ++ (handle □ with H) :: K2, σ⟩
                →  ⟨Nθ[W̄/x̄, κ/k], (drop κ) :: K2, σ[κ ↦ cont(K1 ++ (handle □ with H) :: [])]⟩
                ただし op(x̄) k ⇒ N は H の節、K1 の中の handle の枠はどれも op の節を持たない、κ は σ にない新しい場所、θ = [T̄/ᾱ]（ᾱ は op の型パラメータ。ADR 0297）
(E-Resume)   ⟨resume κ V, K, σ⟩       →  ⟨return V, K' ++ K, σ[κ ↦ used]⟩    σ(κ) = cont(K') のとき
(E-ResumeErr)⟨resume κ V, K, σ⟩       →  error(r_resume, K, σ)               σ(κ) = used のとき
(E-Drop)     ⟨return V, (drop κ) :: K, σ⟩  →  ⟨return V, K, σ⟩               σ(κ) = used のとき
(E-DropRel)  ⟨return V, (drop κ) :: K, σ⟩  →  ⟨return V, releases(K') ++ K, σ[κ ↦ used]⟩   σ(κ) = cont(K') のとき
```

- E-Op は、op を処理する最も内側の `handle` の枠を探し、そこまでの継続（その `handle` の枠を含む）を場所 κ に移して、節を実行する。`handle` の枠を継続に含めるので、再開した続きの中で呼んだ op も同じハンドラが処理する（深いハンドラ）。
- 組み込みの操作 b には、継続に b の節を持つ `handle` の枠がないときにだけ、E-IO・E-IOErr・E-Exit を使う。枠があるときは E-Op を使う。`State` を型に持つ組み込みの関数は操作ではないので、常にストアの規則を使う。
- r_resume は、継続の二度目の再開の実行時エラーの種類である。
- 節が `resume` を呼ばずに値で終わると、E-DropRel が、捨てる続きの中の `release` の枠を内側から順に実行する。捨てる続きの中に `drop κ'` の枠があれば（続きの中の節が、再開する前に外側のハンドラの操作を呼んだとき）、その枠に達したときに、同じ規則で κ' の続きの中の `release` の枠も実行する。したがって、入れ子に捨てた続きの中のリソースも、内側から順に一度ずつ解放する。`escape`、実行時エラーの状態、終了の状態が `drop κ` の枠を通るときも、σ(κ) = cont(K') なら、同じく `releases(K')` を継続の先頭に加え、κ を used にしてから進む。σ(κ) = used なら、`drop κ` の枠を取り除くだけである。
- `escape` と、実行時エラーの状態と終了の状態は、`handle` の枠を取り除いて進む（E-EscLet・E-ErrPop・E-ExitPop の「let の枠」「release の枠でない枠」に `handle` の枠を含める）。

#### 末尾呼び出しの保証の読み替え

【決定】処理系が呼び出しから戻った後に続ける計算を保持する記憶域の量は、初回リリース版でも、継続 K の長さのプログラムごとに決まる定数倍を超えてはならない（[ADR 0013](../decisions/0013-evaluation-order-and-tail-calls.md)）。

【方針】初回リリース版の継続は、`let` の枠のほかに、`mark`、`update`、`release`、`handle`、`drop` の枠を含む。前節の「E-Let だけが継続を伸ばし、関数の呼び出しの遷移は継続を伸ばさない」は、初回リリース版では次のように置き換える。

- 継続を伸ばすのは、E-Let、E-Force、E-Use、E-Handle、E-Op と、継続の先頭が `mark` でないときの関数の呼び出しの遷移（E-Lam、E-Fun、E-Meth）である。E-Resume は、捕まえた継続の長さだけ継続を伸ばす。
- `mark` を積むのは先頭が `mark` でないときに限るので、継続の中で `mark` は連続しない。したがって、継続の中の `mark` の数は、`mark` 以外の枠の数に 1 を足した数を超えない。
- 末尾呼び出しは `mark` 以外の枠を増やさないので、末尾呼び出しを何度続けても継続は伸びない。`with` のブロックの中、`lazy` の本体の中、`handle` の本体と節の中の呼び出しは、その後に解放の枠、`update` の枠、`handle` の枠、`drop` の枠が残るので、末尾呼び出しではない（[評価意味論](01-08-evaluation.md)の「末尾呼び出し」）。

### 確かめる性質

【方針】次の性質が成り立つように、本章と[型システム](01-06-type-system.md)を定める。形式検証の段階 1（[ロードマップ](../00-overview/00-03-roadmap.md)）で、ランダムに生成したプログラムを使って反例を探す。反例が見つかれば、仕様の誤りとして直す。性質 2 と性質 3 は、形式検証の段階 2 で、規則を Lean 4 で定義し、組み込みの関数についての仮定のもとで証明した。性質 1 は証明していない（[形式意味論と検証](../07-quality/07-04-formal-semantics.md)、[ADR 0293](../decisions/0293-formal-verification-stage-2-alongside-first-release.md)）。形式化した規則は Lean の定義を正とする（前述の「本章の位置付け」、[ADR 0307](../decisions/0307-lean-definitions-normative-for-core-calculus.md)）。

1. 脱糖の型の保存: [型システム](01-06-type-system.md)の型検査を通ったプログラムを脱糖すると、すべての定義に型が付く。
2. 進行と保存: 型が付いた状態 `⟨M, K⟩` は、`⟨return V, []⟩` であるか、遷移できる。遷移した先の状態も型が付くか、`error(r)` である。IO の応答は、関数の戻り値の型の値であるとする。
3. エフェクトの健全性: `· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, []⟩` からの実行は IO の事象を伴う遷移をしない。

初回リリース版の拡張でも、同じ三つの性質を確かめる。性質 3 は、「`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、`⟨M, [], ∅⟩` からの実行は IO の事象を伴う遷移をせず、どの `handle` の枠も処理しない操作を呼ばない」と読み替える。性質 2 の状態の型付けでは、継続の型付けに、継続の先頭で許すエフェクトと、継続の末尾で許すエフェクトを加え、組み込みでない操作の呼び出しには、それを処理する `handle` の枠が継続にあることを確かめる。初回リリース版の性質 2 は、「型が付いた状態は、`⟨return V, [], σ⟩`、`error(r̄, [], σ)`、`exit(n, r̄, [], σ)` のいずれかであるか、遷移できる。遷移した先の状態も型が付く」と読み替える。初回リリース版の状態の型付けは、この節の最後に示す。

性質 2 の「型が付いた状態」は、継続の型付けを使って次のように定める。`⊢k K : A ⇒ B` は、継続 K が型 A の値を受け取り、最後に型 B の値を結果とすることを表す。

```text
(K-Empty) ⊢k [] : A ⇒ A

(K-Let)   x:A ⊢c N : C ! ε     ⊢k K : C ⇒ B
          ─────────────────────────────────────
          ⊢k (let x ⇐ □ in N) :: K : A ⇒ B
```

状態 `⟨M, K⟩` に型が付くとは、`· ⊢c M : A ! ε` と `⊢k K : A ⇒ B` が成り立つ型 A、B とエフェクト ε があることである。

【方針】初回リリース版の状態の型付けでは、ストアの型付け Ψ（場所から型への対応）と、最も内側の関数の戻り値の型 R を加える。R は、型か、`escape` を許さないことを表す `none` である。値の判断に Ψ を加え、`Ψ(ℓ) = A` のとき `ℓ : A` とする（可変のセルと明示遅延の場所。継続の場所は値として型が付かず、C-ResumeL の第一引数にだけ書ける）。計算の判断は `Γ; R ⊢c M : A ! ε` とし、`R = none` のときは `escape` に型が付かない。継続の場所 κ には、Ψ が継続の型と R の組 `Ψ(κ) = (Cont(B → T ! ε), R_κ)` を対応させる。R_κ は、κ を作った節の R である。

継続の判断は `R; ε ⊢k K : A ⇒ B ! ε0` とする。K は型 A の値を受け取り、最後に型 B の値を結果とする。R は K の先頭で実行する計算に許す `escape` の型、ε は K の先頭で実行する計算に許すエフェクト、ε0 は K の末尾（空の継続）で許すエフェクトである。

```text
(C-Use)     Γ ⊢v V : O_r（O_r はリソースの型）     Γ; R ⊢c M : B ! ε     rel(O_r) ⊆ ε
            ─────────────────────────────────────────────
            Γ; R ⊢c use V in M : B ! ε

(C-ResumeL) Ψ(κ) = (Cont(B → T ! ε), R)     Γ ⊢v V : B
            ─────────────────────────────────────
            Γ; R ⊢c resume κ V : T ! ε

(K-Empty)   ε ⊆ ε0
            ─────────────────────────────
            R; ε ⊢k [] : A ⇒ A ! ε0

(K-Let)     x:A; R ⊢c N : C ! ε1     ε1 ⊆ ε     R; ε ⊢k K : C ⇒ B ! ε0
            ─────────────────────────────────────
            R; ε ⊢k (let x ⇐ □ in N) :: K : A ⇒ B ! ε0

(K-Mark)    R'; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────
            A; ε ⊢k mark :: K : A ⇒ B ! ε0

(K-Update)  Ψ(ℓ) = Lazy[A]     R; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────────────
            none; ε ⊢k (update ℓ □) :: K : A ⇒ B ! ε0

(K-Release) · ⊢v V : O_r（O_r はリソースの型）     rel(O_r) ⊆ ε     R; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────────────
            R; ε ⊢k (release V) :: K : A ⇒ B ! ε0

(K-Handle)  R; ε ⊢k K : T ⇒ B ! ε0     εc ⊆ ε
            H の各節 op(x̄) k ⇒ N について、op : ∀ᾱ. (Ā) → B' ! {L}、ᾱ はほかの何とも等しくない型として
              x̄:Ā, k:Cont(B' → T ! εc); R ⊢c N : T ! εc
            ─────────────────────────────────────
            R; εc ∪ handled(H) ⊢k (handle □ with H) :: K : T ⇒ B ! ε0

(K-Drop)    Ψ(κ) = (Cont(B' → A' ! ε'), R')     State ∈ ε' ならば State ∈ ε     R; ε ⊢k K : A ⇒ B ! ε0
            ─────────────────────────────────────
            R; ε ⊢k (drop κ) :: K : A ⇒ B ! ε0

(K-Sub)     R; ε ⊢k K : A' ⇒ B ! ε0     A ≤ A'
            ─────────────────────────────────────
            R; ε ⊢k K : A ⇒ B ! ε0
```

- C-Use の `rel(O_r)` は、リソースの型 O_r の解放のエフェクトであり、初回リリース版ではどのリソースの型でも `{State}` である。
- C-ResumeL は、節の変数 k を場所 κ に置き換えた後の `resume` の型付けである。`resume` の R は、κ を作った節の R と等しい。`resume` はラムダと `lazy` の本体の中に書けないので、節の中の `resume` はこの条件を満たす。
- K-Mark は、関数の本体の結果の型 A を、その本体の中の `escape` の型にする。 K-Sub は、継続が受け取る型を広げる。`handle` の式の型が、それを本体とする関数の戻り値の型より狭いとき、E-Resume の後の継続に型を付けるのに要る（[ADR 0301](../decisions/0301-subsumption-on-continuation-input.md)）。K-Update は、`thunk` の本体の実行の上に `escape` を許さない。
- K-Handle は、`handle` の枠の上で、H が処理するエフェクトを許す。節は、枠の下の継続と同じ R で、枠の下の継続が許すエフェクトに含まれるエフェクト εc で検査する。節の本体は枠の下の継続の中で実行されるので、εc が ε に含まれれば足りる。εc と ε を等しくしないのは、E-Resume で捕まえた継続を、より広いエフェクトを許す継続の上につなぐためである（[ADR 0302](../decisions/0302-k-handle-clause-effect-within-below.md)）。K-Drop の `drop` の枠は、受け取った値をそのまま渡すので、受け取る型 A は κ の答えの型と等しくなくてよい。E-Op が積んだ `drop` の枠では、A は κ の答えの型と等しいが、`releases(K')` で別の継続の先頭に移した `drop` の枠では、その継続を流れる値の型を受け取る。
- `drop κ` の枠が E-DropRel で加える `releases(K')` は、K' の中の `release` の枠と `drop` の枠である。解放のエフェクト `State` は、どの `handled(H)` にも含まれない。K-Handle の枠は、上で εc ∪ handled(H) を許し、εc ⊆ ε である。`State` は `handled(H)` に含まれないので、枠の上で `State` を許していれば εc も `State` を含み、枠の下の ε も `State` を含む。ほかの枠は、上と下で同じエフェクトを許す。したがって、ある枠が `State` を許していれば、その下のすべての枠も `State` を許している。K' の中の `release` の枠が `State` を許していれば、K' の末尾（κ の継続の型のエフェクト ε'）も `State` を許している。K-Drop の前提「State ∈ ε' ならば State ∈ ε」により、`drop` の枠の位置でも `State` を許しているので、`releases(K')` を `drop` の枠の位置に加えても型が付く。E-Op が積む `drop κ` の枠では、ε' は捕まえた `handle` の枠の節のエフェクト εc であり、`drop` の枠の位置で許すエフェクトは εc を含むので、この前提は成り立つ。前提がないと、この上下関係を持たないストアと `drop` の枠の組み合わせにも型が付き、保存が破れる（[ADR 0300](../decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）。
- ストア σ が Ψ のもとで型が付くとは、Ψ が型を与える場所に σ の中身があり（σ と Ψ の場所が一致する。[ADR 0300](../decisions/0300-continuations-second-class-drop-state-and-store-domain.md)）、σ のすべての場所について次が成り立つことである。σ(ℓ) = V なら `Ψ(ℓ) = Reference[A]` かつ `· ⊢v V : A`。σ(ℓ) = thunk(M) なら `Ψ(ℓ) = Lazy[A]` かつ `·; none ⊢c M : A ! { }`。σ(ℓ) = done(V) なら `Ψ(ℓ) = Lazy[A]` かつ `· ⊢v V : A`。σ(κ) = cont(K') なら `Ψ(κ) = (Cont(B → T ! ε), R_κ)` であり、K' の末尾の `handle` の枠に K-Handle を R_κ で使う導出で、ある R'、ε' について `R'; ε' ⊢k K' : B ⇒ T ! ε` が成り立つ。σ(κ) = used なら、Ψ(κ) は継続の型と R の組である。
- 状態 `⟨M, K, σ⟩` に型が付くとは、σ が Ψ のもとで型が付き、`·; R ⊢c M : A ! ε1`、`ε1 ⊆ ε`、`R; ε ⊢k K : A ⇒ B ! Eb` が成り立つ Ψ、R、A、B、ε、ε1 があることである。Eb は組み込みのエフェクトの名前の集合である。`error(r̄, K, σ)` と `exit(n, r̄, K, σ)` に型が付くとは、σ が Ψ のもとで型が付き、`R; ε ⊢k K : A ⇒ B ! Eb` が成り立つ Ψ、R、A、B、ε があることである。 いずれの状態の型付けでも、継続の判断は、末尾の K-Empty を `R = none` で使う導出で満たす。実行は `⟨main[;](), [], ∅⟩` から始まり、関数の本体の `escape` は関数の呼び出しが積んだ `mark` の枠で止まるので、実際に到達する状態はこの条件を満たす。この条件がないと、`⟨escape V, [], σ⟩` に型が付き、進行が成り立たない（[ADR 0299](../decisions/0299-state-continuation-ends-with-no-escape.md)）。
- 継続の末尾で許すエフェクトを Eb とするので、型が付いた状態で呼ぶ組み込みでない操作 op のエフェクト L は、継続のどこかの `handle` の枠が K-Handle で許している。その枠の H は、L のすべての操作の節を持つので、op の節を持つ。したがって、E-Op の条件を満たす `handle` の枠がある。
- 並行処理のタスク（[並行処理](01-11-concurrency.md)）と、タスクが引き継いだハンドラ（[ADR 0151](../decisions/0151-inherited-handlers-tail-resume-only.md)）は、本章の状態の型付けに含めない。

## 未決事項

なし。
