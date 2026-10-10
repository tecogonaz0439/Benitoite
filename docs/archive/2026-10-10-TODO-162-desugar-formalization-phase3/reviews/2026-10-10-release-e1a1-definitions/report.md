## 1. 変えたファイルと行数

E1a-1 の実装を完了した。変更は次の二つだけであり、コミットはしていない。

| ファイル | 変更 |
|---|---|
| [formal/Benitoite/Release/Coverage.lean](../../../../../formal/Benitoite/Release/Coverage.lean) | 新規追加、605 行。手順、定理の言明、評価例を含む |
| [formal/Benitoite.lean](../../../../../formal/Benitoite.lean) | 1 行追加。`Release.Model` の直後に `Release.Coverage` を import |

検査の結果は次のとおりである。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功 |
| `formal/` で `lake build desugarDiff` | 成功 |
| 評価例 25 個 | すべて `decide` で成功。例の証明に `sorry` はない |
| 既存の定理の公理の検査 | Core の 5 定理、Release の 4 定理、Surface の 2 定理すべてが、指定の標準公理の範囲内 |
| `git diff --check` と新規ファイルの末尾空白の検査 | 問題なし |

`sorry` は、四つの健全性の定理と型置換の補助定理の計五箇所に限られる。既存の 11 定理には `sorryAx` が現れなかった。公理と再帰の展開を調べる一時ファイルは `formal/` 内に作り、最後に削除した。

## 2. 定義の要約

型ごとの構成子は、次のように定義した。

| 型 | 構成子 |
|---|---|
| `.data d ts` | `ctors d` の順に列挙する。宣言の所属と型引数の数が合えば、引数の型を置換する。合わない名前は値のない `invalidCon` とする |
| `Boolean` | `true`、`false` |
| `Unit` | `()` |
| `Integer`、`Character` | 列の区間の `lo` と `hi + 1` を整列し、隣接する端から区間を作る。そのうち列のいずれかのパターンが覆う区間と、残りの値 `other` を使う |
| `String` | 列の文字列を出現順に重複除去したものと、`other` |
| `List a` | 長さ `k < m` の `exact` と、長さ `m` 以上の `long` |
| その他の型 | `other` だけ |

区間端・文字列・リストの長さの計算には、問いの先頭も含める。`Character` の端は `Int` のまま保持し、サロゲートだけからなる区間を除く。列の区間の間にある覆われない値も `other` に含める。

リストの境界は、残りのないパターンの最大長に 1 を加えた値と、残りのあるパターンの前後の最大長の和から求める。残りのないパターンがなければ前者を 0 とする。`.list before none after` は `before ++ after` の固定長として扱う。

各段では、問いと型の並びの長さに合わない行を除いてから判定する。`.var` と `.wild` は同じに扱う。定数と範囲は列の型と種類が合うものだけを特殊化し、`Float` の等しさは使っていない。不整合な行は除き、不整合な問いは有用と答える。

ガードの扱いは Q3 に従う。位置 `(i, j)` の判定に使う行は、前のガードのない分岐の選択肢と、同じ分岐の前の選択肢である。同じ分岐の選択肢は、ガードがあっても数える。網羅性には `unguardedPats arms` を使う。

停止は燃料による構造的な再帰で示した。燃料は次の式で決める。

```text
N × (A + 1) + max tys.length q.length + 1
```

`N` は行列と問いにあるワイルドカードでない節の数、`A` は入力に現れる構成子の宣言の引数数と、リストの前後の要素数の総和である。最大引数数を求める代わりに、大きめの値を使っている。燃料の十分性は主張していない。尽きたら有用と答え、`fuelExhausted` を記録する。燃料切れを意図した例を除き、通常の判定例ではこの印が偽になることも検査した。

新しく追加した再帰関数は、Lean の展開結果でも `Nat.brecOn`、`List.brecOn`、構文の `brecOn` による構造的な再帰になっている。`partial def`、`termination_by`、`native_decide` は使っていない。

主要な関数の型は次のとおりである。

