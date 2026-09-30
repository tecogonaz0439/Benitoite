# 依頼: 形式検証の段階 A の定義と定理の言明のレビュー

あなたはレビュー担当である。ファイルを書き換えず、最後の応答にレビューの結果だけを書くこと。

## 背景

関数型スクリプト言語 Benitoite の設計書の「コア計算と脱糖」（01-12）の規則を Lean 4 で書き写し、進行と保存・エフェクトの健全性を証明する（段階 2）。今回は段階 A（最小実行版の範囲）の定義と定理の言明だけを書いた。証明はまだ `sorry` である。`lake build` は通る。

方針（ADR 0295）: 01-12 を正とし、Lean の定義はその写しである。レビューの対象は次の三つで、証明の本体はレビューしない。

1. Lean の定義が 01-12 の規則と一致しているか（書き写しの誤り、規則の抜け、余計な制限や緩和）。
2. 定理の言明が 01-12 の性質と一致しているか（性質を弱めていないか、前提を増やしすぎていないか）。
3. 仮定（`Builtins.Assumptions` と定理の前提）が、下に示す 07-04 の表に挙げたものに限られ、妥当か。

加えて、次の点も見てほしい。

4. 言明した定理が、このままの定義で偽になる反例（証明できない理由）が見えるか。見えるなら、その原因が 01-12 の規則の誤りか、書き写しの誤りか、形式化の表現の都合かを分けて示す。
5. 表現の選び方（de Bruijn の番号、エフェクトの集合を `Atom → Bool` で表すこと、網羅性を意味で定めること、型付けを項と別の関係にすること）が、証明や段階 B（ストア、escape、with、ハンドラと一度だけ再開できる継続）の拡張で問題になりそうな点。

必要な資料はすべてこの依頼に含めた。リポジトリのファイルを読む必要はない。どうしても確かめたいことがあるときだけ、読む範囲を行で絞って読むこと。

## 出力の形

指摘ごとに次を書く。重要なものから並べる。問題がない観点は「問題なし」と一行で書く。

- 重さ: 高（定理が偽になる、または 01-12 と意味が違う）／中（証明や段階 B で問題になる）／低（表記・説明）
- 場所: ファイルと行（01-12 の場合は規則名）
- 問題
- 原因の分類: 01-12 の規則の誤り／書き写しの誤り／表現の都合／その他
- 直し方の案

回答は日本語で書く。

## 資料 1: 01-12「コア計算と脱糖」の段階 A の範囲（抜粋）

```markdown
## 仕様

### 本章の位置付け

【決定】最小実行版の表層のプログラムの意味は、本章の規則でコア計算へ脱糖し、抽象機械で実行した結果として定める（[ADR 0014](../decisions/0014-fine-grain-cbv-core.md)）。[評価意味論](01-08-evaluation.md)の記述と本章の規則が食い違うときは、本章を正とする。

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
(E-Prim)   ⟨b[T̄; Ē](W̄), K⟩                  →  ⟨return V, K⟩     δ(b, W̄) = V のとき
(E-Err)    ⟨b[T̄; Ē](W̄), K⟩                  →  error(r)          δ(b, W̄) = error(r) のとき
(E-IO)     ⟨b[T̄; Ē](W̄), K⟩  —b(W̄) ↦ V→      ⟨return V, K⟩
(E-IOErr)  ⟨b[T̄; Ē](W̄), K⟩  —b(W̄) ↦ error(r)→  error(r)
```

