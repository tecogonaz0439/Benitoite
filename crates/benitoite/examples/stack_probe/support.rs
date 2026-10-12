//! 測定と回帰テストで同じ上限の入力を使う（設計書 02-03「入れ子の深さ」）。lib の単体テスト
//! （`pipeline` の `mod tests`）も `#[path]` でこのファイルを読む。

/// 測る形の名前と、構文解析器が数える深さ `k * n + c` の `k` と `c`。
pub const SHAPES: &[(&str, usize, usize)] = &[
    // 最深部は k * n + c。関数(1)、ブロック(2)、式文(3)を基準にする。
    // 束縛の値と最後の式は n + 3。文の並びを深さとして数える。
    ("statements", 1, 3),
    // 要素と引数の並び、bind と二項演算の子で n + 5。
    ("list", 1, 5),
    ("arguments", 1, 5),
    // フィールドの値に加え、二項演算の子で n + 6。
    ("fields", 1, 6),
    // then のブロックと文で二段増える。bind の値から 2n + 4。
    ("if", 2, 4),
    // 各 else if は一段、最後の else のブロックと文まで n + 6。
    ("else-if", 1, 6),
    // 分岐・ブロック・文で三段、最後の false の本体まで 3n + 5。
    ("match-body", 3, 5),
    // 対象で一段、最後の false の本体まで n + 7。
    ("match-subject", 1, 7),
    // Mk(x, _) は三節、最後の _ と match の式文で 3n + 5。
    ("guards", 3, 5),
    // 構成子 n 節と葉の _ 一節を match の式文に加える。
    ("constructor-pattern", 1, 4),
    // リスト n 節・葉の _・次の分岐の _ を match の式文に加える。
    ("list-pattern", 1, 5),
    // 括弧と右辺で二段、左の連鎖とパイプは演算子ごとに一段。
    ("binary-right", 2, 4),
    ("binary-left", 1, 4),
    ("pipe", 1, 4),
    // フィールドの値では二段、更新元では一段ずつ増える。更新元の葉は R(f: 0)。
    ("record", 2, 4),
    ("record-base", 1, 6),
    // ラムダのブロック・bind・その値で三段ずつ増える。
    ("lambda", 3, 4),
    // ブロックと文で二段、最後の openReader の try・パイプ・呼び出しを含めて 2n + 8。
    ("with", 2, 8),
    // lazy と handle のブロックと文は二段。handle の最後の節には resume(()) がある。
    ("lazy", 2, 4),
    ("handle", 2, 6),
    // try と Result.Ok の引数で二段、葉の Result.Ok(()) を含めて 2n + 6。
    ("try", 2, 6),
    // 単項・括弧・リストの子は一段、関数の bind の値から n + 4。
    ("unary", 1, 4),
    ("parentheses", 1, 4),
    ("nested-list", 1, 4),
    // 引数の型は深さ 3。List の引数と関数の戻り値は一段ずつ増える。
    ("list-type", 1, 3),
    ("function-type", 1, 3),
];

/// 形 `shape` を入れ子の上限 `max_depth` の内側に収める繰り返しの数 `n` を返す。
pub fn limit(shape: &str, max_depth: u32) -> Result<usize, String> {
    let (_, k, c) = SHAPES
        .iter()
        .find(|(name, _, _)| *name == shape)
        .ok_or_else(|| format!("unknown shape: {shape}"))?;
    let max = usize::try_from(max_depth).map_err(|e| e.to_string())?;
    Ok(max
        .saturating_sub(*c)
        .checked_div(*k)
        .ok_or("zero depth factor")?)
}

fn nest(prefix: &str, leaf: &str, suffix: &str, n: usize) -> String {
    format!("{}{leaf}{}", prefix.repeat(n), suffix.repeat(n))
}

