//! 制約付き操作の実行・参照比較・交換に共通の入力（設計書 01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」）。

/// 名前、追加宣言、整数を返す式、独立に求めた期待値。
pub const CASES: &[(&str, &str, &str, i64)] = &[
    (
        "constraints on distinct type parameters",
        "effect Render\n function render[A: Trait.Show, B: Trait.Order & Trait.Show](left: A, right: B) -> String\nend effect\n",
        "handle\n String.characterCount(render(right: \"abc\", left: 42)) + String.characterCount(render(right: 7, left: \"xy\"))\nwith\n case render(left, right) ->\n if Trait.Order.compare(x: right, y: right) = Trait.Ordering.Equal then resume(Trait.Show.show(left) + Trait.Show.show(right)) else resume(\"bad\") end if\nend handle",
        12,
    ),
    (
        "two caller types and constraints",
        "effect Render\n function render[T: Trait.Show & Trait.Order & equality](value: T) -> String\nend effect\n",
        "handle\n String.characterCount(render(42)) + String.characterCount(render(\"abc\"))\nwith\n case render(value) ->\n if value = value and Trait.Order.compare(x: value, y: value) = Trait.Ordering.Equal then resume(Trait.Show.show(value)) else resume(\"bad\") end if\nend handle",
        7,
    ),
    (
        "operation reordered holes",
        "effect Pair\n function pair[T: Trait.Show](first: T, second: T) -> String\nend effect\n",
        "handle\n bind f: function(second: String, first: String) -> String uses Pair <- pair(second: _, first: _)\n String.characterCount(f(first: \"a\", second: \"bb\"))\nwith\n case pair(first, second) -> resume(Trait.Show.show(first) + \":\" + Trait.Show.show(second))\nend handle",
        8,
    ),
    (
        "operation holes",
        "effect Render\n function render[T: Trait.Show](value: T) -> String\nend effect\n",
        "handle\n bind show: function(value: Integer) -> String uses Render <- render(value: _)\n String.characterCount(show(42))\nwith\n case render(value) -> resume(Trait.Show.show(value))\nend handle",
        2,
    ),
    (
        "operation pipe",
        "effect Render\n function render[T: Trait.Show](value: T) -> String\nend effect\n",
        "handle\n String.characterCount(42 |> render)\nwith\n case render(value) -> resume(Trait.Show.show(value))\nend handle",
        2,
    ),
    (
        "operation named order and pipe call",
        "effect Pair\n function pair[T: Trait.Show](first: T, second: T) -> String\nend effect\neffect Trace\n function tick(value: Integer) -> Integer\nend effect\n",
        "handle\n bind n <- handle\n bind a <- pair(second: tick(2), first: tick(1))\n bind b <- 3 |> pair(second: tick(4))\n if a = \"1:2\" and b = \"3:4\" then 0 else 10000 end if\nwith\n case pair(first, second) -> resume(Trait.Show.show(first) + \":\" + Trait.Show.show(second))\nend handle\n n\nwith\n case tick(value) ->\n bind rest <- resume(value)\n rest * 10 + value\nend handle",
        412,
    ),
    (
        "outer and clause dictionary zero",
        "effect Render\n function render[T: Trait.Show](value: T) -> String\nend effect\nfunction inspect[T: Trait.Show](outer: T) -> Integer\n return handle\n String.characterCount(render(42))\nwith\n case render(value) ->\n bind show <- lambda() return Trait.Show.show(outer) + Trait.Show.show(value) end lambda\n resume(show())\nend handle\nend function\n",
        "inspect(\"outer\")",
        9,
    ),
    (
        "nested clause dictionaries and lambda",
        "effect Outer\n function outer[T: Trait.Show](value: T) -> String\nend effect\neffect Inner\n function inner[T: Trait.Show](value: T) -> String\nend effect\n",
        "handle\n String.characterCount(outer(42))\nwith\n case outer(value) ->\n bind text <- handle inner(\"x\") with\n case inner(other) ->\n bind show <- lambda() return Trait.Show.show(value) + Trait.Show.show(other) end lambda\n resume(show())\n end handle\n resume(text)\nend handle",
        5,
    ),
    (
        "operation value captures clause superclass",
        "effect Outer\n function outer[T: Trait.Show & Trait.Monoid](value: T) -> String\nend effect\neffect Inner\n function inner[T: Trait.Semigroup](left: T, right: T) -> T\nend effect\n",
        "handle\n String.characterCount(outer(\"a\"))\nwith\n case outer(value) ->\n bind combine <- lambda()\n bind f <- inner\n bind g <- inner(right: _, left: _)\n return handle\n bind _ <- g(left: value, right: value)\n f(right: value, left: value)\n with\n case inner(left, right) -> resume(Trait.Semigroup.combine(x: left, y: right))\n end handle\n end lambda\n resume(Trait.Show.show(combine()))\nend handle",
        4,
    ),
];

/// 期待値も言語内で照合し、参照実行器との一致だけでは誤結果を見逃さない。
pub fn source(declarations: &str, expression: &str, expected: i64) -> String {
    format!(
        "import Benitoite.Trait\n{declarations}\nfunction main() -> Result[Unit, String]\n bind answer <- {expression}\n return if answer = {expected} then Result.Ok(()) else Result.Error(\"wrong value\") end if\nend function\n"
    )
}
