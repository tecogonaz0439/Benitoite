# L70 の新しい関数の完全署名（下書き）

2026-11-06。[detail.md](detail.md) 第2.9節を、大きさのためにこのファイルへ分けた。第2.9.1節は本書の第2節である。

## 1. 新しい関数の完全署名

u02/decisions.md の「後段への申し送り」1 が L70 の詳細化で固定するとした関数の署名である（RV-L70-plan 中1）。綴りは candidates.md S4・S11・R9 と u02/decisions.md に従う。引数名は同じモジュールの既存の関数に揃えた（`Float.isNaN(x:)`・`Float32.isNaN(n:)`。`crates/benitoite/src/prelude/stdlib/Float.bnt`・`Float32.bnt` を読んで確認）。「核の表現」は Lean の受け持ちである。設計者の選択が残る欄は J70-9〜J70-11 に分けた。J70-9・J70-10 は決定済みで、表の「決定と残る選択」の列に反映した。

| 公開の署名 | モジュール | 核の表現と述語への写し | 決定と残る選択 |
|---|---|---|---|
| `public function check[T](value: T) -> Result[U, CheckError]`。公開の綴りは `Refinement.check(value:)`。`U` は期待型から一意に決まる篩付きの型（DET-L23）で、`T` は `U` の基の型。期待型が決まらなければ注釈を求める | `Benitoite.Unofficial.Refinement`（S11 の推す案） | 組み込みの δ の行1。型引数 `[T, U]` を受け、許容判定 `PrimSig.admits` で `U` の正規形が `T` の篩付きの形であることを要求する。δ は閉じた評価（D19）で篩を評価し、真なら `Ok(value)`、偽なら `Err(CheckError { expected })`。評価できない場合は型付きの入力では起きないことを δ の型付けで示す。専用の型付けの規則は足さない | `admits` が型引数の形を検査できることは R/Syntax.lean の `PrimSig.admits` の型で L70.02 の最初に確かめる（未確認）。できなければ型付けの規則の追加になり、停止条件へ戻す |
| `public record CheckError { expected: String }`、`implement Show` | 同 | 欄1の data。`expected` は期待型を診断と同じ書式で表示した文字列で、機械で解析しないと文書に書く（S11 の E1） | なし |
| 各構成子 `C` について `public function isC[T…](value: D[T…]) -> Boolean`（例 `Shape.isCircle(value:)`）。同じモジュールに同名の関数があれば誤り | 利用者の data と同じモジュール（生成） | 生成する本体は `match value` で `C` の腕だけ `true`。篩の中では `Pred.constructorIs value C` へ写す。本体の結果と述語の閉じた評価の一致を補題にする | J70-9: 結果の型を `Boolean{r \| r = true ⇔ Pred.constructorIs value C}` の形（`or`・`and`・`not` で表す）にし、`if` の枝で同じ事実を得る |
| `public function pathMatches(pattern: String, path: String) -> Boolean` | `Benitoite.Unofficial.Scope` | 純粋な δ の行1。篩の中では pattern がリテラルのときだけ `Pred.member .path path r` へ写す。δ の結果と `Pred.member` の閉じた評価の一致を補題にする | J70-10: pattern は絶対形だけ。リテラルの相対形は静的に拒否し（診断は R60）、実行時の文字列が相対形のときの結果は L70.37 で δ の定義として固定する（候補は false。未決）。J70-9: pattern がリテラルのとき結果の型に所属との一致の篩を付ける |
| `public function hostMatches(pattern: String, host: String) -> Boolean` | 同 | 同じ形で種類 host。基準の名前を持たない | J70-9: pattern がリテラルのとき結果の型に一致の篩を付ける |
| `public function charactersIn(text: String, minimum: Character, maximum: Character) -> Boolean` | 既存の String のモジュール（`String.bnt`） | 純粋な δ の行1。篩の中では `minimum`・`maximum` がリテラルのときだけ `Pred.charactersIn text lo hi` へ写す（`Pred.charactersIn` は端を `Char` の定数で持つ） | J70-9: `minimum`・`maximum` がリテラルのとき結果の型に一致の篩を付ける |
| Float の分類6種（`FloatClass` の finite・nan・positiveInfinity・negativeInfinity・positiveZero・negativeZero）の判定。既存は `Float.isNaN(x:)`・`Float32.isNaN(n:)`・`Float32.isInfinite(n:)` | 既存の Float・Float32 のモジュール | 純粋な δ の行（Float に6、Float32 に5）。篩の中では `Pred.floatClass width class value` へ写す。`isInfinite` は二つの類の `or` へ写す | J70-9: 結果の型に一致の篩を付ける。J70-11（2026-11-06 決定）: 6類と一対一の名前 `isFinite`・`isInfinite`（Float32 は既存）・`isPositiveInfinity`・`isNegativeInfinity`・`isPositiveZero`・`isNegativeZero` を Float と Float32 に足す。署名は `public function isFinite(x: Float) -> Boolean` の形（Float32 は引数名 `n`） |