/// 形 `shape` を `n` 回繰り返したソースを作る。
pub fn source(shape: &str, n: usize) -> Result<String, String> {
    let mut declarations = String::new();
    let expr = match shape {
        "statements" => {
            return Ok(format!(
                "function main() -> Unit\n{}()\nend function\n",
                "bind _ <- 1\n".repeat(n)
            ));
        }
        "list" => format!("[{}]", vec!["1 + 1"; n].join(",")),
        "arguments" => {
            let params = (0..n)
                .map(|i| format!("x{i}: Integer"))
                .collect::<Vec<_>>()
                .join(",");
            declarations = format!("function f({params}) -> Unit\n ()\nend function\n");
            format!("f({})", vec!["1 + 1"; n].join(","))
        }
        "fields" => {
            let fields = (0..n)
                .map(|i| format!(" f{i}: Integer\n"))
                .collect::<String>();
            declarations = format!("record R\n{fields}end record\n");
            format!(
                "R({})",
                (0..n)
                    .map(|i| format!("f{i}: 1 + 1"))
                    .collect::<Vec<_>>()
                    .join(",")
            )
        }
        "if" => nest("if true then ", "()", " else () end if", n),
        "else-if" => format!(
            "if true then (){} else () end if",
            " else if false then ()".repeat(n)
        ),
        "match-body" => nest(
            "match true with\ncase true -> ",
            "()",
            "\ncase false -> ()\nend match",
            n,
        ),
        "match-subject" => nest(
            "match ",
            "true",
            " with\ncase true -> true\ncase false -> false\nend match",
            n,
        ),
        "guards" => {
            declarations = "data L\n Mk(Integer, Integer)\nend data\n".into();
            format!(
                "match L.Mk(0, 0) with\n{}case _ -> ()\nend match",
                "case L.Mk(x, _) if x > 0 -> ()\n".repeat(n)
            )
        }
        "constructor-pattern" => {
            let pat = nest("L.Mk(", "_", ")", n);
            return Ok(format!(
                "data L\n Mk(L)\nend data\nfunction f(x: L) -> Unit\nmatch x with\ncase {pat} -> ()\nend match\nend function\n"
            ));
        }
        "list-pattern" => {
            let ty = nest("List[", "Integer", "]", n);
            let pat = nest("[", "_", "]", n);
            return Ok(format!(
                "function f(x: {ty}) -> Unit\nmatch x with\ncase {pat} -> ()\ncase _ -> ()\nend match\nend function\n"
            ));
        }
        "binary-right" => nest("(1 + ", "1", ")", n),
        "binary-left" => format!("{}1", "1 + ".repeat(n)),
        "pipe" => {
            declarations = "function f(x: Integer) -> Integer\n return x\nend function\n".into();
            format!("1{}", " |> f".repeat(n))
        }
        "record" => {
            declarations = "record R[A]\n f: A\nend record\n".into();
            nest("R(f: ", "0", ")", n)
        }
        "record-base" => {
            declarations = "record R\n f: Integer\nend record\n".into();
            nest("R(..", "R(f: 0)", ", f: 0)", n)
        }
        "lambda" => nest("lambda() bind _ <- ", "()", "\nend lambda", n),
        "with" => {
            declarations = "import Benitoite.Unofficial.IO.File\n".into();
            format!("{}(){}", (0..n).map(|i| format!("with r{i} = try File.openReader(\"input\") |> Result.mapError(_, IOError.message) do ")).collect::<String>(), " end with".repeat(n))
        }
        "lazy" => nest("lazy ", "()", " end lazy", n),
        "handle" => {
            declarations = "effect E\n function op() -> Unit\nend effect\n".into();
            nest(
                "handle ",
                "()",
                " with\ncase op() -> resume(())\nend handle",
                n,
            )
        }
        "try" => nest("try Result.Ok(", "Result.Ok(())", ")", n),
        "unary" => nest("not ", "true", "", n),
        "parentheses" => nest("(", "()", ")", n),
        "nested-list" => nest("[", "0", "]", n),
        "list-type" | "function-type" => {
            let ty = if shape == "list-type" {
                nest("List[", "Integer", "]", n)
            } else {
                nest("function() -> ", "Integer", "", n)
            };
            return Ok(format!("function f(x: {ty}) -> Unit\n ()\nend function\n"));
        }
        _ => return Err(format!("unknown shape: {shape}")),
    };
    if shape == "with" {
        Ok(format!(
            "{declarations}function f() -> Result[Unit, String] uses File.Read, State\n bind _ <- {expr}\n return Result.Ok(())\nend function\n"
        ))
    } else if shape == "try" {
        Ok(format!(
            "{declarations}function f() -> Result[Unit, String]\n bind _ <- {expr}\n return Result.Ok(())\nend function\n"
        ))
    } else {
        Ok(format!(
            "{declarations}function main() -> Unit\n bind _ <- {expr}\nend function\n"
        ))
    }
}