```text
Coverage.usefulFuel :
  Program → (DataName → List ConName) →
  Nat → List Ty → List (List Pat) → List Pat → UsefulnessResult

usefulReport :
  Program → (DataName → List ConName) →
  List Ty → List (List Pat) → List Pat → UsefulnessResult

useful :
  Program → (DataName → List ConName) →
  List Ty → List (List Pat) → List Pat → Option (List CoverageWitness)

checkMatch :
  Program → (DataName → List ConName) → Ty → List Arm → MatchCoverage

irrefutable :
  Program → (DataName → List ConName) → Ty → Pat → Bool
```

`CoverageWitness` は、ワイルドカード、残りの値、構成子、値のない構成子、真偽値、Unit、区間、文字列、固定長・長いリストを区別する。`MatchCoverage` は、網羅していない場合の反例 `uncovered`、選ばれない位置の並び `unreachable`、燃料切れの印を返す。

実装中に、既存の `Ty.substAt` が整礎再帰で定義され、構成子の引数の型を `decide` で評価する際に止まることを確認した。このため、構造的な相互再帰による `Coverage.substTy` と `Coverage.substTys` を追加した。既存の `Ty.subst ts []` との一致は、下記の補助定理として言明している。

## 3. 定理の言明と、足した前提とその理由

構成子の一覧の条件と、選択の定義は次のとおりである。

```lean
def CtorsComplete (P : Program) (ctors : DataName → List ConName) : Prop :=
  ∀ c cd, P.cons c = some cd → c ∈ ctors cd.data

def AlternativeSelected (arms : List Arm) (i j : Nat) (v : Val) : Prop :=
  ∃ arm alt, arms[i]? = some arm ∧ arm.alts[j]? = some alt ∧
    (∀ p ∈ unguardedPats (arms.take i), ¬ (Pat.matchVal p v).isSome) ∧
    (∀ prior ∈ arm.alts.take j, ¬ (Pat.matchVal prior.pat v).isSome) ∧
    (Pat.matchVal alt.pat v).isSome
```

補題 U と系の言明は、ファイルに書いたとおり次の形である。

```lean
theorem useful_none_sound (P : Program) (ctors : DataName → List ConName)
    (tys : List Ty) (rows : List (List Pat)) (q : List Pat)
    (hc : CtorsComplete P ctors) (h : useful P ctors tys rows q = none) :
    ∀ vs, InhabitsAll P tys vs → (Pat.matchList q vs).isSome →
      ∃ row ∈ rows, (Pat.matchList row vs).isSome := by
  sorry

theorem checkMatch_exhaustive_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (hc : CtorsComplete P ctors)
    (h : (checkMatch P ctors a arms).exhaustive = true) :
    Exhaustive P a (unguardedPats arms) := by
  sorry

theorem irrefutable_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (p : Pat) (hc : CtorsComplete P ctors)
    (h : irrefutable P ctors a p = true) : Exhaustive P a [p] := by
  sorry

theorem checkMatch_unreachable_sound (P : Program) (ctors : DataName → List ConName)
    (a : Ty) (arms : List Arm) (i j : Nat) (hc : CtorsComplete P ctors)
    (h : (i, j) ∈ (checkMatch P ctors a arms).unreachable) :
    ∀ v, Inhabits P a v → ¬ AlternativeSelected arms i j v := by
  sorry
```

評価用の型置換を既存の型置換に接続する補助定理は、名前空間 `Coverage` 内に置いた。

```lean
theorem substTy_eq (ts : List Ty) (a : Ty) : substTy ts a = Ty.subst ts [] a := by
  sorry
```

指定された健全性の定理に、追加の前提は足していない。パターンの型付け、行列の長さの整合、slots の整合、燃料の十分性は前提にしていない。

系 2 は、指定どおりパターンの照合による選択について述べている。`firstAlt` と実行の規則による選択を直接扱う言明より弱い。実行の規則との接続には、照合後の `selectSlots` が失敗しないことを保証する slots の整合の前提が必要である。

## 4. 例の一覧

25 個の評価例を置き、すべて `decide` で確かめた。表の形の例では複数の入力をまとめて検査している。