- E-Prim と E-Err は、IO を行わない組み込みの関数に使う。δ は、[基本型の意味論](01-04-types-basic.md)、[型システム](01-06-type-system.md)の「等値の型」（代数的データ型とリストの `=`）、[標準ライブラリ](../03-interop/03-06-stdlib.md)が定める関数の値、または実行時エラーの種類を返す。
- E-IO と E-IOErr は、IO を行う組み込みの関数（[エフェクト](01-07-effects.md)）に使う。応答 V または error(r) は、プログラムの外部の状態によって決まる。[エフェクト](01-07-effects.md)は、関数ごとに、応答として起こりうるものと、事象が外部の状態に与える変化を定める。例えば `File.readText` の応答は `Result.Ok(s)` か `Result.Error(e)` の値である。標準出力と標準エラー出力への書き込みの関数の応答は常に `()` とし、書き込みの失敗は抽象機械の規則ではなく[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」の例外として定める（[ADR 0045](../decisions/0045-late-detection-of-output-write-failure.md)）。したがって、最小実行版の IO を行う関数に、E-IOErr を使うものはない。初回リリース版では、解放したリソースの使用（後述の「解放の枠と実行時エラーの継続：`with`」）、応答の二度目の送信（`Http.respond`）、引数が定義域の外（`Process.exit` の終了状態など。[評価意味論](01-08-evaluation.md)の「実行時エラーによる停止」）に E-IOErr を使う。初回リリース版の後にサーバモードとあわせて加える権限の拒否（[エフェクト](01-07-effects.md)の「実行時の権限制御（サーバモード）」。[ADR 0177](../decisions/0177-server-mode-after-first-release.md)）にも、E-IOErr を使う。引数が定義域の外の誤りは引数だけで決まるが、外部に作用する操作を行う組み込みの関数では、ほかの応答と同じく E-IOErr で表す。
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


（中略）

### 確かめる性質

【方針】次の性質が成り立つように、本章と[型システム](01-06-type-system.md)を定める。どれも証明していない。形式検証の段階 1（[ロードマップ](../00-overview/00-03-roadmap.md)）で、ランダムに生成したプログラムを使って反例を探す。反例が見つかれば、仕様の誤りとして直す。性質 2 と性質 3 は、形式検証の段階 2 で、本章の規則を Lean 4 で書き写して証明する。書き写しは本章の写しであり、本章を正とする（[形式意味論と検証](../07-quality/07-04-formal-semantics.md)、[ADR 0293](../decisions/0293-formal-verification-stage-2-alongside-first-release.md)、[ADR 0295](../decisions/0295-core-calculus-chapter-normative-over-formalization.md)）。

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
```

## 資料 2: 07-04「形式意味論と検証」の仮定と対応表（抜粋）

```markdown
### 形式化で仮定するもの

【方針】01-12 は、組み込みの関数の型と値（関数 δ）と IO の応答を、ほかの章に委ねている。形式化では、これらの中身を定義せず、次の性質を定理の仮定として与える。Lean の `axiom` としては置かず、定理の引数（`formal/` の `Builtins.Assumptions`）として明示する。

| 仮定 | 内容 | 01-12 の根拠 |
|---|---|---|
| δ の型の保存 | 型 `(Ā) → B ! ε` の IO を行わない組み込みの関数 `b` に型 `Ā` の値を渡すと、δ は定義されていて、型 `B` の値か `error(r)` を返す | 「実行の規則」の E-Prim・E-Err |
| IO の応答の型 | 型 `(Ā) → B ! ε` の IO を行う組み込みの関数の応答は、型 `B` の値か `error(r)` である | 「確かめる性質」の性質 2 の「IO の応答は、関数の戻り値の型の値であるとする」 |
| IO の応答の存在 | IO を行う組み込みの関数には、起こりうる応答が少なくとも一つある | E-IO・E-IOErr で遷移できること（性質 2 の進行） |
| 組み込みの関数のエフェクト | IO を行う組み込みの関数の型のエフェクトは、組み込みのエフェクトの名前（最小実行版では `IO`）を含む | 性質 3 が IO の事象の不在を型から導くための前提 |
| 組み込みの関数の型の変数 | 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う | 01-12 は名前の束縛として暗黙に前提する |
| 制約の保存 | 型パラメータの制約（V-Prim の「T̄ が b の型パラメータの制約を満たす」）を満たす型は、型とエフェクトの置き換えの後も制約を満たす | E-Fun の置き換えの後も V-Prim が成り立つための前提 |

「組み込みの関数のエフェクト」は、01-12 に明文の規則がなく、[エフェクト](../01-spec/01-07-effects.md)が組み込みの関数ごとに与えるエフェクトから読み取れる性質である。「制約の保存」は、最小実行版では制約が演算子の型の集まりと等値の型に限られ、型パラメータが制約を満たさないので成り立つ。初回リリース版の組み込みの制約（`equality`・`key`）の扱いは [OPEN-070](../open-issues.md#open-070) で決める。

次の二つは、仮定ではなく定理の前提として言明する。

- プログラムの定義の集まり Σ に型が付くこと（すべての定義が 01-12 の「定義」の型付けを満たすこと）。
- 各定義の中の型パラメータとエフェクト変数が、その定義が宣言したものに限られること、構成子の引数の型の中の型パラメータが、代数的データ型が宣言したものに限られること。01-12 は名前の束縛として暗黙に前提するが、形式化では変数を番号で表すので、別に言明する。

### 01-12 との対応

【決定】01-12 を正とし、Lean の定義は 01-12 の規則の写しとする。食い違ったときは Lean の定義を 01-12 に合わせる。01-12 の規則の誤りと判断したときは、ADR を添えて 01-12 を直してから Lean の定義を合わせる（[ADR 0295](../decisions/0295-core-calculus-chapter-normative-over-formalization.md)）。

【決定】Lean の定義の名前は、01-12 の規則の名前に対応させる（規則 `E-Op` の遷移は構成子 `E_Op`、規則 `K-Handle` の継続の型付けは構成子 `K_Handle` とする）。01-12 の節と形式化の対応は、次の表で管理する。形式化のために 01-12 と違う形で書いた箇所は、「表現の違い」の欄にその内容と理由を記す。

| 01-12 の節 | 段 | 表現の違い |
|---|---|---|
| 構文 | 段階 A | 項の変数は de Bruijn の番号で表す（`λ(x1, …, xn). M` の本体では番号 0 が xn）。型パラメータとエフェクト変数は、宣言した関数の中での番号で表す。エフェクトの集合は、エフェクトの原子から真偽値への関数で表す（並びの違いを型の等しさに持ち込まないため）。定数は Lean の値で表し、`type(c)` を関数として定める。`IOError` の値は番号で区別する |
| 型付け規則（値、計算、パターン、定義） | 段階 A | Γ は型の並びで、先頭が番号 0 の変数の型である。P-Con の「変数はすべて異なる」は、変数を番号で表すので要らない。C-Match の網羅性は、01-05 の検査の手順ではなく「型 A のどの値にも照合する分岐がある」こととして定める（01-05 の検査がこれを満たすことは対象外）。組み込みの関数の型と制約は、前述の仮定の欄として与える |
| 実行の規則 | 段階 A | `S → S'` と `S —ℓ→ S'` を、IO の事象の有無をラベルに持つ一つの関係で表す。E-Prim・E-Err と E-IO・E-IOErr のどちらを使うかは、組み込みの関数ごとに IO を行うかの印で決める。遷移を計算する関数も定め、関係と一致することを定理として言明する |
| 末尾呼び出しの保証、置き換えてよい等式 | 対象外 | |
| 表層からの脱糖 | 対象外（性質 1） | |
| 初回リリース版の拡張: モジュール、トップレベルの定数、リストの展開、レコード、文字列補間 | 対象外（脱糖だけで表す） | |
| 初回リリース版の拡張: 基本型とコレクションの型、型クラス、ストア、関数の境界と `escape`、`with`、プロセスの終了、エフェクトの名前と開始状態、ハンドラ | 段階 B | 段階 B で記す |
| 初回リリース版の拡張: 末尾呼び出しの保証の読み替え | 対象外 | |
| 確かめる性質 | 性質 2・3 は段階 A・B。性質 1 は対象外 | |

段階 A の表現は、2026-09-30 に定義と定理の言明を書いた時点のものである。証明の作業で扱いにくいと分かれば改める（[OPEN-069](../open-issues.md#open-069)）。

```

## 資料 3: Lean のソース（`formal/Benitoite/Core/`、行番号つき）

### Syntax.lean

```lean
     1	/-!
     2	# コア計算の構文（段階 A）
     3	
     4	設計書 01-12「コア計算と脱糖」の「構文」を書き写す。段階 A は最小実行版の範囲だけを扱う
     5	（設計書 07-04「進め方」）。
     6	
     7	01-12 との表現の違い（設計書 07-04「01-12 との対応」の表に記す）:
     8	
     9	- 項の変数は de Bruijn の番号で表す。`λ(x1:A1, …, xn:An). M` は n 個の変数を一度に束縛し、
    10	  本体の中で番号 0 が `xn`、番号 n-1 が `x1` を指す。
    11	- 型パラメータ `α` とエフェクト変数 `ρ` は、それを宣言したトップレベルの関数の中での番号で表す。
    12	  局所の束縛とラムダは多相にならない（ADR 0009）ので、型の中に型の変数を束縛する構成はない。
    13	- エフェクトの集合は、エフェクトの原子から真偽値への関数で表す。集合の等しさを関数の等しさにして、
    14	  `{IO, ρ}` と `{ρ, IO}` のような並びの違いを型の等しさに持ち込まないためである。
    15	-/
    16	
    17	namespace Benitoite.Core
    18	
    19	/-- エフェクトの原子。01-12 の `e ::= IO | ρ`。`rho i` は、関数の宣言の i 番目のエフェクト変数。 -/
    20	inductive Atom where
    21	  | io
    22	  | rho (i : Nat)
    23	  deriving DecidableEq, Repr
    24	
    25	/-- エフェクトの集合。01-12 の `ε ::= { e1, …, en }`。 -/
    26	def Eff := Atom → Bool
    27	
    28	namespace Eff
    29	
    30	/-- 空集合 `{ }`。 -/
    31	def empty : Eff := fun _ => false
    32	
    33	/-- `{ IO }`。 -/
    34	def io : Eff := fun a => a == .io
    35	
    36	/-- 包含 `ε ⊆ ε'`。 -/
    37	def Sub (ε ε' : Eff) : Prop := ∀ a, ε a = true → ε' a = true
    38	
    39	/-- 和集合 `ε ∪ ε'`。 -/
    40	def union (ε ε' : Eff) : Eff := fun a => ε a || ε' a
    41	
    42	/-- エフェクト変数の置き換え `ε[Ē/ρ̄]`（01-12「構文」）。
    43	番号が `es` の長さより小さい `rho i` を `es[i]` に置き換え、ほかの原子はそのまま残す。 -/
    44	def substRho (es : List Eff) (ε : Eff) : Eff := fun a =>
    45	  let kept := match a with
    46	    | .io => ε .io
    47	    | .rho i => if i < es.length then false else ε (.rho i)
    48	  kept || (List.range es.length).any (fun i =>
    49	    ε (.rho i) && match es[i]? with
    50	      | some e => e a
    51	      | none => false)
    52	
    53	end Eff
    54	
    55	/-- 基本型。01-12 の `ι`。 -/
    56	inductive BaseTy where
    57	  | integer | float | string | character | boolean | unit
    58	  deriving DecidableEq, Repr
    59	
    60	/-- 中身を見せない prelude の型。01-12 の `O`（段階 A では `IOError` だけ）。 -/
    61	inductive OpaqueTy where
    62	  | ioError
    63	  deriving DecidableEq, Repr
    64	
    65	/-- 代数的データ型の名前 `D`、構成子の名前 `C`、トップレベルの関数の名前 `f`、
    66	組み込みの関数の名前 `b`。 -/
    67	abbrev DataName := String
    68	abbrev ConName := String
    69	abbrev FunName := String
    70	abbrev PrimName := String
    71	
    72	/-- 型。01-12 の `A, B ::= ι | O | D[Ā] | List[A] | (Ā) → B ! ε | α`。
    73	`tvar i` は、関数の宣言の i 番目の型パラメータ。 -/
    74	inductive Ty where
    75	  | base (ι : BaseTy)
    76	  | opaque (o : OpaqueTy)
    77	  | data (d : DataName) (args : List Ty)
    78	  | list (a : Ty)
    79	  | fn (params : List Ty) (ret : Ty) (eff : Eff)
    80	  | tvar (i : Nat)
    81	
    82	/-- 定数。01-12 の `c`（`Integer`・`Float`・`String`・`Character` の値、`true`、`false`、`()`、
    83	IO の関数が返す `IOError` の値）。`IOError` の値の中身は扱わないので、番号で区別する。 -/
    84	inductive Const where
    85	  | integer (n : Int)
    86	  | float (x : Float)
    87	  | string (s : String)
    88	  | character (c : Char)
    89	  | boolean (b : Bool)
    90	  | unit
    91	  | ioError (id : Nat)
    92	
    93	/-- 定数の型 `type(c)`（01-12「型付け規則」の V-Const）。 -/
    94	def Const.type : Const → Ty
    95	  | .integer _ => .base .integer
    96	  | .float _ => .base .float
    97	  | .string _ => .base .string
    98	  | .character _ => .base .character
    99	  | .boolean _ => .base .boolean
   100	  | .unit => .base .unit
   101	  | .ioError _ => .opaque .ioError
   102	
   103	/-- パターンの定数の照合に使う、定数どうしの等しさ。P-Const は `Float` と `IOError` の定数を
   104	パターンに許さないので、その二つは等しいと判定しない。 -/
   105	def Const.matches : Const → Const → Bool
   106	  | .integer a, .integer b => a == b
   107	  | .string a, .string b => a == b
   108	  | .character a, .character b => a == b
   109	  | .boolean a, .boolean b => a == b
   110	  | .unit, .unit => true
   111	  | _, _ => false
   112	
   113	/-- パターン。01-12 の `p ::= _ | x | c | C(p̄)`。変数のパターンが束縛する変数は、
   114	左から順に番号を振る（`Pat.binders`）。 -/
   115	inductive Pat where
   116	  | wild
   117	  | var
   118	  | const (c : Const)
   119	  | con (c : ConName) (args : List Pat)
   120	
   121	mutual
   122	  /-- 値。01-12 の `V, W`。 -/
   123	  inductive Val where
   124	    | var (i : Nat)
   125	    | const (c : Const)
   126	    /-- `f[T̄; Ē]` -/
   127	    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff)
   128	    /-- `b[T̄; Ē]` -/
   129	    | prim (b : PrimName) (tys : List Ty) (effs : List Eff)
   130	    /-- `λ(x1:A1, …, xn:An). M` -/
   131	    | lam (params : List Ty) (body : Comp)
   132	    /-- `C[T̄](V̄)` -/
   133	    | con (c : ConName) (tys : List Ty) (args : List Val)
   134	    /-- `[V1, …, Vn]` -/
   135	    | list (elems : List Val)
   136	
   137	  /-- 計算。01-12 の `M, N`。 -/
   138	  inductive Comp where
   139	    | ret (v : Val)
   140	    /-- `let x ⇐ M in N`。N の中で番号 0 が x を指す。 -/
   141	    | letIn (m : Comp) (n : Comp)
   142	    | app (f : Val) (args : List Val)
   143	    | ite (v : Val) (m n : Comp)
   144	    /-- `match V { p1 ⇒ M1 | … }`。各分岐の本体の中で、パターンが束縛した変数は、
   145	    最後に束縛した変数を番号 0 とする。 -/
   146	    | «match» (v : Val) (arms : List (Pat × Comp))
   147	end
   148	
   149	/-- トップレベルの関数の定義。01-12 の `fn f[ᾱ; ρ̄](x1:A1, …, xn:An) : B ! ε = M`。
   150	`ntys` と `neffs` は ᾱ と ρ̄ の個数である。 -/
   151	structure Def where
   152	  ntys : Nat
   153	  neffs : Nat
   154	  params : List Ty
   155	  ret : Ty
   156	  eff : Eff
   157	  body : Comp
   158	
   159	/-- 代数的データ型の構成子の宣言。構成子 `C` は `D[ᾱ]` の構成子で、引数の型は `C̄` である。
   160	`args` の中の `tvar i` は `D` の i 番目の型パラメータを指す。 -/
   161	structure ConDecl where
   162	  data : DataName
   163	  ntys : Nat
   164	  args : List Ty
   165	
   166	/-- プログラム。01-12 の定義の集まり Σ と、型の宣言の集まり。 -/
   167	structure Program where
   168	  defs : FunName → Option Def
   169	  cons : ConName → Option ConDecl
   170	
   171	end Benitoite.Core
```

### Subst.lean

```lean
     1	import Benitoite.Core.Syntax
     2	
     3	/-!
     4	# 置き換えとパターンの照合（段階 A）
     5	
     6	設計書 01-12 の `Mθ`（型とエフェクトの置き換え）、`M[V/x]`（値の置き換え）、
     7	`match(p, V)`（パターンの照合）を定める。
     8	
     9	項の変数は de Bruijn の番号で表す（`Syntax.lean` の冒頭）。値の置き換えは、番号から値への関数
    10	（並列の置き換え）で定める。01-12 の `M[W̄/x̄]` は `Comp.instantiate` に当たる。
    11	-/
    12	
    13	namespace Benitoite.Core
    14	
    15	/-! ## 型とエフェクトの置き換え `θ = [T̄/ᾱ, Ē/ρ̄]` -/
    16	
    17	/-- 型の置き換え。番号が `ts` の長さより小さい `tvar i` を `ts[i]` に置き換え、
    18	関数の型のエフェクトに `Eff.substRho es` を適用する。 -/
    19	def Ty.subst (ts : List Ty) (es : List Eff) : Ty → Ty
    20	  | .base ι => .base ι
    21	  | .opaque o => .opaque o
    22	  | .data d args => .data d (args.map (Ty.subst ts es))
    23	  | .list a => .list (Ty.subst ts es a)
    24	  | .fn params ret eff => .fn (params.map (Ty.subst ts es)) (Ty.subst ts es ret) (Eff.substRho es eff)
    25	  | .tvar i => (ts[i]?).getD (.tvar i)
    26	
    27	mutual
    28	  /-- 値の中の型とエフェクトに θ を適用する。 -/
    29	  def Val.substTy (ts : List Ty) (es : List Eff) : Val → Val
    30	    | .var i => .var i
    31	    | .const c => .const c
    32	    | .fnRef f tys effs => .fnRef f (tys.map (Ty.subst ts es)) (effs.map (Eff.substRho es))
    33	    | .prim b tys effs => .prim b (tys.map (Ty.subst ts es)) (effs.map (Eff.substRho es))
    34	    | .lam params body => .lam (params.map (Ty.subst ts es)) (Comp.substTy ts es body)
    35	    | .con c tys args => .con c (tys.map (Ty.subst ts es)) (Val.substTyList ts es args)
    36	    | .list elems => .list (Val.substTyList ts es elems)
    37	
    38	  def Val.substTyList (ts : List Ty) (es : List Eff) : List Val → List Val
    39	    | [] => []
    40	    | v :: vs => Val.substTy ts es v :: Val.substTyList ts es vs
    41	
    42	  /-- 計算の中の型とエフェクトに θ を適用する（01-12 の `Mθ`）。 -/
    43	  def Comp.substTy (ts : List Ty) (es : List Eff) : Comp → Comp
    44	    | .ret v => .ret (Val.substTy ts es v)
    45	    | .letIn m n => .letIn (Comp.substTy ts es m) (Comp.substTy ts es n)
    46	    | .app f args => .app (Val.substTy ts es f) (Val.substTyList ts es args)
    47	    | .ite v m n => .ite (Val.substTy ts es v) (Comp.substTy ts es m) (Comp.substTy ts es n)
    48	    | .match v arms => .match (Val.substTy ts es v) (Comp.substTyArms ts es arms)
    49	
    50	  def Comp.substTyArms (ts : List Ty) (es : List Eff) : List (Pat × Comp) → List (Pat × Comp)
    51	    | [] => []
    52	    | (p, m) :: arms => (p, Comp.substTy ts es m) :: Comp.substTyArms ts es arms
    53	end
    54	
    55	/-! ## 値の置き換え -/
    56	
    57	mutual
    58	  /-- パターンが束縛する変数の個数。 -/
    59	  def Pat.binders : Pat → Nat
    60	    | .wild => 0
    61	    | .var => 1
    62	    | .const _ => 0
    63	    | .con _ args => Pat.bindersList args
    64	
    65	  def Pat.bindersList : List Pat → Nat
    66	    | [] => 0
    67	    | p :: ps => Pat.binders p + Pat.bindersList ps
    68	end
    69	
    70	/-- k 個の変数を束縛する位置の内側へ、番号の付け替えを持ち上げる。 -/
    71	def upRen (k : Nat) (ξ : Nat → Nat) (i : Nat) : Nat :=
    72	  if i < k then i else ξ (i - k) + k
    73	
    74	mutual
    75	  /-- 値の自由な変数の番号を付け替える。 -/
    76	  def Val.rename (ξ : Nat → Nat) : Val → Val
    77	    | .var i => .var (ξ i)
    78	    | .const c => .const c
    79	    | .fnRef f tys effs => .fnRef f tys effs
    80	    | .prim b tys effs => .prim b tys effs
    81	    | .lam params body => .lam params (Comp.rename (upRen params.length ξ) body)
    82	    | .con c tys args => .con c tys (Val.renameList ξ args)
    83	    | .list elems => .list (Val.renameList ξ elems)
    84	
    85	  def Val.renameList (ξ : Nat → Nat) : List Val → List Val
    86	    | [] => []
    87	    | v :: vs => Val.rename ξ v :: Val.renameList ξ vs
    88	
    89	  def Comp.rename (ξ : Nat → Nat) : Comp → Comp
    90	    | .ret v => .ret (Val.rename ξ v)
    91	    | .letIn m n => .letIn (Comp.rename ξ m) (Comp.rename (upRen 1 ξ) n)
    92	    | .app f args => .app (Val.rename ξ f) (Val.renameList ξ args)
    93	    | .ite v m n => .ite (Val.rename ξ v) (Comp.rename ξ m) (Comp.rename ξ n)
    94	    | .match v arms => .match (Val.rename ξ v) (Comp.renameArms ξ arms)
    95	
    96	  def Comp.renameArms (ξ : Nat → Nat) : List (Pat × Comp) → List (Pat × Comp)
    97	    | [] => []
    98	    | (p, m) :: arms => (p, Comp.rename (upRen p.binders ξ) m) :: Comp.renameArms ξ arms
    99	end
   100	
   101	/-- k 個の変数を束縛する位置の内側へ、置き換えを持ち上げる。 -/
   102	def upSubst (k : Nat) (σ : Nat → Val) (i : Nat) : Val :=
   103	  if i < k then .var i else (σ (i - k)).rename (· + k)
   104	
   105	mutual
   106	  /-- 値の自由な変数を、番号ごとに値へ置き換える（並列の置き換え）。 -/
   107	  def Val.subst (σ : Nat → Val) : Val → Val
   108	    | .var i => σ i
   109	    | .const c => .const c
   110	    | .fnRef f tys effs => .fnRef f tys effs
   111	    | .prim b tys effs => .prim b tys effs
   112	    | .lam params body => .lam params (Comp.subst (upSubst params.length σ) body)
   113	    | .con c tys args => .con c tys (Val.substList σ args)
   114	    | .list elems => .list (Val.substList σ elems)
   115	
   116	  def Val.substList (σ : Nat → Val) : List Val → List Val
   117	    | [] => []
   118	    | v :: vs => Val.subst σ v :: Val.substList σ vs
   119	
   120	  def Comp.subst (σ : Nat → Val) : Comp → Comp
   121	    | .ret v => .ret (Val.subst σ v)
   122	    | .letIn m n => .letIn (Comp.subst σ m) (Comp.subst (upSubst 1 σ) n)
   123	    | .app f args => .app (Val.subst σ f) (Val.substList σ args)
   124	    | .ite v m n => .ite (Val.subst σ v) (Comp.subst σ m) (Comp.subst σ n)
   125	    | .match v arms => .match (Val.subst σ v) (Comp.substArms σ arms)
   126	
   127	  def Comp.substArms (σ : Nat → Val) : List (Pat × Comp) → List (Pat × Comp)
   128	    | [] => []
   129	    | (p, m) :: arms => (p, Comp.subst (upSubst p.binders σ) m) :: Comp.substArms σ arms
   130	end
   131	
   132	/-- 最も内側の n 個の変数を値の並び `ws`（束縛した順）で置き換え、残りの番号を n だけ詰める。
   133	01-12 の `M[W̄/x̄]` に当たる。束縛した順の最後の値が番号 0 に当たる。 -/
   134	def instSubst (ws : List Val) (i : Nat) : Val :=
   135	  if i < ws.length then (ws.reverse[i]?).getD (.var i) else .var (i - ws.length)
   136	
   137	def Comp.instantiate (ws : List Val) (m : Comp) : Comp :=
   138	  Comp.subst (instSubst ws) m
   139	
   140	/-! ## パターンの照合 `match(p, V)` -/
   141	
   142	mutual
   143	  /-- `match(p, V)`。照合したら、束縛する変数の値を左から順に並べて返す。 -/
   144	  def Pat.matchVal : Pat → Val → Option (List Val)
   145	    | .wild, _ => some []
   146	    | .var, v => some [v]
   147	    | .const c, .const c' => if c.matches c' then some [] else none
   148	    | .con c ps, .con c' _ args =>
   149	        if c = c' then Pat.matchList ps args else none
   150	    | _, _ => none
   151	
   152	  def Pat.matchList : List Pat → List Val → Option (List Val)
   153	    | [], [] => some []
   154	    | p :: ps, v :: vs => do
   155	        let a ← Pat.matchVal p v
   156	        let b ← Pat.matchList ps vs
   157	        pure (a ++ b)
   158	    | _, _ => none
   159	end
   160	
   161	/-- E-Match が選ぶ分岐。照合する最初の分岐の本体と、束縛する値の並びを返す。 -/
   162	def firstMatch (v : Val) : List (Pat × Comp) → Option (Comp × List Val)
   163	  | [] => none
   164	  | (p, m) :: arms =>
   165	      match Pat.matchVal p v with
   166	      | some ws => some (m, ws)
   167	      | none => firstMatch v arms
   168	
   169	end Benitoite.Core
```

### Typing.lean

```lean
     1	import Benitoite.Core.Subst
     2	
     3	/-!
     4	# 型付け規則（段階 A）
     5	
     6	設計書 01-12「型付け規則」（値、計算、パターン、定義）を書き写す。
     7	
     8	01-12 との表現の違い:
     9	
    10	- 型の環境 Γ は型の並びで、先頭が番号 0 の変数の型である。`Γ, x1:A1, …, xn:An` は
    11	  `params.reverse ++ Γ` に当たる。
    12	- P-Con の「Δ1, …, Δn の変数はすべて異なる」は、変数を番号で表すので要らない。
    13	- C-Match の「A について網羅的である」は、01-05 の検査の手順ではなく、
    14	  「型 A のどの値にも、照合する分岐がある」こととして定める（`Exhaustive`）。
    15	  01-05 の検査がこの性質を満たすことは、段階 2 の対象にしない（型推論と同じ扱い）。
    16	- 組み込みの関数の型と制約は、01-12 が他の章に委ねているので、`Builtins` の欄として与える。
    17	-/
    18	
    19	namespace Benitoite.Core
    20	
    21	/-! ## 組み込みの関数 -/
    22	
    23	/-- 実行時エラーの種類 `r`。01-12 は種類の中身を定めないので、名前で表す。 -/
    24	abbrev ErrKind := String
    25	
    26	/-- 組み込みの関数の結果。01-12 の δ の値と IO の応答は、値 V か `error(r)` である。 -/
    27	inductive Outcome where
    28	  | val (v : Val)
    29	  | err (r : ErrKind)
    30	
    31	/-- 組み込みの関数 `b` の型 `∀ᾱ ρ̄. (Ā) → B ! ε` と、型パラメータの制約、IO を行うか。 -/
    32	structure PrimSig where
    33	  ntys : Nat
    34	  neffs : Nat
    35	  params : List Ty
    36	  ret : Ty
    37	  eff : Eff
    38	  /-- 型パラメータの制約（01-12 の V-Prim の「T̄ が b の型パラメータの制約を満たす」）。 -/
    39	  admits : List Ty → Prop
    40	  /-- IO を行う組み込みの関数か（E-IO・E-IOErr を使うか、E-Prim・E-Err を使うか）。 -/
    41	  io : Bool
    42	
    43	/-- 組み込みの関数の型と値。01-12 は、これらを 01-04・01-06・01-07・03-06 に委ねている。
    44	形式化では中身を定めず、`Builtins.Assumptions`（`Assumptions.lean`）の性質だけを仮定する。 -/
    45	structure Builtins where
    46	  sig : PrimName → Option PrimSig
    47	  /-- IO を行わない組み込みの関数の値 δ(b, W̄)。 -/
    48	  delta : PrimName → List Val → Option Outcome
    49	  /-- IO を行う組み込みの関数の応答として起こりうるもの。 -/
    50	  ioResponse : PrimName → List Val → Outcome → Prop
    51	
    52	/-- 関数の型の、型とエフェクトの置き換えの後の形。V-Fun と V-Prim の `((Ā) → B ! ε)θ`。 -/
    53	def fnTy (params : List Ty) (ret : Ty) (eff : Eff) (ts : List Ty) (es : List Eff) : Ty :=
    54	  Ty.subst ts es (.fn params ret eff)
    55	
    56	/-! ## 型の包含 `A ≤ A'` -/
    57	
    58	/-- `A ≤ A'`（01-12「値」の後の【決定】）。A と A' が等しいか、最も外側の関数の型のエフェクトだけが
    59	包含の関係にある。 -/
    60	def Ty.Le (a a' : Ty) : Prop :=
    61	  a = a' ∨ ∃ ps r ε ε', a = .fn ps r ε ∧ a' = .fn ps r ε' ∧ Eff.Sub ε ε'
    62	
    63	/-! ## パターン -/
    64	
    65	mutual
    66	  /-- `⊢p p : A ⊣ Δ`。Δ は束縛する変数の型を左から順に並べたもの。 -/
    67	  inductive PatTy (P : Program) : Pat → Ty → List Ty → Prop
    68	    | wild {a} : PatTy P .wild a []
    69	    | var {a} : PatTy P .var a [a]
    70	    | const {c} :
    71	        (∀ x, c ≠ .float x) → (∀ n, c ≠ .ioError n) →
    72	        PatTy P (.const c) c.type []
    73	    | con {c ps cd ts δ} :
    74	        P.cons c = some cd → ts.length = cd.ntys →
    75	        PatTys P ps (cd.args.map (Ty.subst ts [])) δ →
    76	        PatTy P (.con c ps) (.data cd.data ts) δ
    77	
    78	  inductive PatTys (P : Program) : List Pat → List Ty → List Ty → Prop
    79	    | nil : PatTys P [] [] []
    80	    | cons {p ps a as δ δs} :
    81	        PatTy P p a δ → PatTys P ps as δs → PatTys P (p :: ps) (a :: as) (δ ++ δs)
    82	end
    83	
    84	/-! ## 網羅性 -/
    85	
    86	mutual
    87	  /-- `Inhabits P A V`: 値 V が、網羅性を考えるうえで型 A の値の形をしている。
    88	  型の付いた閉じた値は、その型について `Inhabits` を満たす（証明する補題）。
    89	  関数の型と型パラメータについては、パターンが値の中を調べないので、どの値でもよいとする。 -/
    90	  inductive Inhabits (P : Program) : Ty → Val → Prop
    91	    | const {c} : Inhabits P c.type (.const c)
    92	    | con {c ts tys' args cd} :
    93	        P.cons c = some cd → cd.ntys = ts.length →
    94	        InhabitsAll P (cd.args.map (Ty.subst ts [])) args →
    95	        Inhabits P (.data cd.data ts) (.con c tys' args)
    96	    | list {a elems} : InhabitsEach P a elems → Inhabits P (.list a) (.list elems)
    97	    | fn {ps r ε v} : Inhabits P (.fn ps r ε) v
    98	    | tvar {i v} : Inhabits P (.tvar i) v
    99	
   100	  inductive InhabitsAll (P : Program) : List Ty → List Val → Prop
   101	    | nil : InhabitsAll P [] []
   102	    | cons {a as v vs} : Inhabits P a v → InhabitsAll P as vs → InhabitsAll P (a :: as) (v :: vs)
   103	
   104	  inductive InhabitsEach (P : Program) : Ty → List Val → Prop
   105	    | nil {a} : InhabitsEach P a []
   106	    | cons {a v vs} : Inhabits P a v → InhabitsEach P a vs → InhabitsEach P a (v :: vs)
   107	end
   108	
   109	/-- C-Match の「p1, …, pn は A について網羅的である」。 -/
   110	def Exhaustive (P : Program) (a : Ty) (ps : List Pat) : Prop :=
   111	  ∀ v, Inhabits P a v → ∃ p ∈ ps, (Pat.matchVal p v).isSome
   112	
   113	/-! ## 値と計算の型付け -/
   114	
   115	mutual
   116	  /-- `Γ ⊢v V : A`。 -/
   117	  inductive HasTypeV (P : Program) (B : Builtins) : List Ty → Val → Ty → Prop
   118	    | var {Γ i a} : Γ[i]? = some a → HasTypeV P B Γ (.var i) a
   119	    | const {Γ c} : HasTypeV P B Γ (.const c) c.type
   120	    | fnRef {Γ f d ts es} :
   121	        P.defs f = some d → ts.length = d.ntys → es.length = d.neffs →
   122	        HasTypeV P B Γ (.fnRef f ts es) (fnTy d.params d.ret d.eff ts es)
   123	    | prim {Γ b s ts es} :
   124	        B.sig b = some s → ts.length = s.ntys → es.length = s.neffs → s.admits ts →
   125	        HasTypeV P B Γ (.prim b ts es) (fnTy s.params s.ret s.eff ts es)
   126	    | lam {Γ ps body r ε} :
   127	        HasTypeC P B (ps.reverse ++ Γ) body r ε →
   128	        HasTypeV P B Γ (.lam ps body) (.fn ps r ε)
   129	    | con {Γ c ts args cd} :
   130	        P.cons c = some cd → ts.length = cd.ntys →
   131	        HasTypeVs P B Γ args (cd.args.map (Ty.subst ts [])) →
   132	        HasTypeV P B Γ (.con c ts args) (.data cd.data ts)
   133	    | list {Γ elems a} :
   134	        HasTypeEach P B Γ elems a → HasTypeV P B Γ (.list elems) (.list a)
   135	    | sub {Γ v a a'} :
   136	        HasTypeV P B Γ v a → Ty.Le a a' → HasTypeV P B Γ v a'
   137	
   138	  /-- 値の並びと型の並びの、要素ごとの型付け（C-App・V-Con の「各 i」）。 -/
   139	  inductive HasTypeVs (P : Program) (B : Builtins) : List Ty → List Val → List Ty → Prop
   140	    | nil {Γ} : HasTypeVs P B Γ [] []
   141	    | cons {Γ v vs a as} :
   142	        HasTypeV P B Γ v a → HasTypeVs P B Γ vs as → HasTypeVs P B Γ (v :: vs) (a :: as)
   143	
   144	  /-- 値の並びのすべてが同じ型を持つ（V-List の「各 i」）。 -/
   145	  inductive HasTypeEach (P : Program) (B : Builtins) : List Ty → List Val → Ty → Prop
   146	    | nil {Γ a} : HasTypeEach P B Γ [] a
   147	    | cons {Γ v vs a} :
   148	        HasTypeV P B Γ v a → HasTypeEach P B Γ vs a → HasTypeEach P B Γ (v :: vs) a
   149	
   150	  /-- `Γ ⊢c M : A ! ε`。 -/
   151	  inductive HasTypeC (P : Program) (B : Builtins) : List Ty → Comp → Ty → Eff → Prop
   152	    | ret {Γ v a} : HasTypeV P B Γ v a → HasTypeC P B Γ (.ret v) a Eff.empty
   153	    | sub {Γ m a a' ε ε'} :
   154	        HasTypeC P B Γ m a ε → Ty.Le a a' → Eff.Sub ε ε' → HasTypeC P B Γ m a' ε'
   155	    | letIn {Γ m n a b ε} :
   156	        HasTypeC P B Γ m a ε → HasTypeC P B (a :: Γ) n b ε →
   157	        HasTypeC P B Γ (.letIn m n) b ε
   158	    | app {Γ f args as b ε} :
   159	        HasTypeV P B Γ f (.fn as b ε) → HasTypeVs P B Γ args as →
   160	        HasTypeC P B Γ (.app f args) b ε
   161	    | ite {Γ v m n a ε} :
   162	        HasTypeV P B Γ v (.base .boolean) → HasTypeC P B Γ m a ε → HasTypeC P B Γ n a ε →
   163	        HasTypeC P B Γ (.ite v m n) a ε
   164	    | «match» {Γ v arms a b ε} :
   165	        HasTypeV P B Γ v a → HasTypeArms P B Γ arms a b ε →
   166	        Exhaustive P a (arms.map Prod.fst) →
   167	        HasTypeC P B Γ (.match v arms) b ε
   168	
   169	  /-- C-Match の各分岐 `⊢p pi : A ⊣ Δi` と `Γ, Δi ⊢c Mi : B ! ε`。 -/
   170	  inductive HasTypeArms (P : Program) (B : Builtins) : List Ty → List (Pat × Comp) → Ty → Ty → Eff → Prop
   171	    | nil {Γ a b ε} : HasTypeArms P B Γ [] a b ε
   172	    | cons {Γ p m arms a b ε δ} :
   173	        PatTy P p a δ → HasTypeC P B (δ.reverse ++ Γ) m b ε →
   174	        HasTypeArms P B Γ arms a b ε →
   175	        HasTypeArms P B Γ ((p, m) :: arms) a b ε
   176	end
   177	
   178	/-! ## 定義とプログラム -/
   179	
   180	/-- 定義に型が付く（01-12「定義」）。`x1:A1, …, xn:An ⊢c M : B ! ε`。 -/
   181	def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
   182	  HasTypeC P B d.params.reverse d.body d.ret d.eff
   183	
   184	/-- プログラムのすべての定義に型が付く。 -/
   185	def Program.WellTyped (P : Program) (B : Builtins) : Prop :=
   186	  ∀ f d, P.defs f = some d → d.WellTyped P B
   187	
   188	end Benitoite.Core
```

### Semantics.lean

```lean
     1	import Benitoite.Core.Typing
     2	
     3	/-!
     4	# 実行の規則（段階 A）
     5	
     6	設計書 01-12「実行の規則」の抽象機械を書き写す。遷移を関係 `Step` で定め、
     7	同じ遷移を計算する関数 `step` も定める（設計書 07-04「道具と置き場所」）。`step` は、
     8	小さなコア計算のプログラムを Lean の中で実行して、書き写しの誤りを証明の前に見つけるために使う。
     9	
    10	01-12 との表現の違い:
    11	
    12	- 遷移 `S → S'` と `S —ℓ→ S'` を、ラベル `Option Event` を持つ一つの関係で表す。
    13	  `none` が IO を伴わない遷移、`some ℓ` が IO の事象 ℓ を伴う遷移である。
    14	- E-Prim と E-Err は IO を行わない組み込みの関数に、E-IO と E-IOErr は IO を行う組み込みの関数に
    15	  使う。どちらに当たるかは `PrimSig.io` で決める。
    16	-/
    17	
    18	namespace Benitoite.Core
    19	
    20	/-- IO の事象 `b(W̄) ↦ V` または `b(W̄) ↦ error(r)`。 -/
    21	structure Event where
    22	  prim : PrimName
    23	  args : List Val
    24	  outcome : Outcome
    25	
    26	/-- 継続の枠。01-12 の `F ::= let x ⇐ □ in N`。N の中で番号 0 が x を指す。 -/
    27	inductive Frame where
    28	  | letF (n : Comp)
    29	
    30	/-- 継続。01-12 の `K ::= [] | F :: K`。 -/
    31	abbrev Cont := List Frame
    32	
    33	/-- 状態。01-12 の `S ::= ⟨M, K⟩ | error(r)`。 -/
    34	inductive State where
    35	  | run (m : Comp) (k : Cont)
    36	  | error (r : ErrKind)
    37	
    38	/-- 遷移。01-12「実行の規則」の E-Let から E-IOErr まで。構成子の名前は規則の名前に対応させる。 -/
    39	inductive Step (P : Program) (B : Builtins) : State → Option Event → State → Prop
    40	  | E_Let {m n k} :
    41	      Step P B (.run (.letIn m n) k) none (.run m (.letF n :: k))
    42	  | E_Return {v n k} :
    43	      Step P B (.run (.ret v) (.letF n :: k)) none (.run (n.instantiate [v]) k)
    44	  | E_Lam {ps body ws k} :
    45	      Step P B (.run (.app (.lam ps body) ws) k) none (.run (body.instantiate ws) k)
    46	  | E_Fun {f ts es ws k d} :
    47	      P.defs f = some d →
    48	      Step P B (.run (.app (.fnRef f ts es) ws) k) none
    49	        (.run ((d.body.substTy ts es).instantiate ws) k)
    50	  | E_IfT {m n k} :
    51	      Step P B (.run (.ite (.const (.boolean true)) m n) k) none (.run m k)
    52	  | E_IfF {m n k} :
    53	      Step P B (.run (.ite (.const (.boolean false)) m n) k) none (.run n k)
    54	  | E_Match {v arms k m ws} :
    55	      firstMatch v arms = some (m, ws) →
    56	      Step P B (.run (.match v arms) k) none (.run (m.instantiate ws) k)
    57	  | E_Prim {b ts es ws k s v} :
    58	      B.sig b = some s → s.io = false → B.delta b ws = some (.val v) →
    59	      Step P B (.run (.app (.prim b ts es) ws) k) none (.run (.ret v) k)
    60	  | E_Err {b ts es ws k s r} :
    61	      B.sig b = some s → s.io = false → B.delta b ws = some (.err r) →
    62	      Step P B (.run (.app (.prim b ts es) ws) k) none (.error r)
    63	  | E_IO {b ts es ws k s v} :
    64	      B.sig b = some s → s.io = true → B.ioResponse b ws (.val v) →
    65	      Step P B (.run (.app (.prim b ts es) ws) k) (some ⟨b, ws, .val v⟩) (.run (.ret v) k)
    66	  | E_IOErr {b ts es ws k s r} :
    67	      B.sig b = some s → s.io = true → B.ioResponse b ws (.err r) →
    68	      Step P B (.run (.app (.prim b ts es) ws) k) (some ⟨b, ws, .err r⟩) (.error r)
    69	
    70	/-- 遷移を 0 回以上続けたもの。ラベルは問わない。 -/
    71	inductive Steps (P : Program) (B : Builtins) : State → State → Prop
    72	  | refl {s} : Steps P B s s
    73	  | step {s l s' s''} : Step P B s l s' → Steps P B s' s'' → Steps P B s s''
    74	
    75	/-- 一歩の遷移を計算する関数。IO の応答は `oracle` から得る。遷移できないときは `none` を返す。
    76	`step_sound`（`Theorems.lean`）で `Step` と一致することを示す。 -/
    77	def step (P : Program) (B : Builtins) (oracle : PrimName → List Val → Outcome) :
    78	    State → Option (Option Event × State)
    79	  | .error _ => none
    80	  | .run (.letIn m n) k => some (none, .run m (.letF n :: k))
    81	  | .run (.ret v) (.letF n :: k) => some (none, .run (n.instantiate [v]) k)
    82	  | .run (.ret _) [] => none
    83	  | .run (.app (.lam _ body) ws) k => some (none, .run (body.instantiate ws) k)
    84	  | .run (.app (.fnRef f ts es) ws) k =>
    85	      match P.defs f with
    86	      | some d => some (none, .run ((d.body.substTy ts es).instantiate ws) k)
    87	      | none => none
    88	  | .run (.app (.prim b _ _) ws) k =>
    89	      match B.sig b with
    90	      | none => none
    91	      | some s =>
    92	          if s.io then
    93	            match oracle b ws with
    94	            | .val v => some (some ⟨b, ws, .val v⟩, .run (.ret v) k)
    95	            | .err r => some (some ⟨b, ws, .err r⟩, .error r)
    96	          else
    97	            match B.delta b ws with
    98	            | some (.val v) => some (none, .run (.ret v) k)
    99	            | some (.err r) => some (none, .error r)
   100	            | none => none
   101	  | .run (.app _ _) _ => none
   102	  | .run (.ite (.const (.boolean true)) m _) k => some (none, .run m k)
   103	  | .run (.ite (.const (.boolean false)) _ n) k => some (none, .run n k)
   104	  | .run (.ite _ _ _) _ => none
   105	  | .run (.match v arms) k =>
   106	      match firstMatch v arms with
   107	      | some (m, ws) => some (none, .run (m.instantiate ws) k)
   108	      | none => none
   109	
   110	/-- `step` を n 回まで続ける。値で終わるか、実行時エラーで止まるか、遷移できなくなるか、
   111	n 回に達したら止める。IO の事象の列も返す。 -/
   112	def run (P : Program) (B : Builtins) (oracle : PrimName → List Val → Outcome) :
   113	    Nat → State → List Event → State × List Event
   114	  | 0, s, evs => (s, evs.reverse)
   115	  | n + 1, s, evs =>
   116	      match step P B oracle s with
   117	      | none => (s, evs.reverse)
   118	      | some (none, s') => run P B oracle n s' evs
   119	      | some (some ev, s') => run P B oracle n s' (ev :: evs)
   120	
   121	/-! ## 継続と状態の型付け -/
   122	
   123	/-- `⊢k K : A ⇒ B`（01-12「確かめる性質」の K-Empty・K-Let）。 -/
   124	inductive ContTy (P : Program) (B : Builtins) : Cont → Ty → Ty → Prop
   125	  | K_Empty {a} : ContTy P B [] a a
   126	  | K_Let {n k a c b ε} :
   127	      HasTypeC P B [a] n c ε → ContTy P B k c b →
   128	      ContTy P B (.letF n :: k) a b
   129	
   130	/-- 状態 `⟨M, K⟩` に型が付く。`· ⊢c M : A ! ε` と `⊢k K : A ⇒ B` が成り立つ A、B、ε がある。 -/
   131	def StateTy (P : Program) (B : Builtins) : State → Prop
   132	  | .run m k => ∃ a b ε, HasTypeC P B [] m a ε ∧ ContTy P B k a b
   133	  | .error _ => False
   134	
   135	end Benitoite.Core
```

### WellFormed.lean

```lean
     1	import Benitoite.Core.Typing
     2	
     3	/-!
     4	# 型とエフェクトの変数の範囲（段階 A）
     5	
     6	01-12 は、型パラメータ ᾱ とエフェクト変数 ρ̄ を名前で書き、関数の宣言 `fn f[ᾱ; ρ̄]` が束縛する。
     7	形式化では番号で表す（`Syntax.lean`）ので、定義の中の番号が、その定義が宣言した個数より小さいこと
     8	（名前で書けば、宣言していない名前を使っていないこと）を別に言明する。01-12 では、この条件は
     9	名前の束縛として暗黙に成り立っている。
    10	
    11	同じ述語で、01-12 の性質 3 の「M がエフェクト変数を含まない」も表す。
    12	-/
    13	
    14	namespace Benitoite.Core
    15	
    16	/-- エフェクトの集合の中のエフェクト変数の番号が、すべて `pe` を満たす。 -/
    17	def Eff.RhosIn (pe : Nat → Prop) (ε : Eff) : Prop :=
    18	  ∀ i, ε (.rho i) = true → pe i
    19	
    20	mutual
    21	  /-- 型の中の型パラメータの番号が `pt` を、エフェクト変数の番号が `pe` を満たす。 -/
    22	  def Ty.VarsIn (pt pe : Nat → Prop) : Ty → Prop
    23	    | .base _ => True
    24	    | .opaque _ => True
    25	    | .data _ args => Ty.VarsInList pt pe args
    26	    | .list a => Ty.VarsIn pt pe a
    27	    | .fn params ret eff => Ty.VarsInList pt pe params ∧ Ty.VarsIn pt pe ret ∧ Eff.RhosIn pe eff
    28	    | .tvar i => pt i
    29	
    30	  def Ty.VarsInList (pt pe : Nat → Prop) : List Ty → Prop
    31	    | [] => True
    32	    | a :: as => Ty.VarsIn pt pe a ∧ Ty.VarsInList pt pe as
    33	end
    34	
    35	def Eff.RhosInList (pe : Nat → Prop) : List Eff → Prop
    36	  | [] => True
    37	  | e :: es => Eff.RhosIn pe e ∧ Eff.RhosInList pe es
    38	
    39	mutual
    40	  /-- 値の中に現れる型とエフェクトの変数の番号が、`pt` と `pe` を満たす。 -/
    41	  def Val.VarsIn (pt pe : Nat → Prop) : Val → Prop
    42	    | .var _ => True
    43	    | .const _ => True
    44	    | .fnRef _ tys effs => Ty.VarsInList pt pe tys ∧ Eff.RhosInList pe effs
    45	    | .prim _ tys effs => Ty.VarsInList pt pe tys ∧ Eff.RhosInList pe effs
    46	    | .lam params body => Ty.VarsInList pt pe params ∧ Comp.VarsIn pt pe body
    47	    | .con _ tys args => Ty.VarsInList pt pe tys ∧ Val.VarsInList pt pe args
    48	    | .list elems => Val.VarsInList pt pe elems
    49	
    50	  def Val.VarsInList (pt pe : Nat → Prop) : List Val → Prop
    51	    | [] => True
    52	    | v :: vs => Val.VarsIn pt pe v ∧ Val.VarsInList pt pe vs
    53	
    54	  def Comp.VarsIn (pt pe : Nat → Prop) : Comp → Prop
    55	    | .ret v => Val.VarsIn pt pe v
    56	    | .letIn m n => Comp.VarsIn pt pe m ∧ Comp.VarsIn pt pe n
    57	    | .app f args => Val.VarsIn pt pe f ∧ Val.VarsInList pt pe args
    58	    | .ite v m n => Val.VarsIn pt pe v ∧ Comp.VarsIn pt pe m ∧ Comp.VarsIn pt pe n
    59	    | .match v arms => Val.VarsIn pt pe v ∧ Comp.VarsInArms pt pe arms
    60	
    61	  def Comp.VarsInArms (pt pe : Nat → Prop) : List (Pat × Comp) → Prop
    62	    | [] => True
    63	    | (_, m) :: arms => Comp.VarsIn pt pe m ∧ Comp.VarsInArms pt pe arms
    64	end
    65	
    66	/-- 定義の中の型パラメータとエフェクト変数が、その定義が宣言したものに限られる。 -/
    67	def Def.Scoped (d : Def) : Prop :=
    68	  let pt := (· < d.ntys)
    69	  let pe := (· < d.neffs)
    70	  Ty.VarsInList pt pe d.params ∧ Ty.VarsIn pt pe d.ret ∧ Eff.RhosIn pe d.eff ∧
    71	    Comp.VarsIn pt pe d.body
    72	
    73	/-- 構成子の引数の型の中の型パラメータが、代数的データ型が宣言したものに限られ、
    74	エフェクト変数を含まない。 -/
    75	def ConDecl.Scoped (cd : ConDecl) : Prop :=
    76	  Ty.VarsInList (· < cd.ntys) (fun _ => False) cd.args
    77	
    78	/-- 組み込みの関数の型の中の型パラメータとエフェクト変数が、宣言したものに限られる。 -/
    79	def PrimSig.Scoped (s : PrimSig) : Prop :=
    80	  let pt := (· < s.ntys)
    81	  let pe := (· < s.neffs)
    82	  Ty.VarsInList pt pe s.params ∧ Ty.VarsIn pt pe s.ret ∧ Eff.RhosIn pe s.eff
    83	
    84	/-- プログラムのすべての定義と構成子の宣言が、宣言した変数だけを使う。 -/
    85	def Program.WellFormed (P : Program) : Prop :=
    86	  (∀ f d, P.defs f = some d → d.Scoped) ∧ (∀ c cd, P.cons c = some cd → cd.Scoped)
    87	
    88	/-- 01-12 の性質 3 の「M がエフェクト変数を含まない」。 -/
    89	def Comp.NoEffVars (m : Comp) : Prop :=
    90	  Comp.VarsIn (fun _ => True) (fun _ => False) m
    91	
    92	end Benitoite.Core
```

### Assumptions.lean

```lean
     1	import Benitoite.Core.WellFormed
     2	
     3	/-!
     4	# 形式化で仮定するもの（段階 A）
     5	
     6	設計書 07-04「形式化で仮定するもの」の表を書き写す。01-12 は、組み込みの関数の値（δ）と
     7	IO の応答を他の章に委ねている。形式化では中身を定めず、ここに挙げる性質だけを仮定する。
     8	仮定は `axiom` としては置かず、定理の引数（`Builtins.Assumptions`）として明示する。
     9	-/
    10	
    11	namespace Benitoite.Core
    12	
    13	/-- 組み込みの関数の結果が型 A を持つ。`error(r)` はどの型についても許す。 -/
    14	def OutcomeTy (P : Program) (B : Builtins) : Outcome → Ty → Prop
    15	  | .val v, a => HasTypeV P B [] v a
    16	  | .err _, _ => True
    17	
    18	/-- 組み込みの関数について仮定する性質。 -/
    19	structure Builtins.Assumptions (P : Program) (B : Builtins) : Prop where
    20	  /-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数だけを使う。 -/
    21	  sig_scoped : ∀ b s, B.sig b = some s → s.Scoped
    22	  /-- 型パラメータの制約は、型とエフェクトの置き換えで保たれる。関数の定義の中で制約を満たした
    23	  型は、その関数を呼ぶときの置き換えの後も制約を満たす。 -/
    24	  admits_subst : ∀ b s ts ts' es', B.sig b = some s → s.admits ts →
    25	    s.admits (ts.map (Ty.subst ts' es'))
    26	  /-- δ の型の保存。型 `(Ā) → B ! ε` の IO を行わない組み込みの関数に型 `Ā` の値を渡すと、
    27	  δ は型 `B` の値か `error(r)` を返す（01-12 の E-Prim・E-Err が必ずどちらかに当たる）。 -/
    28	  delta_typed : ∀ b s ts es ws, B.sig b = some s → s.io = false →
    29	    ts.length = s.ntys → es.length = s.neffs → s.admits ts →
    30	    HasTypeVs P B [] ws (s.params.map (Ty.subst ts es)) →
    31	    ∃ o, B.delta b ws = some o ∧ OutcomeTy P B o (Ty.subst ts es s.ret)
    32	  /-- IO の応答の型。型 `(Ā) → B ! ε` の IO を行う組み込みの関数の応答は、型 `B` の値か
    33	  `error(r)` である（01-12 の性質 2 の「IO の応答は、関数の戻り値の型の値であるとする」）。 -/
    34	  io_typed : ∀ b s ts es ws o, B.sig b = some s → s.io = true →
    35	    ts.length = s.ntys → es.length = s.neffs → s.admits ts →
    36	    HasTypeVs P B [] ws (s.params.map (Ty.subst ts es)) →
    37	    B.ioResponse b ws o → OutcomeTy P B o (Ty.subst ts es s.ret)
    38	  /-- IO を行う組み込みの関数には、起こりうる応答が少なくとも一つある（E-IO か E-IOErr で
    39	  遷移できる）。 -/
    40	  io_exists : ∀ b s ws, B.sig b = some s → s.io = true → ∃ o, B.ioResponse b ws o
    41	  /-- IO を行う組み込みの関数の型のエフェクトは、`IO` を含む。 -/
    42	  io_effect : ∀ b s, B.sig b = some s → s.io = true → s.eff .io = true
    43	
    44	end Benitoite.Core
```

### Theorems.lean

```lean
     1	import Benitoite.Core.Semantics
     2	import Benitoite.Core.Assumptions
     3	
     4	/-!
     5	# 段階 A の定理
     6	
     7	設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性）の、
     8	最小実行版の形を言明する。あわせて、遷移を計算する関数 `step` が関係 `Step` と一致することを言明する。
     9	
    10	証明はまだ書いていない（`sorry`）。段階 A は、この節のすべての定理から `sorry` を除いたときに完了する
    11	（設計書 07-04「進め方」）。
    12	-/
    13	
    14	namespace Benitoite.Core
    15	
    16	variable {P : Program} {B : Builtins}
    17	
    18	/-! ## `step` と `Step` の一致 -/
    19	
    20	/-- `step` が返す遷移は `Step` の遷移である。IO の応答は、起こりうる応答の中から `oracle` が選ぶ。 -/
    21	theorem step_sound (oracle : PrimName → List Val → Outcome)
    22	    (horacle : ∀ b ws, B.ioResponse b ws (oracle b ws))
    23	    {s : State} {l : Option Event} {s' : State} :
    24	    step P B oracle s = some (l, s') → Step P B s l s' := by
    25	  sorry
    26	
    27	/-- `Step` の遷移は、その IO の応答を返す `oracle` のもとで `step` が返す。 -/
    28	theorem step_complete (oracle : PrimName → List Val → Outcome)
    29	    {s : State} {l : Option Event} {s' : State}
    30	    (horacle : ∀ ev, l = some ev → oracle ev.prim ev.args = ev.outcome) :
    31	    Step P B s l s' → step P B oracle s = some (l, s') := by
    32	  sorry
    33	
    34	/-! ## 性質 2: 進行と保存 -/
    35	
    36	/-- 進行。型が付いた状態 `⟨M, K⟩` は、`⟨return V, []⟩` であるか、遷移できる。 -/
    37	theorem progress (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P)
    38	    {m : Comp} {k : Cont} :
    39	    StateTy P B (.run m k) →
    40	    (∃ v, m = .ret v ∧ k = []) ∨ ∃ l s', Step P B (.run m k) l s' := by
    41	  sorry
    42	
    43	/-- 保存。型が付いた状態から遷移した先の状態も型が付くか、`error(r)` である。
    44	IO の応答は、`Builtins.Assumptions.io_typed` により関数の戻り値の型の値である。 -/
    45	theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P)
    46	    {m : Comp} {k : Cont} {l : Option Event} {s' : State} :
    47	    StateTy P B (.run m k) → Step P B (.run m k) l s' →
    48	    StateTy P B s' ∨ ∃ r, s' = .error r := by
    49	  sorry
    50	
    51	/-! ## 性質 3: エフェクトの健全性 -/
    52	
    53	/-- エフェクトの健全性。`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、
    54	`⟨M, []⟩` からの実行は IO の事象を伴う遷移をしない。 -/
    55	theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P)
    56	    {m : Comp} {a : Ty} :
    57	    HasTypeC P B [] m a Eff.empty → m.NoEffVars →
    58	    ∀ s ev s', Steps P B (.run m []) s → Step P B s (some ev) s' → False := by
    59	  sorry
    60	
    61	end Benitoite.Core
```

### Examples.lean

```lean
     1	import Benitoite.Core.Semantics
     2	
     3	/-!
     4	# 抽象機械の実行の例（段階 A）
     5	
     6	小さなコア計算のプログラムを `run` で実行し、01-12 の規則から期待する結果と比べる。
     7	書き写しの誤りを証明の前に見つけるためのものであり、定理ではない（設計書 07-04「道具と置き場所」）。
     8	期待と食い違うと `decide` が失敗し、`lake build` が止まる。
     9	-/
    10	
    11	namespace Benitoite.Core.Examples
    12	
    13	open Benitoite.Core
    14	
    15	/-! ## 例で使う組み込みの関数とプログラム -/
    16	
    17	def intTy : Ty := .base .integer
    18	def unitTy : Ty := .base .unit
    19	
    20	/-- 例の組み込みの関数。`add` と `divide` は IO を行わず、`print` は IO を行う。 -/
    21	def builtins : Builtins where
    22	  sig
    23	    | "add" => some { ntys := 0, neffs := 0, params := [intTy, intTy], ret := intTy,
    24	                      eff := Eff.empty, admits := fun _ => True, io := false }
    25	    | "divide" => some { ntys := 0, neffs := 0, params := [intTy, intTy], ret := intTy,
    26	                         eff := Eff.empty, admits := fun _ => True, io := false }
    27	    | "print" => some { ntys := 0, neffs := 0, params := [intTy], ret := unitTy,
    28	                        eff := Eff.io, admits := fun _ => True, io := true }
    29	    | _ => none
    30	  delta
    31	    | "add", [.const (.integer a), .const (.integer b)] => some (.val (.const (.integer (a + b))))
    32	    | "divide", [.const (.integer _), .const (.integer 0)] => some (.err "DivisionByZero")
    33	    | "divide", [.const (.integer a), .const (.integer b)] =>
    34	        some (.val (.const (.integer (a.tdiv b))))
    35	    | _, _ => none
    36	  ioResponse
    37	    | "print", [_], o => o = .val (.const .unit)
    38	    | _, _, _ => False
    39	
    40	/-- `print` の応答として常に `()` を返す。 -/
    41	def oracle : PrimName → List Val → Outcome := fun _ _ => .val (.const .unit)
    42	
    43	def int (n : Int) : Val := .const (.integer n)
    44	
    45	/-- 例のプログラム。
    46	
    47	- `double(x: Integer) : Integer ! {} = add(x, x)`
    48	- `apply[α, β; ρ](f: (α) → β ! {ρ}, x: α) : β ! {ρ} = f(x)`
    49	- `data Option[α] = None | Some(α)` -/
    50	def program : Program where
    51	  defs
    52	    | "double" => some { ntys := 0, neffs := 0, params := [intTy], ret := intTy,
    53	                         eff := Eff.empty,
    54	                         body := .app (.prim "add" [] []) [.var 0, .var 0] }
    55	    | "apply" => some { ntys := 2, neffs := 1,
    56	                        params := [.fn [.tvar 0] (.tvar 1) (fun a => a == .rho 0), .tvar 0],
    57	                        ret := .tvar 1, eff := fun a => a == .rho 0,
    58	                        -- 番号 0 が x、番号 1 が f
    59	                        body := .app (.var 1) [.var 0] }
    60	    | _ => none
    61	  cons
    62	    | "None" => some { data := "Option", ntys := 1, args := [] }
    63	    | "Some" => some { data := "Option", ntys := 1, args := [.tvar 0] }
    64	    | _ => none
    65	
    66	/-- 実行の結果を、例で比べやすい形にしたもの。 -/
    67	inductive Result where
    68	  | returned (n : Int)
    69	  | returnedUnit
    70	  | error (r : String)
    71	  | other
    72	  deriving DecidableEq, Repr
    73	
    74	def summarize : State × List Event → Result × Nat
    75	  | (s, evs) =>
    76	    let r := match s with
    77	      | .run (.ret (.const (.integer n))) [] => .returned n
    78	      | .run (.ret (.const .unit)) [] => .returnedUnit
    79	      | .error r => .error r
    80	      | _ => .other
    81	    (r, evs.length)
    82	
    83	def exec (m : Comp) : Result × Nat :=
    84	  summarize (run program builtins oracle 1000 (.run m []) [])
    85	
    86	/-! ## 例 -/
    87	
    88	/-- `let y ⇐ double(21) in return y` は 42 を返し、IO の事象を伴わない（E-Let、E-Fun、E-Prim、
    89	E-Return）。 -/
    90	example : exec (.letIn (.app (.fnRef "double" [] []) [int 21]) (.ret (.var 0))) =
    91	    (.returned 42, 0) := by decide
    92	
    93	/-- `(λ(x: Integer, y: Integer). divide(x, y))(7, 2)` は 3 を返す。引数の並びと番号の対応
    94	（番号 0 が最後の引数 y）を確かめる。 -/
    95	example : exec (.app (.lam [intTy, intTy] (.app (.prim "divide" [] []) [.var 1, .var 0]))
    96	    [int 7, int 2]) = (.returned 3, 0) := by decide
    97	
    98	/-- 0 での除算は `error(r)` で止まり、継続を捨てる（E-Err）。 -/
    99	example : exec (.letIn (.app (.prim "divide" [] []) [int 1, int 0]) (.ret (int 5))) =
   100	    (.error "DivisionByZero", 0) := by decide
   101	
   102	/-- `match Some[Integer](5) { None ⇒ return 0 | Some(x) ⇒ return add(x, 1) }` は、
   103	照合する最初の分岐を選び、6 を返す（E-Match）。 -/
   104	example : exec (.match (.con "Some" [intTy] [int 5])
   105	    [(.con "None" [], .ret (int 0)),
   106	     (.con "Some" [.var], .app (.prim "add" [] []) [.var 0, int 1])]) = (.returned 6, 0) := by
   107	  decide
   108	
   109	/-- `apply[Integer, Unit; {IO}](print, 3)` は IO の事象を一つ伴い、`()` を返す（E-Fun の型と
   110	エフェクトの置き換え、E-IO）。 -/
   111	example : exec (.app (.fnRef "apply" [intTy, unitTy] [Eff.io]) [.prim "print" [] [], int 3]) =
   112	    (.returnedUnit, 1) := by decide
   113	
   114	/-- `if true then return 1 else return 2` は 1 を返す（E-IfT）。 -/
   115	example : exec (.ite (.const (.boolean true)) (.ret (int 1)) (.ret (int 2))) =
   116	    (.returned 1, 0) := by decide
   117	
   118	end Benitoite.Core.Examples
```