## 2. Float の分類の関数の名前（J70-11 の材料）

Lean の `FloatClass`（R/ScopeSyntax.lean）は finite・nan・positiveInfinity・negativeInfinity・positiveZero・negativeZero の6類であり、`Pred.floatClass` は幅（binary32・binary64）と類を持つ。処理系の既存の名前は `Float.isNaN(x: Float)`・`Float32.isNaN(n: Float32)`・`Float32.isInfinite(n: Float32)` である（`crates/benitoite/src/prelude/stdlib/Float.bnt`・`Float32.bnt`）。他の言語の公式の文書で確かめた名前は次である。取得日はいずれも2026-11-06。

| 言語と型 | 分類・判定の名前 | 出典 |
|---|---|---|
| Rust `f64` | `is_nan`・`is_infinite`・`is_finite`・`is_subnormal`・`is_normal`・`classify`・`is_sign_positive`・`is_sign_negative`。`classify` の結果 `FpCategory` は `Nan`・`Infinite`・`Zero`・`Subnormal`・`Normal`（正負を区別しない） | <https://doc.rust-lang.org/std/primitive.f64.html>、<https://doc.rust-lang.org/std/num/enum.FpCategory.html> |
| Java `Double` | `isNaN`・`isInfinite`・`isFinite` | <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Double.html> |
| C# `System.Double` | `IsNaN`・`IsInfinity`・`IsPositiveInfinity`・`IsNegativeInfinity`（型の概要の頁）、`IsFinite`（.NET Core 2.1 以降。個別の頁）。`IsNegative`・`IsNormal`・`IsSubnormal`・負の零の判定は確かめていない（未確認） | <https://learn.microsoft.com/en-us/dotnet/api/system.double>、<https://learn.microsoft.com/en-us/dotnet/api/system.double.isfinite> |
| JavaScript `Number` | `Number.isNaN`・`Number.isFinite`（`Number.isInfinite` は無い） | <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number> |
| Haskell `RealFloat` | `isNaN`・`isInfinite`・`isDenormalized`・`isNegativeZero`・`isIEEE` | <https://hackage-content.haskell.org/package/base-4.22.0.0/docs/Prelude.html> |
| Swift `FloatingPoint` | 未確認。公式の頁（<https://developer.apple.com/documentation/swift/floatingpoint>、<https://developer.apple.com/documentation/swift/floatingpointclassification>）は取得した本文に一覧が無く、名前を確かめられなかった | — |

正の零を判定する名前は、確かめた範囲の言語に無かった。正負の無限を分けて判定する名前は C# の `IsPositiveInfinity`・`IsNegativeInfinity` だけ、負の零は Haskell の `isNegativeZero` だけである。

| 案 | 足す名前（Float と Float32 の両方。既存の `isNaN`・`Float32.isInfinite` を保つ） | 述語への写し | 比べた点 |
|---|---|---|---|
| A（推す） | `isFinite`・`isInfinite`（Float にだけ足す）・`isPositiveInfinity`・`isNegativeInfinity`・`isPositiveZero`・`isNegativeZero`。Float は7名のうち新6（`isNaN` が既存）、Float32 は7名のうち新5（`isNaN`・`isInfinite` が既存） | 6類と一対一（`isInfinite` は二類の `or`） | 既存の `isNaN`・`isInfinite` と同じ `is` ＋類の名前の形で揃う。`isFinite`・`isInfinite` は Java・C#・JavaScript・Rust の名前と同じ意味。正負の無限は C#、負の零は Haskell に前例がある。`isPositiveZero` だけは前例を確かめられなかった |
| B | `isFinite`・`isInfinite`（Float にだけ足す）・`isNegativeZero` と、符号の判定 `isSignNegative`（Rust の `is_sign_negative` に当たる） | 正の無限は `isInfinite` と符号の否定、正の零は 0 との比較と符号の否定の組で表す | 足す名前は少ない。ただし符号は `FloatClass` の類ではないので、`isSignNegative` を一つの `Pred.floatClass` へ写せず、有限の値では比較の述語との組合せが要る。篩の中と外で同じ意味を保つ写しが一対一でなくなる |

A を推した。理由: 6類と関数が一対一に対応し、篩の中と外で同じ意味で使う R9 の決定と J70-9 の写しが単純になる。名前の形は既存の `isNaN`・`isInfinite` に揃い、確かめた4言語と同じ意味の名前を含む。引数名は既存に合わせ、Float は `x`、Float32 は `n` とする。

**決定（2026-11-06、設計者。J70-11）**: 案 A を採る。Float と Float32 に `isFinite`・`isInfinite`（Float32 は既存）・`isPositiveInfinity`・`isNegativeInfinity`・`isPositiveZero`・`isNegativeZero` を足す。足す関数は Float が6、Float32 が5である。δ の行と合成表への追加は L70.38、公開の宣言は R40 が受け持つ。