| 分類 | 確かめた内容 |
|---|---|
| ワイルドカード | `case _` の後の `case 0` が選ばれない |
| Boolean | 分岐なし、`true` だけ、`true` と `false`。`true` だけの反例が `false` |
| List の網羅性 | `[]` だけでは網羅しない。`[]` と `[_, ..]` で網羅する |
| 同じ分岐の選択肢 | ガードなし・ありの双方で、`1, 1` の二番目が選ばれない |
| 前の分岐のガード | ガード付き `case 1` の後のガードなし `case 1` は選ばれる |
| Character | サロゲートの前後の二範囲が、後の連続した範囲を覆う。全値域の範囲だけでも網羅とは答えない |
| Integer の隙間 | `0` と `2` の行に対する `0..2` の問いから、`1` の区間を反例にする |
| String | 重複した文字列が選ばれない。新しい文字列の問いは有用 |
| データ型 | 型引数を持つ二構成子の型を入れ子にした網羅性と、`L(R(false))` の反例 |
| 必ず照合するパターン | Unit、残りだけのリスト、空リストだけの束縛 |
| 固定長リスト | `rest = none` の `after` を要素として扱い、長さ 1 の重複を検出する |
| 長いリスト | 前後の要素を独立して特殊化し、`false` と `true` を前後に持つ反例を返す |
| 行の長さ | 長さの違う全ワイルドカード行を、問いを覆う行として数えない |
| 定数の種類 | Integer と Character の区別、異種の範囲端、Boolean・Unit・String・Float・Byte・Decimal・opaque の不一致 |
| Q4 の不整合 | 型の列が尽きた場合、構成子の引数数・型引数数・所属が違う場合、型パラメータの非ワイルドカードの問い |
| 構成子の一覧 | 余分な名前を値のない構成子として扱う |
| 空のデータ型 | 空の行列で止める保守的な判定 |
| 燃料切れ | 有用と答え、燃料切れの印を残す |
| slots | 不整合な slots があっても、パターンの照合による覆いを判定する。`firstAlt` の失敗も別に確認する |

例の `Program` と `ctors` が `CtorsComplete` を満たすことは、`CoverageExamples.ctors_complete` として `sorry` なしで証明した。反例の比較には、`DecidableEq` を持つ平たい `Tag` の並びへの要約を使っている。

## 5. 処理系の手順と違う点のうち、Q3・Q4 以外で気付いたもの

- **Integer の値域が違う。** 処理系のリテラルは `i64`、区間端は `i128` である。Lean は上限のない `Int` を使うため、端の加減算に飽和演算を必要としない。
- **Lean 版には燃料の上限がある。** 処理系の `usefulness` は燃料を持たない。Lean 版は燃料切れで有用側に倒れるため、燃料が足りない入力では判定が食い違いうる。`usefulReport` と `checkMatch` でその件数を数えられる。
- **反例の表現が違う。** 処理系は文字列を返し、区間や文字列の構成子を `_` と表示する。Lean 版は区間端や文字列を保持する専用の型を返す。表示の規則を適用する処理は、指定どおり E1c に残している。
- **行列の作り方の実装が違う。** 処理系は行を逐次追加する。Lean 版の `checkMatch` は、各位置について `precedingPats` から行列を作り直す。規則と行の順を定義から読み取れる形を優先したため、選択肢が多い場合には行列を組み立てる手間が増える。

## 6. 後半で難しそうな点

- **区間の分割の補題。** 挿入整列と重複除去で作った端から、問いに照合する値を含む区間を選べることを示す必要がある。列のどの区間にも入らない値を `other` に対応させる場合と、Character のサロゲートを除く場合も含む。
- **長いリストの特殊化。** 実際の長さが `m` 以上のリストから前後の要素を取り出し、特殊化したパターンの照合と元の `Pat.matchVal` の照合を接続する必要がある。`rest = none` の `after` も含めて扱う。
- **評価用の型置換との接続。** `Coverage.substTy_eq` では、深さ 0 の `Ty.shift` が恒等であることと、空の `Eff.substRho` が恒等であることを使う。既存の `Ty.shift_zero` と `Eff.substRho_nil` は利用できる。
- **補題 U の帰納法。** まず燃料を明示した `Coverage.usefulFuel` に対する健全性を証明すると、停止の十分性を証明せずに進められる。全ワイルドカード行の早期判定、長さによる行の除外、特殊化後の行から元の行への照合の復元を分ける必要がある。
- **系 2 と実行の規則の接続。** 今回の `AlternativeSelected` に対する系は、補題 U と位置ごとの行列から導く形である。`firstAlt` との接続では、パターンが照合した後に slots の選択が成功することを別に示す必要がある。